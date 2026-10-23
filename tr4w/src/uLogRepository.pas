(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* ContestExchange <-> a row in qso.  THE MAPPER, AND NOTHING ELSE.

  WHY A REPOSITORY AND NOT A RECORD THAT SAVES ITSELF.  NY4I, 2026-09-01, on
  being shown the mapper plan: "My original idea about a QSO class is inexorably
  linked to the database. Having an in-between stop does not buy us anything...
  otherwise there is throwaway code."

  Fair, and the answer is the shape rather than the order. With Active Record --
  the QSO object persisting itself -- this code WOULD move when ContestExchange
  becomes a class, and the objection holds. With a repository it does not:

      SaveQSO(const aQso: ContestExchange)   today
      SaveQSO(const aQso: TContestQSO)       after the contest factory

  a parameter type, not a rewrite. The expensive part -- 71 field decisions, the
  enum encodings, the sentinel rules -- is identical either way and stays here.

  It is also what TR4QT does, which is worth knowing precisely because it cuts
  against the instinct: struct QSO is a plain VALUE TYPE that does not persist
  itself, and QSORepository::saveQSO saves it. Section 4e of the schema plan
  reaches the same answer independently, from the aliasing hazard -- a record
  assignment copies, a class assignment aliases, and Pascal reports neither.

  THE FIELD MAPPING IS docs\CONTEST_EXCHANGE_CROSSWALK.md, all 71 of them. Three
  of its findings are load-bearing here and each is a defect if ignored:

  1. THE RECORD HAS NO SENT-EXCHANGE FIELD. exchange_sent is left alone by this
     unit -- it is filled at log time (Phase C), and that is issue #2.

  2. ELEVEN rcvd_* COLUMNS HAVE NO RECORD SOURCE, because the record carries one
     polymorphic QTHString. This unit stores the LITERAL and does not guess which
     of rcvd_grid / rcvd_state / rcvd_park it was: guessing would mean the mapper
     knowing the contest, which is the fusion the migration order exists to
     avoid. The contest factory enriches later.

  3. A SENTINEL IS NOT A VALUE. ClearContestExchange writes -1, MAXBYTE and
     MAXWORD for "not set", so writing them through would put zone 255 and
     Ten-Ten 65535 into every contest that uses neither. They become NULL, and
     NULL becomes the sentinel again on the way back. *)
unit uLogRepository;

{$I tr4w.inc}

interface

uses
   (* Windows for MAXBYTE / MAXWORD, which are the sentinels
     ClearContestExchange writes. DateUtils for the unix epoch. *)
   LCLType, Classes,
   (* TObjectList -- LoadEditedMessages hands back owned rows. *)
   Contnrs,
   SysUtils, DateUtils, db, sqldb, VC, uLogDatabase,
   (* TQsoMyFacts -- our station as it was for one QSO, the my_* columns.
      Last, and it declares nothing any unit above also does. *)
   uQsoMyFacts;

type
   ELogRepositoryError = class(Exception);

   TInt64Array = array of Int64;

   (* THE ENTRY DECLARATION -- tier 2, captured when the log is made.

      Everything a Cabrillo header claims about the ENTRY rather than about a
      contact. Read once, at log creation, and never again: that is the whole
      point. Reading it live at export is TR4W-D12 issue #2 for the header,
      and it produces a defect the corpus cannot see, because golden_diff.py
      compares only QSO lines. Measured: a headless export ships a file with
      CATEGORY-ASSISTED, CATEGORY-BAND and CATEGORY-OPERATOR ABSENT and a
      CATEGORY-MODE of SSB where the log's own configuration says MIXED.

      WHAT IT HOLDS: the entry's callsign and park; the nine Cabrillo
      CATEGORY- tags; CLUB and SOAPBOX; and the station identity as declared
      for this log (name, address, city, state, postcode, country, email).

      WRITTEN ONCE, FOR A NEW (OR JUST-MIGRATED) LOG, AND NEVER ON A REOPEN
      -- uLogContestStatements.RecordEntryDeclaration, Q61 (2026-10-17). It
      had been written on EVERY open, which made it today's values rather
      than the entry's.

      IT IS A RECORD OF THE ENTRY AS MADE, NOT THE CURRENT VALUE, AND
      NOTHING READS IT BACK. The CURRENT value of ASSISTED, BAND, MODE,
      OPERATOR and POWER is ONE contest-scoped setting each, held in this
      log's config table as the operator's statement (Q61, design 7.6) --
      that is what the summary window edits and a headless export reads.

      A RECORD RATHER THAN NINETEEN PARAMETERS, and it is filled by the caller
      rather than read here: the values live in uCbrSum, which is the Cabrillo
      header's tag table and sits beside the window that edits it. The
      repository has no business knowing that. *)
   TLogEntryDeclaration = record
      MyCall: AnsiString;
      MyPark: AnsiString;

      CategoryOperator: AnsiString;
      CategoryAssisted: AnsiString;
      CategoryPower: AnsiString;
      CategoryBand: AnsiString;
      CategoryMode: AnsiString;
      CategoryStation: AnsiString;
      CategoryTime: AnsiString;
      CategoryTransmitter: AnsiString;
      CategoryOverlay: AnsiString;

      Club: AnsiString;
      Soapbox: AnsiString;

      (* Tier 1 as DECLARED FOR THIS LOG. Copied from the station identity at
         creation; edited here it does not disturb the next contest. *)
      OpName: AnsiString;
      Address: AnsiString;
      City: AnsiString;
      State: AnsiString;
      Postcode: AnsiString;
      Country: AnsiString;
      Email: AnsiString;
   end;

   (* ROWS TO REWRITE, BY ROW ID -- collected during a whole-log pass and
      written afterwards in ONE transaction by TLogRepository.WriteBatch.
      Section 9c, F1 and F4.

      WHY COLLECT RATHER THAN WRITE AS THE PASS GOES. The pass reads through
      the sequential cursor, and the connection has ONE transaction: sqldb's
      TSQLTransaction.Commit calls CloseDataSets first (sqldb.pp:2412), so a
      commit made while the cursor is open closes it under the reader. Writing
      inline and committing once at the end would avoid that, but it means
      UPDATEs to the table a live SELECT is stepping through, which SQLite
      documents as undefined for what the SELECT then sees. A second write
      transaction is not available either: on SQLite a transaction belongs to
      the CONNECTION, so it would need a second connection -- the two-connection
      shape uLogStore removed because a reader pinned a stale WAL snapshot.

      So the pass collects, the cursor closes, and the writes follow. A record
      is 376 bytes; a 10,000-row log rewritten in full is under 4 MB, for the
      length of one rescore.

      Owns copies of the records, not references: the caller's local is
      overwritten by the next row.

      THE RECORDS ARE KEPT BY TLogQsoList, which TLogQsoAppends shares: the
      two batches differ only in whether each row already has an id. *)
   TLogQsoList = class(TObject)
   private
      FRows: array of ContestExchange;
      FCount: integer;
   protected
      procedure CheckIndex(aIndex: integer);
      (* A copy of aQso at the end; its index. Grows by doubling, so a
         whole-log batch reallocates a handful of times rather than per row. *)
      function AddRow(const aQso: ContestExchange): integer;
   public
      function Count: integer;
      function Row(aIndex: integer): ContestExchange;
   end;

   (* ONE FUNCTION-KEY MEMORY THE OPERATOR EDITED, as the log's message table
     holds it -- a row with edited = 1 (schema 4, Q113). The spellings are
     the table's: kind 'CQ' | 'EX', mode 'CW' | 'PHONE', key_id KeyId's. *)
   TLogStoredMessage = class(TObject)
   public
      Kind: AnsiString;
      Mode: AnsiString;
      KeyId: AnsiString;
      Text: AnsiString;
      Caption: AnsiString;
   end;

   TLogRowUpdates = class(TLogQsoList)
   private
      FRowIds: array of Int64;
   public
      procedure Add(aRowId: Int64; const aQso: ContestExchange);
      function RowId(aIndex: integer): Int64;
   end;

   (* QSOS TO APPEND IN ONE TRANSACTION -- TLogRepository.AppendBatch.

      The ADIF import's batch (NY4I, 2026-10-14: all or nothing). Its rows
      are new, so there is no row id; everything else is TLogRowUpdates'
      list, and the collect-then-write shape is the rescore's. *)
   TLogQsoAppends = class(TLogQsoList)
   private
      (* OUR STATION FOR EACH ROW, kept in step with the records the way
         TLogRowUpdates keeps its ids. *)
      FMyFacts: array of TQsoMyFacts;
      (* WHAT EACH ROW SENT, from its file -- its exchange_sent. *)
      FSentExchanges: array of AnsiString;
   public
      (* A row with no captured station: my_source NULL, as a row written
         before schema 3 -- and no sent exchange. *)
      procedure Add(const aQso: ContestExchange); overload;
      (* A row with OUR STATION AS IT WAS for that QSO and WHAT IT SENT -- both
         from the file it is imported from, never from today's settings (log
         schema 3, stage 2: the D3 fix). '' sends nothing. *)
      procedure Add(const aQso: ContestExchange;
                    const aMyFacts: TQsoMyFacts;
                    const aSentExchange: AnsiString = ''); overload;
      function MyFacts(aIndex: integer): TQsoMyFacts;
      (* Replaces row aIndex's station -- the import's decision, made once the
         whole file has been read (NY4I, 2026-10-18). *)
      procedure SetMyFacts(aIndex: integer; const aMyFacts: TQsoMyFacts);
      function SentExchange(aIndex: integer): AnsiString;
   end;

   (* ~~TSentExchangeText~~ -- the callback AppendBatch asked for a row's sent
      exchange -- IS GONE (stage 2, 2026-10-18). Its one caller supplied the
      LIVE builder, so every imported QSO claimed to have sent today's
      exchange (D3). A row carries its own now; see TLogQsoAppends.Add. *)

   (* QSOs THAT CARRY NO EXCHANGE ID -- TLogRepository.QSOsWithoutExchangeId.
      Count is every one; Sample is the first few, in log order, as
      "CALL yyyy-mm-dd hh:mm" -- enough to find them, not a listing. *)
   TMissingExchangeIds = record
      Count: integer;
      Sample: string;
   end;

   (* Reads and writes QSOs.  Owns its prepared statements and nothing else --
     the connection belongs to the TLogDatabase handed in. *)
   TLogRepository = class(TObject)
   private
      FDatabase: TLogDatabase;
      FInsert: TSQLQuery;
      (* Fields that arrived from disk outside their type's range and were
        stored as NULL. Non-zero means the record did not decode correctly --
        see TestTheRecordHasTheSameFIELD_OFFSETSEverywhere, which is the test
        that says WHY on a platform where it happens. *)
      FDecodeAnomalies: integer;
      FSelect: TSQLQuery;
      FLastGuid: AnsiString;
      FLastSetId: AnsiString;
      FSetIdForNextSave: AnsiString;
      FSentExchangeForNextSave: AnsiString;
      (* OUR STATION FOR THE NEXT INSERT -- SetNextMyFacts. Cleared after every
         save, like the sent exchange; mfsNotCaptured (the zero value) binds
         every my_* column, my_source included, as NULL. *)
      FMyFactsForNextSave: TQsoMyFacts;
      FContest: TContestHandle;
      (* The contest row's start_time, read with the contest -- see
         LogStartTime. *)
      FStartTime: TDateTime;
      (* The contest row's my_call -- the call the entry DECLARED (see
         DeclaredCall), read with the contest. *)
      FDeclaredCall: AnsiString;

      FUpdate: TSQLQuery;
      (* THE ONE WRITE OF A ROW'S my_* COLUMNS AFTER ITS INSERT -- Edit QSO
         (NY4I, ruling B). Kept, so it executes through ExecuteKeptWrite. *)
      FUpdateMyFacts: TSQLQuery;
      FSelectById: TSQLQuery;

      (* A CONTIGUOUS RUN OF ROWS, prepared once -- section 9b. A virtual grid
        asks for "the rows on screen", and answering that a row at a time cost
        three statements per row, each one created, assigned, opened and freed.
        One statement per screenful instead. *)
      FSelectRange: TSQLQuery;

      (* HOW MANY ROWS THERE ARE, remembered.

        RecordCount was a SELECT row count -- a full table scan -- and
        LogSourceReadAtIndex called it on EVERY row fetch purely to bounds-check
        the index. Measured on an 8,448-row log: 1.3 ms, per row.

        Only an INSERT changes it, so the answer is invalidated there and
        nowhere else. -1 means "not known yet". *)
      FRecordCount: Int64;
      (* Created on demand by OpenSequentialRead -- an export is rare and a
         prepared statement held open for the life of the repository would keep
         a read transaction open with it. *)
      FCursor: TSQLQuery;

      (* RowIdAtIndex's statement, prepared ONCE like the others. It was
        created, prepared, opened and freed on every call, and a rescore calls
        it once per QSO: the 2026-10-14 prototype measured 150 us a call
        before and 47 after. *)
      FRowIdAtIndex: TSQLQuery;

      (* True between BeginBatchUpdate and a CommitBatch or RollbackBatch that
         completed. Stays True if a rollback itself fails, so BeginBatchUpdate
         refuses rather than committing what that rollback left behind. *)
      FInBatch: boolean;

      procedure InvalidateRecordCount;
      function NewReadQuery: TSQLQuery;
      procedure ExecuteKeptWrite(aStatement: TSQLQuery);
      procedure OpenQsoReader(aQuery: TSQLQuery; aTrailingRowId: boolean = False);
      procedure PrepareStatements;
      procedure LoadContest;
      function LastInsertedRowId: Int64;
      procedure BindInto(aQuery: TSQLQuery; const aQso: ContestExchange;
                         const aGuid: AnsiString; aInserting: boolean);
      procedure BindRecord(const aQso: ContestExchange; const aGuid: AnsiString);
      procedure BindUpdate(const aQso: ContestExchange);
      procedure ReadRecord(aQuery: TSQLQuery; out aQso: ContestExchange);
      (* The my_* columns: the insert's (aQuery = FInsert) and the editor's
         update's (FUpdateMyFacts), one binder so they cannot disagree. *)
      procedure BindMyFacts(aQuery: TSQLQuery; const aFacts: TQsoMyFacts);
      (* PRECONDITION as ReadRecord's: opened by OpenQsoReader. *)
      procedure ReadMyFacts(aQuery: TSQLQuery; out aFacts: TQsoMyFacts);
      (* THE ONE CURSOR STEP -- every sequential read is this. *)
      function ReadNextRow(out aRowId: Int64; out aQso: ContestExchange;
                           out aFacts: TQsoMyFacts;
                           out aSentExchange: AnsiString): boolean;
      function CountRows(const aSQL: AnsiString): integer;
   public
      constructor Create(aDatabase: TLogDatabase);
      destructor Destroy; override;

      (* Appends a QSO and returns ITS ROW ID -- the handle everything else uses.

        THE ROW IDENTITY IS qso.id, AND THAT WAS MEASURED RATHER THAN CHOSEN.
        The obvious candidate was (ceQSOID1, ceQSOID2), because uNet's
        FindAndUpdateQSOInLog already finds a QSO to update by matching exactly
        that pair. It is not unique: across four corpus logs it gave 3 distinct
        pairs for 1,316 rows, 2 for 206, and in winter_fd 1,314 of 1,316 rows
        are (0, 0). The pair is stamped only on the network path, so that
        function is right for ITS job and useless as a general handle -- keying
        an update on it would have matched 1,314 rows at once.

        Does NOT commit; the caller decides the batch. *)
      function SaveQSO(const aQso: ContestExchange): Int64;

      (* The guid the last SaveQSO stored, for anything that wants the durable
        identity rather than the row handle. *)
      property LastGuid: AnsiString read FLastGuid;

      (* Fields that arrived outside their type's range and were stored as
        NULL. NON-ZERO MEANS THE RECORD DID NOT DECODE CORRECTLY -- an
        importer should report this rather than claim a clean import. *)
      property DecodeAnomalies: integer read FDecodeAnomalies;

      (* PUT THE NEXT SAVED QSO IN THIS SET -- a county line, a POTA n-fer.

        Set it before the SECOND and subsequent rows of one contact, passing the
        set id of the first (which is that row's own guid, since a lone QSO is a
        set of one).

        CLEARED AFTER EVERY SAVE, deliberately: a sticky set id would silently
        pull the next unrelated QSO into the same contact, and that is a defect
        nobody would see until an ADIF export merged two contacts. *)
      (* WHAT THIS QSO SENT, captured for the next save.

         THE RECORD HAS NO FIELD FOR IT, which is TR4W-D12 issue #2 in one
         sentence: the sent exchange is rebuilt from station globals at EXPORT
         time, so correcting a typo or changing a grid retroactively rewrites
         what every past QSO claims to have sent. Two of the four corpus
         known-divergences are that defect.

         So it is captured HERE, at log time, by the caller that knows --
         uExchangeBuilder.BuildSentExchangeText, which reads the live
         CQ exchange template and substitutes this QSO's serial.

         AN IMPORT LEAVES IT EMPTY, and must. A binary log does not record what
         was sent, and inventing it from today's globals would be exactly the
         bug this column exists to fix, committed by the tool meant to fix it.

         Cleared after every save, like the QSO set, so one contact cannot
         inherit another's exchange.

         FOR AN INSERT ONLY. UpdateQSO does not read it, and an update keeps
         the exchange_sent the row already holds. exchange_sent is INSERT-ONLY:
         nothing writes it on an existing row. *)
      procedure SetNextSentExchange(const aSentExchange: AnsiString);

      (* OUR STATION, AS IT WAS FOR THE NEXT SAVED QSO -- the my_* columns.

         The same shape as SetNextSentExchange and for the same reason: the
         record has no field for them, so the caller that knows supplies them
         for the insert. uLogStore captures them at the moment of the QSO;
         an importer passes what its file says, or nothing.

         NOT SET MEANS NOT CAPTURED: my_source is NULL and every reader falls
         back to the session (NY4I, ruling A). That is right for a .TRW
         migration, whose records hold none of this, and wrong for anything
         that knows better -- so a caller that knows MUST set it.

         Cleared after every save. INSERT-ONLY: UpdateQSO, the rescore's
         batch and the network update never touch these columns -- an edit
         changes only what was edited (Q13). The editor writes them, on
         purpose, through UpdateQSOMyFacts. *)
      procedure SetNextMyFacts(const aFacts: TQsoMyFacts);

      (* THE OPERATOR'S CORRECTION -- Edit QSO (NY4I, ruling B). Writes every
         my_* column of the row, my_source included; the caller states the
         source (mfsEdited for an operator's change). Does NOT commit. True
         when the row exists. *)
      function UpdateQSOMyFacts(aRowId: Int64; const aFacts: TQsoMyFacts): boolean;

      (* The row's my_* columns; NotCapturedMyFacts for a row written before
         schema 3. False, and NotCapturedMyFacts, when there is no such row. *)
      function LoadQSOMyFacts(aRowId: Int64; out aFacts: TQsoMyFacts): boolean;

      procedure SetNextQSOSet(const aSetId: AnsiString);

      (* SAVE, PUTTING CONSECUTIVE QSOs THAT SHARE A ContestExchange.id INTO ONE
        SET.  The rule both the importer and the live shadow need, so it lives
        here rather than in each of them.

        WHY THAT RULE. A county line or a POTA n-fer is one contact logged as
        several QSOs, and TR4W writes them CONSECUTIVELY -- the county loop in
        DrainPendingMultiQSORefs calls LogContact once per county without
        anything in between. They also share ContestExchange.id, because that
        field identifies the EXCHANGE: measured on the shipped florida_qp
        fixture, where two W4THY rows both carry
        5cd6c61f69cf4422baef44f93b2cbbd2.

        SO "SAME NON-EMPTY id AS THE PREVIOUS SAVE" IS THE WHOLE RULE, and it
        needs no map of every id in the log. Consecutive is what makes it
        bounded; sharing the id is what makes it right.

        An empty id -- which is most QSOs, since the field is only set on some
        paths -- always starts a new set of one. Grouping on an absent
        identity would merge unrelated contacts. *)
      function SaveQSOGroupingByExchangeId(const aQso: ContestExchange): Int64;

      (* The set the last SaveQSO used -- the id to hand back to SetNextQSOSet
        for the rest of the contact. *)
      property LastSetId: AnsiString read FLastSetId;

      (* What else was this contact? Row ids sharing the set, EXCLUDING the one
        asked about. Empty for an ordinary QSO.

        This is the question qso_set_id exists to answer: ADIF wants one record
        per CONTACT (LoTW keys on call + band + mode + date + time, so three
        records for one contact read as two duplicates), while Cabrillo and the
        log itself want one per QSO. *)
      function RelatedRowIds(aRowId: Int64): TInt64Array;

      (* IMPORT KEYED ON THE GUID: update the row that already carries it, or
        insert one that does.  Returns the row id either way, and aWasNew says
        which happened.

        NY4I, 2026-09-01: "On import, we have to ensure we use the uuid7 in the
        ADIF file as the key. Upon import, we look for an existing item (or just
        insert with no dupes and handle the error)... This allows us to import
        our own exported file. Also good for testing."

        WHY A LOOKUP RATHER THAN CATCHING THE UNIQUE VIOLATION. Both work, and
        the lookup is the one that can UPDATE. Re-importing a file is usually
        meant to refresh what changed, not to skip it -- and a failed INSERT
        inside a batch transaction leaves sqldb's prepared statement in a state
        the next row has to recover from, which is a lot of machinery to buy a
        result that is worse.

        THE CALLER MUST PASS A PER-QSO GUID. Do not pass ContestExchange.id: it
        identifies the EXCHANGE, and a county-line contact is one exchange
        logged as several QSOs. Measured on the shipped florida_qp corpus
        export -- 3 ADIF records, 2 distinct APP_TR4W_ID -- so keying on it
        would silently merge the pair and lose a contact. *)
      function ImportQSOByGuid(const aGuid: AnsiString;
                               const aQso: ContestExchange;
                               out aWasNew: boolean): Int64;

      (* REPLACES the row.  Every column BindRecord writes is rewritten, so a
        partially-populated record blanks what it does not carry -- which is
        what the file-based code does too, since it rewrites the whole record.
        EXCEPT guid, qso_set_id and exchange_sent, which the record does not
        carry and an edit cannot change (QSO_COLUMNS_UPDATABLE).
        False when there is no such row. *)
      function UpdateQSO(aRowId: Int64; const aQso: ContestExchange): boolean;

      (* The newest row, which is what the three "seek back one record" sites
        want: DeleteLastContact, uNet.UpdateRec and uQTCS.SetSendedQSOs all
        rewrite the record they have just written. *)
      (* THE LOG'S CONTEST, WHICH IS NOT ON THE QSO ROW.

        ceContest is stored once, on the contest row, because one log is one
        contest -- and that is measured rather than assumed: all thirteen corpus
        logs carry exactly one distinct ContestType.

        IT MUST STILL BE RESTORED ON READ. It is not decoration: PostUnit
        asks the QSO's own contest (ContestIdentity(rec.ceContest)) for its
        ADIF fields while EXPORTING -- POTA's park tags among them -- MainUnit asks
        the contest's class about a county line from it during ADIF import, and
        HamScore emits it as <contestnr>. A QSO loaded with ceContest left at
        DUMMYCONTEST would export as the wrong contest, silently. *)
      procedure SetContest(aContest: TContestHandle);

      (* Writes the entry declaration onto the contest row.  Call once, when
         the log is created -- see TLogEntryDeclaration for why never again.
         uLogContestStatements.RecordEntryDeclaration is the guarded call.

         False when there is no contest row to write it on: the UPDATE
         invents no row, and a caller that meant to record the declaration
         needs to know it did not. *)
      function SetEntryDeclaration(const aDeclaration: TLogEntryDeclaration): boolean;

      (* CONFIGURATION AND PROGRAM MESSAGES INTO THE LOG -- phase E.

         NY4I: "the configuration info for a database should go into the
         database file too. That includes anything that goes into the .CFG file
         including Program Messages (Alt-P)... when done, the .cfg file should
         not be necessary."

         UPSERTS, because these are CURRENT STATE and not history. An operator
         who changes QSO POINT METHOD mid-contest has changed it; there is no
         earlier value the log needs to defend, which is the opposite of
         exchange_sent and the same reasoning as the entry declaration.

         aSource is the schema's precedence field and it is load-bearing rather
         than descriptive: with no .cfg file left, 'contest' versus 'station' is
         the only thing that says an explicit contest setting outranks the
         station default. uCFG.CommandCameFromContestCFG already knows which is
         which -- this does not re-derive it. *)
      procedure SaveConfigValue(const aCommand, aValue, aSource: AnsiString);

      (* REMOVE A COMMAND'S ROW, if it has one. An absent row is not an error.

        A contest-scoped row exists only while the operator has STATED that
        setting -- absence means the contest decides (section 7.8 of
        docs/CONTEST_OWNERSHIP_DESIGN.md) -- so the capture deletes the row of
        every contest-scoped setting that is not stated, which is also what
        clears the sentinel rows a log written before that rule carries. *)
      procedure DeleteConfigValue(const aCommand: AnsiString);

      (* WHERE THE OPERATOR LEFT OFF -- the session_state table.

        DELIBERATELY SEPARATE FROM SaveConfigValue, though the shape is the
        same. A config row is a SETTING, something the operator chose and
        that a contest file or the station store can also supply; a session
        row is a POSITION, meaningful only to the log it sits in and to
        nobody else. Sharing one table would mean the precedence rules that
        the source column exists for would start applying to a radio's band
        memory, which is nonsense.

        AN ABSENT KEY IS NOT AN ERROR. It is a log written before this
        existed, or a field added since, and both must read as the default
        the caller passes rather than as a failure -- which is the whole
        reason this is rows rather than one blob. *)
      procedure SaveSessionValue(const aKey, aValue: AnsiString);
      function SessionValue(const aKey: AnsiString;
                            const aDefault: AnsiString = ''): AnsiString;
      (* aEdited is the row's edited flag (schema 4, Q113): True for a memory
         the OPERATOR edited, which LoadEditedMessages hands back at open.
         Every other row records the contest's default as it stood. *)
      procedure SaveMessage(const aKind, aMode, aKeyId, aText,
                            aCaption: AnsiString; aEdited: boolean = False);

      (* EMPTY THE message TABLE -- the capture at close rewrites it whole, so
         a memory emptied this session, or no longer edited, leaves no row
         behind to be restored. Does not commit. *)
      procedure DeleteAllMessages;

      (* THE MEMORIES THE OPERATOR EDITED -- the rows with edited = 1, as
         TLogStoredMessage objects aInto owns, ordered by kind, mode, key.
         aInto is cleared first. A log written before schema 4 has none. *)
      procedure LoadEditedMessages(aInto: TObjectList);

      (* How many rows each holds -- for verifying a capture actually captured
         something, which is the failure a silent upsert loop would otherwise
         hide. *)
      (* THE COMMANDS THIS CONTEST SET, as command/value pairs, in the order
         SQLite returns them.

         source = 'contest' ONLY, and that is the whole precedence rule. Those
         are the rows a contest .cfg set; the 'station' rows are a RECORD of
         what the station config was when the log was made -- kept so the log
         describes itself, applied by nothing, because tr4w.ini and
         settings\tr4w.json still own station settings.

         Applying everything was measured wrong once already, in a different
         guise: ApplyStoredCommands takes today's station settings over the
         log's own .cfg and took the corpus from 21/1/4 to 8/14/4, which is why
         it is skipped under /EXPORT. *)
      procedure LoadContestConfig(aInto: TStrings);

      function ConfigCount: integer;
      function MessageCount: integer;
      function LogContest: TContestHandle;

      (* WHEN THE LOG SAYS ITS CONTEST STARTED: the contest row's start_time
         (unix UTC) as a UTC TDateTime, or 0 when the row has none. Q35
         (2026-10-17) is the first reader -- the contest year a bonus table
         is chosen by (uContestBase.LogContestYear).

         READ ONCE, WHEN THE REPOSITORY OPENS (LoadContest), because the
         score asks for it after every QSO and a query per score is the cost
         uScoreTotals measured and refused. NOTHING WRITES start_time YET --
         Q99 seeds it at New Contest -- so today this is 0 for every log. *)
      function LogStartTime: TDateTime;

      (* THE CALL THIS LOG'S ENTRY DECLARED -- contest.my_call, written once
         when the log was made (RecordEntryDeclaration). What an export writes
         for a QSO that recorded no call of its own (log schema 3, stage 4: a
         logged QSO reads the log, not today's MY CALL). '' when none. *)
      function DeclaredCall: AnsiString;

      function NewestRowId: Int64;

      (* The id of the Nth row in id order, counting from zero -- 0 for a log
        with fewer rows than that.

        THE BINARY LOG ADDRESSES A RECORD BY ITS ORDINAL POSITION, which is what
        the QSO editor has (a byte offset divided by the record size). This
        converts that to a row handle WITHOUT assuming id = position + 1: the
        ids happen to be contiguous today, but an assumption that only holds
        while nothing has ever been deleted is one that breaks silently the
        first time something is. *)
      function RowIdAtIndex(aIndex: Int64): Int64;

      (* A RUN OF RECORDS IN LOG ORDER, starting at aFirstIndex, in ONE
        statement. Fills aRows from its low bound and returns how many were
        read -- fewer than requested at the end of the log.

        THIS IS WHAT A GRID ACTUALLY ASKS FOR. Fetching row by row through
        RowIdAtIndex meant an OFFSET walk per row (O(n), 1.4 ms at 8,448 rows)
        plus a row count plus a load, with a statement compiled and thrown away
        each time. *)
      function ReadRange(aFirstIndex: Int64;
                         var aRows: array of ContestExchange): integer;

      (* The multi-op network's own key, which uNet.FindAndUpdateQSOInLog uses to
        find a QSO by scanning the whole log backwards.

        REFUSES (0, 0) and returns False. That pair is stamped only on the
        network path, so it is the DEFAULT for every other QSO -- 1,314 of
        winter_fd's 1,316 rows carry it -- and an unguarded UPDATE would rewrite
        all of them with one record. *)
      function UpdateQSOBySessionIds(aSessionId, aSessionSeq: Int64;
                                     const aQso: ContestExchange): boolean;

      (* SEQUENTIAL READ, IN LOG ORDER -- what an export walks.

         A CURSOR RATHER THAN A LIST, because the binary reader it replaces is
         one: the thirteen export loops in PostUnit are shaped "open, read the
         next record into TempRXData, decide, repeat", and handing them an array
         instead would mean rewriting every loop to prove a mapping. This way
         the loops do not change at all, so a difference in the exported bytes
         can only have come from the STORE.

         ORDER BY id, which is insertion order, which is log order: the binary
         log is append-only and the rowid is an AUTOINCREMENT assigned in the
         same sequence. Ordering by time would NOT be the same thing -- QSO
         times come from the operator's clock and go backwards across a UTC
         correction. *)
      procedure OpenSequentialRead;
      function ReadNext(out aQso: ContestExchange): boolean; overload;
      (* ReadNext, and the row's OWN STATION -- its my_* columns (schema 3),
         NotCapturedMyFacts for a row written before. What the ADIF export
         writes its MY_* tags from. *)
      function ReadNext(out aQso: ContestExchange;
                        out aFacts: TQsoMyFacts): boolean; overload;
      function ReadNextWithMyFacts(out aRowId: Int64;
                                   out aQso: ContestExchange;
                                   out aFacts: TQsoMyFacts): boolean;
      (* ReadNext, the row's station, and WHAT IT SENT -- exchange_sent, '' for
         none. For the export: an imported row's exchange_sent is its file's
         STX_STRING, verbatim (log schema 3, stage 4). *)
      function ReadNextForExport(out aQso: ContestExchange;
                                 out aFacts: TQsoMyFacts;
                                 out aSentExchange: AnsiString): boolean;

      (* ReadNext, and the ROW ID of the record it read -- the handle
         UpdateQSOByRowId takes. The cursor SELECTs it after QSO_COLUMNS, so
         a whole-log pass can rewrite a row without asking where it is: the
         rescore used RowIdAtIndex, an OFFSET walk, once per row and twice per
         changed row. 0 at the end. *)
      function ReadNextWithRowId(out aRowId: Int64;
                                 out aQso: ContestExchange): boolean;
      procedure CloseSequentialRead;

      (* ONE TRANSACTION FOR MANY ROWS -- section 9c, F4.

         Every other write here commits per call, which is right for a QSO
         being logged: the commit IS the contact. A whole-log rewrite is the
         opposite case. Per row it cost a WAL commit apiece (754 ms of a
         1,316-row rescore, measured 2026-10-14), and a failure part-way
         left the log half rescored.

         BeginBatchUpdate COMMITS whatever the connection's implicit
         transaction holds and then begins a fresh one, so the batch's
         boundary is exact and RollbackBatch undoes the batch and nothing
         before it. Every caller of a write here commits its own work, so
         what that first commit ends is normally a read. It REFUSES while
         the sequential cursor is open, because that commit would close the
         cursor (sqldb.pp:2412), and it refuses a second batch.

         THE EXPLICIT START MARKS THE BOUNDARY. sqldb begins a transaction
         only when a statement PREPARES (sqldb.pp:1296), and FUpdate and
         FInsert stay prepared, so they used to execute in SQLite's
         AUTOCOMMIT after any commit -- each UPDATE durable on its own. F4
         found that here; section 9c's audit found it was true of EVERY
         kept write, and ExecuteKeptWrite now begins the transaction for all
         of them (pinned by TestEveryWriteWaitsForItsCommit). The batch still
         starts its own, so its boundary is BeginBatchUpdate and not its
         first row (pinned by TestAFailedBatchRollsBackWhole).

         ROLLBACK GOES THROUGH TLogDatabase.Rollback, which survives SQLite
         having ended the transaction by itself -- on SQLITE_FULL, IOERR,
         NOMEM or BUSY it may. sqldb does not notice that; its own ROLLBACK
         then fails with "no transaction is active", which hid the real
         error, left InBatch True for good and made the close raise too
         (pinned by TestABatchSQLiteRollsBackItselfLeavesTheRepositoryUsable).

         UpdateQSOByRowId RAISES when the row does not exist. UpdateQSO
         answers False there, which suits an edit; inside a batch a missing
         row means the batch is not what its caller read, and it must not be
         half applied.

         WriteBatch is the usual way in: begin, every row, commit, and on ANY
         exception roll back and re-raise. *)
      procedure BeginBatchUpdate;
      procedure UpdateQSOByRowId(aRowId: Int64; const aQso: ContestExchange);
      procedure CommitBatch;
      procedure RollbackBatch;
      procedure WriteBatch(aUpdates: TLogRowUpdates);

      (* APPENDS MANY QSOS IN ONE TRANSACTION -- ALL OR NONE. The ADIF
         import's write (NY4I, 2026-10-14), on the batch above: BeginBatchUpdate,
         every row, CommitBatch, and on ANY exception RollbackBatch and
         re-raise. Not a second mechanism -- the same begin, commit and
         rollback WriteBatch uses, with an insert where it has an update.

         EACH ROW IS WRITTEN AS THE LIVE APPEND WRITES ONE
         (uLogStore.LogStoreAppendQSO): the contest stamped from the record
         when the log carries another, and SaveQSOGroupingByExchangeId. The
         grouping lookup sees this transaction's own rows, so a county line
         inside one file still groups.

         THE ROW'S SENT EXCHANGE AND STATION ARE ITS OWN -- what the batch was
         given for it (TLogQsoAppends.Add), never what this station sends now.
         That is where it differs from the live append, on purpose: the live
         append records a QSO logged HERE, NOW.

         aFailedIndex is the 0-based index of the row that failed, or -1
         when the failure was not a row's -- the begin or the commit. Set
         before the exception leaves, so a caller can name the record. *)
      procedure AppendBatch(aQsos: TLogQsoAppends;
                            out aFailedIndex: integer);
      property InBatch: boolean read FInBatch;

      (* QSO ROWS WITH NO EXCHANGE ID. Reads only.

         A rescore no longer mints one (NY4I, 2026-10-14, open question F6):
         an id is an identity, and inventing it in a scoring pass rewrote
         every row of an imported log on its first rescore. So a log can
         legitimately hold QSOs without one -- a .TRW migration, an ADIF from
         a program that writes none -- and the validity check REPORTS them
         rather than anything repairing them. Notes and QTC records are not
         QSOs and are not counted; deleted QSOs are, since they are still
         contacts in the log. aSampleSize caps the sample, not the count. *)
      function QSOsWithoutExchangeId(aSampleSize: integer): TMissingExchangeIds;

      function LoadQSO(aRowId: Int64; out aQso: ContestExchange): boolean;

      (* By the guid rather than the row.  Kept because the guid is the identity
        that survives an export and a re-import, where a row id does not. *)
      function LoadQSOByGuid(const aGuid: AnsiString; out aQso: ContestExchange): boolean;

      (* Non-deleted QSOs, counted by the database rather than tracked here --
        section 9a: no stored derived values, no in-memory mirror. *)
      function QSOCount: integer;

      (* EVERY row, including deleted ones and non-QSO record kinds.

        Distinct from QSOCount on purpose: this is the number that compares
        against a binary log's record count, and the binary log holds the
        deleted records too. Using QSOCount there would report drift on every
        log that contains a deleted QSO. *)
      function RecordCount: Int64;

      (* Empties the qso table and keeps the contest row -- see the
        implementation for why that distinction matters. The caller commits. *)
      procedure DeleteAllQSOs;
      procedure Commit;

      property Database: TLogDatabase read FDatabase;
   end;

(* A UUIDv7: 48-bit big-endian millisecond timestamp, version 7, then random.
  Question 5 of the schema plan settled v7 over v4 -- it sorts by creation time,
  so a log's rows cluster in insertion order on disk and a chooser can order by
  guid without a second column.

  aUnixMillis lets the IMPORTER stamp a QSO's own time rather than the moment of
  import, so an imported log sorts the way it was made. *)
function NewUUIDv7(aUnixMillis: Int64): AnsiString;

(* THE ROW'S OWN guid, ALWAYS FRESH.

  It would be tempting to reuse ContestExchange.id when the record has one, and
  the first version did. IT IS WRONG, and the corpus proved it: `id` identifies
  the EXCHANGE, not the QSO. A county-line contact is one exchange logged as
  several QSOs, and they share the id -- two W4THY rows in
  florida_qp_2026_ny4i both carry 5cd6c61f69cf4422baef44f93b2cbbd2. Reusing it
  violates the unique key on the second QSO of any county line.

  The record's id is preserved separately, in exchange_id, where two rows
  sharing it is a fact rather than a collision.

  Stamped with the QSO's own time so an imported log sorts the way it was made
  rather than the way it was imported. *)
function NewRowGuid(const aQso: ContestExchange): AnsiString;

(* ceOperator is array[0..10] of AnsiChar, and a cast between a fixed buffer
  and a managed string is NOT a conversion -- see the implementation.
  READING the field back is utils_text.CharBufferBytes: the same NUL-aware
  read. This unit carried its own copy of it, and a second hand-rolled loop
  is how the two drift. WRITING it is this routine, which may use all eleven
  bytes and NUL-pads the tail. *)
procedure AnsiToCharArray(var aBuffer: array of AnsiChar; const aValue: AnsiString);

(* THE COLUMN LIST EVERY qso READER SELECTS, in the order ReadRecord reads it.
  Exported for the pin tests and for nothing else. *)
function QsoColumnList: AnsiString;

(* '' when the ordinal table ReadRecord reads by agrees with QSO_COLUMNS, else
  what disagrees. Computed once, when the unit initializes. *)
function QsoColumnTableProblem: AnsiString;

(* RAISES ELogRepositoryError unless aQuery's fields are QSO_COLUMNS, by name,
  position for position. ReadRecord reads a column by its POSITION, so a reader
  whose SELECT drifted would put one column's value in another field without a
  single error -- this is what turns that into a loud failure at Open instead.

  aTrailingRowId: the reader also SELECTs the row id, AFTER QSO_COLUMNS, so
  exactly one more column, named id, is required at that position. *)
procedure VerifyQsoColumns(aQuery: TSQLQuery; aTrailingRowId: boolean = False);

implementation

uses
   (* TypInfo is here for GetEnumName only -- the proof that TQsoColumn
     matches QSO_COLUMNS. FIRST in this list, so the units below still win
     any name it shares with them. It does follow the interface units; no
     identifier in this unit is one TypInfo also declares (checked
     2026-10-14). *)
   TypInfo,
   uADIF, uLogBinaryFile, ZONECONT, TF,
   utils_text,   (* CharBufferBytes -- a fixed char field read back *)
   uLogNote,   (* NoteText / SetNoteText -- where a note's text lives *)
   uContestRegistry,   (* ContestIdentity, ContestId -- the contest's names *)
   uContestNames;      (* ContestFromName -- the contest row read back *)

(* --------------------------------------------------------------------------- *)
(* sentinels -- crosswalk finding 3                                            *)
(* --------------------------------------------------------------------------- *)

(* Each of these takes the value and the marker ClearContestExchange uses for
  "not set", and yields NULL for it.  Written as four small functions rather
  than inline tests because the sentinel differs per field and an inline `if`
  repeated forty times is where one of them gets the wrong constant. *)

procedure BindByte(aParam: TParam; aValue: byte; aSentinel: byte);
begin
   if aValue = aSentinel then
      begin
      aParam.Clear;      (* NULL *)
      end
   else
      begin
      aParam.AsInteger := aValue;
      end;
end;

procedure BindWord(aParam: TParam; aValue: word; aSentinel: word);
begin
   if aValue = aSentinel then
      begin
      aParam.Clear;
      end
   else
      begin
      aParam.AsInteger := aValue;
      end;
end;

procedure BindSerial(aParam: TParam; aValue: integer);
begin
   (* -1, not 0. ClearContestExchange sets NumberSent and NumberReceived to -1,
     and 0 is a legal serial in some contests. *)
   if aValue = -1 then
      begin
      aParam.Clear;
      end
   else
      begin
      aParam.AsInteger := aValue;
      end;
end;

procedure BindText(aParam: TParam; const aValue: AnsiString);
begin
   (* An empty ShortString and a NULL are the same absence. Storing '' would make
     `WHERE rcvd_grid IS NULL` and `= ''` disagree about the same QSO. *)
   if aValue = '' then
      begin
      aParam.Clear;
      end
   else
      begin
      aParam.AsString := aValue;
      end;
end;

(* ceOperator IS array[0..10] of AnsiChar, NOT a ShortString.

  `AnsiString(aQso.ceOperator)` and `OperatorType(someAnsiString)` both COMPILE
  and both are wrong, which is the whole hazard: the first takes all eleven
  bytes including the NUL padding, and the second is a pointer cast that
  dereferences the string's data -- so an EMPTY AnsiString, whose data pointer
  is nil, faults. Found by a test whose QSO simply had no operator (2026-09-01),
  which is the ordinary case for a single-op log.

  This is the same class CLAUDE.md warns about at Win32 boundaries: a cast
  between a fixed buffer and a managed string is not a conversion. *)

(* OPEN ARRAYS, NOT UNTYPED POINTERS. NY4I, 2026-09-01: "no artifacts of win32
  string handling when we are done -- no PChar, string pointers, s[1] type
  stuff. All native FPC/LAZ."

  The first version took `const aBuffer` untyped and walked it with a PAnsiChar,
  which is the Win32 habit this tree is unwinding. An open array says the same
  thing in the language: the compiler passes the bounds, Low and High are real,
  and there is no address arithmetic to get wrong.

  This exists at all because ContestExchange.ceOperator is
  array[0..10] of AnsiChar -- a fixed buffer in a record designed in the
  nineties. When the contest factory turns that record into a class the field
  becomes a string and AnsiToCharArray can go too. *)
procedure AnsiToCharArray(var aBuffer: array of AnsiChar; const aValue: AnsiString);
var
   i: integer;
begin
   for i := Low(aBuffer) to High(aBuffer) do
      begin
      if i < Length(aValue) then
         begin
         aBuffer[i] := aValue[i + 1];
         end
      else
         begin
         (* NUL padding, so the tail is not whatever was there before. *)
         aBuffer[i] := #0;
         end;
      end;
end;

procedure BindBool(aParam: TParam; aValue: boolean);
begin
   if aValue then
      begin
      aParam.AsInteger := 1;
      end
   else
      begin
      aParam.AsInteger := 0;
      end;
end;

function FieldByte(aField: TField; aSentinel: byte): byte;
begin
   if aField.IsNull then
      begin
      Result := aSentinel;
      end
   else
      begin
      Result := byte(aField.AsInteger);
      end;
end;

function FieldWord(aField: TField; aSentinel: word): word;
begin
   if aField.IsNull then
      begin
      Result := aSentinel;
      end
   else
      begin
      Result := word(aField.AsInteger);
      end;
end;

function FieldSerial(aField: TField): integer;
begin
   if aField.IsNull then
      begin
      Result := -1;
      end
   else
      begin
      Result := aField.AsInteger;
      end;
end;

function FieldBool(aField: TField): boolean;
begin
   Result := (not aField.IsNull) and (aField.AsInteger <> 0);
end;

(* --------------------------------------------------------------------------- *)
(* enum tokens -- the SAME arrays ADIF export uses                             *)
(* --------------------------------------------------------------------------- *)

(* Deliberately not a second set of spellings. ADIFBANDSTRINGSARRAY,
  ADIFModeString and ExtendedModeStringArray are what the exporter emits, so a
  log's band column reads the same as its ADIF file, and there is one table to
  get wrong instead of two. The inverses are uADIF's GetADIFBand / GetADIFMode
  for the same reason. *)

function BandToken(aBand: BandType): AnsiString;
begin
   (* The nil guard is gone with the pointer. Bands ADIF has no token for
     are '' in the table itself now, so the branch that turned a null
     pointer into an empty string by hand has nothing left to do. *)
   Result := AnsiString(ADIFBANDSTRINGSARRAY[aBand]);
end;

function ModeToken(aMode: ModeType): AnsiString;
begin
   Result := AnsiString(ADIFModeString[aMode]);
end;

function ExtModeToken(aMode: ExtendedModeType): AnsiString;
begin
   Result := AnsiString(ExtendedModeStringArray[aMode]);
end;

(* THE INVERSE OF ADIFModeString, BY SCANNING IT -- not uADIF.GetADIFMode.

  That is not duplication, it is a different contract. GetADIFMode maps ADIF
  MODE NAMES (and several TR4W-specific extended modes) onto a TR4W mode, which
  is what an ADIF importer needs. It does not accept 'DIGITAL', the string
  ADIFModeString[Digital] actually contains -- so a Digital QSO written by this
  mapper came back as NoMode. Measured: nine corpus QSOs across florida_qp and
  arrl_fd, 2026-09-01.

  Deriving the inverse from the same array is what makes the pair correct by
  construction, the way uRadioRegistry.RadioTypeToken does for radios. *)
function TokenToMode(const aToken: AnsiString): ModeType;
var
   m: ModeType;
   tok: string;
begin
   Result := NoMode;
   if aToken = '' then
      begin
      Exit;
      end;
   (* Widened ONCE. Comparing an AnsiString against a UnicodeString picks the
     Ansi overload of SameText and narrows BOTH arguments at every iteration,
     which the build counts and which is lossy for anything outside the ANSI
     codepage -- neither is wanted for what is really an ASCII token match. *)
   tok := UpperCase(string(aToken));
   for m := Low(ModeType) to High(ModeType) do
      begin
      (* UpperCase and '=' rather than SameText: SameText resolves to its
        AnsiString overload even when both arguments are UnicodeString, and
        narrows them back at every iteration. These are ASCII tokens we wrote
        ourselves, so an uppercase compare is exact. *)
      if UpperCase(string(AnsiString(ADIFModeString[m]))) = tok then
         begin
         Result := m;
         Exit;
         end;
      end;
end;

function TokenToExtMode(const aToken: AnsiString): ExtendedModeType;
var
   m: ExtendedModeType;
   tok: string;
begin
   (* Derived by scanning the same array rather than kept as a second table --
     the trick uRadioRegistry.RadioTypeToken uses, which makes drift
     unrepresentable rather than merely fixed. *)
   Result := eNoMode;
   if aToken = '' then
      begin
      Exit;
      end;
   tok := UpperCase(string(aToken));
   for m := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      if UpperCase(ExtendedModeStringArray[m]) = tok then
         begin
         Result := m;
         Exit;
         end;
      end;
end;

function RecordKindToken(aKind: LogRecordKind): AnsiString;
begin
   case aKind of
      rkQSO:  Result := 'QSO';
      rkQTCR: Result := 'QTCR';
      rkQTCS: Result := 'QTCS';
      rkNote: Result := 'NOTE';
   else
      Result := 'QSO';
   end;
end;

function TokenToRecordKind(const aToken: AnsiString): LogRecordKind;
begin
   if aToken = 'QTCR' then
      begin
      Result := rkQTCR;
      end
   else if aToken = 'QTCS' then
      begin
      Result := rkQTCS;
      end
   else if aToken = 'NOTE' then
      begin
      Result := rkNote;
      end
   else
      begin
      Result := rkQSO;
      end;
end;

(* --------------------------------------------------------------------------- *)
(* identity                                                                     *)
(* --------------------------------------------------------------------------- *)

(* NOW, AS UNIX SECONDS -- WHICH ARE UTC BY DEFINITION, and every *_at column
  of the log says so (uLogSchema: "unix UTC").

  DateTimeToUnix does NOT convert: it counts days from 1970 in whatever clock
  it is handed, and its AInputIsUTC parameter defaults to True, so handing it
  Now stored LOCAL time as if it were UTC -- off by the station's UTC offset.
  Every write of "now" here did that until 2026-10-19 (contest.created_at,
  config.set_at, session_state.saved_at, and the timestamp inside a contest
  row's guid). LocalTimeToUniversal(Now) is how the rest of the tree reads
  UTC (uSpotAge.UTCNow, uSynTime, TF), so it is used here too rather than a
  third way. Rows already written keep what they hold: nothing migrates them,
  and nothing reads set_at or saved_at. *)
function UnixNowUTC: Int64;
begin
   Result := DateTimeToUnix(LocalTimeToUniversal(Now));
end;

function NewUUIDv7(aUnixMillis: Int64): AnsiString;
var
   b: array[0..15] of byte;
   i: integer;
   ms: Int64;
begin
   ms := aUnixMillis;
   if ms <= 0 then
      begin
      ms := UnixNowUTC * Int64(1000);
      end;

   (* 48-bit big-endian timestamp. *)
   for i := 0 to 5 do
      begin
      b[i] := byte((ms shr ((5 - i) * 8)) and $FF);
      end;

   for i := 6 to 15 do
      begin
      b[i] := byte(Random(256));
      end;

   b[6] := (b[6] and $0F) or $70;   (* version 7 *)
   b[8] := (b[8] and $3F) or $80;   (* variant 10 *)

   (* NO DASHES -- 32 lowercase hex characters.

     Not a style choice: ContestExchange.id is string[32], so the canonical
     36-character form does not fit and a round trip silently truncates it,
     which is how the first version failed its own stability test. TF.GetGUID
     already returns "32-char lowercase hex, no dashes" for the same field, so
     this matches what every existing id in every existing log looks like. *)
   Result := '';
   for i := 0 to 15 do
      begin
      Result := Result + AnsiString(LowerCase(IntToHex(b[i], 2)));
      end;
end;

function NewRowGuid(const aQso: ContestExchange): AnsiString;
begin
   Result := NewUUIDv7(QSOTimeToUnixUTC(aQso.tSysTime) * Int64(1000));
end;

(* --------------------------------------------------------------------------- *)
(* TLogRepository                                                               *)
(* --------------------------------------------------------------------------- *)

const
   (* OUR STATION AT THE MOMENT OF THE QSO -- schema 3. Named once and used
     twice: at the end of QSO_COLUMNS, so every reader carries them and the
     insert writes them, and as the whole SET clause of FUpdateMyFacts. NOT in
     QSO_COLUMNS_UPDATABLE, like exchange_sent: no ordinary update can reach
     them. *)
   QSO_MY_COLUMNS =
      'my_county, my_grid, my_state, my_call, my_section, my_park, my_iota, ' +
      'my_country, my_continent, my_cq_zone, my_itu_zone, my_source';

   (* Named once. Adding a column means adding it here, in BindRecord and in
     ReadRecord, and the round-trip test fails if the three disagree. *)
   QSO_COLUMNS =
      'guid, exchange_id, qso_set_id, session_id, session_seq, ' +
      'computer_id, operator_id, record_kind, ' +
      'qso_at, callsign, standard_call, freq_tx_hz, freq_rx_hz, is_split, ' +
      'band, mode, submode, ' +
      'exchange_sent, exchange_received, ' +
      'rst_sent, rst_received, serial_sent, serial_received, ' +
      'rcvd_zone, rcvd_name, rcvd_age, rcvd_check, rcvd_precedence, rcvd_class, ' +
      'rcvd_power, rcvd_chapter, rcvd_prefecture, rcvd_member_no, rcvd_qth, ' +
      'rcvd_random, random_sent, rcvd_kids, qtc_call, domestic_qth, ' +
      'dxcc_prefix, dxcc_entity, dxcc_code, cty_cq_zone, cty_continent, ' +
      'prefix_mult, dx_mult, domestic_mult, ' +
      'mult_domestic, mult_dx, mult_prefix, mult_zone, inhibit_mults, ' +
      'qso_points, is_dupe, is_run, is_xqso, is_skipped, sent_in_qtc, ' +
      'name_sent, mp3_recorded, clear_dupe_sheet, clear_mult_sheet, ' +
      'radio_nr, operator_call, deleted, sent_to_server, server_dirty, notes, ' +
      QSO_MY_COLUMNS;

   (* THE UPDATABLE COLUMNS: the same list WITHOUT guid, WITHOUT
     qso_set_id, WITHOUT exchange_sent and WITHOUT QSO_MY_COLUMNS (schema 3,
     for exchange_sent's reason: the record has no field for them, so an
     update would bind nothing and erase what the insert captured).

     The first two are identity rather than content, and an edit changes what
     a QSO SAYS, not which row it is or which contact it belonged to. Leaving
     qso_set_id in here was a real defect, caught by a live run: the update
     had no set id to bind, wrote an empty string, and the first QSO of the
     session lost its membership of the county-line pair it had just been
     grouped into. Every subsequent edit would have done the same.

     exchange_sent WENT FOR THE SAME REASON (Q61's column audit, 2026-10-16;
     fixed 2026-10-17). It is what was SENT when the QSO was logged, and the
     record has no field for it -- so an update had nothing to bind but
     FSentExchangeForNextSave, which SaveQSO clears after every insert. Every
     Edit QSO, every rescore and every network update therefore wrote NULL
     over the sent exchange. An edit changes only what was edited (Q13), and
     nothing an edit can reach is the sent exchange. NOTHING writes it on an
     existing row: ~~SetSentExchange~~ did, for one caller -- uLogStore's
     append-after-a-migration branch -- and went with that branch on
     2026-10-17 (the .TRW never holds the QSO being appended). *)
   QSO_COLUMNS_UPDATABLE =
      'exchange_id, session_id, session_seq, ' +
      'computer_id, operator_id, record_kind, ' +
      'qso_at, callsign, standard_call, freq_tx_hz, freq_rx_hz, is_split, ' +
      'band, mode, submode, ' +
      'exchange_received, ' +
      'rst_sent, rst_received, serial_sent, serial_received, ' +
      'rcvd_zone, rcvd_name, rcvd_age, rcvd_check, rcvd_precedence, rcvd_class, ' +
      'rcvd_power, rcvd_chapter, rcvd_prefecture, rcvd_member_no, rcvd_qth, ' +
      'rcvd_random, random_sent, rcvd_kids, qtc_call, domestic_qth, ' +
      'dxcc_prefix, dxcc_entity, dxcc_code, cty_cq_zone, cty_continent, ' +
      'prefix_mult, dx_mult, domestic_mult, ' +
      'mult_domestic, mult_dx, mult_prefix, mult_zone, inhibit_mults, ' +
      'qso_points, is_dupe, is_run, is_xqso, is_skipped, sent_in_qtc, ' +
      'name_sent, mp3_recorded, clear_dupe_sheet, clear_mult_sheet, ' +
      'radio_nr, operator_call, deleted, sent_to_server, server_dirty, notes';

   QSO_PARAMS =
      ':guid, :exchange_id, :qso_set_id, :session_id, :session_seq, ' +
      ':computer_id, :operator_id, :record_kind, ' +
      ':qso_at, :callsign, :standard_call, :freq_tx_hz, :freq_rx_hz, :is_split, ' +
      ':band, :mode, :submode, ' +
      ':exchange_sent, :exchange_received, ' +
      ':rst_sent, :rst_received, :serial_sent, :serial_received, ' +
      ':rcvd_zone, :rcvd_name, :rcvd_age, :rcvd_check, :rcvd_precedence, :rcvd_class, ' +
      ':rcvd_power, :rcvd_chapter, :rcvd_prefecture, :rcvd_member_no, :rcvd_qth, ' +
      ':rcvd_random, :random_sent, :rcvd_kids, :qtc_call, :domestic_qth, ' +
      ':dxcc_prefix, :dxcc_entity, :dxcc_code, :cty_cq_zone, :cty_continent, ' +
      ':prefix_mult, :dx_mult, :domestic_mult, ' +
      ':mult_domestic, :mult_dx, :mult_prefix, :mult_zone, :inhibit_mults, ' +
      ':qso_points, :is_dupe, :is_run, :is_xqso, :is_skipped, :sent_in_qtc, ' +
      ':name_sent, :mp3_recorded, :clear_dupe_sheet, :clear_mult_sheet, ' +
      ':radio_nr, :operator_call, :deleted, :sent_to_server, :server_dirty, :notes, ' +
      ':my_county, :my_grid, :my_state, :my_call, :my_section, :my_park, :my_iota, ' +
      ':my_country, :my_continent, :my_cq_zone, :my_itu_zone, :my_source';

(* 'a, b, c' -> 'a = :a, b = :b, c = :c'.

  DERIVED FROM QSO_COLUMNS rather than written out, so the insert and the update
  cannot drift. A hand-maintained second list is how an update quietly stops
  writing a column that the insert writes -- the row would look right on
  creation and lose the field on the first edit. *)
(* TYPED AnsiString CONSTANTS, not literals.

  An untyped literal is UnicodeString here -- tr4w.inc makes `string` UTF-16 --
  so concatenating one with an AnsiString narrows, and `AnsiString('x')` does NOT
  help: the literal is still built as UnicodeString and then converted, which is
  the very conversion being counted. A typed constant is compiled as AnsiString
  from the start. *)
const
   COMMA_SEP:  AnsiString = ', ';
   EQUALS_BIND: AnsiString = ' = :';
   UPDATE_HEAD: AnsiString = 'UPDATE qso SET ';
   UPDATE_TAIL: AnsiString = ' WHERE id = :row_id';

type
   TAnsiStringArray = array of AnsiString;

(* 'a, b, c' -> ['a', 'b', 'c']. ONE splitter for a column list: AssignmentsFor
  and the ordinal table below both read QSO_COLUMNS through it, so they cannot
  disagree about what a column name is.

  Split by hand rather than with StrUtils' WordCount/ExtractWord: those take
  UnicodeString here, so every column name would round-trip through a
  narrowing conversion for no reason. The separator is one character and the
  input is our own constant. *)
function SplitColumnList(const aColumns: AnsiString): TAnsiStringArray;
var
   i: integer;
   n: integer;
   name: AnsiString;

   procedure Emit;
   begin
      if name = '' then
         begin
         Exit;
         end;
      SetLength(Result, n + 1);
      Result[n] := name;
      Inc(n);
      name := '';
   end;

begin
   SetLength(Result, 0);
   n := 0;
   name := '';
   for i := 1 to Length(aColumns) do
      begin
      if aColumns[i] = ',' then
         begin
         Emit;
         end
      else if aColumns[i] <> ' ' then
         begin
         name := name + aColumns[i];
         end;
      end;
   Emit;
end;

function AssignmentsFor(const aColumns: AnsiString): AnsiString;
var
   names: TAnsiStringArray;
   i: integer;
begin
   names := SplitColumnList(aColumns);
   Result := '';
   for i := 0 to High(names) do
      begin
      if i > 0 then
         begin
         Result := Result + COMMA_SEP;
         end;
      Result := Result + names[i] + EQUALS_BIND + names[i];
      end;
end;

(* --------------------------------------------------------------------------- *)
(* the ordinal table -- how ReadRecord finds a column                          *)
(* --------------------------------------------------------------------------- *)

(* EVERY COLUMN OF QSO_COLUMNS, BY POSITION. ReadRecord reads
  aQuery.Fields[Ord(qc_x)] instead of aQuery.FieldByName('x').

  WHY. In FPC 3.2.2 TFields.FindField is a LINEAR scan that upper-cases both
  names on every comparison. ReadRecord resolved about a hundred fields per row
  that way -- 190 us a row, measured 2026-10-14 -- on every read path the
  program has: LoadinLog at startup, four full reads per /EXPORT, the rescore
  and the grid. By position it is about 10 us a row.

  THE RULE THAT MAKES POSITION SAFE: every reader SELECTs QSO_COLUMNS and
  nothing else, and VerifyQsoColumns checks it BY NAME, position for position,
  every time a reader opens -- a mismatch RAISES; there is no fallback to a
  name lookup, because a fallback is how a shifted read would go unnoticed.

  THE IDENTIFIER IS qc_ PLUS THE COLUMN NAME, EXACTLY. That is not a style
  choice: BuildQsoColumnTable compares each identifier's RTTI name against
  QSO_COLUMNS, so an element added, dropped or moved on one side and not the
  other is reported, and the table refuses to be used. *)
type
   TQsoColumn = (
      qc_guid, qc_exchange_id, qc_qso_set_id, qc_session_id, qc_session_seq,
      qc_computer_id, qc_operator_id, qc_record_kind,
      qc_qso_at, qc_callsign, qc_standard_call, qc_freq_tx_hz, qc_freq_rx_hz,
      qc_is_split,
      qc_band, qc_mode, qc_submode,
      qc_exchange_sent, qc_exchange_received,
      qc_rst_sent, qc_rst_received, qc_serial_sent, qc_serial_received,
      qc_rcvd_zone, qc_rcvd_name, qc_rcvd_age, qc_rcvd_check,
      qc_rcvd_precedence, qc_rcvd_class,
      qc_rcvd_power, qc_rcvd_chapter, qc_rcvd_prefecture, qc_rcvd_member_no,
      qc_rcvd_qth,
      qc_rcvd_random, qc_random_sent, qc_rcvd_kids, qc_qtc_call,
      qc_domestic_qth,
      qc_dxcc_prefix, qc_dxcc_entity, qc_dxcc_code, qc_cty_cq_zone,
      qc_cty_continent,
      qc_prefix_mult, qc_dx_mult, qc_domestic_mult,
      qc_mult_domestic, qc_mult_dx, qc_mult_prefix, qc_mult_zone,
      qc_inhibit_mults,
      qc_qso_points, qc_is_dupe, qc_is_run, qc_is_xqso, qc_is_skipped,
      qc_sent_in_qtc,
      qc_name_sent, qc_mp3_recorded, qc_clear_dupe_sheet, qc_clear_mult_sheet,
      qc_radio_nr, qc_operator_call, qc_deleted, qc_sent_to_server,
      qc_server_dirty, qc_notes,
      (* QSO_MY_COLUMNS, in its order. *)
      qc_my_county, qc_my_grid, qc_my_state, qc_my_call, qc_my_section,
      qc_my_park, qc_my_iota, qc_my_country, qc_my_continent, qc_my_cq_zone,
      qc_my_itu_zone, qc_my_source);

const
   QC_PREFIX: AnsiString = 'qc_';
   QSO_COLUMN_COUNT = Ord(High(TQsoColumn)) + 1;

   (* The row id, which is NOT in QSO_COLUMNS -- it is the table's own key,
     never bound by a writer. The sequential cursor selects it AFTER them, at
     position QSO_COLUMN_COUNT. A `string` constant because it is only ever
     compared with a FieldName and put in a message, both `string`. *)
   ROW_ID_COLUMN = 'id';

var
   (* FILLED ONCE, by BuildQsoColumnTable from the initialization section, and
     read-only after that -- so readers on any thread see the same table. *)
   GQsoColumnName: array[TQsoColumn] of AnsiString;
   GQsoColumnTableProblem: AnsiString;

procedure BuildQsoColumnTable;
var
   names: TAnsiStringArray;
   column: TQsoColumn;
   declared: AnsiString;
begin
   GQsoColumnTableProblem := '';
   names := SplitColumnList(QSO_COLUMNS);
   if Length(names) <> QSO_COLUMN_COUNT then
      begin
      GQsoColumnTableProblem := SysUtils.Format(
         'uLogRepository: QSO_COLUMNS names %d columns and TQsoColumn ' +
         'declares %d. They must be the same list in the same order.',
         [Length(names), QSO_COLUMN_COUNT]);
      Exit;
      end;

   for column := Low(TQsoColumn) to High(TQsoColumn) do
      begin
      GQsoColumnName[column] := names[Ord(column)];
      declared := GetEnumName(TypeInfo(TQsoColumn), Ord(column));
      if not SameText(declared, QC_PREFIX + names[Ord(column)]) then
         begin
         GQsoColumnTableProblem := SysUtils.Format(
            'uLogRepository: column %d of QSO_COLUMNS is "%s" but TQsoColumn ' +
            'declares %s there. They must be the same list in the same order.',
            [Ord(column), names[Ord(column)], declared]);
         Exit;
         end;
      end;
end;

function QsoColumnList: AnsiString;
begin
   Result := QSO_COLUMNS;
end;

function QsoColumnTableProblem: AnsiString;
begin
   Result := GQsoColumnTableProblem;
end;

(* ONCE PER OPEN, NOT PER ROW: sixty-eight name comparisons against a
  table built at start-up, a few microseconds, so the guard costs nothing a
  reader would notice and is never skipped. *)
procedure VerifyQsoColumns(aQuery: TSQLQuery; aTrailingRowId: boolean);
var
   column: TQsoColumn;
   actual: AnsiString;
   expected: integer;
begin
   if Length(GQsoColumnTableProblem) > 0 then
      begin
      raise ELogRepositoryError.Create(GQsoColumnTableProblem);
      end;

   expected := QSO_COLUMN_COUNT;
   if aTrailingRowId then
      begin
      Inc(expected);
      end;

   if aQuery.Fields.Count <> expected then
      begin
      raise ELogRepositoryError.Create(SysUtils.Format(
         'A qso reader returned %d columns where QSO_COLUMNS names %d%s. ' +
         'Its fields are read by POSITION, so it refuses rather than read ' +
         'one column into another field.',
         [aQuery.Fields.Count, QSO_COLUMN_COUNT,
          BoolToStr(aTrailingRowId, ' and the row id follows them', '')]));
      end;

   (* The FieldName is compared as the string it is -- copying it into an
     AnsiString first would be a narrowing conversion for no reason. *)
   if aTrailingRowId and
      (not SameText(aQuery.Fields[QSO_COLUMN_COUNT].FieldName, ROW_ID_COLUMN)) then
      begin
      raise ELogRepositoryError.Create(SysUtils.Format(
         'A qso reader returned "%s" as column %d where the row id "%s" ' +
         'belongs. It is read by POSITION, so it refuses rather than take ' +
         'another column for the row id.',
         [aQuery.Fields[QSO_COLUMN_COUNT].FieldName, QSO_COLUMN_COUNT,
          ROW_ID_COLUMN]));
      end;

   for column := Low(TQsoColumn) to High(TQsoColumn) do
      begin
      actual := aQuery.Fields[Ord(column)].FieldName;
      if not SameText(actual, GQsoColumnName[column]) then
         begin
         raise ELogRepositoryError.Create(SysUtils.Format(
            'A qso reader returned "%s" as column %d where QSO_COLUMNS has ' +
            '"%s". Its fields are read by POSITION, so it refuses rather ' +
            'than read one column into another field.',
            [actual, Ord(column), GQsoColumnName[column]]));
         end;
      end;
end;

constructor TLogRepository.Create(aDatabase: TLogDatabase);
begin
   inherited Create;
   if (aDatabase = nil) or (not aDatabase.IsOpen) then
      begin
      raise ELogRepositoryError.Create(
         'A log repository needs an open contest log.');
      end;
   (* AT CONSTRUCTION, not at the first read: a column table that disagrees
     with QSO_COLUMNS is a build defect, and the earliest point it can be
     reported is the moment anything asks for a repository. *)
   if Length(GQsoColumnTableProblem) > 0 then
      begin
      raise ELogRepositoryError.Create(GQsoColumnTableProblem);
      end;
   FDatabase := aDatabase;
   FContest := NoContest;
   FRecordCount := -1;
   PrepareStatements;
   LoadContest;
end;

destructor TLogRepository.Destroy;
begin
   (* Before the prepared statements: it holds an open result set on the
      same connection. *)
   CloseSequentialRead;
   FInsert.Free;
   FSelect.Free;
   FSelectById.Free;
   FSelectRange.Free;
   FRowIdAtIndex.Free;
   FUpdate.Free;
   FUpdateMyFacts.Free;
   inherited Destroy;
end;

(* A QUERY THAT ONLY READS. Every SELECT in this unit is made here.

  UsePrimaryKeyAsKey := False is the point of it. sqldb's default is True, and
  then EVERY Open of a single-table SELECT first runs UpdateServerIndexDefs
  (sqldb.pp:3121) -- PRAGMA table_info, index_list and index_info -- to learn
  which fields are the key, so that edits made through the dataset can be
  written back. Nothing here edits through a dataset: writes are INSERT and
  UPDATE statements of their own. Measured 2026-10-14 on winter_fd's log, a
  prepared SELECT by id re-opened for each of its 1,316 rows: about 935 us an
  Open with the default, about 715 with this off.

  ParseSQL := False would skip the same metadata -- sqldb's own comment calls
  that a "practical side effect" -- and measured the same (about 755 us). It is
  not used because it is a side effect: UsePrimaryKeyAsKey names exactly the
  work being declined. *)
function TLogRepository.NewReadQuery: TSQLQuery;
begin
   Result := TSQLQuery.Create(nil);
   try
      Result.DataBase := FDatabase.Connection;
      Result.UsePrimaryKeyAsKey := False;
   except
      Result.Free;
      raise;
   end;
end;

(* EVERY EXECUTION OF FInsert OR FUpdate GOES THROUGH HERE, AND IT IS WHAT
  MAKES "Does NOT commit; the caller decides" TRUE OF THEM -- section 9c.

  sqldb begins a transaction only when a statement PREPARES (sqldb.pp:1296).
  A statement made per call -- config, session, messages, the contest row --
  prepares every time and so always runs inside one. FInsert and FUpdate are
  prepared ONCE, at construction, and kept; so after ANY Commit they ran in
  SQLite's AUTOCOMMIT, each one durable the moment it executed. Measured
  2026-10-14 (TestEveryWriteWaitsForItsCommit, before this existed): a SaveQSO
  or an UpdateQSO survived a close with no commit, and of "two SaveQSOs" or
  "UpdateQSO then SaveConfigValue" the FIRST write survived and the second
  did not -- half applied, by a caller that believed it held one
  transaction.

  So a kept write begins the transaction a prepare would have begun, and
  the caller's Commit -- or the rollback at close when it never comes -- ends
  it. One fsync either way: the autocommit paid one per statement, and a
  caller's Commit pays one per transaction.

  A NEW KEPT WRITE STATEMENT MUST EXECUTE THROUGH HERE TOO. *)
procedure TLogRepository.ExecuteKeptWrite(aStatement: TSQLQuery);
begin
   if not FDatabase.Transaction.Active then
      begin
      FDatabase.Transaction.StartTransaction;
      end;
   aStatement.ExecSQL;
end;

(* EVERY qso READER OPENS HERE, and is checked before a row is read. A reader
  that opened some other way would bypass the guard ReadRecord depends on. *)
procedure TLogRepository.OpenQsoReader(aQuery: TSQLQuery; aTrailingRowId: boolean);
begin
   aQuery.Open;
   try
      VerifyQsoColumns(aQuery, aTrailingRowId);
   except
      aQuery.Close;
      raise;
   end;
end;

(* PREPARED ONCE, RE-EXECUTED WITH PARAMETERS -- section 9b. Re-assigning
  SQL.Text per call throws the plan away and re-parses, which is the mistake
  that makes people conclude they need a cache. *)
procedure TLogRepository.PrepareStatements;
begin
   FInsert := TSQLQuery.Create(nil);
   FInsert.DataBase := FDatabase.Connection;
   FInsert.SQL.Text := 'INSERT INTO qso (' + QSO_COLUMNS + ') VALUES (' +
                       QSO_PARAMS + ')';
   FInsert.Prepare;

   FSelect := NewReadQuery;
   FSelect.SQL.Text := 'SELECT ' + QSO_COLUMNS + ' FROM qso WHERE guid = :guid';
   FSelect.Prepare;

   FSelectById := NewReadQuery;
   FSelectById.SQL.Text := 'SELECT ' + QSO_COLUMNS + ' FROM qso WHERE id = :row_id';
   FSelectById.Prepare;

   FSelectRange := NewReadQuery;
   FSelectRange.SQL.Text := 'SELECT ' + QSO_COLUMNS +
                            ' FROM qso ORDER BY id LIMIT :n OFFSET :m';
   FSelectRange.Prepare;

   FRowIdAtIndex := NewReadQuery;
   FRowIdAtIndex.SQL.Text := 'SELECT id FROM qso ORDER BY id LIMIT 1 OFFSET :n';
   FRowIdAtIndex.Prepare;

   (* guid is NOT in the SET clause: a row's identity does not change when its
     contents do, and rewriting it would break anything holding the old one. *)
   FUpdate := TSQLQuery.Create(nil);
   FUpdate.DataBase := FDatabase.Connection;
   FUpdate.SQL.Text := UPDATE_HEAD +
                       AssignmentsFor(QSO_COLUMNS_UPDATABLE) +
                       UPDATE_TAIL;
   FUpdate.Prepare;

   FUpdateMyFacts := TSQLQuery.Create(nil);
   FUpdateMyFacts.DataBase := FDatabase.Connection;
   FUpdateMyFacts.SQL.Text := UPDATE_HEAD +
                              AssignmentsFor(QSO_MY_COLUMNS) +
                              UPDATE_TAIL;
   FUpdateMyFacts.Prepare;
end;

(* ONE BINDER FOR BOTH STATEMENTS.

  BindUpdate calls this against FUpdate, so the insert and the update cannot
  populate different sets of columns -- which is the defect that would show as
  a field surviving creation and vanishing on the first edit. The only
  difference is the guid, which an update must not touch: a row's identity does
  not change when its contents do. *)
procedure TLogRepository.BindInto(aQuery: TSQLQuery;
                                  const aQso: ContestExchange;
                                  const aGuid: AnsiString;
                                  aInserting: boolean);
var
   (* THE RECORD THAT IS BOUND -- aQso itself, except that a note's region
     is cleared. See the first statement of the body. *)
   rec: ContestExchange;


   (* AnsiString, because that is what ParamByName takes. Declaring it `string`
     narrowed on every one of sixty-odd binds. *)
   function P(const aName: AnsiString): TParam;
   begin
      Result := aQuery.ParamByName(aName);
   end;

begin
   (* A NOTE IS NOT A SET OF FIELDS. Its text runs on from Prefix across
     Callsign and the fields after it, so binding those fields by their
     types stored the note as fragments -- its first letter taken as a
     length, the rest truncated -- and put note bytes into columns such as
     the age and the multiplier flags. So every column is bound from a copy
     with that region cleared, and the text goes to `notes`, below. *)
   rec := aQso;
   if aQso.ceRecordKind = rkNote then
      begin
      SetNoteText(rec, '');
      end;

   if aInserting then
      begin
      P('guid').AsString := aGuid;
      end;
   BindText(P('exchange_id'), AnsiString(rec.id));

   (* The set this QSO belongs to. FSetIdForNextSave lets a caller put several
     rows in one set -- a county line, a POTA n-fer -- and is cleared after
     every save so the NEXT QSO cannot silently join a set it has nothing to do
     with. Empty means "a set of one", filled in below with the row's own
     guid. *)
   (* INSERT ONLY. An update must not rewrite which contact this QSO belonged
     to -- see QSO_COLUMNS_UPDATABLE. *)
   if aInserting then
      begin
      if FSetIdForNextSave <> '' then
         begin
         P('qso_set_id').AsString := FSetIdForNextSave;
         end
      else
         begin
         P('qso_set_id').AsString := aGuid;
         end;
      end;

   (* Identity. session_id/session_seq are ceQSOID1/ceQSOID2 -- the pair
     tr4wserver matches on, and how WAE links a QTC to its QSO. *)
   P('session_id').AsLargeInt := rec.ceQSOID1;
   P('session_seq').AsLargeInt := rec.ceQSOID2;
   BindText(P('computer_id'), AnsiString(rec.ceComputerID));
   P('operator_id').AsInteger := rec.ceOperatorID;
   P('record_kind').AsString := RecordKindToken(rec.ceRecordKind);

   P('qso_at').AsLargeInt := QSOTimeToUnixUTC(rec.tSysTime);
   BindText(P('callsign'), AnsiString(rec.Callsign));
   BindText(P('standard_call'), AnsiString(rec.QTH.StandardCall));
   P('freq_tx_hz').AsLargeInt := rec.Frequency;

   (* RX EQUALS TX AND SPLIT IS FALSE, because ContestExchange says nothing
     about either -- it carries ONE Frequency and no split state. That is
     the honest limit of the record rather than an assertion about the
     contact, and writing rx makes "what was I receiving on" answerable
     without every caller having to know about split. Live logging can do
     better, because the radio object knows; that arrives in Phase C with
     the other tier-3 facts. *)
   P('freq_rx_hz').AsLargeInt := rec.Frequency;
   P('is_split').AsInteger := 0;
   BindText(P('band'), BandToken(rec.Band));
   BindText(P('mode'), ModeToken(rec.Mode));
   BindText(P('submode'), ExtModeToken(rec.ExtMode));

   (* The received exchange as rendered. There is no sent counterpart in the
     record -- crosswalk finding 1. *)
   BindText(P('exchange_received'), AnsiString(rec.ExchString));

   (* INSERT ONLY, like qso_set_id: an update keeps what was sent -- see
     QSO_COLUMNS_UPDATABLE. *)
   if aInserting then
      begin
      BindText(P('exchange_sent'), FSentExchangeForNextSave);
      (* INSERT ONLY, the same rule: our station as it was for this QSO. *)
      BindMyFacts(aQuery, FMyFactsForNextSave);
      end;

   P('rst_sent').AsInteger := rec.RSTSent;
   P('rst_received').AsInteger := rec.RSTReceived;
   BindSerial(P('serial_sent'), rec.NumberSent);
   BindSerial(P('serial_received'), rec.NumberReceived);

   BindByte(P('rcvd_zone'), rec.Zone, DUMMYZONE);
   BindText(P('rcvd_name'), AnsiString(rec.Name));
   P('rcvd_age').AsInteger := rec.Age;
   P('rcvd_check').AsInteger := rec.Check;
   BindText(P('rcvd_precedence'), AnsiString(rec.Precedence));
   BindText(P('rcvd_class'), AnsiString(rec.ceClass));
   BindText(P('rcvd_power'), AnsiString(rec.Power));
   BindText(P('rcvd_chapter'), AnsiString(rec.Chapter));
   BindByte(P('rcvd_prefecture'), rec.Prefecture, MAXBYTE);
   BindWord(P('rcvd_member_no'), rec.TenTenNum, MAXWORD);

   (* THE POLYMORPHIC ONE. Stored as the literal it is; the contest factory
     decides later whether it was a grid, a section or a park. *)
   BindText(P('rcvd_qth'), AnsiString(rec.QTHString));

   BindText(P('rcvd_random'), AnsiString(rec.RandomCharsReceived));
   BindText(P('random_sent'), AnsiString(rec.RandomCharsSent));

   (* Kids is overloaded by record kind -- crosswalk. For a QTC it is the call
     inside the traffic, which is not the station in `callsign`. *)
   if rec.ceRecordKind in [rkQTCR, rkQTCS] then
      begin
      P('rcvd_kids').Clear;
      BindText(P('qtc_call'), AnsiString(rec.Kids));
      end
   else
      begin
      BindText(P('rcvd_kids'), AnsiString(rec.Kids));
      P('qtc_call').Clear;
      end;

   BindText(P('domestic_qth'), AnsiString(rec.DomesticQTH));

   (* CTY.DAT-derived, stored so a later CTY.DAT cannot rewrite history. *)
   BindText(P('dxcc_prefix'), AnsiString(rec.QTH.Prefix));
   BindText(P('dxcc_entity'), AnsiString(rec.QTH.CountryID));
   BindWord(P('dxcc_code'), rec.QTH.Country, UNKNOWN_COUNTRY);
   BindByte(P('cty_cq_zone'), rec.QTH.Zone, DUMMYZONE);
   (* THE INDEX IS CHECKED, NOT ASSUMED, AND THIS WAS A REAL CRASH.

     ContinentTypeSA is `array[ContinentType] of PAnsiChar` -- a POINTER table
     -- and the value indexing it arrives from a record read off disk. The
     guard below tested only for UnknownContinent, so ANY other out-of-range
     byte indexed past the end of the array, and AnsiString() then dereferenced
     whatever pointer-shaped bytes were there.

     Measured 2026-09-08: the same corpus QSO gives Continent = 1 on
     x86_64-linux and 86 on aarch64-darwin -- 86 being ASCII 'V', a
     neighbouring field's byte. On Linux and Windows index 86 landed in mapped
     memory and produced a wrong string in silence; on macOS it hit an unmapped
     page and took an EAccessViolation.

     SO THE UNDERLYING DEFECT IS THE RECORD LAYOUT, not this line -- see
     TestTheRecordHasTheSameFIELD_OFFSETSEverywhere. But a lookup table indexed
     by unvalidated file data should never have been unguarded on any platform:
     the silent wrong answer is the worse of the two outcomes, because a QSO
     stored with a garbage continent is a scoring error nobody sees.

     Out of range is stored as NULL -- the same as unknown, which is what it
     is -- and reported once so it cannot be mistaken for a clean import. *)
   if (rec.QTH.Continent = UnknownContinent) or
      (Ord(rec.QTH.Continent) > Ord(High(ContinentType))) then
      begin
      if rec.QTH.Continent <> UnknownContinent then
         begin
         (* COUNTED, NOT LOGGED, because this unit has NO LOGGER ON PURPOSE --
           it links into the test binary and must not drag MainUnit's globals
           in behind it. Reporting UPWARD keeps that property: the importer
           reads DecodeAnomalies when it finishes and says so once, with a
           count, instead of this unit either going silent or gaining a
           dependency it was designed without. *)
         Inc(FDecodeAnomalies);
         end;
      P('cty_continent').Clear;
      end
   else
      begin
      (* ContinentTypeSA, NOT tContinentArray.

        tContinentArray is the DISPLAY table: filled at run time by
        InitializeStringTables and TRANSLATABLE -- it used to hold the TC_C9_*
        constants. Using it here would have written blanks in any program that
        had not called InitializeStringTables (which is how the first
        round-trip test failed: every continent came back Unknown) and Spanish
        continent names in a Spanish build.

        A STORAGE TOKEN MUST NOT BE A DISPLAY STRING. ContinentTypeSA is the
        stable two-letter code -- 'NA', 'EU' -- which is also exactly what
        GetContinentFromString parses, so the pair round-trips by construction. *)
      P('cty_continent').AsString := AnsiString(ContinentTypeSA[rec.QTH.Continent]);
      end;

   (* The multiplier strings as counted, and the outcome flags. *)
   BindText(P('prefix_mult'), AnsiString(rec.Prefix));
   BindText(P('dx_mult'), AnsiString(rec.DXQTH));
   BindText(P('domestic_mult'), AnsiString(rec.DomMultQTH));
   BindBool(P('mult_domestic'), rec.DomesticMult);
   BindBool(P('mult_dx'), rec.DXMult);
   BindBool(P('mult_prefix'), rec.PrefixMult);
   BindBool(P('mult_zone'), rec.ZoneMult);
   BindBool(P('inhibit_mults'), rec.InhibitMults);

   P('qso_points').AsInteger := rec.QSOPoints;
   BindBool(P('is_dupe'), rec.ceDupe);

   (* INVERTED. is_run is the opposite of ceSearchAndPounce, and a straight copy
     would be wrong in a way nothing reports. *)
   BindBool(P('is_run'), not rec.ceSearchAndPounce);

   BindBool(P('is_xqso'), rec.ceXQSO);
   (* is_skipped IS WRITTEN AS FALSE AND NEVER READ BACK INTO ITS OWN FIELD.
     The column stays because dropping it is a schema migration for a fact
     nothing consumes; what it MEANT is now ceQSO_Deleted, and the reader folds
     any historical 1 into that. See ceQSO_Skiped in VC.pas. *)
   BindBool(P('is_skipped'), False);
   BindBool(P('sent_in_qtc'), rec.ceWasSendInQTC);
   BindBool(P('name_sent'), rec.NameSent);
   BindBool(P('mp3_recorded'), rec.MP3Record);
   BindBool(P('clear_dupe_sheet'), rec.ceClearDupeSheet);
   BindBool(P('clear_mult_sheet'), rec.ceClearMultSheet);

   P('radio_nr').AsInteger := Ord(rec.ceRadio);
   BindText(P('operator_call'), CharBufferBytes(rec.ceOperator));
   BindBool(P('deleted'), rec.ceQSO_Deleted);
   BindBool(P('sent_to_server'), rec.ceSendToServer);
   BindBool(P('server_dirty'), rec.ceNeedSendToServerAE);

   if aQso.ceRecordKind = rkNote then
      begin
      BindText(P('notes'), NoteText(aQso));
      (* callsign IS NOT NULL, and BindText stores '' as NULL -- right for
        every optional column and wrong here. A note has no callsign; say
        so with an empty one rather than fail the insert. *)
      P('callsign').AsString := '';
      end
   else
      begin
      P('notes').Clear;
      end;
end;

procedure TLogRepository.BindRecord(const aQso: ContestExchange;
                                    const aGuid: AnsiString);
begin
   BindInto(FInsert, aQso, aGuid, True);
end;

procedure TLogRepository.BindUpdate(const aQso: ContestExchange);
begin
   BindInto(FUpdate, aQso, '', False);
end;

procedure TLogRepository.BindMyFacts(aQuery: TSQLQuery;
                                     const aFacts: TQsoMyFacts);

   function P(const aName: AnsiString): TParam;
   begin
      Result := aQuery.ParamByName(aName);
   end;

   (* 0 is "unknown" for a zone, and unknown is NULL -- never zone 0. *)
   procedure BindZone(aParam: TParam; aZone: integer);
   begin
      if aZone > 0 then
         begin
         aParam.AsInteger := aZone;
         end
      else
         begin
         aParam.Clear;
         end;
   end;

begin
   (* NOT CAPTURED IS NULL IN EVERY COLUMN, my_source included -- the shape a
     row written before schema 3 has, so a reader cannot tell the two apart
     and does not need to: both fall back to the session. Bound from the
     zero record, which is exactly that. *)
   BindText(P('my_county'), aFacts.County);
   BindText(P('my_grid'), aFacts.Grid);
   BindText(P('my_state'), aFacts.State);
   BindText(P('my_call'), aFacts.Call);
   BindText(P('my_section'), aFacts.Section);
   BindText(P('my_park'), aFacts.Park);
   BindText(P('my_iota'), aFacts.Iota);
   BindText(P('my_country'), aFacts.Country);
   BindText(P('my_continent'), aFacts.Continent);
   BindZone(P('my_cq_zone'), aFacts.CQZone);
   BindZone(P('my_itu_zone'), aFacts.ITUZone);
   (* '' for mfsNotCaptured, which BindText stores as NULL. *)
   BindText(P('my_source'), MyFactsSourceToken(aFacts.Source));
end;

procedure TLogRepository.ReadMyFacts(aQuery: TSQLQuery; out aFacts: TQsoMyFacts);

   function F(aColumn: TQsoColumn): TField;
   begin
      Result := aQuery.Fields[Ord(aColumn)];
   end;

   function S(aColumn: TQsoColumn): AnsiString;
   begin
      if F(aColumn).IsNull then
         begin
         Result := '';
         end
      else
         begin
         Result := AnsiString(F(aColumn).AsString);
         end;
   end;

   function Z(aColumn: TQsoColumn): integer;
   begin
      if F(aColumn).IsNull then
         begin
         Result := 0;
         end
      else
         begin
         Result := F(aColumn).AsInteger;
         end;
   end;

begin
   aFacts := NotCapturedMyFacts;
   aFacts.Source := TokenToMyFactsSource(S(qc_my_source));
   (* A ROW NEVER CAPTURED holds nothing to read -- and if a hand edit put a
     value in one of its columns without a source, that value has no
     provenance and is not reported as ours. *)
   if aFacts.Source = mfsNotCaptured then
      begin
      Exit;
      end;

   aFacts.County := S(qc_my_county);
   aFacts.Grid := S(qc_my_grid);
   aFacts.State := S(qc_my_state);
   aFacts.Call := S(qc_my_call);
   aFacts.Section := S(qc_my_section);
   aFacts.Park := S(qc_my_park);
   aFacts.Iota := S(qc_my_iota);
   aFacts.Country := S(qc_my_country);
   aFacts.Continent := S(qc_my_continent);
   aFacts.CQZone := Z(qc_my_cq_zone);
   aFacts.ITUZone := Z(qc_my_itu_zone);
end;

(* PRECONDITION: aQuery was opened by OpenQsoReader, so its fields are
  QSO_COLUMNS in order and Fields[Ord(c)] IS column c. That is checked once per
  Open rather than here, once per row.

  NEVER aQuery.FieldByName IN HERE. See TQsoColumn: a linear, case-folding
  scan per field per row was nineteen-twentieths of this routine's cost. *)
procedure TLogRepository.ReadRecord(aQuery: TSQLQuery; out aQso: ContestExchange);
var
   continentToken: Str20;
   token: AnsiString;

   function F(aColumn: TQsoColumn): TField;
   begin
      Result := aQuery.Fields[Ord(aColumn)];
   end;

   function S(aColumn: TQsoColumn): AnsiString;
   var
      field: TField;
   begin
      field := F(aColumn);
      if field.IsNull then
         begin
         Result := '';
         end
      else
         begin
         Result := AnsiString(field.AsString);
         end;
   end;

begin
   (* EVERY read starts from ClearContestExchange's shape, so a column this unit
     does not restore holds the same "not set" marker the program expects rather
     than a zero that looks like data. *)
   FillChar(aQso, SizeOf(aQso), 0);
   aQso.Band := NoBand;
   aQso.Mode := NoMode;
   aQso.ExtMode := eNoMode;
   aQso.NumberReceived := -1;
   aQso.NumberSent := -1;
   aQso.Prefecture := MAXBYTE;
   aQso.QTH.Zone := DUMMYZONE;
   aQso.Zone := DUMMYZONE;
   aQso.QTH.Continent := UnknownContinent;
   aQso.QTH.Country := UNKNOWN_COUNTRY;
   aQso.TenTenNum := MAXWORD;

   aQso.id := S(qc_exchange_id);
   aQso.ceQSOID1 := Cardinal(F(qc_session_id).AsLargeInt);
   aQso.ceQSOID2 := Cardinal(F(qc_session_seq).AsLargeInt);
   (* A single character out of a text column. Indexing a managed string is
     ordinary Pascal -- what this tree is removing is taking its ADDRESS. Read
     once into a local so the guard and the use cannot disagree. *)
   token := S(qc_computer_id);
   if token <> '' then
      begin
      aQso.ceComputerID := token[1];
      end;
   aQso.ceOperatorID := byte(F(qc_operator_id).AsInteger);
   aQso.ceRecordKind := TokenToRecordKind(S(qc_record_kind));

   (* FROM THE CONTEST ROW, not from the QSO row -- see SetContest. Without this
     every loaded QSO reports DUMMYCONTEST and exports as the wrong contest. *)
   aQso.ceContest := FContest;

   aQso.tSysTime := UnixUTCToQSOTime(F(qc_qso_at).AsLargeInt);
   aQso.Callsign := S(qc_callsign);
   aQso.QTH.StandardCall := S(qc_standard_call);
   aQso.Frequency := F(qc_freq_tx_hz).AsLargeInt;

   (* GetADIFBand IS the inverse of ADIFBANDSTRINGSARRAY -- it scans that very
     array -- so it is the right routine and there is no second table. *)
   aQso.Band := GetADIFBand(string(S(qc_band)));
   aQso.Mode := TokenToMode(S(qc_mode));
   aQso.ExtMode := TokenToExtMode(S(qc_submode));

   aQso.ExchString := S(qc_exchange_received);

   aQso.RSTSent := F(qc_rst_sent).AsInteger;
   aQso.RSTReceived := F(qc_rst_received).AsInteger;
   aQso.NumberSent := FieldSerial(F(qc_serial_sent));
   aQso.NumberReceived := FieldSerial(F(qc_serial_received));

   aQso.Zone := FieldByte(F(qc_rcvd_zone), DUMMYZONE);
   aQso.Name := S(qc_rcvd_name);
   aQso.Age := byte(F(qc_rcvd_age).AsInteger);
   aQso.Check := byte(F(qc_rcvd_check).AsInteger);
   token := S(qc_rcvd_precedence);
   if token <> '' then
      begin
      aQso.Precedence := token[1];
      end;
   aQso.ceClass := S(qc_rcvd_class);
   aQso.Power := S(qc_rcvd_power);
   aQso.Chapter := S(qc_rcvd_chapter);
   aQso.Prefecture := FieldByte(F(qc_rcvd_prefecture), MAXBYTE);
   aQso.TenTenNum := FieldWord(F(qc_rcvd_member_no), MAXWORD);
   aQso.QTHString := S(qc_rcvd_qth);
   aQso.RandomCharsReceived := S(qc_rcvd_random);
   aQso.RandomCharsSent := S(qc_random_sent);

   if aQso.ceRecordKind in [rkQTCR, rkQTCS] then
      begin
      aQso.Kids := S(qc_qtc_call);
      end
   else
      begin
      aQso.Kids := S(qc_rcvd_kids);
      end;

   aQso.DomesticQTH := S(qc_domestic_qth);

   aQso.QTH.Prefix := S(qc_dxcc_prefix);
   aQso.QTH.CountryID := S(qc_dxcc_entity);
   aQso.QTH.Country := FieldWord(F(qc_dxcc_code), UNKNOWN_COUNTRY);
   aQso.QTH.Zone := FieldByte(F(qc_cty_cq_zone), DUMMYZONE);
   if S(qc_cty_continent) <> '' then
      begin
      begin
      continentToken := S(qc_cty_continent);
      aQso.QTH.Continent := GetContinentFromString(continentToken);
      end;
      end;

   aQso.Prefix := S(qc_prefix_mult);
   aQso.DXQTH := S(qc_dx_mult);
   aQso.DomMultQTH := S(qc_domestic_mult);
   aQso.DomesticMult := FieldBool(F(qc_mult_domestic));
   aQso.DXMult := FieldBool(F(qc_mult_dx));
   aQso.PrefixMult := FieldBool(F(qc_mult_prefix));
   aQso.ZoneMult := FieldBool(F(qc_mult_zone));
   aQso.InhibitMults := FieldBool(F(qc_inhibit_mults));

   aQso.QSOPoints := word(F(qc_qso_points).AsInteger);
   aQso.ceDupe := FieldBool(F(qc_is_dupe));
   aQso.ceSearchAndPounce := not FieldBool(F(qc_is_run));
   aQso.ceXQSO := FieldBool(F(qc_is_xqso));
   (* NEVER POPULATED FROM THE DATABASE. What this column meant is folded
     into ceQSO_Deleted below -- see ceQSO_Skiped in VC.pas. *)
   aQso.ceQSO_Skiped := False;
   aQso.ceWasSendInQTC := FieldBool(F(qc_sent_in_qtc));
   aQso.NameSent := FieldBool(F(qc_name_sent));
   aQso.MP3Record := FieldBool(F(qc_mp3_recorded));
   aQso.ceClearDupeSheet := FieldBool(F(qc_clear_dupe_sheet));
   aQso.ceClearMultSheet := FieldBool(F(qc_clear_mult_sheet));

   aQso.ceRadio := RadioType(F(qc_radio_nr).AsInteger);
   AnsiToCharArray(aQso.ceOperator, S(qc_operator_call));
   (* THE LEGACY FOLD, AND IT HAS TO BE HERE RATHER THAN WHERE is_skipped IS
     READ, thirteen lines above: `deleted` is not in aQso yet at that point, so
     an OR there would be against a stale value and this line would then
     overwrite it. A database written before the unification can carry
     is_skipped = 1 on a row whose deleted is 0 -- those QSOs would come back
     UNDELETED without this. *)
   aQso.ceQSO_Deleted := FieldBool(F(qc_deleted)) or FieldBool(F(qc_is_skipped));
   aQso.ceSendToServer := FieldBool(F(qc_sent_to_server));
   aQso.ceNeedSendToServerAE := FieldBool(F(qc_server_dirty));

   (* A NOTE'S TEXT GOES BACK INTO THE LAYOUT IT WAS WRITTEN IN. Every field
     above was read by its type, and for a note those fields were bound
     from a cleared region -- so this restores exactly the record
     tr4w_add_note_in_log produced, and every reader sees what it always
     saw. *)
   if aQso.ceRecordKind = rkNote then
      begin
      SetNoteText(aQso, S(qc_notes));
      end;
end;

function TLogRepository.SaveQSO(const aQso: ContestExchange): Int64;
begin
   FLastGuid := NewRowGuid(aQso);

   if FSetIdForNextSave <> '' then
      begin
      FLastSetId := FSetIdForNextSave;
      end
   else
      begin
      (* A set of one, named by the row itself. *)
      FLastSetId := FLastGuid;
      end;

   BindRecord(aQso, FLastGuid);
   ExecuteKeptWrite(FInsert);
   InvalidateRecordCount;

   (* CLEARED IMMEDIATELY, BOTH OF THEM. A sticky set id would quietly pull the next
     unrelated QSO into this contact, and an ADIF export would then merge two
     contacts into one record -- visible to nobody until a park credit went
     missing. A sticky sent exchange would attribute one QSO's exchange to
     the next -- the same class of error against a different column. *)
   FSetIdForNextSave := '';
   FSentExchangeForNextSave := '';
   (* And our station: one QSO's facts must not be the next one's. *)
   FMyFactsForNextSave := NotCapturedMyFacts;

   Result := LastInsertedRowId;
end;

procedure TLogRepository.LoadContest;
var
   q: TSQLQuery;
   token: ShortString;
begin
   FContest := NoContest;
   FStartTime := 0;
   FDeclaredCall := '';
   q := NewReadQuery;
   try
      q.SQL.Text := 'SELECT contest_type, start_time, my_call FROM contest WHERE id = 1';
      q.Open;
      if not q.EOF then
         begin
         (* NULL, or a zero a writer left, is "not recorded" -- never
            1 January 1970. *)
         if (not q.Fields[1].IsNull) and
            (q.Fields[1].AsLargeInt > 0) then
            begin
            FStartTime := UnixToDateTime(q.Fields[1].AsLargeInt);
            end;
         if not q.Fields[2].IsNull then
            begin
            FDeclaredCall := AnsiString(q.Fields[2].AsString);
            end;
         token := q.Fields[0].AsString;
         (* ContestFromName reads the registry's ids (uContestNames), and
           SetContest writes ContestId, so the pair are inverses for every
           current spelling -- AND it reads a
           LEGACY name too: a New England log written before 2026-10-16
           stores 'NEQP', which still means NEWENGLANDQSO (never Nebraska).
           The row is not rewritten here; it is read as it stands. *)
         FContest := ContestFromName(token);
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

function TLogRepository.SetEntryDeclaration(
   const aDeclaration: TLogEntryDeclaration): boolean;
var
   q: TSQLQuery;
begin
   Result := False;
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FDatabase.Connection;
      (* An UPDATE, not an upsert: SetContest creates the row, and a
         declaration without a contest is not a state this program can reach.
         If the row is missing, RowsAffected is 0 and nothing is invented. *)
      q.SQL.Text :=
         'UPDATE contest SET my_call = :my_call, my_park = :my_park, ' +
         'category_operator = :cat_op, category_assisted = :cat_asst, ' +
         'category_power = :cat_pwr, category_band = :cat_band, ' +
         'category_mode = :cat_mode, category_station = :cat_stn, ' +
         'category_time = :cat_time, category_transmitter = :cat_tx, ' +
         'category_overlay = :cat_ovl, club = :club, soapbox = :soapbox, ' +
         'op_name = :op_name, address = :address, city = :city, ' +
         'state = :state, postcode = :postcode, country = :country, ' +
         'email = :email WHERE id = 1';
      q.ParamByName('my_call').AsString := aDeclaration.MyCall;
      q.ParamByName('my_park').AsString := aDeclaration.MyPark;
      q.ParamByName('cat_op').AsString := aDeclaration.CategoryOperator;
      q.ParamByName('cat_asst').AsString := aDeclaration.CategoryAssisted;
      q.ParamByName('cat_pwr').AsString := aDeclaration.CategoryPower;
      q.ParamByName('cat_band').AsString := aDeclaration.CategoryBand;
      q.ParamByName('cat_mode').AsString := aDeclaration.CategoryMode;
      q.ParamByName('cat_stn').AsString := aDeclaration.CategoryStation;
      q.ParamByName('cat_time').AsString := aDeclaration.CategoryTime;
      q.ParamByName('cat_tx').AsString := aDeclaration.CategoryTransmitter;
      q.ParamByName('cat_ovl').AsString := aDeclaration.CategoryOverlay;
      q.ParamByName('club').AsString := aDeclaration.Club;
      q.ParamByName('soapbox').AsString := aDeclaration.Soapbox;
      q.ParamByName('op_name').AsString := aDeclaration.OpName;
      q.ParamByName('address').AsString := aDeclaration.Address;
      q.ParamByName('city').AsString := aDeclaration.City;
      q.ParamByName('state').AsString := aDeclaration.State;
      q.ParamByName('postcode').AsString := aDeclaration.Postcode;
      q.ParamByName('country').AsString := aDeclaration.Country;
      q.ParamByName('email').AsString := aDeclaration.Email;
      q.ExecSQL;
      Result := q.RowsAffected > 0;
      if Result then
         begin
         FDeclaredCall := aDeclaration.MyCall;
         end;
   finally
      q.Free;
   end;
end;

procedure TLogRepository.SaveConfigValue(const aCommand, aValue,
                                         aSource: AnsiString);
var
   q: TSQLQuery;
begin
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FDatabase.Connection;
      (* ON CONFLICT rather than a SELECT-then-INSERT-or-UPDATE: the command is
         the primary key, so SQLite already knows how to decide, and doing it in
         one statement means a capture cannot half-apply. *)
      q.SQL.Text :=
         'INSERT INTO config (command, value, source, set_at) ' +
         'VALUES (:command, :value, :source, :set_at) ' +
         'ON CONFLICT(command) DO UPDATE SET ' +
         '  value = excluded.value, ' +
         '  source = excluded.source, ' +
         '  set_at = excluded.set_at';
      q.ParamByName('command').AsString := aCommand;
      q.ParamByName('value').AsString := aValue;
      q.ParamByName('source').AsString := aSource;
      q.ParamByName('set_at').AsLargeInt := UnixNowUTC;
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

procedure TLogRepository.DeleteConfigValue(const aCommand: AnsiString);
var
   q: TSQLQuery;
begin
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FDatabase.Connection;
      q.SQL.Text := 'DELETE FROM config WHERE command = :command';
      q.ParamByName('command').AsString := aCommand;
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

procedure TLogRepository.SaveSessionValue(const aKey, aValue: AnsiString);
var
   q: TSQLQuery;
begin
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FDatabase.Connection;
      (* ON CONFLICT, for the reason SaveConfigValue gives: the key decides,
        and one statement cannot half-apply. *)
      q.SQL.Text :=
         'INSERT INTO session_state (key, value, saved_at) ' +
         'VALUES (:key, :value, :saved_at) ' +
         'ON CONFLICT(key) DO UPDATE SET ' +
         '  value = excluded.value, ' +
         '  saved_at = excluded.saved_at';
      q.ParamByName('key').AsString := aKey;
      q.ParamByName('value').AsString := aValue;
      q.ParamByName('saved_at').AsLargeInt := UnixNowUTC;
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

function TLogRepository.SessionValue(const aKey: AnsiString;
                                     const aDefault: AnsiString = ''): AnsiString;
var
   q: TSQLQuery;
begin
   Result := aDefault;
   q := NewReadQuery;
   try
      q.SQL.Text := 'SELECT value FROM session_state WHERE key = :key';
      q.ParamByName('key').AsString := aKey;
      q.Open;
      if not q.EOF then
         begin
         Result := q.Fields[0].AsAnsiString;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

procedure TLogRepository.SaveMessage(const aKind, aMode, aKeyId, aText,
                                     aCaption: AnsiString; aEdited: boolean = False);
var
   q: TSQLQuery;
begin
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FDatabase.Connection;
      q.SQL.Text :=
         'INSERT INTO message (kind, mode, key_id, text, caption, edited) ' +
         'VALUES (:kind, :mode, :key_id, :text, :caption, :edited) ' +
         'ON CONFLICT(kind, mode, key_id) DO UPDATE SET ' +
         '  text = excluded.text, ' +
         '  caption = excluded.caption, ' +
         '  edited = excluded.edited';
      q.ParamByName('kind').AsString := aKind;
      q.ParamByName('mode').AsString := aMode;
      q.ParamByName('key_id').AsString := aKeyId;
      q.ParamByName('text').AsString := aText;
      q.ParamByName('caption').AsString := aCaption;
      q.ParamByName('edited').AsInteger := Ord(aEdited);
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

procedure TLogRepository.DeleteAllMessages;
var
   q: TSQLQuery;
begin
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FDatabase.Connection;
      q.SQL.Text := 'DELETE FROM message';
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

procedure TLogRepository.LoadEditedMessages(aInto: TObjectList);
var
   q: TSQLQuery;
   row: TLogStoredMessage;
begin
   if aInto = nil then
      begin
      Exit;
      end;
   aInto.Clear;

   q := NewReadQuery;
   try
      (* caption is nullable; IFNULL so a NULL reads as the empty caption the
         program holds for "none". *)
      q.SQL.Text := 'SELECT kind, mode, key_id, text, IFNULL(caption, '''') ' +
                    'FROM message WHERE edited = 1 ' +
                    'ORDER BY kind, mode, key_id';
      q.Open;
      while not q.EOF do
         begin
         row := TLogStoredMessage.Create;
         aInto.Add(row);
         row.Kind    := q.Fields[0].AsAnsiString;
         row.Mode    := q.Fields[1].AsAnsiString;
         row.KeyId   := q.Fields[2].AsAnsiString;
         row.Text    := q.Fields[3].AsAnsiString;
         row.Caption := q.Fields[4].AsAnsiString;
         q.Next;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

(* THE WHOLE STATEMENT, not a table name to splice in.

  It took a table name and concatenated it first. That is a worse shape for two
  independent reasons: a table name cannot be bound as a parameter, so the only
  safe form is a literal anyway -- and the concatenation itself narrowed, since
  the literal is a UnicodeString and SQL.Text here is not, which cost a
  ratchet slot for nothing. Passing the finished statement removes both. *)
function TLogRepository.CountRows(const aSQL: AnsiString): integer;
var
   q: TSQLQuery;
begin
   Result := 0;
   q := NewReadQuery;
   try
      q.SQL.Text := aSQL;
      q.Open;
      if not q.EOF then
         begin
         Result := q.Fields[0].AsInteger;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

procedure TLogRepository.LoadContestConfig(aInto: TStrings);
var
   q: TSQLQuery;
begin
   if aInto = nil then
      begin
      Exit;
      end;
   aInto.Clear;

   q := NewReadQuery;
   try
      q.SQL.Text := 'SELECT command, value FROM config ' +
                    (* OR command = 'CONTEST', because a log written before
                       2026-09-03 stored it as a STATION setting -- the capture
                       only marked a row contest-scoped if a .cfg had supplied
                       it, and a contest created by the New Contest dialog has
                       no .cfg. Such a log reopens with Contest = DUMMYCONTEST
                       and ActiveExchange = UnknownExchange, and NO QSO CAN BE
                       LOGGED. Guarding only the writer would leave every log
                       written before today permanently unusable. *)

                    'WHERE source = ''contest'' OR command = ''CONTEST'' ' +

                    'ORDER BY command';
      q.Open;
      while not q.EOF do
         begin
         (* NameValueSeparator is '=', which is also what a .cfg line uses --
            so a value containing one would split wrongly. It cannot here: the
            name comes from a column, not from parsing. *)
         aInto.Add(q.Fields[0].AsString + '=' + q.Fields[1].AsString);
         q.Next;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

function TLogRepository.ConfigCount: integer;
begin
   Result := CountRows('SELECT COUNT(*) FROM config');
end;

function TLogRepository.MessageCount: integer;
begin
   Result := CountRows('SELECT COUNT(*) FROM message');
end;

function TLogRepository.LogContest: TContestHandle;
begin
   Result := FContest;
end;

function TLogRepository.DeclaredCall: AnsiString;
begin
   Result := FDeclaredCall;
end;

function TLogRepository.LogStartTime: TDateTime;
begin
   Result := FStartTime;
end;

procedure TLogRepository.SetContest(aContest: TContestHandle);
var
   q: TSQLQuery;
   token: AnsiString;
   friendly: AnsiString;
begin
   FContest := aContest;
   token := AnsiString(ContestId(aContest));

   (* Asked of the contest -- M1. Its FriendlyName already falls back to the
      enum spelling, which is the rule this used to restate. *)
   friendly := AnsiString(ContestIdentity(aContest).FriendlyName);

   q := TSQLQuery.Create(nil);
   try
      q.DataBase := FDatabase.Connection;
      (* ONE ROW, enforced by the schema's CHECK (id = 1). Written or replaced,
        so setting it twice is not an error -- an import discovers the contest
        from the first record and would otherwise have to know whether it had
        already said so. *)
      q.SQL.Text :=
         'INSERT INTO contest (id, guid, contest_type, contest_name, ' +
         'created_at, my_call) VALUES (1, :guid, :ct, :cn, :created, :call) ' +
         'ON CONFLICT(id) DO UPDATE SET contest_type = :ct2, contest_name = :cn2';
      q.ParamByName('guid').AsString := NewUUIDv7(0);
      q.ParamByName('ct').AsString := token;
      q.ParamByName('cn').AsString := friendly;
      q.ParamByName('created').AsLargeInt := UnixNowUTC;
      (* MY CALL IS NOT IN THE BINARY LOG. The record carries ceOperator, which
        is the OPERATOR and is not the same thing at a multi-op station, so
        guessing would be worse than leaving it empty. Phase E fills it from
        the contest configuration. *)
      q.ParamByName('call').AsString := '';
      q.ParamByName('ct2').AsString := token;
      q.ParamByName('cn2').AsString := friendly;
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

(* MAX(id), NOT last_insert_rowid(), AND THE DIFFERENCE WAS A DEFECT.

  They answer different questions. last_insert_rowid() is "the row THIS
  CONNECTION just inserted" -- right for SaveQSO, and ZERO on a connection that
  has not inserted anything yet. NewestRowId is what DeleteLastContact and the
  other "seek back one record" sites ask, and the first thing a restarted
  session might do is delete the last contact of a log it has just opened.
  Written the first way, that would have silently done nothing.

  MAX(id) is right here because rows are never hard-deleted -- `deleted` is a
  flag -- so the newest row stays the newest. *)
function TLogRepository.NewestRowId: Int64;
var
   q: TSQLQuery;
begin
   Result := 0;
   q := NewReadQuery;
   try
      q.SQL.Text := 'SELECT MAX(id) FROM qso';
      q.Open;
      if (not q.EOF) and (not q.Fields[0].IsNull) then
         begin
         Result := q.Fields[0].AsLargeInt;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

(* The row THIS connection just inserted, which is what SaveQSO must return even
  if another connection has since added rows. *)
function TLogRepository.LastInsertedRowId: Int64;
var
   q: TSQLQuery;
begin
   Result := 0;
   q := NewReadQuery;
   try
      q.SQL.Text := 'SELECT last_insert_rowid()';
      q.Open;
      if not q.EOF then
         begin
         Result := q.Fields[0].AsLargeInt;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

function TLogRepository.ReadRange(aFirstIndex: Int64;
                                  var aRows: array of ContestExchange): integer;
var
   want: integer;
begin
   Result := 0;
   want := Length(aRows);
   if (aFirstIndex < 0) or (want <= 0) then
      begin
      Exit;
      end;

   FSelectRange.Close;
   FSelectRange.ParamByName('n').AsInteger := want;
   FSelectRange.ParamByName('m').AsLargeInt := aFirstIndex;
   OpenQsoReader(FSelectRange);
   try
      while (not FSelectRange.EOF) and (Result < want) do
         begin
         ReadRecord(FSelectRange, aRows[Low(aRows) + Result]);
         Inc(Result);
         FSelectRange.Next;
         end;
   finally
      FSelectRange.Close;
   end;
end;

function TLogRepository.RowIdAtIndex(aIndex: Int64): Int64;
begin
   Result := 0;
   if aIndex < 0 then
      begin
      Exit;
      end;

   FRowIdAtIndex.Close;
   FRowIdAtIndex.ParamByName('n').AsLargeInt := aIndex;
   FRowIdAtIndex.Open;
   try
      if not FRowIdAtIndex.EOF then
         begin
         Result := FRowIdAtIndex.Fields[0].AsLargeInt;
         end;
   finally
      (* Closed at once, as the per-call query was freed: an open result set
        would hold a read transaction for as long as the repository lives. *)
      FRowIdAtIndex.Close;
   end;
end;

function TLogRepository.UpdateQSOBySessionIds(aSessionId, aSessionSeq: Int64;
                                              const aQso: ContestExchange): boolean;
var
   rowId: Int64;
   q: TSQLQuery;
begin
   Result := False;

   (* THE GUARD IS THE POINT. (0, 0) is what ceQSOID1/ceQSOID2 hold on every QSO
     that did not go through the network path, which is nearly all of them.
     Without this, one edited record would overwrite the whole log. *)
   if (aSessionId = 0) and (aSessionSeq = 0) then
      begin
      Exit;
      end;

   rowId := 0;
   q := NewReadQuery;
   try
      q.SQL.Text := 'SELECT id FROM qso WHERE session_id = :sid ' +
                    'AND session_seq = :sseq ORDER BY id DESC LIMIT 1';
      q.ParamByName('sid').AsLargeInt := aSessionId;
      q.ParamByName('sseq').AsLargeInt := aSessionSeq;
      q.Open;
      if not q.EOF then
         begin
         rowId := q.Fields[0].AsLargeInt;
         end;
      q.Close;
   finally
      q.Free;
   end;

   if rowId = 0 then
      begin
      Exit;
      end;

   Result := UpdateQSO(rowId, aQso);
end;

procedure TLogRepository.InvalidateRecordCount;
begin
   FRecordCount := -1;
end;

(* CACHED, because it was being asked once per painted row for a bounds check
  and it is a full table scan. Only an INSERT can change it. *)
function TLogRepository.RecordCount: Int64;
var
   q: TSQLQuery;
begin
   if FRecordCount >= 0 then
      begin
      Result := FRecordCount;
      Exit;
      end;

   Result := 0;
   q := NewReadQuery;
   try
      q.SQL.Text := 'SELECT COUNT(*) FROM qso';
      q.Open;
      Result := q.Fields[0].AsLargeInt;
      q.Close;
   finally
      q.Free;
   end;

   FRecordCount := Result;
end;

function TLogRepository.UpdateQSO(aRowId: Int64;
                                  const aQso: ContestExchange): boolean;
begin
   BindUpdate(aQso);
   FUpdate.ParamByName('row_id').AsLargeInt := aRowId;
   ExecuteKeptWrite(FUpdate);

   (* RowsAffected distinguishes "changed it" from "there was no such row", which
     is the difference between an edit and a silent no-op. The file-based code
     cannot tell those apart -- it seeks and writes -- so this is one thing the
     database does better rather than merely differently. *)
   Result := FUpdate.RowsAffected > 0;
end;

function TLogRepository.SaveQSOGroupingByExchangeId(
   const aQso: ContestExchange): Int64;
var
   thisId: AnsiString;
   existing: AnsiString;
   q: TSQLQuery;
begin
   thisId := AnsiString(aQso.id);

   (* ASKED OF THE DATABASE, not remembered from the previous save.

     The first version compared against the last exchange id this instance had
     written, on the reasoning that a county line is logged consecutively. True,
     and not enough: the FIRST QSO of a session is grouped inside the importer's
     repository during the shadow rebuild, and the SECOND arrives at a freshly
     constructed one that remembers nothing. Measured on the live county-line
     harness -- two rows that should have been one contact came back as two
     sets, and only COUNT(DISTINCT) showed it, because two UUIDv7 values minted
     in the same millisecond share a long prefix and looked identical when
     truncated for display.

     One indexed lookup is also simply more correct: same exchange means same
     contact whether or not the rows were written consecutively, or by the same
     object, or in the same session. *)
   if thisId <> '' then
      begin
      existing := '';
      q := NewReadQuery;
      try
         q.SQL.Text := 'SELECT qso_set_id FROM qso WHERE exchange_id = :x ' +
                       'ORDER BY id DESC LIMIT 1';
         q.ParamByName('x').AsString := thisId;
         q.Open;
         if not q.EOF then
            begin
            existing := AnsiString(q.Fields[0].AsString);
            end;
         q.Close;
      finally
         q.Free;
      end;

      if existing <> '' then
         begin
         SetNextQSOSet(existing);
         end;
      end;

   Result := SaveQSO(aQso);
end;

procedure TLogRepository.SetNextQSOSet(const aSetId: AnsiString);
begin
   FSetIdForNextSave := aSetId;
end;

procedure TLogRepository.SetNextSentExchange(const aSentExchange: AnsiString);
begin
   FSentExchangeForNextSave := aSentExchange;
end;

procedure TLogRepository.SetNextMyFacts(const aFacts: TQsoMyFacts);
begin
   FMyFactsForNextSave := aFacts;
end;

function TLogRepository.UpdateQSOMyFacts(aRowId: Int64;
                                         const aFacts: TQsoMyFacts): boolean;
begin
   BindMyFacts(FUpdateMyFacts, aFacts);
   FUpdateMyFacts.ParamByName('row_id').AsLargeInt := aRowId;
   ExecuteKeptWrite(FUpdateMyFacts);
   Result := FUpdateMyFacts.RowsAffected > 0;
end;

function TLogRepository.LoadQSOMyFacts(aRowId: Int64;
                                       out aFacts: TQsoMyFacts): boolean;
begin
   FSelectById.Close;
   FSelectById.ParamByName('row_id').AsLargeInt := aRowId;
   OpenQsoReader(FSelectById);
   Result := not FSelectById.EOF;
   if Result then
      begin
      ReadMyFacts(FSelectById, aFacts);
      end
   else
      begin
      aFacts := NotCapturedMyFacts;
      end;
   FSelectById.Close;
end;

function TLogRepository.RelatedRowIds(aRowId: Int64): TInt64Array;
var
   q: TSQLQuery;
   n: integer;
begin
   SetLength(Result, 0);
   n := 0;

   q := NewReadQuery;
   try
      (* The set is read from the row itself rather than passed in, so a caller
        holding only a row id can ask. *)
      q.SQL.Text := 'SELECT id FROM qso WHERE qso_set_id = ' +
                    '(SELECT qso_set_id FROM qso WHERE id = :row_id) ' +
                    'AND id <> :row_id2 ORDER BY id';
      q.ParamByName('row_id').AsLargeInt := aRowId;
      q.ParamByName('row_id2').AsLargeInt := aRowId;
      q.Open;
      while not q.EOF do
         begin
         SetLength(Result, n + 1);
         Result[n] := q.Fields[0].AsLargeInt;
         Inc(n);
         q.Next;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

function TLogRepository.ImportQSOByGuid(const aGuid: AnsiString;
                                       const aQso: ContestExchange;
                                       out aWasNew: boolean): Int64;
var
   q: TSQLQuery;
begin
   Result := 0;
   aWasNew := False;

   if aGuid = '' then
      begin
      (* No identity means nothing to match on. Appending is the only honest
        answer -- silently merging records that merely look alike is how an
        import loses a QSO. *)
      aWasNew := True;
      Result := SaveQSO(aQso);
      Exit;
      end;

   q := NewReadQuery;
   try
      q.SQL.Text := 'SELECT id FROM qso WHERE guid = :guid';
      q.ParamByName('guid').AsString := aGuid;
      q.Open;
      if not q.EOF then
         begin
         Result := q.Fields[0].AsLargeInt;
         end;
      q.Close;
   finally
      q.Free;
   end;

   if Result <> 0 then
      begin
      UpdateQSO(Result, aQso);
      Exit;
      end;

   (* New to this log, and it keeps the guid it arrived with -- that is the whole
     point. SaveQSO mints one instead, so it cannot be used here. *)
   aWasNew := True;
   FLastGuid := aGuid;
   BindRecord(aQso, aGuid);
   ExecuteKeptWrite(FInsert);
   InvalidateRecordCount;
   (* Our station is per QSO, as in SaveQSO -- never carried to the next. *)
   FMyFactsForNextSave := NotCapturedMyFacts;
   Result := LastInsertedRowId;
end;

procedure TLogRepository.OpenSequentialRead;
begin
   CloseSequentialRead;
   FCursor := NewReadQuery;
   (* THE SAME QSO_COLUMNS the writer binds and ReadRecord reads. One column
      list, so a column added to the schema cannot reach the writer and miss
      the exporter. *)
   (* AND THE ROW ID AFTER THEM, for ReadNextWithRowId. After, not before,
      so every QSO column keeps the position ReadRecord reads it at; one
      extra field per Open costs an export nothing measurable. *)
   FCursor.SQL.Text := 'SELECT ' + QSO_COLUMNS + ', ' + ROW_ID_COLUMN +
                       ' FROM qso ORDER BY id';
   try
      OpenQsoReader(FCursor, True);
   except
      FreeAndNil(FCursor);
      raise;
   end;
end;

function TLogRepository.ReadNext(out aQso: ContestExchange): boolean;
var
   ignored: Int64;
begin
   Result := ReadNextWithRowId(ignored, aQso);
end;

function TLogRepository.ReadNextWithRowId(out aRowId: Int64;
                                          out aQso: ContestExchange): boolean;
var
   ignored: TQsoMyFacts;
begin
   Result := ReadNextWithMyFacts(aRowId, aQso, ignored);
end;

function TLogRepository.ReadNext(out aQso: ContestExchange;
                                 out aFacts: TQsoMyFacts): boolean;
var
   ignored: Int64;
begin
   Result := ReadNextWithMyFacts(ignored, aQso, aFacts);
end;

(* THE ONE CURSOR STEP every sequential read takes. The my_* columns are in
  QSO_COLUMNS, so reading them is a dozen positional fields more per row,
  whether the caller keeps them or not. *)
function TLogRepository.ReadNextWithMyFacts(out aRowId: Int64;
                                            out aQso: ContestExchange;
                                            out aFacts: TQsoMyFacts): boolean;
var
   ignored: AnsiString;
begin
   Result := ReadNextRow(aRowId, aQso, aFacts, ignored);
end;

function TLogRepository.ReadNextForExport(out aQso: ContestExchange;
                                          out aFacts: TQsoMyFacts;
                                          out aSentExchange: AnsiString): boolean;
var
   ignored: Int64;
begin
   Result := ReadNextRow(ignored, aQso, aFacts, aSentExchange);
end;

function TLogRepository.ReadNextRow(out aRowId: Int64;
                                    out aQso: ContestExchange;
                                    out aFacts: TQsoMyFacts;
                                    out aSentExchange: AnsiString): boolean;
begin
   aRowId := 0;
   aFacts := NotCapturedMyFacts;
   aSentExchange := '';
   Result := (FCursor <> nil) and (not FCursor.EOF);
   if Result then
      begin
      ReadRecord(FCursor, aQso);
      ReadMyFacts(FCursor, aFacts);
      if not FCursor.Fields[Ord(qc_exchange_sent)].IsNull then
         begin
         aSentExchange := AnsiString(FCursor.Fields[Ord(qc_exchange_sent)].AsString);
         end;
      aRowId := FCursor.Fields[QSO_COLUMN_COUNT].AsLargeInt;
      FCursor.Next;
      end
   else
      begin
      (* ContestExchange holds ShortStrings and scalars only, so clearing it
        whole is safe. *)
      FillChar(aQso, SizeOf(aQso), 0);
      end;
end;

(* --------------------------------------------------------------------------- *)
(* one transaction for many rows -- section 9c, F4                             *)
(* --------------------------------------------------------------------------- *)

procedure TLogRepository.BeginBatchUpdate;
begin
   if FInBatch then
      begin
      raise ELogRepositoryError.Create(
         'A batch update is already open on this log. One must be committed ' +
         'or rolled back before the next begins.');
      end;
   if FCursor <> nil then
      begin
      raise ELogRepositoryError.Create(
         'A batch update cannot begin while the sequential read is open: the ' +
         'commit that starts it would close that cursor under its reader. ' +
         'Close the read first.');
      end;

   (* THE IMPLICIT TRANSACTION ENDS HERE, AND OURS STARTS. sqldb starts one on the
     first statement and leaves it open, so one is usually active here,
     holding the reads that came before. Starting on top of it is refused
     (StartTransaction raises when Active), and simply adopting it would make
     RollbackBatch undo more than the batch. *)
   if FDatabase.Transaction.Active then
      begin
      FDatabase.Transaction.Commit;
      end;
   FDatabase.Transaction.StartTransaction;
   FInBatch := True;
end;

procedure TLogRepository.UpdateQSOByRowId(aRowId: Int64;
                                          const aQso: ContestExchange);
begin
   if not FInBatch then
      begin
      raise ELogRepositoryError.Create(
         'UpdateQSOByRowId is for a batch: call BeginBatchUpdate first, or ' +
         'use UpdateQSO for a single edit.');
      end;
   if not UpdateQSO(aRowId, aQso) then
      begin
      raise ELogRepositoryError.Create(SysUtils.Format(
         'There is no qso row %d to rewrite. A batch is written from rows its ' +
         'caller has just read, so a missing one means the batch does not ' +
         'match the log; it is refused rather than half applied.', [aRowId]));
      end;
end;

procedure TLogRepository.CommitBatch;
begin
   if not FInBatch then
      begin
      raise ELogRepositoryError.Create('CommitBatch with no batch open.');
      end;
   (* If the COMMIT itself fails, FInBatch stays True and the transaction is
     still the batch's, so the caller's RollbackBatch undoes it. *)
   FDatabase.Transaction.Commit;
   FInBatch := False;
end;

procedure TLogRepository.RollbackBatch;
begin
   (* TLogDatabase.Rollback, not the transaction's own: it also ends a
     transaction SQLite has already rolled back by itself. *)
   FDatabase.Rollback;
   (* ONLY AFTER A ROLLBACK THAT RETURNED. Cleared first, a rollback that
     raised would leave a half-written transaction open with nothing marking
     it -- and the next BeginBatchUpdate would COMMIT it. *)
   FInBatch := False;
end;

procedure TLogRepository.WriteBatch(aUpdates: TLogRowUpdates);
var
   i: integer;
begin
   BeginBatchUpdate;
   try
      for i := 0 to aUpdates.Count - 1 do
         begin
         UpdateQSOByRowId(aUpdates.FRowIds[i], aUpdates.FRows[i]);
         end;
      CommitBatch;
   except
      (* ANY exception -- a missing row, a constraint, a full disk, a failed
        COMMIT. The log is left exactly as it was before the batch. *)
      RollbackBatch;
      raise;
   end;
end;

procedure TLogRepository.AppendBatch(aQsos: TLogQsoAppends;
                                     out aFailedIndex: integer);
var
   i: integer;
begin
   aFailedIndex := -1;
   BeginBatchUpdate;
   try
      for i := 0 to aQsos.Count - 1 do
         begin
         aFailedIndex := i;
         if LogContest <> aQsos.FRows[i].ceContest then
            begin
            SetContest(aQsos.FRows[i].ceContest);
            end;
         (* The row's own -- from its file, or nothing. Never the session's:
           an import is not a QSO logged here. *)
         SetNextSentExchange(aQsos.SentExchange(i));
         SetNextMyFacts(aQsos.MyFacts(i));
         SaveQSOGroupingByExchangeId(aQsos.FRows[i]);
         end;
      (* Every row is in; a failure from here on is the transaction's. *)
      aFailedIndex := -1;
      CommitBatch;
   except
      (* As WriteBatch: ANY exception, and the log is left exactly as it was
        before the batch. A sent exchange set for a row that then failed is
        cleared with it, so it cannot attach itself to a later save. *)
      SetNextSentExchange('');
      SetNextMyFacts(NotCapturedMyFacts);
      RollbackBatch;
      raise;
   end;
end;

function TLogRepository.QSOsWithoutExchangeId(aSampleSize: integer): TMissingExchangeIds;
var
   q: TSQLQuery;
   at: TDateTime;
begin
   Result := Default(TMissingExchangeIds);
   q := NewReadQuery;
   try
      (* ONE READ, IN LOG ORDER. The sample is the first rows; the count is
        all of them, read as the rows go by rather than by a second query.
        '' is tested as well as NULL because a row written before BindText
        stored the empty string would carry one. *)
      q.SQL.Text := 'SELECT callsign, qso_at FROM qso ' +
                    'WHERE record_kind = ''QSO'' ' +
                    'AND (exchange_id IS NULL OR exchange_id = '''') ' +
                    'ORDER BY id';
      q.Open;
      while not q.EOF do
         begin
         Inc(Result.Count);
         if Result.Count <= aSampleSize then
            begin
            at := UnixToDateTime(q.Fields[1].AsLargeInt);
            if Result.Sample <> '' then
               begin
               Result.Sample := Result.Sample + ', ';
               end;
            Result.Sample := Result.Sample + q.Fields[0].AsString + ' ' +
                             FormatDateTime('yyyy-mm-dd hh:nn', at);
            end;
         q.Next;
         end;
      q.Close;
   finally
      q.Free;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* TLogQsoList, TLogRowUpdates, TLogQsoAppends                                  *)
(* --------------------------------------------------------------------------- *)

procedure TLogQsoList.CheckIndex(aIndex: integer);
begin
   if (aIndex < 0) or (aIndex >= FCount) then
      begin
      raise ELogRepositoryError.Create(SysUtils.Format(
         '%s: index %d is outside 0..%d.', [ClassName, aIndex, FCount - 1]));
      end;
end;

function TLogQsoList.AddRow(const aQso: ContestExchange): integer;
begin
   if FCount = Length(FRows) then
      begin
      SetLength(FRows, (FCount * 2) + 64);
      end;
   FRows[FCount] := aQso;
   Result := FCount;
   Inc(FCount);
end;

function TLogQsoList.Count: integer;
begin
   Result := FCount;
end;

function TLogQsoList.Row(aIndex: integer): ContestExchange;
begin
   CheckIndex(aIndex);
   Result := FRows[aIndex];
end;

procedure TLogRowUpdates.Add(aRowId: Int64; const aQso: ContestExchange);
var
   i: integer;
begin
   i := AddRow(aQso);
   (* The ids keep step with the records' capacity, so one SetLength per
     doubling serves both arrays. *)
   if Length(FRowIds) < Length(FRows) then
      begin
      SetLength(FRowIds, Length(FRows));
      end;
   FRowIds[i] := aRowId;
end;

function TLogRowUpdates.RowId(aIndex: integer): Int64;
begin
   CheckIndex(aIndex);
   Result := FRowIds[aIndex];
end;

procedure TLogQsoAppends.Add(const aQso: ContestExchange);
begin
   Add(aQso, NotCapturedMyFacts, '');
end;

procedure TLogQsoAppends.Add(const aQso: ContestExchange;
                             const aMyFacts: TQsoMyFacts;
                             const aSentExchange: AnsiString);
var
   i: integer;
begin
   i := AddRow(aQso);
   (* In step with the records' capacity, as TLogRowUpdates' ids are. *)
   if Length(FMyFacts) < Length(FRows) then
      begin
      SetLength(FMyFacts, Length(FRows));
      SetLength(FSentExchanges, Length(FRows));
      end;
   FMyFacts[i] := aMyFacts;
   FSentExchanges[i] := aSentExchange;
end;

function TLogQsoAppends.MyFacts(aIndex: integer): TQsoMyFacts;
begin
   CheckIndex(aIndex);
   Result := FMyFacts[aIndex];
end;

procedure TLogQsoAppends.SetMyFacts(aIndex: integer; const aMyFacts: TQsoMyFacts);
begin
   CheckIndex(aIndex);
   FMyFacts[aIndex] := aMyFacts;
end;

function TLogQsoAppends.SentExchange(aIndex: integer): AnsiString;
begin
   CheckIndex(aIndex);
   Result := FSentExchanges[aIndex];
end;

procedure TLogRepository.CloseSequentialRead;
begin
   if FCursor <> nil then
      begin
      FCursor.Close;
      FreeAndNil(FCursor);
      end;
end;

function TLogRepository.LoadQSO(aRowId: Int64;
                                out aQso: ContestExchange): boolean;
begin
   FSelectById.Close;
   FSelectById.ParamByName('row_id').AsLargeInt := aRowId;
   OpenQsoReader(FSelectById);
   Result := not FSelectById.EOF;
   if Result then
      begin
      ReadRecord(FSelectById, aQso);
      end
   else
      begin
      FillChar(aQso, SizeOf(aQso), 0);
      end;
   FSelectById.Close;
end;

function TLogRepository.LoadQSOByGuid(const aGuid: AnsiString;
                                      out aQso: ContestExchange): boolean;
begin
   FSelect.Close;
   FSelect.ParamByName('guid').AsString := aGuid;
   OpenQsoReader(FSelect);
   Result := not FSelect.EOF;
   if Result then
      begin
      ReadRecord(FSelect, aQso);
      end
   else
      begin
      FillChar(aQso, SizeOf(aQso), 0);
      end;
   FSelect.Close;
end;

function TLogRepository.QSOCount: integer;
var
   q: TSQLQuery;
begin
   q := NewReadQuery;
   try
      q.SQL.Text := 'SELECT COUNT(*) FROM qso WHERE deleted = 0';
      q.Open;
      Result := q.Fields[0].AsInteger;
      q.Close;
   finally
      q.Free;
   end;
end;

(* EMPTY THE LOG, KEEPING THE CONTEST ROW.

  NY4I chose DELETE over recreating the file (2026-09-08). The distinction is
  not cosmetic: the contest row carries the contest type, the operator's call
  and the entry declaration, and the settings live beside it. Recreating the
  database would take those with the QSOs and make "clear the log" mean "start
  the whole station again", which is not what an operator pressing it means.

  DELETE FROM with no WHERE, so SQLite empties the table; the caller commits.
  Nothing cascades from qso that we want kept, and anything that does cascade
  is qso data by definition. *)
procedure TLogRepository.DeleteAllQSOs;
begin
   FDatabase.Connection.ExecuteDirect('DELETE FROM qso');
   InvalidateRecordCount;
end;

procedure TLogRepository.Commit;
begin
   FDatabase.Transaction.Commit;
end;

initialization
   Randomize;
   (* Before any repository can exist, and once. It never raises: a problem is
     recorded, and TLogRepository.Create and VerifyQsoColumns report it. *)
   BuildQsoColumnTable;

end.

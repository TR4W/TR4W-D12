unit uQsoMyFacts;
{$I ..\tr4w.inc}

(* OUR STATION, AS IT WAS FOR ONE QSO -- the qso row's my_* columns (schema 3).

  NY4I, 2026-10-18: "our grid is an event source along with all the MY_ values
  for the contest where needed. The QSO record should have all the MY_ values
  (such as MY_GRID)." A rover moves; a station corrects its grid mid-contest;
  a rescore, an edit or an export a month later must read what was true WHEN
  THE QSO WAS LOGGED, never today's settings (Q13: a logged QSO reads its
  record, not live state).

  ContestExchange cannot carry these -- it is a frozen 376-byte record with
  deployed readers -- so they travel beside it, in this record, and live in
  their own columns.

  A RECORD BECAUSE IT IS AN INTERFACE PARAMETER, the exemption CLAUDE.md
  grants: the argument of the repository's insert, update and read, handed
  by value, with no behaviour of its own.

  THE MEANING OF "NOTHING" IS CARRIED BY Source, NOT BY NULL (NY4I, ruling A,
  2026-10-18):

    mfsNotCaptured   my_source IS NULL -- the row was written before this
                     build captured anything (every log before schema 3, every
                     corpus fixture, a .TRW migration). A reader that needs a
                     value FALLS BACK to the session's, and says so once.
    anything else    captured. An empty field (or a zone of 0) means UNKNOWN,
                     and a reader must NEVER borrow today's value for it.

  The per-value NULL cannot carry that distinction on its own: the
  repository's BindText stores '' as NULL for every optional column. So the
  marker is a column of its own, and it doubles as the provenance NY4I asked
  for (ruling D: a peer's QSO is stamped with THIS station's values, MARKED
  as assumed).

  A LEAF: no database, no settings, no program state -- the repository, the
  store and the editor all speak it, and the rules below are unit-tested. *)

interface

type
   TQsoMyFactsSource = (
      mfsNotCaptured,   (* my_source NULL -- see above *)
      mfsLogged,        (* this station's values, captured as it logged the QSO *)
      mfsAssumed,       (* a multi-op PEER's QSO, stamped with THIS station's
                           values because the V1 packet carries none (ruling D) *)
      mfsImported,      (* read from an imported file's own MY_* fields *)
      mfsEdited,        (* the operator changed them in Edit QSO (ruling B) *)
      mfsStamped);      (* an IMPORTED QSO given THIS contest's values at import
                           time, as a new QSO would be (NY4I, 2026-10-18: the
                           file named none, or the operator chose the
                           contest's over the file's) *)

   (* ONE STATION FACT, for the import's report: which a file names, and
      which differ from the contest's. *)
   TMyFactField = (mffCall, mffGrid, mffState, mffCounty, mffSection, mffPark,
                   mffIota, mffCountry, mffCQZone, mffITUZone);
   TMyFactFields = set of TMyFactField;

   TQsoMyFacts = record
      Source: TQsoMyFactsSource;
      Call: AnsiString;        (* as signed, rover suffix and all -- ADIF STATION_CALLSIGN *)
      Grid: AnsiString;        (* MY_GRIDSQUARE *)
      State: AnsiString;       (* MY_STATE -- the PRIMARY subdivision we are in *)
      County: AnsiString;      (* MY_CNTY  -- the SECONDARY subdivision *)
      Section: AnsiString;     (* MY_ARRL_SECT *)
      Park: AnsiString;        (* MY_SIG_INFO / MY_POTA_REF *)
      Iota: AnsiString;        (* MY_IOTA *)
      Country: AnsiString;     (* our CTY.DAT country prefix *)
      Continent: AnsiString;   (* our continent, as cty_continent spells it *)
      CQZone: integer;         (* MY_CQ_ZONE; 0 = unknown *)
      ITUZone: integer;        (* MY_ITU_ZONE; 0 = unknown *)

      (* THE LICENCE YEAR THIS QSO SENT -- qso.year_sent, log schema 8 (issue
         300). The number AS THE CONTEST SENDS IT (uContestBase.
         SentLicenseYearValue): 85 for a two-digit year, 1985 for a four-digit
         one, a count of years licensed -- so the sent text is rebuilt from
         the row alone. TWO FIELDS, NOT A SENTINEL, for RcvdYear's reason: 0
         is a real value (00 = first licensed in 2000) and a zero record must
         read as "none". YearSent means something only when YearSentKnown.

         UNLIKE THE OTHER FIELDS IT DOES NOT FOLLOW Source: a row backfilled
         at the schema-8 migration holds a year with my_source still NULL,
         and the year is the row's own. The repository reads it whatever the
         source; see TSentYearSource for where a new row's year comes from. *)
      YearSent: integer;
      YearSentKnown: boolean;
   end;

   (* WHERE A NEW ROW'S year_sent COMES FROM -- issue 300 (NY4I, 2026-11-13: a
      QSO record depends on nothing but its own row). SentYearSourceOf is the
      rule; the store asks it when a row is written.

         sysNone          the contest sends no year (or the record is not a
                          QSO): year_sent is NULL
         sysThisStation   logged here: the year this station sends now --
                          MY LICENSE YEAR, the contest's statement or the
                          station's (uContestFactory.SessionLicenseYearSent)
         sysPeer          a multi-op PEER's QSO: the year THE PEER sent. The
                          protocol-4 QSO packet carries it
                          (ContestExchange.YearSent / YearSentKnown); a packet
                          with none stores NONE -- never this station's year,
                          which my_source 'assumed' would otherwise stamp on it
         sysFile          imported: the year the file's STX_STRING sent *)
   TSentYearSource = (sysNone, sysThisStation, sysPeer, sysFile);

(* The value a row written before schema 3 reads back as. *)
function NotCapturedMyFacts: TQsoMyFacts;

(* my_source as stored. mfsNotCaptured is '' -- which the repository binds as
   NULL, and NULL is what "never captured" is. *)
function MyFactsSourceToken(aSource: TQsoMyFactsSource): AnsiString;
function TokenToMyFactsSource(const aToken: AnsiString): TQsoMyFactsSource;

(* Do the two hold different VALUES? Source is not compared: it says where the
   values came from, not what they are, and the editor asks this to decide
   whether the operator changed anything. *)
function MyFactsValuesDiffer(const a, b: TQsoMyFacts): boolean;

(* Do the two hold a different SENT YEAR (issue 300)? Asked apart from the
   station's values: the year has its own provenance (a backfilled row holds
   one with my_source NULL), so correcting it alone must not mark a
   never-captured row's station as edited -- that would turn its empty
   columns from "fall back to the session" into "unknown". *)
function MyFactsYearSentDiffers(const a, b: TQsoMyFacts): boolean;

(* DID THIS STATION LOG THE QSO, or did it arrive from a multi-op peer?

   Every local logging path stamps the record with this station's computer id
   before it is stored (MainUnit.AddRecordToLogAndSendToNetwork, the entry
   path, WSJT-X); a QSO that arrived over the network carries the PEER's,
   because a network requires every station to have a distinct id. So the id
   on the record answers the question without the caller having to say. A
   single-op station has no id (#0) on both sides, and logs everything
   itself. *)
function QsoWasLoggedHere(aQsoComputerID, aOurComputerID: AnsiChar): boolean;

(* WHERE A NEW ROW'S SENT YEAR COMES FROM -- see TSentYearSource.
   aContestSendsYear: the QSO's contest states a ReceivedYearKind (it sends
   the year it receives). aSource: the row's my_source as it is being written.
   mfsNotCaptured (a note, a QTC) and every row of a contest that sends no
   year answer sysNone. *)
function SentYearSourceOf(aContestSendsYear: boolean;
                          aSource: TQsoMyFactsSource): TSentYearSource;

(* aFacts with its sent year set to aYear (aKnown) or cleared. *)
procedure SetFactsYearSent(var aFacts: TQsoMyFacts; aKnown: boolean; aYear: integer);

(* ---------------------------------------------------------------------------
  THE IMPORT RULE -- NY4I, 2026-10-18, replacing stage 2's "an absent tag is
  unknown" for an import:

    "So the use case is I start a contest, then import. Therefore you apply
     the set my fields as if it were a new QSO. If the import has its own my
     fields, we should report that and ask the user if they should override
     the contest."
  --------------------------------------------------------------------------- *)

(* The fields aFacts holds a value for -- what a file NAMED. *)
function MyFactsFieldsPresent(const aFacts: TQsoMyFacts): TMyFactFields;

(* The fields aFile names whose value is not aContest's. A field the file does
   not name is not a difference: the file said nothing about it. *)
function MyFactsFieldsDiffering(const aFile, aContest: TQsoMyFacts): TMyFactFields;

(* A field's value as text, and the ADIF tag it travels in -- for the report. *)
function MyFactFieldValue(const aFacts: TQsoMyFacts; aField: TMyFactField): AnsiString;
function MyFactFieldTag(aField: TMyFactField): string;

(* WHAT AN IMPORTED ROW RECORDS AS OUR STATION.

    the file named none (aFile never captured)  -> the contest's, stamped
    the operator chose the file's (aUseFile)    -> the file's, as named: a
                                                   field it did not name is
                                                   UNKNOWN, never filled in
    the operator chose the contest's            -> the contest's, stamped,
                                                   every field

   aContest is this station's values at import time (uLogStore.
   LogStoreCurrentMyFacts) -- what a QSO logged now would record.

   THE SENT YEAR IS aFile's IN EVERY CASE (issue 300): the year a record sent
   comes from its STX_STRING (uContestBase.ApplyImportedSentYear), not from a
   MY_ tag, so the station answer does not move it. *)
function MyFactsForImport(const aFile, aContest: TQsoMyFacts;
                          aUseFile: boolean): TQsoMyFacts;

(* ---------------------------------------------------------------------------
  WHAT AN EXPORT WRITES FOR A LOGGED QSO -- log schema 3, stage 4: a logged
  QSO reads its record, never today's settings (Q13).
  --------------------------------------------------------------------------- *)

(* OUR CALL ON A LOGGED QSO -- D5: the call it recorded (my_call); else the call
   the log's entry declared (contest.my_call); and only when neither is known,
   aSessionCall -- today's MY CALL. *)
function ExportCallOf(const aFacts: TQsoMyFacts;
                      const aDeclaredCall, aSessionCall: AnsiString): AnsiString;

(* WHAT AN IMPORTED QSO SAID IT SENT, to be written back VERBATIM: its
   exchange_sent, when the row was imported (its file's or the contest's
   station) and the file carried an STX_STRING. '' means "build it" -- every
   QSO logged here, whose exchange_sent is the contest's CANONICAL spelling
   (the RTC and UDP one) rather than the ADIF one, and every row that never
   recorded its station. *)
function RecordedSentExchange(const aFacts: TQsoMyFacts;
                              const aExchangeSent: AnsiString): AnsiString;

implementation

uses
   SysUtils;   (* SameText *)

const
   SOURCE_TOKENS: array[TQsoMyFactsSource] of AnsiString = (
      '', 'logged', 'assumed', 'imported', 'edited', 'stamped');

   FIELD_TAGS: array[TMyFactField] of string = (
      'STATION_CALLSIGN', 'MY_GRIDSQUARE', 'MY_STATE', 'MY_CNTY',
      'MY_ARRL_SECT', 'MY_POTA_REF', 'MY_IOTA', 'MY_DXCC', 'MY_CQ_ZONE',
      'MY_ITU_ZONE');

function NotCapturedMyFacts: TQsoMyFacts;
begin
   Result := Default(TQsoMyFacts);
   Result.Source := mfsNotCaptured;
end;

function MyFactsSourceToken(aSource: TQsoMyFactsSource): AnsiString;
begin
   Result := SOURCE_TOKENS[aSource];
end;

function TokenToMyFactsSource(const aToken: AnsiString): TQsoMyFactsSource;
var
   s: TQsoMyFactsSource;
begin
   (* '' is NULL, which is "never captured". *)
   Result := mfsNotCaptured;
   if aToken = '' then
      begin
      Exit;
      end;

   for s := Succ(mfsNotCaptured) to High(TQsoMyFactsSource) do
      begin
      if aToken = SOURCE_TOKENS[s] then
         begin
         Result := s;
         Exit;
         end;
      end;

   (* A TOKEN THIS BUILD DOES NOT KNOW. Only a newer build could have written
      one, and VerifyIdentity refuses a newer schema, so this is a row edited
      by hand. Its values were captured by SOMETHING, so it is not "never
      captured" -- which would let a reader replace them with today's -- and
      the honest reading of a stated value of unknown provenance is that an
      operator put it there. *)
   Result := mfsEdited;
end;

function MyFactsValuesDiffer(const a, b: TQsoMyFacts): boolean;
begin
   Result := (a.Call <> b.Call)           or
             (a.Grid <> b.Grid)           or
             (a.State <> b.State)         or
             (a.County <> b.County)       or
             (a.Section <> b.Section)     or
             (a.Park <> b.Park)           or
             (a.Iota <> b.Iota)           or
             (a.Country <> b.Country)     or
             (a.Continent <> b.Continent) or
             (a.CQZone <> b.CQZone)       or
             (a.ITUZone <> b.ITUZone);
end;

function MyFactsYearSentDiffers(const a, b: TQsoMyFacts): boolean;
begin
   Result := (a.YearSentKnown <> b.YearSentKnown) or
             (a.YearSentKnown and (a.YearSent <> b.YearSent));
end;

function QsoWasLoggedHere(aQsoComputerID, aOurComputerID: AnsiChar): boolean;
begin
   Result := aQsoComputerID = aOurComputerID;
end;

function SentYearSourceOf(aContestSendsYear: boolean;
                          aSource: TQsoMyFactsSource): TSentYearSource;
begin
   Result := sysNone;
   if not aContestSendsYear then
      begin
      Exit;
      end;
   case aSource of
      mfsLogged, mfsEdited:
         begin
         Result := sysThisStation;
         end;
      mfsAssumed:
         begin
         Result := sysPeer;
         end;
      mfsImported, mfsStamped:
         begin
         Result := sysFile;
         end;
   else
      begin
      Result := sysNone;
      end;
   end;
end;

procedure SetFactsYearSent(var aFacts: TQsoMyFacts; aKnown: boolean; aYear: integer);
begin
   aFacts.YearSentKnown := aKnown and (aYear >= 0);
   if aFacts.YearSentKnown then
      begin
      aFacts.YearSent := aYear;
      end
   else
      begin
      aFacts.YearSent := 0;
      end;
end;

function MyFactFieldValue(const aFacts: TQsoMyFacts; aField: TMyFactField): AnsiString;

   function Zone(aZone: integer): AnsiString;
   begin
      Result := '';
      if aZone > 0 then
         begin
         Str(aZone, Result);
         end;
   end;

begin
   case aField of
      mffCall:    Result := aFacts.Call;
      mffGrid:    Result := aFacts.Grid;
      mffState:   Result := aFacts.State;
      mffCounty:  Result := aFacts.County;
      mffSection: Result := aFacts.Section;
      mffPark:    Result := aFacts.Park;
      mffIota:    Result := aFacts.Iota;
      mffCountry: Result := aFacts.Country;
      mffCQZone:  Result := Zone(aFacts.CQZone);
      mffITUZone: Result := Zone(aFacts.ITUZone);
   else
      Result := '';
   end;
end;

function MyFactFieldTag(aField: TMyFactField): string;
begin
   Result := FIELD_TAGS[aField];
end;

function MyFactsFieldsPresent(const aFacts: TQsoMyFacts): TMyFactFields;
var
   f: TMyFactField;
begin
   Result := [];
   if aFacts.Source = mfsNotCaptured then
      begin
      Exit;
      end;
   for f := Low(TMyFactField) to High(TMyFactField) do
      begin
      if Length(MyFactFieldValue(aFacts, f)) > 0 then
         begin
         Include(Result, f);
         end;
      end;
end;

function MyFactsFieldsDiffering(const aFile, aContest: TQsoMyFacts): TMyFactFields;
var
   f: TMyFactField;
begin
   Result := [];
   for f := Low(TMyFactField) to High(TMyFactField) do
      begin
      if (f in MyFactsFieldsPresent(aFile)) and
         (not SameText(MyFactFieldValue(aFile, f), MyFactFieldValue(aContest, f))) then
         begin
         Include(Result, f);
         end;
      end;
end;

function ExportCallOf(const aFacts: TQsoMyFacts;
                      const aDeclaredCall, aSessionCall: AnsiString): AnsiString;
begin
   if (aFacts.Source <> mfsNotCaptured) and (Length(aFacts.Call) > 0) then
      begin
      Result := aFacts.Call;
      end
   else if Length(aDeclaredCall) > 0 then
      begin
      Result := aDeclaredCall;
      end
   else
      begin
      Result := aSessionCall;
      end;
end;

function RecordedSentExchange(const aFacts: TQsoMyFacts;
                              const aExchangeSent: AnsiString): AnsiString;
begin
   Result := '';
   if aFacts.Source in [mfsImported, mfsStamped] then
      begin
      Result := aExchangeSent;
      end;
end;

function MyFactsForImport(const aFile, aContest: TQsoMyFacts;
                          aUseFile: boolean): TQsoMyFacts;
begin
   if (aFile.Source <> mfsNotCaptured) and aUseFile then
      begin
      Result := aFile;
      Result.Source := mfsImported;
      end
   else
      begin
      Result := aContest;
      Result.Source := mfsStamped;
      end;
   (* THE SENT YEAR IS THE RECORD'S, whichever station the operator chose
      (issue 300): it is what the file's STX_STRING sent, not a MY_ tag. *)
   SetFactsYearSent(Result, aFile.YearSentKnown, aFile.YearSent);
end;

end.

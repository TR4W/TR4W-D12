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

(* THE CONTEST LOG -- THE ONE SQLITE DATABASE, AND EVERY WRITE TO IT.

  THIS HEADER DESCRIBED STEP B2 UNTIL 2026-10-17: a shadow written alongside
  an authoritative .TRW, opened lazily on the first append, each call made
  AFTER the binary record was on disk. Every clause of that stopped being true
  at B5 (2026-09-24), and the premise outlived it in two branches -- an append
  that updated the newest imported row instead of inserting, and a rewrite
  that returned without writing, both on the reasoning that the .TRW already
  held the QSO. They are deleted; uTestLogStore pins what replaced them.

  WHAT IS TRUE NOW:

    The database IS the log. tAddQSOToLog writes here and nowhere else; the
    .TRW is IMPORT-ONLY, read once by EnsureOpen to migrate a contest this
    build has never opened, and never written.

    It is opened at STARTUP, by LogStoreApplyContestConfig, before anything
    is logged. Every entry point still goes through EnsureOpen, so a caller
    that comes first gets the same log.

    A write failure DISABLES the store and is put in front of the operator
    (see Disable): there is no fallback behind it, so a QSO that did not
    commit is not acknowledged. docs/SQLITE_MIGRATION_TASKS.md has the
    history. *)
unit uLogStore;

{$I tr4w.inc}

interface

uses
   VC,
   uLogRepository,   (* TLogRepository -- see LogStoreRepository *)
   uQsoMyFacts,      (* TQsoMyFacts -- the editor's read and write below *)
   uExternalDelivery; (* TDeliveryStatus -- LogStoreReadDeliveryAtIndex *)

(* PUT A QSO IN THE LOG, AND SAY WHETHER IT IS ACTUALLY THERE.

  True ONLY after the SQLite transaction carrying this QSO has committed. That
  is the persistence boundary and there is no weaker one worth reporting: with
  synchronous=FULL a committed transaction is on the storage device.

  IT WAS A PROCEDURE AND THAT WAS A DURABILITY HOLE (Codex review,
  2026-09-11). It caught every exception, disabled the store, and returned
  normally -- so the caller incremented the QSO count, refreshed the log
  display and reported success for a contact that reached no disk anywhere.
  Disk-full, a permission change, a locked file or a failed commit all
  produced a QSO that existed only in the totals until the program closed.

  And after the first failure the store is disabled, so every SUBSEQUENT QSO
  returned immediately -- and was acknowledged too. One transient error and the
  rest of the contest was being logged to nothing.

  The caller's obligation is the whole point of the return value: do not count
  it, do not draw it, do not tell the network about it and do not clear the
  entry fields until this says True. Never raises. *)
function LogStoreAppendQSO(const aQso: ContestExchange): boolean;

(* OUR STATION AS THE LAST SUCCESSFUL LogStoreAppendQSO RECORDED IT -- what
  live entry hands the final score's view beside that QSO (log schema 3,
  stage 3), so a whole-log rule reads the station the row holds. Ask it only
  right after an append answered True; NotCapturedMyFacts before any. *)
function LogStoreLastAppendedMyFacts: TQsoMyFacts;

(* THIS STATION'S MY_ VALUES AS THEY ARE NOW -- exactly what a QSO logged at
  this moment records (Source mfsLogged). What an ADIF import stamps on a
  record that names none (NY4I, 2026-10-18). *)
function LogStoreCurrentMyFacts: TQsoMyFacts;

(* Rewrites the log's newest row -- the three sites that used to seek back one
  record in the binary log (DeleteLastContact, uNet.UpdateRec,
  uQTCS.SetSendedQSOs).  Writes even when this call migrated the log: the .TRW
  never holds the rewrite.  Never raises. *)
procedure LogStoreUpdateNewestQSO(const aQso: ContestExchange);

(* Rewrites the row matching a record's POSITION in the binary log -- what the
  QSO editor does with a byte offset.  Never raises. *)
procedure LogStoreUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange); overload;

(* THE SAME, AND OUR STATION FOR THAT QSO WITH IT -- Edit QSO when the operator
  changed one of the my_* values (NY4I, ruling B). Both writes are ONE
  transaction: one commit, or neither. aFacts.Source is written as given;
  the editor passes mfsEdited. Never raises. *)
procedure LogStoreUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange;
                                   const aFacts: TQsoMyFacts); overload;

(* OUR STATION AS RECORDED for the QSO at a record position -- what Edit QSO
  shows. NotCapturedMyFacts for a row written before schema 3. False, with
  NotCapturedMyFacts, when the log is not usable or holds no such row.
  Never raises. *)
function LogStoreReadMyFactsAtIndex(aRecordIndex: Int64;
                                    out aFacts: TQsoMyFacts): boolean;

(* THE EXTERNAL-LOGGER DELIVERY of the QSO at a record position -- the
  read-only line Edit QSO shows (uExternalDelivery.ExternalDeliveryStatusOfQso,
  read through its own read-only connection so it sees what the delivery
  worker has committed). False, with Logger = '', when the QSO has no
  delivery row, the log is not usable, or the read fails; a failure is
  logged and the store stays enabled. Never raises. *)
function LogStoreReadDeliveryAtIndex(aRecordIndex: Int64;
                                     out aStatus: TDeliveryStatus): boolean;

type
   (* Re-exported so a caller can collect rows for LogStoreUpdateQSOsByRowId
     without using uLogRepository itself -- and taking on every name it
     declares into a uses clause where order decides which one wins. *)
   TLogRowUpdates = uLogRepository.TLogRowUpdates;

(* REWRITES MANY ROWS, BY ROW ID, IN ONE TRANSACTION -- ALL OR NONE.

  What a whole-log pass wants: the rescore and the dupe- and mult-sheet
  clears read every row through uLogSource.LogSourceNextWithRowId, collect
  the ones they changed, and hand them here. Section 9c, F4: one commit
  instead of one per row, and no OFFSET walk to find each row again.

  True when every row was written and the transaction committed (also for an
  empty list). On failure the batch is ROLLED BACK -- the log holds exactly
  what it held before -- and the failure is reported and the store disabled,
  the same rule as every other write here: LogStoreIsUsable then says so,
  which is what /RESCORE's exit code reads. Never raises. *)
function LogStoreUpdateQSOsByRowId(aUpdates: TLogRowUpdates): boolean;

type
   (* Re-exported for the same reason as TLogRowUpdates. *)
   TLogQsoAppends = uLogRepository.TLogQsoAppends;

(* APPENDS MANY QSOS IN ONE TRANSACTION -- ALL OR NONE.

  The ADIF import's write. NY4I, 2026-10-14: the import is all or nothing --
  one record that will not go in, and nothing goes in. Each QSO is written as
  LogStoreAppendQSO writes one (the contest stamped from the record,
  county-line grouping), all in TLogRepository.AppendBatch's one transaction
  -- EXCEPT what it sent and where our station was, which are the row's own
  as the batch was given them, never captured from the live station (log
  schema 3, stage 2: the D3 fix).

  True when every QSO was written and the transaction committed (also for an
  empty list). On failure the batch is ROLLED BACK and the log holds exactly
  what it held before; aFailedIndex is the 0-based index of the QSO that
  failed, or -1 when the failure was not one QSO's (the log would not open,
  the commit failed), and aFailure is the reason, fit to show.

  THE STORE STAYS ENABLED WHEN THE ROLLBACK SUCCEEDED, which is a deliberate
  difference from LogStoreUpdateQSOsByRowId. A record that will not insert --
  an ADIF record with no CALL is the realistic one, since callsign is NOT
  NULL -- says something about the FILE, not about the log, and the log is
  provably as it was. Disabling would stop the operator logging for the rest
  of the session over a bad line in a file. If the failure was the disk, the
  next QSO's own append meets it and fails closed there, which is the moment
  that matters. When the ROLLBACK itself fails the log's state is not known,
  and then the store is disabled exactly as every other write failure
  disables it. Never raises. *)
function LogStoreAppendQSOs(aQsos: TLogQsoAppends; out aFailedIndex: integer;
                            out aFailure: string): boolean;

(* THE VALIDITY CHECK FOR EXCHANGE IDS: are there QSOs in the log with none?

  NY4I, 2026-10-14: a rescore no longer mints an exchange id, and a missing
  one is REPORTED on validity check rather than invented. False when there
  are any, with aReport giving the count and the first few (call and time);
  True with a sentence saying so when there are none. A log that cannot be
  opened is a False with the reason -- a check that cannot run has not
  passed. Reads only. Registered with uVerificationChecks, which is the Tools
  menu's verification window. *)
function LogStoreCheckExchangeIds(out aReport: string): boolean;

(* Rewrites the row the multi-op network identifies by (ceQSOID1, ceQSOID2).
  Does nothing when that pair is unset.  Never raises. *)
(* True when a QSO with that network key was found and rewritten.

  IT RETURNS SOMETHING NOW BECAUSE THE CALLER NEEDS IT. uNet's
  FindAndUpdateQSOInLog used to answer that question itself, by scanning
  the .TRW backwards until the key matched -- so it knew whether it had
  found one. The scan is gone; the answer has to come from here. *)
function LogStoreUpdateQSOBySessionIds(const aQso: ContestExchange): boolean;

type
   (* Re-exported, as TLogRowUpdates is, so a caller needs no uLogRepository. *)
   TQsoSessionKey = uLogRepository.TQsoSessionKey;
   TQsoSessionKeys = uLogRepository.TQsoSessionKeys;
   TQsoKeyTest = uLogRepository.TQsoKeyTest;

(* THE MULTI-OP SERVER'S BOOKKEEPING -- Phase 1, C5 (2026-10-27). See
  TLogRepository.CollectUnsentToServer for what "owed" means.

  LogStoreCollectUnsentToServer appends every row the server still has to hear
  about to aInto, oldest first. False when the log cannot be read; a READ, so a
  failure is reported and the store stays enabled. It leaves the log as it was.

  LogStoreHasQSOBySessionIds: does the log already hold a QSO with this network
  key? What makes a received QSO safe to receive twice. False for (0, 0) and,
  reported, when the log cannot be read -- a station that cannot ask records the
  QSO, because a duplicate is the lesser harm than a lost contact.

  LogStoreMarkServerProgress writes sent_to_server = 1 for aSent and
  server_dirty = 0 for aEditsDone, ONE TRANSACTION, FLAGS ONLY, and commits. A
  key that matches no row changes nothing. A write failure disables the store
  like every other write here. True when the transaction committed (also for two
  empty lists).

  LogStoreCountUnsentToServer: how many networked rows the server has never been
  given, and how many it holds an older version of. *)
function LogStoreCollectUnsentToServer(aInto: TLogRowUpdates): boolean;
function LogStoreHasQSOBySessionIds(aSessionId, aSessionSeq: Int64): boolean;

(* EVERY NETWORK KEY IN THE LOG, for the catch-up from the server (Phase 1, C6).
  False, with no keys, when the log cannot be read: a catch-up that cannot tell
  what the log holds must not insert, or it would add what is already there. A
  READ, so a failure is reported and the store stays enabled. *)
function LogStoreCollectSessionKeys(out aKeys: TQsoSessionKeys): boolean;

(* THE ROWS TO CONSIDER WHEN THE MULTI-OP SERVER IS RESTOCKED (2026-10-28), every
  row except those aServerHolds says the server has. See
  TLogRepository.CollectForServerRestock. False when the log cannot be read; a
  READ, so a failure is reported and the store stays enabled. *)
function LogStoreCollectForServerRestock(aInto: TLogRowUpdates;
                                         aServerHolds: TQsoKeyTest): boolean;
function LogStoreMarkServerProgress(const aSent, aEditsDone: TQsoSessionKeys): boolean;
function LogStoreCountUnsentToServer(out aUnsent, aDirty: integer): boolean;

(* EMPTY THE LOG. False if there was no usable store to empty, so a caller can
  tell "cleared" from "could not".

  The contest row survives -- see TLogRepository.DeleteAllQSOs. *)
function LogStoreClearAllQSOs: boolean;

(* Closes it, if it was ever opened.  Safe to call when it was not. *)
procedure LogStoreClose;

(* False after a failure has switched it off, or before anything opened it. *)
(* THE ONE CONNECTION TO THE LOG DATABASE.

  THERE USED TO BE TWO. uLogSource opened a second TLogDatabase on the same
  file to read through, and the consequence was not a tidiness problem: a
  reader connection sits in a read transaction, which in WAL mode pins its view
  of the database, so QSOs COMMITTED by this connection were invisible to it.
  The main window grid was permanently one QSO behind while View/Edit Log --
  which opened a fresh connection each time -- showed the contact (NY4I,
  2026-09-04). That was patched by ending the read transaction; NY4I chose the
  root fix instead, which is this.

  ONE CONNECTION CANNOT BE STALE AGAINST ITSELF, and every future reader of the
  log gets that for free rather than having to know to ask.

  Nil when nothing has opened the store, or when a failure has disabled it --
  so a caller checks, exactly as it checks LogStoreIsUsable. *)
function LogStoreRepository: TLogRepository;

function LogStoreIsUsable: boolean;

procedure LogStoreStartExternalDelivery;

(* TWO SEAMS FOR THE TEST PROGRAM, AND ONLY FOR IT (2026-10-23). The program
  never assigns or calls either.

  A store failure disables the store and puts a modal in front of the
  operator (Disable). Neither can happen in a test run: the modal would hang
  it, and GDisabled was "never cleared", so a test that disabled the store
  broke every store test after it -- which is why the store's fault-injection
  tests had not been written. LogStoreFailureNotice, when assigned, takes the
  operator's notice instead of the modal, so a test can SEE the notice was
  given; LogStoreForgetFailureForTests closes the store and clears the
  failure, so the next suite starts from a closed, usable store. *)
type
   TLogStoreFailureNotice = procedure(const aText: RawByteString);

var
   LogStoreFailureNotice: TLogStoreFailureNotice = nil;

procedure LogStoreForgetFailureForTests;

(* A LOG THAT IS LOCKED WHEN IT IS OPENED (2026-10-31).

  NY4I: if at startup the log is locked, that is fatal for that open -- warn,
  suggest how to fix it, and offer a choice. EnsureOpen probes the log's
  write lock before opening it (ProbeLogWriteLock, waiting
  LOG_BUSY_TIMEOUT_MS) and, when another connection holds it, asks:

    llcRetry     probe again;
    llcReadOnly  open the log READ-ONLY for this session: it can be viewed
                 and exported, and NO QSO CAN BE LOGGED -- every write entry
                 here refuses (LogStoreIsReadOnly) and says so;
    llcQuit      end the program (Halt(1), as the other startup refusals).

  The default asks with a native dialog (AskAboutALockedLog). A test assigns
  LogStoreLockedQuestion to answer instead. A headless run (tSilentExport) is
  never asked: the open fails, logged, as any other failed open.

  NEVER OFFERED, NEVER DONE: deleting the -wal or -shm. They can hold
  committed QSOs that are not yet in the .db. *)
type
   TLogLockedChoice = (llcRetry, llcReadOnly, llcQuit);
   TLogLockedQuestion = function(const aFileName, aDetail: string): TLogLockedChoice;

var
   LogStoreLockedQuestion: TLogLockedQuestion = nil;

   (* The busy wait the store's own connection is opened with, in ms; 0 (the
     program's value, never changed) means TLogDatabase's default,
     LOG_BUSY_TIMEOUT_MS. A test sets a few ms, so a held lock costs it
     milliseconds per attempt rather than seconds. Read at open. *)
   LogStoreBusyTimeoutMs: integer = 0;

(* True when this session's log was opened read-only (the operator's answer to
  a locked log). Nothing is written to it; LogStoreAppendQSO returns False. *)
function LogStoreIsReadOnly: boolean;

(* BEFORE A WRITE ON THE MAIN CONNECTION FROM OUTSIDE THIS UNIT
  (DupeAndMultSheet.SaveRestartFile writes through LogStoreRepository).
  False when nothing may be written (no log, disabled, read-only). Otherwise
  ends a read transaction sqldb left open -- see BeginMainWrite -- and
  returns True. *)
function LogStoreReadyToWrite: boolean;

(* After a write from outside this unit failed: roll back what it began, so
  the next write starts clean. Never raises. *)
procedure LogStoreAbandonWrite;

(* How many times a main-thread write is tried when the log is busy, before
  it is refused. *)
const
   LOG_WRITE_ATTEMPTS = 3;

(* TOOLS > RUN VERIFICATION CHECKS: IS THE LOG LOCKED?

  Reports, and never changes anything (it never removes a sidecar):
    - every secondary connection (the WRL worker) whose transaction has been
      open longer than LOG_WATCH_THRESHOLD_MS, by name;
    - whether something else holds the write lock: a short BEGIN IMMEDIATE on
      a throwaway connection, released at once (ProbeLogWriteLock);
    - the -wal and -shm beside the log, which are EXPECTED while TR4W has it
      open and are information, not a failure;
    - the watchdog's interventions this session.
  False when a lock is held or a transaction is overdue. *)
function LogStoreCheckLockState(out aReport: string): boolean;

(* APPLIES THE CONTEST CONFIGURATION THE LOG CARRIES -- phase E2.

  NY4I: "when done, the .cfg file should not be necessary."

  This is what makes that true. A contest .cfg is read once, when the log is
  created, and captured; from then on the LOG says what the contest is and the
  file is not consulted. Returns how many commands it applied, so a caller can
  tell "this log has none" from "this log has been read".

  ONLY source = 'contest'. See TLogRepository.LoadContestConfig for why.

  AND LAST, THE MEMORIES THE OPERATOR EDITED (Q113) --
  RestoreEditedMessageMemories, after the contest has been set up. *)
function LogStoreApplyContestConfig: integer;

type
   (* HOW THE CONTEST A LOG NAMES IS SET UP -- given its stored id, True when
     it was accepted. The program's is CheckCommand('CONTEST', id), whose
     effect is FoundContest. *)
   TLogContestSetUp = function(const aContestId: ShortString): boolean;

(* LogStoreApplyContestConfig'S ORDERED REPLAY, with the contest's set-up
  handed in -- R3, 2026-10-23. The program calls it only through
  LogStoreApplyContestConfig, which hands in CheckCommand('CONTEST').

  WHY IT EXISTS: the order is the point -- the restore of the edited
  memories must run after every default writer in the replay -- and the
  replay's set-up is FoundContest, which rewrites the whole session. A test
  hands in a set-up that writes the contest's default memories and nothing
  else, and so proves the ORDER through the production routine: delete or
  move the restore and it fails. *)
function LogStoreApplyContestConfigWith(aSetUpContest: TLogContestSetUp): integer;

(* THE FUNCTION-KEY MEMORIES INTO THE LOG'S message TABLE -- every memory the
  program holds, both banks and both modes, with its button caption. A row is
  flagged edited when the operator stated that key (LogCW's Q9 latch:
  CQMemoryIsOperatorStated / EXMemoryIsOperatorStated), and only those rows
  come back at open. The table is rewritten whole, so a row no longer edited
  or emptied does not linger. Does not commit -- the caller's capture does.
  Public so the tests can drive it with their own repository. *)
procedure CaptureMessageMemories(aRepository: TLogRepository);

(* THE MEMORIES THE OPERATOR EDITED, BACK INTO THE PROGRAM (Q113). Each row
  flagged edited is applied as the operator's edit is -- text, caption, and
  the Q9 latch -- so the contest's set-up leaves it alone from here on, and
  the next close records it as edited again. A row NOT flagged is the
  contest's default as it stood at close and is NOT applied: the contest
  builds its defaults afresh, from today's MY STATE and the rest.

  CALL IT AFTER THE CONTEST IS SET UP. The set-up forgets statements made
  under any other contest, and one made before the first set-up is under
  none. Returns how many memories it restored. A row naming a kind, a mode or
  a key this build does not know is reported and skipped. *)
function RestoreEditedMessageMemories(aRepository: TLogRepository): integer;

(* RECORD ONE CONTEST-SCOPED STATEMENT IN THE LOG NOW, AND COMMIT IT -- Q61.

  The contest database is the one home of a contest-scoped setting, and a
  change is written when it is MADE: the Cabrillo summary window calls this
  after it applies CATEGORY-ASSISTED, -BAND, -MODE, -OPERATOR or -POWER.
  Before, such a change reached the log only through the capture at a clean
  close, so a crash lost it. uLogContestStatements.CaptureContestStatement
  is the rule (written while stated, deleted otherwise).

  AND A FUNCTION-KEY MEMORY (R2, 2026-10-23). When aCommand names one --
  'CQ CW MEMORY F3', with or without CAPTION; LogCW's
  ParseMessageMemoryCommand decides -- that key's row in the message table
  is written as the program holds it now: text, caption and edited flag,
  one row, one commit (CaptureMessageMemory). The Alt-P dialog calls this
  once per accepted edit, after it has applied both fields; LogCW's
  line-input edits call it too. The close-time capture still rewrites the
  table whole, as reconciliation. NEVER call it from a default writer or
  from the open-time replay: those are not statements, and startup must not
  become a write per memory.

  True when the row is committed. A batch /EXPORT writes nothing, like the
  close capture. With the store disabled nothing is written, a warning says
  so, and the statement holds for the session only. A write failure
  disables the store, as every write here does. Never raises. *)
function LogStoreRecordContestStatement(const aCommand: string): boolean;

(* MAKES THE LOG EXIST, and returns whether it can be relied on.  Its file
  name is uLogDatabase.LogDatabaseFileName.

  Opens the database when it exists; otherwise migrates the contest's .TRW
  once, when there is one with records; otherwise creates a new log. It
  checks integrity and writability after. A READ may be the first thing to come
  here -- a headless export, or the log window before anybody is worked --
  and gets the same log a write would. (The drift check this used to expose
  went at B5, with the second store.)

  Never raises: on failure the store disables itself and this returns False,
  which is the caller's cue to say so rather than to silently read nothing. *)
function LogStoreEnsureOpen: boolean;

(* A VERIFIED BACKUP OF THE CONTEST LOG, at aDestination.

  WHAT THIS REPLACES, AND WHY IT HAD TO. SaveLogFileToFloppy copied
  TR4W_LOG_FILENAME -- the .TRW -- with CopyFile. QSO appends stopped writing
  that file when the log became SQLite, so on a new contest the backup failed
  because there was no such file, and on an upgraded contest it SUCCEEDED while
  copying a stale log that did not contain a single contact from this session
  (Codex review, 2026-09-11). A backup that reports success and saves the wrong
  bytes is worse than one that fails, because nobody looks again.

  THREE THINGS HAVE TO BE TRUE OF A BACKUP AND ALL THREE ARE CHECKED HERE:

    IT IS CONSISTENT. TLogDatabase.SnapshotTo takes a point-in-time copy
    through SQLite, so committed contacts sitting in the -wal file are in it.
    A file copy of the .db alone is missing exactly those.

    IT OPENS AND IT IS SOUND. The staged file is opened by a SECOND, separate
    TLogDatabase and put through integrity_check and foreign_key_check before
    anything is published. An unverified backup is a belief, not a backup.

    THE PREVIOUS ONE SURVIVES UNTIL THE NEW ONE IS PROVEN. The snapshot is
    staged as <destination>.new and only renamed over the destination after it
    verifies; the file it displaces is kept as <destination>.bak. A failure at
    any point therefore leaves the last good backup exactly where it was.

  aReport is a sentence for the operator -- what happened and to which file --
  and it is set whether this succeeds or fails, because the failure is the
  case that has to be visible. Never raises. *)
function LogStoreBackup(const aDestination: string; out aReport: string): boolean;

(* THE NAME OF THE BACKUP CLEAR LOG TAKES: in aBackupDir (the program passes
  uAppPaths.BackupDir), NOT beside the log (issue #98 step 1, 2026-10-24 --
  a backup beside the log was listed by the Open dialog as a contest),
  "<log name without .db> before clear <UTC yyyy-mm-dd hhnnss>Z.db", e.g.
  "CQ-WW-SSB 2026-10-19 NY4I before clear 2026-10-23 230144Z.db".

  The log's FILE NAME only; its directory is not part of the answer. Only a
  final ".db" is removed (any case); a name with other dots keeps them, and a
  name not ending in .db keeps all of it.

  NAMES NEVER STACK. A log that is itself a pre-clear backup -- named
  "X before clear <stamp>Z.db" -- is backed up as "X before clear <new
  stamp>Z.db", not "X before clear <stamp>Z before clear <new stamp>Z.db".
  Every trailing " before clear <stamp>Z" of exactly that shape, and every
  trailing " periodic", is removed first; anything that merely contains the
  words keeps them. The base is uLogBackup.LogBackupBaseName, which the
  periodic name below shares.

  aBackupDir may or may not end in a separator. aUTC is the moment, already
  in UTC -- the caller converts, so this stays pure and a test can pin it. *)
function LogStoreClearBackupFileName(const aLogFile, aBackupDir: string;
   aUTC: TDateTime): string;

(* THE DATED NAME, FOR ANY PURPOSE: "<base><aInfix><stamp>Z.db" in aBackupDir.
  Clear Log's name above is this with ' before clear ' and is byte-identical to
  what it was; the catch-up from the multi-op server's log (Phase 1, C6) uses
  ' before catch-up '. A DATED BACKUP IS NEVER ROTATED: each is its own file, so
  neither takes the place of the periodic backup or of the other. *)
function LogStoreDatedBackupFileName(const aLogFile, aBackupDir, aInfix: string;
   aUTC: TDateTime): string;

(* THE NAME OF THE PERIODIC BACKUP (issue #98 step 2): in aBackupDir,
  "<log name without .db> periodic.db", e.g. "CQ-WW-SSB 2026-10-19 NY4I
  periodic.db". The same base as LogStoreClearBackupFileName, so names never
  stack. ONE PER LOG -- each generation replaces the last, and the one before
  it is kept as ".bak" by TLogBackup. It replaced 'logback.db', one name that
  every contest overwrote, beside the logs. *)
function LogStorePeriodicBackupFileName(const aLogFile, aBackupDir: string): string;

(* The periodic backup's name for THE LIVE LOG, in aBackupDir. Whether the
  file exists is the caller's question. *)
function LogStorePeriodicBackupPath(const aBackupDir: string): string;

(* THE PERIODIC BACKUP, every BACKUP LOG FREQUENCY QSOs and from the Backup
  Log menu: LogStoreBackup to LogStorePeriodicBackupFileName of the live log,
  in aBackupDir (the program passes uAppPaths.BackupDir; a test its own).
  aPath is the file it was written to, set either way.

  A folder that is not there fails the backup, as for Clear Log, and there is
  no fallback to beside the log.

  SYNCHRONOUS ON THE CALLER'S THREAD, which in the program is the main
  thread. That is deliberate for this step and it is LOCAL disk only: the
  copy to BACKUP DESTINATION is uBackupCopyService's, on its own thread.
  Taking the snapshot off the main thread is a later step of issue #98.
  Never raises. *)
function LogStoreBackupPeriodic(const aBackupDir: string;
   out aPath, aReport: string): boolean;

(* A VERIFIED BACKUP OF THE CONTEST LOG, TAKEN BEFORE CLEAR LOG DELETES
  ANYTHING. LogStoreBackup to LogStoreClearBackupFileName of the live log, in
  aBackupDir, at this moment in UTC. aPath is the file it was written to (set
  either way), aReport LogStoreBackup's sentence for the operator.

  A BACKUP FOLDER THAT IS NOT THERE IS A FAILED BACKUP. uAppPaths.BackupDir
  tries to create it; if it still is not a directory (a file in the way, no
  permission) this answers False and says so, and there is NO fallback to
  beside the log -- that is the place the backup was moved away from.

  SYNCHRONOUS, on the caller's thread, and it pumps no messages: Clear Log
  runs it and then deletes, with nothing able to interleave (issue #98). The
  .TRW is not read, copied or named: the source is the SQLite log only.
  Never raises. *)
function LogStoreBackupBeforeClear(const aBackupDir: string;
   out aPath, aReport: string): boolean;

(* A DATED, VERIFIED BACKUP BEFORE <PURPOSE>: the one routine behind Clear Log's
  and the catch-up's. aInfix is the purpose in the name (' before clear ',
  ' before catch-up ': uLogBackup's constants, which the never-stack rule
  knows). Same folder rule, same verification, same "no fallback beside the
  log". Never rotates the periodic backup. Never raises. *)
function LogStoreBackupBefore(const aInfix, aBackupDir: string;
   out aPath, aReport: string): boolean;

(* THE BACKUP A CATCH-UP FROM THE SERVER'S LOG TAKES FIRST (Phase 1, C6):
  "<log> before catch-up <UTC stamp>Z.db" in aBackupDir. It is NOT the periodic
  slot, so the operator's last periodic backup is not rotated into .bak, and it
  is taken whatever BACKUP LOG FREQUENCY says. *)
function LogStoreBackupBeforeCatchUp(const aBackupDir: string;
   out aPath, aReport: string): boolean;

(* IS THE CONTEST LOG SOUND? ASKED ON PURPOSE, RATHER THAN ON THE WAY PAST.

  The same integrity_check and foreign_key_check the open path runs, exposed
  so an operator can ask. NY4I, 2026-09-11: "it would be handy to have
  something on the tools menu to essentially say run verification checks ...
  one of the things that we do right now is just do an integrity verification
  on the database."

  READ-ONLY, AND IT NEVER DISABLES THE STORE. That is the whole difference
  from the check in EnsureOpen, which is fail-closed because it stands
  between a damaged file and the next QSO. This one stands between the
  operator and an answer, so a failure is REPORTED and the log keeps working
  -- refusing to log because somebody asked a question would be absurd, and
  the open-path check has already had its say about writing.

  aReport is a sentence for the operator either way, because "it is sound"
  is the answer that was asked for. Never raises. *)
function LogStoreCheckIntegrity(out aReport: string): boolean;

implementation

uses
   (* FIRST, AFTER THE RTL, ON PURPOSE: this tree resolves a name to the LAST
      unit that declares it, so these three go where every unit below still
      wins any name they share. Qualified at their call sites anyway.

      CurrentStation -- the station context scoring is handed, so the my_*
      values a QSO records are the ones scoring saw at that moment (country,
      continent, MY CQ ZONE); TStationContext is uContestBase's.
      ctyGetITUZone -- MY ITU ZONE when the operator stated none. *)
   SysUtils, Classes,
   (* THE LOCKED-LOG DIALOG (2026-10-31): QuestionDlg and mtWarning, the
     modal results, its captions, the watchdog's registry, and the schema
     version a read-only open needs. Early in the list on purpose -- every
     unit below still wins a name they share. *)
   Forms, Controls, Dialogs, uAppStrings, uLogConnectionWatch, uLogSchema,
   DateUtils, (* LocalTimeToUniversal -- the UTC stamp in a pre-clear backup's name *)
   Contnrs,   (* TObjectList -- the edited memories RestoreEditedMessageMemories reads *)
   uContestBase, uContestFactory, uCTYDAT,
   (* uLogRepository is in the INTERFACE uses now -- LogStoreRepository's
      return type. *)
   MainUnit, uLogDatabase, uLogImport,
   uContestRegistry,   (* ContestId -- a contest's stored name *)
   uLogBinaryFile,
   (* TLogBackup -- the ORDER of a backup's file operations, which is a leaf so
      the unit tests can hold it. LogStoreBackup supplies the live database. *)
   uLogBackup,
   (* The canonical sent-exchange builder -- the same one the UDP broadcast
      uses, so the database and the broadcast cannot disagree. *)
   uExchangeBuilder,
   (* The Cabrillo header's tag table -- CabrilloTagText answers from the live
      window when it is open and from the store otherwise. *)
   uCbrSum,
   (* The value and provenance accessors -- phase E1. CFGCA is gone; uCFG
      still owns CheckCommand and the renderer. *)
   uCFG,
   (* GetCQMemoryString / GetEXMemoryString -- the program's own accessors --
     and MemoryKeyId / ParseMessageMemoryCommand, which name a memory. *)
   LogCW,
   (* Tree. Its KeyId was the reason, and went to LogCW.MemoryKeyId
     (2026-10-23). LEFT IN PLACE: this tree resolves a name to the LAST unit
     declaring it, so taking a unit out of a uses clause is its own measured
     change, not a tidy-up on the way past. *)
   Tree,
   (* MyPark, which is not a Cabrillo tag: it is a per-log fact TR4W keeps as
      its own global. *)
   LOGWIND,
   (* Contest -- the live contest the program is running. Stamped onto a log at
      the moment that log is created; see StampContestOnNewLog. *)
   postunit,
   (* Settings.CommandIsContestScoped -- which commands belong to the contest
      rather than to the station. See the capture classifier below. *)
   uSettingsModel,
   (* Which contest-scoped rows the log writes, and which stored ones are
     operator statements -- section 7.8. A leaf, so the rules are tested. *)
   uLogContestStatements,
   (* RecalculateMyCountryContinentAndZoneNew -- run once the log has supplied
      the callsign; see the end of LogStoreApplyContestConfig. *)
   FContest,
   utils_text;   (* CharBufferText and LclText *)

var
   GDatabase: TLogDatabase = nil;
   GRepository: TLogRepository = nil;

   (* Tried and failed. Set once, never cleared, so a broken shadow costs one
     log line rather than one per QSO for the rest of a contest. *)
   GDisabled: boolean = False;

   GTriedToOpen: boolean = False;

   (* THE OPERATOR CHOSE "OPEN READ-ONLY" FOR A LOCKED LOG (LogStoreIsReadOnly).
     And whether the one-time notice that a write was refused has been shown. *)
   GReadOnly: boolean = False;
   GReadOnlyRefusalShown: boolean = False;

   (* When the last "the log was locked, not saved" notice was shown
     (GetTickCount64; 0 = never) -- Disable's busy branch shows at most one a
     minute. *)
   GLastBusyNotice: QWord = 0;

const
   BUSY_NOTICE_INTERVAL_MS = 60000;

var

   (* OUR STATION AS THE LAST COMMITTED APPEND RECORDED IT -- see
     LogStoreLastAppendedMyFacts -- and the one being written. *)
   GLastAppendedMyFacts: TQsoMyFacts;
   GPendingMyFacts: TQsoMyFacts;

   (* THERE IS NO "written already" FLAG, ON PURPOSE -- see EnsureOpen. *)

function LogStoreRepository: TLogRepository;
begin
   if GDisabled then
      begin
      Result := nil;
      end
   else
      begin
      Result := GRepository;
      end;
end;

procedure LogStoreStartExternalDelivery;
begin
   (* NOT FOR A READ-ONLY LOG: a worker would open its own connection and
     write, to a log the operator has just been told is locked. GReadOnly is
     read directly: LogStoreIsReadOnly is declared further down. *)
   if (externalLogger <> nil) and (GDatabase <> nil) and not GDisabled and
      not GReadOnly then
      begin
      try
         externalLogger.AfterLogCommit(GDatabase);
      except
         on E: Exception do
            begin
            (* The QSO commit has succeeded. A worker-start failure cannot
               turn that success into an alleged local save failure. *)
            logger.Error('[ExternalLogger] Could not start delivery (%s); pending work remains on disk',
               [E.ClassName]);
            end;
      end;
      end;
end;

function LogStoreIsUsable: boolean;
begin
   Result := (not GDisabled) and (GRepository <> nil);
end;

(* THE OPERATOR'S NOTICE of a store failure: the modal, unless a test has
  installed LogStoreFailureNotice to take it instead. *)
procedure ShowFailureNotice(const aText: RawByteString);
begin
   if Assigned(LogStoreFailureNotice) then
      begin
      LogStoreFailureNotice(aText);
      end
   else
      begin
      ShowMessage(aText);
      end;
end;

procedure LogStoreForgetFailureForTests;
begin
   GDisabled := False;
   GTriedToOpen := False;
   GReadOnly := False;
   GReadOnlyRefusalShown := False;
   GLastBusyNotice := 0;
   FreeAndNil(GRepository);
   FreeAndNil(GDatabase);
end;

function LogStoreIsReadOnly: boolean;
begin
   Result := GReadOnly and (GDatabase <> nil);
end;

(* A READ-ONLY SESSION REFUSES EVERY WRITE, AND SAYS SO. True when the write
  must not happen. Logged each time; put in front of the operator once,
  because each refused QSO is already reported by its caller (the "QSO NOT
  LOGGED" line and the beep). *)
function RefuseReadOnly(const aWhat: string): boolean;
begin
   Result := LogStoreIsReadOnly;
   if not Result then
      begin
      Exit;
      end;
   if logger <> nil then
      begin
      logger.Warn('[LogStore] the log was opened READ-ONLY; not %s', [aWhat]);
      end;
   if (not GReadOnlyRefusalShown) and (not tSilentExport) then
      begin
      GReadOnlyRefusalShown := True;
      ShowFailureNotice(LclText(Format(SLogReadOnlyRefused, [GDatabase.FileName])));
      end;
end;

(* BEFORE EVERY WRITE ON THE MAIN CONNECTION: END THE READ TRANSACTION sqldb
  LEFT OPEN (2026-10-31).

  THE DEFECT IT FIXES, measured. sqldb begins a transaction when a statement
  PREPARES and does not end it, so after a per-call read -- the startup walk
  of the log, a record count, a search -- the main connection sits in a read
  transaction holding an old snapshot. (The grid's range read is a kept
  statement and runs outside one; uTestLogStore's pin uses the walk.) Once the
  WRL worker commits anything, the main connection's next write fails AT ONCE
  with SQLITE_BUSY_SNAPSHOT ("database is locked"), whatever the busy
  timeout, because the old snapshot cannot become a write. That is what failed
  at 10:39:27 (the startup session-state write after the log load) and at
  10:43:25 (the close capture, with the worker already stopped), and what
  would have failed the next QSO after any delivery -- and a failed QSO used to
  disable the store for the session.

  Committing first gives the write a current snapshot. Not inside a batch
  (that is its own transaction) and not with the sequential cursor open (a
  commit closes it under its reader); in both cases the caller already ended
  the implicit transaction when it began. *)
procedure BeginMainWrite;
begin
   if (GDatabase <> nil) and (GRepository <> nil) and
      (not GRepository.InBatch) and (not GRepository.SequentialReadOpen) then
      begin
      GDatabase.EndTransaction;
      end;
end;

(* AFTER A BUSY FAILURE: undo what the attempt began. In WAL mode a busy
  failure can only come before this transaction's first write (holding the
  write lock, a connection is never busy), so nothing committed-to-be is
  lost; the cached record count is forgotten anyway. Never raises. *)
procedure RollBackAfterBusy;
begin
   try
      if (GDatabase <> nil) and GDatabase.IsOpen then
         begin
         GDatabase.Rollback;
         end;
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('[LogStore] rolling back after a busy log failed too: %s -- %s',
                         [E.ClassName, E.Message]);
            end;
         end;
   end;
   if GRepository <> nil then
      begin
      GRepository.InvalidateRecordCount;
      end;
end;

function LogStoreReadyToWrite: boolean;
begin
   (* Read-only refuses SILENTLY here: the session state is where the cursor
     was, not the operator's data, and it is saved at load and per QSO -- a
     notice for it would be noise. *)
   Result := LogStoreIsUsable and (not LogStoreIsReadOnly);
   if Result then
      begin
      BeginMainWrite;
      end;
end;

procedure LogStoreAbandonWrite;
begin
   RollBackAfterBusy;
end;

(* THE LOCKED-LOG QUESTION, natively. The answer is read by MODAL RESULT,
  never by button position: GTK draws the buttons in the other order (see
  MainUnit.YesOrNo). QuestionDlg's custom captions follow their result and
  must be UTF-8 ansi strings, hence LclText. Escape or closing the box is
  Quit: nothing proceeds on a log nobody decided about. *)
function AskAboutALockedLog(const aFileName, aDetail: string): TLogLockedChoice;
var
   answer: TModalResult;
begin
   answer := QuestionDlg(LclText(SLogLockedTitle),
                         LclText(Format(SLogLockedBody, [aFileName, aDetail])),
                         mtWarning,
                         [mrRetry,  LclText(SLogLockedRetry), 'IsDefault',
                          mrIgnore, LclText(SLogLockedReadOnly),
                          mrAbort,  LclText(SLogLockedQuit), 'IsCancel'], 0);
   if answer = mrRetry then
      begin
      Result := llcRetry;
      end
   else if answer = mrIgnore then
      begin
      Result := llcReadOnly;
      end
   else
      begin
      Result := llcQuit;
      end;
end;

(* The store connection's busy wait: LogStoreBusyTimeoutMs when a test set
  one, else the database's own default. Before Open; GDatabase exists. *)
procedure ApplyStoreBusyTimeout;
begin
   if LogStoreBusyTimeoutMs > 0 then
      begin
      GDatabase.BusyTimeoutMs := LogStoreBusyTimeoutMs;
      end;
end;

(* OPEN AN EXISTING LOG, ASKING FIRST IF IT IS LOCKED. GDatabase exists and is
  closed. Leaves GReadOnly saying how it was opened. Raises what Open raises;
  in a headless run a locked log raises (busy-coded) rather than asking. *)
procedure OpenExistingLog(const aDbName: string);
var
   probe: TLogLockProbe;
   detail, holders, said: string;
   choice: TLogLockedChoice;
begin
   GReadOnly := False;
   GReadOnlyRefusalShown := False;
   repeat
      probe := ProbeLogWriteLock(aDbName, GDatabase.BusyTimeoutMs, detail);
      if probe <> llpHeld then
         begin
         (* Free, or the probe itself failed -- the open reports that failure
           better than the probe can. A lock taken BETWEEN the probe and the
           open (its pragmas or a migration meet it) comes back here as a
           held lock, so it is asked about too rather than disabling the
           store. Anything else raises, as it always did. *)
         try
            GDatabase.Open(aDbName);
            Exit;
         except
            on E: Exception do
               begin
               if not SQLiteIsBusy(E) then
                  begin
                  raise;
                  end;
               GDatabase.Close;
               detail := E.Message;
               end;
         end;
         end;

      (* WHO? Inside this process only a registered secondary connection can
        hold it; anything else is another process. Naming that process would
        need the Restart Manager on Windows, a new DLL binding, so it is not
        done; the dialog names the likely ones instead. *)
      holders := LogWatchLongTransactions(GetTickCount64, 0);
      if holders <> '' then
         begin
         said := Format(SLogLockedHeldHere, [holders]);
         end
      else
         begin
         said := SLogLockedHeldElsewhere;
         end;
      if logger <> nil then
         begin
         logger.Error('[LogStore] %s IS LOCKED: another connection held its write ' +
                      'lock for more than %d ms (%s). %s',
                      [aDbName, GDatabase.BusyTimeoutMs, detail, said]);
         end;

      if tSilentExport then
         begin
         (* NOT busy-coded, on purpose: a failed OPEN stands the store down
           (Disable), exactly as before. Coded busy, every later store call
           would open, probe and wait again, for the rest of a batch run. *)
         raise ELogDatabaseError.CreateFmt(
            'The contest log "%s" is locked by another connection: %s',
            [aDbName, detail]);
         end;

      if Assigned(LogStoreLockedQuestion) then
         begin
         choice := LogStoreLockedQuestion(aDbName, said);
         end
      else
         begin
         choice := AskAboutALockedLog(aDbName, said);
         end;

      case choice of
         llcRetry:
            begin
            if logger <> nil then
               begin
               logger.Info('[LogStore] the operator chose Retry for the locked log');
               end;
            end;
         llcReadOnly:
            begin
            GReadOnly := True;
            end;
         llcQuit:
            begin
            if logger <> nil then
               begin
               logger.Error('[LogStore] the operator chose Quit for the locked log %s',
                            [aDbName]);
               end;
            (* As the other startup refusals (uProgramMain): a failed start. *)
            Halt(1);
            end;
      end;
   until GReadOnly;

   GDatabase.OpenReadOnly(aDbName);
   (* AN OLDER LOG CANNOT BE READ THIS WAY: bringing it to this schema is a
     write, and the repository's column checks would refuse every read. *)
   if GDatabase.SchemaVersion < LOG_SCHEMA_VERSION then
      begin
      GReadOnly := False;
      raise ELogDatabaseError.CreateFmt(
         'The contest log "%s" was written by an older TR4W and must be ' +
         'upgraded before it can be used, which is a write -- so it cannot be ' +
         'opened read-only while it is locked. Close whatever holds it and ' +
         'start TR4W again.', [aDbName]);
      end;
   if logger <> nil then
      begin
      logger.Warn('[LogStore] %s opened READ-ONLY at the operator''s choice: it ' +
                  'can be viewed and exported, and NO QSO CAN BE LOGGED this session',
                  [aDbName]);
      end;
end;

(* Report once and stand down.  Called from every except block here. *)
(* A FAILURE HERE IS NOW A LOST QSO, AND MUST BE SAID OUT LOUD.

  THIS RULE IS THE EXACT REVERSE OF THE ONE IT REPLACES, and the reversal had to
  be made deliberately or it would not have been made at all -- the code reaches
  this state unchanged and looks fine.

  While the binary log was authoritative, the right behaviour was to swallow
  everything: report once, switch off, and let the contest carry on. An operator
  must not lose a contact because a database he did not yet use would not write.
  That reasoning depended entirely on there being a fallback.

  There is none. This IS the log. Code that quietly stands down after a write
  failure is code that silently stops logging a contest -- the operator keeps
  working, the screen keeps updating, and the QSOs are going nowhere.

  So the failure is put in front of the operator, once, and the store stays
  disabled so the message is not repeated per QSO. It cannot repair itself and
  pretending otherwise would be worse: what it can do is make sure the person at
  the radio knows to stop and fix it before working anybody else. *)
procedure Disable(const aWhere: string; E: Exception);
begin
   (* A BUSY LOG IS NOT A BROKEN ONE (2026-10-31). Another connection held
     the write lock past every retry and wait, so NOTHING of this write
     reached the log -- and the log itself is fine. Disabling the store for
     the rest of the session over a lock would end the contest log for good
     over a moment's contention -- one delivery commit could cause exactly
     that before BeginMainWrite. So: rolled back, logged, the operator told that
     this change was not saved, and the store stays open for the next one.
     Unless a batch's rollback itself failed (InBatch still True): that is a
     transaction nobody can account for, and the store stands down as for
     any other failure.

     ONLY FOR A WRITE TO AN OPEN LOG (GRepository assigned). A failed OPEN
     stands down as it always did: OpenExistingLog's dialog is the retry for
     an open, and an open that stayed "not disabled" would be re-tried --
     probe, wait and all -- by every later store call.

     THE NOTICE IS RATE-LIMITED, the log line is not: the multi-op bookkeeping
     writes on network events, and a lock held for a minute must not stack up
     modals mid-contest. A refused QSO is still announced per QSO by its
     caller (the "QSO NOT LOGGED" line and the beep). *)
   if SQLiteIsBusy(E) and (GRepository <> nil) and (not GRepository.InBatch) then
      begin
      RollBackAfterBusy;
      if logger <> nil then
         begin
         logger.Error('[LogStore] THE LOG WAS LOCKED while %s: %s -- %s. NOTHING ' +
                      'of it was written. The log is not damaged and stays open; ' +
                      'the next write tries again.',
                      [aWhere, E.ClassName, E.Message]);
         end;
      if (not tSilentExport) and
         ((GLastBusyNotice = 0) or
          (GetTickCount64 - GLastBusyNotice >= BUSY_NOTICE_INTERVAL_MS)) then
         begin
         GLastBusyNotice := GetTickCount64;
         ShowFailureNotice(LclText(Format(SLogBusyNotSaved, [aWhere])));
         end;
      Exit;
      end;

   if not GDisabled then
      begin
      GDisabled := True;
      if logger <> nil then
         begin
         logger.Error('[LogStore] THE LOG IS NOT BEING WRITTEN. Failure in %s: ' +
                      '%s -- %s. There is no binary log behind this any more; ' +
                      'QSOs logged from here are NOT being saved.',
                      [aWhere, E.ClassName, E.Message]);
         end;

      (* IN FRONT OF THE OPERATOR, not only in a file nobody reads mid-contest.
         Once -- GDisabled guards it -- because a modal dialog per QSO would be
         its own kind of contest-ending.

         UNLESS THERE IS NO OPERATOR.  uProgramMain states the rule for itself:
         "A headless mode has no operator, so nothing may open a dialog and
         nothing may wait for an answer."  This one did, and it is reachable --
         /EXPORT, /RESCORE, /IMPORT and /IMPORTLOG all open the log, and any of
         them can meet a damaged or unwritable one.  A modal there does not
         report the failure, it HANGS the run until something kills it, and a
         batch job that hangs is harder to diagnose than one that fails.
         The logger.Error above is unconditional, so nothing is lost by being
         quiet here. *)
      if not tSilentExport then
         begin
         ShowFailureNotice(LclText(
         'THE CONTEST LOG IS NOT BEING SAVED.' + #13#10#13#10 +
         'Writing to the log database failed in ' + aWhere + ':' + #13#10 +
         E.ClassName + ' -- ' + E.Message + #13#10#13#10 +
         'QSOs made from now on are NOT being recorded. Stop and fix this ' +
         (* IT DOES NOT SAY "intact", WHICH IT USED TO. This dialog is now
           also shown when the log FAILED ITS INTEGRITY CHECK on open, and
           there "intact" is precisely the claim that is false -- in the one
           case where the operator most needs to be told to restore a backup.
           The location is still useful; the reassurance was never checked. *)
            'before working anyone else. The log written so far is in ' +
            LogDatabaseFileName(CharBufferText(TR4W_LOG_FILENAME)) + '.'));
         end;
      end;

   FreeAndNil(GRepository);
   FreeAndNil(GDatabase);
end;

(* THE ENTRY DECLARATION, READ ONCE, WHEN THE LOG IS MADE.

   This is tier 2 of the event-sourcing decision and it fixes a defect the
   golden corpus cannot see, because golden_diff.py compares only QSO lines and
   never the header. Measured: a headless export ships a Cabrillo file with
   CATEGORY-ASSISTED, CATEGORY-BAND and CATEGORY-OPERATOR simply ABSENT, and a
   CATEGORY-MODE of SSB where the log's own configuration says MIXED -- because
   those tags come only from tr4w.json and headless has no dialog to seed them.

   CabrilloTagText is the right source and the only one: it answers from the
   live window when it is open and from the store otherwise, which is exactly
   what made the interactive and headless paths agree in the first place.

   ONCE. Reading it again later would reintroduce the bug at the header level:
   what an entry DECLARED is a fact about the entry, not about today.

   AND NOW IT IS ONCE (Q61, 2026-10-17). EnsureOpen wrote it on EVERY open
   until then; RecordEntryDeclaration writes it only for a new or just-migrated
   log. The five category tags here (ASSISTED, BAND, MODE, OPERATOR, POWER)
   are the contest-scoped settings, which CabrilloTagText answers when the
   window is closed -- so a new log records what the New Contest dialog
   stated, not the tr4w.json header store's copy. *)
function ReadEntryDeclaration: TLogEntryDeclaration;
begin
   FillChar(Result, SizeOf(Result), 0);

   (* UTF8Encode, not an AnsiString cast, on both: these declaration fields
     are AnsiStrings and the settings are UTF-16. The cast compiles and
     silently narrows; the encode states the conversion. A callsign and a
     POTA reference are both ASCII, so nothing changes in the bytes -- what
     changes is that the build can still count what it is counting. *)
   Result.MyCall := UTF8Encode(Settings.My.Call);
   Result.MyPark := UTF8Encode(Settings.My.ResolvedPark);

   Result.CategoryOperator    := AnsiString(CabrilloTagText(ctCategoryOperator));
   Result.CategoryAssisted    := AnsiString(CabrilloTagText(ctCategoryAssisted));
   Result.CategoryPower       := AnsiString(CabrilloTagText(ctCategoryPower));
   Result.CategoryBand        := AnsiString(CabrilloTagText(ctCategoryBand));
   Result.CategoryMode        := AnsiString(CabrilloTagText(ctCategoryMode));
   Result.CategoryStation     := AnsiString(CabrilloTagText(ctCategoryStation));
   Result.CategoryTime        := AnsiString(CabrilloTagText(ctCategoryTime));
   Result.CategoryTransmitter := AnsiString(CabrilloTagText(ctCategoryTransmitter));
   Result.CategoryOverlay     := AnsiString(CabrilloTagText(ctCategoryOverlay));

   Result.Club    := AnsiString(CabrilloTagText(ctClub));
   Result.Soapbox := AnsiString(CabrilloTagText(ctSoapbox));

   Result.OpName   := AnsiString(CabrilloTagText(ctName));
   Result.Address  := AnsiString(CabrilloTagText(ctAddress));
   Result.City     := AnsiString(CabrilloTagText(ctAddressCity));
   Result.State    := AnsiString(CabrilloTagText(ctAddressStateProvince));
   Result.Postcode := AnsiString(CabrilloTagText(ctAddressPostalcode));
   Result.Country  := AnsiString(CabrilloTagText(ctAddressCountry));
   Result.Email    := AnsiString(CabrilloTagText(ctEmail));
end;

(* THE CONFIGURATION AND THE PROGRAM MESSAGES, INTO THE LOG -- PHASE E1.

  NY4I: "the configuration info for a database should go into the database file
  too. That includes anything that goes into the .CFG file including Program
  Messages (Alt-P)... when done, the .cfg file should not be necessary."

  E1 WRITES. Nothing reads these yet, and that split is deliberate: writing them
  cannot change how the program behaves, so it can be verified by looking at a
  real log rather than by trusting a reading of the code. E2 makes them
  authoritative, and that is the step that can break a contest.

  EVERY STATION ROW, AND EVERY CONTEST-SCOPED ROW THE OPERATOR STATED. The
  station rows are a record of the station config and are applied by nothing.
  A contest-scoped row is written only while TR4WSettings.CommandIsStated says
  the operator stated it, and deleted otherwise -- absence means the contest
  decides (2026-10-01, section 7.8; see uLogContestStatements). That is not
  this unit choosing which settings matter: the operator's statement is the
  test, and it is recorded where the statement is made.

  THE SOURCE COLUMN IS NOT DESCRIPTIVE. With no .cfg left, 'contest' versus
  'station' is the only thing that will say an explicit contest setting outranks
  the station default. uCFG already tracks it -- CommandCameFromContestCFG --
  and this asks rather than re-deriving, because a second derivation of a
  precedence rule is a second answer waiting to differ.

  ONE TRANSACTION for four hundred-odd upserts. Left to itself sqldb would
  commit each one, and under WAL that is a flush apiece on a path that runs at
  every log open. *)
(* 'CW' or 'PHONE' -- the two values the message table's mode column is
  specified to hold.  ADIFModeString is the wrong source for this: it answers
  'SSB' for Phone, which is the ADIF spelling and not this schema's. *)
function MessageModeName(aMode: ModeType): AnsiString;
begin
   if aMode = CW then
      begin
      Result := 'CW';
      end
   else
      begin
      Result := 'PHONE';
      end;
end;

const
   (* THE TWO MODES THE message TABLE HOLDS, and NOT `CW to Phone`. ModeType
     runs CW, Digital, Phone, and the memory accessors fold Digital into CW --
     so walking the range wrote each CW memory a second time under the PHONE
     key (MessageModeName(Digital) is 'PHONE'), where it stood whenever the
     Phone memory was empty. With an edited flag on the row that would have
     restored CW text into a Phone key. *)
   MESSAGE_MODES: array[0..1] of ModeType = (CW, Phone);

(* ONE MEMORY, AS THE LOG RECORDS IT -- the single-row rule, which
  CaptureMessageMemories loops over and LogStoreRecordContestStatement
  applies to the one key an accepted edit named (R2, 2026-10-23), as
  CaptureContestStatement is for a contest setting. One row carries the
  text, the caption and the edited flag together, so a key is recorded
  whole or not at all.

  AN EMPTY MEMORY NOBODY EDITED IS NOTHING TO RECORD. An EDITED empty memory
  is the operator saying it is empty, and is kept so the open restores it.
  An immediate record always follows an edit, which latches the key, so it
  always writes; a row that should no longer exist is the close capture's
  to clear, and it rewrites the table whole.

  aMode is the memory ROW, CW or Phone; ParseMessageMemoryCommand and
  MESSAGE_MODES both hand it one. KeyId's '' (not a function key) records
  nothing -- the message table is keyed (kind, mode, key_id), so every
  unnamed code would collapse onto one row. Does not commit. *)
procedure CaptureMessageMemory(aRepository: TLogRepository; aCQBank: boolean;
                               aMode: ModeType; aKey: AnsiChar);
var
   keyName: AnsiString;
   kind: AnsiString;
   text: AnsiString;
   caption: AnsiString;
   edited: boolean;
begin
   keyName := MemoryKeyId(aKey);
   if (keyName = '') or ((aMode <> CW) and (aMode <> Phone)) then
      begin
      Exit;
      end;

   if aCQBank then
      begin
      kind := 'CQ';
      text := AnsiString(GetCQMemoryString(aMode, aKey));
      caption := CQCaptionMemory[aMode, aKey];
      edited := CQMemoryIsOperatorStated(aMode, aKey);
      end
   else
      begin
      kind := 'EX';
      text := AnsiString(GetEXMemoryString(aMode, aKey));
      caption := EXCaptionMemory[aMode, aKey];
      edited := EXMemoryIsOperatorStated(aMode, aKey);
      end;

   if (text = '') and (not edited) then
      begin
      Exit;
      end;
   aRepository.SaveMessage(kind, MessageModeName(aMode), keyName, text,
                           caption, edited);
end;

procedure CaptureMessageMemories(aRepository: TLogRepository);
var
   m: integer;
   mode: ModeType;
   key: AnsiChar;
begin
   (* REWRITTEN WHOLE. An upsert alone left a row behind for a memory that
     was emptied, or that a different contest's set-up no longer counts as
     edited -- and a stale row flagged edited would be restored. It also
     clears any row under a key this build cannot name. *)
   aRepository.DeleteAllMessages;

   for m := Low(MESSAGE_MODES) to High(MESSAGE_MODES) do
      begin
      mode := MESSAGE_MODES[m];
      (* F1..AltF12 is a CHARACTER range, not an enumeration of function
        keys, so it walks codes that are not function keys at all; the
        single-row rule records nothing for those (the first capture once
        put a 'CQ/CW' "QRL?" under an empty key that way). *)
      for key := F1 to AltF12 do
         begin
         CaptureMessageMemory(aRepository, True, mode, key);
         CaptureMessageMemory(aRepository, False, mode, key);
         end;
      end;
end;

function RestoreEditedMessageMemories(aRepository: TLogRepository): integer;
var
   rows: TObjectList;
   row: TLogStoredMessage;
   i: integer;
   m: integer;
   mode: ModeType;
   key: AnsiChar;
   k: AnsiChar;
   known: boolean;
begin
   Result := 0;
   rows := TObjectList.Create(True);
   try
      aRepository.LoadEditedMessages(rows);
      for i := 0 to rows.Count - 1 do
         begin
         row := TLogStoredMessage(rows[i]);

         (* THE ROW'S NAMES BACK TO THE PROGRAM'S -- the inverse of the
           capture's MessageModeName and KeyId, asked of the same two. *)
         known := False;
         mode := CW;
         for m := Low(MESSAGE_MODES) to High(MESSAGE_MODES) do
            begin
            if MessageModeName(MESSAGE_MODES[m]) = row.Mode then
               begin
               mode := MESSAGE_MODES[m];
               known := True;
               end;
            end;
         key := F1;
         if known then
            begin
            known := False;
            for k := F1 to AltF12 do
               begin
               if (MemoryKeyId(k) <> '') and
                  (MemoryKeyId(k) = row.KeyId) then
                  begin
                  key := k;
                  known := True;
                  end;
               end;
            end;
         if known then
            begin
            known := (row.Kind = 'CQ') or (row.Kind = 'EX');
            end;
         if not known then
            begin
            if logger <> nil then
               begin
               logger.Warn('[LogStore] an edited memory %s/%s/%s names nothing ' +
                           'this build knows -- not restored',
                           [row.Kind, row.Mode, row.KeyId]);
               end;
            Continue;
            end;

         (* AS THE OPERATOR'S EDIT IS APPLIED: the text, the caption, and the
           latch -- which keeps it through a re-selection of this contest
           and flags it edited again at the next close. *)
         if row.Kind = 'CQ' then
            begin
            SetCQMemoryString(mode, key, ShortString(row.Text));
            SetCQCaptionMemoryString(mode, key, ShortString(row.Caption));
            NoteCQMemoryStatedByOperator(mode, key);
            end
         else
            begin
            SetEXMemoryString(mode, key, ShortString(row.Text));
            SetEXCaptionMemoryString(mode, key, ShortString(row.Caption));
            NoteEXMemoryStatedByOperator(mode, key);
            end;
         Inc(Result);
         end;
   finally
      rows.Free;
   end;
end;

procedure CaptureConfiguration(const aWhy: string);
var
   i: integer;
   cmd: string;
   src: AnsiString;
   value: AnsiString;
   renderable: boolean;
   Column: LogColumnsType;
   saved: integer;
   (* The contest-scoped settings that have left the array -- see below. *)
   names: TStringList;
   modelValue: string;
begin
   saved := 0;

   (* ONE WALK, OVER THE SETTINGS OBJECT -- 2026-09-14.

     TWO LOOPS STOOD HERE and they had to, because a setting was in one of two
     places: a CFGCA row, or the model. The first walked the array by index and
     the second walked Settings.CommandNames for the contest-scoped settings
     the array could no longer reach -- a hole that was silent for as long as
     it existed, because a contest-scoped group is deliberately excluded from
     settings/tr4w.json and so had nowhere else to persist.

     THE ARRAY IS GONE, so there is one place and one walk. Every rule the
     first loop applied is kept below; the skips it made for a nil crCommand
     and a csRem row have no subject any more.

     WHY THIS ROUTINE EXISTS AT ALL: the config table in the log is the
     contest's point-in-time record -- what the settings WERE while this log
     was written -- so reopening it next year scores it the way it was scored
     then. *)
   names := Settings.CommandNames;
   try
      for i := 0 to names.Count - 1 do
         begin
         cmd := string(names[i]);
         if cmd = '' then
            begin
            Continue;
            end;

         (* A CREDENTIAL IS NEVER CAPTURED -- 2026-10-29, and FIRST, ahead of
           every scope test, so no arm below can write one. This walk wrote
           HAMSCORE PASSWORD and SERVER PASSWORD into every log as 'station'
           rows, in the clear, in a file operators share. A password is the
           OS vault's. DeleteStoredSecrets, below, removes the rows an older
           build left. See uLogContestStatements. *)
         if Settings.CommandIsSecret(cmd) then
            begin
            Continue;
            end;

         (* CONTEST IS NOT CAPTURED. NY4I, 2026-09-03: "the config row has
           outlived its usefulness since we can store that in the .db file."

           The contest table holds contest_type, written once when the log is
           created and never recomputed. This row was a SECOND copy, rewritten
           on every clean exit from whatever the running program believed at
           the time -- so one bad session poisoned it permanently. That is not
           hypothetical: NY4I's log opened without a contest, exited cleanly,
           and this wrote CONTEST = DUMMY CONTEST into it. Every open
           afterwards read it back and refused it, and the log could never be
           used again while the contest table said CQ-WW-SSB the whole time.

           One of the two was a fact about the log, the other a fact about a
           session. Only one of them belongs in the file. *)
         if cmd = 'CONTEST' then
            begin
            Continue;
            end;

         (* A CONTEST-SCOPED SETTING IS CAPTURED BELOW, AND ONLY IF THE
           OPERATOR STATED IT -- 2026-10-01, docs/CONTEST_OWNERSHIP_DESIGN.md
           section 7.8. This walk wrote its current value unconditionally,
           which for the contest-rule settings is the constructor's 'NONE' /
           'UNKNOWN' (FoundContest sets the globals, not these properties) --
           so every log recorded defaults, not rules, and reread them as
           though they had been chosen. See uLogContestStatements. *)
         if Settings.CommandIsContestScoped(cmd) then
            begin
            Continue;
            end;

         (* A STATION FACT A CONTEST MAY OVERRIDE (MY STATE, MY ZONE, MY GRID
           ...) IS CAPTURED BELOW TOO -- design 7.12. Its row is the contest's
           override, as 'contest', while one is stated, and otherwise the
           station's value as 'station'. See CaptureStationFactRows. *)
         if Settings.CommandIsContestOverridable(cmd) then
            begin
            Continue;
            end;

         (* A CONTEST-SCOPED SETTING NEVER REACHES HERE -- it is skipped above
           and captured by CaptureContestStatements, always as 'contest' and
           only while stated. The 'or contest-scoped' arm that stood in this
           test is gone with it.

           MY CALL IS A CONTEST SETTING AND HAS TO BE NAMED AS ONE.
           CommandCameFromContestCFG says no for it, and not because it came
           from the station config: LogCfg SKIPS the "MY CALL" line while
           reading a .cfg when a callsign is already set, so
           NoteCommandFromContestCFG never fires and the row defaults to
           'station'. It is the ENTRY'S callsign -- which is why the contest
           row already stores it -- and without it here, a log opened with an
           empty .cfg halts on "No callsign specified" while its own callsign
           sits in the config table unread. *)
         if CommandCameFromContestCFG(cmd)
            or (cmd = 'MY CALL') then
            begin
            src := AnsiString('contest');
            end
         else
            begin
            src := AnsiString('station');
            end;

         (* A COMMAND WHOSE VALUE CANNOT BE WRITTEN DOWN IS NOT CAPTURED.

           THIS HUNG THE PROGRAM, and headlessly it hung it forever. REMINDER
           was an ACTION, not a setting -- applying it called
           QuickEditResponse('Enter time for reminder') and waited for a human
           -- so it was captured with an empty value, re-applied on every
           open, and a batch /EXPORT sat at a prompt nobody could see.
           Measured on the golden corpus: general_qso aborted every run.

           THE RENDERER SAYS SO through aRenderable, which is the distinction
           that was missing: '' is a legitimate value for a string setting,
           so returning '' could not report the difference. *)
         value := AnsiString(CFGCommandValueAsString(cmd, renderable));
         if not renderable then
            begin
            Continue;
            end;

         GRepository.SaveConfigValue(AnsiString(cmd), value, src);
         Inc(saved);
         end;
   finally
      names.Free;
   end;

   (* THE CONTEST-SCOPED SETTINGS: written while stated, deleted otherwise,
     and the log marked as holding statements only. *)
   saved := saved + CaptureContestStatements(Settings, GRepository,
                                             CommandIsRetired);

   (* THE STATION FACTS: the contest's override while stated, else the
     station's value as a record. *)
   saved := saved + CaptureStationFactRows(Settings, GRepository);

   (* THE EDITABLE-LOG COLUMN WIDTHS.

     These are not CommandsArray rows -- CheckCommand special-cases
     'COLUMN WIDTH <token>' (uCFG.pas:1664) rather than holding one row per
     column -- so the loop above cannot reach them and they need naming here,
     exactly as the function-key memories do below.

     THEY USED TO LIVE IN THE CONTEST .cfg, written by
     MainUnit.SaveColumnWidthToConfig. That write is gone: TR4W_CFG_FILENAME is
     a .db now, and asking the INI API to rewrite a SQLite file froze the
     program. Capturing them keeps the behaviour an operator sees -- widths
     survive a restart, and they are per contest, because they are in the
     contest's own file.

     SOURCE 'contest' BECAUSE THAT IS WHERE THEY CAME FROM, and because the
     startup apply reads contest-scoped rows. A width recorded as 'station'
     would be captured and never restored, which is worse than not capturing
     it: it looks saved. *)
   for Column := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if not ColumnsArray[Column].Enable then
         begin
         Continue;
         end;

      (* ONLY A WIDTH THE OPERATOR ACTUALLY SET, AND IN PIXELS.

        THIS CAPTURED THE WRONG NUMBER AND BLANKED THE MAIN LOG. It wrote
        ColumnsArray[].Width, which is a COUNT OF CHARACTERS -- 9, 3, 12 -- and
        the value in a COLUMN WIDTH command is a PIXEL width: CheckCommand puts
        it in ColumnWidthOverride and MainUnit.pas:9514 hands that straight to
        ListView_SetColumnWidth. So every column came back a few pixels wide and
        the editable log rendered as blank paper with a striped edge (NY4I,
        2026-09-03, with a screenshot).

        ColumnWidthOverride IS THE RIGHT SOURCE, and zero is the right reason to
        skip: the override is only set when SaveColumnWidthToConfig runs, which
        is only when a divider is dragged or double-clicked. That is also what
        the old .cfg held -- a COLUMN WIDTH line existed for the columns an
        operator had touched and for no others, so an untouched column keeps the
        character-count default rather than being pinned to whatever pixel width
        it happened to have. *)
      if ColumnWidthOverride[Column] <= 0 then
         begin
         Continue;
         end;

      GRepository.SaveConfigValue(
         AnsiString('COLUMN WIDTH ' + ColumnCanonicalName[Column]),
         AnsiString(IntToStr(ColumnWidthOverride[Column])),
         'contest');
      end;

   (* THE FUNCTION-KEY MEMORIES, flagged where the operator edited them. *)
   CaptureMessageMemories(GRepository);

   (* AND NO CREDENTIAL IS LEFT IN THE LOG, LAST, so it holds whatever wrote
     above: a secret row an older build captured is deleted here, inside this
     transaction, at the log's first clean close under this build. *)
   DeleteStoredSecrets(Settings, GRepository);

   GRepository.Commit;

   (* SAY HOW MANY, because this is the other half of the conversion an
     operator is shown.  A contest .cfg is read once and captured HERE, into
     the log -- so without a line the .cfg-to-database direction happens in
     total silence, and the only way to tell it worked was to restart and see
     whether the contest came back.

     ON CLOSE, so it lands at the end of the run rather than beside the
     tr4w.ini lines at the start.  That is where it belongs: the capture
     records what the session ENDED with, not what it read. *)
   if logger <> nil then
      begin
      logger.Info('[Convert] %d configuration row(s) %s', [saved, aWhy]);
      end;
end;

function LogStoreFileName: string;
begin
   (* The rule itself is uLogDatabase.LogDatabaseFileName -- it outlives this
     unit, which B5 deletes. *)
   Result := LogDatabaseFileName(CharBufferText(TR4W_LOG_FILENAME));
end;

(* DOES A BINARY LOG WITH QSOs IN IT EXIST?

  A yes/no question now, not a count. Counts were what the drift check compared,
  and the drift check is gone with the second store -- see EnsureOpen. The only
  remaining caller asks whether there is anything to MIGRATE. *)
function BinaryLogHasRecords: boolean;
var
   reader: TLogBinaryReader;
begin
   reader := TLogBinaryReader.Create(CharBufferText(TR4W_LOG_FILENAME));
   try
      Result := (reader.Status = lbOK) and (reader.ExpectedRecords > 0);
   finally
      reader.Free;
   end;
end;

(* True when the log is open and usable.

  aRebuilt is True on the one call that MIGRATED the log from a binary .TRW.
  It says what happened to the log, not what the caller should do about the
  write it is making: the .TRW is import-only, so it never holds a QSO this
  build logged, and every write proceeds as written. Read here (the migrated
  log is captured and declared as a new one) and logged by
  LogStoreUpdateQSOAtIndex.

  ~~aAppendPending~~ went 2026-10-17. It told the old drift check that the
  .TRW was one record ahead during an append -- because tAddQSOToLog wrote
  the .TRW first -- and both that write and the drift check were gone; the
  parameter was read by nothing. *)
function EnsureOpen(out aRebuilt: boolean): boolean;
var
   dbName: string;
   trwCount: Int64;
   expected: Int64;
   (* True only on the open that CREATED this log -- see the capture below. *)
   isNewLog: boolean;
   res: TLogImportResult;
   integrity: TIntegrityResult;
   writable: TIntegrityResult;
   damaged: Exception;

   (* Returns False rather than raising: the caller is a try/except that would
     only disable the shadow anyway, and raising here meant constructing an
     Exception from a UnicodeString, which narrows. *)
   function RebuildFromBinary(const aWhy: string): boolean;
   begin
      if logger <> nil then
         begin
         logger.Info('[LogStore] building %s from the binary log (%s)',
                     [dbName, aWhy]);
         end;
      FreeAndNil(GRepository);
      FreeAndNil(GDatabase);
      if FileExists(dbName) then
         begin
         DeleteFile(dbName);
         end;
      res := ImportBinaryLog(CharBufferText(TR4W_LOG_FILENAME), dbName);

      (* AN EARLIER MIGRATION DIED PART WAY, AND THIS ONE STARTED AGAIN.
        ImportBinaryLog builds under a staged name and publishes by rename, so
        a crash mid-import leaves that staged file and no log -- which is why
        we are here at all -- and it has just been discarded. Nothing is lost:
        the .TRW it came from is what is being imported again.

        AT ERROR LEVEL, ON PURPOSE. It is a recovery rather than a failure,
        but it is the one trace an operator has that a previous session ended
        badly, and DEBUG LOG LEVEL = ERROR must not hide it. *)
      if (res.DiscardedStaged <> '') and (logger <> nil) then
         begin
         logger.Error('[LogStore] RECOVERED FROM AN INTERRUPTED MIGRATION: ' +
                      'discarded the unfinished import %s and migrated %s ' +
                      'again from the start', [res.DiscardedStaged, dbName]);
         end;

      Result := res.Ok;
      if (not Result) and (logger <> nil) then
         begin
         logger.Error('[LogStore] could not build the log: %s', [res.Message]);
         end;
   end;

begin
   aRebuilt := False;
   Result := LogStoreIsUsable;
   if Result or GDisabled then
      begin
      Exit;
      end;

   GTriedToOpen := True;
   isNewLog := False;
   try
      dbName := LogDatabaseFileName(CharBufferText(TR4W_LOG_FILENAME));

      (* THE DATABASE IS THE LOG. IT IS NOT DERIVED FROM ANYTHING.

         Until B5 this opened the .TRW alongside, compared record counts, and
         reconciled -- rebuilding the database when the counts disagreed, or
         moving it aside when the binary log had shrunk. All of that existed
         because there were TWO LIVE STORES and something had to decide which
         was right on every open.

         There is one now, so there is nothing to decide. The drift check, the
         orphan rename and the count comparison are gone, and with them a whole
         class of failure: they could not tell "the .TRW was lost" from "the log
         was reset", and either answer destroyed or resurrected a contest.

         WHAT REMAINS IS MIGRATION, WHICH IS A DIFFERENT THING. A one-time
         import when the database does not exist and a binary log does. It runs
         ONCE, when an operator opens a 4.x or pre-B5 contest for the first
         time, and never again -- because after it the database exists. That is
         not reconciliation; nothing is being kept in step. *)
      GDatabase := TLogDatabase.Create;
      ApplyStoreBusyTimeout;

      if FileExists(dbName) then
         begin
         (* Probed first, and the operator asked if it is locked: Retry,
           Read-only, or Quit (2026-10-31). *)
         OpenExistingLog(dbName);
         end
      else if BinaryLogHasRecords then
         begin
         (* AN EXISTING CONTEST, OPENED BY THIS BUILD FOR THE FIRST TIME.
            Migrate it rather than presenting the operator with an empty log
            beside a .TRW full of their QSOs. Once -- after this the database
            exists and the binary log is never consulted again. *)
         FreeAndNil(GDatabase);
         if not RebuildFromBinary('migrating an existing binary log') then
            begin
            GDisabled := True;
            Result := False;
            Exit;
            end;
         aRebuilt := True;
         GDatabase := TLogDatabase.Create;
         ApplyStoreBusyTimeout;
         GDatabase.Open(dbName);
         end
      else
         begin
         (* A NEW CONTEST. CreateNew, not Open: Open REFUSES a missing file on
            purpose -- "an empty log that opens cleanly hides the real mistake"
            -- and that refusal is right for every other caller. Creating one
            is a decision, and this is the one place entitled to make it. *)
         GDatabase.CreateNew(dbName);
         isNewLog := True;
         end;

      (* WHICH FILE IS THIS LOG? NY4I asked for it, 2026-09-02: "The log should
        show the name of the database file. If not, it should."

        IT IS THE FIRST QUESTION EVERY REPORT NEEDS and nothing answered it.
        Diagnosing an edit that would not stick meant working out the path from
        the contest name; if a write and a read ever land on different files,
        this line is what shows it. Logged ONCE per open, not per statement. *)
      if logger <> nil then
         begin
         logger.Info('[LogStore] log database: %s', [dbName]);
         end;

      (* LOOK AT IT BEFORE WRITING TO IT.

        CheckIntegrity was implemented and had NO CALLER anywhere in the
        program (Codex review, 2026-09-11) -- so the one moment it exists for,
        opening a log after a crash or a bad shutdown, went unchecked and the
        next QSO was appended to whatever was there.

        A CHECK CANNOT REPAIR ANYTHING. What it can do is decide, once, that
        this log is not fit to be written to, while the damage is still as
        small as it is ever going to be. Appending to a damaged database makes
        recovery harder, and the operator finds out at the end of the contest.

        SO A FAILURE DISABLES THE STORE, which is fail-closed: with the return
        value of LogStoreAppendQSO now honoured, that means the program refuses
        to acknowledge QSOs rather than quietly adding them to a broken file.
        That is a hard stop mid-contest and it is the correct one -- the
        alternative is an operator logging into rubble for six hours.

        THE COST IS ONE CHECK PER OPEN, not per QSO: integrity_check walks the
        pages and foreign_key_check walks the references, both at startup on a
        file that is a few megabytes at the end of a large contest. *)
      integrity := GDatabase.CheckIntegrity;
      if not integrity.Ok then
         begin
         if logger <> nil then
            begin
            logger.Error('[LogStore] %s FAILED its integrity check: %s',
                         [dbName, integrity.Report]);
            end;
         (* OWNED HERE. Disable's parameter is normally the ACTIVE exception,
           which the runtime owns and frees; this one is manufactured to carry
           a sentence, so it is freed on the way out. *)
         damaged := Exception.Create(AnsiString(
            'The contest log failed its integrity check. It has NOT been '
            + 'written to. Restore the most recent backup. Details are in '
            + 'tr4w.log.'));
         try
            Disable('checking the log on open', damaged);
         finally
            damaged.Free;
         end;

         Result := False;
         Exit;
         end;

      (* AND CAN IT BE WRITTEN TO?  The integrity check above says the file is
        not damaged; it says nothing about whether the next QSO can land in it.

        NY4I, 2026-09-17: *"ensuring the database is writable isn't a bad
        idea."*  SQLite opens a read-only file without complaint and fails only
        on the first write -- which in a contest is the first contact, at the
        worst possible moment.  Asking now costs one inert header write, and
        answers it while nothing has been lost.

        FAIL CLOSED, exactly as the integrity check does.  Warning and
        continuing would be the silent downgrade this tree keeps deleting: the
        operator would log a contest into a file that cannot accept it, and
        find out at the end. *)
      (* NOT ASKED OF A LOG THE OPERATOR CHOSE TO OPEN READ-ONLY: it is
        locked, and its connection cannot write by construction. *)
      writable.Ok := True;
      writable.Report := '';
      if not GReadOnly then
         begin
         writable := GDatabase.CheckWritable;
         end;
      if not writable.Ok then
         begin
         if logger <> nil then
            begin
            logger.Error('[LogStore] %s IS NOT WRITABLE: %s',
                         [dbName, writable.Report]);
            end;
         (* Owned here, like the integrity one a few lines up: manufactured to
           carry a sentence, so it is freed on the way out. *)
         damaged := Exception.Create(AnsiString(
            'The contest log cannot be written to. It has NOT been changed. '
            + writable.Report + ' Details are in tr4w.log.'));
         try
            Disable('checking that the log is writable', damaged);
         finally
            damaged.Free;
         end;

         Result := False;
         Exit;
         end;

      GRepository := TLogRepository.Create(GDatabase);

      (* ~~GRepository.SetEntryDeclaration(ReadEntryDeclaration)~~ stood here
        and ran on EVERY open -- see the entry declaration below the contest
        stamp, which is where it runs now, and only for a new log. *)

      (* THE CONFIGURATION IS CAPTURED WHEN THE LOG IS MADE, AND ONLY THEN.

         E1 refreshed it on every open, which was right while nothing read it
         back. It is exactly wrong now that something does: the stored
         configuration IS the contest's configuration, so overwriting it at
         open with whatever the .cfg happens to say would hand authority back
         to the file this work exists to retire -- and would silently discard
         anything the operator had changed.

         A MIGRATED LOG COUNTS AS NEW, and must: it has just been built from a
         binary log that carried no configuration at all, so the .cfg read at
         startup is the only description of that contest in existence. Skipping
         the capture there would leave it with none.

         Changes made DURING a contest are written back at LogStoreClose --
         see there, and see the limitation it states. *)
      if isNewLog or aRebuilt then
         begin
         (* THE REASON IS PART OF THE LINE, because this call and the one at
           close look identical in a log and mean opposite things. THIS one is
           the CONVERSION -- it happens once, when the database is created,
           and it is what carries a contest .cfg into the log. *)
         CaptureConfiguration('captured from the contest .cfg as the log was created');
         end;

      (* AND THE CONTEST ITSELF, WHICH NOTHING WROTE.

        THIS IS WHY EVERY US CALLSIGN CAME UP DX ON A CONTEST CREATED BY THE
        NEW CONTEST DIALOG. SetContest had exactly two callers -- the binary
        import, and the QSO append -- so a log made by the dialog carried no
        contest row until its FIRST QSO was logged. Reopening it before then
        left GRepository.LogContest = DUMMYCONTEST, LogStoreApplyContestConfig
        skipped its "apply the contest first" arm, FoundContest never ran, the
        domestic country list stayed empty, and DomesticCountryCall answers
        "not domestic" for an empty list -- which MEANS DX.

        AND IT COULD NOT HEAL ITSELF, because the one thing that would have
        written the row is logging a QSO, which is the thing a contest with no
        contest cannot do. NY4I, Linux Mint 2026-09-09: AF4O scored as DX in
        ARRL Field Day, on a log whose config table held 404 rows and whose
        contest table held none.

        THE CONFIG TABLE CANNOT COVER FOR IT. CaptureConfiguration SKIPS the
        CONTEST command deliberately -- see the note there -- because a
        captured row is a fact about a SESSION and one bad session poisoned it
        permanently. The contest row is a fact about the LOG. That division is
        right; what was missing is that nothing wrote the second one.

        WHY HERE. This is the one place entitled to decide a log is new, and it
        sits beside the capture that already runs on exactly the same
        condition -- "the configuration is captured when the log is made, and
        only then". The contest is part of that configuration in every sense
        except which table it lands in.

        THREE GUARDS, and each rules out a way of writing something false:

          isNewLog only -- NOT aRebuilt. An imported log was stamped by
          ImportBinaryLog from its first record, which is a fact about the
          file. The running program's Contest is a fact about this session and
          must not overwrite it.

          LogContest = DUMMYCONTEST -- belt and braces. If anything already
          answered, it stays.

          Contest <> DUMMYCONTEST -- the poisoning guard. A log opened with no
          contest must not have "no contest" written into it as though that
          were the answer. Better an empty row than a wrong one: an empty row
          is still fixable by the dialog. *)
      if isNewLog and
         (GRepository.LogContest = NoContest) and
         (Contest <> NoContest) then
         begin
         GRepository.SetContest(Contest);
         (* COMMITTED, AND THE FIRST VERSION WAS NOT.

           SetContest runs its INSERT and stops; every other caller commits
           afterwards as part of the larger thing it was doing, so the missing
           Commit here was invisible in the source and visible only in the
           file. Measured on the Mint box before this line existed: the log
           said "stamped the new log as contest ARRL-FD" and the contest table
           held no row -- the write sat in the write-ahead log and was rolled
           back when the process ended.

           A REPORT THAT NAMES A WRITE THAT DID NOT HAPPEN IS WORSE THAN NO
           REPORT, because the log becomes evidence for the wrong conclusion. *)
         GRepository.Commit;
         if logger <> nil then
            begin
            logger.Info('[LogStore] stamped the new log as contest %s',
                        [ContestId(Contest)]);
            end;
         end;

      (* THE ENTRY DECLARATION, ONCE: ON THE OPEN THAT MADE THE LOG -- Q61.

        It was written on every open, just after the repository was made, so
        a reopened log
        carried today's values instead of what the entry declared; and for a
        new log it ran BEFORE the contest stamp above, when there was no row
        for its UPDATE to land on. So it runs here, after the stamp, and the
        guard is the leaf's (RecordEntryDeclaration), where it is tested.

        A MIGRATED LOG COUNTS AS NEW, for the reason the configuration capture
        gives: a binary log carries no declaration, so this is the only one it
        will ever have. Its contest row was written by the import. *)
      if RecordEntryDeclaration(GRepository, isNewLog or aRebuilt,
                                ReadEntryDeclaration) then
         begin
         GRepository.Commit;
         if logger <> nil then
            begin
            logger.Info('[LogStore] recorded the entry declaration of the new log');
            end;
         end
      else if (isNewLog or aRebuilt) and (logger <> nil) then
         begin
         (* A NEW LOG OPENED WITH NO CONTEST has no contest row -- the stamp
           above refuses to write "no contest" -- so there is nowhere to put
           the declaration. Said, because the declaration is then simply
           absent from this log. *)
         logger.Info('[LogStore] the new log has no contest row yet, so its ' +
                     'entry declaration is not recorded');
         end;

      Result := True;
   except
      on E: Exception do
         begin
         Disable('opening the log', E);
         Result := False;
         end;
   end;
end;

function LogStoreClearAllQSOs: boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      if RefuseReadOnly('clearing the log') then
         begin
         Exit;
         end;
      BeginMainWrite;
      GRepository.DeleteAllQSOs;
      GRepository.Commit;
      Result := True;
   except
      on E: Exception do
         begin
         (* Disabled rather than raised: failing to clear must not take the
           program down mid-contest, and Disable is how every other failure in
           this unit reports itself. The caller sees False. *)
         Disable('LogStoreClearAllQSOs', E);
         end;
   end;
end;

function LogStoreCheckIntegrity(out aReport: string): boolean;
var
   verdict: TIntegrityResult;
begin
   Result := False;
   aReport := '';

   if not LogStoreEnsureOpen then
      begin
      aReport := 'The contest log is not open, so it could not be checked. '
                 + 'Details are in tr4w.log.';
      Exit;
      end;

   try
      verdict := GDatabase.CheckIntegrity;
   except
      (* A CHECK THAT RAISES HAS STILL ANSWERED THE QUESTION, and the answer
        is no. Swallowing it into a report rather than letting it out keeps
        a menu item from taking the program down. *)
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('[LogStore] the on-demand integrity check raised %s: %s',
                         [AnsiString(E.ClassName), AnsiString(E.Message)]);
            end;
         aReport := 'The check could not be completed: ' + E.Message;
         Exit;
         end;
   end;

   Result := verdict.Ok;
   if Result then
      begin
      aReport := LogStoreFileName + ' passed integrity_check and '
                 + 'foreign_key_check.';
      end
   else
      begin
      if logger <> nil then
         begin
         logger.Error('[LogStore] on-demand integrity check FAILED: %s',
                      [AnsiString(verdict.Report)]);
         end;
      aReport := LogStoreFileName + ' FAILED its integrity check. Stop logging and restore the most recent backup.' + sLineBreak + verdict.Report;
      end;
end;

function LogStoreCheckExchangeIds(out aReport: string): boolean;
const
   (* Enough to find them in the log window, not a listing. *)
   SAMPLE_SIZE = 5;
var
   missing: TMissingExchangeIds;
begin
   Result := False;
   aReport := '';

   if not LogStoreEnsureOpen then
      begin
      aReport := 'The contest log is not open, so it could not be checked. '
                 + 'Details are in tr4w.log.';
      Exit;
      end;

   try
      missing := GRepository.QSOsWithoutExchangeId(SAMPLE_SIZE);
   except
      (* As the integrity check: a check that raises has answered, and the
        answer is no. *)
      on E: Exception do
         begin
         aReport := 'The check could not be completed: ' + E.Message;
         Exit;
         end;
   end;

   if missing.Count = 0 then
      begin
      aReport := 'Every QSO in ' + LogStoreFileName + ' carries an exchange id.';
      Result := True;
      Exit;
      end;

   (* REPORTED, NOT REPAIRED. Minting ids here would be the rescore's old
     behaviour moved to a menu item, and it is the minting that was ruled
     out: an id is an identity, and one invented now is not the one any
     other program knew this contact by. *)
   aReport := string(IntToStr(missing.Count)) + ' QSO(s) in ' + LogStoreFileName
              + ' carry no exchange id. They export with no APP_TR4W_ID, so '
              + 'other software cannot match them across an export and a '
              + 're-import. Nothing has been changed. The first: '
              + missing.Sample + '.';
   if logger <> nil then
      begin
      logger.Warn('[LogStore] validity check: %s', [aReport]);
      end;
end;

(* THE LIVE LOG, AS A BACKUP SOURCE. Everything else about a backup -- the
  staging, the verification, the .bak displacement, the publish-by-rename and
  every report sentence -- is TLogBackup's, in uLogBackup, where the unit tests
  hold it. This class only answers the two questions that need GDatabase. *)
type
   TLogStoreBackup = class(TLogBackup)
   protected
      function SourceIsReady: boolean; override;
      procedure SnapshotTo(const aStaged: string); override;
   end;

function TLogStoreBackup.SourceIsReady: boolean;
begin
   Result := LogStoreEnsureOpen;
end;

procedure TLogStoreBackup.SnapshotTo(const aStaged: string);
begin
   (* NO COMMIT AND NO BATCH REFUSAL HERE, and both were deliberate removals
     (2026-10-24).

     They existed because VACUUM INTO ran on the live connection, which
     refuses it inside a transaction -- and sqldb leaves one open after any
     fresh query prepares ("cannot VACUUM from within a transaction",
     measured 2026-10-23). Running it there also broke every kept statement
     on the connection; see TLogDatabase.SnapshotTo, which now takes the
     snapshot through a read-only connection of its own. That connection does
     not care what this one has open, so there is nothing to end.

     Committing would now be a write decided by a backup: every store entry
     point that writes commits before it returns, so the copy already holds
     everything acknowledged, and a backup has no business committing
     anything else. A batch never spans entry points, and if one were open
     the copy would hold the log as it was before it -- a consistent point in
     time, never half of one. *)
   GDatabase.SnapshotTo(aStaged);
end;

function LogStoreBackup(const aDestination: string; out aReport: string): boolean;
var
   backup: TLogStoreBackup;
begin
   backup := TLogStoreBackup.Create;
   try
      Result := backup.Run(aDestination, aReport);
   finally
      backup.Free;
   end;
end;

function LogStoreDatedBackupFileName(const aLogFile, aBackupDir, aInfix: string;
   aUTC: TDateTime): string;
begin
   (* The base is uLogBackup's one rule, shared with the periodic name:
     directory and .db removed, no suffix of either kind left to stack.

     '-' and a space are literals to FormatDateTime; only '/' and ':' are
     locale separators, and neither is used, so no FormatSettings is needed.
     'hh' is the 24-hour clock because the format names no am/pm. The cast
     widens digits only, so it loses nothing. *)
   Result := IncludeTrailingPathDelimiter(aBackupDir) + LogBackupBaseName(aLogFile) +
             aInfix +
             string(FormatDateTime('yyyy-mm-dd hhnnss', aUTC)) + 'Z.db';
end;

function LogStoreClearBackupFileName(const aLogFile, aBackupDir: string;
   aUTC: TDateTime): string;
begin
   Result := LogStoreDatedBackupFileName(aLogFile, aBackupDir,
                                         CLEAR_BACKUP_INFIX, aUTC);
end;

function LogStorePeriodicBackupFileName(const aLogFile, aBackupDir: string): string;
begin
   Result := IncludeTrailingPathDelimiter(aBackupDir) + LogBackupBaseName(aLogFile) +
             PERIODIC_BACKUP_SUFFIX + '.db';
end;

function LogStorePeriodicBackupPath(const aBackupDir: string): string;
begin
   Result := LogStorePeriodicBackupFileName(LogStoreFileName, aBackupDir);
end;

(* LogStoreBackup to aPath in aBackupDir, refusing a folder that is not there
  -- the half both backup entry points share. *)
function BackupIntoFolder(const aBackupDir, aPath: string; out aReport: string): boolean;
begin
   (* Asked before the snapshot so the operator reads WHY, rather than the
     SQLite error a VACUUM INTO a missing directory would give. *)
   if not DirectoryExists(aBackupDir) then
      begin
      aReport := 'the backup folder ' + aBackupDir + ' does not exist and could '
                 + 'not be created, so no backup was written';
      Result := False;
      Exit;
      end;

   Result := LogStoreBackup(aPath, aReport);
end;

function LogStoreBackupBefore(const aInfix, aBackupDir: string;
   out aPath, aReport: string): boolean;
begin
   (* The name rule's input is the DATABASE's name, never TR4W_LOG_FILENAME
     itself: that names the .TRW, which is a relic nothing here touches. *)
   aPath := LogStoreDatedBackupFileName(LogStoreFileName, aBackupDir, aInfix,
                                        LocalTimeToUniversal(Now));
   Result := BackupIntoFolder(aBackupDir, aPath, aReport);
end;

function LogStoreBackupBeforeClear(const aBackupDir: string;
   out aPath, aReport: string): boolean;
begin
   Result := LogStoreBackupBefore(CLEAR_BACKUP_INFIX, aBackupDir, aPath, aReport);
end;

function LogStoreBackupBeforeCatchUp(const aBackupDir: string;
   out aPath, aReport: string): boolean;
begin
   Result := LogStoreBackupBefore(CATCHUP_BACKUP_INFIX, aBackupDir, aPath, aReport);
end;

function LogStoreBackupPeriodic(const aBackupDir: string;
   out aPath, aReport: string): boolean;
begin
   aPath := LogStorePeriodicBackupPath(aBackupDir);
   Result := BackupIntoFolder(aBackupDir, aPath, aReport);
end;

(* OUR STATION, AS IT IS AT THIS MOMENT -- what a QSO being logged now
  records in its my_* columns (schema 3; NY4I 2026-10-18: "The QSO record
  should have all the MY_ values").

  THE VALUES SCORING SEES, read where scoring reads them: the contest's
  override if it stated one, else the station's (Settings.My.Resolved*, design
  7.12), and country, continent and MY CQ ZONE from the same station context
  a contest class is handed (uContestFactory.CurrentStation). So a rescore
  that later reads the record sees what the live entry saw.

  my_state IS MY STATE, the place -- ADIF MY_STATE, the primary subdivision we
  are in -- NOT the session's SentMyState, which is what the exchange sends in
  that slot and for some contests is not a state at all (the Cup of the RF
  sends the grid there). What was sent is exchange_sent.

  my_county IS EMPTY, which here means UNKNOWN: there is no MY COUNTY setting
  yet (docs/F26_EXCHANGE_LAYOUTS.md, decision 2). It arrives with that setting.

  A PEER'S QSO IS MARKED ASSUMED (NY4I, ruling D). The V1 network packet
  carries none of this, so a QSO another station logged is stamped with THIS
  station's values -- usually the same site -- and my_source says so, so
  nothing reads them as that station's own. The computer id on the record is
  what tells the two apart; see uQsoMyFacts.QsoWasLoggedHere. *)
function LogStoreCurrentMyFacts: TQsoMyFacts;
var
   station: uContestBase.TStationContext;
begin
   station := uContestFactory.CurrentStation;

   Result := NotCapturedMyFacts;
   Result.Source := mfsLogged;

   (* UTF8Encode, as ReadEntryDeclaration: the settings are UTF-16 and the
     fields AnsiString; callsigns, grids and references are ASCII. *)
   Result.Call := UTF8Encode(Settings.My.Call);
   Result.Grid := UTF8Encode(Settings.My.ResolvedGrid);
   Result.State := UTF8Encode(Settings.My.ResolvedState);
   Result.County := '';
   Result.Section := UTF8Encode(Settings.My.ResolvedSection);
   Result.Park := UTF8Encode(Settings.My.ResolvedPark);
   Result.Iota := UTF8Encode(Settings.My.ResolvedIota);
   Result.Country := AnsiString(station.MyCountry);
   (* The stable two-letter token cty_continent stores, and only for a real
     continent -- see the guard on cty_continent in uLogRepository. *)
   if (station.MyContinent <> UnknownContinent) and
      (Ord(station.MyContinent) <= Ord(High(ContinentType))) then
      begin
      Result.Continent := AnsiString(ContinentTypeSA[station.MyContinent]);
      end;
   Result.CQZone := station.MyCQZone();
   (* 0 is "use CTY.DAT" in the setting, so CTY.DAT's answer for our call is
     the zone in effect. 0 from there too is unknown, and is stored as NULL. *)
   Result.ITUZone := Settings.My.ResolvedItuZone;
   if Result.ITUZone = 0 then
      begin
      Result.ITUZone := uCTYDAT.ctyGetITUZone(Settings.My.Call);
      end;
end;

(* The capture for a QSO being logged now: this station's values, and whether
  it was logged HERE or arrived from a multi-op peer (ruling D). *)
function CaptureMyFactsNow(const aQso: ContestExchange): TQsoMyFacts;
begin
   Result := LogStoreCurrentMyFacts;
   if not QsoWasLoggedHere(aQso.ceComputerID, Settings.Computer.Id) then
      begin
      Result.Source := mfsAssumed;
      end;
end;

(* ONE ATTEMPT AT LogStoreAppendQSO. aBusy comes back True when the log was
  busy and this was not the last attempt: the attempt has been rolled back
  and may be run again. Every other failure goes to Disable as it always has
  (whose busy branch handles the last attempt's). *)
function AppendQSOOnce(const aQso: ContestExchange; aLastAttempt: boolean;
                       out aBusy: boolean): boolean;
var
   rebuilt: boolean;
   rowId: Int64;
begin
   (* FALSE UNTIL A COMMIT SAYS OTHERWISE. Every exit below that is not a
     completed commit leaves it here, which is the only default that cannot
     acknowledge a QSO nobody wrote. *)
   Result := False;
   aBusy := False;

   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;

      if RefuseReadOnly('logging a QSO') then
         begin
         Exit;
         end;

      (* A CURRENT SNAPSHOT BEFORE THE FIRST WRITE -- see BeginMainWrite. *)
      BeginMainWrite;

      (* AN APPEND ALWAYS INSERTS, WHETHER OR NOT THIS CALL MIGRATED THE LOG.

        ~~"if rebuilt then update the newest row and return True"~~ stood
        here until 2026-10-17, and its premise was B2's: tAddQSOToLog wrote
        the .TRW FIRST, so a migration triggered by this call had already
        imported the QSO being appended, and inserting it again would have
        duplicated it. Since B5 the .TRW is import-only -- tAddQSOToLog writes
        here and nowhere else -- so a migration imports only what was logged
        BEFORE this build, never the QSO in hand. The branch therefore
        OVERWROTE the newest imported QSO with this one and acknowledged a
        contact it had not stored. uTestLogStore drives that case (the append
        as the first thing to open the log) and pins the insert.

        The program never took the branch -- startup opens the log through
        LogStoreApplyContestConfig before anything is logged, so a migration
        happens there -- but the store's promise cannot rest on its caller
        having opened it first. *)

      (* The contest comes from the records; a binary log has no header naming
        it, and the shadow must answer the same question the same way the
        importer does. *)
      if GRepository.LogContest <> aQso.ceContest then
         begin
         GRepository.SetContest(aQso.ceContest);
         end;

      (* WHAT WAS SENT, CAPTURED NOW -- this is TR4W-D12 issue #2 being fixed
        rather than worked around.

        The binary record has no field for the sent exchange, so today it is
        rebuilt from station globals at EXPORT time: correct a typo in MY NAME
        or move house, and every past QSO retroactively claims to have sent the
        new value. Two of the four corpus known-divergences are that defect.

        BuildSentExchangeText is the canonical builder already used for the UDP
        broadcast, and it reads the LIVE CQ exchange template. Calling it here,
        at the moment of the QSO, records what actually went out -- including a
        stale grid if the operator changed one mid-contest, because that is
        what was sent. An event source records the event, not today's opinion
        of it. *)
      (* AND OUR STATION, CAPTURED NOW, for the same reason: the QSO records
        where we were, not where settings say we are when it is next read.

        ONLY A QSO HAS EITHER (log schema 3, stage 5). A note or a QTC record
        is not a contact: it has no station of ours and no exchange we sent,
        and stamping them (the CQ template rebuilt over a note's fields) put
        invented text into the log. *)
      GPendingMyFacts := NotCapturedMyFacts;
      GRepository.SetNextSentExchange('');
      if aQso.ceRecordKind = rkQSO then
         begin
         GPendingMyFacts := CaptureMyFactsNow(aQso);

         (* A PEER'S QSO SENT WHAT THE PEER SENT, AND THE V1 PACKET DOES NOT
           SAY WHAT THAT WAS (D4, stage 5). The serial is in the record, and
           is stored as serial_sent; the rest of the sent exchange is the
           peer's CQ template, which never crosses the wire. Building it from
           THIS station's template would invent the peer's text, so a peer's
           QSO stores none: unknown, not ours. Its station is still stamped
           with ours, MARKED assumed (ruling D) -- the export rebuilds its
           sent columns from that and from the record, and never reads an
           assumed row's exchange_sent. *)
         if GPendingMyFacts.Source = mfsLogged then
            begin
            GRepository.SetNextSentExchange(
               AnsiString(BuildSentExchangeText(aQso)));
            end;
         end;
      GRepository.SetNextMyFacts(GPendingMyFacts);

      (* The same grouping rule the importer uses -- a county line logged
        live must relate its rows exactly as an imported one does. *)
      rowId := GRepository.SaveQSOGroupingByExchangeId(aQso);
      if externalLogger <> nil then
         begin
         externalLogger.CaptureSavedQso(GDatabase, GRepository, rowId, True);
         end;

      (* PER QSO, not batched -- section 9b. An operator who loses power should
        lose at most the contact in progress.

        THE SECOND HALF OF THAT SENTENCE USED TO READ "and this is a shadow of
        a log that has already been written, so a slow commit costs nothing".
        It is not a shadow any more -- it is the log, and the .TRW behind that
        reassurance is gone. The commit is the contact. *)
      GRepository.Commit;

      (* AND ONLY NOW. *)
      GLastAppendedMyFacts := GPendingMyFacts;
      Result := True;
      LogStoreStartExternalDelivery;
   except
      on E: Exception do
         begin
         if SQLiteIsStaleSnapshot(E) and (not aLastAttempt) and
            ((GRepository = nil) or (not GRepository.InBatch)) then
            begin
            if logger <> nil then
               begin
               logger.Warn('[LogStore] the log was busy appending %s: %s -- trying again',
                           [aQso.Callsign, E.Message]);
               end;
            RollBackAfterBusy;
            aBusy := True;
            end
         else
            begin
            Disable('appending a QSO', E);
            end;
         end;
   end;
end;

(* TRIED AGAIN, WHOLE, IF THE LOG IS BUSY (2026-10-31). In WAL mode a busy
  failure comes before the transaction's first write, so an attempt is rolled
  back with nothing lost and run again from the top -- SetNextMyFacts and
  SetNextSentExchange included, which a save clears. After the last attempt
  the QSO is REFUSED, never lost: it stays in the entry fields, the caller
  shows "QSO NOT LOGGED" and beeps, and Disable's busy branch tells the
  operator and keeps the store open for the next one. *)
function LogStoreAppendQSO(const aQso: ContestExchange): boolean;
var
   attempt: integer;
   busy: boolean;
begin
   Result := False;
   for attempt := 1 to LOG_WRITE_ATTEMPTS do
      begin
      Result := AppendQSOOnce(aQso, attempt = LOG_WRITE_ATTEMPTS, busy);
      if Result or (not busy) then
         begin
         Exit;
         end;
      end;
end;

function LogStoreLastAppendedMyFacts: TQsoMyFacts;
begin
   Result := GLastAppendedMyFacts;
end;

procedure LogStoreUpdateNewestQSO(const aQso: ContestExchange);
var
   rowId: Int64;
   rebuilt: boolean;
begin
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      if RefuseReadOnly('rewriting the newest QSO') then
         begin
         Exit;
         end;
      BeginMainWrite;

      (* ~~"if rebuilt then Exit"~~ stood here until 2026-10-17, on the
        reasoning that the caller had already written this rewrite to the
        binary log and the migration had just re-read it. No caller writes the
        .TRW any more, so the exit DROPPED the rewrite -- an Alt-Y delete, a
        QTC mark, a network update. The rewrite proceeds onto the row the
        migration produced; see the same note in LogStoreAppendQSO, and
        uTestLogStore for the pin. *)
      rowId := GRepository.NewestRowId;
      if rowId <= 0 then
         begin
         (* Nothing to rewrite. Not an error: DeleteLastContact on an empty log
           is a no-op in the binary world too. *)
         Exit;
         end;

      GRepository.UpdateQSO(rowId, aQso);
      if externalLogger <> nil then
         begin
         externalLogger.CaptureSavedQso(GDatabase, GRepository, rowId, False);
         end;
      GRepository.Commit;
      LogStoreStartExternalDelivery;
   except
      on E: Exception do
         begin
         Disable('rewriting the newest QSO', E);
         end;
   end;
end;

(* THE ONE BODY OF BOTH LogStoreUpdateQSOAtIndex OVERLOADS. aWriteFacts says
  whether aFacts is written too, in the same transaction. *)
procedure UpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange;
                           aWriteFacts: boolean; const aFacts: TQsoMyFacts);
var
   rowId: Int64;
   rebuilt: boolean;
begin
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      if RefuseReadOnly('rewriting a QSO') then
         begin
         Exit;
         end;
      BeginMainWrite;
      (* A REBUILD USED TO MEAN "THE EDIT IS ALREADY IN THE BINARY LOG", AND
        THAT STOPPED BEING TRUE. This exited here on the reasoning that the
        caller wrote to the .TRW before calling and the rebuild had just
        re-read it. uEditQSO's seek-and-write is gone, so nothing puts the edit
        anywhere but this call -- exiting would DISCARD it, silently, which is
        the same class of defect as the OpenLogFile gate in that unit.

        SO THE UPDATE PROCEEDS. A rebuild here only happens on the one-time
        migration of an existing .TRW, and after it the row for this record
        exists and is exactly what the migration produced -- which is the
        record WITHOUT the operator's edit. Applying it is the correct
        finish to the migration, not a race with it.

        REPORTED EITHER WAY, because a rebuild in the middle of saving an edit
        is worth knowing about and this branch said nothing at all. *)
      if rebuilt and (logger <> nil) then
         begin
         logger.Info('[LogStore] the log was rebuilt while saving an edit to ' +
                     'record %d; applying the edit on top of the rebuild',
                     [aRecordIndex]);
         end;

      rowId := GRepository.RowIdAtIndex(aRecordIndex);
      if rowId <= 0 then
         begin
         (* The log holds no record at that position, so there is nothing to
           rewrite. Said, because the edit is not saved -- and nothing will
           rebuild it: the drift check that once would is gone with the
           second store. *)
         if logger <> nil then
            begin
            logger.Warn('[LogStore] no row at record index %d -- the edit to ' +
                        'it was NOT saved', [aRecordIndex]);
            end;
         Exit;
         end;

      GRepository.UpdateQSO(rowId, aQso);
      if aWriteFacts then
         begin
         GRepository.UpdateQSOMyFacts(rowId, aFacts);
         end;
      if externalLogger <> nil then
         begin
         externalLogger.CaptureSavedQso(GDatabase, GRepository, rowId, False);
         end;
      GRepository.Commit;
      LogStoreStartExternalDelivery;
   except
      on E: Exception do
         begin
         Disable('rewriting a QSO by position', E);
         end;
   end;
end;

procedure LogStoreUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange);
begin
   UpdateQSOAtIndex(aRecordIndex, aQso, False, NotCapturedMyFacts);
end;

procedure LogStoreUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange;
                                   const aFacts: TQsoMyFacts);
begin
   UpdateQSOAtIndex(aRecordIndex, aQso, True, aFacts);
end;

function LogStoreReadMyFactsAtIndex(aRecordIndex: Int64;
                                    out aFacts: TQsoMyFacts): boolean;
var
   rowId: Int64;
   rebuilt: boolean;
begin
   Result := False;
   aFacts := NotCapturedMyFacts;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      rowId := GRepository.RowIdAtIndex(aRecordIndex);
      if rowId <= 0 then
         begin
         Exit;
         end;
      Result := GRepository.LoadQSOMyFacts(rowId, aFacts);
   except
      on E: Exception do
         begin
         (* A READ, so the store stays enabled: nothing was written, and the
           editor shows the fields as not recorded. *)
         aFacts := NotCapturedMyFacts;
         Result := False;
         if logger <> nil then
            begin
            logger.Error('[LogStore] could not read our station for record ' +
                         '%d: %s', [aRecordIndex, E.Message]);
            end;
         end;
   end;
end;

function LogStoreReadDeliveryAtIndex(aRecordIndex: Int64;
                                     out aStatus: TDeliveryStatus): boolean;
var
   rowId: Int64;
   rebuilt: boolean;
begin
   Result := False;
   aStatus := Default(TDeliveryStatus);
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      rowId := GRepository.RowIdAtIndex(aRecordIndex);
      if rowId <= 0 then
         begin
         Exit;
         end;
      Result := ExternalDeliveryStatusOfQso(GDatabase.FileName, rowId, aStatus);
   except
      on E: Exception do
         begin
         (* A READ, so the store stays enabled: the editor hides the line. *)
         aStatus := Default(TDeliveryStatus);
         Result := False;
         if logger <> nil then
            begin
            logger.Error('[LogStore] could not read the delivery of record ' +
                         '%d: %s', [aRecordIndex, E.Message]);
            end;
         end;
   end;
end;

function LogStoreUpdateQSOsByRowId(aUpdates: TLogRowUpdates): boolean;
begin
   Result := False;
   if GDisabled then
      begin
      Exit;
      end;

   if RefuseReadOnly('rewriting QSOs') then
      begin
      Exit;
      end;

   (* NOT EnsureOpen. The row ids came from a read of THIS open log; a log
     opened or rebuilt now would be a different set of rows, and writing
     these ids into it would be wrong rather than late. *)
   if GRepository = nil then
      begin
      if logger <> nil then
         begin
         logger.Error('[LogStore] %d rewritten QSOs were not saved: the log ' +
                      'is not open.', [aUpdates.Count]);
         end;
      Exit;
      end;

   if aUpdates.Count = 0 then
      begin
      Result := True;
      Exit;
      end;

   try
      (* WriteBatch has rolled back before anything reaches the handler. *)
      GRepository.WriteBatch(aUpdates);
      Result := True;
   except
      on E: Exception do
         begin
         (* string(): the RTL's IntToStr returns AnsiString, and Disable takes
           a string. Stated, so the widening is not a build warning. *)
         Disable('rewriting ' + string(IntToStr(aUpdates.Count)) + ' QSOs in one ' +
                 'transaction -- ROLLED BACK, so the log is as it was ' +
                 'before this pass', E);
         end;
   end;
end;

(* ~~SentExchangeOfQSO~~ stood here: LogStoreAppendQSO's LIVE capture of what
  was sent, handed to AppendBatch -- so every QSO an ADIF import wrote claimed
  the exchange this station sends TODAY (D3). Deleted in stage 2 (2026-10-18):
  each row carries what its file says it sent (TLogQsoAppends.Add). *)
function LogStoreAppendQSOs(aQsos: TLogQsoAppends; out aFailedIndex: integer;
                            out aFailure: string): boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   aFailedIndex := -1;
   aFailure := '';

   if GDisabled then
      begin
      aFailure := 'the contest log is not being written -- an earlier ' +
                  'failure stopped it. See tr4w.log.';
      Exit;
      end;

   try
      (* A log migrated from the .TRW here is simply the log these QSOs join:
        the .TRW holds none of them. *)
      if not EnsureOpen(rebuilt) then
         begin
         aFailure := 'the contest log could not be opened. See tr4w.log.';
         Exit;
         end;
      if RefuseReadOnly('importing QSOs') then
         begin
         aFailure := 'the contest log was opened read-only. See tr4w.log.';
         Exit;
         end;

      if aQsos.Count = 0 then
         begin
         Result := True;
         Exit;
         end;

      GRepository.AppendBatch(aQsos, aFailedIndex);
      Result := True;
   except
      on E: Exception do
         begin
         aFailure := E.Message;
         (* InBatch stays True only when the ROLLBACK ITSELF failed (see
           TLogRepository.RollbackBatch). Then nobody knows what the log
           holds, and that is a write failure like any other. *)
         if (GRepository <> nil) and GRepository.InBatch then
            begin
            Disable('appending ' + string(IntToStr(aQsos.Count)) + ' QSOs ' +
                    'in one transaction -- and its ROLLBACK FAILED, so what ' +
                    'the log holds is not known', E);
            end
         else if logger <> nil then
            begin
            logger.Error('[LogStore] %d QSOs were ROLLED BACK and none ' +
                         'written; the log is as it was. %s: %s',
                         [aQsos.Count, AnsiString(E.ClassName), E.Message]);
            end;
         end;
   end;
end;

function LogStoreUpdateQSOBySessionIds(const aQso: ContestExchange): boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      if RefuseReadOnly('rewriting a QSO from the network') then
         begin
         Exit;
         end;
      BeginMainWrite;

      (* False when the pair is unset or matches nothing, and that is not an
        error -- it means this station has no such QSO. *)
      Result := GRepository.UpdateQSOBySessionIds(aQso.ceQSOID1, aQso.ceQSOID2, aQso);
      if Result then
         begin
         GRepository.Commit;
         end;
   except
      on E: Exception do
         begin
         Disable('rewriting a QSO by its network key', E);
         end;
   end;
end;

function LogStoreCollectUnsentToServer(aInto: TLogRowUpdates): boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      GRepository.CollectUnsentToServer(aInto);
      Result := True;
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('[LogStore] could not read the QSOs the multi-op server ' +
                         'still has to hear about: %s', [E.Message]);
            end;
         end;
   end;
end;

function LogStoreHasQSOBySessionIds(aSessionId, aSessionSeq: Int64): boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      Result := GRepository.HasQSOBySessionIds(aSessionId, aSessionSeq);
   except
      on E: Exception do
         begin
         Result := False;
         if logger <> nil then
            begin
            logger.Error('[LogStore] could not ask whether QSO %d/%d is in the ' +
                         'log: %s', [aSessionId, aSessionSeq, E.Message]);
            end;
         end;
   end;
end;

function LogStoreCollectSessionKeys(out aKeys: TQsoSessionKeys): boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   aKeys := nil;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      aKeys := GRepository.CollectSessionKeys;
      Result := True;
   except
      on E: Exception do
         begin
         aKeys := nil;
         if logger <> nil then
            begin
            logger.Error('[LogStore] could not read the network keys of the ' +
                         'log: %s', [E.Message]);
            end;
         end;
   end;
end;

function LogStoreCollectForServerRestock(aInto: TLogRowUpdates;
                                         aServerHolds: TQsoKeyTest): boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      GRepository.CollectForServerRestock(aInto, aServerHolds);
      Result := True;
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('[LogStore] could not read the QSOs the multi-op server ' +
                         'may lack: %s', [E.Message]);
            end;
         end;
   end;
end;

function LogStoreMarkServerProgress(const aSent, aEditsDone: TQsoSessionKeys): boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   if GDisabled then
      begin
      Exit;
      end;

   if (Length(aSent) = 0) and (Length(aEditsDone) = 0) then
      begin
      Result := True;
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      if RefuseReadOnly('recording what the server was sent') then
         begin
         Exit;
         end;
      BeginMainWrite;
      GRepository.MarkServerProgress(aSent, aEditsDone);
      GRepository.Commit;
      Result := True;
   except
      on E: Exception do
         begin
         Disable('recording what the multi-op server has been sent', E);
         end;
   end;
end;

function LogStoreCountUnsentToServer(out aUnsent, aDirty: integer): boolean;
var
   rebuilt: boolean;
begin
   Result := False;
   aUnsent := 0;
   aDirty := 0;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      GRepository.CountUnsentToServer(aUnsent, aDirty);
      Result := True;
   except
      on E: Exception do
         begin
         aUnsent := 0;
         aDirty := 0;
         if logger <> nil then
            begin
            logger.Error('[LogStore] could not count the QSOs the multi-op server ' +
                         'has not been sent: %s', [E.Message]);
            end;
         end;
   end;
end;

function LogStoreRecordContestStatement(const aCommand: string): boolean;
var
   rebuilt: boolean;
   (* What the rule wrote -- reported only once it has committed. *)
   written: boolean;
   cqBank: boolean;
   mode: ModeType;
   key: AnsiChar;
   isCaption: boolean;
begin
   Result := False;

   (* /EXPORT is read-only for the log -- see CaptureConfigurationOnClose. *)
   if tSilentExport then
      begin
      Exit;
      end;

   (* NO LOG TO WRITE TO, AND SAID: the failure that disabled the store has
     already been put in front of the operator once (Disable). The statement
     stays in force for this session -- applied, and latched if it is a
     memory -- and nothing records it, as nothing records a QSO now. *)
   if GDisabled then
      begin
      if logger <> nil then
         begin
         logger.Warn('[LogStore] %s is NOT recorded in the log: the log is ' +
                     'not being written (see the error above). It holds for ' +
                     'this session only.', [aCommand]);
         end;
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;
      if RefuseReadOnly('recording a contest setting') then
         begin
         Exit;
         end;
      BeginMainWrite;

      (* A FUNCTION-KEY MEMORY IS A CONTEST-SCOPED STATEMENT TOO (R2,
        2026-10-23): the log's message table is per contest, and an edit is
        what the operator stated. D7 wrote an accepted Alt-P edit to the
        contest .cfg the moment OK was pressed (uEditMessage.pas:236/249);
        this is that write. The key's row -- text, caption, edited -- goes
        in as one, so a crash can lose the whole edit but never half of it.

        Otherwise the setting's own rule. COMMITTED EITHER WAY: an unstated
        setting's row is DELETED by the same rule, and that is a write too. *)
      if ParseMessageMemoryCommand(ShortString(AnsiString(aCommand)), cqBank,
                                   mode, key, isCaption) then
         begin
         CaptureMessageMemory(GRepository, cqBank, mode, key);
         written := True;
         end
      else
         begin
         written := CaptureContestStatement(Settings, GRepository, aCommand);
         end;
      GRepository.Commit;

      (* TRUE ONLY NOW, AFTER THE COMMIT (Codex follow-up A, 2026-10-23).
        Result was set before the Commit, so a commit that raised went to
        Disable with Result already True: the caller was told an edit was
        saved that was not. *)
      Result := written;
      if Result then
         begin
         if logger <> nil then
            begin
            logger.Info('[LogStore] %s recorded in the log as the contest''s ' +
                        'statement', [aCommand]);
            end;
         end;
   except
      on E: Exception do
         begin
         Result := False;
         Disable('recording a contest setting', E);
         end;
   end;
end;

(* The program's set-up: the CONTEST command, applied as a trusted caller --
  see the note on CheckCommand in the replay below. *)
function SetUpContestByCommand(const aContestId: ShortString): boolean;
var
   cmdName: ShortString;
   valName: ShortString;
begin
   cmdName := ShortString(AnsiString('CONTEST'));
   valName := aContestId;
   Result := CheckCommand(cmdName, valName, True);
end;

function LogStoreApplyContestConfig: integer;
begin
   Result := LogStoreApplyContestConfigWith(@SetUpContestByCommand);
end;

function LogStoreApplyContestConfigWith(aSetUpContest: TLogContestSetUp): integer;
var
   rebuilt: boolean;
   rows: TStringList;
   (* Stored contest rows that are not statements -- reported, not applied. *)
   dropped: TStringList;
   (* Stored rows naming a RETIRED command (M10 S2) -- reported, not applied. *)
   retired: TStringList;
   (* Stored rows naming a SECRET command (2026-10-29) -- names only, never
     the values; not applied, and deleted by the next capture. *)
   secrets: TStringList;
   i: integer;
   cmd, val: string;
   renderable: boolean;
   (* A NAMED LOCAL, so PAnsiChar below points at a string that is still alive.
      PAnsiChar of a temporary is a dangling pointer -- Delphi's allocator hid
      that and FPC's does not. *)
   cmdName: ShortString;
   valName: ShortString;
   idx: integer;
   valAsShort: ShortString;
begin
   Result := 0;
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt) then
         begin
         Exit;
         end;

      rows := TStringList.Create;
      dropped := TStringList.Create;
      retired := TStringList.Create;
      secrets := TStringList.Create;
      try
         GRepository.LoadContestConfig(rows);

         (* ONLY THE OPERATOR'S STATEMENTS ARE APPLIED -- 2026-10-01, section
           7.8 of docs/CONTEST_OWNERSHIP_DESIGN.md.

           A LOG WRITTEN BEFORE THAT RULE stored every contest-scoped
           setting, so its 'NONE' / 'UNKNOWN' rows are constructor defaults,
           not choices. Applied, one of them CLOBBERED a contest .cfg line
           that had just stated the setting (D2) -- the equality skip below
           protected only the case where the value in force happened to equal
           the sentinel. Such a row is dropped here and deleted at the next
           capture; a non-default row in that era was a real value from a
           .cfg or the New Contest dialog, so it is kept and applied as a
           statement. A log captured under the rule holds statements only. *)
         (* AND A RETIRED SETTING'S ROW IS SET ASIDE IN EITHER ERA -- M10 S2,
           2026-10-14. The seven contest-rule settings (QSO POINT METHOD,
           EXCHANGE RECEIVED, INITIAL EXCHANGE, the four multipliers) are in
           uCFG.RETIRED_COMMANDS: the class decides. Set aside here, so they
           never reach CheckCommand, said ONCE per open with their values,
           and deleted by the next capture -- so a log reports them at most
           until its first clean close. *)
         (* AND A CREDENTIAL'S ROW IS NEVER APPLIED -- 2026-10-29. An old log
           can hold HAMSCORE PASSWORD or SERVER PASSWORD (as 'contest' when a
           .cfg supplied it); applied, a stale password from a shared or
           year-old file would overwrite the one in the OS vault. Set aside
           here, named ONCE per open -- the value is never logged -- and
           deleted by the next capture (DeleteStoredSecrets). *)
         KeepOnlyStatements(rows, LogHoldsStatementsOnly(GRepository), dropped,
                            CommandIsRetired, retired, secrets);
         if (secrets.Count > 0) and (logger <> nil) then
            begin
            logger.Warn('[LogStore] this log holds %d stored credential(s) -- ' +
                        'not applied, the OS vault holds the password; ' +
                        'deleted from the log at its next capture: %s',
                        [secrets.Count, secrets.CommaText]);
            end;
         if (dropped.Count > 0) and (logger <> nil) then
            begin
            logger.Info('[LogStore] %d stored contest setting(s) hold the ' +
                        'built-in default and were written before the log ' +
                        'stored only what the operator stated -- not applied, ' +
                        'the contest decides: %s',
                        [dropped.Count, dropped.CommaText]);
            end;
         if (retired.Count > 0) and (logger <> nil) then
            begin
            logger.Info('[LogStore] %d stored contest setting(s) are retired ' +
                        'commands -- not applied, the contest''s class ' +
                        'decides; deleted from the log at its next capture: %s',
                        [retired.Count, retired.CommaText]);
            end;

         (* THE CALLSIGN BEFORE THE CONTEST -- 2026-09-20.

           FoundContest DERIVES FROM THE CALLSIGN AND DECIDES WITH THE
           RESULT. MY COUNTRY, MY CONTINENT and MY ZONE come from MY CALL
           through CTY.DAT unless the operator stated them, and several
           contests then BRANCH on MY COUNTRY: ARRL DX sends a power to a
           K or VE station and a state to everyone else, ARRL 160 picks its
           exchange on ARRLSectionCountry, and the FCONTEST case runs inside
           the same call that does the deriving.

           The rows below have no order -- they come back as the table
           stores them -- so a log-backed contest could apply CONTEST first,
           derive a country from an EMPTY callsign, and settle the exchange
           before MY CALL was ever read. The derivation at the foot of this
           routine then corrected the country and the zone, and could not
           correct the decision already taken from them.

           MEASURED, NY4I on Linux Mint 2026-09-20: a fresh station (whose
           settings file holds MAIN CALLSIGN but not MY CALL -- the New
           Contest dialog queues MY CALL as the CONTEST'S value), ARRL DX
           SSB, reopened. MY COUNTRY derived to '', so TR4W put a Florida
           station on the DX side and rejected 'K' as a received power with
           "Improper domestic QTH". His Windows and macOS stations were
           unaffected only because their MY CALL arrives from an older
           configuration.

           ONE COMMAND, HOISTED, NOT A SORT. ~~Everything else here is a value
           CONTEST does not read.~~ The contest's station facts are hoisted
           too (2026-10-23, below): CONTEST reads MY STATE. *)
         idx := rows.IndexOfName('MY CALL');
         if idx >= 0 then
            begin
            cmdName := ShortString(AnsiString('MY CALL'));
            valAsShort := ShortString(AnsiString(rows.ValueFromIndex[idx]));
            if CheckCommand(cmdName, valAsShort, True) then
               begin
               if logger <> nil then
                  begin
                  logger.Info('[LogStore] MY CALL = %s applied before the ' +
                              'contest, so the country and zone derived ' +
                              'from it are settled before FCONTEST reads them',
                              [string(valAsShort)]);
                  end;
               end;
            end;

         (* AND THE CONTEST'S OWN STATION FACTS BEFORE THE CONTEST TOO --
           2026-10-23, the same ordering defect as MY CALL's, found by Q119.

           FoundContest DECIDES WITH THEM: a QSO party's in-state answer
           (FCONTEST.StationInHostState, from the RESOLVED MY STATE), and
           with it the domestic file, the contest name and the multipliers;
           the sent state; a contest's default memories (DescribeSession reads
           MY GRID, MY STATE, ...). Applied after CONTEST, a log whose MY STATE
           is its own (source 'contest') was set up from the STATION's value:
           MEASURED, the corpus's michigan_qp_2026_ny4i -- MY STATE = WAYN, a
           Michigan county -- opened OUT OF STATE (its stored CONTEST NAME says
           so), and once the X-QSO predicate asked the host-area rule every
           QSO with DC, MD, VA and OH exported as X-QSO: with a claimed score
           of 0.

           Recording an override assigns nothing and runs no setter (see the
           loop below), so doing it here is safe; the loop skips these rows. *)
         for i := 0 to rows.Count - 1 do
            begin
            cmd := rows.Names[i];
            if (cmd <> '') and Settings.CommandIsContestOverridable(cmd) then
               begin
               if ApplyContestStatement(cmd, rows.ValueFromIndex[i]) then
                  begin
                  inc(Result);
                  end;
               end;
            end;

         (* THE CONTEST COMES FROM THE CONTEST TABLE, NOT FROM A CAPTURED
           SETTING -- and it is applied FIRST, because everything else depends
           on it. FoundContest sets the Contest enum, ActiveExchange and the
           domestic file; until it has run, ProcessExchange has no arm to take
           and no QSO can be logged.

           WHY THE TABLE AND NOT THE config ROW. contest_type is written once,
           when the log is created, and never recomputed. The captured CONTEST
           row is rewritten on every clean exit from whatever the running
           program believed at the time -- so a single bad session poisons it
           permanently, which is exactly what happened. One of the two is a
           fact about the log; the other is a fact about a session.

           A captured CONTEST row is ignored below for the same reason. *)
         (* ONLY WHEN NOTHING ELSE HAS ANSWERED. If a contest .cfg was read it
           has already set this, and it is the better source: the table'''s
           contest_type is derived at IMPORT from the first record'''s ceContest
           ordinal, and a .TRW written under an older ContestType layout maps
           that ordinal to the wrong name. Measured 2026-09-03: the golden
           corpus'''s winter_fd log is stamped ALRS-UA1DZ-CUP while its .CFG says
           WINTER FIELD DAY, and applying the table unconditionally broke that
           set'''s export and made the factory A/B disagree.

           So the table answers the case it exists for -- a log with no .cfg at
           all, which is every contest created by the New Contest dialog -- and
           stays out of the way otherwise. *)
         if (GRepository.LogContest <> NoContest) and
            ((CFGCommandValueAsString('CONTEST') = '') or
             (CFGCommandValueAsString('CONTEST') =
              ContestId(NoContest))) then
            begin
            valName := ShortString(AnsiString(
               ContestId(GRepository.LogContest)));
            (* ONLY IF IT IS NOT ALREADY RIGHT. FoundContest is NOT
               idempotent -- re-running it appends to the domestic file name
               (dom\iaruhq.domiaruhq.dom), and applying it unconditionally on
               every open took the golden corpus from 20 passed to 10 passed /
               14 failed in one run. The comparison is against the CFGCA row
               because that is what the hook maintains; the VALUE comes from
               the contest table because that is what is trustworthy. *)
            if (CFGCommandValueAsString('CONTEST') <> string(valName)) and
               aSetUpContest(valName) then
               begin
               if logger <> nil then
                  begin
                  logger.Info('[LogStore] contest: %s (from the log)',
                              [string(valName)]);
                  end;
               end
            else if logger <> nil then
               begin
               logger.Error('[LogStore] the log names contest "%s" and this ' +
                            'build did not accept it.', [string(valName)]);
               end;
            end
         (* A LOG THAT HAS NO CONTEST ROW, AND A SESSION THAT KNOWS THE ANSWER.

           EnsureOpen stamps the contest when a log is CREATED. Every log made
           by the New Contest dialog before that existed has no contest row at
           all, and could not acquire one: the only other writer is the QSO
           append, and a contest with no contest cannot log a QSO. Left alone
           they score every US callsign as DX, for good.

           So repair them -- but ONLY from something the program already
           believes, never from a guess. Contest is non-DUMMY here in exactly
           one case: the operator has just been through the New Contest dialog
           this session, which applied CONTEST a moment ago. That is the same
           information the running program is scoring with; writing it down
           makes the NEXT open work.

           NOT A HEURISTIC, and it was tempting to make one. The config table
           carries CONTEST NAME = 'ARRL-FD', which for this contest happens to
           equal the internal token -- and for others does not, because that
           row is the CABRILLO name. Recovering from it would be right often
           enough to be believed and wrong quietly. The file name is the same
           trap. Neither is used.

           NOTHING IS OVERWRITTEN. The arm above owns the case where the table
           already answered; this one runs only when it did not. *)
         else if (GRepository.LogContest = NoContest) and
                 (Contest <> NoContest) and
                 (not GReadOnly) then   (* a read-only log is never corrected *)
            begin
            GRepository.SetContest(Contest);
            (* See the note beside the stamp in EnsureOpen: SetContest does not
              commit, and an uncommitted write is rolled back at exit. *)
            GRepository.Commit;
            if logger <> nil then
               begin
               logger.Info('[LogStore] this log carried no contest -- ' +
                           'recorded it as %s, from the contest now open. ' +
                           'It was made before the log stored its own ' +
                           'contest, and would have scored every domestic ' +
                           'callsign as DX on its next open.',
                           [ContestId(Contest)]);
               end;
            end

         (* A TABLE THAT IS WRONG, AND A .cfg THAT SAYS SO -- 2026-09-14.

           THIS IS THE LAST THING KEEPING A .cfg NECESSARY, and it is not an
           ordering problem: contest_type is derived at IMPORT from the first
           record's ceContest ORDINAL, and a .TRW written under an older
           ContestType layout maps that ordinal to a different contest. The
           golden corpus carries one -- winter_fd_2025_w4ta is stamped
           ALRS-UA1DZ-CUP and its .cfg says WINTER FIELD DAY -- and the
           mismatch is permanent, because nothing ever revisited the stamp.

           THE ARM ABOVE THIS ONE ALREADY ESTABLISHES WHO IS RIGHT. It applies
           the table only when nothing else has answered, so reaching here with
           a non-dummy Contest that DISAGREES with the table means a contest
           .cfg set it -- which CommandCameFromContestCFG confirms rather than
           infers, so a contest set any other way this session does not
           silently rewrite a log.

           AND THIS IS THE WHOLE POINT OF "READ ONCE AND CONVERT". The .cfg is
           an import format: what it says is converted INTO the log, and the
           file is not consulted again. Leaving the stamp wrong means the file
           must be kept for ever, which is the thing E3 exists to end.

           NOTHING IS GUESSED. The value written is the contest the program is
           already scoring with. *)
         else if (Contest <> NoContest) and
                 (GRepository.LogContest <> Contest) and
                 CommandCameFromContestCFG('CONTEST') and
                 (not GReadOnly) then   (* a read-only log is never corrected *)
            begin
            if logger <> nil then
               begin
               logger.Warn('[LogStore] this log was stamped %s and its .cfg ' +
                           'says %s -- correcting the log. The stamp came ' +
                           'from a binary import, whose contest ordinal was ' +
                           'written under an older layout.',
                           [ContestId(GRepository.LogContest),
                            ContestId(Contest)]);
               end;
            GRepository.SetContest(Contest);
            (* See the note beside the stamp in EnsureOpen: SetContest does not
              commit, and an uncommitted write is rolled back at exit. *)
            GRepository.Commit;
            end;

         for i := 0 to rows.Count - 1 do
            begin
            cmd := rows.Names[i];

            (* Applied above, from the contest table. *)
            if cmd = 'CONTEST' then
               begin
               Continue;
               end;

            val := rows.ValueFromIndex[i];
            if cmd = '' then
               begin
               Continue;
               end;

            (* AN ACTION IS NOT A SETTING, AND APPLYING ONE HANGS THE PROGRAM.

              REMINDER is the case that found this. It is a COMMAND, not a
              value: applying it calls QuickEditResponse('Enter time for
              reminder') and waits for the operator (help.pas:642). In a
              headless /EXPORT that waits forever; in the interactive program it
              is worse, because the prompt takes the keyboard in the quick
              command window and the operator sees a log that has simply stopped
              accepting QSOs -- NY4I, 2026-09-02: "stuck at entering the zone 4".

              THE GUARD IS HERE, ON THE APPLY, AND NOT ONLY ON THE CAPTURE.
              CaptureConfiguration no longer stores these, but every log written
              before that fix already has them -- 410 rows including REMINDER
              and the two ctFreqList commands. Guarding only the writer would
              leave every existing log broken and unopenable, and the operator
              with no way to tell why. A reader that can be handed bad data has
              to defend itself.

              SAME QUESTION THE CAPTURE ASKS, so the two cannot drift: can this
              command's value be written down at all? If it cannot, it was never
              a setting and there is nothing here to restore. Reported once per
              command rather than silently, because a log carrying rows this
              build refuses is worth knowing about. *)
            CFGCommandValueAsString(cmd, renderable);
            if not renderable then
               begin
               if logger <> nil then
                  begin
                  logger.Warn('[LogStore] "%s" is an action, not a setting -- ' +
                              'ignored. It was captured by a build that should ' +
                              'not have stored it.', [cmd]);
                  end;
               Continue;
               end;

            (* CheckCommand WITH aApplyJSONOwned = TRUE -- the mechanism uCFG
               already provides for exactly this, in its own words:

                 "Default False keeps every existing caller, above all the ini
                  loader, exactly as it was. A trusted caller passes True and
                  the row behaves like any other."

               THE LOG IS THAT TRUSTED CALLER. csJSON means settings\tr4w.json
               owns the row, which is right for a STATION setting; CONTEST and
               the CATEGORY tags are properties of THIS CONTEST, and the log is
               where they now live.

               TWO WRONG ROUTES WERE TRIED FIRST, and both failed the same way.
               SetCFGCommandValue is the "operator changed a setting" path: it
               applies AND PERSISTS, and refuses csJSON outright with "Refusing
               to write tr4w.ini". ProcessConfigInstruction is the .cfg reader's
               line handler, and it calls CheckCommand with the default -- so it
               skips csJSON rows silently and returns True, reporting success
               for a command it did not apply.

               Measured with an emptied .cfg: CONTEST, CATEGORY-POWER,
               CATEGORY-OPERATOR, CATEGORY-BAND, CATEGORY-MODE and
               CATEGORY-TRANSMITTER were all refused, the contest was never set,
               and THE EXPORT PRODUCED NOTHING -- while the log held every one
               of those values.

               Nothing here needs persisting: the value came OUT of the log,
               which is where it is stored. What is wanted is the application
               only -- the same range checks, type conversion and crA hook a
               .cfg line gets. *)
            (* A SHORTSTRING, AND ITS ADDRESS -- NOT PAnsiChar OF AN AnsiString.

               CheckCommand declares its first parameter PAnsiChar and then
               compares with StrComp(@Command[1], ...) -- skipping a byte. That
               is only right if what was passed is a pointer to a SHORTSTRING,
               whose byte 0 is the length and whose first character is at [1].
               Every existing caller does that: ProcessConfigInstruction passes
               @ID with ID a ShortString.

               Handing it PAnsiChar of an AnsiString points at the first
               CHARACTER, so the comparison started one in: 'CONTEST' was
               matched as 'ONTEST', no row was found, and every command came
               back rejected -- with a warning that plausibly blamed the value.

               The declared type cannot catch this; both are PAnsiChar. *)
            (* ONLY WHAT ACTUALLY DIFFERS.

               Re-applying a command that already holds the stored value is not
               free, because a row's crA hook is not required to be idempotent
               and at least one is not. CONTEST's rebuilds the domestic-file
               name, and running it twice produced

                   dom\iaruhq.domiaruhq.dom

               -- the name appended to itself. The file could not be opened, the
               contest loaded no domestic data, and the export produced NOTHING.
               All seven settings had applied successfully; applying them was
               the problem.

               Skipping the no-ops also makes this a genuine no-op when the .cfg
               and the log agree, which is every log created by this build --
               and is why the corpus does not move. *)
            (* SKIP A NO-OP ONLY WHERE APPLYING IT REALLY WOULD BE ONE.

               A ROW WITH A crA HOOK DOES MORE THAN STORE A VALUE, and CONTEST
               is the one that matters: its hook runs FoundContest, which sets
               the Contest enum, ActiveExchange and the domestic file. The
               stored STRING can already match while none of that has happened
               -- which is precisely the state a log-backed contest starts in,
               because nothing parsed a .cfg to make it happen.

               MEASURED 2026-09-03: startup logged "the log applied 2 contest
               setting(s)" while the title bar showed NO CONTEST. CONTEST was
               counted here and skipped, so ActiveExchange stayed
               UnknownExchange; ProcessExchange's case has no else, so it
               returned False in silence and no QSO could be logged at all.
               The count was the most misleading part -- it reported success
               for the very row it had declined to apply.

               THE COMPARISON STAYS FOR ORDINARY SETTINGS, which is what it
               was added for: CONTEST's effect is NOT idempotent, and
               re-applying it appended to the domestic file name.

               'IS IT CONTEST' RATHER THAN 'IS ITS crA ZERO' -- 2026-09-14.
               The crA test named the hook table, and what it was really
               asking is whether re-applying this setting does something
               beyond assigning it. Of every setting in the program that was
               true of exactly one, and it is the one the note above is about;
               a property setter is idempotent by construction. Naming it
               says what the test is for, where a hook index only said where
               the answer was stored. *)
            (* A STATION FACT IS THIS CONTEST'S OVERRIDE -- design 7.12 -- and
              is routed BEFORE the no-op skip below. That skip compares with
              the STATION'S value; a stored MY STATE equal to it would be
              skipped, never become the override, and the next capture would
              rewrite the row as 'station' -- after which a Preferences edit
              of the station would silently change this contest. Recording an
              override assigns nothing and runs no setter, so it is safe
              unconditionally.

              A log written before 7.12 holds the same rows (source 'contest',
              from a .cfg or the New Contest dialog), so it reads exactly as
              it did: the contest's value in force. A log with no such row
              resolves to the station's value, as it always did. *)
            (* APPLIED ABOVE, BEFORE THE CONTEST (2026-10-23) -- see there. *)
            if Settings.CommandIsContestOverridable(cmd) then
               begin
               Continue;
               end;

            if (CFGCommandValueAsString(cmd) = val) and
               (not UnicodeSameText(cmd, 'CONTEST')) then
               begin
               (* NOTHING TO ASSIGN, BUT THE STATEMENT STILL STANDS. Every row
                 that reaches here is one (see KeepOnlyStatements above), and
                 a CheckCommand would have recorded it as such -- skipping the
                 assignment must not skip that, or the next capture would
                 delete a statement because it happened to match. A no-op for
                 a setting that is not contest-scoped. *)
               Settings.SetCommandStated(cmd, True);
               inc(Result);
               Continue;
               end;

            FillChar(cmdName, SizeOf(cmdName), 0);
            FillChar(valAsShort, SizeOf(valAsShort), 0);
            cmdName := ShortString(AnsiString(cmd));

            (* THIS COMMENT USED TO SAY THE CAST BELOW WAS A POINTER
               REINTERPRETATION AND HAD TO BE A PLAIN ASSIGNMENT. It said so
               while the code kept the cast, which was the first clue.

               MEASURED 2026-09-24 against FPC 3.2.2 / i386-win32 in this
               tree's mode: ShortString(x) and `short := x` are the SAME
               conversion and give byte-identical results, including for a
               source longer than the target. The claim was folklore; it is
               retracted in CLAUDE.md and pinned by
               test/unit/uTestShortStringConversion.pas.

               WHAT IS REAL AND IS WHY THE FillChar ABOVE STAYS: a ShortString
               carries no NUL terminator, so anything downstream that treats
               @s[1] as a C string reads past the text. CheckCommand takes the
               ShortString itself and is safe; the zero-fill costs nothing and
               keeps that true if a caller ever changes. *)
            valAsShort := ShortString(AnsiString(val));
            if CheckCommand(cmdName, valAsShort, True) then
               begin
               inc(Result);
               end
            else
               begin
               (* Reported rather than skipped in silence: a command the log
                  carries and this build will not accept is either a setting
                  withdrawn since the log was made or a value out of range, and
                  both are things an operator would want to know rather than
                  discover by its absence. *)
               if logger <> nil then
                  begin
                  logger.Warn('[LogStore] the log sets %s = %s and this build ' +
                              'would not accept it. The command is left at ' +
                              'its current value.',
                              [cmd, val]);
                  end;
               end;
            end;
      finally
         secrets.Free;
         retired.Free;
         dropped.Free;
         rows.Free;
      end;

      (* AND NOW THE CALLSIGN IS SETTLED, SO DERIVE FROM IT -- 2026-09-14.

        THIS IS WHAT KEPT THE .cfg NECESSARY, and it is an ORDERING problem
        rather than a missing setting: every command in the file IS captured
        and applied.

        MY COUNTRY, MY CONTINENT and MY ZONE are DERIVED from MY CALL through
        CTY.DAT unless the operator stated them. While a .cfg supplied the
        callsign, that derivation happened during config load, before anything
        that reads it. Now the callsign arrives HERE, from the log -- and the
        config table has no ordering, so FCONTEST can run (because CONTEST was
        applied) while My.Call is still empty, derive from nothing, and leave
        the zone at its declared default.

        MEASURED, cqww_ssb_2025_ny4i: every sent exchange read `59 15` instead
        of `59 05`. That .cfg does not name a zone at all -- NY4I's zone 5 was
        derived from NY4I -- so no amount of capturing would have fixed it.

        ONCE, AT THE END, rather than after each row: the routine reads the
        WasSet flags itself, so an operator who stated a country or a zone is
        not overruled, and running it once when every source has contributed
        is the definition of "settled". *)
      if Settings.My.Call <> '' then
         begin
         RecalculateMyCountryContinentAndZoneNew(
            CallString(UTF8Encode(Settings.My.Call)));
         end;

      (* THE MEMORIES THE OPERATOR EDITED -- Q113, LAST, AND THAT IS THE POINT.

        D7 kept an operator's Alt-P edit across a restart: the dialog wrote it
        to the contest .cfg's [Messages] section and ReadInConfigFile applied
        it again at start-up (C:\TR4W uEditMessage.pas:236/249). A contest is
        its SQLite file now, so the log's message table is where it lives.

        HERE, BECAUSE EVERY DEFAULT WRITER HAS RUN BY NOW. The contest was set
        up above -- by the .cfg read earlier, or by CONTEST from the contest
        table -- and its set-up writes its default memories and, before that,
        forgets any statement made under another contest. Restoring earlier
        would be forgotten or overwritten. Restored through LogCW's Q9 latch,
        so a later re-selection of THIS contest keeps the edits too: one rule
        for a re-select and for a restart, not two. *)
      i := RestoreEditedMessageMemories(GRepository);
      if (i > 0) and (logger <> nil) then
         begin
         logger.Info('[LogStore] %d function-key memory(ies) the operator ' +
                     'edited restored from the log', [i]);
         end;
   except
      on E: Exception do
         begin
         Disable('applying the contest configuration', E);
         Result := 0;
         end;
   end;
end;

function LogStoreEnsureOpen: boolean;
var
   rebuilt: boolean;
begin
   Result := EnsureOpen(rebuilt);
end;

(* WHAT THE CONTEST'S CONFIGURATION IS WHEN THE OPERATOR STOPS.

  The capture at creation records what the contest STARTED as. An operator who
  changes QSO POINT METHOD, or edits an F-key memory, halfway through has
  changed the contest's configuration, and the log has to carry the new value or
  it is not self-describing.

  ON CLOSE RATHER THAN ON EVERY CHANGE, and the limitation is worth stating
  plainly: SetCFGCommandValue is called from dozens of places, several of them
  DURING config load, so hooking it would mean writing to the store before it is
  open and re-recording the file the load just read. Closing is the one moment
  the configuration is definitely settled.

  THE COST IS A CRASH. Kill TR4W mid-contest and the settings changed in that
  session are not in the log, though every QSO is -- QSOs are committed as they
  are made. Recording changes as they happen is the fix, and it belongs with
  the settings work rather than here.

  TWO KINDS ARE RECORDED AS THEY HAPPEN ALREADY, through
  LogStoreRecordContestStatement: the Cabrillo summary window's categories
  (Q61) and an accepted function-key memory edit (R2, 2026-10-23). For those
  this capture is reconciliation, and rewrites what is already there. *)
procedure CaptureConfigurationOnClose;
var
   attempt: integer;
begin
   (* A BATCH EXPORT DOES NOT REWRITE THE LOG IT IS EXPORTING.

     The program already says so at startup -- "batch /EXPORT: settings are
     READ-ONLY for this run" -- and this was quietly contradicting it, writing
     roughly four hundred config rows into the log on the way out of a run
     whose whole purpose is to read.

     IT WAS ALSO MAKING THE GOLDEN CORPUS FLAKY. A different set aborted on
     every run once the capture started happening, because each of the thirteen
     exports now did a few hundred extra writes at close and the next run read
     back whatever that left. A regression oracle that changes its answer
     between runs is worse than no oracle.

     THE CAPTURE IS FOR AN INTERACTIVE SESSION, where the operator has actually
     changed something. *)
   if tSilentExport then
      begin
      Exit;
      end;

   if (GRepository = nil) or GDisabled then
      begin
      Exit;
      end;
   if LogStoreIsReadOnly then
      begin
      if logger <> nil then
         begin
         logger.Info('[LogStore] the log was opened read-only, so the configuration ' +
                     'is not recorded on close');
         end;
      Exit;
      end;

   (* TRIED LOG_WRITE_ATTEMPTS TIMES WHEN THE LOG IS BUSY, after ending the
     read transaction sqldb left open (BeginMainWrite) -- the stale snapshot
     that failed at 10:43:25 on 2026-10-31 with the worker already stopped.
     Then a warning, and the program closes: QSOs are committed as they are
     made, and only this session's setting changes go unrecorded. *)
   for attempt := 1 to LOG_WRITE_ATTEMPTS do
      begin
      try
         BeginMainWrite;
         (* AND THIS ONE IS NOT A CONVERSION. It runs on every clean exit of an
           interactive session and records what the session ENDED with, so an
           operator checking whether the import re-ran can tell the two apart by
           the reason rather than by the line number. *)
         CaptureConfiguration('recorded on exit -- the settings this session ended with');
         Exit;
      except
         on E: Exception do
            begin
            (* Reported, not raised: this runs while shutting down, and a failure
               to record a setting must not stop the program closing its log. *)
            if SQLiteIsBusy(E) then
               begin
               RollBackAfterBusy;
               (* Only a stale snapshot is worth another try; a lock that
                 outlasted the busy wait is not, and closing must not freeze. *)
               if (attempt = LOG_WRITE_ATTEMPTS) or
                  (not SQLiteIsStaleSnapshot(E)) then
                  begin
                  if logger <> nil then
                     begin
                     logger.Warn('[LogStore] the configuration was not recorded on ' +
                                 'close: the log stayed locked (%s). QSOs are ' +
                                 'unaffected; this session''s setting changes are ' +
                                 'not in the log.', [E.Message]);
                     end;
                  Exit;
                  end;
               end
            else
               begin
               if logger <> nil then
                  begin
                  logger.Error('[LogStore] the configuration could not be recorded ' +
                               'on close: %s -- %s. QSOs are unaffected.',
                               [E.ClassName, E.Message]);
                  end;
               RollBackAfterBusy;
               Exit;
               end;
            end;
      end;
      end;
end;

function LogStoreCheckLockState(out aReport: string): boolean;
var
   dbName, sidecars, overdue, detail: string;
   probe: TLogLockProbe;
   i: integer;
begin
   Result := True;
   aReport := '';
   if (GDatabase = nil) or (not GDatabase.IsOpen) then
      begin
      aReport := 'No contest log is open, so there is no lock to check.';
      Exit;
      end;
   dbName := GDatabase.FileName;

   (* THE SIDECARS FIRST: a probe connection that is the last to close can
     checkpoint and remove the -wal, and this reports what was there. *)
   sidecars := '';
   for i := Low(LOG_SIDECAR_SUFFIXES) to High(LOG_SIDECAR_SUFFIXES) do
      begin
      if FileExists(dbName + LOG_SIDECAR_SUFFIXES[i]) then
         begin
         sidecars := sidecars + ' ' + LOG_SIDECAR_SUFFIXES[i];
         end;
      end;

   overdue := LogWatchLongTransactions(GetTickCount64, LOG_WATCH_THRESHOLD_MS);
   if overdue <> '' then
      begin
      Result := False;
      aReport := aReport + 'A transaction has been open longer than ' +
                 IntToStr(LOG_WATCH_THRESHOLD_MS div 1000) + ' s: ' + overdue +
                 '. The watchdog is dealing with it.' + sLineBreak;
      end
   else
      begin
      aReport := aReport + 'No TR4W connection has a transaction open longer than ' +
                 IntToStr(LOG_WATCH_THRESHOLD_MS div 1000) + ' s.' + sLineBreak;
      end;

   (* A SHORT WAIT, not the open's: a check must not freeze the window. *)
   probe := ProbeLogWriteLock(dbName, 250, detail);
   case probe of
      llpFree:
         begin
         aReport := aReport + 'Nothing else holds the log''s write lock.' + sLineBreak;
         end;
      llpHeld:
         begin
         Result := False;
         if overdue <> '' then
            begin
            aReport := aReport + 'The write lock is held -- by the connection named above.' +
                       sLineBreak;
            end
         else
            begin
            aReport := aReport + 'Another program holds the log''s write lock: another ' +
                       'TR4W (perhaps one stopped at a crash dialog), or a backup, sync ' +
                       'or antivirus tool. QSOs cannot be logged until it lets go.' +
                       sLineBreak;
            end;
         end;
      llpUnknown:
         begin
         Result := False;
         aReport := aReport + 'The lock could not be probed: ' + detail + sLineBreak;
         end;
   end;

   if sidecars <> '' then
      begin
      aReport := aReport + 'Beside the log:' + sidecars + '. Expected while TR4W has ' +
                 'the log open; they can hold committed QSOs, and are never removed.' +
                 sLineBreak;
      end
   else
      begin
      aReport := aReport + 'No -wal or -shm beside the log.' + sLineBreak;
      end;

   aReport := aReport + 'Watchdog interventions this session: ' +
              IntToStr(LogWatchInterventionCount) + '.';
   if LogStoreIsReadOnly then
      begin
      aReport := aReport + sLineBreak + 'This session opened the log READ-ONLY: ' +
                 'no QSO can be logged.';
      end;
end;

procedure LogStoreClose;
begin
   if externalLogger <> nil then
      begin
      externalLogger.LogClosed;
      end;
   CaptureConfigurationOnClose;
   FreeAndNil(GRepository);
   FreeAndNil(GDatabase);
end;

(* A BACKSTOP FOR THE EXIT PATHS THAT ARE NOT tr4w_ShutDown.

  THE TWO EXITS ARE NOT THE SAME AND NEITHER COVERS THE OTHER. The interactive
  program leaves through ExitProcess, which runs NO finalization at all -- so
  this section is dead on that path and the explicit call in tr4w_ShutDown is
  the one that works. The headless modes leave through Halt (/EXPORT, /RESCORE,
  /IMPORTLOG and the startup refusals), which DOES run finalization but never
  reaches tr4w_ShutDown -- so there the explicit call is the dead one and this
  section is what closes the database.

  Corpus runs are the headless case, and they were leaving a -wal behind on
  every one of the thirteen logs.

  SAFE TO RUN TWICE: LogStoreClose is FreeAndNil throughout and
  CaptureConfigurationOnClose returns immediately once GRepository is nil. *)
finalization
   try
      LogStoreClose;
   except
      on E: Exception do
         begin
         (* Finalization order is not ours to choose and a unit this one
           depends on may already be gone. A crash HERE loses the whole
           run for a close that has usually already happened in
           tr4w_ShutDown. *)
         end;
   end;

end.

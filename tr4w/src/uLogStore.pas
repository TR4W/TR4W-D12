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

(* THE SQLITE LOG, WRITTEN ALONGSIDE THE BINARY ONE -- STEP B2.

  The binary .TRW REMAINS AUTHORITATIVE. Nothing reads this database yet: it is
  written so that a bench session produces a real SQLite log next to a real
  binary one, which is the only way to find out whether the mapper survives
  contact with live logging rather than with corpus fixtures.

  That is the strangler pattern this tree already used for the radio and CW
  keyer factories, in CLAUDE.md's own words: "thin adapters over the existing
  globals first, prove the seam on hardware, then delete the legacy path".

  THE RULE THAT OVERRIDES EVERYTHING ELSE HERE: A FAILURE IN THIS UNIT MUST
  NEVER COST A QSO. Every entry point swallows its exceptions, reports once, and
  switches the shadow OFF for the rest of the session. An operator in a contest
  must not lose a contact because a database he does not yet use would not
  write. That is also why nothing here is on the critical path of the log write
  itself -- each call happens AFTER the binary record is safely on disk.

  OPENED LAZILY, on the first append, so there is no startup wiring to get in
  the wrong order and nothing happens at all in a session that logs nothing.

  WHAT IS SHADOWED, AND WHAT IS NOT -- because a partial shadow that pretends to
  be complete would be worse than none:

    shadowed      appending a QSO             (LOGSUBS2.tAddQSOToLog)
                  rewriting the newest row    (DeleteLastContact,
                                               uNet.UpdateRec,
                                               uQTCS.SetSendedQSOs)

                  editing an arbitrary QSO    (uEditQSO, by record position)
                  the network's own update    (uNet.FindAndUpdateQSOInLog,
                                               by (ceQSOID1, ceQSOID2))
                  ADIF import                 (MainUnit.ImportFromADIF)

  ALL EIGHT WRITE SITES ARE NOW SHADOWED. The drift rebuild in EnsureOpen stays
  anyway, and not as a formality: a session that ran with the shadow switched
  off after a failure, or a log edited by an older build, still leaves the two
  out of step. Rebuilding is cheap (1,316 QSOs in 63 ms) and the .TRW is
  authoritative, so disagreement is settled rather than hoped about. *)
unit uLogStore;

{$I tr4w.inc}

interface

uses
   VC,
   uLogRepository;   (* TLogRepository -- see LogStoreRepository *)

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

(* Rewrites the shadow's newest row -- what the three "seek back one record"
  sites do to the binary log.  Never raises. *)
procedure LogStoreUpdateNewestQSO(const aQso: ContestExchange);

(* Rewrites the row matching a record's POSITION in the binary log -- what the
  QSO editor does with a byte offset.  Never raises. *)
procedure LogStoreUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange);

(* Rewrites the row the multi-op network identifies by (ceQSOID1, ceQSOID2).
  Does nothing when that pair is unset.  Never raises. *)
(* True when a QSO with that network key was found and rewritten.

  IT RETURNS SOMETHING NOW BECAUSE THE CALLER NEEDS IT. uNet's
  FindAndUpdateQSOInLog used to answer that question itself, by scanning
  the .TRW backwards until the key matched -- so it knew whether it had
  found one. The scan is gone; the answer has to come from here. *)
function LogStoreUpdateQSOBySessionIds(const aQso: ContestExchange): boolean;

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

(* APPLIES THE CONTEST CONFIGURATION THE LOG CARRIES -- phase E2.

  NY4I: "when done, the .cfg file should not be necessary."

  This is what makes that true. A contest .cfg is read once, when the log is
  created, and captured; from then on the LOG says what the contest is and the
  file is not consulted. Returns how many commands it applied, so a caller can
  tell "this log has none" from "this log has been read".

  ONLY source = 'contest'. See TLogRepository.LoadContestConfig for why. *)
function LogStoreApplyContestConfig: integer;

(* MAKES THE SQLITE LOG EXIST AND MATCH THE BINARY ONE, and returns whether it
  can be relied on.  Its file name is uLogDatabase.LogDatabaseFileName.

  THIS IS WHAT A READER NEEDS AND A WRITER DID NOT. While only writes were
  shadowed, the database was built lazily by the first append and no one else
  cared. A READ can now come first -- a headless export of a log this build has
  never appended to, or an operator opening the log window before working
  anybody -- and it must not find an absent or stale file.

  Rebuild-when-absent and the drift check already existed for the write path;
  this exposes them. Never raises: on failure the shadow disables itself and
  this returns False, which is the caller's cue to say so rather than to
  silently read the wrong store. *)
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
   (* uLogRepository is in the INTERFACE uses now -- LogStoreRepository's
      return type. *)
   SysUtils, Classes, MainUnit, uLogDatabase, uLogImport,
   uLogBinaryFile,
   (* The canonical sent-exchange builder -- the same one the UDP broadcast
      uses, so the database and the broadcast cannot disagree. *)
   uExchangeBuilder,
   (* The Cabrillo header's tag table -- CabrilloTagText answers from the live
      window when it is open and from the store otherwise. *)
   uCbrSum,
   (* The value and provenance accessors -- phase E1. CFGCA is gone; uCFG
      still owns CheckCommand and the renderer. *)
   uCFG,
   (* GetCQMemoryString / GetEXMemoryString -- the program's own accessors. *)
   LogCW,
   (* KeyId, which is the spelling a .cfg already uses for a function key. *)
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

function LogStoreIsUsable: boolean;
begin
   Result := (not GDisabled) and (GRepository <> nil);
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
         its own kind of contest-ending. *)
      ShowMessage(LclText(
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
   what an entry DECLARED is a fact about the entry, not about today. *)
function ReadEntryDeclaration: TLogEntryDeclaration;
begin
   FillChar(Result, SizeOf(Result), 0);

   (* UTF8Encode, not an AnsiString cast, on both: these declaration fields
     are AnsiStrings and the settings are UTF-16. The cast compiles and
     silently narrows; the encode states the conversion. A callsign and a
     POTA reference are both ASCII, so nothing changes in the bytes -- what
     changes is that the build can still count what it is counting. *)
   Result.MyCall := UTF8Encode(Settings.My.Call);
   Result.MyPark := UTF8Encode(Settings.My.Park);

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

  EVERY LIVE ROW, NOT THE ONES THAT LOOK CONTEST-SHAPED. Choosing a subset would
  mean this unit deciding which settings matter, which is exactly the judgement
  that leaves an operator's log missing the one thing they changed. Only csRem
  is skipped, because csRem means the command was WITHDRAWN -- recognised so an
  old config does not error, applied by nothing.

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

procedure CaptureConfiguration(const aWhy: string);
var
   i: integer;
   cmd: string;
   src: AnsiString;
   value: AnsiString;
   renderable: boolean;
   mode: ModeType;
   Column: LogColumnsType;
   key: AnsiChar;
   memText: ShortString;
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

         (* A CONTEST-SCOPED SETTING IS ALWAYS THE CONTEST'S, whatever file it
           arrived in. The band enables are the case: FCONTEST assigns them
           when a contest loads, so CommandCameFromContestCFG can say no --
           the value was not typed in a .cfg, it was computed -- and they
           would be recorded as the STATION'S. Measured in a real log before
           changing anything: HF, VHF and WARC BAND ENABLE all carried source
           'station' in target/2026 ARRL-10 NY4I, with WARC TRUE in a
           ten-metre contest.

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
            or (cmd = 'MY CALL')
            or Settings.CommandIsContestScoped(cmd) then
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

   (* THE FUNCTION-KEY MEMORIES, both kinds and both modes. GetCQMemoryString /
      GetEXMemoryString are the accessors the program itself uses, and KeyId is
      the spelling AppendConfigFile already writes into a .cfg -- so a message
      round-trips through the same names it has always had. *)
   for mode := CW to Phone do
      begin
      for key := F1 to AltF12 do
         begin
         (* ONLY KEYS THE PROGRAM CAN NAME.

            F1..AltF12 is a CHARACTER range, not an enumeration of function
            keys, so iterating it walks every code in between -- and several of
            those are not function keys at all. KeyId answers '' for them.

            That is not a cosmetic problem: the message table is keyed
            (kind, mode, key_id), so every unnamed key collapses onto the SAME
            row and each one silently overwrites the last. The first capture
            recorded a 'CQ/CW' memory of "QRL?" under an empty key, which is
            one of those codes winning the race.

            A key the program cannot name is also one a .cfg could never have
            expressed -- AppendConfigFile writes "CQ MEMORY " + KeyId(...) --
            so there is nothing here that a config file could round-trip. *)
         if KeyId(Char(key)) = '' then
            begin
            Continue;
            end;

         memText := GetCQMemoryString(mode, key);
         if memText <> '' then
            begin
            GRepository.SaveMessage('CQ', MessageModeName(mode),
                                    AnsiString(KeyId(Char(key))),
                                    AnsiString(memText), '');
            end;

         memText := GetEXMemoryString(mode, key);
         if memText <> '' then
            begin
            GRepository.SaveMessage('EX', MessageModeName(mode),
                                    AnsiString(KeyId(Char(key))),
                                    AnsiString(memText), '');
            end;
         end;
      end;

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

(* True when the shadow is open and usable.

  aRebuilt tells the caller the shadow was just built FROM THE BINARY LOG, which
  matters more than it looks -- see LogStoreAppendQSO. *)
(* aAppendPending -- THE CALLER IS PART WAY THROUGH ADDING A QSO.

   The binary record is written and the file CLOSED before LogStoreAppendQSO is
   called (LOGSUBS2.tAddQSOToLog, and that order is deliberate: the contact must
   be durable before anything else is attempted). So during an append the log
   holds exactly ONE record more than the shadow, and that is AGREEMENT, not
   drift.

   Reading it as drift is what the first version did, and the cost was not
   theoretical: EVERY RESUMED SESSION RE-IMPORTED THE WHOLE LOG on its first
   QSO, and the plain-reopen path below was never once taken -- dead code that
   looked live. Measured on the county-line harness with -KeepLog: "shadow holds
   2 record(s), the log holds 3", on a shadow that was perfectly in step.

   AN EXACT EXPECTATION, NOT A TOLERANCE. Accepting a difference of one in
   either direction would have been fewer lines and would have made a genuinely
   lost record invisible -- which is the one thing this check exists to catch. *)
function EnsureOpen(out aRebuilt: boolean; aAppendPending: boolean): boolean;
var
   dbName: string;
   trwCount: Int64;
   expected: Int64;
   (* True only on the open that CREATED this log -- see the capture below. *)
   isNewLog: boolean;
   res: TLogImportResult;
   integrity: TIntegrityResult;
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

      if FileExists(dbName) then
         begin
         GDatabase.Open(dbName);
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

      GRepository := TLogRepository.Create(GDatabase);


      GRepository.SetEntryDeclaration(ReadEntryDeclaration);

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
         (GRepository.LogContest = DUMMYCONTEST) and
         (Contest <> DUMMYCONTEST) then
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
                        [ContestTypeSA[Contest]]);
            end;
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
      (* False: no append is in flight, so the store is expected to be exactly
        in step rather than one record behind. *)
      if not EnsureOpen(rebuilt, False) then
         begin
         Exit;
         end;
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

(* Open the staged file on its OWN connection and ask SQLite whether it is
  sound. A second connection is the point: verifying through the connection
  that wrote it would prove far less, since that one already has the pages in
  its own cache. *)
function StagedBackupIsSound(const aPath: string; out aWhy: string): boolean;
var
   check: TLogDatabase;
   verdict: TIntegrityResult;
begin
   Result := False;
   aWhy   := '';
   check  := TLogDatabase.Create;
   try
      try
         check.Open(aPath);
         verdict := check.CheckIntegrity;
         Result  := verdict.Ok;
         if not Result then
            begin
            aWhy := verdict.Report;
            end;
      except
         on E: Exception do
            begin
            (* It would not even OPEN, which is the most important failure to
              report plainly: the snapshot statement said it succeeded. *)
            aWhy := E.Message;
            end;
      end;
   finally
      check.Free;
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

function LogStoreBackup(const aDestination: string; out aReport: string): boolean;
var
   staged: string;
   previous: string;
   why: string;
begin
   Result  := False;
   aReport := '';

   if Trim(aDestination) = '' then
      begin
      aReport := 'No backup file name is set. See BACKUP LOG FILE NAME.';
      Exit;
      end;

   if not LogStoreEnsureOpen then
      begin
      aReport := 'The contest log could not be opened, so it was not backed up.';
      Exit;
      end;

   staged   := aDestination + '.new';
   previous := aDestination + '.bak';

   try
      (* A staged file left by an interrupted run would make SnapshotTo refuse,
        and it is worth nothing -- the whole point of staging is that it is not
        the backup until it verifies. *)
      if SysUtils.FileExists(staged) then
         begin
         SysUtils.DeleteFile(staged);
         end;

      GDatabase.SnapshotTo(staged);

      if not StagedBackupIsSound(staged, why) then
         begin
         SysUtils.DeleteFile(staged);
         aReport := SysUtils.Format('The backup of %s failed its integrity check and '
                           + 'was discarded: %s', [aDestination, why]);
         Exit;
         end;

      (* PUBLISH. The previous backup is displaced rather than deleted, so a
        machine that dies between these two renames still has one good copy
        under one of the two names. *)
      if SysUtils.FileExists(aDestination) then
         begin
         if SysUtils.FileExists(previous) then
            begin
            SysUtils.DeleteFile(previous);
            end;
         SysUtils.RenameFile(aDestination, previous);
         end;

      if not SysUtils.RenameFile(staged, aDestination) then
         begin
         aReport := SysUtils.Format('The backup was written and verified but could not '
                           + 'be renamed to %s. It is at %s.',
                           [aDestination, staged]);
         Exit;
         end;

      aReport := SysUtils.Format('Log backed up to %s.', [aDestination]);
      Result  := True;
   except
      on E: Exception do
         begin
         (* NOT Disable. A backup that fails says nothing about whether the log
           itself is writable, and switching the store off here would turn a
           full backup volume into a contest that cannot log. *)
         if SysUtils.FileExists(staged) then
            begin
            SysUtils.DeleteFile(staged);
            end;
         aReport := SysUtils.Format('The backup to %s failed: %s',
                           [aDestination, E.Message]);
         end;
   end;
end;

function LogStoreAppendQSO(const aQso: ContestExchange): boolean;
var
   rebuilt: boolean;
   rowId: Int64;
begin
   (* FALSE UNTIL A COMMIT SAYS OTHERWISE. Every exit below that is not a
     completed commit leaves it here, which is the only default that cannot
     acknowledge a QSO nobody wrote. *)
   Result := False;

   if GDisabled then
      begin
      Exit;
      end;

   try
      (* True: tAddQSOToLog has already written this QSO to the binary log,
         so the log being one ahead of the shadow is expected. *)
      if not EnsureOpen(rebuilt, True) then
         begin
         Exit;
         end;

      (* THE SHADOW IS OPENED LAZILY, ON THE FIRST APPEND -- AND THE BINARY
        RECORD IS ALREADY ON DISK BY THEN.

        This call happens after tAddQSOToLog has written and closed the file,
        which is deliberate: the contact must be safe before anything else is
        attempted. But it means a rebuild-from-binary triggered HERE has already
        imported the very QSO being appended, and appending it again duplicates
        it.

        Measured, not reasoned: the county-line UI harness logged two QSOs and
        the shadow held THREE, with the first one twice.

        The drift check in EnsureOpen would have repaired it at the next open,
        which is some comfort -- but a shadow that is briefly wrong is a shadow
        nobody can trust mid-contest, and "it fixes itself later" is not a
        property to rely on. *)
      if rebuilt then
         begin
         (* THE REBUILD ALREADY IMPORTED THIS QSO, so appending would duplicate
            it -- but the import cannot know what was SENT, and this call can.
            Skipping outright therefore lost the sent exchange of the first QSO
            of every session, which is exactly the field this work exists to
            capture. Measured: row 1 came back with exchange_sent NULL while
            row 2 carried it.

            The record just written to the binary log is its LAST one, so the
            row the rebuild just imported is the newest -- update that one with
            what only the live path knows. *)
         GRepository.SetNextSentExchange(
            AnsiString(BuildSentExchangeText(aQso)));
         rowId := GRepository.NewestRowId;
         if rowId > 0 then
            begin
            GRepository.UpdateQSO(rowId, aQso);
            GRepository.Commit;
            end;

         (* TRUE EITHER WAY, and deliberately. The rebuild imported this QSO
           from the binary log, so the contact IS in the database -- that is
           what makes appending it again a duplicate. A failure to attach the
           sent exchange on top of it loses a field, not a contact, and
           reporting the QSO as unlogged here would have the operator work it
           again. *)
         Result := True;
         Exit;
         end;

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
      GRepository.SetNextSentExchange(
         AnsiString(BuildSentExchangeText(aQso)));

      (* The same grouping rule the importer uses -- a county line logged
        live must relate its rows exactly as an imported one does. *)
      GRepository.SaveQSOGroupingByExchangeId(aQso);

      (* PER QSO, not batched -- section 9b. An operator who loses power should
        lose at most the contact in progress.

        THE SECOND HALF OF THAT SENTENCE USED TO READ "and this is a shadow of
        a log that has already been written, so a slow commit costs nothing".
        It is not a shadow any more -- it is the log, and the .TRW behind that
        reassurance is gone. The commit is the contact. *)
      GRepository.Commit;

      (* AND ONLY NOW. *)
      Result := True;
   except
      on E: Exception do
         begin
         Disable('appending a QSO', E);
         end;
   end;
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
      if not EnsureOpen(rebuilt, False) then
         begin
         Exit;
         end;

      (* A rebuild has just re-read the binary log, which already contains this
        rewrite -- the caller writes the record before calling here, exactly as
        the append does. *)
      if rebuilt then
         begin
         Exit;
         end;

      rowId := GRepository.NewestRowId;
      if rowId <= 0 then
         begin
         (* Nothing to rewrite. Not an error: DeleteLastContact on an empty log
           is a no-op in the binary world too. *)
         Exit;
         end;

      GRepository.UpdateQSO(rowId, aQso);
      GRepository.Commit;
   except
      on E: Exception do
         begin
         Disable('rewriting the newest QSO', E);
         end;
   end;
end;

procedure LogStoreUpdateQSOAtIndex(aRecordIndex: Int64; const aQso: ContestExchange);
var
   rowId: Int64;
   rebuilt: boolean;
begin
   if GDisabled then
      begin
      Exit;
      end;

   try
      if not EnsureOpen(rebuilt, False) then
         begin
         Exit;
         end;
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
         (* The shadow is short of that record. EnsureOpen's drift check will
           rebuild at the next open; saying so here is what makes that visible
           rather than mysterious. *)
         if logger <> nil then
            begin
            logger.Warn('[LogStore] no row at record index %d -- the shadow ' +
                        'will be rebuilt from the binary log', [aRecordIndex]);
            end;
         Exit;
         end;

      GRepository.UpdateQSO(rowId, aQso);
      GRepository.Commit;
   except
      on E: Exception do
         begin
         Disable('rewriting a QSO by position', E);
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
      if not EnsureOpen(rebuilt, False) then
         begin
         Exit;
         end;

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

function LogStoreApplyContestConfig: integer;
var
   rebuilt: boolean;
   rows: TStringList;
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
      if not EnsureOpen(rebuilt, False) then
         begin
         Exit;
         end;

      rows := TStringList.Create;
      try
         GRepository.LoadContestConfig(rows);
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
         if (GRepository.LogContest <> DUMMYCONTEST) and
            ((CFGCommandValueAsString('CONTEST') = '') or
             (CFGCommandValueAsString('CONTEST') =
              string(ContestTypeSA[DUMMYCONTEST]))) then
            begin
            cmdName := ShortString(AnsiString('CONTEST'));
            valName := ShortString(AnsiString(
               ContestTypeSA[GRepository.LogContest]));
            (* ONLY IF IT IS NOT ALREADY RIGHT. FoundContest is NOT
               idempotent -- re-running it appends to the domestic file name
               (dom\iaruhq.domiaruhq.dom), and applying it unconditionally on
               every open took the golden corpus from 20 passed to 10 passed /
               14 failed in one run. The comparison is against the CFGCA row
               because that is what the hook maintains; the VALUE comes from
               the contest table because that is what is trustworthy. *)
            if (CFGCommandValueAsString('CONTEST') <> string(valName)) and
               CheckCommand(@cmdName, valName, True) then
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
         else if (GRepository.LogContest = DUMMYCONTEST) and
                 (Contest <> DUMMYCONTEST) then
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
                           [ContestTypeSA[Contest]]);
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
         else if (Contest <> DUMMYCONTEST) and
                 (GRepository.LogContest <> Contest) and
                 CommandCameFromContestCFG('CONTEST') then
            begin
            if logger <> nil then
               begin
               logger.Warn('[LogStore] this log was stamped %s and its .cfg ' +
                           'says %s -- correcting the log. The stamp came ' +
                           'from a binary import, whose contest ordinal was ' +
                           'written under an older layout.',
                           [ContestTypeSA[GRepository.LogContest],
                            ContestTypeSA[Contest]]);
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
            if (CFGCommandValueAsString(cmd) = val) and
               (not UnicodeSameText(cmd, 'CONTEST')) then
               begin
               inc(Result);
               Continue;
               end;

            FillChar(cmdName, SizeOf(cmdName), 0);
            FillChar(valAsShort, SizeOf(valAsShort), 0);
            cmdName := ShortString(AnsiString(cmd));

            (* PLAIN ASSIGNMENT, NOT ShortString(val).

               THE CAST IS NOT A CONVERSION. FPC reinterprets the string's
               POINTER as a ShortString -- the first byte of the pointer becomes
               the length -- so CheckCommand received garbage and rejected every
               command, silently and with a perfectly plausible warning saying
               the build would not accept the value. The value was fine; it
               never arrived.

               CLAUDE.md lists this under "Strings and buffers" and it has now
               cost two separate sessions of this migration. Assignment converts
               and truncates correctly; the cast compiles and lies. *)
            valAsShort := ShortString(AnsiString(val));
            if CheckCommand(@cmdName, valAsShort, True) then
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
   (* aAppendPending FALSE: nobody is part way through adding a QSO here, so the
      log and the shadow should agree exactly. *)
   Result := EnsureOpen(rebuilt, False);
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
  the settings work rather than here. *)
procedure CaptureConfigurationOnClose;
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
   try
      (* AND THIS ONE IS NOT A CONVERSION. It runs on every clean exit of an
        interactive session and records what the session ENDED with, so an
        operator checking whether the import re-ran can tell the two apart by
        the reason rather than by the line number. *)
      CaptureConfiguration('recorded on exit -- the settings this session ended with');
   except
      on E: Exception do
         begin
         (* Reported, not raised: this runs while shutting down, and a failure
            to record a setting must not stop the program closing its log. *)
         if logger <> nil then
            begin
            logger.Error('[LogStore] the configuration could not be recorded ' +
                         'on close: %s -- %s. QSOs are unaffected.',
                         [E.ClassName, E.Message]);
            end;
         end;
   end;
end;

procedure LogStoreClose;
begin
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

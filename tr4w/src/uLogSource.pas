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

(* WHERE AN EXPORT READS ITS QSOs FROM -- STEP B3, THE EQUIVALENCE GATE.

  TR4W has two copies of the log now: the binary .TRW it has always written and
  the SQLite database written beside it (uLogStore). B3 asks the one question
  that decides whether the second can replace the first:

    EXPORTED FROM THE DATABASE, DOES THE PROGRAM PRODUCE THE SAME BYTES?

  The golden corpus is what answers it. Its 26 reference artifacts were written
  by D7 -- A DIFFERENT PROGRAM -- and that independence is the whole value of
  the oracle, so the references do not change here and must never be rebaselined
  from our own output. Only the SOURCE changes, and the corpus is run BOTH ways:
  two independent readers agreeing on 26 byte-exact files is the proof, and it
  is available only while both readers exist.

  WHY A CURSOR AND NOT A LIST. The thirteen export loops in PostUnit are shaped

      if not OpenLogFile then Exit;
      ReadVersionBlock;
      while ReadLogFile do          -- fills the TempRXData global
         if GoodLookingQSO then ...

  and several of them accumulate scoring inline, with gotos. Handing them an
  array would mean rewriting every loop -- and then a difference in the output
  could have come from the rewrite rather than from the store, which is exactly
  what this step exists to rule out. So the shape is preserved exactly and only
  the three verbs are repointed. A difference in the bytes can then have come
  from ONE place.

  THE BINARY ARM IS NOT A COPY of MainUnit's cursor, it CALLS it. There is one
  implementation of reading a .TRW and it stays where it is.

  This unit is deliberately small and dumb: no filtering, no ordering decisions,
  no GoodLookingQSO. Those belong to the caller and are identical either way. *)
unit uLogSource;

{$I tr4w.inc}

interface

uses
   VC;

type
   (* lsBinary -- the .TRW, exactly as before, and the default.
      lsDatabase -- the SQLite log written beside it. *)
   TLogSourceKind = (lsBinary, lsDatabase);

var
   (* THE DEFAULT IS THE DATABASE -- STEP B4, THE READ FLIP.

      It was lsBinary until B3 proved the two stores produce identical bytes:
      13 corpus logs, 1,855 QSOs, zero differences in ADIF and Cabrillo. That
      measurement is the entire warrant for this line, and it is re-runnable --
      tr4w/test/corpus/compare-stores.sh, which forces each store explicitly and
      is therefore unaffected by whatever this default happens to be.

      WHAT STILL WRITES THE .TRW: everything. B4 moves READS only. The binary
      log remains authoritative on disk, the shadow keeps it in step, and a
      reader that cannot make the database current REFUSES rather than quietly
      falling back -- see LogSourceOpen. Writes move at B5, and that is also
      where this variable and the whole two-store idea stop being needed. *)
   LogSourceKind: TLogSourceKind = lsDatabase;

(* Opens the log for a sequential read.  False if it cannot be read at all. *)
(* WHETHER A READ CAN BE MADE RIGHT NOW.

  THE REAL STATE, NOT A FLAG SOMEBODY SET. Thirty-three call sites in twelve
  units call LogSourceClose -- PostUnit alone has seventeen -- so a caller that
  remembers "I opened it" in a boolean of its own is remembering something any
  other unit can invalidate without telling it.

  That is not hypothetical. The main window log kept exactly such a flag and
  went blank the moment a QSO was logged: LogSourceRecordCount answers -1 when
  the source is shut, LogSourceReadAtIndex then rejects every index as past the
  end, and the whole grid paints empty -- including the contact just entered
  (NY4I, 2026-09-04).

  Ask this, and reopen if it says no. *)
function LogSourceIsOpen: boolean;

(* Let go of the read snapshot, so the next read sees what another connection
  has committed since. See TLogRepository.RefreshSnapshot. *)
procedure LogSourceRefreshSnapshot;

function LogSourceOpen: boolean;

(* Positions at the first QSO -- the ReadVersionBlock equivalent.  Call after
  LogSourceOpen and before the first LogSourceNext. *)
procedure LogSourceRewind;

(* Reads the next QSO.  False at the end.  Fills aQso with zeroes when it
  returns False, so a caller that ignores the result reads a blank rather than
  the previous record again. *)
function LogSourceNext(out aQso: ContestExchange): boolean;

procedure LogSourceClose;

(* HOW MANY QSO RECORDS THE LOG HOLDS.  -1 if it cannot be read.

  Callers asked this with Windows.GetFileSize(LogHandle) arithmetic, which is
  three separate assumptions about the store: that it is a file, that its
  records are fixed width, and that its header is one record long. A count is
  the question they were actually asking.

  A TRAP THIS REPLACES. SizeOfTLogHeader and SizeOf(ContestExchange) are BOTH
  376 bytes, so `GetFileSize div SizeOf(ContestExchange)` returns N + 1, and
  LOGEDIT's `for Offset := 1 to records - 1` therefore covered all N records --
  correct only because the two sizes coincide. Nothing says they must, and a
  field added to TLogHeader would have silently dropped the oldest QSO from
  every reverse scan. This returns N. *)
function LogSourceRecordCount: Int64;

(* THE aOffsetFromEnd'th RECORD BACK FROM THE END: 1 is the last one logged.

  What a reverse scan wants, and what `tSetFilePointer(-n * SizeOf(rec),
  FILE_END)` meant. Independent of any sequential read in progress, so a caller
  may use it without disturbing an open cursor. False when there is no such
  record. *)
function LogSourceReadFromEnd(aOffsetFromEnd: Int64;
                              out aQso: ContestExchange): boolean;

(* THE RECORD AT aIndex, 0-BASED, IN LOG ORDER.

  What the QSO editor and the search results address. They held a BYTE OFFSET
  into the .TRW until B5 and each rebuilt it as
  index * SizeOf(ContestExchange) + SizeOfTLogHeader, which restated the file
  layout in three unrelated units and produced an off-by-one on the way back
  (see VC.IndexOfItemInLogForEdit).

  Independent of any sequential read in progress. False when there is no such
  record. *)
function LogSourceReadAtIndex(aIndex: Int64;
                              out aQso: ContestExchange): boolean;

(* The file the current source reads -- for diagnostics and for the corpus
  driver to report which store produced an artifact. *)
function LogSourceDescription: string;

implementation

uses
   (* uLogStore for LogStoreEnsureOpen ONLY -- see LogSourceOpen. At B3 this
      clause said the dependency must not exist, on the grounds that uLogStore
      is deleted at B5. That had it backwards: the call is needed exactly while
      two stores exist, so it dies with the unit rather than outliving it.

      The database's NAME still comes from uLogDatabase, which does outlive the
      shadow. *)
   SysUtils, Windows, MainUnit, uLogDatabase, uLogRepository, uLogStore,
   (* TempRXData, which is declared in PostUnit's INTERFACE and is what
      MainUnit.ReadLogFile fills. PostUnit uses this unit in ITS
      implementation, so the pair is circular -- normal in this tree and
      legal because both edges are implementation-section. *)
   PostUnit;

(* The SQLite log beside the current binary log.  One call, so the two
  arms below and the diagnostic cannot name different files. *)
function DatabasePath: string;
begin
   Result := LogDatabaseFileName(string(StrPas(TR4W_LOG_FILENAME)));
end;

var
   GDatabase: TLogDatabase = nil;
   GRepository: TLogRepository = nil;

   (* True between LogSourceOpen and LogSourceClose, for the nesting guard. *)
   GOpen: boolean = False;

(* THE READ SOURCE IS A SINGLE GLOBAL CURSOR, so it cannot be opened twice --
  and neither could the thing it replaces: MainUnit's OpenLogFile stores one
  handle in the LogHandle global, so a nested open OVERWRITES it, leaks the
  first, and then CloseLogFile shuts the inner one while the outer loop believes
  it is still reading.

  That is a real hazard in this file's shape. PostUnit's readers each open and
  close, and one of them -- GetOperatorsFromLog -- is called from inside another
  reader's routine. It happens to be called BEFORE that routine's own open (line
  2705 against 2848) so the two never overlap, but nothing enforces that and
  nothing would say so if a later edit moved one line.

  So the nesting that the binary path handles SILENTLY AND BADLY is reported
  here instead. Not fixed by allowing it: allowing it would make the two arms
  behave differently, and the entire value of this seam is that they do not. *)
procedure WarnIfAlreadyOpen;
begin
   if GOpen and (logger <> nil) then
      begin
      logger.Warn('[LogSource] opened while already open. The previous read is ' +
                  'abandoned -- the binary path silently did the same thing, ' +
                  'so this is a latent bug being made visible, not a new one.');
      end;
end;

procedure LogSourceRefreshSnapshot;
begin
   if (LogSourceKind = lsDatabase) and (GRepository <> nil) then
      begin
      GRepository.RefreshSnapshot;
      end;
end;

function LogSourceIsOpen: boolean;
begin
   case LogSourceKind of
      lsDatabase:
         begin
         Result := GRepository <> nil;
         end;
      else
         begin
         Result := LogHandle <> INVALID_HANDLE_VALUE;
         end;
      end;
end;

function LogSourceOpen: boolean;
begin
   WarnIfAlreadyOpen;
   GOpen := True;
   case LogSourceKind of
      lsDatabase:
         begin
         LogSourceClose;
         try
            (* THE DATABASE MUST EXIST AND MATCH BEFORE IT CAN BE READ.

               uLogStore owns that guarantee -- it is the unit that keeps the
               two stores in step -- so this asks rather than reimplements. A
               headless export of a log this build has never appended to gets
               the database built from the .TRW right here, which is what lets
               the corpus fixtures (a .TRW and nothing else) be read from
               SQLite at all.

               THE DEPENDENCY ON uLogStore IS DELIBERATE AND TEMPORARY, and it
               corrects what this unit said at B3. The reason given then -- that
               uLogStore is deleted at B5 -- was the wrong way round: the need
               for this call lasts exactly as long as TWO STORES exist, which is
               exactly uLogStore's lifetime. At B5 the call and the unit go
               together. *)
            if not LogStoreEnsureOpen then
               begin
               if logger <> nil then
                  begin
                  logger.Error('[LogSource] the SQLite log could not be made ' +
                               'current from %s -- refusing to read. The binary ' +
                               'log is untouched.', [DatabasePath]);
                  end;
               Result := False;
               Exit;
               end;

            GDatabase := TLogDatabase.Create;
            (* The name rule lives in uLogDatabase. Deriving it a
               second time here is how the two would come to disagree. *)
            GDatabase.Open(DatabasePath);
            GRepository := TLogRepository.Create(GDatabase);
            Result := True;
         except
            on E: Exception do
               begin
               (* REPORTED, NOT SILENTLY FALLEN BACK TO THE BINARY LOG. A
                  fallback here would make a corpus run that was supposed to
                  prove the database quietly prove the .TRW again, and pass. *)
               if logger <> nil then
                  begin
                  logger.Error('[LogSource] cannot open the SQLite log %s: ' +
                               '%s -- %s. The export will produce nothing; it ' +
                               'will NOT fall back to the binary log.',
                               [DatabasePath, E.ClassName, E.Message]);
                  end;
               LogSourceClose;
               Result := False;
               end;
            end;
         end;
      else
         begin
         Result := OpenLogFile;
         end;
      end;
end;

procedure LogSourceRewind;
begin
   case LogSourceKind of
      lsDatabase:
         begin
         if GRepository <> nil then
            begin
            GRepository.OpenSequentialRead;
            end;
         end;
      else
         begin
         ReadVersionBlock;
         end;
      end;
end;

function LogSourceNext(out aQso: ContestExchange): boolean;
begin
   case LogSourceKind of
      lsDatabase:
         begin
         Result := (GRepository <> nil) and GRepository.ReadNext(aQso);
         end;
      else
         begin
         (* MainUnit's ReadLogFile reads into the TempRXData global rather than
            into a parameter, which is why this copies. Every caller passes
            TempRXData itself, so the copy is to the same record and costs
            nothing; a caller that passes something else gets what it asked
            for instead of a hidden write to a global. *)
         Result := ReadLogFile;
         aQso := TempRXData;
         end;
      end;
end;

procedure LogSourceClose;
begin
   GOpen := False;
   case LogSourceKind of
      lsDatabase:
         begin
         if GRepository <> nil then
            begin
            GRepository.CloseSequentialRead;
            end;
         FreeAndNil(GRepository);
         FreeAndNil(GDatabase);
         end;
      else
         begin
         CloseLogFile;
         end;
      end;
end;

function LogSourceRecordCount: Int64;
var
   sizeBytes: DWORD;
begin
   case LogSourceKind of
      lsDatabase:
         begin
         if GRepository <> nil then
            begin
            Result := GRepository.RecordCount;
            end
         else
            begin
            Result := -1;
            end;
         end;
      else
         begin
         Result := -1;
         if LogHandle = INVALID_HANDLE_VALUE then
            begin
            Exit;
            end;
         sizeBytes := Windows.GetFileSize(LogHandle, nil);
         if sizeBytes = INVALID_FILE_SIZE then
            begin
            Exit;
            end;
         if sizeBytes < SizeOfTLogHeader then
            begin
            Result := 0;
            Exit;
            end;
         Result := (Int64(sizeBytes) - SizeOfTLogHeader) div SizeOf(ContestExchange);
         end;
      end;
end;

function LogSourceReadFromEnd(aOffsetFromEnd: Int64;
                              out aQso: ContestExchange): boolean;
var
   total: Int64;
   rowId: Int64;
   bytesRead: Cardinal;
begin
   FillChar(aQso, SizeOf(aQso), 0);
   Result := False;
   total := LogSourceRecordCount;
   if (aOffsetFromEnd < 1) or (total < aOffsetFromEnd) then
      begin
      Exit;
      end;

   case LogSourceKind of
      lsDatabase:
         begin
         (* RowIdAtIndex is 0-based from the START, in id order -- which is log
            order. Offset 1 (the last record) is index total - 1. *)
         rowId := GRepository.RowIdAtIndex(total - aOffsetFromEnd);
         if rowId > 0 then
            begin
            Result := GRepository.LoadQSO(rowId, aQso);
            end;
         end;
      else
         begin
         (* The seek this replaces, unchanged: negative from FILE_END. *)
         tSetFilePointer(-1 * aOffsetFromEnd * SizeOf(ContestExchange), FILE_END);
         Windows.ReadFile(LogHandle, aQso, SizeOf(ContestExchange), bytesRead, nil);
         Result := bytesRead = SizeOf(ContestExchange);
         end;
      end;
end;

function LogSourceReadAtIndex(aIndex: Int64;
                              out aQso: ContestExchange): boolean;
var
   total: Int64;
   rowId: Int64;
   bytesRead: Cardinal;
begin
   FillChar(aQso, SizeOf(aQso), 0);
   Result := False;
   total := LogSourceRecordCount;
   if (aIndex < 0) or (aIndex >= total) then
      begin
      Exit;
      end;

   case LogSourceKind of
      lsDatabase:
         begin
         rowId := GRepository.RowIdAtIndex(aIndex);
         if rowId > 0 then
            begin
            Result := GRepository.LoadQSO(rowId, aQso);
            end;
         end;
      else
         begin
         (* The header sits ahead of record 0. This is the ONE place that fact
            is written down now. *)
         tSetFilePointer(SizeOfTLogHeader + aIndex * SizeOf(ContestExchange),
                         FILE_BEGIN);
         Windows.ReadFile(LogHandle, aQso, SizeOf(ContestExchange), bytesRead, nil);
         Result := bytesRead = SizeOf(ContestExchange);
         end;
      end;
end;

function LogSourceDescription: string;
begin
   case LogSourceKind of
      lsDatabase: Result := 'SQLite: ' + DatabasePath;
      else        Result := 'binary: ' + string(AnsiString(TR4W_LOG_FILENAME));
      end;
end;

end.

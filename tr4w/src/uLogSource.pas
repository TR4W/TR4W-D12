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

(* WHERE AN EXPORT READS ITS QSOs FROM -- THE SQLITE LOG, AND NOTHING ELSE.

  THERE IS NO SOURCE SELECTION HERE ANY MORE (2026-09-24, NY4I). This unit
  carried a TLogSourceKind with two arms -- the binary .TRW and the SQLite
  database -- because step B3 had to run the SAME export over the SAME logs
  from two independent readers and byte-compare the artifacts. That gate passed
  and the database became the default at B4; B5 deleted the binary WRITE path;
  and /EXPORTTRW, the only thing in the tree that could ever select the .TRW,
  went on 2026-09-24. The variable had one reachable state left.

  A TWO-STATE VARIABLE WITH ONE REACHABLE STATE IS NOT A CHOICE, IT IS A
  COMMENT THAT COMPILES -- and a worse one than prose, because it advertises an
  option the program cannot take and the compiler cannot warn about an
  unreachable case arm. So the type, the variable and the binary arms are gone
  and every routine below reads the database in a straight line.

  THE .TRW IS STILL READ, ELSEWHERE, FOR A DIFFERENT QUESTION. uLogBinaryFile
  and uLogImport read one to BUILD a database, which is how an operator
  upgrading from 4.x gets their logs in, and six fixtures under
  test/unit/fixtures/binarylog pin it. That is IMPORT; this unit was SOURCE
  SELECTION. Nothing here touches it.

  WHY A CURSOR AND NOT A LIST. The thirteen export loops in PostUnit are shaped

      if not LogSourceOpen then Exit;
      LogSourceRewind;
      while LogSourceNext(rec) do
         if GoodLookingQSO then ...

  and several of them accumulate scoring inline, with gotos. Handing them an
  array would mean rewriting every loop -- and then a difference in the output
  could have come from the rewrite rather than from the store, which is exactly
  what the equivalence gate existed to rule out. The shape is preserved.

  This unit is deliberately small and dumb: no filtering, no ordering decisions,
  no GoodLookingQSO. Those belong to the caller. *)
unit uLogSource;

{$I tr4w.inc}

interface

uses
   VC;

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

(* Opens the log for a sequential read.  False if it cannot be read at all. *)
function LogSourceOpen: boolean;

(* Positions at the first QSO.  Call after LogSourceOpen and before the first
  LogSourceNext. *)
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

(* A RUN OF RECORDS FROM aFirstIndex, in log order. Fills aRows and returns how
  many were read -- fewer than asked for at the end of the log.

  WHAT A GRID ASKS FOR, AND THEREFORE WHAT THE SEAM SHOULD OFFER. Reading a
  screenful one index at a time cost three SQL statements per row, each
  compiled and thrown away, one of them an O(n) OFFSET walk and one a full
  row count. One statement for the run instead. *)
function LogSourceReadRange(aFirstIndex: Int64;
                            var aRows: array of ContestExchange): integer;

implementation

uses
   (* uLogStore for LogStoreEnsureOpen ONLY -- see LogSourceOpen. At B3 this
      clause said the dependency must not exist, on the grounds that uLogStore
      is deleted at B5. That had it backwards: the call is needed exactly while
      two stores exist, so it dies with the unit rather than outliving it.

      The database's NAME still comes from uLogDatabase, which does outlive the
      shadow. *)
   SysUtils, MainUnit, uLogDatabase, uLogRepository, uLogStore,
   utils_text;   (* CharBufferText -- the log name buffer *)

(* The SQLite log beside the contest's log name.  One call, so no routine
  below can name a different file. *)
function DatabasePath: string;
begin
   Result := LogDatabaseFileName(CharBufferText(TR4W_LOG_FILENAME));
end;

var
   (* NO CONNECTION OF ITS OWN. It reads through uLogStore's -- see
     LogStoreRepository, and Repo below. *)

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

  So the nesting that the binary path handled SILENTLY AND BADLY is reported
  here instead. It is reported rather than allowed: a second open abandons the
  first caller's cursor, and a caller that believes it is still reading is the
  bug, not the warning. *)
procedure WarnIfAlreadyOpen;
begin
   if GOpen and (logger <> nil) then
      begin
      logger.Warn('[LogSource] opened while already open. The previous read is ' +
                  'abandoned -- the binary path silently did the same thing, ' +
                  'so this is a latent bug being made visible, not a new one.');
      end;
end;

(* THE REPOSITORY THIS UNIT READS THROUGH -- uLogStore's, never its own.

  Nil is an ordinary answer: the store may not be open, or a failure may have
  disabled it. Every caller below checks. *)
function Repo: TLogRepository;
begin
   Result := LogStoreRepository;
end;

function LogSourceIsOpen: boolean;
begin
   Result := Repo <> nil;
end;

function LogSourceOpen: boolean;
begin
   WarnIfAlreadyOpen;
   GOpen := True;
   LogSourceClose;
   try
      (* THE DATABASE MUST EXIST AND BE OPEN BEFORE IT CAN BE READ.

         uLogStore owns that guarantee, so this asks rather than reimplements.
         A headless export of a log this build has never appended to gets the
         database opened right here, which is what lets the corpus fixtures be
         read at all. *)
      if not LogStoreEnsureOpen then
         begin
         if logger <> nil then
            begin
            logger.Error('[LogSource] the SQLite log %s could not be opened ' +
                         '-- refusing to read.', [DatabasePath]);
            end;
         Result := False;
         Exit;
         end;

      (* NOTHING IS OPENED HERE. LogStoreEnsureOpen above has made the one
         connection exist and be current; this unit reads through it. Opening
         a second one on the same file is what left the grid a QSO behind --
         see LogStoreRepository. *)
      Result := Repo <> nil;
      if (not Result) and (logger <> nil) then
         begin
         logger.Error('[LogSource] the log store reports no repository ' +
                      'after a successful open -- refusing to read.');
         end;
   except
      on E: Exception do
         begin
         (* REPORTED, NOT SILENTLY DEGRADED. An export that cannot reach the
            log must say so; there is no second store to fall back to, and
            when there was, falling back made a run that was supposed to prove
            the database quietly prove the .TRW again, and pass. *)
         if logger <> nil then
            begin
            logger.Error('[LogSource] cannot open the SQLite log %s: ' +
                         '%s -- %s. The export will produce nothing.',
                         [DatabasePath, E.ClassName, E.Message]);
            end;
         LogSourceClose;
         Result := False;
         end;
      end;
end;

procedure LogSourceRewind;
begin
   if Repo <> nil then
      begin
      Repo.OpenSequentialRead;
      end;
end;

function LogSourceNext(out aQso: ContestExchange): boolean;
begin
   Result := (Repo <> nil) and Repo.ReadNext(aQso);
end;

procedure LogSourceClose;
begin
   GOpen := False;
   (* THE CURSOR, NOT THE CONNECTION. The connection belongs to uLogStore and
     is closed by LogStoreClose at shutdown. Freeing it here would take the log
     out from under the writer, and it is what made "open while already open"
     destructive rather than merely untidy. *)
   if Repo <> nil then
      begin
      Repo.CloseSequentialRead;
      end;
end;

function LogSourceRecordCount: Int64;
begin
   if Repo <> nil then
      begin
      Result := Repo.RecordCount;
      end
   else
      begin
      Result := -1;
      end;
end;

function LogSourceReadFromEnd(aOffsetFromEnd: Int64;
                              out aQso: ContestExchange): boolean;
var
   total: Int64;
   rowId: Int64;
begin
   FillChar(aQso, SizeOf(aQso), 0);
   Result := False;
   total := LogSourceRecordCount;
   if (aOffsetFromEnd < 1) or (total < aOffsetFromEnd) then
      begin
      Exit;
      end;

   (* RowIdAtIndex is 0-based from the START, in id order -- which is log
     order. Offset 1 (the last record) is index total - 1. *)
   rowId := Repo.RowIdAtIndex(total - aOffsetFromEnd);
   if rowId > 0 then
      begin
      Result := Repo.LoadQSO(rowId, aQso);
      end;
end;

function LogSourceReadAtIndex(aIndex: Int64;
                              out aQso: ContestExchange): boolean;
var
   total: Int64;
   rowId: Int64;
begin
   FillChar(aQso, SizeOf(aQso), 0);
   Result := False;
   (* CHEAP NOW, AND IT WAS NOT. This bounds check ran a SELECT row count --
      a full table scan -- on every single row fetch, 1.3 ms of it at 8,448
      rows. TLogRepository caches the count and invalidates it on insert. *)
   total := LogSourceRecordCount;
   if (aIndex < 0) or (aIndex >= total) then
      begin
      Exit;
      end;

   rowId := Repo.RowIdAtIndex(aIndex);
   if rowId > 0 then
      begin
      Result := Repo.LoadQSO(rowId, aQso);
      end;
end;

function LogSourceReadRange(aFirstIndex: Int64;
                            var aRows: array of ContestExchange): integer;
begin
   Result := 0;
   if Length(aRows) <= 0 then
      begin
      Exit;
      end;

   if Repo <> nil then
      begin
      Result := Repo.ReadRange(aFirstIndex, aRows);
      end;
end;

end.

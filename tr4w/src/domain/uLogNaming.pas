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

(* WHAT A CONTEST LOG IS CALLED.

  ONE FILE IN ONE DIRECTORY. No folder per contest -- NY4I, 2026-09-02: "There
  is really no reason for a folder for each one anymore."

  The folder was not arbitrary; it existed because a contest produced EIGHT
  files: the .CFG, the .TRW, the .RST, an .ADI and a .LOG when exported,
  SERVERLOG.TMP, REMAININGMULTS.TXT and sometimes a .DOM override. Grouping
  them was the only way to keep a directory legible. With a single .db that
  reason is gone, and a folder holding one file is a level of nesting an
  operator has to open before seeing anything.

  THE NAME FOLLOWS TR4QT, WHICH NY4I ASKED FOR: its ContestChooserDialog builds
  "CONTESTTYPE_YYYY_MM_DD" and appends ".db", so a logs directory sorts by
  contest and then by date.

  WITH THE CALLSIGN KEPT, WHICH TR4QT DROPS. TR4W has always had it -- the old
  folder was "<year> <contest> <call>" -- and it is not decoration: an operator
  who runs one contest as NY4I and again as W4XX, or who guest-operates,
  otherwise gets one name for two logs. TR4QT can omit it because its contest id
  is a database key with the callsign stored inside; here the FILE NAME is the
  identity, so it has to carry enough to be unique.

  ORDER IS CONTEST, DATE, CALL. Contest first because that is what an operator
  looks for; date second because it is what distinguishes two runnings of the
  same contest and sorts correctly; callsign last because it is the rarest thing
  to vary. *)
unit uLogNaming;

{$I tr4w.inc}

interface

uses
   SysUtils;

(* The file name -- no directory -- for a contest log.

  aContest is the contest's name as an operator sees it ("ARRL-DX-CW"),
  aWhen its start date, aCall the station callsign. Any of them may be empty;
  the result is still a usable name rather than a malformed one, because this
  is called from a dialog where a field can legitimately not be filled in yet. *)
function ContestLogFileName(const aContest: string; aWhen: TDateTime;
                            const aCall: string): string;

(* Strips the characters a file name cannot hold, and collapses what is left.

  Contest names and callsigns reach this from operator-typed fields. A portable
  name is worth more than a faithful one: this runs on Windows today and the
  cross-platform work is coming, so the set removed is the UNION of what Windows
  and POSIX object to, not just Windows'. *)
function SanitiseForFileName(const aText: string): string;

type
   (* Whether a full path names an existing file. The question FirstFreeLogFileName
     asks, passed in so a test can answer it without a disk. *)
   TLogFileTaken = function(const aPath: string): boolean;

(* THE FIRST NAME IN aDir THAT NAMES NO FILE (issue 276, NY4I 2026-11-11).

  aFileName is the default -- ContestLogFileName's answer, no directory. When it
  is free it is the answer; otherwise a number goes before the extension,
  space-separated like the rest of the name: "X.db", "X 2.db", "X 3.db"... The
  FIRST free number wins, so a gap left by a renamed log is filled.

  WHY A NUMBER AND NOT AN OVERWRITE. CW Open runs three independent sessions on
  one date, each with serials from 1 and its own submission, so one contest,
  date and callsign must be able to name several logs. Nothing here deletes or
  replaces a file; it only finds a name that is not in use.

  The answer is a file NAME, like aFileName. aDir may end with a separator or
  not. aTaken is asked of the full path; the overload without it asks the disk.
  It raises if 9999 numbers are all taken: that is a broken test of
  existence, not a real directory, and looping for ever would hang. *)
function FirstFreeLogFileName(const aDir, aFileName: string;
                              aTaken: TLogFileTaken): string; overload;
function FirstFreeLogFileName(const aDir, aFileName: string): string; overload;

implementation

function SanitiseForFileName(const aText: string): string;
const
   (* Windows forbids all of these; '/' and NUL are the POSIX pair; the rest are
      removed because a shell or a script will otherwise need quoting that
      somebody will forget. *)
   BANNED = '<>:"/' + '\' + '|?*';
var
   i: integer;
   ch: char;
   sawSpace: boolean;
begin
   Result := '';
   sawSpace := False;
   for i := 1 to Length(aText) do
      begin
      ch := aText[i];

      if (ch < ' ') or (Pos(ch, BANNED) > 0) then
         begin
         (* A banned character becomes a separator rather than vanishing, so
            "AB/CD" reads as "AB CD" and not "ABCD". *)
         sawSpace := True;
         Continue;
         end;

      if ch = ' ' then
         begin
         sawSpace := True;
         Continue;
         end;

      if sawSpace and (Result <> '') then
         begin
         Result := Result + ' ';
         end;
      sawSpace := False;
      Result := Result + ch;
      end;
end;

function ContestLogFileName(const aContest: string; aWhen: TDateTime;
                            const aCall: string): string;
var
   contest, call: string;
begin
   contest := SanitiseForFileName(aContest);
   call := SanitiseForFileName(aCall);

   if contest = '' then
      begin
      contest := 'CONTEST';
      end;

   Result := contest + ' ' + FormatDateTime('yyyy-mm-dd', aWhen);

   if call <> '' then
      begin
      Result := Result + ' ' + call;
      end;

   Result := Result + '.db';
end;

const
   (* The highest number FirstFreeLogFileName tries. *)
   LAST_LOG_NUMBER = 9999;

function FirstFreeLogFileName(const aDir, aFileName: string;
                              aTaken: TLogFileTaken): string;
var
   dir, stem, ext: string;
   n: integer;
begin
   dir := aDir;
   if dir <> '' then
      begin
      dir := IncludeTrailingPathDelimiter(dir);
      end;

   Result := aFileName;
   if not aTaken(dir + Result) then
      begin
      Exit;
      end;

   ext  := ExtractFileExt(aFileName);
   stem := Copy(aFileName, 1, Length(aFileName) - Length(ext));
   for n := 2 to LAST_LOG_NUMBER do
      begin
      Result := stem + ' ' + IntToStr(n) + ext;
      if not aTaken(dir + Result) then
         begin
         Exit;
         end;
      end;

   raise Exception.CreateFmt('No free log name for "%s" in "%s"', [aFileName, aDir]);
end;

(* The disk's answer. FileExists itself cannot be passed: it is overloaded
  and has a default parameter. *)
function LogFileOnDisk(const aPath: string): boolean;
begin
   Result := FileExists(aPath);
end;

function FirstFreeLogFileName(const aDir, aFileName: string): string;
begin
   Result := FirstFreeLogFileName(aDir, aFileName, @LogFileOnDisk);
end;

end.

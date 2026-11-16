unit uServerLogHealth;
{$I tr4w.inc}

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

(*
  THE SERVER LOG'S HEALTH (issue 314, review finding H9, 2026-11-16).

  A LEAF, like uServerQsoIndex: it knows the record layout (VC) and files, not
  the server or the window, so what it decides is unit tested.

  TWO THINGS LIVE HERE.

  1. A LOG THAT ENDS IN A PART OF A RECORD. The server used to refuse to run and
     tell the operator to delete or rename the file -- the same answer whether
     the cause was a write cut short by a full disk (the tail is torn, every
     whole record before it is good) or a log written in an older record size
     (every record is misaligned). Size cannot tell them apart; THE HEADER CAN.
     The first record of the file is the header (TLogHeader is padded to one
     record), and it names the log version. A file whose header is the current
     one has only lost its tail: it is trimmed to a whole number of records
     AFTER a copy of the whole file has been written and its size checked. A file
     with any other header is never touched.

  2. WHAT AN OPERATOR AND THE STATIONS ARE TOLD when the log cannot be written.
     The texts are built here so their length (an intercom line is 79
     characters) is pinned by a test, and the reason from the OS is clipped, not
     the notice.
*)

interface

uses
   SysUtils,
   Classes,
   VC;

type
   TTornTailVerdict = (
      ttWhole,    (* a whole number of records: nothing to do *)
      ttTrim,     (* the current header and a partial tail: trim, after a backup *)
      ttRefuse);  (* anything else: do not touch the file *)

const
   (* The intercom line is a Str80: 79 characters and its length byte. *)
   SERVER_NOTICE_MAX = 79;

(* THE DECISION, with no file: the file's size, the record size, and whether its
  first record is the current header. aKeep is the size to trim to for ttTrim,
  and the size itself for ttWhole. A file shorter than one record holds no
  header to judge and is refused. *)
function JudgeServerLogSize(aSize, aRecordSize: Int64; aHeaderMatches: boolean;
                            out aKeep: Int64): TTornTailVerdict;

(* Is this the header the server writes (version, description and warning
  text)? The padding after them is not compared. *)
function ServerLogHeaderMatches(const aHeader: TLogHeader): boolean;

(* THE ONE STEP A CALLER TAKES: look at the file, judge it, and report what it is
  and what trimming would cost. aSize is the file's size, aKeep what it would
  keep. False when the file cannot be read (the caller refuses as before). *)
function PlanServerLogRepair(const aFileName: string; out aSize, aKeep: Int64;
                             out aVerdict: TTornTailVerdict): boolean;

(* COPY THE WHOLE FILE, CHECK THE COPY'S SIZE, THEN TRIM THE ORIGINAL to aKeep.
  The original is not touched unless the copy is complete -- a full disk fails
  the copy first, and the answer is False with aError set. The copy is named
  <file>.torn-<aStamp>.bak beside it and never replaced or removed. The file
  must be closed by the caller. *)
function BackupAndTrimServerLog(const aFileName, aStamp: string; aKeep: Int64;
                                out aBackupName, aError: string): boolean;

(* THE TEXTS. All at most SERVER_NOTICE_MAX characters except the window text. *)
function ClipReason(const aReason: string; aMax: integer): string;
(* Sent to every station when the log first fails to save. States what still
  works (the QSO is relayed) and what does not (it is not stored). *)
function ServerLogFailureNotice(const aReason: string): string;
(* Sent once when a write succeeds again. *)
function ServerLogRecoveredNotice: string;
(* The server window's status line and title suffix. Empty aFailures = ''. *)
function ServerLogProblemText(aFailures: integer; const aReason: string): string;

implementation

function JudgeServerLogSize(aSize, aRecordSize: Int64; aHeaderMatches: boolean;
                            out aKeep: Int64): TTornTailVerdict;
begin
   aKeep := aSize;
   if (aRecordSize <= 0) or ((aSize mod aRecordSize) = 0) then
      begin
      Result := ttWhole;
      Exit;
      end;
   if (aSize < aRecordSize) or (not aHeaderMatches) then
      begin
      Result := ttRefuse;
      Exit;
      end;
   aKeep := (aSize div aRecordSize) * aRecordSize;
   Result := ttTrim;
end;

function ServerLogHeaderMatches(const aHeader: TLogHeader): boolean;
begin
   Result := CompareMem(@aHeader, @LogHeader, SizeOfLHValid);
end;

function PlanServerLogRepair(const aFileName: string; out aSize, aKeep: Int64;
                             out aVerdict: TTornTailVerdict): boolean;
var
   f: TFileStream;
   header: TLogHeader;
   matches: boolean;
begin
   Result := False;
   aSize := 0;
   aKeep := 0;
   aVerdict := ttRefuse;
   try
      f := TFileStream.Create(aFileName, fmOpenRead or fmShareDenyNone);
      try
         aSize := f.Size;
         matches := False;
         if aSize >= SizeOf(TLogHeader) then
            begin
            f.ReadBuffer(header, SizeOf(TLogHeader));
            matches := ServerLogHeaderMatches(header);
            end;
      finally
         f.Free;
      end;
   except
      Exit;
   end;
   aVerdict := JudgeServerLogSize(aSize, SizeOf(ContestExchange), matches, aKeep);
   Result := True;
end;

function BackupAndTrimServerLog(const aFileName, aStamp: string; aKeep: Int64;
                                out aBackupName, aError: string): boolean;
var
   src, dst, orig: TFileStream;
   size: Int64;
begin
   Result := False;
   aError := '';
   aBackupName := aFileName + '.torn-' + aStamp + '.bak';
   try
      src := TFileStream.Create(aFileName, fmOpenRead or fmShareDenyNone);
      try
         size := src.Size;
         if (aKeep < 0) or (aKeep > size) then
            begin
            aError := 'nothing to trim';
            Exit;
            end;
         dst := TFileStream.Create(aBackupName, fmCreate);
         try
            dst.CopyFrom(src, 0);
            if dst.Size <> size then
               begin
               aError := 'the backup is ' + IntToStr(dst.Size) + ' bytes, not ' +
                         IntToStr(size);
               Exit;
               end;
         finally
            dst.Free;
         end;
      finally
         src.Free;
      end;
      orig := TFileStream.Create(aFileName, fmOpenReadWrite or fmShareDenyNone);
      try
         orig.Size := aKeep;
      finally
         orig.Free;
      end;
      Result := True;
   except
      on E: Exception do
         begin
         aError := E.Message;
         end;
   end;
end;

function ClipReason(const aReason: string; aMax: integer): string;
begin
   Result := Trim(aReason);
   if Length(Result) > aMax then
      begin
      Result := Copy(Result, 1, aMax - 3) + '...';
      end;
end;

function ServerLogFailureNotice(const aReason: string): string;
begin
   Result := 'SERVER LOG NOT SAVING (' + ClipReason(aReason, 28) +
             '): QSOs relayed, NOT stored';
end;

function ServerLogRecoveredNotice: string;
begin
   Result := 'Server log saving again. Reconnect a station to send it what it missed';
end;

function ServerLogProblemText(aFailures: integer; const aReason: string): string;
begin
   if aFailures <= 0 then
      begin
      Result := '';
      Exit;
      end;
   Result := 'LOG NOT SAVING - ' + IntToStr(aFailures) + ' failed: ' +
             ClipReason(aReason, 60);
end;

end.

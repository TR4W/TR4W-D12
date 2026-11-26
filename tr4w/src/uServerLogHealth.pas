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

  A LEAF: it knows neither the server nor the window, so what it decides is
  unit tested.

  WHAT AN OPERATOR AND THE STATIONS ARE TOLD when the log cannot be written.
  The texts are built here so their length (an intercom line is 79 characters)
  is pinned by a test, and the reason from the OS is clipped, not the notice.

  THE TORN-TAIL REPAIR OF SERVERLOG.TRW IS GONE (issue 386, batch B,
  2026-11-26): JudgeServerLogSize, ServerLogHeaderMatches, PlanServerLogRepair
  and BackupAndTrimServerLog had no caller since the server's log became a
  SQLite store (SERVERLOG.tr4wsrv, uServerWireStore), and they sized the file
  by SizeOf(ContestExchange).
*)

interface

uses
   SysUtils;

const
   (* The intercom line is a Str80: 79 characters and its length byte. *)
   SERVER_NOTICE_MAX = 79;

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

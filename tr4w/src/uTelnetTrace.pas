{
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
}

(* THE LAST FEW MINUTES OF DX CLUSTER TRAFFIC, IN MEMORY, WRITTEN NOWHERE.

  WHY IT IS A RING AND NOT A FILE. This replaced a session log that wrote
  every console line to DXCluster\dxcluster <date> <time>.txt as it arrived.
  NY4I, 2026-09-24: "I do like the pattern of maintaining data in circular
  memory buffers and dumping the data to disk only if required. Of course, a
  crash or reboot loses it but that is tolerable to remove any io we can." And
  the case for the file was weak on its own terms: "an issue that happens once
  is not a significant issue", TR4W already has a deliberate full-capture
  switch -- DX cluster / log all telnet traffic -- and there is no process for
  an operator to send us a trace beyond emailing it, which nobody does
  unprompted.

  SO THE COST IS PAID ONLY WHEN SOMETHING GOES WRONG. Nothing here touches the
  disk. uTelnet registers a dumper with uCrashLog, and the ring is written into
  the crash record -- or into the log at a point where uTelnet has ALREADY
  decided something is wrong.

  IT IS NOT THE CAPTURE CORPUS AND CANNOT BECOME IT. tr4w/test/ carries ~199,000
  real cluster lines, collected by long captures; a few hundred lines of
  ring cannot feed that. The debug switch above is still what produces a corpus
  capture, and it should stay the one full-capture path.

  A LEAF ON PURPOSE. No LCL, no logger, no uCrashLog -- SysUtils and nothing
  else. That is what makes the wrap behaviour testable without a window, which
  the console cap beside it is not: uTelnetForm pulls in MainUnit and cannot
  link into the test binary at all. Whoever holds the ring decides how to
  print it; this unit only decides what it holds.
*)

unit uTelnetTrace;

{$I tr4w.inc}

interface

const
   (* HOW MANY LINES, AND THE NUMBER IS A JUDGEMENT WITH REASONS.

     It has to hold enough context to be worth reading after a fault, and
     little enough that a human pastes it into an email without editing it.

     200 lines is about one to three minutes of a busy node, which is the
     window in which whatever went wrong actually went wrong -- a fault
     explained by traffic from half an hour ago is not a fault this diagnostic
     was going to explain either way. It is roughly 20 kB resident, which is
     nothing beside a contest log. And it stays readable: 200 lines is long but
     scannable, where 2,000 is an attachment nobody opens.

     RAISING IT IS CHEAP AND LOWERING IT IS NOT. Memory is the only cost of a
     bigger ring; a smaller one silently drops the context somebody needed. *)
   TELNET_TRACE_LINES = 200;

{ Record one line. Called from uTelnet's single console-add seam, so the ring
  sees exactly what the operator sees -- which is also why it cannot contain
  the cluster password: that is sent straight to the socket and the console is
  told '<password sent>' instead. }
procedure TelnetTraceAdd(const aLine: string);

{ How many lines are held, 0..TELNET_TRACE_LINES. }
function TelnetTraceCount: integer;

{ Line aIndex, OLDEST FIRST -- 0 is the oldest line still held and
  TelnetTraceCount - 1 the newest. Out of range gives '' rather than raising:
  the one caller reads this while the program is dying. }
function TelnetTraceLine(const aIndex: integer): string;

(* How many lines have been offered since the last reset, including the ones
  that have since been overwritten. It is the difference between the two counts
  that tells a reader the ring wrapped and how much it did not keep.

  A PLAIN INTEGER, not an Int64, and the bound is worth stating rather than
  defending against: two billion lines is about seven years of continuous
  cluster traffic inside one process. *)
function TelnetTraceTotal: integer;

{ Empty it. For tests, and for a deliberate 'start a fresh trace'. }
procedure TelnetTraceReset;

implementation

uses
   SysUtils;

var
   (* THE SLOTS ARE ALLOCATED ONCE, at unit load, and never grow. The whole
     point of this unit is that it costs nothing until it is read, and a
     buffer that reallocates is a buffer that can fail at the worst moment. *)
   GLines: array[0..TELNET_TRACE_LINES - 1] of string;

   { Where the NEXT line goes. Wraps at TELNET_TRACE_LINES. }
   GNext: integer = 0;

   { How many slots hold a line. Stops growing at TELNET_TRACE_LINES; after
     that GNext is also the index of the oldest. }
   GCount: integer = 0;

   { Everything ever offered, wrapped-away lines included. }
   GTotal: integer = 0;

procedure TelnetTraceAdd(const aLine: string);
begin
   (* NO GUARD AND NO TRY. This runs on the main thread on every cluster line
     -- see the note on uTelnet.AddStringToTelnetConsole -- and a string
     assignment into a fixed slot is the whole operation. Anything that could
     raise here would be something this unit introduced. *)
   GLines[GNext] := aLine;

   Inc(GNext);
   if GNext >= TELNET_TRACE_LINES then
      begin
      GNext := 0;
      end;

   if GCount < TELNET_TRACE_LINES then
      begin
      Inc(GCount);
      end;

   Inc(GTotal);
end;

function TelnetTraceCount: integer;
begin
   Result := GCount;
end;

function TelnetTraceLine(const aIndex: integer): string;
var
   slot: integer;
begin
   Result := '';
   if (aIndex < 0) or (aIndex >= GCount) then
      begin
      Exit;
      end;

   (* WHERE THE OLDEST LINE IS depends on whether it has wrapped. Before the
     first wrap the slots are simply 0..GCount-1 and GNext = GCount, so the
     oldest is slot 0 -- and (GNext - GCount) is 0, which is the same answer.
     After the wrap the oldest is the slot about to be overwritten, GNext, and
     GCount is the full size so (GNext - GCount) is GNext - size. Adding the
     size back before the mod covers both without a branch. *)
   slot := (GNext - GCount + aIndex + TELNET_TRACE_LINES) mod TELNET_TRACE_LINES;
   Result := GLines[slot];
end;

function TelnetTraceTotal: integer;
begin
   Result := GTotal;
end;

procedure TelnetTraceReset;
var
   i: integer;
begin
   for i := 0 to TELNET_TRACE_LINES - 1 do
      begin
      (* Emptied, not merely forgotten: a ring holding a contest's worth of
        stale strings is memory nobody asked for. *)
      GLines[i] := '';
      end;
   GNext  := 0;
   GCount := 0;
   GTotal := 0;
end;

end.

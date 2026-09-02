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

(* THE ACTIVE CONTEST OBJECT.

  One instance, for the contest currently loaded, created on demand and replaced
  when the contest changes. TR4W runs one contest at a time -- Contest is a
  global -- so a single instance is the honest model rather than a limitation.

  ActiveContest RETURNS nil FOR A CONTEST NOBODY HAS MOVED YET, and every caller
  is expected to handle that by doing what it did before. That is the strangler
  seam: the factory grows one contest at a time and the legacy path stays exactly
  as it is underneath, so each move is provable on its own against the golden
  corpus rather than as part of a big-bang.

  THE INSTANCE IS REBUILT WHEN THE CONTEST CHANGES, and that is checked on every
  call rather than being invalidated by whoever changes it. The contest is set
  from the .cfg parser, the log's stored configuration, the network, and the
  contest-selection dialog, and requiring each of those to remember to tell the
  factory is a rule that WILL be broken. Comparing a value is cheap; a stale
  contest object scoring an entire log is not. *)
unit uContestFactory;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

(* SWITCHES THE FACTORY OFF, so the legacy `case` runs instead.

  THIS EXISTS TO MAKE EACH CONTEST MOVE PROVABLE, and it is the only way to
  prove one. The golden corpus is BLIND to scoring -- measured: changing ARRL DX
  from 3 points to 7 leaves export-d12-corpus.sh at 24 passed, because /EXPORT
  reads the points STORED in the log and never recomputes them. And comparing a
  rescore against the D7 references is too blunt to be a gate: 7 of the 13 logs
  legitimately move, because our CTY.DAT is not D7's.

  So the question that CAN be answered exactly is: does the factory produce what
  the legacy arm produced, on the same program with the same data? Run the same
  rescore twice, once each way, and diff. That is test-contest-factory.sh, and it
  is what every contest moved into the factory has to survive. *)
var
   ContestFactoryEnabled: boolean = True;

(* The object for aContest, or nil when that contest has no class yet.
  Do not free it -- this unit owns it.

  THE CONTEST IS A PARAMETER, NOT THE GLOBAL. `Contest` lives in PostUnit, and a
  factory that reached for it would drag the Cabrillo/ADIF exporter into every
  unit that wants to score a QSO -- and could not be tested without booting the
  program's globals. Every caller already has the value in scope. *)
function ActiveContest(aContest: ContestType): TContestBase;

(* Drops the current instance.  Called at shutdown; safe at any time, because
  the next ActiveContest simply builds another. *)
procedure ReleaseActiveContest;

implementation

uses
   SysUtils, uContestRegistry;

var
   GActive: TContestBase = nil;
   GActiveFor: ContestType;
   GHaveActive: boolean = False;

function ActiveContest(aContest: ContestType): TContestBase;
var
   cls: TContestClass;
begin
   if not ContestFactoryEnabled then
      begin
      Result := nil;
      Exit;
      end;

   if GHaveActive and (GActiveFor = aContest) then
      begin
      Result := GActive;
      Exit;
      end;

   FreeAndNil(GActive);
   GActiveFor := aContest;
   GHaveActive := True;

   cls := ContestClassFor(aContest);
   if cls <> nil then
      begin
      GActive := cls.Create(aContest);
      end;

   Result := GActive;
end;

procedure ReleaseActiveContest;
begin
   FreeAndNil(GActive);
   GHaveActive := False;
end;

finalization
   ReleaseActiveContest;

end.

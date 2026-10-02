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

(* A CONTEST OBJECT FOR A TEST, MADE ONE WAY -- lifted at M8 (2026-10-02).

  uTestContestTotals and uTestContestSession each carried their own Make and
  NoStation, identical but for whether a station was set; M8's multiplier
  tests were about to be the third copy. They are here once now, and both
  suites use them.

  NOT LIFTED, because they are not the same helper: uTestContestParse's Make
  requires a registered class and sets InHostState, and uTestContestFactory's
  MakeContest answers nil for a classless contest -- each test depends on
  that difference. *)
unit uTestContestObjects;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC, uContestBase;

(* aContest's registered class -- or, for a classless contest, the plain base
   the registry answers with -- with the station given. Caller frees. *)
function Make(aContest: ContestType; const aStation: TStationContext): TContestBase; overload;

(* The same, with no station: every station field zero. *)
function Make(aContest: ContestType): TContestBase; overload;

(* A station with every field zero -- what an object holds before SetStation. *)
function NoStation: TStationContext;

implementation

uses
   uContestRegistry;

function Make(aContest: ContestType; const aStation: TStationContext): TContestBase;
var
   cls: TContestClass;
begin
   cls := ContestClassFor(aContest);
   if cls = nil then
      begin
      Result := TContestBase.Create(aContest);
      end
   else
      begin
      Result := cls.Create(aContest);
      end;
   Result.SetStation(aStation);
end;

function Make(aContest: ContestType): TContestBase;
begin
   Result := Make(aContest, NoStation);
end;

function NoStation: TStationContext;
begin
   FillChar(Result, SizeOf(Result), 0);
end;

end.

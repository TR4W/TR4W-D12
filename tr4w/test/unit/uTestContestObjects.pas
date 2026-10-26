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

(* THE SAME FOR A HANDLE -- a contest registered by its id has no
   ContestType member, so a party test helper that takes one cannot name it
   (the North Dakota QSO Party, 2026-10-26). The ContestType form is this
   one through ContestHandleOf. *)
function Make(aContest: TContestHandle; const aStation: TStationContext): TContestBase; overload;

(* The same, with no station: every station field zero. *)
function Make(aContest: ContestType): TContestBase; overload;

(* aContest's registered class with the station given, as ActiveContest
   hands it -- and nil for a classless contest (DUMMYCONTEST), which is what
   the engine's nil-safe Contest... functions are handed for it. Caller
   frees.

   LIFTED 2026-10-14 (M11 S9a): uTestDomesticMultiplier,
   uTestDXMultiplierKey, uTestZoneMultiplier and uTestExchangeRules each held
   an identical private copy, and uTestExchangeFields would have been the
   fifth.

   The handle form is for a registry walk, so a contest registered by its id
   is made as itself rather than as "no contest" (issue #96). *)
function MakeContestOrNil(aContest: ContestType; const aStation: TStationContext): TContestBase; overload;
function MakeContestOrNil(aContest: TContestHandle; const aStation: TStationContext): TContestBase; overload;

(* A station with every field zero -- what an object holds before SetStation. *)
function NoStation: TStationContext;

(* A DOMESTIC TABLE THAT KNOWS EVERY QTH -- the TStationContext.IsDomesticQTH
   service for a test whose QSOs are all with the host area, Q107
   (2026-10-16). A QSO party's out-of-area entrant credits only a QSO whose
   QTH the table knows (uContestBase.HostAreaRuleCredits); a test about
   POINTS states, with this, that every QSO it scores is with a host-area
   station, so the rule it is not about stays out of its way. A test ABOUT
   the rule hands a table that knows some QTHs and not others. *)
function StubEveryQTHIsAHostCounty(const aQTH: string): boolean;

(* aStation with StubEveryQTHIsAHostCounty as its table. *)
function WithHostAreaTable(const aStation: TStationContext): TStationContext;

(* THE SHIPPED dom DIRECTORY, from the test binary -- ParamStr(0), never the
   working directory, as the CTY.DAT tests do. Ends in a separator.

   LIFTED 2026-10-14: uTestContestFactory and uTestContestParse each held a
   copy, and the Delaware tests were the third. *)
function ShippedDomDir: string;

implementation

uses
   SysUtils, uContestRegistry;

function ShippedDomDir: string;
begin
   Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
             'target' + PathDelim + 'dom' + PathDelim;
end;

function Make(aContest: ContestType; const aStation: TStationContext): TContestBase;
begin
   Result := Make(ContestHandleOf(aContest), aStation);
end;

function Make(aContest: TContestHandle; const aStation: TStationContext): TContestBase;
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

function MakeContestOrNil(aContest: ContestType; const aStation: TStationContext): TContestBase;
begin
   Result := MakeContestOrNil(ContestHandleOf(aContest), aStation);
end;

function MakeContestOrNil(aContest: TContestHandle; const aStation: TStationContext): TContestBase;
var
   cls: TContestClass;
begin
   Result := nil;
   cls := ContestClassFor(aContest);
   if cls <> nil then
      begin
      Result := cls.Create(aContest);
      Result.SetStation(aStation);
      end;
end;

function NoStation: TStationContext;
begin
   (* Default, NEVER FillChar: TStationContext holds managed strings. FPC
     passes the caller's result temporary straight through, so a FillChar
     here zeroed whatever strings that temporary still held without
     releasing them -- a leak in every loop that reused it, and a reference
     count corrupted badly enough to segfault in a reproduction (M11 S0b,
     2026-10-14). Default(T) finalises and re-initialises properly. *)
   Result := Default(TStationContext);
end;

function StubEveryQTHIsAHostCounty(const aQTH: string): boolean;
begin
   Result := True;
end;

function WithHostAreaTable(const aStation: TStationContext): TStationContext;
begin
   Result := aStation;
   Result.IsDomesticQTH := @StubEveryQTHIsAHostCounty;
end;

end.

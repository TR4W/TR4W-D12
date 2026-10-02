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

(* EACH CONTEST DECLARES ITS OWN MULTIPLIER RULES -- milestone M8, 2026-10-02
  (docs/CONTEST_OWNERSHIP_DESIGN.md 7.7, stage 2: the contest declares, the
  shared sheet keeps the state).

  Two seams, each pinned against the arms it replaced:

    * CountsAsMultiplier -- logdupe's SetMultFlags named five contests: a
      'DX' multiplier QTH earns nothing in the New York and Indiana parties
      ('dx', lower case, in BC's), the PCC's own country earns no prefix,
      and the Jock White Field Day's own branch and branch 00 earn no zone.
      Each class answers it now; every other contest answers True for every
      kind (the base), and this suite checks every registered contest.
    * DomesticMultiplierFromCall -- LOGEDIT.GetMultArray's `case Contest of`
      for the need-multiplier hint: a Russian call's oblast (Russian DX, RF
      Championship CW and SSB), CTY.DAT's grid (Ural Cup), the remembered
      exchange of a Russian (RDA) or 'Y' (YO DX) call. The engine's answers
      are handed in as lookups, stubbed here, so what is pinned is the
      contest's own rule.

  The SHEET's half -- that SetMultFlags asks, and that a false answer leaves
  the flag false -- is the contest matrix's to pin: its scoring line records
  every multiplier flag for every contest, frozen before this moved. *)
unit uTestContestMultipliers;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestMultipliersTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_DXQTHEarnsNoMultiplierInThreeParties;
      procedure Test_PCCOwnCountryEarnsNoPrefix;
      procedure Test_JockWhiteOwnBranchEarnsNoZone;
      procedure Test_EveryOtherContestCountsEveryMultiplier;
      procedure Test_RussianCallsImplyTheirOblast;
      procedure Test_LookupContestsAskTheEngine;
      procedure Test_EveryOtherContestImpliesNoMultiplierFromACall;
   end;

implementation

uses
   SysUtils, VC, uContestBase, uContestRegistry, uCallSignRoutines,
   uTestContestObjects;

const
   KINDS: array[0..3] of RemainingMultiplierType = (rmDomestic, rmDX, rmZone, rmPrefix);

(* A QSO whose multiplier fields are set, and nothing else. *)
function Qso(const aDomMultQTH, aCountryID: string; aZone: integer): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.Callsign := 'W1AW';
   Result.DomMultQTH := ShortString(aDomMultQTH);
   Result.QTH.CountryID := ShortString(aCountryID);
   Result.Zone := aZone;
end;

(* True when aContest counts aQso for every one of the four kinds. *)
function CountsAll(aContest: TContestBase; const aQso: ContestExchange): boolean;
var
   i: integer;
begin
   Result := True;
   for i := Low(KINDS) to High(KINDS) do
      begin
      if not aContest.CountsAsMultiplier(aQso, KINDS[i]) then
         begin
         Result := False;
         end;
      end;
end;

(* True when aContest counts aQso for NONE of the four kinds. *)
function CountsNone(aContest: TContestBase; const aQso: ContestExchange): boolean;
var
   i: integer;
begin
   Result := True;
   for i := Low(KINDS) to High(KINDS) do
      begin
      if aContest.CountsAsMultiplier(aQso, KINDS[i]) then
         begin
         Result := False;
         end;
      end;
end;

procedure TContestMultipliersTests.Test_DXQTHEarnsNoMultiplierInThreeParties;
var
   c: TContestBase;
begin
   BeginTest('Test_DXQTHEarnsNoMultiplierInThreeParties');

   c := Make(NYQP);
   try
      CheckTrue(CountsNone(c, Qso('DX', 'DL', 14)), 'NYQP: a DX QTH earns no multiplier of any kind');
      CheckTrue(CountsAll(c, Qso('ALB', 'K', 5)), 'NYQP: a county does');
   finally
      c.Free;
      end;

   c := Make(INQSOPARTY);
   try
      CheckTrue(CountsNone(c, Qso('DX', 'DL', 14)), 'Indiana: a DX QTH earns no multiplier of any kind');
      CheckTrue(CountsAll(c, Qso('MAR', 'K', 4)), 'Indiana: a county does');
   finally
      c.Free;
      end;

   (* TRANSCRIBED, NOT CORRECTED: BC's arm tests the lower-case 'dx' (Q49). *)
   c := Make(BCQP);
   try
      CheckTrue(CountsNone(c, Qso('dx', 'DL', 14)), 'BC: the arm''s lower-case ''dx'' earns nothing');
      CheckTrue(CountsAll(c, Qso('DX', 'DL', 14)), 'BC: an upper-case ''DX'' is the sheet''s, as before');
   finally
      c.Free;
      end;
end;

procedure TContestMultipliersTests.Test_PCCOwnCountryEarnsNoPrefix;
var
   c: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_PCCOwnCountryEarnsNoPrefix');

   station := NoStation;
   station.MyCountry := 'PY';
   c := Make(PCC, station);
   try
      CheckFalse(c.CountsAsMultiplier(Qso('', 'PY', 11), rmPrefix), 'PCC: our own country''s prefix is no multiplier');
      CheckTrue(c.CountsAsMultiplier(Qso('', 'PY', 11), rmDX), 'PCC: the rule names the prefix kind only');
      CheckTrue(c.CountsAsMultiplier(Qso('', 'DL', 14), rmPrefix), 'PCC: another country''s prefix is the sheet''s');
   finally
      c.Free;
      end;
end;

procedure TContestMultipliersTests.Test_JockWhiteOwnBranchEarnsNoZone;
var
   c: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_JockWhiteOwnBranchEarnsNoZone');

   station := NoStation;
   station.MyZone := 7;
   station.MyZoneValid := True;
   c := Make(NZFIELDDAY, station);
   try
      CheckFalse(c.CountsAsMultiplier(Qso('', 'ZL', 7), rmZone), 'JW FD: our own branch is no zone multiplier');
      CheckFalse(c.CountsAsMultiplier(Qso('', 'ZL', 0), rmZone), 'JW FD: nor is branch 00');
      CheckTrue(c.CountsAsMultiplier(Qso('', 'ZL', 12), rmZone), 'JW FD: another branch is the sheet''s');
      CheckTrue(c.CountsAsMultiplier(Qso('', 'ZL', 7), rmDomestic), 'JW FD: the rule names the zone kind only');
   finally
      c.Free;
      end;
end;

procedure TContestMultipliersTests.Test_EveryOtherContestCountsEveryMultiplier;
const
   (* The contests whose CountsAsMultiplier says no to something. A contest
      that gains a multiplier rule joins this list in the same commit. *)
   STATED: array[0..4] of ContestType = (BCQP, NYQP, INQSOPARTY, PCC, NZFIELDDAY);
var
   ct: ContestType;
   i: integer;
   isStated: boolean;
   c: TContestBase;
begin
   BeginTest('Test_EveryOtherContestCountsEveryMultiplier');

   for ct := Low(ContestType) to High(ContestType) do
      begin
      isStated := False;
      for i := Low(STATED) to High(STATED) do
         begin
         if STATED[i] = ct then
            begin
            isStated := True;
            end;
         end;
      if isStated then
         begin
         Continue;
         end;

      c := Make(ct);
      try
         (* The shapes the five rules turn on: a DX QTH, either case, our own
            country (the zero station's is ''), our own zone (0), zone 0. *)
         CheckTrue(CountsAll(c, Qso('DX', '', 0)) and CountsAll(c, Qso('dx', 'PY', 0)),
                   string(ContestTypeSA[ct]) + ' counts every multiplier the sheet finds');
      finally
         c.Free;
         end;
      end;
end;

(* STUBS FOR THE ENGINE'S TWO ANSWERS -- each names its own call, so the
   test can see which was asked and with what. *)
function StubExchange(const aCall: string): string;
begin
   Result := 'EX:' + aCall;
end;

function StubGrid(const aCall: string): string;
begin
   Result := 'GR:' + aCall;
end;

function Lookups: TMultiplierHintLookups;
begin
   Result.InitialExchangeOf := @StubExchange;
   Result.GridOfCall := @StubGrid;
end;

procedure TContestMultipliersTests.Test_RussianCallsImplyTheirOblast;
const
   CONTESTS: array[0..2] of ContestType = (RUSSIANDX, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB);
var
   i: integer;
   c: TContestBase;
begin
   BeginTest('Test_RussianCallsImplyTheirOblast');

   for i := Low(CONTESTS) to High(CONTESTS) do
      begin
      c := Make(CONTESTS[i]);
      try
         CheckEquals(GetRussiaOblastID('UA3ABC'), c.DomesticMultiplierFromCall('UA3ABC', Lookups),
                     string(ContestTypeSA[CONTESTS[i]]) + ': a UA call implies its oblast');
         CheckEquals(GetRussiaOblastID('RA9XYZ'), c.DomesticMultiplierFromCall('RA9XYZ', Lookups),
                     string(ContestTypeSA[CONTESTS[i]]) + ': so does an R call -- RussianID of the CALL');
         CheckEquals('', c.DomesticMultiplierFromCall('DL1ABC', Lookups),
                     string(ContestTypeSA[CONTESTS[i]]) + ': another call implies nothing');
      finally
         c.Free;
         end;
      end;
   CheckTrue(GetRussiaOblastID('UA3ABC') <> '', 'the control: UA3ABC has an oblast to find');
end;

procedure TContestMultipliersTests.Test_LookupContestsAskTheEngine;
var
   c: TContestBase;
   none: TMultiplierHintLookups;
begin
   BeginTest('Test_LookupContestsAskTheEngine');
   FillChar(none, SizeOf(none), 0);

   c := Make(CUPURAL);
   try
      CheckEquals('GR:UA9CDC', c.DomesticMultiplierFromCall('UA9CDC', Lookups), 'Ural Cup: the call''s grid');
      CheckEquals('', c.DomesticMultiplierFromCall('UA9CDC', none), 'Ural Cup: no service, no answer');
   finally
      c.Free;
      end;

   c := Make(RDA);
   try
      CheckEquals('EX:UA3ABC', c.DomesticMultiplierFromCall('UA3ABC', Lookups), 'RDA: a Russian call''s remembered exchange');
      CheckEquals('', c.DomesticMultiplierFromCall('DL1ABC', Lookups), 'RDA: not for another call');
   finally
      c.Free;
      end;

   c := Make(YODX);
   try
      CheckEquals('EX:YO3ABC', c.DomesticMultiplierFromCall('YO3ABC', Lookups), 'YO DX: a Y call''s remembered exchange');
      CheckEquals('', c.DomesticMultiplierFromCall('DL1ABC', Lookups), 'YO DX: not for another call');
      CheckEquals('', c.DomesticMultiplierFromCall('', Lookups), 'YO DX: nor for no call');
   finally
      c.Free;
      end;
end;

procedure TContestMultipliersTests.Test_EveryOtherContestImpliesNoMultiplierFromACall;
const
   STATED: array[0..5] of ContestType = (RUSSIANDX, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB,
                                         CUPURAL, RDA, YODX);
var
   ct: ContestType;
   i: integer;
   isStated: boolean;
   c: TContestBase;
begin
   BeginTest('Test_EveryOtherContestImpliesNoMultiplierFromACall');

   for ct := Low(ContestType) to High(ContestType) do
      begin
      isStated := False;
      for i := Low(STATED) to High(STATED) do
         begin
         if STATED[i] = ct then
            begin
            isStated := True;
            end;
         end;
      if isStated then
         begin
         Continue;
         end;

      c := Make(ct);
      try
         CheckEquals('', c.DomesticMultiplierFromCall('UA3ABC', Lookups) +
                         c.DomesticMultiplierFromCall('YO3ABC', Lookups),
                     string(ContestTypeSA[ct]) + ' implies no multiplier from a call');
      finally
         c.Free;
         end;
      end;
end;

procedure TContestMultipliersTests.RunAllTests;
begin
   Test_DXQTHEarnsNoMultiplierInThreeParties;
   Test_PCCOwnCountryEarnsNoPrefix;
   Test_JockWhiteOwnBranchEarnsNoZone;
   Test_EveryOtherContestCountsEveryMultiplier;
   Test_RussianCallsImplyTheirOblast;
   Test_LookupContestsAskTheEngine;
   Test_EveryOtherContestImpliesNoMultiplierFromACall;
end;

end.

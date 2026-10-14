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

(* THE DELAWARE QSO PARTY -- every rule the class states, pinned (2026-10-14).

  A NEW CONTEST HAS NO FROZEN RECORD: the contest matrix lists it as
  unfrozen until somebody freezes it, so until then these assertions are
  the only oracle that it scores what the sponsor says. Each is written from
  the rule (design 7.14, and uContestDelawareQP's header), never read back
  out of the class:

    * a state party on the family base, the enum APPENDED;
    * points by the ENTRANT's location, each mode, both sides;
    * the bands: WARC scores nothing, 160 m and 6 m up do;
    * multipliers per band, dupes per band per mode, both county files;
    * a county line is two QSOs, three is refused;
    * an out-of-state station working anyone but a DE county is refused;
    * the score: points x multipliers x HIGH 1 / LOW 2 / QRP 3, plus 50;
    * Cabrillo: the CONTEST name, CW / PH / RY, a LOCATION required;
    * ADIF: the id resolves back to this contest. *)
unit uTestContestDelawareQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestDelawareQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_DelawareIsAnAppendedStateParty;
      procedure Test_DelawarePointsFollowTheEntrant;
      procedure Test_DelawareBandsSkipWARC;
      procedure Test_DelawareMultsPerBandDupesPerBandAndMode;
      procedure Test_DelawareCountyFiles;
      procedure Test_DelawareCountyLineIsTwoQSOs;
      procedure Test_DelawareOutOfStateWorksOnlyDelaware;
      procedure Test_DelawareScoreIsPowerTimesFormulaPlusFifty;
      procedure Test_DelawareCabrillo;
      procedure Test_DelawareADIFIdRoundTrips;
      procedure Test_DelawareCQExchangeSendsTheSentState;
   end;

implementation

uses
   (* cpHIGH / cpLOW / cpQRP. Before VC, so VC's names win where they
      overlap. *)
   uSettingsModel,
   Classes, SysUtils, VC, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestDelawareQP, uDomFileKeys,
   uAppStrings, uTR4WStrings,
   uTestContestObjects;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

function StationAt(aInState: boolean): TStationContext;
begin
   Result := NoStation;
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'KDE';
      end
   else
      begin
      Result.MyState := 'PA';
      end;
end;

function PointsFor(aInState: boolean; aBand: BandType; aMode: ModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(DELAWAREQSOPARTY, StationAt(aInState));
   try
      FillChar(qso, SizeOf(qso), 0);
      qso.Band := aBand;
      qso.Mode := aMode;
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* THE STUBBED PARSE ENGINE: the shape sets the QTH it is told to, and the
   domestic table knows the keys in GDomesticKeys -- for an out-of-state
   station the three counties, as delaware_cty.dom loads them. *)
var
   GShapeSetsQTH: string;
   GDomesticKeys: string;

function StubParseShape(aShape: ExchangeType; const aText: string;
                        var aExch: ContestExchange): boolean;
begin
   aExch.QTHString := ShortString(GShapeSetsQTH);
   Result := True;
end;

function StubIsDomesticQTH(const aQTH: string): boolean;
begin
   Result := Pos(',' + UpperCase(aQTH) + ',', ',' + GDomesticKeys + ',') > 0;
end;

function Session: TReceivedExchangeSession;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.Exchange := RSTDomesticOrDXQTHExchange;
   Result.ParseShape := @StubParseShape;
   Result.IsDomesticQTH := @StubIsDomesticQTH;
   Result.CallWindowHasCall := True;
end;

function ParseAs(aInState: boolean; const aQTH: string; out aMessage: string): boolean;
var
   contestObject: TContestBase;
   exch: ContestExchange;
begin
   GShapeSetsQTH := aQTH;
   contestObject := Make(DELAWAREQSOPARTY, StationAt(aInState));
   try
      FillChar(exch, SizeOf(exch), 0);
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, Session, exch, aMessage);
   finally
      contestObject.Free;
   end;
end;

function Totals(aPoints: longint; aMults: longint): TScoreTotals;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.QSOPoints := aPoints;
   Result.ScoredBand := AllBands;
   Result.SessionCountsMultipliers := True;
   Result.SessionExchange := RSTDomesticOrDXQTHExchange;
   Result.Mults[AllBands, Both, rmDomestic] := aMults;
end;

function FinalAt(aPower: tCategoryPower; const aTotals: TScoreTotals): longint;
var
   station: TStationContext;
   contestObject: TContestBase;
   view: TLoggedQSOList;
begin
   station := StationAt(True);
   station.MyPower := aPower;
   view := TLoggedQSOList.Create;
   contestObject := Make(DELAWAREQSOPARTY, station);
   try
      Result := contestObject.FinalScore(aTotals, view);
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE TESTS
   --------------------------------------------------------------------------- *)

(* APPENDED, NOT INSERTED: the ordinal is persisted in the binary log's
   ceContest byte, the multi-op packet and HamScore's <contestnr>. A member
   inserted before it would renumber every contest after it. *)
procedure TContestDelawareQPTests.Test_DelawareIsAnAppendedStateParty;
var
   contestObject: TContestBase;
begin
   BeginTest('Test_DelawareIsAnAppendedStateParty');
   CheckEquals(Ord(IDAHOQSOPARTY) + 1, Ord(DELAWAREQSOPARTY), 'appended right after Idaho');
   CheckEquals('DELAWARE QSO PARTY', string(ContestTypeSA[DELAWAREQSOPARTY]), 'the config spelling');
   CheckEquals('DE', USQSOPartyStateName(DELAWAREQSOPARTY), 'its QSOParties entry names DE');

   CheckTrue(ContestClassFor(DELAWAREQSOPARTY) = TContestDelawareQP, 'registered');
   contestObject := Make(DELAWAREQSOPARTY);
   try
      CheckTrue(contestObject.ClassParent = TContestStateQSOPartyBase,
                'on the state-party family base, directly');
      CheckTrue(contestObject.IsUSQSOParty, 'a US QSO party');
      CheckEquals('DE', contestObject.HostState, 'its host state');
      CheckEquals('Delaware QSO Party', contestObject.DisplayName, 'its display name');
      CheckEquals('delaware_cty', contestObject.DomesticFileName, 'the county file');
      CheckEquals('delaware', contestObject.InStateDomesticFileName, 'the in-state file');
      CheckTrue(contestObject.MarksDupes, 'marks dupes');
      CheckTrue(contestObject.IsActive, 'active');
   finally
      contestObject.Free;
   end;
end;

(* "inside DE: phone 1, digital 2, CW 2; outside DE: phone 10, digital 20,
   CW 20" -- by the ENTRANT's location. FM is phone; Both and NoMode are
   not modes a contact is made in. *)
procedure TContestDelawareQPTests.Test_DelawarePointsFollowTheEntrant;
begin
   BeginTest('Test_DelawarePointsFollowTheEntrant');
   CheckEquals(1, PointsFor(True, Band20, Phone), 'in DE, phone');
   CheckEquals(1, PointsFor(True, Band2, FM), 'in DE, FM is phone');
   CheckEquals(2, PointsFor(True, Band20, Digital), 'in DE, digital');
   CheckEquals(2, PointsFor(True, Band20, CW), 'in DE, CW');
   CheckEquals(0, PointsFor(True, Band20, Both), 'in DE, no mode a contact is made in');

   CheckEquals(10, PointsFor(False, Band20, Phone), 'outside DE, phone');
   CheckEquals(10, PointsFor(False, Band2, FM), 'outside DE, FM is phone');
   CheckEquals(20, PointsFor(False, Band20, Digital), 'outside DE, digital');
   CheckEquals(20, PointsFor(False, Band20, CW), 'outside DE, CW');
   CheckEquals(0, PointsFor(False, Band20, NoMode), 'outside DE, no mode');
end;

(* "All HF bands EXCEPT WARC, plus 6 m and up." An off-band QSO is logged,
   scores 0 and earns no multiplier (design 7.4) -- ScoreQSO asks UsesBand
   first, so even an outside entrant's CW scores nothing there. 60 m has no
   BandType, so it cannot be logged at all. *)
procedure TContestDelawareQPTests.Test_DelawareBandsSkipWARC;
var
   contestObject: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_DelawareBandsSkipWARC');
   contestObject := Make(DELAWAREQSOPARTY);
   try
      for b := Low(BandType) to High(BandType) do
         begin
         expected := not (b in [Band30, Band17, Band12, AllBands, NoBand]);
         CheckEquals(Ord(expected), Ord(contestObject.UsesBand(b)),
                     'band ' + IntToStr(Ord(b)) + ' credited');
         CheckEquals(Ord(expected), Ord(ContestCreditsBand(contestObject, b)),
                     'band ' + IntToStr(Ord(b)) + ' credited through the one seam');
         end;
   finally
      contestObject.Free;
   end;

   CheckEquals(0, PointsFor(False, Band30, CW), '30 m scores nothing');
   CheckEquals(0, PointsFor(False, Band17, Phone), '17 m scores nothing');
   CheckEquals(0, PointsFor(True, Band12, Digital), '12 m scores nothing');
   CheckEquals(20, PointsFor(False, Band160, CW), '160 m scores');
   CheckEquals(20, PointsFor(False, Band6, CW), '6 m scores');
   CheckEquals(10, PointsFor(False, Band432, Phone), '70 cm scores');
end;

(* "Multipliers are counted once PER BAND" and "Dupes: once per band per
   mode" -- the set-up traits the head applies (ContestsBooleanArray, read
   through the class). A DE entrant counts DXCC entities; an outside entrant
   counts only the counties, so its session states no DX multiplier. *)
procedure TContestDelawareQPTests.Test_DelawareMultsPerBandDupesPerBandAndMode;
var
   contestObject: TContestBase;
   session: TSessionDefaults;
   v: TSessionValue;
begin
   BeginTest('Test_DelawareMultsPerBandDupesPerBandAndMode');
   contestObject := Make(DELAWAREQSOPARTY);
   try
      CheckTrue(contestObject.MultByBand, 'a multiplier counts once per band');
      CheckFalse(contestObject.MultByMode, 'and not again per mode');
      CheckTrue(contestObject.QSOByBand, 'a station may be worked once per band');
      CheckTrue(contestObject.QSOByMode, 'and once per mode');
      CheckTrue(contestObject.VHFBandsEnabled, '6 m and up are on');
      CheckEquals(Ord(DomesticFile), Ord(contestObject.DomesticMultiplierType),
                  'states, provinces or counties from the domestic file');
      CheckEquals(Ord(ARRLDXCCWithNoUSACanadaKH6OrKL7), Ord(contestObject.DXMultiplierType),
                  'DXCC entities beyond the states and provinces');
      CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(contestObject.ExchangeKind),
                  'RST and a county, state, province or DX');
   finally
      contestObject.Free;
   end;

   session := TSessionDefaults.Create;
   try
      ContestIdentity(DELAWAREQSOPARTY).DescribeSession(StationAt(True), session);
      for v := Low(TSessionValue) to High(TSessionValue) do
         begin
         CheckFalse(session.IsStated(v), 'in DE, set-up states nothing: ' + IntToStr(Ord(v)));
         end;
   finally
      session.Free;
   end;

   session := TSessionDefaults.Create;
   try
      ContestIdentity(DELAWAREQSOPARTY).DescribeSession(StationAt(False), session);
      CheckTrue(session.IsStated(svDXMult), 'outside DE, set-up states the DX multiplier');
      CheckEquals(Ord(NoDXMults), Ord(session.DXMult), 'and it is none');
      CheckFalse(session.IsStated(svExchange), 'the exchange serves both sides');
   finally
      session.Free;
   end;
end;

(* A NON-DE ENTRANT COUNTS NDE, KDE AND SDE -- the county file, and nothing
   else (no INCLUDE: an outside station loading the states would count
   them). A DE ENTRANT counts the states and provinces: the in-state file
   includes the counties (each mapped to De), S50 and P13, and holds no
   other line the reader would take as an entry. *)
procedure TContestDelawareQPTests.Test_DelawareCountyFiles;
var
   lines: TStringList;
   keys: string;
   i: integer;
   key: string;
   includes: string;
begin
   BeginTest('Test_DelawareCountyFiles');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'delaware_cty.dom'));
      keys := '';
      for i := 0 to lines.Count - 1 do
         begin
         key := DomFileLineKey(string(lines[i]));
         if key <> '' then
            begin
            keys := keys + key + ' ';
            end;
         CheckTrue(Pos('INCLUDE', UpperCase(string(lines[i]))) = 0,
                   'the county file includes nothing, line ' + IntToStr(i + 1));
         CheckTrue((Trim(string(lines[i])) = '') or (Pos('> De =', string(lines[i])) > 0),
                   'each county is mapped to De for an in-state station, line ' + IntToStr(i + 1));
         end;
      CheckEquals('NDE KDE SDE ', keys, 'exactly the three counties');

      lines.LoadFromFile(AnsiString(ShippedDomDir + 'delaware.dom'));
      includes := '';
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('INCLUDE FILE ', UpperCase(string(lines[i]))) = 1 then
            begin
            includes := includes + UpperCase(Trim(Copy(string(lines[i]), 14, MaxInt))) + ' ';
            end
         else
            begin
            CheckEquals(0, Pos('=', string(lines[i])),
                        'delaware.dom line ' + IntToStr(i + 1) + ' would be read as an entry');
            end;
         end;
      CheckEquals('DELAWARE_CTY.DOM S50.DOM P13.DOM ', includes,
                  'the counties first, then the states and the provinces');
   finally
      lines.Free;
   end;
end;

(* "A county-line station counts as two separate QSOs." Delaware has three
   counties and a line joins two. *)
procedure TContestDelawareQPTests.Test_DelawareCountyLineIsTwoQSOs;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_DelawareCountyLineIsTwoQSOs');
   contestObject := Make(DELAWAREQSOPARTY);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(2, party.CountyLineCountiesMax, 'two counties on a line');
      CheckTrue(party.CountyLineAllowed, 'a county line is allowed');
      CheckTrue(party.ValidateQTHCount(1, msg), 'one county');
      CheckTrue(party.ValidateQTHCount(2, msg), 'a line of two');
      CheckFalse(party.ValidateQTHCount(3, msg), 'three is refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), msg, 'with the county-count message');
   finally
      contestObject.Free;
   end;
end;

(* "Non-DE stations work DE stations only" -- refused with an error, design
   7.10, by the family base. DE stations work everyone. *)
procedure TContestDelawareQPTests.Test_DelawareOutOfStateWorksOnlyDelaware;
var
   msg: string;
begin
   BeginTest('Test_DelawareOutOfStateWorksOnlyDelaware');
   GDomesticKeys := 'NDE,KDE,SDE';
   CheckTrue(ParseAs(False, 'KDE', msg), 'outside DE, a Kent County station');
   CheckEquals('', msg, 'nothing to say');
   CheckFalse(ParseAs(False, 'PA', msg), 'outside DE, a Pennsylvania station: refused');
   CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['DE']), msg, 'with the reason');
   CheckFalse(ParseAs(False, 'DX', msg), 'outside DE, a DX station: refused');

   GDomesticKeys := 'NDE,KDE,SDE,PA,ON';
   CheckTrue(ParseAs(True, 'PA', msg), 'in DE, a Pennsylvania station');
   CheckTrue(ParseAs(True, 'DX', msg), 'in DE, a DX station');
   CheckTrue(ParseAs(True, 'SDE', msg), 'in DE, another DE county');
end;

(* "QSO points x multipliers x POWER MULTIPLIER, + 50": HIGH x1, LOW x2,
   QRP x3, and the electronic bonus always (decided, design 8.2q). *)
procedure TContestDelawareQPTests.Test_DelawareScoreIsPowerTimesFormulaPlusFifty;
var
   t: TScoreTotals;
begin
   BeginTest('Test_DelawareScoreIsPowerTimesFormulaPlusFifty');
   CheckEquals(1, DelawarePowerMultiplier(cpHIGH), 'over 100 W: x1');
   CheckEquals(2, DelawarePowerMultiplier(cpLOW), '100 W or less: x2');
   CheckEquals(3, DelawarePowerMultiplier(cpQRP), '5 W or less: x3');
   CheckEquals(50, DelawareElectronicLogBonus, 'the electronic-log bonus');

   t := Totals(100, 5);
   t.Mults[AllBands, Both, rmDX] := 2;
   CheckEquals(100 * 7 + 50, FinalAt(cpHIGH, t), 'HIGH: points x every multiplier, + 50');
   CheckEquals(100 * 7 * 2 + 50, FinalAt(cpLOW, t), 'LOW doubles before the bonus');
   CheckEquals(100 * 7 * 3 + 50, FinalAt(cpQRP, t), 'QRP triples before the bonus');

   (* A SINGLE-BAND ENTRY counts its band's multipliers, as the base does. *)
   t.ScoredBand := Band40;
   t.Mults[Band40, Both, rmDomestic] := 3;
   CheckEquals(100 * 3 * 2 + 50, FinalAt(cpLOW, t), 'a single-band entry');

   CheckEquals(50, FinalAt(cpQRP, Totals(0, 0)), 'an empty log is the bonus alone');
end;

(* CONTEST: DE-QSO-PARTY; "Modes CW / PH / RY (all digital = RY)"; the header
   "MUST carry ARRL-SECTION: or LOCATION:". *)
procedure TContestDelawareQPTests.Test_DelawareCabrillo;
var
   contestObject: TContestBase;
begin
   BeginTest('Test_DelawareCabrillo');
   contestObject := Make(DELAWAREQSOPARTY);
   try
      CheckEquals('DE-QSO-PARTY', contestObject.CabrilloName, 'the Cabrillo name');
      CheckEquals('DE-QSO-PARTY', contestObject.CabrilloContestName('2027 DEQP NY4I', 'X'),
                  'the CONTEST: line, whatever the title');
      CheckEquals('CW', contestObject.CabrilloModeString(CW, eCW), 'CW');
      CheckEquals('PH', contestObject.CabrilloModeString(Phone, eUSB), 'phone');
      CheckEquals('PH', contestObject.CabrilloModeString(FM, eFM), 'FM is phone');
      CheckEquals('RY', contestObject.CabrilloModeString(Digital, eRTTY), 'RTTY');
      CheckEquals('RY', contestObject.CabrilloModeString(Digital, eFT8), 'FT8 is RY too');
      CheckEquals('RY', contestObject.CabrilloModeString(Digital, eNoMode), 'digital is RY');
      CheckTrue(contestObject.RequiresCabrilloLocation, 'no file without a LOCATION');
      CheckEquals(CabrilloQSOLineFormatDefault, contestObject.CabrilloQSOLineFormat,
                  'the standard QSO line');
   finally
      contestObject.Free;
   end;
end;

(* ADIF 3.1.7's DE-QSO-PARTY: what export writes is what import matches. *)
procedure TContestDelawareQPTests.Test_DelawareADIFIdRoundTrips;
var
   c: ContestType;
begin
   BeginTest('Test_DelawareADIFIdRoundTrips');
   CheckEquals('DE-QSO-PARTY', ContestIdentity(DELAWAREQSOPARTY).ADIFContestId, 'the ADIF id');
   CheckTrue(ContestIdentity(DELAWAREQSOPARTY).WritesADIFContestId, 'export writes it');
   CheckTrue(FindContestByADIFContestId('DE-QSO-PARTY', c), 'import resolves it');
   CheckEquals(Ord(DELAWAREQSOPARTY), Ord(c), 'to the Delaware QSO Party');
   CheckTrue(FindContestByADIFContestId('IN7QPNE-QSO-PARTY', c), 'the combined party keeps its own id');
   CheckEquals(Ord(IN7QPNE), Ord(c), 'IN7QPNE is not Delaware');
end;

(* The CQ exchange default: 5NN and the state the session SENDS -- a DE
   station's county, anyone else's state. *)
procedure TContestDelawareQPTests.Test_DelawareCQExchangeSendsTheSentState;
begin
   BeginTest('Test_DelawareCQExchangeSendsTheSentState');
   CheckEquals(' 5NN KDE', ContestIdentity(DELAWAREQSOPARTY).CQExchangeDefault(StationAt(True)),
               'in DE, the county');
   CheckEquals(' 5NN PA', ContestIdentity(DELAWAREQSOPARTY).CQExchangeDefault(StationAt(False)),
               'outside DE, the state');
   CheckEquals('', ContestIdentity(DELAWAREQSOPARTY).RepeatSPExchangeDefault(StationAt(True)),
               'no repeat S&P default');
end;

procedure TContestDelawareQPTests.RunAllTests;
begin
   Test_DelawareIsAnAppendedStateParty;
   Test_DelawarePointsFollowTheEntrant;
   Test_DelawareBandsSkipWARC;
   Test_DelawareMultsPerBandDupesPerBandAndMode;
   Test_DelawareCountyFiles;
   Test_DelawareCountyLineIsTwoQSOs;
   Test_DelawareOutOfStateWorksOnlyDelaware;
   Test_DelawareScoreIsPowerTimesFormulaPlusFifty;
   Test_DelawareCabrillo;
   Test_DelawareADIFIdRoundTrips;
   Test_DelawareCQExchangeSendsTheSentState;
end;

end.

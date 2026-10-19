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

(* THE NEBRASKA QSO PARTY -- every rule the class states, pinned
  (2026-10-16, design Q105).

  A NEW CONTEST HAS NO FROZEN RECORD until somebody freezes it, so these
  assertions are the only oracle that it scores what the sponsor says. Each
  is written from the rule (uContestNebraskaQP's header), never read back
  out of the class:

    * a state party on the family base, the enum APPENDED, its names
      NE-QSO-PARTY everywhere and never New England's NEQP;
    * points: digital 1, phone 2, CW 3; FT8 and FT4 are off-mode;
    * the bands: 160-10 m without WARC, and 6 m up;
    * multipliers once per contest, dupes per band per mode, the files;
    * a county line is two counties;
    * an out-of-state station works only Nebraska;
    * the score: points x multipliers x HIGH 1 / LOW 2 / QRP 5, plus the
      bonus stations, per counting QSO;
    * Cabrillo and ADIF names. *)
unit uTestContestNebraskaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNebraskaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NebraskaIsAnAppendedStateParty;
      procedure Test_NebraskaPoints;
      procedure Test_NebraskaFTIsOffMode;
      procedure Test_NebraskaBands;
      procedure Test_NebraskaMultsOncePerContestDupesPerBandAndMode;
      procedure Test_NebraskaCountyFiles;
      procedure Test_NebraskaCountyLineIsTwoCounties;
      procedure Test_NebraskaOutOfStateWorksOnlyNebraska;
      procedure Test_NebraskaScoreIsPowerTimesFormula;
      procedure Test_NebraskaBonusIsPerCountingQSO;
      procedure Test_NebraskaNames;
      procedure Test_NebraskaRareGridTables;
      procedure Test_NebraskaRareGridPaysOnlyTheQSOsMadeThere;
      procedure Test_NebraskaRareGridReadsTheRowNotTheSession;
      procedure Test_NebraskaRareGridNeverCapturedUsesTheSession;
      procedure Test_NebraskaRareGridYearWithNoTablePaysNothingAndSaysSo;
      procedure Test_NebraskaHasARareGridTableForTheCurrentYear;
   end;

implementation

uses
   (* cpHIGH / cpLOW / cpQRP. Before VC, so VC's names win where they
      overlap. *)
   uSettingsModel,
   Classes, SysUtils, VC, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uContestNebraskaQP, uDomFileKeys,
   uAppStrings, uTR4WStrings,
   uTestContestObjects,
   uTestExchangeParserStub,
   (* The rare grid bonus: each QSO's recorded station, and proof the "no
      table" report is written. *)
   uQsoMyFacts,
   Log4D,
   uTestLogCapture;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

(* Every QSO these tests score is with a Nebraska station, so the table
   knows every QTH (Q107; the host-area rule is uTestHostAreaRule's). *)
function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'LNCS';
      end
   else
      begin
      Result.MyState := 'KS';
      end;
end;

function QsoOn(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
end;

function PointsFor(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(NEBRASKAQSO, StationAt(False));
   try
      qso := QsoOn(aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* THE STUBBED PARSE ENGINE: the shape sets the QTH it is told to, and the
   domestic table knows the keys in GDomesticKeys. *)
var
   GShapeSetsQTH: string;
   GDomesticKeys: string;

function StubParseShape(const aHelper: string; const aText: string;
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
   Result.Parsers := StubExchangeParsers(@StubParseShape);
   Result.IsDomesticQTH := @StubIsDomesticQTH;
   Result.CallWindowHasCall := True;
end;

function ParseAs(aInState: boolean; const aQTH: string; out aMessage: string): boolean;
var
   contestObject: TContestBase;
   exch: ContestExchange;
begin
   GShapeSetsQTH := aQTH;
   contestObject := Make(NEBRASKAQSO, StationAt(aInState));
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
   Result.Mults[AllBands, Both, rmDomestic] := aMults;
end;

function FinalAt(aPower: tCategoryPower; const aTotals: TScoreTotals;
                 aView: TLoggedQSOView): longint;
var
   station: TStationContext;
   contestObject: TContestBase;
begin
   station := StationAt(True);
   station.MyPower := aPower;
   contestObject := Make(NEBRASKAQSO, station);
   try
      Result := contestObject.FinalScore(aTotals, aView);
   finally
      contestObject.Free;
   end;
end;

function Logged(const aCall: string; aBand: BandType; aMode: ModeType;
                aExtMode: ExtendedModeType; aDupe: boolean): ContestExchange;
begin
   Result := QsoOn(aBand, aMode, aExtMode);
   Result.Callsign := CallString(aCall);
   Result.ceDupe := aDupe;
end;

(* A QSO OF THE aYear CONTEST, SCORED AS THE RESCORE SCORES IT -- through
   ScoreQSO with the row's own station -- so its QSOPoints are the class's,
   not typed here. A Nebraska entrant; K0ABC is no bonus station. *)
function RareGridQSO(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType;
                     aDupe: boolean; aYear: integer;
                     const aFacts: TQsoMyFacts): ContestExchange;
var
   contestObject: TContestBase;
begin
   Result := Logged('K0ABC', aBand, aMode, aExtMode, aDupe);
   Result.tSysTime.qtYear := aYear - 2000;
   Result.tSysTime.qtMonth := 4;
   Result.tSysTime.qtDay := 25;
   Result.tSysTime.qtHour := 15;
   contestObject := Make(NEBRASKAQSO, StationAt(True));
   try
      contestObject.ScoreQSO(Result, aFacts);
   finally
      contestObject.Free;
   end;
end;

(* A ROW THAT RECORDED OUR GRID -- this station logged it. *)
function FactsAt(const aGrid: string): TQsoMyFacts;
begin
   Result := NotCapturedMyFacts;
   Result.Source := mfsLogged;
   Result.Grid := AnsiString(aGrid);
end;

(* Adds a 2026 QSO made from aGrid. *)
procedure AddFrom(aView: TLoggedQSOList; const aGrid: string; aBand: BandType;
                  aMode: ModeType; aExtMode: ExtendedModeType; aDupe: boolean);
begin
   aView.Add(RareGridQSO(aBand, aMode, aExtMode, aDupe, 2026, FactsAt(aGrid)),
             FactsAt(aGrid));
end;

(* THE BONUS POINTS, for a Nebraska entrant whose SESSION grid is
   aSessionGrid (what a never-captured row reads). *)
function BonusWithSessionGrid(const aSessionGrid: string; aView: TLoggedQSOView): longint;
var
   station: TStationContext;
   contestObject: TContestBase;
begin
   station := StationAt(True);
   station.MyGrid := aSessionGrid;
   contestObject := Make(NEBRASKAQSO, station);
   try
      Result := contestObject.BonusPoints(Totals(0, 0), aView);
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE TESTS
   --------------------------------------------------------------------------- *)

(* APPENDED, NOT INSERTED: the ordinal is persisted in the binary log's
   ceContest byte, the multi-op packet and HamScore's <contestnr>. *)
procedure TContestNebraskaQPTests.Test_NebraskaIsAnAppendedStateParty;
var
   contestObject: TContestBase;
begin
   BeginTest('Test_NebraskaIsAnAppendedStateParty');
   CheckEquals(Ord(DELAWAREQSOPARTY) + 1, Ord(NEBRASKAQSO), 'appended right after Delaware');
   CheckEquals(Ord(High(ContestType)), Ord(NEBRASKAQSO), 'the last member');
   CheckEquals('NE-QSO-PARTY', string(ContestTypeSA[NEBRASKAQSO]), 'the config spelling');
   CheckTrue(ContestClassFor(NEBRASKAQSO) = TContestNebraskaQP, 'registered');

   contestObject := Make(NEBRASKAQSO);
   try
      CheckTrue(contestObject.ClassParent = TContestStateQSOPartyBase,
                'on the state-party family base, directly');
      CheckTrue(contestObject.IsUSQSOParty, 'a US QSO party');
      CheckEquals('NE', contestObject.HostState, 'its host state');
      CheckEquals('Nebraska QSO Party', contestObject.DisplayName, 'its display name');
      CheckEquals('Nebraska QSO Party', contestObject.FriendlyName, 'its friendly name');
      CheckEquals('nebraska_cty', contestObject.DomesticFileName, 'the county file');
      CheckEquals('nebraska', contestObject.InStateDomesticFileName, 'the in-state file');
      CheckEquals(336, contestObject.WA7BNMId, 'WA7BNM ref 336');
      CheckEquals('nebraskaqsoparty@gmail.com', contestObject.SubmissionEmail, 'the log address');
      CheckTrue(contestObject.MarksDupes, 'marks dupes');
      CheckTrue(contestObject.IsActive, 'active');
   finally
      contestObject.Free;
   end;
end;

(* "Digital 1, phone 2, CW 3." FM is phone; Both and NoMode score nothing. *)
procedure TContestNebraskaQPTests.Test_NebraskaPoints;
begin
   BeginTest('Test_NebraskaPoints');
   CheckEquals(3, PointsFor(Band20, CW, eCW), 'CW');
   CheckEquals(2, PointsFor(Band20, Phone, eUSB), 'phone');
   CheckEquals(2, PointsFor(Band2, FM, eFM), 'FM is phone');
   CheckEquals(1, PointsFor(Band20, Digital, eRTTY), 'RTTY');
   CheckEquals(1, PointsFor(Band20, Digital, ePSK31), 'PSK');
   CheckEquals(0, PointsFor(Band20, Both, eNoMode), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(Band20, NoMode, eNoMode), 'no mode');
end;

(* "FT8/FT4 is a SEPARATE competition with a separate log": logged here,
   scores nothing, earns no multiplier, pays no bonus. *)
procedure TContestNebraskaQPTests.Test_NebraskaFTIsOffMode;
var
   contestObject: TContestBase;
   k: RemainingMultiplierType;
begin
   BeginTest('Test_NebraskaFTIsOffMode');
   CheckEquals(0, PointsFor(Band20, Digital, eFT8), 'FT8 scores 0');
   CheckEquals(0, PointsFor(Band40, Digital, eFT4), 'FT4 scores 0');
   CheckTrue(IsNebraskaFTQSO(QsoOn(Band20, Digital, eFT8)), 'FT8 is the other competition');
   CheckFalse(IsNebraskaFTQSO(QsoOn(Band20, Digital, eRTTY)), 'RTTY is not');

   contestObject := Make(NEBRASKAQSO, StationAt(True));
   try
      for k := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
         begin
         CheckFalse(contestObject.CountsAsMultiplier(QsoOn(Band20, Digital, eFT8), k),
                    'an FT8 QSO earns no multiplier, kind ' + IntToStr(Ord(k)));
         CheckTrue(contestObject.CountsAsMultiplier(QsoOn(Band20, Digital, eRTTY), k),
                   'an RTTY QSO does, kind ' + IntToStr(Ord(k)));
         end;
   finally
      contestObject.Free;
   end;
end;

(* "160, 80, 40, 20, 15, 10 m; WARC contacts do not count; all VHF/UHF bands
   are allowed." *)
procedure TContestNebraskaQPTests.Test_NebraskaBands;
var
   contestObject: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_NebraskaBands');
   contestObject := Make(NEBRASKAQSO);
   try
      for b := Low(BandType) to High(BandType) do
         begin
         expected := not (b in [Band30, Band17, Band12, AllBands, NoBand]);
         CheckEquals(Ord(expected), Ord(ContestCreditsBand(contestObject, b)),
                     'band ' + IntToStr(Ord(b)) + ' credited');
         end;
      CheckTrue(contestObject.VHFBandsEnabled, '6 m and up are on');
   finally
      contestObject.Free;
   end;
   CheckEquals(0, PointsFor(Band30, CW, eCW), '30 m scores nothing');
   CheckEquals(3, PointsFor(Band160, CW, eCW), '160 m scores');
   CheckEquals(2, PointsFor(Band432, Phone, eUSB), '70 cm scores');
end;

(* Multipliers ONCE PER CONTEST; dupes once per band per mode. A Nebraska
   entrant counts DXCC entities; anyone else only the counties. *)
procedure TContestNebraskaQPTests.Test_NebraskaMultsOncePerContestDupesPerBandAndMode;
var
   contestObject: TContestBase;
   session: TSessionDefaults;
   v: TSessionValue;
begin
   BeginTest('Test_NebraskaMultsOncePerContestDupesPerBandAndMode');
   contestObject := Make(NEBRASKAQSO);
   try
      CheckFalse(contestObject.MultByBand, 'a multiplier counts once, not per band');
      CheckFalse(contestObject.MultByMode, 'and not per mode');
      CheckTrue(contestObject.QSOByBand, 'a station may be worked once per band');
      CheckTrue(contestObject.QSOByMode, 'and once per mode');
      CheckTrue(contestObject.UsesDomesticFile, 'counties, states and provinces from the file');
      contestObject.SetStation(StationAt(True));
      CheckTrue(contestObject.HasDXMultiplier, 'in NE: DXCC entities');
      contestObject.SetStation(StationAt(False));
      CheckFalse(contestObject.HasDXMultiplier, 'outside NE: no DX multiplier');
      CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(contestObject.ExchangeKind),
                  'RST and a county, state, province or DX');
   finally
      contestObject.Free;
   end;

   session := TSessionDefaults.Create;
   try
      ContestIdentity(NEBRASKAQSO).DescribeSession(StationAt(True), session);
      for v := Low(TSessionValue) to High(TSessionValue) do
         begin
         CheckFalse(session.IsStated(v), 'set-up states nothing: ' + IntToStr(Ord(v)));
         end;
   finally
      session.Free;
   end;
end;

(* The county file: the 93 counties of DXLog's list, each its OWN
   multiplier (no '>' mapping), including nothing. The in-state file: the
   counties first, then S50 and P13, then NF and LB as NL; no header line
   holds an '='. *)
procedure TContestNebraskaQPTests.Test_NebraskaCountyFiles;
var
   lines: TStringList;
   keys: TStringList;
   i: integer;
   key: string;
   includes: string;
   entries: string;
begin
   BeginTest('Test_NebraskaCountyFiles');
   lines := TStringList.Create;
   keys := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'nebraska_cty.dom'));
      for i := 0 to lines.Count - 1 do
         begin
         key := DomFileLineKey(string(lines[i]));
         if key <> '' then
            begin
            CheckEquals(-1, keys.IndexOf(key), 'county ' + key + ' listed once');
            keys.Add(key);
            CheckEquals(4, Length(key), 'a four-letter abbreviation: ' + key);
            end;
         CheckEquals(0, Pos('>', string(lines[i])),
                     'no county is mapped to Ne, line ' + IntToStr(i + 1));
         CheckTrue(Pos('INCLUDE', UpperCase(string(lines[i]))) = 0,
                   'the county file includes nothing, line ' + IntToStr(i + 1));
         end;
      CheckEquals(93, keys.Count, 'the 93 counties');
      CheckTrue(keys.IndexOf('ADMS') >= 0, 'Adams');
      CheckTrue(keys.IndexOf('LNCS') >= 0, 'Lancaster');
      CheckTrue(keys.IndexOf('YORK') >= 0, 'York');

      lines.LoadFromFile(AnsiString(ShippedDomDir + 'nebraska.dom'));
      includes := '';
      entries := '';
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('INCLUDE FILE ', UpperCase(string(lines[i]))) = 1 then
            begin
            includes := includes + UpperCase(Trim(Copy(string(lines[i]), 14, MaxInt))) + ' ';
            end
         else if Pos('=', string(lines[i])) > 0 then
            begin
            entries := entries + Trim(string(lines[i])) + '|';
            end;
         end;
      CheckEquals('NEBRASKA_CTY.DOM S50.DOM P13.DOM ', includes,
                  'the counties first, then the states and the provinces');
      CheckEquals('Nl = NF,LB|', entries, 'one entry: NF and LB are NL');
   finally
      keys.Free;
      lines.Free;
   end;
end;

(* "County lines limited to two counties." *)
procedure TContestNebraskaQPTests.Test_NebraskaCountyLineIsTwoCounties;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_NebraskaCountyLineIsTwoCounties');
   contestObject := Make(NEBRASKAQSO);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(2, party.CountyLineCountiesMax, 'two counties on a line');
      CheckTrue(party.ValidateQTHCount(2, msg), 'a line of two');
      CheckFalse(party.ValidateQTHCount(3, msg), 'three is refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), msg, 'with the county-count message');
      CheckTrue(contestObject.StripsRoverCountyFromCall, 'a mobile signs call/county');
   finally
      contestObject.Free;
   end;
end;

(* An out-of-state station may work only Nebraska stations; a Nebraska
   station works everyone. *)
procedure TContestNebraskaQPTests.Test_NebraskaOutOfStateWorksOnlyNebraska;
var
   msg: string;
begin
   BeginTest('Test_NebraskaOutOfStateWorksOnlyNebraska');
   GDomesticKeys := 'ADMS,LNCS,YORK';
   CheckTrue(ParseAs(False, 'LNCS', msg), 'outside NE, a Lancaster County station');
   CheckEquals('', msg, 'nothing to say');
   CheckFalse(ParseAs(False, 'KS', msg), 'outside NE, a Kansas station: refused');
   CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['NE']), msg, 'with the reason');
   CheckFalse(ParseAs(False, 'DX', msg), 'outside NE, a DX station: refused');

   GDomesticKeys := 'ADMS,LNCS,YORK,KS,ON';
   CheckTrue(ParseAs(True, 'KS', msg), 'in NE, a Kansas station');
   CheckTrue(ParseAs(True, 'DX', msg), 'in NE, a DX station');
   CheckTrue(ParseAs(True, 'YORK', msg), 'in NE, another NE county');
end;

(* "QSO points x power multiplier x geo multiplier": HIGH x1, LOW x2,
   QRP x5 -- one multiplier on the whole score. *)
procedure TContestNebraskaQPTests.Test_NebraskaScoreIsPowerTimesFormula;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
begin
   BeginTest('Test_NebraskaScoreIsPowerTimesFormula');
   CheckEquals(1, NebraskaPowerMultiplier(cpHIGH), 'otherwise: x1');
   CheckEquals(2, NebraskaPowerMultiplier(cpLOW), 'under 100 W: x2');
   CheckEquals(5, NebraskaPowerMultiplier(cpQRP), '5 W or less: x5');

   view := TLoggedQSOList.Create;
   try
      t := Totals(100, 5);
      t.Mults[AllBands, Both, rmDX] := 2;
      CheckEquals(100 * 7, FinalAt(cpHIGH, t, view), 'HIGH: points x every multiplier');
      CheckEquals(100 * 7 * 2, FinalAt(cpLOW, t, view), 'LOW doubles');
      CheckEquals(100 * 7 * 5, FinalAt(cpQRP, t, view), 'QRP is five times');
      CheckEquals(0, FinalAt(cpQRP, Totals(0, 0), view), 'an empty log scores nothing');
   finally
      view.Free;
   end;
end;

(* 100 for KA0BOJ, 50 for each of the six others -- PER COUNTING QSO: not a
   dupe, on a credited band, not FT8/FT4. The power multiplier does not
   touch it. *)
procedure TContestNebraskaQPTests.Test_NebraskaBonusIsPerCountingQSO;
var
   view: TLoggedQSOList;
   t: TScoreTotals;
begin
   BeginTest('Test_NebraskaBonusIsPerCountingQSO');
   CheckEquals('KA0BOJ', NEBRASKA_BONUS_STATIONS[0].Call, 'the 100-point station');
   CheckEquals(100, NEBRASKA_BONUS_STATIONS[0].Points, 'pays 100');

   view := TLoggedQSOList.Create;
   try
      t := Totals(0, 0);
      view.Add(Logged('KA0BOJ', Band20, CW, eCW, False));
      CheckEquals(100, FinalAt(cpHIGH, t, view), 'one QSO with KA0BOJ');
      view.Add(Logged('KA0BOJ', Band40, CW, eCW, False));
      view.Add(Logged('KA0BOJ', Band40, Phone, eLSB, False));
      CheckEquals(300, FinalAt(cpHIGH, t, view), 'again on another band, and another mode');
      view.Add(Logged('KA0BOJ', Band40, Phone, eLSB, True));
      CheckEquals(300, FinalAt(cpHIGH, t, view), 'a dupe pays nothing');
      view.Add(Logged('KA0BOJ', Band20, Digital, eFT8, False));
      CheckEquals(300, FinalAt(cpHIGH, t, view), 'an FT8 QSO pays nothing');
      view.Add(Logged('KA0BOJ', Band30, CW, eCW, False));
      CheckEquals(300, FinalAt(cpHIGH, t, view), 'nor a 30 m one');
      view.Add(Logged('K0SMM', Band20, CW, eCW, False));
      view.Add(Logged('KE0XQ', Band6, Phone, eUSB, False));
      CheckEquals(400, FinalAt(cpHIGH, t, view), 'K0SMM and KE0XQ pay 50 each');
      view.Add(Logged('K0ABC', Band20, CW, eCW, False));
      CheckEquals(400, FinalAt(cpHIGH, t, view), 'any other call pays nothing');
      CheckEquals(400, FinalAt(cpQRP, t, view), 'the power multiplier does not touch the bonus');
   finally
      view.Free;
   end;
end;

(* NE-QSO-PARTY, Cabrillo and ADIF -- and 'NEQP' is New England's, never
   this contest's. *)
procedure TContestNebraskaQPTests.Test_NebraskaNames;
var
   c: TContestHandle;
begin
   BeginTest('Test_NebraskaNames');
   CheckEquals('NE-QSO-PARTY', ContestIdentity(NEBRASKAQSO).CabrilloName, 'the Cabrillo name');
   CheckEquals('NE-QSO-PARTY', ContestIdentity(NEBRASKAQSO).ADIFContestId, 'the ADIF id');
   CheckTrue(FindContestByADIFContestId('NE-QSO-PARTY', c), 'import resolves it');
   CheckEquals(Ord(NEBRASKAQSO), c.ToByte, 'to Nebraska');
   CheckTrue(FindContestByADIFContestId('NEQP', c), 'NEQP resolves');
   CheckEquals(Ord(NEWENGLANDQSO), c.ToByte, 'to New England, never Nebraska');
   CheckEquals(' 5NN LNCS', ContestIdentity(NEBRASKAQSO).CQExchangeDefault(StationAt(True)),
               'in NE, the county');
   CheckEquals(' 5NN KS', ContestIdentity(NEBRASKAQSO).CQExchangeDefault(StationAt(False)),
               'outside NE, the state');
end;

(* THE YEARS' LISTS. 2026: the sponsor's rules; 2025: the 2025 summary
   sheet. SIX characters, case-blind; a four-character square is not a
   subsquare, and an extended locator is read by its first six. *)
procedure TContestNebraskaQPTests.Test_NebraskaRareGridTables;
var
   rare: boolean;
begin
   BeginTest('Test_NebraskaRareGridTables');
   CheckTrue(TContestNebraskaQP.HasRareGridTable(2026), '2026 has a list');
   CheckTrue(TContestNebraskaQP.HasRareGridTable(2025), '2025 has a list');
   CheckFalse(TContestNebraskaQP.HasRareGridTable(2024), '2024 has none');
   CheckFalse(TContestNebraskaQP.HasRareGridTable(0), 'nor an unknown year');

   CheckTrue(NebraskaRareGrid(2026, 'DN91CE', rare) and rare, 'DN91CE');
   CheckTrue(NebraskaRareGrid(2026, 'DN91DE', rare) and rare, 'DN91DE');
   CheckTrue(NebraskaRareGrid(2026, 'DN91EE', rare) and rare, 'DN91EE');
   CheckTrue(NebraskaRareGrid(2026, 'dn91ce', rare) and rare, 'case-blind');
   CheckTrue(NebraskaRareGrid(2026, ' DN91EE ', rare) and rare, 'blanks trimmed');
   CheckTrue(NebraskaRareGrid(2026, 'DN91CE12', rare) and rare, 'an extended locator by its first six');
   CheckTrue(NebraskaRareGrid(2026, 'DN91', rare) and not rare, 'DN91 is a square, not a rare subsquare');
   CheckTrue(NebraskaRareGrid(2026, 'DN91FE', rare) and not rare, 'the next subsquare east is not');
   CheckTrue(NebraskaRareGrid(2026, 'DN92CE', rare) and not rare, 'DN92CE is not');
   CheckTrue(NebraskaRareGrid(2026, 'EM17', rare) and not rare, 'EM17 is not');
   CheckTrue(NebraskaRareGrid(2026, '', rare) and not rare, 'no grid is not');
   CheckTrue(NebraskaRareGrid(2026, 'EN01MI', rare) and not rare, 'a 2025 grid is not rare in 2026');
   CheckTrue(NebraskaRareGrid(2025, 'EN01MI', rare) and rare, 'EN01MI in 2025');
   CheckTrue(NebraskaRareGrid(2025, 'EN01NI', rare) and rare, 'EN01NI in 2025');
   CheckTrue(NebraskaRareGrid(2025, 'EN01MH', rare) and rare, 'EN01MH in 2025');
   CheckTrue(NebraskaRareGrid(2025, 'EN01NH', rare) and rare, 'EN01NH in 2025');
   CheckTrue(NebraskaRareGrid(2025, 'DN91CE', rare) and not rare, 'a 2026 grid is not rare in 2025');
   CheckFalse(NebraskaRareGrid(2031, 'DN91CE', rare), 'a year with no list answers False');
   CheckFalse(rare, 'and nothing is rare in it');
   CheckEquals(5, NEBRASKA_RARE_GRID_MULTIPLIER, '"the rare grid multiplier of 5"');
end;

(* A ROVER: 5 x the points of the QSOs made FROM a rare subsquare, and of no
   other. CW 3, phone 2, digital 1; a dupe, an FT8 QSO and a WARC QSO from
   the rare grid pay nothing; a captured row with no grid pays nothing. The
   bonus sits BESIDE the score: neither the power nor the county multiplier
   touches it. *)
procedure TContestNebraskaQPTests.Test_NebraskaRareGridPaysOnlyTheQSOsMadeThere;
var
   view: TLoggedQSOList;
begin
   BeginTest('Test_NebraskaRareGridPaysOnlyTheQSOsMadeThere');
   view := TLoggedQSOList.Create;
   try
      (* THE SPONSOR'S EXAMPLE: "a phone QSO that is 2 points and a CW QSO
         that is 3 points ... 5 points times the rare grid multiplier of 5
         for a bonus of 25 points". *)
      AddFrom(view, 'DN91CE', Band20, Phone, eUSB, False);
      AddFrom(view, 'DN91CE', Band40, CW, eCW, False);
      CheckEquals(25, BonusWithSessionGrid('EM17', view), 'the sponsor''s example: 25');

      AddFrom(view, 'DN91DE', Band20, Digital, eRTTY, False);
      CheckEquals(30, BonusWithSessionGrid('EM17', view), 'digital from DN91DE: 1 x 5 more');
      AddFrom(view, 'DN91EE', Band80, CW, eCW, False);
      CheckEquals(45, BonusWithSessionGrid('EM17', view), 'CW from DN91EE: 3 x 5 more');

      (* THE ROVER MOVES ON: QSOs from ordinary grids pay nothing. *)
      AddFrom(view, 'EM17', Band20, CW, eCW, False);
      AddFrom(view, 'DN92CE', Band20, CW, eCW, False);
      AddFrom(view, 'DN91', Band20, CW, eCW, False);
      AddFrom(view, '', Band20, CW, eCW, False);
      CheckEquals(45, BonusWithSessionGrid('DN91CE', view),
                  'EM17, DN92CE, a four-character DN91 and a captured empty grid pay nothing -- ' +
                  'not even with the session in DN91CE');

      (* QSOs THAT DO NOT COUNT, FROM THE RARE GRID. *)
      AddFrom(view, 'DN91CE', Band40, CW, eCW, True);
      AddFrom(view, 'DN91CE', Band20, Digital, eFT8, False);
      AddFrom(view, 'DN91CE', Band40, Digital, eFT4, False);
      AddFrom(view, 'DN91CE', Band30, CW, eCW, False);
      CheckEquals(45, BonusWithSessionGrid('EM17', view), 'a dupe, FT8, FT4 and 30 m pay nothing');

      CheckEquals(45, FinalAt(cpHIGH, Totals(0, 0), view), 'the final score carries it');
      CheckEquals(45, FinalAt(cpQRP, Totals(0, 0), view), 'and QRP does not multiply it');
      CheckEquals(100 * 3 * 2 + 45, FinalAt(cpLOW, Totals(100, 3), view),
                  'points x multipliers x power, PLUS the bonus');
   finally
      view.Free;
   end;
end;

(* THE RESCORE: the same rows scored again, by the rescore's call, with the
   session now somewhere else, give the same bonus -- the grid is the ROW'S.
   And a session in a rare grid does not pay rows recorded elsewhere. *)
procedure TContestNebraskaQPTests.Test_NebraskaRareGridReadsTheRowNotTheSession;
var
   view: TLoggedQSOList;
   rescored: TLoggedQSOList;
   i: integer;
   qso: ContestExchange;
   contestObject: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_NebraskaRareGridReadsTheRowNotTheSession');
   view := TLoggedQSOList.Create;
   rescored := TLoggedQSOList.Create;
   try
      AddFrom(view, 'DN91CE', Band20, CW, eCW, False);
      AddFrom(view, 'DN91DE', Band40, Phone, eLSB, False);
      AddFrom(view, 'EM17', Band20, CW, eCW, False);
      CheckEquals((3 + 2) * 5, BonusWithSessionGrid('DN91CE', view), 'as logged');

      (* RESCORE every row from its own facts, the session moved to EM17. *)
      station := StationAt(True);
      station.MyGrid := 'EM17';
      contestObject := Make(NEBRASKAQSO, station);
      try
         for i := 0 to view.Count - 1 do
            begin
            qso := view.QSO(i);
            qso.QSOPoints := 0;
            contestObject.ScoreQSO(qso, view.MyFacts(i));
            rescored.Add(qso, view.MyFacts(i));
            end;
         CheckEquals((3 + 2) * 5, contestObject.BonusPoints(Totals(0, 0), rescored),
                     'rescored with the session in EM17: the same bonus');
      finally
         contestObject.Free;
      end;

      rescored.Clear;
      rescored.Add(view.QSO(2), view.MyFacts(2));
      CheckEquals(0, BonusWithSessionGrid('DN91CE', rescored),
                  'a row recorded in EM17 is not paid because the session is in DN91CE');
   finally
      rescored.Free;
      view.Free;
   end;
end;

(* RULING A: a row written before schema 3 recorded no station, and reads
   the SESSION'S grid. *)
procedure TContestNebraskaQPTests.Test_NebraskaRareGridNeverCapturedUsesTheSession;
var
   view: TLoggedQSOList;
begin
   BeginTest('Test_NebraskaRareGridNeverCapturedUsesTheSession');
   view := TLoggedQSOList.Create;
   try
      view.Add(RareGridQSO(Band20, CW, eCW, False, 2026, NotCapturedMyFacts));
      view.Add(RareGridQSO(Band40, Phone, eLSB, False, 2026, NotCapturedMyFacts),
               NotCapturedMyFacts);
      CheckEquals(Ord(mfsNotCaptured), Ord(view.MyFacts(0).Source), 'never captured');
      CheckEquals((3 + 2) * 5, BonusWithSessionGrid('DN91EE', view), 'the session is in DN91EE: paid');
      CheckEquals(0, BonusWithSessionGrid('EM17', view), 'the session is in EM17: not');
      CheckEquals(0, BonusWithSessionGrid('', view), 'the session has no grid: not');
   finally
      view.Free;
   end;
end;

(* A YEAR WITH NO LIST pays no rare-grid bonus and SAYS SO, once per year;
   an empty log asks no year and reports nothing. The station bonus is still
   paid. *)
procedure TContestNebraskaQPTests.Test_NebraskaRareGridYearWithNoTablePaysNothingAndSaysSo;
var
   capture: TCaptureAppender;
   keep: ILogAppender;
   lg: TLogLogger;
   savedLevel: TLogLevel;
   station: TStationContext;
   contestObject: TContestBase;
   view: TLoggedQSOList;
   bonusQso: ContestExchange;
begin
   BeginTest('Test_NebraskaRareGridYearWithNoTablePaysNothingAndSaysSo');

   capture := TCaptureAppender.Create('capture');
   keep := capture;
   lg := TLogLogger.GetLogger('uContestNebraskaQP');
   savedLevel := lg.Level;
   lg.Level := Log4D.Error;
   lg.AddAppender(keep);
   view := TLoggedQSOList.Create;
   station := StationAt(True);
   station.MyGrid := 'DN91CE';
   contestObject := Make(NEBRASKAQSO, station);
   try
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), 'an empty log');
      CheckEquals(0, capture.Lines.Count, 'asks no year, reports nothing');

      view.Add(RareGridQSO(Band20, CW, eCW, False, 2031, FactsAt('DN91CE')), FactsAt('DN91CE'));
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), '2031 has no list: no rare grid bonus');
      CheckEquals(1, capture.Lines.Count, 'and it is REPORTED');
      CheckTrue(Pos('2031', capture.Lines.Text) > 0, 'naming the year: ' + capture.Lines.Text);
      CheckTrue(Pos('NOT in the score', capture.Lines.Text) > 0,
                'and saying the score leaves it out: ' + capture.Lines.Text);

      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), 'asked again');
      CheckEquals(1, capture.Lines.Count, 'reported once per year, not once per score');

      bonusQso := RareGridQSO(Band40, CW, eCW, False, 2031, FactsAt('DN91CE'));
      bonusQso.Callsign := CallString('KA0BOJ');
      view.Add(bonusQso, FactsAt('DN91CE'));
      CheckEquals(100, contestObject.BonusPoints(Totals(0, 0), view),
                  'the station bonus is still paid in that year');
   finally
      lg.RemoveAppender(keep);
      lg.Level := savedLevel;
      keep := nil;
      contestObject.Free;
      view.Free;
   end;
end;

(* THE YEARLY REMINDER, ON PURPOSE AGAINST THE CLOCK (Idaho's Q35 pattern):
   the first run of a contest year with no rare-grid list fails until the
   sponsor's list for that year is added to uContestNebraskaQP as a new
   table. Never register an old list for a new year without the sponsor's
   word. *)
procedure TContestNebraskaQPTests.Test_NebraskaHasARareGridTableForTheCurrentYear;
begin
   BeginTest('Test_NebraskaHasARareGridTableForTheCurrentYear');
   CheckTrue(TContestNebraskaQP.HasRareGridTable(CurrentYear),
             Format('YEARLY REMINDER: uContestNebraskaQP has no rare-grid list for %d. ' +
                    'Add the sponsor''s list for that contest (nebraskaqsoparty.com).',
                    [CurrentYear]));
end;

procedure TContestNebraskaQPTests.RunAllTests;
begin
   Test_NebraskaIsAnAppendedStateParty;
   Test_NebraskaPoints;
   Test_NebraskaFTIsOffMode;
   Test_NebraskaBands;
   Test_NebraskaMultsOncePerContestDupesPerBandAndMode;
   Test_NebraskaCountyFiles;
   Test_NebraskaCountyLineIsTwoCounties;
   Test_NebraskaOutOfStateWorksOnlyNebraska;
   Test_NebraskaScoreIsPowerTimesFormula;
   Test_NebraskaBonusIsPerCountingQSO;
   Test_NebraskaNames;
   Test_NebraskaRareGridTables;
   Test_NebraskaRareGridPaysOnlyTheQSOsMadeThere;
   Test_NebraskaRareGridReadsTheRowNotTheSession;
   Test_NebraskaRareGridNeverCapturedUsesTheSession;
   Test_NebraskaRareGridYearWithNoTablePaysNothingAndSaysSo;
   Test_NebraskaHasARareGridTableForTheCurrentYear;
end;

end.

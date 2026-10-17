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
   uTestExchangeParserStub;

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
end;

end.

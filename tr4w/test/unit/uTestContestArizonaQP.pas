(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* THE ARIZONA QSO PARTY'S 2026 RULES (the state-party audit, 2026-11-20).
  The sponsor's text is "AZQP Rules 2026, Rev 2502 10/05/2026", saved by NY4I
  under docs/ContestRules/QSOParties/Arizona/; each test quotes the rule it
  holds, never the class. *)
unit uTestContestArizonaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestArizonaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ArizonaBandsAndModes;
      procedure Test_ArizonaPoints;
      procedure Test_ArizonaExchangeCarriesNoSerial;
      procedure Test_ArizonaDXMultiplierIsInStateAndNotKH6;
      procedure Test_ArizonaCountyIsTheStateInState;
      procedure Test_ArizonaK7AOnce;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestObjects,
   uTestQSOPartyRules;

(* An Arizona entrant (Maricopa) or one in California; the host-area table
   knows every QTH, so a points test is not about that rule. *)
function Entrant(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'MCP';
      end
   else
      begin
      Result.MyState := 'CA';
      end;
end;

function AZQso(const aCall: string; aBand: BandType; aMode: ModeType;
               aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := ShortString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'MCP';
   Result.DomesticQTH := 'MCP';
end;

(* What ScoreQSO gives -- the one public scoring entry. *)
function PointsFor(aInState: boolean; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(ArizonaQsoParty, Entrant(aInState));
   try
      qso := AZQso('K7ABC', aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "MODES: CW, Phone"; "BANDS: 160, 80, 40, 20, 15, 10 meters". A digital or
   WARC QSO is an automatic X-QSO. FM is phone. *)
procedure TContestArizonaQPTests.Test_ArizonaBandsAndModes;
var
   identity: TContestBase;
   b: BandType;
   ext: ExtendedModeType;
begin
   BeginTest('Test_ArizonaBandsAndModes');
   identity := ContestIdentity(ArizonaQsoParty);
   for b := Low(BandType) to High(BandType) do
      begin
      if not (b in [AllBands, NoBand]) then
         begin
         CheckTrue(identity.UsesBand(b) =
                   (b in [Band160, Band80, Band40, Band20, Band15, Band10]),
                   'band ' + IntToStr(Ord(b)) + ' is credited exactly when the rules list it');
         end;
      end;
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'no digital submode is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, CW, ext), 'CW is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, Phone, ext), 'phone is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, FM, ext), 'FM is credited, ext ' + IntToStr(Ord(ext)));
      end;
   CheckTrue(QSOIsXQSO(identity, AZQso('K7ABC', Band20, Digital, eRTTY)),
             'an RTTY QSO is an X-QSO');
   CheckTrue(QSOIsXQSO(identity, AZQso('K7ABC', Band30, CW, eCW)),
             'a 30 m QSO is an X-QSO');
   CheckFalse(QSOIsXQSO(identity, AZQso('K7ABC', Band20, CW, eCW)),
              'a 20 m CW QSO is not');
end;

(* "QSO POINTS: CW=2; Phone=1", on both sides of the state line. *)
procedure TContestArizonaQPTests.Test_ArizonaPoints;
var
   inState: boolean;
begin
   BeginTest('Test_ArizonaPoints');
   for inState := False to True do
      begin
      CheckEquals(2, PointsFor(inState, Band20, CW, eCW), 'CW 2');
      CheckEquals(1, PointsFor(inState, Band40, Phone, eLSB), 'phone 1');
      CheckEquals(1, PointsFor(inState, Band10, FM, eFM), 'FM is phone: 1');
      CheckEquals(0, PointsFor(inState, Band20, Digital, eRTTY), 'digital is no mode of the contest');
      CheckEquals(0, PointsFor(inState, Band17, CW, eCW), '17 m is no band of the contest');
      end;
end;

(* "Arizona stations: Send signal report RS(T) and 3-letter county
   abbreviation"; "Stations outside of Arizona: Send signal report RS(T) and
   2-letter state or Canadian province / territory." No serial anywhere --
   the fields are the ADIF export, so a QSO number here wrote an SRX. *)
procedure TContestArizonaQPTests.Test_ArizonaExchangeCarriesNoSerial;
var
   contestObject: TContestBase;
   inState: boolean;
   fields: ExchangeInformationRecord;
begin
   BeginTest('Test_ArizonaExchangeCarriesNoSerial');
   for inState := False to True do
      begin
      contestObject := Make(ArizonaQsoParty, Entrant(inState));
      try
         fields := contestObject.ReceivedExchangeFields;
         CheckTrue(fields.RST, 'the RS(T) is received');
         CheckTrue(fields.QTH, 'and the county, state or province');
         CheckFalse(fields.QSONumber, 'and no serial number');
      finally
         contestObject.Free;
      end;
      end;
end;

(* "Arizona stations: Multipliers are the 50 US states, the 13 Canadian
   provinces and territories, and DXCC countries." "Stations outside of
   Arizona: Multipliers are the 15 Arizona counties." Hawaii and Alaska are
   two of the 50 states, so KH6 is no DXCC multiplier; an entrant outside
   Arizona has none at all. *)
procedure TContestArizonaQPTests.Test_ArizonaDXMultiplierIsInStateAndNotKH6;
var
   contestObject: TContestBase;
   qso: ContestExchange;
   key: DXMultiplierString;
begin
   BeginTest('Test_ArizonaDXMultiplierIsInStateAndNotKH6');
   contestObject := Make(ArizonaQsoParty, Entrant(True));
   try
      CheckTrue(contestObject.HasDXMultiplier, 'in Arizona: DXCC countries');
      CheckTrue(contestObject.CountryMode = ARRLCountryMode, 'counted on the DXCC list');
      qso := Default(ContestExchange);
      qso.QTH.CountryID := 'ON';
      CheckTrue(contestObject.DXMultiplierKey(qso, key), 'Belgium is a DX multiplier');
      CheckEquals('ON', string(key), 'keyed ON');
      qso.QTH.CountryID := 'KH6';
      CheckFalse(contestObject.DXMultiplierKey(qso, key), 'Hawaii is a state, not DX');
      qso.QTH.CountryID := 'KL';
      CheckFalse(contestObject.DXMultiplierKey(qso, key), 'nor is Alaska');
      qso.QTH.CountryID := 'VE';
      CheckFalse(contestObject.DXMultiplierKey(qso, key), 'nor Canada');
   finally
      contestObject.Free;
   end;

   contestObject := Make(ArizonaQsoParty, Entrant(False));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'outside Arizona: the counties alone');
      qso := Default(ContestExchange);
      qso.QTH.CountryID := 'ON';
      CheckFalse(contestObject.DXMultiplierKey(qso, key), 'so no DX key');
   finally
      contestObject.Free;
   end;
end;

(* "A valid contact consists of ... an Arizona station (AZ) and any other
   station (Non-AZ or AZ)", and an Arizona station's multipliers are "the
   50 US states": an Arizona county, worked in state, is the state AZ. The
   in-state file listed the counties behind a never-followed include line. *)
procedure TContestArizonaQPTests.Test_ArizonaCountyIsTheStateInState;
begin
   BeginTest('Test_ArizonaCountyIsTheStateInState');
   CheckEquals('AZ', InStateMultiplierOf(ArizonaQsoParty, 'MCP'), 'Maricopa is Arizona');
   CheckEquals('AZ', InStateMultiplierOf(ArizonaQsoParty, 'YMA'), 'Yuma is Arizona');
   CheckEquals('AZ', InStateMultiplierOf(ArizonaQsoParty, 'AZ'), 'and AZ itself');
   CheckEquals('CA', InStateMultiplierOf(ArizonaQsoParty, 'CA'), 'California is a state');
   CheckEquals('HI', InStateMultiplierOf(ArizonaQsoParty, 'HI'), 'Hawaii is a state');
   CheckEquals('NL', InStateMultiplierOf(ArizonaQsoParty, 'NL'), 'Newfoundland is a province');
end;

(* "Receive a one-time bonus of 100 points for a QSO with K7A on any band or
   mode during the contest." A dupe or an X-QSO is not a QSO. *)
procedure TContestArizonaQPTests.Test_ArizonaK7AOnce;
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;
   dupe: ContestExchange;
begin
   BeginTest('Test_ArizonaK7AOnce');
   t := Default(TScoreTotals);
   view := TLoggedQSOList.Create;
   contestObject := Make(ArizonaQsoParty, Entrant(True));
   try
      CheckEquals(0, contestObject.BonusPoints(t, view), 'an empty log');

      view.Add(AZQso('K7A', Band80, Digital, eRTTY));
      CheckEquals(0, contestObject.BonusPoints(t, view), 'a digital QSO is an X-QSO: nothing');

      dupe := AZQso('K7A', Band20, CW, eCW);
      dupe.ceDupe := True;
      view.Add(dupe);
      CheckEquals(0, contestObject.BonusPoints(t, view), 'a dupe pays nothing');

      view.Add(AZQso('K7A', Band20, CW, eCW));
      CheckEquals(100, contestObject.BonusPoints(t, view), 'K7A: 100');

      view.Add(AZQso('K7A', Band40, Phone, eLSB));
      CheckEquals(100, contestObject.BonusPoints(t, view), 'once, on any band or mode');

      view.Add(AZQso('K7ABC', Band15, CW, eCW));
      CheckEquals(100, contestObject.BonusPoints(t, view), 'another call is not K7A');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

procedure TContestArizonaQPTests.RunAllTests;
begin
   Test_ArizonaBandsAndModes;
   Test_ArizonaPoints;
   Test_ArizonaExchangeCarriesNoSerial;
   Test_ArizonaDXMultiplierIsInStateAndNotKH6;
   Test_ArizonaCountyIsTheStateInState;
   Test_ArizonaK7AOnce;
end;

end.

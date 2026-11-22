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

(* THE RUSSIAN WW DIGITAL CONTEST (RUS-WW-DIGI) -- added 2026-11-22, issue
  #93. The rules are docs/ContestRules/RUS-WW-DIGI/rules-rus-ww-digi.txt;
  each test below quotes the rule it holds.

  WHAT IS PINNED
    * its identity: the id, no legacy number, the names, russian.dom, the
      flags, the multipliers it has;
    * its bands (160/80/40/20/15/10 m) and its modes (RTTY45, BPSK63);
    * every row of the points table, the low-band doubling and a QRP
      station, through ScoreQSO;
    * the DX multiplier: every DXCC country, Russia's own included, on the
      ARRL list;
    * the parse route (the RST + oblast-or-serial format) and the initial
      exchange of a Russian call;
    * the Cabrillo mode column (RY, PM) and the schedule.

  NOT PINNED HERE: a real-engine session (typed entry through
  ParametersOkay, the real sheets) -- the contest matrix's first record is
  the only end-to-end statement until one is written. *)
unit uTestContestRusWWDigi;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestRusWWDigiTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_RusWWDigiIdentity;
      procedure Test_RusWWDigiBandsAndModes;
      procedure Test_RusWWDigiPointsEveryRow;
      procedure Test_RusWWDigiQRPStation;
      procedure Test_RusWWDigiDXMultiplierIsEveryDXCCCountry;
      procedure Test_RusWWDigiParseRoute;
      procedure Test_RusWWDigiInitialExchange;
      procedure Test_RusWWDigiCabrilloModeColumn;
      procedure Test_RusWWDigiSchedule;
   end;

implementation

uses
   SysUtils,
   DateUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uContestSchedule,
   uContestRusWWDigi,
   uTestContestObjects,
   uTestExchangeParserStub;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

function RusHandle: TContestHandle;
begin
   if not FindContestById(RUS_WW_DIGI_CONTEST_ID, Result) then
      begin
      raise Exception.Create('RUS-WW-DIGI is not registered');
      end;
end;

(* An entrant in aCountry, on aContinent. *)
function RusStation(const aCountry: string; aContinent: ContinentType): TStationContext;
begin
   Result := NoStation;
   Result.MyCountry := CallString(aCountry);
   Result.MyContinent := aContinent;
end;

function MakeRus(const aStation: TStationContext): TContestBase;
begin
   Result := ContestClassFor(RusHandle).Create(RusHandle);
   Result.SetStation(aStation);
end;

function RusQso(aBand: BandType; const aCall: string; const aCountry: string;
                aContinent: ContinentType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Band := aBand;
   Result.Mode := Digital;
   Result.ExtMode := eRTTY;
   Result.Callsign := CallString(aCall);
   Result.QTH.CountryID := DXMultiplierString(aCountry);
   Result.QTH.Continent := aContinent;
end;

(* The points ScoreQSO gives an entrant in European Russia (UA, Europe). *)
function PointsFor(aBand: BandType; const aCall: string; const aCountry: string;
                   aContinent: ContinentType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := MakeRus(RusStation('UA', Europe));
   try
      qso := RusQso(aBand, aCall, aCountry, aContinent);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   IDENTITY
   --------------------------------------------------------------------------- *)

procedure TContestRusWWDigiTests.Test_RusWWDigiIdentity;
var
   h: TContestHandle;
   identity: TContestBase;
   legacy: integer;
begin
   BeginTest('Test_RusWWDigiIdentity');
   CheckTrue(FindContestById('RUS-WW-DIGI', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestRusWWDigi, 'to its class');
   CheckEquals('RUS-WW-DIGI', ContestId(h), 'the stored id');
   CheckFalse(ContestLegacyNumber(h, legacy), 'a new contest has no legacy number');
   identity := ContestIdentity(h);
   CheckEquals('Russian WW Digital Contest', identity.DisplayName, 'display name');
   CheckEquals('Russian WW Digital Contest', identity.FriendlyName, 'friendly name');
   (* Every header example: "CONTEST: RUS-WW-DIGI". *)
   CheckEquals('RUS-WW-DIGI', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('RUS-WW-DIGI', identity.ADIFContestId, 'ADIF CONTEST_ID -- its own id');
   CheckEquals('russian', identity.DomesticFileName, 'the oblast list');
   CheckEquals('', identity.SubmissionEmail, 'the current rules name no address');
   (* "repeated contacts are permitted on different bands and different
      modes"; multipliers "on each mode and each band". *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode, cfMultByBand, cfMultByMode,
                               cfCountsDomesticCountries],
             'QSOs and multipliers per band and mode; Russia is a DXCC multiplier too');
   CheckTrue(ContestUsesDomesticFile(identity), 'the oblast is looked up in russian.dom');
   CheckTrue(ContestHasDomesticMultiplier(identity), 'the oblast is a multiplier');
   CheckTrue(identity.HasDXMultiplier, 'the DXCC country is a multiplier');
   CheckFalse(identity.HasZoneMultiplier, 'no zone multiplier');
   CheckFalse(identity.HasPrefixMultiplier, 'no prefix multiplier');
   CheckFalse(identity.IsUSQSOParty, 'no QSO party');
end;

(* "Bands: 160 m, 80 m, 40 m, 20 m, 15 m, 10 m." "Types of modulation:
   RTTY45, BPSK63." *)
procedure TContestRusWWDigiTests.Test_RusWWDigiBandsAndModes;
var
   identity: TContestBase;
   b: BandType;
   m: ModeType;
   expected: boolean;
begin
   BeginTest('Test_RusWWDigiBandsAndModes');
   identity := ContestIdentity(RusHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band160, Band80, Band40, Band20, Band15, Band10];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when one of the six');
      end;
   for m := Low(ModeType) to High(ModeType) do
      begin
      CheckTrue(identity.RunsInMode(m) = (m = Digital),
                'mode ' + IntToStr(Ord(m)) + ': digital only');
      end;

   CheckTrue(ContestCreditsMode(identity, Digital, eRTTY), 'RTTY is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eRTTY_R), 'reverse RTTY is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, ePSK63), 'BPSK63 is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eNoMode), 'digital with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eData), 'generic data is credited');
   CheckFalse(ContestCreditsMode(identity, Digital, ePSK31), 'PSK31 is not');
   CheckFalse(ContestCreditsMode(identity, Digital, eFT8), 'FT8 is not');
   CheckFalse(ContestCreditsMode(identity, Digital, eFT4), 'FT4 is not');
   CheckFalse(ContestCreditsMode(identity, CW, eCW), 'CW is not');
   CheckFalse(ContestCreditsMode(identity, Phone, eUSB), 'phone is not');
   CheckFalse(ContestCreditsMode(identity, FM, eFM), 'FM is not');

   CheckEquals(0, PointsFor(Band30, 'DL1ABC', 'DL', Europe), 'a 30 m QSO scores 0');
   CheckEquals(0, PointsFor(Band6, 'DL1ABC', 'DL', Europe), 'a 6 m QSO scores 0');
end;

(* ---------------------------------------------------------------------------
   POINTS
   --------------------------------------------------------------------------- *)

(* "Each contact between stations on 20, 15 and 10 m is worth: inside the
   country - 1 point; with other country - 3 points; with other continents -
   5 points ... The points on 160, 80 and 40 m are doubled." For an entrant
   in European Russia. *)
procedure TContestRusWWDigiTests.Test_RusWWDigiPointsEveryRow;
var
   b: BandType;
begin
   BeginTest('Test_RusWWDigiPointsEveryRow');
   for b in [Band20, Band15, Band10] do
      begin
      CheckEquals(1, PointsFor(b, 'RA3ABC', 'UA', Europe), 'inside the country, band ' + IntToStr(Ord(b)));
      CheckEquals(3, PointsFor(b, 'DL1ABC', 'DL', Europe), 'another country, band ' + IntToStr(Ord(b)));
      CheckEquals(5, PointsFor(b, 'W1AW', 'K', NorthAmerica), 'another continent, band ' + IntToStr(Ord(b)));
      end;
   for b in [Band160, Band80, Band40] do
      begin
      CheckEquals(2, PointsFor(b, 'RA3ABC', 'UA', Europe), 'inside the country doubled, band ' + IntToStr(Ord(b)));
      CheckEquals(6, PointsFor(b, 'DL1ABC', 'DL', Europe), 'another country doubled, band ' + IntToStr(Ord(b)));
      CheckEquals(10, PointsFor(b, 'W1AW', 'K', NorthAmerica), 'another continent doubled, band ' + IntToStr(Ord(b)));
      end;

   (* "Country" is the DXCC entity: Asiatic Russia is another entity on
      another continent for a European Russian entrant. *)
   CheckEquals(5, PointsFor(Band20, 'RA9ABC', 'UA9', Asia), 'UA working UA9: another continent');
end;

(* "with QRP-stations - 5 points"; "SOQRP - is necessary to indicate in your
   call /QRP". QRP wins over the country, and is doubled like every row. *)
procedure TContestRusWWDigiTests.Test_RusWWDigiQRPStation;
begin
   BeginTest('Test_RusWWDigiQRPStation');
   CheckEquals(5, PointsFor(Band20, 'RA3ABC/QRP', 'UA', Europe), 'a QRP station inside the country');
   CheckEquals(5, PointsFor(Band20, 'DL1ABC/QRP', 'DL', Europe), 'a QRP station of another country');
   CheckEquals(10, PointsFor(Band40, 'RA3ABC/QRP', 'UA', Europe), 'QRP doubled on 40 m');
   CheckEquals(1, PointsFor(Band20, 'RA3QRP', 'UA', Europe), 'QRP inside the call is not /QRP');

   CheckTrue(TContestRusWWDigi.CallIsQRP(' ra3abc/qrp '), 'any case, blanks around');
   CheckFalse(TContestRusWWDigi.CallIsQRP('/QRP'), 'no call before it');
   CheckFalse(TContestRusWWDigi.CallIsQRP('RA3ABC/P'), '/P is not /QRP');
   CheckFalse(TContestRusWWDigi.CallIsQRP(''), 'nothing');
end;

(* ---------------------------------------------------------------------------
   MULTIPLIERS
   --------------------------------------------------------------------------- *)

(* "The multiplier are the countries according to the list of DXCC and
   Russian areas" -- every country, Russia's own entities among them, on the
   DXCC (ARRL) list. *)
procedure TContestRusWWDigiTests.Test_RusWWDigiDXMultiplierIsEveryDXCCCountry;
var
   identity: TContestBase;
   key: DXMultiplierString;
begin
   BeginTest('Test_RusWWDigiDXMultiplierIsEveryDXCCCountry');
   identity := ContestIdentity(RusHandle);
   CheckTrue(identity.CountryMode = ARRLCountryMode, 'the DXCC list, not CTY.DAT''s DXCC + WAE');
   CheckTrue(identity.DXMultiplierKey(RusQso(Band20, 'DL1ABC', 'DL', Europe), key), 'DL is a key');
   CheckEquals('DL', string(key), 'its key is its country');
   CheckTrue(identity.DXMultiplierKey(RusQso(Band20, 'RA3ABC', 'UA', Europe), key), 'UA is a key');
   CheckEquals('UA', string(key), 'European Russia is a DXCC multiplier');
   CheckTrue(identity.DXMultiplierKey(RusQso(Band20, 'RA9ABC', 'UA9', Asia), key), 'UA9 is a key');
   CheckEquals('UA9', string(key), 'Asiatic Russia is a DXCC multiplier');
end;

(* ---------------------------------------------------------------------------
   THE EXCHANGE
   --------------------------------------------------------------------------- *)

var
   GAsked: string;

function StubParse(const aHelper: string; const aText: string;
                   var aExch: ContestExchange): boolean;
begin
   GAsked := aHelper;
   Result := True;
end;

function StubIsDomesticQTH(const aQTH: string): boolean;
begin
   Result := False;
end;

(* "Participants from Russia ... should send RS,RST(Q) plus 2-letter
   abbreviation of Russian Area (oblast) Code ... Participants from other
   countries ... should send RS,RST(Q) plus QSO number": ONE format reads
   either. *)
procedure TContestRusWWDigiTests.Test_RusWWDigiParseRoute;
var
   contestObject: TContestBase;
   session: TReceivedExchangeSession;
   exch: ContestExchange;
   msg: string;
begin
   BeginTest('Test_RusWWDigiParseRoute');
   session := Default(TReceivedExchangeSession);
   session.Parsers := StubExchangeParsers(@StubParse);
   session.IsDomesticQTH := @StubIsDomesticQTH;
   contestObject := MakeRus(RusStation('UA', Europe));
   try
      GAsked := '';
      exch := Default(ContestExchange);
      CheckTrue(contestObject.ParseReceivedExchange('599 MA', session, exch, msg), '599 MA');
      CheckEquals('ParseRSTDomesticQTHOrQSONumber', GAsked, 'an oblast: the oblast-or-serial format');
      GAsked := '';
      exch := Default(ContestExchange);
      CheckTrue(contestObject.ParseReceivedExchange('599 001', session, exch, msg), '599 001');
      CheckEquals('ParseRSTDomesticQTHOrQSONumber', GAsked, 'a serial: the same format');
   finally
      contestObject.Free;
   end;
end;

(* A Russian call's oblast pre-fills (the one rule, Q50); any other call's
   exchange is a serial, which is not pre-filled. *)
procedure TContestRusWWDigiTests.Test_RusWWDigiInitialExchange;
var
   identity: TContestBase;
   answer: string;
begin
   BeginTest('Test_RusWWDigiInitialExchange');
   identity := ContestIdentity(RusHandle);
   CheckTrue(identity.InitialExchangeFromCall('UA3ABC', 'UA', answer), 'a Russian call pre-fills');
   CheckTrue(answer <> '', 'with its oblast');
   CheckFalse(identity.InitialExchangeFromCall('DL1ABC', 'DL', answer), 'a German call does not');
   CheckFalse(identity.InitialExchangeFromCall('UA3ABC', '', answer), 'no country, no oblast');
end;

(* ---------------------------------------------------------------------------
   EXPORT AND SCHEDULE
   --------------------------------------------------------------------------- *)

(* The superseded rules: "RTTY - RY, BPSK63 - PM"; the current text is
   silent. *)
procedure TContestRusWWDigiTests.Test_RusWWDigiCabrilloModeColumn;
var
   identity: TContestBase;
begin
   BeginTest('Test_RusWWDigiCabrilloModeColumn');
   identity := ContestIdentity(RusHandle);
   CheckEquals('RY', identity.CabrilloModeString(Digital, eRTTY), 'RTTY');
   CheckEquals('RY', identity.CabrilloModeString(Digital, eRTTY_R), 'reverse RTTY');
   CheckEquals('RY', identity.CabrilloModeString(Digital, eNoMode), 'digital with no submode');
   CheckEquals('PM', identity.CabrilloModeString(Digital, ePSK63), 'BPSK63');
end;

(* "13th RUS-WW-DIGI 2026: 12:00 UTC 03.10.2026 - 11:59 UTC 04.10.2026";
   "14th RUS-WW-DIGI 2027: 12:00 UTC 02.10.2027". *)
procedure TContestRusWWDigiTests.Test_RusWWDigiSchedule;
var
   s: TContestSchedule;
   err: string;
   key: TDateTime;
begin
   BeginTest('Test_RusWWDigiSchedule');
   CheckTrue(TryParseContestSchedule(ContestIdentity(RusHandle).Schedule, s, err),
             'the schedule parses (' + err + ')');
   CheckTrue(TryScheduleSortKey(s, EncodeDateTime(2026, 9, 1, 0, 0, 0, 0), key), '2026 key');
   CheckTrue(Abs(key - EncodeDateTime(2026, 10, 3, 12, 0, 0, 0)) < OneSecond,
             '2026: Saturday 3 October 12:00 UTC');
   CheckTrue(TryScheduleSortKey(s, EncodeDateTime(2026, 10, 4, 11, 58, 0, 0), key), 'running');
   CheckTrue(Abs(key - EncodeDateTime(2026, 10, 4, 11, 58, 0, 0)) < OneSecond,
             'Sunday 11:58 UTC is inside the period');
   CheckTrue(TryScheduleSortKey(s, EncodeDateTime(2026, 10, 4, 12, 0, 0, 0), key), 'ended');
   CheckTrue(Abs(key - EncodeDateTime(2027, 10, 2, 12, 0, 0, 0)) < OneSecond,
             'after 2026: Saturday 2 October 2027 12:00 UTC');
end;

procedure TContestRusWWDigiTests.RunAllTests;
begin
   Test_RusWWDigiIdentity;
   Test_RusWWDigiBandsAndModes;
   Test_RusWWDigiPointsEveryRow;
   Test_RusWWDigiQRPStation;
   Test_RusWWDigiDXMultiplierIsEveryDXCCCountry;
   Test_RusWWDigiParseRoute;
   Test_RusWWDigiInitialExchange;
   Test_RusWWDigiCabrilloModeColumn;
   Test_RusWWDigiSchedule;
end;

end.

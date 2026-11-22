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

(* WRT, THE WEEKLY RTTY TEST -- added 2026-11-22 (issue 25). The rules are
  docs/ContestRules/WRT/rules.md (with the organizers' WRT.udc beside it);
  each test below quotes the rule it holds.

  WHAT IS PINNED
    * its identity: the id, no legacy number, the names, no domestic file,
      the flags;
    * its bands (80/40/20/15/10 m) and its mode (RTTY);
    * one point per credited QSO, none off the bands or the mode;
    * the multiplier: the worked call, on the prefix sheet, and no other
      kind -- including the KNOWN six-character limit of the key;
    * the schedule, against known Fridays;
    * the parse: the name-and-domestic-or-DX-QTH format;
    * the Cabrillo and ADIF columns, the fields the rules name in their
      order (the rules give no QSO-line example);
    * through the REAL engine: a call counts once per SESSION, a station may
      be worked once per BAND. *)
unit uTestContestWRT;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestWRTTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_WRTIdentity;
      procedure Test_WRTBandsAndMode;
      procedure Test_WRTOnePointPerQSO;
      procedure Test_WRTCallIsTheMultiplier;
      procedure Test_WRTScheduleIsEveryFridayMorningUTC;
      procedure Test_WRTParseRoute;
      procedure Test_WRTExportColumns;
      procedure Test_WRTRealEngineCallsOncePerSessionDupesPerBand;
   end;

implementation

uses
   Classes,
   SysUtils,
   DateUtils,
   VC,
   uSettingsModel,
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uContestSchedule,
   uContestWRT,
   uTestContestObjects,
   uTestExchangeParserStub,
   uTestRegisteredContests,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   MainUnit;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

function WRTHandle: TContestHandle;
begin
   if not FindContestById(WRT_CONTEST_ID, Result) then
      begin
      raise Exception.Create('WRT is not registered');
      end;
end;

function WRTStation(const aMyName: string; const aMyState: string): TStationContext;
begin
   Result := NoStation;
   Result.MyName := aMyName;
   Result.MyState := aMyState;
end;

function MakeWRT(const aStation: TStationContext): TContestBase;
begin
   Result := ContestClassFor(WRTHandle).Create(WRTHandle);
   Result.SetStation(aStation);
end;

function WRTQso(const aCall: string; aBand: BandType; aMode: ModeType;
                aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Callsign := CallString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.Name := 'RON';
   Result.QTHString := 'TN';
end;

(* The points ScoreQSO gives. *)
function PointsFor(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := MakeWRT(WRTStation('TIM', 'PA'));
   try
      qso := WRTQso('WV4P', aBand, aMode, aExtMode);
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

procedure TContestWRTTests.Test_WRTIdentity;
var
   h: TContestHandle;
   identity: TContestBase;
   legacy: integer;
   member: ContestType;
begin
   BeginTest('Test_WRTIdentity');
   CheckTrue(FindContestById('WRT', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestWRT, 'to its class');
   CheckEquals('WRT', ContestId(h), 'the stored id');
   CheckFalse(ContestLegacyNumber(h, legacy), 'a new contest has no legacy number');
   CheckFalse(TryLegacyContestOf(ContestIdentity(h), member), 'and no legacy member');
   identity := ContestIdentity(h);
   CheckEquals('Weekly RTTY Test', identity.DisplayName, 'display name');
   CheckEquals('Weekly RTTY Test', identity.FriendlyName, 'friendly name');
   (* The organizers' UDC: CabrilloName = WRT; DXLog: CABRILLO_CONTEST_NAME=WRT. *)
   CheckEquals('WRT', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('WRT', identity.ADIFContestId, 'ADIF CONTEST_ID -- ADIF lists none');
   CheckEquals('', identity.DomesticFileName, 'no domestic file');
   CheckEquals('', identity.SubmissionEmail, 'results go to 3830scores.com');
   (* QSOs once per band (NY4I, issue 25: DupeType = 2); the call
      multiplier once per session; "Hamscore real-time scoring is
      supported". *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfRTCCapable], 'QSOs per band, RTC');
   CheckTrue(identity.QSOByBand, 'a station may be worked once per band');
   CheckFalse(identity.QSOByMode, 'RTTY only: not by mode');
   CheckFalse(identity.MultByBand, 'a call counts once per session, not per band');
   CheckFalse(identity.MultByMode, 'nor per mode');
   CheckFalse(identity.IsUSQSOParty, 'no QSO party');
   CheckTrue(identity.ExchangeCarriesDomesticQTH, 'the exchange carries a state or DX prefix');
end;

(* "10, 15, 20, 40, and 80 Meter bands"; RTTY (the UDC's Mode = RTTY). *)
procedure TContestWRTTests.Test_WRTBandsAndMode;
var
   identity: TContestBase;
   b: BandType;
   m: ModeType;
   expected: boolean;
begin
   BeginTest('Test_WRTBandsAndMode');
   identity := ContestIdentity(WRTHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band80, Band40, Band20, Band15, Band10];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when one of the five');
      end;
   for m := Low(ModeType) to High(ModeType) do
      begin
      CheckTrue(identity.RunsInMode(m) = (m = Digital),
                'mode ' + IntToStr(Ord(m)) + ': RTTY only');
      end;

   CheckTrue(ContestCreditsMode(identity, Digital, eRTTY), 'RTTY is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eRTTY_R), 'reverse RTTY is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eNoMode), 'digital with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eData), 'generic data is credited');
   CheckFalse(ContestCreditsMode(identity, Digital, eFT8), 'FT8 is not');
   CheckFalse(ContestCreditsMode(identity, Digital, ePSK31), 'PSK is not');
   CheckFalse(ContestCreditsMode(identity, CW, eCW), 'CW is not');
   CheckFalse(ContestCreditsMode(identity, Phone, eUSB), 'phone is not');
   CheckFalse(ContestCreditsMode(identity, FM, eFM), 'FM is not');
end;

(* ---------------------------------------------------------------------------
   POINTS
   --------------------------------------------------------------------------- *)

(* "1 Point per QSO" -- on every credited band; 0 off the bands or the
   mode (the automatic X-QSO). *)
procedure TContestWRTTests.Test_WRTOnePointPerQSO;
var
   b: BandType;
begin
   BeginTest('Test_WRTOnePointPerQSO');
   for b in [Band80, Band40, Band20, Band15, Band10] do
      begin
      CheckEquals(1, PointsFor(b, Digital, eRTTY), 'RTTY, band ' + IntToStr(Ord(b)));
      end;
   CheckEquals(1, PointsFor(Band20, Digital, eNoMode), 'digital with no submode');
   CheckEquals(0, PointsFor(Band160, Digital, eRTTY), 'a 160 m QSO scores 0');
   CheckEquals(0, PointsFor(Band30, Digital, eRTTY), 'a 30 m QSO scores 0');
   CheckEquals(0, PointsFor(Band6, Digital, eRTTY), 'a 6 m QSO scores 0');
   CheckEquals(0, PointsFor(Band20, CW, eCW), 'a CW QSO scores 0');
   CheckEquals(0, PointsFor(Band20, Digital, eFT8), 'an FT8 QSO scores 0');
end;

(* ---------------------------------------------------------------------------
   THE MULTIPLIER
   --------------------------------------------------------------------------- *)

(* "Each unique call (once per session) is a multiplier". *)
procedure TContestWRTTests.Test_WRTCallIsTheMultiplier;
var
   identity: TContestBase;
   key: PrefixMultiplierString;
begin
   BeginTest('Test_WRTCallIsTheMultiplier');
   identity := ContestIdentity(WRTHandle);
   CheckTrue(ContestHasPrefixMultiplier(identity), 'the call is on the prefix sheet');
   CheckFalse(identity.HasDXMultiplier, 'no DX multiplier');
   CheckFalse(identity.HasZoneMultiplier, 'no zone multiplier');
   CheckFalse(ContestUsesDomesticFile(identity), 'no domestic file');
   CheckFalse(ContestHasDomesticMultiplier(identity), 'the state is no multiplier');

   CheckTrue(ContestPrefixMultiplierKey(identity, WRTQso('N3QE', Band20, Digital, eRTTY), key),
             'every QSO gives a key');
   CheckEquals('N3QE', string(key), 'the key is the worked call');
   CheckTrue(ContestPrefixMultiplierKey(identity, WRTQso('WV4P', Band40, Digital, eRTTY), key),
             'a second call');
   CheckEquals('WV4P', string(key), 'its own key');

   (* THE KNOWN LIMIT (the class header; OPEN, the owner's decision): the key
      is a string[6], so a call longer than six characters is cut, and two
      such calls sharing their first six count as one. Pinned as it is today,
      so the fix that widens the key moves this line on purpose. *)
   CheckTrue(ContestPrefixMultiplierKey(identity, WRTQso('WB9ABCD', Band20, Digital, eRTTY), key),
             'a seven-character call');
   CheckEquals('WB9ABC', string(key), 'KNOWN LIMIT: cut to six characters');
end;

(* ---------------------------------------------------------------------------
   SCHEDULE
   --------------------------------------------------------------------------- *)

(* "Held every Thursday night, 0145-0215Z (Friday UTC)". 2026-11-26 is a
   Thursday; the period is Friday 2026-11-27 01:45-02:15 UTC. *)
procedure TContestWRTTests.Test_WRTScheduleIsEveryFridayMorningUTC;
var
   schedule: TContestSchedule;
   parseError: string;
   key: TDateTime;
   atUTC: TDateTime;
begin
   BeginTest('Test_WRTScheduleIsEveryFridayMorningUTC');
   CheckTrue(TryParseContestSchedule(ContestIdentity(WRTHandle).Schedule, schedule, parseError),
             'the schedule parses: ' + parseError);

   atUTC := EncodeDateTime(2026, 11, 26, 12, 0, 0, 0);
   CheckTrue(TryScheduleSortKey(schedule, atUTC, key), 'Thursday noon has a key');
   CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDateTime(2026, 11, 27, 1, 45, 0, 0)),
               FormatDateTime('yyyy-mm-dd hh:nn', key), 'the next start is Friday 01:45 UTC');

   atUTC := EncodeDateTime(2026, 11, 27, 2, 0, 0, 0);
   CheckTrue(TryScheduleSortKey(schedule, atUTC, key), 'running at 02:00');
   CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', atUTC),
               FormatDateTime('yyyy-mm-dd hh:nn', key), 'a running period keys on the instant asked');

   atUTC := EncodeDateTime(2026, 11, 27, 2, 15, 0, 0);
   CheckTrue(TryScheduleSortKey(schedule, atUTC, key), 'over at 02:15');
   CheckEquals(FormatDateTime('yyyy-mm-dd hh:nn', EncodeDateTime(2026, 12, 4, 1, 45, 0, 0)),
               FormatDateTime('yyyy-mm-dd hh:nn', key), 'thirty minutes, then next Friday');
end;

(* ---------------------------------------------------------------------------
   PARSE
   --------------------------------------------------------------------------- *)

var
   GAsked: string;
   GAskedText: string;

function StubParse(const aHelper: string; const aText: string;
                   var aExch: ContestExchange): boolean;
begin
   GAsked := aHelper;
   GAskedText := aText;
   Result := True;
end;

function StubIsDomesticQTH(const aQTH: string): boolean;
begin
   Result := False;
end;

function StubSession: TReceivedExchangeSession;
begin
   Result := Default(TReceivedExchangeSession);
   Result.Parsers := StubExchangeParsers(@StubParse);
   Result.IsDomesticQTH := @StubIsDomesticQTH;
end;

(* "W/VE - Name and State; DX - Name and Country Prefix". *)
procedure TContestWRTTests.Test_WRTParseRoute;
var
   contestObject: TContestBase;
   exch: ContestExchange;
   msg: string;
begin
   BeginTest('Test_WRTParseRoute');
   GAsked := '';
   GAskedText := '';
   exch := Default(ContestExchange);
   contestObject := MakeWRT(WRTStation('TIM', 'PA'));
   try
      CheckTrue(contestObject.ParseReceivedExchange('RON TN', StubSession, exch, msg), 'RON TN');
      CheckEquals('ParseNameAndDomesticOrDXQTH', GAsked, 'the name-and-state-or-DX format');
      CheckEquals('RON TN', GAskedText, 'with the text as typed');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   EXPORT
   --------------------------------------------------------------------------- *)

(* THE RULES GIVE NO QSO-LINE EXAMPLE. The organizers' UDC lays the line out
   as "SentExchPart1, 10, SentExchPart2, 10, CallSign, 13, Name, 10,
   Exchange1, 4": my name, my state, his call, his name, his state -- the
   fields in that order are what is pinned. A DX station's column is the
   country prefix it sent, as received. *)
procedure TContestWRTTests.Test_WRTExportColumns;
var
   contestObject: TContestBase;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
begin
   BeginTest('Test_WRTExportColumns');
   contestObject := MakeWRT(WRTStation('TIM', 'PA'));
   try
      my := Default(TMyStationExchange);
      my.MyName := 'TIM';
      my.MyState := 'PA';
      qso := WRTQso('WV4P', Band20, Digital, eRTTY);
      ctx := Default(TCabrilloQSOContext);
      ctx.HisQTH := 'TN';

      CheckEquals('RY', contestObject.CabrilloModeString(Digital, eRTTY), 'RTTY is RY');
      CheckEquals('  TIM        PA  ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent: my name, my state');
      CheckEquals('  RON        TN  ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: his name, his state');
      CheckEquals('  TIM        PA  ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: my name, my state');

      (* A DX station: its name and its country prefix. *)
      qso := WRTQso('DL1ABC', Band20, Digital, eRTTY);
      qso.Name := 'KLAUS';
      qso.QTHString := 'DL';
      ctx.HisQTH := 'DL';
      CheckEquals('  KLAUS      DL  ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received from DX: his name, his country prefix');
      CheckEquals('KLAUS DL', contestObject.CanonicalReceivedExchange(qso),
                  'the canonical received exchange');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay, the multiplier sheet and the dupe sheet
   --------------------------------------------------------------------------- *)

(* "Each unique call (once per session) is a multiplier" and DupeType = 2,
   "Each band (stations may be worked once on each band)" (NY4I, issue 25).
   Through MainUnit.ParametersOkay -- the routine live entry's Enter calls --
   and the real sheets, as LogContact does. The engine's flags come FROM THE
   CLASS, as FCONTEST.ApplyContestTraits sets them. *)
procedure TContestWRTTests.Test_WRTRealEngineCallsOncePerSessionDupesPerBand;
var
   savedContest: TContestHandle;
   savedQsoByBand: boolean;
   savedQsoByMode: boolean;
   savedMultByBand: boolean;
   savedMultByMode: boolean;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   identity: TContestBase;
   ctyPath: string;
   rx: ContestExchange;
   accepted: boolean;
   index: integer;

   function Enter(const aCall: string; const aExch: string; aBand: BandType;
                  var aRX: ContestExchange): boolean;
   begin
      aRX := Default(ContestExchange);
      ActiveMode := Digital;
      CallWindowString := CallString(aCall);
      ExchangeErrorMessage := '';
      Result := ParametersOkay(CallString(aCall), Str40(aExch), aBand, Digital,
                               14083000, aRX);
      aRX.ceRecordKind := rkQSO;
      aRX.ceContest := Contest;
      if Result then
         begin
         Sheet.SetMultFlags(aRX);
         Sheet.AddQSOToSheets(@aRX, False);
         AddQSOToDupeSheets(aRX, False);
         end;
   end;

begin
   BeginTest('Test_WRTRealEngineCallsOncePerSessionDupesPerBand');
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   savedContest := Contest;
   savedQsoByBand := Settings.Qso.ByBand;
   savedQsoByMode := Settings.Qso.ByMode;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedTable := DomQTHTable;
   (* AN EMPTY DOMESTIC TABLE: the contest loads no file, and a W/VE call's
      state is taken as typed (GetDomQTH answers True for a contest with no
      domestic multiplier) -- the table is never consulted, but it is never
      nil either. *)
   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      Contest := WRTHandle;
      ReleaseActiveContest;
      identity := ContestIdentity(WRTHandle);
      Settings.Qso.ByBand := identity.QSOByBand;
      Settings.Qso.ByMode := identity.QSOByMode;
      Settings.Mult.ByBand := identity.MultByBand;
      Settings.Mult.ByMode := identity.MultByMode;
      mo.ClearAllMults;

      accepted := Enter('N3QE', 'TIM PA', Band20, rx);
      CheckTrue(accepted, 'TIM PA is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('TIM', string(rx.Name), 'the name');
      CheckEquals('PA', string(rx.QTHString), 'the state');
      CheckEquals('N3QE', string(rx.Prefix), 'the multiplier key is the call');
      CheckTrue(rx.PrefixMult, 'N3QE is a new multiplier');
      CheckEquals(1, Integer(rx.QSOPoints), 'one point');

      CheckTrue(CallsignsList.CallsignIsDupe('N3QE', Band20, Digital, index),
                'N3QE again on 20 m is a dupe');
      CheckFalse(CallsignsList.CallsignIsDupe('N3QE', Band40, Digital, index),
                 'N3QE on 40 m is not: once per band');

      accepted := Enter('N3QE', 'TIM PA', Band40, rx);
      CheckTrue(accepted, 'N3QE on 40 m is taken');
      CheckFalse(rx.PrefixMult, 'N3QE on 40 m is no new multiplier: once per session');
      CheckEquals(1, Integer(rx.QSOPoints), 'but it is a QSO, one point');

      accepted := Enter('DL1ABC', 'KLAUS DL', Band40, rx);
      CheckTrue(accepted, 'a DX station''s name and country prefix are taken: ' +
                          string(ExchangeErrorMessage));
      CheckEquals('DL', string(rx.QTHString), 'the country prefix');
      CheckTrue(rx.PrefixMult, 'DL1ABC is a new multiplier');
      CheckFalse(rx.DomesticMult, 'no domestic multiplier');
      CheckFalse(rx.DXMult, 'no DX multiplier');
   finally
      mo.ClearAllMults;
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      CallWindowString := savedCallWindow;
      ActiveMode := savedActiveMode;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      ExchangeErrorMessage := '';
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

procedure TContestWRTTests.RunAllTests;
begin
   Test_WRTIdentity;
   Test_WRTBandsAndMode;
   Test_WRTOnePointPerQSO;
   Test_WRTCallIsTheMultiplier;
   Test_WRTScheduleIsEveryFridayMorningUTC;
   Test_WRTParseRoute;
   Test_WRTExportColumns;
   Test_WRTRealEngineCallsOncePerSessionDupesPerBand;
end;

end.

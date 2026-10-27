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

(* THE OKLAHOMA QSO PARTY -- added 2026-10-26 (#126), registered by its id
  (OK-QSO-PARTY). The rules are docs/ContestRules/QSOParties/Oklahoma/
  (OK-QSO-PARTY-Rules.txt, "The 2026 Oklahoma QSO Party"; the overview page;
  the county table); NY4I's decisions are on #126. Each test below quotes
  the rule it holds. Written from ADDING_A_CONTEST.md Part A5, copying
  uTestContestGeorgiaQP's shape; nothing is assumed from another party's
  rules.

  WHAT IS PINNED
    * its identity: the id, no legacy number, refused on multi-op, the
      names, the files, the flags, the party base and what it inherits;
    * its bands, and its points in every mode through ScoreQSO; only RTTY,
      PSK and JS8 count as digital -- every other digital submode is an
      automatic X-QSO;
    * the in-state entrant's multipliers (the shipped oklahoma.dom through
      the real loader): the 77 counties, the 50 states with OK among them
      and DC counted as MD, the 13 provinces and territories;
    * the in-state DX multiplier (DXCC but K, VE, KH6 and KL) and none
      outside Oklahoma;
    * the out-of-state entrant's multipliers and the host-area rule, against
      the shipped oklahoma_cty.dom;
    * a county line of up to four, the final score's formula, no bonus
      (#133), no power multiplier;
    * a DX entrant sends its own prefix (the party base's SentLocation);
    * the two .dom files against the sponsor's county table;
    * the dupe rules and the mobile's new county;
    * the Cabrillo lines against the rules' own example;
    * THROUGH THE REAL ENGINE (ParametersOkay and the multiplier sheet):
      an out-of-state entrant, then an in-state one. *)
unit uTestContestOklahomaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestOklahomaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_OklahomaIdentity;
      procedure Test_OklahomaBands;
      procedure Test_OklahomaPoints;
      procedure Test_OklahomaOnlyRTTYPSKAndJS8AreDigital;
      procedure Test_OklahomaInStateMultipliers;
      procedure Test_OklahomaInStateDXMultiplier;
      procedure Test_OklahomaOutOfStateWorksOnlyOklahoma;
      procedure Test_OklahomaCountyLineIsUpToFourCounties;
      procedure Test_OklahomaDupes;
      procedure Test_OklahomaScoreIsPointsTimesMultipliers;
      procedure Test_OklahomaCountyFileIsTheSponsorsTable;
      procedure Test_OklahomaInStateFileIsTheRulesMultipliers;
      procedure Test_OklahomaCabrilloLineIsTheRulesExample;
      procedure Test_OklahomaRealEngine;
   end;

implementation

uses
   (* cpHIGH. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uContestStateQSOPartyBase,
   uContestOklahomaQP,
   uDomFileKeys,
   uAppStrings,
   uTR4WStrings,
   uPendingCounties,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   uTestContestObjects,
   uTestExchangeParserStub,
   (* TryLegacyContestOf -- the frozen enum, reached only through it. *)
   uTestRegisteredContests,
   (* A shipped .dom through the real loader, its INCLUDEs followed. *)
   uTestShippedDom,
   (* The party questions every party test asks one way. *)
   uTestQSOPartyRules,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   FCONTEST,
   (* BuildSingleQsoCabrilloLine -- the X-QSO: prefix, Q119. *)
   uCabrillo,
   MainUnit;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

const
   (* "The 13 Canadian Provinces/Territories - NS, NB, NL, PE, QC, ON, MB, SK,
      AB, BC, NT, NU, YT" -- every one the rules list. *)
   RULES_CANADIAN: array[0..12] of string = (
      'NS', 'NB', 'NL', 'PE', 'QC', 'ON', 'MB', 'SK', 'AB', 'BC', 'NT', 'NU', 'YT');

   (* "Only PSK, RTTY and JS8Call are allowed as digital contacts" (NY4I on
      #126), and eNoMode / eData, which mean "some submode of Digital". *)
   RTTY_PSK_AND_JS8 = [eNoMode, eData, eRTTY, eRTTY_R, ePSK31, ePSK63, ePSK_R, eJS8];

function OklahomaHandle: TContestHandle;
begin
   if not FindContestById(OK_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('OK-QSO-PARTY is not registered');
      end;
end;

function MakeOklahoma(const aStation: TStationContext): TContestBase;
begin
   Result := Make(OklahomaHandle, aStation);
end;

(* An Oklahoma station (Muskogee County, the rules' K5CM) or a Texas one. The
   table knows every QTH (uTestContestObjects.WithHostAreaTable): a test about
   POINTS states that every QSO it scores is with a host-area station. The
   host-area rule itself is Test_OklahomaOutOfStateWorksOnlyOklahoma's,
   against the real county file. *)
function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'MUS';
      end
   else
      begin
      Result.MyState := 'TX';
      end;
   Result.MyCountry := 'K';
end;

(* A DX ENTRANT: no MY STATE, and the country FCONTEST derives from MY CALL. *)
function DXStation(const aCountry: string): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := False;
   Result.MyState := '';
   Result.MyCountry := CallString(aCountry);
end;

function OklahomaQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType;
                     const aQTH: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'K5XYZ';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := ShortString(aQTH);
end;

(* The points ScoreQSO gives -- the ONE public scoring entry. *)
function PointsFor(aStation: TStationContext; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType; const aQTH: string): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := MakeOklahoma(aStation);
   try
      qso := OklahomaQso(aBand, aMode, aExtMode, aQTH);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* THE SPONSOR'S COUNTY TABLE as committed beside the rules:
   OK-QSO-PARTY-Counties.txt, one county a line, "ABC Name (n)", after the
   '====' rule. Filled as ABC=Name. *)
procedure ReadSponsorCountyTable(aCounties: TStringList);
var
   lines: TStringList;
   path: string;
   line: string;
   i: integer;
   open: integer;
   inTable: boolean;
begin
   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
           '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
           'QSOParties' + PathDelim + 'Oklahoma' + PathDelim + 'OK-QSO-PARTY-Counties.txt';
   lines := TStringList.Create;
   try
      lines.LoadFromFile(path);
      inTable := False;
      for i := 0 to lines.Count - 1 do
         begin
         line := Trim(lines[i]);
         if Pos('=====', line) = 1 then
            begin
            inTable := True;
            Continue;
            end;
         if (not inTable) or (line = '') then
            begin
            Continue;
            end;
         open := Pos(' (', line);
         aCounties.Add(Copy(line, 1, 3) + '=' + Copy(line, 5, open - 5));
         end;
   finally
      lines.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   IDENTITY
   --------------------------------------------------------------------------- *)

procedure TContestOklahomaQPTests.Test_OklahomaIdentity;
var
   h: TContestHandle;
   found: TContestHandle;
   identity: TContestBase;
   contestObject: TContestBase;
   member: ContestType;
   legacy: integer;
begin
   BeginTest('Test_OklahomaIdentity');
   CheckEquals('OK-QSO-PARTY', OK_QSO_PARTY_CONTEST_ID, 'the id constant');
   CheckTrue(FindContestById('OK-QSO-PARTY', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestOklahomaQP, 'to its class');
   CheckTrue(TContestOklahomaQP.ClassParent = TContestStateQSOPartyBase,
             'on the state-party base, directly: one host state, its counties, '
             + '"Non Oklahoma stations work only Oklahoma stations"');
   CheckEquals('OK-QSO-PARTY', ContestId(h), 'the stored id');

   identity := ContestIdentity(h);
   CheckFalse(TryLegacyContestOf(identity, member), 'a new contest has no ContestType member');
   CheckTrue(member = DUMMYCONTEST, 'so the walk names none');
   CheckFalse(ContestLegacyNumber(h, legacy), 'and no legacy number');
   CheckFalse(ContestCanUseMultiOp(h), 'and is refused on the multi-op network');

   CheckEquals('Oklahoma QSO Party', identity.DisplayName, 'display name');
   CheckEquals('Oklahoma QSO Party', identity.FriendlyName, 'friendly name');
   (* The rules' example header: "CONTEST: OK-QSO-PARTY". *)
   CheckEquals('OK-QSO-PARTY', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('OK-QSO-PARTY', identity.CabrilloContestName('2026 OKQP K5CM', 'X'),
               'the CONTEST: line, whatever the title');
   CheckEquals('OK-QSO-PARTY', identity.ADIFContestId, 'ADIF CONTEST_ID');
   CheckTrue(identity.WritesADIFContestId, 'export writes it');
   CheckTrue(FindContestByADIFContestId('OK-QSO-PARTY', found), 'import resolves it');
   CheckTrue(found = h, 'to the Oklahoma QSO Party');
   CheckEquals(293, identity.WA7BNMId, 'WA7BNM ref 293');
   CheckEquals(0, identity.QRZRUId, 'no QRZ.RU id');
   (* "Submit logs: https://okqp.contesting.com/" -- no address (NY4I). *)
   CheckEquals('', identity.SubmissionEmail, 'no submission e-mail');
   CheckEquals('OK', identity.HostState, 'host state');
   CheckEquals('OK', identity.QSOPartyArea, 'the New Contest prompt names Oklahoma');
   CheckEquals('oklahoma_cty', identity.DomesticFileName, 'the county file');
   CheckEquals('oklahoma', identity.InStateDomesticFileName, 'the in-state file');
   CheckTrue(identity.IsUSQSOParty, 'a US QSO party');
   CheckTrue(identity.IsActive, 'active');
   CheckTrue(identity.MarksDupes, 'marks dupes');

   (* "Stations may be worked again on each band and mode"; "A Multiplier
      counts once, regardless of the number bands or modes it is worked on";
      "50, and 144 MHz". *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled],
             'dupes per band and mode, multipliers once overall, 6 m and 2 m on');
   CheckTrue(identity.QSOByBand, 'a station may be worked again on another band');
   CheckTrue(identity.QSOByMode, 'and again in another mode');
   CheckFalse(identity.MultByBand, 'a multiplier is NOT counted again per band');
   CheckFalse(identity.MultByMode, 'nor again per mode');
   CheckTrue(identity.VHFBandsEnabled, '6 m and 2 m');

   (* "Oklahoma stations send signal report and county. W/VE stations
      (including KH6/KL7) send signal report and state or province. DX
      stations (including KH2/KP4) send signal report and DXCC prefix." *)
   CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(identity.ExchangeKind),
               'RST and a county, state, province or DXCC prefix');
   CheckEquals(Ord(NoInitialExchange), Ord(identity.InitialExchangeKind), 'no initial exchange');
   CheckTrue(identity.ExchangeCarriesDomesticQTH, 'the exchange carries a domestic QTH');
   CheckTrue(ContestUsesDomesticFile(identity), 'looked up in the domestic file');
   CheckTrue(ContestHasDomesticMultiplier(identity), 'the domestic QTH is the multiplier');

   (* WHAT THE PARTY BASE GIVES IT, pinned here so a base change is seen. *)
   CheckTrue(identity.StripsRoverCountyFromCall, 'a mobile''s /county is stripped live');
   CheckTrue(identity.SplitsRoverCallOnExport,
             'and split on ADIF export ("remove all the /M and /CTY from the calls")');
   CheckTrue(identity.DupeKeyIncludesReceivedQTH,
             '"Oklahoma mobile stations that change counties are considered to be a new station"');
   CheckTrue(identity.WritesADIFCounty, 'CNTY is written');
   CheckEquals(4, (identity as TContestStateQSOPartyBase).CountyLineCountiesMax,
               '"operating on a 2, 3, or 4 county line"');

   (* "Oklahoma stations: ... DXCC countries* (excluding US, Canada, KH6 and
      KL7)"; "Non Oklahoma stations: The 77 Oklahoma counties." *)
   contestObject := MakeOklahoma(StationAt(True));
   try
      CheckTrue(contestObject.HasDXMultiplier, 'in OK: DXCC countries are multipliers');
      CheckTrue(ContestCountryMode(contestObject) = ARRLCountryMode, 'on the DXCC (ARRL) list');
      CheckFalse(contestObject.HasZoneMultiplier, 'in OK: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'in OK: no prefix multiplier');
      CheckEquals(' 5NN MUS', contestObject.CQExchangeDefault(StationAt(True)),
                  'in OK, the CQ exchange sends the county ("signal report and county")');
   finally
      contestObject.Free;
   end;
   contestObject := MakeOklahoma(StationAt(False));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'outside OK: no DX multiplier');
      CheckTrue(ContestCountryMode(contestObject) = CQCountryMode, 'and the CQ list');
      CheckFalse(contestObject.HasZoneMultiplier, 'outside OK: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'outside OK: no prefix multiplier');
      CheckEquals(' 5NN TX', contestObject.CQExchangeDefault(StationAt(False)),
                  'outside OK, the state ("W/VE stations ... state or province")');
      (* "DX stations (including KH2/KP4) send signal report and DXCC
         prefix" -- their own (NY4I). *)
      CheckEquals(' 5NN DL', contestObject.CQExchangeDefault(DXStation('DL')),
                  'a DX entrant with no MY STATE sends its prefix');
      CheckEquals(' 5NN KP4', contestObject.CQExchangeDefault(DXStation('KP4')),
                  'KP4 is a DX entrant too');
   finally
      contestObject.Free;
   end;
end;

(* "Operate only the 3.5, 7, 14, 21, 28, 50, and 144 MHz bands." -- 80, 40,
   20, 15, 10, 6 and 2 m, nothing else: no 160 m, no WARC (NY4I: 2 m is
   credited although WA7BNM and DXLog omit it). An off-band QSO is an
   automatic X-QSO: logged, 0 points, no multiplier. *)
procedure TContestOklahomaQPTests.Test_OklahomaBands;
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_OklahomaBands');
   identity := ContestIdentity(OklahomaHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band80, Band40, Band20, Band15, Band10, Band6, Band2];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when on the rules'' list');
      CheckTrue(ContestCreditsBand(identity, b) = expected,
                'band ' + IntToStr(Ord(b)) + ' through the one seam');
      end;
   CheckEquals(3, PointsFor(StationAt(False), Band80, CW, eCW, 'MUS'), '80 m CW scores');
   CheckEquals(3, PointsFor(StationAt(False), Band10, CW, eCW, 'MUS'), '10 m CW scores');
   CheckEquals(2, PointsFor(StationAt(False), Band6, Phone, eUSB, 'MUS'), '6 m scores');
   CheckEquals(2, PointsFor(StationAt(False), Band2, FM, eFM, 'MUS'), '2 m scores ("144 MHz")');
   CheckEquals(0, PointsFor(StationAt(False), Band160, CW, eCW, 'MUS'), '160 m scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band30, CW, eCW, 'MUS'), '30 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band17, Phone, eUSB, 'MUS'), '17 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band12, CW, eCW, 'MUS'), '12 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band222, FM, eFM, 'MUS'), '222 MHz scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band432, FM, eFM, 'MUS'), '70 cm scores nothing');
end;

(* "Oklahoma stations work anyone / Count two points per phone QSO with any
   station. / Count three points per CW QSO. / Count three points per
   Digital QSO (No FT8/FT4)" and the same three for "Non Oklahoma stations
   work only Oklahoma stations". FM is phone. *)
procedure TContestOklahomaQPTests.Test_OklahomaPoints;
begin
   BeginTest('Test_OklahomaPoints');
   CheckEquals(3, PointsFor(StationAt(False), Band20, CW, eCW, 'MUS'), 'outside OK, CW 3');
   CheckEquals(2, PointsFor(StationAt(False), Band20, Phone, eUSB, 'MUS'), 'outside OK, SSB 2');
   CheckEquals(2, PointsFor(StationAt(False), Band40, Phone, eLSB, 'MUS'), 'outside OK, LSB 2');
   CheckEquals(2, PointsFor(StationAt(False), Band2, FM, eFM, 'TUL'), 'outside OK, FM is phone: 2');
   CheckEquals(3, PointsFor(StationAt(False), Band20, Digital, eRTTY, 'MUS'), 'outside OK, RTTY 3');
   CheckEquals(3, PointsFor(StationAt(False), Band40, Digital, ePSK31, 'MUS'), 'outside OK, PSK 3');
   CheckEquals(3, PointsFor(StationAt(False), Band40, Digital, eJS8, 'MUS'), 'outside OK, JS8 3');
   CheckEquals(3, PointsFor(StationAt(True), Band40, CW, eCW, 'TX'), 'in OK, CW with Texas');
   CheckEquals(2, PointsFor(StationAt(True), Band40, Phone, eLSB, 'ON'), 'in OK, SSB with Ontario');
   CheckEquals(3, PointsFor(StationAt(True), Band20, Digital, eRTTY, 'TUL'), 'in OK, RTTY with Tulsa');
   CheckEquals(3, PointsFor(StationAt(True), Band15, CW, eCW, 'DL'),
               'in OK, a DX station scores ("Oklahoma stations work anyone")');
   CheckEquals(2, PointsFor(StationAt(True), Band15, Phone, eUSB, 'DL'), 'and 2 on phone');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Both, eNoMode, 'TX'), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(StationAt(True), Band20, NoMode, eNoMode, 'TX'), 'nor this one');
end;

(* "Mixed mode (Phone, CW, Digital (NO FT8 allowed)"; "No FT8/FT4"; the
   overview: "Only PSK, RTTY and JS8Call are allowed as digital contacts."
   NY4I on #126: digital is RTTY, PSK and JS8 only. Every other digital
   submode (FT8, FT4, JT65, MFSK, ...) is an automatic X-QSO (Q98,
   QSOIsXQSO): logged, 0 points, no multiplier. eNoMode and eData mean "some
   submode of Digital" and are credited; reversed RTTY and PSK are still RTTY
   and PSK. Every ExtendedModeType is walked, so a submode added to VC is
   judged here. Asked of the station-less identity, as every X-QSO reader
   asks it. *)
procedure TContestOklahomaQPTests.Test_OklahomaOnlyRTTYPSKAndJS8AreDigital;
var
   identity: TContestBase;
   contestObject: TContestBase;
   qso: ContestExchange;
   ext: ExtendedModeType;
begin
   BeginTest('Test_OklahomaOnlyRTTYPSKAndJS8AreDigital');
   identity := ContestIdentity(OklahomaHandle);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckTrue(ContestCreditsMode(identity, Digital, ext) = (ext in RTTY_PSK_AND_JS8),
                'digital submode ' + IntToStr(Ord(ext)) + ' credited exactly when RTTY, PSK or JS8');
      qso := OklahomaQso(Band20, Digital, ext, 'MUS');
      CheckTrue(QSOIsXQSO(identity, qso) = not (ext in RTTY_PSK_AND_JS8),
                'digital submode ' + IntToStr(Ord(ext)) + ' is an X-QSO exactly when not RTTY, PSK or JS8');
      end;
   CheckFalse(ContestCreditsMode(identity, Digital, eFT8), 'FT8 is not credited ("NO FT8")');
   CheckFalse(ContestCreditsMode(identity, Digital, eFT4), 'nor FT4 ("No FT8/FT4")');
   CheckFalse(ContestCreditsMode(identity, Digital, eJT65), 'nor JT65');
   CheckFalse(ContestCreditsMode(identity, Digital, eMFSK), 'nor MFSK');
   CheckTrue(ContestCreditsMode(identity, Digital, eJS8), 'JS8 is ("JS8Call")');
   CheckTrue(ContestCreditsMode(identity, Digital, eRTTY), 'RTTY is');
   CheckTrue(ContestCreditsMode(identity, Digital, ePSK31), 'PSK31 is');
   CheckTrue(ContestCreditsMode(identity, CW, eCW), 'CW is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eUSB), 'USB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eLSB), 'LSB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eNoMode), 'phone with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM is credited');

   (* The readers that know only a ModeType key: the dupe sheet and the
      need-multiplier hint. *)
   CheckTrue(ContestCreditsModeKey(identity, Digital), 'the Digital key is credited');
   CheckTrue(ContestCreditsModeKey(identity, CW), 'the CW key is');
   CheckTrue(ContestCreditsModeKey(identity, Phone), 'the Phone key is');

   (* THE OUTCOME, through ScoreQSO and the X-QSO question SetMultFlags asks
      first -- for the station-carrying object too. *)
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eFT8, 'MUS'), 'outside OK, FT8 scores 0');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Digital, eFT4, 'TX'), 'in OK, FT4 scores 0');
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eJT65, 'MUS'), 'JT65 scores 0');
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eMFSK, 'MUS'), 'MFSK scores 0');
   CheckEquals(3, PointsFor(StationAt(False), Band20, Digital, eJS8, 'MUS'), 'JS8 scores 3');
   CheckEquals(3, PointsFor(StationAt(True), Band40, Digital, ePSK31, 'TX'), 'PSK31 scores 3');
   contestObject := MakeOklahoma(StationAt(True));
   try
      qso := OklahomaQso(Band20, Digital, eFT8, 'TX');
      CheckTrue(QSOIsXQSO(contestObject, qso),
                'an in-state FT8 QSO is an X-QSO, so SetMultFlags gives it no multiplier');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   MULTIPLIERS
   --------------------------------------------------------------------------- *)

(* "Oklahoma stations: The 50 states (DC counts as Maryland); The 13 Canadian
   Provinces/Territories - NS, NB, NL, PE, QC, ON, MB, SK, AB, BC, NT, NU, YT
   ; The 77 Oklahoma counties". The shipped oklahoma.dom through the real
   loader (InStateMultiplierOf follows its INCLUDEs), and the class's own
   CountsAsMultiplier (CountsForEntrant, the seam SetMultFlags asks).

   NY4I on #126: "OK stays in the state list ('The 50 states'); it is
   harmless, since an OK station sends a county" -- so Oklahoma IS a state
   multiplier for an Oklahoma entrant, unlike North Dakota's "49 states". *)
procedure TContestOklahomaQPTests.Test_OklahomaInStateMultipliers;
var
   h: TContestHandle;
   i: integer;
begin
   BeginTest('Test_OklahomaInStateMultipliers');
   h := OklahomaHandle;

   CheckEquals('MUS', InStateMultiplierOf(h, 'MUS'), 'Muskogee County is its own multiplier');
   CheckEquals('ADA', InStateMultiplierOf(h, 'ADA'), 'and Adair');
   CheckEquals('WOO', InStateMultiplierOf(h, 'WOO'), 'and Woods');
   CheckEquals('WDW', InStateMultiplierOf(h, 'WDW'), 'and Woodward, not Woods');
   CheckEquals('OKL', InStateMultiplierOf(h, 'OKL'), 'Oklahoma County is a county, not the state');
   CheckEquals('TEX', InStateMultiplierOf(h, 'TEX'), 'Texas County is a county');
   CheckEquals('TX', InStateMultiplierOf(h, 'TX'), 'and Texas the state is TX');
   CheckEquals('AK', InStateMultiplierOf(h, 'AK'), 'Alaska is a state');
   CheckEquals('HI', InStateMultiplierOf(h, 'HI'), 'Hawaii is');
   CheckEquals('OK', InStateMultiplierOf(h, 'OK'), '"The 50 states" -- Oklahoma among them');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'OK'), rmDomestic),
             'and an Oklahoma entrant counts it (NY4I: OK stays)');

   (* "DC counts as Maryland". *)
   CheckEquals('MD', InStateMultiplierOf(h, 'DC'), 'DC is Maryland''s multiplier');
   CheckEquals('MD', InStateMultiplierOf(h, 'MD'), 'as Maryland is');

   for i := Low(RULES_CANADIAN) to High(RULES_CANADIAN) do
      begin
      CheckEquals(RULES_CANADIAN[i], InStateMultiplierOf(h, RULES_CANADIAN[i]),
                  'the rules'' Canadian abbreviation ' + RULES_CANADIAN[i] + ' is its own multiplier');
      end;
   CheckEquals('NL', InStateMultiplierOf(h, 'NF'), 'NF is Newfoundland and Labrador');
   CheckEquals('NL', InStateMultiplierOf(h, 'LB'), 'and so is LB');
   (* P13.DOM also spells Newfoundland LA. S50.DOM is included first and the
      first alias added wins, so LA stays Louisiana. *)
   CheckEquals('LA', InStateMultiplierOf(h, 'LA'), 'LA is Louisiana, not Labrador');

   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'TX'), rmDomestic), 'Texas counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'MUS'), rmDomestic), 'a county counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'DC'), rmDomestic), 'DC counts (as MD)');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NU'), rmDomestic), 'Nunavut counts');
   CheckTrue(CountsForEntrant(h, False, InStateMultiplierOf(h, 'MUS'), rmDomestic),
             'outside OK a county counts (the host-area rule is a separate question)');

   (* DXCC countries are the DX multiplier (Test_OklahomaInStateDXMultiplier),
      not entries in the in-state file. *)
   CheckEquals('', InStateMultiplierOf(h, 'DX'), 'DX is no domestic multiplier');
   CheckEquals('', InStateMultiplierOf(h, 'DL'), 'nor a DX country');
end;

(* "DXCC countries* (excluding US, Canada, KH6 and KL7)" for "Oklahoma
   stations"; "Non Oklahoma stations: The 77 Oklahoma counties" -- none. The
   key is the worked station's DXCC country, refused for K, VE, KH6 and KL;
   KP4 and KH2 are DX ("DX stations (including KH2/KP4)"). Asked through the
   nil-safe seams LOGEDIT asks. *)
procedure TContestOklahomaQPTests.Test_OklahomaInStateDXMultiplier;
var
   contestObject: TContestBase;

   function KeyFor(const aCountryID: string; out aKey: string): boolean;
   var
      qso: ContestExchange;
      key: DXMultiplierString;
   begin
      qso := OklahomaQso(Band20, CW, eCW, aCountryID);
      qso.QTH.CountryID := ShortString(aCountryID);
      Result := ContestDXMultiplierKey(contestObject, qso, key);
      aKey := string(key);
   end;

var
   key: string;
begin
   BeginTest('Test_OklahomaInStateDXMultiplier');
   contestObject := MakeOklahoma(StationAt(True));
   try
      CheckTrue(ContestHasDXMultiplier(contestObject), 'in OK there is a DX multiplier');
      CheckTrue(KeyFor('DL', key), 'Germany is a DX multiplier');
      CheckEquals('DL', key, 'keyed by its DXCC country');
      CheckTrue(KeyFor('JA', key), 'Japan is');
      CheckEquals('JA', key, 'keyed JA');
      CheckTrue(KeyFor('KP4', key), '"DX stations (including KH2/KP4)": Puerto Rico is');
      CheckEquals('KP4', key, 'keyed KP4');
      CheckTrue(KeyFor('KH2', key), 'and Guam');
      CheckTrue(KeyFor('XE', key), 'and Mexico');
      CheckFalse(KeyFor('K', key), '"excluding US": no key for the USA');
      CheckEquals('', key, 'and none written');
      CheckFalse(KeyFor('VE', key), '"Canada": none');
      CheckFalse(KeyFor('KH6', key), '"KH6": none');
      CheckFalse(KeyFor('KL', key), '"KL7": none');
   finally
      contestObject.Free;
   end;

   contestObject := MakeOklahoma(StationAt(False));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'outside OK there is no DX multiplier');
      CheckFalse(KeyFor('DL', key), 'so no key for Germany');
      CheckFalse(KeyFor('KP4', key), 'nor Puerto Rico');
   finally
      contestObject.Free;
   end;

   contestObject := MakeOklahoma(DXStation('DL'));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'a DX entrant has none either');
      CheckFalse(KeyFor('JA', key), 'so no key for Japan');
   finally
      contestObject.Free;
   end;
end;

(* "Non Oklahoma stations work only Oklahoma stations" -- "Non Oklahoma
   stations: The 77 Oklahoma counties." Q107: an out-of-state entrant's QSO
   with a station the session's table (the shipped oklahoma_cty.dom, through
   the real loader) does not know is refused when typed, and scores 0 with
   no multiplier when logged any other way. *)
var
   GShapeSetsQTH: string;

function StubParseShape(const aHelper: string; const aText: string;
                        var aExch: ContestExchange): boolean;
begin
   aExch.QTHString := ShortString(GShapeSetsQTH);
   Result := True;
end;

function ParseSession: TReceivedExchangeSession;
begin
   Result := Default(TReceivedExchangeSession);
   Result.Parsers := StubExchangeParsers(@StubParseShape);
   Result.IsDomesticQTH := @CountyFileKnowsQTH;
   Result.CallWindowHasCall := True;
end;

function OutOfStateStation: TStationContext;
begin
   Result := NoStation;
   Result.IsDomesticQTH := @CountyFileKnowsQTH;
   Result.InHostState := False;
   Result.MyState := 'TX';
   Result.MyCountry := 'K';
end;

function ParseOutOfState(const aQTH: string; out aMessage: string): boolean;
var
   contestObject: TContestBase;
   exch: ContestExchange;
begin
   GShapeSetsQTH := aQTH;
   contestObject := MakeOklahoma(OutOfStateStation);
   try
      exch := Default(ContestExchange);
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, ParseSession, exch, aMessage);
   finally
      contestObject.Free;
   end;
end;

procedure TContestOklahomaQPTests.Test_OklahomaOutOfStateWorksOnlyOklahoma;
var
   msg: string;
   contestObject: TContestBase;
   qso: ContestExchange;
   counties: TStringList;
   i: integer;
   code: string;
begin
   BeginTest('Test_OklahomaOutOfStateWorksOnlyOklahoma');
   counties := TStringList.Create;
   LoadCountyTable('oklahoma_cty.dom', True);
   try
      (* EVERY ONE OF THE SPONSOR'S 77 COUNTIES is its own multiplier and a
         station this entrant may work. *)
      ReadSponsorCountyTable(counties);
      CheckEquals(77, counties.Count, 'the sponsor''s table lists 77 counties');
      CheckEquals(77, mo.DomList.Count, 'the county file is 77 multipliers');
      for i := 0 to counties.Count - 1 do
         begin
         code := counties.Names[i];
         CheckEquals(code, MultiplierOf(CountyTable, code), code + ' is its own multiplier');
         CheckTrue(CountyFileKnowsQTH(code), code + ' is an Oklahoma station');
         end;

      (* TYPED: a county is taken; anything else is refused with the
         party's reason. *)
      CheckTrue(ParseOutOfState('MUS', msg), 'outside OK, a Muskogee County station');
      CheckEquals('', msg, 'nothing to say');
      CheckTrue(ParseOutOfState('rgm', msg), 'Roger Mills, typed in lower case');
      CheckFalse(ParseOutOfState('TX', msg), 'outside OK, a Texas station: refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['OK']), msg, 'with the reason');
      CheckFalse(ParseOutOfState('ON', msg), 'an Ontario station: refused');
      CheckFalse(ParseOutOfState('OK', msg),
                 'OK alone is no county: "Oklahoma stations send signal report and county"');
      CheckFalse(ParseOutOfState('DL', msg), 'a DX station: refused');

      (* LOGGED: the same rule scores 0 and earns no multiplier. *)
      CheckEquals(3, PointsFor(OutOfStateStation, Band20, CW, eCW, 'TUL'), 'logged: a county scores');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'TX'), 'logged: Texas scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'DL'), 'logged: DX scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, ''), 'logged: no QTH scores 0');

      contestObject := MakeOklahoma(OutOfStateStation);
      try
         qso := OklahomaQso(Band20, CW, eCW, 'TX');
         CheckFalse(ContestCreditsWorkedStation(contestObject, qso),
                    'and earns no multiplier (the predicate SetMultFlags asks)');
         CheckTrue(QSOIsXQSO(contestObject, qso),
                   'an automatic X-QSO, judged with the entrant (Q119)');
         qso := OklahomaQso(Band20, CW, eCW, 'MUS');
         CheckTrue(ContestCreditsWorkedStation(contestObject, qso), 'a county is credited');
         CheckFalse(QSOIsXQSO(contestObject, qso), 'and is no X-QSO');
      finally
         contestObject.Free;
      end;
   finally
      FreeCountyTable;
      counties.Free;
   end;
end;

(* "Oklahoma mobile stations operating on a 2, 3, or 4 county line may be
   counted as 2, 3, or 4 QSO and multipliers. Separate log entries must be
   entered for each county/QSO". One to four pass; five are refused. The
   engine half (one QSO per county from one entry) is the real-engine
   test's. *)
procedure TContestOklahomaQPTests.Test_OklahomaCountyLineIsUpToFourCounties;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
   n: integer;
begin
   BeginTest('Test_OklahomaCountyLineIsUpToFourCounties');
   contestObject := MakeOklahoma(NoStation);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(4, party.CountyLineCountiesMax, 'four counties on a line');
      CheckTrue(party.CountyLineAllowed, 'a county line is allowed');
      for n := 1 to 4 do
         begin
         CheckTrue(party.ValidateQTHCount(n, msg), IntToStr(n) + ' counties are taken');
         CheckEquals('', msg, 'nothing to say about ' + IntToStr(n));
         end;
      CheckFalse(party.ValidateQTHCount(5, msg), 'five are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [4]), msg, 'with the county-count message');
   finally
      contestObject.Free;
   end;
end;

(* "Stations may be worked again on each band and mode." "Oklahoma mobile
   stations that change counties are considered to be a new station and may
   be worked again for QSO and multiplier credit." Through the dupe path
   LogContact takes (uTestQSOPartyRules.RoverDupeAnswers): the same call from
   a new county on the same band and mode is a new QSO; from the first
   county again it is a dupe. The band and mode halves -- CW and digital
   apart ("CW and Digital contacts will be scored separately") -- are the
   real engine's, below. *)
procedure TContestOklahomaQPTests.Test_OklahomaDupes;
var
   newCountyIsDupe: boolean;
   sameCountyIsDupe: boolean;
begin
   BeginTest('Test_OklahomaDupes');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(OklahomaHandle)),
             'the received county is part of the dupe key');
   CheckTrue(ContestDupeModeOf(ContestIdentity(OklahomaHandle), Digital) = Digital,
             'Digital is its own dupe mode, apart from CW');
   CheckTrue(ContestDupeModeOf(ContestIdentity(OklahomaHandle), CW) = CW, 'and CW its own');
   RoverDupeAnswers(OklahomaHandle, 'K5CM', 'MUS', 'OKM', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'K5CM from Okmulgee after Muskogee, 20 m CW: a new station');
   CheckTrue(sameCountyIsDupe, 'K5CM from Muskogee again, 20 m CW: a dupe');
   RoverDupeAnswers(OklahomaHandle, 'K5CM/M', 'PIT', 'LAT', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'a /M call from Latimer after Pittsburg: a new station');
   CheckTrue(sameCountyIsDupe, 'and from Pittsburg again: a dupe');
end;

(* "Scoring: Multiply total QSO Points by total Multipliers." For an
   Oklahoma entrant the multipliers are the domestic ones (counties, states,
   provinces) PLUS the DXCC countries; for anyone else the counties. No power
   multiplier: QRP, LOW and HIGH score alike.

   NOT BUILT, #133: "Oklahoma Mobile stations can earn 500 points per county
   by making at least 10 QSO in the county." The score is points x
   multipliers only -- pinned so the day #133 lands is seen here. *)
procedure TContestOklahomaQPTests.Test_OklahomaScoreIsPointsTimesMultipliers;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_OklahomaScoreIsPointsTimesMultipliers');
   t := Default(TScoreTotals);
   t.QSOPoints := 7437;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 60;
   t.Mults[AllBands, Both, rmDX] := 9;

   station := StationAt(True);
   station.MyPower := cpQRP;
   view := TLoggedQSOList.Create;
   contestObject := MakeOklahoma(station);
   try
      (* The sponsor's 2026 results: N5O "7437 x 69 = 513153", before its
         mobile bonus. *)
      CheckEquals(513153, contestObject.FinalScore(t, view),
                  'points x (domestic + DX multipliers), QRP');
      station.MyPower := cpLOW;
      contestObject.SetStation(station);
      CheckEquals(513153, contestObject.FinalScore(t, view), 'LOW the same');
      station.MyPower := cpHIGH;
      contestObject.SetStation(station);
      CheckEquals(513153, contestObject.FinalScore(t, view), 'HIGH the same');
      CheckEquals(0, contestObject.BonusPoints(t, view), 'no bonus: the mobile bonus is #133');

      (* Outside Oklahoma: "The 77 Oklahoma counties". *)
      contestObject.SetStation(StationAt(False));
      t.QSOPoints := 168;
      t.Mults[AllBands, Both, rmDomestic] := 30;
      t.Mults[AllBands, Both, rmDX] := 0;
      CheckEquals(168 * 30, contestObject.FinalScore(t, view), 'outside OK, points x counties');

      t.Mults[AllBands, Both, rmDomestic] := 0;
      CheckEquals(0, contestObject.FinalScore(t, view), 'no multiplier, no score');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   DATA
   --------------------------------------------------------------------------- *)

(* oklahoma_cty.dom IS THE SPONSOR'S TABLE (OK-QSO-PARTY-Counties.txt, the
   county page the overview names: "Be sure to use the county abbreviations
   shown with Counties Map"): the 77 counties, each abbreviation once, each
   named as the sponsor names it, each its OWN multiplier -- "The 77 Oklahoma
   counties" for every entrant, so no line maps a county to the state -- and
   nothing else: no INCLUDE, so an out-of-state entrant's table holds only
   counties (the host-area rule reads it). *)
procedure TContestOklahomaQPTests.Test_OklahomaCountyFileIsTheSponsorsTable;
var
   sponsorTable: TStringList;
   lines: TStringList;
   seen: TStringList;
   i: integer;
   key: string;
   line: string;
begin
   BeginTest('Test_OklahomaCountyFileIsTheSponsorsTable');
   sponsorTable := TStringList.Create;
   lines := TStringList.Create;
   seen := TStringList.Create;
   try
      ReadSponsorCountyTable(sponsorTable);
      CheckEquals(77, sponsorTable.Count, 'the sponsor lists 77 counties');

      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      lines.LoadFromFile(ShippedDomDir + 'oklahoma_cty.dom');
      for i := 0 to lines.Count - 1 do
         begin
         line := lines[i];
         (* An INCLUDE is a line whose FIRST word is INCLUDE (followed or
            not); the header's prose may name the word. *)
         CheckTrue((DomIncludeName(line) = '') and
                   (Pos('INCLUDE', UpperCase(TrimLeft(line))) <> 1),
                   'the county file includes nothing, line ' + IntToStr(i + 1));
         key := DomFileLineKey(line);
         if key = '' then
            begin
            Continue;
            end;
         CheckTrue(seen.IndexOf(key) < 0, 'each county once: ' + key);
         seen.Add(key);
         CheckTrue(sponsorTable.IndexOfName(key) >= 0, key + ' is in the sponsor''s table');
         CheckEquals(key + ' = ' + key + ',^' + sponsorTable.Values[key], line,
                     'its own multiplier, its own alias, the sponsor''s name: ' + line);
         end;
      CheckEquals(77, seen.Count, 'oklahoma_cty.dom holds the 77 counties and nothing else');
   finally
      seen.Free;
      lines.Free;
      sponsorTable.Free;
   end;

   (* AS AN OKLAHOMA STATION READS IT (MultipliersIsCounties False): still 77
      multipliers, not one -- "The 77 Oklahoma counties". *)
   LoadCountyTable('oklahoma_cty.dom', False);
   try
      CheckEquals(77, mo.DomList.Count, 'in state, the 77 counties are 77 multipliers');
      CheckEquals('MUS', MultiplierOf(CountyTable, 'MUS'), 'Muskogee counts as Muskogee');
      CheckEquals('', MultiplierOf(CountyTable, 'OK'), 'no state is in the county file');
      CheckEquals('', MultiplierOf(CountyTable, 'TX'), 'nor Texas');
   finally
      FreeCountyTable;
   end;
end;

(* oklahoma.dom, read as text: the header holds no '=' (the loader has no
   comment syntax, so a header line holding '=' would be a multiplier); the
   counties first; then "DC counts as Maryland" as Dc > Md, BEFORE S50.DOM
   so it is the first DC alias; then S50.DOM and P13.DOM -- S50 BEFORE P13,
   because P13 also spells Newfoundland LA and the first alias added wins;
   each INCLUDE spelt so the loader follows it; and Nl = NF,LB, so NF and LB
   are the rules' NL.
   Then loaded through the real loader: 77 counties + 50 states (DC is MD,
   not a 51st) + 13 provinces and territories = 140 domestic multipliers,
   Oklahoma among them (NY4I: it stays). *)
procedure TContestOklahomaQPTests.Test_OklahomaInStateFileIsTheRulesMultipliers;
var
   lines: TStringList;
   includes: string;
   included: string;
   entries: string;
   inHeader: boolean;
   i: integer;
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
begin
   BeginTest('Test_OklahomaInStateFileIsTheRulesMultipliers');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(ShippedDomDir + 'oklahoma.dom');
      includes := '';
      entries := '';
      inHeader := True;
      for i := 0 to lines.Count - 1 do
         begin
         included := DomIncludeName(lines[i]);
         if included <> '' then
            begin
            inHeader := False;
            includes := includes + UpperCase(included) + ' ';
            end
         else
            begin
            CheckFalse(Pos('INCLUDE', UpperCase(TrimLeft(lines[i]))) = 1,
                       'oklahoma.dom line ' + IntToStr(i + 1)
                       + ' is an INCLUDE the loader would not follow');
            if inHeader then
               begin
               CheckEquals(0, Pos('=', lines[i]),
                           'oklahoma.dom header line ' + IntToStr(i + 1)
                           + ' would be read as an entry');
               end
            else if Pos('=', lines[i]) > 0 then
               begin
               entries := entries + Trim(lines[i]) + '|';
               end;
            end;
         end;
      CheckEquals('OKLAHOMA_CTY.DOM S50.DOM P13.DOM ', includes,
                  'the counties first, then the states, then the provinces');
      CheckEquals('Dc > Md = DC|Nl = NF,LB|', entries,
                  'two entries of its own: DC is Maryland, NF and LB are NL');
   finally
      lines.Free;
   end;

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      LoadShippedDomFollowingIncludes(table, 'oklahoma.dom', True, 0);
      CheckEquals(140, mo.DomList.Count,
                  '77 counties, 50 states (DC counted as MD) and 13 provinces and territories');
      CheckEquals('OK', MultiplierOf(table, 'OK'), 'Oklahoma is one of them');
      CheckTrue(CountsForEntrant(OklahomaHandle, True, MultiplierOf(table, 'OK'), rmDomestic),
                'and the class counts it');
      CheckEquals('MUS', MultiplierOf(table, 'MUS'),
                  'the counties are loaded first, so a county keeps its own code');
      CheckEquals('MD', MultiplierOf(table, 'DC'), 'DC is Maryland');
      CheckEquals('NL', MultiplierOf(table, 'NL'), 'NL is Newfoundland and Labrador');
      CheckEquals('NL', MultiplierOf(table, 'NF'), 'and NF is the same multiplier');
      CheckEquals('NL', MultiplierOf(table, 'LB'), 'and LB');
      CheckEquals('LA', MultiplierOf(table, 'LA'), 'LA is Louisiana');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

(* ---------------------------------------------------------------------------
   EXPORT
   --------------------------------------------------------------------------- *)

(* THE RULES' OWN EXAMPLE, word for word:

     QSO: 7042 CW 2014-03-22 1301 K5CM    599 MUS  K4AMC   599 TN
     QSO: 7035 CW 2014-03-22 1612 K5CM    599 ROG W5CW     599 MUS

   RST and the county sent, RST and the QTH received. The first part is laid
   out as PostUnit lays every contest's (copied from Georgia's test). The
   rules give no out-of-state or DX example line; those are pinned from the
   exchange rule ("W/VE stations ... state or province"; "DX stations ...
   DXCC prefix"). *)
procedure TContestOklahomaQPTests.Test_OklahomaCabrilloLineIsTheRulesExample;
var
   contestObject: TContestBase;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
   firstPart: string;
   sent: string;
   received: string;
   line: string;

   function Words(const aText: string): string;
   var
      list: TStringList;
   begin
      list := TStringList.Create;
      try
         list.Delimiter := ' ';
         list.StrictDelimiter := False;
         list.DelimitedText := Trim(aText);
         Result := list.CommaText;
      finally
         list.Free;
      end;
   end;

   function FirstPartOf(const aFreq: string; aHour, aMinute: integer; const aCall: string): string;
   begin
      Result := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                       [aFreq, contestObject.CabrilloModeString(CW, eCW),
                        2014, 3, 22, aHour, aMinute, aCall]);
   end;

begin
   BeginTest('Test_OklahomaCabrilloLineIsTheRulesExample');
   CheckEquals('OK-QSO-PARTY', ContestIdentity(OklahomaHandle).CabrilloContestName('', ''),
               'CONTEST: OK-QSO-PARTY');

   (* K5CM, A MUSKOGEE COUNTY MOBILE, WORKS TENNESSEE. *)
   contestObject := MakeOklahoma(StationAt(True));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'MUS';
      qso := OklahomaQso(Band40, CW, eCW, 'TN');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'TN';

      firstPart := FirstPartOf('7042', 13, 1, 'K5CM');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 MUS    ', sent, 'sent: RST and my county');
      CheckEquals('599 TN     ', received, 'received: RST and the state received');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'K4AMC', received, '']);
      CheckEquals(Words('QSO: 7042 CW 2014-03-22 1301 K5CM    599 MUS  K4AMC   599 TN'), Words(line),
                  'the rules'' first example line, word for word: ' + line);
      CheckEquals(CabrilloQSOLineFormatDefault, contestObject.CabrilloQSOLineFormat,
                  'the standard QSO line, no extra column');
      CheckEquals('599 MUS    ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my county');

      (* AN OKLAHOMA-TO-OKLAHOMA QSO, from Rogers County. *)
      my.MyState := 'ROG';
      ctx.HisQTH := 'MUS';
      qso := OklahomaQso(Band40, CW, eCW, 'MUS');
      firstPart := FirstPartOf('7035', 16, 12, 'K5CM');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'W5CW', received, '']);
      CheckEquals(Words('QSO: 7035 CW 2014-03-22 1612 K5CM    599 ROG W5CW     599 MUS'), Words(line),
                  'the rules'' OK-to-OK example line, word for word: ' + line);

      (* PHONE, with Ontario. *)
      ctx.RSTSent := '59';
      ctx.RSTReceived := '59';
      ctx.HisQTH := 'ON';
      qso := OklahomaQso(Band20, Phone, eUSB, 'ON');
      CheckEquals('PH', contestObject.CabrilloModeString(Phone, eUSB), 'SSB is PH');
      CheckEquals('59  ROG    ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent on phone: RS and my county');
      CheckEquals('59  ON     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: RS and the province');

      (* "DX stations ... send signal report and DXCC prefix": the prefix as
         typed; with none typed, the DX QTH the call resolved to, else DX. *)
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'DL';
      qso := OklahomaQso(Band20, CW, eCW, 'DL');
      CheckEquals('599 DL     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'a DX station''s column is the prefix it sent');
      qso := OklahomaQso(Band20, CW, eCW, '');
      qso.DXQTH := 'DL';
      ctx.HisQTH := '';
      CheckEquals('599 DL     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'nothing typed: the DX QTH');
   finally
      contestObject.Free;
   end;

   (* A TEXAS ENTRANT WORKS MUSKOGEE COUNTY. *)
   contestObject := MakeOklahoma(StationAt(False));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'TX';
      qso := OklahomaQso(Band40, CW, eCW, 'MUS');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'MUS';
      firstPart := FirstPartOf('7035', 19, 30, 'W5AAA');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'K5CM', received, '']);
      CheckEquals(Words('QSO: 7035 CW 2014-03-22 1930 W5AAA 599 TX K5CM 599 MUS'), Words(line),
                  'the out-of-state line: ' + line);
      CheckEquals('599 TX     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my state');
   finally
      contestObject.Free;
   end;

   (* A DX ENTRANT: "DX stations (including KH2/KP4) send signal report and
      DXCC prefix" -- its own (NY4I). MY STATE is empty, so the party base's
      SentLocation sends Station.MyCountry. *)
   contestObject := MakeOklahoma(DXStation('DL'));
   try
      my := Default(TMyStationExchange);
      my.MyState := '';
      qso := OklahomaQso(Band20, CW, eCW, 'MUS');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'MUS';
      firstPart := FirstPartOf('14041', 20, 15, 'DL1AAA');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 DL     ', sent, 'sent: RST and my prefix');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'K5CM', received, '']);
      CheckEquals(Words('QSO: 14041 CW 2014-03-22 2015 DL1AAA 599 DL K5CM 599 MUS'), Words(line),
                  'the DX entrant''s line: ' + line);
      CheckEquals('599 DL     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my prefix');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet. First a Texas
   entrant with the shipped oklahoma_cty.dom, then a Muskogee County entrant
   with the shipped oklahoma.dom (its INCLUDEs followed by uTestShippedDom,
   since the test binary has no dom folder).
   --------------------------------------------------------------------------- *)

procedure TContestOklahomaQPTests.Test_OklahomaRealEngine;
var
   savedContest: TContestHandle;
   savedQsoByBand: boolean;
   savedQsoByMode: boolean;
   savedMultByBand: boolean;
   savedMultByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedInHostState: boolean;
   savedCounties: boolean;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedCountries: TStringList;
   savedRefusalDomDir: string;
   savedMyCountry: string;
   savedDomesticFilename: string;
   ctyPath: string;
   h: TContestHandle;
   rx: ContestExchange;
   accepted: boolean;
   dupe: boolean;
   i: integer;

   (* ONE QSO, AS AN OPERATOR ENTERS IT: ParametersOkay, then what
      LogContact does with the record it accepts -- the dupe question, the
      dupe's zero points, the sheets. The submode is the record's, as the
      radio or WSJT-X would leave it. Returns whether it was a dupe. *)
   function Enter(const aCall: string; const aExch: string; aBand: BandType;
                  aMode: ModeType; aExtMode: ExtendedModeType;
                  out aAccepted: boolean; var aRX: ContestExchange): boolean;
   begin
      aRX := Default(ContestExchange);
      aRX.ExtMode := aExtMode;
      ActiveMode := aMode;
      CallWindowString := CallString(aCall);
      ExchangeErrorMessage := '';
      aAccepted := ParametersOkay(CallString(aCall), Str40(aExch), aBand, aMode,
                                  14025000, aRX);
      aRX.ceRecordKind := rkQSO;
      aRX.ceContest := Contest;
      Result := False;
      if aAccepted then
         begin
         Result := VisibleLog.QSOIsADupe(aRX);
         if Result then
            begin
            aRX.ceDupe := True;
            aRX.QSOPoints := 0;
            end;
         Sheet.SetMultFlags(aRX);
         Sheet.AddQSOToSheets(@aRX, False);
         AddQSOToDupeSheets(aRX, False);
         end;
   end;

begin
   BeginTest('Test_OklahomaRealEngine');
   h := OklahomaHandle;
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   savedContest := Contest;
   savedQsoByBand := Settings.Qso.ByBand;
   savedQsoByMode := Settings.Qso.ByMode;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedInHostState := StationInHostState;
   savedCounties := MultipliersIsCounties;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedTable := DomQTHTable;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedRefusalDomDir := DomesticQTHRefusalDomDir;
   savedMyCountry := Settings.My.Country;
   savedDomesticFilename := Settings.Contest.DomesticFilename;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;
   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      (* AS FoundContest SETS IT UP FOR A TEXAS STATION: not in Oklahoma, so
         the county file with each county its own multiplier; K, VE, KH6 and
         KL are domestic countries (Add_KVEKH6KL, as for every party -- so a
         US call reaches the domestic parser); and the class's flags, as
         ApplyContestTraits writes them, so a wrong flag is seen here as a
         wrong dupe or multiplier. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := True;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'oklahoma_cty.dom'),
                'oklahoma_cty.dom loads');
      Contest := h;
      ReleaseActiveContest;
      StationInHostState := False;
      Settings.Qso.ByBand := ContestIdentity(h).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(h).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* MUSKOGEE COUNTY, CW. *)
      dupe := Enter('K5MUS', '599 MUS', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 MUS is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('MUS', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the county');
      CheckTrue(rx.DomesticMult, 'Muskogee is a new multiplier');
      CheckEquals(3, Integer(rx.QSOPoints), '"three points per CW QSO with any OK station"');

      (* "A multiplier counts once, regardless of the number of bands or
         modes it is worked on." "Stations may be worked again on each band
         and mode." *)
      dupe := Enter('K5MUS', '599 MUS', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores 3');
      CheckFalse(rx.DomesticMult, 'but Muskogee is NOT a new multiplier on another band');

      dupe := Enter('K5MUS', '59 MUS', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '59 MUS on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), '"two points per phone QSO"');
      CheckFalse(rx.DomesticMult, 'nor a new multiplier in another mode');

      (* "CW and Digital contacts will be scored separately, so you can work
         the same station on both CW and PSK and get credit for both modes." *)
      dupe := Enter('K5MUS', '599 MUS', Band20, Digital, ePSK31, accepted, rx);
      CheckTrue(accepted, 'PSK is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m PSK after CW is not a dupe');
      CheckFalse(QSOIsXQSO(ContestIdentity(h), rx), 'PSK is no X-QSO');
      CheckEquals(3, Integer(rx.QSOPoints), '"three points per Digital QSO"');
      CheckFalse(rx.DomesticMult, 'and is no new multiplier');

      dupe := Enter('K5MUS', '599 MUS', Band20, Digital, eJS8, accepted, rx);
      CheckTrue(accepted, 'JS8 is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(dupe, 'JS8 after PSK on 20 m IS a dupe: both are Digital');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      dupe := Enter('K5MUS', '599 MUS', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'Muskogee again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      (* FM is phone: FM after SSB on one band is the same mode, so a dupe. *)
      dupe := Enter('K5VHF', '59 TUL', Band2, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '2 m SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), '2 m ("144 MHz") phone scores 2');
      dupe := Enter('K5VHF', '59 TUL', Band2, FM, eFM, accepted, rx);
      CheckTrue(accepted, '2 m FM is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(dupe, 'the same station on 2 m FM after SSB IS a dupe: FM is phone');

      (* "Oklahoma mobile stations that change counties are considered to be
         a new station and may be worked again for QSO and multiplier
         credit." *)
      dupe := Enter('K5MUS', '599 OKM', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same call from Okmulgee on 20 m CW: a new station');
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores');
      CheckTrue(rx.DomesticMult, 'Okmulgee is a new multiplier');

      (* "No FT8/FT4": logged, an automatic X-QSO, nothing earned -- Ward
         stays unworked until a credited QSO with it. *)
      dupe := Enter('K5FT', '599 WAG', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'an FT8 QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and earns no multiplier');
      dupe := Enter('K5FT', '599 WAG', Band40, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'so Wagoner on 40 m CW is still a new multiplier');

      (* NO 160 m: logged, an automatic X-QSO. *)
      dupe := Enter('K5TOP', '599 CRE', Band160, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a 160 m QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO ("3.5, 7, 14, 21, 28, 50, and 144")');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and Creek is no multiplier from it');

      (* "Non Oklahoma stations work only Oklahoma stations." A US call goes
         to the domestic parser, which refuses a QTH the county file does
         not know, naming the host-area reason when the in-state file knows
         it (DomesticQTHRefusalDomDir: the tree's dom folder, as FoundContest
         leaves it for this station). *)
      DomesticQTHRefusalDomDir := ShippedDomDir;
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := 'oklahoma_cty.dom';

      accepted := True;
      Enter('W5TX', '599 TX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a Texas station is refused');
      CheckEquals('Improper domestic QTH!! (TX: work OK stations only)',
                  string(ExchangeErrorMessage),
                  'as an improper QTH, with the host-area reason');

      accepted := True;
      Enter('K5ABC', '599 MUX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a misspelt county is refused');
      CheckEquals('Improper domestic QTH!! (MUX not in oklahoma_cty.dom)',
                  string(ExchangeErrorMessage),
                  'as not in the county file');

      accepted := True;
      Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a DX station is refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['OK']), string(ExchangeErrorMessage),
                  'with the host-area reason');

      (* "Oklahoma mobile stations operating on a 2, 3, or 4 county line may
         be counted as 2, 3, or 4 QSO and multipliers. Separate log entries
         must be entered for each county/QSO": the first county is this
         QSO; the rest are queued, and TryLogContact's drain writes each as
         its own QSO. Five counties are refused before anything is queued. *)
      ClearPendingCounties;
      dupe := Enter('K5LINE', '599 PIT/LAT/HAS/LEF', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a four-county line is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('PIT', UpperCase(string(rx.QTHString)), 'the first county is this QSO');
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores 3');
      CheckEquals(3, PendingCountiesCount, 'three more counties are queued');
      CheckEquals('LAT', UpperCase(DequeuePendingCounty), 'Latimer, as its own QSO');
      CheckEquals('HAS', UpperCase(DequeuePendingCounty), 'Haskell');
      CheckEquals('LEF', UpperCase(DequeuePendingCounty), 'Le Flore');
      ClearPendingCounties;
      accepted := True;
      Enter('K5LINE', '599 PIT/LAT/HAS/LEF/MCU', Band15, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'five counties are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [4]), string(ExchangeErrorMessage),
                  'with the county-count message');
      CheckEquals(0, PendingCountiesCount, 'and nothing is queued');
      ClearPendingCounties;

      (* Q119: THE SAME REFUSED QSO, ARRIVING LOGGED (an import, a peer, an
         edit), is an automatic X-QSO for this entrant. *)
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      rx.Callsign := 'W5TX';
      rx.Band := Band20;
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.Frequency := 14025000;
      rx.RSTSent := 599;
      rx.RSTReceived := 599;
      rx.QTHString := 'TX';
      rx.tSysTime.qtYear := 26;
      rx.tSysTime.qtMonth := 3;
      rx.tSysTime.qtDay := 14;
      ActiveContest(Contest);
      CheckTrue(LoggedQSOIsXQSO(rx), 'out of state, a logged W5TX TX is an X-QSO');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'and its Cabrillo line says so');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx),
                 'and it counts toward no total');
      rx.QTHString := 'MUS';
      CheckFalse(LoggedQSOIsXQSO(rx), 'out of state, a logged Muskogee QSO is not');

      (* NOW A MUSKOGEE COUNTY ENTRANT: in Oklahoma, oklahoma.dom (the
         counties, the states, the provinces), each county its own
         multiplier; and DXCC countries. *)
      MultipliersIsCounties := False;
      LoadShippedDomFollowingIncludes(DomQTHTable, 'oklahoma.dom', True, 0);
      StationInHostState := True;
      Settings.Contest.DomesticFilename := 'oklahoma.dom';
      ReleaseActiveContest;
      ActiveContest(Contest);
      mo.ClearAllMults;

      dupe := Enter('W5AAA', '599 TX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in OK, 599 TX is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores 3');
      CheckTrue(rx.DomesticMult, 'Texas is a new multiplier');
      dupe := Enter('W5AAA', '59 TX', Band40, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'Texas on 40 m SSB is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckFalse(rx.DomesticMult, 'nor a new multiplier: once overall');

      dupe := Enter('K5BBB', '599 MUS', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'another Muskogee station is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'and Muskogee is a new multiplier: "The 77 Oklahoma counties"');

      dupe := Enter('K5CCC', '599 OK', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 OK is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('OK', UpperCase(string(rx.DomMultQTH)), 'its multiplier is OK');
      CheckTrue(rx.DomesticMult, '"The 50 states": Oklahoma counts (NY4I: OK stays)');

      dupe := Enter('W3DC', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 DC is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), '"DC counts as Maryland"');
      CheckTrue(rx.DomesticMult, 'a new multiplier, Maryland');
      dupe := Enter('W3MD', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), 'Maryland itself');
      CheckFalse(rx.DomesticMult, 'is then no new multiplier');

      dupe := Enter('VE3AAA', '599 ON', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 ON is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Ontario is a new multiplier');

      dupe := Enter('VO1AAA', '599 NL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NL is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NL', UpperCase(string(rx.DomMultQTH)), 'NL is Newfoundland and Labrador');
      CheckTrue(rx.DomesticMult, 'a new multiplier');

      dupe := Enter('KH6AAA', '599 HI', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 HI is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Hawaii is a state multiplier ("W/VE stations (including KH6/KL7)")');
      CheckFalse(rx.DXMult, 'and not a DX one ("excluding ... KH6")');

      (* "DXCC countries* (excluding US, Canada, KH6 and KL7)". *)
      dupe := Enter('DL1AAA', '599 DL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in OK, a DX station is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(3, Integer(rx.QSOPoints), 'for 3 points');
      CheckFalse(rx.DomesticMult, 'no domestic multiplier');
      CheckTrue(rx.DXMult, 'and Germany is a new DX multiplier');
      CheckFalse(LoggedQSOIsXQSO(rx), 'and in state it is no X-QSO');
      dupe := Enter('DL2BBB', '59 DL', Band40, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, 'another German station is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(rx.DXMult, 'Germany again is no new multiplier: once overall');

      dupe := Enter('KP4AA', '599 KP4', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a KP4 station is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DXMult, '"DX stations (including KH2/KP4)": Puerto Rico is a DX multiplier');
   finally
      DomesticCountries.Clear;
      for i := 0 to savedCountries.Count - 1 do
         begin
         DomesticCountries.Add(CallString(savedCountries[i]));
         end;
      savedCountries.Free;
      ClearPendingCounties;
      mo.ClearAllMults;
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      CallWindowString := savedCallWindow;
      ActiveMode := savedActiveMode;
      MultipliersIsCounties := savedCounties;
      StationInHostState := savedInHostState;
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      Settings.Contest.DomesticFilename := savedDomesticFilename;
      Settings.My.DeriveCountry(savedMyCountry);
      DomesticQTHRefusalDomDir := savedRefusalDomDir;
      ExchangeErrorMessage := '';
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

procedure TContestOklahomaQPTests.RunAllTests;
begin
   Test_OklahomaIdentity;
   Test_OklahomaBands;
   Test_OklahomaPoints;
   Test_OklahomaOnlyRTTYPSKAndJS8AreDigital;
   Test_OklahomaInStateMultipliers;
   Test_OklahomaInStateDXMultiplier;
   Test_OklahomaOutOfStateWorksOnlyOklahoma;
   Test_OklahomaCountyLineIsUpToFourCounties;
   Test_OklahomaDupes;
   Test_OklahomaScoreIsPointsTimesMultipliers;
   Test_OklahomaCountyFileIsTheSponsorsTable;
   Test_OklahomaInStateFileIsTheRulesMultipliers;
   Test_OklahomaCabrilloLineIsTheRulesExample;
   Test_OklahomaRealEngine;
end;

end.

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

(* THE VERMONT QSO PARTY -- added 2026-11-10 (#130), registered by its id
  (VT-QSO-PARTY). The rules are docs/ContestRules/QSOParties/Vermont/
  (vtqso.md, the 2027 rules dated 30-OCT-2026, and its transcription
  VT-QSO-PARTY-Rules.txt); NY4I's rulings are on #130. Each test below quotes
  the rule it holds. Written from ADDING_A_CONTEST.md Part A5, copying
  uTestContestOklahomaQP's shape; nothing is assumed from another party's
  rules.

  WHAT IS PINNED
    * its identity: the id, no legacy number, the names, the files, the
      flags, the party base and what it inherits;
    * its bands (every band but 30, 17 and 12 m) and its points in every
      mode through ScoreQSO (phone 1, CW 3, digital 2); every mode credited;
    * a WSJT-X QSO earns no multiplier of any kind (7B(f));
    * the in-state entrant's multipliers (the shipped vermont.dom through the
      real loader): the 14 counties, the 50 states with DC counted as MD,
      the 13 provinces and territories; and the gap -- a county does NOT also
      earn VT;
    * the in-state DX multiplier (DXCC but K, VE, KH6 and KL) and none
      outside Vermont;
    * the out-of-state entrant's multipliers and the host-area rule, against
      the shipped vermont_cty.dom;
    * a county line of two, the final score with its power multiplier and
      its rounding;
    * a DX entrant: RST only on the air and in its STX_STRING, its prefix in
      the Cabrillo column;
    * the two .dom files against the rules' county list;
    * the dupe rules and the mobile's new county;
    * the Cabrillo columns the rules name (they give no example line);
    * THROUGH THE REAL ENGINE (ParametersOkay and the multiplier sheet): an
      out-of-state entrant, then an in-state one, including a DX station
      that sends RST only. *)
unit uTestContestVermontQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestVermontQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_VermontIdentity;
      procedure Test_VermontBands;
      procedure Test_VermontPoints;
      procedure Test_VermontEveryModeIsCredited;
      procedure Test_VermontWSJTXEarnsNoMultiplier;
      procedure Test_VermontInStateMultipliers;
      procedure Test_VermontInStateDXMultiplier;
      procedure Test_VermontOutOfStateWorksOnlyVermont;
      procedure Test_VermontCountyLineIsTwoCounties;
      procedure Test_VermontDupes;
      procedure Test_VermontPowerMultiplier;
      procedure Test_VermontScoreIsPointsTimesMultipliersTimesPower;
      procedure Test_VermontCountyFileIsTheRulesList;
      procedure Test_VermontInStateFileIsTheRulesMultipliers;
      procedure Test_VermontCabrilloColumns;
      procedure Test_VermontRealEngine;
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
   uContestVermontQP,
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
   (* "13 Canadian Provinces and Territories (per RAC listing): AB, BC, MB,
      NB, NL, NS, NT, NU, ON, PE, QC, SK, YT." *)
   RULES_CANADIAN: array[0..12] of string = (
      'AB', 'BC', 'MB', 'NB', 'NL', 'NS', 'NT', 'NU', 'ON', 'PE', 'QC', 'SK', 'YT');

   (* 7B(f), "FT8 and other WSJTx modes". *)
   WSJTX_SUBMODES = [eFT8, eFT4, eJT65, eFST4, eFST4W];

function VermontHandle: TContestHandle;
begin
   if not FindContestById(VT_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('VT-QSO-PARTY is not registered');
      end;
end;

function MakeVermont(const aStation: TStationContext): TContestBase;
begin
   Result := Make(VermontHandle, aStation);
end;

(* A Vermont station (Chittenden County) or a New York one. The table knows
   every QTH (uTestContestObjects.WithHostAreaTable): a test about POINTS
   states that every QSO it scores is with a host-area station. The
   host-area rule itself is Test_VermontOutOfStateWorksOnlyVermont's,
   against the real county file. *)
function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'CHI';
      end
   else
      begin
      Result.MyState := 'NY';
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

(* A DX ENTRANT SET UP THROUGH THE NEW CONTEST DIALOG, which takes 'DX' as
   the QTH of a station outside every area (uNewContestHostArea) -- so its
   MY STATE is 'DX', not empty. *)
function DXStationStatingDX(const aCountry: string): TStationContext;
begin
   Result := DXStation(aCountry);
   Result.MyState := 'DX';
end;

function VermontQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType;
                    const aQTH: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'W1XYZ';
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
   contestObject := MakeVermont(aStation);
   try
      qso := VermontQso(aBand, aMode, aExtMode, aQTH);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* THE RULES' COUNTY LIST, read from the sponsor's document as committed:
   vtqso.md, 7B(c), "14 Vermont Counties: ADD, BEN, ..., WNS." -- the codes
   between the colon and the full stop. *)
procedure ReadRulesCountyList(aCounties: TStringList);
var
   lines: TStringList;
   path: string;
   line: string;
   i: integer;
   colon: integer;
   stop: integer;
begin
   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
           '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
           'QSOParties' + PathDelim + 'Vermont' + PathDelim + 'vtqso.md';
   lines := TStringList.Create;
   try
      lines.LoadFromFile(path);
      for i := 0 to lines.Count - 1 do
         begin
         line := lines[i];
         colon := Pos('14 Vermont Counties:', line);
         if colon = 0 then
            begin
            Continue;
            end;
         line := Copy(line, colon + Length('14 Vermont Counties:'), Length(line));
         stop := Pos('.', line);
         line := Copy(line, 1, stop - 1);
         aCounties.Delimiter := ',';
         aCounties.StrictDelimiter := True;
         aCounties.DelimitedText := line;
         Break;
         end;
      for i := 0 to aCounties.Count - 1 do
         begin
         aCounties[i] := Trim(aCounties[i]);
         end;
   finally
      lines.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   IDENTITY
   --------------------------------------------------------------------------- *)

procedure TContestVermontQPTests.Test_VermontIdentity;
var
   h: TContestHandle;
   found: TContestHandle;
   identity: TContestBase;
   contestObject: TContestBase;
   member: ContestType;
   legacy: integer;
begin
   BeginTest('Test_VermontIdentity');
   CheckEquals('VT-QSO-PARTY', VT_QSO_PARTY_CONTEST_ID, 'the id constant');
   CheckTrue(FindContestById('VT-QSO-PARTY', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestVermontQP, 'to its class');
   CheckTrue(TContestVermontQP.ClassParent = TContestStateQSOPartyBase,
             'on the state-party base, directly: one host state, its counties, '
             + '"Stations outside Vermont work Vermont stations"');
   CheckEquals('VT-QSO-PARTY', ContestId(h), 'the stored id');

   identity := ContestIdentity(h);
   CheckFalse(TryLegacyContestOf(identity, member), 'a new contest has no ContestType member');
   CheckTrue(member = DUMMYCONTEST, 'so the walk names none');
   CheckFalse(ContestLegacyNumber(h, legacy), 'and no legacy number');

   CheckEquals('Vermont QSO Party', identity.DisplayName, 'display name');
   CheckEquals('Vermont QSO Party', identity.FriendlyName, 'friendly name');
   CheckEquals('VT-QSO-PARTY', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('VT-QSO-PARTY', identity.CabrilloContestName('2027 VTQP W1VT', 'X'),
               'the CONTEST: line, whatever the title');
   CheckEquals('VT-QSO-PARTY', identity.ADIFContestId, 'ADIF CONTEST_ID');
   CheckTrue(identity.WritesADIFContestId, 'export writes it');
   CheckTrue(FindContestByADIFContestId('VT-QSO-PARTY', found), 'import resolves it');
   CheckTrue(found = h, 'to the Vermont QSO Party');
   CheckEquals(0, identity.WA7BNMId, 'no WA7BNM ref (not found)');
   CheckEquals(0, identity.QRZRUId, 'no QRZ.RU id');
   (* "VTQSO logs to be submitted on line at this site" -- the web robot. *)
   CheckEquals('', identity.SubmissionEmail, 'no submission e-mail');
   CheckEquals('VT', identity.HostState, 'host state');
   CheckEquals('VT', identity.QSOPartyArea, 'the New Contest prompt names Vermont');
   CheckEquals('vermont_cty', identity.DomesticFileName, 'the county file');
   CheckEquals('vermont', identity.InStateDomesticFileName, 'the in-state file');
   CheckTrue(identity.IsUSQSOParty, 'a US QSO party');
   CheckTrue(identity.IsActive, 'active');
   CheckTrue(identity.MarksDupes, 'marks dupes');
   (* 10(B): "Logs must indicate the location ... Any log missing this
      information will not be acceptable." *)
   CheckTrue(identity.RequiresCabrilloLocation, 'the Cabrillo LOCATION is required');

   (* "Stations may be worked once per mode, per band"; "A multiplier can be
      counted only once per mode, regardless of the number of bands on which
      it is worked"; "VHF and UHF frequencies are allowed". *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode, cfMultByMode, cfVHFBandsEnabled],
             'dupes per band and mode, multipliers per mode, VHF on');
   CheckTrue(identity.QSOByBand, 'a station may be worked again on another band');
   CheckTrue(identity.QSOByMode, 'and again in another mode');
   CheckFalse(identity.MultByBand, 'a multiplier is NOT counted again per band');
   CheckTrue(identity.MultByMode, 'but IS counted again per mode');
   CheckTrue(identity.VHFBandsEnabled, '6 m and up');

   (* "(A) Vermont stations send signal report and Vermont county. (B) W/VE
      stations ... send signal report and state or province. (C) DX stations
      ... send signal report." *)
   CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(identity.ExchangeKind),
               'RST and a county, state or province; RST alone from DX');
   CheckEquals(Ord(NoInitialExchange), Ord(identity.InitialExchangeKind), 'no initial exchange');
   CheckTrue(identity.ExchangeCarriesDomesticQTH, 'the exchange carries a domestic QTH');
   CheckTrue(ContestUsesDomesticFile(identity), 'looked up in the domestic file');
   CheckTrue(ContestHasDomesticMultiplier(identity), 'the domestic QTH is the multiplier');

   (* WHAT THE PARTY BASE GIVES IT, pinned here so a base change is seen. *)
   CheckTrue(identity.StripsRoverCountyFromCall, 'a mobile''s /county is stripped live');
   CheckTrue(identity.SplitsRoverCallOnExport, 'and split on ADIF export');
   CheckTrue(identity.DupeKeyIncludesReceivedQTH, 'a mobile in a new county is a new station');
   CheckTrue(identity.WritesADIFCounty, 'CNTY is written');
   CheckEquals(2, (identity as TContestStateQSOPartyBase).CountyLineCountiesMax,
               '"2 QSO''s and 2 multipliers"');

   (* "For Vermont stations, the multipliers are: U.S. States, Canadian
      Provinces, DXCC Countries, Vermont Counties"; "For Non-Vermont
      stations: Vermont Counties". *)
   contestObject := MakeVermont(StationAt(True));
   try
      CheckTrue(contestObject.HasDXMultiplier, 'in VT: DXCC countries are multipliers');
      CheckTrue(ContestCountryMode(contestObject) = ARRLCountryMode,
                'on the "official ARRL DXCC listing"');
      CheckFalse(contestObject.HasZoneMultiplier, 'in VT: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'in VT: no prefix multiplier');
      CheckEquals(' 5NN CHI', contestObject.CQExchangeDefault(StationAt(True)),
                  'in VT, the CQ exchange sends the county');
   finally
      contestObject.Free;
   end;
   contestObject := MakeVermont(StationAt(False));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'outside VT: no DX multiplier');
      CheckTrue(ContestCountryMode(contestObject) = CQCountryMode, 'and the CQ list');
      CheckFalse(contestObject.HasZoneMultiplier, 'outside VT: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'outside VT: no prefix multiplier');
      CheckEquals(' 5NN NY', contestObject.CQExchangeDefault(StationAt(False)),
                  'outside VT, the state');
      (* "DX stations (including U.S. Territories) send signal report." *)
      CheckEquals(' 5NN', contestObject.CQExchangeDefault(DXStation('DL')),
                  'a DX entrant sends the signal report only');
      CheckEquals(' 5NN', contestObject.CQExchangeDefault(DXStation('KP4')),
                  'and so does a US territory');
      CheckEquals(' 5NN', contestObject.CQExchangeDefault(DXStationStatingDX('DL')),
                  'and a DX entrant whose MY STATE is the dialog''s DX: no "DX" on the air');
      CheckEquals(' 5NN', contestObject.CQExchangeDefault(DXStationStatingDX('dx')),
                  'however it is cased');
   finally
      contestObject.Free;
   end;
end;

(* 8): "Use of 30, 17 and 12 meters are prohibited except when operating
   FT8/FT4 on the recognized frequencies ... VHF and UHF frequencies are
   allowed ... Otherwise, operators may use any frequency allowed by their
   license". Every band but the three WARC bands -- and those in EVERY mode,
   FT8 included: UsesBand cannot see the mode (a gap, the class header). *)
procedure TContestVermontQPTests.Test_VermontBands;
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_VermontBands');
   identity := ContestIdentity(VermontHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := not (b in [Band30, Band17, Band12, AllBands, NoBand]);
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when not WARC');
      CheckTrue(ContestCreditsBand(identity, b) = expected,
                'band ' + IntToStr(Ord(b)) + ' through the one seam');
      end;
   CheckEquals(3, PointsFor(StationAt(False), Band160, CW, eCW, 'CHI'), '160 m CW scores');
   CheckEquals(3, PointsFor(StationAt(False), Band10, CW, eCW, 'CHI'), '10 m CW scores');
   CheckEquals(1, PointsFor(StationAt(False), Band6, Phone, eUSB, 'CHI'), '6 m scores');
   CheckEquals(1, PointsFor(StationAt(False), Band2, FM, eFM, 'CHI'), '2 m scores');
   CheckEquals(1, PointsFor(StationAt(False), Band432, FM, eFM, 'CHI'), '70 cm scores ("UHF")');
   CheckEquals(3, PointsFor(StationAt(False), Band1296, CW, eCW, 'CHI'), '23 cm scores');
   CheckEquals(0, PointsFor(StationAt(False), Band30, CW, eCW, 'CHI'), '30 m CW scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band17, Phone, eUSB, 'CHI'), '17 m SSB scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band12, CW, eCW, 'CHI'), '12 m CW scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band30, Digital, eFT8, 'CHI'),
               'NOT BUILT: 30 m FT8 scores nothing either (WARC FT8 is a gap)');
end;

(* 7A): "Each complete non-duplicate Phone contact is worth 1 point, per band.
   Each complete non-duplicate CW contact is worth 3 points ... Each complete
   RTTY contact is worth 2 points ... Each complete non-duplicate Digital
   contact is worth 2 points ... All digital modes (WSJTx) count as a single
   mode." FM is phone. The same for every entrant. *)
procedure TContestVermontQPTests.Test_VermontPoints;
begin
   BeginTest('Test_VermontPoints');
   CheckEquals(3, PointsFor(StationAt(False), Band20, CW, eCW, 'CHI'), 'outside VT, CW 3');
   CheckEquals(1, PointsFor(StationAt(False), Band20, Phone, eUSB, 'CHI'), 'outside VT, SSB 1');
   CheckEquals(1, PointsFor(StationAt(False), Band40, Phone, eLSB, 'CHI'), 'outside VT, LSB 1');
   CheckEquals(1, PointsFor(StationAt(False), Band80, Phone, eAM, 'CHI'), 'outside VT, AM 1');
   CheckEquals(1, PointsFor(StationAt(False), Band2, FM, eFM, 'RUT'), 'outside VT, FM is phone: 1');
   CheckEquals(2, PointsFor(StationAt(False), Band20, Digital, eRTTY, 'CHI'), 'outside VT, RTTY 2');
   CheckEquals(2, PointsFor(StationAt(False), Band40, Digital, ePSK31, 'CHI'), 'outside VT, PSK 2');
   CheckEquals(2, PointsFor(StationAt(False), Band20, Digital, eFT8, 'CHI'),
               'outside VT, FT8 2 (a digital QSO; its grid multiplier is not built)');
   CheckEquals(2, PointsFor(StationAt(False), Band20, Digital, eFT4, 'CHI'), 'outside VT, FT4 2');
   CheckEquals(3, PointsFor(StationAt(True), Band40, CW, eCW, 'NY'), 'in VT, CW with New York');
   CheckEquals(1, PointsFor(StationAt(True), Band40, Phone, eLSB, 'ON'), 'in VT, SSB with Ontario');
   CheckEquals(2, PointsFor(StationAt(True), Band20, Digital, eRTTY, 'ADD'), 'in VT, RTTY with Addison');
   CheckEquals(3, PointsFor(StationAt(True), Band15, CW, eCW, 'DL'),
               'in VT, a DX station scores ("Stations within Vermont work everyone")');
   CheckEquals(1, PointsFor(StationAt(True), Band15, Phone, eUSB, 'DL'), 'and 1 on phone');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Both, eNoMode, 'NY'), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(StationAt(True), Band20, NoMode, eNoMode, 'NY'), 'nor this one');
end;

(* 5): "Entrants may use any combination of modes." Every submode of every
   mode a contact is made in is credited -- no automatic X-QSO from a mode.
   Asked of the station-less identity, as every X-QSO reader asks it. *)
procedure TContestVermontQPTests.Test_VermontEveryModeIsCredited;
var
   identity: TContestBase;
   ext: ExtendedModeType;
   qso: ContestExchange;
begin
   BeginTest('Test_VermontEveryModeIsCredited');
   identity := ContestIdentity(VermontHandle);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckTrue(ContestCreditsMode(identity, Digital, ext),
                'digital submode ' + IntToStr(Ord(ext)) + ' is credited');
      qso := VermontQso(Band20, Digital, ext, 'CHI');
      CheckFalse(QSOIsXQSO(identity, qso),
                 'digital submode ' + IntToStr(Ord(ext)) + ' is no X-QSO');
      end;
   CheckTrue(ContestCreditsMode(identity, CW, eCW), 'CW is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eUSB), 'USB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eAM), 'AM is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eNoMode), 'phone with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM is credited');
   CheckTrue(ContestCreditsModeKey(identity, Digital), 'the Digital key is credited');
   CheckTrue(ContestCreditsModeKey(identity, CW), 'the CW key is');
   CheckTrue(ContestCreditsModeKey(identity, Phone), 'the Phone key is');
end;

(* 7B(f): "Special multiplier rules for FT8 and other WSJTx modes ... An FT8
   or FT4 contact cannot count for county multiplier credit", and the grid
   count is "added to any other non-grid-square multipliers worked on other
   digital modes" -- so a WSJT-X QSO earns no county, state, province or
   DXCC multiplier. Its grids are NOT BUILT (the class header). Every other
   digital submode counts. Asked through the nil-safe seam SetMultFlags
   asks. *)
procedure TContestVermontQPTests.Test_VermontWSJTXEarnsNoMultiplier;
var
   contestObject: TContestBase;
   ext: ExtendedModeType;
   qso: ContestExchange;
   kind: RemainingMultiplierType;
begin
   BeginTest('Test_VermontWSJTXEarnsNoMultiplier');
   contestObject := MakeVermont(StationAt(True));
   try
      for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
         begin
         qso := VermontQso(Band20, Digital, ext, 'ADD');
         for kind := rmDomestic to rmPrefix do
            begin
            CheckTrue(ContestCountsMultiplier(contestObject, qso, kind) = not (ext in WSJTX_SUBMODES),
                      'digital submode ' + IntToStr(Ord(ext)) + ' counts a multiplier exactly when not WSJT-X');
            end;
         CheckTrue(IsWSJTXQSO(qso) = (ext in WSJTX_SUBMODES),
                   'digital submode ' + IntToStr(Ord(ext)) + ' is WSJT-X exactly when listed');
         end;
      qso := VermontQso(Band20, Digital, eFT8, 'ADD');
      CheckFalse(ContestCountsMultiplier(contestObject, qso, rmDomestic),
                 '"An FT8 or FT4 contact cannot count for county multiplier credit"');
      CheckFalse(ContestCountsMultiplier(contestObject, qso, rmDX), 'nor a DXCC one');
      qso := VermontQso(Band20, Digital, eRTTY, 'ADD');
      CheckTrue(ContestCountsMultiplier(contestObject, qso, rmDomestic), 'an RTTY QSO counts its county');
      qso := VermontQso(Band20, CW, eNoMode, 'ADD');
      CheckTrue(ContestCountsMultiplier(contestObject, qso, rmDomestic), 'a CW QSO counts its county');
      (* The submode is only WSJT-X on a digital QSO. *)
      qso := VermontQso(Band20, CW, eFT8, 'ADD');
      CheckFalse(IsWSJTXQSO(qso), 'a CW record with a stray FT8 submode is CW');
   finally
      contestObject.Free;
   end;

   contestObject := MakeVermont(StationAt(False));
   try
      qso := VermontQso(Band20, Digital, eFT4, 'ADD');
      CheckFalse(ContestCountsMultiplier(contestObject, qso, rmDomestic),
                 'outside VT an FT4 QSO earns no county either');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   MULTIPLIERS
   --------------------------------------------------------------------------- *)

(* 7B(1): "For Vermont stations, the multipliers are: U.S. States, Canadian
   Provinces, DXCC Countries, Vermont Counties"; (a) "50 U.S. States ... DC
   is counted as MD"; (b) the 13 provinces and territories; (c) "14 Vermont
   Counties". The shipped vermont.dom through the real loader
   (InStateMultiplierOf follows its INCLUDEs), and the class's own
   CountsAsMultiplier (CountsForEntrant). *)
procedure TContestVermontQPTests.Test_VermontInStateMultipliers;
var
   h: TContestHandle;
   i: integer;
begin
   BeginTest('Test_VermontInStateMultipliers');
   h := VermontHandle;

   CheckEquals('CHI', InStateMultiplierOf(h, 'CHI'), 'Chittenden County is its own multiplier');
   CheckEquals('ADD', InStateMultiplierOf(h, 'ADD'), 'and Addison');
   CheckEquals('WNH', InStateMultiplierOf(h, 'WNH'), 'and Windham');
   CheckEquals('WNS', InStateMultiplierOf(h, 'WNS'), 'and Windsor, not Windham');
   CheckEquals('CAL', InStateMultiplierOf(h, 'CAL'), 'CAL is Caledonia County');
   CheckEquals('CA', InStateMultiplierOf(h, 'CA'), 'and California is CA');
   CheckEquals('WAS', InStateMultiplierOf(h, 'WAS'), 'WAS is Washington County');
   CheckEquals('WA', InStateMultiplierOf(h, 'WA'), 'and Washington state is WA');
   CheckEquals('AK', InStateMultiplierOf(h, 'AK'), 'Alaska is a state');
   CheckEquals('HI', InStateMultiplierOf(h, 'HI'), 'Hawaii is');
   CheckEquals('NY', InStateMultiplierOf(h, 'NY'), 'New York is');

   (* NOT BUILT (NY4I's ruling, DXLog's VTQP.txt): a county QSO also earning
      the state VT. One QSO carries one domestic key, so the county is the
      multiplier and VT is a separate one, earned only by a station that
      sends "VT" -- pinned so the day it is built is seen here. *)
   CheckEquals('VT', InStateMultiplierOf(h, 'VT'),
               '"50 U.S. States" -- Vermont among them, as its own key');
   CheckTrue(InStateMultiplierOf(h, 'CHI') <> InStateMultiplierOf(h, 'VT'),
             'NOT BUILT: a county is not the state VT (the gap)');

   (* "DC is counted as MD". *)
   CheckEquals('MD', InStateMultiplierOf(h, 'DC'), 'DC is Maryland''s multiplier');
   CheckEquals('MD', InStateMultiplierOf(h, 'MD'), 'as Maryland is');

   for i := Low(RULES_CANADIAN) to High(RULES_CANADIAN) do
      begin
      CheckEquals(RULES_CANADIAN[i], InStateMultiplierOf(h, RULES_CANADIAN[i]),
                  'the rules'' Canadian abbreviation ' + RULES_CANADIAN[i] + ' is its own multiplier');
      end;
   CheckEquals('NL', InStateMultiplierOf(h, 'NF'), 'NF is Newfoundland and Labrador');
   CheckEquals('NL', InStateMultiplierOf(h, 'LB'), 'and so is LB');
   CheckEquals('LA', InStateMultiplierOf(h, 'LA'), 'LA is Louisiana, not Labrador');

   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NY'), rmDomestic), 'New York counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'CHI'), rmDomestic), 'a county counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'DC'), rmDomestic), 'DC counts (as MD)');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NU'), rmDomestic), 'Nunavut counts');
   CheckTrue(CountsForEntrant(h, False, InStateMultiplierOf(h, 'CHI'), rmDomestic),
             'outside VT a county counts (the host-area rule is a separate question)');

   (* DXCC countries are the DX multiplier, not entries in the in-state
      file. *)
   CheckEquals('', InStateMultiplierOf(h, 'DX'), 'DX is no domestic multiplier');
   CheckEquals('', InStateMultiplierOf(h, 'DL'), 'nor a DX country');
end;

(* 7B(d): "DXCC Countries, as designated by the official ARRL DXCC listing.
   U.S., Canada, Alaska and Hawaii will not count as DXCC multipliers" --
   for Vermont stations only; "Non-Vermont stations: Vermont Counties". US
   territories are DX ("DX stations (including U.S. Territories)"). *)
procedure TContestVermontQPTests.Test_VermontInStateDXMultiplier;
var
   contestObject: TContestBase;

   function KeyFor(const aCountryID: string; out aKey: string): boolean;
   var
      qso: ContestExchange;
      key: DXMultiplierString;
   begin
      qso := VermontQso(Band20, CW, eCW, aCountryID);
      qso.QTH.CountryID := ShortString(aCountryID);
      Result := ContestDXMultiplierKey(contestObject, qso, key);
      aKey := string(key);
   end;

var
   key: string;
begin
   BeginTest('Test_VermontInStateDXMultiplier');
   contestObject := MakeVermont(StationAt(True));
   try
      CheckTrue(ContestHasDXMultiplier(contestObject), 'in VT there is a DX multiplier');
      CheckTrue(KeyFor('DL', key), 'Germany is a DX multiplier');
      CheckEquals('DL', key, 'keyed by its DXCC country');
      CheckTrue(KeyFor('JA', key), 'Japan is');
      CheckTrue(KeyFor('KP4', key), 'Puerto Rico, a US territory, is');
      CheckEquals('KP4', key, 'keyed KP4');
      CheckTrue(KeyFor('KH2', key), 'and Guam');
      CheckFalse(KeyFor('K', key), '"U.S. ... will not count": no key for the USA');
      CheckEquals('', key, 'and none written');
      CheckFalse(KeyFor('VE', key), '"Canada": none');
      CheckFalse(KeyFor('KH6', key), '"Hawaii": none');
      CheckFalse(KeyFor('KL', key), '"Alaska": none');
   finally
      contestObject.Free;
   end;

   contestObject := MakeVermont(StationAt(False));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'outside VT there is no DX multiplier');
      CheckFalse(KeyFor('DL', key), 'so no key for Germany');
   finally
      contestObject.Free;
   end;

   contestObject := MakeVermont(DXStation('DL'));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'a DX entrant has none either');
      CheckFalse(KeyFor('JA', key), 'so no key for Japan');
   finally
      contestObject.Free;
   end;
end;

(* 1): "Stations outside Vermont work Vermont stations"; 7B(2): "For
   Non-Vermont stations: Vermont Counties". Q107: an out-of-state entrant's
   QSO with a station the session's table (the shipped vermont_cty.dom,
   through the real loader) does not know is refused when typed, and scores
   0 with no multiplier when logged any other way. *)
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
   Result.MyState := 'NY';
   Result.MyCountry := 'K';
end;

function ParseOutOfState(const aQTH: string; out aMessage: string): boolean;
var
   contestObject: TContestBase;
   exch: ContestExchange;
begin
   GShapeSetsQTH := aQTH;
   contestObject := MakeVermont(OutOfStateStation);
   try
      exch := Default(ContestExchange);
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, ParseSession, exch, aMessage);
   finally
      contestObject.Free;
   end;
end;

procedure TContestVermontQPTests.Test_VermontOutOfStateWorksOnlyVermont;
var
   msg: string;
   contestObject: TContestBase;
   qso: ContestExchange;
   counties: TStringList;
   i: integer;
   code: string;
begin
   BeginTest('Test_VermontOutOfStateWorksOnlyVermont');
   counties := TStringList.Create;
   LoadCountyTable('vermont_cty.dom', True);
   try
      (* EVERY ONE OF THE RULES' 14 COUNTIES is its own multiplier and a
         station this entrant may work. *)
      ReadRulesCountyList(counties);
      CheckEquals(14, counties.Count, 'the rules list 14 counties');
      CheckEquals(14, mo.DomList.Count, 'the county file is 14 multipliers');
      for i := 0 to counties.Count - 1 do
         begin
         code := counties[i];
         CheckEquals(code, MultiplierOf(CountyTable, code), code + ' is its own multiplier');
         CheckTrue(CountyFileKnowsQTH(code), code + ' is a Vermont station');
         end;

      (* TYPED: a county is taken; anything else is refused with the
         party's reason. *)
      CheckTrue(ParseOutOfState('CHI', msg), 'outside VT, a Chittenden County station');
      CheckEquals('', msg, 'nothing to say');
      CheckTrue(ParseOutOfState('wnh', msg), 'Windham, typed in lower case');
      CheckFalse(ParseOutOfState('NY', msg), 'outside VT, a New York station: refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['VT']), msg, 'with the reason');
      CheckFalse(ParseOutOfState('ON', msg), 'an Ontario station: refused');
      CheckFalse(ParseOutOfState('VT', msg),
                 'VT alone is no county: "Vermont stations send signal report and Vermont county"');
      CheckFalse(ParseOutOfState('DL', msg), 'a DX station: refused');

      (* LOGGED: the same rule scores 0 and earns no multiplier. *)
      CheckEquals(3, PointsFor(OutOfStateStation, Band20, CW, eCW, 'RUT'), 'logged: a county scores');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'NY'), 'logged: New York scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'DL'), 'logged: DX scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, ''), 'logged: no QTH scores 0');
      (* THE FT8 GAP: a WSJT-X QSO carries a grid, not a county, so the
         host-area rule refuses it -- although the rules credit it (7B(f),
         "the total number of Vermont grid squares worked"). Pinned so the
         day the grid exchange is built is seen here. *)
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, Digital, eFT8, 'FN34'),
                  'NOT BUILT: an FT8 QSO logged with a Vermont grid scores 0 outside VT');
      CheckEquals(2, PointsFor(OutOfStateStation, Band20, Digital, eFT8, 'ORL'),
                  'an FT8 QSO logged with a county scores 2');

      contestObject := MakeVermont(OutOfStateStation);
      try
         qso := VermontQso(Band20, CW, eCW, 'NY');
         CheckFalse(ContestCreditsWorkedStation(contestObject, qso),
                    'and earns no multiplier (the predicate SetMultFlags asks)');
         CheckTrue(QSOIsXQSO(contestObject, qso),
                   'an automatic X-QSO, judged with the entrant (Q119)');
         qso := VermontQso(Band20, CW, eCW, 'CHI');
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

(* 7B(c): "Vermont stations on a county line may be claimed as a QSO and a
   multiplier from each county (2 QSO's and 2 multipliers)." One or two
   pass; three are refused. The engine half is the real-engine test's. *)
procedure TContestVermontQPTests.Test_VermontCountyLineIsTwoCounties;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
   n: integer;
begin
   BeginTest('Test_VermontCountyLineIsTwoCounties');
   contestObject := MakeVermont(NoStation);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(2, party.CountyLineCountiesMax, 'two counties on a line');
      CheckTrue(party.CountyLineAllowed, 'a county line is allowed');
      for n := 1 to 2 do
         begin
         CheckTrue(party.ValidateQTHCount(n, msg), IntToStr(n) + ' counties are taken');
         CheckEquals('', msg, 'nothing to say about ' + IntToStr(n));
         end;
      CheckFalse(party.ValidateQTHCount(3, msg), 'three are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), msg, 'with the county-count message');
   finally
      contestObject.Free;
   end;
end;

(* 9(D): "Stations may be worked once per mode, per band. i.e., WC4E may be
   worked on 20 CW, 20 SSB, and 20 digital for credit"; 7A: "All digital
   modes (WSJTx) count as a single mode" -- so every digital submode is ONE
   dupe mode (the base's identity DupeModeOf). Mobiles in a new county are
   new stations (the party base's received-QTH dupe key). The band and mode
   halves are the real engine's, below. *)
procedure TContestVermontQPTests.Test_VermontDupes;
var
   newCountyIsDupe: boolean;
   sameCountyIsDupe: boolean;
begin
   BeginTest('Test_VermontDupes');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(VermontHandle)),
             'the received county is part of the dupe key');
   CheckTrue(ContestDupeModeOf(ContestIdentity(VermontHandle), Digital) = Digital,
             'Digital is its own dupe mode');
   CheckTrue(ContestDupeModeOf(ContestIdentity(VermontHandle), CW) = CW, 'CW its own');
   CheckTrue(ContestDupeModeOf(ContestIdentity(VermontHandle), Phone) = Phone, 'and Phone its own');
   RoverDupeAnswers(VermontHandle, 'W1VT', 'CHI', 'ADD', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'W1VT from Addison after Chittenden, 20 m CW: a new station');
   CheckTrue(sameCountyIsDupe, 'W1VT from Chittenden again, 20 m CW: a dupe');
   RoverDupeAnswers(VermontHandle, 'W1VT/M', 'RUT', 'WNS', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'a /M call from Windsor after Rutland: a new station');
   CheckTrue(sameCountyIsDupe, 'and from Rutland again: a dupe');
end;

(* 7D(1): "If all QSO's were made using 5W or less, multiply your score by 2
   / ... more than 5W and less than or equal to 150W output, multiply your
   score by 1.5 / ... more than 150W, multiply your score by 1"; 4): "Logs
   not showing power output category will be listed as high power". LOW is
   ROUNDED with FPC's Round, half to EVEN -- the convention of the other
   1.5 factors (Stew Perry, Makrothen); the sponsor states none. *)
procedure TContestVermontQPTests.Test_VermontPowerMultiplier;
begin
   BeginTest('Test_VermontPowerMultiplier');
   CheckEquals(1400, VermontScoreWithPower(700, cpQRP), 'QRP doubles');
   CheckEquals(1050, VermontScoreWithPower(700, cpLOW), 'LOW is x1.5');
   CheckEquals(700, VermontScoreWithPower(700, cpHIGH), 'HIGH is x1');
   CheckEquals(700, VermontScoreWithPower(700, cpUNSET), 'no category is high power: x1');
   CheckEquals(14, VermontScoreWithPower(9, cpLOW), 'LOW 9 x 1.5 = 13.5 rounds to the even 14');
   CheckEquals(22, VermontScoreWithPower(15, cpLOW), 'LOW 15 x 1.5 = 22.5 rounds to the even 22');
   CheckEquals(0, VermontScoreWithPower(0, cpQRP), 'nothing stays nothing');
end;

(* 7D: "Final Score = Total Points X Total Multipliers X Power Multiplier".
   For a Vermont entrant the multipliers are the domestic ones (counties,
   states, provinces) PLUS the DXCC countries; for anyone else the
   counties. No bonus (the club multiplier and the FT8 grids are not built). *)
procedure TContestVermontQPTests.Test_VermontScoreIsPointsTimesMultipliersTimesPower;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_VermontScoreIsPointsTimesMultipliersTimesPower');
   t := Default(TScoreTotals);
   t.QSOPoints := 1001;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 60;
   t.Mults[AllBands, Both, rmDX] := 5;

   station := StationAt(True);
   station.MyPower := cpHIGH;
   view := TLoggedQSOList.Create;
   contestObject := MakeVermont(station);
   try
      CheckEquals(1001 * 65, contestObject.FinalScore(t, view),
                  'HIGH: points x (domestic + DX multipliers)');
      station.MyPower := cpQRP;
      contestObject.SetStation(station);
      CheckEquals(1001 * 65 * 2, contestObject.FinalScore(t, view), 'QRP: x2');
      station.MyPower := cpLOW;
      contestObject.SetStation(station);
      (* 1001 x 65 = 65065, x 1.5 = 97597.5 -- rounded to the even 97598. *)
      CheckEquals(97598, contestObject.FinalScore(t, view), 'LOW: x1.5, rounded half to even');
      station.MyPower := cpUNSET;
      contestObject.SetStation(station);
      CheckEquals(1001 * 65, contestObject.FinalScore(t, view), 'no power category: x1');
      CheckEquals(0, contestObject.BonusPoints(t, view), 'no bonus');

      (* Outside Vermont: "Vermont Counties". *)
      station := StationAt(False);
      station.MyPower := cpQRP;
      contestObject.SetStation(station);
      t.QSOPoints := 120;
      t.Mults[AllBands, Both, rmDomestic] := 14;
      t.Mults[AllBands, Both, rmDX] := 0;
      CheckEquals(120 * 14 * 2, contestObject.FinalScore(t, view), 'outside VT, QRP: points x counties x 2');

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

(* vermont_cty.dom IS THE RULES' LIST (7B(c), "14 Vermont Counties: ADD, BEN,
   CAL, CHI, ESS, FRA, GRA, LAM, ORA, ORL, RUT, WAS, WNH, WNS"): each code
   once, each its OWN multiplier, and nothing else -- no INCLUDE, so an
   out-of-state entrant's table holds only counties. The names are the
   counties' own (the rules give codes only). *)
procedure TContestVermontQPTests.Test_VermontCountyFileIsTheRulesList;
var
   rulesList: TStringList;
   lines: TStringList;
   seen: TStringList;
   i: integer;
   key: string;
   line: string;
begin
   BeginTest('Test_VermontCountyFileIsTheRulesList');
   rulesList := TStringList.Create;
   lines := TStringList.Create;
   seen := TStringList.Create;
   try
      ReadRulesCountyList(rulesList);
      CheckEquals(14, rulesList.Count, 'the rules list 14 counties');

      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      lines.LoadFromFile(ShippedDomDir + 'vermont_cty.dom');
      for i := 0 to lines.Count - 1 do
         begin
         line := lines[i];
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
         CheckTrue(rulesList.IndexOf(key) >= 0, key + ' is in the rules'' list');
         CheckEquals(1, Pos(key + ' = ' + key + ',^', line),
                     'its own multiplier and its own alias: ' + line);
         end;
      CheckEquals(14, seen.Count, 'vermont_cty.dom holds the 14 counties and nothing else');
   finally
      seen.Free;
      lines.Free;
      rulesList.Free;
   end;

   (* AS A VERMONT STATION READS IT (MultipliersIsCounties False): still 14
      multipliers, not one. *)
   LoadCountyTable('vermont_cty.dom', False);
   try
      CheckEquals(14, mo.DomList.Count, 'in state, the 14 counties are 14 multipliers');
      CheckEquals('CHI', MultiplierOf(CountyTable, 'CHI'), 'Chittenden counts as Chittenden');
      CheckEquals('', MultiplierOf(CountyTable, 'VT'), 'no state is in the county file');
      CheckEquals('', MultiplierOf(CountyTable, 'NY'), 'nor New York');
   finally
      FreeCountyTable;
   end;
end;

(* vermont.dom, read as text: the header holds no '='; the counties first;
   then "DC is counted as MD" as Dc > Md, BEFORE S50.DOM; then S50.DOM and
   P13.DOM (S50 first, so LA stays Louisiana); and Nl = NF,LB. Then through
   the real loader: 14 counties + 50 states (DC is MD) + 13 provinces and
   territories = 77 domestic multipliers. *)
procedure TContestVermontQPTests.Test_VermontInStateFileIsTheRulesMultipliers;
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
   BeginTest('Test_VermontInStateFileIsTheRulesMultipliers');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(ShippedDomDir + 'vermont.dom');
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
                       'vermont.dom line ' + IntToStr(i + 1)
                       + ' is an INCLUDE the loader would not follow');
            if inHeader then
               begin
               CheckEquals(0, Pos('=', lines[i]),
                           'vermont.dom header line ' + IntToStr(i + 1)
                           + ' would be read as an entry');
               end
            else if Pos('=', lines[i]) > 0 then
               begin
               entries := entries + Trim(lines[i]) + '|';
               end;
            end;
         end;
      CheckEquals('VERMONT_CTY.DOM S50.DOM P13.DOM ', includes,
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
      LoadShippedDomFollowingIncludes(table, 'vermont.dom', True, 0);
      CheckEquals(77, mo.DomList.Count,
                  '14 counties, 50 states (DC counted as MD) and 13 provinces and territories');
      CheckEquals('VT', MultiplierOf(table, 'VT'), 'Vermont is one of the 50 states');
      CheckEquals('CHI', MultiplierOf(table, 'CHI'),
                  'the counties are loaded first, so a county keeps its own code');
      CheckEquals('CAL', MultiplierOf(table, 'CAL'), 'CAL is Caledonia, not California');
      CheckEquals('MD', MultiplierOf(table, 'DC'), 'DC is Maryland');
      CheckEquals('NL', MultiplierOf(table, 'NF'), 'NF is Newfoundland and Labrador');
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

(* THE RULES GIVE NO EXAMPLE LINE. 10(C): "Logs must indicate band, mode,
   date, time in UTC, calls, sent exchange (signal report and
   state/county/province/DXCC prefix) and received exchange (signal report
   and state/county/province/DXCC prefix)" -- pinned in that order on the
   standard QSO line. A DX station's received column is its prefix ("contest
   software will determine the DXCC country and list the official prefix"),
   not DXLog's "DX". A DX entrant's Cabrillo sent column is its own prefix;
   its STX_STRING is what it transmitted, the RST alone. *)
procedure TContestVermontQPTests.Test_VermontCabrilloColumns;
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
                        2027, 2, 6, aHour, aMinute, aCall]);
   end;

begin
   BeginTest('Test_VermontCabrilloColumns');
   CheckEquals('VT-QSO-PARTY', ContestIdentity(VermontHandle).CabrilloContestName('', ''),
               'CONTEST: VT-QSO-PARTY');

   (* A CHITTENDEN COUNTY STATION WORKS NEW YORK. *)
   contestObject := MakeVermont(StationAt(True));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'CHI';
      qso := VermontQso(Band40, CW, eCW, 'NY');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'NY';

      firstPart := FirstPartOf('7035', 13, 1, 'W1VT');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 CHI    ', sent, 'sent: RST and my county');
      CheckEquals('599 NY     ', received, 'received: RST and the state received');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'W2AAA', received, '']);
      CheckEquals(Words('QSO: 7035 CW 2027-02-06 1301 W1VT 599 CHI W2AAA 599 NY'), Words(line),
                  'band, mode, date, time, calls, sent and received, in the rules'' order: ' + line);
      CheckEquals(CabrilloQSOLineFormatDefault, contestObject.CabrilloQSOLineFormat,
                  'the standard QSO line, no extra column');
      CheckEquals('599 CHI    ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my county');

      (* PHONE, with Ontario. *)
      ctx.RSTSent := '59';
      ctx.RSTReceived := '59';
      ctx.HisQTH := 'ON';
      qso := VermontQso(Band20, Phone, eUSB, 'ON');
      CheckEquals('PH', contestObject.CabrilloModeString(Phone, eUSB), 'SSB is PH');
      CheckEquals('59  CHI    ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent on phone: RS and my county');
      CheckEquals('59  ON     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: RS and the province');

      (* A DX STATION: what was typed, else the DXCC prefix the call
         resolved to. *)
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'DL';
      qso := VermontQso(Band20, CW, eCW, 'DL');
      CheckEquals('599 DL     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'a DX station''s prefix, as typed');
      qso := VermontQso(Band20, CW, eCW, '');
      qso.DXQTH := 'DL';
      ctx.HisQTH := '';
      CheckEquals('599 DL     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'RST alone: the DXCC prefix TR4W determined, not "DX"');
   finally
      contestObject.Free;
   end;

   (* A NEW YORK ENTRANT WORKS CHITTENDEN COUNTY. *)
   contestObject := MakeVermont(StationAt(False));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'NY';
      qso := VermontQso(Band40, CW, eCW, 'CHI');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'CHI';
      firstPart := FirstPartOf('7035', 19, 30, 'W2AAA');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'W1VT', received, '']);
      CheckEquals(Words('QSO: 7035 CW 2027-02-06 1930 W2AAA 599 NY W1VT 599 CHI'), Words(line),
                  'the out-of-state line: ' + line);
      CheckEquals('599 NY     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my state');
   finally
      contestObject.Free;
   end;

   (* A DX ENTRANT: "DX stations (including U.S. Territories) send signal
      report" -- and the log's sent column is its "DXCC prefix" (10(C)). *)
   contestObject := MakeVermont(DXStation('DL'));
   try
      my := Default(TMyStationExchange);
      my.MyState := '';
      qso := VermontQso(Band20, CW, eCW, 'CHI');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'CHI';
      firstPart := FirstPartOf('14041', 20, 15, 'DL1AAA');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 DL     ', sent, 'Cabrillo sent: RST and my DXCC prefix');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'W1VT', received, '']);
      CheckEquals(Words('QSO: 14041 CW 2027-02-06 2015 DL1AAA 599 DL W1VT 599 CHI'), Words(line),
                  'the DX entrant''s line: ' + line);
      CheckEquals('599        ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: what was transmitted, the RST alone');
   finally
      contestObject.Free;
   end;

   (* THE SAME ENTRANT SET UP THROUGH NEW CONTEST: MY STATE is 'DX'. The
      columns are the same -- 'DX' is never sent nor written as a location. *)
   contestObject := MakeVermont(DXStationStatingDX('DL'));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'DX';
      qso := VermontQso(Band20, CW, eCW, 'CHI');
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'CHI';
      CheckEquals('599 DL     ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'MY STATE DX: the Cabrillo sent column is still my DXCC prefix');
      CheckEquals('599        ', contestObject.FormatADIFSentExchange(my, qso),
                  'MY STATE DX: the STX_STRING is still the RST alone');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet. First a New
   York entrant with the shipped vermont_cty.dom, then a Chittenden County
   entrant with the shipped vermont.dom (its INCLUDEs followed by
   uTestShippedDom, since the test binary has no dom folder).
   --------------------------------------------------------------------------- *)

procedure TContestVermontQPTests.Test_VermontRealEngine;
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
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;

   (* ONE QSO, AS AN OPERATOR ENTERS IT: ParametersOkay, then what
      LogContact does with the record it accepts -- the dupe question, the
      dupe's zero points, the sheets. The submode is the record's, as the
      radio or WSJT-X would leave it. Returns whether it was a dupe. *)


begin
   BeginTest('Test_VermontRealEngine');
   h := VermontHandle;
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
      (* AS FoundContest SETS IT UP FOR A NEW YORK STATION: not in Vermont,
         so the county file with each county its own multiplier; K, VE, KH6
         and KL are domestic countries; and the class's flags, as
         ApplyContestTraits writes them. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := True;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'vermont_cty.dom'),
                'vermont_cty.dom loads');
      Contest := h;
      ReleaseActiveContest;
      StationInHostState := False;
      Settings.Qso.ByBand := ContestIdentity(h).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(h).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* CHITTENDEN COUNTY, CW. *)
      dupe := EnterPartyQSO('W1CHI', '599 CHI', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 CHI is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('CHI', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the county');
      CheckTrue(rx.DomesticMult, 'Chittenden is a new multiplier');
      CheckEquals(3, Integer(rx.QSOPoints), '"CW contact is worth 3 points"');

      (* "A multiplier can be counted only once per mode, regardless of the
         number of bands"; "Stations may be worked once per mode, per
         band". *)
      dupe := EnterPartyQSO('W1CHI', '599 CHI', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores 3');
      CheckFalse(rx.DomesticMult, 'but Chittenden is NOT a new multiplier on another band');

      dupe := EnterPartyQSO('W1CHI', '59 CHI', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '59 CHI on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), '"Phone contact is worth 1 point"');
      CheckTrue(rx.DomesticMult, 'and Chittenden IS a new multiplier in another mode');

      dupe := EnterPartyQSO('W1CHI', '599 CHI', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'RTTY is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m RTTY is not a dupe ("20 digital")');
      CheckEquals(2, Integer(rx.QSOPoints), '"RTTY contact is worth 2 points"');
      CheckTrue(rx.DomesticMult, 'and Chittenden is a new multiplier in digital');

      dupe := EnterPartyQSO('W1CHI', '599 CHI', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'FT8 is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(dupe, 'FT8 after RTTY on 20 m IS a dupe: "All digital modes ... a single mode"');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      dupe := EnterPartyQSO('W1CHI', '599 CHI', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'Chittenden again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      (* FM is phone: on one band it is the same dupe mode as SSB, and its
         multiplier the phone one. *)
      dupe := EnterPartyQSO('W1VHF', '59 RUT', Band2, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '2 m SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), '2 m phone scores 1');
      CheckTrue(rx.DomesticMult, 'Rutland is a new phone multiplier');
      dupe := EnterPartyQSO('W1VHF', '59 RUT', Band2, FM, eFM, accepted, rx);
      CheckTrue(accepted, '2 m FM is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(dupe, 'the same station on 2 m FM after SSB IS a dupe: FM is phone');
      dupe := EnterPartyQSO('W1FM', '59 RUT', Band432, FM, eFM, accepted, rx);
      CheckTrue(accepted, '70 cm FM is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'another station on 70 cm FM is not a dupe');
      CheckFalse(rx.DomesticMult, 'and Rutland on FM is no new multiplier: FM is phone');

      (* "Stations may be worked once per mode, per band" -- a mobile in a
         new county is a new station. *)
      dupe := EnterPartyQSO('W1CHI', '599 ADD', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same call from Addison on 20 m CW: a new station');
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores');
      CheckTrue(rx.DomesticMult, 'Addison is a new multiplier');

      (* 7B(f): "An FT8 or FT4 contact cannot count for county multiplier
         credit" -- logged, 2 points, no multiplier; Orleans stays unworked
         in digital until a non-WSJT-X QSO with it. *)
      dupe := EnterPartyQSO('W1FT', '599 ORL', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'an FT8 QSO with a county is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(QSOIsXQSO(ContestIdentity(h), rx), 'and is no X-QSO');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckFalse(rx.DomesticMult, 'and earns no county multiplier');
      dupe := EnterPartyQSO('W1FT2', '599 ORL', Band40, Digital, ePSK31, accepted, rx);
      CheckTrue(rx.DomesticMult, 'so Orleans on 40 m PSK is still a new digital multiplier');

      (* WARC: logged, an automatic X-QSO -- FT8 included (the gap). *)
      dupe := EnterPartyQSO('W1WRC', '599 ESS', Band30, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a 30 m QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO ("30, 17 and 12 meters are prohibited")');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and Essex is no multiplier from it');

      (* "Stations outside Vermont work Vermont stations." *)
      DomesticQTHRefusalDomDir := ShippedDomDir;
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := 'vermont_cty.dom';

      accepted := True;
      EnterPartyQSO('W2NY', '599 NY', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a New York station is refused');
      CheckEquals('Improper domestic QTH!! (NY: work VT stations only)',
                  string(ExchangeErrorMessage),
                  'as an improper QTH, with the host-area reason');

      accepted := True;
      EnterPartyQSO('W1ABC', '599 CHX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a misspelt county is refused');
      CheckEquals('Improper domestic QTH!! (CHX not in vermont_cty.dom)',
                  string(ExchangeErrorMessage),
                  'as not in the county file');

      accepted := True;
      EnterPartyQSO('DL1AAA', '599', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a DX station is refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['VT']), string(ExchangeErrorMessage),
                  'with the host-area reason');

      (* THE FT8 GAP, typed: the WSJT-X exchange is a grid, which the county
         file does not know. *)
      accepted := True;
      EnterPartyQSO('W1GRD', 'FN34', Band20, Digital, eFT8, accepted, rx);
      CheckFalse(accepted, 'NOT BUILT: an FT8 QSO sending a Vermont grid is refused outside VT');

      (* 7B(c): "2 QSO's and 2 multipliers" for a county line. *)
      ClearPendingCounties;
      dupe := EnterPartyQSO('W1LINE', '599 LAM/ORL', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a two-county line is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('LAM', UpperCase(string(rx.QTHString)), 'the first county is this QSO');
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores 3');
      CheckEquals(1, PendingCountiesCount, 'the second county is queued');
      CheckEquals('ORL', UpperCase(DequeuePendingCounty), 'Orleans, as its own QSO');
      ClearPendingCounties;
      accepted := True;
      EnterPartyQSO('W1LINE', '599 LAM/ORL/FRA', Band15, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'three counties are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), string(ExchangeErrorMessage),
                  'with the county-count message');
      CheckEquals(0, PendingCountiesCount, 'and nothing is queued');
      ClearPendingCounties;

      (* Q119: THE SAME REFUSED QSO, ARRIVING LOGGED, is an automatic X-QSO
         for this entrant. *)
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      rx.Callsign := 'W2NY';
      rx.Band := Band20;
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.Frequency := 14025000;
      rx.RSTSent := 599;
      rx.RSTReceived := 599;
      rx.QTHString := 'NY';
      rx.tSysTime.qtYear := 27;
      rx.tSysTime.qtMonth := 2;
      rx.tSysTime.qtDay := 6;
      ActiveContest(Contest);
      CheckTrue(LoggedQSOIsXQSO(rx), 'out of state, a logged W2NY NY is an X-QSO');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'and its Cabrillo line says so');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx),
                 'and it counts toward no total');
      rx.QTHString := 'CHI';
      CheckFalse(LoggedQSOIsXQSO(rx), 'out of state, a logged Chittenden QSO is not');

      (* NOW A CHITTENDEN COUNTY ENTRANT: in Vermont, vermont.dom (the
         counties, the states, the provinces), each county its own
         multiplier; and DXCC countries. *)
      MultipliersIsCounties := False;
      LoadShippedDomFollowingIncludes(DomQTHTable, 'vermont.dom', True, 0);
      StationInHostState := True;
      Settings.Contest.DomesticFilename := 'vermont.dom';
      ReleaseActiveContest;
      ActiveContest(Contest);
      mo.ClearAllMults;

      dupe := EnterPartyQSO('W2AAA', '599 NY', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in VT, 599 NY is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores 3');
      CheckTrue(rx.DomesticMult, 'New York is a new multiplier');
      dupe := EnterPartyQSO('W2BBB', '599 NY', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'New York on 40 m CW is no new multiplier: once per mode');
      dupe := EnterPartyQSO('W2AAA', '59 NY', Band40, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'New York on 40 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), 'and scores 1');
      CheckTrue(rx.DomesticMult, 'and IS a new multiplier: another mode');

      dupe := EnterPartyQSO('W1BBB', '599 CHI', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'another Chittenden station is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('CHI', UpperCase(string(rx.DomMultQTH)), 'its multiplier is the county');
      CheckTrue(rx.DomesticMult, 'and Chittenden is a new multiplier: "14 Vermont Counties"');

      (* NOT BUILT (NY4I's ruling): the county did not also earn VT, so a
         station sending VT is still a new multiplier. *)
      dupe := EnterPartyQSO('W1CCC', '599 VT', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 VT is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('VT', UpperCase(string(rx.DomMultQTH)), 'its multiplier is VT');
      CheckTrue(rx.DomesticMult, 'NOT BUILT: VT is still new after a county QSO (the gap)');

      dupe := EnterPartyQSO('W3DC', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 DC is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), '"DC is counted as MD"');
      CheckTrue(rx.DomesticMult, 'a new multiplier, Maryland');
      dupe := EnterPartyQSO('W3MD', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), 'Maryland itself');
      CheckFalse(rx.DomesticMult, 'is then no new multiplier');

      dupe := EnterPartyQSO('VO1AAA', '599 NL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NL is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NL', UpperCase(string(rx.DomMultQTH)), 'NL is Newfoundland and Labrador');
      CheckTrue(rx.DomesticMult, 'a new multiplier');

      dupe := EnterPartyQSO('KH6AAA', '599 HI', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 HI is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Hawaii is a state multiplier ("W/VE stations (including ... Hawaii)")');
      CheckFalse(rx.DXMult, 'and not a DX one');

      (* "DX stations (including U.S. Territories) send signal report" --
         RST ALONE is taken, and the DXCC country is the multiplier. *)
      dupe := EnterPartyQSO('DL1AAA', '599', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in VT, a DX station sending 599 alone is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(599, Integer(rx.RSTReceived), 'with its signal report');
      CheckEquals(3, Integer(rx.QSOPoints), 'for 3 points');
      CheckFalse(rx.DomesticMult, 'no domestic multiplier');
      CheckTrue(rx.DXMult, 'and Germany is a new DX multiplier');
      CheckEquals('DL', string(rx.DXQTH), 'keyed by its DXCC country');
      CheckFalse(LoggedQSOIsXQSO(rx), 'and in state it is no X-QSO');
      (* "Properly configured contest software will determine the DXCC
         country and list the official prefix" -- the received column. *)
      my := Default(TMyStationExchange);
      my.MyState := 'CHI';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := '';
      CheckEquals('599 DL     ', ActiveContest(Contest).FormatCabrilloReceivedExchange(my, rx, ctx),
                  'the Cabrillo received column is the DXCC prefix');

      (* AN EMPTY EXCHANGE from a DX call is refused today (the engine's RST
         and QTH parser takes nothing from nothing): the operator types the
         RST. Whether a blank exchange should be taken is NY4I's call --
         pinned so a change is seen. *)
      accepted := True;
      EnterPartyQSO('JA1EMP', '', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a DX call with an EMPTY exchange is refused: type the RST');

      dupe := EnterPartyQSO('DL2BBB', '59', Band40, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, 'a German station on SSB, 59 alone: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DXMult, 'Germany IS a new multiplier on phone: once per mode');
      dupe := EnterPartyQSO('DL3CCC', '599', Band15, CW, eCW, accepted, rx);
      CheckFalse(rx.DXMult, 'Germany again on CW is no new multiplier');

      dupe := EnterPartyQSO('KP4AA', '599', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a KP4 station is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DXMult, '"DX stations (including U.S. Territories)": Puerto Rico is a DX multiplier');

      dupe := EnterPartyQSO('JA1FT', '-10', Band20, Digital, eFT8, accepted, rx);
      CheckFalse(rx.DXMult, 'a Japanese FT8 QSO earns no DXCC multiplier (7B(f))');
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

procedure TContestVermontQPTests.RunAllTests;
begin
   Test_VermontIdentity;
   Test_VermontBands;
   Test_VermontPoints;
   Test_VermontEveryModeIsCredited;
   Test_VermontWSJTXEarnsNoMultiplier;
   Test_VermontInStateMultipliers;
   Test_VermontInStateDXMultiplier;
   Test_VermontOutOfStateWorksOnlyVermont;
   Test_VermontCountyLineIsTwoCounties;
   Test_VermontDupes;
   Test_VermontPowerMultiplier;
   Test_VermontScoreIsPointsTimesMultipliersTimesPower;
   Test_VermontCountyFileIsTheRulesList;
   Test_VermontInStateFileIsTheRulesMultipliers;
   Test_VermontCabrilloColumns;
   Test_VermontRealEngine;
end;

end.

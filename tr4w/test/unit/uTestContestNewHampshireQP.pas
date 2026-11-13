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

(* THE NEW HAMPSHIRE QSO PARTY -- added 2026-11-10 (#112), registered by its
  id (NH-QSO-PARTY). The rules are docs/ContestRules/QSOParties/NewHampshire/
  (NHQP_Rules.pdf, the 2026 rules, and its transcription
  NH-QSO-PARTY-Rules.txt, which the data tests read). Each test below quotes
  the rule it holds. Written from ADDING_A_CONTEST.md Part A5, copying
  uTestContestVermontQP's shape; nothing is assumed from another party's
  rules.

  WHAT IS PINNED
    * its identity: the id, no legacy number, the names, the files, the
      flags, the party base and what it inherits;
    * multipliers per band OUTSIDE New Hampshire and once INSIDE it -- the
      session's MultByBand, stated both ways;
    * its bands (80, 40, 20, 15, 10 m) and its points through ScoreQSO (CW
      2, phone 1); CW and phone credited, digital an automatic X-QSO;
    * the in-state entrant's multipliers (the shipped newhampshire.dom
      through the real loader): the 10 counties, the states with DC as MD
      (a question), the 13 provinces and territories; NH itself is none;
    * the in-state DX multiplier (DXCC but K, VE, KH6 and KL) and none
      outside, and the score's cap of 10 DXCC;
    * the out-of-state entrant's multipliers and the host-area rule, against
      the shipped newhampshire_cty.dom;
    * a county line of two (a question), the dupe rules and the mobile's new
      county;
    * a DX entrant sends DX, whether its MY STATE is empty or the New Contest
      dialog's DX;
    * the two .dom files against the rules' county list;
    * the Cabrillo columns (the rules give no example line);
    * NOT BUILT, pinned so the day it is built is seen: the contest period;
    * THROUGH THE REAL ENGINE (ParametersOkay and the multiplier sheet): an
      out-of-state entrant, then an in-state one, each with the MultByBand
      its own DescribeSession states. *)
unit uTestContestNewHampshireQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNewHampshireQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NewHampshireIdentity;
      procedure Test_NewHampshireMultipliersPerBandOnlyOutside;
      procedure Test_NewHampshireBands;
      procedure Test_NewHampshirePoints;
      procedure Test_NewHampshireModesAreCWAndPhone;
      procedure Test_NewHampshireInStateMultipliers;
      procedure Test_NewHampshireInStateDXMultiplier;
      procedure Test_NewHampshireOutOfStateWorksOnlyNewHampshire;
      procedure Test_NewHampshireCountyLineIsTwoCounties;
      procedure Test_NewHampshireDupes;
      procedure Test_NewHampshireScoreCountsAtMostTenDXCC;
      procedure Test_NewHampshireContestPeriodIsNotBuilt;
      procedure Test_NewHampshireCountyFileIsTheRulesList;
      procedure Test_NewHampshireInStateFileIsTheRulesMultipliers;
      procedure Test_NewHampshireCabrilloColumns;
      procedure Test_NewHampshireRealEngine;
   end;

implementation

uses
   (* cpQRP. Before VC, so VC's names win where they overlap. *)
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
   uContestNewHampshireQP,
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
   (* The 13 Canadian provinces and territories -- "each Canadian province";
      the codes DXLog's NHQP.txt and P13.DOM use. *)
   CANADIAN: array[0..12] of string = (
      'AB', 'BC', 'MB', 'NB', 'NL', 'NS', 'NT', 'NU', 'ON', 'PE', 'QC', 'SK', 'YT');

function NewHampshireHandle: TContestHandle;
begin
   if not FindContestById(NH_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('NH-QSO-PARTY is not registered');
      end;
end;

function MakeNewHampshire(const aStation: TStationContext): TContestBase;
begin
   Result := Make(NewHampshireHandle, aStation);
end;

(* A New Hampshire station (Hillsborough County) or a New York one. The table
   knows every QTH (uTestContestObjects.WithHostAreaTable): a test about
   POINTS states that every QSO it scores is with a host-area station. The
   host-area rule itself is Test_NewHampshireOutOfStateWorksOnlyNewHampshire's,
   against the real county file. *)
function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'HIL';
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

function NewHampshireQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType;
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
   contestObject := MakeNewHampshire(aStation);
   try
      qso := NewHampshireQso(aBand, aMode, aExtMode, aQTH);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* WHAT THE CONTEST STATES FOR THE SESSION at aStation -- as FoundContest
   asks it. The caller frees it. *)
function Describe(const aStation: TStationContext): TSessionDefaults;
var
   contestObject: TContestBase;
begin
   Result := TSessionDefaults.Create;
   contestObject := MakeNewHampshire(aStation);
   try
      contestObject.DescribeSession(aStation, Result);
   finally
      contestObject.Free;
   end;
end;

(* THE RULES' COUNTY LIST, read from the transcription as committed:
   NH-QSO-PARTY-Rules.txt, "NH Counties (Abbreviations):", then one line per
   county, "Belknap (BEL)", up to the next blank line. Each entry is
   'BEL=Belknap'. *)
procedure ReadRulesCountyList(aCounties: TStringList);
var
   lines: TStringList;
   path: string;
   line: string;
   i: integer;
   paren: integer;
   inList: boolean;
begin
   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
           '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
           'QSOParties' + PathDelim + 'NewHampshire' + PathDelim +
           'NH-QSO-PARTY-Rules.txt';
   lines := TStringList.Create;
   try
      lines.LoadFromFile(path);
      inList := False;
      for i := 0 to lines.Count - 1 do
         begin
         line := Trim(lines[i]);
         if line = 'NH Counties (Abbreviations):' then
            begin
            inList := True;
            Continue;
            end;
         if not inList then
            begin
            Continue;
            end;
         if line = '' then
            begin
            if aCounties.Count > 0 then
               begin
               Break;
               end;
            Continue;
            end;
         paren := Pos(' (', line);
         if (paren = 0) or (line[Length(line)] <> ')') then
            begin
            Break;
            end;
         aCounties.Add(Copy(line, paren + 2, Length(line) - paren - 2) + '=' +
                       Copy(line, 1, paren - 1));
         end;
   finally
      lines.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   IDENTITY
   --------------------------------------------------------------------------- *)

procedure TContestNewHampshireQPTests.Test_NewHampshireIdentity;
var
   h: TContestHandle;
   found: TContestHandle;
   identity: TContestBase;
   contestObject: TContestBase;
   member: ContestType;
   legacy: integer;
begin
   BeginTest('Test_NewHampshireIdentity');
   CheckEquals('NH-QSO-PARTY', NH_QSO_PARTY_CONTEST_ID, 'the id constant');
   CheckTrue(FindContestById('NH-QSO-PARTY', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestNewHampshireQP, 'to its class');
   CheckTrue(TContestNewHampshireQP.ClassParent = TContestStateQSOPartyBase,
             'on the state-party base, directly: one host state, its counties, '
             + '"Stations outside of NH contact as many NH stations as possible"');
   CheckEquals('NH-QSO-PARTY', ContestId(h), 'the stored id');

   identity := ContestIdentity(h);
   CheckFalse(TryLegacyContestOf(identity, member), 'a new contest has no ContestType member');
   CheckTrue(member = DUMMYCONTEST, 'so the walk names none');
   CheckFalse(ContestLegacyNumber(h, legacy), 'and no legacy number');

   (* NOT THE NEW ENGLAND QSO PARTY: its own id, names and files. *)
   CheckFalse(FindContestById('NEWEQP', found) and (found = h), 'not New England''s id');

   CheckEquals('New Hampshire QSO Party', identity.DisplayName, 'display name');
   CheckEquals('New Hampshire QSO Party', identity.FriendlyName, 'friendly name');
   CheckEquals('NH-QSO-PARTY', identity.CabrilloName, 'Cabrillo CONTEST: (DXLog''s)');
   CheckEquals('NH-QSO-PARTY', identity.CabrilloContestName('2026 NHQP W1NH', 'X'),
               'the CONTEST: line, whatever the title');
   CheckEquals('NH-QSO-PARTY', identity.ADIFContestId, 'ADIF CONTEST_ID (the 3.1.6 enumeration)');
   CheckTrue(identity.WritesADIFContestId, 'export writes it');
   CheckTrue(FindContestByADIFContestId('NH-QSO-PARTY', found), 'import resolves it');
   CheckTrue(found = h, 'to the New Hampshire QSO Party');
   CheckEquals(0, identity.WA7BNMId, 'no WA7BNM ref (not found)');
   CheckEquals(0, identity.QRZRUId, 'no QRZ.RU id');
   (* "Submit logs at https://w1wqm.org/submit-log.php" -- a web form. *)
   CheckEquals('', identity.SubmissionEmail, 'no submission e-mail');
   CheckEquals('NH', identity.HostState, 'host state');
   CheckEquals('NH', identity.QSOPartyArea, 'the New Contest prompt names New Hampshire');
   CheckEquals('newhampshire_cty', identity.DomesticFileName, 'the county file');
   CheckEquals('newhampshire', identity.InStateDomesticFileName, 'the in-state file');
   CheckTrue(identity.IsUSQSOParty, 'a US QSO party');
   CheckTrue(identity.IsActive, 'active');
   CheckTrue(identity.MarksDupes, 'marks dupes');
   CheckFalse(identity.RequiresCabrilloLocation, 'the rules require no Cabrillo LOCATION');

   (* "Work Stations: Once per band per mode"; "Non-NH Stations: Each NH
      county once per band" -- the identity carries the out-of-state answer;
      DescribeSession states the in-state one (the next test). Never per
      mode; no band above 10 m. *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode, cfMultByBand],
             'dupes per band and mode, multipliers per band');
   CheckTrue(identity.QSOByBand, 'a station may be worked again on another band');
   CheckTrue(identity.QSOByMode, 'and again in another mode');
   CheckTrue(identity.MultByBand, 'a county is counted again per band (outside NH)');
   CheckFalse(identity.MultByMode, 'but NOT again per mode');
   CheckFalse(identity.VHFBandsEnabled, 'no VHF');

   (* "NH: RS(T) + County / non-NH W/VE: RS(T) + (State/Province) / DX:
      RS(T) + "DX"". *)
   CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(identity.ExchangeKind),
               'RST and a county, state or province; DX from DX');
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
               'a county line of two (QUESTION on #112)');

   (* "NH Stations: Each NH county, each state, each Canadian province and up
      to 10 DXCC country"; "Non-NH Stations: Each NH county". *)
   contestObject := MakeNewHampshire(StationAt(True));
   try
      CheckTrue(contestObject.HasDXMultiplier, 'in NH: DXCC countries are multipliers');
      CheckTrue(ContestCountryMode(contestObject) = ARRLCountryMode, 'on the ARRL DXCC list');
      CheckFalse(contestObject.HasZoneMultiplier, 'in NH: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'in NH: no prefix multiplier');
      CheckEquals(' 5NN HIL', contestObject.CQExchangeDefault(StationAt(True)),
                  'in NH, the CQ exchange sends the county');
   finally
      contestObject.Free;
   end;
   contestObject := MakeNewHampshire(StationAt(False));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'outside NH: no DX multiplier');
      CheckTrue(ContestCountryMode(contestObject) = CQCountryMode, 'and the CQ list');
      CheckFalse(contestObject.HasZoneMultiplier, 'outside NH: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'outside NH: no prefix multiplier');
      CheckEquals(' 5NN NY', contestObject.CQExchangeDefault(StationAt(False)),
                  'outside NH, the state');
      (* "DX: RS(T) + "DX"". *)
      CheckEquals(' 5NN DX', contestObject.CQExchangeDefault(DXStation('DL')),
                  'a DX entrant with no MY STATE sends DX');
      CheckEquals(' 5NN DX', contestObject.CQExchangeDefault(DXStationStatingDX('DL')),
                  'and so does one whose MY STATE is the dialog''s DX');
   finally
      contestObject.Free;
   end;
end;

(* "NH Stations: Each NH county, each state, each Canadian province and up to
   10 DXCC country once. Non-NH Stations: Each NH county once per band." The
   session's MultByBand, stated BOTH ways (design D8), and MultByMode never. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireMultipliersPerBandOnlyOutside;
var
   session: TSessionDefaults;
begin
   BeginTest('Test_NewHampshireMultipliersPerBandOnlyOutside');
   session := Describe(StationAt(True));
   try
      CheckTrue(session.IsStated(svMultByBand), 'in NH: MultByBand is stated');
      CheckFalse(session.MultByBand, 'in NH: every multiplier counts ONCE, not per band');
      CheckFalse(session.IsStated(svExchange), 'the exchange is the identity''s');
   finally
      session.Free;
   end;
   session := Describe(StationAt(False));
   try
      CheckTrue(session.IsStated(svMultByBand), 'outside NH: MultByBand is stated');
      CheckTrue(session.MultByBand, 'outside NH: each county once PER BAND');
   finally
      session.Free;
   end;
   session := Describe(DXStationStatingDX('DL'));
   try
      CheckTrue(session.IsStated(svMultByBand) and session.MultByBand,
                'a DX entrant is a non-NH station: per band');
   finally
      session.Free;
   end;
end;

(* "80m through 10m, except WARC bands (12m, 17m, 30m)": 80, 40, 20, 15 and
   10 m, nothing else -- not 160 m, not 6 m (DXLog's 50 and 144 MHz lose to
   the rules). *)
procedure TContestNewHampshireQPTests.Test_NewHampshireBands;
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_NewHampshireBands');
   identity := ContestIdentity(NewHampshireHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band80, Band40, Band20, Band15, Band10];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when 80-10 m without WARC');
      CheckTrue(ContestCreditsBand(identity, b) = expected,
                'band ' + IntToStr(Ord(b)) + ' through the one seam');
      end;
   CheckEquals(2, PointsFor(StationAt(False), Band80, CW, eCW, 'HIL'), '80 m CW scores');
   CheckEquals(2, PointsFor(StationAt(False), Band10, CW, eCW, 'HIL'), '10 m CW scores');
   CheckEquals(0, PointsFor(StationAt(False), Band160, CW, eCW, 'HIL'), '160 m scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band6, Phone, eUSB, 'HIL'), '6 m scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band2, FM, eFM, 'HIL'), '2 m scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band30, CW, eCW, 'HIL'), '30 m scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band17, Phone, eUSB, 'HIL'), '17 m scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band12, CW, eCW, 'HIL'), '12 m scores nothing');
end;

(* "QSO Point Credit: 1 Point per phone QSO; 2 points per CW QSO." FM is
   phone. The same for every entrant. *)
procedure TContestNewHampshireQPTests.Test_NewHampshirePoints;
begin
   BeginTest('Test_NewHampshirePoints');
   CheckEquals(2, PointsFor(StationAt(False), Band20, CW, eCW, 'HIL'), 'outside NH, CW 2');
   CheckEquals(1, PointsFor(StationAt(False), Band20, Phone, eUSB, 'HIL'), 'outside NH, SSB 1');
   CheckEquals(1, PointsFor(StationAt(False), Band40, Phone, eLSB, 'HIL'), 'outside NH, LSB 1');
   CheckEquals(1, PointsFor(StationAt(False), Band80, Phone, eAM, 'HIL'), 'outside NH, AM 1');
   CheckEquals(1, PointsFor(StationAt(False), Band10, FM, eFM, 'ROC'), 'outside NH, FM is phone: 1');
   CheckEquals(2, PointsFor(StationAt(True), Band40, CW, eCW, 'NY'), 'in NH, CW with New York');
   CheckEquals(1, PointsFor(StationAt(True), Band40, Phone, eLSB, 'ON'), 'in NH, SSB with Ontario');
   CheckEquals(2, PointsFor(StationAt(True), Band15, CW, eCW, 'DL'),
               'in NH, a DX station scores ("NH Stations contact ... DXCC countries")');
   CheckEquals(1, PointsFor(StationAt(True), Band15, Phone, eUSB, 'DL'), 'and 1 on phone');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Both, eNoMode, 'NY'), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(StationAt(True), Band20, NoMode, eNoMode, 'NY'), 'nor this one');
end;

(* "Modes: CW/Phone". CW, phone and FM are credited; a digital QSO, in any
   submode (DXLog's RTTY included), is an automatic X-QSO: 0 points, no
   multiplier. Asked of the station-less identity, as every X-QSO reader
   asks it. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireModesAreCWAndPhone;
var
   identity: TContestBase;
   ext: ExtendedModeType;
   qso: ContestExchange;
begin
   BeginTest('Test_NewHampshireModesAreCWAndPhone');
   identity := ContestIdentity(NewHampshireHandle);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'digital submode ' + IntToStr(Ord(ext)) + ' is not credited');
      qso := NewHampshireQso(Band20, Digital, ext, 'HIL');
      CheckTrue(QSOIsXQSO(identity, qso),
                'digital submode ' + IntToStr(Ord(ext)) + ' is an X-QSO');
      end;
   CheckTrue(ContestCreditsMode(identity, CW, eCW), 'CW is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eUSB), 'USB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eAM), 'AM is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eNoMode), 'phone with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM is credited (phone)');
   CheckFalse(ContestCreditsModeKey(identity, Digital), 'the Digital key is not');
   CheckTrue(ContestCreditsModeKey(identity, CW), 'the CW key is');
   CheckTrue(ContestCreditsModeKey(identity, Phone), 'the Phone key is');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Digital, eRTTY, 'NY'), 'an RTTY QSO scores 0');
   CheckEquals(0, PointsFor(StationAt(False), Band20, Digital, eFT8, 'HIL'), 'an FT8 QSO scores 0');
end;

(* ---------------------------------------------------------------------------
   MULTIPLIERS
   --------------------------------------------------------------------------- *)

(* "NH Stations: Each NH county, each state, each Canadian province ...".
   The shipped newhampshire.dom through the real loader (InStateMultiplierOf
   follows its INCLUDEs), and the class's own CountsAsMultiplier
   (CountsForEntrant). *)
procedure TContestNewHampshireQPTests.Test_NewHampshireInStateMultipliers;
var
   h: TContestHandle;
   i: integer;
begin
   BeginTest('Test_NewHampshireInStateMultipliers');
   h := NewHampshireHandle;

   CheckEquals('HIL', InStateMultiplierOf(h, 'HIL'), 'Hillsborough County is its own multiplier');
   CheckEquals('BEL', InStateMultiplierOf(h, 'BEL'), 'and Belknap');
   CheckEquals('COO', InStateMultiplierOf(h, 'COO'), 'and Coos');
   CheckEquals('CAR', InStateMultiplierOf(h, 'CAR'), 'CAR is Carroll County');
   CheckEquals('CA', InStateMultiplierOf(h, 'CA'), 'and California is CA');
   CheckEquals('MER', InStateMultiplierOf(h, 'MER'), 'MER is Merrimack County');
   CheckEquals('ME', InStateMultiplierOf(h, 'ME'), 'and Maine is ME');
   CheckEquals('AK', InStateMultiplierOf(h, 'AK'), 'Alaska is a state');
   CheckEquals('HI', InStateMultiplierOf(h, 'HI'), 'Hawaii is');
   CheckEquals('NY', InStateMultiplierOf(h, 'NY'), 'New York is');
   CheckEquals('VT', InStateMultiplierOf(h, 'VT'), 'Vermont is');

   (* QUESTION (#112): "each state" is silent on DC. Built as Maryland --
      DXLog's "MD=Maryland DC"; N1MM, the sponsor's logger, takes no DC. *)
   CheckEquals('MD', InStateMultiplierOf(h, 'DC'), 'DC is Maryland''s multiplier (a question)');
   CheckEquals('MD', InStateMultiplierOf(h, 'MD'), 'as Maryland is');

   for i := Low(CANADIAN) to High(CANADIAN) do
      begin
      CheckEquals(CANADIAN[i], InStateMultiplierOf(h, CANADIAN[i]),
                  'the Canadian abbreviation ' + CANADIAN[i] + ' is its own multiplier');
      end;
   CheckEquals('NL', InStateMultiplierOf(h, 'NF'), 'NF is Newfoundland and Labrador');
   CheckEquals('NL', InStateMultiplierOf(h, 'LB'), 'and so is LB');
   CheckEquals('LA', InStateMultiplierOf(h, 'LA'), 'LA is Louisiana, not Labrador');

   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NY'), rmDomestic), 'New York counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'HIL'), rmDomestic), 'a county counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'DC'), rmDomestic), 'DC counts (as MD)');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NU'), rmDomestic), 'Nunavut counts');
   CheckTrue(CountsForEntrant(h, False, InStateMultiplierOf(h, 'HIL'), rmDomestic),
             'outside NH a county counts (the host-area rule is a separate question)');

   (* RULING -- "NH: RS(T) + County": a New Hampshire station sends its
      county, never NH, and DXLog's states omit NH. S50.DOM still knows NH,
      so the class refuses it as an in-state entrant's multiplier. *)
   CheckEquals('NH', InStateMultiplierOf(h, 'NH'), 'S50.DOM knows NH');
   CheckFalse(CountsForEntrant(h, True, 'NH', rmDomestic), 'but NH is no multiplier for an NH entrant');
   CheckFalse(CountsForEntrant(h, True, 'nh', rmDomestic), 'however it is cased');
   CheckTrue(CountsForEntrant(h, True, 'NH', rmDX), 'the refusal is the domestic kind''s only');

   (* DXCC countries are the DX multiplier, not entries in the in-state
      file. *)
   CheckEquals('', InStateMultiplierOf(h, 'DX'), 'DX is no domestic multiplier');
   CheckEquals('', InStateMultiplierOf(h, 'DL'), 'nor a DX country');
end;

(* "NH Stations: ... up to 10 DXCC country" -- for NH stations only; "Non-NH
   Stations: Each NH county". Every DXCC country but the USA, Canada, Hawaii
   and Alaska, whose stations are states and provinces (DXLog's MULT3
   excludes the same four); US territories are DX. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireInStateDXMultiplier;
var
   contestObject: TContestBase;

   function KeyFor(const aCountryID: string; out aKey: string): boolean;
   var
      qso: ContestExchange;
      key: DXMultiplierString;
   begin
      qso := NewHampshireQso(Band20, CW, eCW, 'DX');
      qso.QTH.CountryID := ShortString(aCountryID);
      Result := ContestDXMultiplierKey(contestObject, qso, key);
      aKey := string(key);
   end;

var
   key: string;
begin
   BeginTest('Test_NewHampshireInStateDXMultiplier');
   contestObject := MakeNewHampshire(StationAt(True));
   try
      CheckTrue(ContestHasDXMultiplier(contestObject), 'in NH there is a DX multiplier');
      CheckTrue(KeyFor('DL', key), 'Germany is a DX multiplier');
      CheckEquals('DL', key, 'keyed by its DXCC country');
      CheckTrue(KeyFor('JA', key), 'Japan is');
      CheckTrue(KeyFor('KP4', key), 'Puerto Rico, a US territory, is');
      CheckEquals('KP4', key, 'keyed KP4');
      CheckFalse(KeyFor('K', key), 'no key for the USA (its states are multipliers)');
      CheckEquals('', key, 'and none written');
      CheckFalse(KeyFor('VE', key), 'nor Canada (its provinces are)');
      CheckFalse(KeyFor('KH6', key), 'nor Hawaii (a state)');
      CheckFalse(KeyFor('KL', key), 'nor Alaska (a state)');
   finally
      contestObject.Free;
   end;

   contestObject := MakeNewHampshire(StationAt(False));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'outside NH there is no DX multiplier');
      CheckFalse(KeyFor('DL', key), 'so no key for Germany');
   finally
      contestObject.Free;
   end;

   contestObject := MakeNewHampshire(DXStation('DL'));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'a DX entrant has none either');
      CheckFalse(KeyFor('JA', key), 'so no key for Japan');
   finally
      contestObject.Free;
   end;
end;

(* "Stations outside of NH contact as many NH stations as possible"; "Non-NH
   Stations: Each NH county once per band". Q107: an out-of-state entrant's
   QSO with a station the session's table (the shipped newhampshire_cty.dom,
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
   contestObject := MakeNewHampshire(OutOfStateStation);
   try
      exch := Default(ContestExchange);
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, ParseSession, exch, aMessage);
   finally
      contestObject.Free;
   end;
end;

procedure TContestNewHampshireQPTests.Test_NewHampshireOutOfStateWorksOnlyNewHampshire;
var
   msg: string;
   contestObject: TContestBase;
   qso: ContestExchange;
   counties: TStringList;
   i: integer;
   code: string;
begin
   BeginTest('Test_NewHampshireOutOfStateWorksOnlyNewHampshire');
   counties := TStringList.Create;
   LoadCountyTable('newhampshire_cty.dom', True);
   try
      (* EVERY ONE OF THE RULES' 10 COUNTIES is its own multiplier and a
         station this entrant may work. *)
      ReadRulesCountyList(counties);
      CheckEquals(10, counties.Count, 'the rules list 10 counties');
      CheckEquals(10, mo.DomList.Count, 'the county file is 10 multipliers');
      for i := 0 to counties.Count - 1 do
         begin
         code := counties.Names[i];
         CheckEquals(code, MultiplierOf(CountyTable, code), code + ' is its own multiplier');
         CheckTrue(CountyFileKnowsQTH(code), code + ' is a New Hampshire station');
         end;

      (* TYPED: a county is taken; anything else is refused with the
         party's reason. *)
      CheckTrue(ParseOutOfState('HIL', msg), 'outside NH, a Hillsborough County station');
      CheckEquals('', msg, 'nothing to say');
      CheckTrue(ParseOutOfState('sul', msg), 'Sullivan, typed in lower case');
      CheckFalse(ParseOutOfState('NY', msg), 'outside NH, a New York station: refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['NH']), msg, 'with the reason');
      CheckFalse(ParseOutOfState('ON', msg), 'an Ontario station: refused');
      CheckFalse(ParseOutOfState('NH', msg), 'NH alone is no county: "NH: RS(T) + County"');
      CheckFalse(ParseOutOfState('DX', msg), 'a DX station: refused');

      (* LOGGED: the same rule scores 0 and earns no multiplier. *)
      CheckEquals(2, PointsFor(OutOfStateStation, Band20, CW, eCW, 'ROC'), 'logged: a county scores');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'NY'), 'logged: New York scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'DX'), 'logged: DX scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, ''), 'logged: no QTH scores 0');

      contestObject := MakeNewHampshire(OutOfStateStation);
      try
         qso := NewHampshireQso(Band20, CW, eCW, 'NY');
         CheckFalse(ContestCreditsWorkedStation(contestObject, qso),
                    'and earns no multiplier (the predicate SetMultFlags asks)');
         CheckTrue(QSOIsXQSO(contestObject, qso),
                   'an automatic X-QSO, judged with the entrant (Q119)');
         qso := NewHampshireQso(Band20, CW, eCW, 'HIL');
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

(* QUESTION (#112): THE RULES ARE SILENT ON COUNTY LINES. Built as two:
   DXLog takes a received county with one '/' and scores "one QSO per
   county, own and worked". One or two pass; three are refused. The engine
   half is the real-engine test's. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireCountyLineIsTwoCounties;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
   n: integer;
begin
   BeginTest('Test_NewHampshireCountyLineIsTwoCounties');
   contestObject := MakeNewHampshire(NoStation);
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

(* "Work Stations: Once per band per mode". A mobile or portable station "may
   operate from one or more counties": in a new county it is a new station
   (the party base's received-QTH dupe key; DXLog's
   DOUBLE_QSO=PER_BAND_MODE_RCVD). CW and phone are their own dupe modes. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireDupes;
var
   newCountyIsDupe: boolean;
   sameCountyIsDupe: boolean;
begin
   BeginTest('Test_NewHampshireDupes');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(NewHampshireHandle)),
             'the received county is part of the dupe key');
   CheckTrue(ContestDupeModeOf(ContestIdentity(NewHampshireHandle), CW) = CW, 'CW is its own dupe mode');
   CheckTrue(ContestDupeModeOf(ContestIdentity(NewHampshireHandle), Phone) = Phone, 'and Phone its own');
   RoverDupeAnswers(NewHampshireHandle, 'W1NH', 'HIL', 'MER', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'W1NH from Merrimack after Hillsborough, 20 m CW: a new station');
   CheckTrue(sameCountyIsDupe, 'W1NH from Hillsborough again, 20 m CW: a dupe');
   RoverDupeAnswers(NewHampshireHandle, 'W1NH/M', 'GRA', 'COO', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'a /M call from Coos after Grafton: a new station');
   CheckTrue(sameCountyIsDupe, 'and from Grafton again: a dupe');
end;

(* "Total score = total QSO points x total multipliers"; "NH Stations: ...
   up to 10 DXCC country". The DXCC count in the score is at most 10; the
   counties, states and provinces are not capped. No power multiplier, no
   bonus. Outside NH: "Maximum multiplier count: 50 (10 counties per band, 5
   bands)" -- the sheet's own count, pinned in the real-engine test. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireScoreCountsAtMostTenDXCC;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_NewHampshireScoreCountsAtMostTenDXCC');
   CheckEquals(10, NH_QSO_PARTY_MAXIMUM_DX_MULTIPLIERS, '"up to 10 DXCC country"');
   t := Default(TScoreTotals);
   t.QSOPoints := 500;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 60;

   station := StationAt(True);
   station.MyPower := cpHIGH;
   view := TLoggedQSOList.Create;
   contestObject := MakeNewHampshire(station);
   try
      t.Mults[AllBands, Both, rmDX] := 9;
      CheckEquals(500 * 69, contestObject.FinalScore(t, view), '9 DXCC: all 9 count');
      t.Mults[AllBands, Both, rmDX] := 10;
      CheckEquals(500 * 70, contestObject.FinalScore(t, view), '10 DXCC: all 10 count');
      t.Mults[AllBands, Both, rmDX] := 11;
      CheckEquals(500 * 70, contestObject.FinalScore(t, view), '11 DXCC: only 10 count');
      t.Mults[AllBands, Both, rmDX] := 40;
      CheckEquals(500 * 70, contestObject.FinalScore(t, view), '40 DXCC: only 10 count');
      t.Mults[AllBands, Both, rmDomestic] := 75;
      CheckEquals(500 * 85, contestObject.FinalScore(t, view), 'the domestic multipliers are not capped');
      CheckEquals(0, contestObject.BonusPoints(t, view), 'no bonus');

      station.MyPower := cpQRP;
      contestObject.SetStation(station);
      CheckEquals(500 * 85, contestObject.FinalScore(t, view), 'no power multiplier: QRP is x1');
      station.MyPower := cpLOW;
      contestObject.SetStation(station);
      CheckEquals(500 * 85, contestObject.FinalScore(t, view), 'and LOW is x1');

      (* Outside New Hampshire: "Each NH county once per band". *)
      contestObject.SetStation(StationAt(False));
      t.QSOPoints := 120;
      t.Mults[AllBands, Both, rmDomestic] := 50;
      t.Mults[AllBands, Both, rmDX] := 0;
      CheckEquals(120 * 50, contestObject.FinalScore(t, view), 'outside NH: points x (county, band) pairs');
      t.Mults[AllBands, Both, rmDomestic] := 0;
      CheckEquals(0, contestObject.FinalScore(t, view), 'no multiplier, no score');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* NOT BUILT -- THE CONTEST PERIOD: "1600 UTC Saturday to 0400 UTC Sunday;
   1200 UTC to 2200 UTC Sunday". TR4W has no contest schedule (design Q99),
   so a QSO in the Sunday 0400-1200 UTC gap scores like any other and is no
   X-QSO. Pinned so the day the schedule is built is seen here: this test
   then fails and is rewritten to the rule. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireContestPeriodIsNotBuilt;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_NewHampshireContestPeriodIsNotBuilt');
   contestObject := MakeNewHampshire(StationAt(False));
   try
      qso := NewHampshireQso(Band40, CW, eCW, 'HIL');
      qso.tSysTime.qtYear := 26;
      qso.tSysTime.qtMonth := 9;
      qso.tSysTime.qtDay := 20;
      qso.tSysTime.qtHour := 8;
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      CheckEquals(2, Integer(qso.QSOPoints),
                  'NOT BUILT: a QSO at 0800 UTC Sunday, between the sessions, still scores 2');
      CheckFalse(QSOIsXQSO(contestObject, qso), 'NOT BUILT: and is no X-QSO');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   DATA
   --------------------------------------------------------------------------- *)

(* newhampshire_cty.dom IS THE RULES' LIST ("NH Counties (Abbreviations):
   Belknap (BEL) ... Sullivan (SUL)"): each code once, each its OWN
   multiplier, named as the rules name it, and nothing else -- no INCLUDE,
   so an out-of-state entrant's table holds only counties. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireCountyFileIsTheRulesList;
var
   rulesList: TStringList;
   lines: TStringList;
   seen: TStringList;
   i: integer;
   key: string;
   line: string;
begin
   BeginTest('Test_NewHampshireCountyFileIsTheRulesList');
   rulesList := TStringList.Create;
   lines := TStringList.Create;
   seen := TStringList.Create;
   try
      ReadRulesCountyList(rulesList);
      CheckEquals(10, rulesList.Count, 'the rules list 10 counties');

      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      lines.LoadFromFile(ShippedDomDir + 'newhampshire_cty.dom');
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
         CheckTrue(rulesList.IndexOfName(key) >= 0, key + ' is in the rules'' list');
         CheckEquals(key + ' = ' + key + ',^' + rulesList.Values[key], line,
                     'its own multiplier, its own alias and the rules'' name: ' + line);
         end;
      CheckEquals(10, seen.Count, 'newhampshire_cty.dom holds the 10 counties and nothing else');
   finally
      seen.Free;
      lines.Free;
      rulesList.Free;
   end;

   (* AS A NEW HAMPSHIRE STATION READS IT (MultipliersIsCounties False):
      still 10 multipliers, not one. *)
   LoadCountyTable('newhampshire_cty.dom', False);
   try
      CheckEquals(10, mo.DomList.Count, 'in state, the 10 counties are 10 multipliers');
      CheckEquals('HIL', MultiplierOf(CountyTable, 'HIL'), 'Hillsborough counts as Hillsborough');
      CheckEquals('', MultiplierOf(CountyTable, 'NH'), 'no state is in the county file');
      CheckEquals('', MultiplierOf(CountyTable, 'NY'), 'nor New York');
   finally
      FreeCountyTable;
   end;
end;

(* newhampshire.dom, read as text: the header holds no '='; the counties
   first; then DC as Maryland (Dc > Md, a question), BEFORE S50.DOM; then
   S50.DOM and P13.DOM (S50 first, so LA stays Louisiana); and Nl = NF,LB.
   Then through the real loader: 10 counties + 50 states (DC is MD; NH among
   them, refused by the class) + 13 provinces and territories = 73. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireInStateFileIsTheRulesMultipliers;
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
   BeginTest('Test_NewHampshireInStateFileIsTheRulesMultipliers');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(ShippedDomDir + 'newhampshire.dom');
      includes := '';
      entries := '';
      inHeader := True;
      for i := 0 to lines.Count - 1 do
         begin
         included := DomIncludeName(lines[i]);
         if included <> '' then
            begin
            inHeader := False;
            includes := includes + included + ' ';
            end
         else
            begin
            CheckFalse(Pos('INCLUDE', UpperCase(TrimLeft(lines[i]))) = 1,
                       'newhampshire.dom line ' + IntToStr(i + 1)
                       + ' is an INCLUDE the loader would not follow');
            if inHeader then
               begin
               CheckEquals(0, Pos('=', lines[i]),
                           'newhampshire.dom header line ' + IntToStr(i + 1)
                           + ' would be read as an entry');
               end
            else if Pos('=', lines[i]) > 0 then
               begin
               entries := entries + Trim(lines[i]) + '|';
               end;
            end;
         end;
      (* Spelled exactly as the files on disk are named (Lint-DomFileCase). *)
      CheckEquals('newhampshire_cty.dom s50.dom p13.dom ', includes,
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
      LoadShippedDomFollowingIncludes(table, 'newhampshire.dom', True, 0);
      CheckEquals(73, mo.DomList.Count,
                  '10 counties, 50 states (DC counted as MD) and 13 provinces and territories');
      CheckEquals('HIL', MultiplierOf(table, 'HIL'),
                  'the counties are loaded first, so a county keeps its own code');
      CheckEquals('CAR', MultiplierOf(table, 'CAR'), 'CAR is Carroll, not California');
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

(* THE RULES GIVE NO EXAMPLE LINE and name no Cabrillo fields; the exchange
   is "NH: RS(T) + County / non-NH W/VE: RS(T) + (State/Province) / DX: RS(T)
   + "DX"" -- pinned on the standard QSO line (DXLog's CABRILLO_LINE is the
   same). A DX station's received column is "DX", what it sent, also when its
   entity was typed; a DX entrant sends "DX" in both columns and its
   STX_STRING, whether its MY STATE is empty or the dialog's DX. *)
procedure TContestNewHampshireQPTests.Test_NewHampshireCabrilloColumns;
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
                        2026, 9, 19, aHour, aMinute, aCall]);
   end;

begin
   BeginTest('Test_NewHampshireCabrilloColumns');
   CheckEquals('NH-QSO-PARTY', ContestIdentity(NewHampshireHandle).CabrilloContestName('', ''),
               'CONTEST: NH-QSO-PARTY');

   (* A HILLSBOROUGH COUNTY STATION WORKS NEW YORK. *)
   contestObject := MakeNewHampshire(StationAt(True));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'HIL';
      qso := NewHampshireQso(Band40, CW, eCW, 'NY');
      qso.DomesticQTH := 'NY';
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'NY';

      firstPart := FirstPartOf('7035', 16, 1, 'W1NH');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 HIL    ', sent, 'sent: RST and my county');
      CheckEquals('599 NY     ', received, 'received: RST and the state received');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'W2AAA', received, '']);
      CheckEquals(Words('QSO: 7035 CW 2026-09-19 1601 W1NH 599 HIL W2AAA 599 NY'), Words(line),
                  'freq, mode, date, time, my call, sent, call, received: ' + line);
      CheckEquals(CabrilloQSOLineFormatDefault, contestObject.CabrilloQSOLineFormat,
                  'the standard QSO line, no extra column');
      CheckEquals('599 HIL    ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my county');

      (* PHONE, with Ontario. *)
      ctx.RSTSent := '59';
      ctx.RSTReceived := '59';
      ctx.HisQTH := 'ON';
      qso := NewHampshireQso(Band20, Phone, eUSB, 'ON');
      qso.DomesticQTH := 'ON';
      CheckEquals('PH', contestObject.CabrilloModeString(Phone, eUSB), 'SSB is PH');
      CheckEquals('59  HIL    ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'sent on phone: RS and my county');
      CheckEquals('59  ON     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'received: RS and the province');

      (* A DX STATION: "DX", what it sent -- whatever was typed. *)
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'DX';
      qso := NewHampshireQso(Band20, CW, eCW, 'DX');
      CheckEquals('599 DX     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'a DX station''s column is DX');
      ctx.HisQTH := 'DL';
      qso := NewHampshireQso(Band20, CW, eCW, 'DL');
      CheckEquals('599 DX     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'also when its entity was typed');
   finally
      contestObject.Free;
   end;

   (* A NEW YORK ENTRANT WORKS HILLSBOROUGH COUNTY. *)
   contestObject := MakeNewHampshire(StationAt(False));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'NY';
      qso := NewHampshireQso(Band40, CW, eCW, 'HIL');
      qso.DomesticQTH := 'HIL';
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'HIL';
      firstPart := FirstPartOf('7035', 19, 30, 'W2AAA');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'W1NH', received, '']);
      CheckEquals(Words('QSO: 7035 CW 2026-09-19 1930 W2AAA 599 NY W1NH 599 HIL'), Words(line),
                  'the out-of-state line: ' + line);
      CheckEquals('599 NY     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my state');
   finally
      contestObject.Free;
   end;

   (* A DX ENTRANT: "DX: RS(T) + "DX"" -- MY STATE empty, then the New
      Contest dialog's DX. The same three columns either way. *)
   contestObject := MakeNewHampshire(DXStation('DL'));
   try
      my := Default(TMyStationExchange);
      my.MyState := '';
      qso := NewHampshireQso(Band20, CW, eCW, 'HIL');
      qso.DomesticQTH := 'HIL';
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'HIL';
      firstPart := FirstPartOf('14041', 20, 15, 'DL1AAA');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 DX     ', sent, 'MY STATE empty: Cabrillo sent is RST and DX');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'W1NH', received, '']);
      CheckEquals(Words('QSO: 14041 CW 2026-09-19 2015 DL1AAA 599 DX W1NH 599 HIL'), Words(line),
                  'the DX entrant''s line: ' + line);
      CheckEquals('599 DX     ', contestObject.FormatADIFSentExchange(my, qso),
                  'MY STATE empty: ADIF STX_STRING is RST and DX, what was transmitted');
   finally
      contestObject.Free;
   end;
   contestObject := MakeNewHampshire(DXStationStatingDX('DL'));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'DX';
      qso := NewHampshireQso(Band20, CW, eCW, 'HIL');
      qso.DomesticQTH := 'HIL';
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'HIL';
      CheckEquals('599 DX     ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'MY STATE DX: Cabrillo sent is RST and DX');
      CheckEquals('599 DX     ', contestObject.FormatADIFSentExchange(my, qso),
                  'MY STATE DX: ADIF STX_STRING is RST and DX');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet. First a New
   York entrant with the shipped newhampshire_cty.dom, then a Hillsborough
   County entrant with the shipped newhampshire.dom (its INCLUDEs followed by
   uTestShippedDom, since the test binary has no dom folder). Each half takes
   MultByBand from the class's DescribeSession for that entrant, as
   FoundContest does -- never from the identity alone.
   --------------------------------------------------------------------------- *)

procedure TContestNewHampshireQPTests.Test_NewHampshireRealEngine;
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
      dupe's zero points, the sheets. Returns whether it was a dupe. *)


   (* THE ENGINE'S FLAGS FOR THIS ENTRANT, as ApplyContestTraits and then
      ApplySessionDefaults write them: the identity's, then what the
      contest's DescribeSession states. *)
   procedure ApplyFlagsFor(aInState: boolean);
   var
      session: TSessionDefaults;
   begin
      Settings.Qso.ByBand := ContestIdentity(h).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(h).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      session := Describe(StationAt(aInState));
      try
         if session.IsStated(svMultByBand) then
            begin
            Settings.Mult.ByBand := session.MultByBand;
            end;
      finally
         session.Free;
      end;
   end;

begin
   BeginTest('Test_NewHampshireRealEngine');
   h := NewHampshireHandle;
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
      (* AS FoundContest SETS IT UP FOR A NEW YORK STATION: not in New
         Hampshire, so the county file with each county its own multiplier;
         K, VE, KH6 and KL are domestic countries; the class's flags and its
         out-of-state MultByBand. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := True;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'newhampshire_cty.dom'),
                'newhampshire_cty.dom loads');
      Contest := h;
      ReleaseActiveContest;
      StationInHostState := False;
      ApplyFlagsFor(False);
      CheckTrue(Settings.Mult.ByBand, 'outside NH the engine counts multipliers per band');
      CheckFalse(Settings.Mult.ByMode, 'and not per mode');
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* BELKNAP, 20 m CW. *)
      dupe := EnterPartyQSO('W1BEL', '599 BEL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 BEL is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('BEL', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the county');
      CheckTrue(rx.DomesticMult, 'Belknap is a new multiplier');
      CheckEquals(2, Integer(rx.QSOPoints), '"2 points per CW QSO"');

      (* "Each NH county once per band": Belknap again on 40 m IS new. *)
      dupe := EnterPartyQSO('W1BEL', '599 BEL', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckTrue(rx.DomesticMult, 'and Belknap IS a new multiplier on another band');

      (* "Once per band per mode" for the QSO; the multiplier is per band
         only, not per mode. *)
      dupe := EnterPartyQSO('W1BEL', '59 BEL', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '59 BEL on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), '"1 Point per phone QSO"');
      CheckFalse(rx.DomesticMult, 'but Belknap is NOT a new multiplier in another mode');

      dupe := EnterPartyQSO('W1BEL', '599 BEL', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'Belknap again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      (* "Maximum multiplier count: 50 (10 counties per band, 5 bands)": the
         sheet's all-band total is the SUM of the (county, band) pairs, which
         the score reads. *)
      CheckEquals(2, mo.MTotals[AllBands, Both, rmDomestic],
                  'Belknap on 20 and 40 m: two multipliers in the total');
      dupe := EnterPartyQSO('W1SUL', '599 SUL', Band15, CW, eCW, accepted, rx);
      CheckTrue(rx.DomesticMult, 'Sullivan on 15 m is new');
      CheckEquals(3, mo.MTotals[AllBands, Both, rmDomestic], 'three (county, band) pairs');

      (* FM is phone: on one band it is the same dupe mode as SSB. *)
      dupe := EnterPartyQSO('W1FM', '59 ROC', Band10, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '10 m SSB is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Rockingham on 10 m is new');
      dupe := EnterPartyQSO('W1FM', '59 ROC', Band10, FM, eFM, accepted, rx);
      CheckTrue(accepted, '10 m FM is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(dupe, 'the same station on 10 m FM after SSB IS a dupe: FM is phone');

      (* Off band and off mode: logged, automatic X-QSOs -- through scoring,
         the multiplier sheet, the totals and the Cabrillo export alike. *)
      ActiveContest(Contest);
      dupe := EnterPartyQSO('W1TOP', '599 STR', Band160, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a 160 m QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO ("80m through 10m")');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and Strafford is no multiplier from it');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'its Cabrillo line is an X-QSO: line');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx), 'and it counts toward no total');
      dupe := EnterPartyQSO('W1WRC', '599 STR', Band17, CW, eCW, accepted, rx);
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'a 17 m QSO is an X-QSO ("except WARC")');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'the 17 m QSO''s Cabrillo line is an X-QSO: line');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx), 'and it counts toward no total');
      dupe := EnterPartyQSO('W1DIG', '599 STR', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(accepted, 'an RTTY QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO ("CW/Phone")');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and Strafford is no multiplier from it');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'the RTTY QSO''s Cabrillo line is an X-QSO: line');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx), 'and it counts toward no total');
      dupe := EnterPartyQSO('W1BEL', '599 BEL', Band15, CW, eCW, accepted, rx);
      CheckFalse(QSOIsXQSO(ContestIdentity(h), rx), 'a 15 m CW QSO with Belknap is no X-QSO');
      CheckTrue(Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 4) = 'QSO:',
                'its Cabrillo line is an ordinary QSO: line');
      CheckTrue(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx), 'and it counts toward the totals');

      (* "Stations outside of NH contact as many NH stations as possible". *)
      DomesticQTHRefusalDomDir := ShippedDomDir;
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := 'newhampshire_cty.dom';

      accepted := True;
      EnterPartyQSO('W2NY', '599 NY', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a New York station is refused');
      CheckEquals('Improper domestic QTH!! (NY: work NH stations only)',
                  string(ExchangeErrorMessage),
                  'as an improper QTH, with the host-area reason');

      accepted := True;
      EnterPartyQSO('W1ABC', '599 HLL', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a misspelt county is refused');
      CheckEquals('Improper domestic QTH!! (HLL not in newhampshire_cty.dom)',
                  string(ExchangeErrorMessage),
                  'as not in the county file');

      accepted := True;
      EnterPartyQSO('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a DX station is refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['NH']), string(ExchangeErrorMessage),
                  'with the host-area reason');

      (* A county line of two (a QUESTION on #112). *)
      ClearPendingCounties;
      dupe := EnterPartyQSO('W1LINE', '599 GRA/COO', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a two-county line is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('GRA', UpperCase(string(rx.QTHString)), 'the first county is this QSO');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckEquals(1, PendingCountiesCount, 'the second county is queued');
      CheckEquals('COO', UpperCase(DequeuePendingCounty), 'Coos, as its own QSO');
      ClearPendingCounties;
      accepted := True;
      EnterPartyQSO('W1LINE', '599 GRA/COO/CAR', Band15, CW, eCW, accepted, rx);
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
      rx.tSysTime.qtYear := 26;
      rx.tSysTime.qtMonth := 9;
      rx.tSysTime.qtDay := 19;
      ActiveContest(Contest);
      CheckTrue(LoggedQSOIsXQSO(rx), 'out of state, a logged W2NY NY is an X-QSO');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'and its Cabrillo line says so');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx),
                 'and it counts toward no total');
      rx.QTHString := 'HIL';
      CheckFalse(LoggedQSOIsXQSO(rx), 'out of state, a logged Hillsborough QSO is not');

      (* NOW A HILLSBOROUGH COUNTY ENTRANT: in New Hampshire,
         newhampshire.dom (the counties, the states, the provinces), each
         county its own multiplier, everything ONCE; and DXCC countries. *)
      MultipliersIsCounties := False;
      LoadShippedDomFollowingIncludes(DomQTHTable, 'newhampshire.dom', True, 0);
      StationInHostState := True;
      Settings.Contest.DomesticFilename := 'newhampshire.dom';
      ApplyFlagsFor(True);
      CheckFalse(Settings.Mult.ByBand, 'in NH the engine counts every multiplier once');
      CheckFalse(Settings.Mult.ByMode, 'in either mode');
      ReleaseActiveContest;
      ActiveContest(Contest);
      mo.ClearAllMults;

      dupe := EnterPartyQSO('W2AAA', '599 NY', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in NH, 599 NY is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckTrue(rx.DomesticMult, 'New York is a new multiplier');
      dupe := EnterPartyQSO('W2BBB', '599 NY', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'New York on 40 m is no new multiplier: "once"');
      dupe := EnterPartyQSO('W2AAA', '59 NY', Band20, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'New York on 20 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), 'and scores 1');
      CheckFalse(rx.DomesticMult, 'and is no new multiplier in another mode: "once"');

      dupe := EnterPartyQSO('W1BBB', '599 BEL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a Belknap station is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('BEL', UpperCase(string(rx.DomMultQTH)), 'its multiplier is the county');
      CheckTrue(rx.DomesticMult, 'and Belknap is a new multiplier: "Each NH county"');
      dupe := EnterPartyQSO('W1CCC', '599 BEL', Band40, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'Belknap on 40 m is no new multiplier in NH: "once"');
      CheckEquals(2, mo.MTotals[AllBands, Both, rmDomestic], 'New York and Belknap: two multipliers');

      (* RULING: an NH station sends its county, never NH -- logged, scored,
         no multiplier. *)
      dupe := EnterPartyQSO('W1NHS', '599 NH', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NH is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'and keeps its points');
      CheckFalse(rx.DomesticMult, 'but NH is no multiplier for an NH entrant');

      (* QUESTION (#112): DC as Maryland. *)
      dupe := EnterPartyQSO('W3DC', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 DC is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), 'DC counts as Maryland');
      CheckTrue(rx.DomesticMult, 'a new multiplier, Maryland');
      dupe := EnterPartyQSO('W3MD', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckFalse(rx.DomesticMult, 'Maryland itself is then no new multiplier');

      dupe := EnterPartyQSO('VO1AAA', '599 NL', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NL is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NL', UpperCase(string(rx.DomMultQTH)), 'NL is Newfoundland and Labrador');
      CheckTrue(rx.DomesticMult, '"each Canadian province": a new multiplier');

      dupe := EnterPartyQSO('KH6AAA', '599 HI', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 HI is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'Hawaii is a state multiplier');
      CheckFalse(rx.DXMult, 'and not a DX one');

      (* "DX: RS(T) + "DX"" -- the DXCC country is the multiplier. *)
      dupe := EnterPartyQSO('DL1AAA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in NH, 599 DX from a German station is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'for 2 points');
      CheckFalse(rx.DomesticMult, 'no domestic multiplier');
      CheckTrue(rx.DXMult, 'and Germany is a new DX multiplier');
      CheckEquals('DL', string(rx.DXQTH), 'keyed by its DXCC country');
      CheckFalse(LoggedQSOIsXQSO(rx), 'and in state it is no X-QSO');
      dupe := EnterPartyQSO('DL2BBB', '59 DX', Band40, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, 'a German station on SSB: ' + string(ExchangeErrorMessage));
      CheckFalse(rx.DXMult, 'Germany is NOT new on phone: "once"');

      dupe := EnterPartyQSO('KP4AA', '599 DX', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a KP4 station is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DXMult, 'Puerto Rico is a DX multiplier');
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

procedure TContestNewHampshireQPTests.RunAllTests;
begin
   Test_NewHampshireIdentity;
   Test_NewHampshireMultipliersPerBandOnlyOutside;
   Test_NewHampshireBands;
   Test_NewHampshirePoints;
   Test_NewHampshireModesAreCWAndPhone;
   Test_NewHampshireInStateMultipliers;
   Test_NewHampshireInStateDXMultiplier;
   Test_NewHampshireOutOfStateWorksOnlyNewHampshire;
   Test_NewHampshireCountyLineIsTwoCounties;
   Test_NewHampshireDupes;
   Test_NewHampshireScoreCountsAtMostTenDXCC;
   Test_NewHampshireContestPeriodIsNotBuilt;
   Test_NewHampshireCountyFileIsTheRulesList;
   Test_NewHampshireInStateFileIsTheRulesMultipliers;
   Test_NewHampshireCabrilloColumns;
   Test_NewHampshireRealEngine;
end;

end.

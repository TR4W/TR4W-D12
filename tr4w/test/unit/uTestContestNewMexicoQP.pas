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

(* THE NEW MEXICO QSO PARTY -- added 2026-10-26 (#125), registered by its id
  (NM-QSO-PARTY). The rules are docs/ContestRules/QSOParties/NewMexico/
  NM-QSO-PARTY-Rules.txt ("2026 New Mexico QSO Party Form Packet", last
  modified 09 April 2026); NY4I's decisions are on #125. Each test below
  quotes the rule it holds. Written from ADDING_A_CONTEST.md Part A5, in
  uTestContestGeorgiaQP's shape; nothing is assumed from another party's
  rules.

  WHAT IS PINNED
    * its identity: the id, no legacy number, refused on multi-op, the
      names, the files, the flags, LOCATION: required, the party base and
      what it inherits;
    * its bands, and its points in every mode through ScoreQSO; EVERY
      digital submode is credited (FT8/FT4 included);
    * the in-state entrant's multipliers (the shipped newmexico.dom through
      the real loader): the 33 counties each its own, the 50 states with NM
      among them and DC counted as MD, the 13 provinces and territories;
    * the in-state DX multiplier (DXCC but K, VE, KH6 and KL; KP4 counts)
      and none outside New Mexico;
    * the out-of-state entrant's multipliers and the host-area rule, against
      the shipped newmexico_cty.dom;
    * a county line of two, the dupe rules and the mobile's new county;
    * the power multiplier (QRP x5, LOW x2, HIGH x1) and the W1AW/5 bonus
      (250, once, a valid contact, after multiplying, 2026 only, by the
      log's year; the yearly pin reads the clock on purpose);
    * a DX entrant sends its DXCC entity on the air (CQ exchange, ADIF
      STX_STRING) but writes "DX" in the Cabrillo; a DX station received is
      "DX" in the Cabrillo whatever it sent;
    * the two .dom files against the rules' own check sheet;
    * the Cabrillo lines against the rules' template and sample, RY for
      every digital mode, FM as PH;
    * THROUGH THE REAL ENGINE (ParametersOkay and the multiplier sheet): an
      out-of-state entrant, then an in-state one.

  NOT PINNED, ON PURPOSE: a county-suffixed W1AW/5/BER paying the bonus.
  The base pays a bonus station by an exact call comparison, so it does
  not today; the fix is the base's, owned by the South Carolina QSO Party
  (#111). A test for it belongs with that change, not here as a pinned
  defect. *)
unit uTestContestNewMexicoQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNewMexicoQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NewMexicoIdentity;
      procedure Test_NewMexicoBands;
      procedure Test_NewMexicoPoints;
      procedure Test_NewMexicoEveryDigitalModeCounts;
      procedure Test_NewMexicoInStateMultipliers;
      procedure Test_NewMexicoInStateDXMultiplier;
      procedure Test_NewMexicoOutOfStateWorksOnlyNewMexico;
      procedure Test_NewMexicoCountyLineIsTwoCounties;
      procedure Test_NewMexicoDupes;
      procedure Test_NewMexicoPowerMultiplier;
      procedure Test_NewMexicoW1AWBonus;
      procedure Test_NewMexicoW1AWBonusIsTiedToTheLogsYear;
      procedure Test_NewMexicoHasAW1AWBonusRulingForTheCurrentYear;
      procedure Test_NewMexicoCountyFileIsTheRulesCheckSheet;
      procedure Test_NewMexicoInStateFileIsTheRulesMultipliers;
      procedure Test_NewMexicoCabrilloLinesAreTheRulesExamples;
      procedure Test_NewMexicoADXEntrantSendsItsEntityButWritesDX;
      procedure Test_NewMexicoRealEngine;
   end;

implementation

uses
   (* cpHIGH. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   Log4D,
   VC,
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uContestStateQSOPartyBase,
   uContestNewMexicoQP,
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
   (* The once-per-year Error, captured. *)
   uTestLogCapture,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   (* CabrilloReceivedQTH -- the QTH the real Cabrillo writer selects. *)
   PostUnit,
   FCONTEST,
   (* BuildSingleQsoCabrilloLine -- the X-QSO: prefix, Q119. *)
   uCabrillo,
   MainUnit;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

const
   (* "List of Canadian Provinces and Territories: Alberta (AB), British
      Columbia (BC), Manitoba (MB), New Brunswick (NB), Newfoundland-Labrador
      (NL), Nova Scotia (NS), Ontario (ON), Prince-Edward Island (PE), Quebec
      (QC), Saskatchewan (SK), Northwest Territories (NT), Nunavut (NU),
      Yukon Territories (YT)" -- every one the rules list. *)
   RULES_CANADIAN: array[0..12] of string = (
      'AB', 'BC', 'MB', 'NB', 'NL', 'NS', 'ON', 'PE', 'QC', 'SK', 'NT', 'NU', 'YT');

function NewMexicoHandle: TContestHandle;
begin
   if not FindContestById(NM_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('NM-QSO-PARTY is not registered');
      end;
end;

function MakeNewMexico(const aStation: TStationContext): TContestBase;
begin
   Result := Make(NewMexicoHandle, aStation);
end;

(* A New Mexico station (Bernalillo County, the rules' sample N5ZGT) or an
   Arizona one. The table knows every QTH (uTestContestObjects.
   WithHostAreaTable): a test about POINTS states that every QSO it scores is
   with a host-area station. The host-area rule itself is
   Test_NewMexicoOutOfStateWorksOnlyNewMexico's, against the real county
   file. *)
function StationAt(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'BER';
      end
   else
      begin
      Result.MyState := 'AZ';
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

function NewMexicoQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType;
                      const aQTH: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'N5XYZ';
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
   contestObject := MakeNewMexico(aStation);
   try
      qso := NewMexicoQso(aBand, aMode, aExtMode, aQTH);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* THE RULES' COUNTY CHECK SHEET, read from the committed rules file itself
   so the test cannot agree with a copy of it: after the "Callsign County
   Abbreviation" heading, each "______________  Name  ABC" line, until the
   next "Check Sheet" heading. Filled as ABC=Name. *)
procedure ReadRulesCountyCheckSheet(aCounties: TStringList);
var
   lines: TStringList;
   path: string;
   line: string;
   i: integer;
   lastSpace: integer;
   inTable: boolean;
begin
   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
           '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
           'QSOParties' + PathDelim + 'NewMexico' + PathDelim + 'NM-QSO-PARTY-Rules.txt';
   lines := TStringList.Create;
   try
      lines.LoadFromFile(path);
      inTable := False;
      for i := 0 to lines.Count - 1 do
         begin
         line := Trim(lines[i]);
         if Pos('Callsign', line) = 1 then
            begin
            inTable := (Pos('County', line) > 0) and (Pos('Abbreviation', line) > 0);
            Continue;
            end;
         if (not inTable) or (Pos('______________', line) <> 1) then
            begin
            Continue;
            end;
         line := Trim(Copy(line, 15, MaxInt));
         lastSpace := LastDelimiter(' ', line);
         aCounties.Add(Copy(line, lastSpace + 1, MaxInt) + '=' + Trim(Copy(line, 1, lastSpace - 1)));
         end;
   finally
      lines.Free;
   end;
end;

(* SCORE TOTALS with aPoints QSO points and aMults domestic multipliers. *)
function Totals(aPoints: longint; aMults: longint): TScoreTotals;
begin
   Result := Default(TScoreTotals);
   Result.QSOPoints := aPoints;
   Result.ScoredBand := AllBands;
   Result.SessionCountsMultipliers := True;
   Result.Mults[AllBands, Both, rmDomestic] := aMults;
end;

(* A LOGGED QSO WITH aCall, dated aYear-04-11 1500Z, scored by the class as
   an in-state entrant would score it (so QSOPoints is the rule's). *)
function LoggedQSO(const aCall: string; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType; aDupe: boolean; aYear: integer): ContestExchange;
var
   contestObject: TContestBase;
begin
   Result := NewMexicoQso(aBand, aMode, aExtMode, 'SAN');
   Result.Callsign := CallString(aCall);
   Result.ceDupe := aDupe;
   if aYear > 0 then
      begin
      Result.tSysTime.qtYear := aYear - 2000;
      Result.tSysTime.qtMonth := 4;
      Result.tSysTime.qtDay := 11;
      Result.tSysTime.qtHour := 15;
      end;
   contestObject := MakeNewMexico(StationAt(True));
   try
      contestObject.ScoreQSO(Result);
   finally
      contestObject.Free;
   end;
   if aDupe then
      begin
      Result.QSOPoints := 0;
      end;
end;

(* The words of a Cabrillo line, blank-separated, so column widths do not
   matter -- the rules say "All QSO data should be space delimited". *)
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

(* ---------------------------------------------------------------------------
   IDENTITY
   --------------------------------------------------------------------------- *)

procedure TContestNewMexicoQPTests.Test_NewMexicoIdentity;
var
   h: TContestHandle;
   found: TContestHandle;
   identity: TContestBase;
   contestObject: TContestBase;
   member: ContestType;
   legacy: integer;
begin
   BeginTest('Test_NewMexicoIdentity');
   CheckEquals('NM-QSO-PARTY', NM_QSO_PARTY_CONTEST_ID, 'the id constant');
   CheckTrue(FindContestById('NM-QSO-PARTY', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestNewMexicoQP, 'to its class');
   CheckTrue(TContestNewMexicoQP.ClassParent = TContestStateQSOPartyBase,
             'on the state-party base, directly: one host state, its counties, '
             + '"Non-NM stations: Work NM stations for NM counties only"');
   CheckEquals('NM-QSO-PARTY', ContestId(h), 'the stored id');

   identity := ContestIdentity(h);
   CheckFalse(TryLegacyContestOf(identity, member), 'a new contest has no ContestType member');
   CheckTrue(member = DUMMYCONTEST, 'so the walk names none');
   CheckFalse(ContestLegacyNumber(h, legacy), 'and no legacy number');
   CheckFalse(ContestCanUseMultiOp(h), 'and is refused on the multi-op network');

   CheckEquals('New Mexico QSO Party', identity.DisplayName, 'display name');
   CheckEquals('New Mexico QSO Party', identity.FriendlyName, 'friendly name');
   (* The rules' sample header: "CONTEST: NM-QSO-PARTY". *)
   CheckEquals('NM-QSO-PARTY', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('NM-QSO-PARTY', identity.CabrilloContestName('2026 NMQP N5ZGT', 'X'),
               'the CONTEST: line, whatever the title');
   CheckEquals('NM-QSO-PARTY', identity.ADIFContestId, 'ADIF CONTEST_ID');
   CheckTrue(identity.WritesADIFContestId, 'export writes it');
   CheckTrue(FindContestByADIFContestId('NM-QSO-PARTY', found), 'import resolves it');
   CheckTrue(found = h, 'to the New Mexico QSO Party');
   CheckEquals(286, identity.WA7BNMId, 'WA7BNM ref 286');
   CheckEquals(0, identity.QRZRUId, 'no QRZ.RU id');
   CheckEquals('logs@newmexicoqsoparty.org', identity.SubmissionEmail,
               '"Electronic logs should be emailed to logs@newmexicoqsoparty.org"');
   CheckEquals('NM', identity.HostState, 'host state');
   CheckEquals('NM', identity.QSOPartyArea, 'the New Contest prompt names New Mexico');
   CheckEquals('newmexico_cty', identity.DomesticFileName, 'the county file');
   CheckEquals('newmexico', identity.InStateDomesticFileName, 'the in-state file');
   CheckTrue(identity.IsUSQSOParty, 'a US QSO party');
   CheckTrue(identity.IsActive, 'active');
   CheckTrue(identity.MarksDupes, 'marks dupes');
   (* "The ARRL-SECTION: tag (Cabrillo v2.0) and LOCATION: tag (Cabrillo
      v3.0) is used to identify New Mexico stations" -- NY4I: required. *)
   CheckTrue(identity.RequiresCabrilloLocation, 'LOCATION: is required');

   (* "Stations may be worked only once per mode, per band"; "Each
      multiplier may be counted ONLY ONCE, regardless of mode or band";
      "plus 6 and 2 meters". *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled],
             'dupes per band and mode, multipliers once overall, 6 m and 2 m on');
   CheckTrue(identity.QSOByBand, 'a station may be worked again on another band');
   CheckTrue(identity.QSOByMode, 'and again in another mode');
   CheckFalse(identity.MultByBand, 'a multiplier is NOT counted again per band');
   CheckFalse(identity.MultByMode, 'nor again per mode');
   CheckTrue(identity.VHFBandsEnabled, '6 m and 2 m');

   (* "New Mexico stations: RS(T) + New Mexico county / Non-New Mexico
      stations: RS(T) + State/Province/DXCC entity". *)
   CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(identity.ExchangeKind),
               'RST and a county, state, province or DXCC entity');
   CheckEquals(Ord(NoInitialExchange), Ord(identity.InitialExchangeKind), 'no initial exchange');
   CheckTrue(identity.ExchangeCarriesDomesticQTH, 'the exchange carries a domestic QTH');
   CheckTrue(ContestUsesDomesticFile(identity), 'looked up in the domestic file');
   CheckTrue(ContestHasDomesticMultiplier(identity), 'the domestic QTH is the multiplier');

   (* WHAT THE PARTY BASE GIVES IT, pinned here so a base change is seen. *)
   CheckTrue(identity.StripsRoverCountyFromCall, 'a mobile''s /county is stripped live');
   CheckTrue(identity.SplitsRoverCallOnExport, 'and split on ADIF export');
   CheckTrue(identity.DupeKeyIncludesReceivedQTH,
             '"A New Mexico mobile station that travels into a new county is considered to be a new station"');
   CheckTrue(identity.WritesADIFCounty, 'CNTY is written');
   CheckEquals(2, (identity as TContestStateQSOPartyBase).CountyLineCountiesMax,
               '"only two counties at a time may be counted for the same contact"');

   (* "Location Multipliers for New Mexico participants ... and DX entities
      worked"; "for Non-New Mexico Participants ... each different NM county
      worked (up to 33)". *)
   contestObject := MakeNewMexico(StationAt(True));
   try
      CheckTrue(contestObject.HasDXMultiplier, 'in NM: DX entities are multipliers');
      CheckTrue(ContestCountryMode(contestObject) = ARRLCountryMode,
                'on the ARRL DXCC list ("See http://www.arrl.org/country-lists-prefixes")');
      CheckFalse(contestObject.HasZoneMultiplier, 'in NM: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'in NM: no prefix multiplier');
      CheckEquals(' 5NN BER', contestObject.CQExchangeDefault(StationAt(True)),
                  'in NM, the CQ exchange sends the county ("RS(T) + New Mexico county")');
   finally
      contestObject.Free;
   end;
   contestObject := MakeNewMexico(StationAt(False));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'outside NM: no DX multiplier');
      CheckTrue(ContestCountryMode(contestObject) = CQCountryMode, 'and the CQ list');
      CheckFalse(contestObject.HasZoneMultiplier, 'outside NM: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'outside NM: no prefix multiplier');
      CheckEquals(' 5NN AZ', contestObject.CQExchangeDefault(StationAt(False)),
                  'outside NM, the state ("RS(T) + State/Province/DXCC entity")');
   finally
      contestObject.Free;
   end;
end;

(* "Contest bands: 160-10 meters, plus 6 and 2 meters / Not permitted: WARC
   bands, 60 meters, and bands above 2 meters" -- 160, 80, 40, 20, 15, 10, 6
   and 2 m, nothing else. An off-band QSO is an automatic X-QSO: logged, 0
   points, no multiplier. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoBands;
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_NewMexicoBands');
   identity := ContestIdentity(NewMexicoHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when on the rules'' list');
      CheckTrue(ContestCreditsBand(identity, b) = expected,
                'band ' + IntToStr(Ord(b)) + ' through the one seam');
      end;
   CheckEquals(2, PointsFor(StationAt(False), Band160, CW, eCW, 'BER'), '160 m CW scores');
   CheckEquals(2, PointsFor(StationAt(False), Band10, CW, eCW, 'BER'), '10 m CW scores');
   CheckEquals(1, PointsFor(StationAt(False), Band6, Phone, eUSB, 'BER'), '6 m scores');
   CheckEquals(1, PointsFor(StationAt(False), Band2, FM, eFM, 'BER'), '2 m scores ("146.52 MHz FM")');
   CheckEquals(0, PointsFor(StationAt(False), Band30, CW, eCW, 'BER'), '30 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band17, Phone, eUSB, 'BER'), '17 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band12, CW, eCW, 'BER'), '12 m (WARC) scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band222, FM, eFM, 'BER'), '222 MHz ("above 2 meters") scores nothing');
   CheckEquals(0, PointsFor(StationAt(False), Band432, FM, eFM, 'BER'), '70 cm scores nothing');
end;

(* "Each Phone contact = 1 point / Each CW contact = 2 points / Each Digital
   contact = 2 points", for every entrant. FM is phone. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoPoints;
begin
   BeginTest('Test_NewMexicoPoints');
   CheckEquals(2, PointsFor(StationAt(False), Band20, CW, eCW, 'BER'), 'outside NM, CW 2');
   CheckEquals(1, PointsFor(StationAt(False), Band20, Phone, eUSB, 'BER'), 'outside NM, SSB 1');
   CheckEquals(1, PointsFor(StationAt(False), Band40, Phone, eLSB, 'BER'), 'outside NM, LSB 1');
   CheckEquals(1, PointsFor(StationAt(False), Band2, FM, eFM, 'SAN'), 'outside NM, FM is phone: 1');
   CheckEquals(2, PointsFor(StationAt(False), Band20, Digital, eRTTY, 'BER'), 'outside NM, RTTY 2');
   CheckEquals(2, PointsFor(StationAt(False), Band20, Digital, eFT8, 'BER'), 'outside NM, FT8 2');
   CheckEquals(2, PointsFor(StationAt(True), Band40, CW, eCW, 'TX'), 'in NM, CW with Texas');
   CheckEquals(1, PointsFor(StationAt(True), Band40, Phone, eLSB, 'BC'), 'in NM, SSB with British Columbia');
   CheckEquals(2, PointsFor(StationAt(True), Band20, Digital, ePSK31, 'SAN'), 'in NM, PSK with Sandoval');
   CheckEquals(2, PointsFor(StationAt(True), Band15, CW, eCW, 'LY'),
               'in NM, a DX station scores ("Work anyone")');
   CheckEquals(1, PointsFor(StationAt(True), Band15, Phone, eUSB, 'LY'), 'and 1 on phone');
   CheckEquals(0, PointsFor(StationAt(True), Band20, Both, eNoMode, 'TX'), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(StationAt(True), Band20, NoMode, eNoMode, 'TX'), 'nor this one');
end;

(* "Phone, CW, digital (any computer-to-computer mode is considered
   digital)"; "For an FT8/FT4 QSO to be valid, it must include the required
   QSO exchange" -- NY4I: every digital mode counts, FT8/FT4 included. EVERY
   ExtendedModeType of Digital is walked, so a submode added to VC is judged
   here; none is an X-QSO. Asked of the station-less identity, as every
   X-QSO reader asks it. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoEveryDigitalModeCounts;
var
   identity: TContestBase;
   qso: ContestExchange;
   ext: ExtendedModeType;
begin
   BeginTest('Test_NewMexicoEveryDigitalModeCounts');
   identity := ContestIdentity(NewMexicoHandle);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckTrue(ContestCreditsMode(identity, Digital, ext),
                'digital submode ' + IntToStr(Ord(ext)) + ' is credited');
      qso := NewMexicoQso(Band20, Digital, ext, 'BER');
      CheckFalse(QSOIsXQSO(identity, qso),
                 'digital submode ' + IntToStr(Ord(ext)) + ' is no X-QSO');
      end;
   CheckTrue(ContestCreditsMode(identity, Digital, eFT8), 'FT8 is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eFT4), 'FT4 is credited');
   CheckTrue(ContestCreditsMode(identity, CW, eCW), 'CW is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eUSB), 'USB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eNoMode), 'phone with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM is credited');
   CheckTrue(ContestCreditsModeKey(identity, Digital), 'the Digital key is credited');
   CheckTrue(ContestCreditsModeKey(identity, CW), 'the CW key is');
   CheckTrue(ContestCreditsModeKey(identity, Phone), 'the Phone key is');
   CheckEquals(2, PointsFor(StationAt(False), Band20, Digital, eFT4, 'BER'), 'FT4 scores 2');
   CheckEquals(2, PointsFor(StationAt(True), Band40, Digital, eJS8, 'TX'), 'JS8 scores 2');
   CheckEquals(2, PointsFor(StationAt(True), Band40, Digital, eMFSK, 'TX'), 'MFSK scores 2');
end;

(* ---------------------------------------------------------------------------
   MULTIPLIERS
   --------------------------------------------------------------------------- *)

(* "Multiply QSO points by total of each different NM county worked (up to
   33), states worked (up to 50), Canadian provinces/territories worked (up
   to 13 ...)"; "District of Columbia (DC) counts as Maryland". The shipped
   newmexico.dom through the real loader (InStateMultiplierOf follows its
   INCLUDEs), and the class's own CountsAsMultiplier (CountsForEntrant).

   "states worked (up to 50)" and the state check sheet lists New Mexico:
   NM is a state multiplier for an NM entrant too. Whether an NM-to-NM QSO
   earns it AS WELL AS the county is NY4I's open question on #125; built as
   county-only, so NM is earned only when "NM" is what was received. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoInStateMultipliers;
var
   h: TContestHandle;
   i: integer;
begin
   BeginTest('Test_NewMexicoInStateMultipliers');
   h := NewMexicoHandle;

   CheckEquals('BER', InStateMultiplierOf(h, 'BER'), 'Bernalillo County is its own multiplier');
   CheckEquals('VAL', InStateMultiplierOf(h, 'VAL'), 'and Valencia, the last on the sheet');
   CheckEquals('SAN', InStateMultiplierOf(h, 'SAN'), 'Sandoval is a county');
   CheckEquals('SJU', InStateMultiplierOf(h, 'SJU'), 'San Juan is SJU');
   CheckEquals('LOS', InStateMultiplierOf(h, 'LOS'), 'Los Alamos is LOS');
   CheckEquals('NM', InStateMultiplierOf(h, 'NM'), '"states worked (up to 50)" -- New Mexico among them');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'NM'), rmDomestic),
             'and an NM entrant counts it (no host-state exclusion)');
   CheckEquals('AZ', InStateMultiplierOf(h, 'AZ'), 'Arizona is a state');
   CheckEquals('AK', InStateMultiplierOf(h, 'AK'), '"Alaska and Hawaii count as state multipliers"');
   CheckEquals('HI', InStateMultiplierOf(h, 'HI'), 'Hawaii is');

   (* "District of Columbia (DC) counts as Maryland". *)
   CheckEquals('MD', InStateMultiplierOf(h, 'DC'), 'DC is Maryland''s multiplier');
   CheckEquals('MD', InStateMultiplierOf(h, 'MD'), 'as Maryland is');

   for i := Low(RULES_CANADIAN) to High(RULES_CANADIAN) do
      begin
      CheckEquals(RULES_CANADIAN[i], InStateMultiplierOf(h, RULES_CANADIAN[i]),
                  'the rules'' Canadian abbreviation ' + RULES_CANADIAN[i] + ' is its own multiplier');
      end;
   CheckEquals('NL', InStateMultiplierOf(h, 'NF'), 'NF is Newfoundland-Labrador');
   CheckEquals('NL', InStateMultiplierOf(h, 'LB'), 'and so is LB');
   (* P13.DOM also spells Newfoundland LA. S50.DOM is included first and the
      first alias added wins, so LA stays Louisiana. *)
   CheckEquals('LA', InStateMultiplierOf(h, 'LA'), 'LA is Louisiana, not Labrador');

   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'TX'), rmDomestic), 'Texas counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'BER'), rmDomestic), 'a county counts');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'DC'), rmDomestic), 'DC counts (as MD)');
   CheckTrue(CountsForEntrant(h, True, InStateMultiplierOf(h, 'YT'), rmDomestic), 'Yukon counts');
   CheckTrue(CountsForEntrant(h, False, InStateMultiplierOf(h, 'BER'), rmDomestic),
             'outside NM a county counts (the host-area rule is a separate question)');

   (* DX entities are the DX multiplier (Test_NewMexicoInStateDXMultiplier),
      not entries in the in-state file. *)
   CheckEquals('', InStateMultiplierOf(h, 'DX'), 'DX is no domestic multiplier');
   CheckEquals('', InStateMultiplierOf(h, 'LY'), 'nor a DX entity');
end;

(* "and DX entities worked" for "New Mexico participants"; "Alaska and
   Hawaii count as state multipliers only"; "United States and Canada do not
   count as DX entity multipliers". The key is the worked station's DXCC
   entity, refused for K, VE, KH6 and KL; NY4I: US possessions such as KP4
   count as DX. None for an out-of-state or DX entrant ("each different NM
   county worked" only). Asked through the nil-safe seams LOGEDIT asks. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoInStateDXMultiplier;
var
   contestObject: TContestBase;

   function KeyFor(const aCountryID: string; out aKey: string): boolean;
   var
      qso: ContestExchange;
      key: DXMultiplierString;
   begin
      qso := NewMexicoQso(Band20, CW, eCW, aCountryID);
      qso.QTH.CountryID := ShortString(aCountryID);
      Result := ContestDXMultiplierKey(contestObject, qso, key);
      aKey := string(key);
   end;

var
   key: string;
begin
   BeginTest('Test_NewMexicoInStateDXMultiplier');
   contestObject := MakeNewMexico(StationAt(True));
   try
      CheckTrue(ContestHasDXMultiplier(contestObject), 'in NM there is a DX multiplier');
      CheckTrue(KeyFor('LY', key), 'Lithuania (the rules'' LY2ZZ) is a DX multiplier');
      CheckEquals('LY', key, 'keyed by its DXCC entity');
      CheckTrue(KeyFor('ZL', key), 'New Zealand (the check sheet''s example) is');
      CheckEquals('ZL', key, 'keyed ZL');
      CheckTrue(KeyFor('KP4', key), 'Puerto Rico, a US possession, is (NY4I)');
      CheckEquals('KP4', key, 'keyed KP4');
      CheckTrue(KeyFor('KH2', key), 'and Guam');
      CheckTrue(KeyFor('XE', key), 'and Mexico');
      CheckFalse(KeyFor('K', key), '"United States ... do not count": no key for the USA');
      CheckEquals('', key, 'and none written');
      CheckFalse(KeyFor('VE', key), '"Canada": none');
      CheckFalse(KeyFor('KH6', key), '"Hawaii count as state multipliers only": none');
      CheckFalse(KeyFor('KL', key), '"Alaska": none');
   finally
      contestObject.Free;
   end;

   contestObject := MakeNewMexico(StationAt(False));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'outside NM there is no DX multiplier');
      CheckFalse(KeyFor('LY', key), 'so no key for Lithuania');
      CheckFalse(KeyFor('KP4', key), 'nor Puerto Rico');
   finally
      contestObject.Free;
   end;

   contestObject := MakeNewMexico(DXStation('LY'));
   try
      CheckFalse(ContestHasDXMultiplier(contestObject), 'a DX entrant has none either');
      CheckFalse(KeyFor('JA', key), 'so no key for Japan');
   finally
      contestObject.Free;
   end;
end;

(* "Non-NM stations: Work NM stations for NM counties only" -- "Location
   Multipliers for Non-New Mexico Participants: ... each different NM county
   worked (up to 33)". Q107: an out-of-state entrant's QSO with a station the
   session's table (the shipped newmexico_cty.dom, through the real loader)
   does not know is refused when typed, and is an automatic X-QSO -- 0
   points, no multiplier -- when logged any other way. *)
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
   Result.MyState := 'AZ';
   Result.MyCountry := 'K';
end;

function ParseOutOfState(const aQTH: string; out aMessage: string): boolean;
var
   contestObject: TContestBase;
   exch: ContestExchange;
begin
   GShapeSetsQTH := aQTH;
   contestObject := MakeNewMexico(OutOfStateStation);
   try
      exch := Default(ContestExchange);
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, ParseSession, exch, aMessage);
   finally
      contestObject.Free;
   end;
end;

procedure TContestNewMexicoQPTests.Test_NewMexicoOutOfStateWorksOnlyNewMexico;
var
   msg: string;
   contestObject: TContestBase;
   qso: ContestExchange;
   counties: TStringList;
   i: integer;
   code: string;
begin
   BeginTest('Test_NewMexicoOutOfStateWorksOnlyNewMexico');
   counties := TStringList.Create;
   LoadCountyTable('newmexico_cty.dom', True);
   try
      (* EVERY ONE OF THE RULES' 33 COUNTIES is its own multiplier and a
         station this entrant may work. *)
      ReadRulesCountyCheckSheet(counties);
      CheckEquals(33, counties.Count, 'the rules'' check sheet lists 33 counties ("up to 33")');
      CheckEquals(33, mo.DomList.Count, 'the county file is 33 multipliers');
      for i := 0 to counties.Count - 1 do
         begin
         code := counties.Names[i];
         CheckEquals(code, MultiplierOf(CountyTable, code), code + ' is its own multiplier');
         CheckTrue(CountyFileKnowsQTH(code), code + ' is a New Mexico station');
         end;

      (* TYPED: a county is taken; anything else is refused with the
         party's reason. *)
      CheckTrue(ParseOutOfState('BER', msg), 'outside NM, a Bernalillo County station');
      CheckEquals('', msg, 'nothing to say');
      CheckTrue(ParseOutOfState('sfe', msg), 'Santa Fe, typed in lower case');
      CheckFalse(ParseOutOfState('AZ', msg), 'outside NM, an Arizona station: refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['NM']), msg, 'with the reason');
      CheckFalse(ParseOutOfState('BC', msg), 'a British Columbia station: refused');
      CheckFalse(ParseOutOfState('NM', msg),
                 'NM alone is no county: "New Mexico stations: RS(T) + New Mexico county"');
      CheckFalse(ParseOutOfState('LY', msg), 'a DX station: refused');

      (* LOGGED: the same rule scores 0 and earns no multiplier. *)
      CheckEquals(2, PointsFor(OutOfStateStation, Band20, CW, eCW, 'SAN'), 'logged: a county scores');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'AZ'), 'logged: Arizona scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, 'LY'), 'logged: DX scores 0');
      CheckEquals(0, PointsFor(OutOfStateStation, Band20, CW, eCW, ''), 'logged: no QTH scores 0');

      contestObject := MakeNewMexico(OutOfStateStation);
      try
         qso := NewMexicoQso(Band20, CW, eCW, 'AZ');
         CheckFalse(ContestCreditsWorkedStation(contestObject, qso),
                    'and earns no multiplier (the predicate SetMultFlags asks)');
         CheckTrue(QSOIsXQSO(contestObject, qso),
                   'an automatic X-QSO, judged with the entrant (Q119)');
         qso := NewMexicoQso(Band20, CW, eCW, 'BER');
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

(* "a stationary mobile may operate on a County Line and contacts with the
   mobile can be used as credit for both counties ... only one County Line
   at a time ... only two counties at a time may be counted for the same
   contact" (an Expedition likewise). One and two pass; three are refused.
   The engine half (one QSO per county from one entry) is the real-engine
   test's. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoCountyLineIsTwoCounties;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_NewMexicoCountyLineIsTwoCounties');
   contestObject := MakeNewMexico(NoStation);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(2, party.CountyLineCountiesMax, 'two counties on a line');
      CheckTrue(party.CountyLineAllowed, 'a county line is allowed');
      CheckTrue(party.ValidateQTHCount(1, msg), 'one county');
      CheckTrue(party.ValidateQTHCount(2, msg), 'a line of two');
      CheckEquals('', msg, 'nothing to say about two');
      CheckFalse(party.ValidateQTHCount(3, msg), 'three are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), msg, 'with the county-count message');
   finally
      contestObject.Free;
   end;
end;

(* "Stations may be worked only once per mode, per band." "A New Mexico
   mobile station that travels into a new county is considered to be a new
   station"; W1AW/5 "may be worked multiple times on the same band and mode
   when operating from different New Mexico counties". Through the dupe path
   LogContact takes (uTestQSOPartyRules.RoverDupeAnswers). CW, Phone and
   Digital are three dupe modes; FM shares Phone's. The band and mode halves
   are the real engine's, below. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoDupes;
var
   newCountyIsDupe: boolean;
   sameCountyIsDupe: boolean;
begin
   BeginTest('Test_NewMexicoDupes');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(NewMexicoHandle)),
             'the received county is part of the dupe key');
   CheckTrue(ContestDupeModeOf(ContestIdentity(NewMexicoHandle), Digital) = Digital,
             'Digital is its own dupe mode');
   CheckTrue(ContestDupeModeOf(ContestIdentity(NewMexicoHandle), CW) = CW, 'CW its own');
   CheckTrue(ContestDupeModeOf(ContestIdentity(NewMexicoHandle), Phone) = Phone, 'and Phone its own');
   RoverDupeAnswers(NewMexicoHandle, 'W1AW/5', 'BER', 'SAN', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'W1AW/5 from Sandoval after Bernalillo, 20 m CW: a new station');
   CheckTrue(sameCountyIsDupe, 'W1AW/5 from Bernalillo again, 20 m CW: a dupe');
   RoverDupeAnswers(NewMexicoHandle, 'KB5SXB/M', 'BER', 'VAL', newCountyIsDupe, sameCountyIsDupe);
   CheckFalse(newCountyIsDupe, 'a /M mobile from Valencia after Bernalillo: a new station');
   CheckTrue(sameCountyIsDupe, 'and from Bernalillo again: a dupe');
end;

(* ---------------------------------------------------------------------------
   THE FINAL SCORE
   --------------------------------------------------------------------------- *)

(* "Power multiplier based on maximum power used: QRP (5 watts or less): x5
   / Low Power (> 5 - 150 watts): x2 / High Power: (> 150 watts): x1";
   "Total = (Sum of QSO points from all bands x power multiplier x location
   multiplier) + W1AW/5 contact bonus". The mapping itself, then the
   product for each CATEGORY-POWER, in state (counties + states + provinces
   + DX) and out of state (counties). *)
procedure TContestNewMexicoQPTests.Test_NewMexicoPowerMultiplier;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_NewMexicoPowerMultiplier');
   CheckEquals(5, NewMexicoPowerMultiplier(cpQRP), 'QRP x5');
   CheckEquals(2, NewMexicoPowerMultiplier(cpLOW), 'LOW x2 (up to 150 W)');
   CheckEquals(1, NewMexicoPowerMultiplier(cpHIGH), 'HIGH x1');

   t := Totals(192, 12);
   t.Mults[AllBands, Both, rmDX] := 3;
   view := TLoggedQSOList.Create;
   station := StationAt(True);
   station.MyPower := cpQRP;
   contestObject := MakeNewMexico(station);
   try
      CheckEquals(192 * 15 * 5, contestObject.FinalScore(t, view),
                  'QRP: points x (domestic + DX multipliers) x 5');
      station.MyPower := cpLOW;
      contestObject.SetStation(station);
      CheckEquals(192 * 15 * 2, contestObject.FinalScore(t, view), 'LOW: x 2');
      station.MyPower := cpHIGH;
      contestObject.SetStation(station);
      CheckEquals(192 * 15, contestObject.FinalScore(t, view), 'HIGH: x 1');
      CheckEquals(0, contestObject.BonusPoints(t, view), 'no bonus without W1AW/5');

      (* Outside New Mexico: "each different NM county worked (up to 33)". *)
      station := StationAt(False);
      station.MyPower := cpQRP;
      contestObject.SetStation(station);
      t := Totals(40, 9);
      CheckEquals(40 * 9 * 5, contestObject.FinalScore(t, view), 'outside NM, QRP: points x counties x 5');

      t.Mults[AllBands, Both, rmDomestic] := 0;
      CheckEquals(0, contestObject.FinalScore(t, view), 'no multiplier, no score');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* "W1AW/5 Bonus (new, for 2026 only): Add an additional 250 points to your
   final score for a valid contact with W1AW/5. Bonus points are valid for
   one (1) W1AW/5 QSO only, regardless of band, mode, or W1AW/5's county."
   Added AFTER the power and location multipliers. ONCE, however many
   W1AW/5 QSOs (each county is a new station for points, "however, the
   W1AW/5 bonus may be claimed only once"); any band, any mode, digital
   included; a dupe or an X-QSO is not "a valid contact". Every QSO is
   dated 2026. For any entrant -- "for any participant who works W1AW/5". *)
procedure TContestNewMexicoQPTests.Test_NewMexicoW1AWBonus;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_NewMexicoW1AWBonus');
   CheckEquals('W1AW/5', NM_W1AW_BONUS_CALL, 'the bonus station, as the rules spell it');
   view := TLoggedQSOList.Create;
   station := StationAt(True);
   station.MyPower := cpQRP;
   contestObject := MakeNewMexico(station);
   try
      view.Add(LoggedQSO('N5ZZZ', Band20, CW, eCW, False, 2026));
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), 'no W1AW/5: no bonus');

      view.Add(LoggedQSO('W1AW/5', Band20, CW, eCW, False, 2026));
      CheckEquals(250, contestObject.BonusPoints(Totals(0, 0), view), 'W1AW/5 worked: 250');
      t := Totals(100, 10);
      CheckEquals(100 * 10 * 5 + 250, contestObject.FinalScore(t, view),
                  'added AFTER multiplying: (points x mults x QRP 5) + 250, not x 5');

      view.Add(LoggedQSO('W1AW/5', Band40, Phone, eLSB, False, 2026));
      view.Add(LoggedQSO('W1AW/5', Band20, CW, eCW, False, 2026));
      CheckEquals(250, contestObject.BonusPoints(Totals(0, 0), view),
                  '"valid for one (1) W1AW/5 QSO only": three QSOs pay 250 once');

      (* NOT A VALID CONTACT: a dupe, an off-band QSO (an X-QSO). *)
      view.Clear;
      view.Add(LoggedQSO('W1AW/5', Band20, CW, eCW, True, 2026));
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), 'a dupe W1AW/5 is no valid contact');
      view.Clear;
      view.Add(LoggedQSO('W1AW/5', Band30, CW, eCW, False, 2026));
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view),
                  'nor a 30 m one: WARC is "Not permitted" (an automatic X-QSO)');

      (* "regardless of band, mode": digital, FT8 included; 2 m FM. *)
      view.Clear;
      view.Add(LoggedQSO('W1AW/5', Band20, Digital, eFT8, False, 2026));
      CheckEquals(250, contestObject.BonusPoints(Totals(0, 0), view), 'an FT8 W1AW/5 QSO pays');
      view.Clear;
      view.Add(LoggedQSO('W1AW/5', Band2, FM, eFM, False, 2026));
      CheckEquals(250, contestObject.BonusPoints(Totals(0, 0), view), 'a 2 m FM one pays');

      (* A DIFFERENT CALL is not W1AW/5: W1AW, the rules' sample CT station. *)
      view.Clear;
      view.Add(LoggedQSO('W1AW', Band20, CW, eCW, False, 2026));
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), 'W1AW in CT is not W1AW/5');

      (* AN OUT-OF-STATE ENTRANT earns it too, from an NM county. *)
      view.Clear;
      view.Add(LoggedQSO('W1AW/5', Band20, CW, eCW, False, 2026));
      contestObject.SetStation(StationAt(False));
      CheckEquals(250, contestObject.BonusPoints(Totals(0, 0), view), 'outside NM, 250 too');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* "W1AW/5 Bonus (new, for 2026 only)" -- NY4I: tied to the year, as the
   Idaho QSO Party's dormant-county table is (Q35): the LOG'S contest year,
   uContestBase.LogContestYear (the contest row's start time, else the
   earliest dated QSO), never the clock. 2026 pays 250; a year before the
   bonus was "new" pays nothing and says nothing; a later year has no ruling
   until the sponsor publishes one -- it pays nothing and logs ONE Error per
   year (the party base's ReportNoTableForYear); a log with no year is
   reported as such. A log that never worked W1AW/5 asks no year. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoW1AWBonusIsTiedToTheLogsYear;
var
   capture: TCaptureAppender;
   keep: ILogAppender;
   lg: TLogLogger;
   savedLevel: TLogLevel;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   points: longint;
   t: TScoreTotals;
begin
   BeginTest('Test_NewMexicoW1AWBonusIsTiedToTheLogsYear');
   CheckTrue(NewMexicoW1AWBonusPoints(2026, points), '2026 has a ruling');
   CheckEquals(250, points, '"Add an additional 250 points" (reduced from 500 on 09 April)');
   CheckTrue(NewMexicoW1AWBonusPoints(2025, points), '2025 has a ruling');
   CheckEquals(0, points, 'no bonus: it was "new" in 2026');
   CheckFalse(NewMexicoW1AWBonusPoints(2027, points), '2027 has no ruling yet');
   CheckEquals(0, points, 'and pays nothing');
   CheckFalse(NewMexicoW1AWBonusPoints(0, points), 'an unknown year has none');
   CheckTrue(TContestNewMexicoQP.HasW1AWBonusRuling(2026), 'the class answers the same');
   CheckFalse(TContestNewMexicoQP.HasW1AWBonusRuling(2031), 'for 2031 too');

   capture := TCaptureAppender.Create('capture');
   keep := capture;
   lg := TLogLogger.GetLogger('uContestNewMexicoQP');
   savedLevel := lg.Level;
   lg.Level := Log4D.Error;
   lg.AddAppender(keep);
   view := TLoggedQSOList.Create;
   contestObject := MakeNewMexico(StationAt(True));
   try
      (* NO W1AW/5 in 2031: no year asked, nothing reported. *)
      view.Add(LoggedQSO('N5ZZZ', Band20, CW, eCW, False, 2031));
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), 'no W1AW/5 in 2031');
      CheckEquals(0, capture.Lines.Count, 'asks no year, reports nothing');

      view.Clear;
      view.Add(LoggedQSO('W1AW/5', Band20, CW, eCW, False, 2025));
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), 'a 2025 log pays nothing');
      CheckEquals(0, capture.Lines.Count, 'and that is a ruling, not reported');

      view.Clear;
      view.Add(LoggedQSO('W1AW/5', Band20, CW, eCW, False, 2031));
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), '2031 has no ruling: no bonus');
      CheckEquals(1, capture.Lines.Count, 'and it is REPORTED');
      CheckTrue(Pos('2031', capture.Lines.Text) > 0, 'naming the year: ' + capture.Lines.Text);
      CheckTrue(Pos('W1AW/5', capture.Lines.Text) > 0, 'and the bonus: ' + capture.Lines.Text);
      CheckTrue(Pos('NOT in the score', capture.Lines.Text) > 0,
                'and saying the score leaves it out: ' + capture.Lines.Text);
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), 'asked again');
      CheckEquals(1, capture.Lines.Count, 'reported once per year, not once per score');

      (* THE LOG'S START TIME OUTRANKS ITS QSOs' DATES. *)
      t := Totals(0, 0);
      t.LogStartTime := EncodeDate(2026, 4, 11) + EncodeTime(14, 0, 0, 0);
      CheckEquals(250, contestObject.BonusPoints(t, view),
                  'a log that started in 2026 pays 250, whatever its QSOs say');

      (* NO YEAR AT ALL: an undated W1AW/5 QSO and no start time. *)
      view.Clear;
      view.Add(LoggedQSO('W1AW/5', Band20, CW, eCW, False, 0));
      CheckEquals(0, contestObject.BonusPoints(Totals(0, 0), view), 'a log with no year: no bonus');
      CheckEquals(2, capture.Lines.Count, 'and that is reported too');
      CheckTrue(Pos('no contest year', capture.Line(1)) > 0, 'as no year: ' + capture.Line(1));
   finally
      lg.RemoveAppender(keep);
      lg.Level := savedLevel;
      keep := nil;
      contestObject.Free;
      view.Free;
   end;
end;

(* THE YEARLY REMINDER, ON PURPOSE AGAINST THE CLOCK (Idaho's Q35 pattern):
   the first run of a year with no W1AW/5 ruling fails until the sponsor's
   word for that year is added to NewMexicoW1AWBonusPoints -- a new arm, "no
   bonus" if the sponsor drops it, never the 2026 value carried forward
   without their word. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoHasAW1AWBonusRulingForTheCurrentYear;
begin
   BeginTest('Test_NewMexicoHasAW1AWBonusRulingForTheCurrentYear');
   CheckTrue(TContestNewMexicoQP.HasW1AWBonusRuling(CurrentYear),
             Format('no W1AW/5 bonus ruling for %d: add the sponsor''s word for this year '
                    + '(newmexicoqsoparty.org) to uContestNewMexicoQP.NewMexicoW1AWBonusPoints',
                    [CurrentYear]));
end;

(* ---------------------------------------------------------------------------
   DATA
   --------------------------------------------------------------------------- *)

(* newmexico_cty.dom IS THE RULES' CHECK SHEET ("Enter the callsign of the
   first station that you worked within each county"): the 33 counties,
   each abbreviation once, each named as the rules name it, each its OWN
   multiplier -- "each different NM county worked (up to 33)" for every
   entrant, so no line maps a county to the state -- and nothing else: no
   INCLUDE, so an out-of-state entrant's table holds only counties (the
   host-area rule reads it). *)
procedure TContestNewMexicoQPTests.Test_NewMexicoCountyFileIsTheRulesCheckSheet;
var
   rulesTable: TStringList;
   lines: TStringList;
   seen: TStringList;
   i: integer;
   key: string;
   line: string;
begin
   BeginTest('Test_NewMexicoCountyFileIsTheRulesCheckSheet');
   rulesTable := TStringList.Create;
   lines := TStringList.Create;
   seen := TStringList.Create;
   try
      ReadRulesCountyCheckSheet(rulesTable);
      CheckEquals(33, rulesTable.Count, 'the rules list 33 counties');
      CheckEquals('Bernalillo', rulesTable.Values['BER'], 'the sheet is read: BER is Bernalillo');
      CheckEquals('De Baca', rulesTable.Values['DEB'], 'a two-word name: DEB is De Baca');

      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      lines.LoadFromFile(ShippedDomDir + 'newmexico_cty.dom');
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
         CheckTrue(rulesTable.IndexOfName(key) >= 0, key + ' is on the rules'' check sheet');
         CheckEquals(key + ' = ' + key + ',^' + rulesTable.Values[key], line,
                     'its own multiplier, its own alias, the rules'' name: ' + line);
         end;
      CheckEquals(33, seen.Count, 'newmexico_cty.dom holds the 33 counties and nothing else');
   finally
      seen.Free;
      lines.Free;
      rulesTable.Free;
   end;

   (* AS AN NM STATION READS IT (MultipliersIsCounties False): still 33
      multipliers, not one -- "each different NM county worked". *)
   LoadCountyTable('newmexico_cty.dom', False);
   try
      CheckEquals(33, mo.DomList.Count, 'in state, the 33 counties are 33 multipliers');
      CheckEquals('BER', MultiplierOf(CountyTable, 'BER'), 'Bernalillo counts as Bernalillo');
      CheckEquals('', MultiplierOf(CountyTable, 'NM'), 'no state is in the county file');
      CheckEquals('', MultiplierOf(CountyTable, 'AZ'), 'nor Arizona');
   finally
      FreeCountyTable;
   end;
end;

(* newmexico.dom, read as text: the header holds no '=' (the loader has no
   comment syntax, so a header line holding '=' would be a multiplier); the
   counties first; then "District of Columbia (DC) counts as Maryland" as
   Dc > Md, BEFORE S50.DOM so it is the first DC alias; then S50.DOM and
   P13.DOM -- S50 BEFORE P13, because P13 also spells Newfoundland LA and the
   first alias added wins; each INCLUDE spelt so the loader follows it; and
   Nl = NF,LB. Then loaded through the real loader: 33 counties + 50 states
   (DC is MD, not a 51st) + 13 provinces and territories = 96 domestic
   multipliers, New Mexico among them. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoInStateFileIsTheRulesMultipliers;
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
   BeginTest('Test_NewMexicoInStateFileIsTheRulesMultipliers');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(ShippedDomDir + 'newmexico.dom');
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
                       'newmexico.dom line ' + IntToStr(i + 1)
                       + ' is an INCLUDE the loader would not follow');
            if inHeader then
               begin
               CheckEquals(0, Pos('=', lines[i]),
                           'newmexico.dom header line ' + IntToStr(i + 1)
                           + ' would be read as an entry');
               end
            else if Pos('=', lines[i]) > 0 then
               begin
               entries := entries + Trim(lines[i]) + '|';
               end;
            end;
         end;
      CheckEquals('NEWMEXICO_CTY.DOM S50.DOM P13.DOM ', includes,
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
      LoadShippedDomFollowingIncludes(table, 'newmexico.dom', True, 0);
      CheckEquals(96, mo.DomList.Count,
                  '33 counties, 50 states (DC counted as MD) and 13 provinces and territories');
      CheckEquals('NM', MultiplierOf(table, 'NM'), 'New Mexico is one of them');
      CheckTrue(CountsForEntrant(NewMexicoHandle, True, MultiplierOf(table, 'NM'), rmDomestic),
                'and the class counts it');
      CheckEquals('BER', MultiplierOf(table, 'BER'),
                  'the counties are loaded first, so a county keeps its own code');
      CheckEquals('MD', MultiplierOf(table, 'DC'), 'DC is Maryland');
      CheckEquals('NL', MultiplierOf(table, 'NL'), 'NL is Newfoundland-Labrador');
      CheckEquals('NL', MultiplierOf(table, 'NF'), 'and NF is the same multiplier');
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

(* THE RULES' TEMPLATE LINE, word for word:

     QSO: 14000 PH 2010-02-07 1501 KB5SXB/M   59 BER    NK5W      59 SAN

   and the received columns of its SAMPLE LOG (sent "BER" throughout):
   "59 SAN", "59 BC", "599 DX" for LY2ZZ, "599 CT" for W1AW, "599 BER". The
   first part is laid out as PostUnit lays every contest's; the words must
   be the rules'. "Modes are PH, CW, or RY. Use RY to designate all digital
   modes": every digital submode RY, FM PH. The received QTH is what the
   real exporter selects (PostUnit.CabrilloReceivedQTH: the resolved
   DomesticQTH), so each QSO carries one as logging leaves it; a DX
   station's record has none. *)
procedure TContestNewMexicoQPTests.Test_NewMexicoCabrilloLinesAreTheRulesExamples;
var
   contestObject: TContestBase;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
   firstPart: string;
   sent: string;
   received: string;
   line: string;
   ext: ExtendedModeType;

   procedure Worked(const aRST: string; const aTyped: string; const aDomestic: string);
   begin
      qso := NewMexicoQso(Band20, CW, eCW, aTyped);
      qso.DomesticQTH := ShortString(aDomestic);
      qso.RSTSent := StrToIntDef(aRST, 0);
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := aRST;
      ctx.RSTReceived := aRST;
      ctx.HisQTH := CabrilloReceivedQTH(True, qso);
   end;

begin
   BeginTest('Test_NewMexicoCabrilloLinesAreTheRulesExamples');
   CheckEquals('NM-QSO-PARTY', ContestIdentity(NewMexicoHandle).CabrilloContestName('', ''),
               'CONTEST: NM-QSO-PARTY');

   contestObject := MakeNewMexico(StationAt(True));
   try
      (* "Modes are PH, CW, or RY. Use RY to designate all digital modes." *)
      CheckEquals('CW', contestObject.CabrilloModeString(CW, eCW), 'CW');
      CheckEquals('PH', contestObject.CabrilloModeString(Phone, eUSB), 'SSB is PH');
      CheckEquals('PH', contestObject.CabrilloModeString(FM, eFM), 'FM is PH');
      for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
         begin
         CheckEquals('RY', contestObject.CabrilloModeString(Digital, ext),
                     'digital submode ' + IntToStr(Ord(ext)) + ' is RY');
         end;

      (* THE TEMPLATE: KB5SXB/M, a Bernalillo mobile, works NK5W in
         Sandoval on phone. *)
      my := Default(TMyStationExchange);
      my.MyState := 'BER';
      Worked('59', 'SAN', 'SAN');
      firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                          ['14000', contestObject.CabrilloModeString(Phone, eUSB),
                           2010, 2, 7, 15, 1, 'KB5SXB/M']);
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('59  BER    ', sent, 'sent: RS and my county');
      CheckEquals('59  SAN    ', received, 'received: RS and the county received');
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'NK5W', received, '']);
      CheckEquals(Words('QSO: 14000 PH 2010-02-07 1501 KB5SXB/M   59 BER    NK5W      59 SAN'),
                  Words(line), 'the rules'' template line, word for word: ' + line);
      CheckEquals(CabrilloQSOLineFormatDefault, contestObject.CabrilloQSOLineFormat,
                  'the standard QSO line, no extra column');

      (* THE SAMPLE LOG'S RECEIVED COLUMNS. *)
      Worked('59', 'BC', 'BC');
      CheckEquals('59  BC     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  '"59 BER VE7RSV 59 BC": a province');
      Worked('599', 'CT', 'CT');
      CheckEquals('599 CT     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  '"599 BER W1AW 599 CT": a state');
      Worked('599', 'BER', 'BER');
      CheckEquals('599 BER    ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  '"599 BER W9WSW 599 BER": a county');
      (* "599 BER LY2ZZ 599 DX": LY2ZZ SENT its DXCC entity ("Non-New
         Mexico stations: RS(T) + State/Province/DXCC entity"), which the
         operator typed; the record holds no domestic QTH. The column is
         "DX" ("QTH is ... or "DX"") -- NY4I. *)
      Worked('599', 'LY', '');
      CheckEquals('', ctx.HisQTH, 'the real exporter selects no QTH for it');
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 DX     ', received, '"599 BER LY2ZZ 599 DX": a DX station is DX');
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                          ['14000', contestObject.CabrilloModeString(CW, eCW),
                           2010, 2, 7, 15, 7, 'N5ZGT']);
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'LY2ZZ', received, '']);
      CheckEquals(Words('QSO: 14000 CW 2010-02-07 1507 N5ZGT 599 BER LY2ZZ 599 DX'), Words(line),
                  'the sample''s DX line: ' + line);
      Worked('599', '', '');
      CheckEquals('599 DX     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'nothing typed is DX too');

      (* ADIF STX_STRING for an NM entrant: RST and the county. *)
      Worked('599', 'CT', 'CT');
      CheckEquals('599 BER    ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my county');
   finally
      contestObject.Free;
   end;

   (* AN ARIZONA ENTRANT works Bernalillo. *)
   contestObject := MakeNewMexico(StationAt(False));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'AZ';
      Worked('599', 'BER', 'BER');
      firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                          ['7000', contestObject.CabrilloModeString(CW, eCW),
                           2010, 2, 7, 16, 30, 'W7AAA']);
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      line := Format(contestObject.CabrilloQSOLineFormat, [firstPart, sent, 'N5ZGT', received, '']);
      CheckEquals(Words('QSO: 7000 CW 2010-02-07 1630 W7AAA 599 AZ N5ZGT 599 BER'), Words(line),
                  'the out-of-state line: ' + line);
      CheckEquals('599 AZ     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my state');
   finally
      contestObject.Free;
   end;
end;

(* A DX ENTRANT -- NY4I on #125: "A DX entrant sends its DXCC entity on the
   air (rule 6), but the Cabrillo column is "DX", per the rules' sample line
   599 BER LY2ZZ 599 DX". On the air: the CQ exchange is its entity (the
   party base's LocationOrOwnCountry). ADIF STX_STRING is ADIF's "contest QSO
   transmitted information", so it holds what went on the air: the entity
   (the party base's SentLocation). Cabrillo is the sponsor's scoring file,
   in their vocabulary: "DX" (the StateOrDX helper). *)
procedure TContestNewMexicoQPTests.Test_NewMexicoADXEntrantSendsItsEntityButWritesDX;
var
   contestObject: TContestBase;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
   firstPart: string;
   line: string;
begin
   BeginTest('Test_NewMexicoADXEntrantSendsItsEntityButWritesDX');
   contestObject := MakeNewMexico(DXStation('LY'));
   try
      CheckEquals(' 5NN LY', contestObject.CQExchangeDefault(DXStation('LY')),
                  'on the air: RS(T) + its DXCC entity');
      CheckEquals(' 5NN KP4', contestObject.CQExchangeDefault(DXStation('KP4')),
                  'a US possession sends its entity too');
      CheckEquals(' 5NN AZ', contestObject.CQExchangeDefault(StationAt(False)),
                  'a stated state is never replaced by the country');

      my := Default(TMyStationExchange);
      my.MyState := '';
      qso := NewMexicoQso(Band20, CW, eCW, 'BER');
      qso.DomesticQTH := 'BER';
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'BER';
      CheckEquals('599 DX     ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'Cabrillo: the sent QTH is "DX"');
      CheckEquals('599 LY     ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: what went on the air, the entity');
      firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                          ['14000', contestObject.CabrilloModeString(CW, eCW),
                           2026, 4, 11, 15, 30, 'LY2ZZ']);
      line := Format(contestObject.CabrilloQSOLineFormat,
                     [firstPart, contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                      'N5ZGT', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx), '']);
      CheckEquals(Words('QSO: 14000 CW 2026-04-11 1530 LY2ZZ 599 DX N5ZGT 599 BER'), Words(line),
                  'the DX entrant''s line: ' + line);
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet. First an
   Arizona entrant with the shipped newmexico_cty.dom, then a Bernalillo
   County entrant with the shipped newmexico.dom (its INCLUDEs followed by
   uTestShippedDom, since the test binary has no dom folder).
   --------------------------------------------------------------------------- *)

procedure TContestNewMexicoQPTests.Test_NewMexicoRealEngine;
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
   ctx: TCabrilloQSOContext;
   my: TMyStationExchange;

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
   BeginTest('Test_NewMexicoRealEngine');
   h := NewMexicoHandle;
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
      (* AS FoundContest SETS IT UP FOR AN ARIZONA STATION: not in New
         Mexico, so the county file with each county its own multiplier; K,
         VE, KH6 and KL are domestic countries (Add_KVEKH6KL, as for every
         party -- so a US call reaches the domestic parser); and the class's
         flags, as ApplyContestTraits writes them, so a wrong flag is seen
         here as a wrong dupe or multiplier. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := True;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'newmexico_cty.dom'),
                'newmexico_cty.dom loads');
      Contest := h;
      ReleaseActiveContest;
      StationInHostState := False;
      Settings.Qso.ByBand := ContestIdentity(h).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(h).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* BERNALILLO COUNTY, CW. *)
      dupe := Enter('N5ZGT', '599 BER', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 BER is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('BER', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the county');
      CheckTrue(rx.DomesticMult, 'Bernalillo is a new multiplier');
      CheckEquals(2, Integer(rx.QSOPoints), '"Each CW contact = 2 points"');

      (* "Stations may be worked only once per mode, per band"; "Each
         multiplier may be counted ONLY ONCE regardless of mode or band". *)
      dupe := Enter('N5ZGT', '599 BER', Band40, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckFalse(rx.DomesticMult, 'but Bernalillo is NOT a new multiplier on another band');

      dupe := Enter('N5ZGT', '59 BER', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '59 BER on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), '"Each Phone contact = 1 point"');
      CheckFalse(rx.DomesticMult, 'nor a new multiplier in another mode');

      (* DIGITAL IS ITS OWN DUPE MODE, and every digital mode is one mode:
         FT8 after CW is new, RTTY after FT8 is a dupe. *)
      dupe := Enter('N5ZGT', '599 BER', Band20, Digital, eFT8, accepted, rx);
      CheckTrue(accepted, 'FT8 is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m FT8 after CW is not a dupe');
      CheckFalse(QSOIsXQSO(ContestIdentity(h), rx), 'FT8 is no X-QSO (NY4I: FT8/FT4 count)');
      CheckEquals(2, Integer(rx.QSOPoints), '"Each Digital contact = 2 points"');
      dupe := Enter('N5ZGT', '599 BER', Band20, Digital, eRTTY, accepted, rx);
      CheckTrue(dupe, 'RTTY after FT8 on 20 m IS a dupe: both are Digital');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      dupe := Enter('N5ZGT', '599 BER', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'Bernalillo again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      (* FM is phone: FM after SSB on one band is the same mode, so a dupe. *)
      dupe := Enter('N5VHF', '59 SAN', Band2, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '2 m SSB is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(1, Integer(rx.QSOPoints), '2 m phone scores 1');
      dupe := Enter('N5VHF', '59 SAN', Band2, FM, eFM, accepted, rx);
      CheckTrue(dupe, 'the same station on 2 m FM after SSB IS a dupe: FM is phone');

      (* 160 m is credited; 30 m is "Not permitted": logged, an X-QSO. *)
      dupe := Enter('N5TOP', '599 LEA', Band160, CW, eCW, accepted, rx);
      CheckEquals(2, Integer(rx.QSOPoints), '160 m CW scores 2');
      CheckTrue(rx.DomesticMult, 'and Lea is a new multiplier');
      dupe := Enter('N5WRC', '599 EDD', Band30, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a 30 m QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(h), rx), 'as an X-QSO ("Not permitted: WARC bands")');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and Eddy is no multiplier from it');

      (* "W1AW/5 may be worked multiple times on the same band and mode when
         operating from different New Mexico counties". *)
      dupe := Enter('W1AW/5', '599 SFE', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'W1AW/5 from Santa Fe is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('W1AW/5', string(rx.Callsign), 'the call is stored as typed');
      dupe := Enter('W1AW/5', '599 TAO', Band20, CW, eCW, accepted, rx);
      CheckFalse(dupe, 'W1AW/5 from Taos on 20 m CW: a new station');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores');
      dupe := Enter('W1AW/5', '599 SFE', Band20, CW, eCW, accepted, rx);
      CheckTrue(dupe, 'W1AW/5 from Santa Fe again on 20 m CW: a dupe');

      (* "Non-NM stations: Work NM stations for NM counties only." A US call
         goes to the domestic parser, which refuses a QTH the county file
         does not know, naming the host-area reason when the in-state file
         knows it (DomesticQTHRefusalDomDir: the tree's dom folder, as
         FoundContest leaves it for this station). *)
      DomesticQTHRefusalDomDir := ShippedDomDir;
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := 'newmexico_cty.dom';

      accepted := True;
      Enter('W7AZ', '599 AZ', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'an Arizona station is refused');
      CheckEquals('Improper domestic QTH!! (AZ: work NM stations only)',
                  string(ExchangeErrorMessage),
                  'as an improper QTH, with the host-area reason');

      accepted := True;
      Enter('N5ABC', '599 BEX', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a misspelt county is refused');
      CheckEquals('Improper domestic QTH!! (BEX not in newmexico_cty.dom)',
                  string(ExchangeErrorMessage),
                  'as not in the county file');

      accepted := True;
      Enter('LY2ZZ', '599 LY', Band20, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'a DX station is refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['NM']), string(ExchangeErrorMessage),
                  'with the host-area reason');

      (* "only two counties at a time may be counted for the same contact":
         the first county is this QSO, the second is queued as its own QSO;
         three are refused before anything is queued. *)
      ClearPendingCounties;
      dupe := Enter('N5LINE', '599 SOC/SIE', Band15, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a county line of two is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('SOC', UpperCase(string(rx.QTHString)), 'the first county is this QSO');
      CheckEquals(1, PendingCountiesCount, 'one more county is queued');
      CheckEquals('SIE', UpperCase(DequeuePendingCounty), 'Sierra, as its own QSO');
      ClearPendingCounties;
      accepted := True;
      Enter('N5LINE', '599 SOC/SIE/CAT', Band15, CW, eCW, accepted, rx);
      CheckFalse(accepted, 'three counties are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), string(ExchangeErrorMessage),
                  'with the county-count message');
      CheckEquals(0, PendingCountiesCount, 'and nothing is queued');
      ClearPendingCounties;

      (* Q119: THE SAME REFUSED QSO, ARRIVING LOGGED (an import, a peer, an
         edit), is an automatic X-QSO for this entrant. *)
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      rx.Callsign := 'W7AZ';
      rx.Band := Band20;
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.Frequency := 14025000;
      rx.RSTSent := 599;
      rx.RSTReceived := 599;
      rx.QTHString := 'AZ';
      rx.tSysTime.qtYear := 26;
      rx.tSysTime.qtMonth := 4;
      rx.tSysTime.qtDay := 11;
      ActiveContest(Contest);
      CheckTrue(LoggedQSOIsXQSO(rx), 'out of state, a logged W7AZ AZ is an X-QSO');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'and its Cabrillo line says so');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx),
                 'and it counts toward no total');
      rx.QTHString := 'BER';
      CheckFalse(LoggedQSOIsXQSO(rx), 'out of state, a logged Bernalillo QSO is not');

      (* NOW A BERNALILLO COUNTY ENTRANT: in New Mexico, newmexico.dom (the
         counties, the states, the provinces), each county its own
         multiplier; and DXCC entities. *)
      MultipliersIsCounties := False;
      LoadShippedDomFollowingIncludes(DomQTHTable, 'newmexico.dom', True, 0);
      StationInHostState := True;
      Settings.Contest.DomesticFilename := 'newmexico.dom';
      ReleaseActiveContest;
      ActiveContest(Contest);
      mo.ClearAllMults;

      dupe := Enter('W7AAA', '599 AZ', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in NM, 599 AZ is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckTrue(rx.DomesticMult, 'Arizona is a new multiplier');
      dupe := Enter('W7AAA', '59 AZ', Band40, Phone, eUSB, accepted, rx);
      CheckFalse(dupe, 'Arizona on 40 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), 'and scores 1');
      CheckFalse(rx.DomesticMult, 'nor a new multiplier: once overall');

      dupe := Enter('W5RMY', '599 BER', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'another Bernalillo station is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'and Bernalillo is a new multiplier: "each different NM county worked"');

      dupe := Enter('N5NM', '599 NM', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 NM is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('NM', UpperCase(string(rx.DomMultQTH)), 'its multiplier is NM');
      CheckTrue(rx.DomesticMult, '"states worked (up to 50)": New Mexico counts');

      dupe := Enter('W3DC', '599 DC', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 DC is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), '"DC counts as Maryland"');
      CheckTrue(rx.DomesticMult, 'a new multiplier, Maryland');
      dupe := Enter('W3MD', '599 MD', Band20, CW, eCW, accepted, rx);
      CheckEquals('MD', UpperCase(string(rx.DomMultQTH)), 'Maryland itself');
      CheckFalse(rx.DomesticMult, 'is then no new multiplier');

      dupe := Enter('VE7RSV', '59 BC', Band20, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, '59 BC is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, 'British Columbia is a new multiplier');

      dupe := Enter('KH6AAA', '599 HI', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, '599 HI is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DomesticMult, '"Alaska and Hawaii count as state multipliers"');
      CheckFalse(rx.DXMult, '"... only": not a DX one');

      (* "and DX entities worked"; "United States and Canada do not count as
         DX entity multipliers". LY2ZZ sends its entity, as the rules
         require. *)
      dupe := Enter('LY2ZZ', '599 LY', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'in NM, a DX station is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'for 2 points');
      CheckFalse(rx.DomesticMult, 'no domestic multiplier');
      CheckTrue(rx.DXMult, 'and Lithuania is a new DX multiplier');
      CheckFalse(LoggedQSOIsXQSO(rx), 'and in state it is no X-QSO');
      CheckEquals('', string(rx.DomesticQTH), 'the record holds no domestic QTH');
      (* ITS CABRILLO COLUMN, as the real writer selects the QTH: "599 BER
         LY2ZZ 599 DX". *)
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTReceived := '599';
      ctx.HisQTH := CabrilloReceivedQTH(ContestHasDomesticMultiplier(ContestIdentity(h)), rx);
      my := Default(TMyStationExchange);
      my.MyState := 'BER';
      CheckEquals('599 DX     ', ContestIdentity(h).FormatCabrilloReceivedExchange(my, rx, ctx),
                  'the logged LY2ZZ is "DX" in the Cabrillo');
      dupe := Enter('LY3BB', '59 LY', Band40, Phone, eUSB, accepted, rx);
      CheckTrue(accepted, 'another Lithuanian station is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(rx.DXMult, 'Lithuania again is no new multiplier: once overall');

      dupe := Enter('KP4AA', '599 KP4', Band20, CW, eCW, accepted, rx);
      CheckTrue(accepted, 'a KP4 station is taken: ' + string(ExchangeErrorMessage));
      CheckTrue(rx.DXMult, 'Puerto Rico, a US possession, is a DX multiplier (NY4I)');

      dupe := Enter('N5FT', '599 COL', Band20, Digital, eFT4, accepted, rx);
      CheckTrue(accepted, 'an FT4 QSO is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckTrue(rx.DomesticMult, 'and Colfax is a new multiplier from it');
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

procedure TContestNewMexicoQPTests.RunAllTests;
begin
   Test_NewMexicoIdentity;
   Test_NewMexicoBands;
   Test_NewMexicoPoints;
   Test_NewMexicoEveryDigitalModeCounts;
   Test_NewMexicoInStateMultipliers;
   Test_NewMexicoInStateDXMultiplier;
   Test_NewMexicoOutOfStateWorksOnlyNewMexico;
   Test_NewMexicoCountyLineIsTwoCounties;
   Test_NewMexicoDupes;
   Test_NewMexicoPowerMultiplier;
   Test_NewMexicoW1AWBonus;
   Test_NewMexicoW1AWBonusIsTiedToTheLogsYear;
   Test_NewMexicoHasAW1AWBonusRulingForTheCurrentYear;
   Test_NewMexicoCountyFileIsTheRulesCheckSheet;
   Test_NewMexicoInStateFileIsTheRulesMultipliers;
   Test_NewMexicoCabrilloLinesAreTheRulesExamples;
   Test_NewMexicoADXEntrantSendsItsEntityButWritesDX;
   Test_NewMexicoRealEngine;
end;

end.

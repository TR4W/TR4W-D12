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

(* THE GEORGIA QSO PARTY -- added 2026-10-23, registered by its id. The rules
  are docs/ContestRules/QSOParties/Georgia/GA-QSO-PARTY-Rules.txt; each test
  below quotes the rule it holds.

  WHAT IS PINNED
    * its identity: the id, no legacy number, the
      names, the files, the flags, the party base and what it inherits;
    * its bands and its points, both sides of each edge;
    * a digital QSO is an automatic X-QSO (UsesMode);
    * the out-of-state entrant's host-area rule, typed and scored;
    * the county line (two counties) and the final score's formula;
    * the two .dom files against the rules' county table;
    * the Cabrillo QSO line, against the rules' own example;
    * THROUGH THE REAL ENGINE (ParametersOkay and the multiplier sheet, the
      shipped georgia_cty.dom): multipliers once per MODE not per band, the
      rover's new county, the host-area refusal, the county-line queue. *)
unit uTestContestGeorgiaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestGeorgiaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_GeorgiaIdentity;
      procedure Test_GeorgiaBands;
      procedure Test_GeorgiaPoints;
      procedure Test_GeorgiaDigitalIsAnXQSO;
      procedure Test_GeorgiaOutOfStateWorksOnlyGeorgia;
      procedure Test_GeorgiaCountyLineIsTwoCounties;
      procedure Test_GeorgiaScoreIsPointsTimesMultipliers;
      procedure Test_GeorgiaCountyFileIsTheRulesTable;
      procedure Test_GeorgiaInStateCountiesCountAsGeorgia;
      procedure Test_GeorgiaCabrilloLineIsTheRulesExample;
      procedure Test_GeorgiaRealEngineOutOfState;
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
   uContestGeorgiaQP,
   uDomFileKeys,
   uAppStrings,
   uTR4WStrings,
   uPendingCounties,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   uTestContestObjects,
   uTestExchangeParserStub,
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

function GeorgiaHandle: TContestHandle;
begin
   if not FindContestById(GA_QSO_PARTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('GA-QSO-PARTY is not registered');
      end;
end;

(* A Georgia station (Harris County) or a Florida one. The table knows the
   QTHs in GHostQTHs -- for an out-of-state station the 159 counties, as
   georgia_cty.dom loads them. *)
var
   GHostQTHs: string;

function StubKnowsHostQTHs(const aQTH: string): boolean;
begin
   Result := Pos(',' + UpperCase(Trim(aQTH)) + ',', ',' + GHostQTHs + ',') > 0;
end;

function StationAt(aInState: boolean): TStationContext;
begin
   Result := NoStation;
   Result.IsDomesticQTH := @StubKnowsHostQTHs;
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'HARR';
      end
   else
      begin
      Result.MyState := 'FL';
      end;
end;

function MakeGeorgia(const aStation: TStationContext): TContestBase;
begin
   Result := ContestClassFor(GeorgiaHandle).Create(GeorgiaHandle);
   Result.SetStation(aStation);
end;

function GeorgiaQso(aBand: BandType; aMode: ModeType; const aQTH: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.QTHString := ShortString(aQTH);
end;

(* The points ScoreQSO gives; the table knows every QTH unless the test says
   otherwise. *)
function PointsFor(aInState: boolean; aBand: BandType; aMode: ModeType;
                   const aQTH: string): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := MakeGeorgia(StationAt(aInState));
   try
      qso := GeorgiaQso(aBand, aMode, aQTH);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* THE RULES' COUNTY TABLE -- "GA County Names and Abbreviations", two
   columns of name and abbreviation per line, read from the rules file
   itself so the test cannot agree with a copy of it. aCounties holds
   ABBREVIATION=Name. *)
procedure ReadRulesCountyTable(aCounties: TStringList);
var
   rules: TStringList;
   cells: TStringList;
   path: string;
   i: integer;
   k: integer;
   inTable: boolean;
begin
   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
           '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
           'QSOParties' + PathDelim + 'Georgia' + PathDelim + 'GA-QSO-PARTY-Rules.txt';
   rules := TStringList.Create;
   cells := TStringList.Create;
   try
      rules.LoadFromFile(path);
      cells.Delimiter := #9;
      cells.StrictDelimiter := True;
      inTable := False;
      for i := 0 to rules.Count - 1 do
         begin
         if Pos('County'#9'Abbreviation', rules[i]) = 1 then
            begin
            inTable := True;
            Continue;
            end;
         if (not inTable) or (Trim(rules[i]) = '') then
            begin
            Continue;
            end;
         cells.DelimitedText := rules[i];
         k := 0;
         while k + 1 < cells.Count do
            begin
            aCounties.Add(Trim(cells[k + 1]) + '=' + Trim(cells[k]));
            k := k + 2;
            end;
         end;
   finally
      cells.Free;
      rules.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   IDENTITY
   --------------------------------------------------------------------------- *)

procedure TContestGeorgiaQPTests.Test_GeorgiaIdentity;
var
   h: TContestHandle;
   found: TContestHandle;
   identity: TContestBase;
   contestObject: TContestBase;
   legacy: integer;
begin
   BeginTest('Test_GeorgiaIdentity');
   CheckTrue(FindContestById('GA-QSO-PARTY', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestGeorgiaQP, 'to its class');
   CheckTrue(TContestGeorgiaQP.ClassParent = TContestStateQSOPartyBase,
             'on the state-party base, directly');
   CheckEquals('GA-QSO-PARTY', ContestId(h), 'the stored id');
   CheckFalse(ContestLegacyNumber(h, legacy), 'a new contest has no legacy number');

   identity := ContestIdentity(h);
   CheckEquals('Georgia QSO Party', identity.DisplayName, 'display name');
   CheckEquals('Georgia QSO Party', identity.FriendlyName, 'friendly name');
   (* "CONTEST: GA-QSO-PARTY" -- the rules' Cabrillo specification. *)
   CheckEquals('GA-QSO-PARTY', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('GA-QSO-PARTY', identity.CabrilloContestName('2026 GQP NY4I', 'X'),
               'the CONTEST: line, whatever the title');
   CheckEquals('GA-QSO-PARTY', identity.ADIFContestId, 'ADIF CONTEST_ID');
   CheckTrue(identity.WritesADIFContestId, 'export writes it');
   CheckTrue(FindContestByADIFContestId('GA-QSO-PARTY', found), 'import resolves it');
   CheckTrue(found = h, 'to the Georgia QSO Party');
   CheckEquals(328, identity.WA7BNMId, 'WA7BNM ref 328');
   CheckEquals(0, identity.QRZRUId, 'no QRZ.RU id');
   CheckEquals('', identity.SubmissionEmail,
               'logs go through the web page; the rules'' address is a fallback only');
   CheckEquals('GA', identity.HostState, 'host state');
   CheckEquals('GA', identity.QSOPartyArea, 'the New Contest prompt names Georgia');
   CheckEquals('georgia_cty', identity.DomesticFileName, 'the county file');
   CheckEquals('georgia', identity.InStateDomesticFileName, 'the in-state file');
   CheckTrue(identity.IsUSQSOParty, 'a US QSO party');
   CheckTrue(identity.IsActive, 'active');
   CheckTrue(identity.MarksDupes, 'marks dupes');

   (* "Stations may be worked once per band and mode"; "Each multiplier may
      be counted once per mode. (Not per band)"; 6 m is on the list. *)
   CheckTrue(identity.Flags = [cfQSOByBand, cfQSOByMode, cfMultByMode, cfVHFBandsEnabled],
             'dupes per band and mode, multipliers per mode only, 6 m on');
   CheckFalse(identity.MultByBand, 'a multiplier is NOT counted again per band');
   CheckTrue(identity.MultByMode, 'a multiplier is counted once per mode');

   CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(identity.ExchangeKind),
               'RST and a county, state, province or DX');
   CheckTrue(identity.ExchangeCarriesDomesticQTH, 'the exchange carries a domestic QTH');
   CheckTrue(ContestUsesDomesticFile(identity), 'looked up in the domestic file');
   CheckTrue(ContestHasDomesticMultiplier(identity), 'the domestic QTH is the multiplier');

   (* WHAT THE PARTY BASE GIVES IT, pinned here so a base change is seen. *)
   CheckTrue(identity.StripsRoverCountyFromCall, 'a rover''s /county is stripped live');
   CheckTrue(identity.SplitsRoverCallOnExport, 'and split on ADIF export');
   CheckTrue(identity.DupeKeyIncludesReceivedQTH,
             '"GEORGIA ROVER stations may be worked once per county, per mode, per band"');
   CheckTrue(identity.WritesADIFCounty, 'CNTY is written');

   (* "DX counts for QSO points only, there are no country multipliers" --
      for an entrant inside Georgia and outside it. *)
   contestObject := MakeGeorgia(StationAt(True));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'in GA: no DX multiplier');
      CheckFalse(contestObject.HasZoneMultiplier, 'in GA: no zone multiplier');
      CheckFalse(contestObject.HasPrefixMultiplier, 'in GA: no prefix multiplier');
      CheckEquals(' 5NN HARR', contestObject.CQExchangeDefault(StationAt(True)),
                  'in GA, the CQ exchange sends the county');
   finally
      contestObject.Free;
   end;
   contestObject := MakeGeorgia(StationAt(False));
   try
      CheckFalse(contestObject.HasDXMultiplier, 'outside GA: no DX multiplier');
      CheckEquals(' 5NN FL', contestObject.CQExchangeDefault(StationAt(False)),
                  'outside GA, the state');
      CheckEquals(' 5NN DX', contestObject.CQExchangeDefault(NoStation),
                  'a DX entrant sends "DX"');
   finally
      contestObject.Free;
   end;
end;

(* "SSB: 1.865, 3.810, 7.190, 14.250, 21.300, 28.450, 50.135" -- 160, 80,
   40, 20, 15, 10 and 6 m, nothing else. An off-band QSO is logged, scores 0
   and earns no multiplier (design 7.4). *)
procedure TContestGeorgiaQPTests.Test_GeorgiaBands;
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
begin
   BeginTest('Test_GeorgiaBands');
   GHostQTHs := 'HARR';
   identity := ContestIdentity(GeorgiaHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band160, Band80, Band40, Band20, Band15, Band10, Band6];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when on the rules'' list');
      CheckTrue(ContestCreditsBand(identity, b) = expected,
                'band ' + IntToStr(Ord(b)) + ' through the one seam');
      end;
   CheckEquals(2, PointsFor(False, Band6, CW, 'HARR'), '6 m CW scores');
   CheckEquals(2, PointsFor(False, Band160, CW, 'HARR'), '160 m CW scores');
   CheckEquals(0, PointsFor(False, Band30, CW, 'HARR'), '30 m scores nothing');
   CheckEquals(0, PointsFor(False, Band17, Phone, 'HARR'), '17 m scores nothing');
   CheckEquals(0, PointsFor(False, Band2, Phone, 'HARR'), '2 m scores nothing');
end;

(* "Each completed SSB contact counts one point. Each completed CW contact
   counts two points." -- inside Georgia and outside it alike. FM is phone. *)
procedure TContestGeorgiaQPTests.Test_GeorgiaPoints;
begin
   BeginTest('Test_GeorgiaPoints');
   GHostQTHs := 'HARR,MUSC';
   CheckEquals(2, PointsFor(False, Band20, CW, 'HARR'), 'outside GA, CW');
   CheckEquals(1, PointsFor(False, Band20, Phone, 'HARR'), 'outside GA, SSB');
   CheckEquals(1, PointsFor(False, Band6, FM, 'MUSC'), 'outside GA, FM is phone');
   CheckEquals(2, PointsFor(True, Band40, CW, 'PA'), 'in GA, CW with Pennsylvania');
   CheckEquals(1, PointsFor(True, Band40, Phone, 'ON'), 'in GA, SSB with Ontario');
   CheckEquals(2, PointsFor(True, Band15, CW, ''), 'in GA, a DX station is points');
   CheckEquals(0, PointsFor(True, Band20, Both, 'PA'), 'no mode a contact is made in');
   CheckEquals(0, PointsFor(True, Band20, NoMode, 'PA'), 'nor this one');
end;

(* "Digital contacts aren't allowed in the Georgia QSO Party." A digital QSO,
   whatever its submode, is an automatic X-QSO (Q98, QSOIsXQSO): logged, 0
   points, no multiplier. CW, SSB and FM ("SSB -- Phone only contacts") are
   credited, an old record with no submode included. Asked of the
   station-less identity, as every X-QSO reader asks it. *)
procedure TContestGeorgiaQPTests.Test_GeorgiaDigitalIsAnXQSO;
var
   identity: TContestBase;
   qso: ContestExchange;
   ext: ExtendedModeType;
begin
   BeginTest('Test_GeorgiaDigitalIsAnXQSO');
   GHostQTHs := 'HARR';
   identity := ContestIdentity(GeorgiaHandle);

   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'no digital submode is credited, ext ' + IntToStr(Ord(ext)));
      qso := GeorgiaQso(Band20, Digital, 'HARR');
      qso.ExtMode := ext;
      CheckTrue(QSOIsXQSO(identity, qso),
                'a digital QSO is an X-QSO, ext ' + IntToStr(Ord(ext)));
      end;

   qso := GeorgiaQso(Band20, CW, 'HARR');
   CheckFalse(QSOIsXQSO(identity, qso), 'a CW QSO is not an X-QSO');
   qso := GeorgiaQso(Band20, Phone, 'HARR');
   CheckFalse(QSOIsXQSO(identity, qso), 'an SSB QSO is not');
   qso := GeorgiaQso(Band6, FM, 'HARR');
   CheckFalse(QSOIsXQSO(identity, qso), 'nor an FM one: FM is phone');
   CheckTrue(ContestCreditsMode(identity, CW, eCW), 'CW is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eUSB), 'USB is credited');
   CheckTrue(ContestCreditsMode(identity, Phone, eNoMode), 'phone with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, FM, eFM), 'FM is credited');

   (* The readers that know only a ModeType key: the dupe sheet and the
      need-multiplier hint. *)
   CheckFalse(ContestCreditsModeKey(identity, Digital), 'the Digital key is not credited');
   CheckTrue(ContestCreditsModeKey(identity, CW), 'the CW key is');
   CheckTrue(ContestCreditsModeKey(identity, Phone), 'the Phone key is');

   (* THE OUTCOME, through ScoreQSO. *)
   CheckEquals(0, PointsFor(False, Band20, Digital, 'HARR'), 'outside GA, digital scores 0');
   CheckEquals(0, PointsFor(True, Band20, Digital, 'PA'), 'in GA, digital scores 0');
end;

(* ---------------------------------------------------------------------------
   THE HOST-AREA RULE -- "Stations outside Georgia may not count contacts
   with non-Georgia or DX stations." Q107: refused when typed, 0 points and
   no multiplier when logged any other way; the party base's rule.
   --------------------------------------------------------------------------- *)

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
   Result.IsDomesticQTH := @StubKnowsHostQTHs;
   Result.CallWindowHasCall := True;
end;

function ParseAs(aInState: boolean; const aQTH: string; out aMessage: string): boolean;
var
   contestObject: TContestBase;
   exch: ContestExchange;
begin
   GShapeSetsQTH := aQTH;
   contestObject := MakeGeorgia(StationAt(aInState));
   try
      exch := Default(ContestExchange);
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, ParseSession, exch, aMessage);
   finally
      contestObject.Free;
   end;
end;

procedure TContestGeorgiaQPTests.Test_GeorgiaOutOfStateWorksOnlyGeorgia;
var
   msg: string;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_GeorgiaOutOfStateWorksOnlyGeorgia');

   (* OUTSIDE GEORGIA the table is the county file. *)
   GHostQTHs := 'HARR,MUSC,COBB';
   CheckTrue(ParseAs(False, 'HARR', msg), 'outside GA, a Harris County station');
   CheckEquals('', msg, 'nothing to say');
   CheckFalse(ParseAs(False, 'PA', msg), 'outside GA, a Pennsylvania station: refused');
   CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['GA']), msg, 'with the reason');
   CheckFalse(ParseAs(False, 'DX', msg), 'outside GA, a DX station: refused');

   CheckEquals(2, PointsFor(False, Band20, CW, 'COBB'), 'logged: a county scores');
   CheckEquals(0, PointsFor(False, Band20, CW, 'PA'), 'logged: Pennsylvania scores 0');
   CheckEquals(0, PointsFor(False, Band20, CW, ''), 'logged: DX scores 0');

   contestObject := MakeGeorgia(StationAt(False));
   try
      qso := GeorgiaQso(Band20, CW, 'PA');
      CheckFalse(ContestCreditsWorkedStation(contestObject, qso),
                 'and earns no multiplier (the same predicate SetMultFlags asks)');
      qso := GeorgiaQso(Band20, CW, 'COBB');
      CheckTrue(ContestCreditsWorkedStation(contestObject, qso), 'a county is credited');
   finally
      contestObject.Free;
   end;

   (* INSIDE GEORGIA everyone may be worked. *)
   GHostQTHs := 'HARR,PA,ON';
   CheckTrue(ParseAs(True, 'PA', msg), 'in GA, a Pennsylvania station');
   CheckTrue(ParseAs(True, 'DX', msg), 'in GA, a DX station');
   CheckTrue(ParseAs(True, 'HARR', msg), 'in GA, another Georgia county');
   CheckEquals(2, PointsFor(True, Band20, CW, 'TX'), 'in GA, any station scores');
end;

(* "KU8E/HARR/MUSC if operating from the Harris/Muscogee county line" --
   "log GA county line QSO's as two separate contacts". Two counties. *)
procedure TContestGeorgiaQPTests.Test_GeorgiaCountyLineIsTwoCounties;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_GeorgiaCountyLineIsTwoCounties');
   contestObject := MakeGeorgia(NoStation);
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

(* "Final Score -Multiply total QSO points by total multipliers." No power
   multiplier, no bonus. *)
procedure TContestGeorgiaQPTests.Test_GeorgiaScoreIsPointsTimesMultipliers;
var
   t: TScoreTotals;
   view: TLoggedQSOList;
   contestObject: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_GeorgiaScoreIsPointsTimesMultipliers');
   t := Default(TScoreTotals);
   t.QSOPoints := 150;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 7;

   station := StationAt(True);
   station.MyPower := cpQRP;
   view := TLoggedQSOList.Create;
   contestObject := MakeGeorgia(station);
   try
      CheckEquals(150 * 7, contestObject.FinalScore(t, view),
                  'points x multipliers, QRP no different');
      station.MyPower := cpHIGH;
      contestObject.SetStation(station);
      CheckEquals(150 * 7, contestObject.FinalScore(t, view), 'HIGH the same');
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

(* georgia_cty.dom IS THE RULES' TABLE: the 159 counties, each abbreviation
   once, each named as the rules name it, each mapped to Ga for a Georgia
   entrant, and nothing else -- no INCLUDE, so an out-of-state entrant's
   table holds only counties (the host-area rule reads it). *)
procedure TContestGeorgiaQPTests.Test_GeorgiaCountyFileIsTheRulesTable;
var
   rulesTable: TStringList;
   lines: TStringList;
   seen: TStringList;
   i: integer;
   key: string;
   line: string;
   name: string;
begin
   BeginTest('Test_GeorgiaCountyFileIsTheRulesTable');
   rulesTable := TStringList.Create;
   lines := TStringList.Create;
   seen := TStringList.Create;
   try
      ReadRulesCountyTable(rulesTable);
      CheckEquals(159, rulesTable.Count, 'the rules list 159 counties ("Each Georgia county (159)")');

      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      lines.LoadFromFile(ShippedDomDir + 'georgia_cty.dom');
      for i := 0 to lines.Count - 1 do
         begin
         line := lines[i];
         CheckTrue(Pos('INCLUDE', UpperCase(line)) = 0,
                   'the county file includes nothing, line ' + IntToStr(i + 1));
         key := DomFileLineKey(line);
         if key = '' then
            begin
            Continue;
            end;
         CheckTrue(seen.IndexOf(key) < 0, 'each county once: ' + key);
         seen.Add(key);
         CheckTrue(rulesTable.IndexOfName(key) >= 0, key + ' is in the rules'' table');
         CheckEquals(key + ' > Ga = ' + key + ',^', Copy(line, 1, Length(key) * 2 + 10),
                     'mapped to Ga, its own alias: ' + line);
         name := Copy(line, Pos('^', line) + 1, MaxInt);
         CheckEquals(rulesTable.Values[key], name, 'named as the rules name it: ' + key);
         end;
      CheckEquals(159, seen.Count, 'georgia_cty.dom holds the 159 counties and nothing else');
   finally
      seen.Free;
      lines.Free;
      rulesTable.Free;
   end;
end;

(* "Multipliers -- Georgia Stations: Each USA State and DC, including Georgia
   (51); Each Canadian Province (13)". georgia.dom names the county file,
   S50, DC and P13 -- the shared files every party reads, held by their own
   tests -- and holds no entry of its own. Its INCLUDEs cannot be followed
   here: they resolve through uAppPaths.ShippedDomFilePath, the program's
   directory, and the test binary's directory has no dom folder. So the
   COUNTY file is read as an in-state station reads it (MultipliersIsCounties
   False): all 159 counties are ONE multiplier, Ga -- Georgia, the state. *)
procedure TContestGeorgiaQPTests.Test_GeorgiaInStateCountiesCountAsGeorgia;
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
   lines: TStringList;
   includes: string;
   i: integer;
   entry: TDomQTHEntry;
begin
   BeginTest('Test_GeorgiaInStateCountiesCountAsGeorgia');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(ShippedDomDir + 'georgia.dom');
      includes := '';
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('INCLUDE FILE ', UpperCase(lines[i])) = 1 then
            begin
            includes := includes + UpperCase(Trim(Copy(lines[i], 14, MaxInt))) + ' ';
            end
         else
            begin
            CheckEquals(0, Pos('=', lines[i]),
                        'georgia.dom line ' + IntToStr(i + 1) + ' would be read as an entry');
            end;
         end;
      CheckEquals('GEORGIA_CTY.DOM S50.DOM DC.DOM P13.DOM ', includes,
                  'the counties first, then the states, DC and the provinces');
   finally
      lines.Free;
   end;

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      CheckTrue(table.ReadDomQTHFile(ShippedDomDir + 'georgia_cty.dom', False),
                'georgia_cty.dom loads as an in-state station loads it');
      CheckEquals(1, mo.DomList.Count, 'the 159 counties are one multiplier');
      (* FindAlias, the table's own lookup: GetDomQTH asks the ACTIVE
         contest first, and there is none here. *)
      CheckTrue(table.FindAlias('HARR', entry), 'Harris is known');
      if table.FindAlias('HARR', entry) then
         begin
         CheckEquals('GA', UpperCase(string(entry.Multiplier)), 'and counts as Georgia');
         end;
      CheckTrue(table.FindAlias('WORT', entry), 'Worth, the table''s last, is known');
      if table.FindAlias('WORT', entry) then
         begin
         CheckEquals('GA', UpperCase(string(entry.Multiplier)), 'and counts as Georgia');
         end;
      CheckFalse(table.FindAlias('PA', entry), 'no state is in the county file');
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

(* THE RULES' EXAMPLE, word for word:
     QSO: 14000 CW 2016-04-09 1805 KU8E 599 HARR AA3B 599 PA
   "BAND, MODE, DATE, TIME, YOUR CALL, RST Sent, QTH Sent, CALL Worked, RST
   Received, QTH Received. DO NOT ADD ADDITIONAL COLUMNS." The first part is
   laid out as PostUnit lays every contest's (copied from its Cabrillo
   writer), so the columns are TR4W's widths; the words must be the
   example's. *)
procedure TContestGeorgiaQPTests.Test_GeorgiaCabrilloLineIsTheRulesExample;
const
   RULES_EXAMPLE = 'QSO: 14000 CW 2016-04-09 1805 KU8E 599 HARR AA3B 599 PA';
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

begin
   BeginTest('Test_GeorgiaCabrilloLineIsTheRulesExample');
   contestObject := MakeGeorgia(StationAt(True));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'HARR';
      qso := GeorgiaQso(Band20, CW, 'PA');
      (* The domestic table's key -- the record's DomesticQTH -- is what makes
         a QTH a county, state or province; a typed DX QTH has none. *)
      qso.DomesticQTH := 'PA';
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := 'PA';

      CheckEquals('CW', contestObject.CabrilloModeString(CW, eCW), 'CW');
      CheckEquals('PH', contestObject.CabrilloModeString(Phone, eUSB), 'SSB is PH');
      firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                          ['14000', contestObject.CabrilloModeString(CW, eCW),
                           2016, 4, 9, 18, 5, 'KU8E']);
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 HARR   ', sent, 'sent: RST and my county');
      CheckEquals('599 PA     ', received, 'received: RST and the state received');
      line := Format(contestObject.CabrilloQSOLineFormat,
                     [firstPart, sent, 'AA3B', received, '']);
      CheckEquals(Words(RULES_EXAMPLE), Words(line), 'the rules'' example, word for word: ' + line);
      CheckEquals(CabrilloQSOLineFormatDefault, contestObject.CabrilloQSOLineFormat,
                  'the standard QSO line, no extra column');

      (* "DX -- Send signal report and 'DX'": a DX station received, and a
         DX entrant's own column. *)
      qso.QTHString := '';
      qso.DomesticQTH := '';
      ctx.HisQTH := '';
      CheckEquals('599 DX     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'a DX station''s column is DX');

      (* A DX STATION LOGGED WITH A TYPED QTH ("599 DL") is still DX: the DX
         branch keeps the text in QTHString and the table resolves nothing, so
         no DomesticQTH and the exporter's HisQTH is empty. The column used
         to be empty (CabrilloReceivedRSTQTHDX tests QTHString); the rules
         say "DX -- Send signal report and DX" (2026-10-27). *)
      qso.QTHString := 'DL';
      CheckEquals('599 DX     ', contestObject.FormatCabrilloReceivedExchange(my, qso, ctx),
                  'a typed DX QTH is still DX in the column');
      qso.QTHString := '';

      my.MyState := '';
      CheckEquals('599 DX     ', contestObject.FormatCabrilloSentExchange(my, qso, ctx),
                  'a DX entrant sends DX');
      CheckEquals('599 DX     ', contestObject.FormatADIFSentExchange(my, qso),
                  'and its ADIF STX_STRING says what was sent: DX');

      my.MyState := 'HARR';
      CheckEquals('599 HARR   ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my county');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet, with the
   shipped georgia_cty.dom, for a Florida entrant
   --------------------------------------------------------------------------- *)

procedure TContestGeorgiaQPTests.Test_GeorgiaRealEngineOutOfState;
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
   rx: ContestExchange;
   accepted: boolean;
   dupe: boolean;
   i: integer;

   (* ONE QSO, AS AN OPERATOR ENTERS IT: ParametersOkay, then what
      LogContact does with the record it accepts -- the dupe question, the
      dupe's zero points, the sheets. Returns whether it was a dupe. *)
   function Enter(const aCall: string; const aExch: string; aBand: BandType;
                  aMode: ModeType; out aAccepted: boolean;
                  var aRX: ContestExchange): boolean;
   begin
      aRX := Default(ContestExchange);
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
   BeginTest('Test_GeorgiaRealEngineOutOfState');
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
      (* AS FoundContest SETS IT UP FOR A FLORIDA STATION: not in Georgia, so
         the county file with each county its own multiplier; K, VE, KH6 and
         KL are domestic countries (Add_KVEKH6KL, as for every party -- so a
         plain US call reaches the domestic parser, not the DX one); and the
         class's flags -- QSOs by band and mode, multipliers by mode only. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := True;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'georgia_cty.dom'),
                'georgia_cty.dom loads');
      Contest := GeorgiaHandle;
      ReleaseActiveContest;
      StationInHostState := False;
      (* FROM THE CLASS, as ApplyContestTraits writes them -- so a wrong
         flag is seen here as wrong multipliers, not only as a wrong set. *)
      Settings.Qso.ByBand := ContestIdentity(GeorgiaHandle).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(GeorgiaHandle).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(GeorgiaHandle).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(GeorgiaHandle).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* A ROVER IN HARRIS COUNTY, CW. *)
      dupe := Enter('KU8E/HARR', '599 HARR', Band20, CW, accepted, rx);
      CheckTrue(accepted, '599 HARR is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'and is not a dupe');
      CheckEquals('KU8E/HARR', string(rx.Callsign), 'the call is stored as typed');
      CheckEquals('HARR', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the county');
      CheckTrue(rx.DomesticMult, 'Harris on CW is a new multiplier');
      CheckEquals(2, Integer(rx.QSOPoints), 'CW scores 2');

      (* "Each multiplier may be counted once per mode. (Not per band)". *)
      dupe := Enter('KU8E/HARR', '599 HARR', Band40, CW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores 2');
      CheckFalse(rx.DomesticMult, 'but Harris on CW is NOT a new multiplier on 40 m');

      dupe := Enter('KU8E/HARR', '59 HARR', Band40, Phone, accepted, rx);
      CheckTrue(accepted, '59 HARR on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 40 m SSB is not a dupe');
      CheckEquals(1, Integer(rx.QSOPoints), 'SSB scores 1');
      CheckTrue(rx.DomesticMult, 'Harris on SSB IS a new multiplier');

      (* "Rovers that move to a new county can work everyone again". *)
      dupe := Enter('KU8E/MUSC', '599 MUSC', Band20, CW, accepted, rx);
      CheckFalse(dupe, 'the rover from Muscogee on 20 m CW is not a dupe');
      CheckTrue(rx.DomesticMult, 'Muscogee is a new multiplier');

      dupe := Enter('W4ABC', '599 COBB', Band20, CW, accepted, rx);
      CheckFalse(dupe, 'a plain call from Cobb');
      dupe := Enter('W4ABC', '599 FULT', Band20, CW, accepted, rx);
      CheckFalse(dupe, 'the same plain call from Fulton, same band and mode: a new county (Q118)');
      CheckEquals(2, Integer(rx.QSOPoints), 'and scores');
      dupe := Enter('W4ABC', '599 COBB', Band20, CW, accepted, rx);
      CheckTrue(dupe, 'Cobb again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      dupe := Enter('KU8E/HARR', '599 HARR', Band20, CW, accepted, rx);
      CheckTrue(dupe, 'the Harris rover again on 20 m CW IS a dupe');

      (* "Stations outside Georgia may not count contacts with non-Georgia or
         DX stations." *)
      (* A US CALL goes to the domestic parser (K is a domestic country),
         which refuses a QTH the county file does not know as an improper
         QTH -- before the party's own rule is asked. A DX call goes to the
         DX branch, which accepts any QTH, and the party's host-area rule
         refuses it with its own reason. *)
      (* THE IMPROPER QTH NAMES ITS REASON -- NY4I, 2026-10-23, after typing
         CT as an out-of-state entrant and reading only "Improper domestic
         QTH!!". The historical text is the stem; the reason is the one
         LOGSTUFF.RefuseDomesticQTH gives at every parser. As FoundContest
         leaves it for this station: MY COUNTRY derived (K), the county file
         named, and the in-state file found in the tree's dom folder (the
         test binary's own directory has none). *)
      DomesticQTHRefusalDomDir := ShippedDomDir;
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := 'georgia_cty.dom';

      (* A STATE: a place the contest knows (georgia.dom has PA through
         S50), which an out-of-state entrant may not work. *)
      accepted := True;
      Enter('AA3B', '599 PA', Band20, CW, accepted, rx);
      CheckFalse(accepted, 'a Pennsylvania station is refused');
      CheckEquals('Improper domestic QTH!! (PA: work GA stations only)',
                  string(ExchangeErrorMessage),
                  'as an improper QTH, with the host-area reason');

      (* The SAME reason from the single-word parser -- CT typed alone. *)
      accepted := True;
      Enter('W1AW', 'CT', Band20, CW, accepted, rx);
      CheckFalse(accepted, 'a Connecticut station is refused');
      CheckEquals('Improper domestic QTH!! (CT: work GA stations only)',
                  string(ExchangeErrorMessage),
                  'the single-word parser gives the same reason');

      (* A TYPO: not a county, not a state -- not in the file this entrant
         loaded, which is named. *)
      accepted := True;
      Enter('K4BAI', '599 HARX', Band20, CW, accepted, rx);
      CheckFalse(accepted, 'a misspelt county is refused');
      CheckEquals('Improper domestic QTH!! (HARX not in georgia_cty.dom)',
                  string(ExchangeErrorMessage),
                  'as not in the county file');

      (* NOTHING THAT COULD BE A QTH -- a report alone. *)
      accepted := True;
      Enter('K4BAI', '599', Band20, CW, accepted, rx);
      CheckFalse(accepted, 'a report alone is refused');
      CheckEquals('Improper domestic QTH!! (no QTH)',
                  string(ExchangeErrorMessage),
                  'as no QTH');

      (* MY COUNTRY EMPTY WINS THE SCREEN (2026-09-20's attribution): a
         configuration gap comes before any QTH reason. *)
      Settings.My.DeriveCountry('');
      accepted := True;
      Enter('AA3B', '599 PA', Band20, CW, accepted, rx);
      CheckFalse(accepted, 'still refused with no MY COUNTRY');
      CheckEquals(TC_IMPROPERDOMESITCQTH + ' ' + SExchangeModeBriefEmptyCountry,
                  string(ExchangeErrorMessage),
                  'and the screen names the empty MY COUNTRY');
      Settings.My.DeriveCountry('K');

      accepted := True;
      Enter('DL1AAA', '599 DX', Band20, CW, accepted, rx);
      CheckFalse(accepted, 'a DX station is refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['GA']), string(ExchangeErrorMessage),
                  'with the host-area reason');

      (* A COUNTY LINE -- "KU8E/HARR/MUSC": the first county is this QSO,
         the second is queued as its own QSO; three is refused. *)
      ClearPendingCounties;
      dupe := Enter('K4BAI', '599 TLBT/MUSC', Band15, CW, accepted, rx);
      CheckTrue(accepted, 'a county line of two is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('TLBT', UpperCase(string(rx.QTHString)), 'the first county is this QSO');
      CheckEquals(1, PendingCountiesCount, 'one more county is queued');
      CheckEquals('MUSC', UpperCase(DequeuePendingCounty), 'Muscogee, as its own QSO');
      ClearPendingCounties;
      accepted := True;
      Enter('K4BAI', '599 TLBT/MUSC/HARR', Band15, CW, accepted, rx);
      CheckFalse(accepted, 'three counties are refused');
      CheckEquals(Format(TC_TOOMANYCOUNTIES, [2]), string(ExchangeErrorMessage),
                  'with the county-count message');
      ClearPendingCounties;

      (* "Digital contacts aren't allowed": logged, an automatic X-QSO,
         nothing earned. *)
      dupe := Enter('N4DIG', '599 BIBB', Band20, Digital, accepted, rx);
      CheckTrue(accepted, 'a digital QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(GeorgiaHandle), rx), 'as an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and earns no multiplier');

      (* Q119 (ruled 2026-10-22, built 2026-10-23): A QSO THE HOST-AREA RULE
         REFUSES IS AN AUTOMATIC X-QSO. Typing W1AW's CT is refused above; the
         same QSO arriving as a LOGGED RECORD -- an import, a peer, an edit --
         is logged, and for this Florida entrant it is an X-QSO: the record's
         contest judged with the entrant (LoggedQSOContest), X-QSO: in the
         Cabrillo. *)
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      rx.Callsign := 'W1AW';
      rx.Band := Band20;
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.Frequency := 14025000;
      rx.RSTSent := 599;
      rx.RSTReceived := 599;
      rx.QTHString := 'CT';
      rx.tSysTime.qtYear := 26;
      rx.tSysTime.qtMonth := 4;
      rx.tSysTime.qtDay := 9;
      (* The session's object, its station as set-up leaves it. *)
      ActiveContest(Contest);
      CheckTrue(LoggedQSOIsXQSO(rx), 'out of state, a logged W1AW CT is an X-QSO');
      CheckEquals('X-QSO:', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 6),
                  'and its Cabrillo line says so');
      CheckFalse(QSOCountsTowardTotals(LoggedQSOContest(Contest), rx),
                 'and it counts toward no total');
      (* A STATION-LESS IDENTITY CANNOT JUDGE THE ENTRANT, so it answers the
         band and mode terms alone. *)
      CheckFalse(QSOIsXQSO(ContestIdentity(GeorgiaHandle), rx),
                 'the identity object does not judge the host-area rule');

      (* THE CONTROLS: a Georgia county out of state, and CT in state. *)
      rx.QTHString := 'COBB';
      CheckFalse(LoggedQSOIsXQSO(rx), 'out of state, a logged Cobb QSO is not');
      CheckEquals('QSO: ', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 5),
                  'a plain QSO: line');
      rx.QTHString := 'CT';
      StationInHostState := True;
      ActiveContest(Contest);
      CheckFalse(LoggedQSOIsXQSO(rx), 'in state, a logged W1AW CT is not an X-QSO');
      CheckEquals('QSO: ', Copy(string(BuildSingleQsoCabrilloLine(rx)), 1, 5),
                  'a plain QSO: line in state');
      StationInHostState := False;
      ActiveContest(Contest);
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

procedure TContestGeorgiaQPTests.RunAllTests;
begin
   Test_GeorgiaIdentity;
   Test_GeorgiaBands;
   Test_GeorgiaPoints;
   Test_GeorgiaDigitalIsAnXQSO;
   Test_GeorgiaOutOfStateWorksOnlyGeorgia;
   Test_GeorgiaCountyLineIsTwoCounties;
   Test_GeorgiaScoreIsPointsTimesMultipliers;
   Test_GeorgiaCountyFileIsTheRulesTable;
   Test_GeorgiaInStateCountiesCountAsGeorgia;
   Test_GeorgiaCabrilloLineIsTheRulesExample;
   Test_GeorgiaRealEngineOutOfState;
end;

end.

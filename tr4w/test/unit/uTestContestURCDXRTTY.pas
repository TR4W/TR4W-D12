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

(* THE URC DX RTTY CONTEST -- added 2026-10-22 (Q138), the first real contest
  registered by its id. The rules are docs/ContestRules/URC/rules.md; each
  test below quotes the rule it holds.

  WHAT IS PINNED
    * its identity: the id, no legacy number, refused on multi-op, the names,
      urc.dom, the flags;
    * its bands (160/80/40/20/15/10 m) and its mode (RTTY);
    * every row of the points table, the same territory and MMS;
    * the parse: a code goes to the RST-and-domestic-QTH format, MMS is read
      by the class -- with the stubbed parsers, and then through the REAL
      engine with the shipped urc.dom, which refuses a code the list does
      not hold;
    * one multiplier per territory per band, MMS never one -- through the
      real multiplier sheet;
    * the Cabrillo QSO line, against the rules' own example;
    * urc.dom against the sponsor's list: every code once, nothing else. *)
unit uTestContestURCDXRTTY;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestURCDXRTTYTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_URCIdentity;
      procedure Test_URCBandsAndMode;
      procedure Test_URCPointsEveryRow;
      procedure Test_URCSameTerritoryIsTheCode;
      procedure Test_URCMaritimeMobile;
      procedure Test_URCParseRoutes;
      procedure Test_URCMMSIsNoMultiplier;
      procedure Test_URCRealEngineParsesAndCountsPerBand;
      procedure Test_URCCabrilloLineIsTheRulesExample;
      procedure Test_URCDomFileIsTheSponsorsList;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   uSettingsModel,
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uContestURCDXRTTY,
   uTestContestObjects,
   uTestExchangeParserStub,
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

function URCHandle: TContestHandle;
begin
   if not FindContestById(URC_DX_RTTY_CONTEST_ID, Result) then
      begin
      raise Exception.Create('URC-DX-RTTY is not registered');
      end;
end;

(* A station whose territory is aMyCode, on aContinent. *)
function URCStation(const aMyCode: string; aContinent: ContinentType): TStationContext;
begin
   Result := NoStation;
   Result.MyState := aMyCode;
   Result.MyContinent := aContinent;
end;

function MakeURC(const aStation: TStationContext): TContestBase;
begin
   Result := ContestClassFor(URCHandle).Create(URCHandle);
   Result.SetStation(aStation);
end;

function URCQso(aBand: BandType; const aCode: string;
                aContinent: ContinentType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Band := aBand;
   Result.Mode := Digital;
   Result.ExtMode := eRTTY;
   Result.QTHString := ShortString(aCode);
   Result.QTH.Continent := aContinent;
end;

(* The points ScoreQSO gives, for an entrant in CLB, Asia. *)
function PointsFor(aBand: BandType; const aCode: string;
                   aContinent: ContinentType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := MakeURC(URCStation('CLB', Asia));
   try
      qso := URCQso(aBand, aCode, aContinent);
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

procedure TContestURCDXRTTYTests.Test_URCIdentity;
var
   h: TContestHandle;
   identity: TContestBase;
   legacy: integer;
begin
   BeginTest('Test_URCIdentity');
   CheckTrue(FindContestById('URC-DX-RTTY', h), 'the id resolves');
   CheckTrue(ContestClassFor(h) = TContestURCDXRTTY, 'to its class');
   CheckEquals('URC-DX-RTTY', ContestId(h), 'the stored id');
   CheckFalse(ContestLegacyNumber(h, legacy), 'a new contest has no legacy number');
   CheckFalse(ContestCanUseMultiOp(h), 'and is refused on the multi-op network');
   identity := ContestIdentity(h);
   CheckEquals('URC DX RTTY Contest', identity.DisplayName, 'display name');
   CheckEquals('URC DX RTTY Contest', identity.FriendlyName, 'friendly name');
   (* The rules' Cabrillo header examples say CONTEST: URCDX. *)
   CheckEquals('URCDX', identity.CabrilloName, 'Cabrillo CONTEST:');
   CheckEquals('URC-DX-RTTY', identity.ADIFContestId, 'ADIF CONTEST_ID -- ADIF lists none');
   CheckEquals('urc', identity.DomesticFileName, 'the territory list');
   CheckEquals('', identity.SubmissionEmail, 'logs go through the web form');
   CheckTrue(identity.Flags = [cfQSOByBand, cfMultByBand], 'QSOs and multipliers per band');
   CheckTrue(ContestUsesDomesticFile(identity), 'the territory is looked up in urc.dom');
   CheckTrue(ContestHasDomesticMultiplier(identity), 'the territory is a multiplier');
   CheckFalse(identity.HasDXMultiplier, 'no DX multiplier');
   CheckFalse(identity.HasZoneMultiplier, 'no zone multiplier');
   CheckFalse(identity.HasPrefixMultiplier, 'no prefix multiplier');
   CheckFalse(identity.IsUSQSOParty, 'no QSO party');
end;

(* "Modes: RTTY. Bands: 160m, 80m, 40m, 20m, 15m, 10m." *)
procedure TContestURCDXRTTYTests.Test_URCBandsAndMode;
var
   identity: TContestBase;
   b: BandType;
   m: ModeType;
   expected: boolean;
begin
   BeginTest('Test_URCBandsAndMode');
   identity := ContestIdentity(URCHandle);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in [Band160, Band80, Band40, Band20, Band15, Band10];
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when one of the six');
      end;
   for m := Low(ModeType) to High(ModeType) do
      begin
      CheckTrue(identity.RunsInMode(m) = (m = Digital),
                'mode ' + IntToStr(Ord(m)) + ': RTTY only');
      end;

   (* THE CREDITED MODES (Q98): RTTY, or a digital record with no submode or
      a generic data one; everything else is an automatic X-QSO. *)
   CheckTrue(ContestCreditsMode(identity, Digital, eRTTY), 'RTTY is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eRTTY_R), 'reverse RTTY is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eNoMode), 'digital with no submode is credited');
   CheckTrue(ContestCreditsMode(identity, Digital, eData), 'generic data is credited');
   CheckFalse(ContestCreditsMode(identity, Digital, eFT8), 'FT8 is not');
   CheckFalse(ContestCreditsMode(identity, Digital, ePSK31), 'PSK is not');
   CheckFalse(ContestCreditsMode(identity, CW, eCW), 'CW is not');
   CheckFalse(ContestCreditsMode(identity, Phone, eUSB), 'phone is not');
   CheckFalse(ContestCreditsMode(identity, FM, eFM), 'FM is not');
   CheckEquals(0, PointsFor(Band30, 'LPK', Asia), 'a 30 m QSO scores 0');
   CheckEquals(0, PointsFor(Band6, 'NJR', NorthAmerica), 'a 6 m QSO scores 0');
end;

(* ---------------------------------------------------------------------------
   POINTS
   --------------------------------------------------------------------------- *)

(* "Same Continent (Different Territory): 2 points on 40, 20, 15 meters; 3
   points on 10, 80 meters; 5 points on 160 meters. Different Continents: 4
   points on 40, 20, 15 meters; 5 points on 10 meters; 6 points on 80 meters;
   10 points on 160 meters." -- for an entrant in CLB (Asia). *)
procedure TContestURCDXRTTYTests.Test_URCPointsEveryRow;
begin
   BeginTest('Test_URCPointsEveryRow');
   CheckEquals(5, PointsFor(Band160, 'QTY', Asia), 'same continent 160 m');
   CheckEquals(3, PointsFor(Band80, 'QTY', Asia), 'same continent 80 m');
   CheckEquals(2, PointsFor(Band40, 'QTY', Asia), 'same continent 40 m');
   CheckEquals(2, PointsFor(Band20, 'QTY', Asia), 'same continent 20 m');
   CheckEquals(2, PointsFor(Band15, 'QTY', Asia), 'same continent 15 m');
   CheckEquals(3, PointsFor(Band10, 'QTY', Asia), 'same continent 10 m');

   CheckEquals(10, PointsFor(Band160, 'NJR', NorthAmerica), 'other continent 160 m');
   CheckEquals(6, PointsFor(Band80, 'NJR', NorthAmerica), 'other continent 80 m');
   CheckEquals(4, PointsFor(Band40, 'NJR', NorthAmerica), 'other continent 40 m');
   CheckEquals(4, PointsFor(Band20, 'NJR', NorthAmerica), 'other continent 20 m');
   CheckEquals(4, PointsFor(Band15, 'NJR', NorthAmerica), 'other continent 15 m');
   CheckEquals(5, PointsFor(Band10, 'NJR', NorthAmerica), 'other continent 10 m');
end;

(* "Same Territory: 1 point, regardless of the band." The territory is the
   CODE, compared with MY STATE (my code), not the country: LPK and CLB are
   both Russia and both Asia here, and LPK is not the same territory. *)
procedure TContestURCDXRTTYTests.Test_URCSameTerritoryIsTheCode;
var
   b: BandType;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_URCSameTerritoryIsTheCode');
   for b in [Band160, Band80, Band40, Band20, Band15, Band10] do
      begin
      CheckEquals(1, PointsFor(b, 'CLB', Asia), 'the same territory, band ' + IntToStr(Ord(b)));
      end;
   CheckEquals(1, PointsFor(Band20, ' clb ', Asia), 'the code is read upper case and trimmed');
   CheckEquals(2, PointsFor(Band20, 'LPK', Asia), 'another territory of the same continent');

   (* No code of my own: nothing is "the same territory". *)
   contestObject := MakeURC(URCStation('', Asia));
   try
      qso := URCQso(Band20, 'CLB', Asia);
      contestObject.ScoreQSO(qso);
      CheckEquals(2, Integer(qso.QSOPoints), 'with no MY STATE, CLB scores by continent');
   finally
      contestObject.Free;
   end;
end;

(* "Maritime mobile stations: 3 points, regardless of the band." -- before
   the continent rule, and even when the entrant is maritime mobile too. *)
procedure TContestURCDXRTTYTests.Test_URCMaritimeMobile;
var
   b: BandType;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_URCMaritimeMobile');
   for b in [Band160, Band80, Band40, Band20, Band15, Band10] do
      begin
      CheckEquals(3, PointsFor(b, 'MMS', NorthAmerica), 'MMS, band ' + IntToStr(Ord(b)));
      CheckEquals(3, PointsFor(b, 'MMS', Asia), 'MMS on my continent, band ' + IntToStr(Ord(b)));
      end;
   contestObject := MakeURC(URCStation('MMS', UnknownContinent));
   try
      qso := URCQso(Band160, 'MMS', UnknownContinent);
      contestObject.ScoreQSO(qso);
      CheckEquals(3, Integer(qso.QSOPoints), 'MMS working MMS is a maritime mobile QSO, 3');
   finally
      contestObject.Free;
   end;
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
   aExch.QTHString := 'PARSED';
   aExch.RSTReceived := 579;
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

function ParseAs(const aText: string; out aExch: ContestExchange): boolean;
var
   contestObject: TContestBase;
   msg: string;
begin
   GAsked := '';
   GAskedText := '';
   aExch := Default(ContestExchange);
   contestObject := MakeURC(URCStation('CLB', Asia));
   try
      Result := contestObject.ParseReceivedExchange(aText, StubSession, aExch, msg);
   finally
      contestObject.Free;
   end;
end;

(* "RST followed by a 3-letter territory code"; "Maritime mobile stations
   should send ... the MMS territory code". *)
procedure TContestURCDXRTTYTests.Test_URCParseRoutes;
var
   exch: ContestExchange;
begin
   BeginTest('Test_URCParseRoutes');
   CheckTrue(ParseAs('599 CLB', exch), '599 CLB');
   CheckEquals('ParseRSTDomesticQTH', GAsked, 'a code is the RST-and-domestic-QTH format');
   CheckEquals('599 CLB', GAskedText, 'with the text as typed');

   CheckTrue(ParseAs('599 MMS', exch), '599 MMS');
   CheckEquals('ParseRSTQTH', GAsked, 'MMS is read by the class: RST and the word');
   CheckEquals('MMS', string(exch.QTHString), 'and the QTH is MMS');
   CheckEquals(579, Integer(exch.RSTReceived), 'the report the parser read stays');

   CheckTrue(ParseAs('mms', exch), 'mms alone');
   CheckEquals('ParseRSTQTH', GAsked, 'MMS alone, any case');
   CheckEquals('MMS', string(exch.QTHString), 'the QTH is MMS');

   CheckTrue(ParseAs('MMS CLB', exch), 'MMS CLB');
   CheckEquals('ParseRSTDomesticQTH', GAsked, 'a word after MMS: the contest''s format');
   CheckTrue(ParseAs('5NN MMS', exch), '5NN MMS');
   CheckEquals('ParseRSTDomesticQTH', GAsked, 'a report that is not digits: the contest''s format');

   CheckTrue(TContestURCDXRTTY.TypedExchangeIsMaritimeMobile(' 599  MMS '), 'blanks around');
   CheckFalse(TContestURCDXRTTY.TypedExchangeIsMaritimeMobile('599 599 MMS'), 'three words');
   CheckFalse(TContestURCDXRTTY.TypedExchangeIsMaritimeMobile(''), 'nothing');
   CheckFalse(TContestURCDXRTTY.TypedExchangeIsMaritimeMobile('599 MMSX'), 'not MMS');
end;

(* "Maritime mobile stations do not count as multipliers". *)
procedure TContestURCDXRTTYTests.Test_URCMMSIsNoMultiplier;
var
   identity: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_URCMMSIsNoMultiplier');
   identity := ContestIdentity(URCHandle);
   qso := URCQso(Band20, 'MMS', Asia);
   CheckFalse(identity.CountsAsMultiplier(qso, rmDomestic), 'MMS is no territory multiplier');
   CheckTrue(identity.CountsAsMultiplier(qso, rmDX), 'the rule is the domestic kind''s only');
   qso := URCQso(Band20, 'CLB', Asia);
   CheckTrue(identity.CountsAsMultiplier(qso, rmDomestic), 'a code is one');
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay and the multiplier sheet, with urc.dom
   --------------------------------------------------------------------------- *)

(* "Territory Multiplier: 1 multiplier for each unique territory contacted
   per band. Maritime mobile stations do not count as multipliers but are
   worth 3 points." Through MainUnit.ParametersOkay -- the routine live
   entry's Enter calls -- and the real sheet, as uTestNYQPRover does. *)
procedure TContestURCDXRTTYTests.Test_URCRealEngineParsesAndCountsPerBand;
var
   savedContest: TContestHandle;
   savedQsoByBand: boolean;
   savedQsoByMode: boolean;
   savedMultByBand: boolean;
   savedMultByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   ctyPath: string;
   rx: ContestExchange;
   accepted: boolean;

   function Enter(const aCall: string; const aExch: string; aBand: BandType;
                  var aRX: ContestExchange): boolean;
   begin
      aRX := Default(ContestExchange);
      ActiveMode := Digital;
      CallWindowString := CallString(aCall);
      ExchangeErrorMessage := '';
      Result := ParametersOkay(CallString(aCall), Str40(aExch), aBand, Digital,
                               14080000, aRX);
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
   BeginTest('Test_URCRealEngineParsesAndCountsPerBand');
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   savedContest := Contest;
   savedQsoByBand := Settings.Qso.ByBand;
   savedQsoByMode := Settings.Qso.ByMode;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedTable := DomQTHTable;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'urc.dom'), 'urc.dom loads');

      (* The contest as its flags set it up: QSOs and multipliers by band. *)
      Contest := URCHandle;
      ReleaseActiveContest;
      Settings.Qso.ByBand := True;
      Settings.Qso.ByMode := False;
      Settings.Mult.ByBand := True;
      Settings.Mult.ByMode := False;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      accepted := Enter('UA5GGG', '599 LPK', Band20, rx);
      CheckTrue(accepted, '599 LPK is taken');
      CheckEquals('LPK', UpperCase(string(rx.DomMultQTH)), 'the multiplier is the code itself');
      CheckTrue(rx.DomesticMult, 'LPK on 20 m is a new multiplier');

      accepted := Enter('RA3ABC', '599 LPK', Band20, rx);
      CheckTrue(accepted, 'a second LPK station is taken');
      CheckFalse(rx.DomesticMult, 'LPK on 20 m again is no new multiplier');

      accepted := Enter('RA3ABC', '599 LPK', Band40, rx);
      CheckTrue(accepted, 'LPK on 40 m is taken');
      CheckTrue(rx.DomesticMult, 'LPK on 40 m is a new multiplier: per band');

      accepted := Enter('W1AW/MM', '599 MMS', Band20, rx);
      CheckTrue(accepted, '599 MMS is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('MMS', string(rx.QTHString), 'the QTH is MMS');
      CheckFalse(rx.DomesticMult, 'MMS is no multiplier');
      CheckEquals(3, Integer(rx.QSOPoints), 'MMS scores 3');

      accepted := Enter('K1ABC', '599 QQQ', Band20, rx);
      CheckFalse(accepted, 'QQQ is no code on the URC list: refused');
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
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      ExchangeErrorMessage := '';
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

(* ---------------------------------------------------------------------------
   EXPORT
   --------------------------------------------------------------------------- *)

(* THE RULES' EXAMPLE, word for word:
     QSO:  7040 RY 2024-10-04 0000 UA8AAA        599 CLB     UA5GGG        599 LPK
   The line is laid out as PostUnit lays every contest's (its first part's
   format is copied here from PostUnit's Cabrillo writer, and the contest's
   CabrilloQSOLineFormat), so the columns are TR4W's widths; a Cabrillo robot
   reads the words, and the words must be the example's. *)
procedure TContestURCDXRTTYTests.Test_URCCabrilloLineIsTheRulesExample;
const
   RULES_EXAMPLE = 'QSO:  7040 RY 2024-10-04 0000 UA8AAA        599 CLB     UA5GGG        599 LPK';
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
   BeginTest('Test_URCCabrilloLineIsTheRulesExample');
   contestObject := MakeURC(URCStation('CLB', Asia));
   try
      my := Default(TMyStationExchange);
      my.MyState := 'CLB';
      qso := URCQso(Band40, 'LPK', Europe);
      qso.RSTSent := 599;
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      (* What PostUnit hands a domestic-multiplier contest: the record's
         DomesticQTH -- blank here, as MMS's always is. The column must not
         depend on it. *)
      ctx.HisQTH := '';

      CheckEquals('RY', contestObject.CabrilloModeString(Digital, eRTTY), 'RTTY is RY');
      firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                          ['7040', contestObject.CabrilloModeString(Digital, eRTTY),
                           2024, 10, 4, 0, 0, 'UA8AAA']);
      sent := contestObject.FormatCabrilloSentExchange(my, qso, ctx);
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 CLB    ', sent, 'sent: RST and my code');
      CheckEquals('599 LPK    ', received, 'received: RST and the code received');
      line := Format(contestObject.CabrilloQSOLineFormat,
                     [firstPart, sent, 'UA5GGG', received, '']);
      CheckEquals(Words(RULES_EXAMPLE), Words(line), 'the rules'' example, word for word: ' + line);

      qso.QTHString := 'MMS';
      received := contestObject.FormatCabrilloReceivedExchange(my, qso, ctx);
      CheckEquals('599 MMS    ', received, 'a maritime mobile''s MMS is written');

      CheckEquals('599 CLB    ', contestObject.FormatADIFSentExchange(my, qso),
                  'ADIF STX_STRING: RST and my code');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   DATA
   --------------------------------------------------------------------------- *)

(* urc.dom holds every code of the sponsor's list once, each its own
   multiplier, and nothing else -- MMS above all. The count is the
   sponsor's table's (territories.md: 1156 rows), read from that file, not
   written here. *)
procedure TContestURCDXRTTYTests.Test_URCDomFileIsTheSponsorsList;
var
   dom: TStringList;
   source: TStringList;
   codes: TStringList;
   i: integer;
   line: string;
   key: string;
   listPath: string;
   tableRows: integer;
begin
   BeginTest('Test_URCDomFileIsTheSponsorsList');
   dom := TStringList.Create;
   source := TStringList.Create;
   codes := TStringList.Create;
   try
      codes.Sorted := True;
      codes.Duplicates := dupIgnore;
      dom.LoadFromFile(ShippedDomDir + 'urc.dom');
      for i := 0 to dom.Count - 1 do
         begin
         line := dom[i];
         if Pos('=', line) = 0 then
            begin
            Continue;
            end;
         key := Trim(Copy(line, 1, Pos('=', line) - 1));
         CheckEquals(3, Length(key), 'a 3-letter key: ' + line);
         CheckEquals(key + ' = ' + key + ', ^', Copy(line, 1, 12),
                     'the code is its own multiplier and alias: ' + line);
         CheckTrue(codes.IndexOf(key) < 0, 'each code once: ' + key);
         codes.Add(key);
         end;
      CheckTrue(codes.IndexOf('MMS') < 0, 'MMS is not in urc.dom');

      listPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
                  '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
                  'URC' + PathDelim + 'territories.md';
      source.LoadFromFile(listPath);
      tableRows := 0;
      for i := 0 to source.Count - 1 do
         begin
         (* A table row ends '| CODE |': the code is the last cell. *)
         line := Trim(source[i]);
         if (Length(line) < 7)            or
            (line[1] <> '|')              or
            (line[Length(line)] <> '|')   or
            (line[Length(line) - 6] <> '|') then
            begin
            Continue;
            end;
         key := Trim(Copy(line, Length(line) - 5, 5));
         if (Length(key) <> 3) or (key[1] < 'A') or (key[1] > 'Z') then
            begin
            Continue;
            end;
         Inc(tableRows);
         CheckTrue(codes.IndexOf(key) >= 0, 'the list''s ' + key + ' is in urc.dom');
         end;
      CheckTrue(tableRows > 1000, 'the sponsor''s table was read (' + IntToStr(tableRows) + ')');
      CheckEquals(tableRows, codes.Count, 'urc.dom holds the list''s codes and nothing else');
   finally
      codes.Free;
      source.Free;
      dom.Free;
   end;
end;

procedure TContestURCDXRTTYTests.RunAllTests;
begin
   Test_URCIdentity;
   Test_URCBandsAndMode;
   Test_URCPointsEveryRow;
   Test_URCSameTerritoryIsTheCode;
   Test_URCMaritimeMobile;
   Test_URCParseRoutes;
   Test_URCMMSIsNoMultiplier;
   Test_URCRealEngineParsesAndCountsPerBand;
   Test_URCCabrilloLineIsTheRulesExample;
   Test_URCDomFileIsTheSponsorsList;
end;

end.

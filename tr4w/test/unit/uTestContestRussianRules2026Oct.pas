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

(* TWO RUSSIAN CONTESTS' RULES, FROM THE SPONSORS' CURRENT RULES -- built
  2026-10-22 under NY4I's standing ruling of that day: a definitive statement
  in the sponsor's current rules is followed.

    THE RUSSIAN DX CONTEST (RDXC 2027 rules, SRR)
      Q97  / 7.3  Franz Josef Land is oblast FJ, RI1AN... is oblast AN, and each
                  is its own DXCC territory, whatever CTY.DAT says of the call.
      Q131 / 9    The country list is DXCC + WAE; points stay on DXCC (7.6).
      Q132 / 7.3  Kaliningrad, FJL and RI1AN score as European Russia.
      Q133 / 7.4  A /MM station is 5 points and no multiplier.
      Q134        russian.dom holds the appendix's 89 subjects, FJ and AN.
      Q135 / 11.5 No e-mail submission: logs go through ua9qcq.ru's form.

    THE POPOV YOUTH CUP (RADIO-YOC, SRR 2026 regulation)
      Q136        1 point; age + serial; 40 and 20 m; a repeat in another
                  30-minute tour is a new QSO; the multiplier is the subject
                  or the country once per contest; MY STATE is the age.

  Each rule is pinned both ways -- what it gives, and the case beside it
  that it must not touch. *)
unit uTestContestRussianRules2026Oct;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework, VC, uContestBase;

type
   TContestRussianRules2026OctTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_RDXCRussianEntrantPoints;
      procedure Test_RDXCKaliningradEntrantPoints;
      procedure Test_RDXCAsianRussianEntrantPoints;
      procedure Test_RDXCForeignEntrantPoints;
      procedure Test_RDXCWAEEntitiesScoreAsTheirDXCCCountry;
      procedure Test_RDXCMaritimeMobile;
      procedure Test_RDXCMultiplierKeysAndCountryList;
      procedure Test_RDXCOblastFromCall;
      procedure Test_RDXCHasNoSubmissionEmail;
      procedure Test_RussianDomHoldsTheAppendixSubjects;
      procedure Test_MaritimeMobileStation;
      procedure Test_RadioYOCPointsAndBands;
      procedure Test_RadioYOCExchange;
      procedure Test_RadioYOCTours;
      procedure Test_RadioYOCSetUp;
      procedure Test_TourJoinsTheReceivedQTHQualifier;
   end;

implementation

uses
   SysUtils,
   Classes,
   uCallSignRoutines,   (* MaritimeMobileStation *)
   uTR4WStrings,        (* TC_ENTERYOURAGEINMYSTATEFIELD *)
   uExchangeFields,     (* ExchangeFieldsQSONumberAge *)
   uContestRegistry,    (* ContestIdentity *)
   uTestExchangeParserStub,
   uTestContestObjects;

type
   (* THE PROTECTED FORMAT, REACHED THE WAY A DESCENDANT REACHES IT. *)
   TRuleCracker = class(TContestBase);

var
   GHelper: string;
   GText: string;

function RecordParser(const aHelper: string; const aText: string;
                      var aExch: ContestExchange): boolean;
begin
   GHelper := aHelper;
   GText := aText;
   Result := True;
end;

(* The engine's call-to-country service, as the hint is handed it: RI1AN...
   as CTY.DAT's Antarctica, R1FJ* as Franz Josef Land, anything else UA. *)
function HintCountryOfCall(const aCall: string): string;
begin
   if Copy(aCall, 1, 5) = 'RI1AN' then
      begin
      Result := 'CE9';
      end
   else if Copy(aCall, 1, 4) = 'R1FJ' then
      begin
      Result := 'R1FJ';
      end
   else
      begin
      Result := 'UA';
      end;
end;

function Station(const aCall: string; const aCountry: string;
                 aContinent: ContinentType): TStationContext;
begin
   Result := NoStation;
   Result.MyCall := aCall;
   Result.MyCountry := ShortString(aCountry);
   Result.MyContinent := aContinent;
end;

function Qso(const aCall: string; const aCountry: string;
             aContinent: ContinentType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Callsign := ShortString(aCall);
   Result.QTH.CountryID := ShortString(aCountry);
   Result.QTH.Continent := aContinent;
   Result.Band := Band20;
   Result.Mode := CW;
end;

function RDXCPoints(const aStation: TStationContext; const aCall: string;
                    const aCountry: string; aContinent: ContinentType): integer;
var
   contestObject: TContestBase;
   q: ContestExchange;
begin
   contestObject := Make(RUSSIANDX, aStation);
   try
      q := Qso(aCall, aCountry, aContinent);
      contestObject.ScoreQSO(q);
      Result := q.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* RULE 7.1: own country (Russia of our continent) 2, Russia of another
   continent 5, another country of our continent 3, another continent 5.
   Rule 7.3 makes Kaliningrad, FJL and RI1AN European Russia -- 2, not 3 --
   and the RI1AN answer does not depend on what CTY.DAT filed the call as. *)
procedure TContestRussianRules2026OctTests.Test_RDXCRussianEntrantPoints;
var
   ua: TStationContext;
begin
   BeginTest('Test_RDXCRussianEntrantPoints');
   ua := Station('UA3AAA', 'UA', Europe);
   CheckEquals(2, RDXCPoints(ua, 'RK3ABC', 'UA', Europe), 'UA working UA: 2');
   CheckEquals(5, RDXCPoints(ua, 'UA9ABC', 'UA9', Asia), 'UA working UA9: Russia of another continent, 5');
   CheckEquals(3, RDXCPoints(ua, 'DL1ABC', 'DL', Europe), 'UA working DL: 3');
   CheckEquals(5, RDXCPoints(ua, 'JA1ABC', 'JA', Asia), 'UA working JA: 5');
   CheckEquals(2, RDXCPoints(ua, 'UA2FAA', 'UA2', Europe), 'Q132: UA working UA2 is European Russia, 2 (was 3)');
   CheckEquals(2, RDXCPoints(ua, 'RI1FJA', 'R1FJ', Europe), 'Q132: UA working FJL, 2 (was 3)');
   CheckEquals(2, RDXCPoints(ua, 'RI1ANA', 'CE9', SouthAmerica), 'Q132: UA working RI1AN filed as CE9, 2 (was 5)');
   CheckEquals(2, RDXCPoints(ua, 'RI1ANA', 'UA', Europe), 'Q132: UA working RI1AN filed as UA, 2');
   CheckEquals(5, RDXCPoints(ua, 'KC4AAA', 'CE9', SouthAmerica), 'a non-Russian Antarctic station is still CE9, 5');
end;

(* RULE 7.3 FOR THE ENTRANT: a Kaliningrad station is European Russia, so
   UA is its own country (2, was 3). *)
procedure TContestRussianRules2026OctTests.Test_RDXCKaliningradEntrantPoints;
var
   ua2: TStationContext;
begin
   BeginTest('Test_RDXCKaliningradEntrantPoints');
   ua2 := Station('UA2FAA', 'UA2', Europe);
   CheckEquals(2, RDXCPoints(ua2, 'RK3ABC', 'UA', Europe), 'Q132: UA2 working UA, 2 (was 3)');
   CheckEquals(2, RDXCPoints(ua2, 'UA2FBB', 'UA2', Europe), 'UA2 working UA2, 2');
   CheckEquals(3, RDXCPoints(ua2, 'DL1ABC', 'DL', Europe), 'UA2 working DL, 3');
   CheckEquals(5, RDXCPoints(ua2, 'UA9ABC', 'UA9', Asia), 'UA2 working UA9, 5');
end;

procedure TContestRussianRules2026OctTests.Test_RDXCAsianRussianEntrantPoints;
var
   ua9: TStationContext;
begin
   BeginTest('Test_RDXCAsianRussianEntrantPoints');
   ua9 := Station('UA9AAA', 'UA9', Asia);
   CheckEquals(2, RDXCPoints(ua9, 'UA0ABC', 'UA9', Asia), 'UA9 working UA9, 2');
   CheckEquals(5, RDXCPoints(ua9, 'RK3ABC', 'UA', Europe), 'UA9 working UA, 5');
   CheckEquals(5, RDXCPoints(ua9, 'RI1ANA', 'CE9', SouthAmerica), 'UA9 working RI1AN (European Russia), 5');
   CheckEquals(5, RDXCPoints(ua9, 'UA2FAA', 'UA2', Europe), 'UA9 working UA2, 5');
   CheckEquals(3, RDXCPoints(ua9, 'JA1ABC', 'JA', Asia), 'UA9 working JA, 3');
end;

(* RULE 7.2: a Russian station 10, own country 2, another country of our
   continent 3, another continent 5. RI1AN is a Russian station (10, was 5
   by continent). *)
procedure TContestRussianRules2026OctTests.Test_RDXCForeignEntrantPoints;
var
   dl: TStationContext;
begin
   BeginTest('Test_RDXCForeignEntrantPoints');
   dl := Station('DL1AAA', 'DL', Europe);
   CheckEquals(10, RDXCPoints(dl, 'RK3ABC', 'UA', Europe), 'DL working UA, 10');
   CheckEquals(10, RDXCPoints(dl, 'UA9ABC', 'UA9', Asia), 'DL working UA9, 10');
   CheckEquals(10, RDXCPoints(dl, 'UA2FAA', 'UA2', Europe), 'DL working UA2, 10');
   CheckEquals(10, RDXCPoints(dl, 'RI1FJA', 'R1FJ', Europe), 'DL working FJL, 10');
   CheckEquals(10, RDXCPoints(dl, 'RI1ANA', 'CE9', SouthAmerica), 'Q132: DL working RI1AN, 10 (was 5)');
   CheckEquals(2, RDXCPoints(dl, 'DL2ABC', 'DL', Europe), 'DL working DL, 2');
   CheckEquals(3, RDXCPoints(dl, 'F1ABC', 'F', Europe), 'DL working F, 3');
   CheckEquals(5, RDXCPoints(dl, 'W1AW', 'K', NorthAmerica), 'DL working W, 5');
end;

(* RULE 7.6 BESIDE RULE 9: the WAE-only entity is a multiplier (the CQ list),
   but it scores as the DXCC country CTY.DAT gives the same call under the
   DXCC list -- exactly what it scored before Q131. *)
procedure TContestRussianRules2026OctTests.Test_RDXCWAEEntitiesScoreAsTheirDXCCCountry;
var
   italy: TStationContext;
   sicily: TStationContext;
   dl: TStationContext;
begin
   BeginTest('Test_RDXCWAEEntitiesScoreAsTheirDXCCCountry');
   italy := Station('I1AAA', 'I', Europe);
   sicily := Station('IT9AAA', '*IT9', Europe);
   dl := Station('DL1AAA', 'DL', Europe);
   CheckEquals(2, RDXCPoints(italy, 'IT9ABC', '*IT9', Europe), 'I working IT9: own DXCC country, 2');
   CheckEquals(2, RDXCPoints(italy, 'IG9ABC', '*IG9', Africa), 'I working IG9: Italy in Europe, 2');
   CheckEquals(2, RDXCPoints(sicily, 'I1ABC', 'I', Europe), 'IT9 working I, 2');
   CheckEquals(3, RDXCPoints(dl, 'IT9ABC', '*IT9', Europe), 'DL working IT9, 3');
   CheckEquals(3, RDXCPoints(dl, '4U1VIC', '*4U1V', Europe), 'DL working 4U1V (Austria), 3');
   CheckEquals(5, RDXCPoints(dl, 'TA1ABC', '*TA1', Europe), 'DL working TA1: Turkey, Asia by DXCC, 5');
   CheckEquals(3, RDXCPoints(dl, 'GM1ABC', '*GM/s', Europe), 'DL working Shetland (Scotland), 3');
   CheckEquals(3, RDXCPoints(dl, 'JW1ABC', '*JW/b', Europe), 'DL working Bear Island (Svalbard), 3');
end;

(* RULE 7.4: a /MM station is 5 for everybody and earns no multiplier; /AM
   is not /MM. *)
procedure TContestRussianRules2026OctTests.Test_RDXCMaritimeMobile;
var
   contestObject: TContestBase;
   q: ContestExchange;
   kind: RemainingMultiplierType;
begin
   BeginTest('Test_RDXCMaritimeMobile');
   CheckEquals(5, RDXCPoints(Station('DL1AAA', 'DL', Europe), 'DL1ABC/MM', 'DL', Europe),
               'Q133: DL working DL /MM, 5 (was 2)');
   CheckEquals(5, RDXCPoints(Station('UA3AAA', 'UA', Europe), 'UA3ABC/MM', 'UA', Europe),
               'Q133: UA working UA /MM, 5 (was 2)');
   CheckEquals(5, RDXCPoints(Station('DL1AAA', 'DL', Europe), 'UA3ABC/MM', 'UA', Europe),
               'Q133: DL working UA /MM, 5 (was 10)');
   CheckEquals(2, RDXCPoints(Station('DL1AAA', 'DL', Europe), 'DL1ABC/AM', 'DL', Europe),
               '/AM is not /MM: DL working DL /AM, 2');

   contestObject := Make(RUSSIANDX, Station('DL1AAA', 'DL', Europe));
   try
      q := Qso('DL1ABC/MM', 'DL', Europe);
      for kind in [rmDomestic, rmDX, rmZone, rmPrefix] do
         begin
         CheckFalse(ContestCountsMultiplier(contestObject, q, kind),
                    'Q133: a /MM station earns no multiplier, kind ' + IntToStr(Ord(kind)));
         end;
      q := Qso('DL1ABC/AM', 'DL', Europe);
      CheckTrue(ContestCountsMultiplier(contestObject, q, rmDX), '/AM still counts');
      q := Qso('DL1ABC', 'DL', Europe);
      CheckTrue(ContestCountsMultiplier(contestObject, q, rmDX), 'a plain call counts');
   finally
      contestObject.Free;
   end;
end;

(* RULES 7.3 AND 9: FJL and RI1AN are each their own DXCC territory whatever
   CTY.DAT filed the call as; Kaliningrad is CTY's UA2; a WAE-only entity is
   its own key; the country list is CQ's (DXCC + WAE). *)
procedure TContestRussianRules2026OctTests.Test_RDXCMultiplierKeysAndCountryList;

   function KeyOf(const aCall: string; const aCountry: string): string;
   var
      contestObject: TContestBase;
      key: DXMultiplierString;
   begin
      contestObject := Make(RUSSIANDX, Station('DL1AAA', 'DL', Europe));
      try
         key := 'UNSET';
         CheckTrue(contestObject.DXMultiplierKey(Qso(aCall, aCountry, Europe), key),
                   'RDXC assigns a DX key for ' + aCall);
         Result := string(key);
      finally
         contestObject.Free;
      end;
   end;

var
   contestObject: TContestBase;
begin
   BeginTest('Test_RDXCMultiplierKeysAndCountryList');
   CheckEquals('CE9', KeyOf('RI1ANA', 'UA'), 'Q97: RI1AN filed as UA is Antarctica, its own territory');
   CheckEquals('CE9', KeyOf('RI1ANC', 'CE9'), 'Q97: RI1AN filed as CE9 stays CE9');
   CheckEquals('R1FJ', KeyOf('RI1FJA', 'UA'), 'Q97: RI1FJ filed as UA is Franz Josef Land');
   CheckEquals('R1FJ', KeyOf('R1FJL', 'R1FJ'), 'FJL filed as R1FJ stays R1FJ');
   CheckEquals('UA2', KeyOf('UA2FAA', 'UA2'), 'Kaliningrad is CTY''s UA2');
   CheckEquals('UA', KeyOf('RK3ABC', 'UA'), 'European Russia is UA');
   CheckEquals('*IT9', KeyOf('IT9ABC', '*IT9'), 'Q131: Sicily is a WAE multiplier of its own');
   CheckEquals('KC4', KeyOf('KC4AAA', 'KC4'), 'any other call: its CTY country');

   contestObject := Make(RUSSIANDX, Station('DL1AAA', 'DL', Europe));
   try
      CheckTrue(ContestCountryMode(contestObject) = CQCountryMode,
                'Q131: the country list is DXCC + WAE (CQCountryMode), was ARRLCountryMode');
   finally
      contestObject.Free;
   end;
end;

(* RULE 7.3 FOR THE PRE-FILL AND THE HINT: FJL is FJ (was SP, read off
   R1FJ's "1F"), RI1AN is AN (was none -- CE9 is not Russian). Everything
   else is the one rule, RussianStationOblast (Q50). *)
procedure TContestRussianRules2026OctTests.Test_RDXCOblastFromCall;
var
   answer: string;
   c: TContestBase;
   lookups: TMultiplierHintLookups;
begin
   BeginTest('Test_RDXCOblastFromCall');
   c := ContestIdentity(RUSSIANDX);
   CheckTrue(c.InitialExchangeFromCall('RI1ANA', 'CE9', answer), 'Q97: RI1AN is a Russian station');
   CheckEquals('AN', answer, 'Q97: RI1AN pre-fills AN');
   CheckTrue(c.InitialExchangeFromCall('RI1ANA', 'UA', answer), 'RI1AN filed as UA');
   CheckEquals('AN', answer, 'Q97: and still AN');
   CheckTrue(c.InitialExchangeFromCall('R1FJL', 'R1FJ', answer), 'FJL is Russian');
   CheckEquals('FJ', answer, 'Q97: R1FJL pre-fills FJ (was SP)');
   CheckTrue(c.InitialExchangeFromCall('RI1FJA', 'UA', answer), 'RI1FJ filed as UA');
   CheckEquals('FJ', answer, 'Q97: and still FJ');
   CheckTrue(c.InitialExchangeFromCall('UA2FAA', 'UA2', answer), 'Kaliningrad');
   CheckEquals('KA', answer, 'Kaliningrad is KA, as before');
   CheckTrue(c.InitialExchangeFromCall('UA3ABC', 'UA', answer), 'Moscow');
   CheckEquals(GetRussiaOblastID('UA3ABC'), answer, 'the one rule elsewhere');
   CheckFalse(c.InitialExchangeFromCall('KC4AAA', 'CE9', answer), 'a non-Russian Antarctic station');
   CheckEquals('', answer, 'has no oblast');
   CheckFalse(c.InitialExchangeFromCall('DL1ABC', 'DL', answer), 'DL');
   CheckEquals('', answer, 'has no oblast');

   (* THE NEED-MULTIPLIER HINT asks the same rule, with the engine's
      country service; with none it has no opinion, as before. *)
   lookups := Default(TMultiplierHintLookups);
   CheckEquals('', c.DomesticMultiplierFromCall('RI1ANA', lookups), 'no country service, no hint');
   lookups.CountryOfCall := @HintCountryOfCall;
   CheckEquals('AN', c.DomesticMultiplierFromCall('RI1ANA', lookups), 'Q97: the hint for RI1AN is AN');
   CheckEquals('FJ', c.DomesticMultiplierFromCall('R1FJL', lookups), 'Q97: the hint for R1FJL is FJ');
   CheckEquals(GetRussiaOblastID('UA3ABC'), c.DomesticMultiplierFromCall('UA3ABC', lookups),
               'the hint elsewhere is the one rule');
end;

procedure TContestRussianRules2026OctTests.Test_RDXCHasNoSubmissionEmail;
begin
   BeginTest('Test_RDXCHasNoSubmissionEmail');
   CheckEquals('', ContestIdentity(RUSSIANDX).SubmissionEmail,
               'Q135: logs go only through ua9qcq.ru''s web form (rule 11.5), not logs@rdxc.org');
end;

(* Q134: target/dom/russian.dom holds every subject of the 2027 appendix --
   60 European, 29 Asian -- plus FJ and AN, and nothing else. The codes are
   rdxc.org/info's (Wayback snapshot 2025-11-16); DO, HE, LU and ZP were the
   four it lacked. *)
procedure TContestRussianRules2026OctTests.Test_RussianDomHoldsTheAppendixSubjects;
const
   SUBJECTS: array[0..90] of string = (
      (* European group 1 *)
      'SP', 'MA', 'MO', 'VR', 'TB', 'NN', 'VG', 'SA', 'SR', 'PE', 'TA', 'KR', 'ST', 'RK', 'RO',
      (* European group 2 *)
      'LO', 'KA', 'OR', 'LP', 'SM', 'YR', 'TL', 'RA', 'VL', 'KU', 'KG', 'BR', 'BO', 'UL', 'KI',
      'UD', 'AD', 'PM',
      (* European group 3 *)
      'KO', 'KL', 'AR', 'VO', 'NV', 'PS', 'MU', 'TV', 'KS', 'IV', 'SE', 'MR', 'MD', 'CU', 'AO',
      'KB',
      (* European group 4 *)
      'NO', 'KC', 'KM', 'SO', 'CN', 'IN', 'DA', 'DO', 'LU', 'HE', 'ZP',
      (* Asian groups 1-4 *)
      'CB', 'SV', 'KE', 'BA', 'KK',
      'TO', 'TN', 'OM', 'NS', 'OB', 'AL', 'HK', 'IR', 'PK',
      'HM', 'YN', 'KN', 'EA', 'AM', 'BU', 'YA', 'ZK', 'HA',
      'GA', 'SL', 'MG', 'CK', 'TU', 'KT',
      (* Rule 9's two more *)
      'FJ', 'AN');
var
   lines: TStringList;
   codes: TStringList;
   line: string;
   code: string;
   i: integer;
begin
   BeginTest('Test_RussianDomHoldsTheAppendixSubjects');
   lines := TStringList.Create;
   codes := TStringList.Create;
   try
      lines.LoadFromFile(ShippedDomDir + 'russian.dom');
      for i := 0 to lines.Count - 1 do
         begin
         line := lines[i];
         if Pos('=', line) = 0 then
            begin
            Continue;
            end;
         code := Copy(line, Pos('=', line) + 1, MaxInt);
         if Pos(',', code) > 0 then
            begin
            code := Copy(code, 1, Pos(',', code) - 1);
            end;
         codes.Add(UpperCase(Trim(code)));
         end;

      CheckEquals(Length(SUBJECTS), codes.Count,
                  'Q134: russian.dom has the 89 subjects plus FJ and AN, and no more');
      for i := Low(SUBJECTS) to High(SUBJECTS) do
         begin
         CheckTrue(codes.IndexOf(SUBJECTS[i]) >= 0, 'Q134: russian.dom has ' + SUBJECTS[i]);
         end;
   finally
      codes.Free;
      lines.Free;
   end;
end;

procedure TContestRussianRules2026OctTests.Test_MaritimeMobileStation;
begin
   BeginTest('Test_MaritimeMobileStation');
   CheckTrue(MaritimeMobileStation('DL1ABC/MM'), '/MM');
   CheckFalse(MaritimeMobileStation('DL1ABC/AM'), '/AM is not maritime');
   CheckFalse(MaritimeMobileStation('DL1ABC'), 'a plain call');
   CheckFalse(MaritimeMobileStation('DL1ABC/M'), '/M is not /MM');
   CheckFalse(MaritimeMobileStation('/MM'), 'too short');
   CheckTrue(MarineOrAirMobileStation('DL1ABC/AM'), 'the wider rule still sees /AM');
end;

function YOCPoints(aBand: BandType; aMode: ModeType): integer;
var
   contestObject: TContestBase;
   q: ContestExchange;
begin
   contestObject := Make(RADIOYOC, Station('UA3AAA', 'UA', Europe));
   try
      q := Qso('RK3ABC', 'UA', Europe);
      q.Band := aBand;
      q.Mode := aMode;
      q.QSOPoints := 99;
      contestObject.ScoreQSO(q);
      Result := q.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* Q136: "1 point for each contact" (was 3), on 7 and 14 MHz only. *)
procedure TContestRussianRules2026OctTests.Test_RadioYOCPointsAndBands;
var
   contestObject: TContestBase;
   b: BandType;
begin
   BeginTest('Test_RadioYOCPointsAndBands');
   CheckEquals(1, YOCPoints(Band20, Phone), 'Q136: 20 m phone, 1 (was 3)');
   CheckEquals(1, YOCPoints(Band40, Phone), 'Q136: 40 m phone, 1');
   CheckEquals(0, YOCPoints(Band80, Phone), 'Q136: 80 m is off-band, 0');
   CheckEquals(0, YOCPoints(Band15, Phone), 'Q136: 15 m is off-band, 0');

   contestObject := Make(RADIOYOC);
   try
      for b := Low(BandType) to High(BandType) do
         begin
         CheckEquals(Ord((b = Band40) or (b = Band20)), Ord(ContestCreditsBand(contestObject, b)),
                     'RADIO-YOC band ' + IntToStr(Ord(b)));
         end;
   finally
      contestObject.Free;
   end;
end;

(* Q136: the exchange is the age and the serial. One five-digit word is split
   before the engine's age + serial parser sees it; two words pass as typed. *)
procedure TContestRussianRules2026OctTests.Test_RadioYOCExchange;
var
   contestObject: TContestBase;
   q: ContestExchange;
   parsers: TExchangeParsers;
begin
   BeginTest('Test_RadioYOCExchange');
   parsers := StubExchangeParsers(@RecordParser);
   contestObject := Make(RADIOYOC);
   try
      CheckTrue(contestObject.ExchangeKind = AgeAndQSONumberExchange,
                'Q136: the exchange kind is age + serial (was QSONumberAndPreviousQSONumber)');
      CheckEquals(ExchangeFieldsText(ExchangeFieldsQSONumberAge),
                  ExchangeFieldsText(contestObject.ReceivedExchangeFields),
                  'Q136: the received fields are the age and the serial');

      q := Default(ContestExchange);
      GHelper := '';
      CheckTrue(TRuleCracker(contestObject).ParseReceivedExchangeFormat('15001', parsers, q),
                'five digits parse');
      CheckEquals('ParseAgeAndQSONumber', GHelper, 'Q136: by the age + serial parser');
      CheckEquals('15 001', GText, 'Q136: "15001" is age 15, serial 001');

      GHelper := '';
      CheckTrue(TRuleCracker(contestObject).ParseReceivedExchangeFormat(' 09123 ', parsers, q),
                'five digits with spaces round them');
      CheckEquals('09 123', GText, 'age 09, serial 123');

      GHelper := '';
      CheckTrue(TRuleCracker(contestObject).ParseReceivedExchangeFormat('15 001', parsers, q),
                'two words');
      CheckEquals('ParseAgeAndQSONumber', GHelper, 'the same parser');
      CheckEquals('15 001', GText, 'two words pass as typed');

      GHelper := '';
      TRuleCracker(contestObject).ParseReceivedExchangeFormat('1500A', parsers, q);
      CheckEquals('1500A', GText, 'not all digits: passed as typed');
      TRuleCracker(contestObject).ParseReceivedExchangeFormat('150011', parsers, q);
      CheckEquals('150011', GText, 'six digits: passed as typed');
   finally
      contestObject.Free;
   end;
end;

function YOCQso(aHour: integer; aMinute: integer; aBand: BandType): ContestExchange;
begin
   Result := Qso('RK3ABC', 'UA', Europe);
   Result.Mode := Phone;
   Result.Band := aBand;
   Result.tSysTime.qtHour := aHour;
   Result.tSysTime.qtMinute := aMinute;
end;

(* Q136: 8 tours of 30 minutes from 07:00 UTC. A repeat in another tour is a
   new QSO (another dupe key); in the same tour the key is the same, and the
   per-band dupe bits make another band a new QSO, as they always did. *)
procedure TContestRussianRules2026OctTests.Test_RadioYOCTours;
var
   c: TContestBase;
begin
   BeginTest('Test_RadioYOCTours');
   c := ContestIdentity(RADIOYOC);
   CheckEquals('TOUR 1', c.DupeKeyTour(YOCQso(7, 0, Band20)), '07:00 is tour 1');
   CheckEquals('TOUR 1', c.DupeKeyTour(YOCQso(7, 29, Band20)), '07:29 is tour 1');
   CheckEquals('TOUR 2', c.DupeKeyTour(YOCQso(7, 30, Band20)), '07:30 is tour 2');
   CheckEquals('TOUR 5', c.DupeKeyTour(YOCQso(9, 0, Band40)), '09:00 is tour 5');
   CheckEquals('TOUR 8', c.DupeKeyTour(YOCQso(10, 59, Band20)), '10:59 is tour 8');
   CheckEquals('', c.DupeKeyTour(YOCQso(6, 59, Band20)), '06:59 is before the contest');
   CheckEquals('', c.DupeKeyTour(YOCQso(11, 0, Band20)), '11:00 is after it');

   CheckTrue(c.DupeKeyQualifier(YOCQso(7, 10, Band20)) <> c.DupeKeyQualifier(YOCQso(7, 40, Band20)),
             'Q136: tours 1 and 2 are different dupe keys');
   CheckEquals(c.DupeKeyQualifier(YOCQso(7, 10, Band20)), c.DupeKeyQualifier(YOCQso(7, 20, Band40)),
               'one tour, one key -- the band decides within it');
   CheckEquals('', c.DupeKeyQualifier(YOCQso(12, 0, Band20)),
               'outside the contest: the call alone');

   (* THE BASE HAS NO TOURS: every other contest's key is unchanged. *)
   CheckEquals('', ContestIdentity(RUSSIANDX).DupeKeyTour(YOCQso(7, 10, Band20)),
               'RDXC has no tours');
   CheckEquals('', ContestIdentity(RUSSIANDX).DupeKeyQualifier(YOCQso(7, 10, Band20)),
               'and its dupe key is the call alone');
end;

(* Q136: what the session states -- the tour countdown, RFOBL MODE (the
   subject multiplier) and phone -- the prompt for the age in MY STATE, and
   the multiplier once per contest (no cfMultByBand). *)
procedure TContestRussianRules2026OctTests.Test_RadioYOCSetUp;
var
   contestObject: TContestBase;
   session: TSessionDefaults;
   prompts: TNewContestPrompts;
begin
   BeginTest('Test_RadioYOCSetUp');
   contestObject := Make(RADIOYOC);
   session := TSessionDefaults.Create;
   prompts := TNewContestPrompts.Create;
   try
      contestObject.DescribeSession(NoStation, session);
      CheckEquals(30, session.MinitourDuration, 'Q136: 30-minute tours');
      CheckTrue(session.IsStated(svRfoblMode) and session.RfoblMode,
                'Q136: RFOBL MODE, so a Russian call is its subject');
      CheckTrue(session.Mode = Phone, 'Q136: SSB');

      contestObject.DescribeNewContestPrompts(prompts);
      CheckEquals(1, prompts.ChoiceCount, 'one prompt on choosing');
      if prompts.ChoiceCount = 1 then
         begin
         CheckEquals(TC_ENTERYOURAGEINMYSTATEFIELD, prompts.Choice(0).Text,
                     'Q136: the age goes in MY STATE');
         CheckTrue(prompts.Choice(0).Field = ncfMyState, 'in MY STATE');
         end;

      CheckFalse(cfMultByBand in contestObject.Flags,
                 'Q136: a multiplier counts once for the whole contest, regardless of band');
   finally
      prompts.Free;
      session.Free;
      contestObject.Free;
   end;
end;

(* THE QUALIFIER'S TWO PARTS DO NOT COLLIDE: a state party's key is its QTH
   and nothing more (no tours), as it was. *)
procedure TContestRussianRules2026OctTests.Test_TourJoinsTheReceivedQTHQualifier;
var
   q: ContestExchange;
begin
   BeginTest('Test_TourJoinsTheReceivedQTHQualifier');
   q := YOCQso(7, 10, Band20);
   q.DomesticQTH := 'ALB';
   CheckEquals('ALB', ContestIdentity(NYQP).DupeKeyQualifier(q),
               'a state party: the received QTH alone, no tour');
   CheckEquals(#1'TOUR 1', ContestIdentity(RADIOYOC).DupeKeyQualifier(q),
               'RADIO-YOC: the tour alone -- it does not key on the QTH');
end;

procedure TContestRussianRules2026OctTests.RunAllTests;
begin
   Test_RDXCRussianEntrantPoints;
   Test_RDXCKaliningradEntrantPoints;
   Test_RDXCAsianRussianEntrantPoints;
   Test_RDXCForeignEntrantPoints;
   Test_RDXCWAEEntitiesScoreAsTheirDXCCCountry;
   Test_RDXCMaritimeMobile;
   Test_RDXCMultiplierKeysAndCountryList;
   Test_RDXCOblastFromCall;
   Test_RDXCHasNoSubmissionEmail;
   Test_RussianDomHoldsTheAppendixSubjects;
   Test_MaritimeMobileStation;
   Test_RadioYOCPointsAndBands;
   Test_RadioYOCExchange;
   Test_RadioYOCTours;
   Test_RadioYOCSetUp;
   Test_TourJoinsTheReceivedQTHQualifier;
end;

end.

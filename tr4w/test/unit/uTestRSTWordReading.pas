unit uTestRSTWordReading;
{$I ..\..\src\tr4w.inc}

(* ISSUE 330: ONE READING OF A TYPED REPORT.

   LOGSTUFF.SetRST was a second report check beside tree.ValidRST and had
   drifted from it: on CW a lone strength gave 509 + n (5 was 514; ValidRST
   gives 559), the CW floor was 111 (ValidRST: 100) and the Phone floor 11
   (10), and it had no Digital arm, so every Digital entry was refused. Its
   two callers -- the RS(T)-and-age parser (Radio Memory) and the RS(T)-and-
   serial-or-French-department parser (REF CW/SSB) -- read the report through
   LOGSTUFF.ReadRSTWord now, and SetRST is deleted.

   The CW zone-then-report form of ReadRSTAndNumberOfDigits ('14 599'; the
   zone parser and the licence-year parser) stored StrToIntDef of the report
   word after a length test only, so '14 699' logged a report of 699 (D7 did
   the same). It asks ReadRSTWord too, and a refusal names the report
   (SExchangeNotASignalReport), not the zone or the year.

   Driven directly, with ActiveMode, the session's DefaultRST and the CTY zone
   mode set and restored here; the report, the zone and the age are pre-set to
   sentinels, so "untouched" is visible. *)

interface

uses
   uTR4WTestFramework,
   VC;

type
   TRSTWordReadingTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      FSavedMode: ModeType;
      FSavedDefault: Word;
      FSavedZoneMode: ZoneModeType;
      procedure EnterMode(aMode: ModeType);
      procedure LeaveMode;
      procedure AgeAccepted(const aText: string; aMode: ModeType;
                            aExpectRST, aExpectAge: integer);
      procedure AgeRefused(const aText: string; aMode: ModeType);
      procedure Test_AgeParserReadsTheReportAsValidRSTDoes;
      procedure Test_AgeParserRefusesWhatValidRSTRefuses;
      procedure Test_FrenchDepartmentParserReadsTheReportAsValidRSTDoes;
      procedure Test_ZoneThenReportFormChecksTheReport;
      procedure Test_YearThenReportFormChecksTheReport;
   end;

implementation

uses
   SysUtils,
   uCTYDAT,
   uAppStrings,
   uTR4WStrings,
   LogWind,
   LOGSTUFF;

const
   SENTINEL_RST = 337;
   SENTINEL_AGE = 77;
   SENTINEL_ZONE = 7;

procedure TRSTWordReadingTests.EnterMode(aMode: ModeType);
begin
   FSavedMode := ActiveMode;
   FSavedDefault := DefaultRST;
   FSavedZoneMode := CTY.ctyZoneMode;
   ActiveMode := aMode;
   if aMode in [Phone, FM] then
      begin
      DefaultRST := 59;
      end
   else
      begin
      DefaultRST := 599;
      end;
   CTY.ctyZoneMode := CQZoneMode;
end;

procedure TRSTWordReadingTests.LeaveMode;
begin
   ActiveMode := FSavedMode;
   DefaultRST := FSavedDefault;
   CTY.ctyZoneMode := FSavedZoneMode;
end;

procedure TRSTWordReadingTests.AgeAccepted(const aText: string; aMode: ModeType;
   aExpectRST, aExpectAge: integer);
var
   rx: ContestExchange;
   accepted: boolean;
   what: string;
begin
   what := '"' + aText + '" mode ' + IntToStr(Ord(aMode));
   EnterMode(aMode);
   try
      rx := Default(ContestExchange);
      rx.RSTReceived := SENTINEL_RST;
      rx.Age := SENTINEL_AGE;
      accepted := ProcessRSTAgeAndPossibleSK(ShortString(aText), rx);
   finally
      LeaveMode;
      end;
   CheckTrue(accepted, what + ' is accepted');
   CheckEquals(aExpectRST, Integer(rx.RSTReceived), what + ' RS(T)');
   CheckEquals(aExpectAge, Integer(rx.Age), what + ' age');
end;

procedure TRSTWordReadingTests.AgeRefused(const aText: string; aMode: ModeType);
var
   rx: ContestExchange;
   accepted: boolean;
   what: string;
begin
   what := '"' + aText + '" mode ' + IntToStr(Ord(aMode));
   EnterMode(aMode);
   try
      rx := Default(ContestExchange);
      rx.RSTReceived := SENTINEL_RST;
      rx.Age := SENTINEL_AGE;
      accepted := ProcessRSTAgeAndPossibleSK(ShortString(aText), rx);
   finally
      LeaveMode;
      end;
   CheckFalse(accepted, what + ' is refused');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), what + ' RS(T) untouched');
   CheckEquals(SENTINEL_AGE, Integer(rx.Age), what + ' age untouched');
end;

(* ValidRST's ranges, which SetRST had drifted from. Each line whose comment
   says "was" is a reading that moved with issue 330. *)
procedure TRSTWordReadingTests.Test_AgeParserReadsTheReportAsValidRSTDoes;
begin
   BeginTest('Test_AgeParserReadsTheReportAsValidRSTDoes');
   AgeAccepted('5 45', CW, 559, 45);           (* was 514 *)
   AgeAccepted('1 45', CW, 519, 45);           (* was 510 *)
   AgeAccepted('9 45', CW, 599, 45);           (* was 518 *)
   AgeAccepted('579 45', CW, 579, 45);
   AgeAccepted('100 45', CW, 100, 45);         (* was refused: SetRST's floor 111 *)
   AgeAccepted('599 45', CW, 599, 45);
   (* 10..59 off Phone: ValidRST takes it and does not write it, so the
      report is the session's default -- its rule for every parser. *)
   AgeAccepted('57 45', CW, 599, 45);          (* was refused *)
   AgeAccepted('5 45', Phone, 55, 45);
   AgeAccepted('10 45', Phone, 10, 45);        (* was refused: SetRST's floor 11 *)
   AgeAccepted('59 45', Phone, 59, 45);
   AgeAccepted('599 45', Digital, 599, 45);    (* was refused: no Digital arm *)
   AgeAccepted('579 45', Digital, 579, 45);    (* was refused *)
end;

procedure TRSTWordReadingTests.Test_AgeParserRefusesWhatValidRSTRefuses;
begin
   BeginTest('Test_AgeParserRefusesWhatValidRSTRefuses');
   AgeRefused('699 45', CW);
   AgeRefused('0 45', CW);
   AgeRefused('1234 45', CW);
   AgeRefused('599 45', Phone);
   AgeRefused('699 45', Digital);
end;

(* The REF parser reads the words ParseArray2 cut (see the report: nothing in
   the engine calls ParseArray2 before it, so it is called here). A station
   that is not French: RS(T) and serial. *)
procedure TRSTWordReadingTests.Test_FrenchDepartmentParserReadsTheReportAsValidRSTDoes;
var
   rx: ContestExchange;
   accepted: boolean;

   function Run(const aText: string; aMode: ModeType): boolean;
   begin
      EnterMode(aMode);
      try
         rx := Default(ContestExchange);
         rx.QTH.CountryID := 'K';
         rx.RSTReceived := SENTINEL_RST;
         ParseArray2(Str80(aText));
         Result := ProcessRSTAndQSONumberOrFrenchDepartmentExchange(Str80(aText), rx);
      finally
         (* An empty entry zeroes ParserArray, so no later suite inherits
            these words. *)
         ParseArray2('');
         LeaveMode;
         end;
   end;

begin
   BeginTest('Test_FrenchDepartmentParserReadsTheReportAsValidRSTDoes');
   accepted := Run('5 123', CW);
   CheckTrue(accepted, '"5 123" CW is accepted');
   CheckEquals(559, Integer(rx.RSTReceived), '"5 123" CW: the strength alone is 559 (was 514)');
   CheckEquals(123, Integer(rx.NumberReceived), '"5 123" CW: the serial');

   accepted := Run('599 123', Digital);
   CheckTrue(accepted, '"599 123" Digital is accepted (was refused)');
   CheckEquals(599, Integer(rx.RSTReceived), '"599 123" Digital: the report');

   accepted := Run('699 123', CW);
   CheckFalse(accepted, '"699 123" CW is refused');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), '"699 123" CW: the RS(T) untouched');
end;

(* THE CW ZONE-THEN-REPORT FORM ('14 599'). NY4I on issue 282: "If the
   operator entered an invalid code anywhere and we know it to be invalid, we
   should tell them." The report is checked as every other report is, and
   the refusal names it. *)
procedure TRSTWordReadingTests.Test_ZoneThenReportFormChecksTheReport;
var
   rx: ContestExchange;
   accepted: boolean;

   function Run(const aText: string): boolean;
   begin
      EnterMode(CW);
      try
         rx := Default(ContestExchange);
         rx.RSTReceived := SENTINEL_RST;
         rx.Zone := SENTINEL_ZONE;
         ExchangeErrorMessage := 'stale';
         Result := ProcessRSTAndZoneExchange(ShortString(aText), rx);
      finally
         LeaveMode;
         end;
   end;

begin
   BeginTest('Test_ZoneThenReportFormChecksTheReport');
   accepted := Run('14 699');
   CheckFalse(accepted, '"14 699" is refused (it stored a report of 699)');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), '"14 699": the RS(T) untouched');
   CheckEquals(SENTINEL_ZONE, Integer(rx.Zone), '"14 699": the zone untouched');
   CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
               '"14 699": the message names the report');

   accepted := Run('14 600');
   CheckFalse(accepted, '"14 600" is refused');

   accepted := Run('14 579');
   CheckTrue(accepted, '"14 579" is accepted');
   CheckEquals(579, Integer(rx.RSTReceived), '"14 579": the RS(T)');
   CheckEquals(14, Integer(rx.Zone), '"14 579": the zone');

   accepted := Run('14 100');
   CheckTrue(accepted, '"14 100" is accepted: ValidRST takes 100..599 on CW');
   CheckEquals(100, Integer(rx.RSTReceived), '"14 100": the RS(T)');

   (* A zone above forty is still the zone's refusal, report or not. *)
   accepted := Run('85 599');
   CheckFalse(accepted, '"85 599" is refused');
   CheckEquals(TC_IMPROPERZONENUMBER, ExchangeErrorMessage, '"85 599": the zone message');
end;

(* The licence-year parser reads the same words: its year-then-report form. *)
procedure TRSTWordReadingTests.Test_YearThenReportFormChecksTheReport;
var
   rx: ContestExchange;
   accepted: boolean;

   function Run(const aText: string; aKind: TReceivedYearKind): boolean;
   begin
      EnterMode(CW);
      try
         rx := Default(ContestExchange);
         rx.RSTReceived := SENTINEL_RST;
         ExchangeErrorMessage := 'stale';
         Result := ProcessRSTAndLicenceYearExchange(ShortString(aText), aKind, rx);
      finally
         LeaveMode;
         end;
   end;

begin
   BeginTest('Test_YearThenReportFormChecksTheReport');
   accepted := Run('87 699', rykTwoDigitYear);
   CheckFalse(accepted, '"87 699" is refused (it stored a report of 699)');
   CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
               '"87 699": the message names the report, not the year');

   accepted := Run('1987 699', rykFourDigitYear);
   CheckFalse(accepted, '"1987 699" is refused');
   CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
               '"1987 699": the message names the report');

   accepted := Run('87 579', rykTwoDigitYear);
   CheckTrue(accepted, '"87 579" is accepted');
   CheckEquals(579, Integer(rx.RSTReceived), '"87 579": the RS(T)');
end;

procedure TRSTWordReadingTests.RunAllTests;
begin
   Test_AgeParserReadsTheReportAsValidRSTDoes;
   Test_AgeParserRefusesWhatValidRSTRefuses;
   Test_FrenchDepartmentParserReadsTheReportAsValidRSTDoes;
   Test_ZoneThenReportFormChecksTheReport;
   Test_YearThenReportFormChecksTheReport;
end;

end.

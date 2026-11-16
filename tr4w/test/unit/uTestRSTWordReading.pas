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
      procedure Test_AgeParserRefusalWritesNothing;
      procedure Test_FrenchDepartmentParserRefusesEveryEntryToday;
      procedure Intended_FrenchDepartmentParserReadsTheReportAsValidRSTDoes;
      procedure Test_ZoneThenReportFormChecksTheReport;
      procedure Test_YearThenReportFormChecksTheReport;
      procedure Test_ContinentParserReadsTheReportAsValidRSTDoes;
      procedure Test_GridParsersReadTheReportAsValidRSTDoes;
      procedure Test_QTHParsersReadTheReportAsValidRSTDoes;
      procedure Test_POTAReadsTheReportAsValidRSTDoes;
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

(* THE LATE EXITS OF FORMS 3 AND 4 (review M7, 2026-11-16). Form 3 (age,
   call, number) wrote the age before it tested the call and the number, and
   form 4 (report, age, call, number) wrote the report and the age; an entry
   refused there left them in the QSO. 300 is no number the forms take
   (0..255), so each entry reaches the last exit with its earlier fields read.
   AgeRefused asserts both sentinels. *)
procedure TRSTWordReadingTests.Test_AgeParserRefusalWritesNothing;
begin
   BeginTest('Test_AgeParserRefusalWritesNothing');
   AgeRefused('45 W1AW 300', CW);
   AgeRefused('599 45 W1AW 300', CW);
end;

(* THE REF PARSER AS PRODUCTION RUNS IT (review M8, 2026-11-16). It reads
   ParserArray, and nothing in the engine fills ParserArray before it -- only
   the age parser calls ParseArray2 -- so in a REF session the array is empty
   and every typed entry is refused (issue 332, which needs NY4I's ruling on
   the exchange). This pins THAT, with ParserArray emptied the way a fresh
   session has it, and the report untouched. The empty array also reached
   paElements[paCount - 1] = paElements[-1], a read before the array; the
   parser now refuses an empty array without reading it.

   The behaviour issue 332 intends is Intended_FrenchDepartmentParserReads
   TheReportAsValidRSTDoes below. *)
procedure TRSTWordReadingTests.Test_FrenchDepartmentParserRefusesEveryEntryToday;
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
         rx.NumberReceived := SENTINEL_AGE;
         (* An empty entry zeroes ParserArray: what the parser meets in a
            REF session, where nothing calls ParseArray2. *)
         ParseArray2('');
         Result := ProcessRSTAndQSONumberOrFrenchDepartmentExchange(Str80(aText), rx);
      finally
         LeaveMode;
         end;
   end;

begin
   BeginTest('Test_FrenchDepartmentParserRefusesEveryEntryToday');
   accepted := Run('5 123', CW);
   CheckFalse(accepted, '"5 123" CW is refused today (issue 332)');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), '"5 123" CW: the RS(T) untouched');
   CheckEquals(SENTINEL_AGE, Integer(rx.NumberReceived), '"5 123" CW: the serial untouched');

   accepted := Run('599 123', CW);
   CheckFalse(accepted, '"599 123" CW is refused today (issue 332)');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), '"599 123" CW: the RS(T) untouched');

   accepted := Run('123', CW);
   CheckFalse(accepted, '"123" CW is refused today (issue 332)');
end;

(* NOT RUN -- the behaviour issue 332 intends, kept so the fix has its test
   waiting. The framework has no skip, so this is left out of RunAllTests on
   purpose; add it there when REF's parser reads its own words. It calls
   ParseArray2 itself, which production does not do: that call is exactly
   what issue 332 must move into the engine. A station that is not French:
   RS(T) and serial. *)
procedure TRSTWordReadingTests.Intended_FrenchDepartmentParserReadsTheReportAsValidRSTDoes;
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
   BeginTest('Intended_FrenchDepartmentParserReadsTheReportAsValidRSTDoes');
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
   (* EVERY REFUSAL LEAVES THE REPORT (review M7, 2026-11-16): the word
      reader wrote the default report before any check, and the year parser
      handed it the QSO itself, so a refused '87 699' left 599 behind. *)
   accepted := Run('87 699', rykTwoDigitYear);
   CheckFalse(accepted, '"87 699" is refused (it stored a report of 699)');
   CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
               '"87 699": the message names the report, not the year');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), '"87 699": the RS(T) untouched');

   accepted := Run('1987 699', rykFourDigitYear);
   CheckFalse(accepted, '"1987 699" is refused');
   CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
               '"1987 699": the message names the report');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), '"1987 699": the RS(T) untouched');

   (* Refused by the RANGE, after the words were read: the report was
      written by then. *)
   accepted := Run('599 1850', rykFourDigitYear);
   CheckFalse(accepted, '"599 1850" is refused: before 1900');
   CheckEquals(SExchangeImproperLicenseYear, ExchangeErrorMessage, '"599 1850": the year message');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), '"599 1850": the RS(T) untouched');

   accepted := Run('87 579', rykTwoDigitYear);
   CheckTrue(accepted, '"87 579" is accepted');
   CheckEquals(579, Integer(rx.RSTReceived), '"87 579": the RS(T)');
end;

(* REVIEW H7, 2026-11-16: THE INLINE REPORT READS ARE ReadRSTWord's. Five
   parsers read a lone strength through their own table, and two of them --
   the continent parser (CQMM, the South American WW) and the JA prefecture
   parser -- wrote 5 + n on Phone, so '5' was a report of 10 (D7 the same,
   LOGSTUFF.PAS 1491 and 3736). ValidRST, every other parser's reading, gives
   55. The continent parser refuses '5 NA' for a reason of its own (it reads
   the continent from the words BEFORE the one it is looking at -- D7 the
   same, reported), but it writes the report first, so the reading shows. *)
procedure TRSTWordReadingTests.Test_ContinentParserReadsTheReportAsValidRSTDoes;
var
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_ContinentParserReadsTheReportAsValidRSTDoes');
   EnterMode(Phone);
   try
      rx := Default(ContestExchange);
      accepted := ProcessRSTAndContinentExchange('NA NA 5', rx);
   finally
      LeaveMode;
      end;
   CheckTrue(accepted, '"NA NA 5" Phone is accepted');
   CheckEquals(55, Integer(rx.RSTReceived), '"NA NA 5" Phone: the strength alone is 55 (was 10)');

   (* A word in the report's place that is no report is refused, naming it
      (it was stored as read: 699). *)
   EnterMode(CW);
   try
      rx := Default(ContestExchange);
      ExchangeErrorMessage := 'stale';
      accepted := ProcessRSTAndContinentExchange('NA NA 699', rx);
   finally
      LeaveMode;
      end;
   CheckFalse(accepted, '"NA NA 699" CW is refused');
   CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
               '"NA NA 699": the message names the report');
end;

(* The grid parsers (the ARRL VHF contests, CQ VHF, Stew Perry; WWL; the
   UA4W Championship) read the report the same way: a word that is neither a
   grid nor a report is refused, and a report reads as ValidRST reads it. *)
procedure TRSTWordReadingTests.Test_GridParsersReadTheReportAsValidRSTDoes;
var
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_GridParsersReadTheReportAsValidRSTDoes');
   EnterMode(CW);
   try
      rx := Default(ContestExchange);
      ExchangeErrorMessage := 'stale';
      accepted := ProcessRSTAndOrGridSquareExchange('699 FN31', rx);
      CheckFalse(accepted, '"699 FN31" is refused (it stored a report of 699)');
      CheckEquals(SysUtils.Format(SExchangeNotAGridOrReport, ['699']), ExchangeErrorMessage,
                  '"699 FN31": the message names the word');

      rx := Default(ContestExchange);
      accepted := ProcessRSTAndOrGridSquareExchange('5 FN31', rx);
      CheckTrue(accepted, '"5 FN31" is accepted');
      CheckEquals(559, Integer(rx.RSTReceived), '"5 FN31": the strength alone is 559');

      rx := Default(ContestExchange);
      ExchangeErrorMessage := 'stale';
      accepted := ProcessRSTAndGridSquareOrRDAExchange('699 FN31', rx);
      CheckFalse(accepted, '"699 FN31" (grid or RDA) is refused');
      CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
                  '"699 FN31" (grid or RDA): the message names the report');
   finally
      LeaveMode;
      end;
end;

(* The name-and-QTH parser and the plain RS(T)-and-QTH parser (the DX half of
   every state party's exchange) stored any number as the report. *)
procedure TRSTWordReadingTests.Test_QTHParsersReadTheReportAsValidRSTDoes;
var
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_QTHParsersReadTheReportAsValidRSTDoes');
   EnterMode(CW);
   try
      rx := Default(ContestExchange);
      rx.RSTReceived := SENTINEL_RST;
      ExchangeErrorMessage := 'stale';
      accepted := ProcessRSTAndQTHExchange('699 DL', rx);
      CheckFalse(accepted, '"699 DL" is refused (it stored a report of 699)');
      CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
                  '"699 DL": the message names the report');
      CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), '"699 DL": the RS(T) untouched');

      rx := Default(ContestExchange);
      accepted := ProcessRSTAndQTHExchange('DL 5', rx);
      CheckTrue(accepted, '"DL 5" is accepted');
      CheckEquals(559, Integer(rx.RSTReceived), '"DL 5": the strength alone is 559 (was 5)');
      CheckEquals('DL', string(rx.QTHString), '"DL 5": the QTH');

      rx := Default(ContestExchange);
      accepted := ProcessRSTAndQTHExchange('599', rx);
      CheckTrue(accepted, '"599" alone is accepted, as before');
      CheckEquals(599, Integer(rx.RSTReceived), '"599": the RS(T)');

      rx := Default(ContestExchange);
      ExchangeErrorMessage := 'stale';
      accepted := ProcessRSTNameAndQTHExchange('699 JOE', rx);
      CheckFalse(accepted, '"699 JOE" is refused');
      CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
                  '"699 JOE": the message names the report');

      rx := Default(ContestExchange);
      accepted := ProcessRSTNameAndQTHExchange('JOE CT 5', rx);
      CheckTrue(accepted, '"JOE CT 5" is accepted');
      CheckEquals(559, Integer(rx.RSTReceived), '"JOE CT 5": the strength alone is 559 (was 5)');
   finally
      LeaveMode;
      end;

   (* AN RST TYPED ON PHONE IS KEPT, AS D7 KEPT IT (coordinator's ruling,
      2026-11-16: no refusal D7 did not have): '599' is accepted and the
      Phone default, 59, is stored -- D7 stored 599 as typed. A three-digit
      word that is no report at all is still refused. *)
   EnterMode(Phone);
   try
      rx := Default(ContestExchange);
      accepted := ProcessRSTAndQTHExchange('599 DL', rx);
      CheckTrue(accepted, '"599 DL" Phone is accepted, as in D7');
      CheckEquals(59, Integer(rx.RSTReceived), '"599 DL" Phone: the Phone default report');

      rx := Default(ContestExchange);
      accepted := ProcessRSTAndContinentExchange('NA NA 599', rx);
      CheckTrue(accepted, '"NA NA 599" Phone is accepted');
      CheckEquals(59, Integer(rx.RSTReceived), '"NA NA 599" Phone: the Phone default report');

      rx := Default(ContestExchange);
      ExchangeErrorMessage := 'stale';
      accepted := ProcessRSTAndQTHExchange('699 DL', rx);
      CheckFalse(accepted, '"699 DL" Phone is refused: no report at all');
      CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']), ExchangeErrorMessage,
                  '"699 DL" Phone: the message names the report');
   finally
      LeaveMode;
      end;
end;

(* POTA IS FREE-FORM AND ALWAYS LOGS (its parser's own contract). A number
   that is a report is read as ValidRST reads it; a number that is NOT one
   ('699') is no longer stored as the report -- it is kept as a note, as any
   other word the parser does not know is. (Four digits or more are a park
   number to this parser, so the example has three.) *)
procedure TRSTWordReadingTests.Test_POTAReadsTheReportAsValidRSTDoes;
var
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_POTAReadsTheReportAsValidRSTDoes');
   EnterMode(CW);
   try
      rx := Default(ContestExchange);
      accepted := ProcessRSTAndPOTAPark('5 699', rx);
      CheckTrue(accepted, '"5 699" is accepted: POTA always logs');
      CheckEquals(559, Integer(rx.RSTSent), '"5 699": the strength alone is 559 (was 5)');
      CheckEquals(599, Integer(rx.RSTReceived), '"5 699": 699 is no report, so the default');
      CheckEquals('699', string(rx.ExchString), '"5 699": 699 is kept as a note');
   finally
      LeaveMode;
      end;
end;

procedure TRSTWordReadingTests.RunAllTests;
begin
   Test_AgeParserReadsTheReportAsValidRSTDoes;
   Test_AgeParserRefusesWhatValidRSTRefuses;
   Test_AgeParserRefusalWritesNothing;
   Test_FrenchDepartmentParserRefusesEveryEntryToday;
   (* Intended_FrenchDepartmentParserReadsTheReportAsValidRSTDoes is NOT run:
      issue 332. See its header. *)
   Test_ZoneThenReportFormChecksTheReport;
   Test_YearThenReportFormChecksTheReport;
   Test_ContinentParserReadsTheReportAsValidRSTDoes;
   Test_GridParsersReadTheReportAsValidRSTDoes;
   Test_QTHParsersReadTheReportAsValidRSTDoes;
   Test_POTAReadsTheReportAsValidRSTDoes;
end;

end.

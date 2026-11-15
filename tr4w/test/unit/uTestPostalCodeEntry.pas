unit uTestPostalCodeEntry;
{$I ..\..\src\tr4w.inc}

(* ISSUE 325: THE RSGB RoPoCo'S RS(T) IS BOUNDED, AND A REFUSAL WRITES NOTHING.

   LOGSTUFF.ProcessRSTAndPostalCodeExchange read the word in the RS(T)'s place
   with StrToIntDef and never checked it: '699 HA1 1TA' and '0 HA1 1TA' logged
   reports of 699 and 0, and a third word that was no number ('HA1 1TA CT') was
   silently the default report. The word is now LOGSTUFF.ReadRSTWord's -- one
   to three digits that ValidRST takes in the QSO's mode -- and a refusal says
   SExchangeNotASignalReport and leaves the QSO as it found it.

   Driven directly, with ActiveMode and the session's DefaultRST set and
   restored here; the QTH and the RS(T) are pre-set to sentinels, so
   "untouched" is visible. *)

interface

uses
   uTR4WTestFramework,
   VC;

type
   TPostalCodeEntryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      function Entry(const aText: string; aMode: ModeType;
                     out aRX: ContestExchange): boolean;
      procedure Accepted(const aText: string; aMode: ModeType;
                         const aExpectQTH: string; aExpectRST: integer);
      procedure Refused(const aText: string; aMode: ModeType;
                        const aBadWord: string);
      procedure Test_CWAcceptsAReportInEitherPlaceAndNone;
      procedure Test_CWBoundaries;
      procedure Test_CWRefusesAReportOutOfRange;
      procedure Test_PhoneAcceptsAnRSAndRefusesAnRST;
      procedure Test_ThirdWordThatIsNoReportIsRefused;
      procedure Test_EmptyEntryIsRefusedWithNoMessage;
   end;

implementation

uses
   SysUtils,
   uAppStrings,
   LogWind,
   LOGSTUFF;

const
   SENTINEL_QTH = 'SENTQ';
   SENTINEL_RST = 111;
   POSTCODE = 'HA1 1TA';

function TPostalCodeEntryTests.Entry(const aText: string; aMode: ModeType;
   out aRX: ContestExchange): boolean;
var
   savedMode: ModeType;
   savedDefault: Word;
begin
   savedMode := ActiveMode;
   savedDefault := DefaultRST;
   try
      ActiveMode := aMode;
      if aMode in [Phone, FM] then
         begin
         DefaultRST := 59;
         end
      else
         begin
         DefaultRST := 599;
         end;
      aRX := Default(ContestExchange);
      aRX.QTHString := SENTINEL_QTH;
      aRX.RSTReceived := SENTINEL_RST;
      ExchangeErrorMessage := 'stale';
      Result := ProcessRSTAndPostalCodeExchange(Str80(aText), aRX);
   finally
      ActiveMode := savedMode;
      DefaultRST := savedDefault;
      end;
end;

procedure TPostalCodeEntryTests.Accepted(const aText: string; aMode: ModeType;
   const aExpectQTH: string; aExpectRST: integer);
var
   rx: ContestExchange;
   what: string;
begin
   what := '"' + aText + '" mode ' + IntToStr(Ord(aMode));
   CheckTrue(Entry(aText, aMode, rx), what + ' is accepted');
   CheckEquals(aExpectQTH, string(rx.QTHString), what + ' QTH');
   CheckEquals(aExpectRST, Integer(rx.RSTReceived), what + ' RS(T)');
   CheckEquals('', ExchangeErrorMessage, what + ' message');
end;

procedure TPostalCodeEntryTests.Refused(const aText: string; aMode: ModeType;
   const aBadWord: string);
var
   rx: ContestExchange;
   what: string;
begin
   what := '"' + aText + '" mode ' + IntToStr(Ord(aMode));
   CheckFalse(Entry(aText, aMode, rx), what + ' is refused');
   CheckEquals(SENTINEL_QTH, string(rx.QTHString), what + ' QTH untouched');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), what + ' RS(T) untouched');
   CheckEquals(UnicodeFormat(SExchangeNotASignalReport, [aBadWord]),
               ExchangeErrorMessage, what + ' message');
end;

(* The three legal forms, and a postcode alone takes the default report. *)
procedure TPostalCodeEntryTests.Test_CWAcceptsAReportInEitherPlaceAndNone;
begin
   BeginTest('Test_CWAcceptsAReportInEitherPlaceAndNone');
   Accepted(POSTCODE, CW, POSTCODE, 599);
   Accepted('579 ' + POSTCODE, CW, POSTCODE, 579);
   Accepted(POSTCODE + ' 579', CW, POSTCODE, 579);
   Accepted('599 ' + POSTCODE, CW, POSTCODE, 599);
end;

(* ValidRST's ranges on CW, at their edges: the strength alone (1..9 is 519..599),
   100..599 as typed. 10..59 is taken WITHOUT being written -- ValidRST's own
   rule, shared with every parser that asks it -- so it is the default. *)
procedure TPostalCodeEntryTests.Test_CWBoundaries;
begin
   BeginTest('Test_CWBoundaries');
   Accepted('1 ' + POSTCODE, CW, POSTCODE, 519);
   Accepted('9 ' + POSTCODE, CW, POSTCODE, 599);
   Accepted('100 ' + POSTCODE, CW, POSTCODE, 100);
   Accepted('599 ' + POSTCODE, CW, POSTCODE, 599);
   Accepted(POSTCODE + ' 5', CW, POSTCODE, 559);
   Accepted('57 ' + POSTCODE, CW, POSTCODE, 599);
   Accepted('10 ' + POSTCODE, CW, POSTCODE, 599);
   Accepted('59 ' + POSTCODE, CW, POSTCODE, 599);
end;

procedure TPostalCodeEntryTests.Test_CWRefusesAReportOutOfRange;
begin
   BeginTest('Test_CWRefusesAReportOutOfRange');
   Refused('0 ' + POSTCODE, CW, '0');
   Refused('600 ' + POSTCODE, CW, '600');
   Refused('699 ' + POSTCODE, CW, '699');
   Refused('999 ' + POSTCODE, CW, '999');
   Refused('099 ' + POSTCODE, CW, '099');
   Refused('60 ' + POSTCODE, CW, '60');
   Refused('1000 ' + POSTCODE, CW, '1000');
   Refused(POSTCODE + ' 600', CW, '600');
   Refused(POSTCODE + ' 0', CW, '0');
end;

(* Phone takes an RS: 1..9 is 51..59, 10..59 as typed. A three-digit report is
   refused -- the zone parser's rule (issue 274: "Phone's report stays 59"). *)
procedure TPostalCodeEntryTests.Test_PhoneAcceptsAnRSAndRefusesAnRST;
begin
   BeginTest('Test_PhoneAcceptsAnRSAndRefusesAnRST');
   Accepted(POSTCODE, Phone, POSTCODE, 59);
   Accepted('59 ' + POSTCODE, Phone, POSTCODE, 59);
   Accepted('10 ' + POSTCODE, Phone, POSTCODE, 10);
   Accepted('5 ' + POSTCODE, Phone, POSTCODE, 55);
   Accepted(POSTCODE + ' 57', Phone, POSTCODE, 57);
   Refused('60 ' + POSTCODE, Phone, '60');
   Refused('599 ' + POSTCODE, Phone, '599');
   Refused('0 ' + POSTCODE, Phone, '0');
   Refused(POSTCODE + ' 599', Phone, '599');
end;

(* A third word after the postcode is in the RS(T)'s place: letters, a cut
   number and four or more digits are no report. Ten digits would overflow
   ValidRST's LeadingInt ('4294967895' wraps to 599) -- refused by its length
   before ValidRST sees it. *)
procedure TPostalCodeEntryTests.Test_ThirdWordThatIsNoReportIsRefused;
begin
   BeginTest('Test_ThirdWordThatIsNoReportIsRefused');
   Refused(POSTCODE + ' CT', CW, 'CT');
   Refused(POSTCODE + ' 5NN', CW, '5NN');
   Refused(POSTCODE + ' 57X', CW, '57X');
   Refused(POSTCODE + ' 1234', CW, '1234');
   Refused(POSTCODE + ' 4294967895', CW, '4294967895');
   Refused('JOE CT 1234', CW, '1234');
   Refused('CT 99 A 123', CW, 'A 123');
end;

(* Nothing typed is refused with no message, as it always was. *)
procedure TPostalCodeEntryTests.Test_EmptyEntryIsRefusedWithNoMessage;
var
   rx: ContestExchange;
begin
   BeginTest('Test_EmptyEntryIsRefusedWithNoMessage');
   CheckFalse(Entry('', CW, rx), 'empty is refused');
   CheckEquals(SENTINEL_QTH, string(rx.QTHString), 'empty: QTH untouched');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), 'empty: RS(T) untouched');
   CheckEquals('stale', ExchangeErrorMessage, 'empty: message not written');
end;

procedure TPostalCodeEntryTests.RunAllTests;
begin
   Test_CWAcceptsAReportInEitherPlaceAndNone;
   Test_CWBoundaries;
   Test_CWRefusesAReportOutOfRange;
   Test_PhoneAcceptsAnRSAndRefusesAnRST;
   Test_ThirdWordThatIsNoReportIsRefused;
   Test_EmptyEntryIsRefusedWithNoMessage;
end;

end.

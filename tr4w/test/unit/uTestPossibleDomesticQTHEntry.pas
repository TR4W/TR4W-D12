unit uTestPossibleDomesticQTHEntry;
{$I ..\..\src\tr4w.inc}

(* ISSUE 263: A WORD TYPED AHEAD OF THE NUMBER IS THE QTH ONLY WHEN THE
   CONTEST KNOWS IT.

   LOGSTUFF.ProcessRSTQSONumberAndPossibleDomesticQTHExchange's '<word>
   <number>' branch (n4af 4.42.7) set its answer from FoundDomesticQTH and
   then overwrote it with True (D7 did the same), so '5NN 12 EU5' in the RSGB
   IOTA logged QTH '5NN': no island, 2 points instead of 15, and the "Mult
   needs for" header named the call. The branch now accepts the word only when
   FoundDomesticQTH does, and otherwise refuses through RefuseDomesticQTH with
   its message, writing nothing -- the rule ProcessRSTZoneAndPossibleDomestic
   QTHExchange already keeps (issue 274).

   Driven directly, with a real contest active: the RSGB IOTA (its domestic
   QTH is a rule, the island reference, no file) and UK/EI (uk-ei.dom loaded
   from the shipped folder). QTH, domestic QTH, domestic multiplier and the
   number start as sentinels, so "untouched" is visible. The RS(T) is not
   asserted.

   ISSUE 282 (2026-11-12) WIDENS IT. NY4I: "If the operator entered an
   invalid code anywhere and we know it to be invalid, we should tell them."
   The same refusal -- a message, nothing written -- now holds for the
   standard order here, and for the two parsers of the same shape:
   ProcessRSTQSONumberAndDomesticQTHExchange (NRAU Baltic, Ohio QP) and
   ProcessQSONumberAndPossibleDomesticQTHExchange (CQIR). Entry drives
   whichever parser the section names (FParser). A dashed IOTA reference
   ('EU-005') is accepted (item 5). *)

interface

uses
   uTR4WTestFramework,
   VC;

type
   (* The shape every parser under test shares. *)
   TExchangeEntryParser = function(Exchange: Str80; var RXData: ContestExchange): boolean;

   TPossibleDomesticQTHEntryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      FParser: TExchangeEntryParser;
      (* The worked station's call: the Ten-Ten and FISTS parsers ask
         DomesticCountryCall of it. Empty for the others. *)
      FCallsign: string;
      function Entry(const aText: string; out aRX: ContestExchange): boolean;
      procedure Accepted(const aText: string; const aExpectQTH: string;
                         const aExpectDomMult: string; aExpectNumber: integer);
      procedure AcceptedWithRST(const aText: string; const aExpectQTH: string;
                                const aExpectDomMult: string; aExpectNumber: integer;
                                aExpectRST: integer);
      procedure Refused(const aText: string; const aExpectMessage: string);
      procedure Test_IOTAAcceptsAKnownReferenceWithAndWithoutTheRST;
      procedure Test_IOTARefusesAWordItDoesNotKnowAndWritesNothing;
      procedure Test_IOTAReadsTheRSTAndNumberAfterAReference;
      procedure Test_IOTAStandardOrderRefusesWithAMessageAndWritesNothing;
      procedure Test_UKEIAcceptsADistrictWithAndWithoutTheRST;
      procedure Test_UKEIRefusesAWordNotInItsFileAndWritesNothing;
      procedure Test_UKEIStandardOrderRefusesWithAMessageAndWritesNothing;
      procedure Test_IOTAAcceptsADashedReference;
      procedure Test_IOTADashedReferenceThroughProcessExchange;
      procedure Test_NRAURefusesAnUnlistedQTHWithAMessageAndWritesNothing;
      procedure Test_CQIRRefusesAnUnlistedCountyWithAMessageAndWritesNothing;
      procedure Test_JAPrefectureOneWordRefusesWithAMessageAndWritesNothing;
      procedure Test_JAPrefectureSeveralWordsReadsTheReportAsValidRSTDoes;
      procedure Test_TenTenRefusesADomesticEntryWithNoQTHAndWritesNothing;
      procedure Test_FISTSRefusesAnUnlistedQTHWithAMessageAndWritesNothing;
      procedure Test_FISTSReadsTheReportAsValidRSTDoes;
      procedure AllJAAccepted(const aText: string; const aExpectQTH: string;
                              const aExpectDomMult: string; aExpectPower: AnsiChar);
      procedure AllJARefused(const aText: string; const aExpectMessage: string);
      procedure Test_AllJAAcceptsEveryEntryShapeInEachMode;
      procedure Test_AllJARefusesWithAReasonAndWritesNothing;
      procedure Test_AllJAPrefectureRangeIsThePromptPattern;
      procedure Test_AllJAHokkaidoRegionsAreADIFHokkaido;
      procedure UseDomesticFile(const aFileName: string);
   end;

implementation

uses
   (* Settings -- MY COUNTRY and the domestic file's name, which
      RefuseDomesticQTH reads. *)
   uSettingsModel,
   SysUtils,
   Classes,
   uTR4WStrings,
   (* SExchangeNotASignalReport -- the report refusal (review H7). *)
   uAppStrings,
   (* ActiveMode, DefaultRST -- the session's mode and report. *)
   LogWind,
   (* DomesticCountries -- Ten-Ten and FISTS ask DomesticCountryCall. *)
   ZoneCont,
   uContestFactory,
   uContestRegistry,
   uTestContestObjects,
   LogDom,
   (* Contest -- the active contest's handle. *)
   PostUnit,
   (* ALLJA_PREFECTURE_PATTERN -- the prompt's prefecture list. *)
   uContestAllJA,
   (* RegexMatches -- the New Contest dialog's whole-value match. *)
   uRegex,
   LOGSTUFF;

const
   SENTINEL_QTH = 'SENTQ';
   SENTINEL_DOMESTIC_QTH = 'SENTD';
   SENTINEL_DOMESTIC_MULT = 'SENTM';
   SENTINEL_NUMBER = 7777;
   (* Not a signal report any parser would write, so "untouched" is visible
      (issue 282: a refused standard-order entry wrote its RS(T)). *)
   SENTINEL_RST = 111;

function TPossibleDomesticQTHEntryTests.Entry(const aText: string;
   out aRX: ContestExchange): boolean;
begin
   aRX := Default(ContestExchange);
   aRX.Callsign := CallString(FCallsign);
   aRX.QTHString := SENTINEL_QTH;
   aRX.DomesticQTH := SENTINEL_DOMESTIC_QTH;
   aRX.DomMultQTH := SENTINEL_DOMESTIC_MULT;
   aRX.NumberReceived := SENTINEL_NUMBER;
   aRX.RSTReceived := SENTINEL_RST;
   ExchangeErrorMessage := '';
   Result := FParser(Str80(aText), aRX);
end;

procedure TPossibleDomesticQTHEntryTests.Accepted(const aText: string;
   const aExpectQTH: string; const aExpectDomMult: string; aExpectNumber: integer);
var
   rx: ContestExchange;
   ok: boolean;
   what: string;
begin
   what := '"' + aText + '"';
   ok := Entry(aText, rx);
   CheckTrue(ok, what + ' is accepted: ' + string(ExchangeErrorMessage));
   CheckEquals('', string(ExchangeErrorMessage), what + ' no message');
   CheckEquals(aExpectQTH, string(rx.QTHString), what + ' QTH');
   CheckEquals(aExpectDomMult, UpperCase(string(rx.DomMultQTH)),
               what + ' domestic multiplier');
   CheckEquals(aExpectNumber, Integer(rx.NumberReceived), what + ' number');
end;

procedure TPossibleDomesticQTHEntryTests.Refused(const aText: string;
   const aExpectMessage: string);
var
   rx: ContestExchange;
   ok: boolean;
   what: string;
begin
   what := '"' + aText + '"';
   ok := Entry(aText, rx);
   CheckFalse(ok, what + ' is refused');
   CheckEquals(aExpectMessage, string(ExchangeErrorMessage), what + ' message');
   CheckEquals(SENTINEL_QTH, string(rx.QTHString), what + ' QTH untouched');
   CheckEquals(SENTINEL_DOMESTIC_QTH, string(rx.DomesticQTH),
               what + ' domestic QTH untouched');
   CheckEquals(SENTINEL_DOMESTIC_MULT, string(rx.DomMultQTH),
               what + ' domestic multiplier untouched');
   CheckEquals(SENTINEL_NUMBER, Integer(rx.NumberReceived),
               what + ' number untouched');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), what + ' RS(T) untouched');
end;

procedure TPossibleDomesticQTHEntryTests.AcceptedWithRST(const aText: string;
   const aExpectQTH: string; const aExpectDomMult: string; aExpectNumber: integer;
   aExpectRST: integer);
var
   rx: ContestExchange;
begin
   Accepted(aText, aExpectQTH, aExpectDomMult, aExpectNumber);
   Entry(aText, rx);
   CheckEquals(aExpectRST, Integer(rx.RSTReceived), '"' + aText + '" RS(T)');
end;

(* THE RSGB IOTA: the reference before the number (the branch this issue is
   about) and the forms the parser already took, with the RS(T) and without. *)
procedure TPossibleDomesticQTHEntryTests.Test_IOTAAcceptsAKnownReferenceWithAndWithoutTheRST;
begin
   BeginTest('Test_IOTAAcceptsAKnownReferenceWithAndWithoutTheRST');
   Accepted('EU5 12', 'EU5', 'EU-005', 12);
   Accepted('EU005 123', 'EU005', 'EU-005', 123);
   Accepted('599 12 EU5', 'EU5', 'EU-005', 12);
   Accepted('12 EU5', 'EU5', 'EU-005', 12);
end;

(* GM0GAV's shape: a cut RST ahead of the number. The word is not a
   reference, so the entry is refused, naming it, and the QSO keeps nothing
   of it. The reference is judged first, so a third word does not change the
   message. *)
procedure TPossibleDomesticQTHEntryTests.Test_IOTARefusesAWordItDoesNotKnowAndWritesNothing;
begin
   BeginTest('Test_IOTARefusesAWordItDoesNotKnowAndWritesNothing');
   Refused('5NN 12 EU5', TC_IMPROPERDOMESITCQTH + ' (5NN not known)');
   Refused('5NN 12', TC_IMPROPERDOMESITCQTH + ' (5NN not known)');
   Refused('XYZ 12', TC_IMPROPERDOMESITCQTH + ' (XYZ not known)');
   Refused('JOE 10 CT', TC_IMPROPERDOMESITCQTH + ' (JOE not known)');
end;

(* ISSUE 282 ITEM 1: 'QTH RS(T) QSO Number' is the documented third order,
   and the third word was ignored -- 'EU5 599 12' logged number 599. It is
   read now; a third word that is no number refuses the entry instead of
   being dropped (Q115), and writes nothing. *)
procedure TPossibleDomesticQTHEntryTests.Test_IOTAReadsTheRSTAndNumberAfterAReference;
begin
   BeginTest('Test_IOTAReadsTheRSTAndNumberAfterAReference');
   AcceptedWithRST('EU5 599 12', 'EU5', 'EU-005', 12, 599);
   AcceptedWithRST('EU005 579 123', 'EU005', 'EU-005', 123, 579);
   Refused('EU5 599 AB', TC_NOQSONUMBERFOUND);
   Refused('EU5 599 XYZ', TC_NOQSONUMBERFOUND);
   (* A third word of cut-number letters IS a number: LookForCutNumbers reads
      'EU6' as 526 (E=5, U=2), as it does in every order. *)
   AcceptedWithRST('EU5 599 EU6', 'EU5', 'EU-005', 526, 599);
end;

(* ISSUE 282 ITEM 2: the standard order, number first, refused an unknown
   reference with NO message and left the QTH, the RS(T) and the number it
   had read in the QSO. It now refuses as the word-first order does, through
   RefuseDomesticQTH, and writes nothing; a number it cannot read says so. *)
procedure TPossibleDomesticQTHEntryTests.Test_IOTAStandardOrderRefusesWithAMessageAndWritesNothing;
begin
   BeginTest('Test_IOTAStandardOrderRefusesWithAMessageAndWritesNothing');
   Refused('599 123 XYZ', TC_IMPROPERDOMESITCQTH + ' (XYZ not known)');
   Refused('123 XYZ', TC_IMPROPERDOMESITCQTH + ' (XYZ not known)');
   Refused('599 12A', TC_IMPROPERDOMESITCQTH + ' (12A not known)');
   Refused('599 XYZ 123', TC_IMPROPERDOMESITCQTH + ' (XYZ not known)');
   Refused('123 JOE CT', TC_NOQSONUMBERFOUND);
   (* What was accepted still is, the RS(T) included. *)
   AcceptedWithRST('599 123 EU5', 'EU5', 'EU-005', 123, 599);
   AcceptedWithRST('579 EU5 123', 'EU5', 'EU-005', 123, 579);
end;

procedure TPossibleDomesticQTHEntryTests.Test_UKEIAcceptsADistrictWithAndWithoutTheRST;
begin
   BeginTest('Test_UKEIAcceptsADistrictWithAndWithoutTheRST');
   Accepted('AB 12', 'AB', 'AB', 12);
   Accepted('LN 123', 'LN', 'LN', 123);
   Accepted('599 12 AB', 'AB', 'AB', 12);
   Accepted('12 AB', 'AB', 'AB', 12);
end;

procedure TPossibleDomesticQTHEntryTests.Test_UKEIRefusesAWordNotInItsFileAndWritesNothing;
begin
   BeginTest('Test_UKEIRefusesAWordNotInItsFileAndWritesNothing');
   Refused('ZZZ 12', TC_IMPROPERDOMESITCQTH + ' (ZZZ not in uk-ei.dom)');
   Refused('5NN 12 AB', TC_IMPROPERDOMESITCQTH + ' (5NN not in uk-ei.dom)');
   Refused('JOE 123', TC_IMPROPERDOMESITCQTH + ' (JOE not in uk-ei.dom)');
end;

(* ISSUE 282, items 1 and 2, with a domestic FILE rather than a rule. *)
procedure TPossibleDomesticQTHEntryTests.Test_UKEIStandardOrderRefusesWithAMessageAndWritesNothing;
begin
   BeginTest('Test_UKEIStandardOrderRefusesWithAMessageAndWritesNothing');
   Refused('599 123 ZZZ', TC_IMPROPERDOMESITCQTH + ' (ZZZ not in uk-ei.dom)');
   Refused('123 ZZZ', TC_IMPROPERDOMESITCQTH + ' (ZZZ not in uk-ei.dom)');
   AcceptedWithRST('AB 599 12', 'AB', 'AB', 12, 599);
   Refused('AB 599 CT', TC_NOQSONUMBERFOUND);
end;

(* ISSUE 282 ITEM 5: a reference is written 'EU-005' on the air. One dash
   straight after the continent is dropped before the reference is read; a
   dash anywhere else is still not a reference. *)
procedure TPossibleDomesticQTHEntryTests.Test_IOTAAcceptsADashedReference;
begin
   BeginTest('Test_IOTAAcceptsADashedReference');
   Accepted('599 123 EU-005', 'EU-005', 'EU-005', 123);
   Accepted('123 EU-5', 'EU-5', 'EU-005', 123);
   Accepted('EU-005 12', 'EU-005', 'EU-005', 12);
   AcceptedWithRST('OC-001 579 7', 'OC-001', 'OC-001', 7, 579);
   (* Unchanged: the undashed form. *)
   Accepted('599 123 EU005', 'EU005', 'EU-005', 123);
   Refused('599 123 E-U005', TC_IMPROPERDOMESITCQTH + ' (E-U005 not known)');
   Refused('599 123 EU-0050', TC_IMPROPERDOMESITCQTH + ' (EU-0050 not known)');
end;

(* The tokenising gate (ParseArray) and the class run first in real entry;
   the dash must survive them. *)
procedure TPossibleDomesticQTHEntryTests.Test_IOTADashedReferenceThroughProcessExchange;
var
   rx: ContestExchange;
   ok: boolean;
begin
   BeginTest('Test_IOTADashedReferenceThroughProcessExchange');
   rx := Default(ContestExchange);
   ExchangeErrorMessage := '';
   ok := ProcessExchange('599 123 EU-005', rx);
   CheckTrue(ok, 'ProcessExchange accepts 599 123 EU-005: ' + string(ExchangeErrorMessage));
   CheckEquals('EU-005', UpperCase(string(rx.DomMultQTH)), 'the island');
   CheckEquals(123, Integer(rx.NumberReceived), 'the number');
end;

(* ProcessRSTQSONumberAndDomesticQTHExchange -- NRAU Baltic (and Ohio). Its
   QTH is required: an unlisted one, and a missing one, were refused with no
   message and left the QTH, RS(T) and number written. *)
procedure TPossibleDomesticQTHEntryTests.Test_NRAURefusesAnUnlistedQTHWithAMessageAndWritesNothing;
begin
   BeginTest('Test_NRAURefusesAnUnlistedQTHWithAMessageAndWritesNothing');
   Refused('599 123 ZZZ', TC_IMPROPERDOMESITCQTH + ' (ZZZ not in nrau.dom)');
   Refused('123 ZZZ', TC_IMPROPERDOMESITCQTH + ' (ZZZ not in nrau.dom)');
   Refused('ZZZ 123', TC_IMPROPERDOMESITCQTH + ' (ZZZ not in nrau.dom)');
   Refused('599 ZZZ 123', TC_IMPROPERDOMESITCQTH + ' (ZZZ not in nrau.dom)');
   Refused('599 123', TC_IMPROPERDOMESITCQTH + ' (no QTH)');
   Refused('AA', TC_NOQSONUMBERFOUND);
   (* A listed code is accepted in every order, as before. *)
   AcceptedWithRST('599 123 AA', 'AA', 'AA', 123, 599);
   Accepted('123 AA', 'AA', 'AA', 123);
   Accepted('AA 123', 'AA', 'AA', 123);
   AcceptedWithRST('AA 579 123', 'AA', 'AA', 123, 579);
   AcceptedWithRST('579 AA 123', 'AA', 'AA', 123, 579);
end;

(* ProcessQSONumberAndPossibleDomesticQTHExchange -- CQIR. An unlisted
   county was refused with no message, the QTH left written. *)
procedure TPossibleDomesticQTHEntryTests.Test_CQIRRefusesAnUnlistedCountyWithAMessageAndWritesNothing;
begin
   BeginTest('Test_CQIRRefusesAnUnlistedCountyWithAMessageAndWritesNothing');
   Refused('123 ZZZ', TC_IMPROPERDOMESITCQTH + ' (ZZZ not in ireland.dom)');
   Refused('ZZZ 123', TC_IMPROPERDOMESITCQTH + ' (ZZZ not in ireland.dom)');
   (* No number word is still refused WITHOUT a message: this reading leaves
      an RS(T)-led entry with no number word, so "no number" would misname
      it. Open on issue 282's audit. *)
   Refused('599 123 COR', '');
   Accepted('123 COR', 'COR', 'COR', 123);
   Accepted('COR 123', 'COR', 'COR', 123);
end;

(* ISSUE 308: ProcessRSTAndJAPrefectureExchange's ONE-WORD form (JA Long
   Prefecture, jacg3.dom, whose class uses the file at every station) ended
   in a bare FoundDomesticQTH, so an unlisted prefecture was refused
   with no message and its QTH and RS(T) left written. It goes through
   DomesticQTHFoundOrRefused on a copy now. Called directly: its exchange is a
   ShortString, not the Str80 FParser takes. The several-word form is still
   silent (open on issue 308). *)
procedure TPossibleDomesticQTHEntryTests.Test_JAPrefectureOneWordRefusesWithAMessageAndWritesNothing;
var
   rx: ContestExchange;
   ok: boolean;
begin
   BeginTest('Test_JAPrefectureOneWordRefusesWithAMessageAndWritesNothing');

   rx := Default(ContestExchange);
   rx.QTHString := SENTINEL_QTH;
   rx.DomesticQTH := SENTINEL_DOMESTIC_QTH;
   rx.DomMultQTH := SENTINEL_DOMESTIC_MULT;
   rx.RSTReceived := SENTINEL_RST;
   ExchangeErrorMessage := '';
   ok := ProcessRSTAndJAPrefectureExchange('ZZ', rx);
   CheckFalse(ok, '"ZZ" is refused');
   CheckEquals(TC_IMPROPERDOMESITCQTH + ' (ZZ not in jacg3.dom)',
               string(ExchangeErrorMessage), '"ZZ" message');
   CheckEquals(SENTINEL_QTH, string(rx.QTHString), '"ZZ" QTH untouched');
   CheckEquals(SENTINEL_DOMESTIC_QTH, string(rx.DomesticQTH), '"ZZ" domestic QTH untouched');
   CheckEquals(SENTINEL_DOMESTIC_MULT, string(rx.DomMultQTH), '"ZZ" domestic multiplier untouched');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), '"ZZ" RS(T) untouched');

   rx := Default(ContestExchange);
   ExchangeErrorMessage := '';
   ok := ProcessRSTAndJAPrefectureExchange('1001', rx);
   CheckTrue(ok, '"1001" is accepted: ' + string(ExchangeErrorMessage));
   CheckEquals('', string(ExchangeErrorMessage), '"1001" no message');
   CheckEquals('1001', string(rx.QTHString), '"1001" QTH');
   CheckEquals('1001', UpperCase(string(rx.DomMultQTH)), '"1001" domestic multiplier');
end;

(* REVIEW H7, 2026-11-16: the several-word form read a lone strength as
   5 + n on Phone, so '5' was a report of 10 (D7 the same, LOGSTUFF.PAS
   3736); it is ReadRSTWord's reading now, 55, as every other parser's. A
   word in the report's place that is no report is refused, naming it. This
   form still writes as it goes (open on issue 308), so only the report and
   the answer are asserted. *)
procedure TPossibleDomesticQTHEntryTests.Test_JAPrefectureSeveralWordsReadsTheReportAsValidRSTDoes;
var
   rx: ContestExchange;
   ok: boolean;
   savedMode: ModeType;
   savedDefault: Word;
begin
   BeginTest('Test_JAPrefectureSeveralWordsReadsTheReportAsValidRSTDoes');
   savedMode := ActiveMode;
   savedDefault := DefaultRST;
   try
      ActiveMode := Phone;
      DefaultRST := 59;
      rx := Default(ContestExchange);
      ExchangeErrorMessage := '';
      ok := ProcessRSTAndJAPrefectureExchange('5 1001', rx);
      CheckTrue(ok, '"5 1001" Phone is accepted: ' + string(ExchangeErrorMessage));
      CheckEquals(55, Integer(rx.RSTReceived), '"5 1001" Phone: the strength alone is 55 (was 10)');

      ActiveMode := CW;
      DefaultRST := 599;
      rx := Default(ContestExchange);
      ok := ProcessRSTAndJAPrefectureExchange('5 1001', rx);
      CheckTrue(ok, '"5 1001" CW is accepted');
      CheckEquals(559, Integer(rx.RSTReceived), '"5 1001" CW: the strength alone is 559');

      rx := Default(ContestExchange);
      ExchangeErrorMessage := '';
      ok := ProcessRSTAndJAPrefectureExchange('699 1001', rx);
      CheckFalse(ok, '"699 1001" CW is refused (it stored a report of 699)');
      CheckEquals(UnicodeFormat(SExchangeNotASignalReport, ['699']),
                  string(ExchangeErrorMessage), '"699 1001": the message names the report');
   finally
      ActiveMode := savedMode;
      DefaultRST := savedDefault;
      end;
end;

(* ISSUE 308: ProcessNameQTHAndPossibleTenTenNumberExchange (Ten-Ten) parses
   on a copy and refuses a DOMESTIC station's entry through
   DomesticQTHFoundOrRefused. Ten-Ten has no domestic file, so any QTH is
   known; what is refused is an entry with none. The refusal is the proof
   that the domestic path ran: a DX call takes any entry. *)
procedure TPossibleDomesticQTHEntryTests.Test_TenTenRefusesADomesticEntryWithNoQTHAndWritesNothing;
var
   rx: ContestExchange;
   ok: boolean;
begin
   BeginTest('Test_TenTenRefusesADomesticEntryWithNoQTHAndWritesNothing');
   FCallsign := 'W1AW';
   Refused('JOE 1234', TC_IMPROPERDOMESITCQTH + ' (no QTH)');
   Refused('1234', TC_IMPROPERDOMESITCQTH + ' (no QTH)');

   ok := Entry('JOE CT 1234', rx);
   CheckTrue(ok, '"JOE CT 1234" from W1AW is accepted: ' + string(ExchangeErrorMessage));
   CheckEquals('JOE', string(rx.Name), '"JOE CT 1234": the name');
   CheckEquals('CT', string(rx.QTHString), '"JOE CT 1234": the QTH');
   CheckEquals(1234, Integer(rx.TenTenNum), '"JOE CT 1234": the Ten-Ten number');

   FCallsign := 'DL1ABC';
   ok := Entry('HANS 1234', rx);
   CheckTrue(ok, '"HANS 1234" from DL1ABC is accepted: a DX entry needs no QTH');
   CheckEquals('HANS', string(rx.Name), '"HANS 1234": the name');
   CheckEquals(1234, Integer(rx.TenTenNum), '"HANS 1234": the Ten-Ten number');
   FCallsign := '';
end;

(* ISSUE 308: ProcessRSTQTHNameAndFistsNumberOrPowerExchange (FISTS,
   s49p8.dom) parses on a copy and refuses an unlisted QTH from a domestic
   station with its reason. A DX station's QTH is not looked up. *)
procedure TPossibleDomesticQTHEntryTests.Test_FISTSRefusesAnUnlistedQTHWithAMessageAndWritesNothing;
var
   rx: ContestExchange;
   ok: boolean;
begin
   BeginTest('Test_FISTSRefusesAnUnlistedQTHWithAMessageAndWritesNothing');
   FCallsign := 'W1AW';
   Refused('599 ZZ JOE 1234', TC_IMPROPERDOMESITCQTH + ' (ZZ not in s49p8.dom)');
   Refused('ZZ JOE 1234', TC_IMPROPERDOMESITCQTH + ' (ZZ not in s49p8.dom)');
   AcceptedWithRST('579 CT JOE 1234', 'CT', 'CT', 1234, 579);
   Accepted('CT JOE 1234', 'CT', 'CT', 1234);

   FCallsign := 'DL1ABC';
   ok := Entry('599 ZZ HANS 1234', rx);
   CheckTrue(ok, '"599 ZZ HANS 1234" from DL1ABC is accepted: a DX QTH is not looked up');
   CheckEquals('HANS', string(rx.Name), '"599 ZZ HANS 1234": the name');
   CheckEquals(1234, Integer(rx.NumberReceived), '"599 ZZ HANS 1234": the member number');
   FCallsign := '';
end;

(* REVIEW H7, 2026-11-16: the FISTS report was StrToIntDef of the first word,
   so '699' was stored and '5' was a report of 5. ReadRSTWord's reading now;
   a word it refuses is named and nothing is written. *)
procedure TPossibleDomesticQTHEntryTests.Test_FISTSReadsTheReportAsValidRSTDoes;
var
   savedMode: ModeType;
   savedDefault: Word;
begin
   BeginTest('Test_FISTSReadsTheReportAsValidRSTDoes');
   savedMode := ActiveMode;
   savedDefault := DefaultRST;
   FCallsign := 'W1AW';
   try
      ActiveMode := CW;
      DefaultRST := 599;
      Refused('699 CT JOE 1234', UnicodeFormat(SExchangeNotASignalReport, ['699']));
      AcceptedWithRST('5 CT JOE 1234', 'CT', 'CT', 1234, 559);
   finally
      ActiveMode := savedMode;
      DefaultRST := savedDefault;
      FCallsign := '';
      end;
end;

(* THE ALL JA (NY4I's bench, 2026-11-24): JA3WED on DIGI, 20 m, typed
   '101 H' and Enter did nothing, with no message -- and '02 H' and '102 H'
   the same. The parser wrote 'p' + the digits for every one-word prefecture,
   allja.dom keys on the bare number, so FoundDomesticQTH never found it.
   '599 12H' (two words, no 'p') worked. Called directly: the exchange is a
   ShortString, not the Str80 FParser takes. *)
procedure TPossibleDomesticQTHEntryTests.AllJAAccepted(const aText: string;
   const aExpectQTH: string; const aExpectDomMult: string; aExpectPower: AnsiChar);
var
   rx: ContestExchange;
   ok: boolean;
   what: string;
begin
   what := '"' + aText + '" (mode ' + IntToStr(Ord(ActiveMode)) + ')';
   rx := Default(ContestExchange);
   ExchangeErrorMessage := '';
   ok := ProcessRSTAllJAPrefectureAndPrecedenceExchange(ShortString(aText), rx);
   CheckTrue(ok, what + ' is accepted: ' + string(ExchangeErrorMessage));
   CheckEquals('', string(ExchangeErrorMessage), what + ' no message');
   CheckEquals(aExpectQTH, string(rx.QTHString), what + ' QTH: the bare number, no p');
   CheckEquals(aExpectDomMult, UpperCase(string(rx.DomMultQTH)),
               what + ' domestic multiplier');
   (* The power class is the Power field (rcvd_power) since 2026-11-24; the
      Sweepstakes precedence slot it rode in is left alone. *)
   CheckEquals(string(aExpectPower), string(rx.Power), what + ' power letter in Power');
   CheckTrue(rx.Precedence = #0, what + ' no power letter in Precedence');
end;

procedure TPossibleDomesticQTHEntryTests.AllJARefused(const aText: string;
   const aExpectMessage: string);
var
   rx: ContestExchange;
   ok: boolean;
   what: string;
begin
   what := '"' + aText + '" (mode ' + IntToStr(Ord(ActiveMode)) + ')';
   rx := Default(ContestExchange);
   rx.QTHString := SENTINEL_QTH;
   rx.DomesticQTH := SENTINEL_DOMESTIC_QTH;
   rx.DomMultQTH := SENTINEL_DOMESTIC_MULT;
   rx.RSTReceived := SENTINEL_RST;
   (* A power letter the RECORD already holds must not pass for one typed:
      the old final test, Precedence <> '', read the record (and was always
      True for an AnsiChar). Both slots are seeded: Power, where the letter
      is stored, and Precedence, where a log saved before 2026-11-24 has it. *)
   rx.Power := 'H';
   rx.Precedence := 'H';
   ExchangeErrorMessage := '';
   ok := ProcessRSTAllJAPrefectureAndPrecedenceExchange(ShortString(aText), rx);
   CheckFalse(ok, what + ' is refused');
   CheckEquals(aExpectMessage, string(ExchangeErrorMessage), what + ' message');
   CheckEquals(SENTINEL_QTH, string(rx.QTHString), what + ' QTH untouched');
   CheckEquals(SENTINEL_DOMESTIC_QTH, string(rx.DomesticQTH),
               what + ' domestic QTH untouched');
   CheckEquals(SENTINEL_DOMESTIC_MULT, string(rx.DomMultQTH),
               what + ' domestic multiplier untouched');
   CheckEquals(SENTINEL_RST, Integer(rx.RSTReceived), what + ' RS(T) untouched');
   CheckEquals('H', string(rx.Power), what + ' power letter untouched');
   CheckEquals('H', string(rx.Precedence), what + ' precedence untouched');
end;

(* Every shape in CW, Phone and Digital (the bench was DIGI, which takes the
   parser's non-CW branch). 102 is Rumoi, inside 101..114 and in the prompt's
   pattern, so '102 H' is ACCEPTED -- the bench report listed it as invalid,
   which the sponsor's list (as the pattern carries it) does not support. *)
procedure TPossibleDomesticQTHEntryTests.Test_AllJAAcceptsEveryEntryShapeInEachMode;
const
   MODES: array[0..2] of ModeType = (CW, Phone, Digital);
var
   savedMode: ModeType;
   savedDefault: Word;
   i: integer;
begin
   BeginTest('Test_AllJAAcceptsEveryEntryShapeInEachMode');
   savedMode := ActiveMode;
   savedDefault := DefaultRST;
   try
      for i := Low(MODES) to High(MODES) do
         begin
         ActiveMode := MODES[i];
         if ActiveMode = CW then
            begin
            DefaultRST := 599;
            end
         else
            begin
            DefaultRST := 59;
            end;
         AllJAAccepted('101 H', '101', '101', 'H');
         AllJAAccepted(' 101 H', '101', '101', 'H');
         AllJAAccepted('02 H', '02', '02', 'H');
         AllJAAccepted('12 H', '12', '12', 'H');
         AllJAAccepted('102 H', '102', '102', 'H');
         AllJAAccepted('599 12H', '12', '12', 'H');
         AllJAAccepted('599 101 H', '101', '101', 'H');
         AllJAAccepted('114 P', '114', '114', 'P');
         AllJAAccepted('48 L', '48', '48', 'L');
         AllJAAccepted('12M', '12', '12', 'M');
         end;
   finally
      ActiveMode := savedMode;
      DefaultRST := savedDefault;
      end;
end;

(* A missing power letter names the letters; a number outside 02..48 and
   101..114 (49, 50 and 115..118 are in allja.dom but not on the list) or no
   number at all names the range. Nothing is written. *)
procedure TPossibleDomesticQTHEntryTests.Test_AllJARefusesWithAReasonAndWritesNothing;
const
   MODES: array[0..2] of ModeType = (CW, Phone, Digital);
var
   savedMode: ModeType;
   savedDefault: Word;
   i: integer;
begin
   BeginTest('Test_AllJARefusesWithAReasonAndWritesNothing');
   savedMode := ActiveMode;
   savedDefault := DefaultRST;
   try
      for i := Low(MODES) to High(MODES) do
         begin
         ActiveMode := MODES[i];
         if ActiveMode = CW then
            begin
            DefaultRST := 599;
            end
         else
            begin
            DefaultRST := 59;
            end;
         AllJARefused('12', SExchangeAllJAPower);
         AllJARefused('599 12', SExchangeAllJAPower);
         AllJARefused('101', SExchangeAllJAPower);
         AllJARefused('49 H', SExchangeAllJAPrefecture);
         AllJARefused('50 H', SExchangeAllJAPrefecture);
         (* In CW '115' is no prefecture. In phone and digital a three-digit
            word is D7's shorthand -- one strength digit and a two-digit
            prefecture -- so '115 H' is accepted there as 1 and 15. *)
         if ActiveMode = CW then
            begin
            AllJARefused('115 H', SExchangeAllJAPrefecture);
            end;
         AllJARefused('01 H', SExchangeAllJAPrefecture);
         AllJARefused('H', SExchangeAllJAPrefecture);
         AllJARefused('599 H', SExchangeAllJAPrefecture);
         end;
   finally
      ActiveMode := savedMode;
      DefaultRST := savedDefault;
      end;
end;

(* ONE LIST: what we may receive is what the New Contest dialog lets us send
   (uContestAllJA.ALLJA_PREFECTURE_PATTERN). Every number 0..200, written as
   the dialog would take it (two digits at least). *)
procedure TPossibleDomesticQTHEntryTests.Test_AllJAPrefectureRangeIsThePromptPattern;
var
   n: integer;
   text: string;
begin
   BeginTest('Test_AllJAPrefectureRangeIsThePromptPattern');
   for n := 0 to 200 do
      begin
      text := Format('%.2d', [n]);
      CheckTrue(RegexMatches(ALLJA_PREFECTURE_PATTERN, text) =
                ValidAllJAPrefecture(Str20(text)),
                'prefecture ' + text + ': the parser and the prompt agree');
      end;
end;

(* ADIF HAS ONE HOKKAIDO ('01'); the ALL JA's regions 101..114 roll into it
   (NY4I, 2026-11-24). Every other number is its own code, unchanged. *)
procedure TPossibleDomesticQTHEntryTests.Test_AllJAHokkaidoRegionsAreADIFHokkaido;
var
   n: integer;
begin
   BeginTest('Test_AllJAHokkaidoRegionsAreADIFHokkaido');
   for n := 101 to 114 do
      begin
      CheckEquals('01', ADIFPrefectureCode(IntToStr(n)), 'region ' + IntToStr(n));
      end;
   CheckEquals('02', ADIFPrefectureCode('02'), 'Aomori');
   CheckEquals('12', ADIFPrefectureCode('12'), 'Chiba');
   CheckEquals('47', ADIFPrefectureCode('47'), 'Okinawa');
   CheckEquals('', ADIFPrefectureCode(''), 'nothing in, nothing out');
end;

procedure TPossibleDomesticQTHEntryTests.UseDomesticFile(const aFileName: string);
begin
   Settings.Contest.DomesticFilename := aFileName;
   DomQTHTable.Free;
   DomQTHTable := TDomQTHTable.Create;
   CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + aFileName),
             aFileName + ' loads');
end;

(* THE CONTEST AND ITS TABLE. FoundDomesticQTH asks the active contest
   whether it has a domestic multiplier and, for the IOTA, its reference
   rule; RefuseDomesticQTH names the file from the setting and reads MY
   COUNTRY. Everything is restored. *)
procedure TPossibleDomesticQTHEntryTests.RunAllTests;
var
   savedContest: TContestHandle;
   savedTable: TDomQTHTable;
   savedMyCountry: string;
   savedDomesticFilename: string;
   savedCountries: TStringList;
   i: integer;
begin
   savedContest := Contest;
   savedTable := DomQTHTable;
   savedMyCountry := Settings.My.Country;
   savedDomesticFilename := Settings.Contest.DomesticFilename;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;
   DomQTHTable := TDomQTHTable.Create;
   try
      Settings.My.DeriveCountry('G');

      FParser := ProcessRSTQSONumberAndPossibleDomesticQTHExchange;
      Settings.Contest.DomesticFilename := '';
      Contest := ContestHandleOf(IOTA);
      ReleaseActiveContest;
      Test_IOTAAcceptsAKnownReferenceWithAndWithoutTheRST;
      Test_IOTARefusesAWordItDoesNotKnowAndWritesNothing;
      Test_IOTAReadsTheRSTAndNumberAfterAReference;
      Test_IOTAStandardOrderRefusesWithAMessageAndWritesNothing;
      Test_IOTAAcceptsADashedReference;
      Test_IOTADashedReferenceThroughProcessExchange;

      UseDomesticFile('uk-ei.dom');
      Contest := ContestHandleOf(UKEI);
      ReleaseActiveContest;
      Test_UKEIAcceptsADistrictWithAndWithoutTheRST;
      Test_UKEIRefusesAWordNotInItsFileAndWritesNothing;
      Test_UKEIStandardOrderRefusesWithAMessageAndWritesNothing;

      FParser := ProcessRSTQSONumberAndDomesticQTHExchange;
      UseDomesticFile('nrau.dom');
      Contest := ContestHandleOf(NRAUBALTICCW);
      ReleaseActiveContest;
      Test_NRAURefusesAnUnlistedQTHWithAMessageAndWritesNothing;

      FParser := ProcessQSONumberAndPossibleDomesticQTHExchange;
      UseDomesticFile('ireland.dom');
      Contest := ContestHandleOf(CQIR);
      ReleaseActiveContest;
      Test_CQIRRefusesAnUnlistedCountyWithAMessageAndWritesNothing;

      UseDomesticFile('jacg3.dom');
      Contest := ContestHandleOf(JALONGPREFECT);
      ReleaseActiveContest;
      Test_JAPrefectureOneWordRefusesWithAMessageAndWritesNothing;
      Test_JAPrefectureSeveralWordsReadsTheReportAsValidRSTDoes;

      UseDomesticFile('allja.dom');
      Contest := ContestHandleOf(ALLJA);
      ReleaseActiveContest;
      Test_AllJAAcceptsEveryEntryShapeInEachMode;
      Test_AllJARefusesWithAReasonAndWritesNothing;
      Test_AllJAPrefectureRangeIsThePromptPattern;
      Test_AllJAHokkaidoRegionsAreADIFHokkaido;

      (* TEN-TEN AND FISTS ASK DomesticCountryCall: a K call is domestic, as
         FoundContest sets it up for both. The list is restored. *)
      DomesticCountries.Clear;
      DomesticCountries.Add('K');

      FParser := ProcessNameQTHAndPossibleTenTenNumberExchange;
      Settings.Contest.DomesticFilename := '';
      DomQTHTable.Free;
      DomQTHTable := TDomQTHTable.Create;
      Contest := ContestHandleOf(TENTEN);
      ReleaseActiveContest;
      Test_TenTenRefusesADomesticEntryWithNoQTHAndWritesNothing;

      FParser := ProcessRSTQTHNameAndFistsNumberOrPowerExchange;
      UseDomesticFile('s49p8.dom');
      Contest := ContestHandleOf(FISTS);
      ReleaseActiveContest;
      Test_FISTSRefusesAnUnlistedQTHWithAMessageAndWritesNothing;
      Test_FISTSReadsTheReportAsValidRSTDoes;
   finally
      DomesticCountries.Clear;
      for i := 0 to savedCountries.Count - 1 do
         begin
         DomesticCountries.Add(CallString(savedCountries[i]));
         end;
      savedCountries.Free;
      FCallsign := '';
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      Settings.Contest.DomesticFilename := savedDomesticFilename;
      Settings.My.DeriveCountry(savedMyCountry);
      ExchangeErrorMessage := '';
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

end.

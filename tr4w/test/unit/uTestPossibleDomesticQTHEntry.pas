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
      procedure UseDomesticFile(const aFileName: string);
   end;

implementation

uses
   (* Settings -- MY COUNTRY and the domestic file's name, which
      RefuseDomesticQTH reads. *)
   uSettingsModel,
   SysUtils,
   uTR4WStrings,
   uContestFactory,
   uContestRegistry,
   uTestContestObjects,
   LogDom,
   (* Contest -- the active contest's handle. *)
   PostUnit,
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
begin
   savedContest := Contest;
   savedTable := DomQTHTable;
   savedMyCountry := Settings.My.Country;
   savedDomesticFilename := Settings.Contest.DomesticFilename;
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
   finally
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

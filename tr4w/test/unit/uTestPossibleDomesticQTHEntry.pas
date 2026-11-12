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
   asserted. *)

interface

uses
   uTR4WTestFramework,
   VC;

type
   TPossibleDomesticQTHEntryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      function Entry(const aText: string; out aRX: ContestExchange): boolean;
      procedure Accepted(const aText: string; const aExpectQTH: string;
                         const aExpectDomMult: string; aExpectNumber: integer);
      procedure Refused(const aText: string; const aExpectMessage: string);
      procedure Test_IOTAAcceptsAKnownReferenceWithAndWithoutTheRST;
      procedure Test_IOTARefusesAWordItDoesNotKnowAndWritesNothing;
      procedure Test_UKEIAcceptsADistrictWithAndWithoutTheRST;
      procedure Test_UKEIRefusesAWordNotInItsFileAndWritesNothing;
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

function TPossibleDomesticQTHEntryTests.Entry(const aText: string;
   out aRX: ContestExchange): boolean;
begin
   aRX := Default(ContestExchange);
   aRX.QTHString := SENTINEL_QTH;
   aRX.DomesticQTH := SENTINEL_DOMESTIC_QTH;
   aRX.DomMultQTH := SENTINEL_DOMESTIC_MULT;
   aRX.NumberReceived := SENTINEL_NUMBER;
   ExchangeErrorMessage := '';
   Result := ProcessRSTQSONumberAndPossibleDomesticQTHExchange(Str80(aText), aRX);
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
   of it. The third word is not read by this branch (as in D7). *)
procedure TPossibleDomesticQTHEntryTests.Test_IOTARefusesAWordItDoesNotKnowAndWritesNothing;
begin
   BeginTest('Test_IOTARefusesAWordItDoesNotKnowAndWritesNothing');
   Refused('5NN 12 EU5', TC_IMPROPERDOMESITCQTH + ' (5NN not known)');
   Refused('5NN 12', TC_IMPROPERDOMESITCQTH + ' (5NN not known)');
   Refused('XYZ 12', TC_IMPROPERDOMESITCQTH + ' (XYZ not known)');
   Refused('JOE 10 CT', TC_IMPROPERDOMESITCQTH + ' (JOE not known)');
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

      Settings.Contest.DomesticFilename := '';
      Contest := ContestHandleOf(IOTA);
      ReleaseActiveContest;
      Test_IOTAAcceptsAKnownReferenceWithAndWithoutTheRST;
      Test_IOTARefusesAWordItDoesNotKnowAndWritesNothing;

      Settings.Contest.DomesticFilename := 'uk-ei.dom';
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'uk-ei.dom'),
                'uk-ei.dom loads');
      Contest := ContestHandleOf(UKEI);
      ReleaseActiveContest;
      Test_UKEIAcceptsADistrictWithAndWithoutTheRST;
      Test_UKEIRefusesAWordNotInItsFileAndWritesNothing;
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

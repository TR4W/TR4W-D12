unit uTestZoneEntryRefusal;
{$I ..\..\src\tr4w.inc}

(* ISSUE 267: A REFUSED RST-AND-ZONE ENTRY LEAVES THE ZONE AS IT FOUND IT.

   LOGSTUFF.ProcessRSTAndZoneExchange wrote RXData.Zone from the two digits
   typed and only then refused a CQ zone above 40, so a refused '599 85' still
   carried zone 85 (D7 did the same). The European HF Championship and KVP sent
   the year licensed through this parser, accepted only because FoundContest
   sets ITU zone mode for them; since 2026-11-11 the year has its own parser
   (uTestLicenceYearEntry), and the ITU-mode rows below pin only the zone
   parser.

   Driven directly, with the CTY zone mode and the active mode set and restored
   here: the zone is pre-set to a sentinel, so "untouched" is visible. RST is
   not asserted -- it is written before a refusal too, which is not this
   issue. *)

interface

uses
   uTR4WTestFramework,
   VC;

type
   TZoneEntryRefusalTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Entry(const aText: string; aMode: ModeType; aZoneMode: ZoneModeType;
                      aExpectAccepted: boolean; aExpectZone: integer);
      procedure Test_CQZoneModeRefusesAboveFortyAndKeepsTheZone;
      procedure Test_CQZoneModeAcceptsAZoneAndSetsIt;
      procedure Test_ITUZoneModeAcceptsAYearAndSetsIt;
      procedure Test_CQZoneModeRefusesEveryZoneAboveForty;
      procedure Test_CQZoneModeAcceptsOneToForty;
      procedure Test_ITUZoneModeAcceptsFiftyToFiftyNine;

      (* ISSUE 274 -- CQ WW RTTY's ProcessRSTZoneAndPossibleDomesticQTHExchange. *)
      procedure Accepted(const aText: string; aMode: ModeType; aZoneMode: ZoneModeType;
                         aExpectZone: integer; const aExpectQTH: string;
                         aExpectRST: integer);
      procedure Refused(const aText: string; aMode: ModeType; aZoneMode: ZoneModeType;
                        const aExpectMessage: string);
      function RTTYEntry(const aText: string; aMode: ModeType; aZoneMode: ZoneModeType;
                         out aRX: ContestExchange): boolean;
      procedure Test_RTTYAcceptsEveryFormWithAndWithoutTheRST;
      procedure Test_RTTYPhoneReportWithAQTHIsMissingTheZone;
      procedure Test_RTTYRefusalsNameTheirReasonAndLeaveTheExchangeAlone;
      procedure Test_RTTYCQZoneModeRefusesAboveForty;
      procedure Test_RTTYITUZoneModeIsNotLimited;
      procedure Test_RSTAndQTHContestTakesTheReportNotAZone;
      procedure RunRTTYTests;
   end;

implementation

uses
   (* Settings -- MY COUNTRY and the domestic file's name, which
      RefuseDomesticQTH reads. *)
   uSettingsModel,
   SysUtils,
   uCTYDAT,
   uTR4WStrings,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uTestContestObjects,
   LogDom,
   LogWind,
   (* Contest -- the active contest's handle. *)
   PostUnit,
   LOGSTUFF;

const
   SENTINEL_ZONE = 7;
   SENTINEL_QTH = 'SENTQ';
   SENTINEL_DOMESTIC_QTH = 'SENTD';
   SENTINEL_DOMESTIC_MULT = 'SENTM';

procedure TZoneEntryRefusalTests.Entry(const aText: string; aMode: ModeType;
   aZoneMode: ZoneModeType; aExpectAccepted: boolean; aExpectZone: integer);
var
   rx: ContestExchange;
   savedMode: ModeType;
   savedZoneMode: ZoneModeType;
   accepted: boolean;
   what: string;
begin
   what := '"' + aText + '" ' + IntToStr(Ord(aMode)) + '/' + IntToStr(Ord(aZoneMode));
   savedMode := ActiveMode;
   savedZoneMode := CTY.ctyZoneMode;
   try
      ActiveMode := aMode;
      CTY.ctyZoneMode := aZoneMode;
      rx := Default(ContestExchange);
      rx.Zone := SENTINEL_ZONE;
      accepted := ProcessRSTAndZoneExchange(ShortString(aText), rx);
      if aExpectAccepted then
         begin
         CheckTrue(accepted, what + ' is accepted');
         end
      else
         begin
         CheckFalse(accepted, what + ' is refused');
         end;
      CheckEquals(aExpectZone, Integer(rx.Zone), what + ' zone');
   finally
      ActiveMode := savedMode;
      CTY.ctyZoneMode := savedZoneMode;
      end;
end;

procedure TZoneEntryRefusalTests.Test_CQZoneModeRefusesAboveFortyAndKeepsTheZone;
begin
   BeginTest('Test_CQZoneModeRefusesAboveFortyAndKeepsTheZone');
   Entry('85', CW, CQZoneMode, False, SENTINEL_ZONE);
   Entry('599 85', CW, CQZoneMode, False, SENTINEL_ZONE);
   Entry('599 41', CW, CQZoneMode, False, SENTINEL_ZONE);
   Entry('59 85', Phone, CQZoneMode, False, SENTINEL_ZONE);
   Entry('59 41', Phone, CQZoneMode, False, SENTINEL_ZONE);
end;

(* THERE ARE 40 CQ ZONES (NY4I, issue 267, 2026-11-10): 41..99 is refused,
   50..59 included -- the check compared the first digit with '5' and let them
   through (D7 did the same). Bare, after a CW RST and after a Phone RS. *)
procedure TZoneEntryRefusalTests.Test_CQZoneModeRefusesEveryZoneAboveForty;
const
   ABOVE: array[0..6] of string = ('41', '45', '50', '55', '59', '60', '99');
var
   z: string;
begin
   BeginTest('Test_CQZoneModeRefusesEveryZoneAboveForty');
   for z in ABOVE do
      begin
      Entry(z, CW, CQZoneMode, False, SENTINEL_ZONE);
      Entry('599 ' + z, CW, CQZoneMode, False, SENTINEL_ZONE);
      Entry('59 ' + z, Phone, CQZoneMode, False, SENTINEL_ZONE);
      Entry(z, Phone, CQZoneMode, False, SENTINEL_ZONE);
      end;
end;

(* 01..40 is accepted in CQ mode, every one of them. *)
procedure TZoneEntryRefusalTests.Test_CQZoneModeAcceptsOneToForty;
var
   zone: integer;
   z: string;
begin
   BeginTest('Test_CQZoneModeAcceptsOneToForty');
   for zone := 1 to 40 do
      begin
      z := IntToStr(zone);
      if zone < 10 then
         begin
         z := '0' + z;
         end;
      Entry(z, CW, CQZoneMode, True, zone);
      Entry('599 ' + z, CW, CQZoneMode, True, zone);
      Entry('59 ' + z, Phone, CQZoneMode, True, zone);
      end;
end;

(* ITU zone mode is unchanged: 50..59 and 99 are accepted. *)
procedure TZoneEntryRefusalTests.Test_ITUZoneModeAcceptsFiftyToFiftyNine;
begin
   BeginTest('Test_ITUZoneModeAcceptsFiftyToFiftyNine');
   Entry('50', CW, ITUZoneMode, True, 50);
   Entry('599 55', CW, ITUZoneMode, True, 55);
   Entry('59 59', Phone, ITUZoneMode, True, 59);
   Entry('75', CW, ITUZoneMode, True, 75);
end;

procedure TZoneEntryRefusalTests.Test_CQZoneModeAcceptsAZoneAndSetsIt;
begin
   BeginTest('Test_CQZoneModeAcceptsAZoneAndSetsIt');
   Entry('40', CW, CQZoneMode, True, 40);
   Entry('599 05', CW, CQZoneMode, True, 5);
   Entry('5', CW, CQZoneMode, True, 5);
   Entry('59 14', Phone, CQZoneMode, True, 14);
end;

procedure TZoneEntryRefusalTests.Test_ITUZoneModeAcceptsAYearAndSetsIt;
begin
   BeginTest('Test_ITUZoneModeAcceptsAYearAndSetsIt');
   Entry('85', CW, ITUZoneMode, True, 85);
   Entry('599 85', CW, ITUZoneMode, True, 85);
   Entry('59 85', Phone, ITUZoneMode, True, 85);
   Entry('00', CW, ITUZoneMode, True, 0);
   Entry('599 99', CW, ITUZoneMode, True, 99);
end;

(* ------------------------------------------------------------------------ *)
(* ISSUE 274: CQ WW RTTY -- RS(T), ZONE AND A POSSIBLE DOMESTIC QTH.          *)
(*                                                                          *)
(* LOGSTUFF.ProcessRSTZoneAndPossibleDomesticQTHExchange, driven directly    *)
(* with a real contest active and its shipped s48p14dc.dom loaded           *)
(* (RunRTTYTests), so FoundDomesticQTH and RefuseDomesticQTH answer as on    *)
(* the air. NY4I's rulings (2026-11-11): a 599 in front is valid on CW and   *)
(* RTTY (Phone stays 59); whether a zone is needed is the CLASS's received   *)
(* exchange fields, so CQ WW RTTY (zone) refuses '59 CT' as missing its zone *)
(* and ARRL RTTY Roundup (no zone, same domestic file) takes it as the RS    *)
(* and the QTH; every refusal names its reason. Zone, QTH, domestic QTH and  *)
(* domestic multiplier start as sentinels, so "untouched" is visible.        *)
(* ------------------------------------------------------------------------ *)

function TZoneEntryRefusalTests.RTTYEntry(const aText: string; aMode: ModeType;
   aZoneMode: ZoneModeType; out aRX: ContestExchange): boolean;
var
   savedMode: ModeType;
   savedZoneMode: ZoneModeType;
begin
   savedMode := ActiveMode;
   savedZoneMode := CTY.ctyZoneMode;
   try
      ActiveMode := aMode;
      CTY.ctyZoneMode := aZoneMode;
      aRX := Default(ContestExchange);
      aRX.Zone := SENTINEL_ZONE;
      aRX.QTHString := SENTINEL_QTH;
      aRX.DomesticQTH := SENTINEL_DOMESTIC_QTH;
      aRX.DomMultQTH := SENTINEL_DOMESTIC_MULT;
      ExchangeErrorMessage := '';
      Result := ProcessRSTZoneAndPossibleDomesticQTHExchange(Str80(aText), aRX);
   finally
      ActiveMode := savedMode;
      CTY.ctyZoneMode := savedZoneMode;
      end;
end;

(* aExpectZone SENTINEL_ZONE: no zone given, the zone left alone. aExpectRST
   0: the default report, not asserted (DefaultRST is the session's). *)
procedure TZoneEntryRefusalTests.Accepted(const aText: string; aMode: ModeType;
   aZoneMode: ZoneModeType; aExpectZone: integer; const aExpectQTH: string;
   aExpectRST: integer);
var
   rx: ContestExchange;
   ok: boolean;
   what: string;
begin
   what := '"' + aText + '" mode ' + IntToStr(Ord(aMode)) + ' zm ' + IntToStr(Ord(aZoneMode));
   ok := RTTYEntry(aText, aMode, aZoneMode, rx);
   CheckTrue(ok, what + ' is accepted: ' + string(ExchangeErrorMessage));
   CheckEquals('', string(ExchangeErrorMessage), what + ' no message');
   CheckEquals(aExpectZone, Integer(rx.Zone), what + ' zone');
   CheckEquals(aExpectQTH, string(rx.QTHString), what + ' QTH');
   if aExpectQTH = '' then
      begin
      CheckEquals(SENTINEL_DOMESTIC_QTH, string(rx.DomesticQTH),
                  what + ' no QTH, so the domestic QTH is not asked');
      end
   else
      begin
      CheckEquals(aExpectQTH, UpperCase(string(rx.DomesticQTH)),
                  what + ' domestic QTH from the file');
      CheckEquals(aExpectQTH, UpperCase(string(rx.DomMultQTH)),
                  what + ' domestic multiplier from the file');
      end;
   if aExpectRST <> 0 then
      begin
      CheckEquals(aExpectRST, Integer(rx.RSTReceived), what + ' RS(T)');
      end;
end;

procedure TZoneEntryRefusalTests.Refused(const aText: string; aMode: ModeType;
   aZoneMode: ZoneModeType; const aExpectMessage: string);
var
   rx: ContestExchange;
   ok: boolean;
   what: string;
begin
   what := '"' + aText + '" mode ' + IntToStr(Ord(aMode)) + ' zm ' + IntToStr(Ord(aZoneMode));
   ok := RTTYEntry(aText, aMode, aZoneMode, rx);
   CheckFalse(ok, what + ' is refused');
   CheckEquals(aExpectMessage, string(ExchangeErrorMessage), what + ' message');
   CheckEquals(SENTINEL_ZONE, Integer(rx.Zone), what + ' zone untouched');
   CheckEquals(SENTINEL_QTH, string(rx.QTHString), what + ' QTH untouched');
   CheckEquals(SENTINEL_DOMESTIC_QTH, string(rx.DomesticQTH),
               what + ' domestic QTH untouched');
   CheckEquals(SENTINEL_DOMESTIC_MULT, string(rx.DomMultQTH),
               what + ' domestic multiplier untouched');
end;

(* CQ WW RTTY, CQ zone mode: every format, with the RS(T) in front and
   without it, on RTTY (Digital), CW and Phone. *)
procedure TZoneEntryRefusalTests.Test_RTTYAcceptsEveryFormWithAndWithoutTheRST;
begin
   BeginTest('Test_RTTYAcceptsEveryFormWithAndWithoutTheRST');
   (* Without an RS(T). *)
   Accepted('5', Digital, CQZoneMode, 5, '', 0);
   Accepted('5 CT', Digital, CQZoneMode, 5, 'CT', 0);
   Accepted('05 ON', Digital, CQZoneMode, 5, 'ON', 0);
   Accepted('4 GA', Digital, CQZoneMode, 4, 'GA', 0);
   Accepted('CT 5', Digital, CQZoneMode, 5, 'CT', 0);
   Accepted('ON 4', Digital, CQZoneMode, 4, 'ON', 0);
   Accepted('40 CT', Digital, CQZoneMode, 40, 'CT', 0);
   Accepted('5 CT', CW, CQZoneMode, 5, 'CT', 0);
   Accepted('CT 5', CW, CQZoneMode, 5, 'CT', 0);
   Accepted('5 GA', Phone, CQZoneMode, 5, 'GA', 0);
   (* Zone 14 and a QTH on Phone: 14 can be a zone, and the class needs one. *)
   Accepted('14 CT', Phone, CQZoneMode, 14, 'CT', 0);

   (* WITH A 599 IN FRONT -- RTTY and CW (NY4I: valid). *)
   Accepted('599 5', Digital, CQZoneMode, 5, '', 599);
   Accepted('599 14', Digital, CQZoneMode, 14, '', 599);
   Accepted('599 5 CT', Digital, CQZoneMode, 5, 'CT', 599);
   Accepted('599 4 GA', Digital, CQZoneMode, 4, 'GA', 599);
   Accepted('599 CT 14', Digital, CQZoneMode, 14, 'CT', 599);
   Accepted('579 5 ON', Digital, CQZoneMode, 5, 'ON', 579);
   Accepted('599 14', CW, CQZoneMode, 14, '', 599);
   Accepted('599 5 CT', CW, CQZoneMode, 5, 'CT', 599);
   Accepted('599 ON 4', CW, CQZoneMode, 4, 'ON', 599);

   (* AND A 59 IN FRONT ON PHONE. *)
   Accepted('59 5 CT', Phone, CQZoneMode, 5, 'CT', 59);
   Accepted('59 4 ON', Phone, CQZoneMode, 4, 'ON', 59);
   Accepted('59 14', Phone, CQZoneMode, 14, '', 59);
   Accepted('57 GA 5', Phone, CQZoneMode, 5, 'GA', 57);
end;

(* CQ WW RTTY STATES A ZONE, so a report and a QTH are refused as missing it
   -- 59 is no CQ zone, and a report-shaped word is read as the report. *)
procedure TZoneEntryRefusalTests.Test_RTTYPhoneReportWithAQTHIsMissingTheZone;
begin
   BeginTest('Test_RTTYPhoneReportWithAQTHIsMissingTheZone');
   Refused('59 CT', Phone, CQZoneMode, TC_NOTENOUGHINFOINEXCHANGE);
   Refused('59 ON', Phone, CQZoneMode, TC_NOTENOUGHINFOINEXCHANGE);
   Refused('57 GA', Phone, CQZoneMode, TC_NOTENOUGHINFOINEXCHANGE);
   Refused('599 CT', Digital, CQZoneMode, TC_NOTENOUGHINFOINEXCHANGE);
   Refused('599 ON', CW, CQZoneMode, TC_NOTENOUGHINFOINEXCHANGE);
   Refused('599', Digital, CQZoneMode, TC_NOTENOUGHINFOINEXCHANGE);
   Refused('CT', Digital, CQZoneMode, TC_NOTENOUGHINFOINEXCHANGE);
   (* ValidRST takes 100..599 on CW and RTTY, so '123' reads as a report
      and the zone is missing (a finding; ValidRST is shared). *)
   Refused('123 CT', Digital, CQZoneMode, TC_NOTENOUGHINFOINEXCHANGE);
   (* 45 is no CQ zone; on Phone it has a report's shape. *)
   Refused('45 CT', Phone, CQZoneMode, TC_NOTENOUGHINFOINEXCHANGE);
end;

(* Every refusal names its reason and leaves zone, QTH and domestic QTH alone. *)
procedure TZoneEntryRefusalTests.Test_RTTYRefusalsNameTheirReasonAndLeaveTheExchangeAlone;
var
   notInFile: string;
begin
   BeginTest('Test_RTTYRefusalsNameTheirReasonAndLeaveTheExchangeAlone');
   (* THE DOMESTIC FILE DOES NOT KNOW THE QTH -- LOGSTUFF.RefuseDomesticQTH,
      the one domestic-QTH refusal. *)
   notInFile := TC_IMPROPERDOMESITCQTH + ' (ZZZ not in s48p14dc.dom)';
   Refused('5 ZZZ', Digital, CQZoneMode, notInFile);
   Refused('ZZZ 5', Digital, CQZoneMode, notInFile);
   Refused('599 5 ZZZ', Digital, CQZoneMode, notInFile);
   Refused('59 5 ZZZ', Phone, CQZoneMode, notInFile);
   Refused('JOE 10', CW, CQZoneMode, TC_IMPROPERDOMESITCQTH + ' (JOE not in s48p14dc.dom)');

   (* A WORD IN THE ZONE'S PLACE THAT CANNOT BE A ZONE. *)
   Refused('599 123', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('599 001', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('599 12A', CW, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('5NN TT7', CW, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('5 12A', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('1234', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);

   (* MALFORMED: letters where the zone or the report goes, a report the
      mode does not take, a third word that is not a QTH. *)
   Refused('JOE CT', Digital, CQZoneMode, TC_INVALID);
   Refused('XYZ 5 CT', Digital, CQZoneMode, TC_INVALID);
   Refused('JOE 10 CT', CW, CQZoneMode, TC_INVALID);
   Refused('CT 5A', Digital, CQZoneMode, TC_INVALID);
   Refused('599 5 14', Digital, CQZoneMode, TC_INVALID);
   (* Phone's report stays two digits. *)
   Refused('599 14', Phone, CQZoneMode, TC_INVALID);
   Refused('599 5 CT', Phone, CQZoneMode, TC_INVALID);
end;

(* THERE ARE 40 CQ ZONES (NY4I, issue 267), here as in ProcessRSTAndZoneExchange. *)
procedure TZoneEntryRefusalTests.Test_RTTYCQZoneModeRefusesAboveForty;
begin
   BeginTest('Test_RTTYCQZoneModeRefusesAboveForty');
   Refused('41 CT', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('45 CT', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('CT 45', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('CT 123', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('45', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('99', CW, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('599 45', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('599 45 CT', CW, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('599 CT 45', Digital, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('59 45 CT', Phone, CQZoneMode, TC_IMPROPERZONENUMBER);
   Refused('59 45', Phone, CQZoneMode, TC_IMPROPERZONENUMBER);
end;

(* ITU zone mode is not limited, and 59 is an ITU zone: in a contest that
   needs a zone, '59 CT' on Phone is zone 59 there. *)
procedure TZoneEntryRefusalTests.Test_RTTYITUZoneModeIsNotLimited;
begin
   BeginTest('Test_RTTYITUZoneModeIsNotLimited');
   Accepted('45 CT', Digital, ITUZoneMode, 45, 'CT', 0);
   Accepted('CT 75', Digital, ITUZoneMode, 75, 'CT', 0);
   Accepted('59 CT', Digital, ITUZoneMode, 59, 'CT', 0);
   Accepted('99', Digital, ITUZoneMode, 99, '', 0);
   Accepted('599 75 CT', Digital, ITUZoneMode, 75, 'CT', 599);
   Accepted('59 45 CT', Phone, ITUZoneMode, 45, 'CT', 59);
   Accepted('59 CT', Phone, ITUZoneMode, 59, 'CT', 0);
end;

(* A CLASS THAT NEEDS NO ZONE -- ARRL RTTY Roundup's received fields are RST,
   number and QTH, on the same s48p14dc.dom. The parser asks the class, not the
   mode: '59 CT' is the report and the QTH, and the zone is left alone. Run
   under the Roundup by RunRTTYTests. *)
procedure TZoneEntryRefusalTests.Test_RSTAndQTHContestTakesTheReportNotAZone;
begin
   BeginTest('Test_RSTAndQTHContestTakesTheReportNotAZone');
   CheckFalse(ContestReceivedExchangeFields(ActiveContest(Contest)).Zone,
              'ARRL RTTY Roundup states no zone');
   Accepted('59 CT', Phone, CQZoneMode, SENTINEL_ZONE, 'CT', 59);
   Accepted('57 ON', Phone, CQZoneMode, SENTINEL_ZONE, 'ON', 57);
   Accepted('599 CT', Digital, CQZoneMode, SENTINEL_ZONE, 'CT', 599);
   Accepted('579 GA', CW, CQZoneMode, SENTINEL_ZONE, 'GA', 579);
   Accepted('CT', Digital, CQZoneMode, SENTINEL_ZONE, 'CT', 0);
   (* A zone may still be given. *)
   Accepted('5 CT', Digital, CQZoneMode, 5, 'CT', 0);
   Refused('59 ZZZ', Phone, CQZoneMode, TC_IMPROPERDOMESITCQTH + ' (ZZZ not in s48p14dc.dom)');
end;

(* THE CONTEST AND ITS TABLE: CQ WW RTTY, then ARRL RTTY Roundup, both on
   s48p14dc.dom. FoundDomesticQTH asks the active contest whether it has a
   domestic multiplier; RefuseDomesticQTH names the file from the setting and
   reads MY COUNTRY. Everything is restored. *)
procedure TZoneEntryRefusalTests.RunRTTYTests;
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
      Settings.My.DeriveCountry('K');
      Settings.Contest.DomesticFilename := 's48p14dc.dom';
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 's48p14dc.dom'),
                's48p14dc.dom loads');

      Contest := ContestHandleOf(CQWWRTTY);
      ReleaseActiveContest;
      CheckTrue(ContestReceivedExchangeFields(ActiveContest(Contest)).Zone,
                'CQ WW RTTY states a zone');
      Test_RTTYAcceptsEveryFormWithAndWithoutTheRST;
      Test_RTTYPhoneReportWithAQTHIsMissingTheZone;
      Test_RTTYRefusalsNameTheirReasonAndLeaveTheExchangeAlone;
      Test_RTTYCQZoneModeRefusesAboveForty;
      Test_RTTYITUZoneModeIsNotLimited;

      Contest := ContestHandleOf(ARRL_RTTY_ROUNDUP);
      ReleaseActiveContest;
      Test_RSTAndQTHContestTakesTheReportNotAZone;
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


procedure TZoneEntryRefusalTests.RunAllTests;
begin
   Test_CQZoneModeRefusesAboveFortyAndKeepsTheZone;
   Test_CQZoneModeAcceptsAZoneAndSetsIt;
   Test_ITUZoneModeAcceptsAYearAndSetsIt;
   Test_CQZoneModeRefusesEveryZoneAboveForty;
   Test_CQZoneModeAcceptsOneToForty;
   Test_ITUZoneModeAcceptsFiftyToFiftyNine;
   RunRTTYTests;
end;

end.

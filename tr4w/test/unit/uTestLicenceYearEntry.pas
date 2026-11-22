unit uTestLicenceYearEntry;
{$I ..\..\src\tr4w.inc}

(* THE LICENCE YEAR HAS ITS OWN PARSER -- 2026-11-11.

   The European HF Championship (docs/ContestRules/euhfc_rules_latest.md,
   rules 5 and 6) and KVP receive RS on SSB / RST on CW plus the two-digit year
   of the operator's first-ever licence, 00..99; the multipliers are the
   different two-digit values, once per band regardless of mode (EUHFC).

   Until today the year went through the ZONE parser and was accepted only
   because FoundContest sets ITU zone mode for these contests, so the 40-CQ-zone
   limit never ran. Now LOGSTUFF.ProcessRSTAndLicenceYearExchange reads the zone
   parser's words (one shared reader) with no zone rule. The year is STORED in
   its own field (RcvdYear, rcvd_year -- issue 298) through StoreLicenceYear,
   which since stage 4 (2026-11-22) no longer copies it into the zone slot;
   mo's numbered zone table counts it, keyed on the field
   (uContestBase.ContestZoneMultiplierKey). No export byte moves.

   What is pinned here: every year 00..99, bare and after the report, on CW and
   Phone; RS against RST; every refusal names a YEAR (SExchangeNoLicenseYear
   for nothing or a report alone, SExchangeImproperLicenseYear otherwise --
   never the zone parser's TC_IMPROPERZONENUMBER) and leaves the stored year
   alone; the SAME answers in CQ and ITU zone mode (the zone
   parser, in CQ mode, refuses the same years -- the contrast); both classes
   reach the year parser through the real engine (ProcessExchange) in CQ zone
   mode; the year counted once per band regardless of mode; the remaining-years
   list; and the export columns, byte for byte. *)

interface

uses
   uTR4WTestFramework,
   VC;

type
   TLicenceYearEntryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      function YearEntry(const aText: string; aMode: ModeType;
                         aZoneMode: ZoneModeType; out aRX: ContestExchange): boolean;
      procedure Accepted(const aText: string; aMode: ModeType; aZoneMode: ZoneModeType;
                         aExpectYear: integer; aExpectRST: integer);
      procedure Refused(const aText: string; aMode: ModeType; aZoneMode: ZoneModeType;
                        const aExpectMessage: string);
      procedure Test_EveryYearIsAcceptedBareAndAfterTheReport;
      procedure Test_TheReportIsRSOnPhoneAndRSTOnCW;
      procedure Test_RefusalsNameTheirReasonAndLeaveTheYear;
      procedure Test_TheYearDoesNotAskTheZoneMode;
      procedure Test_BothContestsParseTheYearThroughTheEngine;
      procedure Test_TheYearCountsOncePerBandRegardlessOfMode;
      procedure Test_ExportBytesAreUnchanged;
      procedure Test_TheSheetKeyIsTheYearFieldNotTheZoneSlot;
      procedure Test_StoredRecordsCountTheirYearOnLoadAndRescore;
   end;

implementation

uses
   (* Settings -- MULT BY BAND / MULT BY MODE, the sheet's scope. *)
   uSettingsModel,
   SysUtils,
   uCTYDAT,
   uCallsigns,
   uMults,
   uTR4WStrings,
   (* SExchangeNoLicenseYear, SExchangeImproperLicenseYear *)
   uAppStrings,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   LogDupe,
   LogWind,
   (* Contest -- the active contest's handle. *)
   PostUnit,
   LOGSTUFF;

const
   (* A year no entry below types, so "untouched" is visible. *)
   SENTINEL_YEAR = 7;

function TwoDigits(aValue: integer): string;
begin
   Result := IntToStr(aValue);
   if aValue < 10 then
      begin
      Result := '0' + Result;
      end;
end;

function TLicenceYearEntryTests.YearEntry(const aText: string; aMode: ModeType;
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
      StoreLicenceYear(aRX, SENTINEL_YEAR);
      ExchangeErrorMessage := '';
      (* The kind both contests state (issue 298, stage 2). *)
      Result := ProcessRSTAndLicenceYearExchange(ShortString(aText), rykTwoDigitYear, aRX);
   finally
      ActiveMode := savedMode;
      CTY.ctyZoneMode := savedZoneMode;
      end;
end;

(* aExpectRST 0: the default report, not asserted (DefaultRST is the
   session's). *)
procedure TLicenceYearEntryTests.Accepted(const aText: string; aMode: ModeType;
   aZoneMode: ZoneModeType; aExpectYear: integer; aExpectRST: integer);
var
   rx: ContestExchange;
   ok: boolean;
   what: string;
begin
   what := '"' + aText + '" mode ' + IntToStr(Ord(aMode)) + ' zm ' + IntToStr(Ord(aZoneMode));
   ok := YearEntry(aText, aMode, aZoneMode, rx);
   CheckTrue(ok, what + ' is accepted: ' + ExchangeErrorMessage);
   CheckEquals('', ExchangeErrorMessage, what + ' no message');
   CheckEquals(aExpectYear, LicenceYearOf(rx), what + ' year');
   if aExpectRST <> 0 then
      begin
      CheckEquals(aExpectRST, Integer(rx.RSTReceived), what + ' RS(T)');
      end;
end;

procedure TLicenceYearEntryTests.Refused(const aText: string; aMode: ModeType;
   aZoneMode: ZoneModeType; const aExpectMessage: string);
var
   rx: ContestExchange;
   ok: boolean;
   what: string;
begin
   what := '"' + aText + '" mode ' + IntToStr(Ord(aMode)) + ' zm ' + IntToStr(Ord(aZoneMode));
   ok := YearEntry(aText, aMode, aZoneMode, rx);
   CheckFalse(ok, what + ' is refused');
   CheckEquals(aExpectMessage, ExchangeErrorMessage, what + ' message');
   CheckEquals(SENTINEL_YEAR, LicenceYearOf(rx), what + ' year untouched');
end;

(* RULE 5: "59(9) 82 means that first ever official amateur radio license was
   issued in 1982, 17 means 2017". Every year 00..99, bare, after a CW RST,
   after a Phone RS, and before a CW RST; one digit too. Both zone modes. *)
procedure TLicenceYearEntryTests.Test_EveryYearIsAcceptedBareAndAfterTheReport;
var
   year: integer;
   zm: ZoneModeType;
   y: string;
begin
   BeginTest('Test_EveryYearIsAcceptedBareAndAfterTheReport');
   for zm := CQZoneMode to ITUZoneMode do
      begin
      for year := 0 to 99 do
         begin
         y := TwoDigits(year);
         Accepted(y, CW, zm, year, 0);
         Accepted(y, Phone, zm, year, 0);
         Accepted('599 ' + y, CW, zm, year, 599);
         Accepted('59 ' + y, Phone, zm, year, 59);
         Accepted(y + ' 579', CW, zm, year, 579);
         end;
      for year := 0 to 9 do
         begin
         Accepted(IntToStr(year), CW, zm, year, 0);
         Accepted('599 ' + IntToStr(year), CW, zm, year, 599);
         end;
      end;
end;

(* RULE 5: "SSB: RS report / CW: RST report". The report typed is the report
   kept; a short report expands as everywhere else (ValidRST). *)
procedure TLicenceYearEntryTests.Test_TheReportIsRSOnPhoneAndRSTOnCW;
begin
   BeginTest('Test_TheReportIsRSOnPhoneAndRSTOnCW');
   Accepted('599 82', CW, CQZoneMode, 82, 599);
   Accepted('579 82', CW, CQZoneMode, 82, 579);
   Accepted('82 559', CW, CQZoneMode, 82, 559);
   Accepted('59 17', Phone, CQZoneMode, 17, 59);
   Accepted('57 17', Phone, CQZoneMode, 17, 57);
   Accepted('5 82', CW, CQZoneMode, 82, 559);
   Accepted('5 82', Phone, CQZoneMode, 82, 55);
end;

(* NOT A YEAR, AND THE MESSAGE NAMES A YEAR, NEVER A ZONE (2026-11-11 -- a
   lone '599' said 'Improper zone number!!' in contests that have no zone).
   NO YEAR: nothing typed, or a report alone -- one word with the mode's RS(T)
   shape, which ValidRST takes ('599' and '123' on CW; on Phone a lone two
   digits is a year, so a three-digit word there is no report). IMPROPER: every
   other entry that is not one or two digits after an optional report --
   three or four digits after a report, a four-digit year, letters. The year is
   left as it was either way. *)
procedure TLicenceYearEntryTests.Test_RefusalsNameTheirReasonAndLeaveTheYear;
const
   IMPROPER_EVERYWHERE: array[0..7] of string = (
      '1982', '599 123', '599 1982', 'CT', '599 CT', '82A', '5NN 82', '699');
var
   zm: ZoneModeType;
   s: string;
begin
   BeginTest('Test_RefusalsNameTheirReasonAndLeaveTheYear');
   for zm := CQZoneMode to ITUZoneMode do
      begin
      Refused('', CW, zm, SExchangeNoLicenseYear);
      Refused('', Phone, zm, SExchangeNoLicenseYear);
      Refused('599', CW, zm, SExchangeNoLicenseYear);
      Refused('579', CW, zm, SExchangeNoLicenseYear);
      Refused('123', CW, zm, SExchangeNoLicenseYear);
      Refused('599', Digital, zm, SExchangeNoLicenseYear);
      Refused('599', Phone, zm, SExchangeImproperLicenseYear);
      Refused('123', Phone, zm, SExchangeImproperLicenseYear);
      for s in IMPROPER_EVERYWHERE do
         begin
         Refused(s, CW, zm, SExchangeImproperLicenseYear);
         Refused(s, Phone, zm, SExchangeImproperLicenseYear);
         end;
      end;
end;

(* THE POINT OF THE CHANGE: the same entries give the same answers whatever the
   CTY zone mode -- and the ZONE parser, in CQ zone mode, refuses the years
   above 40, which is what the year used to depend on not happening. *)
procedure TLicenceYearEntryTests.Test_TheYearDoesNotAskTheZoneMode;
const
   ENTRIES: array[0..9] of string = (
      '41', '599 50', '59 59', '85 579', '99', '00', '599 1982', 'CT', '123', '5');
var
   s: string;
   cqRX, ituRX, zoneRX: ContestExchange;
   cqOk, ituOk, zoneOk: boolean;
   cqMessage: string;
   savedMode: ModeType;
   savedZoneMode: ZoneModeType;
   year: integer;
begin
   BeginTest('Test_TheYearDoesNotAskTheZoneMode');
   for s in ENTRIES do
      begin
      cqOk := YearEntry(s, CW, CQZoneMode, cqRX);
      cqMessage := ExchangeErrorMessage;
      ituOk := YearEntry(s, CW, ITUZoneMode, ituRX);
      CheckTrue(ituOk = cqOk, '"' + s + '": accepted alike in CQ and ITU zone mode');
      CheckEquals(ExchangeErrorMessage, cqMessage, '"' + s + '": the same message');
      CheckEquals(LicenceYearOf(ituRX), LicenceYearOf(cqRX), '"' + s + '": the same year');
      CheckEquals(Integer(ituRX.RSTReceived), Integer(cqRX.RSTReceived),
                  '"' + s + '": the same report');
      end;

   (* The contrast: the zone parser in CQ zone mode refuses 41..99. *)
   savedMode := ActiveMode;
   savedZoneMode := CTY.ctyZoneMode;
   try
      ActiveMode := CW;
      CTY.ctyZoneMode := CQZoneMode;
      for year := 41 to 99 do
         begin
         zoneRX := Default(ContestExchange);
         zoneOk := ProcessRSTAndZoneExchange(ShortString('599 ' + IntToStr(year)), zoneRX);
         CheckFalse(zoneOk, 'the zone parser refuses CQ zone ' + IntToStr(year));
         end;
   finally
      ActiveMode := savedMode;
      CTY.ctyZoneMode := savedZoneMode;
      end;
   Accepted('599 85', CW, CQZoneMode, 85, 599);
end;

(* BOTH CLASSES REACH THE YEAR PARSER through the real engine --
   LOGSTUFF.ProcessExchange, the contest's ParseReceivedExchange, the engine's
   parsers -- in CQ zone mode, where the zone parser would refuse. *)
procedure TLicenceYearEntryTests.Test_BothContestsParseTheYearThroughTheEngine;
const
   YEAR_CONTESTS: array[0..1] of ContestType = (EUROPEANHFC, KVP);
var
   c: ContestType;
   rx: ContestExchange;
   ok: boolean;
   savedContest: TContestHandle;
   savedMode: ModeType;
   savedZoneMode: ZoneModeType;
   savedCallWindow: CallString;
   who: string;
begin
   BeginTest('Test_BothContestsParseTheYearThroughTheEngine');
   savedContest := Contest;
   savedMode := ActiveMode;
   savedZoneMode := CTY.ctyZoneMode;
   savedCallWindow := CallWindowString;
   try
      CTY.ctyZoneMode := CQZoneMode;
      CallWindowString := 'S50A';
      for c in YEAR_CONTESTS do
         begin
         who := string(ContestTypeSA[c]);
         Contest := ContestHandleOf(c);
         ReleaseActiveContest;

         ActiveMode := CW;
         rx := Default(ContestExchange);
         ExchangeErrorMessage := '';
         ok := ProcessExchange('599 85', rx);
         CheckTrue(ok, who + ': 599 85 is accepted in CQ zone mode: ' + ExchangeErrorMessage);
         CheckEquals(85, LicenceYearOf(rx), who + ': the year');
         CheckEquals(599, Integer(rx.RSTReceived), who + ': the RST');

         ActiveMode := Phone;
         rx := Default(ContestExchange);
         ok := ProcessExchange('59 99', rx);
         CheckTrue(ok, who + ': 59 99 is accepted: ' + ExchangeErrorMessage);
         CheckEquals(99, LicenceYearOf(rx), who + ': year 99');

         ActiveMode := CW;
         rx := Default(ContestExchange);
         StoreLicenceYear(rx, SENTINEL_YEAR);
         ExchangeErrorMessage := '';
         ok := ProcessExchange('599 1982', rx);
         CheckFalse(ok, who + ': a four-digit year is refused');
         CheckEquals(SExchangeImproperLicenseYear, ExchangeErrorMessage, who + ': its message');
         CheckEquals(SENTINEL_YEAR, LicenceYearOf(rx), who + ': the year untouched');

         (* THE SCREENSHOT'S CASE: the report alone. It said 'Improper zone
            number!!'. *)
         rx := Default(ContestExchange);
         StoreLicenceYear(rx, SENTINEL_YEAR);
         ExchangeErrorMessage := '';
         ok := ProcessExchange('599', rx);
         CheckFalse(ok, who + ': 599 alone is refused');
         CheckEquals(SExchangeNoLicenseYear, ExchangeErrorMessage, who + ': no year found');
         CheckEquals(SENTINEL_YEAR, LicenceYearOf(rx), who + ': 599 alone, the year untouched');

         (* ISSUE 274'S COMMENT: on Phone '599 00' was refused with an EMPTY
            message through this path. Phone takes a two-digit RS, so the
            refusal stands, and it names the year. *)
         ActiveMode := Phone;
         rx := Default(ContestExchange);
         StoreLicenceYear(rx, SENTINEL_YEAR);
         ExchangeErrorMessage := '';
         ok := ProcessExchange('599 00', rx);
         CheckFalse(ok, who + ': 599 00 on Phone is refused');
         CheckEquals(SExchangeImproperLicenseYear, ExchangeErrorMessage,
                     who + ': 599 00 on Phone names its reason');
         CheckEquals(SENTINEL_YEAR, LicenceYearOf(rx), who + ': 599 00 on Phone, the year untouched');
         end;
   finally
      Contest := savedContest;
      ReleaseActiveContest;
      ActiveMode := savedMode;
      CTY.ctyZoneMode := savedZoneMode;
      CallWindowString := savedCallWindow;
      ExchangeErrorMessage := '';
      end;
end;

(* RULE 6: "The multiplier is counted only once per band regardless of mode."
   The European HF Championship's scope as ApplyContestTraits writes it, the
   sheet's own answers, and the remaining-years list the window shows -- the
   year read in CQ zone mode, which it could not be before. *)
procedure TLicenceYearEntryTests.Test_TheYearCountsOncePerBandRegardlessOfMode;
var
   h: TContestHandle;
   savedContest: TContestHandle;
   savedMode: ModeType;
   savedZoneMode: ZoneModeType;
   savedByBand, savedByMode: boolean;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   contestRules: TContestBase;
   years: TArray<integer>;

   function Logged(const aCall: string; const aText: string; aBand: BandType;
                   aMode: ModeType): ContestExchange;
   begin
      Result := Default(ContestExchange);
      Result.Callsign := ShortString(aCall);
      Result.Band := aBand;
      Result.Mode := aMode;
      ActiveMode := aMode;
      CheckTrue(ProcessExchange(ShortString(aText), Result),
                aCall + ' ' + aText + ' is accepted: ' + ExchangeErrorMessage);
      Sheet.SetMultFlags(Result);
      Sheet.AddQSOToSheets(@Result, False);
   end;

   function Has(const aList: TArray<integer>; aValue: integer): boolean;
   var
      v: integer;
   begin
      Result := False;
      for v in aList do
         begin
         if v = aValue then
            begin
            Result := True;
            end;
         end;
   end;

var
   rx: ContestExchange;
begin
   BeginTest('Test_TheYearCountsOncePerBandRegardlessOfMode');
   h := ContestHandleOf(EUROPEANHFC);
   CheckTrue(ContestIdentity(h).MultByBand, 'EUHFC: multipliers by band');
   CheckFalse(ContestIdentity(h).MultByMode, 'EUHFC: not by mode -- "regardless of mode"');

   savedContest := Contest;
   savedMode := ActiveMode;
   savedZoneMode := CTY.ctyZoneMode;
   savedByBand := Settings.Mult.ByBand;
   savedByMode := Settings.Mult.ByMode;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      Contest := h;
      ReleaseActiveContest;
      CTY.ctyZoneMode := CQZoneMode;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      mo.ClearAllMults;

      rx := Logged('S50A', '599 85', Band20, CW);
      CheckTrue(rx.ZoneMult, '85 on 20 m CW: a new multiplier');
      rx := Logged('S51B', '59 85', Band20, Phone);
      CheckFalse(rx.ZoneMult, '85 on 20 m Phone: the same band, not new');
      rx := Logged('S52C', '599 85', Band40, CW);
      CheckTrue(rx.ZoneMult, '85 on 40 m: a new band, new');
      rx := Logged('S53D', '599 84', Band20, CW);
      CheckTrue(rx.ZoneMult, '84 on 20 m: a different year, new');
      rx := Logged('S54E', '59 00', Band20, Phone);
      CheckTrue(rx.ZoneMult, '00 on 20 m: year 00 is a multiplier');

      (* THE REMAINING-YEARS WINDOW, through the class's answers. *)
      contestRules := ActiveContest(Contest);
      years := mo.RemainingZoneIndices(ContestZoneMultiplierCount(contestRules),
                                       ContestNumbersZonesFromZero(contestRules), False,
                                       Band20, MultiplierSheetMode(Phone));
      CheckFalse(Has(years, 85), '85 is worked on 20 m: not remaining');
      CheckFalse(Has(years, 0), '00 is worked on 20 m: not remaining');
      CheckTrue(Has(years, 86), '86 is remaining');
      CheckTrue(Has(years, 99), '99 is remaining');
      CheckEquals(97, Length(years), 'a hundred years less 84, 85 and 00');
      years := mo.RemainingZoneIndices(ContestZoneMultiplierCount(contestRules),
                                       ContestNumbersZonesFromZero(contestRules), False,
                                       Band15, MultiplierSheetMode(CW));
      CheckTrue(Has(years, 85), '85 is still needed on 15 m');
   finally
      mo.ClearAllMults;
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      Settings.Mult.ByBand := savedByBand;
      Settings.Mult.ByMode := savedByMode;
      Contest := savedContest;
      ReleaseActiveContest;
      ActiveMode := savedMode;
      CTY.ctyZoneMode := savedZoneMode;
      ExchangeErrorMessage := '';
      end;
end;

(* THE EXPORT COLUMNS ARE THE ONES THE ZONE SLOT ALWAYS GAVE: Cabrillo's
   '%-3s %-7.2d' of the RST and the year received (and of MY ZONE sent), ADIF's
   STX_STRING '%-3d %-7.2d'. Literals, so a change of storage that moved a
   byte fails here. *)
procedure TLicenceYearEntryTests.Test_ExportBytesAreUnchanged;
const
   YEAR_CONTESTS: array[0..1] of ContestType = (EUROPEANHFC, KVP);
var
   c: ContestType;
   contestObject: TContestBase;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   rx: ContestExchange;
   who: string;
begin
   BeginTest('Test_ExportBytesAreUnchanged');
   for c in YEAR_CONTESTS do
      begin
      who := string(ContestTypeSA[c]);
      contestObject := ContestIdentity(ContestHandleOf(c));
      my := Default(TMyStationExchange);
      my.MyZone := '82';
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';

      CheckTrue(YearEntry('599 85', CW, CQZoneMode, rx), who + ': 599 85');
      rx.RSTSent := 599;
      CheckEquals('599 85     ', contestObject.FormatCabrilloReceivedExchange(my, rx, ctx),
                  who + ': Cabrillo received');
      CheckEquals('599 82     ', contestObject.FormatCabrilloSentExchange(my, rx, ctx),
                  who + ': Cabrillo sent');
      CheckEquals('599 82     ', contestObject.FormatADIFSentExchange(my, rx),
                  who + ': ADIF STX_STRING');

      CheckTrue(YearEntry('599 5', CW, CQZoneMode, rx), who + ': 599 5');
      CheckEquals('599 05     ', contestObject.FormatCabrilloReceivedExchange(my, rx, ctx),
                  who + ': Cabrillo received, one digit');
      CheckTrue(YearEntry('599 00', CW, CQZoneMode, rx), who + ': 599 00');
      CheckEquals('599 00     ', contestObject.FormatCabrilloReceivedExchange(my, rx, ctx),
                  who + ': Cabrillo received, year 00');
      end;
end;

(* ISSUE 298 STAGE 4 (2026-11-22): THE SHEET'S KEY IS THE YEAR FIELD.
   uContestBase.ContestZoneMultiplierKey is the one answer LOGDUPE's four
   sheet sites ask (credit, new?, mark, count). A year contest answers its
   received year -- never a value left in the zone slot -- and every other
   contest its zone slot, exactly as the sites read before. *)
procedure TLicenceYearEntryTests.Test_TheSheetKeyIsTheYearFieldNotTheZoneSlot;
var
   rx: ContestExchange;
   key: integer;
   c: ContestType;
   who: string;
const
   YEAR_CONTESTS: array[0..1] of ContestType = (EUROPEANHFC, KVP);
begin
   BeginTest('Test_TheSheetKeyIsTheYearFieldNotTheZoneSlot');
   for c in YEAR_CONTESTS do
      begin
      who := string(ContestTypeSA[c]) + ': ';

      rx := Default(ContestExchange);
      rx.Zone := 14;                       (* a value the slot happens to hold *)
      StoreLicenceYear(rx, 85);
      CheckEquals(14, integer(rx.Zone), who + 'StoreLicenceYear leaves the zone slot alone');
      CheckTrue(ContestZoneMultiplierKey(ContestIdentity(ContestHandleOf(c)), rx, key),
                who + 'a year is a key');
      CheckEquals(85, key, who + 'the key is the year, not the slot''s 14');

      StoreLicenceYear(rx, 0);
      CheckTrue(ContestZoneMultiplierKey(ContestIdentity(ContestHandleOf(c)), rx, key),
                who + 'year 00 is a key');
      CheckEquals(0, key, who + 'the cell 0');

      ClearLicenceYear(rx);
      CheckFalse(ContestZoneMultiplierKey(ContestIdentity(ContestHandleOf(c)), rx, key),
                 who + 'no year: no key');
      CheckEquals(DUMMYZONE, key, who + 'answered as DUMMYZONE');

      (* A RECORD FROM BEFORE THE FIELD -- a protocol-2 peer's, caught up from
         a server log: Known False and the year in the slot. TryLicenceYearOf's
         fallback still counts it. *)
      rx := Default(ContestExchange);
      rx.Zone := 33;
      CheckTrue(ContestZoneMultiplierKey(ContestIdentity(ContestHandleOf(c)), rx, key),
                who + 'a pre-field record''s year still keys');
      CheckEquals(33, key, who + 'from the slot, through the one fallback');

      (* A four-digit year is no cell of a hundred. *)
      rx := Default(ContestExchange);
      StoreLicenceYear(rx, 1985);
      CheckFalse(ContestZoneMultiplierKey(ContestIdentity(ContestHandleOf(c)), rx, key),
                 who + 'a year past the sheet is no key');
      end;

   (* A ZONE CONTEST: the zone slot, whatever the year field says. *)
   rx := Default(ContestExchange);
   rx.Zone := 14;
   rx.RcvdYear := 85;
   rx.RcvdYearKnown := True;
   CheckTrue(ContestZoneMultiplierKey(ContestIdentity(ContestHandleOf(CQWWCW)), rx, key),
             'CQ WW: its zone is a key');
   CheckEquals(14, key, 'CQ WW: the zone, never the year field');
   rx.Zone := DUMMYZONE;
   CheckFalse(ContestZoneMultiplierKey(ContestIdentity(ContestHandleOf(CQWWCW)), rx, key),
              'CQ WW: no zone, no key');
   rx.Zone := 14;
   CheckTrue(ContestZoneMultiplierKey(nil, rx, key), 'no contest: the zone slot');
   CheckEquals(14, key, 'no contest: 14');
end;

(* A STORED ROW OF A YEAR CONTEST -- rcvd_zone NULL (DUMMYZONE), rcvd_year
   set, as LOGDUPE sees it on a load or a rescore -- COUNTS ITS YEAR. The
   loader trusts the stored ZoneMult flag (#137) and marks the cell the key
   names; the rescore re-derives the flag (SetMultFlags) in log order. KVP
   counts per band AND mode (cfMultByBand, cfMultByMode), EUHFC per band
   regardless of mode (rule 6). The worked count (issue 12) follows the
   same key. *)
procedure TLicenceYearEntryTests.Test_StoredRecordsCountTheirYearOnLoadAndRescore;
var
   savedContest: TContestHandle;
   savedByBand, savedByMode: boolean;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   rx: ContestExchange;

   function Stored(const aCall: string; aYear: integer; aBand: BandType;
                   aMode: ModeType): ContestExchange;
   begin
      Result := Default(ContestExchange);
      Result.Callsign := ShortString(aCall);
      Result.Band := aBand;
      Result.Mode := aMode;
      Result.Zone := DUMMYZONE;          (* rcvd_zone NULL: no zone *)
      StoreLicenceYear(Result, aYear);
   end;

   (* THE RESCORE'S ORDER: the flag against the sheet so far, then the sheet. *)
   function Rescored(const aCall: string; aYear: integer; aBand: BandType;
                     aMode: ModeType): ContestExchange;
   begin
      Result := Stored(aCall, aYear, aBand, aMode);
      Sheet.SetMultFlags(Result);
      Sheet.AddQSOToSheets(@Result, False);
   end;

   procedure UseContest(aType: ContestType);
   var
      h: TContestHandle;
   begin
      h := ContestHandleOf(aType);
      Contest := h;
      ReleaseActiveContest;
      Settings.Mult.ByBand := ContestIdentity(h).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(h).MultByMode;
      mo.ClearAllMults;
   end;

begin
   BeginTest('Test_StoredRecordsCountTheirYearOnLoadAndRescore');
   CheckTrue(ContestIdentity(ContestHandleOf(KVP)).MultByMode, 'KVP: multipliers by mode');
   CheckTrue(ContestIdentity(ContestHandleOf(KVP)).MultByBand, 'KVP: and by band');

   savedContest := Contest;
   savedByBand := Settings.Mult.ByBand;
   savedByMode := Settings.Mult.ByMode;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      (* THE RESCORE, KVP: per band and mode. *)
      UseContest(KVP);
      rx := Rescored('S50A', 85, Band80, CW);
      CheckTrue(rx.ZoneMult, 'KVP 85 on 80 m CW: new');
      rx := Rescored('S51B', 85, Band80, Phone);
      CheckTrue(rx.ZoneMult, 'KVP 85 on 80 m Phone: new -- by mode');
      rx := Rescored('S52C', 85, Band80, CW);
      CheckFalse(rx.ZoneMult, 'KVP 85 on 80 m CW again: not new');
      rx := Rescored('S53D', 84, Band80, CW);
      CheckTrue(rx.ZoneMult, 'KVP 84 on 80 m CW: a different year, new');
      (* KVP is one band, 80 m (docs/ContestRules/KVP/rules.md, rule III);
         rule VI: "Vsak razlicen mnozitelj se uposteva posebej za vsako vrsto
         dela" -- each multiplier counts separately per mode, which is what
         is pinned. *)
      CheckEquals(2, Integer(mo.MTotals[Band80, CW, rmZone]), 'KVP: two years on 80 m CW');
      CheckEquals(1, Integer(mo.MTotals[Band80, Phone, rmZone]), 'KVP: one on 80 m Phone');
      CheckEquals(2, mo.WorkedCount(rmZone, '85', Band80, CW),
                  'KVP: 85 worked twice on 80 m CW (issue 12 count keys on the year)');
      CheckFalse(mo.IsZnMult(85, Band80, CW), 'the cell is the year''s, 85');

      (* THE LOAD, EUHFC: the stored flag is trusted, and marks the YEAR's
         cell -- the zone slot is DUMMYZONE and would mark nothing. *)
      UseContest(EUROPEANHFC);
      rx := Stored('S50A', 84, Band20, CW);
      rx.ZoneMult := True;
      Sheet.AddQSOToSheets(@rx, False);
      CheckFalse(mo.IsZnMult(84, Band20, MultiplierSheetMode(CW)),
                 'EUHFC load: the stored flag marked year 84 on 20 m');
      CheckEquals(1, Integer(mo.MTotals[Band20, CW, rmZone]), 'EUHFC load: one year counted');

      (* AND THE RESCORE AFTER IT AGREES: 84 on Phone, same band, is not new. *)
      rx := Rescored('S51B', 84, Band20, Phone);
      CheckFalse(rx.ZoneMult, 'EUHFC 84 on 20 m Phone after CW: not new (regardless of mode)');
      rx := Rescored('S52C', 83, Band20, Phone);
      CheckTrue(rx.ZoneMult, 'EUHFC 83: a different year, new');

      (* A QSO WITH NO YEAR EARNS NO YEAR MULTIPLIER, and the sheet is not
         touched at the zone slot. *)
      rx := Default(ContestExchange);
      rx.Callsign := 'S59Z';
      rx.Band := Band15;
      rx.Mode := CW;
      ClearLicenceYear(rx);
      Sheet.SetMultFlags(rx);
      CheckFalse(rx.ZoneMult, 'EUHFC: no year, no multiplier');
   finally
      mo.ClearAllMults;
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      Settings.Mult.ByBand := savedByBand;
      Settings.Mult.ByMode := savedByMode;
      Contest := savedContest;
      ReleaseActiveContest;
      end;
end;

procedure TLicenceYearEntryTests.RunAllTests;
begin
   Test_EveryYearIsAcceptedBareAndAfterTheReport;
   Test_TheReportIsRSOnPhoneAndRSTOnCW;
   Test_RefusalsNameTheirReasonAndLeaveTheYear;
   Test_TheYearDoesNotAskTheZoneMode;
   Test_BothContestsParseTheYearThroughTheEngine;
   Test_TheYearCountsOncePerBandRegardlessOfMode;
   Test_ExportBytesAreUnchanged;
   Test_TheSheetKeyIsTheYearFieldNotTheZoneSlot;
   Test_StoredRecordsCountTheirYearOnLoadAndRescore;
end;

end.

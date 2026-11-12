(* THE RECEIVED YEAR ON SCREEN AND IN EVERY EXPORT -- issue 298, STAGE 3
  (2026-11-12).

  Stage 2 moved the PARSER, Edit QSO's save and the ADIF import to the year's
  own field (ContestExchange.RcvdYear / RcvdYearKnown). Stage 3 moves the
  READERS that show or export it, so stage 4 can stop writing the zone slot:

    - the one text and number answers (uContestBase.ReceivedYearTextOf,
      TryReceivedZoneOrYear, RSTAndReceivedYearText), for every kind;
    - the Cabrillo received column (uCabrilloExchange.CabrilloReceivedRSTYear)
      -- byte for byte the zone helper's text for a two-digit year, four
      digits for a four-digit one;
    - the ADIF SRX_STRING and the canonical received exchange, from the field
      (an edited year was exported as the typed one before);
    - the log grid's cell (MainUnit.LogRowTextFor) and the UDP contact's
      <zone> (logsubs2.BuildUDPContact);
    - Edit QSO's zone box: label and length follow the contest, on the real
      form, built and never shown;
    - what a QSO records as my_cq_zone (uLogStore.LogStoreCurrentMyFacts):
      never the licence year a year contest keeps in MY ZONE.

  A REGISTRY WALK holds every other contest: the year field cannot reach the
  output of a contest that states no year kind.

  THE FOUR-DIGIT KIND HAS NO CONTEST, so it is reached through an
  UNREGISTERED probe class (TFourDigitYearProbe, created with NoContest, as
  uTestContestStateQSOPartyBase's probe is) -- never a shipped contest, and
  never the registered test fixture, whose kind the registry walks pin.

  THE MATRIX'S QSO BUILDER (uContestMatrix.BuildQSO) stores a year contest's
  year through StoreLicenceYear. uContestMatrix is not linked into this
  executable and its QSO table is private, so it is held by a SOURCE-TEXT pin
  (the technique uTestLogReceivedYear uses for uEditQSO); the contest matrix's
  EUROPEAN_HFC and KVP records are its behavioural pin. *)
unit uTestReceivedYearDisplay;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TReceivedYearDisplayTests = class(TTestCase)
   protected
      procedure Test_TheTextAndNumberFollowTheKind;
      procedure Test_TheCabrilloColumnIsTheField;
      procedure Test_SRXStringAndCanonicalReadTheField;
      procedure Test_TheGridCellAndUDPZoneReadTheField;
      procedure Test_NoOtherContestReadsTheYearField;
      procedure Test_EditQSOsZoneBoxFollowsTheContest;
      procedure Test_AYearContestRecordsMyCallsCQZone;
      procedure Test_TheMatrixBuilderStoresTheYear;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uAppStrings,         (* SLogColumnLicenseYear -- first, so every unit below wins a shared name *)
   SysUtils,
   Classes,             (* TStringList -- the source-text pin *)
   StrUtils,            (* ExtractWord *)
   VC,
   uSettingsModel,      (* Settings.My -- the stated MY ZONE and MY CALL *)
   uCTYDAT,             (* ctyGetCQZone -- the CQ zone CTY.DAT gives a call *)
   uQsoMyFacts,         (* TQsoMyFacts *)
   uLogStore,           (* LogStoreCurrentMyFacts *)
   MainUnit,            (* LogRowTextFor -- the log grid's row text *)
   logsubs2,            (* BuildUDPContact *)
   PostUnit,            (* Contest -- the session's contest *)
   uEditQSOForm,        (* TfrmEditQSO -- the real form *)
   uTestEngineEntry,    (* LoadCountryFile *)
   uTestRegisteredContests, (* IdentitiesToWalk, ContestWho, IsLegacyContest *)
   uContestEuropeanHFC, (* TContestEuropeanHFC -- the probe's parent *)
   uCabrilloExchange,   (* CabrilloReceivedRSTZone, CabrilloReceivedRSTYear *)
   uContestRegistry,    (* ContestIdentity, ContestHandleOf *)
   uContestBase;

type
   (* A FOUR-DIGIT YEAR CONTEST THAT DOES NOT EXIST: the European HF
      Championship's columns and parser, stating rykFourDigitYear. Never
      registered. *)
   TFourDigitYearProbe = class(TContestEuropeanHFC)
   protected
      function GetReceivedYearKind: TReceivedYearKind; override;
   end;

function TFourDigitYearProbe.GetReceivedYearKind: TReceivedYearKind;
begin
   Result := rykFourDigitYear;
end;

const
   (* A log grid position no real column uses, so the row's zone cell is
      read back from exactly one place. *)
   PROBE_COLUMN_POS = 250;

(* One QSO of aContest, with its zone slot holding aZone and no year. *)
function YearQSO(aContest: TContestHandle; aZone: integer): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := aContest;
   Result.Callsign := 'S50A';
   Result.Band := Band20;
   Result.Mode := CW;
   Result.ExtMode := eCW;
   Result.Frequency := 14025000;
   Result.tSysTime.qtYear := 26;
   Result.tSysTime.qtMonth := 7;
   Result.tSysTime.qtDay := 11;
   Result.tSysTime.qtHour := 12;
   Result.RSTSent := 599;
   Result.RSTReceived := 599;
   Result.NumberReceived := -1;
   Result.Zone := Byte(aZone);
end;

function CabrilloContext: TCabrilloQSOContext;
begin
   Result := Default(TCabrilloQSOContext);
   Result.RSTSent := '599';
   Result.RSTReceived := '599';
end;

(* The text of the log grid's zone cell for aQso, with the zone column on. *)
function GridZoneCell(const aQso: ContestExchange): string;
var
   saved: TLogColumnsInfo;
   row: TLogRowText;
begin
   saved := ColumnsArray[logColZoneMult];
   try
      ColumnsArray[logColZoneMult].Enable := True;
      ColumnsArray[logColZoneMult].pos := PROBE_COLUMN_POS;
      LogRowTextFor(aQso, row);
      Result := row[logColZoneMult];
   finally
      ColumnsArray[logColZoneMult] := saved;
   end;
end;

(* What the UDP contact's <zone> element holds for aQso. *)
function UDPZone(const aQso: ContestExchange): string;
var
   xml: string;
   first, last: integer;
begin
   xml := BuildUDPContact(aQso, udpContactInfo);
   first := Pos('<zone>', xml);
   last := Pos('</zone>', xml);
   if (first = 0) or (last < first) then
      begin
      Result := '<no zone element>';
      end
   else
      begin
      first := first + Length('<zone>');
      Result := Copy(xml, first, last - first);
      end;
end;

(* --------------------------------------------------------------------------- *)

procedure TReceivedYearDisplayTests.Test_TheTextAndNumberFollowTheKind;
var
   q: ContestExchange;
   v: integer;
begin
   BeginTest('Test_TheTextAndNumberFollowTheKind');
   q := YearQSO(NoContest, 14);

   StoreLicenceYear(q, 5);
   CheckEquals('05', ReceivedYearTextOf(rykTwoDigitYear, q), 'a two-digit year: two digits');
   CheckEquals('5', ReceivedYearTextOf(rykYearsLicensed, q), 'a count: the number');
   CheckEquals('', ReceivedYearTextOf(rykNone, q), 'no kind: no text');
   CheckTrue(TryReceivedZoneOrYear(rykTwoDigitYear, q, v), 'a year is a value');
   CheckEquals(5, v, 'the year');
   CheckEquals('599 05', RSTAndReceivedYearText('599', rykTwoDigitYear, q), 'the RST and the year');

   StoreLicenceYear(q, 0);
   CheckEquals('00', ReceivedYearTextOf(rykTwoDigitYear, q), '00 is a year (2000)');

   StoreLicenceYear(q, 1985);
   CheckEquals('1985', ReceivedYearTextOf(rykFourDigitYear, q), 'a four-digit year: four digits');
   CheckEquals(DUMMYZONE, q.Zone, 'and the zone slot cannot hold it');
   CheckTrue(TryReceivedZoneOrYear(rykFourDigitYear, q, v), 'the four-digit year is a value');
   CheckEquals(1985, v, 'from the field, not the slot');

   (* The zone slot holds a stale zone; the field is what is read. *)
   StoreLicenceYear(q, 23);
   q.Zone := 14;
   CheckEquals('23', ReceivedYearTextOf(rykTwoDigitYear, q), 'the field, not a stale slot');

   ClearLicenceYear(q);
   CheckEquals('', ReceivedYearTextOf(rykTwoDigitYear, q), 'no year: no text');
   CheckFalse(TryReceivedZoneOrYear(rykTwoDigitYear, q, v), 'no year: nothing to show');
   CheckEquals('599', RSTAndReceivedYearText('599', rykTwoDigitYear, q), 'no year: the RST alone');

   (* A record that never carried the field keeps what its zone slot held --
      the stage 2 fallback, unchanged. *)
   q := YearQSO(NoContest, 7);
   CheckEquals('07', ReceivedYearTextOf(rykTwoDigitYear, q), 'the slot, where no field was ever written');

   (* No kind: the zone, as before. *)
   q := YearQSO(NoContest, 14);
   CheckTrue(TryReceivedZoneOrYear(rykNone, q, v), 'a zone contest: its zone');
   CheckEquals(14, v, 'the zone');
   q.Zone := DUMMYZONE;
   CheckFalse(TryReceivedZoneOrYear(rykNone, q, v), 'no zone: nothing');
end;

(* THE RECEIVED CABRILLO COLUMN -- '%-3s %-7s' of the year text, which for a
   two-digit year is exactly the '%-3s %-7.2d' the zone helper printed. *)
procedure TReceivedYearDisplayTests.Test_TheCabrilloColumnIsTheField;
const
   YEAR_CONTESTS: array[0..1] of ContestType = (EUROPEANHFC, KVP);
   YEARS: array[0..4] of integer = (0, 5, 23, 85, 99);
var
   i, j: integer;
   rules: TContestBase;
   probe: TFourDigitYearProbe;
   q: ContestExchange;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   who, adif, failure: string;
begin
   BeginTest('Test_TheCabrilloColumnIsTheField');
   my := Default(TMyStationExchange);
   ctx := CabrilloContext;
   for i := Low(YEAR_CONTESTS) to High(YEAR_CONTESTS) do
      begin
      rules := ContestIdentity(YEAR_CONTESTS[i]);
      who := rules.DisplayName + ': ';
      for j := Low(YEARS) to High(YEARS) do
         begin
         q := YearQSO(ContestHandleOf(YEAR_CONTESTS[i]), 0);
         StoreLicenceYear(q, YEARS[j]);
         CheckEquals(CabrilloReceivedRSTZone(my, q, ctx),
                     rules.FormatCabrilloReceivedExchange(my, q, ctx),
                     who + IntToStr(YEARS[j]) + ' prints byte for byte what the zone helper printed');
         end;
      q := YearQSO(ContestHandleOf(YEAR_CONTESTS[i]), 0);
      StoreLicenceYear(q, 5);
      CheckEquals('599 05     ', rules.FormatCabrilloReceivedExchange(my, q, ctx), who + 'the literal column');

      (* An edited year: the slot is stale, the field is printed. *)
      q.Zone := 14;
      CheckEquals('599 05     ', rules.FormatCabrilloReceivedExchange(my, q, ctx),
                  who + 'the field, not a stale zone slot');

      (* A record that never carried the field (the matrix's sparse QSOs). *)
      q := YearQSO(ContestHandleOf(YEAR_CONTESTS[i]), 0);
      CheckEquals('599 00     ', rules.FormatCabrilloReceivedExchange(my, q, ctx),
                  who + 'a never-carried record prints its slot, as before');

      (* No year at all: blanks, where the slot printed DUMMYZONE's 255. *)
      ClearLicenceYear(q);
      CheckEquals('599        ', rules.FormatCabrilloReceivedExchange(my, q, ctx),
                  who + 'no year: an empty column, not 255');
      end;

   (* A FOUR-DIGIT YEAR, received and sent, in the same seven columns. *)
   probe := TFourDigitYearProbe.Create(NoContest);
   try
      q := YearQSO(NoContest, 0);
      StoreLicenceYear(q, 1985);
      CheckEquals('599 1985   ', probe.FormatCabrilloReceivedExchange(my, q, ctx),
                  'four digits received');
      my.MyZone := '1985';
      CheckEquals('599 1985   ', probe.FormatCabrilloSentExchange(my, q, ctx),
                  'four digits sent, from MY ZONE as stated');
      CheckTrue(probe.TryFormatADIFSentExchange(my, q, adif, failure), 'STX_STRING: ' + failure);
      CheckEquals('1985', ExtractWord(2, adif, [' ']), 'four digits in STX_STRING');
   finally
      probe.Free;
   end;
end;

(* THE ADIF SRX_STRING AND THE CANONICAL RECEIVED EXCHANGE are the RST and the
   year FROM THE FIELD. The typed text is stale after an Edit QSO change. *)
procedure TReceivedYearDisplayTests.Test_SRXStringAndCanonicalReadTheField;
var
   rules: TContestBase;
   probe: TFourDigitYearProbe;
   q, back: ContestExchange;
begin
   BeginTest('Test_SRXStringAndCanonicalReadTheField');
   rules := ContestIdentity(EUROPEANHFC);
   q := YearQSO(ContestHandleOf(EUROPEANHFC), 0);
   q.ExchString := '599 5';
   StoreLicenceYear(q, 5);
   CheckEquals('599 05', rules.FormatADIFReceivedExchange(q, True), 'the year, two digits');
   CheckEquals('05', rules.FormatADIFReceivedExchange(q, False), 'no RST in the exchange: the year');
   CheckEquals('599 05', rules.CanonicalReceivedExchange(q), 'the canonical exchange');

   (* EDIT QSO CHANGED THE YEAR: ExchString still says 5. *)
   StoreLicenceYear(q, 23);
   CheckEquals('599 23', rules.FormatADIFReceivedExchange(q, True), 'the edited year, not the typed one');
   CheckEquals('599 23', rules.CanonicalReceivedExchange(q), 'and in the canonical exchange');

   (* Phone: the RST received. *)
   q.Mode := Phone;
   q.RSTReceived := 59;
   CheckEquals('59 23', rules.FormatADIFReceivedExchange(q, True), 'on phone, RS');

   (* The import reads back what the export wrote. *)
   back := YearQSO(ContestHandleOf(EUROPEANHFC), DUMMYZONE);
   back.RSTReceived := 59;
   ApplyImportedReceivedYear(rykTwoDigitYear, rules.FormatADIFReceivedExchange(q, True), back);
   CheckEquals(23, LicenceYearOf(back), 'the round trip keeps the year');

   ClearLicenceYear(q);
   CheckEquals('59', rules.FormatADIFReceivedExchange(q, True), 'no year: the RST alone');

   probe := TFourDigitYearProbe.Create(NoContest);
   try
      q := YearQSO(NoContest, 0);
      StoreLicenceYear(q, 1985);
      CheckEquals('599 1985', probe.FormatADIFReceivedExchange(q, True), 'four digits in SRX_STRING');
      CheckEquals('599 1985', probe.CanonicalReceivedExchange(q), 'and in the canonical exchange');
   finally
      probe.Free;
   end;
end;

(* THE LOG GRID'S CELL AND THE UDP CONTACT'S <zone>, through the real
   routines: the year from its field. *)
procedure TReceivedYearDisplayTests.Test_TheGridCellAndUDPZoneReadTheField;
var
   q: ContestExchange;
begin
   BeginTest('Test_TheGridCellAndUDPZoneReadTheField');
   q := YearQSO(ContestHandleOf(EUROPEANHFC), 0);
   StoreLicenceYear(q, 5);
   CheckEquals('05', GridZoneCell(q), 'the grid shows the year as typed');
   CheckEquals('5', UDPZone(q), '<zone> carries the year as a number, as before');

   q.Zone := 14;   (* a stale slot *)
   CheckEquals('05', GridZoneCell(q), 'the grid reads the field');
   CheckEquals('5', UDPZone(q), '<zone> reads the field');

   ClearLicenceYear(q);
   CheckEquals('', GridZoneCell(q), 'no year: an empty cell');
   CheckEquals(IntToStr(DUMMYZONE), UDPZone(q), 'no year: what the slot holds, as this element always wrote');

   q := YearQSO(ContestHandleOf(KVP), 0);
   StoreLicenceYear(q, 85);
   CheckEquals('85', GridZoneCell(q), 'KVP: the year');
   CheckEquals('85', UDPZone(q), 'KVP: <zone> is the year');
end;

(* EVERY OTHER CONTEST IS UNTOUCHED -- a registry walk: for a contest that
   states no year kind, setting the year field changes NONE of its grid cell,
   UDP <zone>, Cabrillo received column, SRX_STRING or canonical exchange,
   and the grid and <zone> show the zone slot. Every contest that DOES state a
   kind shows the field instead of a stale slot. *)
procedure TReceivedYearDisplayTests.Test_NoOtherContestReadsTheYearField;

   function Outputs(aRules: TContestBase; const aQso: ContestExchange): string;
   var
      my: TMyStationExchange;
      ctx: TCabrilloQSOContext;
   begin
      my := Default(TMyStationExchange);
      ctx := CabrilloContext;
      Result := GridZoneCell(aQso) + '|' + UDPZone(aQso) + '|' +
                aRules.FormatCabrilloReceivedExchange(my, aQso, ctx) + '|' +
                aRules.FormatADIFReceivedExchange(aQso, True) + '|' +
                aRules.FormatADIFReceivedExchange(aQso, False) + '|' +
                aRules.CanonicalReceivedExchange(aQso);
   end;

var
   identities: TContestIdentityList;
   k: integer;
   rules: TContestBase;
   plain, withYear: ContestExchange;
   who: string;
begin
   BeginTest('Test_NoOtherContestReadsTheYearField');
   CheckTrue(ContestIdentity(EUROPEANHFC).ReceivedYearKind <> rykNone,
             'the walk reaches a year contest (not vacuous)');
   CheckTrue(ContestIdentity(KVP).ReceivedYearKind <> rykNone, 'and KVP');
   identities := IdentitiesToWalk;
   for k := 0 to High(identities) do
      begin
      rules := identities[k];
      who := ContestWho(rules) + ': ';
      plain := YearQSO(HandleOf(rules), 14);
      plain.ExchString := '599 14';
      plain.QTHString := 'CT';
      withYear := plain;
      if rules.ReceivedYearKind = rykNone then
         begin
         withYear.RcvdYear := 1985;
         withYear.RcvdYearKnown := True;
         CheckEquals(Outputs(rules, plain), Outputs(rules, withYear),
                     who + 'the year field reaches none of its output');
         CheckEquals('14', GridZoneCell(plain), who + 'the grid shows the zone');
         CheckEquals('14', UDPZone(plain), who + '<zone> is the zone');
         end
      else
         begin
         StoreLicenceYear(withYear, 23);
         withYear.Zone := 14;   (* stale *)
         CheckEquals('23', GridZoneCell(withYear), who + 'the grid shows the field');
         CheckEquals('23', UDPZone(withYear), who + '<zone> is the field');
         CheckEquals('599 23', rules.FormatADIFReceivedExchange(withYear, True),
                     who + 'SRX_STRING is the field');
         end;
      end;
end;

(* EDIT QSO'S ZONE BOX, ON THE REAL FORM -- built, never shown. Its label and
   length follow the QSO's contest, and come back for the next QSO: the form
   is created once and reused. *)
procedure TReceivedYearDisplayTests.Test_EditQSOsZoneBoxFollowsTheContest;
var
   form: TfrmEditQSO;
   probe: TFourDigitYearProbe;
   designedCaption: string;
   designedLength: integer;
begin
   BeginTest('Test_EditQSOsZoneBoxFollowsTheContest');
   form := TfrmEditQSO.Create(nil);
   probe := TFourDigitYearProbe.Create(NoContest);
   try
      designedCaption := form.lblZone.Caption;
      designedLength := form.edtZone.MaxLength;
      CheckEquals(2, designedLength, 'the .lfm''s zone box takes two digits');

      form.ShowZoneBoxFor(ContestIdentity(EUROPEANHFC));
      CheckEquals(SLogColumnLicenseYear, form.lblZone.Caption, 'EUHFC: labelled Year');
      CheckEquals(2, form.edtZone.MaxLength, 'EUHFC: two digits');

      form.ShowZoneBoxFor(probe);
      CheckEquals(SLogColumnLicenseYear, form.lblZone.Caption, 'four-digit: labelled Year');
      CheckEquals(4, form.edtZone.MaxLength, 'four-digit: four digits');

      form.ShowZoneBoxFor(ContestIdentity(CQWWCW));
      CheckEquals(designedCaption, form.lblZone.Caption, 'CQ WW: the designed label is back');
      CheckEquals(designedLength, form.edtZone.MaxLength, 'CQ WW: and the designed length');

      form.ShowZoneBoxFor(ContestIdentity(KVP));
      CheckEquals(SLogColumnLicenseYear, form.lblZone.Caption, 'KVP: labelled Year');

      form.ShowZoneBoxFor(nil);
      CheckEquals(designedCaption, form.lblZone.Caption, 'no contest: the designed label');
      CheckEquals(designedLength, form.edtZone.MaxLength, 'no contest: the designed length');
   finally
      probe.Free;
      form.Free;
   end;
end;

(* WHAT A QSO RECORDS AS my_cq_zone -- never the licence year (NY4I's EUHFC
   row recorded CQ zone 80). The year is MY LICENSE YEAR since issue 298 and
   MY ZONE is a CQ zone in every contest: a year contest records MY CALL's CQ
   zone from CTY.DAT, or a MY ZONE the operator stated, exactly as CQ WW
   does. *)
procedure TReceivedYearDisplayTests.Test_AYearContestRecordsMyCallsCQZone;
var
   savedContest: TContestHandle;
   savedCall, savedZone, savedYear: string;
   savedZoneStated, savedYearStated: boolean;
   facts: TQsoMyFacts;
   expected: integer;
begin
   BeginTest('Test_AYearContestRecordsMyCallsCQZone');
   CheckTrue(LoadCountryFile, 'the country file loads');
   savedContest := Contest;
   savedCall := Settings.My.Call;
   savedZoneStated := Settings.My.HasContestOverride(sfZone);
   savedZone := Settings.My.ContestOverride(sfZone);
   savedYearStated := Settings.My.HasContestOverride(sfLicenseYear);
   savedYear := Settings.My.ContestOverride(sfLicenseYear);
   try
      Settings.My.Call := 'S50A';
      expected := ctyGetCQZone('S50A');
      CheckTrue((expected >= 1) and (expected <= 40), 'S50A has a CQ zone');

      (* WITH NO MY ZONE STATED BY THE STATION OR THE CONTEST, the zone is MY
         CALL's. (An earlier test in this executable may have stated one on
         the global station, which then wins -- as it does in any contest --
         so this case is asked only while none is.) *)
      Settings.My.ClearContestOverride(sfZone);
      Contest := ContestHandleOf(EUROPEANHFC);
      Settings.My.SetContestOverride(sfLicenseYear, '1980');
      if not Settings.My.ZoneWasSet then
         begin
         facts := LogStoreCurrentMyFacts;
         CheckEquals(expected, facts.CQZone, 'EUHFC: MY CALL''s CQ zone, not the year 80');

         Settings.My.SetContestOverride(sfLicenseYear, '05');
         facts := LogStoreCurrentMyFacts;
         CheckEquals(expected, facts.CQZone, 'EUHFC: not the year 05 either');

         Contest := ContestHandleOf(KVP);
         facts := LogStoreCurrentMyFacts;
         CheckEquals(expected, facts.CQZone, 'KVP: MY CALL''s CQ zone');
         end;

      (* THE YEAR IS NEVER THE ZONE: a stated zone is the zone, whatever the
         year says. *)
      Contest := ContestHandleOf(EUROPEANHFC);
      Settings.My.SetContestOverride(sfLicenseYear, '1980');
      Settings.My.SetContestOverride(sfZone, '3');
      facts := LogStoreCurrentMyFacts;
      CheckEquals(3, facts.CQZone, 'EUHFC: the stated MY ZONE, not the year 80');

      Contest := ContestHandleOf(KVP);
      facts := LogStoreCurrentMyFacts;
      CheckEquals(3, facts.CQZone, 'KVP: a stated MY ZONE is the zone, as in any contest');

      Contest := ContestHandleOf(CQWWCW);
      Settings.My.SetContestOverride(sfZone, '5');
      facts := LogStoreCurrentMyFacts;
      CheckEquals(5, facts.CQZone, 'CQ WW: the stated MY ZONE, as before');
   finally
      Contest := savedContest;
      Settings.My.Call := savedCall;
      if savedZoneStated then
         begin
         Settings.My.SetContestOverride(sfZone, savedZone);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfZone);
         end;
      if savedYearStated then
         begin
         Settings.My.SetContestOverride(sfLicenseYear, savedYear);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfLicenseYear);
         end;
   end;
end;

(* THE MATRIX'S QSO BUILDER SETS THE YEAR THROUGH ITS ONE WRITER, for a
   contest that states a kind -- or every EUHFC/KVP record would export no
   year now that export reads the field. A source-text pin: see the header. *)
procedure TReceivedYearDisplayTests.Test_TheMatrixBuilderStoresTheYear;
var
   lines: TStringList;
   text: string;
   kindAt, storeAt: integer;
begin
   BeginTest('Test_TheMatrixBuilderStoresTheYear');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ExpandFileName(ExtractFilePath(ParamStr(0)) +
         '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim + 'uContestMatrix.pas')));
      text := lines.Text;
   finally
      lines.Free;
   end;
   kindAt := Pos('ContestIdentity(Contest).ReceivedYearKind <> rykNone', text);
   storeAt := Pos('StoreLicenceYear(aRX, aSpec.Zone)', text);
   CheckTrue(kindAt > 0, 'BuildQSO asks the contest''s year kind');
   CheckTrue(storeAt > kindAt, 'and stores the year through StoreLicenceYear under it');
   CheckTrue(Pos('Part(''year''', text) > 0, 'and the exchange dump shows the year field');
end;

procedure TReceivedYearDisplayTests.RunAllTests;
begin
   Test_TheTextAndNumberFollowTheKind;
   Test_TheCabrilloColumnIsTheField;
   Test_SRXStringAndCanonicalReadTheField;
   Test_TheGridCellAndUDPZoneReadTheField;
   Test_NoOtherContestReadsTheYearField;
   Test_EditQSOsZoneBoxFollowsTheContest;
   Test_AYearContestRecordsMyCallsCQZone;
   Test_TheMatrixBuilderStoresTheYear;
end;

end.

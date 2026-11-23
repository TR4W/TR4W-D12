unit uTestRoverState;
{$I ..\..\src\tr4w.inc}

(* WHERE A ROVING STATION IS NOW -- issues 133 and 87 (NY4I, 2026-11-19).

  WHAT IS PINNED, AND WHY EACH:

    the split       a typed entry takes a space, a comma, a dash or a slash
                    between units, any case, a repeat once: NY4I's three
                    separators plus the on-air slash;
    the refusal     a unit that is no place of the contest is named; more
                    units than the county-line limit are refused; a limit
                    below one means one;
    the state       off by default, on with the units in the order chosen,
                    off again on TurnOff -- and joined for display. *)

interface

uses
   uTR4WTestFramework;

type
   TRoverStateTests = class(TTestCase)
   protected
      procedure Test_TheThreeSeparatorsAndTheSlashSplitUnits;
      procedure Test_AnUnknownUnitIsNamed;
      procedure Test_TheCountyLineLimitHolds;
      procedure Test_TheStateIsOffUntilSet;
      procedure Test_HawaiiRovesItsFourteenDistrictsTwoAtATime;
      procedure Test_TheDialogTicksWhatIsTypedAndRefusesPastTheLimit;
      procedure Test_TheExportSendsTheRoverPlaceAndMyCountyIsItsCounty;
      procedure Test_ASchema11LogGainsTheRoverColumnInOneCommit;
      procedure Test_TheCallOnTheAirAndTheRoverQTHToken;
      procedure Test_ARoverFromANewPlaceIsNoDupe;
      procedure Test_ABoundaryEntryLogsOneQSOPerPlace;
      procedure Test_MyCountyOfARoverPlaceIsItsADIFCounty;
      procedure Test_TheCountyFileNamesWhatTheListNamed;
      procedure Test_AnInStateSessionNamesItsCounties;
      procedure Test_EveryNewYorkCountyCodeNamesItsADIFCounty;
      procedure Test_EveryFloridaAndTennesseeCountyNamesItsADIFCounty;
      procedure Test_TheOtherSixCountyFilesNameTheirCounties;
      procedure Test_ASchema12LogGainsTheSentUnitColumnsInOneCommit;
      procedure Test_ASchema13LogGainsThePrefectureColumnsInOneCommit;
      procedure Test_AnInStatePartyQSOKeepsTheHostStateAndSendsItsUnit;
      procedure Test_TheCallIsAssembledFromTheSettingAndThePlaces;
      procedure CheckEveryCountyNamed(const aContestId, aFile, aState: string;
                                      aCount: integer;
                                      const aPins: array of string;
                                      const aUnnamed: array of string);
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, Controls,
   uAppStrings,          (* SRover* *)
   uRoverForm,           (* TfrmRover *)
   VC,                   (* CQWWCW, TContestHandle *)
   uContestRegistry,     (* FindContestById, ContestIdentity *)
   uContestBase,         (* TMyStationExchange, MyStationExchangeWithRoverPlace *)
   uLogDatabase,         (* TLogDatabase *)
   uLogSchema,           (* LOG_V12_QSO_ROVER_QTH_COLUMN, LOG_SCHEMA_VERSION *)
   uTestLatestContest,   (* DowngradeTestLog, TestLogHasColumn, ScrubTestLog *)
   uTestLogDatabase,     (* CommitFramesInWal *)
   uSettingsModel,       (* Settings.Qso -- the dupe sheet's scope *)
   uCallsigns,           (* TCallsignsList, TQualifiedDupeSheet, the two sheets *)
   PostUnit,             (* Contest -- the active contest's handle *)
   LogEdit,              (* VisibleLog.QSOIsADupe, AddQSOToDupeSheets *)
   uMults,               (* mo.DomList -- the session's multiplier list *)
   uAppPaths,            (* ShippedDomDirOverride *)
   uTestContestObjects,  (* ShippedDomDir -- the tree's target\dom *)
   uNewContestHostArea,  (* THostAreaPlaces *)
   uRoverSession,        (* ContestRoverPlaces *)
   LogDom,               (* DomQTHTable, TDomQTHTable -- the real county file's load *)
   uSortedStringList,    (* TSortedStringList -- a fresh mo.DomList *)
   uQsoMyFacts,          (* TQsoMyFacts, AssembledCall -- schema 13 *)
   uDomFileKeys,         (* DomFileLineKey -- every key a county file declares *)
   uLogSource,           (* ExportCallFor, CabrilloCallFor -- a stored row's two calls *)
   uContestStateQSOPartyBase,  (* TContestStateQSOPartyBase -- the parties walked *)
   uTestRegisteredContests,    (* ContestsToWalk, ContestWho *)
   uRoverState;

(* Three Hawaii districts, as hawaiiqp_cty.dom spells its lines. *)
function HawaiiPlaces: THostAreaPlaces;
var
   lines: TStringList;
begin
   Result := THostAreaPlaces.Create;
   lines := TStringList.Create;
   try
      lines.Add('KOH > Hi = KOH,^Kohala');
      lines.Add('KON > Hi = KON,^Kona');
      lines.Add('HIL > Hi = HIL,^Hilo');
      Result.LoadFromLines(lines);
   finally
      lines.Free;
      end;
end;

procedure TRoverStateTests.Test_TheThreeSeparatorsAndTheSlashSplitUnits;
var
   units: TStringList;
begin
   BeginTest('Test_TheThreeSeparatorsAndTheSlashSplitUnits');
   units := TStringList.Create;
   try
      CheckTrue(SplitRoverUnitsText('koh', units), 'one unit');
      CheckEquals('KOH', units.CommaText, 'upper-cased');

      SplitRoverUnitsText('KOH KON', units);
      CheckEquals('KOH,KON', units.CommaText, 'a space');
      SplitRoverUnitsText('KOH,KON', units);
      CheckEquals('KOH,KON', units.CommaText, 'a comma');
      SplitRoverUnitsText('KOH-KON', units);
      CheckEquals('KOH,KON', units.CommaText, 'a dash');
      SplitRoverUnitsText('KOH/KON', units);
      CheckEquals('KOH,KON', units.CommaText, 'a slash');
      SplitRoverUnitsText(' KON , - koh  ', units);
      CheckEquals('KON,KOH', units.CommaText, 'mixed, blanks, order kept');
      SplitRoverUnitsText('KOH KOH kon', units);
      CheckEquals('KOH,KON', units.CommaText, 'a repeat counts once');

      CheckFalse(SplitRoverUnitsText(' , - ', units), 'separators alone are nothing');
      CheckEquals(0, units.Count, 'and leave the list empty');
   finally
      units.Free;
      end;
end;

procedure TRoverStateTests.Test_AnUnknownUnitIsNamed;
var
   units: TStringList;
   places: THostAreaPlaces;
begin
   BeginTest('Test_AnUnknownUnitIsNamed');
   units := TStringList.Create;
   places := HawaiiPlaces;
   try
      SplitRoverUnitsText('KOH', units);
      CheckEquals('', RoverUnitsRefusal(units, places, 2), 'a district is a place');

      SplitRoverUnitsText('KOH XYZ', units);
      CheckEquals(Format(SRoverUnknownUnit, ['XYZ']),
                  RoverUnitsRefusal(units, places, 2), 'XYZ is named');

      units.Clear;
      CheckEquals(string(SRoverNoUnit), RoverUnitsRefusal(units, places, 2),
                  'nothing is refused');
   finally
      places.Free;
      units.Free;
      end;
end;

procedure TRoverStateTests.Test_TheCountyLineLimitHolds;
var
   units: TStringList;
   places: THostAreaPlaces;
begin
   BeginTest('Test_TheCountyLineLimitHolds');
   units := TStringList.Create;
   places := HawaiiPlaces;
   try
      SplitRoverUnitsText('KOH KON', units);
      CheckEquals('', RoverUnitsRefusal(units, places, 2),
                  'two at Hawaii''s limit of two');
      SplitRoverUnitsText('KOH KON HIL', units);
      CheckEquals(Format(SRoverTooManyUnits, [2]),
                  RoverUnitsRefusal(units, places, 2), 'three past it');

      SplitRoverUnitsText('KOH KON', units);
      CheckEquals(Format(SRoverTooManyUnits, [1]),
                  RoverUnitsRefusal(units, places, 0),
                  'a party with no county line takes one');
      CheckEquals('', RoverUnitsRefusal(units, places, High(integer)),
                  'an unlimited party takes any number');
   finally
      places.Free;
      units.Free;
      end;
end;

procedure TRoverStateTests.Test_TheStateIsOffUntilSet;
var
   state: TRoverState;
   units: TStringList;
begin
   BeginTest('Test_TheStateIsOffUntilSet');
   state := TRoverState.Create;
   units := TStringList.Create;
   try
      CheckFalse(state.Active, 'off when made');
      CheckEquals('', state.Joined('/'), 'and joins to nothing');

      SplitRoverUnitsText('KON KOH', units);
      state.SetUnits(units);
      CheckTrue(state.Active, 'on with units');
      CheckEquals(2, state.Count, 'two of them');
      CheckEquals('KON', state.UnitAt(0), 'in the order chosen');
      CheckEquals('KON/KOH', state.Joined('/'), 'joined for display');

      state.TurnOff;
      CheckFalse(state.Active, 'off again');

      CheckFalse(RoverState.Active, 'the program''s state starts off');
   finally
      units.Free;
      state.Free;
      end;
end;

(* THE CONTEST'S OWN UNITS: Hawaii's district file (the New Contest box's), at
  its county-line limit of two; Georgia's counties at its own; CQ WW has none,
  so ROVER says so. *)
procedure TRoverStateTests.Test_HawaiiRovesItsFourteenDistrictsTwoAtATime;
var
   places: THostAreaPlaces;
   maxUnits: integer;
   handle: TContestHandle;
   savedDomDir: string;
begin
   BeginTest('Test_HawaiiRovesItsFourteenDistrictsTwoAtATime');
   places := THostAreaPlaces.Create;
   savedDomDir := ShippedDomDirOverride;
   try
      ShippedDomDirOverride := ShippedDomDir;

      CheckTrue(FindContestById('HI-QSO-PARTY', handle), 'Hawaii is registered');
      CheckTrue(ContestRoverPlaces(ContestIdentity(handle), places, maxUnits),
                'Hawaii has rover places');
      CheckEquals(14, places.Count, 'its fourteen districts');
      CheckTrue(places.IndexOfKey('KOH') >= 0, 'KOH among them');
      CheckEquals(-1, places.IndexOfKey('HI'), 'and no state');
      CheckEquals(2, maxUnits, 'two at a district line');

      CheckFalse(ContestRoverPlaces(ContestIdentity(CQWWCW), places, maxUnits),
                 'CQ WW has no places to rove');
      CheckEquals(0, places.Count, 'and loads none');
      CheckEquals(1, maxUnits, 'and its limit reads one');

      CheckFalse(ContestRoverPlaces(nil, places, maxUnits), 'no contest, no places');
   finally
      ShippedDomDirOverride := savedDomDir;
      places.Free;
      end;
end;

(* THE DIALOG, NEVER SHOWN: what is typed ticks the list, a tick writes the
  box, OK refuses past the limit and names why, "Rover off" turns it off. *)
procedure TRoverStateTests.Test_TheDialogTicksWhatIsTypedAndRefusesPastTheLimit;
var
   places: THostAreaPlaces;
   state: TRoverState;
   form: TfrmRover;
begin
   BeginTest('Test_TheDialogTicksWhatIsTypedAndRefusesPastTheLimit');
   places := HawaiiPlaces;
   state := TRoverState.Create;
   form := TfrmRover.Create(nil);
   try
      form.Prepare(places, 2, state);
      CheckEquals(3, form.clbUnits.Items.Count, 'one row per place');
      CheckEquals('KOH - Kohala', form.clbUnits.Items[0], 'shown with its name');
      CheckEquals('', form.edtUnits.Text, 'nothing typed when not roving');

      form.edtUnits.Text := 'KOH-KON';
      CheckTrue(form.clbUnits.Checked[0], 'KOH ticked from the box');
      CheckTrue(form.clbUnits.Checked[1], 'KON ticked from the box');
      CheckFalse(form.clbUnits.Checked[2], 'HIL not');

      form.clbUnits.Checked[1] := False;
      form.UnitsClickCheck(form.clbUnits);
      CheckEquals('KOH', form.edtUnits.Text, 'unticking KON takes it out of the box');

      form.edtUnits.Text := 'KOH KON HIL';
      form.OKClick(form.btnOK);
      CheckEquals(integer(mrNone), integer(form.ModalResult), 'three at a limit of two stays open');
      CheckEquals(Format(SRoverTooManyUnits, [2]), form.lblRefusal.Caption, 'and says why');

      form.edtUnits.Text := 'kon, koh';
      form.OKClick(form.btnOK);
      CheckEquals(integer(mrOK), integer(form.ModalResult), 'two is accepted');
      CheckEquals('KON,KOH', form.Chosen.CommaText, 'in the order typed');
      CheckFalse(form.TurnedOff, 'and is no "off"');

      form.OffClick(form.btnOff);
      CheckTrue(form.TurnedOff, '"Rover off" turns it off');
      CheckEquals(0, form.Chosen.Count, 'with nothing chosen');
   finally
      form.Free;
      state.Free;
      places.Free;
      end;
end;

(* LOG SCHEMA 12, AS NY4I RULED IT (2026-11-19): a district goes in the SENT
  EXCHANGE -- the row's ceRoverQTH replaces MY STATE in what the export says
  was sent, and a QSO not sent while roving is exactly as before -- and
  my_county is the REAL county the district lies in, by the crosswalk the
  worked station's CNTY uses (state 'HI', county 'Hawaii' for KOH). *)
procedure TRoverStateTests.Test_TheExportSendsTheRoverPlaceAndMyCountyIsItsCounty;
var
   my, sent: TMyStationExchange;
   qso: ContestExchange;
   handle: TContestHandle;
   hawaii: TContestBase;
begin
   BeginTest('Test_TheExportSendsTheRoverPlaceAndMyCountyIsItsCounty');
   my := Default(TMyStationExchange);
   my.MyState := 'KON';

   sent := MyStationExchangeWithRoverPlace(my, 'KOH');
   CheckEquals('KOH', sent.MyState, 'a rover''s QSO sent its place');
   sent := MyStationExchangeWithRoverPlace(my, '');
   CheckEquals('KON', sent.MyState, 'a QSO not sent while roving is unchanged');

   CheckTrue(FindContestById('HI-QSO-PARTY', handle), 'Hawaii is registered');
   hawaii := ContestIdentity(handle);
   qso := Default(ContestExchange);
   qso.RSTSent := 599;
   qso.Mode := CW;
   CheckTrue(Pos('KOH', hawaii.FormatADIFSentExchange(
                            MyStationExchangeWithRoverPlace(my, 'KOH'), qso)) > 0,
             'Hawaii''s STX_STRING carries the rover''s district');

   (* THE CROSSWALK, of a record built as PostUnit.RoverPlaceADIFCounty builds
     it: the place as its QTH, resolved as itself. *)
   qso.QTHString := 'KOH';
   qso.DomesticQTH := 'KOH';
   CheckEquals('HI', hawaii.ADIFCountyState(qso), 'KOH is a Hawaii county place');
   CheckEquals('Hawaii', hawaii.ADIFCountyName(qso, 'Kohala'),
               'KOH lies in Hawaii county, not "Kohala"');
   qso.QTHString := 'HON';
   qso.DomesticQTH := 'HON';
   CheckEquals('Honolulu', hawaii.ADIFCountyName(qso, 'Honolulu'), 'HON in Honolulu');
end;

(* LOG SCHEMA 12 ON A SCHEMA-11 LOG: the column added by ALTER, NULL in every
  row (no earlier build roved), the version stamped, ONE commit; a second
  open changes nothing. A new log has it too. *)
procedure TRoverStateTests.Test_ASchema11LogGainsTheRoverColumnInOneCommit;
var
   fn, dir: string;
   db: TLogDatabase;
begin
   BeginTest('Test_ASchema11LogGainsTheRoverColumnInOneCommit');
   dir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_rover_' + IntToStr(GetProcessID);
   ForceDirectories(dir);
   fn := IncludeTrailingPathDelimiter(dir) + 'rover11.db';
   ScrubTestLog(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V12_QSO_ROVER_QTH_COLUMN.Name)),
                'a new log has my_rover_qth');
   finally
      db.Free;
   end;
   DowngradeTestLog(fn, 11, Low(LOG_V3_QSO_COLUMNS));
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no WAL is left by the fixture');

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(1, CommitFramesInWal(fn + '-wal'), 'the column and the stamp: ONE commit');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'stamped current');
      CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V12_QSO_ROVER_QTH_COLUMN.Name)),
                'the column is there');
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(0, CommitFramesInWal(fn + '-wal'), 'a second open commits nothing');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'still current');
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

(* NY4I, 2026-11-17 and 2026-11-19: while roving the call on the air (what
  {ROVERCALL} keys -- since 2026-11-20 '\' is always the plain call) is the
  roving call -- NY4I/KOH, NY4I/KOH/KON at a boundary -- and a fixed station
  never sends a /KOH. *)
procedure TRoverStateTests.Test_TheCallOnTheAirAndTheRoverQTHToken;
var
   units: TStringList;
begin
   BeginTest('Test_TheCallOnTheAirAndTheRoverQTHToken');
   units := TStringList.Create;
   try
      RoverState.TurnOff;
      CheckEquals('NY4I', RovingCall('NY4I'), 'not roving: the plain call');
      CheckEquals('', RovingCall(''), 'no call: nothing to suffix');

      SplitRoverUnitsText('KOH', units);
      RoverState.SetUnits(units);
      CheckEquals('NY4I/KOH', RovingCall('NY4I'), 'roving: the call gains its place');

      SplitRoverUnitsText('KON KOH', units);
      RoverState.SetUnits(units);
      CheckEquals('NY4I/KON/KOH', RovingCall('NY4I'),
                  'a boundary: both places, in the order chosen');

      RoverState.TurnOff;
      CheckEquals('NY4I', RovingCall('NY4I'), 'off again: the plain call');
      (* The {ROVERQTH} / {ROVERCALL} tokens are uMessageText's now, and
        pinned in uTestMessageText (2026-11-20). *)
   finally
      RoverState.TurnOff;
      units.Free;
      end;
end;

(* NY4I, 2026-11-18 (issue 133): "NY4I/PIN is NOT a dupe of NY4I/PAS" --
  the dupe key carries the place the ROVER sent the QSO from, read from the
  record (ceRoverQTH), through the routines LogContact, the loader and the
  rescore all call (VisibleLog.QSOIsADupe, AddQSOToDupeSheets). A QSO not
  sent while roving keys exactly as before; a contest that is no state party
  never reads the place. *)
procedure TRoverStateTests.Test_ARoverFromANewPlaceIsNoDupe;
var
   handle: TContestHandle;
   hawaii: TContestBase;
   savedContest: TContestHandle;
   savedByBand, savedByMode: boolean;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   rx: ContestExchange;

   function QSO(const aRover: string): ContestExchange;
   begin
      Result := Default(ContestExchange);
      Result.Callsign := 'W1AW';
      Result.QTHString := 'CT';
      Result.DomesticQTH := 'CT';
      Result.Band := Band20;
      Result.Mode := CW;
      Result.ceRecordKind := rkQSO;
      Result.ceContest := Contest;
      Result.ceRoverQTH := ShortString(aRover);
   end;

begin
   BeginTest('Test_ARoverFromANewPlaceIsNoDupe');
   CheckTrue(FindContestById('HI-QSO-PARTY', handle), 'Hawaii is registered');
   hawaii := ContestIdentity(handle);

   (* THE KEY ITSELF. *)
   CheckTrue(hawaii.DupeKeyIncludesSentQTH, 'a state party keys the rover''s place');
   CheckFalse(ContestIdentity(CQWWCW).DupeKeyIncludesSentQTH, 'CQ WW does not');
   rx := QSO('');
   CheckEquals('CT', hawaii.DupeKeyQualifier(rx), 'not roving: the key is as before');
   rx := QSO('KOH');
   CheckEquals('CT'#2'KOH', hawaii.DupeKeyQualifier(rx), 'from KOH: the place joins it');
   CheckEquals('', ContestIdentity(CQWWCW).DupeKeyQualifier(rx),
               'CQ WW''s key never reads the place');

   (* THROUGH THE ENGINE'S SHEETS, as LogContact, the loader and the rescore
      ask them. *)
   savedContest := Contest;
   savedByBand := Settings.Qso.ByBand;
   savedByMode := Settings.Qso.ByMode;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      Contest := handle;
      Settings.Qso.ByBand := True;
      Settings.Qso.ByMode := True;

      rx := QSO('KOH');
      CheckFalse(VisibleLog.QSOIsADupe(rx), 'the first QSO from KOH is new');
      AddQSOToDupeSheets(rx, False);
      rx := QSO('KOH');
      CheckTrue(VisibleLog.QSOIsADupe(rx), 'W1AW again from KOH is a dupe');
      rx := QSO('KON');
      CheckFalse(VisibleLog.QSOIsADupe(rx), 'W1AW from KON is NOT a dupe of KOH');
      AddQSOToDupeSheets(rx, False);
      rx := QSO('KON');
      CheckTrue(VisibleLog.QSOIsADupe(rx), 'and from KON again is');

      rx := QSO('');
      CheckFalse(VisibleLog.QSOIsADupe(rx), 'a fixed station''s key is apart from a rover''s');
      AddQSOToDupeSheets(rx, False);
      rx := QSO('');
      CheckTrue(VisibleLog.QSOIsADupe(rx), 'and a fixed station''s repeat is a dupe, as ever');
   finally
      CallsignsList.Free;
      QualifiedDupes.Free;
      CallsignsList := savedList;
      QualifiedDupes := savedQualified;
      Settings.Qso.ByMode := savedByMode;
      Settings.Qso.ByBand := savedByBand;
      Contest := savedContest;
   end;
end;

(* A BOUNDARY ENTRY IS ONE QSO PER PLACE (issue 133): the extra rows are
  copies of every row the entry logged from the first place, one set per
  further place, each stamped with its place and keeping the entry's id (the
  store's qso_set_id link); a received county line is crossed with ours.
  MainUnit.DrainPendingMultiQSORefs logs them (it cannot run headless, so
  its call is pinned by reading the source). *)
procedure TRoverStateTests.Test_ABoundaryEntryLogsOneQSOPerPlace;
var
   state: TRoverState;
   units: TStringList;
   logged, legs: TRoverLegs;
   source: TStringList;
   drain: integer;
begin
   BeginTest('Test_ABoundaryEntryLogsOneQSOPerPlace');
   state := TRoverState.Create;
   units := TStringList.Create;
   try
      SetLength(logged, 1);
      logged[0] := Default(ContestExchange);
      logged[0].Callsign := 'W1AW';
      logged[0].QTHString := 'CT';
      logged[0].id := 'ENTRY1';
      logged[0].ceRoverQTH := 'KOH';

      CheckEquals(0, Length(RoverBoundaryLegs(logged, state)), 'not roving: no extra QSO');
      SplitRoverUnitsText('KOH', units);
      state.SetUnits(units);
      CheckEquals(0, Length(RoverBoundaryLegs(logged, state)), 'one place: none');

      SplitRoverUnitsText('KOH KON', units);
      state.SetUnits(units);
      legs := RoverBoundaryLegs(logged, state);
      CheckEquals(1, Length(legs), 'two places: one more QSO');
      CheckEquals('KON', string(legs[0].ceRoverQTH), 'from the second place');
      CheckEquals('W1AW', string(legs[0].Callsign), 'with the same station');
      CheckEquals('ENTRY1', string(legs[0].id), 'and the entry''s id, so one set');

      (* A DUPE FROM KOH IS NOT A DUPE FROM KON BY INHERITANCE. *)
      logged[0].ceDupe := True;
      legs := RoverBoundaryLegs(logged, state);
      CheckFalse(legs[0].ceDupe, 'the copy carries no dupe mark from the first place');
      logged[0].ceDupe := False;

      (* The worked station on a county line too: CT and RI received. *)
      SetLength(logged, 2);
      logged[1] := logged[0];
      logged[1].QTHString := 'RI';
      legs := RoverBoundaryLegs(logged, state);
      CheckEquals(2, Length(legs), 'each received leg from the second place');
      CheckEquals('CT', string(legs[0].QTHString), 'CT from KON');
      CheckEquals('RI', string(legs[1].QTHString), 'RI from KON');
      CheckEquals('KON', string(legs[1].ceRoverQTH), 'both from KON');
   finally
      units.Free;
      state.Free;
      end;

   source := TStringList.Create;
   try
      source.LoadFromFile(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
                          PathDelim + 'src' + PathDelim + 'MainUnit.pas');
      (* ISSUE 348: the drain is the leg builder of one submission
         (MainUnit.TEntryLegs.BuildLeg); the copies are legs of the entry. *)
      drain := Pos('procedure TEntryLegs.BuildLeg(', source.Text);
      CheckTrue(drain > 0, 'MainUnit has the leg builder');
      CheckTrue(Pos('RoverBoundaryLegs(logged, RoverState)',
                    Copy(source.Text, drain, 6000)) > 0,
                'and it makes the rover''s boundary legs');
   finally
      source.Free;
   end;
end;

(* my_county OF A ROVER'S QSO, THROUGH THE REAL ROUTINE
  (PostUnit.RoverPlaceADIFCounty -- the worked station's CNTY rule): a Hawaii
  district gives the county it lies in, a county party's county the name its
  COUNTY FILE gives it -- whatever the session's multiplier list holds
  (2026-11-20; it was the list's AltName, seeded here by hand). A place that
  is no key of the county file gives none. *)
procedure TRoverStateTests.Test_MyCountyOfARoverPlaceIsItsADIFCounty;
var
   handle: TContestHandle;
   savedContest: TContestHandle;
   savedDomDir: string;
   savedList: TSortedStringList;
begin
   BeginTest('Test_MyCountyOfARoverPlaceIsItsADIFCounty');
   savedContest := Contest;
   savedDomDir := ShippedDomDirOverride;
   savedList := mo.DomList;
   ShippedDomDirOverride := ShippedDomDir;
   (* AN EMPTY LIST: the answer must not come from it. *)
   mo.DomList := TSortedStringList.Create;
   try
      CheckTrue(FindContestById('HI-QSO-PARTY', handle), 'Hawaii is registered');
      Contest := handle;
      CheckEquals('HI,Hawaii', RoverPlaceADIFCounty('KOH'),
                  'KOH lies in Hawaii county: my_county is the county, not the district');
      CheckEquals('', RoverPlaceADIFCounty(''), 'no place, no county');
      CheckEquals('', RoverPlaceADIFCounty('ZZZ'),
                  'a place the county file does not declare gives none');

      CheckTrue(FindContestById('GA-QSO-PARTY', handle), 'Georgia is registered');
      Contest := handle;
      CheckEquals('GA,APPLING', RoverPlaceADIFCounty('appl'),
                  'a county party''s county is its county file''s name, in any case');
   finally
      mo.DomList.Free;
      mo.DomList := savedList;
      ShippedDomDirOverride := savedDomDir;
      Contest := savedContest;
   end;
end;

(* THE COUNTY FILE NAMES WHAT THE MULTIPLIER LIST NAMED (2026-11-20). The
  ADIF county name moved from the session's list (mo.DomList's AltName) to
  the party's own county file (CountyFileCountyName). An OUT-OF-STATE session
  -- the only one whose list held the counties -- must not move: for EVERY
  party and EVERY key its county file declares, the file loaded as that
  session loads it (MultipliersIsCounties) gives the list's answer, found or
  not and name for name. *)
procedure TRoverStateTests.Test_TheCountyFileNamesWhatTheListNamed;
var
   parties: TContestIdentityList;
   party: TContestBase;
   savedTable: TDomQTHTable;
   savedList: TSortedStringList;
   savedCounties: boolean;
   savedDomDir: string;
   lines: TStringList;
   i, p, index, checked: integer;
   key, fileName, listName: string;
   inFile, inList: boolean;
begin
   BeginTest('Test_TheCountyFileNamesWhatTheListNamed');
   parties := ContestsToWalk;
   savedTable := DomQTHTable;
   savedList := mo.DomList;
   savedCounties := MultipliersIsCounties;
   savedDomDir := ShippedDomDirOverride;
   ShippedDomDirOverride := ShippedDomDir;
   lines := TStringList.Create;
   DomQTHTable := nil;
   mo.DomList := nil;
   checked := 0;
   try
      MultipliersIsCounties := True;
      for p := 0 to High(parties) do
         begin
         party := parties[p];
         if not (party is TContestStateQSOPartyBase) then
            begin
            Continue;
            end;
         DomQTHTable.Free;
         DomQTHTable := TDomQTHTable.Create;
         mo.DomList.Free;
         mo.DomList := TSortedStringList.Create;
         CheckTrue(DomQTHTable.LoadInDomQTHFile(IncludeTrailingPathDelimiter(ShippedDomDir) +
                                                party.DomesticFileName + '.dom'),
                   ContestWho(party) + ': its county file loads');
         lines.LoadFromFile(IncludeTrailingPathDelimiter(ShippedDomDir) +
                            party.DomesticFileName + '.dom');
         for i := 0 to lines.Count - 1 do
            begin
            key := DomFileLineKey(lines[i]);
            if key = '' then
               begin
               Continue;
               end;
            inList := mo.DomList.FindMult(key, index);
            listName := '';
            if inList then
               begin
               listName := string(mo.DomList.AltName[index]);
               end;
            inFile := party.CountyFileCountyName(key, fileName);
            CheckTrue(inList = inFile, ContestWho(party) + ': ' + key + ' is a county in both');
            CheckEquals(listName, fileName, ContestWho(party) + ': ' + key + '''s name');
            Inc(checked);
            end;
         end;
      CheckTrue(checked > 1000, 'every party''s every county was compared');
   finally
      lines.Free;
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      mo.DomList.Free;
      mo.DomList := savedList;
      MultipliersIsCounties := savedCounties;
      ShippedDomDirOverride := savedDomDir;
   end;
end;

(* AN IN-STATE SESSION NAMES ITS OWN COUNTIES (2026-11-20). florida.dom files
  every Florida county under Fl ('Pin > Fl = PIN') and georgia.dom's county
  file every county under Ga, so an in-state session's list holds no county
  key: the list-based rule wrote no CNTY for an in-state county and left an
  in-state station's my_county blank. The county file answers instead. *)
procedure TRoverStateTests.Test_AnInStateSessionNamesItsCounties;
var
   handle: TContestHandle;
   savedContest: TContestHandle;
   savedTable: TDomQTHTable;
   savedList: TSortedStringList;
   savedCounties: boolean;
   savedDomDir: string;
   index: integer;
   facts: TQsoMyFacts;

   procedure LoadInState(const aFile: string);
   begin
      DomQTHTable.Free;
      DomQTHTable := TDomQTHTable.Create;
      mo.DomList.Free;
      mo.DomList := TSortedStringList.Create;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(IncludeTrailingPathDelimiter(ShippedDomDir) + aFile),
                aFile + ' loads');
   end;

begin
   BeginTest('Test_AnInStateSessionNamesItsCounties');
   savedContest := Contest;
   savedTable := DomQTHTable;
   savedList := mo.DomList;
   savedCounties := MultipliersIsCounties;
   savedDomDir := ShippedDomDirOverride;
   ShippedDomDirOverride := ShippedDomDir;
   DomQTHTable := nil;
   mo.DomList := nil;
   try
      (* As FoundContest sets it for an in-state entrant. *)
      MultipliersIsCounties := False;

      Contest := ContestHandleOf(FLORIDAQSOPARTY);
      LoadInState('florida.dom');
      CheckFalse(mo.DomList.FindMult('PIN', index),
                 'the cause: an in-state Florida list holds no county key');
      CheckEquals('FL,PINELLAS', RoverPlaceADIFCounty('PIN'),
                  'an in-state Florida county still names its county');
      facts := NotCapturedMyFacts;
      facts.Source := mfsLogged;
      facts.State := 'PIN';
      CheckTrue(ApplyPartyUnitToMyFacts('PIN', facts), 'PIN is a Florida unit');
      CheckEquals('FL', string(facts.State), 'my_state FL');
      CheckEquals('FL,PINELLAS', string(facts.County), 'my_county Pinellas, not blank');
      CheckEquals('PIN', string(facts.SentUnit), 'and it sends PIN');

      CheckTrue(FindContestById('GA-QSO-PARTY', handle), 'Georgia is registered');
      Contest := handle;
      LoadInState('georgia.dom');
      CheckFalse(mo.DomList.FindMult('APPL', index),
                 'the cause: an in-state Georgia list files APPL under Ga');
      CheckEquals('GA,APPLING', RoverPlaceADIFCounty('APPL'),
                  'an in-state Georgia county names its county');
   finally
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      mo.DomList.Free;
      mo.DomList := savedList;
      MultipliersIsCounties := savedCounties;
      ShippedDomDirOverride := savedDomDir;
      Contest := savedContest;
   end;
end;

(* THE NEW YORK QSO PARTY'S COUNTIES, THROUGH THE REAL FILE (NY4I's rover
  test, 2026-11-19: KIN/QUE stored no my_county). newyork_cty.dom carried
  no ^Name for any county, so mo.DomList had no display name and
  PostUnit.ADIFCountyOfQSO -- my_county of a rover's place AND the worked
  station's CNTY -- answered '' for every NY county. The test above seeded
  the name by hand and could not see it. Here the shipped file is loaded
  as the session loads it, and EVERY key it holds must name its county;
  the names are the sponsor's table (docs/ContestRules/QSOParties/NewYork,
  v1.1), spelled as the ADIF county list spells them. CAY is Cayuga and
  CHA Chautauqua. *)
procedure TRoverStateTests.Test_EveryNewYorkCountyCodeNamesItsADIFCounty;
begin
   BeginTest('Test_EveryNewYorkCountyCodeNamesItsADIFCounty');
   CheckEveryCountyNamed('NY-QSO-PARTY', 'newyork_cty.dom', 'NY', 62,
      ['KIN=NY,KINGS', 'QUE=NY,QUEENS', 'CAT=NY,CATTARAUGUS',
       'CAY=NY,CAYUGA', 'CHA=NY,CHAUTAUQUA', 'ALB=NY,ALBANY',
       'NEW=NY,NEW YORK', 'STL=NY,ST. LAWRENCE'], []);
end;

(* THE SAME FOR FLORIDA AND TENNESSEE (NY4I, 2026-11-20): their county
  files had no ^Name either, so neither ever wrote a CNTY. The names are the
  sponsors' tables -- docs/ContestRules/QSOParties/Florida/
  FL-QSO-PARTY-Counties.txt and Tennessee/TN-QSO-PARTY-Rules.txt -- each
  checked against the ADIF county list when it was written. Arizona,
  Indiana, Michigan, North Carolina, the 7QP and Virginia followed on
  2026-11-20 (Test_TheOtherSixCountyFilesNameTheirCounties). *)
procedure TRoverStateTests.Test_EveryFloridaAndTennesseeCountyNamesItsADIFCounty;
begin
   BeginTest('Test_EveryFloridaAndTennesseeCountyNamesItsADIFCounty');
   CheckEveryCountyNamed(ContestId(ContestHandleOf(FLORIDAQSOPARTY)), 'florida_cty.dom', 'FL', 67,
      ['PIN=FL,PINELLAS', 'HIL=FL,HILLSBOROUGH', 'DAD=FL,MIAMI-DADE',
       'STJ=FL,ST. JOHNS', 'BAY=FL,BAY', 'DES=FL,DESOTO'], []);
   CheckEveryCountyNamed(ContestId(ContestHandleOf(TENNESSEEQSOPARTY)), 'tennessee_cty.dom', 'TN', 95,
      ['ANDE=TN,ANDERSON', 'VANB=TN,VAN BUREN', 'MCMI=TN,MCMINN',
       'HARN=TN,HARDIN', 'HARD=TN,HARDEMAN'], []);
end;

(* THE OTHER SIX COUNTY FILES (2026-11-20): Arizona, Indiana, Michigan, North
  Carolina and Virginia write CNTY and now name every county, from the
  sponsors' own tables committed beside their rules (docs/ContestRules/
  QSOParties/<party>/<XX>-QSO-PARTY-Counties.txt), each name spelled as the
  ADIF county list spells it (the K1MU validator's) -- Indiana's St Joseph has
  no period there, Michigan's St. Clair has one; a Virginia independent city
  is '<name> City' where the list says so (Fairfax City, Richmond City) and
  plain where it does not (Bristol, Salem).
  ONE KEY IS LEFT UNNAMED ON PURPOSE: North Carolina's CHO, which the
  sponsor's table spells "CHOwen" -- no North Carolina county; Chowan is
  presumably meant, which is the sponsor's to confirm, not this file's to
  guess.
  The 7QP's file is named too (the 7QP table, all eight states) but its class
  writes no CNTY, so the names are asked of the file itself. *)
procedure TRoverStateTests.Test_TheOtherSixCountyFilesNameTheirCounties;
var
   lines, names: TStringList;
   i, keys: integer;
   key: string;
begin
   BeginTest('Test_TheOtherSixCountyFilesNameTheirCounties');
   CheckEveryCountyNamed(ContestId(ContestHandleOf(ArizonaQsoParty)), 'arizona_cty.dom', 'AZ', 15,
      ['APH=AZ,APACHE', 'LPZ=AZ,LA PAZ', 'SCZ=AZ,SANTA CRUZ', 'YMA=AZ,YUMA'], []);
   CheckEveryCountyNamed(ContestId(ContestHandleOf(INQSOPARTY)), 'in_cty.dom', 'IN', 92,
      ['INADA=IN,ADAMS', 'INMRN=IN,MARION', 'INSTJ=IN,ST JOSEPH', 'INDEK=IN,DEKALB',
       'INLAP=IN,LAPORTE'], []);
   CheckEveryCountyNamed(ContestId(ContestHandleOf(MICHQSOPARTY)), 'michigan_cty.dom', 'MI', 83,
      ['ALCO=MI,ALCONA', 'STCL=MI,ST. CLAIR', 'GRTR=MI,GRAND TRAVERSE',
       'PRESQ=MI,PRESQUE ISLE', 'KZOO=MI,KALAMAZOO'], []);
   CheckEveryCountyNamed(ContestId(ContestHandleOf(NCQSOPARTY)), 'nc_cty.dom', 'NC', 100,
      ['ALA=NC,ALAMANCE', 'DVD=NC,DAVIDSON', 'MCD=NC,MCDOWELL', 'NEW=NC,NEW HANOVER',
       'PEQ=NC,PERQUIMANS', 'GRM=NC,GRAHAM'], ['CHO']);
   CheckEveryCountyNamed(ContestId(ContestHandleOf(VAQP)), 'va_cty.dom', 'VA', 133,
      ['ACC=VA,ACCOMACK', 'FFX=VA,FAIRFAX', 'FXX=VA,FAIRFAX CITY', 'RIC=VA,RICHMOND',
       'RIX=VA,RICHMOND CITY', 'BRX=VA,BRISTOL', 'KQN=VA,KING AND QUEEN',
       'IOW=VA,ISLE OF WIGHT'], []);

   (* THE 7QP: every key of its file named, by the reader the CNTY rule
      uses (uDomFileKeys.DomFileKeyNames). *)
   lines := TStringList.Create;
   names := TStringList.Create;
   try
      lines.LoadFromFile(IncludeTrailingPathDelimiter(ShippedDomDir) + 'seven_cty.dom');
      DomFileKeyNames(lines, names);
      keys := 0;
      for i := 0 to names.Count - 1 do
         begin
         key := string(names.Names[i]);
         CheckTrue(string(names.ValueFromIndex[i]) <> '', 'seven_cty.dom: ' + key + ' is named');
         Inc(keys);
         end;
      CheckEquals(259, keys, 'seven_cty.dom: the 7QP''s 259 counties');
      CheckEquals('APACHE', string(names.Values['AZAPH']), '7QP AZAPH');
      CheckEquals('LEWIS AND CLARK', string(names.Values['MTLEW']), '7QP MTLEW');
      CheckEquals('CARSON CITY', string(names.Values['NVCAR']), '7QP NVCAR');
      CheckEquals('NEZ PERCE', string(names.Values['IDNEZ']), '7QP IDNEZ');
   finally
      names.Free;
      lines.Free;
   end;
end;

(* A COUNTY FILE, LOADED AS THE SESSION LOADS IT into a fresh table and a
  fresh multiplier list, names an ADIF county '<aState>,...' for EVERY key it
  holds (aCount of them), and the pins 'CODE=ST,NAME' exactly. *)
procedure TRoverStateTests.CheckEveryCountyNamed(const aContestId, aFile, aState: string;
                                                 aCount: integer;
                                                 const aPins: array of string;
                                                 const aUnnamed: array of string);

   function IsUnnamed(const aKey: string): boolean;
   var
      u: integer;
   begin
      Result := False;
      for u := Low(aUnnamed) to High(aUnnamed) do
         begin
         if SameText(aUnnamed[u], aKey) then
            begin
            Result := True;
            end;
         end;
   end;

var
   aHandle: TContestHandle;
   savedContest: TContestHandle;
   savedTable: TDomQTHTable;
   savedList: TSortedStringList;
   savedDomDir: string;
   lines: TStringList;
   i, keys: integer;
   key, county: string;
begin
   CheckTrue(FindContestById(aContestId, aHandle), aContestId + ' is registered');
   savedContest := Contest;
   savedTable := DomQTHTable;
   (* THE NAMES ARE THE COUNTY FILE'S (CountyFileCountyName), read from the
      shipped directory: the tree's, here. *)
   savedDomDir := ShippedDomDirOverride;
   ShippedDomDirOverride := ShippedDomDir;
   DomQTHTable := TDomQTHTable.Create;
   (* A FRESH MULTIPLIER LIST, as a session that opened only this contest has:
      the list the rest of the suite left behind holds other contests' keys
      (KIN is also Oklahoma's Kingfisher). *)
   savedList := mo.DomList;
   mo.DomList := TSortedStringList.Create;
   lines := TStringList.Create;
   try
      CheckTrue(DomQTHTable.LoadInDomQTHFile(IncludeTrailingPathDelimiter(ShippedDomDir) + aFile),
                aFile + ' loads');
      Contest := aHandle;

      for i := Low(aPins) to High(aPins) do
         begin
         key := Copy(aPins[i], 1, Pos('=', aPins[i]) - 1);
         CheckEquals(Copy(aPins[i], Pos('=', aPins[i]) + 1, MaxInt),
                     RoverPlaceADIFCounty(key), aFile + ': ' + key);
         end;

      lines.LoadFromFile(IncludeTrailingPathDelimiter(ShippedDomDir) + aFile);
      keys := 0;
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('=', lines[i]) > 0 then
            begin
            key := Trim(Copy(lines[i], 1, Pos('=', lines[i]) - 1));
            county := RoverPlaceADIFCounty(key);
            if IsUnnamed(key) then
               begin
               CheckEquals('', county, aFile + ': ' + key + ' is left unnamed on purpose');
               end
            else
               begin
               CheckTrue(Copy(county, 1, 3) = aState + ',',
                         aFile + ': ' + key + ' names an ADIF county: "' + county + '"');
               end;
            Inc(keys);
            end;
         end;
      CheckEquals(aCount, keys, aFile + ': the sponsor''s counties');
   finally
      lines.Free;
      mo.DomList.Free;
      mo.DomList := savedList;
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      ShippedDomDirOverride := savedDomDir;
      Contest := savedContest;
   end;
end;

(* LOG SCHEMA 13 ON A SCHEMA-12 LOG: my_sent_unit and my_rover_places added
  by ALTER, NULL in every row ("as before"), the version stamped, ONE commit;
  a second open changes nothing. A new log has both, last. *)
procedure TRoverStateTests.Test_ASchema12LogGainsTheSentUnitColumnsInOneCommit;
var
   fn, dir: string;
   db: TLogDatabase;
   i: integer;
begin
   BeginTest('Test_ASchema12LogGainsTheSentUnitColumnsInOneCommit');
   dir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_rover_' + IntToStr(GetProcessID);
   ForceDirectories(dir);
   fn := IncludeTrailingPathDelimiter(dir) + 'rover12.db';
   ScrubTestLog(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      for i := Low(LOG_V13_QSO_COLUMNS) to High(LOG_V13_QSO_COLUMNS) do
         begin
         CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V13_QSO_COLUMNS[i].Name)),
                   'a new log has ' + string(LOG_V13_QSO_COLUMNS[i].Name));
         end;
   finally
      db.Free;
   end;
   DowngradeTestLog(fn, 12, Low(LOG_V3_QSO_COLUMNS));
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no WAL is left by the fixture');

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(1, CommitFramesInWal(fn + '-wal'), 'both columns and the stamp: ONE commit');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'stamped current');
      for i := Low(LOG_V13_QSO_COLUMNS) to High(LOG_V13_QSO_COLUMNS) do
         begin
         CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V13_QSO_COLUMNS[i].Name)),
                   string(LOG_V13_QSO_COLUMNS[i].Name) + ' is there');
         end;
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(0, CommitFramesInWal(fn + '-wal'), 'a second open commits nothing');
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

(* LOG SCHEMA 14 ON A SCHEMA-13 LOG (the ALL JA, 2026-11-23): my_prefecture
  and my_power_class added by ALTER, NULL in every row (unknown -- nothing is
  backfilled), the version stamped, ONE commit; a second open changes
  nothing. A new log has both, last, after schema 13's two. *)
procedure TRoverStateTests.Test_ASchema13LogGainsThePrefectureColumnsInOneCommit;
var
   fn, dir: string;
   db: TLogDatabase;
   i: integer;
begin
   BeginTest('Test_ASchema13LogGainsThePrefectureColumnsInOneCommit');
   dir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_rover_' + IntToStr(GetProcessID);
   ForceDirectories(dir);
   fn := IncludeTrailingPathDelimiter(dir) + 'allja13.db';
   ScrubTestLog(fn);

   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      for i := Low(LOG_V14_QSO_COLUMNS) to High(LOG_V14_QSO_COLUMNS) do
         begin
         CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V14_QSO_COLUMNS[i].Name)),
                   'a new log has ' + string(LOG_V14_QSO_COLUMNS[i].Name));
         end;
   finally
      db.Free;
   end;
   DowngradeTestLog(fn, 13, Low(LOG_V3_QSO_COLUMNS));
   CheckFalse(FileExists(fn + '-wal'), 'precondition: no WAL is left by the fixture');

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(1, CommitFramesInWal(fn + '-wal'), 'both columns and the stamp: ONE commit');
      CheckEquals(LOG_SCHEMA_VERSION, db.SchemaVersion, 'stamped current');
      for i := Low(LOG_V14_QSO_COLUMNS) to High(LOG_V14_QSO_COLUMNS) do
         begin
         CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V14_QSO_COLUMNS[i].Name)),
                   string(LOG_V14_QSO_COLUMNS[i].Name) + ' is there');
         end;
      for i := Low(LOG_V13_QSO_COLUMNS) to High(LOG_V13_QSO_COLUMNS) do
         begin
         CheckTrue(TestLogHasColumn(db, 'qso', string(LOG_V13_QSO_COLUMNS[i].Name)),
                   string(LOG_V13_QSO_COLUMNS[i].Name) + ' is untouched');
         end;
   finally
      db.Free;
   end;

   db := TLogDatabase.Create;
   try
      db.Open(fn);
      CheckEquals(0, CommitFramesInWal(fn + '-wal'), 'a second open commits nothing');
   finally
      db.Free;
   end;
   ScrubTestLog(fn);
end;

(* NY4I, 2026-11-20 ("since I said I was in state"): an in-state party QSO
  records the HOST state in my_state, the unit it sent in my_sent_unit and
  the unit's ADIF county in my_county -- through the REAL county file (NY,
  then Hawaii's district crosswalk) -- and the export's sent slot still sends
  the unit. A two-letter state is no unit and changes nothing. A row from
  before schema 13 (no my_sent_unit, the county code in my_state) sends what
  it always did. The NY rover test's four rows: each sends its own place. *)
procedure TRoverStateTests.Test_AnInStatePartyQSOKeepsTheHostStateAndSendsItsUnit;
var
   handle: TContestHandle;
   savedContest: TContestHandle;
   savedTable: TDomQTHTable;
   savedList: TSortedStringList;
   savedDomDir: string;
   facts: TQsoMyFacts;
   session: TMyStationExchange;

   procedure LoadFresh(const aFile: string);
   begin
      DomQTHTable.Free;
      DomQTHTable := TDomQTHTable.Create;
      mo.DomList.Free;
      mo.DomList := TSortedStringList.Create;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(IncludeTrailingPathDelimiter(ShippedDomDir) + aFile),
                aFile + ' loads');
   end;

   function Sent(const aFacts: TQsoMyFacts; const aRover: string): string;
   begin
      Result := MyStationExchangeWithRoverPlace(
                   MyStationExchangeOfQSO(session, aFacts, True, szkStatedMyZone, rykNone),
                   aRover).MyState;
   end;

begin
   BeginTest('Test_AnInStatePartyQSOKeepsTheHostStateAndSendsItsUnit');
   savedContest := Contest;
   savedTable := DomQTHTable;
   savedList := mo.DomList;
   savedDomDir := ShippedDomDirOverride;
   ShippedDomDirOverride := ShippedDomDir;
   DomQTHTable := nil;
   mo.DomList := nil;
   session := Default(TMyStationExchange);
   session.MyState := 'ALB';
   try
      CheckTrue(FindContestById('NY-QSO-PARTY', handle), 'New York is registered');
      Contest := handle;
      LoadFresh('newyork_cty.dom');

      facts := NotCapturedMyFacts;
      facts.Source := mfsLogged;
      facts.State := 'ALB';
      CheckTrue(ApplyPartyUnitToMyFacts('alb', facts), 'ALB is a New York unit');
      CheckEquals('NY', string(facts.State), 'my_state is the host state');
      CheckEquals('NY,ALBANY', string(facts.County), 'my_county is Albany county');
      CheckEquals('ALB', string(facts.SentUnit), 'my_sent_unit is what was sent');
      CheckEquals('ALB', Sent(facts, ''), 'and the sent slot still sends ALB, never NY');

      (* THE ROVER TEST'S FOUR ROWS: KIN/QUE working W2BN on CAT/CAY. *)
      facts.State := 'ALB';
      CheckTrue(ApplyPartyUnitToMyFacts('KIN', facts), 'KIN is a New York unit');
      CheckEquals('NY', string(facts.State), 'from KIN: NY');
      CheckEquals('NY,KINGS', string(facts.County), 'from KIN: Kings');
      CheckEquals('KIN', Sent(facts, 'KIN'), 'the KIN rows send KIN (CAT and CAY)');
      CheckTrue(ApplyPartyUnitToMyFacts('QUE', facts), 'QUE is a New York unit');
      CheckEquals('NY,QUEENS', string(facts.County), 'from QUE: Queens');
      CheckEquals('QUE', Sent(facts, 'QUE'), 'the QUE rows send QUE (CAT and CAY)');

      facts := NotCapturedMyFacts;
      facts.Source := mfsLogged;
      facts.State := 'FL';
      CheckFalse(ApplyPartyUnitToMyFacts('FL', facts), 'an out-of-state FL is no unit');
      CheckEquals('FL', string(facts.State), 'and is left as typed');
      CheckEquals('', string(facts.SentUnit), 'with no sent unit');
      CheckEquals('FL', Sent(facts, ''), 'so it sends FL, as ever');

      (* A ROW FROM BEFORE SCHEMA 13: the county code in my_state, no unit. *)
      facts := NotCapturedMyFacts;
      facts.Source := mfsLogged;
      facts.State := 'ALB';
      CheckEquals('ALB', Sent(facts, ''), 'an older row sends its my_state unchanged');

      (* HAWAII: a district is no county; my_county is the county it lies in. *)
      CheckTrue(FindContestById('HI-QSO-PARTY', handle), 'Hawaii is registered');
      Contest := handle;
      LoadFresh('hawaiiqp_cty.dom');
      facts := NotCapturedMyFacts;
      facts.Source := mfsLogged;
      facts.State := 'KOH';
      CheckTrue(ApplyPartyUnitToMyFacts('KOH', facts), 'KOH is a Hawaii unit');
      CheckEquals('HI', string(facts.State), 'a fixed KOH station: my_state HI, not KOH');
      CheckEquals('HI,Hawaii', string(facts.County), 'KOH lies in Hawaii county');
      session.MyState := 'KOH';
      CheckEquals('KOH', Sent(facts, ''), 'and sends KOH');
   finally
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      mo.DomList.Free;
      mo.DomList := savedList;
      ShippedDomDirOverride := savedDomDir;
      Contest := savedContest;
   end;
end;

(* NY4I, 2026-11-20, ruling 6: the call is ASSEMBLED from its parts, never
  stripped -- the call setting as set (it may hold slashes) and the places. *)
procedure TRoverStateTests.Test_TheCallIsAssembledFromTheSettingAndThePlaces;
var
   units: TStringList;
   facts: TQsoMyFacts;
begin
   BeginTest('Test_TheCallIsAssembledFromTheSettingAndThePlaces');
   CheckEquals('VE3FRV/W2/KIN/QUE', AssembledCall('VE3FRV/W2', 'KIN/QUE'),
               'a Canadian in New York on the KIN/QUE line');
   CheckEquals('NY4I/KOH', AssembledCall('NY4I', 'KOH'), 'one place');
   CheckEquals('VE3FRV/W2', AssembledCall('VE3FRV/W2', ''), 'not roving: the setting as set');
   CheckEquals('', AssembledCall('', 'KIN'), 'no call: nothing to sign');

   (* THE TWO EXPORT CALLS OF A STORED ROW (uLogSource). Schema 13: ADIF the
      setting, Cabrillo the assembly. A SCHEMA-12 ROVER ROW -- NY4I's test
      log: my_call NY4I/KIN/QUE as signed, no places -- signs exactly as it
      did in both, and is never suffixed twice. *)
   facts := NotCapturedMyFacts;
   facts.Source := mfsLogged;
   facts.Call := 'VE3FRV/W2';
   facts.RoverPlaces := 'KIN/QUE';
   CheckEquals('VE3FRV/W2', ExportCallFor(facts), 'schema 13: ADIF writes the setting');
   CheckEquals('VE3FRV/W2/KIN/QUE', CabrilloCallFor(facts), 'and Cabrillo the assembly');
   facts.Call := 'NY4I/KIN/QUE';
   facts.RoverPlaces := '';
   CheckEquals('NY4I/KIN/QUE', ExportCallFor(facts), 'schema 12: ADIF as it was');
   CheckEquals('NY4I/KIN/QUE', CabrilloCallFor(facts), 'and Cabrillo as it was, once');

   units := TStringList.Create;
   try
      SplitRoverUnitsText('KIN QUE', units);
      RoverState.SetUnits(units);
      CheckEquals('VE3FRV/W2/KIN/QUE', RovingCall('VE3FRV/W2'),
                  'the call keyed is the same assembly');
   finally
      RoverState.TurnOff;
      units.Free;
   end;
end;

procedure TRoverStateTests.RunAllTests;
begin
   Test_TheThreeSeparatorsAndTheSlashSplitUnits;
   Test_AnUnknownUnitIsNamed;
   Test_TheCountyLineLimitHolds;
   Test_TheStateIsOffUntilSet;
   Test_HawaiiRovesItsFourteenDistrictsTwoAtATime;
   Test_TheDialogTicksWhatIsTypedAndRefusesPastTheLimit;
   Test_TheExportSendsTheRoverPlaceAndMyCountyIsItsCounty;
   Test_ASchema11LogGainsTheRoverColumnInOneCommit;
   Test_TheCallOnTheAirAndTheRoverQTHToken;
   Test_ARoverFromANewPlaceIsNoDupe;
   Test_ABoundaryEntryLogsOneQSOPerPlace;
   Test_MyCountyOfARoverPlaceIsItsADIFCounty;
   Test_TheCountyFileNamesWhatTheListNamed;
   Test_AnInStateSessionNamesItsCounties;
   Test_EveryNewYorkCountyCodeNamesItsADIFCounty;
   Test_EveryFloridaAndTennesseeCountyNamesItsADIFCounty;
   Test_TheOtherSixCountyFilesNameTheirCounties;
   Test_ASchema12LogGainsTheSentUnitColumnsInOneCommit;
   Test_ASchema13LogGainsThePrefectureColumnsInOneCommit;
   Test_AnInStatePartyQSOKeepsTheHostStateAndSendsItsUnit;
   Test_TheCallIsAssembledFromTheSettingAndThePlaces;
end;

end.

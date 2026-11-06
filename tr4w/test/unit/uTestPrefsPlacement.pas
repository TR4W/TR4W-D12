unit uTestPrefsPlacement;
{$I ..\..\src\tr4w.inc}

(*
  WHERE PREFERENCES SHOWS A SETTING -- the placement table of issue 235.

  More settings was a holding page built from nine key prefixes.  Settings leave
  it by being PLACED (uPrefsForm.PrefsPlacements: setting key -> page Tag), never
  by renaming their stored key, so no one's settings file has to migrate.

  WHAT IS PROVED HERE.  The table tests read the placements and the real
  settings registry (DeclareAllSettings): every placed key is a real setting, no
  key has two homes, and every placement names a page that builds rows.  The
  last test BUILDS the real form, against an empty redirected settings folder,
  and reads what TPrefsForm.CheckEveryInventoriedSettingHasOneEditor counted on
  the controls: every More settings or placed setting has exactly one EDITOR
  (a binding or a display-only row).  Geometry is not proved: the form is never
  shown, and position and anchoring are applied only when it is.

  NY4I's decisions on the issue are pinned by name below, so a later edit that
  moves one is a deliberate change to a test rather than a quiet drift.
*)

interface

uses
   uTR4WTestFramework;

type
   TPrefsPlacementTests = class(TTestCase)
   protected
      procedure Test_EveryPlacedKeyIsARegisteredSetting;
      procedure Test_NoKeyIsPlacedTwice;
      procedure Test_EveryPlacementNamesAPageThatIsBuilt;
      procedure Test_EveryInventoriedSettingHasExactlyOneHome;
      procedure Test_TheApprovedMovesArePinned;
      procedure Test_CWHasOneHome;
      procedure Test_TheSpecialCasesAreWhereTheyWereSent;
      procedure Test_PlaceRefusesASecondHome;
      procedure Test_TheBuiltFormHasOneEditorPerSetting;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   Forms,
   Controls,
   uLCLFormHelpers,       (* TNavNode -- the tree's tagged nodes *)
   uPrefsForm,
   uSettingsRegistry,
   uSettingsLegacy,       (* ActiveStoreProvider -- the form sets and clears it *)
   uSettingsDeclarations,
   uTR4WConfigFile,       (* TR4WConfigFileName -- proof the redirect landed *)
   uFileText,             (* TempDirectory, CombinePath, DeleteFileIfExists *)
   utils_text,            (* CharBufferText, SetCharBuffer *)
   VC;                    (* TR4W_INI_FILENAME *)

const
   (* The tag the More settings page carried until issue 235 removed it.  A
     literal on purpose: the constant is gone, and that is what is pinned. *)
   RETIRED_MORE_SETTINGS_TAG = 30;

(* The page a key is placed on, as an integer for CheckEquals: NativeInt is
  64-bit on the Unix targets. *)
function PlacedPage(const aKey: string): integer;
begin
   Result := integer(PrefsPlacements.PageOf(aKey));
end;

(* Every test needs the registry; DeclareAllSettings is idempotent. *)
procedure Declared;
begin
   DeclareAllSettings;
end;

procedure TPrefsPlacementTests.Test_EveryPlacedKeyIsARegisteredSetting;
var
   i: integer;
begin
   BeginTest('every placed key is a registered setting');
   Declared;

   CheckTrue(PrefsPlacements.Count > 0, 'the placement table is empty');
   (* A refused Place leaves nothing in the table to find, so the count is
     the only evidence of a key placed twice in DeclarePrefsPlacements. *)
   CheckEquals(0, PrefsPlacements.Refused,
               'DeclarePrefsPlacements made a placement Place refused -- see tr4w.log');
   for i := 0 to PrefsPlacements.Count - 1 do
      begin
      (* A mistyped key would place nothing and leave the real setting on More
        settings -- or, worse, nowhere a reviewer would look. *)
      CheckTrue(FindSetting(PrefsPlacements.Key(i)) <> nil,
                '"' + PrefsPlacements.Key(i) + '" is placed but is not a registered setting');
      end;
end;

procedure TPrefsPlacementTests.Test_NoKeyIsPlacedTwice;
var
   i, j: integer;
begin
   BeginTest('no key is placed twice');
   for i := 0 to PrefsPlacements.Count - 1 do
      begin
      for j := i + 1 to PrefsPlacements.Count - 1 do
         begin
         CheckFalse(UnicodeSameText(PrefsPlacements.Key(i), PrefsPlacements.Key(j)),
                    '"' + PrefsPlacements.Key(i) + '" is placed twice');
         end;
      end;
end;

procedure TPrefsPlacementTests.Test_EveryPlacementNamesAPageThatIsBuilt;
var
   i: integer;
   page: NativeInt;
begin
   BeginTest('every placement names a page BuildGeneratedSections builds');

   (* THE PAGES THAT BUILD PLACED ROWS: TPrefsForm.BuildGeneratedSections calls
     BuildPlacedSection or BuildPlacedBlock for exactly these.  A placement on
     any other page would build no row at all, and the setting would vanish
     from Preferences.  Adding a destination means adding its builder call
     there AND its tag here. *)
   for i := 0 to PrefsPlacements.Count - 1 do
      begin
      page := PrefsPlacements.Page(i);
      CheckTrue((page = NAV_MESSAGES)      or
                (page = NAV_ENTRY)         or
                (page = NAV_CWCHARACTERS)  or
                (page = NAV_PRINTEDLOG)    or
                (page = NAV_LOGDISPLAY)    or
                (page = NAV_FILES)         or
                (page = NAV_BANDMAPWINDOW) or
                (page = NAV_CLUSTERSPOTS)  or
                (page = NAV_BANDMAP)       or
                (page = NAV_HARDWARE)      or
                (page = NAV_STATION)       or
                (page = NAV_SCP)           or
                (page = NAV_NETWORK)       or
                (page = NAV_AUDIO)         or
                (page = NAV_TWORADIO)      or
                (page = NAV_BANDS)         or
                (page = NAV_CONTEST)       or
                (page = NAV_ADVANCED),
                '"' + PrefsPlacements.Key(i) + '" is placed on page ' + IntToStr(page)
                + ', which builds no placed rows');
      CheckTrue(page <> RETIRED_MORE_SETTINGS_TAG,
                '"' + PrefsPlacements.Key(i) + '" is placed on tag 30, the retired More settings page');
      end;
end;

procedure TPrefsPlacementTests.Test_EveryInventoriedSettingHasExactlyOneHome;
var
   s: TSettingBase;
   inventory, placed, held: integer;
begin
   BeginTest('every setting More settings was built from is placed on a task page');
   Declared;

   (* THE RECONCILIATION THE ISSUE ASKED FOR, against the RUNTIME registry
     rather than a source scan: walk what DeclareAllSettings registered. *)
   inventory := 0;
   placed    := 0;
   held      := 0;
   for s in AllSettings do
      begin
      if not IsHoldingPageKey(s.Key) then
         begin
         Continue;
         end;
      Inc(inventory);
      if PlacedPage(s.Key) <> NAV_NONE then
         begin
         Inc(placed);
         end
      else
         begin
         Inc(held);
         end;
      end;

   CheckTrue(inventory > 0,
             'no registered setting carries a More settings prefix -- did DeclareAllSettings run?');
   (* MORE SETTINGS IS GONE, so an unplaced one would have no editor at all.
     The proof of exactly one EDITOR each is the built-form test below. *)
   CheckEquals(0, held, IntToStr(held) + ' of ' + IntToStr(inventory)
                        + ' former More settings setting(s) are placed nowhere');
   CheckEquals(inventory, placed, 'every former More settings setting is placed');
   CheckFalse(IsHoldingPageKey('voice.ctrlj.anything'),
              'voice.ctrlj. is not an inventory prefix: no setting ever carried it (no empty Voice page)');
end;

procedure TPrefsPlacementTests.Test_TheApprovedMovesArePinned;
begin
   BeginTest('NY4I''s placements on issue 235 are where he put them');

   CheckEquals(NAV_MESSAGES,   PlacedPage('operating.ctrlj.deEnable'),
               'DE ENABLE belongs on Operating > Messages (answer 2)');
   CheckEquals(NAV_BANDMAP,    PlacedPage('operating.ctrlj.ieSwitch'),
               'IE SWITCH belongs with the band map (answer 3)');
   CheckEquals(NAV_HARDWARE,   PlacedPage('hardware.ctrlj.stereoPinHigh'),
               'STEREO PIN HIGH belongs on hardware (answer 4)');
   CheckEquals(NAV_PRINTEDLOG, PlacedPage('operating.ctrlj.logSubTitle'),
               'LOG SUB TITLE belongs with the printed log (answer 5)');
   CheckEquals(NAV_PRINTEDLOG, PlacedPage('appearance.ctrlj.contactsPerPage'),
               'CONTACTS PER PAGE is the other printed-log page setting');
end;

procedure TPrefsPlacementTests.Test_CWHasOneHome;
var
   s: TSettingBase;
begin
   BeginTest('every CW sending setting is under CW Settings (answer 1)');
   Declared;

   (* EVERY cw.ctrlj. SETTING BUT ONE goes to CW Settings > Speed and
     characters.  TUNE ALT-D ENABLE is the exception, and not a CW setting: it
     enters band-map calls while you tune the inactive radio. *)
   for s in AllSettings do
      begin
      if not UnicodeSameText(Copy(s.Key, 1, Length('cw.ctrlj.')), 'cw.ctrlj.') then
         begin
         Continue;
         end;
      if UnicodeSameText(s.Key, 'cw.ctrlj.tuneAltDEnable') then
         begin
         Continue;
         end;
      CheckEquals(NAV_CWCHARACTERS, PlacedPage(s.Key),
                  '"' + s.Key + '" is CW and must live under CW Settings');
      end;

   (* AND THE ONE CW-ONLY BOX THE OPERATING PAGE HAD: AUTO CALL TERMINATE acts
     only with the two auto-send settings above. *)
   CheckEquals(NAV_CWCHARACTERS, PlacedPage('operating.autoCallTerminate'),
               'AUTO CALL TERMINATE is CW-only and must live under CW Settings');
end;

procedure TPrefsPlacementTests.Test_TheSpecialCasesAreWhereTheyWereSent;
var
   s: TSettingBase;
begin
   BeginTest('the settings with a stated exception are where the coordinator and NY4I sent them');
   Declared;

   (* FREQUENCY POLL RATE: TEMPORARY, on Hardware, until it moves to each
     radio's definition (issue 235 step 3).  Still one global value. *)
   CheckEquals(NAV_HARDWARE, PlacedPage('operating.ctrlj.frequencyPollRate'),
               'FREQUENCY POLL RATE sits on Hardware until it moves to the radio definition');
   (* DIGITAL MODE ENABLE is contest-scoped and goes on the Contest page. *)
   CheckEquals(NAV_CONTEST, PlacedPage('operating.ctrlj.digitalModeEnable'),
               'DIGITAL MODE ENABLE goes on the Contest page');
   (* DOMESTIC FILENAME is shown, never edited: the contest sets it. *)
   CheckEquals(NAV_CONTEST, PlacedPage('files.ctrlj.domesticFilename'),
               'DOMESTIC FILENAME goes on the Contest page');
   s := FindSetting('files.ctrlj.domesticFilename');
   CheckTrue((s <> nil) and s.ReadOnly, 'DOMESTIC FILENAME stays read-only');
   (* TUNE ALT-D ENABLE is SO2R: it fills calls while tuning the other radio. *)
   CheckEquals(NAV_TWORADIO, PlacedPage('cw.ctrlj.tuneAltDEnable'),
               'TUNE ALT-D ENABLE goes with Two Radio Mode');
end;

procedure TPrefsPlacementTests.Test_PlaceRefusesASecondHome;
var
   t: TPrefsPlacements;
begin
   BeginTest('a second home for one setting is refused');

   t := TPrefsPlacements.Create;
   try
      CheckTrue(t.Place('test.key', NAV_MESSAGES), 'a first placement is accepted');
      CheckFalse(t.Place('TEST.KEY', NAV_BANDMAP),
                 'a second placement of the same key (any case) is refused');
      CheckEquals(NAV_MESSAGES, integer(t.PageOf('test.key')),
                  'the refused placement does not move the key');
      CheckFalse(t.Place('other.key', NAV_NONE), 'a placement on no page is refused');
      CheckEquals(1, t.Count, 'only the first placement was kept');
      CheckEquals(NAV_NONE, integer(t.PageOf('never.placed')), 'an unplaced key reads NAV_NONE');
   finally
      t.Free;
   end;
end;

(* True when a control named aName is anywhere inside aRoot. *)
function HasDescendantNamed(const aRoot: TWinControl; const aName: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := 0 to aRoot.ControlCount - 1 do
      begin
      if UnicodeSameText(aRoot.Controls[i].Name, aName) then
         begin
         Result := True;
         Exit;
         end;
      if (aRoot.Controls[i] is TWinControl) and
         HasDescendantNamed(TWinControl(aRoot.Controls[i]), aName) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* THE REAL FORM, BUILT: exactly one editor per setting, counted on the
  controls rather than the table.  The settings file is REDIRECTED to an empty
  temp folder first, and the test refuses to build the form unless
  TR4WConfigFileName really landed there (a --settings switch wins over the
  redirect).  Nothing is saved: the form is only constructed and freed. *)
procedure TPrefsPlacementTests.Test_TheBuiltFormHasOneEditorPerSetting;
var
   oldIni, dir, fn: string;
   oldProvider: TActiveStoreProvider;
   form: TPrefsForm;
   i: integer;
begin
   BeginTest('the built Preferences form has exactly one editor per placed or More settings setting');
   if Application <> nil then
      begin
      Application.Initialize;
      end;

   oldIni      := CharBufferText(TR4W_INI_FILENAME);
   oldProvider := uSettingsLegacy.ActiveStoreProvider;
   dir  := CombinePath(TempDirectory, 'tr4wprefs_' + TGUID.NewGuid.ToString);
   form := nil;
   try
      SetCharBuffer(TR4W_INI_FILENAME, CombinePath(dir, 'tr4w.ini'));
      fn := TR4WConfigFileName;
      if Pos(dir, fn) <> 1 then
         begin
         CheckTrue(False, 'the settings file was not redirected (' + fn +
                          ') -- a --settings switch? The form is not built');
         Exit;
         end;

      form := TPrefsForm.Create(nil);
      CheckTrue(form.EditorsChecked > 0,
                'the editor count never ran, so an empty fault list proves nothing');
      CheckEquals('', form.EditorFaults,
                  'settings without exactly one editor (count in brackets)');

      (* MORE SETTINGS IS GONE: no section panel and no navigation entry
        answers to its tag. *)
      for i := 0 to form.layContent.ControlCount - 1 do
         begin
         CheckTrue(form.layContent.Controls[i].Tag <> RETIRED_MORE_SETTINGS_TAG,
                   'a section panel still carries the More settings tag');
         end;
      for i := 0 to form.tvNav.Items.Count - 1 do
         begin
         CheckTrue(TNavNode(form.tvNav.Items[i]).Tag <> RETIRED_MORE_SETTINGS_TAG,
                   'a navigation entry still opens the More settings tag ('
                   + form.tvNav.Items[i].Text + ')');
         end;

      (* AND THE BAND PLAN'S EDIT... BUTTON MOVED, not vanished: it is on the
        Bands page, the only way into the band plan editor from Preferences. *)
      CheckTrue(HasDescendantNamed(form.layBands, 'gen_bandPlanEdit'),
                'the band plan Edit... button is on the Bands page');
   finally
      form.Free;
      uSettingsLegacy.ActiveStoreProvider := oldProvider;
      SetCharBuffer(TR4W_INI_FILENAME, oldIni);
      if DirectoryExists(dir) then
         begin
         DeleteFileIfExists(CombinePath(dir, 'tr4w.json'));
         RemoveDir(dir);
         end;
   end;
end;

procedure TPrefsPlacementTests.RunAllTests;
begin
   Test_EveryPlacedKeyIsARegisteredSetting;
   Test_NoKeyIsPlacedTwice;
   Test_EveryPlacementNamesAPageThatIsBuilt;
   Test_EveryInventoriedSettingHasExactlyOneHome;
   Test_TheApprovedMovesArePinned;
   Test_CWHasOneHome;
   Test_TheSpecialCasesAreWhereTheyWereSent;
   Test_PlaceRefusesASecondHome;
   Test_TheBuiltFormHasOneEditorPerSetting;
end;

end.

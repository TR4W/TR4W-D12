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
   uTR4WTestFramework,
   uPrefsForm;            (* TPrefsForm -- the overview check takes one *)

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
      procedure Test_TheContestLeavesHoldTheirRows;
      procedure Test_PlaceRefusesASecondHome;
      procedure Test_TheBuiltFormHasOneEditorPerSetting;
      procedure CheckHeadingOverviews(const aForm: TPrefsForm);
      procedure CheckKeyersUnderHardware(const aForm: TPrefsForm);
      procedure CheckLicenseYearHasItsOwnBox(const aForm: TPrefsForm);
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   Forms,
   Controls,
   ComCtrls,              (* TTreeNode *)
   uLCLFormHelpers,       (* TNavNode -- the tree's tagged nodes *)
   uSettingsRegistry,
   uSettingsLegacy,       (* ActiveStoreProvider -- the form sets and clears it *)
   uSettingsDeclarations,
   uTR4WConfigFile,       (* TR4WConfigFileName -- proof the redirect landed *)
   uFileText,             (* TempDirectory, CombinePath, DeleteFileIfExists *)
   utils_text,            (* CharBufferText, SetCharBuffer *)
   uCommandHelp,          (* TCommandHelp -- the License year command's own help *)
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
                (page = NAV_CONTESTQTC)       or
                (page = NAV_CONTESTQSO)       or
                (page = NAV_CONTESTQUICKQSL)  or
                (page = NAV_CONTESTMODES)     or
                (page = NAV_CONTESTINITIALEX) or
                (page = NAV_CONTESTMULTS)     or
                (page = NAV_CONTESTCABRILLO)  or
                (page = NAV_CONTESTRULES)     or
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

   (* FREQUENCY POLL RATE LEFT PREFERENCES (issue 235 step 3): it is a field
     of each radio definition, edited in the radio editor. Neither a
     registration nor a placement may come back for the old key. *)
   CheckTrue(FindSetting('operating.ctrlj.frequencyPollRate') = nil,
             'FREQUENCY POLL RATE is no longer a Preferences setting');
   CheckTrue(PrefsPlacements.PageOf('operating.ctrlj.frequencyPollRate') =
                PrefsPlacements.PageOf('no.such.setting'),
             'and nothing places it on a page');
   (* DIGITAL MODE ENABLE is contest-scoped and goes on Contest > Modes. *)
   CheckEquals(NAV_CONTESTMODES, PlacedPage('operating.ctrlj.digitalModeEnable'),
               'DIGITAL MODE ENABLE goes on Contest > Modes');
   (* DOMESTIC FILENAME is shown, never edited: the contest sets it. *)
   CheckEquals(NAV_CONTESTMULTS, PlacedPage('files.ctrlj.domesticFilename'),
               'DOMESTIC FILENAME goes on Contest > Multiplier data');
   s := FindSetting('files.ctrlj.domesticFilename');
   CheckTrue((s <> nil) and s.ReadOnly, 'DOMESTIC FILENAME stays read-only');
   (* TUNE ALT-D ENABLE is SO2R: it fills calls while tuning the other radio. *)
   CheckEquals(NAV_TWORADIO, PlacedPage('cw.ctrlj.tuneAltDEnable'),
               'TUNE ALT-D ENABLE goes with Two Radio Mode');
end;

(* THE CONTEST PAGE, SPLIT INTO LEAVES (NY4I): every key on its leaf, and the
  three that feed only General QSO's Cabrillo CONTEST: line -- or the contest
  selection itself -- left on the Contest page. *)
procedure TPrefsPlacementTests.Test_TheContestLeavesHoldTheirRows;

   procedure Pin(const aPage: NativeInt; const aKeys: array of string);
   var
      k: string;
   begin
      for k in aKeys do
         begin
         CheckEquals(integer(aPage), PlacedPage(k), '"' + k + '" is on the wrong Contest leaf');
         end;
   end;

begin
   BeginTest('the Contest page''s settings are on the Contest leaves NY4I named');
   Declared;

   Pin(NAV_CONTESTQTC, ['contest.qtcEnable', 'contest.qtcExtraSpace',
                        'contest.qtcMinutes', 'contest.qtcQrs']);
   Pin(NAV_CONTESTQSO, ['contest.qsoByBand', 'contest.qsoByMode',
                        'contest.qsoNumberByBand', 'contest.qsoPointsDomesticCw',
                        'contest.qsoPointsDomesticPhone', 'contest.qsoPointsDxCw',
                        'contest.qsoPointsDxPhone']);
   Pin(NAV_CONTESTQUICKQSL, ['contest.quickQslCwMessage', 'contest.quickQslSsbMessage',
                             'contest.quickQslKey1', 'contest.quickQslKey2',
                             'contest.quickQslMessage2', 'contest.qslMode',
                             'contest.autoQslInterval']);
   Pin(NAV_CONTESTMODES, ['operating.ctrlj.digitalModeEnable', 'contest.multipleModes']);
   Pin(NAV_CONTESTINITIALEX, ['files.ctrlj.initialExchangeFilename',
                              'files.ctrlj.useCallHistoryFile',
                              'files.ctrlj.callHistoryFilename',
                              'contest.customInitialExchangeString',
                              'contest.initialExchangeCursorPos',
                              'contest.initialExchangeOverwrite',
                              'contest.reverseInitialEx',
                              'contest.exchangeMemoryEnable']);
   Pin(NAV_CONTESTMULTS, ['files.ctrlj.domesticFilename', 'contest.multByBand',
                          'contest.multByMode', 'contest.multSheetAutoReset',
                          'contest.multReportMinimumBands',
                          'contest.remainingMultDisplayMode',
                          'contest.countDomesticCountries',
                          'contest.showDomesticMultiplierName',
                          'contest.literalDomesticQth']);
   Pin(NAV_CONTESTCABRILLO, ['contest.categoryAssisted', 'contest.categoryBand',
                             'contest.categoryMode', 'contest.categoryOperator',
                             'contest.categoryOverlay', 'contest.categoryPower',
                             'contest.categoryTransmitter']);
   Pin(NAV_CONTESTRULES, ['contest.minitourDuration', 'contest.r150sMode',
                          'contest.rfoblMode', 'contest.sprintQsyRule',
                          'contest.tenMinuteRule', 'contest.singleBandScore',
                          'contest.multipleBands']);

   (* UNPLACED, so the Contest page builds them by prefix. *)
   Pin(NAV_NONE, ['contest.contest', 'contest.contestName', 'contest.contestTitle']);
   CheckTrue(FindSetting('contest.contestTitle') <> nil,
             'CONTEST TITLE is still a registered setting, so the Contest page shows it');
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

(* True when some section panel (a child of layContent) carries aTag. *)
function HasSectionPanel(const aForm: TPrefsForm; const aTag: NativeInt): boolean;
var
   i: integer;
begin
   Result := False;
   for i := 0 to aForm.layContent.ControlCount - 1 do
      begin
      if aForm.layContent.Controls[i].Tag = aTag then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* A HEADING WITH NO PANEL SHOWS AN OVERVIEW (NY4I): one link per child,
  captioned and tagged from the tree, and a link opens its child.  Every such
  heading in the real tree is checked, so a new one is covered unasked; at
  least one must exist (External Software), or this proves nothing. *)
procedure TPrefsPlacementTests.CheckHeadingOverviews(const aForm: TPrefsForm);
var
   i, k, headings: integer;
   node, child: TTreeNode;
   links: array of TPrefsOverviewLink;
begin
   headings := 0;
   for i := 0 to aForm.tvNav.Items.Count - 1 do
      begin
      node := aForm.tvNav.Items[i];
      if (not node.HasChildren) or HasSectionPanel(aForm, TNavNode(node).Tag) then
         begin
         Continue;
         end;
      Inc(headings);

      node.Selected := True;
      aForm.tvNavChange(aForm.tvNav);

      CheckTrue((aForm.ParentOverview <> nil) and aForm.ParentOverview.Visible,
                node.Text + ': a heading with no panel shows its overview');
      if aForm.ParentOverview = nil then
         begin
         Continue;
         end;

      (* The VISIBLE links: a previous heading's are hidden and released. *)
      links := nil;
      for k := 0 to aForm.ParentOverview.ControlCount - 1 do
         begin
         if (aForm.ParentOverview.Controls[k] is TPrefsOverviewLink) and
            aForm.ParentOverview.Controls[k].Visible then
            begin
            SetLength(links, Length(links) + 1);
            links[High(links)] := TPrefsOverviewLink(aForm.ParentOverview.Controls[k]);
            end;
         end;

      CheckEquals(node.Count, Length(links), node.Text + ': one link per child page');
      child := node.GetFirstChild;
      k := 0;
      while (child <> nil) and (k < Length(links)) do
         begin
         CheckEquals(child.Text, links[k].Caption, node.Text + ': link caption is the child''s');
         CheckEquals(integer(TNavNode(child).Tag), integer(links[k].PageTag),
                     node.Text + ': link opens the child''s page');
         CheckTrue(links[k].TabStop, node.Text + ': a link is reachable by Tab');
         child := child.GetNextSibling;
         Inc(k);
         end;

      if Length(links) > 0 then
         begin
         links[0].Click;
         CheckTrue(aForm.tvNav.Selected = node.GetFirstChild,
                   node.Text + ': clicking a link selects its child in the tree');
         end;
      end;

   CheckTrue(headings > 0, 'no heading without a panel was found -- External Software has none');
end;

(* ISSUE 264: THE KEYER LIBRARY IS HARDWARE, AND SEARCH FINDS IT.  NY4I typed
  "winkey" and got nothing, and looked for a WinKeyer under Hardware.  So: the
  library's page is a child of Hardware, its list is on that page, CW Settings
  keeps what TR4W sends, and each word NY4I named -- plus WinKeyer settings
  from the keyer editor -- lists a row that lands on the library. *)
procedure TPrefsPlacementTests.CheckKeyersUnderHardware(const aForm: TPrefsForm);
const
   NEEDLES: array[0..8] of string =
      ('winkey', 'winkeyer', 'WK', 'keyer', 'YCCC',
       'switchpoint', 'paddle-only sidetone', 'keyer weight', 'lead-in');
var
   i: integer;
   node: TTreeNode;
   panel: TControl;
begin
   node := nil;
   for i := 0 to aForm.tvNav.Items.Count - 1 do
      begin
      if TNavNode(aForm.tvNav.Items[i]).Tag = NAV_KEYERS then
         begin
         node := aForm.tvNav.Items[i];
         Break;
         end;
      end;
   CheckTrue(node <> nil, 'a navigation entry opens the keyer library (NAV_KEYERS)');
   if node = nil then
      begin
      Exit;
      end;
   CheckTrue((node.Parent <> nil) and (TNavNode(node.Parent).Tag = NAV_HARDWARE),
             'the keyer library is a child of Hardware');

   panel := aForm.lstKeyers.Parent;
   CheckTrue(panel = aForm.layKeyers, 'the keyer list is on its own page');
   CheckEquals(NAV_KEYERS, integer(aForm.layKeyers.Tag), 'that page answers to NAV_KEYERS');
   CheckTrue(aForm.chkCWEnable.Parent = aForm.layCW,
             'CW Settings keeps the sending settings');
   CheckEquals(NAV_CW, integer(aForm.layCW.Tag), 'CW Settings keeps its tag');

   for i := Low(NEEDLES) to High(NEEDLES) do
      begin
      CheckTrue(aForm.SearchFinds(NEEDLES[i], aForm.lstKeyers),
                'searching "' + NEEDLES[i] + '" lists the keyer library');
      end;
   CheckFalse(aForm.SearchFinds('winkey zzz', aForm.lstKeyers),
              'a word nothing carries still empties the result');
end;

(* THE LICENSE YEAR HAS A BOX OF ITS OWN (issue 298). It was the MY ZONE box
  relabelled by the open contest, with a tooltip swapped in beside it; the year
  is its own setting now, so MY ZONE is a CQ zone in every contest and nothing
  here follows the contest. The two boxes are separate controls, the zone's
  words are the .lfm's, and the year's box is a station field (read and saved
  with the rest of the page) whose command has English help in the catalogue
  the installer ships as help\help_en.po -- read from the repository's i18n
  directory, as TestEveryRegisteredSettingHasHelp reads it. *)
procedure TPrefsPlacementTests.CheckLicenseYearHasItsOwnBox(const aForm: TPrefsForm);
var
   path: string;
   help: TCommandHelp;
begin
   CheckTrue((aForm.lblMyLicenseYear <> nil) and (aForm.edtMyLicenseYear <> nil),
             'the Station page has a License year label and box');
   CheckTrue(aForm.edtMyLicenseYear <> aForm.edtMyZone,
             'the year is not the zone box relabelled');
   CheckEquals('License year:', string(aForm.lblMyLicenseYear.Caption),
               'the year''s label');
   CheckEquals('CQ zone:', string(aForm.lblMyZone.Caption),
               'the zone''s label does not follow the contest');

   path := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim +
           '..' + PathDelim + '..' + PathDelim + 'i18n');
   help := TCommandHelp.Create(path, 'en');
   try
      CheckTrue(help.Describe('MY LICENSE YEAR') <> '',
                'MY LICENSE YEAR has help in help_en.po');
      CheckTrue(help.Describe('MY LICENSE YEAR') <> help.Describe('MY ZONE'),
                'and it is not the zone''s');
   finally
      help.Free;
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

      CheckHeadingOverviews(form);
      CheckKeyersUnderHardware(form);

      CheckLicenseYearHasItsOwnBox(form);
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
   Test_TheContestLeavesHoldTheirRows;
   Test_PlaceRefusesASecondHome;
   Test_TheBuiltFormHasOneEditorPerSetting;
end;

end.

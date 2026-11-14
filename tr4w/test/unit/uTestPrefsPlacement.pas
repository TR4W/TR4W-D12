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
   Controls,              (* TWinControl -- the generated-caption walk *)
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
      procedure Test_StationBoxesCarryTheirHelpTooltips;
      procedure CheckHeadingOverviews(const aForm: TPrefsForm);
      procedure CheckEmptyLeavesSaySo(const aForm: TPrefsForm);
      procedure CheckKeyersUnderHardware(const aForm: TPrefsForm);
      procedure CheckLicenseYearHasItsOwnBox(const aForm: TPrefsForm);
      procedure CheckBoundControlsAreNamed(const aForm: TPrefsForm);
      procedure CheckStationCaptionsAreWindowsBeforeTheirInputs(const aForm: TPrefsForm);
      function CheckGeneratedLabelsFit(const aRoot: TWinControl): integer;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
{$IFDEF WINDOWS}
   (* FIRST, so it shadows nothing below (it declares its own CopyFile).
     GetWindow, GW_HWNDPREV/NEXT: see the z-order check. *)
   Windows,
   uInputCaptionWin32,    (* TWin32WSInputCaption -- the z-order check, issue 278 *)
{$ENDIF}
   SysUtils,
   Forms,
   StdCtrls,              (* TLabel -- the generated captions *)
   ComCtrls,              (* TTreeNode *)
   uLCLFormHelpers,       (* TNavNode -- the tree's tagged nodes; TextWidthInFont,
                             WrappedTextHeight -- the caption check *)
   uSettingsRegistry,
   uSettingsLegacy,       (* ActiveStoreProvider -- the form sets and clears it *)
   uSettingsDeclarations,
   uTR4WConfigFile,       (* TR4WConfigFileName -- proof the redirect landed *)
   uFileText,             (* TempDirectory, CombinePath, DeleteFileIfExists *)
   utils_text,            (* CharBufferText, SetCharBuffer *)
   uCommandHelp,          (* TCommandHelp -- the License year command's own help *)
   uAppStrings,           (* SPrefsPageHasNoSettingsYet -- issue 279 *)
   uSettingsBinding,      (* CaptionOfLabelFor -- issue 278 *)
   FileUtil,              (* CopyFile, DeleteDirectory -- the staged help, issue 280 *)
   Classes,               (* TFPList -- the Station page's tab order *)
   uTestShowOffScreen,    (* ShowOffScreen -- handles exist only once shown *)
   uInputCaption,         (* TInputCaption -- the Station captions, issue 278 *)
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

(* The first label anywhere inside aRoot paired (FocusControl) with an
  enabled GENERATED control of class aClass -- a bound generated row, for the
  issue 278 checks. Enabled, because a row the contest sets is a disabled
  edit that is not bound. *)
function FirstPairedLabel(const aRoot: TWinControl; const aClass: TControlClass): TLabel;
var
   i: integer;
   paired: TWinControl;
begin
   Result := nil;
   for i := 0 to aRoot.ControlCount - 1 do
      begin
      paired := nil;
      if aRoot.Controls[i] is TLabel then
         begin
         paired := TLabel(aRoot.Controls[i]).FocusControl;
         end;
      if (paired <> nil) and (paired is aClass) and paired.Enabled and
         (Pos('gen_', paired.Name) = 1) then
         begin
         Result := TLabel(aRoot.Controls[i]);
         Exit;
         end;
      if aRoot.Controls[i] is TWinControl then
         begin
         Result := FirstPairedLabel(TWinControl(aRoot.Controls[i]), aClass);
         if Result <> nil then
            begin
            Exit;
            end;
         end;
      end;
end;

(* ISSUE 304: EVERY GENERATED ROW'S CAPTION FITS ITS COLUMN, or wraps in it
  and its row grows. A generated row's control is named gen_<key> and its
  caption is the label whose FocusControl it is. Measured by TEXT width, not
  by the label's Width: an AutoSize label has no handle here, so its Width is
  still the column's, and the defect only shows once it is sized on screen.
  Returns how many generated labels it judged. *)
function TPrefsPlacementTests.CheckGeneratedLabelsFit(const aRoot: TWinControl): integer;
var
   i, k: integer;
   lbl, other: TLabel;
   wrapped: integer;
begin
   Result := 0;
   for i := 0 to aRoot.ControlCount - 1 do
      begin
      if aRoot.Controls[i] is TWinControl then
         begin
         Result := Result +
                   CheckGeneratedLabelsFit(TWinControl(aRoot.Controls[i]));
         end;

      if not (aRoot.Controls[i] is TLabel) then
         begin
         Continue;
         end;
      lbl := TLabel(aRoot.Controls[i]);
      if (lbl.FocusControl = nil) or
         (Pos('gen_', string(lbl.FocusControl.Name)) <> 1) then
         begin
         Continue;
         end;

      Inc(Result);
      CheckTrue(lbl.Left + lbl.Width <= lbl.FocusControl.Left,
                      'the caption column ends before ' + lbl.FocusControl.Name);
      if TextWidthInFont(lbl.Font, lbl.Caption) <= lbl.Width then
         begin
         Continue;
         end;

      wrapped := WrappedTextHeight(lbl.Font, lbl.Caption, lbl.Width);
      WriteLn('  [Prefs] wrapped caption (', lbl.Height, ' px, needs ', wrapped,
              '): ', string(lbl.Caption));
      CheckTrue(lbl.WordWrap and (not lbl.AutoSize),
                      '"' + string(lbl.Caption) + '" is wider than its column, so it wraps');
      CheckTrue(lbl.Height >= wrapped,
                      '"' + string(lbl.Caption) + '" is as tall as it wraps (' +
                      IntToStr(lbl.Height) + ' < ' + IntToStr(wrapped) + ')');
      for k := 0 to aRoot.ControlCount - 1 do
         begin
         if (aRoot.Controls[k] is TLabel) and (aRoot.Controls[k] <> lbl) then
            begin
            other := TLabel(aRoot.Controls[k]);
            if other.Top > lbl.Top then
               begin
               CheckTrue(other.Top >= lbl.Top + lbl.Height,
                               'the row after "' + string(lbl.Caption) +
                               '" starts below its wrapped caption');
               end;
            end;
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

(* ISSUE 279: A LEAF WITH NO PAGE SAYS SO, AND POINTS NOWHERE.  It read "Use the
  existing configuration screens for it", which named no screen; Web Server --
  TR4W has no web server -- is the leaf that showed it.  Every panel-less leaf
  in the real tree is opened, so a new one is covered unasked. *)
procedure TPrefsPlacementTests.CheckEmptyLeavesSaySo(const aForm: TPrefsForm);
var
   i, leaves: integer;
   node: TTreeNode;
   shown: string;
begin
   leaves := 0;
   for i := 0 to aForm.tvNav.Items.Count - 1 do
      begin
      node := aForm.tvNav.Items[i];
      if node.HasChildren or HasSectionPanel(aForm, TNavNode(node).Tag) then
         begin
         Continue;
         end;
      Inc(leaves);

      node.Selected := True;
      aForm.tvNavChange(aForm.tvNav);

      shown := string(aForm.lblPlaceholder.Caption);
      CheckTrue(aForm.lblPlaceholder.Visible,
                node.Text + ': a leaf with no page shows the placeholder');
      CheckEquals(SPrefsPageHasNoSettingsYet, shown,
                  node.Text + ': the placeholder says the page holds nothing');
      CheckEquals(0, Pos('existing configuration', shown),
                  node.Text + ': and names no other screen');
      end;

   (* Web Server is such a leaf today; when it gains a page, this count may
     fall to zero, and that is the right time to revisit this check. *)
   CheckTrue(leaves > 0, 'no leaf without a page was found -- Web Server had none');
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
      CheckEmptyLeavesSaySo(form);
      CheckKeyersUnderHardware(form);

      CheckLicenseYearHasItsOwnBox(form);

      CheckTrue(CheckGeneratedLabelsFit(form) > 0,
                'the generated captions were found and judged (issue 304)');

      (* Last: it SHOWS the form, which the checks above do not need. *)
      CheckStationCaptionsAreWindowsBeforeTheirInputs(form);
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

(* ISSUE 278: A BOUND CONTROL IS NAMED, by the binding route.  A designed
  check box by its own caption; a generated row's edit and check box by the
  label beside it (the registered caption, which is what that label shows).

  THIS PROVES THE LCL PROPERTIES ONLY.  Whether an accessibility client SEES
  AccessibleName is the widget set's business, and on Lazarus 4.8 win32, gtk2
  and cocoa register no accessible object -- a running program answers that,
  not this test. *)
procedure TPrefsPlacementTests.CheckBoundControlsAreNamed(const aForm: TPrefsForm);
var
   lbl: TLabel;
   expected: string;
begin
   CheckEquals('Send a greeting to stations worked before',
               string(aForm.chkSayHiEnable.AccessibleName),
               'a designed check box is named by its own caption');

   lbl := FirstPairedLabel(aForm, TEdit);
   CheckTrue(lbl <> nil, 'a generated edit row was found');
   if lbl <> nil then
      begin
      expected := Trim(string(lbl.Caption));
      CheckTrue(expected <> '', 'the generated edit''s label has a caption');
      CheckEquals(expected, string(lbl.FocusControl.AccessibleName),
                  lbl.FocusControl.Name + ': a generated edit is named by its label');
      end;

   lbl := FirstPairedLabel(aForm, TCheckBox);
   CheckTrue(lbl <> nil, 'a generated check box row was found');
   if lbl <> nil then
      begin
      expected := Trim(string(lbl.Caption));
      CheckTrue(expected <> '', 'the generated check box''s label has a caption');
      CheckEquals(expected, string(lbl.FocusControl.AccessibleName),
                  lbl.FocusControl.Name + ': a generated check box (blank caption) '
                  + 'is named by its label');
      end;
end;

(* ISSUE 278: EVERY STATION INPUT IS NAMED BY A WINDOW IMMEDIATELY BEFORE IT.

  Windows UI Automation ignores the LCL's AccessibleName (the win32 widget set
  registers no accessible object), and names an edit from the STATIC window
  immediately ABOVE it in z-order (GW_HWNDPREV; measured on plain Win32
  windows). A TLabel has no window, so every Station box read as unnamed. The
  captions are TStaticText now, each streamed AFTER its input in the .lfm,
  because the LCL's child list is the reverse of window z-order (the last
  child is the top window). The first version streamed them before, and this
  check found the window above each box was the NEXT row's caption.

  What is proved here, in two halves:
    * on the streamed form: each caption is a TStaticText paired (FocusControl)
      with its input, the control just after it in its parent, with the
      designed English text, no Tab stop, transparent, and to the left of its
      input in the same row; CaptionOfLabelFor finds it; and the Tab sequence
      of the page is the seventeen inputs, in order, with no caption in it.
    * SHOWN off screen, the Station page selected through the navigation tree
      as the program selects it: on Windows, the window above each input in
      z-order IS its caption's window, and the caption's widget-set class is
      the win32 one that creates a STATIC. That is the exact boundary UIA
      reads. A handle recreated after load would move in the z-order and fail
      here.

  The z-order is read with Win32 GetWindow because the LCL has no call for it
  (none in winapih.inc or lclintfh.inc), and nothing else here touches a raw
  handle: the window found is turned straight back into its LCL control with
  FindControl, so the check compares CONTROLS. The window CLASS is not asked
  of Windows either: the win32 widget set creates every TCustomStaticText as
  a 'STATIC' (win32wsstdctrls.pp, TWin32WSCustomStaticText.CreateHandle), so
  the check asks the caption which widget-set class built it.

  What is NOT proved: that UIA then reports the name. That is the GUI suite's
  question (pywinauto, the UIA backend). The Main callsign row placed on this
  page is generated (a TLabel, shared with every page) and is deliberately
  not converted yet. *)
{$IFDEF WINDOWS}
(* The LCL control whose window is next to aControl's in z-order, in the
  direction GW_HWNDPREV (above) or GW_HWNDNEXT (below); nil when there is no
  such window or it is not an LCL control. *)
function ControlNextInZOrder(const aControl: TWinControl; const aDirection: UINT): TWinControl;
begin
   Result := FindControl(GetWindow(aControl.Handle, aDirection));
end;

(* A control by name, for a failure message. *)
function NameOfControl(const aControl: TWinControl): string;
begin
   if aControl = nil then
      begin
      Result := '(none, or not an LCL control)';
      Exit;
      end;
   Result := aControl.Name + ':' + aControl.ClassName;
end;
{$ENDIF}

procedure TPrefsPlacementTests.CheckStationCaptionsAreWindowsBeforeTheirInputs(const aForm: TPrefsForm);
type
   TStationRow = record
      Caption: TStaticText;
      Input: TWinControl;
      Text: string;
   end;
var
   rows: array of TStationRow;
   i, at, n: integer;
   order: TFPList;
   stop: TWinControl;
   expected: string;

   procedure AddRow(const aCaption: TStaticText; const aInput: TWinControl;
                    const aText: string);
   begin
      SetLength(rows, Length(rows) + 1);
      rows[High(rows)].Caption := aCaption;
      rows[High(rows)].Input   := aInput;
      rows[High(rows)].Text    := aText;
   end;

   (* A page selected the way SelectPage selects it: through the tree, whose
     change handler is the one place that shows a panel. The tree raises
     OnChange from its own 1 ms TTimer (treeview.inc, FChangeTimer), not from
     the assignment, so wait for it -- bounded, and checked. *)
   procedure SelectNavPage(const aTag: integer; const aWhen: string);
   var
      k: integer;
      wantStation: boolean;
   begin
      for k := 0 to aForm.tvNav.Items.Count - 1 do
         begin
         if TNavNode(aForm.tvNav.Items[k]).Tag = aTag then
            begin
            aForm.tvNav.Items[k].Selected := True;
            Break;
            end;
         end;
      wantStation := aTag = NAV_STATION;
      for k := 1 to 200 do
         begin
         Application.ProcessMessages;
         if aForm.layStation.IsVisible = wantStation then
            begin
            Break;
            end;
         Sleep(5);
         end;
      Application.ProcessMessages;
      CheckTrue(aForm.layStation.IsVisible = wantStation,
                aWhen + ': the Station page is ' + BoolToStr(wantStation, 'showing', 'hidden')
                + ' (form ' + BoolToStr(aForm.Visible, True)
                + ', page ' + BoolToStr(aForm.layStation.Visible, True) + ')');
   end;

   (* THE Z-ORDER UIA READS: the window immediately ABOVE each input is its
     caption's, and the caption was built by the win32 STATIC class. *)
   procedure CheckWindowsAbove(const aWhen: string);
{$IFDEF WINDOWS}
   var
      k: integer;
      above: TWinControl;
      wsName: string;
      plain: TStaticText;

   (* WHAT WINDOWS ASKS before it takes a window as an edit's caption, asked
     the way Windows asks it: a raw message to the real window, through the
     widget set's window procedure. Perform would skip that procedure -- and
     the DLGC_WANTALLKEYS it writes -- so it could not see the defect. A
     test-side measurement at the Win32 boundary; the program sends nothing. *)
   function AnswersAsStatic(const aControl: TWinControl): boolean;
   begin
      Result := (Windows.SendMessage(aControl.Handle, WM_GETDLGCODE, 0, 0)
                 and Windows.DLGC_STATIC) <> 0;   (* winuser.h's, not ours *)
   end;
{$ENDIF}
   begin
{$IFDEF WINDOWS}
      for k := 0 to High(rows) do
         begin
         if (rows[k].Caption = nil) or (rows[k].Input = nil) then
            begin
            Continue;
            end;
         CheckTrue(rows[k].Input.HandleAllocated and rows[k].Caption.HandleAllocated,
                   aWhen + ': ' + rows[k].Input.Name + ' and its caption have windows');
         if not (rows[k].Input.HandleAllocated and rows[k].Caption.HandleAllocated) then
            begin
            Continue;
            end;
         above := ControlNextInZOrder(rows[k].Input, GW_HWNDPREV);
         CheckTrue(above = rows[k].Caption,
                   aWhen + ': ' + rows[k].Input.Name + ': the window above it is '
                   + rows[k].Caption.Name + ' (found ' + NameOfControl(above)
                   + '; below it ' + NameOfControl(ControlNextInZOrder(rows[k].Input, GW_HWNDNEXT)) + ')');
         if rows[k].Caption.WidgetSetClass = nil then
            begin
            wsName := '(none)';
            end
         else
            begin
            wsName := rows[k].Caption.WidgetSetClass.ClassName;
            end;
         (* By NAME, not InheritsFrom: the LCL hands a control a run-time COPY
           of its widget-set class's VMT, named '(V)' + that class's name and
           re-parented past it (wslclclasses.pp, CreateVClass), so it does not
           inherit from the class it copies. The name is taken from the class
           reference, so a rename is still the compiler's to catch.
           TR4W's class, not the LCL's TWin32WSCustomStaticText it descends
           from: this is the proof that TInputCaption's registration took
           precedence over the one it inherits (uInputCaption). *)
         CheckTrue((wsName = TWin32WSInputCaption.ClassName) or
                   (wsName = '(V)' + TWin32WSInputCaption.ClassName),
                   aWhen + ': ' + rows[k].Caption.Name + ' was built by TWin32WSInputCaption, '
                   + 'a win32 STATIC (found ' + wsName + ')');
         CheckTrue(rows[k].Caption is TInputCaption,
                   aWhen + ': ' + rows[k].Caption.Name + ' is a TInputCaption (found '
                   + rows[k].Caption.ClassName + ')');
         CheckTrue(AnswersAsStatic(rows[k].Caption),
                   aWhen + ': ' + rows[k].Caption.Name + ' answers WM_GETDLGCODE with DLGC_STATIC');
         end;

      (* THE CONTROL CASE: a plain TStaticText through the same window
        procedure does NOT answer as a static (the LCL says DLGC_WANTALLKEYS
        for every window). Without it the check above could pass because the
        question never reached the widget set's callback at all. Parented on
        the form, not the page, so it is no sibling of the rows above. *)
      plain := TStaticText.Create(nil);
      try
         plain.Parent := aForm;
         plain.HandleNeeded;
         CheckFalse(AnswersAsStatic(plain),
                    aWhen + ': a plain TStaticText does not answer as a static -- '
                    + 'if this fails the LCL now does, and TInputCaption can go');
      finally
         plain.Free;
      end;
{$ELSE}
      (* The rule checked here is Win32's. How the gtk2 and cocoa
        accessibility layers name a field is not measured. *)
{$ENDIF}
   end;

begin
   (* .lfm order, which is also reading order down each column. *)
   AddRow(aForm.lblMyCall,        aForm.edtMyCall,        'Callsign:');
   AddRow(aForm.lblMyName,        aForm.edtMyName,        'First name:');
   AddRow(aForm.lblMyGrid,        aForm.edtMyGrid,        'Grid square:');
   AddRow(aForm.lblMyContinent,   aForm.cbxMyContinent,   'Continent:');
   AddRow(aForm.lblMyZone,        aForm.edtMyZone,        'CQ zone:');
   AddRow(aForm.lblMyITUZone,     aForm.edtMyITUZone,     'ITU zone:');
   AddRow(aForm.lblMyState,       aForm.edtMyState,       'State/Province:');
   AddRow(aForm.lblMySection,     aForm.edtMySection,     'ARRL section:');
   AddRow(aForm.lblMyCountry,     aForm.edtMyCountry,     'Country:');
   AddRow(aForm.lblMyPostalCode,  aForm.edtMyPostalCode,  'Postal code:');
   AddRow(aForm.lblMyCheck,       aForm.edtMyCheck,       'Check:');
   AddRow(aForm.lblMyPrec,        aForm.edtMyPrec,        'Precedence:');
   AddRow(aForm.lblMyFDClass,     aForm.edtMyFDClass,     'FD class:');
   AddRow(aForm.lblMyFOCNumber,   aForm.edtMyFOCNumber,   'FOC number:');
   AddRow(aForm.lblMyIOTA,        aForm.edtMyIOTA,        'IOTA:');
   AddRow(aForm.lblMyPark,        aForm.edtMyPark,        'Park:');
   AddRow(aForm.lblMyLicenseYear, aForm.edtMyLicenseYear, 'License year:');

   for i := 0 to High(rows) do
      begin
      CheckTrue((rows[i].Caption <> nil) and (rows[i].Input <> nil),
                rows[i].Text + ' has a caption and an input');
      if (rows[i].Caption = nil) or (rows[i].Input = nil) then
         begin
         Continue;
         end;

      CheckEquals(rows[i].Text, string(rows[i].Caption.Caption),
                  rows[i].Caption.Name + ': the designed caption');
      CheckTrue(rows[i].Caption.FocusControl = rows[i].Input,
                rows[i].Caption.Name + ' is paired with ' + rows[i].Input.Name);
      CheckTrue((rows[i].Caption.Parent = aForm.layStation) and
                (rows[i].Input.Parent = aForm.layStation),
                rows[i].Caption.Name + ' and its input are on the Station page');

      (* AFTER its input in the child list, which is the window ABOVE it:
        the LCL's child list is the reverse of window z-order. *)
      at := aForm.layStation.GetControlIndex(rows[i].Input);
      CheckTrue((at >= 0) and (at + 1 < aForm.layStation.ControlCount) and
                (aForm.layStation.Controls[at + 1] = rows[i].Caption),
                rows[i].Caption.Name + ' is the control immediately after '
                + rows[i].Input.Name + ' in the child list');

      CheckFalse(rows[i].Caption.TabStop,
                 rows[i].Caption.Name + ' takes no Tab stop');
      CheckTrue(rows[i].Caption.Transparent,
                rows[i].Caption.Name + ' is transparent (the panel shows through)');
      CheckTrue(rows[i].Caption.Left + rows[i].Caption.Width <= rows[i].Input.Left,
                rows[i].Caption.Name + ' ends before its input');
      CheckTrue(Abs(rows[i].Caption.Top - rows[i].Input.Top) <= 8,
                rows[i].Caption.Name + ' is on its input''s row');

      CheckEquals(rows[i].Text, string(CaptionOfLabelFor(rows[i].Input)),
                  rows[i].Input.Name + ': CaptionOfLabelFor finds the static text');

      (* The LCL property too, as 8706893b set it -- not for the continent,
        which is store-backed and never passed through ApplyAccessibleName. *)
      if rows[i].Input is TEdit then
         begin
         expected := Copy(rows[i].Text, 1, Length(rows[i].Text) - 1);
         CheckEquals(expected, string(rows[i].Input.AccessibleName),
                     rows[i].Input.Name + ': AccessibleName is its caption');
         end;
      end;

   (* SHOWN, with the page selected the way SelectPage selects it: through the
     tree, whose change handler is the one place that shows a panel. *)
   ShowOffScreen(aForm);
   try
      SelectNavPage(NAV_STATION, 'first show');

      (* THE TAB SEQUENCE: the page's own Tab stops, in order, are the inputs.
        A caption in it would be a stop that goes nowhere. *)
      order := TFPList.Create;
      try
         aForm.layStation.GetTabOrderList(order);
         n := 0;
         for i := 0 to order.Count - 1 do
            begin
            stop := TWinControl(order[i]);
            if (stop.Parent <> aForm.layStation) or (not stop.TabStop) then
               begin
               Continue;
               end;
            CheckTrue(not (stop is TStaticText),
                      stop.Name + ': a caption is not a Tab stop');
            if n <= High(rows) then
               begin
               CheckTrue(stop = rows[n].Input,
                         'Tab stop ' + IntToStr(n) + ' is ' + rows[n].Input.Name
                         + ' (found ' + stop.Name + ')');
               end;
            Inc(n);
            end;
         CheckEquals(Length(rows), n, 'the Station page has one Tab stop per input');
      finally
         order.Free;
      end;

      CheckWindowsAbove('first show');

      (* THE REUSED WINDOW. Preferences is created once and hidden on close,
        so the operator meets this page after other pages and after a
        reopen; a handle recreated on either path would move in z-order. *)
      SelectNavPage(NAV_HARDWARE, 'away');
      SelectNavPage(NAV_STATION, 'back');
      CheckWindowsAbove('after another page');

      aForm.Hide;
      Application.ProcessMessages;
      ShowOffScreen(aForm);
      SelectNavPage(NAV_STATION, 'reopened');
      CheckWindowsAbove('after hide and show');
   finally
      aForm.Hide;
   end;
end;

(* ISSUE 280: THE STATION BOXES CARRY THEIR SETTING'S HELP AS A TOOLTIP.  A GUI
  run found no tooltip on Grid square with help_en.po loaded.  This pins the
  half a unit test can see: the real form, finding the shipped English
  catalogue the way the program does (HelpDir: help\ under the working
  directory), gives each hand-wired Station box exactly the text the catalogue
  holds for its command, with ShowHint on.  Whether Windows then DISPLAYS it on
  hover is a running program's question (BENCH_QUEUE / the GUI suite).

  The working directory is moved to a temp folder holding help\help_en.po,
  copied from the repository's i18n directory, and put back afterwards; the
  settings file is redirected into the same folder, as in the test above.  It
  fails closed: no catalogue, or one the form did not load, is a failure, never
  a vacuous pass. *)
procedure TPrefsPlacementTests.Test_StationBoxesCarryTheirHelpTooltips;
type
   TBox = record
      Command: string;
      Edit: TEdit;
      Name: string;
   end;
var
   oldIni, oldDir, dir, fn, source, besideHelp: string;
   stagedBeside: boolean;
   oldProvider: TActiveStoreProvider;
   form: TPrefsForm;
   help: TCommandHelp;
   boxes: array of TBox;
   expected: RawByteString;
   i: integer;
begin
   BeginTest('the Station boxes carry their setting''s help as a tooltip (issue 280)');
   stagedBeside := False;
   besideHelp   := ExtractFilePath(ParamStr(0)) + 'help';
   if Application <> nil then
      begin
      Application.Initialize;
      end;

   source := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim +
             '..' + PathDelim + '..' + PathDelim + 'i18n' + PathDelim + 'help_en.po');
   if not FileExists(source) then
      begin
      CheckTrue(False, 'i18n/help_en.po is not found from the test binary: ' + source);
      Exit;
      end;

   oldIni      := CharBufferText(TR4W_INI_FILENAME);
   oldProvider := uSettingsLegacy.ActiveStoreProvider;
   oldDir      := GetCurrentDir;
   dir  := CombinePath(TempDirectory, 'tr4wprefshelp_' + TGUID.NewGuid.ToString);
   form := nil;
   help := nil;
   try
      if (not ForceDirectories(CombinePath(dir, 'help'))) or
         (not CopyFile(source, CombinePath(CombinePath(dir, 'help'), 'help_en.po'))) then
         begin
         CheckTrue(False, 'the English help catalogue could not be staged in ' + dir);
         Exit;
         end;
      if not SetCurrentDir(dir) then
         begin
         CheckTrue(False, 'could not make ' + dir + ' the working directory');
         Exit;
         end;

{$IFNDEF WINDOWS}
      (* Off Windows HelpDir does not look in the working directory: it tries
        /usr/share/tr4w, then beside the program.  So the catalogue is also staged
        beside the test binary -- only when nothing is there already, and removed
        afterwards.  A help\ that is already there is left alone and the checks
        below fail closed if it holds no help_en.po. *)
      if not DirectoryExists(besideHelp) then
         begin
         if (not ForceDirectories(besideHelp)) or
            (not CopyFile(source, CombinePath(besideHelp, 'help_en.po'))) then
            begin
            CheckTrue(False, 'the English help catalogue could not be staged in ' + besideHelp);
            Exit;
            end;
         stagedBeside := True;
         end;
{$ENDIF}

      SetCharBuffer(TR4W_INI_FILENAME, CombinePath(dir, 'tr4w.ini'));
      fn := TR4WConfigFileName;
      if Pos(dir, fn) <> 1 then
         begin
         CheckTrue(False, 'the settings file was not redirected (' + fn +
                          ') -- a --settings switch? The form is not built');
         Exit;
         end;

      help := TCommandHelp.Create(CombinePath(dir, 'help'), 'en');
      CheckTrue(help.EnglishFile <> '', 'the staged English catalogue loads');

      form := TPrefsForm.Create(nil);

      SetLength(boxes, 4);
      boxes[0].Command := 'MY GRID';         boxes[0].Edit := form.edtMyGrid;
      boxes[0].Name    := 'Grid square';
      boxes[1].Command := 'MY CALL';         boxes[1].Edit := form.edtMyCall;
      boxes[1].Name    := 'Callsign';
      boxes[2].Command := 'MY ZONE';         boxes[2].Edit := form.edtMyZone;
      boxes[2].Name    := 'CQ zone';
      boxes[3].Command := 'MY LICENSE YEAR'; boxes[3].Edit := form.edtMyLicenseYear;
      boxes[3].Name    := 'License year';

      for i := Low(boxes) to High(boxes) do
         begin
         expected := UTF8Encode(FormatHelpHint(help.Describe(boxes[i].Command)));
         CheckTrue(expected <> '', boxes[i].Command + ' has help in help_en.po');
         CheckEquals(string(expected), string(boxes[i].Edit.Hint),
                     boxes[i].Command + ': the box''s tooltip is its help');
         CheckTrue(boxes[i].Edit.ShowHint, boxes[i].Command + ': ShowHint is on');

         (* ISSUE 278: the accessible name is the visible label (its ':'
           dropped), the description the whole help text, unwrapped. *)
         CheckEquals(boxes[i].Name, string(boxes[i].Edit.AccessibleName),
                     boxes[i].Command + ': the box''s accessible name is its label');
         expected := UTF8Encode(Trim(help.Describe(boxes[i].Command)));
         CheckEquals(string(expected), string(boxes[i].Edit.AccessibleDescription),
                     boxes[i].Command + ': the box''s accessible description is its help');
         end;

      CheckBoundControlsAreNamed(form);
   finally
      form.Free;
      help.Free;
      SetCurrentDir(oldDir);
      uSettingsLegacy.ActiveStoreProvider := oldProvider;
      SetCharBuffer(TR4W_INI_FILENAME, oldIni);
      if DirectoryExists(dir) then
         begin
         DeleteDirectory(dir, False);
         end;
      if stagedBeside then
         begin
         DeleteDirectory(besideHelp, False);
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
   Test_StationBoxesCarryTheirHelpTooltips;
end;

end.

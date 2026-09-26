unit uTestMenuShortcuts;
{$I ..\..\src\tr4w.inc}
(*
  WHO OWNS EACH KEYSTROKE -- PINNED IN BOTH DIRECTIONS.

  A menu item carries its own shortcut now (uMenu, item.ShortCut), which is how
  the widget set comes to render it right-aligned on Win32, as a key equivalent
  on the Cocoa menu bar and as an accel label on gtk2. The keystrokes a menu
  item may NOT own stay with uAppInputHooks.

  docs\ACCELERATOR_AUDIT.md exists because two things answering one keystroke is
  a defect. The split is disjoint BY CONSTRUCTION -- one rule,
  uMenu.AcceleratorRowBelongsToTheMenu, read by the menu builder and by the
  input hook -- so what these tests add is the part construction cannot give:

    * that the CLASSIFICATION is what it is meant to be, so a row moving between
      the two sets shows up in a diff rather than silently;
    * that no menu-owned keystroke collides with another menu-owned one or with
      a keystroke the hook still installs. That is the overlap the audit is
      about, asked of the KEYSTROKE rather than of the command id;
    * that the acKey/acCtrl/acAlt/acShift -> TShortCut translation is exact.
      Get one wrong and a key silently changes, and no gate would notice: this
      converts BACK with ShortCutToKey and compares against the row.

  What these tests cannot see: whether the menu item for a command was actually
  created (that needs the built menu), and how any of it looks on screen.
*)

interface

uses
   SysUtils, Classes, Menus, LCLType, uTR4WTestFramework, uAccelerators, uMenu;

type
   TMenuShortcutTests = class(TTestCase)
   protected
      procedure Test_TheSplitIsWhatItSaysItIs;
      procedure Test_MenuOwnedRowsQualify;
      procedure Test_TheShortCutTranslationIsExact;
      procedure Test_NoKeystrokeHasTwoOwners;
      procedure Test_TheGuardedKeysStayWithTheHook;
      procedure Test_TheThreeEditingKeysJoinTheColumn;
      procedure Test_TheFourUnmodifiedKeysJoinTheColumn;
      procedure Test_TheNamedDisplayOnlyRowsAreBound;
      procedure Test_TheCaptionIsJustTheCaption;
      procedure Test_MenuCommandExistsFindsAndMisses;
   public
      procedure RunAllTests; override;
   end;

implementation

{ How many rows each side owns. Counted rather than assumed, and used by more
  than one test. }
procedure CountOwners(out aMenuOwned, aHookInstalled: integer);
var
   i: integer;
begin
   aMenuOwned     := 0;
   aHookInstalled := 0;

   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if AcceleratorRowBelongsToTheMenu(i) then
         begin
         Inc(aMenuOwned);
         end
      else
         begin
         if ACCELERATORS[i].acInstall then
            begin
            Inc(aHookInstalled);
            end;
         end;
      end;
end;

{ The keystroke a row describes, as a TShortCut. A SECOND implementation of
  what uMenu does, deliberately: a check that reuses the code under test agrees
  with itself by construction. }
function RowShortCut(const aRow: TAcceleratorRow): TShortCut;
var
   shift: TShiftState;
begin
   shift := [];
   if aRow.acCtrl then
      begin
      Include(shift, ssCtrl);
      end;
   if aRow.acAlt then
      begin
      Include(shift, ssAlt);
      end;
   if aRow.acShift then
      begin
      Include(shift, ssShift);
      end;
   Result := Menus.ShortCut(aRow.acKey, shift);
end;

procedure TMenuShortcutTests.Test_TheSplitIsWhatItSaysItIs;
var
   menuOwned:     integer;
   hookInstalled: integer;
begin
   BeginTest('Test_TheSplitIsWhatItSaysItIs');

   CountOwners(menuOwned, hookInstalled);

   (* MEASURED 2026-09-25, when the menu items took their shortcuts over: 74 of
     the 94 rows moved and 20 stayed, 16 of which the hook installs -- the other
     four are display-only rows that bind nothing anywhere (Alt+-, the second
     Alt+X, PgUp and PgDn, which the entry fields answer).

     76 AND 16 SINCE 2026-09-26, when NY4I gave Alt+- and Alt+X real menu
     shortcuts. Those two rows are acInstall:false, so they were never counted
     on the hook's side and the 16 is unchanged: what moved is two rows that
     previously belonged to NEITHER side, advertising a key in a caption while
     Alt+- in particular was bound by nothing at all.

     79 AND 13 LATER THE SAME DAY, when the three standard editing keys joined
     the column: Ctrl+A (10400), Ctrl+C (10424) and Ctrl+V (10426). All three
     were acInstall:true, so unlike Alt+- and Alt+X they came off the hook's
     side -- 16 - 3 = 13 -- and what makes that safe is not the row but the
     override: TTR4WMainForm.IsShortcut declines the keystroke when the focused
     control needs it (uEditingKeys, and uTestEditingKeys pins the rule).

     83 AND 11 LATER STILL, when NY4I moved four of the seven UNMODIFIED keys
     into the column. Pause (10500) and Ins (10501) were acInstall:true and came
     off the hook's side -- 13 - 2 = 11 -- while PgUp (10503) and PgDn (10504)
     are acInstall:false and belonged to NEITHER side, being bound by the entry
     field's own key handler until that arm was deleted in the same change.

     The numbers are pinned because a row changing sides is a decision about
     who answers a keystroke, and it must never happen as a side effect. *)
   CheckEquals(83, menuOwned, 'rows a menu item owns');
   CheckEquals(11, hookInstalled, 'rows the input hook still installs');
end;

procedure TMenuShortcutTests.Test_MenuOwnedRowsQualify;
var
   i:   integer;
   row: TAcceleratorRow;
begin
   BeginTest('Test_MenuOwnedRowsQualify');

   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if not AcceleratorRowBelongsToTheMenu(i) then
         begin
         Continue;
         end;

      row := ACCELERATORS[i];

      (* acInstall, OR ONE OF THE FOUR ROWS NAMED IN uMenu. Written as literal
        ids rather than by calling uMenu's own list, so that adding a fifth
        exception fails HERE and has to be argued for. *)
      CheckTrue(row.acInstall     or (row.acId = 10320) or (row.acId = 10337)
                or (row.acId = 10503) or (row.acId = 10504),
                'a menu-owned row installs a binding, or is one of the four '
                + 'named display-only rows: ' + row.acDisplay);

      (* A MODIFIER, OR ONE OF THE FOUR UNMODIFIED ROWS NY4I NAMED. Same
        reasoning, and the two lists are not the same list: PgUp and PgDn are in
        BOTH, which is why uMenu keeps them apart. *)
      CheckTrue(row.acCtrl or row.acAlt or row.acShift
                or (row.acId = 10500) or (row.acId = 10501)
                or (row.acId = 10503) or (row.acId = 10504),
                'a menu-owned row has a modifier, or is one of the four named '
                + 'unmodified rows: ' + row.acDisplay);
      CheckTrue(MenuCommandExists(row.acId),
                'a menu-owned row has a menu item: ' + row.acDisplay);
      CheckTrue(MenuShortCutFor(row.acId) <> scNone,
                'the command reports a shortcut: ' + row.acDisplay);
      end;
end;

procedure TMenuShortcutTests.Test_TheShortCutTranslationIsExact;
var
   i:     integer;
   row:   TAcceleratorRow;
   key:   word;
   shift: TShiftState;
begin
   BeginTest('Test_TheShortCutTranslationIsExact');

   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if not AcceleratorRowBelongsToTheMenu(i) then
         begin
         Continue;
         end;

      row := ACCELERATORS[i];

      { The unit under test agrees with the second implementation above... }
      CheckEquals(integer(RowShortCut(row)), integer(MenuShortCutFor(row.acId)),
                  'MenuShortCutFor matches the row: ' + row.acDisplay);

      { ...and the value converts BACK to the same keystroke, which is what
        says the modifier bits landed where the LCL reads them. }
      key   := 0;
      shift := [];
      ShortCutToKey(MenuShortCutFor(row.acId), key, shift);

      CheckEquals(integer(row.acKey), integer(key),
                  'the key survives the round trip: ' + row.acDisplay);
      CheckTrue(row.acCtrl = (ssCtrl in shift), 'Ctrl: ' + row.acDisplay);
      CheckTrue(row.acAlt = (ssAlt in shift), 'Alt: ' + row.acDisplay);
      CheckTrue(row.acShift = (ssShift in shift), 'Shift: ' + row.acDisplay);
      end;
end;

procedure TMenuShortcutTests.Test_NoKeystrokeHasTwoOwners;
var
   i: integer;
   j: integer;
begin
   BeginTest('Test_NoKeystrokeHasTwoOwners');

   (* THE OVERLAP THE AUDIT IS ABOUT, asked of the KEYSTROKE and not of the
     command id. Two rows may legitimately name one command (10317 is both
     Alt+P and Ctrl+Alt+W); what may never happen is one KEYSTROKE reaching
     both a menu item and the input hook, or two menu items, because then which
     of them answers is decided by array order. *)
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if not AcceleratorRowBelongsToTheMenu(i) then
         begin
         Continue;
         end;

      for j := Low(ACCELERATORS) to High(ACCELERATORS) do
         begin
         if j = i then
            begin
            Continue;
            end;
         if not ACCELERATORS[j].acInstall then
            begin
            Continue;
            end;
         if RowShortCut(ACCELERATORS[j]) <> RowShortCut(ACCELERATORS[i]) then
            begin
            Continue;
            end;

         (* THE ONE DELIBERATE DUPLICATE, NAMED. 10002 File -> Exit and 10337
           Exit Program both carry Alt+X, both are menu items, and both run
           ExitProgram(True) (MainUnit.pas:5004 and :5544). TMenu.FindItem
           returns the first match (menu.inc:217), so which one answers cannot
           be observed. NY4I accepted this on 2026-09-26 as the price of Exit
           Program joining the shortcut column.

           This is an allowance for ONE PAIR, not for the array order deciding
           anything: any other collision still fails. *)
         if ((ACCELERATORS[i].acId = 10002) and (ACCELERATORS[j].acId = 10337)) or
            ((ACCELERATORS[i].acId = 10337) and (ACCELERATORS[j].acId = 10002)) then
            begin
            Continue;
            end;

         CheckTrue(False,
                   'keystroke ' + ACCELERATORS[i].acDisplay
                   + ' is claimed twice -- commands '
                   + IntToStr(ACCELERATORS[i].acId) + ' and '
                   + IntToStr(ACCELERATORS[j].acId));
         end;
      end;
end;

procedure TMenuShortcutTests.Test_TheGuardedKeysStayWithTheHook;
var
   i: integer;
begin
   BeginTest('Test_TheGuardedKeysStayWithTheHook');

   (* THREE KEYSTROKES, AND EACH IS HERE FOR A REASON OF ITS OWN -- which is the
     point of naming them one by one rather than deriving them from the rule.
     Relaxing the rule fails HERE, where the reasons are.

       Tab (10506)    THE WIDGET SET'S OWN NAVIGATION. A ShortCut on Tab is
                      tested before the key reaches the focused control, so
                      focus would stop moving between fields in every tool
                      window. The radio editor closed on Tab, 2026-09-09.
       Esc (10502)    ALSO NAVIGATION. Lint-FormDefaults asserts that every form
                      closes on Escape and TApplication.DoEscapeKey is how that
                      happens; a ShortCut would take the key first.
       `   (10507)    A PRINTABLE CHARACTER. An unmodified shortcut on it would
                      make the backtick untypeable in every edit box in the
                      program, the callsign field included.

     Enter (10651) is on the list too and is a different case again: it has no
     menu row at all, so there is nothing for a shortcut to hang on.

     CTRL+A, CTRL+C AND CTRL+V LEFT THIS LIST ON 2026-09-26 because a menu
     shortcut CAN be declined for one window: TCustomForm.IsShortcut is virtual,
     so TTR4WMainForm returns False without calling inherited when the focused
     control needs the key. Issue #23 (the DX cluster window) and NY4I's
     2026-09-15 report (a field on a non-modal dialog) stay closed by
     uEditingKeys rather than by keeping the key out of the menu.

     PAUSE, INS, PGUP AND PGDN LEFT IT THE SAME DAY, by NY4I's decision, and
     that is a WIDENING he was shown and accepted: those four now fire from
     every modeless window rather than only where they fired before. None of
     them is navigation and none of them is a character anybody types, which is
     exactly what separates them from the three above. *)
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if not AcceleratorRowBelongsToTheMenu(i) then
         begin
         Continue;
         end;

      CheckTrue((ACCELERATORS[i].acDisplay <> 'Tab')    and
                (ACCELERATORS[i].acDisplay <> 'Esc')    and
                (ACCELERATORS[i].acDisplay <> '`')      and
                (ACCELERATORS[i].acDisplay <> 'Enter'),
                'the hook must keep ' + ACCELERATORS[i].acDisplay);
      end;

   { And the other direction, id by id: the three rows still report no shortcut.
     THIS IS THE HALF THAT MUST NOT BE WIDENED. }
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10502)),
               'Esc is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10506)),
               'Tab is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10507)),
               'the spot key is not a menu shortcut');
end;

procedure TMenuShortcutTests.Test_TheFourUnmodifiedKeysJoinTheColumn;
begin
   BeginTest('Test_TheFourUnmodifiedKeysJoinTheColumn');

   (* NY4I, 2026-09-26: FOUR OF THE SEVEN UNMODIFIED KEYS, AND EXACTLY FOUR.

     What makes each safe is stated beside
     uMenu.UNMODIFIED_ROWS_A_MENU_ITEM_MAY_OWN. What makes PgUp and PgDn safe is
     in two more places as well, because they had a second owner: the entry
     field's arm in uMainWindowProc is DELETED in the same change, and
     uEditingKeys declines both keys to a focused grid, list box, memo, combo or
     tree view so the band map and the DX cluster console keep paging. *)
   CheckEquals(integer(Menus.ShortCut(VK_PAUSE, [])),
               integer(MenuShortCutFor(10500)),
               'Focus in main window owns Pause');
   CheckEquals(integer(Menus.ShortCut(VK_INSERT, [])),
               integer(MenuShortCutFor(10501)),
               'Toggle insert mode owns Ins');
   CheckEquals(integer(Menus.ShortCut(VK_PRIOR, [])),
               integer(MenuShortCutFor(10503)),
               'CW Speed Up owns PgUp');
   CheckEquals(integer(Menus.ShortCut(VK_NEXT, [])),
               integer(MenuShortCutFor(10504)),
               'CW Speed Down owns PgDn');

   (* AND THE MODIFIED PAGE KEYS ARE UNTOUCHED AND STILL DIFFERENT COMMANDS.
     Ctrl+PgUp and Ctrl+PgDn are the INACTIVE radio's CW speed, which is why
     uEditingKeys declines only the UNMODIFIED pair: declining these would take
     away a keystroke the operator pressed on purpose. *)
   CheckEquals(integer(Menus.ShortCut(VK_PRIOR, [ssCtrl])),
               integer(MenuShortCutFor(10513)),
               'the inactive radio keeps Ctrl+PgUp');
   CheckEquals(integer(Menus.ShortCut(VK_NEXT, [ssCtrl])),
               integer(MenuShortCutFor(10514)),
               'and Ctrl+PgDn');
end;

procedure TMenuShortcutTests.Test_TheThreeEditingKeysJoinTheColumn;
var
   i: integer;
begin
   BeginTest('Test_TheThreeEditingKeysJoinTheColumn');

   (* NY4I, 2026-09-26: EXACTLY THREE ROWS, and the reason they can be three is
     TTR4WMainForm.IsShortcut, not anything about the rows. The caption read
     "Send Keyboard Input (Ctrl+A)" beside a right-aligned column; it reads
     "Send Keyboard Input" with Ctrl+A in the column now. *)
   CheckEquals(integer(Menus.ShortCut(Ord('A'), [ssCtrl])),
               integer(MenuShortCutFor(10400)),
               'Send Keyboard Input owns Ctrl+A');
   CheckEquals(integer(Menus.ShortCut(Ord('C'), [ssCtrl])),
               integer(MenuShortCutFor(10424)),
               'Clear Mult Sheet owns Ctrl+C');
   CheckEquals(integer(Menus.ShortCut(Ord('V'), [ssCtrl])),
               integer(MenuShortCutFor(10426)),
               'Execute Config File owns Ctrl+V');

   (* AND NO FOURTH. Nothing in ACCELERATORS binds Ctrl+X, so the guard that
     used to name it excluded nothing -- deleting the name changed no row. If a
     Ctrl+X row is ever added this fails, which is the point: it is a decision,
     and uEditingKeys already names Ctrl+X on the decline side. *)
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      CheckTrue(ACCELERATORS[i].acDisplay <> 'Ctrl+X',
                'nothing binds Ctrl+X -- command '
                + IntToStr(ACCELERATORS[i].acId) + ' now does');
      end;
end;

procedure TMenuShortcutTests.Test_TheNamedDisplayOnlyRowsAreBound;
begin
   BeginTest('Test_TheNamedDisplayOnlyRowsAreBound');

   (* NY4I, 2026-09-26: these two join the shortcut column.

     Alt+- was bound by NOTHING -- the accelerator survived only in the ger and
     ukr .RES files -- so this is the advertised key starting to work, which is
     the point of the change and closes the defect the audit records. *)
   CheckEquals(integer(Menus.ShortCut(VK_OEM_MINUS, [ssAlt])),
               integer(MenuShortCutFor(10320)),
               'Toggle autosend owns Alt+-');

   { Alt+X on both items, deliberately, and identical -- see the duplicate
     allowance above. }
   CheckEquals(integer(Menus.ShortCut(Ord('X'), [ssAlt])),
               integer(MenuShortCutFor(10337)),
               'Exit Program owns Alt+X');
   CheckEquals(integer(MenuShortCutFor(10002)),
               integer(MenuShortCutFor(10337)),
               'File -> Exit and Exit Program carry the same keystroke');

   (* AND THE OTHER TWO acInstall:false ROWS ARE BOUND NOW TOO, which needed a
     DELETION to be true: PgUp and PgDn were bound by the entry field's own key
     handler (uMainWindowProc), so a shortcut would have been a SECOND owner and
     would have fired each command twice -- the LCL calls the focused control's
     OnKeyDown before it tests the shortcuts (wincontrol.inc:5881 then :5887),
     and that arm did not consume the key. The arm is gone; the item owns it.

     Pinned in Test_TheFourUnmodifiedKeysJoinTheColumn rather than repeated
     here, because for these two the interesting question is not "is it bound"
     but "is it bound ONCE". *)
   CheckTrue(MenuShortCutFor(10503) <> scNone,
             'CW speed up is bound, and by the menu item alone');
   CheckTrue(MenuShortCutFor(10504) <> scNone,
             'CW speed down likewise');
end;

{ THE BUILT MENU, ONCE PER PROCESS, AND DELIBERATELY NEVER FREED.

  BuildTR4WMainMenu publishes GMainMenu and GMenuIndex inside uMenu, and there
  is no way to unpublish them, so freeing the owner would leave MenuItemById
  handing out dangling pointers to whatever ran next. A test binary that exits
  is the right place to hold one menu for the life of the run. }
var
   GTestMenuOwner: TComponent = nil;

function BuiltMenuItem(const aId: word): TMenuItem;
begin
   if GTestMenuOwner = nil then
      begin
      GTestMenuOwner := TComponent.Create(nil);
      InitializeMenuText;
      BuildTR4WMainMenu(GTestMenuOwner, nil);
      end;

   Result := MenuItemById(aId);
end;

procedure TMenuShortcutTests.Test_TheCaptionIsJustTheCaption;
var
   item: TMenuItem;
   i:    integer;
begin
   BeginTest('Test_TheCaptionIsJustTheCaption');

   (* NY4I, 2026-09-26: THE THREE ROWS THE MENU MAY NOT OWN ADVERTISE NOTHING.

     Their keystroke used to be spelled into the caption -- after a TAB, which
     DrawText expands to a tab stop chosen by the caption's own length, and then
     in PARENTHESES. He rejected both: "the caption is just the caption". So the
     assertion is on the CAPTION THE BUILDER PRODUCES, not on a formatting
     helper, because the helper is deleted and the builder is what puts text on
     screen.

     Esc's hint was redundant on top of that -- the caption is the word
     "Escape". *)
   item := BuiltMenuItem(10502);
   CheckTrue(item <> nil, 'Escape has a menu item');
   CheckEquals('Escape', item.Caption, 'Escape reads as itself');

   { '&&' in the resourcestring is a literal ampersand to the widget set. }
   item := BuiltMenuItem(10506);
   CheckTrue(item <> nil, 'Search & pounce has a menu item');
   CheckEquals('Search && pounce mode', item.Caption,
               'no (Tab) on the end of it');

   item := BuiltMenuItem(10507);
   CheckTrue(item <> nil, 'Send spot has a menu item');
   CheckEquals('Send spot', item.Caption, 'no (`) on the end of it');

   { And all three still carry no shortcut, which is what makes the caption the
     only thing they could have advertised with. }
   CheckEquals(integer(scNone), integer(BuiltMenuItem(10502).ShortCut), 'Esc');
   CheckEquals(integer(scNone), integer(BuiltMenuItem(10506).ShortCut), 'Tab');
   CheckEquals(integer(scNone), integer(BuiltMenuItem(10507).ShortCut), '`');

   (* AND NO CAPTION ANYWHERE CARRIES A TAB. That is the defect NY4I
     photographed, asked of every row rather than of the three -- a tab is what
     the Win32 original used and it renders as a stop, never as a column. *)
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      item := BuiltMenuItem(ACCELERATORS[i].acId);
      if item = nil then
         begin
         Continue;
         end;

      CheckTrue(Pos(#9, item.Caption) = 0,
                'no tab in the caption for ' + ACCELERATORS[i].acDisplay);
      end;

   (* THE FOUR THAT JOINED THE COLUMN SHOW THEIR KEY THERE AND NOT IN THE TEXT.
     "CW Speed Up (PgUp)" is what this would have read a day ago. *)
   CheckEquals('CW Speed Up', BuiltMenuItem(10503).Caption,
               'CW Speed Up has its key in the column');
   CheckEquals('CW Speed Down', BuiltMenuItem(10504).Caption,
               'CW Speed Down likewise');
   CheckEquals('Focus in main window', BuiltMenuItem(10500).Caption,
               'Focus in main window likewise');
end;

procedure TMenuShortcutTests.Test_MenuCommandExistsFindsAndMisses;
begin
   BeginTest('Test_MenuCommandExistsFindsAndMisses');

   CheckTrue(MenuCommandExists(10321), 'menu_alt_bandup has a menu row');
   CheckTrue(MenuCommandExists(10603), 'menu_download_latest_cty_dat has a menu row');
   CheckFalse(MenuCommandExists(10651), 'Enter has no menu row at all');
   CheckFalse(MenuCommandExists(64000), 'a command nothing declares');

   { Alt+B is the item NY4I photographed. It carries the keystroke itself now. }
   CheckEquals(integer(Menus.ShortCut(Ord('B'), [ssAlt])),
               integer(MenuShortCutFor(10321)),
               'Band Up owns Alt+B');
end;

procedure TMenuShortcutTests.RunAllTests;
begin
   Test_TheSplitIsWhatItSaysItIs;
   Test_MenuOwnedRowsQualify;
   Test_TheShortCutTranslationIsExact;
   Test_NoKeystrokeHasTwoOwners;
   Test_TheGuardedKeysStayWithTheHook;
   Test_TheThreeEditingKeysJoinTheColumn;
   Test_TheFourUnmodifiedKeysJoinTheColumn;
   Test_TheNamedDisplayOnlyRowsAreBound;
   Test_TheCaptionIsJustTheCaption;
   Test_MenuCommandExistsFindsAndMisses;
end;

end.

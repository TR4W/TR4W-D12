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
      procedure Test_TheTwoNamedDisplayOnlyRowsAreBound;
      procedure Test_TheInlineKeyIsParenthesised;
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

     The numbers are pinned because a row changing sides is a decision about
     who answers a keystroke, and it must never happen as a side effect. *)
   CheckEquals(79, menuOwned, 'rows a menu item owns');
   CheckEquals(13, hookInstalled, 'rows the input hook still installs');
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

      (* acInstall, OR ONE OF THE TWO ROWS NAMED IN uMenu. Written as two
        literal ids rather than by calling uMenu's own list, so that adding a
        third exception fails HERE and has to be argued for. *)
      CheckTrue(row.acInstall or (row.acId = 10320) or (row.acId = 10337),
                'a menu-owned row installs a binding, or is one of the two '
                + 'named display-only rows: ' + row.acDisplay);
      CheckTrue(row.acCtrl or row.acAlt or row.acShift,
                'a menu-owned row has a modifier -- an unmodified key is typing: '
                + row.acDisplay);
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

   (* EACH OF THESE IS A CLOSED DEFECT that a ShortCut would reopen, because a
     menu shortcut is answered from ANY form:

       Tab, Esc                 the radio editor closed on Tab, 2026-09-09;
       Ins, `, Pause, Enter     unmodified keys, eaten inside any edit field.

     Named one by one rather than derived from the rule, so that relaxing the
     rule fails HERE, where the reasons are written down.

     CTRL+A, CTRL+C AND CTRL+V ARE NO LONGER ON THIS LIST (2026-09-26), and the
     sentence above is why they could leave it: a menu shortcut CAN now be
     declined for one window. TCustomForm.IsShortcut is virtual, so
     TTR4WMainForm returns False without calling inherited when the focused
     control needs the key -- Issue #23 (the DX cluster window) and NY4I's
     2026-09-15 report (a field on a non-modal dialog) are both still closed,
     by uEditingKeys rather than by keeping the key out of the menu.

     THE SEVEN BELOW ARE A DIFFERENT CASE AND MUST NOT FOLLOW. They are
     UNMODIFIED keystrokes, so giving them a shortcut would not merely move who
     draws the key: it would widen WHERE the key fires, from the one window that
     answers it today to every form in the program. That is a behaviour decision
     for NY4I and it has not been made. *)
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if not AcceleratorRowBelongsToTheMenu(i) then
         begin
         Continue;
         end;

      CheckTrue((ACCELERATORS[i].acDisplay <> 'Tab')    and
                (ACCELERATORS[i].acDisplay <> 'Esc')    and
                (ACCELERATORS[i].acDisplay <> 'Ins')    and
                (ACCELERATORS[i].acDisplay <> 'Pause')  and
                (ACCELERATORS[i].acDisplay <> 'PgUp')   and
                (ACCELERATORS[i].acDisplay <> 'PgDn')   and
                (ACCELERATORS[i].acDisplay <> '`')      and
                (ACCELERATORS[i].acDisplay <> 'Enter'),
                'the hook must keep ' + ACCELERATORS[i].acDisplay);
      end;

   { And the other direction, id by id: every one of the seven unmodified rows
     still reports no shortcut, so its item advertises the key in its caption.
     THIS IS THE HALF THAT MUST NOT BE WIDENED. }
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10500)),
               'Pause is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10501)),
               'Ins is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10502)),
               'Esc is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10503)),
               'PgUp is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10504)),
               'PgDn is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10506)),
               'Tab is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10507)),
               'the spot key is not a menu shortcut');
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

procedure TMenuShortcutTests.Test_TheTwoNamedDisplayOnlyRowsAreBound;
begin
   BeginTest('Test_TheTwoNamedDisplayOnlyRowsAreBound');

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

   (* AND THE OTHER TWO acInstall:false ROWS MUST NOT. PgUp and PgDn are bound
     by THE ENTRY FIELD'S OWN KEY HANDLER -- uMainWindowProc:359-367, NOT the
     message loop this said until 2026-09-26; that loop is gone and tr4w.lpr
     runs Application.Run. A menu shortcut would be a second owner AND would
     widen where PgUp changes CW speed, because the entry field's handler fires
     only while a call or exchange field has focus. This is the half of the
     change that must not be widened. *)
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10503)),
               'CW speed up stays with the entry field');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10504)),
               'CW speed down stays with the entry field');
end;

procedure TMenuShortcutTests.Test_TheInlineKeyIsParenthesised;
begin
   BeginTest('Test_TheInlineKeyIsParenthesised');

   (* A ROW THE MENU MAY NOT OWN READS AS A LABEL, NOT AS A COLUMN. The tab
     that stood here was a DT_EXPANDTABS tab stop, so a minority of rows sat
     at a stop of their own beside the real right-aligned column -- the ragged
     menu NY4I photographed on 2026-09-26. *)
   CheckEquals('Send Keyboard Input (Ctrl+A)',
               CaptionWithInlineKey('Send Keyboard Input', 'Ctrl+A'),
               'the key reads as part of the label');
   CheckTrue(Pos(#9, CaptionWithInlineKey('Toggle insert mode', 'Ins')) = 0,
             'no tab survives anywhere in the caption');

   { A command with no accelerator is left exactly alone -- no empty
     parentheses on the end of a perfectly good label. }
   CheckEquals('Band Rescore', CaptionWithInlineKey('Band Rescore', ''),
               'no key, no punctuation');

   { And the inverse, which is what a window title uses. }
   CheckEquals('CW Speed Up',
               CaptionWithoutInlineKey('CW Speed Up (PgUp)'),
               'the title is the label alone');
   CheckEquals('Bandmap', CaptionWithoutInlineKey('Bandmap'),
               'a caption with no key is unchanged');

   (* A PARENTHESIS IS NOT ENOUGH TO STRIP: a keystroke holds no space, and
     that is what keeps an ordinary parenthesised caption intact. Without this
     rule the inverse would silently eat a real part of a label. *)
   CheckEquals('Edit Cabrillo Summary (Issue 914)',
               CaptionWithoutInlineKey('Edit Cabrillo Summary (Issue 914)'),
               'a parenthesised phrase is not a keystroke');
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
   Test_TheTwoNamedDisplayOnlyRowsAreBound;
   Test_TheInlineKeyIsParenthesised;
   Test_MenuCommandExistsFindsAndMisses;
end;

end.

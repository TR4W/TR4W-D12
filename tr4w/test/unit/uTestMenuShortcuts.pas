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
   SysUtils, Classes, Menus, uTR4WTestFramework, uAccelerators, uMenu;

type
   TMenuShortcutTests = class(TTestCase)
   protected
      procedure Test_TheSplitIsWhatItSaysItIs;
      procedure Test_MenuOwnedRowsQualify;
      procedure Test_TheShortCutTranslationIsExact;
      procedure Test_NoKeystrokeHasTwoOwners;
      procedure Test_TheGuardedKeysStayWithTheHook;
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

     The numbers are pinned because a row changing sides is a decision about
     who answers a keystroke, and it must never happen as a side effect. *)
   CheckEquals(74, menuOwned, 'rows a menu item owns');
   CheckEquals(16, hookInstalled, 'rows the input hook still installs');
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

      CheckTrue(row.acInstall,
                'a menu-owned row installs a binding: ' + row.acDisplay);
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
     menu shortcut is answered from ANY form and cannot be declined for one
     window:

       Ctrl+A, Ctrl+C, Ctrl+V   Issue #23 and NY4I 2026-09-15 -- the standard
                                editing keys, in the cluster window and on
                                every non-modal dialog;
       Tab, Esc                 the radio editor closed on Tab, 2026-09-09;
       Ins, `, Pause, Enter     unmodified keys, eaten inside any edit field.

     Named one by one rather than derived from the rule, so that relaxing the
     rule fails HERE, where the reasons are written down. *)
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if not AcceleratorRowBelongsToTheMenu(i) then
         begin
         Continue;
         end;

      CheckTrue((ACCELERATORS[i].acDisplay <> 'Ctrl+A') and
                (ACCELERATORS[i].acDisplay <> 'Ctrl+C') and
                (ACCELERATORS[i].acDisplay <> 'Ctrl+V') and
                (ACCELERATORS[i].acDisplay <> 'Ctrl+X') and
                (ACCELERATORS[i].acDisplay <> 'Tab')    and
                (ACCELERATORS[i].acDisplay <> 'Esc')    and
                (ACCELERATORS[i].acDisplay <> 'Ins')    and
                (ACCELERATORS[i].acDisplay <> 'Pause')  and
                (ACCELERATORS[i].acDisplay <> 'Enter'),
                'the hook must keep ' + ACCELERATORS[i].acDisplay);
      end;

   { And the other direction: the commands that DO have a menu item still
     report no shortcut, so the item advertises the key in its caption. }
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10424)),
               'Ctrl+C clear mult sheet is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10502)),
               'Esc is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10506)),
               'Tab is not a menu shortcut');
   CheckEquals(integer(scNone), integer(MenuShortCutFor(10507)),
               'the spot key is not a menu shortcut');
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
   Test_MenuCommandExistsFindsAndMisses;
end;

end.

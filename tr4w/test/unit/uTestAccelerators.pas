unit uTestAccelerators;
{$I ..\..\src\tr4w.inc}
{
  THE KEYBOARD BINDING TABLE, PINNED.

  src\uAccelerators.pas replaced eleven binary accelerator tables -- one per
  language .RES -- that had drifted apart from each other and from the menu
  captions that advertise them.  See docs\ACCELERATOR_AUDIT.md.

  Those eleven drifted because nothing could compare them.  A Pascal table is
  only an improvement if something checks it, so these tests assert the
  invariants that the .RES files silently broke:

    * no two rows claim the SAME keystroke.  That is the failure that made
      Alt+P ambiguous between menu_messages and menu_alt_p, and it is invisible
      to the compiler;
    * every row's display text MATCHES its own modifiers and key.  The caption
      and the binding come from one row now, and this is what keeps them
      honest -- 'Ctrl+-' on a row that binds plain '-' is exactly the defect
      that shipped;
    * every id resolves to a real command;
    * the table is not silently empty or truncated.

  What these tests CANNOT see: whether a keystroke is the RIGHT one for a
  command, and whether the message loop separately binds something (PgUp/PgDn
  are bound at tr4w.lpr:1589-1590 and appear in no table at all).
}

interface

uses
   SysUtils, uTR4WTestFramework, uAccelerators;

type
   TAcceleratorTests = class(TTestCase)
   protected
      procedure Test_TableIsNotEmpty;
      procedure Test_NoDuplicateKeystroke;
      procedure Test_DisplayTextMatchesTheBinding;
      procedure Test_EveryRowHasAKeyAndACommand;
      procedure Test_LookupFindsAndMisses;
      procedure Test_DisplayOnlyRowsAreNotInstalled;
   public
      procedure RunAllTests; override;
   end;

implementation

// Render a row the way the display text is meant to read, from the row's OWN
// modifier flags and key.  Deliberately a SECOND implementation rather than a
// call into uAccelerators: a check that reuses the code under test agrees with
// itself by construction.
function RenderRow(const aRow: TAcceleratorRow): string;
var
   k: string;
begin
   Result := '';
   if aRow.acCtrl then
      begin
      Result := Result + 'Ctrl+';
      end;
   if aRow.acAlt then
      begin
      Result := Result + 'Alt+';
      end;
   if aRow.acShift then
      begin
      Result := Result + 'Shift+';
      end;

   case aRow.acKey of
      $08: k := 'Back';
      $09: k := 'Tab';
      $0D: k := 'Enter';
      $13: k := 'Pause';
      $1B: k := 'Esc';
      $20: k := 'Space';
      $21: k := 'PgUp';
      $22: k := 'PgDn';
      $23: k := 'End';
      $24: k := 'Home';
      $25: k := 'Left';
      $26: k := 'Up';
      $27: k := 'Right';
      $28: k := 'Down';
      $2D: k := 'Ins';
      $2E: k := 'Del';
      $30..$5A: k := Chr(aRow.acKey);
      $70..$87: k := 'F' + IntToStr(aRow.acKey - $6F);
      $BB: k := '=';
      $BC: k := ',';
      $BD: k := '-';
      $BE: k := '.';
      $BF: k := '/';
      $C0: k := '`';
      $DB: k := '[';
      $DC: k := '\';
      $DD: k := ']';
      $DE: k := '''';
   else
      k := 'VK_$' + IntToHex(aRow.acKey, 2);
   end;
   Result := Result + k;
end;

procedure TAcceleratorTests.Test_TableIsNotEmpty;
begin
   BeginTest('Test_TableIsNotEmpty');
   // A FLOOR.  A table that shrank to nothing would pass every other test here
   // while the program silently lost its keyboard.
   CheckTrue(Length(ACCELERATORS) >= 90,
             'the table holds at least 90 bindings (96 as of 2026-08-25)');
end;

procedure TAcceleratorTests.Test_NoDuplicateKeystroke;
var
   i, j: integer;
begin
   BeginTest('Test_NoDuplicateKeystroke');
   // INSTALLED rows only. Two rows may legitimately show the same keystroke when
   // one of them is display-only: 10337 menu_alt_x shows Alt+X because 10002
   // menu_exit is bound to it and both run ExitProgram(True). What must never
   // happen is two rows both HANDED TO WINDOWS for one key -- that is the
   // ambiguity Alt+P had, and Windows resolves it by picking one silently.
   for i := Low(ACCELERATORS) to High(ACCELERATORS) - 1 do
      begin
      if not ACCELERATORS[i].acInstall then
         begin
         Continue;
         end;
      for j := i + 1 to High(ACCELERATORS) do
         begin
         if not ACCELERATORS[j].acInstall then
            begin
            Continue;
            end;
         CheckFalse((ACCELERATORS[i].acKey   = ACCELERATORS[j].acKey) and
                    (ACCELERATORS[i].acCtrl  = ACCELERATORS[j].acCtrl) and
                    (ACCELERATORS[i].acAlt   = ACCELERATORS[j].acAlt) and
                    (ACCELERATORS[i].acShift = ACCELERATORS[j].acShift),
                    Format('%s is claimed by both command %d and command %d',
                           [ACCELERATORS[i].acDisplay, ACCELERATORS[i].acId,
                            ACCELERATORS[j].acId]));
         end;
      end;
end;

procedure TAcceleratorTests.Test_DisplayTextMatchesTheBinding;
var
   i: integer;
begin
   BeginTest('Test_DisplayTextMatchesTheBinding');
   // THE POINT OF THE WHOLE TABLE.  The caption an operator reads and the
   // keystroke Windows fires now come from one row; this is what stops them
   // drifting the way the .RES and the _HK constants did.
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      CheckEquals(RenderRow(ACCELERATORS[i]), ACCELERATORS[i].acDisplay,
                  Format('command %d display text', [ACCELERATORS[i].acId]));
      end;
end;

procedure TAcceleratorTests.Test_EveryRowHasAKeyAndACommand;
var
   i: integer;
begin
   BeginTest('Test_EveryRowHasAKeyAndACommand');
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      // A zero key or a zero command is a legal-looking record that binds
      // nothing -- the silent-zero shape, again.
      CheckTrue(ACCELERATORS[i].acKey <> 0,
                Format('row %d has a key', [i]));
      CheckTrue(ACCELERATORS[i].acId <> 0,
                Format('row %d has a command id', [i]));
      CheckTrue(ACCELERATORS[i].acDisplay <> '',
                Format('row %d has display text', [i]));
      end;
end;

procedure TAcceleratorTests.Test_LookupFindsAndMisses;
begin
   BeginTest('Test_LookupFindsAndMisses');
   // Alt+P moved to 10317 menu_alt_p on 2026-08-17 (NY4I), and 10101
   // menu_messages gave it up.  Pinned in both directions, because half of
   // that change is a DELETION and a deletion is what silently comes back.
   CheckEquals('Alt+P', AcceleratorDisplayFor(10317), 'menu_alt_p owns Alt+P');
   CheckEquals('', AcceleratorDisplayFor(10101), 'menu_messages has no accelerator');
   CheckEquals('', AcceleratorDisplayFor(0), 'an unknown id has no accelerator');
   // A binding no menu row displays -- 25 of the 96 are like this, and they are
   // exactly what a transcription of the captions would have lost.
   CheckEquals('Ctrl+T', AcceleratorDisplayFor(10608), 'POTA repeat kept its key');
end;

// A display-only row exists so the MENU can show a keystroke that something
// else answers -- the message loop (PgUp/PgDn), another command id (Alt+X), or
// in one case nothing at all (Alt+-, a known defect). Handing those to Windows
// would create a second binding for a key already spoken for.
//
// Pinned because the flag is a boolean whose default is False: a row added
// without stating acInstall silently stops being a keyboard binding while still
// looking like one on the menu.
procedure TAcceleratorTests.Test_DisplayOnlyRowsAreNotInstalled;
var
   i, installed, displayOnly: integer;
begin
   BeginTest('Test_DisplayOnlyRowsAreNotInstalled');
   installed := 0;
   displayOnly := 0;
   for i := Low(ACCELERATORS) to High(ACCELERATORS) do
      begin
      if ACCELERATORS[i].acInstall then
         begin
         Inc(installed);
         end
      else
         begin
         Inc(displayOnly);
         end;
      end;

   { 97 until 2026-08-25, when Ctrl+Alt+N went with the Synchronize-PC-time
     menu item -- setting the clock needs UAC elevation TR4W never asked for.
     The startup NTP CHECK is unaffected: it warns, it never set the clock. }
   CheckEquals(96, installed, 'installed bindings (the table read out of the binary)');
   CheckEquals(4, displayOnly, 'display-only rows');

   // Named individually: each is here for a DIFFERENT reason and losing any one
   // of them removes a keystroke from the menu without removing the behaviour.
   CheckEquals('PgUp', AcceleratorDisplayFor(10503), 'CW speed up, bound by the message loop');
   CheckEquals('PgDn', AcceleratorDisplayFor(10504), 'CW speed down, bound by the message loop');
   CheckEquals('Alt+X', AcceleratorDisplayFor(10337), 'Alt+X, answered by 10002');
   CheckEquals('Alt+-', AcceleratorDisplayFor(10320), 'Alt+-, advertised and unbound');
end;

procedure TAcceleratorTests.RunAllTests;
begin
   Test_TableIsNotEmpty;
   Test_NoDuplicateKeystroke;
   Test_DisplayTextMatchesTheBinding;
   Test_EveryRowHasAKeyAndACommand;
   Test_LookupFindsAndMisses;
   Test_DisplayOnlyRowsAreNotInstalled;
end;

end.

unit uTestFunctionKeyBank;

(* WHICH FUNCTION-KEY BANK THE MODIFIERS SELECT (issue #3).

  One rule decides it for the labels, for the row the right-click editor
  opens and for the memory a key press sends: uFunctionKeys.BankForModifiers.
  Before issue #3 the send asked Ctrl first and the editor asked Alt first, so
  with both held the two disagreed. These pins hold the rule the SEND always
  had -- Ctrl wins -- so a later edit cannot silently move the labels away
  from what the key does.

  The window's half is pinned on the real (streamed, never shown) form: the
  release timer runs while a Ctrl or Alt bank is shown and stops at the plain
  one -- never starting is the defect, never stopping is an idle wake-up.
  What these cannot see is that the press is noticed with focus anywhere and
  that the keyboard's release is read back; that needs a running program, see
  docs/BENCH_QUEUE.md. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TFunctionKeyBankTests = class(TTestCase)
   protected
      procedure TestNoModifierIsThePlainBank;
      procedure TestCtrlIsTheCtrlBank;
      procedure TestAltIsTheAltBank;
      procedure TestCtrlWinsWhenBothAreHeld;
      procedure TestBanksAreTheMemoryOffsets;
      procedure TestTheReleaseTimerRunsOnlyWhileABankIsUp;
      procedure TestAStaleModifierSendsThePlainBank;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Forms, uFunctionKeys, uFunctionKeysForm;

procedure TFunctionKeyBankTests.TestNoModifierIsThePlainBank;
begin
   BeginTest('TestNoModifierIsThePlainBank');
   CheckEquals(FKEY_BANK_PLAIN, BankForModifiers(False, False),
               'no modifier held shows F1..F12');
end;

procedure TFunctionKeyBankTests.TestCtrlIsTheCtrlBank;
begin
   BeginTest('TestCtrlIsTheCtrlBank');
   CheckEquals(FKEY_BANK_CTRL, BankForModifiers(True, False),
               'Ctrl held shows CtrlF1..CtrlF12');
end;

procedure TFunctionKeyBankTests.TestAltIsTheAltBank;
begin
   BeginTest('TestAltIsTheAltBank');
   CheckEquals(FKEY_BANK_ALT, BankForModifiers(False, True),
               'Alt held shows AltF1..AltF12');
end;

procedure TFunctionKeyBankTests.TestCtrlWinsWhenBothAreHeld;
begin
   BeginTest('TestCtrlWinsWhenBothAreHeld');
   CheckEquals(FKEY_BANK_CTRL, BankForModifiers(True, True),
               'Ctrl and Alt held: the Ctrl bank, which is what the key sends');
end;

procedure TFunctionKeyBankTests.TestBanksAreTheMemoryOffsets;
begin
   BeginTest('TestBanksAreTheMemoryOffsets');
   (* The bank is added to a key code (112..123) to index the memories, whose
     rows run F1..F12, CtrlF1..CtrlF12, AltF1..AltF12 -- twelve apart. *)
   CheckEquals(0,  FKEY_BANK_PLAIN, 'plain bank offset');
   CheckEquals(12, FKEY_BANK_CTRL,  'Ctrl bank offset');
   CheckEquals(24, FKEY_BANK_ALT,   'Alt bank offset');
end;

procedure TFunctionKeyBankTests.TestTheReleaseTimerRunsOnlyWhileABankIsUp;
var
   created: boolean;
begin
   BeginTest('TestTheReleaseTimerRunsOnlyWhileABankIsUp');
   (* The widget set registers its window classes here; a timer or a handle
     asked for before it fails. Repeat calls are harmless. *)
   Application.Initialize;

   created := (TR4WFunctionKeysForm = nil);
   if created then
      begin
      CreateTR4WFunctionKeysWindow;
      end;
   try
      ShowFunctionKeyBank(FKEY_BANK_PLAIN);
      CheckFalse(TR4WFunctionKeysForm.WatchModifiers,
                 'at rest the release timer is off');

      ShowFunctionKeyBank(FKEY_BANK_CTRL);
      CheckTrue(TR4WFunctionKeysForm.WatchModifiers,
                'a Ctrl bank shown starts the release timer');

      (* A held Ctrl repeats its key-down. *)
      ShowFunctionKeyBank(FKEY_BANK_CTRL);
      CheckTrue(TR4WFunctionKeysForm.WatchModifiers,
                'a repeated Ctrl press leaves the timer running');

      ShowFunctionKeyBank(FKEY_BANK_ALT);
      CheckTrue(TR4WFunctionKeysForm.WatchModifiers,
                'an Alt bank shown keeps the release timer running');

      ShowFunctionKeyBank(FKEY_BANK_PLAIN);
      CheckFalse(TR4WFunctionKeysForm.WatchModifiers,
                 'the plain bank shown stops the release timer');
   finally
      if created then
         begin
         FreeAndNil(TR4WFunctionKeysForm);
         end;
   end;
end;

(* AFTER A SWITCH AWAY THE LABELS SHOW THE PLAIN BANK, AND THE SEND MUST AGREE
  (review M11). The keyboard can still report Alt held after Alt-Tab on Win32,
  so while the report is stale every caller -- labels, editor row, key, click,
  keypad -- gets the plain bank. Pinned on the pure rule: a test cannot hold a
  key down. *)
procedure TFunctionKeyBankTests.TestAStaleModifierSendsThePlainBank;
begin
   BeginTest('TestAStaleModifierSendsThePlainBank');
   CheckEquals(FKEY_BANK_PLAIN, EffectiveFunctionKeyBank(False, True, True),
               'a stale Alt sends the plain bank the labels show');
   CheckEquals(FKEY_BANK_PLAIN, EffectiveFunctionKeyBank(True, False, True),
               'a stale Ctrl sends the plain bank');
   CheckEquals(FKEY_BANK_ALT, EffectiveFunctionKeyBank(False, True, False),
               'a fresh Alt sends the Alt bank');
   CheckEquals(FKEY_BANK_CTRL, EffectiveFunctionKeyBank(True, True, False),
               'fresh, the one rule still applies: Ctrl wins');

   (* The latch is cleared by a modifier press this program sees; with no key
     held in a test run, the live answer is plain either way. *)
   NoteFunctionKeyModifiersStale;
   CheckEquals(FKEY_BANK_PLAIN, LiveFunctionKeyBank, 'stale: plain');
   NoteFunctionKeyModifierPressed;
   CheckEquals(FKEY_BANK_PLAIN, LiveFunctionKeyBank, 'nothing held: plain');
end;

procedure TFunctionKeyBankTests.RunAllTests;
begin
   TestNoModifierIsThePlainBank;
   TestCtrlIsTheCtrlBank;
   TestAltIsTheAltBank;
   TestCtrlWinsWhenBothAreHeld;
   TestBanksAreTheMemoryOffsets;
   TestTheReleaseTimerRunsOnlyWhileABankIsUp;
   TestAStaleModifierSendsThePlainBank;
end;

end.

unit uTestTXInhibitAlert;
{$I ..\..\src\tr4w.inc}

(*
  ISSUE #97, PHASE 2: WHEN THE OPERATOR IS TOLD A KEY-UP IS NOT RADIATING.

  uTXInhibitAlert is the decision with no LCL, no radio record and no thread, so
  every rule is pinned here with plain calls:

  - nothing is shown while receiving, inhibited or not -- it never nags;
  - keyed AND inhibited shows it, with the radio's words;
  - one warning (log line, optional beep) per KEY-UP, however often the status
    is re-read and however many pieces a message goes out in;
  - it ends on unkey, or when the condition clears;
  - a key-up TR4W started shows at once, survives an RX report that lands before
    the radio keys, and ends on the radio's RX once it has been seen keyed --
    or, if the radio never reports TX, when the wait expires;
  - the PTT indicator's role puts the inhibited key-up above ordinary TX.

  The same rules through the real main form and the real CW facade are in
  uTestStatusAndNotice and uTestCWKeyer.
*)

interface

uses
   uTR4WTestFramework,
   LogRadio;    (* RadioPtr, for SetSettledTXState *)

type
   TTXInhibitAlertTests = class(TTestCase)
   protected
      procedure Test_ReceivingNeverShows;
      procedure Test_RadioKeyUpWhileInhibited_ShowsWithTheRadiosWords;
      procedure Test_OneWarningPerKeyUp_NotPerStatusRead;
      procedure Test_UnkeyClearsIt;
      procedure Test_ConditionClearingClearsIt;
      procedure Test_NotInhibited_IsAnOrdinaryKeyUp;
      procedure Test_ProgramKeyUp_ShowsBeforeTheRadioReportsTX;
      procedure Test_ProgramKeyUp_SurvivesAnEarlyRX_EndsOnRXAfterTX;
      procedure Test_ProgramKeyUp_PiecesOfOneMessageWarnOnce;
      procedure Test_ProgramUnkeyEndsIt;
      procedure Test_WaitExpiry_EndsOnlyAnUnconfirmedKeyUp;
      procedure Test_BeepOnlyWhenEnabled_AndOnlyWithTheWarning;
      procedure Test_PTTIndicatorRole;
      procedure Test_ABadTranslationFallsBackToEnglish;
   public
      procedure RunAllTests; override;
   end;

(* PUT A RADIO'S SETTLED STATUS WHERE A TEST WANTS IT: transmitting or not,
  inhibited or not, with the radio's words.  Through the seqlock, exactly as the
  polling thread publishes it, so RadioTXInhibited and ReadRadioStatus read it
  as they would in the program.  Shared by the facade test (uTestCWKeyer) and
  the main-form test (uTestStatusAndNotice), so the two cannot set it up
  differently. *)
procedure SetSettledTXState(rig: RadioPtr; const aTX, aInhibited: boolean;
                            const aReason: string);

implementation

uses
   SysUtils, uTXInhibitAlert,
   uAppStrings;    (* STXInhibitedStatus *)

procedure SetSettledTXState(rig: RadioPtr; const aTX, aInhibited: boolean;
                            const aReason: string);
begin
   BeginStatusPublish(rig);
   try
      rig^.FilteredStatus.TXOn := aTX;
      rig^.FilteredStatus.TXInhibited := aInhibited;
      rig^.FilteredStatus.TXInhibitReason := aReason;
   finally
      EndStatusPublish(rig);
   end;
end;

const
   K4_REASON = 'TX test mode';
   K4_STATUS = 'TX INHIBITED: TX test mode';

function Warned(a: TTXInhibitAlert): boolean;
var
   beep: boolean;
begin
   Result := a.TakeKeyUpWarning(beep);
end;

procedure TTXInhibitAlertTests.Test_ReceivingNeverShows;
var
   a: TTXInhibitAlert;
begin
   BeginTest('Receiving on an inhibited radio shows nothing and warns nothing');
   a := TTXInhibitAlert.Create;
   try
      a.RadioReport(False, True, K4_REASON);
      a.RadioReport(False, True, K4_REASON);
      CheckFalse(a.Showing, 'not keyed: no alert, whatever the condition');
      CheckFalse(Warned(a), 'and no warning');
      CheckEquals('', a.StatusText, 'and no status text');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_RadioKeyUpWhileInhibited_ShowsWithTheRadiosWords;
var
   a: TTXInhibitAlert;
begin
   BeginTest('Trigger 2: the radio reports TX while inhibited -- shown, in its words');
   a := TTXInhibitAlert.Create;
   try
      a.RadioReport(True, True, K4_REASON);
      CheckTrue(a.Showing, 'keyed and inhibited: the alert is up');
      CheckEquals(K4_REASON, a.Reason, 'the radio''s own words');
      CheckEquals(K4_STATUS, a.StatusText, 'the status panel''s sentence');
      CheckTrue(Warned(a), 'and the key-up is warned');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_OneWarningPerKeyUp_NotPerStatusRead;
var
   a: TTXInhibitAlert;
   i: integer;
   warnings: integer;
begin
   BeginTest('One warning per key-up, not per status read; a second key-up warns again');
   a := TTXInhibitAlert.Create;
   try
      warnings := 0;
      for i := 1 to 20 do
         begin
         a.RadioReport(True, True, K4_REASON);
         if Warned(a) then
            begin
            Inc(warnings);
            end;
         end;
      CheckEquals(1, warnings, 'twenty reads of one key-up warn once');

      a.RadioReport(False, True, K4_REASON);
      CheckFalse(Warned(a), 'the unkey is not a warning');

      a.RadioReport(True, True, K4_REASON);
      CheckTrue(Warned(a), 'the NEXT key-up warns again');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_UnkeyClearsIt;
var
   a: TTXInhibitAlert;
begin
   BeginTest('Unkey takes the alert down');
   a := TTXInhibitAlert.Create;
   try
      a.RadioReport(True, True, K4_REASON);
      CheckTrue(a.Showing, 'precondition: up');
      a.RadioReport(False, True, K4_REASON);
      CheckFalse(a.Showing, 'unkeyed: down, though the radio is still inhibited');
      CheckEquals('', a.StatusText, 'and the status text goes with it');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_ConditionClearingClearsIt;
var
   a: TTXInhibitAlert;
begin
   BeginTest('The condition clearing mid key-up takes the alert down');
   a := TTXInhibitAlert.Create;
   try
      a.RadioReport(True, True, K4_REASON);
      CheckTrue(a.Showing, 'precondition: up');
      a.RadioReport(True, False, '');
      CheckFalse(a.Showing, 'TS0 while keyed: down');
      CheckEquals('', a.Reason, 'and no reason is kept');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_NotInhibited_IsAnOrdinaryKeyUp;
var
   a: TTXInhibitAlert;
begin
   BeginTest('Keyed and not inhibited: no alert, no warning');
   a := TTXInhibitAlert.Create;
   try
      a.ProgramKeyed;
      a.RadioReport(True, False, '');
      CheckFalse(a.Showing, 'an ordinary key-up raises nothing');
      CheckFalse(Warned(a), 'and warns nothing');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_ProgramKeyUp_ShowsBeforeTheRadioReportsTX;
var
   a: TTXInhibitAlert;
begin
   BeginTest('Trigger 1: TR4W keys an inhibited radio -- shown at once, no TX report needed');
   a := TTXInhibitAlert.Create;
   try
      a.RadioReport(False, True, K4_REASON);      (* receiving, test mode on *)
      a.ProgramKeyed;
      CheckTrue(a.Showing, 'shown the moment TR4W keys, ahead of the radio');
      CheckTrue(Warned(a), 'and warned then');
      CheckTrue(a.AwaitingRadioTX, 'waiting for the radio to confirm');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_ProgramKeyUp_SurvivesAnEarlyRX_EndsOnRXAfterTX;
var
   a: TTXInhibitAlert;
begin
   BeginTest('Trigger 1: an RX before the radio keys does not end it; RX after TX does');
   a := TTXInhibitAlert.Create;
   try
      a.RadioReport(False, True, K4_REASON);
      a.ProgramKeyed;

      (* The keyer abort is 'KY <abort>;RX;' -- a poll can report RX after TR4W
        has keyed and before the radio has. *)
      a.RadioReport(False, True, K4_REASON);
      CheckTrue(a.Showing, 'an RX before any TX sighting is not the unkey');

      a.RadioReport(True, True, K4_REASON);
      CheckTrue(a.Showing, 'the radio confirms TX');
      CheckFalse(a.AwaitingRadioTX, 'confirmed: no longer waiting');

      a.RadioReport(False, True, K4_REASON);
      CheckFalse(a.Showing, 'RX after TX ends the key-up TR4W started');

      a.RadioReport(False, True, K4_REASON);
      CheckFalse(a.Showing, 'and it stays down while receiving');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_ProgramKeyUp_PiecesOfOneMessageWarnOnce;
var
   a: TTXInhibitAlert;
   warnings: integer;
   i: integer;
begin
   BeginTest('A message sent in pieces, with the radio''s TX report, warns once');
   a := TTXInhibitAlert.Create;
   try
      warnings := 0;
      a.RadioReport(False, True, K4_REASON);
      for i := 1 to 4 do
         begin
         a.ProgramKeyed;                           (* AddStringToBuffer, per piece *)
         if Warned(a) then
            begin
            Inc(warnings);
            end;
         a.RadioReport(True, True, K4_REASON);     (* and the radio keyed *)
         if Warned(a) then
            begin
            Inc(warnings);
            end;
         end;
      CheckEquals(1, warnings, 'one key-up, one warning');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_ProgramUnkeyEndsIt;
var
   a: TTXInhibitAlert;
begin
   BeginTest('TR4W dropping PTT ends a key-up the radio never reported');
   a := TTXInhibitAlert.Create;
   try
      a.RadioReport(False, True, K4_REASON);
      a.ProgramKeyed;
      CheckTrue(a.Showing, 'precondition: up');
      a.ProgramUnkeyed;
      CheckFalse(a.Showing, 'PTT off: down');
      CheckFalse(a.AwaitingRadioTX, 'and nothing is waited for');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_WaitExpiry_EndsOnlyAnUnconfirmedKeyUp;
var
   a: TTXInhibitAlert;
begin
   BeginTest('The wait ending takes down an unconfirmed key-up, never a confirmed one');
   a := TTXInhibitAlert.Create;
   try
      a.RadioReport(False, True, K4_REASON);
      a.ProgramKeyed;
      a.ProgramKeyExpired;
      CheckFalse(a.Showing, 'the radio never keyed: the alert must not sit over RX');

      a.ProgramKeyed;
      a.RadioReport(True, True, K4_REASON);
      a.ProgramKeyExpired;
      CheckTrue(a.Showing, 'confirmed by the radio: only its RX ends it');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_BeepOnlyWhenEnabled_AndOnlyWithTheWarning;
var
   a: TTXInhibitAlert;
   beep: boolean;
begin
   BeginTest('The beep follows the setting, and only on the key-up''s warning');
   a := TTXInhibitAlert.Create;
   try
      a.BeepEnabled := False;
      a.RadioReport(True, True, K4_REASON);
      CheckTrue(a.TakeKeyUpWarning(beep), 'precondition: warned');
      CheckFalse(beep, 'setting off: no beep');

      a.RadioReport(False, True, K4_REASON);
      a.BeepEnabled := True;
      a.RadioReport(True, True, K4_REASON);
      CheckTrue(a.TakeKeyUpWarning(beep), 'second key-up warned');
      CheckTrue(beep, 'setting on: beep');

      a.RadioReport(True, True, K4_REASON);
      CheckFalse(a.TakeKeyUpWarning(beep), 'the same key-up re-read: no warning');
      CheckFalse(beep, 'and no beep');
   finally
      a.Free;
   end;
end;

procedure TTXInhibitAlertTests.Test_PTTIndicatorRole;
begin
   BeginTest('PTT indicator role: idle, transmitting, inhibited');
   CheckTrue(PTTIndicatorRole(False, False) = tirIdle, 'off, no alert: idle');
   CheckTrue(PTTIndicatorRole(True, False) = tirTransmitting, 'on, no alert: transmitting');
   CheckTrue(PTTIndicatorRole(True, True) = tirInhibited, 'on, alert: inhibited');
   CheckTrue(PTTIndicatorRole(False, True) = tirInhibited,
             'alert before the PTT state catches up: inhibited -- trigger 1 is not ' +
             'behind the radio''s report');
end;

(* STXInhibitedStatus IS A TRANSLATABLE FORMAT, and unreviewed translations
  ship.  One that will not take the reason must not raise on the keying path:
  the sentence falls back to the English.  And the English fallback is the
  resourcestring's own English, so the two cannot drift. *)
procedure TTXInhibitAlertTests.Test_ABadTranslationFallsBackToEnglish;
var
   text: string;
   raised: boolean;
begin
   BeginTest('A translation that will not take the reason falls back to the English');
   raised := False;
   try
      text := TXInhibitedStatusText('TX %d', K4_REASON);
   except
      raised := True;
   end;
   CheckFalse(raised, 'a bad format string must not raise');
   CheckEquals(K4_STATUS, text, 'it falls back to the English sentence');
   CheckEquals(Format(STXInhibitedStatus, [K4_REASON]),
               TXInhibitedStatusText('%d %d %d', K4_REASON),
               'the fallback is the resourcestring''s own English');
   CheckEquals(K4_STATUS, TXInhibitedStatusText(STXInhibitedStatus, K4_REASON),
               'a good format is used as it is');
end;

procedure TTXInhibitAlertTests.RunAllTests;
begin
   Test_ReceivingNeverShows;
   Test_RadioKeyUpWhileInhibited_ShowsWithTheRadiosWords;
   Test_OneWarningPerKeyUp_NotPerStatusRead;
   Test_UnkeyClearsIt;
   Test_ConditionClearingClearsIt;
   Test_NotInhibited_IsAnOrdinaryKeyUp;
   Test_ProgramKeyUp_ShowsBeforeTheRadioReportsTX;
   Test_ProgramKeyUp_SurvivesAnEarlyRX_EndsOnRXAfterTX;
   Test_ProgramKeyUp_PiecesOfOneMessageWarnOnce;
   Test_ProgramUnkeyEndsIt;
   Test_WaitExpiry_EndsOnlyAnUnconfirmedKeyUp;
   Test_BeepOnlyWhenEnabled_AndOnlyWithTheWarning;
   Test_PTTIndicatorRole;
   Test_ABadTranslationFallsBackToEnglish;
end;

end.

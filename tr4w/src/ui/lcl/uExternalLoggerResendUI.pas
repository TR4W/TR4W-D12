unit uExternalLoggerResendUI;
(* THE RESYNC BUTTON'S DIALOGS, ONCE, for every window that has one (the
   Preferences > External Logger grid and the standalone External loggers
   window; NY4I, 2026-11-24: "ONE implementation shared by both windows").

   Lifted out of uExternalLoggerGrid unchanged: the confirmation text, the
   duplicate-safe rules and the summary are what they were. The decisions are
   uExternalLoggerActions' and uExternalLoggerStatusModel's (pure, tested); the
   queueing is uLogStore.LogStoreResendToExternalLogger's, in one transaction.
   This unit is only the questions and the answers. *)
{$I ..\..\tr4w.inc}
interface
uses
   uExternalLoggerConfig, uExternalLoggerService;

(* THE RESYNC BUTTON. A logger that is switched off, not running yet or not
   applied yet is refused first with the reason (the dialog would only say the
   same thing after asking a question); otherwise the Resend dialog. aState is
   the logger's state as the window shows it. *)
procedure ResyncLogger(const aDefinition: TExternalLoggerDefinition;
   aState: TExternalLoggerState);

(* RESEND QSOs (issue 356): two choices and a confirmation. 'Resend all' asks
   again, because it can put a contact at the destination twice. Cancel is both
   the default and Escape. *)
procedure ResendQsosDialog(const aDefinition: TExternalLoggerDefinition);

(* The operator's words for a refusal code of LogStoreResendToExternalLogger. *)
function ResendRefusalText(const aCode: string): string;

implementation
uses
   SysUtils, Forms, Dialogs, Controls, LCLType, uAppStrings, uExternalLoggerActions,
   uExternalLoggerStatusModel, uLogStore, utils_text;

function ResendRefusalText(const aCode: string): string;
begin
   if aCode = 'RESEND_NOT_RUNNING' then
      begin
      Result := SLoggerResendWhyNotRunning;
      end
   else if aCode = 'RESEND_NOT_ACTIVE' then
      begin
      Result := SLoggerResendWhyNotActive;
      end
   else if aCode = 'SYNCHRONIZATION_GAP' then
      begin
      Result := SLoggerResendWhyPaused;
      end
   else if aCode = 'LOGGER_SETUP_REQUIRED' then
      begin
      Result := SLoggerResendWhySetup;
      end
   else if aCode = 'RESEND_NOT_SUPPORTED' then
      begin
      Result := SLoggerResendWhyUnsupported;
      end
   else if aCode = 'RESEND_NO_LOG' then
      begin
      Result := SLoggerResendWhyNoLog;
      end
   else
      begin
      Result := SLoggerResendWhyFailed;
      end;
end;

procedure ResyncLogger(const aDefinition: TExternalLoggerDefinition;
   aState: TExternalLoggerState);
begin
   if aDefinition = nil then
      begin
      Exit;
      end;
   case ResyncPreflight(aState) of
      rpSwitchedOff:
         begin
         MessageDlg(UTF8Encode(SLoggerResyncWhySwitchedOff), mtInformation, [mbOK], 0);
         Exit;
         end;
      rpNotRunning:
         begin
         MessageDlg(UTF8Encode(ResendRefusalText('RESEND_NOT_RUNNING')), mtInformation, [mbOK], 0);
         Exit;
         end;
      rpNotActive:
         begin
         MessageDlg(UTF8Encode(ResendRefusalText('RESEND_NOT_ACTIVE')), mtInformation, [mbOK], 0);
         Exit;
         end;
   end;
   ResendQsosDialog(aDefinition);
end;

(* The decisions are uExternalLoggerActions's; the queueing is
   LogStoreResendToExternalLogger's, in one transaction. The QuestionDlg
   captions are LclText (ansi) and the answer is read by RESULT, never by button
   position (GTK draws them the other way round). *)
procedure ResendQsosDialog(const aDefinition: TExternalLoggerDefinition);
var
   answer: TModalResult;
   mode: TResendMode;
   tally: TResendTally;
   refusal, summary: string;
begin
   if aDefinition = nil then
      begin
      Exit;
      end;
   answer := QuestionDlg('TR4W',
                         LclText(UnicodeFormat(SLoggerResendBody, [aDefinition.Name]) +
                            #10#10 + SLoggerResendDuplicateNote),
                         mtConfirmation,
                         [mrOk,     LclText(SLoggerResendUndelivered),
                          mrYes,    LclText(SLoggerResendAll),
                          mrCancel, 'IsDefault', 'IsCancel'], 0);
   if answer = mrOk then
      begin
      mode := rmUndelivered;
      end
   else if answer = mrYes then
      begin
      mode := rmAll;
      if MessageDlg(UTF8Encode(UnicodeFormat(SLoggerResendAllAsk, [aDefinition.Name])),
         mtWarning, [mbYes, mbNo], 0) <> mrYes then
         begin
         Exit;
         end;
      end
   else
      begin
      Exit;
      end;
   tally := TResendTally.Create;
   try
      if LogStoreResendToExternalLogger(aDefinition.DeliveryId, mode, tally, refusal) then
         begin
         summary := UnicodeFormat(SLoggerResendDone,
            [aDefinition.Name, tally.Queued, tally.Created, tally.Requeued,
             tally.Delivered, tally.AlreadyQueued, tally.Uncertain, tally.NotOurs]);
         if tally.NotDeliverable > 0 then
            begin
            summary := summary + #10#10 +
               UnicodeFormat(SLoggerResendNotDeliverable, [tally.NotDeliverable]);
            end;
         if tally.Resumed then
            begin
            summary := summary + #10#10 + SLoggerResendResumed;
            end;
         MessageDlg(UTF8Encode(summary), mtInformation, [mbOK], 0);
         end
      else
         begin
         MessageDlg(UTF8Encode(UnicodeFormat(SLoggerResendRefused,
            [aDefinition.Name, ResendRefusalText(refusal)])), mtWarning, [mbOK], 0);
         end;
   finally
      tally.Free;
   end;
end;

end.

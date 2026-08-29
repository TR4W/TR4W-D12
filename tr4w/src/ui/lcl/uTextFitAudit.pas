unit uTextFitAudit;
{$I ..\..\tr4w.inc}

(*
  DOES THE TEXT FIT? ASKED FROM INSIDE, WHERE THE ANSWER IS KNOWABLE.

  The layout was drawn for English. A translation is routinely 20-40% longer --
  'Cancel' becomes 'Cancelar', 'Band map' becomes 'Mapa de bandas' -- and the
  first anyone knows is a clipped caption in a screenshot. NY4I has been finding
  these by eye, one language at a time, and reports German is among the worst.

  WHY THIS IS NOT A SCRIPT OUTSIDE THE PROGRAM. It was tried first:
  test/ui/Test-TextFit.ps1 walks the window tree with EnumChildWindows, asks
  each control for its font and measures with GetTextExtentPoint32W. It reported
  NOTHING clipped in German -- a false negative, and the reason is structural:

    * a TLabel is a TGraphicControl. It has NO WINDOW HANDLE, so the window tree
      cannot see it at all -- and most captions in the converted forms are
      labels;
    * only windows that happen to be OPEN are enumerable, and most dialogs are
      opened from a menu;
    * text that is drawn rather than placed is invisible either way.

  From inside, none of that applies. Screen.Forms reaches every form, Controls
  reaches every child windowed or not, and Canvas.TextWidth measures in the
  control's own font. This is a thing the LCL conversion made possible and the
  Win32 dialogs never could.

  WHAT IT REPORTS. Any control whose caption is wider than the space it has,
  with a small allowance for the border and padding a control draws inside
  itself. Edits, memos, lists and combos are skipped: their content scrolls by
  design, so being wider than the box is not a defect.

  WHAT IT CANNOT SAY. Whether the translation is RIGHT -- only whether it fits.
*)

interface

uses
  Forms;

{ Walk every form that exists and log what does not fit. Returns the count.

  Call it with every form CREATED, which for TR4W means after the main window is
  up: a form that has never been constructed has no controls to measure. }
function AuditTextFit(const aWhy: string): integer;

{ True when --textfit was passed. Kept here so the switch and the audit that
  answers it stay in one file. }
function TextFitAuditRequested: boolean;

{ Audit every form AS IT APPEARS, for the rest of the run.

  A one-shot walk at start-up sees ONE form: the others are constructed when
  they are first opened, so at that moment they have no controls to measure.
  Measured 2026-08-28 -- the first version reported '1 form(s) walked' in every
  language and looked like a clean bill of health.

  With this installed, open the windows you care about -- by hand, or with
  test/ui/Invoke-MenuSmoke.ps1 -- and every one is measured as it shows. }
procedure InstallTextFitAudit;

implementation

uses
  SysUtils, Classes, Controls, StdCtrls, Graphics,
  MainUnit;   // logger

const
  (* Border and padding a control draws inside its own bounds. A button reserves
     room for its focus rectangle, a check box for its indicator. Below this a
     caption is merely snug rather than clipped, and reporting snug ones buries
     the real ones. *)
  SLACK_PX = 6;

var
  (* Captions actually measured on the current walk.
     A form whose captions all fit logs nothing, which makes "0 do not fit"
     indistinguishable from "nothing was measured" -- and the second is what a
     harness gets when the window never opened. Counting what was LOOKED AT is
     what makes a zero worth believing. *)
  GMeasured: integer = 0;

function Scrolls(aControl: TControl): boolean;
{ Content that scrolls is SUPPOSED to exceed its box. }
begin
   Result := (aControl is TCustomEdit) or
             (aControl is TCustomMemo) or
             (aControl is TCustomListBox) or
             (aControl is TCustomComboBox);
end;

function Available(aControl: TControl): integer;
{ The width the caption actually has.

  A check box and a radio button spend part of their width on the indicator, so
  their text has less room than their Width suggests -- which is exactly where a
  long translation goes wrong first. }
begin
   Result := aControl.Width;
   if (aControl is TCheckBox) or (aControl is TRadioButton) then
      begin
      Result := Result - 20;
      end;
end;

function Identify(aControl: TControl): string;
{ What to call a control in a report.

  A control placed in the designer without a Name still gets measured, and
  reporting it as an empty string gives a reader nothing to search for. Fall
  back to its class, which at least says what KIND of thing to look for. }
begin
   Result := aControl.Name;
   if Result = '' then
      begin
      Result := '<unnamed ' + aControl.ClassName + '>';
      end;
end;

function MeasureControl(aControl: TControl; const aForm: string;
                        aCanvas: TCanvas): integer;
var
   caption:    string;
   needs:      integer;
   lines:      integer;
   lineHeight: integer;
   canvas:     TCanvas;
begin
   Result := 0;
   if (not aControl.Visible) or Scrolls(aControl) then
      begin
      Exit;
      end;

   caption := '';
   if aControl is TCustomLabel then
      begin
      caption := TCustomLabel(aControl).Caption;
      end
   else if aControl is TButtonControl then
      begin
      caption := TButtonControl(aControl).Caption;
      end
   else if aControl is TCustomGroupBox then
      begin
      caption := TCustomGroupBox(aControl).Caption;
      end;

   if Trim(caption) = '' then
      begin
      Exit;
      end;
   Inc(GMeasured);

   (* THE FORM'S canvas, handed in. TWinControl does not publish one -- only
      TCustomControl and TGraphicControl do -- so there is no canvas to take
      from an arbitrary parent. The form always has one, and the font below
      is the control's own, which is what actually decides the width. *)
   canvas := aCanvas;
   if canvas = nil then
      begin
      Exit;
      end;

   canvas.Font.Assign(aControl.Font);
   needs := canvas.TextWidth(caption);

   (* A WORD-WRAPPED LABEL IS SUPPOSED TO BE WIDER THAN ITS BOX.

      Measuring one against its Width reports every explanatory paragraph on
      the form as catastrophically clipped -- PrefsForm.lblRelayPortInfo came
      back "1449px over" in ENGLISH, on a label 620px wide and 54px tall that
      renders perfectly in three lines. It was the loudest finding in every
      language and it was noise in all of them.

      For these the question is HEIGHT: does the wrapped text still fit the box
      the designer gave it? A translation 40% longer needs a fourth line and
      the box does not grow. Lines are estimated as width/width rather than
      measured, which UNDER-counts -- wrapping breaks at word boundaries, so
      the real line count is never lower than this. Under-counting is the right
      direction: it can miss a marginal case but it cannot invent one, and a
      false finding here is what buried the real ones. *)
   { TLabel, not TCustomLabel: WordWrap is published one level down. }
   if (aControl is TLabel) and TLabel(aControl).WordWrap then
      begin
      lineHeight := canvas.TextHeight('Wg');
      if lineHeight < 1 then
         begin
         Exit;
         end;
      lines := (needs + Available(aControl) - 1) div Available(aControl);
      if (lines * lineHeight) > aControl.Height then
         begin
         logger.Warn('TextFit: %s.%s wraps to %d line(s) needing %dpx of ' +
                     'height, has %dpx -- "%s"',
                     [aForm, Identify(aControl), lines, lines * lineHeight,
                      aControl.Height, caption]);
         Result := 1;
         end;
      Exit;
      end;

   if needs > (Available(aControl) - SLACK_PX) then
      begin
      logger.Warn('TextFit: %s.%s needs %dpx, has %dpx -- "%s"',
                  [aForm, Identify(aControl), needs, Available(aControl), caption]);
      Result := 1;
      end;
end;

function WalkControls(aParent: TWinControl; const aForm: string;
                      aCanvas: TCanvas): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to aParent.ControlCount - 1 do
      begin
      Inc(Result, MeasureControl(aParent.Controls[i], aForm, aCanvas));
      if aParent.Controls[i] is TWinControl then
         begin
         Inc(Result, WalkControls(TWinControl(aParent.Controls[i]), aForm, aCanvas));
         end;
      end;
end;

function AuditTextFit(const aWhy: string): integer;
var
   i: integer;
begin
   Result := 0;
   GMeasured := 0;
   for i := 0 to Screen.FormCount - 1 do
      begin
      Inc(Result, WalkControls(Screen.Forms[i], Screen.Forms[i].Name,
                               Screen.Forms[i].Canvas));
      end;
   logger.Info('TextFit: %s -- %d form(s) walked, %d caption(s) measured, ' +
               '%d do not fit', [aWhy, Screen.FormCount, GMeasured, Result]);
end;

type
  { A handler needs an object to hang off. Nothing else uses it. }
  TTextFitWatcher = class
     procedure AppIdle(Sender: TObject; var Done: boolean);
  end;

var
  GWatcher: TTextFitWatcher = nil;
  GSeen: TStringList = nil;

procedure MeasureForm(aForm: TCustomForm);
var
   n: integer;
begin
   if (aForm = nil) or (GSeen = nil) then
      begin
      Exit;
      end;
   { A form still being streamed in has no Name yet -- see AppIdle. }
   if aForm.Name = '' then
      begin
      Exit;
      end;
   { Once per form. A form reopened ten times is the same measurement. }
   if GSeen.IndexOf(aForm.Name) >= 0 then
      begin
      Exit;
      end;
   GSeen.Add(aForm.Name);
   GMeasured := 0;
   n := WalkControls(aForm, aForm.Name, aForm.Canvas);
   logger.Info('TextFit: %s -- %d caption(s) measured, %d do not fit',
               [aForm.Name, GMeasured, n]);
end;

procedure TTextFitWatcher.AppIdle(Sender: TObject; var Done: boolean);
(* MEASURE WHEN THE FORM IS UP, NOT WHEN IT IS BORN.

   This hung off Screen.AddHandlerFormAdded until 2026-08-28, and that fires
   from the TCustomForm constructor -- BEFORE the .lfm has been streamed in. At
   that moment the form has no controls and not even a Name, so every window
   measured as

      TextFit:  -- 0 caption(s) measured, 0 do not fit

   an empty name and an empty result, which reads exactly like a clean bill of
   health. Every converted window had been "measured" that way and none of them
   had actually been looked at.

   Idle is the right moment instead: the form is constructed, streamed, sized
   and shown, and the LCL pumps idle inside modal loops too, so a modal dialog
   is measured like any other window. *)
var
   i: integer;
begin
   if GSeen = nil then
      begin
      Exit;
      end;
   { CustomForms, not Forms: a modal dialog lives in the custom list. }
   for i := 0 to Screen.CustomFormCount - 1 do
      begin
      if Screen.CustomForms[i].Visible then
         begin
         MeasureForm(Screen.CustomForms[i]);
         end;
      end;
end;

procedure InstallTextFitAudit;
begin
   if GWatcher <> nil then
      begin
      Exit;
      end;
   GWatcher := TTextFitWatcher.Create;
   GSeen := TStringList.Create;
   GSeen.Sorted := True;
   { No @: in Delphi mode a method reference IS the pointer. }
   Application.AddOnIdleHandler(GWatcher.AppIdle);
   logger.Info('TextFit: auditing every form as it opens; open the windows you want measured');
   AuditTextFit('the forms that already exist');
end;

function TextFitAuditRequested: boolean;
var
   i: integer;
begin
   Result := False;
   for i := 1 to ParamCount do
      begin
      if SameText(ParamStr(i), '--textfit') then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

end.

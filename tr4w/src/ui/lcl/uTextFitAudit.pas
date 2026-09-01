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

function SlackRight(aControl: TControl): integer;
{ How much room is there to GROW this control before it hits something.

  A finding says a caption needs more width than it has. It does not say whether
  that is fixable -- and the two cases want completely different work:

    slack >= the shortfall   widen the control in the .lfm. One line.
    slack <  the shortfall   something else has to move, which is a layout
                             change, or the text has to get shorter.

  Without this every finding looks the same and the only way to tell them apart
  is to open each form in the designer and look. Measured 2026-08-29 after a
  21-language sweep produced about thirty overruns and no way to triage them.

  The nearest sibling to the RIGHT whose vertical extent overlaps ours is what
  we would collide with; with none, the parent's client edge is the limit.
  Siblings that do not overlap vertically are on another row and are irrelevant,
  which is why this is not simply "the next control by Left". }
var
   i, myRight, myTop, myBottom, limit: integer;
   sib: TControl;
begin
   myRight  := aControl.Left + aControl.Width;
   myTop    := aControl.Top;
   myBottom := aControl.Top + aControl.Height;

   if aControl.Parent = nil then
      begin
      Result := 0;
      Exit;
      end;

   limit := aControl.Parent.ClientWidth;

   for i := 0 to aControl.Parent.ControlCount - 1 do
      begin
      sib := aControl.Parent.Controls[i];
      if (sib = aControl) or (not sib.Visible) then
         begin
         Continue;
         end;
      // Another row: cannot collide however wide we grow.
      if (sib.Top + sib.Height <= myTop) or (sib.Top >= myBottom) then
         begin
         Continue;
         end;
      if (sib.Left >= myRight) and (sib.Left < limit) then
         begin
         limit := sib.Left;
         end;
      end;

   Result := limit - myRight;
   if Result < 0 then
      begin
      Result := 0;
      end;
end;

function SlackBelow(aControl: TControl): integer;
{ The same question downwards, for a word-wrapped label that needs another line. }
var
   i, myBottom, myLeft, myRight, limit: integer;
   sib: TControl;
begin
   myBottom := aControl.Top + aControl.Height;
   myLeft   := aControl.Left;
   myRight  := aControl.Left + aControl.Width;

   if aControl.Parent = nil then
      begin
      Result := 0;
      Exit;
      end;

   limit := aControl.Parent.ClientHeight;

   for i := 0 to aControl.Parent.ControlCount - 1 do
      begin
      sib := aControl.Parent.Controls[i];
      if (sib = aControl) or (not sib.Visible) then
         begin
         Continue;
         end;
      if (sib.Left + sib.Width <= myLeft) or (sib.Left >= myRight) then
         begin
         Continue;
         end;
      if (sib.Top >= myBottom) and (sib.Top < limit) then
         begin
         limit := sib.Top;
         end;
      end;

   Result := limit - myBottom;
   if Result < 0 then
      begin
      Result := 0;
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
                     'height, has %dpx, slack %dpx -- "%s"',
                     [aForm, Identify(aControl), lines, lines * lineHeight,
                      aControl.Height, SlackBelow(aControl), caption]);
         Result := 1;
         end;
      Exit;
      end;

   if needs > (Available(aControl) - SLACK_PX) then
      begin
      logger.Warn('TextFit: %s.%s needs %dpx, has %dpx, slack %dpx -- "%s"',
                  [aForm, Identify(aControl), needs, Available(aControl),
                   SlackRight(aControl), caption]);
      Result := 1;
      end;
end;

function MeasureOverhang(aControl: TControl; aParent: TWinControl;
                         const aForm: string): integer;
{ DOES THE CONTROL ITSELF FIT INSIDE ITS PARENT?

  A DIFFERENT QUESTION FROM THE ONE ABOVE, AND THIS AUDIT COULD NOT ASK IT.
  MeasureControl asks whether a CAPTION fits its CONTROL, and returns early when
  the caption is blank -- so a captionless panel was never looked at even once.
  The Open-Contest dialog's yellow prompt panel was designed 20px wider than the
  group box holding it, akRight faithfully preserved that negative margin at
  every window size, and it hung off the right edge of the form from the day it
  was drawn until NY4I photographed it (2026-09-01).

  Nothing else can see this. Lint-LFMProperties asks whether a property can be
  STREAMED, not whether a number is sensible; the form opens, every control
  works, and the overhang is simply drawn.

  ANCHORED CONTROLS ARE THE POINT, not an exception. A control anchored to an
  edge keeps its margin -- including a negative one -- so an overhang designed
  in is an overhang for the life of the form rather than something a resize
  corrects.

  Scrolling parents are exempt: content wider than the viewport is what a scroll
  box is FOR. }
const
   { A pixel or two of rounding is not a defect; twenty is. }
   OVERHANG_PX = 4;
var
   over: integer;
begin
   Result := 0;

   if (not aControl.Visible) or Scrolls(aParent) then
      begin
      Exit;
      end;

   over := (aControl.Left + aControl.Width) - aParent.ClientWidth;
   if over > OVERHANG_PX then
      begin
      logger.Warn('TextFit: %s.%s overhangs its parent by %dpx ' +
                  '(left %d + width %d > client %d)',
                  [aForm, Identify(aControl), over,
                   aControl.Left, aControl.Width, aParent.ClientWidth]);
      Result := 1;
      end;

   over := (aControl.Top + aControl.Height) - aParent.ClientHeight;
   if over > OVERHANG_PX then
      begin
      logger.Warn('TextFit: %s.%s hangs below its parent by %dpx ' +
                  '(top %d + height %d > client %d)',
                  [aForm, Identify(aControl), over,
                   aControl.Top, aControl.Height, aParent.ClientHeight]);
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
      Inc(Result, MeasureOverhang(aParent.Controls[i], aParent, aForm));
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

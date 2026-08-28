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

function MeasureControl(aControl: TControl; const aForm: string;
                        aCanvas: TCanvas): integer;
var
   caption: string;
   needs:   integer;
   canvas:  TCanvas;
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

   (* The canvas is the form's; the FONT below is the control's own.

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

   if needs > (Available(aControl) - SLACK_PX) then
      begin
      logger.Warn('TextFit: %s.%s needs %dpx, has %dpx -- "%s"',
                  [aForm, aControl.Name, needs, Available(aControl), caption]);
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
   for i := 0 to Screen.FormCount - 1 do
      begin
      Inc(Result, WalkControls(Screen.Forms[i], Screen.Forms[i].Name,
                               Screen.Forms[i].Canvas));
      end;
   logger.Info('TextFit: %s -- %d form(s) walked, %d caption(s) do not fit',
               [aWhy, Screen.FormCount, Result]);
end;

type
  { A handler needs an object to hang off. Nothing else uses it. }
  TTextFitWatcher = class
     procedure FormAdded(Sender: TObject; Form: TCustomForm);
  end;

var
  GWatcher: TTextFitWatcher = nil;
  GSeen: TStringList = nil;

procedure TTextFitWatcher.FormAdded(Sender: TObject; Form: TCustomForm);
var
   n: integer;
begin
   if (Form = nil) or (GSeen = nil) then
      begin
      Exit;
      end;
   { Once per form. A form reopened ten times is the same measurement. }
   if GSeen.IndexOf(Form.Name) >= 0 then
      begin
      Exit;
      end;
   GSeen.Add(Form.Name);
   n := WalkControls(Form, Form.Name, Form.Canvas);
   if n > 0 then
      begin
      logger.Warn('TextFit: %s -- %d caption(s) do not fit', [Form.Name, n]);
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
   Screen.AddHandlerFormAdded(GWatcher.FormAdded);
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

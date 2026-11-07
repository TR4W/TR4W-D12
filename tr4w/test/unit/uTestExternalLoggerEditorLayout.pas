unit uTestExternalLoggerEditorLayout;
{$I ..\..\src\tr4w.inc}

(*
  THE EXTERNAL LOGGER EDITOR FITS WHAT ITS TEXT AND CONTROLS MEASURE
  (issue 232).

  The editor's rows were laid out from fixed 96-dpi pixels -- captions 190
  wide, boxes at 200, a 42 px row, Refresh 90 wide -- so a caption or a box
  that measured more than that in the running font was clipped or left its
  row. TExternalLoggersForm.FitLayout now lays the dialog out from measured
  widths and heights. These tests open the real editor for EVERY registered
  provider, SHOW it off screen (uTestShowOffScreen), and measure:

  - no two visible siblings overlap -- on the form, in the fields panel and
    inside each row -- and every control lies inside its parent (so the eye
    sits beside its box, not over it, and Refresh is inside the dialog);
  - no single-line label is clipped (its caption, measured in its font, fits
    its width and height); a word-wrapped label is at least as tall as its
    text wraps to at its width, including the longest field status;
  - Refresh, Save and Cancel are as wide as their captions and their widget
    set want; a drop-down holds its longest item plus DROPDOWN_CHROME_96 as a
    Constraints.MinWidth; the eye is as tall as its box;
  - a second layout moves nothing (it runs on every show and provider change).

  THREE CONDITIONS: the default font; a 14 pt font (about 150% of the 9 pt
  Windows UI font), which is how a wider-font platform is simulated; and the
  form adjusted from 96 to 144 ppi (AutoAdjustLayout), so Scale96ToForm
  returns 1.5 times its argument and every scaled floor is exercised.

  WHAT THIS CANNOT SAY. It runs on the Windows widget set and cannot change
  the monitor's DPI or see cocoa or gtk2 fonts. TR4W's Windows manifest
  declares no DPI awareness, so at 150% Windows stretches the window as a
  bitmap and the program sees 96 ppi: there the layout is the 100% one,
  enlarged. A real 150% display and a Mac are on docs/BENCH_QUEUE.md.

  The bounds are printed (WriteLn) so a failure on another machine can be
  read without a debugger.
*)

interface

uses
   Controls, uExternalLoggersForm, uTR4WTestFramework;

type
   TExternalLoggerEditorLayoutTests = class(TTestCase)
   private
      procedure CheckChildren(const aParent: TWinControl; const aWhere: string);
      procedure CheckFits(const aParent: TWinControl; const aForm: TExternalLoggersForm;
         const aWhere: string);
      procedure RunProvider(const aProviderId: string; const aCondition: integer;
         const aWhere: string);
      procedure RunCondition(const aCondition: integer; const aWhere: string);
   protected
      procedure Test_DefaultFont_Fits;
      procedure Test_LargerFont_Fits;
      procedure Test_144PPI_Fits;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Types, Forms, StdCtrls, ExtCtrls,
   uExternalLoggerConfig, uExternalLoggerRegistry, uPasswordReveal, uAppStrings,
   uLCLFormHelpers, uTestShowOffScreen;

const
   CONDITION_DEFAULT = 0;
   CONDITION_LARGER_FONT = 1;
   CONDITION_144_PPI = 2;
   (* The simulated wider-font platform. *)
   LARGER_FONT_SIZE = 14;
   SIMULATED_PPI = 144;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

function Bounds4(const aControl: TControl): string;
begin
   Result := Format('%s(%s) L%d T%d W%d H%d', [aControl.Name, aControl.ClassName,
      aControl.Left, aControl.Top, aControl.Width, aControl.Height]);
end;

(* Every visible control under aParent lies inside it and overlaps no visible
   sibling. *)
procedure TExternalLoggerEditorLayoutTests.CheckChildren(const aParent: TWinControl;
   const aWhere: string);
var
   i, j: integer;
   a, b: TControl;
   ra, rb, overlap: TRect;
begin
   for i := 0 to aParent.ControlCount - 1 do
      begin
      a := aParent.Controls[i];
      if not a.Visible then
         begin
         Continue;
         end;

      CheckTrue((a.Left >= 0) and (a.Top >= 0) and
         (a.Left + a.Width <= aParent.ClientWidth) and
         (a.Top + a.Height <= aParent.ClientHeight),
         aWhere + ': inside its parent (' + IntToStr(aParent.ClientWidth) + 'x' +
         IntToStr(aParent.ClientHeight) + '): ' + Bounds4(a));

      ra := a.BoundsRect;
      for j := i + 1 to aParent.ControlCount - 1 do
         begin
         b := aParent.Controls[j];
         if not b.Visible then
            begin
            Continue;
            end;
         rb := b.BoundsRect;
         CheckTrue(not IntersectRect(overlap, ra, rb),
            aWhere + ': no overlap: ' + Bounds4(a) + ' / ' + Bounds4(b));
         end;

      if a is TPanel then
         begin
         CheckChildren(TPanel(a), aWhere + ' > ' + a.Name);
         end;
      end;
end;

(* Every visible control under aParent is as big as its content needs. *)
procedure TExternalLoggerEditorLayoutTests.CheckFits(const aParent: TWinControl;
   const aForm: TExternalLoggersForm; const aWhere: string);
var
   i, need, pw, ph: integer;
   ctl, eye: TControl;
begin
   for i := 0 to aParent.ControlCount - 1 do
      begin
      ctl := aParent.Controls[i];
      if not ctl.Visible then
         begin
         Continue;
         end;

      if ctl is TLabel then
         begin
         if TLabel(ctl).WordWrap then
            begin
            ControlPreferredSize(ctl, pw, ph);
            CheckTrue(ph <= ctl.Height,
               aWhere + ': wrapped label holds its text, ' + IntToStr(ph) + ' px high: ' +
               Bounds4(ctl));
            end
         else
            begin
            need := TextWidthInFont(TLabel(ctl).Font, TLabel(ctl).Caption);
            CheckTrue(need <= ctl.Width,
               aWhere + ': label not clipped, text ' + IntToStr(need) + ' px: ' + Bounds4(ctl));
            need := TextHeightInFont(TLabel(ctl).Font, TLabel(ctl).Caption);
            CheckTrue(need <= ctl.Height,
               aWhere + ': label tall enough, text ' + IntToStr(need) + ' px: ' + Bounds4(ctl));
            end;
         end
      else if ctl is TComboBox then
         begin
         need := WidestText(TComboBox(ctl).Font, TComboBox(ctl).Items) +
            aForm.Scale96ToForm(DROPDOWN_CHROME_96);
         CheckTrue(ctl.Width >= need,
            aWhere + ': drop-down holds its longest item plus chrome, need ' +
            IntToStr(need) + ' px: ' + Bounds4(ctl));
         CheckTrue(ctl.Constraints.MinWidth >= need,
            aWhere + ': drop-down width is held as a MinWidth (' +
            IntToStr(ctl.Constraints.MinWidth) + '): ' + Bounds4(ctl));
         end
      else if (ctl is TButton) or (ctl is TCheckBox) then
         begin
         ControlPreferredSize(ctl, pw, ph);
         CheckTrue(pw <= ctl.Width,
            aWhere + ': as wide as its widget set prefers, ' + IntToStr(pw) + ' px: ' +
            Bounds4(ctl));
         if ctl is TButton then
            begin
            need := TextWidthInFont(TButton(ctl).Font, TButton(ctl).Caption);
            end
         else
            begin
            need := TextWidthInFont(TCheckBox(ctl).Font, TCheckBox(ctl).Caption);
            end;
         CheckTrue(need < ctl.Width,
            aWhere + ': wider than its caption, ' + IntToStr(need) + ' px: ' + Bounds4(ctl));
         end
      else if ctl is TEdit then
         begin
         eye := PasswordRevealControl(TEdit(ctl));
         if (eye <> nil) and eye.Visible then
            begin
            CheckTrue(Abs(eye.Height - ctl.Height) <= 2,
               aWhere + ': the eye is as tall as its box: ' + Bounds4(eye) + ' / ' + Bounds4(ctl));
            CheckTrue(Abs(eye.Top - ctl.Top) <= 1,
               aWhere + ': the eye is level with its box: ' + Bounds4(eye) + ' / ' + Bounds4(ctl));
            end;
         end;

      if ctl is TPanel then
         begin
         CheckFits(TPanel(ctl), aForm, aWhere + ' > ' + ctl.Name);
         end;
      end;
end;

function Snapshot(const aParent: TWinControl): string;
var
   i: integer;
begin
   Result := Format('[%dx%d]', [aParent.ClientWidth, aParent.ClientHeight]);
   for i := 0 to aParent.ControlCount - 1 do
      begin
      Result := Result + '; ' + Bounds4(aParent.Controls[i]);
      if aParent.Controls[i] is TWinControl then
         begin
         Result := Result + ' ' + Snapshot(TWinControl(aParent.Controls[i]));
         end;
      end;
end;

procedure TExternalLoggerEditorLayoutTests.RunProvider(const aProviderId: string;
   const aCondition: integer; const aWhere: string);
var
   form: TExternalLoggersForm;
   d: TExternalLoggerDefinition;
   first: string;
begin
   form := TExternalLoggersForm.Create(nil);
   try
      form.AutoLoadChoices := False;
      (* Before the rows exist, so the rows built at run time inherit the font
         and scale their floors at the form's PixelsPerInch. *)
      if aCondition = CONDITION_LARGER_FONT then
         begin
         form.Font.Size := LARGER_FONT_SIZE;
         end
      else if aCondition = CONDITION_144_PPI then
         begin
         form.AutoAdjustLayout(lapAutoAdjustForDPI, form.PixelsPerInch, SIMULATED_PPI,
            form.Width, form.Width * SIMULATED_PPI div 96);
         end;

      d := TExternalLoggerDefinition.Create;
      d.Name := 'Layout';
      d.ProviderId := aProviderId;
      d.ApiKey := 'a-key';
      d.Address := '127.0.0.1';
      d.Port := 52001;
      d.Logbook := 'book-1';
      d.LogbookName := 'A rather long logbook name for the drop-down';
      form.Config.Definitions.Add(d);
      form.BeginEdit(d);
      ShowOffScreen(form);
      Application.ProcessMessages;

      WriteLn('  [ExtLoggerEditor] ', aWhere, ': ppi ', form.PixelsPerInch, ', rows ',
         form.RowCount, ', client ', form.ClientWidth, 'x', form.ClientHeight, '  ',
         Bounds4(form.edtName), '  ', Bounds4(form.pnlFields), '  ', Bounds4(form.btnOK));

      CheckTrue(form.RowCount > 0, aWhere + ': the provider declared rows');
      (* The note is the catalogue's text (issue 233's rule), not the .lfm
         placeholder, and it is what the layout measured. *)
      CheckEquals(UTF8Encode(SLoggerEditorNote), form.lblNote.Caption,
         aWhere + ': the note comes from SLoggerEditorNote');
      CheckChildren(form, aWhere);
      CheckFits(form, form, aWhere);
      CheckTrue(form.btnOK.Visible and form.btnCancel.Visible,
         aWhere + ': Save and Cancel are shown');

      first := Snapshot(form);
      form.FitLayout;
      Application.ProcessMessages;
      CheckEquals(first, Snapshot(form), aWhere + ': a second layout moves nothing');

      (* The longest thing the field status says, arriving after the layout
         (a failed load): the reserved lines hold it. *)
      form.lblFieldStatus.Caption := UTF8Encode(
         UnicodeFormat(SLoggerChoiceFailed, ['INVALID_RESPONSE']));
      Application.ProcessMessages;
      CheckFits(form, form, aWhere + ', failed-load status');
   finally
      form.Free;
   end;
end;

procedure TExternalLoggerEditorLayoutTests.RunCondition(const aCondition: integer;
   const aWhere: string);
var
   i: integer;
   id: string;
begin
   CheckTrue(ExternalLoggerProviderCount > 0, aWhere + ': providers are registered');
   for i := 0 to ExternalLoggerProviderCount - 1 do
      begin
      id := ExternalLoggerRegistration(i).Id;
      RunProvider(id, aCondition, aWhere + ', ' + id);
      end;
end;

procedure TExternalLoggerEditorLayoutTests.Test_DefaultFont_Fits;
begin
   InitWidgetSet;
   BeginTest('ExtLoggerEditor layout: every provider at the default font, nothing overlaps or clips');
   RunCondition(CONDITION_DEFAULT, 'default font');
end;

procedure TExternalLoggerEditorLayoutTests.Test_LargerFont_Fits;
begin
   InitWidgetSet;
   BeginTest('ExtLoggerEditor layout: every provider at a larger font, the dialog grows to fit');
   RunCondition(CONDITION_LARGER_FONT, 'font ' + IntToStr(LARGER_FONT_SIZE) + ' pt');
end;

procedure TExternalLoggerEditorLayoutTests.Test_144PPI_Fits;
begin
   InitWidgetSet;
   BeginTest('ExtLoggerEditor layout: every provider on a form adjusted to 144 ppi, the scaled floors fit');
   RunCondition(CONDITION_144_PPI, IntToStr(SIMULATED_PPI) + ' ppi');
end;

procedure TExternalLoggerEditorLayoutTests.RunAllTests;
begin
   Test_DefaultFont_Fits;
   Test_LargerFont_Fits;
   Test_144PPI_Fits;
end;

end.

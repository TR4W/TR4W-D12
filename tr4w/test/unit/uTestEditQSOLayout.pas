unit uTestEditQSOLayout;
{$I ..\..\src\tr4w.inc}

(*
  THE EDIT QSO WINDOW FITS WHAT ITS TEXT AND CONTROLS MEASURE (NY4I, macOS,
  2026-11-06).

  On cocoa the Band and Mode drop-downs showed "10" and "C" under their own
  arrows, the date picker ran into the Zone label, and "Frequency, Hz",
  "Number Sent" and "Number Rcvd" were clipped. TfrmEditQSO.FitLayout now lays
  the fields out from measured widths. These tests SHOW the real form off
  screen (uTestShowOffScreen), fill the drop-downs with the lists the load
  puts in them, lay it out and measure:

  - no two visible siblings overlap, on the form and inside the our-station
    group, and every control lies inside its parent;
  - no label is clipped: its caption, measured in its own font, fits its width;
  - each drop-down is at least its longest item plus the stated chrome
    allowance (DROPDOWN_CHROME_96), and holds that width as a
    Constraints.MinWidth, which is what survives cocoa's AutoSize;
  - the date picker, the check boxes and the buttons are at least as wide as
    their widget set prefers;
  - a second layout moves nothing (the form is reused on every open).

  AT THE DEFAULT FONT AND AT A LARGER ONE (14 pt, about 150% of the 9 pt
  Windows UI font), which is how a wider-font platform is simulated here.

  WHAT THIS CANNOT SAY, AND WHY. It runs on the Windows widget set. It cannot
  change the monitor's DPI, and it cannot see cocoa: Win32 reports no
  preferred width for a combo, so the drop-down assertion proves the width is
  set and HELD, not that an NSPopUpButton draws its text clear of its arrows
  at that width. That, and the real Mac fonts, are on docs/BENCH_QUEUE.md.

  AND THE LISTS ARE REPLACED ON EVERY OPEN (issue 237): a second and a third
  fill leave one row per band and per mode, each at its own enum ordinal.

  The bounds are printed (WriteLn) so a failure on another machine can be read
  without a debugger.
*)

interface

uses
   Controls, uEditQSOForm, uTR4WTestFramework;

type
   TEditQSOLayoutTests = class(TTestCase)
   private
      procedure CheckChildren(const aParent: TWinControl; const aWhere: string);
      procedure CheckFits(const aForm: TfrmEditQSO; const aWhere: string);
      procedure RunLayoutChecks(const aFontSize: integer; const aWhere: string);
   protected
      procedure Test_DefaultFont_Fits;
      procedure Test_LargerFont_Fits;
      procedure Test_Reopen_ListsAreReplacedNotAppended;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Types, Forms, StdCtrls, DateTimePicker, VC,
   uLCLFormHelpers, uTestShowOffScreen;

const
   (* The simulated wider-font platform. *)
   LARGER_FONT_SIZE = 14;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

function Bounds4(const aControl: TControl): string;
begin
   Result := Format('%s L%d T%d W%d H%d', [aControl.Name, aControl.Left, aControl.Top,
      aControl.Width, aControl.Height]);
end;

function PreferredWidthOf(const aControl: TControl): integer;
var
   h: integer;
begin
   Result := 0;
   h := 0;
   aControl.GetPreferredSize(Result, h, True, True);
end;

(* The real form, shown off screen, with the load's drop-down lists in it.
   OnShow would run the load against a log the test does not have and close
   the form, so the form's own handlers are taken off first. *)
function MakeForm(const aFontSize: integer): TfrmEditQSO;
begin
   Result := TfrmEditQSO.Create(nil);
   Result.OnShow := nil;
   Result.OnClose := nil;
   Result.OnCloseQuery := nil;

   if aFontSize > 0 then
      begin
      Result.Font.Size := aFontSize;
      end;

   (* The routine the load calls on every open (issue 237). *)
   Result.FillBandAndModeLists;
   Result.cboBand.ItemIndex := 0;
   Result.cboMode.ItemIndex := 0;

   ShowOffScreen(Result);
   Result.FitLayout;
   Application.ProcessMessages;
end;

procedure TEditQSOLayoutTests.CheckChildren(const aParent: TWinControl;
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
      end;
end;

procedure TEditQSOLayoutTests.CheckFits(const aForm: TfrmEditQSO;
                    const aWhere: string);
var
   i: integer;
   c: TComponent;
   ctl: TControl;
   need: integer;
begin
   for i := 0 to aForm.ComponentCount - 1 do
      begin
      c := aForm.Components[i];
      if not (c is TControl) then
         begin
         Continue;
         end;
      ctl := TControl(c);
      if not ctl.Visible then
         begin
         Continue;
         end;

      if ctl is TLabel then
         begin
         need := TextWidthInFont(TLabel(ctl).Font, TLabel(ctl).Caption);
         CheckTrue(need <= ctl.Width,
            aWhere + ': label not clipped, text ' + IntToStr(need) + ' px: ' + Bounds4(ctl));
         end
      else if ctl is TComboBox then
         begin
         need := WidestText(TComboBox(ctl).Font, TComboBox(ctl).Items) +
                 aForm.Scale96ToForm(DROPDOWN_CHROME_96);
         CheckTrue(ctl.Width >= need,
            aWhere + ': drop-down holds its longest item plus chrome, need ' +
            IntToStr(need) + ' px: ' + Bounds4(ctl));
         CheckTrue(ctl.Constraints.MinWidth >= need,
            aWhere + ': drop-down width is held as a MinWidth against AutoSize (' +
            IntToStr(ctl.Constraints.MinWidth) + '): ' + Bounds4(ctl));
         end
      else if (ctl is TCheckBox) or (ctl is TButton) or (ctl is TDateTimePicker) then
         begin
         need := PreferredWidthOf(ctl);
         CheckTrue(need <= ctl.Width,
            aWhere + ': as wide as its widget set prefers, ' + IntToStr(need) + ' px: ' +
            Bounds4(ctl));
         end;
      end;
end;

function Snapshot(const aForm: TfrmEditQSO): string;
var
   i: integer;
begin
   Result := Format('form %dx%d', [aForm.ClientWidth, aForm.ClientHeight]);
   for i := 0 to aForm.ComponentCount - 1 do
      begin
      if aForm.Components[i] is TControl then
         begin
         Result := Result + '; ' + Bounds4(TControl(aForm.Components[i]));
         end;
      end;
end;

procedure TEditQSOLayoutTests.RunLayoutChecks(const aFontSize: integer;
                          const aWhere: string);
var
   form: TfrmEditQSO;
   first: string;
begin
   form := MakeForm(aFontSize);
   try
      WriteLn('  [EditQSO] ', aWhere, ': client ', form.ClientWidth, 'x',
         form.ClientHeight, '  ', Bounds4(form.lblFrequency), '  ',
         Bounds4(form.cboBand), '  ', Bounds4(form.dtpDateTime), '  ',
         Bounds4(form.lblZone), '  ', Bounds4(form.btnCancel));

      CheckChildren(form, aWhere + ' form');
      CheckChildren(form.grpMyStation, aWhere + ' our-station group');
      CheckFits(form, aWhere);

      (* The dialog is the problem's subject, so its buttons must be there. *)
      CheckTrue(form.btnSave.Visible and form.btnCancel.Visible,
         aWhere + ': Save and Cancel are shown');

      first := Snapshot(form);
      form.FitLayout;
      Application.ProcessMessages;
      CheckEquals(first, Snapshot(form),
         aWhere + ': a second layout moves nothing');
   finally
      form.Free;
   end;
end;

procedure TEditQSOLayoutTests.Test_DefaultFont_Fits;
begin
   InitWidgetSet;
   BeginTest('EditQSO layout: at the default font nothing overlaps, clips or hides an arrow');
   RunLayoutChecks(0, 'default font');
end;

procedure TEditQSOLayoutTests.Test_LargerFont_Fits;
begin
   InitWidgetSet;
   BeginTest('EditQSO layout: at a larger font (a wider-font platform) the form grows to fit');
   RunLayoutChecks(LARGER_FONT_SIZE, 'font ' + IntToStr(LARGER_FONT_SIZE) + ' pt');
end;

(* ISSUE 237: the form is hidden on close and reused, and the load appended a
   full copy of each list on every open. This drives the routine the load
   calls (EditQSOFillBandAndModeLists -> FillBandAndModeLists) for a second
   and a third open on one form. The load itself needs a contest log to read,
   which a unit test does not have, so it is not driven end to end. *)
procedure TEditQSOLayoutTests.Test_Reopen_ListsAreReplacedNotAppended;
var
   form: TfrmEditQSO;
   open: integer;
   bt: BandType;
   m: ExtendedModeType;
   where: string;
begin
   InitWidgetSet;
   BeginTest('EditQSO lists (issue 237): a reopened form holds each band and mode once, at its own ordinal');
   form := MakeForm(0);
   try
      for open := 2 to 3 do
         begin
         form.FillBandAndModeLists;
         Application.ProcessMessages;
         where := 'open ' + IntToStr(open);

         CheckEquals(Ord(High(BandType)) - Ord(Low(BandType)) + 1,
            form.cboBand.Items.Count, where + ': one item per band');
         CheckEquals(Ord(High(ExtendedModeType)) - Ord(Low(ExtendedModeType)) + 1,
            form.cboMode.Items.Count, where + ': one item per extended mode');

         (* Save reads BandType(ItemIndex) and ExtendedModeType(ItemIndex): the
            row at each ordinal must be that value, and the last row must be
            the last value -- never one past it. *)
         for bt := Low(BandType) to High(BandType) do
            begin
            CheckEquals(UTF8Encode(BandStringsArrayWithOutSpaces[bt]),
               form.cboBand.Items[Ord(bt)], where + ': band row ' + IntToStr(Ord(bt)));
            end;
         for m := Low(ExtendedModeType) to High(ExtendedModeType) do
            begin
            CheckEquals(UTF8Encode(ExtendedModeStringArray[m]),
               form.cboMode.Items[Ord(m)], where + ': mode row ' + IntToStr(Ord(m)));
            end;

         form.cboBand.ItemIndex := form.cboBand.Items.Count - 1;
         form.cboMode.ItemIndex := form.cboMode.Items.Count - 1;
         CheckTrue(form.cboBand.ItemIndex <= Ord(High(BandType)),
            where + ': the last band row reads back as a BandType');
         CheckTrue(form.cboMode.ItemIndex <= Ord(High(ExtendedModeType)),
            where + ': the last mode row reads back as an ExtendedModeType');
         end;
   finally
      form.Free;
   end;
end;

procedure TEditQSOLayoutTests.RunAllTests;
begin
   Test_DefaultFont_Fits;
   Test_LargerFont_Fits;
   Test_Reopen_ListsAreReplacedNotAppended;
end;

end.

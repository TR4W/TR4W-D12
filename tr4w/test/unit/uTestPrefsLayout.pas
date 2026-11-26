unit uTestPrefsLayout;
{$I ..\..\src\tr4w.inc}

(*
  PREFERENCES LAID OUT ON A FORM THAT IS SHOWN (2026-11-26).

  5.1.3 shipped every placed block clipped: NewGeneratedBlock copied its
  parent's ClientWidth once, at creation, and the parent was a page's scroll
  box that had never been shown and was still 150 px wide -- so every row
  control at x=330 lay outside the block, on Windows, Linux and macOS alike.

  uTestPrefsPlacement could not see it. It builds the real form and counts its
  editors, but it never shows the pages that hold the blocks, and position,
  anchoring and alignment are applied only when a control is laid out on a
  shown parent. A control that exists, is bound and is named passes every one
  of its checks while sitting 180 px outside the visible block.

  These tests SHOW the form off screen (uTestShowOffScreen), select each page
  the way the tree does, let the LCL lay it out, and measure:

  - each placed block is exactly as wide as its scroll box's visible client
    area, and every row control inside it lies within the block;
  - the block's last row can be reached (inside the box, or within its range);
  - the Network page's hints and the rows below them do not overlap;
  - the CW output drop-downs are wide enough for 'Radio keyer port (COM66)';
  - the Colors page offers ALERT COLOR as a drop-down of the palette.

  The numbers go into the failure messages, so a failure on another widget
  set or DPI can be read without a debugger.
*)

interface

uses
   uTR4WTestFramework;

type
   TPrefsLayoutTests = class(TTestCase)
   protected
      procedure Test_PlacedBlocksFitTheirPages;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   Classes,
   Forms,
   Controls,
   StdCtrls,
   ExtCtrls,
   uLCLFormHelpers,       (* TNavNode, TextWidthInFont, DROPDOWN_CHROME_96 *)
   uSettingsLegacy,       (* ActiveStoreProvider -- the form sets and clears it *)
   uTR4WConfigFile,       (* TR4WConfigFileName -- proof the redirect landed *)
   uFileText,             (* TempDirectory, CombinePath, DeleteFileIfExists *)
   utils_text,            (* CharBufferText, SetCharBuffer *)
   uTestShowOffScreen,
   uPrefsForm,
   VC;                    (* TR4W_INI_FILENAME, tr4wColorsSA *)

function BoundsText(const aControl: TControl): string;
begin
   Result := Format('%s (%d,%d %dx%d)',
                    [string(aControl.Name), aControl.Left, aControl.Top,
                     aControl.Width, aControl.Height]);
end;

function FindDescendant(const aRoot: TWinControl; const aName: string): TControl;
var
   i: integer;
begin
   Result := nil;
   for i := 0 to aRoot.ControlCount - 1 do
      begin
      if SameText(string(aRoot.Controls[i].Name), aName) then
         begin
         Result := aRoot.Controls[i];
         Exit;
         end;
      if aRoot.Controls[i] is TWinControl then
         begin
         Result := FindDescendant(TWinControl(aRoot.Controls[i]), aName);
         if Result <> nil then
            begin
            Exit;
            end;
         end;
      end;
end;

procedure TPrefsLayoutTests.Test_PlacedBlocksFitTheirPages;
var
   oldIni, dir, fn: string;
   oldProvider: TActiveStoreProvider;
   form: TPrefsForm;
   pages: array of TWinControl;
   page, box: TWinControl;
   host: TControl;
   ctl: TControl;
   i, j, bottom, need: integer;
   cbo: TControl;

   (* A page selected the way the tree selects it. The tree raises OnChange
     from its own 1 ms TTimer (treeview.inc), so wait for the page to show --
     bounded, and checked. *)
   procedure SelectPage(const aPage: TWinControl);
   var
      k: integer;
   begin
      for k := 0 to form.tvNav.Items.Count - 1 do
         begin
         if TNavNode(form.tvNav.Items[k]).Tag = aPage.Tag then
            begin
            form.tvNav.Items[k].Selected := True;
            Break;
            end;
         end;
      for k := 1 to 200 do
         begin
         Application.ProcessMessages;
         if aPage.IsVisible then
            begin
            Break;
            end;
         Sleep(5);
         end;
      Application.ProcessMessages;
      CheckTrue(aPage.IsVisible, string(aPage.Name) + ': the page shows when selected');
   end;

   procedure CheckBelow(const aUpper, aLower: TControl);
   begin
      CheckTrue(aLower.Top >= aUpper.Top + aUpper.Height,
                'Network: ' + BoundsText(aLower) + ' starts below ' + BoundsText(aUpper));
   end;

begin
   BeginTest('Preferences: every placed block is as wide as its page and holds its rows');
   if Application <> nil then
      begin
      Application.Initialize;
      end;

   oldIni      := CharBufferText(TR4W_INI_FILENAME);
   oldProvider := uSettingsLegacy.ActiveStoreProvider;
   dir  := CombinePath(TempDirectory, 'tr4wprefslayout_' + TGUID.NewGuid.ToString);
   form := nil;
   try
      SetCharBuffer(TR4W_INI_FILENAME, CombinePath(dir, 'tr4w.ini'));
      fn := TR4WConfigFileName;
      if Pos(dir, fn) <> 1 then
         begin
         CheckTrue(False, 'the settings file was not redirected (' + fn +
                          ') -- a --settings switch? The form is not built');
         Exit;
         end;

      form := TPrefsForm.Create(nil);
      ShowOffScreen(form);

      (* THE PAGES BuildGeneratedSections gives a placed block. *)
      SetLength(pages, 9);
      pages[0] := form.layBandMap;
      pages[1] := form.layHardware;
      pages[2] := form.layStation;
      pages[3] := form.laySCP;
      pages[4] := form.layNetwork;
      pages[5] := form.layAudio;
      pages[6] := form.layTwoRadio;
      pages[7] := form.layWSJTX;
      pages[8] := form.layBands;
      for i := 0 to High(pages) do
         begin
         page := pages[i];
         SelectPage(page);
         box  := form.PageHost(page);
         CheckTrue(box <> page, string(page.Name) + ': the page has its scroll box');
         host := FindDescendant(box, PlacedBlockName(box));
         CheckTrue(host <> nil, string(page.Name) + ': the placed block was found');
         if (host = nil) or (not host.Visible) then
            begin
            Continue;
            end;

         CheckEquals(0, host.Left, string(page.Name) + ': the block starts at the box''s left');
         CheckEquals(box.ClientWidth, host.Width,
                     string(page.Name) + ': the block is as wide as the visible box ('
                     + BoundsText(host) + ', box client ' + IntToStr(box.ClientWidth) + ')');

         for j := 0 to TWinControl(host).ControlCount - 1 do
            begin
            ctl := TWinControl(host).Controls[j];
            CheckTrue((ctl.Left >= 0) and
                      (ctl.Left + ctl.Width <= TWinControl(host).ClientWidth),
                      string(page.Name) + ': ' + BoundsText(ctl) + ' lies inside the block ('
                      + IntToStr(TWinControl(host).ClientWidth) + ' wide)');
            end;

         (* REACHABLE: the block's bottom is on screen, or the box scrolls to it. *)
         bottom := host.Top + host.Height;
         CheckTrue((bottom <= box.ClientHeight) or
                   (TScrollBox(box).VertScrollBar.Range >= bottom),
                   string(page.Name) + ': the last row can be scrolled to (block bottom '
                   + IntToStr(bottom) + ', box ' + IntToStr(box.ClientHeight) + ', range '
                   + IntToStr(TScrollBox(box).VertScrollBar.Range) + ')');
         end;

      (* THE NETWORK PAGE'S CHAIN: each row hangs from the one above it, so a
        taller (gtk2) hint pushes the rows down instead of running into them. *)
      SelectPage(form.layNetwork);
      box := form.PageHost(form.layNetwork);
      CheckBelow(form.edtNetTailcat,      form.lblNetTailcatHint);
      CheckBelow(form.lblNetTailcatHint,  form.edtNetComputerID);
      CheckBelow(form.edtNetComputerID,   form.chkNetAutoSync);
      CheckBelow(form.lblNetComputerIDHint, form.chkNetAutoSync);
      CheckBelow(form.chkNetShareSpots,   form.lblNetHint);
      host := FindDescendant(box, PlacedBlockName(box));
      if (host <> nil) and host.Visible then
         begin
         CheckBelow(form.lblNetHint, host);
         end;
      CheckTrue(form.lblNetTailcatHint.Left + form.lblNetTailcatHint.Width <= box.ClientWidth,
                'Network: ' + BoundsText(form.lblNetTailcatHint) + ' fits the page');
      CheckTrue(form.lblNetHint.Left + form.lblNetHint.Width <= box.ClientWidth,
                'Network: ' + BoundsText(form.lblNetHint) + ' fits the page');

      (* THE CW OUTPUT DROP-DOWNS hold a radio keyer port's whole name. *)
      SelectPage(form.layRadios);
      need := TextWidthInFont(form.cbxCW1.Font, 'Radio keyer port (COM66)') +
              form.Scale96ToForm(DROPDOWN_CHROME_96);
      CheckTrue(form.cbxCW1.Width >= need,
                BoundsText(form.cbxCW1) + ' is wide enough for a keyer port (' + IntToStr(need) + ')');
      CheckTrue(form.cbxCW2.Width >= need,
                BoundsText(form.cbxCW2) + ' is wide enough for a keyer port (' + IntToStr(need) + ')');
      CheckTrue(form.cbxCW1.Left + form.cbxCW1.Width <= form.grpProfile.ClientWidth,
                BoundsText(form.cbxCW1) + ' lies inside the Station profile group');

      (* ALERT COLOR HAS A CONTROL: a drop-down of the palette on the Colors page. *)
      CheckEquals(NAV_COLORS, integer(PrefsPlacements.PageOf('appearance.alertColor')),
                  'ALERT COLOR is placed on the Colors page');
      cbo := nil;
      for i := 0 to form.layContent.ControlCount - 1 do
         begin
         if (form.layContent.Controls[i].Tag = NAV_COLORS) and
            (form.layContent.Controls[i] is TWinControl) then
            begin
            cbo := FindDescendant(TWinControl(form.layContent.Controls[i]),
                                  'gen_appearance_alertColor');
            end;
         end;
      CheckTrue(cbo is TComboBox, 'the Colors page offers ALERT COLOR as a drop-down');
      if cbo is TComboBox then
         begin
         CheckTrue(TComboBox(cbo).Items.IndexOf(string(tr4wColorsSA[trAlert])) >= 0,
                   'ALERT COLOR offers the palette, ALERT among it ('
                   + IntToStr(TComboBox(cbo).Items.Count) + ' item(s))');
         end;
   finally
      form.Free;
      uSettingsLegacy.ActiveStoreProvider := oldProvider;
      SetCharBuffer(TR4W_INI_FILENAME, oldIni);
      if DirectoryExists(dir) then
         begin
         DeleteFileIfExists(CombinePath(dir, 'tr4w.json'));
         RemoveDir(dir);
         end;
   end;
end;

procedure TPrefsLayoutTests.RunAllTests;
begin
   Test_PlacedBlocksFitTheirPages;
end;

end.

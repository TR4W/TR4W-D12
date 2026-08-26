{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 }

{ THE DX CLUSTER (TELNET) WINDOW, as an LCL form.

  The LAST BUT ONE tw_ window to convert; only MMTTY is still a Win32 dialog.

  WHY IT WENT LAST, and it was not arbitrary.  This window used to be part of
  the TRANSPORT: the cluster reader thread PostMessage'd WM_TELNET_MSG to its
  HWND, so "a line arrived" could not happen without a window to receive it.
  That was untangled first (cluster events go through Application.QueueAsyncCall
  now), and only then could the window become a form.  The same knot held up the
  Network window until uNet moved to Indy.

  THIS UNIT OWNS THE VIEW AND NOTHING ELSE.  What a line MEANS -- whether it is
  a spot, a dupe, a multiplier, an alert -- is uTelnet's business, and arrives
  here as a TelnetStringType that this unit only ever turns into a colour.
  Nothing here parses, connects or sends; the buttons call back out.

  THE CALLBACKS ARE ASSIGNED, NOT CALLED DIRECTLY, for the usual reason: this
  form is referenced from uTelnet's implementation, so a direct call back into
  uTelnet from here would need uTelnet in this unit's INTERFACE and that is the
  cycle Pascal will not have.  uTelnet fills them in at initialization.  Same
  shape as uStationsForm/uBandMapView.

  ONE REAL DEPENDENCY IS KEPT: TelnetStringType itself, from uTelnet's
  interface.  That is a plain enum with no code behind it, and passing an
  integer instead would only move the type check out of the compiler and into a
  comment. }
unit uTelnetForm;

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, StdCtrls, ExtCtrls, Menus,
   Buttons, ImgList, Graphics,
   LResources,   { LazarusResources -- the toolbar glyphs, compiled in by lazres }
   uTelnet;   { TelnetStringType -- see the unit header }

type
   TfrmTelnet = class(TForm)
      pnlToolbar: TPanel;
      btnConnect: TBitBtn;
      btnDisconnect: TBitBtn;
      btnFreeze: TBitBtn;
      btnClear: TBitBtn;
      btnCommands: TBitBtn;
      btnShow50: TBitBtn;
      pnlEntry: TPanel;
      cboHost: TComboBox;
      cboCommand: TComboBox;
      btnSend: TButton;
      lstConsole: TListBox;
      popCommands: TPopupMenu;
      tmrResize: TTimer;
      procedure HandleCreate(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleShow(Sender: TObject);
      procedure HandleResize(Sender: TObject);
      procedure ResizeSettled(Sender: TObject);
      procedure ApplyConsoleScale;
      procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure ConsoleDrawItem(Control: TWinControl; Index: Integer;
                                ARect: TRect; State: TOwnerDrawState);
      procedure ConnectClick(Sender: TObject);
      procedure DisconnectClick(Sender: TObject);
      procedure FreezeClick(Sender: TObject);
      procedure ClearClick(Sender: TObject);
      procedure CommandsClick(Sender: TObject);
      procedure Show50Click(Sender: TObject);
      procedure SendClick(Sender: TObject);
      procedure CommandKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure ConsoleDblClick(Sender: TObject);
      procedure MenuItemClick(Sender: TObject);
      procedure AttachCommandHandler(const aItem: TMenuItem);
   private
      { BUILT IN CODE, NOT DESIGNED.  It carries no designed content -- the
        glyphs are added from the compiled-in resource at create -- so putting
        it in the .lfm would only add a component the designer cannot show and
        the lfm lint cannot check.  Private, so it is not a published field
        without a component. }
      FToolbarImages: TImageList;
   end;

{ The toolbar command ids.  DELIBERATELY the same numbers the Win32 toolbar
  used, so uTelnet's dispatch is unchanged by the conversion and the two can be
  compared line for line while this settles.  They are an artifact and should go
  with the menu work -- see [[decision_menu_ids_are_win32_artifact]]. }
const
   TELNET_CMD_CONNECT    = 200;
   TELNET_CMD_DISCONNECT = 201;
   TELNET_CMD_COMMANDS   = 202;
   TELNET_CMD_FREEZE     = 203;
   TELNET_CMD_CLEAR      = 204;
   TELNET_CMD_SHOW50     = 206;

var
   TR4WTelnetForm: TfrmTelnet = nil;

   { WHAT WM_INITDIALOG USED TO DO.  A dialog was built every time it opened; a
     form is created once and reshown, so OnShow is the equivalent moment. }
   TelnetFormOnShow: procedure = nil;

   { A toolbar button was pressed.  Carries the same id the Win32 WM_COMMAND
     did. }
   TelnetFormOnCommand: procedure(const aId: integer) = nil;

   { The operator pressed Enter in the command box, or clicked Send. }
   TelnetFormOnSend: procedure = nil;

   { A console line was double-clicked.  Carries the row, because the caller
     re-decodes the text -- the view does not know a spot from a banner. }
   TelnetFormOnConsoleDblClick: procedure(const aIndex: integer) = nil;

   { A cluster command was chosen from the popup.  Carries the item's Tag,
     which is the same 1000-based id the Win32 menu used. }
   TelnetFormOnMenu: procedure(const aId: integer) = nil;

function CreateTR4WTelnetWindow: HWND;

{ ---- the console -------------------------------------------------------- }
{ Every one of these is a no-op when the window is not open: the headless
  /EXPORT path never builds a form, and the cluster can be connected with the
  window closed. }
procedure TelnetConsoleAdd(const aText: string; const aKind: TelnetStringType);
procedure TelnetConsoleClear;
procedure TelnetConsoleScrollToEnd;
function  TelnetConsoleCount: integer;
function  TelnetConsoleLine(const aIndex: integer): string;
function  TelnetConsoleKind(const aIndex: integer): TelnetStringType;
function  TelnetConsoleSelected: integer;

{ CTRL-CURSOR INTO THE TELNET WINDOW, which MainUnit drives.  It used to do
  this with SetFocus and four LB_ messages against a raw handle; these say
  what it was asking for. }
function  TelnetConsoleHasFocus: boolean;
function  TelnetCommandHasFocus: boolean;
procedure TelnetFocusConsole;
{ Puts the selection somewhere sensible when focus arrives: the last line,
  unless a visible one is already selected.  Returns False when there is
  nothing to select. }
function  TelnetConsoleSelectForEntry: boolean;

{ ---- the toolbar and the entry row --------------------------------------- }
procedure TelnetSetConnected(const aConnected: boolean);
procedure TelnetSetFreezePressed(const aPressed: boolean);

function  TelnetHostText: string;
{ THE HOST LIST IS FILLED AS A BATCH, and it has to be.

  TRCLUSTER.DAT is 726 lines.  Adding them one at a time cost 1741 ms of
  BLOCKED MAIN THREAD at start-up (measured 2026-08-26) -- and because
  OpenOtherWindows runs before Application.Run, that time is the main window
  sitting unpainted.

  Two multipliers, both invisible in the source: on the Win32 widget set a
  TComboBox's Items PROXY THE NATIVE CONTROL, so every IndexOf is a sweep of
  CB_GETLBTEXT round trips and every Add relays the control out; and the
  duplicate check made it O(n^2).  Roughly a quarter of a million messages to
  fill one drop-down.

  So the de-duplication happens in MEMORY, against a sorted list, and the
  control is written ONCE.  Begin/Add*/End -- End is what actually fills it. }
procedure TelnetBeginHostList;
procedure TelnetAddHostItem(const aHost: string);
procedure TelnetEndHostList;
procedure TelnetSelectHostItem(const aHost: string);

function  TelnetCommandText: string;
procedure TelnetSetCommandText(const aText: string);
procedure TelnetRememberCommand(const aText: string);

{ ---- the commands popup -------------------------------------------------- }
procedure TelnetMenuClear;
function  TelnetMenuAddItem(const aParent: TMenuItem; const aCaption: string;
                            const aId: integer; const aEnabled: boolean): TMenuItem;
procedure TelnetShowCommandMenu;
{ The caption of the item carrying this id, '' if there is none.  The caller
  needs the TEXT because that is the cluster command; the id only identifies
  it.  Win32 read this back with GetMenuStringA for the same reason. }
function  TelnetMenuCaption(const aId: integer): string;

implementation

{$R *.lfm}

uses
   VC,                { tw_TELNETWINDOW_INDEX, tr4wColorsArray }
   MainUnit,          { CloseTR4WWindow }
   uLCLFormHelpers;   { OwnFormByMainWindow -- the LCL way to parent a tool window }

var
   { Staging for the batched host list -- see TelnetBeginHostList.  Nil
     except between Begin and End. }
   GHostStaging: TStringList = nil;
   GHostSeen: TStringList = nil;

{ THE COLOUR OF A CONSOLE LINE.

  This was a const INSIDE TelnetWndDlgProc, which is why it moves here rather
  than staying in uTelnet: it would have been deleted with the procedure.  It is
  a view fact and this is the view.

  tstTR4W (status messages) is BLACK, not green -- Issue #23 changed it on the
  grounds that a status line is not an event.  Errors stay red. }
const
   TelnetStringColor: array[TelnetStringType] of tr4wColors =
      (trBlack, trBlue, trBlack, trLightGray, trRed, trRed, trBlack);

{ One guard for every routine below, and it has to be BOTH tests.  The form is
  nil on the headless export path, and a control exists from the moment it is
  constructed while its window does not -- the LCL creates that lazily.  The
  Win32 SendMessage calls these replace were silent no-ops on handle 0; direct
  property access is not. }
function ConsoleUsable: boolean;
begin
   Result := (TR4WTelnetForm <> nil) and
             (TR4WTelnetForm.lstConsole <> nil) and
             TR4WTelnetForm.lstConsole.HandleAllocated;
end;

function FormUsable: boolean;
begin
   Result := (TR4WTelnetForm <> nil) and TR4WTelnetForm.HandleAllocated;
end;

function CreateTR4WTelnetWindow: HWND;
begin
   if TR4WTelnetForm = nil then
      begin
      TR4WTelnetForm := TfrmTelnet.Create(Application);
      end;

   OwnFormByMainWindow(TR4WTelnetForm);
   Result := TR4WTelnetForm.Handle;
end;

{ THE TOOLBAR GLYPHS.

  NY4I drew these; they arrive as 24x24 PNGs with alpha, compiled into the
  binary by lazres (tr4w/res/telnet -> telneticons.lrs, included below).  NO
  RUNTIME FILES: a missing glyph would be a silently blank button on somebody
  else's machine.

  24 PIXELS AND THE FRAMES CROPPED OFF, both deliberate.  At 16 px Connect and
  Disconnect are the same grey blob -- the whole difference between them is a
  green arrow pointing right versus a red one pointing left, which is about
  three pixels at that size, and "am I connected" is exactly what the icon has
  to answer at a glance.  The source art also drew its own rounded-rect button
  face, which inside a real button reads as a button drawn in a button.

  TImageList AND NOT Glyph, because Glyph is a TBitmap and assigning a PNG to
  one loses the alpha.  TBitBtn.Images/ImageIndex composites it properly.

  SH/50 HAS NO GLYPH -- only five were drawn.  It keeps its caption alone, which
  is legitimate: the label IS the whole meaning of that button, unlike a plug or
  a snowflake.  Add a sixth to res	elnet and one line here if that changes. }
procedure TfrmTelnet.HandleCreate(Sender: TObject);

   procedure AddGlyph(const aName: string; const aButton: TBitBtn);
   var
      png: TPortableNetworkGraphic;
   begin
      png := TPortableNetworkGraphic.Create;
      try
         png.LoadFromLazarusResource(aName);
         aButton.Images := FToolbarImages;
         aButton.ImageIndex := FToolbarImages.Add(png, nil);
      finally
         png.Free;
      end;
   end;

begin
   FToolbarImages := TImageList.Create(Self);
   FToolbarImages.Width := 24;
   FToolbarImages.Height := 24;

   AddGlyph('connect',    btnConnect);
   AddGlyph('disconnect', btnDisconnect);
   AddGlyph('freeze',     btnFreeze);
   AddGlyph('clear',      btnClear);
   AddGlyph('commands',   btnCommands);
end;

procedure TfrmTelnet.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   { caHIDE, NOT caNone -- caNone leaves the form visible as far as the LCL is
     concerned while CloseTR4WWindow destroys the handle underneath it, and the
     widget set then recreates it.  Five windows shipped with that defect and
     could not be closed at all (ec3448a6). }
   CloseAction := caHide;
   CloseTR4WWindow(tw_TELNETWINDOW_INDEX);
end;

procedure TfrmTelnet.HandleShow(Sender: TObject);
begin
   if Assigned(TelnetFormOnShow) then
      begin
      TelnetFormOnShow;
      end;

   // The console had no items and possibly no handle when the form was last
   // resized, so the fit has to run again now that it does.
   // DIRECTLY, not through the debounce: a window being shown is not a drag,
   // and waiting 80 ms to size its text would be visible.
   ApplyConsoleScale;
end;

{ THE CONSOLE SCALES WITH THE WINDOW -- FONT AND ROW HEIGHT TOGETHER.

  Same rule as the stations grid, and for the same reason NY4I gave there: a
  window made bigger should show BIGGER TEXT, not the same text with more empty
  space to the right of it.  What differs is what "designed width" means.  A
  grid has columns; a cluster console has a LINE -- every DX spot is the same
  fixed-width record, so the target is simply that one line filling the width.

  MEASURED, NOT ASSUMED.  The pixel width of eighty characters depends on the
  font, so it is asked for at the design size rather than computed from a
  hard-coded character width that would be wrong the moment anyone changes the
  face.

  ITEMHEIGHT DOES NOT FOLLOW THE FONT, and that is the trap here.  A report-view
  TListView takes its row height from the font for free; an OWNER-DRAWN list box
  does not -- lbOwnerDrawFixed means the height is whatever ItemHeight says, so
  growing the font alone would draw larger text clipped inside 15-pixel rows.
  Nothing warns about this; it just looks wrong. }
const
   { A DX spot line.  DXSpotLength in uTelnet is 76; the few extra characters
     are the margin the format actually uses in practice -- see any line in the
     console. }
   CONSOLE_COLUMNS = 80;
   DESIGN_FONT     = 9;
   MIN_FONT        = 7;
   MAX_FONT        = 20;

{ THE RESIZE ITSELF DOES NOTHING BUT RESTART A TIMER.

  A drag fires OnResize continuously, and NY4I asked for it to look smoother.
  Rescaling per tick means recomputing the font and then repainting every line
  in the console -- fifty times during one drag, and only the last one is the
  answer.

  So the work is DEBOUNCED: each resize restarts an 80 ms timer and the scale is
  applied once, when the drag settles.  During the drag the list simply stretches
  at its current font, which is what "freeze the display while resizing" looks
  like from the operator's side.

  80 ms is below the threshold where a deliberate release feels laggy and well
  above a drag's tick rate, so a continuous drag never triggers it and a pause
  does.

  A TIMER RATHER THAN WM_EXITSIZEMOVE, which is the Win32 answer to exactly this
  question.  That message would work and would be smaller -- but it is new Win32
  surface in a window that just shed all of it, and it would not survive the
  platform this port is heading for. }
procedure TfrmTelnet.HandleResize(Sender: TObject);
begin
   if tmrResize = nil then
      begin
      Exit;
      end;

   // Restart, not merely enable: an already-running timer must measure from the
   // LAST movement, not the first.
   tmrResize.Enabled := False;
   tmrResize.Enabled := True;
end;

procedure TfrmTelnet.ResizeSettled(Sender: TObject);
begin
   tmrResize.Enabled := False;
   ApplyConsoleScale;
end;

procedure TfrmTelnet.ApplyConsoleScale;
var
   avail, designed, fontSize, rowHeight: integer;
begin
   if (lstConsole = nil) or (not lstConsole.HandleAllocated) then
      begin
      Exit;
      end;

   // Less the 5px text inset the owner draw uses, and a little for a vertical
   // scrollbar, so a full-width line does not provoke a horizontal one.
   avail := lstConsole.ClientWidth - 10;
   if avail < 1 then
      begin
      Exit;      // mid-layout, or minimised
      end;

   lstConsole.Canvas.Font.Assign(lstConsole.Font);
   lstConsole.Canvas.Font.Size := DESIGN_FONT;
   designed := lstConsole.Canvas.TextWidth(StringOfChar('0', CONSOLE_COLUMNS));
   if designed < 1 then
      begin
      Exit;
      end;

   fontSize := (DESIGN_FONT * avail) div designed;
   if fontSize < MIN_FONT then
      begin
      fontSize := MIN_FONT;
      end;
   if fontSize > MAX_FONT then
      begin
      fontSize := MAX_FONT;
      end;

   // NOTHING TO DO is the common case once the drag settles at a size the
   // clamp already covers, and repainting the console anyway is the flicker
   // this is here to avoid.
   if lstConsole.Font.Size <> fontSize then
      begin
      // Assigning Size also clears ParentFont, which is what we want: this
      // control's font is computed, not inherited.
      lstConsole.Items.BeginUpdate;
      try
         lstConsole.Font.Size := fontSize;
      finally
         lstConsole.Items.EndUpdate;
      end;
      end;

   // FROM THE FONT THAT WAS ACTUALLY APPLIED, not from the window -- when the
   // font is clamped the rows must stop growing with it too.
   lstConsole.Canvas.Font.Assign(lstConsole.Font);
   rowHeight := lstConsole.Canvas.TextHeight('Wg') + 2;
   if (rowHeight > 0) and (lstConsole.ItemHeight <> rowHeight) then
      begin
      lstConsole.ItemHeight := rowHeight;
      end;
end;

procedure TfrmTelnet.HandleKeyDown(Sender: TObject; var Key: Word;
                                   Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

{ THE OWNER DRAW, and it is the same three steps the Win32 handler did:
  an alert gets a yellow band, the text takes its colour from the line's kind,
  and it is drawn transparently five pixels in.

  Index is checked because a draw can arrive for a row the model no longer has;
  in a Win32 window procedure that was a silent no-op, here it would be a range
  error inside the widget set. }
procedure TfrmTelnet.ConsoleDrawItem(Control: TWinControl; Index: Integer;
                                     ARect: TRect; State: TOwnerDrawState);
var
   kind: TelnetStringType;
   cv: TCanvas;
begin
   if (Index < 0) or (Index >= lstConsole.Items.Count) then
      begin
      Exit;
      end;

   cv := lstConsole.Canvas;
   kind := TelnetStringType(PtrUInt(lstConsole.Items.Objects[Index]));

   if kind = tstAlert then
      begin
      cv.Brush.Color := tr4wColorsArray[trYellow];
      end
   else
      begin
      cv.Brush.Color := lstConsole.Color;
      end;
   cv.FillRect(ARect);

   cv.Font.Color := tr4wColorsArray[TelnetStringColor[kind]];
   cv.Brush.Style := bsClear;
   cv.TextOut(ARect.Left + 5, ARect.Top, lstConsole.Items[Index]);
   cv.Brush.Style := bsSolid;
end;

{ Every button hands the SAME id the Win32 toolbar sent, so uTelnet's dispatch
  did not have to change shape when this window converted. }
procedure TfrmTelnet.ConnectClick(Sender: TObject);
begin
   if Assigned(TelnetFormOnCommand) then TelnetFormOnCommand(TELNET_CMD_CONNECT);
end;

procedure TfrmTelnet.DisconnectClick(Sender: TObject);
begin
   if Assigned(TelnetFormOnCommand) then TelnetFormOnCommand(TELNET_CMD_DISCONNECT);
end;

procedure TfrmTelnet.FreezeClick(Sender: TObject);
begin
   if Assigned(TelnetFormOnCommand) then TelnetFormOnCommand(TELNET_CMD_FREEZE);
end;

procedure TfrmTelnet.ClearClick(Sender: TObject);
begin
   if Assigned(TelnetFormOnCommand) then TelnetFormOnCommand(TELNET_CMD_CLEAR);
end;

procedure TfrmTelnet.CommandsClick(Sender: TObject);
begin
   if Assigned(TelnetFormOnCommand) then TelnetFormOnCommand(TELNET_CMD_COMMANDS);
end;

procedure TfrmTelnet.Show50Click(Sender: TObject);
begin
   if Assigned(TelnetFormOnCommand) then TelnetFormOnCommand(TELNET_CMD_SHOW50);
end;

{ ONE handler for every command in the popup, and the item's Tag says which.
  The Win32 version could not do this -- a menu id is an integer in a
  WM_COMMAND and had to be decoded by range test. }
procedure TfrmTelnet.MenuItemClick(Sender: TObject);
begin
   if Assigned(TelnetFormOnMenu) and (Sender is TMenuItem) then
      begin
      TelnetFormOnMenu(TMenuItem(Sender).Tag);
      end;
end;

{ THE FORM WIRES ITS OWN EVENT.  TelnetMenuAddItem is a plain function and
  would have to say TR4WTelnetForm.MenuItemClick, which reads as a dotted
  name -- and Lint-FormEvents deliberately ignores those, because that is how
  it recognises an implementation header (Lint-FormEvents.ps1:151).  So a
  correctly wired handler would have looked unwired.  Doing it inside a
  method is the better shape anyway: a form owning the wiring of its own
  events, rather than a free function reaching in to do it. }
procedure TfrmTelnet.AttachCommandHandler(const aItem: TMenuItem);
begin
   aItem.OnClick := MenuItemClick;
end;

procedure TfrmTelnet.ConsoleDblClick(Sender: TObject);
begin
   if (lstConsole.ItemIndex >= 0) and Assigned(TelnetFormOnConsoleDblClick) then
      begin
      TelnetFormOnConsoleDblClick(lstConsole.ItemIndex);
      end;
end;

procedure TfrmTelnet.SendClick(Sender: TObject);
begin
   if Assigned(TelnetFormOnSend) then TelnetFormOnSend;
end;

{ ENTER SENDS.  The Win32 version got this from the Send button being
  BS_DEFPUSHBUTTON and the dialog manager routing Enter to it; a form has no
  dialog manager, so the combo says so itself.  Key is cleared to stop the
  combo's own handling adding a beep. }
procedure TfrmTelnet.CommandKeyDown(Sender: TObject; var Key: Word;
                                    Shift: TShiftState);
begin
   if (Key = VK_RETURN) and (Shift = []) then
      begin
      Key := 0;
      if Assigned(TelnetFormOnSend) then TelnetFormOnSend;
      end;
end;

{ ------------------------------------------------------------- console ---- }

procedure TelnetConsoleAdd(const aText: string; const aKind: TelnetStringType);
begin
   if not ConsoleUsable then
      begin
      Exit;
      end;

   { The kind travels in Objects[], which is where the Win32 version put it too
     -- LB_SETITEMDATA is the same slot by another name.  No 1023-character cap
     any more: that existed because the owner-draw handler read the item back
     into a fixed stack buffer, and it does not do that now. }
   TR4WTelnetForm.lstConsole.Items.AddObject(aText, TObject(PtrUInt(Ord(aKind))));
end;

procedure TelnetConsoleClear;
begin
   if not ConsoleUsable then
      begin
      Exit;
      end;
   TR4WTelnetForm.lstConsole.Items.Clear;
end;

procedure TelnetConsoleScrollToEnd;
begin
   if not ConsoleUsable then
      begin
      Exit;
      end;
   if TR4WTelnetForm.lstConsole.Items.Count > 0 then
      begin
      TR4WTelnetForm.lstConsole.TopIndex :=
         TR4WTelnetForm.lstConsole.Items.Count - 1;
      end;
end;

function TelnetConsoleCount: integer;
begin
   Result := 0;
   if not ConsoleUsable then
      begin
      Exit;
      end;
   Result := TR4WTelnetForm.lstConsole.Items.Count;
end;

function TelnetConsoleLine(const aIndex: integer): string;
begin
   Result := '';
   if (not ConsoleUsable) or (aIndex < 0) or
      (aIndex >= TR4WTelnetForm.lstConsole.Items.Count) then
      begin
      Exit;
      end;
   Result := TR4WTelnetForm.lstConsole.Items[aIndex];
end;

function TelnetConsoleKind(const aIndex: integer): TelnetStringType;
begin
   Result := tstTR4W;
   if (not ConsoleUsable) or (aIndex < 0) or
      (aIndex >= TR4WTelnetForm.lstConsole.Items.Count) then
      begin
      Exit;
      end;
   Result := TelnetStringType(PtrUInt(TR4WTelnetForm.lstConsole.Items.Objects[aIndex]));
end;

function TelnetConsoleSelected: integer;
begin
   Result := -1;
   if not ConsoleUsable then
      begin
      Exit;
      end;
   Result := TR4WTelnetForm.lstConsole.ItemIndex;
end;

function TelnetConsoleHasFocus: boolean;
begin
   Result := ConsoleUsable and TR4WTelnetForm.lstConsole.Focused;
end;

function TelnetCommandHasFocus: boolean;
begin
   Result := FormUsable and
             (TR4WTelnetForm.cboCommand <> nil) and
             TR4WTelnetForm.cboCommand.HandleAllocated and
             TR4WTelnetForm.cboCommand.Focused;
end;

procedure TelnetFocusConsole;
begin
   if ConsoleUsable and TR4WTelnetForm.lstConsole.CanFocus then
      begin
      TR4WTelnetForm.lstConsole.SetFocus;
      end;
end;

function TelnetConsoleSelectForEntry: boolean;
var
   lb: TListBox;
begin
   Result := False;
   if not ConsoleUsable then
      begin
      Exit;
      end;

   lb := TR4WTelnetForm.lstConsole;
   if lb.Items.Count = 0 then
      begin
      Exit;
      end;

   { Scrolled away from the selection, or nothing selected -- start at the end,
     which is where the live traffic is. }
   if (lb.ItemIndex < 0) or (lb.ItemIndex < lb.TopIndex) then
      begin
      lb.ItemIndex := lb.Items.Count - 1;
      end;
   Result := True;
end;

{ ------------------------------------------------- toolbar and entry row --- }

{ CONNECTED IS ONE FACT AND IT DRIVES FOUR CONTROLS.  The Win32 version reached
  into the toolbar with TB_SETSTATE per button and separately EnableWindow'd the
  send box, which is how the two got out of step whenever a teardown path missed
  one. }
procedure TelnetSetConnected(const aConnected: boolean);
begin
   if not FormUsable then
      begin
      Exit;
      end;

   TR4WTelnetForm.btnConnect.Enabled    := not aConnected;
   TR4WTelnetForm.btnDisconnect.Enabled := aConnected;
   TR4WTelnetForm.cboCommand.Enabled    := aConnected;
   TR4WTelnetForm.btnSend.Enabled       := aConnected;
end;

procedure TelnetSetFreezePressed(const aPressed: boolean);
begin
   if not FormUsable then
      begin
      Exit;
      end;

   { The Win32 button was TBSTYLE_CHECK and showed its state by staying pushed
     in.  A plain TButton has no such state, so the CAPTION carries it -- and
     says what pressing it will do next, which the pushed-in look never did. }
   if aPressed then
      begin
      TR4WTelnetForm.btnFreeze.Caption := 'Unfreeze';
      end
   else
      begin
      TR4WTelnetForm.btnFreeze.Caption := 'Freeze';
      end;
end;

function TelnetHostText: string;
begin
   Result := '';
   if not FormUsable then
      begin
      Exit;
      end;
   Result := Trim(TR4WTelnetForm.cboHost.Text);
end;

procedure TelnetBeginHostList;
begin
   { Recreated per pass: this runs on every show, and a stale staging list
     would accumulate. }
   FreeAndNil(GHostStaging);
   FreeAndNil(GHostSeen);

   GHostStaging := TStringList.Create;      { file order, which is what shows }
   GHostSeen := TStringList.Create;         { the SET -- sorted, so IndexOf
                                              binary-searches }
   GHostSeen.Sorted := True;
   GHostSeen.CaseSensitive := False;
   GHostSeen.Duplicates := dupIgnore;
end;

procedure TelnetAddHostItem(const aHost: string);
var
   host: string;
begin
   host := Trim(aHost);
   if host = '' then
      begin
      Exit;
      end;

   { Called outside a Begin/End pair -- one host added on its own.  Still goes
     through the control directly, because there is nothing to batch. }
   if GHostStaging = nil then
      begin
      if FormUsable and (TR4WTelnetForm.cboHost.Items.IndexOf(host) < 0) then
         begin
         TR4WTelnetForm.cboHost.Items.Add(host);
         end;
      Exit;
      end;

   if GHostSeen.IndexOf(host) >= 0 then
      begin
      Exit;
      end;

   GHostSeen.Add(host);
   GHostStaging.Add(host);
end;

procedure TelnetEndHostList;
begin
   if GHostStaging = nil then
      begin
      Exit;
      end;

   try
      if not FormUsable then
         begin
         Exit;
         end;

      { ONE write to the control.  BeginUpdate/EndUpdate so the widget set
        relays out once rather than per item. }
      TR4WTelnetForm.cboHost.Items.BeginUpdate;
      try
         TR4WTelnetForm.cboHost.Items.Assign(GHostStaging);
      finally
         TR4WTelnetForm.cboHost.Items.EndUpdate;
      end;
   finally
      FreeAndNil(GHostStaging);
      FreeAndNil(GHostSeen);
   end;
end;

procedure TelnetSelectHostItem(const aHost: string);
var
   i: integer;
begin
   if not FormUsable then
      begin
      Exit;
      end;
   i := TR4WTelnetForm.cboHost.Items.IndexOf(aHost);
   if i >= 0 then
      begin
      TR4WTelnetForm.cboHost.ItemIndex := i;
      end
   else
      begin
      TR4WTelnetForm.cboHost.Text := aHost;
      end;
end;

function TelnetCommandText: string;
begin
   Result := '';
   if not FormUsable then
      begin
      Exit;
      end;
   Result := TR4WTelnetForm.cboCommand.Text;
end;

procedure TelnetSetCommandText(const aText: string);
begin
   if not FormUsable then
      begin
      Exit;
      end;
   TR4WTelnetForm.cboCommand.Text := aText;
   TR4WTelnetForm.cboCommand.SelStart := Length(aText);
end;

{ The command box keeps a history, most recent first, which the Win32 combo did
  not do -- it was an edit box with a dropdown that nothing ever filled. }
procedure TelnetRememberCommand(const aText: string);
var
   i: integer;
begin
   if (not FormUsable) or (Trim(aText) = '') then
      begin
      Exit;
      end;

   i := TR4WTelnetForm.cboCommand.Items.IndexOf(aText);
   if i >= 0 then
      begin
      TR4WTelnetForm.cboCommand.Items.Delete(i);
      end;
   TR4WTelnetForm.cboCommand.Items.Insert(0, aText);

   while TR4WTelnetForm.cboCommand.Items.Count > 50 do
      begin
      TR4WTelnetForm.cboCommand.Items.Delete(TR4WTelnetForm.cboCommand.Items.Count - 1);
      end;
end;

{ ------------------------------------------------------- commands popup ---- }

procedure TelnetMenuClear;
begin
   if not FormUsable then
      begin
      Exit;
      end;
   TR4WTelnetForm.popCommands.Items.Clear;
end;

{ aParent nil means top level.  Returns the item so the caller can use it as the
  parent of a submenu -- which is how the Win32 version's TelLastPopMemu worked,
  except that this cannot get out of step with itself. }
function TelnetMenuAddItem(const aParent: TMenuItem; const aCaption: string;
                           const aId: integer; const aEnabled: boolean): TMenuItem;
begin
   Result := nil;
   if not FormUsable then
      begin
      Exit;
      end;

   Result := TMenuItem.Create(TR4WTelnetForm.popCommands);
   Result.Caption := aCaption;
   Result.Tag := aId;
   Result.Enabled := aEnabled;
   { A separator and a submenu PARENT carry no command, so neither gets a
     handler -- clicking a submenu title must open it, not send it. }
   if (aId >= 0) and (aCaption <> '-') then
      begin
      TR4WTelnetForm.AttachCommandHandler(Result);
      end;

   if aParent = nil then
      begin
      TR4WTelnetForm.popCommands.Items.Add(Result);
      end
   else
      begin
      aParent.Add(Result);
      end;
end;

{ Depth-first, because commands live in submenus.  Recursive rather than a
  parallel id->text list: a second list is the thing that drifts. }
function FindCaption(const aItem: TMenuItem; const aId: integer): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to aItem.Count - 1 do
      begin
      if aItem[i].Tag = aId then
         begin
         Result := aItem[i].Caption;
         Exit;
         end;
      Result := FindCaption(aItem[i], aId);
      if Result <> '' then
         begin
         Exit;
         end;
      end;
end;

function TelnetMenuCaption(const aId: integer): string;
begin
   Result := '';
   if not FormUsable then
      begin
      Exit;
      end;
   Result := FindCaption(TR4WTelnetForm.popCommands.Items, aId);
end;

procedure TelnetShowCommandMenu;
var
   pt: TPoint;
begin
   if not FormUsable then
      begin
      Exit;
      end;

   { Under the Commands button, which is where TrackPopupMenu put it -- the
     Win32 code computed the button's rectangle by hand. }
   pt := TR4WTelnetForm.btnCommands.ClientToScreen(
            Point(0, TR4WTelnetForm.btnCommands.Height));
   TR4WTelnetForm.popCommands.PopUp(pt.X, pt.Y);
end;

initialization

{$I telneticons.lrs}

end.

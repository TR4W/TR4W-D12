unit uFunctionKeysForm;
{$I ..\..\tr4w.inc}

{
  THE FUNCTION-KEYS WINDOW, AS A DESIGNED LCL FORM.

  THE FIRST tw_ TOOL WINDOW TO CONVERT, and the seam here is the one the other
  nineteen will use -- see docs/ROADMAP.md section 2, which carries the design
  and the traps.

  WHY THIS ONE FIRST.  It owns two of the three message-loop arms that gate
  Application.Run: WM_RBUTTONDBLCLK and WM_RBUTTONDOWN, dispatched in tr4w.lpr by
  comparing Msg.HWND against the twelve button handles.  A raw Win32 child
  generates no LCL mouse events, so those arms could not move until the buttons
  became LCL controls.  They are TPanels now and the arms are deleted.

  NO CUSTOM PAINTING SURVIVES, and that is the point rather than a shortcut.  The
  owner-draw did exactly three things -- DrawEdge with EDGE_SUNKEN or
  EDGE_ETCHED, a GradientRect with the SAME colour at both ends (so a flat fill),
  and centred text.  A TPanel has all three as properties: BevelOuter, Color,
  Caption.  Porting the GDI would have carried Win32 into the replacement.

  THE LAYOUT IS RUNTIME, THE DECLARATION IS DESIGNED.  The twelve panels are in
  uFunctionKeysForm.lfm so they can be seen and edited; LayOutKeys spreads them
  across whatever width the window has, with the 10px gaps after F4 and F8 that
  the Win32 WM_SIZE handler produced.  Same rule the main window settled on.

  THE DOUBLED AMPERSAND IS DELIBERATE.  ShowFMessages inserts a second '&' so the
  caption renders one; a TPanel caption treats '&' the same way a Win32 owner-draw
  did, so the doubling stays correct.  Removing it would eat every ampersand in a
  CW message.
}

interface

uses
  Forms, Controls, ExtCtrls, StdCtrls, Classes, Graphics,
  LCLType;   // HWND -- the LCL's own declaration, not the Windows unit's, so
             // this unit stays free of a Windows uses clause

type
  TfrmFunctionKeys = class(TForm)
    pnlF1: TPanel;
    pnlF2: TPanel;
    pnlF3: TPanel;
    pnlF4: TPanel;
    pnlF5: TPanel;
    pnlF6: TPanel;
    pnlF7: TPanel;
    pnlF8: TPanel;
    pnlF9: TPanel;
    pnlF10: TPanel;
    pnlF11: TPanel;
    pnlF12: TPanel;
    procedure HandleResize(Sender: TObject);
    procedure HandleShow(Sender: TObject);
    procedure KeyPanelClick(Sender: TObject);
    procedure KeyPanelMouseDown(Sender: TObject; Button: TMouseButton;
                                Shift: TShiftState; X, Y: integer);
  private
    { Indexed 112..123 like everything else that talks about these keys, so a
      caller never has to convert.  Filled in HandleShow from the designed
      panels, so adding a key is an edit to the .lfm and this array. }
    FKeys: array[112..123] of TPanel;

    { THE WRAPPING LABEL ON EACH PANEL.

      A TPanel's Caption is ONE LINE and clips: NY4I's screenshots show it next
      to D7's, where every key wraps its message under the key name across two
      or three centred lines.  There is no WordWrap on a TPanel caption, so the
      text belongs to a TLabel that has one.

      Built in code rather than twelve times in the .lfm.  Twelve identical
      property blocks is exactly the shape NY4I flagged as easy to get wrong in
      one of them -- one helper cannot drift from itself. }
    FCaptions: array[112..123] of TLabel;
    procedure BuildCaptionLabels;
    procedure LayOutKeys;
  public
    { Caption and colour for one key, addressed the way the rest of the program
      addresses them.  Out-of-range is ignored rather than raising: this is
      called from a repaint path. }
    procedure SetKeyCaption(const aKey: integer; const aText: string);
    procedure SetKeyColor(const aKey: integer; const aColor: TColor);
  end;

type
  { What a key press MEANS is uFunctionKeys' business -- it owns the memories,
    the CQ/S&P banks and the Alt-P editor.  This unit owns the widgets.

    PROCEDURE VARIABLES rather than a uses clause, because the dependency runs
    BOTH ways: uFunctionKeys drives the captions and colours, and the panels have
    to call back into it.  A direct reference either way is a circular unit
    reference; this is the shape PossibleCallDrawProc already uses for the
    possible-call list's drawing. }
  TFunctionKeyProc = procedure(const aKey: integer);

var
  { The live form, or nil.  Exposed because uFunctionKeys drives it and
    OpenTR4WWindow needs its Handle. }
  TR4WFunctionKeysForm: TfrmFunctionKeys = nil;

  FunctionKeyClicked: TFunctionKeyProc = nil;
  FunctionKeyRightClicked: TFunctionKeyProc = nil;
  FunctionKeyRightDoubleClicked: TFunctionKeyProc = nil;

{ Create the window and return its handle, for OpenTR4WWindow's seam. }
function CreateTR4WFunctionKeysWindow: HWND;

implementation

{$R *.lfm}

uses
  uLCLFormHelpers;   // OwnFormByMainWindow -- the LCL way to parent a tool window

procedure TfrmFunctionKeys.HandleShow(Sender: TObject);
begin
   // The panels are found in HandleShow, so the labels can only be built
   // after it -- and only once, which BuildCaptionLabels checks for itself.
   BuildCaptionLabels;
   LayOutKeys;
end;

procedure TfrmFunctionKeys.HandleResize(Sender: TObject);
begin
   LayOutKeys;
end;

procedure TfrmFunctionKeys.LayOutKeys;
var
   i, left, w, h: integer;
begin
   // The arithmetic the Win32 WM_SIZE handler used, unchanged: twelve buttons
   // across the client width less 30, one pixel between them, and ten more after
   // F4 and F8 so the banks read as three groups of four.
   w := (ClientWidth - 30) div 12;
   h := ClientHeight;
   left := 0;

   for i := 112 to 123 do
      begin
      if FKeys[i] = nil then
         begin
         Continue;
         end;
      FKeys[i].SetBounds(left, 0, w, h);
      Inc(left, w + 1);
      if (i = 115) or (i = 119) then
         begin
         Inc(left, 10);
         end;
      end;
end;

{ ONE LABEL PER PANEL, so the message can wrap.

  The label covers the panel and is TRANSPARENT, so SetKeyColor still works by
  colouring the panel underneath -- the yellow keys in NY4I's screenshot are the
  panel showing through.

  IT ALSO HAS TO PASS THE MOUSE THROUGH.  A label sits in front of its panel and
  would otherwise swallow every click, so it carries the same Tag and the same
  handlers; those read Sender's Tag rather than casting to TPanel. }
procedure TfrmFunctionKeys.BuildCaptionLabels;
var
   k: integer;
   lab: TLabel;
begin
   for k := Low(FKeys) to High(FKeys) do
      begin
      if (FKeys[k] = nil) or (FCaptions[k] <> nil) then
         begin
         Continue;
         end;

      lab := TLabel.Create(Self);
      lab.Parent      := FKeys[k];
      lab.Align       := alClient;
      lab.Alignment   := taCenter;
      lab.Layout      := tlCenter;
      lab.WordWrap    := True;
      lab.Transparent := True;
      lab.ParentColor := True;
      lab.Tag         := FKeys[k].Tag;
      lab.OnClick     := KeyPanelClick;
      lab.OnMouseDown := KeyPanelMouseDown;

      // SMALLER THAN THE FORM'S FONT.  D7's keys carry up to three lines in the
      // height of one button; at the inherited size two words fill the width and
      // the rest is clipped, which is what NY4I saw.
      lab.ParentFont := False;
      lab.Font.Height := -11;

      FCaptions[k] := lab;
      FKeys[k].Caption := '';   // the panel no longer draws its own text
      end;
end;

procedure TfrmFunctionKeys.SetKeyCaption(const aKey: integer; const aText: string);
begin
   if (aKey < Low(FCaptions)) or (aKey > High(FCaptions)) or
      (FCaptions[aKey] = nil) then
      begin
      Exit;
      end;
   FCaptions[aKey].Caption := aText;
end;

procedure TfrmFunctionKeys.SetKeyColor(const aKey: integer; const aColor: TColor);
begin
   if (aKey < Low(FKeys)) or (aKey > High(FKeys)) or (FKeys[aKey] = nil) then
      begin
      Exit;
      end;
   FKeys[aKey].Color := aColor;
end;

procedure TfrmFunctionKeys.KeyPanelClick(Sender: TObject);
begin
   // Tag IS the key code (112..123), set in the designer.  This replaces
   // WM_COMMAND / BN_CLICKED with LoWord(wParam) as the control id.
   if Assigned(FunctionKeyClicked) then
      begin
      FunctionKeyClicked(TComponent(Sender).Tag);
      end;
end;

procedure TfrmFunctionKeys.KeyPanelMouseDown(Sender: TObject; Button: TMouseButton;
                                             Shift: TShiftState; X, Y: integer);
begin
   if Button <> mbRight then
      begin
      Exit;
      end;

   // THE TWO DELETED LOOP ARMS.  tr4w.lpr compared Msg.HWND against the twelve
   // button handles for WM_RBUTTONDBLCLK and WM_RBUTTONDOWN; Sender says which
   // panel directly, so ResolveFunctionKeyRow no longer has to scan.
   //
   // ssDouble distinguishes them, which is how the LCL reports a double click --
   // there is no separate right-double-click event.
   if ssDouble in Shift then
      begin
      if Assigned(FunctionKeyRightDoubleClicked) then
         begin
         FunctionKeyRightDoubleClicked(TComponent(Sender).Tag);
         end;
      end
   else
      begin
      if Assigned(FunctionKeyRightClicked) then
         begin
         FunctionKeyRightClicked(TComponent(Sender).Tag);
         end;
      end;
end;

function CreateTR4WFunctionKeysWindow: HWND;
var
   f: TfrmFunctionKeys;
   i: integer;
begin
   if TR4WFunctionKeysForm = nil then
      begin
      TR4WFunctionKeysForm := TfrmFunctionKeys.Create(nil);
      end;
   f := TR4WFunctionKeysForm;

   // Indexed by key code so nothing else has to know the panels are named
   // pnlF1..pnlF12.
   f.FKeys[112] := f.pnlF1;   f.FKeys[113] := f.pnlF2;
   f.FKeys[114] := f.pnlF3;   f.FKeys[115] := f.pnlF4;
   f.FKeys[116] := f.pnlF5;   f.FKeys[117] := f.pnlF6;
   f.FKeys[118] := f.pnlF7;   f.FKeys[119] := f.pnlF8;
   f.FKeys[120] := f.pnlF9;   f.FKeys[121] := f.pnlF10;
   f.FKeys[122] := f.pnlF11;  f.FKeys[123] := f.pnlF12;

   for i := 112 to 123 do
      begin
      f.FKeys[i].Tag := i;
      end;

   // PARENTED THE LCL WAY.  CreateDialogParam took tr4whandle as the owner,
   // which is what kept this window above the main one and off the taskbar.
   // OwnFormByMainWindow does that with PopupParent / pmExplicit.  The first
   // draft reached for SetWindowLongPtr(GWL_HWNDPARENT) -- Win32 surface added
   // by the very change that exists to remove it.
   OwnFormByMainWindow(f);

   Result := f.Handle;
end;

end.

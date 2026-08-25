unit uRadioPanelForm;

{ THE RADIO 1 / RADIO 2 PANELS, AS ONE LCL FORM WITH TWO INSTANCES.

  Two instances of one form, like the dupe sheets and the five multiplier
  windows -- an SO2R station has both open at once.

  THE HARD PART WAS NOT THE CONTROLS, IT WAS THAT COLOUR MEANT STATE.

  The dialog's WM_CTLCOLORSTATIC asked IsWindowEnabled(RIT/XIT/SPLIT) and
  returned a yellow brush when the control was ENABLED, and returned light blue
  for whichever panel belonged to ActiveRadioPtr.  So EnableWindow was doing two
  jobs: recording whether the rig has RIT on, and making the label yellow.  An
  LCL label has no such coupling -- Enabled greys the text and nothing else --
  so the flag is explicit state here and the colour follows from it.

  That is a behaviour-preserving change no compiler can check, which is why it
  is spelled out, and why it is in the bench queue.

  THE WRITES STILL ARRIVE FROM THE RADIO'S READING THREAD, through uPanelUpdate
  exactly as before.  This unit installs two hooks so a marshalled update lands
  on a form control instead of going out as SetDlgItemTextA / EnableWindow.
  Nothing in uRadioPolling changed for this: it still posts (panel, control id),
  the coalescing is still keyed on that pair, and the panel handle is the form's
  own Handle so those keys stay valid. }

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, StdCtrls, Graphics, VC;

type
   TfrmRadioPanel = class(TForm)
      lblVFOACaption: TLabel;
      lblVFOBCaption: TLabel;
      lblVFOA: TLabel;
      lblVFOB: TLabel;
      lblModeA: TLabel;
      lblModeB: TLabel;
      lblRITFreq: TLabel;
      lblRIT: TLabel;
      lblXIT: TLabel;
      lblSplit: TLabel;
      lblStatus: TLabel;
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleKeyDown(Sender: TObject; var Key: word;
                              Shift: TShiftState);
   private
      FSlot: integer;
      FFlagOn: array[0..2] of boolean;
   public
      { The three flags that used to be a control's Enabled state.  aIndex is
        0 = RIT, 1 = XIT, 2 = SPLIT. }
      procedure SetFlag(const aIndex: integer; const aOn: boolean);

      { Light blue when this panel belongs to the active radio, as
        WM_CTLCOLORDLG did. }
      procedure SyncActiveTint;

      property Slot: integer read FSlot write FSlot;
   end;

function CreateTR4WRadioPanelWindow(const aID: WindowsType): HWND;
function RadioPanelForm(const aID: WindowsType): TfrmRadioPanel;

{ Repaint both panels' active-radio tint.  Replaces the pair of InvalidateRect
  calls that made WM_CTLCOLORDLG run again. }
procedure RadioPanelsRefreshActive;

implementation

{$R *.lfm}

uses
   MainUnit,
   LOGRADIO,
   uPanelUpdate,
   uLCLFormHelpers;

var
   GForms: array[1..2] of TfrmRadioPanel = (nil, nil);

function SlotOf(const aID: WindowsType): integer;
begin
   if aID = tw_RADIOINTERFACEWINDOW2_INDEX then
      begin
      Result := 2;
      end
   else
      begin
      Result := 1;
      end;
end;

function FlagLabel(const aForm: TfrmRadioPanel; const aIndex: integer): TLabel;
begin
   case aIndex of
     0: Result := aForm.lblRIT;
     1: Result := aForm.lblXIT;
   else
     Result := aForm.lblSplit;
   end;
end;

procedure TfrmRadioPanel.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   CloseAction := caHide;
   if FSlot = 2 then
      begin
      CloseTR4WWindow(tw_RADIOINTERFACEWINDOW2_INDEX);
      end
   else
      begin
      CloseTR4WWindow(tw_RADIOINTERFACEWINDOW1_INDEX);
      end;
end;

{ ESCAPE CLOSES IT.  A Win32 DialogBox did this for free; a TForm does not. }
procedure TfrmRadioPanel.HandleKeyDown(Sender: TObject; var Key: word;
                                       Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmRadioPanel.SetFlag(const aIndex: integer; const aOn: boolean);
var
   lab: TLabel;
begin
   if (aIndex < 0) or (aIndex > 2) then
      begin
      Exit;
      end;

   FFlagOn[aIndex] := aOn;
   lab := FlagLabel(Self, aIndex);

   // YELLOW WHEN SET, the panel's own background when not.  The dialog got this
   // by returning a yellow brush from WM_CTLCOLORSTATIC for an ENABLED control.
   if aOn then
      begin
      lab.Transparent := False;
      lab.Color := clYellow;
      end
   else
      begin
      lab.Transparent := True;
      lab.Color := Color;
      end;
end;

procedure TfrmRadioPanel.SyncActiveTint;
var
   mine: boolean;
   i: integer;
begin
   if FSlot = 2 then
      begin
      mine := ActiveRadioPtr = @Radio2;
      end
   else
      begin
      mine := ActiveRadioPtr = @Radio1;
      end;

   if mine then
      begin
      Color := TColor(tr4wColorsArray[trLightBlue]);
      end
   else
      begin
      Color := clBtnFace;
      end;

   // The unset flags take their colour FROM the form, so they must be redone
   // when it changes.  Reapplied from the STORED state, never read back off the
   // control -- reading it back is what made colour and state the same thing.
   for i := 0 to 2 do
      begin
      SetFlag(i, FFlagOn[i]);
      end;
end;

procedure RadioPanelsRefreshActive;
var
   i: integer;
begin
   for i := 1 to 2 do
      begin
      if GForms[i] <> nil then
         begin
         GForms[i].SyncActiveTint;
         end;
      end;
end;

{ ------------------------------------------------ the uPanelUpdate hooks --- }

{ Resolve a control id to one of this form's labels.  The ids are the dialog's,
  unchanged, because uRadioPolling still posts them and the coalescing cache is
  keyed on them. }
function LabelFor(const aForm: TfrmRadioPanel;
                  const aControlId: integer): TLabel;
begin
   case aControlId of
     102: Result := aForm.lblVFOA;
     104: Result := aForm.lblVFOB;
     105: Result := aForm.lblModeA;
     106: Result := aForm.lblModeB;
     120: Result := aForm.lblRITFreq;
     130: Result := aForm.lblStatus;
   else
     Result := nil;
   end;
end;

function FormForHandle(const aHandle: HWND): TfrmRadioPanel;
var
   i: integer;
begin
   Result := nil;
   for i := 1 to 2 do
      begin
      if (GForms[i] <> nil) and GForms[i].HandleAllocated and
         (GForms[i].Handle = aHandle) then
         begin
         Result := GForms[i];
         Exit;
         end;
      end;
end;

function PanelTextToForm(const aPanel: HWND; const aControlId: integer;
                         const aText: string): boolean;
var
   f: TfrmRadioPanel;
   lab: TLabel;
begin
   Result := False;
   f := FormForHandle(aPanel);
   if f = nil then
      begin
      Exit;
      end;

   lab := LabelFor(f, aControlId);
   if lab = nil then
      begin
      Exit;
      end;

   lab.Caption := aText;
   Result := True;
end;

{ THE THREE FLAGS, and the two VFO rows.

  121/122/123 are RIT/XIT/SPLIT, whose "enabled" was the dialog's way of saying
  the rig has that feature ON -- see the header.  102/104 are the VFO frequency
  rows, and there the meaning really is enabled/disabled: the INACTIVE VFO is
  greyed, which a TLabel does natively. }
function PanelEnableToForm(const aPanel: HWND; const aControlId: integer;
                           const aEnabled: boolean): boolean;
var
   f: TfrmRadioPanel;
begin
   Result := False;
   f := FormForHandle(aPanel);
   if f = nil then
      begin
      Exit;
      end;

   case aControlId of
     121: f.SetFlag(0, aEnabled);
     122: f.SetFlag(1, aEnabled);
     123: f.SetFlag(2, aEnabled);
     102: f.lblVFOA.Enabled := aEnabled;
     104: f.lblVFOB.Enabled := aEnabled;
   else
     Exit;
   end;

   Result := True;
end;

{ ---------------------------------------------------------- construction --- }

function RadioPanelForm(const aID: WindowsType): TfrmRadioPanel;
begin
   Result := GForms[SlotOf(aID)];
end;

function CreateTR4WRadioPanelWindow(const aID: WindowsType): HWND;
var
   slot: integer;
begin
   slot := SlotOf(aID);
   if GForms[slot] = nil then
      begin
      GForms[slot] := TfrmRadioPanel.Create(nil);
      GForms[slot].Slot := slot;
      end;

   OwnFormByMainWindow(GForms[slot]);

   Result := GForms[slot].Handle;
   GForms[slot].SyncActiveTint;
end;

initialization
   PanelTextHook   := @PanelTextToForm;
   PanelEnableHook := @PanelEnableToForm;

end.

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
   Classes, SysUtils, LCLType, Forms, Controls, StdCtrls, ExtCtrls, Graphics, VC,
  uTR4WStrings;

type
   TfrmRadioPanel = class(TForm)
      lblVFOACaption: TPanel;
      lblVFOBCaption: TPanel;
      lblVFOA: TPanel;
      lblVFOB: TPanel;
      lblModeA: TPanel;
      lblModeB: TPanel;
      lblRITFreq: TPanel;
      lblRIT: TPanel;
      lblXIT: TPanel;
      lblSplit: TPanel;
      lblStatus: TPanel;
      btnSpectrum: TButton;
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure SpectrumClick(Sender: TObject);
      procedure UpdateSpectrumButton;
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

{ Open one radio's panadapter, by SLOT.  Public because the start-up restore
  must be able to reopen a window whose radio panel is not itself open.  False
  means the radio cannot supply a spectrum right now. }
function OpenPanadapterForSlot(const aSlot: integer): boolean;

implementation

{$R *.lfm}

uses
   MainUnit,
   LOGRADIO,
   uFactoryRadioBase,   { rcSpectrum / SpectrumAvailable -- the two radio gates }
   uPanadapterForm,     { ShowPanadapterWindow }
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

function FlagLabel(const aForm: TfrmRadioPanel; const aIndex: integer): TPanel;
begin
   case aIndex of
     0: Result := aForm.lblRIT;
     1: Result := aForm.lblXIT;
   else
     Result := aForm.lblSplit;
   end;
end;

{ THE WAY INTO THE PANADAPTER, and the reason it is a button here rather than a
  menu item (PANADAPTER_LCL_DESIGN.md 12.1).

  IT BELONGS TO THE RADIO WHOSE SPECTRUM IT IS.  With two radios open there is
  no question which one a click means -- a Windows-menu item would have to ask,
  or guess from ActiveRadioPtr.

  AND IT HIDES ITSELF RATHER THAN GREYING.  A greyed control says "not now"; an
  absent one says "not this radio".  A K4 on a serial link has no spectrum
  stream at all -- the stream is a second UDP socket, CAT port + 1 -- so there
  is nothing an operator could do to enable it here, and offering a dead control
  invites the support case.  SpectrumAvailable is the instance answer;
  Supports(rcSpectrum) is the model one.  BOTH are asked, because a model that
  CAN is not the same fact as a connection that DOES.

  STILL MISSING, and deliberately: the operator's own enable/disable
  (PANADAPTER_LCL_DESIGN.md 12.3, a csJSON per-radio flag) and the
  IsSpectrumActive in MainUnit that would ask all three gates in ONE place.
  Until that exists this button asks the two gates the radio can answer, which
  is why the test lives here and not in a shared helper -- when the third gate
  arrives, both this and the menu item must move to it together or they will
  drift. }
procedure TfrmRadioPanel.UpdateSpectrumButton;
var
   rig: RadioPtr;
   obj: TFactoryRadioBase;
begin
   btnSpectrum.Visible := False;

   if FSlot = 2 then
      begin
      rig := @Radio2;
      end
   else
      begin
      rig := @Radio1;
      end;

   obj := rig^.tFactoryObject;
   if obj = nil then
      begin
      Exit;
      end;

   btnSpectrum.Visible := obj.Supports(rcSpectrum) and obj.SpectrumAvailable;
end;

{ OPEN ONE RADIO'S PANADAPTER.  Takes the SLOT rather than reading it off a
  form, because the start-up restore has to be able to reopen a window whose
  radio panel is not itself open.  Returns False when the radio cannot supply a
  spectrum, so the caller can say so rather than doing nothing visible. }
function OpenPanadapterForSlot(const aSlot: integer): boolean;
var
   rig: RadioPtr;
   caption, rigName: string;
begin
   Result := False;

   if aSlot = 2 then
      begin
      rig := @Radio2;
      end
   else
      begin
      rig := @Radio1;
      end;

   if rig^.tFactoryObject = nil then
      begin
      Exit;
      end;

   if not (rig^.tFactoryObject.Supports(rcSpectrum)
           and rig^.tFactoryObject.SpectrumAvailable) then
      begin
      Exit;
      end;

   { THE SAME NAME THE PANEL ITSELF CARRIES -- "Radio 1 K4D-278" -- so the
     panadapter title reads "Panadapter - Radio 1 K4D-278".  Built the same way
     as the panel's caption (MainUnit, OpenTR4WWindow): the localized label,
     plus the rig name ONLY when it differs, because RadioName is initialised to
     that same label and would otherwise read "Radio 1 Radio 1" on a station
     with no radio configured. }
   if aSlot = 2 then
      begin
      caption := TC_RADIO2;
      end
   else
      begin
      caption := TC_RADIO1;
      end;

   rigName := Trim(string(rig^.RadioName));
   if (rigName <> '') and (not SameText(rigName, caption)) then
      begin
      caption := caption + ' ' + rigName;
      end;

   { ONE PANADAPTER PER RADIO -- this panel's own slot.  Two K4s on an SO2R
     station get two windows; before 2026-08-26 the second STOLE the first,
     because a single global form was re-attached to whichever radio asked
     last. }
   { THE RADIO NAMES ITS OWN SOURCE, and this is NOT a label -- the window
     filters frames on equality against it (TfrmPanadapter.AcceptFrame).  A
     mismatch is not a wrong caption, it is a filter that matches nothing and a
     window that waits forever with nothing logged.

     THIS USED TO BE THE LITERAL 'A' and that was correct for exactly as long
     as the K4 was the only producer.  A K4 streams several pans down one
     socket and stamps each 'A', 'B' or 'Y'; a network Icom stamps its scope id,
     which is a NUMBER.  So the constant that worked for one family would have
     opened an Icom panadapter that connected, streamed, decoded, and drew
     nothing at all -- the worst shape of failure this seam can produce.

     RADIO 1 AND RADIO 2 ARE DIFFERENT RADIOS, not two sources of one rig, so
     each asks its own object for its own primary source. }
   ShowPanadapterWindow(aSlot, rig^.tFactoryObject,
                        rig^.tFactoryObject.PrimarySpectrumSourceId, caption);
   Result := True;
end;

procedure TfrmRadioPanel.SpectrumClick(Sender: TObject);
begin
   OpenPanadapterForSlot(FSlot);
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
   lab: TPanel;
begin
   if (aIndex < 0) or (aIndex > 2) then
      begin
      Exit;
      end;

   FFlagOn[aIndex] := aOn;
   lab := FlagLabel(Self, aIndex);

   // YELLOW WHEN SET, the form's own background when not.  The dialog got this
   // by returning a yellow brush from WM_CTLCOLORSTATIC for an ENABLED control.
   //
   // ParentColor RATHER THAN COPYING Color, which is what the TLabel version
   // did.  A copy goes stale: SyncActiveTint repaints the FORM when the active
   // radio changes, and a flag that was off still held the tint from before.
   // Parented, it follows for free.
   if aOn then
      begin
      lab.ParentColor := False;
      lab.Color := clYellow;
      end
   else
      begin
      lab.ParentColor := True;
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
         // A radio connecting or dropping is exactly when "is there a spectrum
         // stream" changes its answer, and this already runs then.
         GForms[i].UpdateSpectrumButton;
         end;
      end;
end;

{ ------------------------------------------------ the uPanelUpdate hooks --- }

{ Resolve a control id to one of this form's labels.  The ids are the dialog's,
  unchanged, because uRadioPolling still posts them and the coalescing cache is
  keyed on them. }
function LabelFor(const aForm: TfrmRadioPanel;
                  const aControlId: integer): TPanel;
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
   lab: TPanel;
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
  greyed, which a TPanel does natively. }
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

   { THE PANEL MAY NOT BE SHRUNK PAST ITS OWN READOUT.  It had no Constraints at
     all, so the window could be dragged down until the VFO frequencies were
     clipped -- with nothing to say so, which is the same complaint the open-
     contest dialog had about its category rows (NY4I, 2026-08-31).

     Derived from the controls rather than typed into the .lfm; see
     ApplyContentMinimumSize.  After OwnFormByMainWindow, so the form has its
     final frame when both terms are read. }

   ApplyContentMinimumSize(GForms[slot]);

   Result := GForms[slot].Handle;
   GForms[slot].SyncActiveTint;
   GForms[slot].UpdateSpectrumButton;
end;

initialization
   PanelTextHook   := @PanelTextToForm;
   PanelEnableHook := @PanelEnableToForm;

end.

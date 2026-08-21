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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uLPTForm;
{$I ..\..\tr4w.inc}

{
  THE LPT PORT DIALOG, AS AN LCL FORM.  Phase 4b.

  Three parallel-port base addresses, and which LPT port drives each of six
  functions: foot switch, paddle, the two band outputs, relay control and stereo
  control.

  THE LABEL IS THE COMMAND NAME, and that is not a metaphor. The Win32 version
  saved with

      for c := 101 to 109 do
         ID  := GetDialogItemText(hwnddlg, c);        // the STATIC's caption
         CMD := GetDialogItemText(hwnddlg, c + 100);  // the edit or combo

  -- it read the label off the screen and used it as the configuration key, which
  is why the captions read exactly `LPT1 BASE ADDRESS` and `FOOT SWITCH PORT`.
  Change a caption and you silently change which setting is written.

  That coupling is PRESERVED, because the settings really are named that, but it
  is now explicit: the captions are set in one place from the same table that
  drives the save, instead of being typed once into a dialog template and read
  back off a control.

  THREE DEAD ARMS ARE GONE. Control 50 -- an Apply button that is enabled and
  disabled but NEVER CREATED, so both calls were no-ops on a handle of 0 -- and
  the `wParam = 51` and `wParam = 52` arms, which nothing could send because no
  control with those ids exists either. 52 opened the calculator.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, LCLType,
  VC;   // PortType -- named in the class declaration below, so it belongs
        // in the INTERFACE uses, not the implementation one

type
  TfrmLPT = class(TForm)
    lblBase1, lblBase2, lblBase3: TLabel;
    edtBase1, edtBase2, edtBase3: TEdit;
    lblPort1, lblPort2, lblPort3, lblPort4, lblPort5, lblPort6: TLabel;
    cboPort1, cboPort2, cboPort3, cboPort4, cboPort5, cboPort6: TComboBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    FBaseLabels: array[1..3] of TLabel;
    FBaseEdits: array[1..3] of TEdit;
    FPortLabels: array[1..6] of TLabel;
    FPortCombos: array[1..6] of TComboBox;
    procedure BuildTables;
    procedure SelectPort(const aIndex: integer; const aPort: PortType);
    procedure SaveAndApply;
  end;

// the LPT port dialog.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.
procedure ShowLPTDialog;

implementation

{$R *.lfm}

uses
  Windows,
  uCFG,        // SetCFGCommandValue -- the one route to a [COMMANDS] value
  uIO,         // LPTBaseAA
  LogCfg,      // TryRunPaddleAndFootSwitchThread, InitializeOtherLPTPorts
  LogK1EA,     // the port globals, tUseControlPort, the paddle/footswitch thread
  LogRadio,    // Radio1 / Radio2 band output ports
  LogWind,
  MainUnit,    // logger
  uLCLFormHelpers,
  uHostedFormWindows,
  Log4D;

const
  // The SIX function names, and the source of both the captions and the
  // configuration keys.  One table, so a caption cannot drift from the setting
  // it writes.
  PORT_NAMES: array[1..6] of string =
    ('FOOT SWITCH', 'PADDLE', 'RADIO ONE BAND OUTPUT',
     'RADIO TWO BAND OUTPUT', 'RELAY CONTROL', 'STEREO CONTROL');

  // Ord(PortType) - 20 is the combo index the original used: 0 is NONE and
  // 1..3 are Parallel1..Parallel3.
  PORT_ORD_BASE = 20;

var
  frmLPT: TfrmLPT = nil;

procedure TfrmLPT.BuildTables;
begin
   FBaseLabels[1] := lblBase1;  FBaseLabels[2] := lblBase2;  FBaseLabels[3] := lblBase3;
   FBaseEdits[1]  := edtBase1;  FBaseEdits[2]  := edtBase2;  FBaseEdits[3]  := edtBase3;

   FPortLabels[1] := lblPort1;  FPortLabels[2] := lblPort2;  FPortLabels[3] := lblPort3;
   FPortLabels[4] := lblPort4;  FPortLabels[5] := lblPort5;  FPortLabels[6] := lblPort6;

   FPortCombos[1] := cboPort1;  FPortCombos[2] := cboPort2;  FPortCombos[3] := cboPort3;
   FPortCombos[4] := cboPort4;  FPortCombos[5] := cboPort5;  FPortCombos[6] := cboPort6;
end;

procedure TfrmLPT.SelectPort(const aIndex: integer; const aPort: PortType);
begin
   // NoPort leaves the combo on NONE, which is index 0 -- the original only
   // called SETCURSEL when the port was assigned, for the same reason.
   if aPort = NoPort then
      begin
      FPortCombos[aIndex].ItemIndex := 0;
      Exit;
      end;

   FPortCombos[aIndex].ItemIndex := Ord(aPort) - PORT_ORD_BASE;
end;

procedure TfrmLPT.HandleShow(Sender: TObject);
var
  i: integer;
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption := 'LPT';
   BuildTables;

   for i := 1 to 3 do
      begin
      FBaseLabels[i].Caption := Format('LPT%d BASE ADDRESS', [i]);
      FBaseEdits[i].Text     := IntToStr(LPTBaseAA[PortType(Ord(Parallel1) + i - 1)]);
      end;

   for i := 1 to 6 do
      begin
      FPortLabels[i].Caption := PORT_NAMES[i] + ' PORT';

      FPortCombos[i].Items.BeginUpdate;
      try
         FPortCombos[i].Items.Clear;
         FPortCombos[i].Items.Add('NONE');
         FPortCombos[i].Items.Add('1');
         FPortCombos[i].Items.Add('2');
         FPortCombos[i].Items.Add('3');
      finally
         FPortCombos[i].Items.EndUpdate;
      end;
      FPortCombos[i].ItemIndex := 0;

      // The foot switch and paddle are driven by the radio's control port when
      // that is in use, so their LPT assignment is not the operator's to make.
      if tUseControlPort and (i < 3) then
         begin
         FPortCombos[i].Enabled := False;
         end
      else
         begin
         FPortCombos[i].Enabled := True;
         end;
      end;

   SelectPort(1, ActiveFootSwitchPort);
   SelectPort(2, ActivePaddlePort);
   SelectPort(3, Radio1.BandOutputPort);
   SelectPort(4, Radio2.BandOutputPort);
   SelectPort(5, RelayControlPort);
   SelectPort(6, ActiveStereoPort);
end;

procedure TfrmLPT.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmLPT.SaveAndApply;
var
  i: integer;
begin
   // Through the registry, never straight at the ini: SetCFGCommandValue runs
   // CheckCommand first, which is what assigns the globals and enforces each
   // row's bounds.  The Win32 version wrote the file BEFORE validating, which
   // is what c823c055 fixed here.
   for i := 1 to 3 do
      begin
      SetCFGCommandValue(FBaseLabels[i].Caption, FBaseEdits[i].Text);
      end;

   for i := 1 to 6 do
      begin
      SetCFGCommandValue(FPortLabels[i].Caption, FPortCombos[i].Text);
      end;

   tDoingFootSwitchEnable := ActiveFootSwitchPort <> NoPort;
   DoingPaddle            := ActivePaddlePort <> NoPort;

   // With the radio's control port in use, the paddle and foot switch are live
   // whatever the combos say -- they come off the radio, not off an LPT.
   if tUseControlPort then
      begin
      if Radio1.tCATPortHandle <> INVALID_HANDLE_VALUE then
         begin
         DoingPaddle            := True;
         tDoingFootSwitchEnable := True;
         end;
      end;

   tDispalyPaddleAndFootSwitchStatus;

   if (not DoingPaddle) and (not tDoingFootSwitchEnable) then
      begin
      tExitFromPaddleFootSwitchThread := True;
      tPaddleFootSwitchThread         := INVALID_HANDLE_VALUE;
      end
   else
      begin
      TryRunPaddleAndFootSwitchThread;
      end;

   InitializeOtherLPTPorts;
end;

procedure TfrmLPT.btnOKClick(Sender: TObject);
begin
   SaveAndApply;
   Close;
end;

procedure TfrmLPT.btnCancelClick(Sender: TObject);
begin
   Close;
end;

procedure ShowLPTDialog;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmLPT = nil then
         begin
         frmLPT := TfrmLPT.Create(Application);
         end;
      // THROUGH THE ONE DOOR, parent 0.  There is no raw Win32 parent to
      // disable here, but ShowModalOverWin32Parent is also where the main
      // window is made the owner and the form is centred over it -- see
      // OwnFormByMainWindow.  A bare ShowModal skips both.
      ShowModalOverWin32Parent(frmLPT, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowLPTDialog failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.

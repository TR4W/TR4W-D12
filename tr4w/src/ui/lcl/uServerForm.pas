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
unit uServerForm;
{$I ..\..\tr4w.inc}

{
  TR4WSERVER'S WINDOW, AS AN LCL FORM.

  WHAT IT REPLACES. tr4wserver was a Win32 DIALOG APPLICATION: its entire body
  was

      DialogBox(hInstance, MAKEINTRESOURCE(100), 0, @TR4wServerDlgProc);

  -- a 466-line dialog procedure driving eleven controls addressed by NUMBER
  (102, 103, 104, 106, 108, 109, 110, 112, 115, 117, 118) through
  SetDlgItemInt, SendDlgItemMessage and EnableWindow. The template lived in a
  .res nobody could open in a designer, which is how it once linked the WRONG
  resource file and the program exited silently with no window at all.

  THE CONTROLS HAVE NAMES NOW, and that is most of the point. What used to read

      SetDlgItemInt(ApplicationHandle, 115, ... , False);

  reads SetServerLogQSOs, and the number is gone from the caller.

  THE CAPTIONS ARE IN THE .lfm, DELIBERATELY, unlike every converted window in
  the client. There the rule is that a caption must come from a TC_/RC_
  constant, because those are what the sixteen .po catalogues translate and a
  re-typed English caption is a translation silently lost. TR4WSERVER HAS NO
  CATALOGUE: its strings were baked into a Win32 dialog template in a .res,
  which pas2po never read and could not. So there is no translation to lose
  here, and inventing constants would only imply one exists.

  IT DOES NOT KNOW WHAT A SOCKET IS. Everything below is a setter or an event;
  the engine is tr4wserverUnit and the transport is uServerNet. This unit is
  the window and nothing else, which is what lets the server become an LCL
  application without the protocol moving at the same time.
}

interface

uses
   Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls;

type

   { Raised when the operator asks to stop the server or closes the window.
     Answering False cancels -- the old dialog asked "Do you really want to
     disconnect server`s clients?" and this keeps that decision with the
     engine, which is the only thing that knows whether any are connected. }
   TServerStopQuery = function: boolean;

   TfrmServer = class(TForm)
      lblVersionCaption: TLabel;
      lblVersion:        TLabel;
      lblPortCaption:    TLabel;
      edtPort:           TEdit;
      lblIPCaption:      TLabel;
      cboBind:           TComboBox;
      btnStart:          TButton;
      btnStop:           TButton;
      grpClients:        TGroupBox;
      lstClients:        TListBox;
      lblClientsCaption: TLabel;
      lblClients:        TLabel;
      lblRcvdCaption:    TLabel;
      lblRcvd:           TLabel;
      lblSentCaption:    TLabel;
      lblSent:           TLabel;
      lblQSOsCaption:    TLabel;
      lblQSOs:           TLabel;
      chkSerialLockout:  TCheckBox;

      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
      procedure btnStartClick(Sender: TObject);
      procedure btnStopClick(Sender: TObject);
   private
      FStopping: boolean;
   end;

var
   { The one instance, or nil before Application.CreateForm.  Every setter
     below tolerates nil so the engine can report progress during start-up and
     during shutdown without guarding each call. }
   frmServer: TfrmServer = nil;

   { Installed by the program.  See TServerStopQuery. }
   ServerStopQuery: TServerStopQuery = nil;

   { Called when the operator presses Start or Stop. }
   ServerStartRequested: procedure = nil;
   ServerStopRequested:  procedure = nil;

{ ---- what the engine calls.  Names, not control numbers. --------------- }

procedure SetServerVersion(const aText: string);
procedure SetServerPort(const aPort: integer);
function  GetServerPort(const aDefault: integer): integer;

(* WHICH ADDRESSES THE OPERATOR MAY BIND TO, and which to preselect.

  This was SetServerIP, a LABEL showing one address out of several -- and not
  the one the listener used, because the listener had no Bindings at all and
  bound to everything. It reported a guess as though it were a fact.

  "All interfaces" is row 0 and means the empty string: the behaviour this
  server has always had, and the right default -- a contest station that binds
  to the wrong NIC loses its network at the worst possible moment. *)
procedure SetBindAddresses(const aAddresses: TStrings; const aPreferred: string);

{ The chosen address, or EMPTY for every interface. }
function GetBindAddress: string;

procedure SetServerRunning(const aRunning: boolean);
procedure SetSerialLockout(const aEnabled: boolean);

procedure SetClientCount(const aCount: integer);
procedure SetClientList(const aLines: TStrings);
procedure SetBytesReceivedKB(const aKB: integer);
procedure SetBytesSentKB(const aKB: integer);
procedure SetServerLogQSOs(const aCount: integer);

implementation

{$R *.lfm}

uses
   LCLType;

{ ---------------------------------------------------------------- setters }

procedure SetServerVersion(const aText: string);
begin
   if frmServer <> nil then
      begin
      frmServer.lblVersion.Caption := TCaption(aText);
      end;
end;

procedure SetServerPort(const aPort: integer);
begin
   if frmServer <> nil then
      begin
      frmServer.edtPort.Text := IntToStr(aPort);
      end;
end;

(* THE PORT IS READ BACK FROM THE FIELD, not remembered separately, because the
  operator can edit it before pressing Start. StrToIntDef with the caller's
  default: a field someone has emptied must not become port 0. *)
function GetServerPort(const aDefault: integer): integer;
begin
   Result := aDefault;
   if frmServer <> nil then
      begin
      Result := StrToIntDef(Trim(frmServer.edtPort.Text), aDefault);
      end;
end;

(* THE ITEM TEXT IS THE VALUE, for every row but the first.

  No parallel array and nothing stashed in Objects: rows 1..n ARE the
  addresses, so there is one representation of the choice and it cannot drift
  out of step with what is displayed. Row 0 is the only special case, and it is
  the empty string. *)
const
   ALL_INTERFACES = 'All interfaces (0.0.0.0)';

procedure SetBindAddresses(const aAddresses: TStrings; const aPreferred: string);
var
   at: integer;
begin
   if frmServer = nil then
      begin
      Exit;
      end;

   frmServer.cboBind.Items.BeginUpdate;
   try
      frmServer.cboBind.Items.Clear;
      frmServer.cboBind.Items.Add(ALL_INTERFACES);
      frmServer.cboBind.Items.AddStrings(aAddresses);
   finally
      frmServer.cboBind.Items.EndUpdate;
   end;

   { A preference naming an address that no longer exists -- a NIC removed, a
     DHCP lease moved -- simply does not match, and row 0 is the answer. The
     caller says so out loud; here it is only a lookup. }
   at := 0;
   if aPreferred <> '' then
      begin
      at := frmServer.cboBind.Items.IndexOf(aPreferred);
      if at < 1 then
         begin
         at := 0;
         end;
      end;

   frmServer.cboBind.ItemIndex := at;
end;

function GetBindAddress: string;
begin
   Result := '';
   if (frmServer = nil) or (frmServer.cboBind.ItemIndex <= 0) then
      begin
      Exit;
      end;

   Result := frmServer.cboBind.Items[frmServer.cboBind.ItemIndex];
end;

(* START AND STOP ARE ONE STATE, not two enables that a caller has to keep in
  step. The dialog set them separately -- EnableWindow(103, False) and
  EnableWindow(104, True) on adjacent lines -- which is two chances to get it
  wrong and no way to ask what the state is. *)
procedure SetServerRunning(const aRunning: boolean);
begin
   if frmServer <> nil then
      begin
      frmServer.btnStart.Enabled := not aRunning;
      frmServer.btnStop.Enabled  := aRunning;
      frmServer.edtPort.Enabled  := not aRunning;
      { Fixed while it is bound, exactly like the port beside it. }
      frmServer.cboBind.Enabled  := not aRunning;
      end;
end;

procedure SetSerialLockout(const aEnabled: boolean);
begin
   if frmServer <> nil then
      begin
      frmServer.chkSerialLockout.Checked := aEnabled;
      end;
end;

procedure SetClientCount(const aCount: integer);
begin
   if frmServer <> nil then
      begin
      frmServer.lblClients.Caption := TCaption(IntToStr(aCount));
      { The old DisplayClients also wrote the count into the TITLE BAR, with
        SetWindowTextA(ApplicationHandle, 'TR4WSERVER [n]').  Kept: at a
        multi-op it is read from the taskbar without raising the window. }
      frmServer.Caption := TCaption(Format('TR4WSERVER [%d]', [aCount]));
      end;
end;

(* THE WHOLE LIST AT ONCE, because that is what the caller has.  DisplayClients
  walked its array and sent LB_RESETCONTENT then one LB_ADDSTRING per client;
  BeginUpdate/EndUpdate is the same idea and the LCL owns the flicker. *)
procedure SetClientList(const aLines: TStrings);
begin
   if frmServer = nil then
      begin
      Exit;
      end;

   frmServer.lstClients.Items.BeginUpdate;
   try
      frmServer.lstClients.Items.Assign(aLines);
   finally
      frmServer.lstClients.Items.EndUpdate;
   end;
end;

procedure SetBytesReceivedKB(const aKB: integer);
begin
   if frmServer <> nil then
      begin
      frmServer.lblRcvd.Caption := TCaption(IntToStr(aKB));
      end;
end;

procedure SetBytesSentKB(const aKB: integer);
begin
   if frmServer <> nil then
      begin
      frmServer.lblSent.Caption := TCaption(IntToStr(aKB));
      end;
end;

procedure SetServerLogQSOs(const aCount: integer);
begin
   if frmServer <> nil then
      begin
      frmServer.lblQSOs.Caption := TCaption(IntToStr(aCount));
      end;
end;

{ ------------------------------------------------------------ the form --- }

procedure TfrmServer.HandleShow(Sender: TObject);
begin
   SetServerRunning(False);
end;

procedure TfrmServer.btnStartClick(Sender: TObject);
begin
   if Assigned(ServerStartRequested) then
      begin
      ServerStartRequested();
      end;
end;

(* STOP AND CLOSE ARE THE SAME PATH, as they were in the dialog: its WM_COMMAND
  arm for button 104 fell through a label into the WM_CLOSE arm. Closing the
  window shuts the server down; there is no "leave it running hidden". *)
procedure TfrmServer.btnStopClick(Sender: TObject);
begin
   Close;
end;

procedure TfrmServer.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   Action := caNone;

   { Re-entry is real: the confirmation is modal, and the operator can press
     the window's X again while it is up. }
   if FStopping then
      begin
      Exit;
      end;

   FStopping := True;
   try
      if Assigned(ServerStopQuery) and (not ServerStopQuery()) then
         begin
         Exit;
         end;

      if Assigned(ServerStopRequested) then
         begin
         ServerStopRequested();
         end;

      Action := caFree;
      Application.Terminate;
   finally
      FStopping := False;
   end;
end;

end.

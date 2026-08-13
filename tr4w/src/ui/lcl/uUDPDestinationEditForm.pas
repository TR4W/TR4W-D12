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
unit uUDPDestinationEditForm;
{$I ..\..\tr4w.inc}

{
  One UDP destination, edited in isolation: an address, a port, and which kinds
  of data that endpoint wants.

  Shaped exactly like uKeyerEditForm -- designed .fmx, published control fields
  whose names match the resource, published event handlers, captions from the
  designer, population in code -- and MODELESS for the same reason: ShowModal
  runs FMX's own message loop, which would stop TR4W's, and with it the key
  handling, CW timing and radio servicing, for as long as the dialog is up.
  The result comes back through a callback.

  THE ROW IS AN ENDPOINT, not a stream.  One program listening usually wants
  several kinds of data, so the streams are checkboxes on one destination rather
  than six near-identical rows that have to be kept in step by hand.  The port
  stays per destination because it genuinely varies by stream -- N1MM puts
  RadioInfo on 12060 and ContactInfo on 12061, so one station is two rows here
  (NY4I 2026-08-08).

  IT EDITS THE OBJECT IT IS GIVEN.  The caller passes a CLONE when it wants a
  cancellable edit, which is what TPrefsForm does; Cancel then costs nothing and
  the accepted values are assigned back onto the original so its identity -- and
  anything holding it -- survives.
}

interface

uses
   SysUtils,
   Classes,
   System.UITypes,
   Controls,
   Forms,
   StdCtrls,
   ExtCtrls,
   uUDPBroadcastConfig;

type
   TUDPDestinationEditDone = procedure(const aAccepted: boolean) of object;

   // PUBLISHED for streaming: a control binds to a field only when the field is
   // published and its name matches the component's Name, and an event binds
   // only when the handler is a published method, because TWriter stores it BY
   // NAME.  Both directions are checked by Lint-FormFields, which gates the
   // build.
   TfrmUDPDestinationEdit = class(TForm)
      lblAddress: TLabel;
      edtAddress: TEdit;
      lblPort: TLabel;
      edtPort: TEdit;

      grpStreams: TGroupBox;
      chkStreamContact: TCheckBox;
      chkStreamRadio: TCheckBox;
      chkStreamScore: TCheckBox;
      chkStreamRotor: TCheckBox;
      chkStreamLookup: TCheckBox;
      chkStreamAppInfo: TCheckBox;

      btnTest: TButton;
      lblTestResult: TLabel;
      btnOK: TButton;
      btnCancel: TButton;

      procedure btnTestClick(Sender: TObject);
      procedure btnOKClick(Sender: TObject);
      procedure btnCancelClick(Sender: TObject);
      procedure FormShow(Sender: TObject);
      procedure FormClose(Sender: TObject; var Action: TCloseAction);
   private
      FDestination: TUDPDestination;
      FOnDone: TUDPDestinationEditDone;

      function  StreamCheckBox(const aStream: TUDPStream): TCheckBox;
      function  CheckedStreams: TUDPStreams;
      function  TypedPort: integer;
      procedure LoadFromDestination;
      function  SaveToDestination(out aError: string): boolean;
   public
      constructor Create(AOwner: TComponent); override;
      procedure EditDestination(const aDestination: TUDPDestination;
                                const aOnDone: TUDPDestinationEditDone);
   end;

implementation

{$R *.lfm}

uses
   uHostedFormWindows,
   Dialogs,
   uLCLFormHelpers,
   uLCLTranslate,
   uUDPBroadcaster;

const
   // Said at the point of use, because it CHANGES -- the designer owns the
   // static captions, this owns the ones that depend on what happened.
   TC_UDPEDIT_NOTIMPLEMENTED = ' (not implemented yet)';
   TC_UDPEDIT_TESTSENT       = 'Test packet sent to %s:%d.  UDP cannot confirm ' +
                               'it arrived -- check the receiving program.';
   TC_UDPEDIT_NOADDRESS      = 'Enter an address.';
   TC_UDPEDIT_BADPORT        = 'The port must be a number between 1 and 65535.';
   TC_UDPEDIT_NOSTREAMS      = 'Choose at least one kind of data to send, or ' +
                               'cancel and remove this destination.';

constructor TfrmUDPDestinationEdit.Create(AOwner: TComponent);
begin
   // Create, not CreateNew: the inherited constructor finds the resource named
   // for this class and streams the layout in.
   inherited Create(AOwner);

   TranslateForm(Self);

   // Assigned here as well as bound in the resource: losing them is invisible.
   // The form still opens and looks right, having silently stopped registering
   // its window handle with the coexistence layer, which is what keyboard
   // handling depends on.
   OnShow  := FormShow;
   OnClose := FormClose;

   // SAID, not hidden.  Nothing in TR4W sends an app-info broadcast yet -- the
   // stream exists in the format and the feature is unfinished rather than
   // withdrawn (NY4I 2026-08-08).  A greyed box that says why beats both a
   // missing one and a live one that quietly does nothing.
   chkStreamAppInfo.Caption := chkStreamAppInfo.Caption + TC_UDPEDIT_NOTIMPLEMENTED;
   chkStreamAppInfo.Enabled := False;
end;

// The control for one stream.  A case rather than a lookup table because a
// table of control references cannot be a constant -- and the ELSE branch is
// the honest answer for a stream added to the enum and not given a box here:
// it is left out of both loading and saving rather than silently mapped onto
// somebody else's checkbox.
function TfrmUDPDestinationEdit.StreamCheckBox(const aStream: TUDPStream): TCheckBox;
begin
   case aStream of
      usAppInfo: Result := chkStreamAppInfo;
      usContact: Result := chkStreamContact;
      usScore:   Result := chkStreamScore;
      usRadio:   Result := chkStreamRadio;
      usRotor:   Result := chkStreamRotor;
      usLookup:  Result := chkStreamLookup;
   else
      Result := nil;
   end;
end;

function TfrmUDPDestinationEdit.CheckedStreams: TUDPStreams;
var
   st: TUDPStream;
   box: TCheckBox;
begin
   Result := [];
   for st := Low(TUDPStream) to High(TUDPStream) do
      begin
      box := StreamCheckBox(st);
      if (box <> nil) and box.Checked then
         begin
         Include(Result, st);
         end;
      end;
end;

function TfrmUDPDestinationEdit.TypedPort: integer;
begin
   // StrToIntDef, not StrToInt: this is read while the operator is still typing
   // (the Test button), and an exception is not an answer to "12 6 0".  0 is
   // outside the legal range, so it fails validation like any other bad value.
   Result := StrToIntDef(Trim(edtPort.Text), 0);
end;

procedure TfrmUDPDestinationEdit.EditDestination(const aDestination: TUDPDestination;
                                                 const aOnDone: TUDPDestinationEditDone);
begin
   FDestination := aDestination;
   FOnDone      := aOnDone;
   LoadFromDestination;
   Show;
   BringToFront;
end;

procedure TfrmUDPDestinationEdit.LoadFromDestination;
var
   st: TUDPStream;
   box: TCheckBox;
begin
   lblTestResult.Caption := '';

   if FDestination = nil then
      begin
      Exit;
      end;

   edtAddress.Text := FDestination.Address;
   edtPort.Text    := IntToStr(FDestination.Port);

   for st := Low(TUDPStream) to High(TUDPStream) do
      begin
      box := StreamCheckBox(st);
      if box <> nil then
         begin
         box.Checked := FDestination.Carries(st);
         end;
      end;
end;

function TfrmUDPDestinationEdit.SaveToDestination(out aError: string): boolean;
var
   streams: TUDPStreams;
   port: integer;
begin
   aError := '';
   Result := False;

   if FDestination = nil then
      begin
      Exit;
      end;

   // Checked HERE as well as in TUDPBroadcastConfig.Validate, and that is not
   // redundant: this names the field while the operator is looking at it,
   // whereas Validate names a row by number when the whole panel is saved.  The
   // rules are the same rules; only the moment differs.
   if Trim(edtAddress.Text) = '' then
      begin
      aError := TC_UDPEDIT_NOADDRESS;
      Exit;
      end;

   port := TypedPort;
   if (port < 1) or (port > 65535) then
      begin
      aError := TC_UDPEDIT_BADPORT;
      Exit;
      end;

   // A destination that carries nothing is not "switched off" -- it is an
   // address and a port that will never be sent anything while looking
   // configured on the panel.
   streams := CheckedStreams;
   if streams = [] then
      begin
      aError := TC_UDPEDIT_NOSTREAMS;
      Exit;
      end;

   FDestination.Address := Trim(edtAddress.Text);
   FDestination.Port    := port;
   FDestination.Streams := streams;
   Result := True;
end;

procedure TfrmUDPDestinationEdit.btnTestClick(Sender: TObject);
var
   err: string;
begin
   // Tests WHAT IS TYPED, not what is saved -- the whole point of the button is
   // to try an endpoint before committing to it.  It goes through the
   // broadcaster because that is where the socket is, but it deliberately
   // ignores both the master switch and the destination list: "does this
   // address work" is a different question from "am I broadcasting now".
   if UDPBroadcaster.TestDestination(Trim(edtAddress.Text), TypedPort, err) then
      begin
      // Says SENT, never "reached".  UDP gives no delivery confirmation and
      // wording it as though it did would send someone debugging the wrong end.
      lblTestResult.Caption := Format(TC_UDPEDIT_TESTSENT,
                                   [Trim(edtAddress.Text), TypedPort]);
      end
   else
      begin
      lblTestResult.Caption := err;
      end;
end;

procedure TfrmUDPDestinationEdit.btnOKClick(Sender: TObject);
var
   err: string;
begin
   if not SaveToDestination(err) then
      begin
      ShowMessage(err);
      Exit;
      end;
   Hide;
   if Assigned(FOnDone) then
      begin
      FOnDone(True);
      end;
end;

procedure TfrmUDPDestinationEdit.btnCancelClick(Sender: TObject);
begin
   Hide;
   if Assigned(FOnDone) then
      begin
      FOnDone(False);
      end;
end;

procedure TfrmUDPDestinationEdit.FormShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);
end;

procedure TfrmUDPDestinationEdit.FormClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
   // Closing with the window button means Cancel: the operator did not accept.
   if Assigned(FOnDone) then
      begin
      FOnDone(False);
      end;
end;

end.

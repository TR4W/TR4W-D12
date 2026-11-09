unit uUrlTestButton;
{$I ..\..\tr4w.inc}
(*
  A TEST BUTTON BESIDE A URL EDIT -- the reusable piece (issue 251).

  TUrlTester wires three plain controls that the .lfm already holds: an edit, a
  button and a label. Click the button and the edit's text, as it stands (saved
  or not), is asked for with one read-only GET on a worker thread; the label
  then says what came back ("Answered 200", "No answer: ..."), and the full
  sentence is also its tooltip. The wording and the request are uUrlTest's.
  Another URL field adopts it with three controls and one line:

      TUrlTester.Create(Self, edtSomeUrl, btnSomeUrlTest, lblSomeUrlResult);

  WHY PLAIN CONTROLS AND A NON-VISUAL HELPER, NOT A CUSTOM CONTROL: a custom
  class in the .lfm needs RegisterClass and cannot be seen by the lfm lints;
  three ordinary controls are designed, laid out and linted like any others.

  WHAT IT NEVER DOES. It saves nothing and marks nothing changed: a test is not
  an edit. It never touches a control from the worker thread: the thread only
  fills a ticket, and this component reads the ticket from a TIMER on the main
  thread. It holds no thread, so closing the form never waits for a request; a
  request still in flight just finishes into a ticket nobody reads.

  ORDER OF CONSTRUCTION MATTERS ONCE. The tester chains the edit's OnChange (it
  must blank a result that no longer describes the text), keeping whatever was
  there -- the designed handler, or MarkDirty. Preferences' HookDirtyMarkers
  installs MarkDirty only on an edit that has NO OnChange, so create the tester
  AFTER HookDirtyMarkers has run, or the edit stops arming Save.
*)

interface

uses
   Classes, SysUtils, Controls, StdCtrls, ExtCtrls, uUrlTest;

type
   TUrlTester = class(TComponent)
   private
      FEdit:       TEdit;
      FButton:     TButton;
      FResult:     TLabel;
      (* THE ROW'S OWN "VERIFY THE SERVER'S CERTIFICATE" BOX (issue 256), or nil
        for a row with none. Read at the moment of the click, so a test sees
        what the real call sees. *)
      FVerify:     TCheckBox;
      FDestination: string;
      FTimer:      TTimer;
      FTicket:     IUrlTestTicket;
      FPrevChange: TNotifyEvent;
      FPrevVerifyChange: TNotifyEvent;
      procedure ButtonClick(Sender: TObject);
      procedure EditChange(Sender: TObject);
      procedure VerifyChange(Sender: TObject);
      procedure PollTimer(Sender: TObject);
      procedure ShowText(const aText: string);
      procedure DropTicket;
      procedure ShowBusy(aBusy: boolean);
   protected
      procedure Notification(aComponent: TComponent; aOperation: TOperation); override;
   public
      (* aVerify is the row's certificate box, or nil; aDestination names the
        row in the log. *)
      constructor Create(aOwner: TComponent; aEdit: TEdit; aButton: TButton;
                         aResult: TLabel; aVerify: TCheckBox = nil;
                         const aDestination: string = ''); reintroduce;
      destructor Destroy; override;
      function Running: boolean;
   end;

implementation

uses
   uAppStrings;

const
   POLL_INTERVAL_MS = 200;

constructor TUrlTester.Create(aOwner: TComponent; aEdit: TEdit; aButton: TButton;
                              aResult: TLabel; aVerify: TCheckBox;
                              const aDestination: string);
begin
   inherited Create(aOwner);
   FEdit   := aEdit;
   FButton := aButton;
   FResult := aResult;
   FVerify := aVerify;
   FDestination := aDestination;

   (* If one of the three is freed first, forget it rather than touch it. *)
   FEdit.FreeNotification(Self);
   FButton.FreeNotification(Self);
   FResult.FreeNotification(Self);

   FTimer          := TTimer.Create(Self);
   FTimer.Enabled  := False;
   FTimer.Interval := POLL_INTERVAL_MS;
   FTimer.OnTimer  := PollTimer;

   FButton.Caption := UTF8Encode(SUrlTestButton);
   FButton.OnClick := ButtonClick;
   FResult.Caption := '';
   FResult.ShowHint := True;

   FPrevChange     := FEdit.OnChange;
   FEdit.OnChange  := EditChange;

   if FVerify <> nil then
      begin
      (* Ticking the box changes what the test would do, so a result shown
        for the old choice is blanked, like one for old text. *)
      FVerify.FreeNotification(Self);
      FPrevVerifyChange := FVerify.OnChange;
      FVerify.OnChange  := VerifyChange;
      end;
end;

destructor TUrlTester.Destroy;
begin
   (* The ticket reference is dropped; a worker still running finishes into a
     ticket nobody reads. Nothing here waits. *)
   (* Put the edit's handler back if it is still ours (an event's Data is the
     object it belongs to). *)
   if (FEdit <> nil) and (TMethod(FEdit.OnChange).Data = Pointer(Self)) then
      begin
      FEdit.OnChange := FPrevChange;
      end;
   if (FVerify <> nil) and (TMethod(FVerify.OnChange).Data = Pointer(Self)) then
      begin
      FVerify.OnChange := FPrevVerifyChange;
      end;
   FTicket := nil;
   ShowBusy(False);
   inherited Destroy;
end;

procedure TUrlTester.Notification(aComponent: TComponent; aOperation: TOperation);
begin
   inherited Notification(aComponent, aOperation);
   if aOperation = opRemove then
      begin
      if aComponent = FEdit then
         begin
         FEdit := nil;
         end;
      if aComponent = FButton then
         begin
         FButton := nil;
         end;
      if aComponent = FResult then
         begin
         FResult := nil;
         end;
      if aComponent = FVerify then
         begin
         FVerify := nil;
         end;
      end;
end;

function TUrlTester.Running: boolean;
begin
   Result := FTicket <> nil;
end;

procedure TUrlTester.ShowText(const aText: string);
begin
   if FResult = nil then
      begin
      Exit;
      end;
   FResult.Caption := UTF8Encode(aText);
   FResult.Hint    := UTF8Encode(aText);
end;

(* Forget a request in flight: its answer is for text that is no longer there,
  or for a form that is going. The thread is not stopped (it cannot be
  interrupted); it finishes harmlessly. *)
procedure TUrlTester.DropTicket;
begin
   FTicket := nil;
   if FTimer <> nil then
      begin
      FTimer.Enabled := False;
      end;
   if FButton <> nil then
      begin
      FButton.Enabled := True;
      end;
   ShowBusy(False);
end;

(* THE "WORKING IN THE BACKGROUND" CURSOR (arrow with a small hourglass) on this
  row's button and result label ONLY, never Screen.Cursor or the form: three
  rows can run at once and each owns its own two controls, so no shared counter
  is needed. A control freed first was forgotten by Notification (nil). *)
procedure TUrlTester.ShowBusy(aBusy: boolean);
var
   cursor: TCursor;
begin
   if aBusy then
      begin
      cursor := crAppStart;
      end
   else
      begin
      cursor := crDefault;
      end;
   if FButton <> nil then
      begin
      FButton.Cursor := cursor;
      end;
   if FResult <> nil then
      begin
      FResult.Cursor := cursor;
      end;
end;

procedure TUrlTester.ButtonClick(Sender: TObject);
var
   verify: boolean;
begin
   if (FEdit = nil) or (FButton = nil) or (FTicket <> nil) then
      begin
      Exit;
      end;
   ShowText(SUrlTestRunning);
   FButton.Enabled := False;
   ShowBusy(True);
   verify := True;
   if FVerify <> nil then
      begin
      verify := FVerify.Checked;
      end;
   FTicket         := StartUrlTest(UTF8Decode(FEdit.Text), verify, FDestination);
   FTimer.Enabled  := True;
end;

(* The certificate box changed: a result (or a request still running) belongs
  to the old choice. Then the box's own handler runs (MarkDirty, the warning). *)
procedure TUrlTester.VerifyChange(Sender: TObject);
begin
   DropTicket;
   ShowText('');
   if Assigned(FPrevVerifyChange) then
      begin
      FPrevVerifyChange(Sender);
      end;
end;

(* The edit changed: whatever the label says, or a request still running, is
  about the OLD text. Then the edit's own handler runs (Dirty, the plain-http
  note, ...). *)
procedure TUrlTester.EditChange(Sender: TObject);
begin
   DropTicket;
   ShowText('');
   if Assigned(FPrevChange) then
      begin
      FPrevChange(Sender);
      end;
end;

procedure TUrlTester.PollTimer(Sender: TObject);
var
   outcome: TUrlTestOutcome;
begin
   if (FTicket = nil) or (not FTicket.Finished) then
      begin
      Exit;
      end;
   outcome := FTicket.Outcome;
   if outcome <> nil then
      begin
      ShowText(outcome.Text);
      end;
   DropTicket;
end;

end.

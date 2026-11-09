unit uTestUrlTest;
{$I ..\..\src\tr4w.inc}
(*
  THE URL TEST BUTTON (issue 251): what it asks, what it says, and that the
  worker and the control behave.

  NO NETWORK. The request goes through the shared HTTP layer to a scripted
  TFakeHttpTransport, so what is pinned here is what the PROGRAM decides: the
  request is a read-only GET with no credentials, plain http is allowed, a
  redirect's final address is shown, and every outcome is worded as an answer
  or as "no answer" -- never as a verdict on the address.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uHttpTransport;

type
   TUrlTestTests = class(TTestCase)
   protected
      procedure Test_AnAnswerIsWordedByItsStatus;
      procedure Test_EveryFailureKindHasASentenceAndNoVerdict;
      procedure Test_TheTransportsWordsRideInParentheses;
      procedure Test_TheRequestIsAReadOnlyGet;
      procedure Test_AStatusOtherThan200IsAnAnswerNotASuccess;
      procedure Test_ARedirectShowsTheFinalAddress;
      procedure Test_RefusalsMakeNoRequest;
      procedure Test_AnOversizedAnswerIsStillAnAnswer;
      procedure Test_TheWorkerDeliversAndSurvivesADroppedTicket;
      procedure Test_TheButtonShowsTheAnswerAndTheEditBlanksIt;
      procedure Test_TheButtonUsesTheRowsCertificateBox;
      procedure Test_ClosingTheFormWhileARequestRunsIsHarmless;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, Forms, StdCtrls, Controls,
   uHTTPDownload, uUrlTest, uUrlTestButton, uAppStrings,
   uSettingsRegistry, uSettingsDeclarations,
   uTestFakeTransport;

(* Make aFake the transport the shared layer uses, run aProc, put it back. *)
procedure WithFake(aFake: TFakeHttpTransport);
begin
   SetHttpTransportForTest(aFake);
end;

procedure ReleaseFake(aFake: TFakeHttpTransport);
begin
   SetHttpTransportForTest(nil);
   aFake.Free;
end;

(* The text, in lower case, holds none of the words a verdict would use. *)
function HasVerdictWords(const aText: string): boolean;
var
   t: string;
begin
   t := LowerCase(aText);
   Result := (Pos('invalid', t) > 0) or (Pos('fail', t) > 0) or (Pos('bad', t) > 0) or
             (Pos('wrong', t) > 0) or (Pos('error', t) > 0);
end;

procedure TUrlTestTests.Test_AnAnswerIsWordedByItsStatus;
begin
   BeginTest('an answer reads "Answered <status>", with the final address only when there is one');
   CheckEquals('Answered 200', UrlTestText(True, 200, '', hfNone, ''), '200');
   CheckEquals('Answered 404', UrlTestText(True, 404, '', hfNone, ''), '404');
   CheckEquals('Answered 301 from https://example.org/new/',
               UrlTestText(True, 301, 'https://example.org/new/', hfNone, ''),
               'a final address');
   CheckEquals('Answered 200', UrlTestText(True, 200, '', hfNone, 'ignored detail'),
               'detail has no place in an answer');
end;

procedure TUrlTestTests.Test_EveryFailureKindHasASentenceAndNoVerdict;
var
   kind: THttpFailure;
   text: string;
begin
   BeginTest('every failure kind reads "No answer" and none calls the address invalid, bad or failed');
   for kind := Low(THttpFailure) to High(THttpFailure) do
      begin
      text := UrlTestText(False, 0, '', kind, '');
      CheckTrue(Pos('No answer', text) = 1, HttpFailureName(kind) + ': ' + text);
      CheckFalse(HasVerdictWords(text), HttpFailureName(kind) + ' has a verdict word: ' + text);
      text := UrlTestText(False, 0, '', kind, 'detail text');
      CheckTrue(Pos('detail text', text) > 0, HttpFailureName(kind) + ' keeps the detail');
      end;
   CheckEquals(SUrlTestNoAnswerScheme, UrlTestText(False, 0, '', hfBadScheme, ''),
               'the scheme refusal is its sentence alone');
end;

procedure TUrlTestTests.Test_TheTransportsWordsRideInParentheses;
begin
   BeginTest('the transport''s own words follow the sentence in parentheses, on one line and bounded');
   CheckEquals('No answer: timed out connecting (host is slow)',
               UrlTestText(False, 0, '', hfConnectTimedOut, 'host is slow'), 'parenthesised');
   CheckEquals('No answer: the connection was lost (a b)',
               UrlTestText(False, 0, '', hfConnectionLost, 'a'#13#10'b'), 'one line');
   CheckEquals('No answer: Socket error 11001',
               UrlTestText(False, 0, '', hfOther, 'Socket error 11001'),
               'for "other" the words ARE the answer');
   CheckEquals('No answer', UrlTestText(False, 0, '', hfOther, ''), 'nothing to add');
   CheckTrue(Length(UrlTestText(False, 0, '', hfOther, StringOfChar('x', 1000))) < 220,
             'bounded');
end;

procedure TUrlTestTests.Test_TheRequestIsAReadOnlyGet;
var
   fake: TFakeHttpTransport;
   o:    TUrlTestOutcome;
begin
   BeginTest('the test sends one GET: no body type, no credentials, redirects followed, http allowed');
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus := 200;
   WithFake(fake);
   try
      o := RunUrlTest('http://club.example.invalid/post/');
      try
         CheckEquals('Answered 200', o.Text, 'text');
         CheckTrue(o.Answered and o.Success, 'a 200 is the success');
         CheckEquals(200, o.Status, 'status');
      finally
         o.Free;
      end;
      CheckEquals(1, fake.Calls, 'exactly one request');
      CheckEquals('GET', fake.Last.Method, 'method');
      CheckEquals('http://club.example.invalid/post/', fake.Last.URL,
                  'the text as typed, plain http allowed');
      CheckEquals('', fake.Last.Username, 'no username');
      CheckEquals('', fake.Last.Password, 'no password');
      CheckEquals('', fake.Last.BearerToken, 'no token');
      CheckEquals('', fake.Last.ContentType, 'no content type');
      CheckTrue(fake.Last.FollowRedirects, 'redirects followed');
      CheckTrue(fake.Last.AcceptAnyStatus, 'any status is an answer');
   finally
      ReleaseFake(fake);
   end;
end;

procedure TUrlTestTests.Test_AStatusOtherThan200IsAnAnswerNotASuccess;
var
   fake: TFakeHttpTransport;
   o:    TUrlTestOutcome;
begin
   BeginTest('a 404 is shown as an answer; only 200 is a success');
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus := 404;
   WithFake(fake);
   try
      o := RunUrlTest('https://club.example.invalid/x');
      try
         CheckEquals('Answered 404', o.Text, 'text');
         CheckTrue(o.Answered, 'answered');
         CheckFalse(o.Success, 'not a success');
      finally
         o.Free;
      end;
      fake.ScriptFailure      := hfConnectTimedOut;
      fake.ScriptErrorMessage := 'no route';
      fake.ScriptStatus       := 0;
      o := RunUrlTest('https://club.example.invalid/x');
      try
         CheckEquals('No answer: timed out connecting (no route)', o.Text, 'no answer text');
         CheckFalse(o.Answered, 'not answered');
         CheckFalse(o.Success, 'not a success');
      finally
         o.Free;
      end;
   finally
      ReleaseFake(fake);
   end;
end;

procedure TUrlTestTests.Test_ARedirectShowsTheFinalAddress;
var
   fake: TFakeHttpTransport;
   o:    TUrlTestOutcome;
begin
   BeginTest('a followed redirect shows the address that answered beside the status');
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus   := 200;
   fake.ScriptFinalURL := 'https://new.example.invalid/board/';
   WithFake(fake);
   try
      o := RunUrlTest('http://old.example.invalid/board');
      try
         CheckEquals('Answered 200 from https://new.example.invalid/board/', o.Text, 'text');
         CheckEquals('https://new.example.invalid/board/', o.FinalUrl, 'final');
      finally
         o.Free;
      end;
   finally
      ReleaseFake(fake);
   end;
end;

procedure TUrlTestTests.Test_RefusalsMakeNoRequest;
var
   fake: TFakeHttpTransport;
   o:    TUrlTestOutcome;
begin
   BeginTest('an empty box or a non-http address is reported without asking the transport');
   fake := TFakeHttpTransport.Create;
   WithFake(fake);
   try
      o := RunUrlTest('');
      try
         CheckEquals(SUrlTestNothing, o.Text, 'empty');
         CheckFalse(o.Answered, 'empty is not an answer');
      finally
         o.Free;
      end;
      o := RunUrlTest('ftp://club.example.invalid/');
      try
         CheckEquals(SUrlTestNoAnswerScheme, o.Text, 'other scheme');
      finally
         o.Free;
      end;
      o := RunUrlTest('club.example.invalid/post');
      try
         CheckEquals(SUrlTestNoAnswerScheme, o.Text, 'no scheme');
      finally
         o.Free;
      end;
      CheckEquals(0, fake.Calls, 'the transport was never asked');
   finally
      ReleaseFake(fake);
   end;
end;

procedure TUrlTestTests.Test_AnOversizedAnswerIsStillAnAnswer;
var
   fake: TFakeHttpTransport;
   o:    TUrlTestOutcome;
begin
   BeginTest('a page too big to keep, with a status, is an answer: the server replied');
   fake := TFakeHttpTransport.Create;
   fake.ScriptFailure := hfResponseTooLarge;
   fake.ScriptStatus  := 200;
   WithFake(fake);
   try
      o := RunUrlTest('https://club.example.invalid/big');
      try
         CheckEquals('Answered 200', o.Text, 'text');
         CheckTrue(o.Success, 'success');
      finally
         o.Free;
      end;
   finally
      ReleaseFake(fake);
   end;
end;

procedure TUrlTestTests.Test_TheWorkerDeliversAndSurvivesADroppedTicket;
var
   fake:   TFakeHttpTransport;
   ticket: IUrlTestTicket;
   i:      integer;
begin
   BeginTest('the worker fills its ticket; a ticket dropped at once is harmless');
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus := 200;
   WithFake(fake);
   try
      ticket := StartUrlTest('https://club.example.invalid/x');
      for i := 1 to 200 do
         begin
         if ticket.Finished then
            begin
            Break;
            end;
         Sleep(25);
         end;
      CheckTrue(ticket.Finished, 'finished');
      CheckTrue(ticket.Outcome <> nil, 'has an outcome');
      CheckEquals('Answered 200', ticket.Outcome.Text, 'text');

      ticket := StartUrlTest('https://club.example.invalid/y');
      ticket := nil;
      for i := 1 to 200 do
         begin
         if fake.Calls >= 2 then
            begin
            Break;
            end;
         Sleep(25);
         end;
      Sleep(150);
      CheckEquals(2, fake.Calls, 'the dropped request still ran to its end');
   finally
      ReleaseFake(fake);
   end;
end;

(* Pump the message loop until aDone or the time runs out. *)
procedure PumpUntil(aLabel: TLabel; const aText: string);
var
   i: integer;
begin
   for i := 1 to 200 do
      begin
      Application.ProcessMessages;
      if aLabel.Caption = aText then
         begin
         Break;
         end;
      Sleep(25);
      end;
end;

type
   TChainProbe = class
   public
      Fired: integer;
      procedure Changed(Sender: TObject);
   end;

procedure TChainProbe.Changed(Sender: TObject);
begin
   Inc(Fired);
end;

procedure TUrlTestTests.Test_TheButtonShowsTheAnswerAndTheEditBlanksIt;
var
   fake:   TFakeHttpTransport;
   form:   TForm;
   edit:   TEdit;
   button: TButton;
   lbl:    TLabel;
   probe:  TChainProbe;
begin
   BeginTest('the button asks the text in the box, shows the answer, and an edit blanks it and still chains');
   Application.Initialize;
   fake  := TFakeHttpTransport.Create;
   fake.ScriptStatus := 200;
   WithFake(fake);
   probe := TChainProbe.Create;
   form  := TForm.CreateNew(nil);
   try
      edit   := TEdit.Create(form);
      edit.Parent := form;
      button := TButton.Create(form);
      button.Parent := form;
      lbl    := TLabel.Create(form);
      lbl.Parent := form;
      edit.OnChange := probe.Changed;
      TUrlTester.Create(form, edit, button, lbl);

      CheckEquals('Test', string(button.Caption), 'the button reads Test');
      edit.Text := 'https://unsaved.example.invalid/typed';
      CheckEquals(1, probe.Fired, 'the edit''s own handler still runs');
      button.Click;
      CheckFalse(button.Enabled, 'disabled while asking');
      CheckTrue(button.Cursor = crAppStart, 'the background cursor on the button while asking');
      CheckTrue(lbl.Cursor = crAppStart, 'and on the result label');
      CheckTrue(form.Cursor = crDefault, 'never on the form');
      PumpUntil(lbl, 'Answered 200');
      CheckTrue(button.Cursor = crDefault, 'the normal cursor once the answer is in');
      CheckTrue(lbl.Cursor = crDefault, 'on the label too');
      CheckEquals('Answered 200', string(lbl.Caption), 'the answer is shown');
      CheckTrue(button.Enabled, 'enabled again');
      CheckEquals(1, fake.Calls, 'one request');
      CheckEquals('https://unsaved.example.invalid/typed', fake.Last.URL,
                  'the box''s text, not a saved setting');

      edit.Text := 'https://other.example.invalid/';
      CheckEquals('', string(lbl.Caption), 'an edit blanks a result that no longer describes it');
      CheckEquals(2, probe.Fired, 'and the chain still runs');
   finally
      form.Free;
      probe.Free;
      ReleaseFake(fake);
   end;
end;

procedure TUrlTestTests.Test_ClosingTheFormWhileARequestRunsIsHarmless;
var
   fake:   TFakeHttpTransport;
   form:   TForm;
   edit:   TEdit;
   button: TButton;
   lbl:    TLabel;
   i:      integer;
begin
   BeginTest('a form freed with a request in flight neither waits nor crashes');
   Application.Initialize;
   fake := TFakeHttpTransport.Create;
   fake.ScriptStatus := 200;
   WithFake(fake);
   try
      form := TForm.CreateNew(nil);
      edit := TEdit.Create(form);
      edit.Parent := form;
      button := TButton.Create(form);
      button.Parent := form;
      lbl := TLabel.Create(form);
      lbl.Parent := form;
      TUrlTester.Create(form, edit, button, lbl);
      edit.Text := 'https://club.example.invalid/x';
      button.Click;
      form.Free;
      for i := 1 to 200 do
         begin
         Application.ProcessMessages;
         if fake.Calls >= 1 then
            begin
            Break;
            end;
         Sleep(25);
         end;
      Sleep(150);
      Application.ProcessMessages;
      CheckEquals(1, fake.Calls, 'the request ran, and nothing touched the dead form');
   finally
      ReleaseFake(fake);
   end;
end;

(* THE ROW'S OWN CERTIFICATE BOX (issue 256): the button reads it at the
  moment of the click, so a test sees what the real call sees; ticking it
  blanks a result that belonged to the other choice, and the box's own handler
  still runs. *)
procedure TUrlTestTests.Test_TheButtonUsesTheRowsCertificateBox;
var
   fake:   TFakeHttpTransport;
   form:   TForm;
   edit:   TEdit;
   button: TButton;
   lbl:    TLabel;
   box:    TCheckBox;
   probe:  TChainProbe;
   setting: TSettingBase;
begin
   BeginTest('the button asks with the row''s certificate box: cleared is unverified, ticked is verified, and a toggle blanks the result');
   Application.Initialize;
   DeclareAllSettings;
   setting := FindSetting('network.verifyServerCertificates');
   if setting is TBoolSetting then
      begin
      TBoolSetting(setting).SetValue(True);
      end;
   fake  := TFakeHttpTransport.Create;
   fake.ScriptStatus := 200;
   WithFake(fake);
   probe := TChainProbe.Create;
   form  := TForm.CreateNew(nil);
   try
      edit   := TEdit.Create(form);
      edit.Parent := form;
      button := TButton.Create(form);
      button.Parent := form;
      lbl    := TLabel.Create(form);
      lbl.Parent := form;
      box    := TCheckBox.Create(form);
      box.Parent := form;
      box.Checked := True;
      box.OnChange := probe.Changed;
      TUrlTester.Create(form, edit, button, lbl, box, 'Row');
      edit.Text := 'https://self.example.invalid/post/';

      box.Checked := False;
      CheckEquals(1, probe.Fired, 'the box''s own handler still runs');
      button.Click;
      PumpUntil(lbl, 'Answered 200');
      CheckFalse(fake.Last.VerifyServer, 'cleared: the test is unverified, like the real call');

      box.Checked := True;
      CheckEquals('', string(lbl.Caption), 'a toggle blanks a result that belonged to the other choice');
      CheckEquals(2, probe.Fired, 'and the chain still runs');
      button.Click;
      PumpUntil(lbl, 'Answered 200');
      CheckTrue(fake.Last.VerifyServer, 'ticked: verified');
      CheckEquals(2, fake.Calls, 'two requests, one per click');
   finally
      form.Free;
      probe.Free;
      ReleaseFake(fake);
   end;
end;

procedure TUrlTestTests.RunAllTests;
begin
   Test_TheButtonUsesTheRowsCertificateBox;
   Test_AnAnswerIsWordedByItsStatus;
   Test_EveryFailureKindHasASentenceAndNoVerdict;
   Test_TheTransportsWordsRideInParentheses;
   Test_TheRequestIsAReadOnlyGet;
   Test_AStatusOtherThan200IsAnAnswerNotASuccess;
   Test_ARedirectShowsTheFinalAddress;
   Test_RefusalsMakeNoRequest;
   Test_AnOversizedAnswerIsStillAnAnswer;
   Test_TheWorkerDeliversAndSurvivesADroppedTicket;
   Test_TheButtonShowsTheAnswerAndTheEditBlanksIt;
   Test_ClosingTheFormWhileARequestRunsIsHarmless;
end;

end.

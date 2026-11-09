unit uTestVerifyServer;
{$I ..\..\src\tr4w.inc}
(*
  THE PER-DESTINATION "VERIFY THE SERVER'S CERTIFICATE" CHOICE (issue 256;
  docs/HTTP_TRANSPORT_DESIGN.md question 13).

  THE RULE UNDER TEST, decided in ONE place (uHTTPDownload.VerifyWanted):

        verified  =  (the global master network.verifyServerCertificates is ON)
                     AND (the destination's own choice is ON)

  so a global OFF verifies nothing (as before), and a global ON lets one
  destination opt out for itself only. Every case here runs the REAL request
  path (THttpRequest.Send / the real client) into a scripted transport, and
  asserts the VerifyServer value the TRANSPORT receives, for all four
  combinations of {global ON, OFF} x {destination ON, OFF}:

     the shared layer      a bare https request, and an http:// one (ignored)
     Club Log, WRL, Cloudlog / Wavelog    through each client's own Deliver
     HamScore              through the uploader's own PostToServer
     the score post        through the request the posting thread sends
     the Test button       through RunUrlTest

  plus: the Warn line names the destination and the URL and carries no secret;
  a definition that nothing configured still verifies; a destination's choice
  reaches its service.

  NOT covered here (a screen is needed): the check boxes themselves, the
  warning beside them, the box disabled over a plain http:// address -- see
  docs/BENCH_QUEUE.md. The delivery worker's one-line hand-over of the choice
  to the client it builds needs a database and is read, not run.
*)

interface

uses
   uTR4WTestFramework;

type
   TVerifyServerTests = class(TTestCase)
   protected
      procedure Test_TheSharedLayerMatrix;
      procedure Test_ARequestThatNamesNothingVerifies;
      procedure Test_PlainHttpNeverAsksTheBox;
      procedure Test_TheWarnNamesTheDestinationAndNoSecret;
      procedure Test_ClubLogMatrix;
      procedure Test_WRLMatrix;
      procedure Test_CloudlogMatrix;
      procedure Test_AClientNobodyConfiguredVerifies;
      procedure Test_HamScoreMatrix;
      procedure Test_ScorePostMatrix;
      procedure Test_TheUrlTestMatrix;
      procedure Test_ADefinitionsChoiceReachesItsService;
      procedure Test_ADestinationThatOptsOutDoesNotAffectAnother;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, Log4D,
   uHttpTransport, uHTTPDownload, uSettingsRegistry, uSettingsDeclarations,
   uSettingsModel, uExternalDelivery, uExternalDeliveryClient,
   uClubLogClient, uWRLClient, uCloudlogClient,
   uExternalLoggerConfig, uExternalLoggerRegistry, uExternalLoggerService,
   uClubLogExternalLogger, uWRLExternalLogger, uCloudlogExternalLogger,
   uHamScore, uGetScores, uUrlTest,
   uTestFakeTransport;

const
   SECRET = 'vs-FAKE-SECRET-0123456789abcdef';
   ADIF   = '<CALL:4>W1AW<QSO_DATE:8>20261101<TIME_ON:6>123456<BAND:3>20m<EOR>';

type
   TCaptureAppender = class(TLogCustomAppender)
   protected
      procedure DoAppend(const aMessage: string); override;
   end;

   (* The uploader with its one request made reachable: no thread, no cycle. *)
   THamScoreProbe = class(THamScoreUploader)
   public
      function PostOnce(out aBody: string): integer;
   end;

var
   GCaptured: TStringList = nil;

procedure TCaptureAppender.DoAppend(const aMessage: string);
begin
   if (GCaptured <> nil) and (Trim(aMessage) <> '') then
      begin
      GCaptured.Add(aMessage);
      end;
end;

function THamScoreProbe.PostOnce(out aBody: string): integer;
begin
   Result := PostToServer('<rtc/>', aBody);
end;

(* The global master, set for one case and put back ON by the caller. *)
procedure SetGlobal(aOn: boolean);
var
   setting: TSettingBase;
begin
   DeclareAllSettings;
   setting := FindSetting('network.verifyServerCertificates');
   if setting is TBoolSetting then
      begin
      TBoolSetting(setting).SetValue(aOn);
      end;
end;

function Scripted: TFakeHttpTransport;
begin
   Result := TFakeHttpTransport.Create;
   Result.ScriptStatus := 200;
   Result.ScriptBody   := '{"status":"created","imported_count":1}';
end;

function Expected(aGlobal, aDestination: boolean): boolean;
begin
   Result := aGlobal and aDestination;
end;

function CaseName(aGlobal, aDestination: boolean): string;
begin
   Result := 'global ';
   if aGlobal then
      begin
      Result := Result + 'ON';
      end
   else
      begin
      Result := Result + 'OFF';
      end;
   Result := Result + ', destination ';
   if aDestination then
      begin
      Result := Result + 'ON';
      end
   else
      begin
      Result := Result + 'OFF';
      end;
end;

procedure TVerifyServerTests.Test_TheSharedLayerMatrix;
var
   fake:    TFakeHttpTransport;
   request: THttpRequest;
   g, d:    boolean;
begin
   BeginTest('the shared layer: verified = global AND destination, for all four cases');
   for g in [True, False] do
      begin
      for d in [True, False] do
         begin
         SetGlobal(g);
         fake := Scripted;
         SetHttpTransportForTest(fake);
         try
            request := THttpRequest.Create('https://api.example.invalid/x');
            try
               request.VerifyServer := d;
               request.Destination  := 'Matrix';
               CheckTrue(request.Send, CaseName(g, d) + ': answered');
            finally
               request.Free;
            end;
            CheckEquals(1, fake.Calls, CaseName(g, d) + ': one request');
            CheckTrue(fake.Last.VerifyServer = Expected(g, d),
                      CaseName(g, d) + ': the transport is told verified = global AND destination');
         finally
            SetHttpTransportForTest(nil);
            fake.Free;
            SetGlobal(True);
         end;
         end;
      end;
end;

procedure TVerifyServerTests.Test_ARequestThatNamesNothingVerifies;
var
   fake:    TFakeHttpTransport;
   request: THttpRequest;
   text, reason: string;
begin
   BeginTest('a request that sets nothing verifies (the default is ON), and so do the download verbs');
   SetGlobal(True);
   fake := Scripted;
   SetHttpTransportForTest(fake);
   try
      request := THttpRequest.Create('https://api.example.invalid/x');
      try
         CheckTrue(request.VerifyServer, 'the field defaults to True');
         CheckTrue(request.Send, 'answered');
      finally
         request.Free;
      end;
      CheckTrue(fake.Last.VerifyServer, 'a bare request is verified');
      CheckTrue(HttpGetText('https://api.example.invalid/doc', text, reason), 'a GET: ' + reason);
      CheckTrue(fake.Last.VerifyServer, 'a download verb has no destination choice: verified');
      SetGlobal(False);
      CheckTrue(HttpGetText('https://api.example.invalid/doc', text, reason), 'a GET again: ' + reason);
      CheckFalse(fake.Last.VerifyServer, 'and the master still switches it off');
   finally
      SetGlobal(True);
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure TVerifyServerTests.Test_PlainHttpNeverAsksTheBox;
var
   fake:    TFakeHttpTransport;
   request: THttpRequest;
   joined:  string;
   lg:      TLogLogger;
   keep:    ILogAppender;
   oldLevel: TLogLevel;
begin
   BeginTest('on a plain http:// URL the choice is ignored: it is not read, not warned about, and the request goes as before');
   SetGlobal(True);
   GCaptured := TStringList.Create;
   lg := TLogLogger.GetLogger('TR4WDebugLog.HTTP');
   oldLevel := lg.Level;
   lg.Level := All;
   keep := TCaptureAppender.Create('unit-test verify plain capture');
   lg.AddAppender(keep);
   fake := Scripted;
   SetHttpTransportForTest(fake);
   try
      request := THttpRequest.Create('http://lan.example.invalid/x');
      try
         request.AllowInsecure := True;
         request.VerifyServer  := False;
         request.Destination   := 'PlainOne';
         CheckTrue(request.Send, 'answered');
      finally
         request.Free;
      end;
      CheckEquals(1, fake.Calls, 'the request was made');
   finally
      lg.RemoveAppender(keep);
      lg.Level := oldLevel;
      SetHttpTransportForTest(nil);
      fake.Free;
      joined := GCaptured.Text;
      FreeAndNil(GCaptured);
   end;
   CheckEquals(0, Pos('by its own setting', joined),
               'no "OFF by its own setting" line for a connection with no certificate: ' + joined);
   CheckTrue(Pos('PLAINTEXT', joined) > 0, 'the existing plaintext warning is still written: ' + joined);
end;

procedure TVerifyServerTests.Test_TheWarnNamesTheDestinationAndNoSecret;
var
   fake:    TFakeHttpTransport;
   request: THttpRequest;
   lg:      TLogLogger;
   keep:    ILogAppender;
   oldLevel: TLogLevel;
   joined:  string;
begin
   BeginTest('an opt-out writes one Warn naming the destination and the URL, never the secret; the master has its own line');
   SetGlobal(True);
   GCaptured := TStringList.Create;
   lg := TLogLogger.GetLogger('TR4WDebugLog.HTTP');
   oldLevel := lg.Level;
   lg.Level := All;
   keep := TCaptureAppender.Create('unit-test verify warn capture');
   lg.AddAppender(keep);
   fake := Scripted;
   SetHttpTransportForTest(fake);
   try
      request := THttpRequest.Create('https://cloud.example.invalid/index.php/api/qso');
      try
         request.Method      := 'POST';
         request.Password    := SECRET;
         request.Sensitive   := True;
         request.Body        := '{"key":"' + SECRET + '"}';
         request.VerifyServer := False;
         request.Destination  := 'Cloudlog shack';
         CheckTrue(request.Send, 'answered');
      finally
         request.Free;
      end;
      joined := GCaptured.Text;
      CheckTrue(Pos('OFF for Cloudlog shack by its own setting', joined) > 0,
                'the destination is named: ' + joined);
      CheckTrue(Pos('cloud.example.invalid/index.php/api/qso', joined) > 0,
                'and the URL: ' + joined);
      CheckEquals(0, Pos(SECRET, joined), 'no line carries the secret: ' + joined);

      (* A destination that did NOT opt out writes no such line. *)
      GCaptured.Clear;
      request := THttpRequest.Create('https://other.example.invalid/x');
      try
         request.Destination := 'Verified one';
         CheckTrue(request.Send, 'answered');
      finally
         request.Free;
      end;
      joined := GCaptured.Text;
      CheckEquals(0, Pos('by its own setting', joined), 'a verified destination is not warned about: ' + joined);

      (* The master's own line is unchanged. *)
      GCaptured.Clear;
      SetGlobal(False);
      request := THttpRequest.Create('https://third.example.invalid/x');
      try
         request.Destination := 'Third';
         CheckTrue(request.Send, 'answered');
      finally
         request.Free;
      end;
      joined := GCaptured.Text;
      CheckTrue(Pos('OFF by setting', joined) > 0, 'the master line: ' + joined);
      CheckEquals(0, Pos('by its own setting', joined), 'and not both: ' + joined);
   finally
      SetGlobal(True);
      lg.RemoveAppender(keep);
      lg.Level := oldLevel;
      SetHttpTransportForTest(nil);
      fake.Free;
      FreeAndNil(GCaptured);
   end;
end;

procedure TVerifyServerTests.Test_ClubLogMatrix;
var
   fake: TFakeHttpTransport;
   club: TClubLogClient;
   job:  TDeliveryJob;
   g, d: boolean;
begin
   BeginTest('Club Log: the client puts its destination choice on the request, and the layer ANDs it with the master');
   for g in [True, False] do
      begin
      for d in [True, False] do
         begin
         SetGlobal(g);
         fake := Scripted;
         SetHttpTransportForTest(fake);
         club := TClubLogClient.Create('W1AW', SECRET);
         try
            club.VerifyServer := d;
            club.Destination  := 'Club Log';
            job := Default(TDeliveryJob);
            job.Payload := ADIF;
            club.Deliver(job);
            CheckTrue(fake.Calls >= 1, CaseName(g, d) + ': a request was made');
            CheckTrue(fake.Last.VerifyServer = Expected(g, d), CaseName(g, d));
         finally
            club.Free;
            SetHttpTransportForTest(nil);
            fake.Free;
            SetGlobal(True);
         end;
         end;
      end;
end;

procedure TVerifyServerTests.Test_WRLMatrix;
var
   fake: TFakeHttpTransport;
   wrl:  TWRLClient;
   g, d: boolean;
begin
   BeginTest('WRL: the client puts its destination choice on the request, and the layer ANDs it with the master');
   for g in [True, False] do
      begin
      for d in [True, False] do
         begin
         SetGlobal(g);
         fake := Scripted;
         SetHttpTransportForTest(fake);
         wrl := TWRLClient.Create(SECRET);
         try
            wrl.VerifyServer := d;
            wrl.Destination  := 'World Radio League';
            wrl.Identity;
            CheckTrue(fake.Calls >= 1, CaseName(g, d) + ': a request was made');
            CheckTrue(fake.Last.VerifyServer = Expected(g, d), CaseName(g, d));
         finally
            wrl.Free;
            SetHttpTransportForTest(nil);
            fake.Free;
            SetGlobal(True);
         end;
         end;
      end;
end;

procedure TVerifyServerTests.Test_CloudlogMatrix;
var
   fake: TFakeHttpTransport;
   cloud: TCloudlogClient;
   job:  TDeliveryJob;
   g, d: boolean;
begin
   BeginTest('Cloudlog / Wavelog: the client puts its destination choice on the request, and the layer ANDs it with the master');
   for g in [True, False] do
      begin
      for d in [True, False] do
         begin
         SetGlobal(g);
         fake := Scripted;
         SetHttpTransportForTest(fake);
         cloud := TCloudlogClient.Create('https://log.example.invalid', '7', SECRET);
         try
            cloud.VerifyServer := d;
            cloud.Destination  := 'Cloudlog shack';
            job := Default(TDeliveryJob);
            job.Payload := ADIF;
            cloud.Deliver(job);
            CheckTrue(fake.Calls >= 1, CaseName(g, d) + ': a request was made');
            CheckTrue(fake.Last.VerifyServer = Expected(g, d), CaseName(g, d));
         finally
            cloud.Free;
            SetHttpTransportForTest(nil);
            fake.Free;
            SetGlobal(True);
         end;
         end;
      end;
end;

procedure TVerifyServerTests.Test_AClientNobodyConfiguredVerifies;
var
   fake: TFakeHttpTransport;
   club: TClubLogClient;
   wrl:  TWRLClient;
   cloud: TCloudlogClient;
   job:  TDeliveryJob;
begin
   BeginTest('a client nobody configured (a field starts at zero) verifies: the safe default is the zero one');
   SetGlobal(True);
   fake := Scripted;
   SetHttpTransportForTest(fake);
   club := TClubLogClient.Create('W1AW', SECRET);
   wrl := TWRLClient.Create(SECRET);
   cloud := TCloudlogClient.Create('https://log.example.invalid', '7', SECRET);
   try
      CheckTrue(club.VerifyServer and wrl.VerifyServer and cloud.VerifyServer,
                'the property reads True');
      job := Default(TDeliveryJob);
      job.Payload := ADIF;
      club.Deliver(job);
      CheckTrue(fake.Last.VerifyServer, 'Club Log');
      wrl.Identity;
      CheckTrue(fake.Last.VerifyServer, 'WRL');
      cloud.Deliver(job);
      CheckTrue(fake.Last.VerifyServer, 'Cloudlog');
   finally
      cloud.Free;
      wrl.Free;
      club.Free;
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure TVerifyServerTests.Test_HamScoreMatrix;
var
   fake:  TFakeHttpTransport;
   probe: THamScoreProbe;
   body:  string;
   g, d:  boolean;
begin
   BeginTest('HamScore: the uploader''s own choice reaches the request, and the layer ANDs it with the master');
   for g in [True, False] do
      begin
      for d in [True, False] do
         begin
         SetGlobal(g);
         fake := Scripted;
         SetHttpTransportForTest(fake);
         probe := THamScoreProbe.Create('https://hs.example.invalid/postxml/', 'W1AW', SECRET);
         try
            probe.VerifyServer := d;
            probe.PostOnce(body);
            CheckEquals(1, fake.Calls, CaseName(g, d) + ': one upload');
            CheckTrue(fake.Last.VerifyServer = Expected(g, d), CaseName(g, d));
            CheckEquals(SECRET, fake.Last.Password, CaseName(g, d) + ': the password still goes (to the transport only)');
         finally
            probe.Free;
            SetHttpTransportForTest(nil);
            fake.Free;
            SetGlobal(True);
         end;
         end;
      end;
   BeginTest('HamScore: an uploader nobody configured verifies');
   SetGlobal(True);
   fake := Scripted;
   SetHttpTransportForTest(fake);
   probe := THamScoreProbe.Create('https://hs.example.invalid/postxml/', 'W1AW', SECRET);
   try
      CheckTrue(probe.VerifyServer, 'the property reads True');
      probe.PostOnce(body);
      CheckTrue(fake.Last.VerifyServer, 'verified');
   finally
      probe.Free;
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure TVerifyServerTests.Test_ScorePostMatrix;
var
   fake:  TFakeHttpTransport;
   post:  THttpPost;
   saved: boolean;
   g, d:  boolean;
begin
   BeginTest('the score post: Settings.Score.VerifyServer reaches the request the posting thread sends');
   saved := Settings.Score.VerifyServer;
   try
      for g in [True, False] do
         begin
         for d in [True, False] do
            begin
            SetGlobal(g);
            Settings.Score.VerifyServer := d;
            fake := Scripted;
            SetHttpTransportForTest(fake);
            try
               post := NewScorePostRequest('https://score.example.invalid/post/');
               try
                  post.Body := 'xml=<dynamicresults/>';
                  CheckTrue(post.AllowInsecure, 'a club server on plain http stays allowed');
                  post.Send;
               finally
                  post.Free;
               end;
               CheckEquals(1, fake.Calls, CaseName(g, d) + ': one post');
               CheckTrue(fake.Last.VerifyServer = Expected(g, d), CaseName(g, d));
            finally
               SetHttpTransportForTest(nil);
               fake.Free;
               SetGlobal(True);
            end;
            end;
         end;
   finally
      Settings.Score.VerifyServer := saved;
   end;
end;

procedure TVerifyServerTests.Test_TheUrlTestMatrix;
var
   fake: TFakeHttpTransport;
   o:    TUrlTestOutcome;
   g, d: boolean;
begin
   BeginTest('the Test button: the row''s own choice reaches the request, so a test sees what the real call sees');
   for g in [True, False] do
      begin
      for d in [True, False] do
         begin
         SetGlobal(g);
         fake := Scripted;
         SetHttpTransportForTest(fake);
         try
            o := RunUrlTest('https://hs.example.invalid/postxml/', d, 'HamScore');
            try
               CheckEquals('Answered 200', o.Text, CaseName(g, d) + ': answered');
            finally
               o.Free;
            end;
            CheckTrue(fake.Last.VerifyServer = Expected(g, d), CaseName(g, d));
         finally
            SetHttpTransportForTest(nil);
            fake.Free;
            SetGlobal(True);
         end;
         end;
      end;
   BeginTest('the Test button on a row with no box of its own asks the master alone');
   SetGlobal(True);
   fake := Scripted;
   SetHttpTransportForTest(fake);
   try
      o := RunUrlTest('https://read.example.invalid/scoreboard/');
      o.Free;
      CheckTrue(fake.Last.VerifyServer, 'master ON: verified');
   finally
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure TVerifyServerTests.Test_ADefinitionsChoiceReachesItsService;
const
   (* A typed array: an untyped literal of strings takes the width of its
     first element and silently truncates the rest. *)
   PROVIDERS: array[0..2] of string = ('CLUBLOG', 'CLOUDLOG', 'WRL');
var
   d:       TExternalLoggerDefinition;
   service: TExternalLoggerService;
   id:      string;
begin
   BeginTest('a definition''s choice is copied to the service the registry builds, and a default definition verifies');
   for id in PROVIDERS do
      begin
      d := TExternalLoggerDefinition.Create;
      try
         d.ProviderId := id;
         d.Name := 'Test ' + id;
         d.Logbook := '7';
         d.URL := 'https://log.example.invalid';
         d.Account := 'acct';
         service := CreateExternalLogger(d, 'A');
         try
            CheckTrue(service.VerifyServer, id + ': a new definition verifies');
         finally
            service.Free;
         end;
         d.VerifyServer := False;
         service := CreateExternalLogger(d, 'A');
         try
            CheckFalse(service.VerifyServer, id + ': an opted-out definition builds an unverified service');
         finally
            service.Free;
         end;
      finally
         d.Free;
      end;
      end;
end;

procedure TVerifyServerTests.Test_ADestinationThatOptsOutDoesNotAffectAnother;
var
   fake: TFakeHttpTransport;
   lan, club: TCloudlogClient;
   job: TDeliveryJob;
begin
   BeginTest('global ON: the LAN destination opts out and the other stays verified, in the same session');
   SetGlobal(True);
   fake := Scripted;
   SetHttpTransportForTest(fake);
   lan  := TCloudlogClient.Create('https://shack.lan', '1', SECRET);
   club := TCloudlogClient.Create('https://log.example.invalid', '2', SECRET);
   try
      lan.VerifyServer := False;
      lan.Destination  := 'Shack Wavelog';
      job := Default(TDeliveryJob);
      job.Payload := ADIF;
      lan.Deliver(job);
      CheckFalse(fake.Last.VerifyServer, 'the LAN server is unverified');
      club.Deliver(job);
      CheckTrue(fake.Last.VerifyServer, 'the other is verified');
      lan.Deliver(job);
      CheckFalse(fake.Last.VerifyServer, 'and the LAN one stays unverified');
   finally
      club.Free;
      lan.Free;
      SetHttpTransportForTest(nil);
      fake.Free;
   end;
end;

procedure TVerifyServerTests.RunAllTests;
begin
   Test_TheSharedLayerMatrix;
   Test_ARequestThatNamesNothingVerifies;
   Test_PlainHttpNeverAsksTheBox;
   Test_TheWarnNamesTheDestinationAndNoSecret;
   Test_ClubLogMatrix;
   Test_WRLMatrix;
   Test_CloudlogMatrix;
   Test_AClientNobodyConfiguredVerifies;
   Test_HamScoreMatrix;
   Test_ScorePostMatrix;
   Test_TheUrlTestMatrix;
   Test_ADefinitionsChoiceReachesItsService;
   Test_ADestinationThatOptsOutDoesNotAffectAnother;
end;

end.

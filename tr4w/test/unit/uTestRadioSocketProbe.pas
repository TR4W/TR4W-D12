unit uTestRadioSocketProbe;
{$I ..\..\src\tr4w.inc}

(*
  PINS TFactoryRadioBase.SocketIsConnected: the connected-probe must ANSWER,
  never RAISE.

  WHY THIS EXISTS.  NY4I quit TR4W 5.0.15 on Linux Mint with his Elecraft K4
  switched off -- so the network radio never connected -- and got the LCL's
  unhandled-exception modal:

      Socket Error # 107 / Socket is not connected.

  raised out of ExitProgram.  The backtrace named uFactoryRadioBase.pas:1821,
  which was `if socket.Connected then` at the top of Disconnect: THE GUARD
  WRITTEN TO AVOID THE ERROR WAS THE THING RAISING IT.

  Indy's Connected is not a flag read.  TIdIOHandlerStack.Connected
  (include/Core/IdIOHandlerStack.pas:241) probes the socket and swallows only
  Id_WSAESHUTDOWN / Id_WSAECONNABORTED / Id_WSAECONNRESET, re-raising the
  rest.  Id_WSAENOTCONN is not on that list, and on Unix it is the C ENOTCONN
  -- errno 107 on Linux.

  WHAT IS AND IS NOT COVERED HERE.  These tests build radio objects and touch
  no network, so they run in CI on every platform.  They cover the probe
  itself: a socket that never connected, a nil socket, and a probe that
  raises.  They do NOT cover the bench case -- a real socket, a real shutdown,
  and the LCL exception dialog.  That needs a running program with a radio
  configured to an unreachable address, and there is no unit test for it.
*)

interface

uses
   SysUtils,
   IdTCPClient,
   IdStack,
   uTR4WTestFramework,
   uFactoryRadioBase;

type
   (* A socket whose connected-probe ALWAYS raises, so the except arm can be
     proven on every platform rather than only on the one where the real
     socket happens to misbehave.  TIdTCPConnection.Connected is virtual --
     see include/Core/IdTCPConnection.pas:397. *)
   TRaisingTCPClient = class(TIdTCPClient)
   public
      function Connected: Boolean; override;
   end;

   (* SocketIsConnected is protected -- producing the answer is the driver's
     business.  A descendant is how a test reaches it, and it is also how the
     socket field is swapped for the raising one. *)
   TProbeRadio = class(TFactoryRadioBase)
   public
      function  CallSocketIsConnected: boolean;
      procedure DropSocket;
      procedure InstallRaisingSocket;
   end;

   TRadioSocketProbeTests = class(TTestCase)
   protected
      procedure HandleMessage(sMessage: string);
      function  MakeRadio: TProbeRadio;
      function  ProbeWithoutEscaping(radio: TProbeRadio; out escaped: string): boolean;

      procedure Test_NeverConnectedAnswersFalse;
      procedure Test_NilSocketAnswersFalse;
      procedure Test_RaisingProbeAnswersFalse;
   public
      procedure RunAllTests; override;
   end;

implementation

function TRaisingTCPClient.Connected: Boolean;
begin
   (* 107 and this text are the bytes NY4I actually saw. *)
   Result := False;   // never reached; silences the "result not set" warning
   raise EIdSocketError.CreateError(107, 'Socket Error # 107 - Socket is not connected.');
end;

function TProbeRadio.CallSocketIsConnected: boolean;
begin
   Result := SocketIsConnected;
end;

procedure TProbeRadio.DropSocket;
begin
   FreeAndNil(socket);
end;

procedure TProbeRadio.InstallRaisingSocket;
begin
   FreeAndNil(socket);
   socket := TRaisingTCPClient.Create(nil);
end;

procedure TRadioSocketProbeTests.HandleMessage(sMessage: string);
begin
   (* Nothing arrives: no transport is ever opened. *)
end;

function TRadioSocketProbeTests.MakeRadio: TProbeRadio;
var
   handler: TProcessMsgRef;
begin
   (* A TYPED LOCAL AND NO @.  In Delphi mode a method is assigned to a
     method-pointer variable by NAME; `@Self.HandleMessage` is the FPC-mode
     spelling and here yields an untyped pointer, which the compiler rejects
     with "Variable identifier expected" -- an error that names neither the
     method nor the mode. *)
   handler := HandleMessage;
   (* THE BASE CONSTRUCTOR, not a bare `inherited Create`.  It is what builds
     the socket, the VFOs and the logger; skipping it resolves to
     TObject.Create and leaves a radio that looks built and is not.  See the
     note above BaseConstructorRan in uFactoryRadioBase. *)
   Result := TProbeRadio.Create(handler);
end;

(* CATCHES, so a regression FAILS A TEST rather than killing the binary.  The
  framework's runner has no exception guard, and "the whole run died" says
  much less than "this assertion failed and here is what escaped". *)
function TRadioSocketProbeTests.ProbeWithoutEscaping(radio: TProbeRadio;
                                                     out escaped: string): boolean;
begin
   escaped := '';
   Result := False;
   try
      Result := radio.CallSocketIsConnected;
   except
      on E: Exception do
         begin
         escaped := E.ClassName + ': ' + E.Message;
         end;
   end;
end;

procedure TRadioSocketProbeTests.Test_NeverConnectedAnswersFalse;
var
   radio   : TProbeRadio;
   answer  : boolean;
   escaped : string;
begin
   BeginTest('SocketIsConnected: a socket that never connected answers False');
   radio := MakeRadio;
   try
      CheckTrue(radio.BaseConstructorRan,
                'the base constructor must have run, or there is no socket to probe');
      (* THE BENCH CASE, minus the bench: a radio built and never connected.
        This must answer, not raise -- on Windows, Linux and macOS alike. *)
      answer := ProbeWithoutEscaping(radio, escaped);
      CheckEquals('', escaped, 'the probe must not raise');
      CheckFalse(answer, 'a socket that never connected must probe as NOT connected');
   finally
      radio.Free;
   end;
end;

procedure TRadioSocketProbeTests.Test_NilSocketAnswersFalse;
var
   radio   : TProbeRadio;
   answer  : boolean;
   escaped : string;
begin
   BeginTest('SocketIsConnected: a nil socket answers False');
   radio := MakeRadio;
   try
      radio.DropSocket;
      answer := ProbeWithoutEscaping(radio, escaped);
      CheckEquals('', escaped, 'a nil socket must not be dereferenced');
      CheckFalse(answer, 'a nil socket must probe as NOT connected');
   finally
      radio.Free;
   end;
end;

procedure TRadioSocketProbeTests.Test_RaisingProbeAnswersFalse;
var
   radio   : TProbeRadio;
   answer  : boolean;
   escaped : string;
begin
   BeginTest('SocketIsConnected: a probe that raises answers False');
   radio := MakeRadio;
   try
      radio.InstallRaisingSocket;
      (* If the except arm is ever narrowed to one exception class, or removed
        because "Connected cannot raise", this is where it is caught -- here,
        and not on an operator's bench at the end of a contest. *)
      answer := ProbeWithoutEscaping(radio, escaped);
      CheckEquals('', escaped, 'a raising probe must be handled, not propagated');
      CheckFalse(answer, 'a raising probe must be reported as NOT connected');
   finally
      radio.Free;
   end;
end;

procedure TRadioSocketProbeTests.RunAllTests;
begin
   Test_NeverConnectedAnswersFalse;
   Test_NilSocketAnswersFalse;
   Test_RaisingProbeAnswersFalse;
end;

end.

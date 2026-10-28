(* uHostResolve -- ONE RESOLVER FOR EVERY HOST NAME HANDED TO INDY (issue 148).

  What this reaches on any machine: the literal rule, the empty name, the logic
  around a lookup (driven by a stub, so a failure is exercised without a DNS
  server and cannot be made flaky by the CI runner's network), and the
  platform's own answer.

  WHAT DIFFERS BY PLATFORM IS ASSERTED PER PLATFORM, on purpose:

    Windows   the name comes back exactly as given and nothing is looked up --
              'localhost' stays 'localhost', and so does a name that would not
              resolve.  This is the "Windows is unchanged" rule, pinned.
    Unix      'localhost' comes back as 127.0.0.1 through the C library, and a
              name under .invalid (RFC 6761: guaranteed never to exist) fails
              with a message that names it.

  The Unix arm is exercised for real by the Linux and macOS unit runs; on
  Windows those two checks are the passthrough ones.  What neither can show is
  mDNS itself: that needs avahi and a .local host (BENCH_QUEUE). *)
unit uTestHostResolve;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   THostResolveTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_LiteralsAreRecognised;
      procedure Test_NamesAreNotLiterals;
      procedure Test_EmptyAndLiteralPassThroughWithoutALookup;
      procedure Test_ALookupAnswerIsReturnedAndTheNameIsTrimmed;
      procedure Test_AFailedLookupNamesTheHost;
      procedure Test_ResolveForConnectRaisesNamingTheHost;
      procedure Test_LocalhostPerPlatform;
      procedure Test_AnUnresolvableNamePerPlatform;
      procedure Test_AUdpDestinationThatWillNotResolveDoesNotStopTheNext;
   end;

implementation

uses
   SysUtils, uHostResolve, uUDPBroadcastConfig, uUDPBroadcaster;

var
   GLookups:    Integer;
   GLastAsked:  string;
   GStubAnswer: string;   (* '' = fail *)

(* The stub: counts calls, remembers what it was asked, answers GStubAnswer. *)
function StubLookup(const aName: string; out aIPv4: string;
                    out aWhy: string): Boolean;
begin
   Inc(GLookups);
   GLastAsked := aName;
   aIPv4 := GStubAnswer;
   aWhy  := '';
   Result := GStubAnswer <> '';
   if not Result then
      begin
      aWhy := 'the stub has no such name';
      end;
end;

procedure ResetStub(const aAnswer: string);
begin
   GLookups    := 0;
   GLastAsked  := '';
   GStubAnswer := aAnswer;
end;

procedure THostResolveTests.Test_LiteralsAreRecognised;
begin
   CheckTrue(HostIsAddressLiteral('127.0.0.1'),       '127.0.0.1');
   CheckTrue(HostIsAddressLiteral('0.0.0.0'),         '0.0.0.0');
   CheckTrue(HostIsAddressLiteral('255.255.255.255'), '255.255.255.255');
   CheckTrue(HostIsAddressLiteral('192.168.1.20'),    '192.168.1.20');
   CheckTrue(HostIsAddressLiteral('::1'),             'IPv6 loopback');
   CheckTrue(HostIsAddressLiteral('fe80::1'),         'IPv6 link-local');
   CheckTrue(HostIsAddressLiteral('2001:db8::ff00:42:8329'), 'IPv6');
   CheckTrue(HostIsAddressLiteral('::ffff:10.0.0.1'), 'IPv6 with an IPv4 tail');
end;

procedure THostResolveTests.Test_NamesAreNotLiterals;
begin
   CheckFalse(HostIsAddressLiteral(''),               'empty is not a literal');
   CheckFalse(HostIsAddressLiteral('localhost'),      'localhost');
   CheckFalse(HostIsAddressLiteral('pi400.local'),    'pi400.local');
   CheckFalse(HostIsAddressLiteral('1.2.3'),          'three parts');
   CheckFalse(HostIsAddressLiteral('1.2.3.4.5'),      'five parts');
   CheckFalse(HostIsAddressLiteral('256.1.1.1'),      'a part over 255');
   CheckFalse(HostIsAddressLiteral('1.2.3.'),         'a trailing dot');
   CheckFalse(HostIsAddressLiteral('.1.2.3'),         'a leading dot');
   CheckFalse(HostIsAddressLiteral('1..2.3'),         'an empty part');
   CheckFalse(HostIsAddressLiteral('10.0.0.1.example.com'), 'a name that begins like an address');
   CheckFalse(HostIsAddressLiteral('1234.1.1.1'),     'four digits in a part');
end;

procedure THostResolveTests.Test_EmptyAndLiteralPassThroughWithoutALookup;
var
   addr, why: string;
begin
   ResetStub('9.9.9.9');

   CheckTrue(ResolveHostWith('', StubLookup, addr, why), 'empty is passed through');
   CheckEquals('', addr, 'empty stays empty (the caller has its own empty check)');

   CheckTrue(ResolveHostWith('10.1.2.3', StubLookup, addr, why), 'an IPv4 literal');
   CheckEquals('10.1.2.3', addr, 'untouched');

   CheckTrue(ResolveHostWith('::1', StubLookup, addr, why), 'an IPv6 literal');
   CheckEquals('::1', addr, 'untouched');

   CheckEquals(0, GLookups, 'none of those reached a lookup');
end;

procedure THostResolveTests.Test_ALookupAnswerIsReturnedAndTheNameIsTrimmed;
var
   addr, why: string;
begin
   ResetStub('192.168.7.9');
   CheckTrue(ResolveHostWith('  pi400.local ', StubLookup, addr, why), 'a name resolves');
   CheckEquals('192.168.7.9', addr, 'the lookup''s address');
   CheckEquals('pi400.local', GLastAsked, 'the lookup was asked for the trimmed name');
   CheckEquals(1, GLookups, 'exactly one lookup');
   CheckEquals('', why, 'no reason on success');
end;

procedure THostResolveTests.Test_AFailedLookupNamesTheHost;
var
   addr, why: string;
begin
   ResetStub('');
   CheckFalse(ResolveHostWith('nope.local', StubLookup, addr, why), 'the lookup failed');
   CheckEquals('nope.local', addr, 'the name is handed back unchanged');
   CheckTrue(Pos('could not resolve ''nope.local''', why) = 1,
             'the reason begins by naming the host: ' + why);
   CheckTrue(Pos('the stub has no such name', why) > 0,
             'and carries the lookup''s own reason: ' + why);
end;

procedure THostResolveTests.Test_ResolveForConnectRaisesNamingTheHost;
var
   raised: Boolean;
   msg:    string;
begin
   (* The platform arm. On Windows nothing can fail, so the raise is pinned only
     where it can happen. *)
{$IFDEF UNIX}
   raised := False;
   msg    := '';
   try
      ResolveHostForConnect('no-such-host.invalid');
   except
      on E: EHostResolveError do
         begin
         raised := True;
         msg    := E.Message;
         end;
   end;
   CheckTrue(raised, 'an unresolvable name raises EHostResolveError');
   CheckTrue(Pos('no-such-host.invalid', msg) > 0, 'and the message names it: ' + msg);
{$ELSE}
   raised := False;
   try
      msg := ResolveHostForConnect('no-such-host.invalid');
   except
      on EHostResolveError do
         begin
         raised := True;
         end;
   end;
   CheckFalse(raised, 'Windows never raises');
   CheckEquals('no-such-host.invalid', msg, 'Windows returns the name as given');
{$ENDIF}
end;

procedure THostResolveTests.Test_LocalhostPerPlatform;
var
   addr, why: string;
begin
   CheckTrue(TryResolveHost('localhost', addr, why), 'localhost: ' + why);
{$IFDEF UNIX}
   CheckEquals('127.0.0.1', addr, 'through the C library, IPv4 first');
{$ELSE}
   CheckEquals('localhost', addr, 'Windows: the name is left for Winsock, unchanged');
{$ENDIF}

   CheckTrue(TryResolveHost('127.0.0.1', addr, why), 'a literal');
   CheckEquals('127.0.0.1', addr, 'a literal is never touched, on any platform');
   CheckTrue(TryResolveHost('', addr, why), 'empty');
   CheckEquals('', addr, 'empty is never touched');
end;

procedure THostResolveTests.Test_AnUnresolvableNamePerPlatform;
var
   addr, why: string;
   ok:    Boolean;
begin
   (* A name under .invalid cannot exist (RFC 6761), so no network can answer it. *)
   ok := TryResolveHost('no-such-host.invalid', addr, why);
{$IFDEF UNIX}
   CheckFalse(ok, 'the C library has no such name');
   CheckTrue(Pos('could not resolve ''no-such-host.invalid''', why) = 1,
             'the reason names the host: ' + why);
{$ELSE}
   CheckTrue(ok, 'Windows does not resolve here; Winsock does, at connect time');
   CheckEquals('no-such-host.invalid', addr, 'unchanged');
{$ENDIF}
end;

var
   GSent:     Integer;
   GSentTo:   string;

(* A transport shaped like LogCfg.SendUDPPayload: resolve first, raise if the
  name will not resolve, otherwise record where the datagram would go. *)
procedure ResolvingTransport(const aAddress: string; const aPort: Integer;
                             const aPayload: AnsiString);
var
   addr, why: string;
begin
   if not ResolveHostWith(aAddress, StubLookup, addr, why) then
      begin
      raise EHostResolveError.Create(why);
      end;
   Inc(GSent);
   GSentTo := addr;
end;

procedure THostResolveTests.Test_AUdpDestinationThatWillNotResolveDoesNotStopTheNext;
var
   b: TUDPBroadcaster;
   c: TUDPBroadcastConfig;
begin
   ResetStub('');   (* every NAME fails; a literal never reaches the lookup *)
   GSent   := 0;
   GSentTo := '';
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      b.SetTransport(ResolvingTransport);
      c.AddDestination('dead.local', 1001, [usContact]);
      c.AddDestination('10.0.0.5', 1002, [usContact]);
      b.Configure(c);

      b.SendNow(usContact, 'x');   (* must not raise *)
      CheckEquals(1, GSent, 'the literal destination was still sent to');
      CheckEquals('10.0.0.5', GSentTo, 'and it went out unchanged');
      CheckEquals(1, b.FailedSendCount, 'the unresolvable one is counted as a failed send');
      CheckEquals(1, GLookups, 'only the name reached the lookup');
   finally
      c.Free;
      b.Free;
   end;
end;

procedure THostResolveTests.RunAllTests;
begin
   Test_AUdpDestinationThatWillNotResolveDoesNotStopTheNext;
   Test_LiteralsAreRecognised;
   Test_NamesAreNotLiterals;
   Test_EmptyAndLiteralPassThroughWithoutALookup;
   Test_ALookupAnswerIsReturnedAndTheNameIsTrimmed;
   Test_AFailedLookupNamesTheHost;
   Test_ResolveForConnectRaisesNamingTheHost;
   Test_LocalhostPerPlatform;
   Test_AnUnresolvableNamePerPlatform;
end;

end.

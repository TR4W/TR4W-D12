unit uTestDXClusterClient;
{$I ..\..\src\tr4w.inc}

{
  Pins TDXClusterClient against a REAL socket -- an in-process TIdTCPServer on
  loopback, scripted to send exactly what we want, when we want.

  WHY A FIXTURE SERVER RATHER THAN mockDXCluster.  The simulator at
  c:\projects\test-tools\mockDXCluster is the right tool for driving TR4W by
  hand, but it generates RANDOM callsigns and frequencies, so a test can only
  assert "something arrived".  This serves a KNOWN table (CLUSTER_FIXTURE) and
  asserts the exact lines.  The AK1A line format is copied from that
  simulator's _random_spot(); the simulator itself is not modified and not
  required to run these tests.

  THE TEST THAT MATTERS is Test_LineSplitAcrossSegments.  Before 99ef30fb the
  reader posted whatever ONE recv() returned and the parser restarted its line
  scan per chunk with no carry-over, so a DX line split across two TCP segments
  was cut in half and BOTH halves discarded -- neither fragment matches
  "DX de " -- losing the spot silently.  That test writes a spot line in two
  deliberate sends with a gap between them, and requires it to arrive WHOLE.
  Run it against the pre-99ef30fb reader and it fails.

  WHAT THIS DOES NOT COVER: the spot DECODER.  ProcessDX still lives in
  uTelnet, which pulls in MainUnit, the bandmap and the window layer, so it
  cannot be linked into this EXE.  bce1262e made it take a line rather than a
  global, which is the precondition for testing it; extracting it far enough to
  link here is the next step.  These tests prove the transport delivers exactly
  the bytes the decoder will one day be handed.
}

interface

uses
   SysUtils, Classes, SyncObjs, IdTCPServer, IdContext, IdGlobal,
   uTR4WTestFramework, uDXClusterClient;

type
   TDXClusterClientTests = class(TTestCase)
   private
      FServer:    TIdTCPServer;
      FScript:    TStringList;    // lines the server sends, in order
      FSplitLine: string;         // if set, sent in two halves with a gap
      FLock:      TCriticalSection;
      FReceived:  TStringList;    // lines the client handed us (reader thread)
      FPort:      Word;
      procedure ServerExecute(AContext: TIdContext);
      procedure OnClusterLine(const Line: AnsiString);
      function  StartServer: Word;
      procedure StopServer;
      function  WaitForLines(Count: Integer; TimeoutMs: Integer): Boolean;
      function  ReceivedCount: Integer;
      function  ReceivedLine(Index: Integer): string;
   protected
      procedure Test_KnownSpotsArriveIntact;
      procedure Test_LineSplitAcrossSegments;
      procedure Test_ManySpotsKeepOrderAndCount;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   TSpotFixture = record
      spotter: string;
      freq:    string;
      spotted: string;
   end;

const
   // Known calls and frequencies -- the point of a fixture rather than a
   // random generator.  Deliberately mixed frequency widths (7031.5 vs
   // 14065.00), because that is the difference the decoder's decimal-point
   // offset detection keys on.
   CLUSTER_FIXTURE: array[0..3] of TSpotFixture = (
      (spotter: 'W3OA';   freq: '7031.5';   spotted: 'W8KJP'),
      (spotter: 'NN5ABC'; freq: '14065.00'; spotted: 'SM8NIO'),
      (spotter: 'K4XYZ';  freq: '21025.0';  spotted: 'NY4I'),
      (spotter: 'DL1ABC'; freq: '3520.10';  spotted: 'JA1XYZ')
   );

   // From mockDXCluster.py _random_spot():
   //   f"DX de {spotter + ':':<10} {frequency:>7}  {spotted:<12} {comment:<30} {stamp}"
   // Reference (74 columns):
   //   DX de W3OA-#:     7031.5  W8KJP        CW 12 dB 22 WPM CQ           ? 1945Z
   COMMENT = 'CW 12 dB 22 WPM CQ';
   STAMP   = '1945Z';

function PadRight(const S: string; W: Integer): string;
begin
   Result := S;
   while Length(Result) < W do
      begin
      Result := Result + ' ';
      end;
end;

function PadLeft(const S: string; W: Integer): string;
begin
   Result := S;
   while Length(Result) < W do
      begin
      Result := ' ' + Result;
      end;
end;

// One AK1A spot line, same field widths as the simulator.
function SpotLine(const F: TSpotFixture): string;
begin
   Result := 'DX de ' + PadRight(F.spotter + '-#:', 10) + ' ' +
             PadLeft(F.freq, 7) + '  ' + PadRight(F.spotted, 12) + ' ' +
             PadRight(COMMENT, 30) + ' ' + STAMP;
end;

{ ---- fixture server ------------------------------------------------------ }

procedure TDXClusterClientTests.ServerExecute(AContext: TIdContext);
var
   i: Integer;
   half: Integer;
begin
   // Everything is written once, on the first pass, then the connection is
   // simply held open so the client sees no close mid-test.
   for i := 0 to FScript.Count - 1 do
      begin
      AContext.Connection.IOHandler.Write(FScript[i] + #13#10,
                                          IndyTextEncoding_8Bit);
      end;

   if FSplitLine <> '' then
      begin
      // THE POINT OF THIS FIXTURE: put the line boundary in the middle of a
      // spot.  Two writes with a gap between them so the stack cannot coalesce
      // them into one segment -- the client must reassemble.  Note the CRLF
      // goes with the SECOND half, so the first write ends mid-field.
      half := Length(FSplitLine) div 2;
      AContext.Connection.IOHandler.Write(Copy(FSplitLine, 1, half),
                                          IndyTextEncoding_8Bit);
      Sleep(150);
      AContext.Connection.IOHandler.Write(
         Copy(FSplitLine, half + 1, MaxInt) + #13#10, IndyTextEncoding_8Bit);
      end;

   // Hold the connection open; the test closes from its side.
   while AContext.Connection.Connected do
      begin
      Sleep(50);
      end;
end;

function TDXClusterClientTests.StartServer: Word;
begin
   FServer := TIdTCPServer.Create(nil);
   FServer.OnExecute := ServerExecute;
   with FServer.Bindings.Add do
      begin
      IP := '127.0.0.1';
      Port := 0;          // ephemeral: never collides with a real service
      end;
   FServer.Active := True;
   Result := FServer.Bindings[0].Port;
end;

procedure TDXClusterClientTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

{ ---- client callback (READER THREAD) ------------------------------------- }

procedure TDXClusterClientTests.OnClusterLine(const Line: AnsiString);
begin
   FLock.Enter;
   try
      FReceived.Add(string(Line));
   finally
      FLock.Leave;
   end;
end;

function TDXClusterClientTests.ReceivedCount: Integer;
begin
   FLock.Enter;
   try
      Result := FReceived.Count;
   finally
      FLock.Leave;
   end;
end;

function TDXClusterClientTests.ReceivedLine(Index: Integer): string;
begin
   FLock.Enter;
   try
      if (Index >= 0) and (Index < FReceived.Count) then
         begin
         Result := FReceived[Index];
         end
      else
         begin
         Result := '';
         end;
   finally
      FLock.Leave;
   end;
end;

// Poll rather than sleep a fixed time: a slow machine must not fail the test,
// and a fast one must not pay for the worst case.
function TDXClusterClientTests.WaitForLines(Count, TimeoutMs: Integer): Boolean;
var
   waited: Integer;
begin
   waited := 0;
   while (ReceivedCount < Count) and (waited < TimeoutMs) do
      begin
      Sleep(20);
      Inc(waited, 20);
      end;
   Result := ReceivedCount >= Count;
end;

{ ---- tests --------------------------------------------------------------- }

procedure TDXClusterClientTests.Test_KnownSpotsArriveIntact;
var
   client: TDXClusterClient;
   i: Integer;
begin
   BeginTest('every fixture spot line arrives byte-identical');

   FScript.Clear;
   FSplitLine := '';
   for i := Low(CLUSTER_FIXTURE) to High(CLUSTER_FIXTURE) do
      begin
      FScript.Add(SpotLine(CLUSTER_FIXTURE[i]));
      end;

   FReceived.Clear;
   FPort := StartServer;
   client := TDXClusterClient.Create;
   try
      client.OnLine := OnClusterLine;
      CheckTrue(client.Connect('127.0.0.1', FPort), 'client connects to fixture');
      CheckTrue(WaitForLines(FScript.Count, 5000), 'all fixture lines arrive');

      for i := 0 to FScript.Count - 1 do
         begin
         CheckEquals(FScript[i], ReceivedLine(i),
                     'line ' + IntToStr(i) + ' identical, CRLF stripped');
         end;

      // The known values are IN those lines -- assert on the data, not just on
      // "a line turned up", which is what a random generator would limit us to.
      CheckTrue(Pos('NY4I', ReceivedLine(2)) > 0, 'known spotted call present');
      CheckTrue(Pos('21025.0', ReceivedLine(2)) > 0, 'known frequency present');
   finally
      client.Free;
      StopServer;
   end;
end;

procedure TDXClusterClientTests.Test_LineSplitAcrossSegments;
var
   client: TDXClusterClient;
   expected: string;
begin
   // THE REGRESSION PIN.  The old chunk reader dropped this line entirely:
   // each half was scanned on its own and neither matches "DX de ".
   BeginTest('a spot split across two TCP segments arrives as ONE whole line');

   expected := SpotLine(CLUSTER_FIXTURE[1]);   // 14065.00 SM8NIO
   FScript.Clear;
   FSplitLine := expected;

   FReceived.Clear;
   FPort := StartServer;
   client := TDXClusterClient.Create;
   try
      client.OnLine := OnClusterLine;
      CheckTrue(client.Connect('127.0.0.1', FPort), 'client connects to fixture');

      // PROOF THAT THE SPLIT IS REAL.  The fixture writes the first half, waits
      // 150 ms, then writes the rest.  Look during that gap: the first half is
      // already on the client's socket, and if it produced a line then the two
      // writes coalesced and this test would be passing for the wrong reason.
      // Zero lines here means the reader genuinely held an incomplete line and
      // reassembled it -- which is precisely what the old chunk reader could
      // not do.
      Sleep(80);
      CheckEquals(0, ReceivedCount,
                  'half a line must NOT be emitted -- if it is, the reader is '
                  + 'still posting raw chunks');

      CheckTrue(WaitForLines(1, 5000), 'the split line arrives');
      CheckEquals(1, ReceivedCount, 'ONE line, not two fragments');
      CheckEquals(expected, ReceivedLine(0), 'reassembled byte-identical');
      CheckTrue(Pos('DX de ', ReceivedLine(0)) = 1,
                'still parses as a spot -- the half-line never did');
      CheckTrue(Pos('SM8NIO', ReceivedLine(0)) > 0,
                'the spotted call survived the boundary');
   finally
      client.Free;
      StopServer;
   end;
end;

procedure TDXClusterClientTests.Test_ManySpotsKeepOrderAndCount;
var
   client: TDXClusterClient;
   i: Integer;
   n: Integer;
begin
   // A burst big enough to cross the receive buffer several times, which is
   // where boundary bugs live.  Order is part of the contract: the bandmap
   // shows spots in arrival order.
   BeginTest('a 200-spot burst arrives complete and in order');

   n := 200;
   FScript.Clear;
   FSplitLine := '';
   for i := 0 to n - 1 do
      begin
      FScript.Add(SpotLine(CLUSTER_FIXTURE[i mod Length(CLUSTER_FIXTURE)]) +
                  ' #' + IntToStr(i));
      end;

   FReceived.Clear;
   FPort := StartServer;
   client := TDXClusterClient.Create;
   try
      client.OnLine := OnClusterLine;
      CheckTrue(client.Connect('127.0.0.1', FPort), 'client connects to fixture');
      CheckTrue(WaitForLines(n, 15000), 'all 200 lines arrive');
      CheckEquals(n, ReceivedCount, 'no line lost, none duplicated');

      for i := 0 to n - 1 do
         begin
         if ReceivedLine(i) <> FScript[i] then
            begin
            CheckEquals(FScript[i], ReceivedLine(i),
                        'line ' + IntToStr(i) + ' out of order or corrupt');
            Break;   // one failure is the story; 200 would drown it
            end;
         end;
      CheckTrue(True, 'burst delivered in order');
   finally
      client.Free;
      StopServer;
   end;
end;

procedure TDXClusterClientTests.RunAllTests;
begin
   FLock := TCriticalSection.Create;
   FScript := TStringList.Create;
   FReceived := TStringList.Create;
   try
      Test_KnownSpotsArriveIntact;
      Test_LineSplitAcrossSegments;
      Test_ManySpotsKeepOrderAndCount;
   finally
      StopServer;
      FReceived.Free;
      FScript.Free;
      FLock.Free;
   end;
end;

end.

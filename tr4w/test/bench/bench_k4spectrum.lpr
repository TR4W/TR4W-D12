program bench_k4spectrum;

{
  END-TO-END bench: TK4Radio's spectrum stream against a real Elecraft K4.

  ---------------------------------------------------------------------------
  WHY THIS EXISTS SEPARATELY FROM THE UNIT TESTS
  ---------------------------------------------------------------------------
  test/unit covers the decoder completely and with no radio present: framing,
  CRC, resync, chunk boundaries, the capability seam and the start/stop
  lifecycle (uTestK4Spectrum, driven from a frozen capture).  What it cannot
  cover is the layer below that:

    - the Indy socket actually reaching the K4 on CAT port + 1
    - bytes coming off that socket in whatever chunk sizes the network gives,
      and the framer assembling frames from them IN THE REAL PROGRAM rather
      than from a file
    - the thread publishing through TK4Radio into a subscriber
    - the stream surviving minutes rather than the length of a capture

  Those are exactly the places the equivalent code in TR4QT went wrong: its
  reader runs on the GUI thread despite its own header saying it should not,
  and its buffer class is constructed and never used.  Neither is visible in a
  decoder test.

  ---------------------------------------------------------------------------
  WHAT A GREEN RUN PROVES -- and what it does not
  ---------------------------------------------------------------------------
  It proves TR4W can open the K4's panadapter port, stay synchronised with a
  live radio, and deliver decoded frames to a subscriber.  Unlike the serial
  bench there is no simulator here: the far end is the actual radio, so
  agreement is evidence about the RADIO and not merely self-consistency.

  It does NOT prove anything about rendering, and it deliberately does not open
  the CAT link at all -- StartSpectrum needs only an address and a port, so
  this leaves the radio's CAT state exactly as it found it.

  ---------------------------------------------------------------------------
  USAGE
  ---------------------------------------------------------------------------
     bench_k4spectrum <host> [cat-port] [seconds]
     bench_k4spectrum 192.168.73.108 9200 20

  With no host it SKIPS cleanly (exit 0), so it is safe to invoke from a script
  on a machine with no radio.  Exit 1 means it ran and something was wrong.
}

{$APPTYPE CONSOLE}

uses
   // Interfaces FIRST, exactly as tr4w_unit_tests.lpr does.  Linking MainUnit
   // drags in the LCL, whose widgetset registration lives here; without it the
   // link fails on ~50 undefined WSRegister* symbols.  Nothing in this program
   // opens a window -- this is a link-time requirement, not a UI one.
   Interfaces,
   SysUtils, SyncObjs, Log4D, MainUnit, VC,
   uSpectrumTypes, uFactoryRadioBase, uRadioElecraftK4;

const
   MAX_SOURCES = 8;
   DEFAULT_CAT_PORT = 9200;
   DEFAULT_SECONDS = 20;

type
   TSourceTally = record
      Id: string;
      Count: Integer;
      CentreHz: Int64;
      SpanHz: Int64;
      NoiseFloorDb: Single;
      MinDb: Single;
      MaxDb: Single;
   end;

   { Subscriber.  Its whole job is to be a correct one, so it doubles as the
     worked example: the callback arrives ON THE SPECTRUM THREAD, so every
     touch of shared state is inside the lock, and NOTHING keeps a reference to
     AFrame.Bins beyond the call -- the scalars are copied out and the array is
     summarised on the spot, exactly as TSpectrumFrameProc requires. }
   TFrameCollector = class(TObject)
   private
      FLock: TCriticalSection;
      FTotal: Integer;
      FSources: array[0..MAX_SOURCES - 1] of TSourceTally;
      FSourceCount: Integer;
      function IndexOf(const AId: string): Integer;
   public
      constructor Create;
      destructor Destroy; override;

      procedure OnFrame(const AFrame: TSpectrumFrame);

      function Total: Integer;
      procedure Report;
   end;

constructor TFrameCollector.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   FTotal := 0;
   FSourceCount := 0;
end;

destructor TFrameCollector.Destroy;
begin
   FreeAndNil(FLock);
   inherited Destroy;
end;

// Caller holds the lock.
function TFrameCollector.IndexOf(const AId: string): Integer;
var
   i: Integer;
begin
   for i := 0 to FSourceCount - 1 do
      begin
      if FSources[i].Id = AId then
         begin
         Result := i;
         Exit;
         end;
      end;

   if FSourceCount >= MAX_SOURCES then
      begin
      Result := -1;
      Exit;
      end;

   Result := FSourceCount;
   Inc(FSourceCount);
   FSources[Result].Id := AId;
   FSources[Result].Count := 0;
   FSources[Result].MinDb := 1.0e9;
   FSources[Result].MaxDb := -1.0e9;
end;

procedure TFrameCollector.OnFrame(const AFrame: TSpectrumFrame);
var
   idx: Integer;
   i: Integer;
   v: Single;
begin
   FLock.Acquire;

   try
      Inc(FTotal);
      idx := IndexOf(AFrame.SourceId);

      if idx < 0 then
         begin
         Exit;
         end;

      Inc(FSources[idx].Count);
      FSources[idx].CentreHz := AFrame.CentreHz;
      FSources[idx].SpanHz := AFrame.SpanHz;
      FSources[idx].NoiseFloorDb := AFrame.NoiseFloorDb;

      // Summarise the bins HERE.  Keeping the array would violate the
      // subscriber contract -- the producer may reuse it the moment this
      // returns.
      for i := 0 to AFrame.BinCount - 1 do
         begin
         v := AFrame.Bins[i];

         if v < FSources[idx].MinDb then
            begin
            FSources[idx].MinDb := v;
            end;

         if v > FSources[idx].MaxDb then
            begin
            FSources[idx].MaxDb := v;
            end;
         end;
   finally
      FLock.Release;
   end;
end;

function TFrameCollector.Total: Integer;
begin
   FLock.Acquire;

   try
      Result := FTotal;
   finally
      FLock.Release;
   end;
end;

procedure TFrameCollector.Report;
var
   i: Integer;
begin
   FLock.Acquire;

   try
      WriteLn;
      WriteLn('  frames decoded : ', FTotal);
      WriteLn('  sources seen   : ', FSourceCount);
      WriteLn;

      for i := 0 to FSourceCount - 1 do
         begin
         WriteLn(Format('  source %-2s  frames %-5d  centre %d Hz  span %d Hz',
                        [FSources[i].Id, FSources[i].Count,
                         FSources[i].CentreHz, FSources[i].SpanHz]));
         WriteLn(Format('             noise floor %.1f dB   bins %.1f .. %.1f dB',
                        [FSources[i].NoiseFloorDb,
                         FSources[i].MinDb, FSources[i].MaxDb]));
         end;
   finally
      FLock.Release;
   end;
end;

var
   host: string;
   catPort: Integer;
   seconds: Integer;
   radio: TK4Radio;
   collector: TFrameCollector;
   started: TDateTime;
   elapsed: Double;
   lastTotal: Integer;
   nowTotal: Integer;
   failed: Boolean;

begin
   if ParamCount < 1 then
      begin
      WriteLn('bench_k4spectrum: no host given -- SKIPPED');
      WriteLn('  usage: bench_k4spectrum <host> [cat-port] [seconds]');
      Halt(0);
      end;

   host := ParamStr(1);
   catPort := StrToIntDef(ParamStr(2), DEFAULT_CAT_PORT);
   seconds := StrToIntDef(ParamStr(3), DEFAULT_SECONDS);

   // The radio factory logs through MainUnit's global `logger`, which only
   // tr4w.lpr's startup assigns.  A standalone EXE that links app units must
   // assign it or the first call that logs dies with an access violation.
   logger := TLogLogger.GetLogger('K4SpectrumBench');

   failed := False;
   collector := TFrameCollector.Create;
   radio := TK4Radio.Create;

   try
      radio.radioAddress := host;
      radio.radioPort := catPort;

      WriteLn(Format('K4 spectrum bench -- %s, CAT port %d (stream on %d)',
                     [host, catPort, catPort + 1]));
      WriteLn(Format('Capability rcSpectrum : %s', [BoolToStr(radio.Supports(rcSpectrum), True)]));
      WriteLn(Format('SpectrumAvailable     : %s', [BoolToStr(radio.SpectrumAvailable, True)]));

      if not radio.SpectrumAvailable then
         begin
         WriteLn('FAIL: a network K4 should report spectrum available');
         Halt(1);
         end;

      radio.OnSpectrumFrame := collector.OnFrame;
      radio.StartSpectrum;

      if not radio.SpectrumStreaming then
         begin
         WriteLn('FAIL: StartSpectrum did not start a reader');
         Halt(1);
         end;

      WriteLn(Format('Streaming for %d s ...', [seconds]));
      WriteLn;

      started := Now;
      lastTotal := 0;

      repeat
         Sleep(1000);
         nowTotal := collector.Total;
         elapsed := (Now - started) * 24 * 60 * 60;

         WriteLn(Format('  t=%4.0f s   link %-5s   frames %-6d  (+%d/s)',
                        [elapsed, BoolToStr(radio.SpectrumLinkUp, True),
                         nowTotal, nowTotal - lastTotal]));

         lastTotal := nowTotal;
      until elapsed >= seconds;

      collector.Report;

      // A run that connected and decoded nothing is a FAILURE, not a quiet
      // pass.  This is the whole point of the exercise, so it must not be
      // possible to report green without evidence.
      if collector.Total = 0 then
         begin
         WriteLn;
         WriteLn('FAIL: no frames decoded');
         failed := True;
         end;

      radio.StopSpectrum;

      if radio.SpectrumStreaming then
         begin
         WriteLn('FAIL: StopSpectrum left a reader running');
         failed := True;
         end;
   finally
      radio.Free;
      collector.Free;
   end;

   WriteLn;

   if failed then
      begin
      WriteLn('RESULT: FAIL');
      Halt(1);
      end;

   WriteLn('RESULT: PASS');
   Halt(0);
end.

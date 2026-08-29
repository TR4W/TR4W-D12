program bench_panadapter;

{
  END-TO-END bench: the real panadapter window, showing a real K4.

  ---------------------------------------------------------------------------
  WHY
  ---------------------------------------------------------------------------
  bench_k4spectrum proves frames reach a subscriber.  It says nothing about the
  window, and the window is where the remaining risk is: a TPaintBox is the
  first raster surface in TR4W, the frames arrive on a thread that must not
  touch a control, and the repaint is driven by a TTimer under a hand-rolled
  GetMessage loop rather than by Application.Run.  None of that is provable by
  reading it.

  This opens the ACTUAL TfrmPanadapter through the ACTUAL ShowPanadapterWindow
  entry point, points it at a real radio, pumps messages for a few seconds and
  then WRITES A PNG OF THE WINDOW.  The image is the evidence: a trace that is
  flat, clipped, upside down or absent looks nothing like one that is right,
  and no amount of frame-counting would tell them apart.

  ---------------------------------------------------------------------------
  USAGE
  ---------------------------------------------------------------------------
     bench_panadapter <host> [cat-port] [source] [seconds] [out.png]
                      [palette] [cursor-x] [cat-mode]

     bench_panadapter 192.168.73.108                 -- run until closed
     bench_panadapter 192.168.73.108 9200 A 0        -- the same, explicitly
     bench_panadapter 192.168.73.108 9200 Y 30 y.png -- mini-pan, 30 s, snapshot

  SECONDS = 0 (the default) runs until the window is closed -- Escape, or the
  close box.  Any other value is a fixed duration, which is what the automated
  runs use.

  source    A or B (main pans) or Y (the 3 kHz mini-pan).
  palette   0..4 = Heat Map, Grayscale, Sepia, Blue-Green, Fire-Ice.  Applied
            half way through a timed run, to prove the history re-colours.
  cursor-x  pixel column to park the readout on before the snapshot.
  cat-mode  1 = open the CAT link and TEST CLICK-TO-TUNE (moves the VFO and
            puts it back); 2 = open the CAT link and touch nothing.  Omit for
            neither -- the panadapter itself needs no CAT link.

  With no host it SKIPS cleanly (exit 0).  Exit 1 means it ran and something
  was wrong -- no frames, or an image it could not write.
}

{$APPTYPE CONSOLE}

uses
   // Interfaces first: this links the LCL, whose widgetset registration lives
   // here.  Same reason tr4w_unit_tests.lpr does it.
   Interfaces,
   SysUtils, Classes, Graphics, Forms, Controls, Log4D, MainUnit, VC,
   uSpectrumTypes, uFactoryRadioBase, uRadioElecraftK4, uPanadapterForm,
   uPanadapterView;

const
   DEFAULT_CAT_PORT = 9200;
   DEFAULT_SECONDS = 8;
   DEFAULT_SOURCE = 'A';
   DEFAULT_OUT = 'panadapter.png';
   { The harness drives one radio, so it uses panadapter slot 1. }
   BENCH_SLOT = 1;

{ A stand-in spot provider, installed into the uPanadapterView seam.

  SYNTHETIC ON PURPOSE.  What needs proving here is the DRAWING -- staggering,
  colouring, clipping at the edges -- which wants spots at known places rather
  than whatever a cluster happens to be sending.  The real provider reads
  TR4W's spot store and is wired up with the menu.

  Spread evenly across whatever range is asked for, with a multiplier and a
  dupe among them so all three colours appear. }
function DemoSpots(const AStartHz, AEndHz: Int64): TSpectrumSpots;
const
   CALLS: array[0..5] of string =
      ('CT6IVP', 'MU8RXU', 'G3ABC', 'JA1XYZ', 'VK2DEF', 'W1AW');
var
   i: Integer;
   step: Int64;
begin
   SetLength(Result, 0);

   if AEndHz <= AStartHz then
      begin
      Exit;
      end;

   SetLength(Result, Length(CALLS));
   step := (AEndHz - AStartHz) div (Length(CALLS) + 1);

   for i := 0 to High(CALLS) do
      begin
      Result[i].Callsign := CALLS[i];
      Result[i].FreqHz := AStartHz + (step * (i + 1));
      Result[i].IsMultiplier := (i mod 3) = 1;
      Result[i].IsDupe := (i mod 3) = 2;
      end;
end;

var
   host: string;
   catPort: Integer;
   source: string;
   seconds: Integer;
   outPath: string;
   radio: TK4Radio;
   started: TDateTime;
   elapsed: Double;
   shot: TBitmap;
   png: TPortableNetworkGraphic;
   failed: Boolean;
   palette: Integer;
   switched: Boolean;
   cursorX: Integer;
   doTune: Boolean;
   doConnect: Boolean;
   closedByUser: Boolean;
   wantWidth: Integer;
   wantSpots: Boolean;
   { The bench drives ONE radio, so it drives panadapter slot 1. }
   pan: TfrmPanadapter;
   i: Integer;
   origFreq, f1, f2: Integer;
   centre, span: Int64;

begin
   if ParamCount < 1 then
      begin
      WriteLn('bench_panadapter: no host given -- SKIPPED');
      WriteLn('  usage: bench_panadapter <host> [cat-port] [source] [seconds] [out.png]');
      Halt(0);
      end;

   host := ParamStr(1);
   catPort := StrToIntDef(ParamStr(2), DEFAULT_CAT_PORT);
   source := ParamStr(3);

   if source = '' then
      begin
      source := DEFAULT_SOURCE;
      end;

   // 0 = run until the operator closes the window.  That is the default,
   // because a human running this by hand wants to look at it for as long as
   // they want to look at it, not for a number chosen in advance.
   seconds := StrToIntDef(ParamStr(4), 0);
   outPath := ParamStr(5);

   if outPath = '' then
      begin
      outPath := DEFAULT_OUT;
      end;

   // -1 (the default) means "leave the palette alone".
   palette := StrToIntDef(ParamStr(6), -1);

   // -1 (the default) means no cursor marker in the snapshot.
   cursorX := StrToIntDef(ParamStr(7), -1);

   // OFF unless asked for.  '1' opens the CAT link AND retunes; '2' opens the
   // CAT link and touches nothing -- which is how the shutdown path gets
   // exercised without moving the operator's frequency.
   doConnect := (ParamStr(8) = '1') or (ParamStr(8) = '2');
   doTune := (ParamStr(8) = '1');

   // Optional window width.  The frequency axis is computed from the real
   // width, so a wide run is how that gets checked.
   wantWidth := StrToIntDef(ParamStr(9), 0);

   // Demo spots are OPT-IN: with no provider installed the window draws none,
   // which is the normal state and worth being able to see too.
   wantSpots := (ParamStr(10) = '1');

   if wantSpots then
      begin
      PanadapterSpots := @DemoSpots;
      end;

   // The radio factory logs through MainUnit's global `logger`, which only
   // tr4w.lpr's startup assigns.  Without this the first call that logs dies
   // with an access violation.
   logger := TLogLogger.GetLogger('PanadapterBench');

   failed := False;
   Application.Initialize;

   radio := TK4Radio.Create;

   try
      radio.radioAddress := host;
      radio.radioPort := catPort;

      WriteLn(Format('Panadapter bench -- %s, CAT %d, source %s, %d s',
                     [host, catPort, source, seconds]));

      // The real entry point, not a hand-built form: what is being tested
      // includes the open path.
      ShowPanadapterWindow(BENCH_SLOT, radio, source);
      pan := PanadapterForm(BENCH_SLOT);

      if not PanadapterWindowVisible(BENCH_SLOT) then
         begin
         WriteLn('FAIL: the window did not become visible');
         Halt(1);
         end;

      if wantWidth > 0 then
         begin
         pan.Width := wantWidth;
         Application.ProcessMessages;
         WriteLn(Format('  window widened to %d px', [wantWidth]));
         end;

      started := Now;
      switched := (palette < 0);   // nothing to switch to

      // Pump the LCL the way the app's own loop does -- this is what delivers
      // WM_TIMER to tmrRefresh and therefore what drives every repaint.
      repeat
         Application.ProcessMessages;
         Sleep(10);
         elapsed := (Now - started) * 24 * 60 * 60;

         // SWITCH THE PALETTE HALF WAY, on purpose.  The waterfall stores dB
         // rather than pixels precisely so that changing palette re-colours
         // the WHOLE history; if it stored colours there would be a seam
         // across the middle of the image, and the snapshot would show it.
         if (not switched) and (seconds > 0) and (elapsed >= seconds / 2) then
            begin
            pan.cboPalette.ItemIndex := palette;
            pan.HandlePaletteChange(nil);
            switched := True;
            WriteLn(Format('  switched to palette %d at t=%.1f s', [palette, elapsed]));
            end;
      until (not PanadapterWindowVisible(BENCH_SLOT)) or
            ((seconds > 0) and (elapsed >= seconds));

      closedByUser := not PanadapterWindowVisible(BENCH_SLOT);

      if closedByUser then
         begin
         WriteLn;
         WriteLn(Format('Window closed after %.0f s.', [elapsed]));
         end;

      // MEASUREMENTS, not impressions.  A report of "sluggish" is only
      // actionable once it is known whether frames are arriving, whether they
      // are being turned into rows, and where the milliseconds go.
      WriteLn;
      WriteLn('Performance over the run:');
      WriteLn(Format('  frames from radio : %d  (%.1f/s, all pans)',
                     [pan.FramesIn,
                      pan.FramesIn / elapsed]));
      WriteLn(Format('  waterfall rows    : %d  (%.1f/s)',
                     [pan.RowsPushed,
                      pan.RowsPushed / elapsed]));
      WriteLn(Format('  paints            : %d  (%.1f/s)',
                     [pan.Paints,
                      pan.Paints / elapsed]));

      if pan.RowsPushed > 0 then
         begin
         WriteLn(Format('  ms in row push    : %d total, %.2f ms each',
                        [pan.MsInRows,
                         pan.MsInRows / pan.RowsPushed]));
         end;

      if pan.Paints > 0 then
         begin
         WriteLn(Format('  ms in paint       : %d total, %.2f ms each',
                        [pan.MsInPaint,
                         pan.MsInPaint / pan.Paints]));
         end;

      WriteLn(Format('  CPU busy in draw  : %.1f%% of wall clock',
                     [((pan.MsInRows + pan.MsInPaint)
                       / (elapsed * 1000.0)) * 100.0]));
      WriteLn;
      WriteLn(Format('  link up   : %s', [BoolToStr(radio.SpectrumLinkUp, True)]));
      WriteLn(Format('  streaming : %s', [BoolToStr(radio.SpectrumStreaming, True)]));

      if (not closedByUser) and (not radio.SpectrumLinkUp) then
         begin
         WriteLn('FAIL: no link to the spectrum port');
         failed := True;
         end;

      // ---- click-to-tune, against the real radio ------------------------
      //
      // THIS MOVES THE OPERATOR'S VFO, so it is opt-in, bounded, and it puts
      // the frequency back.  Everything it does stays inside the pan's own
      // span -- a few tens of kHz -- so it cannot leave the band it started
      // in.  Run only with explicit consent (NY4I, 2026-08-25).
      if doConnect then
         begin
         WriteLn;
         WriteLn('CAT link test' + BoolToStr(doTune, ' (with click-to-tune)', ' (connect only)'));

         // The spectrum socket alone cannot tune: SetFrequency writes to the
         // CAT link, which StartSpectrum does not open.
         if radio.Connect <> 0 then
            begin
            WriteLn('  FAIL: could not open the CAT link');
            failed := True;
            end
         else
            begin
            // Let auto-info populate the frequency.  The K4 drops a silent CAT
            // client after ~10 s and nothing here runs TR4W's polling thread,
            // so this sends its own keepalive.
            for i := 1 to 30 do
               begin
               Application.ProcessMessages;
               Sleep(100);

               if (i mod 20) = 0 then
                  begin
                  radio.SendToRadio('PING;');
                  end;
               end;

            origFreq := radio.frequency[nrVFOA];
            centre := pan.DisplayedCentreHz;
            span := pan.DisplayedSpanHz;
            WriteLn(Format('  VFO A now %d Hz;  pan centre %d, span %d',
                           [origFreq, centre, span]));

            if (origFreq <= 0) or (span <= 0) then
               begin
               WriteLn('  FAIL: no frequency or span to work from');
               failed := True;
               end
            else if doTune then
               begin
               try
                  // Quarter and three-quarter width: a click at each should
                  // land a quarter span either side of centre.  Two points,
                  // because ONE would pass even with the frequency axis
                  // mirrored.
                  pan.HandleSpectrumMouseDown(
                     nil, mbLeft, [], pan.pbSpectrum.Width div 4, 10);
                  Sleep(700);
                  Application.ProcessMessages;
                  radio.SendToRadio('FA;');
                  Sleep(500);
                  Application.ProcessMessages;
                  f1 := radio.frequency[nrVFOA];

                  // RE-READ THE CENTRE.  The K4 re-centres the pan on the VFO,
                  // so the first click moved the display out from under us.
                  // Predicting the second click from the ORIGINAL centre made
                  // this test fail against a radio that was behaving perfectly
                  // -- the reading, not the code, was wrong.
                  centre := pan.DisplayedCentreHz;
                  span := pan.DisplayedSpanHz;

                  pan.HandleSpectrumMouseDown(
                     nil, mbLeft, [], (pan.pbSpectrum.Width * 3) div 4, 10);
                  Sleep(700);
                  Application.ProcessMessages;
                  radio.SendToRadio('FA;');
                  Sleep(500);
                  Application.ProcessMessages;
                  f2 := radio.frequency[nrVFOA];

                  WriteLn(Format('  clicked 25%% -> %d Hz  (expected ~%d)',
                                 [f1, centre - (span div 4)]));
                  WriteLn(Format('  clicked 75%% -> %d Hz  (expected ~%d)',
                                 [f2, centre + (span div 4)]));

                  if (f1 = origFreq) and (f2 = origFreq) then
                     begin
                     WriteLn('  FAIL: the radio did not move');
                     failed := True;
                     end;

                  if f2 <= f1 then
                     begin
                     WriteLn('  FAIL: frequency did not increase left-to-right');
                     failed := True;
                     end;

                  // Within a tenth of the span of the predicted point.  Loose
                  // on purpose: the radio rounds to its tuning step and the
                  // pan may drift a little between the two clicks.
                  if Abs(f1 - (centre - (span div 4))) > (span div 10) then
                     begin
                     WriteLn('  FAIL: the 25% click did not land where predicted');
                     failed := True;
                     end;

                  if Abs(f2 - (centre + (span div 4))) > (span div 10) then
                     begin
                     WriteLn('  FAIL: the 75% click did not land where predicted');
                     failed := True;
                     end;
               finally
                  // ALWAYS, including after a failure above: the operator's
                  // frequency is not ours to leave moved.
                  radio.SetFrequency(origFreq, nrVFOA, rmNone);
                  Sleep(500);
                  Application.ProcessMessages;
                  radio.SendToRadio('FA;');
                  Sleep(500);
                  Application.ProcessMessages;
                  WriteLn(Format('  restored VFO A to %d Hz (radio reports %d)',
                                 [origFreq, radio.frequency[nrVFOA]]));

                  if radio.frequency[nrVFOA] <> origFreq then
                     begin
                     WriteLn('  *** WARNING: could not confirm the restore -- CHECK THE RADIO');
                     failed := True;
                     end;
               end;
               end;
            end;
         end;

      // Park the cursor before the snapshot so the readout and the vertical
      // marker appear in it.  Driving the real handler rather than poking a
      // field means the snapshot exercises the same path a mouse does.
      if (cursorX >= 0) and (not closedByUser) then
         begin
         pan.HandleSpectrumMouseMove(nil, [], cursorX, 0);
         Application.ProcessMessages;
         end;

      // THE EVIDENCE.  GetFormImage captures the window as drawn, so the trace,
      // the axis labels and the status text are all in it.
      // A closed window has nothing to photograph, and asking for its image
      // would capture a hidden form rather than fail loudly.
      if closedByUser then
         begin
         WriteLn('  snapshot  : skipped (window was closed)');
         end
      else
         begin
         shot := pan.GetFormImage;

         try
            png := TPortableNetworkGraphic.Create;

            try
               png.Assign(shot);
               png.SaveToFile(outPath);
               WriteLn(Format('  snapshot  : %s (%dx%d)', [outPath, shot.Width, shot.Height]));
            finally
               png.Free;
            end;
         finally
            shot.Free;
         end;
         end;

      ClosePanadapterWindow(BENCH_SLOT);

      if PanadapterWindowVisible(BENCH_SLOT) then
         begin
         WriteLn('FAIL: the window did not close');
         failed := True;
         end;

      if radio.SpectrumStreaming then
         begin
         WriteLn('FAIL: closing the window left the stream running');
         failed := True;
         end;
   finally
      // Free the form before the radio: its destructor detaches, and detaching
      // touches the radio.  Narrated because a fault in here is otherwise an
      // address with no context.
      WriteLn('  teardown: freeing the window ...');
      pan := nil;
      FreePanadapterWindow(BENCH_SLOT);
      WriteLn('  teardown: window freed');

      if doConnect then
         begin
         WriteLn('  teardown: disconnecting CAT ...');
         radio.Disconnect;
         WriteLn('  teardown: CAT disconnected');
         end;

      WriteLn('  teardown: freeing the radio ...');
      radio.Free;
      WriteLn('  teardown: radio freed');
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

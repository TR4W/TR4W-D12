unit uPanadapterForm;
{$I ..\..\tr4w.inc}

{
  THE PANADAPTER WINDOW.  A designed LCL form -- and a PURE one: no Win32 call,
  no HWND, nothing from the legacy window table.

  NY4I, 2026-08-25: "please ensure you do not use any win32 or hwnd code at
  all" / "Yes pure LCL only".  That rules out most of the band map's plumbing,
  which is LCL-designed but still opened the old way: CreateTR4WBandMapWindow
  returns a Form.Handle, OpenTR4WWindow stores it in tr4w_WindowsArray as an
  HWND and finishes with SetWindowPos.  None of that appears here.  This window
  is created, Shown and Hidden, and that is the whole of its lifecycle.

  ---------------------------------------------------------------------------
  HOW FRAMES GET FROM THE RADIO TO THE SCREEN
  ---------------------------------------------------------------------------
  AcceptFrame is called ON THE SPECTRUM THREAD, ~36 times a second.  It touches
  NO control.  All it does is copy the frame into a locked slot and set a dirty
  flag; a TTimer on the main thread picks the slot up and repaints.

  A TIMER RATHER THAN Synchronize, and for coalescing -- not because
  Synchronize is unavailable.  (An earlier draft of this comment said it was,
  on the strength of TR4W owning a hand-rolled GetMessage loop.  That has been
  false since Phase 3c on 2026-08-23: the program runs Application.Run, whose
  loop does call CheckSynchronize.  The design below did not change when that
  was corrected; only this paragraph did.)

  The reason is the shape of the data.  The K4 interleaves THREE pans down one
  socket at ~36 frames a second between them, this window shows ONE, and only
  the newest frame of that one is worth drawing.  Synchronize would marshal
  every frame -- including the two thirds destined to be discarded -- into 36
  cross-thread round trips a second to produce at most 20 useful repaints.
  Parking the newest frame and letting a timer collect it does strictly less
  work and cannot build a backlog.

  TThread.Queue is separately unsafe here: under FPC it purges its own
  callback.  A TTimer becomes SetTimer/WM_TIMER, the same mechanism
  uPrefsForm.pas:3410 relies on for its focus timer.

  DOUBLE COPY, ON PURPOSE.  The timer copies the shared slot into render fields
  that only the main thread touches, and the paint path then reads those with
  no lock held.  Holding the lock across a repaint would stall the reader.

  ---------------------------------------------------------------------------
  SCALING -- THE RADIO'S OWN MODEL
  ---------------------------------------------------------------------------
  The K4 scales its display with a REFERENCE LEVEL and a SCALE (a dB range):
  QK4's renderer is literally `minDb = refLevel; maxDb = refLevel + scale`
  (qk4/src/dsp/panadapter_rhi.cpp:1895), and the radio reports #REF -126 with
  #SCL 80.  This window uses the same model with the same 80 dB default, so its
  vertical scaling matches what the operator already sees on the rig.

  AND IT NEEDS NO CAT LINK TO DO IT.  The K4's AutoRef makes #REF track the
  noise floor, and the noise floor is already in every spectrum packet -- so
  the reference comes from the stream.  Measured within seconds of each other:
  #REF -126, packet noise floor -125.5.

  A SMALL MARGIN BELOW THE REFERENCE, deliberately.  Exactly [ref, ref+scale]
  clips every noise excursion below the floor into a solid bar along the
  bottom; the bins run to -160 while the floor is -125.  REF_MARGIN_DB keeps
  that texture visible without changing the 80 dB range.

  Scale is adjustable over the K4's own 10..150 range for the same reason the
  radio makes it adjustable: 80 dB is right for a busy band and far too much
  for a quiet one.

  ---------------------------------------------------------------------------
  DRAWING
  ---------------------------------------------------------------------------
  This is the first raster surface in TR4W -- there was no TPaintBox and no
  TBitmap anywhere in src before it, only grid OnDrawCell.  Three decisions:

  DECIMATE BY PEAK, not by nearest neighbour.  2048 bins land on ~700 pixels,
  so each pixel covers about three bins.  Sampling one of the three -- what
  TR4QT does -- lets a signal one or two bins wide fall between samples and
  vanish.  For a contest logger, where the whole point is spotting a weak CW
  signal in the noise, dropping the narrowest signals is the wrong trade.  One
  helper serves both the trace and the waterfall so they cannot disagree.

  THE WATERFALL KEEPS dB, NOT PIXELS.  The obvious implementation scrolls the
  bitmap and writes coloured pixels into the top row, which is what TR4QT's
  WaterfallImageProvider does -- and it bakes the palette and the scale into
  the history.  Change either and the old rows keep the old colours, leaving a
  seam across the display.  Keeping the decimated dB values instead means a
  palette or scale change re-renders the whole waterfall correctly.  It costs
  one Single per pixel of history (~450 KB) and a full re-render only when
  something actually changed.

  AND IT KEEPS THEM RELATIVE TO EACH ROW'S OWN REFERENCE.  Storing absolute dB
  and scaling by the newest frame's noise floor has the opposite failure: change
  band and the floor moves 25 dB, so the entire history re-colours at once and
  rows recorded minutes ago change appearance.  Storing "how far above the floor
  this was when it was measured" is stable over time AND still re-renderable.

  THE PALETTES ARE THE K4'S FIVE.  #WFC is 0..4 on the radio, which is where
  TR4QT's five come from too.  TR4W picks its own (NY4I, 2026-08-25) rather
  than following #WFC, but there being exactly five is not a coincidence.
}

interface

uses
   Classes, SysUtils, SyncObjs, Forms, Controls, Graphics, ExtCtrls, StdCtrls,
   ComCtrls, LCLType, Math,
   uSpectrumTypes, uFactoryRadioBase, uPanadapterView;

type
   TfrmPanadapter = class(TForm)
      pnlTop: TPanel;
      lblSource: TLabel;
      lblStatus: TLabel;
      lblScale: TLabel;
      cboPalette: TComboBox;
      btnPause: TButton;
      trkScale: TTrackBar;
      pbSpectrum: TPaintBox;
      lblSpan: TLabel;
      btnSpanNarrow: TButton;
      btnSpanWide: TButton;
      tmrRefresh: TTimer;

      procedure HandleCreate(Sender: TObject);
      procedure HandleDestroy(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure HandleSpectrumPaint(Sender: TObject);
      procedure HandleRefreshTimer(Sender: TObject);
      procedure HandlePaletteChange(Sender: TObject);
      procedure HandlePauseClick(Sender: TObject);
      procedure HandleScaleChange(Sender: TObject);
      procedure HandleSpanNarrow(Sender: TObject);
      procedure HandleSpanWide(Sender: TObject);
      procedure HandleSpectrumMouseDown(Sender: TObject; Button: TMouseButton;
                                        Shift: TShiftState; X, Y: Integer);
      procedure HandleSpectrumMouseMove(Sender: TObject; Shift: TShiftState;
                                        X, Y: Integer);
      procedure HandleSpectrumMouseLeave(Sender: TObject);
   private
      // SyncObjs. IS LOAD-BEARING.  LCLType declares `TCriticalSection = PtrUInt`
      // (lcltype.pp:70) -- a Win32 handle alias, not the class -- and it comes
      // later in the uses clause than SyncObjs, so an unqualified name binds to
      // the PtrUInt and every .Acquire fails with "Illegal qualifier".
      FLock: SyncObjs.TCriticalSection;
      FRadio: TFactoryRadioBase;

      // ---- shared slot: written on the SPECTRUM THREAD, read by the timer,
      //      never touched without FLock ------------------------------------
      FWantSource: string;
      FShareDirty: Boolean;
      FShareCentreHz: Int64;
      FShareSpanHz: Int64;
      FShareNoiseDb: Single;
      FShareBins: TSpectrumBins;

      // ---- render copy: MAIN THREAD ONLY, no lock needed ------------------
      FHaveRender: Boolean;
      FRenderCentreHz: Int64;
      FRenderSpanHz: Int64;
      FRenderNoiseDb: Single;
      FRenderBins: TSpectrumBins;

      // ---- display settings ------------------------------------------------
      FPalette: Integer;
      FScaleDb: Integer;
      FPaused: Boolean;
      FLUT: array[0..255] of LongWord;

      { Which radio this window belongs to, 1 or 2.  Set by
        ShowPanadapterWindow; it is what makes the layout key distinct. }
      FSlot: integer;
      { Restored ONCE per run -- reshowing must not drag the window back to
        where it sat at start-up. }
      FBoundsRestored: boolean;
      { WHAT IS BELIEVED TO BE ON DISK, so a move can be detected without
        rewriting settings/tr4w.json every tick.  Same shape as MainUnit's
        GSavedLayout, and for the same reason. }
      FSavedBounds: TRect;
      FSavedVisible: boolean;
      FHaveSaved: boolean;

      // ---- waterfall: dB history plus the bitmap rendered from it ----------
      FWaterfall: TBitmap;
      FWfDb: array of Single;      // FWfW * FWfH, row 0 = newest
      FWfW: Integer;
      FWfH: Integer;
      FWfDirty: Boolean;

      // Mouse cursor column, or -1.  Drawn, not a control.
      FCursorX: Integer;
      FCWPitchHz: Integer;

      // ---- instrumentation -------------------------------------------------
      // Counters and millisecond totals, so "it feels slow" can be turned into
      // numbers.  Deliberately NOT QueryPerformanceCounter: that is Win32, and
      // this window is required to stay clear of it.  GetTickCount64 is only
      // millisecond-resolution, which is why these are TOTALS over a run rather
      // than per-call timings.
      FFramesIn: Int64;
      FRowsPushed: Int64;
      FPaints: Int64;
      FMsInRows: Int64;
      FMsInPaint: Int64;

      procedure AcceptFrame(const AFrame: TSpectrumFrame);   // SPECTRUM THREAD
      procedure UpdateLabels;
      function FormatMHz(AHz: Int64): string;
      function RenderFrame: TSpectrumFrame;
      function FreqAtPixel(AX: Integer): Int64;
      procedure PlotLayout(out ASpecH, AAxisTop, AWfTop, AWfH: Integer);
      function FormatAxis(AHz, AStepHz: Int64): string;
      procedure DrawAxis(ACanvas: TCanvas; AWidth, AAxisTop: Integer);
      procedure DrawDbScale(ACanvas: TCanvas; AWidth, ASpecH: Integer;
                            AMinDb, ARangeDb: Single);
      procedure StepSpan(const aWider: boolean);
      procedure ShowSpan;
      function  LayoutName: string;
      procedure RestoreBounds;
      procedure SaveCurrentBounds(const aVisible: boolean);
      function  LiveBounds: TRect;
      function  LayoutDiffersFromDisk: boolean;
      function PixelForFreq(AHz: Int64; AWidth: Integer): Integer;
      function VfoDisplayHz(AVfo: TVFO): Int64;
      procedure DrawVfoPassband(ACanvas: TCanvas; AVfo: TVFO; APassband: TColor;
                                AWidth, ASpecH: Integer);
      procedure DrawVfoMarker(ACanvas: TCanvas; AVfo: TVFO; AColor: TColor;
                              const ATag: string; AWidth, AAxisTop: Integer);
      procedure DrawSpots(ACanvas: TCanvas; AWidth, ASpecH: Integer);

      procedure BuildPalette;
      function PeakForPixel(AX: Integer; ABinsPerPixel: Double): Single;
      procedure DisplayRange(out AMinDb, ARangeDb: Single);
      function WaterfallColor(ARelDb: Single): LongWord;
      procedure EnsureWaterfall(AWidth, AHeight: Integer);
      procedure PushWaterfallRow(ABinsPerPixel: Double);
      procedure RenderWaterfall;
   public
      procedure AttachRadio(ARadio: TFactoryRadioBase; const ASourceId: string);
      procedure DetachRadio;

      { The receiver's CW pitch in Hz, for click-to-tune.  0 (the default)
        means no correction.

        SUPPLIED BY THE CALLER, deliberately, because nothing here can know it.
        In CW the spectrum shows a signal at its RF frequency, but the dial has
        to sit a pitch below that for the signal to land in the passband -- so
        clicking a signal and tuning to exactly where it appears leaves you
        offset by the pitch, which on CW is the difference between working a
        station and calling on top of one.

        Nothing in TR4W can answer it today: there is no CW pitch anywhere in
        the radio factory (the rigs are never asked), and Config.CWTone is
        TR4W's own SIDETONE, which only equals the receiver's pitch on a
        station where the operator has matched them.  Rather than quietly
        assume that, the window takes the number from whoever opens it and
        applies no correction until told. }
      property CWPitchHz: Integer read FCWPitchHz write FCWPitchHz;

      { What the window is currently showing.  0 before the first frame.
        Published so a host can label or verify the display without reaching
        into the render state -- the bench uses them to predict where a click
        at a given pixel should land. }
      property DisplayedCentreHz: Int64 read FRenderCentreHz;
      property DisplayedSpanHz: Int64 read FRenderSpanHz;

      { Run counters, for turning a report of sluggishness into measurements.
        FramesIn counts EVERY frame the radio sent, including the pans this
        window is not showing -- the decode cost is paid for all of them. }
      property FramesIn: Int64 read FFramesIn;
      property RowsPushed: Int64 read FRowsPushed;
      property Paints: Int64 read FPaints;
      property MsInRows: Int64 read FMsInRows;
      property MsInPaint: Int64 read FMsInPaint;
   end;

{ ONE PANADAPTER PER RADIO.  Slot 1 is Radio 1, slot 2 is Radio 2 -- the same
  shape the dupe sheets and the radio panels already use, and for the same
  reason: an SO2R station with two K4s wants both spectra at once, and a single
  global made opening the second STEAL the first, because AttachRadio detaches
  whatever was there.

  NOTHING ABOUT THE RENDERING HAD TO CHANGE.  Every one of the form's sixty-odd
  fields -- the waterfall bitmap, the lock, the palette, the frame buffers --
  was already per-instance, and each TK4Radio already owns its own spectrum
  thread on its own port (CAT + 1, derived from that radio's radioPort).  Only
  three things were singletons: the form, the restore-once flag and the layout
  key. }
function PanadapterForm(const aSlot: integer): TfrmPanadapter;

procedure ShowPanadapterWindow(const aSlot: integer;
                               ARadio: TFactoryRadioBase; const ASourceId: string;
                               const ACaption: string = '');
procedure ClosePanadapterWindow(const aSlot: integer);

{ A RADIO OBJECT IS ABOUT TO BE FREED.  Closes any panadapter bound to it.

  CALL THIS WHILE THE RADIO IS STILL ALIVE -- that is the whole contract.  The
  window has to run its normal teardown (StopSpectrum, which terminates and
  JOINS the reading thread, then unsubscribe), and none of that is possible
  against a freed object.

  WHY IT EXISTS.  A panadapter holds a raw TFactoryRadioBase it does not own,
  and until now nothing told it when that object died.  Changing the active
  profile frees every radio and builds new ones
  (RadioObject.ShutDownRadioInterface), so the window was left holding a
  dangling pointer -- and every nil guard in this unit passed, because the
  pointer was not nil, it was DEAD.  Measured on NY4I's station 2026-08-26,
  switching a K4 profile to "FT1000/K3":

      [CRASH] unhandled EAccessViolation in thread (main)
        at  SHOWSPAN,           line 1288 of uPanadapterForm.pas
            UPDATELABELS,       line 1733
            HANDLEREFRESHTIMER, line 980

  -- the refresh timer reaching FRadio.SpectrumSpanHz on freed memory.  The
  same run also logged "[Elecraft K4 spectrum] link lost: Access violation"
  from TWO K4 spectrum threads still reconnecting to the old profile's radios a
  second after the switch.

  CLOSES RATHER THAN HIDES.  NY4I, 2026-08-26: "if the radio does not support a
  spectrum scope, those windows should be closed."  A window whose radio has
  gone can show nothing, and leaving it up as an empty frame is worse than
  removing it.  The operator gets it back from the panel's Spectrum button,
  which reappears exactly when the new radio can feed one.

  ACloseWindow=False FOR SHUTDOWN, AND THE DIFFERENCE IS NOT COSMETIC.
  Closing runs HandleClose, which records visible=False -- that is right for
  a profile change (the operator's radio really did go away) and WRONG at
  program exit, where it would silently discard "this window was open" and
  the panadapter would not come back next run.  Shutdown wants the radio
  released and the saved state left exactly as it stands. }
procedure PanadapterRadioGoingAway(ARadio: TFactoryRadioBase;
                                   const ACloseWindow: Boolean = True);
function PanadapterWindowVisible(const aSlot: integer): Boolean;
{ Frees the instance AND clears the slot.  A bench harness that freed the
  form itself would leave a dangling pointer in GPanForms. }
procedure FreePanadapterWindow(const aSlot: integer);

{ WINDOW LAYOUT.  The panadapter is NOT a tw_ window, so
  FindAndSaveRectOfAllWindows never sees it and it has to answer for itself.
  These two are driven by MainUnit's EXISTING 5-second autosave and its
  save-at-exit backstop -- deliberately not a second timer with its own
  cadence, because two mechanisms writing one file is how drift starts. }
function PanadapterLayoutChanged: boolean;
procedure SavePanadapterLayout;

{ Was this slot's window open when TR4W last shut down?  Read straight from
  the layout store, so it can be asked before any form exists. }
function PanadapterWasOpen(const aSlot: integer): boolean;

implementation

uses
   uLCLFormHelpers,     // OwnFormByMainWindow -- LCL PopupParent, not GWL_HWNDPARENT
   Types,               // IntersectRect -- the RTL one, not Windows
   uWindowLayoutStore,  // the bounds, keyed by name
   uTR4WConfigFile,     // TR4WConfigFileName, Load/SaveWindowLayout
   Log4D;               // a window that vanishes on its own must say why

{$R *.lfm}

var
   { Indexed by SLOT: 1 is Radio 1, 2 is Radio 2. }
   GPanForms: array[1..2] of TfrmPanadapter = (nil, nil);

var
   { NOT MainUnit's global `logger`.  This form deliberately depends on
     nothing but the LCL, the spectrum seam and its own helpers, and pulling
     MainUnit in for one log line would undo that.  Log4D's own registry
     gives the same appender without the coupling -- the same thing
     uRadioIcomBase does. }
   panLogger: TLogLogger;

function SlotIsValid(const aSlot: integer): boolean;
begin
   Result := (aSlot >= Low(GPanForms)) and (aSlot <= High(GPanForms));
end;

procedure PanadapterRadioGoingAway(ARadio: TFactoryRadioBase;
                                   const ACloseWindow: Boolean = True);
var
   i: integer;
   what: string;
begin
   if ACloseWindow then
      begin
      what := 'closed';
      end
   else
      begin
      what := 'detached';
      end;

   if ARadio = nil then
      begin
      Exit;
      end;

   for i := Low(GPanForms) to High(GPanForms) do
      begin
      if (GPanForms[i] = nil) or (GPanForms[i].FRadio <> ARadio) then
         begin
         Continue;
         end;

      { ORDER MATTERS, and it is the order HandleDestroy already relies on.
        DetachRadio calls StopSpectrum, which joins the reading thread -- so
        after it returns no AcceptFrame can still be in flight.  Doing this
        AFTER the free, or not at all, is what produced the crash quoted on the
        declaration. }
      GPanForms[i].DetachRadio;

      if ACloseWindow then
         begin
         GPanForms[i].Close;
         end;

      if Assigned(panLogger) then
         begin
         panLogger.Info('[Panadapter %d] %s -- its radio is being freed', [i, what]);
         end;
      end;
end;

function PanadapterForm(const aSlot: integer): TfrmPanadapter;
begin
   Result := nil;
   if SlotIsValid(aSlot) then
      begin
      Result := GPanForms[aSlot];
      end;
end;

type
   // Indexing a raw scan line.  Range checking is off in this tree, which is
   // what makes the [0..0] idiom work; it is the standard Pascal spelling for
   // "pointer to an array of unknown length".
   TLongWordArray = array[0..0] of LongWord;
   PLongWordArray = ^TLongWordArray;

const
   // The K4's own default scale (#SCL) and its adjustable range.
   DEFAULT_SCALE_DB = 80;
   MIN_SCALE_DB = 10;
   MAX_SCALE_DB = 150;

   // How far BELOW the reference the display starts -- see the unit header.
   REF_MARGIN_DB = 10.0;

   // The radio reports #WFH 50, i.e. it splits its own display in half.
   WATERFALL_FRACTION = 0.5;

   TRACE_COLOR = TColor($00FF9040);      // TColor is $00BBGGRR: a light blue
   CENTRE_COLOR = TColor($00606060);
   GRID_COLOR = TColor($00303030);
   CURSOR_COLOR = TColor($00A0A0A0);
   AXIS_COLOR = TColor($00C0C0C0);
   AXIS_TICK_COLOR = TColor($00707070);

   // Height reserved at the bottom for the frequency scale.
   AXIS_HEIGHT = 20;

   // Roughly the width of one label plus breathing room.  The number of ticks
   // follows from the window width, which is the whole point: three labels at
   // fixed positions bunched up on the left the moment the window was widened
   // (NY4I, 2026-08-25) -- and the middle one, still captioned as the centre
   // frequency, was no longer anywhere near the centre.
   AXIS_LABEL_PX = 130;

   // QK4's VFO colours, matched deliberately (k4constants.h:34-35): an operator
   // running both programs should not have to learn two colour schemes.
   // TColor is $00BBGGRR, so these are the byte-swapped forms of #00BFFF and
   // #00FF00.
   VFOA_COLOR = TColor($00FFBF00);        // cyan
   VFOB_COLOR = TColor($0000FF00);        // green
   VFOA_PASSBAND = TColor($00301F00);     // the same hues, dark enough to sit
   VFOB_PASSBAND = TColor($00002800);     // behind the trace without hiding it

   // Anything outside this is not a receive filter, and drawing a passband from
   // it would paint most of the window.
   MIN_FILTER_HZ = 20;
   MAX_FILTER_HZ = 30000;

   // DX spots.  Multipliers stand out because in a contest that is the whole
   // question; dupes are dimmed rather than hidden, because "already worked"
   // is information too -- it stops you calling again.
   SPOT_COLOR = TColor($00FFFF00);        // cyan
   SPOT_MULT_COLOR = TColor($0000D7FF);   // amber
   SPOT_DUPE_COLOR = TColor($00707070);   // grey
   SPOT_TICK_COLOR = TColor($00808080);

   // Callsign rows available for staggering before labels are dropped.
   SPOT_ROWS = 3;
   SPOT_ROW_HEIGHT = 14;
   SPOT_TOP = 18;

   PALETTE_HEATMAP = 0;
   PALETTE_GRAYSCALE = 1;
   PALETTE_SEPIA = 2;
   PALETTE_BLUEGREEN = 3;
   PALETTE_FIREICE = 4;

   // The uninitialised waterfall reads far below any real reference, so it
   // clamps to LUT index 0 -- black in every palette -- rather than needing a
   // separate "no data here" test in the render loop.
   WF_EMPTY_DB = -1.0e9;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

procedure TfrmPanadapter.HandleCreate(Sender: TObject);
begin
   FLock := SyncObjs.TCriticalSection.Create;   // qualified -- see the field
   FHaveRender := False;
   FShareDirty := False;
   FWantSource := 'A';
   FPalette := PALETTE_HEATMAP;
   FScaleDb := DEFAULT_SCALE_DB;
   FPaused := False;
   FWfW := 0;
   FWfH := 0;
   FWfDirty := False;
   FCursorX := -1;
   FCWPitchHz := 0;
   FFramesIn := 0;
   FRowsPushed := 0;
   FPaints := 0;
   FMsInRows := 0;
   FMsInPaint := 0;

   cboPalette.ItemIndex := FPalette;
   trkScale.Position := FScaleDb;
   lblScale.Caption := IntToStr(FScaleDb) + ' dB';

   BuildPalette;
end;

procedure TfrmPanadapter.HandleDestroy(Sender: TObject);
begin
   // Before the lock goes: DetachRadio joins the reading thread, so after it
   // returns nothing can call AcceptFrame on a half-destroyed form.
   DetachRadio;
   FreeAndNil(FWaterfall);
   FreeAndNil(FLock);
end;

procedure TfrmPanadapter.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   { visible=FALSE: closing IS the operator saying they do not want this
     window next time.  True here would reopen, next run, a window they
     had just dismissed. }
   SaveCurrentBounds(False);

   // Closing STOPS THE STREAM.  It is a second TCP socket and ~150 KB/s; a
   // hidden window quietly consuming that would be a cost nobody asked for.
   DetachRadio;
   tmrRefresh.Enabled := False;
   CloseAction := caHide;
end;

procedure TfrmPanadapter.HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmPanadapter.AttachRadio(ARadio: TFactoryRadioBase; const ASourceId: string);
begin
   if ARadio = nil then
      begin
      Exit;
      end;

   if FRadio <> nil then
      begin
      DetachRadio;
      end;

   FLock.Acquire;

   try
      FWantSource := ASourceId;
      FShareDirty := False;
   finally
      FLock.Release;
   end;

   FHaveRender := False;
   FRadio := ARadio;

   lblSource.Caption := 'Pan ' + ASourceId;

   // Subscribe BEFORE starting, so the very first frame is not dropped.
   FRadio.OnSpectrumFrame := AcceptFrame;
   FRadio.StartSpectrum;

   tmrRefresh.Enabled := True;
   UpdateLabels;
end;

procedure TfrmPanadapter.DetachRadio;
var
   radio: TFactoryRadioBase;
begin
   radio := FRadio;
   FRadio := nil;

   if radio = nil then
      begin
      Exit;
      end;

   // ORDER MATTERS.  StopSpectrum terminates and JOINS the reading thread, so
   // once it returns no AcceptFrame call can still be running.
   radio.StopSpectrum;
   radio.OnSpectrumFrame := nil;
end;

// ---------------------------------------------------------------------------
// SPECTRUM THREAD.  Touches no control, takes no decision -- copies and leaves.
// ---------------------------------------------------------------------------
procedure TfrmPanadapter.AcceptFrame(const AFrame: TSpectrumFrame);
begin
   FLock.Acquire;

   try
      // Counted BEFORE the source filter: the decode cost was already paid for
      // this frame whether or not this window wants it.
      Inc(FFramesIn);

      if AFrame.SourceId <> FWantSource then
         begin
         Exit;                       // another pan on the same socket
         end;

      FShareCentreHz := AFrame.CentreHz;
      FShareSpanHz := AFrame.SpanHz;
      FShareNoiseDb := AFrame.NoiseFloorDb;

      // COPY the bins.  The producer may reuse or free its array the moment
      // this returns -- retaining the reference is what TSpectrumFrameProc
      // forbids.
      if Length(FShareBins) <> AFrame.BinCount then
         begin
         SetLength(FShareBins, AFrame.BinCount);
         end;

      if AFrame.BinCount > 0 then
         begin
         Move(AFrame.Bins[0], FShareBins[0], AFrame.BinCount * SizeOf(Single));
         end;

      FShareDirty := True;
   finally
      FLock.Release;
   end;
end;

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

procedure TfrmPanadapter.BuildPalette;
var
   i: Integer;
   t, u: Single;
   r, g, b: Integer;

   function Clamp255(v: Integer): Integer;
   begin
      if v < 0 then
         begin
         Result := 0;
         end
      else if v > 255 then
         begin
         Result := 255;
         end
      else
         begin
         Result := v;
         end;
   end;

begin
   for i := 0 to 255 do
      begin
      t := i / 255.0;
      r := 0;
      g := 0;
      b := 0;

      case FPalette of
         PALETTE_GRAYSCALE:
            begin
            r := Round(255 * t);
            g := r;
            b := r;
            end;

         PALETTE_SEPIA:
            begin
            r := Clamp255(Round(300 * t));
            g := Clamp255(Round(220 * t * t + 30 * t));
            b := Clamp255(Round(150 * t * t * t));
            end;

         PALETTE_BLUEGREEN:
            begin
            r := 0;
            g := Round(255 * t);
            b := Clamp255(Round(210 * (1 - t) * t * 4));
            end;

         PALETTE_FIREICE:
            begin
            // BLACK first, then blue -> white -> red.  The obvious spelling of
            // "ice to fire" starts at full blue, and that is wrong for a
            // waterfall: almost every pixel is noise floor, so a bright colour
            // at t=0 floods the display and buries the signals it exists to
            // show.  Proven on the bench -- the first version rendered a solid
            // blue-white sheet.  EVERY palette here starts at black.
            // The dark run reaches 0.45 for the same reason the heat map's does:
            // at an 80 dB scale the noise floor lands around t = 0.1..0.3, so a
            // palette that is already saturated there has nothing left to show a
            // weak signal with.  Measured, not guessed -- the first version
            // saturated by 0.33 and the noise came out solid blue.
            if t < 0.45 then
               begin
               u := t / 0.45;                // black -> blue
               b := Round(255 * u);
               end
            else if t < 0.75 then
               begin
               u := (t - 0.45) / 0.30;       // blue -> white
               r := Round(255 * u);
               g := Round(255 * u);
               b := 255;
               end
            else
               begin
               u := (t - 0.75) / 0.25;       // white -> red
               r := 255;
               g := Round(255 * (1 - u));
               b := Round(255 * (1 - u));
               end;
            end;

         else
            begin
            // Heat map: black -> blue -> cyan -> green -> yellow -> red.
            // The stops are TR4QT's, which are in turn modelled on the K4's.
            if t < 0.25 then
               begin
               u := t / 0.25;
               b := Round(40 * u);
               end
            else if t < 0.4 then
               begin
               u := (t - 0.25) / 0.15;
               g := Round(30 * u);
               b := 40 + Round(120 * u);
               end
            else if t < 0.55 then
               begin
               u := (t - 0.4) / 0.15;
               g := 30 + Round(225 * u);
               b := 160 + Round(95 * u);
               end
            else if t < 0.7 then
               begin
               u := (t - 0.55) / 0.15;
               g := 255;
               b := Round(255 * (1 - u));
               end
            else if t < 0.85 then
               begin
               u := (t - 0.7) / 0.15;
               r := Round(255 * u);
               g := 255;
               end
            else
               begin
               u := (t - 0.85) / 0.15;
               r := 255;
               g := Round(255 * (1 - u));
               end;
            end;
      end;

      // 32-bit LCL bitmaps on Windows are BGRA in memory, so the little-endian
      // LongWord is $00RRGGBB -- NOT a TColor, which is $00BBGGRR.  Writing a
      // TColor straight in swaps red and blue, which is obvious the moment you
      // look at a heat map, and is why the bench writes a PNG.
      FLUT[i] := (LongWord(Clamp255(r)) shl 16) or
                 (LongWord(Clamp255(g)) shl 8) or
                  LongWord(Clamp255(b));
      end;
end;

// ---------------------------------------------------------------------------
// Shared measurement helpers -- one definition, so the trace and the waterfall
// cannot drift apart.
// ---------------------------------------------------------------------------

procedure TfrmPanadapter.DisplayRange(out AMinDb, ARangeDb: Single);
begin
   // The K4's model: reference at the bottom, scale upward.  The reference is
   // the frame's own noise floor (AutoRef makes #REF equal it), less a margin
   // so noise texture below the floor stays visible.
   AMinDb := FRenderNoiseDb - REF_MARGIN_DB;
   ARangeDb := FScaleDb;
end;

function TfrmPanadapter.PeakForPixel(AX: Integer; ABinsPerPixel: Double): Single;
var
   first, last, i: Integer;
begin
   first := Trunc(AX * ABinsPerPixel);
   last := Trunc((AX + 1) * ABinsPerPixel) - 1;

   if last < first then
      begin
      last := first;
      end;

   if first > High(FRenderBins) then
      begin
      first := High(FRenderBins);
      end;

   if last > High(FRenderBins) then
      begin
      last := High(FRenderBins);
      end;

   Result := FRenderBins[first];

   for i := first + 1 to last do
      begin
      if FRenderBins[i] > Result then
         begin
         Result := FRenderBins[i];
         end;
      end;
end;

// ---------------------------------------------------------------------------
// Waterfall
// ---------------------------------------------------------------------------

procedure TfrmPanadapter.EnsureWaterfall(AWidth, AHeight: Integer);
var
   i: Integer;
begin
   if (AWidth <= 0) or (AHeight <= 0) then
      begin
      Exit;
      end;

   if (FWaterfall <> nil) and (FWfW = AWidth) and (FWfH = AHeight) then
      begin
      Exit;
      end;

   // A resize discards the history.  Rescaling old rows horizontally would be
   // inventing data that was never measured at that resolution.
   FreeAndNil(FWaterfall);
   FWaterfall := TBitmap.Create;
   FWaterfall.PixelFormat := pf32bit;
   FWaterfall.SetSize(AWidth, AHeight);

   // SetSize does not define the contents, and a 32-bit bitmap's padding bytes
   // are never written by the render loop.  Clearing once here means an
   // unwritten pixel can only ever be black, not whatever the allocator left.
   FWaterfall.Canvas.Brush.Color := clBlack;
   FWaterfall.Canvas.Brush.Style := bsSolid;
   FWaterfall.Canvas.FillRect(0, 0, AWidth, AHeight);

   FWfW := AWidth;
   FWfH := AHeight;
   SetLength(FWfDb, FWfW * FWfH);

   for i := 0 to High(FWfDb) do
      begin
      FWfDb[i] := WF_EMPTY_DB;
      end;

   FWfDirty := True;
end;

// The one place a stored dB value becomes a colour, so the incremental row and
// the full re-render cannot disagree about what a level looks like.
function TfrmPanadapter.WaterfallColor(ARelDb: Single): LongWord;
var
   n: Single;
begin
   // The history is dB ABOVE ITS OWN REFERENCE (see PushWaterfallRow), so the
   // bottom of the scale is the margin below zero and no absolute reference is
   // involved -- which is what stops old rows re-colouring when the radio's
   // noise floor moves.
   n := (ARelDb + REF_MARGIN_DB) / FScaleDb;

   if n < 0 then
      begin
      n := 0;
      end;

   if n > 1 then
      begin
      n := 1;
      end;

   Result := FLUT[Round(n * 255)];
end;

procedure TfrmPanadapter.PushWaterfallRow(ABinsPerPixel: Double);
var
   x, y: Integer;
   bytesPerLine: Integer;
   row: PLongWordArray;
   started: QWord;
begin
   if (FWfW <= 0) or (FWfH <= 0) then
      begin
      Exit;
      end;

   // Scroll the dB history down one row.  One Move, not a per-row loop: the
   // rows are contiguous.
   if FWfH > 1 then
      begin
      Move(FWfDb[0], FWfDb[FWfW], (FWfH - 1) * FWfW * SizeOf(Single));
      end;

   // ONE NEW ROW, not a full repaint.
   //
   // The first version set a dirty flag here and let the paint path re-colour
   // all ~116,000 pixels, twelve times a second -- for a display in which
   // exactly one row had changed.  The dB history exists so that a PALETTE OR
   // SCALE change can re-render everything; it was never a reason to do that on
   // every frame.  The bitmap now scrolls (one memcpy) and only the new top row
   // is coloured: 700 lookups instead of 116,000.
   //
   // HONEST PROVENANCE.  This was written while chasing a report that the
   // display lagged the VFO knob, and it did NOT fix that -- the cause turned
   // out to be the radio's tuning step, set finer on that band, so the knob
   // really was changing frequency more slowly (NY4I, 2026-08-25).  The change
   // is kept because doing 116,000 recolours to update one row is wasteful on
   // its own terms, not because it cured anything.

   // STORED RELATIVE TO THIS FRAME'S OWN REFERENCE, not as absolute dB.
   //
   // The absolute version looked right until the operator changed band: the
   // render scales every row by the NEWEST frame's noise floor, so a floor that
   // moves 25 dB re-colours the whole history at once and minutes-old rows
   // suddenly turn green.  Seen on the bench moving from 20 m to 6 m.
   //
   // "How far above the floor this was, when it was measured" is both stable
   // over time and still fully re-renderable when the palette or scale changes,
   // which is the property the dB history exists for.
   for x := 0 to FWfW - 1 do
      begin
      FWfDb[x] := PeakForPixel(x, ABinsPerPixel) - FRenderNoiseDb;
      end;

   if FWaterfall = nil then
      begin
      Exit;
      end;

   started := GetTickCount64;
   FWaterfall.BeginUpdate;

   try
      bytesPerLine := FWaterfall.RawImage.Description.BytesPerLine;

      // Scroll the pixels down to match the history.  Bottom-up so a row is
      // never overwritten before it has been copied.
      for y := FWfH - 1 downto 1 do
         begin
         Move(PByte(FWaterfall.ScanLine[y - 1])^,
              PByte(FWaterfall.ScanLine[y])^, bytesPerLine);
         end;

      row := PLongWordArray(FWaterfall.ScanLine[0]);

      for x := 0 to FWfW - 1 do
         begin
         row^[x] := WaterfallColor(FWfDb[x]);
         end;
   finally
      FWaterfall.EndUpdate;
   end;

   Inc(FRowsPushed);
   Inc(FMsInRows, Int64(GetTickCount64 - started));
end;

procedure TfrmPanadapter.RenderWaterfall;
var
   x, y: Integer;
   row: PLongWordArray;
begin
   if (FWaterfall = nil) or (FWfW <= 0) or (FWfH <= 0) then
      begin
      Exit;
      end;

   // THE EXPENSIVE PATH, and it runs only when the palette or the scale
   // changes -- never per frame.  That is the whole point of keeping the
   // history as dB: those two changes re-colour every row consistently, with
   // no seam between what was recorded before and after.
   FWaterfall.BeginUpdate;

   try
      for y := 0 to FWfH - 1 do
         begin
         row := PLongWordArray(FWaterfall.ScanLine[y]);

         for x := 0 to FWfW - 1 do
            begin
            row^[x] := WaterfallColor(FWfDb[(y * FWfW) + x]);
            end;
         end;
   finally
      FWaterfall.EndUpdate;
   end;

   FWfDirty := False;
end;

// ---------------------------------------------------------------------------
// MAIN THREAD from here down
// ---------------------------------------------------------------------------

procedure TfrmPanadapter.HandleRefreshTimer(Sender: TObject);
var
   fresh: Boolean;
   w, specH, wfH, wfTop, axisTop: Integer;
begin
   fresh := False;
   FLock.Acquire;

   try
      if FShareDirty then
         begin
         FShareDirty := False;
         fresh := True;

         FRenderCentreHz := FShareCentreHz;
         FRenderSpanHz := FShareSpanHz;
         FRenderNoiseDb := FShareNoiseDb;

         if Length(FRenderBins) <> Length(FShareBins) then
            begin
            SetLength(FRenderBins, Length(FShareBins));
            end;

         if Length(FShareBins) > 0 then
            begin
            Move(FShareBins[0], FRenderBins[0], Length(FShareBins) * SizeOf(Single));
            end;
         end;
   finally
      FLock.Release;
   end;

   // Labels track the link even when no frame arrived -- that is how a radio
   // that has gone away becomes visible rather than the display just freezing.
   UpdateLabels;

   if not fresh then
      begin
      Exit;
      end;

   FHaveRender := True;

   if FPaused then
      begin
      // Paused freezes the DISPLAY, not the stream: frames keep arriving and
      // the newest is kept, so resuming shows current data rather than
      // replaying a backlog.
      Exit;
      end;

   w := pbSpectrum.Width;
   PlotLayout(specH, axisTop, wfTop, wfH);

   if (w > 0) and (wfH > 0) and (Length(FRenderBins) > 0) then
      begin
      EnsureWaterfall(w, wfH);
      PushWaterfallRow(Length(FRenderBins) / w);
      end;

   pbSpectrum.Invalidate;
end;

function TfrmPanadapter.FormatMHz(AHz: Int64): string;
begin
   Result := FormatFloat('0.000', AHz / 1000000.0) + ' MHz';
end;

// Where the trace, the waterfall and the frequency scale each live.  ONE
// definition, used by both the paint path and the timer -- when the timer sized
// the waterfall with its own copy of this arithmetic, the two could disagree
// about how tall the bitmap was.
procedure TfrmPanadapter.PlotLayout(out ASpecH, AAxisTop, AWfTop, AWfH: Integer);
var
   plotH: Integer;
begin
   plotH := pbSpectrum.Height - AXIS_HEIGHT;

   if plotH < 0 then
      begin
      plotH := 0;
      end;

   AWfH := Round(plotH * WATERFALL_FRACTION);
   ASpecH := plotH - AWfH;

   { THE SCALE SITS BETWEEN THE TWO, which is where the K4 puts it (NY4I,
     2026-08-26).  It reads as a shared axis that both halves hang off, rather
     than as a caption under the whole picture -- and the numbers end up next to
     the trace, which is what an operator is reading them against.

     It used to be at the very bottom, below the waterfall. }
   AAxisTop := ASpecH;
   AWfTop := ASpecH + AXIS_HEIGHT;
end;

// Enough decimals to tell one tick from the next, and no more: at a 3 kHz span
// the ticks are 500 Hz apart and '50.259' would print the same number five
// times.
function TfrmPanadapter.FormatAxis(AHz, AStepHz: Int64): string;
var
   decimals: Integer;
begin
   if AStepHz >= 1000000 then
      begin
      decimals := 0;
      end
   else if AStepHz >= 100000 then
      begin
      decimals := 1;
      end
   else if AStepHz >= 10000 then
      begin
      decimals := 2;
      end
   else if AStepHz >= 1000 then
      begin
      decimals := 3;
      end
   else if AStepHz >= 100 then
      begin
      decimals := 4;
      end
   else
      begin
      decimals := 5;
      end;

   { NEVER FEWER THAN THREE.  A step of 10 kHz gives two by the rule above, so
     the band read 7.04, 7.05 while the K4 beside it read 7.040, 7.050 -- and a
     kHz digit is the one an operator is actually tuning by (NY4I, 2026-08-26).
     Wider steps still get three, which is what the K4 shows on a full band. }
   if decimals < 3 then
      begin
      decimals := 3;
      end;

   if decimals = 0 then
      begin
      Result := FormatFloat('0', AHz / 1000000.0);
      end
   else
      begin
      Result := FormatFloat('0.' + StringOfChar('0', decimals), AHz / 1000000.0);
      end;
end;

{ THE VERTICAL SCALE, and the horizontal grid it labels.

  dB, NOT dBm, and that is deliberate.  The K4's own display says dBm; the
  numbers IN THE PACKET are not those numbers.  Measured over 902 packets
  (docs/PANADAPTER_LCL_DESIGN.md 1.1): pan A runs -150.0..-106.6 dB with its
  floor near -126, while the 3 kHz mini-pan Y runs -2.0..+19.4 with a floor near
  zero -- the same radio, the same field, scales 150 dB apart.  Printing "dBm"
  against that would claim a calibration this stream does not carry.

  The scale is anchored to the FRAME'S OWN noise floor (DisplayRange), so the
  numbers move with the reference rather than being absolute.  That is what
  makes one display work for both pans. }
{ WHERE THE WINDOW WAS LEFT.  Keyed by NAME in settings\tr4w.json, the same way
  the band plan does it -- this is not a tw_ window, so it has no entry in
  tr4w_WindowsArray and FindAndSaveRectOfAllWindows never sees it.  NY4I: "the
  position of the panadapter window is not being saved."

  Making it a tw_ window would give position, the Windows menu and the
  accelerator in one move, but a tw_ window's caption is read back from its MENU
  ITEM -- so that route is blocked behind the I18N work, and this is not. }
{ ONE KEY PER SLOT.  Two windows sharing 'Panadapter' would each overwrite the
  other's row on close, and whichever closed last would win. }
function TfrmPanadapter.LayoutName: string;
begin
   Result := SysUtils.Format('Panadapter%d', [FSlot]);
end;

procedure TfrmPanadapter.RestoreBounds;
var
   store: TWindowLayoutStore;
   saved, desktop, overlap: TRect;
   visible: boolean;
begin
   store := TWindowLayoutStore.Create;
   try
      if not LoadWindowLayout(TR4WConfigFileName, store) then
         begin
         Exit;
         end;

      { LEGACY KEY.  Before 2026-08-26 there was one panadapter and one row,
        'Panadapter'.  Slot 1 inherits it rather than silently losing the
        operator's saved position on the upgrade. }
      if not store.TryGetLayout(LayoutName, saved, visible) then
         begin
         if (FSlot <> 1) or (not store.TryGetLayout('Panadapter', saved, visible)) then
            begin
            Exit;
            end;
         end;

      // A monitor that is no longer attached leaves a well-formed rect that
      // puts the window where nobody can reach it.  Any overlap with the
      // virtual desktop is enough; Windows nudges a partly-off window back.
      desktop := Rect(Screen.DesktopLeft, Screen.DesktopTop,
                      Screen.DesktopLeft + Screen.DesktopWidth,
                      Screen.DesktopTop  + Screen.DesktopHeight);

      if not IntersectRect(overlap, saved, desktop) then
         begin
         Exit;
         end;

      // poDesigned FIRST, or the LCL re-applies its own rule when the form is
      // shown and throws the restored position away.
      Position := poDesigned;
      SetBounds(saved.Left, saved.Top,
                saved.Right - saved.Left, saved.Bottom - saved.Top);
   finally
      store.Free;
   end;
end;

{ THE LIVE RECTANGLE, in the LCL's own units.  Left/Top/Width/Height, never
  GetWindowRect -- mixing the two is what made the function-key window grow by
  its frame height on every restart (2026-08-25). }
function TfrmPanadapter.LiveBounds: TRect;
begin
   Result := Rect(Left, Top, Left + Width, Top + Height);
end;

function TfrmPanadapter.LayoutDiffersFromDisk: boolean;
begin
   Result := (not FHaveSaved)
             or (FSavedVisible <> Visible)
             or (not EqualRect(FSavedBounds, LiveBounds));
end;

procedure TfrmPanadapter.SaveCurrentBounds(const aVisible: boolean);
var
   store: TWindowLayoutStore;
begin
   // Minimised or maximised bounds are not what to restore.
   if WindowState <> wsNormal then
      begin
      Exit;
      end;

   store := TWindowLayoutStore.Create;
   try
      // SetLayout on an EMPTY store: SaveWindowLayout re-reads the file and
      // overlays these entries, so every other window's row survives without
      // this one having to know they exist.
      store.SetLayout(LayoutName, LiveBounds, aVisible);
      SaveWindowLayout(TR4WConfigFileName, store);

      FSavedBounds := LiveBounds;
      FSavedVisible := aVisible;
      FHaveSaved := True;
   finally
      store.Free;
   end;
end;

{ SPAN STEPPING: THE WINDOW ASKS FOR A DETENT, THE RADIO DECIDES WHAT ONE IS.

  This used to hold the rule itself -- one kHz per press, the way QK4 steps a
  K4 (NY4I: "in qk4, pressing + increases the K4 span by 1", a fine trim rather
  than a zoom).  That was right while the K4 was the only spectrum radio and is
  wrong now, because the two families differ in KIND and not merely in step
  size:

    * the K4 accepts any span in Hz and CLAMPS what it cannot do, so a kHz at a
      time is meaningful and the rig reports back what it settled on;
    * a network Icom offers EIGHT discrete spans and SNAPS a request to the
      nearest.  A 1 kHz step never crosses the midpoint of a gap, so the rig
      snaps straight back to where it was and the button is INERT -- at every
      span, in the widening direction.  AetherSDR measured exactly that: zoom
      out dead at all eight spans, zoom in working at seven, an asymmetry that
      reads as "zoom is broken" rather than "zoom is quantised", and which no
      amount of clicking can escape.

  So the rule moved onto TFactoryRadioBase.StepSpectrumSpan.  A per-radio STEP
  SIZE would not have been enough: it cannot express snapping, and a window
  that chose between the two would be asking which radio it has.

  WHAT STAYS HERE is the part that belongs to the window: telling the operator
  why a press did nothing.  Both buttons used to Exit in silence, which is
  indistinguishable from a dead control -- the reason was findable only by
  grepping the CAT log for a command never sent. }
procedure TfrmPanadapter.StepSpan(const aWider: boolean);
var
   current: Integer;
   direction: Integer;
begin
   { A BUTTON THAT DOES NOTHING MUST SAY WHY. }
   if FRadio = nil then
      begin
      lblSpan.Caption := 'Span: no radio';
      Exit;
      end;

   { FROM THE RADIO'S OWN SETTING, not the drawn width.  They are different
     numbers: the frame reported 384 kHz while the radio reported 368 kHz for
     the same moment, so stepping from the frame asked for a value derived from
     something the radio never had -- and the result looked random.

     NY4I: "it seems like you should read the span from the radio and set your
     initial span to that value."  Each driver's StartSpectrum asks the rig at
     connect and keeps the value current from the radio's own pushes.

     ASKED HERE ONLY TO REPORT A FAILURE.  The step itself reads the same value
     inside the radio object; this window needs it solely to distinguish "the
     rig has not told us yet" from a press that really did go out. }
   current := FRadio.SpectrumSpanHz;

   if current <= 0 then
      begin
      lblSpan.Caption := 'Span: radio has not reported one';
      Exit;
      end;

   if aWider then
      begin
      direction := 1;
      end
   else
      begin
      direction := -1;
      end;

   FRadio.StepSpectrumSpan(direction);
end;

procedure TfrmPanadapter.HandleSpanNarrow(Sender: TObject);
begin
   StepSpan(False);
end;

procedure TfrmPanadapter.HandleSpanWide(Sender: TObject);
begin
   StepSpan(True);
end;

{ What the RADIO is sending, not what was asked for -- see StepSpan. }
procedure TfrmPanadapter.ShowSpan;
var
   frame: TSpectrumFrame;
begin
   { THE RADIO'S SETTING WHEN IT HAS GIVEN ONE, because that is what the buttons
     act on -- a readout showing the drawn width while the buttons stepped
     something else is how the last round of confusion started. }
   if (FRadio <> nil) and (FRadio.SpectrumSpanHz > 0) then
      begin
      lblSpan.Caption := Format('Span %.0f kHz', [FRadio.SpectrumSpanHz / 1000.0]);
      Exit;
      end;

   frame := RenderFrame;

   if frame.SpanHz <= 0 then
      begin
      lblSpan.Caption := 'Span --';
      Exit;
      end;

   if frame.SpanHz >= 1000 then
      begin
      lblSpan.Caption := Format('Span %.0f kHz', [frame.SpanHz / 1000.0]);
      end
   else
      begin
      lblSpan.Caption := Format('Span %d Hz', [frame.SpanHz]);
      end;
end;

procedure TfrmPanadapter.DrawDbScale(ACanvas: TCanvas;
                                     AWidth, ASpecH: Integer;
                                     AMinDb, ARangeDb: Single);
const
   DB_STEP = 10;
var
   db, y: Integer;
begin
   if (ASpecH <= 0) or (ARangeDb <= 0) or (AWidth <= 0) then
      begin
      Exit;
      end;

   // The first multiple of the step at or above the bottom of the range.
   db := Ceil(AMinDb / DB_STEP) * DB_STEP;

   ACanvas.Brush.Style := bsClear;

   while db <= (AMinDb + ARangeDb) do
      begin
      y := ASpecH - Round(((db - AMinDb) / ARangeDb) * ASpecH);

      if (y >= 0) and (y < ASpecH) then
         begin
         ACanvas.Pen.Color := GRID_COLOR;
         ACanvas.Line(0, y, AWidth, y);

         ACanvas.Font.Color := AXIS_COLOR;
         ACanvas.TextOut(2, y + 1, IntToStr(db) + ' dB');
         end;

      Inc(db, DB_STEP);
      end;
end;

procedure TfrmPanadapter.DrawAxis(ACanvas: TCanvas; AWidth, AAxisTop: Integer);
var
   frame: TSpectrumFrame;
   startHz, endHz, step, f: Int64;
   slots: Integer;
   x, labelX, tw: Integer;
   caption: string;
   magnitude, normalised: Double;
begin
   frame := RenderFrame;

   if (frame.SpanHz <= 0) or (AWidth <= 0) then
      begin
      Exit;
      end;

   startHz := SpectrumStartHz(frame);
   endHz := SpectrumEndHz(frame);

   // As many labels as fit, never fewer than two.
   slots := AWidth div AXIS_LABEL_PX;

   if slots < 2 then
      begin
      slots := 2;
      end;

   // A ROUND step -- 1, 2 or 5 times a power of ten.  Dividing the span into
   // equal fractions would give ticks like 50.2513 MHz; an operator navigates
   // by landmarks, so the labels have to be numbers worth reading.
   magnitude := Power(10, Floor(Log10(frame.SpanHz / slots)));
   normalised := (frame.SpanHz / slots) / magnitude;

   if normalised <= 1 then
      begin
      step := Round(magnitude);
      end
   else if normalised <= 2 then
      begin
      step := Round(2 * magnitude);
      end
   else if normalised <= 5 then
      begin
      step := Round(5 * magnitude);
      end
   else
      begin
      step := Round(10 * magnitude);
      end;

   if step <= 0 then
      begin
      Exit;
      end;

   // First multiple of the step at or after the left edge.
   f := (startHz div step) * step;

   if f < startHz then
      begin
      Inc(f, step);
      end;

   ACanvas.Font.Color := AXIS_COLOR;
   ACanvas.Brush.Style := bsClear;

   while f <= endHz do
      begin
      x := Round(((f - startHz) / frame.SpanHz) * AWidth);

      { THE GRID LINE FIRST, then the tick.  It runs UP through the trace from
        the scale, so a peak can be read against a frequency without counting
        pixels -- the K4 draws the same lines.  Not over the waterfall: that is
        picture, and a grid across it hides the very detail it is there for. }
      if AAxisTop > 0 then
         begin
         ACanvas.Pen.Color := GRID_COLOR;
         ACanvas.Line(x, 0, x, AAxisTop);
         end;

      ACanvas.Pen.Color := AXIS_TICK_COLOR;
      ACanvas.Line(x, AAxisTop, x, AAxisTop + 4);

      caption := FormatAxis(f, step);
      tw := ACanvas.TextWidth(caption);
      labelX := x - (tw div 2);

      // Nudge the end labels inside rather than letting them hang half off the
      // window, which is what a plain centred label does at both edges.
      if labelX < 2 then
         begin
         labelX := 2;
         end;

      if (labelX + tw) > (AWidth - 2) then
         begin
         labelX := AWidth - 2 - tw;
         end;

      ACanvas.TextOut(labelX, AAxisTop + 5, caption);
      Inc(f, step);
      end;
end;

// The inverse of FreqAtPixel.  Both go through the same frame, so a marker
// drawn at a frequency and a click read back from that pixel agree.
function TfrmPanadapter.PixelForFreq(AHz: Int64; AWidth: Integer): Integer;
var
   frame: TSpectrumFrame;
begin
   Result := -1;
   frame := RenderFrame;

   if (frame.SpanHz <= 0) or (AWidth <= 0) then
      begin
      Exit;
      end;

   Result := Round(((AHz - SpectrumStartHz(frame)) / frame.SpanHz) * AWidth);
end;

{ Where a VFO is actually LISTENING, or 0 if that is not known.

  BOTH VFOs ON ONE DISPLAY (NY4I, 2026-08-25), which is how QK4 works: pan A
  carries VFO A as its primary and VFO B as a secondary overlay
  (spectrumcontroller.cpp setSecondaryVfo).  Two windows would make the operator
  compare two pictures to see a split; one window shows the split.

  Needs the CAT link -- the spectrum stream carries the pan's centre, not where
  each VFO is tuned -- so this returns 0 and nothing is drawn when the frequency
  is unknown.  For a panadapter opened with no CAT connection that is the normal
  state, not an error.

  One function, because the passband and the marker must agree about where the
  VFO is; two copies of the RIT rule would eventually disagree. }
function TfrmPanadapter.VfoDisplayHz(AVfo: TVFO): Int64;
begin
   Result := 0;

   if FRadio = nil then
      begin
      Exit;
      end;

   Result := FRadio.frequency[AVfo];

   if Result <= 0 then
      begin
      Result := 0;
      Exit;
      end;

   // RIT moves where the receiver is listening, which is what this marker
   // claims to show.  QK4 applies it the same way.
   if FRadio.IsRITOn[AVfo] then
      begin
      Result := Result + FRadio.RITOffset[AVfo];
      end;
end;

// UNDER the trace: this fills, so anything drawn before it would be erased.
procedure TfrmPanadapter.DrawVfoPassband(ACanvas: TCanvas; AVfo: TVFO;
                                         APassband: TColor;
                                         AWidth, ASpecH: Integer);
var
   hz: Int64;
   bandwidth: Integer;
   x1, x2: Integer;
begin
   hz := VfoDisplayHz(AVfo);

   if (hz <= 0) or (ASpecH <= 0) or (FRadio = nil) then
      begin
      Exit;
      end;

   bandwidth := FRadio.filter[AVfo];

   // Outside this range it is not a receive filter, and drawing a passband from
   // it would paint most of the window.
   if (bandwidth < MIN_FILTER_HZ) or (bandwidth > MAX_FILTER_HZ) then
      begin
      Exit;
      end;

   x1 := PixelForFreq(hz - (bandwidth div 2), AWidth);
   x2 := PixelForFreq(hz + (bandwidth div 2), AWidth);

   // At a wide span a narrow CW filter is under a pixel wide; widen it to one
   // rather than let it silently vanish.
   if x2 <= x1 then
      begin
      x2 := x1 + 1;
      end;

   ACanvas.Brush.Color := APassband;
   ACanvas.Brush.Style := bsSolid;
   ACanvas.FillRect(x1, 0, x2, ASpecH);
end;

// OVER the trace, and running the full height so a signal can be lined up
// against it in the waterfall as well.
procedure TfrmPanadapter.DrawVfoMarker(ACanvas: TCanvas; AVfo: TVFO;
                                       AColor: TColor; const ATag: string;
                                       AWidth, AAxisTop: Integer);
var
   hz: Int64;
   x: Integer;
begin
   hz := VfoDisplayHz(AVfo);

   if hz <= 0 then
      begin
      Exit;
      end;

   x := PixelForFreq(hz, AWidth);

   if (x < 0) or (x >= AWidth) then
      begin
      Exit;                       // this VFO is off the displayed span
      end;

   ACanvas.Pen.Color := AColor;
   ACanvas.Line(x, 0, x, AAxisTop);

   ACanvas.Font.Color := AColor;
   ACanvas.Brush.Style := bsClear;
   ACanvas.TextOut(x + 3, 2, ATag);
end;

{ DX spot callsigns across the top of the spectrum.

  Asked for through uPanadapterView, so this window still knows nothing about
  contests, multipliers or the spot store -- only how to draw what it is given.
  No provider installed is the normal state, not an error.

  STAGGERED OVER A FEW ROWS, because in a pile-up the callsigns collide: on a
  busy 20 m evening a dozen spots can land inside one screen width, and
  overlapping text is worse than no text.  A label goes in the first row where
  it fits; when every row is taken at that x, it is DROPPED rather than drawn on
  top of another. }
procedure TfrmPanadapter.DrawSpots(ACanvas: TCanvas; AWidth, ASpecH: Integer);
var
   frame: TSpectrumFrame;
   spots: TSpectrumSpots;
   i, r, x, labelX, tw, y: Integer;
   rowEnd: array[0..SPOT_ROWS - 1] of Integer;
   placed: Boolean;
begin
   if not PanadapterSpotsAvailable then
      begin
      Exit;
      end;

   frame := RenderFrame;

   if (frame.SpanHz <= 0) or (AWidth <= 0) or (ASpecH <= 0) then
      begin
      Exit;
      end;

   spots := PanadapterSpots(SpectrumStartHz(frame), SpectrumEndHz(frame));

   if Length(spots) = 0 then
      begin
      Exit;
      end;

   for r := 0 to SPOT_ROWS - 1 do
      begin
      rowEnd[r] := -1;
      end;

   ACanvas.Brush.Style := bsClear;

   for i := 0 to High(spots) do
      begin
      x := PixelForFreq(spots[i].FreqHz, AWidth);

      if (x < 0) or (x >= AWidth) then
         begin
         Continue;
         end;

      if spots[i].IsDupe then
         begin
         ACanvas.Font.Color := SPOT_DUPE_COLOR;
         end
      else if spots[i].IsMultiplier then
         begin
         ACanvas.Font.Color := SPOT_MULT_COLOR;
         end
      else
         begin
         ACanvas.Font.Color := SPOT_COLOR;
         end;

      tw := ACanvas.TextWidth(spots[i].Callsign);
      labelX := x + 3;

      // Keep the label on screen; a callsign half off the right edge is
      // unreadable exactly when it matters.
      if (labelX + tw) > (AWidth - 2) then
         begin
         labelX := x - tw - 3;
         end;

      placed := False;

      for r := 0 to SPOT_ROWS - 1 do
         begin
         if labelX > rowEnd[r] then
            begin
            y := SPOT_TOP + (r * SPOT_ROW_HEIGHT);

            // A tick from the callsign down to the trace, so which signal it
            // refers to is unambiguous once labels are staggered.
            ACanvas.Pen.Color := SPOT_TICK_COLOR;
            ACanvas.Line(x, y + SPOT_ROW_HEIGHT - 2, x, ASpecH);

            ACanvas.TextOut(labelX, y, spots[i].Callsign);
            rowEnd[r] := labelX + tw + 6;
            placed := True;
            Break;
            end;
         end;

      // Every row already occupied at this x: drop it.  Drawing it anyway would
      // overlap a callsign that is already there and make both unreadable.
      if not placed then
         begin
         Continue;
         end;
      end;
end;

// The frame the display is currently showing, as a TSpectrumFrame, so the axis
// labels, the cursor readout and click-to-tune all go through the SAME
// frequency helpers.  If they each did their own arithmetic, the operator would
// click a signal and land somewhere the labels disagreed with.
function TfrmPanadapter.RenderFrame: TSpectrumFrame;
begin
   Result := Default(TSpectrumFrame);
   Result.CentreHz := FRenderCentreHz;
   Result.SpanHz := FRenderSpanHz;
   Result.BinCount := Length(FRenderBins);
end;

function TfrmPanadapter.FreqAtPixel(AX: Integer): Int64;
var
   frame: TSpectrumFrame;
   bin: Integer;
   w: Integer;
begin
   Result := 0;
   frame := RenderFrame;
   w := pbSpectrum.Width;

   if (frame.BinCount <= 0) or (w <= 0) then
      begin
      Exit;
      end;

   // Through the bin, not straight from the pixel: the trace is drawn per bin,
   // so this is the frequency of the data actually under the cursor.
   bin := Trunc(AX * (frame.BinCount / w));

   if bin < 0 then
      begin
      bin := 0;
      end;

   if bin > frame.BinCount - 1 then
      begin
      bin := frame.BinCount - 1;
      end;

   Result := SpectrumBinHz(frame, bin);
end;

procedure TfrmPanadapter.UpdateLabels;
begin
   { The span the frames are actually carrying -- refreshed with the rest of the
     labels, so a change made at the RIG'S front panel shows here too and not
     only one made with the buttons. }
   ShowSpan;

   if FRadio = nil then
      begin
      lblStatus.Caption := 'No radio';
      lblStatus.Font.Color := clGray;
      Exit;
      end;

   if FRadio.SpectrumLinkUp then
      begin
      lblStatus.Caption := 'Connected';
      lblStatus.Font.Color := clLime;
      end
   else if FRadio.SpectrumStreaming then
      begin
      // Streaming but no link: connecting, or backing off after a failure.
      // Distinct on purpose -- collapsing the two would show a switched-off
      // radio as connected.
      lblStatus.Caption := 'Connecting...';
      lblStatus.Font.Color := clYellow;
      end
   else
      begin
      lblStatus.Caption := 'Stopped';
      lblStatus.Font.Color := clGray;
      end;

   // The frequency axis is DRAWN, not laid out in labels -- see DrawAxis.
end;

procedure TfrmPanadapter.HandleSpectrumPaint(Sender: TObject);
var
   cv: TCanvas;
   w, h, specH, wfH: Integer;
   x, y, centreX, axisTop, wfTop: Integer;
   peak: Single;
   minDb, rangeDb: Single;
   binsPerPixel: Double;
   readout: string;
   tw: Integer;
   started: QWord;
begin
   started := GetTickCount64;
   cv := pbSpectrum.Canvas;
   w := pbSpectrum.Width;
   h := pbSpectrum.Height;

   cv.Brush.Color := clBlack;
   cv.Brush.Style := bsSolid;
   cv.FillRect(0, 0, w, h);

   Inc(FPaints);

   if (w <= 0) or (h <= 0) then
      begin
      Exit;
      end;

   if (not FHaveRender) or (Length(FRenderBins) = 0) then
      begin
      cv.Font.Color := clGray;
      cv.Brush.Style := bsClear;
      cv.TextOut(8, 8, 'Waiting for spectrum data...');
      Exit;
      end;

   PlotLayout(specH, axisTop, wfTop, wfH);
   DrawAxis(cv, w, axisTop);

   DisplayRange(minDb, rangeDb);

   if rangeDb <= 0 then
      begin
      Exit;
      end;

   // Behind the trace and the markers: a grid drawn over them would compete
   // with the data it exists to measure.
   DrawDbScale(cv, w, specH, minDb, rangeDb);

   // ---- waterfall, below the trace ------------------------------------
   // Just a blit.  The bitmap is kept current by PushWaterfallRow (one row) and
   // by RenderWaterfall (palette/scale changes only), so paint does no
   // per-pixel work at all.
   if (FWaterfall <> nil) and (wfH > 0) then
      begin
      cv.Draw(0, wfTop, FWaterfall);
      end;

   if specH <= 0 then
      begin
      Exit;
      end;

   // ---- spectrum trace --------------------------------------------------
   // The one dB value on screen the radio itself reported, so it is worth
   // being able to see.
   y := specH - Round(((FRenderNoiseDb - minDb) / rangeDb) * specH);

   if (y >= 0) and (y < specH) then
      begin
      cv.Pen.Color := GRID_COLOR;
      cv.Line(0, y, w, y);
      end;

   // Pan centre.  Dim, because with both VFO markers drawn it is the least
   // interesting vertical line on the display -- but still worth having, since
   // in fixed-tune mode the centre is NOT where either VFO is.
   centreX := w div 2;
   cv.Pen.Color := CENTRE_COLOR;
   cv.Line(centreX, 0, centreX, specH);

   // Passbands go down BEFORE the trace, so the trace draws over them.
   DrawVfoPassband(cv, nrVFOA, VFOA_PASSBAND, w, specH);
   DrawVfoPassband(cv, nrVFOB, VFOB_PASSBAND, w, specH);

   cv.Pen.Color := TRACE_COLOR;
   binsPerPixel := Length(FRenderBins) / w;

   for x := 0 to w - 1 do
      begin
      peak := PeakForPixel(x, binsPerPixel);
      y := specH - Round(((peak - minDb) / rangeDb) * specH);

      if y < 0 then
         begin
         y := 0;
         end;

      if y > specH - 1 then
         begin
         y := specH - 1;
         end;

      if x = 0 then
         begin
         cv.MoveTo(x, y);
         end
      else
         begin
         cv.LineTo(x, y);
         end;
      end;

   DrawSpots(cv, w, specH);

   // ---- VFO markers, OVER the trace -------------------------------------
   { THE FULL PICTURE, not just to the scale.  A VFO marker that stopped at the
     axis would leave the waterfall -- the half showing where a signal has BEEN
     -- with no reference line at all. }
   DrawVfoMarker(cv, nrVFOA, VFOA_COLOR, 'A', w, wfTop + wfH);
   DrawVfoMarker(cv, nrVFOB, VFOB_COLOR, 'B', w, wfTop + wfH);

   // ---- cursor and readout ----------------------------------------------
   // Drawn rather than made a control: a label would need layout space in a
   // window whose whole point is the picture, and the line has to cross both
   // the trace and the waterfall to be useful.
   if (FCursorX >= 0) and (FCursorX < w) then
      begin
      cv.Pen.Color := CURSOR_COLOR;
      cv.Line(FCursorX, 0, FCursorX, wfTop + wfH);

      readout := FormatMHz(FreqAtPixel(FCursorX)) + '    ' +
                 Format('%.0f dB', [PeakForPixel(FCursorX, binsPerPixel)]);

      cv.Font.Color := clWhite;
      cv.Brush.Style := bsClear;
      tw := cv.TextWidth(readout);

      // Away from the cursor, so the text never sits on top of the line it is
      // describing.
      if FCursorX > (w - tw - 20) then
         begin
         cv.TextOut(8, 4, readout);
         end
      else
         begin
         cv.TextOut(w - tw - 8, 4, readout);
         end;
      end;

   Inc(FMsInPaint, Int64(GetTickCount64 - started));
end;

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

procedure TfrmPanadapter.HandlePaletteChange(Sender: TObject);
begin
   if cboPalette.ItemIndex < 0 then
      begin
      Exit;
      end;

   FPalette := cboPalette.ItemIndex;
   BuildPalette;

   // The history is dB, not pixels, so the whole waterfall re-colours -- no
   // seam between the old palette and the new.  Re-rendered HERE rather than
   // flagged for the paint path: paint no longer does per-pixel work, so a flag
   // would simply never be acted on -- which showed up on the bench as a seam
   // exactly where the palette changed.
   RenderWaterfall;
   pbSpectrum.Invalidate;
end;

procedure TfrmPanadapter.HandlePauseClick(Sender: TObject);
begin
   FPaused := not FPaused;

   if FPaused then
      begin
      btnPause.Caption := 'Resume';
      end
   else
      begin
      btnPause.Caption := 'Pause';
      end;
end;

// ---------------------------------------------------------------------------
// Click to tune
// ---------------------------------------------------------------------------

procedure TfrmPanadapter.HandleSpectrumMouseDown(Sender: TObject; Button: TMouseButton;
                                                 Shift: TShiftState; X, Y: Integer);
var
   vfo: TVFO;
   rf, dial: Int64;
   rigMode: TRadioMode;
begin
   if (FRadio = nil) or (not FHaveRender) then
      begin
      Exit;
      end;

   // Left tunes VFO A, right tunes VFO B -- the convention TR4QT and QK4 both
   // use, and what an operator coming from either will expect.
   if Button = mbLeft then
      begin
      vfo := nrVFOA;
      end
   else if Button = mbRight then
      begin
      vfo := nrVFOB;
      end
   else
      begin
      Exit;
      end;

   rf := FreqAtPixel(X);

   if rf <= 0 then
      begin
      Exit;
      end;

   // The CW offset lives in uSpectrumTypes as a pure function, where it can be
   // unit-tested without a radio; all this does is translate the rig's mode
   // into the two flags it takes.
   rigMode := FRadio.mode[vfo];
   dial := SpectrumDialFrequency(rf, FCWPitchHz,
                                 rigMode = rmCW,
                                 rigMode = rmCWRev);

   // rmNone means TUNE ONLY.  TK4Radio.SetFrequency calls SetMode whenever the
   // mode is anything else, and a click on the panadapter is not a request to
   // change mode.
   FRadio.SetFrequency(LongInt(dial), vfo, rmNone);
end;

procedure TfrmPanadapter.HandleSpectrumMouseMove(Sender: TObject; Shift: TShiftState;
                                                 X, Y: Integer);
begin
   if FCursorX = X then
      begin
      Exit;                       // same column: nothing would change
      end;

   FCursorX := X;

   if FHaveRender then
      begin
      pbSpectrum.Invalidate;
      end;
end;

procedure TfrmPanadapter.HandleSpectrumMouseLeave(Sender: TObject);
begin
   if FCursorX < 0 then
      begin
      Exit;
      end;

   FCursorX := -1;
   pbSpectrum.Invalidate;
end;

procedure TfrmPanadapter.HandleScaleChange(Sender: TObject);
begin
   FScaleDb := trkScale.Position;

   if FScaleDb < MIN_SCALE_DB then
      begin
      FScaleDb := MIN_SCALE_DB;
      end;

   if FScaleDb > MAX_SCALE_DB then
      begin
      FScaleDb := MAX_SCALE_DB;
      end;

   lblScale.Caption := IntToStr(FScaleDb) + ' dB';

   // Same reason as the palette: the waterfall is stored as dB, so a scale
   // change re-renders the history at the new range instead of leaving rows
   // that mean something different from the trace above them.
   RenderWaterfall;
   pbSpectrum.Invalidate;
end;

// ---------------------------------------------------------------------------
// Open / close.  No handle, no window table, no SetWindowPos.
// ---------------------------------------------------------------------------

procedure ShowPanadapterWindow(const aSlot: integer;
                               ARadio: TFactoryRadioBase; const ASourceId: string;
                               const ACaption: string);
begin
   if not SlotIsValid(aSlot) then
      begin
      Exit;
      end;

   if GPanForms[aSlot] = nil then
      begin
      GPanForms[aSlot] := TfrmPanadapter.Create(nil);
      GPanForms[aSlot].FSlot := aSlot;   { before RestoreBounds -- it keys on it }

      // Parents through the LCL's PopupParent, NOT GWL_HWNDPARENT.  This is
      // the one helper in uLCLFormHelpers that is HWND-free;
      // ShowModalOverWin32Parent is not, and is not wanted here anyway --
      // the panadapter is modeless.
      OwnFormByMainWindow(GPanForms[aSlot]);
      end;

   { NAME THE RADIO, the way the radio panel does -- "Panadapter - Radio 1
     K4D-278".  On an SO2R station a bare "Panadapter" cannot say whose spectrum
     it is, which is the one thing the title has to answer (NY4I, 2026-08-26). }
   if ACaption <> '' then
      begin
      GPanForms[aSlot].Caption := 'Panadapter - ' + ACaption;
      end;

   GPanForms[aSlot].AttachRadio(ARadio, ASourceId);

   { BOUNDS BEFORE Show, and only the first time.  Reshowing must not drag the
     window back to where it was when TR4W started. }
   if not GPanForms[aSlot].FBoundsRestored then
      begin
      GPanForms[aSlot].FBoundsRestored := True;
      GPanForms[aSlot].RestoreBounds;
      end;

   GPanForms[aSlot].Show;
end;

procedure ClosePanadapterWindow(const aSlot: integer);
begin
   if PanadapterForm(aSlot) = nil then
      begin
      Exit;
      end;

   GPanForms[aSlot].Close;      // HandleClose detaches and hides
end;

function PanadapterWindowVisible(const aSlot: integer): Boolean;
begin
   Result := (PanadapterForm(aSlot) <> nil) and GPanForms[aSlot].Visible;
end;

procedure FreePanadapterWindow(const aSlot: integer);
begin
   if PanadapterForm(aSlot) = nil then
      begin
      Exit;
      end;

   FreeAndNil(GPanForms[aSlot]);
end;

{ ---------------------------------------------------- the layout seam --- }

{ ANY live window whose bounds or open state no longer match what was written.

  MainUnit's autosave already owns the cadence, the dirty check and the
  save-at-exit backstop for every tw_ window; this lets the panadapter ride
  the same tick instead of growing a second timer. }
function PanadapterLayoutChanged: boolean;
var
   slot: integer;
begin
   Result := False;
   for slot := Low(GPanForms) to High(GPanForms) do
      begin
      if (GPanForms[slot] <> nil) and GPanForms[slot].LayoutDiffersFromDisk then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

procedure SavePanadapterLayout;
var
   slot: integer;
begin
   for slot := Low(GPanForms) to High(GPanForms) do
      begin
      if GPanForms[slot] <> nil then
         begin
         { The LIVE visibility, so quitting with the window open records it as
           open -- which is the whole point.  Before this, bounds were written
           in HandleClose alone, so an operator who moved the window and then
           quit saved nothing at all (NY4I, 2026-08-26). }
         GPanForms[slot].SaveCurrentBounds(GPanForms[slot].Visible);
         end;
      end;
end;

function PanadapterWasOpen(const aSlot: integer): boolean;
var
   store: TWindowLayoutStore;
   saved: TRect;
   visible: boolean;
begin
   Result := False;
   if not SlotIsValid(aSlot) then
      begin
      Exit;
      end;

   store := TWindowLayoutStore.Create;
   try
      if not LoadWindowLayout(TR4WConfigFileName, store) then
         begin
         Exit;
         end;

      if store.TryGetLayout(SysUtils.Format('Panadapter%d', [aSlot]),
                            saved, visible) then
         begin
         Result := visible;
         end
      else if (aSlot = 1) and store.TryGetLayout('Panadapter', saved, visible) then
         begin
         { The pre-2026-08-26 single-window row -- slot 1 inherits it, here as
           well as in RestoreBounds, so the upgrade keeps both the position and
           the open state the operator last had. }
         Result := visible;
         end;
   finally
      store.Free;
   end;
end;

initialization
   panLogger := TLogLogger.GetLogger('Panadapter');

end.

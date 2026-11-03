unit uSpectrumTypes;
{$I tr4w.inc}

{
  The vendor-neutral spectrum frame, and the frequency arithmetic that goes
  with it.

  This is the seam between a radio that can produce a panadapter/waterfall
  stream and the window that draws one.  Nothing here may name a vendor, a
  command, a port or a protocol -- the same rule the radio factory applies to
  its base classes.  Today the Elecraft K4 is the only producer (see
  uK4Spectrum); Icom network radios and FlexRadio both have spectrum and are
  expected to follow, and neither of their formats is verified, which is
  precisely why the joint is defined and the machinery is not.

  Two fields exist to keep K4 assumptions out of the window:

    BinCount   is a FIELD, not a constant.  2048 is a K4 number.  A window
               that indexes a fixed 2048 is a window that has to be rewritten
               for the second radio.

    SourceId   is an opaque string, not a "pan ID" and not a character.  The
               K4 puts 'A', 'B', 'Y' or 'Z' in it and streams all of them down
               one socket at once; another radio may have one source, or name
               them differently.  The window filters on equality and must
               never parse it.

  SCALE IS NOT UNIVERSAL -- READ THIS BEFORE DRAWING ANYTHING.  NoiseFloorDb
  is the source's own reported reference, and it is there because the dB
  values in Bins are NOT on a single absolute scale even within one radio.
  Measured on a K4 over 75 seconds (docs/PANADAPTER_LCL_DESIGN.md section 1.1):
  the two main pans ran -160..-106 dB with a floor near -125, while the 3 kHz
  mini-pan ran -2..+19 dB with a floor near 0.  Any fixed dB window that
  renders one renders the other as a single flat colour.  So colour and height
  are scaled RELATIVE TO NoiseFloorDb, never against hard-coded limits.

  The frequency helpers live here rather than in the renderer because the draw
  path and the click-to-tune path must agree to the bin: one converts bins to
  Hz, the other converts Hz back to bins, and if those two ever disagree the
  operator clicks on a signal and lands somewhere else.
}

interface

type
   TSpectrumBins = array of Single;    // dB, one entry per bin, low frequency first

   TSpectrumFrame = record
      SourceId: string;                // opaque; 'A'/'B'/'Y'/'Z' on a K4
      CentreHz: Int64;
      SpanHz: Int64;                   // total width, NOT half
      NoiseFloorDb: Single;            // the source's own reference -- see above
      BinCount: Integer;
      Bins: TSpectrumBins;
      Sequence: Integer;               // per source; wraps
   end;

   { How a producer hands a finished frame outward.

     RAISED ON THE PRODUCER'S THREAD.  The K4's frames arrive on a dedicated
     reading thread, so a subscriber that touches a control must marshal --
     with Synchronize, never TThread.Queue, which purges its own callback
     under FPC.

     The frame is passed by const and the subscriber must not retain a
     reference to Bins beyond the call: the producer is free to reuse or free
     it as soon as this returns.  Copy what you intend to keep.  A producer
     DOES reuse it: a K4 main-pan frame is cropped into one buffer the radio
     owns and overwrites on the next frame (SpectrumCropCentred). }
   TSpectrumFrameProc = procedure(const AFrame: TSpectrumFrame) of object;

   (* HOW A SOURCE WANTS TO BE DRAWN, STATED BY THE RADIO THAT PRODUCES IT.

      The panadapter window used to hold these as constants, every one of them
      a K4 number (#SCL 80 over 10..150, #WFH 50) applied to every radio.  The
      radio owns them now and the window reads them; the window never asks
      which radio it has (NY4I: the spectrum is shared by the K4, the Icoms and
      later the Flex, and a radio's numbers belong to the radio).

      DefaultScaleDb  the dB range from the reference to the top of the trace
                      when the window first shows this source;
      MinScaleDb,     the range the operator's scale slider may move over;
      MaxScaleDb
      RefMarginDb     how far BELOW the reference the display starts, so noise
                      excursions under the floor keep their texture rather
                      than clipping into a solid bar;
      WaterfallFraction  the share of the plot height the waterfall takes;
      LevelsCalibrated   True when Bins are real dB (the K4), False when they
                      are the radio's own units mapped onto a dB-like scale
                      (an Icom's 0..160 or 0..200 levels).  NOTHING READS IT
                      YET; it is stated so a dB scale label can one day say
                      "relative" for an uncalibrated source instead of
                      printing numbers that look like dBm.

      ALL ZERO MEANS "THIS RADIO STATED NOTHING", and it is not a usable
      record -- a zero scale divides by zero.  SpectrumDisplayDefaultsValid is
      the test, and uTestSpectrumDisplayDefaults walks the whole registry so a
      radio that declares rcSpectrum and forgets to state these fails by name
      (CLAUDE.md note 9: a silently-defaulted field reads as a legal zero). *)
   TSpectrumDisplayDefaults = record
      DefaultScaleDb: Integer;
      MinScaleDb: Integer;
      MaxScaleDb: Integer;
      RefMarginDb: Single;
      WaterfallFraction: Single;
      LevelsCalibrated: Boolean;
   end;

   (* WHAT THE RADIO SAYS ITS OWN DISPLAY IS SET TO, RIGHT NOW, FOR ONE SOURCE.

      Distinct from TSpectrumDisplayDefaults above.  Those are fixed numbers
      the radio states about itself ("draw me at 80 dB unless told otherwise");
      these are LIVE values the radio reports as the operator turns its knobs
      (reference level, scale, AutoRef, waterfall share, averaging, waterfall
      colour range, waterfall colour mode).  Today only the K4 reports them
      (uK4DisplayReport).  THE WINDOW DOES NOT READ THIS RECORD: it is in the
      radio's own units, so the radio translates it into a
      TSpectrumLiveDisplay (below) and the window reads that.

      EVERY VALUE HAS ITS OWN Has FLAG, because "the radio has not said" is not
      a legal zero: a REF of 0 dB and a waterfall share of 0 percent are both
      real settings.  A field whose flag is False means nothing.

      Generation moves on EVERY accepted report for this source, including one
      that repeats the value already held, and on every reset (a new link).  It
      never goes back to 0 once moved and never repeats, so a reader that keeps
      the last Generation it applied can tell "the radio said something" from
      "nothing new" without comparing every field.  It is not a count: it
      wraps from High(Integer) to 1.

      NO MANAGED FIELDS, ON PURPOSE.  The record is returned by value from
      under a lock and may be block-copied; a string here would be copied
      without its reference count.

      Units are the radio's and are stated per field.  Vendor-neutral by the
      rule of this unit: nothing here names a command. *)
   TSpectrumRadioState = record
      HasRef: Boolean;
      RefDb: Integer;                 // bottom of the display window, dB
      HasScale: Boolean;
      ScaleDb: Integer;               // height of the display window, dB
      HasAutoRef: Boolean;
      AutoRef: Boolean;               // the radio tracks the reference itself
      AutoRefOffsetDb: Integer;       // its offset, dB; valid with HasAutoRef
      HasWaterfallFraction: Boolean;
      WaterfallPercent: Integer;      // waterfall share of the display, 0..100
      HasAvg: Boolean;
      AvgFrames: Integer;             // spectrum averaging, frames
      HasColourRange: Boolean;
      ColourRange: Integer;           // waterfall colour range, radio's units
      HasColourMode: Boolean;
      ColourMode: Integer;            // waterfall colour scheme, radio's units
      Generation: Integer;            // see above; 0 = never reported or reset
   end;

   (* A WATERFALL COLOUR SCHEME, NAMED BY ITS TONE.  Vendor-neutral: a radio
      maps its own scheme numbers onto these, and the window maps these onto
      the palettes it draws.  Neither side knows the other's numbering. *)
   TSpectrumPaletteTone = (sptGray, sptColour, sptTeal, sptBlue, sptSepia);

   (* WHAT THE RADIO'S OWN DISPLAY SAYS THE WINDOW SHOULD LOOK LIKE, RIGHT NOW,
      in units the window understands.  The radio derives it from its
      TSpectrumRadioState; the window reads it on its refresh timer and falls
      back to TSpectrumDisplayDefaults for every value whose flag is False.

      WaterfallShare        the waterfall's share of the plot height, 0..1
                            INCLUSIVE: 0 is trace only, 1 is waterfall only.
                            (TSpectrumDisplayDefaults.WaterfallFraction must
                            lie strictly inside; a live value may not.)
      ColourFloorOfScale    where the bottom of the waterfall palette sits,
                            BELOW the reference, as a fraction of the scale:
                            the floor is ColourFloorOfScale x scale dB under
                            the reference, and the palette spans one scale
                            above that.  > 0.
      Palette               the colour scheme.

      No Generation: the window applies a value only when it differs from the
      one it last applied, because a radio under AutoRef reports its reference
      several times a second and each report would otherwise re-colour the
      whole history. *)
   TSpectrumLiveDisplay = record
      HasWaterfallShare: Boolean;
      WaterfallShare: Single;
      HasColourFloor: Boolean;
      ColourFloorOfScale: Single;
      HasPalette: Boolean;
      Palette: TSpectrumPaletteTone;
   end;

(* Nothing known, Generation 0.  What a radio that reports nothing returns. *)
function SpectrumRadioStateUnknown: TSpectrumRadioState;

(* Nothing known: every flag False.  What a radio with no live display says. *)
function SpectrumLiveDisplayUnknown: TSpectrumLiveDisplay;
function SpectrumLiveDisplayKnowsNothing(const ALive: TSpectrumLiveDisplay): Boolean;

(* THE WINDOW'S TWO RESOLUTIONS, as pure functions so a test can hold them to
   "unknown means exactly today's numbers".

   SpectrumWaterfallShare: the live share when known, else the defaults'.
   SpectrumWaterfallColourMarginDb: how far below each row's reference the
   palette starts -- ColourFloorOfScale x AScaleDb when known, else the
   defaults' RefMarginDb.  The TRACE never uses this: its margin stays
   RefMarginDb whatever the radio says about waterfall colours. *)
function SpectrumWaterfallShare(const ADefaults: TSpectrumDisplayDefaults;
                                const ALive: TSpectrumLiveDisplay): Single;
function SpectrumWaterfallColourMarginDb(const ADefaults: TSpectrumDisplayDefaults;
                                         const ALive: TSpectrumLiveDisplay;
                                         AScaleDb: Integer): Single;

(* True when no Has flag is set.  THIS, not equality with
   SpectrumRadioStateUnknown, is "the radio has told us nothing": a reset
   clears the flags but moves Generation on. *)
function SpectrumRadioStateKnowsNothing(const AState: TSpectrumRadioState): Boolean;

(* Generation + 1, wrapping from High(Integer) to 1 -- never back to 0, and
   never an overflow under range or overflow checking. *)
function NextSpectrumRadioStateGeneration(AGeneration: Integer): Integer;

(* The neutral answer: all zero, and not valid.  What a radio with no spectrum
   returns. *)
function SpectrumDisplayDefaultsNone: TSpectrumDisplayDefaults;

function MakeSpectrumDisplayDefaults(ADefaultScaleDb, AMinScaleDb,
                                     AMaxScaleDb: Integer;
                                     ARefMarginDb, AWaterfallFraction: Single;
                                     ALevelsCalibrated: Boolean): TSpectrumDisplayDefaults;

(* 0 < min < default < max, margin >= 0, 0 < fraction < 1.  A record that fails
   this cannot be drawn with. *)
function SpectrumDisplayDefaultsValid(const ADefaults: TSpectrumDisplayDefaults): Boolean;

(* Every field, LevelsCalibrated included. *)
function SameSpectrumDisplayDefaults(const A, B: TSpectrumDisplayDefaults): Boolean;

(* Do the two disagree about the SCALE -- default, min or max?  This, and only
   this, is what makes the window reset the operator's slider when a new source
   is attached.  Not SameSpectrumDisplayDefaults: a K4 (calibrated) and an Icom
   (not) state the same scale, and switching profile between them must keep
   the operator's choice, as it always has. *)
function SpectrumScaleRangeDiffers(const A, B: TSpectrumDisplayDefaults): Boolean;

(* THE WINDOW'S DECISION, as a pure function: must attaching AIncoming put the
   scale slider at the radio's default and range?  Yes on the first attach
   (AHaveApplied False) -- the designed form carries no scale of its own, so
   there is nothing to keep -- and whenever the scale range differs from the
   one in force.  No otherwise: the operator's position stands. *)
function SpectrumScaleNeedsReset(AHaveApplied: Boolean;
                                 const AApplied, AIncoming: TSpectrumDisplayDefaults): Boolean;

// Bin i covers [Start + i*Span/N, Start + (i+1)*Span/N).  StartHz and EndHz
// are the frame's extent; SpectrumBinHz returns the CENTRE of a bin.
//
// Centre, not low edge, and that is not cosmetic.  Bins are rarely a whole
// number of Hz wide -- 192000/2048 is 93.75 -- so a low edge truncated to an
// integer Hz lands BELOW its own bin, and SpectrumHzToBin then hands back
// i-1.  Rounding the centre instead keeps the value inside the bin for any
// bin wider than 1 Hz, which the round-trip test pins at both the 192 kHz and
// the 3 kHz span.  (Below 1 Hz per bin no integer-Hz scheme can distinguish
// adjacent bins at all; the K4's narrowest is 1.46 Hz.)
function SpectrumStartHz(const AFrame: TSpectrumFrame): Int64;
function SpectrumEndHz(const AFrame: TSpectrumFrame): Int64;
function SpectrumBinHz(const AFrame: TSpectrumFrame; ABin: Integer): Int64;

// Returns -1 when AHz falls outside the frame, so a caller cannot silently
// treat an off-screen click as bin 0.  A clamped result would be a plausible
// wrong answer, which is worse than a refusal.
function SpectrumHzToBin(const AFrame: TSpectrumFrame; AHz: Int64): Integer;

const
   (* The fewest bins SpectrumCropCentred will keep, so an absurd requested
      span (1 Hz) still draws a trace rather than one or two columns. *)
   SPECTRUM_CROP_MIN_BINS = 64;

(* KEEP THE CENTRED PART OF A FRAME THAT SPANS AWantSpanHz -- for a producer
   whose frames are WIDER than the span its radio says it is showing.

   Vendor-neutral on purpose: which source is cropped, to which span, and how
   many edge bins are never worth drawing are the PRODUCER's decisions and
   arrive as arguments.  The K4 is the caller today (TK4Radio.HandleSpectrumFrame;
   docs/PANADAPTER_LCL_DESIGN.md section 10.4).

   ACropped is ALWAYS assigned.  The result says whether it differs from
   AFrame: False means ACropped = AFrame, unchanged, and that is the answer
   when AWantSpanHz is unknown (<= 0), when it is not narrower than the frame,
   when the frame has no bins, or when no exact crop exists (below).

   EXACT, NOT APPROXIMATE.  Bin i of ACropped has the same SpectrumBinHz as
   bin (i + first) of AFrame, to the Hz, so the trace, the axis and
   click-to-tune of the cropped frame put every signal where the uncropped
   frame did.  The frame carries whole Hz, so that needs a kept count n with
   n * SpanHz divisible by 2 * BinCount -- then the new SpanHz is a whole,
   even number, its half lands on a bin edge of the original, and CentreHz
   stays as it is because the crop is centred.  n is therefore the multiple
   of that step NEAREST the requested width.  For the K4 the step is 750 Hz at
   every frame width it serves (8 bins at 192 kHz, 4 at 384 kHz), so the
   drawn span is within 375 Hz of the requested one unless the edge guard
   below caps it.  An odd BinCount, or a
   span with no such step inside the frame, gets no crop.

   AEdgeGuardBins is the most bins either end can hold that are not signal
   (padding, filter roll-off): n never exceeds BinCount - 2 * AEdgeGuardBins,
   whatever span is asked for.  0 means no guard.

   ABUFFER IS THE CALLER'S AND IS REUSED.  ACropped.Bins IS ABuffer, resized
   only when the kept count changes, so a stream of frames at one span
   allocates nothing here.  That is sound under the TSpectrumFrameProc rule
   above -- a subscriber copies what it keeps and never holds Bins past the
   call -- and it means ONE buffer per producer thread: two threads must not
   share an ABuffer. *)
function SpectrumCropCentred(const AFrame: TSpectrumFrame;
                             AWantSpanHz: Int64;
                             AEdgeGuardBins: Integer;
                             var ABuffer: TSpectrumBins;
                             out ACropped: TSpectrumFrame): Boolean;

(* THE HORIZONTAL MAPPING -- pixel columns, bins and Hz -- in one place.

   The panadapter's trace, its waterfall, its axis, its VFO markers, its spot
   ticks and click-to-tune all place things across the same AWidth columns.
   They used to do it with four inline formulas in the form; these are those
   formulas, moved here unchanged so they can be tested without a window.

   THEY ARE NOT ONE DEFINITION YET, and the tests in uTestSpectrumMapping say
   by how much.  The trace takes, for column x, the bins
   [Trunc(x * bpp), Trunc((x + 1) * bpp) - 1] (one bin when that is empty);
   click-to-tune reports the CENTRE OF THE FIRST of those bins, while the trace
   and the readout show their MAXIMUM; a marker rounds its Hz to the nearest
   column edge, which is not always the column the trace draws that bin in.
   Changing any of that changes pixels, so it is a decision, not a refactor.

   ABinsPerPixel is a Double ON PURPOSE.  The trace computes it once as
   BinCount / Width into a Double, and Trunc of x times that Double is what it
   draws.  Integer arithmetic would differ wherever the Double undershoots an
   integer -- which is also why, for some widths, the top bin falls in no
   column at all.  Callers get the value from SpectrumBinsPerPixel so that
   every one of them truncates the same Double. *)

(* BinCount / Width as the trace has always computed it; 0 for no width. *)
function SpectrumBinsPerPixel(ABinCount, AWidth: Integer): Double;

(* The bins the trace draws in column AX: AFirst..ALast, both inside
   0..ABinCount - 1.  Wider than the data, one bin repeats across several
   columns.  Both are -1 when there are no bins. *)
procedure SpectrumColumnBins(AX, ABinCount: Integer; ABinsPerPixel: Double;
                             out AFirst, ALast: Integer);

(* Click-to-tune: the centre of the FIRST bin of column AX.  0 when the frame
   has no bins. *)
function SpectrumColumnHz(const AFrame: TSpectrumFrame; AX: Integer;
                          ABinsPerPixel: Double): Int64;

(* Markers, spots and axis ticks: AHz rounded to the nearest column edge.
   NOT clamped -- a passband edge off either side still has to be placed so
   the visible part is drawn -- so a caller drawing a point checks
   0 <= x < AWidth itself.  -1 when the span or the width is not positive. *)
function SpectrumHzToPixel(const AFrame: TSpectrumFrame; AHz: Int64;
                           AWidth: Integer): Integer;

{ The DIAL frequency to set so that a signal displayed at ARfHz is actually
  heard -- the click-to-tune correction.

  In CW the spectrum shows a signal where it transmits, but the receiver only
  hears it when the dial sits one CW pitch away: BELOW in normal CW, ABOVE in
  CW-reverse.  Tuning to exactly where the signal is drawn therefore lands the
  operator a pitch off -- around 600 Hz, which in a CW pileup is the difference
  between working a station and transmitting on top of one.

  A pure function, and separated from the window on purpose: this is the part
  of click-to-tune with a right answer that can be checked without a radio, a
  socket or a mouse.  Pass ACwNormal/ACwReverse from the rig's mode, and
  APitchHz = 0 to disable the correction entirely (the honest default when
  nothing has established the receiver's pitch). }
function SpectrumDialFrequency(ARfHz: Int64; APitchHz: Integer;
                               ACwNormal, ACwReverse: Boolean): Int64;

implementation

function SpectrumRadioStateUnknown: TSpectrumRadioState;
begin
   Result := Default(TSpectrumRadioState);
end;

function SpectrumRadioStateKnowsNothing(const AState: TSpectrumRadioState): Boolean;
begin
   Result := (not AState.HasRef)                 and
             (not AState.HasScale)               and
             (not AState.HasAutoRef)             and
             (not AState.HasWaterfallFraction)   and
             (not AState.HasAvg)                 and
             (not AState.HasColourRange)         and
             (not AState.HasColourMode);
end;

function SpectrumLiveDisplayUnknown: TSpectrumLiveDisplay;
begin
   Result := Default(TSpectrumLiveDisplay);
end;

function SpectrumLiveDisplayKnowsNothing(const ALive: TSpectrumLiveDisplay): Boolean;
begin
   Result := (not ALive.HasWaterfallShare)   and
             (not ALive.HasColourFloor)      and
             (not ALive.HasPalette);
end;

function SpectrumWaterfallShare(const ADefaults: TSpectrumDisplayDefaults;
                                const ALive: TSpectrumLiveDisplay): Single;
begin
   Result := ADefaults.WaterfallFraction;

   if ALive.HasWaterfallShare then
      begin
      Result := ALive.WaterfallShare;
      end;

   (* A radio's driver bounds its own value; this keeps a wrong one from
      producing a negative surface. *)
   if Result < 0 then
      begin
      Result := 0;
      end;

   if Result > 1 then
      begin
      Result := 1;
      end;
end;

function SpectrumWaterfallColourMarginDb(const ADefaults: TSpectrumDisplayDefaults;
                                         const ALive: TSpectrumLiveDisplay;
                                         AScaleDb: Integer): Single;
begin
   Result := ADefaults.RefMarginDb;

   if ALive.HasColourFloor and (ALive.ColourFloorOfScale > 0) and (AScaleDb > 0) then
      begin
      Result := ALive.ColourFloorOfScale * AScaleDb;
      end;
end;

function NextSpectrumRadioStateGeneration(AGeneration: Integer): Integer;
begin
   if (AGeneration < 0) or (AGeneration = High(Integer)) then
      begin
      Result := 1;
      end
   else
      begin
      Result := AGeneration + 1;
      end;
end;

function SpectrumDisplayDefaultsNone: TSpectrumDisplayDefaults;
begin
   Result.DefaultScaleDb := 0;
   Result.MinScaleDb := 0;
   Result.MaxScaleDb := 0;
   Result.RefMarginDb := 0;
   Result.WaterfallFraction := 0;
   Result.LevelsCalibrated := False;
end;

function MakeSpectrumDisplayDefaults(ADefaultScaleDb, AMinScaleDb,
                                     AMaxScaleDb: Integer;
                                     ARefMarginDb, AWaterfallFraction: Single;
                                     ALevelsCalibrated: Boolean): TSpectrumDisplayDefaults;
begin
   Result.DefaultScaleDb := ADefaultScaleDb;
   Result.MinScaleDb := AMinScaleDb;
   Result.MaxScaleDb := AMaxScaleDb;
   Result.RefMarginDb := ARefMarginDb;
   Result.WaterfallFraction := AWaterfallFraction;
   Result.LevelsCalibrated := ALevelsCalibrated;
end;

function SpectrumDisplayDefaultsValid(const ADefaults: TSpectrumDisplayDefaults): Boolean;
begin
   Result := (ADefaults.MinScaleDb > 0)                          and
             (ADefaults.MinScaleDb < ADefaults.DefaultScaleDb)   and
             (ADefaults.DefaultScaleDb < ADefaults.MaxScaleDb)   and
             (ADefaults.RefMarginDb >= 0)                        and
             (ADefaults.WaterfallFraction > 0)                   and
             (ADefaults.WaterfallFraction < 1);
end;

function SameSpectrumDisplayDefaults(const A, B: TSpectrumDisplayDefaults): Boolean;
begin
   Result := (A.DefaultScaleDb = B.DefaultScaleDb)         and
             (A.MinScaleDb = B.MinScaleDb)                 and
             (A.MaxScaleDb = B.MaxScaleDb)                 and
             (A.RefMarginDb = B.RefMarginDb)               and
             (A.WaterfallFraction = B.WaterfallFraction)   and
             (A.LevelsCalibrated = B.LevelsCalibrated);
end;

function SpectrumScaleRangeDiffers(const A, B: TSpectrumDisplayDefaults): Boolean;
begin
   Result := (A.DefaultScaleDb <> B.DefaultScaleDb)   or
             (A.MinScaleDb <> B.MinScaleDb)           or
             (A.MaxScaleDb <> B.MaxScaleDb);
end;

function SpectrumScaleNeedsReset(AHaveApplied: Boolean;
                                 const AApplied, AIncoming: TSpectrumDisplayDefaults): Boolean;
begin
   Result := (not AHaveApplied) or
             SpectrumScaleRangeDiffers(AApplied, AIncoming);
end;

function SpectrumStartHz(const AFrame: TSpectrumFrame): Int64;
begin
   Result := AFrame.CentreHz - (AFrame.SpanHz div 2);
end;

function SpectrumEndHz(const AFrame: TSpectrumFrame): Int64;
begin
   Result := SpectrumStartHz(AFrame) + AFrame.SpanHz;
end;

function SpectrumBinHz(const AFrame: TSpectrumFrame; ABin: Integer): Int64;
begin
   if AFrame.BinCount <= 0 then
      begin
      Result := AFrame.CentreHz;
      Exit;
      end;

   // Centre of bin i = Start + Span*(2i+1) / 2N, rounded to nearest.
   // (x + d div 2) div d is round-half-up for positive d; SpanHz is Int64 so
   // the multiply cannot overflow at any span the radio can report.
   Result := SpectrumStartHz(AFrame)
             + ((AFrame.SpanHz * ((2 * ABin) + 1) + AFrame.BinCount)
                div (2 * AFrame.BinCount));
end;

function SpectrumHzToBin(const AFrame: TSpectrumFrame; AHz: Int64): Integer;
var
   offset: Int64;
begin
   Result := -1;

   if (AFrame.BinCount <= 0) or (AFrame.SpanHz <= 0) then
      begin
      Exit;
      end;

   offset := AHz - SpectrumStartHz(AFrame);

   if (offset < 0) or (offset >= AFrame.SpanHz) then
      begin
      Exit;
      end;

   Result := Integer((offset * AFrame.BinCount) div AFrame.SpanHz);
end;

function GreatestCommonDivisor(A, B: Int64): Int64;
var
   t: Int64;
begin
   while B <> 0 do
      begin
      t := A mod B;
      A := B;
      B := t;
      end;

   Result := A;
end;

function SpectrumCropCentred(const AFrame: TSpectrumFrame;
                             AWantSpanHz: Int64;
                             AEdgeGuardBins: Integer;
                             var ABuffer: TSpectrumBins;
                             out ACropped: TSpectrumFrame): Boolean;
var
   binCount: Int64;
   spanHz: Int64;
   step: Int64;
   kept: Int64;
   maxKept: Int64;
   first: Integer;
   i: Integer;
begin
   ACropped := AFrame;
   Result := False;

   binCount := AFrame.BinCount;
   spanHz := AFrame.SpanHz;

   if (AWantSpanHz <= 0)                  or
      (spanHz <= 0)                       or
      (AWantSpanHz >= spanHz)             or
      (binCount <= 0)                     or
      Odd(binCount)                       or
      (Length(AFrame.Bins) < binCount)    then
      begin
      Exit;
      end;

   if AEdgeGuardBins < 0 then
      begin
      AEdgeGuardBins := 0;
      end;

   (* The step: the smallest kept count whose span is a whole, even number of
      Hz -- see the interface.  Even as well, so (binCount - kept) is even and
      the crop sits exactly in the middle. *)
   step := (2 * binCount) div GreatestCommonDivisor(spanHz, 2 * binCount);

   if Odd(step) then
      begin
      step := step * 2;
      end;

   (* The guard caps the kept count, rounded DOWN to a step, so rounding can
      never put a guarded bin back. *)
   maxKept := ((binCount - (2 * AEdgeGuardBins)) div step) * step;

   (* The multiple of step nearest binCount * want / span: round(x / y) is
      (2x + y) div 2y for positive x and y. *)
   kept := (((2 * binCount * AWantSpanHz) + (spanHz * step))
            div (2 * spanHz * step)) * step;

   if kept < SPECTRUM_CROP_MIN_BINS then
      begin
      kept := ((SPECTRUM_CROP_MIN_BINS + step - 1) div step) * step;
      end;

   if kept > maxKept then
      begin
      kept := maxKept;
      end;

   if (kept <= 0) or (kept >= binCount) then
      begin
      Exit;
      end;

   first := Integer((binCount - kept) div 2);

   if Length(ABuffer) <> kept then
      begin
      SetLength(ABuffer, kept);
      end;

   (* Element by element, not Move (docs/POINTER_AUDIT.md P15): at most 2048
      Singles a frame, and Copy would allocate the array this buffer exists to
      avoid allocating. *)
   for i := 0 to Integer(kept) - 1 do
      begin
      ABuffer[i] := AFrame.Bins[first + i];
      end;

   ACropped.SpanHz := (kept * spanHz) div binCount;    // exact: see the step
   ACropped.BinCount := Integer(kept);
   ACropped.Bins := ABuffer;
   Result := True;
end;

function SpectrumBinsPerPixel(ABinCount, AWidth: Integer): Double;
begin
   Result := 0;

   if AWidth <= 0 then
      begin
      Exit;
      end;

   Result := ABinCount / AWidth;
end;

procedure SpectrumColumnBins(AX, ABinCount: Integer; ABinsPerPixel: Double;
                             out AFirst, ALast: Integer);
var
   top: Integer;
begin
   AFirst := -1;
   ALast := -1;

   if ABinCount <= 0 then
      begin
      Exit;
      end;

   top := ABinCount - 1;

   (* The trace's own expressions, in the trace's own order.  Do not turn
      them into integer division: see the note on ABinsPerPixel. *)
   AFirst := Trunc(AX * ABinsPerPixel);
   ALast := Trunc((AX + 1) * ABinsPerPixel) - 1;

   if ALast < AFirst then
      begin
      ALast := AFirst;
      end;

   if AFirst > top then
      begin
      AFirst := top;
      end;

   if ALast > top then
      begin
      ALast := top;
      end;

   (* Only a column left of the window gets here -- the trace never asks for
      one, click-to-tune used to clamp it to bin 0, and this keeps that. *)
   if AFirst < 0 then
      begin
      AFirst := 0;
      end;

   if ALast < AFirst then
      begin
      ALast := AFirst;
      end;
end;

function SpectrumColumnHz(const AFrame: TSpectrumFrame; AX: Integer;
                          ABinsPerPixel: Double): Int64;
var
   first, last: Integer;
begin
   Result := 0;
   SpectrumColumnBins(AX, AFrame.BinCount, ABinsPerPixel, first, last);

   if first < 0 then
      begin
      Exit;
      end;

   Result := SpectrumBinHz(AFrame, first);
end;

function SpectrumHzToPixel(const AFrame: TSpectrumFrame; AHz: Int64;
                           AWidth: Integer): Integer;
begin
   Result := -1;

   if (AFrame.SpanHz <= 0) or (AWidth <= 0) then
      begin
      Exit;
      end;

   (* Round is the RTL's banker's rounding, exactly as the form had it. *)
   Result := Round(((AHz - SpectrumStartHz(AFrame)) / AFrame.SpanHz) * AWidth);
end;

function SpectrumDialFrequency(ARfHz: Int64; APitchHz: Integer;
                               ACwNormal, ACwReverse: Boolean): Int64;
begin
   Result := ARfHz;

   // A pitch of zero means "nobody has told us the receiver's pitch", and a
   // negative one is nonsense.  Either way, do not invent an offset.
   if APitchHz <= 0 then
      begin
      Exit;
      end;

   // Guarded against both being set: a mode cannot be normal AND reverse, and
   // silently preferring one would hide the caller's bug.
   if ACwNormal and ACwReverse then
      begin
      Exit;
      end;

   if ACwNormal then
      begin
      Result := ARfHz - APitchHz;
      end
   else if ACwReverse then
      begin
      Result := ARfHz + APitchHz;
      end;
end;

end.

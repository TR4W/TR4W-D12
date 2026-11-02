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
     it as soon as this returns.  Copy what you intend to keep. }
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

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

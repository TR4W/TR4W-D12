unit uK4Spectrum;
{$I ..\tr4w.inc}

{
  Decoding the Elecraft K4's panadapter stream into vendor-neutral
  TSpectrumFrame records.

  This unit is PURE: bytes in, frames out.  No socket, no thread, no UI, no
  radio object, no globals.  That is deliberate and it is what makes the
  format testable with no radio on the bench -- uTestK4Spectrum drives every
  path below from tr4w/test/unit/fixtures/k4pan-sample.bin, a real capture.

  THE FORMAT WAS MEASURED, NOT ASSUMED.  tools/k4panwatch.py captured 2,706
  packets from a K4 and checked each structural claim independently; the full
  table and the method are in docs/PANADAPTER_LCL_DESIGN.md section 1.  In
  summary, a frame is 4,162 bytes:

     0..3      sync $FF $FE $01 $00
     4         version (2)
     5         sequence, PER SOURCE, wraps at 256
     6         source id, ASCII 'A' 'B' 'Y' 'Z'
     7..12     span in Hz, ASCII
     13..23    centre in Hz, ASCII
     24..28    noise floor x10, ASCII, signed
     29..62    reserved -- zero on every packet observed
     63        checksum byte: bytes 0..63 sum to 0 mod 256
     64..4159  2048 samples, signed big-endian int16, /10 = dB
     4160..4161 CRC-16/X-25 over bytes 0..4159, big-endian

  Note the header carries TWO independent integrity checks (the zero-sum byte
  and the CRC) on top of a four-byte sync marker.  All three are verified.
  That is not belt-and-braces for its own sake: a false sync marker inside
  sample data is entirely possible -- the payload is arbitrary binary and
  $FF $FE $01 $00 is not a reserved sequence -- so the cheap checks are what
  stop a mid-payload coincidence being decoded as a frame.

  THE FIELDS ARE ASCII, AND A BAD ONE FAILS THE DECODE.  TR4QT's reader
  defaults an unparseable sample rate to 48000 and an unparseable centre
  frequency to 0.  That is defensible in a running program and wrong here: a
  manufactured 48 kHz span would draw a plausible, silently incorrect display.
  A field that does not parse means the frame is not what we think it is, so
  DecodeK4Frame refuses it and the framer treats it as a bad frame.
}

interface

uses
   SysUtils, uSpectrumTypes;

const
   K4_SYNC_0 = $FF;
   K4_SYNC_1 = $FE;
   K4_SYNC_2 = $01;
   K4_SYNC_3 = $00;

   K4_HEADER_SIZE = 64;
   K4_SAMPLE_COUNT = 2048;
   K4_PAYLOAD_SIZE = K4_SAMPLE_COUNT * 2;      // 4096
   K4_FOOTER_SIZE = 2;                         // CRC-16
   K4_PACKET_SIZE = K4_HEADER_SIZE + K4_PAYLOAD_SIZE + K4_FOOTER_SIZE;   // 4162

   K4_EXPECTED_VERSION = 2;

type
   TK4FrameStatus = (
      k4Ok,
      k4TooShort,          // fewer than K4_PACKET_SIZE bytes available
      k4BadSync,           // the four sync bytes are not where they should be
      k4BadHeaderSum,      // bytes 0..63 do not sum to zero mod 256
      k4BadCRC,            // CRC-16 mismatch
      k4BadField);         // an ASCII header field would not parse

// Cheap-to-expensive: sync, then header sum, then CRC.  A false sync inside
// payload data is rejected by the header sum in 64 byte-adds, without paying
// for a CRC over 4,160.
function ValidateK4Frame(const ABytes: TBytes; AOffset: Integer): TK4FrameStatus;

// Assumes nothing: re-validates before decoding, so it cannot be called on an
// unchecked buffer by mistake.
function DecodeK4Frame(const ABytes: TBytes; AOffset: Integer;
                       out AFrame: TSpectrumFrame): TK4FrameStatus;

type
   { Byte stream -> whole frames, with resynchronisation.

     Pull model (Feed, then NextFrame until it returns False) rather than a
     callback, because it makes the thing trivially testable: a test can feed
     a capture in awkward chunk sizes and count what comes out.  The reading
     thread will drive it exactly the same way. }
   TK4SpectrumFramer = class(TObject)
   private
      FBuffer: TBytes;
      FHead: Integer;         // first unread byte
      FTail: Integer;         // one past the last valid byte
      FDiscarded: Int64;
      FResyncs: Int64;
      FBadFrames: Int64;
      FFramesOut: Int64;
      function FindSync(AFrom: Integer): Integer;
   public
      constructor Create;

      procedure Feed(const AData: TBytes; ACount: Integer);
      function NextFrame(out AFrame: TSpectrumFrame): Boolean;
      procedure Reset;

      // Diagnostics.  Reported as counters rather than logged per event: at 36
      // frames a second a per-byte log line during a resync storm would be the
      // loudest thing in tr4w.log and would tell you less than one number.
      property Discarded: Int64 read FDiscarded;
      property Resyncs: Int64 read FResyncs;
      property BadFrames: Int64 read FBadFrames;
      property FramesOut: Int64 read FFramesOut;
   end;

implementation

uses
   uCRC16;

// ---------------------------------------------------------------------------
// Header field helpers
// ---------------------------------------------------------------------------

// An ASCII integer field.  Returns False rather than a sentinel value, so the
// caller cannot mistake a failure for data -- see the unit header.
function AsciiInt64(const ABytes: TBytes; AOffset, ALength: Integer;
                    out AValue: Int64): Boolean;
var
   s: string;
   i: Integer;
begin
   s := '';

   for i := 0 to ALength - 1 do
      begin
      s := s + Char(ABytes[AOffset + i]);   // Char, not Chr -- see uRadioYaesuBinary.SendBytes
      end;

   // The K4 pads with leading zeros ('00003534390') and signs the noise floor
   // ('-1259'); both are ordinary for TryStrToInt64.  Trim covers any spaces.
   Result := TryStrToInt64(Trim(s), AValue);
end;

function HasSyncAt(const ABytes: TBytes; AOffset: Integer): Boolean;
begin
   Result := (ABytes[AOffset] = K4_SYNC_0) and
             (ABytes[AOffset + 1] = K4_SYNC_1) and
             (ABytes[AOffset + 2] = K4_SYNC_2) and
             (ABytes[AOffset + 3] = K4_SYNC_3);
end;

// ---------------------------------------------------------------------------
// Validation and decode
// ---------------------------------------------------------------------------

function ValidateK4Frame(const ABytes: TBytes; AOffset: Integer): TK4FrameStatus;
var
   sum: Byte;
   i: Integer;
   computed: Word;
   received: Word;
begin
   if (AOffset < 0) or (AOffset + K4_PACKET_SIZE > Length(ABytes)) then
      begin
      Result := k4TooShort;
      Exit;
      end;

   if not HasSyncAt(ABytes, AOffset) then
      begin
      Result := k4BadSync;
      Exit;
      end;

   // Byte 63 is chosen by the radio so that this sum is zero.  Byte arithmetic
   // wraps, which is the mod 256 the rule is stated in.
   sum := 0;

   for i := 0 to K4_HEADER_SIZE - 1 do
      begin
      sum := Byte(sum + ABytes[AOffset + i]);
      end;

   if sum <> 0 then
      begin
      Result := k4BadHeaderSum;
      Exit;
      end;

   computed := GetCRC16X25(ABytes[AOffset], K4_PACKET_SIZE - K4_FOOTER_SIZE);
   received := (Word(ABytes[AOffset + K4_PACKET_SIZE - 2]) shl 8) or
                Word(ABytes[AOffset + K4_PACKET_SIZE - 1]);

   if computed <> received then
      begin
      Result := k4BadCRC;
      Exit;
      end;

   Result := k4Ok;
end;

function DecodeK4Frame(const ABytes: TBytes; AOffset: Integer;
                       out AFrame: TSpectrumFrame): TK4FrameStatus;
var
   span: Int64;
   centre: Int64;
   noise: Int64;
   i: Integer;
   raw: SmallInt;
   payload: Integer;
begin
   AFrame := Default(TSpectrumFrame);

   Result := ValidateK4Frame(ABytes, AOffset);

   if Result <> k4Ok then
      begin
      Exit;
      end;

   if not AsciiInt64(ABytes, AOffset + 7, 6, span) then
      begin
      Result := k4BadField;
      Exit;
      end;

   if not AsciiInt64(ABytes, AOffset + 13, 11, centre) then
      begin
      Result := k4BadField;
      Exit;
      end;

   if not AsciiInt64(ABytes, AOffset + 24, 5, noise) then
      begin
      Result := k4BadField;
      Exit;
      end;

   AFrame.SourceId := Char(ABytes[AOffset + 6]);   // Char, not Chr -- see uRadioYaesuBinary.SendBytes
   AFrame.Sequence := ABytes[AOffset + 5];
   AFrame.SpanHz := span;
   AFrame.CentreHz := centre;
   AFrame.NoiseFloorDb := noise / 10.0;
   AFrame.BinCount := K4_SAMPLE_COUNT;

   SetLength(AFrame.Bins, K4_SAMPLE_COUNT);
   payload := AOffset + K4_HEADER_SIZE;

   for i := 0 to K4_SAMPLE_COUNT - 1 do
      begin
      // Big-endian, and SIGNED: values run to -160 dB, i.e. raw -1600.  Build
      // the 16-bit pattern then reinterpret as SmallInt, rather than assigning
      // a possibly-negative expression into a wider type first.
      raw := SmallInt((Word(ABytes[payload + (i * 2)]) shl 8) or
                       Word(ABytes[payload + (i * 2) + 1]));
      AFrame.Bins[i] := raw / 10.0;
      end;

   Result := k4Ok;
end;

// ---------------------------------------------------------------------------
// TK4SpectrumFramer
// ---------------------------------------------------------------------------

constructor TK4SpectrumFramer.Create;
begin
   inherited Create;
   Reset;
end;

procedure TK4SpectrumFramer.Reset;
begin
   SetLength(FBuffer, 0);
   FHead := 0;
   FTail := 0;
   FDiscarded := 0;
   FResyncs := 0;
   FBadFrames := 0;
   FFramesOut := 0;
end;

procedure TK4SpectrumFramer.Feed(const AData: TBytes; ACount: Integer);
var
   live: Integer;
   needed: Integer;
begin
   if ACount <= 0 then
      begin
      Exit;
      end;

   // Compact first.  Consumed bytes are dropped by advancing FHead rather than
   // by deleting from the front, so the per-frame cost is not a 4 KB memory
   // move; the leftover moved here is normally a partial frame.  (A Copy/Delete
   // buffer is what makes a naive framer quadratic in the feed count.)
   live := FTail - FHead;

   if (FHead > 0) and (live > 0) then
      begin
      Move(FBuffer[FHead], FBuffer[0], live);
      end;

   FHead := 0;
   FTail := live;

   needed := FTail + ACount;

   if needed > Length(FBuffer) then
      begin
      // Grow generously: the reading thread feeds whatever the socket returns,
      // so reallocating on every read would be the dominant cost.
      SetLength(FBuffer, needed * 2);
      end;

   Move(AData[0], FBuffer[FTail], ACount);
   Inc(FTail, ACount);
end;

function TK4SpectrumFramer.FindSync(AFrom: Integer): Integer;
var
   i: Integer;
begin
   Result := -1;

   // Stop 4 bytes short: a marker cannot be confirmed past the end.
   for i := AFrom to FTail - 4 do
      begin
      if HasSyncAt(FBuffer, i) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function TK4SpectrumFramer.NextFrame(out AFrame: TSpectrumFrame): Boolean;
var
   syncPos: Integer;
   keep: Integer;
   status: TK4FrameStatus;
begin
   Result := False;

   while (FTail - FHead) >= K4_PACKET_SIZE do
      begin
      if not HasSyncAt(FBuffer, FHead) then
         begin
         syncPos := FindSync(FHead + 1);

         if syncPos < 0 then
            begin
            // Nothing usable.  Keep the last 3 bytes: a sync marker may
            // straddle this read and the next, and discarding them would turn
            // a recoverable stream into a permanently broken one.
            keep := 3;

            if (FTail - FHead) > keep then
               begin
               Inc(FDiscarded, (FTail - FHead) - keep);
               FHead := FTail - keep;
               end;

            Exit;
            end;

         Inc(FDiscarded, syncPos - FHead);
         Inc(FResyncs);
         FHead := syncPos;
         Continue;
         end;

      status := ValidateK4Frame(FBuffer, FHead);

      if status = k4Ok then
         begin
         if DecodeK4Frame(FBuffer, FHead, AFrame) = k4Ok then
            begin
            Inc(FHead, K4_PACKET_SIZE);
            Inc(FFramesOut);
            Result := True;
            Exit;
            end;

         // Structurally sound but a header field would not parse.  Treat it
         // like any other bad frame rather than trusting the CRC over the
         // content it protects.
         Inc(FBadFrames);
         Inc(FHead);
         Inc(FDiscarded);
         Continue;
         end;

      // Sync matched but the frame failed a check.  Drop ONE byte and re-align
      // -- the same self-syncing contract TReadingThread's frameValidator uses
      // (uFactoryRadioBase.pas:227).  Skipping a whole 4,162 bytes instead
      // would be right for a corrupted-but-aligned frame and badly wrong for
      // the likelier case here: a coincidental sync marker inside payload
      // data, where a whole-packet skip steps over real frames.  TCP has
      // already ruled out bit corruption, so the coincidence is the case that
      // actually happens.
      Inc(FBadFrames);
      Inc(FHead);
      Inc(FDiscarded);
      end;
end;

end.

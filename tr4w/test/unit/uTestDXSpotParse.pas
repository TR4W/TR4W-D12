unit uTestDXSpotParse;

{
  Pins uDXSpotParse.ParseDXSpotLine -- the DX cluster spot DECODER, until now
  the first half of uTelnet.ProcessDX and never once covered by a test.

  WHERE THE FIXTURES COME FROM.  Every line marked "REAL" below is copied
  byte-for-byte out of the captured cluster sessions in
  D7-LogFilesForTesting/dxcluster (265 files, 198,979 "DX de" lines, AR-Cluster
  and DXSpider nodes).  That matters because the decoder is fixed-column
  arithmetic with no format validation: the only way to know an offset is right
  is to feed it what real nodes actually sent.  The survey behind the column
  map in uDXSpotParse's header comes from those same files -- 198,977 of the
  198,979 lines put the frequency's decimal point on column 22.

  Lines marked "SYNTHETIC" are hand-built from a REAL line by changing one
  field, for cases the capture does not contain (UP7 / UP10 without a space).

  THESE ARE CHARACTERIZATION TESTS.  Several assertions below pin behaviour
  that is arguably WRONG (they say so where they do).  That is deliberate: this
  is a refactor, the arithmetic moved unchanged, and a pin that encodes today's
  behaviour is what makes any later correction a visible, deliberate diff
  rather than a silent drift.
}

interface

uses
   SysUtils, uTR4WTestFramework, VC, uDXSpotParse;

type
   TDXSpotParseTests = class(TTestCase)
   protected
      // REAL lines: the ordinary shape, 198,977 of 198,979 captured lines
      procedure Test_PlainSpot_Frequency;
      procedure Test_PlainSpot_Call;
      procedure Test_PlainSpot_SourceCall;
      procedure Test_PlainSpot_Notes;
      procedure Test_PlainSpot_NoQSX;

      // REAL: spotter callsign too long for the field shifts every column right
      procedure Test_LongSpotter_ShiftsCallColumn;
      procedure Test_LongSpotter_Frequency;
      procedure Test_LongSpotter_SourceCallHasLength;

      // The ShortString length-byte quirk, pinned in both directions
      procedure Test_SourceCall_LengthByteQuirk;

      // REAL: QSX in the comment
      procedure Test_QSX_WithDecimal;
      procedure Test_QSX_WholeKilohertz;
      procedure Test_QSX_OutOfBandIsDropped;

      // REAL + SYNTHETIC: "UP n"
      procedure Test_UP_WithSpace;
      procedure Test_UP_NoSpace_SingleDigit;
      procedure Test_UP_NoSpace_TwoDigits;
      procedure Test_UP_WithSpace_TwoDigits;
      procedure Test_UP_InsideAWordIsNotQSX;
      procedure Test_UP_InCallsignIsNotQSX;

      // Frequencies across the bands the arithmetic has to cover
      procedure Test_Frequency_VHF;
      procedure Test_Frequency_160m;

      // Rejection and degenerate input
      procedure Test_BadCallSyntaxRejected;
      procedure Test_TruncatedLineAccepted_KNOWN_DEFECT;
      procedure Test_EmptyLineAccepted_KNOWN_DEFECT;

      // The time stamp
      procedure Test_Time_Parsed;
      procedure Test_Time_MissingZRejected;
      procedure Test_Time_TrailingGridStillParses;

   public
      procedure RunAllTests; override;
   end;

implementation

const
   // ---- REAL lines, byte-for-byte from D7-LogFilesForTesting/dxcluster ------
   //         0         1         2         3         4         5         6         7
   //         0123456789012345678901234567890123456789012345678901234567890123456789012345
   PLAIN   = 'DX de N4RJ:      14332.0  KL5DX        USB                            1537Z';
   QSXDEC  = 'DX de K3WJV:      7105.0  DL1GLH       QSX 7275.10                    0126Z';
   QSXWHOLE= 'DX de K2AX:       7240.0  K2AX         QSX 7082 QRV                   0130Z';
   UPSPACE = 'DX de WB1DXD:    21023.0  TX5XG        UP 2                           1804Z';
   UPBIG   = 'DX de NW3Y:      14195.0  VP2EE        UP 200-205                     1917Z FM28';
   UPCALL  = 'DX de KB7HDX:    14247.2  UP0L                                        1717Z';
   LONGSPTR= 'DX de 3V/KF5EYY-#:14007.0  PA3DZM      CW 20 DB 33 WPM CQ          PA 1941Z 3V';
   TRUNC   = 'DX de K3LR:  ';

   // ---- SYNTHETIC: PLAIN with the comment field replaced ---------------------
   // Same columns, so only the comment differs from a REAL line.
   //         0         1         2         3         4         5         6         7
   //         0123456789012345678901234567890123456789012345678901234567890123456789012345
   UP7     = 'DX de N4RJ:      14332.0  KL5DX        UP7                            1537Z';
   UP10    = 'DX de N4RJ:      14332.0  KL5DX        UP10                           1537Z';
   UPSP10  = 'DX de N4RJ:      14332.0  KL5DX        UP 10                          1537Z';
   SOUP    = 'DX de N4RJ:      14332.0  KL5DX        SOUP 5                         1537Z';
   VHF     = 'DX de N4RJ:     144200.0  KL5DX        SSB                            1537Z';
   TOPBAND = 'DX de N4RJ:       1824.5  KL5DX        CW                             1537Z';
   BADCALL = 'DX de N4RJ:      14332.0  12345        USB                            1537Z';

// Read a fixed AnsiChar array the way every consumer of these fields reads it:
// as a NUL-terminated C string.
function CStr(const A: array of AnsiChar): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to High(A) do
      begin
      if A[i] = #0 then
         begin
         Exit;
         end;
      Result := Result + Char(A[i]);
      end;
end;

// The same view of a CallString field.  Necessary, not merely convenient: see
// Test_SourceCall_LengthByteQuirk -- on an ordinary line FSourceCall's LENGTH
// byte is never written, so reading it as a Pascal string yields ''.
//
// TAKES A POINTER, DELIBERATELY.  The obvious spelling -- `const S: CallString`
// and then `@S[1]` inside -- does NOT work, and measurably so: a ShortString
// passed by const is copied only up to its LENGTH BYTE, so with that byte at 0
// the callee's copy holds no characters at all and @S[1] reads stack garbage.
// (Measured under D12: 'N4RJ' in the record, two junk bytes in the callee.)
// A field whose length byte lies can only be read through a pointer to the
// field itself.
function CallCStr(P: PAnsiChar): string;
begin
   Result := string(P);
end;

{ ---- REAL: the ordinary line --------------------------------------------- }

procedure TDXSpotParseTests.Test_PlainSpot_Frequency;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_PlainSpot_Frequency');
   CheckTrue(ParseDXSpotLine(PLAIN, spot), 'line decodes');
   // "14332.0" kHz -> Hz.  Only the FIRST decimal digit is read; the decoder
   // multiplies by 100 and stops, which is why 100 Hz is its resolution.
   CheckEquals(14332000, spot.FFrequency, 'frequency in Hz');
   CheckEquals('14332.0', CStr(spot.FFreqString), 'frequency text as sent');
end;

procedure TDXSpotParseTests.Test_PlainSpot_Call;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_PlainSpot_Call');
   CheckTrue(ParseDXSpotLine(PLAIN, spot), 'line decodes');
   CheckEquals('KL5DX', string(spot.FCall), 'spotted call');
end;

procedure TDXSpotParseTests.Test_PlainSpot_SourceCall;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_PlainSpot_SourceCall');
   CheckTrue(ParseDXSpotLine(PLAIN, spot), 'line decodes');
   CheckEquals('N4RJ', CallCStr(@spot.FSourceCall[1]), 'spotter, read as C string');
end;

procedure TDXSpotParseTests.Test_PlainSpot_Notes;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_PlainSpot_Notes');
   CheckTrue(ParseDXSpotLine(PLAIN, spot), 'line decodes');
   // 30 columns of comment, trailing blanks and all -- the decoder copies the
   // fixed field width rather than trimming.
   CheckEquals(30, Length(CStr(spot.FNotes)), 'note is the whole 30-col field');
   CheckEquals('USB', Trim(CStr(spot.FNotes)), 'comment text');
end;

procedure TDXSpotParseTests.Test_PlainSpot_NoQSX;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_PlainSpot_NoQSX');
   CheckTrue(ParseDXSpotLine(PLAIN, spot), 'line decodes');
   CheckEquals(0, spot.FQSXFrequency, 'no QSX in a plain comment');
end;

{ ---- REAL: the long-spotter line, the one case that moves the columns ----- }

procedure TDXSpotParseTests.Test_LongSpotter_ShiftsCallColumn;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_LongSpotter_ShiftsCallColumn');
   // "3V/KF5EYY-#:" overruns the 10-column spotter field, so the frequency and
   // the DX call each sit one column right of where they normally do.  This is
   // the ONLY shape in 198,979 captured lines that exercises the Offset logic;
   // without it the four `Offset :=` tests in the decoder are dead code under
   // test.
   CheckTrue(ParseDXSpotLine(LONGSPTR, spot), 'line decodes');
   CheckEquals('PA3DZM', string(spot.FCall), 'spotted call, shifted right by one');
end;

procedure TDXSpotParseTests.Test_LongSpotter_Frequency;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_LongSpotter_Frequency');
   CheckTrue(ParseDXSpotLine(LONGSPTR, spot), 'line decodes');
   CheckEquals(14007000, spot.FFrequency, 'frequency survives the shift');
end;

procedure TDXSpotParseTests.Test_LongSpotter_SourceCallHasLength;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_LongSpotter_SourceCallHasLength');
   CheckTrue(ParseDXSpotLine(LONGSPTR, spot), 'line decodes');
   CheckEquals('3V/KF5EYY-#', CallCStr(@spot.FSourceCall[1]), 'spotter, C string');
end;

procedure TDXSpotParseTests.Test_SourceCall_LengthByteQuirk;
var
   plainSpot, longSpot: TSpotRecord;
begin
   BeginTest('Test_SourceCall_LengthByteQuirk');
   // PINS A KNOWN DEFECT, unchanged from D7 (verified in the D7 tree, tagged
   // "4.92.6").  SetLength on FSourceCall is guarded by "next column is not a
   // space" while the character copy is not, so on the ORDINARY line -- where
   // the spotter field IS blank-padded -- the length byte stays 0 and the
   // spotter reads as an empty Pascal string.  It has never shown because
   // every consumer reads @FSourceCall[1], i.e. as a C string.  Assigning
   // FSourceCall to another CallString, or passing it to anything expecting a
   // Pascal string, silently yields ''.
   CheckTrue(ParseDXSpotLine(PLAIN, plainSpot), 'plain line decodes');
   CheckEquals(0, Length(plainSpot.FSourceCall),
               'padded spotter: length byte NOT written (defect, pinned)');
   CheckEquals('N4RJ', CallCStr(@plainSpot.FSourceCall[1]),
               'the characters are there all the same');

   CheckTrue(ParseDXSpotLine(LONGSPTR, longSpot), 'long-spotter line decodes');
   CheckEquals(11, Length(longSpot.FSourceCall),
               'unpadded spotter: length byte IS written');
end;

{ ---- REAL: QSX ------------------------------------------------------------ }

procedure TDXSpotParseTests.Test_QSX_WithDecimal;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_QSX_WithDecimal');
   CheckTrue(ParseDXSpotLine(QSXDEC, spot), 'line decodes');
   CheckEquals(7105000, spot.FFrequency, 'transmit frequency');
   CheckEquals(7275100, spot.FQSXFrequency, 'QSX 7275.10 kHz -> Hz');
end;

procedure TDXSpotParseTests.Test_QSX_WholeKilohertz;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_QSX_WholeKilohertz');
   CheckTrue(ParseDXSpotLine(QSXWHOLE, spot), 'line decodes');
   CheckEquals(7240000, spot.FFrequency, 'transmit frequency');
   // "QSX 7082" with no decimal point: kHz, and the trailing " QRV" ends it.
   CheckEquals(7082000, spot.FQSXFrequency, 'QSX 7082 kHz -> Hz');
end;

procedure TDXSpotParseTests.Test_QSX_OutOfBandIsDropped;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_QSX_OutOfBandIsDropped');
   // SYNTHETIC: the QSX branch -- and ONLY the QSX branch -- runs the result
   // through CalculateBandMode and throws it away if it lands outside every
   // ham band.  5000 kHz is in no band.
   CheckTrue(ParseDXSpotLine(
      'DX de K3WJV:      7105.0  DL1GLH       QSX 5000.00                    0126Z',
      spot), 'line decodes');
   CheckEquals(0, spot.FQSXFrequency, 'out-of-band QSX discarded');
end;

{ ---- UP n ----------------------------------------------------------------- }

procedure TDXSpotParseTests.Test_UP_WithSpace;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_UP_WithSpace');
   CheckTrue(ParseDXSpotLine(UPSPACE, spot), 'line decodes');
   CheckEquals(21023000, spot.FFrequency, 'transmit frequency');
   CheckEquals(21025000, spot.FQSXFrequency, '"UP 2" = 2 kHz up');
end;

procedure TDXSpotParseTests.Test_UP_NoSpace_SingleDigit;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_UP_NoSpace_SingleDigit');
   // THE REGRESSION PIN.  The decoder used to enumerate five literal tokens,
   // UP1..UP5, plus a separate space-form block.  "UP7" matched neither: the
   // QSX was silently dropped and the operator called on the DX's own
   // frequency.  Reading the number instead of the spelling is the fix.
   CheckTrue(ParseDXSpotLine(UP7, spot), 'line decodes');
   CheckEquals(14339000, spot.FQSXFrequency, '"UP7" = 7 kHz up');
end;

procedure TDXSpotParseTests.Test_UP_NoSpace_TwoDigits;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_UP_NoSpace_TwoDigits');
   // Same defect, the other half: no two-digit token was ever listed, so
   // "UP10" was dropped however it was written.
   CheckTrue(ParseDXSpotLine(UP10, spot), 'line decodes');
   CheckEquals(14342000, spot.FQSXFrequency, '"UP10" = 10 kHz up');
end;

procedure TDXSpotParseTests.Test_UP_WithSpace_TwoDigits;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_UP_WithSpace_TwoDigits');
   CheckTrue(ParseDXSpotLine(UPSP10, spot), 'line decodes');
   CheckEquals(14342000, spot.FQSXFrequency, '"UP 10" = 10 kHz up');
end;

procedure TDXSpotParseTests.Test_UP_InsideAWordIsNotQSX;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_UP_InsideAWordIsNotQSX');
   // The left word boundary earns its keep: SOUP / PUP / CUP appear in real
   // comments and must not be read as a QSX instruction.
   CheckTrue(ParseDXSpotLine(SOUP, spot), 'line decodes');
   CheckEquals(0, spot.FQSXFrequency, '"SOUP 5" is not "UP 5"');
end;

procedure TDXSpotParseTests.Test_UP_InCallsignIsNotQSX;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_UP_InCallsignIsNotQSX');
   // REAL line: UP0L is a callsign, in the CALL field.  The UP scan covers the
   // comment columns only (39..65), which is what keeps this from being read
   // as "up 0".
   CheckTrue(ParseDXSpotLine(UPCALL, spot), 'line decodes');
   CheckEquals('UP0L', string(spot.FCall), 'the call is UP0L');
   CheckEquals(0, spot.FQSXFrequency, 'a call is not a QSX instruction');
end;

{ ---- frequency range ------------------------------------------------------ }

procedure TDXSpotParseTests.Test_Frequency_VHF;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_Frequency_VHF');
   // Six digits before the point still land the point on column 22, because
   // the field is right-justified.  This is what makes the fixed columns work.
   CheckTrue(ParseDXSpotLine(VHF, spot), 'line decodes');
   CheckEquals(144200000, spot.FFrequency, '144.2 MHz');
end;

procedure TDXSpotParseTests.Test_Frequency_160m;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_Frequency_160m');
   CheckTrue(ParseDXSpotLine(TOPBAND, spot), 'line decodes');
   CheckEquals(1824500, spot.FFrequency, '1824.5 kHz');
end;

{ ---- rejection and degenerate input --------------------------------------- }

procedure TDXSpotParseTests.Test_BadCallSyntaxRejected;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_BadCallSyntaxRejected');
   // The one validation the decoder does perform: GoodCallSyntax on the DX
   // call.  "12345" has no letters.
   CheckFalse(ParseDXSpotLine(BADCALL, spot), 'a call with no letters is rejected');
end;

procedure TDXSpotParseTests.Test_TruncatedLineAccepted_KNOWN_DEFECT;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_TruncatedLineAccepted_KNOWN_DEFECT');
   // REAL: exactly one of the 198,979 captured lines is cut off like this
   // (a node dropping mid-write).  The call-scan loop never matches, so
   // GoodCallSyntax is never reached and the decoder reports SUCCESS with an
   // empty call and a zero frequency.  ProcessDX then dupe-checks and band-maps
   // that empty spot.  Pinned, not fixed: rejecting it is a behaviour change
   // and belongs in its own commit.
   CheckTrue(ParseDXSpotLine(TRUNC, spot), 'truncated line reports success (defect)');
   CheckEquals('', string(spot.FCall), 'with no call at all');
   CheckEquals(0, spot.FFrequency, 'and no frequency');
end;

procedure TDXSpotParseTests.Test_EmptyLineAccepted_KNOWN_DEFECT;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_EmptyLineAccepted_KNOWN_DEFECT');
   // Same defect at its limit.  It also proves the NUL fill holds: an empty
   // line must not read off the end of the buffer.
   CheckTrue(ParseDXSpotLine('', spot), 'empty line reports success (defect)');
   CheckEquals(0, spot.FFrequency, 'nothing decoded');
end;

{ ---- the time stamp ------------------------------------------------------- }

procedure TDXSpotParseTests.Test_Time_Parsed;
var
   minuteOfDay: integer;
begin
   BeginTest('Test_Time_Parsed');
   CheckTrue(ParseDXSpotTimeUTC(PLAIN, minuteOfDay), '1537Z is a time stamp');
   CheckEquals(15 * 60 + 37, minuteOfDay, 'minutes since midnight UTC');
end;

procedure TDXSpotParseTests.Test_Time_MissingZRejected;
var
   minuteOfDay: integer;
begin
   BeginTest('Test_Time_MissingZRejected');
   // The 'Z' in the fixed column is the entire validation this format has.
   // Without it ProcessDX falls back to the local clock.
   CheckFalse(ParseDXSpotTimeUTC(TRUNC, minuteOfDay), 'truncated line has no stamp');
   CheckFalse(ParseDXSpotTimeUTC('', minuteOfDay), 'empty line has no stamp');
end;

procedure TDXSpotParseTests.Test_Time_TrailingGridStillParses;
var
   minuteOfDay: integer;
begin
   BeginTest('Test_Time_TrailingGridStillParses');
   // REAL: some nodes append the spotter's grid after the stamp.  The stamp is
   // read by column, so the tail is irrelevant.
   CheckTrue(ParseDXSpotTimeUTC(UPBIG, minuteOfDay), '1917Z followed by " FM28"');
   CheckEquals(19 * 60 + 17, minuteOfDay, 'minutes since midnight UTC');
end;

{ -------------------------------------------------------------------------- }

procedure TDXSpotParseTests.RunAllTests;
begin
   Test_PlainSpot_Frequency;
   Test_PlainSpot_Call;
   Test_PlainSpot_SourceCall;
   Test_PlainSpot_Notes;
   Test_PlainSpot_NoQSX;

   Test_LongSpotter_ShiftsCallColumn;
   Test_LongSpotter_Frequency;
   Test_LongSpotter_SourceCallHasLength;
   Test_SourceCall_LengthByteQuirk;

   Test_QSX_WithDecimal;
   Test_QSX_WholeKilohertz;
   Test_QSX_OutOfBandIsDropped;

   Test_UP_WithSpace;
   Test_UP_NoSpace_SingleDigit;
   Test_UP_NoSpace_TwoDigits;
   Test_UP_WithSpace_TwoDigits;
   Test_UP_InsideAWordIsNotQSX;
   Test_UP_InCallsignIsNotQSX;

   Test_Frequency_VHF;
   Test_Frequency_160m;

   Test_BadCallSyntaxRejected;
   Test_TruncatedLineAccepted_KNOWN_DEFECT;
   Test_EmptyLineAccepted_KNOWN_DEFECT;

   Test_Time_Parsed;
   Test_Time_MissingZRejected;
   Test_Time_TrailingGridStillParses;
end;

end.

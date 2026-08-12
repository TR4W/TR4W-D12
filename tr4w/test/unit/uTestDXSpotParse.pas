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
      procedure Test_TruncatedLineRejected;
      procedure Test_EmptyLineRejected;

      // ParseSplitHint -- the comment grammar, tested on comments directly
      procedure CheckHint(const Comment: string; BaseHz: integer; Mode: ModeType;
                          ExpectHz: integer; const ctx: string);
      procedure Test_Hint_QSX_Kilohertz;
      procedure Test_Hint_QSX_Megahertz;
      procedure Test_Hint_QSX_DottedMegahertz;
      procedure Test_Hint_QSX_SpelledUnit;
      procedure Test_Hint_QSX_SmallValueIsAnOffset;
      procedure Test_Hint_QSX_WithDirection;
      procedure Test_Hint_CaseInsensitive;
      procedure Test_Hint_Listening_Absolute;
      procedure Test_Hint_Listening_Synonyms;
      procedure Test_Hint_RX_Absolute;
      procedure Test_Hint_Split_UpAndDown;
      procedure Test_Hint_Down_Synonyms;
      procedure Test_Hint_Range_TakesLowEnd;
      procedure Test_Hint_Postfix;
      procedure Test_Hint_FractionalOffset;
      procedure Test_Hint_AbsoluteAfterDirection;
      procedure Test_Hint_AutoSplit_CW;
      procedure Test_Hint_AutoSplit_Phone;
      procedure Test_Hint_AutoSplit_BareSplit;
      procedure Test_Hint_AutoSplit_CommentModeWins;
      procedure Test_Hint_AutoSplit_NotOnDigital;
      procedure Test_Hint_AutoSplit_NotWhenModeUnknown;
      procedure Test_Hint_ExplicitBeatsAutoSplit;
      procedure Test_Hint_Reject_NoKeyword;
      procedure Test_Hint_Reject_NotSplit;
      procedure Test_Hint_Reject_PileUp;
      procedure Test_Hint_Reject_GridSquares;
      procedure Test_Hint_Reject_GridEndingInUP;
      procedure Test_Hint_Reject_OversizedOffset;
      procedure Test_Hint_Reject_SignalReports;
      procedure Test_Hint_Reject_Junk;
      procedure Test_Hint_Reject_OutOfBand;
      procedure Test_Hint_Reject_BareR;
      procedure Test_Hint_Reject_PhrasalVerbs;
      procedure Test_Hint_Reject_GluedIntroducer;
      procedure Test_Hint_FillerWordBeforeFrequency;
      procedure Test_PasswordPrompt_Recognised;
      procedure Test_PasswordPrompt_SmearedIntoTheNextChunk;
      procedure Test_PasswordPrompt_CorpusLinesDoNotTrigger;
      procedure Test_PasswordPrompt_SpotTrafficDoesNotTrigger;
      procedure Test_LoginPrompt_Recognised;
      procedure Test_LoginPrompt_SmearedIntoTheNextChunk;
      procedure Test_LoginPrompt_YieldsToAPasswordPromptOnTheSameLine;
      procedure Test_LoginPrompt_OrdinaryTrafficDoesNotTrigger;

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
   // REGRESSION PIN for a defect that survived from D7 (tagged "4.92.6" and
   // identical in the D7 tree): SetLength on FSourceCall was guarded by "next
   // column is not a space" while the character copy was not.  On the ORDINARY
   // blank-padded line -- 198,759 of the 198,979 captured -- the characters
   // landed in the field and the length byte stayed 0, so the spotter read as
   // '' as a Pascal string and correctly only through @FSourceCall[1].
   //
   // Both readings must now agree, which is the whole point.
   CheckTrue(ParseDXSpotLine(PLAIN, plainSpot), 'plain line decodes');
   CheckEquals(4, Length(plainSpot.FSourceCall),
               'padded spotter: length byte written');
   CheckEquals('N4RJ', string(plainSpot.FSourceCall), 'as a Pascal string');
   CheckEquals('N4RJ', CallCStr(@plainSpot.FSourceCall[1]), 'as a C string');

   CheckTrue(ParseDXSpotLine(LONGSPTR, longSpot), 'long-spotter line decodes');
   CheckEquals(11, Length(longSpot.FSourceCall), 'unpadded spotter length');
   CheckEquals('3V/KF5EYY-#', string(longSpot.FSourceCall), 'as a Pascal string');
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

procedure TDXSpotParseTests.Test_TruncatedLineRejected;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_TruncatedLineRejected');
   // REGRESSION PIN.  REAL: exactly one of the 198,979 captured lines is cut off
   // like this, a node dropping mid-write.  The call-scan loop never matches, so
   // GoodCallSyntax -- the only validation there is -- was never reached, and
   // the decoder used to report SUCCESS.  ProcessDX would then dupe-check,
   // band-map and display a spot with an empty callsign and a zero frequency.
   CheckFalse(ParseDXSpotLine(TRUNC, spot), 'a line with no call is not a spot');
end;

procedure TDXSpotParseTests.Test_EmptyLineRejected;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_EmptyLineRejected');
   // The same rule at its limit.  It also proves the NUL fill holds: an empty
   // line must not read off the end of the buffer.
   CheckFalse(ParseDXSpotLine('', spot), 'an empty line is not a spot');
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

{ ---- ParseSplitHint: the comment grammar ---------------------------------- }

// ExpectHz = 0 means "no hint": the grammar must decline rather than guess.
procedure TDXSpotParseTests.CheckHint(const Comment: string; BaseHz: integer;
                                      Mode: ModeType; ExpectHz: integer;
                                      const ctx: string);
var
   hz: integer;
   found: boolean;
begin
   found := ParseSplitHint(AnsiString(Comment), BaseHz, Mode, hz);
   if ExpectHz = 0 then
      begin
      CheckFalse(found, ctx + ' -- must not be read as a split');
      CheckEquals(0, hz, ctx + ' -- and must leave the frequency alone');
      end
   else
      begin
      CheckTrue(found, ctx + ' -- must be recognised');
      CheckEquals(ExpectHz, hz, ctx);
      end;
end;

procedure TDXSpotParseTests.Test_Hint_QSX_Kilohertz;
begin
   BeginTest('Test_Hint_QSX_Kilohertz');
   CheckHint('QSX 7275.10', 7105000, CW, 7275100, 'QSX 7275.10 kHz');
   CheckHint('QSX 7082 QRV', 7240000, CW, 7082000, 'QSX 7082 kHz');
   CheckHint('QSX 28040.942', 28020000, CW, 28040942, 'QSX to the Hz');
end;

procedure TDXSpotParseTests.Test_Hint_QSX_Megahertz;
begin
   BeginTest('Test_Hint_QSX_Megahertz');
   // REAL comments, all of which the old decoder dropped: an integer part under
   // 1000 with a decimal point is MHz, because no ham band is at 14 kHz.
   CheckHint('QSX 14.030', 14025000, CW, 14030000, 'QSX 14.030 MHz');
   CheckHint('QSX 24.9015', 24891000, CW, 24901500, 'QSX 24.9015 MHz');
   CheckHint('QSX 28.029', 28029000, CW, 28029000, 'QSX 28.029 MHz');
end;

procedure TDXSpotParseTests.Test_Hint_QSX_DottedMegahertz;
begin
   BeginTest('Test_Hint_QSX_DottedMegahertz');
   // REAL: European-style grouping, MHz.kHz.Hz.  The old decoder produced the
   // spot's OWN frequency for these -- its running divisor reached zero and
   // zeroed the result, which then fell under the "small value is an offset"
   // rule and was added to the base.  Silently wrong, not dropped.
   CheckHint('USB QSX 21.290.000 UP 5-10', 21250000, Phone, 21290000,
             'QSX 21.290.000');
   CheckHint('CW QSX 18.072.411', 18069000, CW, 18072411, 'QSX 18.072.411');
   CheckHint('QSX 24.899.87', 24897700, CW, 24899870, 'QSX 24.899.87');
end;

procedure TDXSpotParseTests.Test_Hint_QSX_SpelledUnit;
begin
   BeginTest('Test_Hint_QSX_SpelledUnit');
   // REAL.  Without honouring the spelled-out unit, "18.072" after a direction
   // reads as an 18 kHz offset and lands 15 kHz from the DX.
   CheckHint('QSX UP 18.072 MHZ  STRONG SIGN', 18069000, CW, 18072000,
             'QSX UP 18.072 MHZ');
end;

procedure TDXSpotParseTests.Test_Hint_QSX_SmallValueIsAnOffset;
begin
   BeginTest('Test_Hint_QSX_SmallValueIsAnOffset');
   // The original decoder's rule, deliberately preserved: under 10 kHz after an
   // introducer is a distance, not a frequency.  Real comments rely on it.
   CheckHint('QSX 5', 14025000, CW, 14030000, 'QSX 5 = 5 kHz up');
   CheckHint('LISTENING 5 UP.', 50115000, Phone, 50120000, 'LISTENING 5');
end;

procedure TDXSpotParseTests.Test_Hint_QSX_WithDirection;
begin
   BeginTest('Test_Hint_QSX_WithDirection');
   CheckHint('QSX UP 5', 14025000, CW, 14030000, 'QSX UP 5');
   CheckHint('QSX UP1', 14025000, CW, 14026000, 'QSX UP1');
   CheckHint('LSN UP 5', 14025000, CW, 14030000, 'LSN UP 5');
end;

procedure TDXSpotParseTests.Test_Hint_CaseInsensitive;
begin
   BeginTest('Test_Hint_CaseInsensitive');
   // Nodes are not consistent about case, and TR4W no longer upper-cases the
   // line buffer in place before matching, so this is a real risk rather than a
   // theoretical one.
   CheckHint('qsx 7275.10', 7105000, CW, 7275100, 'lower-case qsx');
   CheckHint('Split Up 5', 14025000, CW, 14030000, 'mixed-case Split Up');
   CheckHint('listening 7093.5', 7203000, CW, 7093500, 'lower-case listening');
end;

procedure TDXSpotParseTests.Test_Hint_Listening_Absolute;
begin
   BeginTest('Test_Hint_Listening_Absolute');
   // REAL: the listening forms carry an absolute frequency at least as often as
   // an offset.  None of these were recognised at all before.
   CheckHint('LSN 7217', 7086900, CW, 7217000, 'LSN 7217');
   CheckHint('LISTENING 7093.5', 7203000, CW, 7093500, 'LISTENING 7093.5');
end;

procedure TDXSpotParseTests.Test_Hint_Listening_Synonyms;
begin
   BeginTest('Test_Hint_Listening_Synonyms');
   CheckHint('LISTENING UP 2', 7005000, CW, 7007000, 'LISTENING');
   CheckHint('LISTENS UP 2', 7005000, CW, 7007000, 'LISTENS');
   CheckHint('LISTEN UP 2', 7005000, CW, 7007000, 'LISTEN');
   CheckHint('LSTN UP 2', 7005000, CW, 7007000, 'LSTN');
   CheckHint('LSN UP 2', 7005000, CW, 7007000, 'LSN');
end;

procedure TDXSpotParseTests.Test_Hint_RX_Absolute;
begin
   BeginTest('Test_Hint_RX_Absolute');
   CheckHint('RX 14205', 14195000, Phone, 14205000, 'RX with a frequency');
end;

procedure TDXSpotParseTests.Test_Hint_Split_UpAndDown;
begin
   BeginTest('Test_Hint_Split_UpAndDown');
   CheckHint('CQ DX SPLIT UP 5', 14025000, CW, 14030000, 'SPLIT UP 5');
   CheckHint('SPLIT DOWN 2', 14025000, CW, 14023000, 'SPLIT DOWN 2');
   CheckHint('SPLT UP 3', 14025000, CW, 14028000, 'SPLT');
   CheckHint('SPL UP 3', 14025000, CW, 14028000, 'SPL');
end;

procedure TDXSpotParseTests.Test_Hint_Down_Synonyms;
begin
   BeginTest('Test_Hint_Down_Synonyms');
   CheckHint('DOWN 2', 14025000, CW, 14023000, 'DOWN 2');
   CheckHint('DWN 2', 14025000, CW, 14023000, 'DWN 2');
   CheckHint('QSX DOWN 1.5', 14025000, CW, 14023500, 'QSX DOWN 1.5');
end;

procedure TDXSpotParseTests.Test_Hint_Range_TakesLowEnd;
begin
   BeginTest('Test_Hint_Range_TakesLowEnd');
   // "Listening 5 to 10 up" means start at the bottom of the range.
   CheckHint('UP 5-10', 14025000, CW, 14030000, 'UP 5-10 takes the 5');
   CheckHint('UP 5 - 10', 14025000, CW, 14030000, 'spaced range');
end;

procedure TDXSpotParseTests.Test_Hint_Postfix;
begin
   BeginTest('Test_Hint_Postfix');
   // REAL and common: the number comes FIRST.  "5UP" with no space has to work
   // too, while the grid square DM33UP must not (see Test_Hint_Reject_*).
   CheckHint('5 UP', 50115000, Phone, 50120000, '5 UP');
   CheckHint('WRKD 5UP', 14025000, CW, 14030000, '5UP');
   CheckHint('TNX FOR GOOD QSO, 5 UP', 14025000, CW, 14030000, 'trailing 5 UP');
   CheckHint('WRKD 2.5 UP. GOOD COPY', 7005000, CW, 7007500, '2.5 UP');
   CheckHint('CALLING CQ TNX 1 UP', 28025000, CW, 28026000, '1 UP');
end;

procedure TDXSpotParseTests.Test_Hint_FractionalOffset;
begin
   BeginTest('Test_Hint_FractionalOffset');
   // REAL, and the old decoder truncated every one of these to whole kHz: it
   // read the digits before the point and stopped, so "UP 1.5" tuned 500 Hz low.
   CheckHint('UP 1.5', 24892000, CW, 24893500, 'UP 1.5');
   CheckHint('UP 5.9', 14025000, CW, 14030900, 'UP 5.9');
   CheckHint('TNX NEW BAND. CW UP 1.34', 21061000, CW, 21062340, 'UP 1.34');
   CheckHint('CN84LV<>AH48 UP1.95K', 24891000, CW, 24892950, 'UP1.95K');
end;

procedure TDXSpotParseTests.Test_Hint_AbsoluteAfterDirection;
begin
   BeginTest('Test_Hint_AbsoluteAfterDirection');
   // REAL: "UP 1829.5" is a frequency, not a 1,829 kHz offset.  The old decoder
   // added it to the base and reported 3655 kHz -- a different band.
   CheckHint('UP 1829.5', 1826000, CW, 1829500, 'UP <absolute kHz>');
   CheckHint('UP 7259.1', 7105000, CW, 7259100, 'UP 7259.1');
end;

procedure TDXSpotParseTests.Test_Hint_AutoSplit_CW;
begin
   BeginTest('Test_Hint_AutoSplit_CW');
   // AUTO SPLIT: bare UP is 1 kHz up on CW.  76 bare "UP"s in the capture, all
   // of which the old decoder ignored.
   CheckHint('UP', 28005000, CW, 28006000, 'bare UP on CW');
   CheckHint('UP - LOUD', 21005000, CW, 21006000, 'UP with punctuation');
   CheckHint('DOWN', 28005000, CW, 28004000, 'bare DOWN on CW');
end;

procedure TDXSpotParseTests.Test_Hint_AutoSplit_Phone;
begin
   BeginTest('Test_Hint_AutoSplit_Phone');
   CheckHint('UP', 14250000, Phone, 14255000, 'bare UP on phone');
   CheckHint('UP', 29600000, FM, 29605000, 'bare UP on FM');
end;

procedure TDXSpotParseTests.Test_Hint_AutoSplit_BareSplit;
begin
   BeginTest('Test_Hint_AutoSplit_BareSplit');
   // REAL: a comment that is just the word SPLIT.  By convention that means up.
   CheckHint('SPLIT', 21005000, CW, 21006000, 'bare SPLIT on CW');
   CheckHint('SPLIT', 14250000, Phone, 14255000, 'bare SPLIT on phone');
end;

procedure TDXSpotParseTests.Test_Hint_AutoSplit_CommentModeWins;
begin
   BeginTest('Test_Hint_AutoSplit_CommentModeWins');
   // The band plan says this 160 m frequency has no mode at all; the spotter
   // says CW.  REAL line: "UP TU NEW ONE 160M! CW" on 1826.5.
   CheckHint('UP TU NEW ONE 160M! CW', 1826500, NoMode, 1827500,
             'comment mode supplies what the band plan cannot');
   // And where they disagree, the comment still wins.
   CheckHint('CW UP', 14250000, Phone, 14251000, 'comment CW beats band-plan phone');
end;

procedure TDXSpotParseTests.Test_Hint_AutoSplit_NotOnDigital;
begin
   BeginTest('Test_Hint_AutoSplit_NotOnDigital');
   // There is no auto-split convention on FT8, and comments on those spots are
   // full of the word UP for other reasons.
   CheckHint('FT8 -13DB UP', 14074000, Digital, 0, 'bare UP on FT8');
   CheckHint('RTTY UP', 14080000, Digital, 0, 'bare UP on RTTY');
end;

procedure TDXSpotParseTests.Test_Hint_AutoSplit_NotWhenModeUnknown;
begin
   BeginTest('Test_Hint_AutoSplit_NotWhenModeUnknown');
   // No mode in the comment and none from the band plan: no convention to
   // apply, so nothing is invented.
   CheckHint('UP', 1826500, NoMode, 0, 'bare UP with no mode anywhere');
end;

procedure TDXSpotParseTests.Test_Hint_ExplicitBeatsAutoSplit;
begin
   BeginTest('Test_Hint_ExplicitBeatsAutoSplit');
   // REAL: "CW SPLIT QSX 28.027.800".  Read strictly left to right, the bare
   // SPLIT answers first and the exact frequency four words later is never
   // reached.  A stated frequency must always win.
   CheckHint('CW SPLIT QSX 28.027.800', 28023000, CW, 28027800,
             'the stated QSX, not the SPLIT default');
   CheckHint('USB QSX 24.970.000 SPLIT UP', 24960000, Phone, 24970000,
             'stated frequency ahead of a trailing SPLIT UP');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_NoKeyword;
begin
   BeginTest('Test_Hint_Reject_NoKeyword');
   CheckHint('', 14025000, CW, 0, 'empty comment');
   CheckHint('CW 12 DB 22 WPM CQ', 14025000, CW, 0, 'a skimmer comment');
   CheckHint('USB', 14250000, Phone, 0, 'just a mode');
   CheckHint('ARRL INTERNATIONAL DX CONTEST', 14025000, CW, 0, 'a contest name');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_NotSplit;
begin
   BeginTest('Test_Hint_Reject_NotSplit');
   // REAL: "NOT SPLIT" is in the capture.  The auto-split default would
   // otherwise turn a denial into a QSX.
   CheckHint('NOT SPLIT', 14025000, CW, 0, 'NOT SPLIT');
   CheckHint('NO SPLIT', 14025000, CW, 0, 'NO SPLIT');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_PileUp;
begin
   BeginTest('Test_Hint_Reject_PileUp');
   // REAL, four times.  Ordinary English that ends in the word UP.
   CheckHint('PILE UP', 28762000, Phone, 0, 'PILE UP is not a split');
   CheckHint('WHATS UP', 28762000, Phone, 0, 'WHATS UP is not a split');
   CheckHint('SOUP 5', 14025000, CW, 0, 'UP inside a word');
   CheckHint('UPSHUR COUNTY', 14025000, CW, 0, 'a word that starts with UP');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_GridSquares;
begin
   BeginTest('Test_Hint_Reject_GridSquares');
   // THE EXPENSIVE ONE.  Letters and digits tokenize separately, so a grid
   // square DN70 offers up a token spelled DN.  Every single "DN" in the
   // 198,979-line capture is a grid square, never "down" -- which is why DN is
   // not a synonym.  Before that was measured, 6 m grid comments decoded as
   // 70 kHz down.
   CheckHint('DN70MQ<>BL01XI', 50313000, Phone, 0, 'DN70 is a grid');
   CheckHint('USB EN62CB -> DN11', 28565000, Phone, 0, 'DN11 is a grid');
   CheckHint('FT8 -13DB FROM DN13 551HZ', 28074000, Digital, 0, 'DN13 is a grid');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_GridEndingInUP;
begin
   BeginTest('Test_Hint_Reject_GridEndingInUP');
   // REAL: grid squares whose sub-square happens to be UP.  The postfix form
   // "5UP" is legitimate, so the rule cannot simply be "no glued UP" -- it is
   // that a keyword may follow a number only when the number starts the word.
   CheckHint('FT8 FM05PN -> DM33UP TNX', 14074000, Digital, 0, 'DM33UP');
   CheckHint('USB EM84UR -> GF29UP', 28450000, Phone, 0, 'GF29UP');
   CheckHint('FT8 -18  FN32DR<>JN87UP', 14074000, Digital, 0, 'JN87UP');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_OversizedOffset;
begin
   BeginTest('Test_Hint_Reject_OversizedOffset');
   // REAL: "UP 200-205" on 14195.  200 kHz up is 14395, outside the band; the
   // spotter almost certainly meant 14200-14205 and wrote the last three digits.
   // Ambiguous, so nothing is emitted -- the old decoder emitted 14395.
   CheckHint('UP 200-205', 14195000, Phone, 0, 'a 200 kHz "offset"');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_SignalReports;
begin
   BeginTest('Test_Hint_Reject_SignalReports');
   // REAL: "59 TU 73 UP LOUD OHIO".  The postfix form would read the 73 as an
   // offset.  Nobody splits 73 kHz, so the number is refused -- and the bare UP
   // that remains still gets the auto-split default, which is the right answer.
   CheckHint('59 TU 73 UP LOUD OHIO', 14250000, Phone, 14255000,
             '73 is not an offset, but UP is still UP');
   CheckHint('57 UP', 28450000, Phone, 28455000, '57 is not an offset');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_Junk;
begin
   BeginTest('Test_Hint_Reject_Junk');
   // REAL, all four: an introducer with nothing usable after it.  A bare
   // introducer is a missing frequency, not a convention, so it gets no guess.
   CheckHint('QSX ??? LSB', 14025000, CW, 0, 'QSX ???');
   CheckHint('QSX CQ CQ', 14025000, CW, 0, 'QSX CQ CQ');
   CheckHint('QSX!', 14025000, CW, 0, 'QSX with nothing after it');
   CheckHint('QSX UP, TNX QSO, 73...', 14025000, CW, 14026000,
             'QSX UP is a direction, and does get the default');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_OutOfBand;
begin
   BeginTest('Test_Hint_Reject_OutOfBand');
   // One band check for every form, which the old decoder applied to QSX only.
   CheckHint('QSX 5000.00', 7105000, CW, 0, '5 MHz is in no ham band');
   CheckHint('QSX 455 TNX', 7105000, CW, 0, '455 kHz is in no ham band');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_BareR;
begin
   BeginTest('Test_Hint_Reject_BareR');
   // "R" is NOT an introducer, on the evidence: every "R" and "RX" in the
   // capture is an FT8 report, "RX ONLY", or an initial.  Accepting bare R
   // would turn "R-17" into a QSX on 17 kHz -- and worse, "R 14205" style
   // false matches into a confident wrong frequency.
   CheckHint('DM78<>GF11 FT8 S-17 R-17 TNX', 14074000, Digital, 0, 'R-17');
   CheckHint('QRL NO RX???', 14025000, CW, 0, 'RX with no number');
   CheckHint('FT8 QG64KR<>DM61 -18 RX', 14074000, Digital, 0, 'RX at the end');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_PhrasalVerbs;
begin
   BeginTest('Test_Hint_Reject_PhrasalVerbs');
   // REAL, one occurrence each.  A verb ending in -ING or -ED before UP makes it
   // ordinary English, and the AUTO SPLIT default would otherwise answer with a
   // confident QSX for every one of them.
   CheckHint('MESSED UP - CALLING ON RX FREQ', 14025000, CW, 0, 'MESSED UP');
   CheckHint('COMING UP NICELY LSB', 3719400, Phone, 0, 'COMING UP');
   CheckHint('73 GL. WARMING UP', 24940000, Phone, 0, 'WARMING UP');
   CheckHint('BY #S NOW #1 GOING UP', 14255000, Phone, 0, 'GOING UP');
   CheckHint('WAMING UP FOR WPX', 14202500, Phone, 0, 'the misspelling too');

   // ...but only the GUESS is suppressed.  A stated distance is still read.
   CheckHint('WORKING UP 5', 14025000, CW, 14030000,
             'a stated distance survives the phrase guard');
end;

procedure TDXSpotParseTests.Test_Hint_Reject_GluedIntroducer;
begin
   BeginTest('Test_Hint_Reject_GluedIntroducer');
   // REAL: "3RX 4 ANT DIR" is VHF antenna talk -- three receive antennas.  Only
   // a DIRECTION may be glued to a preceding number ("5UP" is a real form);
   // "3RX" is not, and reading it as "receive on 4" moved the operator 4 kHz.
   CheckHint('3RX 4 ANT DIR', 144050000, CW, 0, '3RX is not RX');
   // The form this exception exists for still works.
   CheckHint('5UP', 14025000, CW, 14030000, '5UP is a real postfix');
end;

procedure TDXSpotParseTests.Test_Hint_FillerWordBeforeFrequency;
begin
   BeginTest('Test_Hint_FillerWordBeforeFrequency');
   // REAL: "LISTENING ON 7227.00 SPLIT LSB".  Requiring the number to follow the
   // introducer immediately meant the stated frequency was never reached, and
   // the trailing SPLIT then produced a 5 kHz guess instead.
   CheckHint('LISTENING ON 7227.00 SPLIT LSB', 7052300, Phone, 7227000,
             'a filler word between introducer and frequency');
   CheckHint('QSX AT 14205', 14195000, Phone, 14205000, 'QSX AT');
end;

{ -------------------------------------------------------------------------- }


{ ----------------------------------------------- the cluster password prompt --

  LineAsksForPassword decides when the operator's PASSWORD goes on the wire, so
  the negative cases matter more than the positive one. Every "must not trigger"
  line below is real traffic from the 209-file capture corpus rather than
  invented -- a false positive here transmits a secret to a public node, in the
  clear, as a command.                                                         }

procedure TDXSpotParseTests.Test_PasswordPrompt_Recognised;
begin
   BeginTest('Test_PasswordPrompt_Recognised');
   // HamAlert is the one node NY4I uses that actually challenges.
   CheckTrue(LineAsksForPassword('password: '), 'the bare HamAlert prompt');
   CheckTrue(LineAsksForPassword('Password:'), 'capitalised');
   CheckTrue(LineAsksForPassword('Enter password: '), 'with a lead-in');
end;

// Prompts carry no terminator, so they reach us joined to the next chunk -- the
// corpus has `login: nected to VE7CC-1:` verbatim. A whole-line match would
// fail on precisely the delivery this has to cope with.
procedure TDXSpotParseTests.Test_PasswordPrompt_SmearedIntoTheNextChunk;
begin
   BeginTest('Test_PasswordPrompt_SmearedIntoTheNextChunk');
   CheckTrue(LineAsksForPassword('password: Hello NY4I, this is HamAlert'),
             'a prompt with the following line stuck to it still counts');
end;

// Real corpus lines that mention passwords and MUST NOT cause a send.
procedure TDXSpotParseTests.Test_PasswordPrompt_CorpusLinesDoNotTrigger;
begin
   BeginTest('Test_PasswordPrompt_CorpusLinesDoNotTrigger');
   CheckFalse(LineAsksForPassword('Pse Set password on internet connects with set/password'),
              'the CC Cluster advice line -- no colon after "password"');
   CheckFalse(LineAsksForPassword('set/password w4afc'),
              'an operator setting their own password');
   CheckFalse(LineAsksForPassword('set/password'), 'the bare command');
end;

// The feed is public and runs for hours, so anything a user can type can arrive.
procedure TDXSpotParseTests.Test_PasswordPrompt_SpotTrafficDoesNotTrigger;
begin
   BeginTest('Test_PasswordPrompt_SpotTrafficDoesNotTrigger');
   CheckFalse(LineAsksForPassword('DX de NY4I:      14025.0  K1ABC        no password needed   1713Z'),
              'a spot comment mentioning a password');
   CheckFalse(LineAsksForPassword(''), 'an empty line');
   CheckFalse(LineAsksForPassword('login:'), 'the LOGIN prompt is not the password prompt');
end;


{ -------------------------------------------------- the cluster login prompt --

  `login:` only. It is a protocol token that survives translation -- the Spanish
  DXSpider node in the corpus prints its banner in three languages and still
  prompts in English. The prose forms are sysop text and DO get translated, so
  they are handled by a TIMEOUT in uTelnet rather than by widening this.        }

procedure TDXSpotParseTests.Test_LoginPrompt_Recognised;
begin
   BeginTest('Test_LoginPrompt_Recognised');
   CheckTrue(LineAsksForLogin('login:'), 'the bare DXSpider prompt');
   CheckTrue(LineAsksForLogin('login: '), 'with the trailing space nodes send');
   CheckTrue(LineAsksForLogin('Login:'), 'capitalised');
end;

procedure TDXSpotParseTests.Test_LoginPrompt_SmearedIntoTheNextChunk;
begin
   BeginTest('Test_LoginPrompt_SmearedIntoTheNextChunk');
   // Verbatim from the capture corpus: a prompt with no terminator, delivered
   // joined to the line that followed it.
   CheckTrue(LineAsksForLogin('login: nected to VE7CC-1:'),
             'a smeared prompt is still a prompt');
end;

// The case that would answer the WRONG prompt. Both can arrive in one delivery
// when the login prompt smears into what follows; replying with the callsign
// there would send it where the password was wanted -- and then the password
// would never be sent at all.
procedure TDXSpotParseTests.Test_LoginPrompt_YieldsToAPasswordPromptOnTheSameLine;
begin
   BeginTest('Test_LoginPrompt_YieldsToAPasswordPromptOnTheSameLine');
   CheckFalse(LineAsksForLogin('login: NY4I' + #13#10 + 'password:'),
              'a line carrying both prompts is the PASSWORD prompt');
   CheckTrue(LineAsksForPassword('login: NY4I' + #13#10 + 'password:'),
             'and the password matcher still sees it');
end;

procedure TDXSpotParseTests.Test_LoginPrompt_OrdinaryTrafficDoesNotTrigger;
begin
   BeginTest('Test_LoginPrompt_OrdinaryTrafficDoesNotTrigger');
   CheckFalse(LineAsksForLogin(''), 'an empty line');
   CheckFalse(LineAsksForLogin('DX de NY4I:      14025.0  K1ABC        tnx qso   1713Z'),
              'a spot');
   CheckFalse(LineAsksForLogin('Please enter your callsign'),
              'prose is deliberately NOT matched -- the timeout covers it');
end;

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
   Test_TruncatedLineRejected;
   Test_EmptyLineRejected;

   Test_Time_Parsed;
   Test_Time_MissingZRejected;
   Test_Time_TrailingGridStillParses;

   Test_Hint_QSX_Kilohertz;
   Test_Hint_QSX_Megahertz;
   Test_Hint_QSX_DottedMegahertz;
   Test_Hint_QSX_SpelledUnit;
   Test_Hint_QSX_SmallValueIsAnOffset;
   Test_Hint_QSX_WithDirection;
   Test_Hint_CaseInsensitive;
   Test_Hint_Listening_Absolute;
   Test_Hint_Listening_Synonyms;
   Test_Hint_RX_Absolute;
   Test_Hint_Split_UpAndDown;
   Test_Hint_Down_Synonyms;
   Test_Hint_Range_TakesLowEnd;
   Test_Hint_Postfix;
   Test_Hint_FractionalOffset;
   Test_Hint_AbsoluteAfterDirection;
   Test_Hint_AutoSplit_CW;
   Test_Hint_AutoSplit_Phone;
   Test_Hint_AutoSplit_BareSplit;
   Test_Hint_AutoSplit_CommentModeWins;
   Test_Hint_AutoSplit_NotOnDigital;
   Test_Hint_AutoSplit_NotWhenModeUnknown;
   Test_Hint_ExplicitBeatsAutoSplit;
   Test_Hint_Reject_NoKeyword;
   Test_Hint_Reject_NotSplit;
   Test_Hint_Reject_PileUp;
   Test_Hint_Reject_GridSquares;
   Test_Hint_Reject_GridEndingInUP;
   Test_Hint_Reject_OversizedOffset;
   Test_Hint_Reject_SignalReports;
   Test_Hint_Reject_Junk;
   Test_Hint_Reject_OutOfBand;
   Test_Hint_Reject_BareR;
   Test_Hint_Reject_PhrasalVerbs;
   Test_Hint_Reject_GluedIntroducer;
   Test_Hint_FillerWordBeforeFrequency;
   Test_PasswordPrompt_Recognised;
   Test_PasswordPrompt_SmearedIntoTheNextChunk;
   Test_PasswordPrompt_CorpusLinesDoNotTrigger;
   Test_PasswordPrompt_SpotTrafficDoesNotTrigger;
   Test_LoginPrompt_Recognised;
   Test_LoginPrompt_SmearedIntoTheNextChunk;
   Test_LoginPrompt_YieldsToAPasswordPromptOnTheSameLine;
   Test_LoginPrompt_OrdinaryTrafficDoesNotTrigger;
end;

end.

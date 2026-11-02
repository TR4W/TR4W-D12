unit uTestK4DisplayReport;
{$I ..\..\src\tr4w.inc}

(*
  THE K4'S OWN DISPLAY REPORTS, DECODED -- stage 1 of the K4 display-state
  work.  uK4DisplayReport is pure, so every case here is a string in and a
  record out, with no radio and no transport.

  The strings are the radio's own where one exists: '#REF-126', '#SCL080',
  '#AR1201+041' and '#AR1206+041' were captured from a real K4 (this tree's
  docs/PANADAPTER_LCL_DESIGN.md section 10, QK4 docs/k4-protocol-quirks.md
  section 13).  The rest follow the K4 Programmer's Reference forms QK4 records.

  What is pinned:
  - each report lands in the right field, and in the right receiver: #REF is
    main, #REF$ is sub, and the global reports reach both;
  - leading zeros are accepted and not required -- which the radio sends is
    unknown;
  - every accepted report moves Generation, even one that repeats the value;
  - every rejected one -- junk, out of range, a sign where none belongs, the
    wrong length, #SPN, #HREF, an empty string, a bare '#' -- leaves the WHOLE
    state byte-for-byte as it was;
  - the AutoRef debounce field is kept but not range-checked, because the
    radio's own captures contradict the documented range;
  - a reset clears every flag and moves every Generation on.
*)

interface

uses
   uTR4WTestFramework;

type
   TK4DisplayReportTests = class(TTestCase)
   protected
      procedure Test_RealCaptures_LandInTheRightFields;
      procedure Test_RefIsPerReceiver_GlobalsReachBoth;
      procedure Test_LeadingZeros_AcceptedNotRequired;
      procedure Test_AutoRef_Fields;
      procedure Test_AutoRefDebounce_NotRangeChecked;
      procedure Test_ExternalMonitorAndFps_TouchNoReceiver;
      procedure Test_RepeatedValue_StillMovesGeneration;
      procedure Test_Rejected_LeavesTheStateAlone;
      procedure Test_RangeEdges;
      procedure Test_TrailingTerminator_Tolerated;
      procedure Test_Reset_ClearsFlagsAndMovesGeneration;
      procedure Test_Generation_WrapsToOneNeverZero;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uSpectrumTypes, uK4DisplayReport;

function Fresh: TK4DisplayState;
begin
   Result := K4DisplayStateUnknown;
end;

(* The record holds no managed field and is only ever copied whole, so an
   untouched state is byte-identical to its snapshot. *)
function SameBytes(const A, B: TK4DisplayState): Boolean;
begin
   Result := CompareMem(@A, @B, SizeOf(TK4DisplayState));
end;

procedure TK4DisplayReportTests.Test_RealCaptures_LandInTheRightFields;
var
   s: TK4DisplayState;
begin
   BeginTest('K4 display: the radio''s own captured strings land in the right fields');
   s := Fresh;

   CheckTrue(ParseK4DisplayReport('#REF-126', s), '#REF-126 accepted');
   CheckTrue(s.Main.HasRef, 'main REF known');
   CheckEquals(-126, s.Main.RefDb, 'main REF value');

   CheckTrue(ParseK4DisplayReport('#SCL080', s), '#SCL080 accepted');
   CheckTrue(s.Main.HasScale, 'scale known');
   CheckEquals(80, s.Main.ScaleDb, 'scale value');

   CheckTrue(ParseK4DisplayReport('#WFH50', s), '#WFH50 accepted');
   CheckEquals(50, s.Main.WaterfallPercent, 'waterfall share');
   CheckTrue(s.Main.HasWaterfallFraction, 'waterfall share known');

   CheckTrue(ParseK4DisplayReport('#WBS12', s), '#WBS12 accepted');
   CheckEquals(12, s.Main.ColourRange, 'colour range');
   CheckTrue(s.Main.HasColourRange, 'colour range known');

   CheckTrue(ParseK4DisplayReport('#AVG2', s), '#AVG2 accepted');
   CheckEquals(2, s.Main.AvgFrames, 'averaging');
   CheckTrue(s.Main.HasAvg, 'averaging known');

   CheckTrue(ParseK4DisplayReport('#FPS12', s), '#FPS12 accepted');
   CheckTrue(s.HasFps, 'frame rate known');
   CheckEquals(12, s.Fps, 'frame rate');

   CheckTrue(ParseK4DisplayReport('#AR1206+041', s), '#AR1206+041 accepted');
   CheckTrue(s.Main.HasAutoRef, 'AutoRef known');
   CheckTrue(s.Main.AutoRef, 'AutoRef on');
   CheckEquals(4, s.Main.AutoRefOffsetDb, 'AutoRef offset');
end;

procedure TK4DisplayReportTests.Test_RefIsPerReceiver_GlobalsReachBoth;
var
   s: TK4DisplayState;
   mainGen, subGen: Integer;
begin
   BeginTest('K4 display: #REF is main, #REF$ is sub, and the global reports reach both');
   s := Fresh;

   CheckTrue(ParseK4DisplayReport('#REF$-125', s), '#REF$-125 accepted');
   CheckTrue(s.Sub.HasRef, 'sub REF known');
   CheckEquals(-125, s.Sub.RefDb, 'sub REF value');
   CheckFalse(s.Main.HasRef, '#REF$ must not touch the main receiver');
   CheckEquals(0, s.Main.Generation, 'nor move the main receiver''s Generation');
   CheckEquals(1, s.Sub.Generation, 'the sub''s Generation moved');

   CheckTrue(ParseK4DisplayReport('#REF-126', s), '#REF-126 accepted');
   CheckEquals(-126, s.Main.RefDb, 'main REF value');
   CheckEquals(-125, s.Sub.RefDb, '#REF must not touch the sub receiver');
   CheckEquals(1, s.Sub.Generation, 'nor move the sub''s Generation');

   mainGen := s.Main.Generation;
   subGen := s.Sub.Generation;
   CheckTrue(ParseK4DisplayReport('#SCL80', s), '#SCL80 accepted');
   CheckTrue(s.Main.HasScale and s.Sub.HasScale, 'the scale is one value for both');
   CheckEquals(80, s.Sub.ScaleDb, 'sub sees the scale');
   CheckEquals(mainGen + 1, s.Main.Generation, 'a global report moves main');
   CheckEquals(subGen + 1, s.Sub.Generation, 'and sub');

   CheckTrue(ParseK4DisplayReport('#WFH40', s), '#WFH40 accepted');
   CheckTrue(ParseK4DisplayReport('#WBS9', s), '#WBS9 accepted');
   CheckTrue(ParseK4DisplayReport('#AVG5', s), '#AVG5 accepted');
   CheckTrue(ParseK4DisplayReport('#AR1201+040', s), '#AR1201+040 accepted');
   CheckEquals(40, s.Sub.WaterfallPercent, 'sub waterfall share');
   CheckEquals(9, s.Sub.ColourRange, 'sub colour range');
   CheckEquals(5, s.Sub.AvgFrames, 'sub averaging');
   CheckTrue(s.Sub.HasAutoRef and (not s.Sub.AutoRef), 'sub sees AutoRef off');
   CheckEquals(s.Main.Generation, s.Sub.Generation,
               'every report since the two REFs reached both receivers');
end;

procedure TK4DisplayReportTests.Test_LeadingZeros_AcceptedNotRequired;
var
   s: TK4DisplayState;
begin
   BeginTest('K4 display: leading zeros are accepted and not required');
   s := Fresh;

   CheckTrue(ParseK4DisplayReport('#AVG02', s), '#AVG02');
   CheckEquals(2, s.Main.AvgFrames, '#AVG02 is 2');
   CheckTrue(ParseK4DisplayReport('#AVG7', s), '#AVG7');
   CheckEquals(7, s.Main.AvgFrames, '#AVG7 is 7');

   CheckTrue(ParseK4DisplayReport('#WFH050', s), '#WFH050');
   CheckEquals(50, s.Main.WaterfallPercent, '#WFH050 is 50');
   CheckTrue(ParseK4DisplayReport('#WFH000', s), '#WFH000');
   CheckEquals(0, s.Main.WaterfallPercent, '#WFH000 is 0 -- a real setting, and known');
   CheckTrue(s.Main.HasWaterfallFraction, 'zero is known, not unknown');

   CheckTrue(ParseK4DisplayReport('#FPS05', s), '#FPS05');
   CheckEquals(5, s.Fps, '#FPS05 is 5');

   CheckTrue(ParseK4DisplayReport('#REF-0126', s), '#REF-0126');
   CheckEquals(-126, s.Main.RefDb, '#REF-0126 is -126');
   CheckTrue(ParseK4DisplayReport('#REF+010', s), '#REF+010');
   CheckEquals(10, s.Main.RefDb, '#REF+010 is 10');
   CheckTrue(ParseK4DisplayReport('#REF0', s), '#REF0');
   CheckEquals(0, s.Main.RefDb, '#REF0 is 0 dB');
end;

procedure TK4DisplayReportTests.Test_AutoRef_Fields;
var
   s: TK4DisplayState;
begin
   BeginTest('K4 display: #ARaadd+oom -- averaging, debounce, signed offset, on/off');
   s := Fresh;

   CheckTrue(ParseK4DisplayReport('#AR1201+041', s), '#AR1201+041');
   CheckTrue(s.Main.AutoRef, 'last character 1 is AutoRef ON');
   CheckEquals(4, s.Main.AutoRefOffsetDb, 'offset +04');
   CheckTrue(s.HasAutoRefTiming, 'the timing fields are known');
   CheckEquals(12, s.AutoRefAveraging, 'aa = 12');
   CheckEquals(1, s.AutoRefDebounce, 'dd = 01');

   CheckTrue(ParseK4DisplayReport('#AR1201+081', s), '#AR1201+081');
   CheckEquals(8, s.Main.AutoRefOffsetDb, 'offset +08, the documented top');

   CheckTrue(ParseK4DisplayReport('#AR1201-080', s), '#AR1201-080');
   CheckEquals(-8, s.Main.AutoRefOffsetDb, 'offset -08, the documented bottom');
   CheckFalse(s.Main.AutoRef, 'last character 0 is AutoRef OFF');
   CheckTrue(s.Main.HasAutoRef, 'and OFF is known, not unknown');

   CheckTrue(ParseK4DisplayReport('#AR0105+000', s), '#AR0105+000');
   CheckEquals(0, s.Main.AutoRefOffsetDb, 'offset 0');
   CheckEquals(1, s.AutoRefAveraging, 'aa = 01, the documented bottom');
end;

(* QK4's command table says the debounce is 4..9; the radio itself sent 01.
   Range-checking it would reject the radio's own report, so it is kept as
   read.  If a bench capture ever settles the range, this test is where that
   decision lands. *)
procedure TK4DisplayReportTests.Test_AutoRefDebounce_NotRangeChecked;
var
   s: TK4DisplayState;
begin
   BeginTest('K4 display: the AutoRef debounce is kept but not range-checked (its range is unknown)');
   s := Fresh;
   CheckTrue(ParseK4DisplayReport('#AR1200+041', s), 'debounce 00 accepted');
   CheckEquals(0, s.AutoRefDebounce, 'debounce 00');
   CheckTrue(ParseK4DisplayReport('#AR1299+041', s), 'debounce 99 accepted');
   CheckEquals(99, s.AutoRefDebounce, 'debounce 99');
end;

procedure TK4DisplayReportTests.Test_ExternalMonitorAndFps_TouchNoReceiver;
var
   s: TK4DisplayState;
   gen: Integer;
begin
   BeginTest('K4 display: #HWFH, #HWBS and #FPS are K4 facts and touch no receiver record');
   s := Fresh;

   CheckTrue(ParseK4DisplayReport('#HWFH070', s), '#HWFH070');
   CheckTrue(s.HasExtWaterfall, 'external waterfall share known');
   CheckEquals(70, s.ExtWaterfallPercent, 'external waterfall share');

   CheckTrue(ParseK4DisplayReport('#HWBS20', s), '#HWBS20');
   CheckTrue(s.HasExtColourRange, 'external colour range known');
   CheckEquals(20, s.ExtColourRange, 'external colour range');

   CheckTrue(ParseK4DisplayReport('#FPS30', s), '#FPS30');

   CheckTrue(SpectrumRadioStateKnowsNothing(s.Main), 'main receiver untouched');
   CheckTrue(SpectrumRadioStateKnowsNothing(s.Sub), 'sub receiver untouched');
   CheckEquals(0, s.Main.Generation, 'main Generation untouched');
   CheckEquals(0, s.Sub.Generation, 'sub Generation untouched');
   CheckEquals(3, s.Generation, 'but each was an accepted report');

   (* And the LCD waterfall is not the external one. *)
   gen := s.Generation;
   CheckTrue(ParseK4DisplayReport('#WFH30', s), '#WFH30');
   CheckEquals(70, s.ExtWaterfallPercent, '#WFH does not move #HWFH');
   CheckEquals(30, s.Main.WaterfallPercent, 'it moves the receivers');
   CheckEquals(gen + 1, s.Generation, 'one more accepted report');
end;

procedure TK4DisplayReportTests.Test_RepeatedValue_StillMovesGeneration;
var
   s: TK4DisplayState;
   gen: Integer;
begin
   BeginTest('K4 display: a report equal to the value held still moves Generation');
   s := Fresh;

   CheckTrue(ParseK4DisplayReport('#REF-126', s), 'first #REF-126');
   gen := s.Main.Generation;
   CheckEquals(1, gen, 'the first report moves Generation from 0');

   CheckTrue(ParseK4DisplayReport('#REF-126', s), 'the same value again');
   CheckEquals(gen + 1, s.Main.Generation, 'a repeat is still the radio speaking');
   CheckEquals(-126, s.Main.RefDb, 'and the value is unchanged');

   (* A first report equal to the all-zero default: REF 0 dB.  "Known" is the
      flag, not "differs from zero". *)
   s := Fresh;
   CheckTrue(ParseK4DisplayReport('#REF0', s), '#REF0 on a fresh state');
   CheckTrue(s.Main.HasRef, 'a first report equal to the default is still KNOWN');
   CheckEquals(1, s.Main.Generation, 'and moves Generation');
end;

procedure TK4DisplayReportTests.Test_Rejected_LeavesTheStateAlone;
const
   JUNK: array[0..47] of string = (
      '', '#', ';', '#;', 'FA00014025000', 'TS1',
      '#REF', '#REF-', '#REF+', '#REF-+1', '#REFabc', '#REF1 2', '#REF 12',
      '#REF$', '#REF$x', '#REF$-', '#REF-12345', '#REF$12$',
      '#SCL', '#SCL-80', '#SCL+80', '#SCL8O', '#SCL$80',
      '#WFH', '#WFH-1', '#WBS', '#WBS1x', '#HWFH', '#HWBS',
      '#AVG', '#AVG1.5', '#FPS', '#FPSxx',
      '#AR', '#AR1201+04', '#AR1201+0411', '#AR1201*041', '#AR1201+042',
      '#AR1201+04A', '#ARx201+041', '#AR12a1+041', '#AR1201+x41',
      '#SPN100000', '#SPN$100000', '#HREF-131', '#HREF$-131', '#MP1',
      '#AR/');
var
   s, before: TK4DisplayState;
   i: Integer;
   leaked: string;
begin
   BeginTest('K4 display: junk, the wrong length, #SPN, #HREF, empty and a bare # change nothing');
   s := Fresh;
   CheckTrue(ParseK4DisplayReport('#REF-126', s), 'precondition: a known REF');
   CheckTrue(ParseK4DisplayReport('#REF$-125', s), 'precondition: a known sub REF');
   CheckTrue(ParseK4DisplayReport('#SCL80', s), 'precondition: a known scale');
   leaked := '';

   for i := Low(JUNK) to High(JUNK) do
      begin
      before := s;

      if ParseK4DisplayReport(JUNK[i], s) then
         begin
         leaked := leaked + '[' + JUNK[i] + '] accepted; ';
         end;

      if not SameBytes(before, s) then
         begin
         leaked := leaked + '[' + JUNK[i] + '] changed the state; ';
         end;
      end;

   CheckEquals('', leaked, 'rejected messages must return False and change nothing');
   CheckEquals(-126, s.Main.RefDb, '#HREF-131 is the external monitor''s and must not be read as #REF');
end;

procedure TK4DisplayReportTests.Test_RangeEdges;
const
   (* Each pair: the legal edge, then one step outside it. *)
   GOOD: array[0..15] of string = (
      '#REF-200', '#REF60', '#REF$-200', '#REF$60',
      '#SCL10', '#SCL150', '#WFH0', '#WFH100',
      '#WBS5', '#WBS30', '#AVG1', '#AVG20',
      '#FPS1', '#FPS30', '#AR0101+081', '#AR2001-081');
   BAD: array[0..15] of string = (
      '#REF-201', '#REF61', '#REF$-201', '#REF$61',
      '#SCL9', '#SCL151', '#HWFH101', '#WFH101',
      '#WBS4', '#WBS31', '#AVG0', '#AVG21',
      '#FPS0', '#FPS31', '#AR0001+041', '#AR2101+041');
   (* The offset edge, separately: one past +8 and one past -8. *)
   BAD_OFFSET: array[0..1] of string = ('#AR1201+091', '#AR1201-091');
var
   s, before: TK4DisplayState;
   i: Integer;
   wrong: string;
begin
   BeginTest('K4 display: every range edge is accepted and one step past it is refused');
   wrong := '';

   for i := Low(GOOD) to High(GOOD) do
      begin
      s := Fresh;

      if not ParseK4DisplayReport(GOOD[i], s) then
         begin
         wrong := wrong + GOOD[i] + ' refused; ';
         end;
      end;

   for i := Low(BAD) to High(BAD) do
      begin
      s := Fresh;
      before := s;

      if ParseK4DisplayReport(BAD[i], s) or (not SameBytes(before, s)) then
         begin
         wrong := wrong + BAD[i] + ' accepted; ';
         end;
      end;

   for i := Low(BAD_OFFSET) to High(BAD_OFFSET) do
      begin
      s := Fresh;
      before := s;

      if ParseK4DisplayReport(BAD_OFFSET[i], s) or (not SameBytes(before, s)) then
         begin
         wrong := wrong + BAD_OFFSET[i] + ' accepted; ';
         end;
      end;

   CheckEquals('', wrong, 'range edges');
end;

procedure TK4DisplayReportTests.Test_TrailingTerminator_Tolerated;
var
   s: TK4DisplayState;
begin
   BeginTest('K4 display: one trailing ";" is tolerated');
   s := Fresh;
   CheckTrue(ParseK4DisplayReport('#SCL80;', s), '#SCL80;');
   CheckEquals(80, s.Main.ScaleDb, 'scale');
   CheckTrue(ParseK4DisplayReport('#AR1201+041;', s), '#AR1201+041;');
   CheckTrue(s.Main.AutoRef, 'AutoRef on');
   CheckFalse(ParseK4DisplayReport('#SCL80;;', s), 'but not two');
end;

procedure TK4DisplayReportTests.Test_Reset_ClearsFlagsAndMovesGeneration;
var
   s: TK4DisplayState;
   mainGen, subGen, gen: Integer;
begin
   BeginTest('K4 display: a reset clears every flag and moves every Generation on');
   s := Fresh;
   CheckTrue(ParseK4DisplayReport('#REF-126', s), '#REF');
   CheckTrue(ParseK4DisplayReport('#REF$-125', s), '#REF$');
   CheckTrue(ParseK4DisplayReport('#SCL80', s), '#SCL');
   CheckTrue(ParseK4DisplayReport('#WFH50', s), '#WFH');
   CheckTrue(ParseK4DisplayReport('#WBS12', s), '#WBS');
   CheckTrue(ParseK4DisplayReport('#AVG2', s), '#AVG');
   CheckTrue(ParseK4DisplayReport('#AR1201+041', s), '#AR');
   CheckTrue(ParseK4DisplayReport('#FPS12', s), '#FPS');
   CheckTrue(ParseK4DisplayReport('#HWFH50', s), '#HWFH');
   CheckTrue(ParseK4DisplayReport('#HWBS12', s), '#HWBS');
   mainGen := s.Main.Generation;
   subGen := s.Sub.Generation;
   gen := s.Generation;

   ResetK4DisplayState(s);

   CheckTrue(SpectrumRadioStateKnowsNothing(s.Main), 'main knows nothing after a reset');
   CheckTrue(SpectrumRadioStateKnowsNothing(s.Sub), 'sub knows nothing after a reset');
   CheckFalse(s.HasFps or s.HasExtWaterfall or s.HasExtColourRange or s.HasAutoRefTiming,
              'nor do the K4-only fields');
   CheckEquals(mainGen + 1, s.Main.Generation, 'main Generation moved on, not back to 0');
   CheckEquals(subGen + 1, s.Sub.Generation, 'sub Generation moved on');
   CheckEquals(gen + 1, s.Generation, 'the K4 Generation moved on');

   (* A fresh state reset is still "nothing known", and moves off 0. *)
   s := Fresh;
   ResetK4DisplayState(s);
   CheckTrue(SpectrumRadioStateKnowsNothing(s.Main), 'a fresh reset knows nothing');
   CheckEquals(1, s.Main.Generation, 'and its Generation is 1');
end;

procedure TK4DisplayReportTests.Test_Generation_WrapsToOneNeverZero;
begin
   BeginTest('Generation: +1, and from High(Integer) it wraps to 1, never 0');
   CheckEquals(1, NextSpectrumRadioStateGeneration(0), '0 -> 1');
   CheckEquals(42, NextSpectrumRadioStateGeneration(41), '41 -> 42');
   CheckEquals(1, NextSpectrumRadioStateGeneration(High(Integer)), 'High -> 1');
   CheckEquals(1, NextSpectrumRadioStateGeneration(-5), 'a negative (corrupt) value -> 1');
   CheckTrue(SpectrumRadioStateKnowsNothing(SpectrumRadioStateUnknown), 'unknown knows nothing');
   CheckEquals(0, SpectrumRadioStateUnknown.Generation, 'and has Generation 0');
end;

procedure TK4DisplayReportTests.RunAllTests;
begin
   Test_RealCaptures_LandInTheRightFields;
   Test_RefIsPerReceiver_GlobalsReachBoth;
   Test_LeadingZeros_AcceptedNotRequired;
   Test_AutoRef_Fields;
   Test_AutoRefDebounce_NotRangeChecked;
   Test_ExternalMonitorAndFps_TouchNoReceiver;
   Test_RepeatedValue_StillMovesGeneration;
   Test_Rejected_LeavesTheStateAlone;
   Test_RangeEdges;
   Test_TrailingTerminator_Tolerated;
   Test_Reset_ClearsFlagsAndMovesGeneration;
   Test_Generation_WrapsToOneNeverZero;
end;

end.

unit uTestSpectrumMapping;
{$I ..\..\src\tr4w.inc}

(*
  The panadapter's horizontal mapping -- column, bin, Hz -- as ONE integer
  partition (issue 155, NY4I 2026-11-22: one partition for trace, click and
  markers; the click tunes the exact bin under the pointer; markers follow
  the partition).

  Until that ruling this unit pinned four DISAGREEMENTS between the trace,
  the markers and click-to-tune, and could not assert that the top bin was
  drawn at all, because the old Double formula lost it at some widths.  Those
  pins are rewritten here as AGREEMENTS, on purpose:

    - every bin is in exactly one column when there are at least as many
      bins as columns, and every column is non-empty;
    - the last column holds the top bin at EVERY width;
    - a click tunes a bin the clicked column draws -- the bin under the
      pixel's centre, kept inside the column;
    - a marker is drawn in the column the trace draws its bin in;
    - a click's marker draws the clicked bin, and is the clicked column
      itself whenever bins >= columns.

  Integer arithmetic is exact, so unlike the old suite every width can be
  asserted, inexact ratios included.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uSpectrumTypes;

type
   TSpectrumMappingTests = class(TTestCase)
   protected
      function MakeFrame(ABinCount: Integer): TSpectrumFrame;
      procedure CheckColumn(ABinCount, AWidth, AX, AFirst, ALast: Integer);
      function PeakColumnOf(ABinCount, AWidth, ACarrierBin: Integer): Integer;
      function ColumnHolds(ABinCount, AWidth, AX, ABin: Integer): Boolean;

      procedure Test_Columns_WholeBinsPerPixel;
      procedure Test_Columns_FractionalBinsPerPixel;
      procedure Test_Columns_WiderThanTheData_RepeatBins;
      procedure Test_Columns_OneBin;
      procedure Test_Columns_TileTheBins;
      procedure Test_Columns_NoBins;
      procedure Test_Carrier_AtBothEnds;
      procedure Test_ClickBin_IsTheBinUnderThePointer;
      procedure Test_ClickHz_Values;
      procedure Test_HzToPixel_EdgesAndOffSpan;
      procedure Test_Agree_MarkerIsTheTraceColumn;
      procedure Test_Agree_ClickTunesADrawnBin;
      procedure Test_Agree_ClickRoundTrip;
      procedure Test_SpanCommand_Syntax;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   SPAN_HZ = 192000;
   CENTRE_HZ = 14100000;

function TSpectrumMappingTests.MakeFrame(ABinCount: Integer): TSpectrumFrame;
begin
   Result := Default(TSpectrumFrame);
   Result.CentreHz := CENTRE_HZ;
   Result.SpanHz := SPAN_HZ;
   Result.BinCount := ABinCount;
end;

procedure TSpectrumMappingTests.CheckColumn(ABinCount, AWidth, AX, AFirst, ALast: Integer);
var
   first, last: Integer;
   tag: string;
begin
   SpectrumColumnBins(AX, ABinCount, AWidth, first, last);
   tag :=IntToStr(ABinCount) + ' bins / ' + IntToStr(AWidth) + ' px, column ' + IntToStr(AX);
   CheckEquals(AFirst, first, tag + ': first bin');
   CheckEquals(ALast, last, tag + ': last bin');
end;

(* The column the trace draws a one-bin carrier in: the first column whose
   bins include it, so whose maximum is the carrier.  -1 when no column on
   the window shows it. *)
function TSpectrumMappingTests.PeakColumnOf(ABinCount, AWidth, ACarrierBin: Integer): Integer;
var
   x: Integer;
begin
   Result := -1;

   for x := 0 to AWidth - 1 do
      begin
      if ColumnHolds(ABinCount, AWidth, x, ACarrierBin) then
         begin
         Result := x;
         Exit;
         end;
      end;
end;

function TSpectrumMappingTests.ColumnHolds(ABinCount, AWidth, AX, ABin: Integer): Boolean;
var
   first, last: Integer;
begin
   (* A column off the window shows nothing, even though SpectrumColumnBins
      clamps it onto the end bins. *)
   if (AX < 0) or (AX >= AWidth) then
      begin
      Result := False;
      Exit;
      end;

   SpectrumColumnBins(AX, ABinCount, AWidth, first, last);
   Result := (ABin >= first) and (ABin <= last);
end;

procedure TSpectrumMappingTests.Test_Columns_WholeBinsPerPixel;
begin
   BeginTest('Test_Columns_WholeBinsPerPixel');
   (* Two bins per column, then four, then exactly one. *)
   CheckColumn(2048, 1024, 0, 0, 1);
   CheckColumn(2048, 1024, 1, 2, 3);
   CheckColumn(2048, 1024, 1023, 2046, 2047);
   CheckColumn(2048, 512, 0, 0, 3);
   CheckColumn(2048, 512, 511, 2044, 2047);
   CheckColumn(2048, 2048, 0, 0, 0);
   CheckColumn(2048, 2048, 2047, 2047, 2047);
end;

procedure TSpectrumMappingTests.Test_Columns_FractionalBinsPerPixel;
begin
   BeginTest('Test_Columns_FractionalBinsPerPixel');
   (* 2.5 bins per column: (x * N) div W gives 2-3-2-3, every bin once. *)
   CheckColumn(10, 4, 0, 0, 1);
   CheckColumn(10, 4, 1, 2, 4);
   CheckColumn(10, 4, 2, 5, 6);
   CheckColumn(10, 4, 3, 7, 9);

   (* 1.25: 1-1-1-2, and the top bin is in the last column. *)
   CheckColumn(5, 4, 0, 0, 0);
   CheckColumn(5, 4, 1, 1, 1);
   CheckColumn(5, 4, 2, 2, 2);
   CheckColumn(5, 4, 3, 3, 4);

   (* An inexact ratio the old Double could not be trusted with: 2048 bins
      across 700 columns.  Column 699 starts at (699 * 2048) div 700 = 2045
      and ends at the top bin. *)
   CheckColumn(2048, 700, 0, 0, 1);
   CheckColumn(2048, 700, 699, 2045, 2047);
end;

procedure TSpectrumMappingTests.Test_Columns_WiderThanTheData_RepeatBins;
begin
   BeginTest('Test_Columns_WiderThanTheData_RepeatBins');
   (* 0.75 bins per column: each column shows the bin under its LEFT edge, so
      bin 0 is drawn twice and the others once -- no interpolation. *)
   CheckColumn(3, 4, 0, 0, 0);
   CheckColumn(3, 4, 1, 0, 0);
   CheckColumn(3, 4, 2, 1, 1);
   CheckColumn(3, 4, 3, 2, 2);

   (* 0.5: every bin twice. *)
   CheckColumn(1024, 2048, 0, 0, 0);
   CheckColumn(1024, 2048, 1, 0, 0);
   CheckColumn(1024, 2048, 2, 1, 1);
   CheckColumn(1024, 2048, 2047, 1023, 1023);

   (* A column past the right edge clamps to the top bin rather than reading
      off the end of the array. *)
   CheckColumn(1024, 2048, 5000, 1023, 1023);
end;

(* One bin across five columns: every column draws it, a click anywhere
   tunes it, and its marker is the rightmost column of the run. *)
procedure TSpectrumMappingTests.Test_Columns_OneBin;
var
   x: Integer;
   f: TSpectrumFrame;
begin
   BeginTest('Test_Columns_OneBin');
   f := MakeFrame(1);

   for x := 0 to 4 do
      begin
      CheckColumn(1, 5, x, 0, 0);
      CheckEquals(0, SpectrumClickBin(x, 1, 5), 'one bin: click column ' + IntToStr(x));
      end;

   CheckEquals(4, SpectrumBinColumn(0, 1, 5), 'one bin: its column is the rightmost');
   CheckEquals(IntToStr(CENTRE_HZ), IntToStr(SpectrumColumnHz(f, 2, 5)),
               'one bin: a click tunes its centre, the frame centre');
   CheckEquals(4, SpectrumHzToPixel(f, CENTRE_HZ, 5), 'one bin: the centre marker');

   (* One bin, one column. *)
   CheckColumn(1, 1, 0, 0, 0);
   CheckEquals(0, SpectrumBinColumn(0, 1, 1), 'one bin, one column');
end;

(* THE PARTITION'S PROPERTIES, at every width -- exact integer arithmetic, so
   inexact ratios are asserted too.  Column 0 starts at bin 0 and the last
   column holds the TOP bin (the old Double formula lost it at some widths).
   With bins >= columns: neighbouring columns meet with no gap and no overlap,
   every column is non-empty, and every bin is in exactly one column.  With
   fewer bins: one bin per column, never skipping a bin, every bin shown. *)
procedure TSpectrumMappingTests.Test_Columns_TileTheBins;
const
   BIN_COUNTS: array[0..6] of Integer = (2048, 2047, 1024, 10, 5, 3, 1);
   WIDTHS: array[0..9] of Integer = (1, 3, 4, 7, 100, 333, 700, 1000, 1999, 3001);
var
   ni, wi, n, w, x, b, first, last, prevLast, prevFirst: Integer;
   tag: string;
   gapFound, skipFound, emptyFound, countWrong: Boolean;
   seen: array of Integer;
begin
   BeginTest('Test_Columns_TileTheBins');

   for ni := Low(BIN_COUNTS) to High(BIN_COUNTS) do
      begin
      for wi := Low(WIDTHS) to High(WIDTHS) do
         begin
         n := BIN_COUNTS[ni];
         w := WIDTHS[wi];
         tag := IntToStr(n) + ' bins / ' + IntToStr(w) + ' px';
         gapFound := False;
         skipFound := False;
         emptyFound := False;
         countWrong := False;
         prevLast := -1;
         prevFirst := -1;
         seen := nil;
         SetLength(seen, n);

         for x := 0 to w - 1 do
            begin
            SpectrumColumnBins(x, n, w, first, last);

            if x = 0 then
               begin
               CheckEquals(0, first, tag + ': column 0 starts at bin 0');
               end;

            if last < first then
               begin
               emptyFound := True;
               end;

            if n >= w then
               begin
               if (x > 0) and (first <> prevLast + 1) then
                  begin
                  gapFound := True;
                  end;

               for b := first to last do
                  begin
                  Inc(seen[b]);
                  end;
               end
            else
               begin
               if (first <> last) or ((x > 0) and (first <> prevFirst) and (first <> prevFirst + 1)) then
                  begin
                  skipFound := True;
                  end;

               seen[first] := 1;
               end;

            prevFirst := first;
            prevLast := last;
            end;

         for b := 0 to n - 1 do
            begin
            if seen[b] <> 1 then
               begin
               countWrong := True;
               end;
            end;

         Check(not emptyFound, tag + ': every column draws at least one bin');
         Check(not gapFound, tag + ': neighbouring columns must tile the bins');
         Check(not skipFound, tag + ': one bin per column, never skipping one');
         Check(not countWrong, tag + ': every bin in exactly one column (or shown, when wider)');
         CheckEquals(n - 1, prevLast, tag + ': the last column holds the top bin');
         end;
      end;
end;

procedure TSpectrumMappingTests.Test_Columns_NoBins;
var
   first, last: Integer;
   f: TSpectrumFrame;
begin
   BeginTest('Test_Columns_NoBins');
   SpectrumColumnBins(3, 0, 4, first, last);
   CheckEquals(-1, first, 'no bins: first');
   CheckEquals(-1, last, 'no bins: last');

   SpectrumColumnBins(3, 2048, 0, first, last);
   CheckEquals(-1, first, 'no width: first');
   CheckEquals(-1, last, 'no width: last');

   CheckEquals(-1, SpectrumBinColumn(0, 0, 4), 'no bins: no column');
   CheckEquals(-1, SpectrumBinColumn(0, 2048, 0), 'no width: no column');
   CheckEquals(-1, SpectrumClickBin(3, 0, 4), 'no bins: no click bin');
   CheckEquals(-1, SpectrumClickBin(3, 2048, 0), 'no width: no click bin');

   f := MakeFrame(0);
   CheckEquals('0', IntToStr(SpectrumColumnHz(f, 3, 4)), 'no bins: no click frequency');
   CheckEquals(-1, SpectrumHzToPixel(f, CENTRE_HZ, 4), 'no bins: no marker');
end;

procedure TSpectrumMappingTests.Test_Carrier_AtBothEnds;
begin
   BeginTest('Test_Carrier_AtBothEnds');
   (* A one-bin carrier in the bottom and in the top bin, at exact ratios
      above, at and below one bin per column. *)
   CheckEquals(0, PeakColumnOf(2048, 1024, 0), '2048/1024 bottom');
   CheckEquals(1023, PeakColumnOf(2048, 1024, 2047), '2048/1024 top');
   CheckEquals(0, PeakColumnOf(2048, 2048, 0), '2048/2048 bottom');
   CheckEquals(2047, PeakColumnOf(2048, 2048, 2047), '2048/2048 top');
   CheckEquals(0, PeakColumnOf(1024, 2048, 0), '1024/2048 bottom');
   CheckEquals(2046, PeakColumnOf(1024, 2048, 1023), '1024/2048 top, first of two columns');
   CheckEquals(0, PeakColumnOf(10, 4, 0), '10/4 bottom');
   CheckEquals(3, PeakColumnOf(10, 4, 9), '10/4 top');

   (* At inexact ratios too -- the top-bin cure.  The old Double formula
      drew a top-bin carrier in NO column at some of these widths. *)
   CheckEquals(0, PeakColumnOf(2048, 700, 0), '2048/700 bottom');
   CheckEquals(699, PeakColumnOf(2048, 700, 2047), '2048/700 top');
   CheckEquals(1998, PeakColumnOf(2048, 1999, 2047), '2048/1999 top');
   CheckEquals(332, PeakColumnOf(2048, 333, 2047), '2048/333 top');
   CheckEquals(0, PeakColumnOf(2048, 3001, 0), '2048/3001 bottom');
   CheckEquals(3000, PeakColumnOf(2048, 3001, 2047), '2048/3001 top');
end;

(* NY4I's "exact": the bin under the pixel's centre, ((2x + 1) * N) div 2W,
   kept inside the column's own bins. *)
procedure TSpectrumMappingTests.Test_ClickBin_IsTheBinUnderThePointer;
begin
   BeginTest('Test_ClickBin_IsTheBinUnderThePointer');

   (* A whole number of bins per column puts the pixel centre ON a bin edge,
      and the bin to its right is taken: 2048/1024 gives bin 2x + 1. *)
   CheckEquals(1, SpectrumClickBin(0, 2048, 1024), '2048/1024 column 0');
   CheckEquals(3, SpectrumClickBin(1, 2048, 1024), '2048/1024 column 1');
   CheckEquals(701, SpectrumClickBin(350, 2048, 1024), '2048/1024 column 350');
   CheckEquals(2047, SpectrumClickBin(1023, 2048, 1024), '2048/1024 column 1023');

   (* 2.5 bins per column: the centre lands inside the column. *)
   CheckEquals(1, SpectrumClickBin(0, 10, 4), '10/4 column 0 (bins 0..1)');
   CheckEquals(3, SpectrumClickBin(1, 10, 4), '10/4 column 1 (bins 2..4)');
   CheckEquals(6, SpectrumClickBin(2, 10, 4), '10/4 column 2 (bins 5..6)');
   CheckEquals(8, SpectrumClickBin(3, 10, 4), '10/4 column 3 (bins 7..9)');

   (* THE CLAMP: the centre of column 2 of 5 bins over 4 columns is in bin 3,
      but that column draws bin 2 only, so bin 2 is tuned. *)
   CheckEquals(2, SpectrumClickBin(2, 5, 4), '5/4 column 2: kept inside the column');
   CheckEquals(4, SpectrumClickBin(3, 5, 4), '5/4 column 3 (bins 3..4)');

   (* Wider than the data: the column's one bin, whatever the centre says. *)
   CheckEquals(0, SpectrumClickBin(1, 3, 4), '3/4 column 1 draws bin 0, centre is in bin 1');
   CheckEquals(2, SpectrumClickBin(3, 3, 4), '3/4 column 3');

   (* Off either side clamps to the end bins, as click-to-tune always did. *)
   CheckEquals(0, SpectrumClickBin(-10, 2048, 1024), 'left of the window');
   CheckEquals(2047, SpectrumClickBin(5000, 2048, 1024), 'right of the window');
end;

procedure TSpectrumMappingTests.Test_ClickHz_Values;
var
   f: TSpectrumFrame;
begin
   BeginTest('Test_ClickHz_Values');
   f := MakeFrame(2048);

   CheckEquals(IntToStr(SpectrumBinHz(f, 1)), IntToStr(SpectrumColumnHz(f, 0, 1024)), 'column 0');
   CheckEquals(IntToStr(SpectrumBinHz(f, 3)), IntToStr(SpectrumColumnHz(f, 1, 1024)), 'column 1');
   CheckEquals(IntToStr(SpectrumBinHz(f, 2047)), IntToStr(SpectrumColumnHz(f, 1023, 1024)), 'column 1023');
   CheckEquals(IntToStr(SpectrumBinHz(f, 0)), IntToStr(SpectrumColumnHz(f, -10, 1024)), 'left of the window');
   CheckEquals(IntToStr(SpectrumBinHz(f, 2047)), IntToStr(SpectrumColumnHz(f, 5000, 1024)), 'right of the window');

   (* The real values, so a change to SpectrumBinHz shows here too: bins are
      93.75 Hz, the start is 14,004,000, so bin 1's centre is 140.625 Hz up
      and bin 3's is 328.125. *)
   CheckEquals('14004141', IntToStr(SpectrumColumnHz(f, 0, 1024)), 'column 0 in Hz');
   CheckEquals('14004328', IntToStr(SpectrumColumnHz(f, 1, 1024)), 'column 1 in Hz');
end;

procedure TSpectrumMappingTests.Test_HzToPixel_EdgesAndOffSpan;
var
   f: TSpectrumFrame;
   start: Int64;
begin
   BeginTest('Test_HzToPixel_EdgesAndOffSpan');
   (* 16 bins of 64 Hz across 8 columns: two bins, 128 Hz, per column. *)
   f := MakeFrame(16);
   f.SpanHz := 1024;
   start := SpectrumStartHz(f);

   CheckEquals(-1, SpectrumHzToPixel(f, start, 0), 'no width');
   f.SpanHz := 0;
   CheckEquals(-1, SpectrumHzToPixel(f, start, 8), 'no span');
   f.SpanHz := 1024;

   CheckEquals(0, SpectrumHzToPixel(f, start, 8), 'the low edge');
   CheckEquals(4, SpectrumHzToPixel(f, f.CentreHz, 8), 'the centre (bin 8)');
   CheckEquals(8, SpectrumHzToPixel(f, SpectrumEndHz(f), 8),
               'the high edge is column 8 -- one past the last, so a caller drops it');

   (* By bin, not by rounding: the whole of bins 0 and 1 is column 0. *)
   CheckEquals(0, SpectrumHzToPixel(f, start + 64, 8), 'bin 1 is column 0');
   CheckEquals(0, SpectrumHzToPixel(f, start + 127, 8), 'the top of bin 1 is column 0');
   CheckEquals(1, SpectrumHzToPixel(f, start + 128, 8), 'bin 2 is column 1');
   CheckEquals(7, SpectrumHzToPixel(f, start + 1023, 8), 'the top Hz of the span is column 7');

   (* Off the span, extrapolated by the same rule and bounded to one column
      either side, so a passband edge off the window is still placed. *)
   CheckEquals(-1, SpectrumHzToPixel(f, start - 1, 8), 'one Hz below the span');
   CheckEquals(-1, SpectrumHzToPixel(f, start - 64, 8), 'a bin below the span');
   CheckEquals(8, SpectrumHzToPixel(f, start + 1280, 8), 'right of the span');
   CheckEquals(8, SpectrumHzToPixel(f, start + 1000000000, 8), 'another band, above');
   CheckEquals(-1, SpectrumHzToPixel(f, start - 1000000000, 8), 'another band, below');
end;

(* AGREEMENT (was a pinned disagreement until issue 155): a marker for any
   frequency in a bin is drawn in a column the trace draws that bin in -- the
   rightmost of the run when a bin repeats.  The old continuous rounding put
   half of the 2048/1024 markers one column right of their bin. *)
procedure TSpectrumMappingTests.Test_Agree_MarkerIsTheTraceColumn;
const
   BIN_COUNTS: array[0..5] of Integer = (2048, 2047, 1024, 10, 3, 1);
   WIDTHS: array[0..7] of Integer = (1, 4, 7, 333, 700, 1024, 1999, 3001);
var
   ni, wi, n, w, b, x, misses, notRightmost, notTheBinColumn: Integer;
   f: TSpectrumFrame;
   tag: string;
begin
   BeginTest('Test_Agree_MarkerIsTheTraceColumn');

   for ni := Low(BIN_COUNTS) to High(BIN_COUNTS) do
      begin
      for wi := Low(WIDTHS) to High(WIDTHS) do
         begin
         n := BIN_COUNTS[ni];
         w := WIDTHS[wi];
         f := MakeFrame(n);
         tag := IntToStr(n) + ' bins / ' + IntToStr(w) + ' px';
         misses := 0;
         notRightmost := 0;
         notTheBinColumn := 0;

         for b := 0 to n - 1 do
            begin
            x := SpectrumBinColumn(b, n, w);

            if not ColumnHolds(n, w, x, b) then
               begin
               Inc(misses);
               end;

            if ColumnHolds(n, w, x + 1, b) then
               begin
               Inc(notRightmost);
               end;

            (* Through Hz: the bin's centre places the marker in the bin's
               column (every bin here is wider than 1 Hz). *)
            if (SpectrumHzToPixel(f, SpectrumBinHz(f, b), w) <> x) then
               begin
               Inc(notTheBinColumn);
               end;
            end;

         CheckEquals(0, misses, tag + ': bins whose column does not draw them');
         CheckEquals(0, notRightmost, tag + ': a repeated bin marks its rightmost column');
         CheckEquals(0, notTheBinColumn, tag + ': marker for a bin centre is the bin''s column');
         end;
      end;

   (* The old disagreement's own example: bin 1 at 2048/1024 is drawn in
      column 0, and its marker is now column 0 too. *)
   f := MakeFrame(2048);
   CheckEquals(0, PeakColumnOf(2048, 1024, 1), 'bin 1 drawn');
   CheckEquals(0, SpectrumHzToPixel(f, SpectrumBinHz(f, 1), 1024), 'bin 1 marker');
   CheckEquals(1023, SpectrumHzToPixel(f, SpectrumBinHz(f, 2047), 1024), 'the top bin''s marker');
end;

(* AGREEMENT (was "click vs trace peak"): a click tunes a bin the clicked
   column DRAWS, at every width.  It is the bin under the pointer, NOT the
   column's peak -- NY4I chose exact over peak -- so a carrier in bin 700,
   drawn in column 350 at 2048/1024, is tuned by a click there only to the
   bin beside it, 701, one bin (94 Hz) high.  That is stated, not hidden. *)
procedure TSpectrumMappingTests.Test_Agree_ClickTunesADrawnBin;
const
   BIN_COUNTS: array[0..6] of Integer = (2048, 2047, 1024, 10, 5, 3, 1);
   WIDTHS: array[0..8] of Integer = (1, 3, 4, 7, 333, 700, 1024, 1999, 3001);
var
   ni, wi, n, w, x, b, outside, wrongHz: Integer;
   f: TSpectrumFrame;
   tag: string;
begin
   BeginTest('Test_Agree_ClickTunesADrawnBin');

   for ni := Low(BIN_COUNTS) to High(BIN_COUNTS) do
      begin
      for wi := Low(WIDTHS) to High(WIDTHS) do
         begin
         n := BIN_COUNTS[ni];
         w := WIDTHS[wi];
         f := MakeFrame(n);
         tag := IntToStr(n) + ' bins / ' + IntToStr(w) + ' px';
         outside := 0;
         wrongHz := 0;

         for x := 0 to w - 1 do
            begin
            b := SpectrumClickBin(x, n, w);

            if not ColumnHolds(n, w, x, b) then
               begin
               Inc(outside);
               end;

            if SpectrumHzToBin(f, SpectrumColumnHz(f, x, w)) <> b then
               begin
               Inc(wrongHz);
               end;
            end;

         CheckEquals(0, outside, tag + ': clicks tuning a bin their column does not draw');
         CheckEquals(0, wrongHz, tag + ': click Hz is the click bin''s centre');
         end;
      end;

   f := MakeFrame(2048);
   CheckEquals(350, PeakColumnOf(2048, 1024, 700), 'bin 700 is drawn in column 350');
   CheckEquals(IntToStr(SpectrumBinHz(f, 701)), IntToStr(SpectrumColumnHz(f, 350, 1024)),
               'a click on column 350 tunes bin 701, the bin under the pointer');
   CheckEquals('94', IntToStr(SpectrumColumnHz(f, 350, 1024) - SpectrumBinHz(f, 700)),
               'one bin above a carrier in bin 700, in Hz');
end;

(* AGREEMENT (was a pinned disagreement): a click's marker draws the bin the
   click tuned, at every width; with bins >= columns it is the clicked column
   itself.  Wider than the data a bin repeats -- 1024 bins over 2048 columns,
   columns 2b and 2b+1 both draw bin b -- and its marker is the rightmost of
   the run, so a click on an even column marks its right twin, which draws
   the same bin. *)
procedure TSpectrumMappingTests.Test_Agree_ClickRoundTrip;
const
   BIN_COUNTS: array[0..6] of Integer = (2048, 2047, 1024, 10, 5, 3, 1);
   WIDTHS: array[0..8] of Integer = (1, 3, 4, 7, 333, 700, 1024, 1999, 3001);
var
   ni, wi, n, w, x, xm, b, notDrawn, moved: Integer;
   f: TSpectrumFrame;
   tag: string;
begin
   BeginTest('Test_Agree_ClickRoundTrip');

   for ni := Low(BIN_COUNTS) to High(BIN_COUNTS) do
      begin
      for wi := Low(WIDTHS) to High(WIDTHS) do
         begin
         n := BIN_COUNTS[ni];
         w := WIDTHS[wi];
         f := MakeFrame(n);
         tag := IntToStr(n) + ' bins / ' + IntToStr(w) + ' px';
         notDrawn := 0;
         moved := 0;

         for x := 0 to w - 1 do
            begin
            b := SpectrumClickBin(x, n, w);
            xm := SpectrumHzToPixel(f, SpectrumColumnHz(f, x, w), w);

            if not ColumnHolds(n, w, xm, b) then
               begin
               Inc(notDrawn);
               end;

            if xm <> x then
               begin
               Inc(moved);
               end;
            end;

         CheckEquals(0, notDrawn, tag + ': a click''s marker draws the clicked bin');

         if n >= w then
            begin
            CheckEquals(0, moved, tag + ': every click''s marker is the clicked column');
            end;
         end;
      end;

   (* The old pinned case, now an agreement in the sense above. *)
   f := MakeFrame(1024);
   CheckEquals(1, SpectrumHzToPixel(f, SpectrumColumnHz(f, 0, 2048), 2048),
               '1024/2048: click column 0 marks column 1, its twin');
   CheckTrue(ColumnHolds(1024, 2048, 1, 0) and ColumnHolds(1024, 2048, 0, 0),
             '1024/2048: columns 0 and 1 both draw bin 0');
end;

(* Issue 192: the SPAN function-key command's argument.  Accepted forms, and
  that everything else is refused with both outputs 0. *)
procedure TSpectrumMappingTests.Test_SpanCommand_Syntax;

   procedure Refused(const AText: string);
   var
      step, hz: Integer;
   begin
      CheckFalse(SpectrumParseSpanCommand(AText, step, hz), '"' + AText + '" must be refused');
      CheckEquals(0, step, '"' + AText + '": no step');
      CheckEquals(0, hz, '"' + AText + '": no span');
   end;

   procedure Span(const AText: string; AExpectedHz: Integer);
   var
      step, hz: Integer;
   begin
      CheckTrue(SpectrumParseSpanCommand(AText, step, hz), '"' + AText + '" must be accepted');
      CheckEquals(0, step, '"' + AText + '" is a width, not a step');
      CheckEquals(AExpectedHz, hz, '"' + AText + '" in Hz');
   end;

var
   step, hz: Integer;
begin
   BeginTest('SPAN command: kHz, + and -, and nothing else');

   CheckTrue(SpectrumParseSpanCommand('+', step, hz), '+ accepted');
   CheckEquals(1, step, '+ widens one step');
   CheckEquals(0, hz, '+ carries no width');
   CheckTrue(SpectrumParseSpanCommand('-', step, hz), '- accepted');
   CheckEquals(-1, step, '- narrows one step');

   Span('50', 50000);
   Span('2.5', 2500);
   Span('2.500', 2500);
   Span('0.5', 500);
   Span('5.', 5000);
   Span('368', 368000);
   Span('10000', 10000000);

   Refused('');
   Refused('0');
   Refused('0.000');
   Refused('.');
   Refused('10000.001');
   Refused('10001');
   Refused('99999999999');
   Refused('2.5.0');
   Refused('2.5001');
   Refused('50k');
   Refused(' 50');
   Refused('++');
   Refused('-5');
end;

procedure TSpectrumMappingTests.RunAllTests;
begin
   Test_Columns_WholeBinsPerPixel;
   Test_Columns_FractionalBinsPerPixel;
   Test_Columns_WiderThanTheData_RepeatBins;
   Test_Columns_OneBin;
   Test_Columns_TileTheBins;
   Test_Columns_NoBins;
   Test_Carrier_AtBothEnds;
   Test_ClickBin_IsTheBinUnderThePointer;
   Test_ClickHz_Values;
   Test_HzToPixel_EdgesAndOffSpan;
   Test_Agree_MarkerIsTheTraceColumn;
   Test_Agree_ClickTunesADrawnBin;
   Test_Agree_ClickRoundTrip;
   Test_SpanCommand_Syntax;
end;

end.

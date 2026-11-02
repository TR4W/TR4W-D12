unit uTestSpectrumMapping;
{$I ..\..\src\tr4w.inc}

(*
  The panadapter's horizontal mapping -- column, bin, Hz -- as it is TODAY.

  These pin the behaviour the form had before the arithmetic moved into
  uSpectrumTypes, so the move is provably a move.  Where the trace, the markers
  and click-to-tune disagree, the disagreement is pinned too, with its size:
  a test named ..._Disagree... states a defect to be decided, not a property
  to be protected.  When the definitions are unified those tests change, on
  purpose, in the same commit.

  ONLY ARITHMETIC THAT IS EXACT IN A DOUBLE IS PINNED.  The trace truncates
  x * (BinCount / Width), and BinCount / Width is usually inexact: i386 does
  that multiply in x87 extended precision and x86_64 in SSE double, so the two
  disagree about the bucket boundary in some columns.  The suite runs on both,
  so a case whose answer depends on that rounding is measured outside the
  suite, never asserted here.  The exact cases are widths that divide the
  bin count or that the bin count divides, and small ratios such as 10/4.
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

      procedure Test_BinsPerPixel;
      procedure Test_Columns_WholeBinsPerPixel;
      procedure Test_Columns_FractionalBinsPerPixel;
      procedure Test_Columns_WiderThanTheData_RepeatBins;
      procedure Test_Columns_TileTheBins;
      procedure Test_Columns_NoBins;
      procedure Test_Carrier_AtBothEnds;
      procedure Test_ClickHz_IsTheFirstBinCentre;
      procedure Test_HzToPixel_EdgesAndRounding;
      procedure Test_Disagree_MarkerVsTrace;
      procedure Test_Disagree_ClickVsTracePeak;
      procedure Test_Disagree_ClickRoundTrip;
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
   SpectrumColumnBins(AX, ABinCount, SpectrumBinsPerPixel(ABinCount, AWidth), first, last);
   tag := IntToStr(ABinCount) + ' bins / ' + IntToStr(AWidth) + ' px, column ' + IntToStr(AX);
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

   SpectrumColumnBins(AX, ABinCount, SpectrumBinsPerPixel(ABinCount, AWidth), first, last);
   Result := (ABin >= first) and (ABin <= last);
end;

procedure TSpectrumMappingTests.Test_BinsPerPixel;
begin
   BeginTest('Test_BinsPerPixel');
   Check(SpectrumBinsPerPixel(2048, 0) = 0, 'no width is 0, not a division by zero');
   Check(SpectrumBinsPerPixel(2048, -5) = 0, 'a negative width is 0');
   Check(SpectrumBinsPerPixel(2048, 1024) = 2.0, '2048 / 1024');
   Check(SpectrumBinsPerPixel(10, 4) = 2.5, '10 / 4');
   Check(SpectrumBinsPerPixel(3, 4) = 0.75, '3 / 4');
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
   (* 2.5 bins per column: the buckets are UNEVEN, 2-3-2-3, because both ends
      are truncated.  That is today's behaviour, not a goal. *)
   CheckColumn(10, 4, 0, 0, 1);
   CheckColumn(10, 4, 1, 2, 4);
   CheckColumn(10, 4, 2, 5, 6);
   CheckColumn(10, 4, 3, 7, 9);
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

(* PROPERTIES that hold under either rounding, so they are safe to assert for
   inexact ratios too: column 0 starts at bin 0, and when there are at least as
   many bins as columns, neighbouring columns meet with no gap and no overlap;
   when there are fewer, every bin is shown and the last column shows the top
   bin.  (Whether the last column REACHES the top bin when there are more bins
   than columns is exactly what depends on rounding -- see the unit header.) *)
procedure TSpectrumMappingTests.Test_Columns_TileTheBins;
const
   BIN_COUNTS: array[0..2] of Integer = (2048, 1024, 10);
   WIDTHS: array[0..7] of Integer = (3, 7, 100, 333, 700, 1000, 1999, 3001);
var
   ni, wi, n, w, x, first, last, prevLast, prevFirst: Integer;
   bpp: Double;
   tag: string;
   gapFound, skipFound: Boolean;
begin
   BeginTest('Test_Columns_TileTheBins');

   for ni := Low(BIN_COUNTS) to High(BIN_COUNTS) do
      begin
      for wi := Low(WIDTHS) to High(WIDTHS) do
         begin
         n := BIN_COUNTS[ni];
         w := WIDTHS[wi];
         bpp := SpectrumBinsPerPixel(n, w);
         tag := IntToStr(n) + ' bins / ' + IntToStr(w) + ' px';
         gapFound := False;
         skipFound := False;
         prevLast := -1;
         prevFirst := -1;

         for x := 0 to w - 1 do
            begin
            SpectrumColumnBins(x, n, bpp, first, last);

            if x = 0 then
               begin
               CheckEquals(0, first, tag + ': column 0 starts at bin 0');
               end;

            if n >= w then
               begin
               if (x > 0) and (first <> prevLast + 1) then
                  begin
                  gapFound := True;
                  end;
               end
            else
               begin
               if (first <> last) or ((x > 0) and (first <> prevFirst) and (first <> prevFirst + 1)) then
                  begin
                  skipFound := True;
                  end;
               end;

            prevFirst := first;
            prevLast := last;
            end;

         Check(not gapFound, tag + ': neighbouring columns must tile the bins');
         Check(not skipFound, tag + ': one bin per column, never skipping one');

         if n < w then
            begin
            CheckEquals(n - 1, prevLast, tag + ': the last column shows the top bin');
            end;
         end;
      end;
end;

procedure TSpectrumMappingTests.Test_Columns_NoBins;
var
   first, last: Integer;
   f: TSpectrumFrame;
begin
   BeginTest('Test_Columns_NoBins');
   SpectrumColumnBins(3, 0, 1.0, first, last);
   CheckEquals(-1, first, 'no bins: first');
   CheckEquals(-1, last, 'no bins: last');

   f := MakeFrame(0);
   CheckEquals('0', IntToStr(SpectrumColumnHz(f, 3, 1.0)), 'no bins: no click frequency');
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

   (* The bottom bin is in column 0 at ANY width -- Trunc(0) is exact. *)
   CheckEquals(0, PeakColumnOf(2048, 700, 0), '2048/700 bottom');
   CheckEquals(0, PeakColumnOf(2048, 3001, 0), '2048/3001 bottom');
end;

procedure TSpectrumMappingTests.Test_ClickHz_IsTheFirstBinCentre;
var
   f: TSpectrumFrame;
   bpp: Double;
begin
   BeginTest('Test_ClickHz_IsTheFirstBinCentre');
   f := MakeFrame(2048);
   bpp := SpectrumBinsPerPixel(2048, 1024);

   CheckEquals(IntToStr(SpectrumBinHz(f, 0)), IntToStr(SpectrumColumnHz(f, 0, bpp)), 'column 0');
   CheckEquals(IntToStr(SpectrumBinHz(f, 2)), IntToStr(SpectrumColumnHz(f, 1, bpp)), 'column 1');
   CheckEquals(IntToStr(SpectrumBinHz(f, 2046)), IntToStr(SpectrumColumnHz(f, 1023, bpp)), 'column 1023');

   (* Off either side clamps to the end bins, as click-to-tune always did. *)
   CheckEquals(IntToStr(SpectrumBinHz(f, 0)), IntToStr(SpectrumColumnHz(f, -10, bpp)), 'left of the window');
   CheckEquals(IntToStr(SpectrumBinHz(f, 2047)), IntToStr(SpectrumColumnHz(f, 5000, bpp)), 'right of the window');

   (* The real values, so a change to SpectrumBinHz shows here too: bins are
      93.75 Hz, the start is 14,004,000. *)
   CheckEquals('14004047', IntToStr(SpectrumColumnHz(f, 0, bpp)), 'column 0 in Hz');
   CheckEquals('14004234', IntToStr(SpectrumColumnHz(f, 1, bpp)), 'column 1 in Hz');
end;

procedure TSpectrumMappingTests.Test_HzToPixel_EdgesAndRounding;
var
   f: TSpectrumFrame;
   start: Int64;
begin
   BeginTest('Test_HzToPixel_EdgesAndRounding');
   (* 1024 Hz across 8 columns: 128 Hz each, so every value below is exact. *)
   f := MakeFrame(2048);
   f.SpanHz := 1024;
   start := SpectrumStartHz(f);

   CheckEquals(-1, SpectrumHzToPixel(f, start, 0), 'no width');
   f.SpanHz := 0;
   CheckEquals(-1, SpectrumHzToPixel(f, start, 8), 'no span');
   f.SpanHz := 1024;

   CheckEquals(0, SpectrumHzToPixel(f, start, 8), 'the low edge');
   CheckEquals(4, SpectrumHzToPixel(f, f.CentreHz, 8), 'the centre');
   CheckEquals(8, SpectrumHzToPixel(f, SpectrumEndHz(f), 8),
               'the high edge is column 8 -- one past the last, so a caller drops it');

   (* Banker's rounding: a half rounds to EVEN. *)
   CheckEquals(0, SpectrumHzToPixel(f, start + 64, 8), 'half a column rounds to 0');
   CheckEquals(2, SpectrumHzToPixel(f, start + 192, 8), 'one and a half rounds to 2');
   CheckEquals(1, SpectrumHzToPixel(f, start + 65, 8), 'just past half rounds up');

   (* Not clamped: off-span frequencies land off the window. *)
   CheckEquals(-1, SpectrumHzToPixel(f, start - 65, 8), 'left of the span');
   CheckEquals(10, SpectrumHzToPixel(f, start + 1280, 8), 'right of the span');

   (* Half a column BELOW the span still rounds to column 0, so a marker for a
      frequency the display does not cover is drawn on its left edge. *)
   CheckEquals(0, SpectrumHzToPixel(f, start - 64, 8), 'half a column below the span');
end;

(* DISAGREEMENT, PINNED: a marker for a bin's centre can land one column right
   of the column the trace draws that bin in.  At 2048 bins across 1024 columns
   the trace puts bins 2x and 2x+1 in column x; the marker for bin 2x+1's
   centre is at x + 0.75 and rounds to x + 1.  Half the bins, by exactly one
   column. *)
procedure TSpectrumMappingTests.Test_Disagree_MarkerVsTrace;
var
   f: TSpectrumFrame;
   b, x, misses, worst: Integer;
begin
   BeginTest('Test_Disagree_MarkerVsTrace');
   f := MakeFrame(2048);
   misses := 0;
   worst := 0;

   for b := 0 to 2047 do
      begin
      x := SpectrumHzToPixel(f, SpectrumBinHz(f, b), 1024);

      if not ColumnHolds(2048, 1024, x, b) then
         begin
         Inc(misses);

         if Abs(x - PeakColumnOf(2048, 1024, b)) > worst then
            begin
            worst := Abs(x - PeakColumnOf(2048, 1024, b));
            end;
         end;
      end;

   CheckEquals(1024, misses, 'bins whose marker misses the drawn column');
   CheckEquals(1, worst, 'by at most one column');
   CheckEquals(1, SpectrumHzToPixel(f, SpectrumBinHz(f, 1), 1024), 'bin 1 marker');
   CheckEquals(0, PeakColumnOf(2048, 1024, 1), 'bin 1 drawn');
end;

(* DISAGREEMENT, PINNED: the trace shows a column's MAXIMUM, click-to-tune
   tunes its FIRST bin.  A carrier in bin 2x+1 peaks in column x, and a click
   there tunes bin 2x -- one bin, 93.75 Hz at a 192 kHz span, low. *)
procedure TSpectrumMappingTests.Test_Disagree_ClickVsTracePeak;
var
   f: TSpectrumFrame;
   bpp: Double;
   x: Integer;
begin
   BeginTest('Test_Disagree_ClickVsTracePeak');
   f := MakeFrame(2048);
   bpp := SpectrumBinsPerPixel(2048, 1024);
   x := PeakColumnOf(2048, 1024, 701);

   CheckEquals(350, x, 'bin 701 is drawn in column 350');
   CheckEquals(IntToStr(SpectrumBinHz(f, 700)), IntToStr(SpectrumColumnHz(f, x, bpp)),
               'a click on that column tunes bin 700, not the carrier');
   CheckEquals('94', IntToStr(SpectrumBinHz(f, 701) - SpectrumColumnHz(f, x, bpp)),
               'the miss in Hz');
end;

(* DISAGREEMENT, PINNED: wider than the data, a click and the marker for the
   frequency it tuned are not in the same column.  1024 bins across 2048
   columns: columns 2b and 2b+1 both show bin b, a click on either tunes bin
   b's centre, and that centre's marker is column 2b+1 -- so a click on an
   EVEN column draws its marker one column right. *)
procedure TSpectrumMappingTests.Test_Disagree_ClickRoundTrip;
var
   f: TSpectrumFrame;
   bpp: Double;
   x, moved: Integer;
begin
   BeginTest('Test_Disagree_ClickRoundTrip');
   f := MakeFrame(1024);
   bpp := SpectrumBinsPerPixel(1024, 2048);
   moved := 0;

   for x := 0 to 2047 do
      begin
      if SpectrumHzToPixel(f, SpectrumColumnHz(f, x, bpp), 2048) <> x then
         begin
         Inc(moved);
         end;
      end;

   CheckEquals(1024, moved, '1024/2048: clicks whose marker is another column');
   CheckEquals(1, SpectrumHzToPixel(f, SpectrumColumnHz(f, 0, bpp), 2048), 'click column 0');

   (* At two bins per column the round trip holds, which is why it looked
      right on the bench. *)
   f := MakeFrame(2048);
   bpp := SpectrumBinsPerPixel(2048, 1024);
   moved := 0;

   for x := 0 to 1023 do
      begin
      if SpectrumHzToPixel(f, SpectrumColumnHz(f, x, bpp), 1024) <> x then
         begin
         Inc(moved);
         end;
      end;

   CheckEquals(0, moved, '2048/1024: every click round-trips');
end;

procedure TSpectrumMappingTests.RunAllTests;
begin
   Test_BinsPerPixel;
   Test_Columns_WholeBinsPerPixel;
   Test_Columns_FractionalBinsPerPixel;
   Test_Columns_WiderThanTheData_RepeatBins;
   Test_Columns_TileTheBins;
   Test_Columns_NoBins;
   Test_Carrier_AtBothEnds;
   Test_ClickHz_IsTheFirstBinCentre;
   Test_HzToPixel_EdgesAndRounding;
   Test_Disagree_MarkerVsTrace;
   Test_Disagree_ClickVsTracePeak;
   Test_Disagree_ClickRoundTrip;
end;

end.

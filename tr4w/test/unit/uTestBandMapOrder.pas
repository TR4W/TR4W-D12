unit uTestBandMapOrder;

(* THE BAND MAP'S PURE ARITHMETIC (issues 82 and 246): the beam-heading order
  and the centring column. Every case is one a wrong implementation gets wrong
  quietly -- above all the wrap at 0/360, where a plain subtraction ranks a
  spot at 10 degrees as 340 away from a beam on 350. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TBandMapOrderTests = class(TTestCase)
   protected
      procedure Test_AngularDistance_WrapsAtNorth;
      procedure Test_AngularDistance_NeverPastHalfTurn;
      procedure Test_AngularDistance_OutOfRangeInputs;
      procedure Test_Rank_NoHeadingIsLast;
      procedure Test_Rank_NoReferenceIsAbsolute;
      procedure Test_Order_NearestTheBeamFirst;
      procedure Test_Order_WrapsAcrossNorth;
      procedure Test_Order_TiesKeepFrequencyOrder;
      procedure Test_Order_NoReferenceIsAbsoluteHeading;
      procedure Test_Order_NoHeadingGoesToTheEnd;
      procedure Test_Order_EmptyAndSingle;
      procedure Test_FirstSpotAbove_Basics;
      procedure Test_CentreLeftCol_Middle;
      procedure Test_CentreLeftCol_Clamps;
      procedure Test_CentreLeftCol_EverythingFits;
      procedure Test_SpotNearRadio_GuardBand;
      procedure Test_SpotNearRadio_NoRadio;
      procedure Test_NearestSpot_Basics;
      procedure Test_NearestSpot_AnyOrderAndTies;
      procedure Test_NearestSpot_EmptyOrNoRadio;
      procedure Test_DisplayLimit_IsACeiling;
      procedure Test_DisplayLimit_UnknownWindowUsesTheSetting;
      procedure Test_DisplayLimit_EvenAndFloored;
      procedure Test_TextSize_DefaultsAreUnchanged;
      procedure Test_TextSize_RowAndColumnNeverShrinkBelowTheSettings;
      procedure Test_TextSize_GrowsWithTheText;
      procedure Test_TextSize_Step;
      procedure Test_FollowsRadio_ModeChangeAtSameFrequency;
      procedure Test_AClusterSpotOn14240IsBand20Phone;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC,
   logwind,   (* GetBandMapBandModeFromFrequency, BandMapModeCutoffFrequency *)
   uBandMapOrder;

procedure TBandMapOrderTests.Test_AngularDistance_WrapsAtNorth;
begin
   BeginTest('Test_AngularDistance_WrapsAtNorth');
   CheckEquals(20, AngularDistance(350, 10), 'beam on 350, spot at 10: 20 degrees, not 340');
   CheckEquals(20, AngularDistance(10, 350), 'and symmetric');
   CheckEquals(1,  AngularDistance(359, 0), '359 and 0 are one degree apart');
   CheckEquals(0,  AngularDistance(0, 0), 'same heading');
   CheckEquals(90, AngularDistance(45, 135), 'no wrap needed');
end;

procedure TBandMapOrderTests.Test_AngularDistance_NeverPastHalfTurn;
begin
   BeginTest('Test_AngularDistance_NeverPastHalfTurn');
   CheckEquals(180, AngularDistance(0, 180), 'straight behind');
   CheckEquals(179, AngularDistance(0, 181), 'one past behind wraps the other way');
   CheckEquals(179, AngularDistance(0, 179), 'one short of behind');
end;

procedure TBandMapOrderTests.Test_AngularDistance_OutOfRangeInputs;
begin
   BeginTest('Test_AngularDistance_OutOfRangeInputs');
   CheckEquals(0, AngularDistance(360, 0), '360 is north');
   CheckEquals(10, AngularDistance(365, 355), 'values past 359 are normalised');
end;

procedure TBandMapOrderTests.Test_Rank_NoHeadingIsLast;
begin
   BeginTest('Test_Rank_NoHeadingIsLast');
   CheckTrue(BeamRank(NO_HEADING, 90) > BeamRank(180, 0),
             'a spot with no heading ranks after the farthest real one (angular)');
   CheckTrue(BeamRank(NO_HEADING, NO_HEADING) > BeamRank(359, NO_HEADING),
             'and after the largest absolute heading');
end;

procedure TBandMapOrderTests.Test_Rank_NoReferenceIsAbsolute;
begin
   BeginTest('Test_Rank_NoReferenceIsAbsolute');
   CheckEquals(270, BeamRank(270, NO_HEADING), 'no beam: rank is the heading itself');
   CheckEquals(0,   BeamRank(360, NO_HEADING), '360 normalises to 0');
end;

procedure TBandMapOrderTests.Test_Order_NearestTheBeamFirst;
var
   headings: array of integer;
   order: array of integer;
begin
   BeginTest('Test_Order_NearestTheBeamFirst');
   SetLength(headings, 4);
   SetLength(order, 4);
   headings[0] := 200;
   headings[1] := 95;
   headings[2] := 10;
   headings[3] := 120;
   OrderByBeam(headings, 100, order);
   CheckEquals(1, order[0], '95 is 5 away: first');
   CheckEquals(3, order[1], '120 is 20 away');
   CheckEquals(2, order[2], '10 is 90 away');
   CheckEquals(0, order[3], '200 is 100 away: last');
end;

procedure TBandMapOrderTests.Test_Order_WrapsAcrossNorth;
var
   headings: array of integer;
   order: array of integer;
begin
   BeginTest('Test_Order_WrapsAcrossNorth');
   SetLength(headings, 4);
   SetLength(order, 4);
   headings[0] := 170;
   headings[1] := 5;
   headings[2] := 340;
   headings[3] := 355;
   OrderByBeam(headings, 350, order);
   CheckEquals(3, order[0], '355 is 5 from a beam on 350');
   CheckEquals(2, order[1], '340 is 10 away');
   CheckEquals(1, order[2], '5 is 15 away ACROSS NORTH -- a plain subtraction says 345');
   CheckEquals(0, order[3], '170 is 180 away');
end;

procedure TBandMapOrderTests.Test_Order_TiesKeepFrequencyOrder;
var
   headings: array of integer;
   order: array of integer;
begin
   BeginTest('Test_Order_TiesKeepFrequencyOrder');
   SetLength(headings, 4);
   SetLength(order, 4);
   (* Positions are frequency order. 10 and 350 are both 10 from north; 90
     and 90 tie exactly. *)
   headings[0] := 350;
   headings[1] := 90;
   headings[2] := 10;
   headings[3] := 90;
   OrderByBeam(headings, 0, order);
   CheckEquals(0, order[0], 'tie at 10 degrees: the lower frequency first');
   CheckEquals(2, order[1], 'then the other one');
   CheckEquals(1, order[2], 'tie at 90: the lower frequency first');
   CheckEquals(3, order[3], 'then the other');
end;

procedure TBandMapOrderTests.Test_Order_NoReferenceIsAbsoluteHeading;
var
   headings: array of integer;
   order: array of integer;
begin
   BeginTest('Test_Order_NoReferenceIsAbsoluteHeading');
   SetLength(headings, 3);
   SetLength(order, 3);
   headings[0] := 300;
   headings[1] := 20;
   headings[2] := 180;
   OrderByBeam(headings, NO_HEADING, order);
   CheckEquals(1, order[0], 'north first: 20');
   CheckEquals(2, order[1], '180');
   CheckEquals(0, order[2], '300 last, 0 to 359 ascending -- option (a), the no-rotator fallback');
end;

procedure TBandMapOrderTests.Test_Order_NoHeadingGoesToTheEnd;
var
   headings: array of integer;
   order: array of integer;
begin
   BeginTest('Test_Order_NoHeadingGoesToTheEnd');
   SetLength(headings, 4);
   SetLength(order, 4);
   headings[0] := NO_HEADING;
   headings[1] := 180;
   headings[2] := NO_HEADING;
   headings[3] := 0;
   OrderByBeam(headings, 0, order);
   CheckEquals(3, order[0], 'the spot on the beam');
   CheckEquals(1, order[1], 'the spot behind it');
   CheckEquals(0, order[2], 'then the headingless, in frequency order');
   CheckEquals(2, order[3], 'second headingless');
end;

procedure TBandMapOrderTests.Test_Order_EmptyAndSingle;
var
   headings: array of integer;
   order: array of integer;
begin
   BeginTest('Test_Order_EmptyAndSingle');
   SetLength(headings, 0);
   SetLength(order, 0);
   OrderByBeam(headings, 0, order);
   Check(True, 'an empty list is not an error');

   SetLength(headings, 1);
   SetLength(order, 1);
   headings[0] := 77;
   OrderByBeam(headings, 0, order);
   CheckEquals(0, order[0], 'one spot stays');
end;

procedure TBandMapOrderTests.Test_FirstSpotAbove_Basics;
var
   freqs: array of integer;
begin
   BeginTest('Test_FirstSpotAbove_Basics');
   SetLength(freqs, 4);
   freqs[0] := 14010;
   freqs[1] := 14020;
   freqs[2] := 14030;
   freqs[3] := 14040;
   CheckEquals(2, FirstSpotAbove(freqs, 14025), 'between two spots: the one above');
   CheckEquals(2, FirstSpotAbove(freqs, 14020), 'ON a spot: the next one above, not that spot');
   CheckEquals(0, FirstSpotAbove(freqs, 13000), 'below every spot: the first');
   CheckEquals(3, FirstSpotAbove(freqs, 15000), 'above every spot: the last');
   SetLength(freqs, 0);
   CheckEquals(-1, FirstSpotAbove(freqs, 14000), 'no spots');
end;

procedure TBandMapOrderTests.Test_CentreLeftCol_Middle;
begin
   BeginTest('Test_CentreLeftCol_Middle');
   CheckEquals(3, CentreLeftCol(5, 5, 20), 'column 5 in the middle of five: left is 3');
   CheckEquals(4, CentreLeftCol(7, 6, 20), 'an even count puts the target just right of middle');
   CheckEquals(9, CentreLeftCol(10, 3, 30), 'three visible: left is target - 1');
end;

procedure TBandMapOrderTests.Test_CentreLeftCol_Clamps;
begin
   BeginTest('Test_CentreLeftCol_Clamps');
   CheckEquals(0, CentreLeftCol(1, 5, 20), 'near the start: not below 0');
   CheckEquals(0, CentreLeftCol(0, 5, 20), 'the first column');
   CheckEquals(15, CentreLeftCol(19, 5, 20), 'the last column: scrolled as far right as it goes');
   CheckEquals(15, CentreLeftCol(18, 5, 20), 'near the end: clamped so no blank space shows');
end;

procedure TBandMapOrderTests.Test_CentreLeftCol_EverythingFits;
begin
   BeginTest('Test_CentreLeftCol_EverythingFits');
   CheckEquals(0, CentreLeftCol(2, 8, 4), 'fewer columns than fit: nowhere to scroll');
   CheckEquals(0, CentreLeftCol(0, 1, 1), 'a one-column grid');
end;

(* ISSUE 65 (a): the red frequency field. *)
procedure TBandMapOrderTests.Test_SpotNearRadio_GuardBand;
begin
   BeginTest('Test_SpotNearRadio_GuardBand');
   CheckTrue(SpotNearRadio(14025200, 14025000, 200), 'exactly the guard band away: inside');
   CheckTrue(SpotNearRadio(14024800, 14025000, 200), 'below the radio counts too');
   CheckFalse(SpotNearRadio(14025201, 14025000, 200), 'one hertz past: outside');
   CheckTrue(SpotNearRadio(14025000, 14025000, 0), 'guard band 0: an exact match is near');
   CheckFalse(SpotNearRadio(14025001, 14025000, 0), 'guard band 0: one hertz off is not');
end;

procedure TBandMapOrderTests.Test_SpotNearRadio_NoRadio;
begin
   BeginTest('Test_SpotNearRadio_NoRadio');
   CheckFalse(SpotNearRadio(0, 0, 0), 'no radio: even a 0 Hz spot is not marked');
   CheckFalse(SpotNearRadio(150, 0, 200), 'no radio: inside the guard band of 0 is still not marked');
   CheckFalse(SpotNearRadio(14025000, -1, 65535), 'a negative frequency is no radio');
end;

(* ISSUE 65 (b): the outline goes on ONE spot. *)
procedure TBandMapOrderTests.Test_NearestSpot_Basics;
var
   freqs: array of integer;
begin
   BeginTest('Test_NearestSpot_Basics');
   SetLength(freqs, 4);
   freqs[0] := 14010000;
   freqs[1] := 14020000;
   freqs[2] := 14030000;
   freqs[3] := 14040000;
   CheckEquals(1, NearestSpotIndex(freqs, 14024000), 'between two: the closer, below');
   CheckEquals(2, NearestSpotIndex(freqs, 14026000), 'between two: the closer, above');
   CheckEquals(2, NearestSpotIndex(freqs, 14030000), 'on a spot: that spot');
   CheckEquals(0, NearestSpotIndex(freqs, 7000000), 'below every spot: the lowest');
   CheckEquals(3, NearestSpotIndex(freqs, 21000000), 'above every spot: the highest');
end;

procedure TBandMapOrderTests.Test_NearestSpot_AnyOrderAndTies;
var
   freqs: array of integer;
begin
   BeginTest('Test_NearestSpot_AnyOrderAndTies');
   (* Beam-heading order is not frequency order. *)
   SetLength(freqs, 4);
   freqs[0] := 14040000;
   freqs[1] := 14010000;
   freqs[2] := 14031000;
   freqs[3] := 14020000;
   CheckEquals(2, NearestSpotIndex(freqs, 14032000), 'unsorted: still the closest');
   CheckEquals(1, NearestSpotIndex(freqs, 14015000),
               'equidistant (5 kHz each side): the FIRST position wins');
   SetLength(freqs, 1);
   freqs[0] := 3500000;
   CheckEquals(0, NearestSpotIndex(freqs, 28000000), 'one spot: it is the nearest, however far');
end;

procedure TBandMapOrderTests.Test_NearestSpot_EmptyOrNoRadio;
var
   freqs: array of integer;
begin
   BeginTest('Test_NearestSpot_EmptyOrNoRadio');
   SetLength(freqs, 0);
   CheckEquals(-1, NearestSpotIndex(freqs, 14025000), 'an empty map: no outline');
   SetLength(freqs, 2);
   freqs[0] := 14010000;
   freqs[1] := 14020000;
   CheckEquals(-1, NearestSpotIndex(freqs, 0), 'no radio frequency: no outline');
   CheckEquals(-1, NearestSpotIndex(freqs, -5), 'a negative frequency is no radio');
end;

(* ISSUE 65, question 2: BAND MAP DISPLAY LIMIT is a ceiling on what fits. *)
procedure TBandMapOrderTests.Test_DisplayLimit_IsACeiling;
begin
   BeginTest('Test_DisplayLimit_IsACeiling');
   CheckEquals(40, EffectiveDisplayLimit(164, 10, 4), 'fewer fit than the setting: what fits');
   CheckEquals(164, EffectiveDisplayLimit(164, 30, 10), 'more fit than the setting: the setting');
   CheckEquals(30, EffectiveDisplayLimit(30, 6, 5), 'exactly the setting fits');
end;

procedure TBandMapOrderTests.Test_DisplayLimit_UnknownWindowUsesTheSetting;
begin
   BeginTest('Test_DisplayLimit_UnknownWindowUsesTheSetting');
   CheckEquals(164, EffectiveDisplayLimit(164, 0, 4), 'no rows known: the setting');
   CheckEquals(164, EffectiveDisplayLimit(164, 10, 0), 'no whole column fits: the setting');
   CheckEquals(164, EffectiveDisplayLimit(164, -3, -1), 'a nonsense size: the setting');
end;

procedure TBandMapOrderTests.Test_DisplayLimit_EvenAndFloored;
begin
   BeginTest('Test_DisplayLimit_EvenAndFloored');
   CheckEquals(20, EffectiveDisplayLimit(164, 7, 3),
               '21 fit: 20, because an odd limit centres one short anyway');
   CheckEquals(2, EffectiveDisplayLimit(164, 1, 1),
               'one cell fits: 2, never 1 -- a limit of 1 centres on NO spot');
   CheckEquals(30, EffectiveDisplayLimit(31, 40, 40), 'an odd setting is evened too');
end;

(* THE TEXT SIZE MENU. The pin that matters is the first: at the default size
  and the default row height and column width the cell is EXACTLY what it was
  before the menu existed (row 14, column 135, text 13). *)
procedure TBandMapOrderTests.Test_TextSize_DefaultsAreUnchanged;
begin
   BeginTest('Test_TextSize_DefaultsAreUnchanged');
   CheckEquals(13, BandMapTextHeight(3), 'size 3 is a 13-pixel text, as before');
   CheckEquals(14, BandMapRowHeight(14, 3), 'the default row height is unchanged');
   CheckEquals(135, BandMapColumnWidth(135, 3), 'the default column width is unchanged');
   CheckEquals(3, BANDMAP_REFERENCE_SIZE, 'the reference is the setting default');
   CheckEquals(6, BandMapTextHeight(-4), 'the floor of the range is 6 pixels');
end;

procedure TBandMapOrderTests.Test_TextSize_RowAndColumnNeverShrinkBelowTheSettings;
var
   size: integer;
begin
   BeginTest('Test_TextSize_RowAndColumnNeverShrinkBelowTheSettings');
   for size := -4 to 3 do
      begin
      CheckEquals(14, BandMapRowHeight(14, size),
                  'smaller text keeps the operator''s row height');
      CheckEquals(135, BandMapColumnWidth(135, size),
                  'smaller text keeps the operator''s column width');
      end;
   CheckEquals(50, BandMapRowHeight(50, 12), 'a tall row setting is kept at any size');
   CheckEquals(200, BandMapColumnWidth(200, -4), 'a wide column setting is kept');
   CheckEquals(100, BandMapColumnWidth(100, -4), 'the minimum width setting is kept');
end;

procedure TBandMapOrderTests.Test_TextSize_GrowsWithTheText;
var
   size, rowPrev, colPrev: integer;
begin
   BeginTest('Test_TextSize_GrowsWithTheText');
   rowPrev := 0;
   colPrev := 0;
   for size := -4 to 12 do
      begin
      CheckTrue(BandMapRowHeight(14, size) >= rowPrev, 'the row never shrinks as the text grows');
      CheckTrue(BandMapColumnWidth(135, size) >= colPrev, 'the column never shrinks as the text grows');
      CheckTrue(BandMapRowHeight(14, size) > BandMapTextHeight(size),
                'a row is always taller than its text');
      rowPrev := BandMapRowHeight(14, size);
      colPrev := BandMapColumnWidth(135, size);
      end;
   CheckEquals(23, BandMapRowHeight(14, 12), 'the largest text: 22 pixels plus one');
   CheckEquals(228, BandMapColumnWidth(135, 12), 'the largest text: 135 * 22 div 13');
   CheckEquals(14, BandMapRowHeight(12, 3),
               'a 12-pixel row setting is raised to fit the 13-pixel text');
end;

procedure TBandMapOrderTests.Test_TextSize_Step;
begin
   BeginTest('Test_TextSize_Step');
   CheckEquals(4, SteppedBandMapSize(3, 1, -4, 12), 'larger');
   CheckEquals(2, SteppedBandMapSize(3, -1, -4, 12), 'smaller');
   CheckEquals(12, SteppedBandMapSize(12, 1, -4, 12), 'larger is held at the maximum');
   CheckEquals(-4, SteppedBandMapSize(-4, -1, -4, 12), 'smaller is held at the minimum');
   CheckEquals(0, SteppedBandMapSize(0, 0, -4, 12), 'no step is no change');
end;

procedure TBandMapOrderTests.Test_FollowsRadio_ModeChangeAtSameFrequency;
begin
   BeginTest('Test_FollowsRadio_ModeChangeAtSameFrequency');
   (* The K4 sequence of 2026-11-22: frequency first, mode a poll later. *)
   CheckTrue(BandMapFollowsRadio(0, 14230000, 14230000, True),
             'no frequency move, mode differs: follow');
   CheckTrue(BandMapFollowsRadio(30000, 14230000, 18097000, False),
             'frequency moved to a new place: follow');
   CheckFalse(BandMapFollowsRadio(0, 14230000, 14230000, False),
              'nothing changed: do not follow');
   CheckFalse(BandMapFollowsRadio(30000, 14230000, 14230000, False),
              'moved but already at the cursor: do not follow');
   CheckFalse(BandMapFollowsRadio(30000, 0, 14230000, True),
              'a radio that reports no frequency never moves the map');
end;

(* A CLUSTER SPOT AT 14240.0 IS 20 m PHONE (NY4I, 2026-11-22: the radio was on
  14.230 SSB and no spot showed). The spot's mode comes from its FREQUENCY
  alone, so with the band map on 20 m Phone the filter must pass it. *)
procedure TBandMapOrderTests.Test_AClusterSpotOn14240IsBand20Phone;
var
   savedCutoff: LongInt;
   band: BandType;
   mode: ModeType;
begin
   BeginTest('Test_AClusterSpotOn14240IsBand20Phone');
   savedCutoff := BandMapModeCutoffFrequency[Band20];
   BandMapModeCutoffFrequency[Band20] := 14100000;
   try
      band := NoBand;
      mode := NoMode;
      GetBandMapBandModeFromFrequency(14240000, band, mode);
      CheckEquals(Ord(Band20), Ord(band), '14240.0 is on 20 m');
      CheckEquals(Ord(Phone), Ord(mode), '14240.0 is above the 14100 cutoff: Phone');
      GetBandMapBandModeFromFrequency(14025000, band, mode);
      CheckEquals(Ord(CW), Ord(mode), '14025.0 is below the cutoff: CW');
   finally
      BandMapModeCutoffFrequency[Band20] := savedCutoff;
   end;
end;

procedure TBandMapOrderTests.RunAllTests;
begin
   Test_AClusterSpotOn14240IsBand20Phone;
   Test_FollowsRadio_ModeChangeAtSameFrequency;
   Test_AngularDistance_WrapsAtNorth;
   Test_AngularDistance_NeverPastHalfTurn;
   Test_AngularDistance_OutOfRangeInputs;
   Test_Rank_NoHeadingIsLast;
   Test_Rank_NoReferenceIsAbsolute;
   Test_Order_NearestTheBeamFirst;
   Test_Order_WrapsAcrossNorth;
   Test_Order_TiesKeepFrequencyOrder;
   Test_Order_NoReferenceIsAbsoluteHeading;
   Test_Order_NoHeadingGoesToTheEnd;
   Test_Order_EmptyAndSingle;
   Test_FirstSpotAbove_Basics;
   Test_CentreLeftCol_Middle;
   Test_CentreLeftCol_Clamps;
   Test_CentreLeftCol_EverythingFits;
   Test_SpotNearRadio_GuardBand;
   Test_SpotNearRadio_NoRadio;
   Test_NearestSpot_Basics;
   Test_NearestSpot_AnyOrderAndTies;
   Test_NearestSpot_EmptyOrNoRadio;
   Test_DisplayLimit_IsACeiling;
   Test_DisplayLimit_UnknownWindowUsesTheSetting;
   Test_DisplayLimit_EvenAndFloored;
   Test_TextSize_DefaultsAreUnchanged;
   Test_TextSize_RowAndColumnNeverShrinkBelowTheSettings;
   Test_TextSize_GrowsWithTheText;
   Test_TextSize_Step;
end;

end.

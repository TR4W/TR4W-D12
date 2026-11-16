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
   public
      procedure RunAllTests; override;
   end;

implementation

uses
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

procedure TBandMapOrderTests.RunAllTests;
begin
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
end;

end.

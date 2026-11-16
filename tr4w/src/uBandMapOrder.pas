unit uBandMapOrder;

(* THE BAND MAP'S TWO PIECES OF PURE ARITHMETIC (issues 82 and 246).

  A LEAF, deliberately: uSpots and the band map form pull in the whole program
  and cannot be linked by the unit tests, and "which spot comes first" and
  "which column goes in the middle" are exactly the questions that should be
  pinned rather than judged on a bench. Nothing here knows what a spot is.

  SORT BY BEAM HEADING (issue 82, NY4I chose 1b). The map is ordered by the
  ANGULAR DISTANCE between a spot's beam heading and where the beam points now,
  smallest first -- "what can I work without turning". Distance is measured
  round the circle, so with the beam on 350 a spot at 10 is 20 degrees away,
  not 340: that wrap at 0/360 is the thing the tests pin.

  Two fallbacks, both NY4I's:

    * A spot with no heading (no station grid, or none for the call) goes to
      the END (NO_HEADING).
    * No reference heading at all -- no rotator, or none commanded yet -- sorts
      by the ABSOLUTE heading, 0 to 359, which is the issue's option (a).

  Spots that tie keep the order they came in, and they come in frequency
  order, so ties read in frequency order.

  CENTRING (issue 246). The band map is a newspaper layout: spots run down a
  column and on to the next, so "centred on the radio" means scrolling the grid
  sideways until the column holding the cursor's spot is in the middle. *)

{$I tr4w.inc}

interface

const
   (* What a spot's heading is when it has none -- GetBeamHeading's own -1. *)
   NO_HEADING = -1;

(* Degrees round the circle between two headings, 0..180. Either may be outside
  0..359 (a heading of 360 is north). *)
function AngularDistance(const aFrom, aTo: integer): integer;

(* The rank of one spot: smaller sorts first. aReference is the beam's heading,
  or NO_HEADING when there is none, in which case the rank is the absolute
  heading. A spot with no heading ranks after every spot that has one. *)
function BeamRank(const aHeading, aReference: integer): integer;

(* THE SPOTS' ORDER. aHeadings holds one heading per spot, in the order the spots
  are in now (frequency order). On return aOrder[0..High] holds the POSITIONS in
  aHeadings, best first; equal ranks keep their incoming order. aOrder must be
  the same length as aHeadings. *)
procedure OrderByBeam(const aHeadings: array of integer;
                      const aReference: integer;
                      var aOrder: array of integer);

(* THE FIRST SPOT ABOVE THE CURSOR. aFrequencies is in ascending order. Returns
  the position of the first spot whose frequency is greater than aCursor, or the
  LAST position when none is (the cursor is above every spot), or -1 for an
  empty list. *)
function FirstSpotAbove(const aFrequencies: array of integer;
                        const aCursor: integer): integer;

(* THE LEFTMOST COLUMN that puts aTargetCol in the middle of aVisibleCols,
  clamped to what the grid can scroll to: never below 0, never past the point
  where the last column is at the right edge. A grid that fits entirely has
  nowhere to scroll and gives 0. *)
function CentreLeftCol(const aTargetCol, aVisibleCols,
                       aColCount: integer): integer;

implementation

uses
   Generics.Collections;

(* A RANK IS THE DISTANCE, AND THE DISTANCE NEVER REACHES THIS. A spot with no
  heading ranks beyond the largest real rank (359 absolute, 180 angular). *)
const
   RANK_NO_HEADING = 1000;

function NormalHeading(const aHeading: integer): integer;
begin
   Result := aHeading mod 360;
   if Result < 0 then
      begin
      Inc(Result, 360);
      end;
end;

function AngularDistance(const aFrom, aTo: integer): integer;
begin
   Result := Abs(NormalHeading(aFrom) - NormalHeading(aTo));
   if Result > 180 then
      begin
      Result := 360 - Result;
      end;
end;

function BeamRank(const aHeading, aReference: integer): integer;
begin
   if aHeading < 0 then
      begin
      Result := RANK_NO_HEADING;
      Exit;
      end;
   if aReference < 0 then
      begin
      Result := NormalHeading(aHeading);
      end
   else
      begin
      Result := AngularDistance(aHeading, aReference);
      end;
end;

procedure OrderByBeam(const aHeadings: array of integer;
                      const aReference: integer;
                      var aOrder: array of integer);
const
   POSITION_BITS = 20;
var
   keys: TList<Int64>;
   i: integer;
begin
   (* ONE SORT KEY PER SPOT: the rank in the high bits and the incoming position
     in the low ones, so a plain sort of the keys is a STABLE sort of the spots
     and equal ranks keep frequency order without a comparer. A million
     positions is far beyond the thousand spots the list holds. *)
   keys := TList<Int64>.Create;
   try
      for i := 0 to High(aHeadings) do
         begin
         keys.Add((Int64(BeamRank(aHeadings[i], aReference)) shl POSITION_BITS)
                  or Int64(i));
         end;

      keys.Sort;

      for i := 0 to keys.Count - 1 do
         begin
         aOrder[i] := integer(keys[i] and ((Int64(1) shl POSITION_BITS) - 1));
         end;
   finally
      keys.Free;
   end;
end;

function FirstSpotAbove(const aFrequencies: array of integer;
                        const aCursor: integer): integer;
var
   i: integer;
begin
   Result := -1;
   if Length(aFrequencies) = 0 then
      begin
      Exit;
      end;
   for i := 0 to High(aFrequencies) do
      begin
      if aFrequencies[i] > aCursor then
         begin
         Result := i;
         Exit;
         end;
      end;
   Result := High(aFrequencies);
end;

function CentreLeftCol(const aTargetCol, aVisibleCols,
                       aColCount: integer): integer;
var
   maxLeft: integer;
begin
   maxLeft := aColCount - aVisibleCols;
   if maxLeft < 0 then
      begin
      maxLeft := 0;
      end;

   Result := aTargetCol - (aVisibleCols div 2);
   if Result > maxLeft then
      begin
      Result := maxLeft;
      end;
   if Result < 0 then
      begin
      Result := 0;
      end;
end;

end.

unit uBandMapOrder;

(* THE BAND MAP'S PURE ARITHMETIC (issues 82 and 246; the radio's marks and
  the display-limit ceiling, issue 65, are below CentreLeftCol).

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

(* WHERE THE RADIO IS (issues 65 and 59, NY4I 2026-11-19: "a plus b").

  The band map marks the radio's frequency two ways, both separate from the
  grid's selection -- the selection is a spot the OPERATOR chose and must not
  follow the VFO:

    (a) a spot within BAND MAP GUARD BAND of the radio has its frequency field
        drawn in the VFO marker colour (SpotNearRadio);
    (b) the ONE spot nearest the radio is outlined in that colour, so the map
        answers "which spot am I on" even when nothing is inside the guard
        band (NearestSpotIndex).

  aCursor is the radio's frequency in Hz; 0 or less means no radio, and with
  no radio neither marks anything. *)

(* True when a spot at aSpotFrequency is within aGuardBand Hz of the radio.
  A guard band of 0 is an exact frequency match (the setting's default, and
  what "no guard band" has always meant). False with no radio. *)
function SpotNearRadio(const aSpotFrequency, aCursor,
                       aGuardBand: integer): boolean;

(* THE SPOT NEAREST THE RADIO: the position in aFrequencies of the smallest
  distance to aCursor, the FIRST such position on a tie. aFrequencies may be in
  any order (beam-heading order is not frequency order). -1 for an empty list
  or no radio. *)
function NearestSpotIndex(const aFrequencies: array of integer;
                          const aCursor: integer): integer;

(* BAND MAP DISPLAY LIMIT IS A CEILING (issue 65, NY4I 2026-11-19): the map
  shows whichever is smaller, the setting or what fits in the window
  (aRowsDown x aVisibleCols, whole columns only), so a resize re-centres on the
  radio without editing a setting.

  A window whose size is not known yet (either count below 1 -- the form
  before it is shown) gives the setting. The result is never below
  MIN_DISPLAY_LIMIT and is EVEN: the centring window in
  TDXSpotsList.BuildVisibleSpots spans (limit div 2) below and above the
  radio, so an odd limit shows one fewer spot and a limit of 1 shows none. *)
const
   MIN_DISPLAY_LIMIT = 2;

function EffectiveDisplayLimit(const aSetting, aRowsDown,
                               aVisibleCols: integer): integer;

(* THE TEXT SIZE AND WHAT FOLLOWS FROM IT (the right-click Text size menu).

  BAND MAP SIZE is added to BANDMAP_TEXT_BASE to give the spot text's height in
  pixels. The row height and the column width the operator set (BAND MAP ITEM
  HEIGHT / WIDTH) are what fit the REFERENCE size, BANDMAP_REFERENCE_SIZE (3,
  the setting's default, so 13 pixels): at the reference the two functions below
  return the settings exactly as they were, and only a LARGER text asks for
  more room. Smaller text never takes room away -- the operator who wants
  tighter rows has BAND MAP ITEM HEIGHT for that. *)
const
   BANDMAP_TEXT_BASE      = 10;
   BANDMAP_REFERENCE_SIZE = 3;

(* The spot text's height in pixels for a BAND MAP SIZE. *)
function BandMapTextHeight(const aSize: integer): integer;

(* The row height to use: the operator's BAND MAP ITEM HEIGHT, or one pixel
  more than the text, whichever is larger. 14 at the defaults (size 3, height
  14). *)
function BandMapRowHeight(const aItemHeight, aSize: integer): integer;

(* The column width to use: the operator's BAND MAP ITEM WIDTH, scaled up in
  proportion to the text once it is taller than the reference, never below it.
  135 at the defaults. *)
function BandMapColumnWidth(const aItemWidth, aSize: integer): integer;

(* One step of the Text size menu: aSize + aDelta held inside aMin..aMax. *)
function SteppedBandMapSize(const aSize, aDelta, aMin, aMax: integer): integer;

(* SHOULD THE BAND MAP'S BAND AND MODE BE RE-TAKEN FROM THE ACTIVE RADIO NOW
  (uRadioPolling, once per poll). aFreqDelta is the move since the last poll,
  aRadioFreq the radio's frequency, aCursor the frequency the map last followed,
  aMapModeDiffers whether the map's mode is not the active mode.

  A MODE CHANGE AT THE SAME FREQUENCY MUST COUNT. The gate used to be
  "the frequency moved" for both arms, and a K4 that reports the new
  frequency (still in its old mode) and then the new mode a poll later
  left the map on the old mode for good: the window said 20SSB, the map
  said Digital, and every 20 m phone spot failed the mode filter
  (NY4I, 2026-11-22, log 12:38:42 band 7->3 mode 1->1, then 12:38:43 mode
  1->2 at the same 14230000). No frequency, no follow. *)
function BandMapFollowsRadio(const aFreqDelta, aRadioFreq, aCursor: integer;
                             const aMapModeDiffers: boolean): boolean;

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

function SpotNearRadio(const aSpotFrequency, aCursor,
                       aGuardBand: integer): boolean;
begin
   if aCursor <= 0 then
      begin
      Result := False;
      Exit;
      end;
   Result := Abs(aSpotFrequency - aCursor) <= aGuardBand;
end;

function NearestSpotIndex(const aFrequencies: array of integer;
                          const aCursor: integer): integer;
var
   i: integer;
   distance: integer;
   best: integer;
begin
   Result := -1;
   if (aCursor <= 0) or (Length(aFrequencies) = 0) then
      begin
      Exit;
      end;
   best := 0;
   for i := 0 to High(aFrequencies) do
      begin
      distance := Abs(aFrequencies[i] - aCursor);
      (* Strictly smaller, so a tie keeps the first position. *)
      if (Result < 0) or (distance < best) then
         begin
         best := distance;
         Result := i;
         end;
      end;
end;

function EffectiveDisplayLimit(const aSetting, aRowsDown,
                               aVisibleCols: integer): integer;
var
   fits: integer;
begin
   Result := aSetting;
   if (aRowsDown >= 1) and (aVisibleCols >= 1) then
      begin
      fits := aRowsDown * aVisibleCols;
      if fits < Result then
         begin
         Result := fits;
         end;
      end;
   if Odd(Result) then
      begin
      Dec(Result);
      end;
   if Result < MIN_DISPLAY_LIMIT then
      begin
      Result := MIN_DISPLAY_LIMIT;
      end;
end;

function BandMapTextHeight(const aSize: integer): integer;
begin
   Result := BANDMAP_TEXT_BASE + aSize;
end;

function BandMapRowHeight(const aItemHeight, aSize: integer): integer;
begin
   Result := aItemHeight;
   if BandMapTextHeight(aSize) + 1 > Result then
      begin
      Result := BandMapTextHeight(aSize) + 1;
      end;
end;

function BandMapColumnWidth(const aItemWidth, aSize: integer): integer;
var
   scaled: integer;
begin
   Result := aItemWidth;
   scaled := (aItemWidth * BandMapTextHeight(aSize)) div
             BandMapTextHeight(BANDMAP_REFERENCE_SIZE);
   if scaled > Result then
      begin
      Result := scaled;
      end;
end;

function SteppedBandMapSize(const aSize, aDelta, aMin, aMax: integer): integer;
begin
   Result := aSize + aDelta;
   if Result > aMax then
      begin
      Result := aMax;
      end;
   if Result < aMin then
      begin
      Result := aMin;
      end;
end;

function BandMapFollowsRadio(const aFreqDelta, aRadioFreq, aCursor: integer;
                             const aMapModeDiffers: boolean): boolean;
begin
   Result := (aRadioFreq <> 0) and
             (((aFreqDelta > 0) and (aRadioFreq <> aCursor)) or
              aMapModeDiffers);
end;

end.

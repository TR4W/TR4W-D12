unit uPanadapterView;
{$I tr4w.inc}

{
  THE PANADAPTER'S VIEW SEAM -- one procedure variable and the record it hands
  back.

  Same shape and the same reasoning as uBandMapView, but pointing the other way.
  The band map's seam carries a REQUEST ("repaint") from the model to whatever
  is displaying it; this one carries a QUESTION ("what is spotted between these
  two frequencies?") from the display to whatever owns the spots.

  WHY A SEAM AND NOT `uses uSpots`.  The panadapter window currently depends on
  two units: uSpectrumTypes and uFactoryRadioBase.  It has no idea what a
  contest, a multiplier or a dupe is, and referencing the spot store would give
  it all of that -- the legacy machinery the LCL migration is unpicking, pulled
  into the newest window in the program.  NY4I chose this shape over a direct
  dependency on 2026-08-25.

  WHAT CROSSES IT IS DATA, NEVER A CONTROL, and never a live list.  The provider
  returns a COPY covering the range asked for, because the display runs off a
  timer and the spot list is mutated by the cluster reader; handing back a
  reference into the live list would be a race with a repaint.

  UNASSIGNED IS A LEGAL STATE -- and the usual one.  There is no spot provider
  until something installs one, and a panadapter with no DX cluster running is
  perfectly normal.  The window simply draws no callsigns.
}

interface

type
   { One spotted station, reduced to what a spectrum display can draw.

     Deliberately NOT TR4W's spot record: this seam exists so the window need
     not know that type.  Frequency is in Hz to match TSpectrumFrame -- the
     spot store works in tenths of a kHz, and converting once at the provider
     is better than teaching the display a second unit. }
   TSpectrumSpot = record
      Callsign: string;
      FreqHz: Int64;
      IsMultiplier: Boolean;    // worth working -- drawn to stand out
      IsDupe: Boolean;          // already worked -- drawn dimmed
   end;

   TSpectrumSpots = array of TSpectrumSpot;

   { Every spot whose frequency falls in [AStartHz, AEndHz].  Returning an empty
     array is normal and is not an error. }
   TSpectrumSpotsProc = function(const AStartHz, AEndHz: Int64): TSpectrumSpots;

var
   { Assigned by whatever owns the spot list; nil until then. }
   PanadapterSpots: TSpectrumSpotsProc = nil;

{ The one test every caller should use, so "is anyone providing spots" is
  spelled the same way everywhere. }
function PanadapterSpotsAvailable: boolean;

implementation

function PanadapterSpotsAvailable: boolean;
begin
   Result := Assigned(PanadapterSpots);
end;

end.

unit uBandMapView;
{$I tr4w.inc}

{
  THE BAND MAP'S VIEW SEAM -- three procedure variables and nothing else.

  WHY A UNIT AND NOT A USES CLAUSE.  Four units need to talk to whatever is
  currently displaying the band map: uSpots (the model, which resolves the
  cursor row), uBandmap (the spot-info status bar and the focus handling),
  LOGWIND (DisplayBandMap, the program's one "repaint the band map" call) and
  MainUnit (the refresh timer).  Three of those are in src\trdos or are used BY
  the form, so a direct reference to the form unit is a cycle in at least one
  direction.  This is the same shape as TFunctionKeyProc in uFunctionKeysForm
  and PossibleCallDrawProc in uMainForm -- the established answer here.

  WHY IT IS NOT "just call the form".  The model must not know a control
  exists.  TDXSpotsList.Display -- the model reaching into a list box -- is what
  this replaces, and reintroducing the same coupling through a different unit
  name would be no better.  What crosses this seam is a REQUEST ("repaint") and
  a QUESTION ("which spot is selected"), never a control.

  UNASSIGNED IS A LEGAL STATE and is what the program does before the band map
  window is opened, and after it is closed.  Every caller must check.  It is
  also what keeps the old Win32 path working while both exist: nil means "no
  LCL form", and the caller falls back.
}

interface

type
   { Ask whoever owns the band map to repaint.  Called from the coalescing
     timer, never per spot. }
   TBandMapRefreshProc = procedure;

   { The FList index of the selected spot, or -1.  An INDEX and not a spot,
     because every caller already goes on to call SpotsList.Get with it. }
   TBandMapSelectedProc = function: integer;

   { Put the cursor on the first spot.  Asked for by BMFirst, in src\trdos,
     which cannot see the form unit -- MainUnit can and calls it directly, so
     only this one needs a hook.  It used to be a message posted to a list box
     handle. }
   TBandMapActionProc = procedure;

var
   { Assigned when the band map form opens, cleared when it closes. }
   BandMapRefresh:    TBandMapRefreshProc  = nil;
   BandMapSelected:   TBandMapSelectedProc = nil;
   BandMapSelectTop:  TBandMapActionProc   = nil;

{ True when an LCL band map form is on screen and owns the display.  The one
  test every fallback path should use, so "is there a form" is spelled the same
  way everywhere. }
function BandMapFormActive: boolean;

implementation

function BandMapFormActive: boolean;
begin
   Result := Assigned(BandMapRefresh);
end;

end.

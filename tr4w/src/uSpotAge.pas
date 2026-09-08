unit uSpotAge;

{ HOW OLD A BAND MAP SPOT IS.

  A LEAF, deliberately.  This lived in uSpots, which pulls in MainUnit and the
  whole spots model and therefore cannot be linked by the unit tests -- and an
  age calculation is exactly the kind of thing that should be pinned rather
  than eyeballed on a bench.  Nothing here knows what a spot is; it takes two
  timestamps and returns seconds.

  WHY NOT SecondSpan ALONE.  SecondSpan returns the ABSOLUTE difference, so a
  stamp in the future reads as very old.  That is not hypothetical: the PC
  clock stepping backwards -- an NTP correction mid-contest -- would make every
  spot in the list look expired at once and empty the map.  The order is
  established first and SecondSpan asked only for the magnitude. }

{$I tr4w.inc}

interface

uses
   SysUtils, DateUtils;

{ Now, in UTC.

  LocalTimeToUniversal(Now) -- see the body. This used to call
  Windows.GetSystemTime and rebuild the value from the SYSTEMTIME fields,
  deliberately NOT through SystemTimeToDateTime, because Windows.SYSTEMTIME and
  SysUtils.TSystemTime are separate declarations that merely happen to share a
  layout. Going through TDateTime sidesteps that trap entirely. }
function UTCNow: TDateTime;

{ Whole seconds between the two, never negative.  aStamp at or after aNow is
  age zero. }
function AgeSeconds(const aStamp, aNow: TDateTime): integer;

implementation

(* THE SAME INSTANT, WITHOUT ASKING WINDOWS FOR IT.

  Was Windows.GetSystemTime into a SYSTEMTIME and then EncodeDate + EncodeTime
  to put it back together. LocalTimeToUniversal(Now) is the RTL's own answer on
  every platform: it takes the local clock and applies the OS's UTC offset,
  which is what GetSystemTime returns directly.

  RESOLUTION IS UNCHANGED -- Now carries milliseconds and so did the
  reassembly. The one difference worth knowing is at a DST boundary, where the
  offset is read at the moment of the call rather than baked into the
  timestamp; a spot's age is measured in minutes against a decay time in
  minutes, so a one-hour ambiguity in the same second the clock changes is not
  something this can observe. *)
function UTCNow: TDateTime;
begin
   Result := LocalTimeToUniversal(Now);
end;

function AgeSeconds(const aStamp, aNow: TDateTime): integer;
begin
   if aStamp >= aNow then
      begin
      Result := 0;
      Exit;
      end;
   Result := Round(SecondSpan(aNow, aStamp));
end;

end.

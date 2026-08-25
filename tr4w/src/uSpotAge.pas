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

  Built from GetSystemTime's fields rather than through SystemTimeToDateTime:
  Windows.SYSTEMTIME and SysUtils.TSystemTime are separate declarations that
  merely happen to share a layout. }
function UTCNow: TDateTime;

{ Whole seconds between the two, never negative.  aStamp at or after aNow is
  age zero. }
function AgeSeconds(const aStamp, aNow: TDateTime): integer;

implementation

uses
   Windows;

function UTCNow: TDateTime;
var
   st: SYSTEMTIME;
begin
   Windows.GetSystemTime(st);
   Result := EncodeDate(st.wYear, st.wMonth, st.wDay) +
             EncodeTime(st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
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

unit uLogTime;

(* THE ONE PLACE A LOG TIMESTAMP IS MADE.

  tr4w.log, the early-start trace, the crash reports and the Telnet trace all
  stamp their lines with these functions and with nothing else, so no two logs
  can disagree about what time it is.

  UTC, WITH A Z, IN 24-HOUR TIME (NY4I, 2026-11-23). Logs arrive from all over the
  world, and a local time in a log says nothing without the writer's zone and
  its daylight-saving rule. The trailing Z is the marker: a line written before
  this change carries no Z and was local time, so the two can never be taken
  for one another.

      2026-11-23 02:58:27.466Z

  ISO 8601 order (year first), so a sorted listing is a time-ordered listing.
  `hh` is 24-hour in FormatDateTime unless am/pm is asked for, and it is not.

  The clock is uSpotAge.UTCNow, not a second copy of LocalTimeToUniversal: one
  UTC implementation in the program, and this unit only names the log's use of
  it and its format.

  A LEAF. It uses nothing of the program's but uSpotAge (itself RTL only), so
  Log4D and the crash reporter -- which link everywhere, including the unit
  tests and the server -- can use it.

  Lint-LogTime fails the build if a log-writing unit asks the RTL for the
  time itself. *)

{$I tr4w.inc}

interface

const
   (* The layout, without the Z. A name, so a test pins it and a reader can
     see what a log line looks like. *)
   LOG_TIME_FORMAT = 'yyyy-mm-dd hh:nn:ss.zzz';

(* Now, in UTC. *)
function LogUtcNow: TDateTime;

(* aUtc (a UTC TDateTime) as '2026-11-23 02:58:27.466Z'. *)
function LogTimeText(const aUtc: TDateTime): string;

(* The current time as a log stamp. *)
function LogNowText: string;

implementation

uses
   SysUtils, uSpotAge;

function LogUtcNow: TDateTime;
begin
   Result := UTCNow;
end;

function LogTimeText(const aUtc: TDateTime): string;
begin
   Result := FormatDateTime(LOG_TIME_FORMAT, aUtc) + 'Z';
end;

function LogNowText: string;
begin
   Result := LogTimeText(LogUtcNow);
end;

end.

unit uContestTimeLeft;

(* HOW MUCH OF A CONTEST IS LEFT -- issue 243.

  A LEAF, as uSpotAge is: three UTC instants in, a phase and a whole number of
  minutes out. Nothing here knows what a contest is, where its times come from
  or how they are shown, so every boundary is pinned by uTestContestTimeLeft
  rather than judged on a bench.

  WHERE THE TIMES WILL COME FROM IS NOT BUILT. No contest class states when it
  runs yet (design Q99, CONTEST_FACTORY_OPEN_QUESTIONS.md: accepted, not
  built), and the contest row's start_time / end_time columns are written by
  nothing. So the caller has no window to give this today, and an unknown
  window is a phase of its own (cpNoWindow) that a display shows as nothing.

  ONE WINDOW, START TO END. A contest with more than one operating period in
  a weekend (the Georgia QP's Saturday and Sunday sessions) is not expressible
  here; that is Q99's shape to decide, not this unit's.

  UTC ONLY. The sponsor's UTC is the contest's definition; the local clock
  zone never enters. The caller passes uSpotAge.UTCNow. *)

{$I tr4w.inc}

interface

type
   TContestPhase = (
      cpNoWindow,     (* no start, no end, or an end not after the start *)
      cpNotStarted,   (* now is before the start *)
      cpRunning,      (* start <= now < end *)
      cpEnded);       (* now is at or after the end *)

(* Which side of the window aNowUTC is on. A zero (or negative) start or end
  is "not known", as an unset TDateTime is. *)
function ContestPhaseAt(const aNowUTC, aStartUTC, aEndUTC: TDateTime): TContestPhase;

(* Whole minutes to the next boundary: to the END while running, to the START
  before it, 0 otherwise. ROUNDED UP, so a running contest never reads 0:00
  while there is still time to work a station; it reads 0:00 at the end. *)
function ContestMinutesLeft(const aNowUTC, aStartUTC, aEndUTC: TDateTime): integer;

(* aMinutes as hours:minutes, 'H:MM'. The hours do NOT wrap at 24: a 48-hour
  contest with 30 h 5 min left reads '30:05'. Negative reads '0:00'. Digits
  and a colon only, so nothing here needs translating. *)
function FormatHoursMinutes(const aMinutes: integer): string;

implementation

uses
   SysUtils;

function WindowIsKnown(const aStartUTC, aEndUTC: TDateTime): boolean;
begin
   Result := (aStartUTC > 0) and (aEndUTC > aStartUTC);
end;

function ContestPhaseAt(const aNowUTC, aStartUTC, aEndUTC: TDateTime): TContestPhase;
begin
   if not WindowIsKnown(aStartUTC, aEndUTC) then
      begin
      Result := cpNoWindow;
      end
   else if aNowUTC < aStartUTC then
      begin
      Result := cpNotStarted;
      end
   else if aNowUTC < aEndUTC then
      begin
      Result := cpRunning;
      end
   else
      begin
      Result := cpEnded;
      end;
end;

(* Whole seconds from aFrom to aTo, rounded to the nearest second first so a
  TDateTime's floating-point residue (a few microseconds either way) cannot
  turn an exact minute into one more. *)
function SecondsUntil(const aFrom, aTo: TDateTime): Int64;
begin
   Result := Round((aTo - aFrom) * SecsPerDay);
end;

function CeilingMinutes(const aSeconds: Int64): integer;
begin
   if aSeconds <= 0 then
      begin
      Result := 0;
      end
   else
      begin
      Result := integer((aSeconds + 59) div 60);
      end;
end;

function ContestMinutesLeft(const aNowUTC, aStartUTC, aEndUTC: TDateTime): integer;
begin
   case ContestPhaseAt(aNowUTC, aStartUTC, aEndUTC) of
      cpNotStarted:
         begin
         Result := CeilingMinutes(SecondsUntil(aNowUTC, aStartUTC));
         end;
      cpRunning:
         begin
         (* At least one: under half a second left rounds to 0 seconds, and a
           running contest must not read 0:00. *)
         Result := CeilingMinutes(SecondsUntil(aNowUTC, aEndUTC));
         if Result < 1 then
            begin
            Result := 1;
            end;
         end;
   else
      begin
      Result := 0;
      end;
   end;
end;

function FormatHoursMinutes(const aMinutes: integer): string;
var
   minutes: integer;
begin
   minutes := aMinutes;
   if minutes < 0 then
      begin
      minutes := 0;
      end;

   (* UnicodeFormat, not Format: FPC 3.2.2's SysUtils.Format and IntToStr are
     AnsiString, and this unit's strings are not. *)
   Result := UnicodeFormat('%d:%.2d', [minutes div 60, minutes mod 60]);
end;

end.

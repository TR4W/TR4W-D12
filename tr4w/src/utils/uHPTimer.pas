(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
*)
unit uHPTimer;
{$I ..\tr4w.inc}

(* THE HIGH-RESOLUTION MONOTONIC CLOCK -- THE MEASUREMENT HALF.

  Design: docs/PLATFORM_CLOCK_ABSTRACTION.md, part 2. This unit is the
  instrument that answers "was that dit actually 40 ms?", which nothing in
  this program could answer on any platform before it existed.

  THIS IS A STOPWATCH, NOT A DELAY. The delay half (HPSleepMicroseconds, what
  LOGK1EA.tCWSleep becomes) is a separate decision and is NOT here. Off
  Windows, CW element timing is still a plain Sleep placeholder and WILL NOT
  KEY A CONTEST -- nothing in this unit changes that.

  WHY OUR OWN UNIT AND NOT AN FPC CLASS: there is none to prefer. FPC 3.2.2
  gives GetTickCount64 (milliseconds -- a dit at 40 WPM is 30 ms, so a 1 ms
  floor is a 3% error before anything else goes wrong), and on Darwin it has
  no monotonic clock at all: rtl/unix/sysutils.pp defines HAVECLOCKGETTIME
  only for Linux and FreeBSD, so Darwin's GetTickCount64 falls back to
  gettimeofday, which is wall time and can step.

  PER PLATFORM -- the tick source, and what the RTL provides for it:

    WINDOWS  QueryPerformanceCounter / QueryPerformanceFrequency, from the
             RTL's Windows unit. Ticks are QPC units at whatever rate QPF
             reports (10 MHz on current Windows; do not assume it).
    LINUX    clock_gettime(CLOCK_MONOTONIC_RAW), from the RTL's Linux unit
             (linux.pp declares both the call and the constant). Ticks are
             nanoseconds. RAW rather than MONOTONIC: MONOTONIC is slewed by
             NTP, so its rate is deliberately wrong while it corrects.
    DARWIN   mach_absolute_time + mach_timebase_info, bound HERE because FPC
             declares neither (see the binding below for the justification).
             Ticks are the hardware counter's; the timebase converts them.

  Any other target is a compile error, not a quiet fallback to Sleep-grade
  time. A silent downgrade is exactly the defect class this program keeps
  finding on the bench.

  THE CONVERSION IS A PURE FUNCTION (HPScaleTicks) so it can be pinned with
  synthetic ratios and tick counts independently of whatever clock the test
  host happens to have -- including Apple Silicon's 125/3 on a Windows box. *)

interface

uses
   SysUtils;

type
   (* Raised when the platform clock cannot be read or its timebase is
     unusable, and when the pure conversion is given inputs it cannot compute
     exactly. Never swallowed: a wrong interval is worse than no interval. *)
   EHPTimerError = class(Exception);

(* MEASUREMENT ---------------------------------------------------------------

  HPTicks            the platform's monotonic counter, in its own units. Only
                     DIFFERENCES are meaningful; the origin is unspecified.
  HPTicksPerSecond   the counter's rate. Exact on Windows and Linux, and on
                     Darwin whenever denom * 10^9 is divisible by numer (true
                     for both 1/1 and 125/3); otherwise rounded down. The
                     microsecond conversions below never go through this
                     figure -- they use the exact reduced ratio.
  HPTicksToMicroseconds
                     a tick COUNT (normally a difference) to microseconds,
                     truncated toward zero.
  HPElapsedMicroseconds
                     microseconds since aFrom, a value previously returned by
                     HPTicks. *)
function HPTicks: Int64;
function HPTicksPerSecond: Int64;
function HPTicksToMicroseconds(const aTicks: Int64): Int64;
function HPElapsedMicroseconds(const aFrom: Int64): Int64;

(* The timebase as the platform reported it, for logs and bench reports --
  e.g. 'mach_timebase_info 125/3 (24000000 ticks/s)'. *)
function HPTimebaseDescription: string;

(* PURE ARITHMETIC -- public so the tests can drive it with synthetic input.

  HPReduceRatio      divides aNumer and aDenom by their greatest common
                     divisor. Both must be positive.

  HPScaleTicks       aTicks * aNumer / aDenom, truncated toward zero, WITHOUT
                     forming aTicks * aNumer. It splits aTicks into
                     whole * aDenom + remainder, so the only products are
                       whole * aNumer      -- no larger than the RESULT
                       remainder * aNumer  -- smaller than aNumer * aDenom
                     and it raises EHPTimerError rather than overflow in
                     either. See the overflow note in the implementation. *)
procedure HPReduceRatio(var aNumer, aDenom: Int64);
function HPScaleTicks(const aTicks, aNumer, aDenom: Int64): Int64;

implementation

{$IFDEF WINDOWS}
uses
   Windows;
{$ENDIF}
{$IFDEF LINUX}
uses
   BaseUnix, Linux;
{$ENDIF}

{$IF not (defined(WINDOWS) or defined(LINUX) or defined(DARWIN))}
   {$ERROR uHPTimer has no monotonic high-resolution clock for this target. Add an arm; do not fall back to Sleep-grade time -- see docs/PLATFORM_CLOCK_ABSTRACTION.md part 2.}
{$IFEND}

const
   MICROSECONDS_PER_SECOND = Int64(1000000);
   NANOSECONDS_PER_SECOND  = Int64(1000000000);

{$IFDEF DARWIN}
(* A DIRECT libSystem BINDING, AND WHY IT IS JUSTIFIED.

  CLAUDE.md requires a reason beside every new external declaration. Here it
  is: FPC 3.2.2 declares neither mach_absolute_time nor mach_timebase_info
  anywhere in its RTL or packages (checked: the only mentions are two
  comments in packages/univint), and it does not declare clock_gettime for
  Darwin either -- rtl/unix/sysutils.pp limits HAVECLOCKGETTIME to Linux and
  FreeBSD. So there is no FPC facility to prefer, and mach_absolute_time is
  Apple's supported way to read the hardware counter (CNTVCT_EL0 on Apple
  Silicon, which has no RDTSC).

  'c' is the name FPC's own RTL binds libc by on Darwin (rtl/bsd/sysos.inc,
  rtl/unix/initc.pp); on macOS that is libSystem, which exports both.

  The RECORD is the one shape the house rule exempts: a layout defined by the
  OS, at the boundary where it is passed -- struct mach_timebase_info is two
  uint32_t, numer then denom. *)
type
   TMachTimebaseInfo = record
      numer: UInt32;
      denom: UInt32;
   end;

function mach_absolute_time: UInt64; cdecl; external 'c' name 'mach_absolute_time';
function mach_timebase_info(var aInfo: TMachTimebaseInfo): LongInt; cdecl; external 'c' name 'mach_timebase_info';
{$ENDIF}

var
   (* Set once, by the initialization section, before any thread can run.
     Read-only afterwards, so no lock is needed. *)
   gTicksPerSecond : Int64  = 0;
   gUsNumer        : Int64  = 0;   // microseconds = ticks * gUsNumer / gUsDenom,
   gUsDenom        : Int64  = 0;   // reduced by their GCD
   gDescription    : string = '';
   gInitError      : string = '';  // non-empty = the timebase is unusable

(* THE OVERFLOW NOTE.

  The obvious conversion, ticks * 1000000 div ticksPerSecond, forms a product
  that overflows Int64 (9.22e18) once ticks passes 9.22e12:

    counter rate          naive product overflows after
    10 MHz  (QPC)         ~10.7 days
    24 MHz  (Apple M-)    ~4.4 days
    1 GHz   (Linux ns)    ~2.6 HOURS

  A station computer up for a contest weekend passes the first two, and every
  Linux box passes the third before lunch. That matters the moment anyone
  converts a raw HPTicks value rather than a short difference.

  HPScaleTicks never forms that product. With the ratio reduced by its GCD:

    * remainder * aNumer < aDenom * aNumer, which is checked up front. For the
      real clocks it is tiny: 1 x 10 (QPC 10 MHz), 1 x 24 (Apple Silicon),
      1 x 1000 (Linux), 200000 x 715909 (the old 3.579545 MHz ACPI PM timer,
      whose ratio does not reduce far) -- about 1.4e11 at worst.
    * whole * aNumer is at most the result itself, so it fits whenever the
      answer does: an interval under ~292,000 YEARS of microseconds. That is
      checked too, rather than assumed, so the function is total -- an exact
      answer or an EHPTimerError, never a wrapped number. *)

procedure HPReduceRatio(var aNumer, aDenom: Int64);
var
   a, b, t: Int64;
begin
   if (aNumer <= 0) or (aDenom <= 0) then
      begin
      raise EHPTimerError.CreateFmt('HPReduceRatio: both terms must be positive (got %d/%d)',
                                    [aNumer, aDenom]);
      end;

   (* Euclid. Both positive, so the loop terminates with a > 0. *)
   a := aNumer;
   b := aDenom;
   while b <> 0 do
      begin
      t := a mod b;
      a := b;
      b := t;
      end;

   aNumer := aNumer div a;
   aDenom := aDenom div a;
end;

function HPScaleTicks(const aTicks, aNumer, aDenom: Int64): Int64;
var
   whole, remainder, limit: Int64;
begin
   if (aNumer <= 0) or (aDenom <= 0) then
      begin
      raise EHPTimerError.CreateFmt('HPScaleTicks: ratio terms must be positive (got %d/%d)',
                                    [aNumer, aDenom]);
      end;

   (* remainder < aDenom, so remainder * aNumer < aDenom * aNumer. *)
   if aNumer > High(Int64) div aDenom then
      begin
      raise EHPTimerError.CreateFmt('HPScaleTicks: ratio %d/%d is too large to scale exactly; reduce it first',
                                    [aNumer, aDenom]);
      end;

   (* Pascal div and mod truncate toward zero and share a sign, so a negative
     tick count scales symmetrically: -x gives exactly -(result for x). *)
   whole     := aTicks div aDenom;
   remainder := aTicks mod aDenom;

   (* |remainder * aNumer div aDenom| < aNumer, so bounding |whole * aNumer|
     by High(Int64) - aNumer bounds the sum as well. Compared on both sides
     rather than through Abs, which cannot represent -Low(Int64). *)
   limit := (High(Int64) - aNumer) div aNumer;
   if (whole > limit) or (whole < -limit) then
      begin
      raise EHPTimerError.CreateFmt('HPScaleTicks: %d ticks at %d/%d does not fit in Int64',
                                    [aTicks, aNumer, aDenom]);
      end;

   Result := whole * aNumer + (remainder * aNumer) div aDenom;
end;

procedure RequireTimebase;
begin
   if gInitError <> '' then
      begin
      (* CreateFmt('%s'), not Create(gInitError): FPC 3.2.2's Exception takes
        an AnsiString and this unit's string is UnicodeString, so Create would
        be an implicit NARROWING conversion -- counted against Build-App's
        ceiling once the app links this unit. Passed as a Format argument the
        conversion is Format's, at run time, and the text is ASCII anyway. *)
      raise EHPTimerError.CreateFmt('%s', [gInitError]);
      end;
end;

{$IFDEF WINDOWS}
procedure InitTimebase;
var
   freq: Int64;
begin
   freq := 0;
   if (not QueryPerformanceFrequency(freq)) or (freq <= 0) then
      begin
      gInitError := Format('QueryPerformanceFrequency failed or reported %d; no high-resolution clock',
                           [freq]);
      Exit;
      end;

   gTicksPerSecond := freq;
   gUsNumer        := MICROSECONDS_PER_SECOND;
   gUsDenom        := freq;
   HPReduceRatio(gUsNumer, gUsDenom);
   gDescription    := Format('QueryPerformanceFrequency %d ticks/s', [freq]);
end;

function HPTicks: Int64;
begin
   Result := 0;
   (* Documented never to fail on XP and later. Checked anyway: a zero here
     would read as "no time passed", which is a wrong answer, not an error. *)
   if not QueryPerformanceCounter(Result) then
      begin
      raise EHPTimerError.Create('QueryPerformanceCounter failed');
      end;
end;
{$ENDIF}

{$IFDEF LINUX}
procedure InitTimebase;
var
   ts: timespec;
begin
   (* Probe once. CLOCK_MONOTONIC_RAW exists from Linux 2.6.28, so a failure
     here is a very old or very strange kernel -- reported, not papered over
     with CLOCK_MONOTONIC, whose rate NTP deliberately bends. *)
   if clock_gettime(CLOCK_MONOTONIC_RAW, @ts) <> 0 then
      begin
      gInitError := Format('clock_gettime(CLOCK_MONOTONIC_RAW) failed, errno %d',
                           [fpgeterrno]);
      Exit;
      end;

   gTicksPerSecond := NANOSECONDS_PER_SECOND;
   gUsNumer        := MICROSECONDS_PER_SECOND;
   gUsDenom        := NANOSECONDS_PER_SECOND;
   HPReduceRatio(gUsNumer, gUsDenom);
   gDescription    := 'clock_gettime(CLOCK_MONOTONIC_RAW) 1000000000 ticks/s';
end;

function HPTicks: Int64;
var
   ts: timespec;
begin
   (* The pointer is the RTL's signature for clock_gettime, not a choice. *)
   if clock_gettime(CLOCK_MONOTONIC_RAW, @ts) <> 0 then
      begin
      raise EHPTimerError.CreateFmt('clock_gettime(CLOCK_MONOTONIC_RAW) failed, errno %d',
                                    [fpgeterrno]);
      end;

   (* Nanoseconds. tv_sec * 10^9 fits Int64 for 292 years of uptime. *)
   Result := Int64(ts.tv_sec) * NANOSECONDS_PER_SECOND + Int64(ts.tv_nsec);
end;
{$ENDIF}

{$IFDEF DARWIN}
procedure InitTimebase;
var
   info: TMachTimebaseInfo;
begin
   info.numer := 0;
   info.denom := 0;
   if (mach_timebase_info(info) <> 0) or (info.numer = 0) or (info.denom = 0) then
      begin
      gInitError := Format('mach_timebase_info failed or reported %d/%d',
                           [Int64(info.numer), Int64(info.denom)]);
      Exit;
      end;

   (* ns = ticks * numer / denom, so us = ticks * numer / (denom * 1000).
     NEVER HARDCODED: Intel Macs report 1/1, Apple Silicon a 24 MHz counter
     as 125/3. Reading it is the whole reason the call exists. *)
   gUsNumer        := Int64(info.numer);
   gUsDenom        := Int64(info.denom) * 1000;
   HPReduceRatio(gUsNumer, gUsDenom);
   gTicksPerSecond := (Int64(info.denom) * NANOSECONDS_PER_SECOND) div Int64(info.numer);
   gDescription    := Format('mach_timebase_info %d/%d (%d ticks/s)',
                             [Int64(info.numer), Int64(info.denom), gTicksPerSecond]);
end;

function HPTicks: Int64;
begin
   (* Cannot fail. A 24 MHz counter reaches High(Int64) after ~12,000 years,
     so the cast to a signed tick is safe. *)
   Result := Int64(mach_absolute_time);
end;
{$ENDIF}

function HPTicksPerSecond: Int64;
begin
   RequireTimebase;
   Result := gTicksPerSecond;
end;

function HPTicksToMicroseconds(const aTicks: Int64): Int64;
begin
   RequireTimebase;
   Result := HPScaleTicks(aTicks, gUsNumer, gUsDenom);
end;

function HPElapsedMicroseconds(const aFrom: Int64): Int64;
begin
   Result := HPTicksToMicroseconds(HPTicks - aFrom);
end;

function HPTimebaseDescription: string;
begin
   if gInitError <> '' then
      begin
      Result := 'UNAVAILABLE: ' + gInitError;
      end
   else
      begin
      Result := gDescription;
      end;
end;

initialization
   (* Record a failure rather than raise it: an exception here would stop the
     whole program starting, and a logger with no precise clock can still log.
     Every conversion raises the recorded error when it is asked for time. *)
   try
      InitTimebase;
   except
      on E: Exception do
         begin
         gInitError := 'uHPTimer initialisation failed: ' + E.Message;
         end;
   end;

end.

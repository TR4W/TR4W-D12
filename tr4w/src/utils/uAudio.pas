{
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
}
unit uAudio;
{$I ..\tr4w.inc}

(* ALL OF TR4W'S SOUND, IN ONE PLACE.

  NY4I, 2026-09-08: "I guess as native as we can and fate for Mac. Or write a
  unit to handle it all and we can test it independently."

  THIS IS THE SECOND OF THOSE, AND IT MAKES THE FIRST POSSIBLE. Everything
  platform-specific about playing a sound lives behind these three routines,
  so a better back end on any one platform is a change HERE and nowhere else
  -- the same argument as `HAMLIB_LIB` being one constant rather than 36.

  WHAT TR4W ACTUALLY NEEDS, and it is only two things:

    A .WAV FILE, PLAYED WHOLE   the voice keyer (logdvp). Half a second of
                                tolerance; nothing depends on when it starts.
    A SHORT ALERT TONE          dupe, new multiplier, prompt (tDoABeep,
                                QuickBeep). Frequency and duration in the tens
                                to hundreds of milliseconds.

  WHAT IT NO LONGER NEEDS, and this is why the unit can be this small: THE CW
  SIDETONE IS GONE (NY4I, 2026-09-08 -- "the sidetone comes from the radio").
  That was the hard one: a tone that has to start and stop with a CW element,
  which is a synthesiser on its own thread. Without it, nothing here is
  timing-critical.

  THE BACK ENDS, most native first:

    Windows   winmm, which is already linked and needs no new binding.
              sndPlaySoundA for the file; Windows.Beep for the tone -- and
              Windows.Beep is the RIGHT call here even though it was wrong for
              the sidetone. It BLOCKS for the duration, which is exactly what
              SpeakerBeep already did (ntBeep then Sleep), and unlike
              \Device\Beep it synthesises through the sound card rather than
              needing a PC speaker and a driver most machines have disabled.
    Unix      a helper process -- aplay / paplay / afplay -- through
              uPlatformProcess.RunProgram. NOT the most native answer, and
              said so plainly: ALSA or PulseAudio bindings would be, and they
              would be a NEW LIBRARY BINDING, which CLAUDE.md says needs a
              reason and NY4I deferred to the cross-platform step. A helper
              process needs no binding, no build change and no extra
              dependency on any build machine, and it is replaceable from
              inside this unit when someone wants to pay for the real thing.
    macOS     afplay for files; NO TONE. "Fate for Mac" (NY4I) -- macOS ships
              no command-line tone generator, so BeepAlert reports False there
              rather than pretending. The alert is a courtesy, and the log
              says what happened.

  TESTABLE WITHOUT MAKING A SOUND, which is the point of the split below:
  every DECISION -- is the file there, which player would be chosen, is the
  request even sane -- is in plain functions that return values.
  test/unit/uTestAudio.pas exercises those. Only PlayFile and BeepAlert
  actually touch a device, and they are thin. *)

interface

type
   (* Which helper a Unix back end would use. Exposed so a test can assert the
     CHOICE without a sound card, and so a log line can name it. *)
   TUnixPlayer = (upNone, upAplay, upPaplay, upAfplay);

(* Play a .WAV file. Returns False if it could not be started, and the reason
  is logged -- never raises, because every caller is on a keying or UI path
  where an exception would be worse than silence. *)
function PlayFile(const aPath: string): boolean;

(* A short alert tone. Frequency in Hz, duration in milliseconds. BLOCKS for
  roughly the duration on Windows, which is what the callers already assumed.
  False where no tone generator exists (macOS), logged once. *)
function BeepAlert(const aFrequencyHz, aDurationMs: Cardinal): boolean;

(* Stop anything currently playing. Safe to call when nothing is. *)
procedure StopSound;

(* ---- the decisions, separated so they can be tested without a device ---- *)

(* Would this request be attempted at all? False for an empty path, or a file
  that is not there. Callers use PlayFile; this is what PlayFile asks first,
  and what a test can ask directly. *)
function CanPlayFile(const aPath: string): boolean;

(* Which helper this platform would use for a file, given which of them exist.
  aProbe answers "is this executable available" so a test can supply its own
  answer instead of depending on the machine. *)
type
   TExecutableProbe = function(const aName: string): boolean;

function ChooseUnixPlayer(const aProbe: TExecutableProbe): TUnixPlayer;

(* The name a TUnixPlayer runs, or '' for upNone. *)
function UnixPlayerExecutable(const aPlayer: TUnixPlayer): string;

(* Is a tone request sane? Guards the range Windows.Beep documents (37 Hz to
  32767 Hz) and refuses a zero duration, so a caller's typo is a logged
  refusal rather than a hang or a silent no-op. *)
function IsSaneTone(const aFrequencyHz, aDurationMs: Cardinal): boolean;

implementation

uses
{$IFDEF WINDOWS}
   Windows,     (* Beep -- synthesised, unlike the \Device\Beep this replaces *)
   MMSystem,    (* sndPlaySoundA *)
{$ENDIF}
   SysUtils,
   uPlatformProcess,   (* RunProgram -- cross-platform, no shell *)
   Log4D;

const
   TONE_MIN_HZ = 37;      { Windows.Beep's documented minimum }
   TONE_MAX_HZ = 32767;   { and its maximum }

var
   logger: TLogLogger = nil;
   GNoToneWarned: boolean = False;

(* ------------------------------------------------------------------ *)
(* The decisions. No device is touched below this line.               *)
(* ------------------------------------------------------------------ *)

function CanPlayFile(const aPath: string): boolean;
begin
   Result := (aPath <> '') and FileExists(aPath);
end;

function IsSaneTone(const aFrequencyHz, aDurationMs: Cardinal): boolean;
begin
   Result := (aFrequencyHz >= TONE_MIN_HZ) and
             (aFrequencyHz <= TONE_MAX_HZ) and
             (aDurationMs > 0);
end;

function UnixPlayerExecutable(const aPlayer: TUnixPlayer): string;
begin
   case aPlayer of
      upAplay:  Result := 'aplay';    { ALSA, on every Linux with alsa-utils }
      upPaplay: Result := 'paplay';   { PulseAudio / PipeWire }
      upAfplay: Result := 'afplay';   { macOS, ships with the system }
   else
      Result := '';
   end;
end;

function ChooseUnixPlayer(const aProbe: TExecutableProbe): TUnixPlayer;
begin
   (* ORDER IS DELIBERATE. aplay talks to ALSA directly and is present on a
     bare Linux install; paplay needs a sound server running but works where
     ALSA is exclusively held by one; afplay is macOS only. Asking in this
     order prefers the fewest moving parts. *)
   Result := upNone;
   if not Assigned(aProbe) then
      begin
      Exit;
      end;
   if aProbe('aplay') then
      begin
      Result := upAplay;
      end
   else if aProbe('paplay') then
      begin
      Result := upPaplay;
      end
   else if aProbe('afplay') then
      begin
      Result := upAfplay;
      end;
end;

(* ------------------------------------------------------------------ *)
(* The device.                                                        *)
(* ------------------------------------------------------------------ *)

{$IFNDEF WINDOWS}
function ProbeExecutable(const aName: string): boolean;
begin
   (* ExeSearch looks along PATH, which is how a Unix box answers "is this
     installed". It does NOT run anything. *)
   Result := FileSearch(aName, GetEnvironmentVariable('PATH')) <> '';
end;
{$ENDIF}

function PlayFile(const aPath: string): boolean;
{$IFNDEF WINDOWS}
var
   player: TUnixPlayer;
   exe:    string;
{$ENDIF}
begin
   Result := False;
   if not CanPlayFile(aPath) then
      begin
      logger.Warn('[Audio] will not play "%s": %s',
                  [aPath, {$IFDEF WINDOWS}'no such file'{$ELSE}'no such file'{$ENDIF}]);
      Exit;
      end;

{$IFDEF WINDOWS}
   Result := sndPlaySoundA(PAnsiChar(AnsiString(aPath)),
                           SND_ASYNC or SND_NODEFAULT);
   if not Result then
      begin
      logger.Warn('[Audio] sndPlaySound failed for "%s"', [aPath]);
      end;
{$ELSE}
   player := ChooseUnixPlayer(@ProbeExecutable);
   exe    := UnixPlayerExecutable(player);
   if exe = '' then
      begin
      logger.Warn('[Audio] no player found for "%s" -- looked for aplay, ' +
                  'paplay and afplay on PATH', [aPath]);
      Exit;
      end;
   Result := RunProgram(exe, [aPath]);
{$ENDIF}
end;

function BeepAlert(const aFrequencyHz, aDurationMs: Cardinal): boolean;
begin
   Result := False;
   if not IsSaneTone(aFrequencyHz, aDurationMs) then
      begin
      logger.Warn('[Audio] refusing tone %d Hz for %d ms -- outside %d..%d Hz ' +
                  'or zero length',
                  [aFrequencyHz, aDurationMs, TONE_MIN_HZ, TONE_MAX_HZ]);
      Exit;
      end;

{$IFDEF WINDOWS}
   (* Windows.Beep, NOT the \Device\Beep IOCTL this replaces. It synthesises
     through the sound card, where the IOCTL needed a PC speaker and a
     beep.sys that is disabled on most Windows 10/11 machines -- which is why
     the old warning beeps did nothing, silently, on most stations.

     It BLOCKS for the duration, and that is correct HERE: SpeakerBeep already
     blocked (ntBeep then Sleep(Duration)). It was the wrong call for the CW
     sidetone, which is gone. *)
   Result := Windows.Beep(aFrequencyHz, aDurationMs);
{$ELSE}
   (* NO TONE GENERATOR OFF WINDOWS, and this reports rather than pretends.
     A .WAV would work (PlayFile above), so if the alerts matter on Linux or
     macOS the answer is to ship short files -- a decision about what TR4W
     installs, not something this unit should invent. Said once. *)
   if not GNoToneWarned then
      begin
      GNoToneWarned := True;
      logger.Warn('[Audio] no tone generator on this platform: alert beeps ' +
                  'are silent. Playing a short .WAV would work -- see the ' +
                  'note in uAudio.BeepAlert');
      end;
{$ENDIF}
end;

procedure StopSound;
begin
{$IFDEF WINDOWS}
   (* nil with SND_PURGE stops whatever this process started. *)
   sndPlaySoundA(nil, SND_PURGE);
{$ELSE}
   (* The helper process owns its own lifetime and a .WAV is short. Killing it
     would mean tracking a PID for no benefit the callers ask for -- none of
     them stop a sound today. *)
{$ENDIF}
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.Audio');

end.

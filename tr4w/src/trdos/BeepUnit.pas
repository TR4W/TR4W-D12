{
 Copyright Larry Tyree, N6TR, 2011,2012,2013,2014,2015.

 This file is part of TR4W    (TRDOS)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W.  If not, see
 <http: www.gnu.org/licenses/>.
 }
 unit BeepUnit;
{$I ..\tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC
{$IFDEF WINDOWS}
  (* GENUINELY WINDOWS, AND GATED RATHER THAN PORTED (2026-09-08).

    This unit drives \Device\Beep (beep.sys) by IOCTL through a DOS device
    alias it defines for itself: QueryDosDeviceA, DefineDosDeviceA,
    CreateFileA, DeviceIoControl. There is no equivalent anywhere else, and
    there should not be -- the note by ntBeep already says what should replace
    it ON WINDOWS TOO: a sidetone rendered on its own thread. That is a real
    piece of work, not a translation, so gating is the honest holding position
    and porting it now would be guessing at both platforms at once.

    Off Windows every entry point below is a no-op that SAYS SO ONCE, which is
    the same complaint the ntBeep note makes about the Windows path failing
    silently when beep.sys is disabled. *)
  , Windows
{$ENDIF}
  ;

procedure SpeakerBeep(Tone, Duration: Word);
procedure NoSound;
procedure ntBeepInit;
procedure ntBeepClose;
procedure ntBeep(Freq, Duration: Cardinal);

{$IFDEF WINDOWS}
type
  BEEP_SET_PARAMETERS = record
    Frequency, Duration: Cardinal;
  end;
{$ENDIF}

{$IFDEF WINDOWS}
const
  IOCTL_BEEP_SET                        = $10000;
  FileNameStr                           : array[0..9] of AnsiChar = '\\.\tr4w'#0;
  BeepFileName                          : PAnsiChar = @FileNameStr[0];
  DevName                               : PAnsiChar = @FileNameStr[3];
{$ENDIF}
{$IFDEF WINDOWS}
var
  (* CreateFileA on the beep device -- a FILE handle, not a window. *)
  hBeep                                 : THandle = INVALID_HANDLE_VALUE;
  OwnDevName                            : LongBool;
{$ENDIF}

implementation

uses
{$IFNDEF WINDOWS}
  Log4D,
{$ENDIF}
  MainUnit,
  LogK1EA,
  LogRadio,
  Tree;

{$IFNDEF WINDOWS}
(* SAID ONCE, NOT ONCE PER BEEP.

  Every entry point in this unit is a no-op off Windows -- see the gate on the
  interface uses clause. A contest generates a beep per dupe and per new
  multiplier, so this reports the first time and then stays quiet. *)
var
  GToneWarned: boolean = False;

procedure ReportNoToneGenerator;
begin
   if GToneWarned then
      begin
      Exit;
      end;
   GToneWarned := True;
   TLogLogger.GetLogger('TR4WDebugLog').Warn(
      'No tone generator on this platform: the sidetone and every warning beep '
      + 'are silent. BeepUnit drives the Windows \Device\Beep driver, and the '
      + 'replacement (a sidetone on its own thread) is owed on Windows too.');
end;
{$ENDIF}

{
  DELETED: SetPort, GetPort and Sound -- the PC-speaker path.
  KEPT AS A NO-OP: NoSound (see below), which still has five callers.

  Sound() programmed the 8253 timer directly through IN/OUT on ports $42, $43
  and $61.  IN and OUT are PRIVILEGED instructions: executed from user mode on
  any NT-family Windows they raise STATUS_PRIVILEGED_INSTRUCTION.  They worked
  on Windows 95/98/Me and have not worked on anything since.

  Nothing supported reached them, which is why this was never seen:

    - SetPort and GetPort had NO callers outside this unit.
    - LOGK1EA's two Sound() calls sat behind
      `if WindowsOSversion = VER_PLATFORM_WIN32_WINDOWS`, i.e. Windows 9x only;
      every other Windows already took the ntBeep branch. Those tests are gone
      with them, so the sidetone code no longer asks what OS it is on.
    - tree.pas's Dit/Dah were the only unguarded callers, and they are not in
      tree's interface and nothing calls them. Deleted with these.

  Behaviour on every supported Windows is therefore unchanged: the branch that
  is gone could not execute.

  WHAT REPLACES IT IS STILL OPEN, and is a real decision rather than a
  translation -- see ntBeep below.
}

{
  NoSound -- retained, and does nothing, on purpose.

  It has five live callers (MainUnit, JCtrl1, JCTRL2, LOGK1EA, LOGSUBS2), four
  of them in TRDOS, and they call it WITHOUT parentheses -- which is how they
  escape a `NoSound\s*\(` search. Its whole body was already inside
  `if WindowsOSversion = VER_PLATFORM_WIN32_WINDOWS`, so on every supported
  Windows it has always done nothing. Keeping it as an explicit no-op preserves
  all five call sites with provably zero behaviour change; deleting it would
  have meant editing five files across TRDOS to remove calls that already had
  no effect.

  When a real threaded sidetone lands (see ntBeep), this is the hook that stops
  it, and these five call sites are already in the right places.
}
procedure NoSound;
begin
  // Intentionally empty -- see above.
end;

procedure SpeakerBeep(Tone, Duration: Word);

begin
  if not BeepEnable then 
     begin
     Exit;
     end;

  ntBeep(Tone, Duration);
  Sleep(Duration);

end;

procedure ntBeepInit;
begin
{$IFNDEF WINDOWS}
  ReportNoToneGenerator;
{$ELSE}
  OwnDevName := False;

  if WindowsOSversion = VER_PLATFORM_WIN32_WINDOWS then
     begin
     Exit;
     end;
     
  if Windows.QueryDosDeviceA(DevName, wsprintfBuffer, MAX_PATH) = 0 then
     begin
     Windows.DefineDosDeviceA(DDD_RAW_TARGET_PATH, DevName, '\Device\Beep');
     OwnDevName := True;

     hBeep := Windows.CreateFileA(BeepFileName, GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
     ntBeep(32767 - 1, 1);
     end;
{$ENDIF}
end;

procedure ntBeepClose;
begin
{$IFDEF WINDOWS}
  if OwnDevName then
     begin
     Windows.DefineDosDeviceA(DDD_REMOVE_DEFINITION, DevName, nil);
     end;
  if hBeep <> INVALID_HANDLE_VALUE then
     begin
     CloseHandle(hBeep);
     end;
{$ENDIF}
end;

{
  ntBeep -- the CW sidetone and every warning beep.

  OPEN, and deliberately NOT changed in the same pass that removed the port I/O.

  This drives \Device\Beep (beep.sys) by IOCTL, via a DOS device alias this unit
  defines for itself in ntBeepInit.  On Windows 10/11 beep.sys is commonly
  disabled and most machines have no PC speaker, in which case CreateFile fails,
  hBeep stays INVALID_HANDLE_VALUE, and every beep SILENTLY does nothing -- the
  exact silent-fallback shape this project treats as a defect.

  Windows.Beep(freq, duration) is the documented modern replacement and does
  synthesize through the sound card. It is NOT a drop-in here: it BLOCKS for the
  duration, whereas this IOCTL returns immediately and LOGK1EA does its own
  `tCWSleep(CWElementLength, ...)` afterwards. Swapping it in directly would
  double every CW element's timing -- a keyer regression, not a cosmetic one.

  So a real fix is a sidetone rendered on its own thread (waveOut or XAudio2),
  which is also the only version that survives the move off Win32. Pending that
  work, this stays as it is -- with the failure documented rather than hidden.
}
procedure ntBeep(Freq, Duration: Cardinal);
{$IFNDEF WINDOWS}
begin
  ReportNoToneGenerator;
end;
{$ELSE}
var
  BeepSetParams                         : BEEP_SET_PARAMETERS;
  BytesReturned                         : Cardinal;
begin
  if hBeep = INVALID_HANDLE_VALUE then 
     begin
     Exit;
     end;
     
  if Freq < 37 then 
     begin
     Exit;
     end;
     
  if Freq > 32767 then 
     begin
     Exit;
     end;
     
  BeepSetParams.Frequency := Freq;
  BeepSetParams.Duration := Duration;
  DeviceIoControl(hBeep, 
                  IOCTL_BEEP_SET, 
                  @BeepSetParams, 
                  SizeOf(BEEP_SET_PARAMETERS), 
                  nil, 
                  0, 
                  BytesReturned, 
                  nil);
end;
{$ENDIF}

end.

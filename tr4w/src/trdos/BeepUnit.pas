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
  VC,
  Windows;

procedure SpeakerBeep(Tone, Duration: Word);
procedure NoSound;
procedure ntBeepInit;
procedure ntBeepClose;
procedure ntBeep(Freq, Duration: Cardinal);

type
  BEEP_SET_PARAMETERS = record
    Frequency, Duration: Cardinal;
  end;

const
  IOCTL_BEEP_SET                        = $10000;
  FileNameStr                           : array[0..9] of AnsiChar = '\\.\tr4w'#0;
  BeepFileName                          : PAnsiChar = @FileNameStr[0];
  DevName                               : PAnsiChar = @FileNameStr[3];
var
  hBeep                                 : HWND = INVALID_HANDLE_VALUE;
  OwnDevName                            : LongBool;

implementation

uses
  MainUnit,
  LogK1EA,
  LogRadio,
  Tree;

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
 // if Tone < 40 then Exit;
  if not BeepEnable then Exit;

  ntBeep(Tone, Duration);
  Sleep(Duration);
{
  Exit;

  if WindowsOSversion = VER_PLATFORM_WIN32_NT then
    Windows.Beep(Tone, Duration)

  else
  begin
    //if BeepEnable then
    Sound(Tone);
    Sleep(Duration);
    NoSound;
  end;
}
end;

procedure ntBeepInit;
begin
  OwnDevName := False;

  if WindowsOSversion = VER_PLATFORM_WIN32_WINDOWS then Exit;
  if Windows.QueryDosDeviceA(DevName, wsprintfBuffer, MAX_PATH) = 0 then
     begin
     //if not
     Windows.DefineDosDeviceA(DDD_RAW_TARGET_PATH, DevName, '\Device\Beep');
     //then ShowSysErrorMessage('GET SPEAKER');
     OwnDevName := True;

     hBeep := Windows.CreateFileA(BeepFileName, GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
 //    if hBeep = INVALID_HANDLE_VALUE then ShowSysErrorMessage('COMPUTER SPEAKER');
     ntBeep(32767 - 1, 1);
     end;
end;

procedure ntBeepClose;
begin
  if OwnDevName then
     begin
     Windows.DefineDosDeviceA(DDD_REMOVE_DEFINITION, DevName, nil);
     end;
  if hBeep <> INVALID_HANDLE_VALUE then
     begin
     CloseHandle(hBeep);
     end;
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
var
  BeepSetParams                         : BEEP_SET_PARAMETERS;
  BytesReturned                         : Cardinal;
begin
  if hBeep = INVALID_HANDLE_VALUE then Exit;
  if Freq < 37 then Exit;
  if Freq > 32767 then Exit;
  BeepSetParams.Frequency := Freq;
  BeepSetParams.Duration := Duration;
//  if not
  DeviceIoControl(hBeep, IOCTL_BEEP_SET, @BeepSetParams, SizeOf(BEEP_SET_PARAMETERS), nil, 0, BytesReturned, nil);
//    then ShowSysErrorMessage('SET SPEAKER');
end;

end.

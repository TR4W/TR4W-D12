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

(* TWO ROUTINES NOW, AND NO DEVICE (2026-09-08).

  ntBeepInit, ntBeepClose and ntBeep are GONE with the \Device\Beep driver
  they drove. That path opened a DOS device alias this unit defined for
  itself -- QueryDosDeviceA, DefineDosDeviceA, CreateFileA, DeviceIoControl --
  and on Windows 10/11 it usually did NOTHING AT ALL: beep.sys is commonly
  disabled and most machines have no PC speaker, so CreateFile failed, the
  handle stayed invalid, and every warning beep was silent with nothing said.

  uAudio.BeepAlert replaces it with Windows.Beep, which SYNTHESISES THROUGH
  THE SOUND CARD. That call was rejected once before, correctly, because it
  BLOCKS for the duration and the CW sidetone could not afford that -- but the
  sidetone is gone (NY4I, 2026-09-08) and SpeakerBeep already blocked, with an
  explicit Sleep(Duration) after the IOCTL. *)
procedure SpeakerBeep(Tone, Duration: Word);
procedure NoSound;

implementation

uses
  uAudio,   (* every platform decision about sound lives there now *)
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
  if not BeepEnable then
     begin
     Exit;
     end;

  (* THE Sleep IS GONE WITH THE IOCTL, and dropping it is not an oversight.
    ntBeep returned immediately -- DeviceIoControl fires and returns -- so the
    Sleep WAS the duration. Windows.Beep blocks for the duration itself, so
    keeping both would make every alert take twice as long. *)
  uAudio.BeepAlert(Tone, Duration);
end;

end.

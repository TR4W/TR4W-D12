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
unit uHostName;
{$I ..\tr4w.inc}

(* THE NAME OF THIS MACHINE, AND THE ONE PLACE THAT KNOWS HOW TO ASK.

  WHY THIS IS A UNIT AND NOT A GATE IN MainUnit. There is genuinely no portable
  RTL or LCL call for a host name -- checked, not assumed:

    Windows   the Win32 GetComputerNameW
    Unix      unix.pp declares `function GetHostName: String` (unix.pp:115),
              and it exists ONLY in that unit, which does not compile on Windows

  So a conditional is unavoidable. What IS avoidable is having it in the middle
  of a 12,000-line unit, which is why it lives here: one small leaf, one
  conditional, and every caller reads as ordinary Pascal. That is the shape
  CLAUDE.md asks for when a platform difference is real -- the same argument as
  the single unit that should own every shipped library's NAME.

  This is the FIRST caller of a per-platform helper in this tree, so it is worth
  saying what makes it correct rather than merely working: the two arms return
  the same KIND of answer -- the name this machine is known by on the local
  network -- and neither invents one. A Windows NetBIOS name and a Unix host
  name are not byte-identical concepts, and for the two consumers here (a
  <NetBiosName> element in the HamScore XML and a <StationName> in the PST
  rotator XML, both identifying the operating position to another program on
  the same LAN) that difference does not matter. If a caller ever needs the
  fully-qualified DNS name, that is a DIFFERENT function, not a change to this
  one. *)

interface

(* The local machine's network name, or '' if the platform cannot say.

  EMPTY IS A REAL ANSWER, not an error to swallow: a container or a chroot can
  genuinely have no host name. Callers already embed the result in XML, where
  an empty element is well-formed and readable. *)
function LocalComputerName: string;

implementation

uses
{$IFDEF WINDOWS}
   Windows        (* GetComputerNameW -- there is no RTL equivalent *)
{$ELSE}
   Unix           (* GetHostName -- unix.pp:115 *)
{$ENDIF}
   ;

{$IFDEF WINDOWS}
function LocalComputerName: string;
var
   len:  DWORD;
   name: array[0..MAX_COMPUTERNAME_LENGTH] of WideChar;
begin
   (* MAX_COMPUTERNAME_LENGTH, not MAX_PATH. The old code in MainUnit sized
     this buffer at MAX_PATH and told the API so, which is harmless but says
     the wrong thing about what a computer name is. The constant Windows
     documents for this call is the right one, and the +1 for the terminator
     comes from the array being 0..MAX_COMPUTERNAME_LENGTH inclusive.

     GetComputerNameW is named explicitly rather than the generic
     GetComputerName: the generic name binds to the ANSI entry point under
     FPC's windows unit, and this buffer is WideChar. That was already the
     reason given in MainUnit and it still holds. *)
   len := Length(name);
   if not GetComputerNameW(@name[0], len) then
      begin
      Result := '';
      Exit;
      end;

   (* len is set BY THE CALL to the character count actually written, so use
     it rather than trusting the terminator. *)
   SetString(Result, PWideChar(@name[0]), len);
end;
{$ELSE}
function LocalComputerName: string;
begin
   Result := Unix.GetHostName;
end;
{$ENDIF}

end.

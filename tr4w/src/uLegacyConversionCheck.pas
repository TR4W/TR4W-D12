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
unit uLegacyConversionCheck;
{$I tr4w.inc}

(*
  ONE QUESTION, ASKED OF THE FILE SYSTEM: has this station got a 4.x
  configuration that has never been carried across?

  THE CONDITION IS EXACTLY TWO FILE TESTS AND IT IS DELIBERATELY NARROW.

      a legacy tr4w.ini EXISTS   and   settings\tr4w.json DOES NOT

  Nothing else. It does not read either file, it does not look at what is in
  the ini, and it has no opinion about what should happen next.

  WHY IT IS THIS NARROW, AND WHY IT MUST STAY SO. An in-program detector for a
  leftover ini existed and was REMOVED on NY4I's instruction (2026-09-19):
  "it frankly kept getting in the way and causing confusion". What he approved
  in its place (2026-09-20) is a single first-run offer to run the converter,
  and the reason it cannot become the thing that was removed is arithmetic
  rather than restraint: TR4W writes settings\tr4w.json the first time it
  loads its settings, so from that moment the right-hand test is False
  FOREVER. The offer can fire AT MOST ONCE in a station's life, by
  construction. There is no flag to remember and no "do not ask again" to get
  wrong, because there is nothing that could ask twice.

  Broadening it -- "the ini has commands in it", "the ini is newer than the
  json", "some settings look unconverted" -- reintroduces exactly the nagging
  detector that was withdrawn. Do not.

  IT IS A LEAF ON PURPOSE. No LCL, no logger, no globals: the dialog and the
  launch live in uFirstRunConvert, which cannot be driven from the test
  binary, and this can (uTestLegacyConversionCheck).
*)

interface

(* True when the station has an old configuration and TR4W has never written
  its own settings file.

  Both paths are given rather than resolved here, so the caller states which
  files it means -- the program passes the two it is actually about to use,
  and a test passes two it has arranged. An empty path answers False: "no
  file was named" is not "the file is there". *)
function LegacyConversionOffered(const aLegacyIniPath: string;
                                 const aSettingsFilePath: string): boolean;

implementation

uses
   SysUtils;

function LegacyConversionOffered(const aLegacyIniPath: string;
                                 const aSettingsFilePath: string): boolean;
begin
   Result := False;

   if (Trim(aLegacyIniPath) = '') or (Trim(aSettingsFilePath) = '') then
      begin
      Exit;
      end;

   Result := FileExists(aLegacyIniPath) and
             (not FileExists(aSettingsFilePath));
end;

end.

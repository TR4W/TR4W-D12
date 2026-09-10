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
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* A FONT NAME THAT EXISTS ON THIS MACHINE.

  A FONT NAME IS A PLATFORM ASSUMPTION WEARING A TYPEFACE, and it fails the
  same way a hardcoded library name does: silently, with a substitution that
  looks like a rendering bug rather than a missing file.

  THE DEFECT THIS UNIT COMES FROM. The DX cluster console asks for 'Lucida
  Console'. That font ships with Windows and exists on no Linux box:

      $ fc-match 'Lucida Console'
      NotoSans-Regular.ttf: "Noto Sans" "Regular"

  Noto Sans is PROPORTIONAL and its line metrics are taller. So a window whose
  entire purpose is column-aligned text -- callsign, frequency, comment, time,
  each in its own column -- was drawn in a variable-pitch face, and its rows
  were far enough apart that NY4I read it as a data fault: "The dx cluster
  seems to be adding an extra CR or LF at the end of each line" (2026-09-09).

  IT WAS NEITHER A CR NOR AN LF. The wire was clean -- telnet debug showed one
  spot per line, length 75, no blank lines between them. The only thing wrong
  was the typeface, and nothing reported the substitution because fontconfig
  considers substituting its job.

  Font.Pitch = fpFixed WAS ALREADY SET and did not help. It is a hint the
  widget set is free to ignore, and gtk2 did.

  SO ASK THE MACHINE WHAT IT HAS. Screen.Fonts is the LCL's own answer and
  needs no platform call; the candidate lists below are ordered best-first per
  platform and end in a name the widget set understands generically. The
  chosen name is LOGGED, because "which font am I actually looking at" is the
  first question a rendering complaint needs and there was no way to ask it. *)
unit uPlatformFonts;

{$MODE DELPHI}
{$H+}

interface

(* The best fixed-pitch family installed here. Computed once. *)
function MonospaceFontName: string;

implementation

uses
   SysUtils, Classes, Forms, Log4D;

var
   GMonospace: string = '';
   GLogger: TLogLogger = nil;

function Log: TLogLogger;
begin
   if GLogger = nil then
      begin
      GLogger := TLogLogger.GetLogger('TR4WDebugLog.Fonts');
      end;
   Result := GLogger;
end;

(* ORDERED BEST FIRST, AND EVERY LIST ENDS IN A GENERIC.

  Windows keeps Lucida Console because that is what TR4W has always drawn this
  window in and it is present on every supported version; Consolas is the
  newer answer and Courier New the floor.

  Linux leads with DejaVu Sans Mono -- effectively universal, and it is on
  NY4I's Mint box -- then Liberation Mono, which is metric-compatible with
  Courier New, then Noto Sans Mono. 'Monospace' is fontconfig's own alias and
  resolves to whatever the system considers the default fixed-pitch face, so
  the list cannot come back empty on a machine that has any at all.

  macOS leads with Menlo, the Terminal default since 10.6; Monaco is the older
  one and SF Mono ships with newer systems but is not always exposed by name. *)
function Candidates: TStringArray;
begin
{$IFDEF WINDOWS}
   Result := ['Lucida Console', 'Consolas', 'Courier New'];
{$ENDIF}
{$IFDEF LINUX}
   Result := ['DejaVu Sans Mono', 'Liberation Mono', 'Noto Sans Mono',
              'Monospace'];
{$ENDIF}
{$IFDEF DARWIN}
   Result := ['Menlo', 'Monaco', 'Courier New'];
{$ENDIF}
end;

function MonospaceFontName: string;
var
   want: TStringArray;
   i:    integer;
begin
   if GMonospace <> '' then
      begin
      Result := GMonospace;
      Exit;
      end;

   want := Candidates;

   for i := Low(want) to High(want) do
      begin
      (* IndexOf, not a substring search: Screen.Fonts holds exact family
        names, and a partial match would accept 'DejaVu Sans' for 'DejaVu Sans
        Mono' -- which is the proportional face and the exact mistake being
        fixed. *)
      if Screen.Fonts.IndexOf(want[i]) >= 0 then
         begin
         GMonospace := want[i];
         Break;
         end;
      end;

   if GMonospace = '' then
      begin
      (* NOTHING MATCHED. Take the last candidate anyway -- it is the generic
        one -- and SAY SO, because from here the widget set substitutes
        whatever it likes and the operator gets the misaligned columns this
        unit exists to prevent. *)
      GMonospace := want[High(want)];
      Log.Warn('[Fonts] no fixed-pitch family from the candidate list is '
               + 'installed; falling back to "%s", which the widget set will '
               + 'substitute. Column-aligned windows may not line up.',
               [GMonospace]);
      end
   else
      begin
      Log.Info('[Fonts] fixed-pitch family: %s', [GMonospace]);
      end;

   Result := GMonospace;
end;

end.

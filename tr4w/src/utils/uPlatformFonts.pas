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

(* A BARE MODE DELPHI, AND NOT tr4w.inc -- DELIBERATELY. Do not "fix" it.

  Every other unit in src\utils includes tr4w.inc, which adds MODESWITCH
  UnicodeStrings, so this one looks like an oversight. It is not, and adding
  the include was tried on 2026-09-16 and reverted the same hour.

  THIS UNIT'S ENTIRE SURFACE IS THE LCL'S OWN STRING TYPE. Screen.Fonts is a
  TStrings, the candidate lists are a TStringArray, and MonospaceFontName's one
  caller assigns it straight to TFont.Name. All of those are AnsiString,
  because the LCL is not compiled with UnicodeStrings. Matching them is the
  whole point: the value never leaves the widget set.

  Adding the include did not remove the conversions, it MOVED them inward --
  two callers stopped converting and the unit's own body started, at the
  TStringArray and at Screen.Fonts. Same count, worse place.

  SO A CALLER THAT PASSES A REAL STRING DECLARES UnicodeString EXPLICITLY, as
  InstallPrivateFont and UninstallPrivateFont do below. That is not decoration:
  those two call the WIDE Win32 entry points, and PWideChar over an AnsiString
  is a POINTER REINTERPRET, not a conversion -- the exact defect tr4w.inc's own
  header records, where it opened COM13 and got ERROR_INVALID_NAME with no
  diagnostic anywhere. *)
{$MODE DELPHI}
{$H+}

interface

(* The best fixed-pitch family installed here. Computed once. *)
function MonospaceFontName: string;

(* INSTALL AND UNINSTALL A PRIVATE FONT FILE -- the pair, in one unit.

  They arrived here on 2026-09-16 from two DIFFERENT units: the install was a
  gated AddFontResourceW in uProgramMain and the uninstall a gated
  RemoveFontResourceW in logsubs2, a TRDOS core unit. An acquire and its
  matching release, six hundred lines and one subsystem apart, each carrying
  its own copy of the platform reasoning.

  There is no FPC or LCL class to reach for instead, and that is not an
  oversight: font INSTALLATION has no cross-platform shape. Windows has
  AddFontResource, Linux hands it to fontconfig, macOS to CTFontManager. So
  the rung below applies -- OUR unit owns the gate, and the callers pass a
  string and read a Boolean.

  Install returns False where the platform does not do this, which is the
  TRUE answer rather than a degraded one: the font genuinely is not loaded.
  Callers already branch on that.

  UnicodeString EXPLICITLY, NOT `string`, and this is the one place in this
  unit where that is right. See the note at the top: `string` here is the
  LCL's AnsiString, on purpose, because everything else this unit touches is
  the widget set's own type. These two are the exception -- they take a file
  name from a caller that IS UnicodeString and hand it to the WIDE Win32
  entry point, where PWideChar over an AnsiString would reinterpret bytes
  rather than convert them. Spelling the type removes the conversion at both
  callers and makes the cast inside correct by construction. *)
function InstallPrivateFont(const aFileName: UnicodeString): Boolean;
procedure UninstallPrivateFont(const aFileName: UnicodeString);

implementation

uses
{$IFDEF WINDOWS}
   (* AddFontResourceW and RemoveFontResourceW, and the ONLY reason this unit
     knows what Windows is. That is the point of putting them here: the gate
     belongs in the unit that owns fonts, not in the startup path and not in a
     TRDOS core unit, which is where the two halves used to live. *)
   Windows,
{$ENDIF}
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

function InstallPrivateFont(const aFileName: UnicodeString): Boolean;
{$IFDEF WINDOWS}
const
   (* TYPED UnicodeString, and the reason is the unit's string mode rather
     than taste: a bare literal here is an AnsiString, so concatenating it
     with the UnicodeString parameter would convert -- and the build counts
     every such conversion against a ceiling. Two typed constants and the
     parameter concatenate with no crossing at all, and Log4D's Warn takes
     exactly this type because Log4D is on tr4w.inc. *)
   FAILED_PREFIX: UnicodeString = 'AddFontResource failed for ';
   FAILED_SUFFIX: UnicodeString = ' -- the private font will not be available';
{$ENDIF}
begin
   (* False is the answer on every platform that does not do this, and the
     callers rely on it: LuconSZLoadded is read three times and each reader
     already branches. *)
   Result := False;

{$IFDEF WINDOWS}
   (* PWideChar is the transport and it STAYS INSIDE THIS UNIT. AddFontResourceW
     takes an LPCWSTR and there is no FPC or LCL wrapper that takes a string,
     so this cast is a genuine boundary rather than a habit -- which is exactly
     the distinction the pointer work is drawing.

     AND IT IS ONLY CORRECT BECAUSE THE PARAMETER IS UnicodeString. Over an
     AnsiString this same line would reinterpret bytes as UTF-16 instead of
     converting them, silently, which is how uSerialPort once opened COM13 and
     got ERROR_INVALID_NAME with nothing in any log. *)
   Result := AddFontResourceW(PWideChar(aFileName)) <> 0;

   if not Result then
      begin
      (* REPORTED, NOT SILENT, and this is a change in behaviour. The old call
        site discarded the result: a missing or unreadable font file left the
        flag False with nothing said, and surfaced much later as the wrong
        face in the log window with no way to connect the two. *)
      Log.Warn(FAILED_PREFIX + aFileName + FAILED_SUFFIX);
      end;
{$ENDIF}
end;

procedure UninstallPrivateFont(const aFileName: UnicodeString);
begin
{$IFDEF WINDOWS}
   RemoveFontResourceW(PWideChar(aFileName));
{$ENDIF}

   (* There is deliberately nothing in the else arm. Where InstallPrivateFont
     returned False nothing was installed, and a caller guarding on that
     result -- which both do -- never arrives here at all. *)
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

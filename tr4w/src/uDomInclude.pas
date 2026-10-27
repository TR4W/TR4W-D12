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

unit uDomInclude;

(* WHERE A .dom's `INCLUDE FILE <name>` IS LOOKED FOR, AND WHAT IS SAID WHEN
  IT CANNOT BE FOLLOWED -- issue #138, 2026-10-27.

  LOGDOM's EnumDOMFILE follows the line; this leaf answers the two questions
  it needs SysUtils for (LOGDOM keeps SysUtils out of its uses on purpose --
  see its finalization), so both are pinned without the loader.

  BESIDE THE INCLUDING FILE FIRST, THEN THE SHIPPED dom FOLDER. D7 looked
  only in '<program dir>DOM\', and so did this tree, through
  uAppPaths.ShippedDomFilePath -- the WORKING directory's dom folder. In the
  program the two are one place: every shipped .dom is read from that folder
  and includes its neighbours, so nothing there changes. They differ for a
  .dom read from anywhere else: the unit tests read the tree's files by full
  path from tr4w/test/unit, which has no dom folder, so a real INCLUDE FILE
  was never found there; and an operator's own .dom (TR4W_DOM_FILENAME,
  beside the contest) now finds a neighbour it ships with, and still falls
  back to the shipped file it names. A neighbour SHADOWS the shipped file of
  the same name -- the same precedence an operator's own .dom already has
  over the shipped one.

  NESTING IS BOUNDED. Nothing stopped a file that includes itself, or two
  that include each other, from re-entering the loader until the stack ran
  out. The shipped files nest two deep (colorado.dom -> S50.DOM -> S48.DOM);
  eight is far past that and close enough to stop a circle quickly. *)

{$I tr4w.inc}

interface

const
   MAX_DOM_INCLUDE_DEPTH = 8;

(* THE FILE `INCLUDE FILE aName` READS, written in aIncludingFile; '' when
   neither place has it. aName is trimmed. aTried lists, one per line, every
   path that was looked at, for the report. *)
function ResolveDomInclude(const aIncludingFile, aName: string; out aTried: string): string;

(* The operator's report of an include that could not be read, and of one
   that would nest too deep. aLine is the line as written. *)
function DomIncludeNotReadText(const aIncludingFile, aLine, aTried: string): string;
function DomIncludeTooDeepText(const aIncludingFile, aLine: string): string;

(* The same report on one line, for the log. *)
function DomIncludeLogLine(const aReport: string): string;

implementation

uses
   SysUtils,
   (* ExistingDataFile, ShippedDomFilePath. *)
   uAppPaths,
   uAppStrings;

function ResolveDomInclude(const aIncludingFile, aName: string; out aTried: string): string;
var
   name: string;
   beside: string;
   shipped: string;
begin
   Result := '';
   aTried := '';
   name := Trim(aName);
   if name = '' then
      begin
      Exit;
      end;

   (* A BARE including name has no directory of its own to look beside. *)
   if ExtractFilePath(aIncludingFile) <> '' then
      begin
      beside := ExistingDataFile(ExtractFilePath(aIncludingFile) + name);
      aTried := beside;
      if FileExists(beside) then
         begin
         Result := beside;
         Exit;
         end;
      end;

   (* THE SAME PLACE IS LISTED ONCE. In the program the including file was
      itself composed by ShippedDomFilePath, so the two spellings are equal
      when the two places are; a plain compare, as SameFileName and
      ExpandFileName take AnsiString here and would narrow both. *)
   shipped := ShippedDomFilePath(name);
   if shipped <> aTried then
      begin
      if aTried <> '' then
         begin
         aTried := aTried + sLineBreak;
         end;
      aTried := aTried + shipped;
      end;
   if FileExists(shipped) then
      begin
      Result := shipped;
      end;
end;

function DomIncludeNotReadText(const aIncludingFile, aLine, aTried: string): string;
begin
   Result := UnicodeFormat(SDomIncludeNotRead, [aIncludingFile, aLine, aTried]);
end;

function DomIncludeTooDeepText(const aIncludingFile, aLine: string): string;
begin
   Result := UnicodeFormat(SDomIncludeTooDeep, [aIncludingFile, MAX_DOM_INCLUDE_DEPTH, aLine]);
end;

function DomIncludeLogLine(const aReport: string): string;
var
   i: integer;
begin
   (* A line break becomes a blank; by hand, as StringReplace takes
      AnsiString here and would narrow the report. *)
   Result := '[LogDom] ';
   for i := 1 to Length(aReport) do
      begin
      if aReport[i] = #10 then
         begin
         Result := Result + ' ';
         end
      else if aReport[i] <> #13 then
         begin
         Result := Result + aReport[i];
         end;
      end;
end;

end.

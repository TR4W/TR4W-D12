(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* LOADING A SHIPPED .dom THROUGH THE REAL LOADER, ITS INCLUDEs FOLLOWED BY
  THE TEST -- lifted from uTestContestNewEnglandQP on 2026-10-26 (#88), when
  uTestContestMissouriQP and uTestContestBritishColumbiaQP became its second
  and third callers. The text below is that unit's, unchanged. *)
unit uTestShippedDom;

{$I ..\..\src\tr4w.inc}

interface

uses
   LogDom;

(* The file an INCLUDE FILE line names, read as EnumDOMFILE reads it; ''
   for any other line. *)
function DomIncludeName(const aLine: string): string;

(* aFileName (a name in the shipped dom folder, in any case) into aTable, as
   the loader would, its INCLUDEs followed by the test. Answers the file's
   OWN INCLUDE FILE names, upper-cased, in its order, blank-separated. *)
function LoadShippedDomFollowingIncludes(aTable: TDomQTHTable;
                                         const aFileName: string;
                                         aTopLevel: boolean;
                                         aDepth: integer): string;

(* The multiplier and the QTH aTable gives aAlias, upper-cased; '' when it
   does not know it. *)
function MultiplierOf(aTable: TDomQTHTable; const aAlias: string): string;
function QTHOf(aTable: TDomQTHTable; const aAlias: string): string;

implementation

uses
   Classes,
   SysUtils,
   (* ExistingDataFile -- a shipped file, whatever case it is spelled in. *)
   uAppPaths,
   (* ShippedDomDir. *)
   uTestContestObjects;

(* ---------------------------------------------------------------------------
   LOADING A SHIPPED .dom, ITS INCLUDEs FOLLOWED BY THE TEST

   THE LOADER CANNOT FOLLOW AN INCLUDE FILE FROM HERE. EnumDOMFILE resolves
   one through uAppPaths.ShippedDomFilePath, which is DataDir's dom folder --
   the working directory on Windows, but /usr/share/tr4w/ or the binary's
   own directory (tr4w/test/unit, which has no dom folder) on Linux. So on
   Linux the include is missing, the loader queues its modal "could not
   find this file" warning, and the first later test that pumps messages
   blocks for ever under xvfb (the v5.0.31 release run). uTestContestGeorgiaQP
   records the same limit ("Its INCLUDEs cannot be followed here").

   So the test follows them itself, and the REAL loader still reads every
   line of every real file: each file is cut at its INCLUDE FILE lines into
   segments, each segment is written to a temp copy and read by
   ReadDomQTHFile, and each named file is loaded the same way, in the
   file's order -- depth first, exactly where the loader would have
   re-entered. Only the first segment of the top-level file is read as a
   top-level file (it clears the table, as LoadInDomQTHFile's one call to
   ReadDomQTHFile(..., False) does); every other one is read as included.
   No temp copy holds an INCLUDE line, so the loader never resolves a path
   itself, and every file is proved to exist BEFORE it is read -- a missing
   one fails here with its path, instead of queuing the warning.
   --------------------------------------------------------------------------- *)

const
   DOM_INCLUDE_KEYWORD = 'INCLUDE FILE';

(* The file an INCLUDE FILE line names, read as EnumDOMFILE reads it (leading
   blanks dropped, the keyword case-sensitive); '' for any other line. *)
function DomIncludeName(const aLine: string): string;
var
   trimmed: string;
begin
   Result := '';
   trimmed := TrimLeft(aLine);
   if Copy(trimmed, 1, Length(DOM_INCLUDE_KEYWORD)) = DOM_INCLUDE_KEYWORD then
      begin
      Result := Trim(Copy(trimmed, Length(DOM_INCLUDE_KEYWORD) + 2, 200));
      end;
end;

(* One segment of aFileName, through the real loader, from a temp copy. The
   copy starts with a line naming its source -- no '=', so not an entry --
   which also keeps it from being empty: EnumerateLinesInFile refuses an
   empty file, and the loader would queue the warning for it. *)
procedure LoadDomSegment(aTable: TDomQTHTable; aSegment: TStringList;
                         const aFileName: string; aTopLevel: boolean);
var
   path: string;
begin
   aSegment.Insert(0, 'TEST COPY OF ' + UpperCase(aFileName) + ', INCLUDES REMOVED');
   path := GetTempFileName(GetTempDir, 'tr4wdom');
   try
      aSegment.SaveToFile(AnsiString(path));
      if not aTable.ReadDomQTHFile(path, not aTopLevel) then
         begin
         raise Exception.Create('the loader refused a segment of ' + aFileName + ': ' + path);
         end;
   finally
      SysUtils.DeleteFile(path);
   end;
   aSegment.Clear;
end;

(* aFileName (a name in the shipped dom folder, in any case) into aTable,
   as the loader would, its INCLUDEs followed as above. Answers the file's
   OWN INCLUDE FILE names, upper-cased, in its order, blank-separated. *)
function LoadShippedDomFollowingIncludes(aTable: TDomQTHTable;
                                         const aFileName: string;
                                         aTopLevel: boolean;
                                         aDepth: integer): string;
var
   path: string;
   included: string;
   lines: TStringList;
   segment: TStringList;
   firstSegment: boolean;
   i: integer;
begin
   Result := '';
   if aDepth > 8 then
      begin
      raise Exception.Create('INCLUDE FILE nests too deep at ' + aFileName);
      end;
   (* THE SAME FILE, WHATEVER CASE IT IS SPELLED IN: the .dom says P14.DOM,
      and on Linux the shipped file is p14.dom. *)
   path := ExistingDataFile(ShippedDomDir + aFileName);
   if not FileExists(path) then
      begin
      raise Exception.Create('a shipped .dom is missing, so the loader would queue its '
                             + '"could not find" warning: ' + path);
      end;
   lines := TStringList.Create;
   segment := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(path));
      firstSegment := aTopLevel;
      for i := 0 to lines.Count - 1 do
         begin
         included := DomIncludeName(lines[i]);
         if included = '' then
            begin
            segment.Add(lines[i]);
            end
         else
            begin
            LoadDomSegment(aTable, segment, aFileName, firstSegment);
            firstSegment := False;
            if Result <> '' then
               begin
               Result := Result + ' ';
               end;
            Result := Result + UpperCase(included);
            LoadShippedDomFollowingIncludes(aTable, included, False, aDepth + 1);
            end;
         end;
      LoadDomSegment(aTable, segment, aFileName, firstSegment);
   finally
      segment.Free;
      lines.Free;
   end;
end;

function MultiplierOf(aTable: TDomQTHTable; const aAlias: string): string;
var
   entry: TDomQTHEntry;
begin
   Result := '';
   if aTable.FindAlias(aAlias, entry) then
      begin
      Result := UpperCase(string(entry.Multiplier));
      end;
end;

function QTHOf(aTable: TDomQTHTable; const aAlias: string): string;
var
   entry: TDomQTHEntry;
begin
   Result := '';
   if aTable.FindAlias(aAlias, entry) then
      begin
      Result := UpperCase(string(entry.DomQTH));
      end;
end;

end.

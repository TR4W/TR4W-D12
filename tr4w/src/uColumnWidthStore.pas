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
unit uColumnWidthStore;
{$I tr4w.inc}

(*
  The column widths an operator dragged: the 'columns' section of
  settings\tr4w.json (issue 234).

      "columns": {
         "MainLog":         { "CALLSIGN": 96, "FREQ": 70 },
         "ExternalLoggers": { "Name": 210 }
      }

  PER USER, NOT PER CONTEST (NY4I) -- WITH ONE EXCEPTION, THE MAIN LOG. A width
  is how this operator likes to read a grid, so it lives beside the window
  layout rather than in a contest's database.

  THE MAIN LOG GRID IS KEPT PER CONTEST (NY4I, 2026-11-06), because which
  columns it shows depends on the contest. Its widths are the 'COLUMN WIDTH
  <token>' rows of the contest database's config table, written by
  uLogStore's close capture and read back by its open. In memory they are
  ContestColumnWidths, below: the SAME class, under the grid name
  CONTEST_LOG_COLUMNS_NAME, so the clamp, the 96-dpi rule and the token rule
  are this unit's and uLCLFormHelpers' for both homes. Only the backing store
  differs. The main log never writes the 'columns' section.

  KEYED BY NAME TWICE, NEVER BY POSITION. A grid is named by its owner, and a
  column by a language-neutral TOKEN -- ColumnCanonicalName for the log
  columns, a fixed constant for the others. Never a column index, because the
  columns a log shows change with the contest; never a caption, because a
  caption is translated.

  WIDTHS ARE AT 96 DPI. A width dragged on a 150% monitor and read back on a
  100% one would otherwise come back half again too wide. The conversion is
  the LCL's (ScaleFormTo96 / Scale96ToForm), done by uLCLFormHelpers at the
  grid; this unit only ever sees 96-dpi numbers.

  IT KEEPS WHAT IT DOES NOT RECOGNISE, as uWindowLayoutStore does: a store is
  loaded, overlaid entry by entry, and written back, so a grid or a column a
  newer TR4W knows about survives an older build saving over it.

  PURE RTL, so it is tested without the application. It does not know what a
  grid is. *)

interface

uses
   SysUtils,
   Classes,
   Generics.Collections,
   uJSON;

type
   TColumnWidthEntry = class(TObject)
   public
      Grid: string;
      Token: string;
      Width96: integer;
   end;

   TColumnWidthStore = class(TObject)
   private
      FEntries: TObjectList<TColumnWidthEntry>;
      function IndexOf(const aGrid, aToken: string): integer;
   public
      constructor Create;
      destructor Destroy; override;

      procedure Clear;

      function EntryCount: integer;
      function Entry(const aIndex: integer): TColumnWidthEntry;

      (* Replace-or-add. A blank grid or token, or a width that is not
        positive, is refused rather than stored: none can come from a real
        drag, and a zero width would hide the column with no way back. *)
      procedure SetWidth(const aGrid, aToken: string; const aWidth96: integer);

      (* False when absent, and aWidth96 is then untouched, so the caller keeps
        the default it computed. Case-insensitive on both names, so a
        hand-edited file cannot orphan an entry by its spelling. *)
      function TryGetWidth(const aGrid, aToken: string;
                           var aWidth96: integer): boolean;

      (* Every entry of aOther over this one -- the row-level overlay a save
        and a pending restore both need. *)
      procedure MergeFrom(const aOther: TColumnWidthStore);

      function ToJSON: TJSONObject;
      procedure FromJSON(const aObj: TJSONObject);
   end;

(* THE WIDTH A RESTORE APPLIES: the saved one, but never narrower than the
  header's own text, nor than the grid's minimum.

  The header floor is what keeps a translation readable. A width saved under
  English and read back under a language whose header is longer would
  otherwise cut the header off; the floor widens the column instead. *)
function ClampRestoredWidth(const aSaved, aHeaderWidth, aMinimum: integer): integer;

const
   (* THE MAIN LOG'S NAME IN ContestColumnWidths. On disk only as the meaning
     of the contest database's rows, which carry no grid name: a contest
     database holds the main log's widths and no other grid's. *)
   CONTEST_LOG_COLUMNS_NAME = 'MainLog';

   (* The config-table command a contest database stores a width under,
     followed by the column's token: 'COLUMN WIDTH CALLSIGN' = 108. The
     spelling every earlier build wrote, so an old log reads as it is. *)
   COLUMN_WIDTH_COMMAND_PREFIX = 'COLUMN WIDTH ';

(* THE OPEN CONTEST'S MAIN-LOG WIDTHS, at 96 dpi, under
  CONTEST_LOG_COLUMNS_NAME.

  Filled from the contest database's COLUMN WIDTH rows when the contest is
  opened (and from a .cfg's lines when one is imported); changed by a drag on
  the main log; written back into the database by the close capture; emptied
  when the log closes. One contest per process -- File > Open Log relaunches
  -- so it never carries one contest's widths into another.

  Created in initialization and freed in finalization, never lazily. Main
  thread only. *)
function ContestColumnWidths: TColumnWidthStore;

(* aCommand is a 'COLUMN WIDTH <token>' command: True, with the token after
  the prefix, trimmed. Case-insensitive on the prefix, like every command. *)
function IsColumnWidthCommand(const aCommand: string; out aToken: string): boolean;

implementation

var
   GContestColumnWidths: TColumnWidthStore = nil;

function ContestColumnWidths: TColumnWidthStore;
begin
   Result := GContestColumnWidths;
end;

function IsColumnWidthCommand(const aCommand: string; out aToken: string): boolean;
begin
   aToken := '';
   Result := (Length(aCommand) > Length(COLUMN_WIDTH_COMMAND_PREFIX)) and
             UnicodeSameText(Copy(aCommand, 1, Length(COLUMN_WIDTH_COMMAND_PREFIX)),
                             COLUMN_WIDTH_COMMAND_PREFIX);
   if Result then
      begin
      aToken := Trim(Copy(aCommand, Length(COLUMN_WIDTH_COMMAND_PREFIX) + 1, MaxInt));
      Result := aToken <> '';
      end;
end;

constructor TColumnWidthStore.Create;
begin
   inherited Create;
   FEntries := TObjectList<TColumnWidthEntry>.Create(True);
end;

destructor TColumnWidthStore.Destroy;
begin
   FEntries.Free;
   inherited Destroy;
end;

procedure TColumnWidthStore.Clear;
begin
   FEntries.Clear;
end;

function TColumnWidthStore.EntryCount: integer;
begin
   Result := FEntries.Count;
end;

function TColumnWidthStore.Entry(const aIndex: integer): TColumnWidthEntry;
begin
   if (aIndex < 0) or (aIndex >= FEntries.Count) then
      begin
      Result := nil;
      Exit;
      end;
   Result := FEntries[aIndex];
end;

function TColumnWidthStore.IndexOf(const aGrid, aToken: string): integer;
var
   i: integer;
begin
   Result := -1;
   (* UnicodeSameText, not SameText: SysUtils' plain name takes AnsiString,
     so every call would narrow these UnicodeStrings. *)
   for i := 0 to FEntries.Count - 1 do
      begin
      if UnicodeSameText(FEntries[i].Grid, aGrid) and
         UnicodeSameText(FEntries[i].Token, aToken) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure TColumnWidthStore.SetWidth(const aGrid, aToken: string;
                                     const aWidth96: integer);
var
   idx, i: integer;
   entry: TColumnWidthEntry;
begin
   if (Trim(aGrid) = '') or (Trim(aToken) = '') or (aWidth96 <= 0) then
      begin
      Exit;
      end;

   idx := IndexOf(aGrid, aToken);
   if idx >= 0 then
      begin
      entry := FEntries[idx];
      end
   else
      begin
      (* The caller's spelling on a new entry; an existing entry keeps the
        spelling on disk, so a hand-edited file is not rewritten under the
        operator on every save. A new token of a grid already held takes
        that grid's spelling, or ToJSON would write the grid twice. *)
      entry := TColumnWidthEntry.Create;
      entry.Grid  := aGrid;
      entry.Token := aToken;
      for i := 0 to FEntries.Count - 1 do
         begin
         if UnicodeSameText(FEntries[i].Grid, aGrid) then
            begin
            entry.Grid := FEntries[i].Grid;
            Break;
            end;
         end;
      FEntries.Add(entry);
      end;

   entry.Width96 := aWidth96;
end;

function TColumnWidthStore.TryGetWidth(const aGrid, aToken: string;
                                       var aWidth96: integer): boolean;
var
   idx: integer;
begin
   idx := IndexOf(aGrid, aToken);
   Result := idx >= 0;
   if Result then
      begin
      aWidth96 := FEntries[idx].Width96;
      end;
end;

procedure TColumnWidthStore.MergeFrom(const aOther: TColumnWidthStore);
var
   i: integer;
begin
   if aOther = nil then
      begin
      Exit;
      end;

   for i := 0 to aOther.EntryCount - 1 do
      begin
      SetWidth(aOther.Entry(i).Grid, aOther.Entry(i).Token,
               aOther.Entry(i).Width96);
      end;
end;

function TColumnWidthStore.ToJSON: TJSONObject;
var
   i: integer;
   grid: TJSONValue;
begin
   (* An OBJECT of objects, keyed by grid then by token, so the file reads as
     "MainLog": { "CALLSIGN": 96 } and needs no schema beside it -- the same
     choice the windows section made. *)
   Result := TJSONObject.Create;
   for i := 0 to FEntries.Count - 1 do
      begin
      grid := Result.FindValue(FEntries[i].Grid);
      if not (grid is TJSONObject) then
         begin
         grid := TJSONObject.Create;
         JSONSetSection(Result, FEntries[i].Grid, TJSONObject(grid));
         end;
      JSONSetSection(TJSONObject(grid), FEntries[i].Token,
                     TJSONNumber.Create(FEntries[i].Width96));
      end;
end;

procedure TColumnWidthStore.FromJSON(const aObj: TJSONObject);
var
   g, t: integer;
   value: TJSONValue;
   grid: TJSONObject;
   width: integer;
begin
   Clear;
   if aObj = nil then
      begin
      Exit;
      end;

   for g := 0 to aObj.Count - 1 do
      begin
      value := JSONPairValue(aObj, g);
      if not (value is TJSONObject) then
         begin
         (* A grid whose value is not an object is skipped: there is nothing in
           it to read, and guessing would invent widths. *)
         Continue;
         end;

      grid := TJSONObject(value);
      for t := 0 to grid.Count - 1 do
         begin
         (* Through the text form, so a hand-edited "96" reads like 96; a value
           that is not a whole number reads as 0 and SetWidth refuses it. *)
         width := StrToIntDef(AnsiString(Trim(JSONText(JSONPairValue(grid, t)))), 0);
         SetWidth(JSONPairName(aObj, g), JSONPairName(grid, t), width);
         end;
      end;
end;

function ClampRestoredWidth(const aSaved, aHeaderWidth, aMinimum: integer): integer;
begin
   Result := aSaved;
   if Result < aHeaderWidth then
      begin
      Result := aHeaderWidth;
      end;
   if Result < aMinimum then
      begin
      Result := aMinimum;
      end;
end;

initialization
   GContestColumnWidths := TColumnWidthStore.Create;

finalization
   FreeAndNil(GContestColumnWidths);

end.

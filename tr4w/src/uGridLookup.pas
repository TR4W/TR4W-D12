(*
 Copyright Thomas M. Schaefer, NY4I (c) 2020.
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

(* MAIDENHEAD GRID -> STATE(S), issue 52.

   DATA PROVENANCE AND LICENCE. The table in uGridStateTable.inc is GENERATED
   from vuccgrids.dat, the ARRL's VUCC grid list as shipped with TrustedQSL
   (version 1.6, updated 2026-03-27), by tools/grids/gen_grid_state_table.py.
   Regenerate with

      python -I tools/grids/gen_grid_state_table.py <path>\vuccgrids.dat

   which rewrites uGridStateTable.inc and uGridStateTableCount.inc (CRLF,
   deterministic; the first comment of the first names the source version).
   It replaced the table converted from WSJT-X's grid.dat (695 grids, which
   named some states wrongly and missed others). The notice also stands in
   docs/THIRD_PARTY_NOTICES.md.

   The data is copyright the American Radio Relay League and is redistributed
   under its licence (TrustedQSL's LICENSE.txt), reproduced here as it
   requires:

   Copyright (C) 2001-2020 American Radio Relay League, Inc. All rights
   reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   1. Any redistribution of source code must retain the above copyright
   notice, this list of conditions and the disclaimer shown in
   Paragraph 5 (below).

   2. Redistribution in binary form must reproduce the above copyright
   notice, this list of conditions and the disclaimer shown in
   Paragraph 5 (below) in the documentation and/or other materials
   provided with the distribution.

   3. Products derived from or including this software may not use
   "Logbook of the World" or "LoTW" or any other American Radio Relay
   League, Incorporated trademarks or servicemarks in their names
   without prior written permission of the ARRL. See Paragraph 6
   (below) for contact information.

   4. Use of this software does not imply endorsement by ARRL of
   products derived from or including this software and vendors may not
   claim such endorsement.

   5. Disclaimer: This software is provided "as-is" without
   representation, guarantee or warranty of any kind, either express or
   implied, including but not limited to the implied warranties of
   merchantability or of fitness for a particular purpose. The entire
   risk as to the quality and performance of the software is solely
   with you. Should the software prove defective, you (and not the
   American Radio Relay League, its officers, directors, employees or
   agents) assume the entire cost of all necessary servicing, repair or
   correction. In no event will ARRL be liable to you or to any third
   party for any damages, whether direct or indirect, including lost
   profits, lost savings, or other incidental or consequential damages
   arising out of the use or inability to use such software, regardless
   of whether ARRL has been advised of the possibility of such damages.

   6. Contact information:

   American Radio Relay League, Inc.
   Attn: Logbook of the World Manager
   225 Main St
   Newington, CT 06111
   voice: 860-594-0200
   fax: 860-594-0259
   email: logbook@arrl.org
   Worldwide Web: www.arrl.org

   This software consists of voluntary contributions made by many
   individuals on behalf of the ARRL. More information on the "Logbook
   of The World" project and the ARRL is available from the ARRL Web
   site at www.arrl.org.

   WHAT THE DATA SAYS. Each row of the source is (ADIF DXCC entity, primary
   administrative subdivision, four-character grid). Subdivisions exist in the
   file only for entity 291 (USA: the 48 states and DC), 6 (Alaska), 110
   (Hawaii) and 1 (Canada). The table keeps every grid that has one, as
   'CN88=291:WA;1:BC': per entity, the subdivisions the grid reaches. Canada's
   old codes are written as ADIF spells them: NF is NL, PQ is QC.

   EDGES. The file lists every subdivision a grid TOUCHES, an edge included
   (DM37 is AZ and UT although Arizona only reaches its southern edge). That
   is the safe direction for the rule below: such a grid is ambiguous, so a
   state is not written for it, and a wrong state is never written. The cost
   is that some grids that are in practice one state name none.

   THE RULE, PER ENTITY (NY4I, issue 52, and 2026-11-25): a grid names a state
   only when, among the subdivisions of ONE entity in that grid, there is
   exactly one. StateOfGridForEntity asks with the entity of the station's
   call: CN88 is WA for a US call and BC for a Canadian one, CN81 is CA and OR
   (ambiguous) for a US call, and a call of any other entity has no list so a
   border grid names nothing for it. The order of the states in the file is
   not "mostly the first": an ambiguous grid infers NO state.

   StateOfGrid has no call, hence no entity, and is the CONSERVATIVE form the
   WSJT-X path uses: a state only when the grid has exactly one subdivision
   across ALL entities (CN88 is ambiguous there). A grid the table does not
   hold is UNKNOWN; so is a grid whose only entities have no subdivisions.
   A 6-character grid is looked up by its first four characters, in any
   case. The candidates of an ambiguous grid are offered as text,
   'possible states for EN61 are IL, IN and MI'.

   This unit has no dependencies on the rest of the program, so it is tested
   directly (uTestGridLookup). Who may call it for a QSO is the WSJT-X
   logging path's decision, in uWSJTX, and the ADIF export's, in uADIF. *)

unit uGridLookup;
{$I tr4w.inc}

interface

uses Classes, SysUtils;

const
   (* Generated, with the table. uTestGridLookup pins the loaded total. *)
   {$I uGridStateTableCount.inc}

   (* ADIF DXCC numbers of the four entities that have subdivisions. *)
   GRID_ENTITY_CANADA = 1;
   GRID_ENTITY_ALASKA = 6;
   GRID_ENTITY_HAWAII = 110;
   GRID_ENTITY_USA = 291;

type
   TGridStateKind = (gskUnknown, gskUnique, gskAmbiguous);

   TGridLookup = class(TObject)
   private
      (* Sorted by the four-character grid; Objects[] is the grid's own
         TStringList of 'entity:state' items, in the table's order. *)
      FGrids: TStringList;
      function GetGridIndex(const aGrid: string): integer;
   public
      constructor Create;
      destructor Destroy; override;
      procedure AddStateToGrid(const aGrid: string; aEntity: integer;
                               const aState: string);
      (* Appends the grid's states (every entity's) to aStates;
         False (and nothing appended) when the grid is unknown or not a grid. *)
      function ReturnStatesForGrid(const aGrid: string; aStates: TStrings): boolean;
      (* The conservative, entity-less answer. gskUnique: aState is the state.
         Otherwise aState is ''. *)
      function StateKindOfGrid(const aGrid: string; out aState: string): TGridStateKind;
      (* The per-entity answer. gskUnknown when the grid is not in the table
         or the entity has no subdivision in it; gskUnique when it has exactly
         one; gskAmbiguous when several. *)
      function StateKindOfGridForEntity(const aGrid: string; aEntity: integer;
                                        out aState: string): TGridStateKind;
      function GridCount: integer;
   end;

(* The grid as the table keys it: upper-case, four characters, A-R A-R 0-9
   0-9. A 4, 6 or 8 character locator is accepted; anything else (2 characters,
   5, 7, text) is not a grid and answers False. *)
function NormalizeGridForStateLookup(const aGrid: string; out aKey: string): boolean;

(* The one table, built on first use. Main-thread callers only. *)
function GridLookupShared: TGridLookup;

(* The pure answers the logging path uses. *)
function StateOfGrid(const aGrid: string; out aState: string): TGridStateKind;
function StateOfGridForEntity(const aGrid: string; aEntity: integer;
                              out aState: string): TGridStateKind;
function PossibleStatesComment(const aGrid: string): string;

implementation

const
   (* 'GGNN=E:SS' or 'GGNN=E:SS,SS;E:SS': GENERATED, one grid a line. The count
      is a compile-time check of the array bounds. *)
   GRID_STATE_TABLE: array[0..GRID_STATE_TABLE_COUNT - 1] of string = (
      {$I uGridStateTable.inc}
   );

var
   GSharedGridLookup: TGridLookup;

(* One 'entity:state' item of a grid's list. *)
function GridItem(aEntity: integer; const aState: string): string;
begin
   Result := IntToStr(aEntity) + ':' + aState;
end;

function GridItemEntity(const aItem: string): integer;
begin
   Result := StrToIntDef(AnsiString(Copy(aItem, 1, Pos(':', aItem) - 1)), 0);
end;

function GridItemState(const aItem: string): string;
begin
   Result := Copy(aItem, Pos(':', aItem) + 1, Length(aItem));
end;

function NormalizeGridForStateLookup(const aGrid: string; out aKey: string): boolean;
var
   text: string;
begin
   Result := False;
   aKey := '';
   text := UpperCase(Trim(aGrid));
   if not (Length(text) in [4, 6, 8]) then
      begin
      Exit;
      end;
   if (text[1] < 'A') or (text[1] > 'R') or
      (text[2] < 'A') or (text[2] > 'R') or
      (text[3] < '0') or (text[3] > '9') or
      (text[4] < '0') or (text[4] > '9') then
      begin
      Exit;
      end;
   aKey := Copy(text, 1, 4);
   Result := True;
end;

constructor TGridLookup.Create;
var
   i: integer;
   entry: string;
   rest: string;
   block: string;
   states: string;
   grid: string;
   entity: integer;
   semiAt: integer;
   commaAt: integer;
   colonAt: integer;
begin
   inherited Create;
   FGrids := TStringList.Create;
   FGrids.CaseSensitive := True;
   FGrids.Sorted := True;
   for i := Low(GRID_STATE_TABLE) to High(GRID_STATE_TABLE) do
      begin
      entry := GRID_STATE_TABLE[i];
      grid := Copy(entry, 1, 4);
      rest := Copy(entry, 6, Length(entry));
      while rest <> '' do
         begin
         semiAt := Pos(';', rest);
         if semiAt = 0 then
            begin
            block := rest;
            rest := '';
            end
         else
            begin
            block := Copy(rest, 1, semiAt - 1);
            rest := Copy(rest, semiAt + 1, Length(rest));
            end;
         colonAt := Pos(':', block);
         entity := StrToIntDef(AnsiString(Copy(block, 1, colonAt - 1)), 0);
         states := Copy(block, colonAt + 1, Length(block));
         while states <> '' do
            begin
            commaAt := Pos(',', states);
            if commaAt = 0 then
               begin
               AddStateToGrid(grid, entity, states);
               states := '';
               end
            else
               begin
               AddStateToGrid(grid, entity, Copy(states, 1, commaAt - 1));
               states := Copy(states, commaAt + 1, Length(states));
               end;
            end;
         end;
      end;
end;

destructor TGridLookup.Destroy;
var
   i: integer;
begin
   if FGrids <> nil then
      begin
      for i := 0 to FGrids.Count - 1 do
         begin
         FGrids.Objects[i].Free;
         end;
      FGrids.Free;
      end;
   inherited Destroy;
end;

function TGridLookup.GetGridIndex(const aGrid: string): integer;
var
   key: string;
begin
   if NormalizeGridForStateLookup(aGrid, key) then
      begin
      Result := FGrids.IndexOf(AnsiString(key));
      end
   else
      begin
      Result := -1;
      end;
end;

procedure TGridLookup.AddStateToGrid(const aGrid: string; aEntity: integer;
                                     const aState: string);
var
   i: integer;
   items: TStringList;
   key: string;
   item: string;
begin
   if not NormalizeGridForStateLookup(aGrid, key) then
      begin
      Exit;
      end;
   item := GridItem(aEntity, aState);
   i := FGrids.IndexOf(AnsiString(key));
   if i < 0 then
      begin
      items := TStringList.Create;
      items.Add(AnsiString(item));
      FGrids.AddObject(AnsiString(key), items);
      end
   else
      begin
      items := TStringList(FGrids.Objects[i]);
      if items.IndexOf(AnsiString(item)) < 0 then
         begin
         items.Add(AnsiString(item));
         end;
      end;
end;

function TGridLookup.ReturnStatesForGrid(const aGrid: string; aStates: TStrings): boolean;
var
   i: integer;
   j: integer;
   items: TStringList;
begin
   j := GetGridIndex(aGrid);
   Result := j >= 0;
   if not Result then
      begin
      Exit;
      end;
   items := TStringList(FGrids.Objects[j]);
   (* A state code belongs to one entity, so no state repeats across them. *)
   for i := 0 to items.Count - 1 do
      begin
      aStates.Add(AnsiString(GridItemState(items[i])));
      end;
end;

function TGridLookup.StateKindOfGrid(const aGrid: string; out aState: string): TGridStateKind;
var
   i: integer;
   items: TStringList;
begin
   aState := '';
   i := GetGridIndex(aGrid);
   if i < 0 then
      begin
      Result := gskUnknown;
      Exit;
      end;
   items := TStringList(FGrids.Objects[i]);
   if items.Count = 1 then
      begin
      aState := GridItemState(items[0]);
      Result := gskUnique;
      end
   else
      begin
      Result := gskAmbiguous;
      end;
end;

function TGridLookup.StateKindOfGridForEntity(const aGrid: string; aEntity: integer;
                                              out aState: string): TGridStateKind;
var
   i: integer;
   j: integer;
   items: TStringList;
   found: integer;
begin
   aState := '';
   Result := gskUnknown;
   i := GetGridIndex(aGrid);
   if i < 0 then
      begin
      Exit;
      end;
   items := TStringList(FGrids.Objects[i]);
   found := 0;
   for j := 0 to items.Count - 1 do
      begin
      if GridItemEntity(items[j]) = aEntity then
         begin
         Inc(found);
         aState := GridItemState(items[j]);
         end;
      end;
   case found of
      0:
         begin
         Result := gskUnknown;
         end;
      1:
         begin
         Result := gskUnique;
         end;
   else
      begin
      aState := '';
      Result := gskAmbiguous;
      end;
   end;
end;

function TGridLookup.GridCount: integer;
begin
   Result := FGrids.Count;
end;

function GridLookupShared: TGridLookup;
begin
   if GSharedGridLookup = nil then
      begin
      GSharedGridLookup := TGridLookup.Create;
      end;
   Result := GSharedGridLookup;
end;

function StateOfGrid(const aGrid: string; out aState: string): TGridStateKind;
begin
   Result := GridLookupShared.StateKindOfGrid(aGrid, aState);
end;

function StateOfGridForEntity(const aGrid: string; aEntity: integer;
                              out aState: string): TGridStateKind;
begin
   Result := GridLookupShared.StateKindOfGridForEntity(aGrid, aEntity, aState);
end;

function PossibleStatesComment(const aGrid: string): string;
var
   states: TStringList;
   key: string;
   i: integer;
begin
   Result := '';
   if not NormalizeGridForStateLookup(aGrid, key) then
      begin
      Exit;
      end;
   states := TStringList.Create;
   try
      if (GridLookupShared.ReturnStatesForGrid(key, states)) and
         (states.Count > 1) then
         begin
         Result := 'possible states for ' + key + ' are ';
         for i := 0 to states.Count - 1 do
            begin
            if i = 0 then
               begin
               Result := Result + states[i];
               end
            else if i = states.Count - 1 then
               begin
               Result := Result + ' and ' + states[i];
               end
            else
               begin
               Result := Result + ', ' + states[i];
               end;
            end;
         end;
   finally
      states.Free;
   end;
end;

initialization
   GSharedGridLookup := nil;

finalization
   FreeAndNil(GSharedGridLookup);

end.

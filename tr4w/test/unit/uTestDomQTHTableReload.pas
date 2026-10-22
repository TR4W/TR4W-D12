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

(* THE DOMESTIC TABLE (LOGDOM.TDomQTHTable) -- 2026-10-16.

  LOADING A .dom INTO A TABLE THAT ALREADY HOLDS ONE. The table was 36
  hand-built linked lists, and the loop that emptied them before a top-level
  load (D7's, line for line) stepped to the next record and THEN read its
  NextRecord -- a read through nil at the end of every list. This test was
  run once against that loop and failed with EAccessViolation on the second
  load; the lists are gone (the table owns a dictionary), so the crash has
  nothing left to happen in, and this pins that a reload REPLACES the table.

  AND THE LOOKUP RULES THE DICTIONARY HAS TO KEEP (see the class's
  declaration): the first of two equal aliases wins, an alias is stored
  truncated to ten characters, and one starting with anything but 0-9 or
  A-Z, or an empty one, is not stored.

  A PRIVATE TABLE, never the live DomQTHTable: ReadDomQTHFile fills the
  table it is called on. The multipliers the files name still go to the
  sheet's domestic list (EnumDOMFILE's own write), so they are taken out. *)
unit uTestDomQTHTableReload;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TDomQTHTableReloadTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ASecondLoadReplacesTheFirst;
      procedure Test_TheStoreKeepsTheListsRules;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   uMults,
   LogDom;

const
   MULT_Z = 'ZZRLD';
   MULT_Q = 'QQRLD';
   MULT_N = 'NNRLD';

function WriteDomFile(const aName: string; const aLines: array of string): string;
var
   lines: TStringList;
   i: integer;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + aName;
   lines := TStringList.Create;
   try
      for i := Low(aLines) to High(aLines) do
         begin
         lines.Add(AnsiString(aLines[i]));
         end;
      lines.SaveToFile(AnsiString(Result));
   finally
      lines.Free;
   end;
end;

(* Takes a multiplier a file named out of the sheet's domestic list, unless
   it was there before. *)
procedure RemoveTestMultiplier(const aMult: string; aWasThere: boolean);
var
   index: integer;
begin
   if aWasThere then
      begin
      Exit;
      end;
   if mo.DomList.FindMult(aMult, index) then
      begin
      mo.DomList.Delete(index);
      end;
end;

procedure TDomQTHTableReloadTests.Test_ASecondLoadReplacesTheFirst;
var
   table: TDomQTHTable;
   first, second: string;
   hadZ, hadQ, hadN: boolean;
   index: integer;
   raisedText: string;
   loaded: boolean;
begin
   BeginTest('Test_ASecondLoadReplacesTheFirst');

   hadZ := mo.DomList.FindMult(MULT_Z, index);
   hadQ := mo.DomList.FindMult(MULT_Q, index);
   hadN := mo.DomList.FindMult(MULT_N, index);
   (* Two records under Z and one under Q: under the lists, a chain to step
      along and an end to stop at. *)
   first := WriteDomFile('tr4w_dom_reload_1.dom',
                         [MULT_Z + ' = ZZRA, ZZRB', MULT_Q + ' = QQRA']);
   second := WriteDomFile('tr4w_dom_reload_2.dom', [MULT_N + ' = NNRA']);
   table := TDomQTHTable.Create;
   try
      CheckTrue(table.ReadDomQTHFile(first, False), 'the file loads into an empty table');
      CheckTrue(table.HasPrefix('ZZRA') and table.HasPrefix('ZZRB') and
                table.HasPrefix('QQRA'), 'and holds its three aliases');

      (* THE CASE THAT READ THROUGH NIL: the same file into the full table. *)
      raisedText := '';
      loaded := False;
      try
         loaded := table.ReadDomQTHFile(first, False);
      except
         on E: Exception do
            begin
            raisedText := E.ClassName + ': ' + E.Message;
            end;
      end;
      CheckEquals('', raisedText, 'a second load into a populated table raises nothing');
      CheckTrue(loaded, 'and loads');
      CheckTrue(table.HasPrefix('ZZRA') and table.HasPrefix('ZZRB') and
                table.HasPrefix('QQRA'), 'and holds the same three aliases');

      (* A DIFFERENT file REPLACES the table -- nothing of the first is left. *)
      CheckTrue(table.ReadDomQTHFile(second, False), 'another file loads over it');
      CheckTrue(table.HasPrefix('NNRA'), 'and its alias is there');
      CheckFalse(table.HasPrefix('ZZRA') or table.HasPrefix('ZZRB') or
                 table.HasPrefix('QQRA'), 'and none of the first file''s is');
   finally
      table.Free;
      DeleteFile(first);
      DeleteFile(second);
      RemoveTestMultiplier(MULT_Z, hadZ);
      RemoveTestMultiplier(MULT_Q, hadQ);
      RemoveTestMultiplier(MULT_N, hadN);
   end;
end;

procedure TDomQTHTableReloadTests.Test_TheStoreKeepsTheListsRules;
var
   table: TDomQTHTable;
   entry: TDomQTHEntry;
begin
   BeginTest('Test_TheStoreKeepsTheListsRules');

   table := TDomQTHTable.Create;
   try
      (* THE FIRST OF TWO EQUAL ALIASES WINS -- the walk stopped at it. *)
      table.AddNewPrefixRecord('ABC', 'FIRST', 'M1');
      table.AddNewPrefixRecord('ABC', 'SECOND', 'M2');
      CheckTrue(table.FindAlias('ABC', entry), 'the alias is found');
      CheckEquals('FIRST', string(entry.DomQTH), 'and answers with the first record');
      CheckEquals('M1', string(entry.Multiplier), 'and its multiplier');

      (* TRUNCATED TO TEN, as string[10] stored it: the eleven-character
         alias is found by its first ten and not by itself, and so is a
         long name. *)
      table.AddNewPrefixRecord('ABCDEFGHIJK', 'ABCDEFGHIJKLMN', 'M3');
      CheckTrue(table.FindAlias('ABCDEFGHIJ', entry), 'a long alias is stored as its first ten');
      CheckEquals('ABCDEFGHIJ', string(entry.DomQTH), 'and its name is truncated too');
      CheckFalse(table.HasPrefix('ABCDEFGHIJK'), 'and it is not found as itself');

      (* EXACT, not a prefix match and not case-folded. *)
      CheckFalse(table.HasPrefix('AB'), 'a shorter text is not an alias');
      CheckFalse(table.HasPrefix('ABCD'), 'nor a longer one');

      (* ONLY 0-9 AND A-Z BEGIN A STORED ALIAS; an empty one is not stored. *)
      table.AddNewPrefixRecord('9XY', 'NINE', 'M4');
      CheckTrue(table.HasPrefix('9XY'), 'a digit begins an alias');
      table.AddNewPrefixRecord('#XY', 'HASH', 'M5');
      CheckFalse(table.HasPrefix('#XY'), 'a # does not');
      table.AddNewPrefixRecord('abc', 'LOWER', 'M6');
      CheckFalse(table.HasPrefix('abc'), 'nor a lowercase letter');
      table.AddNewPrefixRecord('', 'EMPTY', 'M7');
      CheckFalse(table.HasPrefix(''), 'and an empty alias is not stored');
   finally
      table.Free;
   end;
end;

procedure TDomQTHTableReloadTests.RunAllTests;
begin
   Test_ASecondLoadReplacesTheFirst;
   Test_TheStoreKeepsTheListsRules;
end;

end.

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

(* SHIPPED .dom FILES CHECKED AGAINST THEIR SPONSOR'S LIST -- 2026-10-19.

  Leads from the N1MM UDC cross-walk (docs/UDC_CROSSWALK_FINDINGS.md), each
  value confirmed against the sponsor's own rules before the file changed.

  LABRE DX (brazil.dom). The 2026 rules, section V, Table 1, list 28
  codes: 26 states, the Federal District and Fernando de Noronha (FN); the
  note under it and section VI.C add the official LABRE stations, whose
  exchange is HQ and which count as a multiplier. The file had 26 of them --
  no GO, FN or HQ -- so a station sending one was refused as an improper
  domestic QTH.
  https://www.labre.org.br/contest/wp-content/uploads/2026/07/Regulamento-Contest-LABRE-DX-2026-Ingles-v3.pdf
  AND THE CODE IS THE MULTIPLIER (NY4I, 2026-10-19: "The codes are the
  multipliers. Rio Grande is RN (Norte) and RS (Sul)."). The file's left
  side -- the multiplier -- was the state's NAME, and the table and the
  sheet keep ten characters, so Rio Grande do Norte and do Sul were one
  multiplier ("Rio Grande") and Mato Grosso and do Sul another: 26 lines,
  24 multipliers. Each line is `CODE = CODE, ^Name` now; the name is the
  remaining-multipliers window's display name (EnumDOMFILE -> AltName).

  EU DX (eudx.dom). The rules' point 7 lists the regions; Belgium's
  eleventh is BE11, where the file said BE011. The file also ended in 26
  ` = ` lines and `eudx = eudx`, `Page = Page`. EnumDOMFILE takes every line
  holding `=` and adds its left side to the sheet's domestic list, so those
  put an EMPTY multiplier, `eudx` and `Page` there, and `EUDX` and `PAGE`
  were accepted exchanges -- and since TContestEUDX scores a station as in
  the EU when its exchange matched the file, either one scored 10 points.
  DK06 ("Overseas Countries and Territories", in the 2022-2025 lists) is
  not in the 2026 list, which gives Denmark DK01-DK05; it is removed.
  https://www.eudx-contest.com/rules/

  A PRIVATE TABLE AND A PRIVATE SHEET: ReadDomQTHFile fills the table it is
  called on, and EnumDOMFILE writes the multipliers to `mo.DomList`, so the
  global sheet is swapped for a fresh one and put back. *)
unit uTestShippedDomLists;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TShippedDomListsTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_LABREListIsTheSponsorsTable;
      procedure Test_EUDXListHoldsOnlyRegions;
   end;

implementation

uses
   SysUtils,
   uMults,
   LogDom;

function ShippedDom(const aName: string): string;
begin
   Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
             PathDelim + 'target' + PathDelim + 'dom' + PathDelim + aName;
end;

(* THE REGION SHAPE THE EUDX RULES USE: two letters, two digits. *)
function IsEUDXRegionCode(const s: string): boolean;
begin
   Result := (Length(s) = 4)            and
             (s[1] in ['A'..'Z'])       and
             (s[2] in ['A'..'Z'])       and
             (s[3] in ['0'..'9'])       and
             (s[4] in ['0'..'9']);
end;

(* THE MULTIPLIER aCode RESOLVES TO, or '' when it is not an alias. *)
function MultiplierOf(aTable: TDomQTHTable; const aCode: string): string;
var
   entry: TDomQTHEntry;
begin
   Result := '';
   if aTable.FindAlias(aCode, entry) then
      begin
      Result := string(entry.Multiplier);
      end;
end;

procedure TShippedDomListsTests.Test_LABREListIsTheSponsorsTable;
const
   (* Table 1 of the 2026 rules, in its order, then HQ. *)
   SPONSOR_CODES: array[0..28] of string = (
      'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'FN', 'GO',
      'MA', 'MT', 'MS', 'MG', 'PA', 'PB', 'PE', 'PI', 'PR', 'RJ',
      'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO', 'HQ');
var
   table: TDomQTHTable;
   savedSheet: TMultsObject;
   savedCounties: boolean;
   entry: TDomQTHEntry;
   index: integer;
   i: integer;
begin
   BeginTest('Test_LABREListIsTheSponsorsTable');

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      CheckTrue(table.ReadDomQTHFile(ShippedDom('brazil.dom'), False), 'brazil.dom loads');

      (* EVERY CODE IS AN ACCEPTED EXCHANGE AND IS ITS OWN MULTIPLIER, on
         the sheet's domestic list. *)
      for i := Low(SPONSOR_CODES) to High(SPONSOR_CODES) do
         begin
         CheckTrue(table.FindAlias(SPONSOR_CODES[i], entry),
                   SPONSOR_CODES[i] + ' is an accepted exchange');
         if table.FindAlias(SPONSOR_CODES[i], entry) then
            begin
            CheckEquals(SPONSOR_CODES[i], string(entry.Multiplier),
                        SPONSOR_CODES[i] + '''s multiplier is the code');
            end;
         CheckTrue(mo.DomList.FindMult(SPONSOR_CODES[i], index),
                   SPONSOR_CODES[i] + ' is on the sheet''s domestic list');
         end;

      (* 29 DISTINCT MULTIPLIERS -- nothing collapses into another, and the
         list holds nothing else. *)
      CheckEquals(Length(SPONSOR_CODES), mo.DomList.Count,
                  'the domestic list holds exactly the 29 codes');

      (* THE PAIRS THAT USED TO COLLAPSE, named. *)
      CheckFalse(MultiplierOf(table, 'RN') = MultiplierOf(table, 'RS'),
                 'Rio Grande do Norte and do Sul are separate multipliers');
      CheckFalse(MultiplierOf(table, 'MT') = MultiplierOf(table, 'MS'),
                 'Mato Grosso and Mato Grosso do Sul are separate multipliers');

      (* THE NAME IS THE DISPLAY NAME (the loader upper-cases it). *)
      CheckTrue(mo.DomList.FindMult('RN', index), 'RN is on the list');
      if mo.DomList.FindMult('RN', index) then
         begin
         CheckEquals('RIO GRANDE DO NORTE', string(mo.DomList.AltName[index]),
                     'and shows as Rio Grande do Norte');
         end;
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

procedure TShippedDomListsTests.Test_EUDXListHoldsOnlyRegions;
var
   table: TDomQTHTable;
   savedSheet: TMultsObject;
   savedCounties: boolean;
   entry: TDomQTHEntry;
   index: integer;
   i: integer;
   badMults: string;
begin
   BeginTest('Test_EUDXListHoldsOnlyRegions');

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      CheckTrue(table.ReadDomQTHFile(ShippedDom('eudx.dom'), False), 'eudx.dom loads');

      (* BELGIUM'S ELEVENTH REGION IS BE11 (East Flanders). *)
      CheckTrue(table.FindAlias('BE11', entry), 'BE11 is an accepted exchange');
      CheckFalse(table.FindAlias('BE011', entry), 'BE011 is not');

      (* THE NON-REGION LINES ARE GONE: nothing accepts EUDX or PAGE ... *)
      CheckFalse(table.FindAlias('EUDX', entry), 'EUDX is not an accepted exchange');
      CheckFalse(table.FindAlias('PAGE', entry), 'PAGE is not an accepted exchange');

      (* ... and nothing but a region is a multiplier -- no empty one, no
         eudx, no Page. *)
      CheckFalse(mo.DomList.FindMult('', index), 'no empty multiplier');
      CheckFalse(mo.DomList.FindMult('eudx', index), 'no eudx multiplier');
      CheckFalse(mo.DomList.FindMult('Page', index), 'no Page multiplier');
      badMults := '';
      for i := 0 to mo.DomList.Count - 1 do
         begin
         if not IsEUDXRegionCode(mo.DomList.Get(i)) then
            begin
            badMults := badMults + '[' + mo.DomList.Get(i) + ']';
            end;
         end;
      CheckEquals('', badMults, 'every multiplier is a two-letter, two-digit region');
      CheckTrue(mo.DomList.Count > 0, 'and there are regions');

      (* DK06 LEFT THE LIST IN 2026 (the rules list DK01-DK05; NY4I
         2026-10-19), and the list is the sponsor's 2026 list, 275 regions. *)
      CheckFalse(table.FindAlias('DK06', entry), 'DK06 is not an accepted exchange');
      CheckFalse(mo.DomList.FindMult('DK06', index), 'and is not a multiplier');
      CheckTrue(table.FindAlias('DK05', entry), 'DK05 still is');
      CheckEquals(275, mo.DomList.Count, 'the sponsor''s 2026 list holds 275 regions');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

procedure TShippedDomListsTests.RunAllTests;
begin
   Test_LABREListIsTheSponsorsTable;
   Test_EUDXListHoldsOnlyRegions;
end;

end.

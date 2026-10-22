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

(* THE CTY ENTITY -> ADIF DXCC TABLE, HELD TO THE SHIPPED cty.dat (Q62).

  uDXCCEntities is generated from the country-files.com CSV; CTY.DAT itself
  carries no DXCC number. The table is only worth anything if it names EVERY
  entity the shipped country file does and no other, so this loads
  tr4w\target\cty.dat and checks both directions. A cty.dat replaced without
  tools/dxcc/gen_dxcc_entities.py being run again fails HERE, by name, rather
  than as a quietly missing DXCC tag in somebody's export.

  The subdivision question (uADIF.IsADIFPrimarySubdivisionOfDXCC) was
  uADIF.IsADIFPrimarySubdivision's body before Q62 and is pinned through it by
  uTestContestExport; the DXCC form is pinned here. *)
unit uTestDXCCEntities;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TDXCCEntitiesTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure EnsureCtyLoaded;
      procedure Test_EveryShippedEntityHasACode;
      procedure Test_TheTableHoldsNoEntityTheShippedFileLacks;
      procedure Test_CallsignsResolveToTheirDXCC;
      procedure Test_AnUnknownEntityIsZero;
      procedure Test_SubdivisionByDXCC;
   end;

implementation

uses
   SysUtils,
   uCTYDAT,
   uDXCCEntities,
   uADIF;

procedure TDXCCEntitiesTests.EnsureCtyLoaded;
var
   path: string;
begin
   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
           PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(FileExists(path), 'cty.dat present at ' + path);
   CheckTrue(ctyLoadInCountryFile(path, False, False, {ReplaceTable} True),
             'ctyLoadInCountryFile succeeded');
end;

procedure TDXCCEntitiesTests.Test_EveryShippedEntityHasACode;
var
   i: integer;
   id: string;
begin
   BeginTest('Test_EveryShippedEntityHasACode');
   EnsureCtyLoaded;
   for i := 0 to ctyGetTotalCountries - 1 do
      begin
      id := Trim(ctyGetCountryIdByIndex(i));
      CheckTrue(ADIFDXCCOfCTYEntity(id) > 0,
                'cty.dat entity "' + id + '" has an ADIF DXCC code');
      end;
end;

procedure TDXCCEntitiesTests.Test_TheTableHoldsNoEntityTheShippedFileLacks;
var
   i, j: integer;
   found: boolean;
begin
   BeginTest('Test_TheTableHoldsNoEntityTheShippedFileLacks');
   EnsureCtyLoaded;
   CheckEquals(ctyGetTotalCountries, DXCCEntityCount,
               'one table row per cty.dat entity');
   for i := 0 to DXCCEntityCount - 1 do
      begin
      found := False;
      for j := 0 to ctyGetTotalCountries - 1 do
         begin
         if Trim(ctyGetCountryIdByIndex(j)) = DXCCEntityPrefixAt(i) then
            begin
            found := True;
            Break;
            end;
         end;
      CheckTrue(found, 'table row "' + DXCCEntityPrefixAt(i) + '" is in cty.dat');
      end;
end;

(* THE PATH THE POTA EXPORT TAKES: callsign -> CTY entity -> DXCC. *)
procedure TDXCCEntitiesTests.Test_CallsignsResolveToTheirDXCC;

   procedure CheckCall(const aCall: string; aExpected: integer);
   begin
      CheckEquals(aExpected, ADIFDXCCOfCTYEntity(Trim(ctyGetCountryID(aCall))),
                  aCall + ' DXCC');
   end;

begin
   BeginTest('Test_CallsignsResolveToTheirDXCC');
   EnsureCtyLoaded;
   CheckCall('W1AW', 291);
   CheckCall('VE3ABC', 1);
   CheckCall('KL7ABC', 6);
   CheckCall('KH6ABC', 110);
   CheckCall('DL1ABC', 230);
   CheckCall('G3ABC', 223);
   CheckCall('GM3ABC', 279);
   CheckCall('JA1ABC', 339);
   CheckCall('VK2ABC', 150);
   CheckCall('XE1ABC', 50);
end;

procedure TDXCCEntitiesTests.Test_AnUnknownEntityIsZero;
begin
   BeginTest('Test_AnUnknownEntityIsZero');
   CheckEquals(0, ADIFDXCCOfCTYEntity(''), 'empty');
   CheckEquals(0, ADIFDXCCOfCTYEntity('QQ9'), 'not an entity');
   CheckEquals(0, ADIFDXCCOfCTYEntity('k'), 'case-sensitive, as cty.dat spells it');
end;

procedure TDXCCEntitiesTests.Test_SubdivisionByDXCC;
begin
   BeginTest('Test_SubdivisionByDXCC');
   CheckTrue(IsADIFPrimarySubdivisionOfDXCC(291, 'GA'), 'a state of the USA');
   CheckTrue(IsADIFPrimarySubdivisionOfDXCC(291, 'DC'), 'DC');
   CheckFalse(IsADIFPrimarySubdivisionOfDXCC(291, 'AK'), 'Alaska is its own entity');
   CheckFalse(IsADIFPrimarySubdivisionOfDXCC(291, 'HI'), 'Hawaii is its own entity');
   CheckTrue(IsADIFPrimarySubdivisionOfDXCC(6, 'AK'), 'Alaska');
   CheckTrue(IsADIFPrimarySubdivisionOfDXCC(110, 'HI'), 'Hawaii');
   CheckTrue(IsADIFPrimarySubdivisionOfDXCC(1, 'BC'), 'a province');
   CheckFalse(IsADIFPrimarySubdivisionOfDXCC(1, 'GA'), 'a state is not a province');
   CheckFalse(IsADIFPrimarySubdivisionOfDXCC(223, 'ENG'), 'no list for England');
   CheckFalse(IsADIFPrimarySubdivisionOfDXCC(0, 'GA'), 'no entity');
   (* The CTY-keyed form is the same answer through the table. *)
   CheckTrue(IsADIFPrimarySubdivision('K', 'GA'), 'K, GA');
   CheckTrue(IsADIFPrimarySubdivision('VE', 'ON'), 'VE, ON');
   CheckFalse(IsADIFPrimarySubdivision('DL', 'ON'), 'Germany has none');
end;

procedure TDXCCEntitiesTests.RunAllTests;
begin
   Test_EveryShippedEntityHasACode;
   Test_TheTableHoldsNoEntityTheShippedFileLacks;
   Test_CallsignsResolveToTheirDXCC;
   Test_AnUnknownEntityIsZero;
   Test_SubdivisionByDXCC;
end;

end.

{
 Copyright Larry Tyree, N6TR, 2011,2012,2013,2014,2015.

 This file is part of TR4W    (TRDOS)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W.  If not, see
 <http: www.gnu.org/licenses/>.
 }
unit ZoneCont;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  Windows,
  Tree,
  uCTYDAT,
  utils_text,
  uCallSignRoutines;

  //Country9;

//const
//  UpdateListDate                        = '3 Apr 93';

type
  DomesticCountryRecordPointer = ^DomesticCountryRecord;

  DomesticCountryRecord = record
    CountryID: string[6];
    NextRecord: DomesticCountryRecordPointer;
  end;

var
  FirstDomesticCountryRecord            : DomesticCountryRecordPointer;
//  LastLocateCall                        : CallString;
  LastLocateQTH                         : QTHRecord;
  tAddDomesticCountryString             : CallString;

procedure AddDomesticCountry(ID: CallString);
procedure ClearDomesticCountryList;
function DomesticCountryCall(Call: CallString): boolean;

function ClubCall(Call: CallString): boolean;

function GetVEInitialExchange(Call: CallString): string;

//procedure LocateCall(Call: VC.CallString; var QTH: VC.QTHRecord; UseStandardCallFormat: boolean);

function GetContinentName(Cont: ContinentType): string;
function GetContinentFromString(Cont: ShortString): ContinentType;
function SACDistrict(QTH: QTHRecord): string;
function IndonesianDistrict(QTH: QTHRecord): string;
function EuropeanCountriesAndWAECallRegions(QTH: QTHRecord): string;

implementation
uses LogWind;

function GetVEInitialExchange(Call: CallString): string;

var
  CountryID                             : Str20;
  QTH                                   : QTHRecord;
begin
  GetVEInitialExchange := '';

  Call := StandardCallFormat(Call, True);
  ctyLocateCall(Call, QTH);
  CountryID := QTH.CountryID;

  if ActiveQSOPointMethod = RussianDXQSOPointMethod then
    if (CountryID[1] = 'U') then
      if (CountryID[2] = 'A') then
         begin
         Result := GetRussiaOblastID(Call);
         Exit;
         end;

  if CountryID <> 'VE' then Exit;
  Call := Copy(Call, 1, 3);

  if StringHas(Call, '3') then
     begin
     GetVEInitialExchange := 'Ont ';
     end;
  if StringHas(Call, '4') then
     begin
     GetVEInitialExchange := 'Man';
     end;
  if StringHas(Call, '5') then
     begin
     GetVEInitialExchange := 'Sask';
     end;
  if StringHas(Call, '6') then
     begin
     GetVEInitialExchange := 'Ab';
     end;
  if StringHas(Call, '7') then
     begin
     GetVEInitialExchange := 'Bc';
     end;
  if StringHas(Call, '8') then
     begin
     GetVEInitialExchange := 'NWT';
     end;

  if Call = 'VE2' then
     begin
     GetVEInitialExchange := 'Que';
     end;
  if Call = 'VY2' then
     begin
     GetVEInitialExchange := 'vy2';
     end;
  if Call = 'VY1' then
     begin
     GetVEInitialExchange := 'Yuk';
     end;
  if Call = 'VO1' then
     begin
     GetVEInitialExchange := 'vo1';
     end;
  if Call = 'VO2' then
     begin
     GetVEInitialExchange := 'vo2';
     end;
  if Call = 'VE1' then
     begin
     GetVEInitialExchange := 've1';
     end;
end;

procedure AddDomesticCountry(ID: CallString);

var
  ActiveRecord                          : DomesticCountryRecordPointer;

begin
  strU(ID);

  if FirstDomesticCountryRecord = nil then
     begin
     FirstDomesticCountryRecord := New(DomesticCountryRecordPointer);
     FirstDomesticCountryRecord^.CountryID := ID;
     FirstDomesticCountryRecord^.NextRecord := nil;
     Exit;
     end;

  ActiveRecord := FirstDomesticCountryRecord;

  while ActiveRecord^.NextRecord <> nil do
     begin
     ActiveRecord := ActiveRecord^.NextRecord;
     end;

  ActiveRecord^.NextRecord := New(DomesticCountryRecordPointer);

  ActiveRecord := ActiveRecord^.NextRecord;

  ActiveRecord^.CountryID := ID;
  ActiveRecord^.NextRecord := nil;
end;

function DomesticCountryCall(Call: CallString): boolean;

{ Returns TRUE if the callsign is in one of the countries identified as
  domestic countries. }

var
  ActiveRecord                          : DomesticCountryRecordPointer;
  ID                                    : CallString;
  QTH                                   : QTHRecord;
begin
  ActiveRecord := FirstDomesticCountryRecord;

  if ActiveRecord = nil then
     begin
     DomesticCountryCall := False;
     Exit;
     end;

  ctyLocateCall(Call, QTH);
  ID := QTH.CountryID;

  repeat
    if ActiveRecord^.CountryID = ID then
       begin
       DomesticCountryCall := True;
       Exit;
       end;

    ActiveRecord := ActiveRecord^.NextRecord;

  until ActiveRecord = nil;

  DomesticCountryCall := False;
end;

procedure ClearDomesticCountryList;

var
  NextRecord, ActiveRecord              : DomesticCountryRecordPointer;

begin
  ActiveRecord := FirstDomesticCountryRecord;

  while ActiveRecord <> nil do
     begin
     NextRecord := ActiveRecord^.NextRecord;
     Dispose(ActiveRecord);
     ActiveRecord := NextRecord;
     end;
  FirstDomesticCountryRecord := nil;
end;

function EuropeanCountriesAndWAECallRegions(QTH: QTHRecord): string;
var
  NumberChar                            : AnsiChar;
begin
  Result := '';
  if QTH.Continent = Europe then Exit;
  Result := QTH.CountryID;
//W, VE, VK, ZL, ZS, JA, PY, ? ????? RA8/RA9 ? RA0
  if (QTH.CountryID = 'K') or
    (QTH.CountryID = 'VE') or
    (QTH.CountryID = 'VK') or
    (QTH.CountryID = 'ZL') or
    (QTH.CountryID = 'ZS') or
    (QTH.CountryID = 'JA') or
    (QTH.CountryID = 'PY') or
    (QTH.CountryID = 'UA9') then
     begin
     NumberChar := AnsiChar(GetNumber(QTH.StandardCall));
     Result := QTH.CountryID + NumberChar;
     end;

end;

function SACDistrict(QTH: QTHRecord): string;
var
  Oblast                                : Str2;
begin
  SACDistrict := '';
  if ScandinavianCountry(QTH.CountryID) then
     begin
     Oblast := GetOblast(QTH.StandardCall);
     if length(Oblast) = 0 then
        begin
        Oblast := '0';
        end;
     SACDistrict := QTH.CountryID + Oblast[1];
     if (QTH.CountryID = 'OH0') or (QTH.CountryID = 'OJ0') then
        begin
        SACDistrict := QTH.CountryID;
        end;
     end;
end;

function IndonesianDistrict(QTH: QTHRecord): string;        // 4.64.1

begin
  IndonesianDistrict := '';
  if (IndonesianCountry(QTH.CountryID) or (IndonesianCountry(MyCountry))) then
    IndonesianDistrict := GetPrefix(QTH.StandardCall); ;
end;

function ClubCall(Call: CallString): boolean;

begin
end;

function GetNumber(Call: CallString): AnsiChar;

{ This function will look at the callsign passed to it and return the
  single number that is in it.  If the call is portable, the number from
  the portable designator will be given if there is one.  If the call
  or prefix has two numbers in it, the last one will be given.         }

var
  CharPtr                               : integer;

begin
  if StringHas(Call, '/') then
     begin
     Call := PrecedingString(Call, '/');
     end;

  for CharPtr := length(Call) downto 1 do
    if (Call[CharPtr] <= '9') and (Call[CharPtr] >= '0') then
       begin
       GetNumber := Call[CharPtr];
       Exit;
       end;
  GetNumber := #0;
end;

function GetContinentName(Cont: ContinentType): string;
begin
  case Cont of
    NorthAmerica: GetContinentName := 'NA';
    SouthAmerica: GetContinentName := 'SA';
    Europe: GetContinentName := 'EU';
    Africa: GetContinentName := 'AF';
    Asia: GetContinentName := 'AS';
    Oceania: GetContinentName := 'OC';
  else GetContinentName := '';
  end;
end;

function GetContinentFromString(Cont: ShortString): ContinentType;
begin
  Result := UnknownContinent;
  if Cont = 'NA' then
     begin
     Result := NorthAmerica;
     end;
  if Cont = 'NO' then
     begin
     Result := NorthAmerica;
     end;

  if Cont = 'SA' then
     begin
     Result := SouthAmerica;
     end;
  if Cont = 'SO' then
     begin
     Result := SouthAmerica;
     end;

  if Cont = 'EU' then
     begin
     Result := Europe;
     end;
  if Cont = 'AF' then
     begin
     Result := Africa;
     end;
  if Cont = 'AS' then
     begin
     Result := Asia;
     end;
  if Cont = 'OC' then
     begin
     Result := Oceania;
     end;
  if Cont = 'AN' then
     begin
     Result := Antartica;
     end;
end;

//begin
  //  LastLocateCall := '';
end.


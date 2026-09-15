{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
 }
unit uCTYDAT;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses

  VC,
  (* LCLType, not Windows: MAXWORD is all this unit wanted from it, and
    LCLType declares it for every widget set -- see the note at the top of
    VC.pas. Classes brings TFileStream, which replaces the memory mapping. *)
  LCLType,
  Classes,
  uCallSignRoutines,
  utils_text,
  utils_file,
  SysUtils    // Issue #1033: StrPas for the RTL Val that replaces TF.ValExt
  ,
  uTR4WStrings;
{
type
  DXMultiplierString = string[5];
  GridString = string[7];
  ContinentType = (UnknownContinent, NorthAmerica, SouthAmerica, Europe, Africa, Asia, Oceania);
  CallString = string[10];
}

const
  MaxCountries                          = 1000 {380};    // n4af 4.42.6
const
{(*}
  RussianGrids                          : array['A'..'Z'] of array['0'..'9'] of  FourChar =
    (
//   0       1       2       3       4       5       6       7       8       9
    ('NO66', 'KO59', ''    , 'KO85', 'LN28', ''    , 'KN95', ''    , ''    , 'MO05'), //A
    ('OQ26', 'KO59', ''    , 'KO85', 'LN28', ''    , 'KN95', ''    , ''    , 'MO05'), //B
    ('PN78', 'KO59', ''    , 'KO85', 'LO31', ''    , 'KN95', ''    , ''    , 'MO06'), //C
    ('PN68', 'KO59', ''    , 'KO85', 'LO31', ''    , 'KN95', ''    , ''    , 'MO06'), //D
    ('QO11', 'KO59', ''    , 'KO82', ''    , ''    , 'LN14', ''    , ''    , 'MO06'), //E
    ('QO11', 'KO59', ''    , 'KO85', 'LO23', ''    , 'LN05', ''    , ''    , 'LO88'), //F
    ('QO11', 'KO59', ''    , 'KO92', ''    , ''    , 'LN05', ''    , ''    , 'LP70'), //G
    ('OO29', 'KO59', ''    , 'LO05', 'LO53', ''    , 'LN05', ''    , ''    , 'NO26'), //H
    ('QO59', 'KO59', ''    , 'KO76', 'LO53', ''    , 'LN26', ''    , ''    , 'NO26'), //I
    ('PO80', 'KO59', ''    , 'KO76', ''    , ''    , 'LN23', ''    , ''    , 'MP50'), //J
    ('RP96', 'KO59', ''    , ''    , ''    , ''    , ''    , ''    , ''    , 'MP26'), //K
    ('PN53', 'KO59', ''    , 'KO64', 'LO44', ''    , 'KN97', ''    , ''    , 'MO27'), //L
    ('PN53', 'KO59', ''    , 'KO97', 'LO44', ''    , 'KN97', ''    , ''    , 'MO65'), //M
    ('PN53', 'KP71', ''    , 'LO07', 'KO74', ''    , 'KN97', ''    , ''    , 'MO65'), //N
    ('OO43', 'LP04', ''    , 'LO07', 'KO74', ''    , 'KN97', ''    , ''    , 'NO15'), //O
    ('OO43', 'LP77', ''    , 'KO84', 'LO55', ''    , 'LN23', ''    , ''    , 'NO15'), //P
    ('PP00', 'KO99', ''    , 'KO91', 'LO55', ''    , 'LN23', ''    , ''    , 'MO25'), //Q
    ('PP00', 'KO99', ''    , 'LO02', 'LO55', ''    , ''    , ''    , ''    , 'MO25'), //R
    ('OO22', 'KO99', ''    , 'KO94', 'LO46', ''    , ''    , ''    , ''    , 'LO71'), //S
    ('OO22', 'LO26', ''    , 'LO26', 'LO46', ''    , ''    , ''    , 'OO22', 'LO71'), //T
    ('OO62', 'LO26', ''    , 'LO07', 'LO24', ''    , 'LN46', ''    , ''    , 'NO35'), //U
    ('OO62', 'KO59', ''    , 'LO06', ''    , ''    , 'LN46', ''    , 'ON69', 'NO35'), //V
    ('NO53', 'KO47', ''    , 'KO81', 'LO66', ''    , 'LN33', ''    , ''    , 'LO84'), //W
    ('RO06', 'KO47', ''    , 'KO84', ''    , ''    , 'LN13', ''    , ''    , 'LP63'), //X
    ('NO83', 'KP68', ''    , 'KO73', 'LO35', ''    , 'LN05', ''    , ''    , 'NO12'), //Y
    ('RO06', 'KP68', ''    , 'KO80', 'LO35', ''    , ''    , ''    , ''    , 'NO31')  //Z
    );
{*)}
const

  GridsArraysCount                      = 18;

  GridsIndexArray                       : array[1..GridsArraysCount] of string[2] =
    ('ZS', 'K', 'CE', 'CP', 'EA', 'EU', 'HK', 'JA', 'OA', 'OH', 'PY', 'SM', 'ZP', 'YV', 'YB', 'VE', 'VK', 'XE');

{(*}
  GridsArray                            : array[1..GridsArraysCount] of array['0'..'9'] of FourChar =
    (
    ('',     'KF07', 'KF26', 'KG12', 'KG31', 'KG50', 'KG44', '',     '',     ''),
    ('EN12', 'FN48', 'FN22', 'FN10', 'EM73', 'EM01', 'DM06', 'DN21', 'EN81', 'EN52'),
    ('',     'FG58', 'FG41', 'FF47', 'FF45', 'FF32', 'FF30', 'FE22', '',     ''),
    ('',     'FH63', 'FH70', 'FH61', 'FG69', 'FH73', 'FH93', 'FG88', 'FH77', 'FH68'),
    ('',     'IN62', 'IN82', 'IN92', 'IM79', 'IM98', '',     'IM77', '',     ''),
    ('',     'KO33', 'KO33', 'KO12', 'KO13', '',     'KO55', 'KO53', 'KO52', ''),
    ('',     'FK20', 'GK80', 'FJ34', 'FJ16', 'FJ16', 'FJ23', 'FJ35', 'FJ21', 'FJ40'),
    ('',     'PM95', 'PM84', 'PM74', 'PM65', 'PM63', 'PM52', 'QM09', 'QN13', 'PM86'),
    ('',     'EI95', 'FI03', 'FI20', 'FH18', 'FH26', 'FH32', 'FH46', 'FI27', 'FI14'),
    ('',     'KP10', 'KP20', 'KP11', 'KP32', 'KP20', 'KP03', 'KP42', 'KP44', 'KP25'),
    ('',     'GG88', 'GH65', 'GG30', 'GH71', 'GG44', 'GH97', 'HI13', 'GI05', 'GH25'),
    ('',     'JO97', 'KP05', 'JP83', 'JO79', 'JO89', 'JO67', 'JO76', '',     ''),
    ('',     'GG08', 'GG06', 'GG17', 'GG16', 'GG14', 'GG14', 'GG25', 'GG13', 'GG24'),
    ('',     'FK30', 'FJ48', 'FK40', 'FJ57', 'FK60', 'FJ86', 'FK80', 'FJ99', 'FJ63'),
    ('OI33', 'OI33', 'OI52', 'OI62', 'OI27', 'OJ00', 'NJ93', 'OI68', 'PI08', 'OI07'),
    ('',     'FN75', 'FN25', 'FN04', 'EN19', 'DO72', 'DO33', 'CN99', 'DP20', 'FN65'),
    ('',     'QF56', 'QF46', 'QF22', 'QG53', 'PF85', 'OF88', 'QE37', 'PH65', ''),
    ('',     'EK09', 'DM21', 'EK48', '',     '',     '',     '',     '',     '')
    );
{*)}
{
  ZSGrids                               : array['0'..'9'] of GridString =
    ('', 'KF07', 'KF26', 'KG12', 'KG31', 'KG50', 'KG44', '', '', '');

  KGrids                                : array['0'..'9'] of GridString =
    ('EN12', 'FN48', 'FN22', 'FN10', 'EM73', 'EM01', 'DM06', 'DN21', 'EN81', 'EN52');

  CEGrids                               : array['0'..'9'] of GridString =
    ('', 'FG58', 'FG41', 'FF47', 'FF45', 'FF32', 'FF30', 'FE22', '', '');

  CPGrids                               : array['0'..'9'] of GridString =
    ('', 'FH63', 'FH70', 'FH61', 'FG69', 'FH73', 'FH93', 'FG88', 'FH77', 'FH68');

  EAGrids                               : array['0'..'9'] of GridString =
    ('', 'IN62', 'IN82', 'IN92', 'IM79', 'IM98', '', 'IM77', '', '');

  EUGrids                               : array['0'..'9'] of GridString =
    ('', 'KO33', 'KO33', 'KO12', 'KO13', '', 'KO55', 'KO53', 'KO52', '');

  HKGrids                               : array['0'..'9'] of GridString =
    ('', 'FK20', 'GK80', 'FJ34', 'FJ16', 'FJ16', 'FJ23', 'FJ35', 'FJ21', 'FJ40');

  JAGrids                               : array['0'..'9'] of GridString =
    ('', 'PM95', 'PM84', 'PM74', 'PM65', 'PM63', 'PM52', 'QM09', 'QN13', 'PM86');

  OAGrids                               : array['0'..'9'] of GridString =
    ('', 'EI95', 'FI03', 'FI20', 'FH18', 'FH26', 'FH32', 'FH46', 'FI27', 'FI14');

  OHGrids                               : array['0'..'9'] of GridString =
    ('', 'KP10', 'KP20', 'KP11', 'KP32', 'KP20', 'KP03', 'KP42', 'KP44', 'KP25');

  PYGrids                               : array['0'..'9'] of GridString =
    ('', 'GG88', 'GH65', 'GG30', 'GH71', 'GG44', 'GH97', 'HI13', 'GI05', 'GH25');

  SMGrids                               : array['0'..'9'] of GridString =
    ('', 'JO97', 'KP05', 'JP83', 'JO79', 'JO89', 'JO67', 'JO76', '', '');

  ZPGrids                               : array['0'..'9'] of GridString =
    ('', 'GG08', 'GG06', 'GG17', 'GG16', 'GG14', 'GG14', 'GG25', 'GG13', 'GG24');

  YVGrids                               : array['0'..'9'] of GridString =
    ('', 'FK30', 'FJ48', 'FK40', 'FJ57', 'FK60', 'FJ86', 'FK80', 'FJ99', 'FJ63');

  YBGrids                               : array['0'..'9'] of GridString =
    ('OI33', 'OI33', 'OI52', 'OI62', 'OI27', 'OJ00', 'NJ93', 'OI68', 'PI08', 'OI07');

  VEGrids                               : array['0'..'9'] of GridString =
    ('', 'FN75', 'FN25', 'FN04', 'EN19', 'DO72', 'DO33', 'CN99', 'DP20', 'FN65');

  VKGrids                               : array['0'..'9'] of GridString =
    ('', 'QF56', 'QF46', 'QF22', 'QG53', 'PF85', 'OF88', 'QE37', 'PH65', '');
}
  ARRLSectionCountryString              = ' K VE KC6 KG4 KL KH0 KH1 KH2 KH3 KH4 KH5 KH6 KH7 KH8 KH9 KP1 KP2 KP3 KP4 KP5 ';

  UBAEuroCountryString                  = ' 5B 9H CT CT3 CU DL EA EA6 EA8 EI ES F FG FM FR FY G GD GI GJ GM GU GW HA I IS LX LY LZ OE OH OH0 OJ0 OK OM OZ PA S5 SM SP SV SV5 SV9 SY TK YL YO ';

  ScandinavianCountries                 = ' LA JW JX OH OH0 OJ0 OX OY OZ SM TF ';

  BlackSeaCountriesString               = ' OE ZA EU LZ E7 HA DL 4L I Z3 ER SP UA YO OM S5 TA UR 9A 4O OK HB YU ';

type
  DXMultString = array[0..7] of AnsiChar;
  PrefixName = array[0..13] of AnsiChar;

//  ZoneModeType = (CQZoneMode, ITUZoneMode);
//const
//  ZoneModeTypeSA                        : array[ZoneModeType] of PChar = ('CQ Zone', 'ITU Zone');

type

  PrefixRec = record
    {14}Prefix: PrefixName;
    {01}PrefLength: Byte;
    {01}FullCallsigns: boolean;

    {02}Country: Word;
    {01}CQZone: Byte;
    {01}ITUZone: Byte;
  end;

  PrefixRecPtr = ^PrefixRec;

  (* THE COUNTRY PREFIX TABLE.

    A PLAIN DYNAMIC ARRAY. It was an HDSA -- comctl32's "dynamic structure
    array" -- which is a UI library's private allocator holding the country
    lookup, and it is worse than it sounds. uCommctrl quotes Microsoft's own
    documentation beside the declarations: DSA_GetItem "is not exported by
    name. To use it, you must use GetProcAddress and request ordinal 322 from
    ComCtl32.dll", and DSA_DeleteItem "is available through Windows XP Service
    Pack 2. It might be altered or unavailable in subsequent versions."

    So the callsign-to-country lookup, which is on the hot path of every QSO,
    rested on undocumented by-ordinal exports Microsoft reserves the right to
    withdraw -- to store a sorted array of 14-byte records. FPC's own dynamic
    array does that, with bounds the compiler knows, and it is the same
    contiguous block underneath: the binary search still indexes, and
    ctyPrefixesTableRecords still counts.

    It also removes comctl32 from the DATA layer entirely, which is the point
    on the way to a non-Windows build: there is no DSA on macOS or Linux to
    port to, and nothing to replace because the replacement is the language. *)
  TPrefixTable = array of PrefixRec;

  CountryInfoRecord = record
    {06}ID: DXMultiplierString;
    {01}dummy: Byte;
    {01}DefaultContinent: ContinentType;

    {08}DefaultGrid: GridString;

    {32}Name: array[0..31] of AnsiChar;
    {01}DefaultITUZone: Byte;
    {02}UTCOffset: Smallint;
    {01}DefaultCQZone: Byte;
    {01}VisibleInRM: Byte;
  end;

  CountryInfoArrayType = array[0..MaxCountries - 1] of CountryInfoRecord;

  CTYInterface = record
    ctyVersion: array[0..15] of AnsiChar;
    ctyTable: CountryInfoArrayType;
    ctyNumberCountries: longint;   // 4.42.6
    ctyPrefixesTable: TPrefixTable;
    ctyPrefixesTableRecords: longword;
    ctyZoneMode: ZoneModeType;
    ctyTempQTHRecord: QTHRecord;
    ctyCountryMode: CountryModeType;
//    ctyLastCountryCall: CallString;
    ctyNumberRemainingCountries: longint; // 4.42.6
    ctyCustomRemainingCountryListFound: boolean;
    ctyIndexArray: array[Char] of Smallint;
    ctyMaxLengthIndexArray: array[Char] of Byte;
    ctyLastLocatedCall: CallString;
    ctyLastLocatedRecord: QTHRecord;
    ctyLastIndex: integer;
//    ctyUA3Country: Word;
//    ctyUA9Country: Word;
  end;

//  RemainingDXMultTemplateType = array[0..MaxCountries - 1] of DXMultString; //FourBytes;
//  RemainingDXMultTemplatePointer = ^RemainingDXMultTemplateType;

function ctyLocateCall(Call: CallString; var QTH: QTHRecord): boolean;
//function ctyInit(ctyFilename: PAnsiChar): boolean;
function ctyLoadInCountryFile(const ctyFilename: string; CheckDupe: boolean;
                              LoadRemainingMults: boolean;
                              ReplaceTable: boolean = False): boolean;
function ctyFindCallsign(const s: PrefixName; var Index: integer;
                         PreferFullCallsign: boolean = True): boolean;
function ctyGetGrid(const Call: string; var ID: DXMultiplierString): string;
function ctyGetContinent(const Call: string): ContinentType;
function ctyGetCountry(const Call: string): Word;
function ctyGetCountryUTCOffset(Country: Word): Smallint;
function ctyGetZone(const Call: string): Byte;
function ctyGetITUZone(const Call: string): Byte;
function ctyGetCQZone(const Call: string): Byte;

function ctyGetDefaultITUZone(Country: Word): Byte;
function ctyGetDefaultCQZone(Country: Word): Byte;
function ctyGetDefaultGrid(Country: Word): string;
function ctyGetCountryIdByIndex(Country: Word): string;
function ctyGetContinentByIndex(Country: Word): ContinentType;
function ctyGetTotalCountries: integer;
function ctyGetVersion: string;
function ctyIsActiveMultiplier(Index: Word): boolean;
procedure ctySetCountryMode(CountryMode: CountryModeType);

function ctyGetCountryName(Index: Word): string;
function ctyGetCountryID(const Call: string): string;

procedure ctyShellSort;
procedure ctyAddNewPrefixRecord(pr: PrefixRecPtr; CheckDupe: boolean);
procedure ctyLoadInRFOblList;   // n4af 4.42.6
procedure ctyLoadInRemainingMults(const aSection: AnsiString);
procedure ctyLoadInR150SList;

var
  CTY                                   : CTYInterface;


const
   (* The growth quantum DSA_Create was given, kept so the allocation pattern
     is unchanged. *)
   PREFIX_TABLE_GROW = 100;

implementation

// Issue #1033: uCTYDAT previously borrowed the global `logger` from MainUnit,
// which coupled this otherwise self-contained country-lookup unit to the entire
// application and blocked it from being linked into the unit-test EXE. Give it
// its own Log4D logger -- the same pattern every modern unit uses (e.g.
// uExternalLoggerFactory) -- so the unit no longer depends on MainUnit.
uses
   Log4D,
   (* SetCharBuffer / CharBufferText -- a fixed AnsiChar buffer written and
     read through its OWN bounds, in place of StrPCopy and StrPas. *)
   TF;

var
   logger: TLogLogger;

(* ctyDbgFmt WAS HERE and is deleted: the tDebugMode prefix-table dump it was
  written for is gone, so it had NO CALLER. Its own comment still described it
  as a wsprintfA binding, which it had stopped being when it was repointed at
  CFormatBuf -- a stale claim guarding a dead routine. *)

// ---------------------------------------------------------------------------
// Issue #1033: helpers lifted VERBATIM from TF / LogGrid so uCTYDAT no longer
// depends on either -- both pull in MainUnit -> LogStuff and blocked uCTYDAT
// from linking into the dependency-light unit-test EXE. Bodies are unchanged
// (identical behavior + git blame); fold into a shared light unit during the
// Delphi 12 refactor. See docs/tr4w-migration-strategy.md.
// ---------------------------------------------------------------------------

(* PCharToInt WAS HERE -- lifted verbatim from TF in Issue #1033 to break a
  dependency, and byte-for-byte identical to the original ever since, which
  is a copy free to drift. It is utils_text.LeadingInt now, in a leaf the
  unit tests can reach, and both copies are gone. *)

// Lifted from LogGrid.ConvertLatLonToGrid: Maidenhead grid from lat/lon.
function ConvertLatLonToGrid(Lat, Lon: REAL): GridString;
var
  c                                     : integer;
  G4, L4                                : REAL;
  m1, m2, m3, m4, m5, m6                : Char;
begin
  G4 := 180 - Lon;
  c := Trunc(G4 / 20);
  m1 := CHR(c + Ord('A'));
  G4 := G4 - c * 20;
  c := Trunc(G4 / 2);
  m3 := CHR(c + Ord('0'));
  G4 := G4 - c * 2;
  c := Trunc(G4 / (2 / 24));
  m5 := CHR(c + Ord('A'));
  L4 := Lat + 90;
  c := Trunc(L4 / 10);
  m2 := CHR(c + Ord('A'));
  L4 := L4 - c * 10;
  c := Trunc(L4);
  m4 := CHR(c + Ord('0'));
  L4 := L4 - c;
  c := Trunc(L4 / (1 / 24));
  m6 := CHR(c + Ord('A'));
  ConvertLatLonToGrid := m1 + m2 + m3 + m4 + m5 + m6;
end;

procedure ctyAddNewPrefixRecord(pr: PrefixRecPtr; CheckDupe: boolean);
var
  TempIndex                             : integer;
begin

  if not pr.FullCallsigns then
     begin
     if pr.Prefix[0] = 'R' then
 //      if pr.Prefix[1] in ['B'..'Z'] then
       if pr.Prefix[1] in ['B'..'H', 'J'..'Z'] then
         if pr.Prefix[2] <> '2' then
            begin
            Exit;
            end;

     if pr.Prefix[0] = 'U' then
       if pr.Prefix[1] in ['B'..'E', 'G'..'I'] then Exit;

     end;
   if CheckDupe then
      begin

      for TempIndex := 0 to CTY.CTYPrefixesTableRecords - 1 do
        if CompareCharBuffer(CTY.ctyPrefixesTable[TempIndex].Prefix, pr.Prefix) = 0 then
           begin
           CTY.ctyPrefixesTable[TempIndex] := pr^;
           Exit;
           end;
      end;

  if CTY.CTYPrefixesTableRecords >= Length(CTY.ctyPrefixesTable) then
     begin
     SetLength(CTY.ctyPrefixesTable,
               Length(CTY.ctyPrefixesTable) + PREFIX_TABLE_GROW);
     end;

  CTY.ctyPrefixesTable[CTY.CTYPrefixesTableRecords] := pr^;
  inc(CTY.CTYPrefixesTableRecords);
end;

(* A `!` LINE IN cty.dat MERGES ONE ENTITY INTO ANOTHER.

  The caller reaches here when the country-name field begins with '!', and it
  has packed two things into the record by then:

      r.Name   the FIRST field, marker included -- "!<the entity to keep>"
      r.ID     the SECOND field -- the entity to retire

  So this finds both, hides the retired one from the remaining-multiplier
  windows, and re-points every prefix that named it at the one being kept.

  THE SHIPPED cty.dat HAS NO `!` LINES -- this serves an operator's own file.

  A NOTE HERE CLAIMED THIS SKIPPED THE FIRST LETTER OF THE NAME. IT DID NOT,
  AND THE CLAIM WAS THE WORSE HALF OF THE PROBLEM. `@r.Name[1]` steps past the
  '!' the caller just tested at r.Name[0], which is exactly right. Reading the
  call site settles it in a minute; the note had been carried instead.

  WHAT WAS REAL IS THE OTHER SIDE. `@CTY.CTYTable[i].ID[1]` handed a pointer
  into a ShortString to a routine that stops at a NUL, and
  DXMultiplierString is string[5] -- so a five-character id (`*GM/s`, `*4U1V`,
  both in the shipped file) fills the buffer with no terminator at all and the
  compare runs on into `dummy` and `DefaultContinent`. Comparing through the
  string reads exactly the id. *)
procedure ReplaceCountry(r: CountryInfoRecord);
var

  i, Index1, Index2                     : Word;
  c                                     : Cardinal;
  keepID                                : AnsiString;
begin
  Index1 := MAXWORD;
  Index2 := MAXWORD;

  (* BYTES, NOT TEXT: a country name in cty.dat may be CP1251 or CP1250, so
    decoding it as UTF-8 on the way to an ASCII comparison would be deciding
    something this routine has no business deciding. *)
  keepID := CharBufferBytes(r.Name);
  Delete(keepID, 1, 1);          (* the '!' marker the caller matched on *)
  for i := 0 to CTY.CTYNumberCountries do
     begin
     if CTY.CTYTable[i].ID = r.ID then
        begin
        Index1 := i;
        end;

     (* SUSPECTED DEFECT, LEFT AS IT IS UNTIL NY4I RULES (2026-09-14).

       This compares a country ID against r.Name STARTING AT INDEX 1, and
       r.Name is array[0..31] of AnsiChar whose text begins at index 0 --
       line 594 writes it with Move(p[s], r.Name, l) and line 599 reads
       r.Name[0] as a CHARACTER. So this skips the first letter of the
       name it is matching on.

       The line above it compares the same ID field with a plain
       ShortString equality test, which is what this looks like it meant
       to be.

       It is NOT changed here because removing a pointer must not change
       what a comparison MEANS: ReplaceCountry decides which country a
       CTY.DAT override replaces, and making this match one character
       earlier could start replacing a different country. Ruling needed
       on what Index2 is supposed to find; the pointers go with the fix. *)
     if AnsiString(CTY.CTYTable[i].ID) = keepID then
        begin
        Index2 := i;
        end;
     end;
  if Index1 = MAXWORD then Exit;
  if Index2 = MAXWORD then Exit;

  CTY.ctyTable[Index1].VisibleInRM := 1;
  for c := 0 to CTY.CTYPrefixesTableRecords - 1 do
     begin
     if CTY.ctyPrefixesTable[c].Country = Index1 then
        begin
        CTY.ctyPrefixesTable[c].Country := Index2;
        end;
     end;

end;

function ctyLoadInCountryFile(const ctyFilename: string; CheckDupe: boolean;
                              LoadRemainingMults: boolean;
                              ReplaceTable: boolean = False): boolean;

// (#) Override CQ Zone
// [#] Override ITU Zone
// ? <#/#> Override latitude/longitude
// ? {aa} Override Continent
type
  ctyColumns = (cpCountryName, cpCQZone, cpITUZone, cpContinent, cpLatitude, cpLongitude, cpTimeOffset, cpPrimaryPrefix, cpUnDef);

var
  (* THE FILE IS READ INTO MEMORY, NOT MEMORY-MAPPED (2026-09-07).

    It was CreateFileA + CreateFileMapping + MapViewOfFile, with two labels and
    two gotos to unwind the three handles on a partial failure. All four calls
    are Windows-only and there is no portable mapping in the RTL.

    A read costs one allocation of the file's size -- CTY.DAT is about a
    megabyte, read once at start-up -- and in exchange the unwinding disappears
    with the handles: TFileStream frees itself, and a dynamic array frees
    itself. Both labels and both gotos are gone.

    THE PARSE INDEXES raw ITSELF (2026-09-15). It walked a PAnsiChar laid over
    raw, and copied each field with a Move of the field's length -- into a
    32-byte buffer, a 32-byte name, a five-character id and a 14-byte
    prefix -- with nothing bounding that length. Every field is a bounded
    slice now: AnsiStringFromBytes. *)
  raw                                   : TBytes;
  body                                  : AnsiString;   (* raw as bytes, for the REMAINING MULTS search *)
  rmAt                                  : integer;
  fs                                    : TFileStream;
  i                                     : Cardinal;
  s                                     : Cardinal;
  prefixText                            : AnsiString;   (* one prefix token, as its bytes *)
  //rmbuffer                              : array[0..4096 - 1] of Char;
  c                                     : ctyColumns;
  //x                                     : Cardinal;
  l                                     : Cardinal;
  Lat, Lon                              : REAL;
  code                                  : integer;
  r                                     : CountryInfoRecord;
  pr                                    : PrefixRec;
  e                                     : Cardinal;
  z                                     : Cardinal;
  oITU                                  : Byte;
  oCQ                                   : Byte;
  Size                                  : Cardinal;
 // Minutes                               : integer;
 // pppp                                  : integer;
//  NumberCountriesIndex             : integer;
const
  rm                                    = 'REMAINING MULTS';

  (* THE ENTITY ID, BOUNDED BY ITS OWN TYPE. DXMultiplierString is string[5];
    a Move of the token's length and a length byte of AnsiChar(l) wrote as
    far as the token went. High(aId) is 5 here -- this is a typed var
    parameter, not an openstring, whose High is 255 in Delphi mode. *)
  procedure SetIdFromBytes(var aId: DXMultiplierString; aStart, aLength: integer);
  var
     text: AnsiString;
     k: integer;
  begin
     text := AnsiStringFromBytes(raw, aStart, aLength);
     if Length(text) > High(aId) then
        begin
        SetLength(text, High(aId));
        end;
     aId[0] := AnsiChar(Length(text));
     for k := 1 to Length(text) do
        begin
        aId[k] := text[k];
        end;
  end;

begin
//3.900.000 ticks
//  Start := GetCPU;
  Result := False;
  z := 0; // 4.79.3

  (* A MISSING OR UNREADABLE FILE RETURNS False, as it always did -- the old
    code exited on INVALID_HANDLE_VALUE. TFileStream raises instead, so the
    same answer is produced by catching it. *)
  raw := nil;
  try
     (* AnsiString, NOT string(AnsiString(...)). The RTL is built without
       UnicodeStrings, so TFileStream.Create takes an AnsiString -- widening
       to UnicodeString here only to have the call narrow it back is a silent
       round trip, and the build ratchet counts it. *)
     fs := TFileStream.Create(AnsiString(ctyFilename), fmOpenRead or fmShareDenyNone);
     try
        SetLength(raw, fs.Size);
        if Length(raw) > 0 then
           begin
           fs.ReadBuffer(raw[0], Length(raw));
           end;
     finally
        fs.Free;
     end;
  except
     Exit;
  end;

  if Length(raw) = 0 then
     begin
     Exit;
     end;

  (* GROWN IN BLOCKS, not per prefix. DSA_Create's second argument was its
    growth quantum (100 records); SetLength on every append would be a
    reallocation per prefix over a CTY.DAT of ~2,000, so the capacity is
    raised in the same steps and ctyPrefixesTableRecords -- not Length --
    remains the count of live records. *)
  if Length(CTY.ctyPrefixesTable) = 0 then
     begin
     SetLength(CTY.ctyPrefixesTable, PREFIX_TABLE_GROW);
     end;

  c := cpCountryName;
  s := 0;
  e := 0;
  oITU := 0;
  oCQ := 0;

(* A RELOAD MUST REPLACE THE TABLE, AND UNTIL NOW NOTHING DID.

    A FillChar of the country table stood here, COMMENTED OUT, and the count
    beside it was never reset either -- so every call to this routine APPENDED
    to whatever was already loaded. The country table is
    array[0..MaxCountries - 1] with MaxCountries = 1000 and the shipped
    cty.dat carries ~693 entities, so:

        startup            693 of 1000
        a CTY.DAT download 1386 -- and the write runs off the end at 1000

    ctyLoadInCountryFile IS the reload path after a download
    (uMainWindowProc), so ONE re-download in a session was enough to write
    past the array into the rest of the CTY record. It never announced
    itself, because Pascal range checking is off here.

    THE APPEND IS NOT A BUG BY ITSELF -- it is what the r150s and rfobl
    overlays want, and they call this same routine to add their entities on
    top of the main file. That is why the reset is a PARAMETER and not
    unconditional: the caller says which it means, rather than this routine
    guessing from CheckDupe or from LoadRemainingMults, neither of which is
    about the table. *)
  if ReplaceTable then
     begin
     FillChar(CTY.CTYTable, SizeOf(CTY.CTYTable), 0);
     CTY.CTYNumberCountries := 0;
     SetLength(CTY.ctyPrefixesTable, 0);
     CTY.ctyPrefixesTableRecords := 0;
     CTY.ctyCustomRemainingCountryListFound := False;
     end;

    Size := Length(raw);

  for i := 0 to Size - 1 do
     begin
           case AnsiChar(raw[i]) of
      ':':
        begin
          l := i - s;
          case c of

            cpCountryName:
              begin
                r := Default(CountryInfoRecord);
                SetCharBufferBytes(r.Name, AnsiStringFromBytes(raw, s, l));
              end;

            cpCQZone:
              begin
                if r.Name[0] = '!' then
                   begin
                   // Issue #997: removed asm nop (no-op).
                   SetIdFromBytes(r.ID, i - l, l);
                   ReplaceCountry(r);
                   c := cpCountryName;
                   Continue;
                   end;
                r.DefaultCQZone := raw[i - 1] - Ord('0');
                if l = 2 then
                   begin
                   r.DefaultCQZone := r.DefaultCQZone + (raw[i - 2] - Ord('0')) * 10;
                   end;
              end;

            cpITUZone:
              begin
                r.DefaultITUZone := raw[i - 1] - Ord('0');
                if l = 2 then
                   begin
                   r.DefaultITUZone := r.DefaultITUZone + (raw[i - 2] - Ord('0')) * 10;
                   end;
              end;

            cpContinent:
              begin
                if AnsiChar(raw[i - 2]) = 'E' then
                   begin
                   r.DefaultContinent := Europe;
                   end;
                if AnsiChar(raw[i - 2]) = 'O' then
                   begin
                   r.DefaultContinent := Oceania;
                   end;
                if AnsiChar(raw[i - 2]) = 'N' then
                   begin
                   r.DefaultContinent := NorthAmerica;
                   end;
                if AnsiChar(raw[i - 2]) = 'S' then
                   begin
                   r.DefaultContinent := SouthAmerica;
                   end;
                if AnsiChar(raw[i - 1]) = 'S' then
                   begin
                   r.DefaultContinent := Asia;
                   end;
                if AnsiChar(raw[i - 1]) = 'F' then
                   begin
                   r.DefaultContinent := Africa;
                   end;
              end;

            cpLatitude:
              begin
                Val(string(AnsiStringFromBytes(raw, s, l)), Lat, code);   // Issue #1033: was TF.ValExt (asm); RTL Val is equivalent for cty.dat's well-formed decimals
              end;
            cpLongitude:
              begin

                Val(string(AnsiStringFromBytes(raw, s, l)), Lon, code);   // Issue #1033: was TF.ValExt (asm)
                if code = 0 then
                   begin
                   r.DefaultGrid := ConvertLatLonToGrid(Lat, Lon);
                   end;
              end;

            cpTimeOffset:
              begin
                r.UTCOffset := LeadingInt(string(AnsiStringFromBytes(raw, s, l))) * 60;
{
                for Minutes := 1 to 3 do
                  if b[Minutes] = '.' then
                  begin
                    if b[Minutes + 1] <> '0' then
                      r.UTCOffset := r.UTCOffset + (PCharToInt(@b[Minutes + 1]) div 25) * 15;
                  end;
}
                //tPos(
//                Lon := ValExt(b, code);
//                if code = 0 then r.UTCOffset := round(Lon * 100);
              end;
            cpPrimaryPrefix:
              begin
                SetIdFromBytes(r.ID, s, l);
//                if r.ID = 'UA9' then
//                  asm nop end;
{
                for NumberCountriesIndex := 0 to MaxCountries - 1 do
                begin
                  if CountryInfoTable^[NumberCountriesIndex].ID = r.ID then Break;
                  if CountryInfoTable^[NumberCountriesIndex].ID = '' then Break;
                end;
}
                (* FAIL CLOSED. Range checking is off in this unit, so an
                  overrun here is a silent memory write; the guard above
                  removes the cause and this removes the CONSEQUENCE if a
                  country file ever genuinely holds more than the table. *)
                if CTY.CTYNumberCountries >= MaxCountries then
                   begin
                   logger.Error('cty: more than %d entities in %s -- the rest are ignored',
                                [MaxCountries, ctyFilename]);
                   Break;
                   end;

                CTY.CTYTable[CTY.CTYNumberCountries] := r;
                inc(CTY.CTYNumberCountries);

              end;
          end;
          inc(c);
        end;
      ' ', #9: if c <> cpCountryName then s := i + 1;
      #13, #10: s := i + 1;
   
      '[', '(': begin z := i + 1;
          if e = 0 then
             begin
             e := i + 1;
             end;
        end;
      ')':
        begin
          oCQ := raw[i - 1] - Ord('0');

          if i - z = 2 then
             begin
             oCQ := oCQ + (raw[i - 2] - Ord('0')) * 10;
             end;
        end;
      ']':
        begin
          oITU := raw[i - 1] - Ord('0');
          if i - z = 2 then
             begin
             oITU := oITU + (raw[i - 2] - Ord('0')) * 10;
             end;
        end;

      ',', ';':
        begin
          pr := Default(PrefixRec);
          if (s < Size) and (raw[s] = Ord('=')) then
             begin
             inc(s);
             pr.FullCallsigns := True;
             end;
               l := i - s;
          if e <> 0 then
          if (s <= e)  then   //n4af 4.35.2
             begin
             l := (e - s - 1);
             end;
          (* BOUNDED BY THE 14-BYTE PREFIX. l is Cardinal, and e - s - 1 wraps to
            4294967295 when the two positions meet; AnsiStringFromBytes takes it
            as an integer, which is below one, and gives ''. *)
          prefixText := AnsiStringFromBytes(raw, s, l);
          SetCharBufferBytes(pr.Prefix, prefixText);
          pr.PrefLength := Length(prefixText);
          if pr.PrefLength > High(pr.Prefix) then
             begin
             pr.PrefLength := High(pr.Prefix);
             end;

          pr.Country := CTY.CTYNumberCountries - 1;
          if oCQ <> 0 then begin pr.CQZone := oCQ;
            oCQ := 0;
          end { else pr.CQZone := r.DefaultCQZone};
          if oITU <> 0 then begin pr.ITUZone := oITU;
            oITU := 0;
          end {else pr.ITUZone := r.DefaultITUZone};
          ctyAddNewPrefixRecord(@pr, CheckDupe);
          if pr.Prefix[0] = 'V' then
            if pr.Prefix[1] = 'E' then
              if pr.Prefix[2] = 'R' then
                if pr.Prefix[3] = '2' then
                  if pr.Prefix[4] = '0' then
                     begin
                     (* AN APPEND, BOUNDED, AND NO POINTER. This was
                       lstrcatA -- unbounded, and ctyVersion is 16 bytes
                       against Prefix's 14 -- then StrLCat. SetCharBufferBytes
                       keeps StrLCat's bound (High leaves room for the
                       terminator) over the two buffers' text. *)
                     SetCharBufferBytes(CTY.CtyVersion,
                        CharBufferBytes(CTY.CtyVersion) + CharBufferBytes(pr.Prefix));
                     end;

          s := i + 1;
          e := 0;
          if raw[i] = Ord(';') then
             begin
             c := cpCountryName;
             end;
        end;
    end;

  end;

  if LoadRemainingMults then
     begin
     (* THE NOTE THAT USED TO BE HERE WAS WRONG, and it had been wrong long
       enough to read as fact: it claimed StrPos resolved to the WideChar
       variant so this branch could never find the ANSI marker, and was
       "effectively disabled". Nothing tested it and the shipped cty.dat has
       no such section, so nobody could tell. It works, and
       Test_RemainingMultsSection is the proof -- a two-entity country file
       with the section, asserting what the section is for.

       Bytes, not text: cty.dat is CP1251/CP1250 in places, so the file goes
       into an AnsiString whose bytes are its own. Pos on an AnsiString is a
       byte search, which is what the marker needs. *)
     body := AnsiStringFromBytes(raw, 0, Length(raw));

     rmAt := Pos(AnsiString(rm), body);
     if rmAt > 0 then
        begin
        ctyLoadInRemainingMults(Copy(body, rmAt, Length(body) - rmAt + 1));
        end;
     end;

  (* NOTHING TO UNWIND. This was `1: UnmapViewOfFile; 2: CloseHandle(MapFin);
    CloseHandle(h);` -- the two goto targets for a mapping that failed halfway.
    The stream is already closed and `raw` is freed by the compiler. *)

  Result := True;
  ctyShellSort;
//  Stop := GetCPU;
//  showint(Stop - Start);
end;

(* ===========================================================================
  SORTING THE PREFIX TABLE, AND INDEXING IT -- TWO JOBS, SO TWO ROUTINES.

  This was one 92-line procedure doing both. They share nothing except the
  moment they run, and the indexes are the more interesting half: they are
  what makes ctyFindCallsign search one letter's block instead of all 6562
  records.

  ---------------------------------------------------------------------------
  THE SORT ALGORITHM IS UNCHANGED HERE, BUT IT IS NO LONGER LOAD-BEARING.
  ---------------------------------------------------------------------------

  A shell sort is UNSTABLE, and cty.dat contains FOURTEEN prefixes twice --
  thirteen of them under two DIFFERENT countries:

      4U0IARU 4U0R 4U1A 4U1VIC 4U2U 4UNR 4Y1A C7A     country 23 or 208
      GB1DAA GB2ELH GB3LER GB3LER/B GB4LER            country 143 or 144
      UA4H                                            268 twice (harmless)

  So "which entity does 4U1A belong to" used to be answered by wherever an
  unstable sort happened to leave two equal keys -- which is why four of the
  eight 4U calls resolved to Austria and the other two to the Vienna
  International Centre, from the identical pair of records.

  THAT IS DECIDED BY A RULE NOW, not by the sort: see
  ctyChooseAmongDuplicates, beside ctyFindCallsign. Replacing this sort with
  any correct algorithm is therefore safe -- stable or not, the answer no
  longer depends on the order of equal keys.

  WHAT A REPLACEMENT STILL OWES: re-run the 2064-record characterisation
  fixture. That is what caught the first attempt, when the answer DID depend
  on the order.
  =========================================================================== *)

(* The shell sort, byte for byte as it was. The odd step-back --
  `if iJ > iK then dec(iJ, iK) else iJ := 0` -- is part of what makes its
  treatment of equal keys what it is, so it is not tidied either. *)
procedure ctySortPrefixTable;
var
  iI, iJ, iK, iSize : integer;
  wTemp1            : PrefixRec;
  wTemp2            : PrefixRec;
begin
  iSize := CTY.ctyPrefixesTableRecords - 1;
  iK := iSize shr 1;
  while iK > 0 do
     begin
     for iI := 0 to iSize - iK do
        begin
        iJ := iI;
        while (iJ >= 0) and
              (CompareCharBuffer(CTY.ctyPrefixesTable[iJ].Prefix,
                                 CTY.ctyPrefixesTable[iJ + iK].Prefix) > 0) do
           begin
           wTemp1 := CTY.ctyPrefixesTable[iJ];
           wTemp2 := CTY.ctyPrefixesTable[iJ + iK];
           CTY.ctyPrefixesTable[iJ] := wTemp2;
           CTY.ctyPrefixesTable[iJ + iK] := wTemp1;

           if iJ > iK then
              begin
              dec(iJ, iK)
              end
           else
              begin
              iJ := 0
              end
           end;
        end;
     iK := iK shr 1;
     end;
end;

(* The two indexes the binary search needs: where each starting character's
  block begins, and the longest prefix filed under it. *)
procedure ctyBuildPrefixIndex;
var
  i        : integer;
  TempChar : Char;
  rec      : PrefixRecPtr;
begin
  FillChar(CTY.ctyIndexArray, SizeOf(CTY.ctyIndexArray), -1);
  FillChar(CTY.ctyMaxLengthIndexArray, SizeOf(CTY.ctyMaxLengthIndexArray), 0);

  (* DESCENDING, AND THAT IS LOAD-BEARING. ctyIndexArray must hold the
    FIRST record of each block, because ctyFindCallsign uses it as the LOW
    bound of its binary search. Ascending leaves the LAST index there, so
    low ends up above high, the search never runs, and EVERY callsign
    resolves to nothing -- which is what happened when this loop was
    rewritten the wrong way round. *)
  for i := Integer(CTY.ctyPrefixesTableRecords) - 1 downto 0 do
     begin
     rec := @CTY.ctyPrefixesTable[i];
     CTY.ctyIndexArray[rec^.Prefix[0]] := i;

     (* A FULL CALLSIGN IS NOT A PREFIX and must not stretch the length the
       search is willing to try -- otherwise every lookup under that letter
       would test prefixes no prefix is that long. *)
     if not rec^.FullCallsigns then
        if rec^.PrefLength > CTY.ctyMaxLengthIndexArray[rec^.Prefix[0]] then
           begin
           CTY.ctyMaxLengthIndexArray[rec^.Prefix[0]] := rec^.PrefLength;
           end;
     end;

  (* The sentinel past 'Z' is the end of the table, so 'Z' has an upper bound
    like every other character. *)
  CTY.ctyIndexArray[CHR(Ord('Z') + 1)] := CTY.ctyPrefixesTableRecords - 1;

  (* A character with no records of its own borrows the NEXT one's start, so
    its block is empty rather than unbounded. Descending, because each answer
    depends on the one above it. *)
  for TempChar := 'Z' downto '0' do
     begin
     if CTY.ctyIndexArray[TempChar] = -1 then
        begin
        CTY.ctyIndexArray[TempChar] := CTY.ctyIndexArray[CHR(Ord(TempChar) + 1)];
        end;
     end;
end;

(* The name every caller uses. It was never only a sort, which is why the two
  halves are now named for what they do. *)
procedure ctyShellSort;
begin
  ctySortPrefixTable;
  ctyBuildPrefixIndex;
end;

(* ===========================================================================
  TWO RECORDS FOR ONE PREFIX: WHICH ONE THE PREFIX MEANS.

  cty.dat files the same callsign under two entities on purpose, and the
  LEADING ASTERISK on a primary prefix is what tells them apart -- it marks an
  entity that is NOT a DXCC country:

      Vienna Intl Ctr: ... *4U1V: =4U0IARU,=4U0R,=4U1A,=4U1VIC,=4U2U,=4UNR,...
      Austria:            OE: OE,=4U0IARU,=4U0R,=4U1A,=4U1VIC,=4U2U,=4UNR,...

      Shetland Islands: ... *GM/s: ...,=GB1DAA,=GB2ELH,...
      Scotland:            GM: ...,=GB1DAA,=GB1OL,...

  NY4I's rule, 2026-09-14: THE SPECIFIC ONE ALWAYS WINS, THEN THE LESS
  SPECIFIC. The call-then-shortening-prefix ladder in ctyLocateCall is that
  rule along one axis -- the whole callsign is tried before any prefix, and a
  longer prefix before a shorter -- and it is unchanged, because it is what the
  D7 program did (uCTYDAT.PAS, the `for TempPointer := TempLength downto 1`
  walk) and it gets 4U right: a bare `4U` is filed under Italy, and =4U1ITU
  under the ITU HQ entity, so the exception beats the prefix.

  THIS ROUTINE IS THE SAME RULE ALONG THE OTHER AXIS, where two records are
  equally specific as CALLSIGNS and differ only in which entity claims them.
  The '*' entity is the sub-entity -- Vienna inside Austria, Shetland inside
  Scotland -- so it is the more specific answer, and it wins wherever it is
  allowed to count:

      CQCountryMode  (DXCC + WAE) -- prefer the '*' record
      ARRLCountryMode (DXCC only) -- prefer the record that is NOT '*'

  UNTIL NOW NOTHING DECIDED THIS AND THE SORT DID. A shell sort is unstable, so
  which of the two equal keys ctyFindCallsign landed on was an artifact, and
  the results were split down the middle for no reason anyone chose:

      4U0R 4U1VIC              -> 23  (*4U1V, Vienna Intl Ctr)
      4U0IARU 4U1A 4U2U 4UNR   -> 208 (OE, Austria)
      GB1DAA GB2ELH            -> 144 (*GM/s, Shetland)

  All eight 4U calls carry the identical pair of records. Four went one way and
  two the other. These are MULTIPLIERS on submitted logs, so the inconsistency
  was visible to operators and had no rule behind it.

  AND IT FIXES A SECOND DEFECT IN THE ARRL PATH. ctyLocateCall's exact-call
  branch tested the found record for '*' and, when it was one, fell through to
  the prefix walk -- it never looked for the OTHER record of the pair, which is
  the DXCC one it wanted. Choosing before returning means the branch now gets
  the record it was asking for.

  THE SORT IS FREE AGAIN AS A RESULT. Nothing about the answer depends on where
  an unstable sort leaves equal keys any more, so ctySortPrefixTable may be
  replaced by any correct algorithm -- see the note above it. *)

(* A '*' on the entity's primary prefix: not a DXCC country, so a sub-entity
  of one. ID is a ShortString-style buffer indexed from 1. *)
function ctyIsSubEntity(Index: integer): boolean;
begin
   Result := CTY.ctyTable[CTY.ctyPrefixesTable[Index].Country].ID[1] = '*';
end;

procedure ctyChooseAmongDuplicates(var Index: integer;
                                   PreferFullCallsign: boolean);
var
   first, last, i : integer;
   wantSub        : boolean;
   score, best    : integer;
begin
   (* The binary search stops at whichever equal key it met first, so the run
     extends in both directions from there. *)
   first := Index;
   while (first > 0) and
         (CompareCharBuffer(CTY.ctyPrefixesTable[first - 1].Prefix,
                            CTY.ctyPrefixesTable[Index].Prefix) = 0) do
      begin
      dec(first);
      end;

   last := Index;
   while (last < Integer(CTY.ctyPrefixesTableRecords) - 1) and
         (CompareCharBuffer(CTY.ctyPrefixesTable[last + 1].Prefix,
                            CTY.ctyPrefixesTable[Index].Prefix) = 0) do
      begin
      inc(last);
      end;

   if first = last then
      begin
      Exit;
      end;

   wantSub := CTY.ctyCountryMode = CQCountryMode;

   (* TWO KEYS, AND SPECIFICITY IS THE SENIOR ONE -- NY4I's rule in the order
     he stated it. A record flagged FullCallsigns came from an `=CALL`
     exception; one without it is a prefix. UA4H is filed BOTH ways under the
     same entity and with two different ITU zones:

         UA4H[30]     a prefix override, inside the UA block
         =UA4H[29]    an exact-callsign exception, also UA

     so for the callsign UA4H the exception wins and the answer is zone 29.
     The prefix walk asks for the opposite -- it is looking for what a
     SHORTENED prefix means, and must not be handed a whole callsign -- which
     is why the caller states which it wants rather than this routine assuming.

     The FIRST record of the run is the fallback, so a run whose records are
     all alike gives the same answer whichever mode is set, and the ARRL '*'
     filter in ctyLocateCall still rejects it exactly as before. *)
   Index := first;
   best := -1;
   for i := first to last do
      begin
      score := 0;
      if CTY.ctyPrefixesTable[i].FullCallsigns = PreferFullCallsign then
         begin
         inc(score, 2);
         end;
      if ctyIsSubEntity(i) = wantSub then
         begin
         inc(score, 1);
         end;

      if score > best then
         begin
         best := score;
         Index := i;
         end;
      end;
end;

function ctyFindCallsign(const s: PrefixName; var Index: integer;
                         PreferFullCallsign: boolean = True): boolean;
var
  l, h, i, c                            : integer;

begin
  Result := False;

//  l := 0;
//  h := CTY.ctyPrefixesTableRecords - 1;
   (* s is the BUFFER now, so the sentinel is tested by its bytes rather
     than by comparing a pointer against a literal. *)
   if (s[0] = '-') and (s[1] = #0) then
      begin
      logger.Debug('Exiting ctyFindCallsign early because s = -');
      Exit;
      end;


  l := CTY.ctyIndexArray[s[0]];
  h := CTY.ctyIndexArray[CHR(Ord(s[0]) + 1)];

  try
  while l <= h do
     begin
     i := (l + h) shr 1;

     (* CompareCharBuffer, not StrComp: the same unsigned byte order
       without taking the address of either buffer. The SIGN drives this
       binary search, which is why it is pinned against StrComp in
       uTestUtilsText rather than assumed. *)
     c := CompareCharBuffer(CTY.ctyPrefixesTable[i].Prefix, s);
     if c < 0 then l := i + 1 else
                                 begin
                                 h := i - 1;
                                 if c = 0 then
                                    begin
                                    Result := True;
                                    l := i;
                                    end;
                                 end;
     end;
  except
     logger.error('Exception in ctyFindCallsign s = %s',[CharBufferText(s)]);
  end;
  Index := l;

  (* A prefix can name two records. Which one it MEANS is decided here, by the
    rule above, and not by where the sort happened to leave them. *)
  if Result then
     begin
     ctyChooseAmongDuplicates(Index, PreferFullCallsign);
     end;
end;
{
}

function ctyLocateCall(Call: CallString; var QTH: QTHRecord): boolean;
label
  FillRecord;
var
  TempIndex                             : integer;
  TempPrefixRec                         : PrefixRecPtr;
  TempLength                            : integer;
  TempPrefix                            : PrefixName;
  TempPointer                           : integer;
  //StandardCall                          : CallString;
  GuantanamoBayCallsign                 : boolean;
begin
  TempIndex := 0;
  if Call = CTY.ctyLastLocatedCall then
     begin
     QTH := cty.ctyLastLocatedRecord;
     Result := True;
     Exit;
     end;

  Result := False;

  if Call[1] = '/' then Exit;

  FillChar(QTH, SizeOf(QTHRecord), 0);
  if length(Call) = 0 then Exit;

  (* SetCharBuffer does the copy AND the terminator AND the bound. The Move
    it replaces did the first two and not the third: it was safe only
    because CallstringLength (13) happens to equal High(PrefixName), so a
    full-length callsign fitted exactly and one character more would have
    written past the buffer. *)
  SetCharBuffer(TempPrefix, string(Call));

  QTH.StandardCall := StandardCallFormat(Call, True);

  GuantanamoBayCallsign := False;

  if QTH.StandardCall[1] = 'K' then
    if QTH.StandardCall[2] = 'G' then
      if QTH.StandardCall[3] = '4' then
        if length(QTH.StandardCall) <> 5 then
//        if (PInteger(@QTH.StandardCall)^ = $34474B04) or (PInteger(@QTH.StandardCall)^ = $34474B06) then
           begin
           TempPrefix[1] := 'A';
           GuantanamoBayCallsign := True;
           end;

//  MainUnit.showint(PInteger(@QTH.StandardCall)^);

  if ctyFindCallsign(TempPrefix, TempIndex) then
     begin
     //    asm nop end;

         if CTY.ctyCountryMode = ARRLCountryMode then
            begin
            if not ctyIsSubEntity(TempIndex) then
               begin
               goto FillRecord;
               end;
            end else
           goto FillRecord;
     end;

  if length(QTH.StandardCall) > 3 then
    if QTH.StandardCall[1] = 'M' then
      if QTH.StandardCall[2] = 'M' then
        if QTH.StandardCall[3] = '/' then Exit;

  if length(Call) = 1 then Exit;

  SetCharBuffer(TempPrefix, string(QTH.StandardCall));

  if GuantanamoBayCallsign then
     begin
     TempPrefix[1] := 'A';
     end;

  if TempPrefix[0] = 'R' then
//    if TempPrefix[1] in ['B'..'H','J'..'Z'] then
    if TempPrefix[1] in ['B'..'Z'] then
      if TempPrefix[2] <> '2' then
         begin
         TempPrefix[1] := 'A';
         end;

  if TempPrefix[0] = 'U' then
    if TempPrefix[1] in ['B'..'E', 'G'..'I'] then
       begin
       TempPrefix[1] := 'A';
       end;

  TempLength := length(QTH.StandardCall);

  if CTY.ctyMaxLengthIndexArray[TempPrefix[0]] < TempLength then
     begin
     TempLength := CTY.ctyMaxLengthIndexArray[TempPrefix[0]];
     end;

  for TempPointer := TempLength downto 1 do
     begin
     TempPrefix[TempPointer] := #0;
     (* Asking for a prefix: a run holding both an `=CALL` exception and a
       prefix override must yield the prefix one, or the test below throws
       the match away and the shorter prefixes never get their chance. *)
     if ctyFindCallsign(TempPrefix, TempIndex, False) then
        begin

        if CTY.ctyCountryMode = ARRLCountryMode then
           begin
           if ctyIsSubEntity(TempIndex) then Continue;
           end;

        if not CTY.ctyPrefixesTable[TempIndex].FullCallsigns then
           begin
           goto FillRecord;
           end;

        end;
     end;
  Exit;

  FillRecord:

  CTY.ctyLastIndex := TempIndex;

  TempPrefixRec := @CTY.ctyPrefixesTable[TempIndex];
  QTH.Continent := CTY.ctyTable[TempPrefixRec^.Country].DefaultContinent;

  QTH.CountryID := CTY.ctyTable[TempPrefixRec.Country].ID;
  QTH.Country := TempPrefixRec.Country;

  case CTY.ctyZoneMode of
    ITUZoneMode: QTH.Zone := TempPrefixRec.ITUZone;
    CQZoneMode: QTH.Zone := TempPrefixRec.CQZone;
  end;

  if QTH.Zone = 0 then
     begin
     case CTY.ctyZoneMode of
       ITUZoneMode: QTH.Zone := CTY.ctyTable[QTH.Country].DefaultITUZone;
       CQZoneMode: QTH.Zone := CTY.ctyTable[QTH.Country].DefaultCQZone;
     end;
     end;

//  QTH.Zone := TempPrefixRec.CQZone;

  QTH.Prefix := GetPrefix(QTH.StandardCall);
{
  if CTY.ctyR150SMode then
    if QTH.Country = CTY.ctyUA9Country then
    begin
      QTH.Country := CTY.ctyUA3Country;
      QTH.CountryID := 'UA';
    end;
}
  Result := True;
  CTY.ctyLastLocatedCall := Call;
  CTY.ctyLastLocatedRecord := QTH;
end;

function ctyGetGrid(const Call: string; var ID: DXMultiplierString): string;
var
  TempInteger                           : integer;
  TempChar                              : Char;
 // TempFourChar                          : FourChar;
  Oblast                                : Str2;
begin
  if ctyLocateCall(Call, CTY.ctyTempQTHRecord) then
     begin
     ID := CTY.ctyTempQTHRecord.CountryID;

     for TempInteger := 1 to GridsArraysCount do
       if ID = GridsIndexArray[TempInteger] then
          begin
          TempChar := Char(GetNumber(Call));
          if TempChar in ['0'..'9'] then
             begin
             Result := GridsArray[TempInteger][TempChar];
             if Result <> '' then Exit;
             end;
          end;

     if Copy(ID, 1, 2) = 'UA' then
        begin
        Oblast := GetOblast(Call);
        if length(Oblast) = 2 then
           begin
           if (Oblast[2] in ['A'..'Z']) {and (Oblast[1] <> '2')} then
              begin
              Result := RussianGrids[Oblast[2]][Oblast[1]];
              if Result <> '' then Exit;
              end;
           end;
        end;

     Result := CTY.ctyTable[CTY.ctyTempQTHRecord.Country].DefaultGrid;
     end
  else
     begin
     Result := '';
     end;
end;

function ctyGetContinent(const Call: string): ContinentType;
begin
  if ctyLocateCall(Call, CTY.ctyTempQTHRecord) then
     begin
     Result := CTY.ctyTable[CTY.ctyTempQTHRecord.Country].DefaultContinent
     end
  else
     begin
     Result := UnknownContinent;
     end;
end;

function ctyGetCountry(const Call: string): Word;
begin
  if ctyLocateCall(Call, CTY.ctyTempQTHRecord) then
     begin

     Result := CTY.ctyTempQTHRecord.Country;

     end
  else
     begin
     Result := UNKNOWN_COUNTRY;
     end;
end;

function ctyGetCountryIdByIndex(Country: Word): string;
begin
  // Result is '' by default (native string); no ZeroMemory buffer-clear needed.
  if Country = UNKNOWN_COUNTRY then Exit;
  Result := CTY.ctyTable[Country].ID;
end;

function ctyGetContinentByIndex(Country: Word): ContinentType;
begin
  if Country = UNKNOWN_COUNTRY then
     begin
     Result := UnknownContinent
     end
  else
     begin
     Result := CTY.ctyTable[Country].DefaultContinent;
     end;
end;

function ctyGetDefaultGrid(Country: Word): string;
begin
  // Result is '' by default (native string); no ZeroMemory buffer-clear needed.
  if Country = UNKNOWN_COUNTRY then Exit;
  Result := CTY.ctyTable[Country].DefaultGrid;
end;

function ctyGetDefaultITUZone(Country: Word): Byte;
begin
  Result := 0;
  if Country = UNKNOWN_COUNTRY then Exit;
  Result := CTY.ctyTable[Country].DefaultITUZone;
end;

function ctyGetDefaultCQZone(Country: Word): Byte;
begin
  Result := 0;
  if Country = UNKNOWN_COUNTRY then Exit;
  Result := CTY.ctyTable[Country].DefaultCQZone;
end;

function ctyGetCountryUTCOffset(Country: Word): Smallint;
begin
  Result := 0;
  if Country = UNKNOWN_COUNTRY then Exit;
  Result := CTY.ctyTable[Country].UTCOffset;
end;

(* ===========================================================================
  THE ZONE RULES, AS DATA.

  These were 247 lines of nested if/case inside ctyGetZone, one arm per
  country, written twice -- once for ITU zones and once for CQ zones. They are
  not logic. Every one of them says the same thing:

      for country C, in zone mode M, a station whose DISTRICT DIGIT is d
      (and/or whose FIRST SUFFIX LETTER is one of L) is in zone Z.

  So that is what the table says, and one 20-line resolver reads it. The rules
  below are in the SAME ORDER as the code they replace and FIRST MATCH WINS,
  which is how the original behaved: an inner `else` arm is a row with the
  district pinned and no letters, and an outer `else` is a row with neither.

  WHY IT IS WORTH MOVING. A rule expressed as code can only be read by
  executing it in your head, and nothing can enumerate it -- there was no way
  to ask "which countries have a zone rule" or "is this branch reachable"
  except by eye over 247 lines. As data it can be counted, listed, and covered:
  test/tools/ctygen/genzone.py walks this shape to generate a callsign for
  every branch, which is how all 366 of them ended up in the characterisation
  fixture.

  AND SOME OF THESE ROWS ARE DEAD. ctyGetZone returns the PREFIX RECORD'S zone
  when cty.dat supplies one and only falls through to these rules when it does
  not -- so UA8T, for instance, answers 30 from the file and never reaches the
  row below that says 32. Which rows are dead depends on the cty.dat in use,
  so they stay: a row that cannot fire today can fire against a different file.
  =========================================================================== *)
type
  TZoneRule = record
    Countries : string;   (* one or more country IDs, space separated *)
    Mode      : ZoneModeType;
    District  : Char;     (* #0 matches any district digit       *)
    Letters   : string;   (* '' matches any first suffix letter  *)
    Zone      : Byte;
  end;

const
  ZONE_RULES: array[0..95] of TZoneRule = (

    (* ---- ITU ------------------------------------------------------- *)
    (Countries: 'K';       Mode: ITUZoneMode; District: '5'; Letters: '';     Zone: 7),
    (Countries: 'K';       Mode: ITUZoneMode; District: '0'; Letters: '';     Zone: 7),
    (Countries: 'K';       Mode: ITUZoneMode; District: '6'; Letters: '';     Zone: 6),
    (Countries: 'K';       Mode: ITUZoneMode; District: '7'; Letters: '';     Zone: 6),
    (Countries: 'K';       Mode: ITUZoneMode; District: #0;  Letters: '';     Zone: 8),

    (Countries: 'BY';      Mode: ITUZoneMode; District: '8'; Letters: '';     Zone: 43),
    (Countries: 'BY';      Mode: ITUZoneMode; District: '9'; Letters: '';     Zone: 43),
    (Countries: 'BY';      Mode: ITUZoneMode; District: '0'; Letters: '';     Zone: 42),
    (Countries: 'BY';      Mode: ITUZoneMode; District: #0;  Letters: '';     Zone: 44),

    (* CE has no else arm: districts 0 and 9 fall through to the default. *)
    (Countries: 'CE';      Mode: ITUZoneMode; District: '1'; Letters: '';     Zone: 14),
    (Countries: 'CE';      Mode: ITUZoneMode; District: '2'; Letters: '';     Zone: 14),
    (Countries: 'CE';      Mode: ITUZoneMode; District: '3'; Letters: '';     Zone: 14),
    (Countries: 'CE';      Mode: ITUZoneMode; District: '4'; Letters: '';     Zone: 14),
    (Countries: 'CE';      Mode: ITUZoneMode; District: '5'; Letters: '';     Zone: 14),
    (Countries: 'CE';      Mode: ITUZoneMode; District: '6'; Letters: '';     Zone: 16),
    (Countries: 'CE';      Mode: ITUZoneMode; District: '7'; Letters: '';     Zone: 16),
    (Countries: 'CE';      Mode: ITUZoneMode; District: '8'; Letters: '';     Zone: 16),

    (Countries: 'CP';      Mode: ITUZoneMode; District: '1'; Letters: '';     Zone: 12),
    (Countries: 'CP';      Mode: ITUZoneMode; District: '8'; Letters: '';     Zone: 12),
    (Countries: 'CP';      Mode: ITUZoneMode; District: '9'; Letters: '';     Zone: 12),
    (Countries: 'CP';      Mode: ITUZoneMode; District: #0;  Letters: '';     Zone: 14),

    (Countries: 'LU';      Mode: ITUZoneMode; District: #0;  Letters: 'VWX';  Zone: 16),
    (Countries: 'LU';      Mode: ITUZoneMode; District: #0;  Letters: '';     Zone: 14),

    (Countries: 'PY';      Mode: ITUZoneMode; District: '6'; Letters: '';     Zone: 13),
    (Countries: 'PY';      Mode: ITUZoneMode; District: '7'; Letters: '';     Zone: 13),
    (Countries: 'PY';      Mode: ITUZoneMode; District: '8'; Letters: '';     Zone: 13),
    (Countries: 'PY';      Mode: ITUZoneMode; District: #0;  Letters: '';     Zone: 15),

    (Countries: 'UN';      Mode: ITUZoneMode; District: #0;  Letters: 'JDVG'; Zone: 31),
    (Countries: 'UN';      Mode: ITUZoneMode; District: #0;  Letters: '';     Zone: 30),

    (* UA and UA9 shared ONE arm in the original, hence one row each here. *)
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '1'; Letters: 'NZO';  Zone: 19),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '1'; Letters: '';     Zone: 29),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '3'; Letters: '';     Zone: 29),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '6'; Letters: '';     Zone: 29),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '4'; Letters: 'ACFLNQSUY'; Zone: 29),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '4'; Letters: 'HPW';  Zone: 30),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '8'; Letters: 'T';    Zone: 32),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '8'; Letters: 'V';    Zone: 33),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '9'; Letters: 'ACFGLMQSTW'; Zone: 30),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '9'; Letters: 'HOUYZ'; Zone: 31),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '9'; Letters: 'JK';   Zone: 21),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '9'; Letters: 'X';    Zone: 20),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '0'; Letters: 'BH';   Zone: 22),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '0'; Letters: 'Q';    Zone: 23),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '0'; Letters: 'I';    Zone: 24),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '0'; Letters: 'X';    Zone: 25),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '0'; Letters: 'K';    Zone: 26),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '0'; Letters: 'AORSWY'; Zone: 32),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '0'; Letters: 'DJU';  Zone: 33),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '0'; Letters: 'CFL';  Zone: 34),
    (Countries: 'UA UA9';  Mode: ITUZoneMode; District: '0'; Letters: 'Z';    Zone: 35),

    (* VE's else arm assigned 0, which means "no answer" -- the same thing
      omitting it would mean, so it is simply absent here. *)
    (Countries: 'VE';      Mode: ITUZoneMode; District: '1'; Letters: '';     Zone: 9),
    (Countries: 'VE';      Mode: ITUZoneMode; District: '9'; Letters: '';     Zone: 9),
    (Countries: 'VE';      Mode: ITUZoneMode; District: '2'; Letters: '';     Zone: 4),
    (Countries: 'VE';      Mode: ITUZoneMode; District: '3'; Letters: '';     Zone: 4),
    (Countries: 'VE';      Mode: ITUZoneMode; District: '4'; Letters: '';     Zone: 3),
    (Countries: 'VE';      Mode: ITUZoneMode; District: '5'; Letters: '';     Zone: 3),
    (Countries: 'VE';      Mode: ITUZoneMode; District: '6'; Letters: '';     Zone: 2),
    (Countries: 'VE';      Mode: ITUZoneMode; District: '7'; Letters: '';     Zone: 2),

    (Countries: 'VK';      Mode: ITUZoneMode; District: '4'; Letters: '';     Zone: 55),
    (Countries: 'VK';      Mode: ITUZoneMode; District: '8'; Letters: '';     Zone: 55),
    (Countries: 'VK';      Mode: ITUZoneMode; District: '6'; Letters: '';     Zone: 58),
    (Countries: 'VK';      Mode: ITUZoneMode; District: #0;  Letters: '';     Zone: 59),

    (Countries: 'K';       Mode: CQZoneMode; District: '1'; Letters: '';      Zone: 5),
    (Countries: 'K';       Mode: CQZoneMode; District: '2'; Letters: '';      Zone: 5),
    (Countries: 'K';       Mode: CQZoneMode; District: '3'; Letters: '';      Zone: 5),
    (Countries: 'K';       Mode: CQZoneMode; District: '4'; Letters: '';      Zone: 5),
    (Countries: 'K';       Mode: CQZoneMode; District: '5'; Letters: '';      Zone: 4),
    (Countries: 'K';       Mode: CQZoneMode; District: '8'; Letters: '';      Zone: 4),
    (Countries: 'K';       Mode: CQZoneMode; District: '9'; Letters: '';      Zone: 4),
    (Countries: 'K';       Mode: CQZoneMode; District: '0'; Letters: '';      Zone: 4),
    (Countries: 'K';       Mode: CQZoneMode; District: '6'; Letters: '';      Zone: 3),
    (Countries: 'K';       Mode: CQZoneMode; District: '7'; Letters: '';      Zone: 3),

    (Countries: 'VE';      Mode: CQZoneMode; District: '1'; Letters: '';      Zone: 5),
    (Countries: 'VE';      Mode: CQZoneMode; District: '2'; Letters: '';      Zone: 5),
    (Countries: 'VE';      Mode: CQZoneMode; District: '9'; Letters: '';      Zone: 5),
    (Countries: 'VE';      Mode: CQZoneMode; District: '0'; Letters: '';      Zone: 5),
    (Countries: 'VE';      Mode: CQZoneMode; District: '3'; Letters: '';      Zone: 4),
    (Countries: 'VE';      Mode: CQZoneMode; District: '4'; Letters: '';      Zone: 4),
    (Countries: 'VE';      Mode: CQZoneMode; District: '5'; Letters: '';      Zone: 4),
    (Countries: 'VE';      Mode: CQZoneMode; District: '6'; Letters: '';      Zone: 4),
    (Countries: 'VE';      Mode: CQZoneMode; District: '7'; Letters: '';      Zone: 3),
    (Countries: 'VE';      Mode: CQZoneMode; District: '8'; Letters: '';      Zone: 2),

    (* CQ mode names UA9 ONLY -- not UA -- unlike the ITU arm above. *)
    (Countries: 'UA9';     Mode: CQZoneMode; District: '8'; Letters: '';      Zone: 18),
    (Countries: 'UA9';     Mode: CQZoneMode; District: '9'; Letters: 'ACDFGJKLMNQRSTWX'; Zone: 17),
    (Countries: 'UA9';     Mode: CQZoneMode; District: '9'; Letters: 'HOUYZ'; Zone: 18),
    (Countries: 'UA9';     Mode: CQZoneMode; District: '0'; Letters: 'ABHORSUW'; Zone: 18),
    (Countries: 'UA9';     Mode: CQZoneMode; District: '0'; Letters: 'Y';     Zone: 23),
    (Countries: 'UA9';     Mode: CQZoneMode; District: '0'; Letters: '';      Zone: 19),

    (Countries: 'BY';      Mode: CQZoneMode; District: '3'; Letters: 'GHIJKL'; Zone: 23),
    (Countries: 'BY';      Mode: CQZoneMode; District: '9'; Letters: 'MNPQRS'; Zone: 24),
    (Countries: 'BY';      Mode: CQZoneMode; District: '9'; Letters: '';      Zone: 23),
    (Countries: 'BY';      Mode: CQZoneMode; District: '0'; Letters: '';      Zone: 23),
    (Countries: 'BY';      Mode: CQZoneMode; District: #0;  Letters: '';      Zone: 24),

    (Countries: 'VK';      Mode: CQZoneMode; District: '6'; Letters: '';      Zone: 29),
    (Countries: 'VK';      Mode: CQZoneMode; District: '8'; Letters: '';      Zone: 29),
    (Countries: 'VK';      Mode: CQZoneMode; District: #0;  Letters: '';      Zone: 30)
  );







(* Does one rule describe this station? *)
function ZoneRuleMatches(const aRule: TZoneRule; const aID: string;
                         aDistrict, aLetter: Char; aMode: ZoneModeType): boolean;
begin
   Result := False;
   if aRule.Mode <> aMode then Exit;

   (* Space-delimited so 'UA' cannot match inside 'UA9'. *)
   if Pos(' ' + aID + ' ', ' ' + aRule.Countries + ' ') = 0 then Exit;

   if (aRule.District <> #0) and (aRule.District <> aDistrict) then Exit;
   if (aRule.Letters <> '') and (Pos(aLetter, aRule.Letters) = 0) then Exit;

   Result := True;
end;

function ctyGetZone(const Call: string): Byte;
var
  TempPrefixRec : PrefixRecPtr;
  id            : string;
  district      : Char;
  letter        : Char;
  i             : integer;
begin
  if not ctyLocateCall(Call, CTY.ctyTempQTHRecord) then
     begin
     Result := DUMMYZONE;
     Exit;
     end;

  TempPrefixRec := @CTY.ctyPrefixesTable[CTY.ctyLastIndex];

  (* THE FILE ANSWERS FIRST, and that has not changed: when cty.dat carries a
    zone for this prefix it wins outright, and the rules below never run. It is
    why several of them are unreachable against the shipped file. *)
  case CTY.ctyZoneMode of
     ITUZoneMode:
        if TempPrefixRec^.ITUZone <> 0 then
           begin
           Result := TempPrefixRec^.ITUZone;
           Exit;
           end;
     CQZoneMode:
        if TempPrefixRec^.CQZone <> 0 then
           begin
           Result := TempPrefixRec^.CQZone;
           Exit;
           end;
  end;

  Result   := 0;
  id       := string(CTY.ctyTempQTHRecord.CountryID);
  district := GetNumber(Call);
  letter   := GetFirstSuffixLetter(Call);

  (* FIRST MATCH WINS, in table order, which is the order the if/case
    chain tested in. A row with no letters is an inner `else` arm; a row
    with neither a district nor letters is an outer one. *)
  for i := Low(ZONE_RULES) to High(ZONE_RULES) do
     begin
     if ZoneRuleMatches(ZONE_RULES[i], id, district, letter, CTY.ctyZoneMode) then
        begin
        Result := ZONE_RULES[i].Zone;
        Break;
        end;
     end;

  (* No rule answered: the country's own default. *)
  if Result = 0 then
     begin
     case CTY.ctyZoneMode of
        ITUZoneMode: Result := CTY.ctyTable[CTY.ctyTempQTHRecord.Country].DefaultITUZone;
        CQZoneMode:  Result := CTY.ctyTable[CTY.ctyTempQTHRecord.Country].DefaultCQZone;
     end;
     end;
end;

function ctyGetITUZone(const Call: string): Byte;
var
  TempZoneModeType                      : ZoneModeType;
begin
  TempZoneModeType := CTY.ctyZoneMode;
  CTY.ctyZoneMode := ITUZoneMode;
  Result := ctyGetZone(Call);
  CTY.ctyZoneMode := TempZoneModeType;
end;

function ctyGetCQZone(const Call: string): Byte;
var
  TempZoneModeType                      : ZoneModeType;
begin
  TempZoneModeType := CTY.ctyZoneMode;
  CTY.ctyZoneMode := CQZoneMode;
  Result := ctyGetZone(Call);
  CTY.ctyZoneMode := TempZoneModeType;
end;

(* WAS ctyGetCountryNamePchar, handing out the ADDRESS of a table entry.
  Every one of its four callers immediately made a string of it, and one
  assigned the pointer straight to an LCL Caption -- so the pointer was
  never what any of them wanted, and it was live for exactly as long as the
  table was not reloaded. Name is a NUL-terminated buffer, so CharBufferText
  reads it through its own bounds.

  ctyGetCountryIdPchar went with it: it had NO caller anywhere in the tree.
  ctyGetCountryIdByIndex already returns the same field as a string. *)
function ctyGetCountryName(Index: Word): string;
begin
  if Index < CTY.ctyNumberCountries then
     begin
     Result := CharBufferText(CTY.ctyTable[Index].Name);
     end
  else
     begin
     Result := '';
     end;
end;


function ctyGetCountryID(const Call: string): string;
begin
  if ctyLocateCall(Call, CTY.ctyTempQTHRecord) then
     begin
     Result := CTY.ctyTempQTHRecord.CountryID
     end
  else
     begin
     Result := '';
     end;
end;


(* The tail of cty.dat from the REMAINING MULTS marker onward: a list of
  entity ids, separated by whitespace, commas or semicolons, naming the
  entities the remaining-multiplier windows should list.

  WAS A POINTER WALK over up to 4096 bytes with a hand-rolled tokeniser,
  StrUpper on a stack buffer and StrComp against @ID[1]. That last one was the
  same ShortString-read-as-NUL-terminated mistake postunit had: ID carries a
  LENGTH, so StrComp ran past the field. Every id in this file is ASCII, so
  the whole thing is string work. *)
procedure ctyLoadInRemainingMults(const aSection: AnsiString);
var
  i        : integer;
  token    : AnsiString;

   procedure ApplyToken;
   var
      c : integer;
   begin
      if token = '' then
         begin
         Exit;
         end;

      for c := 0 to MaxCountries - 1 do
         begin
         if UpperCase(Trim(AnsiString(CTY.ctyTable[c].ID))) = token then
            begin
            CTY.ctyTable[c].VisibleInRM := 2;
            CTY.ctyCustomRemainingCountryListFound := True;
            Break;
            end;
         end;
      token := '';
   end;

begin
  token := '';

  (* The marker itself is the first token and matches no entity id, so it
    falls out of ApplyToken without being special-cased. *)
  for i := 1 to Length(aSection) do
     begin
     if aSection[i] in ['*', 'A'..'Z', 'a'..'z', '0'..'9', '/'] then
        begin
        token := token + UpperCase(aSection[i]);
        end
     else
        begin
        ApplyToken;
        end;
     end;

  (* The file may end without a delimiter after the last id. *)
  ApplyToken;
end;

function ctyGetTotalCountries(): integer;
begin
  Result := CTY.ctyNumberCountries;
end;

(* The version stamp cty.dat carries in its own text -- 16 NUL-terminated
  bytes, returned as text rather than as a pointer at them. *)
function ctyGetVersion: string;
begin
  Result := CharBufferText(CTY.ctyVersion);
end;

function ctyIsActiveMultiplier(Index: Word): boolean;
begin
  Result := CTY.ctyTable[Index].VisibleInRM <> 1;
end;

procedure ctySetCountryMode(CountryMode: CountryModeType);
begin
  CTY.ctyCountryMode := CountryMode;
end;

procedure ctyLoadInR150SList;
//var
  //TempIndex                             : integer;
 // TempRec                               : PrefixRecPtr;
begin
  (* The flag it used to set here is the SETTING that got us called -- this
    routine has one caller and it is gated on that setting. Writing it back
    was redundant, and now it would mean a country-file loader writing a
    contest parameter. *)
  SetCharBuffer(TR4W_R150S_FILENAME, CharBufferText(TR4W_PATH_NAME) + 'r150s.dat');   // Issue #1033: was TF.Format(=wsprintfA)
  ctyLoadInCountryFile(CharBufferText(TR4W_R150S_FILENAME), True, False);

end;

procedure ctyLoadInRFOblList;
//var
  //TempIndex                             : integer;
  //TempRec                               : PrefixRecPtr;
begin
  // See ctyLoadInR150SList: the same redundant write, for the same reason.
  SetCharBuffer(TR4W_rfobl_FILENAME, CharBufferText(TR4W_PATH_NAME) + 'rfobl.dat');   // Issue #1033: was TF.Format(=wsprintfA)
  ctyLoadInCountryFile(CharBufferText(TR4W_rfobl_FILENAME), True, False);

end;

initialization
   // Own Log4D logger (see Issue #1033 note above) -- replaces the former
   // MainUnit.logger borrow. GetLogger is safe before Log4D is configured.
   logger := TLogLogger.GetLogger('uCTYDAT');

end.


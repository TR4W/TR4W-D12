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
unit uCallSignRoutines;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
{
  Phase 2.5 (D12 string modernization PoC): this leaf, ASCII-only callsign
  parser is the first module flipped from the ANSI byte core to native Delphi
  `string`/`Char`.  Callsigns are ASCII, so UTF-16 `pos`/`Copy`/comparison are
  semantically identical.  Three ANSI byte-level idioms were rewritten to
  provably-equivalent char logic (they would misbehave on a wide `string`):
    * GetOblast / GetRussiaOblastID: `Result[0]:=#2; Result[1]:=..` ShortString
      length-byte writes -> `Result := c1 + c2` string build.
    * StandardCallFormat: `PWORD(@Call[l-2])^ = $412F` ("/A") and
      `PInteger(@Call[l-3])^ = $5052512F` ("/QRP") byte-pattern reads ->
      explicit char comparisons.
    * GoodCallSyntax: `uStrSearch.StrU(Call)` (var ShortString) -> `UpperCase`
      (ASCII-only in the RTL; identical for callsigns), dropping uStrSearch.
  Callers pass ContestExchange.Callsign (ShortString) into the `string` params;
  Delphi auto-converts ShortString<->string at the call site -- lossless for
  ASCII callsigns.  Behavior is byte-identical (proven by uTestCallSignRoutines
  + the golden-master oracle).
}
interface
uses
  uRussiaOblasts,
  // Tree,
  utils_text,      // UpperCase (ANSI ShortString) -- also replaces uStrSearch.StrU (var ShortString)
  VC,
  Windows;
const
  ARRLSectionCountryString              = ' K VE KC6 KG4 KL KH0 KH1 KH2 KH3 KH4 KH5 KH6 KH7 KH8 KH9 KP1 KP2 KP3 KP4 KP5 ';
  BlackSeaCountriesString               = ' OE ZA EU LZ E7 HA DL 4L I Z3 ER SP UA YO OM S5 TA UR 9A 4O OK HB YU ';
  CISCountries                          = ' UA UA2 UA9 UR EU 4J EK UN EX ER EY EZ UK 4L ';
  UBAEuroCountryString                  = ' 5B 9A 9H CT CT3 CU DL EA EA6 EA8 EI ES F FG FM FR FY  HA I IS LX LY LZ OE OH OH0 OJ0 OK OM OZ PA S5 SM SP SV SV/A SV5 SV9 SY TK YL YO ';   // 4.106.5
  ScandinavianCountries                 = ' LA JW JX OH OH0 OJ0 OX OY OZ SM TF ';
  IndonesianCountries                   = ' YB YC YD YE YF ';           // 4.64.1
function ARRLSectionCountry(CountryID: string): boolean;
function BlackSeaRegionCountry(CountryID: string): boolean;
function CISCountry(CountryID: string): boolean;
function UBACountry(CountryID: string): boolean;
function ScandinavianCountry(CountryID: string): boolean;
function IndonesianCountry(CountryID: string): boolean;
function GetNumber(Call: string): Char;
function GetFirstSuffixLetter(Call: string): Char;
function RussianID(ID: string): boolean;
function FrenchID(ID: string): boolean;
function SpanishStation(ID: string): boolean;
function OKOMStation(ID: string): boolean;
function UKEIStation(ID: string): boolean;
function GetPrefix(Call: string): string;
function GetOblast(Call: string): string;
function MobileCall(Call: string): boolean;  //n4af 4.41.8
//function IsUA1AStation(Call: string): boolean;
function StandardCallFormat(Call: string; Complete: boolean): string;
function GetRussiaOblastID(Call: string): string; //
function CaliforniaCall(Call: string): boolean;
function RootCall(Call: string): string;
function RoverCall(Call: string): boolean;
function SimilarCall(Call1: string; Call2: string): boolean;
// TRUE when this looks like a real callsign.
//
// RENAMED from GoodCallSyntax (NY4I, 2026-08-21) to match the house naming for
// predicates, and it is now the ONE callsign validator in TR4W: the RX_CALLSIGN
// regular expression in LOGSTUFF was retired in favour of it.
//
// MEASURED, not asserted (tr4w\test\bench\bench_callsign.dpr, over the 234,467
// callsigns in ARRL's LOTW activity file):
//
//   IsAGoodCall              327 ns/call   accepted 234,466 of 234,467
//   RX_CALLSIGN            1,367 ns/call   accepted 234,335
//   a 725-branch ITU prefix regex  21,524 ns/call   accepted 203,101
//
// So this is four times faster than the pattern it replaced AND a strict
// SUPERSET of it: of the 234,467, there are 131 that this accepts and
// RX_CALLSIGN refused -- 3DA/G3SXW, 3DA0/ZS6BCR, 5JSTAYHOME, 5VDE,
// 7L3DNX/1/QRP -- and NOT ONE that RX_CALLSIGN accepted and this refuses. The
// regex was stricter in the wrong direction: DX prefix-portables, special-event
// calls and double suffixes are exactly what a contest logger sees.
//
// The single call in that corpus this refuses is 2SZ, whose last activity was
// 2014 and which matches no current callsign format. Deliberately still refused
// (NY4I): "I am not changing it for one call that does not follow any standard."
function IsAGoodCall(Call: string): boolean;

// Does this callsign carry a US prefix -- A, W, K or N?  Together with
// IsAGoodUSCall this is the two-tier test the operator-login field applies:
// anything that LOOKS American is then held to the stricter US form.
function IsAUSPrefix(const Call: string): boolean;

// The strict US form: prefix letter, optional second letter, one digit, then
// one to three letters.  W1AW, K5ZZ, KC2ABC, N0AX.
//
// OPEN QUESTION, DELIBERATELY NOT ANSWERED HERE (NY4I, 2026-08-21).  "US" is
// not one idea, and this routine quietly picks one of them:
//
//   * By CALLSIGN FORM -- what this does. KL7 and KH6 have US prefix letters,
//     so they answer True.
//   * By DXCC ENTITY -- what CTY.DAT says. Alaska and Hawaii are their OWN
//     entities, separate from the continental US.
//   * By 50-STATE MEMBERSHIP -- what several contests actually mean, where AK
//     and HI ARE states and count as such.
//
// Which one is right DEPENDS ON THE CONTEST, so it cannot be settled by a
// callsign routine at all. The likely shape is a second predicate --
// IsAGoodUSCall50State, or whatever the contest factory ends up calling it --
// answering the states question from CTY.DAT rather than from letters. That
// belongs with the contest factory; it is recorded here because THIS is the
// routine somebody will reach for when they hit the question.
//
// Its one caller today is the operator-login field, which only wants "does
// this look like a well-formed US call" -- so the ambiguity does not bite yet.
function IsAGoodUSCall(const Call: string): boolean;
function ValidCallCharacter(CallChar: Char): boolean;
implementation
uses uCTYDAT;
function ARRLSectionCountry(CountryID: string): boolean;
begin
  Result := False;
  if pos(' ' + CountryID + ' ', ARRLSectionCountryString) <> 0 then
     begin
     Result := True;
     end;
end;
function BlackSeaRegionCountry(CountryID: string): boolean;
begin
  Result := False;
  if pos(' ' + CountryID + ' ', BlackSeaCountriesString) <> 0 then
     begin
     Result := True;
     end;
end;
function CISCountry(CountryID: string): boolean;
begin
  Result := False;
  if pos(' ' + CountryID + ' ', CISCountries) <> 0 then
     begin
     Result := True;
     end;
end;
function UBACountry(CountryID: string): boolean;
begin
  Result := pos(' ' + CountryID + ' ', UBAEuroCountryString) <> 0;
end;
function ScandinavianCountry(CountryID: string): boolean;
begin
  Result := False;
  if pos(' ' + CountryID + ' ', ScandinavianCountries) <> 0 then
     begin
     Result := True;
     end;
end;
function IndonesianCountry(CountryID: string): boolean;         // 4.64.1
begin
  Result := False;
  if pos(' ' + CountryID + ' ', IndonesianCountries) <> 0 then
     begin
     Result := True;
     end;
end;
function GetNumber(Call: string): Char;
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
    if Call[CharPtr] in ['0'..'9'] then
       begin
       GetNumber := Call[CharPtr];
       Exit;
       end ;
  GetNumber := #0;
end;
function GetFirstSuffixLetter(Call: string): Char;
{ This function will get the first letter after the last number in the
  callsign or portable designator.  If the call does not have a letter
  after the last number, or if the portable designator does not have
  it, a null character will be returned.                             }
var
  CharPtr                               : integer;
  TempString                            : string;
begin
  if StringHas(Call, '/') then
     begin
     TempString := PostcedingString(Call, '/');
     GetFirstSuffixLetter := GetFirstSuffixLetter(TempString);
     end
  else
     begin
     for CharPtr := length(Call) - 1 downto 1 do
       if Call[CharPtr] in ['0'..'9'] then
          begin
          GetFirstSuffixLetter := Call[CharPtr + 1];
          Exit;
          end;
   GetFirstSuffixLetter := #0;
     end;
end;
function OKOMStation(ID: string): boolean;
begin
  Result := False;
  if length(ID) > 1 then
    if ID[1] = 'O' then if
      ID[2] in ['K', 'M'] then Result := True;
end;
function UKEIStation(ID: string): boolean;  // 4.58.2
begin
  Result := False;
//  if length(ID) > 1 then
    if ((ID[1] = 'G') or (ID[1] = 'M') or ((ID[1] = 'E') and (ID[2] = 'I')) or (ID[1] = '2')) then
       begin
       Result := True;
       end;
end;
function SpanishStation(ID: string): boolean;
begin
  Result := False;
  if length(ID) > 1 then
    if ID[1] = 'E' then if
      ID[2] = 'A' then Result := True;
end;
function FrenchID(ID: string): boolean;
begin
  Result := (ID[1] = 'F') or (ID = 'TM') or (ID = 'TK');
end;
function RussianID(ID: string): boolean;
begin
  Result := False;
  if length(ID) > 1 then
     begin
     if ID[1] = 'R' then
        begin
        Result := True;
        end;
     if ID[1] = 'U' then if ID[2] = 'A' then Result := True;
     end;
end;
{
function getRussianRegion(Callsign: CallString): RussianRegionType;
begin
  result := rtUnknownRegion;
  Result := False;
  if length(ID) > 1 then
  begin
    if ID[1] = 'R' then Result := True;
    if ID[1] = 'U' then if ID[2] = 'A' then Result := True;
  end;
end;
}
function StandardCallFormat(Call: string; Complete: boolean): string;
{ This fucntion will take the call passed to it and put it into a
  standard format with the country indicator as the first part of
  the call.  It is intended to convert calls as they would be sent
  on the air to N6TR duping service perferred format.  This means
  that a callsign as normally sent on the air would be converted to
  a callsign that can be passed to GetCountry, GetContinent, GetZone
  and so on with probable success.
  A change made on 4 November adds the complete flag.  If the flag is
  TRUE, the routine works the way it always has.  If the flag is false,
  the call is unchanged if the call has a single integer after the / sign.
  This is intended to eliminate problems with KC8UNP/6 showing up as
  KC6/KC8UNP which gets reported as the Carolines. }
label
  1;
var

  FirstPart, SecondPart                 : string;
  TempPrefixString                      : string;
  l                                     : integer;
begin
  if not StringHas(Call, '/') then
     begin
     StandardCallFormat := Call;
     Exit;
     end;
  l := length(Call);
  {/P /M /N /T}
  if l > 2 then if Call[l - 1] = '/' then if Call[l] in ['P', 'M', 'N', 'T'] then
                                             begin
                                             SetLength(Call, l - 2);
                                             goto 1;
                                             end;
  {/AG /AA /AE}  // was PWORD(@Call[l-2])^ = $412F ("/A"); rewritten for `string`
  if l > 3 then if (Call[l - 2] = '/') and (Call[l - 1] = 'A') then if Call[l] in ['A', 'G', 'E'] then
                                                                       begin
                                                                       SetLength(Call, l - 3);
                                                                       goto 1;
                                                                       end;
  {/QRP}  // was PInteger(@Call[l-3])^ = $5052512F ("/QRP"); rewritten for `string`
  if l > 4 then if (Call[l - 3] = '/') and (Call[l - 2] = 'Q') and (Call[l - 1] = 'R') and (Call[l] = 'P') then
                   begin
                   SetLength(Call, l - 4);
                   goto 1;
                   end;
  1:
  if not StringHas(Call, '/') then
     begin
     StandardCallFormat := Call;
     Exit;
     end;
  FirstPart := PrecedingString(Call, '/');
  SecondPart := PostcedingString(Call, '/');
  if SecondPart = 'MOBILE' then {KK1L: 6.71 Added per Tree request}
     begin
     StandardCallFormat := FirstPart;
     Exit;
     end;
  if SecondPart = 'MM' then
     begin
     StandardCallFormat := 'MM/' + FirstPart;
     Exit;
     end;
  if SecondPart = 'R' then
     begin
     StandardCallFormat := FirstPart + '/' + SecondPart;
     Exit;
     end;

  if length(Call) = 11 then if (Call[1] = 'V') and (Call[2] = 'U') and (Call[7] = '/') then if Call[8] in ['0', '9'] then
                                                                                               begin
                                                                                               StandardCallFormat := Call;
                                                                                               Exit;
                                                                                               end;
  if length(SecondPart) = 1 then
    if SecondPart[1] in ['0'..'9'] then
       begin
       if Complete then
          begin
          TempPrefixString := GetPrefix(FirstPart);
          Delete(TempPrefixString, length(TempPrefixString), 1);
          SecondPart := TempPrefixString + SecondPart;
          StandardCallFormat := SecondPart + '/' + FirstPart;
          end
       else
          begin
          StandardCallFormat := Call;
          end;
       Exit;
       end
    else
       begin
       if SecondPart[1] in ['F', 'G', 'I', 'K', 'N', 'W'] then
          begin
          StandardCallFormat := SecondPart[1] + '/' + FirstPart
          end
       else
          begin
          StandardCallFormat := FirstPart;
          end;
       Exit;
       end;
  if length(FirstPart) > length(SecondPart) then
     begin
     StandardCallFormat := SecondPart + '/' + FirstPart;
     Exit;
     end;
  if length(FirstPart) <= length(SecondPart) then
     begin
     StandardCallFormat := Call;
     Exit;
     end;
end;
function GetPrefix(Call: string): string;
{ This function will return the prefix for the call passed to it. This is
    a new and improved version that will handle calls as they are usaully
    sent on the air.                                                          }
var
    FirstPart, SecondPart, TempString     : string;
    CallPointer, Count                    : Integer;
begin
  for CallPointer := 1 to length(Call) do
    if Call[CallPointer] = '/' then
       begin
       FirstPart := Call;
         //{WLI}            FirstPart [0] := Chr (CallPointer - 1);
       FirstPart := Copy(FirstPart, 1, CallPointer - 1);
       SecondPart := '';
       for Count := CallPointer + 1 to length(Call) do
          begin
          SecondPart := SecondPart + Call[Count];
          end;
       if length(SecondPart) = 1 then
         if (SecondPart >= '0') and (SecondPart <= '9') then
            begin
            TempString := GetPrefix(FirstPart);
                //{WLI}                    TempString [0] := Chr (Length (TempString) - 1);
            TempString := Copy(TempString, 1, length(TempString) - 1);
            GetPrefix := TempString + SecondPart;
            Exit;
            end
         else
            begin
            //         GetPrefix := GetPrefix(FirstPart);
                     Exit;
            end;
         {KK1L: 6.68 Added AM check to allow /AM as aeronautical mobile rather than Spain}
       if (Copy(SecondPart, 1, 2) = 'MM') or (Copy(SecondPart, 1, 2) = 'AM') then
          begin
          GetPrefix := GetPrefix(FirstPart);
          Exit;
          end;
       if length(FirstPart) > length(SecondPart) then
          begin
          GetPrefix := GetPrefix(SecondPart);
          Exit;
          end;
       if length(FirstPart) <= length(SecondPart) then
          begin
          GetPrefix := GetPrefix(FirstPart);
          Exit;
          end;
       end;
  { Call does not have portable sign.  Find natural prefix. }
  if not StringHasNumber(Call) then
     begin
     GetPrefix := Call + '0';
     Exit;
     end;
  for CallPointer := length(Call) downto 2 do
    if Call[CallPointer] <= '9' then
       begin
       GetPrefix := Call;
         //{WLI}            GetPrefix [0] := CHR (CallPointer);
       Result := Copy(Call, 1, CallPointer);
       Exit;
       end;
  if (Call[1] <= '9') and (length(Call) = 2) then
     begin
     GetPrefix := Call + '0';
     Exit;
     end;
  GetPrefix := ''; { We have no idea what the prefix is }
end;
function GetOblast(Call: string): string;
var
  i                                     : integer;
  c1                                    : Char;
  c2                                    : Char;
begin
  Call := StandardCallFormat(Call, False);
  if StringHas(Call, '/') then
     begin
     Call := PrecedingString(Call, '/');
     end;
  c1 := #0;
  c2 := #0;
  for i := 2 to length(Call) do
     begin
     if c1 <> #0 then
        begin
        if Call[i] in ['A'..'Z'] then
           begin
           c2 := Call[i];
           Break;
           end;
        Continue;
        end;
     if Call[i] in ['0'..'9'] then
        begin
        c1 := Call[i];
        end;
     end;
  if (c1 = #0) or (c2 = #0) then
     begin
     Result := ''
     end
  else
     begin
     Result := c1 + c2;   // was Result[0]:=#2; Result[1]:=c1; Result[2]:=c2; (ShortString length-byte)
     end;
end;
function GetRussiaOblastID(Call: string): string; //
var

  Oblast                                : string;
  r                                     : PAnsiChar;   // boundary: indexes RussianRegionsTypeIdArray (ANSI)
  reg                                   : RussianRegionType;
begin
  Result := '';
  if tPos(Call, '/') <> 0 then Exit;
  Oblast := GetOblast(Call);
  if length(Oblast) < 2 then Exit;
  reg := GetRussiaOblastByTwoChars(Char(Oblast[1]), Char(Oblast[2]));
  if reg = rtUnknownRegion then Exit;
  r := RussianRegionsTypeIdArray[GetRussiaOblastByTwoChars(Char(Oblast[1]), Char(Oblast[2]))];
  Result := Char(r[0]) + Char(r[1]);   // was Result[0]:=#2; Result[1]:=AnsiChar(r[0]); Result[2]:=AnsiChar(r[1]);
end;
function CaliforniaCall(Call: string): boolean;
begin
  CaliforniaCall := False;
  if not StringHas(Call, '6') then Exit;
  Call := StandardCallFormat(Call, True);
  if StringHas(Call, '/') then if not StringHas(Call, '6/') then Exit;
  if (Call[1] <> 'A') and (Call[1] <> 'K') and (Call[1] <> 'N') and (Call[1] <> 'W') then Exit;
  if Call[2] = 'H' then Exit;
  CaliforniaCall := True;
end;
function RootCall(Call: string): string;
var
  TempCall                              : string;
begin
  TempCall := StandardCallFormat(Call, True);
  if StringHas(TempCall, '/') then
     begin
     TempCall := PostcedingString(TempCall, '/');
     end;
  if length(TempCall) <= 2 then
     begin
     TempCall := PrecedingString(StandardCallFormat(Call, True), '/');
     if length(TempCall) >= 3 then
        begin
        RootCall := TempCall;
        Exit;
        end;
     end;
  if StringHas(TempCall, '/') then
     begin
     TempCall := PrecedingString(TempCall, '/');
     end;
  {   IF Length (TempCall) > 6 THEN TempCall [0] := Chr (6); }
  RootCall := TempCall;
end;
function RoverCall(Call: string): boolean;
begin
  RoverCall := UpperCase(Copy(Call, length(Call) - 1, 2)) = '/R';
end;
function MobileCall(Call: string): boolean;      //n4af 4.41.8
begin
  MobileCall := UpperCase(Copy(Call, length(Call) - 1, 2)) = '/M';
end;
function SimilarCall(Call1: string; Call2: string): boolean;
{ This function will return true if the two calls only differ in one
    character position.         }
var
  NumberDifferentChars, NumberTestChars, TestChar: integer;
  c1, c2                                : string;
begin
  if pos('/', Call1) > 0 then
     begin
     Call1 := RootCall(Call1);
     end;
  if pos('/', Call2) > 0 then
     begin
     Call2 := RootCall(Call2);
     end;
  SimilarCall := False;
  if Abs(length(Call1) - length(Call2)) > 1 then Exit;
  NumberTestChars := length(Call1);
  if (length(Call2) > NumberTestChars) then
     begin
     inc(NumberTestChars);
     end;
  { NumberTestChars is equal to length of longest call. }
  NumberDifferentChars := 0;
  for TestChar := NumberTestChars downto 1 do
     begin
     c1 := Copy(Call1, TestChar, 1);
     c2 := Copy(Call2, TestChar, 1);
     if (c1 <> c2) and (c1 <> '?') and (c2 <> '?') then
        begin
        inc(NumberDifferentChars);
        if (NumberDifferentChars) = 2 then Break;
        end;
     end;
  if NumberDifferentChars <= 1 then
     begin
     SimilarCall := True;
     Exit;
     end;
  { Let's see if either call shows up in the other - finds I4COM PI4COM }
  if (pos(Call1, Call2) = 0) and (pos(Call2, Call1) = 0) then Exit;
  SimilarCall := True;
end;

function IsAGoodCall(Call: string): boolean;
{ This function will look at the callsign passed to it and see if it
    looks like a real callsign.                                           }
var
  CharacterPointer                      : integer;
begin
  IsAGoodCall := False;
  if length(Call) < 3 then 
     begin
     Exit;
     end;
     
  Call := UpperCase(Call);   
  if not StringHasLetters(Call) then Exit;
  case length(Call) of
    8:
      if ((Call[2] = '/') or (Call[2] = '-')) and
        ((Call[6] = '/') or (Call[6] = '-')) then
         begin
         Exit;
         end;
    9:
      if ((Call[3] = '/') or (Call[3] = '-')) and
        ((Call[7] = '/') or (Call[7] = '-')) then
         begin
         Exit;
         end;
  end;
  if Call = 'RAEM' then
     begin
     IsAGoodCall := True;
     Exit;
     end;
  for CharacterPointer := 1 to length(Call) do
    if not ValidCallCharacter(Call[CharacterPointer]) then Exit;
  for CharacterPointer := 1 to length(Call) do
    if Call[CharacterPointer] = '/' then
       begin
       if CharacterPointer = 1 then Exit;
       if CharacterPointer = length(Call) then Exit;
       IsAGoodCall := True;
       Exit;
       end;
  if (Call[1] <= '9') and (Call[2] <= '9') then Exit;
  if length(Call) = 3 then
     begin
     if
       ((Call[2] < '0') or (Call[2] > '9')) and
       ((Call[3] < '0') or (Call[3] > '9')) then
        begin
        Exit;
        end;
     end ;
  IsAGoodCall := True;
end;
function IsAUSPrefix(const Call: string): boolean;
begin
   // Replaces RX_US_PREFIX, '^[AaWaKkNn][a-zA-Z]?', WHICH CARRIED A TYPO: the
   // character class has 'a' twice and NO lowercase 'w', so a lowercase w4ta
   // failed this test, fell through to the general branch and silently skipped
   // the strict US check below. Fixed here by asking the question directly.
   Result := (Length(Call) >= 1) and (UpCase(Call[1]) in ['A', 'W', 'K', 'N']);
end;

function IsAGoodUSCall(const Call: string): boolean;
var
   i: integer;
   digitAt: integer;
begin
   // RX_US_CALLSIGN was '^[AaWaKkNn][a-zA-Z]?[0-9][a-zA-Z]{1,3}$' -- one prefix
   // letter, an optional second, one digit, then one to three letters. Written
   // out because a four-times-faster hand test is worth more here than a
   // pattern, and because the typo above lived in this one too.
   Result := False;

   // THREE, not four: '^[AWKN][a-zA-Z]?[0-9][a-zA-Z]{1,3}$' can match with the
   // optional second prefix letter absent and a single-letter suffix -- W1A is
   // a legal 1x1. Six is the other end: two prefix letters, a digit, three
   // suffix letters.
   if (Length(Call) < 3) or (Length(Call) > 6) then
      begin
      Exit;
      end;

   if not IsAUSPrefix(Call) then
      begin
      Exit;
      end;

   // The digit is at position 2 or 3 -- one or two prefix letters before it.
   if (Call[2] >= '0') and (Call[2] <= '9') then
      begin
      digitAt := 2;
      end
   else if (Length(Call) >= 3) and (Call[3] >= '0') and (Call[3] <= '9') and
           (UpCase(Call[2]) in ['A'..'Z']) then
      begin
      digitAt := 3;
      end
   else
      begin
      Exit;
      end;

   // One to three letters after it, and nothing else.
   if (Length(Call) - digitAt < 1) or (Length(Call) - digitAt > 3) then
      begin
      Exit;
      end;

   for i := digitAt + 1 to Length(Call) do
      begin
      if not (UpCase(Call[i]) in ['A'..'Z']) then
         begin
         Exit;
         end;
      end;

   Result := True;
end;

function ValidCallCharacter(CallChar: Char): boolean;
begin
  Result := CallChar in ['/', '0'..'9', 'A'..'Z'];
end;
end.

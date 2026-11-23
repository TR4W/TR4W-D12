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

(* IS WHAT THE OPERATOR TYPED INTO A STATION FIELD THE SHAPE THAT FIELD
  TAKES? -- a leaf, written 2026-11-16 for Preferences > Station.

  NY4I typed junk into Grid, ARRL section, Country, Park and License year, and
  only the license year said anything -- and only at Save: "Why not do the
  edit when focus leaves the field and perform type editing against the
  format of a park and others." StationFieldProblem is that check, one
  function, asked by the Station page when a field loses focus AND at Save.

  IT IS PREFERENCES' QUESTION, NOT A REGISTERED VALUE CHECK. A check
  registered with the settings model (RegisterSettingValueCheck) refuses on
  EVERY channel -- the contest .cfg, a log's stored rows, a peer, the
  converter -- and a refused .cfg line is the modal "invalid statement in
  config file". An old .cfg naming an unusual park or section must keep
  loading, so the new format rules stay here. The two rules that WERE
  already registered (MY COUNTRY, MY LICENSE YEAR) are asked here through
  the same functions, so the page and the model cannot disagree.

  REUSED, NOT COPIED. Every rule is an existing predicate:

    MY GRID         uGridShape.IsGoodLookingGrid -- the grid LOGGRID will
                    measure, so 4 or 6 characters (an 8-character grid would
                    give no distance and no heading)
    MY SECTION      uARRLSections.IsADIFARRLSection, plus DX (Field Day)
    MY PARK         uPOTAReference.IsValidPOTAPark, per comma-separated park
    MY IOTA         IsIOTAReference         -- lifted here from uADIF
    MY FD CLASS     CheckCountAndLetterClass -- lifted here from TContestBase
    MY LICENSE YEAR LicenseYearIsDigits      -- lifted here from uCFG
    MY COUNTRY      uCFG.MyCountryIsAKnownPrefix, through the hook below,
                    because CTY.DAT is not a leaf's to read

  The three lifted predicates are moved line for line and their old homes
  call these; there is one copy of each.

  MY STATE IS CHECKED ONLY WHEN IT IS TWO LETTERS (see IsAcceptableState): it
  is a polymorphic QTH -- a state, county, province, oblast or grid; see
  uSettingsModel near 'property State'. DELIBERATELY NOT CHECKED: MY
  POSTAL CODE (country dependent), MY NAME and MY CALL (the Station page
  queries a doubtful call at Save already). EMPTY IS ALWAYS ALLOWED: it is
  "not set", not a claim.

  PURE apart from the country hook: no globals read, no logging. *)
unit uStationFieldCheck;

{$I tr4w.inc}

interface

type
   (* What CheckCountAndLetterClass found. calcBadCount is the transmitter
     count (no digits, or outside 1..99); calcBadLetter is the class letter
     (none, two, or one the contest does not use). *)
   TCountAndLetterClass = (calcValid, calcBadCount, calcBadLetter);

   (* A yes/no question about a typed value -- the shape of
     uSettingsModel.TSettingValueCheck, so one function can be registered
     with both. *)
   TStationTextCheck = function(const aValue: string): boolean;

   (* WHERE FOCUS WENT when a Station field was left -- the one thing
     ShouldHoldFocus needs to know about the screen. *)
   TStationFocusDestination = (
      sfdStationPage,   (* another control on the Station page: a Tab, a click *)
      sfdDialogButton,  (* OK, Cancel, Apply, Activate, any button *)
      sfdNavigation,    (* the page tree: the operator chose another page *)
      sfdOtherControl,  (* anything else in Preferences, e.g. the search box *)
      sfdOutsideForm);  (* another window, or Preferences closing or hidden *)

const
   (* THE CLASS LETTERS OF THE TWO FIELD DAYS, named once. Both contests and
     the Station page read these. *)
   FIELD_DAY_CLASS_LETTERS        = 'ABCDEF';
   WINTER_FIELD_DAY_CLASS_LETTERS = 'IOHM';

(* '' when aText is acceptable for the Station-page setting aCommand (its
  command name, 'MY GRID'), else a short, translated reason. aText is
  trimmed first; '' is always acceptable. A command this unit has no rule
  for answers ''. *)
function StationFieldProblem(const aCommand, aText: string): string;

(* EVERY FIELD, NOT ONLY THE TOUCHED ONES (NY4I, 2026-11-16: a bad park LOADED
  from the settings file was saved, because it never lost focus). aCommands
  and aTexts are parallel. The index of the first pair StationFieldProblem
  refuses, or -1; aProblem is its reason ('' when none). *)
function FirstStationFieldProblem(const aCommands, aTexts: array of string;
                                  out aProblem: string): integer;

(* SHOULD FOCUS GO BACK INTO THE FIELD JUST LEFT? (NY4I, 2026-11-16: "when
  there is an error, shouldn't the cursor be left in that field even if I hit
  tab?") Only when it is wrong (aProblem <> ''), not empty -- an emptied field
  is valid and is never held -- and focus merely moved within the Station
  page. Every way OUT is let go: a dialog button (Cancel above all), another
  page, the rest of Preferences, another window, a closing form. The hold
  must never stop the operator leaving. *)
function ShouldHoldFocus(const aProblem, aText: string;
                         aDestination: TStationFocusDestination): boolean;

(* A Field Day style class: a transmitter count 1..99 and exactly one of
  aValidLetters, either case -- '2A', '1h'. Lifted unchanged from
  TContestBase.ValidateCountAndLetterClass, which now maps this answer to its
  contest's message. *)
function CheckCountAndLetterClass(const aClass, aValidLetters: string): TCountAndLetterClass;

(* Two letters, a hyphen, three digits, either case -- 'NA-001'. Lifted from
  uADIF.IsADIFIOTARef, which calls this. *)
function IsIOTAReference(const aText: string): boolean;

(* MY LICENSE YEAR: nothing, or one to four digits -- a year ('1985'), its
  last two digits ('85') or a count of years ('9'). Lifted from uCFG, which
  registers this function with the settings model. *)
function LicenseYearIsDigits(const aValue: string): boolean;

(* MY PREFECTURE: nothing, one to three digits (a JARL number -- ALL JA 02..48
  and 101..114, JIDX 01..48), or two letters (the KCJ's prefecture code, TK).
  The SHAPE only: which numbers a contest takes is the contest's own pattern
  (TNewContestPrompt.Pattern). Registered with the settings model by uCFG. *)
function PrefectureIsAcceptable(const aValue: string): boolean;

(* MY POWER CLASS: nothing, or one of H, M, L, P, either case. Registered
  with the settings model by uCFG. *)
function PowerClassIsAcceptable(const aValue: string): boolean;

(* THE MY COUNTRY RULE NEEDS CTY.DAT, which a leaf may not read, so uCFG
  hands its check in here at initialization. Until one is registered, a
  country is not checked. *)
procedure RegisterStationCountryCheck(const aCheck: TStationTextCheck);

implementation

uses
   SysUtils,
   uAppStrings,    (* the reasons, as resourcestrings *)
   uGridShape,     (* IsGoodLookingGrid *)
   uARRLSections,  (* IsADIFARRLSection *)
   uPOTAReference; (* IsValidPOTAPark *)

var
   CountryCheck: TStationTextCheck = nil;

procedure RegisterStationCountryCheck(const aCheck: TStationTextCheck);
begin
   CountryCheck := aCheck;
end;

(* RANGE COMPARISONS, NOT `in ['0'..'9']`: string is a UnicodeString here,
  and a WideChar tested against an AnsiChar set is truncated first. *)
function IsAsciiDigit(aCh: Char): boolean;
begin
   Result := (aCh >= '0') and (aCh <= '9');
end;

function IsAsciiLetter(aCh: Char): boolean;
begin
   Result := ((aCh >= 'A') and (aCh <= 'Z')) or
             ((aCh >= 'a') and (aCh <= 'z'));
end;

function AllDigits(const aText: string): boolean;
var
   i: integer;
begin
   Result := aText <> '';
   for i := 1 to Length(aText) do
      begin
      if not IsAsciiDigit(aText[i]) then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

(* At most aMaxDigits digits, and a value in aLow..aHigh. Accumulated rather
  than converted: StrToInt and Val are not range-checked on Win64, and the
  length bound keeps the sum small. '05' is 5. *)
function DigitsInRange(const aText: string; aMaxDigits, aLow, aHigh: integer): boolean;
var
   i: integer;
   value: integer;
begin
   Result := False;
   if (Length(aText) > aMaxDigits) or (not AllDigits(aText)) then
      begin
      Exit;
      end;
   value := 0;
   for i := 1 to Length(aText) do
      begin
      value := value * 10 + (Ord(aText[i]) - Ord('0'));
      end;
   Result := (value >= aLow) and (value <= aHigh);
end;

function CheckCountAndLetterClass(const aClass, aValidLetters: string): TCountAndLetterClass;
var
   i: integer;
   (* THE COUNT AS A NUMBER, not a string to convert back -- accumulated a
     digit at a time, with the digit COUNT kept separately so an empty class
     can still be told from a class of "0". *)
   count: integer;
   countDigits: integer;
   category: string;
   categorySet: boolean;
begin
   count := 0;
   countDigits := 0;
   category := '';
   categorySet := False;

   for i := 1 to Length(aClass) do
      begin
      if IsAsciiDigit(aClass[i]) then
         begin
         inc(countDigits);
         (* Capped so a long run of digits cannot overflow into a value that
           happens to land back inside 1..99. Anything past two digits is
           already invalid. *)
         if countDigits <= 3 then
            begin
            count := count * 10 + (Ord(aClass[i]) - Ord('0'));
            end
         else
            begin
            count := 1000;
            end;
         end
      else if Pos(UpCase(aClass[i]), aValidLetters) > 0 then
         begin
         (* A SECOND letter empties the category rather than appending, so "2AB"
           fails on the length test below. Reproduced from the legacy loop,
           where it reads as a break with sCategory cleared. *)
         if categorySet then
            begin
            category := '';
            Break;
            end
         else
            begin
            categorySet := True;
            category := category + aClass[i];
            end;
         end
      else
         begin
         (* Anything else at all -- a letter this contest does not use, or
           punctuation. Empties the category so the answer is the letter's. *)
         category := '';
         Break;
         end;
      end;

   if (countDigits = 0) or (count < 1) or (count > 99) then
      begin
      Result := calcBadCount;
      end
   else if Length(category) <> 1 then
      begin
      Result := calcBadLetter;
      end
   else
      begin
      Result := calcValid;
      end;
end;

function IsIOTAReference(const aText: string): boolean;
var
   i: integer;
begin
   Result := False;
   if (Length(aText) <> 6) or (aText[3] <> '-') then
      begin
      Exit;
      end;
   if not (IsAsciiLetter(aText[1]) and IsAsciiLetter(aText[2])) then
      begin
      Exit;
      end;
   for i := 4 to 6 do
      begin
      if not IsAsciiDigit(aText[i]) then
         begin
         Exit;
         end;
      end;
   Result := True;
end;

function LicenseYearIsDigits(const aValue: string): boolean;
var
   value: string;
   i: integer;
begin
   value := Trim(aValue);
   Result := Length(value) <= 4;
   for i := 1 to Length(value) do
      begin
      if (value[i] < '0') or (value[i] > '9') then
         begin
         Result := False;
         end;
      end;
end;

function PrefectureIsAcceptable(const aValue: string): boolean;
var
   value: string;
begin
   value := Trim(aValue);
   if value = '' then
      begin
      Result := True;
      end
   else if AllDigits(value) then
      begin
      Result := Length(value) <= 3;
      end
   else
      begin
      Result := (Length(value) = 2) and IsAsciiLetter(value[1]) and
                IsAsciiLetter(value[2]);
      end;
end;

function PowerClassIsAcceptable(const aValue: string): boolean;
var
   value: string;
begin
   value := UpperCase(Trim(aValue));
   Result := (value = '') or (value = 'H') or (value = 'M') or (value = 'L') or
             (value = 'P');
end;

(* ONE OR MORE PARKS, SEPARATED BY COMMAS -- 'US-1234' or 'US-1234,US-5678'
  for an n-fer. Every piece must be a park; an empty piece (a stray comma)
  is not one. *)
function IsParkList(const aText: string): boolean;
var
   rest: string;
   piece: string;
   comma: integer;
begin
   Result := False;
   rest := aText;
   repeat
      comma := Pos(',', rest);
      if comma > 0 then
         begin
         piece := Trim(Copy(rest, 1, comma - 1));
         rest := Copy(rest, comma + 1, MaxInt);
         end
      else
         begin
         piece := Trim(rest);
         rest := '';
         end;
      if not IsValidPOTAPark(piece) then
         begin
         Exit;
         end;
   until comma = 0;
   Result := True;
end;

(* MY STATE: ONLY A TWO-LETTER VALUE IS JUDGED (NY4I, 2026-11-16: "A state
  or province cannot be AA").

  MY STATE is NOT a state. It is the polymorphic QTH the exchange sends where
  a US station sends its state -- a county, an oblast, a grid in the VHF
  contests (FCONTEST assigns the grid straight into it), a number in a few
  (uSettingsModel, the note on 'property State'). So anything that is not
  exactly two letters is accepted as typed.

  Two letters is a claim to be a state or province code, and is checked
  against uPOTAReference.LooksLikeAState -- the tree's one list: the 50
  states, DC and the 13 Canadian provinces and territories, case-folded here
  because that list is upper case. PLUS the five US territories with their
  own two-letter postal codes (PR, VI, GU, AS, MP): LooksLikeAState leaves
  them out because a POTA hunter's state never needed them, but an operator
  there types his own code into this field, and refusing it would be the
  "invalid entry" this check exists to avoid. *)
const
   US_TERRITORY_CODES: array[0..4] of string = ('PR', 'VI', 'GU', 'AS', 'MP');

function IsAcceptableState(const aText: string): boolean;
var
   code: string;
   i: integer;
begin
   Result := True;
   if (Length(aText) <> 2) or (not IsAsciiLetter(aText[1])) or
      (not IsAsciiLetter(aText[2])) then
      begin
      Exit;
      end;
   code := UpperCase(aText);
   if LooksLikeAState(code) then
      begin
      Exit;
      end;
   for i := Low(US_TERRITORY_CODES) to High(US_TERRITORY_CODES) do
      begin
      if code = US_TERRITORY_CODES[i] then
         begin
         Exit;
         end;
      end;
   Result := False;
end;

function IsPrecedence(const aText: string): boolean;
begin
   Result := (Length(aText) = 1) and (Pos(UpCase(aText[1]), 'QABUMS') > 0);
end;

function ShouldHoldFocus(const aProblem, aText: string;
                         aDestination: TStationFocusDestination): boolean;
begin
   Result := (aProblem <> '') and (Trim(aText) <> '') and
             (aDestination = sfdStationPage);
end;

function FirstStationFieldProblem(const aCommands, aTexts: array of string;
                                  out aProblem: string): integer;
var
   i: integer;
begin
   Result := -1;
   aProblem := '';
   for i := 0 to High(aCommands) do
      begin
      if i > High(aTexts) then
         begin
         Exit;
         end;
      aProblem := StationFieldProblem(aCommands[i], aTexts[i]);
      if aProblem <> '' then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function StationFieldProblem(const aCommand, aText: string): string;
var
   command: string;
   text: string;
begin
   Result := '';
   text := Trim(aText);
   if text = '' then
      begin
      Exit;
      end;
   command := UpperCase(Trim(aCommand));

   (* An if-chain: a case on a string does not compile in Delphi mode. *)
   if command = 'MY GRID' then
      begin
      if not IsGoodLookingGrid(text) then
         begin
         Result := SStationFieldGrid;
         end;
      end
   else if (command = 'MY STATE') or (command = 'MY QTH') then
      begin
      (* MY QTH is the same setting under its second name. *)
      if not IsAcceptableState(text) then
         begin
         Result := SStationFieldState;
         end;
      end
   else if command = 'MY ZONE' then
      begin
      if not DigitsInRange(text, 2, 1, 40) then
         begin
         Result := SStationFieldZone;
         end;
      end
   else if command = 'MY ITU ZONE' then
      begin
      (* uSettingsModel.TMyItuZone is 0..90; 0 means "use CTY.DAT's". *)
      if not DigitsInRange(text, 2, 0, 90) then
         begin
         Result := SStationFieldItuZone;
         end;
      end
   else if command = 'MY SECTION' then
      begin
      (* DX is what a station outside the US and Canada sends in Field Day;
        no ADIF section is spelled DX. *)
      if (not IsADIFARRLSection(text)) and (not UnicodeSameText(text, 'DX')) then
         begin
         Result := SStationFieldSection;
         end;
      end
   else if command = 'MY COUNTRY' then
      begin
      if Assigned(CountryCheck) and (not CountryCheck(text)) then
         begin
         Result := SStationFieldCountry;
         end;
      end
   else if command = 'MY PARK' then
      begin
      if not IsParkList(text) then
         begin
         Result := SStationFieldPark;
         end;
      end
   else if command = 'MY IOTA' then
      begin
      if not IsIOTAReference(text) then
         begin
         Result := SStationFieldIota;
         end;
      end
   else if command = 'MY FD CLASS' then
      begin
      (* The Station page does not know which Field Day is next, so either
        contest's letters are accepted. *)
      if CheckCountAndLetterClass(text, FIELD_DAY_CLASS_LETTERS +
                                        WINTER_FIELD_DAY_CLASS_LETTERS) <> calcValid then
         begin
         Result := SStationFieldFDClass;
         end;
      end
   else if command = 'MY CHECK' then
      begin
      (* Exactly two digits: the Sweepstakes parser refuses a received check
        of any other length (LOGSTUFF), so a one-digit check sent would be
        one the other station's logger refuses. *)
      if (Length(text) <> 2) or (not AllDigits(text)) then
         begin
         Result := SStationFieldCheck;
         end;
      end
   else if command = 'MY PREC' then
      begin
      if not IsPrecedence(text) then
         begin
         Result := SStationFieldPrec;
         end;
      end
   else if command = 'MY FOC NUMBER' then
      begin
      if not AllDigits(text) then
         begin
         Result := SStationFieldFOCNumber;
         end;
      end
   else if command = 'MY LICENSE YEAR' then
      begin
      if not LicenseYearIsDigits(text) then
         begin
         Result := SStationFieldLicenseYear;
         end;
      end
   else if command = 'MY PREFECTURE' then
      begin
      if not PrefectureIsAcceptable(text) then
         begin
         Result := SStationFieldPrefecture;
         end;
      end
   else if command = 'MY POWER CLASS' then
      begin
      if not PowerClassIsAcceptable(text) then
         begin
         Result := SStationFieldPowerClass;
         end;
      end;
end;

end.

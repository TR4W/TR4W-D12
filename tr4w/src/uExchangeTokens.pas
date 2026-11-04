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

(* THE CONTEST-BLIND HALF OF EXCHANGE PARSING -- M5b, 2026-10-02.

  A typed exchange is cut into words before anybody asks what the words MEAN,
  and the cutting is the same whoever asks. The routines here are that
  cutting, LIFTED out of LOGSTUFF so a contest class may use them: a class
  may not call the TRDOS engine, and a helper reads no globals
  (docs/CONTEST_OWNERSHIP_DESIGN.md 1.3). LOGSTUFF calls the same routines,
  so the engine and the classes cut an exchange one way, not two.

  LIFTED, NOT REWRITTEN. Each routine is its LOGSTUFF original line for line,
  quirks included -- a ten-character field that truncates, a leading-blank
  trim that keeps a lone blank. They decide which word a contest is handed,
  and a "tidier" version would hand some contests a different word.
  ONE DELIBERATE DEPARTURE, marked where it stands: ProcessSweepstakesEntry
  reads a precedence joined to digits with nothing after ('U123', 'U12',
  'A99') as precedence and SERIAL (issue #174 and NY4I's rulings,
  2026-11-04); 'A99CT' is still precedence, check and section. It also REPORTS which reading
  each word took (TSweepstakesWordKind), so SweepstakesSerialIsAmbiguous
  counts what the parser saw rather than re-deriving it.

  NOTHING HERE NAMES A CONTEST OR READS A SETTING. A rule -- which word is a
  serial, which is a county, what a refusal says -- is the contest's, on its
  class. *)
unit uExchangeTokens;

{$I tr4w.inc}

interface

uses
   VC;

type
   (* WHAT ONE PASS OVER A SWEEPSTAKES EXCHANGE HAS FOUND -- the serial, the
     precedence, the check and the section, each taken the first time a word
     supplies it. The field widths are the engine's, and they truncate. *)
   TSweepstakesFields = record
      Number: string[4];
      Check: string[2];
      Section: Str10;
      Prec: AnsiChar;
      (* THE ENTRY HOLDS A WORD THAT CAN ONLY BE THE SERIAL ('123', 'U12',
        '43M') -- set BEFORE the fold by MarkSweepstakesSerialElsewhere,
        because a precedence-digits-section word ('A99CT') reads its digits
        as the serial unless another word must be the serial, and the fold
        meets the words last first. NY4I, 2026-11-04. *)
      SerialElsewhere: boolean;
   end;

   (* WHICH READING ONE WORD OF A SWEEPSTAKES EXCHANGE TOOK -- the branch of
     ProcessSweepstakesEntry that consumed it, reported so a caller can count
     the shapes of an exchange WITHOUT a second copy of the word grammar
     (SweepstakesSerialIsAmbiguous, 2026-11-04). The kind says what the word
     IS, not what it changed: a second two-digit word is swBareTwoDigits
     whether or not a field was still empty for it.

       swIgnored                 empty, or a run of more than four digits
       swBareTwoDigits           '43' -- a check or a serial; cannot tell
       swBareOtherDigits         '4', '430', '1234' -- only ever a serial
       swPrecedenceAlone         'M'
       swSerialThenPrecedence    '43M', 'M' after digits
       swPrecedenceThenSerial    'U123', 'U12', 'A99', 'M43' -- nothing after
       swPrecedenceSerialSection 'A99CT', 'U12WCF' -- the digits are the
                                 serial, or the check when another word
                                 must be the serial
       swSerialPrecedenceCheckSection
                                 '123A99CT' -- the serial ahead of the letter
       swCheckThenSection        '31CT', '99CT', '43MI' -- exactly two digits
       swSection                 'CT', 'W1AW', 'AB', '4CT' *)
   TSweepstakesWordKind = (
      swIgnored,
      swBareTwoDigits,
      swBareOtherDigits,
      swPrecedenceAlone,
      swSerialThenPrecedence,
      swPrecedenceThenSerial,
      swPrecedenceSerialSection,
      swSerialPrecedenceCheckSection,
      swCheckThenSection,
      swSection);

const
   (* THE PRECEDENCE LETTERS of the ARRL Sweepstakes. *)
   SweepstakesPrecedences: set of AnsiChar = ['A', 'B', 'Q', 'U', 'M', 'S'];

(* THE FIRST THREE WORDS OF AN EXCHANGE -- LOGSTUFF.ParseExchange, lifted.
  The third holds everything after the second word, and each field is ten
  characters at most. *)
procedure SplitExchangeInThree(Exchange: ShortString;
                               var FirstString, SecondString, ThirdString: Str10);

(* IS THE EXCHANGE ONE WORD THAT IS NOT A NUMBER, once its outer blanks are
  trimmed and every '/' is read as a blank? The test
  LOGSTUFF.ProcessRSTAndDomesticQTHExchange makes before it takes the single
  QTH branch -- a county-line 'DAL/BAY' is two words. *)
function IsSingleNonNumericToken(const aText: string): boolean;

(* ONE WORD OF A SWEEPSTAKES EXCHANGE, folded into aFields --
  LOGSTUFF.ProcessSSEntry, lifted. The result names the reading the word
  took; a caller that only folds ignores it. *)
function ProcessSweepstakesEntry(InputString: Str80; var aFields: TSweepstakesFields): TSweepstakesWordKind;

(* SETS aFields.SerialElsewhere from the words of aText -- the one pre-pass
  the fold needs, called by ScanSweepstakesExchange and by LOGSTUFF's parse
  before their loops. *)
procedure MarkSweepstakesSerialElsewhere(const aText: string; var aFields: TSweepstakesFields);

(* EVERY WORD OF A SWEEPSTAKES EXCHANGE, last first, as the engine's parse
  folds them -- what the exchange SUPPLIED, before any field is validated. *)
procedure ScanSweepstakesExchange(const aText: string; out aFields: TSweepstakesFields);

(* CAN THE SERIAL NOT BE TOLD FROM THE CHECK? -- NY4I, 2026-11-04 (issue
  #174 follow-up): "in our free-form parsing, you cannot tell ... If the
  exchange is ambiguous, it is ok to tell the user and ask them to put
  serial number and precedence together."

  True exactly when ALL of these hold, over the words the engine reads:
    - a precedence stands as a word of its own ('M', never '43M');
    - no word joins digits to a precedence ('43M', 'U123', 'A99', 'A99CT');
    - no bare number of one, three or four digits ('4', '430', '1234' can
      only be the serial, so the lone two-digit word is the check);
    - and EITHER exactly TWO bare two-digit numbers ('43 M W1AW 31 CT'),
      OR bare two-digit numbers and two-digit-then-section words ('99CT')
      come to exactly two, a check-then-section word counting ONLY when a
      bare two-digit number is typed AFTER it ('A 99CT 32'; NY4I: "a 99ct
      32 would be ambiguous"). Typed before it, the number reads in the
      base order -- serial, precedence, call, check, section -- so
      '42 M W1AW 31CT' and '32 A 99CT' are not ambiguous (NY4I's bench).
      '43 M 22 31CT' stays ambiguous by the first clause (two bare), and
      '43 M 31 CT 22' positional (three bare).
  The numbers named are the digits alone ('99', not '99CT').

  aFirst and aSecond are the two numbers IN THE ORDER TYPED; aPrecedence is
  the letter the scan keeps (the later typed, as the engine's parse does).
  All three are empty / #0 when the result is False. *)
function SweepstakesSerialIsAmbiguous(const aText: string;
                                      out aFirst, aSecond: string;
                                      out aPrecedence: AnsiChar): boolean;

implementation

uses
   utils_text;

const
   TAB_CHARACTER = #9;

(* TREE.GetRidOfPrecedingSpaces, as LOGSTUFF calls it: a LONE blank is kept,
  because the loop stops at two characters. *)
procedure TrimLeadingBlanks(var s: ShortString);
begin
   if s = '' then
      begin
      Exit;
      end;
   while ((s[1] = ' ') or (s[1] = TAB_CHARACTER)) and (Length(s) >= 2) do
      begin
      Delete(s, 1, 1);
      end;
end;

(* TREE.GetRidOfPostcedingSpaces. *)
procedure TrimTrailingBlanks(var s: ShortString);
begin
   while Length(s) > 0 do
      begin
      if (s[Length(s)] = ' ') or (s[Length(s)] = TAB_CHARACTER) then
         begin
         Delete(s, Length(s), 1);
         end
      else
         begin
         Exit;
         end;
      end;
end;

procedure SplitExchangeInThree(Exchange: ShortString;
                               var FirstString, SecondString, ThirdString: Str10);
begin
   FirstString := '';
   SecondString := '';
   ThirdString := '';

   if Length(Exchange) = 0 then
      begin
      Exit;
      end;

   (* The ShortString casts are the engine's own narrowing, made explicit: the
     words of a typed exchange are ANSI and each field is ten characters. *)
   if StringHas(string(Exchange), ' ') then
      begin
      FirstString := ShortString(PrecedingString(string(Exchange), ' '));
      Delete(Exchange, 1, Length(FirstString) + 1);
      TrimLeadingBlanks(Exchange);

      if StringHas(string(Exchange), ' ') then
         begin
         SecondString := ShortString(PrecedingString(string(Exchange), ' '));
         Delete(Exchange, 1, Length(SecondString));
         TrimLeadingBlanks(Exchange);
         ThirdString := Exchange;
         end
      else
         begin
         SecondString := Exchange;
         end;
      end
   else
      begin
      FirstString := Exchange;
      end;
end;

function IsSingleNonNumericToken(const aText: string): boolean;
var
   s: ShortString;
   i: integer;
begin
   (* The cast is a typed exchange returning to the width it was typed in. *)
   s := ShortString(aText);
   TrimLeadingBlanks(s);
   TrimTrailingBlanks(s);
   for i := 1 to Length(s) do
      begin
      if s[i] = '/' then
         begin
         s[i] := ' ';
         end;
      end;
   Result := (not StringHas(string(s), ' ')) and (not StringIsAllNumbers(string(s)));
end;

function ProcessSweepstakesEntry(InputString: Str80; var aFields: TSweepstakesFields): TSweepstakesWordKind;
var
   NumberStr, TempString: Str20;
   PrecedenceLetter: AnsiChar;
begin
   Result := swIgnored;
   TempString := InputString;

   NumberStr := '';

   (* Gobble up all the leading numbers. *)
   while StringIsAllNumbers(Copy(string(TempString), 1, 1)) do
      begin
      NumberStr := NumberStr + Copy(TempString, 1, 1);
      Delete(TempString, 1, 1);
      end;

   if Length(NumberStr) > 4 then
      begin
      Exit;
      end;

   if TempString = '' then
      begin
      if Length(NumberStr) = 2 then
         begin
         Result := swBareTwoDigits;
         end
      else if NumberStr <> '' then
         begin
         Result := swBareOtherDigits;
         end;

      (* All we had was numbers. Is it a check? *)
      if Length(NumberStr) = 2 then
         begin
         if aFields.Check = '' then
            begin
            aFields.Check := NumberStr;
            end
         else if aFields.Number = '' then
            begin
            aFields.Number := NumberStr;
            end;
         end
      else if aFields.Number = '' then
         begin
         aFields.Number := NumberStr;
         end;

      Exit;
      end;

   (* This works even if only A, B or Q was entered. *)
   if Length(TempString) = 1 then
      begin
      if TempString[1] in SweepstakesPrecedences then
         begin
         if NumberStr = '' then
            begin
            Result := swPrecedenceAlone;
            end
         else
            begin
            Result := swSerialThenPrecedence;
            end;
         if aFields.Number = '' then
            begin
            aFields.Number := NumberStr;
            end;
         if aFields.Prec = Chr(0) then
            begin
            aFields.Prec := TempString[1];
            end;
         Exit;
         end;
      end;

   (* THE PRECEDENCE BEFORE THE SERIAL, IN ONE WORD -- 'U123' as well as
     '123U' (issue #174, TR4W#460, 2026-11-04; NOT in the LOGSTUFF original).
     NY4I: "As long as we do not have a space between the precedence and
     number, we can figure this out to not be the check."

     ONE TO FOUR DIGITS AFTER THE LETTER, TWO INCLUDED -- NY4I, 2026-11-04:
     "a check would NEVER be entered with the precedence next to it without
     a space. The only thing we accept without a space is the
     <serial><precedence>." So 'U12', 'A99' and 'M43' -- a letter and
     digits with NOTHING after -- are a precedence and a SERIAL. With a
     section after the digits ('A99CT'), the branch below. The one entry
     that was taken and now reads differently holds TWO serials
     ('123 U5 80 WCF'): it took 123 and now takes 5, the later-typed one, as
     this parser does everywhere else. *)
   if (NumberStr = '') and
      (Length(TempString) in [2..5]) and
      (TempString[1] in SweepstakesPrecedences) and
      StringIsAllNumbers(Copy(string(TempString), 2, Length(TempString) - 1)) then
      begin
      Result := swPrecedenceThenSerial;
      if aFields.Number = '' then
         begin
         aFields.Number := Copy(TempString, 2, Length(TempString) - 1);
         end;
      if aFields.Prec = Chr(0) then
         begin
         aFields.Prec := TempString[1];
         end;
      Exit;
      end;

   (* A PRECEDENCE, DIGITS AND A SECTION IN ONE WORD -- 'A99CT', 'U12WCF'.

     THE DIGITS ARE THE SERIAL (NY4I, 2026-11-04: "a serial number and a
     precedence without a space was valid, so a99ct 32 would be precedence
     of a, serial number 99, section of ct and check of 32") -- UNLESS
     another word can only be the serial ("a99ct 123" is check 99, serial
     123: "123 cannot be a check"), when they are the check. That needs the
     whole entry, so the pre-pass has set aFields.SerialElsewhere. A serial
     already taken counts the same way. Digits that are not two cannot be a
     check, and are dropped there.

     DIGITS AHEAD OF THE LETTER ('123A99CT') are the serial, and the two
     after it the check, as D7 read them. *)
   if (Length(TempString) > 1) and
      (TempString[1] in SweepstakesPrecedences) and
      StringIsAllNumbers(Copy(string(TempString), 2, 1)) then
      begin
      if NumberStr <> '' then
         begin
         Result := swSerialPrecedenceCheckSection;
         if aFields.Number = '' then
            begin
            aFields.Number := NumberStr;
            end;
         if aFields.Prec = Chr(0) then
            begin
            aFields.Prec := TempString[1];
            end;
         if aFields.Check = '' then
            begin
            aFields.Check := Copy(TempString, 2, 2);
            end;
         Delete(TempString, 1, 3);
         if aFields.Section = '' then
            begin
            aFields.Section := TempString;
            end;
         Exit;
         end;

      PrecedenceLetter := TempString[1];
      Delete(TempString, 1, 1);
      while StringIsAllNumbers(Copy(string(TempString), 1, 1)) do
         begin
         NumberStr := NumberStr + Copy(TempString, 1, 1);
         Delete(TempString, 1, 1);
         end;
      if Length(NumberStr) > 4 then
         begin
         Exit;
         end;

      Result := swPrecedenceSerialSection;
      if aFields.Prec = Chr(0) then
         begin
         aFields.Prec := PrecedenceLetter;
         end;
      if aFields.SerialElsewhere or (aFields.Number <> '') then
         begin
         if (Length(NumberStr) = 2) and (aFields.Check = '') then
            begin
            aFields.Check := NumberStr;
            end;
         end
      else
         begin
         aFields.Number := NumberStr;
         end;
      if aFields.Section = '' then
         begin
         aFields.Section := TempString;
         end;
      Exit;
      end;

   (* A check and a section, or maybe just a section. *)
   if Length(NumberStr) = 2 then
      begin
      Result := swCheckThenSection;
      end
   else
      begin
      Result := swSection;
      end;
   if Length(NumberStr) = 2 then
      begin
      if aFields.Check = '' then
         begin
         aFields.Check := NumberStr;
         end;
      end;

   if aFields.Section = '' then
      begin
      aFields.Section := TempString;
      end;
end;

(* TREE.RemoveFirstString: line breaks read as blanks, leading blanks
  skipped, and the word is everything up to the next blank. *)
function RemoveFirstWord(var LongString: ShortString): Str80;
var
   CharCount: integer;
   FirstWordFound: boolean;
   FirstWordCursor: integer;
begin
   if LongString = '' then
      begin
      Result := '';
      Exit;
      end;

   for CharCount := 1 to Length(LongString) do
      begin
      if (LongString[CharCount] = #13) or (LongString[CharCount] = #10) then
         begin
         LongString[CharCount] := ' ';
         end;
      end;

   FirstWordFound := False;
   FirstWordCursor := 0;

   for CharCount := 1 to Length(LongString) do
      begin
      if FirstWordFound then
         begin
         if (LongString[CharCount] = ' ') or (LongString[CharCount] = TAB_CHARACTER) then
            begin
            Result := Copy(LongString, FirstWordCursor, CharCount - FirstWordCursor);
            Delete(LongString, 1, CharCount);
            Exit;
            end;
         end
      else if (LongString[CharCount] <> ' ') and (LongString[CharCount] <> TAB_CHARACTER) then
         begin
         FirstWordFound := True;
         FirstWordCursor := CharCount;
         end;
      end;

   if FirstWordFound then
      begin
      Result := Copy(LongString, FirstWordCursor, Length(LongString) - FirstWordCursor + 1);
      end
   else
      begin
      Result := '';
      end;

   LongString := '';
end;

type
   (* THE WORDS THE ENGINE READS -- eleven at most, as
     LOGSTUFF.ProcessQSONumberPrecedenceCheckDomesticQTHExchange cuts them. *)
   TSweepstakesWords = array[0..10] of Str20;

(* ONE CUTTING OF THE WORDS, for the scan and the ambiguity test alike. *)
procedure CutSweepstakesWords(const aText: string; out aWords: TSweepstakesWords;
                              out aCount: integer);
var
   Exchange: ShortString;
begin
   aWords := Default(TSweepstakesWords);

   (* The cast is a typed exchange returning to the width it was typed in. *)
   Exchange := ShortString(aText);
   aCount := 0;
   while (Exchange <> '') and (aCount <= 10) do
      begin
      aWords[aCount] := RemoveFirstWord(Exchange);
      inc(aCount);
      end;
end;

(* THE WORDS THAT CAN ONLY BE THE SERIAL -- a bare number that is not two
   digits, a precedence joined to bare digits either way round, and the
   serial ahead of a precedence-check-section word. 'A99CT' itself is not
   one: its digits are the serial only when nothing else is. *)
procedure MarkSweepstakesSerialElsewhere(const aText: string; var aFields: TSweepstakesFields);
var
   Entries: TSweepstakesWords;
   NumberEntries: integer;
   Entry: integer;
   scratch: TSweepstakesFields;
begin
   aFields.SerialElsewhere := False;
   CutSweepstakesWords(aText, Entries, NumberEntries);
   for Entry := 0 to NumberEntries - 1 do
      begin
      scratch := Default(TSweepstakesFields);
      if ProcessSweepstakesEntry(Entries[Entry], scratch) in
         [swBareOtherDigits, swSerialThenPrecedence, swPrecedenceThenSerial,
          swSerialPrecedenceCheckSection] then
         begin
         aFields.SerialElsewhere := True;
         Exit;
         end;
      end;
end;

procedure ScanSweepstakesExchange(const aText: string; out aFields: TSweepstakesFields);
var
   Entries: TSweepstakesWords;
   NumberEntries: integer;
   Entry: integer;
begin
   aFields := Default(TSweepstakesFields);
   MarkSweepstakesSerialElsewhere(aText, aFields);
   CutSweepstakesWords(aText, Entries, NumberEntries);

   for Entry := NumberEntries - 1 downto 0 do
      begin
      ProcessSweepstakesEntry(Entries[Entry], aFields);
      end;
end;

(* THE WORDS ARE FOLDED LAST FIRST, exactly as the scan folds them, and each
   reports the reading it took -- so this counts the shapes the engine SAW,
   with no grammar of its own. Walking backwards, the first two-digit number
   met is the LATER typed: each list below holds the later one at [0]. *)
function SweepstakesSerialIsAmbiguous(const aText: string;
                                      out aFirst, aSecond: string;
                                      out aPrecedence: AnsiChar): boolean;
var
   Entries: TSweepstakesWords;
   NumberEntries: integer;
   Entry: integer;
   fields: TSweepstakesFields;
   aloneCount, joinedCount, otherDigitsCount: integer;
   bareCount, candidateCount: integer;
   (* The bare two-digit words, and the bare words together with the digits
      of the check-then-section words -- the first two met of each. *)
   bare, candidates: array[0..1] of string;

   procedure AddCandidate(const aDigits: string);
   begin
      if candidateCount < 2 then
         begin
         candidates[candidateCount] := aDigits;
         end;
      inc(candidateCount);
   end;

begin
   aFirst := '';
   aSecond := '';
   aPrecedence := Chr(0);

   fields := Default(TSweepstakesFields);
   MarkSweepstakesSerialElsewhere(aText, fields);
   CutSweepstakesWords(aText, Entries, NumberEntries);

   aloneCount := 0;
   joinedCount := 0;
   otherDigitsCount := 0;
   bareCount := 0;
   candidateCount := 0;
   bare[0] := '';
   bare[1] := '';
   candidates[0] := '';
   candidates[1] := '';

   for Entry := NumberEntries - 1 downto 0 do
      begin
      case ProcessSweepstakesEntry(Entries[Entry], fields) of
         swBareTwoDigits:
            begin
            if bareCount < 2 then
               begin
               bare[bareCount] := string(Entries[Entry]);
               end;
            inc(bareCount);
            AddCandidate(string(Entries[Entry]));
            end;
         swCheckThenSection:
            begin
            (* ONLY WITH A BARE TWO-DIGIT NUMBER TYPED AFTER IT -- met
               already, since the walk is backwards. In the base order
               (serial, precedence, call, check, section) the check and
               section come last, so '43 M W1AW 31CT' is serial 43, check
               31; a number after the section breaks that order, and
               'A 99CT 32' cannot be told (NY4I, 2026-11-04). *)
            if bareCount > 0 then
               begin
               AddCandidate(Copy(string(Entries[Entry]), 1, 2));
               end;
            end;
         swBareOtherDigits:
            begin
            inc(otherDigitsCount);
            end;
         swPrecedenceAlone:
            begin
            inc(aloneCount);
            end;
         swSerialThenPrecedence,
         swPrecedenceThenSerial,
         swPrecedenceSerialSection,
         swSerialPrecedenceCheckSection:
            begin
            inc(joinedCount);
            end;
         end;
      end;

   Result := (aloneCount > 0) and
             (joinedCount = 0) and
             (otherDigitsCount = 0) and
             ((bareCount = 2) or (candidateCount = 2));
   if Result then
      begin
      if bareCount = 2 then
         begin
         aFirst := bare[1];
         aSecond := bare[0];
         end
      else
         begin
         aFirst := candidates[1];
         aSecond := candidates[0];
         end;
      aPrecedence := fields.Prec;
      end;
end;

end.

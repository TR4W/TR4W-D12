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
  reads 'U123' as precedence and serial (issue #174, 2026-11-04). It also
  REPORTS which reading each word took (TSweepstakesWordKind), so
  SweepstakesSerialIsAmbiguous counts what the parser saw rather than
  re-deriving it -- the fold itself is unchanged.

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
       swPrecedenceThenSerial    'U123', 'A5', 'Q1234'
       swPrecedenceThenCheck     'A99', 'A99CT', 'M43', '123A99CT'
       swCheckOrSection          '31CT', '43MI', 'CT', 'W1AW', 'AB' *)
   TSweepstakesWordKind = (
      swIgnored,
      swBareTwoDigits,
      swBareOtherDigits,
      swPrecedenceAlone,
      swSerialThenPrecedence,
      swPrecedenceThenSerial,
      swPrecedenceThenCheck,
      swCheckOrSection);

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
    - exactly TWO bare two-digit numbers.
  A check joined to its section ('31CT') is not a bare number, so
  '43 M W1AW 31CT' is not ambiguous.

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

     ONLY ONE, THREE OR FOUR DIGITS. Two digits after the letter stay the
     precedence and the CHECK below, as they always were: 'A99' is
     'A99CT' without its section, and a two-digit serial cannot be told from
     a check. Every word this branch takes was misread before (U123 gave
     check 12, section 3). The one entry that was taken and now reads
     differently holds TWO serials ('123 U5 80 WCF'): it took 123 and now
     takes 5, the later-typed one, as this parser does everywhere else. *)
   if (NumberStr = '') and
      (Length(TempString) in [2, 4, 5]) and
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

   (* More than one character left. A real precedence may be followed only by
     a number; otherwise the letter is part of a section (AB, AL). *)
   if Length(TempString) > 0 then
      begin
      if TempString[1] in SweepstakesPrecedences then
         begin
         if StringIsAllNumbers(Copy(string(TempString), 2, 1)) then
            begin
            Result := swPrecedenceThenCheck;
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
         end;
      end;

   (* A check and a section, or maybe just a section. *)
   Result := swCheckOrSection;
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

procedure ScanSweepstakesExchange(const aText: string; out aFields: TSweepstakesFields);
var
   Entries: TSweepstakesWords;
   NumberEntries: integer;
   Entry: integer;
begin
   aFields := Default(TSweepstakesFields);
   CutSweepstakesWords(aText, Entries, NumberEntries);

   for Entry := NumberEntries - 1 downto 0 do
      begin
      ProcessSweepstakesEntry(Entries[Entry], aFields);
      end;
end;

(* THE WORDS ARE FOLDED LAST FIRST, exactly as the scan folds them, and each
   reports the reading it took -- so this counts the shapes the engine SAW,
   with no grammar of its own. Walking backwards, the first two-digit word
   met is the LATER typed. *)
function SweepstakesSerialIsAmbiguous(const aText: string;
                                      out aFirst, aSecond: string;
                                      out aPrecedence: AnsiChar): boolean;
var
   Entries: TSweepstakesWords;
   NumberEntries: integer;
   Entry: integer;
   fields: TSweepstakesFields;
   aloneCount, joinedCount, otherDigitsCount, twoDigitsCount: integer;
   laterTwoDigits, earlierTwoDigits: string;
begin
   aFirst := '';
   aSecond := '';
   aPrecedence := Chr(0);

   fields := Default(TSweepstakesFields);
   CutSweepstakesWords(aText, Entries, NumberEntries);

   aloneCount := 0;
   joinedCount := 0;
   otherDigitsCount := 0;
   twoDigitsCount := 0;
   laterTwoDigits := '';
   earlierTwoDigits := '';

   for Entry := NumberEntries - 1 downto 0 do
      begin
      case ProcessSweepstakesEntry(Entries[Entry], fields) of
         swBareTwoDigits:
            begin
            inc(twoDigitsCount);
            if twoDigitsCount = 1 then
               begin
               laterTwoDigits := string(Entries[Entry]);
               end
            else if twoDigitsCount = 2 then
               begin
               earlierTwoDigits := string(Entries[Entry]);
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
         swPrecedenceThenCheck:
            begin
            inc(joinedCount);
            end;
         end;
      end;

   Result := (aloneCount > 0) and
             (joinedCount = 0) and
             (otherDigitsCount = 0) and
             (twoDigitsCount = 2);
   if Result then
      begin
      aFirst := earlierTwoDigits;
      aSecond := laterTwoDigits;
      aPrecedence := fields.Prec;
      end;
end;

end.

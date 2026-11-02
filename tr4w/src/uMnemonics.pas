unit uMnemonics;

(* KEYBOARD MNEMONICS (Alt+letter) FOR ONE GROUP OF TRANSLATED CAPTIONS.

   STAGE 1 OF THE MNEMONIC PLAN: the rule, and nothing else. This unit knows
   nothing about forms, menus or widget sets. It is given the captions of one
   group -- the controls of one form, or the items of one menu -- with the
   English accelerator letter of each and the letters already spoken for, and
   returns the captions with their '&' markers repaired so that no two items
   claim one letter. Wiring it to a form, and macOS (which has no Alt
   mnemonics), are stage 2.

   WHY IT IS NEEDED. A translation keeps its English accelerator only when the
   translated word happens to contain the same letter, and two translated
   captions on one form often land on the same letter -- '&Si' from the LCL's
   own catalogue and a TR4W '&Salvar' both claim S. Nothing in the build sees
   it; Alt+S simply picks one of them.

   DECISIONS (NY4I, 2026-11-02):
   - REPAIR ONLY WHERE THE ENGLISH HAS AN '&'. An item whose English letter is
     '' is returned byte-identical -- but a marker it carries anyway is still
     on screen, so its letter is TAKEN for everyone else.
   - The main menu bar's top level is out of scope: its letters reach this
     function as aReserved, like any other letter already in use.

   THE PARSE IS IsAccel's (lcl/forms.pp), not po_lint's. The accelerator is the
   character after the FIRST lone '&'; '&&' is a literal ampersand and is
   skipped as a pair; an '&' in the last position marks nothing. So '&&&Xenon'
   has accelerator X here, while po_lint's LONE_AMP regex sees no lone '&' at
   all, and '& Salvar' has a SPACE as its accelerator to IsAccel and is a
   defect to po_lint. Following the LCL is the point: it is what decides which
   control Alt+letter reaches.

   THE RULES, IN THE FIXED ORDER THEY ARE APPLIED. No hashing and no sort, so
   the same input always gives the same output, and running the output through
   again changes nothing (pinned by the tests on every vector).

   1. TAKEN starts as aReserved, upper-cased.
   2. Every item whose English letter is '' adds its own marker's letter, if
      it has one, in index order. Those items are never changed.
   3. Every other item, in index order, KEEPS a marker it already has when
      that marker is before a letter (or a digit) nobody has taken. Any further
      lone '&' in it is removed -- a second marker is ignored by IsAccel and
      painted by nobody, so it is noise. In a CJK caption (rule 4) only a
      marker on an ASCII letter or digit is kept. Keeping comes before assigning so
      that item 0 can never take a letter item 3 already holds; that is what
      makes a second run a no-op.
   4. What is left, in index order, has every lone '&' removed and is given a
      new letter:
        - a caption containing Han, kana or Hangul gets '(&X)' after the text,
          before one trailing '...', U+2026, ':' or U+FF1A -- '<save>(&S)...'
          -- which is the Windows convention and the LCL's own ja/ko/zh
          catalogues'. X is the English letter, else the first free A..Z.
          A '(&X)' group already in such a caption is removed whole, with
          the whitespace before it, before the new one goes on.
        - any other caption gets an '&' before one of its own characters, the
          first free one of: the English letter at a word start; the English
          letter anywhere; any letter at a word start; any letter. A digit is
          a candidate only when it IS the English letter.
      A character inside a %-specifier ('%s' holds an s), inside a literal
      '&&', or directly after one is never chosen -- the same positions
      mt_seed.place_accelerator blocks.
   5. When no candidate is free the item gets NO marker. A control without a
      mnemonic still works when clicked; a duplicate one does not work at all.

   "A LETTER" is any Unicode letter (Character.IsLetter), not only A..Z: a
   Russian form underlines Cyrillic letters, and the LCL compares the typed
   character against the caption's.

   CJK IS DECIDED BY THE CAPTION'S SCRIPT, because this function is not told
   the language. mt_seed.place_accelerator decides by the TARGET LANGUAGE
   instead, so the two disagree on a Japanese caption with no Japanese
   characters in it ('OK'); the shared vectors keep such rows out.

   WHY NOT Menus.StripHotkey OR LCLProc.RemoveAmpersands (asked to reuse them
   "where they fit"; they do not). Both turn '&&' into '&' -- they produce the
   DISPLAYED text, and this unit must return caption MARKUP in which a literal
   ampersand stays doubled. Both also take the LCL's 8-bit string, while this
   unit's string is UTF-16 (tr4w.inc), so every call would be a narrowing
   conversion counted against the build's ratcheted ceiling. And Menus would
   pull Graphics, ImgList and ActnList into a unit that is meant to be a leaf.

   THE SHARED TEST VECTORS are tr4w/test/unit/fixtures/mnemonic_vectors.txt.
   uTestMnemonics runs every row; tools/i18n/test_mnemonic_vectors.py runs the
   single-caption rows through mt_seed.place_accelerator, so the Pascal and the
   Python placement cannot drift apart unseen. *)

{$I tr4w.inc}

interface

type
   TMnemonicCaptions = array of string;

(* The 1-based index of the accelerator CHARACTER in aCaption -- the one after
   the first lone '&' -- or 0 when there is none. The IsAccel parse. *)
function AcceleratorIndex(const aCaption: string): integer;

(* That character as a one-character string, or ''. *)
function AcceleratorLetter(const aCaption: string): string;

(* Does the caption contain Han, kana or Hangul? Then its mnemonic is '(&X)'. *)
function IsCJKCaption(const aCaption: string): boolean;

(* The rules in the header. aEnglishLetters[i] is the English accelerator
   letter of aCaptions[i], or '' for an item that must not be changed; an index
   past the end of aEnglishLetters counts as ''. aReserved lists letters
   already in use, in any case. The result has one element per caption. *)
function AssignMnemonics(const aCaptions: array of string;
                         const aEnglishLetters: array of string;
                         const aReserved: string): TMnemonicCaptions;

implementation

uses
   Character;

const
   AMP = '&';
   ELLIPSIS        = #$2026;
   FULLWIDTH_COLON = #$FF1A;
   FULLWIDTH_OPEN  = #$FF08;
   FULLWIDTH_CLOSE = #$FF09;

type
   TFlags = array of boolean;

function AcceleratorIndex(const aCaption: string): integer;
var
   i: integer;
begin
   Result := 0;
   i := 1;
   (* '<' and not '<=': an '&' in the last position marks nothing. *)
   while i < Length(aCaption) do
      begin
      if aCaption[i] = AMP then
         begin
         if aCaption[i + 1] = AMP then
            begin
            i := i + 2;
            end
         else
            begin
            Result := i + 1;
            Exit;
            end;
         end
      else
         begin
         i := i + 1;
         end;
      end;
end;

function AcceleratorLetter(const aCaption: string): string;
var
   k: integer;
begin
   Result := '';
   k := AcceleratorIndex(aCaption);
   if k > 0 then
      begin
      Result := aCaption[k];
      end;
end;

function IsCJKChar(c: WideChar): boolean;
var
   n: integer;
begin
   n := Ord(c);
   Result := ((n >= $1100) and (n <= $11FF)) or    (* Hangul jamo *)
             ((n >= $2E80) and (n <= $2FDF)) or    (* CJK and Kangxi radicals *)
             ((n >= $3040) and (n <= $30FF)) or    (* hiragana, katakana *)
             ((n >= $3100) and (n <= $318F)) or    (* bopomofo, Hangul compatibility jamo *)
             ((n >= $3400) and (n <= $4DBF)) or    (* CJK extension A *)
             ((n >= $4E00) and (n <= $9FFF)) or    (* CJK unified ideographs *)
             ((n >= $AC00) and (n <= $D7AF)) or    (* Hangul syllables *)
             ((n >= $F900) and (n <= $FAFF)) or    (* CJK compatibility ideographs *)
             ((n >= $FF66) and (n <= $FF9F));      (* half-width katakana *)
end;

function IsCJKCaption(const aCaption: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := 1 to Length(aCaption) do
      begin
      if IsCJKChar(aCaption[i]) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function IsAsciiDigit(c: WideChar): boolean;
begin
   Result := (c >= '0') and (c <= '9');
end;

(* A character a mnemonic may sit on at all. A digit only when the English
   chose it is decided by the caller. *)
function IsMnemonicChar(c: WideChar): boolean;
begin
   Result := IsLetter(c) or IsAsciiDigit(c);
end;

function UpperOf(c: WideChar): WideChar;
begin
   Result := ToUpper(c);
end;

function IsTaken(const aTaken: string; c: WideChar): boolean;
begin
   Result := Pos(UpperOf(c), aTaken) > 0;
end;

procedure Take(var aTaken: string; c: WideChar);
begin
   if not IsTaken(aTaken, c) then
      begin
      aTaken := aTaken + UpperOf(c);
      end;
end;

(* aCaption with every lone '&' removed except the one at aKeep (0 = none).
   A '&&' pair is copied as it stands. *)
function RemoveMarkersExcept(const aCaption: string; aKeep: integer): string;
var
   i: integer;
begin
   Result := '';
   i := 1;
   while i <= Length(aCaption) do
      begin
      if aCaption[i] = AMP then
         begin
         if (i < Length(aCaption)) and (aCaption[i + 1] = AMP) then
            begin
            Result := Result + AMP + AMP;
            i := i + 2;
            end
         else
            begin
            if i = aKeep then
               begin
               Result := Result + AMP;
               end;
            i := i + 1;
            end;
         end
      else
         begin
         Result := Result + aCaption[i];
         i := i + 1;
         end;
      end;
end;

function IsOpenParen(c: WideChar): boolean;
begin
   Result := (c = '(') or (c = FULLWIDTH_OPEN);
end;

function IsCloseParen(c: WideChar): boolean;
begin
   Result := (c = ')') or (c = FULLWIDTH_CLOSE);
end;

(* Every '(&X)' group removed whole, with the whitespace before it. The '&'
   must be a lone one: '(&&X)' is literal text. *)
function RemoveSuffixGroups(const aCaption: string): string;
var
   i, start: integer;
begin
   Result := aCaption;
   i := 1;
   while i + 3 <= Length(Result) do
      begin
      if IsOpenParen(Result[i])        and
         (Result[i + 1] = AMP)         and
         (Result[i + 2] <> AMP)        and
         IsCloseParen(Result[i + 3]) then
         begin
         start := i;
         while (start > 1) and (Result[start - 1] = ' ') do
            begin
            start := start - 1;
            end;
         Delete(Result, start, (i + 4) - start);
         i := start;
         end
      else
         begin
         i := i + 1;
         end;
      end;
end;

(* The length of a %-specifier starting at aStart, or 0 if none starts there.
   The same shape as pasconsts.PLACEHOLDER_RE: '%', any of '-' '#' '0', an
   optional width (digits or a star), an optional '.' with a precision
   (digits or a star), then one of c C d i s S u x X %. (The regex itself
   cannot be quoted here: its star-paren would close this comment.) *)
function SpecifierLength(const s: string; aStart: integer): integer;
var
   i: integer;
begin
   Result := 0;
   if s[aStart] <> '%' then
      begin
      Exit;
      end;
   i := aStart + 1;
   while (i <= Length(s)) and ((s[i] = '-') or (s[i] = '#') or (s[i] = '0')) do
      begin
      i := i + 1;
      end;
   if (i <= Length(s)) and (s[i] = '*') then
      begin
      i := i + 1;
      end
   else
      begin
      while (i <= Length(s)) and IsAsciiDigit(s[i]) do
         begin
         i := i + 1;
         end;
      end;
   if (i <= Length(s)) and (s[i] = '.') then
      begin
      if (i + 1 <= Length(s)) and (s[i + 1] = '*') then
         begin
         i := i + 2;
         end
      else if (i + 1 <= Length(s)) and IsAsciiDigit(s[i + 1]) then
         begin
         i := i + 1;
         while (i <= Length(s)) and IsAsciiDigit(s[i]) do
            begin
            i := i + 1;
            end;
         end;
      end;
   if (i <= Length(s)) and (Pos(s[i], 'cCdisSuxX%') > 0) then
      begin
      Result := (i - aStart) + 1;
      end;
end;

(* Which positions of aText a marker may not go before. *)
function BlockedPositions(const aText: string): TFlags;
var
   i, j, n: integer;
begin
   Result := nil;
   SetLength(Result, Length(aText) + 1);
   for i := 0 to Length(aText) do
      begin
      Result[i] := False;
      end;
   i := 1;
   while i <= Length(aText) do
      begin
      if (aText[i] = AMP) and (i < Length(aText)) and (aText[i + 1] = AMP) then
         begin
         (* The pair, and the character after it: '&&&x' is legal to IsAccel
            but reads as '&&' plus nothing to po_lint and mt_seed. *)
         for j := i to i + 2 do
            begin
            if j <= Length(aText) then
               begin
               Result[j] := True;
               end;
            end;
         i := i + 2;
         end
      else
         begin
         n := SpecifierLength(aText, i);
         if n > 0 then
            begin
            for j := i to i + n - 1 do
               begin
               Result[j] := True;
               end;
            i := i + n;
            end
         else
            begin
            i := i + 1;
            end;
         end;
      end;
end;

function IsWordStart(const aText: string; i: integer): boolean;
begin
   Result := (i = 1) or not IsMnemonicChar(aText[i - 1]);
end;

(* Tier 1..4 of rule 4, inline. Returns the position, or 0. *)
function PickInline(const aText: string; aEnglish: WideChar;
                    const aTaken: string): integer;
var
   blocked: TFlags;
   tier, i: integer;
   c: WideChar;
   fits: boolean;
begin
   Result := 0;
   blocked := BlockedPositions(aText);
   for tier := 1 to 4 do
      begin
      for i := 1 to Length(aText) do
         begin
         c := aText[i];
         if blocked[i] or IsTaken(aTaken, c) then
            begin
            Continue;
            end;
         case tier of
            1:
               begin
               fits := (UpperOf(c) = UpperOf(aEnglish)) and IsWordStart(aText, i);
               end;
            2:
               begin
               fits := UpperOf(c) = UpperOf(aEnglish);
               end;
            3:
               begin
               fits := IsLetter(c) and IsWordStart(aText, i);
               end;
            else
               begin
               fits := IsLetter(c);
               end;
            end;
         if fits and IsMnemonicChar(c) then
            begin
            Result := i;
            Exit;
            end;
         end;
      end;
end;

(* Where '(&X)' goes: before one trailing '...', ellipsis or colon, and the
   whitespace around it -- the shape of mt_seed.place_accelerator's regex,
   whitespace, then at most one of '...' U+2026 ':' U+FF1A, then whitespace,
   at the end. Returns the 1-based insertion index. *)
function SuffixCut(const aText: string): integer;
var
   i: integer;
begin
   i := Length(aText);
   while (i >= 1) and (aText[i] = ' ') do
      begin
      i := i - 1;
      end;
   if (i >= 3) and (Copy(aText, i - 2, 3) = '...') then
      begin
      i := i - 3;
      end
   else if (i >= 1) and ((aText[i] = ELLIPSIS) or (aText[i] = ':') or (aText[i] = FULLWIDTH_COLON)) then
      begin
      i := i - 1;
      end;
   while (i >= 1) and (aText[i] = ' ') do
      begin
      i := i - 1;
      end;
   Result := i + 1;
end;

(* The suffix letter: the English letter upper-cased if free, else the first
   free A..Z. #0 when none is free. *)
function PickSuffix(aEnglish: WideChar; const aTaken: string): WideChar;
var
   c: WideChar;
begin
   Result := #0;
   if IsMnemonicChar(aEnglish) and (Ord(aEnglish) < 128) and not IsTaken(aTaken, aEnglish) then
      begin
      Result := UpperOf(aEnglish);
      Exit;
      end;
   for c := 'A' to 'Z' do
      begin
      if not IsTaken(aTaken, c) then
         begin
         Result := c;
         Exit;
         end;
      end;
end;

function AssignMnemonics(const aCaptions: array of string;
                         const aEnglishLetters: array of string;
                         const aReserved: string): TMnemonicCaptions;
var
   n, i, k, cut: integer;
   taken, text: string;
   managed, done: array of boolean;
   english: array of WideChar;
   letter: WideChar;
begin
   n := Length(aCaptions);
   Result := nil;
   SetLength(Result, n);
   SetLength(managed, n);
   SetLength(done, n);
   SetLength(english, n);

   (* Rule 1. *)
   taken := '';
   for i := 1 to Length(aReserved) do
      begin
      if IsMnemonicChar(aReserved[i]) then
         begin
         Take(taken, aReserved[i]);
         end;
      end;

   for i := 0 to n - 1 do
      begin
      Result[i] := aCaptions[i];
      managed[i] := (i <= High(aEnglishLetters)) and (Length(aEnglishLetters[i]) > 0);
      done[i] := not managed[i];
      english[i] := ' ';
      if managed[i] then
         begin
         english[i] := aEnglishLetters[i][1];
         end;
      end;

   (* Rule 2: the items left alone, whose letters are still on screen. *)
   for i := 0 to n - 1 do
      begin
      if not managed[i] then
         begin
         k := AcceleratorIndex(aCaptions[i]);
         if (k > 0) and IsMnemonicChar(aCaptions[i][k]) then
            begin
            Take(taken, aCaptions[i][k]);
            end;
         end;
      end;

   (* Rule 3: keep what is already sound. *)
   for i := 0 to n - 1 do
      begin
      if managed[i] then
         begin
         k := AcceleratorIndex(aCaptions[i]);
         (* In a CJK caption only an ASCII letter or digit is kept: a marker
            on a kana or a hanzi is not a key anyone can press. *)
         if (k > 0)                                                   and
            IsMnemonicChar(aCaptions[i][k])                           and
            ((Ord(aCaptions[i][k]) < 128) or not IsCJKCaption(aCaptions[i])) and
            not IsTaken(taken, aCaptions[i][k]) then
            begin
            Take(taken, aCaptions[i][k]);
            Result[i] := RemoveMarkersExcept(aCaptions[i], k - 1);
            done[i] := True;
            end;
         end;
      end;

   (* Rule 4 and 5: assign the rest, in index order. *)
   for i := 0 to n - 1 do
      begin
      if done[i] then
         begin
         Continue;
         end;
      if IsCJKCaption(aCaptions[i]) then
         begin
         text := RemoveMarkersExcept(RemoveSuffixGroups(aCaptions[i]), 0);
         letter := PickSuffix(english[i], taken);
         if letter <> #0 then
            begin
            Take(taken, letter);
            cut := SuffixCut(text);
            Insert('(' + AMP + letter + ')', text, cut);
            end;
         Result[i] := text;
         end
      else
         begin
         text := RemoveMarkersExcept(aCaptions[i], 0);
         k := PickInline(text, english[i], taken);
         if k > 0 then
            begin
            Take(taken, text[k]);
            Insert(AMP, text, k);
            end;
         Result[i] := text;
         end;
      end;
end;

end.

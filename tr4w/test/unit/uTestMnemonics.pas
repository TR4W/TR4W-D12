unit uTestMnemonics;

(* KEYBOARD MNEMONICS -- uMnemonics.AssignMnemonics, stage 1 of the plan.

   Most cases live in fixtures/mnemonic_vectors.txt rather than here, because
   the same rows are run through mt_seed.place_accelerator by
   tools/i18n/test_mnemonic_vectors.py. Two implementations of one placement
   rule drift unless something runs both over the same inputs; the file is
   that something. Its header describes the row kinds.

   Every vector is also run a SECOND time over its own output and must come
   back unchanged: stage 2 will apply this to captions that already carry the
   result of an earlier run, and a rule that moved a marker each time would
   rewrite every catalogue on every pass.

   The direct tests below cover what a row of text cannot say: the IsAccel
   parse on its own, and an aEnglishLetters array shorter than the captions. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TMnemonicTests = class(TTestCase)
   private
      FLines: array of string;
      FLoaded: boolean;
      procedure LoadVectors;
   protected
      procedure TestVectorFileLoads;
      procedure TestPlaceRows;
      procedure TestSetRows;
      procedure TestAcceleratorIndexIsTheIsAccelParse;
      procedure TestIsCJKCaption;
      procedure TestShortLetterArrayLeavesTheRestAlone;
      procedure TestEmptyInput;
      procedure TestDisplayedText;
      procedure TestMarkupFollowsTheCapability;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uMnemonics, uMnemonicsLCL;

type
   TFields = array of string;

function Num(n: integer): string;
var
   s: ShortString;
begin
   Str(n, s);
   Result := string(s);
end;

(* Split on '|' with nothing trimmed. *)
function SplitBar(const aLine: string): TFields;
var
   i, start: integer;
begin
   Result := nil;
   start := 1;
   for i := 1 to Length(aLine) + 1 do
      begin
      if (i > Length(aLine)) or (aLine[i] = '|') then
         begin
         SetLength(Result, Length(Result) + 1);
         Result[High(Result)] := Copy(aLine, start, i - start);
         start := i + 1;
         end;
      end;
end;

(* '-' in a letter or reserved field means none. *)
function Field(const s: string): string;
begin
   Result := s;
   if s = '-' then
      begin
      Result := '';
      end;
end;

procedure TMnemonicTests.LoadVectors;
var
   path: string;
   handle: THandle;
   size: integer;
   bytes: RawByteString;
   text, line: string;
   i, start: integer;
begin
   if FLoaded then
      begin
      Exit;
      end;
   FLoaded := True;
   SetLength(FLines, 0);
   path := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim + 'mnemonic_vectors.txt';
   if not FileExists(path) then
      begin
      Exit;
      end;
   (* FileOpen, not TFileStream: Classes takes the 8-bit string, so passing
      this unit's UTF-16 path would be a narrowing conversion. *)
   handle := FileOpen(path, fmOpenRead or fmShareDenyWrite);
   if handle = THandle(-1) then
      begin
      Exit;
      end;
   try
      size := FileSeek(handle, 0, fsFromEnd);
      FileSeek(handle, 0, fsFromBeginning);
      SetLength(bytes, size);
      if size > 0 then
         begin
         FileRead(handle, bytes[1], size);
         end;
   finally
      FileClose(handle);
   end;
   (* Read as bytes and decoded once, explicitly: TStringList would decode
      with the build machine's ANSI codepage and mangle every non-ASCII row. *)
   text := UTF8Decode(bytes);
   start := 1;
   for i := 1 to Length(text) + 1 do
      begin
      if (i > Length(text)) or (text[i] = #10) then
         begin
         line := Copy(text, start, i - start);
         if (Length(line) > 0) and (line[Length(line)] = #13) then
            begin
            SetLength(line, Length(line) - 1);
            end;
         if (Length(line) > 0) and (line[1] <> '#') then
            begin
            SetLength(FLines, Length(FLines) + 1);
            FLines[High(FLines)] := line;
            end;
         start := i + 1;
         end;
      end;
end;

procedure TMnemonicTests.TestVectorFileLoads;
var
   i, places, sets: integer;
begin
   BeginTest('TestVectorFileLoads');
   LoadVectors;
   places := 0;
   sets := 0;
   for i := 0 to High(FLines) do
      begin
      if Copy(FLines[i], 1, 6) = 'place|' then
         begin
         places := places + 1;
         end
      else if Copy(FLines[i], 1, 4) = 'set|' then
         begin
         sets := sets + 1;
         end;
      end;
   (* A fixture that silently went missing or empty would pass every other
      test in this suite. *)
   CheckTrue(places >= 10, 'mnemonic_vectors.txt should hold 10+ place rows, saw ' + Num(places));
   CheckTrue(sets >= 10, 'mnemonic_vectors.txt should hold 10+ sets, saw ' + Num(sets));
end;

procedure TMnemonicTests.TestPlaceRows;
var
   i: integer;
   f: TFields;
   once, twice: TMnemonicCaptions;
begin
   BeginTest('TestPlaceRows');
   LoadVectors;
   for i := 0 to High(FLines) do
      begin
      if Copy(FLines[i], 1, 6) <> 'place|' then
         begin
         Continue;
         end;
      f := SplitBar(FLines[i]);
      if Length(f) <> 5 then
         begin
         CheckTrue(False, 'malformed place row: ' + FLines[i]);
         Continue;
         end;
      once := AssignMnemonics([f[3]], [Field(f[2])], '');
      CheckEquals(f[4], once[0], 'place ' + f[1] + ' "' + f[3] + '"');
      twice := AssignMnemonics([once[0]], [Field(f[2])], '');
      CheckEquals(once[0], twice[0], 'second run changed place ' + f[1] + ' "' + f[3] + '"');
      end;
end;

procedure TMnemonicTests.TestSetRows;
var
   i, j, count: integer;
   f: TFields;
   name, reserved: string;
   captions, letters, expected: array of string;
   once, twice: TMnemonicCaptions;
   inSet: boolean;
begin
   BeginTest('TestSetRows');
   LoadVectors;
   inSet := False;
   count := 0;
   for i := 0 to High(FLines) do
      begin
      f := SplitBar(FLines[i]);
      if f[0] = 'set' then
         begin
         CheckFalse(inSet, 'set opened inside a set: ' + FLines[i]);
         inSet := True;
         name := f[1];
         reserved := '';
         if Length(f) >= 3 then
            begin
            reserved := Field(f[2]);
            end;
         SetLength(captions, 0);
         SetLength(letters, 0);
         SetLength(expected, 0);
         end
      else if f[0] = 'item' then
         begin
         CheckTrue(inSet and (Length(f) = 4), 'malformed item row: ' + FLines[i]);
         if inSet and (Length(f) = 4) then
            begin
            SetLength(captions, Length(captions) + 1);
            SetLength(letters, Length(letters) + 1);
            SetLength(expected, Length(expected) + 1);
            letters[High(letters)] := Field(f[1]);
            captions[High(captions)] := f[2];
            expected[High(expected)] := f[3];
            end;
         end
      else if f[0] = 'end' then
         begin
         CheckTrue(inSet, 'end outside a set');
         inSet := False;
         count := count + 1;
         once := AssignMnemonics(captions, letters, reserved);
         CheckEquals(Length(captions), Length(once), name + ': one result per caption');
         for j := 0 to High(captions) do
            begin
            CheckEquals(expected[j], once[j], name + ', item ' + Num(j));
            end;
         twice := AssignMnemonics(once, letters, reserved);
         for j := 0 to High(captions) do
            begin
            CheckEquals(once[j], twice[j], name + ', item ' + Num(j) + ', second run');
            end;
         end
      else if f[0] <> 'place' then
         begin
         CheckTrue(False, 'unknown row kind: ' + FLines[i]);
         end;
      end;
   CheckFalse(inSet, 'the last set has no end line');
   CheckTrue(count > 0, 'no sets were run');
end;

procedure TMnemonicTests.TestAcceleratorIndexIsTheIsAccelParse;
begin
   BeginTest('TestAcceleratorIndexIsTheIsAccelParse');
   CheckEquals(0, AcceleratorIndex(''), 'empty');
   CheckEquals(0, AcceleratorIndex('&'), 'a lone & in the last position');
   CheckEquals(0, AcceleratorIndex('Save&'), 'an & at the end marks nothing');
   CheckEquals(0, AcceleratorIndex('A && B'), '&& is literal');
   CheckEquals(0, AcceleratorIndex('&&'), '&& alone');
   CheckEquals(2, AcceleratorIndex('&Save'), 'the first character');
   CheckEquals(4, AcceleratorIndex('&&&Xenon'), 'the pair is skipped, then the marker');
   CheckEquals(4, AcceleratorIndex('Sa&ve &As'), 'the FIRST lone & counts');
   CheckEquals(2, AcceleratorIndex('& Salvar'), 'IsAccel takes a space too');
   CheckEquals('v', AcceleratorLetter('Sa&ve'), 'the letter as written');
   CheckEquals('', AcceleratorLetter('Save'), 'none');
end;

procedure TMnemonicTests.TestIsCJKCaption;
begin
   BeginTest('TestIsCJKCaption');
   CheckFalse(IsCJKCaption('Copy'), 'Latin');
   CheckFalse(IsCJKCaption(#$041A#$043E#$043F#$0438#$044F), 'Cyrillic');
   CheckTrue(IsCJKCaption(#$30B3#$30D4#$30FC), 'katakana');
   CheckTrue(IsCJKCaption(#$590D#$5236), 'hanzi');
   CheckTrue(IsCJKCaption(#$B2EB#$AE30), 'Hangul');
   CheckTrue(IsCJKCaption('CW ' + #$901F#$5EA6), 'mixed Latin and hanzi');
   (* CJK punctuation alone is not CJK text. *)
   CheckFalse(IsCJKCaption('OK' + #$3002), 'an ideographic full stop alone');
end;

procedure TMnemonicTests.TestShortLetterArrayLeavesTheRestAlone;
var
   r: TMnemonicCaptions;
begin
   BeginTest('TestShortLetterArrayLeavesTheRestAlone');
   (* Item 1 has no letter at all, so it is not touched -- and its marker on C
      is still on screen, so item 0 cannot have C. *)
   r := AssignMnemonics(['Copiar', '&Cerrar'], ['C'], '');
   CheckEquals(2, Length(r), 'one result per caption');
   CheckEquals('C&opiar', r[0], 'item 0 yields C to the untouched item');
   CheckEquals('&Cerrar', r[1], 'item 1 is byte-identical');
end;

procedure TMnemonicTests.TestEmptyInput;
var
   none: array of string;
   r: TMnemonicCaptions;
begin
   BeginTest('TestEmptyInput');
   SetLength(none, 0);
   r := AssignMnemonics(none, none, 'ABC');
   CheckEquals(0, Length(r), 'no captions, no results');
end;

(* uMnemonicsLCL.DisplayedText: the text a caption PAINTS. '&&' is the case the
   hand-written stripper it replaced in uQTCSendForm got wrong -- it removed
   both ampersands, so a literal one measured as nothing. *)
procedure TMnemonicTests.TestDisplayedText;
begin
   BeginTest('TestDisplayedText');
   CheckEquals('File', string(DisplayedText('&File')), 'a lone marker is removed');
   CheckEquals('Exit', string(DisplayedText('E&xit')), 'wherever it is');
   CheckEquals('Q&A', string(DisplayedText('Q&&A')), '&& paints one &');
   CheckEquals('A&B', string(DisplayedText('A&&&B')), 'the pair, then a marker');
   CheckEquals('&', string(DisplayedText('&&')), '&& alone');
   CheckEquals('Save', string(DisplayedText('Save&')), 'a trailing lone & paints nothing');
   CheckEquals('NEXT [return]', string(DisplayedText('N&EXT [return]')),
               'a QTC button caption measures as before');
   CheckEquals('Beacons monitor', string(DisplayedText('Beacons monitor')),
               'a caption with no markup is unchanged');
   CheckEquals('', string(DisplayedText('')), 'empty');
end;

(* uMnemonicsLCL.MnemonicMarkupFor: both outcomes, on any platform. The live
   capability is deliberately not pinned -- that would be an {$IFDEF} on the
   platform, moved into the suite. *)
procedure TMnemonicTests.TestMarkupFollowsTheCapability;
begin
   BeginTest('TestMarkupFollowsTheCapability');
   CheckTrue(MnemonicMarkupFor(True) = mmAssign,
             'a widget set that honours & gets mnemonics');
   CheckTrue(MnemonicMarkupFor(False) = mmLeaveAlone,
             'one that does not (Cocoa) gets none written');
end;

procedure TMnemonicTests.RunAllTests;
begin
   TestVectorFileLoads;
   TestPlaceRows;
   TestSetRows;
   TestAcceleratorIndexIsTheIsAccelParse;
   TestIsCJKCaption;
   TestShortLetterArrayLeavesTheRestAlone;
   TestEmptyInput;
   TestDisplayedText;
   TestMarkupFollowsTheCapability;
end;

end.

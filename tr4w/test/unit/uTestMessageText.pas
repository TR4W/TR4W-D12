unit uTestMessageText;
{$I ..\..\src\tr4w.inc}

(*
  THE BRACE WORDS OF A PROGRAM MESSAGE (NY4I, 2026-11-20) -- uMessageText,
  the one grammar, and the two places that act on it: uProcessCommand's
  FoundCommand (commands run and taken out, unknown words skipped) and the
  old-bookend upgrade.

  uProcessCommand is linked, so the command table's names are registered;
  the commands used with FoundCommand here match no table row, so no handler
  runs.
*)

interface

uses
   SysUtils, Contnrs,
   uTR4WTestFramework, VC, uMessageText, uProcessCommand;

type
   TMessageTextTests = class(TTestCase)
   protected
      procedure Test_CrypticCharactersAreText;
      procedure Test_TokensAndCommands;
      procedure Test_LoneAndOddBraces;
      procedure Test_UnknownWords;
      procedure Test_OldBookendsAndTheirUpgrade;
      procedure Test_ChainPredicate;
      procedure Test_PickerText;
      procedure Test_FoundCommandTakesOutCommandsAndUnknownWords;
   public
      procedure RunAllTests; override;
   end;

implementation

function PartsOf(const aText: AnsiString): string;
var
   parts: TObjectList;
   i: integer;
   p: TMessagePart;
begin
   Result := '';
   parts := TObjectList.Create(True);
   try
      ParseMessage(aText, parts);
      for i := 0 to parts.Count - 1 do
         begin
         p := TMessagePart(parts[i]);
         case p.Kind of
            mpText:
               begin
               Result := Result + 'T[' + string(p.Text) + ']';
               end;
            mpToken:
               begin
               Result := Result + 'K[' + string(p.Name) + ']';
               end;
            mpCommand:
               begin
               Result := Result + 'C[' + string(p.Name);
               if p.HasArgument then
                  begin
                  Result := Result + '=' + string(p.Argument);
                  end;
               Result := Result + ']';
               end;
            mpUnknownWord:
               begin
               Result := Result + 'U[' + string(p.Name) + ']';
               end;
            mpOldCommand:
               begin
               Result := Result + 'O[' + string(p.Text) + ']';
               end;
         end;
         end;
   finally
      parts.Free;
   end;
end;

procedure TMessageTextTests.Test_CrypticCharactersAreText;
begin
   BeginTest('Test_CrypticCharactersAreText');
   CheckEquals('T[CQ TEST \ \ TEST]', PartsOf('CQ TEST \ \ TEST'), 'my call, as text');
   CheckEquals('T[@ DE \ 5NN #+1 ]}]', PartsOf('@ DE \ 5NN #+1 ]}'),
               'every cryptic character stays text, for the CW sender');
   CheckEquals('', PartsOf(''), 'empty');
end;

procedure TMessageTextTests.Test_TokensAndCommands;
begin
   BeginTest('Test_TokensAndCommands');
   CheckEquals('T[599 ]K[ROVERQTH]', PartsOf('599 {ROVERQTH}'), 'ROVERQTH');
   CheckEquals('T[DE ]K[ROVERCALL]T[ K]', PartsOf('DE {ROVERCALL} K'), 'ROVERCALL');
   CheckEquals('K[ROVERCALL]', PartsOf('{rovercall}'), 'any case');
   CheckEquals('C[MM_GRABLASTCALL]', PartsOf('{MM_GRABLASTCALL}'), 'a table command');
   CheckEquals('C[BANDUP]C[BANDDOWN]', PartsOf('{bandup}{BandDown}'), 'BANDUP / BANDDOWN exist');
   CheckEquals('C[SPOTME]', PartsOf('{SPOTME}'), 'SPOTME');
   CheckEquals('C[QSY]C[SPEED25]', PartsOf('{QSY}{SPEED25}'), 'QSY and SPEEDnn');
   CheckEquals('C[SRS=PB1;]', PartsOf('{SRS=PB1;}'), 'an argument, as written');
   CheckEquals('C[SENDTOCLUSTER=hi There]', PartsOf('{sendtocluster=hi There}'),
               'the argument keeps its case and spaces');
   CheckEquals('U[ROVERCALL]', PartsOf('{ROVERCALL=X}'), 'a token takes no argument');
end;

procedure TMessageTextTests.Test_LoneAndOddBraces;
begin
   BeginTest('Test_LoneAndOddBraces');
   CheckEquals('T[{ TU]', PartsOf('{ TU'), 'a lone { is the worked call');
   CheckEquals('T[{}]', PartsOf('{}'), 'empty braces: worked call, partial call');
   CheckEquals('T[{]U[X]T[}]', PartsOf('{{X}}'), '{{X}}: {, the word X, }');
   CheckEquals('T[TU {ROVERQT]', PartsOf('TU {ROVERQT'), 'no closing brace');
   CheckEquals('T[A{B]', PartsOf('A{B'), 'inside a word, unclosed');
   CheckEquals('T[{ALT-D}]', PartsOf('{ALT-D}'), 'a dash is no word character');
   CheckEquals('T[{A B}]', PartsOf('{A B}'), 'a space is no word character');
end;

procedure TMessageTextTests.Test_UnknownWords;
begin
   BeginTest('Test_UnknownWords');
   CheckEquals('U[NOSUCHWORD]', PartsOf('{NoSuchWord}'), 'unknown');
   CheckEquals('NoSuchWord', string(FirstUnknownMessageWord('CQ {NoSuchWord} {BANDUP}')),
               'named as written');
   CheckEquals('', string(FirstUnknownMessageWord('CQ {ROVERCALL} {BANDUP} { \')),
               'nothing unknown');
end;

procedure TMessageTextTests.Test_OldBookendsAndTheirUpgrade;
var
   s, up: AnsiString;
   converted, leftAlone: integer;
begin
   BeginTest('Test_OldBookendsAndTheirUpgrade');
   CheckEquals('O[MM_GRABLASTCALL]', PartsOf(#3'MM_GRABLASTCALL'#4), 'the old form parses');

   up := UpgradeMessageBookends(#3'MM_GRABLASTCALL'#4, converted, leftAlone);
   CheckEquals('{MM_GRABLASTCALL}', string(up), 'converted');
   CheckEquals(1, converted, 'one converted');
   CheckEquals(0, leftAlone, 'none left');

   up := UpgradeMessageBookends('CQ '#3'SRS=PB1;'#4' {BANDUP} '#3#1'SRS=X'#4' '#3'SPEED+'#4,
                                converted, leftAlone);
   CheckEquals('CQ {SRS=PB1;} {BANDUP} '#3#1'SRS=X'#4' '#3'SPEED+'#4, string(up),
               'both forms: the old one converts; Ctrl-A and SPEED+ stay');
   CheckEquals(1, converted, 'one converted');
   CheckEquals(2, leftAlone, 'two left as they were');

   up := UpgradeMessageBookends(#3'NOSUCHCOMMAND'#4, converted, leftAlone);
   CheckEquals(#3'NOSUCHCOMMAND'#4, string(up), 'an unknown name stays in the old form');

   up := UpgradeMessageBookends('TU'#4' '#3'BANDUP', converted, leftAlone);
   CheckEquals('TU'#4' '#3'BANDUP', string(up), 'a lone Ctrl-D and an unclosed Ctrl-C untouched');
   CheckEquals(0, converted + leftAlone, 'not pairs');

   (* 255 bytes: two bytes for two bytes. *)
   s := StringOfChar(AnsiChar('A'), 255 - 10) + #3'BANDDOWN'#4;
   CheckEquals(255, Length(s), 'a full memory');
   up := UpgradeMessageBookends(s, converted, leftAlone);
   CheckEquals(255, Length(up), 'still 255 after the conversion');
   CheckEquals('{BANDDOWN}', string(Copy(up, 246, 10)), 'and it is the brace form');
end;

procedure TMessageTextTests.Test_ChainPredicate;
begin
   BeginTest('Test_ChainPredicate');
   CheckTrue(MessageChainsOrCommands(#3'BANDUP'#4), 'an old command never flushed');
   CheckTrue(MessageChainsOrCommands('{MM_GRABLASTCALL}'), 'nor does its brace form');
   CheckTrue(MessageChainsOrCommands('TU'#4), 'the chain Ctrl-D');
   CheckFalse(MessageChainsOrCommands('CQ {ROVERCALL}'), 'a token flushes');
   CheckFalse(MessageChainsOrCommands('CQ {NOSUCH}'), 'an unknown word flushes');
   CheckFalse(MessageChainsOrCommands('CQ TEST \'), 'plain text flushes');
end;

procedure TMessageTextTests.Test_PickerText;
begin
   BeginTest('Test_PickerText');
   CheckEquals('{MM_GRABLASTCALL}', string(MessagePickerText('MM_GRABLASTCALL')), 'a command');
   CheckEquals('{OTRSP=RX1}', string(MessagePickerText('OTRSP=RX1')), 'with its argument');
   CheckEquals('#', string(MessagePickerText('#')), 'a cryptic character');
   CheckEquals('ALT-D', string(MessagePickerText('ALT-D')), 'no brace form');
   CheckEquals('{ROVERCALL}', string(MessagePickerText('{ROVERCALL}')), 'a token row');
end;

procedure TMessageTextTests.Test_FoundCommandTakesOutCommandsAndUnknownWords;
var
   s: Str160;
begin
   BeginTest('Test_FoundCommandTakesOutCommandsAndUnknownWords');
   s := '5NN {ROVERQTH} {ZZNOSUCHWORDFORTEST} TU';
   CheckTrue(FoundCommand(s), 'an unknown word was taken out');
   CheckEquals('5NN {ROVERQTH}  TU', string(s), 'the token stays; the word is never keyed');

   s := 'CQ \ \';
   CheckFalse(FoundCommand(s), 'plain text');
   CheckEquals('CQ \ \', string(s), 'untouched');

   s := 'TU'#4' QRZ';
   CheckFalse(FoundCommand(s), 'a lone chain Ctrl-D is no command');
   CheckEquals('TU'#4' QRZ', string(s), 'and it stays for the sender');

   s := 'TU'#4' '#3'ZZNOSUCHCOMMANDFORTEST'#4'X';
   CheckTrue(FoundCommand(s), 'a chain Ctrl-D before a bookend no longer loops');
   CheckEquals('TU'#4' X', string(s), 'the bookend is taken out');
end;

procedure TMessageTextTests.RunAllTests;
begin
   Test_CrypticCharactersAreText;
   Test_TokensAndCommands;
   Test_LoneAndOddBraces;
   Test_UnknownWords;
   Test_OldBookendsAndTheirUpgrade;
   Test_ChainPredicate;
   Test_PickerText;
   Test_FoundCommandTakesOutCommandsAndUnknownWords;
end;

end.

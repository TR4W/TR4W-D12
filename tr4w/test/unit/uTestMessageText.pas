unit uTestMessageText;
{$I ..\..\src\tr4w.inc}

(*
  THE BRACE WORDS OF A PROGRAM MESSAGE (NY4I, 2026-11-20) -- uMessageText,
  the one grammar, and the two places that act on it: uProcessCommand's
  FoundCommand (commands run and taken out, unknown words skipped) and the
  old-bookend upgrade.

  NY4I's rule: '{' stands for <03> and '}' for <04>; a body is any text but a
  brace, run as <03>BODY<04> runs; a leading '$' is the inactive radio (the
  old Ctrl-A).

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
      procedure Test_TheInactiveRadioMark;
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

(* T[text] K[token] C[command line, Ctrl-A shown as ^A] U[body] O[old body] *)
function PartsOf(const aText: AnsiString): string;
var
   parts: TObjectList;
   i: integer;
   p: TMessagePart;
   line: string;
begin
   Result := '';
   parts := TObjectList.Create(True);
   try
      ParseMessage(aText, parts);
      for i := 0 to parts.Count - 1 do
         begin
         p := TMessagePart(parts[i]);
         line := StringReplace(string(p.CommandLine), #1, '^A', []);
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
               Result := Result + 'C[' + line + ']';
               end;
            mpUnknownWord:
               begin
               Result := Result + 'U[' + string(p.Body) + ']';
               end;
            mpOldCommand:
               begin
               Result := Result + 'O[' + line + ']';
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
   CheckEquals('T[~ $ % ]', PartsOf('~ $ % '), 'a $ outside braces is the salutation, as ever');
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
   CheckEquals('C[SPEED+]C[SPEED--]', PartsOf('{SPEED+}{speed--}'), 'SPEED+ and SPEED-');
   CheckEquals('C[ALT-D]', PartsOf('{ALT-D}'), 'ALT-D, a dash and all');
   CheckEquals('C[SRS=PB1;]', PartsOf('{SRS=PB1;}'), 'an argument, as written');
   CheckEquals('C[OTRSP=RX1]', PartsOf('{otrsp=RX1}'), 'the name in any case');
   CheckEquals('C[SENDTOCLUSTER=hi There]', PartsOf('{sendtocluster=hi There}'),
               'the argument keeps its case and spaces');
   CheckEquals('U[ROVERCALL=X]', PartsOf('{ROVERCALL=X}'), 'a token takes no argument');
end;

procedure TMessageTextTests.Test_TheInactiveRadioMark;
begin
   BeginTest('Test_TheInactiveRadioMark');
   CheckEquals('C[^ASPEED+]', PartsOf('{$SPEED+}'), '$ is the Ctrl-A the old form carried');
   CheckEquals('C[^ASRS=PB1;]', PartsOf('{$srs=PB1;}'), 'with an argument');
   CheckEquals('U[$ROVERCALL]', PartsOf('{$ROVERCALL}'), 'a token has no inactive radio');
   CheckEquals('U[$]', PartsOf('{$}'), 'a mark alone names nothing');
end;

procedure TMessageTextTests.Test_LoneAndOddBraces;
begin
   BeginTest('Test_LoneAndOddBraces');
   CheckEquals('T[{ TU]', PartsOf('{ TU'), 'a { with no closing brace is the worked call');
   CheckEquals('T[{}]', PartsOf('{}'), 'empty braces: worked call, partial call');
   CheckEquals('T[{]U[X]T[}]', PartsOf('{{X}}'), '{{X}}: {, the word X, }');
   CheckEquals('T[TU {ROVERQT]', PartsOf('TU {ROVERQT'), 'no closing brace');
   CheckEquals('T[A{B]', PartsOf('A{B'), 'inside a word, unclosed');
   CheckEquals('U[A B]', PartsOf('{A B}'), 'any text but a brace is a body');
end;

procedure TMessageTextTests.Test_UnknownWords;
begin
   BeginTest('Test_UnknownWords');
   CheckEquals('U[NoSuchWord]', PartsOf('{NoSuchWord}'), 'unknown, as written');
   CheckEquals('NoSuchWord', string(FirstUnknownMessageWord('CQ {NoSuchWord} {BANDUP}')),
               'named as written');
   CheckEquals('', string(FirstUnknownMessageWord('CQ {ROVERCALL} {BANDUP} {$SPEED+} { \')),
               'nothing unknown');
end;

procedure TMessageTextTests.Test_OldBookendsAndTheirUpgrade;
var
   s, up: AnsiString;
   converted, leftAlone: integer;
begin
   BeginTest('Test_OldBookendsAndTheirUpgrade');
   CheckEquals('O[MM_GRABLASTCALL]', PartsOf(#3'MM_GRABLASTCALL'#4), 'the old form parses');
   CheckEquals('O[^ASRS=X]', PartsOf(#3#1'SRS=X'#4), 'and runs verbatim, Ctrl-A and all');

   up := UpgradeMessageBookends(#3'MM_GRABLASTCALL'#4, converted, leftAlone);
   CheckEquals('{MM_GRABLASTCALL}', string(up), 'converted');
   CheckEquals(1, converted, 'one converted');
   CheckEquals(0, leftAlone, 'none left');

   up := UpgradeMessageBookends('CQ '#3'SRS=PB1;'#4' {BANDUP} '#3#1'SRS=X'#4' '#3'SPEED+'#4 +
                                ' '#3'ALT-D'#4, converted, leftAlone);
   CheckEquals('CQ {SRS=PB1;} {BANDUP} {$SRS=X} {SPEED+} {ALT-D}', string(up),
               'both forms; Ctrl-A becomes $, SPEED+ and ALT-D convert too');
   CheckEquals(4, converted, 'four converted');
   CheckEquals(0, leftAlone, 'none left');

   up := UpgradeMessageBookends(#3'NOSUCHCOMMAND'#4, converted, leftAlone);
   CheckEquals(#3'NOSUCHCOMMAND'#4, string(up), 'an unknown name stays in the old form');
   CheckEquals(1, leftAlone, 'and is counted');

   up := UpgradeMessageBookends(#3'SENDTOCLUSTER=a}b'#4, converted, leftAlone);
   CheckEquals(#3'SENDTOCLUSTER=a}b'#4, string(up), 'a brace in the body cannot be braced');

   up := UpgradeMessageBookends('TU'#4' '#3'BANDUP', converted, leftAlone);
   CheckEquals('TU'#4' '#3'BANDUP', string(up), 'a lone Ctrl-D and an unclosed Ctrl-C untouched');
   CheckEquals(0, converted + leftAlone, 'not pairs');

   (* 255 bytes: byte for byte, the Ctrl-A included. *)
   s := StringOfChar(AnsiChar('A'), 255 - 19) + #3'BANDDOWN'#4 + #3#1'BANDUP'#4;
   CheckEquals(255, Length(s), 'a full memory');
   up := UpgradeMessageBookends(s, converted, leftAlone);
   CheckEquals(255, Length(up), 'still 255 after the conversion');
   CheckEquals('{BANDDOWN}{$BANDUP}', string(Copy(up, 237, 19)), 'and it is the brace form');
end;

procedure TMessageTextTests.Test_ChainPredicate;
begin
   BeginTest('Test_ChainPredicate');
   CheckTrue(MessageChainsOrCommands(#3'BANDUP'#4), 'an old command never flushed');
   CheckTrue(MessageChainsOrCommands('{MM_GRABLASTCALL}'), 'nor does its brace form');
   CheckTrue(MessageChainsOrCommands('{$SPEED+}'), 'nor an inactive-radio one');
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
   CheckEquals('{ALT-D}', string(MessagePickerText('ALT-D')), 'ALT-D');
   CheckEquals('#', string(MessagePickerText('#')), 'a cryptic character');
   CheckEquals('CTRL-P CTRL-F', string(MessagePickerText('CTRL-P CTRL-F')), 'a display row');
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
   Test_TheInactiveRadioMark;
   Test_LoneAndOddBraces;
   Test_UnknownWords;
   Test_OldBookendsAndTheirUpgrade;
   Test_ChainPredicate;
   Test_PickerText;
   Test_FoundCommandTakesOutCommandsAndUnknownWords;
end;

end.

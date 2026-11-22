unit uTestnetPass;
{$I ..\..\src\tr4w.inc}

(*
  THE nETWORK PASS WORDS (issue 71, nY4I 2026-11-22) -- unetPass, the pure
  decision, and the grammar's three new tokens (uMessageText). The glue that
  reads unet.StatusArray and paints the network window is not driven here: it
  copies the table into a TPassPeers and calls ExpandPassTokens.
*)

interface

uses
   SysUtils, Contnrs,
   uTR4WTestFramework, uMessageText, unetPass;

type
   TnetPassTests = class(TTestCase)
   protected
      procedure Test_Grammar;
      procedure Test_FrequencyText;
      procedure Test_PassByIdAndByname;
      procedure Test_PassByBand;
      procedure Test_RefusalsnameTheStation;
      procedure Test_ExpansionLeavesOtherTextAlone;
      procedure Test_LastPassedFrequency;
      procedure Test_ARefusedMessageIsnotPartlyExpanded;
   public
      procedure RunAllTests; override;
   end;

implementation

function Peers: TPassPeers;
begin
   SetLength(Result, 4);
   Result[3].Id := 'E';
   Result[3].name := 'QUIET';
   Result[3].FreqHz := 0;
   Result[0].Id := 'A';
   Result[0].name := 'RUn';
   Result[0].FreqHz := 14025400;
   Result[1].Id := 'B';
   Result[1].name := 'MULT';
   Result[1].FreqHz := 21025500;
   Result[2].Id := #0;
   Result[2].name := '';
   Result[2].FreqHz := 0;
end;

function KindOf(const aText: AnsiString): string;
var
   parts: TObjectList;
   p: TMessagePart;
begin
   Result := '';
   parts := TObjectList.Create(True);
   try
      ParseMessage(aText, parts);
      if parts.Count > 0 then
         begin
         p := TMessagePart(parts[0]);
         case p.Kind of
            mpToken:       Result := 'K[' + string(p.name) + '|' + string(p.Argument) + ']';
            mpUnknownWord: Result := 'U[' + string(p.Body) + ']';
            mpText:        Result := 'T[' + string(p.Text) + ']';
         else
            Result := '?';
         end;
         end;
   finally
      parts.Free;
   end;
end;

(* Expand aText as station C with the peers above; returns the expanded text,
  or 'REFUSED:<failure>:<missing id>' *)
function Run(const aText: AnsiString; var aLast: Int64): string;
var
   expanded, theWord: AnsiString;
   failure: TPassFailure;
   missing: AnsiChar;
   missingText: string;
begin
   if ExpandPassTokens(aText, Peers, 'C', aLast, expanded, failure, missing, theWord) then
      begin
      Result := string(expanded);
      end
   else
      begin
      missingText := '';
      if missing <> #0 then
         begin
         missingText := string(missing);
         end;
      Result := 'REFUSED:' + IntToStr(Ord(failure)) + ':' + missingText;
      end;
end;

function Runnew(const aText: AnsiString): string;
var
   last: Int64;
begin
   last := 0;
   Result := Run(aText, last);
end;

procedure TnetPassTests.Test_Grammar;
begin
   BeginTest('Test_Grammar');
   CheckEquals('K[PASS|B]', KindOf('{PASS B}'), 'a station');
   CheckEquals('K[PASS|14000]', KindOf('{pass 14000}'), 'a band, any case');
   CheckEquals('K[PASS|MULT STn]', KindOf('{PASS   MULT STn }'), 'trimmed, spaces inside kept');
   CheckEquals('K[LASTPASSEDFREQ|]', KindOf('{LastPassedFreq}'), 'LASTPASSEDFREQ');
   CheckEquals('U[PASS]', KindOf('{PASS}'), 'a bare PASS names nothing');
   CheckEquals('U[PASS ]', KindOf('{PASS }'), 'PASS and a blank names nothing');
   CheckEquals('U[PASSB]', KindOf('{PASSB}'), 'no space, no token');
   CheckEquals('', string(FirstUnknownMessageWord('PLS QSY {PASS B} {LASTPASSEDFREQ}')),
               'the save check accepts them');
   CheckEquals('PASS', string(FirstUnknownMessageWord('{PASS}')), 'and refuses a bare PASS');
end;

procedure TnetPassTests.Test_FrequencyText;
begin
   BeginTest('Test_FrequencyText');
   CheckEquals('14025', string(PassFrequencyText(14025400, False)), 'rounds down');
   CheckEquals('14026', string(PassFrequencyText(14025500, False)), 'rounds up at .5');
   CheckEquals('7000', string(PassFrequencyText(7000000, False)), 'whole');
   CheckEquals('14025R5', string(PassFrequencyText(14025500, True)), 'one decimal, R for the point');
   CheckEquals('14025', string(PassFrequencyText(14025000, True)), 'a zero decimal is dropped');
   CheckEquals('14025R4', string(PassFrequencyText(14025400, True)), 'tenths');
   CheckEquals('14026', string(PassFrequencyText(14025960, True)), 'rounds up into the next kHz');
end;

procedure TnetPassTests.Test_PassByIdAndByname;
begin
   BeginTest('Test_PassByIdAndByname');
   CheckEquals('PLS QSY 14025', Runnew('PLS QSY {PASS A}'), 'by id');
   CheckEquals('PLS QSY 21026', Runnew('PLS QSY {pass b}'), 'by id, any case');
   CheckEquals('PLS QSY 21026', Runnew('PLS QSY {PASS mult}'), 'by computer name, any case');
end;

procedure TnetPassTests.Test_PassByBand;
begin
   BeginTest('Test_PassByBand');
   CheckEquals('QSY 14025', Runnew('QSY {PASS 14000}'), 'the first station on 20m');
   CheckEquals('QSY 21026', Runnew('QSY {PASS 21000}'), 'and on 15m');
   CheckEquals('REFUSED:3:', Runnew('QSY {PASS 7000}'), 'nobody on 40m');
   CheckEquals('REFUSED:2:', Runnew('QSY {PASS 123}'), 'not a pass band');
end;

procedure TnetPassTests.Test_RefusalsnameTheStation;
begin
   BeginTest('Test_RefusalsnameTheStation');
   CheckEquals('REFUSED:5:', Runnew('{PASS C}'), 'C is this computer, not an absent station');
   CheckEquals('REFUSED:6:E', Runnew('{PASS E}'), 'on the network, no frequency reported');
   CheckEquals('REFUSED:6:E', Runnew('{PASS quiet}'), 'the same by name, and the id is still named');
   CheckEquals('REFUSED:2:', Runnew('{PASS 123}'), 'not a band');
end;

procedure TnetPassTests.Test_ExpansionLeavesOtherTextAlone;
begin
   BeginTest('Test_ExpansionLeavesOtherTextAlone');
   CheckEquals('CQ TEST \ # { } 599', Runnew('CQ TEST \ # { } 599'), 'no pass word: unchanged');
   CheckEquals('{ROVERQTH} 5nn @', Runnew('{ROVERQTH} 5nn @'), 'other tokens stay for the CW sender');
   CheckEquals('', Runnew(''), 'empty');
   CheckEquals('{PASS', Runnew('{PASS'), 'an unclosed brace is not a word');
end;

procedure TnetPassTests.Test_LastPassedFrequency;
var
   last: Int64;
begin
   BeginTest('Test_LastPassedFrequency');
   last := 0;
   CheckEquals('REFUSED:7:', Run('GO {LASTPASSEDFREQ}', last), 'nothing passed yet');
   CheckEquals('X 14025 Y', Run('X {PASS A} Y', last), 'a pass sets the memory');
   CheckTrue(last = 14025400, 'the memory holds the unrounded frequency');
   CheckEquals('GO 14025R4', Run('GO {LASTPASSEDFREQ}', last), 'one decimal, R for the point');
end;

procedure TnetPassTests.Test_ARefusedMessageIsnotPartlyExpanded;
var
   last: Int64;
begin
   BeginTest('Test_ARefusedMessageIsnotPartlyExpanded');
   last := 0;
   CheckEquals('REFUSED:4:Z', Run('QSY {PASS A} THEn {PASS Z}', last), 'the second word fails');
   CheckTrue(last = 0, 'a refused message passed nobody: the memory is untouched');
   CheckEquals('REFUSED:4:', Run('{PASS nosuch}', last), 'a name nobody has: no id to mark');
   CheckEquals('REFUSED:4:D', Run('{PASS D}', last), 'an id with no station');
   CheckEquals('{PASS }', Run('{PASS }', last), 'a PASS with nothing is not a pass word (FoundCommand refuses it)');
end;

procedure TnetPassTests.RunAllTests;
begin
   Test_Grammar;
   Test_FrequencyText;
   Test_PassByIdAndByname;
   Test_PassByBand;
   Test_RefusalsnameTheStation;
   Test_ExpansionLeavesOtherTextAlone;
   Test_LastPassedFrequency;
   Test_ARefusedMessageIsnotPartlyExpanded;
end;

end.

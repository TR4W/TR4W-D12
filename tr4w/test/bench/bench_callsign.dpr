program bench_callsign;

{ How long does validating a callsign actually take?

  NY4I asked the right question -- "we clearly run code to check callsigns very
  frequently, so I wonder if a regex is the best one to use" -- and it is a
  question with a number, not an opinion.

  Five measurements over the SAME corpus:

    1. GoodCallSyntax                  what TR4W does today: character tests.
    2. uRegex.RegexMatches             what TR4W's regex API does today, which
                                       CONSTRUCTS AND COMPILES TRegExpr on every
                                       single call.
    3. TRegExpr, compiled once, anchored     the fair regex number.
    4. TRegExpr, compiled once, unanchored   the pattern exactly as published.
    5. Hybrid: GoodCallSyntax first, regex only for what it accepts.

  It also reports AGREEMENT, because speed is only half the question: a
  validator that is fast and wrong is not a candidate.

  Usage:  bench_callsign <calls-file> <regex-file>
          one callsign per line; the regex file is one line.
}

{$MODE DELPHI}
{$H+}

uses
   SysUtils,
   Classes,
   Windows,
   RegExpr,
   uRegex,
   uCallSignRoutines;

const
   // Copied verbatim from LOGSTUFF.PAS:10534 -- the pattern TR4W uses today.
   RX_TREE = '^(?:\w{1,2}\d\/|\d\w\/|\w{1,2}\/)?\w+[0-9]+\w+\/?\w*\s*$';

var
   gFreq: Int64;

procedure StartClock(out aAt: Int64);
begin
   QueryPerformanceCounter(aAt);
end;

function StopClock(const aAt: Int64): double;   // milliseconds
var
   now_: Int64;
begin
   QueryPerformanceCounter(now_);
   Result := ((now_ - aAt) * 1000.0) / gFreq;
end;

procedure Report(const aName: string; const aMs: double; const aCount: integer;
                 const aAccepted: integer);
begin
   WriteLn(Format('%-46s %9.1f ms   %9.0f ns/call   accepted %d/%d (%.1f%%)',
                  [aName, aMs, (aMs * 1000000.0) / aCount, aAccepted, aCount,
                   (aAccepted * 100.0) / aCount]));
end;

var
   calls: TStringList;
   rxFile: TStringList;
   pattern, anchored: string;
   rxOnce, rxUnanchored, rxTree: TRegExpr;
   i, n, acc: integer;
   t0: Int64;
   ms: double;
   subset: integer;
   goodFlags: array of boolean;
   disagreeRegexNo, disagreeRegexYes: integer;
   sampleNo, sampleYes: string;

begin
   if ParamCount < 2 then
      begin
      WriteLn('usage: bench_callsign <calls-file> <regex-file>');
      Halt(2);
      end;

   QueryPerformanceFrequency(gFreq);

   calls := TStringList.Create;
   calls.LoadFromFile(ParamStr(1));
   n := calls.Count;

   rxFile := TStringList.Create;
   try
      rxFile.LoadFromFile(ParamStr(2));
      pattern := Trim(rxFile.Text);
   finally
      rxFile.Free;
   end;

   anchored := '^' + pattern + '$';

   WriteLn(Format('corpus: %d callsigns   pattern: %d bytes', [n, Length(pattern)]));
   WriteLn;

   SetLength(goodFlags, n);

   { 1. GoodCallSyntax -------------------------------------------------- }
   acc := 0;
   StartClock(t0);
   for i := 0 to n - 1 do
      begin
      goodFlags[i] := GoodCallSyntax(calls[i]);
      if goodFlags[i] then
         begin
         Inc(acc);
         end;
      end;
   ms := StopClock(t0);
   Report('1. GoodCallSyntax (character tests)', ms, n, acc);

   { 2. uRegex.RegexMatches -- compiles the pattern EVERY call.
        Deliberately run over a small subset: at this cost the full corpus
        would take many minutes, which is itself the finding. }
   subset := 2000;
   if subset > n then
      begin
      subset := n;
      end;
   acc := 0;
   StartClock(t0);
   for i := 0 to subset - 1 do
      begin
      if RegexMatches(anchored, calls[i]) then
         begin
         Inc(acc);
         end;
      end;
   ms := StopClock(t0);
   Report(Format('2. uRegex.RegexMatches (compiles per call, n=%d)', [subset]),
          ms, subset, acc);
   WriteLn(Format('   ... extrapolated to the full corpus: %.1f ms',
                  [ms * (n / subset)]));

   { 3. compiled once, anchored ----------------------------------------- }
   rxOnce := TRegExpr.Create;
   rxOnce.Expression := AnsiString(anchored);
   rxOnce.Compile;
   acc := 0;
   StartClock(t0);
   for i := 0 to n - 1 do
      begin
      if rxOnce.Exec(AnsiString(calls[i])) then
         begin
         Inc(acc);
         end;
      end;
   ms := StopClock(t0);
   Report('3. TRegExpr compiled ONCE, anchored', ms, n, acc);

   { 4. compiled once, exactly as published (unanchored) ----------------- }
   rxUnanchored := TRegExpr.Create;
   rxUnanchored.Expression := AnsiString(pattern);
   rxUnanchored.Compile;
   acc := 0;
   StartClock(t0);
   for i := 0 to n - 1 do
      begin
      if rxUnanchored.Exec(AnsiString(calls[i])) then
         begin
         Inc(acc);
         end;
      end;
   ms := StopClock(t0);
   Report('4. TRegExpr compiled ONCE, UNANCHORED (as published)', ms, n, acc);

   { 5. the hybrid NY4I proposed ---------------------------------------- }
   acc := 0;
   StartClock(t0);
   for i := 0 to n - 1 do
      begin
      if GoodCallSyntax(calls[i]) then
         begin
         if rxOnce.Exec(AnsiString(calls[i])) then
            begin
            Inc(acc);
            end;
         end;
      end;
   ms := StopClock(t0);
   Report('5. HYBRID: GoodCallSyntax then regex', ms, n, acc);

   { agreement ----------------------------------------------------------- }
   WriteLn;
   disagreeRegexNo := 0;
   disagreeRegexYes := 0;
   sampleNo := '';
   sampleYes := '';
   for i := 0 to n - 1 do
      begin
      if goodFlags[i] <> rxOnce.Exec(AnsiString(calls[i])) then
         begin
         if goodFlags[i] then
            begin
            Inc(disagreeRegexNo);
            if Length(sampleNo) < 60 then
               begin
               sampleNo := sampleNo + calls[i] + ' ';
               end;
            end
         else
            begin
            Inc(disagreeRegexYes);
            if Length(sampleYes) < 60 then
               begin
               sampleYes := sampleYes + calls[i] + ' ';
               end;
            end;
         end;
      end;

   // Which calls does the CHEAP test refuse? With a corpus of real, issued
   // callsigns every rejection is either a genuine oddity or a bug in the
   // rule, so they are worth naming rather than counting.
   WriteLn;
   WriteLn('GoodCallSyntax REJECTED these:');
   for i := 0 to n - 1 do
      begin
      if not goodFlags[i] then
         begin
         WriteLn('   <' + calls[i] + '>  length=' + IntToStr(Length(calls[i])));
         end;
      end;
   WriteLn;
   WriteLn(Format('AGREEMENT over %d real callsigns:', [n]));
   WriteLn(Format('   GoodCallSyntax says YES, regex says NO : %6d   e.g. %s',
                  [disagreeRegexNo, sampleNo]));
   WriteLn(Format('   GoodCallSyntax says NO,  regex says YES: %6d   e.g. %s',
                  [disagreeRegexYes, sampleYes]));

   { The tree's OWN callsign pattern, which is the swap actually on the table:
     does IsAGoodCall answer the same as RX_CALLSIGN? }
   rxTree := TRegExpr.Create;
   rxTree.Expression := AnsiString(RX_TREE);
   rxTree.Compile;
   acc := 0;
   StartClock(t0);
   for i := 0 to n - 1 do
      begin
      if rxTree.Exec(AnsiString(calls[i])) then
         begin
         Inc(acc);
         end;
      end;
   ms := StopClock(t0);
   Report('6. TR4W RX_CALLSIGN compiled once', ms, n, acc);

   disagreeRegexNo := 0;
   disagreeRegexYes := 0;
   sampleNo := '';
   sampleYes := '';
   for i := 0 to n - 1 do
      begin
      if goodFlags[i] <> rxTree.Exec(AnsiString(calls[i])) then
         begin
         if goodFlags[i] then
            begin
            Inc(disagreeRegexNo);
            if Length(sampleNo) < 70 then sampleNo := sampleNo + calls[i] + ' ';
            end
         else
            begin
            Inc(disagreeRegexYes);
            if Length(sampleYes) < 70 then sampleYes := sampleYes + calls[i] + ' ';
            end;
         end;
      end;
   WriteLn;
   WriteLn('GoodCallSyntax vs TR4W RX_CALLSIGN:');
   WriteLn(Format('   GoodCallSyntax YES, RX_CALLSIGN NO : %6d   e.g. %s', [disagreeRegexNo, sampleNo]));
   WriteLn(Format('   GoodCallSyntax NO,  RX_CALLSIGN YES: %6d   e.g. %s', [disagreeRegexYes, sampleYes]));
   rxTree.Free;

   rxOnce.Free;
   rxUnanchored.Free;
   calls.Free;
end.

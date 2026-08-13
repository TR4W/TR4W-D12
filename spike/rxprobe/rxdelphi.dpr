program rxdelphi;
{$APPTYPE CONSOLE}
uses
   SysUtils, Classes, PerlRegEx;

// Baseline capture: what the SHIPPING Delphi build answers for each of the five
// LOGSTUFF validators, over every callsign in calls.txt.  The FPC probe reads
// this file back and must agree line for line.
//
// The callsign pattern is emitted TWICE -- once with PCRE's possessive `?+` as
// LOGSTUFF has it today, once with a plain `?` -- because TRegExpr rejects the
// possessive form outright ("nested *?+"), so the port has to change it and the
// change has to be shown to be behaviour-preserving rather than argued to be.
const
   PGUID      = '^[{]?[0-9a-fA-F]{8}-?([0-9a-fA-F]{4}-?){3}[0-9a-fA-F]{12}[}]?$';
   PUSPFX     = '^[AaWaKkNn][a-zA-Z]?';
   PUSCALL    = '^[AaWaKkNn][a-zA-Z]?[0-9][a-zA-Z]{1,3}$';
   PCALLPOSS  = '^(?:\w{1,2}\d\/|\d\w\/|\w{1,2}\/)?+\w+[0-9]+\w+\/?\w*\s*$';
   PCALLPLAIN = '^(?:\w{1,2}\d\/|\d\w\/|\w{1,2}\/)?\w+[0-9]+\w+\/?\w*\s*$';
   PPARK      = '^([A-Za-z]{2})-(\d{4,5})$';

function M(rx: TPerlRegEx; const subj: string): char;
begin
   rx.Subject := UTF8Encode(subj);
   if rx.MatchAgain then
      begin
      Result := '1';
      end
   else
      begin
      Result := '0';
      end;
end;

var
   src, dst: TStringList;
   rGuid, rPfx, rCall, rPoss, rPlain, rPark: TPerlRegEx;
   i, diffs: integer;
   line: string;
begin
   src := TStringList.Create;
   dst := TStringList.Create;
   rGuid  := TPerlRegEx.Create;
   rPfx   := TPerlRegEx.Create;
   rCall  := TPerlRegEx.Create;
   rPoss  := TPerlRegEx.Create;
   rPlain := TPerlRegEx.Create;
   rPark  := TPerlRegEx.Create;
   try
      src.LoadFromFile('calls.txt');
      rGuid.RegEx  := PGUID;
      rPfx.RegEx   := PUSPFX;
      rCall.RegEx  := PUSCALL;
      rPoss.RegEx  := PCALLPOSS;
      rPlain.RegEx := PCALLPLAIN;
      rPark.RegEx  := PPARK;

      diffs := 0;
      for i := 0 to src.Count - 1 do
         begin
         line := M(rGuid, src[i]) + M(rPfx, src[i]) + M(rCall, src[i]) +
                 M(rPoss, src[i]) + M(rPlain, src[i]) + M(rPark, src[i]);
         if line[4] <> line[5] then
            begin
            Inc(diffs);
            WriteLn('POSSESSIVE DIFFERS: ', src[i], ' -> ', line[4], ' vs ', line[5]);
            end;
         dst.Add(src[i] + #9 + line);
         end;

      dst.SaveToFile('delphi-baseline.txt');
      WriteLn('subjects=', src.Count, '  possessive-vs-plain differences=', diffs);
   finally
      rPark.Free; rPlain.Free; rPoss.Free; rCall.Free; rPfx.Free; rGuid.Free;
      dst.Free; src.Free;
   end;
end.

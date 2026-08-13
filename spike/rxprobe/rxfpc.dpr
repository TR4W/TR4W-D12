program rxfpc;
{$MODE Delphi}
{$MODESWITCH UnicodeStrings}
uses SysUtils, Classes, RegExpr;

// Cross-engine check: does FPC's TRegExpr answer the SAME as the shipping
// Delphi/PCRE build for all five LOGSTUFF validators, over every real callsign
// in calls.txt?  Reads the baseline the Delphi probe wrote.
const
   PGUID      = '^[{]?[0-9a-fA-F]{8}-?([0-9a-fA-F]{4}-?){3}[0-9a-fA-F]{12}[}]?$';
   PUSPFX     = '^[AaWaKkNn][a-zA-Z]?';
   PUSCALL    = '^[AaWaKkNn][a-zA-Z]?[0-9][a-zA-Z]{1,3}$';
   PCALLPLAIN = '^(?:\w{1,2}\d\/|\d\w\/|\w{1,2}\/)?\w+[0-9]+\w+\/?\w*\s*$';
   PPARK      = '^([A-Za-z]{2})-(\d{4,5})$';

function M(rx: TRegExpr; const subj: string): char;
begin
   if rx.Exec(subj) then
      begin
      Result := '1';
      end
   else
      begin
      Result := '0';
      end;
end;

var
   base: TStringList;
   rGuid, rPfx, rCall, rPlain, rPark: TRegExpr;
   i, tab, diffs, shown: integer;
   subj, expect, got: string;
begin
   base := TStringList.Create;
   rGuid  := TRegExpr.Create;
   rPfx   := TRegExpr.Create;
   rCall  := TRegExpr.Create;
   rPlain := TRegExpr.Create;
   rPark  := TRegExpr.Create;
   try
      base.LoadFromFile('delphi-baseline.txt');
      rGuid.Expression  := PGUID;
      rPfx.Expression   := PUSPFX;
      rCall.Expression  := PUSCALL;
      rPlain.Expression := PCALLPLAIN;
      rPark.Expression  := PPARK;

      diffs := 0;
      shown := 0;
      for i := 0 to base.Count - 1 do
         begin
         tab := Pos(#9, base[i]);
         if tab = 0 then
            begin
            Continue;
            end;
         subj   := Copy(base[i], 1, tab - 1);
         // Delphi wrote guid,pfx,uscall,possessive,plain,park.  Compare against
         // the PLAIN callsign column -- the possessive one has already been
         // shown equal to it on this same data.
         expect := Copy(base[i], tab + 1, 3) + Copy(base[i], tab + 5, 2);
         got    := M(rGuid, subj) + M(rPfx, subj) + M(rCall, subj) +
                   M(rPlain, subj) + M(rPark, subj);
         if expect <> got then
            begin
            Inc(diffs);
            if shown < 20 then
               begin
               WriteLn('DIFF ', subj, '  delphi=', expect, '  fpc=', got);
               Inc(shown);
               end;
            end;
         end;

      WriteLn('subjects=', base.Count, '  cross-engine differences=', diffs);
   finally
      rPark.Free; rPlain.Free; rCall.Free; rPfx.Free; rGuid.Free; base.Free;
   end;
end.

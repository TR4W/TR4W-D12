program gp;
{$MODE Delphi}
{$MODESWITCH UnicodeStrings}
uses SysUtils, RegExpr;
function M(const pat, subj: string): string;
var r: TRegExpr;
begin
   r := TRegExpr.Create;
   try
      r.Expression := AnsiString(pat);
      if r.Exec(AnsiString(subj)) then Result := 'TRUE' else Result := 'false';
   except
      on E: Exception do Result := 'EXCEPTION: ' + E.Message;
   end;
   r.Free;
end;
const
   NESTED   = '^[{]?[0-9a-fA-F]{8}-?([0-9a-fA-F]{4}-?){3}[0-9a-fA-F]{12}[}]?$';
   EXPANDED = '^[{]?[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}[}]?$';
var
   subs: array[0..6] of string = (
      '6B29FC40-CA47-1067-B31D-00DD010662DA',
      '{6B29FC40-CA47-1067-B31D-00DD010662DA}',
      '6b29fc40ca471067b31d00dd010662da',
      '6B29FC40-CA47-1067-B31D-00DD010662D',
      'ZB29FC40-CA47-1067-B31D-00DD010662DA',
      'notaguid',
      '');
   i: integer;
begin
   for i := 0 to High(subs) do
      begin
      WriteLn('nested   [', subs[i], '] -> ', M(NESTED, subs[i]));
      WriteLn('expanded [', subs[i], '] -> ', M(EXPANDED, subs[i]));
      end;
end.

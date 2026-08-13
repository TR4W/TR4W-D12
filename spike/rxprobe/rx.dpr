program rx;
{$MODE Delphi}
{$MODESWITCH UnicodeStrings}
uses SysUtils, RegExpr;

function M(const pat, subj: string): boolean;
var r: TRegExpr;
begin
   r := TRegExpr.Create;
   try
      r.Expression := pat;
      Result := r.Exec(subj);
   finally
      r.Free;
   end;
end;

procedure T(const label_, pat, subj: string);
begin
   try
      WriteLn(label_, ' [', subj, '] -> ', M(pat, subj));
   except
      on E: Exception do WriteLn(label_, ' [', subj, '] -> EXCEPTION: ', E.Message);
   end;
end;

const
   PGUID = '^[{]?[0-9a-fA-F]{8}-?([0-9a-fA-F]{4}-?){3}[0-9a-fA-F]{12}[}]?$';
   PUSPFX = '^[AaWaKkNn][a-zA-Z]?';
   PUSCALL = '^[AaWaKkNn][a-zA-Z]?[0-9][a-zA-Z]{1,3}$';
   PCALLPOSS = '^(?:\w{1,2}\d\/|\d\w\/|\w{1,2}\/)?+\w+[0-9]+\w+\/?\w*\s*$';
   PCALLPLAIN = '^(?:\w{1,2}\d\/|\d\w\/|\w{1,2}\/)?\w+[0-9]+\w+\/?\w*\s*$';
   PPARK = '^([A-Za-z]{2})-(\d{4,5})$';
begin
   T('guid ', PGUID, '{6B29FC40-CA47-1067-B31D-00DD010662DA}');
   T('guid ', PGUID, 'notaguid');
   T('uspfx', PUSPFX, 'W1AW');
   T('uspfx', PUSPFX, 'DL1ABC');
   T('uscal', PUSCALL, 'W1AW');
   T('uscal', PUSCALL, 'DL1ABC');
   T('poss ', PCALLPOSS, 'W1AW');
   T('plain', PCALLPLAIN, 'W1AW');
   T('plain', PCALLPLAIN, 'W1/AB2CD');
   T('plain', PCALLPLAIN, 'DL1ABC');
   T('park ', PPARK, 'US-1234');
   T('park ', PPARK, '59');
end.

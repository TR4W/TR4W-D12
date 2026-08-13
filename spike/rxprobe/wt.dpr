program wt;
{$MODE Delphi}
{$MODESWITCH UnicodeStrings}
uses SysUtils, Classes, Windows;
type
   THolder = class
      procedure Dummy(var Msg: TMessage);
   end;
procedure THolder.Dummy(var Msg: TMessage);
begin
end;
var
   h: HWND;
   o: THolder;
begin
   o := THolder.Create;
   try
      WriteLn('calling AllocateHWnd...');
      h := Classes.AllocateHWnd(o.Dummy);
      WriteLn('AllocateHWnd -> ', h);
      if h <> 0 then
         begin
         WriteLn('SetTimer -> ', SetTimer(h, 1, 50, nil));
         Classes.DeallocateHWnd(h);
         WriteLn('DeallocateHWnd ok');
         end;
   except
      on E: Exception do WriteLn('EXCEPTION ', E.ClassName, ': ', E.Message);
   end;
   o.Free;
end.

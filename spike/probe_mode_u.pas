unit probe_mode_u;
{$MODE Delphi}
interface
function UnitCharSize: Integer;
implementation
function UnitCharSize: Integer;
begin
   Result := SizeOf(Char);
end;
end.

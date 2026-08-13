unit directives;

interface

implementation

procedure Demo;
begin
{$IFDEF DEBUG}
   if A then
      begin
      DebugOne;
      end;
{$ELSE}
   if A then
      begin
      ReleaseOne;
      end;
{$ENDIF}
   if B then
      begin
      Clean;
      end;

{$IFDEF WEIRD}
   if C then
      begin
{$ELSE}
   if C then
      begin
{$ENDIF}
      Body;
      end;
end;

end.

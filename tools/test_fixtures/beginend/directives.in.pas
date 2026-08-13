unit directives;

interface

implementation

procedure Demo;
begin
{$IFDEF DEBUG}
   if A then
      DebugOne;
{$ELSE}
   if A then
      ReleaseOne;
{$ENDIF}
   if B then
      Clean;

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

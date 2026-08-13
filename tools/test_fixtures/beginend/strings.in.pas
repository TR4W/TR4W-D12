unit strings;

interface

implementation

procedure Demo;
begin
   if A then
      Send('a { brace } and // a slash');
   if B then
      Send('it''s quoted' + #13#10);
   if C then
      Send('(* not a comment *)');
   if D then Send('{$IFDEF NOPE}');
end;

end.

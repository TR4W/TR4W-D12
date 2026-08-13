unit strings;

interface

implementation

procedure Demo;
begin
   if A then
      begin
      Send('a { brace } and // a slash');
      end;
   if B then
      begin
      Send('it''s quoted' + #13#10);
      end;
   if C then
      begin
      Send('(* not a comment *)');
      end;
   if D then
      begin
      Send('{$IFDEF NOPE}');
      end;
end;

end.

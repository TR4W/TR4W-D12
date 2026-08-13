unit reindent;

interface

implementation

procedure Demo;
begin
   if A then
   begin
      DoOne;
      DoTwo;
   end;

   if B then
      begin
         Nested;
         if C then
            begin
               Deeper;
            end;
      end
   else
      begin
         Other;
      end;
end;

end.

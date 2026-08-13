unit inline_begin;

interface

implementation

procedure Demo;
begin
   if A then begin
      DoOne;
   end;

   while B do begin
      DoTwo;
   end;

   if C then begin
      DoThree;
   end else begin
      DoFour;
   end;
end;

end.

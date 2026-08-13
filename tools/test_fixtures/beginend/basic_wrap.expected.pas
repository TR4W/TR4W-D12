unit basic_wrap;

interface

implementation

procedure Demo;
var
   i: integer;
begin
   if Ready then
      begin
      Fire;
      end;

   if Ready then
      begin
      LongCall(ArgOne,
               ArgTwo);
      end;

   for i := 0 to 9 do
      begin
      Process(i);
      end;

   while not Done do
      begin
      Step;
      end;

   with Rec do
      begin
      Value := 1;
      end;

   if A then
      begin
      Foo
      end
   else
      begin
      Bar;
      end;
end;

end.

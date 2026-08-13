unit basic_wrap;

interface

implementation

procedure Demo;
var
   i: integer;
begin
   if Ready then
      Fire;

   if Ready then
      LongCall(ArgOne,
               ArgTwo);

   for i := 0 to 9 do
      Process(i);

   while not Done do
      Step;

   with Rec do
      Value := 1;

   if A then
      Foo
   else
      Bar;
end;

end.

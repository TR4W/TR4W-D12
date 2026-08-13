unit comments;

interface

implementation

procedure Demo;
begin
   // if Ready then
   //    Fire;
   { if Ready then
        Fire; }
   (* if Ready then
         Fire; *)
   if Live then
      Fire;
   {
      begin
      end;
   }
   if Other then
      Go;
end;

end.

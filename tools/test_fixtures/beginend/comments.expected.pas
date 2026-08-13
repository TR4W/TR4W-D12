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
      begin
      Fire;
      end;
   {
      begin
      end;
   }
   if Other then
      begin
      Go;
      end;
end;

end.

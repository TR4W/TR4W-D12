unit case_try;

interface

type
   TRec = record
      A: integer;
      B: integer;
   end;

   TThing = class(TObject)
   private
      FX: integer;
   public
      procedure Go;
   end;

implementation

procedure TThing.Go;
var
   n: integer;
begin
   case n of
      0:
         Zero;
      1:
         if A then
            begin
            One;
            end;
      2..3:
         begin
            Two;
         end;
   else
      Many;
   end;

   try
      if A then
         begin
         Risky;
         end;
   finally
      if B then
         begin
         Cleanup;
         end;
   end;

   try
      Risky;
   except
      on E: Exception do
         begin
         Report(E);
         end;
   else
      Unknown;
   end;

   repeat
      if A then
         begin
         Once;
         end;
   until Done;
end;

end.

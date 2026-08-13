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
            One;
      2..3:
         begin
            Two;
         end;
   else
      Many;
   end;

   try
      if A then
         Risky;
   finally
      if B then
         Cleanup;
   end;

   try
      Risky;
   except
      on E: Exception do
         Report(E);
   else
      Unknown;
   end;

   repeat
      if A then
         Once;
   until Done;
end;

end.

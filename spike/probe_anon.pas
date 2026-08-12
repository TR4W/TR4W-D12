program probe_anon;
{$MODE DELPHI}
// STEP 2 of the FPC spike: does this FPC support anonymous methods?
// TR4W leans on them in 7 units -- uRadioRegistry's self-registration closures,
// TProcessMsgRef, uRotatorControl, uSettingsRegistry -- and they are the NEWEST
// code, so this single answer decides whether the spike is a formality or a
// redesign. Kept to ten lines so the answer is not buried in link errors.
type
   TIntProc = reference to procedure(v: integer);
var
   sink: integer;
   p: TIntProc;
begin
   sink := 0;
   p := procedure (v: integer)
        begin
           sink := sink + v;    // captures the VARIABLE, which is the property
        end;                    // uSettingsRegistry.Own depends on
   p(41);
   p(1);
   WriteLn('captured sum = ', sink);
end.

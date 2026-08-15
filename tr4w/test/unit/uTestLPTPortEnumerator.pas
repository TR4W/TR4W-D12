unit uTestLPTPortEnumerator;
{$I ..\..\src\tr4w.inc}
{
  The parallel-port enumerator.

  MOST OF THIS UNIT IS I/O -- QueryDosDevice and a registry key -- whose answer is
  a property of the machine, not of the code. A test asserting "no LPT ports"
  would pass here and fail on the one older PC NY4I digs out to try it, which is
  worse than no test.

  So these pin what is TRUE EVERYWHERE: the range guard, and self-consistency
  between the two entry points. The range guard is the one with teeth -- TR4W can
  only represent LPT1..LPT3 (PortType's Parallel1..Parallel3), and without it a
  caller passing 0 or 4 would have the enumerator probing for device names that
  cannot be stored even if they answered.
}

interface

uses
   SysUtils, uTR4WTestFramework, uLPTPortEnumerator;

type
   TLPTPortEnumeratorTests = class(TTestCase)
   protected
      procedure Test_OutOfRangeIsNotPresent;
      procedure Test_DescriptionAgreesWithPresence;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TLPTPortEnumeratorTests.Test_OutOfRangeIsNotPresent;
begin
   // TR4W stores this as Parallel1..Parallel3 and nothing else, so a port outside
   // that range is not "undetected", it is unrepresentable. Answering False keeps
   // the probe from asking about a device it could not record the answer for.
   BeginTest('only LPT1..LPT3 can be present');
   CheckFalse(LPTPortPresent(0),  'LPT0 is not a thing');
   CheckFalse(LPTPortPresent(4),  'LPT4 cannot be stored by TR4W');
   CheckFalse(LPTPortPresent(-1), 'a negative port is not present');
   CheckFalse(LPTPortPresent(99), 'a wild number is not present');
end;

procedure TLPTPortEnumeratorTests.Test_DescriptionAgreesWithPresence;
var
   i: integer;
   desc: string;
begin
   // Environment-independent: whatever this machine has, the summary must name
   // exactly the ports the per-port call reports. A machine with none gives an
   // empty string and still satisfies this.
   BeginTest('the summary names exactly the ports reported present');
   desc := PresentLPTPortsDescription;
   for i := 1 to 3 do
      begin
      if LPTPortPresent(i) then
         begin
         CheckTrue(Pos('LPT' + IntToStr(i), desc) > 0,
                   Format('LPT%d is present but missing from "%s"', [i, desc]));
         end
      else
         begin
         CheckFalse(Pos('LPT' + IntToStr(i), desc) > 0,
                    Format('LPT%d is absent but named in "%s"', [i, desc]));
         end;
      end;
end;

procedure TLPTPortEnumeratorTests.RunAllTests;
begin
   Test_OutOfRangeIsNotPresent;
   Test_DescriptionAgreesWithPresence;
end;

end.

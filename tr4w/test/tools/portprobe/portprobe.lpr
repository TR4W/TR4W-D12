program portprobe;
{$MODE DELPHI}
{$APPTYPE CONSOLE}

(* WHAT DOES TR4W ACTUALLY SEE ON THIS MACHINE'S SERIAL PORTS?

    portprobe

  Prints every port TComPortEnumerator reports, with each field that decides
  how the port is shown and whether it can be chosen. Exits 0 always: this
  asks a question, it does not assert an answer.

  WHY IT EXISTS. The enumerator's own unit test is deliberately
  ENVIRONMENT-INDEPENDENT -- Test_LiveListIsSelfConsistent checks that the two
  entry points agree and that Addressable means what it says, and its comment
  records that "a machine with no serial port satisfies all of it". That is
  the right property for a test that must pass in CI, and it is exactly why
  the suite cannot answer "how does TR4W see the adapter you just plugged in".
  It passes identically with the adapter and without it.

  So the suite proves the enumerator is self-consistent, and this proves what
  it found. Different questions, and the second one needs real hardware.

  NO `Interfaces`, DELIBERATELY. VC reaches the LCL for LCLType -- a TYPE
  unit, declaring HWND/HFONT/TLogFont for every widget set -- not for a
  widget set itself. Adding Interfaces would link gtk2 and make this need a
  display (the unit-test binary does, which is why it runs under xvfb-run).
  A port probe that cannot run on a headless build host would be useless on
  the one machine most likely to need it.

  IT IS A SEPARATE PROGRAM rather than a probe inside tr4w_platformcheck,
  because that program is deliberately free of this tree: it links only
  uProbeReport and uPlatformProbes and its build script passes no -Fu at all.
  It asks the PLATFORM questions. This one asks a TR4W question and needs
  TR4W's units to do it. Folding it in would give platformcheck a dependency
  on src/ that it has been kept clean of -- a decision worth making on its own
  merits, not as a side effect of wanting one answer today. *)

uses
   SysUtils,
   ComPortEnumerator;

function YesNo(aValue: boolean): string;
begin
   if aValue then
      begin
      Result := 'yes';
      end
   else
      begin
      Result := 'no';
      end;
end;

(* Empty is a real answer and has to look like one: a blank column reads as a
  bug in the probe rather than as "the platform did not say". *)
function OrNone(const aValue: string): string;
begin
   if Trim(aValue) = '' then
      begin
      Result := '(none)';
      end
   else
      begin
      Result := aValue;
      end;
end;

var
   enumerator: TComPortEnumerator;
   info: TComPortInfo;
   i: integer;

begin
   WriteLn('portprobe -- what TComPortEnumerator reports on this machine');
   WriteLn('target: ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
   WriteLn;

   (* THE CONSTANT FIRST, because an empty list means two different things and
     only this tells them apart: "this platform has no enumerator" versus
     "this platform has an enumerator and there are no ports". The enumerator
     unit exists to make that distinction rather than silently returning
     nothing, so a probe that did not print it would hide the very thing it
     was written to show. *)
   WriteLn('enumeration supported on this platform: ',
           YesNo(ComPortEnumerationSupported));
   WriteLn('highest COM number TR4W can store:      ', MAX_ADDRESSABLE_COM_PORT);
   WriteLn;

   enumerator := TComPortEnumerator.Create;
   try
      enumerator.Refresh;

      WriteLn('ports found: ', enumerator.Count);
      WriteLn;

      for i := 0 to enumerator.Count - 1 do
         begin
         info := enumerator.Ports[i];
         WriteLn('[', i, ']');
         WriteLn('  PortName     : ', OrNone(info.PortName));
         WriteLn('  PortNumber   : ', info.PortNumber,
                 '   (0 = the name carries no COM number)');
         WriteLn('  FriendlyName : ', OrNone(info.FriendlyName));
         WriteLn('  DeviceDesc   : ', OrNone(info.DeviceDesc));
         WriteLn('  InstanceID   : ', OrNone(info.InstanceID));
         WriteLn('  Addressable  : ', YesNo(info.Addressable),
                 '   (can TR4W''s config vocabulary name it?)');
         WriteLn('  Present      : ', YesNo(info.Present));
         WriteLn('  Describe     : ', OrNone(info.Describe));
         WriteLn;
         end;

      if enumerator.Count = 0 then
         begin
         if ComPortEnumerationSupported then
            begin
            WriteLn('No ports. On a platform WITH an enumerator that means no');
            WriteLn('hardware is fitted, not that the list is unavailable.');
            end
         else
            begin
            WriteLn('No ports, and none can be reported: this platform has no');
            WriteLn('enumeration arm. That is the correct answer, not a failure.');
            end;
         end;
   finally
      enumerator.Free;
   end;
end.

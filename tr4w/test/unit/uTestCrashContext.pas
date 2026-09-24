unit uTestCrashContext;

(* THE CRASH-REPORT CONTEXT HOOK.

  uCrashLog gained a registration point so a subsystem can add what it knows
  to a crash record without uCrashLog ever naming that subsystem -- the arrow
  has to point this way because uCrashLog links into tr4wserver, which has no
  LCL, no DX cluster and no radios.

  THE PART THAT NEEDS A TEST IS NOT THE REGISTRATION, IT IS THE PROMISE THAT
  A DUMPER CANNOT MAKE A CRASH WORSE. These run while the program is already
  dying. A dumper that raises must cost its own section and nothing else; if
  it could escape, a diagnostic would destroy the report it exists to produce,
  and that failure is invisible until the one crash somebody needed.
*)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCrashContextTests = class(TTestCase)
   protected
      procedure TestARegisteredDumperIsCalled;
      procedure TestTheWriterReachesTheDumper;
      procedure TestARaisingDumperDoesNotEscape;
      procedure TestARaisingDumperDoesNotStopTheNextOne;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uCrashLog;

var
   GCalledA: integer = 0;
   GCalledB: integer = 0;
   GLinesA: integer = 0;

procedure DumperA(aWrite: TCrashContextWriter);
begin
   Inc(GCalledA);
   aWrite('a line from A');
   aWrite('and another');
   Inc(GLinesA, 2);
end;

procedure DumperRaises(aWrite: TCrashContextWriter);
begin
   raise Exception.Create('a dumper that is itself broken');
end;

procedure DumperB(aWrite: TCrashContextWriter);
begin
   Inc(GCalledB);
   aWrite('a line from B');
end;

procedure TCrashContextTests.TestARegisteredDumperIsCalled;
begin
   BeginTest('TestARegisteredDumperIsCalled');
   GCalledA := 0;
   RegisterCrashContext('test A', @DumperA);
   WriteCrashContext('unit test');
   CheckTrue(GCalledA > 0, 'the registered dumper ran');
end;

procedure TCrashContextTests.TestTheWriterReachesTheDumper;
begin
   (* The writer is a procedure POINTER handed across a unit boundary. If it
     arrived nil, the dumper would fault on its first line -- and because
     WriteCrashContext swallows that, the section would simply be missing
     with nothing to say so. *)
   BeginTest('TestTheWriterReachesTheDumper');
   GLinesA := 0;
   WriteCrashContext('unit test');
   CheckEquals(2, GLinesA, 'both lines were written through the writer');
end;

procedure TCrashContextTests.TestARaisingDumperDoesNotEscape;
begin
   BeginTest('TestARaisingDumperDoesNotEscape');
   RegisterCrashContext('test raises', @DumperRaises);
   try
      WriteCrashContext('unit test');
      Check(True, 'a raising dumper did not propagate');
   except
      on E: Exception do
         begin
         Check(False, 'a dumper exception escaped: ' + E.Message);
         end;
   end;
end;

procedure TCrashContextTests.TestARaisingDumperDoesNotStopTheNextOne;
begin
   (* ONE TRY PER DUMPER, not one around the loop. With a single try the first
     broken subsystem would silently delete every section after it, and the
     sections are ordered by registration -- which is unit initialisation
     order, i.e. arbitrary. *)
   BeginTest('TestARaisingDumperDoesNotStopTheNextOne');
   RegisterCrashContext('test B', @DumperB);
   GCalledB := 0;
   WriteCrashContext('unit test');
   CheckTrue(GCalledB > 0, 'the dumper after the broken one still ran');
end;

procedure TCrashContextTests.RunAllTests;
begin
   TestARegisteredDumperIsCalled;
   TestTheWriterReachesTheDumper;
   TestARaisingDumperDoesNotEscape;
   TestARaisingDumperDoesNotStopTheNextOne;
end;

end.

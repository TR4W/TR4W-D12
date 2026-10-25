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
      procedure TestSetupLinesCarryTheSetupTag;
      procedure TestAContextSectionCarriesTheCrashTag;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, Log4D, uCrashLog;

type
   (* Holds every line the crash logger writes while a test has it attached.
     The lines go to GCaptured, a test-owned list, because the appender is an
     interface and the logger frees it when it is removed. *)
   TCaptureAppender = class(TLogCustomAppender)
   protected
      procedure DoAppend(const aMessage: string); override;
   end;

var
   GCaptured: TStringList = nil;

procedure TCaptureAppender.DoAppend(const aMessage: string);
begin
   (* The appender also receives the layout's header and footer, which are
     empty for the simple layout; only real lines are kept. *)
   if (GCaptured <> nil) and
      (Trim(aMessage) <> '') then
      begin
      GCaptured.Add(aMessage);
      end;
end;

(* Run aProc with a capture appender on the crash logger, and return what it
  wrote. The level is set exactly as InstallCrashLog sets it, so this does not
  depend on whether another suite has installed the reporter first. *)
type
   TCapturedProc = procedure;

procedure Capture(aProc: TCapturedProc);
var
   crashLogger: TLogLogger;
   appender: ILogAppender;
begin
   crashLogger := TLogLogger.GetLogger('TR4WDebugLog.CrashLog');
   crashLogger.Level := All;
   GCaptured.Clear;
   appender := TCaptureAppender.Create('unit-test capture');
   crashLogger.AddAppender(appender);
   try
      aProc;
   finally
      crashLogger.RemoveAppender(appender);
   end;
end;

procedure WriteSymbolState;
begin
   ReportSymbolState;
end;

procedure WriteAContext;
begin
   WriteCrashContext('unit test');
end;

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

procedure TCrashContextTests.TestSetupLinesCarryTheSetupTag;
var
   i: integer;
begin
   (* THE SETUP LINES ARE NOT CRASHES. They are written on every ordinary
     start, and while they said '[CRASH]' a search for that tag could not
     tell a crash from a start -- and an operator reading tr4w.log took them
     for an alarm (NY4I, 2026-10-25). ReportSymbolState is the bulk of them
     and is the one a test can call on its own. *)
   BeginTest('TestSetupLinesCarryTheSetupTag');
   Capture(@WriteSymbolState);
   CheckTrue(GCaptured.Count > 0, 'the symbol state wrote something');
   for i := 0 to GCaptured.Count - 1 do
      begin
      CheckTrue(Pos(CRASH_SETUP_TAG, GCaptured[i]) > 0,
                'a setup line carries ' + CRASH_SETUP_TAG + ': ' + GCaptured[i]);
      CheckTrue(Pos('[CRASH]', GCaptured[i]) = 0,
                'a setup line does not say [CRASH]: ' + GCaptured[i]);
      end;
end;

procedure TCrashContextTests.TestAContextSectionCarriesTheCrashTag;
var
   i: integer;
begin
   (* THE OTHER DIRECTION. A context section is written with a crash report,
     so it keeps '[CRASH]' -- relabelling it with the setup lines would hide
     the part of a report that explains it from the search that finds it. *)
   BeginTest('TestAContextSectionCarriesTheCrashTag');
   // DumperA was registered by TestARegisteredDumperIsCalled, which runs first.
   Capture(@WriteAContext);
   CheckTrue(GCaptured.Count > 0, 'the context sections wrote something');
   for i := 0 to GCaptured.Count - 1 do
      begin
      CheckTrue(Pos('[CRASH]', GCaptured[i]) > 0,
                'a context line carries [CRASH]: ' + GCaptured[i]);
      CheckTrue(Pos(CRASH_SETUP_TAG, GCaptured[i]) = 0,
                'a context line does not carry the setup tag: ' + GCaptured[i]);
      end;
end;

procedure TCrashContextTests.RunAllTests;
begin
   TestARegisteredDumperIsCalled;
   TestTheWriterReachesTheDumper;
   TestARaisingDumperDoesNotEscape;
   TestARaisingDumperDoesNotStopTheNextOne;

   GCaptured := TStringList.Create;
   try
      TestSetupLinesCarryTheSetupTag;
      TestAContextSectionCarriesTheCrashTag;
   finally
      FreeAndNil(GCaptured);
   end;
end;

end.

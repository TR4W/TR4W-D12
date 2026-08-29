unit uCrashLogLCL;
{$I ..\..\tr4w.inc}
{
  THE LCL HALF OF THE CRASH REPORTER.

  Two statements live here and nowhere else: Application.OnException, which
  installs the hook, and Application.ShowException, which is what the hook hands
  on to. They are the only part of crash reporting that needs a widget set.

  WHY THEY ARE NOT IN uCrashLog. TF references uCrashLog so that a fault on a
  worker thread is not silent, and tr4wserver references TF. So while these two
  statements sat in uCrashLog, the chain

      tr4wserver.dpr -> tr4wserverUnit -> TF -> uCrashLog -> Forms

  dragged the LCL into a console program whose unit search path deliberately
  excludes it. The server stopped linking on 2026-08-23 and nothing noticed for
  three days: that search path is the only guard on the boundary, and it fires
  only when someone runs a full build.

  It had an IFDEF FPC around it -- spelled without its braces here, because a
  directive written inside a brace comment closes the comment -- which could
  not have helped. That asks which
  COMPILER, and the question is which PROGRAM -- both are FPC, only one has
  Forms. No conditional can answer that; only the unit graph can. Hence a
  second unit rather than a smarter define.

  WHAT THE LCL HOOK IS FOR, kept from the original note because it is the reason
  one hook is not enough: the LCL CATCHES exceptions raised inside its own
  control and event-handler code and shows its own dialog, so a fault in the
  Preferences form never reaches ExceptProc at all. Without this hook, exactly
  the parts of the program being rewritten right now would be the parts that
  crashed without a trace.
}

interface

{ Installs BOTH hooks: calls uCrashLog.InstallCrashLog for the RTL one, then
  adds the LCL one. Call this instead of InstallCrashLog from any program that
  has a widget set -- one call site, and no way to end up with a GUI program
  that quietly has only half its crash reporting.

  Idempotent, like the RTL half. }
procedure InstallCrashLogLCL;

implementation

uses
   SysUtils,
   Forms,        // Application.OnException / ShowException -- the whole point
   Log4D,
   uCrashLog;

type
   { A class only because Application.OnException is a method pointer. It holds
     no state. }
   TLCLCrashReporter = class(TObject)
   public
      procedure HandleException(Sender: TObject; E: Exception);
   end;

var
   GReporter: TLCLCrashReporter = nil;

procedure TLCLCrashReporter.HandleException(Sender: TObject; E: Exception);
begin
   // ExceptAddr/ExceptFrames rather than the exception object alone: the LCL
   // hands over only E, and an exception without a location is barely more
   // useful than "it crashed".
   WriteCrashReport('LCL', E, ExceptAddr, ExceptFrameCount, ExceptFrames);

   // Then the LCL's own dialog, unchanged.  Suppressing it would hide from the
   // operator a fault we have only written to a file they have not been asked
   // to look at.
   Application.ShowException(E);
end;

procedure InstallCrashLogLCL;
begin
   InstallCrashLog;

   if GReporter <> nil then
      begin
      Exit;
      end;

   GReporter := TLCLCrashReporter.Create;
   // NO @ on the method reference: tr4w.inc compiles every unit in
   // {$MODE Delphi}, where a method is assigned directly. The ObjFPC spelling
   // with @, which the FreePascal wiki example uses, does not compile here.
   Application.OnException := GReporter.HandleException;

   TLogLogger.GetLogger('TR4WDebugLog.CrashLog').Info(
      '[CRASH] LCL exception handler installed');
end;

finalization
   FreeAndNil(GReporter);

end.

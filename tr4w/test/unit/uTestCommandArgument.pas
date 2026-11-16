unit uTestCommandArgument;
{$I ..\..\src\tr4w.inc}

(*
  A FUNCTION-KEY COMMAND'S ARGUMENT BELONGS TO THAT COMMAND ONLY (issue 192).

  uProcessCommand.FoundCommand hands a command's '=' argument to its handler
  through the unit variable scFileName, and used to assign it only when the
  command carried '='.  So a bare SPAN (or SRS, WINEXEC, OTRSP) ran with the
  PREVIOUS command's argument.

  The commands used here match no row in the dispatch table, so no handler
  runs and nothing touches a radio, a file or the screen: what is pinned is
  the argument FoundCommand leaves for the handler it would have called.
*)

interface

uses
   SysUtils,
   uTR4WTestFramework, VC, uProcessCommand;

type
   TCommandArgumentTests = class(TTestCase)
   protected
      procedure Test_BareCommandAfterOneWithAnArgument_HasNoArgument;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   (* Not a command: the dispatch table has no such row. *)
   NO_SUCH_COMMAND = 'ZZNOSUCHCOMMANDFORTEST';

procedure TCommandArgumentTests.Test_BareCommandAfterOneWithAnArgument_HasNoArgument;
var
   s: Str160;
begin
   BeginTest('Test_BareCommandAfterOneWithAnArgument_HasNoArgument');

   s := ControlC + NO_SUCH_COMMAND + '=abc' + ControlD;
   CheckTrue(FoundCommand(s), 'a bracketed command is found');
   CheckEquals('abc', string(scFileName), 'the argument after = reaches the handler');

   s := ControlC + NO_SUCH_COMMAND + ControlD;
   CheckTrue(FoundCommand(s), 'the same command, bare');
   CheckEquals('', string(scFileName), 'a bare command has no argument -- not the last one');
end;

procedure TCommandArgumentTests.RunAllTests;
begin
   Test_BareCommandAfterOneWithAnArgument_HasNoArgument;
end;

end.

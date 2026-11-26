unit uTestServerLogHealth;
{$I ..\..\src\tr4w.inc}

(*
   THE SERVER LOG'S HEALTH (issue 314, review H9): the texts the stations and
   the window get when the log cannot be written. The server unit is not linked
   into this binary; the leaf it calls is, and carries every decision.

   The torn-tail repair of SERVERLOG.TRW and its four tests were deleted with
   the routines (issue 386, batch B): nothing called them since the server's
   log became a SQLite store.
*)

interface

uses
   SysUtils,
   uTR4WTestFramework;

type
   TServerLogHealthTests = class(TTestCase)
   private
      procedure Test_TheNoticesFitAnIntercomLine;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uServerLogHealth;

procedure TServerLogHealthTests.Test_TheNoticesFitAnIntercomLine;
var
   longReason: string;
begin
   BeginTest('Test_TheNoticesFitAnIntercomLine');
   longReason := StringOfChar('x', 400);
   CheckTrue(Length(ServerLogFailureNotice(longReason)) <= SERVER_NOTICE_MAX,
      'a long OS reason is clipped, not the notice');
   CheckTrue(Pos('NOT stored', ServerLogFailureNotice('Disk Full')) > 0, 'says the QSO is not stored');
   CheckTrue(Pos('relayed', ServerLogFailureNotice('Disk Full')) > 0, 'says the QSO is still relayed');
   CheckTrue(Pos('Disk Full', ServerLogFailureNotice('Disk Full')) > 0, 'names the reason');
   CheckTrue(Length(ServerLogRecoveredNotice) <= SERVER_NOTICE_MAX, 'recovery notice fits');
   CheckEquals('', ServerLogProblemText(0, 'x'), 'no failures, no text');
   CheckTrue(Pos('3', ServerLogProblemText(3, 'Disk Full')) > 0, 'the count is shown');
end;

procedure TServerLogHealthTests.RunAllTests;
begin
   Test_TheNoticesFitAnIntercomLine;
end;

end.

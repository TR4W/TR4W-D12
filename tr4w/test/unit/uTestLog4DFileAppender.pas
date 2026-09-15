unit uTestLog4DFileAppender;
{$I ..\..\src\tr4w.inc}

(* LOG4D'S FILE APPENDER MUST NOT TAKE THE PROGRAM DOWN BECAUSE IT COULD NOT
  OPEN ITS FILE.

  It used to. TFileStream.Create raised out of the appender's constructor, and
  uProgramMain creates the appender before the crash handler is installed, so
  a log file TR4W could not open ended the process with an exit code and
  nothing else. The same open ran again at every rollover, from inside
  whichever log call crossed the size limit, on whatever thread made it.

  An unopenable path is made the same way on every platform by putting the log
  UNDER A FILE: <file>/sub/x.log cannot be created, because its parent is not a
  directory. Deleting that file makes the very same path usable, which is what
  the reopen test needs.

  EVERY APPENDER HERE GETS A LAYOUT. Without one, Log4D refuses the event
  before it reaches the file code at all (RequiresLayout), so a log call would
  pass these tests without ever touching the path under test. *)

interface

uses
   uTR4WTestFramework;

type
   TLog4DFileAppenderTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      FBlocker: string;

      (* A log path that cannot be opened while FBlocker exists. *)
      function BlockedLogPath: string;
      procedure RemoveBlocker;

      procedure Test_UnopenablePathDoesNotRaise;
      procedure Test_LoggingWithNoFileDoesNotRaise;
      procedure Test_ReopensOnceThePathIsUsable;
   end;

implementation

uses
   Classes,
   SysUtils,
   Log4D;

function TLog4DFileAppenderTests.BlockedLogPath: string;
var
   f: TFileStream;
begin
   FBlocker := IncludeTrailingPathDelimiter(GetTempDir(False))
               + 'tr4w-log4d-blocker-' + IntToStr(GetProcessID);
   f := TFileStream.Create(FBlocker, fmCreate);
   f.Free;
   Result := FBlocker + PathDelim + 'sub' + PathDelim + 'x.log';
end;

procedure TLog4DFileAppenderTests.RemoveBlocker;
begin
   if FileExists(FBlocker) then
      begin
      DeleteFile(FBlocker);
      end
   else
      begin
      (* The reopen test turned it into a directory holding the log. *)
      DeleteFile(FBlocker + PathDelim + 'sub' + PathDelim + 'x.log');
      RemoveDir(FBlocker + PathDelim + 'sub');
      RemoveDir(FBlocker);
      end;
end;

procedure TLog4DFileAppenderTests.Test_UnopenablePathDoesNotRaise;
var
   path:     string;
   appender: TLogFileAppender;
   keep:     ILogAppender;
begin
   path := BlockedLogPath;
   try
      try
         appender := TLogRollingFileAppender.Create('blocked', path);
         keep := appender;
      except
         on E: Exception do
            begin
            Check(False, 'creating the appender raised ' + E.ClassName + ': ' + E.Message);
            Exit;
            end;
      end;
      CheckTrue(appender.OpenError <> '', 'the reason the file could not be opened is recorded');
      CheckEquals(path, appender.FileName, 'the appender still names the file it wants');
   finally
      keep := nil;
      RemoveBlocker;
   end;
end;

procedure TLog4DFileAppenderTests.Test_LoggingWithNoFileDoesNotRaise;
var
   appender: TLogFileAppender;
   keep:     ILogAppender;
   lg:       TLogLogger;
begin
   appender := TLogRollingFileAppender.Create('blocked', BlockedLogPath);
   keep := appender;
   appender.Layout := TLogSimpleLayout.Create;
   lg := TLogLogger.GetLogger('Log4DFileAppenderTests.NoFile');
   try
      lg.Additive := False;
      lg.Level := All;
      lg.AddAppender(keep);
      try
         lg.Info('a line with nowhere to go');
         lg.Info('and a second, after the retry interval has not passed');
         Check(True);
      except
         on E: Exception do
            begin
            Check(False, 'logging with no file raised ' + E.ClassName + ': ' + E.Message);
            end;
      end;
      CheckTrue(appender.OpenError <> '', 'still recorded as unopened');
   finally
      lg.RemoveAllAppenders;
      keep := nil;
      RemoveBlocker;
   end;
end;

procedure TLog4DFileAppenderTests.Test_ReopensOnceThePathIsUsable;
var
   appender: TLogFileAppender;
   keep:     ILogAppender;
   lg:       TLogLogger;
   path:     string;
begin
   path := BlockedLogPath;
   appender := TLogRollingFileAppender.Create('blocked', path);
   keep := appender;
   appender.Layout := TLogSimpleLayout.Create;
   appender.ReopenInterval := 0;
   lg := TLogLogger.GetLogger('Log4DFileAppenderTests.Reopen');
   try
      lg.Additive := False;
      lg.Level := All;
      lg.AddAppender(keep);
      CheckTrue(appender.OpenError <> '', 'unopenable while the blocker exists');

      DeleteFile(FBlocker);
      CheckFalse(FileExists(FBlocker), 'the blocker is gone');
      lg.Info('the first line once the path is usable');

      CheckEquals('', appender.OpenError, 'the next log call reopened the file');
      CheckTrue(FileExists(path), 'and the file now exists');
   finally
      lg.RemoveAllAppenders;
      keep := nil;
      RemoveBlocker;
   end;
end;

procedure TLog4DFileAppenderTests.RunAllTests;
begin
   Test_UnopenablePathDoesNotRaise;
   Test_LoggingWithNoFileDoesNotRaise;
   Test_ReopensOnceThePathIsUsable;
end;

end.

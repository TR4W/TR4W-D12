unit uLogConfig;
{$I tr4w.inc}

{ Centralizes the TR4W Log4D layout so every appender renders identical
  timestamps.  The %d token is the event's UTC time formatted by uLogTime
  ("2026-11-23 02:58:27.466Z"); Log4D ignores the dateFormat option, so there is
  no per-appender format to set and none that can drift. }

interface

uses
   Log4D;

{ Builds the standard TR4W pattern layout (date + TTCC).  Use everywhere an
  appender is created.

  Returns ILogLayout (not the concrete class) on purpose: Log4D layouts are
  reference-counted TInterfacedObjects, so an interface reference must be
  anchored (via Result) BEFORE the "as ILogOptionHandler" cast -- otherwise
  that temporary interface would be the object's first/only reference and
  would free the layout when the statement ends, leaving a dangling layout. }
function CreateTR4WLogLayout: ILogLayout;

implementation

function CreateTR4WLogLayout: ILogLayout;
begin
   // Result (ILogLayout) takes the first reference here: refcount 0 -> 1.
   Result := TLogPatternLayout.Create('%d ' + TTCCPattern);
end;

end.

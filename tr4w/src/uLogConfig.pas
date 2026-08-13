unit uLogConfig;
{$I tr4w.inc}

{ Centralizes the TR4W Log4D layout so every appender renders identical
  timestamps.  D12's Log4D fork defaults the %d token to ShortDateFormat
  (date only); this restores the full D7-style "dd mmm yyyy hh:nn:ss.zzz"
  timestamp in one place instead of being repeated at each appender site. }

interface

uses
   Log4D;

const
   TR4W_LOG_DATEFORMAT = 'dd mmm yyyy hh:nn:ss.zzz';

{ Builds the standard TR4W pattern layout (date + TTCC) with the full
  timestamp date format applied.  Use everywhere an appender is created.

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
   // %d renders via the layout's dateFormat option; override the D12 default.
   // The temporary interface from "as" is now the 2nd reference, so releasing
   // it at end of statement leaves the layout alive (held by Result).
   (Result as ILogOptionHandler).SetOption('dateFormat', TR4W_LOG_DATEFORMAT);
end;

end.

unit uCallbookFactory;
{$I tr4w.inc}

(* THE ASYNCHRONOUS ENTRY POINT TO THE CALLBOOK (issue 321).

   The thread pattern is DownloadCTYAsync's (uCTYUpdate): the work runs in
   Execute, the result is stored on the thread object, and TThread.OnTerminate --
   which the RTL raises through Synchronize -- hands it to the caller ON THE MAIN
   THREAD, with no posted message and no window handle. *)

interface

uses
   uCallbookBase;

const
   (* The provider used until there is more than one and a setting to choose. *)
   DEFAULT_CALLBOOK_PROVIDER = 'hamdb';

(* Looks aCall up in the default provider off the UI thread and calls aOnDone on
   the main thread.

   aRec IS OWNED BY THE LOOKUP and freed as soon as aOnDone returns: copy what
   you need out of it.  It is never nil.  A failed request, an unknown call and
   an empty call all arrive as Found=False; each writes one line to tr4w.log,
   and nothing is raised or shown.  aOnDone may be nil (the lookup is then only
   logged).  The callback is NOT called if the program shuts down first, and a
   receiver destroyed before it fires must not be the one that is called. *)
procedure LookupCallsignAsync(const aCall: string; aOnDone: TCallbookDoneEvent);

implementation

uses
   Classes, SysUtils, uCallbookRegistry;

type
   TCallbookLookupThread = class(TThread)
   private
      FCall:   string;
      FOnDone: TCallbookDoneEvent;
      FRec:    TCallbookRecord;
      procedure ReportDone(Sender: TObject);
   protected
      procedure Execute; override;
   public
      constructor Create(const aCall: string; aOnDone: TCallbookDoneEvent);
      destructor Destroy; override;
   end;

constructor TCallbookLookupThread.Create(const aCall: string;
   aOnDone: TCallbookDoneEvent);
begin
   inherited Create(True);  // suspended; the caller starts it
   FCall           := aCall;
   FOnDone         := aOnDone;
   OnTerminate     := ReportDone;
   FreeOnTerminate := True;
end;

destructor TCallbookLookupThread.Destroy;
begin
   FRec.Free;  // only non-nil when the program ended before ReportDone ran
   inherited Destroy;
end;

procedure TCallbookLookupThread.Execute;
var
   provider: TCallbookProvider;
begin
   try
      provider := CreateCallbookProvider(DEFAULT_CALLBOOK_PROVIDER);
      try
         FRec := provider.Lookup(FCall);
      finally
         provider.Free;
      end;
   except
      on E: Exception do
         begin
         CallbookLogger.Error('[Callbook] lookup of %s raised %s: %s',
            [FCall, E.ClassName, E.Message]);
         end;
   end;

   if FRec = nil then
      begin
      FRec := TCallbookRecord.Create;
      FRec.Call := UpperCase(Trim(FCall));
      end;
end;

procedure TCallbookLookupThread.ReportDone(Sender: TObject);
begin
   try
      if Assigned(FOnDone) then
         begin
         FOnDone(FRec);
         end;
   finally
      FreeAndNil(FRec);
   end;
end;

procedure LookupCallsignAsync(const aCall: string; aOnDone: TCallbookDoneEvent);
var
   thread: TCallbookLookupThread;
begin
   thread := TCallbookLookupThread.Create(aCall, aOnDone);
   thread.Start;
end;

end.

unit uTestRadioPTTviaCAT;
{$I ..\..\src\tr4w.inc}

(*
  TFactoryRadioBase.PTTviaCAT -- issue 323.

  The property was `read GetPTTviaCAT write SetPTTviaCAT`, and each accessor
  read or wrote the PROPERTY rather than storage behind it:

     Result := Self.PTTviaCAT;      -- in GetPTTviaCAT
     Self.PTTviaCAT := Value;       -- in SetPTTviaCAT

  so either one called itself until the stack ran out.  Nothing in the program
  reads or writes the property, which is why it never showed.  It now reads and
  writes a field, and there is no accessor left to recurse.

  HOW A REGRESSION SHOWS.  The get and the sets run on a SACRIFICIAL WORKER
  THREAD with a small stack, never on the runner's thread.  A recursive
  accessor exhausts that thread's stack; the worker's own except records the
  exception (EStackOverflow) as text and the test thread then FAILS AN
  ASSERTION naming it.  The runner's stack is never touched, so a regression
  is one [FAIL] line and the rest of the run goes on.  If the worker does not
  finish inside the deadline the test fails by assertion as well, and the
  thread is deliberately leaked rather than joined, so the run cannot hang.
*)

interface

uses
   SysUtils, Classes, SyncObjs,
   uTR4WTestFramework, uFactoryRadioBase;

type
   (* A TFactoryRadioBase and nothing else. *)
   TPTTviaCATProbeRadio = class(TFactoryRadioBase)
   end;

   (* Reads and writes the property on its own thread, and records what it
     saw.  Every result is written before FDone is set and read after it. *)
   TPTTviaCATWorker = class(TThread)
   private
      FRadio: TFactoryRadioBase;
      FDone: TEvent;
      FError: string;
      FAfterCreate: boolean;
      FAfterSetTrue: boolean;
      FAfterSetFalse: boolean;
   protected
      procedure Execute; override;
   public
      constructor Create(ARadio: TFactoryRadioBase);
      destructor Destroy; override;
      function WaitDone(AMs: Cardinal): boolean;
      property Error: string read FError;
      property AfterCreate: boolean read FAfterCreate;
      property AfterSetTrue: boolean read FAfterSetTrue;
      property AfterSetFalse: boolean read FAfterSetFalse;
   end;

   TRadioPTTviaCATTests = class(TTestCase)
   private
      procedure HandleMessage(sMessage: string);
   protected
      procedure Test_PTTviaCAT_GetAndSetRoundTrip;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   (* Enough for a field read and a field write many times over; small, so a
     recursive accessor runs out quickly. *)
   WORKER_STACK_BYTES = 256 * 1024;

   (* A correct run finishes in microseconds. *)
   WORKER_DEADLINE_MS = 10000;

(* ---- worker ----------------------------------------------------------------- *)

constructor TPTTviaCATWorker.Create(ARadio: TFactoryRadioBase);
begin
   FRadio := ARadio;
   FDone := TEvent.Create(nil, True, False, '');
   FError := '';
   inherited Create(True, WORKER_STACK_BYTES);
end;

destructor TPTTviaCATWorker.Destroy;
begin
   (* inherited joins the thread; the event it signals is freed after. *)
   inherited Destroy;
   FDone.Free;
end;

procedure TPTTviaCATWorker.Execute;
begin
   try
      try
         FAfterCreate := FRadio.PTTviaCAT;
         FRadio.PTTviaCAT := True;
         FAfterSetTrue := FRadio.PTTviaCAT;
         FRadio.PTTviaCAT := False;
         FAfterSetFalse := FRadio.PTTviaCAT;
      except
         on E: Exception do
            begin
            FError := E.ClassName + ': ' + E.Message;
            end;
      end;
   finally
      FDone.SetEvent;
   end;
end;

function TPTTviaCATWorker.WaitDone(AMs: Cardinal): boolean;
begin
   Result := FDone.WaitFor(AMs) = wrSignaled;
end;

(* ---- tests ------------------------------------------------------------------ *)

procedure TRadioPTTviaCATTests.HandleMessage(sMessage: string);
begin
   (* The probe radio never connects, so nothing arrives here. *)
end;

procedure TRadioPTTviaCATTests.Test_PTTviaCAT_GetAndSetRoundTrip;
var
   handler: TProcessMsgRef;
   radio: TFactoryRadioBase;
   worker: TPTTviaCATWorker;
begin
   BeginTest('PTTviaCAT reads and writes its field -- no accessor recursion (issue 323)');
   (* A typed local and no @ -- see uTestRadioSocketProbe.MakeRadio. *)
   handler := HandleMessage;
   radio := TPTTviaCATProbeRadio.Create(handler);
   worker := TPTTviaCATWorker.Create(radio);
   worker.Start;

   if not worker.WaitDone(WORKER_DEADLINE_MS) then
      begin
      (* Leaked on purpose, the radio with it: freeing either would wait on, or
        pull memory from under, a thread that is still running. *)
      CheckTrue(False, Format('reading and writing PTTviaCAT did not finish in %d ms',
                              [WORKER_DEADLINE_MS]));
      Exit;
      end;

   worker.WaitFor;
   CheckEquals('', worker.Error,
               'reading or writing PTTviaCAT raised -- an accessor that reads or ' +
               'writes the property itself recurses until the stack runs out');
   CheckFalse(worker.AfterCreate, 'a new radio reports PTTviaCAT = False');
   CheckTrue(worker.AfterSetTrue, 'PTTviaCAT reads True after it is set True');
   CheckFalse(worker.AfterSetFalse, 'PTTviaCAT reads False after it is set False');

   worker.Free;
   radio.Free;
end;

procedure TRadioPTTviaCATTests.RunAllTests;
begin
   Test_PTTviaCAT_GetAndSetRoundTrip;
end;

end.

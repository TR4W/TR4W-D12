unit uTestExternalLoggerLookup;
{$I ..\..\src\tr4w.inc}

(*
  TExternalLogger.LookupCallsign FOR EVERY LOGGER TYPE (issue #101).

  THE DEFECT.  The lt_DxKeeper arm read `Result := Self.LookupCallsign(ce)`:
  the method called itself with its own argument, so any caller recursed until
  the stack overflowed.  (The D7 tree, uExternalLogger.pas:261, has the same
  line, so D7 was no guide.)  The intended target is LookupCallsignToDXKeeper,
  the DXKeeper "check" command builder two screens below.  The ACLog and HRD
  types had no arm at all, so the function returned an unassigned value there.

  THE DOCUMENTED VALUES.  0 = the lookup was queued for the logger; -1 = this
  logger type does not support a lookup (none, ACLog, HRD).

  NO NETWORK.  The probe overrides the protected DeliverCommand -- the one
  transport hook the sender thread calls -- and records the command instead of
  connecting anywhere.  The sender thread is asynchronous, so the DXKeeper case
  waits on an event (bounded) for the recorded command.
*)

interface

uses
   SysUtils, Classes, SyncObjs,
   uTR4WTestFramework, uExternalLoggerBase, uExternalLogger;

type
   (* A real TExternalLogger whose transport records. *)
   TRecordingLogger = class(TExternalLogger)
   private
      FLock:     TCriticalSection;
      FSeen:     TStringList;
      FArrived:  TEvent;
   protected
      function DeliverCommand(const cmd: string): boolean; override;
   public
      constructor Create(aType: ExternalLoggerType);
      destructor Destroy; override;
      function WaitForCommand(aTimeoutMs: Integer): boolean;
      function CommandCount: Integer;
      function CommandText(aIndex: Integer): string;
   end;

   TExternalLoggerLookupTests = class(TTestCase)
   protected
      procedure Test_DXKeeper_QueuesTheCheckCommand;
      procedure Test_UnsupportedTypes_ReturnMinusOneAndSendNothing;
      procedure Test_EveryTypeAnswersWithoutRecursing;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC;

const
   TEST_CALL = 'K1ABC';

constructor TRecordingLogger.Create(aType: ExternalLoggerType);
begin
   FLock := TCriticalSection.Create;
   FSeen := TStringList.Create;
   FArrived := TEvent.Create(nil, False, False, '');
   inherited Create(aType);
end;

destructor TRecordingLogger.Destroy;
begin
   (* The base destructor drains and joins the sender thread, which calls
     DeliverCommand: stop it BEFORE the recorder it writes to is freed. *)
   inherited Destroy;
   FreeAndNil(FArrived);
   FreeAndNil(FSeen);
   FreeAndNil(FLock);
end;

function TRecordingLogger.DeliverCommand(const cmd: string): boolean;
begin
   FLock.Enter;
   try
      FSeen.Add(cmd);
   finally
      FLock.Leave;
   end;
   FArrived.SetEvent;
   Result := True;
end;

function TRecordingLogger.WaitForCommand(aTimeoutMs: Integer): boolean;
begin
   Result := FArrived.WaitFor(aTimeoutMs) = wrSignaled;
end;

function TRecordingLogger.CommandCount: Integer;
begin
   FLock.Enter;
   try
      Result := FSeen.Count;
   finally
      FLock.Leave;
   end;
end;

function TRecordingLogger.CommandText(aIndex: Integer): string;
begin
   FLock.Enter;
   try
      Result := FSeen[aIndex];
   finally
      FLock.Leave;
   end;
end;

function LookupExchange: ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Callsign := TEST_CALL;
end;

procedure TExternalLoggerLookupTests.Test_DXKeeper_QueuesTheCheckCommand;
var
   probe: TRecordingLogger;
   answer: Integer;
begin
   BeginTest('LookupCallsign on a DXKeeper logger queues the check command and returns 0');

   probe := TRecordingLogger.Create(lt_DxKeeper);
   try
      answer := probe.LookupCallsign(LookupExchange);

      CheckEquals(0, answer, 'queued');
      CheckTrue(probe.WaitForCommand(5000), 'the sender thread delivered the lookup');
      CheckEquals(1, probe.CommandCount, 'exactly one command');
      CheckEquals('<command:5>check<parameters:5>' + TEST_CALL, probe.CommandText(0),
                  'the DXKeeper check command for the callsign');
   finally
      probe.Free;
   end;
end;

procedure TExternalLoggerLookupTests.Test_UnsupportedTypes_ReturnMinusOneAndSendNothing;
var
   lt: ExternalLoggerType;
   probe: TRecordingLogger;
begin
   BeginTest('LookupCallsign on none, ACLog and HRD returns -1 and sends nothing');

   for lt := lt_NoExternalLogger to lt_HRD do
      begin
      if lt <> lt_DxKeeper then
         begin
         probe := TRecordingLogger.Create(lt);
         try
            CheckEquals(-1, probe.LookupCallsign(LookupExchange),
                        ExternalLoggerTypeSA[lt] + ': not supported, a defined value rather than garbage');
            CheckFalse(probe.WaitForCommand(200), ExternalLoggerTypeSA[lt] + ': nothing was sent');
         finally
            probe.Free;
         end;
         end;
      end;
end;

(* The headline: every type returns.  On the old code the DXKeeper arm never
  does -- it overflows the stack. *)
procedure TExternalLoggerLookupTests.Test_EveryTypeAnswersWithoutRecursing;
var
   lt: ExternalLoggerType;
   probe: TRecordingLogger;
   answer: Integer;
begin
   BeginTest('LookupCallsign terminates for every logger type');

   for lt := lt_NoExternalLogger to lt_HRD do
      begin
      probe := TRecordingLogger.Create(lt);
      try
         answer := probe.LookupCallsign(LookupExchange);
         Check((answer = 0) or (answer = -1), ExternalLoggerTypeSA[lt] + ' returned a documented value');
      finally
         probe.Free;
      end;
      end;
end;

procedure TExternalLoggerLookupTests.RunAllTests;
begin
   Test_EveryTypeAnswersWithoutRecursing;
   Test_DXKeeper_QueuesTheCheckCommand;
   Test_UnsupportedTypes_ReturnMinusOneAndSendNothing;
end;

end.

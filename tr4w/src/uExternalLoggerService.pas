unit uExternalLoggerService;
{$I tr4w.inc}

interface

uses
   VC, uQsoDispatcher, uLogDatabase, uLogRepository;

type
   (* Protocol-neutral contract. The factory selects the implementation;
      callers neither select a wire format nor own a transport. *)
   TExternalLoggerService = class
   public
      DisplayName: string;
      procedure SetActive(aActive: boolean); virtual;
      function QueuesCommands: boolean; virtual;
      procedure PrepareMessage(const aMessage: TQsoMessage;
                               const ce: ContestExchange); virtual;
      procedure SubmitMessage(const aMessage: TQsoMessage); virtual;
      function PrepareOp(const aKind: TQsoMessageKind; const ce: ContestExchange;
                         out aCommand1: string; out aCommand2: string): TQsoExternalOp;
                         virtual; abstract;
      procedure SubmitOp(const aOp: TQsoExternalOp; const aCommand1: string;
                         const aCommand2: string; const aDescription: string);
                         virtual; abstract;
      function LookupCallsign(ce: ContestExchange): integer; virtual; abstract;
      (* Main-thread database hook. The row is saved but not committed yet.
         TCP loggers retain their dispatcher path; durable loggers override. *)
      procedure CaptureSavedQso(aDatabase: TLogDatabase; aRepository: TLogRepository;
                                aRowId: Int64; aNew: boolean); virtual;
      procedure AfterLogCommit(aDatabase: TLogDatabase); virtual;
      procedure LogClosed; virtual;
      procedure RequestStop; virtual;
      function StopFinished: boolean; virtual;
      procedure DetachOwner; virtual;
   end;

implementation

function TExternalLoggerService.QueuesCommands: boolean;
begin
   Result := True;
end;

procedure TExternalLoggerService.SetActive(aActive: boolean);
begin
end;

procedure TExternalLoggerService.RequestStop;
begin
end;

function TExternalLoggerService.StopFinished: boolean;
begin
   Result := True;
end;

procedure TExternalLoggerService.DetachOwner;
begin
end;

procedure TExternalLoggerService.PrepareMessage(const aMessage: TQsoMessage;
   const ce: ContestExchange);
begin
   aMessage.ExtOp := PrepareOp(aMessage.Kind, ce,
      aMessage.ExtCommand1, aMessage.ExtCommand2);
end;

procedure TExternalLoggerService.SubmitMessage(const aMessage: TQsoMessage);
begin
   SubmitOp(aMessage.ExtOp, aMessage.ExtCommand1, aMessage.ExtCommand2,
      aMessage.Description);
end;

procedure TExternalLoggerService.CaptureSavedQso(aDatabase: TLogDatabase;
   aRepository: TLogRepository; aRowId: Int64; aNew: boolean);
begin
end;

procedure TExternalLoggerService.AfterLogCommit(aDatabase: TLogDatabase);
begin
end;

procedure TExternalLoggerService.LogClosed;
begin
end;

end.

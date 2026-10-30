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
   end;

implementation

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

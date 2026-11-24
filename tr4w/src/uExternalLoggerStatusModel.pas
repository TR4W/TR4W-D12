unit uExternalLoggerStatusModel;
(* WHAT THE EXTERNAL LOGGERS WINDOW SHOWS, AS DATA (NY4I, 2026-11-24: "an
   external window which shows the status of the external loggers, ability to
   resend, and a button to edit or add new ones").

   No window, no database and no network in this unit, so a unit test pins every
   decision. Three things live here, each ONCE for both windows that need it:

   1. THE STATE TEXT of a logger (ExternalLoggerStateText) -- what the Preferences
      grid's Connection column and the standalone window both print. It was
      private to the grid; lifted here so the two cannot word a state two ways.
   2. THE ROW MODEL (BuildLoggerStatusRows): one row per configured logger, from
      the SAVED configuration and a state query, in the order Preferences shows
      (active ones in delivery order, then the rest).
   3. THE DECISIONS: whether Resync may run for a state (ResyncPreflight) and
      whether the button is enabled (LoggerStatusCanResync).

   The saved configuration, not the Preferences working copy: this window is
   about what the running program is doing, and an unsaved edit changes a
   definition's DeliveryId and so its queue. *)
{$I tr4w.inc}
interface
uses
   SysUtils, Classes, Generics.Collections, uExternalLoggerConfig,
   uExternalLoggerService, uExternalDelivery;
type
   (* The owner's window onto the running program: the snapshot of the service
      running aDeliveryId (False when there is none) and that destination's
      durable queue counts (zero when no log is open). Main thread. *)
   TLoggerStateQuery = function(const aDeliveryId: string;
      out aSnapshot: TExternalLoggerSnapshot;
      out aCounts: TDeliveryCounts): boolean of object;

   (* One logger, as the window lists it. A class (the project prefers one);
      the list that holds it owns it. *)
   TLoggerStatusRow = class
   public
      Id, DeliveryId, Name, Provider: string;
      (* '1', '2', ... the delivery position, or '-' when switched off. *)
      OrderText: string;
      Enabled: boolean;
      State: TExternalLoggerState;
      StateText: string;
   end;

   TLoggerStatusRows = TObjectList<TLoggerStatusRow>;

   (* Whether Resync may go ahead for a logger in a given state, and if not,
      why. The reasons are the ones the Preferences button has always given,
      said before the confirmation is asked. *)
   TResyncPreflight = (rpOk, rpSwitchedOff, rpNotRunning, rpNotActive);

(* The text for a state. The reason is a fixed delivery code, never server text
   (a code with words shows them: DeliveryFailureReasonText). Old uncertain or
   failed rows ride along as counts. *)
function ExternalLoggerStateText(aState: TExternalLoggerState;
   const aSnapshot: TExternalLoggerSnapshot; const aCounts: TDeliveryCounts): string;

(* Fills aRows (cleared first) from aConfig, in display order. aQuery may be
   nil: every logger is then reported as not running. *)
procedure BuildLoggerStatusRows(const aConfig: TExternalLoggerConfig;
   aQuery: TLoggerStateQuery; const aRows: TLoggerStatusRows);

function ResyncPreflight(aState: TExternalLoggerState): TResyncPreflight;

(* The Resync button is enabled when a logger is selected. *)
function LoggerStatusCanResync(const aSelectedId: string): boolean;

implementation
uses uAppStrings, uExternalLoggerActions;

function ExternalLoggerStateText(aState: TExternalLoggerState;
   const aSnapshot: TExternalLoggerSnapshot; const aCounts: TDeliveryCounts): string;
var
   code: string;
begin
   code := aSnapshot.Code;
   if code = '' then
      begin
      code := 'UNSPECIFIED';
      end
   else if DeliveryFailureReasonText(code) <> '' then
      begin
      (* A code that has words (plain http refused, a QSO the logger cannot be
         given) shows them; any other shows the code itself. *)
      code := DeliveryFailureReasonText(code);
      end;
   case aState of
      elsDisabled:
         begin
         Result := SLoggerStateDisabled;
         end;
      elsRestartNeeded:
         begin
         Result := SLoggerStateRestart;
         end;
      elsApplyOnSave:
         begin
         Result := SLoggerStateApplyOnSave;
         end;
      elsIdle:
         begin
         Result := SLoggerStateIdle;
         end;
      elsSending:
         begin
         Result := UnicodeFormat(SLoggerStateSending,
            [aCounts.Pending + aCounts.InFlight + aSnapshot.QueueDepth]);
         end;
      elsRetrying:
         begin
         Result := UnicodeFormat(SLoggerStateRetrying, [code]);
         end;
      elsPaused:
         begin
         Result := UnicodeFormat(SLoggerStatePaused, [code]);
         end;
      elsFailed:
         begin
         Result := UnicodeFormat(SLoggerStateFailed, [code]);
         end;
   else
      begin
      Result := '';
      end;
   end;
   if (aState in [elsIdle, elsSending, elsRetrying, elsPaused, elsFailed]) and
      ((aCounts.Uncertain > 0) or (aCounts.Failed > 0)) then
      begin
      Result := UnicodeFormat(SLoggerStateCounts,
         [Result, aCounts.Uncertain, aCounts.Failed]);
      end;
end;

procedure BuildLoggerStatusRows(const aConfig: TExternalLoggerConfig;
   aQuery: TLoggerStateQuery; const aRows: TLoggerStatusRows);
var
   ids: TStringList;
   i, position: integer;
   definition: TExternalLoggerDefinition;
   row: TLoggerStatusRow;
   snapshot: TExternalLoggerSnapshot;
   counts: TDeliveryCounts;
   known: boolean;
begin
   aRows.Clear;
   if aConfig = nil then
      begin
      Exit;
      end;
   ids := TStringList.Create;
   try
      aConfig.DisplayOrder(ids);
      for i := 0 to ids.Count - 1 do
         begin
         definition := aConfig.Find(string(ids[i]));
         if definition = nil then
            begin
            Continue;
            end;
         position := aConfig.ActivePosition(definition.Id);
         row := TLoggerStatusRow.Create;
         row.Id := definition.Id;
         row.DeliveryId := definition.DeliveryId;
         row.Name := definition.Name;
         row.Provider := definition.ProviderId;
         row.Enabled := position > 0;
         if row.Enabled then
            begin
            row.OrderText := string(IntToStr(position));
            end
         else
            begin
            row.OrderText := '-';
            end;
         snapshot := Default(TExternalLoggerSnapshot);
         counts := Default(TDeliveryCounts);
         known := Assigned(aQuery) and aQuery(definition.DeliveryId, snapshot, counts);
         row.State := DeriveExternalLoggerState(row.Enabled, known, snapshot, counts);
         row.StateText := ExternalLoggerStateText(row.State, snapshot, counts);
         aRows.Add(row);
         end;
   finally
      ids.Free;
   end;
end;

function ResyncPreflight(aState: TExternalLoggerState): TResyncPreflight;
begin
   (* Not running (added or changed since start) or not yet applied: the same
      reasons the service would give, said before the question is asked. *)
   case aState of
      elsDisabled:
         begin
         Result := rpSwitchedOff;
         end;
      elsRestartNeeded:
         begin
         Result := rpNotRunning;
         end;
      elsApplyOnSave:
         begin
         Result := rpNotActive;
         end;
   else
      begin
      Result := rpOk;
      end;
   end;
end;

function LoggerStatusCanResync(const aSelectedId: string): boolean;
begin
   Result := aSelectedId <> '';
end;

end.

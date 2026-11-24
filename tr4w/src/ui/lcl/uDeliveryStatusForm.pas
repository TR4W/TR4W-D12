(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
*)
unit uDeliveryStatusForm;
{$I ..\..\tr4w.inc}

(* WHERE EACH EXTERNAL LOGGER STANDS WITH ONE QSO -- a read-only window
  opened from Edit QSO's "External loggers..." button (2026-11-23).

  It replaced a one-line label under the our-station group. That line named
  the destination by its delivery KEY (provider/definition id/fingerprint,
  TExternalLoggerDefinition.DeliveryId), which overflowed the form, and it
  showed ONE row (the query had LIMIT 1), so a QSO sent to three loggers
  described one and hid two. Here every external_delivery row of the QSO is
  a grid row, and the logger is named by the NAME the operator gave its
  definition (DeliveryLoggerName).

  THE DATA IS IN THE GRID'S Cells -- no owner draw, no shadow list. The
  texts come from DeliveryRowCells, a plain function the unit tests call
  without the form. Every caption is a placeholder in the .lfm and is
  assigned from uAppStrings in the constructor (uServerLogForm's pattern),
  so the catalogue is the one route to a translation. *)

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Grids,
  uExternalDelivery,       // TDeliveryStatus, TDeliveryStatusList
  uExternalLoggerService,  // TExternalLoggerSnapshot -- a logger's standing now
  uExternalLoggerConfig;   // TExternalLoggerConfig -- the definitions' names

type
  TfrmDeliveryStatus = class(TForm)
    grdDeliveries: TStringGrid;
    pnlButtons: TPanel;
    btnClose: TButton;
  public
    constructor Create(aOwner: TComponent); override;
    (* One grid row per element of aStatuses, named through aConfig (nil:
       provider names only). Replaces whatever the grid held. *)
    procedure ShowStatuses(const aStatuses: TDeliveryStatusList;
                           aConfig: TExternalLoggerConfig);
  end;

const
  (* The grid's columns, and the order DeliveryRowCells writes them in. *)
  DELIVERY_COL_LOGGER    = 0;
  DELIVERY_COL_STATUS    = 1;
  DELIVERY_COL_LAST_SENT = 2;
  DELIVERY_COLUMNS       = 3;

(* The stored state word (uLogSchema's CHECK) in the operator's words -- the
  same ones the Preferences delivery summary uses. A failed row names its
  code when it has one. A state this build does not know is shown as stored
  rather than hidden. *)
function DeliveryStateText(const aStatus: TDeliveryStatus): string;

(* When the destination last answered, in UTC: 'yyyy-mm-dd hh:nn', or the
  "not sent yet" words when it never did (LastSent = 0). *)
function DeliveryLastSentText(const aStatus: TDeliveryStatus): string;

(* THE LOGGER'S NAME FOR A DELIVERY KEY. The key is
  <provider>/<definition id>/<fingerprint>, or a bare provider id in a log
  written before definitions existed ('WRL'). In order:
    1. the name of the definition with that id in aConfig (nil: skipped);
    2. the provider's registered DisplayName (the definition was removed);
    3. the provider id itself (not registered in this build).
  Pure apart from the provider registry, so the tests pin it. *)
function DeliveryLoggerName(const aLoggerKey: string;
                            aConfig: TExternalLoggerConfig): string;

(* One row's texts, in the order of the DELIVERY_COL_ constants: aCells is cleared and
  receives exactly DELIVERY_COLUMNS strings. *)
procedure DeliveryRowCells(const aStatus: TDeliveryStatus;
                           aConfig: TExternalLoggerConfig; aCells: TStrings);

type
  (* A running logger's standing, asked by delivery id: the snapshot of the
     service that runs it, False when none does. A plain function so a test
     can stand in for the program's composite. *)
  TLoggerStanding = function(const aDeliveryId: string;
                             out aSnapshot: TExternalLoggerSnapshot): boolean;

(* WHY A CONFIGURED LOGGER HAS NOTHING FOR THIS QSO, as a fixed token:
     'off'       switched off (or its running copy is);
     'restart'   switched on but no running service has it yet;
     'paused'    stopped after a capture failure (review needed);
     'setup'     account or logbook not set up;
     'notqueued' running, and this QSO was never queued for it (logged while
                 it was off, or by another station).
  Pure, so a test pins every branch. *)
function UnsentReasonToken(aConfigEnabled, aKnown: boolean;
                           const aSnapshot: TExternalLoggerSnapshot): string;

(* EVERY CONFIGURED LOGGER IS LISTED FOR EVERY QSO. A logger with no delivery
  row is absent from aStatuses; a window that shows only rows reads as if TR4W
  never tried. Returns aStatuses followed by one row per configured logger that
  has none: State 'notsent' and ErrorCode the token above. A row belongs to a
  definition by its delivery id or by the definition's own id inside the key
  (a destination edited since has a new delivery id). aConfig nil returns
  aStatuses unchanged. *)
function WithUnlistedLoggers(const aStatuses: TDeliveryStatusList;
                             aConfig: TExternalLoggerConfig;
                             aStanding: TLoggerStanding): TDeliveryStatusList;

(* The window, modal over aOver (Edit QSO). The definitions are read from the
  settings file at the click, so a logger renamed since startup shows its
  new name; if the file will not load, the provider names are shown. *)
procedure ShowDeliveryStatus(const aStatuses: TDeliveryStatusList;
                             aOver: TCustomForm);

implementation

{$R *.lfm}

uses
  // FIRST, so every unit below still wins any name it shares.
  uAppStrings,              // SDelivery*, SEditQSODelivery*
  uExternalLoggerActions,   // DeliveryFailureReasonText
  DateUtils,                // UnixToDateTime
  uExternalLoggerRegistry,  // FindExternalLoggerRegistration
  uRadioConfigStore,        // TRadioConfigStore -- holds the definitions
  uTR4WConfigFile,          // TR4WConfigFileName
  utils_text,               // LclText
  MainUnit,                 // logger
  Log4D;

(* The provider id a delivery key starts with (the whole key when it has no
  slash: a log written before definitions existed). *)
function DeliveryProviderOf(const aLoggerKey: string): string;
var
   slash: integer;
begin
   slash := Pos('/', aLoggerKey);
   if slash = 0 then
      begin
      Result := aLoggerKey;
      end
   else
      begin
      Result := Copy(aLoggerKey, 1, slash - 1);
      end;
end;

function DeliveryStateText(const aStatus: TDeliveryStatus): string;
var
   registration: TExternalLoggerRegistration;
   reason: string;
begin
   if aStatus.State = 'notsent' then
      begin
      (* A configured logger with no row for this QSO (WithUnlistedLoggers);
         ErrorCode is the token UnsentReasonToken chose. *)
      if aStatus.ErrorCode = 'paused' then
         begin
         Result := SDeliveryNotSentPaused;
         end
      else if aStatus.ErrorCode = 'off' then
         begin
         Result := SDeliveryNotSentOff;
         end
      else if aStatus.ErrorCode = 'restart' then
         begin
         Result := SDeliveryNotSentRestart;
         end
      else if aStatus.ErrorCode = 'setup' then
         begin
         Result := SDeliveryNotSentSetup;
         end
      else
         begin
         Result := SDeliveryNotSentNotQueued;
         end;
      Exit;
      end;
   reason := '';
   if aStatus.State = 'failed' then
      begin
      (* A QSO the logger could not be given (no frequency, say) names why. *)
      reason := DeliveryFailureReasonText(aStatus.ErrorCode);
      end;
   if reason <> '' then
      begin
      Result := UnicodeFormat(SEditQSODeliveryFailedBecause, [reason]);
      end
   else if (aStatus.State = 'pending') and (aStatus.ErrorCode <> '') then
      begin
      (* Complete(doRetry) leaves the code of the attempt that failed. *)
      Result := UnicodeFormat(SEditQSODeliveryRetryingWithCode, [aStatus.ErrorCode]);
      end
   else if aStatus.State = 'pending' then
      begin
      Result := SEditQSODeliveryPending;
      end
   else if aStatus.State = 'inflight' then
      begin
      Result := SEditQSODeliverySending;
      end
   else if (aStatus.State = 'synced') and
           FindExternalLoggerRegistration(DeliveryProviderOf(aStatus.Logger), registration) and
           registration.HandOffOnly then
      begin
      (* The destination gives no reply: the command was written, nothing more. *)
      Result := SEditQSODeliveryHandedOff;
      end
   else if aStatus.State = 'synced' then
      begin
      Result := SEditQSODeliverySynced;
      end
   else if aStatus.State = 'uncertain' then
      begin
      Result := SEditQSODeliveryUncertain;
      end
   else if aStatus.State = 'failed' then
      begin
      if aStatus.ErrorCode <> '' then
         begin
         Result := UnicodeFormat(SEditQSODeliveryFailedWithCode, [aStatus.ErrorCode]);
         end
      else
         begin
         Result := SEditQSODeliveryFailed;
         end;
      end
   else
      begin
      Result := aStatus.State;
      end;
end;

// LastSent is Unix seconds UTC; UnixToDateTime converts nothing by default,
// so the time shown is UTC, and the column heading says so. The colon is
// QUOTED: a bare ':' in FormatDateTime is the locale's TimeSeparator, which
// is '.' on some stations, and a UTC stamp should read the same everywhere.
function DeliveryLastSentText(const aStatus: TDeliveryStatus): string;
begin
   if aStatus.LastSent > 0 then
      begin
      Result := string(FormatDateTime('yyyy-mm-dd hh":"nn',
                                      DateUtils.UnixToDateTime(aStatus.LastSent)));
      end
   else
      begin
      Result := SEditQSODeliveryNeverSent;
      end;
end;

function DeliveryLoggerName(const aLoggerKey: string;
                            aConfig: TExternalLoggerConfig): string;
var
  slash, lastSlash: integer;
  provider, rest, definitionId: string;
  definition: TExternalLoggerDefinition;
  registration: TExternalLoggerRegistration;
begin
   (* Split the key. The definition id is a GUID and the fingerprint a hex
      digest, neither of which holds a '/'; the id is taken as everything
      between the first and the last slash all the same, so the split does
      not depend on that. *)
   slash := Pos('/', aLoggerKey);
   provider := DeliveryProviderOf(aLoggerKey);
   if slash = 0 then
      begin
      definitionId := '';
      end
   else
      begin
      rest := Copy(aLoggerKey, slash + 1, MaxInt);
      (* A scan, not SysUtils.LastDelimiter: that takes an AnsiString in FPC
         3.2.2, and the call would narrow. *)
      lastSlash := Length(rest);
      while (lastSlash > 0) and (rest[lastSlash] <> '/') do
         begin
         Dec(lastSlash);
         end;
      if lastSlash = 0 then
         begin
         definitionId := rest;
         end
      else
         begin
         definitionId := Copy(rest, 1, lastSlash - 1);
         end;
      end;

   if (aConfig <> nil) and (definitionId <> '') then
      begin
      definition := aConfig.Find(definitionId);
      if (definition <> nil) and (Trim(definition.Name) <> '') then
         begin
         Result := definition.Name;
         Exit;
         end;
      end;

   if FindExternalLoggerRegistration(provider, registration) then
      begin
      Result := registration.DisplayName;
      end
   else if provider <> '' then
      begin
      Result := provider;
      end
   else
      begin
      Result := aLoggerKey;
      end;
end;

function UnsentReasonToken(aConfigEnabled, aKnown: boolean;
                           const aSnapshot: TExternalLoggerSnapshot): string;
begin
   if not aKnown then
      begin
      if aConfigEnabled then
         begin
         Result := 'restart';
         end
      else
         begin
         Result := 'off';
         end;
      end
   else if not (aConfigEnabled and aSnapshot.Active) then
      begin
      Result := 'off';
      end
   else if aSnapshot.Halted and (aSnapshot.Code = 'LOGGER_SETUP_REQUIRED') then
      begin
      Result := 'setup';
      end
   else if aSnapshot.Halted then
      begin
      Result := 'paused';
      end
   else
      begin
      Result := 'notqueued';
      end;
end;

function WithUnlistedLoggers(const aStatuses: TDeliveryStatusList;
                             aConfig: TExternalLoggerConfig;
                             aStanding: TLoggerStanding): TDeliveryStatusList;
var
   k, i, n: integer;
   definition: TExternalLoggerDefinition;
   listed, known: boolean;
   snapshot: TExternalLoggerSnapshot;
begin
   Result := Copy(aStatuses);
   if aConfig = nil then
      begin
      Exit;
      end;
   for k := 0 to aConfig.Definitions.Count - 1 do
      begin
      definition := aConfig.Definitions[k];
      listed := False;
      for i := 0 to High(aStatuses) do
         begin
         if (aStatuses[i].Logger = definition.DeliveryId) or
            (Pos('/' + definition.Id + '/', aStatuses[i].Logger) > 0) then
            begin
            listed := True;
            Break;
            end;
         end;
      if listed then
         begin
         Continue;
         end;
      snapshot := Default(TExternalLoggerSnapshot);
      known := Assigned(aStanding) and aStanding(definition.DeliveryId, snapshot);
      n := Length(Result);
      SetLength(Result, n + 1);
      Result[n] := Default(TDeliveryStatus);
      Result[n].Logger := definition.DeliveryId;
      Result[n].State := 'notsent';
      Result[n].ErrorCode := UnsentReasonToken(aConfig.ActivePosition(definition.Id) > 0,
         known, snapshot);
      end;
end;

(* The program's composite, as a TLoggerStanding. *)
function ProgramLoggerStanding(const aDeliveryId: string;
                               out aSnapshot: TExternalLoggerSnapshot): boolean;
begin
   aSnapshot := Default(TExternalLoggerSnapshot);
   Result := (externalLogger <> nil) and externalLogger.StateSnapshot(aDeliveryId, aSnapshot);
end;

procedure DeliveryRowCells(const aStatus: TDeliveryStatus;
                           aConfig: TExternalLoggerConfig; aCells: TStrings);
begin
   aCells.Clear;
   (* In the order of the DELIVERY_COL_ constants. LclText: a TStrings holds the LCL's UTF-8. *)
   aCells.Add(LclText(DeliveryLoggerName(aStatus.Logger, aConfig)));
   aCells.Add(LclText(DeliveryStateText(aStatus)));
   aCells.Add(LclText(DeliveryLastSentText(aStatus)));
end;

(* TfrmDeliveryStatus *)

constructor TfrmDeliveryStatus.Create(aOwner: TComponent);
begin
   inherited Create(aOwner);
   (* RUN-TIME TEXT FROM uAppStrings: the .lfm text is a placeholder.
      Resourcestrings are 8-bit, so they go onto a caption directly. *)
   Caption := SDeliveryWindowTitle;
   btnClose.Caption := SDeliveryClose;
   grdDeliveries.Cells[DELIVERY_COL_LOGGER, 0] := SDeliveryColLogger;
   grdDeliveries.Cells[DELIVERY_COL_STATUS, 0] := SDeliveryColStatus;
   grdDeliveries.Cells[DELIVERY_COL_LAST_SENT, 0] := SDeliveryColLastSent;
end;

procedure TfrmDeliveryStatus.ShowStatuses(const aStatuses: TDeliveryStatusList;
                                          aConfig: TExternalLoggerConfig);
var
  i, c: integer;
  slack: integer;
  cells: TStringList;
begin
   cells := TStringList.Create;
   grdDeliveries.BeginUpdate;
   try
      grdDeliveries.RowCount := grdDeliveries.FixedRows + Length(aStatuses);
      for i := 0 to High(aStatuses) do
         begin
         DeliveryRowCells(aStatuses[i], aConfig, cells);
         for c := 0 to DELIVERY_COLUMNS - 1 do
            begin
            grdDeliveries.Cells[c, grdDeliveries.FixedRows + i] := cells[c];
            end;
         end;
   finally
      grdDeliveries.EndUpdate;
      cells.Free;
   end;
   (* Each column as wide as its widest text, heading included -- the grid
      measures its own Cells. *)
   grdDeliveries.AutoSizeColumns;
   (* THE LAST COLUMN TAKES WHAT IS LEFT, so the grid fills its window instead
      of ending after the last text. The dialog is not resizable (bsDialog), so
      once is enough. The vertical scrollbar's width is kept clear. *)
   slack := grdDeliveries.ClientWidth - 2;
   if grdDeliveries.RowCount * grdDeliveries.DefaultRowHeight >
      grdDeliveries.ClientHeight then
      begin
      (* A TStringGrid publishes no scrollbar object to ask; one row height is
         a close stand-in for the bar's width and errs on the safe side. *)
      slack := slack - grdDeliveries.DefaultRowHeight;
      end;
   for c := 0 to DELIVERY_COLUMNS - 2 do
      begin
      slack := slack - grdDeliveries.ColWidths[c];
      end;
   if slack > grdDeliveries.ColWidths[DELIVERY_COLUMNS - 1] then
      begin
      grdDeliveries.ColWidths[DELIVERY_COLUMNS - 1] := slack;
      end;
end;

procedure ShowDeliveryStatus(const aStatuses: TDeliveryStatusList;
                             aOver: TCustomForm);
var
  store: TRadioConfigStore;
  config: TExternalLoggerConfig;
  error: string;
  form: TfrmDeliveryStatus;
begin
   store := TRadioConfigStore.Create;
   form := nil;
   try
      config := nil;
      if FileExists(TR4WConfigFileName) then
         begin
         if store.LoadFromFile(TR4WConfigFileName, error) then
            begin
            config := store.ExternalLoggers;
            end
         else if logger <> nil then
            begin
            logger.Error('[EditQSO] external logger names could not be read (%s); ' +
                         'showing provider names', [error]);
            end;
         end;

      form := TfrmDeliveryStatus.Create(aOver);
      (* Every configured logger is listed, with a row or without. *)
      form.ShowStatuses(WithUnlistedLoggers(aStatuses, config, ProgramLoggerStanding), config);
      if aOver <> nil then
         begin
         (* Above Edit QSO, which is itself modal: the LCL's own owner rule,
            no window handle. *)
         form.PopupMode := pmExplicit;
         form.PopupParent := aOver;
         end;
      form.ShowModal;
   finally
      form.Free;
      store.Free;
   end;
end;

end.

unit uTestExternalLoggerStatusModel;
{$I ..\..\src\tr4w.inc}
(*
  THE EXTERNAL LOGGERS WINDOW'S DATA (NY4I, 2026-11-24) -- uExternalLoggerStatusModel,
  pure: no window, no database, no network.

  What is pinned: the state text (lifted out of the Preferences grid, so both
  windows word a state the same way, and a code with words shows them), the row
  model built from a configuration and the running program's answer (the order
  Preferences shows, the enabled flag, each state), and the two small decisions
  behind the buttons (Resync preflight, Resync enabled).
*)

interface

uses
   uTR4WTestFramework;

type
   TExternalLoggerStatusModelTests = class(TTestCase)
   protected
      procedure Test_StateTextForEveryState;
      procedure Test_StateTextShowsWordsForAKnownCode;
      procedure Test_StateTextAppendsOldCounts;
      procedure Test_RowsFollowTheDisplayOrder;
      procedure Test_RowsTakeTheirStateFromTheQuery;
      procedure Test_NoQueryMeansNotRunning;
      procedure Test_NilConfigIsAnEmptyList;
      procedure Test_ResyncPreflight;
      procedure Test_ResyncButtonNeedsASelection;
      procedure Test_WindowSlotAndMenuIdAgree;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, VC, uExternalLoggerConfig, uExternalLoggerService, uExternalDelivery,
   uExternalLoggerStatusModel, uAppStrings;

type
   (* Answers the question the way the running composite does: a destination is
      known only if it was told so; what it says is what it was handed. *)
   TStubQuery = class
   public
      KnownId: string;
      Snapshot: TExternalLoggerSnapshot;
      Counts: TDeliveryCounts;
      Asked: string;
      function Query(const aDeliveryId: string;
         out aSnapshot: TExternalLoggerSnapshot;
         out aCounts: TDeliveryCounts): boolean;
   end;

function TStubQuery.Query(const aDeliveryId: string;
   out aSnapshot: TExternalLoggerSnapshot; out aCounts: TDeliveryCounts): boolean;
begin
   Asked := Asked + '[' + aDeliveryId + ']';
   aSnapshot := Default(TExternalLoggerSnapshot);
   aCounts := Default(TDeliveryCounts);
   Result := aDeliveryId = KnownId;
   if Result then
      begin
      aSnapshot := Snapshot;
      aCounts := Counts;
      end;
end;

function NewDefinition(const aConfig: TExternalLoggerConfig; const aId, aName,
   aProvider: string): TExternalLoggerDefinition;
begin
   Result := TExternalLoggerDefinition.Create;
   Result.Id := aId;
   Result.Name := aName;
   Result.ProviderId := aProvider;
   Result.URL := 'https://' + aId + '.example';
   aConfig.Definitions.Add(Result);
end;

procedure TExternalLoggerStatusModelTests.Test_StateTextForEveryState;
var
   snap: TExternalLoggerSnapshot;
   counts: TDeliveryCounts;
begin
   BeginTest('State text: every state has its words');
   snap := Default(TExternalLoggerSnapshot);
   counts := Default(TDeliveryCounts);
   CheckEquals(SLoggerStateDisabled, ExternalLoggerStateText(elsDisabled, snap, counts));
   CheckEquals(SLoggerStateRestart, ExternalLoggerStateText(elsRestartNeeded, snap, counts));
   CheckEquals(SLoggerStateApplyOnSave, ExternalLoggerStateText(elsApplyOnSave, snap, counts));
   CheckEquals(SLoggerStateIdle, ExternalLoggerStateText(elsIdle, snap, counts));
   counts.Pending := 2;
   counts.InFlight := 1;
   snap.QueueDepth := 4;
   CheckEquals(UnicodeFormat(SLoggerStateSending, [7]), ExternalLoggerStateText(elsSending, snap, counts),
      'sending counts pending, in flight and the in-memory queue');
   snap.Code := 'WRL_RATE_LIMITED';
   CheckEquals(UnicodeFormat(SLoggerStateRetrying, ['WRL_RATE_LIMITED']),
      ExternalLoggerStateText(elsRetrying, snap, counts), 'retrying shows the code');
   CheckEquals(UnicodeFormat(SLoggerStatePaused, ['WRL_RATE_LIMITED']),
      ExternalLoggerStateText(elsPaused, snap, counts), 'paused shows the code');
   CheckEquals(UnicodeFormat(SLoggerStateFailed, ['WRL_RATE_LIMITED']),
      ExternalLoggerStateText(elsFailed, snap, counts), 'failed shows the code');
   snap.Code := '';
   CheckEquals(UnicodeFormat(SLoggerStatePaused, ['UNSPECIFIED']),
      ExternalLoggerStateText(elsPaused, snap, counts), 'no code reads UNSPECIFIED, never blank');
end;

procedure TExternalLoggerStatusModelTests.Test_StateTextShowsWordsForAKnownCode;
var
   snap: TExternalLoggerSnapshot;
   counts: TDeliveryCounts;
begin
   BeginTest('State text: a code that has words shows them (plain http refused), not the code');
   snap := Default(TExternalLoggerSnapshot);
   counts := Default(TDeliveryCounts);
   snap.Code := 'CLOUDLOG_INSECURE_URL_REFUSED';
   CheckEquals(UnicodeFormat(SLoggerStatePaused, [SLoggerWhyInsecure]),
      ExternalLoggerStateText(elsPaused, snap, counts));
   CheckTrue(Pos('CLOUDLOG', ExternalLoggerStateText(elsPaused, snap, counts)) = 0,
      'the raw code is not shown');
   snap.Code := 'MISSING_FREQUENCY';
   CheckEquals(UnicodeFormat(SLoggerStateFailed, [SLoggerWhyNoFrequency]),
      ExternalLoggerStateText(elsFailed, snap, counts));
   snap.Code := 'CLOUDLOG_HTTP_404';
   CheckEquals(UnicodeFormat(SLoggerStatePaused, [SLoggerWhyCloudlog404]),
      ExternalLoggerStateText(elsPaused, snap, counts), 'a Cloudlog 404 names the index.php cure');
   CheckTrue(Pos('CLOUDLOG_HTTP_404', ExternalLoggerStateText(elsPaused, snap, counts)) = 0,
      'the raw code is not shown');
end;

procedure TExternalLoggerStatusModelTests.Test_StateTextAppendsOldCounts;
var
   snap: TExternalLoggerSnapshot;
   counts: TDeliveryCounts;
begin
   BeginTest('State text: old uncertain and failed rows ride along as counts, only for a running state');
   snap := Default(TExternalLoggerSnapshot);
   counts := Default(TDeliveryCounts);
   counts.Uncertain := 3;
   counts.Failed := 5;
   CheckEquals(UnicodeFormat(SLoggerStateCounts, [SLoggerStateIdle, 3, 5]),
      ExternalLoggerStateText(elsIdle, snap, counts));
   CheckEquals(SLoggerStateDisabled, ExternalLoggerStateText(elsDisabled, snap, counts),
      'a switched-off logger carries no counts');
   CheckEquals(SLoggerStateRestart, ExternalLoggerStateText(elsRestartNeeded, snap, counts),
      'nor one that needs a restart');
   counts.LastFailedCode := 'DXKEEPER_NOT_DELIVERED';
   CheckEquals(UnicodeFormat(SLoggerStateCountsWhy,
      [SLoggerStateIdle, 3, 5, SLoggerWhyDXKeeperBrief]),
      ExternalLoggerStateText(elsIdle, snap, counts),
      'the latest failed row''s reason follows the counts');
   counts.LastFailedCode := 'UNKNOWN_CODE_WITH_NO_WORDS';
   CheckEquals(UnicodeFormat(SLoggerStateCounts, [SLoggerStateIdle, 3, 5]),
      ExternalLoggerStateText(elsIdle, snap, counts),
      'a code with no words keeps the old format');
end;

procedure TExternalLoggerStatusModelTests.Test_RowsFollowTheDisplayOrder;
var
   config: TExternalLoggerConfig;
   rows: TLoggerStatusRows;
   stub: TStubQuery;
   a, b, c: TExternalLoggerDefinition;
begin
   BeginTest('Rows: active loggers first in delivery order, then the rest; Order is the position or a dash');
   config := TExternalLoggerConfig.Create;
   rows := TLoggerStatusRows.Create(True);
   stub := TStubQuery.Create;
   try
      a := NewDefinition(config, 'id-a', 'Alpha', 'CLUBLOG');
      b := NewDefinition(config, 'id-b', 'Bravo', 'WRL');
      c := NewDefinition(config, 'id-c', 'Charlie', 'CLOUDLOG');
      config.SetActive(c.Id, True);
      config.SetActive(a.Id, True);
      BuildLoggerStatusRows(config, stub.Query, rows);
      CheckEquals(3, rows.Count, 'one row per definition');
      CheckEquals('Charlie', rows[0].Name, 'first active, first in delivery order');
      CheckEquals('1', rows[0].OrderText);
      CheckTrue(rows[0].Enabled);
      CheckEquals('CLOUDLOG', rows[0].Provider);
      CheckEquals('id-c', rows[0].Id);
      CheckEquals(c.DeliveryId, rows[0].DeliveryId, 'the delivery id names the queue');
      CheckEquals('Alpha', rows[1].Name);
      CheckEquals('2', rows[1].OrderText);
      CheckEquals('Bravo', rows[2].Name, 'the inactive one last');
      CheckEquals('-', rows[2].OrderText, 'a dash is a logger that is switched off');
      CheckFalse(rows[2].Enabled);
      CheckTrue(Pos('[' + b.DeliveryId + ']', stub.Asked) > 0, 'every row asked the program about its own delivery id');
   finally
      stub.Free;
      rows.Free;
      config.Free;
   end;
end;

procedure TExternalLoggerStatusModelTests.Test_RowsTakeTheirStateFromTheQuery;
var
   config: TExternalLoggerConfig;
   rows: TLoggerStatusRows;
   stub: TStubQuery;
   a, b, c: TExternalLoggerDefinition;
begin
   BeginTest('Rows: the state is DeriveExternalLoggerState over the program''s answer');
   config := TExternalLoggerConfig.Create;
   rows := TLoggerStatusRows.Create(True);
   stub := TStubQuery.Create;
   try
      a := NewDefinition(config, 'id-a', 'Alpha', 'CLOUDLOG');
      b := NewDefinition(config, 'id-b', 'Bravo', 'WRL');
      c := NewDefinition(config, 'id-c', 'Charlie', 'CLUBLOG');
      config.SetActive(a.Id, True);
      config.SetActive(c.Id, True);
      (* Alpha runs and is paused on a plain-http refusal; Charlie is not running
         (added since start); Bravo is off and not running. *)
      stub.KnownId := a.DeliveryId;
      stub.Snapshot.Active := True;
      stub.Snapshot.Halted := True;
      stub.Snapshot.Code := 'CLOUDLOG_INSECURE_URL_REFUSED';
      BuildLoggerStatusRows(config, stub.Query, rows);
      CheckTrue(rows[0].State = elsPaused, 'Alpha: paused');
      CheckEquals(UnicodeFormat(SLoggerStatePaused, [SLoggerWhyInsecure]), rows[0].StateText,
         'in words, so no one reads the log to learn why');
      CheckTrue(rows[1].State = elsRestartNeeded, 'Charlie: on, not running: restart');
      CheckEquals(SLoggerStateRestart, rows[1].StateText);
      CheckTrue(rows[2].State = elsDisabled, 'Bravo: off');
      CheckEquals(SLoggerStateDisabled, rows[2].StateText);
   finally
      stub.Free;
      rows.Free;
      config.Free;
   end;
end;

procedure TExternalLoggerStatusModelTests.Test_NoQueryMeansNotRunning;
var
   config: TExternalLoggerConfig;
   rows: TLoggerStatusRows;
   a: TExternalLoggerDefinition;
begin
   BeginTest('Rows: with no query nothing is running (an enabled logger reads restart)');
   config := TExternalLoggerConfig.Create;
   rows := TLoggerStatusRows.Create(True);
   try
      a := NewDefinition(config, 'id-a', 'Alpha', 'CLOUDLOG');
      config.SetActive(a.Id, True);
      BuildLoggerStatusRows(config, nil, rows);
      CheckEquals(1, rows.Count);
      CheckTrue(rows[0].State = elsRestartNeeded);
   finally
      rows.Free;
      config.Free;
   end;
end;

procedure TExternalLoggerStatusModelTests.Test_NilConfigIsAnEmptyList;
var
   rows: TLoggerStatusRows;
begin
   BeginTest('Rows: no configuration (the settings file could not be read) is an empty list, and an old list is cleared');
   rows := TLoggerStatusRows.Create(True);
   try
      rows.Add(TLoggerStatusRow.Create);
      BuildLoggerStatusRows(nil, nil, rows);
      CheckEquals(0, rows.Count);
   finally
      rows.Free;
   end;
end;

procedure TExternalLoggerStatusModelTests.Test_ResyncPreflight;
var
   state: TExternalLoggerState;
begin
   BeginTest('Resync preflight: off, not running and not applied are refused with their reason; every running state may go on');
   CheckTrue(ResyncPreflight(elsDisabled) = rpSwitchedOff);
   CheckTrue(ResyncPreflight(elsRestartNeeded) = rpNotRunning);
   CheckTrue(ResyncPreflight(elsApplyOnSave) = rpNotActive);
   for state in [elsIdle, elsSending, elsRetrying, elsPaused, elsFailed] do
      begin
      CheckTrue(ResyncPreflight(state) = rpOk, 'a running logger may be resynced (the service refuses with its own reason)');
      end;
end;

procedure TExternalLoggerStatusModelTests.Test_ResyncButtonNeedsASelection;
begin
   BeginTest('Resync button: enabled with a selected logger, never without one');
   CheckTrue(LoggerStatusCanResync('id-a'));
   CheckFalse(LoggerStatusCanResync(''));
end;

(* THE WINDOW'S SLOT, MENU ID AND SAVED-POSITION NAME. The menu id is derived
   from the ordinal (SetMenuChecked(10199 + Ord(ID)), the windows-menu dispatch's
   range guard), so a slot that moves without its id moves the check mark onto a
   different window. The window is the LAST real one: every "to
   tw_..._INDEX" loop ends at it, and tw_Dummy11 must stay beyond it. *)
procedure TExternalLoggerStatusModelTests.Test_WindowSlotAndMenuIdAgree;
begin
   BeginTest('Window slot: menu id = 10199 + ordinal, a saved-position name of its own, and the last real window');
   CheckEquals(10199 + Ord(tw_EXTLOGGERSWINDOW_INDEX), menu_windows_externalloggers);
   CheckEquals(10199 + Ord(tw_HAMSCOREWINDOW_INDEX), menu_windows_hamscore, 'HamScore did not move');
   CheckEquals('ExternalLoggers', WindowNames[tw_EXTLOGGERSWINDOW_INDEX]);
   CheckTrue(Succ(tw_EXTLOGGERSWINDOW_INDEX) = tw_Dummy11, 'tw_Dummy11 stays beyond the last window');
   CheckTrue(Succ(tw_HAMSCOREWINDOW_INDEX) = tw_EXTLOGGERSWINDOW_INDEX);
end;

procedure TExternalLoggerStatusModelTests.RunAllTests;
begin
   Test_StateTextForEveryState;
   Test_StateTextShowsWordsForAKnownCode;
   Test_StateTextAppendsOldCounts;
   Test_RowsFollowTheDisplayOrder;
   Test_RowsTakeTheirStateFromTheQuery;
   Test_NoQueryMeansNotRunning;
   Test_NilConfigIsAnEmptyList;
   Test_ResyncPreflight;
   Test_ResyncButtonNeedsASelection;
   Test_WindowSlotAndMenuIdAgree;
end;

end.

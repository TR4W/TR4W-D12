unit uTestExternalLoggerActions;
{$I ..\..\src\tr4w.inc}
(*
  THE DECISIONS BEHIND THE RESEND AND OPEN SITE BUTTONS, AND THE WRL LOGBOOK
  NAME (issues 356, 358) -- uExternalLoggerActions, pure, no database.

  The resend verdict table is pinned row by row, because a wrong row either
  loses a contact (a skipped create) or duplicates one (a replayed uncertain
  create, a second create where only an update is possible).
*)

interface

uses
   SysUtils, uTR4WTestFramework, uExternalLoggerActions, uExternalLoggerConfig,
   uJSON, uKeychain;

type
   TExternalLoggerActionsTests = class(TTestCase)
   protected
      procedure Test_NoRowIsCreatedInBothModes;
      procedure Test_QueuedWorkIsNeverTouched;
      procedure Test_UncertainIsNeverReplayed;
      procedure Test_AnUnknownStateIsTreatedAsUncertain;
      procedure Test_FailedCreateIsQueuedAgain;
      procedure Test_FailedUpdateOnlyForResendAll;
      procedure Test_SyncedOnlyForResendAllAndOnlyWhereItCanUpdate;
      procedure Test_TheTallyCountsEveryVerdict;
      procedure Test_SiteUrlAcceptsOnlyHttpAndHttps;
      procedure Test_SiteUrlRefusesOddShapes;
      procedure Test_DefaultAndEffectiveSiteUrl;
      procedure Test_SiteUrlRoundTripsAndOldFilesLoadEmpty;
      procedure Test_WRLLogbookName;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TExternalLoggerActionsTests.Test_NoRowIsCreatedInBothModes;
begin
   BeginTest('Resend: a QSO with no delivery row is created, in either mode');
   CheckTrue(ResendVerdict(rmUndelivered, False, '', False, True) = rvCreate);
   CheckTrue(ResendVerdict(rmAll, False, '', False, True) = rvCreate);
   CheckTrue(ResendVerdict(rmUndelivered, False, '', False, False) = rvCreate,
      'a provider that cannot update still takes a first create');
end;

procedure TExternalLoggerActionsTests.Test_QueuedWorkIsNeverTouched;
begin
   BeginTest('Resend: pending and inflight rows are left alone');
   CheckTrue(ResendVerdict(rmAll, True, 'pending', False, True) = rvQueued);
   CheckTrue(ResendVerdict(rmAll, True, 'inflight', True, True) = rvQueued);
   CheckTrue(ResendVerdict(rmUndelivered, True, 'pending', False, True) = rvQueued);
end;

procedure TExternalLoggerActionsTests.Test_UncertainIsNeverReplayed;
begin
   BeginTest('Resend: an uncertain row is never replayed, whatever the mode');
   CheckTrue(ResendVerdict(rmUndelivered, True, 'uncertain', False, True) = rvUncertain);
   CheckTrue(ResendVerdict(rmAll, True, 'uncertain', False, True) = rvUncertain);
   CheckTrue(ResendVerdict(rmAll, True, 'uncertain', True, True) = rvUncertain);
end;

procedure TExternalLoggerActionsTests.Test_AnUnknownStateIsTreatedAsUncertain;
begin
   BeginTest('Resend: a state this code does not know is the safe reading');
   CheckTrue(ResendVerdict(rmAll, True, 'frobnicated', True, True) = rvUncertain);
   CheckTrue(ResendVerdict(rmAll, True, '', False, True) = rvUncertain);
end;

procedure TExternalLoggerActionsTests.Test_FailedCreateIsQueuedAgain;
begin
   BeginTest('Resend: a failed create (no remote id) is not delivered, so both modes queue it');
   CheckTrue(ResendVerdict(rmUndelivered, True, 'failed', False, True) = rvRequeue);
   CheckTrue(ResendVerdict(rmAll, True, 'failed', False, True) = rvRequeue);
   CheckTrue(ResendVerdict(rmUndelivered, True, 'failed', False, False) = rvRequeue);
end;

procedure TExternalLoggerActionsTests.Test_FailedUpdateOnlyForResendAll;
begin
   BeginTest('Resend: a failed edit or delete of a delivered contact is delivered, not undelivered');
   CheckTrue(ResendVerdict(rmUndelivered, True, 'failed', True, True) = rvDelivered);
   CheckTrue(ResendVerdict(rmAll, True, 'failed', True, True) = rvRequeue);
   CheckTrue(ResendVerdict(rmAll, True, 'failed', True, False) = rvDelivered,
      'Cloudlog / AC Log: its edit failure is not retried by a resend');
end;

procedure TExternalLoggerActionsTests.Test_SyncedOnlyForResendAllAndOnlyWhereItCanUpdate;
begin
   BeginTest('Resend: a synced contact is sent again only by Resend all, as an update');
   CheckTrue(ResendVerdict(rmUndelivered, True, 'synced', True, True) = rvDelivered);
   CheckTrue(ResendVerdict(rmAll, True, 'synced', True, True) = rvRequeue);
   BeginTest('Resend: ... and never created a second time where no update exists');
   CheckTrue(ResendVerdict(rmAll, True, 'synced', True, False) = rvDelivered);
   BeginTest('Resend: ... nor when it has no remote contact to update');
   CheckTrue(ResendVerdict(rmAll, True, 'synced', False, True) = rvDelivered);
end;

procedure TExternalLoggerActionsTests.Test_TheTallyCountsEveryVerdict;
var
   tally: TResendTally;
   v: TResendVerdict;
begin
   BeginTest('Resend: the tally adds every verdict to its own counter');
   tally := TResendTally.Create;
   try
      for v := Low(TResendVerdict) to High(TResendVerdict) do
         begin
         tally.Add(v);
         end;
      tally.Add(rvCreate);
      CheckEquals(2, tally.Created);
      CheckEquals(1, tally.Requeued);
      CheckEquals(1, tally.AlreadyQueued);
      CheckEquals(1, tally.Uncertain);
      CheckEquals(1, tally.Delivered);
      CheckEquals(1, tally.NotOurs);
      CheckEquals(3, tally.Queued, 'queued = created + requeued');
      CheckEquals(7, tally.Total);
   finally
      tally.Free;
   end;
end;

procedure TExternalLoggerActionsTests.Test_SiteUrlAcceptsOnlyHttpAndHttps;
begin
   BeginTest('Site URL: http and https with a host are accepted, any case');
   CheckTrue(CheckSiteUrl('https://clublog.org') = supNone);
   CheckTrue(CheckSiteUrl('http://example.org/path?x=1') = supNone);
   CheckTrue(CheckSiteUrl('HTTPS://Example.ORG') = supNone);
   CheckTrue(CheckSiteUrl('https://192.168.1.5:8080/index.php') = supNone);
   BeginTest('Site URL: other schemes are refused');
   CheckTrue(CheckSiteUrl('file:///c:/windows/system32/calc.exe') = supScheme);
   CheckTrue(CheckSiteUrl('javascript:alert(1)') = supScheme);
   CheckTrue(CheckSiteUrl('ftp://example.org') = supScheme);
   CheckTrue(CheckSiteUrl('mailto:someone@example.org') = supScheme);
   CheckTrue(CheckSiteUrl('clublog.org') = supScheme, 'no scheme at all');
end;

procedure TExternalLoggerActionsTests.Test_SiteUrlRefusesOddShapes;
begin
   BeginTest('Site URL: empty, blank, spaces, controls, no host and credentials are refused');
   CheckTrue(CheckSiteUrl('') = supEmpty);
   CheckTrue(CheckSiteUrl('   ') = supEmpty);
   CheckTrue(CheckSiteUrl('https://exa mple.org') = supCharacters);
   CheckTrue(CheckSiteUrl('https://example.org'#10'calc') = supCharacters);
   CheckTrue(CheckSiteUrl('https://') = supHost);
   CheckTrue(CheckSiteUrl('https://user:secret@example.org') = supHost);
end;

procedure TExternalLoggerActionsTests.Test_DefaultAndEffectiveSiteUrl;
begin
   BeginTest('Site URL: the placeholder defaults (the owner replaces them)');
   CheckEquals('https://www.worldradioleague.com', DefaultSiteUrl('WRL'));
   CheckEquals('https://clublog.org', DefaultSiteUrl('CLUBLOG'));
   CheckEquals('', DefaultSiteUrl('DXKEEPER'));
   CheckEquals('', DefaultSiteUrl('ACLOG'));
   BeginTest('Site URL: the definition''s own value wins, trimmed');
   CheckEquals('https://wrl.example', EffectiveSiteUrl('WRL', ' https://wrl.example ', ''));
   BeginTest('Site URL: empty falls back to the provider default');
   CheckEquals('https://clublog.org', EffectiveSiteUrl('CLUBLOG', '', ''));
   BeginTest('Site URL: Cloudlog uses the address already entered');
   CheckEquals('https://log.example/index.php',
      EffectiveSiteUrl('CLOUDLOG', '', 'https://log.example/index.php'));
   BeginTest('Site URL: a TCP provider has none, even with an address');
   CheckEquals('', EffectiveSiteUrl('DXKEEPER', '', '127.0.0.1'));
end;

procedure TExternalLoggerActionsTests.Test_SiteUrlRoundTripsAndOldFilesLoadEmpty;
var
   source, loaded, copied: TExternalLoggerDefinition;
   json: TJSONObject;
begin
   InstallTestKeychain;
   source := TExternalLoggerDefinition.Create;
   loaded := TExternalLoggerDefinition.Create;
   copied := TExternalLoggerDefinition.Create;
   try
      source.Id := 'def-site';
      source.Name := 'Site';
      source.ProviderId := 'WRL';
      BeginTest('Site URL: a definition that never set one writes none and loads empty');
      json := source.ToJSON;
      try
         CheckTrue(json.GetValue('siteUrl') = nil, 'nothing written');
         loaded.SiteURL := 'stale';
         loaded.LoadJSON(json);
      finally
         json.Free;
      end;
      CheckEquals('', loaded.SiteURL);
      BeginTest('Site URL: a set value round-trips and Assign copies it');
      source.SiteURL := 'https://wrl.example';
      json := source.ToJSON;
      try
         loaded.LoadJSON(json);
      finally
         json.Free;
      end;
      CheckEquals('https://wrl.example', loaded.SiteURL);
      copied.Assign(loaded);
      CheckEquals('https://wrl.example', copied.SiteURL);
      BeginTest('Site URL: it is display only, in neither the fingerprint nor the stamp');
      CheckEquals(source.SettingsStamp, copied.SettingsStamp);
      source.SiteURL := '';
      CheckEquals(source.DestinationFingerprint, copied.DestinationFingerprint);
      CheckEquals(source.SettingsStamp, copied.SettingsStamp);
   finally
      copied.Free;
      loaded.Free;
      source.Free;
   end;
end;

procedure TExternalLoggerActionsTests.Test_WRLLogbookName;
begin
   BeginTest('WRL logbook name: YYYY, the ADIF contest id, then the mode');
   CheckEquals('2026 CQ-WW-SSB SSB', WRLDefaultLogbookName(2026, 'CQ-WW-SSB', ['SSB']));
   CheckEquals('2026 ARRL-DX-CW CW', WRLDefaultLogbookName(2026, 'ARRL-DX-CW', ['cw']));
   BeginTest('WRL logbook name: one mode repeated is still one mode');
   CheckEquals('2026 CQ-WW-RTTY RTTY',
      WRLDefaultLogbookName(2026, 'CQ-WW-RTTY', ['RTTY', ' rtty ', '']));
   BeginTest('WRL logbook name: several modes, or none, are MIXED');
   CheckEquals('2027 ARRL-FIELD-DAY MIXED',
      WRLDefaultLogbookName(2027, 'ARRL-FIELD-DAY', ['CW', 'SSB']));
   CheckEquals('2027 ARRL-FIELD-DAY MIXED',
      WRLDefaultLogbookName(2027, 'ARRL-FIELD-DAY', []));
   BeginTest('WRL logbook name: a contest that writes no id never leaves a double space');
   CheckEquals('2026 CW', WRLDefaultLogbookName(2026, '', ['CW']));
   CheckEquals('2026 CQ-WPX-CW CW', WRLDefaultLogbookName(2026, '  CQ-WPX-CW ', ['CW']));
end;

procedure TExternalLoggerActionsTests.RunAllTests;
begin
   Test_NoRowIsCreatedInBothModes;
   Test_QueuedWorkIsNeverTouched;
   Test_UncertainIsNeverReplayed;
   Test_AnUnknownStateIsTreatedAsUncertain;
   Test_FailedCreateIsQueuedAgain;
   Test_FailedUpdateOnlyForResendAll;
   Test_SyncedOnlyForResendAllAndOnlyWhereItCanUpdate;
   Test_TheTallyCountsEveryVerdict;
   Test_SiteUrlAcceptsOnlyHttpAndHttps;
   Test_SiteUrlRefusesOddShapes;
   Test_DefaultAndEffectiveSiteUrl;
   Test_SiteUrlRoundTripsAndOldFilesLoadEmpty;
   Test_WRLLogbookName;
end;

end.

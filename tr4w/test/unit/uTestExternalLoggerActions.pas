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
   SysUtils, fpjson, uTR4WTestFramework, uExternalLoggerActions, uExternalLoggerConfig,
   uJSON, uKeychain, uWRLClient;

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
      procedure Test_WRLCreateLogbookBody;
      procedure Test_WRLDecodeCreateLogbook;
      procedure Test_WRLCreateLogbookText;
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
      CheckEquals(1, tally.NotDeliverable);
      CheckEquals(3, tally.Queued, 'queued = created + requeued');
      CheckEquals(8, tally.Total);
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

(* ISSUE 358: POST /logbooks. The body, the envelope decode and the words the
   operator reads, all pure: no network, no thread. *)
procedure TExternalLoggerActionsTests.Test_WRLCreateLogbookBody;
var
   body, code: string;
   json: TJSONData;
   i: integer;
   longName: string;
begin
   BeginTest('Create logbook body: the name and the station call, nothing else');
   CheckTrue(WRLCreateLogbookBody('2026 CQ-WW-SSB SSB', 'K1ABC', body, code));
   json := GetJSON(UTF8Encode(body));
   try
      CheckEquals(2, json.Count, 'only name and defaultCallSign');
      CheckEquals('2026 CQ-WW-SSB SSB', UTF8Decode(TJSONObject(json).Get('name', '')));
      CheckEquals('K1ABC', UTF8Decode(TJSONObject(json).Get('defaultCallSign', '')));
   finally
      json.Free;
   end;
   BeginTest('Create logbook body: no call, or one over 20 characters, is left out');
   CheckTrue(WRLCreateLogbookBody('Name', '', body, code));
   CheckEquals(0, Pos('defaultCallSign', body));
   CheckTrue(WRLCreateLogbookBody('Name', '123456789012345678901', body, code));
   CheckEquals(0, Pos('defaultCallSign', body));
   CheckTrue(WRLCreateLogbookBody('Name', '12345678901234567890', body, code));
   CheckTrue(Pos('defaultCallSign', body) > 0, 'exactly 20 is allowed');
   BeginTest('Create logbook body: quotes, a backslash and accents survive the JSON');
   CheckTrue(WRLCreateLogbookBody('A "B" \ C' + #$00E9, 'K1ABC', body, code));
   json := GetJSON(UTF8Encode(body));
   try
      CheckEquals('A "B" \ C' + #$00E9, UTF8Decode(TJSONObject(json).Get('name', '')));
   finally
      json.Free;
   end;
   BeginTest('Create logbook body: the name is trimmed and capped at 100');
   CheckTrue(WRLCreateLogbookBody('  x  ', '', body, code));
   json := GetJSON(UTF8Encode(body));
   try
      CheckEquals('x', UTF8Decode(TJSONObject(json).Get('name', '')));
   finally
      json.Free;
   end;
   longName := '';
   for i := 1 to 100 do
      begin
      longName := longName + 'n';
      end;
   CheckTrue(WRLCreateLogbookBody(longName, '', body, code), '100 is allowed');
   CheckFalse(WRLCreateLogbookBody(longName + 'n', '', body, code), '101 is refused');
   CheckEquals('NAME_TOO_LONG', code);
   CheckEquals('', body, 'nothing to send');
   CheckFalse(WRLCreateLogbookBody('   ', 'K1ABC', body, code));
   CheckEquals('NAME_REQUIRED', code);
end;

procedure TExternalLoggerActionsTests.Test_WRLDecodeCreateLogbook;
const
   KEY = 'wrl_live_secretkey';
   ID = '3f2c1a9e-0b1d-4c55-9a7e-1234567890ab';
var
   r: TWRLCreateLogbookResult;
begin
   BeginTest('Create logbook decode: a 201 with data.id is a success');
   r := WRLDecodeCreateLogbook(201, '{"data":{"id":"' + ID + '","name":"2026 X CW",' +
      '"description":null,"defaultCallSign":"K1ABC","isLocked":null,' +
      '"createdAt":"2026-11-22T00:00:00Z","updatedAt":null},"meta":null,"error":null}', KEY);
   CheckTrue(r.Ok);
   CheckFalse(r.Uncertain);
   CheckEquals(ID, r.LogbookId);
   CheckEquals('2026 X CW', r.Name);
   CheckEquals(201, r.Status);
   BeginTest('Create logbook decode: a validation error carries code, field, hint and request id');
   r := WRLDecodeCreateLogbook(400, '{"data":null,"error":{"code":"VALIDATION_ERROR",' +
      '"message":"name is too long","field":"name","hint":"Use 100 or fewer.",' +
      '"requestId":"req_123"}}', KEY);
   CheckFalse(r.Ok);
   CheckFalse(r.Uncertain, 'a 4xx never created anything');
   CheckEquals('VALIDATION_ERROR', r.ErrorCode);
   CheckEquals('name is too long', r.ErrorMessage);
   CheckEquals('name', r.ErrorField);
   CheckEquals('Use 100 or fewer.', r.ErrorHint);
   CheckEquals('req_123', r.RequestId);
   BeginTest('Create logbook decode: branch on the code, key problems and conflicts');
   r := WRLDecodeCreateLogbook(401, '{"data":null,"error":{"code":"INVALID_KEY","message":"x"}}', KEY);
   CheckEquals('INVALID_KEY', r.ErrorCode);
   r := WRLDecodeCreateLogbook(409, '{"data":null,"error":{"code":"CONFLICT","message":"x"}}', KEY);
   CheckEquals('CONFLICT', r.ErrorCode);
   CheckFalse(r.Uncertain);
   r := WRLDecodeCreateLogbook(401, '{"data":null,"error":null}', KEY);
   CheckEquals('HTTP_401', r.ErrorCode, 'no error object: the status names it');
   r := WRLDecodeCreateLogbook(429, '{"data":null,"error":{"message":"slow down"}}', KEY);
   CheckEquals('RATE_LIMITED', r.ErrorCode, 'a 429 with no code is still rate limiting');
   BeginTest('Create logbook decode: what may have been created is Uncertain');
   r := WRLDecodeCreateLogbook(500, '{"data":null,"error":{"code":"INTERNAL_ERROR","message":"x"}}', KEY);
   CheckTrue(r.Uncertain, '5xx');
   r := WRLDecodeCreateLogbook(201, 'this is not json', KEY);
   CheckFalse(r.Ok);
   CheckTrue(r.Uncertain, 'a 2xx we cannot read');
   CheckEquals('INVALID_RESPONSE', r.ErrorCode);
   r := WRLDecodeCreateLogbook(201, '{"data":{"name":"x"},"meta":null,"error":null}', KEY);
   CheckFalse(r.Ok);
   CheckTrue(r.Uncertain, 'a 2xx with no data.id');
   CheckEquals('MISSING_LOGBOOK_ID', r.ErrorCode);
   r := WRLDecodeCreateLogbook(201, '{"data":{"id":"a/../b"},"meta":null,"error":null}', KEY);
   CheckFalse(r.Ok, 'an id that is not a UUID is never stored');
   CheckEquals('INVALID_LOGBOOK_ID', r.ErrorCode);
   r := WRLDecodeCreateLogbook(400, 'plain text, not json', KEY);
   CheckEquals('INVALID_RESPONSE', r.ErrorCode);
   CheckFalse(r.Uncertain);
   r := WRLDecodeCreateLogbook(201, '[1,2]', KEY);
   CheckEquals('INVALID_RESPONSE', r.ErrorCode, 'not an envelope');
   BeginTest('Create logbook decode: a server text that echoes the key is dropped');
   r := WRLDecodeCreateLogbook(400, '{"data":null,"error":{"code":"VALIDATION_ERROR",' +
      '"message":"bad ' + KEY + '","hint":"' + KEY + '"}}', KEY);
   CheckEquals('', r.ErrorMessage);
   CheckEquals('', r.ErrorHint);
end;

procedure TExternalLoggerActionsTests.Test_WRLCreateLogbookText;
var
   r: TWRLCreateLogbookResult;
   a, b: string;
begin
   BeginTest('Create logbook text: each family of code reads differently, never the key');
   r := Default(TWRLCreateLogbookResult);
   r.ErrorCode := 'INVALID_KEY';
   a := WRLCreateLogbookText(r);
   CheckTrue(a <> '');
   r.ErrorCode := 'KEY_REVOKED';
   CheckEquals(a, WRLCreateLogbookText(r), 'the key problems share one answer');
   r.ErrorCode := 'CONFLICT';
   b := WRLCreateLogbookText(r);
   CheckTrue(b <> a);
   r.ErrorCode := 'LOGBOOK_NOT_EMPTY';
   CheckEquals(b, WRLCreateLogbookText(r), 'a name that already exists');
   r.ErrorCode := 'RATE_LIMITED';
   CheckTrue(WRLCreateLogbookText(r) <> b);
   r.ErrorCode := 'VALIDATION_ERROR';
   r.ErrorField := 'defaultCallSign';
   r.ErrorMessage := 'too long';
   CheckTrue(Pos('defaultCallSign', WRLCreateLogbookText(r)) > 0, 'the field is named');
   r.ErrorHint := 'Shorten it.';
   CheckTrue(Pos('Shorten it.', WRLCreateLogbookText(r)) > 0, 'the hint is shown');
   r.RequestId := 'req_9';
   CheckTrue(Pos('req_9', WRLCreateLogbookText(r)) > 0, 'the request id is shown');
   BeginTest('Create logbook text: an uncertain answer says look before trying again');
   r := Default(TWRLCreateLogbookResult);
   r.Uncertain := True;
   r.ErrorCode := 'DELIVERY_UNCONFIRMED';
   CheckTrue(WRLCreateLogbookText(r) <> '');
   r.ErrorCode := 'SOMETHING_NEW';
   r.Uncertain := False;
   CheckTrue(Pos('SOMETHING_NEW', WRLCreateLogbookText(r)) > 0, 'an unknown code is shown');
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
   Test_WRLCreateLogbookBody;
   Test_WRLDecodeCreateLogbook;
   Test_WRLCreateLogbookText;
end;

end.

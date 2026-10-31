unit uTestKeychain;
{$I tr4w.inc}

(*
  THE KEYCHAIN.

  EVERY TEST RUNS AGAINST AN IN-MEMORY VAULT. Nothing here touches the
  machine's Credential Manager -- a suite that did would depend on the
  developer's machine and could leave entries behind on it.

  WHAT IS WORTH PINNING, and each is a defect that would otherwise reach an
  operator quietly:

    * clearing a password must REMOVE it, or an operator who deleted one
      would still find it in Control Panel afterwards;
    * an absent or revoked secret must be REFUSED, never half-read, or a
      settings file from another machine sends rubbish to a server;
    * and with no vault the value must NOT be written somewhere weaker --
      it is reported and kept for the session only.

  THE FILE FORMAT IS TESTED WHERE IT IS WRITTEN, in the settings model: the
  reference goes in its own `<Name>Ref` member and the value member is
  removed. This unit is about the vault itself.
*)

interface

uses
   uTR4WTestFramework;

type
   TKeychainTests = class(TTestCase)
   protected
      procedure TestRoundTrip;
      procedure TestMixedCaseSurvives;
      procedure TestNonAsciiSurvives;
      procedure TestStoringAgainReplaces;
      procedure TestCaseOfTheNameDoesNotMatter;
      procedure TestALockedVaultIsReportedAsLocked;
      procedure TestClearingRemovesItFromTheVault;
      procedure TestAMissingSecretIsRefusedNotGuessed;
      procedure TestForgetRemovesWithoutStoring;
      procedure TestNoVaultIsReportedAndNotDowngraded;
      procedure TestTheValueIsNeverInTheNotice;
      procedure TestAvailabilityIsAnswerable;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   uKeychain;

const
   SECRET_NAME = 'Hamscore.Password';

(*
  A VAULT THAT IS NOT THERE -- a locked keyring, a platform with no store, a
  policy that forbids credential storage.
*)
type
   TUnavailableKeychain = class(TKeychainBackend)
   public
      function Name: string; override;
      function Available: boolean; override;
      function WriteSecret(const aName, aValue: string): TKeychainStatus;
         override;
      function ReadSecret(const aName: string;
                          out aValue: string): TKeychainStatus; override;
      function DeleteSecret(const aName: string): TKeychainStatus; override;
   end;

function TUnavailableKeychain.Name: string;
begin
   (* The same name as the test vault, so installing this REPLACES it rather
     than sitting beside it. *)
   Result := 'memory1';
end;

function TUnavailableKeychain.Available: boolean;
begin
   Result := False;
end;

function TUnavailableKeychain.WriteSecret(const aName,
                                          aValue: string): TKeychainStatus;
begin
   Result := ksUnavailable;
end;

function TUnavailableKeychain.ReadSecret(const aName: string;
                                         out aValue: string): TKeychainStatus;
begin
   aValue := '';
   Result := ksUnavailable;
end;

function TUnavailableKeychain.DeleteSecret(const aName: string): TKeychainStatus;
begin
   Result := ksUnavailable;
end;

(*
  A VAULT THAT IS THERE BUT LOCKED -- a macOS keychain or a Secret Service
  collection whose unlock prompt the operator dismissed. Available answers
  True, as both real backends do: "is there a vault" must not prompt.
*)
type
   TLockedKeychain = class(TKeychainBackend)
   public
      function Name: string; override;
      function Available: boolean; override;
      function WriteSecret(const aName, aValue: string): TKeychainStatus;
         override;
      function ReadSecret(const aName: string;
                          out aValue: string): TKeychainStatus; override;
      function DeleteSecret(const aName: string): TKeychainStatus; override;
   end;

function TLockedKeychain.Name: string;
begin
   Result := 'memory1';
end;

function TLockedKeychain.Available: boolean;
begin
   Result := True;
end;

function TLockedKeychain.WriteSecret(const aName,
                                     aValue: string): TKeychainStatus;
begin
   Result := ksLocked;
end;

function TLockedKeychain.ReadSecret(const aName: string;
                                    out aValue: string): TKeychainStatus;
begin
   aValue := '';
   Result := ksLocked;
end;

function TLockedKeychain.DeleteSecret(const aName: string): TKeychainStatus;
begin
   Result := ksLocked;
end;

var
   GNoticeCount: integer = 0;
   GLastNoticeName: string = '';
   GLastNoticeText: string = '';

procedure RecordNotice(const aName, aMessage: string);
begin
   Inc(GNoticeCount);
   GLastNoticeName := aName;
   GLastNoticeText := aMessage;
end;

procedure TKeychainTests.TestRoundTrip;
var
   back: string;
begin
   BeginTest('a secret survives the trip to the vault and back');
   InstallTestKeychain;

   CheckTrue(StoreSecret(SECRET_NAME, 'Hunter2'), 'it stores');
   CheckTrue(FetchSecret(SECRET_NAME, back), 'it reads back');
   CheckEquals('Hunter2', back, 'and it is what went in');
end;

procedure TKeychainTests.TestMixedCaseSurvives;
var
   back: string;
begin
   (* THE CASE QUESTION IS WHY THIS WORK STARTED. The legacy ini parser
     upper-cased whole lines, so a password came back shouting. A value that
     goes through here must not acquire that behaviour. *)
   BeginTest('case is not touched');
   InstallTestKeychain;
   CheckTrue(StoreSecret(SECRET_NAME, 'MiXeD-CaSe-Pw'), 'stored');
   CheckTrue(FetchSecret(SECRET_NAME, back), 'read back');
   CheckEquals('MiXeD-CaSe-Pw', back, 'exactly as typed');
end;

procedure TKeychainTests.TestStoringAgainReplaces;
var
   back: string;
begin
   (* EVERY SAVE STORES AGAIN. A backend that added a second entry, or kept
     the first, would hand back a password the operator has since changed.
     The macOS backend updates first for exactly this reason. *)
   BeginTest('storing a secret again replaces the old value');
   InstallTestKeychain;

   CheckTrue(StoreSecret(SECRET_NAME, 'first'), 'the first value stores');
   CheckTrue(StoreSecret(SECRET_NAME, 'second'), 'the second value stores');
   CheckTrue(FetchSecret(SECRET_NAME, back), 'it reads back');
   CheckEquals('second', back, 'and it is the newer value');
end;

procedure TKeychainTests.TestCaseOfTheNameDoesNotMatter;
var
   back: string;
begin
   (* EVERY BACKEND FOLDS THE NAME. Windows does it itself; macOS and Linux
     upper-case the account so the three agree. The test vault pins the
     same contract. *)
   BeginTest('the name of a secret is not case-sensitive');
   InstallTestKeychain;

   CheckTrue(StoreSecret('Wrl.ApiKey', 'k1'), 'stored under one spelling');
   CheckTrue(FetchSecret('WRL.APIKEY', back), 'read under another');
   CheckEquals('k1', back, 'and it is the same secret');
end;

procedure TKeychainTests.TestALockedVaultIsReportedAsLocked;
var
   back: string;
begin
   (* NY4I: A LOCKED VAULT IS REPORTED AS A LOCKED VAULT, not as a missing
     one and not by quietly storing somewhere weaker. The operator can fix
     "locked"; the log has to say which it was. *)
   BeginTest('a locked vault is reported as locked, and nothing is stored');

   GNoticeCount := 0;
   GLastNoticeText := '';
   SetKeychainNotice(@RecordNotice);
   RegisterKeychainBackend(TLockedKeychain.Create);
   try
      CheckFalse(StoreSecret(SECRET_NAME, 'Hunter2'), 'nothing is stored');
      CheckEquals(1, GNoticeCount, 'it is reported once');
      CheckTrue(Pos('locked', GLastNoticeText) > 0, 'and the notice says locked');
      CheckTrue(Pos('Hunter2', GLastNoticeText) = 0,
                'and does not carry the value');

      CheckFalse(FetchSecret(SECRET_NAME, back), 'a read is refused');
      CheckEquals('', back, 'with nothing handed back');
      CheckTrue(Pos('locked', GLastNoticeText) > 0, 'and that says locked too');
   finally
      SetKeychainNotice(nil);
      InstallTestKeychain;
   end;
end;

procedure TKeychainTests.TestNonAsciiSurvives;
var
   back: string;
begin
   BeginTest('a non-ASCII password survives');
   InstallTestKeychain;
   CheckTrue(StoreSecret(SECRET_NAME, 'pa' + Chr($DF) + 'wort'), 'stored');
   CheckTrue(FetchSecret(SECRET_NAME, back), 'read back');
   CheckEquals('pa' + Chr($DF) + 'wort', back, 'unchanged');
end;

procedure TKeychainTests.TestClearingRemovesItFromTheVault;
var
   back: string;
begin
   (* A REAL DEFECT UNTIL THIS EXISTED. Clearing a password used to write an
     empty value and leave the old one in the vault, where the operator who
     had just deleted it could still find it. *)
   BeginTest('clearing a password removes it, it does not merely hide it');
   InstallTestKeychain;

   CheckTrue(StoreSecret(SECRET_NAME, 'Hunter2'), 'stored to begin with');
   CheckTrue(FetchSecret(SECRET_NAME, back), 'and readable');

   (* An empty value is the instruction to remove. It answers False because
     nothing was stored, which is the caller's signal to write no
     reference. *)
   CheckFalse(StoreSecret(SECRET_NAME, ''), 'clearing stores nothing');
   CheckFalse(FetchSecret(SECRET_NAME, back), 'and the vault no longer has it');
   CheckEquals('', back, 'with nothing handed back');
end;

procedure TKeychainTests.TestAMissingSecretIsRefusedNotGuessed;
var
   back: string;
begin
   (* A SETTINGS FILE FROM ANOTHER MACHINE, or a credential the operator
     revoked in Control Panel. Either way the answer is "ask again", never a
     half-read value that would be sent to a server. *)
   BeginTest('a secret that is not there is refused');
   InstallTestKeychain;
   CheckFalse(FetchSecret('Nothing.Stored.Here', back), 'refused');
   CheckEquals('', back, 'and nothing handed back');
end;

procedure TKeychainTests.TestForgetRemovesWithoutStoring;
var
   back: string;
begin
   BeginTest('a secret can be removed without storing another');
   InstallTestKeychain;

   CheckTrue(StoreSecret(SECRET_NAME, 'Hunter2'), 'stored');
   CheckTrue(ForgetSecret(SECRET_NAME), 'removed');
   CheckFalse(FetchSecret(SECRET_NAME, back), 'and it is gone');

   (* Removing something already absent is a no-op, not a fault -- otherwise
     clearing a password twice would report an error the second time. *)
   CheckTrue(ForgetSecret(SECRET_NAME), 'removing it again is not an error');
end;

procedure TKeychainTests.TestNoVaultIsReportedAndNotDowngraded;
begin
   (*
     THE RULE THIS UNIT WAS REBUILT AROUND (NY4I): a store that is
     unavailable is a reason to SAY SO, not a reason to write the password
     somewhere weaker.

     An earlier version kept a cipher and a key file for this case. That is
     deleted -- so what has to be pinned is that nothing takes its place.
   *)
   BeginTest('with no vault the secret is reported, not written weaker');

   GNoticeCount := 0;
   GLastNoticeName := '';
   SetKeychainNotice(@RecordNotice);
   RegisterKeychainBackend(TUnavailableKeychain.Create);
   try
      CheckFalse(KeychainAvailable, 'the vault is not available');
      CheckFalse(StoreSecret(SECRET_NAME, 'Hunter2'), 'and nothing is stored');
      CheckEquals(1, GNoticeCount, 'it is reported exactly once');
      CheckEquals(SECRET_NAME, GLastNoticeName, 'naming the setting');
   finally
      SetKeychainNotice(nil);
      (* Put a working vault back, or every later test inherits this one. *)
      InstallTestKeychain;
   end;
end;

procedure TKeychainTests.TestTheValueIsNeverInTheNotice;
begin
   (* THE ONE RULE THAT IS ABSOLUTE. A notice goes to the log, and a log is
     copied into bug reports and pasted into chat. Whatever else a message
     says, it must not say the password. *)
   BeginTest('a notice never carries the secret');

   GNoticeCount := 0;
   GLastNoticeText := '';
   SetKeychainNotice(@RecordNotice);
   RegisterKeychainBackend(TUnavailableKeychain.Create);
   try
      StoreSecret(SECRET_NAME, 'Hunter2');
      CheckTrue(GNoticeCount > 0, 'something was reported');
      CheckTrue(Pos('Hunter2', GLastNoticeText) = 0,
                'and the value is not in it');
   finally
      SetKeychainNotice(nil);
      InstallTestKeychain;
   end;
end;

procedure TKeychainTests.TestAvailabilityIsAnswerable;
begin
   (* A caller that has to explain why a password cannot be saved needs to
     be able to ask, rather than inferring it from a failure. *)
   BeginTest('whether there is a vault at all is answerable');
   InstallTestKeychain;
   CheckTrue(KeychainAvailable, 'the test vault is available');
   CheckEquals('memory1', ActiveKeychainName, 'and it names itself');
end;

procedure TKeychainTests.RunAllTests;
begin
   TestRoundTrip;
   TestMixedCaseSurvives;
   TestNonAsciiSurvives;
   TestStoringAgainReplaces;
   TestCaseOfTheNameDoesNotMatter;
   TestALockedVaultIsReportedAsLocked;
   TestClearingRemovesItFromTheVault;
   TestAMissingSecretIsRefusedNotGuessed;
   TestForgetRemovesWithoutStoring;
   TestNoVaultIsReportedAndNotDowngraded;
   TestTheValueIsNeverInTheNotice;
   TestAvailabilityIsAnswerable;
end;

end.

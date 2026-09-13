unit uTestKeychain;
{$I tr4w.inc}

(*
  THE KEYCHAIN.

  EVERY TEST RUNS AGAINST AN IN-MEMORY VAULT. Nothing here touches the
  machine's Credential Manager -- a suite that did would depend on the
  developer's machine and could leave entries behind on it.

  WHAT IS WORTH PINNING, and each is a defect that would otherwise reach an
  operator quietly:

    * the settings file must carry a REFERENCE and never the secret, which is
      the whole point of using a vault at all;
    * clearing a password must REMOVE it, or an operator who deleted one
      would still find it in Control Panel afterwards;
    * an untagged value must still read, or every existing tr4w.json loses
      its passwords the first time this code runs;
    * and with no vault the value must NOT be written somewhere weaker --
      it is reported and kept for the session only.
*)

interface

uses
   uTR4WTestFramework;

type
   TKeychainTests = class(TTestCase)
   protected
      procedure TestRoundTrip;
      procedure TestTheFileGetsAReferenceNotTheSecret;
      procedure TestMixedCaseSurvives;
      procedure TestNonAsciiSurvives;
      procedure TestClearingRemovesItFromTheVault;
      procedure TestUntaggedValueIsReadAsItself;
      procedure TestPlainTaggedValueIsRead;
      procedure TestAMissingSecretIsRefusedNotGuessed;
      procedure TestAnUnknownPrefixIsReadAsAPassword;
      procedure TestNoVaultIsReportedAndNotDowngraded;
      procedure TestTheValueIsNeverInTheNotice;
      procedure TestIsProtectedTellsTheTwoApart;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   uKeychain;

const
   NAME = 'Hamscore.Password';

(*
  A VAULT THAT IS NOT THERE -- a locked keyring, a platform with no store, a
  policy that forbids credential storage.
*)
type
   TUnavailableKeychain = class(TKeychainBackend)
   public
      function Scheme: string; override;
      function Available: boolean; override;
      function WriteSecret(const aName, aValue: string): TKeychainStatus;
         override;
      function ReadSecret(const aName: string;
                          out aValue: string): TKeychainStatus; override;
      function DeleteSecret(const aName: string): TKeychainStatus; override;
   end;

function TUnavailableKeychain.Scheme: string;
begin
   Result := 'memory1';   (* replaces the test vault, same tag *)
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
   stored: string;
   back: string;
begin
   BeginTest('a secret survives the trip to the vault and back');
   InstallTestKeychain;
   CheckTrue(KeychainAvailable, 'there is a vault');

   stored := ProtectSecret(NAME, 'Hunter2');
   CheckTrue(UnprotectSecret(NAME, stored, back), 'it reads back');
   CheckEquals('Hunter2', back, 'and it is what went in');
end;

procedure TKeychainTests.TestTheFileGetsAReferenceNotTheSecret;
var
   stored: string;
begin
   (* THE WHOLE POINT OF A VAULT. A settings file that is screen-shared,
     synced or attached to a bug report must carry no password -- not in the
     clear, and not enciphered either. *)
   BeginTest('the settings file gets a reference, never the secret');
   InstallTestKeychain;

   stored := ProtectSecret(NAME, 'Hunter2');
   CheckTrue(Pos('Hunter2', stored) = 0, 'the password is not in it');
   CheckTrue(IsProtectedSecret(stored), 'and it is marked as a reference');
   CheckTrue(Pos(NAME, stored) > 0, 'which names the setting');
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
   CheckTrue(UnprotectSecret(NAME, ProtectSecret(NAME, 'MiXeD-CaSe-Pw'), back),
             'it reads back');
   CheckEquals('MiXeD-CaSe-Pw', back, 'exactly as typed');
end;

procedure TKeychainTests.TestNonAsciiSurvives;
var
   back: string;
begin
   BeginTest('a non-ASCII password survives');
   InstallTestKeychain;
   CheckTrue(UnprotectSecret(NAME,
                             ProtectSecret(NAME, 'pa' + Chr($DF) + 'wort'),
                             back), 'it reads back');
   CheckEquals('pa' + Chr($DF) + 'wort', back, 'unchanged');
end;

procedure TKeychainTests.TestClearingRemovesItFromTheVault;
var
   stored: string;
   back: string;
begin
   (* A REAL DEFECT UNTIL THIS EXISTED. Clearing a password wrote an empty
     value and left the old one sitting in the vault, where an operator who
     had just deleted it could still find it. *)
   BeginTest('clearing a password removes it, it does not merely hide it');
   InstallTestKeychain;

   stored := ProtectSecret(NAME, 'Hunter2');
   CheckTrue(UnprotectSecret(NAME, stored, back), 'stored to begin with');

   CheckEquals('', ProtectSecret(NAME, ''), 'clearing writes nothing');

   (* The old reference must now find nothing, which is what proves the vault
     entry is gone rather than merely unreferenced. *)
   CheckFalse(UnprotectSecret(NAME, stored, back), 'and the vault is empty');
   CheckEquals('', back, 'with nothing handed back');
end;

procedure TKeychainTests.TestUntaggedValueIsReadAsItself;
var
   back: string;
begin
   (* EVERY EXISTING tr4w.json DEPENDS ON THIS. Passwords in it carry no tag,
     and reading one as itself is what stops this change emptying every
     operator's configuration on first run. The next save moves it into the
     vault. *)
   BeginTest('a value from before any of this is read as itself');
   InstallTestKeychain;
   CheckTrue(UnprotectSecret(NAME, 'LegacyPlainPw', back), 'it reads');
   CheckEquals('LegacyPlainPw', back, 'unchanged');

   (* AND A COLON DOES NOT MAKE A TAG. A stored URL, or a password with a
     colon in it, must not be taken for a scheme nobody ever wrote. *)
   CheckTrue(UnprotectSecret(NAME, 'http://example.test/x', back), 'reads');
   CheckEquals('http://example.test/x', back, 'a colon is not a scheme');
end;

procedure TKeychainTests.TestPlainTaggedValueIsRead;
var
   back: string;
begin
   BeginTest('a deliberately plain value is read');
   InstallTestKeychain;
   CheckTrue(UnprotectSecret(NAME, KEYCHAIN_SCHEME_PLAIN + ':Hunter2', back),
             'it reads');
   CheckEquals('Hunter2', back, 'as itself');
end;

procedure TKeychainTests.TestAMissingSecretIsRefusedNotGuessed;
var
   back: string;
begin
   (* A SETTINGS FILE FROM ANOTHER MACHINE, or a credential the operator
     revoked in Control Panel. Either way the answer is "ask again", never a
     half-read value that would be sent to a server. *)
   BeginTest('a reference with nothing behind it is refused');
   InstallTestKeychain;
   CheckFalse(UnprotectSecret(NAME, 'memory1:Nothing.Stored.Here', back),
              'refused');
   CheckEquals('', back, 'and nothing handed back');
end;

procedure TKeychainTests.TestAnUnknownPrefixIsReadAsAPassword;
var
   back: string;
begin
   (*
     AN AMBIGUITY THAT HAS TO BE DECIDED ONE WAY, and this test records which
     way and why. The first version of it asserted the opposite and was
     wrong.

     A stored value beginning with something:something could be either a
     reference written by a build with a vault this one does not have, OR a
     plain password that happens to contain a colon. The string cannot tell
     them apart.

     IT IS READ AS A PASSWORD, because only one of those two definitely
     exists. Operators have tr4w.json files with plain passwords in them
     today; a scheme from a future build is hypothetical. Guessing the other
     way would empty a real configuration to guard against a file nobody has.

     The cost is bounded and visible: if such a file ever arrives, its
     reference reaches a login as though it were the password, that login
     fails, and the operator retypes it. Nothing is lost.
   *)
   BeginTest('an unrecognised prefix is read as a password, not refused');
   InstallTestKeychain;
   CheckTrue(UnprotectSecret(NAME, 'martian9:whatever', back), 'it reads');
   CheckEquals('martian9:whatever', back, 'as itself, colon and all');

   (* A scheme this build DOES know, with nothing behind it, is a different
     case and is still refused -- see the test above. *)
end;

procedure TKeychainTests.TestNoVaultIsReportedAndNotDowngraded;
var
   stored: string;
begin
   (*
     THE RULE THIS UNIT WAS REBUILT AROUND (NY4I, 2026-09-13): a store that
     is unavailable is a reason to SAY SO, not a reason to write the password
     somewhere weaker.

     The earlier version kept a cipher and a key file for this case. That is
     deleted -- so what has to be pinned is that nothing takes its place.
   *)
   BeginTest('with no vault the secret is reported, not written weaker');

   GNoticeCount := 0;
   GLastNoticeText := '';
   SetKeychainNotice(@RecordNotice);
   RegisterKeychainBackend(TUnavailableKeychain.Create);
   try
      CheckFalse(KeychainAvailable, 'the vault is not available');

      stored := ProtectSecret(NAME, 'Hunter2');

      CheckEquals('', stored, 'nothing is written to the settings file');
      CheckEquals(1, GNoticeCount, 'and it is reported exactly once');
      CheckEquals(NAME, GLastNoticeName, 'naming the setting');
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
      ProtectSecret(NAME, 'Hunter2');
      CheckTrue(GNoticeCount > 0, 'something was reported');
      CheckTrue(Pos('Hunter2', GLastNoticeText) = 0,
                'and the value is not in it');
   finally
      SetKeychainNotice(nil);
      InstallTestKeychain;
   end;
end;

procedure TKeychainTests.TestIsProtectedTellsTheTwoApart;
var
   stored: string;
begin
   (* Lint-NoSecrets asks this of every tracked file, so a wrong answer here
     is a secret reference reaching the repository unnoticed. *)
   BeginTest('a reference is told apart from a bare password');
   InstallTestKeychain;

   stored := ProtectSecret(NAME, 'Hunter2');
   CheckTrue(IsProtectedSecret(stored), 'the reference');
   CheckFalse(IsProtectedSecret('Hunter2'), 'a bare password');
   CheckFalse(IsProtectedSecret(''), 'nothing at all');
   CheckFalse(IsProtectedSecret(KEYCHAIN_SCHEME_PLAIN + ':Hunter2'),
              'plain is tagged but is not a reference');
end;

procedure TKeychainTests.RunAllTests;
begin
   TestRoundTrip;
   TestTheFileGetsAReferenceNotTheSecret;
   TestMixedCaseSurvives;
   TestNonAsciiSurvives;
   TestClearingRemovesItFromTheVault;
   TestUntaggedValueIsReadAsItself;
   TestPlainTaggedValueIsRead;
   TestAMissingSecretIsRefusedNotGuessed;
   TestAnUnknownPrefixIsReadAsAPassword;
   TestNoVaultIsReportedAndNotDowngraded;
   TestTheValueIsNeverInTheNotice;
   TestIsProtectedTellsTheTwoApart;
end;

end.

unit uTestKeychain;
{$I tr4w.inc}

(*
  THE SECRET STORE.

  EVERY TEST HERE RUNS AGAINST A FIXED KEY HELD IN MEMORY. Nothing reads or
  writes settings\tr4w.key, and nothing touches the Windows Credential
  Manager -- a suite that did either would depend on the developer's machine
  and could leave something behind on it.

  WHAT IS WORTH PINNING, and each of these is a defect that would otherwise
  reach an operator quietly:

    * a wrong key must REFUSE, not return rubbish. The RTL cipher returns
      bytes either way -- measured with a probe -- so without the MAC a
      settings file copied between machines would have TR4W logging in
      somewhere with a garbage password.
    * an untagged value must still read, or every existing tr4w.json loses
      its passwords on the first run of this code.
    * a password containing a colon must survive, because the stored form
      is colon-delimited and that is exactly the character an author of a
      format like this forgets to think about.
    * an empty secret must store as nothing at all, so clearing a password
      clears it rather than leaving a blob that decodes to emptiness.
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
      procedure TestColonInThePasswordSurvives;
      procedure TestEmptyStoresAsNothing;
      procedure TestStoredFormIsTagged;
      procedure TestUntaggedValueIsReadAsItself;
      procedure TestPlainTaggedValueIsRead;
      procedure TestWrongKeyIsRefusedNotReturned;
      procedure TestTamperedPayloadIsRefused;
      procedure TestMalformedPayloadIsRefused;
      procedure TestIsProtectedTellsTheTwoApart;
      procedure TestARefusedStoreIsReportedNotSilent;
      procedure TestTheValueIsNeverInTheNotice;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   uKeychain;

const
   (* Two keys that are nothing alike, so a test that passes by accident on
     a near-miss cannot pass here. *)
   KEY_A = '0123456789ABCDEF0123456789ABCDEF';
   KEY_B = 'FEDCBA9876543210FEDCBA9876543210';

   NAME = 'Hamscore.Password';

procedure UseKey(const aKey: string);
begin
   InstallTestKeychain(aKey);
end;

(* The base64 field of a stored value -- everything after the last colon.
  The test needs to edit the CIPHERTEXT specifically, not the length or the
  MAC, or it would be proving that a malformed header is rejected rather
  than that a tampered payload is. *)
function ExtractBase64(const aStored: string): string;
var
   i: integer;
begin
   Result := aStored;
   for i := Length(aStored) downto 1 do
      begin
      if aStored[i] = ':' then
         begin
         Result := Copy(aStored, i + 1, Length(aStored));
         Exit;
         end;
      end;
end;

procedure TKeychainTests.TestRoundTrip;
var
   stored: string;
   back: string;
begin
   BeginTest('a secret survives the trip to the file and back');
   UseKey(KEY_A);
   stored := ProtectSecret(NAME, 'Hunter2');
   CheckTrue(UnprotectSecret(NAME, stored, back), 'it reads back');
   CheckEquals('Hunter2', back, 'and it is what went in');
end;

procedure TKeychainTests.TestMixedCaseSurvives;
var
   stored: string;
   back: string;
begin
   (* THE CASE QUESTION IS WHY ANY OF THIS STARTED. The legacy ini parser
     upper-cased whole lines, so a password came back shouting; a value that
     goes through here must not acquire that behaviour. *)
   BeginTest('case is not touched');
   UseKey(KEY_A);
   stored := ProtectSecret(NAME, 'MiXeD-CaSe-Pw');
   CheckTrue(UnprotectSecret(NAME, stored, back), 'it reads back');
   CheckEquals('MiXeD-CaSe-Pw', back, 'exactly as typed');
end;

procedure TKeychainTests.TestNonAsciiSurvives;
var
   stored: string;
   back: string;
begin
   (* THE PLAINTEXT GOES THROUGH UTF-8 BOTH WAYS ON PURPOSE. Hashing or
     encoding it through the machine's codepage instead would make a
     password hash differently on a differently-localised machine, and the
     failure would look like a wrong password rather than a wrong
     conversion. *)
   BeginTest('a non-ASCII password survives');
   UseKey(KEY_A);
   stored := ProtectSecret(NAME, 'pa' + Chr($DF) + 'wort-' + Chr($E9));
   CheckTrue(UnprotectSecret(NAME, stored, back), 'it reads back');
   CheckEquals('pa' + Chr($DF) + 'wort-' + Chr($E9), back, 'unchanged');
end;

procedure TKeychainTests.TestColonInThePasswordSurvives;
var
   stored: string;
   back: string;
begin
   (* The stored form is colon-delimited and the password is not part of the
     delimited region -- it is inside the ciphertext. This is the test that
     says so. *)
   BeginTest('a password containing the delimiter survives');
   UseKey(KEY_A);
   stored := ProtectSecret(NAME, 'a:b:c:1234');
   CheckTrue(UnprotectSecret(NAME, stored, back), 'it reads back');
   CheckEquals('a:b:c:1234', back, 'colons and all');
end;

procedure TKeychainTests.TestEmptyStoresAsNothing;
var
   back: string;
begin
   BeginTest('an empty secret stores as nothing, not as a blob');
   UseKey(KEY_A);
   CheckEquals('', ProtectSecret(NAME, ''), 'nothing is written');
   CheckTrue(UnprotectSecret(NAME, '', back), 'and nothing reads back');
   CheckEquals('', back, 'as empty');
end;

procedure TKeychainTests.TestStoredFormIsTagged;
var
   stored: string;
begin
   (* THE TAG IS WHAT MAKES THE MECHANISM REVERSIBLE, so it is pinned rather
     than left as an implementation detail: a build that prefers a different
     scheme still has to recognise what this one wrote. *)
   BeginTest('what goes in the file names its own scheme');
   UseKey(KEY_A);
   stored := ProtectSecret(NAME, 'Hunter2');
   CheckEquals(KEYCHAIN_SCHEME_LOCALFILE, SecretSchemeOf(stored),
               'the portable scheme names itself');
   CheckTrue(Pos('Hunter2', stored) = 0,
             'and the password is not sitting in it in the clear');
end;

procedure TKeychainTests.TestUntaggedValueIsReadAsItself;
var
   back: string;
begin
   (* EVERY EXISTING tr4w.json DEPENDS ON THIS. Passwords in it today carry
     no tag, and reading one as itself is what stops this change emptying
     every operator's configuration on first run. *)
   BeginTest('a value from before any of this is read as itself');
   UseKey(KEY_A);
   CheckTrue(UnprotectSecret(NAME, 'LegacyPlainPw', back), 'it reads');
   CheckEquals('LegacyPlainPw', back, 'unchanged');

   (* AND A COLON DOES NOT MAKE A TAG. A stored URL or a password with a
     colon in it must not be mistaken for a scheme nobody ever wrote. *)
   CheckTrue(UnprotectSecret(NAME, 'http://example.test/x', back), 'reads');
   CheckEquals('http://example.test/x', back, 'a colon is not a scheme');
end;

procedure TKeychainTests.TestPlainTaggedValueIsRead;
var
   back: string;
begin
   BeginTest('a deliberately plain value is read');
   UseKey(KEY_A);
   CheckTrue(UnprotectSecret(NAME, KEYCHAIN_SCHEME_PLAIN + ':Hunter2', back),
             'it reads');
   CheckEquals('Hunter2', back, 'as itself');
end;

procedure TKeychainTests.TestWrongKeyIsRefusedNotReturned;
var
   stored: string;
   back: string;
begin
   (* THE ONE THAT MATTERS MOST. The cipher hands back bytes for any key, so
     without the MAC this would "succeed" and return rubbish -- and TR4W
     would send that rubbish to a score server as a password. *)
   BeginTest('a foreign key is refused, not decoded into rubbish');
   UseKey(KEY_A);
   stored := ProtectSecret(NAME, 'Hunter2');

   UseKey(KEY_B);
   CheckFalse(UnprotectSecret(NAME, stored, back), 'the wrong key refuses');
   CheckEquals('', back, 'and hands back nothing at all');
end;

procedure TKeychainTests.TestTamperedPayloadIsRefused;
var
   stored: string;
   back: string;
   base64At: integer;
begin
   (* WHERE THE EDIT LANDS DECIDES WHAT THIS PROVES, and the first version of
     this test got it wrong in an instructive way.

     It changed the LAST character of the base64 and then failed, because a
     seven-byte password fills one eight-byte block: the tail of the encoding
     is padding that Unprotect discards by length before the MAC ever sees
     it. Editing there is genuinely harmless and refusing it would be wrong.

     So the edit goes at the START of the ciphertext, which is plaintext
     nobody discards. THAT is what the MAC exists to catch. *)
   BeginTest('an edited ciphertext is refused');
   UseKey(KEY_A);
   stored := ProtectSecret(NAME, 'Hunter2');

   base64At := Length(stored) - Length(ExtractBase64(stored)) + 1;
   if stored[base64At] = 'A' then
      begin
      stored[base64At] := 'B';
      end
   else
      begin
      stored[base64At] := 'A';
      end;

   CheckFalse(UnprotectSecret(NAME, stored, back), 'refused');
   CheckEquals('', back, 'and nothing handed back');
end;

procedure TKeychainTests.TestMalformedPayloadIsRefused;
var
   back: string;
begin
   BeginTest('a payload that is not the right shape is refused');
   UseKey(KEY_A);
   CheckFalse(UnprotectSecret(NAME, KEYCHAIN_SCHEME_LOCALFILE + ':', back),
              'no fields');
   CheckFalse(UnprotectSecret(NAME, KEYCHAIN_SCHEME_LOCALFILE + ':7:abc', back),
              'two fields, not three');
   CheckFalse(UnprotectSecret(NAME, KEYCHAIN_SCHEME_LOCALFILE + ':x:y:z', back),
              'a length that is not a number');
end;

procedure TKeychainTests.TestIsProtectedTellsTheTwoApart;
var
   stored: string;
begin
   (* Lint-NoSecrets asks this question of every tracked file, so a wrong
     answer here is a protected blob reaching the repository. *)
   BeginTest('a protected value is told apart from a bare one');
   UseKey(KEY_A);
   stored := ProtectSecret(NAME, 'Hunter2');
   CheckTrue(IsProtectedSecret(stored), 'the protected one');
   CheckFalse(IsProtectedSecret('Hunter2'), 'a bare password');
   CheckFalse(IsProtectedSecret(''), 'nothing at all');
   CheckFalse(IsProtectedSecret(KEYCHAIN_SCHEME_PLAIN + ':Hunter2'),
              'plain is tagged but is not protected');
end;

(*
  A STORE THAT WILL NOT TAKE THE VALUE -- a locked keyring, a read-only
  install directory, a policy that forbids credential storage.
*)
type
   TRefusingBackend = class(TKeychainBackend)
   public
      function Scheme: string; override;
      function Protect(const aName, aPlain: string;
                       out aStored: string): TKeychainStatus; override;
      function Unprotect(const aName, aPayload: string;
                         out aPlain: string): TKeychainStatus; override;
   end;

function TRefusingBackend.Scheme: string;
begin
   Result := 'refusing1';
end;

function TRefusingBackend.Protect(const aName, aPlain: string;
                                  out aStored: string): TKeychainStatus;
begin
   aStored := '';
   Result := ksUnavailable;
end;

function TRefusingBackend.Unprotect(const aName, aPayload: string;
                                    out aPlain: string): TKeychainStatus;
begin
   aPlain := '';
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

procedure TKeychainTests.TestARefusedStoreIsReportedNotSilent;
var
   stored: string;
begin
   (* THE FIRST VERSION OF THIS UNIT DOWNGRADED IN SILENCE, which is the
     failure CLAUDE.md names outright -- prefer a reported error to a silent
     fallback. An operator whose keyring was locked would have had a password
     written in a weaker form with nothing anywhere saying so.

     THE VALUE IS STILL KEPT, deliberately. Refusing would lose a password
     the operator has just typed, which is worse than storing it less well. *)
   BeginTest('a store that refuses is reported, and the value is not lost');

   GNoticeCount := 0;
   GLastNoticeName := '';
   GLastNoticeText := '';
   SetKeychainNotice(@RecordNotice);
   RegisterKeychainBackend(TRefusingBackend.Create);
   try
      stored := ProtectSecret('Server.Password', 'Hunter2');

      CheckEquals(1, GNoticeCount, 'the downgrade was announced exactly once');
      CheckEquals('Server.Password', GLastNoticeName, 'and it named the setting');
      CheckEquals(KEYCHAIN_SCHEME_PLAIN, SecretSchemeOf(stored),
                  'the weaker form is tagged for what it is');
      CheckFalse(IsProtectedSecret(stored),
                 'and it does not claim to be protected');
   finally
      SetKeychainNotice(nil);
      (* Put a working backend back, or every later test in the run inherits
        a store that refuses. *)
      UseKey(KEY_A);
   end;
end;

procedure TKeychainTests.TestTheValueIsNeverInTheNotice;
var
   stored: string;
begin
   (* THE ONE RULE THAT IS ABSOLUTE. A notice goes to the log, and a log is
     copied into bug reports and pasted into chat. Whatever else a message
     says, it must not say the password. *)
   BeginTest('a notice never carries the secret');

   GNoticeCount := 0;
   GLastNoticeText := '';
   SetKeychainNotice(@RecordNotice);
   RegisterKeychainBackend(TRefusingBackend.Create);
   try
      stored := ProtectSecret('Server.Password', 'Hunter2');
      CheckTrue(GNoticeCount > 0, 'something was reported');
      CheckTrue(Pos('Hunter2', GLastNoticeText) = 0,
                'and the value is not in it');
   finally
      SetKeychainNotice(nil);
      UseKey(KEY_A);
   end;
end;

procedure TKeychainTests.RunAllTests;
begin
   TestRoundTrip;
   TestMixedCaseSurvives;
   TestNonAsciiSurvives;
   TestColonInThePasswordSurvives;
   TestEmptyStoresAsNothing;
   TestStoredFormIsTagged;
   TestUntaggedValueIsReadAsItself;
   TestPlainTaggedValueIsRead;
   TestWrongKeyIsRefusedNotReturned;
   TestTamperedPayloadIsRefused;
   TestMalformedPayloadIsRefused;
   TestIsProtectedTellsTheTwoApart;
   TestARefusedStoreIsReportedNotSilent;
   TestTheValueIsNeverInTheNotice;
end;

end.

unit uTestSecretStore;
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
   TSecretStoreTests = class(TTestCase)
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
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   uSecretStore;

const
   (* Two keys that are nothing alike, so a test that passes by accident on
     a near-miss cannot pass here. *)
   KEY_A = '0123456789ABCDEF0123456789ABCDEF';
   KEY_B = 'FEDCBA9876543210FEDCBA9876543210';

   NAME = 'Hamscore.Password';

procedure UseKey(const aKey: string);
begin
   InstallFixedKeyProtectorForTesting(aKey);
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

procedure TSecretStoreTests.TestRoundTrip;
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

procedure TSecretStoreTests.TestMixedCaseSurvives;
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

procedure TSecretStoreTests.TestNonAsciiSurvives;
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

procedure TSecretStoreTests.TestColonInThePasswordSurvives;
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

procedure TSecretStoreTests.TestEmptyStoresAsNothing;
var
   back: string;
begin
   BeginTest('an empty secret stores as nothing, not as a blob');
   UseKey(KEY_A);
   CheckEquals('', ProtectSecret(NAME, ''), 'nothing is written');
   CheckTrue(UnprotectSecret(NAME, '', back), 'and nothing reads back');
   CheckEquals('', back, 'as empty');
end;

procedure TSecretStoreTests.TestStoredFormIsTagged;
var
   stored: string;
begin
   (* THE TAG IS WHAT MAKES THE MECHANISM REVERSIBLE, so it is pinned rather
     than left as an implementation detail: a build that prefers a different
     scheme still has to recognise what this one wrote. *)
   BeginTest('what goes in the file names its own scheme');
   UseKey(KEY_A);
   stored := ProtectSecret(NAME, 'Hunter2');
   CheckEquals(SECRET_SCHEME_BLOWFISH, SecretSchemeOf(stored),
               'the portable scheme names itself');
   CheckTrue(Pos('Hunter2', stored) = 0,
             'and the password is not sitting in it in the clear');
end;

procedure TSecretStoreTests.TestUntaggedValueIsReadAsItself;
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

procedure TSecretStoreTests.TestPlainTaggedValueIsRead;
var
   back: string;
begin
   BeginTest('a deliberately plain value is read');
   UseKey(KEY_A);
   CheckTrue(UnprotectSecret(NAME, SECRET_SCHEME_PLAIN + ':Hunter2', back),
             'it reads');
   CheckEquals('Hunter2', back, 'as itself');
end;

procedure TSecretStoreTests.TestWrongKeyIsRefusedNotReturned;
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

procedure TSecretStoreTests.TestTamperedPayloadIsRefused;
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

procedure TSecretStoreTests.TestMalformedPayloadIsRefused;
var
   back: string;
begin
   BeginTest('a payload that is not the right shape is refused');
   UseKey(KEY_A);
   CheckFalse(UnprotectSecret(NAME, SECRET_SCHEME_BLOWFISH + ':', back),
              'no fields');
   CheckFalse(UnprotectSecret(NAME, SECRET_SCHEME_BLOWFISH + ':7:abc', back),
              'two fields, not three');
   CheckFalse(UnprotectSecret(NAME, SECRET_SCHEME_BLOWFISH + ':x:y:z', back),
              'a length that is not a number');
end;

procedure TSecretStoreTests.TestIsProtectedTellsTheTwoApart;
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
   CheckFalse(IsProtectedSecret(SECRET_SCHEME_PLAIN + ':Hunter2'),
              'plain is tagged but is not protected');
end;

procedure TSecretStoreTests.RunAllTests;
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
end;

end.

unit uKeychainJSON;
{$I ..\tr4w.inc}
interface
uses uJSON;
procedure AddProtectedPassword(const aTarget: TJSONObject;
   const aMember, aSecretName, aPlain: string; aKeepReference: boolean = False);
function ReadProtectedPassword(const aObject: TJSONObject;
   const aMember: string; const aExpectedName: string = ''): string;
implementation
uses SysUtils, uKeychain;
procedure AddProtectedPassword(const aTarget: TJSONObject;
   const aMember, aSecretName, aPlain: string; aKeepReference: boolean = False);
begin
   if StoreSecret(aSecretName, aPlain) or (aKeepReference and (aPlain <> '')) then
      begin
      aTarget.AddPair(aMember + KEYCHAIN_REF_SUFFIX, aSecretName);
      end;
end;
function ReadProtectedPassword(const aObject: TJSONObject;
   const aMember: string; const aExpectedName: string): string;
var
   reference: string;
begin
   Result := JSONGetStr(aObject, aMember, '');
   if Result <> '' then
      begin
      Exit;
      end;
   reference := JSONGetStr(aObject, aMember + KEYCHAIN_REF_SUFFIX, '');
   if reference = '' then
      begin
      Exit;
      end;
   if (aExpectedName <> '') and (reference <> aExpectedName) then
      begin
      raise EConvertError.Create('Credential reference does not match its definition ID');
      end;
   FetchSecret(reference, Result);
end;
end.

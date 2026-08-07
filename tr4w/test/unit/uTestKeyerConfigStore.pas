{
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
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uTestKeyerConfigStore;

{
  Tests for the keyer library (uKeyerConfigStore).

  THE ROUND-TRIP TEST IS THE IMPORTANT ONE, and it is written the way the radio
  store's is: every field gets a value distinguishable from the type's zero AND
  from every other field's value.  A store that drops a field is caught, and so
  is one that crosses two -- which a test using TRUE/1/'x' everywhere would sail
  straight past.  That is the class of defect CLAUDE.md warns about: a silently
  defaulted field reads as a legal zero.
}

interface

uses
   SysUtils, Classes, System.JSON,
   uTR4WTestFramework, uKeyerConfigStore;

type
   TKeyerConfigStoreTests = class(TTestCase)
   private
      function MakeFullyPopulatedKeyer(const aName: string): TKeyerDefinition;
      procedure CheckKeyersMatch(const aExpected, aActual: TKeyerDefinition);
   protected
      procedure Test_RoundTripsEveryField;
      procedure Test_RoundTripsEveryKind;
      procedure Test_FromJSONOfEmptyArrayYieldsEmptyStore;
      procedure Test_UnknownKindIsRejectedNotGuessed;
      procedure Test_KindIsStoredAsTextNotOrdinal;
      procedure Test_TolerATesBooleanWrittenAsText;

      procedure Test_NameMatchingIsCaseInsensitive;
      procedure Test_UniqueKeyerNameDedupes;
      procedure Test_RenameToTakenNameRefused;
      procedure Test_RenameToADifferentSpellingOfItselfAllowed;
      procedure Test_RenameOfMissingKeyerRefused;
      procedure Test_RemoveKeyer;

      procedure Test_ValidateCatchesDuplicateNames;
      procedure Test_ValidateCatchesBlankName;
      procedure Test_ValidateCatchesMissingPort;

      procedure Test_SameAsDetectsEveryFieldIncludingName;
      procedure Test_CloneIsIndependent;
      procedure Test_DisplaySummaryNamesTheTransport;
   public
      procedure RunAllTests; override;
   end;

implementation

{ ---------------------------------------------------------------- helpers -- }

function TKeyerConfigStoreTests.MakeFullyPopulatedKeyer(const aName: string): TKeyerDefinition;
begin
   Result := TKeyerDefinition.Create;
   Result.Name := aName;
   Result.Kind := kkWinKeyer;
   Result.Port := 'SERIAL 7';

   // Distinct values throughout -- see the unit header.
   Result.WKKeyerMode          := 'IAMBIC B';
   Result.WKSidetoneFrequency  := '750';
   Result.WKAutospace          := True;
   Result.WKCTSpacing          := False;
   Result.WKIgnoreSpeedPot     := True;
   Result.WKPaddleOnlySidetone := False;
   Result.WKPaddleSwap         := True;
   Result.WKSidetoneEnable     := False;
   Result.WKWeight             := 51;
   Result.WKLeadInTime         := 13;
   Result.WKTailTime           := 17;
   Result.WKDitDahRatio        := 44;
   Result.WKFirstExtension     := 6;
   Result.WKKeyerCompensation  := 9;
   Result.WKPaddleSwitchpoint  := 33;
end;

procedure TKeyerConfigStoreTests.CheckKeyersMatch(const aExpected, aActual: TKeyerDefinition);
begin
   CheckEquals(aExpected.Name, aActual.Name, 'Name');
   CheckEquals(KeyerKindToStr(aExpected.Kind), KeyerKindToStr(aActual.Kind), 'Kind');
   CheckEquals(aExpected.Port, aActual.Port, 'Port');

   CheckEquals(aExpected.WKKeyerMode, aActual.WKKeyerMode, 'WKKeyerMode');
   CheckEquals(aExpected.WKSidetoneFrequency, aActual.WKSidetoneFrequency, 'WKSidetoneFrequency');
   CheckTrue(aExpected.WKAutospace = aActual.WKAutospace, 'WKAutospace');
   CheckTrue(aExpected.WKCTSpacing = aActual.WKCTSpacing, 'WKCTSpacing');
   CheckTrue(aExpected.WKIgnoreSpeedPot = aActual.WKIgnoreSpeedPot, 'WKIgnoreSpeedPot');
   CheckTrue(aExpected.WKPaddleOnlySidetone = aActual.WKPaddleOnlySidetone, 'WKPaddleOnlySidetone');
   CheckTrue(aExpected.WKPaddleSwap = aActual.WKPaddleSwap, 'WKPaddleSwap');
   CheckTrue(aExpected.WKSidetoneEnable = aActual.WKSidetoneEnable, 'WKSidetoneEnable');
   CheckEquals(aExpected.WKWeight, aActual.WKWeight, 'WKWeight');
   CheckEquals(aExpected.WKLeadInTime, aActual.WKLeadInTime, 'WKLeadInTime');
   CheckEquals(aExpected.WKTailTime, aActual.WKTailTime, 'WKTailTime');
   CheckEquals(aExpected.WKDitDahRatio, aActual.WKDitDahRatio, 'WKDitDahRatio');
   CheckEquals(aExpected.WKFirstExtension, aActual.WKFirstExtension, 'WKFirstExtension');
   CheckEquals(aExpected.WKKeyerCompensation, aActual.WKKeyerCompensation, 'WKKeyerCompensation');
   CheckEquals(aExpected.WKPaddleSwitchpoint, aActual.WKPaddleSwitchpoint, 'WKPaddleSwitchpoint');
end;

{ ------------------------------------------------------------------ JSON -- }

procedure TKeyerConfigStoreTests.Test_RoundTripsEveryField;
var
   store, reloaded: TKeyerConfigStore;
   original: TKeyerDefinition;
   arr: TJSONArray;
begin
   BeginTest('Test_RoundTripsEveryField');
   store := TKeyerConfigStore.Create;
   reloaded := TKeyerConfigStore.Create;
   original := nil;
   try
      original := MakeFullyPopulatedKeyer('Desk WinKey');
      store.AddKeyer('Desk WinKey', kkWinKeyer).Assign(original);

      arr := store.ToJSON;
      try
         reloaded.FromJSON(arr);
      finally
         arr.Free;
      end;

      CheckEquals(1, reloaded.KeyerCount, 'one keyer survives the round trip');
      CheckKeyersMatch(original, reloaded.Keyer(0));
   finally
      original.Free;
      reloaded.Free;
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_RoundTripsEveryKind;
var
   store, reloaded: TKeyerConfigStore;
   arr: TJSONArray;
   k: TKeyerKind;
   i: integer;
begin
   BeginTest('Test_RoundTripsEveryKind');
   store := TKeyerConfigStore.Create;
   reloaded := TKeyerConfigStore.Create;
   try
      for k := Low(TKeyerKind) to High(TKeyerKind) do
         begin
         store.AddKeyer(KeyerKindToStr(k), k).Port := 'SERIAL 1';
         end;

      arr := store.ToJSON;
      try
         reloaded.FromJSON(arr);
      finally
         arr.Free;
      end;

      CheckEquals(store.KeyerCount, reloaded.KeyerCount, 'every kind survives');
      for i := 0 to store.KeyerCount - 1 do
         begin
         CheckEquals(KeyerKindToStr(store.Keyer(i).Kind),
                     KeyerKindToStr(reloaded.Keyer(i).Kind),
                     'kind ' + IntToStr(i));
         end;
   finally
      reloaded.Free;
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_FromJSONOfEmptyArrayYieldsEmptyStore;
var
   store: TKeyerConfigStore;
   arr: TJSONArray;
begin
   BeginTest('Test_FromJSONOfEmptyArrayYieldsEmptyStore');
   store := TKeyerConfigStore.Create;
   arr := TJSONArray.Create;
   try
      store.AddKeyer('Doomed', kkYCCC);
      store.FromJSON(arr);
      CheckEquals(0, store.KeyerCount, 'loading an empty array clears the store');
   finally
      arr.Free;
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_UnknownKindIsRejectedNotGuessed;
var
   kind: TKeyerKind;
begin
   BeginTest('Test_UnknownKindIsRejectedNotGuessed');
   // A keyer of the wrong kind keys nothing and presents as a hardware fault,
   // so an unrecognised spelling must NOT fall through to kind zero silently.
   CheckFalse(StrToKeyerKind('BANANA', kind), 'unknown kind rejected');
   CheckTrue(StrToKeyerKind('winkeyer', kind), 'known kind accepted, case-insensitively');
   CheckEquals(KeyerKindToStr(kkWinKeyer), KeyerKindToStr(kind), 'and maps correctly');
end;

procedure TKeyerConfigStoreTests.Test_KindIsStoredAsTextNotOrdinal;
var
   store: TKeyerConfigStore;
   arr: TJSONArray;
   s: string;
begin
   BeginTest('Test_KindIsStoredAsTextNotOrdinal');
   // Text, so that inserting a kind later cannot silently re-interpret every
   // file already written.
   store := TKeyerConfigStore.Create;
   try
      store.AddKeyer('K', kkYCCC);
      arr := store.ToJSON;
      try
         s := arr.ToJSON;
      finally
         arr.Free;
      end;
      CheckTrue(Pos('YCCC', UpperCase(s)) > 0, 'kind appears as text: ' + s);
   finally
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_TolerATesBooleanWrittenAsText;
var
   store: TKeyerConfigStore;
   arr: TJSONArray;
begin
   BeginTest('Test_TolerATesBooleanWrittenAsText');
   // A hand-edited file may carry "TRUE" rather than true. The store reads what
   // an operator plausibly wrote.
   arr := TJSONObject.ParseJSONValue(
      '[{"name":"Hand","kind":"WINKEYER","port":"SERIAL 2","wkAutospace":"TRUE"}]')
      as TJSONArray;
   store := TKeyerConfigStore.Create;
   try
      store.FromJSON(arr);
      CheckEquals(1, store.KeyerCount, 'parsed');
      CheckTrue(store.Keyer(0).WKAutospace, 'TRUE as text is read as True');
   finally
      store.Free;
      arr.Free;
   end;
end;

{ ------------------------------------------------------------- the store -- }

procedure TKeyerConfigStoreTests.Test_NameMatchingIsCaseInsensitive;
var
   store: TKeyerConfigStore;
begin
   BeginTest('Test_NameMatchingIsCaseInsensitive');
   store := TKeyerConfigStore.Create;
   try
      store.AddKeyer('Desk WinKey', kkWinKeyer);
      CheckTrue(store.FindKeyer('desk winkey') <> nil, 'found case-insensitively');
      CheckTrue(store.FindKeyer('DESK WINKEY') <> nil, 'and in upper case');
      CheckTrue(store.FindKeyer('Nope') = nil, 'a genuine miss is still nil');
   finally
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_UniqueKeyerNameDedupes;
var
   store: TKeyerConfigStore;
begin
   BeginTest('Test_UniqueKeyerNameDedupes');
   store := TKeyerConfigStore.Create;
   try
      CheckEquals('WinKeyer', store.UniqueKeyerName('WinKeyer'), 'first is unadorned');
      store.AddKeyer('WinKeyer', kkWinKeyer);
      CheckEquals('WinKeyer 2', store.UniqueKeyerName('WinKeyer'), 'second gets a suffix');
      store.AddKeyer('WinKeyer 2', kkWinKeyer);
      CheckEquals('WinKeyer 3', store.UniqueKeyerName('WinKeyer'), 'and keeps counting');
      CheckEquals('Keyer', store.UniqueKeyerName('   '), 'a blank base gets a default');
   finally
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_RenameToTakenNameRefused;
var
   store: TKeyerConfigStore;
   err: string;
begin
   BeginTest('Test_RenameToTakenNameRefused');
   store := TKeyerConfigStore.Create;
   try
      store.AddKeyer('One', kkWinKeyer);
      store.AddKeyer('Two', kkYCCC);
      CheckFalse(store.RenameKeyer('One', 'Two', err), 'rename onto a taken name refused');
      CheckTrue(err <> '', 'and says why');
      CheckEquals('One', store.Keyer(0).Name, 'the original name is untouched');
   finally
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_RenameToADifferentSpellingOfItselfAllowed;
var
   store: TKeyerConfigStore;
   err: string;
begin
   BeginTest('Test_RenameToADifferentSpellingOfItselfAllowed');
   // How an operator fixes capitalisation. The clash test must exclude itself.
   store := TKeyerConfigStore.Create;
   try
      store.AddKeyer('desk winkey', kkWinKeyer);
      CheckTrue(store.RenameKeyer('desk winkey', 'Desk WinKey', err), 'recase allowed: ' + err);
      CheckEquals('Desk WinKey', store.Keyer(0).Name, 'and applied');
   finally
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_RenameOfMissingKeyerRefused;
var
   store: TKeyerConfigStore;
   err: string;
begin
   BeginTest('Test_RenameOfMissingKeyerRefused');
   store := TKeyerConfigStore.Create;
   try
      CheckFalse(store.RenameKeyer('Ghost', 'Other', err), 'renaming nothing is refused');
      CheckTrue(err <> '', 'and says why');
   finally
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_RemoveKeyer;
var
   store: TKeyerConfigStore;
begin
   BeginTest('Test_RemoveKeyer');
   store := TKeyerConfigStore.Create;
   try
      store.AddKeyer('One', kkWinKeyer);
      store.AddKeyer('Two', kkYCCC);
      CheckTrue(store.RemoveKeyer('one'), 'removed case-insensitively');
      CheckEquals(1, store.KeyerCount, 'one left');
      CheckEquals('Two', store.Keyer(0).Name, 'and it is the other one');
      CheckFalse(store.RemoveKeyer('Ghost'), 'removing nothing reports False');
   finally
      store.Free;
   end;
end;

{ ---------------------------------------------------------- validation ---- }

procedure TKeyerConfigStoreTests.Test_ValidateCatchesDuplicateNames;
var
   store: TKeyerConfigStore;
   err: string;
begin
   BeginTest('Test_ValidateCatchesDuplicateNames');
   store := TKeyerConfigStore.Create;
   try
      store.AddKeyer('Same', kkWinKeyer).Port := 'SERIAL 1';
      store.AddKeyer('same', kkYCCC).Port := 'SERIAL 2';
      CheckFalse(store.Validate(err), 'duplicate names caught');
      CheckTrue(Pos('Same', err) > 0, 'and names the offender: ' + err);
   finally
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_ValidateCatchesBlankName;
var
   store: TKeyerConfigStore;
   err: string;
begin
   BeginTest('Test_ValidateCatchesBlankName');
   store := TKeyerConfigStore.Create;
   try
      store.AddKeyer('', kkWinKeyer);
      CheckFalse(store.Validate(err), 'a blank name is caught');
   finally
      store.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_ValidateCatchesMissingPort;
var
   store: TKeyerConfigStore;
   err: string;
begin
   BeginTest('Test_ValidateCatchesMissingPort');
   // Reported, not left to fail at the device -- that presents as a hardware
   // fault, which is exactly the silent-downgrade class the radio track hit.
   store := TKeyerConfigStore.Create;
   try
      store.AddKeyer('Portless', kkWinKeyer);   // Port defaults to NONE
      CheckFalse(store.Validate(err), 'a WinKeyer with no port is caught');
      CheckTrue(Pos('Portless', err) > 0, 'and names it: ' + err);
   finally
      store.Free;
   end;
end;

{ -------------------------------------------------------- the definition -- }

procedure TKeyerConfigStoreTests.Test_SameAsDetectsEveryFieldIncludingName;
var
   a, b: TKeyerDefinition;
begin
   BeginTest('Test_SameAsDetectsEveryFieldIncludingName');
   a := MakeFullyPopulatedKeyer('A');
   b := nil;
   try
      b := a.Clone;
      CheckTrue(a.SameAs(b), 'a clone is the same');

      b.Name := 'B';
      CheckFalse(a.SameAs(b), 'renaming IS a change');

      b.Assign(a);
      b.WKPaddleSwitchpoint := a.WKPaddleSwitchpoint + 1;
      CheckFalse(a.SameAs(b), 'a single changed field is detected');

      b.Assign(a);
      b.WKSidetoneFrequency := 'SOMETHING ELSE';
      CheckFalse(a.SameAs(b), 'and so is a string field');

      CheckFalse(a.SameAs(nil), 'nil is not the same as anything');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_CloneIsIndependent;
var
   a, b: TKeyerDefinition;
begin
   BeginTest('Test_CloneIsIndependent');
   a := MakeFullyPopulatedKeyer('A');
   b := nil;
   try
      b := a.Clone;
      b.WKWeight := a.WKWeight + 10;
      CheckTrue(a.WKWeight <> b.WKWeight, 'editing the clone does not touch the original');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TKeyerConfigStoreTests.Test_DisplaySummaryNamesTheTransport;
var
   k: TKeyerDefinition;
begin
   BeginTest('Test_DisplaySummaryNamesTheTransport');
   k := TKeyerDefinition.Create;
   try
      k.Name := 'Desk';
      k.Kind := kkWinKeyer;
      k.Port := 'SERIAL 5';
      CheckTrue(Pos('SERIAL 5', k.DisplaySummary) > 0, 'the device shows its port');
      CheckTrue(Pos('WINKEYER', UpperCase(k.DisplaySummary)) > 0, 'and its kind');

      k.Kind := kkYCCC;
      CheckTrue(Pos('YCCC', UpperCase(k.DisplaySummary)) > 0, 'YCCC too');
   finally
      k.Free;
   end;
end;

{ ------------------------------------------------------------------ run --- }


procedure TKeyerConfigStoreTests.RunAllTests;
begin
   Test_RoundTripsEveryField;
   Test_RoundTripsEveryKind;
   Test_FromJSONOfEmptyArrayYieldsEmptyStore;
   Test_UnknownKindIsRejectedNotGuessed;
   Test_KindIsStoredAsTextNotOrdinal;
   Test_TolerATesBooleanWrittenAsText;

   Test_NameMatchingIsCaseInsensitive;
   Test_UniqueKeyerNameDedupes;
   Test_RenameToTakenNameRefused;
   Test_RenameToADifferentSpellingOfItselfAllowed;
   Test_RenameOfMissingKeyerRefused;
   Test_RemoveKeyer;

   Test_ValidateCatchesDuplicateNames;
   Test_ValidateCatchesBlankName;
   Test_ValidateCatchesMissingPort;

   Test_SameAsDetectsEveryFieldIncludingName;
   Test_CloneIsIndependent;
   Test_DisplaySummaryNamesTheTransport;
end;

end.

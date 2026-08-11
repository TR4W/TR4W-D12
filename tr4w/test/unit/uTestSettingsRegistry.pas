unit uTestSettingsRegistry;

{
  The settings registry -- what replaces CFGCA's untyped-pointer table.

  WHAT THESE TESTS ARE REALLY ABOUT.  The old table stored a setting as a
  Pointer plus a tag saying how to dereference it, so 'MY CALL' (crAddress:
  @MyCall) and 'SCP MINIMUM LETTERS' (crAddress: pointer(1), an INDEX) had the
  same type as far as the compiler was concerned.  Reading the second as if it
  were the first is what produced an access violation on 2026-08-11.

  That failure CANNOT BE WRITTEN in this design, and that is the point of the
  exercise rather than a happy accident: a setting carries typed closures, so
  there is no pointer to mis-cast and no tag to misread.  What remains testable
  is the behaviour built on top -- validation, allow-lists, refusal semantics --
  and above all that a REFUSED value leaves the setting alone.  A validator that
  reports failure and assigns anyway is worse than none, because the caller then
  reports an error for a change that did happen.
}

interface

uses
   SysUtils, uTR4WTestFramework;

type
   TSettingsRegistryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_BoolRoundTripsAndAcceptsCommonSpellings;
      procedure Test_BoolRefusesNonsenseAndKeepsItsValue;
      procedure Test_IntRangeIsEnforced;
      procedure Test_IntAllowListBeatsRange;
      procedure Test_StringLengthIsRefusedNotTruncated;
      procedure Test_StringIsNotTrimmed;
      procedure Test_EnumStoresTheDeclaredSpelling;
      procedure Test_OnApplyRunsOnlyWhenTheValueWasAccepted;
      procedure Test_DuplicateKeyIsRefused;
      procedure Test_AllowedValuesDrivesTheControlChoice;
      procedure Test_SelfStoringNeedsNoGlobal;
      procedure Test_SelfStoringInstancesAreIndependent;
      procedure Test_SelfStoringEnumRefusesADefaultOutsideItsValues;
   end;

implementation

uses
   uSettingsRegistry;

// Backing variables for the settings under test.  Deliberately plain globals:
// that is what the real settings wrap, so the tests exercise the same shape.
var
   vBool: boolean;
   vInt: integer;
   vStr: string;
   vEnum: string;
   applyCount: integer;

function NewBool(const aKey: string): TBoolSetting;
begin
   Result := TBoolSetting.Create(aKey, 'test',
      function: boolean begin Result := vBool end,
      procedure (v: boolean) begin vBool := v end);
end;

function NewInt(const aKey: string; const aMin, aMax: integer): TIntSetting;
begin
   Result := TIntSetting.Create(aKey, 'test',
      function: integer begin Result := vInt end,
      procedure (v: integer) begin vInt := v end,
      aMin, aMax);
end;

function NewStr(const aKey: string; const aMax: integer): TStringSetting;
begin
   Result := TStringSetting.Create(aKey, 'test',
      function: string begin Result := vStr end,
      procedure (v: string) begin vStr := v end,
      aMax);
end;

procedure TSettingsRegistryTests.Test_BoolRoundTripsAndAcceptsCommonSpellings;
var
   s: TBoolSetting;
   err: string;
begin
   BeginTest('a boolean round-trips and accepts the spellings people type');
   s := NewBool('test.bool.spellings');
   try
      vBool := False;
      CheckEquals('FALSE', s.AsText, 'renders FALSE');

      CheckTrue(s.TrySetText('TRUE', err), 'TRUE accepted: ' + err);
      CheckTrue(vBool, 'and assigned');
      CheckEquals('TRUE', s.AsText, 'renders TRUE');

      // Generous on input, exact on output: config files get hand-edited.
      CheckTrue(s.TrySetText('no', err),  'no accepted');
      CheckFalse(vBool, 'no means false');
      CheckTrue(s.TrySetText('1', err),   '1 accepted');
      CheckTrue(vBool, '1 means true');
      CheckTrue(s.TrySetText('Off', err), 'Off accepted');
      CheckFalse(vBool, 'Off means false');
   finally
      s.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_BoolRefusesNonsenseAndKeepsItsValue;
var
   s: TBoolSetting;
   err: string;
begin
   BeginTest('a refused boolean leaves the value ALONE');
   s := NewBool('test.bool.refuse');
   try
      vBool := True;
      CheckFalse(s.TrySetText('banana', err), 'banana refused');
      CheckTrue(err <> '', 'and says why');
      // The half of "refused" that matters: reporting failure while assigning
      // anyway would have the caller show an error for a change that happened.
      CheckTrue(vBool, 'value untouched by the refusal');
   finally
      s.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_IntRangeIsEnforced;
var
   s: TIntSetting;
   err: string;
begin
   BeginTest('an integer outside its range is refused, and the value kept');
   s := NewInt('test.int.range', 1, 65535);
   try
      vInt := 50001;
      CheckFalse(s.TrySetText('0', err),      '0 is below the range');
      CheckEquals(50001, vInt, 'value untouched');
      CheckFalse(s.TrySetText('70000', err),  '70000 is above the range');
      CheckEquals(50001, vInt, 'value untouched');
      CheckFalse(s.TrySetText('garbage', err),'garbage is not a number');
      CheckEquals(50001, vInt, 'value untouched');

      CheckTrue(s.TrySetText('1024', err), '1024 accepted: ' + err);
      CheckEquals(1024, vInt, 'and assigned');
   finally
      s.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_IntAllowListBeatsRange;
var
   s: TIntSetting;
   err: string;
begin
   BeginTest('an allow-list is the range, and a value outside it is refused');
   // THE SCP MINIMUM LETTERS CASE, which is where this started: the old table
   // expressed it as ckArray with crAddress secretly holding an INDEX, and the
   // panel offered a free-text box that let the operator type 2 and have it
   // silently refused deeper down.  Declared here, so a UI can offer exactly
   // these and nothing else.
   s := NewInt('test.int.allowed', 0, 100).Allowed([0, 3, 4, 5]);
   try
      vInt := 4;
      CheckFalse(s.TrySetText('2', err), '2 is not in the list');
      CheckEquals(4, vInt, 'value untouched');
      CheckTrue(err <> '', 'and says why');

      CheckTrue(s.TrySetText('5', err), '5 is in the list: ' + err);
      CheckEquals(5, vInt, 'and assigned');

      // Inside the min/max but not in the list -- the list is the stricter
      // rule and must win, or the range silently re-admits what it excluded.
      CheckFalse(s.TrySetText('50', err), '50 is in range but not in the list');
      CheckEquals(5, vInt, 'value untouched');
   finally
      s.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_StringLengthIsRefusedNotTruncated;
var
   s: TStringSetting;
   err: string;
begin
   BeginTest('an over-long string is REFUSED, not silently truncated');
   // The legacy targets are ShortStrings, where an over-long assignment is cut
   // without a word -- so the operator sees a value they did not type and gets
   // no explanation.  Refusing is the honest answer.
   s := NewStr('test.str.length', 10);
   try
      vStr := 'NY4I';
      CheckFalse(s.TrySetText('THIS IS FAR TOO LONG', err), 'refused');
      CheckEquals('NY4I', vStr, 'value untouched -- NOT truncated');
      CheckTrue(Pos('10', err) > 0, 'the message names the limit: ' + err);
   finally
      s.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_StringIsNotTrimmed;
var
   s: TStringSetting;
   err: string;
begin
   BeginTest('a string setting does not trim -- a password may need its spaces');
   s := NewStr('test.str.trim', 0);
   try
      CheckTrue(s.TrySetText('  spaced  ', err), 'accepted');
      CheckEquals('  spaced  ', vStr,
                  'stored verbatim: silently eating a space turns "wrong password" into a puzzle');
   finally
      s.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_EnumStoresTheDeclaredSpelling;
var
   s: TEnumSetting;
   err: string;
begin
   BeginTest('an enum stores the DECLARED spelling, whatever case was typed');
   s := TEnumSetting.Create('test.enum', 'test',
      function: string begin Result := vEnum end,
      procedure (v: string) begin vEnum := v end,
      ['NONE', 'DXKEEPER', 'ACLOG', 'HRD']);
   try
      vEnum := 'NONE';
      CheckTrue(s.TrySetText('dxkeeper', err), 'lower case accepted: ' + err);
      // One spelling in the system: a hand-edited file is normalised on the
      // next save rather than carrying a variant that only some code matches.
      CheckEquals('DXKEEPER', vEnum, 'normalised to the declared spelling');

      CheckFalse(s.TrySetText('LOGGER32', err), 'an unknown value is refused');
      CheckEquals('DXKEEPER', vEnum, 'value untouched');
   finally
      s.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_OnApplyRunsOnlyWhenTheValueWasAccepted;
var
   s: TIntSetting;
   err: string;
begin
   BeginTest('OnApply runs on a successful set and NOT on a refused one');
   // OnApply replaces crA and crP -- deriving dependent state, redrawing,
   // restarting a server.  Running it after a refusal would act on a change
   // that did not happen; not running it after a success leaves the program
   // holding a value nothing has reacted to.  Both are silent in the old table.
   s := NewInt('test.int.apply', 1, 10);
   applyCount := 0;
   s.OnApply := procedure begin Inc(applyCount) end;
   try
      vInt := 5;
      CheckTrue(s.TrySetText('7', err), 'accepted');
      CheckEquals(1, applyCount, 'OnApply ran once');

      CheckFalse(s.TrySetText('99', err), 'refused');
      CheckEquals(1, applyCount, 'OnApply did NOT run for the refusal');
   finally
      s.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_DuplicateKeyIsRefused;
var
   raised: boolean;
begin
   BeginTest('registering the same key twice raises rather than shadowing');
   RegisterSetting(NewBool('test.duplicate.key'));
   raised := False;
   try
      RegisterSetting(NewBool('test.duplicate.key'));
   except
      on E: Exception do
         begin
         raised := True;
         end;
   end;
   // Silent shadowing would let the UI and the persister disagree about which
   // setting a key means -- the dictionary would hold the second while the list
   // still held the first.
   CheckTrue(raised, 'a duplicate key must be loud');
   CheckTrue(FindSetting('test.duplicate.key') <> nil, 'the first one is still findable');
   CheckTrue(FindSetting('TEST.DUPLICATE.KEY') <> nil, 'and look-up is case-insensitive');
end;

procedure TSettingsRegistryTests.Test_AllowedValuesDrivesTheControlChoice;
var
   plain: TIntSetting;
   listed: TIntSetting;
   str: TStringSetting;
begin
   BeginTest('AllowedValues says drop-down or text box, and empty means text box');
   plain  := NewInt('test.control.plain', 0, 100);
   listed := NewInt('test.control.listed', 0, 100).Allowed([0, 3, 4, 5]);
   str    := NewStr('test.control.str', 0);
   try
      // Empty is NOT "accepts nothing" -- it means "no fixed list", which is
      // what a UI reads as "use a text box".  Getting that backwards would give
      // every free-text setting an empty drop-down.
      CheckEquals(0, Length(plain.AllowedValues), 'a ranged integer has no fixed list');
      CheckEquals(4, Length(listed.AllowedValues), 'an allow-list offers exactly its values');
      CheckEquals('3', listed.AllowedValues[1], 'in declaration order');
      CheckEquals(0, Length(str.AllowedValues), 'a string has no fixed list');
   finally
      plain.Free;
      listed.Free;
      str.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_SelfStoringNeedsNoGlobal;
var
   b: TBoolSetting;
   i: TIntSetting;
   t: TStringSetting;
   e: TEnumSetting;
   err: string;
begin
   BeginTest('a self-storing setting works with NO backing global at all');
   // The point of Own: a NEW setting should not have to invent a global first.
   // Nothing in this test declares one -- the setting is the storage.
   b := TBoolSetting.Own('test.own.bool', 'b', True);
   i := TIntSetting.Own('test.own.int', 'i', 50001, 1, 65535);
   t := TStringSetting.Own('test.own.str', 'S', 'hello', 20);
   e := TEnumSetting.Own('test.own.enum', 'e', 'NONE', ['NONE', 'DXKEEPER']);
   try
      CheckEquals('TRUE', b.AsText,   'bool default');
      CheckEquals('50001', i.AsText,  'int default');
      CheckEquals('hello', t.AsText,  'string default');
      CheckEquals('NONE', e.AsText,   'enum default');

      CheckTrue(b.TrySetText('FALSE', err), 'bool set: ' + err);
      CheckEquals('FALSE', b.AsText, 'bool round-trips through its own storage');

      CheckTrue(i.TrySetText('1024', err), 'int set: ' + err);
      CheckEquals('1024', i.AsText, 'int round-trips');

      // Validation is unchanged by where the value lives.
      CheckFalse(i.TrySetText('99999', err), 'out of range still refused');
      CheckEquals('1024', i.AsText, 'and the value is untouched');

      CheckTrue(t.TrySetText('world', err), 'string set: ' + err);
      CheckEquals('world', t.AsText, 'string round-trips');

      CheckTrue(e.TrySetText('dxkeeper', err), 'enum set: ' + err);
      CheckEquals('DXKEEPER', e.AsText, 'enum normalises, self-stored');
   finally
      e.Free;
      t.Free;
      i.Free;
      b.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_SelfStoringInstancesAreIndependent;
var
   a, b: TIntSetting;
   err: string;
begin
   BeginTest('two self-storing settings do not share storage');
   // THE FAILURE THIS GUARDS AGAINST is subtle and would look like haunting:
   // each Own captures its OWN one-element array.  Had the storage been a class
   // variable, or a local whose frame both closures somehow shared, setting one
   // would move the other, and it would present as a settings page where
   // changing one field altered a different one.
   a := TIntSetting.Own('test.own.indep.a', 'a', 1);
   b := TIntSetting.Own('test.own.indep.b', 'b', 2);
   try
      CheckTrue(a.TrySetText('100', err), 'a set');
      CheckEquals('100', a.AsText, 'a changed');
      CheckEquals('2', b.AsText, 'b did NOT change');

      CheckTrue(b.TrySetText('200', err), 'b set');
      CheckEquals('100', a.AsText, 'a still unchanged');
      CheckEquals('200', b.AsText, 'b changed');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TSettingsRegistryTests.Test_SelfStoringEnumRefusesADefaultOutsideItsValues;
var
   raised: boolean;
   e: TEnumSetting;
begin
   BeginTest('a self-storing enum refuses a default that is not one of its values');
   // Such a setting would start in a state TrySetText will never accept, so the
   // operator could not put it back after changing it.  Caught at registration
   // rather than puzzled over during a contest.
   raised := False;
   e := nil;
   try
      e := TEnumSetting.Own('test.own.enum.bad', 'e', 'LOGGER32', ['NONE', 'DXKEEPER']);
   except
      on E2: Exception do
         begin
         raised := True;
         end;
   end;
   if e <> nil then
      begin
      e.Free;
      end;
   CheckTrue(raised, 'a default outside the declared values must raise');
end;

procedure TSettingsRegistryTests.RunAllTests;
begin
   Test_BoolRoundTripsAndAcceptsCommonSpellings;
   Test_BoolRefusesNonsenseAndKeepsItsValue;
   Test_IntRangeIsEnforced;
   Test_IntAllowListBeatsRange;
   Test_StringLengthIsRefusedNotTruncated;
   Test_StringIsNotTrimmed;
   Test_EnumStoresTheDeclaredSpelling;
   Test_OnApplyRunsOnlyWhenTheValueWasAccepted;
   Test_DuplicateKeyIsRefused;
   Test_AllowedValuesDrivesTheControlChoice;
   Test_SelfStoringNeedsNoGlobal;
   Test_SelfStoringInstancesAreIndependent;
   Test_SelfStoringEnumRefusesADefaultOutsideItsValues;
end;

end.

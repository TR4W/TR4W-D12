unit uTestRadioSupportsCaps;
{$I ..\..\src\tr4w.inc}

{
  Pins rcCWByCAT / rcPlayDVK / rcCWSpeedSync against the LOGRADIO sets they were
  derived from.

  Those three capabilities replace LOGRADIO's RadioSupportsCWByCAT,
  RadioSupportsPlayDVK and RadioSupportsCWSpeedSync. The declarations were
  GENERATED from those sets across 48 classes, not typed by hand, and a
  transcription slip would be invisible: a radio that quietly loses rcCWByCAT
  simply stops keying CW for its owner, with nothing failing anywhere near the
  mistake.

  So the test re-derives the expectation from the legacy sets and compares every
  registered radio. While both representations exist this is a true cross-check;
  once InitRadios is deleted it becomes the record of what the sets contained.

  CONFIG IS NOT CAPABILITY. NY4I: "we have to make the distinction between the
  program option CWbyCAT and each radio that supports having it set in its
  capabilities." The operator's CW BY CAT setting says what they WANT; these flags
  say what the radio CAN do; IsCWByCATActive requires both. Nothing here asserts
  anything about the config side.

  No transport: capabilities are set in the constructor, so this only builds radio
  objects. Runs in CI.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioRegistry, VC;

type
   TRadioSupportsCapsTests = class(TTestCase)
   protected
      // A method, not a free function: CheckTrue/CheckEquals are TTestCase members.
      procedure CheckCapAgainstSet(const capName: string; cap: TRadioCapability;
                                   const arr: array of InterfacedRadioType);
      procedure Test_CWByCATMatchesLegacySet;
      procedure Test_PlayDVKMatchesLegacySet;
      procedure Test_CWSpeedSyncMatchesLegacySet;
      procedure Test_CWSpeedSyncIsWiderThanCWByCAT;
   public
      procedure RunAllTests; override;
   end;

implementation

// The three legacy sets, transcribed ONCE here so the test is independent of the
// generator that wrote the declarations. Kept in LOGRADIO's own order.
const
   LEGACY_CWBYCAT: array[0..27] of InterfacedRadioType = (
      TS850, K2, K3, KX3, K4, TS480, TS570, TS590, TS890, TS990, TS2000,
      FLEX, IC705, IC7100, IC7300, IC7410, IC7600, IC7610, IC7700, IC7760,
      IC7800, IC7850, IC7851, IC9100, IC9700, IC905, IC7300MK2, ORION);

   LEGACY_PLAYDVK: array[0..29] of InterfacedRadioType = (
      K2, K3, K4,
      IC705, IC7300, IC7610, IC7760, IC7850, IC7851, IC9100, IC9700, IC905, IC7300MK2,
      FT710, FT991, FT1200, FTDX3000, FTDX5000, FTDX9000, FTDX10, FTDX101, FTX1F,
      TS480, TS570, TS590, TS850, TS890, TS950, TS990, TS2000);

   LEGACY_CWSPEEDSYNC: array[0..46] of InterfacedRadioType = (
      TS850, K2, K3, K4, TS480, TS570, TS590, TS890, TS990, TS2000, FLEX,
      FTDX10, FTDX101, FTX1F, FT450, FT710, FT891, FT950, FT991,
      FT1200, FT2000, FTDX3000, FTDX5000, FTDX9000, IC718, IC746, IC746PRO,
      IC756PROII, IC756PROIII, IC910, IC705, IC7100, IC7200, IC7300, IC7410,
      IC7600, IC7610, IC7700, IC7760, IC7800, IC7850, IC7851, IC9100, IC9700,
      IC905, IC7300MK2, ORION);

// DELIBERATE divergences from the legacy sets.  Each entry is a legacy BUG that
// NY4I has ruled on, not a porting slip -- the factory is right and LOGRADIO's
// list was wrong.  Note these still ASSERT: the expected value is checked, so
// reverting the factory back to the legacy answer fails this test rather than
// quietly passing.  Anything NOT listed here must match legacy exactly.
type
   TCapDivergence = record
      cap:         TRadioCapability;
      model:       InterfacedRadioType;
      factorySays: Boolean;
      why:         string;
   end;

const
   KNOWN_DIVERGENCES: array[0..0] of TCapDivergence = (
      (cap: rcCWSpeedSync; model: KX3; factorySays: True;
       why: 'NY4I: the KX3 differs from the K3 ONLY in the memory keyer. It ' +
            'takes the same KS keyer-speed command through ' +
            'TElecraftSerial.SetCWSpeed, so its absence from ' +
            'RadioSupportsCWSpeedSync was a legacy omission -- the same class ' +
            'of gap as the KX3 missing from the Elecraft prosign set, where it ' +
            'silently keyed Kenwood spellings.')
   );

// True when this (cap, model) pair is a sanctioned divergence; expected returns
// what the FACTORY must say.
function IsKnownDivergence(cap: TRadioCapability; m: InterfacedRadioType;
                           out expected: Boolean): Boolean;
var
   i: Integer;
begin
   Result := False;
   expected := False;
   for i := Low(KNOWN_DIVERGENCES) to High(KNOWN_DIVERGENCES) do
      begin
      if (KNOWN_DIVERGENCES[i].cap = cap) and (KNOWN_DIVERGENCES[i].model = m) then
         begin
         expected := KNOWN_DIVERGENCES[i].factorySays;
         Result := True;
         Exit;
         end;
      end;
end;

function InLegacy(m: InterfacedRadioType; const arr: array of InterfacedRadioType): Boolean;
var
   i: Integer;
begin
   Result := False;
   for i := Low(arr) to High(arr) do
      begin
      if arr[i] = m then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

// Builds every registered radio and compares one capability against the set.
// ORION is skipped throughout: it is in two of the legacy sets but has no factory
// class yet (its native driver, pOrion3, is still on the legacy path), so there is
// nothing to construct and nothing to assert.
procedure TRadioSupportsCapsTests.CheckCapAgainstSet(const capName: string;
                             cap: TRadioCapability;
                             const arr: array of InterfacedRadioType);
var
   m: InterfacedRadioType;
   r: TFactoryRadioBase;
   want, got: Boolean;
   bad: string;
   checked: Integer;
begin
   bad := '';
   checked := 0;
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if not uRadioRegistry.IsRegistered(m) then
         begin
         Continue;
         end;
      r := uRadioRegistry.CreateInstance(m);
      if r = nil then
         begin
         bad := bad + uRadioRegistry.DisplayName(m) + '(nil) ';
         Continue;
         end;
      try
         Inc(checked);
         if not IsKnownDivergence(cap, m, want) then
            begin
            want := InLegacy(m, arr);
            end;
         got  := r.Supports(cap);
         if want <> got then
            begin
            bad := bad + Format('%s(want %s got %s) ',
                                [uRadioRegistry.DisplayName(m),
                                 BoolToStr(want, True), BoolToStr(got, True)]);
            end;
      finally
         r.Free;
      end;
      end;
   // Guard against the loop asserting nothing if registration ever breaks.
   CheckTrue(checked > 80, Format('expected 90-odd registered radios, built %d', [checked]));
   CheckEquals('', bad, capName + ' diverges from its legacy set: ' + bad);
end;

procedure TRadioSupportsCapsTests.Test_CWByCATMatchesLegacySet;
begin
   BeginTest('rcCWByCAT matches RadioSupportsCWByCAT for every registered radio');
   CheckCapAgainstSet('rcCWByCAT', rcCWByCAT, LEGACY_CWBYCAT);
end;

procedure TRadioSupportsCapsTests.Test_PlayDVKMatchesLegacySet;
begin
   BeginTest('rcPlayDVK matches RadioSupportsPlayDVK for every registered radio');
   CheckCapAgainstSet('rcPlayDVK', rcPlayDVK, LEGACY_PLAYDVK);
end;

procedure TRadioSupportsCapsTests.Test_CWSpeedSyncMatchesLegacySet;
begin
   BeginTest('rcCWSpeedSync matches RadioSupportsCWSpeedSync for every registered radio');
   CheckCapAgainstSet('rcCWSpeedSync', rcCWSpeedSync, LEGACY_CWSPEEDSYNC);
end;

procedure TRadioSupportsCapsTests.Test_CWSpeedSyncIsWiderThanCWByCAT;
var
   r: TFactoryRadioBase;
begin
   // The two flags are deliberately independent: a radio can accept a keyer SPEED
   // without being able to key TEXT. If someone later "simplifies" by making one
   // imply the other, this fails. The IC-718 is the clean witness -- it is in the
   // CW-speed-sync set and NOT in the CW-by-CAT set.
   BeginTest('rcCWSpeedSync does not imply rcCWByCAT (IC-718)');
   r := uRadioRegistry.CreateInstance(IC718);
   CheckTrue(r <> nil, 'IC-718 must be registered');
   try
      CheckTrue(r.Supports(rcCWSpeedSync), 'IC-718 accepts a CW speed');
      CheckFalse(r.Supports(rcCWByCAT), 'IC-718 cannot key CW text over CAT');
   finally
      r.Free;
   end;
end;

procedure TRadioSupportsCapsTests.RunAllTests;
begin
   Test_CWByCATMatchesLegacySet;
   Test_PlayDVKMatchesLegacySet;
   Test_CWSpeedSyncMatchesLegacySet;
   Test_CWSpeedSyncIsWiderThanCWByCAT;
end;

end.

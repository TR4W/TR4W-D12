unit uTestIcomRegistry;
{$I ..\..\src\tr4w.inc}

{
  Guards the CI-V addresses and capability profiles of the migrated Icom radios.

  WHY THIS EXISTS.  Migrating the Icom family meant transcribing 28 CI-V addresses
  out of LOGRADIO's RadioParametersArray into registration code by hand.  A wrong
  address does not fail loudly -- the radio simply never answers, which looks
  exactly like a bad cable, the wrong COM port, or a baud mismatch, and would cost
  an operator an evening before anyone suspected the driver.

  So rather than trust the transcription, each registered radio is CONSTRUCTED
  THROUGH THE REGISTRY and its address compared against RadioParametersArray --
  the same table the legacy path uses.  The two cannot drift.

  This is a comparison against TR4W's own legacy data, so its authority is exactly
  that of the legacy table: it proves the migration preserved what the D7 program
  did, NOT that the addresses are right in absolute terms.  They have been in
  service for years, which is decent evidence, but a radio that never worked in D7
  will not work now either and this test would not notice.

  The capability assertions are the other half.  The split between the
  read-limited profile and the full one comes from LOGRADIO's own
  IcomRadiosThatSupportRIT / IcomRadiosThatSupportVFOB sets.  The test reads THOSE
  SETS DIRECTLY and compares them, model by model, with what each factory radio
  declares -- rather than spot-checking a representative, which would only prove
  that one radio matched somebody's summary of the sets.  Both directions fail:
  claiming a capability the sets withhold, and withholding one they grant.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioIcomBase,
   uRadioRegistry, LogRadio, VC;

type
   TIcomRegistryTests = class(TTestCase)
   protected
      procedure Test_EveryRegisteredIcom_MatchesLegacyAddress;
      procedure Test_EveryRegisteredIcom_MatchesLegacyCapabilities;
      procedure Test_RegistryCoversEveryCIVModel;
   public
      procedure RunAllTests; override;
   end;

implementation

function InModelList(m: InterfacedRadioType; const arr: array of InterfacedRadioType): Boolean;
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

// Build through the registry -- the same path the application uses -- so this
// also proves the registration closure works, not just that a class exists.
function Build(model: InterfacedRadioType): TFactoryRadioBase;
begin
   Result := CreateInstance(model);
end;

procedure TIcomRegistryTests.Test_EveryRegisteredIcom_MatchesLegacyAddress;
var
   m: InterfacedRadioType;
   r: TFactoryRadioBase;
   mismatches: string;
   checked: integer;
begin
   BeginTest('every CI-V radio sets the address the registry declares for it');
   mismatches := '';
   checked := 0;
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if not IsRegistered(m) then
         begin
         Continue;
         end;
      { ASK THE OBJECT, not a table, whether this is an Icom -- see the
        `r is TIcomRadio` guard below, which is now the only test. }
      r := Build(m);
      if r = nil then
         begin
         Continue;
         end;
      try
         if r is TIcomRadio then
            begin
            Inc(checked);
            if TIcomRadio(r).RadioAddress <> RegisteredCIVAddress(m) then
               begin
               mismatches := mismatches + Format('%s: driver $%2.2x, registry $%2.2x; ',
                  [RadioTypeToken(m), TIcomRadio(r).RadioAddress,
                   RegisteredCIVAddress(m)]);
               end;
            end;
      finally
         r.Free;
      end;
      end;
   // Guard the guard: if the loop matched nothing, an empty mismatch string would
   // pass while proving nothing at all.
   CheckTrue((checked > 20) and (mismatches = ''),
             Format('checked %d radios; mismatches: %s', [checked, mismatches]));
end;

procedure TIcomRegistryTests.Test_EveryRegisteredIcom_MatchesLegacyCapabilities;
var
   m: InterfacedRadioType;
   r: TFactoryRadioBase;
   wrong: string;
   checked: integer;

   // Report both directions.  Claiming a capability the radio lacks costs a
   // timeout (or a NAK) on every poll cycle; withholding one it has silently
   // drops RIT and VFO-B from the radio window.
   procedure Compare(cap: TRadioCapability; legacy: boolean; const what: string);
   begin
      if (cap in r.Capabilities.Flags) <> legacy then
         begin
         wrong := wrong + Format('%s: %s factory=%s legacy=%s; ',
            [RadioTypeToken(m), what,
             BoolToStr(cap in r.Capabilities.Flags, True), BoolToStr(legacy, True)]);
         end;
   end;

const
   // BENCH-PROVEN DIVERGENCES -- radios where the HARDWARE contradicts the legacy
   // sets, so the factory is deliberately right and the sets are stale.
   //
   // NY4I's testers established on real IC-706 / IC-706MkII / IC-706MkIIG / IC-7000
   // that split is NOT readable and TX status is NOT readable, even though none of
   // them appears in IcomRadiosSplitSetOnly or IcomRadiosTXStatusUnreadable (both
   // of which contain only the IC-718).  A bench beats the code it contradicts, so
   // these are excluded rather than the test being weakened.
   //
   // Do NOT add a model here to silence a failure.  A row belongs here only when
   // someone has had that radio on a bench.  Anything else is the migration
   // dropping behaviour, which is exactly what this test exists to catch.
   // The four LOGRADIO typesets these assertions used to read, transcribed here
   // ONCE.  The sets themselves were retired when the last live reader moved to
   // the radio's own rcReadRIT capability -- but the test must keep asserting
   // the same model lists, and transcribing them makes it INDEPENDENT of the
   // code under test (same rule as uTestRadioSupportsCaps).
   LEGACY_RIT_MODELS: array[0..12] of InterfacedRadioType = (
      IC705, IC7100, IC7300, IC7800, IC7850, IC7851, IC7600, IC7610, IC7700,
      IC7760, IC9700, IC905, IC7300MK2);
   LEGACY_VFOB_MODELS: array[0..12] of InterfacedRadioType = (
      IC705, IC7100, IC7300, IC7800, IC7850, IC7851, IC7600, IC7610, IC7700,
      IC7760, IC9700, IC905, IC7300MK2);
   LEGACY_SPLIT_SET_ONLY: array[0..0] of InterfacedRadioType = (IC718);
   LEGACY_TXSTATUS_UNREADABLE: array[0..0] of InterfacedRadioType = (IC718);

   BenchProvenDivergences = [IC706, IC706II, IC706IIG, IC7000];

begin
   // Walks the WHOLE registry against LOGRADIO's sets.  Checking a representative
   // model instead would only confirm that one radio agreed with someone's
   // summary of the sets -- and a summary is exactly what tends to be wrong.
   BeginTest('every registered CI-V radio''s RIT/VFO-B flags match LOGRADIO''s sets');
   wrong := '';
   checked := 0;
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      // Post-legacy radios are skipped: LOGRADIO's sets predate them, so
      // there is no legacy value to disagree with. See MarkPostLegacy.
      if (not IsRegistered(m)) or uRadioRegistry.RegisteredPostLegacy(m) then
         begin
         Continue;
         end;
      r := Build(m);
      if r = nil then
         begin
         Continue;
         end;
      try
         { CI-V ONLY, and the OBJECT is what says so. This used to read
           RadioParametersArray[m].rt = rtICOM, from a table that no longer
           exists; asking whether the driver IS a TIcomRadio is the same
           question put to the thing that actually knows. Without this the
           loop compares Kenwoods and Yaesus against Icom-specific lists
           and reports 100 disagreements -- which is exactly what it did
           for one build here. }
         if not (r is TIcomRadio) then
            begin
            Continue;
            end;
         Inc(checked);
         // All FOUR sets, not two.  An earlier version checked only RIT and VFOB
         // and passed while 26 radios were silently missing split and TX-status
         // reads that D7 performs -- the deny-lists below contain the IC-718 and
         // nothing else, so for every other model the answer is "yes".
         Compare(rcReadRIT, InModelList(m, LEGACY_RIT_MODELS), 'RIT');
         Compare(rcReadVFOB, InModelList(m, LEGACY_VFOB_MODELS), 'VFOB');
         // Family-wide, expected TRUE for every CI-V radio (deliberately
         // including the Omni VI, which is CI-V by mechanism but outside the
         // ICOMRadios enum range).  This assertion exists because the flag was
         // once Include'd BEFORE DefineCapabilities in TIcomRadio.Create, and
         // the `Flags := [...]` full replacement there silently wiped it --
         // every Icom answered False and the LOGSUBS1 Issue-145 guard never
         // fired.  No test covered it, so nothing failed.
         if not (m in BenchProvenDivergences) then
            begin
            Compare(rcReadSplit, not (InModelList(m, LEGACY_SPLIT_SET_ONLY)), 'Split');
            Compare(rcReadTXStatus, not (InModelList(m, LEGACY_TXSTATUS_UNREADABLE)), 'TXStatus');
            end;
      finally
         r.Free;
      end;
      end;
   CheckTrue((checked > 20) and (wrong = ''),
             Format('checked %d radios; disagreements: %s', [checked, wrong]));
end;

procedure TIcomRegistryTests.Test_RegistryCoversEveryCIVModel;
var
   m: InterfacedRadioType;
   r: TFactoryRadioBase;
   idText: string;
   idSeen: integer;
   missing: string;
begin
   // The point of the migration: no CI-V radio left on the legacy path.
   { WAS: 'every rtICOM model in the legacy table is registered'. That asked
     whether the migration had finished, and it finished in 2026-08. The
     question worth asking now is a factory invariant: a radio that BEHAVES
     as CI-V must have an address declared for it, because a missing one
     reads as the perfectly legal address $00 and the radio simply never
     answers. }
   BeginTest('every CI-V radio has a CI-V address declared in the registry');
   missing := '';
   idSeen := 0;
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if not IsRegistered(m) then
         begin
         Continue;
         end;
      r := Build(m);
      if r = nil then
         begin
         Continue;
         end;
      try
         if (r is TIcomRadio) and (RegisteredCIVAddress(m) = 0) then
            begin
            missing := missing + RadioTypeToken(m) + ' ';
            end;
      finally
         r.Free;
      end;
      end;
   { AND THE ID-ONLY RADIOS, which the loop above cannot see.

     This gap was not theoretical for a single day. The radio editor asked for
     the CI-V default with RegisteredCIVAddress(ModelForId(id)) -- a round trip
     through the enum -- so for the IC-7110 it got NoInterfacedRadio, then 0,
     then disabled the field. An Icom whose CI-V address the operator could not
     edit, on a radio that declares it perfectly well. NY4I found it on the
     bench the day after the radio was added; this test is what should have.

     The registry is keyed by id and has an ...Id form of every lookup. Asking
     by id is not an alternative spelling, it is the correct one. }
   for idText in uRadioRegistry.RegisteredIds do
      begin
      if uRadioRegistry.ModelForId(idText) <> NoInterfacedRadio then
         begin
         Continue;      { an enum radio -- covered above }
         end;
      r := uRadioRegistry.CreateInstanceId(idText);
      if r = nil then
         begin
         Continue;
         end;
      try
         Inc(idSeen);
         if (r is TIcomRadio) and (uRadioRegistry.RegisteredCIVAddressId(idText) = 0) then
            begin
            missing := missing + idText + ' ';
            end;
      finally
         r.Free;
      end;
      end;

   { Guard the guard. An id-only radio that constructs to nil, or a registry
     that returns no ids, would leave `missing` empty and the loop would report
     success while examining nothing -- which is precisely the shape of the bug
     it is here to catch. }
   CheckTrue(idSeen > 0,
             'no string-id radios were examined at all -- this check proves nothing');

   CheckEquals('', missing, 'CI-V radios with no declared address: ' + missing);
end;

procedure TIcomRegistryTests.RunAllTests;
begin
   Test_EveryRegisteredIcom_MatchesLegacyAddress;
   Test_EveryRegisteredIcom_MatchesLegacyCapabilities;
   Test_RegistryCoversEveryCIVModel;
end;

end.

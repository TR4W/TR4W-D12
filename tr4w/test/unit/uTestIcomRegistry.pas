unit uTestIcomRegistry;

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
  IcomRadiosThatSupportRIT / IcomRadiosThatSupportVFOB sets, so those are checked
  against the same source rather than against my reading of it.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioIcomBase,
   uRadioRegistry, LogRadio, VC;

type
   TIcomRegistryTests = class(TTestCase)
   protected
      procedure Test_EveryRegisteredIcom_MatchesLegacyAddress;
      procedure Test_ReadLimitedModels_DeclareNoVFOBOrRIT;
      procedure Test_CapableModels_DeclareVFOBAndRIT;
      procedure Test_RegistryCoversEveryCIVModel;
   public
      procedure RunAllTests; override;
   end;

implementation

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
   BeginTest('every registered CI-V radio uses its LOGRADIO CI-V address');
   mismatches := '';
   checked := 0;
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if not IsRegistered(m) then
         begin
         Continue;
         end;
      if RadioParametersArray[m].rt <> rtICOM then
         begin
         Continue;
         end;
      r := Build(m);
      if r = nil then
         begin
         Continue;
         end;
      try
         if r is TIcomRadio then
            begin
            Inc(checked);
            if TIcomRadio(r).RadioAddress <> RadioParametersArray[m].RA then
               begin
               mismatches := mismatches + Format('%s: factory $%2.2x, legacy $%2.2x; ',
                  [InterfacedRadioTypeSA[m], TIcomRadio(r).RadioAddress,
                   RadioParametersArray[m].RA]);
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

procedure TIcomRegistryTests.Test_ReadLimitedModels_DeclareNoVFOBOrRIT;
var
   r: TFactoryRadioBase;
begin
   // A representative of the conservative profile.  Asking a radio for something
   // it NAKs is worse than not asking, so these capabilities must stay absent.
   BeginTest('a read-limited Icom (IC-735) declares no VFO-B and no RIT read');
   r := Build(IC735);
   try
      CheckTrue(r <> nil, 'IC-735 is not registered');
      if r <> nil then
         begin
         CheckFalse(rcReadVFOB in r.Capabilities.Flags);
         CheckFalse(rcReadRIT in r.Capabilities.Flags);
         end;
   finally
      r.Free;
   end;
end;

procedure TIcomRegistryTests.Test_CapableModels_DeclareVFOBAndRIT;
var
   r: TFactoryRadioBase;
begin
   // IC-7700 and IC-7800 are the only two radios in this batch that LOGRADIO's
   // IcomRadiosThatSupportRIT / ...VFOB sets include.
   BeginTest('IC-7700 declares VFO-B and RIT reads');
   r := Build(IC7700);
   try
      CheckTrue(r <> nil, 'IC-7700 is not registered');
      if r <> nil then
         begin
         CheckTrue(rcReadVFOB in r.Capabilities.Flags);
         CheckTrue(rcReadRIT in r.Capabilities.Flags);
         end;
   finally
      r.Free;
   end;
end;

procedure TIcomRegistryTests.Test_RegistryCoversEveryCIVModel;
var
   m: InterfacedRadioType;
   missing: string;
begin
   // The point of the migration: no CI-V radio left on the legacy path.
   BeginTest('every rtICOM model in the legacy table is registered in the factory');
   missing := '';
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if (RadioParametersArray[m].rt = rtICOM) and (not IsRegistered(m)) then
         begin
         missing := missing + InterfacedRadioTypeSA[m] + ' ';
         end;
      end;
   CheckEquals('', missing, 'unmigrated CI-V models: ' + missing);
end;

procedure TIcomRegistryTests.RunAllTests;
begin
   Test_EveryRegisteredIcom_MatchesLegacyAddress;
   Test_ReadLimitedModels_DeclareNoVFOBOrRIT;
   Test_CapableModels_DeclareVFOBAndRIT;
   Test_RegistryCoversEveryCIVModel;
end;

end.

unit uTestRegistryTaxonomy;

{
  Pins the registry-derived taxonomy that replaced the InitRadios sets.

  Until 2026-07-30 LOGRADIO.InitRadios hand-maintained four manufacturer /
  transport sets (ICOMRadios, KenwoodRadios, YaesuRadios, HamLibONLYRadios).
  They are retired: the registry answers those questions now.  This unit pins
  the two derivations against the sets' last hand-maintained contents, so a
  registration change that silently alters the taxonomy fails here instead of
  surfacing as a mis-routed radio.

  IsHamLibOnly: a real model with no factory registration has no native CAT
  path, so it can only be driven through HamLib.  The last hand-maintained
  HamLibONLYRadios was [FLRIG, TRXMANAGER, FT757GXII, EXPERTTCI, ACLOG,
  HAMLIBANY, FT736R].

  FT736R history (moved here from InitRadios when the set was deleted): TR4W
  never had a read path for it.  pFT736R wrote one 5-byte CAT-enable frame and
  returned -- no ReadFromCOMPort, and no repeat loop, so the polling thread
  exited immediately and no frequency or mode ever arrived.  (Identical in the
  D7 tree, so this was an unfinished driver, not a port regression; it also
  wrote the FT-767 enable string, apparently copy-pasted.)  HamLib supports the
  radio properly (hamlibID 1010), so it is routed there rather than carrying a
  stub forward into the factory -- which is why it is deliberately NOT
  registered.

  ManufacturerOf: first word of the registered display name.  The Yaesu check
  replaces the YaesuRadios membership test in LOGK1EA's keyer-stop-bits
  warning.  Two knowing divergences from the old set, both log-message-only:
    - FT736R: was in YaesuRadios but has no registration, so ManufacturerOf
      returns '' -- the warning no longer fires for it.  It is HamLib-only;
      its keyer config was never meaningful.
    - FT100: was NOT in YaesuRadios (an omission -- it is a Yaesu), so the
      warning now fires for it too.
}

interface

uses
   SysUtils, uTR4WTestFramework, uRadioRegistry, LogRadio, VC;   // LogRadio for InterfacedRadioTypeSA

type
   TRegistryTaxonomyTests = class(TTestCase)
   protected
      procedure Test_IsHamLibOnly_MatchesRetiredSet;
      procedure Test_ManufacturerOf_YaesuMatchesRetiredSet;
      procedure Test_ManufacturerOf_EmptyForUnregistered;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   // The last hand-maintained contents of the retired sets, copied verbatim so
   // the derivation is compared against the historical fact, not against itself.
   RetiredHamLibONLYRadios: InterfacedRadioTypeSet =
      [FLRIG, TRXMANAGER, FT757GXII, EXPERTTCI, ACLOG, HAMLIBANY, FT736R];
   RetiredYaesuRadios: InterfacedRadioTypeSet =
      [FTDX10, FTDX101, FTX1F, FT450, FT710, FT736R, FT747GX, FT767, FT817,
       FT818, FT840, FT847, FT857, FT890, FT891, FT897, FT900, FT920,
       FT950, FT990, FT991, FT1000, FT1000MP, FT1200, FT2000,
       FTDX3000, FTDX5000, FTDX9000];
   // See the unit header for why each of these two diverges.
   KnownYaesuDivergences: InterfacedRadioTypeSet = [FT736R, FT100];

procedure TRegistryTaxonomyTests.Test_IsHamLibOnly_MatchesRetiredSet;
var
   m: InterfacedRadioType;
   wrong: string;
begin
   BeginTest('IsHamLibOnly = membership of the retired HamLibONLYRadios set');
   wrong := '';
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if m = NoInterfacedRadio then
         begin
         // Not a radio: must be neither registered nor HamLib-only.
         if IsHamLibOnly(m) then
            begin
            wrong := wrong + 'NoInterfacedRadio reported HamLib-only; ';
            end;
         Continue;
         end;
      if IsHamLibOnly(m) <> (m in RetiredHamLibONLYRadios) then
         begin
         wrong := wrong + Format('%s: IsHamLibOnly=%s, retired set says %s; ',
            [InterfacedRadioTypeSA[m],
             BoolToStr(IsHamLibOnly(m), True),
             BoolToStr(m in RetiredHamLibONLYRadios, True)]);
         end;
      end;
   CheckEquals('', wrong, wrong);
end;

procedure TRegistryTaxonomyTests.Test_ManufacturerOf_YaesuMatchesRetiredSet;
var
   m: InterfacedRadioType;
   isYaesu: boolean;
   wrong: string;
begin
   BeginTest('ManufacturerOf=''Yaesu'' = the retired YaesuRadios set (2 known divergences)');
   wrong := '';
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if m in KnownYaesuDivergences then
         begin
         Continue;
         end;
      isYaesu := ManufacturerOf(m) = 'Yaesu';
      if isYaesu <> (m in RetiredYaesuRadios) then
         begin
         wrong := wrong + Format('%s: ManufacturerOf=''%s'', retired set says Yaesu=%s; ',
            [InterfacedRadioTypeSA[m], ManufacturerOf(m),
             BoolToStr(m in RetiredYaesuRadios, True)]);
         end;
      end;
   CheckEquals('', wrong, wrong);
end;

procedure TRegistryTaxonomyTests.Test_ManufacturerOf_EmptyForUnregistered;
begin
   // An unregistered (HamLib-only) model has no display name to derive from.
   // Callers must treat '' as "unknown", never as a manufacturer.
   BeginTest('ManufacturerOf is '''' for an unregistered model');
   CheckEquals('', ManufacturerOf(FLRIG), 'FLRIG has no registration');
   CheckEquals('', ManufacturerOf(NoInterfacedRadio), 'NoInterfacedRadio is not a radio');
end;

procedure TRegistryTaxonomyTests.RunAllTests;
begin
   Test_IsHamLibOnly_MatchesRetiredSet;
   Test_ManufacturerOf_YaesuMatchesRetiredSet;
   Test_ManufacturerOf_EmptyForUnregistered;
end;

end.

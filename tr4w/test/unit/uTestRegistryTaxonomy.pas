unit uTestRegistryTaxonomy;
{$I ..\..\src\tr4w.inc}

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
   SysUtils, Classes, TypInfo, uTR4WTestFramework, uRadioRegistry, VC;

type
   TRegistryTaxonomyTests = class(TTestCase)
   protected
      procedure Test_IsHamLibOnly_MatchesRetiredSet;
      procedure Test_ManufacturerOf_YaesuMatchesRetiredSet;
      procedure Test_ManufacturerOf_EmptyForUnregistered;
      procedure Test_HamLibOnlyRegistrations;
      procedure Test_NetworkCredentialsArePinned;
      procedure Test_EveryNetworkRadioDeclaresCredentialsEitherWay;
      procedure Test_ConfigTokensAreTheEnumNamesOrDeclared;
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
   // Knowing divergences from the retired YaesuRadios set (see unit header):
   // - FT100: a Yaesu the old set simply omitted -- the keyer warning now
   //   correctly covers it.
   // - FT757GXII: a Yaesu the old set omitted because it was HamLib-only;
   //   since the bridges registered (2026-07-30) its display name declares
   //   the manufacturer, so the warning covers it too.
   // (FT736R left this list the same day: once registered as
   // 'Yaesu FT-736R (via HamLib)' it AGREES with the retired set again.)
   KnownYaesuDivergences: InterfacedRadioTypeSet = [FT100, FT757GXII];

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
            [RadioTypeToken(m),
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
            [RadioTypeToken(m), ManufacturerOf(m),
             BoolToStr(m in RetiredYaesuRadios, True)]);
         end;
      end;
   CheckEquals('', wrong, wrong);
end;

procedure TRegistryTaxonomyTests.Test_ManufacturerOf_EmptyForUnregistered;
begin
   // Since the bridges registered (2026-07-30) every real model has a display
   // name; only the not-a-radio sentinel derives nothing.
   BeginTest('ManufacturerOf is '''' only for NoInterfacedRadio');
   CheckEquals('', ManufacturerOf(NoInterfacedRadio), 'NoInterfacedRadio is not a radio');
   CheckEquals('FLRig', ManufacturerOf(FLRIG), 'bridges carry display names now');
end;

procedure TRegistryTaxonomyTests.Test_HamLibOnlyRegistrations;
var
   m: InterfacedRadioType;
   bad: string;

   procedure CheckID(model: InterfacedRadioType; want: Integer; const why: string);
   begin
      if RegisteredHamLibID(model) <> want then
         begin
         bad := bad + Format('%s: hamlibID %d, want %d (%s); ',
            [RadioTypeToken(model), RegisteredHamLibID(model), want, why]);
         end;
   end;

begin
   // The seven HamLib-only rows registered by uRadioHamLibOnly: each must be
   // registered, flagged, and carry its riglist.h default rig_model verbatim
   // from the legacy RadioParametersArray (HAMLIBANY's 1 is a placeholder --
   // the RADIO n HAMLIB ID config supplies the real one at connect).
   BeginTest('the seven HamLib-only models register with their default rig_models');
   bad := '';
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if (m in RetiredHamLibONLYRadios) and (not IsRegistered(m)) then
         begin
         bad := bad + RadioTypeToken(m) + ': not registered; ';
         end;
      end;
   CheckID(FLRIG, 4, 'RIG_MODEL_FLRIG');
   CheckID(TRXMANAGER, 5, 'RIG_MODEL_TRXMANAGER_RIG');
   CheckID(EXPERTTCI, 7, 'RIG_MODEL_TCI1X');
   CheckID(ACLOG, 8, 'RIG_MODEL_ACLOG');
   CheckID(HAMLIBANY, 1, 'placeholder; config supplies the real ID');
   CheckID(FT736R, 1010, 'RIG_MODEL_FT736R');
   CheckID(FT757GXII, 1007, 'RIG_MODEL_FT757GX2');
   // And a native radio must NOT carry a hamlib-only registration.
   if IsHamLibOnly(IC7300) then
      begin
      bad := bad + 'IC7300 flagged hamlibOnly; ';
      end;
   CheckEquals('', bad, bad);
end;

{ WHICH NETWORK RADIOS AUTHENTICATE -- exhaustive, and it fails on a radio that
  is not listed.

  "Network" and "wants a username" are different questions. The Elecraft K4 is
  reached over TCP 9200 with no login; every network Icom and both Kenwood LAN
  radios want user and password. The radio editor greys the credential fields on
  what the registry says here, so a model that forgets to declare it offers no
  fields and then cannot log in -- a silent failure that looks like a network
  fault rather than a missing declaration.

  The list is the AUTHORITY, not a sample: the second test below fails if any
  network-capable radio is missing from it, so adding one forces a decision. }
const
   { ENUM RADIOS ONLY. An id-only radio (RegisterRadioById) has no member here
     to name, so this list cannot see one and the loop that walks it does not
     either -- the IC-7110 declares its credentials and is invisible to this
     pin. That is a real gap for id-only network radios and it grows as more
     radios move off the enum; the check wants re-expressing over RegisteredIds
     when they do. }
   CREDENTIALED_NETWORK_RADIOS: array[0..11] of InterfacedRadioType =
      (IC705, IC7300MK2, IC7600, IC7610, IC7700, IC7760, IC7850, IC7851, IC905,
       IC9700, TS890, TS990);

   { Network-capable and deliberately WITHOUT credentials. Named rather than
     merely absent, so "nobody looked at this one" cannot masquerade as "this one
     does not authenticate". }
   OPEN_NETWORK_RADIOS: array[0..1] of InterfacedRadioType = (K4, FLEX);

function InSet(model: InterfacedRadioType;
               const list: array of InterfacedRadioType): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(list) to High(list) do
      begin
      if list[i] = model then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

procedure TRegistryTaxonomyTests.Test_NetworkCredentialsArePinned;
var
   m: InterfacedRadioType;
   expected: boolean;
begin
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if not IsRegistered(m) then
         begin
         Continue;
         end;

      expected := InSet(m, CREDENTIALED_NETWORK_RADIOS);
      Check(RegisteredNetworkCredentials(m) = expected,
            Format('%s: the registry says credentials=%s, the pinned list says %s',
                   [DisplayName(m),
                    BoolToStr(RegisteredNetworkCredentials(m), True),
                    BoolToStr(expected, True)]));
      end;
end;

procedure TRegistryTaxonomyTests.Test_EveryNetworkRadioDeclaresCredentialsEitherWay;
var
   m: InterfacedRadioType;
begin
   // A NETWORK radio must appear in one list or the other. Being in neither
   // means nobody decided, and the default (no credentials) would quietly become
   // the answer.
   for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if (not IsRegistered(m)) or (RegisteredNetworkPort(m) <= 0) then
         begin
         Continue;
         end;

      Check(InSet(m, CREDENTIALED_NETWORK_RADIOS) or InSet(m, OPEN_NETWORK_RADIOS),
            Format('%s is a network radio (port %d) but appears in neither the ' +
                   'credentialed nor the open list -- say which it is',
                   [DisplayName(m), RegisteredNetworkPort(m)]));
      end;
end;

procedure TRegistryTaxonomyTests.Test_ConfigTokensAreTheEnumNamesOrDeclared;
{ THE REGRESSION PIN FOR A REAL DEFECT, found 2026-08-28.

  'RADIO ONE MODEL = TS450' is matched against the token list and the INDEX of
  the hit becomes the enum value. LOGRADIO used to hold that list by hand,
  beside the enum in VC.pas -- two copies of one thing. It was missing TS140
  and carried a TS530 the enum never had, so four Kenwoods were off by one: a
  config saying TS440 selected the TS-140 driver, TS450 selected the TS-440,
  and TS140 could not be selected at all. Nothing failed. The names simply
  lined up against the wrong radios.

  The token is derived from the enum now, so that class of drift is gone. What
  is still possible is a careless MarkConfigToken, which is what this pins:
  every token is either the enum name or one of the handful deliberately
  declared, and no two models share one. }
var
   m:     InterfacedRadioType;
   token: string;
   seen:  TStringList;
   bad:   string;
   n:     integer;
begin
   BeginTest('every config token is the enum name, or a declared exception, and unique');
   bad := '';
   n := 0;
   seen := TStringList.Create;
   try
      seen.Sorted := True;
      for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
         begin
         if (m <> NoInterfacedRadio) and (not IsRegistered(m)) then
            begin
            Continue;
            end;
         token := RadioTypeToken(m);
         Inc(n);
         if token = '' then
            begin
            bad := bad + GetEnumName(TypeInfo(InterfacedRadioType), Ord(m)) + ': empty; ';
            end
         else if seen.IndexOf(token) >= 0 then
            begin
            bad := bad + token + ': duplicated; ';
            end
         else
            begin
            seen.Add(token);
            end;
         end;
   finally
      seen.Free;
   end;

   { The four the old table got wrong. Spelled out rather than derived, so this
     still fails if someone reintroduces a hand-maintained list. }
   CheckEquals('TS140', RadioTypeToken(TS140), 'TS140 token');
   CheckEquals('TS440', RadioTypeToken(TS440), 'TS440 token');
   CheckEquals('TS450', RadioTypeToken(TS450), 'TS450 token');
   CheckEquals('TS480', RadioTypeToken(TS480), 'TS480 token');

   { The deliberate exceptions -- existing configs spell these differently and
     must keep parsing. }
   CheckEquals('NONE',        RadioTypeToken(NoInterfacedRadio), 'no-radio token');
   CheckEquals('IC910H',      RadioTypeToken(IC910),      'IC910 token');
   CheckEquals('FTX-1',       RadioTypeToken(FTX1F),      'FTX1F token');
   CheckEquals('TRX-MANAGER', RadioTypeToken(TRXMANAGER), 'TRXMANAGER token');
   CheckEquals('HAMLIB-ANY',  RadioTypeToken(HAMLIBANY),  'HAMLIBANY token');

   { Guard the guard: an empty loop would report no duplicates at all. }
   CheckTrue((n > 90) and (bad = ''),
             Format('checked %d tokens; problems: %s', [n, bad]));
end;

procedure TRegistryTaxonomyTests.RunAllTests;
begin
   Test_IsHamLibOnly_MatchesRetiredSet;
   Test_ManufacturerOf_YaesuMatchesRetiredSet;
   Test_ManufacturerOf_EmptyForUnregistered;
   Test_HamLibOnlyRegistrations;
   Test_NetworkCredentialsArePinned;
   Test_EveryNetworkRadioDeclaresCredentialsEitherWay;
   Test_ConfigTokensAreTheEnumNamesOrDeclared;
end;

end.

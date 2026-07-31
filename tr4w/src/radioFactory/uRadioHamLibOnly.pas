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
unit uRadioHamLibOnly;

{
  Registrations for the HAMLIB-ONLY radios -- the seven models with no native
  TR4W driver, driven through THamLibDirect: the software bridges (FLRig,
  TRX-Manager, Expert TCI, N3FJP ACLog, and the "any HamLib rig" entry) plus
  two real rigs whose only driver is a HamLib backend (FT-736R, FT-757GXII).

  WHY ONE UNIT AND NOT ONE PER MODEL.  The "one unit per radio" rule exists so
  every radio with a CLASS has a home a developer can copy.  These seven share
  ONE class (THamLibDirect) and differ only in registration DATA -- a display
  name and a default hamlib rig_model.  A model that later grows a native
  driver moves OUT of this unit into its own (exactly how the Orion left the
  HamLib-only list when pOrion3 was ported).

  WHY REGISTER AT ALL.  Until 2026-07-30 these models were expressed by NOT
  being registered ("native = registered").  Building the CAT dialog's radio
  drop-down from the registry requires every selectable model to be a
  registration, so they now carry an explicit hamlibOnly flag instead
  (uRadioRegistry.IsHamLibOnly reads it; uTestRegistryTaxonomy still pins the
  membership against the retired HamLibONLYRadios set).

  The hamlibID stored here is the DEFAULT rig_model handed to HamLib
  (riglist.h numbering, verified against the reference checkout); the
  RADIO n HAMLIB ID config command overrides it at connect, which is the whole
  point of HAMLIBANY (its stored ID 1 = the hamlib dummy rig is a placeholder).

  Serial defaults mirror the legacy RadioParametersArray rows: the TCP-based
  software bridges carry 57600 (what rigctld-style links use); the two real
  rigs their CAT rates.  HamLib itself owns the transport once connected --
  these values seed the dialog, nothing more.

  RUNTIME PATH NOTE: connection still flows through SetUpRadioInterface's
  UseHamLib branch (TRadioFactory.CreateHamLibDirect).  IsHamLibOnly forces
  UseHamLib=True for every model in this unit, so the registered closures
  below are exercised by capability queries (CapabilitiesFor) and future
  registry-driven creation, not by today's connect path.
}

interface

uses uFactoryRadioBase, uRadioHamLibDirect, VC, uRadioRegistry;

implementation

// One closure body shared by all seven registrations: a THamLibDirect
// preconfigured with the model's default hamlib rig_model.  The display name
// is taken from the model's own registration (this runs at CreateInstance
// time, after registration) -- deliberately NOT a string literal here, so the
// registry lint's "the ctor contains no string literals" extraction rule
// holds for this call form too.
function MakeHamLibRadio(model: InterfacedRadioType; hamlibID: Integer): TFactoryRadioBase;
begin
   Result := THamLibDirect.Create;
   THamLibDirect(Result).HamLibModelID := hamlibID;
   Result.radioModel := uRadioRegistry.DisplayName(model);
end;

initialization
   // Software bridges (TCP links to other programs; hamlib "dummy" backend family).
   RegisterHamLibOnlyRadio(FLRIG,
      function: TFactoryRadioBase begin Result := MakeHamLibRadio(FLRIG, 4) end,
      'FLRig (HamLib bridge)', 4,
      SerialParams(57600, 8, PARITY_NONE, 2));
   RegisterHamLibOnlyRadio(TRXMANAGER,
      function: TFactoryRadioBase begin Result := MakeHamLibRadio(TRXMANAGER, 5) end,
      'TRX-Manager (HamLib bridge)', 5,
      SerialParams(57600, 8, PARITY_NONE, 2));
   RegisterHamLibOnlyRadio(EXPERTTCI,
      function: TFactoryRadioBase begin Result := MakeHamLibRadio(EXPERTTCI, 7) end,
      'Expert TCI (HamLib bridge)', 7,
      SerialParams(57600, 8, PARITY_NONE, 2));
   RegisterHamLibOnlyRadio(ACLOG,
      function: TFactoryRadioBase begin Result := MakeHamLibRadio(ACLOG, 8) end,
      'N3FJP ACLog (HamLib bridge)', 8,
      SerialParams(57600, 8, PARITY_NONE, 2));
   // "Any rig HamLib knows" -- the stored ID 1 (hamlib dummy) is a placeholder;
   // the real rig_model ALWAYS comes from the RADIO n HAMLIB ID config command.
   RegisterHamLibOnlyRadio(HAMLIBANY,
      function: TFactoryRadioBase begin Result := MakeHamLibRadio(HAMLIBANY, 1) end,
      'HamLib (any supported rig)', 1,
      SerialParams(57600, 8, PARITY_NONE, 2));

   // Real radios whose only driver is a HamLib backend.
   // FT-736R: TR4W never had a working native read path (the legacy pFT736R
   // stub wrote one enable frame and returned) -- hamlib 1010 drives it properly.
   RegisterHamLibOnlyRadio(FT736R,
      function: TFactoryRadioBase begin Result := MakeHamLibRadio(FT736R, 1010) end,
      'Yaesu FT-736R (via HamLib)', 1010,
      SerialParams(4800, 8, PARITY_NONE, 2));
   RegisterHamLibOnlyRadio(FT757GXII,
      function: TFactoryRadioBase begin Result := MakeHamLibRadio(FT757GXII, 1007) end,
      'Yaesu FT-757GXII (via HamLib)', 1007,
      SerialParams(4800, 8, PARITY_NONE, 2));

end.

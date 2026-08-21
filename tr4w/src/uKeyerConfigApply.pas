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
unit uKeyerConfigApply;
{$I tr4w.inc}

{
  Puts a keyer DEFINITION into the live program state.

  THIS UNIT IS NOW LOAD-BEARING, not a convenience.  The seventeen WK command
  rows were retired to csJSON, so CheckCommand no longer applies them and the
  ini no longer configures the WinKeyer at all.  If this unit does not push a
  device's settings into WinKeySettings, they are simply lost -- which is why
  the retirement and this code belong to the same piece of work.

  WHAT IT TOUCHES.  uWinKey's WinKeySettings record, which is a PACKED record
  with reserved bytes: it mirrors a wire/persistence layout, so fields are
  assigned individually and the record is never rebuilt wholesale.

  RESOLUTION, not policy.  Deciding WHICH keyer a slot uses is the profile's
  business; this unit is told the device and writes it out.  The vocabularies
  (KeyerModeSA, SidetoneFrequencySA, PortTypeSA) are the legacy spellings the
  store holds as strings, mapped back to their enums here -- the one place that
  translation belongs, since a wrong spelling silently selects the wrong value.
}

interface

uses
   uKeyerConfigStore;

// Writes the device's settings into WinKeySettings.  Returns False with a
// reason when a stored vocabulary value is not one the program knows, rather
// than silently substituting a default -- a WinKeyer quietly running in the
// wrong keyer mode is the kind of fault an operator blames on the hardware.
function ApplyKeyerToWinKey(const aKeyer: TKeyerDefinition; out aError: string): boolean;

// Whether the WinKeyer is in use at all.  Separate from ApplyKeyerToWinKey
// because that is a property of the PROFILE, not of the device: the same keyer
// sits on the desk whether or not tonight's profile keys through it.  Exposed
// here so this unit stays the only one that touches WinKeySettings.
procedure SetWinKeyerEnabled(const aEnabled: boolean);

{ Seed ONE WinKeyer into an EMPTY keyer library from the legacy WinKeySettings,
  returning True if it added one so the caller knows to write the file.

  IT LIVES HERE, not in uRadioConfigApply where it is called from, because this
  unit is the only one that touches WinKeySettings -- see SetWinKeyerEnabled
  above.  Writing the seed there would have meant exporting the enum-typed
  spelling converters and letting another unit read the legacy record, which is
  exactly the boundary this unit exists to hold. }
function SeedKeyerLibraryFromLegacy(const aKeyers: TKeyerConfigStore): boolean;

implementation

uses
   SysUtils,
   uWinKey,
   Tree,       // PortType / PortTypeSA -- the port vocabulary the store's strings use
   VC;

// The vocabulary lookups are written out rather than done with an index,
// because the STORE holds a spelling and the program holds an enum, and an
// index would re-point silently the next time either list changed.  Returning
// False on an unknown spelling is deliberate: see the interface note.
procedure SetWinKeyerEnabled(const aEnabled: boolean);
begin
   WinKeySettings.wksWinKey2Enable := aEnabled;
end;

function SeedKeyerLibraryFromLegacy(const aKeyers: TKeyerConfigStore): boolean;
var
   k: TKeyerDefinition;
begin
   // WHY THIS EXISTS.  The seventeen WK rows are csJSON, so an upgrading
   // station's WinKeyer settings are carried into the store and applied into
   // WinKeySettings -- the keyer KEYS correctly.  But the editor does not read
   // WinKeySettings; it reads the keyer LIBRARY, and nothing ever seeded that.
   //
   // So on a station that had a WinKeyer configured, every option applied and
   // none of them could be seen or changed: "where did all those winkeyer
   // options go?" (NY4I, 2026-08-21).  They had not gone anywhere, which is
   // exactly what made it hard to see.
   //
   // Same shape as the rotator library, which seeds one rotator from the legacy
   // ROTATOR TYPE / ROTATOR PORT for the same reason.
   Result := False;

   if aKeyers = nil then
      begin
      Exit;
      end;

   // ONLY INTO AN EMPTY LIBRARY.  An operator who has defined keyers has said
   // what they want, and a legacy record must not add a phantom device beside
   // them on every start.
   if aKeyers.KeyerCount > 0 then
      begin
      Exit;
      end;

   // NOTHING TO SEED FROM.  A station that never enabled a WinKeyer should get
   // an empty list, not a device it has to work out how to delete.
   if not WinKeySettings.wksWinKey2Enable then
      begin
      Exit;
      end;

   k := aKeyers.AddKeyer(aKeyers.UniqueKeyerName('WinKeyer'), kkWinKeyer);
   if k = nil then
      begin
      Exit;
      end;

   // NO "Enabled" IS SET, because a keyer definition has no such field: whether
   // the WinKeyer is in use is a property of the PROFILE, settled by
   // ApplyKeyersForProfile.  See SetWinKeyerEnabled.  The seed describes the
   // DEVICE on the desk and nothing more.
   //
   // SPELLINGS, through the same arrays the FromString functions read back --
   // the store holds 'SERIAL 1' and 'IAMBIC B', not ordinals.
   k.Port    := string(PortTypeSA[WinKeySettings.wksWinKey2Port]);

   k.WKAutospace          := WinKeySettings.wksAutospace;
   k.WKCTSpacing          := WinKeySettings.wksCTSpacing;
   k.WKIgnoreSpeedPot     := WinKeySettings.wksIgnoreSpeedSpot;
   k.WKSidetoneEnable     := WinKeySettings.wksSideTEnable;
   k.WKPaddleOnlySidetone := WinKeySettings.wksPadOnlySideT;
   k.WKPaddleSwap         := WinKeySettings.wksPaddleSwap;

   k.WKKeyerMode          := string(KeyerModeSA[WinKeySettings.wksKeyerMode]);
   k.WKSidetoneFrequency  := string(SidetoneFrequencySA[WinKeySettings.wksValueList.vlSidetoneFrequency]);

   k.WKWeight             := WinKeySettings.wksValueList.vlWeight;
   k.WKDitDahRatio        := WinKeySettings.wksValueList.vlDitDahRatio;
   k.WKLeadInTime         := WinKeySettings.wksValueList.vlLeadInTime;
   k.WKTailTime           := WinKeySettings.wksValueList.vlTailTime;
   k.WKFirstExtension     := WinKeySettings.wksValueList.vl1stExtension;
   k.WKKeyerCompensation  := WinKeySettings.wksValueList.vlKeyCompensation;
   k.WKPaddleSwitchpoint  := WinKeySettings.wksValueList.vlPaddleSWPoint;

   // NOT LOGGED HERE.  This unit has no logger and deliberately no MainUnit
   // dependency; the caller has both and reports it.
   Result := True;
end;

function KeyerModeFromString(const aText: string; out aMode: TWK2KeyerMode): boolean;
var
   m: TWK2KeyerMode;
begin
   Result := False;
   aMode := kmIambicB;
   for m := Low(TWK2KeyerMode) to High(TWK2KeyerMode) do
      begin
      if SameText(Trim(aText), string(KeyerModeSA[m])) then
         begin
         aMode := m;
         Result := True;
         Exit;
         end;
      end;
end;

function SidetoneFromString(const aText: string; out aFreq: TWKSidetoneFrequency): boolean;
var
   f: TWKSidetoneFrequency;
begin
   Result := False;
   aFreq := stf800;
   for f := Low(TWKSidetoneFrequency) to High(TWKSidetoneFrequency) do
      begin
      if SameText(Trim(aText), string(SidetoneFrequencySA[f])) then
         begin
         aFreq := f;
         Result := True;
         Exit;
         end;
      end;
end;

function PortFromString(const aText: string; out aPort: PortType): boolean;
var
   p: PortType;
begin
   Result := False;
   aPort := NoPort;
   for p := Low(PortType) to High(PortType) do
      begin
      if SameText(Trim(aText), string(PortTypeSA[p])) then
         begin
         aPort := p;
         Result := True;
         Exit;
         end;
      end;
end;

function ApplyKeyerToWinKey(const aKeyer: TKeyerDefinition; out aError: string): boolean;
var
   port: PortType;
   mode: TWK2KeyerMode;
   freq: TWKSidetoneFrequency;

   // A stored 0 means "leave it to the device", the convention the whole store
   // uses. Only a stated value overwrites what the WinKeyer already has.
   procedure SetByte(var aTarget: Byte; const aValue: integer);
   begin
      if aValue > 0 then
         begin
         aTarget := Byte(aValue);
         end;
   end;

begin
   aError := '';
   Result := False;

   if aKeyer = nil then
      begin
      aError := 'No keyer supplied.';
      Exit;
      end;

   if aKeyer.Kind <> kkWinKeyer then
      begin
      // A YCCC box is a different device with its own settings; this routine
      // speaks only WinKeyer. Reported rather than silently doing nothing.
      aError := Format('"%s" is not a WinKeyer.', [aKeyer.Name]);
      Exit;
      end;

   if not PortFromString(aKeyer.Port, port) then
      begin
      aError := Format('Keyer "%s" has an unrecognised port "%s".',
                       [aKeyer.Name, aKeyer.Port]);
      Exit;
      end;

   // The PORT only.  Whether the WinKeyer is IN USE is a property of the
   // profile, not of the device, so wksWinKey2Enable is settled once per
   // profile by the caller -- see ApplyKeyersForProfile.  Enabling it here
   // would mean a profile that stops using the keyer could never turn it off,
   // because nothing would run to say so.
   WinKeySettings.wksWinKey2Port := port;

   if Trim(aKeyer.WKKeyerMode) <> '' then
      begin
      if not KeyerModeFromString(aKeyer.WKKeyerMode, mode) then
         begin
         aError := Format('Keyer "%s" has an unrecognised keyer mode "%s".',
                          [aKeyer.Name, aKeyer.WKKeyerMode]);
         Exit;
         end;
      WinKeySettings.wksKeyerMode := mode;
      end;

   if Trim(aKeyer.WKSidetoneFrequency) <> '' then
      begin
      if not SidetoneFromString(aKeyer.WKSidetoneFrequency, freq) then
         begin
         aError := Format('Keyer "%s" has an unrecognised sidetone frequency "%s".',
                          [aKeyer.Name, aKeyer.WKSidetoneFrequency]);
         Exit;
         end;
      WinKeySettings.wksValueList.vlSidetoneFrequency := freq;
      end;

   WinKeySettings.wksAutospace       := aKeyer.WKAutospace;
   WinKeySettings.wksCTSpacing       := aKeyer.WKCTSpacing;
   WinKeySettings.wksIgnoreSpeedSpot := aKeyer.WKIgnoreSpeedPot;
   WinKeySettings.wksSideTEnable     := aKeyer.WKSidetoneEnable;
   WinKeySettings.wksPadOnlySideT    := aKeyer.WKPaddleOnlySidetone;
   WinKeySettings.wksPaddleSwap      := aKeyer.WKPaddleSwap;

   SetByte(WinKeySettings.wksValueList.vlWeight,          aKeyer.WKWeight);
   SetByte(WinKeySettings.wksValueList.vlLeadInTime,      aKeyer.WKLeadInTime);
   SetByte(WinKeySettings.wksValueList.vlTailTime,        aKeyer.WKTailTime);
   SetByte(WinKeySettings.wksValueList.vlDitDahRatio,     aKeyer.WKDitDahRatio);
   SetByte(WinKeySettings.wksValueList.vl1stExtension,    aKeyer.WKFirstExtension);
   SetByte(WinKeySettings.wksValueList.vlKeyCompensation, aKeyer.WKKeyerCompensation);
   SetByte(WinKeySettings.wksValueList.vlPaddleSWPoint,   aKeyer.WKPaddleSwitchpoint);

   Result := True;
end;

end.

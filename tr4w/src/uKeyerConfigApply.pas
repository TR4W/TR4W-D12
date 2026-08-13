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

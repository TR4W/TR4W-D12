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
unit uRadioConfigStore;

{
  A LIBRARY OF RADIO DEFINITIONS, and the station profiles that put two of them
  on the air.

  WHY THIS EXISTS.  TR4W has exactly two radio slots and the configuration IS
  those slots: the ini holds RADIO ONE TYPE, RADIO ONE CONTROL PORT and so on,
  so describing a radio and activating it are the same act.  An operator with
  four rigs on the bench therefore retypes a whole slot every time they change
  which one is connected -- port, baud, CI-V address, keyer lines, the lot --
  and a mistake is not visible until the radio fails to answer.  TR4QT solved
  this by separating the two ideas, and this unit is that separation: DEFINE
  many radios once, then ACTIVATE a pair of them by choosing a profile.

  WHAT IT IS AND IS NOT.  This unit is a pure data store.  It holds the
  library, validates it, and reads/writes it as an ini file.  It knows nothing
  about the radio registry, the CAT layer, the legacy [Radio] keys, or any UI.
  Turning a definition into live TR4W configuration is uRadioConfigApply's job
  (Phase 2), and choosing definitions in a dialog is the FMX preferences UI's
  (Phase 3).  Keeping that line sharp is what makes this unit testable without
  booting the application's globals -- the contest engine's global state is
  precisely what makes most of TR4W untestable, and this is deliberately on the
  other side of that line.

  It is also the reason the radio TYPE is held as an opaque registry id STRING
  rather than the InterfacedRadioType enum: a string has no dependency on VC.pas
  and survives a registry that gains models.  Whether a given id is real is a
  question for the apply layer and the UI, both of which have uRadioRegistry.

  ON UNIT DEPENDENCIES.  SysUtils, Classes, IniFiles and Generics.Collections --
  all RTL, no VCL, no FMX, no TR4W unit at all.  That is not tidiness for its
  own sake: it is what lets test/unit link this without MainUnit, and what
  would let the store move to a non-Windows target later.

  ON PERSISTENCE.  Load/Save take a TCustomIniFile the CALLER owns.  Production
  passes a TIniFile over settings\tr4wradios.ini; tests pass a TMemIniFile and
  never touch the disk.  The file is deliberately SEPARATE from tr4w.ini: the
  legacy [Radio] section is rewritten wholesale by GroupRadioIniKeys, so a
  shared file would mean each system could silently discard the other's work.

  ON PASSWORDS.  NetworkPassword round-trips in plaintext.  That is the status
  quo -- the legacy RADIO ONE NETWORK PASSWORD key is plaintext in tr4w.ini
  today, and this unit deliberately does not change the security posture while
  changing the storage location.  Encrypting it (DPAPI) is a follow-up that
  should cover both files at once, not a thing to do by halves here.
}

interface

uses
   System.SysUtils,
   System.StrUtils,      // StartsText, for the section-name prefixes
   System.Classes,
   System.IniFiles,
   System.Generics.Collections;

type
   // How TR4W reaches the radio.  This is a property of the DEFINITION, not of
   // the model: a K4 can be driven over serial or over the network, and the
   // operator may well have a definition of each.
   TRadioTransport = (rtSerial, rtNetwork);

   { One radio the operator owns, described completely enough to put it on the
     air without visiting any other dialog.

     The field list is a full sweep of the RADIO ONE/RADIO TWO rows in uCFG's
     CFGCA -- every key the legacy dialog can write, so that activating a
     definition leaves nothing behind from the previously active radio.  The
     rows marked csRem there (COMMAND PAUSE, ID CHARACTER, TRACKING ENABLE,
     UPDATE SECONDS) are RETIRED: CFGCA still accepts them from an old ini so
     it does not error, but they drive nothing, so they are absent here by
     intent rather than by oversight. }
   TRadioDefinition = class(TObject)
   public
      // Identity.  Name is the key the operator sees and profiles refer to, so
      // it is unique within a store and renaming has to fix the references
      // (see TRadioConfigStore.RenameRadio).
      Name: string;
      // Registry id, e.g. 'K3', 'IC7300', 'TCI', 'HAMLIBANY'.  Opaque here.
      RegistryId: string;
      Transport: TRadioTransport;

      // --- serial transport ------------------------------------------------
      // ControlPort is the PortTypeSA vocabulary ('SERIAL 15', 'NONE') -- the
      // NAME, never a combo index.  An index would silently re-point at a
      // different port the next time the machine enumerates differently.
      ControlPort: string;
      BaudRate: integer;          // 0 = leave to the registry/model default
      SerialFormat: string;       // '8N1' etc.; '' = registry default
      CatRTS: string;             // tr4w_RTSDTRType vocabulary
      CatDTR: string;

      // --- network transport -----------------------------------------------
      IPAddress: string;
      TCPPort: integer;           // 0 = the model's default port
      NetworkUsername: string;
      NetworkPassword: string;    // plaintext -- see the unit header

      // --- keyer lines on this radio's port --------------------------------
      KeyerOutputPort: string;
      KeyerRTS: string;
      KeyerDTR: string;
      KeyerStopBits: integer;

      // --- CW ---------------------------------------------------------------
      CWByCAT: boolean;
      CWSpeedSync: boolean;

      // --- model particulars ------------------------------------------------
      UseHamLib: boolean;
      HamLibID: integer;          // meaningful only when RegistryId='HAMLIBANY'
      ReceiverAddress: integer;   // CI-V address; 0 = the model's default
      IcomDataModeID: integer;
      IcomFilterByte: integer;
      WideCWFilter: boolean;
      FT1000MPCWReverse: boolean;
      FrequencyAdder: integer;
      BandOutputPort: string;
      StartupCommand: string;
      PollingEnable: boolean;

      constructor Create;
      procedure Assign(const aSource: TRadioDefinition);
      function Clone: TRadioDefinition;

      // One line for a list box: 'K4D [192.168.73.108:9200]' or
      // 'IC-7100 [SERIAL 17 @ 19200]'.  Presentation, but it belongs with the
      // data so every UI spells it the same way.
      function DisplaySummary: string;
   end;

   { Which two radios are live, and how CW reaches each of them.

     A profile is the thing the operator switches: "Home SO2R", "Portable".
     Radio1Name/Radio2Name refer to definitions BY NAME; '' means the slot is
     empty, which is how a single-radio profile is expressed. }
   TStationProfile = class(TObject)
   public
      Name: string;
      Radio1Name: string;
      Radio2Name: string;
      DefaultActiveSlot: integer;   // 1 or 2
      // CW output per slot: 'CAT', a keyer port value, or 'NONE'.  Held as a
      // string because the keyer vocabulary is the ini's, not an enum here.
      CWOutput1: string;
      CWOutput2: string;
      SpeedSync1: boolean;
      SpeedSync2: boolean;
      SO2REnabled: boolean;

      constructor Create;
      procedure Assign(const aSource: TStationProfile);
      function Clone: TStationProfile;
      // Slot lookup without the caller writing the same if/else every time.
      function RadioNameForSlot(const aSlot: integer): string;
      function ReferencesRadio(const aRadioName: string): boolean;
   end;

   { The library itself: radios, profiles, and which profile is active. }
   TRadioConfigStore = class(TObject)
   private
      FRadios: TObjectList<TRadioDefinition>;
      FProfiles: TObjectList<TStationProfile>;
      FActiveProfileName: string;
      FAutoConnectOnStartup: boolean;
      procedure LoadRadio(const aIni: TCustomIniFile; const aSection, aName: string);
      procedure SaveRadio(const aIni: TCustomIniFile; const aRadio: TRadioDefinition);
      procedure LoadProfile(const aIni: TCustomIniFile; const aSection, aName: string);
      procedure SaveProfile(const aIni: TCustomIniFile; const aProfile: TStationProfile);
   public
      constructor Create;
      destructor Destroy; override;

      procedure Clear;

      // --- radios -----------------------------------------------------------
      function RadioCount: integer;
      function Radio(const aIndex: integer): TRadioDefinition;
      // Case-INSENSITIVE, because the operator typing 'k4' means the 'K4' they
      // already defined, and a store holding both would be a trap.
      function FindRadio(const aName: string): TRadioDefinition;
      function IndexOfRadio(const aName: string): integer;
      // Takes ownership of aRadio.  Returns False (and frees nothing) if the
      // name is blank or already taken -- the caller still owns it then.
      function AddRadio(const aRadio: TRadioDefinition; out aError: string): boolean;
      // Refuses while any profile still refers to it: a dangling reference is
      // a profile that silently loses a radio, which is worse than a refusal.
      function DeleteRadio(const aName: string; out aError: string): boolean;
      function RenameRadio(const aOldName, aNewName: string; out aError: string): boolean;
      // A name not yet in use, derived from aBase ('K3', 'K3 (2)', ...).
      function UniqueRadioName(const aBase: string): string;

      // --- profiles ---------------------------------------------------------
      function ProfileCount: integer;
      function Profile(const aIndex: integer): TStationProfile;
      function FindProfile(const aName: string): TStationProfile;
      function AddProfile(const aProfile: TStationProfile; out aError: string): boolean;
      function DeleteProfile(const aName: string; out aError: string): boolean;
      function ActiveProfile: TStationProfile;

      // --- whole-store checks ------------------------------------------------
      // Everything that makes a store unusable: duplicate names, profiles
      // pointing at radios that are gone, one profile using one radio twice,
      // and (SO2R only) two live radios fighting over one serial port.
      function Validate(out aError: string): boolean;

      // --- persistence -------------------------------------------------------
      // aIni is the CALLER'S -- this never opens or frees a file.
      procedure LoadFrom(const aIni: TCustomIniFile);
      procedure SaveTo(const aIni: TCustomIniFile);

      // --- first run ----------------------------------------------------------
      // Read the legacy [Radio] section of tr4w.ini and build one definition
      // per configured slot plus a 'Default' profile.  READ-ONLY on the legacy
      // file: seeding must never be able to damage the configuration the
      // operator is still using.
      class function LegacyIniHasRadios(const aIni: TCustomIniFile): boolean;
      procedure SeedFromLegacyIni(const aIni: TCustomIniFile);

      property ActiveProfileName: string read FActiveProfileName write FActiveProfileName;
      property AutoConnectOnStartup: boolean read FAutoConnectOnStartup write FAutoConnectOnStartup;
   end;

const
   // Bumped only when the on-disk schema changes in a way a reader must know
   // about.  Written to [General]; nothing reads it yet, deliberately -- it is
   // here so that a future migration HAS a version to branch on.
   RADIOCONFIG_SCHEMA_VERSION = 1;

   RADIOSECTION_PREFIX   = 'Radio.';
   PROFILESECTION_PREFIX = 'Profile.';
   GENERALSECTION        = 'General';

   DEFAULTPROFILENAME    = 'Default';

   // The CW-output vocabulary used by TStationProfile.CWOutputN.
   CWOUTPUT_CAT  = 'CAT';
   CWOUTPUT_NONE = 'NONE';

   // The 'no port' value in TR4W's PortTypeSA vocabulary.
   PORT_NONE = 'NONE';

function TransportToStr(const aTransport: TRadioTransport): string;
function StrToTransport(const aValue: string): TRadioTransport;

implementation

const
   TRANSPORTNAME: array[TRadioTransport] of string = ('SERIAL', 'NETWORK');

function TransportToStr(const aTransport: TRadioTransport): string;
begin
   Result := TRANSPORTNAME[aTransport];
end;

function StrToTransport(const aValue: string): TRadioTransport;
begin
   // Anything unrecognised reads as serial: that is the overwhelmingly common
   // case, and a corrupt value should degrade to the ordinary thing rather
   // than raise while loading a settings file.
   if SameText(Trim(aValue), TRANSPORTNAME[rtNetwork]) then
      begin
      Result := rtNetwork;
      end
   else
      begin
      Result := rtSerial;
      end;
end;

{ ---------------------------------------------------------------- helpers -- }

// Names are compared case-insensitively and with the ends trimmed everywhere
// in this unit; going through one function keeps that rule in a single place.
function SameName(const aLeft, aRight: string): boolean;
begin
   Result := SameText(Trim(aLeft), Trim(aRight));
end;

{ ------------------------------------------------------- TRadioDefinition -- }

constructor TRadioDefinition.Create;
begin
   inherited Create;
   // Defaults chosen to mean "nothing configured": a zero baud rate or CI-V
   // address is not a real setting, so the apply layer can leave the model's
   // own default in place rather than write a wrong number.
   Transport         := rtSerial;
   ControlPort       := PORT_NONE;
   KeyerOutputPort   := PORT_NONE;
   BandOutputPort    := PORT_NONE;
   // Polling on is the useful default -- a radio defined but never polled
   // looks broken to the operator.
   PollingEnable     := True;
end;

procedure TRadioDefinition.Assign(const aSource: TRadioDefinition);
begin
   if aSource = nil then
      begin
      Exit;
      end;

   Name              := aSource.Name;
   RegistryId        := aSource.RegistryId;
   Transport         := aSource.Transport;

   ControlPort       := aSource.ControlPort;
   BaudRate          := aSource.BaudRate;
   SerialFormat      := aSource.SerialFormat;
   CatRTS            := aSource.CatRTS;
   CatDTR            := aSource.CatDTR;

   IPAddress         := aSource.IPAddress;
   TCPPort           := aSource.TCPPort;
   NetworkUsername   := aSource.NetworkUsername;
   NetworkPassword   := aSource.NetworkPassword;

   KeyerOutputPort   := aSource.KeyerOutputPort;
   KeyerRTS          := aSource.KeyerRTS;
   KeyerDTR          := aSource.KeyerDTR;
   KeyerStopBits     := aSource.KeyerStopBits;

   CWByCAT           := aSource.CWByCAT;
   CWSpeedSync       := aSource.CWSpeedSync;

   UseHamLib         := aSource.UseHamLib;
   HamLibID          := aSource.HamLibID;
   ReceiverAddress   := aSource.ReceiverAddress;
   IcomDataModeID    := aSource.IcomDataModeID;
   IcomFilterByte    := aSource.IcomFilterByte;
   WideCWFilter      := aSource.WideCWFilter;
   FT1000MPCWReverse := aSource.FT1000MPCWReverse;
   FrequencyAdder    := aSource.FrequencyAdder;
   BandOutputPort    := aSource.BandOutputPort;
   StartupCommand    := aSource.StartupCommand;
   PollingEnable     := aSource.PollingEnable;
end;

function TRadioDefinition.Clone: TRadioDefinition;
begin
   Result := TRadioDefinition.Create;
   Result.Assign(Self);
end;

function TRadioDefinition.DisplaySummary: string;
var
   detail: string;
begin
   if Transport = rtNetwork then
      begin
      detail := Trim(IPAddress);
      if TCPPort > 0 then
         begin
         detail := detail + ':' + IntToStr(TCPPort);
         end;
      end
   else
      begin
      detail := Trim(ControlPort);
      if BaudRate > 0 then
         begin
         detail := detail + ' @ ' + IntToStr(BaudRate);
         end;
      end;

   Result := Trim(Name);
   if detail <> '' then
      begin
      Result := Result + ' [' + detail + ']';
      end;
end;

{ --------------------------------------------------------- TStationProfile -- }

constructor TStationProfile.Create;
begin
   inherited Create;
   DefaultActiveSlot := 1;
   CWOutput1         := CWOUTPUT_NONE;
   CWOutput2         := CWOUTPUT_NONE;
end;

procedure TStationProfile.Assign(const aSource: TStationProfile);
begin
   if aSource = nil then
      begin
      Exit;
      end;

   Name              := aSource.Name;
   Radio1Name        := aSource.Radio1Name;
   Radio2Name        := aSource.Radio2Name;
   DefaultActiveSlot := aSource.DefaultActiveSlot;
   CWOutput1         := aSource.CWOutput1;
   CWOutput2         := aSource.CWOutput2;
   SpeedSync1        := aSource.SpeedSync1;
   SpeedSync2        := aSource.SpeedSync2;
   SO2REnabled       := aSource.SO2REnabled;
end;

function TStationProfile.Clone: TStationProfile;
begin
   Result := TStationProfile.Create;
   Result.Assign(Self);
end;

function TStationProfile.RadioNameForSlot(const aSlot: integer): string;
begin
   if aSlot = 2 then
      begin
      Result := Radio2Name;
      end
   else
      begin
      Result := Radio1Name;
      end;
end;

function TStationProfile.ReferencesRadio(const aRadioName: string): boolean;
begin
   Result := SameName(Radio1Name, aRadioName) or SameName(Radio2Name, aRadioName);
end;

{ ------------------------------------------------------ TRadioConfigStore -- }

constructor TRadioConfigStore.Create;
begin
   inherited Create;
   // Owning lists: the store is the lifetime owner of every definition and
   // profile it holds, which is why AddRadio documents that it takes the
   // object over.
   FRadios   := TObjectList<TRadioDefinition>.Create(True);
   FProfiles := TObjectList<TStationProfile>.Create(True);
end;

destructor TRadioConfigStore.Destroy;
begin
   FreeAndNil(FProfiles);
   FreeAndNil(FRadios);
   inherited Destroy;
end;

procedure TRadioConfigStore.Clear;
begin
   FRadios.Clear;
   FProfiles.Clear;
   FActiveProfileName    := '';
   FAutoConnectOnStartup := False;
end;

function TRadioConfigStore.RadioCount: integer;
begin
   Result := FRadios.Count;
end;

function TRadioConfigStore.Radio(const aIndex: integer): TRadioDefinition;
begin
   Result := FRadios[aIndex];
end;

function TRadioConfigStore.IndexOfRadio(const aName: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to FRadios.Count - 1 do
      begin
      if SameName(FRadios[i].Name, aName) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function TRadioConfigStore.FindRadio(const aName: string): TRadioDefinition;
var
   idx: integer;
begin
   idx := IndexOfRadio(aName);
   if idx >= 0 then
      begin
      Result := FRadios[idx];
      end
   else
      begin
      Result := nil;
      end;
end;

function TRadioConfigStore.AddRadio(const aRadio: TRadioDefinition; out aError: string): boolean;
begin
   aError := '';
   Result := False;

   if aRadio = nil then
      begin
      aError := 'No radio supplied';
      Exit;
      end;

   if Trim(aRadio.Name) = '' then
      begin
      aError := 'A radio must have a name';
      Exit;
      end;

   if IndexOfRadio(aRadio.Name) >= 0 then
      begin
      aError := Format('A radio named "%s" already exists', [Trim(aRadio.Name)]);
      Exit;
      end;

   aRadio.Name := Trim(aRadio.Name);
   FRadios.Add(aRadio);
   Result := True;
end;

function TRadioConfigStore.DeleteRadio(const aName: string; out aError: string): boolean;
var
   idx, i: integer;
begin
   aError := '';
   Result := False;

   idx := IndexOfRadio(aName);
   if idx < 0 then
      begin
      aError := Format('No radio named "%s"', [Trim(aName)]);
      Exit;
      end;

   // A profile pointing at a deleted radio would come up empty at activation
   // time with no explanation, so refuse and name the profile instead.
   for i := 0 to FProfiles.Count - 1 do
      begin
      if FProfiles[i].ReferencesRadio(aName) then
         begin
         aError := Format('"%s" is used by profile "%s"',
                          [Trim(aName), FProfiles[i].Name]);
         Exit;
         end;
      end;

   FRadios.Delete(idx);
   Result := True;
end;

function TRadioConfigStore.RenameRadio(const aOldName, aNewName: string; out aError: string): boolean;
var
   radioDef: TRadioDefinition;
   i, existing: integer;
   trimmed: string;
begin
   aError := '';
   Result := False;

   radioDef := FindRadio(aOldName);
   if radioDef = nil then
      begin
      aError := Format('No radio named "%s"', [Trim(aOldName)]);
      Exit;
      end;

   trimmed := Trim(aNewName);
   if trimmed = '' then
      begin
      aError := 'A radio must have a name';
      Exit;
      end;

   // Renaming to a different spelling of the SAME name (case or whitespace) is
   // legitimate, so only a DIFFERENT radio holding the name is a collision.
   existing := IndexOfRadio(trimmed);
   if (existing >= 0) and (FRadios[existing] <> radioDef) then
      begin
      aError := Format('A radio named "%s" already exists', [trimmed]);
      Exit;
      end;

   // Fix the references before the name moves, or the comparison below would
   // no longer match anything.
   for i := 0 to FProfiles.Count - 1 do
      begin
      if SameName(FProfiles[i].Radio1Name, aOldName) then
         begin
         FProfiles[i].Radio1Name := trimmed;
         end;
      if SameName(FProfiles[i].Radio2Name, aOldName) then
         begin
         FProfiles[i].Radio2Name := trimmed;
         end;
      end;

   radioDef.Name := trimmed;
   Result := True;
end;

function TRadioConfigStore.UniqueRadioName(const aBase: string): string;
var
   stem: string;
   n: integer;
begin
   stem := Trim(aBase);
   if stem = '' then
      begin
      stem := 'Radio';
      end;

   Result := stem;
   n := 2;
   while IndexOfRadio(Result) >= 0 do
      begin
      Result := Format('%s (%d)', [stem, n]);
      Inc(n);
      end;
end;

function TRadioConfigStore.ProfileCount: integer;
begin
   Result := FProfiles.Count;
end;

function TRadioConfigStore.Profile(const aIndex: integer): TStationProfile;
begin
   Result := FProfiles[aIndex];
end;

function TRadioConfigStore.FindProfile(const aName: string): TStationProfile;
var
   i: integer;
begin
   Result := nil;
   for i := 0 to FProfiles.Count - 1 do
      begin
      if SameName(FProfiles[i].Name, aName) then
         begin
         Result := FProfiles[i];
         Exit;
         end;
      end;
end;

function TRadioConfigStore.AddProfile(const aProfile: TStationProfile; out aError: string): boolean;
begin
   aError := '';
   Result := False;

   if aProfile = nil then
      begin
      aError := 'No profile supplied';
      Exit;
      end;

   if Trim(aProfile.Name) = '' then
      begin
      aError := 'A profile must have a name';
      Exit;
      end;

   if FindProfile(aProfile.Name) <> nil then
      begin
      aError := Format('A profile named "%s" already exists', [Trim(aProfile.Name)]);
      Exit;
      end;

   aProfile.Name := Trim(aProfile.Name);
   FProfiles.Add(aProfile);
   Result := True;
end;

function TRadioConfigStore.DeleteProfile(const aName: string; out aError: string): boolean;
var
   i: integer;
begin
   aError := '';
   Result := False;

   for i := 0 to FProfiles.Count - 1 do
      begin
      if SameName(FProfiles[i].Name, aName) then
         begin
         // Deleting the ACTIVE profile is allowed -- refusing would leave the
         // operator unable to remove a profile without first activating
         // another.  The active name is simply cleared.
         if SameName(FActiveProfileName, aName) then
            begin
            FActiveProfileName := '';
            end;
         FProfiles.Delete(i);
         Result := True;
         Exit;
         end;
      end;

   aError := Format('No profile named "%s"', [Trim(aName)]);
end;

function TRadioConfigStore.ActiveProfile: TStationProfile;
begin
   Result := FindProfile(FActiveProfileName);
end;

function TRadioConfigStore.Validate(out aError: string): boolean;
var
   i, j: integer;
   prof: TStationProfile;
   radio1, radio2: TRadioDefinition;
begin
   aError := '';
   Result := False;

   for i := 0 to FRadios.Count - 1 do
      begin
      if Trim(FRadios[i].Name) = '' then
         begin
         aError := 'A radio has no name';
         Exit;
         end;
      for j := i + 1 to FRadios.Count - 1 do
         begin
         if SameName(FRadios[i].Name, FRadios[j].Name) then
            begin
            aError := Format('Two radios are named "%s"', [FRadios[i].Name]);
            Exit;
            end;
         end;
      end;

   for i := 0 to FProfiles.Count - 1 do
      begin
      prof := FProfiles[i];

      if Trim(prof.Name) = '' then
         begin
         aError := 'A profile has no name';
         Exit;
         end;

      for j := i + 1 to FProfiles.Count - 1 do
         begin
         if SameName(prof.Name, FProfiles[j].Name) then
            begin
            aError := Format('Two profiles are named "%s"', [prof.Name]);
            Exit;
            end;
         end;

      radio1 := nil;
      radio2 := nil;

      if Trim(prof.Radio1Name) <> '' then
         begin
         radio1 := FindRadio(prof.Radio1Name);
         if radio1 = nil then
            begin
            aError := Format('Profile "%s" refers to radio "%s", which does not exist',
                             [prof.Name, prof.Radio1Name]);
            Exit;
            end;
         end;

      if Trim(prof.Radio2Name) <> '' then
         begin
         radio2 := FindRadio(prof.Radio2Name);
         if radio2 = nil then
            begin
            aError := Format('Profile "%s" refers to radio "%s", which does not exist',
                             [prof.Name, prof.Radio2Name]);
            Exit;
            end;
         end;

      // The same definition in both slots is not two radios; it is one radio
      // whose port would be opened twice.
      if (radio1 <> nil) and (radio1 = radio2) then
         begin
         aError := Format('Profile "%s" uses "%s" in both slots',
                          [prof.Name, radio1.Name]);
         Exit;
         end;

      // Two DIFFERENT serial radios on one COM port is the same collision the
      // legacy dialog warns about, and it is fatal rather than advisory: the
      // second open fails and that radio silently never answers.
      if (radio1 <> nil) and (radio2 <> nil)         and
         (radio1.Transport = rtSerial)               and
         (radio2.Transport = rtSerial)               and
         (Trim(radio1.ControlPort) <> '')            and
         (not SameText(Trim(radio1.ControlPort), PORT_NONE)) and
         SameText(Trim(radio1.ControlPort), Trim(radio2.ControlPort)) then
         begin
         aError := Format('Profile "%s": "%s" and "%s" both use %s',
                          [prof.Name, radio1.Name, radio2.Name, Trim(radio1.ControlPort)]);
         Exit;
         end;
      end;

   // An active-profile name that names nothing would activate nothing, with no
   // visible cause.  '' is fine: it means no profile is active yet.
   if (Trim(FActiveProfileName) <> '') and (ActiveProfile = nil) then
      begin
      aError := Format('The active profile "%s" does not exist', [FActiveProfileName]);
      Exit;
      end;

   Result := True;
end;

{ ------------------------------------------------------------ persistence -- }

procedure TRadioConfigStore.SaveRadio(const aIni: TCustomIniFile; const aRadio: TRadioDefinition);
var
   section: string;
begin
   section := RADIOSECTION_PREFIX + aRadio.Name;

   aIni.WriteString(section,  'RegistryId',        aRadio.RegistryId);
   aIni.WriteString(section,  'Transport',         TransportToStr(aRadio.Transport));

   aIni.WriteString(section,  'ControlPort',       aRadio.ControlPort);
   aIni.WriteInteger(section, 'BaudRate',          aRadio.BaudRate);
   aIni.WriteString(section,  'SerialFormat',      aRadio.SerialFormat);
   aIni.WriteString(section,  'CatRTS',            aRadio.CatRTS);
   aIni.WriteString(section,  'CatDTR',            aRadio.CatDTR);

   aIni.WriteString(section,  'IPAddress',         aRadio.IPAddress);
   aIni.WriteInteger(section, 'TCPPort',           aRadio.TCPPort);
   aIni.WriteString(section,  'NetworkUsername',   aRadio.NetworkUsername);
   aIni.WriteString(section,  'NetworkPassword',   aRadio.NetworkPassword);

   aIni.WriteString(section,  'KeyerOutputPort',   aRadio.KeyerOutputPort);
   aIni.WriteString(section,  'KeyerRTS',          aRadio.KeyerRTS);
   aIni.WriteString(section,  'KeyerDTR',          aRadio.KeyerDTR);
   aIni.WriteInteger(section, 'KeyerStopBits',     aRadio.KeyerStopBits);

   aIni.WriteBool(section,    'CWByCAT',           aRadio.CWByCAT);
   aIni.WriteBool(section,    'CWSpeedSync',       aRadio.CWSpeedSync);

   aIni.WriteBool(section,    'UseHamLib',         aRadio.UseHamLib);
   aIni.WriteInteger(section, 'HamLibID',          aRadio.HamLibID);
   aIni.WriteInteger(section, 'ReceiverAddress',   aRadio.ReceiverAddress);
   aIni.WriteInteger(section, 'IcomDataModeID',    aRadio.IcomDataModeID);
   aIni.WriteInteger(section, 'IcomFilterByte',    aRadio.IcomFilterByte);
   aIni.WriteBool(section,    'WideCWFilter',      aRadio.WideCWFilter);
   aIni.WriteBool(section,    'FT1000MPCWReverse', aRadio.FT1000MPCWReverse);
   aIni.WriteInteger(section, 'FrequencyAdder',    aRadio.FrequencyAdder);
   aIni.WriteString(section,  'BandOutputPort',    aRadio.BandOutputPort);
   aIni.WriteString(section,  'StartupCommand',    aRadio.StartupCommand);
   aIni.WriteBool(section,    'PollingEnable',     aRadio.PollingEnable);
end;

procedure TRadioConfigStore.LoadRadio(const aIni: TCustomIniFile; const aSection, aName: string);
var
   radioDef: TRadioDefinition;
   err: string;
begin
   radioDef := TRadioDefinition.Create;
   radioDef.Name := aName;

   radioDef.RegistryId        := aIni.ReadString(aSection,  'RegistryId',        '');
   radioDef.Transport         := StrToTransport(
                                 aIni.ReadString(aSection,  'Transport',         TRANSPORTNAME[rtSerial]));

   radioDef.ControlPort       := aIni.ReadString(aSection,  'ControlPort',       PORT_NONE);
   radioDef.BaudRate          := aIni.ReadInteger(aSection, 'BaudRate',          0);
   radioDef.SerialFormat      := aIni.ReadString(aSection,  'SerialFormat',      '');
   radioDef.CatRTS            := aIni.ReadString(aSection,  'CatRTS',            '');
   radioDef.CatDTR            := aIni.ReadString(aSection,  'CatDTR',            '');

   radioDef.IPAddress         := aIni.ReadString(aSection,  'IPAddress',         '');
   radioDef.TCPPort           := aIni.ReadInteger(aSection, 'TCPPort',           0);
   radioDef.NetworkUsername   := aIni.ReadString(aSection,  'NetworkUsername',   '');
   radioDef.NetworkPassword   := aIni.ReadString(aSection,  'NetworkPassword',   '');

   radioDef.KeyerOutputPort   := aIni.ReadString(aSection,  'KeyerOutputPort',   PORT_NONE);
   radioDef.KeyerRTS          := aIni.ReadString(aSection,  'KeyerRTS',          '');
   radioDef.KeyerDTR          := aIni.ReadString(aSection,  'KeyerDTR',          '');
   radioDef.KeyerStopBits     := aIni.ReadInteger(aSection, 'KeyerStopBits',     0);

   radioDef.CWByCAT           := aIni.ReadBool(aSection,    'CWByCAT',           False);
   radioDef.CWSpeedSync       := aIni.ReadBool(aSection,    'CWSpeedSync',       False);

   radioDef.UseHamLib         := aIni.ReadBool(aSection,    'UseHamLib',         False);
   radioDef.HamLibID          := aIni.ReadInteger(aSection, 'HamLibID',          0);
   radioDef.ReceiverAddress   := aIni.ReadInteger(aSection, 'ReceiverAddress',   0);
   radioDef.IcomDataModeID    := aIni.ReadInteger(aSection, 'IcomDataModeID',    0);
   radioDef.IcomFilterByte    := aIni.ReadInteger(aSection, 'IcomFilterByte',    0);
   radioDef.WideCWFilter      := aIni.ReadBool(aSection,    'WideCWFilter',      False);
   radioDef.FT1000MPCWReverse := aIni.ReadBool(aSection,    'FT1000MPCWReverse', False);
   radioDef.FrequencyAdder    := aIni.ReadInteger(aSection, 'FrequencyAdder',    0);
   radioDef.BandOutputPort    := aIni.ReadString(aSection,  'BandOutputPort',    PORT_NONE);
   radioDef.StartupCommand    := aIni.ReadString(aSection,  'StartupCommand',    '');
   radioDef.PollingEnable     := aIni.ReadBool(aSection,    'PollingEnable',     True);

   // A duplicate section name cannot happen in a well-formed ini, but a
   // hand-edited file can produce one; drop the later one rather than raise
   // while loading settings.
   if not AddRadio(radioDef, err) then
      begin
      radioDef.Free;
      end;
end;

procedure TRadioConfigStore.SaveProfile(const aIni: TCustomIniFile; const aProfile: TStationProfile);
var
   section: string;
begin
   section := PROFILESECTION_PREFIX + aProfile.Name;

   aIni.WriteString(section,  'Radio1',            aProfile.Radio1Name);
   aIni.WriteString(section,  'Radio2',            aProfile.Radio2Name);
   aIni.WriteInteger(section, 'DefaultActiveSlot', aProfile.DefaultActiveSlot);
   aIni.WriteString(section,  'CWOutput1',         aProfile.CWOutput1);
   aIni.WriteString(section,  'CWOutput2',         aProfile.CWOutput2);
   aIni.WriteBool(section,    'SpeedSync1',        aProfile.SpeedSync1);
   aIni.WriteBool(section,    'SpeedSync2',        aProfile.SpeedSync2);
   aIni.WriteBool(section,    'SO2REnabled',       aProfile.SO2REnabled);
end;

procedure TRadioConfigStore.LoadProfile(const aIni: TCustomIniFile; const aSection, aName: string);
var
   prof: TStationProfile;
   err: string;
begin
   prof := TStationProfile.Create;
   prof.Name := aName;

   prof.Radio1Name        := aIni.ReadString(aSection,  'Radio1',            '');
   prof.Radio2Name        := aIni.ReadString(aSection,  'Radio2',            '');
   prof.DefaultActiveSlot := aIni.ReadInteger(aSection, 'DefaultActiveSlot', 1);
   prof.CWOutput1         := aIni.ReadString(aSection,  'CWOutput1',         CWOUTPUT_NONE);
   prof.CWOutput2         := aIni.ReadString(aSection,  'CWOutput2',         CWOUTPUT_NONE);
   prof.SpeedSync1        := aIni.ReadBool(aSection,    'SpeedSync1',        False);
   prof.SpeedSync2        := aIni.ReadBool(aSection,    'SpeedSync2',        False);
   prof.SO2REnabled       := aIni.ReadBool(aSection,    'SO2REnabled',       False);

   if prof.DefaultActiveSlot <> 2 then
      begin
      prof.DefaultActiveSlot := 1;
      end;

   if not AddProfile(prof, err) then
      begin
      prof.Free;
      end;
end;

procedure TRadioConfigStore.LoadFrom(const aIni: TCustomIniFile);
var
   sections: TStringList;
   i: integer;
   section: string;
begin
   Clear;

   sections := TStringList.Create;
   try
      aIni.ReadSections(sections);

      // Radios first: a profile's references are only meaningful once the
      // radios exist, and Validate is easier to reason about in that order.
      for i := 0 to sections.Count - 1 do
         begin
         section := sections[i];
         if StartsText(RADIOSECTION_PREFIX, section) then
            begin
            LoadRadio(aIni, section, Copy(section, Length(RADIOSECTION_PREFIX) + 1, MaxInt));
            end;
         end;

      for i := 0 to sections.Count - 1 do
         begin
         section := sections[i];
         if StartsText(PROFILESECTION_PREFIX, section) then
            begin
            LoadProfile(aIni, section, Copy(section, Length(PROFILESECTION_PREFIX) + 1, MaxInt));
            end;
         end;
   finally
      sections.Free;
   end;

   FActiveProfileName    := aIni.ReadString(GENERALSECTION, 'ActiveProfile', '');
   FAutoConnectOnStartup := aIni.ReadBool(GENERALSECTION,   'AutoConnect',   False);
end;

procedure TRadioConfigStore.SaveTo(const aIni: TCustomIniFile);
var
   sections: TStringList;
   i: integer;
   section: string;
begin
   // Erase the old radio/profile sections first.  Without this, deleting a
   // radio in the UI would leave its section behind and the next load would
   // resurrect it -- the classic ini-writer bug.  [General] is rewritten in
   // place, and any OTHER section is left alone on principle.
   sections := TStringList.Create;
   try
      aIni.ReadSections(sections);
      for i := 0 to sections.Count - 1 do
         begin
         section := sections[i];
         if StartsText(RADIOSECTION_PREFIX, section) or
            StartsText(PROFILESECTION_PREFIX, section) then
            begin
            aIni.EraseSection(section);
            end;
         end;
   finally
      sections.Free;
   end;

   aIni.WriteInteger(GENERALSECTION, 'Version',       RADIOCONFIG_SCHEMA_VERSION);
   aIni.WriteString(GENERALSECTION,  'ActiveProfile', FActiveProfileName);
   aIni.WriteBool(GENERALSECTION,    'AutoConnect',   FAutoConnectOnStartup);

   for i := 0 to FRadios.Count - 1 do
      begin
      SaveRadio(aIni, FRadios[i]);
      end;

   for i := 0 to FProfiles.Count - 1 do
      begin
      SaveProfile(aIni, FProfiles[i]);
      end;

   aIni.UpdateFile;
end;

{ ------------------------------------------------------------- first run --- }

// The legacy slot keys, spelled the way CFGCA spells them.  Kept local: the
// apply layer has its own, authoritative table, and duplicating the strings
// here rather than sharing them keeps this unit dependency-free.  These are
// only ever READ.
const
   LEGACYSECTION = 'Radio';
   SLOTWORD: array[1..2] of string = ('ONE', 'TWO');

function LegacyKey(const aSlot: integer; const aSuffix: string): string;
begin
   Result := 'RADIO ' + SLOTWORD[aSlot] + ' ' + aSuffix;
end;

class function TRadioConfigStore.LegacyIniHasRadios(const aIni: TCustomIniFile): boolean;
var
   slot: integer;
   radioType, factoryId: string;
begin
   Result := False;
   for slot := 1 to 2 do
      begin
      radioType := Trim(aIni.ReadString(LEGACYSECTION, LegacyKey(slot, 'TYPE'), ''));
      factoryId := Trim(aIni.ReadString(LEGACYSECTION, LegacyKey(slot, 'FACTORY ID'), ''));
      // A factory (string-id) radio writes TYPE=NONE and puts the real
      // identity in FACTORY ID, so TYPE alone is not the test.
      if (factoryId <> '') or
         ((radioType <> '') and not SameText(radioType, 'NONE')) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

procedure TRadioConfigStore.SeedFromLegacyIni(const aIni: TCustomIniFile);
var
   slot: integer;
   radioDef: TRadioDefinition;
   prof: TStationProfile;
   radioType, factoryId, controlPort, ipAddress, err: string;

   function ReadStr(const aSuffix: string): string;
   begin
      Result := Trim(aIni.ReadString(LEGACYSECTION, LegacyKey(slot, aSuffix), ''));
   end;

   function ReadInt(const aSuffix: string; const aDefault: integer): integer;
   begin
      Result := StrToIntDef(ReadStr(aSuffix), aDefault);
   end;

   function ReadBool(const aSuffix: string): boolean;
   begin
      // CFGCA's boolean vocabulary is TRUE/FALSE; anything else is False.
      Result := SameText(ReadStr(aSuffix), 'TRUE');
   end;

begin
   prof := TStationProfile.Create;
   prof.Name := DEFAULTPROFILENAME;

   for slot := 1 to 2 do
      begin
      radioType := ReadStr('TYPE');
      factoryId := ReadStr('FACTORY ID');

      if (factoryId = '') and
         ((radioType = '') or SameText(radioType, 'NONE')) then
         begin
         // Slot not configured -- skip it rather than seed an empty radio.
         Continue;
         end;

      radioDef := TRadioDefinition.Create;

      // The registry id IS the factory id when there is one; otherwise the
      // legacy enum name doubles as the id.  Which of the two the apply layer
      // writes back (TYPE vs FACTORY ID) is its decision, not the store's.
      if factoryId <> '' then
         begin
         radioDef.RegistryId := factoryId;
         end
      else
         begin
         radioDef.RegistryId := radioType;
         end;

      // Prefer the operator's own name for the slot; fall back to the id, and
      // dedupe, because both slots may hold the same model.
      radioDef.Name := ReadStr('NAME');
      if radioDef.Name = '' then
         begin
         radioDef.Name := radioDef.RegistryId;
         end;
      radioDef.Name := UniqueRadioName(radioDef.Name);

      controlPort := ReadStr('CONTROL PORT');
      ipAddress   := ReadStr('IP ADDRESS');
      if controlPort = '' then
         begin
         controlPort := PORT_NONE;
         end;

      // Transport is not stored in the legacy ini -- it is INFERRED, the same
      // way the legacy code infers it: no serial port but an IP address means
      // the radio is reached over the network.
      if SameText(controlPort, PORT_NONE) and (ipAddress <> '') then
         begin
         radioDef.Transport := rtNetwork;
         end
      else
         begin
         radioDef.Transport := rtSerial;
         end;

      radioDef.ControlPort       := controlPort;
      radioDef.BaudRate          := ReadInt('BAUD RATE', 0);
      radioDef.SerialFormat      := ReadStr('SERIAL FORMAT');
      radioDef.CatRTS            := ReadStr('CAT RTS');
      radioDef.CatDTR            := ReadStr('CAT DTR');

      radioDef.IPAddress         := ipAddress;
      radioDef.TCPPort           := ReadInt('TCP PORT', 0);
      radioDef.NetworkUsername   := ReadStr('NETWORK USERNAME');
      radioDef.NetworkPassword   := ReadStr('NETWORK PASSWORD');
      // Issue #904 left the older ICOM-prefixed spellings in circulation; an
      // ini written before that change still uses them.
      if radioDef.NetworkUsername = '' then
         begin
         radioDef.NetworkUsername := ReadStr('ICOM NETWORK USERNAME');
         end;
      if radioDef.NetworkPassword = '' then
         begin
         radioDef.NetworkPassword := ReadStr('ICOM NETWORK PASSWORD');
         end;

      // The keyer output port key is spelled the other way round: KEYER RADIO
      // ONE OUTPUT PORT, not RADIO ONE KEYER OUTPUT PORT.
      radioDef.KeyerOutputPort   := Trim(aIni.ReadString(LEGACYSECTION,
                                      'KEYER RADIO ' + SLOTWORD[slot] + ' OUTPUT PORT', ''));
      if radioDef.KeyerOutputPort = '' then
         begin
         radioDef.KeyerOutputPort := PORT_NONE;
         end;
      radioDef.KeyerRTS          := ReadStr('KEYER RTS');
      radioDef.KeyerDTR          := ReadStr('KEYER DTR');
      radioDef.KeyerStopBits     := ReadInt('KEYER STOP BITS', 0);

      radioDef.CWByCAT           := ReadBool('CW BY CAT');
      radioDef.CWSpeedSync       := ReadBool('CW SPEED SYNC');

      radioDef.UseHamLib         := ReadBool('USE HAMLIB');
      radioDef.HamLibID          := ReadInt('HAMLIB ID', 0);
      radioDef.ReceiverAddress   := ReadInt('RECEIVER ADDRESS', 0);
      radioDef.IcomDataModeID    := ReadInt('ICOM DATA MODE ID', 0);
      radioDef.IcomFilterByte    := ReadInt('ICOM FILTER BYTE', 0);
      radioDef.WideCWFilter      := ReadBool('WIDE CW FILTER');
      radioDef.FT1000MPCWReverse := ReadBool('FT1000MP CW REVERSE');
      radioDef.FrequencyAdder    := ReadInt('FREQUENCY ADDER', 0);
      radioDef.BandOutputPort    := ReadStr('BAND OUTPUT PORT');
      if radioDef.BandOutputPort = '' then
         begin
         radioDef.BandOutputPort := PORT_NONE;
         end;
      radioDef.StartupCommand    := ReadStr('STARTUP COMMAND');

      // POLL RADIO ONE, again spelled the other way round.  Absent means on,
      // which is what the legacy default is.
      radioDef.PollingEnable     := not SameText(
         Trim(aIni.ReadString(LEGACYSECTION, 'POLL RADIO ' + SLOTWORD[slot], 'TRUE')), 'FALSE');

      if not AddRadio(radioDef, err) then
         begin
         radioDef.Free;
         Continue;
         end;

      if slot = 1 then
         begin
         prof.Radio1Name := radioDef.Name;
         if radioDef.CWByCAT then
            begin
            prof.CWOutput1 := CWOUTPUT_CAT;
            end
         else
            begin
            prof.CWOutput1 := radioDef.KeyerOutputPort;
            end;
         prof.SpeedSync1 := radioDef.CWSpeedSync;
         end
      else
         begin
         prof.Radio2Name := radioDef.Name;
         if radioDef.CWByCAT then
            begin
            prof.CWOutput2 := CWOUTPUT_CAT;
            end
         else
            begin
            prof.CWOutput2 := radioDef.KeyerOutputPort;
            end;
         prof.SpeedSync2 := radioDef.CWSpeedSync;
         end;
      end;

   // Two configured slots is what SO2R means in the legacy configuration, so
   // seed the flag from that rather than leave the operator to set it.
   prof.SO2REnabled := (prof.Radio1Name <> '') and (prof.Radio2Name <> '');

   if (prof.Radio1Name = '') and (prof.Radio2Name = '') then
      begin
      // Nothing was configured -- no radios, and no profile pointing at none.
      prof.Free;
      Exit;
      end;

   if AddProfile(prof, err) then
      begin
      FActiveProfileName := prof.Name;
      end
   else
      begin
      prof.Free;
      end;
end;

end.

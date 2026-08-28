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
unit uKeyerConfigStore;
{$I tr4w.inc}

{
  The KEYER LIBRARY: define each keying DEVICE once, reference it by name.

  Exactly the shape uRadioConfigStore gave radios, and for the same reason: a
  WinKeyer's seventeen settings sit in one flat command list today, reading as
  station-wide facts rather than as properties of a device.

  WHAT IS IN HERE, AND WHAT IS NOT (settled with NY4I, 2026-08-07).  Only
  devices with their own settings -- WinKeyer and the YCCC SO2R+ box.  The other
  ways to key CW are not devices at all:

    * CW by CAT is a property of the RADIO MODEL;
    * keying on the radio's own control port is the RADIO's wiring;
    * a keying cable from some COM port to a rig's key jack is also that
      RADIO's wiring, and lives on TRadioDefinition as KeyerOutputPort /
      KeyerRTS / KeyerDTR -- where the legacy config already put it.

  A profile then chooses, per slot: nothing, CW by CAT, the radio's own keyer
  port, or one of these devices by name (CWOUT_* below).  That retires
  ActiveCWKeyer's precedence chain (CAT -> WinKeyer -> YCCC -> CPU), which
  docs/CW_Keyer_Factory_Plan.md records as an artifact of the original if/else
  ordering rather than a decision: a named reference makes it a lookup.

  WHAT THIS UNIT IS AND IS NOT.  A pure data store -- it holds the library,
  validates it, and reads/writes JSON.  It knows nothing about uWinKey, the CW
  keyer factory, the legacy WK/PADDLE command rows, or any UI.  Turning a
  definition into a live keyer is the apply layer's job; editing one is the FMX
  preferences UI's.  Keeping that line sharp is what lets test/unit link this
  without booting MainUnit and the contest engine's globals.

  ON UNIT DEPENDENCIES.  SysUtils, Classes, Generics.Collections and
  uJSON -- all RTL.  No VCL, no FMX, no TR4W unit at all.

  VOCABULARY VALUES ARE HELD AS STRINGS, NOT ENUMS OR INDEXES.  Port is the
  PortTypeSA spelling ('SERIAL 15', 'NONE'), KeyerMode is the KeyerModeSA
  spelling, and so on.  An index would silently re-point at something else the
  next time a list changed, and an enum would drag VC.pas in here.  Whether a
  given spelling is currently valid is a question for the apply layer, which
  has the vocabularies.

  JSON IS WRITTEN WITHOUT A BOM.  TFile.WriteAllText emits a preamble that
  Python and jq reject; see the radio store and commit 578d4cf0.  Reading
  tolerates one.
}

interface

uses
  uConfigValues,
   SysUtils,
   Classes,
   uJSON,
   Generics.Collections;

type
   { DEVICES WITH KNOBS -- and only those.

     THE LINE, settled with NY4I 2026-08-07: WIRING belongs to the radio,
     DEVICE SETTINGS belong here.

     If COM6's DTR runs to the K4's key jack, that is a fact about the K4 -- not
     about a device you can point somewhere else -- so it lives on
     TRadioDefinition as KeyerOutputPort/KeyerRTS/KeyerDTR, where the legacy
     config already had it and where it belongs.  Same for CW-by-CAT, which is a
     property of the model, and for keying on the radio's own control port.
     None of those are library entries; they are METHODS available to a radio,
     with no settings of their own.

     A WinKeyer's dit/dah ratio, Config.weight, lead-in and sidetone are different:
     they belong to the DEVICE, and putting them on a radio would mean retyping
     seventeen settings for every rig the WinKeyer might key.  That is what this
     library is for.

     So the profile offers, per slot: (none), CW by CAT if the slot's radio
     supports it, the radio's own keyer port if it has one, or one of these
     devices by name.  See CWOUT_* below. }
   TKeyerKind = (kkWinKeyer, kkYCCC);

const
   // The JSON spelling of each kind.  Text, not the ordinal, so adding a device
   // later cannot silently re-interpret every file already written.
   KEYERKINDSTR: array[TKeyerKind] of string = ('WINKEYER', 'YCCC');

   // The PROFILE's CW-output vocabulary.  A slot holds one of these two
   // radio-relative tokens, or the NAME of a device in this library, or the
   // store's CWOUTPUT_NONE.  Kept here beside the devices so the whole
   // vocabulary is readable in one place.
   //
   // Both tokens are resolved AGAINST THE SLOT'S RADIO at apply time, and the
   // capability check for CWOUT_CAT must ask the RADIO
   // (HasCapability(rcCWByCAT)), never the model enum -- a model-keyed gate is
   // what once left TCI, a string-id radio, with no CW at all.
   CWOUT_CAT       = 'CAT';         // over the slot radio's CAT link
   CWOUT_RADIOPORT = 'RADIOPORT';   // the slot radio's own keyer output port

   PORT_NONE = 'NONE';

type
   { ONE keyer definition.  Fields are flat and kind-specific groups sit
     together, exactly as TRadioDefinition keeps serial and network fields flat
     with Transport selecting between them.  A variant record would be tidier
     and much worse to serialise, diff and edit. }
   TKeyerDefinition = class(TObject)
   public
      // THE KEY, and it is not the name -- see TRadioDefinition.Id, which was
      // changed first and for the same reason: a profile referring to a device
      // by a name the operator can edit turns a rename into a fan-out that has
      // to be got right in every path.
      //
      // Minted on creation, never rewritten, and given to a keyer read from a
      // store that predates it.
      Id: string;
      // What the OPERATOR sees. Unique within the store because two keyers
      // called WinKeyer would be indistinguishable in a combo box, not because
      // anything keys on it.
      Name: string;
      Kind: TKeyerKind;

      // --- shared ------------------------------------------------------------
      // The port this DEVICE speaks on, in the PortTypeSA vocabulary. Every
      // kind here has one -- that is part of what makes it a device rather than
      // a property of a radio -- so Validate insists on it.
      Port: string;

      // --- WinKeyer ----------------------------------------------------------
      // Vocabulary strings (KeyerModeSA, SidetoneFrequencySA).
      WKKeyerMode: string;
      WKSidetoneFrequency: string;
      WKAutospace: boolean;
      WKCTSpacing: boolean;
      WKIgnoreSpeedPot: boolean;
      WKPaddleOnlySidetone: boolean;
      WKPaddleSwap: boolean;
      WKSidetoneEnable: boolean;
      WKWeight: integer;
      WKLeadInTime: integer;
      WKTailTime: integer;
      WKDitDahRatio: integer;
      WKFirstExtension: integer;
      WKKeyerCompensation: integer;
      WKPaddleSwitchpoint: integer;

      // NO paddle / CPU fields here.  The computer's own keyer keys through
      // whichever radio's keyer output port is configured, and its paddle
      // settings are station-wide -- one paddle, one computer -- so they belong
      // with the other station CW settings rather than on a per-device row.

      constructor Create;
      procedure Assign(const aSource: TKeyerDefinition);
      function Clone: TKeyerDefinition;
      // Field-by-field, so a dialog can answer "did anything change" without a
      // dirty flag that goes stale the moment someone adds a field. Name is
      // included: renaming IS a change.
      function SameAs(const aOther: TKeyerDefinition): boolean;
      // One line for a list box: 'Desk WinKey [WINKEYER SERIAL 3]'.
      function DisplaySummary: string;
   end;

   TKeyerConfigStore = class(TObject)
   private
      FKeyers: TObjectList<TKeyerDefinition>;
      function KeyerToJSON(const aKeyer: TKeyerDefinition): TJSONObject;
      procedure KeyerFromJSON(const aObj: TJSONObject; const aKeyer: TKeyerDefinition);
   public
      constructor Create;
      destructor Destroy; override;

      procedure Clear;

      function KeyerCount: integer;
      function Keyer(const aIndex: integer): TKeyerDefinition;
      // Case-INSENSITIVE: an operator typing 'desk winkey' means the 'Desk
      // WinKey' they already defined, and a store holding both is a trap.
      function FindKeyerById(const aId: string): TKeyerDefinition;
      function FindKeyer(const aName: string): TKeyerDefinition;
      function IndexOfKeyer(const aName: string): integer;
      function AddKeyer(const aName: string; const aKind: TKeyerKind): TKeyerDefinition;
      function RemoveKeyer(const aName: string): boolean;
      function RenameKeyer(const aOldName, aNewName: string; out aError: string): boolean;
      // 'WinKeyer', 'WinKeyer 2', ... -- never collides with an existing name.
      function UniqueKeyerName(const aBase: string): string;

      // Whole-store validation: unique names, a name on every keyer, and a port
      // on every kind that needs one. Returns False with a human-readable
      // reason rather than raising, because the caller is a dialog.
      function Validate(out aError: string): boolean;

      function ToJSON: TJSONArray;
      procedure FromJSON(const aArray: TJSONArray);
   end;

// The spelling used in JSON, and back. StrToKeyerKind is tolerant of case and
// returns False on anything unrecognised rather than guessing -- a keyer of the
// wrong kind would key nothing and look like a hardware fault.
function KeyerKindToStr(const aKind: TKeyerKind): string;
function StrToKeyerKind(const aText: string; out aKind: TKeyerKind): boolean;

implementation

{ ------------------------------------------------------------ vocabulary --- }

function KeyerKindToStr(const aKind: TKeyerKind): string;
begin
   Result := KEYERKINDSTR[aKind];
end;

function StrToKeyerKind(const aText: string; out aKind: TKeyerKind): boolean;
var
   k: TKeyerKind;
begin
   Result := False;
   aKind := kkWinKeyer;
   for k := Low(TKeyerKind) to High(TKeyerKind) do
      begin
      if SameText(Trim(aText), KEYERKINDSTR[k]) then
         begin
         aKind := k;
         Result := True;
         Exit;
         end;
      end;
end;

{ ------------------------------------------------------- TKeyerDefinition --- }

{ A NEW KEYER ID -- a GUID in the registry spelling, braces stripped. Same
  shape and the same reasoning as NewRadioId. }
function NewKeyerId: string;
var
   g: TGUID;
begin
   if CreateGUID(g) = 0 then
      begin
      Result := Copy(GUIDToString(g), 2, 36);
      end
   else
      begin
      Result := 'keyer-' + FormatDateTime('yyyymmddhhnnsszzz', Now);
      end;
end;

constructor TKeyerDefinition.Create;
begin
   inherited Create;
   Id   := NewKeyerId;
   Kind := kkWinKeyer;
   Port := PORT_NONE;
   // Zeroes elsewhere mean "leave it to the device default", the same
   // convention the radio store uses for BaudRate and ReceiverAddress. A store
   // that invented WinKeyer timings here would fight the hardware's own
   // settings for no reason.
end;

procedure TKeyerDefinition.Assign(const aSource: TKeyerDefinition);
begin
   if aSource = nil then
      begin
      Exit;
      end;

   { The Id travels with the definition: the editor copies a clone back onto
     the original, and a clone that lost its identity would look like a new
     keyer to every profile referring to it. }
   Id   := aSource.Id;
   Name := aSource.Name;
   Kind := aSource.Kind;
   Port := aSource.Port;

   WKKeyerMode          := aSource.WKKeyerMode;
   WKSidetoneFrequency  := aSource.WKSidetoneFrequency;
   WKAutospace          := aSource.WKAutospace;
   WKCTSpacing          := aSource.WKCTSpacing;
   WKIgnoreSpeedPot     := aSource.WKIgnoreSpeedPot;
   WKPaddleOnlySidetone := aSource.WKPaddleOnlySidetone;
   WKPaddleSwap         := aSource.WKPaddleSwap;
   WKSidetoneEnable     := aSource.WKSidetoneEnable;
   WKWeight             := aSource.WKWeight;
   WKLeadInTime         := aSource.WKLeadInTime;
   WKTailTime           := aSource.WKTailTime;
   WKDitDahRatio        := aSource.WKDitDahRatio;
   WKFirstExtension     := aSource.WKFirstExtension;
   WKKeyerCompensation  := aSource.WKKeyerCompensation;
   WKPaddleSwitchpoint  := aSource.WKPaddleSwitchpoint;
end;

function TKeyerDefinition.Clone: TKeyerDefinition;
begin
   Result := TKeyerDefinition.Create;
   Result.Assign(Self);
end;

function TKeyerDefinition.SameAs(const aOther: TKeyerDefinition): boolean;
begin
   Result := False;
   if aOther = nil then
      begin
      Exit;
      end;

   Result :=
      SameText(Name, aOther.Name) and
      (Kind = aOther.Kind) and
      SameText(Port, aOther.Port) and
      SameText(WKKeyerMode, aOther.WKKeyerMode) and
      SameText(WKSidetoneFrequency, aOther.WKSidetoneFrequency) and
      (WKAutospace = aOther.WKAutospace) and
      (WKCTSpacing = aOther.WKCTSpacing) and
      (WKIgnoreSpeedPot = aOther.WKIgnoreSpeedPot) and
      (WKPaddleOnlySidetone = aOther.WKPaddleOnlySidetone) and
      (WKPaddleSwap = aOther.WKPaddleSwap) and
      (WKSidetoneEnable = aOther.WKSidetoneEnable) and
      (WKWeight = aOther.WKWeight) and
      (WKLeadInTime = aOther.WKLeadInTime) and
      (WKTailTime = aOther.WKTailTime) and
      (WKDitDahRatio = aOther.WKDitDahRatio) and
      (WKFirstExtension = aOther.WKFirstExtension) and
      (WKKeyerCompensation = aOther.WKKeyerCompensation) and
      (WKPaddleSwitchpoint = aOther.WKPaddleSwitchpoint);
end;

function TKeyerDefinition.DisplaySummary: string;
begin
   Result := Name;
   if Result = '' then
      begin
      Result := '(unnamed)';
      end;

   Result := Result + ' [' + KeyerKindToStr(Kind) + ' ' + Port + ']';
end;

{ ------------------------------------------------------ TKeyerConfigStore --- }

constructor TKeyerConfigStore.Create;
begin
   inherited Create;
   FKeyers := TObjectList<TKeyerDefinition>.Create(True);
end;

destructor TKeyerConfigStore.Destroy;
begin
   FreeAndNil(FKeyers);
   inherited Destroy;
end;

procedure TKeyerConfigStore.Clear;
begin
   FKeyers.Clear;
end;

function TKeyerConfigStore.KeyerCount: integer;
begin
   Result := FKeyers.Count;
end;

function TKeyerConfigStore.Keyer(const aIndex: integer): TKeyerDefinition;
begin
   Result := nil;
   if (aIndex >= 0) and (aIndex < FKeyers.Count) then
      begin
      Result := FKeyers[aIndex];
      end;
end;

function TKeyerConfigStore.IndexOfKeyer(const aName: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to FKeyers.Count - 1 do
      begin
      if SameText(FKeyers[i].Name, Trim(aName)) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

{ THE LOOKUP A PROFILE USES. By id, so a rename cannot break it. }
function TKeyerConfigStore.FindKeyerById(const aId: string): TKeyerDefinition;
var
   i: integer;
begin
   Result := nil;
   if Trim(aId) = '' then
      begin
      Exit;
      end;
   for i := 0 to FKeyers.Count - 1 do
      begin
      if SameText(FKeyers[i].Id, aId) then
         begin
         Result := FKeyers[i];
         Exit;
         end;
      end;
end;

function TKeyerConfigStore.FindKeyer(const aName: string): TKeyerDefinition;
var
   i: integer;
begin
   Result := nil;
   i := IndexOfKeyer(aName);
   if i >= 0 then
      begin
      Result := FKeyers[i];
      end;
end;

function TKeyerConfigStore.AddKeyer(const aName: string;
                                    const aKind: TKeyerKind): TKeyerDefinition;
begin
   Result := TKeyerDefinition.Create;
   Result.Name := Trim(aName);
   Result.Kind := aKind;
   FKeyers.Add(Result);
end;

function TKeyerConfigStore.RemoveKeyer(const aName: string): boolean;
var
   i: integer;
begin
   Result := False;
   i := IndexOfKeyer(aName);
   if i >= 0 then
      begin
      FKeyers.Delete(i);
      Result := True;
      end;
end;

function TKeyerConfigStore.RenameKeyer(const aOldName, aNewName: string;
                                       out aError: string): boolean;
var
   target: TKeyerDefinition;
   clash: integer;
begin
   aError := '';
   Result := False;

   target := FindKeyer(aOldName);
   if target = nil then
      begin
      aError := Format('There is no keyer named "%s".', [aOldName]);
      Exit;
      end;

   if Trim(aNewName) = '' then
      begin
      aError := 'A keyer needs a name.';
      Exit;
      end;

   // A rename to a different case of the SAME keyer is legal -- that is how an
   // operator fixes capitalisation -- so the clash test excludes itself.
   clash := IndexOfKeyer(aNewName);
   if (clash >= 0) and (FKeyers[clash] <> target) then
      begin
      aError := Format('A keyer named "%s" already exists.', [Trim(aNewName)]);
      Exit;
      end;

   target.Name := Trim(aNewName);
   Result := True;
end;

function TKeyerConfigStore.UniqueKeyerName(const aBase: string): string;
var
   n: integer;
   base: string;
begin
   base := Trim(aBase);
   if base = '' then
      begin
      base := 'Keyer';
      end;

   Result := base;
   n := 1;
   while IndexOfKeyer(Result) >= 0 do
      begin
      Inc(n);
      Result := base + ' ' + IntToStr(n);
      end;
end;

function TKeyerConfigStore.Validate(out aError: string): boolean;
var
   i, j: integer;
begin
   aError := '';
   Result := False;

   for i := 0 to FKeyers.Count - 1 do
      begin
      if Trim(FKeyers[i].Name) = '' then
         begin
         aError := 'Every keyer needs a name.';
         Exit;
         end;

      for j := i + 1 to FKeyers.Count - 1 do
         begin
         if SameText(FKeyers[i].Name, FKeyers[j].Name) then
            begin
            aError := Format('Two keyers are both named "%s".', [FKeyers[i].Name]);
            Exit;
            end;
         end;

      // A keyer that needs a port and has none cannot key. Reported here rather
      // than left to fail silently at the device, which presents as a hardware
      // fault (see the radio track: a silent downgrade cost a bench session).
      // EVERY device here has a port -- CW-by-CAT and radio-port keying are the
      // radio's business, not library rows -- so this is unconditional.
      if (Trim(FKeyers[i].Port) = '') or SameText(FKeyers[i].Port, PORT_NONE) then
         begin
         aError := Format('Keyer "%s" has no port.', [FKeyers[i].Name]);
         Exit;
         end;
      end;

   Result := True;
end;

{ ------------------------------------------------------------------ JSON --- }

function TKeyerConfigStore.KeyerToJSON(const aKeyer: TKeyerDefinition): TJSONObject;
begin
   Result := TJSONObject.Create;
   // NAME IS A VALUE, not a key. The ini encoded a definition's name in its
   // section header, which made ']' and '=' hazards; the radio store learned
   // that in F-5a and this follows it.
   Result.AddPair('id',   aKeyer.Id);
   Result.AddPair('name', aKeyer.Name);
   Result.AddPair('kind', KeyerKindToStr(aKeyer.Kind));
   Result.AddPair('port', aKeyer.Port);

   Result.AddPair('wkKeyerMode', aKeyer.WKKeyerMode);
   Result.AddPair('wkSidetoneFrequency', aKeyer.WKSidetoneFrequency);
   Result.AddPair('wkAutospace', TJSONBool.Create(aKeyer.WKAutospace));
   Result.AddPair('wkCTSpacing', TJSONBool.Create(aKeyer.WKCTSpacing));
   Result.AddPair('wkIgnoreSpeedPot', TJSONBool.Create(aKeyer.WKIgnoreSpeedPot));
   Result.AddPair('wkPaddleOnlySidetone', TJSONBool.Create(aKeyer.WKPaddleOnlySidetone));
   Result.AddPair('wkPaddleSwap', TJSONBool.Create(aKeyer.WKPaddleSwap));
   Result.AddPair('wkSidetoneEnable', TJSONBool.Create(aKeyer.WKSidetoneEnable));
   Result.AddPair('wkWeight', TJSONNumber.Create(aKeyer.WKWeight));
   Result.AddPair('wkLeadInTime', TJSONNumber.Create(aKeyer.WKLeadInTime));
   Result.AddPair('wkTailTime', TJSONNumber.Create(aKeyer.WKTailTime));
   Result.AddPair('wkDitDahRatio', TJSONNumber.Create(aKeyer.WKDitDahRatio));
   Result.AddPair('wkFirstExtension', TJSONNumber.Create(aKeyer.WKFirstExtension));
   Result.AddPair('wkKeyerCompensation', TJSONNumber.Create(aKeyer.WKKeyerCompensation));
   Result.AddPair('wkPaddleSwitchpoint', TJSONNumber.Create(aKeyer.WKPaddleSwitchpoint));
end;

procedure TKeyerConfigStore.KeyerFromJSON(const aObj: TJSONObject;
                                          const aKeyer: TKeyerDefinition);

   function Str(const aKey, aDefault: string): string;
   var
      v: TJSONValue;
   begin
      Result := aDefault;
      v := aObj.GetValue(aKey);
      if v <> nil then
         begin
         Result := JSONText(v);
         end;
   end;

   function Num(const aKey: string; const aDefault: integer): integer;
   var
      v: TJSONValue;
   begin
      Result := aDefault;
      v := aObj.GetValue(aKey);
      if v <> nil then
         begin
         Result := StrToIntDef(JSONText(v), aDefault);
         end;
   end;

   function Bool(const aKey: string; const aDefault: boolean): boolean;
   var
      v: TJSONValue;
   begin
      Result := aDefault;
      v := aObj.GetValue(aKey);
      if v is TJSONBool then
         begin
         Result := TJSONBool(v).AsBoolean;
         end
      else if v <> nil then
         begin
         // Tolerate 'TRUE'/'FALSE' from a hand-edited file. The store's job is
         // to read what an operator plausibly wrote, not to be strict for its
         // own sake.
         Result := SameText(JSONText(v), 'TRUE');
         end;
   end;

var
   kind: TKeyerKind;
begin
   aKeyer.Id := Str('id', '');
   if aKeyer.Id = '' then
      begin
      { A store written before keyers had ids. }
      aKeyer.Id := NewKeyerId;
      end;
   aKeyer.Name := Str('name', '');
   if StrToKeyerKind(Str('kind', ''), kind) then
      begin
      aKeyer.Kind := kind;
      end;
   aKeyer.Port := Str('port', PORT_NONE);

   aKeyer.WKKeyerMode          := Str('wkKeyerMode', '');
   aKeyer.WKSidetoneFrequency  := Str('wkSidetoneFrequency', '');
   aKeyer.WKAutospace          := Bool('wkAutospace', False);
   aKeyer.WKCTSpacing          := Bool('wkCTSpacing', False);
   aKeyer.WKIgnoreSpeedPot     := Bool('wkIgnoreSpeedPot', False);
   aKeyer.WKPaddleOnlySidetone := Bool('wkPaddleOnlySidetone', False);
   aKeyer.WKPaddleSwap         := Bool('wkPaddleSwap', False);
   aKeyer.WKSidetoneEnable     := Bool('wkSidetoneEnable', False);
   aKeyer.WKWeight             := Num('wkWeight', 0);
   aKeyer.WKLeadInTime         := Num('wkLeadInTime', 0);
   aKeyer.WKTailTime           := Num('wkTailTime', 0);
   aKeyer.WKDitDahRatio        := Num('wkDitDahRatio', 0);
   aKeyer.WKFirstExtension     := Num('wkFirstExtension', 0);
   aKeyer.WKKeyerCompensation  := Num('wkKeyerCompensation', 0);
   aKeyer.WKPaddleSwitchpoint  := Num('wkPaddleSwitchpoint', 0);
end;

function TKeyerConfigStore.ToJSON: TJSONArray;
var
   i: integer;
begin
   Result := TJSONArray.Create;
   for i := 0 to FKeyers.Count - 1 do
      begin
      Result.AddElement(KeyerToJSON(FKeyers[i]));
      end;
end;

procedure TKeyerConfigStore.FromJSON(const aArray: TJSONArray);
var
   i: integer;
   obj: TJSONObject;
   k: TKeyerDefinition;
begin
   Clear;
   if aArray = nil then
      begin
      Exit;
      end;

   for i := 0 to aArray.Count - 1 do
      begin
      if aArray.Items[i] is TJSONObject then
         begin
         obj := TJSONObject(aArray.Items[i]);
         k := TKeyerDefinition.Create;
         KeyerFromJSON(obj, k);
         FKeyers.Add(k);
         end;
      end;
end;

end.

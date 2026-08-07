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

{
  The KEYER LIBRARY: define many keyers once, reference one by name.

  Exactly the shape uRadioConfigStore gave radios, for the same reason.  TR4W
  has four mutually exclusive ways to key CW -- WinKeyer, YCCC SO2R+, CPU
  (DTR/RTS/LPT) and CW-by-CAT -- and today their settings sit in one flat
  command list, where WK PORT, PADDLE PORT and RADIO ONE CW BY CAT all read as
  station-wide facts rather than as properties of a particular keyer.  An
  operator with a WinKeyer at the desk and a laptop that keys by CAT has to
  retype settings rather than pick one.

  So: DEFINE the keyers, then REFERENCE one by name (from a station profile, or
  a radio).  That also retires ActiveCWKeyer's precedence chain
  (CAT -> WinKeyer -> YCCC -> CPU), which docs/CW_Keyer_Factory_Plan.md records
  as an artifact of the original if/else ordering rather than a decision: a
  named reference makes it a lookup.

  WHAT THIS UNIT IS AND IS NOT.  A pure data store -- it holds the library,
  validates it, and reads/writes JSON.  It knows nothing about uWinKey, the CW
  keyer factory, the legacy WK/PADDLE command rows, or any UI.  Turning a
  definition into a live keyer is the apply layer's job; editing one is the FMX
  preferences UI's.  Keeping that line sharp is what lets test/unit link this
  without booting MainUnit and the contest engine's globals.

  ON UNIT DEPENDENCIES.  SysUtils, Classes, Generics.Collections and
  System.JSON -- all RTL.  No VCL, no FMX, no TR4W unit at all.

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
   System.SysUtils,
   System.Classes,
   System.JSON,
   System.Generics.Collections;

type
   { The ways TR4W can key CW.  Held as an enum here (unlike the radio store's
     opaque registry id) because this list is CLOSED -- it is a property of the
     program, not of a registry that gains models.  See
     docs/CW_Keyer_Factory_Plan.md.

     NOT ALL OF THEM ARE INDEPENDENT HARDWARE (NY4I, 2026-08-07).  Three own a
     port and stand alone; two BORROW THE SLOT'S RADIO and mean nothing without
     it:

       kkWinKeyer   own COM port          independent
       kkYCCC       own port              independent
       kkCPU        own port, DTR/RTS/LPT independent
       kkRadioPort  the RADIO's control port, keyed by DTR/RTS   <- radio-relative
       kkCWByCAT    commands over the radio's CAT link           <- radio-relative

     The last two are why a profile pairs a keyer WITH a radio rather than
     choosing them independently: "the radio's COM port" has no meaning until
     you know which radio is in the slot, and CW by CAT is only possible if that
     radio supports it. }
   TKeyerKind = (kkWinKeyer, kkYCCC, kkCPU, kkRadioPort, kkCWByCAT);

const
   // The JSON spelling of each kind.  Text, not the ordinal -- which is what
   // made ADDING kkRadioPort in the middle of the enum safe: every file already
   // written still reads back correctly.
   KEYERKINDSTR: array[TKeyerKind] of string =
      ('WINKEYER', 'YCCC', 'CPU', 'RADIOPORT', 'CWBYCAT');

   PORT_NONE = 'NONE';

type
   { ONE keyer definition.  Fields are flat and kind-specific groups sit
     together, exactly as TRadioDefinition keeps serial and network fields flat
     with Transport selecting between them.  A variant record would be tidier
     and much worse to serialise, diff and edit. }
   TKeyerDefinition = class(TObject)
   public
      // Identity.  Name is what the operator sees and what a profile or radio
      // refers to, so it is unique within a store (case-insensitively) and
      // renaming has to fix the references.
      Name: string;
      Kind: TKeyerKind;

      // --- shared ------------------------------------------------------------
      // The port this keyer speaks on, in the PortTypeSA vocabulary.
      // MEANINGLESS for kkCWByCAT, which uses whichever radio is nominated --
      // that is the whole point of it, and why Port is not required below.
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

      // --- CPU / paddle (DTR, RTS, LPT) --------------------------------------
      PaddlePort: string;
      PaddleBugEnable: boolean;
      PaddleSwap: boolean;
      PaddleSpeed: integer;
      PaddleMonitorTone: integer;
      PaddlePTTHoldCount: integer;
      CurtisKeyerMode: string;

      constructor Create;
      procedure Assign(const aSource: TKeyerDefinition);
      function Clone: TKeyerDefinition;
      // Field-by-field, so a dialog can answer "did anything change" without a
      // dirty flag that goes stale the moment someone adds a field. Name is
      // included: renaming IS a change.
      function SameAs(const aOther: TKeyerDefinition): boolean;
      // One line for a list box: 'Desk WinKey [SERIAL 3]', 'By CAT'.
      function DisplaySummary: string;
      // True when this kind needs a port of its own -- so Validate can insist
      // on one without tripping over the kinds that borrow the radio's.
      function UsesOwnPort: boolean;
      // True when this keyer is meaningless without knowing which radio is in
      // the slot: kkRadioPort borrows the radio's control port, kkCWByCAT sends
      // over its CAT link.
      //
      // THE STORE DELIBERATELY STOPS HERE.  Whether a PARTICULAR radio can do
      // CW by CAT is a capability question, and answering it needs
      // uRadioRegistry -- which this RTL-only unit must not reach.  The profile
      // and apply layers own that check, and they must ask the RADIO
      // (HasCapability(rcCWByCAT)), never the model enum: a model-keyed gate is
      // exactly what once left TCI, a string-id radio, with no CW at all.
      function NeedsSlotRadio: boolean;
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

constructor TKeyerDefinition.Create;
begin
   inherited Create;
   Kind := kkWinKeyer;
   Port := PORT_NONE;
   PaddlePort := PORT_NONE;
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

   PaddlePort         := aSource.PaddlePort;
   PaddleBugEnable    := aSource.PaddleBugEnable;
   PaddleSwap         := aSource.PaddleSwap;
   PaddleSpeed        := aSource.PaddleSpeed;
   PaddleMonitorTone  := aSource.PaddleMonitorTone;
   PaddlePTTHoldCount := aSource.PaddlePTTHoldCount;
   CurtisKeyerMode    := aSource.CurtisKeyerMode;
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
      (WKPaddleSwitchpoint = aOther.WKPaddleSwitchpoint) and
      SameText(PaddlePort, aOther.PaddlePort) and
      (PaddleBugEnable = aOther.PaddleBugEnable) and
      (PaddleSwap = aOther.PaddleSwap) and
      (PaddleSpeed = aOther.PaddleSpeed) and
      (PaddleMonitorTone = aOther.PaddleMonitorTone) and
      (PaddlePTTHoldCount = aOther.PaddlePTTHoldCount) and
      SameText(CurtisKeyerMode, aOther.CurtisKeyerMode);
end;

function TKeyerDefinition.UsesOwnPort: boolean;
begin
   // The radio-relative kinds have no port of their own -- kkRadioPort borrows
   // the radio's control port, kkCWByCAT uses its CAT link. Asking the KIND
   // rather than testing Port <> '' means an empty port on a WinKeyer is still
   // reportable as the mistake it is.
   Result := not NeedsSlotRadio;
end;

function TKeyerDefinition.NeedsSlotRadio: boolean;
begin
   Result := Kind in [kkRadioPort, kkCWByCAT];
end;

function TKeyerDefinition.DisplaySummary: string;
begin
   Result := Name;
   if Result = '' then
      begin
      Result := '(unnamed)';
      end;

   case Kind of
      kkCWByCAT:
         begin
         // No port named, because it depends on the slot's radio -- saying
         // otherwise in a list box would be a small lie the operator has to
         // discover.
         Result := Result + ' [by CAT, this slot''s radio]';
         end;
      kkRadioPort:
         begin
         Result := Result + ' [radio''s COM port, DTR/RTS]';
         end;
      kkCPU:
         begin
         Result := Result + ' [CPU ' + PaddlePort + ']';
         end;
   else
      begin
      Result := Result + ' [' + KeyerKindToStr(Kind) + ' ' + Port + ']';
      end;
   end;
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
      if FKeyers[i].UsesOwnPort and
         ((Trim(FKeyers[i].Port) = '') or SameText(FKeyers[i].Port, PORT_NONE)) then
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

   Result.AddPair('paddlePort', aKeyer.PaddlePort);
   Result.AddPair('paddleBugEnable', TJSONBool.Create(aKeyer.PaddleBugEnable));
   Result.AddPair('paddleSwap', TJSONBool.Create(aKeyer.PaddleSwap));
   Result.AddPair('paddleSpeed', TJSONNumber.Create(aKeyer.PaddleSpeed));
   Result.AddPair('paddleMonitorTone', TJSONNumber.Create(aKeyer.PaddleMonitorTone));
   Result.AddPair('paddlePTTHoldCount', TJSONNumber.Create(aKeyer.PaddlePTTHoldCount));
   Result.AddPair('curtisKeyerMode', aKeyer.CurtisKeyerMode);
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
         Result := v.Value;
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
         Result := StrToIntDef(v.Value, aDefault);
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
         Result := SameText(v.Value, 'TRUE');
         end;
   end;

var
   kind: TKeyerKind;
begin
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

   aKeyer.PaddlePort         := Str('paddlePort', PORT_NONE);
   aKeyer.PaddleBugEnable    := Bool('paddleBugEnable', False);
   aKeyer.PaddleSwap         := Bool('paddleSwap', False);
   aKeyer.PaddleSpeed        := Num('paddleSpeed', 0);
   aKeyer.PaddleMonitorTone  := Num('paddleMonitorTone', 0);
   aKeyer.PaddlePTTHoldCount := Num('paddlePTTHoldCount', 0);
   aKeyer.CurtisKeyerMode    := Str('curtisKeyerMode', '');
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

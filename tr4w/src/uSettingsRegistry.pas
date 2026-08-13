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
unit uSettingsRegistry;
{$I tr4w.inc}

{
  THE SETTINGS REGISTRY -- what CommandsArray would be if it were written today.

  WHY THIS EXISTS.  CFGCA describes a setting as an untyped POINTER plus a tag
  saying how to dereference it:

      (crCommand: 'MY CALL';             crAddress: @MyCall;    crType: ctString)
      (crCommand: 'SCP MINIMUM LETTERS'; crAddress: pointer(1); crType: ctInteger;
                                         crKind: ckArray)

  Those two crAddress values have the SAME TYPE as far as the compiler is
  concerned -- one is a variable's address, the other is an INDEX into a
  different array entirely -- and the only thing standing between them is a
  reader remembering to check crKind first.  On 2026-08-11 a reader did not, and
  the program dereferenced the integer 1 (NY4I: "If we were designing a config
  management system from scratch, would we use procedure addresses like this?").

  No.  So this unit does not.

  A SETTING IS A CLOSURE PAIR, NOT AN ADDRESS.  Each setting carries a typed
  getter and setter over whatever storage actually holds it:

      RegisterSetting(TBoolSetting.Create('operating.cw.sayHi', 'Send a greeting',
         function: boolean begin Result := SayHiEnable end,
         procedure (const v: boolean) begin SayHiEnable := v end));

  What that buys, point by point against the old table:

    crAddress   gone.  There is no pointer to mis-dereference.  The setter is
                ordinary Pascal that assigns a variable, checked by the compiler.
    crType      gone.  The type IS the closure's type.  A boolean setting cannot
                be read as an integer, because there is nothing to cast.
    crKind      gone.  ckArray was "crAddress is secretly an index"; an
                allow-list is now DECLARED on the setting (TIntSetting.Allowed),
                where a UI can read it and offer exactly those values.
    crMin/crMax declared per setting and enforced in one place, not re-checked by
                every caller that assigns.
    crA         an OnApply closure -- derive dependent state right here, next to
                the setting it depends on, instead of an index into
                AdditionalProcsArray whose function reads its argument out of a
                global called CMD.
    crP         an OnChanged closure, for redrawing what now looks wrong.

  WHERE SETTINGS REGISTER.  Beside the code that owns them, exactly as radios
  self-register in the radio factory -- so adding a setting touches the unit it
  belongs to, and nothing else.  A central table is the thing that has to be
  edited from far away and therefore drifts.

  ON THE GLOBALS.  This does NOT try to abolish TR4W's global variables; they
  are read from thousands of places and that is a separate, much larger job.
  The registry sits in FRONT of them: the store persists by key, the UI binds by
  key, and the setter is the one place that knows a given setting lives in a
  global called SayHiEnable.  When a global is eventually replaced, only its
  closure changes.

  ON CFGCA.  It stays as the READER FOR OLD INI FILES, which is a job it does
  well and which nothing else can do.  A setting that moves here has its CFGCA
  row marked csJSON, so the loader accepts an old key without applying it, and
  this registry becomes the system of record.
}

interface

uses
   SysUtils,
   Generics.Collections;

type
   { METHOD POINTERS, not anonymous methods.

     These were TFunc<T> / TProc<T> -- generic anonymous method types. They read
     beautifully and they cost a closure-capable compiler: FPC 3.2.2 stable
     answers `Identifier not found "reference"`. `of object` says the same thing
     with the owner named rather than implied, which is the property the rotator
     factory gained from the same change.

     A setting binds to storage SOMEBODY ELSE owns -- a CFGCA row, a global, a
     record field -- so a method pointer is the honest shape: there is always an
     object behind the pair. Where there genuinely was not one, see the cells
     below. }
   TSettingApplyProc = procedure of object;

   TBoolGetter   = function: boolean of object;
   TBoolSetter   = procedure (aValue: boolean) of object;
   TIntGetter    = function: integer of object;
   TIntSetter    = procedure (aValue: integer) of object;
   TStringGetter = function: string of object;
   TStringSetter = procedure (aValue: string) of object;

   { STORAGE FOR A SETTING THAT HAS NO HOME ELSEWHERE.

     `Own` used to capture a one-element dynamic array, which gave the closure
     something to hold that outlived the call. That is a cell object with the
     object left out, so here it is with the object put back: same lifetime, same
     single value, and now something a method pointer can point at.

     The setting OWNS the cell it creates -- see TSettingBase.OwnCell -- so a
     self-storing setting still cleans up after itself the way the closure did. }
   TBoolCell = class
   private
      FValue: boolean;
   public
      constructor Create(const aDefault: boolean);
      function  Get: boolean;
      procedure SetValue(aValue: boolean);
   end;

   TIntCell = class
   private
      FValue: integer;
   public
      constructor Create(const aDefault: integer);
      function  Get: integer;
      procedure SetValue(aValue: integer);
   end;

   TStringCell = class
   private
      FValue: string;
   public
      constructor Create(const aDefault: string);
      function  Get: string;
      procedure SetValue(aValue: string);
   end;

   { What a setting is made of that a UI or a persister can use without knowing
     the setting's type.  Everything type-specific is on the descendants. }
   TSettingBase = class abstract
   private
      FKey: string;
      FCaption: string;
      FNeedsRestart: boolean;
      FOnApply: TSettingApplyProc;
      { A cell this setting created for itself, or nil.  See TBoolCell. }
      FOwnedCell: TObject;
   public
      constructor Create(const aKey, aCaption: string);
      destructor Destroy; override;

      { Take ownership of a cell created by Own, so a self-storing setting still
        cleans up after itself exactly as the captured array did. }
      procedure OwnCell(const aCell: TObject);

      { The value as text, for JSON and for a text control.  Never raises: a
        setting that cannot render itself is a bug in the setting, not something
        for a caller to guard on every use. }
      function AsText: string; virtual; abstract;

      { Parse, validate and assign.  False with aError set means NOTHING was
        assigned -- the caller can show aError and the setting keeps its value.
        This is the whole validation story; there is no second copy in the UI. }
      function TrySetText(const aText: string; out aError: string): boolean; virtual; abstract;

      { The values this setting will accept, when that is a short fixed list.
        Empty means "not an enumerated setting" -- NOT "accepts nothing".  A UI
        offers a drop-down when this is non-empty and a text box otherwise,
        which is what stops a control offering values the setting will refuse. }
      function AllowedValues: TArray<string>; virtual;

      { The JSON key and the store key: 'operating.cw.sayHi'.  Dotted so the
        persister can nest, and stable so a caption can be reworded or
        translated without moving anyone's settings. }
      property Key: string read FKey;
      property Caption: string read FCaption write FCaption;

      { True when the running program will not pick this up until restart.  A UI
        that knows this can say so; today that fact lives only in crJ:1 and in
        whatever the operator remembers. }
      property NeedsRestart: boolean read FNeedsRestart write FNeedsRestart;

      { Runs after a successful set: derive dependent state, redraw, restart a
        server.  Replaces crA and crP, and unlike them it is written next to the
        setting rather than in a numbered array. }
      property OnApply: TSettingApplyProc read FOnApply write FOnApply;
   end;

   TBoolSetting = class(TSettingBase)
   private
      FGet: TBoolGetter;
      FSet: TBoolSetter;
   public
      constructor Create(const aKey, aCaption: string;
                         const aGet: TBoolGetter; const aSet: TBoolSetter);
      function AsText: string; override;
      function TrySetText(const aText: string; out aError: string): boolean; override;
      function AllowedValues: TArray<string>; override;

      { SELF-STORING: the registry holds the value and there is no global
        anywhere.  For a setting that is genuinely NEW.

        The closure form above exists to WRAP an existing global during
        migration.  A new setting has nothing to wrap, and making one declare a
        global first would be the old design creeping back in through the door
        marked "consistency" -- so it does not have to. }
      class function Own(const aKey, aCaption: string;
                         const aDefault: boolean): TBoolSetting;

      function Value: boolean;
      procedure SetValue(const aValue: boolean);
   end;

   TIntSetting = class(TSettingBase)
   private
      FGet: TIntGetter;
      FSet: TIntSetter;
      FMin, FMax: integer;
      FAllowed: TArray<integer>;
   public
      { aMin/aMax bound a RANGE.  For a setting that accepts only particular
        values, pass them to Allowed instead -- that is the old ckArray, made
        explicit rather than hidden behind a pointer that is really an index. }
      constructor Create(const aKey, aCaption: string;
                         const aGet: TIntGetter; const aSet: TIntSetter;
                         const aMin: integer = Low(integer);
                         const aMax: integer = High(integer));
      function AsText: string; override;
      function TrySetText(const aText: string; out aError: string): boolean; override;
      function AllowedValues: TArray<string>; override;

      function Value: integer;
      procedure SetValue(const aValue: integer);

      { Restrict to a fixed set.  Returns Self so it reads as one declaration. }
      function Allowed(const aValues: array of integer): TIntSetting;

      { Self-storing -- see TBoolSetting.Own. }
      class function Own(const aKey, aCaption: string; const aDefault: integer;
                         const aMin: integer = Low(integer);
                         const aMax: integer = High(integer)): TIntSetting;
   end;

   TStringSetting = class(TSettingBase)
   private
      FGet: TStringGetter;
      FSet: TStringSetter;
      FMaxLength: integer;
      FIsSecret: boolean;
   public
      constructor Create(const aKey, aCaption: string;
                         const aGet: TStringGetter; const aSet: TStringSetter;
                         const aMaxLength: integer = 0);
      function AsText: string; override;
      function TrySetText(const aText: string; out aError: string): boolean; override;

      function Value: string;
      procedure SetValue(const aValue: string);

      { A password.  Marked rather than guessed at from the key, so a UI can
        mask it and a log can refuse to print it. }
      function Secret: TStringSetting;
      property IsSecret: boolean read FIsSecret;

      { Self-storing -- see TBoolSetting.Own. }
      class function Own(const aKey, aCaption: string; const aDefault: string;
                         const aMaxLength: integer = 0): TStringSetting;
   end;

   TEnumSetting = class(TSettingBase)
   private
      FGet: TStringGetter;
      FSet: TStringSetter;
      FValues: TArray<string>;
   public
      { The values ARE the contract, so they are required rather than optional.
        This replaces ckList, where the values lived in a parallel array reached
        through an index stored in a pointer field. }
      constructor Create(const aKey, aCaption: string;
                         const aGet: TStringGetter; const aSet: TStringSetter;
                         const aValues: array of string);
      function AsText: string; override;
      function TrySetText(const aText: string; out aError: string): boolean; override;
      function AllowedValues: TArray<string>; override;

      { Self-storing -- see TBoolSetting.Own.  The default MUST be one of the
        declared values, or the setting starts in a state it will not let you
        return to. }
      class function Own(const aKey, aCaption: string; const aDefault: string;
                         const aValues: array of string): TEnumSetting;
   end;

{ Registration.  Takes ownership; the registry frees everything at shutdown.
  Returns the setting so a declaration can be chained -- see TIntSetting.Allowed. }
function RegisterSetting(const aSetting: TSettingBase): TSettingBase;

{ Look-up by key.  nil when there is no such setting, which a caller should
  treat as a programming error rather than a user one. }
function FindSetting(const aKey: string): TSettingBase;

{ Every registered setting, in registration order. }
function AllSettings: TArray<TSettingBase>;

{ How many are registered.  Exists so a test can assert that a unit's
  initialization actually ran -- a self-registering unit that gets dropped from
  the project link is silent otherwise, which is the one real hazard of this
  pattern and the same one the radio registry guards against. }
function SettingCount: integer;

implementation

var
   GSettings: TObjectList<TSettingBase> = nil;
   GByKey: TDictionary<string, TSettingBase> = nil;

{ ------------------------------------------------------------ TSettingBase - }

{ ------------------------------------------------------------- the cells --- }

constructor TBoolCell.Create(const aDefault: boolean);
begin
   inherited Create;
   FValue := aDefault;
end;

function TBoolCell.Get: boolean;
begin
   Result := FValue;
end;

procedure TBoolCell.SetValue(aValue: boolean);
begin
   FValue := aValue;
end;

constructor TIntCell.Create(const aDefault: integer);
begin
   inherited Create;
   FValue := aDefault;
end;

function TIntCell.Get: integer;
begin
   Result := FValue;
end;

procedure TIntCell.SetValue(aValue: integer);
begin
   FValue := aValue;
end;

constructor TStringCell.Create(const aDefault: string);
begin
   inherited Create;
   FValue := aDefault;
end;

function TStringCell.Get: string;
begin
   Result := FValue;
end;

procedure TStringCell.SetValue(aValue: string);
begin
   FValue := aValue;
end;

{ -------------------------------------------------------- TSettingBase ----- }

constructor TSettingBase.Create(const aKey, aCaption: string);
begin
   inherited Create;
   FKey     := aKey;
   FCaption := aCaption;
end;

destructor TSettingBase.Destroy;
begin
   // Only a cell this setting MADE for itself.  A setting bound to somebody
   // else's storage owns nothing and frees nothing -- FOwnedCell is nil there,
   // which is the whole point of it being a separate field rather than a flag.
   FreeAndNil(FOwnedCell);
   inherited Destroy;
end;

procedure TSettingBase.OwnCell(const aCell: TObject);
begin
   FOwnedCell := aCell;
end;

function TSettingBase.AllowedValues: TArray<string>;
begin
   // Not enumerated.  See the declaration: empty means "no fixed list", which a
   // UI reads as "use a text box", not as "refuses everything".
   Result := nil;
end;

{ ------------------------------------------------------ self-storing ------ }

{ HOW THESE WORK, because the trick is worth understanding before anyone edits
  one.  A self-storing setting has no global to point at, so it makes its own
  storage: a one-element array captured by the getter and setter closures.  The
  array is a managed dynamic array, so it lives as long as the closures do and
  is freed with them -- there is nothing to leak and nothing to free by hand.

  A local variable would NOT do.  It goes out of scope when the constructor
  returns, and the closures would capture a dead frame.  Delphi's closures
  capture VARIABLES, not values, which is exactly what makes the array work and
  a plain local fail. }

{ ------------------------------------------------------------ TBoolSetting - }

constructor TBoolSetting.Create(const aKey, aCaption: string;
                                const aGet: TBoolGetter; const aSet: TBoolSetter);
begin
   inherited Create(aKey, aCaption);
   FGet := aGet;
   FSet := aSet;
end;

class function TBoolSetting.Own(const aKey, aCaption: string;
                                const aDefault: boolean): TBoolSetting;
var
   cell: TBoolCell;
begin
   cell := TBoolCell.Create(aDefault);
   Result := TBoolSetting.Create(aKey, aCaption, cell.Get, cell.SetValue);
   Result.OwnCell(cell);
end;

function TBoolSetting.Value: boolean;
begin
   Result := FGet();
end;

procedure TBoolSetting.SetValue(const aValue: boolean);
begin
   FSet(aValue);
   if Assigned(OnApply) then
      begin
      OnApply();
      end;
end;

function TBoolSetting.AsText: string;
begin
   // TRUE/FALSE, which is what the ini has always held and what an operator
   // reading the JSON will expect to see.
   if Value then
      begin
      Result := 'TRUE';
      end
   else
      begin
      Result := 'FALSE';
      end;
end;

function TBoolSetting.TrySetText(const aText: string; out aError: string): boolean;
var
   t: string;
begin
   aError := '';
   t := UpperCase(Trim(aText));

   // Generous on input, exact on output.  Files get hand-edited, and refusing
   // 'Yes' or '1' to be strict about a boolean helps nobody.
   if (t = 'TRUE') or (t = 'YES') or (t = 'ON') or (t = '1') then
      begin
      SetValue(True);
      Result := True;
      end
   else if (t = 'FALSE') or (t = 'NO') or (t = 'OFF') or (t = '0') then
      begin
      SetValue(False);
      Result := True;
      end
   else
      begin
      aError := Format('"%s" is not true or false', [aText]);
      Result := False;
      end;
end;

function TBoolSetting.AllowedValues: TArray<string>;
begin
   Result := ['TRUE', 'FALSE'];
end;

{ ------------------------------------------------------------- TIntSetting - }

constructor TIntSetting.Create(const aKey, aCaption: string;
                               const aGet: TIntGetter; const aSet: TIntSetter;
                               const aMin, aMax: integer);
begin
   inherited Create(aKey, aCaption);
   FGet := aGet;
   FSet := aSet;
   FMin := aMin;
   FMax := aMax;
end;

class function TIntSetting.Own(const aKey, aCaption: string; const aDefault: integer;
                               const aMin, aMax: integer): TIntSetting;
var
   cell: TIntCell;
begin
   cell := TIntCell.Create(aDefault);
   Result := TIntSetting.Create(aKey, aCaption, cell.Get, cell.SetValue,
      aMin, aMax);
end;

function TIntSetting.Allowed(const aValues: array of integer): TIntSetting;
var
   i: integer;
begin
   SetLength(FAllowed, Length(aValues));
   for i := Low(aValues) to High(aValues) do
      begin
      FAllowed[i - Low(aValues)] := aValues[i];
      end;
   Result := Self;
end;

function TIntSetting.Value: integer;
begin
   Result := FGet();
end;

procedure TIntSetting.SetValue(const aValue: integer);
begin
   FSet(aValue);
   if Assigned(OnApply) then
      begin
      OnApply();
      end;
end;

function TIntSetting.AsText: string;
begin
   Result := IntToStr(Value);
end;

function TIntSetting.AllowedValues: TArray<string>;
var
   i: integer;
begin
   SetLength(Result, Length(FAllowed));
   for i := 0 to High(FAllowed) do
      begin
      Result[i] := IntToStr(FAllowed[i]);
      end;
end;

function TIntSetting.TrySetText(const aText: string; out aError: string): boolean;
var
   n, i: integer;
begin
   aError := '';
   Result := False;

   // Val, not StrToIntDef(s, 0): a default turns "garbage" into a legal-looking
   // zero, and for a port or a count zero usually means something specific.
   if not TryStrToInt(Trim(aText), n) then
      begin
      aError := Format('"%s" is not a whole number', [aText]);
      Exit;
      end;

   // An allow-list beats the range when there is one -- it IS the range, and a
   // more specific one.
   if Length(FAllowed) > 0 then
      begin
      for i := 0 to High(FAllowed) do
         begin
         if FAllowed[i] = n then
            begin
            SetValue(n);
            Result := True;
            Exit;
            end;
         end;
      aError := Format('%d is not one of the values this setting accepts', [n]);
      Exit;
      end;

   if (n < FMin) or (n > FMax) then
      begin
      aError := Format('%d is outside %d..%d', [n, FMin, FMax]);
      Exit;
      end;

   SetValue(n);
   Result := True;
end;

{ ---------------------------------------------------------- TStringSetting - }

constructor TStringSetting.Create(const aKey, aCaption: string;
                                  const aGet: TStringGetter; const aSet: TStringSetter;
                                  const aMaxLength: integer);
begin
   inherited Create(aKey, aCaption);
   FGet       := aGet;
   FSet       := aSet;
   FMaxLength := aMaxLength;
end;

class function TStringSetting.Own(const aKey, aCaption: string; const aDefault: string;
                                  const aMaxLength: integer): TStringSetting;
var
   cell: TStringCell;
begin
   cell := TStringCell.Create(aDefault);
   Result := TStringSetting.Create(aKey, aCaption, cell.Get, cell.SetValue,
      aMaxLength);
end;

function TStringSetting.Secret: TStringSetting;
begin
   FIsSecret := True;
   Result := Self;
end;

function TStringSetting.Value: string;
begin
   Result := FGet();
end;

procedure TStringSetting.SetValue(const aValue: string);
begin
   FSet(aValue);
   if Assigned(OnApply) then
      begin
      OnApply();
      end;
end;

function TStringSetting.AsText: string;
begin
   Result := Value;
end;

function TStringSetting.TrySetText(const aText: string; out aError: string): boolean;
begin
   aError := '';

   // REFUSED, not truncated.  The legacy targets are ShortStrings, where an
   // over-long assignment is silently cut -- so the operator sees a value they
   // did not type and no explanation.
   if (FMaxLength > 0) and (Length(aText) > FMaxLength) then
      begin
      aError := Format('longer than %d characters', [FMaxLength]);
      Result := False;
      Exit;
      end;

   // NOT trimmed: a password may legitimately begin or end with a space, and
   // this class cannot tell which strings those are.  Trimming belongs to the
   // caller that knows.
   SetValue(aText);
   Result := True;
end;

{ ------------------------------------------------------------ TEnumSetting - }

constructor TEnumSetting.Create(const aKey, aCaption: string;
                                const aGet: TStringGetter; const aSet: TStringSetter;
                                const aValues: array of string);
var
   i: integer;
begin
   inherited Create(aKey, aCaption);
   FGet := aGet;
   FSet := aSet;
   SetLength(FValues, Length(aValues));
   for i := Low(aValues) to High(aValues) do
      begin
      FValues[i - Low(aValues)] := aValues[i];
      end;
end;

class function TEnumSetting.Own(const aKey, aCaption: string; const aDefault: string;
                                const aValues: array of string): TEnumSetting;
var
   cell: TStringCell;
   i: integer;
   ok: boolean;
begin
   // A DEFAULT OUTSIDE THE DECLARED VALUES is a setting that starts in a state
   // TrySetText will not let the operator return to -- so it is a defect at
   // registration, caught here rather than puzzled over later.
   ok := False;
   for i := Low(aValues) to High(aValues) do
      begin
      if SameText(aValues[i], aDefault) then
         begin
         ok := True;
         Break;
         end;
      end;
   if not ok then
      begin
      raise Exception.CreateFmt('Setting "%s": default "%s" is not one of its values',
                                [aKey, aDefault]);
      end;

   cell := TStringCell.Create(aDefault);
   Result := TEnumSetting.Create(aKey, aCaption, cell.Get, cell.SetValue, aValues);
   Result.OwnCell(cell);
end;

function TEnumSetting.AsText: string;
begin
   Result := FGet();
end;

function TEnumSetting.AllowedValues: TArray<string>;
begin
   Result := FValues;
end;

function TEnumSetting.TrySetText(const aText: string; out aError: string): boolean;
var
   i: integer;
begin
   aError := '';
   for i := 0 to High(FValues) do
      begin
      if SameText(FValues[i], Trim(aText)) then
         begin
         // The DECLARED spelling is stored, not what the operator typed, so a
         // hand-edited file with 'dxkeeper' becomes 'DXKEEPER' on the next save
         // and there is one spelling in the system.
         FSet(FValues[i]);
         if Assigned(OnApply) then
            begin
            OnApply();
            end;
         Result := True;
         Exit;
         end;
      end;
   aError := Format('"%s" is not one of the accepted values', [aText]);
   Result := False;
end;

{ ---------------------------------------------------------------- registry - }

function RegisterSetting(const aSetting: TSettingBase): TSettingBase;
begin
   if GSettings = nil then
      begin
      GSettings := TObjectList<TSettingBase>.Create(True);
      GByKey    := TDictionary<string, TSettingBase>.Create;
      end;

   // A DUPLICATE KEY IS A DEFECT, and a silent one: the second registration
   // would win in the dictionary while the first still sat in the list, so the
   // UI and the persister could disagree about which setting a key means.
   if GByKey.ContainsKey(LowerCase(aSetting.Key)) then
      begin
      raise Exception.CreateFmt('Setting "%s" is registered twice', [aSetting.Key]);
      end;

   GSettings.Add(aSetting);
   GByKey.Add(LowerCase(aSetting.Key), aSetting);
   Result := aSetting;
end;

function FindSetting(const aKey: string): TSettingBase;
begin
   if (GByKey = nil) or (not GByKey.TryGetValue(LowerCase(aKey), Result)) then
      begin
      Result := nil;
      end;
end;

function AllSettings: TArray<TSettingBase>;
begin
   if GSettings = nil then
      begin
      Result := nil;
      end
   else
      begin
      Result := GSettings.ToArray;
      end;
end;

function SettingCount: integer;
begin
   if GSettings = nil then
      begin
      Result := 0;
      end
   else
      begin
      Result := GSettings.Count;
      end;
end;

initialization

finalization
   FreeAndNil(GByKey);
   FreeAndNil(GSettings);

end.

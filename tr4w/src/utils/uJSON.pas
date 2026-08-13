unit uJSON;

// One JSON vocabulary for both compilers.
//
// TR4W's config stores were written against Delphi's System.JSON, which FPC does
// not have.  FPC ships fcl-json (fpjson + jsonparser), whose DOM is the same
// SHAPE -- object, array, string, number, boolean -- but spells the operations
// differently: Add rather than AddPair, Find rather than GetValue, FormatJSON
// rather than Format, GetJSON rather than TJSONObject.ParseJSONValue.
//
// The choice was between rewriting ~175 call sites across the four config units
// into neutral free functions, or teaching FPC the spellings the code already
// uses.  The second is what this unit does, via class helpers, and it is the
// safer of the two by a wide margin: the Delphi side keeps compiling EXACTLY the
// code it compiles today, so the ~1,099 config-store assertions are testing the
// same source they have always tested, and only the FPC path is new.
//
// Consequently the four config units change ONE LINE each -- System.JSON becomes
// uJSON -- and nothing else.
//
// ---------------------------------------------------------------------------
// The one semantic difference that is NOT cosmetic
// ---------------------------------------------------------------------------
// Delphi's TJSONObject.ParseJSONValue returns NIL for malformed input.  fpjson's
// GetJSON RAISES.  Every caller in TR4W tests the result against nil -- so left
// alone, a corrupt config file would be a silent nil-check on Delphi and an
// unhandled exception on FPC, at startup, on the user's machine.  The FPC
// helper below converts the exception to nil so both compilers fail the same
// way.  This is the whole reason the shim is a unit and not a set of aliases.
//
// ---------------------------------------------------------------------------
// Free functions rather than helpers where the two DOMs genuinely differ
// ---------------------------------------------------------------------------
// A type can have only one active class helper, so layering a TJSONValue helper
// under a TJSONObject helper would silently hide the former for objects.  The
// four operations that need real translation are therefore free functions,
// identical in name on both compilers:
//
//   JSONText      - the string form of a value.  Delphi's TJSONValue.Value is a
//                   string; fpjson's TJSONData.Value is a VARIANT, and letting
//                   that convert implicitly is exactly the class of silent
//                   boundary bug this project has already paid for.
//   JSONPairName  - Delphi indexes Pairs[i].JsonString; fpjson has Names[i].
//   JSONPairValue - Delphi indexes Pairs[i].JsonValue; fpjson has Items[i].
//   JSONGetStr /  - Delphi's GetValue<T>(name, default) is a GENERIC method.
//   JSONGetInt      FPC 3.2 does not carry generic methods on helpers.

{$I ..\tr4w.inc}

interface

uses
{$IFDEF FPC}
   fpjson,
   jsonparser;
{$ELSE}
   System.JSON;
{$ENDIF}

type
{$IFDEF FPC}
   TJSONValue  = TJSONData;
   TJSONObject = fpjson.TJSONObject;
   TJSONArray  = fpjson.TJSONArray;
   TJSONString = fpjson.TJSONString;
   TJSONBool   = TJSONBoolean;

   // fpjson.TJSONNumber is the ABSTRACT base over integer/int64/qword/float,
   // which is what Delphi's TJSONNumber also is.  Aliasing the concrete
   // TJSONIntegerNumber instead would have been a silent behaviour change: a
   // value written as 1.0 parses to TJSONFloatNumber, so every `v is TJSONNumber`
   // guard in the config stores would have said no and fallen back to the
   // default.
   TJSONNumber = fpjson.TJSONNumber;

   // Supplies the Delphi spellings on top of fpjson so the call sites need no
   // edit.  Delphi already has all of these, which is why the helper is FPC-only.
   TJSONObjectHelper = class helper for TJSONObject
   public
      function AddPair(const aName: string; const aValue: string): TJSONObject; overload;
      function AddPair(const aName: string; aValue: TJSONData): TJSONObject; overload;
      function GetValue(const aName: string): TJSONData;
      function FindValue(const aName: string): TJSONData;
      function Format(aIndent: integer): string;
      function ToJSON: string;
      class function ParseJSONValue(const aText: string): TJSONData;
   end;

   TJSONArrayHelper = class helper for TJSONArray
   public
      procedure AddElement(aValue: TJSONData);
      // Delphi's TJSONAncestor.ToJSON; fpjson spells it AsJSON.  Declared on
      // BOTH helpers rather than on a TJSONData helper, because a type can have
      // only one active class helper and the object/array ones would hide it.
      function ToJSON: string;
   end;

   // Two differences behind one alias.
   //
   // Delphi spells the accessor AsInt; fpjson spells it AsInteger.
   //
   // And Delphi's TJSONNumber is concrete -- TJSONNumber.Create(42) builds a
   // number -- while fpjson's is the abstract base and only its descendants
   // construct.  These class functions restore the Delphi spelling by picking
   // the right descendant, which also keeps an integer an INTEGER in the file:
   // routing everything through TJSONFloatNumber would write baudRate as
   // 9600.0 and change every config file on first save.
   TJSONNumberHelper = class helper for TJSONNumber
   public
      function AsInt: integer;
      class function Create(aValue: Int64): TJSONNumber; overload;
      class function Create(aValue: Double): TJSONNumber; overload;
   end;
{$ELSE}
   TJSONValue  = System.JSON.TJSONValue;
   TJSONObject = System.JSON.TJSONObject;
   TJSONArray  = System.JSON.TJSONArray;
   TJSONString = System.JSON.TJSONString;
   TJSONBool   = System.JSON.TJSONBool;
   TJSONNumber = System.JSON.TJSONNumber;
{$ENDIF}

function JSONText(aValue: TJSONValue): string;
function JSONPairName(aObj: TJSONObject; aIndex: integer): string;
function JSONPairValue(aObj: TJSONObject; aIndex: integer): TJSONValue;
function JSONGetStr(aObj: TJSONObject; const aName, aDefault: string): string;
function JSONGetInt(aObj: TJSONObject; const aName: string; aDefault: integer): integer;

implementation

uses
   SysUtils;

{$IFDEF FPC}

function TJSONObjectHelper.AddPair(const aName: string; const aValue: string): TJSONObject;
begin
   Add(aName, aValue);
   // Delphi's AddPair returns the object so calls can chain.
   Result := Self;
end;

function TJSONObjectHelper.AddPair(const aName: string; aValue: TJSONData): TJSONObject;
begin
   Add(aName, aValue);
   Result := Self;
end;

function TJSONObjectHelper.GetValue(const aName: string): TJSONData;
begin
   // Find returns nil for an absent name, which is what GetValue does.
   Result := Find(aName);
end;

function TJSONObjectHelper.FindValue(const aName: string): TJSONData;
begin
   // Delphi's FindValue walks a JSON PATH ('a.b'); every TR4W caller passes a
   // plain key, so Find is the faithful mapping.  If a dotted path is ever
   // introduced this will quietly return nil -- hence the note.
   Result := Find(aName);
end;

procedure TJSONArrayHelper.AddElement(aValue: TJSONData);
begin
   Add(aValue);
end;

function TJSONArrayHelper.ToJSON: string;
begin
   Result := AsJSON;
end;

function TJSONObjectHelper.ToJSON: string;
begin
   Result := AsJSON;
end;

function TJSONNumberHelper.AsInt: integer;
begin
   // AsInteger truncates a float the same way Delphi's AsInt does.
   Result := AsInteger;
end;

class function TJSONNumberHelper.Create(aValue: Int64): TJSONNumber;
begin
   Result := TJSONInt64Number.Create(aValue);
end;

class function TJSONNumberHelper.Create(aValue: Double): TJSONNumber;
begin
   Result := TJSONFloatNumber.Create(aValue);
end;

function TJSONObjectHelper.Format(aIndent: integer): string;
begin
   // fpjson's FormatJSON has its own indent options; the callers only ever ask
   // for "pretty", so the indent argument is honoured in spirit, not in width.
   Result := FormatJSON();
end;

class function TJSONObjectHelper.ParseJSONValue(const aText: string): TJSONData;
begin
   // Delphi returns nil for malformed input; fpjson raises.  Callers test for
   // nil, so raising here would turn a handled bad-config path into a crash.
   try
      Result := GetJSON(aText);
   except
      on E: Exception do
         begin
         Result := nil;
         end;
   end;
end;

{$ENDIF}

function JSONText(aValue: TJSONValue): string;
begin
   if aValue = nil then
      begin
      Result := '';
      Exit;
      end;

{$IFDEF FPC}
   // AsString, not Value: Value is a Variant and would convert implicitly.
   Result := aValue.AsString;
{$ELSE}
   Result := aValue.Value;
{$ENDIF}
end;

function JSONPairName(aObj: TJSONObject; aIndex: integer): string;
begin
{$IFDEF FPC}
   Result := aObj.Names[aIndex];
{$ELSE}
   Result := aObj.Pairs[aIndex].JsonString.Value;
{$ENDIF}
end;

function JSONPairValue(aObj: TJSONObject; aIndex: integer): TJSONValue;
begin
{$IFDEF FPC}
   Result := aObj.Items[aIndex];
{$ELSE}
   Result := aObj.Pairs[aIndex].JsonValue;
{$ENDIF}
end;

function JSONGetStr(aObj: TJSONObject; const aName, aDefault: string): string;
var
   v: TJSONValue;
begin
   Result := aDefault;
   if aObj = nil then
      begin
      Exit;
      end;

   v := aObj.GetValue(aName);
   if v <> nil then
      begin
      Result := JSONText(v);
      end;
end;

function JSONGetInt(aObj: TJSONObject; const aName: string; aDefault: integer): integer;
var
   v: TJSONValue;
begin
   Result := aDefault;
   if aObj = nil then
      begin
      Exit;
      end;

   v := aObj.GetValue(aName);
   if v <> nil then
      begin
      // Via the text form so a number written as a string still reads, which is
      // what Delphi's GetValue<integer> does for a quoted numeric.
      Result := StrToIntDef(JSONText(v), aDefault);
      end;
end;

end.

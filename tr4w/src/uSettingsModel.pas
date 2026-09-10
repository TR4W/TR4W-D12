(*
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
 *)
unit uSettingsModel;
{$I tr4w.inc}

(*
  TR4W'S SETTINGS, AS AN FPC APPLICATION WOULD WRITE THEM.

  ------------------------------------------------------------------------
  WHY THIS SHAPE
  ------------------------------------------------------------------------

  NY4I's standing rule is "what would we do if we were doing this from scratch
  in an FPC app", and he applied it to the settings work on 2026-09-10.  The
  answer is not a table of pointers, and it is not a registry of getter and
  setter method pointers either.  It is this:

      published property Port: integer read FPort write FPort;

  THE PROPERTY NAME IS THE KEY.  THE PROPERTY TYPE IS THE TYPE.  There is
  nothing else to declare, because the compiler already emits both as RTTI and
  fpjsonrtti already reads them.  Everything CFGCA carries per row --
  crAddress, crType, crKind, crMin, crMax -- is a restatement of something the
  compiler knows.

  A CLASS, NOT A RECORD, AND THAT IS LOAD-BEARING RATHER THAN STYLISTIC.
  Config in uConfigValues is a record for one reason: CFGCA stores the ADDRESS
  of each setting and writes through it, and @Config.Field works only because a
  record field's offset is known at link time.  A record has no published
  properties and no RTTI, so it cannot be streamed this way at all.  The array
  was forcing the very shape that blocks the native answer.

  ------------------------------------------------------------------------
  THREE RULES FOR ADDING TO THIS UNIT
  ------------------------------------------------------------------------

  1. GROUP IT.  One child object per area, not a flat list of five hundred
     names.  The JSON nests to match, so a section is readable by a human and
     an area can be reasoned about on its own.

  2. DEFAULTS BELONG IN Create, NOT IN A `default` DIRECTIVE.  The `default`
     specifier tells the STREAMER it may omit a value; it does not initialise
     anything.  A property left out of Create is zero or empty, which for a
     port number or an address is a silently wrong setting rather than an
     absent one.

  3. OLD SETTINGS ARE MIGRATED ONCE AND NEVER USED AGAIN (NY4I, 2026-09-10).
     A setting that moves here reads its legacy value exactly once, from the
     old `commands` section, and after that the legacy key is dead.  It is NOT
     a fallback consulted at every start -- that is the arrangement where two
     stores disagree and nobody can say which is in force.  See
     ImportLegacyCommands.

  ------------------------------------------------------------------------
  WHAT AN ABSENT KEY MEANS
  ------------------------------------------------------------------------

  Nothing.  Deliberately.  fpjsonrtti leaves a property alone when the JSON
  does not carry it, so a settings file written by an older build simply does
  not disturb a property that build had never heard of.  That is what makes
  adding a setting safe by construction rather than by a migration step, and it
  is verified in uTestSettingsModel rather than assumed.
*)

interface

uses
   Classes,
   SysUtils,
   uJSON;   // TJSONObject -- the same DOM every other store in the file uses

type
   (* THE EXTERNAL LOGGER -- the first area to move off CFGCA.

     It went first because it is the smallest COMPLETE case in the tree: three
     settings, no competing structured store, no contest .cfg writes them, no
     multi-op peer sync, and exactly two reading sites.  The UDP and WinKeyer
     groups look similar by reference count and are not: both already have a
     structured store of their own, so moving them is a merge of two models
     rather than a migration of one. *)
   TExternalLoggerSettings = class(TPersistent)
   private
      FAddress: string;
      FPort: integer;
      FEnabled: boolean;
   public
      constructor Create;
   published
      // Was ExternalLoggerAddress in logstuff.pas, a string[255].
      property Address: string read FAddress write FAddress;
      // Was ExternalLoggerPort.  DXKeeper listens on 52000 plus one.
      property Port: integer read FPort write FPort;
      // Was ExternalLoggerEnabled.
      property Enabled: boolean read FEnabled write FEnabled;
   end;

   TR4WSettings = class(TPersistent)
   private
      FExternalLogger: TExternalLoggerSettings;
   public
      constructor Create;
      destructor Destroy; override;

      (* The whole object as one JSON object, and back.  Same shape as every
        other store in settings\tr4w.json -- each serialises ITS OWN SECTION
        and knows nothing about the others.

        The caller owns the returned object. *)
      function ToJSON: TJSONObject;
      procedure FromJSON(const aObj: TJSONObject);

      (* SEED FROM THE OLD KEYS, ONCE.  aCommands is the legacy `commands`
        section: flat keys spelled the way a config command is spelled,
        'EXTERNAL LOGGER PORT'.  Only properties the caller has not already
        loaded should be seeded, which is why this takes the commands object
        and not the whole file -- see uSettingsMigrate for the policy. *)
      procedure ImportLegacyCommands(const aCommands: TJSONObject);
   published
      property ExternalLogger: TExternalLoggerSettings read FExternalLogger;
   end;

(* THE ONE INSTANCE.  Created on first use so no unit's initialisation order
  can reach it before it exists, freed by FreeSettings at shutdown.

  A singleton is what NY4I described -- "callers just access Registry.variable
  name" -- and it is the honest shape for a program whose settings ARE global.
  What it replaces is not a smaller thing: it replaces ~500 loose globals with
  one object whose members are typed, grouped and named. *)
function Settings: TR4WSettings;
procedure FreeSettings;

implementation

uses
   fpjson,
   fpjsonrtti;

var
   GSettings: TR4WSettings = nil;

function Settings: TR4WSettings;
begin
   if GSettings = nil then
      begin
      GSettings := TR4WSettings.Create;
      end;
   Result := GSettings;
end;

procedure FreeSettings;
begin
   FreeAndNil(GSettings);
end;

{ TExternalLoggerSettings }

constructor TExternalLoggerSettings.Create;
begin
   inherited Create;
   (* The values the typed constants in logstuff.pas carried.  See rule 2 in
     the header: these are set HERE, not with a `default` directive, because
     `default` only tells the streamer it may omit the value. *)
   FAddress := '127.0.0.1';
   FPort    := 52001;
   FEnabled := False;
end;

{ TR4WSettings }

constructor TR4WSettings.Create;
begin
   inherited Create;
   FExternalLogger := TExternalLoggerSettings.Create;
end;

destructor TR4WSettings.Destroy;
begin
   FExternalLogger.Free;
   inherited Destroy;
end;

function TR4WSettings.ToJSON: TJSONObject;
var
   streamer: TJSONStreamer;
begin
   streamer := TJSONStreamer.Create(nil);
   try
      (* jsoStreamChildren is what makes the nested objects appear at all --
        without it a child object property is skipped in silence, which reads
        as "that area has no settings" rather than as an error. *)
      streamer.Options := streamer.Options + [jsoStreamChildren];
      Result := streamer.ObjectToJSON(Self);
   finally
      streamer.Free;
   end;
end;

procedure TR4WSettings.FromJSON(const aObj: TJSONObject);
var
   destreamer: TJSONDeStreamer;
begin
   if aObj = nil then
      begin
      Exit;
      end;

   destreamer := TJSONDeStreamer.Create(nil);
   try
      (* A property the object does not carry is LEFT ALONE.  That is the
        whole of the forward-compatibility story -- see the unit header. *)
      destreamer.JSONToObject(aObj, Self);
   finally
      destreamer.Free;
   end;
end;

procedure TR4WSettings.ImportLegacyCommands(const aCommands: TJSONObject);

   (* The legacy section stores every value as TEXT, whatever its type, because
     it is a rendering of config-file lines.  '' is absent, not empty. *)
   function Text(const aKey: string; const aDefault: string): string;
   var
      v: TJSONData;
   begin
      Result := aDefault;
      if aCommands = nil then
         begin
         Exit;
         end;
      (* EXPLICIT AT THE DOM BOUNDARY.  fpjson is built with UTF8String and
        this unit is UnicodeString, so both directions convert; written down
        rather than left to the compiler, which is the rule the build counts.
        A config command key is ASCII, so there is nothing to lose. *)
      v := aCommands.FindPath(UTF8String(aKey));
      if v = nil then
         begin
         Exit;
         end;
      Result := string(v.AsString);
   end;

   function Num(const aKey: string; const aDefault: integer): integer;
   begin
      // StrToIntDef is an AnsiString routine; the text is a decimal number.
      Result := StrToIntDef(AnsiString(Trim(Text(aKey, ''))), aDefault);
   end;

   function Flag(const aKey: string; const aDefault: boolean): boolean;
   var
      s: string;
   begin
      Result := aDefault;
      s := UpperCase(Trim(Text(aKey, '')));
      if s = '' then
         begin
         Exit;
         end;

      (* EXACTLY WHAT CheckCommand ACCEPTED, AND NOTHING MORE.  Its ctBoolean
        arm is one test -- `if not (CustomCMD[1] in ['T','F']) then Exit` --
        so a leading T or F decided it and EVERY OTHER WORD WAS REJECTED, the
        setting left untouched.  'ON', 'YES' and '1' were never accepted.

        A first draft of this accepted all three, which reads as generosity and
        is not: this import runs ONCE per installation and gets no second
        chance to ask, so inventing an acceptance the old parser never had
        would turn a value TR4W had always ignored into one that now changes a
        station's configuration.  uTestSettingsModel is what caught it.

        Case-folded, though, which IS safe: the value being read was written by
        CFGCommandValueAsString from BA, so it is 'TRUE' or 'FALSE' already,
        and folding cannot accept anything a case-sensitive test would refuse
        except the same two words differently typed. *)
      if s[1] = 'T' then
         begin
         Result := True;
         end
      else if s[1] = 'F' then
         begin
         Result := False;
         end;
   end;

begin
   if aCommands = nil then
      begin
      Exit;
      end;

   ExternalLogger.Address := Text('EXTERNAL LOGGER ADDRESS', ExternalLogger.Address);
   ExternalLogger.Port    := Num('EXTERNAL LOGGER PORT',     ExternalLogger.Port);
   ExternalLogger.Enabled := Flag('EXTERNAL LOGGER ENABLED', ExternalLogger.Enabled);
end;

(* FREED WITH THE UNIT, not left to a caller.  A settings object outlives every
  consumer by definition, so there is no natural owner to hand it to, and a leak
  report at exit is noise that a real leak then has to be found inside. *)
finalization
   FreeSettings;

end.

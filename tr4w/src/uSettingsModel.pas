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
      // command name -> property path, built once by walking the RTTI.
      FCommands: TStringList;
      FExternalLogger: TExternalLoggerSettings;
      procedure BuildCommandMap;
      function PathForCommand(const aCommand: string): string;
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
        'EXTERNAL LOGGER PORT'.

        It walks THIS OBJECT rather than a list of settings to look for, so a
        property added later is imported with no edit here. *)
      procedure ImportLegacyCommands(const aCommands: TJSONObject);

      (* ---------------------------------------------------------------
        ANSWERING TO A CONFIG COMMAND NAME.

        Three callers need it and all three are why CFGCA still exists:

          * the one-time import above;
          * MULTI-OP PEER SYNC.  A change made at one position travels as
            COMMAND TEXT plus a value, and the receiving position applies it
            by name.  A setting that moved here and could not be reached by
            name would leave the other position silently stale, which is the
            failure mode uNet already had for seventeen rows;
          * the contest .cfg, which is a live input format and is not going
            away with the ini.

        THE NAME IS DERIVED FROM THE PROPERTY PATH, not declared in a table.
        'ExternalLogger.Port' gives 'EXTERNAL LOGGER PORT' -- a space at each
        word boundary, upper-cased.  That is the whole mapping for every
        setting migrated so far, so adding one costs no line anywhere, and a
        table that has to be edited from far away is the thing that drifts.

        Where a legacy name genuinely does not derive, BuildCommandMap carries
        an explicit exception.  Keep that list short: a long one means the
        derivation rule is wrong. *)
      function OwnsCommand(const aCommand: string): boolean;
      function TrySetByCommand(const aCommand, aValue: string): boolean;
      function TryGetByCommand(const aCommand: string; out aValue: string): boolean;

      // Every command name this object answers to. Caller owns the result.
      function CommandNames: TStringList;
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
   fpjsonrtti,
   TypInfo;   // the property walk -- see the note on OwnsCommand

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

   FCommands := TStringList.Create;
   FCommands.CaseSensitive := False;
   FCommands.Sorted := True;
   FCommands.Duplicates := dupError;   // two properties claiming one command name
   BuildCommandMap;
end;

destructor TR4WSettings.Destroy;
begin
   FCommands.Free;
   FExternalLogger.Free;
   inherited Destroy;
end;

(* 'ExternalLogger.Port' -> 'EXTERNAL LOGGER PORT'.

  A space at each word boundary -- a capital that follows a lower-case letter
  or a digit, and every dot between groups -- then upper-cased.  A RUN of
  capitals is one word, so a property named UDPPort gives 'UDPPORT' rather
  than 'U D P PORT'; where that is not the legacy spelling, the exception
  belongs in BuildCommandMap. *)
function CommandNameOf(const aPath: string): string;
var
   i: integer;
   c: char;
   prev: char;
begin
   Result := '';
   for i := 1 to Length(aPath) do
      begin
      c := aPath[i];
      if c = '.' then
         begin
         if (Result <> '') and (Result[Length(Result)] <> ' ') then
            begin
            Result := Result + ' ';
            end;
         Continue;
         end;

      if i > 1 then
         begin
         prev := aPath[i - 1];
         if (c >= 'A') and (c <= 'Z') and
            (not ((prev >= 'A') and (prev <= 'Z'))) and
            (Result <> '') and (Result[Length(Result)] <> ' ') then
            begin
            Result := Result + ' ';
            end;
         end;

      Result := Result + c;
      end;
   Result := UpperCase(Result);
end;

(* EXPLICIT AT THE RTTI BOUNDARY, EVERY CROSSING.

  TypInfo and TStringList are compiled with String = AnsiString and this unit
  is UnicodeString, so every name and value that crosses converts.  The build
  counts implicit ones and it is right to: a silent narrowing is how a
  non-ASCII value loses characters.

  NOTHING HERE CAN LOSE ANYTHING.  A Pascal property identifier is ASCII by the
  language's own rules, and a config command name is ASCII by TR4W's.  The one
  crossing that carries operator text -- a string property's VALUE, in
  SetStrProp and GetStrProp -- is the reason this is written down rather than
  waved away: if a setting ever holds a call sign or a name outside the ANSI
  code page, this is the line that would drop it, and it should be found by
  reading rather than by a bug report. *)

(* The object that owns the leaf named by a dotted path, and the leaf itself.
  False for a path that does not resolve, which is what makes an unknown
  command a refusal rather than a silent no-op somewhere later. *)
function ResolvePath(const aRoot: TObject; const aPath: string;
                     out aOwner: TObject; out aInfo: PPropInfo): boolean;
var
   rest, head: string;
   dot: integer;
begin
   Result := False;
   aOwner := aRoot;
   aInfo  := nil;
   rest   := aPath;

   while rest <> '' do
      begin
      dot := Pos('.', rest);
      if dot = 0 then
         begin
         aInfo  := GetPropInfo(aOwner, AnsiString(rest));
         Result := aInfo <> nil;
         Exit;
         end;

      head := Copy(rest, 1, dot - 1);
      rest := Copy(rest, dot + 1, MaxInt);
      aInfo := GetPropInfo(aOwner, AnsiString(head));
      if (aInfo = nil) or (aInfo^.PropType^.Kind <> tkClass) then
         begin
         Exit;
         end;
      aOwner := GetObjectProp(aOwner, aInfo);
      if aOwner = nil then
         begin
         Exit;
         end;
      end;
end;

procedure TR4WSettings.BuildCommandMap;

   procedure Walk(const aObj: TObject; const aPrefix: string);
   var
      props: PPropList;
      count: integer;
      i: integer;
      info: PPropInfo;
      child: TObject;
      path: string;
   begin
      count := GetPropList(aObj.ClassInfo, props);
      if count = 0 then
         begin
         Exit;
         end;
      try
         for i := 0 to count - 1 do
            begin
            info := props^[i];
            path := aPrefix + string(info^.Name);

            if info^.PropType^.Kind = tkClass then
               begin
               child := GetObjectProp(aObj, info);
               if child <> nil then
                  begin
                  Walk(child, path + '.');
                  end;
               end
            else
               begin
               // dupError on the list turns two properties claiming one legacy
               // name into a startup failure rather than a silent shadowing.
               FCommands.Values[AnsiString(CommandNameOf(path))] := AnsiString(path);
               end;
            end;
      finally
         FreeMem(props);
      end;
   end;

begin
   FCommands.Clear;
   Walk(Self, '');

   (* THE EXCEPTIONS, where a legacy command name does not derive from the
     property path.  There are none yet: every setting migrated so far derives
     exactly.  Keep this short -- a long list means the rule above is wrong,
     not that the settings are irregular. *)
end;

function TR4WSettings.PathForCommand(const aCommand: string): string;
begin
   Result := string(FCommands.Values[AnsiString(Trim(aCommand))]);
end;

function TR4WSettings.OwnsCommand(const aCommand: string): boolean;
begin
   Result := PathForCommand(aCommand) <> '';
end;

function TR4WSettings.CommandNames: TStringList;
var
   i: integer;
begin
   Result := TStringList.Create;
   for i := 0 to FCommands.Count - 1 do
      begin
      Result.Add(FCommands.Names[i]);
      end;
end;

function TR4WSettings.TrySetByCommand(const aCommand, aValue: string): boolean;
var
   path: string;
   owner: TObject;
   info: PPropInfo;
   n: integer;
   code: integer;
   text: string;
begin
   Result := False;
   path := PathForCommand(aCommand);
   if path = '' then
      begin
      Exit;
      end;
   if not ResolvePath(Self, path, owner, info) then
      begin
      Exit;
      end;

   text := Trim(aValue);

   (* A VALUE THIS CANNOT READ LEAVES THE PROPERTY ALONE, on every arm.  That
     is the rule the old parser had -- CheckCommand exits without assigning --
     and it matters more here than it did there, because the one-time import
     gets no second chance to ask. *)
   case info^.PropType^.Kind of
      tkInteger:
         begin
         Val(text, n, code);
         if code <> 0 then
            begin
            Exit;
            end;
         SetOrdProp(owner, info, n);
         Result := True;
         end;

      tkBool:
         begin
         (* EXACTLY WHAT CheckCommand ACCEPTED. Its ctBoolean arm is
           `if not (CustomCMD[1] in ['T','F']) then Exit`, so a leading T or F
           decided it and every other word -- 'ON', 'YES', '1' -- was refused.
           Case is folded, which is safe: the value was written as TRUE or
           FALSE by CFGCommandValueAsString. *)
         if text = '' then
            begin
            Exit;
            end;
         if UpCase(text[1]) = 'T' then
            begin
            SetOrdProp(owner, info, 1);
            end
         else if UpCase(text[1]) = 'F' then
            begin
            SetOrdProp(owner, info, 0);
            end
         else
            begin
            Exit;
            end;
         Result := True;
         end;

      tkEnumeration:
         begin
         n := GetEnumValue(info^.PropType, AnsiString(text));
         if n < 0 then
            begin
            Exit;
            end;
         SetOrdProp(owner, info, n);
         Result := True;
         end;

      tkString, tkLString, tkAString, tkUString, tkWString:
         begin
         SetStrProp(owner, info, AnsiString(aValue));
         Result := True;
         end;
   end;
end;

function TR4WSettings.TryGetByCommand(const aCommand: string;
                                      out aValue: string): boolean;
var
   path: string;
   owner: TObject;
   info: PPropInfo;
begin
   Result := False;
   aValue := '';
   path := PathForCommand(aCommand);
   if path = '' then
      begin
      Exit;
      end;
   if not ResolvePath(Self, path, owner, info) then
      begin
      Exit;
      end;

   case info^.PropType^.Kind of
      tkInteger:
         begin
         aValue := string(IntToStr(GetOrdProp(owner, info)));
         Result := True;
         end;
      tkBool:
         begin
         // The spelling BA uses, so a rendered value is one CheckCommand and
         // a peer both still read.
         if GetOrdProp(owner, info) <> 0 then
            begin
            aValue := 'TRUE';
            end
         else
            begin
            aValue := 'FALSE';
            end;
         Result := True;
         end;
      tkEnumeration:
         begin
         aValue := string(GetEnumName(info^.PropType, GetOrdProp(owner, info)));
         Result := True;
         end;
      tkString, tkLString, tkAString, tkUString, tkWString:
         begin
         aValue := string(GetStrProp(owner, info));
         Result := True;
         end;
   end;
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
var
   names: TStringList;
   i: integer;
   key: string;
   value: TJSONValue;
begin
   if aCommands = nil then
      begin
      Exit;
      end;

   (* WALKS THIS OBJECT, NOT A LIST OF SETTINGS TO LOOK FOR.  A property added
     later is imported with no edit here, which is the whole reason the command
     name is derived rather than declared.

     THE LEGACY SECTION STORES EVERY VALUE AS TEXT whatever its type, because it
     is a rendering of config-file lines -- so TrySetByCommand's parsing is
     exactly what is wanted, including its refusals.

     A KEY THAT IS ABSENT, OR A VALUE THAT WILL NOT PARSE, LEAVES THE PROPERTY
     AT ITS DEFAULT.  Not an error: a station that never set a value has no key
     for it, and this import gets no second chance to ask about one it cannot
     read. *)
   names := CommandNames;
   try
      for i := 0 to names.Count - 1 do
         begin
         key := names[i];
         value := aCommands.FindPath(UTF8String(key));
         if value = nil then
            begin
            Continue;
            end;
         TrySetByCommand(key, string(value.AsString));
         end;
   finally
      names.Free;
   end;
end;

(* FREED WITH THE UNIT, not left to a caller.  A settings object outlives every
  consumer by definition, so there is no natural owner to hand it to, and a leak
  report at exit is noise that a real leak then has to be found inside. *)
finalization
   FreeSettings;

end.

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
   (*
     A SETTING CHANGED, AND SOMETHING HAS TO REDRAW.

     THIS IS WHAT crP WAS.  Thirty CFGCA rows carry a `crP` index into
     CommandsProcArray, and uCFG's own note says the handler is "the ONLY thing
     that repaints for a changed setting".  A setting cannot leave the array
     until its side effect has somewhere else to live, and this is that
     somewhere.

     A PATH, NOT AN INDEX INTO A TABLE, which is the whole improvement: crP:1
     means @DisplayBandMap only if you go and read the array, and a row pointing
     at the wrong index is exactly the defect EXTERNAL LOGGER ENABLED had --
     crA:23 firing the WSJT-X hook.  'BandMap.AllBands' cannot point at the
     wrong thing.

     THE MODEL RAISES IT AND KNOWS NOTHING ABOUT WHO LISTENS.  uSettingsModel
     must not name a form or a window: the band map subscribes, the model does
     not reach for it.  That is the same layering Lint-DomainPurity enforces one
     directory down.
   *)
   TSettingChanged = procedure (const aPath: string);

   TR4WSettings = class;

   (*
     A BOUNDED INTEGER SETTING DECLARES ITS BOUNDS AS ITS TYPE.

     CFGCA carried crMin and crMax per row, and CheckCommand refused anything
     outside them.  Those two fields have to go somewhere when the row does,
     and the native FPC answer is not a table and not a validate() method: it
     is a SUBRANGE TYPE.  The compiler emits MinValue and MaxValue into the
     property's RTTI, which is the same RTTI the streamer and the command
     lookup already read -- so TrySetByCommand enforces the range without
     being told about any particular setting, exactly as it types them without
     being told.

     This is the unit header's thesis applied to one more field: the property
     name is the key, the property TYPE is the type -- and the range is part
     of the type.

     WHAT IT DOES NOT DO.  Range checking is off in this build, so a direct
     Pascal assignment of an out-of-range value still compiles and stores.
     The guard is at the boundary where untrusted values arrive -- a config
     file, an import, a peer -- which is where crMin and crMax guarded too.
   *)
   TBandMapDisplayLimit = 30..1000;
   TBandMapItemHeight   = 12..50;
   TBandMapItemWidth    = 100..200;
   TBandMapSize         = 0..8;
   TPttTurnOnDelay      = 0..65535;   // was crMin:0, crMax:MAXWORD

   (*
     THE BASE OF EVERY SETTINGS GROUP.

     It exists for ONE reason: so that a property setter can perform the side
     effect the change requires.  NY4I, 2026-09-11: "a property setter can do
     the side effect, which is better than a hook index."

     WHY IT IS BETTER, CONCRETELY.  crP: 1 is an index into CommandsProcArray,
     and three things about it are wrong that a setter fixes for free:

       * THE INDEX IS TYPED BY HAND AND NOTHING CHECKS IT.  A row pointing at
         the wrong slot is a legal integer.  That defect has already happened
         here -- EXTERNAL LOGGER ENABLED carried crA: 23, which fires the
         WSJT-X colorization hook.
       * IT ONLY FIRES THROUGH THE ARRAY.  CheckCommand runs the handler;
         ordinary Pascal assigning the global does not.  So the SAME setting
         repaints when a config file sets it and silently does not when a menu
         toggles it -- which is why the band map window had to write its own
         repaint call by hand, in ToggleAndRepaint.
       * IT IS REACHABLE ONLY BY LOOKING SOMEWHERE ELSE.  Reading the row tells
         you a number.

     A setter has none of those properties.  It cannot point at the wrong
     handler, it runs however the value was set, and it is written beside the
     field it guards.

     THE GROUP DOES NOT KNOW ITS OWN NAME, AND MUST NOT.  FPath is assigned by
     the owner's RTTI walk from the PUBLISHED PROPERTY NAME that reaches this
     object, so 'BandMap' is written exactly once -- as the property -- and a
     rename cannot leave a stale string behind.  A prefix passed to a
     constructor would be that second declaration.
   *)
   TSettingsGroup = class(TPersistent)
   private
      FOwner: TR4WSettings;
      FPath: string;
   protected
      (* Tell the owner that one of this group's properties has taken a new
        value.  aProperty is the bare property name; the group supplies its own
        path. *)
      procedure Changed(const aProperty: string);

      (* Assign and notify, but ONLY IF THE VALUE ACTUALLY CHANGED.

        Setting a property to what it already holds is not a change, and
        repainting for it is not merely wasted work: every JSON load and every
        multi-op sync writes every property it carries, so a setter that
        notified unconditionally would repaint the band map eight times at
        startup. *)
      procedure SetBool(var aField: boolean; aValue: boolean; const aProperty: string);
   public
      // Called by the owner's walk. Not for anyone else.
      procedure BindTo(aOwner: TR4WSettings; const aPath: string);
   end;

   (* THE EXTERNAL LOGGER -- the first area to move off CFGCA.

     It went first because it is the smallest COMPLETE case in the tree: three
     settings, no competing structured store, no contest .cfg writes them, no
     multi-op peer sync, and exactly two reading sites.  The UDP and WinKeyer
     groups look similar by reference count and are not: both already have a
     structured store of their own, so moving them is a merge of two models
     rather than a migration of one. *)
   TExternalLoggerSettings = class(TSettingsGroup)
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

   (* THE DXLAB SPOT COLLECTOR BRIDGE.  One setting; the group exists because
     the property PATH is what derives the legacy command name, so
     SpotCollector.Enabled is what gives 'SPOT COLLECTOR ENABLED'. *)
   TSpotCollectorSettings = class(TSettingsGroup)
   private
      FEnabled: boolean;
   published
      property Enabled: boolean read FEnabled write FEnabled;
   end;

   (* THE TCP SERVER TR4W RUNS FOR RADIO CLIENTS -- not a radio's own port.
     Radio.TcpServerPort derives 'RADIO TCP SERVER PORT', which is the command
     an existing config file uses. *)
   TRadioServerSettings = class(TSettingsGroup)
   private
      FTcpServerPort: integer;
   public
      constructor Create;
   published
      property TcpServerPort: integer read FTcpServerPort write FTcpServerPort;
   end;

   (* THE YCCC SO2R+ BOX.  Yccc.So2rEnable derives 'YCCC SO2R ENABLE'. *)
   TYcccSettings = class(TSettingsGroup)
   private
      FSo2rEnable: boolean;
   published
      property So2rEnable: boolean read FSo2rEnable write FSo2rEnable;
   end;

   (* THE MMTTY RTTY ENGINE.

     A STRING, WHERE THE GLOBAL WAS A FileNameType -- a fixed AnsiChar array.
     That is the point of moving it rather than a side effect: its two readers
     were `TR4W_MMTTYPATH[0] = #0` and `string(PAnsiChar(TR4W_MMTTYPATH))`,
     which is exactly the Win32 string handling CLAUDE.md says the program is
     getting rid of.  Both are now an ordinary comparison and an ordinary
     assignment, and two PChars leave the tree with them. *)
   TMmttySettings = class(TSettingsGroup)
   private
      FEngine: string;
   published
      property Engine: string read FEngine write FEngine;
   end;

   (*
     THE BAND MAP'S DISPLAY FILTERS -- eight booleans that decide what the band
     map shows, and the first group in this unit whose settings have a SIDE
     EFFECT.

     ALL EIGHT CARRIED crP: 1 IN CFGCA, which is @DisplayBandMap: changing any
     of them has to redraw the window or the operator sees the old contents
     until something else happens to repaint it.  That is what the setters do,
     and it is why this group went next -- the groups migrated before it are all
     inert values, so none of them could prove the mechanism.

     THE SETTER REPLACES TWO SEPARATE MECHANISMS, not one.  A config file went
     through CheckCommand and got the crP handler; the band map's own menu
     toggles went through ToggleAndRepaint, a helper that took the global by
     var and called RequestRepaint itself.  Both spellings of "and now redraw"
     collapse into the property.
   *)
   TBandMapSettings = class(TSettingsGroup)
   private
      FAllBands: boolean;
      FAllModes: boolean;
      FCallWindowEnable: boolean;
      FDisplayCQ: boolean;
      FDisplayGhz: boolean;
      FDupeDisplay: boolean;
      FMultsOnly: boolean;
      FSo2rDisplay: boolean;
      FDisplayLimit: TBandMapDisplayLimit;
      FItemHeight: TBandMapItemHeight;
      FItemWidth: TBandMapItemWidth;
      FSize: TBandMapSize;
      procedure SetAllBands(aValue: boolean);
      procedure SetAllModes(aValue: boolean);
      procedure SetCallWindowEnable(aValue: boolean);
      procedure SetDisplayCQ(aValue: boolean);
      procedure SetDisplayGhz(aValue: boolean);
      procedure SetDupeDisplay(aValue: boolean);
      procedure SetMultsOnly(aValue: boolean);
      procedure SetSo2rDisplay(aValue: boolean);
      procedure SetDisplayLimit(aValue: TBandMapDisplayLimit);
   public
      constructor Create;
   published
      // Was BandMapAllBands in logwind.pas.  Show spots from every band.
      property AllBands: boolean read FAllBands write SetAllBands;
      // Was BandMapAllModes.
      property AllModes: boolean read FAllModes write SetAllModes;
      (* Was BandMapCallWindowEnable in logstuff.pas -- the one of the eight
        that did NOT live in logwind.pas, and one of the three whose default
        is True. *)
      property CallWindowEnable: boolean read FCallWindowEnable write SetCallWindowEnable;
      // Was BandMapDisplayCQ.
      property DisplayCQ: boolean read FDisplayCQ write SetDisplayCQ;
      (* Was BandMapDisplayGhz in uBandmap.pas.  Renders above 1 GHz in GHz
        rather than MHz (N4AF, 4.42.8). *)
      property DisplayGhz: boolean read FDisplayGhz write SetDisplayGhz;
      // Was BandMapDupeDisplay.
      property DupeDisplay: boolean read FDupeDisplay write SetDupeDisplay;
      // Was BandMapMultsOnly.
      property MultsOnly: boolean read FMultsOnly write SetMultsOnly;
      // Was BandMapSO2RDisplay.
      property So2rDisplay: boolean read FSo2rDisplay write SetSo2rDisplay;

      (* How many spots the map will show.  Was BandMapDisplayLimit, and it
        carried crP: 1 -- so it redraws, and its setter says so. *)
      property DisplayLimit: TBandMapDisplayLimit read FDisplayLimit write SetDisplayLimit;

      (* THE THREE BELOW CARRIED crP: 0 AND crJ: 1 -- no redraw, restart
        required -- so they are plain field writes with no notification.

        That asymmetry is REAL rather than an oversight like HF BAND ENABLE's:
        the grid's geometry is computed once in LayOutGrid, and a repaint
        would not re-run it.  Making them take effect live is a UI change, not
        a settings change, and it is not one to make blind. *)
      // Was BandMapItemHeight in uBandmap.pas.
      property ItemHeight: TBandMapItemHeight read FItemHeight write FItemHeight;
      // Was BandMapItemWidth in uBandmap.pas.
      property ItemWidth: TBandMapItemWidth read FItemWidth write FItemWidth;
      // Was BandMapSize in VC.pas.
      property Size: TBandMapSize read FSize write FSize;
   end;

   (*
     WHICH CLASSES OF BAND ARE IN PLAY -- HF, the WARC bands (30/17/12m), and
     VHF and up.

     THESE THREE ARE NOT A DISPLAY FILTER, and the difference is the reason
     they are their own group rather than more properties on TBandMapSettings.
     Two of the three carry crP: 1 in CFGCA, the band map redraw, which makes
     them look like band map settings from the array.  They are not: they also
     REFUSE A BAND CHANGE (logstuff.pas, at four sites) and decide which band
     columns the main window shows.  Grouping them by their redraw hook would
     have filed a rule of the contest under a display filter.

     That is the argument for a setter over a hook index, stated against a real
     row: the index says only "redraw the band map", so it cannot tell you the
     setting also refuses a band change, and it therefore invites exactly that
     mis-grouping.

     THE CONTEST WRITES THEM.  FCONTEST assigns all three when a contest is
     selected.  An earlier draft of the migration plan held them back for that
     reason, as "contest properties wearing a settings costume"; that line was
     withdrawn (NY4I, 2026-08-16) -- every parameter belongs in the registry,
     and WHO WRITES a value is a separate question from WHERE IT LIVES.

     THE GLOBALS THEY REPLACE WERE SPELLED INCONSISTENTLY -- HFBandEnable but
     VHFBandsEnabled and WARCBandsEnabled, singular Band against plural Bands.
     uSettingsDeclarations already carried a note that this makes a naive grep
     under-report them.  Three properties on one object cannot drift that way.
   *)
   TBandSettings = class(TSettingsGroup)
   private
      FHfEnabled: boolean;
      FVhfEnabled: boolean;
      FWarcEnabled: boolean;
      procedure SetHfEnabled(aValue: boolean);
      procedure SetVhfEnabled(aValue: boolean);
      procedure SetWarcEnabled(aValue: boolean);
   public
      constructor Create;
   published
      // Was HFBandEnable in logdupe.pas.
      property HfEnabled: boolean read FHfEnabled write SetHfEnabled;
      // Was VHFBandsEnabled in logwind.pas.
      property VhfEnabled: boolean read FVhfEnabled write SetVhfEnabled;
      // Was WARCBandsEnabled in logwind.pas.
      property WarcEnabled: boolean read FWarcEnabled write SetWarcEnabled;
   end;

   (*
     PUSH TO TALK.

     THE FIRST GROUP TO COME OFF THE `Config` RECORD, and that record's own
     header asked for it: "leaves exactly one place to change when the applier
     stops being CheckCommand.  That last step is what finally removes the
     address-taking, and it cannot happen until the rows have moved."  This is
     that step, for five of its seventy-one rows.

     WHY Config HAD TO BE A RECORD, and why it no longer does.  CFGCA is a
     const array holding the ADDRESS of each setting, so the storage had to be
     statically addressable -- `@Config.PTTEnable` resolves at link time and
     `@SomeObject.Property` cannot.  The record was never the design; it was
     the shape the array forced.  A published property needs no address at
     all.

     NO HOOKS ON ANY OF THE FIVE -- crP, crA, crJ and crC are all zero -- so
     these are plain field writes.  A setter that notified would be inventing
     a side effect none of them ever had.
   *)
   TPttSettings = class(TSettingsGroup)
   private
      FEnable: boolean;
      FLockout: boolean;
      FViaCommands: boolean;
      FNoPollDuring: boolean;
      FTurnOnDelay: TPttTurnOnDelay;
   public
      constructor Create;
   published
      // Was Config.PTTEnable.
      property Enable: boolean read FEnable write FEnable;
      // Was Config.PTTLockout.
      property Lockout: boolean read FLockout write FLockout;
      (* Was Config.PTTViaCommand -- SINGULAR in the record, while the config
        command has always been PTT VIA COMMANDS.  The property takes the
        command's spelling, which is the one an operator has typed and the one
        another station sends. *)
      property ViaCommands: boolean read FViaCommands write FViaCommands;
      (* Was Config.NoPollDuringPTT.  The only one of the five whose legacy
        name does not derive -- it reads NO POLL DURING PTT, putting the group
        last -- so it carries an alias.  See BuildCommandMap. *)
      property NoPollDuring: boolean read FNoPollDuring write FNoPollDuring;
      // Was Config.PTTTurnOnDelay, in milliseconds.
      property TurnOnDelay: TPttTurnOnDelay read FTurnOnDelay write FTurnOnDelay;
   end;

   TR4WSettings = class(TPersistent)
   private
      // command name -> property path, built once by walking the RTTI.
      FCommands: TStringList;
      FOnChanged: TSettingChanged;
      FExternalLogger: TExternalLoggerSettings;
      FSpotCollector: TSpotCollectorSettings;
      FRadio: TRadioServerSettings;
      FYccc: TYcccSettings;
      FMmtty: TMmttySettings;
      FBandMap: TBandMapSettings;
      FBands: TBandSettings;
      FPtt: TPttSettings;
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

      (* Force every bounded integer property back inside its own subrange.

        WHY IT IS NEEDED AT ALL.  TrySetByCommand refuses an out-of-range
        value, so the config, import and peer paths are all guarded.  The
        STREAMER is not: fpjsonrtti writes whatever ordinal the file carries,
        so a hand-edited settings\tr4w.json can put 0 into a 12..50 property
        and every reader downstream believes the type.  One of them divides by
        it.

        CLAMPED HERE, NOT REFUSED, and that is the opposite of the rule one
        layer up -- deliberately.  A config LINE is something the operator
        just typed, so refusing it and saying so is useful.  A stored file is
        the program's own state arriving at startup: refusing leaves the
        property at a default that is no closer to their intent, and there is
        nobody at the keyboard to tell. *)
      procedure ClampToDeclaredRanges;

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

      (* Raised AFTER a property has taken its new value, naming the property
        path.  A group's setter calls this; nothing else should.

        ONE HANDLER, not a list: there is one main window, the handler
        dispatches on the path, and a subscriber list would be machinery for a
        problem this program does not have. *)
      procedure Changed(const aPath: string);
      property OnChanged: TSettingChanged read FOnChanged write FOnChanged;
   published
      property ExternalLogger: TExternalLoggerSettings read FExternalLogger;
      property SpotCollector: TSpotCollectorSettings read FSpotCollector;
      property Radio: TRadioServerSettings read FRadio;
      property Yccc: TYcccSettings read FYccc;
      property Mmtty: TMmttySettings read FMmtty;
      property BandMap: TBandMapSettings read FBandMap;
      property Bands: TBandSettings read FBands;
      property Ptt: TPttSettings read FPtt;
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

{ TSettingsGroup }

procedure TSettingsGroup.BindTo(aOwner: TR4WSettings; const aPath: string);
begin
   FOwner := aOwner;
   FPath  := aPath;
end;

procedure TSettingsGroup.Changed(const aProperty: string);
begin
   (* FOwner is nil only before the owner's walk has reached this group, which
     is during TR4WSettings.Create.  A default assigned in a group's own
     constructor is not a change anyone can have asked to see. *)
   if FOwner <> nil then
      begin
      FOwner.Changed(FPath + '.' + aProperty);
      end;
end;

procedure TSettingsGroup.SetBool(var aField: boolean; aValue: boolean;
                                 const aProperty: string);
begin
   if aField = aValue then
      begin
      Exit;
      end;
   aField := aValue;
   Changed(aProperty);
end;

{ TBandMapSettings }

constructor TBandMapSettings.Create;
begin
   inherited Create;
   (* The values the globals carried.  Three of the eight default True and
     five default False, and that asymmetry is real: logstuff.pas and
     logwind.pas initialised them individually. *)
   FAllBands         := False;
   FAllModes         := False;
   FCallWindowEnable := True;
   FDisplayCQ        := True;
   FDisplayGhz       := False;
   FDupeDisplay      := True;
   FMultsOnly        := False;
   FSo2rDisplay      := False;
   (* The values the globals carried: logwind.pas 164 (GAV, for the centred
     band map), uBandmap.pas 14 and 135, VC.pas 3.  Every one is inside its
     own subrange, which the compiler would not check but a reader should. *)
   FDisplayLimit     := 164;
   FItemHeight       := 14;
   FItemWidth        := 135;
   FSize             := 3;
end;

(* EIGHT SETTERS THAT DIFFER ONLY IN WHICH FIELD THEY GUARD.

  They are written out rather than generated because the alternative in Pascal
  is an index-keyed setter -- SetFlag(BM_ALL_BANDS, aValue) -- and that is the
  hook index again, one indirection further down. *)
procedure TBandMapSettings.SetAllBands(aValue: boolean);
begin
   SetBool(FAllBands, aValue, 'AllBands');
end;

procedure TBandMapSettings.SetAllModes(aValue: boolean);
begin
   SetBool(FAllModes, aValue, 'AllModes');
end;

procedure TBandMapSettings.SetCallWindowEnable(aValue: boolean);
begin
   SetBool(FCallWindowEnable, aValue, 'CallWindowEnable');
end;

procedure TBandMapSettings.SetDisplayCQ(aValue: boolean);
begin
   SetBool(FDisplayCQ, aValue, 'DisplayCQ');
end;

procedure TBandMapSettings.SetDisplayGhz(aValue: boolean);
begin
   SetBool(FDisplayGhz, aValue, 'DisplayGhz');
end;

procedure TBandMapSettings.SetDupeDisplay(aValue: boolean);
begin
   SetBool(FDupeDisplay, aValue, 'DupeDisplay');
end;

procedure TBandMapSettings.SetMultsOnly(aValue: boolean);
begin
   SetBool(FMultsOnly, aValue, 'MultsOnly');
end;

procedure TBandMapSettings.SetSo2rDisplay(aValue: boolean);
begin
   SetBool(FSo2rDisplay, aValue, 'So2rDisplay');
end;

procedure TBandMapSettings.SetDisplayLimit(aValue: TBandMapDisplayLimit);
begin
   if FDisplayLimit = aValue then
      begin
      Exit;
      end;
   FDisplayLimit := aValue;
   Changed('DisplayLimit');
end;

{ TPttSettings }

constructor TPttSettings.Create;
begin
   inherited Create;
   // The values uConfigValues' initialiser carried.
   FEnable       := True;
   FLockout      := False;
   FViaCommands  := True;
   FNoPollDuring := False;
   FTurnOnDelay  := 15;
end;

{ TBandSettings }

constructor TBandSettings.Create;
begin
   inherited Create;
   (* HF on, the other two off -- the values logdupe.pas and logwind.pas
     carried.  FCONTEST overwrites all three the moment a contest loads. *)
   FHfEnabled   := True;
   FVhfEnabled  := False;
   FWarcEnabled := False;
end;

(* ALL THREE NOTIFY, INCLUDING HF, WHICH CARRIED NO crP.

  HF BAND ENABLE has crP: 0 in CFGCA while its two siblings have crP: 1, so
  changing it repainted nothing.  There is no reason for that asymmetry --
  all three decide which bands the band map shows -- and it reads as an
  omission rather than a decision, of exactly the kind a hand-typed index
  invites.  Notifying is the safe direction: the worst case is one repaint
  nobody needed. *)
procedure TBandSettings.SetHfEnabled(aValue: boolean);
begin
   SetBool(FHfEnabled, aValue, 'HfEnabled');
end;

procedure TBandSettings.SetVhfEnabled(aValue: boolean);
begin
   SetBool(FVhfEnabled, aValue, 'VhfEnabled');
end;

procedure TBandSettings.SetWarcEnabled(aValue: boolean);
begin
   SetBool(FWarcEnabled, aValue, 'WarcEnabled');
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

constructor TRadioServerSettings.Create;
begin
   inherited Create;
   // The value logstuff.pas's typed constant carried.
   FTcpServerPort := 52002;
end;

constructor TR4WSettings.Create;
begin
   inherited Create;
   FExternalLogger := TExternalLoggerSettings.Create;
   FSpotCollector  := TSpotCollectorSettings.Create;
   FRadio          := TRadioServerSettings.Create;
   FYccc           := TYcccSettings.Create;
   FMmtty          := TMmttySettings.Create;
   FBandMap        := TBandMapSettings.Create;
   FBands          := TBandSettings.Create;
   FPtt            := TPttSettings.Create;

   FCommands := TStringList.Create;
   FCommands.CaseSensitive := False;
   FCommands.Sorted := True;
   FCommands.Duplicates := dupError;   // two properties claiming one command name
   BuildCommandMap;
end;

destructor TR4WSettings.Destroy;
begin
   FCommands.Free;
   FPtt.Free;
   FBands.Free;
   FBandMap.Free;
   FMmtty.Free;
   FYccc.Free;
   FRadio.Free;
   FSpotCollector.Free;
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

procedure TR4WSettings.ClampToDeclaredRanges;

   procedure Walk(const aObj: TObject);
   var
      props: PPropList;
      count, i, v: integer;
      info: PPropInfo;
      child: TObject;
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
            if info^.PropType^.Kind = tkClass then
               begin
               child := GetObjectProp(aObj, info);
               if child <> nil then
                  begin
                  Walk(child);
                  end;
               end
            else if info^.PropType^.Kind = tkInteger then
               begin
               v := GetOrdProp(aObj, info);
               with GetTypeData(info^.PropType)^ do
                  begin
                  (* A plain Integer property carries the full 32-bit range,
                    so this cannot fire for one -- no list of "which settings
                    are bounded" is needed or wanted. *)
                  if v < MinValue then
                     begin
                     SetOrdProp(aObj, info, MinValue);
                     end
                  else if v > MaxValue then
                     begin
                     SetOrdProp(aObj, info, MaxValue);
                     end;
                  end;
               end;
            end;
      finally
         FreeMem(props);
      end;
   end;

begin
   Walk(Self);
end;

procedure TR4WSettings.Changed(const aPath: string);
begin
   if Assigned(FOnChanged) then
      begin
      FOnChanged(aPath);
      end;
end;

procedure TR4WSettings.BuildCommandMap;

   (* Give one property the legacy command name it actually answers to, and
     REMOVE the name the derivation invented for it.  Leaving both would put a
     command TR4W has never had -- 'BANDS WARC ENABLED' -- into CommandNames,
     where the Preferences list and the multi-op peer sync would both offer
     it.

     THIS LIST IS PART OF THE IMPORTER, NOT PART OF THE SETTINGS.  That
     distinction decides how long it is allowed to get.  The PROPERTIES define
     the settings; these names exist so that a config file written years ago
     still reads, and so a peer running an older build is still understood.
     TR4W's command vocabulary is historically FLAT -- 'NO POLL DURING PTT'
     puts the subject last -- while a property path necessarily puts the group
     first, so a steady trickle of these is expected as the flat names meet
     the grouped model.  It is not evidence the derivation rule is wrong; it
     is the legacy compatibility layer, and it goes when the legacy formats
     stop being read. *)
   procedure Alias(const aCommand, aPath: string);
   var
      i: integer;
   begin
      for i := FCommands.Count - 1 downto 0 do
         begin
         if string(FCommands.ValueFromIndex[i]) = aPath then
            begin
            FCommands.Delete(i);
            end;
         end;
      FCommands.Values[AnsiString(aCommand)] := AnsiString(aPath);
   end;

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
                  (* THE GROUP LEARNS ITS PATH HERE, from the property name
                    that reaches it, so 'BandMap' is declared once -- as the
                    published property -- and a rename carries the change
                    notification with it automatically. *)
                  if child is TSettingsGroup then
                     begin
                     TSettingsGroup(child).BindTo(Self, path);
                     end;
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
     property path.  Keep this short -- a long list means the rule above is
     wrong, not that the settings are irregular.

     THE BAND CLASS COMMANDS LEAD WITH THE DISCRIMINATOR: 'WARC BAND ENABLE',
     not 'BAND ENABLE WARC'.  No property path can produce that and still keep
     the three in one group, because the derivation puts the GROUP first and
     these names put the band class first.

     The alternative was three one-property groups -- Warc.BandEnable,
     Vhf.BandEnable, Hf.BandEnable -- which derive with no exception at all.
     That was rejected because 'Warc' is a prefix, not an area: the settings
     store already groups these as operating.bands.hf / .warc / .vhf, so
     splitting them into three objects would disagree with the one grouping
     this program has already committed to. *)
   Alias('HF BAND ENABLE',   'Bands.HfEnabled');
   Alias('VHF BAND ENABLE',  'Bands.VhfEnabled');
   Alias('WARC BAND ENABLE', 'Bands.WarcEnabled');

   (* The group goes LAST in this one -- NO POLL DURING PTT -- which no
     property path can produce.  The other four PTT settings derive exactly. *)
   Alias('NO POLL DURING PTT', 'Ptt.NoPollDuring');
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

         (* THE RANGE COMES FROM THE PROPERTY'S OWN TYPE, which is what
           replaced crMin and crMax.  A plain Integer property carries the
           full 32-bit range here, so this costs nothing where no bound was
           declared -- and a subrange property is guarded without this code
           knowing which setting it is looking at.

           REFUSED, NOT CLAMPED.  CheckCommand rejected an out-of-range value
           and left the setting alone, and a one-time import gets no second
           chance to ask: silently substituting a nearby number would put a
           value in the store the operator never typed. *)
         with GetTypeData(info^.PropType)^ do
            begin
            if (n < MinValue) or (n > MaxValue) then
               begin
               Exit;
               end;
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
   (* THE STREAMER DOES NOT KNOW ABOUT SUBRANGES -- it writes whatever ordinal
     the file carried.  This is the one place an untrusted value reaches a
     property without passing TrySetByCommand, so it is the one place the
     ranges have to be re-imposed. *)
   ClampToDeclaredRanges;
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

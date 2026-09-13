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
   uJSON,   // TJSONObject -- the same DOM every other store in the file uses
   (* TypInfo for PPropInfo and fpjson for TJSONData: both appear in the
     signature of the streamer hook that keeps a contest-scoped group out of
     the file, so they have to be visible in the INTERFACE rather than only
     where the hook is written. *)
   TypInfo,
   fpjson;

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
   (* MINUTES, and the help file is the authority on that -- uSpots and the
     form both multiply by 60 before comparing. Named here so the unit is
     attached to the type rather than rediscovered at each reader. *)
   TBandMapDecayTime    = 0..65535;   // was crMin:0, crMax:MAXWORD
   (* HERTZ, and the LOWER BOUND IS DELIBERATELY 0 WHERE THE ROW SAID 100.

     THE ROW'S MINIMUM AND THE PROGRAM'S DEFAULT CONTRADICTED EACH OTHER.
     The global was declared `BandMapGuardBand: integer;` with its `= 200`
     commented out, and cfgdef's assignment was commented out too, so a
     station that never set the command ran at ZERO -- below a minimum of
     100 that made zero impossible to type. An older uCFG in the D7 tree
     carries crMin:0, so the floor was RAISED at some point and stranded
     the default underneath it.

     MEASURED BEFORE DECIDING, in the D7 tree at C:\TR4W and in a real
     contest database: D7 has no default either (identical commented-out
     declaration), and NY4I's own captured station config reads
     BAND MAP GUARD BAND = 0. So zero is not a porting accident, it is
     what every station is actually running.

     NY4I ruled on 2026-09-11 to keep 0 and drop the floor: defaulting to
     200 instead would silently start treating spots within 200 Hz as one
     frequency on every station that had never set it. A minimum that
     forbids the value the program itself ships with is the defect. *)
   TBandMapGuardBand    = 0..65535;   // was crMin:100 -- see above
   TAutoSapSensitivity  = 10..10000;  // was crMin:10, crMax:10000
   TAutoCqDelay         = 500..10000; // was crMin:500, crMax:10000 -- ms
   TSayHiRateCutoff     = 0..65535;   // was crMin:0, crMax:MAXWORD
   TMyItuZone           = 0..90;      // was crMin:0, crMax:90; 0 = use CTY.DAT
   TPttTurnOnDelay      = 0..65535;   // was crMin:0, crMax:MAXWORD
   TPaddleMonitorTone   = 0..65535;   // was crMin:0, crMax:MAXWORD
   TPaddlePttHoldCount  = 0..65535;   // was crMin:0, crMax:MAXWORD
   TPaddleSpeed         = 0..99;      // was crMin:0, crMax:99

   (*
     TWO STRING TYPES THAT CARRY A FACT ABOUT THEIR VALUE.

     A SUBRANGE ALREADY DOES THIS FOR NUMBERS -- the bound that used to be
     crMin and crMax is part of the type, and the compiler emits it as RTTI
     for anything that needs to ask. These do the same for two facts about
     text that the config array used to carry as crType:

       TSecretText          a password or token. Never written to the
                            settings file in the clear, never sent to a
                            multi-op peer, masked in Preferences, and its
                            case is preserved through the legacy import.

       TCaseSensitiveText   not a secret, but its capitalisation is the
                            operator's and must survive the import, which
                            upper-cases every line before splitting it.

     WHY A TYPE AND NOT A LIST. The alternative is a table of "which settings
     are secret" somewhere, and this tree has spent months deleting exactly
     that shape -- a hand-maintained list beside the thing it describes,
     free to disagree with it. FOUR separate pieces of code need this answer
     (the streamer, the importer, the multi-op sync and the Preferences
     masking) and a list would be four chances to forget one.

     MEASURED BEFORE IT WAS RELIED ON: FPC's RTTI reports the DECLARED type
     name for a distinct string type while the kind stays tkUString, so the
     existing string arm handles assignment unchanged and the name carries
     the fact.
   *)
   TSecretText = type string;
   TCaseSensitiveText = type string;
   (* The Network window's refresh timer, in milliseconds. *)
   TNetStatusInterval   = 1000..10000; // was crMin:1000, crMax:10000
   TFreqPollRate        = 10..1000;   // was crMin:10, crMax:1000 -- ms
   TServerPort          = 0..65535;   // was crMin:0, crMax:MAXWORD
   TContactsPerPage     = 10..100;    // was crMin:10, crMax:100
   (* MINITOUR DURATION, in minutes. THE ROW SAID 5..60 AND THE GLOBAL
     SAT AT 0, which MainUnit tests for -- `if TourDuration <> 0` is how
     it knows there is no tour. So the type has to admit the off value
     the program actually uses, exactly as TQsoPoints admits -1. *)
   TTourDuration        = 0..60;      // was crMin:5, crMax:60 -- see above
   TAutoTimeIncrement   = 0..65535;   // was crMin:0, crMax:MAXWORD
   TWakeUpTimeOut       = 0..255;     // was crMin:0, crMax:MAXBYTE
   (* A UDP PORT. 1..65535, which is the port range and not a TR4W rule --
     the old row said crMin:1, crMax:65535 and meant the same thing. *)
   TWsjtxPort           = 1..65535;   // was crMin:1, crMax:65535
   (* QSO POINTS, AND -1 IS THE VALUE THAT MATTERS.

     Minus one means "this contest declares no fixed point value", and the
     scoring code says so directly: `if (QSOPointsDomesticCW >= 0)` in
     logstuff.  THE CFGCA ROW COULD NOT EXPRESS IT -- crMin and crMax are
     Word, unsigned -- so all four rows said 0..MAXWORD while all four
     variables sat at -1, a value their own declared range rejected.  A
     subrange is signed, so the type simply says what the program means. *)
   TQsoPoints           = -1..65535;  // was crMin:0, crMax:MAXWORD -- see above

   (*
     AN ENUMERATED SETTING'S TYPE LIVES HERE NOW.

     NY4I, 2026-09-13: *"If it is related to settings, regardless of where it
     is defined today, it should now live in uSettings. That goes for VC.pas
     too."*

     RateDisplayType was declared in trdos/logwind.pas, which is where the
     thing it controls is drawn -- and that is the wrong reason for a type to
     live somewhere. It describes a SETTING: what the rate box counts.

     IT INVERTS THE DEPENDENCY, WHICH IS THE POINT. Publishing a property of
     this type from a group would otherwise mean uSettingsModel using LogWind;
     with the declaration here, LogWind uses uSettingsModel, which it already
     did. This unit still depends on nothing but the RTL.

     THE SPELLING IS NOT THE IDENTIFIER, and that is why the vocabulary comes
     with it. A config file says QSO POINTS; the enum member is Points. The
     table below is the one logwind carried, as `string` rather than
     PAnsiChar, and it is registered against the property at startup -- so the
     ordinal a file selects is decided by POSITION in one place.
   *)
   RateDisplayType = (QSOs, Points, BandQSOs);
   (* The other five that moved on the same ruling, from logwind, loggrid and
     logdom. Each describes what a SETTING may be, so each belongs here. *)
   HourDisplayType = (ThisHour, LastSixtyMins, BandChanges,
                      BandChangesThisComputer);
   TenMinuteRuleType = (NoTenMinuteRule, TimeOfFirstQSO);
   BandMapSplitModeType = (ByCutoffFrequency, AlwaysPhone);
   DistanceDisplayType = (NoDistanceDisplay, DistanceMiles, DistanceKM);
   RemainingMultDisplayModeType = (NoRemainingMults, Erase, HiLight);
   DupeCheckSoundType = (DupeCheckNoSound, DupeCheckBeepIfDupe,
                         DupeCheckGratsIfMult);
   (* Was tLogLevels in VC.pas -- the unit NY4I named explicitly. It is the
     vocabulary of a setting, and VC is the source of truth for TYPES. *)
   tLogLevels = (llNone, llFatal, llError, llWarn, llInfo, llDebug, llTrace);
   (* Was PossibleCallActionType in trdos/logscp.pas. *)
   PossibleCallActionType = (AnyCall, OnlyCallsWithNames, LogOnly);
   UserInfoType = (NoUserInfo, NameInfo, QTHInfo, CheckSectionInfo,
                   SectionInfo, OldCallInfo, FocInfo, GridInfo, CQZoneInfo,
                   ITUZoneInfo, User1Info, User2Info, User3Info, User4Info,
                   User5Info, CustomInfo);
   (*
     FOUR THAT WERE ALLOW-LISTS, NOT RANGES.

     Each was a ckArray row: crAddress indexed ArrayRecordArray, whose entry
     named a const array of the values the setting may take, and CheckCommand
     refused anything not in it. crMin and crMax were advisory there, and in
     one case simply wrong -- MULT REPORT MINIMUM BANDS says 2..5 against an
     array of (2, 3, 4).

     ALL FOUR OF THESE LISTS ARE CONTIGUOUS, which is why they become plain
     subranges and need no registered value check: (1..10), (3, 4, 5, 6),
     (0, 1, 2, 3) and (0..6) are ranges written out one element at a time.
     The two allow-lists that are genuinely NOT ranges -- SCP MINIMUM LETTERS
     (0, 3, 4, 5) and STEREO CONTROL PIN (5, 9) -- are still rows, and they
     want RegisterSettingValueCheck rather than a type.
   *)
   TCwSpeedIncrement       = 1..10;   // was CW_SPEED_INCREMENT
   TCwDitDahRatio          = 3..6;    // was DITDAHRATIO_ARRAY
   TCwLeadingZeros         = 0..3;    // was LEADING_ZEROS_ARRAY
   TAutoSendCharacterCount = 0..6;    // was AUTO_SEND_CHARACTER_COUNT_ARRAY
   (* THE MAIN WINDOW'S TWO SIZES, both ckArray rows whose allow-lists are
     ranges: ROW_COUNT_ARRAY is (5..15) and WINDOW_SIZE_ARRAY is (1..15). *)
   TLogRowCount            = 5..15;   // was ROW_COUNT_ARRAY
   TMainWindowSize         = 1..15;   // was WINDOW_SIZE_ARRAY
   TAutoQslInterval        = 0..6;    // was AUTO_QSL_INTERVAL
   (*
     AND THE TWO ALLOW-LISTS THAT ARE NOT RANGES KEEP A PLAIN integer.

     SCP MINIMUM LETTERS admits (0, 3, 4, 5) and STEREO CONTROL PIN admits
     (5, 9) -- an LPT pin number, where 6, 7 and 8 are other signals. A
     subrange would quietly widen both, and widening what a config file may
     say is a behaviour change however harmless it looks.

     THEIR VOCABULARY IS REGISTERED INSTEAD -- see RegisterSettingAllowedValues,
     and uCFG's registration of it from the very const arrays CheckCommand
     matched against. One registration is both the refusal and what a
     drop-down offers, so the two cannot drift apart.
   *)
   (* THE MAIN WINDOW'S FONT SIZE, and it is a STEP not a point size --
     0, 1 or 2, which MainUnit turns into pixels as `13 + FontSize - 1`
     and into a cell width as `ws + 2 * FontSize - 3`. The old row carried
     crMin:0, crMax:2 and said nothing about what the numbers meant. *)
   TMainFontSize        = 0..2;       // was crMin:0, crMax:2
   (* THE RS AND RST THIS STATION LOGS AS SENT. Two settings, not one: a
     phone report has two digits and a CW report three, and the ranges the
     rows carried say so -- 11..59 and 111..599. Writing them as subranges
     puts that in the type, where CFGCommandValueAsString and the peer sync
     both read it out of RTTI. *)
   TLogRsSent           = 11..59;     // was crMin:11,  crMax:59
   TLogRstSent          = 111..599;   // was crMin:111, crMax:599
   TBackupLogFrequency  = 0..65535;   // was crMin:0, crMax:MAXWORD -- QSOs
   TRotatorUdpPort      = 1..65535;   // was crMin:1, crMax:65535

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
      (* The same, for a string property. Same only-if-changed rule and the
        same reason for it. *)
      procedure SetStr(var aField: string; const aValue, aProperty: string);
   public
      // Called by the owner's walk. Not for anyone else.
      procedure BindTo(aOwner: TR4WSettings; const aPath: string);

      (* WHERE THIS GROUP SITS, e.g. 'Hamscore'. Assigned by BindTo during
        the command walk, and read by the streamer so a secret can be filed
        under a stable name -- the Windows Credential Manager needs one, and
        it has to be the SAME name on every save or the operator collects a
        new entry each time. *)
      property Path: string read FPath;

      (* IS THIS GROUP THE CONTEST'S, RATHER THAN THE STATION'S?

        False for almost everything. True for a group whose values are
        assigned by FCONTEST when a contest loads -- band enables today.
        Such a group is EXCLUDED from settings\tr4w.json and captured into
        the contest database instead, because a value the contest sets is
        not a preference the station holds. See TBandSettings for the
        defect that made this necessary.

        A CLASS FUNCTION so the question can be asked of the type, and so
        no instance has to exist to answer it. *)
      class function IsContestScoped: boolean; virtual;
   end;

   (*
     WSJT-X -- the digital-mode program TR4W exchanges decodes and QSOs with
     over UDP.

     EVERY ONE OF THE FIVE NAMES CARRIES AN ALIAS, and it is one reason five
     times rather than five irregularities: the command spelling is WSJT-X,
     with a hyphen, and no Pascal identifier can contain one. The alternative
     -- naming the group W and the property SJTXEnabled, or some other
     contortion that happens to derive a hyphen -- would make the property
     path lie about what it is to satisfy the importer.

     THREE OF THEM WERE HOOKS IN AdditionalProcsArray, slots 23, 24 and 25,
     and all three are property setters now (uSettingsEffects). Slot 23 is the
     one worth remembering: EXTERNAL LOGGER ENABLED carried crA: 23 for a
     while and therefore started and stopped the WSJT-X server, because a hook
     index is an integer typed by hand into a table and a wrong one compiles.
   *)
   TWsjtxSettings = class(TSettingsGroup)
   private
      FEnabled: boolean;
      FRadioControlEnabled: boolean;
      FSendHighlights: boolean;
      FBroadcastPort: TWsjtxPort;
      FMulticastGroup: string;
   public
      constructor Create;
   published
      (* Was WSJTXEnabled in uCFG, and it defaults TRUE so that a config file
        which never mentions WSJT-X still starts the listener -- the comment
        in uProgramMain beside the old global says exactly that. *)
      property Enabled: boolean read FEnabled write FEnabled;
      (* Was WSJTXRadioControlEnabled -- whether a frequency change in WSJT-X
        is allowed to move the radio. *)
      property RadioControlEnabled: boolean
         read FRadioControlEnabled write FRadioControlEnabled;
      (* Was WSJTXSendColorization. The COMMAND is WSJT-X SEND HIGHLIGHTS and
        the property is named after the command rather than after the old
        global: what travels is a colour hint for a decode line, and
        "highlights" is what the operator sees it called. *)
      property SendHighlights: boolean
         read FSendHighlights write FSendHighlights;
      (* Was WSJTXUDPPort in logstuff.pas, 2237 -- WSJT-X's own default. The
        bound is a SUBRANGE, so the range that used to be crMin/crMax is part
        of the type and the compiler emits it as RTTI. *)
      property BroadcastPort: TWsjtxPort
         read FBroadcastPort write FBroadcastPort;
      (* Was WSJTXMulticastGroup, a Str20 -- e.g. '224.0.0.1'. Empty means
        ordinary unicast, which is the usual case. *)
      property MulticastGroup: string
         read FMulticastGroup write FMulticastGroup;
   end;

   (*
     THE MAIN WINDOW'S APPEARANCE -- four flags an operator sets once and
     forgets, which the settings store has always grouped under
     "appearance.".

     ALL FOUR CARRY AN ALIAS, and for the usual reason: TR4W's command
     vocabulary is flat, so the names are NO BORDER and SHOW GRIDLINES rather
     than MAIN WINDOW NO BORDER. A property path necessarily puts the group
     first.

     TWO OF THEM ARE ABOUT THE LOG GRID and are here rather than in
     TLogSettings on purpose: TLogSettings is about what LOGGING does -- when
     a QSO is written, what is backed up, which report is recorded -- and
     these two are about what the window looks like. The store made the same
     split before this migration existed.
   *)
   TMainWindowSettings = class(TSettingsGroup)
   private
      FNoBorder: boolean;
      FNoCaption: boolean;
      FNoColumnHeader: boolean;
      FShowGridlines: boolean;
      FRowCount: TLogRowCount;
      FWindowSize: TMainWindowSize;
      FRateDisplay: RateDisplayType;
      FHourDisplay: HourDisplayType;
      FUserInfoShown: UserInfoType;
   public
      constructor Create;
   published
      (* Was Config.NoBorder -- drops the sunken edge from every main-window
        element and from the entry fields. *)
      property NoBorder: boolean read FNoBorder write FNoBorder;
      (* Was Config.NoCaption -- the form's title bar. Defaults False and has
        never been bench-tested either way; see docs/BENCH_QUEUE.md. *)
      property NoCaption: boolean read FNoCaption write FNoCaption;
      (* Was Config.NoColumnHeader.

        NO LIVE READER IN THIS BUILD, and it is carried rather than dropped,
        following the ruling that produced MY IOTA and SHOW ALL SERIAL PORTS:
        an operator can see it in Preferences, so deleting it is NY4I's call
        and not a migration's side effect. *)
      property NoColumnHeader: boolean
         read FNoColumnHeader write FNoColumnHeader;
      (* Was Config.ShowGridlines. This one had crP: 3 -- the grid redraw --
        and is an arm in uSettingsEffects now, so it takes effect when it is
        changed rather than at the next start. *)
      property ShowGridlines: boolean read FShowGridlines write FShowGridlines;
      (* Was the global LinesInEditableLog in VC.pas -- how many QSOs the log
        pane shows. ROW COUNT, aliased: no property path produces a name that
        says nothing about what is being counted.

        IT IS A HEIGHT AND NOT A ROW LIMIT ANY MORE. The log pane used to be
        a fixed window of exactly this many records; it is a TLogGrid now and
        this survives as the height it is sized to. *)
      property RowCount: TLogRowCount read FRowCount write FRowCount;
      (* Was the global WindowSize in VC.pas.

        IT IS A SCALE STEP, NOT A PIXEL SIZE. `ws := WindowSize + 12` is the
        font size every element on the main window is measured in, so this
        one number sets how large the whole window draws.

        WINDOW SIZE, aliased -- the derived name would say it twice. *)
      property WindowSize: TMainWindowSize read FWindowSize write FWindowSize;
      (* Was the global RateDisplay in logwind -- WHAT THE RATE BOX COUNTS:
        QSOs, QSO points, or QSOs on the current band.

        RATE DISPLAY, aliased. The spellings a config file uses are
        RATE_DISPLAY_SPELLINGS, registered against this property. *)
      property RateDisplay: RateDisplayType
         read FRateDisplay write FRateDisplay;
      (* Was the global HourDisplay in logwind -- WHAT THE HOUR BOX COUNTS
        OVER: this clock hour, the last sixty minutes, or band changes (all
        of them, or only this position's). HOUR DISPLAY, aliased. *)
      property HourDisplay: HourDisplayType
         read FHourDisplay write FHourDisplay;
      (* Was the global UserInfoShown in logwind -- WHICH FIELD the user-info
        box shows beside a callsign, from the sixteen the database can offer.
        USER INFO SHOWN, aliased. *)
      property UserInfoShown: UserInfoType
         read FUserInfoShown write FUserInfoShown;
   end;

   (*
     THE MULTI-OP NETWORK, as this position behaves on it.

     NOT TComputerSettings, which is this position's IDENTITY -- the name and
     id the other positions see. These four are policy: what arriving traffic
     is allowed to do to this log, what is announced, and how often.

     ALL FOUR CARRY AN ALIAS, because every one of the legacy names omits the
     subject or abbreviates it -- ALLOW AUTO UPDATE, NET STATUS UPDATE
     INTERVAL. A property path has to say which network.
   *)
   TNetworkSettings = class(TSettingsGroup)
   private
      FAllowAutoUpdate: boolean;
      FMultiMultsOnly: boolean;
      FShowTypedCallsign: boolean;
      FStatusUpdateInterval: TNetStatusInterval;
      FIntercomFileEnable: boolean;
   public
      constructor Create;
   published
      (* Was tAllowAutoUpdate in uNet -- whether a correction arriving from
        another position is applied to a QSO already in this log. Defaults
        TRUE, which is what a multi-op network is for. *)
      property AllowAutoUpdate: boolean
         read FAllowAutoUpdate write FAllowAutoUpdate;
      (* Was Config.MultiMultsOnly.

        NO LIVE READER IN THIS BUILD, and carried rather than dropped for the
        reason NO COLUMN HEADER was: an operator can see it in Preferences,
        so removing a setting is a decision and not a migration's side
        effect. *)
      property MultiMultsOnly: boolean
         read FMultiMultsOnly write FMultiMultsOnly;
      (* Was tShowTypedCallsign in uNet -- whether each keystroke of a partly
        typed callsign is announced to the other positions, so they can see
        who is being worked before the QSO is logged. *)
      property ShowTypedCallsign: boolean
         read FShowTypedCallsign write FShowTypedCallsign;
      (* Was tNetStatusUpdateInterval -- the Network window's refresh timer,
        in milliseconds. The bound is a subrange, which is where crMin:1000
        and crMax:10000 went. *)
      property StatusUpdateInterval: TNetStatusInterval
         read FStatusUpdateInterval write FStatusUpdateInterval;
      (* Was Config.IntercomFileEnable -- the intercom writes its
        messages to a file as well as showing them, so another program
        on the position can read them. *)
      property IntercomFileEnable: boolean
         read FIntercomFileEnable write FIntercomFileEnable;
   end;

   (*
     HOW THE PROGRAM BEHAVES WHILE AN OPERATOR IS WORKING -- nine flags and
     counters that belong to no window and no device, which the settings store
     has grouped as "operating." since before this migration existed.

     EVERY NAME HERE CARRIES AN ALIAS, and that is the cost of the grouping
     rather than evidence against it. TR4W's vocabulary is flat -- SHIFT KEY
     ENABLE, WAKE UP TIME OUT -- so a path that says which area a setting
     belongs to cannot also produce the historic name.

     THE ALTERNATIVE WAS NINE ONE-PROPERTY GROUPS, named so that each derives
     exactly: ShiftKey.Enable, WakeUp.TimeOut, Ie.Switch. That is how Qzb and
     Stations were done, and it is right when the group is a REAL area with
     one setting in it today. It is wrong here: it would put nine sections in
     settings\tr4w.json for nine unrelated booleans and claim a structure the
     program does not have.
   *)
   TOperatingSettings = class(TSettingsGroup)
   private
      FAskForFrequencies: boolean;
      FAutoTimeIncrement: TAutoTimeIncrement;
      FTenMinuteRule: TenMinuteRuleType;
      FDupeCheckSound: DupeCheckSoundType;
      FBeepEnable: boolean;
      FHandLogMode: boolean;
      FIeSwitch: boolean;
      FIncrementTimeEnable: boolean;
      FShiftKeyEnable: boolean;
      FTuneAltDEnable: boolean;
      FWakeUpTimeOut: TWakeUpTimeOut;
      FAutoQsoNumberDecrement: boolean;
      FCustomUserString: string;
      FFrequencyMemoryEnable: boolean;
      FLogSubTitle: string;
      FFrequencyPollRate: TFreqPollRate;
   public
      constructor Create;
   published
      (* Was AskForFrequencies in logwind -- whether the cluster connection
        asks for a spot's frequency when one arrives without it. *)
      property AskForFrequencies: boolean
         read FAskForFrequencies write FAskForFrequencies;
      (* Was the global TenMinuteRule in logwind -- the band-change rule some
        contests impose, and NONE when none does.

        TEN MINUTE RULE, aliased. STATION-SCOPED, unlike the settings around
        it whose names begin CONTEST: nothing anywhere assigns it per
        contest, which is the test that put QSO NUMBER BY BAND in the
        contest-scoped group. *)
      property TenMinuteRule: TenMinuteRuleType
         read FTenMinuteRule write FTenMinuteRule;
      (* Was the global DupeCheckSound in logstuff -- what the dupe check is
        allowed to make a noise about: nothing, a beep on a dupe, or a
        fanfare on a new multiplier. DUPE CHECK SOUND, aliased. *)
      property DupeCheckSound: DupeCheckSoundType
         read FDupeCheckSound write FDupeCheckSound;
      (* Was AutoTimeIncrementQSOs -- advance the clock by a minute every N
        QSOs, for practice runs. Zero is off, which is why the subrange
        starts there. *)
      property AutoTimeIncrement: TAutoTimeIncrement
         read FAutoTimeIncrement write FAutoTimeIncrement;
      (* Was BeepEnable in logk1ea -- the audible cue. Declared False there
        with the note "N4AF performance change". *)
      property BeepEnable: boolean read FBeepEnable write FBeepEnable;
      (* Was tHandLogMode -- entering QSOs after the fact rather than as they
        happen, which suppresses the live timing behaviour. *)
      property HandLogMode: boolean read FHandLogMode write FHandLogMode;
      (* Was IE_Switch in logwind, read by uSpots when it decides what an
        initial exchange contributes. The name is TR4W's own. *)
      property IeSwitch: boolean read FIeSwitch write FIeSwitch;
      (* Was IncrementTimeEnable.

        IT IS ALSO DERIVED, and that is deliberate rather than a second
        writer: LogCfg turns it on when AUTO TIME INCREMENT is non-zero,
        because a QSO count with no enable would do nothing. The setting
        remains an operator-settable value; the derivation only raises it. *)
      property IncrementTimeEnable: boolean
         read FIncrementTimeEnable write FIncrementTimeEnable;
      (* Was ShiftKeyEnable in logk1ea, read by the main window's key
        handling. Declared True. *)
      property ShiftKeyEnable: boolean
         read FShiftKeyEnable write FShiftKeyEnable;
      (* Was TuneDupeCheckEnable -- dupe-check the frequency the radio is
        tuned to, the way Alt-D does for a typed callsign. The command has a
        hyphen in it, so this one would need an alias whatever the group were
        called. *)
      property TuneAltDEnable: boolean
         read FTuneAltDEnable write FTuneAltDEnable;
      (* Was WakeUpTimeOut -- minutes of no QSOs before the alarm sounds.
        Zero is off. *)
      property WakeUpTimeOut: TWakeUpTimeOut
         read FWakeUpTimeOut write FWakeUpTimeOut;
      (* Was Config.AutoQSONumberDecrement -- take the serial number back
        when a QSO is abandoned, so the next one reuses it. It carried
        crP: 5, the next-number display, which is a setter arm now. *)
      property AutoQsoNumberDecrement: boolean
         read FAutoQsoNumberDecrement write FAutoQsoNumberDecrement;
      (* Was CustomUserString, a Str40 -- text the operator puts in the
        user-defined field of the log display. *)
      property CustomUserString: string
         read FCustomUserString write FCustomUserString;
      (* Was FrequencyMemoryEnable in logwind, declared True. The memory
        list itself is FREQUENCY MEMORY, a ctFreqList row that stays
        where it is: an accumulating list is a different shape from a
        value and is not part of this move. *)
      property FrequencyMemoryEnable: boolean
         read FFrequencyMemoryEnable write FFrequencyMemoryEnable;
      (* Was LogSubTitle, a Str40 -- the second line of the log window's
        title. No live reader in this build; carried, not withdrawn. *)
      property LogSubTitle: string
         read FLogSubTitle write FLogSubTitle;
      (* Was FreqPollRate in logwind -- how often the polling thread asks
        the radio for its frequency, in milliseconds.

        STATION-WIDE, NOT PER RADIO, which is why it is here and not in
        the radio library: a driver that cannot stand a fast rate says so
        itself with honorsFreqPollRate, so the two answer different
        questions. The bound is a subrange, from crMin:10 and
        crMax:1000. *)
      property FrequencyPollRate: TFreqPollRate
         read FFrequencyPollRate write FFrequencyPollRate;
   end;

   (*
     SUPER CHECK PARTIAL -- the callsign database behind the partial-call
     strip. One setting today; the group exists because the property PATH is
     what derives the command name, and because SCP is a real area of the
     program rather than a convenient bucket.
   *)
   TScpSettings = class(TSettingsGroup)
   private
      FNameFlagEnable: boolean;
      FMinimumLetters: integer;
      FPossibleCallMode: PossibleCallActionType;
      FCountryString: string;
      procedure SetCountryString(const aValue: string);
   public
      constructor Create;
   published
      (* Was Config.NameFlagEnable -- show the operator's name from the
        database beside a matched callsign.

        NO LIVE READER IN THIS BUILD, and carried rather than dropped on the
        same ruling as NO COLUMN HEADER: an operator can see it in
        Preferences, so withdrawing it is a decision. *)
      property NameFlagEnable: boolean
         read FNameFlagEnable write FNameFlagEnable;
      (* Was the global SCPMinimumLetters in logstuff -- how many characters
        must be typed before Super Check Partial offers anything, and 0
        switches it off. SCP MINIMUM LETTERS, which derives exactly.

        (0, 3, 4, 5), NOT 0..5, and NOT a subrange: see the note on the types
        above. The vocabulary is registered from uCFG. *)
      property MinimumLetters: integer
         read FMinimumLetters write FMinimumLetters;
      (* Was CD.PossibleCallAction -- a FIELD of the Super Check Partial
        database object, read by BARE NAME inside two of its own methods.

        WHICH PARTIAL MATCHES ARE OFFERED: all of them, only those whose
        database entry carries a name, or none (log only). POSSIBLE CALL
        MODE, aliased. *)
      property PossibleCallMode: PossibleCallActionType
         read FPossibleCallMode write FPossibleCallMode;
      (*
        Was CD.CountryString, a Str80 field of the SCP database object --
        which countries Super Check Partial offers calls from, as a
        comma-separated list, or empty for all of them. A leading '!' or '-'
        inverts it into an exclude list.

        SCP COUNTRY STRING, which derives exactly.

        THE SETTER IS THE crA HOOK. F_SCP_COUNTRY_STRING appended a trailing
        comma when one was missing, because GoodCountry walks the list by
        looking for the next comma and the last entry would otherwise be
        skipped. That normalisation ran only when CheckCommand applied the
        row; it runs however the value is set now.

        IT IS A string, NOT A Str80. The row's crMax: 80 truncated on input;
        the one reader that needs a bounded copy still takes one, so what
        changes is that a long list is KEPT rather than silently cut.
      *)
      property CountryString: string read FCountryString write SetCountryString;
   end;

   (*
     THE DX CLUSTER, as this station connects to it.

     TWO SETTINGS, AND THE THIRD IS DELIBERATELY ABSENT. CONNECTION COMMAND
     is not here: the cluster LIBRARY owns it -- one cluster, one connect
     command, written by the cluster editor and applied by
     ApplyActiveCluster -- so moving it is a merge of two models rather than
     a migration of one. These two have no such second owner; nothing but
     the config array ever wrote them.
   *)
   TClusterSettings = class(TSettingsGroup)
   private
      FConnectionAtStartup: boolean;
      FBroadcastAllPacketData: boolean;
   public
      constructor Create;
   published
      (* Was Config.tConnectionAtStartup -- open the cluster connection when
        the program starts, and the flag uTelnet consults before deciding an
        automatic reconnect is wanted. *)
      property ConnectionAtStartup: boolean
         read FConnectionAtStartup write FConnectionAtStartup;
      (* Was Packet.BroadcastAllPacketData -- relay every line from the
        cluster to the other multi-op positions, not only the spots.

        ITS ONE READER IS COMMENTED OUT in logpack, so this reaches nothing
        in this build. Carried, not withdrawn, for the reason above. *)
      property BroadcastAllPacketData: boolean
         read FBroadcastAllPacketData write FBroadcastAllPacketData;
   end;

   (*
     THE SCORE SERVER -- where live scores are posted during a contest and
     where the standings are read back.

     BOTH NAMES DERIVE EXACTLY from Score.PostingUrl and Score.ReadingUrl,
     which is why the group is called Score and not Scores or ScoreServer.
   *)
   TScoreSettings = class(TSettingsGroup)
   private
      FPostingUrl: string;
      FReadingUrl: string;
   public
      constructor Create;
   published
      (* Was Config.GetScoresSeverPostingAddress, a ShortString. The old row
        was ctURL, which CheckCommand treated exactly as a string -- there was
        no validation behind the type. *)
      property PostingUrl: string read FPostingUrl write FPostingUrl;
      (* Was Config.GetScoresSeverReadingAddress. The PostScores window opens
        this in a browser. *)
      property ReadingUrl: string read FReadingUrl write FReadingUrl;
   end;

   (*
     THE TELNET CLUSTER HOST. One setting, and TELNET SERVER derives exactly
     from Telnet.Server.

     NOT TClusterSettings, which holds the two policy flags. This is the
     host itself, and it is the one piece of cluster configuration the
     cluster library will eventually claim -- keeping it in its own group
     makes that a move of one property rather than an unpicking.
   *)
   TTelnetSettings = class(TSettingsGroup)
   private
      FServer: string;
   published
      (* Was TelnetServer in uTelnet, a Str50. uTelnet seeds its host list
        from it and preselects it. *)
      property Server: string read FServer write FServer;
   end;

   (*
     TR4WSERVER, as this position reaches it -- the multi-op server that
     holds the shared log.

     THREE OF FOUR, AND THE FOURTH IS NAMED SO THE GAP READS AS A DECISION.
     SERVER PASSWORD is ctPassword, and a password cannot leave the array
     yet: LogCfg re-reads every ctPassword and ctCaseSensitive value from the
     ini a second time to put the operator's original case back, and it finds
     them by walking CFGCA BY ADDRESS. A migrated row is not in that walk, so
     the password would silently arrive upper-cased. That wants one mechanism
     built deliberately, not three times.

     ALL THREE NAMES HERE DERIVE EXACTLY, including the long one.
   *)
   TServerSettings = class(TSettingsGroup)
   private
      FAddress: string;
      FPort: TServerPort;
      FAutoSynchronizeLogOnConnect: boolean;
      FPassword: TSecretText;
   public
      constructor Create;
   published
      (* Was ServerAddress in uNet, a str31 holding 'LOCALHOST'. Its old
        ShortString form is why uNet formatted it as @ServerAddress[1] -- a
        pointer into the string's bytes -- which goes with it. *)
      property Address: string read FAddress write FAddress;
      (* Was ServerPort, 1061. The log-synchronise client uses this plus one,
        which is why the bound stops one short of the top of the range. *)
      property Port: TServerPort read FPort write FPort;
      (* Was ServerAutoSynchronizeLogOnConnect (issue #912) -- pull the
        server's log as soon as this position connects. *)
      property AutoSynchronizeLogOnConnect: boolean
         read FAutoSynchronizeLogOnConnect write FAutoSynchronizeLogOnConnect;
      (* Was ServerPassword in uNet, a Str20 declared 'TR4WSERVER'.

        IT USED TO CROSS THE NETWORK. The row carried crNetwork: 1, so this
        position's server password was synced to the others in the clear, and
        one position could overwrite another's. As TSecretText it is refused
        from a peer and each position holds its own (NY4I, 2026-09-12). *)
      property Password: TSecretText read FPassword write FPassword;
   end;

   (*
     HAMSCORE -- live score posting to scoredistributor.net.

     THREE OF FIVE. HAMSCORE USERNAME is ctCaseSensitive and HAMSCORE
     PASSWORD is ctPassword, and both wait on the same case-restoring
     mechanism described on TServerSettings.

     THE GROUP IS SPELLED Hamscore, ONE CAPITAL, ON PURPOSE. The derivation
     splits before a capital that follows a lower-case letter, so HamScore
     would produce 'HAM SCORE ENABLE' and every name would need an alias.
     Spelling the group the way the command spells it costs nothing and
     leaves three exact derivations.
   *)
   THamscoreSettings = class(TSettingsGroup)
   private
      FUrl: string;
      FSendContactInfo: boolean;
      FUsername: TCaseSensitiveText;
      FPassword: TSecretText;
   public
      constructor Create;
   published
      (* Was Config.HamScoreURL. uHamScore fills in the RTC 3.0 default when
        it is empty, and that assignment still works -- it is a property with
        a setter rather than a field, which is the only thing that changed. *)
      property Url: string read FUrl write FUrl;
      // Was Config.HamScoreSendContactInfo -- send each QSO, not just totals.
      property SendContactInfo: boolean
         read FSendContactInfo write FSendContactInfo;
      (* Was Config.HamScoreUsername, a ShortString. EMPTY FALLS BACK TO MY
        CALL, which is why an empty value is meaningful and not merely unset.

        TCaseSensitiveText, so the legacy import puts the operator's own
        capitalisation back -- the ini reader upper-cases a whole line before
        splitting it, which is what made this setting unmovable until the
        keychain work. *)
      property Username: TCaseSensitiveText read FUsername write FUsername;
      (* Was Config.HamScorePassword. TSecretText, so it goes to the keychain
        rather than into settings\tr4w.json, is never sent to a multi-op
        peer, and is masked in Preferences -- four behaviours from one
        declaration. *)
      property Password: TSecretText read FPassword write FPassword;
   end;

   (*
     THE MP3 RECORDER. One setting of three: MP3 PATH and MP3 PLAYER are
     ctDirectory and ctFileName, which wait on the open ruling about what a
     path setting validates.

     NOTHING READS IT IN THIS BUILD -- uMP3Recorder was deleted in September
     with its lame_enc.dll binding. It is carried rather than withdrawn for
     the reason NO COLUMN HEADER was: an operator can see it in Preferences,
     so removing a setting is a decision.
   *)
   TMp3Settings = class(TSettingsGroup)
   private
      FRecorderEnable: boolean;
      FPath: string;
      FPlayer: string;
   published
      // Was Config.MP3RecorderEnable. MP3 RECORDER ENABLE derives exactly.
      property RecorderEnable: boolean
         read FRecorderEnable write FRecorderEnable;
      (* Was Config.MP3Path, and NOTHING READS IT -- uMP3Recorder went with
        the waveIn capture engine. MP3 PATH derives exactly.

        CARRIED RATHER THAN WITHDRAWN, per NY4I on MY IOTA: "migrate my iota
        too, it is for future use". An operator's configured folder survives
        into the build that rewrites the feature, instead of being silently
        dropped by the one that did not have it. *)
      property Path: string read FPath write FPath;
      (* Was Config.MP3Player. Same story, and one step further: this one had
        no reader anywhere in the tree even before the recorder was deleted. *)
      property Player: string read FPlayer write FPlayer;
   end;

   (*
     THE PARALLEL-PORT HARDWARE, as far as one flag goes. The three LPT base
     addresses and the three port assignments beside it are ctPortLPT and
     belong to the port identity work, which is deciding what a port IS
     before deciding where its setting lives.
   *)
   THardwareSettings = class(TSettingsGroup)
   private
      FUseControlPort: boolean;
      FStereoControlPin: integer;
   public
      constructor Create;
   published
      (* Was tUseControlPort in logk1ea -- whether the LPT control lines are
        driven at all. Nothing writes it at run time; it is read where the
        paddle and footswitch are serviced. *)
      property UseControlPort: boolean
         read FUseControlPort write FUseControlPort;
      (* Was the global StereoControlPin in logk1ea -- WHICH LPT PIN drives
        the headphone relay. (5, 9), registered from uCFG.

        STEREO CONTROL PIN, aliased: the derived name would put the word
        HARDWARE in front of a command an operator has typed for years. *)
      property StereoControlPin: integer
         read FStereoControlPin write FStereoControlPin;
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
      FLoggerType: string;
   public
      constructor Create;
   published
      (*
        WHICH LOGGER PROGRAM, AS A TOKEN -- 'NONE', 'DXKEEPER', 'ACLOG',
        'HRD'. Was the global elLogType, an ExternalLoggerType.

        A STRING, AND THE ENUM STAYS WITH THE SUBSYSTEM. NY4I, 2026-09-13:
        the external logger is a subsystem, so its type parameters "are
        strictly supporting the factory objects (just like the radio
        works)" -- and a radio definition holds an opaque RegistryId string
        for exactly this reason. The settings model has no business knowing
        what logger programs exist; the factory does, and it publishes its
        vocabulary here through RegisterSettingAllowedValues.

        EXTERNAL LOGGER, aliased -- the derived name would say it twice.
      *)
      property LoggerType: string read FLoggerType write FLoggerType;
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
      FDecayTime: TBandMapDecayTime;
      FGuardBand: TBandMapGuardBand;
      FItemWidth: TBandMapItemWidth;
      FSize: TBandMapSize;
      FSplitMode: BandMapSplitModeType;
      procedure SetSplitMode(aValue: BandMapSplitModeType);
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
      (* Was the global BandMapSplitMode in logwind -- how a split-mode spot
        is placed: by the cutoff frequency, or always as phone.

        BAND MAP SPLIT MODE, which derives exactly. Its row carried crP: 1,
        the band-map redraw, so its setter raises like DisplayLimit's. *)
      property SplitMode: BandMapSplitModeType
         read FSplitMode write SetSplitMode;

      (* THE THREE BELOW CARRIED crP: 0 AND crJ: 1 -- no redraw, restart
        required -- so they are plain field writes with no notification.

        That asymmetry is REAL rather than an oversight like HF BAND ENABLE's:
        the grid's geometry is computed once in LayOutGrid, and a repaint
        would not re-run it.  Making them take effect live is a UI change, not
        a settings change, and it is not one to make blind. *)
      // Was BandMapItemHeight in uBandmap.pas.
      property ItemHeight: TBandMapItemHeight read FItemHeight write FItemHeight;
      (* Was the global BandMapDecayTime in logwind.pas. BAND MAP DECAY
        TIME derives exactly, so no alias.

        ITS crA HOOK WAS DEAD. F_BAND_MAP_DECAY_TIME's entire body is
        commented out and it returns True -- the two lines that once
        derived a multiplier and divided by it are gone. So this needs no
        setter side effect, and AdditionalProcsArray entry 5 now has no
        user. Its crP was 1, the band map redraw, which uSettingsEffects
        already raises for the whole BandMap group. *)
      property DecayTime: TBandMapDecayTime read FDecayTime write FDecayTime;
      (* Was the global BandMapGuardBand in logwind.pas, in Hz. BAND MAP
        GUARD BAND derives exactly, so no alias. Zero means no guard band:
        every 'is this spot near that one' test degenerates to an exact
        frequency match, which is what the program has always done when
        nobody set it. *)
      property GuardBand: TBandMapGuardBand read FGuardBand write FGuardBand;
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
   (*
     BANDS ARE A CONTEST PARAMETER, NOT A STATION SETTING.

     NY4I, 2026-09-11: "it's false by default, but set in the contest
     config. If the user changes it, that goes into the contest config in
     the database. So it never actually gets written to the json file?
     Same for all contest parameters including vhf enabled."

     THIS GROUP'S OWN CONSTRUCTOR ALREADY ADMITTED THE PROBLEM: "FCONTEST
     overwrites all three the moment a contest loads." So the copy in
     settings\tr4w.json was never the value in force -- it was a value
     that got overwritten seconds later, which is harmless until it is
     written BACK. Preferences saves the whole settings object on every
     applied change, so loading a contest that enables WARC and then
     changing any unrelated setting made that contest's choice the
     station's default, permanently. In the old world the global was
     re-set per contest every time and nothing stuck.

     A contest-scoped group is EXCLUDED FROM THE JSON ENTIRELY (see
     TR4WSettings.ToJSON) and captured into the contest database with
     source 'contest' (see uLogStore.CaptureConfiguration). The contest is
     where it came from and the contest is where a change to it belongs.

     HF STAYS TRUE BY DEFAULT while the other two are False. The default
     is nearly unobservable -- FCONTEST assigns all three before anything
     reads them -- but "nearly" is the wrong thing to gamble a band plan
     on, and a False HF default would mean no HF bands at all in the
     window where it IS observable.
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
      class function IsContestScoped: boolean; override;
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

   (*
     THE PADDLE -- the operator's own key, as distinct from the keyer that
     sends messages.

     THREE OF THE FOUR DEFAULTS ARE LOAD-BEARING AND ONE IS A TRAP.

       PaddleSpeed 0 IS MEANINGFUL.  It does not mean "unset" and it is not
       the zero a record starts with: it means the paddle follows the keyboard
       speed.  uTestConfigDefaults pins it with the note "so nobody fixes it
       to a plausible 25 WPM", and that warning travels with it here.

       MonitorTone 0 is silence and PttHoldCount 0 drops PTT between
       characters, which on an amplifier is hot switching.  Neither is a
       compile error and neither announces itself.

     SWAP PADDLES IS IN THIS GROUP BUT NOT IN ITS NAME, so it carries an
     alias.  It belongs here -- it is a property of how the paddle is wired --
     and the legacy command reads SWAP PADDLES, subject last, which no
     property path produces.
   *)
   TPaddleSettings = class(TSettingsGroup)
   private
      FSwap: boolean;
      FSpeed: TPaddleSpeed;
      FMonitorTone: TPaddleMonitorTone;
      FPttHoldCount: TPaddlePttHoldCount;
   public
      constructor Create;
   published
      // Was Config.SwapPaddles. Answers to SWAP PADDLES -- see BuildCommandMap.
      property Swap: boolean read FSwap write FSwap;
      (* Was Config.PaddleSpeed.  ZERO MEANS FOLLOW THE KEYBOARD SPEED and is
        the default; it is not an unset value. *)
      property Speed: TPaddleSpeed read FSpeed write FSpeed;
      // Was Config.PaddleMonitorTone, in Hz.
      property MonitorTone: TPaddleMonitorTone read FMonitorTone write FMonitorTone;
      // Was Config.PaddlePTTHoldCount, in dit counts.
      property PttHoldCount: TPaddlePttHoldCount read FPttHoldCount write FPttHoldCount;
   end;

   (*
     CW -- BUT ONLY THE HALF THE SESSION DOES NOT MUTATE.

     THE CW COMMANDS SPLIT IN TWO, and uConfigValues already said so before
     this move: "THE SESSION MUTATES THEM... So the stored value is what the
     session STARTS with; a change made while operating is not written back.
     That was already true and simply undocumented."

     The five here are ordinary settings -- set them, they stay set.

     THE OTHER FIVE ARE DELIBERATELY LEFT IN CFGCA FOR NOW: CW ENABLE, CW TONE,
     FARNSWORTH ENABLE, FARNSWORTH SPEED and WEIGHT. Weight, FarnsworthEnable
     and FarnsworthSpeed are changed by CW-buffer control codes mid-message
     (LOGK1EA), and CWEnable and CWTone by live keystrokes. A published
     property is STREAMED, so moving them as they stand would silently start
     persisting a mid-contest adjustment -- turning "the speed I nudged for one
     message" into the speed the station starts with tomorrow. That is a
     behaviour change, not a migration.

     CW ENABLE already shows the shape the other four need: the configured
     value is Config.CWEnable and the live gate is the separate global
     CWEnabled, which Alt-K toggles and LogCfg mirrors after each config read.
     Splitting the remaining four the same way is a decision for NY4I, and it
     is why this batch is five rather than ten. WEIGHT additionally needs a
     real-typed property with x10-scaled bounds, which the model has no support
     for yet.

     NO HOOKS ON ANY OF THE FIVE -- crP, crA, crJ and crC are all zero -- so
     these are plain field writes, as TPttSettings is.
   *)
   TCwSettings = class(TSettingsGroup)
   private
      FAllMessagesChainable: boolean;
      FSpeedFromDatabase: boolean;
      FKeypadMemories: boolean;
      FSendCompleteFourLetterCall: boolean;
      FTuneWithDits: boolean;
      FShortIntegers: boolean;
      FStartSendingNowKey: Char;
      FShort0: AnsiChar;
      FShort1: AnsiChar;
      FShort2: AnsiChar;
      FShort9: AnsiChar;
      FLeadingZeroCharacter: AnsiChar;
      FIncludeFKeyNumber: boolean;
      FQuestionMarkChar: Char;
      FSlashMarkChar: Char;
      FSpeedIncrement: TCwSpeedIncrement;
      FDitDahRatio: TCwDitDahRatio;
      FLeadingZeros: TCwLeadingZeros;
      FAutoSendCharacterCount: TAutoSendCharacterCount;
      procedure SetAutoSendCharacterCount(aValue: TAutoSendCharacterCount);
   public
      constructor Create;
   published
      (* Was Config.CodeSpeedIncrement -- how many words a minute the speed
        keys move. CW SPEED INCREMENT, which derives exactly. *)
      property SpeedIncrement: TCwSpeedIncrement
         read FSpeedIncrement write FSpeedIncrement;
      (* Was Config.tDitDahRatio -- the dit-to-dah length ratio in TENTHS,
        so 3 is the textbook 1:3. LOGK1EA multiplies by 10 to get the element
        length, which is where the tenths live. Serial keying only: a
        WinKeyer, a YCCC box or CW-by-CAT keep their own timing.

        DIT DAH RATIO, aliased -- the command name carries no CW. *)
      property DitDahRatio: TCwDitDahRatio
         read FDitDahRatio write FDitDahRatio;
      (* Was Config.LeadingZeros -- how many digits a sent serial number is
        padded to. LEADING ZEROS, aliased for the same reason. *)
      property LeadingZeros: TCwLeadingZeros
         read FLeadingZeros write FLeadingZeros;
      (* Was the global AutoSendCharacterCount in logwind.

        HOW MANY CHARACTERS OF A CALLSIGN TRIGGER AUTOMATIC SENDING, and 0
        means the feature is off. AUTO SEND CHARACTER COUNT, aliased.

        THE SETTER IS WHY THIS ONE NEEDED THINKING ABOUT. It was
        CommandsProcArray[4], UpadateAutoSend, which DERIVES AutoSendEnable
        from it -- and that flag is live state the operator also toggles from
        the keyboard, so it cannot just be replaced by asking the count. The
        derivation runs whenever the count changes, and nothing else touches
        the flag. *)
      property AutoSendCharacterCount: TAutoSendCharacterCount
         read FAutoSendCharacterCount write SetAutoSendCharacterCount;
      // Was Config.AllCWMessagesChainable. ALL CW MESSAGES CHAINABLE.
      property AllMessagesChainable: boolean
         read FAllMessagesChainable write FAllMessagesChainable;
      (* Was Config.CWSpeedFromDataBase, and the ONE name in this group that
        derives exactly: CW SPEED FROM DATABASE. *)
      property SpeedFromDatabase: boolean
         read FSpeedFromDatabase write FSpeedFromDatabase;
      // Was Config.KeypadCWMemories. KEYPAD CW MEMORIES.
      property KeypadMemories: boolean
         read FKeypadMemories write FKeypadMemories;
      // Was Config.SendCompleteFourLetterCall.
      property SendCompleteFourLetterCall: boolean
         read FSendCompleteFourLetterCall write FSendCompleteFourLetterCall;
      (* Was Config.TuneWithDits. uCWKeyerCPU records that the CPU keyer has no
        tune, so this currently reaches no reader -- it is migrated as a
        setting rather than withdrawn, because withdrawing a command an
        operator has in a .cfg is a separate decision. *)
      property TuneWithDits: boolean read FTuneWithDits write FTuneWithDits;
      (* Was the global ShortIntegers in logstuff.pas -- send a serial
        number's zeros and ones as T and N, the CW abbreviations. LogSend is
        the one reader and it is CW-only, which is why this is here and not
        in the log group the command name suggests. *)
      property ShortIntegers: boolean read FShortIntegers write FShortIntegers;
      (* Was the global StartSendingNowKey in logstuff.pas -- the key that
        makes the keyer start sending the call being typed.

        A Char, so WideChar in this tree, and that is a fix rather than a
        translation: the global was declared Char too, but CheckCommand's
        ctChar arm wrote ONE BYTE through a PAnsiChar into it. It worked only
        because the high byte happened to be zero from the initialiser.

        crA: 19 pointed at F_START_SENDING_NOW_KEY, whose whole body is a
        commented-out line and `Result := True`. There is no side effect to
        carry over, so this needs no setter -- see the hook table in uCFG,
        where the slot keeps its place holding nil. *)
      property StartSendingNowKey: Char
         read FStartSendingNowKey write FStartSendingNowKey;
      (* Was Config.LeadingZeroCharacter -- what is keyed in place of a
        serial number's leading zero. 'T' by default, the same cut-number
        idea as Short0 below. *)
      property LeadingZeroCharacter: AnsiChar
         read FLeadingZeroCharacter write FLeadingZeroCharacter;
      (* Was Config.IncludeFKeyNumber -- put the function key's number in
        its on-screen caption. *)
      property IncludeFKeyNumber: boolean
         read FIncludeFKeyNumber write FIncludeFKeyNumber;
      (* Was QuestionMarkChar in tree.pas -- which key sends a question
        mark, for a keyboard layout where '?' needs a modifier. *)
      property QuestionMarkChar: Char
         read FQuestionMarkChar write FQuestionMarkChar;
      // Was SlashMarkChar in tree.pas, the same idea for '/'.
      property SlashMarkChar: Char
         read FSlashMarkChar write FSlashMarkChar;
      (*
        THE CUT NUMBERS -- what is actually keyed for 0, 1, 2 and 9. An
        operator sending fast CW sends T for zero and N for nine, because the
        shorter character is easier to copy at speed.

        A STATION PREFERENCE, NOT A CONTEST PARAMETER, which is the one
        question worth answering before moving any setting: no contest
        assigns them -- neither fcontest.pas nor LogCfg mentions them at all
        -- and the settings store had already filed them under 'cw.ctrlj.'.
        They are how this operator's fist sounds, and that is the same in
        every contest.

        AnsiChar, NOT Char, DELIBERATELY. The globals were AnsiChar and the
        only consumer writes one straight into a ShortString element
        (LogSend). tr4w.inc sets UnicodeStrings, so a Char here would be two
        bytes -- the latent width bug TPossibleCallSettings documents -- and
        nothing these key is outside ASCII.

        THE DEFAULTS ARE THE DIGITS THEMSELVES, so nothing is cut until the
        operator says so. LogCW declared T, A, 2 and N; cfgdef.pas then
        overwrote three of them with '0', '1' and '9' at every startup, so
        the LIVE defaults were the digits and the declarations were dead
        text. Short2 was never in that block and its declared '2' is already
        a digit, so all four now agree and none of them changes.
      *)
      property Short0: AnsiChar read FShort0 write FShort0;
      property Short1: AnsiChar read FShort1 write FShort1;
      property Short2: AnsiChar read FShort2 write FShort2;
      property Short9: AnsiChar read FShort9 write FShort9;
   end;

   (*
     AUTOMATIC SEARCH AND POUNCE -- noticing that the operator has tuned.

     TWO SETTINGS, TWO ALIASES, and the reason is a single character: the
     commands are spelled AUTO S&P ENABLE and AUTO S&P ENABLE SENSITIVITY,
     and no Pascal identifier yields an ampersand. This is the one case
     where an alias is not a naming accident but an alphabet limit.

     NEITHER IS CONTEST STATE, which is what made them safe to move while
     the neighbouring AUTO DUPE ENABLE pair was not: nothing outside the
     config reader writes these, whereas fcontest.pas assigns
     AutoDupeEnableCQ and AutoDupeEnableSandP for six different contests.
     (That pair HAS since moved -- see TAutoDupeSettings. What changed is
     not the reading above but IsContestScoped: being contest state is a
     reason to keep a setting OUT OF tr4w.json, which is now expressible,
     rather than a reason to leave it in the array.)

     No hooks -- crP, crA, crJ and crC are all zero.
   *)
   TAutoSapSettings = class(TSettingsGroup)
   private
      FEnable: boolean;
      FSensitivity: TAutoSapSensitivity;
   public
      constructor Create;
   published
      // Was the global AutoSAPEnable in logstuff.pas. AUTO S&P ENABLE.
      property Enable: boolean read FEnable write FEnable;
      (* Was AutoSAPEnableRate in logwind.pas, in Hz: uRadioPolling treats
        it as how far the VFO must move before the tuning counts as search
        and pounce. AUTO S&P ENABLE SENSITIVITY -- the legacy name keeps
        the word ENABLE in the middle, which no property path produces
        even before the ampersand. *)
      property Sensitivity: TAutoSapSensitivity read FSensitivity write FSensitivity;
   end;

   (*
     THE PARTIAL-CALL STRIP -- the candidates offered while a call is typed,
     and the three keys that walk and accept them.

     THREE OF THE FOUR NAMES DERIVE EXACTLY. Only the enable needs an
     alias, because the command is the PLURAL noun -- POSSIBLE CALLS --
     where every other member names the thing and then the attribute.

     AND MOVING THEM FIXES A LATENT WIDTH BUG. The globals are declared
     `Char`, and tr4w.inc sets {$MODESWITCH UnicodeStrings}, so a Char is
     TWO BYTES. CFGCA applied a ctChar row with

         PAnsiChar(CFGCA[i].crAddress)^ := CustomCMD[1];

     -- ONE byte, written into a two-byte variable. It worked only because
     the high byte starts at zero and nothing ever set it, which is luck
     rather than design and is exactly the Win32 artifact class this tree
     is removing. A typed property is assigned, not poked.

     No hooks -- crP, crA, crJ and crC are all zero.
   *)
   TPossibleCallSettings = class(TSettingsGroup)
   private
      FEnable: boolean;
      FAcceptKey: Char;
      FLeftKey: Char;
      FRightKey: Char;
   public
      constructor Create;
   published
      // Was Config.PossibleCallEnable. Answers to POSSIBLE CALLS.
      property Enable: boolean read FEnable write FEnable;
      // Was the global PossibleCallAcceptKey in logstuff.pas.
      property AcceptKey: Char read FAcceptKey write FAcceptKey;
      // Was PossibleCallLeftKey -- moves the selection left.
      property LeftKey: Char read FLeftKey write FLeftKey;
      // Was PossibleCallRightKey.
      property RightKey: Char read FRightKey write FRightKey;
   end;

   (*
     TWO RADIOS -- SO2R, and everything that only means something when a
     second radio is in the shack.

     EVERY NAME IN THIS GROUP NEEDS AN ALIAS, which is worth stating rather
     than hiding: SO2R predates any namespacing in TR4W, so not one of the
     seven commands carries a common leading word. The derivation puts the
     group first and these names have no group in them at all.

     THE ALTERNATIVES WERE WORSE. Seven one-property groups is the shape
     already rejected for the band classes. Publishing them on TR4WSettings
     itself would derive exactly -- a root property has no prefix -- but it
     makes the root a bag of ungrouped booleans, and a group is what a
     contest-scope marker, a change notification and a Preferences page all
     key off. The aliases are the legacy compatibility layer and they go
     when the legacy formats stop being read.

     ONE OF THE SEVEN CARRIES A HOOK. QSY INACTIVE RADIO had crP:1, the
     band map redraw -- see uSettingsEffects, which matches it by exact
     path rather than by group, because the other six repaint nothing.
   *)
   TSo2rSettings = class(TSettingsGroup)
   private
      FTwoRadioMode: boolean;
      FQsyInactiveRadio: boolean;
      FSkipActiveBand: boolean;
      FSwapPacketSpotRadios: boolean;
      FSwapRelaySense: boolean;
      FInBandLockout: boolean;
      FWaitForStrength: boolean;
      procedure SetQsyInactiveRadio(aValue: boolean);
   public
      constructor Create;
   published
      (* Was Config.TwoRadioMode. uConfigValues calls it "the sole mode
        knob" -- SINGLE RADIO MODE, its deprecated inverse, was withdrawn
        in the same commit that said so. *)
      property TwoRadioMode: boolean read FTwoRadioMode write FTwoRadioMode;
      (* Was Config.QSYInactiveRadio. THE ONLY ONE WITH A SIDE EFFECT: its
        row carried crP:1, so changing it repainted the band map. The setter
        raises that now, however the value was set -- which the hook could
        not, since it only ran when CheckCommand applied the row. *)
      property QsyInactiveRadio: boolean
         read FQsyInactiveRadio write SetQsyInactiveRadio;
      // Was Config.SkipActiveBand.
      property SkipActiveBand: boolean read FSkipActiveBand write FSkipActiveBand;
      // Was Config.SwapPacketSpotRadios.
      property SwapPacketSpotRadios: boolean
         read FSwapPacketSpotRadios write FSwapPacketSpotRadios;
      // Was Config.SwapRadioRelaySense -- SWAP RADIO RELAY SENSE.
      property SwapRelaySense: boolean read FSwapRelaySense write FSwapRelaySense;
      (* Was Config.InBandLock, and the command is IN BAND LOCKOUT -- the
        record field was the only place it was ever called a lock. *)
      property InBandLockout: boolean read FInBandLockout write FInBandLockout;
      // Was Config.WaitForStrength.
      property WaitForStrength: boolean read FWaitForStrength write FWaitForStrength;
   end;

   (*
     ALT-D -- calling a station on the OTHER radio without leaving the one
     you are on.

     TWO SETTINGS, TWO ALIASES, and the difference is one character: the
     commands are ALT-D BUFFER ENABLE and ALT-D CQ ENABLE, hyphenated, and
     no Pascal identifier yields a hyphen. Teaching the derivation about
     this one punctuation mark was rejected -- a rule bent for one group
     stops being a rule.
   *)
   TAltDSettings = class(TSettingsGroup)
   private
      FBufferEnable: boolean;
      FCqEnable: boolean;
   public
      constructor Create;
   published
      // Was Config.AltDBufferEnable. ALT-D BUFFER ENABLE.
      property BufferEnable: boolean read FBufferEnable write FBufferEnable;
      // Was Config.AltDCQEnable. ALT-D CQ ENABLE.
      property CqEnable: boolean read FCqEnable write FCqEnable;
   end;

   (*
     THE CALL WINDOW -- what the field where a callsign is typed does while
     it is being typed.

     ONE OF THE FIVE DERIVES EXACTLY -- CALL WINDOW SHOW ALL SPOTS -- which
     is one more than several groups before it and is worth noting only
     because it shows the derivation is not arbitrary: where the legacy
     name happens to lead with its subject, the rule produces it.

     PARTIAL CALLS ARE NOT POSSIBLE CALLS, and the two groups are next to
     each other in this file, so: a PARTIAL call is matched against the log
     and Super Check Partial as characters are typed; a POSSIBLE call is an
     entry in the strip of candidates that TPossibleCallSettings governs.
     Different features, similar names, and the commands have always
     distinguished them.

     No hooks on any of the five.
   *)
   TCallWindowSettings = class(TSettingsGroup)
   private
      FShowAllSpots: boolean;
      FLeaveCursor: boolean;
      FSpaceBarDupeCheck: boolean;
      FPartialCallEnable: boolean;
      FWildcardPartials: boolean;
      FCompleteCallsignMask: string;
      FCallsignUpdateEnable: boolean;
      FInsertMode: boolean;
      procedure SetInsertMode(aValue: boolean);
   public
      constructor Create;
   published
      (* Was Config.CallWindowShowAllSpots -- CALL WINDOW SHOW ALL SPOTS,
        which derives with no alias. *)
      property ShowAllSpots: boolean read FShowAllSpots write FShowAllSpots;
      // Was Config.LeaveCursorInCallWindow. LEAVE CURSOR IN CALL WINDOW.
      property LeaveCursor: boolean read FLeaveCursor write FLeaveCursor;
      // Was Config.SpaceBarDupeCheckEnable. SPACE BAR DUPE CHECK ENABLE.
      property SpaceBarDupeCheck: boolean
         read FSpaceBarDupeCheck write FSpaceBarDupeCheck;
      // Was Config.PartialCallEnable. PARTIAL CALL ENABLE.
      property PartialCallEnable: boolean
         read FPartialCallEnable write FPartialCallEnable;
      // Was Config.WildCardPartials. WILDCARD PARTIALS -- plural, as ever.
      property WildcardPartials: boolean
         read FWildcardPartials write FWildcardPartials;
      (* Was the global CompleteCallsignMask in VC.pas. COMPLETE CALLSIGN
        MASK, so it carries an alias.

        IT LIVES HERE BECAUSE IT COMPLETES WHAT IS TYPED IN THE CALL
        WINDOW: MainUnit.CompleteCallsign walks the mask and substitutes
        CallWindowString for the first '*', so a mask of '*/P' turns a
        typed K1ABC into K1ABC/P. An empty mask, or one with no '*', does
        nothing -- which is the ordinary state, and why that routine leads
        with two early exits. *)
      (*
        TAKE A CORRECTED CALLSIGN FROM THE EXCHANGE FIELD -- if the operator
        types the right call into the exchange, adopt it as the callsign.

        A STATION PREFERENCE, MOVED OUT OF THE CONTEST GROUP 2026-09-12 on
        NY4I's ruling, and the contest definitions no longer assign it.

        IT WAS CONTEST-SCOPED FOR A DEFENSIBLE REASON and the reason was not
        enough: FCONTEST set it for ARRL Sweepstakes alone, because the
        Sweepstakes exchange contains the callsign. But an operator who wants
        that behaviour wants it everywhere, and a contest-scoped setting made
        them ask for it once per contest.

        THE ASSIGNMENT HAD TO GO WITH THE MOVE, not merely be left alone. A
        station setting persists; a contest that raised it would have written
        the operator's own preference over, permanently, after one
        Sweepstakes. One setting, one writer.

        AND IT DEFAULTS TRUE NOW, which it never did before. NY4I, 2026-09-12:
        "I use that feature in many places. In fact, it was not the default but
        I would like it now to default to true." That is what makes dropping
        the Sweepstakes assignment cost nothing -- the contest was turning on
        something that is now on to begin with.
      *)
      property CallsignUpdateEnable: boolean
         read FCallsignUpdateEnable write FCallsignUpdateEnable;
      property CompleteCallsignMask: string
         read FCompleteCallsignMask write FCompleteCallsignMask;
      (* Was the global InsertMode in logstuff.pas -- whether typing in the
        entry fields inserts or overwrites. INSERT MODE names no window, so
        it carries an alias; it lives here because the call window is where
        it is observed and where the Insert key is pressed.

        crP: 8 WAS DisplayInsertMode, which repaints the INS/OVR panel, and
        the setter raises the change for uSettingsEffects to act on. That
        hook fired only when CheckCommand applied the row, which is why the
        Alt-menu toggle had to go the long way round through
        InvertBooleanCommand to get the panel repainted at all. *)
      property InsertMode: boolean read FInsertMode write SetInsertMode;
   end;

   (*
     CALLING CQ, and moving between CQ and search-and-pounce.

     THE DELAY IS MILLISECONDS, which the subrange states and the old row
     only implied: 500..10000. That matters because a DEAD ROUTINE in
     logsubs2 wrote SECONDS into the same global -- see the note on that
     deletion in this commit.

     All four are hook-free; the delay is written through Preferences by
     uAutoCQForm, which already goes through the settings path rather than
     at the value.
   *)
   TCqSettings = class(TSettingsGroup)
   private
      FAlwaysCallBlind: boolean;
      FAutoCallTerminate: boolean;
      FAutoReturnToMode: boolean;
      FEscapeExitsSearchAndPounce: boolean;
      FAutoDelay: TAutoCqDelay;
      FRandomMode: boolean;
   public
      constructor Create;
   published
      // Was Config.AlwaysCallBlindCQ. ALWAYS CALL BLIND CQ.
      property AlwaysCallBlind: boolean
         read FAlwaysCallBlind write FAlwaysCallBlind;
      // Was Config.AutoCallTerminate. AUTO CALL TERMINATE.
      property AutoCallTerminate: boolean
         read FAutoCallTerminate write FAutoCallTerminate;
      // Was Config.AutoReturnToCQMode. AUTO RETURN TO CQ MODE.
      property AutoReturnToMode: boolean
         read FAutoReturnToMode write FAutoReturnToMode;
      // Was Config.EscapeExitsSearchAndPounce.
      property EscapeExitsSearchAndPounce: boolean
         read FEscapeExitsSearchAndPounce write FEscapeExitsSearchAndPounce;
      (* Was the global AutoCQDelayTime in LogCW.pas, in MILLISECONDS.
        AUTO-CQ DELAY TIME, hyphenated, so it carries an alias. *)
      property AutoDelay: TAutoCqDelay read FAutoDelay write FAutoDelay;
      (* Was the global RandomCQMode in logstuff.pas -- alternate between the
        F1 and F2 CQ memories instead of always sending F1. The command puts
        the subject in the middle, RANDOM CQ MODE, so it carries an alias. *)
      property RandomMode: boolean read FRandomMode write FRandomMode;
   end;

   (*
     THE LOG -- entering a contact and changing one afterwards.

     ONE NAME DERIVES EXACTLY, LOG WITH SINGLE ENTER, because it happens to
     lead with the group's own word. The other three do not and carry
     aliases.

     THIS GROUP IS NOT THE LOG STORE. It is how the operator INTERACTS with
     the log; where the rows actually live is uLogStore and the SQLite
     database, which no setting here touches. Worth saying because 'Log' is
     a broad word and the next person adding to this file will have to
     decide whether their setting belongs here.

     No hooks on any of them.
   *)
   TLogSettings = class(TSettingsGroup)
   private
      FWithSingleEnter: boolean;
      FConfirmEditChanges: boolean;
      FCheckFileSize: boolean;
      FUpdateRestartFile: boolean;
      FFrequencyEnable: boolean;
      FColumnAutoSize: boolean;
      FRsSent: TLogRsSent;
      FRstSent: TLogRstSent;
      FLookForRstSent: boolean;
      FBackupFrequency: TBackupLogFrequency;
      FBeepEvery10Qsos: boolean;
      FDisabled: boolean;
      FShowFrequency: boolean;
      FDistanceMode: DistanceDisplayType;
      FDebugLevel: tLogLevels;
   public
      constructor Create;
   published
      (* Was Config.LogWithSingleEnter -- LOG WITH SINGLE ENTER, the one
        name in this group that needs no alias. *)
      property WithSingleEnter: boolean
         read FWithSingleEnter write FWithSingleEnter;
      // Was Config.ConfirmEditChanges. CONFIRM EDIT CHANGES.
      property ConfirmEditChanges: boolean
         read FConfirmEditChanges write FConfirmEditChanges;
      // Was Config.CheckLogFileSize. CHECK LOG FILE SIZE.
      property CheckFileSize: boolean read FCheckFileSize write FCheckFileSize;
      // Was Config.UpdateRestartFileEnable. UPDATE RESTART FILE ENABLE.
      property UpdateRestartFile: boolean
         read FUpdateRestartFile write FUpdateRestartFile;
      (* Was the global LogFrequencyEnable in VC.pas. LOG FREQUENCY ENABLE
        -- a second name that derives exactly, like WithSingleEnter above.

        NO LIVE READER IN THIS BUILD. The three that existed are in
        JCtrl1/JCTRL2, the deprecated Ctrl-J units, so the setting is
        carried faithfully rather than deleted: what reads it is a question
        for whoever restores frequency logging, not for a migration. *)
      property FrequencyEnable: boolean
         read FFrequencyEnable write FFrequencyEnable;
      (* Was the global ColumnAutoSize in VC.pas. COLUMN AUTOSIZE, one
        word and no LOG in it, so it carries an alias.

        THE LOG GRID'S COLUMN WIDTHS, from the received serial number
        rightwards: uLogGrid fits each of those columns to its content
        when this is on. *)
      property ColumnAutoSize: boolean
         read FColumnAutoSize write FColumnAutoSize;
      (* Was the global LogRSSent in logstuff.pas -- the phone report this
        station records as sent. LOG RS SENT derives exactly. *)
      property RsSent: TLogRsSent read FRsSent write FRsSent;
      // Was LogRSTSent. LOG RST SENT, and it derives exactly too.
      property RstSent: TLogRstSent read FRstSent write FRstSent;
      (* Was LookForRSTSent -- whether the exchange parser accepts a report
        in the received exchange. The command leads with the verb, so it
        carries an alias. *)
      property LookForRstSent: boolean
         read FLookForRstSent write FLookForRstSent;
      (* Was BackupLogFrequency -- write a backup every N QSOs, 0 for never.
        The command is BACKUP LOG FREQUENCY, which puts the group second. *)
      property BackupFrequency: TBackupLogFrequency
         read FBackupFrequency write FBackupFrequency;
      (* Was BeepEvery10QSOs. The digits are what stops this deriving: the
        rule splits at a capital following a lower-case letter and 10 is
        neither, so the derived name is BEEP EVERY10 QSOS. *)
      property BeepEvery10Qsos: boolean
         read FBeepEvery10Qsos write FBeepEvery10Qsos;
      (* Was the global NoLog -- refuse to log a QSO at all, for a station
        that is only demonstrating or checking. NAMED FOR WHAT IT DOES rather
        than translated: `if Settings.Log.Disabled` reads the way the code
        means, and the legacy NO LOG still reaches it by alias. *)
      property Disabled: boolean read FDisabled write FDisabled;
      (* Was tShowFrequencyinLog in postunit -- whether the frequency is
        written with each QSO on export. Defaults TRUE, and the golden
        corpus is what proves it: every reference carries a FREQ. *)
      property ShowFrequency: boolean
         read FShowFrequency write FShowFrequency;
      (* Was the global DistanceMode in loggrid -- the units the log's
        distance column is shown in, or NONE for no column at all.
        DISTANCE MODE, aliased. *)
      property DistanceMode: DistanceDisplayType
         read FDistanceMode write FDistanceMode;
      (* Was the global logLevels in VC -- how much detail reaches tr4w.log.

        DEBUG LOG LEVEL, aliased. The property holds the LEVEL; pushing it
        into Log4D is UpdateDebugLogLevel's job and every site that assigns
        this already calls it, which is why this needs no setter. *)
      property DebugLevel: tLogLevels read FDebugLevel write FDebugLevel;
   end;

   (*
     SAY HI -- greeting an operator by name when the rate is low enough to
     afford the extra characters.

     BOTH NAMES DERIVE EXACTLY AND NEITHER NEEDS AN ALIAS, which is the
     first group in this file where that is true of every member. It is not
     luck: both commands lead with their subject, which is what the
     derivation rule assumes and what most of TR4W's older names do not do.

     No hooks on either.
   *)
   TSayHiSettings = class(TSettingsGroup)
   private
      FEnable: boolean;
      FRateCutoff: TSayHiRateCutoff;
   public
      constructor Create;
   published
      // Was Config.SayHiEnable. SAY HI ENABLE.
      property Enable: boolean read FEnable write FEnable;
      (* Was Config.SayHiRateCutOff -- the note is the CASE: the record
        spelled it CutOff and the command has always been CUTOFF, so the
        property takes the command's spelling. Contacts per hour, below
        which the greeting is sent. *)
      property RateCutoff: TSayHiRateCutoff read FRateCutoff write FRateCutoff;
   end;

   (*
     THE STATION'S OWN FACTS -- the seventeen MY ... commands.

     THE GROUP IS CALLED My, AND THAT IS NOT A STYLE CHOICE. Sixteen of the
     seventeen legacy names derive EXACTLY from it -- MY CALL, MY GRID,
     MY ITU ZONE, MY POSTAL CODE -- where any other grouping (Station,
     Operator) would have needed an alias for every single one. The
     derivation puts the group first and these commands already do.
     Settings.My.Call reads oddly for a moment and then stops.

     STRINGS, NOT ShortStrings, AND THAT IS NOT A PREFERENCE -- IT IS THE
     ONLY OPTION. A ShortString property CANNOT BE PUBLISHED: FPC answers
     "This kind of property cannot be published", because its RTTI carries
     no writer for tkSString. Tried on 2026-09-12 precisely because the
     alternative looked cheaper, and it is not available.

     SO THE COST IS REAL AND IS PAID AT THE BOUNDARY. These globals are
     concatenated into Str40 exchange templates all over fcontest -- 58
     such assignments tree-wide -- and a UTF-16 value assigned to a
     ShortString is a narrowing conversion the build counts. The pattern
     is to build the whole expression as a string and UTF8Encode ONCE at
     the assignment: an AnsiString-family value assigned to a ShortString
     is not a narrowing conversion, and callsigns, zones and sections are
     ASCII by construction.

     MIGRATED IN BATCHES, and this is the first. The seventeen have 778
     references between them -- MY CALL alone has 154 -- so they arrive a
     few at a time with the build measured after each, rather than as one
     sweep whose failure mode is a day of unpicking.
   *)
   TMySettings = class(TSettingsGroup)
   private
      FFocNumber: string;
      FIota: string;
      FPark: string;
      FCheck: string;
      FPrec: string;
      FFdClass: string;
      FSection: string;
      FName: string;
      FPostalCode: string;
      FGrid: string;
      FZone: string;
      FZoneWasSet: boolean;
      FCountry: string;
      FCountryWasSet: boolean;
      FCall: string;
      FMainCallsign: string;
      FState: string;
      FItuZone: TMyItuZone;
      procedure SetCall(const aValue: string);
      procedure SetCountry(const aValue: string);
      procedure SetZone(const aValue: string);
   public
      constructor Create;
      (* DID THE OPERATOR STATE A ZONE, or is it ours to derive?

        NOT published, so it is not streamed and has no command name: it is
        a fact ABOUT the zone, not a second setting. FCONTEST asks it, and
        derives the zone from CTY.DAT when the answer is no -- which is why
        an empty string does not count as an answer. This replaces the
        global MyZoneIsSet, which was set by a hook in the config array and
        so was true only when a config FILE had applied the row; a value
        typed into Preferences left it false. *)
      property ZoneWasSet: boolean read FZoneWasSet;
      (* DID THE OPERATOR STATE A COUNTRY? Same rule and same reason as
        ZoneWasSet: FCONTEST derives country, continent and zone from the
        callsign, and an operator who has named one must not be overruled by
        the country file. NY4I, 2026-09-12: "the operator needs to be able
        to override zone and in fact any of the derived settings." *)
      property CountryWasSet: boolean read FCountryWasSet;
   published
      // Was the global MyFOCNumber in logwind.pas. MY FOC NUMBER.
      property FocNumber: string read FFocNumber write FFocNumber;
      (* Was MyIOTA in logstuff.pas, and IT HAS NO READER -- the global was
        declared, initialised to '' and used by nothing but its own config
        row. Migrated rather than withdrawn on NY4I's instruction
        (2026-09-12): "migrate my iota too. it is for future use." So the
        command keeps working, an operator's .cfg keeps being understood,
        and the value is waiting when an IOTA contest wants it. *)
      property Iota: string read FIota write FIota;
      (* Was MyPark in logwind.pas -- the POTA reference being activated.
        NormalizePOTAPark already took a string, so two of its readers lose
        a widening cast rather than gaining anything. *)
      property Park: string read FPark write FPark;
      (* Was MyCheck in logwind.pas -- the year first licensed, sent in
        Sweepstakes. A station fact that only one contest asks for. *)
      property Check: string read FCheck write FCheck;
      // Was MyPrec -- the Sweepstakes precedence letter.
      property Prec: string read FPrec write FPrec;
      (* Was MyFDClass -- the Field Day class, e.g. 2A. MY FD CLASS derives
        exactly: FdClass yields FD CLASS. *)
      property FdClass: string read FFdClass write FFdClass;
      (* Was MySection in logwind.pas -- the ARRL or RAC section, sent in
        Field Day, Sweepstakes and the section-based contests. *)
      property Section: string read FSection write FSection;
      (* Was MyName in logwind.pas -- the operator's name, sent in the QSO
        party and sprint exchanges and greeted by SAY HI. *)
      property Name: string read FName write FName;
      // Was MyPostalCode in logwind.pas. MY POSTAL CODE.
      property PostalCode: string read FPostalCode write FPostalCode;
      (* Was the global MyGrid in LOGGRID -- the operator's own Maidenhead
        locator, used for beam headings, for grid-square distance scoring,
        and as the sent exchange in the VHF and Makrothen contests.

        IT CARRIED THE WHOLE UNIT'S GRID VOCABULARY WITH IT. Every grid
        routine in LOGGRID took a GridString, so this value could not have
        been passed to any of them without narrowing; their parameters are
        native strings now, which cost nothing because every other caller
        passes a ShortString and widening is silent. *)
      property Grid: string read FGrid write FGrid;
      (* Was the global MyZone in LOGWIND -- the operator's CQ zone, as
        TEXT, because several contests send it with a leading zero and one
        (Russian DX) temporarily appends the oblast to it.

        IT IS ONE GLOBAL DOING TWO JOBS and that is not fixed here: the
        same value is sent as an ITU zone by the IARU contest, which is a
        different number. See the note above PostUnit.ZoneSentForThisContest
        and the header of uContestIARU; both are about the VALUE, not about
        where it is stored. *)
      property Zone: string read FZone write SetZone;
      (* Was the global MyCountry in LOGWIND -- the CTY.DAT PREFIX CODE for
        the operator's DXCC entity, 'K' for the United States (NY4I,
        2026-09-12). It is not a country name and not a callsign, which is
        why a value CTY.DAT cannot resolve to itself is REFUSED rather than
        stored -- see the check registered against this path in uCFG. *)
      property Country: string read FCountry write SetCountry;
      (* Was the global MyCall in LOGWIND -- the callsign being operated.

        IT IS NOT ALWAYS THE STATION'S OWN. NY4I, 2026-09-12: "while my
        station call is NY4I, there may be a contest where I want to operate
        it as a club call hence I might use W4AFC in just a specific
        contest." That already works and keeps working, because of the
        ORDER the sources are read in: this object is loaded from
        settings\tr4w.json before any contest file, and the contest .cfg --
        whose FIRST line must be MY CALL -- is read after it and wins. The
        station default is not touched by that, because nothing writes the
        settings file on exit; the contest's own callsign is captured into
        the contest database, where uLogStore already records it as
        contest-scoped.

        EVERYTHING DERIVED FROM IT IS OVERRIDABLE. Country, continent and
        zone are computed from this callsign only where the operator has
        not stated one -- see CountryWasSet and ZoneWasSet. *)
      property Call: string read FCall write SetCall;
      (* Was the global MainCallsign in VC.pas. MAIN CALLSIGN, so it
        carries an alias.

        IT IS NOT Call, AND THE TWO ARE DELIBERATELY SEPARATE. Call is the
        callsign being OPERATED and a contest .cfg overrides it -- the club
        call case. This is the station's own, remembered across contests:
        the New Contest dialog pre-fills its callsign box from here, and
        writes it back the first time it is empty. Nothing else reads it,
        which is why a contest overriding Call leaves it alone. *)
      property MainCallsign: string read FMainCallsign write FMainCallsign;
      (* Was the global MyState in LOGWIND. It is NOT a state: it is the
        contest-dependent catch-all the exchange sends where a US station
        sends its state -- a province, an oblast, a county, a serial number
        in a few contests, and a grid square in the VHF ones, where FCONTEST
        assigns the operator's grid straight into it.

        WHICH IS WHY IT ANSWERS TO TWO NAMES. 'MY QTH' and 'MY STATE' were
        two rows in the config array pointing at this one global, and both
        still resolve -- see AlsoKnownAs. Preferences shows ONE box, because
        two would let editing either silently change the other. *)
      property State: string read FState write FState;
      (* Was MyITUZone in VC.pas, and ZERO IS MEANINGFUL: it means "use the
        CTY.DAT default", which is why the row allowed 0 in a range whose
        real zones start at 1. Issue #930 added it so a station in a
        multi-zone country could override that default. *)
      property ItuZone: TMyItuZone read FItuZone write FItuZone;
   end;

   (*
     THE DVK -- the voice keyer that plays recorded messages.

     THREE OF ITS FIVE COMMANDS. DVK PATH and DVK RECORDER are still out,
     and the gap is deliberate: they are ctDirectory and ctFileName, which
     CheckCommand treats specially, and their readers take them as PAnsiChar
     through GetRealPath. Moving them is the PChar audit CLAUDE.md already
     owes, not a settings batch.

     DVK ENABLE WAS HELD BACK FOR A REASON THAT NO LONGER HOLDS, and the
     note that stood here said so: its crP:7 is the code-speed redraw, and
     honouring that from a setter means calling into LOGWIND, which
     uSettingsEffects may not assume has a window. The precedent arrived
     with INSERT MODE -- DisplayInsertMode asks `TR4WMainForm = nil` and
     returns, for exactly this reason. DisplayCodeSpeed does the same now.
   *)
   TDvkSettings = class(TSettingsGroup)
   private
      FEnable: boolean;
      FLocalizedMessagesEnable: boolean;
      FUseRecordedSigns: boolean;
      FMissingCallsignsFileEnable: boolean;
      FPath: string;
      FRecorder: string;
      procedure SetEnable(aValue: boolean);
   public
      constructor Create;
   published
      (*
        Was Config.DVKEnable. DVK ENABLE, which derives exactly.

        THE SETTER IS WHY THIS MIGRATED AT ALL. The code-speed panel shows
        'DVK ON', 'DVK OFF' or 'DVK Dis.' in phone mode, and until now only
        a config line repainted it -- LogCW's Alt-D toggle flipped the
        global directly and the panel kept whatever it last said. One
        spelling of the rule, so the two cannot disagree.
      *)
      property Enable: boolean read FEnable write SetEnable;
      (* Was Config.DVKLocalizedMessagesEnable. DVK LOCALIZED MESSAGES ENABLE,
        which derives exactly. *)
      property LocalizedMessagesEnable: boolean
         read FLocalizedMessagesEnable write FLocalizedMessagesEnable;
      (* Was Config.UseRecordedSigns -- whether a recorded callsign is played
        rather than spoken. The command is USE RECORDED SIGNS with no DVK in
        it, so it carries an alias. *)
      property UseRecordedSigns: boolean
         read FUseRecordedSigns write FUseRecordedSigns;
      (* Was tMissCallsFileEnable in logdvp.

        IT IS A DVK SETTING, WHICH THE COMMAND NAME HIDES. The file it
        controls is FULLCALLSIGNS\\MISSINGCALLSIGNS.TXT under the DVK
        path, and it records the callsigns for which no recording exists
        -- so an operator can go and record them. Nothing about it is
        general file handling, which is where the settings store filed
        it. *)
      property MissingCallsignsFileEnable: boolean
         read FMissingCallsignsFileEnable write FMissingCallsignsFileEnable;
      (* Was Config.DVKPath -- the folder the .WAV messages live in. DVK PATH
        derives exactly.

        A RELATIVE NAME IS LEGAL AND IS THE COMMON CASE: GetRealPath puts the
        program directory in front of anything with no backslash in it, which
        is why the value is not resolved here. *)
      property Path: string read FPath write FPath;
      (* Was Config.DVKRecorder -- the external program Alt-R hands a .WAV to
        for recording. DVK RECORDER derives exactly.

        EMPTY IS MEANINGFUL: uEditMessageForm opens the recorder settings
        rather than running nothing. *)
      property Recorder: string read FRecorder write FRecorder;
   end;

   (*
     THE UNKNOWN COUNTRY FILE -- a list of callsigns CTY.DAT could not place,
     written out so an operator can look for missed multipliers afterwards.

     NEITHER SETTING HAS A READER. Both globals are declared and never looked
     at: nothing in the tree generates this file. They are MIGRATED RATHER
     THAN WITHDRAWN, following NY4I's ruling on MY IOTA (2026-09-12, "migrate
     my iota too, it is for future use") -- the command keeps parsing, an
     existing .cfg keeps being understood, and the value is there when the
     feature is written.

     BOTH NAMES DERIVE EXACTLY, which is the second group in this file where
     that is true of every member.

     THE DEFAULT NAME COMES FROM THE HELP FILE, NOT FROM THE DECLARATION. The
     global's initialiser is commented out, so it ran as an empty string;
     commands_help_eng.ini says UNKNOWN.CTY and the description explains the
     file is "by default named UNKNOWN.CTY". With no reader, the live value
     was not behaviour -- it was an absence -- so the documented intent is the
     better answer here, where for a setting that IS read the live declaration
     would win. That distinction has come up three times now and is worth
     stating rather than re-deciding.
   *)
   TUnknownCountryFileSettings = class(TSettingsGroup)
   private
      FEnable: boolean;
      FName: string;
   public
      constructor Create;
   published
      // Was Config.UnknownCountryFileEnable.
      property Enable: boolean read FEnable write FEnable;
      // Was the global UnknownCountryFileName in logwind.pas.
      property Name: string read FName write FName;
   end;


   (*
     ========================================================================
     THE CONTEST'S OWN RULES -- the five groups below are the CONTEST'S, not
     the station's, and every one of them overrides IsContestScoped.
     ========================================================================

     THE TEST APPLIED TO EVERY ROW, one at a time: would this value be
     different for a different contest at the same station?  For all
     twenty-one it is, and for most of them the EVIDENCE IS IN THE PROGRAM
     rather than in an opinion -- fcontest.pas assigns them as a contest
     loads, from ContestsBooleanArray or from a per-contest arm:

         QSOByBand, QSOByMode, MultByBand, MultByMode and
         CountDomesticCountries come straight out of the contest's bit mask;
         AutoDupeEnableCQ/SandP, ExchangeMemoryEnable, SprintQSYRule,
         DigitalModeEnable, MultipleBandsEnabled, MultipleModesEnabled,
         CallsignUpdateEnable and QTCsEnabled are each set by name for the
         contests whose rules require them.

     The three that fcontest does NOT compute -- MULT SHEET AUTO RESET, QTC
     MINUTES and the four QSO POINTS values -- carried crJ: 2, the table's
     mark for "displayed, not editable: a contest sets this".  And a shipped
     contest file proves it for the rest: target\dom\Idaho QSO Party.cfg
     sets DOMESTIC FILENAME, MULT BY BAND, MULT BY MODE, MULTIPLE BANDS and
     MULTIPLE MODES in five consecutive lines.

     WHAT CONTEST-SCOPED MEANS HERE, and why it is the whole point of moving
     these: a contest-scoped group is EXCLUDED from settings\tr4w.json
     (TR4WSettings.ToJSON) and captured into the contest database instead
     (uLogStore.CaptureConfiguration).  Without that, Preferences -- which
     saves the whole settings object on every applied change -- would make
     whichever contest was last loaded the station's permanent default.
     That is not a risk being guessed at; it is the measured defect the band
     enables had, and TBandSettings' header records it.  Here it would mean
     a sprint's QSY rule, or a QSO worth two points, following the operator
     into next weekend's contest.

     THE COMMAND NAMES ARE FLAT AND THE PATHS ARE NOT, which is where the
     aliases come from.  Mult, Qso and Qtc were chosen as group names for
     exactly that reason: 'Mult.ByBand' derives MULT BY BAND on its own, and
     twelve of the twenty-one names need no exception at all.  The eight in
     TContestSettings do, because TR4W spells them with no shared first word
     to group them by -- DOMESTIC FILENAME and SPRINT QSY RULE have nothing
     in common but the contest they describe -- and AUTO DUPE ENABLE S AND P
     makes nine, for an alphabet reason given at its own group.
   *)
   TQsoSettings = class(TSettingsGroup)
   private
      FByBand: boolean;
      FByMode: boolean;
      FPointsDomesticCw: TQsoPoints;
      FPointsDomesticPhone: TQsoPoints;
      FPointsDxCw: TQsoPoints;
      FPointsDxPhone: TQsoPoints;
   public
      constructor Create;
      class function IsContestScoped: boolean; override;
   published
      (* Was QSOByBand in logdupe.pas -- whether the same station may be
        worked again on another band.  QSO BY BAND derives exactly. *)
      property ByBand: boolean read FByBand write FByBand;
      // Was QSOByMode in logdupe.pas. QSO BY MODE.
      property ByMode: boolean read FByMode write FByMode;
      (* THE FOUR FIXED POINT VALUES, was QSOPointsDomesticCW and its three
        companions in logwind.pas.  -1 means the contest states no fixed
        value and the scoring method decides; see TQsoPoints.

        They were already half out of the array -- registered in
        uSettingsDeclarations through a getter/setter pair over the globals
        because the row could not declare their range.  This is the rest of
        that move. *)
      property PointsDomesticCw: TQsoPoints
         read FPointsDomesticCw write FPointsDomesticCw;
      property PointsDomesticPhone: TQsoPoints
         read FPointsDomesticPhone write FPointsDomesticPhone;
      property PointsDxCw: TQsoPoints read FPointsDxCw write FPointsDxCw;
      property PointsDxPhone: TQsoPoints read FPointsDxPhone write FPointsDxPhone;
   end;

   (*
     MULTIPLIERS -- how this contest counts them.

     ALL THREE NAMES DERIVE EXACTLY.  MULT SHEET AUTO RESET is the odd
     member: nothing computes it, its single reader gates on the multiplier
     sheet's own tAutoReset flag, and it reaches the program only from a
     contest file.  It is here rather than in a display group because crJ: 2
     says the same thing its one reader does -- it is a property of the
     contest being run, not of the operator's screen.
   *)
   TMultSettings = class(TSettingsGroup)
   private
      FByBand: boolean;
      FByMode: boolean;
      FSheetAutoReset: boolean;
   public
      constructor Create;
      class function IsContestScoped: boolean; override;
   published
      // Was MultByBand in logdupe.pas. MULT BY BAND.
      property ByBand: boolean read FByBand write FByBand;
      // Was MultByMode in logdupe.pas. MULT BY MODE.
      property ByMode: boolean read FByMode write FByMode;
      // Was MultReset in logdupe.pas. MULT SHEET AUTO RESET.
      property SheetAutoReset: boolean read FSheetAutoReset write FSheetAutoReset;
   end;

   (*
     QTCs -- the traffic exchanged in the WAE contests, and nowhere else.

     BOTH NAMES DERIVE EXACTLY.  Enable is what fcontest sets for WAEDC;
     Minutes is a BOOLEAN despite its name -- it chooses whether the QTC
     serial is sent with the minutes of the hour appended -- and its row
     said crType: ctBoolean, so the type here is not a narrowing of an
     integer.
   *)
   TQtcSettings = class(TSettingsGroup)
   private
      FEnable: boolean;
      FMinutes: boolean;
      FExtraSpace: boolean;
      FQrs: boolean;
   public
      constructor Create;
      class function IsContestScoped: boolean; override;
   published
      // Was QTCsEnabled in logwind.pas. QTC ENABLE.
      property Enable: boolean read FEnable write FEnable;
      // Was QTCMinutes in logwind.pas. QTC MINUTES.
      property Minutes: boolean read FMinutes write FMinutes;
      (* Was QTCExtraSpace in logwae.pas -- whether the QTC line is sent
        with wider spacing. QTC EXTRA SPACE derives exactly. *)
      property ExtraSpace: boolean read FExtraSpace write FExtraSpace;
      (* Was QTCQRS -- send the QTC slower than the rest. QTC QRS derives
        exactly too, which is why this group needs no alias at all. *)
      property Qrs: boolean read FQrs write FQrs;
   end;

   (*
     AUTOMATIC DUPE CHECKING, separately for CQ and for search and pounce.

     THE PAIR TAutoSapSettings' HEADER DELIBERATELY LEFT BEHIND.  It says so:
     "NEITHER IS CONTEST STATE, which is what made them safe to move while
     the neighbouring AUTO DUPE ENABLE pair was not: nothing outside the
     config reader writes these, whereas fcontest.pas assigns
     AutoDupeEnableCQ and AutoDupeEnableSandP for six different contests."
     That was the right call at the time and it is what IsContestScoped
     exists to answer -- the objection was never that the values could not
     be properties, it was that streaming them into tr4w.json would make one
     contest's rule the station's default.  A contest-scoped group is not
     streamed.

     ENABLE S AND P CANNOT DERIVE.  'EnableSAndP' gives ENABLE SAND P,
     because a capital that follows a capital does not start a word -- and
     it should not, or UDPPort would be U D P PORT.  So one alias.
   *)
   TAutoDupeSettings = class(TSettingsGroup)
   private
      FEnableCq: boolean;
      FEnableSAndP: boolean;
   public
      constructor Create;
      class function IsContestScoped: boolean; override;
   published
      // Was AutoDupeEnableCQ in logdupe.pas. AUTO DUPE ENABLE CQ.
      property EnableCq: boolean read FEnableCq write FEnableCq;
      (* Was AutoDupeEnableSandP in logdupe.pas.  Answers to
        AUTO DUPE ENABLE S AND P -- see BuildCommandMap. *)
      property EnableSAndP: boolean read FEnableSAndP write FEnableSAndP;
   end;

   (*
     THE REST OF THE CONTEST'S RULES -- the eight whose legacy names share no
     first word, so each carries an alias.

     THE DOMESTIC FILE IS THE ONE WITH TEETH.  It was a FileNameType -- a
     MAX_PATH array of AnsiChar -- appended to with pointer arithmetic in
     two units, and the bound it needed was the array's.  A string has no
     bound to get wrong.  The two sites that built it are ordinary
     concatenation now; see fcontest.pas and LogCfg.pas.
   *)
   (*
     THIS POSITION'S IDENTITY ON A MULTI-OP NETWORK.

     BOTH NAMES DERIVE EXACTLY, and the group exists because they share a
     subject rather than to make them derive: COMPUTER ID and COMPUTER NAME
     are what an operator has always typed.

     THE ID IS LOAD-BEARING AND IS NOT A LABEL. TR4WServer indexes station
     status BY THE LETTER -- uNet turns it into StatusArray[Ord(id) - Ord('A')
     + 1] -- so two positions sharing one letter overwrite each other's row,
     which is what the "computer ID already in use" message is about. That is
     why the row was ctAlphaChar: A..Z, refused outright, rather than any
     character. The rule survives the move as a registered value check; see
     RegisterSettingValueCheck and uCFG's registration of it.

     #0 IS THE UNSET VALUE AND HAS TO STAY ONE. MainUnit asks
     `not (Id in ['A'..'Z'])` before opening the network window and prompts
     for the setting; a plausible default of 'A' would silently make every
     un-configured station claim the first slot.

     NEITHER IS BROADCAST. Both rows carried crNetwork: 0, which is the one
     sensible answer for a setting whose entire purpose is to be different at
     each position.
   *)
   TComputerSettings = class(TSettingsGroup)
   private
      FId: AnsiChar;
      FName: string;
      procedure SetName(const aValue: string);
   public
      constructor Create;
   published
      // Was the global ComputerID in logstuff.pas. COMPUTER ID.
      property Id: AnsiChar read FId write FId;
      (* Was ComputerName, a Str10. COMPUTER NAME.

        crP: 6 WAS SetComputerName, which tells the other positions the name
        changed, so the setter raises the change and uSettingsEffects sends
        it. The old hook ran only from Preferences. *)
      property Name: string read FName write SetName;
   end;

   (*
     THE ROTATOR BRIDGE -- PstRotator, reached over UDP.

     TWO ALIASES FOR ONE REASON: the commands spell the product's name as a
     single word, PSTROTATOR, and no identifier can produce that without
     making the group PstRotator and the derived names PST ROTATOR .... The
     group is named for the JOB rather than the product, because a second
     rotator bridge would belong in it.

     uRotatorControl is the only reader and already copies both into its own
     live record, so nothing here is read on a hot path.
   *)
   TRotatorSettings = class(TSettingsGroup)
   private
      FRotatorType: string;
      FIpAddress: string;
      FUdpPort: TRotatorUdpPort;
   public
      constructor Create;
   published
      (*
        WHICH ROTATOR, AS A TOKEN -- 'NONE', 'DCU1', 'ORION', 'YAESU',
        'ALFA SPID', 'PSTROTATOR'. Was the global ActiveRotatorType.

        A STRING, AND THE ENUM STAYS WITH THE SUBSYSTEM, for the reason
        ExternalLogger.LoggerType is a string: the rotator is a subsystem and
        its taxonomy supports the factory, not the settings model. The
        rotator registry already keyed its drivers by string id, so the
        legacy seed wanted this spelling anyway and used to derive it from
        the enum.

        ROTATOR TYPE, aliased.
      *)
      property RotatorType: string read FRotatorType write FRotatorType;
      // Was the global PSTRotatorIPAddress in logstuff.pas.
      property IpAddress: string read FIpAddress write FIpAddress;
      // Was PSTRotatorUDPPort.
      property UdpPort: TRotatorUdpPort read FUdpPort write FUdpPort;
   end;

   (*
     THE DUPE SHEET -- the window listing calls already worked.

     ONE DERIVES AND ONE DOES NOT. DUPE SHEET AUTO RESET derives exactly;
     AUTO DISPLAY DUPE QSO buries the subject in the middle, which no
     property path can do.

     AUTO RESET DEFAULTS TRUE, and that is not the zero a record starts
     with: logstuff declared `Sheet: DupeAndMultSheet = (tAutoReset: True)`,
     and that typed constant went with the field. Losing the True would
     leave a stale dupe sheet across a band change with nothing to say why.

     DupeSheetEnable STAYS IN THE RECORD. It is not a config command -- no
     CFGCA row names it -- so it is not a setting and moving it would be a
     different change.
   *)
   TDupeSheetSettings = class(TSettingsGroup)
   private
      FAutoReset: boolean;
      FAutoDisplayQso: boolean;
   public
      constructor Create;
   published
      // Was Sheet.tAutoReset in logstuff.pas. DUPE SHEET AUTO RESET.
      property AutoReset: boolean read FAutoReset write FAutoReset;
      // Was the global AutoDisplayDupeQSO. AUTO DISPLAY DUPE QSO.
      property AutoDisplayQso: boolean
         read FAutoDisplayQso write FAutoDisplayQso;
   end;

   (*
     THE COUNTRY DATABASE. One setting, the name of the CTY.DAT file, and
     Country.InformationFile derives COUNTRY INFORMATION FILE exactly --
     the same reason TSpotCollectorSettings is a group of one.

     IT HAS NO READER. The global is declared and nothing looks at it; the
     country file is opened by name elsewhere. Migrated rather than
     withdrawn, following the ruling on MY IOTA and on the unknown country
     file: the command keeps parsing and an existing .cfg keeps being
     understood.

     NOT ctFileName. The row is ctString, so nothing here inherits the open
     question about what a path setting validates.
   *)
   TCountrySettings = class(TSettingsGroup)
   private
      FInformationFile: string;
      FUpdateCheckOnStartup: boolean;
   public
      constructor Create;
   published
      // Was the global CountryInformationFile in logstuff.pas.
      property InformationFile: string
         read FInformationFile write FInformationFile;
      (* Was CTYUpdateCheckOnStartup in uCFG -- ask tr4w.net whether a
        newer CTY.DAT exists, once, at startup. *)
      property UpdateCheckOnStartup: boolean
         read FUpdateCheckOnStartup write FUpdateCheckOnStartup;
   end;

   (*
     THE GRID MAP. One setting -- the four-character square at the centre of
     the map -- and GridMap.Center derives GRID MAP CENTER exactly.

     ITS ONE READER IS UNREACHABLE. MoveGridMap in logedit walks the centre
     square with the arrow keys and nothing calls it, and
     EditableLog.DisplayGridMap has an empty body. Migrated for the same
     reason as the country file above.
   *)
   TGridMapSettings = class(TSettingsGroup)
   private
      FRadiusOfEarth: double;
      FCenter: string;
   published
      // Was the global GridMapCenter in logstuff.pas, a GridString.
      property Center: string read FCenter write FCenter;
      (* Was RadiusOfEarth in loggrid.pas -- the radius the distance
        calculation uses, in kilometres, and zero means do not compute a
        distance at all.

        ITS BOUND IS A REGISTERED CHECK, NOT A SUBRANGE. A subrange is an
        ordinal type and this is a double, so the range that was crMin and
        crMax -- divided by ten, which is what the old ctReal arm did --
        is registered against the path by uCFG instead. *)
      property RadiusOfEarth: double
         read FRadiusOfEarth write FRadiusOfEarth;
   end;

   (*
     QSX -- a DX station listening on a frequency other than its own.
     Qsx.Enable derives QSX ENABLE, and logpack is the single reader: with
     it False, a spot's notes are never scanned for a listening frequency.
   *)
   TQsxSettings = class(TSettingsGroup)
   private
      FEnable: boolean;
   public
      constructor Create;
   published
      // Was the global QSXEnable in logstuff.pas.
      property Enable: boolean read FEnable write FEnable;
   end;

   (*
     SENDING A MESSAGE -- the memories, however they are keyed.

     MESSAGE ENABLE IS THE GATE FOR ALL OF THEM, CW and voice alike, which
     is why this is its own group rather than part of TCwSettings: MainUnit
     tests `Settings.Dvk.Enable and Settings.Message.Enable` in one breath.

     THE OTHER THREE ARE ALIASED, and all three for the same historical
     reason -- the names predate any grouping. DE ENABLE decides whether a
     call is sent as "DE <call>"; the two QSL keys fire a memory directly
     from the entry field.

     THE KEY NUMBERS ARE WHY QUICK QSL KEY 1 CANNOT DERIVE: the rule splits
     at a capital and a digit is not one, so Key1 stays welded to the word
     before it.

     BOTH KEYS ARE Char, hence WideChar here, and both were Char globals
     written one byte at a time through a PAnsiChar. See the note on
     Cw.StartSendingNowKey, which had the same defect.
   *)
   TMessageSettings = class(TSettingsGroup)
   private
      FEnable: boolean;
      FDeEnable: boolean;
      FQuickQslKey1: Char;
      FQuickQslKey2: Char;
      FAutoQslInterval: TAutoQslInterval;
      procedure SetAutoQslInterval(aValue: TAutoQslInterval);
   public
      constructor Create;
   published
      // Was the global MessageEnable in logstuff.pas. MESSAGE ENABLE.
      property Enable: boolean read FEnable write FEnable;
      // Was DEEnable.
      property DeEnable: boolean read FDeEnable write FDeEnable;
      // Was QuickQSLKey1.
      property QuickQslKey1: Char read FQuickQslKey1 write FQuickQslKey1;
      // Was QuickQSLKey2.
      property QuickQslKey2: Char read FQuickQslKey2 write FQuickQslKey2;
      (* Was the global AutoQSLInterval in logstuff -- send the QSL message
        automatically every N QSOs, and 0 switches it off.

        AUTO QSL INTERVAL, aliased.

        THE SETTER RE-SEEDS THE COUNTDOWN, which was F_AUTO_QSL_INTERVAL,
        crA: 6. AutoQSLCount is the live counter the logger decrements; this
        is the setting it reloads from. Two keystrokes adjust the interval on
        the fly and BOTH carried the re-seed by hand, which is two spellings
        of one rule -- there is one now. *)
      property AutoQslInterval: TAutoQslInterval
         read FAutoQslInterval write SetAutoQslInterval;
   end;

   (*
     THE CONTEST'S OWN PARAMETERS -- AND THIS GROUP IS CONTEST-SCOPED.

     BOTH ARE ASSIGNED BY FCONTEST WHEN A CONTEST LOADS, which is the exact
     signature TBandSettings records: QSO NUMBER BY BAND is set True for two
     VHF contests, INITIAL EXCHANGE OVERWRITE for four others, and NOTHING
     EVER SETS EITHER BACK. As station settings they would be written to
     settings\tr4w.json by the next unrelated Preferences save, and a VHF
     field day would permanently give a station per-band serial numbers.

     NEITHER IS A PREFERENCE THE STATION HOLDS. A different contest at the
     same station wants a different answer, which is the question NY4I's
     rule asks -- a contest parameter belongs in the contest config in the
     database and never in tr4w.json.

     WHY THEY ARE IN ONE GROUP DESPITE BEING UNRELATED FEATURES: the scope
     is a property of the GROUP, not of the property, so a contest-scoped
     setting has to live in a contest-scoped group. Both aliases exist
     because that group name necessarily leads the derived name with
     CONTEST.
   *)
   TContestSettings = class(TSettingsGroup)
   private
      FCountDomesticCountries: boolean;
      FDigitalModeEnable: boolean;
      FDomesticFilename: string;
      FExchangeMemoryEnable: boolean;
      FMultipleBands: boolean;
      FMultipleModes: boolean;
      FSprintQsyRule: boolean;
      FQsoNumberByBand: boolean;
      FInitialExchangeOverwrite: boolean;
      FContactsPerPage: TContactsPerPage;
      FMinitourDuration: TTourDuration;
      FLiteralDomesticQth: boolean;
      FCustomInitialExchangeString: string;
      FHamscoreEnable: boolean;
      FR150SMode: boolean;
      FRfoblMode: boolean;
   public
      constructor Create;
      class function IsContestScoped: boolean; override;
   published
      (* Was CountDomesticCountries in logdupe.pas -- whether domestic
        countries count as country multipliers.  COUNT DOMESTIC COUNTRIES. *)
      property CountDomesticCountries: boolean
         read FCountDomesticCountries write FCountDomesticCountries;
      (* Was DigitalModeEnable in logwind.pas -- whether Digital is a mode
        this contest has at all.  DIGITAL MODE ENABLE. *)
      property DigitalModeEnable: boolean
         read FDigitalModeEnable write FDigitalModeEnable;
      (* Was DomQTHDataFileName in logdupe.pas -- the .DOM file naming this
        contest's domestic multipliers.  DOMESTIC FILENAME.

        It holds a BARE NAME while a contest file is being read and a FULL
        PATH once LogCfg has resolved it, which is how it has always
        behaved; the resolution is still in LogCfg and is unchanged. *)
      property DomesticFilename: string
         read FDomesticFilename write FDomesticFilename;
      (* Was ExchangeMemoryEnable in logdupe.pas -- offer the exchange this
        station sent last time.  EXCHANGE MEMORY ENABLE. *)
      property ExchangeMemoryEnable: boolean
         read FExchangeMemoryEnable write FExchangeMemoryEnable;
      (* Was MultipleBandsEnabled in logwind.pas -- whether the contest is
        worked on more than one band.  MULTIPLE BANDS. *)
      property MultipleBands: boolean read FMultipleBands write FMultipleBands;
      (* Was MultipleModesEnabled in logwind.pas.  MULTIPLE MODES. *)
      property MultipleModes: boolean read FMultipleModes write FMultipleModes;
      (* Was SprintQSYRule in logwind.pas -- the sprint rule that a station
        calling CQ must move after a QSO.  SPRINT QSY RULE. *)
      property SprintQsyRule: boolean read FSprintQsyRule write FSprintQsyRule;
      // Was the global QSONumberByBand in logstuff.pas.
      property QsoNumberByBand: boolean
         read FQsoNumberByBand write FQsoNumberByBand;
      // Was InitialExchangeOverwrite {KK1L: 6.70}.
      property InitialExchangeOverwrite: boolean
         read FInitialExchangeOverwrite write FInitialExchangeOverwrite;
      (* THE FOUR BELOW ARE HERE BECAUSE FCONTEST ASSIGNS THEM PER
        CONTEST and nothing ever sets them back -- the same reason
        QSO NUMBER BY BAND and INITIAL EXCHANGE OVERWRITE are. A group
        that is contest-scoped is kept out of settings\tr4w.json and
        captured into the contest database instead, which is exactly
        what a value the contest chooses needs. *)
      (* Was ContactsPerPage in logwind -- how many QSOs a printed page
        holds. FCONTEST sets 40 for one contest. *)
      property ContactsPerPage: TContactsPerPage
         read FContactsPerPage write FContactsPerPage;
      (* Was TourDuration -- the minutes a minitour lasts, shown as a
        progress bar. FCONTEST sets 15 and 20 for two contests. *)
      property MinitourDuration: TTourDuration
         read FMinitourDuration write FMinitourDuration;
      (* Was LiteralDomesticQTH -- take the received domestic QTH as
        typed rather than resolving it against the .DOM file. FCONTEST
        sets it for the contests whose exchange is free text. *)
      property LiteralDomesticQth: boolean
         read FLiteralDomesticQth write FLiteralDomesticQth;
      (* Was CustomInitialExchangeString, a Str40 -- the exchange the
        editor offers when there is no history for a station. *)
      property CustomInitialExchangeString: string
         read FCustomInitialExchangeString
         write FCustomInitialExchangeString;
      (*
        POST LIVE SCORES FOR THIS CONTEST.

        THE CONTEST'S, NOT THE STATION'S (NY4I, 2026-09-12). Whether scores
        are posted is a decision per contest -- a club event yes, a casual
        weekend no -- while WHERE they are posted and AS WHOM do not change
        from one contest to the next. Those stay in Settings.Hamscore.

        THE SPLIT IS FORCED BY THE MECHANISM AS WELL AS BY THE MEANING: scope
        is a property of the whole GROUP, so a group cannot be half
        contest-scoped. Moving the one member is the only way to say this.
      *)
      property HamscoreEnable: boolean
         read FHamscoreEnable write FHamscoreEnable;
      (*
        Was CTY.ctyR150SMode -- a field of the country-database record.

        IT OVERLAYS AN EXTRA COUNTRY FILE. With it on, startup reads
        r150s.dat over CTY.DAT so the Russian oblast prefixes resolve the way
        the R150S award counts them; RfoblMode does the same with rfobl.dat.

        CONTEST-SCOPED, AND THAT IS A FIX RATHER THAN A FILING DECISION.
        FCONTEST turns them on for particular contests and NOTHING EVER TURNS
        THEM OFF, which is the exact signature that placed QSO NUMBER BY BAND
        in this group. As a station setting, one Russian contest left every
        later contest at that station resolving prefixes by an award's rules.
      *)
      property R150SMode: boolean read FR150SMode write FR150SMode;
      // Was CTY.ctyRFOblMode. See R150SMode.
      property RfoblMode: boolean read FRfoblMode write FRfoblMode;
   end;

   (*
     THE MAIN WINDOW'S FONT -- face, size and weight.

     ONE NAME DERIVES EXACTLY, FONT SIZE. The other two are TR4W's flat
     spellings, BOLD FONT and MAIN FONT, and carry aliases.

     ALL THREE NEED A RESTART and are registered saying so. That is not the
     usual answer for this model -- a setter normally applies its own side
     effect -- but the font is handed to every main-window element once, at
     CreateMainWindow, and nothing re-reads these afterwards. Claiming
     otherwise would be a lie the Preferences page repeats to the operator.

     THE COLOURS ARE NOT HERE and must not move here. Element colours have
     their own structured store -- the `colors` section of
     settings\tr4w.json, written by uRadioConfigStore -- and folding
     a font into it, or it into this, is a merge of two models rather
     than a migration of one.
   *)
   TFontSettings = class(TSettingsGroup)
   private
      FSize: TMainFontSize;
      FBold: boolean;
      FFace: string;
   public
      constructor Create;
   published
      (* Was the global FontSize in VC.pas. A STEP, NOT A POINT SIZE -- see
        TMainFontSize. FONT SIZE derives with no alias. *)
      property Size: TMainFontSize read FSize write FSize;
      // Was the global BoldFont in VC.pas. BOLD FONT.
      property Bold: boolean read FBold write FBold;
      // Was the global MainFontName in VC.pas, a Str31. MAIN FONT.
      property Face: string read FFace write FFace;
   end;

   (*
     THE STATIONS WINDOW -- the multi-op list of who is working whom.

     One setting, and the path derives its command exactly:
     Stations.CallsignsMask gives STATIONS CALLSIGNS MASK.
   *)
   TStationsSettings = class(TSettingsGroup)
   private
      FCallsignsMask: string;
      procedure SetCallsignsMask(const aValue: string);
   public
      constructor Create;
   published
      (* Was the global StationsCallsignsMask in VC.pas.

        A SUBSTRING FILTER, not a wildcard: uStations rejects a callsign
        the mask does not appear in, so an empty mask admits everything.

        THE SETTER IS THE OLD crP:12. That row pointed at
        SetStationsCallsignMask, which re-filters the list that is already
        on screen -- and it ran only when the config array applied the row,
        so the same edit made anywhere else left a stale window. The effect
        is raised in uSettingsEffects now, however the value arrives. *)
      property CallsignsMask: string
         read FCallsignsMask write SetCallsignsMask;
   end;

   (*
     THE REMAINING-MULTIPLIER WINDOWS.

     One setting, and it widens a column rather than adding text: with the
     domestic multiplier NAME shown, MainUnit gives the columns the prefix
     width instead of the base width.
   *)
   TRemainingMultsSettings = class(TSettingsGroup)
   private
      FShowDomesticName: boolean;
      FDisplayMode: RemainingMultDisplayModeType;
      procedure SetShowDomesticName(aValue: boolean);
      procedure SetDisplayMode(aValue: RemainingMultDisplayModeType);
   public
      constructor Create;
   published
      (* Was the global tShowDomesticMultiplierName in VC.pas. SHOW
        DOMESTIC MULTIPLIER NAME, so it carries an alias.

        THE SETTER IS THE OLD crP:9 -- UpdateRemainingMultsWindows, which
        rebuilds those windows at the new column width. Same story as the
        stations mask: the hook fired only for a config file, so a change
        made any other way left the columns as they were. *)
      property ShowDomesticName: boolean
         read FShowDomesticName write SetShowDomesticName;
      (* Was the global RemainingMultDisplayMode in logdom -- what happens to
        a multiplier once it is worked: nothing, erased from the list, or
        left in place and highlighted.

        REMAINING MULT DISPLAY MODE, aliased -- the command says MULT where
        the group says MULTS. Its row carried crP: 2, the remaining-mults
        rebuild, so the setter raises. *)
      property DisplayMode: RemainingMultDisplayModeType
         read FDisplayMode write SetDisplayMode;
   end;

   (*
     THE INITIAL EXCHANGE -- what TR4W offers before the other station
     sends anything.

     One setting today. The FILE it is read from, INITIAL EXCHANGE
     FILENAME, is still a CFGCA row: that row is ctFileName, and what a
     path setting has to validate is an open question rather than a
     mechanical move.
   *)
   TInitialExchangeSettings = class(TSettingsGroup)
   private
      FReverse: boolean;
   public
      constructor Create;
   published
      (* Was the global ReverseInitialEx in VC.pas. REVERSE INITIAL EX --
        the flat name puts the verb first, so it carries an alias.

        WHAT IT REVERSES is the ORDER OF TWO SOURCES, not the text: LOGEDIT
        normally computes an exchange and falls back to the callsigns list,
        and with this on it takes the callsigns list's answer instead. *)
      property Reverse: boolean read FReverse write FReverse;
   end;

   (*
     QZB -- the small random offset applied when tuning to a CW spot, so
     that everyone clicking the same spot does not land on the same
     frequency to the hertz.
   *)
   TQzbSettings = class(TSettingsGroup)
   private
      FRandomOffsetEnable: boolean;
   public
      constructor Create;
   published
      (* Was the global QZBRandomOffsetEnable in VC.pas. QZB RANDOM OFFSET
        ENABLE derives exactly, which is why the group is named for TR4W's
        own term rather than for the band map. *)
      property RandomOffsetEnable: boolean
         read FRandomOffsetEnable write FRandomOffsetEnable;
   end;

   (*
     SERIAL PORT ENUMERATION.

     NOTHING IN THIS BUILD READS THE ONE SETTING IN HERE, and that is
     recorded rather than fixed: it has no reader in the D7 tree either
     (checked 2026-09-12), so it is not a port regression. It is carried
     across faithfully because deleting a setting an operator can see in
     Preferences is a decision for NY4I, not a side effect of a migration.
   *)
   TSerialPortsSettings = class(TSettingsGroup)
   private
      FShowAll: boolean;
   public
      constructor Create;
   published
      (* Was the global tShowAllSerialPorts in VC.pas. SHOW ALL SERIAL
        PORTS.

        WHAT IT WAS MEANT TO DO, in the words of the comment that stood
        beside the global: the radio dialog's port list normally shows
        only the ports Windows is reporting, plus the one already
        configured even if absent; True was to list SERIAL 1..
        MAX_SERIAL_PORT instead, for ports that exist but do not
        enumerate -- com0com pairs, Bluetooth SPP that appears only when
        the device connects, or configuring a station before the hardware
        is plugged in. Default False: the filtered list is what an
        operator wants day to day.

        NOTHING IMPLEMENTS THAT. See the class comment above. *)
      property ShowAll: boolean read FShowAll write FShowAll;
   end;

   (*
     THE MESSAGE TEMPLATES -- what TR4W sends when it answers a call, confirms
     a contact, says it has worked somebody before, or repeats an exchange.
     CW and phone are separate settings, because a phone one names a WAV file
     rather than holding text.

     THESE ARE CONTEST PARAMETERS, NOT STATION PREFERENCES, which is why this
     is a group of its own rather than properties added to Cw and Cq. The
     evidence is not a judgement call:

       FCONTEST ASSIGNS THEM. fcontest.pas writes the CQ exchange, the S&P
       exchange, the QSL, QSO-before, quick-QSL and call-corrected messages
       for named contests, and LogCfg.tSetupExchangeNumbers fills whatever is
       still empty from that contest's own exchange shape. A value a contest
       computes belongs to the contest.

       A CONTEST .cfg CARRIES THEM, in a section called [Messages].
       test/corpus/winter_fd_2025_w4ta/log.cfg holds
       "REPEAT S&P CW EXCHANGE=3I WCF 3I WCF" -- that is Winter Field Day's
       class and section, and it means nothing in any other contest.

       THE SETTINGS STORE HAD ALREADY FILED THE QUICK QSL MESSAGES UNDER
       'contest.'. That taxonomy predates this work and agrees with it.

     ASKED THE OTHER WAY -- would this value differ for a different contest at
     the same station? -- 'TU \ TEST' against '73 \ WFD' settles it.

     SO IsContestScoped IS TRUE, and every one of them stays out of
     settings\tr4w.json. See TR4WSettings.SkipContestScoped.

     THE CUT NUMBERS WENT THE OTHER WAY and are on TCwSettings: SHORT 0/1/2/9
     say how this operator sends a digit, which no contest decides.

     EVERY NAME NEEDS AN ALIAS, AND THAT IS NOT EVIDENCE THE DERIVATION RULE
     IS WRONG. The legacy spellings put the MODE IN THE MIDDLE -- CQ CW
     EXCHANGE, QSL SSB MESSAGE -- and six contain an ampersand, which no
     Pascal identifier yields. No property path produces either shape. The
     grouping is the model's; the names are the legacy's, and they go when the
     legacy formats stop being read.

     EIGHT OF THEM ANSWER TO MORE THAN ONE NAME. TR4W has always accepted the
     mode-less spelling -- CQ EXCHANGE, QSL MESSAGE -- as a synonym for the CW
     one, as two CFGCA rows sharing a single crAddress. Both keep working,
     through AlsoKnownAs.

     NO HOOKS ON ANY OF THE THIRTY ROWS: crA, crP and crC are zero throughout,
     so these are plain field writes. And no bounds -- crMin and crMax are zero
     too. The storage was Str40 for CW and a full ShortString for phone, which
     is a capacity rather than a rule anybody stated, so nothing here restates
     it as a length limit.

     THE DEFAULTS DO NOT COME FROM THE DECLARATIONS, and believing they did
     would have been silent data loss. Every initialiser in LogCW.pas is
     commented out and so is every line cfgdef.pas has for them, which reads
     as "these start empty" -- and thirteen of the seventeen do not.
     uCFG.InitializeStrings holds the real table, and it runs at startup
     BEFORE any configuration file is read, so its values are the defaults an
     operator who has configured nothing actually gets: '} OK %' for a
     corrected call, 'TU \ TEST' for a QSL, and a WAV file name for each of
     the seven phone messages. Those thirteen entries move into the
     constructor below and leave that table with two rows.

     THE FOUR THAT REALLY ARE EMPTY are the CW exchanges -- CQ, CQ name
     known, S&P and repeat S&P. Empty is load-bearing for them:
     LogCfg.tSetupExchangeNumbers fills each one ONLY IF it is still empty,
     so a non-empty default would suppress the contest's own exchange.
   *)
   TMessageTemplateSettings = class(TSettingsGroup)
   private
      FCallOkNowCw: string;
      FCallOkNowSsb: string;
      FCqExchangeCw: string;
      FCqExchangeCwNameKnown: string;
      FCqExchangeSsb: string;
      FCqExchangeSsbNameKnown: string;
      FQslCw: string;
      FQslSsb: string;
      FQsoBeforeCw: string;
      FQsoBeforeSsb: string;
      FQuickQslCw1: string;
      FQuickQslCw2: string;
      FQuickQslSsb: string;
      FRepeatSpExchangeCw: string;
      FRepeatSpExchangeSsb: string;
      FSpExchangeCw: string;
      FSpExchangeSsb: string;
   public
      constructor Create;
      class function IsContestScoped: boolean; override;
   published
      (* Was the global CorrectedCallMessage in LogCW.pas -- sent after the
        operator has fixed a callsign. CALL OK NOW CW MESSAGE, and also CALL
        OK NOW MESSAGE. *)
      property CallOkNowCw: string read FCallOkNowCw write FCallOkNowCw;
      // Was CorrectedCallPhoneMessage. CALL OK NOW SSB MESSAGE.
      property CallOkNowSsb: string read FCallOkNowSsb write FCallOkNowSsb;
      (* Was CQExchange -- the exchange sent after answering a CQ, and the
        template uExchangeBuilder substitutes the serial number into. CQ CW
        EXCHANGE, and also CQ EXCHANGE. *)
      property CqExchangeCw: string read FCqExchangeCw write FCqExchangeCw;
      (* Was CQExchangeNameKnown -- the same exchange when the call is already
        in the name database and SAY HI is on. *)
      property CqExchangeCwNameKnown: string
         read FCqExchangeCwNameKnown write FCqExchangeCwNameKnown;
      // Was CQPhoneExchange. CQ SSB EXCHANGE.
      property CqExchangeSsb: string read FCqExchangeSsb write FCqExchangeSsb;
      // Was CQPhoneExchangeNameKnown. CQ SSB EXCHANGE NAME KNOWN.
      property CqExchangeSsbNameKnown: string
         read FCqExchangeSsbNameKnown write FCqExchangeSsbNameKnown;
      // Was QSLMessage. QSL CW MESSAGE, and also QSL MESSAGE.
      property QslCw: string read FQslCw write FQslCw;
      // Was QSLPhoneMessage. QSL SSB MESSAGE.
      property QslSsb: string read FQslSsb write FQslSsb;
      (* Was QSOBeforeMessage. QSO BEFORE CW MESSAGE, and also QSO BEFORE
        MESSAGE. *)
      property QsoBeforeCw: string read FQsoBeforeCw write FQsoBeforeCw;
      // Was QSOBeforePhoneMessage. QSO BEFORE SSB MESSAGE.
      property QsoBeforeSsb: string read FQsoBeforeSsb write FQsoBeforeSsb;
      (* Was QuickQSLMessage1, and THREE legacy commands write it: QUICK QSL
        CW MESSAGE, QUICK QSL CW MESSAGE1 and QUICK QSL MESSAGE 1 were three
        CFGCA rows over one global. All three are kept rather than a spelling
        chosen, because a .cfg or a multi-op peer may use any of them. *)
      property QuickQslCw1: string read FQuickQslCw1 write FQuickQslCw1;
      // Was QuickQSLMessage2. QUICK QSL MESSAGE 2, the second quick-QSL key.
      property QuickQslCw2: string read FQuickQslCw2 write FQuickQslCw2;
      // Was QuickQSLPhoneMessage. QUICK QSL SSB MESSAGE.
      property QuickQslSsb: string read FQuickQslSsb write FQuickQslSsb;
      (* Was RepeatSearchAndPounceExchange -- sent when the exchange has
        already gone once. REPEAT S&P CW EXCHANGE, and also REPEAT S&P
        EXCHANGE. *)
      property RepeatSpExchangeCw: string
         read FRepeatSpExchangeCw write FRepeatSpExchangeCw;
      // Was RepeatSearchAndPouncePhoneExchange. REPEAT S&P SSB EXCHANGE.
      property RepeatSpExchangeSsb: string
         read FRepeatSpExchangeSsb write FRepeatSpExchangeSsb;
      (* Was SearchAndPounceExchange. S&P CW EXCHANGE, and also S&P
        EXCHANGE. *)
      property SpExchangeCw: string read FSpExchangeCw write FSpExchangeCw;
      // Was SearchAndPouncePhoneExchange. S&P SSB EXCHANGE.
      property SpExchangeSsb: string read FSpExchangeSsb write FSpExchangeSsb;
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
      FPaddle: TPaddleSettings;
      FCw: TCwSettings;
      FAutoSap: TAutoSapSettings;
      FPossibleCall: TPossibleCallSettings;
      FSo2r: TSo2rSettings;
      FAltD: TAltDSettings;
      FCallWindow: TCallWindowSettings;
      FCq: TCqSettings;
      FLog: TLogSettings;
      FSayHi: TSayHiSettings;
      FMy: TMySettings;
      FDvk: TDvkSettings;
      FWsjtx: TWsjtxSettings;
      FMainWindow: TMainWindowSettings;
      FNetwork: TNetworkSettings;
      FOperating: TOperatingSettings;
      FScp: TScpSettings;
      FCluster: TClusterSettings;
      FScore: TScoreSettings;
      FTelnet: TTelnetSettings;
      FServer: TServerSettings;
      FHamscore: THamscoreSettings;
      FMp3: TMp3Settings;
      FHardware: THardwareSettings;
      FUnknownCountryFile: TUnknownCountryFileSettings;
      FQso: TQsoSettings;
      FMult: TMultSettings;
      FQtc: TQtcSettings;
      FAutoDupe: TAutoDupeSettings;
      FFont: TFontSettings;
      FStations: TStationsSettings;
      FRemainingMults: TRemainingMultsSettings;
      FInitialExchange: TInitialExchangeSettings;
      FQzb: TQzbSettings;
      FSerialPorts: TSerialPortsSettings;
      FComputer: TComputerSettings;
      FRotator: TRotatorSettings;
      FDupeSheet: TDupeSheetSettings;
      FCountry: TCountrySettings;
      FGridMap: TGridMapSettings;
      FQsx: TQsxSettings;
      FMessage: TMessageSettings;
      FContest: TContestSettings;
      FMessages: TMessageTemplateSettings;
      procedure BuildCommandMap;
      function PathForCommand(const aCommand: string): string;
      (* The streamer hook that keeps contest-scoped groups out of the
        file. A method rather than a plain procedure because it has to
        reach IsContestScoped through the property it is asked about. *)
      function PropertyForCommand(const aCommand: string): PPropInfo;
      (* Applied to the finished document and to the freshly loaded
        object, NOT inside the streamer. See ProtectSecretsInDocument. *)
      procedure ProtectSecretsInDocument(const aDoc: TJSONObject);
      procedure UnprotectSecretsAfterLoad;
      procedure SkipContestScoped(aSender: TObject; aObject: TObject;
                                  aInfo: PPropInfo; var aResult: TJSONData);
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
      (* Is this command's value the contest's rather than the station's?
        False for a name the model does not own at all, so a caller can ask
        about any command. *)
      function CommandIsContestScoped(const aCommand: string): boolean;
      function TrySetByCommand(const aCommand, aValue: string): boolean;
      (* IS THIS SETTING A CREDENTIAL? Asked by the multi-op sync before it
        sends anything, by the importer before it upper-cases a line, and by
        Preferences before it shows a value. *)
      (*
        THE VALUES A BOUNDED SETTING WILL ACCEPT, for a control that offers a
        choice rather than a text box.

        READ OUT OF THE SUBRANGE, so there is no list anywhere of which
        settings are enumerable -- the type says it, the way it says the
        bounds ClampToDeclaredRanges imposes.

        EMPTY MEANS "NO FIXED LIST", which a UI reads as "use a text box" --
        the same contract TSettingBase.AllowedValues documents. A plain
        Integer property carries the full 32-bit range and gets nothing, and
        so does anything wider than a drop-down should ever be.
      *)
      function AllowedValuesForCommand(const aCommand: string): TArray<string>;
      function CommandIsSecret(const aCommand: string): boolean;
      (* IS THIS SETTING'S CAPITALISATION THE OPERATOR'S? True for a secret
        too -- a password is case-sensitive by definition. *)
      function CommandIsCaseSensitive(const aCommand: string): boolean;
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
      property Paddle: TPaddleSettings read FPaddle;
      property Cw: TCwSettings read FCw;
      property AutoSap: TAutoSapSettings read FAutoSap;
      property PossibleCall: TPossibleCallSettings read FPossibleCall;
      property So2r: TSo2rSettings read FSo2r;
      property AltD: TAltDSettings read FAltD;
      property CallWindow: TCallWindowSettings read FCallWindow;
      property Cq: TCqSettings read FCq;
      property Log: TLogSettings read FLog;
      property SayHi: TSayHiSettings read FSayHi;
      property My: TMySettings read FMy;
      property Dvk: TDvkSettings read FDvk;
      property Wsjtx: TWsjtxSettings read FWsjtx;
      property MainWindow: TMainWindowSettings read FMainWindow;
      property Network: TNetworkSettings read FNetwork;
      property Operating: TOperatingSettings read FOperating;
      property Scp: TScpSettings read FScp;
      property Cluster: TClusterSettings read FCluster;
      property Score: TScoreSettings read FScore;
      property Telnet: TTelnetSettings read FTelnet;
      property Server: TServerSettings read FServer;
      property Hamscore: THamscoreSettings read FHamscore;
      property Mp3: TMp3Settings read FMp3;
      property Hardware: THardwareSettings read FHardware;
      property UnknownCountryFile: TUnknownCountryFileSettings
         read FUnknownCountryFile;
      property Qso: TQsoSettings read FQso;
      property Mult: TMultSettings read FMult;
      property Qtc: TQtcSettings read FQtc;
      property AutoDupe: TAutoDupeSettings read FAutoDupe;
      property Font: TFontSettings read FFont;
      property Stations: TStationsSettings read FStations;
      property RemainingMults: TRemainingMultsSettings read FRemainingMults;
      property InitialExchange: TInitialExchangeSettings read FInitialExchange;
      property Qzb: TQzbSettings read FQzb;
      property SerialPorts: TSerialPortsSettings read FSerialPorts;
      property Computer: TComputerSettings read FComputer;
      property Rotator: TRotatorSettings read FRotator;
      property DupeSheet: TDupeSheetSettings read FDupeSheet;
      property Country: TCountrySettings read FCountry;
      property GridMap: TGridMapSettings read FGridMap;
      property Qsx: TQsxSettings read FQsx;
      property Message: TMessageSettings read FMessage;
      (* CONTEST-SCOPED: excluded from settings\tr4w.json entirely. See
        TContestSettings, and TR4WSettings.SkipContestScoped. *)
      property Contest: TContestSettings read FContest;
      property Messages: TMessageTemplateSettings read FMessages;
   end;

(* THE ONE INSTANCE.  Created on first use so no unit's initialisation order
  can reach it before it exists, freed by FreeSettings at shutdown.

  A singleton is what NY4I described -- "callers just access Registry.variable
  name" -- and it is the honest shape for a program whose settings ARE global.
  What it replaces is not a smaller thing: it replaces ~500 loose globals with
  one object whose members are typed, grouped and named. *)

(* A VALUE ONLY ANOTHER UNIT CAN JUDGE.

  WHAT IT REPLACES. `MY COUNTRY` carried crA: 8, an AdditionalProcsArray
  hook whose False return REFUSED the config line -- the one row in the
  table whose hook was a validator rather than a side effect. Its rule is
  that the value must be a CTY.DAT prefix that resolves to itself, which is
  a question this unit cannot answer and must not learn to: putting the
  country file in the settings model's dependency graph would put it in the
  unit tests' too.

  A REGISTRY KEYED BY PROPERTY PATH, NOT A CASE IN TrySetByCommand. The
  association lives with the KNOWLEDGE -- uCFG registers it, because uCFG is
  what knows about CTY.DAT -- rather than in a table here that would be a
  second hand-maintained list of which setting means what. That is the same
  reason the hook index went in the first place.

  IT REFUSES, IT DOES NOT CORRECT. A check returning False leaves the
  property exactly as it was, which is the rule every other arm of
  TrySetByCommand already follows. *)
type
   TSettingValueCheck = function(const aValue: string): boolean;

procedure RegisterSettingValueCheck(const aPath: string;
                                    const aCheck: TSettingValueCheck);

(*
  THE VALUES A SETTING ACCEPTS, WHEN THEY ARE A LIST AND NOT A RANGE.

  A subrange already says both things a UI needs -- what to refuse and what to
  offer -- and needs nothing registered. This is for the settings whose
  vocabulary is a LIST: (0, 3, 4, 5) letters for Super Check Partial, or the
  two LPT pins a headphone relay can be wired to.

  IT DOES BOTH JOBS FROM ONE REGISTRATION. Membership is the refusal, and the
  same list is what a drop-down offers -- so the two cannot disagree, which is
  the whole complaint against the table this replaces.

  REGISTERED, NOT DECLARED HERE, for the reason MY COUNTRY's check is: the
  unit that owns the vocabulary is the one that knows it. uCFG builds these
  from the very const arrays CheckCommand matched against, so there is still
  exactly one statement of which values are legal.
*)
procedure RegisterSettingAllowedValues(const aPath: string;
                                       const aValues: array of string);

function Settings: TR4WSettings;
procedure FreeSettings;

implementation

uses
   (* fpjson and TypInfo moved to the INTERFACE uses -- SkipContestScoped names
     TJSONData and PPropInfo in its signature. Naming them again here is a
     duplicate identifier, not a harmless repetition. *)
   fpjsonrtti,   // the streamer; the property walk is TypInfo, see OwnsCommand
   uKeychain;    // StoreSecret / FetchSecret -- see TSecretText

var
   GSettings: TR4WSettings = nil;

type
   TRegisteredCheck = record
      Path: string;
      Check: TSettingValueCheck;
   end;

var
   GValueChecks: array of TRegisteredCheck;

type
   TRegisteredValues = record
      Path: string;
      Values: TArray<string>;
   end;

var
   GAllowedValues: array of TRegisteredValues;

procedure RegisterSettingAllowedValues(const aPath: string;
                                       const aValues: array of string);
var
   i, n: integer;
   copied: TArray<string>;
begin
   (* COPIED, because the caller passes an open array built on the spot. *)
   SetLength(copied, Length(aValues));
   for i := 0 to High(aValues) do
      begin
      copied[i] := aValues[i];
      end;

   for i := 0 to High(GAllowedValues) do
      begin
      if UnicodeSameText(GAllowedValues[i].Path, aPath) then
         begin
         GAllowedValues[i].Values := copied;
         Exit;
         end;
      end;

   n := Length(GAllowedValues);
   SetLength(GAllowedValues, n + 1);
   GAllowedValues[n].Path := aPath;
   GAllowedValues[n].Values := copied;
end;

(* The vocabulary registered for this path, or nil. *)
function RegisteredValuesFor(const aPath: string): TArray<string>;
var
   i: integer;
begin
   Result := nil;
   for i := 0 to High(GAllowedValues) do
      begin
      if UnicodeSameText(GAllowedValues[i].Path, aPath) then
         begin
         Result := GAllowedValues[i].Values;
         Exit;
         end;
      end;
end;

(* Where a value sits in the registered vocabulary, or -1.

  POSITION IS THE ORDINAL. That is exactly what the ckList row did: it found
  the text in a spelling table and wrote the table's INDEX through a pointer.
  The table is the same one; the pointer is gone. *)
function IndexOfRegisteredValue(const aPath, aValue: string): integer;
var
   allowed: TArray<string>;
   i: integer;
begin
   Result := -1;
   allowed := RegisteredValuesFor(aPath);
   for i := 0 to High(allowed) do
      begin
      if UnicodeSameText(Trim(allowed[i]), Trim(aValue)) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure RegisterSettingValueCheck(const aPath: string;
                                    const aCheck: TSettingValueCheck);
var
   i: integer;
begin
   if not Assigned(aCheck) then
      begin
      Exit;
      end;

   (* REGISTERING A PATH TWICE REPLACES, so a unit re-registering after a
     reload cannot end up with two checks disagreeing. *)
   for i := 0 to High(GValueChecks) do
      begin
      if UnicodeSameText(GValueChecks[i].Path, aPath) then
         begin
         GValueChecks[i].Check := aCheck;
         Exit;
         end;
      end;

   i := Length(GValueChecks);
   SetLength(GValueChecks, i + 1);
   GValueChecks[i].Path := aPath;
   GValueChecks[i].Check := aCheck;
end;

(* True when nothing objects -- which is the answer for every path that has
  no check registered, so this costs one walk of an array with one entry. *)
function ValueIsAcceptable(const aPath, aValue: string): boolean;
var
   i: integer;
   allowed: TArray<string>;
begin
   Result := True;

   (* A REGISTERED LIST IS THE REFUSAL AS WELL AS THE OFFER. Case and
     surrounding space are tolerated, the way the config file's matcher always
     has; what must match is the VALUE. *)
   allowed := RegisteredValuesFor(aPath);
   if allowed <> nil then
      begin
      Result := False;
      for i := 0 to High(allowed) do
         begin
         if UnicodeSameText(Trim(allowed[i]), Trim(aValue)) then
            begin
            Result := True;
            Break;
            end;
         end;
      if not Result then
         begin
         Exit;
         end;
      end;

   for i := 0 to High(GValueChecks) do
      begin
      if UnicodeSameText(GValueChecks[i].Path, aPath) then
         begin
         Result := GValueChecks[i].Check(aValue);
         Exit;
         end;
      end;
end;

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

procedure TSettingsGroup.SetStr(var aField: string;
                                const aValue, aProperty: string);
begin
   if aField = aValue then
      begin
      Exit;
      end;
   aField := aValue;
   Changed(aProperty);
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
   (* 60 MINUTES -- the value logwind.pas gave the global. The commented
     default in cfgdef.pas agreed, which is why this one needed no ruling. *)
   FDecayTime        := 60;
   (* ZERO, and it is the value the global actually had -- NOT the 200 that
     sits commented out beside its declaration. See the type. *)
   FGuardBand        := 0;
   // logwind commented its default as ByCutoffFrequency, and zero is it.
   FSplitMode        := ByCutoffFrequency;
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

{ TPaddleSettings }

constructor TPaddleSettings.Create;
begin
   inherited Create;
   // The values uConfigValues' initialiser carried.
   FSwap         := False;
   FSpeed        := 0;     // follow the keyboard speed -- see the note above
   FMonitorTone  := 700;   // Hz
   FPttHoldCount := 13;    // dit counts
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
   (* The token for lt_NoExternalLogger, which is what the global carried:
     the enum's zero value. The factory owns the spelling; this is the only
     place the settings model repeats it, and the vocabulary the factory
     registers is what refuses anything else. *)
   FLoggerType := 'NONE';
end;

{ TR4WSettings }

constructor TRadioServerSettings.Create;
begin
   inherited Create;
   // The value logstuff.pas's typed constant carried.
   FTcpServerPort := 52002;
end;

procedure TScpSettings.SetCountryString(const aValue: string);
var
   normalised: string;
begin
   (* THE TRAILING COMMA IS PART OF THE VALUE, not a display nicety: the
     reader consumes entries up to the next comma, so without one the last
     country in the list is never tested. *)
   normalised := aValue;
   if (normalised <> '') and (Copy(normalised, Length(normalised), 1) <> ',') then
      begin
      normalised := normalised + ',';
      end;
   SetStr(FCountryString, normalised, 'CountryString');
end;

procedure TBandMapSettings.SetSplitMode(aValue: BandMapSplitModeType);
begin
   if FSplitMode = aValue then
      begin
      Exit;
      end;
   FSplitMode := aValue;
   Changed('SplitMode');
end;

procedure TRemainingMultsSettings.SetDisplayMode(
   aValue: RemainingMultDisplayModeType);
begin
   if FDisplayMode = aValue then
      begin
      Exit;
      end;
   FDisplayMode := aValue;
   Changed('DisplayMode');
end;

procedure TCwSettings.SetAutoSendCharacterCount(aValue: TAutoSendCharacterCount);
begin
   if FAutoSendCharacterCount = aValue then
      begin
      Exit;
      end;
   FAutoSendCharacterCount := aValue;
   Changed('AutoSendCharacterCount');
end;

constructor TCwSettings.Create;
begin
   inherited Create;
   // The values uConfigValues' initialiser carried.
   FAllMessagesChainable      := False;
   FSpeedFromDatabase         := False;
   FKeypadMemories            := False;
   FSendCompleteFourLetterCall := False;
   FTuneWithDits              := False;
   (* The values the logstuff globals carried. The apostrophe is the key
     itself, not a quoting accident -- logstuff declares it as ''''. *)
   FShortIntegers             := False;
   FStartSendingNowKey        := '''';
   (* The values cfgdef.pas assigned at every startup -- see the note on the
     properties. *)
   FShort0 := '0';
   FShort1 := '1';
   FShort2 := '2';
   FShort9 := '9';
   (* The values uConfigValues and tree.pas carried. *)
   (* cfgdef assigned '0' at every startup, which is what the program
     actually ran with; the record initialiser's 'T' never won. *)
   FLeadingZeroCharacter := '0';
   FIncludeFKeyNumber    := False;
   FQuestionMarkChar     := '?';
   FSlashMarkChar        := '/';
   (* The values uConfigValues' initialiser carried, and logwind's zero. *)
   FSpeedIncrement         := 3;
   FDitDahRatio            := 3;
   FLeadingZeros           := 3;
   FAutoSendCharacterCount := 0;
end;

constructor TUnknownCountryFileSettings.Create;
begin
   inherited Create;
   FEnable := False;
   FName   := 'UNKNOWN.CTY';   // see the note on the class
end;

constructor TFontSettings.Create;
begin
   inherited Create;
   (* What the globals in VC.pas were declared with: FontSize = 2,
     BoldFont = True, MainFontName = 'Arial'. *)
   FSize := 2;
   FBold := True;
   FFace := 'Arial';
end;

constructor TStationsSettings.Create;
begin
   inherited Create;
   // No initialiser on the global, so empty -- which admits every callsign.
   FCallsignsMask := '';
end;

procedure TStationsSettings.SetCallsignsMask(const aValue: string);
begin
   SetStr(FCallsignsMask, aValue, 'CallsignsMask');
end;

constructor TRemainingMultsSettings.Create;
begin
   inherited Create;
   // No initialiser on the global, so False.
   FShowDomesticName := False;
   // logdom declared it HiLight, which is NOT the zero value.
   FDisplayMode := HiLight;
end;

procedure TRemainingMultsSettings.SetShowDomesticName(aValue: boolean);
begin
   SetBool(FShowDomesticName, aValue, 'ShowDomesticName');
end;

constructor TInitialExchangeSettings.Create;
begin
   inherited Create;
   // ReverseInitialex was declared = False in VC.pas.
   FReverse := False;
end;

constructor TQzbSettings.Create;
begin
   inherited Create;
   // No initialiser on the global, so False.
   FRandomOffsetEnable := False;
end;

constructor TSerialPortsSettings.Create;
begin
   inherited Create;
   // tShowAllSerialPorts was declared = False in VC.pas.
   FShowAll := False;
end;

constructor TServerSettings.Create;
begin
   inherited Create;
   // The values uNet's typed constants carried.
   FAddress                     := 'LOCALHOST';
   FPort                        := 1061;
   FAutoSynchronizeLogOnConnect := False;
   (* The value uNet's typed constant carried. It is the stock password the
     server ships with, so it is a default rather than a secret until the
     operator changes one or both ends. *)
   FPassword                    := 'TR4WSERVER';
end;

constructor THamscoreSettings.Create;
begin
   inherited Create;
   (* The values uConfigValues' initialiser carried, and neither is the
     zero value: the URL is the service's own address and contact info is
     ON. *)
   FUrl             := 'http://scoredistributor.net/';
   FSendContactInfo := True;
   FUsername        := '';
   FPassword        := '';
end;

constructor TScoreSettings.Create;
begin
   inherited Create;
   (* THE VALUES InitializeStrings SEEDED AT EVERY STARTUP, not the
     record initialisers empty string -- the table that held them is
     deleted with this move, and a default belongs in a constructor. *)
   FPostingUrl := 'https://post.contestonlinescore.com/post/';
   FReadingUrl := 'https://contestonlinescore.com/scoreboard/';
end;

constructor TScpSettings.Create;
begin
   inherited Create;
   // uConfigValues declared NameFlagEnable True.
   FNameFlagEnable := True;
   (* logstuff declared SCPMinimumLetters with no initialiser, so zero -- the
     value that means Super Check Partial is off. *)
   FMinimumLetters := 0;
   // The field had no initialiser, so AnyCall -- offer every partial match.
   FPossibleCallMode := AnyCall;
   // Empty means every country, which is what the field carried.
   FCountryString := '';
end;

constructor TClusterSettings.Create;
begin
   inherited Create;
   FConnectionAtStartup    := False;
   (* TRUE, because cfgdef assigned it at every startup -- see the note
     there. The record initialiser said False and never won. *)
   FBroadcastAllPacketData := True;
end;

constructor TOperatingSettings.Create;
begin
   inherited Create;
   (* The values the globals carried. Only ShiftKeyEnable was declared
     TRUE; the rest had no initialiser at all, which in Pascal is the
     zero value and is what this says out loud. *)
   FAskForFrequencies   := False;
   FAutoTimeIncrement   := 0;
   // logwind commented its default as NoTenMinuteRule, and zero is it.
   FTenMinuteRule       := NoTenMinuteRule;
   // logstuff declared it DupeCheckBeepIfDupe, NOT the zero value.
   FDupeCheckSound      := DupeCheckBeepIfDupe;
   FBeepEnable          := False;
   FHandLogMode         := False;
   FIeSwitch            := False;
   FIncrementTimeEnable := False;
   FShiftKeyEnable      := True;
   FTuneAltDEnable      := False;
   FWakeUpTimeOut       := 0;
   (* FrequencyMemoryEnable was declared True in logwind; the other three
     had no initialiser. *)
   FAutoQsoNumberDecrement := False;
   FCustomUserString       := '';
   FFrequencyMemoryEnable  := True;
   FLogSubTitle            := '';
   // logwind declared FreqPollRate = 10.
   FFrequencyPollRate      := 10;
end;

constructor TNetworkSettings.Create;
begin
   inherited Create;
   (* The values the typed constants in uNet and uConfigValues carried. *)
   FAllowAutoUpdate      := True;
   FMultiMultsOnly       := False;
   FShowTypedCallsign    := True;
   FStatusUpdateInterval := 5000;
   FIntercomFileEnable   := False;
end;

constructor TWsjtxSettings.Create;
begin
   inherited Create;
   (* The values the typed constants in uCFG and logstuff carried. *)
   FEnabled             := True;
   FRadioControlEnabled := False;
   FSendHighlights      := True;
   FBroadcastPort       := 2237;
   FMulticastGroup      := '';
end;

procedure TDvkSettings.SetEnable(aValue: boolean);
begin
   SetBool(FEnable, aValue, 'Enable');
end;

constructor TMainWindowSettings.Create;
begin
   inherited Create;
   (* The values VC.pas' declarations carried. The four booleans keep the
     False the field initialiser gives them, which is also what they had. *)
   FRowCount   := 5;
   FWindowSize := 5;
   // logwind's declaration commented its default as QSOs, and zero is it.
   FRateDisplay := QSOs;
   FHourDisplay := ThisHour;
   FUserInfoShown := NoUserInfo;
end;

procedure TMessageSettings.SetAutoQslInterval(aValue: TAutoQslInterval);
begin
   if FAutoQslInterval = aValue then
      begin
      Exit;
      end;
   FAutoQslInterval := aValue;
   Changed('AutoQslInterval');
end;

constructor THardwareSettings.Create;
begin
   inherited Create;
   // The value logk1ea's declaration carried.
   FStereoControlPin := 9;
end;

constructor TDvkSettings.Create;
begin
   inherited Create;
   // The values uConfigValues' initialiser carried.
   FEnable                  := False;
   FLocalizedMessagesEnable := False;
   FUseRecordedSigns        := False;
   FMissingCallsignsFileEnable := False;
   (* 'DVK', NOT EMPTY -- the value SetConfigurationDefaultValues appended
     into Config.DVKPath. GetRealPath sees no backslash in it and resolves it
     under the program directory, which is the out-of-the-box layout. *)
   FPath                    := 'DVK';
   FRecorder                := '';
end;

constructor TMySettings.Create;
begin
   inherited Create;
   (* Empty, and zero for the ITU zone, which is what the globals carried --
     cfgdef sets the two strings to '' explicitly and VC leaves the Byte at
     its zero. Zero is the "use CTY.DAT" sentinel, not an unset value. *)
   FFocNumber  := '';
   FIota       := '';
   FPark       := '';
   FCheck      := '';
   FPrec       := '';
   FFdClass    := '';
   FSection    := '';
   FName       := '';
   FPostalCode := '';
   FGrid       := '';
   FZone          := '';
   FZoneWasSet    := False;
   FCall          := '';
   FMainCallsign  := '';
   FCountry       := '';
   FCountryWasSet := False;
   FState         := '';
   FItuZone    := 0;
end;

procedure TMySettings.SetCall(const aValue: string);
begin
   SetStr(FCall, aValue, 'Call');
end;

procedure TMySettings.SetCountry(const aValue: string);
begin
   if aValue <> '' then
      begin
      FCountryWasSet := True;
      end;
   SetStr(FCountry, aValue, 'Country');
end;

procedure TMySettings.SetZone(const aValue: string);
begin
   if aValue <> '' then
      begin
      FZoneWasSet := True;
      end;
   SetStr(FZone, aValue, 'Zone');
end;

constructor TSayHiSettings.Create;
begin
   inherited Create;
   // The values uConfigValues' initialiser carried.
   FEnable     := False;
   FRateCutoff := 200;   // contacts per hour
end;

constructor TLogSettings.Create;
begin
   inherited Create;
   // The values uConfigValues' initialiser carried.
   FWithSingleEnter    := False;
   FConfirmEditChanges := True;
   // loggrid declared DistanceMode as DistanceKM, NOT the zero value.
   FDistanceMode       := DistanceKM;
   // VC declared logLevels with no initialiser, so llNone.
   FDebugLevel         := llNone;
   FCheckFileSize      := False;
   FUpdateRestartFile  := True;
   (* The values the globals in VC.pas carried: LogFrequencyEnable has no
     initialiser and so was False, ColumnAutoSize was declared = True. *)
   FFrequencyEnable    := False;
   FColumnAutoSize     := True;
   (* The values the logstuff globals carried. THE TWO REPORTS ARE THE ONLY
     ONES HERE THAT ARE NOT ZERO OR FALSE, and they matter: 59 and 599 are
     what every contest sends, and a zero would be refused by the subrange
     the moment anything tried to write it back. *)
   FRsSent             := 59;
   FRstSent            := 599;
   FLookForRstSent     := False;
   FBackupFrequency    := 0;
   FBeepEvery10Qsos    := False;
   FDisabled           := False;
   (* tShowFrequencyinLog was declared TRUE in postunit.pas. *)
   FShowFrequency      := True;
end;

constructor TCqSettings.Create;
begin
   inherited Create;
   // The values uConfigValues and LogCW.pas carried.
   FAlwaysCallBlind           := False;
   FAutoCallTerminate         := False;
   FAutoReturnToMode          := True;
   FEscapeExitsSearchAndPounce := True;
   FAutoDelay                 := 3000;   // ms
   FRandomMode                := False;  // logstuff's declaration
end;

constructor TAltDSettings.Create;
begin
   inherited Create;
   FBufferEnable := False;
   FCqEnable     := False;
end;

constructor TCallWindowSettings.Create;
begin
   inherited Create;
   (* Three of the five default True. That asymmetry is the values
     uConfigValues carried, not a guess. *)
   FShowAllSpots      := False;
   FLeaveCursor       := False;
   FSpaceBarDupeCheck := True;
   FPartialCallEnable := True;
   FWildcardPartials  := True;
   // CompleteCallsignMask had no initialiser in VC.pas, so it was empty.
   FCompleteCallsignMask := '';
   (* TRUE, and it was False before the move. NY4I asked for it: the
     feature is used in many places and being off by default made every
     operator turn it on. *)
   FCallsignUpdateEnable := True;
   FInsertMode        := True;   // logstuff's declaration
end;

procedure TCallWindowSettings.SetInsertMode(aValue: boolean);
begin
   SetBool(FInsertMode, aValue, 'InsertMode');
end;

constructor TSo2rSettings.Create;
begin
   inherited Create;
   // The values uConfigValues' initialiser carried.
   FTwoRadioMode         := False;
   FQsyInactiveRadio     := False;
   FSkipActiveBand       := False;
   FSwapPacketSpotRadios := False;
   FSwapRelaySense       := False;
   FInBandLockout        := True;
   FWaitForStrength      := True;
end;

procedure TSo2rSettings.SetQsyInactiveRadio(aValue: boolean);
begin
   SetBool(FQsyInactiveRadio, aValue, 'QsyInactiveRadio');
end;

constructor TPossibleCallSettings.Create;
begin
   inherited Create;
   (* The values the globals carried -- logstuff.pas for the three keys,
     uConfigValues for the enable. cfgdef's commented-out lines agree with
     all four, which is not something to assume: they have disagreed with
     the live declaration three times today. *)
   FEnable    := True;
   FAcceptKey := ';';
   FLeftKey   := ',';
   FRightKey  := '.';
end;

constructor TAutoSapSettings.Create;
begin
   inherited Create;
   (* The values the globals carried: logstuff.pas declares AutoSAPEnable
     with no initialiser, and logwind.pas gives AutoSAPEnableRate 500.
     cfgdef's commented-out line says 1000 and is NOT the live value --
     the declaration is. *)
   FEnable      := False;
   FSensitivity := 500;
end;

(* THE DEFAULTS ARE CARRIED ACROSS BY HAND, from each global's own
  declaration in logdupe.pas or logwind.pas, or from cfgdef where the
  declaration had none.  A field defaults to zero and a lost `= True`
  disables a feature in silence, which in this group would be a scoring
  change nothing reports. *)
constructor TQsoSettings.Create;
begin
   inherited Create;
   FByBand              := False;
   FByMode              := False;
   (* -1, NOT 0.  Zero is a legal fixed value -- "this contest scores no
     points for that kind of QSO" -- and -1 is the absence of one. *)
   FPointsDomesticCw    := -1;
   FPointsDomesticPhone := -1;
   FPointsDxCw          := -1;
   FPointsDxPhone       := -1;
end;

class function TQsoSettings.IsContestScoped: boolean;
begin
   Result := True;
end;

constructor TMultSettings.Create;
begin
   inherited Create;
   FByBand         := False;
   FByMode         := False;
   FSheetAutoReset := False;   // was MultReset : boolean = False
end;

class function TMultSettings.IsContestScoped: boolean;
begin
   Result := True;
end;

constructor TQtcSettings.Create;
begin
   inherited Create;
   FEnable  := False;
   FMinutes := False;
   (* Both declared TRUE in logwae.pas. *)
   FExtraSpace := True;
   FQrs        := True;
end;

class function TQtcSettings.IsContestScoped: boolean;
begin
   Result := True;
end;

constructor TAutoDupeSettings.Create;
begin
   inherited Create;
   (* The two halves ship DIFFERENT: dupe checking is off while calling CQ
     and on while searching and pouncing.  Both come from the declarations
     in logdupe.pas. *)
   FEnableCq    := False;
   FEnableSAndP := True;
end;

class function TAutoDupeSettings.IsContestScoped: boolean;
begin
   Result := True;
end;

constructor TComputerSettings.Create;
begin
   inherited Create;
   (* #0, which is what the uninitialised AnsiChar global carried and what
     MainUnit tests for. cfgdef's commented-out line agrees. *)
   FId   := #0;
   FName := 'New';   // logstuff's declaration
end;

procedure TComputerSettings.SetName(const aValue: string);
begin
   SetStr(FName, aValue, 'Name');
end;

constructor TRotatorSettings.Create;
begin
   inherited Create;
   // The values logstuff's declarations carried.
   FIpAddress := '127.0.0.1';
   FUdpPort   := 12000;
   // The token for NoRotator, which is what the global carried.
   FRotatorType := 'NONE';
end;

constructor TDupeSheetSettings.Create;
begin
   inherited Create;
   FAutoReset      := True;    // Sheet's record initialiser
   FAutoDisplayQso := False;
end;

constructor TCountrySettings.Create;
begin
   inherited Create;
   FInformationFile      := '';
   (* CTYUpdateCheckOnStartup was declared TRUE in uCFG. *)
   FUpdateCheckOnStartup := True;
end;

constructor TQsxSettings.Create;
begin
   inherited Create;
   FEnable := True;   // logstuff's declaration
end;

constructor TMessageSettings.Create;
begin
   inherited Create;
   (* All four from logstuff's declarations. The two keys are a backslash
     and an equals sign; they are not placeholders. *)
   FEnable       := True;
   FDeEnable     := True;
   FQuickQslKey1 := '\';
   FQuickQslKey2 := '=';
   // logstuff declared AutoQSLInterval with no initialiser: no automatic QSL.
   FAutoQslInterval := 0;
end;

constructor TContestSettings.Create;
begin
   inherited Create;
   (* Both off. The two country-list overlays are loaded only for the
     contests that ask for them. *)
   FR150SMode := False;
   FRfoblMode := False;
   (* CallsignUpdateEnable and DigitalModeEnable had no initialiser on their
     declarations; both were assigned in cfgdef.SetConfigurationDefaultValues,
     which runs once at startup before any config is read -- so the value
     there IS the default and comes here. *)
   FCountDomesticCountries := False;
   FDigitalModeEnable      := True;    // cfgdef
   FDomesticFilename       := '';
   FExchangeMemoryEnable   := True;
   FMultipleBands          := True;
   FMultipleModes          := True;
   FSprintQsyRule          := False;
   // Both globals are declared with no initialiser, so both were False.
   FQsoNumberByBand          := False;
   FInitialExchangeOverwrite := False;
   (* ContactsPerPage was declared = 50; the other three had no
     initialiser. *)
   FContactsPerPage             := 50;
   FMinitourDuration            := 0;
   FLiteralDomesticQth          := False;
   FCustomInitialExchangeString := '';
   FHamscoreEnable              := False;
end;

class function TContestSettings.IsContestScoped: boolean;
begin
   Result := True;
end;

constructor TMessageTemplateSettings.Create;
begin
   inherited Create;
   (* THIRTEEN OF THESE CAME OUT OF uCFG.InitializeStrings, NOT out of the
     declarations -- see the note on the class. The four CW exchanges are
     genuinely empty, and have to stay that way: tSetupExchangeNumbers only
     fills one that is still empty. *)
   FCallOkNowCw            := '} OK %';
   FCallOkNowSsb           := 'CORCALL.WAV';
   FCqExchangeCw           := '';
   FCqExchangeCwNameKnown  := '';
   FCqExchangeSsb          := 'CQEXCHNG.WAV';
   FCqExchangeSsbNameKnown := 'CQEXNAME.WAV';
   FQslCw                  := 'TU \ TEST';
   FQslSsb                 := 'QSL.WAV';
   FQsoBeforeCw            := ' SRI QSO B4 TU \ TEST';
   FQsoBeforeSsb           := 'QSOB4.WAV';
   FQuickQslCw1            := 'TU';
   FQuickQslCw2            := 'TU';
   FQuickQslSsb            := 'QUICKQSL.WAV';
   FRepeatSpExchangeCw     := '';
   FRepeatSpExchangeSsb    := 'RPTSPEX.WAV';
   FSpExchangeCw           := '';
   FSpExchangeSsb          := 'SAPEXCHG.WAV';
end;

class function TMessageTemplateSettings.IsContestScoped: boolean;
begin
   Result := True;
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
   FPaddle         := TPaddleSettings.Create;
   FCw             := TCwSettings.Create;
   FAutoSap        := TAutoSapSettings.Create;
   FPossibleCall   := TPossibleCallSettings.Create;
   FSo2r           := TSo2rSettings.Create;
   FAltD           := TAltDSettings.Create;
   FCallWindow     := TCallWindowSettings.Create;
   FCq             := TCqSettings.Create;
   FLog            := TLogSettings.Create;
   FSayHi          := TSayHiSettings.Create;
   FMy             := TMySettings.Create;
   FDvk            := TDvkSettings.Create;
   FWsjtx          := TWsjtxSettings.Create;
   FMainWindow     := TMainWindowSettings.Create;
   FNetwork        := TNetworkSettings.Create;
   FOperating      := TOperatingSettings.Create;
   FScp            := TScpSettings.Create;
   FCluster        := TClusterSettings.Create;
   FScore          := TScoreSettings.Create;
   FTelnet         := TTelnetSettings.Create;
   FServer         := TServerSettings.Create;
   FHamscore       := THamscoreSettings.Create;
   FMp3            := TMp3Settings.Create;
   FHardware       := THardwareSettings.Create;
   FUnknownCountryFile := TUnknownCountryFileSettings.Create;
   FQso            := TQsoSettings.Create;
   FMult           := TMultSettings.Create;
   FQtc            := TQtcSettings.Create;
   FAutoDupe       := TAutoDupeSettings.Create;
   FContest        := TContestSettings.Create;
   FFont            := TFontSettings.Create;
   FStations        := TStationsSettings.Create;
   FRemainingMults  := TRemainingMultsSettings.Create;
   FInitialExchange := TInitialExchangeSettings.Create;
   FQzb             := TQzbSettings.Create;
   FSerialPorts     := TSerialPortsSettings.Create;
   FComputer       := TComputerSettings.Create;
   FRotator        := TRotatorSettings.Create;
   FDupeSheet      := TDupeSheetSettings.Create;
   FCountry        := TCountrySettings.Create;
   FGridMap        := TGridMapSettings.Create;
   FQsx            := TQsxSettings.Create;
   FMessage        := TMessageSettings.Create;
   FContest        := TContestSettings.Create;
   FMessages       := TMessageTemplateSettings.Create;

   FCommands := TStringList.Create;
   FCommands.CaseSensitive := False;
   FCommands.Sorted := True;
   FCommands.Duplicates := dupError;   // two properties claiming one command name
   BuildCommandMap;
end;

destructor TR4WSettings.Destroy;
begin
   FCommands.Free;
   FContest.Free;
   FAutoDupe.Free;
   FQtc.Free;
   FMult.Free;
   FQso.Free;
   FSerialPorts.Free;
   FQzb.Free;
   FInitialExchange.Free;
   FRemainingMults.Free;
   FStations.Free;
   FFont.Free;
   FMessage.Free;
   FQsx.Free;
   FGridMap.Free;
   FCountry.Free;
   FDupeSheet.Free;
   FRotator.Free;
   FComputer.Free;
   FMessages.Free;
   FUnknownCountryFile.Free;
   FDvk.Free;
   FMy.Free;
   FSayHi.Free;
   FLog.Free;
   FCq.Free;
   FCallWindow.Free;
   FAltD.Free;
   FSo2r.Free;
   FPossibleCall.Free;
   FAutoSap.Free;
   FCw.Free;
   FPaddle.Free;
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
  SetUnicodeStrProp and GetUnicodeStrProp -- is the reason this is written down rather than
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
   (* A SECOND NAME FOR A PATH THAT KEEPS THE FIRST.

     Alias REPLACES: it deletes every existing name for the path before
     installing the new one, which is right when the derived name is wrong.
     This is for the other case -- two names TR4W has always accepted for
     one setting, both of which must keep working. MY QTH and MY STATE were
     two rows in the config array whose crAddress was the same global; a
     config file, and a multi-op peer, may use either. *)
   procedure AlsoKnownAs(const aCommand, aPath: string);
   begin
      FCommands.Values[AnsiString(aCommand)] := AnsiString(aPath);
   end;

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
   (* MY STATE derives exactly. MY QTH is the older spelling of the same
     setting and is ADDED, not substituted. *)
   AlsoKnownAs('MY QTH', 'My.State');

   (* ALL FIVE WSJT-X NAMES, for the one reason given on TWsjtxSettings:
     the command spelling has a hyphen in it and a Pascal identifier
     cannot. The derivation produces WSJTX ...; the program has always
     accepted WSJT-X ..., so the derived spelling is REPLACED rather than
     kept alongside -- a name TR4W never had would be offered in
     Preferences and claimed in a multi-op peer message. *)
   Alias('WSJT-X ENABLED',               'Wsjtx.Enabled');
   Alias('WSJT-X RADIO CONTROL ENABLED', 'Wsjtx.RadioControlEnabled');
   Alias('WSJT-X SEND HIGHLIGHTS',       'Wsjtx.SendHighlights');
   Alias('WSJT-X BROADCAST PORT',        'Wsjtx.BroadcastPort');
   Alias('WSJT-X MULTICAST GROUP',       'Wsjtx.MulticastGroup');

   (* The four main-window appearance flags. Flat names, every one. *)
   Alias('NO BORDER',        'MainWindow.NoBorder');
   Alias('NO CAPTION',       'MainWindow.NoCaption');
   Alias('NO COLUMN HEADER', 'MainWindow.NoColumnHeader');
   Alias('SHOW GRIDLINES',   'MainWindow.ShowGridlines');

   (* The multi-op network's four, none of which name the network. *)
   Alias('ALLOW AUTO UPDATE',          'Network.AllowAutoUpdate');
   Alias('MULTI MULTS ONLY',           'Network.MultiMultsOnly');
   Alias('SHOW TYPED CALLSIGN',        'Network.ShowTypedCallsign');
   Alias('NET STATUS UPDATE INTERVAL', 'Network.StatusUpdateInterval');

   (* CTY is what an operator calls the country file; the group is named
     for the thing rather than for the file extension. *)
   Alias('CTY UPDATE CHECK ON STARTUP', 'Country.UpdateCheckOnStartup');

   (* The log's own display of the frequency. The command puts the group
     in the middle -- SHOW FREQUENCY IN LOG -- which no path can do. *)
   Alias('SHOW FREQUENCY IN LOG', 'Log.ShowFrequency');

   (* All nine operating names. See TOperatingSettings for why they are
     one group with nine aliases rather than nine groups with none. *)
   Alias('ASK FOR FREQUENCIES',   'Operating.AskForFrequencies');
   Alias('AUTO TIME INCREMENT',   'Operating.AutoTimeIncrement');
   Alias('BEEP ENABLE',           'Operating.BeepEnable');
   Alias('HAND LOG MODE',         'Operating.HandLogMode');
   Alias('IE SWITCH',             'Operating.IeSwitch');
   Alias('INCREMENT TIME ENABLE', 'Operating.IncrementTimeEnable');
   Alias('SHIFT KEY ENABLE',      'Operating.ShiftKeyEnable');
   Alias('TUNE ALT-D ENABLE',     'Operating.TuneAltDEnable');
   Alias('WAKE UP TIME OUT',      'Operating.WakeUpTimeOut');
   Alias('AUTO QSO NUMBER DECREMENT', 'Operating.AutoQsoNumberDecrement');
   Alias('CUSTOM USER STRING',        'Operating.CustomUserString');
   Alias('FREQUENCY MEMORY ENABLE',   'Operating.FrequencyMemoryEnable');
   Alias('LOG SUB TITLE',             'Operating.LogSubTitle');

   (* The CW group's four new names. LEADING ZERO CHARACTER and the two
     key characters say nothing about CW; INCLUDE F-KEY NUMBER says
     nothing about anything. *)
   Alias('LEADING ZERO CHARACTER', 'Cw.LeadingZeroCharacter');
   Alias('INCLUDE F-KEY NUMBER',   'Cw.IncludeFKeyNumber');
   Alias('QUESTION MARK CHAR',     'Cw.QuestionMarkChar');
   Alias('SLASH MARK CHAR',        'Cw.SlashMarkChar');

   Alias('INTERCOM FILE ENABLE',       'Network.IntercomFileEnable');
   Alias('NAME FLAG ENABLE',           'Scp.NameFlagEnable');
   Alias('CONNECTION AT STARTUP',      'Cluster.ConnectionAtStartup');
   Alias('BROADCAST ALL PACKET DATA',  'Cluster.BroadcastAllPacketData');
   Alias('FREQUENCY POLL RATE',        'Operating.FrequencyPollRate');
   Alias('RADIUS OF EARTH',            'GridMap.RadiusOfEarth');
   (* Moved out of the contest group 2026-09-12; the command never named
     the call window and still does not. *)
   Alias('CALLSIGN UPDATE ENABLE',     'CallWindow.CallsignUpdateEnable');
   (* Moved into the contest group 2026-09-12; the command has never
     named the contest. *)
   Alias('HAMSCORE ENABLE',            'Contest.HamscoreEnable');
   (* The credentials. HAMSCORE USERNAME and PASSWORD derive exactly from
     Hamscore.Username and Hamscore.Password; SERVER PASSWORD derives from
     Server.Password. All three are listed here only because they are the
     ones a reader will come looking for -- none actually needs an alias. *)
   Alias('USE CONTROL PORT',           'Hardware.UseControlPort');

   (* The contest's four. Every one puts the subject first and the
     contest nowhere, which is what a flat vocabulary does. *)
   Alias('CONTACTS PER PAGE',   'Contest.ContactsPerPage');
   Alias('MINITOUR DURATION',   'Contest.MinitourDuration');
   Alias('LITERAL DOMESTIC QTH', 'Contest.LiteralDomesticQth');
   Alias('CUSTOM INITIAL EXCHANGE STRING',
         'Contest.CustomInitialExchangeString');
   (* The command runs the two words together; the property cannot. *)
   Alias('MISSINGCALLSIGNS FILE ENABLE',
         'Dvk.MissingCallsignsFileEnable');

   Alias('HF BAND ENABLE',   'Bands.HfEnabled');
   Alias('VHF BAND ENABLE',  'Bands.VhfEnabled');
   Alias('WARC BAND ENABLE', 'Bands.WarcEnabled');

   (* The group goes LAST in this one -- NO POLL DURING PTT -- which no
     property path can produce.  The other four PTT settings derive exactly. *)
   Alias('NO POLL DURING PTT', 'Ptt.NoPollDuring');

   (* SWAP PADDLES, subject last again.  The setting belongs with the paddle;
     the command name puts the verb first. *)
   Alias('SWAP PADDLES', 'Paddle.Swap');

   (* CW IS THE LARGEST HISTORICALLY-FLAT FAMILY, and four of its five need an
     alias, which is more than a trickle and worth explaining rather than
     waving at.

     These names were coined before any grouping existed, so most carry no CW
     prefix at all (TUNE WITH DITS) and one buries it in the middle (KEYPAD CW
     MEMORIES, ALL CW MESSAGES CHAINABLE). No property path produces either
     shape: the derivation puts the group first, once.

     THIS IS NOT EVIDENCE THE RULE IS WRONG. The alternative is a property
     named AllCwMessagesChainable inside a group called Cw, which derives to
     CW ALL CW MESSAGES CHAINABLE -- a name nobody has ever typed -- or five
     one-property groups, which is the shape rejected for the band classes
     above. The names are the legacy; the model is not obliged to be shaped
     like them. *)
   Alias('ALL CW MESSAGES CHAINABLE',      'Cw.AllMessagesChainable');
   Alias('AUTO SEND CHARACTER COUNT',      'Cw.AutoSendCharacterCount');
   Alias('DIT DAH RATIO',                  'Cw.DitDahRatio');
   Alias('KEYPAD CW MEMORIES',             'Cw.KeypadMemories');
   Alias('LEADING ZEROS',                  'Cw.LeadingZeros');

   (* The main window's two sizes. ROW COUNT says nothing about what is
     counted and WINDOW SIZE would derive as MAIN WINDOW WINDOW SIZE. *)
   (* The QSL message's own interval; the derived name would put MESSAGE in
     front of a command an operator has typed for years. *)
   (* THE TWO COUNTRY-LIST OVERLAYS. No property path produces either: the
     derivation splits at a capital and these names run a digit and a letter
     together. *)
   Alias('R150S MODE', 'Contest.R150SMode');
   Alias('RFOBL MODE', 'Contest.RfoblMode');
   Alias('AUTO QSL INTERVAL', 'Message.AutoQslInterval');
   Alias('STEREO CONTROL PIN', 'Hardware.StereoControlPin');
   Alias('RATE DISPLAY', 'MainWindow.RateDisplay');
   Alias('HOUR DISPLAY', 'MainWindow.HourDisplay');
   Alias('USER INFO SHOWN', 'MainWindow.UserInfoShown');
   Alias('DUPE CHECK SOUND', 'Operating.DupeCheckSound');
   Alias('DEBUG LOG LEVEL', 'Log.DebugLevel');
   Alias('POSSIBLE CALL MODE', 'Scp.PossibleCallMode');
   Alias('EXTERNAL LOGGER', 'ExternalLogger.LoggerType');
   Alias('ROTATOR TYPE', 'Rotator.RotatorType');
   (* A CONTEST RULE THE STATION SETS, not one FCONTEST assigns -- nothing
     anywhere writes it per contest -- so it is station-scoped and joins
     Operating rather than the contest-scoped Contest group. *)
   Alias('TEN MINUTE RULE', 'Operating.TenMinuteRule');
   Alias('DISTANCE MODE', 'Log.DistanceMode');
   Alias('REMAINING MULT DISPLAY MODE', 'RemainingMults.DisplayMode');
   Alias('ROW COUNT',   'MainWindow.RowCount');
   Alias('WINDOW SIZE', 'MainWindow.WindowSize');
   Alias('SEND COMPLETE FOUR LETTER CALL', 'Cw.SendCompleteFourLetterCall');
   Alias('TUNE WITH DITS',                 'Cw.TuneWithDits');

   (* AN ALPHABET LIMIT, not a naming accident: no identifier yields '&'. *)
   (* THE PLURAL NOUN, where every sibling names the thing and then the
     attribute. POSSIBLE CALL ENABLE would be the derived spelling and is
     not what any config file says. *)
   (* No DVK in the command at all. *)
   Alias('USE RECORDED SIGNS', 'Dvk.UseRecordedSigns');

   Alias('POSSIBLE CALLS', 'PossibleCall.Enable');

   (* THE WHOLE SO2R GROUP -- see TSo2rSettings for why every one of them
     needs a line here and why that is not evidence the rule is wrong. *)
   (* LOG WITH SINGLE ENTER and LOG FREQUENCY ENABLE are NOT here -- both
     derive, because both happen to lead with the group's own word. *)
   Alias('CONFIRM EDIT CHANGES',        'Log.ConfirmEditChanges');
   Alias('CHECK LOG FILE SIZE',         'Log.CheckFileSize');
   Alias('UPDATE RESTART FILE ENABLE',  'Log.UpdateRestartFile');
   Alias('COLUMN AUTOSIZE',             'Log.ColumnAutoSize');

   (* THE MAIN WINDOW FONT. FONT SIZE derives; the other two are flat
     names with the noun last. *)
   Alias('BOLD FONT', 'Font.Bold');
   Alias('MAIN FONT', 'Font.Face');

   (* STATIONS CALLSIGNS MASK and QZB RANDOM OFFSET ENABLE are NOT here --
     both derive exactly from their group and property names. *)
   Alias('COMPLETE CALLSIGN MASK',        'CallWindow.CompleteCallsignMask');
   Alias('MAIN CALLSIGN',                 'My.MainCallsign');
   Alias('SHOW DOMESTIC MULTIPLIER NAME', 'RemainingMults.ShowDomesticName');
   Alias('REVERSE INITIAL EX',            'InitialExchange.Reverse');
   Alias('SHOW ALL SERIAL PORTS',         'SerialPorts.ShowAll');

   Alias('ALWAYS CALL BLIND CQ',           'Cq.AlwaysCallBlind');
   Alias('AUTO CALL TERMINATE',            'Cq.AutoCallTerminate');
   Alias('AUTO RETURN TO CQ MODE',         'Cq.AutoReturnToMode');
   Alias('ESCAPE EXITS SEARCH AND POUNCE', 'Cq.EscapeExitsSearchAndPounce');
   Alias('AUTO-CQ DELAY TIME',             'Cq.AutoDelay');

   (* A HYPHEN, which no identifier yields. *)
   Alias('ALT-D BUFFER ENABLE', 'AltD.BufferEnable');
   Alias('ALT-D CQ ENABLE',     'AltD.CqEnable');

   (* CALL WINDOW SHOW ALL SPOTS is NOT here -- it derives. *)
   Alias('LEAVE CURSOR IN CALL WINDOW',  'CallWindow.LeaveCursor');
   Alias('SPACE BAR DUPE CHECK ENABLE',  'CallWindow.SpaceBarDupeCheck');
   Alias('PARTIAL CALL ENABLE',          'CallWindow.PartialCallEnable');
   Alias('WILDCARD PARTIALS',            'CallWindow.WildcardPartials');

   Alias('TWO RADIO MODE',           'So2r.TwoRadioMode');
   Alias('QSY INACTIVE RADIO',       'So2r.QsyInactiveRadio');
   Alias('SKIP ACTIVE BAND',         'So2r.SkipActiveBand');
   Alias('SWAP PACKET SPOT RADIOS',  'So2r.SwapPacketSpotRadios');
   Alias('SWAP RADIO RELAY SENSE',   'So2r.SwapRelaySense');
   Alias('IN BAND LOCKOUT',          'So2r.InBandLockout');
   Alias('WAIT FOR STRENGTH',        'So2r.WaitForStrength');

   Alias('AUTO S&P ENABLE',             'AutoSap.Enable');
   Alias('AUTO S&P ENABLE SENSITIVITY', 'AutoSap.Sensitivity');

   (* THE CONTEST'S RULES.  Twelve of the twenty-one derive on their own --
     every member of Qso, Mult and Qtc, plus AUTO DUPE ENABLE CQ -- and
     these nine do not, because TR4W's contest vocabulary is flat where a
     property path is grouped.  See the header above TQsoSettings. *)
   Alias('AUTO DUPE ENABLE S AND P', 'AutoDupe.EnableSAndP');

   Alias('COUNT DOMESTIC COUNTRIES', 'Contest.CountDomesticCountries');
   Alias('DIGITAL MODE ENABLE',      'Contest.DigitalModeEnable');
   Alias('DOMESTIC FILENAME',        'Contest.DomesticFilename');
   Alias('EXCHANGE MEMORY ENABLE',   'Contest.ExchangeMemoryEnable');
   Alias('MULTIPLE BANDS',           'Contest.MultipleBands');
   Alias('MULTIPLE MODES',           'Contest.MultipleModes');
   Alias('SPRINT QSY RULE',          'Contest.SprintQsyRule');
   (* THE logstuff STATION SETTINGS. Sixteen of the twenty-five need a line
     here, and every one of them for a shape the derivation cannot make:
     the subject in the middle (AUTO DISPLAY DUPE QSO), the group second
     (BACKUP LOG FREQUENCY), a digit welded to the word before it (QUICK
     QSL KEY 1, BEEP EVERY 10 QSOS), a product name spelled as one word
     (PSTROTATOR), or a group that exists for scope rather than for
     naming (CONTEST). The other nine derive with no line at all. *)
   Alias('SHORT INTEGERS',        'Cw.ShortIntegers');
   Alias('START SENDING NOW KEY', 'Cw.StartSendingNowKey');

   Alias('RANDOM CQ MODE', 'Cq.RandomMode');

   Alias('INSERT MODE', 'CallWindow.InsertMode');

   Alias('LOOK FOR RST SENT',   'Log.LookForRstSent');
   Alias('BACKUP LOG FREQUENCY','Log.BackupFrequency');
   Alias('BEEP EVERY 10 QSOS',  'Log.BeepEvery10Qsos');
   Alias('NO LOG',              'Log.Disabled');

   Alias('PSTROTATOR IP ADDRESS', 'Rotator.IpAddress');
   Alias('PSTROTATOR UDP PORT',   'Rotator.UdpPort');

   Alias('AUTO DISPLAY DUPE QSO', 'DupeSheet.AutoDisplayQso');

   Alias('DE ENABLE',       'Message.DeEnable');
   Alias('QUICK QSL KEY 1', 'Message.QuickQslKey1');
   Alias('QUICK QSL KEY 2', 'Message.QuickQslKey2');

   Alias('QSO NUMBER BY BAND',         'Contest.QsoNumberByBand');
   Alias('INITIAL EXCHANGE OVERWRITE', 'Contest.InitialExchangeOverwrite');
   (* THE CUT NUMBERS. A digit cannot follow a space in a Pascal identifier,
     so 'SHORT 0' cannot derive from any property name; 'CW SHORT0' is what
     the rule produces and is not a command TR4W has ever had. *)
   Alias('SHORT 0', 'Cw.Short0');
   Alias('SHORT 1', 'Cw.Short1');
   Alias('SHORT 2', 'Cw.Short2');
   Alias('SHORT 9', 'Cw.Short9');

   (* THE MESSAGE TEMPLATES -- THIRTY NAMES FOR SEVENTEEN SETTINGS, and the
     longest block in this list by some way. It is worth saying why that is
     not the derivation rule failing.

     THE MODE IS IN THE MIDDLE OF EVERY ONE OF THEM: CQ *CW* EXCHANGE, QSL
     *SSB* MESSAGE, REPEAT S&P *CW* EXCHANGE. The derivation puts the group
     first and once, so no arrangement of properties and groups produces that
     shape -- and six of the names contain an ampersand, which no identifier
     yields at all. The alternative is seventeen one-property groups named
     after fragments of a sentence, which is the shape already rejected for
     the band classes.

     AND EIGHT OF THEM CARRY A SECOND, OLDER NAME. TR4W has always taken the
     mode-less spelling as meaning the CW one -- they were two CFGCA rows
     sharing a crAddress -- so a .cfg written years ago, or a multi-op peer
     running an older build, still says CQ EXCHANGE. AlsoKnownAs adds; Alias
     replaces. *)
   Alias('CALL OK NOW CW MESSAGE',      'Messages.CallOkNowCw');
   AlsoKnownAs('CALL OK NOW MESSAGE',   'Messages.CallOkNowCw');
   Alias('CALL OK NOW SSB MESSAGE',     'Messages.CallOkNowSsb');

   Alias('CQ CW EXCHANGE',              'Messages.CqExchangeCw');
   AlsoKnownAs('CQ EXCHANGE',           'Messages.CqExchangeCw');
   Alias('CQ CW EXCHANGE NAME KNOWN',   'Messages.CqExchangeCwNameKnown');
   AlsoKnownAs('CQ EXCHANGE NAME KNOWN', 'Messages.CqExchangeCwNameKnown');
   Alias('CQ SSB EXCHANGE',             'Messages.CqExchangeSsb');
   Alias('CQ SSB EXCHANGE NAME KNOWN',  'Messages.CqExchangeSsbNameKnown');

   Alias('QSL CW MESSAGE',              'Messages.QslCw');
   AlsoKnownAs('QSL MESSAGE',           'Messages.QslCw');
   Alias('QSL SSB MESSAGE',             'Messages.QslSsb');

   Alias('QSO BEFORE CW MESSAGE',       'Messages.QsoBeforeCw');
   AlsoKnownAs('QSO BEFORE MESSAGE',    'Messages.QsoBeforeCw');
   Alias('QSO BEFORE SSB MESSAGE',      'Messages.QsoBeforeSsb');

   (* THREE NAMES, ONE SETTING. These were three CFGCA rows whose crAddress
     was the same global, and QUICK QSL CW MESSAGE1 has no space before the
     digit while QUICK QSL MESSAGE 1 does. Both spellings are real. *)
   Alias('QUICK QSL CW MESSAGE',        'Messages.QuickQslCw1');
   AlsoKnownAs('QUICK QSL CW MESSAGE1', 'Messages.QuickQslCw1');
   AlsoKnownAs('QUICK QSL MESSAGE 1',   'Messages.QuickQslCw1');
   Alias('QUICK QSL MESSAGE 2',         'Messages.QuickQslCw2');
   Alias('QUICK QSL SSB MESSAGE',       'Messages.QuickQslSsb');

   Alias('REPEAT S&P CW EXCHANGE',      'Messages.RepeatSpExchangeCw');
   AlsoKnownAs('REPEAT S&P EXCHANGE',   'Messages.RepeatSpExchangeCw');
   Alias('REPEAT S&P SSB EXCHANGE',     'Messages.RepeatSpExchangeSsb');

   Alias('S&P CW EXCHANGE',             'Messages.SpExchangeCw');
   AlsoKnownAs('S&P EXCHANGE',          'Messages.SpExchangeCw');
   Alias('S&P SSB EXCHANGE',            'Messages.SpExchangeSsb');
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

function TR4WSettings.CommandIsContestScoped(const aCommand: string): boolean;
var
   path: string;
   owner: TObject;
   info: PPropInfo;
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

   (* The OWNER is the group -- ResolvePath walks down to the object that
     actually publishes the property, which is what carries the marker. *)
   Result := (owner is TSettingsGroup) and TSettingsGroup(owner).IsContestScoped;
end;

function TR4WSettings.TrySetByCommand(const aCommand, aValue: string): boolean;
var
   path: string;
   owner: TObject;
   info: PPropInfo;
   n: integer;
   code: integer;
   text: string;
   realValue: double;
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

   (* ASKED BEFORE ANY ARM ASSIGNS, so a refusal leaves the property exactly
     as it was. See RegisterSettingValueCheck. *)
   if not ValueIsAcceptable(path, text) then
      begin
      Exit;
      end;

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

      tkChar, tkWChar, tkUChar:
         begin
         (* EXACTLY WHAT CheckCommand TOOK: its ctChar arm is a single
           statement, `PAnsiChar(crAddress)^ := CustomCMD[1]` -- the first
           character, with no validation of any kind. So an empty value is
           the only thing refused here, and it is refused rather than
           read past the end of the string as the old arm would.

           NOT TRIMMED, unlike every other arm. A key is one character and
           a space is a legal one; trimming would turn a configured space
           bar into a refusal. *)
         if aValue = '' then
            begin
            Exit;
            end;
         SetOrdProp(owner, info, Ord(aValue[1]));
         Result := True;
         end;

      (* A REAL. The old ctReal arm did exactly this -- Val, and refuse
        the line if it does not parse -- and its RANGE check is a
        registered value check now, because a double has no subrange to
        carry one. See RegisterSettingValueCheck. *)
      tkFloat:
         begin
            Val(text, realValue, code);
            if code <> 0 then
               begin
               Exit;
               end;
            SetFloatProp(owner, info, realValue);
            Result := True;
         end;

      tkEnumeration:
         begin
         (* THE REGISTERED VOCABULARY FIRST, BY POSITION. A config file says
           QSO POINTS where the enum member is Points, so GetEnumValue would
           answer -1 for a value the program has always accepted. Falling
           through to it still serves an enum whose members ARE spelled the
           way the file spells them. *)
         n := IndexOfRegisteredValue(path, text);
         if n < 0 then
            begin
            n := GetEnumValue(info^.PropType, AnsiString(text));
            end;
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
   spellings: TArray<string>;
   n: integer;
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
      tkChar, tkWChar, tkUChar:
         begin
         aValue := Char(GetOrdProp(owner, info));
         Result := True;
         end;

      tkEnumeration:
         begin
         (* RENDERED FROM THE VOCABULARY, for the reason the setter reads from
           it: GetEnumName would write `Points` into a config file, which no
           TR4W has ever accepted back. *)
         spellings := RegisteredValuesFor(path);
         n := GetOrdProp(owner, info);
         if (spellings <> nil) and (n >= 0) and (n <= High(spellings)) then
            begin
            aValue := spellings[n];
            end
         else
            begin
            aValue := string(GetEnumName(info^.PropType, n));
            end;
         Result := True;
         end;
      tkString, tkLString, tkAString, tkUString, tkWString:
         begin
         aValue := string(GetStrProp(owner, info));
         Result := True;
         end;
   end;
end;

class function TSettingsGroup.IsContestScoped: boolean;
begin
   Result := False;
end;

class function TBandSettings.IsContestScoped: boolean;
begin
   (* FCONTEST assigns all three the moment a contest loads. *)
   Result := True;
end;

(* DROP A CONTEST-SCOPED GROUP ON THE WAY OUT.

  fpjsonrtti raises this after building each property's JSON and takes the
  value back by reference; ObjectToJSON then skips a nil, so freeing it and
  nilling it removes the property cleanly rather than writing an empty
  object. Verified against fpjsonrtti.pp -- StreamProperty calls the event
  last, and ObjectToJSON guards with `If (PD<>Nil)`.

  THE GROUP IS STILL PUBLISHED, and must be: the RTTI walk that derives
  command names reads published properties, so un-publishing it would
  remove HF BAND ENABLE from the vocabulary as well as from the file. What
  changes is where the VALUE lives, not whether the command exists. *)
(* THE TYPE NAME IS THE MARK. See TSecretText. *)
function IsSecretProperty(const aInfo: PPropInfo): boolean;
begin
   Result := (aInfo <> nil) and
             UnicodeSameText(string(aInfo^.PropType^.Name), 'TSecretText');
end;

function IsCaseSensitiveProperty(const aInfo: PPropInfo): boolean;
begin
   Result := (aInfo <> nil) and
             (IsSecretProperty(aInfo) or
              UnicodeSameText(string(aInfo^.PropType^.Name),
                              'TCaseSensitiveText'));
end;

(* Resolve a command to its property so the two questions below can be asked
  of a NAME, which is what every caller actually holds. *)
function TR4WSettings.PropertyForCommand(const aCommand: string): PPropInfo;
var
   path: string;
   owner: TObject;
begin
   Result := nil;
   path := PathForCommand(aCommand);
   if path = '' then
      begin
      Exit;
      end;
   if not ResolvePath(Self, path, owner, Result) then
      begin
      Result := nil;
      end;
end;

function TR4WSettings.AllowedValuesForCommand(const aCommand: string): TArray<string>;
const
   (* A DROP-DOWN, NOT AN ESSAY. The allow-lists this replaces were four to
     fifteen values; a bound of 64 is well clear of them and still refuses to
     build a list for a range like 0..65535, which is a text box. *)
   MAX_OFFERED = 64;
var
   info: PPropInfo;
   lo, hi, i: integer;
begin
   (* A REGISTERED VOCABULARY WINS. It is the only thing that can describe a
     list that is not a range, and where one exists the subrange below would
     be a wider, wronger answer. *)
   Result := RegisteredValuesFor(PathForCommand(aCommand));
   if Result <> nil then
      begin
      Exit;
      end;

   info := PropertyForCommand(aCommand);
   if (info = nil) or (info^.PropType^.Kind <> tkInteger) then
      begin
      Exit;
      end;

   with GetTypeData(info^.PropType)^ do
      begin
      lo := MinValue;
      hi := MaxValue;
      end;

   if (hi <= lo) or (hi - lo + 1 > MAX_OFFERED) then
      begin
      Exit;
      end;

   SetLength(Result, hi - lo + 1);
   for i := lo to hi do
      begin
      Result[i - lo] := IntToStr(i);
      end;
end;

function TR4WSettings.CommandIsSecret(const aCommand: string): boolean;
begin
   Result := IsSecretProperty(PropertyForCommand(aCommand));
end;

function TR4WSettings.CommandIsCaseSensitive(const aCommand: string): boolean;
begin
   Result := IsCaseSensitiveProperty(PropertyForCommand(aCommand));
end;

(*
  THE NAME A SECRET IS FILED UNDER, and it must not move.

  The group knows its own path and the property knows its name, so the two
  together give 'Hamscore.Password' -- the same string the reader will build,
  and the same one an operator sees in Credential Manager. A name derived any
  other way would risk differing between the save and the load, which on
  Windows means the password is written to one entry and looked for in
  another.
*)
function SecretNameFor(const aObject: TObject;
                       const aInfo: PPropInfo): string;
begin
   if aObject is TSettingsGroup then
      begin
      Result := TSettingsGroup(aObject).Path + '.' + string(aInfo^.Name);
      end
   else
      begin
      Result := string(aInfo^.Name);
      end;
end;

procedure TR4WSettings.SkipContestScoped(aSender: TObject; aObject: TObject;
                                         aInfo: PPropInfo; var aResult: TJSONData);
var
   child: TObject;
begin
   if (aResult = nil) or (aInfo^.PropType^.Kind <> tkClass) then
      begin
      Exit;
      end;

   child := GetObjectProp(aObject, aInfo);
   if (child is TSettingsGroup) and TSettingsGroup(child).IsContestScoped then
      begin
      FreeAndNil(aResult);
      end;
end;

function TR4WSettings.ToJSON: TJSONObject;
var
   streamer: TJSONStreamer;
begin
   streamer := TJSONStreamer.Create(nil);
   try
      (* NO @ -- this tree compiles in Delphi mode (forced by Indy), where a
        method is assigned to an event by name. The address-of form is the
        objfpc spelling and is a syntax error here. *)
      streamer.OnStreamProperty := SkipContestScoped;
      (* jsoStreamChildren is what makes the nested objects appear at all --
        without it a child object property is skipped in silence, which reads
        as "that area has no settings" rather than as an error. *)
      streamer.Options := streamer.Options + [jsoStreamChildren];
      Result := streamer.ObjectToJSON(Self);
   finally
      streamer.Free;
   end;

   (* AND THE SECRETS ARE PROTECTED IN THE FINISHED DOCUMENT.

     NOT IN THE STREAMER'S HOOK, and the first version tried exactly that.
     Replacing a string property's value from inside OnStreamProperty
     produced a document whose own AsJSON recursed until the stack gave out
     -- both values were computed correctly and the hook ran to completion,
     so the fault surfaced nowhere near its cause. Adding a WriteLn made it
     disappear, which is the signature of a lifetime or aliasing problem
     rather than a logic one.

     It is not worth winning that fight. The document is plain data once it
     exists, and editing it is something anyone can read and a test can
     pin -- which is also why the load side has always done its work
     afterwards rather than during (see ClampToDeclaredRanges). *)
   ProtectSecretsInDocument(Result);
end;

(*
  PUT EVERY SECRET IN THE VAULT AND LEAVE A REFERENCE BEHIND.

  THE VALUE MEMBER IS REMOVED AND `<Name>Ref` IS ADDED, so the file carries
  the SETTING'S NAME and never the password:

      "Password"    gone
      "PasswordRef" "Hamscore.Password"

  A SEPARATE MEMBER RATHER THAN A TAG INSIDE THE VALUE. An earlier version
  wrote scheme:reference, and NY4I rejected the shape: it reads like web
  basic authentication, and it cannot be told apart from a password that
  happens to contain a colon. A member name has no such ambiguity.

  IF THE VAULT REFUSES, NEITHER MEMBER IS WRITTEN. The password is not put
  anywhere weaker and not left in the file in the clear -- it is kept for the
  session and asked for again, and the keychain reports why.
*)
procedure TR4WSettings.ProtectSecretsInDocument(const aDoc: TJSONObject);

   procedure Walk(const aObj: TObject; const aNode: TJSONObject;
                  const aPrefix: string);
   var
      props: PPropList;
      count, i, idx: integer;
      info: PPropInfo;
      child: TObject;
      childNode: TJSONData;
      name: string;
      secretName: string;
      plainValue: string;
   begin
      if aNode = nil then
         begin
         Exit;
         end;
      count := GetPropList(aObj.ClassInfo, props);
      if count = 0 then
         begin
         Exit;
         end;
      try
         for i := 0 to count - 1 do
            begin
            info := props^[i];
            name := string(info^.Name);
            (* UTF8Encode, EXPLICITLY. A JSON member name is a UTF8String and
              a property name is a native string; a property name is ASCII,
              but saying so once beats an implicit conversion the ratchet has
              to forgive. *)
            idx := aNode.IndexOfName(UTF8Encode(name));
            if idx < 0 then
               begin
               Continue;
               end;

            if info^.PropType^.Kind = tkClass then
               begin
               child := GetObjectProp(aObj, info);
               childNode := aNode.Items[idx];
               if (child <> nil) and (childNode is TJSONObject) then
                  begin
                  Walk(child, TJSONObject(childNode), aPrefix + name + '.');
                  end;
               end
            else if IsSecretProperty(info) then
               begin
               secretName := aPrefix + name;
               plainValue := GetUnicodeStrProp(aObj, info);

               (* THE VALUE LEAVES THE DOCUMENT EITHER WAY. Whether the vault
                 took it or refused, the password does not go in the file. *)
               aNode.Delete(idx);

               if StoreSecret(secretName, plainValue) then
                  begin
                  aNode.Add(UTF8Encode(name + KEYCHAIN_REF_SUFFIX),
                            UTF8Encode(secretName));
                  end;
               end;
            end;
      finally
         FreeMem(props);
      end;
   end;

begin
   Walk(Self, aDoc, '');
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
        whole of the forward-compatibility story -- see the unit header.

        IT IS ALSO WHAT MAKES A <Name>Ref MEMBER HARMLESS HERE: no property
        is called that, so the de-streamer skips it and the load pass below
        reads it. *)
      destreamer.JSONToObject(aObj, Self);
   finally
      destreamer.Free;
   end;
   (* THE STREAMER DOES NOT KNOW ABOUT SUBRANGES -- it writes whatever ordinal
     the file carried.  This is the one place an untrusted value reaches a
     property without passing TrySetByCommand, so it is the one place the
     ranges have to be re-imposed. *)
   ClampToDeclaredRanges;
   (* AND THE SECRETS COME OUT OF THE VAULT, for the same reason the ranges
     are re-imposed here: the de-streamer assigned what the file carried, and
     for a secret the file carries nothing. *)
   UnprotectSecretsAfterLoad;
end;

procedure TR4WSettings.UnprotectSecretsAfterLoad;

   procedure Walk(const aObj: TObject; const aPrefix: string);
   var
      props: PPropList;
      count, i: integer;
      info: PPropInfo;
      child: TObject;
      path: string;
      plain: string;
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
            else if IsSecretProperty(info) then
               begin
               (*
                 WHAT THE DE-STREAMER LEFT IN THE PROPERTY DECIDES WHICH
                 CASE THIS IS.

                 It assigned whatever member matched the property name. For a
                 file this build wrote there is no such member -- only
                 <Name>Ref, which the de-streamer ignored -- so the property
                 is EMPTY and the value comes from the vault.

                 A NON-EMPTY PROPERTY IS A PLAINTEXT PASSWORD from before any
                 of this, and it is left exactly as it is. The next save puts
                 it in the vault and removes it from the file. That is the
                 whole of the upgrade path, and it needs no flag day.
               *)
               if GetUnicodeStrProp(aObj, info) <> '' then
                  begin
                  Continue;
                  end;

               (* A REFUSAL LEAVES THE SETTING EMPTY, deliberately. The store
                 says what went wrong -- a revoked credential, a file from
                 another machine -- and an empty password asks the operator
                 for it again, where a half-read one would be sent to a
                 server. *)
               if FetchSecret(path, plain) then
                  begin
                  SetUnicodeStrProp(aObj, info, plain);
                  end
               else
                  begin
                  SetUnicodeStrProp(aObj, info, '');
                  end;
               end;
            end;
      finally
         FreeMem(props);
      end;
   end;

begin
   Walk(Self, '');
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
const
   (* THE SPELLINGS A CONFIG FILE USES FOR RateDisplayType, in ORDINAL ORDER
     -- position is the value. This is the table logwind carried, as `string`
     rather than PAnsiChar.

     Here rather than beside the type, and that is a language constraint
     rather than a choice: the interface's type section carries a forward
     `TR4WSettings = class`, and FPC requires a forward class to be completed
     in the SAME type block. Opening a const block partway through ends it. *)
   RATE_DISPLAY_SPELLINGS: array[RateDisplayType] of string =
      ('QSOS', 'QSO POINTS', 'BAND QSOS');
   HOUR_DISPLAY_SPELLINGS: array[HourDisplayType] of string =
      ('THIS HOUR', 'LAST SIXTY MINUTES', 'BAND CHANGES',
       'BAND CHANGES ON THIS COMPUTER');
   TEN_MINUTE_RULE_SPELLINGS: array[TenMinuteRuleType] of string =
      ('NONE', 'TIME OF FIRST QSO');
   BAND_MAP_SPLIT_MODE_SPELLINGS: array[BandMapSplitModeType] of string =
      ('BY CUTOFF FREQ', 'ALWAYS PHONE');
   DISTANCE_MODE_SPELLINGS: array[DistanceDisplayType] of string =
      ('NONE', 'MILES', 'KM');
   REMAINING_MULT_DISPLAY_SPELLINGS:
      array[RemainingMultDisplayModeType] of string =
      ('NONE', 'ERASE', 'HILIGHT');
   DUPE_CHECK_SOUND_SPELLINGS: array[DupeCheckSoundType] of string =
      ('NONE', 'DUPE BEEP', 'MULT FANFARE');
   (* Was tLogLevelsSA in VC. UPPERCASE, as its comment there said. *)
   LOG_LEVEL_SPELLINGS: array[tLogLevels] of string =
      ('NONE', 'FATAL', 'ERROR', 'WARN', 'INFO', 'DEBUG', 'TRACE');
   POSSIBLE_CALL_MODE_SPELLINGS: array[PossibleCallActionType] of string =
      ('ALL', 'NAMES', 'LOG ONLY');
   USER_INFO_SPELLINGS: array[UserInfoType] of string =
      ('NONE', 'NAME', 'QTH', 'CHECK SECTION', 'SECTION', 'OLD CALL',
       'FOC NUMBER', 'GRID', 'CQ ZONE', 'ITU ZONE', 'USER 1', 'USER 2',
       'USER 3', 'USER 4', 'USER 5', 'CUSTOM');

initialization
   (* THE VOCABULARY OF EVERY ENUMERATED SETTING THIS UNIT OWNS.

     Here rather than in uCFG, unlike the two integer allow-lists: those read
     const arrays that unit still owns, and this table moved with its type. An
     initialization section runs before any configuration is read, so the
     spellings are in force for the first line of the first file. *)
   RegisterSettingAllowedValues('MainWindow.RateDisplay',
                                RATE_DISPLAY_SPELLINGS);
   RegisterSettingAllowedValues('MainWindow.HourDisplay',
                                HOUR_DISPLAY_SPELLINGS);
   RegisterSettingAllowedValues('Operating.TenMinuteRule',
                                TEN_MINUTE_RULE_SPELLINGS);
   RegisterSettingAllowedValues('BandMap.SplitMode',
                                BAND_MAP_SPLIT_MODE_SPELLINGS);
   RegisterSettingAllowedValues('Log.DistanceMode',
                                DISTANCE_MODE_SPELLINGS);
   RegisterSettingAllowedValues('RemainingMults.DisplayMode',
                                REMAINING_MULT_DISPLAY_SPELLINGS);
   RegisterSettingAllowedValues('Operating.DupeCheckSound',
                                DUPE_CHECK_SOUND_SPELLINGS);
   RegisterSettingAllowedValues('Log.DebugLevel', LOG_LEVEL_SPELLINGS);
   RegisterSettingAllowedValues('Scp.PossibleCallMode',
                                POSSIBLE_CALL_MODE_SPELLINGS);
   RegisterSettingAllowedValues('MainWindow.UserInfoShown',
                                USER_INFO_SPELLINGS);

finalization
   FreeSettings;

end.

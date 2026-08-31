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
{$I tr4w.inc}

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
   SysUtils,
   StrUtils,      // StartsText, for the section-name prefixes
   Classes,
   uFileText,            // whole-file UTF-8 read/write -- see the BOM note in that unit
   IniFiles,
   uJSON,          // the format of record for settings\tr4w.json
   Generics.Collections;

const
   // "Let the radio decide."  Distinct from 0, which is the operator saying
   // OFF -- see TRadioDefinition.AutoInfoLevel.
   AUTOINFO_RADIO_DEFAULT = -1;

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
   { ONE DX CLUSTER the operator connects to.

     NOT A FACTORY, and NY4I was explicit about why: "I am not suggesting that
     the user would state the type of cluster it is.  The user is just connected
     to one cluster at a time.  But they may want to have a list of frequently
     connected servers they use stored with different credentials for each."

     So there is no protocol type here and no driver -- every cluster is telnet.
     What varies is the SERVER AND THE CREDENTIALS, which is a library, not
     polymorphism.  I had proposed carrying a type discriminator "so it can grow
     into a factory"; that would have been a field nobody sets, answering a
     question nobody asked.

     Credentials are PER SERVER because they genuinely differ: a reverse-beacon
     node wants a bare callsign, a club cluster may want a password, and an
     operator with two calls logs into different clusters as different
     stations. }
   TClusterDefinition = class(TObject)
   public
      // What the operator calls it.  The key, and what the drop-down shows.
      Name: string;
      // 'dxc.nc7j.com:7373' -- host and optional port, the spelling
      // TRCLUSTER.DAT uses so an entry can be pasted straight in.
      Server: string;
      // The callsign to log in AS.  Blank means "my station callsign", which is
      // what nearly everyone wants and nobody should have to type twice.
      LoginCall: string;
      Password: string;
      // Sent after the login is accepted -- filters, set/name, sh/dx.
      ConnectCommand: string;

      procedure Assign(const aOther: TClusterDefinition);
   end;

   { ONE ROTATOR the operator has defined.  Shaped like TRadioDefinition on
     purpose: the operator's mental model is the same -- a thing with a name,
     a type, and how it is connected -- and reusing the shape means the
     Add/Edit/Remove machinery reads the same way on both pages.

     BANDS is the part that is NOT like a radio.  NY4I: "I could see a case of
     defining a band to a rotator and when we tell the program to turn the
     rotator for a contact on 20m, it knows to turn the Orion rotator but on 40
     meters, it turns the Yaesu rotator."  So rotators are not "define many,
     activate one" like radios -- they are "define many, each responsible for
     some bands", which is a different SELECTION model and the reason this
     carries a band list rather than being chosen by a profile. }
   { ONE BAND'S ENTRY IN THE BAND PLAN.

     Three numbers per band, and the ini shape they replace could express none
     of that directly: [BAND PLAN] held REPEATED keys -- twelve
     `BAND MAP CUTOFF FREQUENCY=` lines and up to twenty-four
     `FREQUENCY MEMORY=` ones -- with the band DERIVED from each frequency by
     CalculateBandMode, and the phone memory told apart from the CW one by an
     'SSB ' prefix inside the value. That works, but nothing about the file says
     what it means, and a value that lands in the wrong band is invisible.

     Keyed by the band SPELLING rather than a BandType, because this unit
     deliberately knows nothing about the program's types -- the same reason
     HEADER_SECTIONS repeats its section names as literals. uRadioConfigApply
     maps the spelling to a band; it is the half that is allowed to know. }
   TBandPlanEntry = class(TObject)
   public
      // The band spelling, as BandStringsArrayWithOutSpaces writes it: '160',
      // '80' ... '2'.  Not an ordinal: an ordinal silently re-points at a
      // different band the day the enum gains a member.
      Band: string;

      // 0 means NOT SET, and is not written to the file.  That distinction is
      // the whole reason these are not simply zeroed defaults: the editor
      // leaves a band's stored value alone when its cell is not a number, and
      // an absent entry has to survive the round trip to keep doing that.
      Cutoff: integer;    // BAND MAP CUTOFF FREQUENCY -- CW/data above, phone below
      CW: integer;        // FREQUENCY MEMORY
      SSB: integer;       // FREQUENCY MEMORY, with the old 'SSB ' prefix
   end;

   { ONE MAIN-WINDOW ELEMENT'S COLORS.

     Fifty elements, each with a foreground and a background drawn from a fixed
     18-entry palette.  They were never CFGCA rows: CheckCommand matches them by
     PREFIX against TWindows[..].mweName, so "CALLSIGN COLOR" and "CALLSIGN
     BACKGROUND" are recognised without either existing in any table.

     SPELLINGS, not ordinals -- 'YELLOW', not 15.  An ordinal silently
     re-points at a different color the day the palette gains an entry, and
     trBtnFace and trAlert were both added to the end of that enum at some
     point. }
   TElementColors = class(TObject)
   public
      Element: string;    // mweName, e.g. 'CALLSIGN'
      Foreground: string; // a tr4wColorsSA spelling, '' meaning not set
      Background: string;
   end;

   TRotatorDefinition = class(TObject)
   public
      // THE KEY -- see TRadioDefinition.Id. Note this is NOT RotatorId below,
      // which is the MODEL ('YAESU', 'ORION'); this identifies THIS rotator.
      //
      // It matters more here than anywhere else: the rotator editor writes
      // r.Name on EVERY KEYSTROKE in the name box, so a rename is not an event
      // that can be hooked -- it is a continuous stream of them, and the active
      // rotator was tracked by that same name.
      Id: string;
      Name: string;
      // Registry id from uRotatorRegistry: 'YAESU', 'ORION', 'DCU1',
      // 'ALFA SPID', 'PSTROTATOR'.  Opaque here -- the store knows no protocol.
      RotatorId: string;

      // Serial rotators.  The PortTypeSA vocabulary ('SERIAL 15'), the NAME and
      // never a combo index -- an index re-points at a different port the day
      // the list changes, which is the trap the radio store documents.
      ControlPort: string;
      // 0 means "whatever the driver prefers" -- the DCU-1 wants 4800 and the
      // rest 9600, and that is the driver's business, not a number the operator
      // should have to know.
      BaudRate: integer;

      // PstRotator is UDP and has no port at all.
      IPAddress: string;
      UDPPort: integer;

      // Which bands this rotator turns for.  EMPTY MEANS ALL BANDS, which is
      // the right default for the overwhelmingly common case of one rotator:
      // an operator with a single antenna should not have to tick eleven boxes
      // to make it work.
      Bands: string;

      procedure Assign(const aOther: TRotatorDefinition);

      constructor Create;
   end;

   TRadioDefinition = class(TObject)
   public
      // THE KEY, and it is not the name.  A profile refers to a radio by Id, so
      // renaming is a non-event: nothing else has to be found and fixed.
      //
      // It used to be the Name, and that cost NY4I a profile: renaming K4Z to
      // K40 left the active profile pointing at a radio that no longer existed
      // (2026-08-28).  "Changeable names are not good for keys in any context.
      // GUID is cheap and universally unique."
      //
      // Assigned when the radio is created and never rewritten.  A store read
      // from an older file has none, so one is minted on load -- see LoadRadios.
      Id: string;
      // What the OPERATOR sees and types.  Unique within a store because two
      // radios called K3 would be unusable in the combo boxes, not because
      // anything keys on it.
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
      // FUTURE (NY4I 2026-08-05): these four are properties of a KEYER, not of
      // a radio, and they are here only because that is where the legacy config
      // keys put them.  The intended shape is the one this unit already uses for
      // radios -- a library of DEFINED keyers (WinKeyer, YCCC, CPU/LPT,
      // CW-by-CAT), each with its own name, port and line settings, with the
      // radio naming one.  Then "which keyer does this radio use" is a
      // reference, exactly like "which radio is in slot 1".
      //
      // GATED ON the CW keyer settings arriving in Preferences.  Doing it
      // earlier would leave a keyer defined in one place and configured in
      // another, which is worse than the present arrangement.
      //
      // Worth folding in at the same time: ActiveCWKeyer's precedence chain
      // (CAT -> WinKeyer -> YCCC -> CPU) is an artifact of the original if/else
      // ordering rather than a decision, and a named keyer reference turns it
      // into a lookup -- which is what the proposed "CW INTERFACE" command was
      // for.  See docs\CW_Keyer_Factory_Plan.md.
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
      StartupCommand: string;
      PollingEnable: boolean;
      // Auto-info level.  The radio pushes state changes instead of being
      // polled for them.  Per RADIO, not per station: a K3 and a K2 on the
      // same desk can want different levels, and what a level MEANS is the
      // driver's business.
      //
      //   -1  let the RADIO decide (the default, and what a new definition
      //       gets) -- an Elecraft chooses 2, anything else ignores it
      //    0  explicitly OFF: poll for everything, the historic behaviour
      //   1+  an explicit level the operator has chosen
      //
      // The three-way split exists because "off" and "not chosen" are
      // different answers, and collapsing them would mean a driver could
      // never have a default of its own.
      AutoInfoLevel: integer;

      constructor Create;
      procedure Assign(const aSource: TRadioDefinition);
      function Clone: TRadioDefinition;
      // Field-by-field equality, so a dialog can answer "did the operator
      // actually change anything" without tracking a dirty flag on fifteen
      // controls -- a flag that is wrong the moment someone adds a sixteenth
      // and forgets to wire it.  Name is included: renaming IS a change.
      function SameAs(const aOther: TRadioDefinition): boolean;

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
      { THE REFERENCE IS THE ID. The two names below are a MIRROR kept for the
        file to stay readable and for a store written by this build to remain
        openable by an older one -- nothing resolves through them except the
        migration of a file that predates ids. }
      Radio1Id: string;
      Radio2Id: string;
      Radio1Name: string;
      Radio2Name: string;
      DefaultActiveSlot: integer;   // 1 or 2
      // CW output per slot: 'CAT', 'NONE', or the NAME of a keyer device.
      //
      // SENTINEL AND REFERENCE IN ONE FIELD, which is why the keyer id lives
      // beside it rather than replacing it: 'CAT' and 'NONE' are answers, not
      // devices, and they have no id to hold.
      CWOutput1: string;
      CWOutput2: string;
      // The keyer's Id when CWOutput names a device, and '' for CAT and NONE.
      // THIS is the reference; the name above is the readable mirror, refreshed
      // from the id on save so the two cannot disagree.
      CWOutput1Id: string;
      CWOutput2Id: string;
      SpeedSync1: boolean;
      SpeedSync2: boolean;
      SO2REnabled: boolean;

      constructor Create;
      procedure Assign(const aSource: TStationProfile);
      function Clone: TStationProfile;
      function SameAs(const aOther: TStationProfile): boolean;
      // Slot lookup without the caller writing the same if/else every time.
      function RadioIdForSlot(const aSlot: integer): string;
      function RadioNameForSlot(const aSlot: integer): string;
      function ReferencesRadioId(const aRadioId: string): boolean;
      function ReferencesRadio(const aRadioName: string): boolean;
   end;

   { The library itself: radios, profiles, and which profile is active. }
   TRadioConfigStore = class(TObject)
   private
      FRadios: TObjectList<TRadioDefinition>;
      FRotators: TObjectList<TRotatorDefinition>;
      FBandPlan: TObjectList<TBandPlanEntry>;
      FColors: TObjectList<TElementColors>;
      FClusters: TObjectList<TClusterDefinition>;
      FActiveClusterName: string;
      { The rotator that turns. ONE at a time (NY4I, 2026-08-16).

        Before this, ConfigureRotators made EVERY defined rotator live and
        TurnRotator turned every one whose band claim matched -- and a blank
        claim matches every band. Two rotators with blank Bands therefore both
        received every command, with nothing on screen saying so: the list
        selection only chose which one you were EDITING.

        By NAME, like ActiveClusterName, so renaming the active one has to carry
        this with it; an index would silently re-point at whatever moved into
        the slot. }
      FActiveRotatorName: string;
      { The reference. FActiveRotatorName above is the readable mirror. }
      FActiveRotatorId: string;
      { The contest .cfg last opened. NOT a setting -- it is bookkeeping, which
        is why it lives in `general` beside activeProfile rather than in
        `commands`, and why it is deliberately absent from Preferences and from
        the search index. It moved here from tr4w.ini (NY4I, 2026-08-16): that
        one WritePrivateProfileString was the only thing recreating the ini
        file, so a station whose settings had all reached the JSON still got an
        ini back on every start. }
      FLatestConfigFile: string;
      { Whether TR4W has already offered to set MY GRID.  Asked ONCE per
        installation, not once per start: an operator who does not want a grid
        should not be asked again every time they open the program, and one who
        does can set it in Preferences > Station, where it is also searchable. }
      FGridPromptShown: boolean;
      { The export headers -- tr4w.ini's [REPORT] and [ERMAKREPORT] sections,
        moved here. One Name=Value list per section, using the same _TAG
        spellings the ini used, so the tag table in uCbrSum stays the single
        source of truth for what a header contains.
        NOT settings: they are not CFGCA rows, were never registered, and do not
        appear in Preferences or the search index. See uCabrilloHeader.

        A MAP rather than a field per section: ERMAK is the same kind of thing
        as the Cabrillo header -- the Russian format's own header block, written
        by the same dialog with FormatSpecification swapped -- so giving it its
        own field would have duplicated the load/save/seed path that already
        exists, and the two copies would drift. }
      FHeaders: TStringList;   // section name -> TStringList, owned
      FProfiles: TObjectList<TStationProfile>;
      FActiveProfileName: string;
      FAutoConnectOnStartup: boolean;
      FKeepLegacyIni: boolean;

      // TCI SERVER -- ITS OWN SECTION, not three more keys in "general".
      //
      // Enabled started life as general.tciServer, which was wrong for a reason
      // that only became visible when the second setting arrived: general is a
      // junk drawer, and a subsystem with five settings is not a general
      // setting (NY4I spotted it in the file).  udpBroadcast is already a
      // top-level section and TCI is the same KIND of thing -- a network
      // service TR4W offers -- so it gets the same treatment.
      //
      // Debug and MaxTxSeconds were in tr4w.ini only because they had nowhere
      // else to live; they are the reason this could not stay as it was.
      FTCIServerEnabled: boolean;
      FTCIPort: integer;
      FTCIBindAll: boolean;
      FTCIDebug: boolean;
      FTCIMaxTxSeconds: integer;

      // LOGGING -- consolidated here because it was "all over the place"
      // (NY4I): a level in one ini key, three HamLib switches in others, a
      // telnet switch in another, and TCI's in a third file.  The Preferences
      // Logging section is the one place, so the store needs one home for it.
      //
      // THE LEVEL IS STORED AS ITS SPELLING, NOT ITS ORDINAL.  tLogLevels is a
      // Pascal enum; writing 5 to the file would silently change meaning the
      // day anyone inserts a level in the middle, and the operator reading
      // their own settings file would learn nothing from "5".  'DEBUG' is
      // stable under reordering and is the same vocabulary the ini used, so an
      // old value pasted into the new file still means what it says.
      FLogLevelName: string;
      FHamLibDebug: boolean;
      FHamLibAsyncOnly: boolean;
      FHamLibTrace: boolean;
      FTelnetDebug: boolean;

      // Was there a logging section in the file we loaded?
      //
      // This is the MIGRATION SIGNAL, and it is needed because these settings
      // are not being renamed within this file (as tci.enabled was) -- they are
      // arriving from tr4w.ini, a different file this unit deliberately knows
      // nothing about.  So the store cannot do the fallback itself; it can only
      // report "I had nothing to load", and the apply layer -- which can read
      // the ini -- seeds from there exactly once.  Without this an operator
      // with DEBUG LOG LEVEL = DEBUG in their ini would silently drop to INFO
      // on upgrade, at the moment they were trying to diagnose something.
      FHasLoggingSection: boolean;

      // RETIRED CFGCA ROWS, name -> value.
      //
      // A generic map rather than a hand-written field per setting, because
      // "everything moves to JSON" (NY4I) means ~400 CFGCA rows eventually
      // land here and a field each is not a plan.  The KEY IS THE COMMAND
      // NAME exactly as CFGCA spells it ('MY SECTION'), so there is no
      // second vocabulary to drift: the applier hands each pair straight
      // back to CheckCommand, which already knows the type, the bounds and
      // the hook.
      //
      // Structured sections (radios, profiles, keyers, tci, logging) stay
      // structured -- those are objects with shape, not flat legacy rows.
      FCommands: TStringList;
      procedure LoadRadio(const aIni: TCustomIniFile; const aSection, aName: string);
      procedure SaveRadio(const aIni: TCustomIniFile; const aRadio: TRadioDefinition);
      procedure LoadProfile(const aIni: TCustomIniFile; const aSection, aName: string);
      procedure SaveProfile(const aIni: TCustomIniFile; const aProfile: TStationProfile);
      // Frees the per-section lists FHeaders owns.  TStringList.OwnsObjects is
      // not relied on: it is a property this code would have to remember to set,
      // and forgetting it leaks silently rather than failing.
      procedure ClearHeaders;
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
      function FindRadioById(const aId: string): TRadioDefinition;
      function SetProfileRadioByName(const aProfile: TStationProfile;
                                     const aSlot: integer;
                                     const aName: string): boolean;
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
      // JSON is the format of record (settings\tr4w.json).  The ini pair below
      // is kept for reading a store written before the move, and for
      // SeedFromLegacyIni, which reads tr4w.ini and always will.
      //
      // A JSON object rather than an ini-shaped adapter, deliberately.  The
      // ini encodes a radio's NAME IN ITS SECTION HEADER ('[Radio.K3]'), so a
      // name has to survive being an ini section -- brackets, '=' and leading
      // or trailing spaces are all hazards there and none of them are hazards
      // in a value.  Radios and profiles are therefore JSON ARRAYS whose name
      // is an ordinary field.
      //
      // aRoot is the CALLER'S in both directions: LoadFromJSON does not free
      // it, and SaveToJSON returns a new object the caller owns.
      procedure LoadFromJSON(const aRoot: TJSONObject);
      function  SaveToJSON: TJSONObject;

      // Whole-file convenience.  LoadFromFile returns False when the file is
      // absent or unreadable so the caller can fall back to a migration, and
      // raises nothing on malformed JSON -- a corrupt settings file must not
      // stop the program from starting.
      function  LoadFromFile(const aFileName: string; out aError: string): boolean;

      { WRITES ONLY THIS STORE'S SECTIONS, and so is NOT the way to save the
        configuration file.

        tr4w.json also holds the keyer library and the UDP settings, which this
        object knows nothing about -- so calling this drops them.  Two callers
        added on 2026-08-21 did exactly that: saving a band plan would have
        deleted every configured keyer.

        uTR4WConfigFile.SaveConfig is the ONE writer.  It preserves the sections
        it was not given, so `SaveConfig(file, store, nil, nil)` writes this
        store and leaves the others alone.  Kept public only because SaveConfig
        itself and the unit tests use it; call it from nowhere else.
        (NY4I, 2026-08-22: "two paths to write anything is a bad idea.") }
      procedure SaveToFile(const aFileName: string);

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

      { The operator was offered the removal of a now-unused tr4w.ini and said
        no.  Recorded so the question is asked ONCE: a prompt that returns every
        start is not a choice, it is nagging. }
      property KeepLegacyIni: boolean read FKeepLegacyIni write FKeepLegacyIni;

      // Offers a TCI server so other programs can reach the radio THIS
      // program has the COM port open on.  Station-wide, not a property of any
      // one radio or profile -- which is why it is NOT inside the radios
      // array.  See the field declarations for why it has its own section
      // rather than sitting in "general".
      property TCIServerEnabled: boolean read FTCIServerEnabled write FTCIServerEnabled;
      // ZERO MEANS "THE SERVER'S DEFAULT", not port zero.
      //
      // The store deliberately does NOT name 50001.  That constant belongs to
      // uTCIServer, and this unit's uses clause is pure RTL on purpose --
      // uTestRadioConfigStore links it standalone, so reaching for uTCIServer
      // would drag LOGRADIO and MainUnit into the test EXE to learn one
      // integer.  Copying the number here instead would be two defaults for
      // one setting, which is the duplication this whole section exists to
      // remove.  So the sentinel says "not chosen" and the apply layer, which
      // can see both, substitutes the real default -- the same idiom as
      // AutoInfoLevel's negative "you decide".
      property TCIPort: integer read FTCIPort write FTCIPort;
      property TCIBindAll: boolean read FTCIBindAll write FTCIBindAll;
      property TCIDebug: boolean read FTCIDebug write FTCIDebug;
      property TCIMaxTxSeconds: integer read FTCIMaxTxSeconds write FTCIMaxTxSeconds;

      // Logging.  The level is a SPELLING ('NONE'..'TRACE') -- see the field.
      // The store does not know tLogLevels exists; translating the spelling to
      // the enum is the apply layer's job, for the same reason it owns the TCI
      // globals: this unit's uses clause stays pure RTL so the store can be
      // unit-tested without linking VC and the world.
      property LogLevelName: string read FLogLevelName write FLogLevelName;
      property HamLibDebug: boolean read FHamLibDebug write FHamLibDebug;
      property HamLibAsyncOnly: boolean read FHamLibAsyncOnly write FHamLibAsyncOnly;
      property HamLibTrace: boolean read FHamLibTrace write FHamLibTrace;
      property TelnetDebug: boolean read FTelnetDebug write FTelnetDebug;

      // False when the loaded file had no logging section -- see the field.
      // Read-only: only a load can answer it.
      property HasLoggingSection: boolean read FHasLoggingSection;

      // Retired CFGCA rows as name=value.  Owned by the store; callers read
      // and write entries but do not free it.
      property Commands: TStringList read FCommands;

      { The rotator library.  Same shape as the radio one -- see AddRadio for
        why Add takes ownership. }
      { THE BAND PLAN.  SetBand is an upsert by spelling, so the editor can
        write every band it has without first asking what is already there, and
        a band whose values are all 0 is REMOVED rather than stored as zeros --
        see TBandPlanEntry on why 0 has to mean absent. }
      { MAIN-WINDOW COLORS.  SetElementColors is an upsert by element name, and
        an entry with neither color set is REMOVED rather than stored blank --
        the same rule as the band plan, and for the same reason: "not set" has
        to mean "leave the compiled default alone". }
      function  ColorCount: integer;
      function  ColorEntry(const aIndex: integer): TElementColors;
      function  FindElementColors(const aElement: string): TElementColors;
      procedure SetElementColors(const aElement, aForeground, aBackground: string);

      function  BandPlanCount: integer;
      function  BandPlanEntry(const aIndex: integer): TBandPlanEntry;
      function  FindBandPlan(const aBand: string): TBandPlanEntry;
      procedure SetBandPlan(const aBand: string; const aCutoff, aCW, aSSB: integer);

      function  RotatorCount: integer;
      function  Rotator(const aIndex: integer): TRotatorDefinition;
      function  IndexOfRotator(const aName: string): integer;
      function  AddRotator(const aRotator: TRotatorDefinition): boolean;
      procedure DeleteRotator(const aIndex: integer);
      { The active rotator, by id, falling back to the name for a store written
        before rotators had one. -1 when there is none. }
      function  IndexOfActiveRotator: integer;
      function  UniqueRotatorName(const aBase: string): string;

      { The cluster library.  One is ACTIVE -- the one TR4W connects to. }
      function  ClusterCount: integer;
      function  Cluster(const aIndex: integer): TClusterDefinition;
      function  IndexOfCluster(const aName: string): integer;
      function  AddCluster(const aCluster: TClusterDefinition): boolean;
      procedure DeleteCluster(const aIndex: integer);
      function  UniqueClusterName(const aBase: string): string;
      function  ActiveCluster: TClusterDefinition;
      property  ActiveClusterName: string read FActiveClusterName write FActiveClusterName;
      property  ActiveRotatorName: string read FActiveRotatorName write FActiveRotatorName;
      property  ActiveRotatorId: string read FActiveRotatorId write FActiveRotatorId;
      property  LatestConfigFile: string read FLatestConfigFile write FLatestConfigFile;
      property  GridPromptShown: boolean read FGridPromptShown write FGridPromptShown;
      { The Name=Value list for one export header section ('REPORT',
        'ERMAKREPORT'). Created on demand, so a caller never has to test for
        nil and an unknown section is an empty header rather than a crash. }
      function  Header(const aSection: string): TStringList;
      function  CommandValue(const aCommand: string; const aDefault: string = ''): string;
      procedure SetCommand(const aCommand, aValue: string);
   end;

const
   // Bumped only when the on-disk schema changes in a way a reader must know
   // about.  Written to [General]; nothing reads it yet, deliberately -- it is
   // here so that a future migration HAS a version to branch on.
   RADIOCONFIG_SCHEMA_VERSION = 1;

   // --- JSON schema ---------------------------------------------------
   // Written on every save and checked on every load.  It exists so that a
   // later shape change can migrate rather than guess: a store with no
   // version predates the field and is not something this code will ever
   // have written.
   JSON_SCHEMA_VERSION   = 1;
   JSONKEY_VERSION       = 'version';
   JSONKEY_GENERAL       = 'general';
   JSONKEY_RADIOS        = 'radios';
   JSONKEY_PROFILES      = 'profiles';
   JSONKEY_NAME          = 'name';
   JSONKEY_TCI           = 'tci';
   JSONKEY_LOGGING       = 'logging';
   JSONKEY_COMMANDS      = 'commands';
   { Commands whose section cannot be derived. Named rather than blank so it is
     obvious in the file that they are unclassified, not misfiled. }
   SECTION_OTHER         = 'other';
   JSONKEY_ROTATORS      = 'rotators';
   JSONKEY_CLUSTERS      = 'clusters';
   JSONKEY_BANDPLAN      = 'bandPlan';
   JSONKEY_COLORS        = 'colors';

type
   TExportHeaderSection = record
      Section: string;     // the ini section name it replaced, and the key callers pass
      JSONKey: string;     // where it lives in tr4w.json
   end;

const
   // THE ONE PLACE THAT SAYS WHICH EXPORT HEADERS EXIST.  Save, load and the
   // one-time ini seed all iterate this, so adding a header section is one row
   // here and nothing else.  The section spellings match CABRILLOSECTION and
   // ERMAKSECTION in VC.pas -- repeated as literals rather than pulling VC into
   // the store, which has no other reason to know about the program's globals.
   HEADER_SECTIONS: array[0..1] of TExportHeaderSection = (
      (Section: 'REPORT';      JSONKey: 'cabrilloHeader'),
      (Section: 'ERMAKREPORT'; JSONKey: 'ermakHeader'));

   // The level TR4W has always shipped with.  A spelling, not an ordinal --
   // see TRadioConfigStore.FLogLevelName.
   LOG_DEFAULT_LEVEL     = 'INFO';

   // Defaults.  MAX TX SECONDS MUST MATCH TR4W_TCI_MAX_TX_SECONDS in VC.pas --
   // two defaults for one setting is how a value silently changes meaning
   // depending on which path initialised it.
   TCI_DEFAULT_MAX_TX_SECONDS = 180;
   TCI_DEFAULT_DEBUG          = False;
   TCI_DEFAULT_BINDALL        = False;
   TCI_PORT_USE_SERVER_DEFAULT = 0;   // see the TCIPort property

   RADIOSECTION_PREFIX   = 'Radio.';
   PROFILESECTION_PREFIX = 'Profile.';
   GENERALSECTION        = 'General';

   DEFAULTPROFILENAME    = 'Default';

   // The CW-output vocabulary used by TStationProfile.CWOutputN.
   CWOUTPUT_CAT  = 'CAT';
   CWOUTPUT_NONE = 'NONE';

   // The 'no port' value in TR4W's PortTypeSA vocabulary.
   PORT_NONE = 'NONE';

   // The NETWORK member of that same vocabulary (tree.pas PortTypeSA, the entry
   // after 'SERIAL 64').  CONTROL PORT is not a serial-only setting that a
   // network radio leaves blank -- it is the key that SELECTS the link, so
   // 'TCP/IP' is what tells the legacy path to use IP ADDRESS / TCP PORT at all.
   PORT_NETWORK = 'TCP/IP';

function TransportToStr(const aTransport: TRadioTransport): string;
function StrToTransport(const aValue: string): TRadioTransport;

implementation

uses
   uSettingsRegistry;   { AllSettings -- the dotted key that names a command
                          section is already registered there }

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

{ A NEW RADIO ID.

  A GUID, in the registry spelling without the braces: it has to survive a
  round trip through JSON and be legible in a file an operator may read, and it
  never has to be parsed back. Cheap, and unique without a central counter --
  two stores merged by hand cannot collide. }
function NewRadioId: string;
var
   g: TGUID;
begin
   if CreateGUID(g) = 0 then
      begin
      Result := Copy(GUIDToString(g), 2, 36);
      end
   else
      begin
      { CreateGUID does not fail in practice; if it ever did, a name-shaped
        fallback is still better than an empty key, which would make every
        radio look like the same one. }
      Result := 'radio-' + FormatDateTime('yyyymmddhhnnsszzz', Now);
      end;
end;

constructor TRadioDefinition.Create;
begin
   inherited Create;
   Id                := NewRadioId;
   // Defaults chosen to mean "nothing configured": a zero baud rate or CI-V
   // address is not a real setting, so the apply layer can leave the model's
   // own default in place rather than write a wrong number.
   Transport         := rtSerial;
   ControlPort       := PORT_NONE;
   KeyerOutputPort   := PORT_NONE;
   // Polling on is the useful default -- a radio defined but never polled
   // looks broken to the operator.
   PollingEnable     := True;
   AutoInfoLevel     := AUTOINFO_RADIO_DEFAULT;
end;

procedure TRadioDefinition.Assign(const aSource: TRadioDefinition);
begin
   if aSource = nil then
      begin
      Exit;
      end;

   { The Id travels with the definition: EditorDone copies a clone back onto
     the original, and a clone that lost its identity would look like a new
     radio to every profile referring to it. }
   Id                := aSource.Id;
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
   StartupCommand    := aSource.StartupCommand;
   PollingEnable     := aSource.PollingEnable;
   AutoInfoLevel     := aSource.AutoInfoLevel;
end;

function TRadioDefinition.SameAs(const aOther: TRadioDefinition): boolean;
begin
   Result := (aOther <> nil)                                        and
      (Name              = aOther.Name)                             and
      (RegistryId        = aOther.RegistryId)                       and
      (Transport         = aOther.Transport)                        and
      (ControlPort       = aOther.ControlPort)                      and
      (BaudRate          = aOther.BaudRate)                         and
      (SerialFormat      = aOther.SerialFormat)                     and
      (CatRTS            = aOther.CatRTS)                           and
      (CatDTR            = aOther.CatDTR)                           and
      (IPAddress         = aOther.IPAddress)                        and
      (TCPPort           = aOther.TCPPort)                          and
      (NetworkUsername   = aOther.NetworkUsername)                  and
      (NetworkPassword   = aOther.NetworkPassword)                  and
      (KeyerOutputPort   = aOther.KeyerOutputPort)                  and
      (KeyerRTS          = aOther.KeyerRTS)                         and
      (KeyerDTR          = aOther.KeyerDTR)                         and
      (KeyerStopBits     = aOther.KeyerStopBits)                    and
      (CWByCAT           = aOther.CWByCAT)                          and
      (CWSpeedSync       = aOther.CWSpeedSync)                      and
      (UseHamLib         = aOther.UseHamLib)                        and
      (HamLibID          = aOther.HamLibID)                         and
      (ReceiverAddress   = aOther.ReceiverAddress)                  and
      (IcomDataModeID    = aOther.IcomDataModeID)                   and
      (IcomFilterByte    = aOther.IcomFilterByte)                   and
      (WideCWFilter      = aOther.WideCWFilter)                     and
      (FT1000MPCWReverse = aOther.FT1000MPCWReverse)                and
      (FrequencyAdder    = aOther.FrequencyAdder)                   and
      (StartupCommand    = aOther.StartupCommand)                   and
      (PollingEnable     = aOther.PollingEnable) and
      (AutoInfoLevel     = aOther.AutoInfoLevel);
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
   { The ids are the reference; the names are their mirror. Both travel. }
   Radio1Id          := aSource.Radio1Id;
   Radio2Id          := aSource.Radio2Id;
   CWOutput1Id       := aSource.CWOutput1Id;
   CWOutput2Id       := aSource.CWOutput2Id;
   Radio1Name        := aSource.Radio1Name;
   Radio2Name        := aSource.Radio2Name;
   DefaultActiveSlot := aSource.DefaultActiveSlot;
   CWOutput1         := aSource.CWOutput1;
   CWOutput2         := aSource.CWOutput2;
   SpeedSync1        := aSource.SpeedSync1;
   SpeedSync2        := aSource.SpeedSync2;
   SO2REnabled       := aSource.SO2REnabled;
end;

function TStationProfile.SameAs(const aOther: TStationProfile): boolean;
begin
   Result := (aOther <> nil)                             and
      (Name              = aOther.Name)                  and
      (Radio1Name        = aOther.Radio1Name)            and
      (Radio2Name        = aOther.Radio2Name)            and
      (DefaultActiveSlot = aOther.DefaultActiveSlot)     and
      (CWOutput1         = aOther.CWOutput1)             and
      (CWOutput2         = aOther.CWOutput2)             and
      (SpeedSync1        = aOther.SpeedSync1)            and
      (SpeedSync2        = aOther.SpeedSync2)            and
      (SO2REnabled       = aOther.SO2REnabled);
end;

function TStationProfile.Clone: TStationProfile;
begin
   Result := TStationProfile.Create;
   Result.Assign(Self);
end;

{ The id for a slot -- what every lookup should ask for. }
function TStationProfile.RadioIdForSlot(const aSlot: integer): string;
begin
   if aSlot = 2 then
      begin
      Result := Radio2Id;
      end
   else
      begin
      Result := Radio1Id;
      end;
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

{ BY ID. Asked before deleting a radio, and a name comparison would answer
  "no" for a radio whose name had changed since the profile was written -- which
  is exactly the case ids exist to remove. }
function TStationProfile.ReferencesRadioId(const aRadioId: string): boolean;
begin
   Result := (Trim(aRadioId) <> '') and
             (SameText(Radio1Id, aRadioId) or SameText(Radio2Id, aRadioId));
end;

function TStationProfile.ReferencesRadio(const aRadioName: string): boolean;
begin
   Result := SameName(Radio1Name, aRadioName) or SameName(Radio2Name, aRadioName);
end;

{ ------------------------------------------------------ TRotatorDefinition - }

procedure TRotatorDefinition.Assign(const aOther: TRotatorDefinition);
begin
   if aOther = nil then
      begin
      Exit;
      end;
   Name        := aOther.Name;
   RotatorId   := aOther.RotatorId;
   ControlPort := aOther.ControlPort;
   BaudRate    := aOther.BaudRate;
   IPAddress   := aOther.IPAddress;
   UDPPort     := aOther.UDPPort;
   Bands       := aOther.Bands;
end;

function TRadioConfigStore.ColorCount: integer;
begin
   Result := FColors.Count;
end;

function TRadioConfigStore.ColorEntry(const aIndex: integer): TElementColors;
begin
   Result := FColors[aIndex];
end;

function TRadioConfigStore.FindElementColors(const aElement: string): TElementColors;
var
   i: integer;
begin
   Result := nil;
   for i := 0 to FColors.Count - 1 do
      begin
      if SameText(FColors[i].Element, aElement) then
         begin
         Result := FColors[i];
         Exit;
         end;
      end;
end;

procedure TRadioConfigStore.SetElementColors(const aElement, aForeground,
                                             aBackground: string);
var
   e: TElementColors;
begin
   if aElement = '' then
      begin
      Exit;
      end;

   e := FindElementColors(aElement);

   if (aForeground = '') and (aBackground = '') then
      begin
      if e <> nil then
         begin
         FColors.Remove(e);
         end;
      Exit;
      end;

   if e = nil then
      begin
      e := TElementColors.Create;
      e.Element := aElement;
      FColors.Add(e);
      end;

   e.Foreground := aForeground;
   e.Background := aBackground;
end;

function TRadioConfigStore.BandPlanCount: integer;
begin
   Result := FBandPlan.Count;
end;

function TRadioConfigStore.BandPlanEntry(const aIndex: integer): TBandPlanEntry;
begin
   Result := FBandPlan[aIndex];
end;

function TRadioConfigStore.FindBandPlan(const aBand: string): TBandPlanEntry;
var
   i: integer;
begin
   Result := nil;
   for i := 0 to FBandPlan.Count - 1 do
      begin
      if SameText(FBandPlan[i].Band, aBand) then
         begin
         Result := FBandPlan[i];
         Exit;
         end;
      end;
end;

procedure TRadioConfigStore.SetBandPlan(const aBand: string;
                                        const aCutoff, aCW, aSSB: integer);
var
   e: TBandPlanEntry;
begin
   if aBand = '' then
      begin
      Exit;
      end;

   e := FindBandPlan(aBand);

   // ALL ZERO MEANS ABSENT, not "three zeros".  Storing zeros would make the
   // next load set three frequencies to 0 rather than leaving the band alone,
   // which is the opposite of what an empty cell in the editor means.
   if (aCutoff = 0) and (aCW = 0) and (aSSB = 0) then
      begin
      if e <> nil then
         begin
         FBandPlan.Remove(e);
         end;
      Exit;
      end;

   if e = nil then
      begin
      e := TBandPlanEntry.Create;
      e.Band := aBand;
      FBandPlan.Add(e);
      end;

   e.Cutoff := aCutoff;
   e.CW     := aCW;
   e.SSB    := aSSB;
end;

function TRadioConfigStore.RotatorCount: integer;
begin
   Result := FRotators.Count;
end;

function TRadioConfigStore.Rotator(const aIndex: integer): TRotatorDefinition;
begin
   Result := FRotators[aIndex];
end;

function TRadioConfigStore.IndexOfRotator(const aName: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to FRotators.Count - 1 do
      begin
      // Case-insensitive, like the radio library: an operator who types
      // "yaesu" should not end up with a second rotator beside "Yaesu".
      if SameText(FRotators[i].Name, aName) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function TRadioConfigStore.AddRotator(const aRotator: TRotatorDefinition): boolean;
begin
   // TAKES OWNERSHIP on success, and FREES NOTHING on failure -- the caller
   // still owns what it handed over, so a rejected add cannot double-free.
   Result := False;
   if aRotator = nil then
      begin
      Exit;
      end;
   if Trim(aRotator.Name) = '' then
      begin
      Exit;
      end;
   if IndexOfRotator(aRotator.Name) >= 0 then
      begin
      Exit;
      end;
   FRotators.Add(aRotator);
   Result := True;
end;

procedure TRadioConfigStore.DeleteRotator(const aIndex: integer);
begin
   // No reference check, unlike DeleteRadio.  A profile names radios; nothing
   // names a rotator -- a rotator claims BANDS instead, and deleting it simply
   // leaves those bands unserved, which is a decision the operator just made.
   if (aIndex >= 0) and (aIndex < FRotators.Count) then
      begin
      // Deleting the ACTIVE one clears the choice rather than silently
      // promoting a neighbour -- same rule as DeleteCluster, and for the same
      // reason: turning a rotator the operator never picked is worse than
      // turning none until they say which.
      if SameText(FRotators[aIndex].Id, FActiveRotatorId) or
         SameText(FRotators[aIndex].Name, FActiveRotatorName) then
         begin
         FActiveRotatorName := '';
         FActiveRotatorId   := '';
         end;
      FRotators.Delete(aIndex);
      end;
end;

constructor TRotatorDefinition.Create;
begin
   inherited Create;
   { Born with one, so no creation site has to remember. }
   Id := NewRadioId;
end;

function TRadioConfigStore.IndexOfActiveRotator: integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to FRotators.Count - 1 do
      begin
      if (FActiveRotatorId <> '') and SameText(FRotators[i].Id, FActiveRotatorId) then
         begin
         Result := i;
         Exit;
         end;
      end;
   { A store written before rotators had ids still says which one by name. }
   if FActiveRotatorName <> '' then
      begin
      for i := 0 to FRotators.Count - 1 do
         begin
         if SameText(FRotators[i].Name, FActiveRotatorName) then
            begin
            Result := i;
            Exit;
            end;
         end;
      end;
end;

function TRadioConfigStore.UniqueRotatorName(const aBase: string): string;
var
   n: integer;
begin
   Result := aBase;
   n := 2;
   while IndexOfRotator(Result) >= 0 do
      begin
      Result := Format('%s %d', [aBase, n]);
      Inc(n);
      end;
end;

{ ------------------------------------------------------ TClusterDefinition - }

procedure TClusterDefinition.Assign(const aOther: TClusterDefinition);
begin
   if aOther = nil then
      begin
      Exit;
      end;
   Name           := aOther.Name;
   Server         := aOther.Server;
   LoginCall      := aOther.LoginCall;
   Password       := aOther.Password;
   ConnectCommand := aOther.ConnectCommand;
end;

function TRadioConfigStore.ClusterCount: integer;
begin
   Result := FClusters.Count;
end;

function TRadioConfigStore.Cluster(const aIndex: integer): TClusterDefinition;
begin
   Result := FClusters[aIndex];
end;

function TRadioConfigStore.IndexOfCluster(const aName: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to FClusters.Count - 1 do
      begin
      if SameText(FClusters[i].Name, aName) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function TRadioConfigStore.AddCluster(const aCluster: TClusterDefinition): boolean;
begin
   // Takes ownership on success, frees NOTHING on failure -- the caller still
   // owns what it handed over, so a rejected add cannot double-free.
   Result := False;
   if (aCluster = nil) or (Trim(aCluster.Name) = '') then
      begin
      Exit;
      end;
   if IndexOfCluster(aCluster.Name) >= 0 then
      begin
      Exit;
      end;
   FClusters.Add(aCluster);
   Result := True;
end;

procedure TRadioConfigStore.DeleteCluster(const aIndex: integer);
begin
   if (aIndex < 0) or (aIndex >= FClusters.Count) then
      begin
      Exit;
      end;

   // Deleting the ACTIVE one clears the choice rather than silently promoting a
   // neighbour.  TR4W then connects to nothing until the operator says which --
   // better than connecting to a cluster they never picked.
   if SameText(FClusters[aIndex].Name, FActiveClusterName) then
      begin
      FActiveClusterName := '';
      end;
   FClusters.Delete(aIndex);
end;

function TRadioConfigStore.UniqueClusterName(const aBase: string): string;
var
   n: integer;
begin
   Result := aBase;
   n := 2;
   while IndexOfCluster(Result) >= 0 do
      begin
      Result := Format('%s %d', [aBase, n]);
      Inc(n);
      end;
end;

function TRadioConfigStore.ActiveCluster: TClusterDefinition;
var
   i: integer;
begin
   Result := nil;
   i := IndexOfCluster(FActiveClusterName);
   if i >= 0 then
      begin
      Result := FClusters[i];
      end;
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

   // Name=value, case-insensitive: CFGCA command names are matched with
   // SameText everywhere else, and a store that disagreed would answer '' for
   // a command the program is perfectly happy to apply.
   FRotators := TObjectList<TRotatorDefinition>.Create(True);
   FBandPlan := TObjectList<TBandPlanEntry>.Create(True);
   FColors   := TObjectList<TElementColors>.Create(True);
   FHeaders := TStringList.Create;
   FHeaders.CaseSensitive := False;   // section names are matched like ini's
   FClusters := TObjectList<TClusterDefinition>.Create(True);

   FCommands := TStringList.Create;
   FCommands.CaseSensitive := False;
   { NOT Sorted, AND THAT IS NOT AN OVERSIGHT. Setting it raises
     EStringListError -- "operation not allowed on sorted list" -- the first
     time Values[] has to INSERT a name, which is every new setting, during
     startup, before there is a window to show the error in. TR4W died silently
     (NY4I, 2026-08-31: "dies quietly").

     The file is made stable by sorting at WRITE time instead; see SaveToJSON.
     The live list stays insertion-ordered, which is what Values[] needs. }
end;

function TRadioConfigStore.CommandValue(const aCommand, aDefault: string): string;
var
   idx: integer;
begin
   // A DEFAULT, not ''.  The caller passes the live value, so the first run
   // after upgrade -- store empty, globals seeded from the ini -- shows what is
   // actually in force rather than blanking the operator's station.
   idx := FCommands.IndexOfName(aCommand);
   if idx < 0 then
      begin
      Result := aDefault;
      end
   else
      begin
      Result := FCommands.ValueFromIndex[idx];
      end;
end;

procedure TRadioConfigStore.SetCommand(const aCommand, aValue: string);
begin
   // Values[] REPLACES, so setting a command twice updates it rather than
   // leaving a second entry whose effect would depend on read order.
   FCommands.Values[aCommand] := aValue;
end;

function TRadioConfigStore.Header(const aSection: string): TStringList;
var
   idx: integer;
begin
   idx := FHeaders.IndexOf(aSection);
   if idx < 0 then
      begin
      Result := TStringList.Create;
      FHeaders.AddObject(aSection, Result);
      end
   else
      begin
      Result := TStringList(FHeaders.Objects[idx]);
      end;
end;

procedure TRadioConfigStore.ClearHeaders;
var
   i: integer;
begin
   for i := 0 to FHeaders.Count - 1 do
      begin
      FHeaders.Objects[i].Free;
      end;
   FHeaders.Clear;
end;

destructor TRadioConfigStore.Destroy;
begin
   ClearHeaders;
   FreeAndNil(FHeaders);
   FreeAndNil(FCommands);
   FreeAndNil(FClusters);
   FreeAndNil(FRotators);
   FreeAndNil(FBandPlan);
   FreeAndNil(FColors);
   FreeAndNil(FProfiles);
   FreeAndNil(FRadios);
   inherited Destroy;
end;

procedure TRadioConfigStore.Clear;
begin
   FRadios.Clear;
   FBandPlan.Clear;
   FColors.Clear;
   FRotators.Clear;
   FClusters.Clear;
   FActiveClusterName := '';
   FActiveRotatorName := '';
   FProfiles.Clear;
   FActiveProfileName    := '';
   FAutoConnectOnStartup := False;
   FKeepLegacyIni := False;

   FTCIServerEnabled     := False;
   FTCIPort              := TCI_PORT_USE_SERVER_DEFAULT;
   FTCIBindAll           := TCI_DEFAULT_BINDALL;
   FTCIDebug             := TCI_DEFAULT_DEBUG;
   FTCIMaxTxSeconds      := TCI_DEFAULT_MAX_TX_SECONDS;

   if FCommands <> nil then
      begin
      FCommands.Clear;
      end;

   // Headers too: a Clear that left the previous station's Cabrillo name and
   // address behind would carry them into the next file loaded.
   if FHeaders <> nil then
      begin
      ClearHeaders;
      end;

   FHasLoggingSection    := False;
   FLogLevelName         := LOG_DEFAULT_LEVEL;
   FHamLibDebug          := False;
   FHamLibAsyncOnly      := False;
   FHamLibTrace          := False;
   FTelnetDebug          := False;
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

{ POINT A PROFILE SLOT AT A RADIO, GIVEN A NAME.

  The only supported way to do it from a name, and it exists because the
  alternative is a footgun: assigning Radio1Name on its own now leaves the ID
  -- the actual reference -- untouched, so the profile would look right in the
  file and resolve to nothing. Setting both here keeps them from disagreeing.

  False when no radio has that name, and the slot is left alone; the caller
  decides whether that is an error. }
function TRadioConfigStore.SetProfileRadioByName(const aProfile: TStationProfile;
                                                 const aSlot: integer;
                                                 const aName: string): boolean;
var
   radioDef: TRadioDefinition;
begin
   Result := False;
   if aProfile = nil then
      begin
      Exit;
      end;

   if Trim(aName) = '' then
      begin
      { Clearing a slot is legitimate and is not a lookup failure. }
      if aSlot = 2 then
         begin
         aProfile.Radio2Id := '';
         aProfile.Radio2Name := '';
         end
      else
         begin
         aProfile.Radio1Id := '';
         aProfile.Radio1Name := '';
         end;
      Result := True;
      Exit;
      end;

   radioDef := FindRadio(aName);
   if radioDef = nil then
      begin
      Exit;
      end;

   if aSlot = 2 then
      begin
      aProfile.Radio2Id   := radioDef.Id;
      aProfile.Radio2Name := radioDef.Name;
      end
   else
      begin
      aProfile.Radio1Id   := radioDef.Id;
      aProfile.Radio1Name := radioDef.Name;
      end;
   Result := True;
end;

{ THE LOOKUP PROFILES USE. By id, so a rename cannot break it. }
function TRadioConfigStore.FindRadioById(const aId: string): TRadioDefinition;
var
   i: integer;
begin
   Result := nil;
   if Trim(aId) = '' then
      begin
      Exit;
      end;
   for i := 0 to FRadios.Count - 1 do
      begin
      if SameText(FRadios[i].Id, aId) then
         begin
         Result := FRadios[i];
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
      if FProfiles[i].ReferencesRadioId(FRadios[idx].Id) then
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

   // THE MIRROR, NOT THE REFERENCE. Profiles point at this radio by Id, so the
   // rename is already a non-event for them; these two fields are the readable
   // copy written into the file and they would otherwise still say K4Z.
   // Updated before the name moves, or the comparison would match nothing.
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
         radio1 := FindRadioById(prof.Radio1Id);
         if radio1 = nil then
            begin
            aError := Format('Profile "%s" refers to radio "%s", which does not exist',
                             [prof.Name, prof.Radio1Name]);
            Exit;
            end;
         end;

      if Trim(prof.Radio2Name) <> '' then
         begin
         radio2 := FindRadioById(prof.Radio2Id);
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
   aIni.WriteString(section,  'StartupCommand',    aRadio.StartupCommand);
   aIni.WriteBool(section,    'PollingEnable',     aRadio.PollingEnable);
   aIni.WriteInteger(section, 'AutoInfoLevel',     aRadio.AutoInfoLevel);
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
   radioDef.StartupCommand    := aIni.ReadString(aSection,  'StartupCommand',    '');
   radioDef.PollingEnable     := aIni.ReadBool(aSection,    'PollingEnable',     True);
   radioDef.AutoInfoLevel     := aIni.ReadInteger(aSection, 'AutoInfoLevel',     AUTOINFO_RADIO_DEFAULT);

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
   { An ini names radios; the caller resolves those to ids once the radios are
     in the store -- see ResolveProfileRadioIds. }
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

{ ------------------------------------------------------------------ JSON --- }

// Small readers that give a MISSING key and a present-but-wrong-typed key the
// same answer: the default.  A settings file is edited by hand sooner or later,
// and a typo in one field must not cost the operator the other forty.
function JSONStr(const aObj: TJSONObject; const aKey: string; const aDefault: string): string;
var
   v: TJSONValue;
begin
   Result := aDefault;
   if aObj = nil then
      begin
      Exit;
      end;
   v := aObj.GetValue(aKey);
   if (v <> nil) and (v is TJSONString) then
      begin
      Result := JSONText(v);
      end;
end;

function JSONInt(const aObj: TJSONObject; const aKey: string; const aDefault: integer): integer;
var
   v: TJSONValue;
begin
   Result := aDefault;
   if aObj = nil then
      begin
      Exit;
      end;
   v := aObj.GetValue(aKey);
   if (v <> nil) and (v is TJSONNumber) then
      begin
      Result := TJSONNumber(v).AsInt;
      end;
end;

function JSONBool(const aObj: TJSONObject; const aKey: string; const aDefault: boolean): boolean;
var
   v: TJSONValue;
begin
   Result := aDefault;
   if aObj = nil then
      begin
      Exit;
      end;
   v := aObj.GetValue(aKey);
   if (v <> nil) and (v is TJSONBool) then
      begin
      Result := TJSONBool(v).AsBoolean;
      end;
end;

function RadioToJSON(const aRadio: TRadioDefinition): TJSONObject;
begin
   Result := TJSONObject.Create;

   Result.AddPair('id',              aRadio.Id);
   Result.AddPair(JSONKEY_NAME,      aRadio.Name);
   Result.AddPair('registryId',      aRadio.RegistryId);
   Result.AddPair('transport',       TransportToStr(aRadio.Transport));

   Result.AddPair('controlPort',     aRadio.ControlPort);
   Result.AddPair('baudRate',        TJSONNumber.Create(aRadio.BaudRate));
   Result.AddPair('serialFormat',    aRadio.SerialFormat);
   Result.AddPair('catRTS',          aRadio.CatRTS);
   Result.AddPair('catDTR',          aRadio.CatDTR);

   Result.AddPair('ipAddress',       aRadio.IPAddress);
   Result.AddPair('tcpPort',         TJSONNumber.Create(aRadio.TCPPort));
   Result.AddPair('networkUsername', aRadio.NetworkUsername);
   Result.AddPair('networkPassword', aRadio.NetworkPassword);

   Result.AddPair('keyerOutputPort', aRadio.KeyerOutputPort);
   Result.AddPair('keyerRTS',        aRadio.KeyerRTS);
   Result.AddPair('keyerDTR',        aRadio.KeyerDTR);
   Result.AddPair('keyerStopBits',   TJSONNumber.Create(aRadio.KeyerStopBits));

   Result.AddPair('cwByCAT',         TJSONBool.Create(aRadio.CWByCAT));
   Result.AddPair('cwSpeedSync',     TJSONBool.Create(aRadio.CWSpeedSync));

   Result.AddPair('useHamLib',       TJSONBool.Create(aRadio.UseHamLib));
   Result.AddPair('hamLibID',        TJSONNumber.Create(aRadio.HamLibID));
   Result.AddPair('receiverAddress', TJSONNumber.Create(aRadio.ReceiverAddress));
   Result.AddPair('icomDataModeID',  TJSONNumber.Create(aRadio.IcomDataModeID));
   Result.AddPair('icomFilterByte',  TJSONNumber.Create(aRadio.IcomFilterByte));
   Result.AddPair('wideCWFilter',    TJSONBool.Create(aRadio.WideCWFilter));
   Result.AddPair('ft1000mpCWReverse', TJSONBool.Create(aRadio.FT1000MPCWReverse));
   Result.AddPair('frequencyAdder',  TJSONNumber.Create(aRadio.FrequencyAdder));
   Result.AddPair('startupCommand',  aRadio.StartupCommand);
   Result.AddPair('pollingEnable',   TJSONBool.Create(aRadio.PollingEnable));
   Result.AddPair('autoInfoLevel',   TJSONNumber.Create(aRadio.AutoInfoLevel));
end;

function ProfileToJSON(const aProfile: TStationProfile): TJSONObject;
begin
   Result := TJSONObject.Create;

   Result.AddPair(JSONKEY_NAME,        aProfile.Name);
   { BOTH, and the id is the one that counts. The names stay so the file can be
     read by a person and by an older build; they are refreshed from the ids on
     every save, so they cannot drift into a lie. }
   Result.AddPair('radio1Id',          aProfile.Radio1Id);
   Result.AddPair('radio2Id',          aProfile.Radio2Id);
   Result.AddPair('cwOutput1Id',       aProfile.CWOutput1Id);
   Result.AddPair('cwOutput2Id',       aProfile.CWOutput2Id);
   Result.AddPair('radio1',            aProfile.Radio1Name);
   Result.AddPair('radio2',            aProfile.Radio2Name);
   Result.AddPair('defaultActiveSlot', TJSONNumber.Create(aProfile.DefaultActiveSlot));
   Result.AddPair('cwOutput1',         aProfile.CWOutput1);
   Result.AddPair('cwOutput2',         aProfile.CWOutput2);
end;

{ command -> section, built ONCE.

  DERIVED, NOT DECLARED. Every stored setting already registers a dotted key --
  'appearance.ctrlj.showFrequencyInLog' -- so its first segment is a section
  name that already exists and is already maintained. Adding a section argument
  to 230 registrations would be the same fact typed twice, and the copies would
  drift the first time a setting moved page.

  A MAP RATHER THAN A LOOKUP PER COMMAND: the obvious shape scans all 230
  settings for each of 243 commands, which is 56,000 comparisons and a string
  allocation apiece to save one file.

  UpperCase COMPARISON, NOT SameText, and that is not fussiness: SameText here
  resolves to the AnsiString overload, so passing two `string`s narrows both --
  two ratchet entries for a comparison of ASCII command names. Comparing
  upper-cased strings stays in one type and says the same thing. }
function BuildSectionMap: TStringList;
var
   all: TArray<TSettingBase>;
   i, dot: integer;
   key: string;
begin
   Result := TStringList.Create;
   Result.CaseSensitive := False;
   all := AllSettings;
   for i := 0 to High(all) do
      begin
      if all[i] = nil then
         begin
         Continue;
         end;
      if Trim(all[i].LegacyCommand) = '' then
         begin
         Continue;
         end;
      key := all[i].Key;
      dot := Pos('.', key);
      if dot > 1 then
         begin
         { EXPLICIT, and the invariant is real rather than convenient: both
           sides are ASCII by construction -- a CFGCA command name ('MY CALL')
           and the first segment of a registered setting key ('appearance').
           Neither is operator text, so nothing can be outside the codepage.
           Left implicit this would be two more ratchet entries claiming a risk
           that does not exist here. }
         Result.Values[AnsiString(all[i].LegacyCommand)] :=
            AnsiString(Copy(key, 1, dot - 1));
         end;
      end;
end;

{ Put one command into the list, and NOWHERE ELSE does.

  TStringList is AnsiString-backed, so this assignment narrows -- it always did,
  and the flat reader had exactly one of them. Reading a sectioned file needs
  two call sites; two ASSIGNMENTS would have been two narrowings and two places
  for the conversion to be got wrong later. One routine keeps it at one, which
  is why the ratchet does not move for a reader that now understands two
  shapes. }
procedure TakeCommand(const aList: TStringList; const aName, aValue: string);
begin
   aList.Values[aName] := aValue;
end;

function TRadioConfigStore.SaveToJSON: TJSONObject;
var
   radios, profiles: TJSONArray;
   general, tci, logging, commands, rot, clu, hdr: TJSONObject;
   bandPlan, bp, colors, col: TJSONObject;
   rotators, clusters: TJSONArray;
   lst, sections, sectionMap: TStringList;
   { ITS OWN NAME, not lst. Further down, `lst := Header(...)` BORROWS a list
     the store owns and must not free; this one is created and freed here.
     Sharing the variable would leave the next reader one edit away from
     freeing something that belongs to the object. }
   ordered: TStringList;
   section: TJSONObject;
   sectionName: AnsiString;
   i, s, idx: integer;
begin
   Result := TJSONObject.Create;
   Result.AddPair(JSONKEY_VERSION, TJSONNumber.Create(JSON_SCHEMA_VERSION));

   // "general" keeps what is genuinely general: which profile is active, and
   // whether to connect the radios at startup.  Both are single station-wide
   // statements with no subsystem of their own.
   general := TJSONObject.Create;
   general.AddPair('activeProfile', FActiveProfileName);
   general.AddPair('autoConnect',   TJSONBool.Create(FAutoConnectOnStartup));
   general.AddPair('keepLegacyIni', TJSONBool.Create(FKeepLegacyIni));
   Result.AddPair(JSONKEY_GENERAL, general);

   // tciServer USED to be written into "general" above.  It is not written
   // there any more -- writing both would create two sources of truth for one
   // setting, and the next person to edit the file by hand would have no way
   // to know which one wins.  LoadFromJSON still READS the old key when the
   // new section is absent, which is what makes an existing file migrate
   // silently and correctly on its first save.
   tci := TJSONObject.Create;
   tci.AddPair('enabled',      TJSONBool.Create(FTCIServerEnabled));
   tci.AddPair('port',         TJSONNumber.Create(FTCIPort));
   tci.AddPair('bindAll',      TJSONBool.Create(FTCIBindAll));
   tci.AddPair('debug',        TJSONBool.Create(FTCIDebug));
   tci.AddPair('maxTxSeconds', TJSONNumber.Create(FTCIMaxTxSeconds));
   Result.AddPair(JSONKEY_TCI, tci);

   // Logging.  tci.debug is NOT duplicated here even though the Logging panel
   // shows it: it is one setting belonging to the TCI subsystem, and the panel
   // is a VIEW of it.  Writing it in both places would be the same
   // two-homes-for-one-setting mistake the tci migration just removed.
   logging := TJSONObject.Create;
   logging.AddPair('level',           FLogLevelName);
   logging.AddPair('hamlibDebug',     TJSONBool.Create(FHamLibDebug));
   logging.AddPair('hamlibAsyncOnly', TJSONBool.Create(FHamLibAsyncOnly));
   logging.AddPair('hamlibTrace',     TJSONBool.Create(FHamLibTrace));
   logging.AddPair('telnetDebug',     TJSONBool.Create(FTelnetDebug));
   Result.AddPair(JSONKEY_LOGGING, logging);

   // Retired CFGCA rows.  An OBJECT keyed by command name, so the file reads as
   // what it is -- "MY SECTION": "WCF" -- and needs no schema beyond CFGCA.
   { COMMANDS, GROUPED. One flat list of 243 names is machine-correct and
     unreadable, and this file does get read by a human in practice (NY4I:
     "inevitably, I do check things in the json file").

     THE SECTION IS DERIVED, NOT DECLARED. Every stored setting already
     registers a dotted key -- 'appearance.ctrlj.showFrequencyInLog' -- so the
     first segment is a section name that already exists and is already
     maintained. Adding a section argument to 230 registrations would have been
     the same information typed twice, and the two copies would disagree.

     A command with no registered setting, or a key with no dot, goes to
     SECTION_OTHER rather than being dropped: this file is the store, and a
     value we cannot classify must still round-trip. }
   commands := TJSONObject.Create;
   sections := TStringList.Create;
   sectionMap := BuildSectionMap;
   try
      sections.Sorted := True;
      sections.Duplicates := dupIgnore;
      sections.OwnsObjects := False;

      { SORTED FOR OUTPUT ONLY. The live list cannot be Sorted -- Values[] then
        refuses to insert -- so the order the operator sees is made here, where
        it costs one copy and breaks nothing.

        This is the actual fix for "the json file changes the order depending
        upon what was saved last": unsorted, Values[] appends each new name at
        the end, so tr4w.json recorded the write history of ONE MACHINE and two
        operators with identical settings got different files. }
      ordered := TStringList.Create;
      ordered.Assign(FCommands);
      ordered.Sort;

      for i := 0 to ordered.Count - 1 do
         begin
         { Unclassified is NAMED, not blank: it must be obvious in the file
           that a command was not misfiled but never had a section. }
         sectionName := sectionMap.Values[ordered.Names[i]];
         if sectionName = '' then
            begin
            sectionName := SECTION_OTHER;
            end;
         idx := sections.IndexOf(sectionName);
         if idx < 0 then
            begin
            section := TJSONObject.Create;
            sections.AddObject(sectionName, section);
            end
         else
            begin
            section := TJSONObject(sections.Objects[idx]);
            end;
         section.AddPair(ordered.Names[i], ordered.ValueFromIndex[i]);
         end;

      for i := 0 to sections.Count - 1 do
         begin
         commands.AddPair(sections[i], TJSONObject(sections.Objects[i]));
         end;
   finally
      sections.Free;
      sectionMap.Free;
      ordered.Free;
   end;
   Result.AddPair(JSONKEY_COMMANDS, commands);

   // Rotators.  An ARRAY, like radios and keyers, so order is preserved and a
   // name is an ordinary value rather than something encoded in a key.
   rotators := TJSONArray.Create;
   for i := 0 to FRotators.Count - 1 do
      begin
      rot := TJSONObject.Create;
      rot.AddPair('id',          FRotators[i].Id);
      rot.AddPair(JSONKEY_NAME,  FRotators[i].Name);
      rot.AddPair('rotatorId',   FRotators[i].RotatorId);
      rot.AddPair('controlPort', FRotators[i].ControlPort);
      rot.AddPair('baudRate',    TJSONNumber.Create(FRotators[i].BaudRate));
      rot.AddPair('ipAddress',   FRotators[i].IPAddress);
      rot.AddPair('udpPort',     TJSONNumber.Create(FRotators[i].UDPPort));
      rot.AddPair('bands',       FRotators[i].Bands);
      rotators.AddElement(rot);
      end;
   Result.AddPair(JSONKEY_ROTATORS, rotators);

   // The band plan.  An OBJECT keyed by band spelling, not an array, because
   // there is exactly one entry per band and the band is the identity -- the
   // file reads as "160": { "cutoff": 1800 } and needs no schema to follow.
   //
   // A zero is OMITTED rather than written, so "not set" survives the round
   // trip: an absent value leaves that band alone on load, which is what an
   // empty cell in the editor has always meant.
   bandPlan := TJSONObject.Create;
   for i := 0 to FBandPlan.Count - 1 do
      begin
      bp := TJSONObject.Create;
      if FBandPlan[i].Cutoff <> 0 then
         begin
         bp.AddPair('cutoff', TJSONNumber.Create(FBandPlan[i].Cutoff));
         end;
      if FBandPlan[i].CW <> 0 then
         begin
         bp.AddPair('cw', TJSONNumber.Create(FBandPlan[i].CW));
         end;
      if FBandPlan[i].SSB <> 0 then
         begin
         bp.AddPair('ssb', TJSONNumber.Create(FBandPlan[i].SSB));
         end;
      bandPlan.AddPair(FBandPlan[i].Band, bp);
      end;
   Result.AddPair(JSONKEY_BANDPLAN, bandPlan);

   // Main-window colors.  Keyed by element name, and a color that is not set
   // is omitted rather than written empty -- so an element the operator never
   // touched keeps its compiled default rather than being forced to blank.
   colors := TJSONObject.Create;
   for i := 0 to FColors.Count - 1 do
      begin
      col := TJSONObject.Create;
      if FColors[i].Foreground <> '' then
         begin
         col.AddPair('fg', FColors[i].Foreground);
         end;
      if FColors[i].Background <> '' then
         begin
         col.AddPair('bg', FColors[i].Background);
         end;
      colors.AddPair(FColors[i].Element, col);
      end;
   Result.AddPair(JSONKEY_COLORS, colors);

   // Clusters, and which one is active.  The active NAME rather than an index:
   // an index silently re-points at a different server the moment the list is
   // reordered, and reordering a list is exactly what an operator does.
   clusters := TJSONArray.Create;
   for i := 0 to FClusters.Count - 1 do
      begin
      clu := TJSONObject.Create;
      clu.AddPair(JSONKEY_NAME,     FClusters[i].Name);
      clu.AddPair('server',         FClusters[i].Server);
      clu.AddPair('loginCall',      FClusters[i].LoginCall);
      clu.AddPair('password',       FClusters[i].Password);
      clu.AddPair('connectCommand', FClusters[i].ConnectCommand);
      clusters.AddElement(clu);
      end;
   Result.AddPair(JSONKEY_CLUSTERS, clusters);
   general.AddPair('activeCluster', FActiveClusterName);
   general.AddPair('activeRotatorId', FActiveRotatorId);
   general.AddPair('activeRotator',   FActiveRotatorName);
   general.AddPair('latestConfigFile', FLatestConfigFile);
   general.AddPair('gridPromptShown', TJSONBool.Create(FGridPromptShown));

   // The export headers, each as its own object rather than inside `commands`:
   // these are not CFGCA commands and ApplyStoredCommands must not try to
   // apply them through CheckCommand, which would refuse every one.
   for s := Low(HEADER_SECTIONS) to High(HEADER_SECTIONS) do
      begin
      hdr := TJSONObject.Create;
      lst := Header(HEADER_SECTIONS[s].Section);
      for i := 0 to lst.Count - 1 do
         begin
         hdr.AddPair(lst.Names[i], lst.ValueFromIndex[i]);
         end;
      Result.AddPair(HEADER_SECTIONS[s].JSONKey, hdr);
      end;

   // Arrays, so ORDER is preserved and a name is an ordinary value.  The ini
   // form had to encode the name in the section header, which made a name
   // containing ']' or '=' a hazard and left ordering to whatever the ini
   // reader happened to return.
   radios := TJSONArray.Create;
   for i := 0 to FRadios.Count - 1 do
      begin
      radios.AddElement(RadioToJSON(FRadios[i]));
      end;
   Result.AddPair(JSONKEY_RADIOS, radios);

   profiles := TJSONArray.Create;
   for i := 0 to FProfiles.Count - 1 do
      begin
      profiles.AddElement(ProfileToJSON(FProfiles[i]));
      end;
   Result.AddPair(JSONKEY_PROFILES, profiles);
end;

procedure TRadioConfigStore.LoadFromJSON(const aRoot: TJSONObject);
var
   arr: TJSONArray;
   obj: TJSONObject;
   general, tci, logging, commands: TJSONObject;
   bandPlan, bp, colors, col: TJSONObject;
   radioDef: TRadioDefinition;
   rotDef: TRotatorDefinition;
   cluDef: TClusterDefinition;
   profile: TStationProfile;
   v, pv: TJSONValue;
   section: TJSONObject;
   lst: TStringList;
   i, s, k: integer;
   err: string;
begin
   Clear;
   if aRoot = nil then
      begin
      Exit;
      end;

   general := nil;
   v := aRoot.GetValue(JSONKEY_GENERAL);
   if (v <> nil) and (v is TJSONObject) then
      begin
      general := TJSONObject(v);
      end;
   FActiveProfileName    := JSONStr(general,  'activeProfile', '');
   FAutoConnectOnStartup := JSONBool(general, 'autoConnect',   False);
   FKeepLegacyIni        := JSONBool(general, 'keepLegacyIni', False);

   // TCI: the new section, falling back to the OLD general.tciServer key.
   //
   // The fallback is not politeness, it is the difference between a rename and
   // a silent reset.  Every existing file has general.tciServer and no "tci"
   // section; reading only the new location would default enabled to False and
   // turn the operator's TCI server OFF on upgrade -- with nothing to see, at
   // the exact moment they went looking for it.  That is the same
   // silently-defaulted-to-a-legal-zero trap this project keeps meeting.
   //
   // Reading the old key as the DEFAULT for the new one means both files
   // behave correctly and the first save writes the new shape, so the
   // migration completes itself with no version branch.
   tci := nil;
   v := aRoot.GetValue(JSONKEY_TCI);
   if (v <> nil) and (v is TJSONObject) then
      begin
      tci := TJSONObject(v);
      end;

   FTCIServerEnabled := JSONBool(tci, 'enabled',
                                 JSONBool(general, 'tciServer', False));
   FTCIPort          := JSONInt(tci,  'port',         TCI_PORT_USE_SERVER_DEFAULT);
   FTCIBindAll       := JSONBool(tci, 'bindAll',      TCI_DEFAULT_BINDALL);
   FTCIDebug         := JSONBool(tci, 'debug',        TCI_DEFAULT_DEBUG);
   FTCIMaxTxSeconds  := JSONInt(tci,  'maxTxSeconds', TCI_DEFAULT_MAX_TX_SECONDS);

   logging := nil;
   v := aRoot.GetValue(JSONKEY_LOGGING);
   if (v <> nil) and (v is TJSONObject) then
      begin
      logging := TJSONObject(v);
      end;

   // No fallback to an old JSON key here, unlike tci: these settings have never
   // been in this file.  They are arriving from tr4w.ini, and the ini rows stay
   // readable for one release, so an operator who has not opened Preferences
   // yet keeps the behaviour their ini describes.
   FHasLoggingSection := logging <> nil;
   FLogLevelName    := JSONStr(logging,  'level',           LOG_DEFAULT_LEVEL);
   FHamLibDebug     := JSONBool(logging, 'hamlibDebug',     False);
   FHamLibAsyncOnly := JSONBool(logging, 'hamlibAsyncOnly', False);
   FHamLibTrace     := JSONBool(logging, 'hamlibTrace',     False);
   FTelnetDebug     := JSONBool(logging, 'telnetDebug',     False);

   // Retired CFGCA rows.  Whatever is here is applied verbatim by the apply
   // layer through CheckCommand, so an unknown name simply fails there rather
   // than needing a check of its own.
   FClusters.Clear;
   FActiveClusterName := JSONStr(general, 'activeCluster', '');
   FActiveRotatorName := JSONStr(general, 'activeRotator',   '');
   FActiveRotatorId   := JSONStr(general, 'activeRotatorId', '');
   FLatestConfigFile  := JSONStr(general, 'latestConfigFile', '');
   FGridPromptShown   := JSONBool(general, 'gridPromptShown', False);

   // Clear (above) has already emptied the headers.
   for s := Low(HEADER_SECTIONS) to High(HEADER_SECTIONS) do
      begin
      v := aRoot.GetValue(HEADER_SECTIONS[s].JSONKey);
      if (v <> nil) and (v is TJSONObject) then
         begin
         lst := Header(HEADER_SECTIONS[s].Section);
         for i := 0 to TJSONObject(v).Count - 1 do
            begin
            lst.Values[JSONPairName(TJSONObject(v), i)] :=
               JSONText(JSONPairValue(TJSONObject(v), i));
            end;
         end;
      end;
   v := aRoot.GetValue(JSONKEY_CLUSTERS);
   if (v <> nil) and (v is TJSONArray) then
      begin
      arr := TJSONArray(v);
      for i := 0 to arr.Count - 1 do
         begin
         if not (arr.Items[i] is TJSONObject) then
            begin
            Continue;
            end;
         obj := TJSONObject(arr.Items[i]);
         cluDef := TClusterDefinition.Create;
         cluDef.Name           := JSONStr(obj, JSONKEY_NAME,     '');
         cluDef.Server         := JSONStr(obj, 'server',         '');
         cluDef.LoginCall      := JSONStr(obj, 'loginCall',      '');
         cluDef.Password       := JSONStr(obj, 'password',       '');
         cluDef.ConnectCommand := JSONStr(obj, 'connectCommand', '');
         if not AddCluster(cluDef) then
            begin
            cluDef.Free;
            end;
         end;
      end;

   FColors.Clear;
   v := aRoot.GetValue(JSONKEY_COLORS);
   if (v <> nil) and (v is TJSONObject) then
      begin
      colors := TJSONObject(v);
      for i := 0 to colors.Count - 1 do
         begin
         if not (JSONPairValue(colors, i) is TJSONObject) then
            begin
            Continue;
            end;
         col := TJSONObject(JSONPairValue(colors, i));
         SetElementColors(JSONPairName(colors, i),
                          JSONStr(col, 'fg', ''),
                          JSONStr(col, 'bg', ''));
         end;
      end;

   FBandPlan.Clear;
   v := aRoot.GetValue(JSONKEY_BANDPLAN);
   if (v <> nil) and (v is TJSONObject) then
      begin
      bandPlan := TJSONObject(v);
      for i := 0 to bandPlan.Count - 1 do
         begin
         // JSONPairName/JSONPairValue rather than .Pairs[]: FPC's fpjson has
         // no Pairs property, and these helpers are what the commands section
         // above already uses to stay portable across both JSON units.
         if not (JSONPairValue(bandPlan, i) is TJSONObject) then
            begin
            Continue;
            end;
         bp := TJSONObject(JSONPairValue(bandPlan, i));
         // Through SetBandPlan rather than by construction, so the all-zero
         // rule lives in ONE place and a hand-edited file with three zeros in
         // it behaves the same as an absent entry.
         SetBandPlan(JSONPairName(bandPlan, i),
                     JSONInt(bp, 'cutoff', 0),
                     JSONInt(bp, 'cw',     0),
                     JSONInt(bp, 'ssb',    0));
         end;
      end;

   FRotators.Clear;
   v := aRoot.GetValue(JSONKEY_ROTATORS);
   if (v <> nil) and (v is TJSONArray) then
      begin
      arr := TJSONArray(v);
      for i := 0 to arr.Count - 1 do
         begin
         if not (arr.Items[i] is TJSONObject) then
            begin
            Continue;
            end;
         obj := TJSONObject(arr.Items[i]);
         rotDef := TRotatorDefinition.Create;
         rotDef.Id          := JSONStr(obj, 'id',           '');
         if rotDef.Id = '' then
            begin
            rotDef.Id := NewRadioId;   { the same minter; a GUID is a GUID }
            end;
         rotDef.Name        := JSONStr(obj, JSONKEY_NAME,  '');
         rotDef.RotatorId   := JSONStr(obj, 'rotatorId',   '');
         rotDef.ControlPort := JSONStr(obj, 'controlPort', '');
         rotDef.BaudRate    := JSONInt(obj, 'baudRate',    0);
         rotDef.IPAddress   := JSONStr(obj, 'ipAddress',   '');
         rotDef.UDPPort     := JSONInt(obj, 'udpPort',     0);
         rotDef.Bands       := JSONStr(obj, 'bands',       '');
         // AddRotator refuses a blank or duplicate name and does NOT free on
         // refusal, so the object has to be released here or a malformed file
         // leaks one per bad entry.
         if not AddRotator(rotDef) then
            begin
            rotDef.Free;
            end;
         end;
      end;

   FCommands.Clear;
   v := aRoot.GetValue(JSONKEY_COMMANDS);
   if (v <> nil) and (v is TJSONObject) then
      begin
      { BOTH SHAPES, and the value's TYPE says which -- an object is a section
        to descend into, a string is a command. No version flag: the file
        describes itself, and a store that refused the older shape would empty
        the operator's settings on first run for no gain. }
      commands := TJSONObject(v);
      { FLATTENED FIRST, then stored in ONE place. Two assignment sites would be
        two conversions to the list's AnsiString and two chances for them to
        drift; this also keeps the narrowing count where the flat reader left
        it. }
      lst := TStringList.Create;
      try
         for i := 0 to commands.Count - 1 do
            begin
            pv := JSONPairValue(commands, i);
            if pv is TJSONObject then
               begin
               section := TJSONObject(pv);
               for k := 0 to section.Count - 1 do
                  begin
                  TakeCommand(lst, JSONPairName(section, k),
                              JSONText(JSONPairValue(section, k)));
                  end;
               end
            else
               begin
               TakeCommand(lst, JSONPairName(commands, i), JSONText(pv));
               end;
            end;
         FCommands.Assign(lst);
      finally
         lst.Free;
      end;
      end;

   // Radios before profiles: a profile's radio references are only meaningful
   // once the radios exist, and Validate is easier to reason about that way.
   v := aRoot.GetValue(JSONKEY_RADIOS);
   if (v <> nil) and (v is TJSONArray) then
      begin
      arr := TJSONArray(v);
      for i := 0 to arr.Count - 1 do
         begin
         if not (arr.Items[i] is TJSONObject) then
            begin
            Continue;
            end;
         obj := TJSONObject(arr.Items[i]);

         radioDef := TRadioDefinition.Create;
         radioDef.Id                := JSONStr(obj,  'id',              '');
         if radioDef.Id = '' then
            begin
            { A store written before radios had ids.  Mint one now; the profile
              reader below resolves its by NAME in the same pass, so the two
              halves of the migration cannot disagree. }
            radioDef.Id := NewRadioId;
            end;
         radioDef.Name              := JSONStr(obj,  JSONKEY_NAME,      '');
         radioDef.RegistryId        := JSONStr(obj,  'registryId',      '');
         radioDef.Transport         := StrToTransport(
                                       JSONStr(obj,  'transport',       TRANSPORTNAME[rtSerial]));

         radioDef.ControlPort       := JSONStr(obj,  'controlPort',     PORT_NONE);
         radioDef.BaudRate          := JSONInt(obj,  'baudRate',        0);
         radioDef.SerialFormat      := JSONStr(obj,  'serialFormat',    '');
         radioDef.CatRTS            := JSONStr(obj,  'catRTS',          '');
         radioDef.CatDTR            := JSONStr(obj,  'catDTR',          '');

         radioDef.IPAddress         := JSONStr(obj,  'ipAddress',       '');
         radioDef.TCPPort           := JSONInt(obj,  'tcpPort',         0);
         radioDef.NetworkUsername   := JSONStr(obj,  'networkUsername', '');
         radioDef.NetworkPassword   := JSONStr(obj,  'networkPassword', '');

         radioDef.KeyerOutputPort   := JSONStr(obj,  'keyerOutputPort', PORT_NONE);
         radioDef.KeyerRTS          := JSONStr(obj,  'keyerRTS',        '');
         radioDef.KeyerDTR          := JSONStr(obj,  'keyerDTR',        '');
         radioDef.KeyerStopBits     := JSONInt(obj,  'keyerStopBits',   0);

         radioDef.CWByCAT           := JSONBool(obj, 'cwByCAT',         False);
         radioDef.CWSpeedSync       := JSONBool(obj, 'cwSpeedSync',     False);

         radioDef.UseHamLib         := JSONBool(obj, 'useHamLib',       False);
         radioDef.HamLibID          := JSONInt(obj,  'hamLibID',        0);
         radioDef.ReceiverAddress   := JSONInt(obj,  'receiverAddress', 0);
         radioDef.IcomDataModeID    := JSONInt(obj,  'icomDataModeID',  0);
         radioDef.IcomFilterByte    := JSONInt(obj,  'icomFilterByte',  0);
         radioDef.WideCWFilter      := JSONBool(obj, 'wideCWFilter',    False);
         radioDef.FT1000MPCWReverse := JSONBool(obj, 'ft1000mpCWReverse', False);
         radioDef.FrequencyAdder    := JSONInt(obj,  'frequencyAdder',  0);
         radioDef.StartupCommand    := JSONStr(obj,  'startupCommand',  '');
         radioDef.PollingEnable     := JSONBool(obj, 'pollingEnable',   True);
         radioDef.AutoInfoLevel     := JSONInt(obj,  'autoInfoLevel',  AUTOINFO_RADIO_DEFAULT);

         // A blank or duplicate name cannot come from SaveToJSON, but it can
         // come from a hand-edited file.  Drop that entry rather than raise
         // while loading settings.
         if not AddRadio(radioDef, err) then
            begin
            radioDef.Free;
            end;
         end;
      end;

   v := aRoot.GetValue(JSONKEY_PROFILES);
   if (v <> nil) and (v is TJSONArray) then
      begin
      arr := TJSONArray(v);
      for i := 0 to arr.Count - 1 do
         begin
         if not (arr.Items[i] is TJSONObject) then
            begin
            Continue;
            end;
         obj := TJSONObject(arr.Items[i]);

         profile := TStationProfile.Create;
         profile.Name              := JSONStr(obj, JSONKEY_NAME,        '');
         profile.Radio1Name        := JSONStr(obj, 'radio1',            '');
         profile.Radio2Name        := JSONStr(obj, 'radio2',            '');
         profile.Radio1Id          := JSONStr(obj, 'radio1Id',          '');
         profile.Radio2Id          := JSONStr(obj, 'radio2Id',          '');
         profile.CWOutput1Id       := JSONStr(obj, 'cwOutput1Id',       '');
         profile.CWOutput2Id       := JSONStr(obj, 'cwOutput2Id',       '');

         { MIGRATION, once, for a file written before profiles carried ids: the
           name still says which radio was meant, and the radios were read
           above, so resolve it now. A name that matches nothing leaves the id
           empty and Validate reports it, which is the same outcome as before
           and better than inventing a reference. }
         if (profile.Radio1Id = '') and (Trim(profile.Radio1Name) <> '') then
            begin
            radioDef := FindRadio(profile.Radio1Name);
            if radioDef <> nil then
               begin
               profile.Radio1Id := radioDef.Id;
               end;
            end;
         if (profile.Radio2Id = '') and (Trim(profile.Radio2Name) <> '') then
            begin
            radioDef := FindRadio(profile.Radio2Name);
            if radioDef <> nil then
               begin
               profile.Radio2Id := radioDef.Id;
               end;
            end;
         profile.DefaultActiveSlot := JSONInt(obj, 'defaultActiveSlot', 1);
         profile.CWOutput1         := JSONStr(obj, 'cwOutput1',         '');
         profile.CWOutput2         := JSONStr(obj, 'cwOutput2',         '');

         if not AddProfile(profile, err) then
            begin
            profile.Free;
            end;
         end;
      end;
end;

function TRadioConfigStore.LoadFromFile(const aFileName: string; out aError: string): boolean;
var
   text: string;
   root: TJSONValue;
begin
   Result  := False;
   aError  := '';

   if not FileExists(aFileName) then
      begin
      aError := 'not found: ' + aFileName;
      Exit;
      end;

   try
      // TEncoding.UTF8 explicitly: JSON is UTF-8 by definition (RFC 8259), and
      // letting this default to the machine's ANSI codepage would mangle a
      // non-ASCII radio name differently on different machines -- the same
      // class of bug the lang files hit.
      text := ReadAllTextUTF8(aFileName);
   except
      on E: Exception do
         begin
         aError := 'unreadable: ' + E.Message;
         Exit;
         end;
   end;

   root := TJSONObject.ParseJSONValue(text);
   if root = nil then
      begin
      // Malformed.  Report it and leave the store EMPTY rather than
      // half-loaded: a corrupt settings file must not stop TR4W starting, and
      // a partial library is harder to diagnose than an obviously empty one.
      aError := 'not valid JSON: ' + aFileName;
      Exit;
      end;

   try
      if not (root is TJSONObject) then
         begin
         aError := 'root is not a JSON object: ' + aFileName;
         Exit;
         end;
      LoadFromJSON(TJSONObject(root));
      Result := True;
   finally
      root.Free;
   end;
end;

procedure TRadioConfigStore.SaveToFile(const aFileName: string);
var
   root: TJSONObject;
   dir: string;
begin
   dir := ExtractFilePath(aFileName);
   if (dir <> '') and (not DirectoryExists(dir)) then
      begin
      ForceDirectories(dir);
      end;

   root := SaveToJSON;
   try
      // Format, not ToJSON: this file is meant to be readable and hand-editable
      // -- that is the reason for moving off the ini in the first place.
      //
      // WriteAllBytes over GetBytes, NOT WriteAllText: WriteAllText emits the
      // encoding's preamble, which for TEncoding.UTF8 is a BOM -- and a JSON
      // text must not start with one (RFC 8259).  Our own reader tolerates it,
      // but Python's json.load rejects the file outright, and so will jq and
      // anything else the operator or a future cross-platform reader points at
      // it.  Found by opening the file we had just written (2026-08-06).
      //
      // Note this is the OPPOSITE of the rule for src\lang\*.pas, which must
      // KEEP their BOM.  Same three bytes, opposite requirement, and neither
      // produces a diagnostic when it is wrong.
      WriteAllTextUTF8(aFileName, root.Format(2));
   finally
      root.Free;
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

   // The legacy ini store, which JSON replaced.  It is a READ path for old
   // files, so it keeps the flat [General] TCIServer key it was written with
   // and does NOT grow the new settings -- adding them here would mean
   // maintaining the new shape in a format that is on its way out.  A file
   // loaded through here gets the defaults for the rest and writes the full
   // tci section on its first JSON save.
   FTCIServerEnabled     := aIni.ReadBool(GENERALSECTION,   'TCIServer',     False);
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
   aIni.WriteBool(GENERALSECTION,    'TCIServer',     FTCIServerEnabled);

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

      // Transport is not stored in the legacy ini -- it is INFERRED from the
      // control port.  TWO spellings mean network and both must be honoured:
      //
      //   'TCP/IP' (PORT_NETWORK) -- what the program writes TODAY.  This is
      //       the authoritative marker.  RenderRadioKeys emits it for every
      //       network radio.
      //
      //   'NONE' + an IP address -- the OLD convention, still sitting in every
      //       ini written before that changed.  Kept as a fallback so an
      //       existing config still migrates.
      //
      // ONLY THE SECOND WAS TESTED, WHICH IS HOW THIS SURVIVED.  The writer was
      // corrected on the bench (NY4I, 2026-08-05) to emit 'TCP/IP', because
      // writing 'NONE' to avoid opening a COM port also withdrew "use the
      // network" and the factory refused to build a driver -- see the note in
      // uRadioConfigLegacyMap.  The reader was never moved with it, so a
      // correctly-configured network radio round-tripped into a SERIAL
      // definition with its IP and TCP port still attached: the editor then
      // opened it on the Serial tab, found no matching port, and saved
      // CONTROL PORT=NONE over it.  Observed on NY4I's own K4.
      //
      // This matters more, not less, as radio settings move to csJSON: seeding
      // then runs ONCE per operator and the JSON becomes authoritative, so a
      // mis-inference here stops being a re-runnable bug and becomes permanent.
      if SameText(controlPort, PORT_NETWORK) or
         (SameText(controlPort, PORT_NONE) and (ipAddress <> '')) then
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
         prof.Radio1Id   := radioDef.Id;
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
         prof.Radio2Id   := radioDef.Id;
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

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
unit uRadioConfigApply;
{$I tr4w.inc}

{
  Puts a station profile on the air.

  THE ONLY UNIT THAT KNOWS BOTH WORLDS.  uRadioConfigStore holds the operator's
  library and knows nothing about TR4W; uRadioConfigLegacyMap turns a definition
  into ini keys and knows nothing about the live application.  This unit is
  where those meet the running program: it writes the keys, tells CFGCA to
  re-read them, and restarts the radios.  Everything genuinely untestable lives
  here on purpose, and it is deliberately thin -- the decisions were all made in
  the two units below it.

  WHY WRITE THE INI AT ALL, RATHER THAN SET THE GLOBALS DIRECTLY.  Because
  CheckCommand is the only code that knows how to turn 'SERIAL 15' into a port
  type, how to validate a baud rate, and which of the sixty-odd globals a given
  key feeds.  Reproducing that here would be reimplementing the config parser
  and would drift from it the first time either side changed.  So the sequence
  is the same one the legacy dialog uses: write the key, then CheckCommand it.

  STARTUP -- THIS CHANGED, 2026-08-06.  It used to say that startup needed
  nothing from this unit: apply wrote the legacy keys, ReadInConfigFile read
  them back, and the JSON library was never consulted while booting.  That is
  true only while nothing else edits tr4w.ini.  NY4I hand-edited
  RADIO ONE CONTROL PORT to 'SERIAL 3' after the library had been saved as JSON
  and the program obeyed the INI -- the library and the live configuration had
  silently diverged, with nothing to tell the operator which was in force.

  So settings\tr4w.json is now the FORMAT OF RECORD for radio settings, and the
  [Radio] keys are a rendering of it.  ApplyActiveProfileToConfigAtStartup
  rewrites them from the library on every start, before anything reads them.
  A conflicting hand-edit is overwritten rather than obeyed, and the
  disagreement is logged.

  ON COEXISTENCE WITH THE OLD DIALOG.  Both write the same [Radio] keys, so
  within a session it is last-writer-wins.  ACROSS a restart it is not: the
  library wins, so a change made in the legacy dialog (CATLEGACY) does not
  survive the next start once a profile is active.  That is the intended
  direction of travel -- the legacy dialog is a transitional escape hatch, not a
  second place to configure radios -- but it is a real behaviour change and is
  the reason the override is logged rather than silent.

  ON THREADS.  ApplyProfile closes the CAT and keyer ports through the same
  CloseCATAndKeyerForThisRadio the dialog uses, and lets the polling thread
  notice and wind down.  It does NOT call TerminateThread -- the legacy dialog
  does, and it is wrong: terminating a thread mid-write leaves the serial handle
  and the radio object in whatever state they were in, which is how you get a
  port that cannot be reopened until TR4W restarts.
}

interface

uses
   SysUtils,
   IniFiles,
   uRadioConfigStore,
   uKeyerConfigStore,
   uRadioConfigLegacyMap,
  uAnsiStr;

// Resolve what the registry says about a definition's identity, so the pure
// renderer does not have to know the registry exists.
function ResolveTypeRendering(const aRegistryId: string): TRadioTypeRendering;

// Write one slot's keys and hand each to CheckCommand.  Does NOT touch ports;
// ApplyProfile sequences that.  aRadio may be nil, meaning "clear this slot".
// aPersist decides whether the rendered keys are also WRITTEN to tr4w.ini.
// The two halves are genuinely separate concerns: CheckCommand is what moves
// a value into TR4W's globals, and the ini write is only what makes it
// survive a restart.  Startup passes False -- the library is already the
// record, so persisting a copy of it would be writing to disk purely to
// configure memory, and on a read-only program directory that write fails
// or is redirected without anyone noticing.
procedure ApplyRadioToSlot(const aRadio: TRadioDefinition;
                           const aSlot: integer;
                           const aProfile: TStationProfile;

                           const aNamesAKeyerDevice: boolean = False);

// The whole sequence: stop both radios, write both slots, regroup the ini,
// restart.  Returns False with aError set if the profile cannot be applied at
// all (unknown radio names); a radio that merely fails to CONNECT is not an
// error here -- that is reported by the normal connection path.
// aKeyers resolves a profile's CW-output choice when it names a keyer DEVICE.
// Optional so existing callers are unchanged; without it a named device cannot
// be resolved and its slot renders no keyer port.
function ApplyProfile(const aStore: TRadioConfigStore;
                      const aProfile: TStationProfile;
                      out aError: string;
                      const aKeyers: TKeyerConfigStore = nil): boolean;

// Where the radio library lives.  Here rather than in the preferences form
// because STARTUP needs it too and must not depend on a UI unit -- and not in
// uRadioConfigStore, which is deliberately RTL-only and knows no TR4W unit.
function RadioStoreFileName: string;
function LegacyRadioStoreFileName: string;

// The settings folder itself.  Exported because the UDP settings are seeded
// from settings\tr4w.ini and the Preferences form must reach it the SAME way
// startup does -- two spellings of one path is exactly the divergence this
// unit exists to prevent.
function SettingsDirectory: string;

// STARTUP ONLY.  Writes the active profile's keys into the configuration and
// CheckCommands them -- and does NOTHING to the radios, because at startup they
// do not exist yet and the normal CheckAndInitializePorts path is about to
// connect them with these values.
//
// WHY THIS EXISTS.  Until now the legacy [Radio] keys were the system of record
// AT STARTUP: apply wrote them, and ReadInConfigFile read them back, so the
// JSON library was never consulted while booting.  That works only while
// nothing else edits tr4w.ini.  NY4I hand-edited RADIO ONE CONTROL PORT to
// 'SERIAL 3' after the library had been written to JSON, and the program used
// the ini value -- the two stores had silently diverged with no way for the
// operator to tell which one was live.
//
// So the JSON library WINS.  It is the format of record; the [Radio] keys are
// now a rendering of it, rewritten from it on every start.  A conflicting
// hand-edit of those keys is overwritten rather than obeyed, and the
// disagreement is logged so "why did my ini change" has an answer.
//
// Returns False only when the store cannot be used at all.  No store, no active
// profile, or a profile naming a radio that no longer exists all return True
// having changed nothing -- an operator who has never opened Preferences must
// boot exactly as they always did.
// Library-owned settings that the PROGRAM (not a radio) acts on, published
// here by ApplyActiveProfileToConfigAtStartup.  The store is loaded once at
// startup and freed again, so a global is how a decision made in Preferences
// reaches tr4w.dpr without a second read of the file.
var
   RadioLibraryTCIServerEnabled: boolean = False;

   // 0 = "use the server's own default port" -- the store deliberately does not
   // name 50001, so that number stays written down in exactly one place
   // (uTCIServer).  tr4w.dpr substitutes it.
   RadioLibraryTCIPort: integer = 0;
   RadioLibraryTCIBindAll: boolean = False;

// Logging settings from the store into the globals -- see the implementation
// for why the level cannot simply be assigned.
procedure ApplyLoggingSettings(const aStore: TRadioConfigStore);

// Apply every retired CFGCA row the store holds.  Trusted caller: csJSON rows
// ARE applied, with their bounds and crA hooks -- see the implementation.
procedure ApplyStoredCommands(const aStore: TRadioConfigStore);

// The band plan -- per-band mode cutoff and the CW/phone frequency memories --
// from the store into the globals.  Seeds itself once from an existing
// tr4w.ini [BAND PLAN] section when the store has none, so a station upgrading
// keeps the plan it had.
procedure ApplyBandPlan(const aStore: TRadioConfigStore);

// Main-window element colors from the store into TWindows.  Seeds itself once
// from whatever the config load already put there, which is the faithful
// migration: the ini's [COLORS] lines have been applied by then.
procedure ApplyElementColors(const aStore: TRadioConfigStore);

// The palette spellings, for a settings screen that offers them.  Here rather
// than in the UI so there is one list and it comes from the enum.
function PaletteSpellings: TArray<string>;

// Render the chosen cluster into the globals the connect path reads: server,
// login callsign, password and post-login command.  Called at startup and
// whenever Preferences is saved, so the two cannot disagree.
procedure ApplyActiveCluster(const aStore: TRadioConfigStore);

// One command from a trusted source (a settings screen, or a multi-op peer):
// applied through CFGCA and recorded in the store.  Returns CFGCA's verdict.
function ApplyAndStoreCommand(const aStore: TRadioConfigStore;
                              const aCommand, aValue: string): boolean;

function ApplyActiveProfileToConfigAtStartup(out aError: string): boolean;

{ One config parameter arriving from a MULTI-OP PEER.  Returns True if it was
  accepted, so the caller can tell the operator; False means CFGCA refused it.

  WHY THIS EXISTS.  uNet applied a peer's parameter with a bare CheckCommand and
  then wrote the key to tr4w.ini.  Neither half works for a migrated row:
  CheckCommand is inert for csJSON, so the call returned False, nothing was
  applied, nothing was displayed, and the operator was told nothing -- while the
  station that made the change saw it take effect locally.  Seventeen rows are
  already in that state, the UDP broadcast block among them.

  A PEER IS A TRUSTED SOURCE, exactly as Preferences is: multi-op parameter sync
  is a feature, and the peer has already validated the value through its own
  CFGCA.  So a migrated row is applied with aApplyJSONOwned and recorded in the
  JSON store, which is where that row's system of record now is; an
  un-migrated row keeps the ini write it always had.

  It loads and saves the store per call.  That is heavy, and it is fine: these
  arrive when a human changes a setting, not per QSO.  Holding a long-lived
  store instead would mean two writers to one file -- this path and Preferences,
  which loads its own working copy -- and a peer's change would be silently
  reverted the next time the operator pressed Save. }
function ApplyPeerCommand(const aCommand, aValue: string): boolean;

// The contest .cfg last opened, read from and written to the `general` section
// of settings\tr4w.json.
//
// NOT a setting: it is bookkeeping, it is not registered, and it does not
// appear in Preferences or in the search index (NY4I, 2026-08-16). It lives
// here rather than in tr4w.ini because that ini write was the only thing
// recreating the file on a station whose settings had all moved to JSON.
//
// GetLatestConfigFile returns '' when there is no store yet, which the caller
// must treat as "no previous contest" rather than as an error -- it is the
// ordinary first-run state.
function  GetLatestConfigFile: string;
procedure SetLatestConfigFile(const aFileName: string);

// Has TR4W already offered to set MY GRID?  Asked once per installation rather
// than once per start -- see the store's GridPromptShown.
function  GridPromptAlreadyShown: boolean;
procedure MarkGridPromptShown;

// Apply ONE stored command from settings\tr4w.json, and return whether it was
// found and accepted.
//
// For the handful of settings a HEADLESS /EXPORT genuinely needs.  That path
// deliberately skips ApplyStoredCommands, because applying every stored command
// takes the operator's current settings over the log's own .cfg -- measured
// wrong, 21/1/4 -> 8/14/4.  Applying ONE NAMED command is a different thing:
// the caller states which, and why, at the call site.
//
// Do not turn this into a loop over the store.  That is ApplyStoredCommands,
// and it is skipped under /EXPORT on purpose.
function ApplyStoredCommand(const aCommand: string): boolean;

// UI-free description of the port collisions a profile WOULD cause, '' when
// clean.  Advisory: unlike TRadioConfigStore.Validate, this also covers the
// keyer lines and CAT-versus-keyer sharing, which are warnings rather than
// certain failures.
function DescribePortConflicts(const aStore: TRadioConfigStore;
                               const aProfile: TStationProfile): string;

implementation

uses
   // Windows, not Winapi.Windows: the rest of the tree spells it the short way
   // and qualifies calls as Windows.<fn>, which only resolves if the unit is
   // named that way here too.
   Windows,
   StrUtils,   // StartsText -- KeySuffix
   VC,
   uCFG,
   uCAT,
   uRadioRegistry,
   uKeyerConfigApply,   // resolve a named keyer device and configure it
   uTR4WConfigFile,     // LoadConfig -- both libraries live in the one file
   uUDPBroadcastConfig, // round-tripped by ApplyPeerCommand so its section survives
   LOGRADIO,
   LOGK1EA,    // ActiveRadio
   uRotatorControl,   // ConfigureRotators -- the rotator library goes live here
   uCWKeyerBase,   // KeyerSelectionIsProfileDriven
   LogCW,
   LOGWIND,
   uBandLookup,   // CalculateBandMode -- the extracted, unit-tested copy, not tree.pas
   MainUnit;   // logger

function ResolveTypeRendering(const aRegistryId: string): TRadioTypeRendering;
var
   model: InterfacedRadioType;
begin
   // ModelForId answers NoInterfacedRadio for a string-id (factory) radio,
   // which is exactly the test the legacy dialog makes before deciding between
   // TYPE and FACTORY ID.  Same rule, one layer up.
   model := ModelForId(aRegistryId);

   Result.IsFactoryRadio := (model = NoInterfacedRadio);
   if Result.IsFactoryRadio then
      begin
      Result.LegacyTypeName := '';
      end
   else
      begin
      Result.LegacyTypeName := string(AnsiString(InterfacedRadioTypeSA[model]));
      end;

   // The model's own defaults, for every field the operator left blank.  The
   // renderer cannot look these up -- it has no registry, deliberately -- and
   // it must not render a blank number, because CFGCA reads a blank numeric as
   // "never set" and keeps the PREVIOUS radio's value.
   Result.DefaultBaudRate := 0;
   Result.DefaultTCPPort  := 0;
   if aRegistryId <> '' then
      begin
      Result.DefaultBaudRate := SerialParamsForId(aRegistryId).baud;
      Result.DefaultTCPPort  := RegisteredNetworkPortId(aRegistryId);
      end;

   Result.DefaultCIVAddress := 0;
   Result.DefaultHamLibID   := 0;
   if model <> NoInterfacedRadio then
      begin
      Result.DefaultCIVAddress := RegisteredCIVAddress(model);
      Result.DefaultHamLibID   := RegisteredHamLibID(model);
      end;
end;

// ---------------------------------------------------------------------------
// Logging settings, from the store into the globals the program actually reads.
//
// ONE TRANSLATION SITE FOR THE LEVEL, and this is the shape Set 2 of the ini
// retirement will need for its twelve ckList rows.  The store keeps the
// SPELLING ('DEBUG'); tLogLevels is a Pascal enum; somewhere the two must meet,
// and the whole point is that it happens exactly once.  tLogLevelsSA is the
// same table CFGCA matched against, so the vocabularies cannot drift -- reading
// the spellings from the array rather than retyping them here is what
// guarantees that.  An unrecognised spelling keeps the current level rather
// than silently selecting llNone, because a typo in a settings file must not
// turn logging off at the moment someone is trying to diagnose something.
//
// UpdateDebugLogLevel IS NOT OPTIONAL.  The ini row carries crP:13, which is
// CommandsProcArray[13] = @UpdateDebugLogLevel, and that hook exists so a level
// changed in the UI takes effect IMMEDIATELY (NY4I).  csJSON makes CheckCommand
// inert, so nothing else will call it: assigning logLevels without this would
// store the new level correctly, show it correctly, and leave the running
// logger exactly as it was.
{ ONE-TIME MIGRATION for a command whose row has just become csJSON.

  THE STEP THAT IS EASY TO FORGET, and it loses operator settings when it is.
  A csJSON row is inert to the ini loader. So on the first run after a row
  graduates, the value the operator set months ago is sitting in tr4w.ini,
  nothing reads it, and the setting silently reverts to its compiled default.
  For CW SPEED INCREMENT that is 2 becoming 3; for something like TWO RADIO MODE
  it would be a station behaving differently mid-contest.

  So each migrated command is copied ini -> store ONCE, and only when the store
  has no value of its own. After Preferences saves, the store answers and the
  ini is never consulted for that key again -- which matters, because otherwise
  a value deliberately CHANGED later could be resurrected by the stale ini line
  still sitting in the file.

  AN EXPLICIT LIST, not "every csJSON row". Deriving it would be tidier and is
  wrong: the RADIO rows are csJSON too, their ini keys are known to be stale
  duplicates, and seeding those into Commands would let ApplyStoredCommands
  apply them over the top of the active profile. Every entry here is added in
  the same commit that flips its row.

  The ini keys are left in place: inert, harmless, and a fallback for anyone who
  rolls back to a previous build. }
const
   MIGRATED_COMMANDS: array[0..250] of string =
   (
      'BAND MAP CUTOFF FREQUENCY',
      'FREQUENCY MEMORY',
      'CONTEST NAME',
      'CONTEST',
      'DOMESTIC MULTIPLIER',
      'DX MULTIPLIER',
      'EXCHANGE RECEIVED',
      'PADDLE PORT',
      'PREFIX MULTIPLIER',
      'QSO POINT METHOD',
      'QUICK QSL CW MESSAGE',
      'QUICK QSL CW MESSAGE1',
      'QUICK QSL MESSAGE 1',
      'QUICK QSL MESSAGE 2',
      'QUICK QSL SSB MESSAGE',
      'REMINDER',
      'ZONE MULTIPLIER',
      'BAND MAP SPLIT MODE',
      'CATEGORY-ASSISTED',
      'CATEGORY-BAND',
      'CATEGORY-MODE',
      'CATEGORY-OPERATOR',
      'CATEGORY-POWER',
      'CATEGORY-TRANSMITTER',
      'CATEGORY-OVERLAY',
      'DISTANCE MODE',
      'DUPE CHECK SOUND',
      'HOUR DISPLAY',
      'INITIAL EXCHANGE',
      'INITIAL EXCHANGE CURSOR POS',
      'MODE',
      'MP3 RECORDER DURATION',
      'POSSIBLE CALL MODE',
      'QSL MODE',
      'RATE DISPLAY',
      'REMAINING MULT DISPLAY MODE',
      'TEN MINUTE RULE',
      'USER INFO SHOWN',
      'CW SPEED INCREMENT',          // 2026-08-14
      'HAMSCORE ENABLE',             // 2026-08-14
      'HAMSCORE URL',
      'HAMSCORE USERNAME',
      'HAMSCORE PASSWORD',
      'HAMSCORE SEND CONTACT INFO',
      'ALT-D BUFFER ENABLE',
      'ALT-D CQ ENABLE',
      'ALWAYS CALL BLIND CQ',
      'SKIP ACTIVE BAND',
      'CW SPEED FROM DATABASE',
      'KEYPAD CW MEMORIES',
      'SAY HI ENABLE',
      'SAY HI RATE CUTOFF',
      'LEADING ZERO CHARACTER',
      'DIT DAH RATIO',
      'SCORE POSTING URL',
      'SCORE READING URL',
      'CONNECTION AT STARTUP',
      'CW ENABLE',
      'CW TONE',
      'FARNSWORTH ENABLE',
      'FARNSWORTH SPEED',
      'WEIGHT',
      'TWO RADIO MODE',
      'LEADING ZEROS',

      // The csOwned batch, 2026-08-14: already written to JSON by the
      // hand-wired Preferences panels, but their rows still round-tripped the
      // ini until now.
      'BACKUP LOG FILE NAME',
      'BACKUP LOG FREQUENCY',
      'BAND MAP DECAY TIME',
      'BAND MAP DISPLAY LIMIT',
      'BAND MAP GUARD BAND',
      'COMPUTER ID',
      'EXTERNAL LOGGER',
      'EXTERNAL LOGGER ADDRESS',
      'EXTERNAL LOGGER PORT',
      'FONT SIZE',
      'MAIN FONT',
      'MMTTY ENGINE',
      'RADIO TCP SERVER PORT',
      'SCP COUNTRY STRING',
      'SCP MINIMUM LETTERS',
      'SERVER ADDRESS',
      'SERVER PASSWORD',
      'SERVER PORT',
      'TELNET SERVER',
      'WSJT-X BROADCAST PORT',
      'WSJT-X MULTICAST GROUP',
      'RELAY CONTROL PORT',

      // The rest of the parallel-port wiring, 2026-08-14. These were the
      // last radio-scoped strays; NY4I placed them on Hardware rather than
      // the radio form because they describe the STATION's cabling, not the
      // radio -- see the note in uRadioConfigLegacyMap.
      'RADIO ONE BAND OUTPUT PORT',
      'RADIO TWO BAND OUTPUT PORT',
      'STEREO CONTROL PORT',

      // CW keying, paddle and PTT, 2026-08-14.
      'ALL CW MESSAGES CHAINABLE',
      'TUNE WITH DITS',
      'SEND COMPLETE FOUR LETTER CALL',
      'PADDLE SPEED',
      'PADDLE MONITOR TONE',
      'SWAP PADDLES',
      'PADDLE PTT HOLD COUNT',
      'PTT ENABLE',
      'PTT TURN ON DELAY',
      'NO POLL DURING PTT',

      // Two radio and multi-op, 2026-08-15.
      'IN BAND LOCKOUT',
      'QSY INACTIVE RADIO',
      'SWAP RADIO RELAY SENSE',
      'WAIT FOR STRENGTH',
      'MULTI MULTS ONLY',
      'INTERCOM FILE ENABLE',

      // Operating and PTT, 2026-08-15.
      'PTT VIA COMMANDS',
      'PTT LOCKOUT',
      'AUTO CALL TERMINATE',
      'AUTO RETURN TO CQ MODE',
      'ESCAPE EXITS SEARCH AND POUNCE',
      'LEAVE CURSOR IN CALL WINDOW',
      'LOG WITH SINGLE ENTER',
      'SPACE BAR DUPE CHECK ENABLE',
      'CONFIRM EDIT CHANGES',
      'AUTO QSO NUMBER DECREMENT',

      // SCP, band map and log files, 2026-08-15.
      'POSSIBLE CALLS',
      'PARTIAL CALL ENABLE',
      'WILDCARD PARTIALS',
      'NAME FLAG ENABLE',
      'CALL WINDOW SHOW ALL SPOTS',
      'SWAP PACKET SPOT RADIOS',
      'CHECK LOG FILE SIZE',
      'UNKNOWN COUNTRY FILE ENABLE',
      'UPDATE RESTART FILE ENABLE',

      // The F-key button captions, 2026-08-15.
      'INCLUDE F-KEY NUMBER',

      // The old Appearance menu, 2026-08-15.
      'NO BORDER',
      'NO CAPTION',
      'NO COLUMN HEADER',
      'SHOW GRIDLINES',

      // Audio -- MP3 and DVK, 2026-08-15.
      'MP3 RECORDER ENABLE',
      'MP3 PATH',
      'MP3 PLAYER',
      'DVK ENABLE',
      'DVK LOCALIZED MESSAGES ENABLE',
      'DVK PATH',
      'DVK RECORDER',
      'USE RECORDED SIGNS',

      // Contest-set band enables, 2026-08-16.  Seeded like any other migrated
      // row: the value an operator had in tr4w.ini must survive the flip, and
      // a csJSON row is inert to the ini loader, so without this entry the
      // setting silently reverts to its compiled default on the first run.
      //
      // FCONTEST still assigns these when a contest is selected -- that is the
      // intended behaviour, not a competing owner, and it is why the plan calls
      // for the Bands panel to say the value came from the contest.
      'HF BAND ENABLE',
      'WARC BAND ENABLE',
      'VHF BAND ENABLE',
      // Migrated 2026-08-21.
      'AUTO-CQ DELAY TIME',
      'BEEP EVERY 10 QSOS',
      'CONTEST TITLE',
      'COUNT DOMESTIC COUNTRIES',
      'CUSTOM INITIAL EXCHANGE STRING',
      'EXCHANGE MEMORY ENABLE',
      'GRID MAP CENTER',
      'INITIAL EXCHANGE OVERWRITE',
      'LITERAL DOMESTIC QTH',
      'LOG RS SENT',
      'LOG RST SENT',
      'LOOK FOR RST SENT',
      'MESSAGE ENABLE',
      'MINITOUR DURATION',
      'MULT BY BAND',
      'MULT BY MODE',
      'MULT SHEET AUTO RESET',
      'MULTIPLE BANDS',
      'MULTIPLE MODES',
      // Migrated 2026-08-21.
      'QSO BY BAND',
      'QSO BY MODE',
      'QSO NUMBER BY BAND',
      'QSO POINTS DOMESTIC CW',
      'QSO POINTS DOMESTIC PHONE',
      'QSO POINTS DX CW',
      'QSO POINTS DX PHONE',
      'QTC ENABLE',
      'QTC EXTRA SPACE',
      'QTC MINUTES',
      'QTC QRS',
      'QUICK QSL KEY 1',
      'QUICK QSL KEY 2',
      'R150S MODE',
      'RANDOM CQ MODE',
      'REVERSE INITIAL EX',
      'RFOBL MODE',
      'SHOW ALL SERIAL PORTS',
      'SHOW DOMESTIC MULTIPLIER NAME',
      'SPRINT QSY RULE',
      // Migrated 2026-08-21.
      'ASK FOR FREQUENCIES',
      'AUTO DISPLAY DUPE QSO',
      'AUTO DUPE ENABLE CQ',
      'AUTO DUPE ENABLE S AND P',
      'AUTO S&P ENABLE',
      'AUTO S&P ENABLE SENSITIVITY',
      'AUTO TIME INCREMENT',
      'CUSTOM USER STRING',
      'DE ENABLE',
      'DIGITAL MODE ENABLE',
      'DUPE SHEET AUTO RESET',
      'FREQUENCY MEMORY ENABLE',
      'FREQUENCY POLL RATE',
      'IE SWITCH',
      'INCREMENT TIME ENABLE',
      'LOG FREQUENCY ENABLE',
      'LOG SUB TITLE',
      'MAIN CALLSIGN',
      'POSSIBLE CALL ACCEPT KEY',
      'POSSIBLE CALL LEFT KEY',
      // Migrated 2026-08-21.
      'POSSIBLE CALL RIGHT KEY',
      'QSX ENABLE',
      'QZB RANDOM OFFSET ENABLE',
      'RADIUS OF EARTH',
      'SHIFT KEY ENABLE',
      'STATIONS CALLSIGNS MASK',
      'WAKE UP TIME OUT',
      'CODE SPEED',
      'QUESTION MARK CHAR',
      'SHORT 0',
      'SHORT 1',
      'SHORT 2',
      'SHORT 9',
      'SHORT INTEGERS',
      'SLASH MARK CHAR',
      'TUNE ALT-D ENABLE',
      'BEEP ENABLE',
      'COLUMN AUTOSIZE',
      'COMPLETE CALLSIGN MASK',
      'CONTACTS PER PAGE',
      // Migrated 2026-08-21.
      'INSERT MODE',
      'SHOW FREQUENCY IN LOG',
      'SHOW TYPED CALLSIGN',
      'LPT1 BASE ADDRESS',
      'LPT2 BASE ADDRESS',
      'LPT3 BASE ADDRESS',
      'STEREO PIN HIGH',
      'USE CONTROL PORT',
      'ALLOW AUTO UPDATE',
      'CALLSIGN UPDATE ENABLE',
      'COUNTRY INFORMATION FILE',
      'CTY UPDATE CHECK ON STARTUP',
      'DOMESTIC FILENAME',
      'MISSINGCALLSIGNS FILE ENABLE',
      'UNKNOWN COUNTRY FILE NAME',
      'BAND MAP ITEM HEIGHT',
      'BAND MAP ITEM WIDTH',
      'BAND MAP SIZE',
      'COMPUTER NAME',
      'NET STATUS UPDATE INTERVAL',
      // Migrated 2026-08-21.
      'HAND LOG MODE',
      'NO LOG',
      'BROADCAST ALL PACKET DATA',
      'INITIAL EXCHANGE FILENAME',
      // Migrated 2026-08-21.
      'AUTO QSL INTERVAL',
      'MULT REPORT MINIMUM BANDS',
      'AUTO SEND CHARACTER COUNT',
      'ROW COUNT',
      'WINDOW SIZE',
      'MP3 RECORDER BITRATE',
      'STEREO CONTROL PIN',
      // Migrated 2026-08-21.
      'START SENDING NOW KEY'
   );

procedure SeedMigratedCommandsFromIni(const aStore: TRadioConfigStore);
var
   ini: TIniFile;
   i: integer;
   idx: integer;
   value: string;
begin
   if aStore = nil then
      begin
      Exit;
      end;

   ini := TIniFile.Create(SettingsDirectory + 'tr4w.ini');
   try
      for i := Low(MIGRATED_COMMANDS) to High(MIGRATED_COMMANDS) do
         begin
         // Already in the store means Preferences has saved it at least once;
         // the ini is history from that point on.
         if aStore.CommandValue(MIGRATED_COMMANDS[i], '') <> '' then
            begin
            Continue;
            end;

         value := ini.ReadString(string(_COMMANDS), MIGRATED_COMMANDS[i], '');
         if value = '' then
            begin
            Continue;
            end;

         // A PASSWORD IN THE INI IS NOT TRUSTWORTHY AS A PASSWORD.  Ctrl-J
         // displays ctPassword rows as a fixed '********' mask, and although
         // uOption:761 now refuses to write the mask back, an existing file can
         // already contain it -- NY4I's does, for HAMSCORE PASSWORD.  Carrying
         // that across would set the operator's password to the literal mask
         // and produce an authentication failure that looks like a server
         // problem.  There is no way to tell a masked value from a real one, so
         // the row is skipped and the operator is told to type it once.
         idx := FindCFGCommand(MIGRATED_COMMANDS[i]);
         if (idx >= 0) and (CFGCA[idx].crType = ctPassword) then
            begin
            logger.Warn('[SeedMigratedCommands] %s not carried over from tr4w.ini ' +
                        '-- passwords there may be a display mask.  Re-enter it in Preferences.',
                        [MIGRATED_COMMANDS[i]]);
            Continue;
            end;

         aStore.SetCommand(MIGRATED_COMMANDS[i], value);
         logger.Info('[SeedMigratedCommands] %s = %s carried over from tr4w.ini',
                     [MIGRATED_COMMANDS[i], value]);
         end;
   finally
      ini.Free;
   end;

   // DELIBERATELY NOT SAVED HERE, matching SeedLoggingFromIni. Writing
   // settings\tr4w.json during startup would mean the first run after an
   // upgrade rewrites the operator's configuration file before they have asked
   // for anything -- on a directory that may not even be writable. Until
   // Preferences saves, the ini stays the source and the carry-over simply
   // happens again next start: same key, same value, idempotent, and nothing
   // else writes that ini key now that the row is csJSON.
end;

procedure SeedLoggingFromIni(const aStore: TRadioConfigStore);
var
   ini: TIniFile;
begin
   // ONE-TIME MIGRATION, tr4w.ini -> the store's logging section.
   //
   // These five settings lived in tr4w.ini until their rows became csJSON,
   // which makes CheckCommand inert for them.  So on the first run after the
   // upgrade NOTHING would apply them and an operator with
   // DEBUG LOG LEVEL = DEBUG would silently drop to INFO -- precisely when
   // they were trying to diagnose something.
   //
   // Runs only when the JSON had no logging section at all.  Once Preferences
   // saves, the section exists and the ini is never consulted again, so a value
   // deliberately turned off later cannot be resurrected by a stale ini line.
   // The ini keys are left in place: harmless, inert, and a fallback if someone
   // rolls back to the previous build.
   if (aStore = nil) or aStore.HasLoggingSection then
      begin
      Exit;
      end;

   ini := TIniFile.Create(SettingsDirectory + 'tr4w.ini');
   try
      // Defaults are the store's OWN current values, so a key missing from the
      // ini leaves the default alone rather than forcing it to False.
      aStore.LogLevelName    := ini.ReadString(string(_COMMANDS), 'DEBUG LOG LEVEL',
                                               aStore.LogLevelName);
      aStore.HamLibDebug     := ini.ReadBool(string(_COMMANDS), 'HAMLIB DEBUG',
                                             aStore.HamLibDebug);
      aStore.HamLibAsyncOnly := ini.ReadBool(string(_COMMANDS), 'HAMLIB ASYNC ONLY',
                                             aStore.HamLibAsyncOnly);
      aStore.HamLibTrace     := ini.ReadBool(string(_COMMANDS), 'HAMLIB TRACE',
                                             aStore.HamLibTrace);
      aStore.TelnetDebug     := ini.ReadBool(string(_COMMANDS), 'TELNET DEBUG',
                                             aStore.TelnetDebug);
      logger.Info('[SeedLoggingFromIni] logging settings migrated from tr4w.ini (level %s)',
                  [aStore.LogLevelName]);
   finally
      ini.Free;
   end;
end;


procedure ApplyStoredCommands(const aStore: TRadioConfigStore);
var
   i: integer;
   name, value: string;
   keyShort, valueShort: ShortString;
begin
   // EVERY RETIRED ROW, APPLIED THROUGH CFGCA.
   //
   // csJSON makes CheckCommand inert for the INI LOADER, which is the whole
   // point -- a stale ini must not override the store.  Here we are the
   // trusted caller, so aApplyJSONOwned is True and the row behaves normally:
   // right typed global, crMin/crMax enforced, crA hook run.  Assigning the
   // globals directly instead would skip all three, and for MY CALL,
   // MY CONTINENT, MY COUNTRY and MY ZONE the hook is where dependent state
   // gets derived.
   if aStore = nil then
      begin
      Exit;
      end;

   for i := 0 to aStore.Commands.Count - 1 do
      begin
      name  := aStore.Commands.Names[i];
      value := aStore.Commands.ValueFromIndex[i];
      if name = '' then
         begin
         Continue;
         end;

      // THE LOADED CONTEST WINS OVER THE STATION DEFAULT.
      //
      // A contest .cfg that names a migrated setting has already applied it (see
      // LogCfg), and applying the stored value here would immediately undo it --
      // silently, because this runs after every config file. LEADING ZEROS is the
      // case that forced this: six real contest configs set it, and a
      // serial-number contest asking for leading zeros must not be overruled by
      // a station preference.
      //
      // The stored value is untouched and returns as soon as a contest that does
      // not claim it is loaded.
      if CommandCameFromContestCFG(name) then
         begin
         logger.Info('[ApplyStoredCommands] %s left to the contest .cfg -- stored value not applied', [name]);
         Continue;
         end;

      Windows.ZeroMemory(@keyShort, SizeOf(keyShort));
      Windows.ZeroMemory(@valueShort, SizeOf(valueShort));
      keyShort   := ShortString(AnsiString(name));
      valueShort := ShortString(AnsiString(value));

      if not CheckCommand(@keyShort, valueShort, True) then
         begin
         // Loud: a stored value CFGCA refuses is a setting the operator
         // believes is in force and is not.
         logger.Warn('[ApplyStoredCommands] CFGCA refused "%s" = "%s"', [name, value]);
         end;
      end;
end;

procedure SeedBandPlanFromIni(const aStore: TRadioConfigStore);
var
   buf: array[0..8191] of AnsiChar;
   n, i, start, freq, err: integer;
   line, key, value: string;
   band: BandType;
   mode: ModeType;
   vCutoff, vCW, vSSB: array[BandType] of integer;   // v- prefixed: a local named cw would SHADOW the CW member of ModeType
begin
   // ONE-TIME, and only into an empty store.  A station that has already saved
   // a band plan must not have it overwritten by a stale ini.
   if aStore.BandPlanCount > 0 then
      begin
      Exit;
      end;

   // GetPrivateProfileSectionA, not TIniFile.  [BAND PLAN] has REPEATED keys --
   // twelve `BAND MAP CUTOFF FREQUENCY=` lines and up to twenty-four
   // `FREQUENCY MEMORY=` ones -- and a TIniFile collapses duplicates, so it
   // would read one of each and silently drop the rest.  This is the exact
   // counterpart of the WritePrivateProfileSectionA that used to write it.
   Windows.ZeroMemory(@buf, SizeOf(buf));
   n := Windows.GetPrivateProfileSectionA('BAND PLAN', @buf[0], SizeOf(buf),
                                          PAnsiChar(WinAnsi(TR4W_INI_FILENAME)));
   if n = 0 then
      begin
      Exit;
      end;

   for band := Low(BandType) to High(BandType) do
      begin
      vCutoff[band] := 0;
      vCW[band]     := 0;
      vSSB[band]    := 0;
      end;

   // The buffer is a run of null-terminated "key=value" strings ending in a
   // second null.
   start := 0;
   for i := 0 to n do
      begin
      if buf[i] <> #0 then
         begin
         Continue;
         end;
      if i = start then
         begin
         Break;      // the second null: end of section
         end;

      line  := string(AnsiString(PAnsiChar(@buf[start])));
      start := i + 1;

      if Pos('=', line) = 0 then
         begin
         Continue;
         end;
      key   := Trim(Copy(line, 1, Pos('=', line) - 1));
      value := Trim(Copy(line, Pos('=', line) + 1, Length(line)));

      // The band is DERIVED from the frequency, exactly as F_FREQUENCY_MEMORY
      // and AddBandMapModeCutoffFrequency do it -- the ini format never stated
      // which band a line was for.
      if SameText(key, 'BAND MAP CUTOFF FREQUENCY') then
         begin
         Val(value, freq, err);
         if err = 0 then
            begin
            CalculateBandMode(freq, band, mode);
            vCutoff[band] := freq;
            end;
         end
      else if SameText(key, 'FREQUENCY MEMORY') then
         begin
         // The 'SSB ' prefix inside the VALUE is what selected phone.
         if Copy(UpperCase(value), 1, 4) = 'SSB ' then
            begin
            Val(Trim(Copy(value, 5, Length(value))), freq, err);
            if err = 0 then
               begin
               CalculateBandMode(freq, band, mode);
               vSSB[band] := freq;
               end;
            end
         else
            begin
            Val(value, freq, err);
            if err = 0 then
               begin
               CalculateBandMode(freq, band, mode);
               vCW[band] := freq;
               end;
            end;
         end;
      end;

   for band := Low(BandType) to High(BandType) do
      begin
      aStore.SetBandPlan(string(AnsiString(BandStringsArrayWithOutSpaces[band])),
                         vCutoff[band], vCW[band], vSSB[band]);
      end;

   if aStore.BandPlanCount > 0 then
      begin
      logger.Info('[BandPlan] seeded %d band(s) from tr4w.ini', [aStore.BandPlanCount]);
      end;
end;

function PaletteSpellings: TArray<string>;
var
   c: tr4wColors;
begin
   SetLength(Result, Ord(High(tr4wColors)) - Ord(Low(tr4wColors)) + 1);
   for c := Low(tr4wColors) to High(tr4wColors) do
      begin
      Result[Ord(c)] := string(AnsiString(tr4wColorsSA[c]));
      end;
end;

function ColorFromSpelling(const aSpelling: string; out aColor: tr4wColors): boolean;
var
   c: tr4wColors;
begin
   Result := False;
   for c := Low(tr4wColors) to High(tr4wColors) do
      begin
      if SameText(string(AnsiString(tr4wColorsSA[c])), aSpelling) then
         begin
         aColor := c;
         Result := True;
         Exit;
         end;
      end;
end;

procedure SeedElementColorsFromGlobals(const aStore: TRadioConfigStore);
var
   e: TMainWindowElement;
begin
   // ONE-TIME, into an empty store, and FROM THE GLOBALS rather than from the
   // ini -- which is the faithful migration here and was not an option for the
   // band plan.
   //
   // The config loader is SECTION-BLIND: it reads every line of tr4w.ini in
   // order regardless of which [SECTION] it sits under, which is the only
   // reason writing colors into [COLORS] ever worked.  So by the time this
   // runs, whatever the ini said is already in TWindows, and copying it out is
   // exact -- no second parser, and no chance of the two disagreeing.
   if aStore.ColorCount > 0 then
      begin
      Exit;
      end;

   for e := Low(TMainWindowElement) to High(TMainWindowElement) do
      begin
      if TWindows[e].mweName = nil then
         begin
         Continue;
         end;
      aStore.SetElementColors(string(AnsiString(TWindows[e].mweName)),
                              string(AnsiString(tr4wColorsSA[TWindows[e].mweColor])),
                              string(AnsiString(tr4wColorsSA[TWindows[e].mweBackG])));
      end;

   logger.Info('[Colors] seeded %d element(s) from the loaded configuration',
               [aStore.ColorCount]);
end;

procedure ApplyElementColors(const aStore: TRadioConfigStore);
var
   e: TMainWindowElement;
   entry: TElementColors;
   col: tr4wColors;
begin
   SeedElementColorsFromGlobals(aStore);

   for e := Low(TMainWindowElement) to High(TMainWindowElement) do
      begin
      if TWindows[e].mweName = nil then
         begin
         Continue;
         end;

      entry := aStore.FindElementColors(string(AnsiString(TWindows[e].mweName)));
      if entry = nil then
         begin
         Continue;
         end;

      // An UNRECOGNISED spelling leaves the element alone and says so.  A
      // hand-edited file with a typo in it should not silently repaint the
      // callsign window black.
      if entry.Foreground <> '' then
         begin
         if ColorFromSpelling(entry.Foreground, col) then
            begin
            TWindows[e].mweColor := col;
            end
         else
            begin
            logger.Warn('[Colors] %s: "%s" is not a color this build knows',
                        [entry.Element, entry.Foreground]);
            end;
         end;

      if entry.Background <> '' then
         begin
         if ColorFromSpelling(entry.Background, col) then
            begin
            TWindows[e].mweBackG := col;
            end
         else
            begin
            logger.Warn('[Colors] %s background: "%s" is not a color this build knows',
                        [entry.Element, entry.Background]);
            end;
         end;
      end;

   // ON SCREEN NOW, not at the next start.  Assigning TWindows changes what the
   // next paint WOULD use; a list view has already been handed its colours and
   // never asks again.  RefreshMainWindowColors does both halves and is a no-op
   // before the main window exists, which is the case at startup.
   RefreshMainWindowColors;
end;

procedure ApplyBandPlan(const aStore: TRadioConfigStore);
var
   band: BandType;
   e: TBandPlanEntry;
   cfgOwnsCutoff, cfgOwnsMemory: boolean;
begin
   SeedBandPlanFromIni(aStore);

   // THE LOADED CONTEST WINS, exactly as it does in ApplyStoredCommands.  A
   // contest .cfg that carries FREQUENCY MEMORY lines has already applied them,
   // and a station-wide band plan must not undo that -- the two rows are csJSON
   // now, and LogCfg applies a csJSON row from the contest .cfg as a trusted
   // caller for precisely this reason.
   cfgOwnsCutoff := CommandCameFromContestCFG('BAND MAP CUTOFF FREQUENCY');
   cfgOwnsMemory := CommandCameFromContestCFG('FREQUENCY MEMORY');

   for band := Low(BandType) to High(BandType) do
      begin
      e := aStore.FindBandPlan(string(AnsiString(BandStringsArrayWithOutSpaces[band])));
      if e = nil then
         begin
         Continue;
         end;

      // A ZERO IS NOT A VALUE.  An absent number leaves that band's compiled
      // default alone, which is what an empty cell in the editor means and what
      // the ini loader did by simply never seeing a line for it.
      if (e.Cutoff <> 0) and (not cfgOwnsCutoff) and
         (band >= Band160) and (band <= Band2) then
         begin
         BandMapModeCutoffFrequency[band] := e.Cutoff;
         end;
      if (e.CW <> 0) and (not cfgOwnsMemory) then
         begin
         DefaultFreqMemory[band, CW] := e.CW;
         end;
      if (e.SSB <> 0) and (not cfgOwnsMemory) then
         begin
         DefaultFreqMemory[band, Phone] := e.SSB;
         end;
      end;
end;

function ApplyAndStoreCommand(const aStore: TRadioConfigStore;
                              const aCommand, aValue: string): boolean;
var
   keyShort, valueShort: ShortString;
begin
   // APPLY FIRST, RECORD SECOND -- the same order as everywhere else here.
   // CheckCommand is what moves the value into the live globals and runs the
   // hook; the store is only what makes it survive a restart.  Recording a
   // value CFGCA rejected would put it in the file for the next start to
   // stumble over.
   Windows.ZeroMemory(@keyShort, SizeOf(keyShort));
   Windows.ZeroMemory(@valueShort, SizeOf(valueShort));
   keyShort   := ShortString(AnsiString(aCommand));
   valueShort := ShortString(AnsiString(aValue));

   Result := CheckCommand(@keyShort, valueShort, True);
   if Result and (aStore <> nil) then
      begin
      aStore.SetCommand(aCommand, aValue);
      end;
end;

function ApplyStoredCommand(const aCommand: string): boolean;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr, value: string;
   keyShort, valueShort: ShortString;
begin
   Result := False;
   if not FileExists(RadioStoreFileName) then
      begin
      Exit;
      end;

   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   udp    := TUDPBroadcastConfig.Create;
   try
      if not LoadConfig(RadioStoreFileName, store, keyers, loadErr, udp) then
         begin
         logger.Warn('[Startup] %s could not be read for %s: %s',
                     [RadioStoreFileName, aCommand, loadErr]);
         Exit;
         end;

      value := store.CommandValue(aCommand, '');
      if value = '' then
         begin
         Exit;   // not stored: the ini or the .cfg keeps whatever it set
         end;

      Windows.ZeroMemory(@keyShort, SizeOf(keyShort));
      Windows.ZeroMemory(@valueShort, SizeOf(valueShort));
      keyShort   := ShortString(AnsiString(aCommand));
      valueShort := ShortString(AnsiString(value));

      // True: apply even when the row is csJSON, which is the whole point.
      Result := CheckCommand(@keyShort, valueShort, True);
      if Result then
         begin
         logger.Info('[Startup] %s = %s applied from %s',
                     [aCommand, value, RadioStoreFileName]);
         end
      else
         begin
         logger.Warn('[Startup] CFGCA refused stored %s = "%s"', [aCommand, value]);
         end;
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

function GridPromptAlreadyShown: boolean;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr: string;
begin
   Result := False;
   if not FileExists(RadioStoreFileName) then
      begin
      Exit;   // first run: nothing asked yet
      end;

   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   udp    := TUDPBroadcastConfig.Create;
   try
      if LoadConfig(RadioStoreFileName, store, keyers, loadErr, udp) then
         begin
         Result := store.GridPromptShown;
         end;
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

procedure MarkGridPromptShown;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr: string;
begin
   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   udp    := TUDPBroadcastConfig.Create;
   try
      if FileExists(RadioStoreFileName) then
         begin
         if not LoadConfig(RadioStoreFileName, store, keyers, loadErr, udp) then
            begin
            // REFUSE rather than write over a file we could not read.  The cost
            // is being asked again next start, which is the old behaviour.
            logger.Error('[Startup] not recording the grid prompt: %s could not be read (%s)',
                         [RadioStoreFileName, loadErr]);
            Exit;
            end;
         end;

      if store.GridPromptShown then
         begin
         Exit;   // already recorded -- do not rewrite the file every start
         end;

      store.GridPromptShown := True;
      SaveConfig(RadioStoreFileName, store, keyers, udp);
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

function GetLatestConfigFile: string;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr: string;
begin
   Result := '';
   if not FileExists(RadioStoreFileName) then
      begin
      Exit;   // first run: no previous contest, not an error
      end;

   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   udp    := TUDPBroadcastConfig.Create;
   try
      if LoadConfig(RadioStoreFileName, store, keyers, loadErr, udp) then
         begin
         Result := store.LatestConfigFile;
         end
      else
         begin
         logger.Warn('[Startup] cannot read %s for the latest config file: %s',
                     [RadioStoreFileName, loadErr]);
         end;
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

procedure SetLatestConfigFile(const aFileName: string);
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr: string;
begin
   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   udp    := TUDPBroadcastConfig.Create;
   try
      // ALL THREE LIBRARIES ARE LOADED AND SAVED TOGETHER even though only one
      // scalar changes: they share one file, and saving a store that was loaded
      // without the others would silently drop their sections. Same rule as
      // ApplyPeerCommand below.
      if FileExists(RadioStoreFileName) then
         begin
         if not LoadConfig(RadioStoreFileName, store, keyers, loadErr, udp) then
            begin
            // REFUSE rather than write over a file we could not read.
            logger.Error('[Startup] not recording the latest config file: %s could not be read (%s)',
                         [RadioStoreFileName, loadErr]);
            Exit;
            end;
         end;

      if SameText(store.LatestConfigFile, aFileName) then
         begin
         Exit;   // unchanged -- do not rewrite the file on every start
         end;

      store.LatestConfigFile := aFileName;
      SaveConfig(RadioStoreFileName, store, keyers, udp);
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

function ApplyPeerCommand(const aCommand, aValue: string): boolean;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr: string;
   ini: TIniFile;
begin
   Result := False;

   if not CommandIsJSONOwned(aCommand) then
      begin
      // UNCHANGED BEHAVIOUR for a row that has not migrated: apply, then write
      // the ini key.  ApplyAndStoreCommand with a nil store is exactly
      // CheckCommand here -- aApplyJSONOwned only gates csJSON rows, and this
      // is not one.
      Result := ApplyAndStoreCommand(nil, aCommand, aValue);
      if Result then
         begin
         // TIniFile rather than WritePrivateProfileStringA: D12/FPC bind the
         // generic name to the W variant, and this call site was passing
         // @ShortString[1] to it.  It happened to work because the parameter is
         // an untyped pointer; it is the trap documented in CLAUDE.md and there
         // is no reason to keep it when the RTL wrapper says what it means.
         ini := TIniFile.Create(SettingsDirectory + 'tr4w.ini');
         try
            ini.WriteString(string(_COMMANDS), aCommand, aValue);
         finally
            ini.Free;
         end;
         end;
      Exit;
      end;

   // A MIGRATED ROW.  All three libraries are loaded and saved together even
   // though only one command changes: they share one file, and saving a store
   // that was loaded without the others would silently drop their sections.
   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   udp    := TUDPBroadcastConfig.Create;
   try
      if FileExists(RadioStoreFileName) then
         begin
         if not LoadConfig(RadioStoreFileName, store, keyers, loadErr, udp) then
            begin
            // REFUSE rather than write over a file we could not read.  Returning
            // False means the caller says nothing changed, which is true.
            logger.Error('[ApplyPeerCommand] "%s" not applied: %s cannot be read (%s)',
                         [aCommand, RadioStoreFileName, loadErr]);
            Exit;
            end;
         end;

      Result := ApplyAndStoreCommand(store, aCommand, aValue);
      if Result then
         begin
         // Creating the file when it did not exist is intended.  Startup skips
         // the store entirely when there is no file, so without writing one the
         // peer's change would apply to this session and be gone on restart --
         // which is the failure this routine exists to remove.
         SaveConfig(RadioStoreFileName, store, keyers, udp);
         end;
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

procedure ApplyActiveCluster(const aStore: TRadioConfigStore);
var
   c: TClusterDefinition;
begin
   // NOTHING CHOSEN LEAVES THE LEGACY SETTINGS ALONE.  An operator who has never
   // opened the DX Cluster page still has TELNET SERVER in their ini and must
   // keep connecting exactly as before -- the same migration rule the rotators
   // use.  Clearing the globals here would take the cluster away from everyone
   // who has not adopted the library yet.
   if (aStore = nil) or (aStore.ActiveCluster = nil) then
      begin
      Exit;
      end;

   c := aStore.ActiveCluster;

   if Trim(c.Server) <> '' then
      begin
      ApplyAndStoreCommand(aStore, 'TELNET SERVER', Trim(c.Server));
      end;

   // BLANK LOGIN MEANS MY CALL, which is what the field's own hint promises.
   // Left blank HERE and resolved at connect time, because MyCall can change
   // after startup -- a different contest, a different operator -- and baking it
   // in now would log in as whoever was configured when the program booted.
   TelnetLoginCall := Trim(c.LoginCall);

   // NOT trimmed: a password may legitimately begin or end with a space, and
   // trimming one produces a login failure with no visible cause.
   TelnetPassword := c.Password;

   // The post-login command.  Str20 is the legacy declaration and it truncates,
   // so SAY SO rather than quietly sending half of what the operator typed.
   if Length(Trim(c.ConnectCommand)) > 20 then
      begin
      logger.Warn('[ApplyActiveCluster] "After connecting" is %d characters and the ' +
                  'legacy ConnectionCommand holds 20 -- it will be truncated',
                  [Length(Trim(c.ConnectCommand))]);
      end;
   ConnectionCommand := Str20(Trim(c.ConnectCommand));

   // The password itself is never logged, at any level.
   logger.Info('[ApplyActiveCluster] "%s" -> %s, login "%s"%s',
               [c.Name, c.Server, TelnetLoginCall,
                IfThen(TelnetPassword <> '', ', password set', '')]);
end;

procedure ApplyLoggingSettings(const aStore: TRadioConfigStore);
var
   lvl: tLogLevels;
   wanted: string;
   matched: boolean;
begin
   if aStore = nil then
      begin
      Exit;
      end;

   SeedLoggingFromIni(aStore);

   wanted  := UpperCase(Trim(aStore.LogLevelName));
   matched := False;
   for lvl := Low(tLogLevels) to High(tLogLevels) do
      begin
      if wanted = UpperCase(string(AnsiString(tLogLevelsSA[lvl]))) then
         begin
         logLevels := lvl;
         matched   := True;
         Break;
         end;
      end;

   if not matched then
      begin
      logger.Warn('[ApplyLoggingSettings] "%s" is not a log level -- keeping the current one',
                  [aStore.LogLevelName]);
      end;

   TR4W_HAMLIB_DEBUG      := aStore.HamLibDebug;
   TR4W_HAMLIB_ASYNC_ONLY := aStore.HamLibAsyncOnly;
   TR4W_HAMLIB_TRACE      := aStore.HamLibTrace;
   TR4W_TELNET_DEBUG      := aStore.TelnetDebug;

   // The whole reason the level is wired this way.  Safe before the logger
   // exists: it checks and returns.
   UpdateDebugLogLevel;
end;

// The part of a key after 'RADIO ONE ' / 'RADIO TWO ', or the whole key if it
// does not have that shape.
//
// NOT EVERY RADIO KEY IS SLOT-PREFIXED, which is why this does not just chop a
// fixed number of characters: 'KEYER RADIO ONE OUTPUT PORT' and
// 'POLL RADIO ONE' put the slot in the MIDDLE and at the END.  Neither is in
// Set 1, but both will arrive here when their sets move, and a naive strip
// would silently produce a suffix that matches nothing -- or worse, one that
// matches the wrong row.  Returning the key whole makes such a case fall into
// the applier's else-branch, which logs an error loudly.
function KeySuffix(const aKey: string): string;
const
   PREFIX_ONE = 'RADIO ONE ';
   PREFIX_TWO = 'RADIO TWO ';
begin
   if StartsText(PREFIX_ONE, aKey) then
      begin
      Result := Copy(aKey, Length(PREFIX_ONE) + 1, MaxInt);
      end
   else if StartsText(PREFIX_TWO, aKey) then
      begin
      Result := Copy(aKey, Length(PREFIX_TWO) + 1, MaxInt);
      end
   else
      begin
      Result := aKey;
      end;
end;

// ---------------------------------------------------------------------------
// The direct applier for rows that JSON now owns (Set 1: plain scalars).
//
// WHY THIS EXISTS AT ALL.  csJSON makes CheckCommand INERT, and CheckCommand is
// the only thing that moves a radio setting into TR4W's live globals.  So
// retiring a row without an applier for it does not fall back to the ini -- it
// silently configures nothing.  The retirement and the applier are therefore
// one piece of work, and that is why this landed in the same commit as the
// csJSON flips rather than after them.
//
// WHY IT TAKES THE RENDERED STRING RATHER THAN THE TYPED TRadioDefinition.
// This looks like the round trip NY4I objected to for auto-info, and it is
// deliberately not the same case.  Auto-info had NO legacy reader: nothing in
// the old tree had ever heard of it, so there was no existing rule to preserve
// and inventing an ini key would have been pure ceremony.  These thirteen rows
// are the opposite -- the renderer already holds rules that are load-bearing
// and bench-proven:
//
//   * a NETWORK radio blanks SERIAL FORMAT, and a SERIAL radio blanks
//     IP ADDRESS / NETWORK USERNAME / NETWORK PASSWORD.  Not tidiness: a stale
//     value in the inapplicable field is how a K4 with a good IP came up as
//     "NO PORT SET" (2026-08-05), and how a shared serial port gets stolen
//     from the other radio.
//   * TCP PORT falls back to the model's default when unset (NumericValue).
//   * FACTORY ID is emitted for a string-id radio and DELETED for an enum one,
//     because a stale FACTORY ID resurrects the previous radio.
//
// Re-deriving that from aRadio here would be a SECOND implementation of those
// rules, which is precisely the drift the audit warns about -- the same
// vocabulary hazard has already bitten twice (NONE vs TCP/IP cost a bench
// session; the mirror of it silently converted a network K4 to serial).  One
// source of values, two destinations: the ini for rows still owned by CFGCA,
// the globals directly for rows JSON owns.  When every set has moved, the
// renderer collapses into this function and the strings disappear with it.
//
// VALIDATION IS NOT OPTIONAL HERE.  Bypassing CheckCommand also bypasses the
// crMin/crMax bounds it enforced, and the bounds are NOT decorative: a Str20
// silently TRUNCATES a longer name in Delphi rather than failing, and
// ICOM DATA MODE ID outside 1..3 is a mode the radio does not have.  Each case
// below carries the same bound as its CommandsArray row, and a rejection is
// logged and NOT applied -- matching what CFGCA did, so a bad JSON value
// behaves the way a bad ini value did.
function ApplyJSONOwnedRadioKey(const aSlot: integer;
                                const aSuffix: string;
                                const aValue: string;
                                const aDelete: boolean): boolean;
var
   rig: RadioPtr;
   n: integer;

   // Assign a string, refusing one too long for its ShortString target rather
   // than letting Delphi truncate it in silence.
   function FitsIn(const aMax: integer): boolean;
   begin
      Result := Length(aValue) <= aMax;
      if not Result then
         begin
         logger.Warn('[ApplyJSONOwnedRadioKey] %s: "%s" is %d chars, max %d -- NOT applied',
                     [aSuffix, aValue, Length(aValue), aMax]);
         end;
   end;

   // Parse an integer within bounds.  An unparseable or out-of-range value is
   // refused, not silently coerced to zero -- StrToIntDef(s, 0) would turn
   // "garbage" into a legal-looking 0, which for TCP PORT means "no port".
   function IntInRange(const aMin, aMax: integer; out aOut: integer): boolean;
   var
      code: integer;
   begin
      Val(aValue, aOut, code);
      Result := (code = 0) and (aOut >= aMin) and (aOut <= aMax);
      if not Result then
         begin
         logger.Warn('[ApplyJSONOwnedRadioKey] %s: "%s" is not an integer in %d..%d -- NOT applied',
                     [aSuffix, aValue, aMin, aMax]);
         end;
   end;

begin
   Result := True;

   if aSlot = 2 then
      begin
      rig := @Radio2;
      end
   else
      begin
      rig := @Radio1;
      end;

   // A DELETE clears the field.  Only FACTORY ID is emitted this way today,
   // and for it "" and "absent" mean the same thing to the factory: no
   // string-id radio.  Handled before the case so every future deletable row
   // gets the same treatment for free.
   if aDelete then
      begin
      if SameText(aSuffix, 'FACTORY ID') then
         begin
         rig^.FactoryId := '';
         end;
      Exit;
      end;

   if SameText(aSuffix, 'NAME') then
      begin
      if FitsIn(20) then rig^.RadioName := Str20(aValue) else Result := False;
      end
   else if SameText(aSuffix, 'FACTORY ID') then
      begin
      // 48, not 50: the CommandsArray row says 48 and this must not be laxer
      // than the rule it replaces.
      if FitsIn(48) then rig^.FactoryId := Str50(aValue) else Result := False;
      end
   else if SameText(aSuffix, 'IP ADDRESS') then
      begin
      if FitsIn(50) then rig^.IPAddress := Str50(aValue) else Result := False;
      end
   else if SameText(aSuffix, 'NETWORK USERNAME') then
      begin
      if FitsIn(50) then rig^.NetworkUsername := Str50(aValue) else Result := False;
      end
   else if SameText(aSuffix, 'NETWORK PASSWORD') then
      begin
      if FitsIn(50) then rig^.NetworkPassword := Str50(aValue) else Result := False;
      end
   else if SameText(aSuffix, 'SERIAL FORMAT') then
      begin
      // 3 is a LENGTH, not a value: '8N2'.  Blank is legal and means "use the
      // driver's default", which is how a network radio renders.
      if FitsIn(3) then rig^.SerialFormat := Str50(aValue) else Result := False;
      end
   else if SameText(aSuffix, 'STARTUP COMMAND') then
      begin
      if FitsIn(50) then rig^.StartupCommand := Str50(aValue) else Result := False;
      end
   else if SameText(aSuffix, 'TCP PORT') then
      begin
      if IntInRange(0, 65535, n) then rig^.RadioTCPPort := n else Result := False;
      end
   else if SameText(aSuffix, 'RECEIVER ADDRESS') then
      begin
      if IntInRange(0, MAXWORD, n) then rig^.ReceiverAddress := n else Result := False;
      end
   else if SameText(aSuffix, 'HAMLIB ID') then
      begin
      if IntInRange(0, MAXWORD, n) then rig^.HamLibID := n else Result := False;
      end
   else if SameText(aSuffix, 'FREQUENCY ADDER') then
      begin
      if IntInRange(0, MAXWORD, n) then rig^.FrequencyAdder := n else Result := False;
      end
   else if SameText(aSuffix, 'ICOM DATA MODE ID') then
      begin
      if IntInRange(1, 3, n) then rig^.IcomDataModeID := Byte(n) else Result := False;
      end
   else if SameText(aSuffix, 'KEYER STOP BITS') then
      begin
      if IntInRange(0, 2, n) then rig^.RadioKeyerStopBits := n else Result := False;
      end
   else
      begin
      // A row was flipped to csJSON with no applier written for it.  This is
      // the exact failure the audit warns about -- it would otherwise be
      // SILENT, the setting simply never reaching the program -- so it is
      // loud, and the unit test below asserts it cannot happen.
      logger.Error('[ApplyJSONOwnedRadioKey] "%s" is csJSON but has NO applier -- ' +
                   'the setting will not reach the program', [aSuffix]);
      Result := False;
      end;
end;

procedure ApplyRadioToSlot(const aRadio: TRadioDefinition;
                           const aSlot: integer;
                           const aProfile: TStationProfile;

                           const aNamesAKeyerDevice: boolean = False);
var
   rendered: TConfigKeyValues;
   i: integer;
   typeRendering: TRadioTypeRendering;
   idKey, cmdValue: AnsiString;
   keyShort, valueShort: ShortString;
   accepted: boolean;
begin
   if aRadio <> nil then
      begin
      typeRendering := ResolveTypeRendering(aRadio.RegistryId);
      end
   else
      begin
      typeRendering := Default(TRadioTypeRendering);
      end;

   // SETTINGS THAT ARE NEW GO STRAIGHT ONTO THE RADIO.
   //
   // The rendered-keys path below exists to feed CFGCA -- it is a BRIDGE to
   // legacy code that reads its configuration from ini commands.  Auto-info
   // has no legacy reader: nothing in the old tree has ever heard of it, so
   // routing it through an ini key would invent a round trip through a format
   // we are trying to retire, purely to arrive back in memory (NY4I).
   //
   // Assigned before the keys are written for the same reason they are: the
   // radio has not been opened yet at this point, and SetUpRadioInterface
   // hands the value to the driver through ApplyAutoInfoLevel when it is.
   if aSlot = 1 then
      begin
      Radio1.AutoInfoLevel := 0;
      end
   else
      begin
      Radio2.AutoInfoLevel := 0;
      end;
   if aRadio <> nil then
      begin
      if aSlot = 1 then
         begin
         Radio1.AutoInfoLevel := aRadio.AutoInfoLevel;
         end
      else
         begin
         Radio2.AutoInfoLevel := aRadio.AutoInfoLevel;
         end;
      logger.Debug('[ApplyProfile] radio %d auto-info level %d',
                   [aSlot, aRadio.AutoInfoLevel]);
      end;

   rendered := RenderRadioKeys(aSlot, aRadio, typeRendering, aProfile, aNamesAKeyerDevice);

   for i := 0 to High(rendered) do
      begin
      // A SETTING THAT HAS MOVED TO JSON IS NOT WRITTEN HERE.
      //
      // csJSON means the ini row is inert: CheckCommand accepts it so an old
      // config does not error, and then does nothing with it.  Emitting such
      // a key would write a value into a file nothing reads -- which is worse
      // than useless, because the next person to open the ini sees it and
      // takes it for the system of record.
      //
      // Asking the row rather than maintaining a second list is the point
      // (NY4I): migrating a setting becomes "add the direct applier, flip the
      // row to csJSON", and this writer follows automatically.  A hand-removed
      // Emit is a second place to keep in step, and it will not be.
      if CommandIsJSONOwned(rendered[i].Key) then
         begin
         // ...but it still has to REACH THE PROGRAM.  Skipping the ini write is
         // only half of the retirement: CheckCommand below is what moves a
         // value into the live globals, and csJSON has just made it inert for
         // this row.  Without the direct applier the setting would be stored
         // perfectly in JSON, shown correctly in Preferences, and never
         // actually configure anything.
         logger.Debug('[ApplyProfile] %s is csJSON -- Preferences owns it, not the ini',
                      [rendered[i].Key]);
         ApplyJSONOwnedRadioKey(aSlot, KeySuffix(rendered[i].Key),
                                rendered[i].Value, rendered[i].Delete);
         Continue;
         end;

      // A FRESH AnsiString per value, not a reused buffer.  The ini write takes
      // @s[1] as a null-terminated PAnsiChar, so a shorter value assigned over
      // a longer one in the same ShortString leaves the previous tail in place
      // and the FILE receives the leftover -- the corruption NY4I hit on the
      // port combo, where the log and the ini disagreed.
      idKey    := AnsiString(rendered[i].Key);
      cmdValue := AnsiString(rendered[i].Value);

      Windows.ZeroMemory(@keyShort, SizeOf(keyShort));
      Windows.ZeroMemory(@valueShort, SizeOf(valueShort));
      keyShort   := ShortString(idKey);
      valueShort := ShortString(cmdValue);

      // VALIDATE FIRST, PERSIST SECOND.  CheckCommand is what actually moves the
      // value into TR4W's globals; the ini write is only what makes it survive
      // a restart.  The order used to be the other way round, so a value CFGCA
      // REJECTED was still written to the operator's ini -- and the next
      // startup stopped on it with "Invalid statement in config file".  That is
      // not hypothetical: a cleared slot rendered RADIO TWO BAUD RATE=0, CFGCA
      // refused it (it is ckArray), the warning was logged, the line was
      // written anyway, and TR4W would not start (NY4I, 2026-08-08).
      //
      // A rejected key now leaves the ini untouched, so at worst the file keeps
      // its previous value for that one key -- a stale line beats an unstartable
      // program, and the warning still says the renderer and CFGCA have drifted.
      accepted := CheckCommand(@keyShort, valueShort);
      if not accepted then
         begin
         logger.Warn('[ApplyRadioToSlot] CFGCA did not accept "%s" = "%s" -- NOT written to the ini',
                     [rendered[i].Key, rendered[i].Value]);
         end;

      end;

   if aRadio <> nil then
      begin
      logger.Info('[ApplyRadioToSlot] Radio %s := %s (%s), %d keys',
                  [SlotWord(aSlot), aRadio.Name, aRadio.RegistryId, Length(rendered)]);
      end
   else
      begin
      logger.Info('[ApplyRadioToSlot] Radio %s cleared, %d keys',
                  [SlotWord(aSlot), Length(rendered)]);
      end;
end;

// The keyer DEVICE a slot's CW-output choice names, or nil.  CAT, RADIOPORT and
// NONE are the renderer's business and are not devices, so they resolve to nil.
function KeyerDeviceForSlot(const aKeyers: TKeyerConfigStore;
                            const aProfile: TStationProfile;
                            const aSlot: integer): TKeyerDefinition;
var
   cwChoice, cwId: string;
begin
   Result := nil;
   if (aKeyers = nil) or (aProfile = nil) then
      begin
      Exit;
      end;

   if aSlot = 2 then
      begin
      cwChoice := Trim(aProfile.CWOutput2);
      cwId     := Trim(aProfile.CWOutput2Id);
      end
   else
      begin
      cwChoice := Trim(aProfile.CWOutput1);
      cwId     := Trim(aProfile.CWOutput1Id);
      end;

   { THE ID FIRST, THE NAME AS A FALLBACK.

     The id is the reference and survives a rename. The name lookup stays
     because it is also the MIGRATION: the keyer store is a different store from
     the one profiles live in, so a profile read from a file written before
     keyer ids cannot be resolved during load -- there is nothing to resolve
     against yet. Falling back here means such a profile keeps working
     unchanged, and gains its id the next time Preferences writes it.

     'CAT' and 'NONE' match no keyer by either route and correctly yield nil. }
   Result := aKeyers.FindKeyerById(cwId);
   if Result = nil then
      begin
      Result := aKeyers.FindKeyer(cwChoice);
      end;
end;

// Configures every keyer device the profile names, and settles whether the
// WinKeyer is enabled AT ALL.
//
// PROFILE-LEVEL, not per-slot, for two reasons.  The enable flag is one flag
// for the whole program, so deciding it inside a per-slot loop would let slot 2
// undo what slot 1 asked for.  And it must be decided in BOTH directions: WK
// ENABLE is csJSON and so inert in the ini, which means nothing but this
// routine can ever turn the WinKeyer back off -- a profile switched from a
// WinKeyer to CW-by-CAT would otherwise keep opening the keyer's port for the
// rest of the session.
procedure ApplyKeyersForProfile(const aKeyers: TKeyerConfigStore;
                                const aProfile: TStationProfile);
var
   slot: integer;
   keyerDef: TKeyerDefinition;
   winKeyer: TKeyerDefinition;
   keyerErr: string;
begin
   winKeyer := nil;

   for slot := 1 to 2 do
      begin
      keyerDef := KeyerDeviceForSlot(aKeyers, aProfile, slot);
      if (keyerDef = nil) or (keyerDef.Kind <> kkWinKeyer) then
         begin
         Continue;
         end;

      // TR4W has ONE WinKeyer: a single WinKeySettings, a single port, a single
      // thread.  Two slots naming two DIFFERENT WinKeyers cannot both be
      // honoured, and silently letting the second win would be a keyer on the
      // wrong port with nothing said about it.
      if (winKeyer <> nil) and (not SameText(winKeyer.Name, keyerDef.Name)) then
         begin
         logger.Warn('[Keyer] profile "%s" names two different WinKeyers ("%s" and "%s"); ' +
                     'TR4W supports one, so "%s" is used',
                     [aProfile.Name, winKeyer.Name, keyerDef.Name, winKeyer.Name]);
         Continue;
         end;

      // REPORTED, not swallowed: a WinKeyer silently keeping the previous
      // settings is a fault an operator blames on the box.
      if ApplyKeyerToWinKey(keyerDef, keyerErr) then
         begin
         winKeyer := keyerDef;
         end
      else
         begin
         logger.Warn('[Keyer] %s', [keyerErr]);
         end;
      end;

   // False when the profile names none, or when the one it named could not be
   // configured -- enabling a keyer we failed to set up would start its thread
   // against a port we never validated.
   SetWinKeyerEnabled(winKeyer <> nil);

   // A profile STATED the CW output for each slot, so the CW-by-CAT versus
   // hardware-keyer combination is no longer an ambiguity to warn about: the
   // per-slot choice is written as the per-radio CWByCAT that ActiveCWKeyer
   // already tests, so it resolves by radio.  The warning predates profiles.
   KeyerSelectionIsProfileDriven := True;

   if winKeyer <> nil then
      begin
      logger.Info('[Keyer] profile "%s" uses WinKeyer "%s" on %s',
                  [aProfile.Name, winKeyer.Name, winKeyer.Port]);
      end;
end;

function ApplyProfile(const aStore: TRadioConfigStore;
                      const aProfile: TStationProfile;
                      out aError: string;
                      const aKeyers: TKeyerConfigStore = nil): boolean;
var
   slot: integer;
   radioDef: TRadioDefinition;
   // NOT named radioPtr: Delphi is case-insensitive, so a variable of that name
   // shadows the TYPE RadioPtr in its own declaration.
   slotRadio: RadioPtr;
   previousCATWTR: RadioPtr;
   // Per-phase timing -- see the comment at the first log line below.
   tStart, tPhase: cardinal;
begin
   aError := '';
   Result := False;

   if (aStore = nil) or (aProfile = nil) then
      begin
      aError := 'No profile to apply';
      Exit;
      end;

   // Resolve BOTH slots before touching anything.  Half-applying a profile --
   // slot one swapped, slot two failed -- would leave the station in a state
   // that matches neither the old profile nor the new one.
   for slot := 1 to 2 do
      begin
      if Trim(aProfile.RadioNameForSlot(slot)) = '' then
         begin
         Continue;
         end;
      if aStore.FindRadioById(aProfile.RadioIdForSlot(slot)) = nil then
         begin
         aError := Format('Profile "%s" refers to radio "%s", which does not exist',
                          [aProfile.Name, aProfile.RadioNameForSlot(slot)]);
         Exit;
         end;
      end;

   // TIMED, PER PHASE.  NY4I: "there seems to be a noticable delay when swapping
   // profiles... to debug this, consider if we need more debug log messages
   // right after the user selects the next profile and presses Activate."
   //
   // Timing each phase rather than the whole thing, because the answer decides
   // what to do next and the phases have very different fixes: closing ports is
   // waiting on the OS and on a polling thread noticing; writing keys is CPU;
   // reopening is the radio's own startup.  A single total would say "it is
   // slow" and nothing more.
   //
   // The swap case NY4I describes -- the same two radios trading slots, both
   // already connected -- is the one worth measuring: everything gets torn down
   // and rebuilt to reach a state that was already true.  Whether that is worth
   // an exception path is a decision to make from numbers, not from a hunch.
   tStart := GetTickCount;
   logger.Info('[ApplyProfile] Applying profile "%s"', [aProfile.Name]);

   // CATWTR is the "radio being configured" that uCAT's helpers work through.
   // Save and restore it: this unit is not the CAT dialog and must not leave
   // that global pointing somewhere the dialog does not expect.
   previousCATWTR := CATWTR;
   try
      for slot := 1 to 2 do
         begin
         if slot = 1 then
            begin
            slotRadio := @Radio1;
            end
         else
            begin
            slotRadio := @Radio2;
            end;

         CATWTR := slotRadio;

         // Stop first, for every slot, BEFORE any key is written.  If slot two
         // is about to take over slot one's COM port -- which is exactly what
         // swapping two radios on one interface looks like -- then writing and
         // reopening slot by slot would try to open a port the other radio has
         // not released yet.
         CloseCATAndKeyerForThisRadio;
         end;
      logger.Info('[ApplyProfile] phase 1 -- both radios stopped: %d ms',
                  [GetTickCount - tStart]);
      tPhase := GetTickCount;

      // Once, across both slots -- the enable flag is one flag for the program.
      ApplyKeyersForProfile(aKeyers, aProfile);

      for slot := 1 to 2 do
         begin
         radioDef := aStore.FindRadioById(aProfile.RadioIdForSlot(slot));
         // radioDef is nil for an empty slot, and the renderer treats that as
         // "clear it" -- necessary, or the slot keeps whatever the previously
         // active profile left there.
         ApplyRadioToSlot(radioDef, slot, aProfile,
                          KeyerDeviceForSlot(aKeyers, aProfile, slot) <> nil);
         end;

      // The ini keys are correct but possibly scattered: WritePrivateProfileString
      // appends a newly-created key at the END of the section, so keys added to
      // TR4W after the operator's ini was first written land away from their
      // radio's block.  This puts them back.
      GroupRadioIniKeys;

      for slot := 1 to 2 do
         begin
         if slot = 1 then
            begin
            slotRadio := @Radio1;
            end
         else
            begin
            slotRadio := @Radio2;
            end;

         CATWTR := slotRadio;
         // A radio that fails to connect is NOT an apply failure: the port may
         // be busy, the rig may be off.  That is reported the same way it is
         // for any other connection attempt, and the profile is still active.
         logger.Info('[ApplyProfile] phase 2 -- keys written for both slots: %d ms',
                     [GetTickCount - tPhase]);
         tPhase := GetTickCount;
         slotRadio^.CheckAndInitializePorts_ForThisRadio;
         logger.Info('[ApplyProfile] phase 3 -- radio %d port opened: %d ms',
                     [slot, GetTickCount - tPhase]);
         tPhase := GetTickCount;
         end;
   finally
      CATWTR := previousCATWTR;
   end;

   // Once, at the end: the keyer serves both radios, so re-initialising it per
   // slot would tear down the one just built.
   InitializeKeyer;
   DisplayRadio(ActiveRadio);

   aStore.ActiveProfileName := aProfile.Name;
    logger.Info('[ApplyProfile] profile "%s" active after %d ms total',
                [aProfile.Name, GetTickCount - tStart]);
   Result := True;
end;

{ ------------------------------------------------------- the store on disk - }

function SettingsDirectory: string;
begin
   Result := ExtractFilePath(string(AnsiString(PAnsiChar(@TR4W_INI_FILENAME[0]))));
end;

function RadioStoreFileName: string;
begin
   // Delegated: uTR4WConfigFile owns the file, so it owns where the file is.
   Result := TR4WConfigFileName;
end;

function LegacyRadioStoreFileName: string;
begin
   Result := SettingsDirectory + 'tr4wradios.ini';
end;

// The value the library WOULD render for one key -- read-only.  '' when the
// slot is empty or the key is not in the rendered set.
function RenderedValueFor(const aStore: TRadioConfigStore;
                          const aProfile: TStationProfile;
                          const aSlot: integer;
                          const aKey: string): string;
var
   radioDef: TRadioDefinition;
   rendered: TConfigKeyValues;
   i: integer;
begin
   Result := '';
   radioDef := aStore.FindRadioById(aProfile.RadioIdForSlot(aSlot));
   if radioDef = nil then
      begin
      Exit;
      end;
   rendered := RenderRadioKeys(aSlot, radioDef,
                               ResolveTypeRendering(radioDef.RegistryId), aProfile);
   for i := 0 to High(rendered) do
      begin
      if SameText(rendered[i].Key, aKey) then
         begin
         Result := rendered[i].Value;
         Exit;
         end;
      end;
end;

function ApplyActiveProfileToConfigAtStartup(out aError: string): boolean;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   profile: TStationProfile;
   slot: integer;
   radioDef: TRadioDefinition;
   previousCATWTR: RadioPtr;
   loadErr: string;
   before, after: string;
begin
   aError := '';
   Result := True;

   if not FileExists(RadioStoreFileName) then
      begin
      // NO RADIO LIBRARY YET -- this station has never opened Preferences.
      //
      // The RADIO side must boot exactly as it always did, and below this it
      // does.  The MIGRATED COMMANDS must not, and that distinction is the
      // defect this guard used to have (found and fixed 2026-08-16).
      //
      // "Boots exactly as it always did" stopped being achievable for a csJSON
      // row the moment rows started moving: the ini loader treats csJSON as
      // accepted-and-INERT (uCFG.pas:1482), so the value in tr4w.ini is never
      // applied. With this guard also skipping SeedMigratedCommandsFromIni,
      // such a station got the COMPILED DEFAULT for every migrated setting --
      // all 161 csJSON rows -- with no error, no log line, and nothing to
      // notice until mid-contest. Exactly the silent loss the seed list exists
      // to prevent, defeated by a guard added for an unrelated reason.
      //
      // Measured, not reasoned: same tr4w.ini with HF BAND ENABLE=FALSE, same
      // binary. Without settings\tr4w.json, no seeding ran and the value was
      // lost. With a tr4w.json containing nothing but `{}`, seeding carried it
      // across correctly. An empty object was the whole difference.
      //
      // So seed and apply against an EMPTY store, which is a no-op for a
      // station that genuinely has nothing: the seeding reads tr4w.ini, and
      // ApplyStoredCommands puts whatever it found into force on this run.
      // Everything else here is radio-library work and stays behind the guard.
      store := TRadioConfigStore.Create;
      try
         SeedMigratedCommandsFromIni(store);
         ApplyStoredCommands(store);
         ApplyBandPlan(store);
         ApplyElementColors(store);
      finally
         store.Free;
      end;
      Exit;
      end;

   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      // BOTH libraries, from the one file.  LoadConfig rather than the radio
      // store's own loader: a profile's CW output may name a keyer DEVICE, and
      // without the keyer library that name resolves to nothing -- the slot
      // would render no keyer port and the device would never be configured.
      // A file with no keyers section is not an error; the store stays empty.
      if not LoadConfig(RadioStoreFileName, store, keyers, loadErr) then
         begin
         // Readable-but-broken is worth saying out loud, because the legacy
         // keys are about to be used instead and the operator's library is
         // effectively ignored for this run.
         aError := loadErr;
         Result := False;
         Exit;
         end;

      // Published BEFORE the profile check: whether TR4W offers a TCI server
      // is a station-wide decision and does not depend on a profile
      // resolving, which is a separate failure with its own message.
      RadioLibraryTCIServerEnabled := store.TCIServerEnabled;

      // The other TCI settings, which the server reads from globals at the
      // point of use.  These used to arrive through CFGCA from tr4w.ini; the
      // rows are csJSON now, which makes CheckCommand inert for them, so THIS
      // is the only thing that sets them at startup.  Same shape as the
      // csJSON radio rows: retiring the ini row and writing the applier are
      // one change, because a retired row with no applier is silent.
      TR4W_TCI_DEBUG          := store.TCIDebug;
      TR4W_TCI_MAX_TX_SECONDS := store.TCIMaxTxSeconds;

      RadioLibraryTCIPort    := store.TCIPort;
      RadioLibraryTCIBindAll := store.TCIBindAll;

      // APPLIED AT STARTUP, and all three of these were missing -- the store
      // held the values, Preferences displayed them, and the program never
      // received them until the operator opened Preferences and saved.  Which
      // is the exact silent failure csJSON is documented to cause without an
      // applier; I wrote the appliers and then did not call them.
      ApplyLoggingSettings(store);
      // BEFORE ApplyStoredCommands, not after: it carries a migrated command's
      // value out of tr4w.ini and into the store, and the apply below is what
      // then puts it into force on this very run.
      SeedMigratedCommandsFromIni(store);
      ApplyStoredCommands(store);
      ApplyBandPlan(store);
      ApplyElementColors(store);
      ApplyActiveCluster(store);

      // The rotator library.  ConfigureRotators seeds one rotator from the
      // legacy ROTATOR TYPE / ROTATOR PORT when the library is empty, so a
      // station that has never opened the Rotators page keeps working -- and
      // there is still only ONE code path, which is what made the old
      // `case ActiveRotatorType of` safe to delete outright rather than keep
      // as a fallback.
      uRotatorControl.ConfigureRotators(store);

      // The keyer library, for the same reason and at the same point.  Written
      // back immediately: the seed is only useful if Preferences can see it,
      // and Preferences loads the file rather than sharing this store.
      if SeedKeyerLibraryFromLegacy(keyers) then
         begin
         logger.Info('[Keyers] seeded "%s" from the legacy WinKeyer settings',
                     [keyers.Keyer(0).Name]);
         SaveConfig(RadioStoreFileName, store, keyers, nil);
         end;

      profile := store.ActiveProfile;
      if profile = nil then
         begin
         logger.Debug('[Startup] radio library has no active profile -- leaving the [Radio] keys alone');
         Exit;
         end;

      // Both slots must resolve before anything is written.  A half-applied
      // profile at startup would leave the station matching neither the library
      // nor the ini, which is the exact confusion this whole change is about.
      for slot := 1 to 2 do
         begin
         if Trim(profile.RadioNameForSlot(slot)) = '' then
            begin
            Continue;
            end;
         if store.FindRadio(profile.RadioNameForSlot(slot)) = nil then
            begin
            aError := Format('Profile "%s" refers to radio "%s", which does not exist',
                             [profile.Name, profile.RadioNameForSlot(slot)]);
            logger.Warn('[Startup] %s -- leaving the [Radio] keys alone', [aError]);
            Result := False;
            Exit;
            end;
         end;

      // Once, across both slots -- see ApplyKeyersForProfile.  This is the path
      // that matters: the WK command rows are csJSON and inert, so a normal
      // start configures the WinKeyer here or not at all.
      ApplyKeyersForProfile(keyers, profile);

      previousCATWTR := CATWTR;
      try
         for slot := 1 to 2 do
            begin
            if slot = 1 then
               begin
               CATWTR := @Radio1;
               end
            else
               begin
               CATWTR := @Radio2;
               end;

            radioDef := store.FindRadio(profile.RadioNameForSlot(slot));
            // nil for an empty slot, which the renderer treats as "clear it" --
            // necessary, or the slot keeps whatever was last in the ini.
            //
            // aPersist=False: CONFIGURE, do not persist.  The library is
            // already the record, so writing a copy of it into tr4w.ini on
            // every start would be writing to disk purely to set globals --
            // and it would fail silently on a read-only program directory.
            // It also means a start CANNOT damage the operator's ini.
            ApplyRadioToSlot(radioDef, slot, profile,
                             KeyerDeviceForSlot(keyers, profile, slot) <> nil);
            end;

         // No GroupRadioIniKeys: nothing was written to group.
      finally
         CATWTR := previousCATWTR;
      end;

      // NOTHING COMPARES AGAINST THE INI ANY MORE.  This used to read
      // RADIO ONE CONTROL PORT back and warn when it disagreed with the
      // library, which made sense while the [Radio] keys were still being
      // written.  Nothing has written them since 2026-08-21, so a
      // difference now means only that the operator has an old file, and
      // saying so on every start is noise rather than information.
      logger.Info('[Startup] radio profile "%s" applied from the library',
                  [profile.Name]);
   finally
      keyers.Free;
      store.Free;
   end;
end;

{ --------------------------------------------------------- port conflicts - }

// A serial port value that actually names a port.  '' and 'NONE' do not, and
// treating them as ports would report a conflict on every station that leaves
// a keyer line unset -- the false positive that trains people to ignore the
// warning.
function IsRealPort(const aPort: string): boolean;
begin
   Result := (Trim(aPort) <> '') and (not SameText(Trim(aPort), PORT_NONE));
end;

function DescribePortConflicts(const aStore: TRadioConfigStore;
                               const aProfile: TStationProfile): string;
var
   radio1, radio2: TRadioDefinition;

   procedure Note(const aText: string);
   begin
      if Result <> '' then
         begin
         Result := Result + sLineBreak;
         end;
      Result := Result + aText;
   end;

   // CAT and keyer on the SAME port within one radio is not a conflict -- that
   // is CW by CAT, or a keyer sharing the CAT cable's control lines, and both
   // are normal.  Between two different radios it is.
   procedure CheckAcross(const aLabel1, aPort1, aLabel2, aPort2: string);
   begin
      if IsRealPort(aPort1) and SameText(Trim(aPort1), Trim(aPort2)) then
         begin
         Note(Format('%s and %s both use %s', [aLabel1, aLabel2, Trim(aPort1)]));
         end;
   end;

begin
   Result := '';
   if (aStore = nil) or (aProfile = nil) then
      begin
      Exit;
      end;

   radio1 := aStore.FindRadioById(aProfile.Radio1Id);
   radio2 := aStore.FindRadioById(aProfile.Radio2Id);

   if (radio1 = nil) or (radio2 = nil) then
      begin
      // One radio cannot collide with itself, and a dangling reference is
      // Validate's business, not this function's.
      Exit;
      end;

   if radio1.Transport = rtSerial then
      begin
      if radio2.Transport = rtSerial then
         begin
         CheckAcross(radio1.Name + ' CAT', radio1.ControlPort,
                     radio2.Name + ' CAT', radio2.ControlPort);
         end;
      CheckAcross(radio1.Name + ' CAT', radio1.ControlPort,
                  radio2.Name + ' keyer', radio2.KeyerOutputPort);
      end;

   if radio2.Transport = rtSerial then
      begin
      CheckAcross(radio2.Name + ' CAT', radio2.ControlPort,
                  radio1.Name + ' keyer', radio1.KeyerOutputPort);
      end;

   CheckAcross(radio1.Name + ' keyer', radio1.KeyerOutputPort,
               radio2.Name + ' keyer', radio2.KeyerOutputPort);
end;

end.

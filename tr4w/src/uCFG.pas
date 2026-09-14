{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uCFG;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}

interface

uses
  uRadioRegistry,  // RadioTypeTokensA + RegisteredCIVAddress. In the INTERFACE
                   // uses because ListParamArray below takes its address.
  uConfigValues,   // Config -- the live values migrated rows write into
  uAnsiStr,
    uCTYDAT,
   uWinKey,
   uYCCCSO2R,
   uGetScores,
   uHamScore,         // Issue #783 -- HAMSCORE config statements
   uStations,
   uRemMults,
   PostUnit,
   LogEdit,
   LogGrid,
   LogSCP,
   TF,
   FCONTEST,
   ZoneCont,
   utils_text,
   //Country9,
   CfgCmd,
   LCLType,   // MAXWORD, in the crMax column of the command table
   LogStuff,
   LogK1EA,
   LOGWAE,
   LogDom,
   LOGDVP,
   LogRadio,
   LogDupe,
   LogPack,
   LogCW,
   uNet,
   LogWind,
   uBandmap,
   uTelnet,
   uFunctionKeys,
   Tree,
   VC,
   IdUDPClient,
   IdGlobal,
   Log4D,
   uExternalLoggerBase
   ,
  uTR4WStrings;

(* THE THREE RECORDS THAT DESCRIBED A ROW ARE GONE -- 2026-09-14.

  CFGRecord was twenty fields, and the migration found a destination for every
  one: crCommand is the property path, crAddress and crType are the property,
  crMin/crMax are a subrange type, crP and crA are the setter and
  uSettingsEffects, crJ is a parameter on RegisterModelSetting, and crS was a
  migratory status with no meaning left.

  ArrayRecord and ListParamRecord were the two POSITIONAL side tables a row
  reached by index -- an allow-list of integers, and a list of spellings. A
  bounded setting states its bounds in its type and a token setting registers
  its own vocabulary, so neither has anything left to hold. *)

   //procedure F_MY_GRID;
// Is this command's system of record settings\tr4w.json rather than the ini?
//
// csJSON means the row is INERT: recognised so an old config does not error,
// but not applied and hidden from Ctrl-J.  A writer that still emitted such a
// key would put a value into a file nothing reads, which then looks
// authoritative to the next person who opens it.
//
// Exposed so the RADIO LIBRARY's writer can ask.  That makes csJSON the one
// switch for a migration: add the direct applier, flip the row, and the ini
// writer stops on its own -- rather than a hand-removed Emit that can drift
// out of step with the row it is meant to match (NY4I).
function CommandIsJSONOwned(const aCommand: string): boolean;

{ AN EXPLICIT CONTEST .cfg LINE BEATS THE STORED VALUE, while that contest is
  loaded.

  Startup applies, in order: compiled defaults, tr4w.ini, the contest .cfg,
  common messages, and finally the JSON store. The store therefore wins BY BEING
  LAST -- right for a station setting, wrong for one a contest deliberately sets.
  LEADING ZEROS is the live example: six real contest configs set it, both
  CQ-WPX files among them, and a serial-number contest asking for leading zeros
  must not be overruled by a station preference.

  This is the station-defaults <- contest-overrides model in its minimal form:
  the .cfg needs no storage of its own, it only needs to be SEEN. A command
  recorded here is skipped by ApplyStoredCommands for this run.

  Reset at the start of each contest .cfg load, so switching contests re-decides
  rather than accumulating. }
procedure NoteCommandFromContestCFG(const aCommand: string);
procedure ClearContestCFGCommands;
function CommandCameFromContestCFG(const aCommand: string): boolean;

(* FindCFGCommand IS GONE with the array it indexed. A command is a NAME
  now, and every question that used to be asked of its row -- what type is
  it, is it read-only, what may it hold -- is asked of the settings object
  instead. *)

// A command's current value as text// A command's current value as text, rendered per its crType/crKind.
function CFGCommandValueAsString(const aCommand: string): string; overload;

(* THE SAME THING, AND WHETHER IT WORKED.

  NOT EVERY COMMAND HAS A VALUE THAT CAN BE WRITTEN DOWN. Some are ACTIONS
  (REMINDER prompts the operator for a time), some are MULTI-VALUED (the
  ctFreqList pair appear once per band-plan entry). The renderer's else arm
  already warns about those and returns '' -- but '' is also a perfectly good
  value for a string setting, so a caller cannot tell the two apart.

  ONE CASE STATEMENT, TWO ENTRY POINTS: the plain function delegates here and
  discards the flag, so the list of renderable types stays in one place. A
  caller that must not store an unrenderable command asks this one. *)
function CFGCommandValueAsString(const aCommand: string;
                                 out aRenderable: boolean): string; overload;

(* THE VALUES A BOUNDED SETTING WILL ACCEPT, as text, in the model's order --
  empty for one that is not bounded, which a UI reads as "use a text box".
  Delegates to the settings object; it is still exported from here because
  Preferences asks by COMMAND NAME. *)
function CFGCommandAllowedValues(const aCommand: string): TArray<string>;

(* WHAT KIND OF CONTROL DOES THIS SETTING WANT? A check box for a boolean, a
  numbers-only box for an integer. Both were the row's crType and are the
  property's TYPE now.

  THE OTHER THREE PREDICATES WENT WITH THE ARRAY, and each for its own reason
  rather than by a sweep:

    CFGCommandIsReadOnly -- crJ 2/3. TSettingBase.ReadOnly says it, set at
      registration, so Preferences reads the flag it already holds.
    CFGCommandIsList     -- a ckList row could not be put in a drop-down
      because its spellings lived in a second positional array. A token
      setting registers its own vocabulary, so those rows are ordinary
      drop-downs and there is nothing left to exclude.
    CFGCommandIsFreqList -- the two accumulating band-plan commands. They are
      not settings at all any more (TryApplyCommandAction), so no generated
      row can name them; the way into the band-plan editor is an explicit
      button on the Band Map page instead of one synthesised from a row. *)
function CFGCommandIsBoolean(const aCommand: string): boolean;
function CFGCommandIsInteger(const aCommand: string): boolean;

// Apply a value to a command and persist it.  Returns False when the value is
// REFUSED, in which case nothing is written -- see the implementation.
(* HOW A [COMMANDS] VALUE IS MADE PERMANENT.

  A HOOK RATHER THAN A CALL, because the direction of the units forbids the
  call: the store lives in uRadioConfigApply, which uses uCFG.

  ASSIGNED AT STARTUP by uRadioConfigApply. Unassigned means "no store", and
  SetCFGCommandValue then applies the value and says out loud that it will not
  survive. *)
type
   TPersistCommandValue = function(const aCommand, aValue: string): boolean;

var
   PersistCommandValue: TPersistCommandValue = nil;

(* DOES THIS SETTING HAVE TO MATCH AT THE OTHER POSITIONS?

  Was the row's crNetwork byte, and it is a list of names here -- the question
  belongs to the MULTI-OP PROTOCOL ("do the desks have to agree about this")
  rather than to the setting. SetCFGCommandValue announces a change to peers
  when the answer is yes; Preferences reads it as TSettingBase.Broadcast. *)
function CommandIsSharedWithPeers(const aCommand: string): boolean;

function SetCFGCommandValue(const aCommand, aValue: string): boolean;

(* RunCommandRedrawProc IS GONE, and so is the hazard it embodied.

  It ran CommandsProcArray[crP] -- a hand-typed index into a positional array
  of untyped Pointers, so a wrong number compiled and called the wrong
  handler. That happened here: EXTERNAL LOGGER ENABLED carried crA: 23, the
  WSJT-X hook.

  A PROPERTY SETTER CANNOT POINT AT THE WRONG HANDLER, and it runs however
  the value was set rather than only when CheckCommand applied a row -- which
  is why a config file used to repaint the band map and a menu toggle did
  not. See uSettingsEffects. *)

//function F_ICOM_RESPONSE_TIMEOUT: boolean;
procedure UpdateDebugLogLevel;
//function F_SETPARALLELPORT: boolean;

const
   ICOM_FILTER_WIDTH: array[0..03] of integer = (0, 1, 2, 3);
   SCP_MINIMUM_LETTERS_ARRAY: array[0..03] of integer = (0, 3, 4, 5);
   AUTO_SEND_CHARACTER_COUNT_ARRAY: array[0..06] of integer = (0, 1, 2, 3, 4, 5,
      6);
   AUTO_QSL_INTERVAL: array[0..06] of integer = (0, 1, 2, 3, 4, 5, 6);
   ROW_COUNT_ARRAY: array[0..10] of integer = (5, 6, 7, 8, 9, 10, 11, 12, 13,
      14, 15);
   WINDOW_SIZE_ARRAY: array[0..14] of integer = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
      11, 12, 13, 14, 15);
   CW_SPEED_INCREMENT: array[1..10] of integer = (1, 2, 3, 4, 5, 6, 7, 8, 9,
      10);
   MULT_REPORT_MINIMUM_BANDS_ARRAY: array[0..02] of integer = (2, 3, 4);
   //FilterBandMap                         : array[0..02] of pchar = ('OFF','CW','Digital');
   RECORDER_BITRATE_ARRAY: array[0..07] of integer = (8, 16, 24, 32, 40, 48, 56,
      64 {, 80, 96, 112, 128});
   RECORDER_SAMPLERATE_ARRAY: array[0..05] of integer = (08000, 11025, 12000,
      16000, 22050, 44100);

   CAT_BAUDRATE_ARRAY: array[0..07] of integer = (1200, 2400, 4800, 9600, 19200,
      38400, 57600, 115200); // [AGENT] Add 230400, 460800, and 921600 when working here.
   DITDAHRATIO_ARRAY: array[0..03] of integer = (3, 4, 5, 6);
   LEADING_ZEROS_ARRAY: array[0..03] of integer = (0, 1, 2, 3);

(* THE FOUR POSITIONAL TABLES ARE GONE -- 2026-09-14.

  ArrayRecordArray (16 slots), ListParamArray (54), AdditionalProcsArray (25)
  and CommandsProcArray (13). Every one was reached by an INDEX WRITTEN BY
  HAND into a row's crAddress, crA or crP, which is why a freed slot had to be
  nil'd rather than removed: deleting an entry shifted every index above it
  and silently repointed other settings at the wrong variable, the wrong
  allow-list or the wrong handler. That is not a hypothetical -- EXTERNAL
  LOGGER ENABLED carried crA: 23, the WSJT-X hook, and CATEGORY-OVERLAY
  carried the transmitter slot's index, so every overlay line was refused.

  WHAT REPLACED EACH: an allow-list is a subrange type or a registered
  vocabulary; a spelling list belongs to the subsystem that owns the enum; a
  redraw hook is the property's setter; an "additional proc" is an effect in
  uSettingsEffects, which runs however the value was set.

  THE MP3 RECORDER'S LAST TWO DECLARATIONS WENT WITH THEM. They existed only
  to keep two withdrawn rows VALID, because ListParamArray's lpVar was
  dereferenced with no nil check. Nothing read them; the recorder itself went
  on 2026-09-07 and recording is QSOCapture's job. *)

   //  CFGKindStringArray                    : array[CFGKind] of PChar = ('Supported', 'Supported', 'Supported', 'Supported', 'Supported', 'Added', 'Removed', 'Not supported');

   // Indexed by CFGStatus -- adding a status without adding a name here is a
   // compile error, which is how csOwned's missing entry was caught.
   CFGStatusArray: array[CFGStatus] of PAnsiChar = ('New', 'Old', 'Removed', 'Preferences', 'JSON');

   CFGTypeStringArray: array[CFGType] of PAnsiChar = (nil, 'Directory', 'FileName',
      'String', 'Multiplier', 'Boolean', 'Real', 'Byte', 'Integer', 'Integer',
      { 'Integer', } 'String', 'URL', 'CaseSensitive', 'Password', 'Operation', 'Other', 'Char', 'Char',
      {'Port',} 'Port', 'Band');

var
   CMD: ShortString;
   (* THE THREE WSJT-X BOOLEANS ARE GONE (2026-09-12) -- Settings.Wsjtx in
     uSettingsModel, with the two in logstuff.pas that went with them. *)
   (* SpotCollectorEnabled MOVED, 2026-09-10 -- Settings.SpotCollector.Enabled
     in uSettingsModel.  Its default moved into that class's constructor. *)
   (* CTYUpdateCheckOnStartup MOVED, 2026-09-12 --
     Settings.Country.UpdateCheckOnStartup. *)

(* CommandsArraySize IS GONE, and it is the most eloquent thing in the file's
  history: a constant that counted the rows by ADDING UP EVERY FEATURE EVER
  ADDED, then subtracting every group that left. It started at 415 and the
  subtractions -- each one a group of settings arriving in uSettingsModel --
  took it to zero on 2026-09-14. An array of size zero is illegal, which is
  how the compiler said the migration was finished. *)


   (* CFGCA IS GONE -- 2026-09-14, and this is what the whole migration was for.

     It was a table of up to 415 rows: a command name, a bare pointer to a
     global, a type byte, two hook indices and a status. Every one of those
     fields restated something the compiler already knew, and a wrong index
     compiled silently -- EXTERNAL LOGGER ENABLED once carried crA: 23, which
     is the WSJT-X hook.

     WHERE EVERYTHING WENT:

       a SETTING          a published property on Settings, its bounds a
                          subrange type and its side effect in the setter
       a SUBSYSTEM'S      a token on the setting plus the subsystem's own
       vocabulary         table -- radios, keyers, rotators, multipliers
       a COMMAND          TryApplyCommandAction: the three that accumulate,
                          and the one that is a bare instruction
       LIVE STATE         a setting for what was configured and a global for
                          what the session is doing, mirrored per config read
       a WITHDRAWN name   RETIRED_COMMANDS -- accepted, logged once, ignored
       a STORE'S value    OWNED_BY_A_STORE -- accepted here, applied there

     CheckCommand still exists and still means the same thing to a config
     file. What it no longer has is a table to scan. *)
function CheckCommand(Command: PAnsiChar; CustomCMD: ShortString;
                      const aApplyJSONOwned: boolean = False): boolean;
// True when Command names a single-valued (overwrite) config command, i.e. one
// for which a duplicate line is a misconfiguration.  Accumulating commands
// (frequency lists, band lists, ADD DOMESTIC COUNTRY, indexed arrays) legitimately
// repeat and return False, as do pattern-matched commands (COLUMN WIDTH,
// "* WINDOW *", messages) and unknown commands.  Used by the config loader to
// flag hand-edited duplicate keys.  See the implementation for the list.
function CommandIsSingleValued(Command: PAnsiChar): boolean;

(* True when aCommand names a feature TR4W has withdrawn.  Such a command is
  ACCEPTED and does nothing, so an old tr4w.ini or contest .cfg that still
  names it loads without telling the operator their configuration is invalid.

  EXPORTED SO IT CAN BE TESTED.  The list replaced 91 csRem rows, and those
  rows were the only record that these names were ever TR4W commands -- so the
  test that they still resolve is now the only thing standing behind them. *)
function CommandIsRetired(const aCommand: string): boolean;

(* How many withdrawn names are on that list.  For the test's ratchet; there
  is no other reason to ask. *)
function RetiredCommandCount: integer;

(* IS THIS A COMMAND A STORE OWNS -- accepted here, applied by whatever
  reads that store.  NOT the same question as CommandIsRetired: these
  settings still work.  See OWNED_BY_A_STORE. *)
function CommandIsOwnedByAStore(const aCommand: string): boolean;

(* How many such names there are.  For the test's ratchet. *)
function StoreOwnedCommandCount: integer;

function ProcessMessage(ID, CMD: ShortString): boolean;
procedure InitializeStrings;

(* `Changed` WENT WITH THE ARRAY. It was one boolean per row and nothing ever
  indexed it -- checked before deleting: zero references in the tree. *)

implementation
uses MainUnit, SysUtils,   // Issue #997 -- SysUtils for Format/StrPCopy (asm-to-Pascal conversion)
     uSettingsModel,       // Settings -- the commands that have left this array
     uStateBridge;         // RefreshWSJTXIndicator -- the box tracks WSJT-X ENABLED

var
   { Commands the CURRENT contest .cfg set explicitly. Single digits in every
     real config measured, so a linear scan is the right shape -- a dictionary
     here would be more code than the problem. }
   gContestCFGCommands: array of string;

procedure ClearContestCFGCommands;
begin
   SetLength(gContestCFGCommands, 0);
end;

procedure NoteCommandFromContestCFG(const aCommand: string);
var
   i: integer;
   name: string;
begin
   name := UpperCase(Trim(aCommand));
   if name = '' then
      begin
      Exit;
      end;

   for i := 0 to High(gContestCFGCommands) do
      begin
      if gContestCFGCommands[i] = name then
         begin
         Exit;
         end;
      end;

   SetLength(gContestCFGCommands, Length(gContestCFGCommands) + 1);
   gContestCFGCommands[High(gContestCFGCommands)] := name;
end;

function CommandCameFromContestCFG(const aCommand: string): boolean;
var
   i: integer;
   name: string;
begin
   Result := False;
   name := UpperCase(Trim(aCommand));
   for i := 0 to High(gContestCFGCommands) do
      begin
      if gContestCFGCommands[i] = name then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function CommandIsRadioLibraryKey(const aCommand: string): boolean; forward;

function CommandIsJSONOwned(const aCommand: string): boolean;
var
   i: integer;
begin
   (* A SETTING THAT HAS LEFT THE ARRAY IS STILL JSON-OWNED, and saying so is
     what keeps the contest-overrides-station model working for it.

     LogCfg asks this question to decide whether a contest .cfg line may be
     applied -- it calls CheckCommand with aApplyJSONOwned = True only when
     the answer is yes (LogCfg.pas:1250). Scanning CFGCA alone answers FALSE
     for a migrated setting, because its row is gone, so a contest .cfg
     setting BAND MAP MULTS ONLY would be accepted and silently ignored.

     That is the half of this pair that is easy to miss: the guard added in
     CheckCommand stops the INI overriding the store, and this stops that
     guard from also muting the CONTEST FILE, which is the one source that is
     supposed to win while its contest is loaded. *)
   if Settings.OwnsCommand(aCommand) then
      begin
      Result := True;
      Exit;
      end;

   (* AND A STORE'S NAMES COUNT TOO. THIS WAS A REGRESSION, 2026-09-14, and
     it broke EVERY RADIO.

     What stood here after the array was deleted was `Result := False`, on
     the reasoning that "a name the settings model does not own is not a
     setting". That is wrong in exactly one direction, and it is the
     direction that matters: the settings model is not the only owner. The
     RADIO, KEYER and CLUSTER LIBRARIES own names too, and their values live
     in settings/tr4w.json just as much as a published property's do.

     WHAT IT COST. uRadioConfigApply.ApplyRadioToSlot dispatches on this
     question -- True means "call the direct applier", False means "push it
     through CheckCommand". With the answer False for RADIO ONE PORT and its
     twenty-six siblings, every key fell through to CheckCommand, whose rows
     had just been deleted, so every one was refused:

         [ApplyRadioToSlot] CFGCA did not accept "POLL RADIO TWO" = "FALSE"
         [Radio 1 config] radio=NONE (no RADIO n TYPE and no RADIO n FACTORY
                          ID configured)  connection=COM0 0 baud 8N2

     A fully configured IC-7100 on COM18 came up as NO RADIO AT ALL. NY4I
     found it on the bench; nothing in the build, the lints, the unit tests
     or the corpus can see it, because none of them configures a radio.

     THE THREE OWNERS, and the question is the same for all three: is this
     command's system of record settings/tr4w.json rather than this file? *)
   Result := CommandIsOwnedByAStore(aCommand)
             or CommandIsRadioLibraryKey(aCommand);
end;

function CFGCommandValueAsString(const aCommand: string): string;
var
   renderable: boolean;
begin
   Result := CFGCommandValueAsString(aCommand, renderable);
end;

function CFGCommandValueAsString(const aCommand: string;
                                 out aRenderable: boolean): string;
begin
   (* A CONFIG VALUE AS TEXT, AND THE SETTINGS OBJECT IS THE ONLY SOURCE.

     The header that stood here described reading the value out of a ROW --
     "crAddress is a bare pointer and crType is what makes it an integer, a
     ShortString or an index into a list", plus a note about a ShortString's
     length byte and a pointer to uOption's fuller copy for Ctrl-J. Every
     clause of that is now false: there is no row, no crAddress, and no
     Ctrl-J. Three local variables went with it (idx, listIdx, p) -- dead the
     moment the body did.

     WHAT IS LEFT IS THE CONTRACT, which has not changed: TryGetByCommand
     renders from RTTI, and aRenderable is False for a property kind it does
     not handle. That distinction is the valuable part -- '' is a legitimate
     value for a string setting, so a caller cannot tell "empty" from
     "cannot be written down" without it, and a setting that reads blank is
     set to blank by the next OK. *)
   aRenderable := True;
   Result := '';

   (* A SETTING THAT HAS LEFT CFGCA -- THE READ HALF.
     -------------------------------------------------------------------
     CheckCommand already resolves these names for WRITING.  Without the
     same arm here the two halves disagree, and the way they disagree is
     the worst possible: a Preferences panel READS blank or False, the
     operator presses OK, and the write path faithfully stores what the
     control was showing.  A setting the operator never touched is turned
     off by opening the page it lives on.

     THAT IS NOT HYPOTHETICAL -- it is what this build did.  Seven
     hand-wired controls in uPrefsForm read through here by name
     (EXTERNAL LOGGER ADDRESS / ENABLED / PORT, MMTTY ENGINE, RADIO TCP
     SERVER PORT, SPOT COLLECTOR ENABLED, YCCC SO2R ENABLE) and every one
     of them had moved to uSettingsModel.  Found by NY4I asking whether
     the deleted rows were still referenced anywhere; the deletion did not
     cause it -- the rows had been stubs with crAddress: nil since
     2026-09-10 -- but it is the same defect either way.

     THE RULE, RESTATED: a migrated name and an unmigrated one are
     disjoint sets, and EVERY path that resolves a command name has to
     know about both.  There are two: this one reads, CheckCommand
     writes. *)
   if Settings.OwnsCommand(aCommand) then
      begin
      aRenderable := Settings.TryGetByCommand(aCommand, Result);
      Exit;
      end;

   (* AND NOTHING ELSE ANSWERS. Every branch that stood below this read a
     row: a ckList index into ListParamArray, a ckArray index into
     ArrayRecordArray, and a crType case dereferencing crAddress as a
     ShortString, an integer or a double.

     THE WHOLE OF IT IS THE PROPERTY'S TYPE NOW, and TryGetByCommand renders
     from RTTI -- which is why aRenderable can still be False: a property
     kind the renderer does not handle reports it rather than returning a
     plausible empty string. That distinction was the expensive one. A
     setting that reads blank is set to blank by the next OK. *)
   aRenderable := False;
end;


function CFGCommandIsBoolean(const aCommand: string): boolean;
begin
   (* Asked by the generated settings panel to choose a CHECK BOX rather than
     a text box. AllowedValues cannot answer it -- a boolean has no allow-list
     -- so without this a boolean renders as a field that accepts "maybe". *)
   Result := Settings.CommandIsBoolean(aCommand);
end;

function CFGCommandIsInteger(const aCommand: string): boolean;
begin
   (* So an integer row gets a NUMBERS-ONLY box. Without it the row is an
     ordinary TEdit that accepts anything: NY4I typed "ewed" into Auto-CQ
     Delay Time (2026-08-18) and the text went to the parser.

     THE '-' QUESTION MOVED WITH IT. The old form was safe because no row
     declared a negative crMin; a subrange type states its own lower bound,
     so a signed setting would be visible in the type rather than having to
     be remembered here. *)
   Result := Settings.CommandIsInteger(aCommand);
end;

function CFGCommandAllowedValues(const aCommand: string): TArray<string>;
begin
   (* ONE SOURCE. This used to enumerate a ckList's spellings out of
     ListParamArray or a ckArray's integers out of ArrayRecordArray, and fell
     back to the model for a migrated name. There is only the model now --
     a subrange's bounds, an enumeration's values, or a vocabulary the
     subsystem registered for a token. *)
   Result := Settings.AllowedValuesForCommand(aCommand);
end;


function SetCFGCommandValue(const aCommand, aValue: string): boolean;
var
   keyShort, valueShort: ShortString;
   idKey, cmdValue: AnsiString;
begin
   // VALIDATE FIRST, PERSIST SECOND -- the same order, and for the same reason,
   // as ApplyRadioToSlot: CheckCommand is what moves the value into the live
   // globals AND what runs the row's crA hook and bounds check; the ini write
   // is only what makes it survive a restart.  Writing first would put a value
   // CFGCA rejected into the operator's file, and the next start would stop on
   // it with "Invalid statement in config file".
   //
   (* MULTI-OP SYNC, AND THIS COMMENT WAS WRONG UNTIL 2026-09-10.

     It said "the send side reads crNetwork from the row".  THERE WAS NO SEND
     SIDE.  Nothing in this build filled a TParameterToNetwork or put one on
     the wire -- the record was declared and never used, and its message id
     was never even set.  Only the RECEIVE side survived the LCL conversion,
     so this program has been obeying its peers while telling them nothing.

     D7 sent it from JCTRL2.SendParameterToNetwork and from the Options
     dialog, both of which went with the Win32 windows that held them.  It is
     sent from here now -- a routine every settings screen already goes
     through, rather than from a window that may not be open. *)
   //
   // Fresh AnsiStrings per call, not a reused buffer: the ini write takes
   // @s[1] as a null-terminated PAnsiChar, so a shorter value written over a
   // longer one in the same ShortString leaves the previous tail behind.
   idKey    := AnsiString(aCommand);
   cmdValue := AnsiString(aValue);

   FillChar(keyShort, SizeOf(keyShort), 0);
   FillChar(valueShort, SizeOf(valueShort), 0);
   keyShort   := ShortString(idKey);
   valueShort := ShortString(cmdValue);

   // A csJSON ROW MUST NOT COME THROUGH HERE, and refusing is the only safe
   // answer.  CheckCommand returns TRUE for such a row WITHOUT APPLYING IT
   // (uCFG.pas:1591 -- accepted so an old config does not error, then Exit),
   // so the write below would fire on a value that never reached the global:
   // the setting would not take effect AND tr4w.ini would gain a key nothing
   // reads, which -- as the contract on CommandIsJSONOwned puts it -- 'looks
   // authoritative to the next person who opens it'.
   //
   // Nothing calls this with a csJSON command today (cross-checked across all
   // 230 registered settings, 2026-08-21, zero hits). This is here so that
   // when someone eventually does, it FAILS LOUDLY instead of half-working:
   // the fix is to register the setting with RegisterStoredSetting, which
   // writes the JSON store, rather than RegisterLegacySetting.
   (* csJSON ROWS ARE NO LONGER REFUSED HERE.

     This used to return False for them, because the only thing below was a
     write to tr4w.ini and a csJSON row does not read that file -- so applying
     and "saving" it was a lie. The route below is the JSON store now, which is
     exactly where a csJSON row belongs, so the refusal has nothing left to
     protect.

     It was not harmless while it stood: uAutoCQForm saves AUTO-CQ DELAY TIME
     through here and that row IS csJSON, so every save was refused and logged
     as an error. *)

   Result := CheckCommand(@keyShort, valueShort);
   if Result then
      begin
      (* PERSISTED THROUGH THE STORE, NOT INTO tr4w.ini.

        The ini write that stood here reached a file this program no longer
        reads: on a migrated station it is empty and read-only, so the value
        applied and was gone on restart -- silently, because
        WritePrivateProfileStringA reports failure through a BOOL nobody
        checked.

        Unassigned hook means there is genuinely nowhere to put it, and that is
        worth saying rather than pretending. *)
      if Assigned(PersistCommandValue) then
         begin
         if not PersistCommandValue(aCommand, aValue) then
            begin
            logger.Error('[SetCFGCommandValue] "%s" applied but NOT saved -- the ' +
                         'configuration store refused it.', [aCommand]);
            end;
         end
      else
         begin
         logger.Warn('[SetCFGCommandValue] "%s" applied but not saved: no ' +
                     'configuration store is available yet.', [aCommand]);
         end;

      (* AND TELL THE OTHER POSITIONS, if this setting is shared.

        AFTER the apply and the save, deliberately: a value that was refused,
        or that the store would not keep, must not be announced to a peer as
        though it had taken.  SendParameterToNetwork is a no-op when the link
        is down, which is every single-operator station. *)
      if CommandIsSharedWithPeers(aCommand) then
         begin
         SendParameterToNetwork(aCommand, aValue);
         end;
      end;

   { SAY WHAT CHANGED.  NY4I asked for this (bench queue): a configuration
     that behaves differently after a session gives no account of itself,
     and "which setting moved, and did it take" is the first question
     every support case asks.

     AT DEBUG, not INFO -- a Preferences page can write dozens of rows in
     one OK, and that volume belongs behind a level the operator turns on
     deliberately.

     THE REJECTION IS LOGGED TOO, and is the more valuable half: today a
     value CheckCommand refuses is simply discarded, so a setting the
     operator typed can vanish with nothing anywhere to say why. }
   if logger.IsDebugEnabled then
      begin
      if Result then
         begin
         logger.Debug('[Config] %s = %s (stored in tr4w.ini)', [aCommand, aValue]);
         end
      else
         begin
         logger.Debug('[Config] %s = %s REJECTED by CheckCommand -- not applied, not stored',
                      [aCommand, aValue]);
         end;
      end;
end;
var
   TempBand: BandType;
   TempMode: ModeType;
   TempFreq: integer;

   Result1: integer;

(* COMMANDS A CONFIG FILE MAY LEGITIMATELY NAME MORE THAN ONCE.

  "Single-valued" means the command overwrites a scalar target, so a second
  line for the same key is a misconfiguration -- the line-based loader applies
  every occurrence (last wins) while the profile API the old config dialog
  used reads the FIRST, so the two silently disagree and LogCfg reports the
  duplicate.

  THE OLD TEST WAS STRUCTURAL: ckNormal, not ctFreqList, crA = 0. Every
  accumulating command failed at least one of those. It is a NAME now, and a
  short list, because accumulating is a property of the four commands that do
  it rather than something the table happened to encode -- see
  TryApplyCommandAction, which is where all four went.

  Unknown names answer False, exactly as the row scan did: a pattern-matched
  command (COLUMN WIDTH <name>, <element> WINDOW COLOR) has no row and never
  did. *)
const
   ACCUMULATING_COMMANDS: array[0..3] of string = (
      'ADD DOMESTIC COUNTRY',
      'BAND MAP CUTOFF FREQUENCY',
      'CLEAR DUPE SHEET',
      'FREQUENCY MEMORY');

function CommandIsSingleValued(Command: PAnsiChar): boolean;
var
   name: string;
   i: integer;
begin
   Command[Ord(Command[0]) + 1] := #0;   // as CheckCommand does
   name := string(PShortString(Command)^);

   Result := Settings.OwnsCommand(name);
   if not Result then
      begin
      Exit;
      end;

   for i := Low(ACCUMULATING_COMMANDS) to High(ACCUMULATING_COMMANDS) do
      begin
      if SameText(ACCUMULATING_COMMANDS[i], name) then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

(* WHICH SETTINGS GO TO THE OTHER POSITIONS when one of them changes.

  Was the row's crNetwork byte. The list is the fifty names that carried
  crNetwork: 1, minus the ones whose feature has since been withdrawn -- a
  name nothing resolves never reaches SetCFGCommandValue, so a stale entry is
  inert rather than wrong, but there is no reason to carry one.

  WHY A LIST AND NOT A FLAG ON THE PROPERTY: the answer belongs to the
  MULTI-OP PROTOCOL, not to the setting -- it is "do the positions have to
  agree about this", which is a statement about a contest being logged at
  several desks. That question is being answered properly by the new
  multi-station work; until then this is the same answer the rows gave,
  written once where it can be read. *)
const
   SHARED_WITH_PEERS: array[0..44] of string = (
      'BACKUP LOG FILE NAME',
      'BAND',
      'CATEGORY-ASSISTED',
      'CATEGORY-BAND',
      'CATEGORY-MODE',
      'CATEGORY-OPERATOR',
      'CATEGORY-OVERLAY',
      'CATEGORY-POWER',
      'CATEGORY-TRANSMITTER',
      'CODE SPEED',
      'CONNECTION COMMAND',
      'CONTEST',
      'CONTEST NAME',
      'CONTEST TITLE',
      'COPY FILES',
      'CQ MENU',
      'CW TONE',
      'DISPLAY REFRESH',
      'DOMESTIC MULTIPLIER',
      'DVK PORT',
      'DX MULTIPLIER',
      'EXCHANGE RECEIVED',
      'FARNSWORTH ENABLE',
      'FARNSWORTH SPEED',
      'HOUR OFFSET',
      'ICOM COMMAND PAUSE',
      'INITIAL EXCHANGE',
      'INITIAL EXCHANGE CURSOR POS',
      'INITIAL EXCHANGE FILENAME',
      'INPUT CONFIG FILE',
      'MODE',
      'MULT REPORT MINIMUM BANDS',
      'MULTIPLIER ITEM WIDTH',
      'MY CONTINENT',
      'PADDLE PORT',
      'PREFIX MULTIPLIER',
      'QSL MODE',
      'QSO POINT METHOD',
      'SINGLE BAND SCORE',
      'TAIL END CW MESSAGE',
      'TAIL END KEY',
      'TAIL END MESSAGE',
      'TAIL END SSB MESSAGE',
      'WEIGHT',
      'ZONE MULTIPLIER');

function CommandIsSharedWithPeers(const aCommand: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(SHARED_WITH_PEERS) to High(SHARED_WITH_PEERS) do
      begin
      if SameText(SHARED_WITH_PEERS[i], aCommand) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(*
  COMMANDS TR4W ONCE HAD AND NO LONGER APPLIES.

  WHAT THIS REPLACES.  Each of these was a csRem row in CFGCA -- a full
  twenty-field CFGRecord carrying an address, a type, a kind, bounds and four
  hook indices, every one of them ignored, because CheckCommand exits on csRem
  before it reads any of them.  The row existed to answer exactly one
  question: was this once a TR4W command?  That question wants a name, not a
  record.

  WHY THE ANSWER CANNOT SIMPLY BE "NO".  LogCfg.pas:1262 shows a MODAL
  "invalid statement in config file" for a line CheckCommand refuses.  An
  operator whose tr4w.ini or contest .cfg still names a feature withdrawn two
  versions ago would be told their working configuration is invalid, once per
  stale line.  Accepting and ignoring is what csRem bought, and it is worth
  keeping; the twenty ignored fields are not.

  DISTINCT FROM A SETTING THAT MOVED.  EXTERNAL LOGGER PORT and MMTTY ENGINE
  were also csRem, and they are NOT here: the settings model owns those names
  and CheckCommand resolves them for real, applying the value.  These have no
  owner and no value to apply -- the feature is gone.

  ADDING TO THIS LIST IS THE LAST STEP OF REMOVING A FEATURE, not a way to
  silence a command that still does something.
*)
const
   RETIRED_COMMANDS: array[0..92] of string = (
      'AUTO ALT-D ENABLE',
      'BACKCOPY ENABLE',
      'BAND MAP ENABLE',
      'CALL WINDOW POSITION',
      'COLUMN DUPESHEET ENABLE',
      'CURTIS KEYER MODE',
      'CUSTOM CARET',
      'DUPE SHEET ENABLE',
      'EIGHT BIT PACKET PORT',
      'EX MENU',
      'EXCHANGE WINDOW S&P BACKGROUND',
      'FOOT SWITCH MODE',
      'FOOT SWITCH PORT',
      'FREQUENCY ADDER RADIO ONE',
      'FREQUENCY ADDER RADIO TWO',
      'FT1000MP CW REVERSE',
      'HAMLIB ASYNC ONLY',
      'HAMLIB DEBUG',
      'HAMLIB TRACE',
      'ICOM RESPONSE TIMEOUT',
      'LATEST CONFIG FILE',
      'LOG FILE NAME',
      'MODEM PORT',
      'MODEM PORT BAUD RATE',
      'MOUSE ENABLE',
      'MP3 RECORDER BITRATE',
      'MP3 RECORDER DURATION',
      'MP3 RECORDER SAMPLERATE',
      'MULTI INFO MESSAGE',
      'MULTI PORT',
      'MULTI PORT BAUD RATE',
      'MULTI RETRY TIME',
      'MULTI UPDATE MULT DISPLAY',
      'ORION PORT',
      'PACKET ADD LF',
      'PACKET AUTO CR',
      'PACKET BAND SPOTS',
      'PACKET BAUD RATE',
      'PACKET BEEP',
      'PACKET LOG FILENAME',
      'PACKET PORT',
      'PACKET PORT BAUD RATE',
      'PACKET RETURN PER MINUTE',
      'PACKET SPOT COMMENT',
      'PACKET SPOT DISABLE',
      'PACKET SPOT EDIT ENABLE',
      'PACKET SPOT KEY',
      'PACKET SPOT PREFIX ONLY',
      'PACKET SPOTS',
      'PADDLE BUG ENABLE',
      'PARTIAL CALL LOAD LOG ENABLE',
      'PARTIAL CALL MULT INFO ENABLE',
      'PRINTER ENABLE',
      'QUICK QSL KEY',
      'QUICK QSL MESSAGE',
      (* WITHDRAWN 2026-09-13 (NY4I). The row was ckNormal carrying
        pointer(51) -- a ListParamArray INDEX in the field that means an
        address -- and wrote nothing only because ctOther has no arm in that
        dispatch. There is no variable called Reminder anywhere. *)
      'REMINDER',
      'RADIO ONE COMMAND PAUSE',
      'RADIO ONE ICOM NETWORK PASSWORD',
      'RADIO ONE ICOM NETWORK USERNAME',
      'RADIO ONE ID CHARACTER',
      'RADIO ONE TRACKING ENABLE',
      'RADIO ONE UPDATE SECONDS',
      'RADIO TWO COMMAND PAUSE',
      'RADIO TWO ICOM NETWORK PASSWORD',
      'RADIO TWO ICOM NETWORK USERNAME',
      'RADIO TWO ID CHARACTER',
      'RADIO TWO TRACKING ENABLE',
      'RADIO TWO UPDATE SECONDS',
      'RTTY PORT',
      'RTTY RECEIVE STRING',
      'RTTY SEND STRING',
      'SCORE POSTING ID',
      'SEND ALT-D SPOTS TO PACKET',
      'SEND QSO IMMEDIATELY',
      'SERIAL 5 PORT ADDRESS',
      'SERIAL 6 PORT ADDRESS',
      'SERIAL PORT DEBUG',
      'SHOW SEARCH AND POUNCE',
      'SIMULATOR ENABLE',
      'TAB MODE',
      'TCI DEBUG',
      'TCI MAX TX SECONDS',
      'TELNET DEBUG',
      'TOTAL OFF TIME',
      'SINGLE RADIO MODE',
      'TOTAL SCORE MESSAGE',
      'UDP BROADCAST PORT',
      'USE BIOS KEY CALLS',
      'USE IRQS',
      'VGA DISPLAY ENABLE',
      'VISIBLE DUPESHEET',
      'WIDE FREQUENCY DISPLAY',
      'YAESU RESPONSE TIMEOUT'
      );

function RetiredCommandCount: integer;
begin
   Result := Length(RETIRED_COMMANDS);
end;

(*
  COMMANDS THAT STILL DO SOMETHING, WHOSE VALUE THIS ARRAY NO LONGER
  CARRIES.

  DELIBERATELY NOT RETIRED_COMMANDS, whose own header says adding to it is
  the last step of REMOVING a feature. UDP broadcasting is not removed: it
  is configured in settings\tr4w.json and applied by TUDPBroadcaster. The
  two lists answer different questions and a reader who conflates them will
  reach for the wrong fix.

  WHY THE NAMES HAVE TO STAY KNOWN. LogCfg.pas shows a MODAL "invalid
  statement in config file" for a line CheckCommand refuses, so an
  operator's existing tr4w.ini -- which is exactly the file the seeder
  reads -- would be declared invalid fourteen times over on the one startup
  where it still matters.

  AND WHY THE VALUE IS NOT APPLIED HERE. The store's own importer reads the
  ini directly, and it has to: a per-stream flag plus a port plus one shared
  address does not map onto a destination list one key at a time. Two
  importers for one file is how the globals and the store came to disagree
  in the first place.
*)
const
   OWNED_BY_A_STORE: array[0..31] of string = (
      (* THE WINKEYER, owned by the keyer library in settings\tr4w.json.

        ApplyKeyerToWinKey writes every one of these fields into
        WinKeySettings from the keyer definition, which is why the rows could
        go: the array was carrying a value the store already applies.

        THEY ARE NOT RETIRED AND MUST NOT GO ON THAT LIST. A WinKeyer still
        works; only the route changed. The log line the two lists produce is
        the whole point of keeping them apart -- an operator reading
        "withdrawn" against a WK line would conclude their keyer was
        unsupported. *)
      'WK AUTOSPACE',
      'WK CT SPACING',
      'WK DIT DAH RATIO',
      'WK ENABLE',
      'WK FIRST EXTENSION',
      'WK IGNORE SPEED POT',
      'WK KEYER COMPENSATION',
      'WK KEYER MODE',
      'WK LEADIN TIME',
      'WK PADDLE ONLY SIDETONE',
      'WK PADDLE SWAP',
      'WK PADDLE SWITCHPOINT',
      'WK PORT',
      'WK SIDETONE ENABLE',
      'WK SIDETONE FREQUENCY',
      'WK TAIL TIME',
      'WK WEIGHT',

      (* THE CLUSTER'S CONNECT STRING, owned by the cluster library in
        settings\tr4w.json. uRadioConfigApply assigns ConnectionCommand from
        the active cluster definition -- the row was a second writer of the
        same global, and the one that could disagree. *)
      'CONNECTION COMMAND',

      (* UDP BROADCASTING, owned by udpBroadcast in the same file. *)
      'UDP BROADCAST ADDRESS',
      'UDP BROADCAST ALL QSOS',
      'UDP BROADCAST APP INFO',
      'UDP BROADCAST CONTACT INFO',
      'UDP BROADCAST LOOKUP INFO',
      'UDP BROADCAST PORT APP INFO',
      'UDP BROADCAST PORT CONTACT',
      'UDP BROADCAST PORT LOOKUP',
      'UDP BROADCAST PORT RADIO',
      'UDP BROADCAST PORT SCORE',
      'UDP BROADCAST RADIO INFO',
      'UDP BROADCAST ROTOR',
      'UDP BROADCAST ROTOR PORT',
      'UDP BROADCAST SCORE'
      );

(* THE RADIO LIBRARY'S KEYS, WHICH ARE A SHAPE RATHER THAN A LIST.

  Twenty-seven per slot and both slots share the spellings, so naming them
  all would be fifty-four entries that have to stay in step with the
  renderer in uRadioConfigApply. The shape is what is stable:

      RADIO ONE <anything>      RADIO TWO <anything>
      POLL RADIO ONE            POLL RADIO TWO
      KEYER RADIO ONE ...       KEYER RADIO TWO ...

  The last two put the slot in the MIDDLE and at the END, which is why this
  cannot be a single prefix test -- the same reason KeySuffix in
  uRadioConfigApply is written the way it is. *)
function CommandIsRadioLibraryKey(const aCommand: string): boolean;
var
   name: string;
begin
   name := UpperCase(Trim(aCommand));
   Result := (Pos('RADIO ONE ', name) = 1)
          or (Pos('RADIO TWO ', name) = 1)
          or (name = 'POLL RADIO ONE')
          or (name = 'POLL RADIO TWO')
          or (Pos('KEYER RADIO ONE ', name) = 1)
          or (Pos('KEYER RADIO TWO ', name) = 1);
end;

function CommandIsOwnedByAStore(const aCommand: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(OWNED_BY_A_STORE) to High(OWNED_BY_A_STORE) do
      begin
      if UnicodeSameText(OWNED_BY_A_STORE[i], aCommand) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function StoreOwnedCommandCount: integer;
begin
   Result := Length(OWNED_BY_A_STORE);
end;

(* Linear over ~90 short strings, run once per config line at startup and
  never afterwards -- a dictionary here would be more code than the problem. *)
(* THE ONE BOUND A SUBRANGE CANNOT CARRY.

  RADIUS OF EARTH is a double, and a subrange type is ordinal, so the
  range that replaced crMin and crMax for every other bounded setting has
  nowhere to live on this one. The old ctReal arm compared against
  crMin/10 and crMax/10 -- 0 to 6553.5 -- and refused the line outside
  that, so the rule is registered against the property path instead.

  IT IS REGISTERED FROM HERE, not declared in uSettingsModel, for the
  reason MY COUNTRY's check is: the knowledge that this row once carried
  those bounds belongs to the unit that held the row. *)
function RadiusOfEarthIsInRange(const aValue: string): boolean;
var
   v: double;
   code: integer;
begin
   Val(aValue, v, code);
   Result := (code = 0) and (v >= 0) and (v <= 6553.5);
end;

function CommandIsRetired(const aCommand: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(RETIRED_COMMANDS) to High(RETIRED_COMMANDS) do
      begin
      if UnicodeSameText(RETIRED_COMMANDS[i], aCommand) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* THE COMMANDS THAT DO SOMETHING RATHER THAN SET SOMETHING.

  CFGCA is a table of SETTINGS -- a name, a place to put the value, a type.
  These four never fitted it: three APPEND to a list and one is a bare
  instruction, so each carried a crA hook that did the work and a crAddress
  pointing at scratch nobody read back. The row was a router.

  THE BODIES ARE THE HOOKS', UNCHANGED, and they run at the same point in
  CheckCommand that the hook did -- so a config file behaves identically.

  ACCUMULATING, WHICH IS WHY THEY ARE NOT SETTINGS AND NOT DUPLICATES: a
  config file may legitimately name FREQUENCY MEMORY a dozen times, and each
  line adds. CommandIsSingleValued already says so. *)
function TryApplyCommandAction(const aCommand: string;
                               const aValue: ShortString): boolean;
var
   n: integer;
   code: integer;
   freq: longint;
   band: BandType;
   mode: ModeType;
   text: string;
begin
   Result := True;

   if UnicodeSameText(aCommand, 'ADD DOMESTIC COUNTRY') then
      begin
      if aValue = 'CLEAR' then
         begin
         ClearDomesticCountryList;
         end
      else
         begin
         AddDomesticCountry(aValue);
         end;
      Exit;
      end;

   if UnicodeSameText(aCommand, 'CLEAR DUPE SHEET') then
      begin
      (* THE VALUE IS IGNORED, as it always was: naming the command IS the
        instruction, and what it records is WHICH file asked. *)
      ClearDupeSheetCommandGiven := RunningConfigFile;
      Exit;
      end;

   if UnicodeSameText(aCommand, 'BAND MAP CUTOFF FREQUENCY') then
      begin
      Val(aValue, n, code);
      Result := code = 0;
      if Result then
         begin
         AddBandMapModeCutoffFrequency(n);
         end;
      Exit;
      end;

   if UnicodeSameText(aCommand, 'FREQUENCY MEMORY') then
      begin
      (* THE HOOK'S BODY, with its own locals rather than the unit-wide
        scratch it used. 'SSB 14250' means the phone memory for that band;
        a bare frequency means CW. *)
      text := string(aValue);
      if Pos('SSB', UpperCase(text)) > 0 then
         begin
         Delete(text, Pos('SSB ', UpperCase(text)), 4);
         Val(text, freq, code);
         Result := code = 0;
         if Result then
            begin
            CalculateBandMode(freq, band, mode);
            DefaultFreqMemory[band, Phone] := freq;
            end;
         end
      else
         begin
         Val(text, freq, code);
         Result := code = 0;
         if Result then
            begin
            CalculateBandMode(freq, band, mode);
            DefaultFreqMemory[band, CW] := freq;
            end;
         end;
      Exit;
      end;

   Result := False;
end;

function CheckCommand(Command: PAnsiChar; CustomCMD: ShortString;
                      const aApplyJSONOwned: boolean = False): boolean;
label
   AdditionalProc;
type
   // Issue #997: every AdditionalProcsArray entry is a param-less boolean
   // function (default register convention); this type lets us call Proc
   // through a typed cast instead of inline asm.
   TAdditionalProc = function: Boolean;
var
   { The command as a STRING, so the tests below are Pos() on a value with a
     length rather than StrPos() on a pointer that runs to the first NUL.  See
     the window/colour block for why the pointer form had to go. }
   cmdText: string;
   i: integer;
   TempInteger: integer;
   TempInteger2: integer;
   TempReal: REAL;
   code: integer;
   Proc: Pointer;
   TempByte: Byte;
   //  TempString                            : Str10;
   TempElement: TMainWindowElement;
   TempColumn: LogColumnsType;
   ColumnToken: AnsiString;   // language-neutral column token from COLUMN WIDTH line
begin
{$IF MAKE_DEFAULT_VALUES = TRUE}
   Result := True;
   Exit;
{$IFEND}

   Command[Ord(Command[0]) + 1] := #0;
   Result := False;

   (* A SETTING THAT HAS LEFT CFGCA.

     NOT A FALLBACK, AND THE DISTINCTION IS THE WHOLE POINT.  A migrated
     setting and an unmigrated one are DISJOINT SETS -- a name that resolves
     here has no row, and a name with a row is not known here.  Each resolves
     in exactly one place.  Asking the settings object first is not a safety
     net in front of the array; it is the array becoming the smaller of two
     lookups, on its way to being none of them.

     WHAT IT IS ACTUALLY FOR, and the scope is one-time.  The ini and the
     contest .cfg are read ONCE and converted.  During that read a station
     upgrading from an older version still names these commands, and without
     this arm two things happen: the value is silently lost, and
     LogCfg.pas:1262 puts a modal "invalid statement in config file" dialog in
     front of the operator, about their own working config.

     IT IS ALSO WHY A ROW CAN BE DELETED RATHER THAN HOLLOWED OUT.  The csRem
     stubs exist only to return True so that dialog does not appear.  Once the
     name resolves for real, the stub has no job. *)
   (* A COMMAND THAT DOES SOMETHING, before the settings lookup and before the
     row scan -- which is where its row sat. Four accumulating or instruction
     commands live there now; see TryApplyCommandAction. *)
   if TryApplyCommandAction(string(pshortstring(Command)^), CustomCMD) then
      begin
      Result := True;
      Exit;
      end;

   if Settings.OwnsCommand(string(pshortstring(Command)^)) then
      begin
      (* AND IT DEPENDS ON WHO IS ASKING, exactly as a csJSON row does.

        THIS GUARD WAS MISSING WHEN THE ARM WAS FIRST WRITTEN, and its absence
        was a REGRESSION rather than an oversight in new code: every setting
        that has moved here came FROM a csJSON row, and those rows are
        protected a few lines below by

            if (CFGCA[i].crS = csJSON) and (not aApplyJSONOwned) then Exit;

        whose note says plainly what it is for -- "to stop a STALE INI FILE
        overriding settings\tr4w.json, which is the system of record". Moving
        a setting out of the array must not cost it that.

        WHAT IT LOOKED LIKE WITHOUT THIS: settings\tr4w.json is loaded first
        and asserted as the source of record, then ReadInConfigFile(cfgINI)
        runs unconditionally a dozen lines later -- so an old ini line for a
        migrated setting silently overwrote the stored value on EVERY launch,
        and a value changed in Preferences would not survive a restart. Two
        stores disagreeing with nobody able to say which is in force, which is
        the exact failure uSettingsModel's header exists to prevent.

        Found in review by Codex, 2026-09-11. It was invisible to the settings
        unit tests because they call TrySetByCommand directly and never
        reproduce the startup ORDER. *)
      if not aApplyJSONOwned then
         begin
         (* ACCEPTED AND INERT, the same answer a csJSON row gives an
           untrusted caller: the line is recognised, so no "invalid statement
           in config file" dialog, and it is not applied. *)
         Result := True;
         Exit;
         end;

      Result := Settings.TrySetByCommand(string(pshortstring(Command)^),
                                         string(CustomCMD));
      if (not Result) and (logger <> nil) then
         begin
         (* A value the property's type refuses -- reported, never swallowed.
           The config file said something this setting cannot be. *)
         logger.Warn('[CheckCommand] "%s" = "%s" refused by the settings object',
                     [pshortstring(Command)^, CustomCMD]);
         end;
      Exit;
      end;
   { if pshortstring(Command)^ = 'QSO POINT METHOD' then
     result := false;  }
   if length(pshortstring(Command)^) > 5 then

      if pshortstring(Command)^[1] in ['C', 'E'] then
         if pshortstring(Command)^[3] in [' '] then
            if pshortstring(Command)^[4] in ['S', 'C', 'D', 'M'] then
               //          if pshortstring(Command)^[7] in [' ', 'M', 'O'] then
               if pshortstring(Command)^[10] in ['M', 'O', ' '] then
                  begin
                  Result := ProcessMessage(pshortstring(Command)^,
                     CustomCMD);

                  Exit;
                  end;

   { WAS StrPos(PAnsiChar(@Command[1]), ...), AND THE CAST WAS ITSELF A FIX.

     The comment that used to be here explained that @Command[1] is an untyped
     Pointer, so StrPos resolved to the WIDE overload and read the ANSI bytes as
     UTF-16 -- it never matched, and PAnsiChar forced the right overload.  True,
     and it fixed the symptom while leaving the shape: the address of a
     ShortString's first character, read until a NUL that the string does not
     carry.  NY4I, 2026-08-24: "this type of typecasting has no place in this
     code base any longer."

     A string has a length, Pos takes one, and there is no overload to pick
     wrong.  Note StrPos(a, b) = a -- "b starts at the beginning of a" -- is
     Pos(b, a) = 1. }
   cmdText := string(pshortstring(Command)^);

   if Pos(' WINDOW ', cmdText) > 0 then
      begin
      for TempElement := Low(TMainWindowElement) to High(TMainWindowElement)
         do
         begin

         if Pos(string(TWindows[TempElement].mweName), cmdText) = 1 then
            begin
            TempByte := GetValueFromArray(@tr4wColorsSA,
               Byte(High(tr4wColors)), CustomCMD);
            if TempByte <> UNKNOWNTYPE then
               begin
               if Pos(' COLOR', cmdText) > 0 then
                  begin
                  TWindows[TempElement].mweColor :=
                     tr4wColors(TempByte)
                  end
               else
                  begin
                  TWindows[TempElement].mweBackG :=
                     tr4wColors(TempByte);
                  end;
               Result := True;
               Exit;
               end
            else
               begin
               Break;
               end;

            end;

         end;
      end;

   if Pos('COLUMN WIDTH ', cmdText) = 1 then
      begin
      // Match against the canonical (language-neutral) column name first.
      // Fall back to UpperCase(Text) so CFGs written before the canonical
      // table existed (i.e. old English builds where Text already happened
      // to be an English word) continue to load. Without the canonical
      // path, non-English builds reject COLUMN WIDTH lines because Text
      // is translated at compile time -- e.g. RC_CALLSIGN resolves to
      // 'Indicativo' under -DLANG_ESP and never matches 'CALLSIGN'.
      // The token is extracted once to an AnsiString so the PChar cast
      // is legal -- Delphi 7 cannot cast a ShortString directly to PChar.
      ColumnToken := Copy(pshortstring(Command)^, 14, 255);
      for TempColumn := Low(LogColumnsType) to High(LogColumnsType) do
         begin
         if (StrComp(ColumnCanonicalName[TempColumn], PAnsiChar(ColumnToken)) = 0)
         or (UpperCase(ColumnsArray[TempColumn].Text) = ColumnToken) then
            begin
            Val(CustomCMD, TempInteger, code);
            if code = 0 then
               begin
               ColumnWidthOverride[TempColumn] := TempInteger;
               logger.Debug('CheckCommand: COLUMN WIDTH %s = %d (col index %d)',
                  [ColumnCanonicalName[TempColumn], TempInteger, Ord(TempColumn)]);
               end;
            Result := True;
            Exit;
            end;
         end;
      end;

   if pshortstring(Command)^ = 'ALERT COLOR' then
      begin
      TempByte := GetValueFromArray(@tr4wColorsSA,
         Byte(High(tr4wColors)), CustomCMD);
      if TempByte <> UNKNOWNTYPE then
         begin
         AlertColor := tr4wColors(TempByte);
         Result := True;
         Exit;
         end;
      end;


   (* THE ROW SCAN IS GONE -- 2026-09-14, and with it the last of CFGCA.

     Three hundred lines stood here: a linear StrComp down 415 rows, then a
     crS check, then a crKind branch into one of two positional arrays, then
     a crType case that dereferenced crAddress as a ShortString, a Boolean,
     a Double, a Word, a Byte or an Integer, then bounds from crMin/crMax,
     then a crA index into a table of untyped Pointers called as a function.

     EVERY ONE OF THOSE WAS A RESTATEMENT OF SOMETHING THE COMPILER ALREADY
     KNEW. The name is derived from the property path, the target IS the
     property, the bounds are a subrange type, the side effect is the
     setter, and what used to be a hook index is an effect in
     uSettingsEffects that runs however the value was set rather than only
     when a config line applied it.

     WHAT STILL HAPPENS HERE, in order, is what the arms above and below do:
     the pattern families (COLUMN WIDTH, the window colours), the four
     ACTIONS in TryApplyCommandAction, the settings arm that resolves a name
     against the model, then the two lists that ACCEPT and ignore -- a
     withdrawn name, and a name a store owns. *)

   (* A WITHDRAWN COMMAND -- accepted, and deliberately does nothing.

     LAST, AFTER EVERY LIVE HANDLER HAS DECLINED, which is what makes it safe.
     CheckCommand matches several PATTERN families before it ever scans the
     rows, and one withdrawn name -- EXCHANGE WINDOW S&P BACKGROUND -- is
     matched by the generated "<element> WINDOW COLOR/BACKGROUND" family, so
     it has been reaching the colour handler rather than its own row all
     along.  Asking this question earlier would silently stop that colour
     being applied. *)
   if (not Result) and CommandIsRetired(string(pshortstring(Command)^)) then
      begin
      if logger <> nil then
         begin
         logger.Info('[Config] %s is a withdrawn command -- accepted and ignored',
                     [pshortstring(Command)^]);
         end;
      Result := True;
      end;

   (* A SETTING A STORE OWNS. Same position and the same reason as the
     withdrawn names above -- last, after every live handler has declined --
     but a DIFFERENT fact, so it says a different thing in the log. An
     operator reading "withdrawn" against a UDP line would conclude the
     feature was gone. *)
   if (not Result) and
      CommandIsOwnedByAStore(string(pshortstring(Command)^)) then
      begin
      if logger <> nil then
         begin
         logger.Info('[Config] %s is read from the settings store, not from '
                     + 'this file -- accepted here and applied there',
                     [pshortstring(Command)^]);
         end;
      Result := True;
      end;
end;






{
function F_ICOM_RESPONSE_TIMEOUT: boolean;
begin
  Val(CMD, cmdIcomResponseTimeout, Result1);
  RESULT := Result1 = 0;
  if Result1 = 0 then cmdIcomResponseTimeout := cmdIcomResponseTimeout div 10 else Exit;
  if not (cmdIcomResponseTimeout in [10..100]) then cmdIcomResponseTimeout := 10;
end;
}


(* IS THIS A COUNTRY CTY.DAT KNOWS?

  MY COUNTRY is the CTY.DAT PREFIX CODE for the operator's DXCC entity --
  'K' for the United States (NY4I, 2026-09-12) -- so the test is that the
  country file resolves the value to ITSELF. 'K' resolves to country 'K';
  'USA' does not resolve to 'USA', and is refused.

  THIS IS WHAT F_MY_COUNTRY DID, minus the two things that were not
  validation. It raised MyCountryIsSet, which is the property setter's job
  now, and it assigned CountryString, a global written in five places and
  READ IN NONE -- deleted rather than carried across.

  It is registered against the property PATH rather than the command name,
  because the path is what the settings model resolves and what a wrong
  hook index can no longer be. *)
(* A..Z, EXACTLY AS ctAlphaChar DEMANDED, and nothing else -- see the
  registration at the bottom of this unit for why this is a check rather
  than a subrange type. An empty value is refused the way the old arm
  refused it: CustomCMD[1] on an empty ShortString is #0, which is not a
  letter. *)
function ComputerIdIsALetter(const aValue: string): boolean;
begin
   Result := (Length(aValue) = 1) and (aValue[1] >= 'A') and (aValue[1] <= 'Z');
end;

function MyCountryIsAKnownPrefix(const aValue: string): boolean;
var
   TempQTH: QTHRecord;
begin
   (* An empty value is not a claim about a country, so it is accepted and
     leaves the derivation to the callsign -- CountryWasSet stays False. *)
   if Trim(aValue) = '' then
      begin
      Result := True;
      Exit;
      end;

   ctyLocateCall(ShortString(AnsiString(aValue)), TempQTH);
   Result := UnicodeSameText(aValue, string(TempQTH.CountryID));
end;





{
function F_SETPARALLELPORT: boolean;
begin
  asm
nop
  end;
end;
}


function ProcessMessage(ID, CMD: ShortString): boolean;
var
   CQMessage: boolean;
   TempValue: integer;
   TempMode: ModeType;
   Offset: Cardinal;
   FuncKey: Cardinal;
begin
   {
   CQ DIG MEMORY F1=CQ CQ CQ \ \ TEST
   CQ DIG MEMORY ALTF1=CQ CQ CQ \ \ TEST
   CQ CW MEMORY CONTROLF1=CQ CQ CQ \ \ TEST
   CQ MEMORY F1 =\\ TEST
   CQ DIG MEMORY F1 CAPTION=
   CQ CW MEMORY CONTROLF5=<03>SRS=PB1;<04>
   CQ CW MEMORY CONTROLF5 CAPTION=PLAYCH1MSG
   }

   //  if ID[1] = 'C' then CQMessage := True else CQMessage := False;
   Result := False;
   CQMessage := ID[1] = 'C';
   TempMode := NoMode;

   Offset := 8; //Pos of  "MEMORY"

   case ID[4] of
      'S': TempMode := Phone;
      'D': TempMode := Digital;
      'C':
         begin
            TempMode := CW;
            Offset := 7;
         end;

      'M':
         begin
            TempMode := CW;
            Offset := 4;
         end;
   end;

   if TempMode = NoMode then
      begin
      Exit;
      end;

   TempValue := 0;
   case ID[Offset + 7] of
      'F':
         begin
            TempValue := 111;
            inc(Offset, 8);
         end;
      'A':
         begin
            TempValue := 135;
            inc(Offset, 8 + 3);
         end;
      'C':
         begin
            TempValue := 123;
            inc(Offset, 8 + 7);
         end;
   end;

   { THE CASE ABOVE HAS NO else, AND THAT WAS A CRASH.

     TempValue is the base of the function-key code: 111 for plain F-keys,
     123 for Ctrl, 135 for Alt. If the character is none of F/A/C it stays
     ZERO and Offset is never advanced -- so the key became CHR(0 + FuncKey),
     i.e. 1..12, written into an array declared [F1..AltF12] = 112..147.
     That is an out-of-bounds New() roughly 111 elements BEFORE the array,
     silently, because range checking is off in this build. It leaves a
     valid-looking heap pointer in whatever global sits there.

     ShowFMessages then finds that slot non-nil, dereferences it and takes
     an access violation -- which is the Ctrl-P crash of 2026-08-15
     (uFunctionKeys.pas:279, reached from tr4w.lpr:1415 where Ctrl calls
     ShowFMessages(12)). The corruption and the symptom are in different
     units, which is why it took a symbolicated backtrace to find.

     An unrecognised prefix means this is not a function-key memory command
     at all, so refuse it rather than inventing a key for it. }
   if TempValue = 0 then
      begin
      Exit;
      end;
   FuncKey := Ord(ID[Offset]) - Ord('0');
   if length(ID) > Offset then
      if ID[Offset + 1] in ['0'..'2'] then
         begin
         FuncKey := Ord(ID[Offset + 1]) - Ord('0') + 10;
         end;

   if not (FuncKey in [1..12]) then
      begin
      Exit;
      end;

   Result := True;

   if ID[length(ID)] = 'N' then
      begin
      if CQMessage then
         begin
         SetCQCaptionMemoryString(TempMode, CHR(TempValue + FuncKey), CMD)
         end
      else
         begin
         SetEXCaptionMemoryString(TempMode, CHR(TempValue + FuncKey), CMD);
         end;
      end
   else
      begin
      if CQMessage then
         begin
         SetCQMemoryString(TempMode, CHR(TempValue + FuncKey), CMD)
         end
      else
         begin
         SetEXMemoryString(TempMode, CHR(TempValue + FuncKey), CMD);
         end;
      end;

end;

procedure UpdateDebugLogLevel; // This is called when changed in the Config dialog
begin
   if not Assigned(logger) then
      begin
      // UpdateLogLevel called before logger object has been created
      Exit;
      end;
   case Settings.Log.DebugLevel of
      llNone: logger.Level := Off;
      llFatal: logger.level := Fatal;
      llError: logger.Level := Error;
      llWarn: logger.Level := Warn;
      llInfo: logger.Level := Info;
      llDebug: logger.Level := Debug;
      llTrace: logger.Level := Trace;
      else ;
   end;
   // Also set root logger so all named loggers (transport, radio, etc.) inherit the level
   TLogLogger.GetRootLogger.Level := logger.Level;

end;





procedure InitializeStrings;
(* THE SEED TABLE IS GONE, 2026-09-12, AND SO ARE THE TYPE AND THE LOOP.

  It was a hand-typed list of ADDRESSES beside the values they seed -- the
  same shape as the pointer tables being retired -- and it shrank from
  fifteen entries to two when the message templates left for
  Settings.Messages. Those last two were the score server URLs, and they are
  TScoreSettings' constructor now, which is where a default belongs.

  WHAT THAT TABLE TAUGHT IS WORTH KEEPING. Every global it seeded was
  declared with its initialiser COMMENTED OUT, so the declarations said
  "empty" and this routine held the real values. A migration that trusted a
  declaration would have shipped thirteen blank messages, and neither a build
  nor a test run would have said so. Check for a startup assignment before
  believing any default.

  The four buffer appends below are a different job and stay. *)
begin
   (* FOUR APPENDS ONTO MAX_PATH BUFFERS.  lstrcatA took the destination as
     a bare pointer with no length, so nothing here could have stopped an
     overrun -- and nothing checked.  AppendToBuffer takes the array and
     reads its own bounds; all four fit, and it says so if one ever stops
     fitting. *)
   (* .db, NOT .tr4w. The backup is a SQLite snapshot of the contest log
     now, so the old extension named a format it no longer is -- and an
     operator who needs this file back has to be able to open it. *)
   (* THE TWO FILE-NAME DEFAULTS MOVED WITH THEIR SETTINGS, 2026-09-13 --
     TLogSettings.Create and TContestSettings.Create carry the same
     'logback.db' and 'INITIAL.EX' these lines appended.  A default belongs
     with the value it defaults. *)
   (* THE TWO AUDIO DEFAULTS MOVED WITH THEIR SETTINGS. MP3 is withdrawn
     with the recorder; DVK is TDvkSettings.Create, which carries the same
     'DVK' this line did -- a default belongs with the value it defaults. *)

end;

(* AN ALLOW-LIST, RENDERED ONCE AS TEXT.

  The const arrays below are what CheckCommand matched a config line against,
  and they stay exactly where they are. This turns one into the form the
  settings model registers, at startup, so there is still ONE statement of
  which values a setting accepts rather than a second copy typed out by hand.
*)
function IntegerVocabulary(const aValues: array of integer): TArray<string>;
var
   i: integer;
begin
   SetLength(Result, Length(aValues));
   for i := 0 to High(aValues) do
      begin
      Result[i] := IntToStr(aValues[i]);
      end;
end;

(* THE VALIDATOR THAT USED TO BE A HOOK INDEX.

  Registered HERE because this is the unit that knows about CTY.DAT, and
  the settings model deliberately does not. An initialization section runs
  before any configuration is read, so the check is in force for the very
  first MY COUNTRY line of the first file. *)
initialization
   RegisterSettingValueCheck('My.Country', @MyCountryIsAKnownPrefix);
   (* AND THE ONE THAT USED TO BE A crType. COMPUTER ID was ctAlphaChar,
     whose whole difference from ctChar is `if CustomCMD[1] in ['A'..'Z']`
     and Exit otherwise -- a REFUSAL, which is what a registered check does
     and what a property setter cannot do.

     It is registered here rather than expressed as a char subrange on the
     property because #0 is the unset value and has to stay assignable; a
     type of 'A'..'Z' could not hold it. *)
   RegisterSettingValueCheck('Computer.Id', @ComputerIdIsALetter);
   (* AND THE ONE THAT WAS crMin/crMax ON A REAL. See the function. *)
   RegisterSettingValueCheck('GridMap.RadiusOfEarth',
                             @RadiusOfEarthIsInRange);
   (* AND THE ALLOW-LIST THAT IS NOT A RANGE. It was a ckArray row; the array
     is unchanged and this is the same list, rendered.

     STEREO CONTROL PIN was the second one and went with the parallel port on
     2026-09-13 -- it named WHICH LPT PIN drove the headphone relay. *)
   RegisterSettingAllowedValues('Scp.MinimumLetters',
                                IntegerVocabulary(SCP_MINIMUM_LETTERS_ARRAY));
   RegisterSettingAllowedValues('Contest.MultReportMinimumBands',
                                IntegerVocabulary(MULT_REPORT_MINIMUM_BANDS_ARRAY));

   (* THE FOUR MULTIPLIER VOCABULARIES, from the very tables CheckCommand
     matched their ckList rows against -- so the drop-down, the refusal and
     the engine cannot disagree about what 'ARRL DXCC' means.

     HERE rather than in uSettingsModel for the reason MY COUNTRY's check is:
     the unit that can SEE the vocabulary is the one that registers it. These
     four tables live in VC, logdupe and logwind, none of which the settings
     model imports. *)
   (* THE TEN ckList TOKENS' VOCABULARIES, from the very tables their rows
     matched against. Without these each setting would have NO allow-list --
     which is not a quiet gap: Preferences renders a setting with no allowed
     values as an EMPTY drop-down, and nothing refuses a bad value. That
     failure is invisible to the build, the lints and the corpus, and it has
     happened here before. *)
   RegisterSettingAllowedValues('Contest.Band',
                                BandStringsArrayWithOutSpaces);
   RegisterSettingAllowedValues('Contest.SingleBandScore',
                                BandStringsArrayWithOutSpaces);
   RegisterSettingAllowedValues('Contest.ContestToken', ContestTypeSA);
   RegisterSettingAllowedValues('Contest.ExchangeReceived',
                                ActiveExchangeArray);
   RegisterSettingAllowedValues('Contest.InitialExchange',
                                InitialExchangeTypeStringArray);
   RegisterSettingAllowedValues('Contest.InitialExchangeCursorPos',
                                IECursorPosTypeStringArray);
   RegisterSettingAllowedValues('Contest.Mode', ModeStringArray);
   RegisterSettingAllowedValues('Contest.MyContinent', ContinentTypeSA);
   RegisterSettingAllowedValues('Contest.QslMode',
                                ParameterOkayModeTypeStringArray);
   RegisterSettingAllowedValues('Contest.QsoPointMethod', QSOPointMethodArray);

   RegisterSettingAllowedValues('Contest.DomesticMultiplier',
                                DomesticMultStringArray);
   RegisterSettingAllowedValues('Contest.DxMultiplier',
                                DXMultTypenameArray);
   RegisterSettingAllowedValues('Contest.PrefixMultiplier',
                                PrefixMultStringArray);
   RegisterSettingAllowedValues('Contest.ZoneMultiplier',
                                ZoneMultTypeSA);

end.

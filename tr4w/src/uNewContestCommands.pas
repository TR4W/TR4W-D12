unit uNewContestCommands;

(* WHAT THE NEW CONTEST DIALOG CHOSE, HELD UNTIL THE STATION IS LOADED.

  THE ORDER IS THE WHOLE POINT OF THIS UNIT. A contest's own values must be
  applied AFTER the station's, because the contest is allowed to override the
  station -- the club-call case: the station call is NY4I, and this one contest
  is operated as W4TA. That is how it always worked. The dialog wrote a .cfg
  and startup read it after tr4w.ini (D7: tr4w.dpr:683 then :685), so the
  contest's lines landed last and won.

  66ac1ebe (2026-09-02) took the .cfg file out and applied the values straight
  into the config layer AT DIALOG TIME -- which was harmless while MY CALL was a
  global nothing reloaded. Ten days later the MY commands became properties of
  the settings object (c1463660, ad78fc8a, 463a0835), and that object is loaded
  from settings\tr4w.json by LoadSettingsForStartup -- AFTER the dialog. The
  load put the station's values back over the contest's:

    a fresh station     MY CALL, MY FD CLASS and MY SECTION came back EMPTY,
                        the new log captured them empty, and startup halted
                        on "No callsign specified!!" (NY4I, macOS, ARRL-FD).
    a configured one    the stored station call silently replaced the club
                        call the operator had just typed.

  THE SAME MISTAKE HID TWO MORE:

    CONTEST never set the contest up. Its effect -- FoundContest, which
    chooses the exchange, the multipliers and the domestic file -- runs from
    InstallTokenEffects, and that is subscribed long after the dialog closes.
    The token was stored and nothing acted on it.

    The dialog's provenance was erased. ReadInConfigFile(cfgCFG) clears the
    "this contest asked for it" tracker when the contest file does not exist
    yet -- which a brand-new log never does -- so everything the dialog
    marked as the CONTEST'S was captured into the log as the STATION'S.

  So the dialog QUEUES, and uProgramMain APPLIES, at the point where the .cfg
  used to be read: after the station settings, after the effects are
  subscribed, and before the log is created and captures its configuration.

  MAIN CALLSIGN IS QUEUED TOO, for the same reason and a worse consequence.
  The dialog wrote it back and SAVED THE SETTINGS -- from an object that had
  not been loaded yet. SaveSettings replaces the whole section, so every New
  Contest wrote the constructor defaults over the operator's station settings
  (uSettingsConvert warns about exactly this, beside its own load). It is
  applied here BEFORE the contest's values, so the station file gets the
  station's callsign and none of the contest's.

  NOTHING QUEUED, NOTHING DONE. Opening an existing contest, a contest file on
  the command line, and every headless mode never show the dialog, so for them
  ApplyNewContestChoices returns at its first test. *)

{$I tr4w.inc}

interface

(* Forgets anything queued. The dialog calls it before queuing, so a second
  pass through the dialog does not inherit the first one's choices. *)
procedure ClearNewContestChoices;

(* The callsign to remember as the station's own, if it has none yet. *)
procedure SetNewContestMainCallsign(const aCallsign: string);

(* One setting the dialog collected, AS THE CONTEST'S. Order is kept: CONTEST
  must be queued last, because its effect builds the contest from the values
  queued before it. *)
procedure QueueNewContestCommand(const aCommand, aValue: string);

(* Whether the dialog created a contest this run -- anything queued at all. *)
function HasNewContestChoices: boolean;

(* THE APPLICATION. Call it after the station settings are loaded and the
  token effects are subscribed, and before the log is opened. Returns how many
  commands were accepted; nothing queued returns 0 having done nothing.

  aSettingsFile is where MAIN CALLSIGN is saved -- TR4WConfigFileName in the
  program, a temporary file in the tests. *)
function ApplyNewContestChoices(const aSettingsFile: string): integer;

implementation

uses
   Classes,
   SysUtils,
   MainUnit,         // logger
   uCFG,             // CheckCommand, NoteCommandFromContestCFG, ClearContestCFGCommands
   uSettingsModel,   // Settings.My.MainCallsign
   uTR4WConfigFile;  // SaveSettings

var
   (* NAME=VALUE, in the order queued. A command name never contains '=',
     so Names and ValueFromIndex split each line correctly even when the value
     does. *)
   gCommands: TStringList = nil;
   gMainCallsign: string = '';

function Commands: TStringList;
begin
   if gCommands = nil then
      begin
      gCommands := TStringList.Create;
      end;
   Result := gCommands;
end;

procedure ClearNewContestChoices;
begin
   Commands.Clear;
   gMainCallsign := '';
end;

procedure SetNewContestMainCallsign(const aCallsign: string);
begin
   gMainCallsign := Trim(aCallsign);
end;

procedure QueueNewContestCommand(const aCommand, aValue: string);
begin
   if Trim(aCommand) = '' then
      begin
      Exit;
      end;
   (* AnsiString() STATED: TStringList holds the RTL string while tr4w.inc
     makes this unit's string UnicodeString. ApplyOne hands CheckCommand a
     ShortString anyway, so the text becomes ANSI on the way there either
     way; saying so here keeps the conversion out of the narrowing count. *)
   Commands.Add(AnsiString(Trim(aCommand) + '=' + aValue));
end;

function HasNewContestChoices: boolean;
begin
   Result := (Commands.Count > 0) or (gMainCallsign <> '');
end;

(* Applies one setting AS THE CONTEST'S.

  Two halves and both are load-bearing. NoteCommandFromContestCFG records that
  THIS CONTEST asked for it, which is what makes uLogStore capture it with
  source = 'contest' and apply it back on the next open. CheckCommand with
  aApplyJSONOwned = True applies it: the settings object owns every one of
  these names, and the default refuses a stored setting from an untrusted
  caller. *)
function ApplyOne(const aCommand, aValue: string): boolean;
var
   key, val: ShortString;
begin
   NoteCommandFromContestCFG(aCommand);

   (* PLAIN ASSIGNMENT from an AnsiString. A ShortString() cast of a string
     reinterprets the pointer rather than converting -- see uLogStore. *)
   key := AnsiString(aCommand);
   val := AnsiString(aValue);

   Result := CheckCommand(key, val, True);
   if (not Result) and (logger <> nil) then
      begin
      logger.Warn('[NewContest] %s = %s was refused and is not set.',
                  [aCommand, aValue]);
      end;
end;

function ApplyNewContestChoices(const aSettingsFile: string): integer;
var
   i: integer;
begin
   Result := 0;
   if not HasNewContestChoices then
      begin
      Exit;
      end;

   try
      (* THE STATION'S CALLSIGN FIRST, and only the first time -- see the
        property's own note: the dialog pre-fills from it and writes it back
        when it is empty. Saved BEFORE any contest value is applied, so the
        station file receives this and nothing the contest chose. *)
      if (gMainCallsign <> '') and (Settings.My.MainCallsign = '') then
         begin
         Settings.My.MainCallsign := gMainCallsign;
         SaveSettings(aSettingsFile, Settings);
         end;

      (* THE DIALOG IS THIS CONTEST'S CONFIGURATION, so it starts the tracker
        afresh -- the same reset a contest .cfg load makes before its first
        line. *)
      ClearContestCFGCommands;

      for i := 0 to Commands.Count - 1 do
         begin
         if ApplyOne(string(Commands.Names[i]),
                     string(Commands.ValueFromIndex[i])) then
            begin
            Inc(Result);
            end;
         end;

      if logger <> nil then
         begin
         logger.Info('[NewContest] applied %d of %d setting(s) chosen in ' +
                     'New Contest, after the station settings',
                     [Result, Commands.Count]);
         end;
   finally
      (* Applied once. A later call in the same run must not apply them again
        over whatever the log has since said. *)
      ClearNewContestChoices;
   end;
end;

finalization
   FreeAndNil(gCommands);

end.

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

(* THE VALUE QUEUED FOR aCommand -- the last one queued, matched in any case;
  '' when it was not queued. Read only: what the dialog will apply, for a
  test to check (issue 217) and nothing to change. *)
function QueuedNewContestValue(const aCommand: string): string;

(* THE APPLICATION. Call it after the station settings are loaded and the
  token effects are subscribed, and before the log is opened. Returns how many
  commands were accepted; nothing queued returns 0 having done nothing.

  aSettingsFile is where MAIN CALLSIGN is saved -- TR4WConfigFileName in the
  program, a temporary file in the tests. *)
function ApplyNewContestChoices(const aSettingsFile: string): integer;

(* THE QUEUE, HANDED TO ANOTHER PROCESS -- File > Open Log's New Contest
  (issue 228).

  From the running program the dialog cannot create the contest: its values
  are applied AFTER the station load and BEFORE the log is created (above),
  and doing that inside a session already holding another contest is the
  state leak issue 218 S1-S6 exist to fix. So the queue is written to aFile,
  the program restarts, and the new instance loads it back into this queue
  before startup reaches ApplyNewContestChoices -- the same place, the same
  order, a clean process.

  THE FORMAT IS THIS UNIT'S AND NOBODY ELSE'S: a header line, the station
  callsign (its own line, so no command name can collide with it),
  then the queued NAME=VALUE lines verbatim and in order.

  Save answers False, having reported why, when the file cannot be written;
  the caller then starts nothing. Load answers False for a file that is
  missing, unreadable, or not in this format, and queues nothing; it does not
  delete the file -- the caller does, once it has the answer. *)
function SaveNewContestChoices(const aFile: string): boolean;
function LoadNewContestChoices(const aFile: string): boolean;

implementation

uses
   Classes,
   SysUtils,
   MainUnit,         // logger
   uCFG,             // ApplyContestStatement, NoteCommandFromContestCFG, ClearContestCFGCommands
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

function QueuedNewContestValue(const aCommand: string): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to Commands.Count - 1 do
      begin
      (* Widened to compare, never narrowed: the list holds the RTL string. *)
      if UnicodeSameText(string(Commands.Names[i]), Trim(aCommand)) then
         begin
         Result := string(Commands.ValueFromIndex[i]);
         end;
      end;
end;

(* Applies one setting AS THE CONTEST'S.

  Two halves and both are load-bearing. NoteCommandFromContestCFG records that
  THIS CONTEST asked for it, which is what makes uLogStore capture it with
  source = 'contest' and apply it back on the next open. ApplyContestStatement
  applies it: a STATION FACT the dialog asked for (MY STATE, MY ZONE, MY
  SECTION...) becomes this contest's override and never reaches the station's
  settings (design 7.12); anything else is CheckCommand with aApplyJSONOwned =
  True, because the settings object owns these names and the default refuses
  a stored setting from an untrusted caller. *)
function ApplyOne(const aCommand, aValue: string): boolean;
begin
   NoteCommandFromContestCFG(aCommand);

   Result := ApplyContestStatement(aCommand, aValue);
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

const
   HANDOFF_HEADER = 'TR4W NEW CONTEST HAND-OFF 1';

function SaveNewContestChoices(const aFile: string): boolean;
var
   lines: TStringList;
begin
   Result := False;
   lines := TStringList.Create;
   try
      lines.Add(HANDOFF_HEADER);
      (* AnsiString() STATED, exactly as QueueNewContestCommand states it for
        the command lines below: the same program reads it back the same way. *)
      lines.Add(AnsiString(gMainCallsign));
      lines.AddStrings(Commands);
      try
         (* SaveToFile opens, writes and CLOSES the file before it returns, so
           the child can never find it half written by a parent still running. *)
         lines.SaveToFile(RawByteString(aFile));
         Result := True;
      except
         on e: Exception do
            begin
            if logger <> nil then
               begin
               logger.Error('[NewContest] the new contest could not be written ' +
                            'for the restart to %s: %s', [aFile, e.Message]);
               end;
            end;
      end;
   finally
      lines.Free;
   end;
end;

function LoadNewContestChoices(const aFile: string): boolean;
var
   lines: TStringList;
   i: integer;
begin
   Result := False;
   ClearNewContestChoices;
   if not FileExists(aFile) then
      begin
      Exit;
      end;

   lines := TStringList.Create;
   try
      try
         lines.LoadFromFile(RawByteString(aFile));
      except
         on e: Exception do
            begin
            if logger <> nil then
               begin
               logger.Error('[NewContest] the hand-off file %s could not be read: %s',
                            [aFile, e.Message]);
               end;
            Exit;
            end;
      end;

      if (lines.Count < 2) or (lines[0] <> HANDOFF_HEADER) then
         begin
         Exit;
         end;

      gMainCallsign := Trim(string(lines[1]));
      for i := 2 to lines.Count - 1 do
         begin
         if lines[i] <> '' then
            begin
            Commands.Add(lines[i]);
            end;
         end;
      Result := True;
   finally
      lines.Free;
   end;
end;

finalization
   FreeAndNil(gCommands);

end.

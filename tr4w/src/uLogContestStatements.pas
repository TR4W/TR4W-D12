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

(* THE CONTEST LOG STORES ONLY WHAT THE OPERATOR STATED -- section 7.8 of
  docs/CONTEST_OWNERSHIP_DESIGN.md (Q3, decided 2026-10-01).

  WHAT WAS WRONG. uLogStore.CaptureConfiguration wrote EVERY contest-scoped
  setting's current value into the log's config table, on create and on every
  clean close. For the contest-rule settings -- QSO POINT METHOD, the four
  MULTIPLIER commands, INITIAL EXCHANGE, EXCHANGE RECEIVED -- that value is
  the TR4WSettings constructor default ('NONE', 'UNKNOWN'), because
  FoundContest sets the GLOBALS and never those properties. Every log in the
  golden corpus carries all seven as sentinels. Nothing could tell "the
  operator chose NONE" from "nobody chose", and on reopen a stored sentinel
  was applied over whatever a .cfg had just said (defect D2): harmless only
  while the value in force happened to equal it.

  THE RULE NOW, IN THREE PARTS:

    WRITE  a contest-scoped row exists only while TR4WSettings.CommandIsStated
           answers True. The capture writes those and DELETES the row of every
           other contest-scoped setting. Absence means the contest decides.

    MARK   the log records that it was captured under this rule, in its own
           session_state table (STATEMENTS_ONLY_KEY). From then on every
           contest-scoped row in it is a statement, whatever its value --
           including an operator who stated 'NONE' on purpose (ARRL Field Day
           has no multipliers, Q1).

    READ   a log WITHOUT the mark was written by the dumping capture. A
           contest-scoped row there whose value equals the constructor
           default is read as NOT stated: dropped, not applied, and deleted
           at the next capture. A non-default value is a statement -- in that
           era the capture wrote real values, which came from a .cfg or the
           New Contest dialog -- and is applied and flagged as one.

  WHY A LEAF. uLogStore links MainUnit and cannot be linked by the unit-test
  program; these rules need tests, and need nothing but the settings object
  and the repository. uLogStore calls in.

  A RETIRED SETTING'S ROW IS NOT A STATEMENT, IN EITHER ERA -- M10 S2,
  2026-10-14. QSO POINT METHOD, EXCHANGE RECEIVED, INITIAL EXCHANGE and the
  four multiplier commands are in uCFG.RETIRED_COMMANDS (NY4I, Q4): the
  contest's class decides them. Every log written before 2026-10-01 stores a
  row for each (the sentinels above), and a statements-only log may hold a
  real one an operator made before the ruling. The read sets every such row
  aside -- not applied, and handed back so the caller can say what it set
  aside -- and the capture DELETES it. Deleted rather than left inert
  because (1) nothing can ever read it again, (2) left in place it would be
  set aside and reported on every open of that log for ever, and (3) an
  older build opening the log afterwards finds no row, which already meant
  "the contest decides" there. /EXPORT never captures, so the corpus
  fixtures keep theirs and keep exercising the read.

  THIS UNIT DOES NOT KNOW WHICH NAMES ARE RETIRED. uCFG owns that list and
  is far too heavy for a leaf to link, so the caller passes the question in
  as a TCommandTest -- uLogStore passes uCFG.CommandIsRetired, the tests pass
  their own. One list, asked from one place.

  STATION-SCOPED ROWS ARE NOT THIS UNIT'S BUSINESS -- WITH ONE EXCEPTION.
  CaptureConfiguration still writes them as it always did, except the station
  FACTS a contest may override (design 7.12, 2026-10-13): MY STATE, MY ZONE,
  MY GRID and the rest are written by CaptureStationFactRows, the contest's
  override as 'contest' while it stated one, else the station's value as
  'station'. Same rule as above, applied to a station fact: a 'contest' row
  is a statement, and absence means the station decides. *)
unit uLogContestStatements;

{$I tr4w.inc}

interface

uses
   Classes,
   uSettingsModel,
   uLogRepository;

const
   (* The session_state key that says a log's config table holds statements
     only. Its value is '1'. A log without it predates the rule. *)
   STATEMENTS_ONLY_KEY = 'configHoldsStatementsOnly';

type
   (* "Is this command withdrawn?" -- uCFG.CommandIsRetired, passed in. See
     the header for why the leaf does not ask uCFG itself. *)
   TCommandTest = function(const aCommand: string): boolean;

(* Was this log's config table captured under the statements-only rule? *)
function LogHoldsStatementsOnly(aRepository: TLogRepository): boolean;

(* WRITE EACH STATED CONTEST-SCOPED SETTING, DELETE EVERY OTHER, AND MARK THE
  LOG. Returns how many rows were written. Does not commit -- the caller's
  capture is one transaction.

  AND DELETE EVERY CONTEST ROW NAMING A RETIRED COMMAND, when aIsRetired is
  given -- rows the model no longer names, so the walk over the model's
  commands can never reach them. See the header (M10 S2).

  CONTEST IS NEITHER WRITTEN NOR DELETED: it is the contest table's, never a
  config row's (see CaptureConfiguration). *)
function CaptureContestStatements(aSettings: TR4WSettings;
                                  aRepository: TLogRepository;
                                  aIsRetired: TCommandTest = nil): integer;

(* THE SAME RULE FOR ONE COMMAND -- written while stated, deleted otherwise.
  True when a row was written. Does not commit, and does NOT set the mark.

  WHY IT EXISTS: A CHANGE IS WRITTEN WHEN IT IS MADE (Q61, 2026-10-17). The
  whole capture runs at log creation and at a clean close, so a statement
  made mid-session -- CATEGORY-MODE in the Cabrillo summary window -- was in
  the log only if the program closed cleanly. uLogStore's
  LogStoreRecordContestStatement calls this the moment the window applies
  the value. CaptureContestStatements loops over it, so the two are one rule.

  NO MARK, DELIBERATELY. The mark says EVERY contest-scoped row is a
  statement, and a single write vouches for one row only: an old log's
  sentinels would become statements. Unmarked, the row is still read
  correctly -- a non-default row is a statement, and a default one is
  dropped as a sentinel, which leaves the setting at that same default. *)
function CaptureContestStatement(aSettings: TR4WSettings;
                                 aRepository: TLogRepository;
                                 const aCommand: string): boolean;

(* THE ENTRY DECLARATION, WRITTEN WHEN THE LOG IS MADE AND NEVER AGAIN --
  Q61's latent defect (1), found by the column audit 2026-10-16.

  uLogStore wrote it on EVERY open, against its own "READ ONCE, WHEN THE LOG
  IS MADE" comment, so a reopened log's declaration was today's values. It
  was also written BEFORE the new log's contest row existed, so for a new log
  the UPDATE landed on nothing and the first real write was the first reopen.

  aLogIsNew is True on the open that created the log, or that migrated it
  from a binary log (which carries no declaration). Anything else writes
  nothing. True when the declaration was written; False when aLogIsNew is
  False or there is no contest row yet. Does not commit. *)
function RecordEntryDeclaration(aRepository: TLogRepository;
                                aLogIsNew: boolean;
                                const aDeclaration: TLogEntryDeclaration): boolean;

(* THE STATION FACTS A CONTEST MAY OVERRIDE -- design 7.12. For every command
  naming one (MY STATE and its alias MY QTH, MY ZONE, MY GRID...): the open
  contest's override, as source 'contest', while it stated one; otherwise the
  STATION'S value, as source 'station' -- the record of the station config
  every station row has always been, which nothing applies.

  THAT IS 7.8's SHAPE FOR A STATION FACT: a 'contest' row is a statement and
  is applied on reopen (as the override again, never into the station); its
  absence means the station decides. A withdrawn override's row is not
  deleted but rewritten as 'station', because the station row is a record the
  log has always kept.

  Returns how many rows were written. Does not commit. *)
function CaptureStationFactRows(aSettings: TR4WSettings;
                                aRepository: TLogRepository): integer;

(* WHAT CaptureStationFactRows WRITES FOR ONE COMMAND -- the value and the
  source -- or False for a command that is not an overridable station fact.
  Separate so a test can ask what the log will hold without a database. *)
function StationFactRow(aSettings: TR4WSettings; const aCommand: string;
                        out aValue, aSource: string): boolean;

(* REMOVE FROM aRows (name=value pairs, as LoadContestConfig returns them) EVERY
  ROW THAT IS NOT AN OPERATOR STATEMENT, and add each removed command to
  aDropped when it is not nil.

  For a statements-only log every row is kept. For a log written before the
  rule, a contest-scoped row whose value equals the TR4WSettings constructor
  default is removed. A row that is not contest-scoped is always kept -- it is
  not this rule's to judge.

  EXCEPT A RETIRED COMMAND'S ROW, which is removed IN BOTH ERAS when
  aIsRetired is given, and added as name=value to aRetired when that is not
  nil -- the value included, so a real statement being set aside is visible
  and not only a placeholder (M10 S2). It goes to aRetired and NOT to
  aDropped: aDropped means "held the built-in default", which a retired
  statement need not. *)
procedure KeepOnlyStatements(aRows: TStrings; aStatementsOnly: boolean;
                             aDropped: TStrings;
                             aIsRetired: TCommandTest = nil;
                             aRetired: TStrings = nil);

implementation

uses
   SysUtils;

function LogHoldsStatementsOnly(aRepository: TLogRepository): boolean;
begin
   Result := (aRepository <> nil) and
             (aRepository.SessionValue(STATEMENTS_ONLY_KEY, '') = '1');
end;

function CaptureContestStatement(aSettings: TR4WSettings;
                                 aRepository: TLogRepository;
                                 const aCommand: string): boolean;
var
   value: string;
begin
   Result := False;
   if (aSettings = nil) or (aRepository = nil) or
      (aCommand = '') or
      (not aSettings.CommandIsContestScoped(aCommand)) or
      UnicodeSameText(aCommand, 'CONTEST') then
      begin
      Exit;
      end;

   (* A STATED VALUE THAT CANNOT BE WRITTEN DOWN IS DELETED, not kept: the
     renderer answers False only for a property kind it does not handle, and
     a stale row for it would be applied on reopen as though it were
     current. *)
   if aSettings.CommandIsStated(aCommand) and
      aSettings.TryGetByCommand(aCommand, value) then
      begin
      aRepository.SaveConfigValue(AnsiString(aCommand), AnsiString(value),
                                  AnsiString('contest'));
      Result := True;
      end
   else
      begin
      aRepository.DeleteConfigValue(AnsiString(aCommand));
      end;
end;

function RecordEntryDeclaration(aRepository: TLogRepository;
                                aLogIsNew: boolean;
                                const aDeclaration: TLogEntryDeclaration): boolean;
begin
   Result := False;
   if (aRepository = nil) or (not aLogIsNew) then
      begin
      Exit;
      end;
   Result := aRepository.SetEntryDeclaration(aDeclaration);
end;

function CaptureContestStatements(aSettings: TR4WSettings;
                                  aRepository: TLogRepository;
                                  aIsRetired: TCommandTest = nil): integer;
var
   names: TStringList;
   stored: TStringList;
   i: integer;
   cmd: string;
begin
   Result := 0;
   if (aSettings = nil) or (aRepository = nil) then
      begin
      Exit;
      end;

   names := aSettings.CommandNames;
   try
      for i := 0 to names.Count - 1 do
         begin
         cmd := string(names[i]);
         (* ONE COMMAND'S RULE, which skips a name that is not contest-scoped
           and CONTEST itself. *)
         if CaptureContestStatement(aSettings, aRepository, cmd) then
            begin
            Inc(Result);
            end;
         end;
   finally
      names.Free;
   end;

   (* THE RETIRED ROWS. Found from what the log HOLDS, because the model's
     command list above no longer names them. LoadContestConfig is the read
     the reopen makes, so what is deleted here is exactly what that read
     would otherwise set aside on every open. A 'station' row of a retired
     name is a record nothing applies, and is left alone like every other
     station row. *)
   if Assigned(aIsRetired) then
      begin
      stored := TStringList.Create;
      try
         aRepository.LoadContestConfig(stored);
         for i := 0 to stored.Count - 1 do
            begin
            cmd := string(stored.Names[i]);
            if (cmd <> '') and aIsRetired(cmd) then
               begin
               aRepository.DeleteConfigValue(AnsiString(cmd));
               end;
            end;
      finally
         stored.Free;
      end;
      end;

   aRepository.SaveSessionValue(AnsiString(STATEMENTS_ONLY_KEY), '1');
end;

function StationFactRow(aSettings: TR4WSettings; const aCommand: string;
                        out aValue, aSource: string): boolean;
begin
   aValue := '';
   aSource := '';
   Result := (aSettings <> nil) and
             aSettings.CommandIsContestOverridable(aCommand);
   if not Result then
      begin
      Exit;
      end;

   if aSettings.TryGetContestOverride(aCommand, aValue) then
      begin
      aSource := 'contest';
      end
   else
      begin
      (* The station's value, through the same renderer every station row
        uses. A fact is always renderable -- all are strings but MY ITU ZONE,
        an integer. *)
      if not aSettings.TryGetByCommand(aCommand, aValue) then
         begin
         aValue := '';
         end;
      aSource := 'station';
      end;
end;

function CaptureStationFactRows(aSettings: TR4WSettings;
                                aRepository: TLogRepository): integer;
var
   names: TStringList;
   i: integer;
   cmd: string;
   value: string;
   source: string;
begin
   Result := 0;
   if (aSettings = nil) or (aRepository = nil) then
      begin
      Exit;
      end;

   names := aSettings.CommandNames;
   try
      for i := 0 to names.Count - 1 do
         begin
         cmd := string(names[i]);
         if StationFactRow(aSettings, cmd, value, source) then
            begin
            aRepository.SaveConfigValue(AnsiString(cmd), AnsiString(value),
                                        AnsiString(source));
            Inc(Result);
            end;
         end;
   finally
      names.Free;
   end;
end;

procedure KeepOnlyStatements(aRows: TStrings; aStatementsOnly: boolean;
                             aDropped: TStrings;
                             aIsRetired: TCommandTest = nil;
                             aRetired: TStrings = nil);
var
   defaults: TR4WSettings;
   i: integer;
   cmd: string;
   stored: string;
   defaultValue: string;
begin
   if aRows = nil then
      begin
      Exit;
      end;

   (* RETIRED FIRST, AND WHATEVER THE LOG'S ERA: a statements-only log can
     hold a real statement of a setting that has since retired, and it is no
     more applicable than a sentinel. *)
   if Assigned(aIsRetired) then
      begin
      for i := aRows.Count - 1 downto 0 do
         begin
         cmd := string(aRows.Names[i]);
         if (cmd <> '') and aIsRetired(cmd) then
            begin
            if aRetired <> nil then
               begin
               aRetired.Add(aRows[i]);
               end;
            aRows.Delete(i);
            end;
         end;
      end;

   if aStatementsOnly then
      begin
      Exit;
      end;

   (* A FRESH OBJECT IS THE CONSTRUCTOR DEFAULT, by definition, and asking it
     keeps this unit from holding a second list of what the defaults are. It
     also answers which commands are contest-scoped, which does not depend on
     values. *)
   defaults := TR4WSettings.Create;
   try
      for i := aRows.Count - 1 downto 0 do
         begin
         cmd := string(aRows.Names[i]);
         if (cmd = '') or (not defaults.CommandIsContestScoped(cmd)) then
            begin
            Continue;
            end;

         stored := string(aRows.ValueFromIndex[i]);
         (* EXACT, NOT CASE-FOLDED: these rows were rendered by the same
           TryGetByCommand that renders the default, and a message template's
           case is part of its value. *)
         if defaults.TryGetByCommand(cmd, defaultValue) and (stored = defaultValue) then
            begin
            if aDropped <> nil then
               begin
               aDropped.Add(AnsiString(cmd));
               end;
            aRows.Delete(i);
            end;
         end;
   finally
      defaults.Free;
   end;
end;

end.

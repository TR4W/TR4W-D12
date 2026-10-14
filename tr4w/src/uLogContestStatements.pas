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

(* Was this log's config table captured under the statements-only rule? *)
function LogHoldsStatementsOnly(aRepository: TLogRepository): boolean;

(* WRITE EACH STATED CONTEST-SCOPED SETTING, DELETE EVERY OTHER, AND MARK THE
  LOG. Returns how many rows were written. Does not commit -- the caller's
  capture is one transaction.

  CONTEST IS NEITHER WRITTEN NOR DELETED: it is the contest table's, never a
  config row's (see CaptureConfiguration). *)
function CaptureContestStatements(aSettings: TR4WSettings;
                                  aRepository: TLogRepository): integer;

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
  not this rule's to judge. *)
procedure KeepOnlyStatements(aRows: TStrings; aStatementsOnly: boolean;
                             aDropped: TStrings);

implementation

uses
   SysUtils;

function LogHoldsStatementsOnly(aRepository: TLogRepository): boolean;
begin
   Result := (aRepository <> nil) and
             (aRepository.SessionValue(STATEMENTS_ONLY_KEY, '') = '1');
end;

function CaptureContestStatements(aSettings: TR4WSettings;
                                  aRepository: TLogRepository): integer;
var
   names: TStringList;
   i: integer;
   cmd: string;
   value: string;
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
         if (cmd = '') or
            (not aSettings.CommandIsContestScoped(cmd)) or
            UnicodeSameText(cmd, 'CONTEST') then
            begin
            Continue;
            end;

         (* A STATED VALUE THAT CANNOT BE WRITTEN DOWN IS DELETED, not kept:
           the renderer answers False only for a property kind it does not
           handle, and a stale row for it would be applied on reopen as
           though it were current. *)
         if aSettings.CommandIsStated(cmd) and
            aSettings.TryGetByCommand(cmd, value) then
            begin
            aRepository.SaveConfigValue(AnsiString(cmd), AnsiString(value),
                                        AnsiString('contest'));
            Inc(Result);
            end
         else
            begin
            aRepository.DeleteConfigValue(AnsiString(cmd));
            end;
         end;
   finally
      names.Free;
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
                             aDropped: TStrings);
var
   defaults: TR4WSettings;
   i: integer;
   cmd: string;
   stored: string;
   defaultValue: string;
begin
   if (aRows = nil) or aStatementsOnly then
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

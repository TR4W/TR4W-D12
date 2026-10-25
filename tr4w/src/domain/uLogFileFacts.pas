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

(* WHAT A CONTEST LOG FILE SAYS ABOUT ITSELF, READ WITHOUT ADOPTING IT.

  WHY IT EXISTS. NY4I, 2026-10-19, on the New Contest dialog's "Last Contest"
  button: "it is not clear what contest is in the latest button. We need to
  make the contest and year more obvious." The button showed the file's PATH,
  elided from the middle, so the contest and the year were exactly what got
  cut. The log already knows both -- its one-row contest table -- so the
  dialog asks the log, not the file name.

  A PEEK, NOT AN OPEN. The file is opened through TLogDatabase.OpenToPeek
  (immutable, or read-only through a sidecar beside it; SQLITE_OPEN_READONLY
  either way, no journal_mode, no MigrateSchema), read, and closed before this
  returns, so:
    - a schema-2 log is NOT upgraded to 3 because a dialog looked at it;
    - no lock is held once the answer is in hand;
    - nothing beside the file is left behind (pinned by a test).

  NEVER RAISES. A missing file, an old .cfg, somebody else's database, a
  locked or damaged one -- each answers nil with the reason in aWhy, and the
  caller decides what to show and what to log. ClassifyContestFile is asked
  FIRST, by the bytes, so a .cfg never reaches SQLite at all.

  A LEAF OF THE LOG LAYER: no registry, no logger, no LCL. Turning the stored
  token into a display name is the caller's business (uLatestContest). *)
unit uLogFileFacts;

{$I ..\tr4w.inc}

interface

type
   (* THE CONTEST ROW'S FACTS, as stored. Times are UTC TDateTimes, 0 when the
     log records none -- never 1 January 1970. *)
   TLogFileFacts = class
   private
      FContestToken: string;
      FContestName: string;
      FMyCall: string;
      FStartTime: TDateTime;
      FFirstQSOTime: TDateTime;
      FCreatedAt: TDateTime;
      FLastQSOTime: TDateTime;
      FQSOCount: integer;
   public
      (* THE YEAR THIS LOG'S CONTEST WAS RUN, or 0 when nothing says.

        start_time first -- what the log declares (uContestBase.LogContestYear
        asks it first too). Then the EARLIEST QSO, which is LogContestYear's
        own fallback, and the one that matters: nothing writes start_time yet,
        and an imported log's created_at is the day it was IMPORTED, so a 2024
        CQ WW imported in 2026 would otherwise read 2026. created_at last, for
        a log with no QSOs at all. *)
      function ContestYear: integer;

      (* contest_type: the registry id the log was written under. *)
      property ContestToken: string read FContestToken;
      (* contest_name: the friendly name the log was written with. *)
      property ContestName: string read FContestName;
      (* my_call: the entry's declared call; often '' (see SetContest). *)
      property MyCall: string read FMyCall;
      property StartTime: TDateTime read FStartTime;
      property FirstQSOTime: TDateTime read FFirstQSOTime;
      property CreatedAt: TDateTime read FCreatedAt;
      (* THE NEWEST QSO and HOW MANY -- NY4I, 2026-10-24: the New Contest
        dialog's grid lists them so two logs of one contest can be told apart
        (a file name carries the day the log was CREATED, not operated).

        A QSO here is a record_kind 'QSO' row that is neither deleted nor
        skipped -- the reader folds is_skipped into ceQSO_Deleted. Notes and
        QTC traffic are not QSOs; dupes and X-QSOs are, since they are rows
        of the log. LastQSOTime is 0 and QSOCount 0 for a log with none. *)
      property LastQSOTime: TDateTime read FLastQSOTime;
      property QSOCount: integer read FQSOCount;
   end;

(* THE FACTS OF THE LOG AT aFileName, or nil with aWhy saying why not. The
  caller owns the result. Never raises. *)
function ReadLogFileFacts(const aFileName: string; out aWhy: string): TLogFileFacts;

implementation

uses
   SysUtils, DateUtils, db, sqldb,
   uContestFileKind,
   uLogDatabase;

(* A unix-seconds column, NULL or not positive meaning "not recorded". *)
function UnixColumn(aField: TField): TDateTime;
begin
   Result := 0;
   if (not aField.IsNull) and
      (aField.AsLargeInt > 0) then
      begin
      Result := UnixToDateTime(aField.AsLargeInt);
      end;
end;

function TLogFileFacts.ContestYear: integer;
begin
   Result := 0;
   if FStartTime > 0 then
      begin
      Result := YearOf(FStartTime);
      end
   else if FFirstQSOTime > 0 then
      begin
      Result := YearOf(FFirstQSOTime);
      end
   else if FCreatedAt > 0 then
      begin
      Result := YearOf(FCreatedAt);
      end;
end;

(* The three reads, on an open read-only connection. False with aWhy when the
  log has no contest row. *)
function ReadFacts(aDatabase: TLogDatabase; aFacts: TLogFileFacts;
                   out aWhy: string): boolean;
var
   q: TSQLQuery;
begin
   Result := False;
   aWhy := '';
   q := TSQLQuery.Create(nil);
   try
      q.DataBase := aDatabase.Connection;
      q.Transaction := aDatabase.Transaction;
      (* As TLogRepository.NewReadQuery does: sqldb's default runs three
        PRAGMAs per Open for key metadata nothing here uses. *)
      q.UsePrimaryKeyAsKey := False;

      q.SQL.Text := 'SELECT contest_type, contest_name, my_call, start_time, ' +
                    'created_at FROM contest WHERE id = 1';
      q.Open;
      if q.EOF then
         begin
         aWhy := 'the log has no contest row';
         q.Close;
         Exit;
         end;
      aFacts.FContestToken := Trim(q.Fields[0].AsString);
      aFacts.FContestName  := Trim(q.Fields[1].AsString);
      aFacts.FMyCall       := Trim(q.Fields[2].AsString);
      aFacts.FStartTime    := UnixColumn(q.Fields[3]);
      aFacts.FCreatedAt    := UnixColumn(q.Fields[4]);
      q.Close;

      (* ONE INDEX PROBE, not a scan: idx_qso_at serves a MIN. *)
      q.SQL.Text := 'SELECT MIN(qso_at) FROM qso WHERE qso_at > 0';
      q.Open;
      if not q.EOF then
         begin
         aFacts.FFirstQSOTime := UnixColumn(q.Fields[0]);
         end;
      q.Close;

      (* THE COUNT AND THE NEWEST, IN ONE PASS -- and NOT INDEXED on purpose.

        A peeked log is read-only, so it has no ANALYZE statistics, and the
        planner then picks the partial index idx_qso_dupe (WHERE deleted = 0)
        and looks every row up in the table through it. Measured 2026-10-24
        on a 19,740-row log: 52 ms that way, 8.7 ms as a plain table scan;
        ORDER BY qso_at DESC LIMIT 1 fell into the same index and was no
        better. A 101-row log is 0.4 ms either way. Stated rather than left
        to a planner whose choice depends on statistics this read cannot
        write. *)
      q.SQL.Text := 'SELECT COUNT(*), MAX(qso_at) FROM qso NOT INDEXED ' +
                    'WHERE record_kind = ''QSO'' AND deleted = 0 ' +
                    'AND is_skipped = 0';
      q.Open;
      if not q.EOF then
         begin
         aFacts.FQSOCount := q.Fields[0].AsInteger;
         aFacts.FLastQSOTime := UnixColumn(q.Fields[1]);
         end;
      q.Close;

      Result := True;
   finally
      q.Free;
   end;
end;

function ReadLogFileFacts(const aFileName: string; out aWhy: string): TLogFileFacts;
var
   log: TLogDatabase;
   facts: TLogFileFacts;
begin
   Result := nil;
   aWhy := '';

   case ClassifyContestFile(aFileName) of
      cfkTR4WDatabase:
         begin
         (* the only kind worth opening *)
         end;
      cfkMissing:
         begin
         aWhy := 'no such file';
         Exit;
         end;
      cfkForeignDatabase:
         begin
         aWhy := 'a database that is not a TR4W log';
         Exit;
         end;
      cfkTextConfig:
         begin
         aWhy := 'a text configuration file, not a log';
         Exit;
         end;
      else
         begin
         aWhy := 'not a contest log';
         Exit;
         end;
   end;

   facts := TLogFileFacts.Create;
   try
      log := TLogDatabase.Create;
      try
         try
            (* Immutable when nothing is beside the file, else through its
              WAL or journal -- the choice, and the window it leaves, are
              TLogDatabase.OpenToPeek's. *)
            log.OpenToPeek(aFileName);
            if ReadFacts(log, facts, aWhy) then
               begin
               Result := facts;
               facts := nil;
               end;
         except
            on E: Exception do
               begin
               aWhy := E.ClassName + ': ' + E.Message;
               end;
         end;
      finally
         (* The destructor closes: no connection and no lock outlive this. *)
         log.Free;
      end;
   finally
      facts.Free;
   end;
end;

end.

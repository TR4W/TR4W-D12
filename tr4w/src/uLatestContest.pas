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

(* WHAT THE NEW CONTEST DIALOG'S "LAST CONTEST" BUTTON SAYS.

  NY4I, 2026-10-19: "Because of the length of the name, it is not clear what
  contest is in the latest button. We need to make the contest and year more
  obvious." The button was its label and the file's full path, elided from the
  middle -- so the contest and year, which live in the file NAME the operator
  happened to choose, were the part that got cut.

  THREE LINES NOW, each from the LOG rather than the path:

      Last Contest, Alt+A:                   the label (the caller's)
      CQ Worldwide DX Contest, SSB 2026      the contest's display name + year
      NY4I - cqww ssb 2026.db                the call, if declared, + file name

  and the full path goes in the hint, always.

  THE SAME DESCRIPTION FILLS THE DIALOG'S EXISTING-LOG GRID (NY4I,
  2026-10-19): one TLatestContest per listed file, its ContestName, Year,
  Call, LastQSOTime and QSOCount (2026-10-24) in the columns. One reader and one name/year rule for the button and
  the grid -- a second would drift from this one.

  WHEN THE LOG CANNOT SAY -- a missing file, an old .cfg, a damaged or foreign
  database -- the button reads exactly as it did before (the label and the
  lower-cased path), and Why says why for the caller's debug log.

  THE FITTING IS HERE TOO, AND HAS NO LCL. The form supplies a measurement (a
  TLatestCaptionFits); FitLatestCaption decides what to give up, in order, so
  the unit tests can pin that order with a fake measurer:

      1. shorten the FILE line from its middle (as the path always was);
      2. drop the file line altogether -- it is the one line of less import;
      3. only then shorten the contest name from its END, KEEPING THE YEAR.

  The label is never touched: it is the one part that says what the button
  does. *)
unit uLatestContest;

{$I tr4w.inc}

interface

uses
   Generics.Collections;   (* TObjectList -- the dialog's described files, owned *)

type
   (* What the last contest's log says about itself, ready to show. *)
   TLatestContest = class
   private
      FFileName: string;
      FDescribed: boolean;
      FContestName: string;
      FYear: integer;
      FCall: string;
      FLastQSOTime: TDateTime;
      FQSOCount: integer;
      FDetail: string;
      FWhy: string;
      procedure Describe(const aContestName: string; aYear: integer;
                         const aCall: string; aLastQSOTime: TDateTime;
                         aQSOCount: integer);
   public
      (* Reads the log at aFileName (uLogFileFacts) and resolves its contest
        through the registry. Never raises. *)
      constructor Create(const aFileName: string);

      (* A DESCRIBED last contest from facts already in hand -- what Create
        builds once the log has answered, and how a test states one without a
        file. *)
      constructor CreateFor(const aFileName, aContestName: string;
                            aYear: integer; const aCall: string;
                            aLastQSOTime: TDateTime = 0; aQSOCount: integer = 0);

      (* The full path -- the button's hint. *)
      property FileName: string read FFileName;
      (* True when the log answered; False is the old two-line caption. *)
      property Described: boolean read FDescribed;
      (* The registry's DisplayName for the log's contest; the log's own
        stored name, or its token, when the registry does not know it. *)
      property ContestName: string read FContestName;
      (* 0 when nothing in the log dates it. *)
      property Year: integer read FYear;
      (* The entry's declared callsign; '' when the log declares none or
        cannot describe itself. *)
      property Call: string read FCall;
      (* The newest QSO's UTC time, 0 when the log has none or cannot
        describe itself (uLogFileFacts.LastQSOTime says what a QSO is). *)
      property LastQSOTime: TDateTime read FLastQSOTime;
      (* How many QSOs the log holds; 0 when none or not Described. *)
      property QSOCount: integer read FQSOCount;
      (* The last line: call + file name, or the lower-cased path when not
        Described. *)
      property Detail: string read FDetail;
      (* Why the log could not describe itself; '' when it could. *)
      property Why: string read FWhy;
   end;

   (* DOES THIS CAPTION FIT THE BUTTON? Supplied by the form, which alone can
     measure. *)
   TLatestCaptionFits = function(const aCaption: string): boolean of object;

   (* The New Contest dialog's files, each described -- owned by the list. *)
   TContestFileList = TObjectList<TLatestContest>;

(* THE ORDER THE NEW CONTEST DIALOG LISTS LOGS IN -- NY4I, 2026-10-19, and
  2026-10-24.

  THE NEWEST LAST QSO FIRST, since 2026-10-24. NY4I opened
  "CQ-WW-SSB 2026-10-19 NY4I.db" for a contest operated on 10-24 and could not
  tell his logs apart: the file name carries the day the log was CREATED, and
  year-then-contest put every CQ WW 2026 log side by side in file-name order.
  The log knows when it was last worked, so that decides.

      1. logs with QSOs, the newest last QSO first;
      2. logs with none, the NEWEST YEAR first (a log with no year after every
         dated one), then the contest's name, then the file name -- the
         2026-10-19 order, unchanged;
      3. files that cannot describe themselves -- an old .cfg, a damaged or
         foreign database -- by file name.

  A tie in 1 falls through to 2's keys. File names compare without case; the
  full path breaks a remaining tie, so the order is total.

  Negative when aLeft lists first. *)
function CompareContestFiles(constref aLeft, aRight: TLatestContest): integer;

(* aFiles in CompareContestFiles' order. *)
procedure SortContestFiles(aFiles: TContestFileList);

(* The contest line: "<name> <year>", or the bare name when aYear is 0. *)
function LatestContestLine(const aName: string; aYear: integer): string;

(* THE GRID'S LAST QSO CELL: "2026-10-24 2318z", UTC, or '' for 0. ISO date
  and the log's HHMM time, so it reads the same in every language. *)
function LatestContestLastQSOText(aWhen: TDateTime): string;

(* The detail line: "<call> - <file name>", or the bare name with no call. *)
function LatestContestDetail(const aCall, aFileName: string): string;

(* The contest's display name for a stored token -- the registry's, else the
  log's stored name, else the token itself. *)
function LatestContestDisplayName(const aToken, aStoredName: string): string;

(* THE CAPTION, cut down until aFits says it fits -- see the unit header for
  the order. Lines are joined with #13#10. Gives up at a floor and returns the
  shortest form it reached; the caller clamps the height. *)
function FitLatestCaption(const aLabel: string; aLatest: TLatestContest;
                          aFits: TLatestCaptionFits): string;

implementation

uses
   SysUtils,
   Generics.Defaults,  (* TComparer -- SortContestFiles *)
   VC,
   uContestNames,      (* TryContestFromName -- current ids and legacy names *)
   uContestRegistry,   (* ContestIdentity -- the display name *)
   uLogFileFacts,      (* ReadLogFileFacts -- the log, read without adopting it *)
   uAppStrings;        (* SLatestContestLine, SLatestContestDetail *)

const
   ELLIPSIS = '...';
   (* A shortened file line keeps at least this much on each side of the dots. *)
   DETAIL_FLOOR = Length(ELLIPSIS) + 8;
   (* A shortened contest name keeps at least this many characters. *)
   NAME_FLOOR = 4;

function LatestContestLine(const aName: string; aYear: integer): string;
begin
   if aYear > 0 then
      begin
      Result := Format(SLatestContestLine, [aName, aYear]);
      end
   else
      begin
      Result := aName;
      end;
end;

function LatestContestLastQSOText(aWhen: TDateTime): string;
begin
   Result := '';
   if aWhen > 0 then
      begin
      (* The "z" QUOTED: a bare z in FormatDateTime is milliseconds. *)
      Result := FormatDateTime('yyyy-mm-dd hhnn"z"', aWhen);
      end;
end;

function LatestContestDetail(const aCall, aFileName: string): string;
begin
   if aCall <> '' then
      begin
      Result := Format(SLatestContestDetail, [aCall, aFileName]);
      end
   else
      begin
      Result := aFileName;
      end;
end;

function LatestContestDisplayName(const aToken, aStoredName: string): string;
var
   contest: TContestHandle;
begin
   if TryContestFromName(aToken, contest) then
      begin
      Result := ContestIdentity(contest).DisplayName;
      end
   else if aStoredName <> '' then
      begin
      Result := aStoredName;
      end
   else
      begin
      Result := aToken;
      end;
end;

function CompareContestFiles(constref aLeft, aRight: TLatestContest): integer;
begin
   (* Described first. *)
   if aLeft.Described <> aRight.Described then
      begin
      if aLeft.Described then
         begin
         Result := -1;
         end
      else
         begin
         Result := 1;
         end;
      Exit;
      end;

   Result := 0;
   if aLeft.Described then
      begin
      (* The newest last QSO first; 0 (no QSO) is below every real time, so
        a log with none lists after every log with one. *)
      if aLeft.LastQSOTime > aRight.LastQSOTime then
         begin
         Result := -1;
         end
      else if aLeft.LastQSOTime < aRight.LastQSOTime then
         begin
         Result := 1;
         end
      (* Newest year first; 0 (no year) is below every real year, so last. *)
      else if aLeft.Year > aRight.Year then
         begin
         Result := -1;
         end
      else if aLeft.Year < aRight.Year then
         begin
         Result := 1;
         end
      else
         begin
         Result := UnicodeCompareText(aLeft.ContestName, aRight.ContestName);
         end;
      end;

   if Result = 0 then
      begin
      Result := UnicodeCompareText(ExtractFileName(aLeft.FileName),
                                   ExtractFileName(aRight.FileName));
      end;
   if Result = 0 then
      begin
      Result := UnicodeCompareStr(aLeft.FileName, aRight.FileName);
      end;
end;

procedure SortContestFiles(aFiles: TContestFileList);
begin
   aFiles.Sort(TComparer<TLatestContest>.Construct(CompareContestFiles));
end;

constructor TLatestContest.Create(const aFileName: string);
var
   facts: TLogFileFacts;
   why: string;
   name: string;
begin
   inherited Create;
   FFileName := aFileName;
   (* THE OLD CAPTION, until the log says otherwise. Lower-cased as it always
     was. *)
   FDetail := LowerCase(aFileName);

   facts := ReadLogFileFacts(aFileName, why);
   if facts = nil then
      begin
      FWhy := why;
      Exit;
      end;
   try
      name := LatestContestDisplayName(facts.ContestToken, facts.ContestName);
      if name = '' then
         begin
         FWhy := 'the contest row names no contest';
         Exit;
         end;
      Describe(name, facts.ContestYear, facts.MyCall, facts.LastQSOTime,
               facts.QSOCount);
   finally
      facts.Free;
   end;
end;

constructor TLatestContest.CreateFor(const aFileName, aContestName: string;
                                     aYear: integer; const aCall: string;
                                     aLastQSOTime: TDateTime; aQSOCount: integer);
begin
   inherited Create;
   FFileName := aFileName;
   Describe(aContestName, aYear, aCall, aLastQSOTime, aQSOCount);
end;

procedure TLatestContest.Describe(const aContestName: string; aYear: integer;
                                  const aCall: string; aLastQSOTime: TDateTime;
                                  aQSOCount: integer);
begin
   FContestName := aContestName;
   FYear := aYear;
   FCall := aCall;
   FLastQSOTime := aLastQSOTime;
   FQSOCount := aQSOCount;
   FDetail := LatestContestDetail(aCall, ExtractFileName(FFileName));
   FDescribed := True;
   FWhy := '';
end;

(* The detail cut from its MIDDLE to aKeep characters, as the path always was:
  the start and the end (the extension, the date) identify a name. *)
function ElideMiddle(const aText: string; aKeep: integer): string;
begin
   Result := Copy(aText, 1, aKeep div 2) + ELLIPSIS +
             Copy(aText, Length(aText) - (aKeep - aKeep div 2) + 1, MaxInt);
end;

function FitLatestCaption(const aLabel: string; aLatest: TLatestContest;
                          aFits: TLatestCaptionFits): string;
var
   head, contestLine, detail: string;
   keep: integer;
begin
   head := aLabel;
   if aLatest.Described then
      begin
      contestLine := LatestContestLine(aLatest.ContestName, aLatest.Year);
      head := head + #13#10 + contestLine;
      end;

   (* 1. The file line, shortened from its middle -- halved each pass, so a
     handful of passes on any real name. *)
   detail := aLatest.Detail;
   Result := head + #13#10 + detail;
   keep := Length(detail);
   while (not aFits(Result)) and
         (keep > DETAIL_FLOOR) do
      begin
      keep := keep div 2;
      Result := head + #13#10 + ElideMiddle(detail, keep);
      end;

   if aFits(Result) or
      (not aLatest.Described) then
      begin
      (* Without a contest line the path IS the content: never dropped. *)
      Exit;
      end;

   (* 2. No file line at all. *)
   Result := head;
   if aFits(Result) then
      begin
      Exit;
      end;

   (* 3. The contest name from its END, one character at a time -- a name is
     a few dozen characters, and the last fitting length is the one wanted.
     The year is never cut. *)
   keep := Length(aLatest.ContestName);
   while (not aFits(Result)) and
         (keep > NAME_FLOOR) do
      begin
      dec(keep);
      Result := aLabel + #13#10 +
                LatestContestLine(TrimRight(Copy(aLatest.ContestName, 1, keep)) + ELLIPSIS,
                                  aLatest.Year);
      end;
end;

end.

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

(* THE CONTESTS THE NEW CONTEST DIALOG OFFERS, IN THE ORDER IT OFFERS THEM --
  milestone M9b, 2026-10-02 (docs/CONTEST_OWNERSHIP_DESIGN.md section 8.2n).

  NY4I: "i would like the display name in the drop down", and "inactive
  contests go at the bottom of the drop down". So each entry is a contest and
  the words that name it, and both come from the contest: its DisplayName and
  its IsActive (TContestBase). This unit decides only the ORDER and the
  marking, which are the dialog's.

  THE IDENTITY IS A CONTEST HANDLE (VC.TContestHandle, Q108 S2), HELD
  BESIDE THE CAPTION -- never recovered from the caption, and never carried
  in a combo's Objects[]. The token that is persisted (the CONTEST command,
  the log's file name) is still that contest's id
  (uContestRegistry.ContestId), so choosing by display name changes nothing
  that is written. Two contests with one display name would be one line an
  operator could not tell apart; uTestContestChoices fails if that happens.

  THE ORDER (DECIDED): every active contest, then every inactive one; within
  each, by display name, case-insensitively in the platform's collation
  (UnicodeCompareText -- what a sorted LCL list would use too); a tie by the
  handle's order (the legacy number), so the list is the same on every run. The Win32 combo sorted by the enum's spelling
  (CBS_SORT), which put 'ARRL-10' beside 'ARRL-160' and every QSO party under
  its state's code; sorting by what the operator reads is the only order that
  helps them find it.

  A SHARED DISPLAY NAME IS TOLD APART BY THE TOKEN (DECIDED). Two contests
  can carry one display name; each such line adds its token in brackets
  ('<name> [TOKEN]'), and a unique name is shown bare. Brackets, not words,
  so nothing needs translating. The one pair there was -- WRTC, whose row
  gave it the friendly name 'IARU HF World Championship', the event it runs
  inside, and IARU-HF -- ended when WRTC took a name of its own, 'World
  Radiosport Team Championship' (NY4I, 2026-10-16, design Q58). So no pair
  shares a name today; the rule stays for any future pair, and
  uTestContestUI's ratchet fails if one appears.

  THE MARK (DECIDED): an inactive contest's caption is SContestInactive --
  '%s (inactive)' -- a resourcestring, so a translation reaches it. The
  display names themselves are NOT translated: they are the sponsors' proper
  names, and the same names feed the summary sheet's CONTEST: line and the
  log database's friendly name, where a translation would change the output.

  HIDDEN UNLESS ASKED FOR (DECIDED, Q59, NY4I 2026-10-19: "hide inactive
  contests"). A native list cannot grey one row, so the dialog lists the
  inactive contests only when its "Show inactive contests" box is ticked
  (Matching's aIncludeInactive), and even then one cannot be chosen for a NEW
  contest (ContestCanStartNew). The list itself still holds every contest, so
  the order and the marks above are unchanged.

  UPCOMING CONTESTS FIRST (DECIDED, NY4I 2026-11-16: "show me the contests
  coming up soonest"; contests with no date "sort alphabetically at the
  end"). A SECOND ORDER over the same entries, built once with the list from
  ONE "now" (SoonestFirstOrder): a contest on the air first, then by the start
  of its next period, then every undated contest in the alphabetical order
  above -- a contest that states no schedule (''), says 'unscheduled', has
  run out of dates, or states one that does not parse. An inactive contest is
  never dated, so it stays last. Each dated entry carries a HINT, the date it
  was ordered by (ContestDateHint); it is display only and never part of the
  caption, so the search still matches the name and nothing reads it back.

  NO FORM, NO LCL, so the unit tests build the same list the dialog shows. *)
unit uContestChoices;

{$I tr4w.inc}

interface

uses
   VC;

type
   (* Positions in a TContestChoices, in its order. *)
   TContestChoiceIndexes = array of integer;

   (* One text per position. Not SysUtils' TStringArray: that is declared
      in an ObjFPC unit, where string is AnsiString. *)
   TContestChoiceTexts = array of string;

   TContestChoices = class
   private
      FContests: array of TContestHandle;
      FCaptions: array of string;
      (* THE UPCOMING-FIRST ORDER (positions) and, per position, its date
         hint and the reason its schedule did not parse ('' when it did, or
         when there was nothing to parse) -- SoonestFirstOrder's answer. *)
      FSoonest: TContestChoiceIndexes;
      FHints: TContestChoiceTexts;
      FScheduleErrors: TContestChoiceTexts;
      function GetCount: integer;
      function GetContest(aIndex: integer): TContestHandle;
      function GetCaption(aIndex: integer): string;
      function GetHint(aIndex: integer): string;
      function GetScheduleError(aIndex: integer): string;
   public
      (* Builds the whole list, in order, from the contest registry; the
         upcoming-first order is resolved against uSpotAge.UTCNow, read once. *)
      constructor Create; overload;
      (* The same, against aNowUTC -- for a test that needs a fixed "now". *)
      constructor Create(const aNowUTC: TDateTime); overload;

      (* Where a contest sits in the list, or -1. *)
      function IndexOf(aContest: TContestHandle): integer;

      (* THE ROW TEXT: the caption, plus the date hint when aWithHint and
         the entry has one (ContestChoiceDisplay). *)
      function DisplayText(aIndex: integer; aWithHint: boolean): string;

      (* THE LINES A SEARCH KEEPS, in the list's own order -- Q103. Each
         position whose Caption ContestChoiceMatches aFilter; every position
         when the filter is empty.

         AN INACTIVE CONTEST IS KEPT ONLY WHEN aIncludeInactive -- Q59, NY4I
         2026-10-19: "hide inactive contests". The New Contest dialog passes
         its "Show inactive contests" box; ticked, the inactive lines are kept
         too, still last (the list's order) and still subject to aFilter. *)
      (* aSoonestFirst: the kept positions in the upcoming-first order
         instead of the alphabetical one; what is kept does not change. *)
      function Matching(const aFilter: string;
                        aIncludeInactive: boolean;
                        aSoonestFirst: boolean = False): TContestChoiceIndexes;

      property Count: integer read GetCount;
      property Contest[aIndex: integer]: TContestHandle read GetContest;
      property Caption[aIndex: integer]: string read GetCaption;
      (* '' for an undated entry. *)
      property Hint[aIndex: integer]: string read GetHint;
      (* Why the entry's stated schedule did not parse; '' when it did, or
         when it states none. The dialog logs each once per build. *)
      property ScheduleError[aIndex: integer]: string read GetScheduleError;
   end;

(* THE UPCOMING-FIRST ORDER -- pure, the rule TContestChoices applies.

  aSchedules[i] is entry i's schedule string, in the list's alphabetical
  order; aEligible[i] False never dates it (an inactive contest). Every
  string is parsed ONCE and resolved against aNowUTC (uContestSchedule).
  The answer is a permutation of 0..n-1: dated entries by their key -- a
  running one's key is aNowUTC, so it is first -- then every undated entry in
  its input order (uContestDates.SortContestDates, stable). aHints[i] is
  ContestDateHint for a dated entry and '' otherwise. aErrors[i] names the
  parse failure of a stated schedule that does not parse (such an entry is
  undated); '' (nothing stated yet) and 'unscheduled' are not errors. *)
function SoonestFirstOrder(const aSchedules: array of string;
                           const aEligible: array of boolean;
                           const aNowUTC: TDateTime;
                           out aHints: TContestChoiceTexts;
                           out aErrors: TContestChoiceTexts): TContestChoiceIndexes;

(* THE HINT FOR A DATED ENTRY: SNewContestRunningNow when aRunning, else the
  start as 'YYYY-MM-DD HH:MM UTC', or 'YYYY-MM-DD' for a date-only clause.
  ISO, built from the numbers, so it reads the same in every locale and
  needs no translation (FormatDateTime would take ':' as the locale's time
  separator). *)
function ContestDateHint(const aStartUTC: TDateTime;
                         aRunning, aTimed: boolean): string;

(* A ROW'S TEXT: aCaption, then the hint in brackets when there is one. *)
function ContestChoiceDisplay(const aCaption, aHint: string): string;

(* ONE CONTEST'S LINE: its display name -- with its token in brackets when
  another contest shares that name -- marked when it is inactive. *)
function ContestChoiceCaption(aContest: TContestHandle): string;

(* DOES THIS LINE SURVIVE THE SEARCH? -- Q103, NY4I 2026-10-16: "search".

  True when aFilter, trimmed, occurs ANYWHERE in aCaption, ignoring case; an
  empty (or all-blank) filter keeps every line, which is the unfiltered,
  alphabetical list. So "qso" keeps every QSO party, and "sprint" every
  sprint.

  IT MATCHES THE CAPTION, the words the operator is reading: the display name,
  plus the inactive mark when there is one. A row never shows the contest's
  internal id (NY4I: "let's leave out the internal name"), so the search
  cannot find a contest by it either -- a search for words that are not on the
  screen would answer with lines that do not appear to match. *)
function ContestChoiceMatches(const aCaption, aFilter: string): boolean;

(* CAN A NEW CONTEST BE STARTED AS THIS ONE? -- Q59, NY4I 2026-10-16: "I see
  no reason anyone would ever select it." False for an inactive contest, and
  for NoContest.

  THE NEW CONTEST LIST ONLY. An existing log of an inactive contest still
  opens, rescores, exports and imports; nothing else asks this. An inactive
  contest is listed at all only so the transition shows the port kept it. *)
function ContestCanStartNew(aContest: TContestHandle): boolean;

implementation

uses
   SysUtils,
   DateUtils,          (* DecodeDateTime -- the hint's numbers *)
   uSpotAge,           (* UTCNow -- the one "now" a list is built against *)
   uContestDates,      (* SortContestDates, TContestDateEntries *)
   uContestSchedule,   (* TryParseContestSchedule, TryScheduleNextPeriod *)
   uContestBase,
   uContestRegistry,   (* ContestIdentity -- the display name and the flag;
                          KnownContests, ContestId -- the set and the token *)
   uAppStrings;        (* SContestInactive *)

(* DOES ANOTHER OFFERED CONTEST CARRY THIS DISPLAY NAME? *)
function DisplayNameIsShared(aContest: TContestHandle): boolean;
var
   known: TContestHandleList;
   k: integer;
   c: TContestHandle;
   name: string;
begin
   Result := False;
   name := ContestIdentity(aContest).DisplayName;
   known := KnownContests;
   for k := 0 to High(known) do
      begin
      c := known[k];
      if c = NoContest then
         begin
         Continue;
         end;
      (* UnicodeSameText, NOT SameText: SysUtils' plain name takes AnsiString
         and this unit's string is UnicodeString. *)
      if (c <> aContest) and
         UnicodeSameText(ContestIdentity(c).DisplayName, name) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function ContestChoiceCaption(aContest: TContestHandle): string;
var
   identity: TContestBase;
   name: string;
begin
   identity := ContestIdentity(aContest);
   name := identity.DisplayName;
   if DisplayNameIsShared(aContest) then
      begin
      name := name + ' [' + ContestId(aContest) + ']';
      end;

   if identity.IsActive then
      begin
      Result := name;
      end
   else
      begin
      Result := Format(SContestInactive, [name]);
      end;
end;

(* DOES a COME BEFORE b? Active first, then the display name, then the
  handle -- the legacy number, the enum order this used. *)
function ComesBefore(a, b: TContestHandle): boolean;
var
   ia, ib: TContestBase;
   byName: integer;
begin
   ia := ContestIdentity(a);
   ib := ContestIdentity(b);
   if ia.IsActive <> ib.IsActive then
      begin
      Result := ia.IsActive;
      Exit;
      end;

   (* UnicodeCompareText -- see DisplayNameIsShared on the plain name. *)
   byName := UnicodeCompareText(ia.DisplayName, ib.DisplayName);
   if byName <> 0 then
      begin
      Result := byName < 0;
      Exit;
      end;

   Result := a.ToByte < b.ToByte;
end;

function ContestDateHint(const aStartUTC: TDateTime;
                         aRunning, aTimed: boolean): string;
var
   year, month, day, hour, minute, second, ms: word;
begin
   if aRunning then
      begin
      Result := SNewContestRunningNow;
      Exit;
      end;
   DecodeDateTime(aStartUTC, year, month, day, hour, minute, second, ms);
   Result := UnicodeFormat('%.4d-%.2d-%.2d', [year, month, day]);
   if aTimed then
      begin
      Result := Result + UnicodeFormat(' %.2d:%.2d UTC', [hour, minute]);
      end;
end;

function ContestChoiceDisplay(const aCaption, aHint: string): string;
begin
   if aHint = '' then
      begin
      Result := aCaption;
      end
   else
      begin
      Result := aCaption + '   (' + aHint + ')';
      end;
end;

function SoonestFirstOrder(const aSchedules: array of string;
                           const aEligible: array of boolean;
                           const aNowUTC: TDateTime;
                           out aHints: TContestChoiceTexts;
                           out aErrors: TContestChoiceTexts): TContestChoiceIndexes;
var
   entries: TContestDateEntries;
   schedule: TContestSchedule;
   startUTC: TDateTime;
   running, timed: boolean;
   parseError: string;
   n, i: integer;
begin
   n := Length(aSchedules);
   aHints := nil;
   aErrors := nil;
   entries := nil;
   Result := nil;
   SetLength(aHints, n);
   SetLength(aErrors, n);
   SetLength(entries, n);
   SetLength(Result, n);

   for i := 0 to n - 1 do
      begin
      aHints[i] := '';
      aErrors[i] := '';
      entries[i].Tag := i;
      entries[i].HasDate := False;
      entries[i].DateUTC := 0;

      (* NOTHING STATED IS NOT AN ERROR: most contests are still waiting for
         their schedule, and a warning for each would bury a real one. *)
      if (i > High(aEligible)) or
         (not aEligible[i]) or
         (Trim(aSchedules[i]) = '') then
         begin
         Continue;
         end;

      if not TryParseContestSchedule(aSchedules[i], schedule, parseError) then
         begin
         aErrors[i] := parseError;
         Continue;
         end;

      if TryScheduleNextPeriod(schedule, aNowUTC, startUTC, running, timed) then
         begin
         entries[i].HasDate := True;
         if running then
            begin
            entries[i].DateUTC := aNowUTC;
            end
         else
            begin
            entries[i].DateUTC := startUTC;
            end;
         aHints[i] := ContestDateHint(startUTC, running, timed);
         end;
      end;

   SortContestDates(entries);
   for i := 0 to n - 1 do
      begin
      Result[i] := entries[i].Tag;
      end;
end;

constructor TContestChoices.Create;
begin
   Create(UTCNow);
end;

constructor TContestChoices.Create(const aNowUTC: TDateTime);
var
   known: TContestHandleList;
   held: TContestHandle;
   n, i, j, k: integer;
   schedules: TContestChoiceTexts;
   eligible: array of boolean;
begin
   inherited Create;

   (* THE RANGE THE WIN32 DIALOG OFFERED: every contest but "no contest"
      (NoContest, DUMMYCONTEST) -- every contest the registry knows by
      name, in handle order, since Q108 S2. *)
   known := KnownContests;
   SetLength(FContests, Length(known));
   n := 0;
   for k := 0 to High(known) do
      begin
      if known[k] <> NoContest then
         begin
         FContests[n] := known[k];
         inc(n);
         end;
      end;
   SetLength(FContests, n);

   (* AN INSERTION SORT: under two hundred entries, built once per dialog,
      and stable, which the enum tie-break does not need but costs nothing. *)
   for i := 1 to n - 1 do
      begin
      held := FContests[i];
      j := i - 1;
      while (j >= 0) and ComesBefore(held, FContests[j]) do
         begin
         FContests[j + 1] := FContests[j];
         dec(j);
         end;
      FContests[j + 1] := held;
      end;

   SetLength(FCaptions, n);
   for i := 0 to n - 1 do
      begin
      FCaptions[i] := ContestChoiceCaption(FContests[i]);
      end;

   (* THE UPCOMING-FIRST ORDER, from the alphabetical one just built, so an
      undated tail keeps it. Only a contest that can be started is dated. *)
   schedules := nil;
   eligible := nil;
   SetLength(schedules, n);
   SetLength(eligible, n);
   for i := 0 to n - 1 do
      begin
      eligible[i] := ContestCanStartNew(FContests[i]);
      if eligible[i] then
         begin
         schedules[i] := ContestIdentity(FContests[i]).Schedule;
         end
      else
         begin
         schedules[i] := '';
         end;
      end;
   FSoonest := SoonestFirstOrder(schedules, eligible, aNowUTC, FHints, FScheduleErrors);
end;

function TContestChoices.GetHint(aIndex: integer): string;
begin
   Result := FHints[aIndex];
end;

function TContestChoices.GetScheduleError(aIndex: integer): string;
begin
   Result := FScheduleErrors[aIndex];
end;

function TContestChoices.DisplayText(aIndex: integer; aWithHint: boolean): string;
begin
   if aWithHint then
      begin
      Result := ContestChoiceDisplay(FCaptions[aIndex], FHints[aIndex]);
      end
   else
      begin
      Result := FCaptions[aIndex];
      end;
end;

function TContestChoices.GetCount: integer;
begin
   Result := Length(FContests);
end;

function TContestChoices.GetContest(aIndex: integer): TContestHandle;
begin
   Result := FContests[aIndex];
end;

function TContestChoices.GetCaption(aIndex: integer): string;
begin
   Result := FCaptions[aIndex];
end;

function ContestChoiceMatches(const aCaption, aFilter: string): boolean;
var
   wanted: string;
begin
   wanted := Trim(aFilter);
   if wanted = '' then
      begin
      Result := True;
      Exit;
      end;
   (* UnicodeLowerCase, NOT LowerCase: LowerCase folds ASCII only, and a
      sponsor's name need not be ASCII. *)
   Result := Pos(UnicodeLowerCase(wanted), UnicodeLowerCase(aCaption)) > 0;
end;

function ContestCanStartNew(aContest: TContestHandle): boolean;
begin
   Result := (aContest <> NoContest) and ContestIdentity(aContest).IsActive;
end;

function TContestChoices.Matching(const aFilter: string;
                                  aIncludeInactive: boolean;
                                  aSoonestFirst: boolean): TContestChoiceIndexes;
var
   k, i, n: integer;
begin
   Result := nil;
   SetLength(Result, Length(FContests));
   n := 0;
   for k := 0 to High(FCaptions) do
      begin
      if aSoonestFirst then
         begin
         i := FSoonest[k];
         end
      else
         begin
         i := k;
         end;
      if (not aIncludeInactive) and
         (not ContestCanStartNew(FContests[i])) then
         begin
         Continue;
         end;
      if ContestChoiceMatches(FCaptions[i], aFilter) then
         begin
         Result[n] := i;
         inc(n);
         end;
      end;
   SetLength(Result, n);
end;

function TContestChoices.IndexOf(aContest: TContestHandle): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to High(FContests) do
      begin
      if FContests[i] = aContest then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

end.

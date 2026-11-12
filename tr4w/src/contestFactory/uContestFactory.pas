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

(* THE ACTIVE CONTEST OBJECT.

  One instance, for the contest currently loaded, created on demand and replaced
  when the contest changes. TR4W runs one contest at a time -- Contest is a
  global -- so a single instance is the honest model rather than a limitation.

  ActiveContest RETURNS nil FOR A CONTEST NOBODY HAS MOVED YET, and every caller
  is expected to handle that by doing what it did before. That is the strangler
  seam: the factory grows one contest at a time and the legacy path stays exactly
  as it is underneath, so each move is provable on its own against the golden
  corpus rather than as part of a big-bang.

  THE INSTANCE IS REBUILT WHEN THE CONTEST CHANGES, and that is checked on every
  call rather than being invalidated by whoever changes it. The contest is set
  from the .cfg parser, the log's stored configuration, the network, and the
  contest-selection dialog, and requiring each of those to remember to tell the
  factory is a rule that WILL be broken. Comparing a value is cheap; a stale
  contest object scoring an entire log is not. *)
unit uContestFactory;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

(* ~~ContestFactoryEnabled~~ AND ITS /NOFACTORY SWITCH ARE GONE -- 2026-09-29.

  They answered "does the factory produce what the legacy arm produced" by
  running the same rescore twice in one invocation, once each way, and diffing.
  That was the only exact measurement available, because the golden corpus is
  BLIND to scoring: changing ARRL DX from 3 points to 7 leaves
  export-d12-corpus.sh at 24 passed, since /EXPORT sums the points STORED in the
  log and never recomputes them.

  IT HAD A DEATH DATE BUILT IN. Every contest moved into the factory deletes
  more of the legacy arm, so the A/B weakened exactly as the work proceeded and
  would be unrunnable the day the last contest moved. NY4I, 2026-09-29, with the
  remaining contests due to move inside two weeks: "We should deprecate
  NOFACTORY."

  THE MEASUREMENT IS NOT LOST, IT IS FROZEN. The legacy pass was run once and
  written down as each corpus set's rescored.adi / rescored.cbr, and
  test-contest-factory.sh now rescores through the factory and diffs against
  those bytes. Same assertion, same sensitivity to a point-rule change, and it
  survives the deletion of the path it was measured against.

  WHAT THAT GATE DOES NOT ASSERT is whether the scoring is CORRECT -- it is our
  own former output, so it says the factory agrees with what TR4W did before the
  move, exactly as /NOFACTORY did. freeze-rescore-baseline.sh carries the full
  statement of that, and of when re-freezing a set is legitimate. *)

(* The object for aContest, or nil when that contest has no class yet.
  Do not free it -- this unit owns it.

  THE CONTEST IS A PARAMETER, NOT THE GLOBAL. `Contest` lives in PostUnit, and a
  factory that reached for it would drag the Cabrillo/ADIF exporter into every
  unit that wants to score a QSO -- and could not be tested without booting the
  program's globals. Every caller already has the value in scope. *)
function ActiveContest(aContest: TContestHandle): TContestBase; overload;

(* The same, for a legacy contest named by its member -- the tests'
  spelling (Q108 S2). *)
function ActiveContest(aContest: ContestType): TContestBase; overload;

(* Drops the current instance.  Called at shutdown; safe at any time, because
  the next ActiveContest simply builds another. *)
procedure ReleaseActiveContest;

(* THE FOUR `QSO POINTS ...` OVERRIDES AS THE OPERATOR HAS STATED THEM, read
  from the settings model. CurrentStation puts them in every contest's
  TStationContext, and LOGSTUFF.CalculateQSOPoints hands them to
  uContestBase.ApplyQSOPointOverride for a classless contest -- one reader of
  the four settings, so the two paths cannot read them differently. *)
function CurrentQSOPointOverrides: TQSOPointOverrides;

(* THE STATION AS THE PROGRAM CURRENTLY HAS IT -- the one place the station's
  globals are read into a TStationContext. ActiveContest hands it to the
  scoring object on every request; since M7a (2026-10-02) FCONTEST hands it to
  TContestBase.DescribeSession and LogCfg to CQExchangeDefault, so a contest's
  set-up reads the same snapshot its scoring does. *)
function CurrentStation: TStationContext;

(* MY ITU ZONE AS THIS SESSION HAS IT -- issue 222: the stated MY ITU ZONE,
  else the ITU zone CTY.DAT gives MY CALL, else 0 (unknown). The ONE answer
  behind TStationContext.MyITUZone (scoring), uLogStore.LogStoreCurrentMyFacts
  (what a QSO records as my_itu_zone) and PostUnit.ZoneSentForThisContest (the
  ITU zone an export sends) -- three copies of this rule until then. *)
function SessionMyITUZone: integer;

(* MY CQ ZONE AS A QSO RECORDS IT (my_cq_zone) -- issue 298. TStationContext.
  MyCQZone's answer: a stated MY ZONE wins, else MY CALL's CQ zone from
  CTY.DAT. The same in every contest: until MY LICENSE YEAR existed the
  European HF Championship and KVP kept the SENT licence year in MY ZONE and
  recorded it as the CQ zone (NY4I's row read 80), so this asked the contest;
  MY ZONE is a zone everywhere now. aContest is kept so the caller does not
  change. Rows already stored keep what they hold: nothing rewrites a
  captured row. uLogStore.LogStoreCurrentMyFacts is the caller. *)
function SessionMyCQZone(aContest: TContestBase): integer;

(* THE ZONE aContest SENDS IN THIS SESSION, AS TEXT -- issue 225.
  uContestBase.ZoneTextSent over aContest's zone list (nil: neither),
  SessionMyITUZone and the resolved MY ZONE text. The ONE answer behind
  PostUnit.ZoneSentForThisContest (what the export prints) and the default CW
  exchange messages FoundContest writes (FCONTEST.SetUpRSTMyZoneExchange), so
  an ITU-zone contest sends on the air the ITU zone its log exports. *)
function SessionZoneTextSent(aContest: TContestBase): string;

(* A LOG OR .cfg THAT STATED THE LICENCE YEAR AS MY ZONE -- issue 298. Before
  MY LICENSE YEAR existed the European HF Championship and KVP kept the year in
  the zone slot, so a contest the operator set up then holds it as a MY ZONE
  statement (a New Contest answer, a .cfg line, the log's own row). Asked once
  the open contest is known (FCONTEST.FoundContest): when aKind says the
  contest exchanges a year, and it STATED a MY ZONE but no MY LICENSE YEAR, the
  statement moves -- the year becomes this contest's MY LICENSE YEAR, and the
  MY ZONE statement is withdrawn, so the zone is derived from MY CALL again
  rather than read as a CQ zone of 80. A statement that is not one to four
  digits is left alone (the year would be nothing). The next capture writes
  the log's rows under their own names; nothing else changes. A station-wide
  MY ZONE is never moved: it is the station's zone, and only a contest's own
  statement can have been a year. aKind rykNone does nothing. *)
procedure AdoptLegacyLicenseYear(aKind: TReceivedYearKind);

implementation

uses
   SysUtils,
   (* THE ONE UNIT IN THE FACTORY THAT TOUCHES THE PROGRAM'S GLOBALS.

      LOGWIND holds MyContinent; the country and the zone are on the
      settings model. Keeping that here rather
      than in TContestBase is what lets a contest class -- and anything that
      asks one a question, such as uCabrilloExchange -- stay free of the display
      layer and testable without booting TR4W. *)
   LOGWIND,
   (* uContestSession STOOD HERE for ContestSession.DomesticMult, the kind
      IsNewMultiplierAnywhere asked the sheet with (M10 S9e). Since M11 S6
      part 1 the active contest answers it (HasGridFieldMultiplier). *)
   uSettingsModel,
   (* StationInHostState -- set-up's in-state answer for a QSO party (M5b). *)
   FCONTEST,
   (* DomesticCountryCall -- the engine's CTY lookup behind the station
      context's IsDomesticCountryCall service (M7b). *)
   ZoneCont,
   (* ctyGetCQZone -- the CTY lookup behind MyCQZone (2026-10-14). *)
   uCTYDAT,
   (* mo, the multiplier sheet -- read, never written, behind
      IsNewMultiplierAnywhere (design 7.13, 2026-10-14). Whether it keys the
      domestic multiplier on the grid field is the active contest's answer
      (M11 S6); LogDom was used for that global alone and left with it at
      M10 S9e. *)
   uMults,
   (* DomesticTableKnowsQTH -- the session's domestic table, behind the
      station context's IsDomesticQTH service (Q107, 2026-10-16). The same
      function LOGSTUFF hands a typed exchange's session. IMPLEMENTATION-
      section, so no interface cycle. *)
   LogDupe,
   uContestRegistry;

(* THE ENGINE'S DOMESTIC-COUNTRY TEST, AS THE STATION CONTEXT'S SERVICE -- see
   TStationContext.IsDomesticCountryCall. A callsign is ASCII, so the
   conversion to CallString is the one the engine's own callers make. *)
function EngineDomesticCountryCall(const aCall: string): boolean;
begin
   Result := DomesticCountryCall(CallString(aCall));
end;

(* MY CQ ZONE, RESOLVED, AS THE STATION CONTEXT'S SERVICE -- see
   TStationContext.MyCQZone and TMyCQZoneQuery.

   A STATED ZONE WINS: the contest's override, or the station's MY ZONE when
   the operator typed one (ZoneWasSet). Only an UNSTATED zone is derived, and
   it is derived as a CQ zone whatever the contest's zone mode -- which is
   what the stored MY ZONE is not, in an ITU-zone contest (see TMyCQZoneQuery).
   ctyGetCQZone swaps CTY's zone mode while it looks, exactly as the UA4W
   arm that called it did; it is asked on the main thread, from scoring. *)
function EngineMyCQZone: integer;
var
   code: integer;
begin
   if Settings.My.HasContestOverride(sfZone) or Settings.My.ZoneWasSet then
      begin
      Val(Settings.My.ResolvedZone, Result, code);
      if code <> 0 then
         begin
         Result := 0;
         end;
      end
   else
      begin
      Result := ctyGetCQZone(Settings.My.Call);
      end;
end;

function SessionMyITUZone: integer;
begin
   (* See the declaration. 0 in the setting is "use CTY.DAT". *)
   Result := Settings.My.ResolvedItuZone;
   if Result <= 0 then
      begin
      Result := ctyGetITUZone(Settings.My.Call);
      end;
end;

function SessionMyCQZone(aContest: TContestBase): integer;
begin
   (* See the declaration. MY ZONE is a CQ zone in every contest since MY
      LICENSE YEAR took the year (issue 298), so aContest no longer matters. *)
   Result := EngineMyCQZone;
end;

(* THIS YEAR, from the calendar -- what MY LICENSE YEAR is read against
   (TStationContext.CurrentYear). *)
function CalendarYear: integer;
var
   year, month, day: word;
begin
   DecodeDate(Date, year, month, day);
   Result := year;
end;

function SessionZoneTextSent(aContest: TContestBase): string;
var
   kind: TReceivedYearKind;
begin
   (* See the declaration. A contest that exchanges a year sends MY LICENSE
      YEAR in the zone's place (issue 298). *)
   kind := ContestReceivedYearKind(aContest);
   if kind <> rykNone then
      begin
      Result := SentLicenseYearText(kind, Settings.My.ResolvedLicenseYear,
                                    CalendarYear);
      Exit;
      end;
   Result := ZoneTextSent(ContestZoneMultiplierZones(aContest),
                          @SessionMyITUZone,
                          Settings.My.ResolvedZone);
end;

procedure AdoptLegacyLicenseYear(aKind: TReceivedYearKind);
var
   stated: string;
   year: integer;
begin
   (* See the declaration. *)
   if (aKind = rykNone) or
      (not Settings.My.HasContestOverride(sfZone)) or
      Settings.My.HasContestOverride(sfLicenseYear) then
      begin
      Exit;
      end;
   stated := Trim(Settings.My.ContestOverride(sfZone));
   if (stated = '') or (Length(stated) > 4) or
      (not TryStrToInt(stated, year)) or (year < 0) then
      begin
      Exit;
      end;
   Settings.My.SetContestOverride(sfLicenseYear, stated);
   Settings.My.ClearContestOverride(sfZone);
end;

(* THE ACTIVE CONTEST OBJECT -- see ActiveContest. Declared here, ahead of the
   station's services, because IsNewMultiplierAnywhere asks it (M11 S6). *)
var
   GActive: TContestBase = nil;
   GActiveFor: TContestHandle;
   GHaveActive: boolean = False;

(* THE SHEET'S READ-ONLY "IS THIS NEW" ANSWER, AS A SERVICE -- design 7.13.
   See TNewMultiplierQuery: the all-band, both-mode row, as LOGSTUFF's
   RSGB160Method arm asked it. *)
function EngineIsNewMultiplierAnywhere(const aQso: ContestExchange;
                                       aKind: TNewMultiplierKind): boolean;
begin
   case aKind of
      nmkDomestic:
         begin
         (* The sheet's grid-field key is the contest's answer (M11 S6 part
            1); it was the session kind. The contest is GActive, NOT a fresh
            ActiveContest: this service is reached only through a station
            ActiveContest built, from inside that object's own scoring, and
            ActiveContest would rewrite the station of the object whose
            method is running. nil -- no active contest -- answers False, as
            the classless session's NoDomesticMults did. *)
         Result := mo.IsDmMult(string(aQso.DomMultQTH), AllBands, Both,
                               ContestHasGridFieldMultiplier(GActive));
         end;
      nmkDX:
         begin
         Result := mo.IsDXMult(aQso.QTH.Country, AllBands, Both);
         end;
   else
      begin
      Result := False;
      end;
   end;
end;

function CurrentQSOPointOverrides: TQSOPointOverrides;

   (* -1 is the setting's "not stated" (uSettingsModel.TQsoPoints); the
      record says it with a flag instead -- see TQSOPointOverride. *)
   procedure Take(aValue: integer; out aOverride: TQSOPointOverride);
   begin
      aOverride.Stated := aValue >= 0;
      aOverride.Points := aValue;
   end;

begin
   Take(Settings.Qso.PointsDomesticCw, Result.DomesticCW);
   Take(Settings.Qso.PointsDxCw, Result.DXCW);
   Take(Settings.Qso.PointsDomesticPhone, Result.DomesticPhone);
   Take(Settings.Qso.PointsDxPhone, Result.DXPhone);
end;

function CurrentStation: TStationContext;
var
   code: integer;
begin
   Result.PointOverrides := CurrentQSOPointOverrides;
   Result.MyCountry := UTF8Encode(Settings.My.Country);
   Result.MyContinent := MyContinent;
   (* THE STATION'S FACTS AS THIS CONTEST HAS THEM -- design 7.12: the
      contest's override if it stated one, else the station's value. *)
   Result.MyGrid := Settings.My.ResolvedGrid;
   (* THE STATE SENT IN THIS SESSION, NOT MY STATE -- design 7.11 (M9a).
      Until then set-up wrote a contest's sent state into MY STATE and this
      read it back; it reads the session's value now, so every contest sees
      exactly what it saw. *)
   Result.MyState := SentMyState;
   Result.ContestTitle := Settings.Contest.Title;
   Result.MyCall := Settings.My.Call;
   (* FoundContest's own in-state decision -- see TStationContext.InHostState. *)
   Result.InHostState := StationInHostState;
   (* CATEGORY-POWER, the one value -- set by the New Contest dialog or the
      Cabrillo summary window, the last touch winning (M9b, design 7.6). See
      TStationContext.MyPower. *)
   Result.MyPower := Settings.Contest.CategoryPower;
   (* CATEGORY-MODE, the same way -- see TStationContext.MyCategoryMode. *)
   Result.MyCategoryMode := Settings.Contest.CategoryMode;
   (* The rest of MY exchange, for set-up -- see TStationContext.MyName. *)
   Result.MyName := Settings.My.ResolvedName;
   Result.MyFDClass := Settings.My.ResolvedFdClass;
   Result.MySection := Settings.My.ResolvedSection;
   Result.MyPrec := Settings.My.ResolvedPrec;
   Result.MyCheck := Settings.My.ResolvedCheck;
   Result.MyZoneText := Settings.My.ResolvedZone;
   (* MY LICENSE YEAR, as stated, and this year to read it against -- see
      TStationContext. *)
   Result.MyLicenseYear := Settings.My.ResolvedLicenseYear;
   Result.CurrentYear := CalendarYear;
   (* The session's contest name -- see TStationContext.ContestName (M7b). *)
   Result.ContestName := Settings.Contest.Name;
   (* The engine's domestic-country CTY lookup, as a service (M7b). *)
   Result.IsDomesticCountryCall := @EngineDomesticCountryCall;
   (* MY CQ ZONE and the sheet's new-multiplier answer, as services
      (2026-10-14) -- see TStationContext. *)
   Result.MyCQZone := @EngineMyCQZone;
   (* MY ITU ZONE, as a service (issue 222) -- see TStationContext. *)
   Result.MyITUZone := @SessionMyITUZone;
   Result.IsNewMultiplierAnywhere := @EngineIsNewMultiplierAnywhere;
   (* THE DOMESTIC TABLE, as a service (Q107) -- see TStationContext.
      IsDomesticQTH. *)
   Result.IsDomesticQTH := @DomesticTableKnowsQTH;

   (* MY ZONE, RESOLVED -- design 7.12. In the contest's zone mode when
      unstated; see TStationContext.MyZone. *)
   Val(Settings.My.ResolvedZone, Result.MyZone, code);
   Result.MyZoneValid := (code = 0) and (Settings.My.ResolvedZone <> '');
   if not Result.MyZoneValid then
      begin
      Result.MyZone := 0;
      end;
end;

function ActiveContest(aContest: TContestHandle): TContestBase;
var
   cls: TContestClass;
begin
   if GHaveActive and (GActiveFor = aContest) then
      begin
      Result := GActive;
      if Result <> nil then
         begin
         (* Refreshed on every request, not only when the contest changes: MY
            CALL can be edited mid-contest and everything derived from it moves
            with it. *)
         Result.SetStation(CurrentStation);
         end;
      Exit;
      end;

   FreeAndNil(GActive);
   GActiveFor := aContest;
   GHaveActive := True;

   cls := ContestClassFor(aContest);
   if cls <> nil then
      begin
      GActive := cls.Create(aContest);
      GActive.SetStation(CurrentStation);
      end;

   Result := GActive;
end;

function ActiveContest(aContest: ContestType): TContestBase;
begin
   Result := ActiveContest(ContestHandleOf(aContest));
end;

procedure ReleaseActiveContest;
begin
   FreeAndNil(GActive);
   GHaveActive := False;
end;

(* THE OBJECT THAT JUDGES A LOGGED RECORD -- uContestRegistry.LoggedQSOContest
   (Q119, 2026-10-23). The session's object when the record is of the
   session's contest: it carries the entrant, which the host-area rule needs.
   nil otherwise, and the registry answers with the station-less identity.

   GActive AS IT IS, NOT A FRESH ActiveContest. Readers of a record -- the
   ADIF and Cabrillo writers, the grids, the score-posting XML -- may run off
   the main thread or inside another call on this object, and ActiveContest
   would rebuild its station (and could free it for another contest). Every
   main-thread scoring request refreshes the station, and the two facts the
   host-area rule reads -- the in-area answer and the domestic-table service
   -- change only at set-up, which itself asks ActiveContest.

   MAIN THREAD ONLY -- an invariant, audited 2026-10-23: every reader of a
   logged record's X-QSO status (Cabrillo/ADIF export, /EXPORT, the loader,
   the rescore, the summary sheet, UDP and score-posting XML, HamScore's
   render, the grids, the peer and WSJT-X arms through QueueAsyncCall) runs on
   the main thread. IN7QPNE's answer WRITES its component party's station
   (PartyContest), so a reader added off the main thread must not come here. *)
function SessionLoggedQSOContest(aContest: TContestHandle): TContestBase;
begin
   Result := nil;
   if GHaveActive and (GActiveFor = aContest) then
      begin
      Result := GActive;
      end;
end;

initialization
   RegisterLoggedQSOContestProvider(@SessionLoggedQSOContest);

finalization
   ReleaseActiveContest;

end.

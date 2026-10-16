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
function ActiveContest(aContest: ContestType): TContestBase;

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

(* THE ACTIVE CONTEST OBJECT -- see ActiveContest. Declared here, ahead of the
   station's services, because IsNewMultiplierAnywhere asks it (M11 S6). *)
var
   GActive: TContestBase = nil;
   GActiveFor: ContestType;
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
   (* The session's contest name -- see TStationContext.ContestName (M7b). *)
   Result.ContestName := Settings.Contest.Name;
   (* The engine's domestic-country CTY lookup, as a service (M7b). *)
   Result.IsDomesticCountryCall := @EngineDomesticCountryCall;
   (* MY CQ ZONE and the sheet's new-multiplier answer, as services
      (2026-10-14) -- see TStationContext. *)
   Result.MyCQZone := @EngineMyCQZone;
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

function ActiveContest(aContest: ContestType): TContestBase;
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

procedure ReleaseActiveContest;
begin
   FreeAndNil(GActive);
   GHaveActive := False;
end;

finalization
   ReleaseActiveContest;

end.

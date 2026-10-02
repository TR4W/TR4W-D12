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

(* THE APPLICATION'S HALF OF THE FINAL SCORE -- M6, 2026-10-02
  (docs/CONTEST_OWNERSHIP_DESIGN.md 5 and 7.7, stage 3).

  The contest owns the formula and the bonuses (TContestBase.FinalScore); the
  application owns the log and the sheet. This unit is where the two meet:

    GatherScoreTotals    reads the sheet and the counters into a TScoreTotals
    ResetLoggedQSOs,     keep the read-only view of the logged QSOs a bonus
    AddLoggedQSO         rule reads, alongside the totals
    ContestFinalScore    asks the session's contest for its final score

  LogEdit.TotalScore is the one caller of ContestFinalScore, and every reader
  of the score reads TotalScore. NOTHING HERE NAMES A CONTEST: what differs
  per contest is the contest's own class, asked through ActiveContest, or its
  identity when it has none.

  ---------------------------------------------------------------------------
  THE VIEW IS KEPT WITH THE TOTALS, NOT READ FROM THE DATABASE PER SCORE, AND
  THAT WAS MEASURED, NOT ASSUMED
  ---------------------------------------------------------------------------
  The first version read the SQLite log when a bonus rule first asked. Timed
  on a 5,000-QSO log (2026-10-02, a throwaway test against TLogRepository):
  659 ms in one statement, 676 ms in runs of 256 -- the cost is decoding a
  row (about 130 us each), not the query. TotalScore runs after every logged
  QSO, so a 1,500-QSO Missouri log would have paused about 200 ms on every
  Enter.

  So the view is a MIRROR, filled exactly where the totals are: emptied with
  them (LOGDUPE's DisposeOfMemoryAndZeroTotals), filled by the log's loader
  for every record it adds to the sheet (MainUnit.LoadinLog), and extended by
  live entry where it counts a new QSO (LOGSUBS2.LogContact). Every path
  found that changes a logged QSO -- the editor, the rescore, an import, a
  deletion, a network update -- already ends in LoadinLog, because the totals
  would be wrong otherwise. So the view and the totals are rebuilt together
  and can never describe two different logs, and a score costs a walk of
  memory. It holds what
  QSOCountsTowardTotals accepts, which is the loader's own test.

  MAIN THREAD ONLY. The loader and live entry run there; TotalScore answers a
  worker thread from its last main-thread score and never reaches here. *)
unit uScoreTotals;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

(* THE TOTALS AS THE PROGRAM HOLDS THEM NOW -- see TScoreTotals. *)
procedure GatherScoreTotals(out aTotals: TScoreTotals);

(* THE VIEW, KEPT WITH THE TOTALS -- see the header. Reset empties it; Add
   keeps aQso when QSOCountsTowardTotals accepts it. *)
procedure ResetLoggedQSOs;
procedure AddLoggedQSO(const aQso: ContestExchange);

(* The view itself, as a contest receives it: read-only. *)
function LoggedQSOView: TLoggedQSOView;

(* THE FINAL SCORE of aContest's log, from aTotals: its class, else its
   identity (a plain TContestBase -- the general formula, no bonus), over the
   view above. Main thread only. *)
function ContestFinalScore(aContest: ContestType;
                           const aTotals: TScoreTotals): longint;

implementation

uses
   SysUtils,
   uSettingsModel,
   LogWind,
   LogDupe,
   LogDom,
   uMults,
   uContestFactory,
   uContestRegistry;

var
   (* Created on first use, freed at finalization. The contest only ever sees
      it as a TLoggedQSOView, which has no way to write. *)
   GLoggedQSOs: TLoggedQSOList = nil;

function LoggedQSOs: TLoggedQSOList;
begin
   if GLoggedQSOs = nil then
      begin
      GLoggedQSOs := TLoggedQSOList.Create;
      end;
   Result := GLoggedQSOs;
end;

function LoggedQSOView: TLoggedQSOView;
begin
   Result := LoggedQSOs;
end;

procedure ResetLoggedQSOs;
begin
   LoggedQSOs.Clear;
end;

procedure AddLoggedQSO(const aQso: ContestExchange);
begin
   if QSOCountsTowardTotals(aQso) then
      begin
      LoggedQSOs.Add(aQso);
      end;
end;

procedure GatherScoreTotals(out aTotals: TScoreTotals);
var
   b: BandType;
   m: ModeType;
   r: RemainingMultiplierType;
begin
   FillChar(aTotals, SizeOf(aTotals), 0);

   aTotals.QSOPoints := TotalQSOPoints;
   if Settings.Qtc.Enable then
      begin
      aTotals.QTCPoints := TotalNumberQTCsProcessed;
      end;

   for b := Low(BandType) to High(BandType) do
      begin
      for m := CW to Both do
         begin
         aTotals.QSOs[b, m] := QSOTotals[b, m];
         for r := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
            begin
            aTotals.Mults[b, m, r] := mo.MTotals[b, m, r];
            end;
         end;
      end;

   aTotals.ScoredBand := SingleBand;
   aTotals.SessionCountsMultipliers := not ((ActiveDomesticMult = NoDomesticMults) and
                                            (ActiveDXMult = NoDXMults)             and
                                            (ActivePrefixMult = NoPrefixMults)     and
                                            (ActiveZoneMult = NoZoneMults));
   aTotals.SessionExchange := ActiveExchange;
   aTotals.SessionDXMult := ActiveDXMult;
   aTotals.LiveSessionTally := LiveSessionTally;
end;

function ContestFinalScore(aContest: ContestType;
                           const aTotals: TScoreTotals): longint;
var
   scorer: TContestBase;
begin
   (* THE ACTIVE OBJECT FIRST, because it carries the station (Winter Field
      Day's power, Idaho's county, the Salmon Run's mode category); a
      classless contest has none and its identity needs none. *)
   scorer := ActiveContest(aContest);
   if scorer = nil then
      begin
      scorer := ContestIdentity(aContest);
      end;

   Result := scorer.FinalScore(aTotals, LoggedQSOs);
end;

finalization
   FreeAndNil(GLoggedQSOs);

end.

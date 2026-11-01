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
 *)
unit uScoreBreakdown;

{$I tr4w.inc}

(* THE <breakdown> OF THE ONLINE-SCORING XML, FROM TOTALS HANDED IN.

   https://blog.contestonlinescore.com/online-scoring-xml-specification/ says a
   <qso>, <point> or <mult> row is one band and one mode, and that the SUMMARY is
   band="total" mode="ALL", once per multiplier type.

   WHAT THE SCORER DID WITH THE OLD ROW SET (RTC 2026, NY4I, 2026-11-01): eight
   QSOs on 20 m CW, eight grids, and the post carried each multiplier count four
   times -- 20/CW, 20/ALL, total/CW, total/ALL. The scorer reported 16 raw
   multipliers, which is 20/CW plus 20/ALL: it sums every row that is not a
   total, so a row the spec does not describe is double-counted. This unit
   emits the real (band, mode) rows and ONE total/ALL row, and nothing else.

   THE LABEL OF A MULTIPLIER IS THE CONTEST'S, asked through
   TContestBase.ScorePostingMultiplierType -- the one hook the UDP score
   builder in LOGSUBS2 uses -- and not a table kept here. The totals arrive as
   a parameter so a test can drive it without a booted session; the caller
   (uGetScores) fills them from the globals. *)

interface

uses
   VC,
   uMults,
   uContestBase;

type
   TBreakdownTotals = record
      QSOs: array[BandType, CW..Both] of integer;
      Points: array[BandType, CW..Both] of integer;
      Mults: TMultTotals;
   end;

(* The rows, with no <breakdown> wrapper. *)
function BuildBreakdownXml(const aTotals: TBreakdownTotals;
                           aContest: TContestBase): AnsiString;

const
   (* WHEN THE POSTED SCORE IS REBUILT (uHamScore).  Rebuilding reads the whole
      log (PostUnit.CalculateTotals), so a change coalesces: at most one rebuild
      per SCORE_REBUILD_MIN_MS however fast QSOs arrive, and the first change
      after a quiet spell goes out on the next one-second tick.  With no change
      at all it is rebuilt every SCORE_REBUILD_HEARTBEAT_MS, so the timestamp
      and anything that moved without a logged QSO (a rescore) never go stale
      for long; the uploader posts every 120 s. *)
   SCORE_REBUILD_MIN_MS       = 5000;
   SCORE_REBUILD_HEARTBEAT_MS = 30000;

(* Is it time to rebuild the posted score?  aElapsedMs is the time since the
   last rebuild; aChanged says a QSO was logged, edited or deleted since. *)
function ScoreRebuildDue(aChanged: boolean; aElapsedMs: Int64): boolean;

implementation

uses
   SysUtils;

const
   (* The spec's mode names: CW, DIGI, PH, and ALL for the summary. *)
   BREAKDOWN_MODE: array[ModeType] of string = ('CW', 'DIGI', 'PH', 'ALL', '', '');

function BuildBreakdownXml(const aTotals: TBreakdownTotals;
                           aContest: TContestBase): AnsiString;
var
   band: BandType;
   mode: ModeType;
   kind: RemainingMultiplierType;
   count: integer;
   qsoTotal: integer;
   multType: string;
   rows: string;
begin
   rows := '';
   qsoTotal := 0;

   for band := Band160 to AllBands do
      begin
      if band = AllBands then
         begin
         Continue;
         end;
      for mode := CW to Phone do
         begin
         count := aTotals.QSOs[band, mode];
         if count <> 0 then
            begin
            rows := rows + '<qso band="' + BandStringsArrayWithOutSpaces[band] +
                    '" mode="' + BREAKDOWN_MODE[mode] + '">' + IntToStr(count) + '</qso>';
            qsoTotal := qsoTotal + count;
            end;
         for kind := Succ(Low(RemainingMultiplierType)) to High(RemainingMultiplierType) do
            begin
            multType := aContest.ScorePostingMultiplierType(kind, False);
            count := aTotals.Mults[band, mode, kind];
            if (multType <> '') and (count <> 0) then
               begin
               rows := rows + '<mult band="' + BandStringsArrayWithOutSpaces[band] +
                       '" mode="' + BREAKDOWN_MODE[mode] + '" type="' + multType +
                       '">' + IntToStr(count) + '</mult>';
               end;
            end;
         count := aTotals.Points[band, mode];
         if count <> 0 then
            begin
            rows := rows + '<point band="' + BandStringsArrayWithOutSpaces[band] +
                    '" mode="' + BREAKDOWN_MODE[mode] + '">' + IntToStr(count) + '</point>';
            end;
         end;
      end;

   (* THE SUMMARY, ONCE: total/ALL for the QSOs, the points and each type. *)
   rows := rows + '<qso band="total" mode="ALL">' + IntToStr(qsoTotal) + '</qso>';
   count := aTotals.Points[AllBands, Both];
   if count <> 0 then
      begin
      rows := rows + '<point band="total" mode="ALL">' + IntToStr(count) + '</point>';
      end;
   for kind := Succ(Low(RemainingMultiplierType)) to High(RemainingMultiplierType) do
      begin
      multType := aContest.ScorePostingMultiplierType(kind, True);
      count := aTotals.Mults[AllBands, Both, kind];
      if (multType <> '') and (count <> 0) then
         begin
         rows := rows + '<mult band="total" mode="ALL" type="' + multType + '">' +
                 IntToStr(count) + '</mult>';
         end;
      end;

   Result := AnsiString(rows);
end;

(* The decision alone, so a test can drive it without a clock. *)
function ScoreRebuildDue(aChanged: boolean; aElapsedMs: Int64): boolean;
begin
   Result := (aChanged and (aElapsedMs >= SCORE_REBUILD_MIN_MS)) or
             (aElapsedMs >= SCORE_REBUILD_HEARTBEAT_MS);
end;

end.

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
   total, so a second row for the same band is double-counted.

   THE SHAPE IS DXLog's (2.6.38, same contest, accepted by the scorer): ONE row
   per band, mode="ALL", for the QSOs, the points and each multiplier; after
   them the band="total" mode="ALL" summary. No per-mode rows. A multiplier
   counted by band (RTC) is one on 20 m however many modes it was worked in,
   and only the Both slot knows that; per-mode rows would add to two.

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

(* The rows, with no <breakdown> wrapper. aRowPrefix and aRowSuffix go before
   and after EVERY row: the HamScore post is one run of text (both empty), and
   the local UDP score message puts each row on its own indented line (LOGSUBS2
   passes its tabs and line break), so the two share the rows and not the
   layout. *)
function BuildBreakdownXml(const aTotals: TBreakdownTotals;
                           aContest: TContestBase;
                           const aRowPrefix: string = '';
                           const aRowSuffix: string = ''): AnsiString;

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

(* THE GRID THE <qth> BLOCK REPORTS.  The contest's grid is what the exchange
   sends -- RTC asks for four characters -- and it overrides the station's for
   that contest, so ResolvedGrid is four characters even when the operator's
   own MY GRID is six (RTC 2026-11-01: EL88pa saved, grid4 EL88 posted).  The
   scoreboard places the STATION, so the longer station grid is used when it
   is the same square as the contest's; a station grid in a different square
   is stale or mistyped and does not override. *)
function QthGrid(const aStation, aContest: string): string;

implementation

uses
   SysUtils;

function BuildBreakdownXml(const aTotals: TBreakdownTotals;
                           aContest: TContestBase;
                           const aRowPrefix: string = '';
                           const aRowSuffix: string = ''): AnsiString;
var
   band: BandType;
   kind: RemainingMultiplierType;
   count: integer;
   qsoTotal: integer;
   multType: string;
   rows: string;

   function Row(const aXml: string): string;
   begin
      Result := aRowPrefix + aXml + aRowSuffix;
   end;

begin
   rows := '';
   qsoTotal := 0;

   (* ONE ROW PER BAND, IN THE ALL-MODES COLUMN -- DXLog's shape, which the
      real scorer accepts for RTC. The Both slot is the band's count: a
      multiplier counted by band is ONE on 20 m however many modes it was
      worked in, and only the Both slot knows that (the CW and phone slots of
      a band would add to two). A band with no QSOs posts nothing. A band
      with QSOs posts its multiplier and point rows even at zero, as DXLog
      does. *)
   for band := Band160 to Pred(AllBands) do
      begin
      count := aTotals.QSOs[band, Both];
      if count = 0 then
         begin
         Continue;
         end;
      rows := rows + Row('<qso band="' + BandStringsArrayWithOutSpaces[band] +
              '" mode="ALL">' + IntToStr(count) + '</qso>');
      qsoTotal := qsoTotal + count;
      rows := rows + Row('<point band="' + BandStringsArrayWithOutSpaces[band] +
              '" mode="ALL">' + IntToStr(aTotals.Points[band, Both]) + '</point>');
      for kind := Succ(Low(RemainingMultiplierType)) to High(RemainingMultiplierType) do
         begin
         multType := aContest.ScorePostingMultiplierType(kind, True);
         (* A kind the log has no multiplier of at all is not posted: RTC has
            no country, zone or prefix multiplier to report as zero. *)
         if (multType <> '') and (aTotals.Mults[AllBands, Both, kind] <> 0) then
            begin
            rows := rows + Row('<mult band="' + BandStringsArrayWithOutSpaces[band] +
                    '" mode="ALL" type="' + multType + '">' +
                    IntToStr(aTotals.Mults[band, Both, kind]) + '</mult>');
            end;
         end;
      end;

   (* THE SUMMARY, ONCE: total/ALL for the QSOs, the points and each type. The
      QSOs are the bands' sum -- QSOTotals[AllBands] counts deleted QSOs too. *)
   rows := rows + Row('<qso band="total" mode="ALL">' + IntToStr(qsoTotal) + '</qso>');
   if qsoTotal <> 0 then
      begin
      rows := rows + Row('<point band="total" mode="ALL">' +
              IntToStr(aTotals.Points[AllBands, Both]) + '</point>');
      for kind := Succ(Low(RemainingMultiplierType)) to High(RemainingMultiplierType) do
         begin
         multType := aContest.ScorePostingMultiplierType(kind, True);
         if (multType <> '') and (aTotals.Mults[AllBands, Both, kind] <> 0) then
            begin
            rows := rows + Row('<mult band="total" mode="ALL" type="' + multType + '">' +
                    IntToStr(aTotals.Mults[AllBands, Both, kind]) + '</mult>');
            end;
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

function QthGrid(const aStation, aContest: string): string;
var
   station: string;
   contest: string;
   i: integer;
begin
   station := Trim(aStation);
   contest := Trim(aContest);
   Result := contest;
   if Length(station) < 6 then
      begin
      Exit;
      end;
   if contest = '' then
      begin
      Result := station;
      Exit;
      end;
   (* Compared character by character: SysUtils.SameText takes AnsiStrings in
      FPC 3.2.2, and two narrowing conversions are a build-gate failure. *)
   if Length(contest) < 4 then
      begin
      Exit;
      end;
   for i := 1 to 4 do
      begin
      if UpCase(station[i]) <> UpCase(contest[i]) then
         begin
         Exit;
         end;
      end;
   Result := station;
end;

end.

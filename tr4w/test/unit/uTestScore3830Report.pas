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

(* THE 3830SCORES REPORT'S TABLE IS THE CONTEST'S -- design 8.2x
  (NY4I after CQ WW SSB 2026: "we need to see a break out of both zone and
  country multipliers ... allow the contest class to tell the main program
  what to show in the 3830scores report as they can all be different").

  WHAT IS PINNED:
    - the base's layout: one 'Mults' column adding every kind -- the report as
      it was, for every contest that states none;
    - CQ WW CW and SSB: Zones then Countries, 160-10 m only (6 and 2 m, the
      WARC bands and VHF are never rows, even with QSOs);
    - CQ WW RTTY: State/Prov, DX, Zones, 80-10 m;
    - the rendered table for NY4I's CQ WW SSB 2026 log shape (5/36/31/11
      QSOs on 40/20/15/10 m), byte for byte;
    - the base layout's rendered table, byte for byte as PostUnit wrote it
      before the seam, and the one deliberate change (a credited WARC band
      with QSOs is now a row);
    - every registered contest: a well-formed layout, and no row on a band it
      does not credit (registry walks, no list to keep).

  No oracle sees this report -- the corpus, the matrix and /EXPORT do not
  write it -- so these are the only statement that it is right. *)
unit uTestScore3830Report;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TScore3830ReportTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TheBaseLayoutIsOneMultsColumn;
      procedure Test_CQWWLayoutIsZonesThenCountries;
      procedure Test_CQWWRTTYLayoutIsStatesDXZones;
      procedure Test_CQWWRowsAre160To10Only;
      procedure Test_CQWWSSBRendersNY4IsLogShape;
      procedure Test_TheBaseLayoutRendersTheReportAsItWas;
      procedure Test_ACreditedWARCBandWithQSOsIsARow;
      procedure Test_EveryContestStatesAWellFormedLayout;
      procedure Test_NoContestHasARowOnABandItDoesNotCredit;
   end;

implementation

uses
   SysUtils,
   VC,
   uMults,
   uContestBase,
   uContestRegistry,
   uScore3830Report,
   uTestRegisteredContests;

const
   CRLF = #13#10;
   ALL_KINDS: TRemainingMultiplierKinds = [rmDomestic, rmDX, rmZone, rmPrefix];

(* A TALLY WITH NOTHING IN IT, multipliers counted per band and not per
   mode -- CQ WW's session. *)
function EmptyTally: T3830Tally;
begin
   Result := Default(T3830Tally);
   Result.MultByBand := True;
   Result.MultByMode := False;
end;

(* aCount QSOs in aMode on aBand, with the AllBands and Both totals the
   summary keeps beside them. *)
procedure AddQSOs(var aTally: T3830Tally; aBand: BandType; aMode: ModeType;
                  aCount: integer);
begin
   aTally.QSOs[aBand, aMode] := aTally.QSOs[aBand, aMode] + aCount;
   aTally.QSOs[aBand, Both] := aTally.QSOs[aBand, Both] + aCount;
   aTally.QSOs[AllBands, aMode] := aTally.QSOs[AllBands, aMode] + aCount;
   aTally.QSOs[AllBands, Both] := aTally.QSOs[AllBands, Both] + aCount;
end;

(* aCount multipliers of aKind on aBand, in aMode, counted as
   uMults.TMultsObject.IncrementTotals counts them. *)
procedure AddMults(var aTally: T3830Tally; aBand: BandType; aMode: ModeType;
                   aKind: RemainingMultiplierType; aCount: integer);
begin
   aTally.Mults[aBand, aMode, aKind] := aTally.Mults[aBand, aMode, aKind] + aCount;
   aTally.Mults[aBand, Both, aKind] := aTally.Mults[aBand, Both, aKind] + aCount;
   aTally.Mults[AllBands, aMode, aKind] := aTally.Mults[AllBands, aMode, aKind] + aCount;
   aTally.Mults[AllBands, Both, aKind] := aTally.Mults[AllBands, Both, aKind] + aCount;
end;

function KindsText(aKinds: TRemainingMultiplierKinds): string;
var
   k: RemainingMultiplierType;
begin
   Result := '';
   for k := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
      begin
      if k in aKinds then
         begin
         Result := Result + IntToStr(Ord(k)) + ' ';
         end;
      end;
end;

(* ------------------------------------------------------------------------ *)

procedure TScore3830ReportTests.Test_TheBaseLayoutIsOneMultsColumn;
var
   base: TContestBase;
   layout: T3830SummaryLayout;
begin
   BeginTest('Test_TheBaseLayoutIsOneMultsColumn');
   base := TContestBase.Create(NoContest);
   try
      layout := base.Summary3830;
      CheckEquals(1, Length(layout.MultiplierColumns), 'the base states one column');
      CheckEquals('Mults', layout.MultiplierColumns[0].Title, 'headed Mults, as the report was');
      CheckEquals(KindsText(ALL_KINDS), KindsText(layout.MultiplierColumns[0].Kinds),
                  'adding every kind the sheet counts');
   finally
      base.Free;
      end;
end;

procedure TScore3830ReportTests.Test_CQWWLayoutIsZonesThenCountries;
const
   RUNNINGS: array[0..1] of ContestType = (CQWWCW, CQWWSSB);
var
   i: integer;
   layout: T3830SummaryLayout;
   who: string;
begin
   BeginTest('Test_CQWWLayoutIsZonesThenCountries');
   for i := Low(RUNNINGS) to High(RUNNINGS) do
      begin
      who := ContestWho(ContestIdentity(RUNNINGS[i]));
      layout := ContestIdentity(RUNNINGS[i]).Summary3830;
      CheckEquals(2, Length(layout.MultiplierColumns), who + ': two columns');
      if Length(layout.MultiplierColumns) = 2 then
         begin
         CheckEquals('Zones', layout.MultiplierColumns[0].Title, who + ': Zones first');
         CheckEquals(KindsText([rmZone]), KindsText(layout.MultiplierColumns[0].Kinds),
                     who + ': Zones counts the zone kind only');
         CheckEquals('Countries', layout.MultiplierColumns[1].Title, who + ': Countries second');
         CheckEquals(KindsText([rmDX]), KindsText(layout.MultiplierColumns[1].Kinds),
                     who + ': Countries counts the DX kind only');
         end;
      end;
end;

procedure TScore3830ReportTests.Test_CQWWRTTYLayoutIsStatesDXZones;
var
   layout: T3830SummaryLayout;
begin
   BeginTest('Test_CQWWRTTYLayoutIsStatesDXZones');
   layout := ContestIdentity(CQWWRTTY).Summary3830;
   CheckEquals(3, Length(layout.MultiplierColumns), 'CQ WW RTTY: three columns');
   if Length(layout.MultiplierColumns) = 3 then
      begin
      CheckEquals('State/Prov', layout.MultiplierColumns[0].Title, 'State/Prov first');
      CheckEquals(KindsText([rmDomestic]), KindsText(layout.MultiplierColumns[0].Kinds),
                  'State/Prov counts the domestic kind');
      CheckEquals('DX', layout.MultiplierColumns[1].Title, 'DX second');
      CheckEquals(KindsText([rmDX]), KindsText(layout.MultiplierColumns[1].Kinds),
                  'DX counts the DX kind');
      CheckEquals('Zones', layout.MultiplierColumns[2].Title, 'Zones third');
      CheckEquals(KindsText([rmZone]), KindsText(layout.MultiplierColumns[2].Kinds),
                  'Zones counts the zone kind');
      end;
end;

procedure TScore3830ReportTests.Test_CQWWRowsAre160To10Only;
const
   RUNNINGS: array[0..1] of ContestType = (CQWWCW, CQWWSSB);
var
   i: integer;
   tally: T3830Tally;
   b: BandType;
   contest: TContestBase;
begin
   BeginTest('Test_CQWWRowsAre160To10Only');
   (* QSOs on EVERY band: only the credited ones may become rows. *)
   tally := EmptyTally;
   for b := Band160 to Band24G do
      begin
      AddQSOs(tally, b, Phone, 1);
      end;
   for i := Low(RUNNINGS) to High(RUNNINGS) do
      begin
      contest := ContestIdentity(RUNNINGS[i]);
      for b := Band160 to Band24G do
         begin
         CheckEquals(BoolToStr(b in [Band160, Band80, Band40, Band20, Band15, Band10], True),
                     BoolToStr(Is3830Row(contest, tally, b), True),
                     ContestWho(contest) + ': is ' + Trim(BandStringsArray[b]) + ' m a row');
         end;
      end;
   (* And with NO QSOs the six are still rows -- the form lists every band. *)
   tally := EmptyTally;
   contest := ContestIdentity(CQWWSSB);
   for b := Band160 to Band10 do
      begin
      CheckTrue(Is3830Row(contest, tally, b),
                'CQ WW SSB: ' + Trim(BandStringsArray[b]) + ' m is a row with no QSOs');
      end;
   CheckFalse(Is3830Row(contest, tally, Band6), 'CQ WW SSB: 6 m is never a row');
   CheckFalse(Is3830Row(contest, tally, Band2), 'CQ WW SSB: 2 m is never a row');
   (* The RTTY running: 80-10 m. *)
   contest := ContestIdentity(CQWWRTTY);
   CheckFalse(Is3830Row(contest, tally, Band160), 'CQ WW RTTY: 160 m is not a row');
   CheckTrue(Is3830Row(contest, tally, Band80), 'CQ WW RTTY: 80 m is a row');
   CheckTrue(Is3830Row(contest, tally, Band10), 'CQ WW RTTY: 10 m is a row');
end;

(* NY4I's CQ WW SSB 2026 shape: 5, 36, 31 and 11 QSOs on 40, 20, 15 and 10 m,
   112 multipliers, 24640 points. The zone/country split per band is made up
   to add to his 112 (and his 43 on 20 m); the layout is what is pinned. *)
procedure TScore3830ReportTests.Test_CQWWSSBRendersNY4IsLogShape;
var
   tally: T3830Tally;
   expected: string;
begin
   BeginTest('Test_CQWWSSBRendersNY4IsLogShape');
   tally := EmptyTally;
   AddQSOs(tally, Band40, Phone, 5);
   AddQSOs(tally, Band20, Phone, 36);
   AddQSOs(tally, Band15, Phone, 31);
   AddQSOs(tally, Band10, Phone, 11);
   AddMults(tally, Band40, Phone, rmZone, 5);
   AddMults(tally, Band40, Phone, rmDX, 6);
   AddMults(tally, Band20, Phone, rmZone, 15);
   AddMults(tally, Band20, Phone, rmDX, 28);
   AddMults(tally, Band15, Phone, rmZone, 12);
   AddMults(tally, Band15, Phone, rmDX, 22);
   AddMults(tally, Band10, Phone, rmZone, 9);
   AddMults(tally, Band10, Phone, rmDX, 15);
   tally.TotalScore := 24640;

   expected :=
      '         Ph Qs    Zones Countries' + CRLF +
      ' 160         0        0         0' + CRLF + CRLF +
      '  80         0        0         0' + CRLF + CRLF +
      '  40         5        5         6' + CRLF + CRLF +
      '  20        36       15        28' + CRLF + CRLF +
      '  15        31       12        22' + CRLF + CRLF +
      '  10        11        9        15' + CRLF + CRLF +
      'Total       83       41        71' + CRLF + CRLF +
      'Zones: 41' + CRLF +
      'Countries: 71' + CRLF +
      'Mults: 112' + CRLF +
      'Total Score: 24640' + CRLF;
   CheckEquals(expected, Render3830Summary(ContestIdentity(CQWWSSB), tally),
               'CQ WW SSB: 160-10 m, Zones and Countries');
end;

(* THE BASE LAYOUT, BYTE FOR BYTE AS PostUnit.ExportTo3830Scores WROTE IT
   BEFORE THE SEAM: the eight standard rows always, 222 MHz because it has a
   QSO, one 'Mults' column adding every kind, then 'Mults: N'. The expected
   text was worked from the old routine's Format calls by hand. *)
procedure TScore3830ReportTests.Test_TheBaseLayoutRendersTheReportAsItWas;
var
   base: TContestBase;
   tally: T3830Tally;
   expected: string;
begin
   BeginTest('Test_TheBaseLayoutRendersTheReportAsItWas');
   tally := EmptyTally;
   AddQSOs(tally, Band20, CW, 10);
   AddQSOs(tally, Band222, CW, 1);
   AddMults(tally, Band20, CW, rmDX, 5);
   AddMults(tally, Band20, CW, rmZone, 3);
   AddMults(tally, Band222, CW, rmDomestic, 1);
   tally.TotalScore := 99;

   expected :=
      '         CW Qs    Mults' + CRLF +
      ' 160         0        0' + CRLF + CRLF +
      '  80         0        0' + CRLF + CRLF +
      '  40         0        0' + CRLF + CRLF +
      '  20        10        8' + CRLF + CRLF +
      '  15         0        0' + CRLF + CRLF +
      '  10         0        0' + CRLF + CRLF +
      '   6         0        0' + CRLF + CRLF +
      '   2         0        0' + CRLF + CRLF +
      ' 222         1        1' + CRLF + CRLF +
      'Total       11        9' + CRLF + CRLF +
      'Mults: 9' + CRLF +
      'Total Score: 99' + CRLF;

   base := TContestBase.Create(NoContest);
   try
      CheckEquals(expected, Render3830Summary(base, tally),
                  'a contest stating no layout: the report as it was');

      (* NOT counted per band: no multiplier column, the 'Mults:' line only. *)
      tally.MultByBand := False;
      expected :=
         '         CW Qs' + CRLF +
         ' 160         0' + CRLF + CRLF +
         '  80         0' + CRLF + CRLF +
         '  40         0' + CRLF + CRLF +
         '  20        10' + CRLF + CRLF +
         '  15         0' + CRLF + CRLF +
         '  10         0' + CRLF + CRLF +
         '   6         0' + CRLF + CRLF +
         '   2         0' + CRLF + CRLF +
         ' 222         1' + CRLF + CRLF +
         'Total       11' + CRLF + CRLF +
         'Mults: 9' + CRLF +
         'Total Score: 99' + CRLF;
      CheckEquals(expected, Render3830Summary(base, tally),
                  'multipliers not by band: no column, as before');

      (* COUNTED PER MODE: the per-mode lines, as before. *)
      tally.MultByMode := True;
      expected :=
         '         CW Qs' + CRLF +
         ' 160         0' + CRLF + CRLF +
         '  80         0' + CRLF + CRLF +
         '  40         0' + CRLF + CRLF +
         '  20        10' + CRLF + CRLF +
         '  15         0' + CRLF + CRLF +
         '  10         0' + CRLF + CRLF +
         '   6         0' + CRLF + CRLF +
         '   2         0' + CRLF + CRLF +
         ' 222         1' + CRLF + CRLF +
         'Total       11' + CRLF + CRLF +
         'CW Mults: 9' + CRLF +
         'Total Mults: 9' + CRLF +
         'Total Score: 99' + CRLF;
      CheckEquals(expected, Render3830Summary(base, tally),
                  'multipliers by mode: the per-mode lines, as before');
   finally
      base.Free;
      end;
end;

(* THE ONE DELIBERATE CHANGE for a contest stating nothing: a credited band
   outside the eight standard rows has a row when it has QSOs. 30 m had none,
   so its QSOs were missing from the Total row too. *)
procedure TScore3830ReportTests.Test_ACreditedWARCBandWithQSOsIsARow;
var
   base: TContestBase;
   tally: T3830Tally;
   text: string;
begin
   BeginTest('Test_ACreditedWARCBandWithQSOsIsARow');
   tally := EmptyTally;
   AddQSOs(tally, Band20, CW, 10);
   AddQSOs(tally, Band30, CW, 2);
   base := TContestBase.Create(NoContest);
   try
      CheckTrue(Is3830Row(base, tally, Band30), '30 m with QSOs is a row');
      CheckFalse(Is3830Row(base, tally, Band17), '17 m with none is not');
      text := Render3830Summary(base, tally);
      CheckTrue(Pos('  30         2', text) > 0, '30 m row rendered: ' + text);
      CheckTrue(Pos('Total       12', text) > 0, 'its QSOs reach the Total row: ' + text);
   finally
      base.Free;
      end;
end;

(* EVERY REGISTERED CONTEST'S LAYOUT IS RENDERABLE: at least one column, each
   with a one-line heading and at least one real kind, no kind in two
   columns (it would be counted twice in 'Mults:'). Asked of the identity --
   every layout today is station-free; one that reads the entrant is asked
   with a station by PostUnit, and this walk would need NewContestLike. *)
procedure TScore3830ReportTests.Test_EveryContestStatesAWellFormedLayout;
var
   contests: TContestIdentityList;
   k, c: integer;
   layout: T3830SummaryLayout;
   seen: TRemainingMultiplierKinds;
   who: string;
begin
   BeginTest('Test_EveryContestStatesAWellFormedLayout');
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      who := ContestWho(contests[k]);
      layout := contests[k].Summary3830;
      CheckTrue(Length(layout.MultiplierColumns) > 0, who + ': at least one column');
      seen := [];
      for c := 0 to High(layout.MultiplierColumns) do
         begin
         CheckTrue(Trim(layout.MultiplierColumns[c].Title) <> '',
                   who + ': column ' + IntToStr(c) + ' has a heading');
         CheckTrue((Pos(#13, layout.MultiplierColumns[c].Title) = 0) and
                   (Pos(#10, layout.MultiplierColumns[c].Title) = 0),
                   who + ': column ' + IntToStr(c) + '''s heading is one line');
         CheckTrue((layout.MultiplierColumns[c].Kinds * ALL_KINDS) <> [],
                   who + ': column ' + IntToStr(c) + ' counts a kind');
         CheckTrue(not (rmNoRemMultDisplay in layout.MultiplierColumns[c].Kinds),
                   who + ': column ' + IntToStr(c) + ' names no non-kind');
         CheckTrue((layout.MultiplierColumns[c].Kinds * seen) = [],
                   who + ': column ' + IntToStr(c) + ' counts no kind another does');
         seen := seen + layout.MultiplierColumns[c].Kinds;
         end;
      end;
end;

(* THE ROWS ARE THE CONTEST'S BANDS: with QSOs on every band, a row exists
   exactly where the contest credits the band (UsesBand). *)
procedure TScore3830ReportTests.Test_NoContestHasARowOnABandItDoesNotCredit;
var
   contests: TContestIdentityList;
   k: integer;
   tally: T3830Tally;
   b: BandType;
begin
   BeginTest('Test_NoContestHasARowOnABandItDoesNotCredit');
   tally := EmptyTally;
   for b := Band160 to Band24G do
      begin
      AddQSOs(tally, b, CW, 1);
      end;
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      for b := Band160 to Band24G do
         begin
         CheckEquals(BoolToStr(ContestCreditsBand(contests[k], b), True),
                     BoolToStr(Is3830Row(contests[k], tally, b), True),
                     ContestWho(contests[k]) + ': ' + Trim(BandStringsArray[b]) +
                     ' m is a row exactly where it is credited');
         end;
      CheckFalse(Is3830Row(contests[k], tally, BandLight),
                 ContestWho(contests[k]) + ': light is never a row');
      end;
end;

procedure TScore3830ReportTests.RunAllTests;
begin
   Test_TheBaseLayoutIsOneMultsColumn;
   Test_CQWWLayoutIsZonesThenCountries;
   Test_CQWWRTTYLayoutIsStatesDXZones;
   Test_CQWWRowsAre160To10Only;
   Test_CQWWSSBRendersNY4IsLogShape;
   Test_TheBaseLayoutRendersTheReportAsItWas;
   Test_ACreditedWARCBandWithQSOsIsARow;
   Test_EveryContestStatesAWellFormedLayout;
   Test_NoContestHasARowOnABandItDoesNotCredit;
end;

end.

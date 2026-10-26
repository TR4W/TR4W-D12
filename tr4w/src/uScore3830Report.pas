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

(* THE 3830SCORES REPORT'S SUMMARY TABLE -- what PostUnit.ExportTo3830Scores
  writes below its header block, and what NY4I copies into the
  3830scores.com submission form.

  A LEAF, and pure: it reads no global. PostUnit gathers the tally (the
  summary's QSO totals, the multiplier sheet's MTotals, the session's
  by-band/by-mode flags and the final score) and the contest; this renders.
  So a unit test can hand it a known tally and read the text back.

  WHAT THE CONTEST DECIDES (design 8.2x):
    the ROWS     -- the bands it credits (TContestBase.UsesBand, through
                    ContestCreditsBand). Of those, the 3830 form's standard
                    rows (160-10, 6, 2) are always shown, any other only when
                    it has QSOs.
    the COLUMNS  -- TContestBase.Summary3830: each multiplier column's
                    heading and the kinds it adds together. The base's one
                    column is 'Mults', every kind -- the report as it was.

  WHAT IT DOES NOT DECIDE, and stays the report's: one QSO column per mode
  that has QSOs (CW Qs, Ph Qs -- FM folded in -- Dig Qs); the per-band
  multiplier cells only when the session counts multipliers per band; the
  per-mode multiplier lines when it counts them per mode.

  FOR A CONTEST STATING NOTHING THE TEXT IS BYTE FOR BYTE WHAT THE REPORT
  WROTE BEFORE, with one exception: a credited band outside the standard rows
  -- 30, 17 or 12 m included -- now has a row when it has QSOs. The WARC bands
  had no row at all, so their QSOs were missing from the Total row too. *)
unit uScore3830Report;

{$I tr4w.inc}

interface

uses
   VC, uMults, uContestBase;

type
   (* PostUnit.RawQSOTotals' shape: QSOs per band and mode, FM folded into
      Phone, AllBands and Both the totals. *)
   T3830QSOTotals = array[BandType, CW..Both] of integer;

   (* WHAT THE TABLE IS RENDERED FROM. A RECORD BECAUSE IT IS AN INTERFACE
      PARAMETER -- the values one call needs, pure data. *)
   T3830Tally = record
      QSOs: T3830QSOTotals;
      Mults: TMultTotals;
      MultByBand: boolean;
      MultByMode: boolean;
      TotalScore: LongInt;
   end;

const
   (* THE 3830 FORM'S STANDARD ROWS, shown when the contest credits them even
      with no QSOs -- the eight the report always printed. Presentation, not a
      band rule: a band the contest does not credit is never a row. *)
   STANDARD_3830_BANDS = [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2];

(* IS aBand A ROW OF aContest'S TABLE for aTally? Credited, and a standard
   row or one with QSOs. Band160..Band24G only; BandLight never was. *)
function Is3830Row(aContest: TContestBase; const aTally: T3830Tally;
                   aBand: BandType): boolean;

(* THE TABLE, from its heading row to the 'Total Score:' line, CRLF line
   ends. aContest answers the rows and columns, and must not be nil (it
   raises): for "no contest" pass ContestIdentity(NoContest). *)
function Render3830Summary(aContest: TContestBase; const aTally: T3830Tally): string;

implementation

uses
   SysUtils;

const
   CRLF = #13#10;
   (* A column is at least nine wide, as the report's always were; a longer
      heading ('State/Prov') widens its column so a space still separates
      it. *)
   MIN_COLUMN_WIDTH = 9;

function ColumnWidth(const aColumn: T3830MultiplierColumn): integer;
begin
   Result := Length(aColumn.Title) + 1;
   if Result < MIN_COLUMN_WIDTH then
      begin
      Result := MIN_COLUMN_WIDTH;
      end;
end;

function RightAligned(const aText: string; aWidth: integer): string;
begin
   Result := StringOfChar(' ', aWidth - Length(aText)) + aText;
end;

function QSOsOnBand(const aTally: T3830Tally; aBand: BandType): integer;
begin
   Result := aTally.QSOs[aBand, CW] + aTally.QSOs[aBand, Phone] +
             aTally.QSOs[aBand, Digital];
end;

(* ONE MULTIPLIER CELL: the column's kinds on aBand, per mode added up when
   the session counts per mode -- PostUnit's CalcBandMults, restricted to the
   column's kinds. *)
function ColumnCountOnBand(const aTally: T3830Tally;
                           const aColumn: T3830MultiplierColumn;
                           aBand: BandType): integer;
var
   k: RemainingMultiplierType;
begin
   Result := 0;
   for k := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
      begin
      if k in aColumn.Kinds then
         begin
         if aTally.MultByMode then
            begin
            Result := Result + aTally.Mults[aBand, CW, k] +
                      aTally.Mults[aBand, Phone, k] + aTally.Mults[aBand, Digital, k];
            end
         else
            begin
            Result := Result + aTally.Mults[aBand, Both, k];
            end;
         end;
      end;
end;

(* The sheet's count of aKinds in aMode over all bands. *)
function KindsInMode(const aTally: T3830Tally; aKinds: TRemainingMultiplierKinds;
                     aMode: ModeType): integer;
var
   k: RemainingMultiplierType;
begin
   Result := 0;
   for k := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
      begin
      if k in aKinds then
         begin
         Result := Result + aTally.Mults[AllBands, aMode, k];
         end;
      end;
end;

function Is3830Row(aContest: TContestBase; const aTally: T3830Tally;
                   aBand: BandType): boolean;
begin
   if (aBand < Band160) or (aBand > Band24G) then
      begin
      Result := False;
      end
   else if not ContestCreditsBand(aContest, aBand) then
      begin
      Result := False;
      end
   else
      begin
      Result := (aBand in STANDARD_3830_BANDS) or (QSOsOnBand(aTally, aBand) > 0);
      end;
end;

function Render3830Summary(aContest: TContestBase; const aTally: T3830Tally): string;
var
   layout: T3830SummaryLayout;
   columns: T3830MultiplierColumns;
   allKinds: TRemainingMultiplierKinds;
   showCW, showPh, showDig: boolean;
   band: BandType;
   c: integer;
   cell: integer;
   sumCW, sumPh, sumDig: integer;
   sumColumn: array of integer;
   cwMults, phMults, digMults: integer;
begin
   (* NEVER nil: "no contest" is the registry's plain TContestBase, whose
      answer is the base layout. A nil here is a caller's mistake, reported
      rather than rendered as something. *)
   if aContest = nil then
      begin
      raise Exception.Create('Render3830Summary: no contest object');
      end;
   layout := aContest.Summary3830;
   columns := layout.MultiplierColumns;
   allKinds := [];
   for c := 0 to High(columns) do
      begin
      allKinds := allKinds + columns[c].Kinds;
      end;
   SetLength(sumColumn, Length(columns));

   showCW := aTally.QSOs[AllBands, CW] > 0;
   showPh := aTally.QSOs[AllBands, Phone] > 0;
   showDig := aTally.QSOs[AllBands, Digital] > 0;

   (* THE HEADING ROW. *)
   Result := '     ';
   if showCW then
      begin
      Result := Result + '    CW Qs';
      end;
   if showPh then
      begin
      Result := Result + '    Ph Qs';
      end;
   if showDig then
      begin
      Result := Result + '   Dig Qs';
      end;
   if aTally.MultByBand then
      begin
      for c := 0 to High(columns) do
         begin
         Result := Result + RightAligned(columns[c].Title, ColumnWidth(columns[c]));
         end;
      end;
   Result := Result + CRLF;

   sumCW := 0;
   sumPh := 0;
   sumDig := 0;
   for c := 0 to High(sumColumn) do
      begin
      sumColumn[c] := 0;
      end;

   (* THE BAND ROWS, a blank line after each, as the report always wrote. *)
   for band := Band160 to Band24G do
      begin
      if not Is3830Row(aContest, aTally, band) then
         begin
         Continue;
         end;
      Result := Result + Format('%4s ', [BandStringsArray[band]]);
      if showCW then
         begin
         Result := Result + Format('%9d', [aTally.QSOs[band, CW]]);
         end;
      if showPh then
         begin
         Result := Result + Format('%9d', [aTally.QSOs[band, Phone]]);
         end;
      if showDig then
         begin
         Result := Result + Format('%9d', [aTally.QSOs[band, Digital]]);
         end;
      if aTally.MultByBand then
         begin
         for c := 0 to High(columns) do
            begin
            cell := ColumnCountOnBand(aTally, columns[c], band);
            Result := Result + RightAligned(IntToStr(cell), ColumnWidth(columns[c]));
            sumColumn[c] := sumColumn[c] + cell;
            end;
         end;
      Result := Result + CRLF + CRLF;

      sumCW := sumCW + aTally.QSOs[band, CW];
      sumPh := sumPh + aTally.QSOs[band, Phone];
      sumDig := sumDig + aTally.QSOs[band, Digital];
      end;

   (* THE TOTAL ROW -- the rows shown, added up. *)
   Result := Result + 'Total';
   if showCW then
      begin
      Result := Result + Format('%9d', [sumCW]);
      end;
   if showPh then
      begin
      Result := Result + Format('%9d', [sumPh]);
      end;
   if showDig then
      begin
      Result := Result + Format('%9d', [sumDig]);
      end;
   if aTally.MultByBand then
      begin
      for c := 0 to High(columns) do
         begin
         Result := Result + RightAligned(IntToStr(sumColumn[c]), ColumnWidth(columns[c]));
         end;
      end;
   Result := Result + CRLF + CRLF;

   (* THE MULTIPLIER LINES -- the sheet's own totals. Per mode when the
      session counts per mode; else one line per column when there are
      several, and always the 'Mults:' line, every column's kinds together. *)
   if aTally.MultByMode then
      begin
      cwMults := KindsInMode(aTally, allKinds, CW);
      phMults := KindsInMode(aTally, allKinds, Phone);
      digMults := KindsInMode(aTally, allKinds, Digital);
      if showCW then
         begin
         Result := Result + Format('CW Mults: %d', [cwMults]) + CRLF;
         end;
      if showPh then
         begin
         Result := Result + Format('Ph Mults: %d', [phMults]) + CRLF;
         end;
      if showDig then
         begin
         Result := Result + Format('Dig Mults: %d', [digMults]) + CRLF;
         end;
      Result := Result + Format('Total Mults: %d', [cwMults + phMults + digMults]) + CRLF;
      end
   else
      begin
      if Length(columns) > 1 then
         begin
         for c := 0 to High(columns) do
            begin
            Result := Result + Format('%s: %d',
                                      [columns[c].Title,
                                       KindsInMode(aTally, columns[c].Kinds, Both)]) + CRLF;
            end;
         end;
      Result := Result + Format('Mults: %d', [KindsInMode(aTally, allKinds, Both)]) + CRLF;
      end;

   Result := Result + Format('Total Score: %d', [aTally.TotalScore]) + CRLF;
end;

end.

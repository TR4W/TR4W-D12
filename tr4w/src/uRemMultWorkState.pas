unit uRemMultWorkState;

(* HOW A REMAINING-MULTIPLIER CELL SHOWS ITS WORKINGS -- issue 357.

  NY4I, 2026-11-21: show whether each multiplier was worked once, twice and
  so on, with the orange the program already uses. That orange is BAND MAP
  WORKED MULT COLOR (Settings.BandMap.WorkedMultColor, read through
  uSpots.WorkedMultColor). Since issue 12 it means ONE thing, on the band map
  and in the telnet console: the multiplier is worked at least once but
  fewer than BAND MAP WORKED MULT LIMIT times on this band and mode -- a
  backup is wanted. The window gives it the same meaning and no other, so a
  colour never says two things.

  A LEAF: no LCL, no globals, no settings. The caller passes the sheet's
  worked bit, the sheet's count (mo.WorkedCount, keyed as the bit is) and the
  limit; uRemMults gathers them, LOGEDIT.ShowRemMultsInWindow applies these
  two functions, and the form maps the state to a colour. Pinned by
  uTestRemMultWorkState. *)

{$I tr4w.inc}

interface

type
   (* rwsNeeded: not worked on the window's band and mode (the sheet's bit).
     rwsBackupWanted: worked, and the count is at least 1 and below the
     limit -- drawn in BAND MAP WORKED MULT COLOR.
     rwsWorked: worked, the count at or above the limit -- drawn as a worked
     multiplier always was. *)
   TRemMultWorkState = (rwsNeeded, rwsBackupWanted, rwsWorked);

(* THE STATE OF ONE CELL. aWorked is the sheet's bit, and it is the
  authority: a count without the bit is no working (rwsNeeded), and the bit
  with a count of 0 -- a flag the counts never saw -- is rwsWorked, never a
  backup, as LOGEDIT.DetermineMultStatus' "at least once" guard rules for
  the band map. aLimit is BAND MAP WORKED MULT LIMIT; at its default of 1 no
  cell is ever a backup. *)
function RemainingMultWorkState(const aWorked: boolean; const aCount, aLimit: integer): TRemMultWorkState;

(* THE TEXT OF ONE CELL: the multiplier's name, and ' <count>' after it when
  the sheet says it is worked AND the count is 2 or more ('Oh 2'). Once is
  what the worked look already says, so a single working adds no number. *)
function RemainingMultCellText(const aName: string; const aWorked: boolean; const aCount: integer): string;

implementation

uses
   SysUtils;

function RemainingMultWorkState(const aWorked: boolean; const aCount, aLimit: integer): TRemMultWorkState;
begin
   if not aWorked then
      begin
      Result := rwsNeeded;
      end
   else if (aCount >= 1) and (aCount < aLimit) then
      begin
      Result := rwsBackupWanted;
      end
   else
      begin
      Result := rwsWorked;
      end;
end;

function RemainingMultCellText(const aName: string; const aWorked: boolean; const aCount: integer): string;
begin
   if aWorked and (aCount >= 2) then
      begin
      Result := aName + ' ' + IntToStr(aCount);
      end
   else
      begin
      Result := aName;
      end;
end;

end.

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
  limit; uRemMults gathers them, LOGEDIT.ShowRemMultsInWindow applies the
  first two functions, and the form asks RemainingMultCellStyle how the state
  looks (flat; the gradient is gone). Pinned by uTestRemMultWorkState. *)

{$I tr4w.inc}

interface

type
   (* rwsNeeded: not worked on the window's band and mode (the sheet's bit).
     rwsBackupWanted: worked, and the count is at least 1 and below the
     limit -- drawn in BAND MAP WORKED MULT COLOR.
     rwsWorked: worked, the count at or above the limit -- a flat cell of the
     window's text colour (black by default), as RemainingMultCellStyle
     says. *)
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

(* HOW A CELL LOOKS -- the UI refresh proposal's "Multiplier and related
  grids" (docs/TR4W_UI_REFRESH_PROPOSAL.md, GRID_RESTYLE_PLAN.md), and NY4I's
  ruling of 2026-11-22 on the worked cell. Every fill is FLAT; there is no
  gradient:

    rwsNeeded       the window's own text on the window, no fill: a needed
                    multiplier is not highlighted at all.
    rwsWorked       INVERTED -- a fill of the window's TEXT colour under the
                    window's own colour: black under white by default, as the
                    pre-refresh worked cell was (it faded black to white
                    under white text; NY4I wants the black back, flat). It
                    follows the window, so a dark theme inverts too. Should
                    the two colours not read on each other (below
                    MIN_TEXT_CONTRAST) the text is ReadableTextOn the fill.
    rwsBackupWanted a FLAT fill of BAND MAP WORKED MULT COLOR (orange by
                    default; the band map's orange M, the same meaning and no
                    other), with black or white text, whichever reads better
                    on the operator's colour.

  aHiLight is REMAINING MULT DISPLAY MODE = HILIGHT. In any other mode the
  builder lists needed multipliers only and every cell is drawn as needed --
  as the gradient code drew nothing for them.

  EVERY COLOUR IS A RESOLVED RGB, $00BBGGRR (TColor's byte order): the
  caller resolves system colours (clWindow, clWindowText, BTNFACE) with
  Graphics.ColorToRGB first, because a system colour's value is an index with
  the high bit set, not a colour. aBold is the weight; it is False for every
  state today (a 49-px cell clips bold text, unmeasured -- BENCH_QUEUE). *)
procedure RemainingMultCellStyle(const aState: TRemMultWorkState; const aHiLight: boolean;
                                 const aWindowRGB, aTextRGB, aBackupRGB: longint;
                                 out aBackRGB, aForeRGB: longint; out aBold: boolean);

(* WCAG 2 relative luminance of a resolved $00BBGGRR colour: 0 for black,
  1 for white. *)
function RelativeLuminance(const aRGB: longint): double;

(* WCAG 2 contrast ratio of two resolved colours, 1 (identical) to 21 (black
  on white), whichever order they are given in. *)
function ContrastRatio(const aRGB1, aRGB2: longint): double;

(* Black or white, whichever contrasts more with aBackRGB. The better of the
  two never falls below about 4.58:1, so text chosen this way is readable on
  any colour the operator can pick. *)
function ReadableTextOn(const aBackRGB: longint): longint;

const
   RGB_BLACK = longint($000000);
   RGB_WHITE = longint($FFFFFF);
   (* The least contrast a worked cell's text may have on its fill before
     ReadableTextOn chooses it instead -- WCAG AA for body text, which
     ReadableTextOn itself always reaches. *)
   MIN_TEXT_CONTRAST = 4.5;

implementation

uses
   SysUtils, Math;

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

function ChannelLuminance(const aChannel: integer): double;
var
   c: double;
begin
   c := aChannel / 255.0;
   if c <= 0.03928 then
      begin
      Result := c / 12.92;
      end
   else
      begin
      Result := Power((c + 0.055) / 1.055, 2.4);
      end;
end;

function RelativeLuminance(const aRGB: longint): double;
var
   red: integer;
   green: integer;
   blue: integer;
begin
   red := aRGB and $FF;
   green := (aRGB shr 8) and $FF;
   blue := (aRGB shr 16) and $FF;
   Result := 0.2126 * ChannelLuminance(red) +
             0.7152 * ChannelLuminance(green) +
             0.0722 * ChannelLuminance(blue);
end;

function ContrastRatio(const aRGB1, aRGB2: longint): double;
var
   l1: double;
   l2: double;
begin
   l1 := RelativeLuminance(aRGB1);
   l2 := RelativeLuminance(aRGB2);
   if l1 >= l2 then
      begin
      Result := (l1 + 0.05) / (l2 + 0.05);
      end
   else
      begin
      Result := (l2 + 0.05) / (l1 + 0.05);
      end;
end;

function ReadableTextOn(const aBackRGB: longint): longint;
begin
   if ContrastRatio(aBackRGB, RGB_BLACK) >= ContrastRatio(aBackRGB, RGB_WHITE) then
      begin
      Result := RGB_BLACK;
      end
   else
      begin
      Result := RGB_WHITE;
      end;
end;

procedure RemainingMultCellStyle(const aState: TRemMultWorkState; const aHiLight: boolean;
                                 const aWindowRGB, aTextRGB, aBackupRGB: longint;
                                 out aBackRGB, aForeRGB: longint; out aBold: boolean);
var
   state: TRemMultWorkState;
begin
   state := aState;
   if not aHiLight then
      begin
      state := rwsNeeded;
      end;

   aBold := False;
   case state of
      rwsBackupWanted:
         begin
         aBackRGB := aBackupRGB;
         aForeRGB := ReadableTextOn(aBackupRGB);
         end;
      rwsWorked:
         begin
         aBackRGB := aTextRGB;
         if ContrastRatio(aWindowRGB, aTextRGB) >= MIN_TEXT_CONTRAST then
            begin
            aForeRGB := aWindowRGB;
            end
         else
            begin
            aForeRGB := ReadableTextOn(aTextRGB);
            end;
         end;
   else
      begin
      aBackRGB := aWindowRGB;
      aForeRGB := aTextRGB;
      end;
   end;
end;

end.

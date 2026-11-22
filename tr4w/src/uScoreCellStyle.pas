unit uScoreCellStyle;

(* HOW THE TOTALS GRID'S CELLS AND THE POINTS TOTAL LOOK -- the UI refresh
  proposal's "Band strip and log grid" (docs/TR4W_UI_REFRESH_PROPOSAL.md),
  the band strip and score cells only.

  The proposal: keep the solid blue active-band marker; flatten the idle band
  headers and the score cells with thin separators instead of the recessed
  edge; a slightly stronger weight for the points total; nothing moves.

  WHAT THIS UNIT DECIDES, AND WHAT IT DOES NOT.

    * The separator's colour, DERIVED from the colours the cell already has:
      its own background and its own text, both operator-chosen through the
      window colour roles. Nothing here is a new default colour, so a custom
      palette or a dark one gets a separator that belongs to it.
    * The points total's weight.

  It does not decide WHICH cells are flat (uMainGrids does: every totals cell,
  every band header but the active one, and the points total) or how the rule
  is drawn (TElementPanel, through the LCL's own TCustomPanel.BevelColor).

  A LEAF: no LCL, no globals, no settings, so uElementPanel can use it and
  still be linked by build/lintlfm, which has only the LCL. Pinned by
  uTestScoreCellStyle. *)

{$I tr4w.inc}

interface

(* THE COLOUR OF A FLAT CELL'S 1 PX RULE.

  The cell's background blended toward the cell's own text colour, starting at
  FLAT_RULE_START_PERCENT and stepping by FLAT_RULE_STEP_PERCENT until the rule
  reaches FLAT_RULE_MIN_CONTRAST against the background, at most
  FLAT_RULE_MAX_PERCENT. Blending toward the TEXT is what makes one rule serve
  every palette: on a light window it comes out a little darker than the
  window, on a dark one a little lighter, and it never takes the text's full
  weight.

  When the background and the text are one colour no blend can separate them
  and the result is that colour: the operator's palette already hides the
  text, and inventing a contrasting line would be a colour nobody chose.

  EVERY COLOUR IS A RESOLVED RGB, $00BBGGRR (TColor's byte order): the caller
  resolves system colours with Graphics.ColorToRGB first, because a system
  colour's value is an index with the high bit set, not a colour. *)
function FlatRuleRGB(const aBackRGB, aTextRGB: longint): longint;

(* THE POINTS TOTAL'S WEIGHT: bold, whatever the window's font is.

  A TFont offers exactly one step heavier than normal -- fsBold; there is no
  semibold to choose -- so "slightly stronger" is bold. When the operator's
  configured font is already bold (Settings.Font.Bold) there is no heavier
  step and the cell is simply bold like everything else, so it is never drawn
  lighter than its neighbours. *)
function PointsTotalBold(const aConfiguredBold: boolean): boolean;

const
   FLAT_RULE_START_PERCENT = 20;
   FLAT_RULE_STEP_PERCENT = 5;
   FLAT_RULE_MAX_PERCENT = 50;
   (* Enough to see a hairline, well short of the text's own contrast. The
     default look (black on the Windows button face, $F0F0F0) reaches it at
     the first step, as $C0C0C0. *)
   FLAT_RULE_MIN_CONTRAST = 1.3;

implementation

uses
   uRemMultWorkState;   (* ContrastRatio: one copy of the WCAG arithmetic *)

function BlendChannel(const aBack, aText, aPercent: integer): integer;
begin
   Result := aBack + ((aText - aBack) * aPercent) div 100;
end;

function BlendRGB(const aBackRGB, aTextRGB: longint; const aPercent: integer): longint;
var
   red: integer;
   green: integer;
   blue: integer;
begin
   red := BlendChannel(aBackRGB and $FF, aTextRGB and $FF, aPercent);
   green := BlendChannel((aBackRGB shr 8) and $FF, (aTextRGB shr 8) and $FF, aPercent);
   blue := BlendChannel((aBackRGB shr 16) and $FF, (aTextRGB shr 16) and $FF, aPercent);
   Result := longint(red or (green shl 8) or (blue shl 16));
end;

function FlatRuleRGB(const aBackRGB, aTextRGB: longint): longint;
var
   percent: integer;
   back: longint;
   text: longint;
begin
   (* Only the colour bytes: a caller that forgot to resolve a system colour
     must not hand the blend its index bit. *)
   back := aBackRGB and $FFFFFF;
   text := aTextRGB and $FFFFFF;

   percent := FLAT_RULE_START_PERCENT;
   Result := BlendRGB(back, text, percent);
   while (ContrastRatio(Result, back) < FLAT_RULE_MIN_CONTRAST) and
         (percent < FLAT_RULE_MAX_PERCENT) do
      begin
      percent := percent + FLAT_RULE_STEP_PERCENT;
      Result := BlendRGB(back, text, percent);
      end;
end;

function PointsTotalBold(const aConfiguredBold: boolean): boolean;
begin
   (* aConfiguredBold is named so the call site states what it was asked
     about; both answers are bold, for the reason given in the interface. *)
   Result := aConfiguredBold or True;
end;

end.

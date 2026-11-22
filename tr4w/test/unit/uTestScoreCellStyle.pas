unit uTestScoreCellStyle;

(* THE BAND STRIP AND SCORE CELLS' FLAT LOOK -- the UI refresh proposal's
  "Band strip and log grid" (2026-11-22).

  uScoreCellStyle derives the 1 px rule a flat totals cell draws from that
  cell's own background and text, and decides the points total's weight.
  These pin the colour at the default look, on a dark palette and on an
  operator's own colour, the byte order, the edges where the palette leaves
  nothing to separate, and that a rule never outweighs the text. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TScoreCellStyleTests = class(TTestCase)
   protected
      procedure Test_TheDefaultLookGetsALightGreyRule;
      procedure Test_AWhiteWindowGetsALightGreyRule;
      procedure Test_ADarkPaletteGetsARuleLighterThanItsBackground;
      procedure Test_AnOperatorsColourGetsARuleOfItsOwnHue;
      procedure Test_TheChannelsKeepTheirByteOrder;
      procedure Test_ALowContrastPaletteStopsAtTheCeiling;
      procedure Test_TextTheColourOfTheBackgroundGivesTheBackground;
      procedure Test_AnUnresolvedIndexBitIsIgnored;
      procedure Test_TheRuleNeverOutweighsTheText;
      procedure Test_ThePointsTotalIsBoldWhateverTheFont;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uRemMultWorkState,   (* ContrastRatio, RelativeLuminance *)
   uScoreCellStyle;

const
   (* GetSysColor(COLOR_BTNFACE) on Windows 10 and 11: what the default
     palette's trBtnFace resolves to, and so what every totals cell is. *)
   BTNFACE = longint($F0F0F0);
   BLACK = longint($000000);
   WHITE = longint($FFFFFF);
   DARK_BACK = longint($202020);
   DARK_TEXT = longint($E0E0E0);

procedure TScoreCellStyleTests.Test_TheDefaultLookGetsALightGreyRule;
var
   rule: longint;
begin
   BeginTest('Test_TheDefaultLookGetsALightGreyRule');
   rule := FlatRuleRGB(BTNFACE, BLACK);
   (* $F0 - $F0 / 5 = $C0 in every channel: the first step is enough. *)
   CheckEquals(longint($C0C0C0), rule, 'black on the button face: $C0C0C0');
   CheckTrue(ContrastRatio(rule, BTNFACE) >= FLAT_RULE_MIN_CONTRAST, 'the rule is visible');
   CheckTrue(RelativeLuminance(rule) < RelativeLuminance(BTNFACE), 'darker than the window');
end;

procedure TScoreCellStyleTests.Test_AWhiteWindowGetsALightGreyRule;
begin
   BeginTest('Test_AWhiteWindowGetsALightGreyRule');
   CheckEquals(longint($CCCCCC), FlatRuleRGB(WHITE, BLACK), 'black on white: $CCCCCC');
end;

procedure TScoreCellStyleTests.Test_ADarkPaletteGetsARuleLighterThanItsBackground;
var
   rule: longint;
begin
   BeginTest('Test_ADarkPaletteGetsARuleLighterThanItsBackground');
   rule := FlatRuleRGB(DARK_BACK, DARK_TEXT);
   CheckTrue(RelativeLuminance(rule) > RelativeLuminance(DARK_BACK), 'lighter than the dark window');
   CheckTrue(RelativeLuminance(rule) < RelativeLuminance(DARK_TEXT), 'darker than the light text');
   CheckTrue(ContrastRatio(rule, DARK_BACK) >= FLAT_RULE_MIN_CONTRAST, 'the rule is visible');
end;

procedure TScoreCellStyleTests.Test_AnOperatorsColourGetsARuleOfItsOwnHue;
var
   rule: longint;
begin
   BeginTest('Test_AnOperatorsColourGetsARuleOfItsOwnHue');
   (* Yellow ($00BBGGRR = $00FFFF) under black text: red and green fall by a
     fifth, blue stays at nothing -- a darker yellow, not a grey. *)
   rule := FlatRuleRGB(longint($00FFFF), BLACK);
   CheckEquals(longint($00CCCC), rule, 'a darker yellow');
   CheckTrue(ContrastRatio(rule, longint($00FFFF)) >= FLAT_RULE_MIN_CONTRAST, 'the rule is visible');
end;

procedure TScoreCellStyleTests.Test_TheChannelsKeepTheirByteOrder;
begin
   BeginTest('Test_TheChannelsKeepTheirByteOrder');
   (* White blended toward pure red ($0000FF): only green and blue move. A
     swapped byte order would move red and blue instead. *)
   CheckEquals(longint($CCCCFF), FlatRuleRGB(WHITE, longint($0000FF)), 'toward red');
   CheckEquals(longint($FFCCCC), FlatRuleRGB(WHITE, longint($FF0000)), 'toward blue');
end;

procedure TScoreCellStyleTests.Test_ALowContrastPaletteStopsAtTheCeiling;
begin
   BeginTest('Test_ALowContrastPaletteStopsAtTheCeiling');
   (* $80 against $90 never reaches the floor, so the blend stops at its
     ceiling: half way, $88. It terminates and never passes the text. *)
   CheckEquals(longint($888888), FlatRuleRGB(longint($808080), longint($909090)),
               'half way at the ceiling');
end;

procedure TScoreCellStyleTests.Test_TextTheColourOfTheBackgroundGivesTheBackground;
begin
   BeginTest('Test_TextTheColourOfTheBackgroundGivesTheBackground');
   (* Nothing to separate: the rule is the palette's own colour, never an
     invented one. *)
   CheckEquals(BTNFACE, FlatRuleRGB(BTNFACE, BTNFACE), 'the background itself');
end;

procedure TScoreCellStyleTests.Test_AnUnresolvedIndexBitIsIgnored;
begin
   BeginTest('Test_AnUnresolvedIndexBitIsIgnored');
   (* The top byte is not a colour. A caller that forgot ColorToRGB must not
     get it back in the rule. *)
   CheckEquals(longint($C0C0C0), FlatRuleRGB(longint($01F0F0F0), BLACK), 'the top byte is dropped');
end;

procedure TScoreCellStyleTests.Test_TheRuleNeverOutweighsTheText;
begin
   BeginTest('Test_TheRuleNeverOutweighsTheText');
   CheckTrue(ContrastRatio(FlatRuleRGB(BTNFACE, BLACK), BTNFACE) < ContrastRatio(BLACK, BTNFACE),
             'default: the text is stronger than the rule');
   CheckTrue(ContrastRatio(FlatRuleRGB(DARK_BACK, DARK_TEXT), DARK_BACK) <
             ContrastRatio(DARK_TEXT, DARK_BACK),
             'dark: the text is stronger than the rule');
end;

procedure TScoreCellStyleTests.Test_ThePointsTotalIsBoldWhateverTheFont;
begin
   BeginTest('Test_ThePointsTotalIsBoldWhateverTheFont');
   CheckTrue(PointsTotalBold(False), 'a regular window font: the total is bold');
   CheckTrue(PointsTotalBold(True), 'a bold window font: the total is not made lighter');
end;

procedure TScoreCellStyleTests.RunAllTests;
begin
   Test_TheDefaultLookGetsALightGreyRule;
   Test_AWhiteWindowGetsALightGreyRule;
   Test_ADarkPaletteGetsARuleLighterThanItsBackground;
   Test_AnOperatorsColourGetsARuleOfItsOwnHue;
   Test_TheChannelsKeepTheirByteOrder;
   Test_ALowContrastPaletteStopsAtTheCeiling;
   Test_TextTheColourOfTheBackgroundGivesTheBackground;
   Test_AnUnresolvedIndexBitIsIgnored;
   Test_TheRuleNeverOutweighsTheText;
   Test_ThePointsTotalIsBoldWhateverTheFont;
end;

end.

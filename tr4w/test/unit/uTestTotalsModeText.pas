unit uTestTotalsModeText;

(* BOTH MODES IN ONE TOTALS CELL -- issue 55 (NY4I's option (a)).

  uTotalsModeText words a multiplier row of the main window's totals grid when
  a contest counts multipliers by mode: '12/6' under 'CW/Ph Dom'. These pin
  that one mode is exactly what the cell showed before, the zero rules, large
  and three-digit counts, the label for every real caption pair, the fallback
  when a caption is off the shape -- and measure the widest likely text in
  the narrowest cell it lands in, through the cell's own fit
  (TElementPanel.FitCaption), not by counting characters. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TTotalsModeTextTests = class(TTestCase)
   protected
      procedure Test_OneCountIsWhatTheCellAlwaysShowed;
      procedure Test_BothModesShareOneCell;
      procedure Test_AZeroBesideACountIsShown;
      procedure Test_EveryZeroIsBlank;
      procedure Test_ThreeDigitAndLargeCounts;
      procedure Test_ThreeModesKeepTheirOrder;
      procedure Test_EveryRealCaptionPairJoinsItsModes;
      procedure Test_ACaptionOffTheShapeFallsBack;
      procedure Test_ADigitalSlotAloneIsLabelled;
      procedure Test_TheWidestTextFitsTheNarrowestAllColumn;
      procedure Test_TwoDigitCountsFitTheNarrowestBandColumn;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,
   Graphics,
   uElementPanel,
   uMainLayout,
   uTotalsModeText;

procedure TTotalsModeTextTests.Test_OneCountIsWhatTheCellAlwaysShowed;
begin
   BeginTest('Test_OneCountIsWhatTheCellAlwaysShowed');
   (* uTotal.iTotalTextOut's rule: blank for 0, else the number. *)
   CheckEquals('', TotalsModeCountsText([0]), 'one zero is blank');
   CheckEquals('12', TotalsModeCountsText([12]), 'one count is the number');
end;

procedure TTotalsModeTextTests.Test_BothModesShareOneCell;
begin
   BeginTest('Test_BothModesShareOneCell');
   CheckEquals('12/6', TotalsModeCountsText([12, 6]), 'CW then phone');
   CheckEquals('1/1', TotalsModeCountsText([1, 1]), 'single digits');
end;

procedure TTotalsModeTextTests.Test_AZeroBesideACountIsShown;
begin
   BeginTest('Test_AZeroBesideACountIsShown');
   (* The position says which mode a number belongs to, so a zero beside a
     count is written: blank would make '6' read as CW. *)
   CheckEquals('0/6', TotalsModeCountsText([0, 6]), 'no CW yet');
   CheckEquals('12/0', TotalsModeCountsText([12, 0]), 'no phone yet');
end;

procedure TTotalsModeTextTests.Test_EveryZeroIsBlank;
begin
   BeginTest('Test_EveryZeroIsBlank');
   CheckEquals('', TotalsModeCountsText([0, 0]), 'two zeros are blank, as one is');
   CheckEquals('', TotalsModeCountsText([0, 0, 0]), 'three zeros are blank');
end;

procedure TTotalsModeTextTests.Test_ThreeDigitAndLargeCounts;
begin
   BeginTest('Test_ThreeDigitAndLargeCounts');
   CheckEquals('123/456', TotalsModeCountsText([123, 456]), 'three digits each');
   CheckEquals('99/100', TotalsModeCountsText([99, 100]), 'two and three digits');
   (* The sheet's totals are Words: the largest a count can be. *)
   CheckEquals('65535/65535', TotalsModeCountsText([65535, 65535]), 'the largest counts');
end;

procedure TTotalsModeTextTests.Test_ThreeModesKeepTheirOrder;
begin
   BeginTest('Test_ThreeModesKeepTheirOrder');
   CheckEquals('12/6/3', TotalsModeCountsText([12, 6, 3]), 'CW, phone, digital');
   CheckEquals('0/0/3', TotalsModeCountsText([0, 0, 3]), 'digital only, still in place');
end;

procedure TTotalsModeTextTests.Test_EveryRealCaptionPairJoinsItsModes;
const
   (* Every CW / phone pair the contests give the totals (uContestBase and
     its overrides' GetTotalsDisplay, uTotal's DX row): the word after the
     tag. *)
   WORDS: array[0..9] of string =
      ('Dom', 'HQ', 'Pfxs', 'Grids', 'Clubs', 'Calls', 'Provs', 'Years', 'Zone', 'DX');
var
   i: integer;
begin
   BeginTest('Test_EveryRealCaptionPairJoinsItsModes');
   for i := Low(WORDS) to High(WORDS) do
      begin
      CheckEquals('CW/Ph ' + WORDS[i],
                  TotalsByModeCaption([TOTALS_TAG_CW, TOTALS_TAG_PHONE],
                                      'CW ' + WORDS[i], 'Ph ' + WORDS[i], 'fallback'),
                  'CW ' + WORDS[i] + ' and Ph ' + WORDS[i]);
      end;
   CheckEquals('CW/Ph/Dig Dom',
               TotalsByModeCaption([TOTALS_TAG_CW, TOTALS_TAG_PHONE, TOTALS_TAG_DIGITAL],
                                   'CW Dom', 'Ph Dom', 'Dom Mults'),
               'three modes');
end;

procedure TTotalsModeTextTests.Test_ACaptionOffTheShapeFallsBack;
begin
   BeginTest('Test_ACaptionOffTheShapeFallsBack');
   CheckEquals('Dom Mults',
               TotalsByModeCaption([TOTALS_TAG_CW, TOTALS_TAG_PHONE], 'Oblasts', 'Ph Dom', 'Dom Mults'),
               'a CW caption without its tag');
   CheckEquals('Dom Mults',
               TotalsByModeCaption([TOTALS_TAG_CW, TOTALS_TAG_PHONE], 'CW Dom', 'Ph HQ', 'Dom Mults'),
               'two captions that name different things');
   CheckEquals('Dom Mults',
               TotalsByModeCaption([TOTALS_TAG_CW, TOTALS_TAG_PHONE], 'CW ', 'Ph ', 'Dom Mults'),
               'a tag with nothing after it');
   CheckEquals('Dom Mults',
               TotalsByModeCaption([TOTALS_TAG_CW, TOTALS_TAG_PHONE], 'CWDom', 'PhDom', 'Dom Mults'),
               'no space after the tag');
end;

procedure TTotalsModeTextTests.Test_ADigitalSlotAloneIsLabelled;
begin
   BeginTest('Test_ADigitalSlotAloneIsLabelled');
   (* Before issue 55 a digital active mode wrote NO multiplier label, and the
     numbers slid up a row. *)
   CheckEquals('Dig Dom',
               TotalsByModeCaption([TOTALS_TAG_DIGITAL], 'CW Dom', 'Ph Dom', 'Dom Mults'),
               'digital alone');
end;

(* HOW WIDE aText IS WHEN THE CELL ITSELF HAS FITTED IT into aWidth: a real
  TElementPanel, captioned and fitted as uMainGrids.PositionMainGrids fits a
  totals cell, then aText measured in the font the fit chose. The default
  main window font: Arial, bold (uSettingsModel), at the LARGEST FONT SIZE
  step at that scale (ws + 2 * 2 - 3, MainUnit.MainFontCellHeight) -- the fit
  shrinks to the same floor from any start. *)
function FittedTextWidth(const aText: string; const aWidth: integer): integer;
var
   panel: TElementPanel;
   measure: TBitmap;
begin
   (* The widget set must be up before a canvas measures. Repeat calls are
     harmless -- uTestAltPRows makes the same one. *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;

   panel := TElementPanel.Create(nil);
   measure := TBitmap.Create;
   try
      panel.Width := aWidth;
      panel.Font.Name := 'Arial';
      panel.Font.Style := [fsBold];
      panel.Caption := aText;
      panel.SetFittedFontHeight(WS_MIN + 2 * 2 - 3);

      measure.SetSize(1, 1);
      measure.Canvas.Font.Assign(panel.Font);
      Result := measure.Canvas.TextWidth(aText);
   finally
      measure.Free;
      panel.Free;
   end;
end;

procedure TTotalsModeTextTests.Test_TheWidestTextFitsTheNarrowestAllColumn;
var
   left, width: integer;
begin
   BeginTest('Test_TheWidestTextFitsTheNarrowestAllColumn');
   (* ARRL 10 Meter does not count multipliers by band, so its multiplier
     cells are the All column only. Three digits a mode is more than the
     contest has (about 96 domestic multipliers); the bevel takes 4 px. *)
   TotalsColumnGeometry(WS_MIN, TOTALS_COLUMNS - 1, left, width);
   CheckTrue(FittedTextWidth('123/456', width) <= width - 4,
             'the All column at the smallest scale holds 123/456');
end;

procedure TTotalsModeTextTests.Test_TwoDigitCountsFitTheNarrowestBandColumn;
var
   left, width: integer;
begin
   BeginTest('Test_TwoDigitCountsFitTheNarrowestBandColumn');
   (* A contest that counts multipliers by band AND by mode puts the pair in
     every band column, the narrowest cell of the grid. *)
   TotalsColumnGeometry(WS_MIN, 1, left, width);
   CheckTrue(FittedTextWidth('99/99', width) <= width - 4,
             'a band column at the smallest scale holds 99/99');
end;

procedure TTotalsModeTextTests.RunAllTests;
begin
   Test_OneCountIsWhatTheCellAlwaysShowed;
   Test_BothModesShareOneCell;
   Test_AZeroBesideACountIsShown;
   Test_EveryZeroIsBlank;
   Test_ThreeDigitAndLargeCounts;
   Test_ThreeModesKeepTheirOrder;
   Test_EveryRealCaptionPairJoinsItsModes;
   Test_ACaptionOffTheShapeFallsBack;
   Test_ADigitalSlotAloneIsLabelled;
   Test_TheWidestTextFitsTheNarrowestAllColumn;
   Test_TwoDigitCountsFitTheNarrowestBandColumn;
end;

end.

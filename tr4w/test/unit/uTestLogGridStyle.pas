unit uTestLogGridStyle;

(* HOW A LOG ROW LOOKS -- the UI refresh proposal's "Band strip and log grid"
  (docs/TR4W_UI_REFRESH_PROPOSAL.md), 2026-11-22.

  uLogGrid's DrawCell asks four pure functions: LogSoftRuleColor (the
  vertical rule, derived from the window colour), LogCellFontStyle (the
  callsign's weight), LogColumnAlignment (numbers right-aligned) and
  LogRowColors (ordinary, deleted and X-QSO rows, selected or not). These pin
  the decisions; how they look on a screen is on docs/BENCH_QUEUE.md. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLogGridStyleTests = class(TTestCase)
   protected
      procedure Test_TheSoftRuleIsSofterThanTheLCLDefaultAndStillSeen;
      procedure Test_TheSoftRuleIsSeenOnEveryPaletteWindow;
      procedure Test_TheSoftRuleMovesTowardTheText;
      procedure Test_OnlyTheCallsignIsBold;
      procedure Test_TheNumbersAreRightAligned;
      procedure Test_OtherColumnsKeepTheirDeclaredAlignment;
      procedure Test_RowStylesStayDistinctWithSelectionOnAndOff;
      procedure Test_DeletedWinsOverXQSO;
      procedure Test_AnOperatorsColoursAreUsedAsGiven;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes,           (* TAlignment *)
   Graphics,          (* fsBold, clSilver, clRed, clGray *)
   VC,                (* LogColumnsType, the palette, LVCFMT_ via ColumnsArray *)
   uRemMultWorkState, (* ContrastRatio, RelativeLuminance *)
   uLogGrid;

const
   (* THE DEFAULT LOOK: the log's white window and black text
     (TR4WEditableLogApplyColors' defaults) and the grid's SelectedColor,
     the pale blue TLogGrid.Create states. *)
   WINDOW_RGB   = longint($FFFFFF);
   TEXT_RGB     = longint($000000);
   SELECTED_RGB = longint($FFDEC5);

   (* WHAT EVERY ROW'S TEXT MUST REACH ON ITS OWN BACKGROUND. Measured, not
     wished: the X-QSO grey on the selection blue is 2.87:1 and the deleted
     red 2.91:1 -- the colours the program has always used, which this work
     does not change (the brief: do not change an operator's colours). 2.5
     holds them there; a change that makes either worse fails. *)
   MIN_ROW_TEXT_CONTRAST = 2.5;

function AlignName(const aAlign: TAlignment): string;
begin
   case aAlign of
      taRightJustify:
         begin
         Result := 'right';
         end;
      taCenter:
         begin
         Result := 'centre';
         end;
   else
      begin
      Result := 'left';
      end;
   end;
end;

procedure TLogGridStyleTests.Test_TheSoftRuleIsSofterThanTheLCLDefaultAndStillSeen;
var
   rule: longint;
begin
   BeginTest('Test_TheSoftRuleIsSofterThanTheLCLDefaultAndStillSeen');
   rule := LogSoftRuleColor(WINDOW_RGB);
   CheckTrue(rule <> WINDOW_RGB, 'the rule is not the window');
   CheckTrue(ContrastRatio(rule, WINDOW_RGB) >= LOG_RULE_MIN_CONTRAST,
             'the rule is still seen on white');
   (* clSilver is the LCL's GridLineColor default: "softer" means less
     contrast against the window than that. *)
   CheckTrue(ContrastRatio(rule, WINDOW_RGB) < ContrastRatio(longint(clSilver), WINDOW_RGB),
             'the rule is softer than the LCL''s silver');
end;

procedure TLogGridStyleTests.Test_TheSoftRuleIsSeenOnEveryPaletteWindow;
var
   c:    tr4wColors;
   back: longint;
   rule: longint;
begin
   BeginTest('Test_TheSoftRuleIsSeenOnEveryPaletteWindow');
   for c := Low(tr4wColors) to High(tr4wColors) do
      begin
      (* BTNFACE and HIGHLIGHT are system colours; the grid resolves them
        with ColorToRGB before it asks, which a leaf test cannot. *)
      if (c = trBtnFace) or (c = trHighlight) then
         begin
         Continue;
         end;
      back := longint(tr4wColorsArray[c]) and $FFFFFF;
      rule := LogSoftRuleColor(back);
      CheckTrue(rule <> back, 'a rule apart from ' + tr4wColorsSA[c]);
      CheckTrue(ContrastRatio(rule, back) >= LOG_RULE_MIN_CONTRAST,
                'the rule is seen on ' + tr4wColorsSA[c]);
      end;
end;

procedure TLogGridStyleTests.Test_TheSoftRuleMovesTowardTheText;
begin
   BeginTest('Test_TheSoftRuleMovesTowardTheText');
   (* A light window gets a darker rule, a dark window a lighter one: the
     rule is derived from the window, not a fixed grey. *)
   CheckTrue(RelativeLuminance(LogSoftRuleColor(WINDOW_RGB)) < RelativeLuminance(WINDOW_RGB),
             'darker than a white window');
   CheckTrue(RelativeLuminance(LogSoftRuleColor(TEXT_RGB)) > RelativeLuminance(TEXT_RGB),
             'lighter than a black window');
   CheckTrue(LogSoftRuleColor(WINDOW_RGB) <> LogSoftRuleColor(longint($C0FFFF)),
             'a different window gives a different rule');
end;

procedure TLogGridStyleTests.Test_OnlyTheCallsignIsBold;
var
   c: LogColumnsType;
begin
   BeginTest('Test_OnlyTheCallsignIsBold');
   CheckTrue(LogCellFontStyle(logColCallsign, []) = [fsBold], 'the callsign is bold');
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if c = logColCallsign then
         begin
         Continue;
         end;
      CheckTrue(LogCellFontStyle(c, []) = [], 'no other column is bold (' +
                ColumnCanonicalName[c] + ')');
      end;
   (* The operator's own style survives: an italic font stays italic, and a
     bold one is not made anything else. *)
   CheckTrue(LogCellFontStyle(logColCallsign, [fsItalic]) = [fsItalic, fsBold],
             'italic kept, bold added');
   CheckTrue(LogCellFontStyle(logColCallsign, [fsBold]) = [fsBold],
             'an already bold font is unchanged');
   CheckTrue(LogCellFontStyle(logColFreq, [fsBold]) = [fsBold],
             'a bold font stays bold in every column');
end;

procedure TLogGridStyleTests.Test_TheNumbersAreRightAligned;
begin
   BeginTest('Test_TheNumbersAreRightAligned');
   CheckEquals('right', AlignName(LogColumnAlignment(logColNumberSent,
                ColumnsArray[logColNumberSent].Align)), 'the serial sent');
   CheckEquals('right', AlignName(LogColumnAlignment(logColNumberReceive,
                ColumnsArray[logColNumberReceive].Align)), 'the serial received');
   CheckEquals('right', AlignName(LogColumnAlignment(logColPoints,
                ColumnsArray[logColPoints].Align)), 'the QSO points (declared centre)');
   CheckEquals('right', AlignName(LogColumnAlignment(logColFreq,
                ColumnsArray[logColFreq].Align)), 'the frequency (declared centre)');
end;

procedure TLogGridStyleTests.Test_OtherColumnsKeepTheirDeclaredAlignment;
begin
   BeginTest('Test_OtherColumnsKeepTheirDeclaredAlignment');
   CheckEquals('left', AlignName(LogColumnAlignment(logColCallsign,
               ColumnsArray[logColCallsign].Align)), 'the callsign');
   CheckEquals('centre', AlignName(LogColumnAlignment(logColBand,
               ColumnsArray[logColBand].Align)), 'the band');
   CheckEquals('centre', AlignName(LogColumnAlignment(logColTime,
               ColumnsArray[logColTime].Align)), 'the time');
   CheckEquals('left', AlignName(LogColumnAlignment(logColOperator,
               ColumnsArray[logColOperator].Align)), 'the operator');
   (* The flag is read as declared, whatever ColumnsArray holds. *)
   CheckEquals('right', AlignName(LogColumnAlignment(logColName, LVCFMT_RIGHT)), 'a declared right');
end;

procedure TLogGridStyleTests.Test_RowStylesStayDistinctWithSelectionOnAndOff;
var
   sel:      boolean;
   backN, foreN: longint;
   backD, foreD: longint;
   backX, foreX: longint;
   backUnsel, foreUnsel: longint;
   label_:   string;
begin
   BeginTest('Test_RowStylesStayDistinctWithSelectionOnAndOff');
   for sel := False to True do
      begin
      if sel then
         begin
         label_ := 'selected';
         end
      else
         begin
         label_ := 'not selected';
         end;

      LogRowColors(False, False, sel, WINDOW_RGB, TEXT_RGB, SELECTED_RGB, backN, foreN);
      LogRowColors(True, False, sel, WINDOW_RGB, TEXT_RGB, SELECTED_RGB, backD, foreD);
      LogRowColors(False, True, sel, WINDOW_RGB, TEXT_RGB, SELECTED_RGB, backX, foreX);

      CheckTrue(foreN <> foreD, 'ordinary and deleted differ, ' + label_);
      CheckTrue(foreN <> foreX, 'ordinary and X-QSO differ, ' + label_);
      CheckTrue(foreD <> foreX, 'deleted and X-QSO differ, ' + label_);

      CheckTrue(ContrastRatio(foreN, backN) >= MIN_ROW_TEXT_CONTRAST, 'ordinary reads, ' + label_);
      CheckTrue(ContrastRatio(foreD, backD) >= MIN_ROW_TEXT_CONTRAST, 'deleted reads, ' + label_);
      CheckTrue(ContrastRatio(foreX, backX) >= MIN_ROW_TEXT_CONTRAST, 'X-QSO reads, ' + label_);
      end;

   (* The selection moves the background and nothing else, so red and grey
     keep their meanings on the selected row. *)
   LogRowColors(True, False, False, WINDOW_RGB, TEXT_RGB, SELECTED_RGB, backUnsel, foreUnsel);
   LogRowColors(True, False, True, WINDOW_RGB, TEXT_RGB, SELECTED_RGB, backD, foreD);
   CheckTrue(backUnsel <> backD, 'a selected row has its own background');
   CheckEquals(foreUnsel, foreD, 'a deleted row stays red when selected');
   CheckEquals(WINDOW_RGB, backUnsel, 'an unselected row is the window');
   CheckEquals(SELECTED_RGB, backD, 'a selected row is SelectedColor');
end;

procedure TLogGridStyleTests.Test_DeletedWinsOverXQSO;
var
   back, fore: longint;
begin
   BeginTest('Test_DeletedWinsOverXQSO');
   LogRowColors(True, True, False, WINDOW_RGB, TEXT_RGB, SELECTED_RGB, back, fore);
   CheckEquals(longint(clRed), fore, 'a deleted X-QSO is drawn deleted');
end;

procedure TLogGridStyleTests.Test_AnOperatorsColoursAreUsedAsGiven;
var
   back, fore: longint;
begin
   BeginTest('Test_AnOperatorsColoursAreUsedAsGiven');
   (* A dark log: the operator's window and text pass straight through. *)
   LogRowColors(False, False, False, longint($202020), longint($E0E0E0), SELECTED_RGB, back, fore);
   CheckEquals(longint($202020), back, 'the operator''s window');
   CheckEquals(longint($E0E0E0), fore, 'the operator''s text');
end;

procedure TLogGridStyleTests.RunAllTests;
begin
   Test_TheSoftRuleIsSofterThanTheLCLDefaultAndStillSeen;
   Test_TheSoftRuleIsSeenOnEveryPaletteWindow;
   Test_TheSoftRuleMovesTowardTheText;
   Test_OnlyTheCallsignIsBold;
   Test_TheNumbersAreRightAligned;
   Test_OtherColumnsKeepTheirDeclaredAlignment;
   Test_RowStylesStayDistinctWithSelectionOnAndOff;
   Test_DeletedWinsOverXQSO;
   Test_AnOperatorsColoursAreUsedAsGiven;
end;

end.

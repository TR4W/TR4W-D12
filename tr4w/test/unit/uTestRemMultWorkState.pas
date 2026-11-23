unit uTestRemMultWorkState;

(* THE REMAINING-MULTIPLIER CELL'S WORKINGS -- issue 357.

  uRemMultWorkState decides, from the sheet's worked bit, its count and BAND
  MAP WORKED MULT LIMIT, whether a cell is needed, a backup wanted (the
  orange) or worked, and whether its text carries the count. These pin the
  rule the band map already follows (issue 12) and the edges where the bit
  and the count disagree. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TRemMultWorkStateTests = class(TTestCase)
   protected
      procedure Test_NotWorkedIsNeededWhateverTheCount;
      procedure Test_AtTheDefaultLimitNothingIsABackup;
      procedure Test_BelowTheLimitIsABackup;
      procedure Test_AtOrAboveTheLimitIsWorked;
      procedure Test_TheBitWithNoCountIsWorkedNotABackup;
      procedure Test_TheTextCarriesACountOfTwoOrMore;
      procedure Test_TheTextCarriesNoCountWithoutTheBit;
      (* THE WIRING: uRemMults.ResolveRemainingMult reads the count from the
        cell LOGDUPE.CountWorkedMultipliers writes. Were the keys to differ
        every count would read 0 and the window would look exactly as before,
        with no error -- so this is the one check that sees it. *)
      procedure Test_TheWindowReadsTheSheetsZoneCount;

      (* HOW A CELL LOOKS (the UI refresh proposal's "Multiplier and related
        grids", and NY4I's ruling of 2026-11-22 on the worked cell): flat, no
        gradient; needed plain, worked inverted, backup orange. *)
      procedure Test_LuminanceAndContrastAtTheEnds;
      procedure Test_ANeededCellIsTheWindowsOwnText;
      procedure Test_AWorkedCellIsTheTextColourUnderTheWindowColour;
      procedure Test_AWorkedCellInvertsOnADarkWindowToo;
      procedure Test_AWorkedCellWhoseColoursWouldNotReadGetsReadableText;
      procedure Test_ABackupIsAFlatFillOfTheOperatorsColour;
      procedure Test_EveryPaletteColourGetsReadableBackupText;
      procedure Test_EveryStateReadsInTheDefaultColours;
      procedure Test_OutsideHiLightEveryCellIsDrawnNeeded;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC,               (* MultBand, MultMode, BandType, ModeType; the palette *)
   uMults,           (* mo *)
   uSettingsModel,   (* Settings.Mult.ByBand / ByMode *)
   uRemMults,        (* ResolveRemainingMult *)
   uRemMultWorkState;

function StateName(const aState: TRemMultWorkState): string;
begin
   case aState of
      rwsNeeded:
         begin
         Result := 'needed';
         end;
      rwsBackupWanted:
         begin
         Result := 'backup';
         end;
   else
      begin
      Result := 'worked';
      end;
   end;
end;

procedure TRemMultWorkStateTests.Test_NotWorkedIsNeededWhateverTheCount;
begin
   BeginTest('Test_NotWorkedIsNeededWhateverTheCount');
   CheckEquals('needed', StateName(RemainingMultWorkState(False, 0, 1)), 'count 0, limit 1');
   CheckEquals('needed', StateName(RemainingMultWorkState(False, 0, 3)), 'count 0, limit 3');
   (* The bit is the authority: a count the bit does not agree with is not a
     working the window shows. *)
   CheckEquals('needed', StateName(RemainingMultWorkState(False, 2, 3)), 'count 2 without the bit');
end;

procedure TRemMultWorkStateTests.Test_AtTheDefaultLimitNothingIsABackup;
begin
   BeginTest('Test_AtTheDefaultLimitNothingIsABackup');
   CheckEquals('worked', StateName(RemainingMultWorkState(True, 1, 1)), 'once, limit 1');
   CheckEquals('worked', StateName(RemainingMultWorkState(True, 5, 1)), 'five times, limit 1');
end;

procedure TRemMultWorkStateTests.Test_BelowTheLimitIsABackup;
begin
   BeginTest('Test_BelowTheLimitIsABackup');
   CheckEquals('backup', StateName(RemainingMultWorkState(True, 1, 2)), 'once, limit 2');
   CheckEquals('backup', StateName(RemainingMultWorkState(True, 1, 3)), 'once, limit 3');
   CheckEquals('backup', StateName(RemainingMultWorkState(True, 2, 3)), 'twice, limit 3');
end;

procedure TRemMultWorkStateTests.Test_AtOrAboveTheLimitIsWorked;
begin
   BeginTest('Test_AtOrAboveTheLimitIsWorked');
   CheckEquals('worked', StateName(RemainingMultWorkState(True, 2, 2)), 'twice, limit 2');
   CheckEquals('worked', StateName(RemainingMultWorkState(True, 3, 2)), 'three times, limit 2');
   CheckEquals('worked', StateName(RemainingMultWorkState(True, 9, 9)), 'nine times, limit 9');
end;

procedure TRemMultWorkStateTests.Test_TheBitWithNoCountIsWorkedNotABackup;
begin
   BeginTest('Test_TheBitWithNoCountIsWorkedNotABackup');
   (* A flag the counts never saw: shown worked, as the band map's "at least
     once" guard rules, never as a backup. *)
   CheckEquals('worked', StateName(RemainingMultWorkState(True, 0, 3)), 'the bit, count 0, limit 3');
end;

procedure TRemMultWorkStateTests.Test_TheTextCarriesACountOfTwoOrMore;
begin
   BeginTest('Test_TheTextCarriesACountOfTwoOrMore');
   CheckEquals('Oh', RemainingMultCellText('Oh', True, 0), 'worked, count 0');
   CheckEquals('Oh', RemainingMultCellText('Oh', True, 1), 'worked once');
   CheckEquals('Oh 2', RemainingMultCellText('Oh', True, 2), 'worked twice');
   CheckEquals('05 12', RemainingMultCellText('05', True, 12), 'a zone worked twelve times');
end;

procedure TRemMultWorkStateTests.Test_TheTextCarriesNoCountWithoutTheBit;
begin
   BeginTest('Test_TheTextCarriesNoCountWithoutTheBit');
   CheckEquals('Oh', RemainingMultCellText('Oh', False, 0), 'needed, count 0');
   CheckEquals('Oh', RemainingMultCellText('Oh', False, 3), 'a count without the bit');
end;

procedure TRemMultWorkStateTests.Test_TheWindowReadsTheSheetsZoneCount;
var
   savedByBand: boolean;
   savedByMode: boolean;
   savedMultBand: BandType;
   savedMultMode: ModeType;
   cellText: string;
   worked: boolean;
   workedCount: integer;
begin
   BeginTest('Test_TheWindowReadsTheSheetsZoneCount');
   savedByBand := Settings.Mult.ByBand;
   savedByMode := Settings.Mult.ByMode;
   savedMultBand := MultBand;
   savedMultMode := MultMode;
   try
      mo.ClearAllMults;
      (* Multipliers per band, not per mode: the window's keys are then the
        real band and Both, as logwind sets MultBand and MultMode. *)
      Settings.Mult.ByBand := True;
      Settings.Mult.ByMode := False;

      (* Zone 5 worked twice on 20 m CW, as AddQSOToSheets records it: the
        bit once (SetMultFlags, first working only), the count per QSO. *)
      mo.SetZnMult(5, Band20, CW);
      mo.CountWorked(rmZone, '5', Band20, CW);
      mo.CountWorked(rmZone, '5', Band20, CW);

      MultBand := Band20;
      MultMode := Both;
      ResolveRemainingMult(rmZone, 5, nil, cellText, worked, workedCount);
      CheckEquals('05', cellText, 'the zone''s name');
      CheckTrue(worked, 'zone 5 is worked on 20 m');
      CheckEquals(2, workedCount, 'zone 5 is worked twice on 20 m');
      CheckEquals('05 2', RemainingMultCellText(cellText, worked, workedCount), 'the cell text');

      (* Per band: 40 m has neither the bit nor a count. *)
      MultBand := Band40;
      ResolveRemainingMult(rmZone, 5, nil, cellText, worked, workedCount);
      CheckFalse(worked, 'zone 5 is not worked on 40 m');
      CheckEquals(0, workedCount, 'zone 5 has no count on 40 m');
   finally
      mo.ClearAllMults;
      Settings.Mult.ByBand := savedByBand;
      Settings.Mult.ByMode := savedByMode;
      MultBand := savedMultBand;
      MultMode := savedMultMode;
   end;
end;

const
   (* THE DEFAULT LOOK, RESOLVED: a white window and black text, what
     ColorToRGB(clWindow) and ColorToRGB(clWindowText) give the form on a
     default Windows 10 or 11. A dark theme is the pair the other way round,
     not quite black and white. *)
   DEFAULT_WINDOW = longint($FFFFFF);
   DEFAULT_TEXT = longint($000000);
   DARK_WINDOW = longint($1E1E1E);
   DARK_TEXT = longint($F0F0F0);
   (* WCAG AA for body text: what every state's text must reach on its
     fill. Stated here, not read from MIN_TEXT_CONTRAST, so a lowered
     constant fails the tests rather than moving them. *)
   READABLE_CONTRAST = 4.5;

procedure TRemMultWorkStateTests.Test_LuminanceAndContrastAtTheEnds;
begin
   BeginTest('Test_LuminanceAndContrastAtTheEnds');
   CheckTrue(Abs(RelativeLuminance(RGB_BLACK)) < 0.0001, 'black has no luminance');
   CheckTrue(Abs(RelativeLuminance(RGB_WHITE) - 1.0) < 0.0001, 'white has luminance 1');
   CheckTrue(Abs(ContrastRatio(RGB_BLACK, RGB_WHITE) - 21.0) < 0.001, 'black on white is 21:1');
   CheckTrue(Abs(ContrastRatio(RGB_WHITE, RGB_BLACK) - 21.0) < 0.001, 'the order does not matter');
   CheckTrue(Abs(ContrastRatio(DARK_WINDOW, DARK_WINDOW) - 1.0) < 0.001, 'a colour on itself is 1:1');
   (* $00BBGGRR: pure red and pure blue are NOT the same luminance -- green
     and red weigh far more than blue. A swapped byte order would fail it. *)
   CheckTrue(RelativeLuminance(longint($0000FF)) > RelativeLuminance(longint($FF0000)),
             'red ($0000FF) is brighter than blue ($FF0000)');
end;

procedure TRemMultWorkStateTests.Test_ANeededCellIsTheWindowsOwnText;
var
   back: longint;
   fore: longint;
   bold: boolean;
begin
   BeginTest('Test_ANeededCellIsTheWindowsOwnText');
   RemainingMultCellStyle(rwsNeeded, True, DEFAULT_WINDOW, DEFAULT_TEXT,
                          longint($00A5FF), back, fore, bold);
   CheckEquals(DEFAULT_WINDOW, back, 'no fill: the window');
   CheckEquals(DEFAULT_TEXT, fore, 'the window''s own text');
   CheckFalse(bold, 'normal weight');
   CheckTrue(ContrastRatio(fore, back) >= READABLE_CONTRAST, 'needed text reads');
end;

procedure TRemMultWorkStateTests.Test_AWorkedCellIsTheTextColourUnderTheWindowColour;
var
   back: longint;
   fore: longint;
   bold: boolean;
begin
   BeginTest('Test_AWorkedCellIsTheTextColourUnderTheWindowColour');
   (* NY4I, 2026-11-22: a worked multiplier is a BLACK cell with white text,
     as before the refresh, but flat. *)
   RemainingMultCellStyle(rwsWorked, True, DEFAULT_WINDOW, DEFAULT_TEXT,
                          longint($00A5FF), back, fore, bold);
   CheckEquals(RGB_BLACK, back, 'a black fill: the window''s text colour');
   CheckEquals(RGB_WHITE, fore, 'white text: the window''s colour');
   CheckFalse(bold, 'normal weight');
   CheckTrue(ContrastRatio(fore, back) >= READABLE_CONTRAST, 'worked text reads');
end;

procedure TRemMultWorkStateTests.Test_AWorkedCellInvertsOnADarkWindowToo;
var
   back: longint;
   fore: longint;
   bold: boolean;
begin
   BeginTest('Test_AWorkedCellInvertsOnADarkWindowToo');
   (* A dark theme: the fill follows the window's TEXT colour, so a worked
     cell is light on a dark window -- never a black cell lost in it. *)
   RemainingMultCellStyle(rwsWorked, True, DARK_WINDOW, DARK_TEXT,
                          longint($00A5FF), back, fore, bold);
   CheckEquals(DARK_TEXT, back, 'the dark theme''s light text colour as the fill');
   CheckEquals(DARK_WINDOW, fore, 'the dark window''s colour as the text');
   CheckTrue(ContrastRatio(fore, back) >= READABLE_CONTRAST, 'and it reads');

   (* Needed on the same dark window: the window and its text, no fill. *)
   RemainingMultCellStyle(rwsNeeded, True, DARK_WINDOW, DARK_TEXT,
                          longint($00A5FF), back, fore, bold);
   CheckEquals(DARK_WINDOW, back, 'needed, dark: the window');
   CheckEquals(DARK_TEXT, fore, 'needed, dark: the window''s text');
end;

procedure TRemMultWorkStateTests.Test_AWorkedCellWhoseColoursWouldNotReadGetsReadableText;
var
   back: longint;
   fore: longint;
   bold: boolean;
begin
   BeginTest('Test_AWorkedCellWhoseColoursWouldNotReadGetsReadableText');
   (* A theme whose window and text are two near greys: inverted, the window
     colour would not read on the fill, so the text is black or white,
     whichever reads on it. The fill is still the text colour. *)
   RemainingMultCellStyle(rwsWorked, True, longint($808080), longint($909090),
                          longint($00A5FF), back, fore, bold);
   CheckEquals(longint($909090), back, 'the fill is still the text colour');
   CheckEquals(ReadableTextOn(longint($909090)), fore, 'black or white, whichever reads');
   CheckTrue(ContrastRatio(fore, back) >= READABLE_CONTRAST, 'and it reads');
end;

procedure TRemMultWorkStateTests.Test_ABackupIsAFlatFillOfTheOperatorsColour;
var
   back: longint;
   fore: longint;
   bold: boolean;
begin
   BeginTest('Test_ABackupIsAFlatFillOfTheOperatorsColour');
   (* The default BAND MAP WORKED MULT COLOR, ORANGE: a flat orange cell
     under black text, as the fade's left edge was. *)
   RemainingMultCellStyle(rwsBackupWanted, True, DEFAULT_WINDOW, DEFAULT_TEXT,
                          longint(tr4wColorsArray[trOrange]), back, fore, bold);
   CheckEquals(longint(tr4wColorsArray[trOrange]), back, 'the orange, flat');
   CheckEquals(RGB_BLACK, fore, 'black text on orange');
   CheckFalse(bold, 'normal weight');
   CheckTrue(ContrastRatio(fore, back) >= READABLE_CONTRAST, 'the backup text reads');

   (* A dark colour the operator picked: white text, not black on blue. *)
   RemainingMultCellStyle(rwsBackupWanted, True, DEFAULT_WINDOW, DEFAULT_TEXT,
                          longint(tr4wColorsArray[trBlue]), back, fore, bold);
   CheckEquals(longint(tr4wColorsArray[trBlue]), back, 'the operator''s blue, flat');
   CheckEquals(RGB_WHITE, fore, 'white text on blue');
end;

procedure TRemMultWorkStateTests.Test_EveryPaletteColourGetsReadableBackupText;
var
   c: tr4wColors;
   back: longint;
   fore: longint;
   bold: boolean;
begin
   BeginTest('Test_EveryPaletteColourGetsReadableBackupText');
   for c := Low(tr4wColors) to High(tr4wColors) do
      begin
      (* BTNFACE and HIGHLIGHT are system colours (an index with the high bit
        set); the form resolves them with ColorToRGB, which a leaf test
        cannot. Every literal one is checked. *)
      if (c = trBtnFace) or (c = trHighlight) then
         begin
         Continue;
         end;
      RemainingMultCellStyle(rwsBackupWanted, True, DEFAULT_WINDOW, DEFAULT_TEXT,
                             longint(tr4wColorsArray[c]), back, fore, bold);
      CheckTrue(ContrastRatio(fore, back) >= READABLE_CONTRAST,
                'backup text reads on ' + tr4wColorsSA[c]);
      end;
end;

procedure TRemMultWorkStateTests.Test_EveryStateReadsInTheDefaultColours;
var
   state: TRemMultWorkState;
   back: longint;
   fore: longint;
   bold: boolean;
   backs: array[TRemMultWorkState] of longint;
begin
   BeginTest('Test_EveryStateReadsInTheDefaultColours');
   (* White window, black text, the default orange: every state's text reads
     on its own fill, and the three states are three different fills. *)
   for state := Low(TRemMultWorkState) to High(TRemMultWorkState) do
      begin
      RemainingMultCellStyle(state, True, DEFAULT_WINDOW, DEFAULT_TEXT,
                             longint(tr4wColorsArray[trOrange]), back, fore, bold);
      CheckTrue(ContrastRatio(fore, back) >= READABLE_CONTRAST,
                StateName(state) + ' text reads on its fill');
      backs[state] := back;
      end;
   CheckTrue(backs[rwsNeeded] <> backs[rwsWorked], 'needed and worked differ');
   CheckTrue(backs[rwsNeeded] <> backs[rwsBackupWanted], 'needed and backup differ');
   CheckTrue(backs[rwsWorked] <> backs[rwsBackupWanted], 'worked and backup differ');
end;

procedure TRemMultWorkStateTests.Test_OutsideHiLightEveryCellIsDrawnNeeded;
var
   back: longint;
   fore: longint;
   bold: boolean;
begin
   BeginTest('Test_OutsideHiLightEveryCellIsDrawnNeeded');
   RemainingMultCellStyle(rwsWorked, False, DEFAULT_WINDOW, DEFAULT_TEXT,
                          longint($00A5FF), back, fore, bold);
   CheckEquals(DEFAULT_WINDOW, back, 'worked, ERASE: the window, not black');
   CheckEquals(DEFAULT_TEXT, fore, 'worked, ERASE: the window''s text');
   RemainingMultCellStyle(rwsBackupWanted, False, DEFAULT_WINDOW, DEFAULT_TEXT,
                          longint($00A5FF), back, fore, bold);
   CheckEquals(DEFAULT_WINDOW, back, 'backup, ERASE: no orange');
   CheckEquals(DEFAULT_TEXT, fore, 'backup, ERASE: the window''s text');
end;

procedure TRemMultWorkStateTests.RunAllTests;
begin
   Test_NotWorkedIsNeededWhateverTheCount;
   Test_AtTheDefaultLimitNothingIsABackup;
   Test_BelowTheLimitIsABackup;
   Test_AtOrAboveTheLimitIsWorked;
   Test_TheBitWithNoCountIsWorkedNotABackup;
   Test_TheTextCarriesACountOfTwoOrMore;
   Test_TheTextCarriesNoCountWithoutTheBit;
   Test_TheWindowReadsTheSheetsZoneCount;
   Test_LuminanceAndContrastAtTheEnds;
   Test_ANeededCellIsTheWindowsOwnText;
   Test_AWorkedCellIsTheTextColourUnderTheWindowColour;
   Test_AWorkedCellInvertsOnADarkWindowToo;
   Test_AWorkedCellWhoseColoursWouldNotReadGetsReadableText;
   Test_ABackupIsAFlatFillOfTheOperatorsColour;
   Test_EveryPaletteColourGetsReadableBackupText;
   Test_EveryStateReadsInTheDefaultColours;
   Test_OutsideHiLightEveryCellIsDrawnNeeded;
end;

end.

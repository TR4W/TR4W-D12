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
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC,               (* MultBand, MultMode, BandType, ModeType *)
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
end;

end.

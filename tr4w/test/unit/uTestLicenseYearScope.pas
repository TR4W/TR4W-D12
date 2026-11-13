unit uTestLicenseYearScope;

(* A STATION-PAGE EDIT OF MY LICENSE YEAR WHILE THE OPEN CONTEST SENDS THE
  YEAR -- issue 300 (NY4I confirmed the three answers, 2026-11-12). The rule
  is uLicenseYearChange; the form only asks and records. These pin:

    the question   asked only when the open contest sends the year and the
                   station's value really changes;

    station only   the default. A contest that stated its year keeps it; one
                   that FOLLOWED the station is pinned to the year it was
                   following, empty included, so the edit does not move it;

    this contest   the contest states the new year -- and "this contest and
                   its existing QSOs" is the SAME write;

    the evidence   why they are the same: a QSO logged here records no year,
                   so its exported sent exchange follows the contest's year
                   whichever button was pressed. If this test ever fails, rows
                   have started recording a year and the two buttons can, and
                   must, be told apart. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLicenseYearScopeTests = class(TTestCase)
   protected
      procedure Test_TheQuestionIsAskedOnlyWhenItMatters;
      procedure Test_StationOnlyKeepsAStatedContestYear;
      procedure Test_StationOnlyPinsTheYearTheContestFollowed;
      procedure Test_StationOnlyPinsAContestThatSentNoYear;
      procedure Test_ThisContestStatesTheNewYear;
      procedure Test_ExistingQSOsIsTheSameWrite;
      procedure Test_ALoggedQSOExportsTheContestsCurrentYear;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uCFG,                (* registers MY LICENSE YEAR's check *)
   uContestBase,
   uContestFactory,     (* SessionZoneTextSent *)
   uContestRegistry,    (* ContestIdentity *)
   uQsoMyFacts,
   uLicenseYearChange;

(* A station whose own year is aStation, and whose contest states aContest
  when aStated -- a fresh settings object, so nothing global moves. *)
function NewSettings(const aStation: string; aStated: boolean;
                     const aContest: string): TR4WSettings;
begin
   Result := TR4WSettings.Create;
   Result.TrySetByCommand(LICENSE_YEAR_COMMAND, aStation);
   if aStated then
      begin
      Result.TryOverrideForContest(LICENSE_YEAR_COMMAND, aContest);
      end;
end;

procedure TLicenseYearScopeTests.Test_TheQuestionIsAskedOnlyWhenItMatters;
begin
   BeginTest('the question is asked only when the contest sends the year and the year changes');
   CheckTrue(LicenseYearEditAsks(True, '1985', '1990'), 'a year contest, a new year');
   CheckTrue(LicenseYearEditAsks(True, '', '1990'), 'a first year');
   CheckTrue(LicenseYearEditAsks(True, '1985', ''), 'a cleared year');
   CheckFalse(LicenseYearEditAsks(True, '1985', '1985'), 'the same year');
   CheckFalse(LicenseYearEditAsks(True, '1985', ' 1985 '), 'blanks are not a change');
   CheckFalse(LicenseYearEditAsks(False, '1985', '1990'),
              'a contest that does not send the year: no question');
end;

procedure TLicenseYearScopeTests.Test_StationOnlyKeepsAStatedContestYear;
var
   s: TR4WSettings;
   before: string;
begin
   BeginTest('station only: a contest that stated its year keeps it');
   s := NewSettings('1985', True, '64');
   try
      before := s.My.ResolvedLicenseYear;
      s.TrySetByCommand(LICENSE_YEAR_COMMAND, '1990');
      CheckFalse(ApplyLicenseYearScope(s, lysStationOnly, before),
                 'nothing for the log to record');
      CheckEquals('64', s.My.ResolvedLicenseYear, 'the contest still sends 64');
      CheckEquals('1990', s.My.LicenseYear, 'and the station''s default is the new year');
   finally
      s.Free;
   end;
end;

procedure TLicenseYearScopeTests.Test_StationOnlyPinsTheYearTheContestFollowed;
var
   s: TR4WSettings;
   before: string;
begin
   BeginTest('station only: a contest that followed the station keeps the year it followed');
   s := NewSettings('1985', False, '');
   try
      before := s.My.ResolvedLicenseYear;
      CheckEquals('1985', before, 'the contest followed the station');
      s.TrySetByCommand(LICENSE_YEAR_COMMAND, '1990');
      CheckEquals('1990', s.My.ResolvedLicenseYear,
                  'unpinned, the edit alone would move the contest');
      CheckTrue(ApplyLicenseYearScope(s, lysStationOnly, before), 'a statement to record');
      CheckTrue(s.My.HasContestOverride(sfLicenseYear), 'the contest states its year now');
      CheckEquals('1985', s.My.ResolvedLicenseYear, 'the year it was sending');
      CheckEquals('1990', s.My.LicenseYear, 'and the station''s default moved');
   finally
      s.Free;
   end;
end;

procedure TLicenseYearScopeTests.Test_StationOnlyPinsAContestThatSentNoYear;
var
   s: TR4WSettings;
   before: string;
begin
   BeginTest('station only: a contest that sent no year goes on sending none');
   s := NewSettings('', False, '');
   try
      before := s.My.ResolvedLicenseYear;
      s.TrySetByCommand(LICENSE_YEAR_COMMAND, '1990');
      CheckTrue(ApplyLicenseYearScope(s, lysStationOnly, before), 'a statement to record');
      CheckTrue(s.My.HasContestOverride(sfLicenseYear), 'stated');
      CheckEquals('', s.My.ResolvedLicenseYear, 'of no year');
   finally
      s.Free;
   end;
end;

procedure TLicenseYearScopeTests.Test_ThisContestStatesTheNewYear;
var
   s: TR4WSettings;
   before: string;
begin
   BeginTest('also this contest: the contest states the station''s new year');

   s := NewSettings('1985', True, '64');
   try
      before := s.My.ResolvedLicenseYear;
      s.TrySetByCommand(LICENSE_YEAR_COMMAND, '1990');
      CheckTrue(ApplyLicenseYearScope(s, lysAlsoContest, before), 'a statement to record');
      CheckEquals('1990', s.My.ResolvedLicenseYear, 'over a year the contest had stated');
      CheckFalse(ApplyLicenseYearScope(s, lysAlsoContest, before),
                 'asked again with nothing new: nothing to record');
   finally
      s.Free;
   end;

   s := NewSettings('1985', False, '');
   try
      before := s.My.ResolvedLicenseYear;
      s.TrySetByCommand(LICENSE_YEAR_COMMAND, '1990');
      CheckTrue(ApplyLicenseYearScope(s, lysAlsoContest, before), 'a statement to record');
      CheckTrue(s.My.HasContestOverride(sfLicenseYear),
                'stated, so a later station edit elsewhere does not move it');
      CheckEquals('1990', s.My.ResolvedLicenseYear, 'the new year');
   finally
      s.Free;
   end;

   s := NewSettings('1985', True, '64');
   try
      before := s.My.ResolvedLicenseYear;
      s.TrySetByCommand(LICENSE_YEAR_COMMAND, '');
      CheckTrue(ApplyLicenseYearScope(s, lysAlsoContest, before), 'a cleared year');
      CheckEquals('', s.My.ResolvedLicenseYear, 'the contest sends none either');
   finally
      s.Free;
   end;
end;

procedure TLicenseYearScopeTests.Test_ExistingQSOsIsTheSameWrite;
var
   a, b: TR4WSettings;
   before: string;
begin
   BeginTest('this contest and its existing QSOs is the same write as this contest');
   a := NewSettings('1985', True, '64');
   b := NewSettings('1985', True, '64');
   try
      before := a.My.ResolvedLicenseYear;
      a.TrySetByCommand(LICENSE_YEAR_COMMAND, '1990');
      b.TrySetByCommand(LICENSE_YEAR_COMMAND, '1990');
      CheckTrue(ApplyLicenseYearScope(a, lysAlsoContest, before), 'this contest records');
      CheckTrue(ApplyLicenseYearScope(b, lysContestAndQSOs, before), 'and so does the other');
      CheckEquals(a.My.ResolvedLicenseYear, b.My.ResolvedLicenseYear, 'the same year');
      CheckTrue(a.My.HasContestOverride(sfLicenseYear) =
                b.My.HasContestOverride(sfLicenseYear), 'the same statement');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TLicenseYearScopeTests.Test_ALoggedQSOExportsTheContestsCurrentYear;
var
   euhfc: TContestBase;
   stated: boolean;
   saved: string;
   facts: TQsoMyFacts;
   my: TMyStationExchange;

   (* What the export sends for a QSO logged HERE, as PostUnit builds it:
      the session's MY-station exchange overlaid by the row's own facts
      (CurrentMyStationExchange's two steps). *)
   function ExportedSentYear: string;
   begin
      my := Default(TMyStationExchange);
      my.MyZone := SessionZoneTextSent(euhfc);
      my := MyStationExchangeOfQSO(my, facts, False,
                                   SentZoneKindOfQSO(euhfc, CQZoneMode));
      Result := my.MyZone;
   end;

begin
   BeginTest('a QSO logged here records no year: its export follows the contest''s current year');
   euhfc := ContestIdentity(EUROPEANHFC);
   stated := Settings.My.HasContestOverride(sfLicenseYear);
   saved := Settings.My.ContestOverride(sfLicenseYear);
   try
      (* A row as the capture writes it (uLogStore.LogStoreCurrentMyFacts):
         every my_* field there is, and none of them a year. *)
      facts := NotCapturedMyFacts;
      facts.Source := mfsLogged;
      facts.Call := 'S50A';
      facts.CQZone := 15;
      facts.ITUZone := 28;

      Settings.My.SetContestOverride(sfLicenseYear, '1964');
      CheckEquals('64', ExportedSentYear, 'logged while the contest sent 64');

      Settings.My.SetContestOverride(sfLicenseYear, '1990');
      CheckEquals('90', ExportedSentYear,
                  'the same row exports the contest''s new year -- so "this contest" ' +
                  'already changes its existing QSOs');
   finally
      if stated then
         begin
         Settings.My.SetContestOverride(sfLicenseYear, saved);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfLicenseYear);
         end;
   end;
end;

procedure TLicenseYearScopeTests.RunAllTests;
begin
   Test_TheQuestionIsAskedOnlyWhenItMatters;
   Test_StationOnlyKeepsAStatedContestYear;
   Test_StationOnlyPinsTheYearTheContestFollowed;
   Test_StationOnlyPinsAContestThatSentNoYear;
   Test_ThisContestStatesTheNewYear;
   Test_ExistingQSOsIsTheSameWrite;
   Test_ALoggedQSOExportsTheContestsCurrentYear;
end;

end.

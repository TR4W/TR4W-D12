unit uTestLicenseYearScope;

(* A STATION-PAGE EDIT OF MY LICENSE YEAR WHILE THE OPEN CONTEST SENDS THE
  YEAR -- issue 300 (two answers since log schema 8, NY4I 2026-11-13). The
  rule is uLicenseYearChange; the form only asks and records. These pin:

    the question   asked only when the open contest sends the year and the
                   station's value really changes;

    station only   the default. A contest that stated its year keeps it; one
                   that FOLLOWED the station is pinned to the year it was
                   following, empty included, so the edit does not move it;

    this contest   the contest states the new year;

    the correction asked only after "Also this contest", when a correction
                   is offered and logged QSOs sent the old year (a log that
                   cannot be read asks nothing);

    the evidence   FLIPPED BY LOG SCHEMA 8 (issue 300, NY4I 2026-11-13): a
                   QSO logged here records the year it sent (qso.year_sent),
                   so its export keeps that year after the contest's changes.
                   Existing QSOs move only through the correction question
                   (uTestLogYearSent pins its rule and its write). *)

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
      procedure Test_TheCorrectionIsAskedOnlyAfterAlsoThisContest;
      procedure Test_ALoggedQSOKeepsTheYearItSent;
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

procedure TLicenseYearScopeTests.Test_TheCorrectionIsAskedOnlyAfterAlsoThisContest;
var
   s: TR4WSettings;
   before: string;
   c: TLicenseYearCorrection;
   offered: boolean;
begin
   BeginTest('the correction question follows "Also this contest", an offer and QSOs to correct');

   CheckTrue(LicenseYearCorrectionAsks(lysAlsoContest, True, 3),
             'also this contest, a new year sent, three QSOs sent the old one');
   CheckTrue(LicenseYearCorrectionAsks(lysAlsoContest, True, 1), 'one QSO is enough');
   CheckFalse(LicenseYearCorrectionAsks(lysStationOnly, True, 3),
              'station only never asks: the contest goes on sending what it sent');
   CheckFalse(LicenseYearCorrectionAsks(lysAlsoContest, False, 3),
              'no change in what is sent: nothing to correct');
   CheckFalse(LicenseYearCorrectionAsks(lysAlsoContest, True, 0),
              'no QSO sent the old year: nothing to ask');
   CheckFalse(LicenseYearCorrectionAsks(lysAlsoContest, True, -1),
              'a log that cannot be read asks nothing');

   (* THE FORM'S SEQUENCE ON A SETTINGS OBJECT: the resolved year before the
      write, the answer applied, the resolved year after -- what
      LicenseYearCorrectionOf is given, so the offer is the one it reads. *)
   s := NewSettings('1985', True, '1964');
   try
      before := s.My.ResolvedLicenseYear;
      s.TrySetByCommand(LICENSE_YEAR_COMMAND, '1990');
      ApplyLicenseYearScope(s, lysAlsoContest, before);
      offered := LicenseYearCorrectionOf(rykTwoDigitYear, before,
                                         s.My.ResolvedLicenseYear, 2026, c);
      CheckTrue(offered, 'the contest moved from 1964 to 1990');
      CheckTrue(c.OldKnown and (c.OldValue = 64), 'the QSOs to correct sent 64');
      CheckTrue(c.NewKnown and (c.NewValue = 90), 'and are offered 90');
      CheckTrue(LicenseYearCorrectionAsks(lysAlsoContest, offered, 2), 'so it asks');
   finally
      s.Free;
   end;

   s := NewSettings('1985', True, '1964');
   try
      before := s.My.ResolvedLicenseYear;
      s.TrySetByCommand(LICENSE_YEAR_COMMAND, '1990');
      ApplyLicenseYearScope(s, lysStationOnly, before);
      offered := LicenseYearCorrectionOf(rykTwoDigitYear, before,
                                         s.My.ResolvedLicenseYear, 2026, c);
      CheckFalse(offered, 'station only: the contest still sends 64, nothing offered');
      CheckFalse(LicenseYearCorrectionAsks(lysStationOnly, offered, 2), 'and nothing asked');
   finally
      s.Free;
   end;
end;

procedure TLicenseYearScopeTests.Test_ALoggedQSOKeepsTheYearItSent;
var
   euhfc: TContestBase;
   stated: boolean;
   saved: string;
   facts: TQsoMyFacts;
   my: TMyStationExchange;
   year: integer;

   (* What the export sends for a QSO logged HERE, as PostUnit builds it:
      the session's MY-station exchange overlaid by the row's own facts
      (CurrentMyStationExchange's two steps), the year included. *)
   function ExportedSentYear: string;
   begin
      my := Default(TMyStationExchange);
      my.MyZone := SessionZoneTextSent(euhfc);
      my := MyStationExchangeOfQSO(my, facts, False,
                                   SentZoneKindOfQSO(euhfc, CQZoneMode),
                                   ContestReceivedYearKind(euhfc));
      Result := my.MyZone;
   end;

begin
   BeginTest('a QSO logged here keeps the year it sent after the contest''s year changes');
   euhfc := ContestIdentity(EUROPEANHFC);
   stated := Settings.My.HasContestOverride(sfLicenseYear);
   saved := Settings.My.ContestOverride(sfLicenseYear);
   try
      (* A row as the capture writes it (uLogStore.LogStoreCurrentMyFacts):
         every my_* field there is, and -- since log schema 8 -- the year it
         sent, as the session sent it then. *)
      Settings.My.SetContestOverride(sfLicenseYear, '1964');
      facts := NotCapturedMyFacts;
      facts.Source := mfsLogged;
      facts.Call := 'S50A';
      facts.CQZone := 15;
      facts.ITUZone := 28;
      facts.YearSentKnown := SessionLicenseYearSent(euhfc, year);
      facts.YearSent := year;
      CheckTrue(facts.YearSentKnown, 'the capture records a year');
      CheckEquals('64', ExportedSentYear, 'logged while the contest sent 64');

      Settings.My.SetContestOverride(sfLicenseYear, '1990');
      CheckEquals('90', SessionZoneTextSent(euhfc), 'the contest sends 90 now');
      CheckEquals('64', ExportedSentYear,
                  'and the logged row still exports the 64 it sent -- "this contest" ' +
                  'no longer reaches its existing QSOs (issue 300, schema 8)');

      (* A ROW THAT NEVER CAPTURED A STATION, AND HOLDS NO YEAR, IS THE
         SESSION'S (ruling A): a log the backfill has not reached. *)
      facts := NotCapturedMyFacts;
      CheckEquals('90', ExportedSentYear, 'a never-captured row follows the session');
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
   Test_TheCorrectionIsAskedOnlyAfterAlsoThisContest;
   Test_ALoggedQSOKeepsTheYearItSent;
end;

end.

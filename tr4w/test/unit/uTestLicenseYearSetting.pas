unit uTestLicenseYearSetting;

(* THE SENT LICENSE YEAR IS A SETTING OF ITS OWN -- MY LICENSE YEAR, issue 298
  (NY4I, 2026-11-12: "the whole point was to add the year field to the
  database and add the new field to the UX, so do NOT leave it as MY ZONE").

  Until now the year a European HF Championship or KVP station SENDS was the
  MY ZONE setting, relabelled on Preferences, on the New Contest row and in a
  tooltip, and exported through a branch that kept a captured zone out of it.
  Now there is a setting named for what it holds, and these pin:

    the reading    one to four digits as typed; a two-digit year is read as the
                   closest past one (LicenseYearValue);

    the kinds      what a contest SENDS from it follows the contest's
                   TReceivedYearKind and never the digits typed: 85, 1985, or
                   the count of years licensed (SentLicenseYearText) -- the
                   three kinds DXLog's contest files use, though only the first
                   has a TR4W class today;

    the setting    a station fact a contest may state for itself, refused when
                   it is not digits, and a different command from MY ZONE;

    the readers    the station context's SentZoneText, the export's
                   SessionZoneTextSent and the whole MY-station exchange send
                   the year in a year contest and the zone in every other,
                   whatever MY ZONE holds;

    the alias      a year stated as MY ZONE before the setting existed -- a
                   .cfg line, a New Contest answer, the log's own row -- is
                   MOVED to MY LICENSE YEAR once the contest is known
                   (uContestFactory.AdoptLegacyLicenseYear), so an existing
                   log needs no migration step.

  THE LOG'S ROWS are pinned beside the other station facts in
  uTestStationFactOverrides.Test_LicenseYearIsCapturedAndReopened. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLicenseYearSettingTests = class(TTestCase)
   protected
      procedure Test_TheYearAsTyped;
      procedure Test_WhatEachKindSends;
      procedure Test_TheSettingIsAStationFactOfItsOwn;
      procedure Test_AYearContestSendsTheYearNotTheZone;
      procedure Test_TheExportSendsTheYearForAYearContest;
      procedure Test_ALegacyYearStatedAsMyZoneMoves;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uContestBase,
   uContestFactory,       (* SessionZoneTextSent, AdoptLegacyLicenseYear *)
   uContestRegistry,      (* ContestIdentity, ContestHandleOf *)
   uQsoMyFacts;           (* TQsoMyFacts, NotCapturedMyFacts *)

const
   NOW_YEAR = 2026;

function Year(const aText: string; aCurrent: integer): integer;
begin
   if not LicenseYearValue(aText, aCurrent, Result) then
      begin
      Result := NO_RECEIVED_YEAR;
      end;
end;

procedure TLicenseYearSettingTests.Test_TheYearAsTyped;
var
   y: integer;
begin
   BeginTest('a year is read as typed, and a two-digit one as the closest past year');
   CheckEquals(1985, Year('1985', NOW_YEAR), 'four digits are the year');
   CheckEquals(2005, Year('2005', NOW_YEAR), 'a recent year');
   CheckEquals(1985, Year('85', NOW_YEAR), '85 is 1985');
   CheckEquals(2005, Year('05', NOW_YEAR), '05 is 2005');
   CheckEquals(2005, Year('5', NOW_YEAR), 'one digit is a year too');
   CheckEquals(2026, Year('26', NOW_YEAR), 'this year');
   CheckEquals(1927, Year('27', NOW_YEAR), 'a year not yet reached is last century''s');
   CheckEquals(1985, Year('85', 0), 'no current year known: the 1900s');
   CheckEquals(1985, Year(' 85 ', NOW_YEAR), 'surrounding blanks are not part of it');

   CheckFalse(LicenseYearValue('', NOW_YEAR, y), 'empty is no year');
   CheckEquals(NO_RECEIVED_YEAR, y, 'and says so');
   CheckFalse(LicenseYearValue('198', NOW_YEAR, y), 'three digits are no year');
   CheckFalse(LicenseYearValue('1899', NOW_YEAR, y), 'a year before any licence');
   CheckFalse(LicenseYearValue('19x5', NOW_YEAR, y), 'letters are no year');
   CheckFalse(LicenseYearValue('19850', NOW_YEAR, y), 'five digits are no year');
end;

procedure TLicenseYearSettingTests.Test_WhatEachKindSends;
begin
   BeginTest('what a contest sends from MY LICENSE YEAR follows its kind, never the digits typed');

   CheckEquals('85', SentLicenseYearText(rykTwoDigitYear, '1985', NOW_YEAR), '2-digit from a year');
   CheckEquals('05', SentLicenseYearText(rykTwoDigitYear, '2005', NOW_YEAR), '2-digit keeps its zero');
   CheckEquals('05', SentLicenseYearText(rykTwoDigitYear, '5', NOW_YEAR), '2-digit from one digit');
   CheckEquals('85', SentLicenseYearText(rykTwoDigitYear, '85', NOW_YEAR), '2-digit from two');
   CheckEquals('00', SentLicenseYearText(rykTwoDigitYear, '2000', NOW_YEAR), 'the year 2000 is 00');
   CheckEquals('', SentLicenseYearText(rykTwoDigitYear, '', NOW_YEAR), 'nothing stated, nothing sent');
   CheckEquals('', SentLicenseYearText(rykTwoDigitYear, 'abc', NOW_YEAR), 'not a year, nothing sent');

   CheckEquals('1985', SentLicenseYearText(rykFourDigitYear, '1985', NOW_YEAR), '4-digit from a year');
   CheckEquals('1985', SentLicenseYearText(rykFourDigitYear, '85', NOW_YEAR), '4-digit from two digits');
   CheckEquals('2005', SentLicenseYearText(rykFourDigitYear, '05', NOW_YEAR), '4-digit, a recent year');
   CheckEquals('', SentLicenseYearText(rykFourDigitYear, '', NOW_YEAR), '4-digit, nothing stated');

   CheckEquals('41', SentLicenseYearText(rykYearsLicensed, '1985', NOW_YEAR),
               'a count from a year');
   CheckEquals('9', SentLicenseYearText(rykYearsLicensed, '9', NOW_YEAR),
               'a count stated as a count stays one');
   CheckEquals('85', SentLicenseYearText(rykYearsLicensed, '85', NOW_YEAR),
               '85 is a count of 85 here, and a year only in a year kind');
   CheckEquals('0', SentLicenseYearText(rykYearsLicensed, '2026', NOW_YEAR), 'licensed this year');
   CheckEquals('', SentLicenseYearText(rykYearsLicensed, '1985', 0),
               'a year with no current year cannot give a count');
   CheckEquals('', SentLicenseYearText(rykYearsLicensed, '2027', NOW_YEAR),
               'a year not yet reached gives no count');
   CheckEquals('', SentLicenseYearText(rykYearsLicensed, '1900', NOW_YEAR),
               'a count over 99 is no count');

   CheckEquals('', SentLicenseYearText(rykNone, '1985', NOW_YEAR), 'no kind, nothing');
end;

procedure TLicenseYearSettingTests.Test_TheSettingIsAStationFactOfItsOwn;
var
   s: TR4WSettings;
   fact: TStationFact;
begin
   BeginTest('MY LICENSE YEAR is a station fact a contest may state, and is not MY ZONE');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.StationFactOfCommand('MY LICENSE YEAR', fact), 'the name is a station fact');
      CheckTrue(fact = sfLicenseYear, 'and it is the license year');
      CheckTrue(s.CommandIsContestOverridable('MY LICENSE YEAR'), 'a contest may state it');
      CheckEquals('LicenseYear', STATION_FACT_PROPERTY[sfLicenseYear], 'its property');

      CheckEquals('', s.My.LicenseYear, 'unset by default');
      CheckTrue(s.TrySetByCommand('MY LICENSE YEAR', '1985'), 'the station''s year');
      CheckEquals('1985', s.My.LicenseYear, 'is the property');
      CheckEquals('', s.My.Zone, 'and not the zone');

      CheckTrue(s.TrySetByCommand('MY LICENSE YEAR', ''), 'it can be cleared');
      CheckTrue(s.TrySetByCommand('MY LICENSE YEAR', '85'), 'two digits are accepted');
      CheckFalse(s.TrySetByCommand('MY LICENSE YEAR', 'abc'), 'letters are refused');
      CheckFalse(s.TrySetByCommand('MY LICENSE YEAR', '19850'), 'five digits are refused');
      CheckEquals('85', s.My.LicenseYear, 'a refusal leaves the value');

      CheckTrue(s.TryOverrideForContest('MY LICENSE YEAR', '1990'), 'this contest''s year');
      CheckEquals('1990', s.My.ResolvedLicenseYear, 'resolves to the contest''s');
      CheckEquals('85', s.My.LicenseYear, 'and leaves the station''s');
      CheckFalse(s.TryOverrideForContest('MY LICENSE YEAR', 'x'), 'a contest''s year is refused alike');
   finally
      s.Free;
   end;
end;

(* A STATION AS THE SESSION HANDS IT, with MY ZONE and MY LICENSE YEAR both
   stated and different, so which one is sent is unmistakable. *)
function StationWithZoneAndYear: TStationContext;
begin
   Result := Default(TStationContext);
   Result.MyZoneText := '5';
   Result.MyLicenseYear := '1985';
   Result.CurrentYear := NOW_YEAR;
end;

procedure TLicenseYearSettingTests.Test_AYearContestSendsTheYearNotTheZone;
var
   station: TStationContext;
   euhfcRules, kvpRules, cqwwRules: TContestBase;
begin
   BeginTest('a contest that exchanges a year sends MY LICENSE YEAR; any other sends the zone');
   station := StationWithZoneAndYear;
   euhfcRules := ContestIdentity(EUROPEANHFC);
   kvpRules := ContestIdentity(KVP);
   cqwwRules := ContestIdentity(CQWWCW);

   CheckEquals('85', euhfcRules.SentZoneText(station), 'EUHFC sends the year');
   CheckEquals('85', kvpRules.SentZoneText(station), 'KVP sends the year');
   CheckEquals('5', cqwwRules.SentZoneText(station), 'CQ WW sends the zone, whatever the year says');

   station.MyLicenseYear := '';
   CheckEquals('', euhfcRules.SentZoneText(station), 'no year stated: EUHFC sends none, not the zone');
   CheckEquals('5', cqwwRules.SentZoneText(station), 'and CQ WW still the zone');
end;

procedure TLicenseYearSettingTests.Test_TheExportSendsTheYearForAYearContest;
var
   euhfcRules, cqwwRules: TContestBase;
   savedZone, savedYear: string;
   savedZoneStated, savedYearStated: boolean;
   facts: TQsoMyFacts;
   my: TMyStationExchange;
begin
   BeginTest('the export and the default CW exchange send the year in a year contest');
   euhfcRules := ContestIdentity(EUROPEANHFC);
   cqwwRules := ContestIdentity(CQWWCW);
   savedZoneStated := Settings.My.HasContestOverride(sfZone);
   savedZone := Settings.My.ContestOverride(sfZone);
   savedYearStated := Settings.My.HasContestOverride(sfLicenseYear);
   savedYear := Settings.My.ContestOverride(sfLicenseYear);
   try
      Settings.My.SetContestOverride(sfZone, '3');
      Settings.My.SetContestOverride(sfLicenseYear, '1985');

      CheckEquals('85', SessionZoneTextSent(euhfcRules), 'SessionZoneTextSent: the year');
      CheckEquals('3', SessionZoneTextSent(cqwwRules), 'and the zone for CQ WW');

      (* THE MY-STATION EXCHANGE PostUnit BUILDS carries the session's sent
         text in the zone's slot, then overlays a captured QSO's facts
         (CurrentMyStationExchange -- the two steps taken here). *)
      my := Default(TMyStationExchange);
      my.MyZone := SessionZoneTextSent(euhfcRules);
      CheckEquals('85', my.MyZone, 'the exchange carries the year in the slot the zone had');
      my.MyZone := SessionZoneTextSent(cqwwRules);
      CheckEquals('3', my.MyZone, 'and the zone for CQ WW');

      (* A QSO that captured a station zone: it must not replace the year. *)
      my.MyZone := SessionZoneTextSent(euhfcRules);
      facts := NotCapturedMyFacts;
      facts.Source := mfsLogged;
      facts.CQZone := 14;
      facts.ITUZone := 28;
      my := MyStationExchangeOfQSO(my, facts, False,
                                   SentZoneKindOfQSO(euhfcRules, CQZoneMode));
      CheckEquals('85', my.MyZone, 'a captured zone never replaces the year');
   finally
      if savedZoneStated then
         begin
         Settings.My.SetContestOverride(sfZone, savedZone);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfZone);
         end;
      if savedYearStated then
         begin
         Settings.My.SetContestOverride(sfLicenseYear, savedYear);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfLicenseYear);
         end;
   end;
end;

procedure TLicenseYearSettingTests.Test_ALegacyYearStatedAsMyZoneMoves;
var
   savedZone, savedYear: string;
   savedZoneStated, savedYearStated: boolean;
begin
   BeginTest('a year stated as MY ZONE before the setting existed moves to MY LICENSE YEAR');
   savedZoneStated := Settings.My.HasContestOverride(sfZone);
   savedZone := Settings.My.ContestOverride(sfZone);
   savedYearStated := Settings.My.HasContestOverride(sfLicenseYear);
   savedYear := Settings.My.ContestOverride(sfLicenseYear);
   try
      Settings.My.ClearContestOverride(sfLicenseYear);
      Settings.My.SetContestOverride(sfZone, '80');
      AdoptLegacyLicenseYear(rykTwoDigitYear);
      CheckTrue(Settings.My.HasContestOverride(sfLicenseYear), 'the year is stated now');
      CheckEquals('80', Settings.My.ContestOverride(sfLicenseYear), 'as it was');
      CheckFalse(Settings.My.HasContestOverride(sfZone),
                 'and is no longer read as a CQ zone of 80');

      (* A contest with no year does not take the statement. *)
      Settings.My.ClearContestOverride(sfLicenseYear);
      Settings.My.SetContestOverride(sfZone, '3');
      AdoptLegacyLicenseYear(rykNone);
      CheckTrue(Settings.My.HasContestOverride(sfZone), 'a zone contest keeps its zone');
      CheckFalse(Settings.My.HasContestOverride(sfLicenseYear), 'and gains no year');

      (* A year already stated stands; the zone is then a zone. *)
      Settings.My.SetContestOverride(sfLicenseYear, '1990');
      AdoptLegacyLicenseYear(rykTwoDigitYear);
      CheckEquals('1990', Settings.My.ContestOverride(sfLicenseYear), 'the stated year stands');
      CheckEquals('3', Settings.My.ContestOverride(sfZone), 'and the zone stays a zone');

      (* A statement that is not digits is not a year. *)
      Settings.My.ClearContestOverride(sfLicenseYear);
      Settings.My.SetContestOverride(sfZone, 'abc');
      AdoptLegacyLicenseYear(rykTwoDigitYear);
      CheckFalse(Settings.My.HasContestOverride(sfLicenseYear), 'not moved');
      CheckEquals('abc', Settings.My.ContestOverride(sfZone), 'and left alone');
   finally
      if savedZoneStated then
         begin
         Settings.My.SetContestOverride(sfZone, savedZone);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfZone);
         end;
      if savedYearStated then
         begin
         Settings.My.SetContestOverride(sfLicenseYear, savedYear);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfLicenseYear);
         end;
   end;
end;

procedure TLicenseYearSettingTests.RunAllTests;
begin
   Test_TheYearAsTyped;
   Test_WhatEachKindSends;
   Test_TheSettingIsAStationFactOfItsOwn;
   Test_AYearContestSendsTheYearNotTheZone;
   Test_TheExportSendsTheYearForAYearContest;
   Test_ALegacyYearStatedAsMyZoneMoves;
end;

end.

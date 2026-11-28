(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* THE STATION PAGE'S FIELD CHECK -- uStationFieldCheck.StationFieldProblem
  (NY4I, 2026-11-16: Grid 'EL88pa', ARRL section 'okh', Country 'K', Park
  'abcdedf' and License year 'alph' were typed, and only the year said
  anything, and only at Save).

  Each field is pinned both ways -- accepted and refused -- with NY4I's own
  five values among them. The three predicates lifted into the leaf
  (CheckCountAndLetterClass, IsIOTAReference, LicenseYearIsDigits) are
  pinned against their old callers, so the lift changed no answer. *)
unit uTestStationFieldCheck;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TStationFieldCheckTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Accepted(const aCommand: string; const aTexts: array of string);
      procedure Refused(const aCommand: string; const aTexts: array of string);
      procedure Test_NY4IsFiveValues;
      procedure Test_EmptyIsAlwaysAllowed;
      procedure Test_FieldsWithNoRuleAreNotChecked;
      procedure Test_GridIsAGridTheProgramMeasures;
      procedure Test_Zones;
      procedure Test_PrefectureIsANumberOrATwoLetterCode;
      procedure Test_PowerClassIsOneOfHMLP;
      procedure Test_SectionIsAnARRLOrRACSectionOrDX;
      procedure Test_CountryIsACTYPrefix;
      procedure Test_ParkIsOneOrMoreReferences;
      procedure Test_Iota;
      procedure Test_FieldDayClassTakesEitherFieldDaysLetters;
      procedure Test_CheckPrecFOCAndLicenseYear;
      procedure Test_TheLiftedClassRuleAnswersAsBefore;
      procedure Test_TheLiftedIOTARuleAnswersAsBefore;
      procedure Test_EveryFieldIsCheckedNotOnlyTheTouchedOnes;
      procedure Test_StateIsJudgedOnlyWhenItIsTwoLetters;
      procedure Test_FocusIsHeldOnlyWithinTheStationPage;
   end;

implementation

uses
   SysUtils,
   uAppStrings,
   uADIF,
   uStationFieldCheck,
   (* LoadCountryFile -- MY COUNTRY asks CTY.DAT through uCFG's hook. *)
   uTestEngineEntry;

procedure TStationFieldCheckTests.Accepted(const aCommand: string;
                                           const aTexts: array of string);
var
   i: integer;
begin
   for i := Low(aTexts) to High(aTexts) do
      begin
      CheckEquals('', StationFieldProblem(aCommand, aTexts[i]),
                  aCommand + ' "' + aTexts[i] + '" is accepted');
      end;
end;

procedure TStationFieldCheckTests.Refused(const aCommand: string;
                                          const aTexts: array of string);
var
   i: integer;
begin
   for i := Low(aTexts) to High(aTexts) do
      begin
      CheckTrue(StationFieldProblem(aCommand, aTexts[i]) <> '',
                aCommand + ' "' + aTexts[i] + '" is refused');
      end;
end;

procedure TStationFieldCheckTests.Test_NY4IsFiveValues;
begin
   BeginTest('Test_NY4IsFiveValues');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   CheckEquals('', StationFieldProblem('MY GRID', 'EL88pa'), 'EL88pa is a grid');
   CheckEquals(string(SStationFieldSection), StationFieldProblem('MY SECTION', 'okh'),
               'okh is not a section, and says so');
   CheckEquals('', StationFieldProblem('MY COUNTRY', 'K'), 'K is a country prefix');
   CheckEquals(string(SStationFieldPark), StationFieldProblem('MY PARK', 'abcdedf'),
               'abcdedf is not a park, and says so');
   CheckEquals(string(SStationFieldLicenseYear), StationFieldProblem('MY LICENSE YEAR', 'alph'),
               'alph is not a license year, and says so');
end;

procedure TStationFieldCheckTests.Test_EmptyIsAlwaysAllowed;
const
   COMMANDS: array[0..14] of string = ('MY GRID', 'MY ZONE', 'MY ITU ZONE',
      'MY SECTION', 'MY COUNTRY', 'MY PARK', 'MY IOTA', 'MY FD CLASS',
      'MY CHECK', 'MY PREC', 'MY FOC NUMBER', 'MY LICENSE YEAR', 'MY STATE',
      'MY PREFECTURE', 'MY POWER CLASS');
var
   i: integer;
begin
   BeginTest('Test_EmptyIsAlwaysAllowed');
   for i := Low(COMMANDS) to High(COMMANDS) do
      begin
      CheckEquals('', StationFieldProblem(COMMANDS[i], ''), COMMANDS[i] + ' empty');
      CheckEquals('', StationFieldProblem(COMMANDS[i], '   '), COMMANDS[i] + ' blanks');
      end;
end;

procedure TStationFieldCheckTests.Test_FieldsWithNoRuleAreNotChecked;
begin
   BeginTest('Test_FieldsWithNoRuleAreNotChecked');
   Accepted('MY POSTAL CODE', ['32801', 'SW1A 1AA', 'xyz']);
   Accepted('MY NAME', ['Tom', '1234']);
   Accepted('MY CALL', ['NY4I', 'junk']);
end;

procedure TStationFieldCheckTests.Test_GridIsAGridTheProgramMeasures;
begin
   BeginTest('Test_GridIsAGridTheProgramMeasures');
   Accepted('MY GRID', ['EL88', 'el88', 'EL88PA', 'el88pa', ' EL88pa ']);
   (* Eight characters: LOGGRID would give no distance and no heading. *)
   Refused('MY GRID', ['EL8', 'EL88P', 'EL88PA12', 'SL88', 'ELAA', 'EL88P1', 'K']);
end;

(* MY PREFECTURE (2026-11-23): the SHAPE only -- up to three digits (a JARL
  number: ALL JA 02..48 and 101..114, JIDX 01..48) or two letters (the KCJ's
  code). Which numbers a contest takes is its own pattern, not this rule. *)
procedure TStationFieldCheckTests.Test_PrefectureIsANumberOrATwoLetterCode;
begin
   BeginTest('Test_PrefectureIsANumberOrATwoLetterCode');
   Accepted('MY PREFECTURE', ['02', '48', '101', '114', '1', 'TK', 'tk', ' 12 ']);
   Refused('MY PREFECTURE', ['1011', 'T', 'TKO', '1A', 'T1']);
   CheckEquals(string(SStationFieldPrefecture), StationFieldProblem('MY PREFECTURE', '1011'),
               'a four-digit prefecture says why');
end;

(* MY POWER and MY POWER CLASS, one value under two names. ANY POWER since
  2026-11-27 (ARRL DX sends '100' or 'KW'); the ALL JA's four letters are that
  contest's own rule (uTestContestUI). *)
procedure TStationFieldCheckTests.Test_PowerClassIsOneOfHMLP;
begin
   BeginTest('Test_PowerClassIsOneOfHMLP');
   Accepted('MY POWER CLASS', ['H', 'M', 'L', 'P', 'h', ' p ']);
   Accepted('MY POWER CLASS', ['100', 'K', 'KW', 'kw', '1.5KW', '5', '']);
   Accepted('MY POWER', ['100', 'K', 'KW', 'H']);
   Refused('MY POWER', ['1 KW', '100W/QRP', 'KILOWATTS', '-5']);
   CheckEquals(string(SStationFieldPower), StationFieldProblem('MY POWER', '1 KW'),
               'a power with a blank says why');
end;

procedure TStationFieldCheckTests.Test_Zones;
begin
   BeginTest('Test_Zones');
   Accepted('MY ZONE', ['1', '05', '5', '40']);
   Refused('MY ZONE', ['0', '41', '005', 'five', '5a', '-5']);
   Accepted('MY ITU ZONE', ['0', '1', '08', '90']);
   Refused('MY ITU ZONE', ['91', '100', 'x', '8.0']);
end;

procedure TStationFieldCheckTests.Test_SectionIsAnARRLOrRACSectionOrDX;
begin
   BeginTest('Test_SectionIsAnARRLOrRACSectionOrDX');
   Accepted('MY SECTION', ['WCF', 'wcf', 'NFL', 'ONE', 'GH', 'DX', 'dx']);
   Refused('MY SECTION', ['okh', 'FLA', 'XX', 'MD']);
end;

procedure TStationFieldCheckTests.Test_CountryIsACTYPrefix;
begin
   BeginTest('Test_CountryIsACTYPrefix');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   Accepted('MY COUNTRY', ['K', 'VE', 'G']);
   CheckEquals(string(SStationFieldCountry), StationFieldProblem('MY COUNTRY', 'USA'),
               'USA is a name, not a prefix');
end;

procedure TStationFieldCheckTests.Test_ParkIsOneOrMoreReferences;
begin
   BeginTest('Test_ParkIsOneOrMoreReferences');
   Accepted('MY PARK', ['US-1234', 'us-1234', 'VE-0123', 'US-12345',
                        'US-1234,US-5678', 'US-1234, US-5678']);
   (* 'K-0001' is POTA's OLD one-letter form; IsValidPOTAPark, the program's
     one rule for a reference, takes two letters. *)
   Refused('MY PARK', ['abcdedf', 'US1234', 'US-123', 'US-123456', 'K-0001',
                       'US-1234,', ',US-1234', 'US-1234,,US-5678', 'US-1234 US-5678']);
end;

procedure TStationFieldCheckTests.Test_Iota;
begin
   BeginTest('Test_Iota');
   Accepted('MY IOTA', ['NA-001', 'na-001', 'EU-123']);
   Refused('MY IOTA', ['NA001', 'NA-01', 'NA-0001', 'N1-001', 'NA-00A']);
end;

procedure TStationFieldCheckTests.Test_FieldDayClassTakesEitherFieldDaysLetters;
begin
   BeginTest('Test_FieldDayClassTakesEitherFieldDaysLetters');
   Accepted('MY FD CLASS', ['1A', '2a', '12F', '2H', '1o', '3I', '1M']);
   Refused('MY FD CLASS', ['A', '0A', '100A', '2G', '2AB', '2', '2-A']);
end;

procedure TStationFieldCheckTests.Test_CheckPrecFOCAndLicenseYear;
begin
   BeginTest('Test_CheckPrecFOCAndLicenseYear');
   Accepted('MY CHECK', ['85', '05', '00']);
   Refused('MY CHECK', ['5', '1985', 'ab', '8a']);
   Accepted('MY PREC', ['Q', 'a', 'B', 'u', 'M', 'S']);
   Refused('MY PREC', ['C', 'QA', '1']);
   Accepted('MY FOC NUMBER', ['1', '1234']);
   Refused('MY FOC NUMBER', ['#1234', '12a']);
   Accepted('MY LICENSE YEAR', ['1985', '85', '9']);
   Refused('MY LICENSE YEAR', ['alph', '19855', '19a5']);
end;

(* uContestBase.ValidateCountAndLetterClass reported these from its own loop
  before the lift; the same answers from the leaf. *)
procedure TStationFieldCheckTests.Test_TheLiftedClassRuleAnswersAsBefore;
begin
   BeginTest('Test_TheLiftedClassRuleAnswersAsBefore');
   CheckTrue(CheckCountAndLetterClass('2A', FIELD_DAY_CLASS_LETTERS) = calcValid, '2A');
   CheckTrue(CheckCountAndLetterClass('2a', FIELD_DAY_CLASS_LETTERS) = calcValid, '2a');
   CheckTrue(CheckCountAndLetterClass('A2', FIELD_DAY_CLASS_LETTERS) = calcValid,
             'A2: the loop never cared about the order');
   CheckTrue(CheckCountAndLetterClass('99F', FIELD_DAY_CLASS_LETTERS) = calcValid, '99F');
   CheckTrue(CheckCountAndLetterClass('A', FIELD_DAY_CLASS_LETTERS) = calcBadCount, 'A: no count');
   CheckTrue(CheckCountAndLetterClass('0A', FIELD_DAY_CLASS_LETTERS) = calcBadCount, '0A');
   CheckTrue(CheckCountAndLetterClass('100A', FIELD_DAY_CLASS_LETTERS) = calcBadCount, '100A');
   CheckTrue(CheckCountAndLetterClass('2', FIELD_DAY_CLASS_LETTERS) = calcBadLetter, '2: no letter');
   CheckTrue(CheckCountAndLetterClass('2AB', FIELD_DAY_CLASS_LETTERS) = calcBadLetter, '2AB');
   CheckTrue(CheckCountAndLetterClass('2H', FIELD_DAY_CLASS_LETTERS) = calcBadLetter,
             '2H is not an ARRL Field Day class');
   CheckTrue(CheckCountAndLetterClass('2H', WINTER_FIELD_DAY_CLASS_LETTERS) = calcValid,
             '2H is a Winter Field Day class');
   CheckTrue(CheckCountAndLetterClass('2A', WINTER_FIELD_DAY_CLASS_LETTERS) = calcBadLetter,
             '2A is not a Winter Field Day class');
end;

procedure TStationFieldCheckTests.Test_TheLiftedIOTARuleAnswersAsBefore;
(* The answers uADIF.IsADIFIOTARef gave from its own body before the lift --
  upper-cased, six characters, two letters, a hyphen, three digits -- asked
  of uADIF, which now delegates to the leaf. *)
const
   TEXTS: array[0..8] of string = ('NA-001', 'na-001', 'Eu-123', 'NA001', 'NA-01',
                                   'N1-001', 'NA-00A', '', 'NA-0011');
   EXPECTED: array[0..8] of boolean = (True, True, True, False, False,
                                       False, False, False, False);
var
   i: integer;
begin
   BeginTest('Test_TheLiftedIOTARuleAnswersAsBefore');
   for i := Low(TEXTS) to High(TEXTS) do
      begin
      CheckTrue(IsADIFIOTARef(TEXTS[i]) = EXPECTED[i],
                '"' + TEXTS[i] + '": uADIF answers as before');
      end;
end;

(* NY4I'S SECOND CASE (2026-11-16): he corrected MY SECTION to WCF and saved,
  and the park 'abcdedf' LOADED from the settings file was saved with it,
  because it never lost focus. The all-fields pass still finds the park. *)
procedure TStationFieldCheckTests.Test_EveryFieldIsCheckedNotOnlyTheTouchedOnes;
const
   COMMANDS: array[0..4] of string = ('MY CALL', 'MY GRID', 'MY SECTION',
                                      'MY PARK', 'MY LICENSE YEAR');
   FIXED_SECTION_BAD_PARK: array[0..4] of string = ('NY4I', 'EL88pa', 'WCF',
                                                    'abcdedf', '1985');
   ALL_GOOD: array[0..4] of string = ('NY4I', 'EL88pa', 'WCF', 'US-1234', '1985');
   TWO_BAD: array[0..4] of string = ('NY4I', 'EL88pa', 'okh', 'abcdedf', 'alph');
var
   problem: string;
begin
   BeginTest('Test_EveryFieldIsCheckedNotOnlyTheTouchedOnes');
   CheckEquals(3, FirstStationFieldProblem(COMMANDS, FIXED_SECTION_BAD_PARK, problem),
               'the section is fixed and the untouched park is still refused');
   CheckEquals(string(SStationFieldPark), problem, 'with the park''s reason');

   CheckEquals(-1, FirstStationFieldProblem(COMMANDS, ALL_GOOD, problem),
               'every field right: nothing refused');
   CheckEquals('', problem, 'and no reason');

   CheckEquals(2, FirstStationFieldProblem(COMMANDS, TWO_BAD, problem),
               'the FIRST bad field in page order is named');
   CheckEquals(string(SStationFieldSection), problem, 'the section''s reason');
end;

(* NY4I, 2026-11-16: "A state or province cannot be AA." MY STATE is a
  polymorphic QTH -- a county, an oblast, a grid in the VHF contests, a
  number -- so only an exactly-two-letter value is a claim to be a state or
  province code, and only that is judged. *)
procedure TStationFieldCheckTests.Test_StateIsJudgedOnlyWhenItIsTwoLetters;
begin
   BeginTest('Test_StateIsJudgedOnlyWhenItIsTwoLetters');
   CheckEquals(string(SStationFieldState), StationFieldProblem('MY STATE', 'AA'),
               'AA is no state or province, and says so');
   Refused('MY STATE', ['aa', 'XX', 'ZZ', 'QQ']);
   (* Every state, DC and every province and territory, either case. *)
   Accepted('MY STATE', ['FL', 'fl', 'ON', 'dc', 'DC', 'AK', 'HI', 'WY',
                         'AB', 'BC', 'MB', 'NB', 'NL', 'NS', 'NT', 'NU',
                         'PE', 'QC', 'SK', 'YT',
                         'PR', 'VI', 'GU', 'AS', 'MP']);
   (* Not two letters: a QTH of another kind, accepted as typed. *)
   Accepted('MY STATE', ['EL88', 'Pinellas', 'okh', 'MOW', '123', 'A1', 'A']);
   (* MY QTH is the same setting under its second name. *)
   Refused('MY QTH', ['AA']);
   Accepted('MY QTH', ['FL', 'EL88']);
end;

(* NY4I, 2026-11-16: "when there is an error, shouldn't the cursor be left in
  that field even if I hit tab?" -- but never so that he cannot leave. *)
procedure TStationFieldCheckTests.Test_FocusIsHeldOnlyWithinTheStationPage;
const
   BAD = 'not a park';
var
   d: TStationFocusDestination;
begin
   BeginTest('Test_FocusIsHeldOnlyWithinTheStationPage');
   CheckTrue(ShouldHoldFocus(BAD, 'abcdedf', sfdStationPage),
             'a wrong field left by Tab within the page is held');
   for d := Low(TStationFocusDestination) to High(TStationFocusDestination) do
      begin
      if d <> sfdStationPage then
         begin
         CheckFalse(ShouldHoldFocus(BAD, 'abcdedf', d),
                    'leaving for ' + IntToStr(Ord(d)) + ' is never stopped');
         end;
      CheckFalse(ShouldHoldFocus('', 'US-1234', d), 'a right field is never held');
      CheckFalse(ShouldHoldFocus(BAD, '', d), 'an emptied field is never held');
      CheckFalse(ShouldHoldFocus(BAD, '   ', d), 'nor one of blanks');
      end;
end;

procedure TStationFieldCheckTests.RunAllTests;
begin
   Test_NY4IsFiveValues;
   Test_EmptyIsAlwaysAllowed;
   Test_FieldsWithNoRuleAreNotChecked;
   Test_GridIsAGridTheProgramMeasures;
   Test_Zones;
   Test_PrefectureIsANumberOrATwoLetterCode;
   Test_PowerClassIsOneOfHMLP;
   Test_SectionIsAnARRLOrRACSectionOrDX;
   Test_CountryIsACTYPrefix;
   Test_ParkIsOneOrMoreReferences;
   Test_Iota;
   Test_FieldDayClassTakesEitherFieldDaysLetters;
   Test_CheckPrecFOCAndLicenseYear;
   Test_TheLiftedClassRuleAnswersAsBefore;
   Test_TheLiftedIOTARuleAnswersAsBefore;
   Test_EveryFieldIsCheckedNotOnlyTheTouchedOnes;
   Test_StateIsJudgedOnlyWhenItIsTwoLetters;
   Test_FocusIsHeldOnlyWithinTheStationPage;
end;

end.

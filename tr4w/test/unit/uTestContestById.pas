(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

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

(* A CONTEST REGISTERED BY ITS STRING ID -- Q108 S3, 2026-10-17
  (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u).

  Through the unit-test program's own fixture (uContestTestFixture), which
  has no ContestType member: its handle is above the legacy range, assigned
  at the seal; the name resolver, the New Contest choices and the CONTEST
  vocabulary find it; the registry walks see it; an id that is a legacy
  spelling, a legacy alias or a duplicate is refused; a registration after
  the seal raises; and the fixture is not in the application.

  WHAT IS NOT HERE: S4's boundaries (multi-op refusal, the broadcast number)
  -- not built yet. The .TRW import's refusal of such a handle is
  uTestLogImport's. *)
unit uTestContestById;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestByIdTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TheFixtureHasAHandleAboveTheLegacyRange;
      procedure Test_KnownContestsListTheLegacyOnesThenTheByIdOnes;
      procedure Test_TheNameResolverFindsIt;
      procedure Test_TheRegistryWalkSeesIt;
      procedure Test_TheChoicesAndTheContestVocabularyOfferIt;
      procedure Test_AnIdIsRefusedForTheRightReasons;
      procedure Test_ARegistrationAfterTheSealRaises;
      procedure Test_TheFixtureIsNotInTheApplication;
   end;

implementation

uses
   SysUtils, Classes,
   VC, uContestBase, uContestRegistry, uContestNames, uContestChoices,
   uSettingsModel,
   uCFG,                  (* registers the CONTEST setting's vocabulary *)
   uTestRegisteredContests,
   uContestTestFixture;

(* The fixture's handle, or NoContest when the id does not resolve (a
  failure the first test reports). *)
function FixtureHandle: TContestHandle;
begin
   if not FindContestById(TEST_FIXTURE_CONTEST_ID, Result) then
      begin
      Result := NoContest;
      end;
end;

procedure TContestByIdTests.Test_TheFixtureHasAHandleAboveTheLegacyRange;
var
   h: TContestHandle;
   n: integer;
   obj: TContestBase;
begin
   BeginTest('Test_TheFixtureHasAHandleAboveTheLegacyRange');
   CheckTrue(FindContestById(TEST_FIXTURE_CONTEST_ID, h), 'the fixture''s id finds a contest');
   CheckTrue(h.ToByte >= FirstByIdContestHandle.ToByte,
             'its handle is above the legacy range');
   CheckEquals(Ord(High(ContestType)) + 1, FirstByIdContestHandle.ToByte,
               'which starts one above the last legacy number');
   CheckFalse(ContestLegacyNumber(h, n), 'it has no legacy number');
   CheckEquals(0, n, 'and the number is zeroed');
   CheckTrue(LegacyContestOf(h) = DUMMYCONTEST, 'so no rule site''s member compare matches it');
   CheckEquals(TEST_FIXTURE_CONTEST_ID, ContestId(h), 'its id is the one it registered');
   CheckTrue(IsKnownContest(h), 'it is a known contest');
   CheckTrue(ContestClassFor(h) = TContestTestFixture, 'its class is the fixture''s');

   obj := ContestIdentity(h);
   CheckTrue(obj is TContestTestFixture, 'its identity object is the fixture''s class');
   CheckEquals(1, Pos(TEST_FIXTURE_CONTEST_ID + ' (', ContestWho(obj)), 'a message names it by its id');
   CheckTrue(HandleOf(obj) = h, 'and the handle');
   CheckTrue(ContestIdentity(h) = obj, 'one identity object per contest');
end;

procedure TContestByIdTests.Test_KnownContestsListTheLegacyOnesThenTheByIdOnes;
var
   known: TContestHandleList;
   k, n, byId: integer;
begin
   BeginTest('Test_KnownContestsListTheLegacyOnesThenTheByIdOnes');
   known := KnownContests;
   CheckTrue(Length(known) > Ord(High(ContestType)) + 1,
             'more contests are known than the legacy ones');
   byId := 0;
   for k := 0 to High(known) do
      begin
      if k <= Ord(High(ContestType)) then
         begin
         CheckEquals(k, known[k].ToByte, 'legacy contest ' + IntToStr(k) + ' in handle order');
         end
      else
         begin
         inc(byId);
         CheckFalse(ContestLegacyNumber(known[k], n), ContestId(known[k]) + ': no legacy number');
         CheckTrue(known[k].ToByte > known[k - 1].ToByte, ContestId(known[k]) + ': in handle order');
         (* HANDLES ARE ASSIGNED IN ID ORDER, so the same set of contests gives
            the same handles in every program. *)
         if k > Ord(High(ContestType)) + 1 then
            begin
            CheckTrue(CompareText(ContestId(known[k - 1]), ContestId(known[k])) < 0,
                      ContestId(known[k]) + ': handles follow id order');
            end;
         CheckEquals(FirstByIdContestHandle.ToByte + byId - 1, known[k].ToByte,
                     ContestId(known[k]) + ': handles are dense from the first by-id one');
         end;
      end;
   CheckTrue(byId >= 1, 'the fixture is among them');
end;

procedure TContestByIdTests.Test_TheNameResolverFindsIt;
var
   h: TContestHandle;
begin
   BeginTest('Test_TheNameResolverFindsIt');
   CheckTrue(TryContestFromName(TEST_FIXTURE_CONTEST_ID, h) and (h = FixtureHandle),
             'its id resolves');
   CheckTrue(TryContestFromName('  ' + LowerCase(TEST_FIXTURE_CONTEST_ID) + ' ', h) and
             (h = FixtureHandle),
             'whatever the case and the surrounding blanks');
   CheckTrue(ContestFromName(TEST_FIXTURE_CONTEST_ID) = FixtureHandle,
             'ContestFromName agrees');
   CheckEquals(TEST_FIXTURE_CONTEST_ID, CurrentContestSpelling(TEST_FIXTURE_CONTEST_ID),
               'a current id is stored as written');
end;

procedure TContestByIdTests.Test_TheRegistryWalkSeesIt;
var
   contests: TContestIdentityList;
   k, seen: integer;
begin
   BeginTest('Test_TheRegistryWalkSeesIt');
   contests := ContestsToWalk;
   seen := 0;
   for k := 0 to High(contests) do
      begin
      if contests[k] is TContestTestFixture then
         begin
         inc(seen);
         CheckTrue(contests[k] = ContestIdentity(FixtureHandle),
                   'the walk hands out the shared identity object');
         end;
      end;
   CheckEquals(1, seen, 'every invariant that walks the registry meets the fixture once');
   CheckTrue(ContestOf(ContestIdentity(FixtureHandle)) = DUMMYCONTEST,
             'and no enum-keyed pin can name it');
end;

procedure TContestByIdTests.Test_TheChoicesAndTheContestVocabularyOfferIt;
var
   choices: TContestChoices;
   offered: TArray<string>;
   k, seen: integer;
begin
   BeginTest('Test_TheChoicesAndTheContestVocabularyOfferIt');
   choices := TContestChoices.Create;
   try
      CheckTrue(choices.IndexOf(FixtureHandle) >= 0, 'the New Contest drop-down offers it');
   finally
      choices.Free;
   end;

   offered := Settings.AllowedValuesForCommand('CONTEST');
   seen := 0;
   for k := 0 to High(offered) do
      begin
      if offered[k] = TEST_FIXTURE_CONTEST_ID then
         begin
         inc(seen);
         end;
      end;
   CheckEquals(1, seen, 'the CONTEST setting accepts its id, once');
end;

procedure TContestByIdTests.Test_AnIdIsRefusedForTheRightReasons;

   procedure Refused(const aId, aWhy: string);
   begin
      CheckTrue(ContestIdRefusal(aId) <> '', '''' + aId + ''' is refused: ' + aWhy);
   end;

begin
   BeginTest('Test_AnIdIsRefusedForTheRightReasons');
   Refused('', 'empty');
   Refused(' NEW CONTEST', 'a leading blank');
   Refused('NEW CONTEST ', 'a trailing blank');
   Refused('NEW' + #9 + 'CONTEST', 'a control character');
   Refused('NEW ' + #$00E9 + ' CONTEST', 'not printable ASCII');
   Refused('ARRL-DX-CW', 'a legacy contest''s stored name');
   Refused('arrl-dx-cw', 'whatever the case');
   Refused('DUMMY CONTEST', 'NoContest''s stored name too');
   Refused('NEQP', 'a legacy alias (New England''s old name)');
   Refused(TEST_FIXTURE_CONTEST_ID, 'already registered by id');
   Refused(LowerCase(TEST_FIXTURE_CONTEST_ID), 'already registered, whatever the case');
   CheckEquals('', ContestIdRefusal('A NEW CONTEST NOBODY HAS'), 'a fresh id is accepted');
   CheckEquals('', ContestIdRefusal('NEW-CONTEST_2'), 'hyphens, digits and underscores are fine');
end;

procedure TContestByIdTests.Test_ARegistrationAfterTheSealRaises;

   function RaisesById(const aId: string; aCls: TContestClass): string;
   begin
      Result := '';
      try
         RegisterContestById(aId, aCls);
      except
         on E: Exception do
            begin
            Result := E.Message;
            end;
      end;
   end;

var
   msg: string;
   h: TContestHandle;
begin
   BeginTest('Test_ARegistrationAfterTheSealRaises');
   (* The registry has been asked many questions by now, so it is sealed. *)
   CheckTrue(IsKnownContest(FixtureHandle), 'the registry has answered, so it is sealed');

   msg := RaisesById('A NEW CONTEST NOBODY HAS', TContestTestFixture);
   CheckTrue(Pos('sealed', msg) > 0, 'a fresh id after the seal raises, saying so: ' + msg);
   CheckFalse(FindContestById('A NEW CONTEST NOBODY HAS', h), 'and registers nothing');

   msg := RaisesById('ARRL-DX-CW', TContestTestFixture);
   CheckTrue(Pos('legacy contest', msg) > 0, 'a legacy spelling raises with its reason: ' + msg);

   msg := RaisesById('NEW CONTEST WITH NO CLASS', nil);
   CheckTrue(Pos('nil class', msg) > 0, 'a nil class raises: ' + msg);

   (* A LEGACY REGISTRATION AFTER THE SEAL RAISES TOO. DUMMYCONTEST is the one
      member with no class, so only the seal can refuse it. *)
   msg := '';
   try
      RegisterContest(DUMMYCONTEST, TContestTestFixture);
   except
      on E: Exception do
         begin
         msg := E.Message;
         end;
   end;
   CheckTrue(Pos('sealed', msg) > 0, 'a legacy registration after the seal raises: ' + msg);
   CheckTrue(ContestClassFor(NoContest) = nil, 'and NoContest still has no class');
end;

(* THE APPLICATION'S PROGRAM FILE NAMES NO TEST FIXTURE. Lint-ContestUnitsLinked
  holds the same from the build; this is the unit-test half the design asks
  for, read from the tree beside this test program (tr4w/test/unit). The
  contest matrix asks the running application's own registry. *)
procedure TContestByIdTests.Test_TheFixtureIsNotInTheApplication;
var
   lpr: TStringList;
   path: string;
begin
   BeginTest('Test_TheFixtureIsNotInTheApplication');
   path := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
                          PathDelim + 'tr4w.lpr');
   CheckTrue(FileExists(path), 'tr4w.lpr is beside the tests: ' + path);
   if not FileExists(path) then
      begin
      Exit;
      end;
   lpr := TStringList.Create;
   try
      lpr.LoadFromFile(AnsiString(path));
      CheckTrue(Pos('UCONTESTREGISTRY', UpperCase(lpr.Text)) > 0,
                'the file read is the application (it links the registry)');
      CheckEquals(0, Pos('UCONTESTTESTFIXTURE', UpperCase(lpr.Text)),
                  'the application does not name the test fixture''s unit');
   finally
      lpr.Free;
   end;
end;

procedure TContestByIdTests.RunAllTests;
begin
   Test_TheFixtureHasAHandleAboveTheLegacyRange;
   Test_KnownContestsListTheLegacyOnesThenTheByIdOnes;
   Test_TheNameResolverFindsIt;
   Test_TheRegistryWalkSeesIt;
   Test_TheChoicesAndTheContestVocabularyOfferIt;
   Test_AnIdIsRefusedForTheRightReasons;
   Test_ARegistrationAfterTheSealRaises;
   Test_TheFixtureIsNotInTheApplication;
end;

end.

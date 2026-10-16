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

(* A CONTEST NAME READ BACK INTO A ContestType -- uContestNames (2026-10-16,
  design Q105).

  The New England QSO Party was 'NEQP' and is 'NEWEQP'; 'NEQP' is a
  permanent READ alias, because every older .cfg and contest log stores it.
  Pinned at every reader: the function, TF.GetContestFromString, the CONTEST
  setting, and a contest log whose contest row still says NEQP. And the
  rules that keep an alias safe: none equals a live spelling, and no two
  live spellings differ only by case (the one rule is case-insensitive). *)
unit uTestContestNames;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNamesTests = class(TTestCase)
   private
      FDir: string;
      function TempLogName(const aLeaf: string): string;
      procedure Scrub(const aFileName: string);
   public
      procedure RunAllTests; override;
   private
      procedure Test_BothNewEnglandSpellingsResolveToNewEngland;
      procedure Test_NebraskaIsNEQSOParty;
      procedure Test_NoAliasShadowsALiveName;
      procedure Test_NoTwoLiveNamesDifferOnlyByCase;
      procedure Test_EveryLiveNameResolvesToItself;
      procedure Test_CurrentSpellingTranslatesOnlyALegacyName;
      procedure Test_TheContestSettingReadsTheLegacyName;
      procedure Test_ALogStoringNEQPReopensAsNewEngland;
   end;

implementation

uses
   SysUtils, VC, TF, uContestNames, uSettingsModel,
   (* uCFG registers the CONTEST setting's vocabulary and its spelling. *)
   uCFG,
   uLogDatabase, uLogRepository;

function TContestNamesTests.TempLogName(const aLeaf: string): string;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_contestnames_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   Result := IncludeTrailingPathDelimiter(FDir) + aLeaf;
end;

procedure TContestNamesTests.Scrub(const aFileName: string);
begin
   if FileExists(aFileName) then
      begin
      DeleteFile(aFileName);
      end;
   if FileExists(aFileName + '-wal') then
      begin
      DeleteFile(aFileName + '-wal');
      end;
   if FileExists(aFileName + '-shm') then
      begin
      DeleteFile(aFileName + '-shm');
      end;
end;

procedure TContestNamesTests.Test_BothNewEnglandSpellingsResolveToNewEngland;
var
   c: ContestType;
begin
   BeginTest('Test_BothNewEnglandSpellingsResolveToNewEngland');
   CheckEquals('NEWEQP', string(ContestTypeSA[NEWENGLANDQSO]), 'the current spelling');
   CheckTrue(TryContestFromName('NEWEQP', c), 'NEWEQP resolves');
   CheckEquals(Ord(NEWENGLANDQSO), Ord(c), 'NEWEQP is New England');
   CheckTrue(TryContestFromName('NEQP', c), 'NEQP resolves');
   CheckEquals(Ord(NEWENGLANDQSO), Ord(c), 'NEQP is New England, for good');
   CheckEquals(Ord(NEWENGLANDQSO), Ord(ContestFromName(' neqp ')),
               'case and blanks ignored, as the config file always did');
   CheckEquals(Ord(NEWENGLANDQSO), Ord(GetContestFromString('NEQP')),
               'TF.GetContestFromString reads the legacy name');
   CheckEquals(Ord(NEWENGLANDQSO), Ord(GetContestFromString('NEWEQP')),
               'and the current one');
end;

procedure TContestNamesTests.Test_NebraskaIsNEQSOParty;
var
   c: ContestType;
begin
   BeginTest('Test_NebraskaIsNEQSOParty');
   CheckTrue(TryContestFromName('NE-QSO-PARTY', c), 'NE-QSO-PARTY resolves');
   CheckEquals(Ord(NEBRASKAQSO), Ord(c), 'NE-QSO-PARTY is Nebraska');
   CheckEquals(Ord(NEBRASKAQSO), Ord(GetContestFromString('NE-QSO-PARTY')),
               'through TF as well');
   CheckFalse(TryContestFromName('NOT A CONTEST', c), 'nonsense resolves to nothing');
   CheckEquals(Ord(DUMMYCONTEST), Ord(c), 'and says DUMMYCONTEST');
   CheckFalse(TryContestFromName('', c), 'an empty name is no contest');
end;

procedure TContestNamesTests.Test_NoAliasShadowsALiveName;
var
   i: integer;
   c: ContestType;
begin
   BeginTest('Test_NoAliasShadowsALiveName');
   for i := Low(LEGACY_CONTEST_NAMES) to High(LEGACY_CONTEST_NAMES) do
      begin
      for c := Low(ContestType) to High(ContestType) do
         begin
         CheckFalse(SameText(LEGACY_CONTEST_NAMES[i].Name, string(ContestTypeSA[c])),
                    'alias ' + LEGACY_CONTEST_NAMES[i].Name +
                    ' is the live spelling of ordinal ' + IntToStr(Ord(c)));
         end;
      CheckTrue(LEGACY_CONTEST_NAMES[i].Contest <> DUMMYCONTEST,
                'alias ' + LEGACY_CONTEST_NAMES[i].Name + ' names a contest');
      end;
end;

procedure TContestNamesTests.Test_NoTwoLiveNamesDifferOnlyByCase;
var
   a, b: integer;
begin
   BeginTest('Test_NoTwoLiveNamesDifferOnlyByCase');
   (* ORDINALS, so the inner loop's start cannot step past the enum. *)
   for a := Ord(Low(ContestType)) to Ord(High(ContestType)) do
      begin
      for b := a + 1 to Ord(High(ContestType)) do
         begin
         CheckFalse(SameText(Trim(ContestTypeSA[ContestType(a)]),
                             Trim(ContestTypeSA[ContestType(b)])),
                    'ordinals ' + IntToStr(a) + ' and ' + IntToStr(b) +
                    ' share the name ' + string(ContestTypeSA[ContestType(a)]));
         end;
      end;
end;

procedure TContestNamesTests.Test_EveryLiveNameResolvesToItself;
var
   c, found: ContestType;
begin
   BeginTest('Test_EveryLiveNameResolvesToItself');
   for c := Low(ContestType) to High(ContestType) do
      begin
      CheckTrue(TryContestFromName(string(ContestTypeSA[c]), found),
                string(ContestTypeSA[c]) + ' resolves');
      CheckEquals(Ord(c), Ord(found), string(ContestTypeSA[c]) + ' is itself');
      CheckEquals(string(ContestTypeSA[c]), CurrentContestSpelling(string(ContestTypeSA[c])),
                  string(ContestTypeSA[c]) + ' is already current');
      end;
end;

procedure TContestNamesTests.Test_CurrentSpellingTranslatesOnlyALegacyName;
begin
   BeginTest('Test_CurrentSpellingTranslatesOnlyALegacyName');
   CheckEquals('NEWEQP', CurrentContestSpelling('NEQP'), 'the legacy name becomes the current one');
   CheckEquals('NEWEQP', CurrentContestSpelling(' neqp '), 'whatever its case');
   CheckEquals('cq-ww-cw', CurrentContestSpelling('cq-ww-cw'),
               'a live name is left exactly as written');
   CheckEquals('NOT A CONTEST', CurrentContestSpelling('NOT A CONTEST'),
               'text that is no contest is left for the vocabulary to refuse');
end;

procedure TContestNamesTests.Test_TheContestSettingReadsTheLegacyName;
var
   s: TR4WSettings;
begin
   BeginTest('Test_TheContestSettingReadsTheLegacyName');
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('CONTEST', 'NEQP'),
                'CONTEST = NEQP is accepted -- a D7 .cfg says it');
      CheckEquals('NEWEQP', s.Contest.ContestToken,
                  'and stored as the current spelling');
      CheckTrue(s.TrySetByCommand('CONTEST', 'NE-QSO-PARTY'), 'Nebraska is accepted');
      CheckEquals('NE-QSO-PARTY', s.Contest.ContestToken, 'and stored as written');
      CheckFalse(s.TrySetByCommand('CONTEST', 'NOT A CONTEST'), 'nonsense is refused');
      CheckEquals('NE-QSO-PARTY', s.Contest.ContestToken, 'and changes nothing');
   finally
      s.Free;
   end;
end;

procedure TContestNamesTests.Test_ALogStoringNEQPReopensAsNewEngland;
var
   fn: string;
   db: TLogDatabase;
   repo: TLogRepository;
begin
   BeginTest('Test_ALogStoringNEQPReopensAsNewEngland');
   fn := TempLogName('neqp.db');
   Scrub(fn);
   db := TLogDatabase.Create;
   try
      db.CreateNew(fn);
      repo := TLogRepository.Create(db);
      try
         repo.SetContest(NEWENGLANDQSO);
         repo.Commit;
      finally
         repo.Free;
      end;

      (* THE ROW A LOG WRITTEN BEFORE 2026-10-16 HOLDS. *)
      db.Connection.ExecuteDirect(
         'UPDATE contest SET contest_type = ''NEQP'' WHERE id = 1');
      db.Transaction.Commit;

      repo := TLogRepository.Create(db);
      try
         CheckEquals(Ord(NEWENGLANDQSO), Ord(repo.LogContest),
                     'a log storing NEQP reopens as New England -- never Nebraska');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

procedure TContestNamesTests.RunAllTests;
begin
   Test_BothNewEnglandSpellingsResolveToNewEngland;
   Test_NebraskaIsNEQSOParty;
   Test_NoAliasShadowsALiveName;
   Test_NoTwoLiveNamesDifferOnlyByCase;
   Test_EveryLiveNameResolvesToItself;
   Test_CurrentSpellingTranslatesOnlyALegacyName;
   Test_TheContestSettingReadsTheLegacyName;
   Test_ALogStoringNEQPReopensAsNewEngland;
end;

end.

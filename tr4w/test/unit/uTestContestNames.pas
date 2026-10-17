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

(* A CONTEST NAME READ BACK INTO A CONTEST -- uContestNames (2026-10-16,
  design Q105), over the registry's ids since Q108 S2.

  The New England QSO Party was 'NEQP' and is 'NEWEQP'; 'NEQP' is a
  permanent READ alias, because every older .cfg and contest log stores it.
  Pinned at every reader: the function, the CONTEST setting, and a contest
  log whose contest row still says NEQP (TF.GetContestFromString, the third,
  is deleted -- the log repository asks ContestFromName). And the rules that
  keep an alias safe: none equals a live id, its id resolves, and no two
  live ids differ only by case (the one rule is case-insensitive). The
  walks are over the registry's KNOWN contests (KnownContests), so a contest
  registered by id alone (Q108 S3) is held to them too. *)
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
      procedure Test_TheContestVocabularyIsEveryKnownId;
   end;

implementation

uses
   uContestRegistry,   (* ContestHandleOf -- a legacy contest's handle, Q108 S2 *)
   SysUtils, VC, uContestNames, uSettingsModel,
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
   c: TContestHandle;
begin
   BeginTest('Test_BothNewEnglandSpellingsResolveToNewEngland');
   CheckEquals('NEWEQP', string(ContestTypeSA[NEWENGLANDQSO]), 'the current spelling');
   CheckTrue(TryContestFromName('NEWEQP', c), 'NEWEQP resolves');
   CheckEquals(Ord(NEWENGLANDQSO), c.ToByte, 'NEWEQP is New England');
   CheckTrue(TryContestFromName('NEQP', c), 'NEQP resolves');
   CheckEquals(Ord(NEWENGLANDQSO), c.ToByte, 'NEQP is New England, for good');
   CheckEquals(Ord(NEWENGLANDQSO), ContestFromName(' neqp ').ToByte,
               'case and blanks ignored, as the config file always did');
   CheckEquals(Ord(NEWENGLANDQSO), ContestFromName('NEWEQP').ToByte,
               'ContestFromName, the log row''s reader, reads the current one');
end;

procedure TContestNamesTests.Test_NebraskaIsNEQSOParty;
var
   c: TContestHandle;
begin
   BeginTest('Test_NebraskaIsNEQSOParty');
   CheckTrue(TryContestFromName('NE-QSO-PARTY', c), 'NE-QSO-PARTY resolves');
   CheckEquals(Ord(NEBRASKAQSO), c.ToByte, 'NE-QSO-PARTY is Nebraska');
   CheckEquals(Ord(NEBRASKAQSO), ContestFromName('NE-QSO-PARTY').ToByte,
               'through ContestFromName as well');
   CheckFalse(TryContestFromName('NOT A CONTEST', c), 'nonsense resolves to nothing');
   CheckTrue(c = NoContest, 'and says NoContest');
   CheckFalse(TryContestFromName('', c), 'an empty name is no contest');
end;

procedure TContestNamesTests.Test_NoAliasShadowsALiveName;
var
   i, k: integer;
   known: TContestHandleList;
   c: TContestHandle;
begin
   BeginTest('Test_NoAliasShadowsALiveName');
   known := KnownContests;
   CheckTrue(Length(known) > 100, 'the registry knows the contests');
   for i := Low(LEGACY_CONTEST_NAMES) to High(LEGACY_CONTEST_NAMES) do
      begin
      for k := 0 to High(known) do
         begin
         CheckFalse(UnicodeSameText(LEGACY_CONTEST_NAMES[i].Name, ContestId(known[k])),
                    'alias ' + LEGACY_CONTEST_NAMES[i].Name +
                    ' is the live id of contest ' + IntToStr(known[k].ToByte));
         end;
      (* ITS ID RESOLVES, to a contest -- an alias naming an id nobody
         registers would resolve nothing, silently. *)
      CheckTrue(FindContestById(LEGACY_CONTEST_NAMES[i].Id, c) and (c <> NoContest),
                'alias ' + LEGACY_CONTEST_NAMES[i].Name + ' names a contest');
      CheckEquals(LEGACY_CONTEST_NAMES[i].Id, ContestId(c),
                  'alias ' + LEGACY_CONTEST_NAMES[i].Name + ' names a CURRENT id, exactly');
      end;
end;

procedure TContestNamesTests.Test_NoTwoLiveNamesDifferOnlyByCase;
var
   a, b: integer;
   known: TContestHandleList;
begin
   BeginTest('Test_NoTwoLiveNamesDifferOnlyByCase');
   known := KnownContests;
   for a := 0 to High(known) do
      begin
      for b := a + 1 to High(known) do
         begin
         CheckFalse(UnicodeSameText(Trim(ContestId(known[a])),
                                    Trim(ContestId(known[b]))),
                    'contests ' + IntToStr(known[a].ToByte) + ' and ' +
                    IntToStr(known[b].ToByte) + ' share the id ' + ContestId(known[a]));
         end;
      end;
end;

procedure TContestNamesTests.Test_EveryLiveNameResolvesToItself;
var
   known: TContestHandleList;
   k: integer;
   found: TContestHandle;
   id: string;
begin
   BeginTest('Test_EveryLiveNameResolvesToItself');
   known := KnownContests;
   for k := 0 to High(known) do
      begin
      id := ContestId(known[k]);
      CheckTrue(TryContestFromName(id, found), id + ' resolves');
      CheckTrue(found = known[k], id + ' is itself');
      CheckEquals(id, CurrentContestSpelling(id), id + ' is already current');
      end;
   (* AND A LEGACY CONTEST'S ID IS ITS ContestTypeSA SPELLING -- the stored
      name did not move when the registry took the ids over (Q108 S2). *)
   for k := Ord(Low(ContestType)) to Ord(High(ContestType)) do
      begin
      CheckEquals(string(ContestTypeSA[ContestType(k)]),
                  ContestId(ContestHandleOf(ContestType(k))),
                  'legacy number ' + IntToStr(k) + ': its id is its spelling');
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
         repo.SetContest(ContestHandleOf(NEWENGLANDQSO));
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
         CheckEquals(Ord(NEWENGLANDQSO), repo.LogContest.ToByte,
                     'a log storing NEQP reopens as New England -- never Nebraska');
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
   Scrub(fn);
end;

(* THE CONTEST SETTING'S VOCABULARY IS THE REGISTRY'S IDS, READ WHEN ASKED
   (Q108 S2). uCFG registers it from its initialization, which runs before
   any contest unit registers, so a list copied then would be empty; it is a
   provider, and what it answers here -- after every unit has initialised --
   is every known contest's id in handle order, which today is ContestTypeSA
   exactly. *)
procedure TContestNamesTests.Test_TheContestVocabularyIsEveryKnownId;
var
   offered: TArray<string>;
   known: TContestHandleList;
   k: integer;
begin
   BeginTest('Test_TheContestVocabularyIsEveryKnownId');
   offered := Settings.AllowedValuesForCommand('CONTEST');
   known := KnownContests;
   CheckEquals(Length(known), Length(offered), 'one value per known contest');
   for k := 0 to High(known) do
      begin
      if k > High(offered) then
         begin
         Break;
         end;
      CheckEquals(ContestId(known[k]), offered[k], 'value ' + IntToStr(k));
      end;
   CheckEquals(Ord(High(ContestType)) + 1, Length(offered),
               'today, exactly the legacy contests');
   for k := 0 to High(offered) do
      begin
      if k > Ord(High(ContestType)) then
         begin
         Break;
         end;
      CheckEquals(string(ContestTypeSA[ContestType(k)]), offered[k],
                  'value ' + IntToStr(k) + ' is the legacy spelling');
      end;
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
   Test_TheContestVocabularyIsEveryKnownId;
end;

end.

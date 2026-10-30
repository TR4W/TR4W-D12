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

(* WHAT THE UI ITSELF ASKS A CONTEST -- milestone M9b, 2026-10-02
  (docs/CONTEST_OWNERSHIP_DESIGN.md section 8.2n).

  NO AUTOMATED ORACLE SEES A WINDOW. The matrix and the corpus read files; the
  New Contest drop-down, the call-entry displays, the log's columns and the
  summary window's power row are seen only on the bench. So what each of them
  is BUILT FROM is pinned here, without a form:

    * THE DROP-DOWN'S LIST (uContestChoices): every contest once, active
      before inactive, by display name, inactive ones marked, no two lines
      alike.
    * IsActive: exactly the contests NY4I named inactive -- a ratchet.
    * THE CALL-ENTRY AND LOG TRAITS, each contest by contest with every other
      contest's base answer as a ratchet: General QSO's three, the FOC
      Marathon's power column, WAG's frequency windows to the kHz.
    * A CATEGORY-POWER CHANGE (uCategoryPowerChange): when it sets, when it
      rescores, and that re-saving the same value does neither.
    * THE MINIMUM OFF TIME (Q60): 60 for the CQ WW family, 30 for every other
      contest, and PostUnit's gap rule at its edge. No oracle sees it -- the
      summary sheet is not in the matrix or the corpus. *)
unit uTestContestUI;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestUITests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ChoicesListEveryContestOnce;
      procedure Test_ChoicesActiveFirstThenByDisplayName;
      procedure Test_ChoicesShowDisplayNamesAndMarkInactive;
      procedure Test_ChoiceCaptionsAreUnique;
      procedure Test_OnlyNamedContestsAreInactive;
      procedure Test_GeneralQSOIsALog;
      procedure Test_FOCMarathonPowerColumn;
      procedure Test_WAGFrequencyWarning;
      procedure Test_CategoryPowerChange;
      procedure Test_Q61_CategoriesAreOneValueEach;
      procedure Test_EveryCategoryMayBeBlank;
      procedure Test_OnlyCQWWHasASixtyMinuteBreak;
      procedure Test_AGapCountsUpToTheBreak;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uContestChoices,
   uCategoryPowerChange,
   (* CabrilloTagText -- what a closed summary window answers, Q61 *)
   uCbrSum,
   uSettingsModel,
   uAppStrings,
   uTR4WStrings,
   PostUnit,
   uTestContestObjects,
   (* ContestsToWalk -- the invariants walk the registry (Q108 S1). *)
   uTestRegisteredContests;

const
   (* NY4I, 2026-10-01/02: inactive, kept for old logs. Add one only on his
      word, and in the same commit as its class's GetIsActive. *)
   INACTIVE_CONTESTS: array[0..1] of ContestType = (SASPRINT, LQP);

(* Asked of the walked object (issue #96): a contest registered by its id is
  no legacy member, so it is never on the list -- it must be active. *)
function IsListedInactive(aContest: TContestBase): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(INACTIVE_CONTESTS) to High(INACTIVE_CONTESTS) do
      begin
      if IsLegacyContest(aContest, INACTIVE_CONTESTS[i]) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* ------------------------------------------------------------------------ *)
(* THE NEW CONTEST DROP-DOWN                                                 *)
(* ------------------------------------------------------------------------ *)

procedure TContestUITests.Test_ChoicesListEveryContestOnce;
var
   choices: TContestChoices;
   contests: TContestIdentityList;
   c: TContestHandle;
   k, i, seen: integer;
begin
   BeginTest('Test_ChoicesListEveryContestOnce');
   choices := TContestChoices.Create;
   try
      (* EVERY REGISTERED CONTEST IS OFFERED, ONCE -- walked over the registry
         (Q108 S1), so a contest registered by its id must appear too.
         DUMMYCONTEST, which has no class, is never offered. *)
      contests := ContestsToWalk;
      CheckEquals(Length(contests), choices.Count, 'one line per registered contest');
      CheckEquals(-1, choices.IndexOf(NoContest), 'DUMMYCONTEST is not offered');

      for k := 0 to High(contests) do
         begin
         c := HandleOf(contests[k]);
         seen := 0;
         for i := 0 to choices.Count - 1 do
            begin
            if choices.Contest[i] = c then
               begin
               inc(seen);
               end;
            end;
         CheckEquals(1, seen, ContestWho(contests[k]) + ' is offered exactly once');
         CheckTrue(choices.IndexOf(c) >= 0, ContestWho(contests[k]) + ': IndexOf finds it');
         if choices.IndexOf(c) >= 0 then
            begin
            CheckTrue(choices.Contest[choices.IndexOf(c)] = c,
                      ContestWho(contests[k]) + ': IndexOf answers its own line');
            end;
         end;
   finally
      choices.Free;
   end;
end;

procedure TContestUITests.Test_ChoicesActiveFirstThenByDisplayName;
var
   choices: TContestChoices;
   i, firstInactive: integer;
   prev, cur: TContestBase;
   who: string;
begin
   BeginTest('Test_ChoicesActiveFirstThenByDisplayName');
   choices := TContestChoices.Create;
   try
      firstInactive := choices.Count;
      for i := 0 to choices.Count - 1 do
         begin
         if not ContestIdentity(choices.Contest[i]).IsActive then
            begin
            firstInactive := i;
            Break;
            end;
         end;

      (* EVERY INACTIVE CONTEST IS AFTER EVERY ACTIVE ONE -- and they are the
         last lines, as many as there are inactive contests. *)
      CheckEquals(Length(INACTIVE_CONTESTS), choices.Count - firstInactive,
                  'the inactive contests are the last lines');
      for i := firstInactive to choices.Count - 1 do
         begin
         CheckFalse(ContestIdentity(choices.Contest[i]).IsActive,
                    'line ' + IntToStr(i) + ' is past the first inactive one, and inactive');
         end;

      (* WITHIN EACH GROUP, BY DISPLAY NAME, case-insensitively; a tie by the
         enum's order. *)
      for i := 1 to choices.Count - 1 do
         begin
         prev := ContestIdentity(choices.Contest[i - 1]);
         cur  := ContestIdentity(choices.Contest[i]);
         if prev.IsActive <> cur.IsActive then
            begin
            Continue;
            end;
         who := prev.DisplayName + ' / ' + cur.DisplayName;
         CheckTrue(UnicodeCompareText(prev.DisplayName, cur.DisplayName) <= 0,
                   who + ': in display-name order');
         if UnicodeCompareText(prev.DisplayName, cur.DisplayName) = 0 then
            begin
            CheckTrue(choices.Contest[i - 1].ToByte < choices.Contest[i].ToByte,
                      who + ': a tie in enum order');
            end;
         end;
   finally
      choices.Free;
   end;
end;

procedure TContestUITests.Test_ChoicesShowDisplayNamesAndMarkInactive;
var
   choices: TContestChoices;
   i, j, shared: integer;
   identity: TContestBase;
   who, name: string;
begin
   BeginTest('Test_ChoicesShowDisplayNamesAndMarkInactive');
   choices := TContestChoices.Create;
   try
      shared := 0;
      for i := 0 to choices.Count - 1 do
         begin
         identity := ContestIdentity(choices.Contest[i]);
         who := ContestId(choices.Contest[i]);

         (* THE DISPLAY NAME, and the token in brackets only where another
            line carries the same name. *)
         name := identity.DisplayName;
         for j := 0 to choices.Count - 1 do
            begin
            if (j <> i) and
               UnicodeSameText(ContestIdentity(choices.Contest[j]).DisplayName, name) then
               begin
               name := name + ' [' + who + ']';
               inc(shared);
               Break;
               end;
            end;

         if identity.IsActive then
            begin
            CheckEquals(name, choices.Caption[i],
                        who + ': the line is the display name');
            end
         else
            begin
            CheckEquals(Format(SContestInactive, [name]),
                        choices.Caption[i], who + ': the line is marked inactive');
            end;
         CheckEquals(choices.Caption[i], ContestChoiceCaption(choices.Contest[i]),
                     who + ': one caption rule');
         end;

      (* THE ENGLISH MARK, as an operator without a catalogue reads it. *)
      (* Its display name since design Q53 (2026-10-17); 'SA-SPRINT' before. *)
      CheckEquals('SA Sprint Contest (inactive)', ContestChoiceCaption(ContestHandleOf(SASPRINT)),
                  'SA Sprint is marked');

      (* NO TWO LINES SHARE A DISPLAY NAME TODAY -- a RATCHET. The one pair
         there was, IARU-HF and WRTC, ended when WRTC took a name of its own
         (NY4I, 2026-10-16, design Q58). A new pair fails here and is a
         display name to ask NY4I for. The bracket rule itself stays in
         uContestChoices for such a pair, and the loop above states it
         independently of that unit -- but with no pair it is exercised by
         nothing, because the rule is inline in ContestChoiceCaption and
         answers only for a real ContestType. *)
      CheckEquals(0, shared, 'no two lines share a display name');
      CheckEquals('IARU HF World Championship', ContestChoiceCaption(ContestHandleOf(IARU)),
                  'IARU-HF is shown bare');
      CheckEquals('World Radiosport Team Championship', ContestChoiceCaption(ContestHandleOf(WRTC)),
                  'WRTC is shown bare, by its own name');
   finally
      choices.Free;
   end;
end;

(* TWO LINES ALIKE WOULD BE ONE CONTEST AN OPERATOR CANNOT PICK -- the radio
  list's rule (a duplicate display name makes a model invisible) applied
  here. *)
procedure TContestUITests.Test_ChoiceCaptionsAreUnique;
var
   choices: TContestChoices;
   i, j: integer;
begin
   BeginTest('Test_ChoiceCaptionsAreUnique');
   choices := TContestChoices.Create;
   try
      for i := 0 to choices.Count - 1 do
         begin
         for j := i + 1 to choices.Count - 1 do
            begin
            CheckFalse(UnicodeSameText(choices.Caption[i], choices.Caption[j]),
                       ContestId(choices.Contest[i]) + ' and ' +
                       ContestId(choices.Contest[j]) +
                       ' share the line "' + choices.Caption[i] + '"');
            end;
         end;
   finally
      choices.Free;
   end;
end;

procedure TContestUITests.Test_OnlyNamedContestsAreInactive;
var
   contests: TContestIdentityList;
   k: integer;
   obj: TContestBase;
begin
   BeginTest('Test_OnlyNamedContestsAreInactive');
   (* EVERY REGISTERED CONTEST, BY THE REGISTRY -- an invariant, so a
      contest registered by its id is held to it too (Q108 S1). *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      obj := NewContestLike(contests[k], NoStation);
      try
         CheckEquals(Ord(not IsListedInactive(obj)), Ord(obj.IsActive),
                     ContestWho(obj) + ': IsActive');
      finally
         obj.Free;
      end;
      end;
end;

(* ------------------------------------------------------------------------ *)
(* CALL ENTRY AND THE LOG                                                    *)
(* ------------------------------------------------------------------------ *)

procedure TContestUITests.Test_GeneralQSOIsALog;
var
   contests: TContestIdentityList;
   k: integer;
   obj: TContestBase;
   who: string;
   isLog: boolean;
begin
   BeginTest('Test_GeneralQSOIsALog');
   (* EVERY REGISTERED CONTEST, BY THE REGISTRY -- an invariant, so a
      contest registered by its id is held to it too (Q108 S1). *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      obj := NewContestLike(contests[k], NoStation);
      try
         who := ContestWho(obj);
         isLog := IsLegacyContest(obj, GENERALQSO);
         CheckEquals(Ord(not isLog), Ord(obj.ShowsContestStatus),
                     who + ': call entry shows contest status');
         if isLog then
            begin
            CheckEquals(0, obj.MaximumContestDates, who + ': never warns of dates');
            end
         else
            begin
            CheckEquals(10, obj.MaximumContestDates, who + ': warns after ten dates');
            end;
         CheckEquals(Ord(isLog), Ord(obj.BandStepIncludesWARC),
                     who + ': band stepping reaches WARC');
      finally
         obj.Free;
      end;
      end;
end;

procedure TContestUITests.Test_FOCMarathonPowerColumn;
var
   contests: TContestIdentityList;
   k: integer;
   obj: TContestBase;
begin
   BeginTest('Test_FOCMarathonPowerColumn');
   (* EVERY REGISTERED CONTEST, BY THE REGISTRY -- an invariant, so a
      contest registered by its id is held to it too (Q108 S1). *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      obj := NewContestLike(contests[k], NoStation);
      try
         CheckEquals(Ord(IsLegacyContest(obj, FOCMARATHON)), Ord(obj.PowerFieldIsFOCNumber),
                     ContestWho(obj) + ': the power field is an FOC number');
      finally
         obj.Free;
      end;
      end;
end;

procedure TContestUITests.Test_WAGFrequencyWarning;
const
   (* MainUnit.WagCheck's windows, every bound exclusive, as it stood. Each
      row: kHz, does WAG warn. *)
   EDGES: array[0..23] of record
      kHz: integer;
      warns: boolean;
   end = (
      (kHz: 3650;  warns: False), (kHz: 3651;  warns: True),
      (kHz: 3699;  warns: True),  (kHz: 3700;  warns: False),
      (kHz: 7043;  warns: False), (kHz: 7044;  warns: True),
      (kHz: 7079;  warns: True),  (kHz: 7080;  warns: False),
      (kHz: 7081;  warns: True),  (kHz: 7142;  warns: True),
      (kHz: 7143;  warns: False), (kHz: 14060; warns: False),
      (kHz: 14061; warns: True),  (kHz: 14124; warns: True),
      (kHz: 14125; warns: False), (kHz: 14281; warns: True),
      (kHz: 14350; warns: False), (kHz: 21348; warns: True),
      (kHz: 21449; warns: True),  (kHz: 21450; warns: False),
      (kHz: 28226; warns: True),  (kHz: 28399; warns: True),
      (kHz: 28400; warns: False), (kHz: 0;     warns: False));
var
   contests: TContestIdentityList;
   k: integer;
   obj: TContestBase;
   i: integer;
   expected: string;
begin
   BeginTest('Test_WAGFrequencyWarning');
   (* EVERY REGISTERED CONTEST, BY THE REGISTRY -- an invariant, so a
      contest registered by its id is held to it too (Q108 S1). *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      obj := NewContestLike(contests[k], NoStation);
      try
         for i := Low(EDGES) to High(EDGES) do
            begin
            expected := '';
            if IsLegacyContest(obj, WAG) and EDGES[i].warns then
               begin
               expected := TC_WAGWarn;
               end;
            CheckEquals(expected, obj.CallEntryFrequencyWarning(EDGES[i].kHz),
                        ContestWho(obj) + ' at ' + IntToStr(EDGES[i].kHz) + ' kHz');
            end;
      finally
         obj.Free;
      end;
      end;
end;

(* ------------------------------------------------------------------------ *)
(* CATEGORY-POWER                                                            *)
(* ------------------------------------------------------------------------ *)

procedure TContestUITests.Test_CategoryPowerChange;
var
   from, toPower, got: tCategoryPower;
   change: TCategoryPowerChange;
   who: string;
begin
   BeginTest('Test_CategoryPowerChange');
   for from := Low(tCategoryPower) to High(tCategoryPower) do
      begin
      for toPower := Low(tCategoryPower) to High(tCategoryPower) do
         begin
         who := tCategoryPowerSA[from] + ' -> ' + tCategoryPowerSA[toPower];

         (* NOTHING LOGGED: set it, and no rescore and no reminder. *)
         change := DecideCategoryPowerChange(from, tCategoryPowerSA[toPower], 0, got);
         if from = toPower then
            begin
            CheckTrue(change = cpcUnchanged, who + ', empty log: unchanged');
            end
         else
            begin
            CheckTrue(change = cpcSet, who + ', empty log: set only');
            end;
         CheckTrue(got = toPower, who + ', empty log: the power chosen');

         (* QSOs LOGGED: set it and rescore -- the mid-contest reminder. *)
         change := DecideCategoryPowerChange(from, tCategoryPowerSA[toPower], 42, got);
         if from = toPower then
            begin
            CheckTrue(change = cpcUnchanged, who + ', 42 QSOs: re-saving rescores nothing');
            end
         else
            begin
            CheckTrue(change = cpcSetAndRescore, who + ', 42 QSOs: set and rescore');
            end;
         CheckTrue(got = toPower, who + ', 42 QSOs: the power chosen');
         end;
      end;

   (* THE ROW'S TEXT, AS A COMBO HANDS IT OVER: case and spaces do not matter;
      text that is no power changes nothing and keeps the current one. *)
   change := DecideCategoryPowerChange(cpHIGH, ' qrp ', 5, got);
   CheckTrue((change = cpcSetAndRescore) and (got = cpQRP), 'a lower-case, padded QRP is QRP');
   (* AN EMPTY ROW IS THE BLANK "no power" CHOICE NOW (2026-10-29), not "no
      change": '' is cpUNSET's spelling. The window guards "nothing selected"
      by the row's item index before asking. *)
   change := DecideCategoryPowerChange(cpLOW, '', 5, got);
   CheckTrue((change = cpcSetAndRescore) and (got = cpUNSET),
             'an empty row chooses UNSET, and rescores a logged contest');
   change := DecideCategoryPowerChange(cpUNSET, '', 5, got);
   CheckTrue((change = cpcUnchanged) and (got = cpUNSET), 'UNSET over UNSET changes nothing');
   change := DecideCategoryPowerChange(cpLOW, 'KILOWATT', 5, got);
   CheckTrue((change = cpcUnchanged) and (got = cpLOW), 'a value that is no power changes nothing');
end;

(* ------------------------------------------------------------------------ *)
(* Q61 -- ASSISTED, BAND, MODE, OPERATOR: ONE VALUE EACH                     *)
(* ------------------------------------------------------------------------ *)

(* TWO HALVES, BOTH WITHOUT A FORM.

  THE WINDOW'S RULE (CategoryChoiceIndex): a row commits only a spelling of
  its category that differs from the value in force -- so closing the window
  states nothing the operator did not change, and an ERMAK-only value such as
  MULTI-OP-2, which no setting can hold, is not offered to one.

  WHAT A CLOSED WINDOW ANSWERS (CabrilloTagText), which is what a headless
  /EXPORT and the 3830 report read: the setting, for all five categories. It
  answered the header store for four of them, so MODE was a stale copy and
  ASSISTED, BAND and OPERATOR were empty. *)
procedure TContestUITests.Test_Q61_CategoriesAreOneValueEach;
var
   m: tCategoryMode;
   savedAssisted: tCategoryAssisted;
   savedBand: tCategoryBand;
   savedMode: tCategoryMode;
   savedOperator: tCategoryOperator;
   savedPower: tCategoryPower;
begin
   BeginTest('Test_Q61_CategoriesAreOneValueEach');

   for m := Low(tCategoryMode) to High(tCategoryMode) do
      begin
      CheckEquals(-1, CategoryChoiceIndex(tCategoryModeSA, Ord(m), tCategoryModeSA[m]),
                  tCategoryModeSA[m] + ' over itself: no change');
      end;
   CheckEquals(Ord(cmSSB),
               CategoryChoiceIndex(tCategoryModeSA, Ord(cmCW), ' ssb '),
               'CW -> a padded, lower-case SSB is SSB');
   CheckEquals(Ord(caASSISTED),
               CategoryChoiceIndex(tCategoryAssistedSA, Ord(caNONASSISTED), 'ASSISTED'),
               'NON-ASSISTED -> ASSISTED');
   CheckEquals(Ord(cb40M),
               CategoryChoiceIndex(tCategoryBandSA, Ord(cbALL), '40M'),
               'ALL -> 40M');
   CheckEquals(-1, CategoryChoiceIndex(tCategoryOperatorSA, Ord(coSINGLEOP), 'MULTI-OP-2'),
               'an ERMAK value no setting can hold changes nothing');
   (* '' IS THE BLANK "no band" CHOICE NOW (2026-10-29), cbUNSET's spelling. *)
   CheckEquals(Ord(cbUNSET), CategoryChoiceIndex(tCategoryBandSA, Ord(cbALL), ''),
               'an empty row chooses UNSET');
   CheckEquals(-1, CategoryChoiceIndex(tCategoryBandSA, Ord(cbUNSET), ''),
               'UNSET over UNSET changes nothing');

   (* THE CLOSED WINDOW. The test program never opens it. *)
   CheckFalse(CabrilloSummaryIsOpen, 'the summary window is not open');
   savedAssisted := Settings.Contest.CategoryAssisted;
   savedBand := Settings.Contest.CategoryBand;
   savedMode := Settings.Contest.CategoryMode;
   savedOperator := Settings.Contest.CategoryOperator;
   savedPower := Settings.Contest.CategoryPower;
   try
      Settings.Contest.CategoryAssisted := caASSISTED;
      Settings.Contest.CategoryBand := cb20M;
      Settings.Contest.CategoryMode := cmMIXED;
      Settings.Contest.CategoryOperator := coMULTIOP;
      Settings.Contest.CategoryPower := cpQRP;
      CheckEquals('ASSISTED', CabrilloTagText(ctCategoryAssisted), 'ASSISTED is the setting');
      CheckEquals('20M', CabrilloTagText(ctCategoryBand), 'BAND is the setting');
      CheckEquals('MIXED', CabrilloTagText(ctCategoryMode), 'MODE is the setting');
      CheckEquals('MULTI-OP', CabrilloTagText(ctCategoryOperator), 'OPERATOR is the setting');
      CheckEquals('QRP', CabrilloTagText(ctCategoryPower), 'POWER is still the setting');
   finally
      Settings.Contest.CategoryAssisted := savedAssisted;
      Settings.Contest.CategoryBand := savedBand;
      Settings.Contest.CategoryMode := savedMode;
      Settings.Contest.CategoryOperator := savedOperator;
      Settings.Contest.CategoryPower := savedPower;
   end;
end;

(* ------------------------------------------------------------------------ *)
(* EVERY CATEGORY-* MAY BE BLANK -- NY4I, 2026-10-29                         *)
(* ------------------------------------------------------------------------ *)

(* "NONE of the CATEGORY-* fields is strictly required", and a blank one still
  writes its header line, bare: 'CATEGORY-OVERLAY:'.

  FOUR HALVES, ALL WITHOUT A FORM:
    * the six enum settings take '' by name and give '' back (the *UNSET
      member), and a fresh settings object still holds every old default --
      so no contest's export moves;
    * the header line: the bare tag for a blank category, 'TAG: value'
      otherwise, nothing for any other blank tag;
    * every category list the two windows are filled from ends in exactly
      one '', after the values it always offered;
    * a closed summary window answers '' for a blank enum category. *)
procedure TContestUITests.Test_EveryCategoryMayBeBlank;
const
   COMMANDS: array[0..5] of string = (
      'CATEGORY-ASSISTED', 'CATEGORY-BAND', 'CATEGORY-MODE',
      'CATEGORY-OPERATOR', 'CATEGORY-POWER', 'CATEGORY-TRANSMITTER');
   (* The constructor's -- what every contest exported before, unchanged. *)
   DEFAULTS: array[0..5] of string = (
      'NON-ASSISTED', 'ALL', 'CW', 'SINGLE-OP', 'HIGH', 'ONE');
   (* The nine tags, their names, and the FIRST value each list offered
      before the blank -- still first. *)
   CATEGORY_TAGS: array[0..8] of CabrilloTags = (
      ctCategoryAssisted, ctCategoryBand, ctCategoryMode, ctCategoryOperator,
      ctCategoryPower, ctCategoryStation, ctCategoryTime,
      ctCategoryTransmitter, ctCategoryOverlay);
   CATEGORY_NAMES: array[0..8] of string = (
      'CATEGORY-ASSISTED', 'CATEGORY-BAND', 'CATEGORY-MODE',
      'CATEGORY-OPERATOR', 'CATEGORY-POWER', 'CATEGORY-STATION',
      'CATEGORY-TIME', 'CATEGORY-TRANSMITTER', 'CATEGORY-OVERLAY');
   FIRST_VALUES: array[0..8] of string = (
      'NON-ASSISTED', 'ALL', 'CW', 'SINGLE-OP', 'HIGH', 'DISTRIBUTED',
      '6-HOURS', 'ONE', 'CLASSIC');
var
   s: TR4WSettings;
   i, j, blanks: integer;
   v: string;
   values: TArray<string>;
   savedPower: tCategoryPower;
   savedBand: tCategoryBand;
begin
   BeginTest('Test_EveryCategoryMayBeBlank');

   s := TR4WSettings.Create;
   try
      for i := Low(COMMANDS) to High(COMMANDS) do
         begin
         CheckTrue(s.TryGetByCommand(COMMANDS[i], v), COMMANDS[i] + ' reads');
         CheckEquals(DEFAULTS[i], v, COMMANDS[i] + ': the default is unchanged');

         CheckTrue(s.TrySetByCommand(COMMANDS[i], ''), COMMANDS[i] + ' takes a blank');
         CheckTrue(s.TryGetByCommand(COMMANDS[i], v), COMMANDS[i] + ' reads back');
         CheckEquals('', v, COMMANDS[i] + ' is blank');
         CheckTrue(s.CommandIsStated(COMMANDS[i]),
                   COMMANDS[i] + ': a blank is the operator''s statement');

         CheckTrue(s.TrySetByCommand(COMMANDS[i], DEFAULTS[i]),
                   COMMANDS[i] + ' goes back to its default');
         CheckTrue(s.TryGetByCommand(COMMANDS[i], v), COMMANDS[i] + ' reads again');
         CheckEquals(DEFAULTS[i], v, COMMANDS[i] + ': a blank is not sticky');
         end;

      CheckTrue(s.TrySetByCommand('CATEGORY-POWER', ''), 'POWER blank');
      CheckTrue(s.Contest.CategoryPower = cpUNSET, 'blank is cpUNSET');
      CheckTrue(s.TrySetByCommand('CATEGORY-BAND', '   '), 'BAND spaces');
      CheckTrue(s.Contest.CategoryBand = cbUNSET, 'spaces are blank too');
      CheckFalse(s.TrySetByCommand('CATEGORY-MODE', 'TELEPATHY'),
                 'a word that is no mode is still refused');
   finally
      s.Free;
   end;

   (* THE HEADER LINE, exactly as written to the file. *)
   for i := Low(CATEGORY_TAGS) to High(CATEGORY_TAGS) do
      begin
      CheckTrue(CabrilloTagIsCategory(CATEGORY_TAGS[i]),
                CATEGORY_NAMES[i] + ' is a category');
      CheckEquals(CATEGORY_NAMES[i] + ':' + #13#10,
                  CabrilloHeaderTagLine(CATEGORY_TAGS[i], ''),
                  CATEGORY_NAMES[i] + ' blank: the bare tag, no trailing space');
      end;
   CheckEquals('CATEGORY-OVERLAY: CLASSIC' + #13#10,
               CabrilloHeaderTagLine(ctCategoryOverlay, 'CLASSIC'),
               'a value is written as it always was');
   CheckEquals('CATEGORY-POWER: HIGH' + #13#10,
               CabrilloHeaderTagLine(ctCategoryPower, 'HIGH'),
               'POWER with a value');
   CheckFalse(CabrilloTagIsCategory(ctClub), 'CLUB is not a category');
   CheckEquals('', CabrilloHeaderTagLine(ctClub, ''),
               'any other blank tag writes nothing, as before');
   CheckEquals('LOCATION: FL' + #13#10, CabrilloHeaderTagLine(ctLocation, 'FL'),
               'any other tag with a value');

   (* THE LISTS: the old values first, in their old places, then one ''. *)
   for i := Low(CATEGORY_TAGS) to High(CATEGORY_TAGS) do
      begin
      values := CategoryValuesFor(CATEGORY_TAGS[i]);
      CheckTrue(Length(values) >= 2, CATEGORY_NAMES[i] + ' offers a list');
      if Length(values) < 2 then
         begin
         Continue;
         end;
      CheckEquals(FIRST_VALUES[i], values[0],
                  CATEGORY_NAMES[i] + ': the first value is where it was');
      CheckEquals('', values[High(values)], CATEGORY_NAMES[i] + ' ends in the blank');
      blanks := 0;
      for j := 0 to High(values) do
         begin
         if values[j] = '' then
            begin
            Inc(blanks);
            end;
         end;
      CheckEquals(1, blanks, CATEGORY_NAMES[i] + ' has exactly one blank');
      end;
   CheckEquals(Ord(High(tCategoryPower)) + 1, Length(CategoryValuesFor(ctCategoryPower)),
               'POWER: one item per member, so a row''s index is the ordinal');
   CheckEquals(NumberOverlayCategories + 1, Length(CategoryValuesFor(ctCategoryOverlay)),
               'OVERLAY: PostUnit''s list plus the blank');

   (* A CLOSED WINDOW ANSWERS THE SETTING, blank included. *)
   CheckFalse(CabrilloSummaryIsOpen, 'the summary window is not open');
   savedPower := Settings.Contest.CategoryPower;
   savedBand := Settings.Contest.CategoryBand;
   try
      Settings.Contest.CategoryPower := cpUNSET;
      Settings.Contest.CategoryBand := cbUNSET;
      CheckEquals('', CabrilloTagText(ctCategoryPower), 'blank POWER answers ''''');
      CheckEquals('', CabrilloTagText(ctCategoryBand), 'blank BAND answers ''''');
      CheckEquals('CATEGORY-POWER:' + #13#10,
                  CabrilloHeaderTagLine(ctCategoryPower, CabrilloTagText(ctCategoryPower)),
                  'and the export writes the bare tag for it');
   finally
      Settings.Contest.CategoryPower := savedPower;
      Settings.Contest.CategoryBand := savedBand;
   end;
end;

(* ------------------------------------------------------------------------ *)
(* THE MINIMUM OFF TIME -- Q60, NY4I 2026-10-15                              *)
(* ------------------------------------------------------------------------ *)

(* 60 MINUTES FOR EXACTLY THE CQ WW FAMILY -- CW, SSB and RTTY, the three
  tokens `Pos('CQ-WW', ...)` matched -- and the base 30 for every other
  contest, IARU HF and WRTC included. A RATCHET: a contest that states another
  break fails here and joins the list on a rule's evidence. *)
procedure TContestUITests.Test_OnlyCQWWHasASixtyMinuteBreak;
var
   q108Contests: TContestIdentityList;
   k: integer;
   obj: TContestBase;
   expected: integer;
begin
   BeginTest('Test_OnlyCQWWHasASixtyMinuteBreak');
   (* EVERY REGISTERED CONTEST, BY THE REGISTRY -- an invariant, so a
      contest registered by its id is held to it too (Q108 S1). *)
   q108Contests := ContestsToWalk;
   for k := 0 to High(q108Contests) do
      begin
      obj := NewContestLike(q108Contests[k], NoStation);
      try
         expected := 30;
         if IsLegacyContest(obj, CQWWCW)  or
            IsLegacyContest(obj, CQWWSSB) or
            IsLegacyContest(obj, CQWWRTTY) then
            begin
            expected := 60;
            end;
         CheckEquals(expected, obj.MinimumOffTimeMinutes,
                     ContestWho(obj) + ': the minimum off time');
         (* THE IDENTITY BY ITS HANDLE: by the legacy member, a contest
           registered by its id asked "no contest" (issue #96). *)
         CheckEquals(obj.MinimumOffTimeMinutes,
                     ContestIdentity(HandleOf(obj)).MinimumOffTimeMinutes,
                     ContestWho(obj) + ': the identity gives the same break');
      finally
         obj.Free;
      end;
      end;
   CheckEquals(30, ContestIdentity(IARU).MinimumOffTimeMinutes,
               'IARU HF takes the default 30 (DXLog IARUHF.txt states none)');
end;

(* POSTUNIT.CALCULATETOTALS' RULE, AT ITS EDGE: a gap of exactly the break is
  operating time (`<=`, as it always was), one second more is off time. *)
procedure TContestUITests.Test_AGapCountsUpToTheBreak;
begin
   BeginTest('Test_AGapCountsUpToTheBreak');
   CheckTrue(GapIsOperatingTime(0, 30), 'no gap counts');
   CheckTrue(GapIsOperatingTime(30 * 60, 30), '30:00 counts at a 30-minute break');
   CheckFalse(GapIsOperatingTime(30 * 60 + 1, 30), '30:01 is off time at a 30-minute break');
   CheckTrue(GapIsOperatingTime(45 * 60, 60), '45:00 counts at a 60-minute break');
   CheckTrue(GapIsOperatingTime(60 * 60, 60), '60:00 counts at a 60-minute break');
   CheckFalse(GapIsOperatingTime(60 * 60 + 1, 60), '60:01 is off time at a 60-minute break');

   (* THE TWO ANSWERS, through the contest -- a 45-minute gap is operating
      time in CQ WW and off time in IARU HF. *)
   CheckTrue(GapIsOperatingTime(45 * 60, ContestIdentity(CQWWCW).MinimumOffTimeMinutes),
             'CQ WW CW: a 45-minute gap is operating time');
   CheckFalse(GapIsOperatingTime(45 * 60, ContestIdentity(IARU).MinimumOffTimeMinutes),
              'IARU HF: a 45-minute gap is off time');
end;

procedure TContestUITests.RunAllTests;
begin
   Test_ChoicesListEveryContestOnce;
   Test_ChoicesActiveFirstThenByDisplayName;
   Test_ChoicesShowDisplayNamesAndMarkInactive;
   Test_ChoiceCaptionsAreUnique;
   Test_OnlyNamedContestsAreInactive;
   Test_GeneralQSOIsALog;
   Test_FOCMarathonPowerColumn;
   Test_WAGFrequencyWarning;
   Test_CategoryPowerChange;
   Test_Q61_CategoriesAreOneValueEach;
   Test_EveryCategoryMayBeBlank;
   Test_OnlyCQWWHasASixtyMinuteBreak;
   Test_AGapCountsUpToTheBreak;
end;

end.

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
      rescores, and that re-saving the same value does neither. *)
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
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uContestChoices,
   uCategoryPowerChange,
   uSettingsModel,
   uAppStrings,
   uTR4WStrings,
   uTestContestObjects;

const
   (* NY4I, 2026-10-01/02: inactive, kept for old logs. Add one only on his
      word, and in the same commit as its class's GetIsActive. *)
   INACTIVE_CONTESTS: array[0..1] of ContestType = (SASPRINT, LQP);

function IsListedInactive(aContest: ContestType): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(INACTIVE_CONTESTS) to High(INACTIVE_CONTESTS) do
      begin
      if INACTIVE_CONTESTS[i] = aContest then
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
   c: ContestType;
   i, seen: integer;
begin
   BeginTest('Test_ChoicesListEveryContestOnce');
   choices := TContestChoices.Create;
   try
      (* THE RANGE THE DIALOG ALWAYS OFFERED: every contest after
         DUMMYCONTEST, which is never offered. *)
      CheckEquals(Ord(High(ContestType)) - Ord(DUMMYCONTEST), choices.Count,
                  'one line per contest after DUMMYCONTEST');
      CheckEquals(-1, choices.IndexOf(DUMMYCONTEST), 'DUMMYCONTEST is not offered');

      for c := Succ(DUMMYCONTEST) to High(ContestType) do
         begin
         seen := 0;
         for i := 0 to choices.Count - 1 do
            begin
            if choices.Contest[i] = c then
               begin
               inc(seen);
               end;
            end;
         CheckEquals(1, seen, string(ContestTypeSA[c]) + ' is offered exactly once');
         CheckTrue(choices.IndexOf(c) >= 0, string(ContestTypeSA[c]) + ': IndexOf finds it');
         if choices.IndexOf(c) >= 0 then
            begin
            CheckTrue(choices.Contest[choices.IndexOf(c)] = c,
                      string(ContestTypeSA[c]) + ': IndexOf answers its own line');
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
            CheckTrue(Ord(choices.Contest[i - 1]) < Ord(choices.Contest[i]),
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
         who := string(ContestTypeSA[choices.Contest[i]]);

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
      CheckEquals('SA-SPRINT (inactive)', ContestChoiceCaption(SASPRINT),
                  'SA Sprint is marked');

      (* THE ONE SHARED NAME TODAY, told apart -- a RATCHET: a new pair fails
         here and is a display name to ask NY4I for (design Q58). *)
      CheckEquals(2, shared, 'exactly two lines share a display name');
      CheckEquals('IARU HF World Championship [IARU-HF]', ContestChoiceCaption(IARU),
                  'IARU-HF is told apart from WRTC');
      CheckEquals('IARU HF World Championship [WRTC]', ContestChoiceCaption(WRTC),
                  'WRTC is told apart from IARU-HF');
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
                       string(ContestTypeSA[choices.Contest[i]]) + ' and ' +
                       string(ContestTypeSA[choices.Contest[j]]) +
                       ' share the line "' + choices.Caption[i] + '"');
            end;
         end;
   finally
      choices.Free;
   end;
end;

procedure TContestUITests.Test_OnlyNamedContestsAreInactive;
var
   c: ContestType;
   obj: TContestBase;
begin
   BeginTest('Test_OnlyNamedContestsAreInactive');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         CheckEquals(Ord(not IsListedInactive(c)), Ord(obj.IsActive),
                     string(ContestTypeSA[c]) + ': IsActive');
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
   c: ContestType;
   obj: TContestBase;
   who: string;
   isLog: boolean;
begin
   BeginTest('Test_GeneralQSOIsALog');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         who := string(ContestTypeSA[c]);
         isLog := c = GENERALQSO;
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
   c: ContestType;
   obj: TContestBase;
begin
   BeginTest('Test_FOCMarathonPowerColumn');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         CheckEquals(Ord(c = FOCMARATHON), Ord(obj.PowerFieldIsFOCNumber),
                     string(ContestTypeSA[c]) + ': the power field is an FOC number');
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
   c: ContestType;
   obj: TContestBase;
   i: integer;
   expected: string;
begin
   BeginTest('Test_WAGFrequencyWarning');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         for i := Low(EDGES) to High(EDGES) do
            begin
            expected := '';
            if (c = WAG) and EDGES[i].warns then
               begin
               expected := TC_WAGWarn;
               end;
            CheckEquals(expected, obj.CallEntryFrequencyWarning(EDGES[i].kHz),
                        string(ContestTypeSA[c]) + ' at ' + IntToStr(EDGES[i].kHz) + ' kHz');
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
   change := DecideCategoryPowerChange(cpLOW, '', 5, got);
   CheckTrue((change = cpcUnchanged) and (got = cpLOW), 'an empty row changes nothing');
   change := DecideCategoryPowerChange(cpLOW, 'KILOWATT', 5, got);
   CheckTrue((change = cpcUnchanged) and (got = cpLOW), 'a value that is no power changes nothing');
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
end;

end.

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

(* THE MULTIPLIER MODE -- issue 122 (2026-11-18), pinned in its own right, as
  the digital share of the points (issue 129) was.

  The seam: TContestBase.MultiplierModeOf(aMode) says which mode a QSO in
  aMode counts its multipliers in (base: aMode itself). The nil-safe
  ContestMultiplierModeOf keeps Both and NoMode as they are.
  LOGDUPE.MultiplierSlotMode asks it of the session's contest's identity, and
  is the slot every write to the multiplier sheet uses (AddQSOToSheets, the
  worked counts, the #317 replay); LOGDUPE.MultiplierSheetMode -- the read
  key SetMultFlags, the #317 test, the spot hint and the remaining-multipliers
  display (LOGWIND's MultMode) use -- reads through it. So the sheet is
  written and read in one slot.

  What is held here:
    * NO OTHER CONTEST MOVES: every registered contest answers every mode
      as itself, except the closed list of contests whose sponsor groups
      modes for multipliers;
    * Both and NoMode are keys; nil answers the mode;
    * the slot and the read key follow the session's contest, and the read
      key is Both where the session does not count multipliers by mode;
    * on the sheet itself, a grouping contest writes and reads one slot (a
      parish on CW, then on RTTY, is not new; on phone it is), and the same
      sequence under another contest keeps the three modes apart. *)
unit uTestMultiplierMode;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TMultiplierModeTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_OnlyTheClosedListGroupsModes;
      procedure Test_BothAndNoModeAreKeys;
      procedure Test_SlotAndKeyFollowTheSessionContest;
      procedure Test_TheSheetWritesAndReadsOneSlot;
   end;

implementation

uses
   SysUtils, Classes, VC, uSettingsModel, uContestBase, uContestRegistry,
   uContestLouisianaQP, uContestIllinoisQP, uMults, LogDupe,
   (* Contest, the session's contest. *)
   PostUnit,
   uTestRegisteredContests;

const
   (* THE CONTESTS WHOSE MultiplierModeOf IS NOT THE MODE ITSELF -- a CLOSED
      list, by id and sorted: a contest joins it in the commit that gives it
      the rule, with its sponsor's words in its class header.
      LA-QSO-PARTY (issue 122, rule 9.1): "CW/Digital and Phone contacts
      count as separate multipliers" -- Digital is CW. *)
   GROUPS_MULTIPLIER_MODES = 'LA-QSO-PARTY';

   (* The modes a QSO is logged in (Both and NoMode are keys, not modes). *)
   LOGGED_MODES: array[0..3] of ModeType = (CW, Digital, Phone, FM);

function HandleById(const aId: string): TContestHandle;
begin
   if not FindContestById(aId, Result) then
      begin
      raise Exception.Create(aId + ' is not registered');
      end;
end;

procedure TMultiplierModeTests.Test_OnlyTheClosedListGroupsModes;
var
   contests: TContestIdentityList;
   k, m: integer;
   groupers: TStringList;
   joined: string;
   moved: boolean;
begin
   BeginTest('Test_OnlyTheClosedListGroupsModes');
   groupers := TStringList.Create;
   try
      contests := ContestsToWalk;
      for k := 0 to High(contests) do
         begin
         moved := False;
         for m := Low(LOGGED_MODES) to High(LOGGED_MODES) do
            begin
            if ContestMultiplierModeOf(contests[k], LOGGED_MODES[m]) <> LOGGED_MODES[m] then
               begin
               moved := True;
               end;
            end;
         if moved then
            begin
            groupers.Add(AnsiString(ContestId(HandleOf(contests[k]))));
            end;
         end;
      groupers.Sort;
      joined := '';
      for k := 0 to groupers.Count - 1 do
         begin
         if k > 0 then
            begin
            joined := joined + '|';
            end;
         joined := joined + string(groupers[k]);
         end;
      CheckEquals(GROUPS_MULTIPLIER_MODES, joined,
                  'the contests whose multiplier mode is not the mode itself');
   finally
      groupers.Free;
   end;

   (* THE LIST'S RULE, exactly: Louisiana files Digital under CW and leaves
      CW, phone and FM as they are. *)
   CheckTrue(ContestMultiplierModeOf(ContestIdentity(HandleById(LA_QSO_PARTY_CONTEST_ID)), Digital) = CW,
             'Louisiana: digital is CW');
   CheckTrue(ContestMultiplierModeOf(ContestIdentity(HandleById(LA_QSO_PARTY_CONTEST_ID)), CW) = CW,
             'Louisiana: CW is CW');
   CheckTrue(ContestMultiplierModeOf(ContestIdentity(HandleById(LA_QSO_PARTY_CONTEST_ID)), Phone) = Phone,
             'Louisiana: phone is its own');
   CheckTrue(ContestMultiplierModeOf(ContestIdentity(HandleById(LA_QSO_PARTY_CONTEST_ID)), FM) = FM,
             'Louisiana: FM is left to the sheet''s own FM rule (Phone''s slot)');

   (* NOT INHERITED FROM THE DUPE RULE: Illinois groups digital with CW for
      dupes only -- its multipliers are once overall. *)
   CheckTrue(ContestDupeModeOf(ContestIdentity(HandleById(IL_QSO_PARTY_CONTEST_ID)), Digital) = CW,
             'Illinois: digital is CW for dupes');
   CheckTrue(ContestMultiplierModeOf(ContestIdentity(HandleById(IL_QSO_PARTY_CONTEST_ID)), Digital) = Digital,
             'but not for multipliers');
end;

procedure TMultiplierModeTests.Test_BothAndNoModeAreKeys;
var
   la: TContestBase;
   m: integer;
begin
   BeginTest('Test_BothAndNoModeAreKeys');
   la := ContestIdentity(HandleById(LA_QSO_PARTY_CONTEST_ID));
   CheckTrue(ContestMultiplierModeOf(la, Both) = Both, 'Both is a key');
   CheckTrue(ContestMultiplierModeOf(la, NoMode) = NoMode, 'NoMode is a key');
   for m := Low(LOGGED_MODES) to High(LOGGED_MODES) do
      begin
      CheckTrue(ContestMultiplierModeOf(nil, LOGGED_MODES[m]) = LOGGED_MODES[m],
                'no contest answers the mode');
      end;
end;

procedure TMultiplierModeTests.Test_SlotAndKeyFollowTheSessionContest;
var
   savedContest: TContestHandle;
   savedByMode: boolean;
begin
   BeginTest('Test_SlotAndKeyFollowTheSessionContest');
   savedContest := Contest;
   savedByMode := Settings.Mult.ByMode;
   try
      Contest := HandleById(LA_QSO_PARTY_CONTEST_ID);
      CheckTrue(MultiplierSlotMode(Digital) = CW, 'Louisiana writes digital in CW''s slot');
      CheckTrue(MultiplierSlotMode(Phone) = Phone, 'and phone in its own');
      Settings.Mult.ByMode := True;
      CheckTrue(MultiplierSheetMode(Digital) = CW, 'and reads it there, by mode');
      Settings.Mult.ByMode := False;
      CheckTrue(MultiplierSheetMode(Digital) = Both, 'Both where multipliers are not by mode');

      Contest := HandleById(IL_QSO_PARTY_CONTEST_ID);
      CheckTrue(MultiplierSlotMode(Digital) = Digital, 'another contest: digital is its own slot');
      Settings.Mult.ByMode := True;
      CheckTrue(MultiplierSheetMode(Digital) = Digital, 'and its own read key');
   finally
      Settings.Mult.ByMode := savedByMode;
      Contest := savedContest;
   end;
end;

(* THE SHEET ITSELF: the writes AddQSOToSheets makes and the reads
   SetMultFlags makes, through the two LOGDUPE functions. *)
procedure TMultiplierModeTests.Test_TheSheetWritesAndReadsOneSlot;
var
   savedContest: TContestHandle;
   savedByMode, savedByBand: boolean;
   savedSheet: TMultsObject;

   (* Mark aKey worked on aBand in aMode, as AddQSOToSheets does. *)
   procedure Work(const aKey: string; aBand: BandType; aMode: ModeType);
   begin
      mo.SetDmMult(aKey, aBand, MultiplierSlotMode(aMode));
      mo.CountWorked(rmDomestic, aKey, aBand, MultiplierSlotMode(aMode));
   end;

   (* Is aKey new on aBand in aMode, as SetMultFlags asks? *)
   function IsNew(const aKey: string; aBand: BandType; aMode: ModeType): boolean;
   begin
      Result := mo.IsDmMult(aKey, aBand, MultiplierSheetMode(aMode), False);
   end;

begin
   BeginTest('Test_TheSheetWritesAndReadsOneSlot');
   savedContest := Contest;
   savedByMode := Settings.Mult.ByMode;
   savedByBand := Settings.Mult.ByBand;
   savedSheet := mo;
   mo := TMultsObject.Create;
   try
      Settings.Mult.ByMode := True;
      Settings.Mult.ByBand := True;

      (* LOUISIANA: rule 9.1. *)
      Contest := HandleById(LA_QSO_PARTY_CONTEST_ID);
      CheckTrue(IsNew('ACAD', Band20, CW), 'Acadia is new on 20 m CW');
      Work('ACAD', Band20, CW);
      CheckFalse(IsNew('ACAD', Band20, Digital), 'and NOT new on 20 m RTTY: CW and digital are one');
      CheckTrue(IsNew('ACAD', Band20, Phone), 'new on 20 m phone');
      CheckTrue(IsNew('ACAD', Band40, Digital), 'new on 40 m digital');
      Work('ACAD', Band40, Digital);
      CheckFalse(IsNew('ACAD', Band40, CW), 'and then not new on 40 m CW');
      CheckEquals(1, integer(mo.MTotals[Band20, CW, rmDomestic]), 'counted once in 20 m CW/digital');
      CheckEquals(0, integer(mo.MTotals[Band20, Digital, rmDomestic]), 'never in a digital slot');
      CheckEquals(2, integer(mo.MTotals[AllBands, Both, rmDomestic]), 'two in the score''s cell');
      CheckEquals(1, mo.WorkedCount(rmDomestic, 'ACAD', Band20, MultiplierSheetMode(Digital)),
                  'the worked count reads the same slot');

      (* THE SAME SEQUENCE UNDER ANOTHER CONTEST: three modes apart. *)
      mo.ClearAllMults;
      Contest := HandleById(IL_QSO_PARTY_CONTEST_ID);
      Work('ACAD', Band20, CW);
      CheckTrue(IsNew('ACAD', Band20, Digital), 'another contest: RTTY after CW is new');
      Work('ACAD', Band20, Digital);
      CheckEquals(1, integer(mo.MTotals[Band20, CW, rmDomestic]), 'CW''s slot');
      CheckEquals(1, integer(mo.MTotals[Band20, Digital, rmDomestic]), 'digital''s slot');
      CheckEquals(2, integer(mo.MTotals[AllBands, Both, rmDomestic]), 'two in the score''s cell');
   finally
      mo.Free;
      mo := savedSheet;
      Settings.Mult.ByBand := savedByBand;
      Settings.Mult.ByMode := savedByMode;
      Contest := savedContest;
   end;
end;

procedure TMultiplierModeTests.RunAllTests;
begin
   Test_OnlyTheClosedListGroupsModes;
   Test_BothAndNoModeAreKeys;
   Test_SlotAndKeyFollowTheSessionContest;
   Test_TheSheetWritesAndReadsOneSlot;
end;

end.

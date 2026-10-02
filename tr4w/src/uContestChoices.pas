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

(* THE CONTESTS THE NEW CONTEST DIALOG OFFERS, IN THE ORDER IT OFFERS THEM --
  milestone M9b, 2026-10-02 (docs/CONTEST_OWNERSHIP_DESIGN.md section 8.2n).

  NY4I: "i would like the display name in the drop down", and "inactive
  contests go at the bottom of the drop down". So each entry is a contest and
  the words that name it, and both come from the contest: its DisplayName and
  its IsActive (TContestBase). This unit decides only the ORDER and the
  marking, which are the dialog's.

  THE IDENTITY IS A ContestType, HELD BESIDE THE CAPTION -- never recovered
  from the caption, and never carried in a combo's Objects[]. The token that
  is persisted (the CONTEST command, the log's file name) is still
  ContestTypeSA of that contest, so choosing by display name changes nothing
  that is written. Two contests with one display name would be one line an
  operator could not tell apart; uTestContestChoices fails if that happens.

  THE ORDER (DECIDED): every active contest, then every inactive one; within
  each, by display name, case-insensitively in the platform's collation
  (UnicodeCompareText -- what a sorted LCL list would use too); a tie by the
  enum's order, so the list is the same on every run. The Win32 combo sorted by the enum's spelling
  (CBS_SORT), which put 'ARRL-10' beside 'ARRL-160' and every QSO party under
  its state's code; sorting by what the operator reads is the only order that
  helps them find it.

  A SHARED DISPLAY NAME IS TOLD APART BY THE TOKEN (DECIDED). Two contests
  can carry one display name -- WRTC's row gives it the friendly name 'IARU
  HF World Championship', the event it runs inside, so it and IARU-HF were
  two identical lines. Each such line adds its token in brackets ('IARU HF
  World Championship [WRTC]'); a unique name is shown bare. Brackets, not
  words, so nothing needs translating. The better answer is a name of WRTC's
  own, which is NY4I's (design Q58) and would change its FriendlyName -- the
  summary sheet's CONTEST: line -- so it is not taken here.

  THE MARK (DECIDED): an inactive contest's caption is SContestInactive --
  '%s (inactive)' -- a resourcestring, so a translation reaches it. The
  display names themselves are NOT translated: they are the sponsors' proper
  names, and the same names feed the summary sheet's CONTEST: line and the
  log database's friendly name, where a translation would change the output.

  NO FORM, NO LCL, so the unit tests build the same list the dialog shows. *)
unit uContestChoices;

{$I tr4w.inc}

interface

uses
   VC;

type
   TContestChoices = class
   private
      FContests: array of ContestType;
      FCaptions: array of string;
      function GetCount: integer;
      function GetContest(aIndex: integer): ContestType;
      function GetCaption(aIndex: integer): string;
   public
      (* Builds the whole list, in order, from the contest registry. *)
      constructor Create;

      (* Where a contest sits in the list, or -1. *)
      function IndexOf(aContest: ContestType): integer;

      property Count: integer read GetCount;
      property Contest[aIndex: integer]: ContestType read GetContest;
      property Caption[aIndex: integer]: string read GetCaption;
   end;

(* ONE CONTEST'S LINE: its display name -- with its token in brackets when
  another contest shares that name -- marked when it is inactive. *)
function ContestChoiceCaption(aContest: ContestType): string;

implementation

uses
   SysUtils,
   uContestBase,
   uContestRegistry,   (* ContestIdentity -- the display name and the flag *)
   uAppStrings;        (* SContestInactive *)

(* DOES ANOTHER OFFERED CONTEST CARRY THIS DISPLAY NAME? *)
function DisplayNameIsShared(aContest: ContestType): boolean;
var
   c: ContestType;
   name: string;
begin
   Result := False;
   name := ContestIdentity(aContest).DisplayName;
   for c := Succ(DUMMYCONTEST) to High(ContestType) do
      begin
      (* UnicodeSameText, NOT SameText: SysUtils' plain name takes AnsiString
         and this unit's string is UnicodeString. *)
      if (c <> aContest) and
         UnicodeSameText(ContestIdentity(c).DisplayName, name) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function ContestChoiceCaption(aContest: ContestType): string;
var
   identity: TContestBase;
   name: string;
begin
   identity := ContestIdentity(aContest);
   name := identity.DisplayName;
   if DisplayNameIsShared(aContest) then
      begin
      name := name + ' [' + string(ContestTypeSA[aContest]) + ']';
      end;

   if identity.IsActive then
      begin
      Result := name;
      end
   else
      begin
      Result := Format(SContestInactive, [name]);
      end;
end;

(* DOES a COME BEFORE b? Active first, then the display name, then the enum. *)
function ComesBefore(a, b: ContestType): boolean;
var
   ia, ib: TContestBase;
   byName: integer;
begin
   ia := ContestIdentity(a);
   ib := ContestIdentity(b);
   if ia.IsActive <> ib.IsActive then
      begin
      Result := ia.IsActive;
      Exit;
      end;

   (* UnicodeCompareText -- see DisplayNameIsShared on the plain name. *)
   byName := UnicodeCompareText(ia.DisplayName, ib.DisplayName);
   if byName <> 0 then
      begin
      Result := byName < 0;
      Exit;
      end;

   Result := Ord(a) < Ord(b);
end;

constructor TContestChoices.Create;
var
   c, held: ContestType;
   n, i, j: integer;
begin
   inherited Create;

   (* THE RANGE THE WIN32 DIALOG OFFERED: every contest after DUMMYCONTEST. *)
   n := Ord(High(ContestType)) - Ord(DUMMYCONTEST);
   SetLength(FContests, n);
   i := 0;
   for c := Succ(DUMMYCONTEST) to High(ContestType) do
      begin
      FContests[i] := c;
      inc(i);
      end;

   (* AN INSERTION SORT: under two hundred entries, built once per dialog,
      and stable, which the enum tie-break does not need but costs nothing. *)
   for i := 1 to n - 1 do
      begin
      held := FContests[i];
      j := i - 1;
      while (j >= 0) and ComesBefore(held, FContests[j]) do
         begin
         FContests[j + 1] := FContests[j];
         dec(j);
         end;
      FContests[j + 1] := held;
      end;

   SetLength(FCaptions, n);
   for i := 0 to n - 1 do
      begin
      FCaptions[i] := ContestChoiceCaption(FContests[i]);
      end;
end;

function TContestChoices.GetCount: integer;
begin
   Result := Length(FContests);
end;

function TContestChoices.GetContest(aIndex: integer): ContestType;
begin
   Result := FContests[aIndex];
end;

function TContestChoices.GetCaption(aIndex: integer): string;
begin
   Result := FCaptions[aIndex];
end;

function TContestChoices.IndexOf(aContest: ContestType): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to High(FContests) do
      begin
      if FContests[i] = aContest then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

end.

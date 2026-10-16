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

(* A CONTEST NAME, READ BACK INTO A ContestType -- the ONE place that does it
  (2026-10-16, design Q105).

  WHAT A "CONTEST NAME" IS HERE. The ContestTypeSA spelling (VC.pas): what a
  .cfg's CONTEST = line says, what the SQLite log stores in its contest table
  (uLogRepository.SetContest writes it, LoadContest reads it back through
  TF.GetContestFromString), and what the CONTEST setting holds. It is NOT the
  Cabrillo CONTEST: name nor the ADIF CONTEST_ID -- those are the class's
  (CabrilloName, ADIFContestId) and ADIF import resolves them through
  uContestRegistry.FindContestByADIFContestId.

  TWO READERS, ONE RULE. TF.GetContestFromString (the log's contest row) and
  the CONTEST setting (uCFG registers CurrentContestSpelling for it, so a
  config line, a stored config row or a peer is read the same way) both come
  here. Before this unit they were two loops with two rules -- one exact, one
  case-insensitive -- and a renamed contest would have had to be taught to
  both.

  ---------------------------------------------------------------------------
  THE LEGACY NAMES -- READ-ONLY, AND PERMANENT

  A CONTEST NAME THAT WAS EVER WRITTEN TO A FILE IS NEVER REUSED FOR A
  DIFFERENT CONTEST. It is stored data: every D7 .cfg, every imported binary
  log's .cfg and every SQLite contest log written under the old spelling still
  says it, and giving it to another contest would reopen all of them as that
  contest, silently. So when a contest's spelling changes, its OLD spelling
  goes into LEGACY_CONTEST_NAMES below and stays there for good: it is READ
  (resolved to its contest), and nothing ever WRITES it again -- writers use
  ContestTypeSA, which holds only the current spelling.

  An alias may never equal a current ContestTypeSA spelling (a live name would
  then resolve two ways); uTestContestNames pins that for every entry.

    NEQP   New England QSO Party, renamed NEWEQP on 2026-10-16 (NY4I, Q105):
           DXLog's name, and NE-QSO-PARTY -- the ADIF and Cabrillo name of the
           NEBRASKA QSO Party -- is too close to 'NEQP' to leave the New
           England party holding it. Its ADIF CONTEST_ID stays NEQP (the ADIF
           3.1.7 enumeration's New England value); that is the class's
           ADIFContestId and has nothing to do with this table.

  A RECORD, NOT A CLASS, and that is the CLAUDE.md exemption rather than a
  habit: a compile-time table can only be a typed constant, and a typed
  constant of a class does not exist. Nothing outside this unit holds one. *)
unit uContestNames;

{$I tr4w.inc}

interface

uses
   VC;

type
   TLegacyContestName = record
      Name: string;
      Contest: ContestType;
   end;

const
   LEGACY_CONTEST_NAMES: array[0..0] of TLegacyContestName = (
      (Name: 'NEQP'; Contest: NEWENGLANDQSO)
   );

(* THE CONTEST A NAME MEANS. A current ContestTypeSA spelling first, then a
  legacy name. Case and surrounding blanks are ignored -- the config file's
  matcher always ignored them, and no two spellings differ only by case
  (pinned). False, with aContest DUMMYCONTEST, for a name that is neither. *)
function TryContestFromName(const aName: string; out aContest: ContestType): boolean;

(* The same, DUMMYCONTEST for a name that means no contest -- what
  TF.GetContestFromString has always answered. *)
function ContestFromName(const aName: string): ContestType;

(* THE SPELLING A NAME IS STORED UNDER FROM NOW ON. A legacy name becomes its
  contest's current ContestTypeSA spelling; anything else -- a current
  spelling, as typed, or text that is no contest at all -- comes back
  unchanged, so the CONTEST setting's own refusal still sees what was
  written. *)
function CurrentContestSpelling(const aName: string): string;

implementation

uses
   SysUtils;

(* A CURRENT SPELLING -- the one loop over ContestTypeSA. *)
function FindLiveName(const aName: string; out aContest: ContestType): boolean;
var
   c: ContestType;
begin
   aContest := DUMMYCONTEST;
   Result := False;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if UnicodeSameText(ContestTypeSA[c], aName) then
         begin
         aContest := c;
         Result := True;
         Exit;
         end;
      end;
end;

(* A LEGACY NAME -- the one loop over LEGACY_CONTEST_NAMES. *)
function FindLegacyName(const aName: string; out aContest: ContestType): boolean;
var
   i: integer;
begin
   aContest := DUMMYCONTEST;
   Result := False;
   for i := Low(LEGACY_CONTEST_NAMES) to High(LEGACY_CONTEST_NAMES) do
      begin
      if UnicodeSameText(LEGACY_CONTEST_NAMES[i].Name, aName) then
         begin
         aContest := LEGACY_CONTEST_NAMES[i].Contest;
         Result := True;
         Exit;
         end;
      end;
end;

function TryContestFromName(const aName: string; out aContest: ContestType): boolean;
var
   name: string;
begin
   aContest := DUMMYCONTEST;
   Result := False;
   name := Trim(aName);
   if name = '' then
      begin
      Exit;
      end;

   Result := FindLiveName(name, aContest);
   if not Result then
      begin
      Result := FindLegacyName(name, aContest);
      end;
end;

function ContestFromName(const aName: string): ContestType;
begin
   TryContestFromName(aName, Result);
end;

function CurrentContestSpelling(const aName: string): string;
var
   c: ContestType;
   name: string;
begin
   Result := aName;
   name := Trim(aName);
   if FindLiveName(name, c) then
      begin
      Exit;
      end;
   if FindLegacyName(name, c) then
      begin
      Result := ContestTypeSA[c];
      end;
end;

end.

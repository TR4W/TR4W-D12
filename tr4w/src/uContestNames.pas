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

(* A CONTEST NAME, READ BACK INTO A CONTEST -- the ONE place that does it
  (2026-10-16, design Q105).

  WHAT A "CONTEST NAME" IS HERE. The contest's ID (uContestRegistry.ContestId;
  for a legacy contest, its ContestTypeSA spelling in VC.pas): what a .cfg's
  CONTEST = line says, what the SQLite log stores in its contest table
  (uLogRepository.SetContest writes it, LoadContest reads it back through
  ContestFromName), and what the CONTEST setting holds. It is NOT the
  Cabrillo CONTEST: name nor the ADIF CONTEST_ID -- those are the class's
  (CabrilloName, ADIFContestId) and ADIF import resolves them through
  uContestRegistry.FindContestByADIFContestId.

  THE REGISTRY HOLDS THE IDS (Q108 S2, 2026-10-16). This unit asks
  uContestRegistry.FindContestById for a current name, so a contest that
  registers by id alone (S3) is found the same way, and walks no table of
  its own. The answer is a registry handle (VC.TContestHandle).

  TWO READERS, ONE RULE. The log's contest row and the CONTEST setting (uCFG
  registers CurrentContestSpelling for it, so a config line, a stored config
  row or a peer is read the same way) both come here. Before this unit they
  were two loops with two rules -- one exact, one case-insensitive -- and a
  renamed contest would have had to be taught to both.

  ---------------------------------------------------------------------------
  THE LEGACY NAMES -- READ-ONLY, AND PERMANENT

  A CONTEST NAME THAT WAS EVER WRITTEN TO A FILE IS NEVER REUSED FOR A
  DIFFERENT CONTEST. It is stored data: every D7 .cfg, every imported binary
  log's .cfg and every SQLite contest log written under the old spelling still
  says it, and giving it to another contest would reopen all of them as that
  contest, silently. So when a contest's spelling changes, its OLD spelling
  goes into LEGACY_CONTEST_NAMES below and stays there for good: it is READ
  (resolved to its contest), and nothing ever WRITES it again -- writers use
  the contest's id, which is only ever the current spelling.

  AN ALIAS NAMES THE CONTEST BY ITS CURRENT ID, NOT BY A ContestType MEMBER
  (Q108 S2), so a contest that registers by id alone can be renamed under
  the same rule. An alias may never equal a current id (a live name would
  then resolve two ways), and its id must resolve; uTestContestNames pins
  both for every entry.

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
      (* The CURRENT id of the contest the old name means. *)
      Id: string;
   end;

const
   LEGACY_CONTEST_NAMES: array[0..0] of TLegacyContestName = (
      (Name: 'NEQP'; Id: 'NEWEQP')
   );

(* THE CONTEST A NAME MEANS. A current id first, then a legacy name. Case and
  surrounding blanks are ignored -- the config file's matcher always ignored
  them, and no two spellings differ only by case (pinned). False, with
  aContest NoContest, for a name that is neither. *)
function TryContestFromName(const aName: string;
                            out aContest: TContestHandle): boolean;

(* The same, NoContest for a name that means no contest -- what the log's
  contest row has always been read as. *)
function ContestFromName(const aName: string): TContestHandle;

(* THE SPELLING A NAME IS STORED UNDER FROM NOW ON. A legacy name becomes its
  contest's current id; anything else -- a current spelling, as typed, or
  text that is no contest at all -- comes back unchanged, so the CONTEST
  setting's own refusal still sees what was written. *)
function CurrentContestSpelling(const aName: string): string;

implementation

uses
   SysUtils,
   uContestRegistry;

(* A LEGACY NAME -- the one loop over LEGACY_CONTEST_NAMES. *)
function FindLegacyName(const aName: string;
                        out aContest: TContestHandle): boolean;
var
   i: integer;
begin
   aContest := NoContest;
   Result := False;
   for i := Low(LEGACY_CONTEST_NAMES) to High(LEGACY_CONTEST_NAMES) do
      begin
      if UnicodeSameText(LEGACY_CONTEST_NAMES[i].Name, aName) then
         begin
         Result := FindContestById(LEGACY_CONTEST_NAMES[i].Id, aContest);
         Exit;
         end;
      end;
end;

function TryContestFromName(const aName: string;
                            out aContest: TContestHandle): boolean;
var
   name: string;
begin
   aContest := NoContest;
   Result := False;
   name := Trim(aName);
   if name = '' then
      begin
      Exit;
      end;

   Result := FindContestById(name, aContest);
   if not Result then
      begin
      Result := FindLegacyName(name, aContest);
      end;
end;

function ContestFromName(const aName: string): TContestHandle;
begin
   TryContestFromName(aName, Result);
end;

function CurrentContestSpelling(const aName: string): string;
var
   c: TContestHandle;
   name: string;
begin
   Result := aName;
   name := Trim(aName);
   if FindContestById(name, c) then
      begin
      Exit;
      end;
   if FindLegacyName(name, c) then
      begin
      Result := ContestId(c);
      end;
end;

end.

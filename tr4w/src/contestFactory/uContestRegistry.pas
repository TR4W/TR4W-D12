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

(* WHICH CLASS SERVES WHICH CONTEST -- the single source of truth, as
  uRadioRegistry is for radios.

  A contest unit registers itself from its own initialization section, so
  adding a contest touches its own unit and the two program files that list
  units, and nothing else. That property is the reason the radio factory is
  worth copying: it was verified there by adding TCI without changing a single
  shared file.

  AN ARRAY INDEXED BY ContestType, NOT A LIST. There are ~200 contests and the
  enum is dense, so the lookup is one index. It also means a registration for a
  contest that already has one is a DUPLICATE this can see and refuse -- the
  radio registry learned that the hard way, where a duplicate display name made
  a model invisible in the list rather than raising anything.

  NOT EVERY CONTEST HAS A CLASS, AND THAT IS THE POINT. This is a strangler:
  Lookup answers nil for a contest nobody has moved yet, and the caller falls
  through to the legacy path unchanged. *)
unit uContestRegistry;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

(* Registers aCls as the class serving aContest.

  RAISES on a duplicate. A second registration for one contest is a programming
  error -- two units both claiming ARRL-DX-CW -- and the alternatives are worse:
  last-wins hides it completely, and first-wins hides it while making the
  behaviour depend on unit initialisation order, which is the .lpr's uses clause
  and not something anyone reads as an ordering. *)
procedure RegisterContest(aContest: ContestType; aCls: TContestClass);

(* The class serving aContest, or nil when nothing has been registered for it.
  nil is an ORDINARY ANSWER during the migration, not a failure. *)
function ContestClassFor(aContest: ContestType): TContestClass;

(* How many contests have a class. For a lint or a test to assert against, so
  that "the factory is empty" cannot be mistaken for "the factory agrees with
  the legacy path". *)
function RegisteredContestCount: integer;

(* WHICH CONTEST ANSWERS TO THIS ADIF CONTEST_ID? True with aContest set when
  one does; False, with aContest at Low(ContestType), when none does.

  IT ASKS EVERY CONTEST, CLASS OR NOT, THROUGH THE SAME ACCESSOR. A contest
  with a class answers from its class; one without is asked through a plain
  TContestBase, whose accessor reads ContestsArray. So there is one rule for
  "what is this contest's id", and this is not a second copy of it.

  THE ORDER IS THE RULE:
    1. the input is TRIMMED, and an empty result matches NOTHING. A blank id
       means "this contest has none", so it can never identify one -- matching
       it is how an import used to land on the first blank row;
    2. every contest's CURRENT id is tried first, over the whole table;
    3. only then its FORMER ids (TContestBase.FormerADIFContestIds).
  So a rename can never let an old spelling steal a name another contest uses
  today. Within each pass the lowest ContestType wins, which is what the old
  lookup did for the one id two rows still share (RSGB-ROLO, CW and SSB).

  COMPARISON IS EXACT after the trim, as the lookup it replaces was.

  WHY IT LIVES HERE AND NOT IN uADIF. "Which contest is this" is a question
  about the whole set of contests, and this unit is the one that knows which
  class serves each. uADIF keeps its cache and calls this. *)
function FindContestByADIFContestId(const aId: string;
                                    out aContest: ContestType): boolean;

implementation

uses
   SysUtils;

var
   GRegistry: array[ContestType] of TContestClass;

procedure RegisterContest(aContest: ContestType; aCls: TContestClass);
begin
   if aCls = nil then
      begin
      raise Exception.CreateFmt(
         'RegisterContest(%s) was given a nil class.',
         [string(ContestTypeSA[aContest])]);
      end;

   if GRegistry[aContest] <> nil then
      begin
      raise Exception.CreateFmt(
         'Two classes claim %s: %s is already registered and %s tried to ' +
         'register as well. One contest, one class.',
         [string(ContestTypeSA[aContest]),
          GRegistry[aContest].ClassName, aCls.ClassName]);
      end;

   GRegistry[aContest] := aCls;
end;

function ContestClassFor(aContest: ContestType): TContestClass;
begin
   Result := GRegistry[aContest];
end;

function RegisteredContestCount: integer;
var
   c: ContestType;
begin
   Result := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if GRegistry[c] <> nil then
         begin
         inc(Result);
         end;
      end;
end;

(* The object that answers for aContest: its class, or a plain TContestBase
   reading ContestsArray when it has none. The caller frees it. *)
function NewContestObject(aContest: ContestType): TContestBase;
begin
   if GRegistry[aContest] <> nil then
      begin
      Result := GRegistry[aContest].Create(aContest);
      end
   else
      begin
      Result := TContestBase.Create(aContest);
      end;
end;

function FindContestByADIFContestId(const aId: string;
                                    out aContest: ContestType): boolean;
var
   id: string;
   c: ContestType;
   obj: TContestBase;
   former: TContestIdList;
   i: integer;
   haveFormer: boolean;
   formerContest: ContestType;
begin
   Result := False;
   aContest := Low(ContestType);

   id := Trim(aId);
   if id = '' then
      begin
      Exit;
      end;

   (* ONE WALK, TWO ANSWERS. A current-id match ends the search at once; a
      former-id match is only remembered, because a later contest's CURRENT id
      must still beat it. *)
   haveFormer := False;
   formerContest := Low(ContestType);
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := NewContestObject(c);
      try
         if obj.ADIFContestId = id then
            begin
            aContest := c;
            Result := True;
            Exit;
            end;

         if not haveFormer then
            begin
            former := obj.FormerADIFContestIds;
            for i := 0 to High(former) do
               begin
               if former[i] = id then
                  begin
                  haveFormer := True;
                  formerContest := c;
                  Break;
                  end;
               end;
            end;
      finally
         obj.Free;
         end;
      end;

   if haveFormer then
      begin
      aContest := formerContest;
      Result := True;
      end;
end;

end.

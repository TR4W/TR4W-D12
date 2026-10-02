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

(* NORTH CAROLINA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'nc_cty';  WA7BNM: 265;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 13;  AE: RSTDomesticQTHExchange;
   XM: NoDXMults;  QP: NCQSOPointMethod;
   ADIFName: 'NC-QSO-PARTY';  CABName: 'NC-QSO-PARTY';
   CountyLineAllowed: True;  FriendlyName: 'North Carolina QSO Party'

  ITS ADIFName WAS A SENTENCE UNTIL 2026-09-29 AND THE ARRAY WAS CORRECTED.
  The row held 'North Carolina QSO Party' where every other contest holds an
  upper-case token -- 'PA-QSO-PARTY', 'TX-QSO-PARTY'. NY4I: "The NC qso party
  adif name is in fact NC-QSO-PARTY." So VC.pas was changed, with his explicit
  approval, and this class states the corrected value.

  THE COMPATIBILITY COST WAS REAL AND IS CLOSED. D7 holds the same sentence,
  so every NC log TR4W has EVER exported carries CONTEST_ID = 'North Carolina
  QSO Party'. NY4I ruled that import accept both spellings while export writes
  only the new one -- "Yes support old spellings" (2026-09-29) -- so the
  sentence is this contest's former id, GetFormerADIFContestIds below.

  ===========================================================================
  THIS CLASS DELIBERATELY CHANGES THE SCORE. IT IS THE ONLY CONTEST IN THE
  MIGRATION THAT DOES, AND IT WAS RULED ON RATHER THAN DECIDED HERE.

  Every other contest moved into this factory reproduces its legacy arm
  exactly, because the one gate that can see scoring --
  test-contest-factory.sh -- compares the factory against TR4W's own former
  output. This one does not, on NY4I's instruction, 2026-09-29: "the rules
  given are it. tarheel was back in 2020 so go with the current rules."

  WHAT THE LEGACY ARM DID, and what has been deleted:
    a flat +50 for each of SEVEN callsigns -- N4T, N4A, N4R, N4H, N4E, W4E,
      N4L, which spell TARHEEL. They were that year's special-event stations;
      the sponsor's current rules specify no callsign bonuses at all.
    a flat +50 when DomesticQTH was 'ALL' or 'COL'. ALL is Alleghany, which is
      one of the ten rare counties below and is now paid on its own merits;
      COL is Columbus, which is not a rare county under the current rules and
      now scores base points like any other.

  WHAT THE SPONSOR PUBLISHES, https://ncqsoparty.org/rules/, and what this
  class implements:
    base points -- phone 2, CW 3, digital 5. UNCHANGED; the legacy arm already
      matched.
    "A QSO with someone in one of these counties will be scored 10X QSO points
      as follows: Phone - 20 points each CW - 30 points each Digital - 50
      points each" -- the ten "Rarest of NC" counties, listed below.

  THE SWEEP -- IMPLEMENTED AT M6 (2026-10-02), the gap this header recorded
  until the final-score seam existed: "If at least one QSO is made with a
  station in five of the 'Rarest of NC' counties, 500 additional bonus points
  are added to the score after multiplication. This would constitute a
  sweep." And: "Add bonus points to score (as applicable) after the
  multiplication."

  So BonusPoints, awarded ONCE for the whole log and never per QSO: five of
  the ten counties below, each by at least one contact, pays 500, and more
  than five pays the same 500. A county counts by the received county the
  per-QSO rule reads (DomesticQTH), from a contact that is not a dupe; a
  county-line station is logged as one QSO per county, so each of its
  counties counts.

  ---------------------------------------------------------------------------
  TWO COUNTIES ON A COUNTY LINE, FROM THE SAME PUBLISHED RULES.

  "A Mobile (while stationary,) Portable, or Expedition may operate on a county
  line and contacts can be used as credit for two counties. A maximum of two
  counties may be worked simultaneously under this provision."

  So GetCountyLineCountiesMax returns 2, the way Florida's does from its own
  rules. That number has been READ OUT OF THE RULES and is not derived from
  ContestsArray's CountyLineAllowed boolean, which carries no limit at all.
 *)
unit uContestNorthCarolinaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestNorthCarolinaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same answer -- but the base makes it
         abstract for state parties precisely so that answer is never an
         accident. *)
      function GetHostState: string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I, 2026-09-29: "all the info in [the row] should go into the contest
         class." Every getter below returns what the array holds today, so this
         changes no behaviour -- it moves the ANSWER, so that reading this one
         file tells you what the contest is without cross-referencing a 185-row
         table by enum position.

         THE ROW IS NOT DELETED AND MUST NOT BE. It still answers for every
         contest that has no class, and for every accessor a class does not
         override. *)
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFormerADIFContestIds: TContestIdList; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetPrefixMultiplierType: PrefixMultType; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDXMultiplierType: DXMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;

      (* Two counties, from the sponsor's rules -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* THE RAREST-OF-NC SWEEP -- see the header. *)
      function BonusPoints(const aTotals: TScoreTotals;
                           aView: TLoggedQSOView): longint; override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

const
   (* THE TEN "RAREST OF NC" COUNTIES, as the sponsor lists them and as
      target\dom\nc_cty.dom spells them. Every one of these ten abbreviations
      was checked to exist in that file before it was written here.

      GRAHAM IS 'GRM' AND NOT 'GRA'. BOTH EXIST IN nc_cty.dom -- 'GRA' is a
      different county on line 52, 'GRM' is Graham on line 54 -- so a
      three-letter slip does not fail, it pays ten times the points to the
      wrong county and says nothing. That is the one mistake this list invites,
      so it is written down beside the list rather than in a commit message.

      ONE NAMED SET AND NOT TEN if-BLOCKS: the legacy arm's shape was a list
      pretending to be control flow, which could not be read at a glance or
      changed in one place. The rule is a membership test, so it is written as
      one. *)
   NCRareCounties: array[0..9] of string =
      ('CAB',    (* Cabarrus   *)
       'GRM',    (* Graham -- NOT 'GRA', see above *)
       'VAN',    (* Vance      *)
       'MAC',    (* Macon      *)
       'DAV',    (* Davie      *)
       'CUR',    (* Currituck  *)
       'PAM',    (* Pamlico    *)
       'ALL',    (* Alleghany  *)
       'PER',    (* Person     *)
       'CAS');   (* Caswell    *)

   (* "A QSO with someone in one of these counties will be scored 10X QSO
      points as follows: Phone - 20 points each CW - 30 points each Digital -
      50 points each."

      THE RULE IS A MULTIPLIER AND IS WRITTEN AS ONE. Stating 20 / 30 / 50 as
      three more literals would be a second copy of the base points, free to
      drift from the first the day the sponsor changes one of them -- and the
      sponsor's own wording derives the three numbers exactly this way. *)
   NCRareCountyMultiplier = 10;

   (* "at least one QSO ... in five of the 'Rarest of NC' counties, 500
      additional bonus points" -- the two numbers of the sweep. *)
   NCSweepCounties = 5;
   NCSweepBonus = 500;

function TContestNorthCarolinaQP.GetDisplayName: string;
begin
   Result := 'North Carolina QSO Party';
end;

function TContestNorthCarolinaQP.GetHostState: string;
begin
   Result := 'NC';
end;

function TContestNorthCarolinaQP.GetCabrilloName: string;
begin
   Result := 'NC-QSO-PARTY';
end;

function TContestNorthCarolinaQP.GetADIFContestId: string;
begin
   Result := 'NC-QSO-PARTY';
end;

function TContestNorthCarolinaQP.GetFormerADIFContestIds: TContestIdList;
begin
   (* The row's ADIFName until 2026-09-29, and D7's -- see the unit header. *)
   Result := ContestIdList(['North Carolina QSO Party']);
end;

function TContestNorthCarolinaQP.GetWA7BNMId: integer;
begin
   Result := 265;
end;

function TContestNorthCarolinaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNorthCarolinaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestNorthCarolinaQP.GetDomesticFileName: string;
begin
   Result := 'nc_cty';
end;

function TContestNorthCarolinaQP.GetFriendlyName: string;
begin
   Result := 'North Carolina QSO Party';
end;

function TContestNorthCarolinaQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestNorthCarolinaQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestNorthCarolinaQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestNorthCarolinaQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestNorthCarolinaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNorthCarolinaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestNorthCarolinaQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := NCQSOPointMethod;
end;

function TContestNorthCarolinaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* MEMBERSHIP IN THE RARE-COUNTY LIST. An exact, case-sensitive comparison
   against the abbreviations nc_cty.dom holds, which is what the exchange
   parser puts in DomesticQTH -- the same comparison the legacy arm used for
   its own county test. *)
function IsRareNCCounty(const aQTH: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(NCRareCounties) to High(NCRareCounties) do
      begin
      if aQTH = NCRareCounties[i] then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* NCQSOPointMethod, REPLACED BY THE CURRENT PUBLISHED RULES -- see the header
   for what was deleted and who approved it.

   THE BASE IS A THREE-WAY SPLIT AND NOT A TWO-WAY ONE: phone 2, CW 3, digital
   5. Digital is its own number here, unlike most of the state parties, so
   FixedModePoints' third argument is genuinely a third value rather than a
   repeat of one of the others.

   THE RARE-COUNTY BONUS MULTIPLIES THAT BASE, giving the sponsor's phone 20 /
   CW 30 / digital 50 without restating any of them. *)
procedure TContestNorthCarolinaQP.CalculateQSOPoints(var aQso: ContestExchange);
var
   points: integer;
begin
   points := FixedModePoints(aQso.Mode, 3, 2, 5);

   if IsRareNCCounty(string(aQso.DomesticQTH)) then
      begin
      points := points * NCRareCountyMultiplier;
      end;

   aQso.QSOPoints := points;
end;

function TContestNorthCarolinaQP.BonusPoints(const aTotals: TScoreTotals;
                                             aView: TLoggedQSOView): longint;
var
   worked: array[Low(NCRareCounties)..High(NCRareCounties)] of boolean;
   countiesWorked: integer;
   i, c: integer;
   qso: ContestExchange;
begin
   Result := inherited BonusPoints(aTotals, aView);

   for c := Low(worked) to High(worked) do
      begin
      worked[c] := False;
      end;

   for i := 0 to aView.Count - 1 do
      begin
      qso := aView.QSO(i);
      if qso.ceDupe then
         begin
         Continue;
         end;
      for c := Low(NCRareCounties) to High(NCRareCounties) do
         begin
         if string(qso.DomesticQTH) = NCRareCounties[c] then
            begin
            worked[c] := True;
            end;
         end;
      end;

   countiesWorked := 0;
   for c := Low(worked) to High(worked) do
      begin
      if worked[c] then
         begin
         inc(countiesWorked);
         end;
      end;

   if countiesWorked >= NCSweepCounties then
      begin
      Result := Result + NCSweepBonus;
      end;
end;

initialization
   RegisterContest(NCQSOPARTY, TContestNorthCarolinaQP);

end.

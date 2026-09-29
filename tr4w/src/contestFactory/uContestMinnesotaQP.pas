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

(* MINNESOTA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'minnesota_cty';  WA7BNM: 238;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 1;  AE: NameAndDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: TwoPointsPerQSO, with a commented-out
   MQPQSOPointMethod beside it;
   ADIFName: 'MN-QSO-PARTY';  CABName: 'MN-QSO-PARTY';
   CountyLineAllowed: True;  FriendlyName: 'Minnesota QSO Party'

  THE ROW CARRIES A COMMENTED-OUT SECOND ANSWER: its QP names TwoPointsPerQSO
  with MQPQSOPointMethod commented out immediately beside it. The live value is
  TwoPointsPerQSO and that is what is stated here; MQPQSOPointMethod is a point
  method somebody once intended and did not switch on, and reviving it would be
  a rules change rather than a move.

  NO COUNTY-LINE MAXIMUM IS ESTABLISHED FOR THIS PARTY, so it inherits
  TContestStateQSOPartyBase's CountyLineCountiesUnlimited -- which is exactly
  what TR4W does today, because nothing in the program has ever counted the
  queued counties.

  THAT IS "NOT LOOKED UP YET", NOT "UNLIMITED BY DECISION", and the difference
  matters: a number here would have to come from the sponsor's published rules,
  the way Florida's two and California's four did. It must NOT be derived from
  ContestsArray's CountyLineAllowed boolean, which carries no limit at all --
  reading it as a number is the defect that made a class of any kind start
  refusing a two-QTH exchange.
 *)
unit uContestMinnesotaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestStateQSOPartyBase;

type
   TContestMinnesotaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'MN' -- but the base makes it abstract
         for state parties precisely so that answer is never an accident. *)
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
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestMinnesotaQP.GetDisplayName: string;
begin
   Result := 'Minnesota QSO Party';
end;

function TContestMinnesotaQP.GetHostState: string;
begin
   Result := 'MN';
end;

function TContestMinnesotaQP.GetCabrilloName: string;
begin
   Result := 'MN-QSO-PARTY';
end;

function TContestMinnesotaQP.GetADIFContestId: string;
begin
   Result := 'MN-QSO-PARTY';
end;

function TContestMinnesotaQP.GetWA7BNMId: integer;
begin
   Result := 238;
end;

function TContestMinnesotaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestMinnesotaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestMinnesotaQP.GetDomesticFileName: string;
begin
   Result := 'minnesota_cty';
end;

function TContestMinnesotaQP.GetFriendlyName: string;
begin
   Result := 'Minnesota QSO Party';
end;

function TContestMinnesotaQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestMinnesotaQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestMinnesotaQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestMinnesotaQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestMinnesotaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestMinnesotaQP.GetExchangeKind: ExchangeType;
begin
   Result := NameAndDomesticOrDXQTHExchange;
end;

function TContestMinnesotaQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TwoPointsPerQSO;
end;

(* TwoPointsPerQSO -- `RXData.QSOPoints := 2`, a flat two whatever the mode.
   All three numbers are the same and are still written out: the day this
   contest gains a mode rule, the shape is already here. *)
procedure TContestMinnesotaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 2, 2);
end;

initialization
   RegisterContest(MINNQSOPARTY, TContestMinnesotaQP);

end.

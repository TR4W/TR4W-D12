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

(* PENNSYLVANIA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'pa_cty';  WA7BNM: 153;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 14;  AE: QSONumberDomesticQTHExchange;
   XM: NoDXMults;  QP: PAQSOPointMethod;  ADIFName: 'PA-QSO-PARTY';
   CABName: 'PA-QSO-PARTY';  CountyLineAllowed: True;
   FriendlyName: 'Pennsylvania QSO Party'

  ITS POINT METHOD WAS SHARED WITH ANOTHER CONTEST. PAQSOPointMethod is also
  the QP in IN7QPNE's row, the combined Indiana / 7th call area / New England
  / Delaware entry -- which scored every QSO through the legacy arm until it
  gained its composite class on 2026-10-14 (design 8.2r) and now scores each
  QSO by its party's class. The arm stayed only for an operator's QSO POINT
  METHOD, and was deleted with the legacy scoring case at M10 S3 (design
  7.15).

  NO COUNTY-LINE MAXIMUM IS ESTABLISHED FOR THIS PARTY, so it inherits
  TContestStateQSOPartyBase's CountyLineCountiesUnlimited -- exactly what TR4W
  does today, because nothing in the program has ever counted the queued
  counties.

  THAT IS "NOT LOOKED UP YET", NOT "UNLIMITED BY DECISION". Its row does carry
  CountyLineAllowed: True, and that boolean carries no LIMIT at all: reading
  its False arm as zero is the defect that made a contest start refusing a
  two-QTH exchange the moment it got a class, and reading its True arm as some
  particular number would be an invention. A number must come from the
  sponsor's published rules the way Florida's two and California's four did.
 *)
unit uContestPennsylvaniaQP;

{$I tr4w.inc}

interface

uses
   VC,
   uContestBase,   (* TContestFlags (M10 S5) *)
   uContestStateQSOPartyBase;

type
   TContestPennsylvaniaQP = class(TContestStateQSOPartyBase)
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
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetInStateDomesticFileName: string; override;
      (* THE OLD ROW'S CountyLineAllowed: True, which ADIF export read to split
         a rover's call -- M10 S8; open question Q90. See
         TContestStateQSOPartyBase.GetSplitsRoverCallOnExport. *)
      function GetSplitsRoverCallOnExport: boolean; override;
      function GetFlags: TContestFlags; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestPennsylvaniaQP.GetDisplayName: string;
begin
   Result := 'Pennsylvania QSO Party';
end;

function TContestPennsylvaniaQP.GetHostState: string;
begin
   Result := 'PA';
end;

function TContestPennsylvaniaQP.GetCabrilloName: string;
begin
   Result := 'PA-QSO-PARTY';
end;

function TContestPennsylvaniaQP.GetADIFContestId: string;
begin
   Result := 'PA-QSO-PARTY';
end;

function TContestPennsylvaniaQP.GetWA7BNMId: integer;
begin
   Result := 153;
end;

function TContestPennsylvaniaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestPennsylvaniaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestPennsylvaniaQP.GetDomesticFileName: string;
begin
   Result := 'pa_cty';
end;

function TContestPennsylvaniaQP.GetFriendlyName: string;
begin
   Result := 'Pennsylvania QSO Party';
end;

function TContestPennsylvaniaQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestPennsylvaniaQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestPennsylvaniaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestPennsylvaniaQP.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberDomesticQTHExchange;
end;

function TContestPennsylvaniaQP.GetInStateDomesticFileName: string;
begin
   Result := 'pa';
end;

function TContestPennsylvaniaQP.GetSplitsRoverCallOnExport: boolean;
begin
   Result := True;
end;

function TContestPennsylvaniaQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode];
end;

(* PAQSOPointMethod -- `if Mode = PHONE then 1 else 2`.

   THE INVERTED SHAPE, AND THE THIRD ARGUMENT IS WHERE IT SHOWS. The test is
   PHONE-versus-not, so DIGITAL takes the CW value of 2, not the phone value of
   1. Most of the state parties test CW-versus-not and their digital number is
   the phone one; writing 1 here would reproduce the phone and CW arms
   perfectly and be silently wrong about every digital QSO. *)
procedure TContestPennsylvaniaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 2);
end;

initialization
   RegisterContest(PAQSOPARTY, TContestPennsylvaniaQP);

end.

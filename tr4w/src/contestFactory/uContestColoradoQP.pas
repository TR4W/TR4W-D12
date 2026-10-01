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

(* COLORADO QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'colorado_cty';  WA7BNM: 431;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 12;  AE: NameAndDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: TwoPointsPerQSO;  ADIFName: 'CO-QSO-PARTY';
   CABName: 'COQP';  CountyLineAllowed: True;
   FriendlyName: 'Colorado QSO Party'

  THE ROW'S Email AND DF WERE SWAPPED, AND ARE CORRECTED -- in the row and here
  together, 2026-10-01 (M2, inventory defect #5). Email held 'colorado_cty',
  a domestic file name, and DF was empty, where every other state party names
  its <state>_cty county file in DF. It came from D7: C:\TR4W VC.pas carries
  the same Email: 'colorado_cty' with DF: nil, so it was never a port
  regression.

  IT WAS INERT UNTIL M2 AND WOULD NOT HAVE STAYED SO. FCONTEST took a party's
  files from QSOParties[P] and never asked DF, so the empty name cost nothing
  -- but the in-state test read DF, and once M2 made that test work (defect
  #1) and set-up began asking the contest for its county file, an empty DF
  would have left Colorado the one party whose stations could never be in
  state. The sponsor's submission address is not known here, so Email is
  blank, as it is for most parties.

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
unit uContestColoradoQP;

{$I tr4w.inc}

interface

uses
   VC, uContestStateQSOPartyBase;

type
   TContestColoradoQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'CO' -- but the base makes it abstract
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

function TContestColoradoQP.GetDisplayName: string;
begin
   Result := 'Colorado QSO Party';
end;

function TContestColoradoQP.GetHostState: string;
begin
   Result := 'CO';
end;

function TContestColoradoQP.GetCabrilloName: string;
begin
   Result := 'COQP';
end;

function TContestColoradoQP.GetADIFContestId: string;
begin
   Result := 'CO-QSO-PARTY';
end;

function TContestColoradoQP.GetWA7BNMId: integer;
begin
   Result := 431;
end;

function TContestColoradoQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestColoradoQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestColoradoQP.GetDomesticFileName: string;
begin
   Result := 'colorado_cty';
end;

function TContestColoradoQP.GetFriendlyName: string;
begin
   Result := 'Colorado QSO Party';
end;

function TContestColoradoQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestColoradoQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestColoradoQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestColoradoQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestColoradoQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestColoradoQP.GetExchangeKind: ExchangeType;
begin
   Result := NameAndDomesticOrDXQTHExchange;
end;

function TContestColoradoQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TwoPointsPerQSO;
end;

(* TwoPointsPerQSO -- `RXData.QSOPoints := 2`, a flat two whatever the mode.
   All three numbers are the same and are still written out: the day this
   contest gains a mode rule, the shape is already here. *)
procedure TContestColoradoQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 2, 2);
end;

initialization
   RegisterContest(COLORADOQSOPARTY, TContestColoradoQP);

end.

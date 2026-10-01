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

(* TENNESSEE QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'tennessee_cty';  WA7BNM: 115;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 8;  AE: RSTDomesticQTHExchange;
   XM: NoDXMults;  QP: TwoPhoneThreeCW;  ADIFName: 'TN-QSO-PARTY';
   CABName: 'TN-QSO-PARTY';  CountyLineAllowed: True;
   FriendlyName: 'Tennessee QSO Party'

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
unit uContestTennesseeQP;

{$I tr4w.inc}

interface

uses
   VC, uContestStateQSOPartyBase;

type
   TContestTennesseeQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'TN' -- but the base makes it abstract
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
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestTennesseeQP.GetDisplayName: string;
begin
   Result := 'Tennessee QSO Party';
end;

function TContestTennesseeQP.GetHostState: string;
begin
   Result := 'TN';
end;

function TContestTennesseeQP.GetCabrilloName: string;
begin
   Result := 'TN-QSO-PARTY';
end;

function TContestTennesseeQP.GetADIFContestId: string;
begin
   Result := 'TN-QSO-PARTY';
end;

function TContestTennesseeQP.GetWA7BNMId: integer;
begin
   Result := 115;
end;

function TContestTennesseeQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestTennesseeQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestTennesseeQP.GetDomesticFileName: string;
begin
   Result := 'tennessee_cty';
end;

function TContestTennesseeQP.GetFriendlyName: string;
begin
   Result := 'Tennessee QSO Party';
end;

function TContestTennesseeQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestTennesseeQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestTennesseeQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestTennesseeQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestTennesseeQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestTennesseeQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestTennesseeQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TwoPhoneThreeCW;
end;

(* TwoPhoneThreeCW -- `if Mode = CW then 3 else 2`, so DIGITAL scores the
   PHONE value. That is why the third number is stated rather than left to
   a CW-versus-not test, which would be wrong here and silent about it. *)
procedure TContestTennesseeQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 3, 2, 2);
end;

initialization
   RegisterContest(TENNESSEEQSOPARTY, TContestTennesseeQP);

end.

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

(* TEXAS QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'texas_cty';  WA7BNM: 133;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 4;  AE: RSTDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: TwoPhoneThreeCW;  ADIFName: 'TX-QSO-PARTY';
   CABName: '';  CountyLineAllowed: True;
   FriendlyName: 'Texas QSO Party'

  ITS CABName IS BLANK IN THE ROW AND BLANK IS NOT THE ANSWER. PostUnit's rule,
  reproduced by TContestBase.GetCabrilloName, is that an empty CABName means
  ContestTypeSA[ct] -- so the CONTEST: line of a submitted log reads
  TEXAS QSO PARTY, and returning '' here would put a blank header line in an
  entrant's Cabrillo. ADIFName is the opposite and is stated as it stands.

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
unit uContestTexasQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestTexasQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'TX' -- but the base makes it abstract
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
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestTexasQP.GetDisplayName: string;
begin
   Result := 'Texas QSO Party';
end;

function TContestTexasQP.GetHostState: string;
begin
   Result := 'TX';
end;

function TContestTexasQP.GetCabrilloName: string;
begin
   Result := 'TEXAS QSO PARTY';
end;

function TContestTexasQP.GetADIFContestId: string;
begin
   Result := 'TX-QSO-PARTY';
end;

function TContestTexasQP.GetWA7BNMId: integer;
begin
   Result := 133;
end;

function TContestTexasQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestTexasQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestTexasQP.GetDomesticFileName: string;
begin
   Result := 'texas_cty';
end;

function TContestTexasQP.GetFriendlyName: string;
begin
   Result := 'Texas QSO Party';
end;

function TContestTexasQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestTexasQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestTexasQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestTexasQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestTexasQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestTexasQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestTexasQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TwoPhoneThreeCW;
end;

(* TwoPhoneThreeCW -- `if Mode = CW then 3 else 2`, so DIGITAL scores the
   PHONE value. That is why the third number is stated rather than left to
   a CW-versus-not test, which would be wrong here and silent about it. *)
procedure TContestTexasQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 3, 2, 2);
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestTexasQP.DescribeSession(const aStation: TStationContext;
                                          aSession: TSessionDefaults);
begin
   (* BOTH SIDES OF THE STATE LINE, STATED (inventory D8). *)
   if aStation.InHostState then
      begin
      aSession.DXMult := ARRLDXCCWithNoUSACanadaKH6OrKL7;
      end
   else
      begin
      aSession.Exchange := RSTDomesticQTHExchange;
      end;
end;

initialization
   RegisterContest(TEXASQSOPARTY, TContestTexasQP);

end.

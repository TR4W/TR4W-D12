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

(* INDIANA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'in_cty';  WA7BNM: 8;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 15;  AE: RSTDomesticQTHExchange;
   XM: NoDXMults;  QP: TWOPOINTSPERQSO;  ADIFName: 'IN-QSO-PARTY';
   CABName: 'IN-QSO-PARTY';  CountyLineAllowed: True;
   FriendlyName: 'Indiana QSO Party'

  TWO COUNTIES, FROM THE SPONSOR'S RULES. NY4I, 2026-09-29: "Indiana qso party
  allows 2 counties max at once."

  Same number as Florida and arrived at independently, which is the argument
  for looking each party up rather than copying a neighbour: Michigan forbids
  the practice outright and California allows four.
 *)
unit uContestIndianaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestStateQSOPartyBase;

type
   TContestIndianaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'IN' -- but the base makes it abstract
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

      (* The county-line maximum, from the sponsor -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* A DX STATION EARNS NO MULTIPLIER -- logdupe's SetMultFlags rule for
         this contest (4.116.5), moved here at M8 and transcribed exactly: a
         multiplier QTH of 'DX' earns no multiplier of any kind. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestIndianaQP.CountsAsMultiplier(const aQso: ContestExchange;
                                              aKind: RemainingMultiplierType): boolean;
begin
   (* Every kind: the legacy rule returned before any flag was set. *)
   Result := aQso.DomMultQTH <> 'DX';
end;

function TContestIndianaQP.GetDisplayName: string;
begin
   Result := 'Indiana QSO Party';
end;

function TContestIndianaQP.GetHostState: string;
begin
   Result := 'IN';
end;

function TContestIndianaQP.GetCabrilloName: string;
begin
   Result := 'IN-QSO-PARTY';
end;

function TContestIndianaQP.GetADIFContestId: string;
begin
   Result := 'IN-QSO-PARTY';
end;

function TContestIndianaQP.GetWA7BNMId: integer;
begin
   Result := 8;
end;

function TContestIndianaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestIndianaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestIndianaQP.GetDomesticFileName: string;
begin
   Result := 'in_cty';
end;

function TContestIndianaQP.GetFriendlyName: string;
begin
   Result := 'Indiana QSO Party';
end;

function TContestIndianaQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestIndianaQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestIndianaQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestIndianaQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestIndianaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestIndianaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestIndianaQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TwoPointsPerQSO;
end;

function TContestIndianaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* TwoPointsPerQSO -- `RXData.QSOPoints := 2`, a flat two whatever the mode.
   All three numbers are the same and are still written out: the day this
   contest gains a mode rule, the shape is already here. *)
procedure TContestIndianaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 2, 2);
end;

initialization
   RegisterContest(INQSOPARTY, TContestIndianaQP);

end.

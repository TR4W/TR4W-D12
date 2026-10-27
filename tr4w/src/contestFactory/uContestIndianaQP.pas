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

  BANDS (NY4I, 2026-10-16, from the four parties' rules): 160, 80, 40, 20,
  15 and 10 m -- no WARC, no VHF. UsesBand states them; a QSO anywhere else
  is logged, scores 0 and earns no multiplier (design 7.4).

  #88 ROUND 3 (2026-10-26), the sponsor's 2026 rules
  (docs/ContestRules/QSOParties/Indiana/IN-QSO-PARTY-Rules.txt):
  multipliers once per MODE (GetFlags' cfMultByMode), and for an Indiana
  entrant the states are "the other 49" -- Indiana itself is no multiplier
  (CountsAsMultiplier). Rovers in a new county were already new QSOs here
  (the state-party base's dupe key, Q118).
 *)
unit uContestIndianaQP;

{$I tr4w.inc}

interface

uses
   VC,
   uContestBase,   (* TContestFlags (M10 S5) *)
   uContestStateQSOPartyBase;

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
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;

      (* The county-line maximum, from the sponsor -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* 160 to 10 m without WARC -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;
      (* A DX STATION EARNS NO MULTIPLIER -- logdupe's SetMultFlags rule for
         this contest (4.116.5), moved here at M8: a multiplier QTH of 'DX'
         earns no multiplier of any kind. IN ANY CASE since Q84 (NY4I,
         2026-10-15: "ignore case") -- IN7QPNE's file maps `dx = dx`, so an
         Indiana-judged DX contact there earned the one 'dx' multiplier.
         uContestBase.DomesticMultiplierIsDX is the test. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestIndianaQP.CountsAsMultiplier(const aQso: ContestExchange;
                                              aKind: RemainingMultiplierType): boolean;
begin
   (* Every kind: the legacy rule returned before any flag was set. *)
   Result := not DomesticMultiplierIsDX(string(aQso.DomMultQTH));

   (* "Indiana stations: The 92 Indiana counties (see Section 9). The other
      49 U.S. states" -- #88 round 3 (2026-10-26). in.dom includes the shared
      S50.DOM, which holds In; for an Indiana entrant that is not a
      multiplier (an Indiana station sends its county). *)
   if Result and
      Station.InHostState and
      DomesticMultiplierIsHostState(string(aQso.DomMultQTH), HostState) then
      begin
      Result := False;
      end;
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

function TContestIndianaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestIndianaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestIndianaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestIndianaQP.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

procedure TContestIndianaQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestIndianaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestIndianaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestIndianaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestIndianaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

function TContestIndianaQP.GetInStateDomesticFileName: string;
begin
   Result := 'in';
end;

function TContestIndianaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10];
end;

(* MULTIPLIERS ONCE PER MODE -- #88 round 3 (2026-10-26): "Multipliers
   count once per mode (i.e. once on CW and once on phone). This means you
   can double your possible mults by working both modes." For every entrant,
   inside Indiana and out. *)
function TContestIndianaQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByMode];
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

(* ONE SEARCH-AND-POUNCE ENTRY MAY CARRY SEVERAL QTHs, at every station --
   M11 S7, 2026-10-14. It was the session's RSTDomesticQTH shape; see
   TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestIndianaQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(INQSOPARTY, TContestIndianaQP);

end.

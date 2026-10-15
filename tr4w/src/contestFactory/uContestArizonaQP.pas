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

(* ARIZONA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: 'info@azqp.org';  DF: 'arizona_cty';  WA7BNM: 482;
   QRZRUID: 0;  Pxm: NoPrefixMults;  ZnM: NoZoneMults;
   AIE: NoInitialExchange;  DM: DomesticFile;  P: 19;
   AE: RSTDomesticOrDXQTHExchange;  XM: ARRLDXCCWithNoUSAOrCanada;
   QP: OnePhoneTwoCW;  ADIFName: 'AZ-QSO-PARTY';
   CABName: 'AZ-QSO-PARTY';  FriendlyName: 'Arizona QSO Party'

  THE ONE OF THE TEN WHOSE ROW CARRIES NO CountyLineAllowed FIELD AT ALL, so it
  reads as False. THAT MEANS UNKNOWN, NOT ZERO. A missing field is the record's
  default and not a decision anybody made -- four other single-state parties are
  in the same position -- so inferring "no county line permitted" from it would
  invent a rule out of an absence. Michigan's none came from the sponsor's own
  words; nothing comparable has been read for Arizona, so it inherits unlimited
  with every other unlooked-up party and TR4W's behaviour is unchanged.

  IT IS ALSO THE ONLY ONE OF THE TEN WITH DX MULTIPLIERS: XM is
  ARRLDXCCWithNoUSAOrCanada, where the other nine are NoDXMults. Stated as a
  literal like the rest of the row; nothing else about it moves here.

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
unit uContestArizonaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestArizonaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'AZ' -- but the base makes it abstract
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

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      (* THE CTY COUNTRY LIST -- see TContestBase.CountryMode (M11 S4). *)
      function CountryMode: CountryModeType; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   end;

implementation

uses
   uDXMultiplierKey,
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestArizonaQP.GetDisplayName: string;
begin
   Result := 'Arizona QSO Party';
end;

function TContestArizonaQP.GetHostState: string;
begin
   Result := 'AZ';
end;

function TContestArizonaQP.GetCabrilloName: string;
begin
   Result := 'AZ-QSO-PARTY';
end;

function TContestArizonaQP.GetADIFContestId: string;
begin
   Result := 'AZ-QSO-PARTY';
end;

function TContestArizonaQP.GetWA7BNMId: integer;
begin
   Result := 482;
end;

function TContestArizonaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestArizonaQP.GetSubmissionEmail: string;
begin
   Result := 'info@azqp.org';
end;

function TContestArizonaQP.GetDomesticFileName: string;
begin
   Result := 'arizona_cty';
end;

function TContestArizonaQP.GetFriendlyName: string;
begin
   Result := 'Arizona QSO Party';
end;

function TContestArizonaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestArizonaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestArizonaQP.GetInStateDomesticFileName: string;
begin
   Result := 'arizona';
end;

function TContestArizonaQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfMultByMode];
end;

(* OnePhoneTwoCW -- `if Mode = CW then 2 else 1`, so DIGITAL scores the
   PHONE value. That is why the third number is stated rather than left to
   a CW-versus-not test, which would be wrong here and silent about it. *)
procedure TContestArizonaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestArizonaQP.DescribeSession(const aStation: TStationContext;
                                            aSession: TSessionDefaults);
begin
   aSession.SetCQMemory(CW, smkF1, 'CQ AZ \ \ AZ');
   aSession.SetCQMemory(CW, smkF2, 'CQ^AZ CQ^AZ \ \ AZQP');
   aSession.CQExchangeCW := aStation.MyState;
   aSession.SPExchangeCW := aStation.MyState;
   aSession.QSLCW := '73 \/AZ ';

   (* BOTH SIDES OF THE STATE LINE, STATED (inventory D8). The trait is the
      row's RSTDomesticOrDXQTHExchange, and an in-state station keeps it;
      out of state the exchange is the county alone. *)
   if aStation.InHostState then
      begin
      aSession.MultByBand := False;
      end
   else
      begin
      aSession.Exchange := RSTDomesticQTHExchange;
      end;
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`ARRLDXCCWithNoUSAOrCanada`) until the kind was
   deleted. *)
function TContestArizonaQP.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country but the USA and Canada -- the ARRLDXCCWithNoUSAOrCanada arm. *)
function TContestArizonaQP.DXMultiplierKey(const aQso: ContestExchange;
                                           out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if not IsUSAOrCanadaCountry(aQso.QTH.CountryID) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only, at every station. *)
function TContestArizonaQP.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;

(* OUT OF THE HOST STATE ONE ENTRY MAY CARRY SEVERAL QTHs (RSTDomesticQTH);
   in it, not (RSTDomesticOrDXQTH) -- M11 S7, 2026-10-14. It was the
   session's shape, and this is the station test DescribeSession chooses the
   shape by; see TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestArizonaQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := not Station.InHostState;
end;

initialization
   RegisterContest(ArizonaQsoParty, TContestArizonaQP);

end.

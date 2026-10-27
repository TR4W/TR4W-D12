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

(* MICHIGAN QSO PARTY.

  THE SECOND STATE PARTY, AND IT EXISTS TO PROVE THE BASE RATHER THAN TO SHOW
  IT OFF. Florida had a class and Michigan ran entirely through the legacy path,
  so the pair is the one place in the corpus where TContestStateQSOPartyBase can be
  measured: both logs are in the golden corpus, and test-contest-factory.sh can
  diff factory against legacy on a contest that has just changed sides.

  WHAT IT DOES NOT OWN, AND WHY THAT IS THE POINT.

  ITS EXCHANGE IS NOT FLORIDA'S. Michigan is RSTDomesticQTHExchange and Florida
  is RSTDomesticOrDXQTHExchange: Florida delegates to the domestic parser only
  for a domestic callsign and gives a DX station a free-text QTH, where Michigan
  has no DX side at all. Two state parties, two parsers -- which is the whole
  argument for this base being a mechanism base and not a family one.

  IT HAS NO EXPORT RULE OF ITS OWN. TContestBase formats it through the
  shared RSTDomesticQTHExchange arm (M4). The three cases in that arm that
  were not Michigan's -- CQ VHF's grid, SP DX's and PACC's serial -- left it at
  M4: PACC's is TContestPACC's own, and the other two were dead.

  ITS POINTS ARE ITS OWN, though they happen to equal Florida's. OnePhoneTwoCW
  is 11 contests' answer and two of them being state parties is a coincidence
  of sponsors -- California is three points flat and Texas is TwoPhoneThreeCW.
  NY4I on the two Field Days: "They keep diverging with rule changes each
  year." *)
unit uContestMichiganQP;

{$I tr4w.inc}

interface

uses
   VC,
   uContestBase,   (* TContestFlags (M10 S5) *)
   uContestStateQSOPartyBase;

type
   TContestMichiganQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFriendlyName: string; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetWA7BNMId: integer; override;
      function GetDomesticFileName: string; override;
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
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      function GetHostState: string; override;

      (* NO COUNTY LINE AT ALL -- AND ContestsArray SAYS OTHERWISE.

         THE SPONSOR'S RULE: "No station may claim simultaneous operation in
         more than one county, state, or province." Michigan is the opposite
         end of the same axis from Florida, whose rules allow exactly two.

         VC.pas GIVES MICHQSOPARTY CountyLineAllowed: True, WHICH IS WRONG, AND
         THIS IS THE FIRST THING THE FACTORY HAS CAUGHT THAT NOTHING ELSE
         COULD. The flag is not inert: MainUnit's ADIF import sets
         ceClearDupeSheet whenever the same (call|band|mode) reappears with a
         different QTHString in a contest carrying it, so a GENUINE DUPLICATE
         in a Michigan log is accepted today instead of being flagged.

         THE ARRAY IS DELIBERATELY NOT EDITED. It is the compatibility source
         and the class is where a contest states what it owns, so the two are
         allowed to disagree exactly where somebody has deliberately made them
         -- see uContestBase's note on the accessors. Everything still reading
         ContestsArray directly (MainUnit's import, uADIF's rover-call parse)
         is unchanged and keeps its present behaviour until it asks the factory
         instead. That repoint is a separate change with its own evidence.

         SO WHAT DOES CHANGE TODAY: the exchange parser will refuse a
         two-county exchange in this contest, which is the edit check the rule
         describes. Nothing in the export path consults this -- verified
         against uADIF.ResolveRoverCall and MainUnit's import, both of which
         read the array -- so the golden corpus cannot move. *)
      function GetCountyLineCountiesMax: integer; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   public
      (* MICHIGAN IS NOT A STATE MULTIPLIER FOR A MICHIGAN ENTRANT --
         #88 round 3 (2026-10-26). See the implementation. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestFixedPoints, uContestRegistry;

function TContestMichiganQP.GetDisplayName: string;
begin
   Result := 'Michigan QSO Party';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestMichiganQP.GetCabrilloName: string;
begin
   Result := 'MI-QSO-PARTY';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestMichiganQP.GetADIFContestId: string;
begin
   Result := 'MI-QSO-PARTY';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestMichiganQP.GetFriendlyName: string;
begin
   Result := 'Michigan QSO Party';
end;

function TContestMichiganQP.GetWA7BNMId: integer;
begin
   Result := 323;
end;

function TContestMichiganQP.GetDomesticFileName: string;
begin
   Result := 'michigan_cty';
end;

function TContestMichiganQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestMichiganQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestMichiganQP.ParseReceivedExchangeFormat(const aText: string;
                                                        aParsers: TExchangeParsers;
                                                        var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

procedure TContestMichiganQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestMichiganQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestMichiganQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestMichiganQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestMichiganQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

function TContestMichiganQP.GetInStateDomesticFileName: string;
begin
   Result := 'michigan';
end;

function TContestMichiganQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByMode];
end;

function TContestMichiganQP.GetHostState: string;
begin
   Result := 'MI';
end;

function TContestMichiganQP.GetCountyLineCountiesMax: integer;
begin
   (* Zero, so the derived CountyLineAllowed reads False. *)
   Result := 0;
end;

(* OnePhoneTwoCW: `if Mode = CW then 2 else 1`, so DIGITAL scores the PHONE
   value. Written as three numbers rather than a mode test for that reason --
   see the note on FixedModePoints. *)
procedure TContestMichiganQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

(* ONE SEARCH-AND-POUNCE ENTRY MAY CARRY SEVERAL QTHs, at every station --
   M11 S7, 2026-10-14. It was the session's RSTDomesticQTH shape; see
   TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestMichiganQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := True;
end;

(* MICHIGAN IS NOT A STATE MULTIPLIER FOR A MICHIGAN ENTRANT -- #88
   round 3 (2026-10-26), the sponsor's 2026 rules:
   "For Michigan stations, multipliers are the 83 Michigan counties, 49
   American states (excluding Michigan) + 1 District of Columbia".
   michigan.dom includes the shared S51.DOM, which holds Mi; an
   in-state entrant's QSO whose domestic multiplier is the host state
   itself earns no multiplier and keeps its points. Outside Michigan the
   multipliers are the counties, and none is spelled as the state. The
   shared file is never edited for this: other contests read it. *)
function TContestMichiganQP.CountsAsMultiplier(const aQso: ContestExchange;
                                               aKind: RemainingMultiplierType): boolean;
begin
   Result := not (Station.InHostState and
                  DomesticMultiplierIsHostState(string(aQso.DomMultQTH), HostState));
end;

initialization
   RegisterContest(MICHQSOPARTY, TContestMichiganQP);

end.

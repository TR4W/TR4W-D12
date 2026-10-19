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

(* IN7QPNE -- THE COMBINED INDIANA, 7TH CALL AREA, NEW ENGLAND AND DELAWARE
  QSO PARTIES. A COMPOSITE: EACH QSO IS JUDGED BY ITS PARTY'S OWN CLASS.

  NY4I, 2026-10-13 (CONTEST_OWNERSHIP_DESIGN.md 7.14): IN7QPNE is "a logging
  convenience" for four parties held the same weekend. "When I work a New
  England station, the rules for the New England QSO party apply even though
  I'm working underneath the combined IN7QPNE." So this class holds the four
  component CONTESTS -- Indiana, 7QP, NEQP and Delaware, each its own class --
  and hands each QSO to the one it belongs to. That is composition of whole
  contests, which the ruling asks for. It is NOT a strategy object and NOT a
  registry of rules: nothing here is picked from a shared set, and the
  components are the same classes that run those contests on their own.

  NEW BEHAVIOUR, BY RULING. Until this class, IN7QPNE was classless and scored
  every QSO by one merged rule (PAQSOPointMethod: phone 1, else 2), whoever
  was worked. Design 8.2r records what changed and why.

  ---------------------------------------------------------------------------
  WHICH PARTY JUDGES A QSO (the routing rule, IN7QPNEPartyOfQTH below)

  THE WORKED STATION'S COUNTY, AS THE SESSION'S DOMESTIC TABLE RESOLVED IT --
  aQso.DomesticQTH. The session loads this contest's own files
  (in7qpne_cty.dom out of the four areas, IN7QPNE.dom inside them), and every
  county key in in7qpne_cty.dom says its party by its spelling:
    Indiana       IN + three letters                     INADA
    7QP           AZ ID MT NV OR UT WA WY + three        Azaph
    New England   CT MA ME NH RI VT + three              MEAnd, CTCap
    Delaware      NDE, KDE, SDE                          NDE
  Measured 2026-10-14: all 422 keys route to exactly one party, and no key of
  the states and provinces the in-state file includes (two letters each)
  routes to any. uTestContestIN7QPNE reads the shipped files and holds both.

  WHY THE FILE'S SPELLING AND NOT THE COMPONENTS' OWN COUNTY FILES. The
  session can only ever hold THIS file's keys, so routing reads this file's
  convention. Until Q81 (2026-10-17) New England's own files disagreed with
  it -- neqso.dom spelled a county county-first (AndME) with Connecticut's
  eight old counties; it now carries this file's 68 New England entries
  exactly (state first, MEAnd; the planning regions, CTCap), as the NEQP
  sponsor spells them.

  A QSO WHOSE COUNTY IS IN NO PARTY -- a state, a province, DX, or nothing --
  belongs to the ENTRANT'S own party when the entrant is in one: an in-state
  station works everyone in every one of the four parties. When the entrant
  is in none, it belongs to no party: it is refused when typed (the same
  out-of-state refusal every single-state party makes, design 7.10), and a
  logged one scores 0 and earns no multiplier.

  OVERLAP CANNOT HAPPEN. The four areas share no state, and the key spellings
  above are disjoint, so a county is in one party or none.

  THE ENTRANT'S PARTY is its MY STATE (resolved, design 7.12) routed by the
  same rule, when set-up found it in state (Station.InHostState: MY STATE is a
  key of in7qpne_cty.dom). Each component is then told whether the entrant is
  in ITS host area -- Delaware's points depend on that.

  ---------------------------------------------------------------------------
  WHAT DELEGATES AND WHAT CANNOT (design 8.2r has the table)

    per QSO, to the party   points (ScoreQSO), whether a QSO earns a
                            multiplier (CountsAsMultiplier, with the party's
                            bands), the received exchange
                            (ParseReceivedExchange)
    the composite's own     identity, the one Cabrillo log and the ADIF id,
                            set-up, the New Contest prompts, import, export,
                            the final score, no score posting
    the union of the four   a band question asked with no QSO (UsesBand: the
                            dupe sheet and the need-multiplier hint) --
                            2026-10-16; it credited every band before
    cannot, with today's    the
    seams                   county-line count (asked with a number, no QTH),
                            the session's by-band / by-mode / VHF traits, and
                            WHICH multiplier a QTH counts as (the session's
                            one domestic table)

  ---------------------------------------------------------------------------
  OWNERSHIP OF THE COMPONENTS

  OWNED, ONE SET PER COMPOSITE INSTANCE, made through the registry's class for
  each component contest (ContestClassFor) and freed with this object.

  NOT uContestRegistry.ContestIdentity. Those instances are shared, carry NO
  station by contract, and are read from worker threads. A component must be
  handed a station to score -- Delaware's points read InHostState -- so
  pushing one into a shared identity object would make every reader see it.
  Owned instances keep that state private to this composite. The station is
  pushed per delegation (PartyContest), from this object's own, so a
  component never scores against a stale one. Per-QSO delegation runs on the
  object the engine scores with (uContestFactory.ActiveContest), on the main
  thread. *)
unit uContestIN7QPNE;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   (* THE FOUR PARTIES, in the order the contest's name gives them. *)
   TIN7QPNEParty = (ipIndiana, ipSevenQP, ipNewEngland, ipDelaware);

const
   (* THE CONTEST THAT IS EACH PARTY -- the class registered for it judges
      that party's QSOs. *)
   IN7QPNEPartyContest: array[TIN7QPNEParty] of ContestType =
      (INQSOPARTY, SEVENQP, NEWENGLANDQSO, DELAWAREQSOPARTY);

   (* THE STATES WHOSE COUNTY KEYS BELONG TO EACH PARTY -- the first two
      letters of a five-letter key of in7qpne_cty.dom. Delaware's keys are
      not spelled that way; they are listed whole, below. *)
   IN7QPNEPartyCountyStates: array[TIN7QPNEParty] of string =
      ('IN', 'AZ ID MT NV OR UT WA WY', 'CT MA ME NH RI VT', '');

   (* DELAWARE'S THREE COUNTY KEYS, as in7qpne_cty.dom spells them. *)
   IN7QPNEDelawareCountyKeys = 'NDE KDE SDE';

   (* The four areas, as the out-of-area refusal names them. *)
   IN7QPNEPartyAreas = 'IN, 7th area, NE or DE';

(* WHICH PARTY IS THIS COUNTY KEY IN? True with aParty when it is one of a
  party's counties as in7qpne_cty.dom spells them; False -- with aParty set
  to ipIndiana, meaning nothing -- for a state, a province, 'dx', an empty key
  or anything else. Case and surrounding blanks are ignored: the table hands
  back the key as written ('Azaph'), an operator types 'AZAPH'. *)
function IN7QPNEPartyOfQTH(const aQTH: string; out aParty: TIN7QPNEParty): boolean;

const
   (* THE STATES INSIDE EACH PARTY -- Q104 (NY4I, 2026-10-16). Indiana's,
      the 7th call area's eight, New England's six, Delaware. The first three
      are IN7QPNEPartyCountyStates; Delaware's state is stated here, because
      its county keys do not start with it. *)
   IN7QPNEPartyStates: array[TIN7QPNEParty] of string =
      ('IN', 'AZ ID MT NV OR UT WA WY', 'CT MA ME NH RI VT', 'DE');

(* IS THIS ENTRANT'S MY STATE INSIDE ONE OF THE FOUR PARTIES? -- Q104. True
  with aParty when aMyState is one of IN7QPNEPartyStates, or a county key
  of a party (IN7QPNEPartyOfQTH) -- the New Contest prompt (Q87) still
  invites an in-area station to type its county. Case and blanks ignored.
  False for any other state, a province, DX or nothing. *)
function IN7QPNEPartyOfEntrantState(const aMyState: string;
                                    out aParty: TIN7QPNEParty): boolean;

type
   TContestIN7QPNE = class(TContestBase)
   private
      FParties: array[TIN7QPNEParty] of TContestBase;

      (* The entrant's own party: set-up found it in state, and its MY STATE
         routes to a party. *)
      function EntrantParty(out aParty: TIN7QPNEParty): boolean;

      (* The component for aParty, handed this object's station with
         InHostState saying whether the entrant is in THAT party. *)
      function PartyContest(aParty: TIN7QPNEParty): TContestBase;
   protected
      (* THE WHOLE ContestsArray ROW, STATED HERE -- the M9a rule for
         identity, and Test_MovedRowValuesStillMatchTheArray holds the rest
         to the row. *)
      function GetDisplayName: string; override;
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
      function GetQSOPartyArea: string; override;
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      function GetHostState: string; override;

      (* NO SCORE POSTING -- design 7.14: IN7QPNE is not sent to HamScore or
         the contest scoreboard. *)
      function GetPermittedOperatingAids: TOperatingAids; override;

      (* THE JUDGING PARTY'S OWN ScoreQSO, or 0 for a QSO in no party. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      constructor Create(aContest: TContestHandle); override;
      destructor Destroy; override;

      (* WHICH PARTY JUDGES THIS QSO? -- the routing rule in the header: the
         worked station's county, else the entrant's own party. False when
         neither names one. Public so the tests ask it directly. *)
      function JudgingParty(const aQso: ContestExchange;
                            out aParty: TIN7QPNEParty): boolean;

      (* THE BANDS ANY OF THE FOUR PARTIES CREDITS -- asked with no QSO (the
         dupe sheet, the hint), so it cannot route; it is the UNION, asked
         of the four party classes rather than copied (NY4I, 2026-10-16).
         A QSO still scores and counts only on its JUDGING party's bands:
         ScoreQSO and CountsAsMultiplier ask that party. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* THE JUDGING PARTY'S ANSWER, ON THE JUDGING PARTY'S BANDS. False for a
         QSO in no party. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;

      (* THE JUDGING PARTY'S HOST-AREA ANSWER -- Q107 (2026-10-16). Every
         component states the rule (Indiana and Delaware on the state-party
         base, the 7QP and NEQP their own), so the composite asks the party
         that judges the QSO, handed the station that says whether the
         entrant is in THAT party -- the answer its ScoreQSO and
         ParseReceivedExchange already give. False for a QSO in no party,
         which already scored 0 and earned nothing. *)
      function CreditsWorkedStation(const aQso: ContestExchange): boolean; override;

      (* THE JUDGING PARTY PARSES THE EXCHANGE -- see the implementation. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPT, IN ITS OWN WORDS -- Q87. See the
         implementation. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
      (* AN IN-AREA STATION IS SENT TO ITS OWN PARTY -- Q104. See the
         implementation. *)
      function NewContestValueRefusal(aField: TNewContestField;
                                      const aValue: string): string; override;
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
      (* THE ROVER COUNTY -- see TContestBase.StripsRoverCountyFromCall (M11 S7)
         and SplitsRoverCallOnExport (Q90/Q94). *)
      function StripsRoverCountyFromCall: boolean; override;
      function SplitsRoverCallOnExport: boolean; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
      (* THE WORKED STATION'S ADIF STATE -- see TContestBase.ADIFCountyState
         and ADIFWorkedStationState (Q76/Q89, NY4I 2026-10-16). THE
         COMPOSITE'S OWN, NOT A COMPONENT'S: the session holds
         in7qpne_cty.dom's keys (the components' own files spell theirs the
         same way -- New England's only since Q81, 2026-10-17 -- but this
         file is the one loaded), so the county's state comes from the same
         routing rule that judges the
         QSO (IN7QPNEPartyOfQTH): the key's first two letters, or DE for
         Delaware's NDE/KDE/SDE. No CNTY: WritesADIFCounty stays False. *)
      function ADIFCountyState(const aQso: ContestExchange): string; override;
      function ADIFWorkedStationState(const aQso: ContestExchange): string; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   (* FIRST, so every later unit wins a shared name: ADIFPartyQTHKey and
      ADIFStateOfPartyQSO (Q76/Q89). *)
   uADIF,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   SysUtils,
   uAppStrings,      (* SExchangeOutOfStateWorksHostOnly, SNewContestIN7QPNECountyOrState,
                        SNewContestIN7QPNEInsideAParty *)
   uContestRegistry;

(* True when aWord is one of the blank-separated words of aList. *)
function IsWordOf(const aWord: string; const aList: string): boolean;
begin
   Result := (aWord <> '') and
             (Pos(' ' + aWord + ' ', ' ' + aList + ' ') > 0);
end;

function IN7QPNEPartyOfQTH(const aQTH: string; out aParty: TIN7QPNEParty): boolean;
var
   key: string;
   state: string;
   p: TIN7QPNEParty;
begin
   Result := False;
   aParty := ipIndiana;
   key := UpperCase(Trim(aQTH));

   if (Length(key) = 3) and IsWordOf(key, IN7QPNEDelawareCountyKeys) then
      begin
      aParty := ipDelaware;
      Result := True;
      Exit;
      end;

   if Length(key) <> 5 then
      begin
      Exit;
      end;

   state := Copy(key, 1, 2);
   for p := Low(TIN7QPNEParty) to High(TIN7QPNEParty) do
      begin
      if IsWordOf(state, IN7QPNEPartyCountyStates[p]) then
         begin
         aParty := p;
         Result := True;
         Exit;
         end;
      end;
end;

constructor TContestIN7QPNE.Create(aContest: TContestHandle);
var
   p: TIN7QPNEParty;
   cls: TContestClass;
begin
   inherited Create(aContest);
   for p := Low(TIN7QPNEParty) to High(TIN7QPNEParty) do
      begin
      cls := ContestClassFor(IN7QPNEPartyContest[p]);
      if cls = nil then
         begin
         (* A PROGRAM THAT LINKS THIS UNIT AND NOT A COMPONENT'S. Refused, not
            defaulted: a plain TContestBase would score that party's QSOs 0
            and nothing would say why. The destructor frees what was made. *)
         raise Exception.CreateFmt(
            'IN7QPNE needs the %s class, and none is registered.',
            [ContestId(ContestHandleOf(IN7QPNEPartyContest[p]))]);
         end;
      FParties[p] := cls.Create(ContestHandleOf(IN7QPNEPartyContest[p]));
      end;
end;

destructor TContestIN7QPNE.Destroy;
var
   p: TIN7QPNEParty;
begin
   for p := Low(TIN7QPNEParty) to High(TIN7QPNEParty) do
      begin
      FreeAndNil(FParties[p]);
      end;
   inherited Destroy;
end;

function TContestIN7QPNE.EntrantParty(out aParty: TIN7QPNEParty): boolean;
begin
   aParty := ipIndiana;
   Result := Station.InHostState and
             IN7QPNEPartyOfQTH(Station.MyState, aParty);
end;

function TContestIN7QPNE.PartyContest(aParty: TIN7QPNEParty): TContestBase;
var
   partyStation: TStationContext;
   entrant: TIN7QPNEParty;
begin
   partyStation := Station;
   partyStation.InHostState := EntrantParty(entrant) and (entrant = aParty);
   Result := FParties[aParty];
   Result.SetStation(partyStation);
end;

(* EVERY PARTY'S OWN UsesBand, through the one band seam. A band rule needs
   no station, so the owned components are asked as they stand. Today that
   is 160-10 m without WARC (Indiana, 7QP; New England's 80-10 m is inside
   it) plus Delaware's 6 m and up. *)
function TContestIN7QPNE.UsesBand(aBand: BandType): boolean;
var
   p: TIN7QPNEParty;
begin
   Result := False;
   for p := Low(TIN7QPNEParty) to High(TIN7QPNEParty) do
      begin
      if ContestCreditsBand(FParties[p], aBand) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function TContestIN7QPNE.JudgingParty(const aQso: ContestExchange;
                                      out aParty: TIN7QPNEParty): boolean;
begin
   Result := IN7QPNEPartyOfQTH(string(aQso.DomesticQTH), aParty);
   if not Result then
      begin
      Result := EntrantParty(aParty);
      end;
end;

procedure TContestIN7QPNE.CalculateQSOPoints(var aQso: ContestExchange);
var
   party: TIN7QPNEParty;
begin
   if not JudgingParty(aQso, party) then
      begin
      aQso.QSOPoints := 0;
      Exit;
      end;

   (* THE COMPONENT'S WHOLE ENTRY POINT, not its rule alone: its own band
      check (Delaware's WARC is 0) runs first, as it does when that contest
      runs on its own. The four QSO POINTS overrides it then applies are the
      operator's, the same ones this object's ScoreQSO has already found not
      to match this QSO, so they cannot match there either.

      AND THE QSO'S OWN STATION GOES WITH IT (log schema 3, stage 3): the
      component scores by the same recorded facts this object was handed. *)
   PartyContest(party).ScoreQSO(aQso, ScoringMyFacts);
end;

function TContestIN7QPNE.CountsAsMultiplier(const aQso: ContestExchange;
                                            aKind: RemainingMultiplierType): boolean;
var
   party: TIN7QPNEParty;
   component: TContestBase;
begin
   if not JudgingParty(aQso, party) then
      begin
      Result := False;
      Exit;
      end;

   (* THE PARTY'S BANDS ARE ASKED HERE, AND THAT IS NOT THE BAND RULE
      REPEATED. A contest never restates its OWN bands in this method, because
      SetMultFlags asks UsesBand first. This composite's UsesBand cannot route
      -- it is asked with a band and no QSO -- so it credits the UNION of the
      four parties' bands, and the judging party's own bands can only be
      asked here, through the one function that states the band rule. *)
   component := PartyContest(party);
   Result := ContestCreditsBand(component, aQso.Band) and
             component.CountsAsMultiplier(aQso, aKind);
end;

function TContestIN7QPNE.CreditsWorkedStation(const aQso: ContestExchange): boolean;
var
   party: TIN7QPNEParty;
begin
   if not JudgingParty(aQso, party) then
      begin
      Result := False;
      Exit;
      end;

   Result := PartyContest(party).CreditsWorkedStation(aQso);
end;

(* THE JUDGING PARTY PARSES THE EXCHANGE.

   1. This contest's format parses it (inherited) -- every component's parse
      starts there, and the county it finds is what routes the QSO. A refusal
      here stands exactly as the format left it.
   2. A QSO in no party is refused with the out-of-area reason -- the
      out-of-state rule every single-state party applies (design 7.10). It is
      reached only when the entrant is in no party, and the session's
      exchange accepts a QTH outside the four (an operator's EXCHANGE
      RECEIVED line): out of area, the session's table holds the four
      parties' counties and nothing else, so the shape refuses first.
   3. Otherwise the judging party's own ParseReceivedExchange runs, from the
      record as it arrived, and its answer is the answer -- ITS RULES, IN THIS
      CONTEST'S FORMAT. The party is handed the session with this contest
      named in ExchangeFormatOf (unless a caller already named one), so a
      party whose own format differs (Delaware's RSTDomesticOrDXQTH, the 7QP
      and NEQP at a host station) still parses IN7QPNE's. Until M11 S9d that
      was implicit: the party parsed the session's exchange KIND, which was
      this contest's.

   THE FORMAT RUNS TWICE ON SUCCESS. That is safe because every format's
   parser starts by clearing the county-line queue (LOGSTUFF's
   ClearPendingCounties) and writes the same fields from the same text. *)
function TContestIN7QPNE.ParseReceivedExchange(const aText: string;
                                               const aSession: TReceivedExchangeSession;
                                               var aExch: ContestExchange;
                                               out aErrorMessage: string): boolean;
var
   arrived: ContestExchange;
   party: TIN7QPNEParty;
   partySession: TReceivedExchangeSession;
begin
   arrived := aExch;
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
   if not Result then
      begin
      Exit;
      end;

   if not JudgingParty(aExch, party) then
      begin
      Result := False;
      aErrorMessage := Format(SExchangeOutOfStateWorksHostOnly, [IN7QPNEPartyAreas]);
      Exit;
      end;

   aExch := arrived;
   partySession := aSession;
   if partySession.ExchangeFormatOf = nil then
      begin
      partySession.ExchangeFormatOf := Self;
      end;
   Result := PartyContest(party).ParseReceivedExchange(aText, partySession, aExch, aErrorMessage);
end;

function TContestIN7QPNE.GetDisplayName: string;
begin
   Result := 'Combined Indiana, 7th Call Area, New England and Delaware QSO Party';
end;

function TContestIN7QPNE.GetCabrilloName: string;
begin
   (* ONE COMBINED LOG UNDER THIS NAME, the same file to all four sponsors
      (design 7.14) -- never a component's name. *)
   Result := 'IN7QPNE-QSO-PARTY';
end;

function TContestIN7QPNE.GetADIFContestId: string;
begin
   (* What export has always written and import matches. Kept: nothing says
      otherwise. *)
   Result := 'IN7QPNE-QSO-PARTY';
end;

function TContestIN7QPNE.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestIN7QPNE.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestIN7QPNE.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestIN7QPNE.GetDomesticFileName: string;
begin
   (* The four parties' counties -- the in-state test's file and the file an
      entrant outside the four areas loads. *)
   Result := 'in7qpne_cty';
end;

function TContestIN7QPNE.GetFriendlyName: string;
begin
   Result := 'Combined Indiana, 7th Call Area, New England and Delaware QSO Party';
end;

function TContestIN7QPNE.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestIN7QPNE.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestIN7QPNE.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestIN7QPNE.ParseReceivedExchangeFormat(const aText: string;
                                                     aParsers: TExchangeParsers;
                                                     var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
end;

procedure TContestIN7QPNE.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestIN7QPNE.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestIN7QPNE.GetADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(aMy, aQso);
end;

function TContestIN7QPNE.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestIN7QPNE.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
end;

function TContestIN7QPNE.GetInStateDomesticFileName: string;
begin
   Result := 'in7qpne';
end;

(* THE BASE'S PROMPT NAMES THE AREA TWICE, and this party's area is four
   areas, so it read "in IN7QPNE state ... outside of IN7QPNE". Q87, NY4I
   2026-10-14: the composite class states its own prompt. Same field. *)
procedure TContestIN7QPNE.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(SNewContestIN7QPNECountyOrState, ncfMyState);
end;

function IN7QPNEPartyOfEntrantState(const aMyState: string;
                                    out aParty: TIN7QPNEParty): boolean;
var
   state: string;
   p: TIN7QPNEParty;
begin
   if IN7QPNEPartyOfQTH(aMyState, aParty) then
      begin
      Result := True;
      Exit;
      end;

   Result := False;
   aParty := ipIndiana;
   state := UpperCase(Trim(aMyState));
   if Length(state) <> 2 then
      begin
      Exit;
      end;
   for p := Low(TIN7QPNEParty) to High(TIN7QPNEParty) do
      begin
      if IsWordOf(state, IN7QPNEPartyStates[p]) then
         begin
         aParty := p;
         Result := True;
         Exit;
         end;
      end;
end;

(* IN7QPNE IS FOR STATIONS OUTSIDE ALL FOUR PARTIES -- Q104 (NY4I,
   2026-10-16), from the New England QSO Party's own set-up note: "Stations
   from Indiana, pick IN, from Delaware pick DE, and from the 7th Call Area,
   pick 7QP" -- "Note for 7th area, they would select 7QP and not their
   individual state qso parties like Utah or WA. Same for New England
   picking NEQP." DXLog's IN7QPNEDE.txt says the same: "INQP, 7QP, NEWEQP,
   and DEQP in-state stations should use the respective QP."

   So a MY STATE inside a party is refused, and the message names that
   party's contest by its display name -- the 7QP for all eight 7th-area
   states, never a single state's party. The party is the component this
   object already owns, so the name cannot drift from the class that runs
   it. Every other row, and every other value, is accepted. *)
function TContestIN7QPNE.NewContestValueRefusal(aField: TNewContestField;
                                                const aValue: string): string;
var
   party: TIN7QPNEParty;
begin
   Result := '';
   if aField <> ncfMyState then
      begin
      Exit;
      end;
   if IN7QPNEPartyOfEntrantState(aValue, party) then
      begin
      Result := Format(SNewContestIN7QPNEInsideAParty,
                       [UpperCase(Trim(aValue)), FParties[party].DisplayName]);
      end;
end;

function TContestIN7QPNE.GetQSOPartyArea: string;
begin
   Result := 'IN7QPNE';
end;

function TContestIN7QPNE.GetFlags: TContestFlags;
begin
   (* cfVHFBandsEnabled SINCE 2026-10-16: UsesBand credits Delaware's 6 m and
      up, so band stepping and the band map must reach them (design Q79's
      recommendation). *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestIN7QPNE.GetIsUSQSOParty: boolean;
begin
   (* P: 18 -- set-up runs the party head for it: the in-state test against
      in7qpne_cty, the in-state file IN7QPNE, K/VE/KH6/KL. *)
   Result := True;
end;

function TContestIN7QPNE.GetHostState: string;
begin
   (* NO SINGLE HOST STATE -- the area spans fourteen. ADIF export therefore
      writes no host STATE for an in-area entrant's QSOs. *)
   Result := '';
end;

function TContestIN7QPNE.GetPermittedOperatingAids: TOperatingAids;
begin
   Result := [oaSuperCheckPartial, oaDXCluster];
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestIN7QPNE.UsesDomesticFile: boolean;
begin
   Result := True;
end;

(* A CALL'S /SUFFIX THAT THE DOMESTIC TABLE KNOWS IS A ROVER'S COUNTY, at
   every station, stripped live AND split on ADIF export. M11 S7 transcribed
   the strip from the session's RSTDomesticQTH shape; NY4I's ruling on Q94
   with Q90 (2026-10-14) made both every QSO party's answer: "yes QSO parties
   allow it". Every component party answers True to both, so the composite
   does too; it is asked without a QSO (the export asks the record's
   contest), which is why it states them itself rather than delegating. The
   county-line import bypass is a different rule and stays False (#894). *)
function TContestIN7QPNE.StripsRoverCountyFromCall: boolean;
begin
   Result := True;
end;

function TContestIN7QPNE.SplitsRoverCallOnExport: boolean;
begin
   Result := True;
end;

(* ONE SEARCH-AND-POUNCE ENTRY MAY CARRY SEVERAL QTHs, at every station --
   M11 S7, 2026-10-14. It was the session's RSTDomesticQTH shape; see
   TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestIN7QPNE.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := True;
end;

function TContestIN7QPNE.ADIFCountyState(const aQso: ContestExchange): string;
var
   key: string;
   party: TIN7QPNEParty;
begin
   Result := '';
   key := UpperCase(ADIFPartyQTHKey(aQso));
   if IN7QPNEPartyOfQTH(key, party) then
      begin
      if party = ipDelaware then
         begin
         Result := 'DE';
         end
      else
         begin
         Result := Copy(key, 1, 2);
         end;
      end;
end;

function TContestIN7QPNE.ADIFWorkedStationState(const aQso: ContestExchange): string;
begin
   Result := ADIFStateOfPartyQSO(ADIFCountyState(aQso), aQso);
end;

initialization
   RegisterContest(IN7QPNE, TContestIN7QPNE);

end.

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

(* THE SSB SPRINT -- ITS OWN CONTEST, NOT AN NA SPRINT.

  NY4I, 2026-10-01: "a different contest with a different sponsor so keep it
  separate" (rules: https://ssbsprint.com/rules/). So this class sits on
  TContestBase, not beside or beneath the NCJ's NA Sprint classes, even though
  today it scores, parses and exports exactly as they do. Any resemblance is a
  starting point this class owns (CONTEST_OWNERSHIP_DESIGN.md 1.4).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'naqp';  WA7BNM: 242;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NameQTHInitialExchange;
   DM: DomesticFile;  P: 0;  AE: QSONumberNameDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: OnePointPerQSO;  ADIFName: 'NA-SPRINT-SSB';
   CABName: 'NA-SPRINT-SSB';  FriendlyName: 'North American Sprint, SSB'

  Its enum spelling is SSB-SPRINT; the ADIF and Cabrillo names are stated in
  the row and are NOT the spelling. Its names still say "North American
  Sprint" -- transcribed unchanged; whether they should is a question for
  NY4I, recorded with M3 in the design doc.

  SCORING IS OnePointPerQSO, an arm of the legacy LOGSTUFF scoring
  case (deleted at M10 S3; see git history or the D7 tree):

      OnePointPerQSO: RXData.QSOPoints := 1;

  stated here through the FixedModePoints helper.

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE BASE'S DEFAULT (M4): the
  shared QSONumberNameDomesticOrDXQTHExchange arm, the same one the NA Sprint
  CW class reproduces for itself. postunit's no-op arm that named this
  contest beside the NA Sprints (inventory D6) was deleted at M4. FCONTEST's
  set-up arm is this class's DescribeSession since M7a; uNewContest still
  names it (M9).

  2026-10-16, Q16 (docs/CONTEST_FACTORY_OPEN_QUESTIONS.md): ANSWERED by NY4I
  against the sponsor's rules (https://ssbsprint.com/rules/).
    * The display and friendly name are the sponsor's, "North American SSB
      Sprint" (the row above said "North American Sprint, SSB"). The Cabrillo
      and ADIF name stay NA-SPRINT-SSB: WA7BNM (ref 242) gives that Cabrillo
      name, the ADIF enumeration lists it, and the sponsor names none.
    * The sponsor's rule 10 counts, besides each state and DC (KL7 and KH6
      count as states) and each Canadian province or territory, EACH NORTH
      AMERICAN COUNTRY OTHER THAN W AND VE, by the CQ WW list. The row said
      XM: NoDXMults, so TR4W undercounted. This class now states that DX
      multiplier itself (HasDXMultiplier, DXMultiplierKey) -- the rule the NA
      Sprint CW class states, copied and owned here (design 1.4). Multipliers
      count once per contest, as before: GetFlags states no cfMultByBand. The
      Canadian count (13 by the sponsor, 12 in naqp.dom) is Q88's, not this
      class's. *)
unit uContestSprintSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestSprintSSB = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. Every getter below states
         the ContestsArray row quoted above. *)
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
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier. Q16, 2026-10-16. *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey. Q16. *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uDXMultiplierKey,
   uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

procedure TContestSprintSSB.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestSprintSSB.GetDisplayName: string;
begin
   (* The sponsor's name since Q16, 2026-10-16 (was the row's "North American
      Sprint, SSB"). *)
   Result := 'North American SSB Sprint';
end;

function TContestSprintSSB.GetCabrilloName: string;
begin
   Result := 'NA-SPRINT-SSB';
end;

function TContestSprintSSB.GetADIFContestId: string;
begin
   Result := 'NA-SPRINT-SSB';
end;

function TContestSprintSSB.GetWA7BNMId: integer;
begin
   Result := 242;
end;

function TContestSprintSSB.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestSprintSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestSprintSSB.GetDomesticFileName: string;
begin
   Result := 'naqp';
end;

function TContestSprintSSB.GetFriendlyName: string;
begin
   (* The sponsor's name since Q16, 2026-10-16. *)
   Result := 'North American SSB Sprint';
end;

function TContestSprintSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameQTHInitialExchange;
end;

function TContestSprintSSB.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberNameDomesticOrDXQTHExchange;
end;

function TContestSprintSSB.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsQSONumberNameQTH;
end;

function TContestSprintSSB.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseQSONumberNameDomesticOrDXQTH(aText, aExch);
end;

function TContestSprintSSB.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestSprintSSB.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := ADIFSentQSONumberNameState(aMy, aQso);
end;

function TContestSprintSSB.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentQSONumberNameStateDX(aMy, aQso, aCtx);
end;

function TContestSprintSSB.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedQSONumberNameQTHDX(aMy, aQso, aCtx);
end;

function TContestSprintSSB.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand];
end;

function TContestSprintSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestSprintSSB.DescribeSession(const aStation: TStationContext;
                                            aSession: TSessionDefaults);
begin
   aSession.Band := Band20;

   aSession.CQExchangeCW := '^  \   # ' + aStation.MyName + ' ' + aStation.MyState;
   aSession.QSLCW := 'TU';
   aSession.QuickQSLCW1 := 'EE';
   aSession.QSOBeforeCW := 'B4 \ NA';
   aSession.SPExchangeCW := '@ # ' + aStation.MyName + ' ' + aStation.MyState + '  \ ';
   aSession.RepeatSPExchangeCW := '# ' + aStation.MyName + ' ' + aStation.MyState;
   aSession.CallOkNowCW := '} R';

   aSession.SetCQMemory(CW, smkF1, 'NA \');
   aSession.SetCQMemory(CW, smkF2, 'CQ^NA CQ^NA \ \ NA');
   aSession.SetCQMemory(CW, smkF5, '   ? ');
   aSession.SetCQMemory(CW, smkF6, '   NA \ NA ');
   aSession.SetCQMemory(CW, smkF7, '   CQ^NA \ \ NA ');
   aSession.SetCQMemory(CW, smkF8, '   CQ^NA CQ^NA \ \ NA ');
   (* The arm set Alt-F1 to 'NA \ NA' first and overwrote it with this. *)
   aSession.SetCQMemory(CW, smkAltF1, 'NA \ \ NA');

   aSession.SetExchangeMemory(CW, smkF3, 'NR #');
   aSession.SetExchangeMemory(CW, smkF4, aStation.MyName);
   aSession.SetExchangeMemory(CW, smkF5, aStation.MyState);
   aSession.SetExchangeMemory(CW, smkF6, '@ \ NR^# ' + aStation.MyName + ' ' + aStation.MyState);
   aSession.SetExchangeMemory(CW, smkF7, '   CQ^NA \ \ NA ');
   aSession.SetExchangeMemory(CW, smkF8, '   CQ^NA CQ^NA \ \ NA ');
   aSession.SetExchangeMemory(CW, smkAltF3, 'NR?');
   aSession.SetExchangeMemory(CW, smkAltF4, 'NAME?');
   aSession.SetExchangeMemory(CW, smkAltF5, 'QTH?');

   aSession.SprintQSYRule := True;
   aSession.AddDomesticCountries(DomesticCountriesKVEKH6KL);
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for NASPRINTCW, NASPRINTRTTY.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestSprintSSB.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURQTHANDTHENAME, ncfMyState);
   aPrompts.AskField(ncfMyName);
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestSprintSSB.UsesDomesticFile: boolean;
begin
   Result := True;
end;

(* A DX MULTIPLIER AT EVERY STATION -- the sponsor's rule 10 (Q16,
   2026-10-16). Every entrant counts the same multipliers. *)
function TContestSprintSSB.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY: each North American country other than W and VE,
   by the CQ WW list (rule 10). KL7 and KH6 count as STATES, so neither is a
   country here: IsNorthAmericanDXCountry excludes K, VE and KL by name, and
   KH6 only because CTY.DAT puts Hawaii in Oceania. The sponsor's rule names
   KH6, so this class says so itself rather than leaning on the continent.
   Copied from the NA Sprint CW's rule and owned here (design 1.4). *)
function TContestSprintSSB.DXMultiplierKey(const aQso: ContestExchange;
                                           out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if (IsNorthAmericanDXCountry(aQso.QTH.CountryID, aQso.QTH.Continent)) and
      (aQso.QTH.CountryID <> 'KH6')                                       then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

initialization
   RegisterContest(SPRINTSSB, TContestSprintSSB);

end.

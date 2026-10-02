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

(* THE EU AUTUMN SPRINT, SSB.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 143;  QRZRUID: 216;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NameInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: QSONumberAndNameExchange;
   XM: NoDXMults;  QP: EuropeanSprintQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Eu Autumn Sprint, SSB'

  Blank CABName and ADIFName resolve to the enum's spelling, 'EU-SPRINT-AUTUMN-SSB'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: EuropeanSprintQSOPointMethod -- a European station 1 for every
  contact; anyone else 1 for a European contact, else 0.

  SET-UP: 20 m. LogCfg's defaults: CQ exchange `DE \ #` and MY NAME, and
  the repeat S&P exchange `@` and the same -- the one arm that set a repeat
  S&P default, which is why RepeatSPExchangeDefault exists (M7b).

  A SIBLING, NOT A FAMILY MEMBER (M7b, DECIDED on evidence). The four EU Sprint runnings
  (spring and autumn, CW and SSB) share one arm today, but their rows already
  differ (only the spring CW running has no friendly name).
  Extending NY4I's NRAU-Baltic ruling to every two-mode pair is his open
  Q7, so this class is a COPY of its sibling and owns it (design 1.4).
  Never merge the two, and never extract a base for them. *)
unit uContestEUSprintAutumnSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestEUSprintAutumnSSB = class(TContestBase)
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
      function GetPrefixMultiplierType: PrefixMultType; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDXMultiplierType: DXMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      (* LogCfg's default repeat S&P exchange -- see
         TContestBase.RepeatSPExchangeDefault. *)
      function RepeatSPExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   uTR4WStrings;

procedure TContestEUSprintAutumnSSB.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if Station.MyContinent = Europe then
      begin
      aQso.QSOPoints := 1;
      end
   else if aQso.QTH.Continent = Europe then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 0;
      end;
end;

function TContestEUSprintAutumnSSB.GetDisplayName: string;
begin
   Result := 'Eu Autumn Sprint, SSB';
end;

function TContestEUSprintAutumnSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'EU-SPRINT-AUTUMN-SSB';
end;

function TContestEUSprintAutumnSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'EU-SPRINT-AUTUMN-SSB';
end;

function TContestEUSprintAutumnSSB.GetWA7BNMId: integer;
begin
   Result := 143;
end;

function TContestEUSprintAutumnSSB.GetQRZRUId: integer;
begin
   Result := 216;
end;

function TContestEUSprintAutumnSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestEUSprintAutumnSSB.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestEUSprintAutumnSSB.GetFriendlyName: string;
begin
   Result := 'Eu Autumn Sprint, SSB';
end;

function TContestEUSprintAutumnSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestEUSprintAutumnSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestEUSprintAutumnSSB.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestEUSprintAutumnSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestEUSprintAutumnSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameInitialExchange;
end;

function TContestEUSprintAutumnSSB.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndNameExchange;
end;

function TContestEUSprintAutumnSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := EuropeanSprintQSOPointMethod;
end;

function TContestEUSprintAutumnSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestEUSprintAutumnSSB.DescribeSession(const aStation: TStationContext;
                                                    aSession: TSessionDefaults);
begin
   aSession.Band := Band20;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved at M7b -- see
   TContestBase.CQExchangeDefault. *)
function TContestEUSprintAutumnSSB.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' DE \ # ' + aStation.MyName;
end;

(* The same arm's repeat S&P exchange -- see
   TContestBase.RepeatSPExchangeDefault. *)
function TContestEUSprintAutumnSSB.RepeatSPExchangeDefault(const aStation: TStationContext): string;
begin
   Result := '@' + CQExchangeDefault(aStation);
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for CWOPEN, EUSPRINT_AUTUMN_CW,
   EUSPRINT_SPRING_CW, EUSPRINT_SPRING_SSB, MST.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestEUSprintAutumnSSB.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURNAME, ncfMyName);
end;

initialization
   RegisterContest(EUSPRINT_AUTUMN_SSB, TContestEUSprintAutumnSSB);

end.

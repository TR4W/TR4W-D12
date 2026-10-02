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

(* THE CQ WORLDWIDE VHF CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 73;  QRZRUID: 363;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: GridSquares;  P: 0;  AE: RSTandorGridExchange;
   XM: NoDXMults;  QP: CQVHFQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'CQ Worldwide VHF SSB/CW Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CQ-VHF'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: CQVHFQSOPointMethod -- 2 on 2 m, 1 on 6 m. Any other band keeps
  the 0 ScoreQSO starts from: the arm's `case` had no else.

  SET-UP: 2 m, and the HF bands off. *)
unit uContestCQVHF;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQVHF = class(TContestBase)
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
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   uTR4WStrings;

procedure TContestCQVHF.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Band of
      Band2:
         begin
         aQso.QSOPoints := 2;
         end;
      Band6:
         begin
         aQso.QSOPoints := 1;
         end;
      end;
end;

function TContestCQVHF.GetDisplayName: string;
begin
   Result := 'CQ Worldwide VHF SSB/CW Contest';
end;

function TContestCQVHF.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'CQ-VHF';
end;

function TContestCQVHF.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'CQ-VHF';
end;

function TContestCQVHF.GetWA7BNMId: integer;
begin
   Result := 73;
end;

function TContestCQVHF.GetQRZRUId: integer;
begin
   Result := 363;
end;

function TContestCQVHF.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCQVHF.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestCQVHF.GetFriendlyName: string;
begin
   Result := 'CQ Worldwide VHF SSB/CW Contest';
end;

function TContestCQVHF.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCQVHF.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCQVHF.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestCQVHF.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := GridSquares;
end;

function TContestCQVHF.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCQVHF.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndOrGridExchange;
end;

function TContestCQVHF.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CQVHFQSOPointMethod;
end;

function TContestCQVHF.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestCQVHF.DescribeSession(const aStation: TStationContext;
                                        aSession: TSessionDefaults);
begin
   aSession.Band := Band2;
   aSession.HFEnabled := False;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLDIGI, ARRLVHFJAN, ARRLVHFJUN,
   ARRLVHFSEP, BATAVIA_FT8, CUPRFCW, CUPRFDIG, CUPRFSSB, MAKROTHEN, RTC,
   STEWPERRY, TESLA, WWDIGI.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestCQVHF.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
end;

initialization
   RegisterContest(CQVHF, TContestCQVHF);

end.

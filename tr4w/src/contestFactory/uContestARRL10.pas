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

(* THE ARRL 10-METER CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '10meter@arrl.org';  DF: 'arrl10';  WA7BNM: 199;  QRZRUID: 14;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTDomesticQTHOrQSONumberExchange;
   XM: ARRLDXCCWithNoUSACanadaKH6OrKL7;  QP: ARRL10QSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'ARRL 10-Meter Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'ARRL-10'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: ARRL10QSOPointMethod -- 4 on CW, 2 otherwise.

  SET-UP: 10 m; DXCC without the ARRL-section countries; multiple bands
  off; K, VE, KH6, KL and XE are the domestic countries. *)
unit uContestARRL10;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRL10 = class(TContestBase)
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
   protected
      (* THE CABRILLO HEADER -- M9a. *)
      function GetRequiresCabrilloLocation: boolean; override;
   end;

implementation

uses
   uContestRegistry,
   (* FixedModePoints -- the helper for a number per mode. *)
   uContestFixedPoints,
   uTR4WStrings;

procedure TContestARRL10.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 4, 2, 2);
end;

function TContestARRL10.GetDisplayName: string;
begin
   Result := 'ARRL 10-Meter Contest';
end;

function TContestARRL10.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'ARRL-10';
end;

function TContestARRL10.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'ARRL-10';
end;

function TContestARRL10.GetWA7BNMId: integer;
begin
   Result := 199;
end;

function TContestARRL10.GetQRZRUId: integer;
begin
   Result := 14;
end;

function TContestARRL10.GetSubmissionEmail: string;
begin
   Result := '10meter@arrl.org';
end;

function TContestARRL10.GetDomesticFileName: string;
begin
   Result := 'arrl10';
end;

function TContestARRL10.GetFriendlyName: string;
begin
   Result := 'ARRL 10-Meter Contest';
end;

function TContestARRL10.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestARRL10.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestARRL10.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCCWithNoUSACanadaKH6OrKL7;
end;

function TContestARRL10.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestARRL10.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestARRL10.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestARRL10.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ARRL10QSOPointMethod;
end;

function TContestARRL10.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestARRL10.DescribeSession(const aStation: TStationContext;
                                         aSession: TSessionDefaults);
begin
   aSession.Band := Band10;
   aSession.DXMult := ARRLDXCCWithNoARRLSections;
   aSession.MultipleBands := False;
   aSession.AddDomesticCountries(DomesticCountriesKVEKH6KL);
   aSession.AddDomesticCountry('XE');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRL160, ARRL_RTTY_ROUNDUP,
   CQ160CW, CQ160SSB, CQWWRTTY.
   The same steps on ticking the box stood for ARRL160, ARRLDXCW,
   ARRL_RTTY_ROUNDUP.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestARRL10.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_NORTHAMERICA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERTHEQTHTHATYOUWANTTOSEND, ncfMyState);
end;

(* THE CABRILLO FILE IS NOT STARTED WITHOUT A LOCATION -- PostUnit's guard,
   which named this contest and Winter Field Day, moved here at M9a
   (2026-10-02). Each holds its own copy (design 1.4). *)
function TContestARRL10.GetRequiresCabrilloLocation: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(ARRL10, TContestARRL10);

end.

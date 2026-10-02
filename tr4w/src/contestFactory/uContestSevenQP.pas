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

(* THE 7TH CALL AREA QSO PARTY (7QP).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'seven_cty';  WA7BNM: 404;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 10;  AE: RSTDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: TwoPhoneThreeCW;
   ADIFName: '7QP';  CABName: '';
   FriendlyName: '7th Call Area QSO Party'

  A blank CABName resolves to the enum's spelling, '7QP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  NOT A STATE QSO PARTY, ALTHOUGH ITS ROW SAYS P: 10. It is a MULTI-STATE
  party -- eight states share one exchange -- and TContestStateQSOPartyBase
  assumes ONE host state: its out-of-state refusal (design 7.10) and its
  county-line rule are written for that. So it sits on TContestBase and
  keeps exactly what the program did: the row's P still makes set-up treat
  it as a party (the in-state test against seven_cty, the in-state file
  `seven`, K/VE/KH6/KL), stated here as IsUSQSOParty, and its exchange is
  parsed by the session's shape with no party rule. Whether a multi-state
  party wants a base of its own is a design question recorded in the
  design doc (M7b), not answered here. Its county-line maximum is 4 by the
  sponsor's rule (ADDING_A_CONTEST.md's worksheet) and is NOT enforced --
  nothing enforced it before.

  SCORING: TwoPhoneThreeCW -- 3 on CW, 2 otherwise.

  SET-UP: an in-state station (FoundContest's own in-state answer,
  aStation.InHostState -- the arm asked FoundMyStateInDomFile again, which
  is the same question on the same data) sends RST and its county or DX
  and counts DXCC without W/VE/KH6/KL7, at most 20; everyone else sends RST
  and a county. LogCfg's CQ exchange: 5NN and MY STATE. *)
unit uContestSevenQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestSevenQP = class(TContestBase)
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
   end;

implementation

uses
   uContestRegistry,
   (* FixedModePoints -- the helper for a number per mode. *)
   uContestFixedPoints;

procedure TContestSevenQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 3, 2, 2);
end;

function TContestSevenQP.GetDisplayName: string;
begin
   Result := '7QP';
end;

function TContestSevenQP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := '7QP';
end;

function TContestSevenQP.GetADIFContestId: string;
begin
   Result := '7QP';
end;

function TContestSevenQP.GetWA7BNMId: integer;
begin
   Result := 404;
end;

function TContestSevenQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestSevenQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestSevenQP.GetDomesticFileName: string;
begin
   Result := 'seven_cty';
end;

function TContestSevenQP.GetFriendlyName: string;
begin
   Result := '7th Call Area QSO Party';
end;

function TContestSevenQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestSevenQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestSevenQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestSevenQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestSevenQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestSevenQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestSevenQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TwoPhoneThreeCW;
end;

function TContestSevenQP.GetIsUSQSOParty: boolean;
begin
   (* P: 10 -- the row indexes QSOParties, so set-up treats it as a
      QSO party (the in-state test, both domestic files). See the header for
      why it is nevertheless not on TContestStateQSOPartyBase. *)
   Result := True;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestSevenQP.DescribeSession(const aStation: TStationContext;
                                          aSession: TSessionDefaults);
begin
   if aStation.InHostState then
      begin
      aSession.Exchange := RSTDomesticOrDXQTHExchange;
      aSession.DXMult := ARRLDXCCWithNoUSACanadaKH6OrKL7;
      aSession.DXMultLimit := 20;
      end
   else
      begin
      aSession.Exchange := RSTDomesticQTHExchange;
      end;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved at M7b -- see
   TContestBase.CQExchangeDefault. *)
function TContestSevenQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN ' + aStation.MyState;
end;

initialization
   RegisterContest(SEVENQP, TContestSevenQP);

end.

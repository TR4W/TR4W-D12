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

(* THE NEW ENGLAND QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 10;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: OnePhoneTwoCW;
   ADIFName: '';  CABName: '';
   FriendlyName: 'New England QSO Party'

  Blank CABName and ADIFName resolve to the enum's spelling, 'NEQP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  NOT A STATE QSO PARTY. It is a MULTI-STATE party -- six states -- and its
  row carries no QSOParties index (P: 0), so set-up never ran the party head
  for it, and TContestStateQSOPartyBase's one-host-state rules (the
  out-of-state refusal, the county line) were never applied. It sits on
  TContestBase and keeps exactly that. Whether a multi-state party wants a
  base of its own is a design question recorded in the design doc (M7b),
  not answered here.

  SCORING: OnePhoneTwoCW -- 2 on CW, 1 otherwise.

  SET-UP, both branches stated. A NEW ENGLAND STATION is one whose MY STATE
  begins with ME, NH, VT, MA, CT or RI -- a string comparison of the first
  two characters, D7's rule, as M2 restored it (inventory defect #3: the
  PWORD read never matched, and crashed on an empty MY STATE). It loads
  NEQSOW1, sends RST and its county or DX, and counts DXCC without
  W/VE/KH6/KL7. Everyone else loads NEQSO and sends RST and a county. Both
  count at most 20 DX multipliers, and K, VE, KH6 and KL are domestic. *)
unit uContestNewEnglandQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestNewEnglandQP = class(TContestBase)
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
   private
      (* Does MY STATE begin with one of the six New England states? *)
      class function IsNewEnglandState(const aMyState: string): boolean;
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
   (* FixedModePoints -- the helper for a number per mode. *)
   uContestFixedPoints,
   uTR4WStrings;

procedure TContestNewEnglandQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

class function TContestNewEnglandQP.IsNewEnglandState(const aMyState: string): boolean;
var
   state: string;
begin
   state := Copy(aMyState, 1, 2);
   Result := (state = 'ME') or
             (state = 'NH') or
             (state = 'VT') or
             (state = 'MA') or
             (state = 'CT') or
             (state = 'RI');
end;

function TContestNewEnglandQP.GetDisplayName: string;
begin
   Result := 'New England QSO Party';
end;

function TContestNewEnglandQP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'NEQP';
end;

function TContestNewEnglandQP.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'NEQP';
end;

function TContestNewEnglandQP.GetWA7BNMId: integer;
begin
   Result := 10;
end;

function TContestNewEnglandQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNewEnglandQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestNewEnglandQP.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestNewEnglandQP.GetFriendlyName: string;
begin
   Result := 'New England QSO Party';
end;

function TContestNewEnglandQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestNewEnglandQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestNewEnglandQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestNewEnglandQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestNewEnglandQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNewEnglandQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestNewEnglandQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePhoneTwoCW;
end;

function TContestNewEnglandQP.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestNewEnglandQP.DescribeSession(const aStation: TStationContext;
                                               aSession: TSessionDefaults);
begin
   if IsNewEnglandState(aStation.MyState) then
      begin
      aSession.DomesticFile := 'NEQSOW1';
      aSession.DXMult := ARRLDXCCWithNoUSACanadaKH6OrKL7;
      aSession.Exchange := RSTDomesticOrDXQTHExchange;
      end
   else
      begin
      aSession.DomesticFile := 'NEQSO';
      aSession.Exchange := RSTDomesticQTHExchange;
      end;

   aSession.DXMultLimit := 20;
   aSession.AddDomesticCountries(DomesticCountriesKVEKH6KL);
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestNewEnglandQP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_NEWENGLAND);
   aPrompts.AskFieldWithCommentWhenInside(TC_NEWENGLANDSTATEABREVIATION, ncfMyState);
end;

initialization
   RegisterContest(NEWENGLANDQSO, TContestNewEnglandQP);

end.

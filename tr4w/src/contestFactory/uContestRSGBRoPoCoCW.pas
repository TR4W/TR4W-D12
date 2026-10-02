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

(* THE RSGB ROTATING POSTCODE CONTEST (RoPoCo / RoLo), CW.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 77;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTAndPostalCodeExchange;
   XM: NoDXMults;  QP: TenPointsPerQSO;
   ADIFName: 'RSGB-ROLO';  CABName: 'RSGB-ROLO';
   FriendlyName: 'RSGB RoLo CW'

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: TenPointsPerQSO -- 10 in every mode.

  SET-UP: 80 m, one band, and the CW messages and memories that send RST
  and the postcode -- the arm both runnings shared.

  ONE ADIF ID FOR TWO CONTESTS, TOLD APART BY THE MODE (M7b batch 2,
  DECIDED, design 8.2k). ADIF's CONTEST_ID for the RSGB RoPoCo is
  RSGB-ROLO, the same for both runnings. FindContestByADIFContestId answers
  the CW running for that id, as it always has; once the whole record is
  read the importer asks the contests sharing it which RUNS IN the record's
  mode (TContestBase.RunsInMode, uContestRegistry.ContestOfADIFRecordMode).
  This running is run in CW; a phone record is the SSB running's, and a
  record in a mode neither runs in (digital) stays with the id's answer,
  this one.

  A SIBLING, NOT A FAMILY MEMBER (M7b batch 2, DECIDED on evidence). It and
  RSGB_ROPOCO_SSB (uContestRSGBRoPoCoSSB) share their rules today -- one
  contest in two modes, the NRAU-Baltic shape -- and that is exactly NY4I's
  open Q7 (and Q43). While Q7 is open the brief is siblings, so this class
  is a COPY and owns it (design 1.4). Never merge the two, and never extract
  a base for them. *)
unit uContestRSGBRoPoCoCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRSGBRoPoCoCW = class(TContestBase)
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
      (* WHICH MODE THIS RUNNING IS -- see the header and
         TContestBase.RunsInMode. *)
      function RunsInMode(aMode: ModeType): boolean; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   uContestFixedPoints,
   uTR4WStrings;

(* TenPointsPerQSO -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestRSGBRoPoCoCW.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 10, 10, 10);
end;

function TContestRSGBRoPoCoCW.GetDisplayName: string;
begin
   Result := 'RSGB RoLo CW';
end;

function TContestRSGBRoPoCoCW.GetCabrilloName: string;
begin
   Result := 'RSGB-ROLO';
end;

function TContestRSGBRoPoCoCW.GetADIFContestId: string;
begin
   Result := 'RSGB-ROLO';
end;

function TContestRSGBRoPoCoCW.GetWA7BNMId: integer;
begin
   Result := 77;
end;

function TContestRSGBRoPoCoCW.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestRSGBRoPoCoCW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRSGBRoPoCoCW.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRSGBRoPoCoCW.GetFriendlyName: string;
begin
   Result := 'RSGB RoLo CW';
end;

function TContestRSGBRoPoCoCW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRSGBRoPoCoCW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRSGBRoPoCoCW.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestRSGBRoPoCoCW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestRSGBRoPoCoCW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRSGBRoPoCoCW.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndPostalCodeExchange;
end;

function TContestRSGBRoPoCoCW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TenPointsPerQSO;
end;

function TContestRSGBRoPoCoCW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestRSGBRoPoCoCW.DescribeSession(const aStation: TStationContext;
                                               aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
   aSession.MultipleBands := False;
   aSession.CQExchangeCW := '_~ %5NN (';
   aSession.RepeatSPExchangeCW := '5NN (';
   aSession.SPExchangeCW := '~ %5NN (';
   aSession.SetCQMemory(CW, smkF3, '5NN (');
   aSession.SetExchangeMemory(CW, smkF3, '5NN');
   aSession.SetExchangeMemory(CW, smkF4, '(');
   aSession.SetExchangeMemory(CW, smkF5, '@ DE \ 5NN (');
   aSession.SetExchangeMemory(CW, smkAltF3, 'RST?');
   aSession.SetExchangeMemory(CW, smkAltF4, 'PC?');
end;

(* See the header: the RSGB-ROLO id names both runnings, and the mode
   tells an ADIF record which. *)
function TContestRSGBRoPoCoCW.RunsInMode(aMode: ModeType): boolean;
begin
   Result := aMode = CW;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for RSGB_ROPOCO_SSB.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestRSGBRoPoCoCW.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURPOSTCODE, ncfMyPostalCode);
end;

initialization
   RegisterContest(RSGB_ROPOCO_CW, TContestRSGBRoPoCoCW);

end.

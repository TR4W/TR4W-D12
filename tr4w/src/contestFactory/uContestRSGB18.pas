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

(* THE RSGB 1.8 MHz CONTEST (RSGB-160).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'rsgb';  WA7BNM: 0000;  QRZRUID: 44;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTQSONumberAndPossibleDomesticQTHExchange;
   XM: CQDXCC;  QP: RSGB160Method;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling,
  'RSGB-160'.

  WHY IT HAS A CLASS NOW. It was held classless on purpose from M6 to
  2026-10-14 (design Q33): its points read the multiplier sheet, and design
  7.7 said a contest's per-QSO rule sees only the QSO and the station. NY4I
  ruled (design 7.13) that scoring may ASK the sheet, read-only, whether a
  contact is a new multiplier. The station context carries that question as
  the IsNewMultiplierAnywhere service. A registered class is the contest's
  scorer and final score from the moment it exists, so the whole contest is
  transcribed here: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named
  it, each deleted from the shared code it stood in -- LOGEDIT.TotalScore
  (points times one) and uNewContest.ClasslessPrompts (the prompts).

  SCORING: RSGB160Method -- 7 for a contact that is a new multiplier, 2
  otherwise. "New" is the sheet's ALL-BAND, BOTH-MODE row, as the legacy arm
  asked it, whatever the session's by-band or by-mode keys: a domestic
  multiplier first (only when the QSO carries one), then a DX one.

  THE FINAL SCORE IS THE POINTS. The 7 already pays for the multiplier, so
  the sponsor multiplies by nothing: CombineWithMultipliers is the points
  (QTCs included, as every contest's are). The two cases CombineScore
  decides before asking -- no multiplier counted, the FISTS exchange --
  score the points too, so all three agree with the old "times one". *)
unit uContestRSGB18;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRSGB18 = class(TContestBase)
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
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      (* THE SPONSOR'S FORMULA -- the points alone; see the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- see
         TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   uTR4WStrings;

(* RSGB160Method -- the legacy LOGSTUFF arm for this contest's point
   method (deleted at M10 S3), moved here as it stood (2026-10-14), the sheet asked through
   the station context's read-only service. No service is no sheet: nothing
   is new, so 2. *)
procedure TContestRSGB18.CalculateQSOPoints(var aQso: ContestExchange);
var
   isNew: TNewMultiplierQuery;
begin
   aQso.QSOPoints := 2;
   isNew := Station.IsNewMultiplierAnywhere;
   if not Assigned(isNew) then
      begin
      Exit;
      end;

   if (aQso.DomMultQTH <> '') and isNew(aQso, nmkDomestic) then
      begin
      aQso.QSOPoints := 7;
      end
   else if isNew(aQso, nmkDX) then
      begin
      aQso.QSOPoints := 7;
      end;
end;

(* LOGEDIT.TotalScore's arm for this contest, "points times one", moved
   here (2026-10-14). *)
function TContestRSGB18.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals);
end;

function TContestRSGB18.GetDisplayName: string;
begin
   (* The row has no friendly name; the enum's spelling is the name shown
      (design Q53). *)
   Result := 'RSGB-160';
end;

function TContestRSGB18.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'RSGB-160';
end;

function TContestRSGB18.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'RSGB-160';
end;

function TContestRSGB18.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRSGB18.GetQRZRUId: integer;
begin
   Result := 44;
end;

function TContestRSGB18.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRSGB18.GetDomesticFileName: string;
begin
   Result := 'rsgb';
end;

function TContestRSGB18.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'RSGB-160';
end;

function TContestRSGB18.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRSGB18.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRSGB18.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestRSGB18.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestRSGB18.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRSGB18.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndPossibleDomesticQTHExchange;
end;

function TContestRSGB18.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest.ClasslessPrompts' two
   arms for this contest, moved here as they stood (2026-10-14): the "I am
   in the UK" box on choosing it, and the district in MY STATE on ticking
   it. *)
procedure TContestRSGB18.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_UK);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
end;

initialization
   RegisterContest(RSGB18, TContestRSGB18);

end.

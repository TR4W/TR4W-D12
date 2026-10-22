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
      (* THE SPONSOR'S FORMULA -- the points alone; see the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* 160 m and nothing else -- Q71; see the body. *)
      function UsesBand(aBand: BandType): boolean; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- see
         TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
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
   (* The contest's human name: WA7BNM, accepted (design Q53,
      docs/Q53_CONTEST_NAMES.csv). *)
   Result := 'RSGB 1.8 MHz Contest';
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
   (* WA7BNM's ref, accepted by NY4I with its name (design Q53). *)
   Result := 252;
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
   (* The display name above -- design Q53. *)
   Result := 'RSGB 1.8 MHz Contest';
end;

function TContestRSGB18.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRSGB18.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndPossibleDomesticQTHExchange;
end;

function TContestRSGB18.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestRSGB18.ParseReceivedExchangeFormat(const aText: string;
                                                    aParsers: TExchangeParsers;
                                                    var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTQSONumberAndPossibleDomesticQTH(aText, aExch);
end;

function TContestRSGB18.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestRSGB18.GetADIFSentExchange(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTQSONumberState(aMy, aQso);
end;

function TContestRSGB18.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTQSONumberState(aMy, aQso, aCtx);
end;

function TContestRSGB18.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQSONumberQTH(aMy, aQso, aCtx);
end;

function TContestRSGB18.GetFlags: TContestFlags;
begin
   Result := [cfCountsDomesticCountries];
end;

function TContestRSGB18.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* 160 M AND NOTHING ELSE -- Q71, NY4I 2026-10-15: "a 1.8 MHz contest like
   this (and ARRL-160 or CQ-160) would only allow points for 160." The class
   credited every band, as its row always had. A QSO on any other band is
   logged, scores 0 and earns no multiplier (design 7.4). *)
function TContestRSGB18.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand = Band160;
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

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`CQDXCC`) until the kind was deleted. *)
function TContestRSGB18.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's CQDXCC. *)
function TContestRSGB18.DXMultiplierKey(const aQso: ContestExchange;
                                        out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestRSGB18.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(RSGB18, TContestRSGB18);

end.

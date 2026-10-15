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

(* THE OZ HAM CONTEST RADIO VHF (OZHCR-VHF).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0;  QRZRUID: 203;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: GridSquares;  P: 0;
   AE: RSTQSONumberAndGridSquareExchange;  XM: NoDXMults;  QP: OZHCRVHFQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName resolve to the enum's spelling,
  'OZHCR-VHF'.

  WHY IT HAS A CLASS NOW. M6 (2026-10-02) moved the final score onto the
  contest, and this contest's formula was LogEdit.TotalScore's
  `ActiveQSOPointMethod = OZHCRVHFQSOPointMethod` test -- the session's POINT METHOD, so an
  operator's QSO POINT METHOD line reached it in any contest. A class to hold
  that formula needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, its totals included, which is the proof.

  ITS FINAL SCORE: the points PLUS 1000 for each multiplier, not times --
  LogEdit.TotalScore's OZHCRVHFQSOPointMethod arm, moved at M6.

  SCORING, transcribed from OZHCRVHFQSOPointMethod: the distance in km
  between the two grids, weighted by band. *)
unit uContestOZHCRVHF;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestOZHCRVHF = class(TContestBase)
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
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      (* THE SPONSOR'S FORMULA -- see the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* THE DOMESTIC QTH -- see TContestBase.DomesticMultiplierFromQTH
         (M11 S6). *)
      function DomesticMultiplierFromQTH(const aText: Str20;
                                         var aMultiplier: Str10;
                                         var aQTH: Str10;
                                         var aFound: boolean): TDomesticQTHAnswer; override;
      (* THE NEED-MULTIPLIER HINT -- see
         TContestBase.DomesticMultiplierHint (M11 S6). *)
      function DomesticMultiplierHint(const aText: Str14): string; override;
      (* THE GRID SQUARE -- see TContestBase.HasGridSquareMultiplier
         (M11 S6). *)
      function HasGridSquareMultiplier: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uADIFExchange,
   (* RDADistrictKey, DOKKey, GridSquareKey, GridFieldKey -- the shared
      domestic-QTH shapes (M11 S6). *)
   uDomesticKey,
   uContestRegistry,
   (* GetDistanceBetweenGrids -- the arm's own geodesic; see
      uContestARRLDigi for why it is the TRDOS unit. *)
   LOGGRID,
   uTR4WStrings;

(* OZHCRVHFQSOPointMethod, transcribed. With our grid known, the distance to
   the worked grid (the domestic QTH, as the arm read it) is the points on
   2 m, doubled on 70 cm, four times on 23 cm and six times above; any other
   band, or no grid of ours, scores 0. *)
procedure TContestOZHCRVHF.CalculateQSOPoints(var aQso: ContestExchange);
var
   points: integer;
begin
   if Station.MyGrid <> '' then
      begin
      points := GetDistanceBetweenGrids(Station.MyGrid, string(aQso.DomesticQTH));
      if aQso.Band = Band2 then
         begin
         aQso.QSOPoints := points;
         end;
      if aQso.Band = Band432 then
         begin
         aQso.QSOPoints := points * 2;
         end;
      if aQso.Band = Band1296 then
         begin
         aQso.QSOPoints := points * 4;
         end;
      if aQso.Band > Band1296 then
         begin
         aQso.QSOPoints := points * 6;
         end;
      end;
end;

function TContestOZHCRVHF.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) + 1000 * SummedMultipliers(aTotals);
end;

function TContestOZHCRVHF.GetDisplayName: string;
begin
   Result := 'OZHCR-VHF';
end;

function TContestOZHCRVHF.GetCabrilloName: string;
begin
   (* The row's CABName is blank; the Cabrillo header writes the enum's spelling. *)
   Result := 'OZHCR-VHF';
end;

function TContestOZHCRVHF.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'OZHCR-VHF';
end;

function TContestOZHCRVHF.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestOZHCRVHF.GetQRZRUId: integer;
begin
   Result := 203;
end;

function TContestOZHCRVHF.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestOZHCRVHF.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestOZHCRVHF.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank, which means the enum's spelling. *)
   Result := 'OZHCR-VHF';
end;

function TContestOZHCRVHF.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestOZHCRVHF.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndGridSquareExchange;
end;

function TContestOZHCRVHF.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestOZHCRVHF.GetADIFSentExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTQSONumberGrid(aMy, aQso);
end;

function TContestOZHCRVHF.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfErmakSpecification, cfVHFBandsEnabled];
end;

function TContestOZHCRVHF.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestOZHCRVHF.DescribeSession(const aStation: TStationContext;
                                           aSession: TSessionDefaults);
begin
   aSession.QSONumberByBand := True;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestOZHCRVHF.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN # ' + aStation.MyGrid;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for EUROPEANVHF, RADIOVHFFD.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestOZHCRVHF.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURSIXDIGITGRIDSQUARE, ncfMyGrid);
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   GridSquares arm (the trait): a four- or six-character grid square gives its key; the QTH is the text. Anything
   else is not found, and the domestic file is never consulted. *)
function TContestOZHCRVHF.DomesticMultiplierFromQTH(const aText: Str20;
                                                    var aMultiplier: Str10;
                                                    var aQTH: Str10;
                                                    var aFound: boolean): TDomesticQTHAnswer;
var
   key: ShortString;
begin
   if GridSquareKey(aText, key) then
      begin
      aMultiplier := key;
      aQTH := aText;
      aFound := True;
      end;
   Result := dqaDecided;
end;

(* THE NEED-MULTIPLIER HINT -- M11 S6 part 1, moved from LOGSTUFF.
   DomStringParse's GridSquares arm: the key, or '' for a text that is not one. *)
function TContestOZHCRVHF.DomesticMultiplierHint(const aText: Str14): string;
var
   key: ShortString;
begin
   if GridSquareKey(aText, key) then
      begin
      Result := string(key);
      end
   else
      begin
      Result := '';
      end;
end;

(* THE DOMESTIC MULTIPLIER IS THE GRID SQUARE, A ROVER WORKED AGAIN IN EVERY
   SQUARE -- M11 S6 part 1, moved from the four `= GridSquares` engine
   sites. See TContestBase.HasGridSquareMultiplier. *)
function TContestOZHCRVHF.HasGridSquareMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(OZHCRVHF, TContestOZHCRVHF);

end.

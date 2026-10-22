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

(* THE ARRL JUNE VHF CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 43;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: GridSquares;  P: 0;  AE: RSTandorGridExchange;
   XM: NoDXMults;  QP: ARRLVHFJUNPointMethod;
   ADIFName: 'ARRL-VHF-JUN';  CABName: '';
   FriendlyName: 'ARRL June VHF Contest'

  A blank CABName resolves to the enum's spelling, 'ARRL-VHF-JUN'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: ARRLVHFJUNPointMethod -- 1 on 6 m and 2 m, 2 on 222 and 432, 3
  on 902 and 1296, 4 on every band above; 0 on any other band.

  SET-UP: 6 m, the contest name 'ARRL-VHF-JUN' -- its Cabrillo name (design
  Q41; 'VHF QSO JUNE' until 2026-10-17) -- and the HF bands off.

  A SIBLING, NOT A FAMILY MEMBER (M7b, DECIDED on evidence). The three ARRL VHF runnings are three
  contests of one sponsor on three weekends; they share a point table today,
  but their rows already differ (September's ADIF id is the enum's
  spelling, the other two state their own) and January's set-up has never
  been the other two's.
  Extending NY4I's NRAU-Baltic ruling to every two-mode pair is his open
  Q7, so this class is a COPY of its sibling and owns it (design 1.4).
  Never merge the two, and never extract a base for them. *)
unit uContestARRLVHFJun;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRLVHFJun = class(TContestBase)
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
      function GetReceivesGridSquareExchange: boolean; override;

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
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesGridSquare: boolean; override;
   public
      (* MAY AN EXCHANGE WORD BE A GRID? -- see
         TContestBase.ExchangeTextMayHoldGridSquare (M11 S9e part 1). *)
      function ExchangeTextMayHoldGridSquare: boolean; override;
   public
      (* WHAT THE RECEIVED EXCHANGE REQUIRES -- see
         TContestBase.ParseReceivedExchange and RequireReceivedGrid (Q115). *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
      (* A GRID WORD IS NEVER A CALL -- see TContestBase.MayBeACallsign. *)
      function MayBeACallsign(const aWord: string): boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* RDADistrictKey, DOKKey, GridSquareKey, GridFieldKey -- the shared
      domestic-QTH shapes (M11 S6). *)
   uDomesticKey,
   (* IsGoodLookingGrid -- a grid word is not a call (Q115). *)
   uGridShape,
   uContestRegistry,
   uTR4WStrings;

procedure TContestARRLVHFJun.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Band of
      Band6:
         begin
         aQso.QSOPoints := 1;
         end;
      Band2:
         begin
         aQso.QSOPoints := 1;
         end;
      Band222:
         begin
         aQso.QSOPoints := 2;
         end;
      Band432:
         begin
         aQso.QSOPoints := 2;
         end;
      Band902:
         begin
         aQso.QSOPoints := 3;
         end;
      Band1296:
         begin
         aQso.QSOPoints := 3;
         end;
      Band2304:
         begin
         aQso.QSOPoints := 4;
         end;
      Band3456:
         begin
         aQso.QSOPoints := 4;
         end;
      Band5760:
         begin
         aQso.QSOPoints := 4;
         end;
      Band10G:
         begin
         aQso.QSOPoints := 4;
         end;
      Band24G:
         begin
         aQso.QSOPoints := 4;
         end;
      BandLight:
         begin
         aQso.QSOPoints := 4;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestARRLVHFJun.GetDisplayName: string;
begin
   Result := 'ARRL June VHF Contest';
end;

function TContestARRLVHFJun.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'ARRL-VHF-JUN';
end;

function TContestARRLVHFJun.GetADIFContestId: string;
begin
   Result := 'ARRL-VHF-JUN';
end;

function TContestARRLVHFJun.GetWA7BNMId: integer;
begin
   Result := 43;
end;

function TContestARRLVHFJun.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestARRLVHFJun.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestARRLVHFJun.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestARRLVHFJun.GetFriendlyName: string;
begin
   Result := 'ARRL June VHF Contest';
end;

function TContestARRLVHFJun.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestARRLVHFJun.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndOrGridExchange;
end;

function TContestARRLVHFJun.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestARRLVHFJun.ParseReceivedExchangeFormat(const aText: string;
                                                        aParsers: TExchangeParsers;
                                                        var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTAndOrGrid(aText, aExch);
end;

function TContestARRLVHFJun.ExchangeTextMayHoldGridSquare: boolean;
begin
   Result := True;
end;

(* THE GRID IS REQUIRED, THE SIGNAL REPORT OPTIONAL -- Q115 (NY4I,
   2026-10-18: "The contest class should be stating what is required.").
   The sponsor's rule, ARRL Jan-Jun-Sep VHF Contest Rules v1.2, rule 4: "the
   required exchange consists of: 4.1 4-character Maidenhead grid-square
   locator ... 4.2 A signal report is optional." So a signal report alone is
   refused; a grid alone is taken, the RST defaulting as it always has. A
   word that is neither is the format's refusal (LOGSTUFF's RST-and/or-grid
   parse). *)
function TContestARRLVHFJun.ParseReceivedExchange(const aText: string;
                                                  const aSession: TReceivedExchangeSession;
                                                  var aExch: ContestExchange;
                                                  out aErrorMessage: string): boolean;
begin
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
   Result := RequireReceivedGrid(Result, aExch, aErrorMessage);
end;

(* A WORD THAT IS A GRID SQUARE IS THE GRID -- Q115. Without this a
   six-character grid ('FN31PR') has a call's shape, the call window took it
   as the worked station's call, and '599 FN31PR' logged a QSO with the call
   FN31PR and no grid. *)
function TContestARRLVHFJun.MayBeACallsign(const aWord: string): boolean;
begin
   Result := not IsGoodLookingGrid(aWord);
end;

function TContestARRLVHFJun.ExchangeCarriesGridSquare: boolean;
begin
   Result := True;
end;

function TContestARRLVHFJun.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTGrid(aMy, aQso);
end;

function TContestARRLVHFJun.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTGrid(aMy, aQso, aCtx);
end;

function TContestARRLVHFJun.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTH(aMy, aQso, aCtx);
end;

function TContestARRLVHFJun.GetReceivesGridSquareExchange: boolean;
begin
   Result := True;
end;

function TContestARRLVHFJun.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand, cfVHFBandsEnabled];
end;

function TContestARRLVHFJun.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestARRLVHFJun.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.Band := Band6;
   (* ITS OWN NAME, its Cabrillo name's spelling -- NY4I, design Q41. *)
   aSession.ContestName := 'ARRL-VHF-JUN';
   aSession.HFEnabled := False;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLDIGI, ARRLVHFJAN, ARRLVHFSEP,
   BATAVIA_FT8, CQVHF, CUPRFCW, CUPRFDIG, CUPRFSSB, MAKROTHEN, RTC,
   STEWPERRY, TESLA, WWDIGI.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestARRLVHFJun.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   GridSquares arm (the trait): a four- or six-character grid square gives its key; the QTH is the text. Anything
   else is not found, and the domestic file is never consulted. *)
function TContestARRLVHFJun.DomesticMultiplierFromQTH(const aText: Str20;
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
function TContestARRLVHFJun.DomesticMultiplierHint(const aText: Str14): string;
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
function TContestARRLVHFJun.HasGridSquareMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(ARRLVHFJUN, TContestARRLVHFJun);

end.

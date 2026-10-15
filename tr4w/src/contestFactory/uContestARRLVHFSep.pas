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

(* THE ARRL SEPTEMBER VHF CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 113;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: GridSquares;  P: 0;  AE: RSTandorGridExchange;
   XM: NoDXMults;  QP: ARRLVHFJUNPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'ARRL September VHF Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'ARRL-VHF-SEP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: ARRLVHFJUNPointMethod -- 1 on 6 m and 2 m, 2 on 222 and 432, 3
  on 902 and 1296, 4 on every band above; 0 on any other band.

  SET-UP: 6 m, the contest name 'VHF QSO JUNE' -- the June running's name,
  because the arm named both; transcribed, not judged -- and the HF bands
  off.

  A SIBLING, NOT A FAMILY MEMBER (M7b, DECIDED on evidence). The three ARRL VHF runnings are three
  contests of one sponsor on three weekends; they share a point table today,
  but their rows already differ (September's ADIF id is the enum's
  spelling, the other two state their own) and January's set-up has never
  been the other two's.
  Extending NY4I's NRAU-Baltic ruling to every two-mode pair is his open
  Q7, so this class is a COPY of its sibling and owns it (design 1.4).
  Never merge the two, and never extract a base for them. *)
unit uContestARRLVHFSep;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRLVHFSep = class(TContestBase)
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
   end;

implementation

uses
   uExchangeFields,
   uADIFExchange,
   (* RDADistrictKey, DOKKey, GridSquareKey, GridFieldKey -- the shared
      domestic-QTH shapes (M11 S6). *)
   uDomesticKey,
   uContestRegistry,
   uTR4WStrings;

procedure TContestARRLVHFSep.CalculateQSOPoints(var aQso: ContestExchange);
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

function TContestARRLVHFSep.GetDisplayName: string;
begin
   Result := 'ARRL September VHF Contest';
end;

function TContestARRLVHFSep.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'ARRL-VHF-SEP';
end;

function TContestARRLVHFSep.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'ARRL-VHF-SEP';
end;

function TContestARRLVHFSep.GetWA7BNMId: integer;
begin
   Result := 113;
end;

function TContestARRLVHFSep.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestARRLVHFSep.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestARRLVHFSep.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestARRLVHFSep.GetFriendlyName: string;
begin
   Result := 'ARRL September VHF Contest';
end;

function TContestARRLVHFSep.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestARRLVHFSep.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndOrGridExchange;
end;

function TContestARRLVHFSep.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestARRLVHFSep.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTGrid(aMy, aQso);
end;

function TContestARRLVHFSep.GetReceivesGridSquareExchange: boolean;
begin
   Result := True;
end;

function TContestARRLVHFSep.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand, cfVHFBandsEnabled];
end;

function TContestARRLVHFSep.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestARRLVHFSep.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.Band := Band6;
   aSession.ContestName := 'VHF QSO JUNE';
   aSession.HFEnabled := False;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLDIGI, ARRLVHFJAN, ARRLVHFJUN,
   BATAVIA_FT8, CQVHF, CUPRFCW, CUPRFDIG, CUPRFSSB, MAKROTHEN, RTC,
   STEWPERRY, TESLA, WWDIGI.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestARRLVHFSep.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   GridSquares arm (the trait): a four- or six-character grid square gives its key; the QTH is the text. Anything
   else is not found, and the domestic file is never consulted. *)
function TContestARRLVHFSep.DomesticMultiplierFromQTH(const aText: Str20;
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
function TContestARRLVHFSep.DomesticMultiplierHint(const aText: Str14): string;
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
function TContestARRLVHFSep.HasGridSquareMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(ARRLVHFSEP, TContestARRLVHFSep);

end.

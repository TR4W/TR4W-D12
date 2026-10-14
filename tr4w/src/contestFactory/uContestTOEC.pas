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

(* THE TOEC WW GRID CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 163;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: GridFields;  P: 0;  AE: RSTDomesticQTHExchange;
   XM: NoDXMults;  QP: TOECQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'TOEC'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: TOECQSOPointMethod -- 3 off our continent or for a mobile
  (a call containing /M), 1 otherwise.

  SET-UP: nothing -- no FoundContest or LogCfg arm named it. *)
unit uContestTOEC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestTOEC = class(TContestBase)
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
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
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
      (* THE GRID FIELD -- see TContestBase.HasGridFieldMultiplier
         (M11 S6). *)
      function HasGridFieldMultiplier: boolean; override;
   end;

implementation

uses
   (* RDADistrictKey, DOKKey, GridSquareKey, GridFieldKey -- the shared
      domestic-QTH shapes (M11 S6). *)
   uDomesticKey,
   uContestRegistry,
   utils_text;

(* TOECQSOPointMethod -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2). The arm
   was deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestTOEC.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else if StringHas(aQso.Callsign, '/M') then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestTOEC.GetDisplayName: string;
begin
   Result := 'TOEC';
end;

function TContestTOEC.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'TOEC';
end;

function TContestTOEC.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'TOEC';
end;

function TContestTOEC.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestTOEC.GetQRZRUId: integer;
begin
   Result := 163;
end;

function TContestTOEC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestTOEC.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestTOEC.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'TOEC';
end;

function TContestTOEC.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := GridFields;
end;

function TContestTOEC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestTOEC.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestTOEC.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand];
end;

function TContestTOEC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   GridFields arm (the trait): a four-character grid square gives its key; the QTH is the text. Anything
   else is not found, and the domestic file is never consulted. *)
function TContestTOEC.DomesticMultiplierFromQTH(const aText: Str20;
                                                var aMultiplier: Str10;
                                                var aQTH: Str10;
                                                var aFound: boolean): TDomesticQTHAnswer;
var
   key: ShortString;
begin
   if GridFieldKey(aText, key) then
      begin
      aMultiplier := key;
      aQTH := aText;
      aFound := True;
      end;
   Result := dqaDecided;
end;

(* THE NEED-MULTIPLIER HINT -- M11 S6 part 1, moved from LOGSTUFF.
   DomStringParse's GridFields arm: the key, or '' for a text that is not one. *)
function TContestTOEC.DomesticMultiplierHint(const aText: Str14): string;
var
   key: ShortString;
begin
   if GridFieldKey(aText, key) then
      begin
      Result := string(key);
      end
   else
      begin
      Result := '';
      end;
end;

(* THE DOMESTIC MULTIPLIER IS THE GRID FIELD -- M11 S6 part 1, moved from
   uMults.IsDmMult's and uWSJTX's `= GridFields`. See
   TContestBase.HasGridFieldMultiplier. *)
function TContestTOEC.HasGridFieldMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(TOEC, TContestTOEC);

end.

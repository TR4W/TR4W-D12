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

(* THE WWL CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: GridFields;  P: 0;  AE: RSTAndGridExchange;
   XM: NoDXMults;  QP: WWLQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'WWL'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: WWLQSOPointMethod -- with MY GRID and the received grid: one
  point per 500 km begun, doubled on 80 m and quadrupled on 160 m; without
  both grids, 1.

  SET-UP: nothing -- no FoundContest or LogCfg arm named it.

  DESIGN Q37 REACHES THIS CONTEST. LOGGRID.GetDistanceBetweenGrids pads a
  grid that is not six characters with 'LL', and ConvertGridToLatLon reads
  four characters of it: a grid shorter than four is read past its end, and
  such a QSO's points follow the heap. Q37 is open; the grid handling is
  transcribed untouched. Only a received grid
  that is non-empty and shorter than four characters reaches it. *)
unit uContestWWL;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWWL = class(TContestBase)
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
   uExchangeFields,
   uADIFExchange,
   (* RDADistrictKey, DOKKey, GridSquareKey, GridFieldKey -- the shared
      domestic-QTH shapes (M11 S6). *)
   uDomesticKey,
   uContestRegistry,
   LOGGRID;

(* WWLQSOPointMethod -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2). The arm
   was deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestWWL.CalculateQSOPoints(var aQso: ContestExchange);
var
   distance: longint;
begin
   if (Station.MyGrid <> '') and (aQso.DomesticQTH <> '') then
      begin
      distance := GetDistanceBetweenGrids(Station.MyGrid, aQso.DomesticQTH);
      aQso.QSOPoints := (distance div 500) + 1;

      if (aQso.Band = Band80) or (aQso.Band = Band160) then
         begin
         aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
         end;

      if aQso.Band = Band160 then
         begin
         aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
         end;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestWWL.GetDisplayName: string;
begin
   Result := 'WWL';
end;

function TContestWWL.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'WWL';
end;

function TContestWWL.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'WWL';
end;

function TContestWWL.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestWWL.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWWL.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestWWL.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestWWL.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'WWL';
end;

function TContestWWL.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestWWL.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndGridExchange;
end;

function TContestWWL.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestWWL.GetADIFSentExchange(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange): string;
begin
   Result := ADIFSentNotImplemented(aMy, aQso);
end;

function TContestWWL.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestWWL.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   GridFields arm (the trait): a four-character grid square gives its key; the QTH is the text. Anything
   else is not found, and the domestic file is never consulted. *)
function TContestWWL.DomesticMultiplierFromQTH(const aText: Str20;
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
function TContestWWL.DomesticMultiplierHint(const aText: Str14): string;
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
function TContestWWL.HasGridFieldMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(WWL, TContestWWL);

end.

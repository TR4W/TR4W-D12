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

(* THE RUSSIAN ASIAN CHAMPIONSHIP, CW (AS-CHAMP).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 64;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: QSONumberAndCoordinatesSum;
   XM: NoDXMults;  QP: ChampionshipRFASMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'AS-CHAMP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: ChampionshipRFASMethod -- when MY STATE is all digits and both
  it and the received QTH are given: the QTH's first digit and next two are
  a coordinate pair, and the points are 5 plus the two differences from
  ours, 5 more on CW. Otherwise 0.

  SET-UP: nothing; FoundContest's arm for it was empty. LogCfg's CQ
  exchange: MY STATE and the serial. *)
unit uContestRFASChampionshipCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRFASChampionshipCW = class(TContestBase)
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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   uContestRegistry,
   SysUtils,
   utils_text;

(* ChampionshipRFASMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestRFASChampionshipCW.CalculateQSOPoints(var aQso: ContestExchange);
var
   la1, la2, lo1, lo2: integer;
begin
   if (Station.MyState <> '') and (aQso.QTHString <> '') then
      begin
      if StringIsAllNumbers(Station.MyState) then
         begin
         la1 := StrToIntDef(aQso.QTHString[1], 0);
         lo1 := StrToIntDef(Copy(aQso.QTHString, 2, 2), 0);

         la2 := StrToIntDef(UTF8Encode(Station.MyState[1]), 0);
         lo2 := StrToIntDef(UTF8Encode(Copy(Station.MyState, 2, 2)), 0);
         aQso.QSOPoints := Abs(la1 - la2) + Abs(lo1 - lo2) + 5;
         if aQso.Mode = CW then
            begin
            aQso.QSOPoints := aQso.QSOPoints + 5;
            end;
         end;
      end;
end;

function TContestRFASChampionshipCW.GetDisplayName: string;
begin
   Result := 'AS-CHAMP';
end;

function TContestRFASChampionshipCW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'AS-CHAMP';
end;

function TContestRFASChampionshipCW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'AS-CHAMP';
end;

function TContestRFASChampionshipCW.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRFASChampionshipCW.GetQRZRUId: integer;
begin
   Result := 64;
end;

function TContestRFASChampionshipCW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRFASChampionshipCW.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRFASChampionshipCW.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'AS-CHAMP';
end;

function TContestRFASChampionshipCW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRFASChampionshipCW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRFASChampionshipCW.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestRFASChampionshipCW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestRFASChampionshipCW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRFASChampionshipCW.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndCoordinatesSum;
end;

function TContestRFASChampionshipCW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ChampionshipRFASMethod;
end;

function TContestRFASChampionshipCW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (M7b batch 2). See TContestBase.CQExchangeDefault. *)
function TContestRFASChampionshipCW.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + aStation.MyState + '#';
end;

initialization
   RegisterContest(RFASCHAMPIONSHIPCW, TContestRFASChampionshipCW);

end.

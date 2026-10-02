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

(* THE IARU REGION 1 FIELD DAY, RCC RULES, CW.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 358;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberExchange;
   XM: CQDXCC;  QP: RegionOneFieldDayRCCQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'REGION 1 FIELD DAY-RCC-CW'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: RegionOneFieldDayRCCQSOPointMethod -- 2 on our continent, 3 off
  it; 4 for a station signing /P or /M (the suffix found at the call's last
  two characters).

  SET-UP: nothing -- no FoundContest or LogCfg arm named it.

  A SIBLING, NOT A FAMILY MEMBER (M7b batch 2, DECIDED on evidence). It and
  REGION1FIELDDAY_RCC_SSB (uContestRegion1FieldDayRCCSSB) share their rules
  today -- one contest in two modes, the NRAU-Baltic shape -- and that is
  exactly NY4I's open Q7 (and Q43). While Q7 is open the brief is siblings,
  so this class is a COPY and owns it (design 1.4). Never merge the two, and
  never extract a base for them.

  NOT A REGION 1 FIELD DAY FAMILY EITHER: the plain Region 1 Field Day
  (uContestRegion1FieldDay) scores by another arm, its society tables. *)
unit uContestRegion1FieldDayRCCCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRegion1FieldDayRCCCW = class(TContestBase)
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
   end;

implementation

uses
   uContestRegistry;

(* RegionOneFieldDayRCCQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestRegion1FieldDayRCCCW.CalculateQSOPoints(var aQso: ContestExchange);
var
   suffixAt: integer;
begin
   if Station.MyContinent = aQso.QTH.Continent then
      begin
      aQso.QSOPoints := 2;
      end
   else
      begin
      aQso.QSOPoints := 3;
      end;
   suffixAt := Pos('/P', aQso.Callsign);
   if suffixAt = 0 then
      begin
      suffixAt := Pos('/M', aQso.Callsign);
      end;
   if suffixAt = Length(aQso.Callsign) - 1 then
      begin
      aQso.QSOPoints := 4;
      end;
end;

function TContestRegion1FieldDayRCCCW.GetDisplayName: string;
begin
   Result := 'REGION 1 FIELD DAY-RCC-CW';
end;

function TContestRegion1FieldDayRCCCW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'REGION 1 FIELD DAY-RCC-CW';
end;

function TContestRegion1FieldDayRCCCW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'REGION 1 FIELD DAY-RCC-CW';
end;

function TContestRegion1FieldDayRCCCW.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRegion1FieldDayRCCCW.GetQRZRUId: integer;
begin
   Result := 358;
end;

function TContestRegion1FieldDayRCCCW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRegion1FieldDayRCCCW.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRegion1FieldDayRCCCW.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'REGION 1 FIELD DAY-RCC-CW';
end;

function TContestRegion1FieldDayRCCCW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRegion1FieldDayRCCCW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRegion1FieldDayRCCCW.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestRegion1FieldDayRCCCW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestRegion1FieldDayRCCCW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRegion1FieldDayRCCCW.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestRegion1FieldDayRCCCW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := RegionOneFieldDayRCCQSOPointMethod;
end;

function TContestRegion1FieldDayRCCCW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(REGION1FIELDDAY_RCC_CW, TContestRegion1FieldDayRCCCW);

end.

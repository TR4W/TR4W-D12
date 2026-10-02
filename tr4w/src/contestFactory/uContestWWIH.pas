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

(* THE WORLD WIDE IRON HAM CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 552;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: CQZones;  AIE: ZoneInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;
   XM: CQDXCC;  QP: CQWWRTTYQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'World Wide Iron Ham Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'WWIH'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: CQWWRTTYQSOPointMethod -- another continent 3, another country
  2, our own 1.

  SET-UP: nothing -- no FoundContest or LogCfg arm named it.

  NOT A MEMBER OF ANY CQ WW FAMILY: it scores by the CQ WW RTTY arm, which
  TContestCQWWRTTY owns (batch 1) for another sponsor. The arm is COPIED
  here and owned (design 1.4). *)
unit uContestWWIH;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWWIH = class(TContestBase)
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

(* CQWWRTTYQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestWWIH.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 2;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestWWIH.GetDisplayName: string;
begin
   Result := 'WWIH';
end;

function TContestWWIH.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'WWIH';
end;

function TContestWWIH.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'WWIH';
end;

function TContestWWIH.GetWA7BNMId: integer;
begin
   Result := 552;
end;

function TContestWWIH.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWWIH.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestWWIH.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestWWIH.GetFriendlyName: string;
begin
   Result := 'World Wide Iron Ham Contest';
end;

function TContestWWIH.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestWWIH.GetZoneMultiplierType: ZoneMultType;
begin
   Result := CQZones;
end;

function TContestWWIH.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestWWIH.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestWWIH.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestWWIH.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestWWIH.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CQWWRTTYQSOPointMethod;
end;

function TContestWWIH.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(WWIH, TContestWWIH);

end.

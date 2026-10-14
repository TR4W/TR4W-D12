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

(* THE IARU REGION 1 FIELD DAY, RCC RULES, SSB.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 358;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberExchange;
   XM: CQDXCC;  QP: RegionOneFieldDayRCCQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'REGION 1 FIELD DAY-RCC-SSB'.

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
  REGION1FIELDDAY_RCC_CW (uContestRegion1FieldDayRCCCW) share their rules
  today -- one contest in two modes, the NRAU-Baltic shape -- and that is
  exactly NY4I's open Q7 (and Q43). While Q7 is open the brief is siblings,
  so this class is a COPY and owns it (design 1.4). Never merge the two, and
  never extract a base for them.

  NOT A REGION 1 FIELD DAY FAMILY EITHER: the plain Region 1 Field Day
  (uContestRegion1FieldDay) scores by another arm, its society tables. *)
unit uContestRegion1FieldDayRCCSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRegion1FieldDayRCCSSB = class(TContestBase)
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
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   end;

implementation

uses
   uContestRegistry;

(* RegionOneFieldDayRCCQSOPointMethod -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2). The arm
   was deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestRegion1FieldDayRCCSSB.CalculateQSOPoints(var aQso: ContestExchange);
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

function TContestRegion1FieldDayRCCSSB.GetDisplayName: string;
begin
   Result := 'REGION 1 FIELD DAY-RCC-SSB';
end;

function TContestRegion1FieldDayRCCSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'REGION 1 FIELD DAY-RCC-SSB';
end;

function TContestRegion1FieldDayRCCSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'REGION 1 FIELD DAY-RCC-SSB';
end;

function TContestRegion1FieldDayRCCSSB.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRegion1FieldDayRCCSSB.GetQRZRUId: integer;
begin
   Result := 358;
end;

function TContestRegion1FieldDayRCCSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRegion1FieldDayRCCSSB.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRegion1FieldDayRCCSSB.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'REGION 1 FIELD DAY-RCC-SSB';
end;

function TContestRegion1FieldDayRCCSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestRegion1FieldDayRCCSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRegion1FieldDayRCCSSB.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestRegion1FieldDayRCCSSB.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand];
end;

function TContestRegion1FieldDayRCCSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`CQDXCC`) until the kind was deleted. *)
function TContestRegion1FieldDayRCCSSB.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's CQDXCC. *)
function TContestRegion1FieldDayRCCSSB.DXMultiplierKey(const aQso: ContestExchange;
                                                       out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;

initialization
   RegisterContest(REGION1FIELDDAY_RCC_SSB, TContestRegion1FieldDayRCCSSB);

end.

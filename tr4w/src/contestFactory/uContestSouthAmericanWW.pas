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

(* THE SOUTH AMERICAN WW CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTAndContinentExchange;
   XM: NoDXMults;  QP: SouthAmericanWWQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'SOUTH AMERICAN WW'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: SouthAmericanWWQSOPointMethod -- a South American station: 2 in
  South America, 10 outside it; anyone else: 10 for South America, 2
  otherwise.

  SET-UP, both branches stated (the arm stated both): a South American
  station counts non-South-American prefixes, anyone else South American
  ones. *)
unit uContestSouthAmericanWW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestSouthAmericanWW = class(TContestBase)
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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uContestRegistry;

(* SouthAmericanWWQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestSouthAmericanWW.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if Station.MyContinent = SouthAmerica then
      begin
      if aQso.QTH.Continent = SouthAmerica then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 10;
         end;
      end
   else if aQso.QTH.Continent = SouthAmerica then
      begin
      aQso.QSOPoints := 10;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

function TContestSouthAmericanWW.GetDisplayName: string;
begin
   Result := 'SOUTH AMERICAN WW';
end;

function TContestSouthAmericanWW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'SOUTH AMERICAN WW';
end;

function TContestSouthAmericanWW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'SOUTH AMERICAN WW';
end;

function TContestSouthAmericanWW.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestSouthAmericanWW.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestSouthAmericanWW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestSouthAmericanWW.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestSouthAmericanWW.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'SOUTH AMERICAN WW';
end;

function TContestSouthAmericanWW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestSouthAmericanWW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestSouthAmericanWW.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestSouthAmericanWW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestSouthAmericanWW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestSouthAmericanWW.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndContinentExchange;
end;

function TContestSouthAmericanWW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := SouthAmericanWWQSOPointMethod;
end;

function TContestSouthAmericanWW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestSouthAmericanWW.DescribeSession(const aStation: TStationContext;
                                                  aSession: TSessionDefaults);
begin
   if aStation.MyContinent = SouthAmerica then
      begin
      aSession.PrefixMult := NonSouthAmericanPrefixes;
      end
   else
      begin
      aSession.PrefixMult := SouthAmericanPrefixes;
      end;
end;

initialization
   RegisterContest(SOUTHAMERICANWW, TContestSouthAmericanWW);

end.

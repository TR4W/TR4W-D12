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

(* THE BALTIC CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 28;  QRZRUID: 161;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberExchange;
   XM: NoDXMults;  QP: BalticQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Baltic Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'BALTIC'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: BalticQSOPointMethod. A Baltic station (ES, YL, LY): Europe 1,
  elsewhere 2. Anyone else working a Baltic station: 10 from Europe, 20
  from elsewhere; any other contact 1.

  SET-UP: 80 m. *)
unit uContestBaltic;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestBaltic = class(TContestBase)
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

procedure TContestBaltic.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if (Station.MyCountry = 'ES') or
      (Station.MyCountry = 'YL') or
      (Station.MyCountry = 'LY') then
      begin
      if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else if (rxCty = 'ES') or
           (rxCty = 'YL') or
           (rxCty = 'LY') then
      begin
      if Station.MyContinent = Europe then
         begin
         aQso.QSOPoints := 10;
         end
      else
         begin
         aQso.QSOPoints := 20;
         end;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestBaltic.GetDisplayName: string;
begin
   Result := 'Baltic Contest';
end;

function TContestBaltic.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'BALTIC';
end;

function TContestBaltic.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'BALTIC';
end;

function TContestBaltic.GetWA7BNMId: integer;
begin
   Result := 28;
end;

function TContestBaltic.GetQRZRUId: integer;
begin
   Result := 161;
end;

function TContestBaltic.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestBaltic.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestBaltic.GetFriendlyName: string;
begin
   Result := 'Baltic Contest';
end;

function TContestBaltic.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestBaltic.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestBaltic.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestBaltic.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestBaltic.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestBaltic.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestBaltic.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := BalticQSOPointMethod;
end;

function TContestBaltic.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestBaltic.DescribeSession(const aStation: TStationContext;
                                         aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
end;

initialization
   RegisterContest(BALTIC, TContestBaltic);

end.

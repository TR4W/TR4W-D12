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

(* THE TEN-TEN ON AIR ACTIVITIES.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: NameQTHAndPossibleTenTenNumber;
   XM: NoDXMults;  QP: TenTenQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Ten-Ten On Air Activities'

  Blank CABName and ADIFName resolve to the enum's spelling, 'TEN TEN'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: TenTenQSOPointMethod -- 2, for every QSO. The arm reads "2 for a
  station that sent a Ten-Ten number, 1 otherwise", written as
  `TenTenNum <> -1`; TenTenNum is a Word, so that is never false (FPC:
  "Comparison might be always true"), and every QSO has scored 2. "No
  number" is MAXWORD, $FFFF, which the test never reached. Transcribed as
  what it does, without the comparison the compiler proves dead; what the
  rule should be is design Q46.

  SET-UP: K, VE, KH6 and KL as domestic countries.

  THE 'TENTEN' IN LOGSCP, LOGWIND AND LOGEDIT IS NOT THIS CONTEST: it is
  TRMASTER's Ten-Ten number field, and stays where it is. *)
unit uContestTenTen;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestTenTen = class(TContestBase)
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

(* TenTenQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestTenTen.CalculateQSOPoints(var aQso: ContestExchange);
begin
   (* `if TenTenNum <> -1 then 2 else 1`, on a Word: always 2 -- see the
      header and design Q46. *)
   aQso.QSOPoints := 2;
end;

function TContestTenTen.GetDisplayName: string;
begin
   Result := 'TEN TEN';
end;

function TContestTenTen.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'TEN TEN';
end;

function TContestTenTen.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'TEN TEN';
end;

function TContestTenTen.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestTenTen.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestTenTen.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestTenTen.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestTenTen.GetFriendlyName: string;
begin
   Result := 'Ten-Ten On Air Activities';
end;

function TContestTenTen.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestTenTen.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestTenTen.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestTenTen.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestTenTen.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestTenTen.GetExchangeKind: ExchangeType;
begin
   Result := NameQTHAndPossibleTenTenNumber;
end;

function TContestTenTen.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TenTenQSOPointMethod;
end;

function TContestTenTen.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestTenTen.DescribeSession(const aStation: TStationContext;
                                         aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesKVEKH6KL);
end;

initialization
   RegisterContest(TENTEN, TContestTenTen);

end.

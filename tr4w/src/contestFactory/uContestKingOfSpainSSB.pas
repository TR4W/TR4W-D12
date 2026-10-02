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

(* HIS MAJESTY THE KING OF SPAIN CONTEST, SSB.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'ea';  WA7BNM: 59;  QRZRUID: 308;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTDomesticQTHOrQSONumberExchange;
   XM: CQDXCC;  QP: KingOfSpainQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'His Maj. King of Spain Contest, SSB'

  Blank CABName and ADIFName resolve to the enum's spelling, 'KING-OF-SPAIN-SSB'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: KingOfSpainQSOPointMethod -- a non-Spanish station 1; a Spanish
  one 2 when we are Spanish, 3 when we are not
  (uCallSignRoutines.SpanishStation).

  SET-UP: EA, EA6, EA8 and EA9 as domestic countries -- the arm both
  runnings shared.

  A SIBLING, NOT A FAMILY MEMBER (M7b batch 2, DECIDED on evidence). It and
  KINGOFSPAINCW (uContestKingOfSpainCW) share their rules today -- one
  contest in two modes, the NRAU-Baltic shape -- and that is exactly NY4I's
  open Q7 (and Q43). While Q7 is open the brief is siblings, so this class
  is a COPY and owns it (design 1.4). Never merge the two, and never extract
  a base for them. *)
unit uContestKingOfSpainSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestKingOfSpainSSB = class(TContestBase)
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
   uContestRegistry,
   uCallSignRoutines;

(* KingOfSpainQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestKingOfSpainSSB.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if not SpanishStation(rxCty) then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      if SpanishStation(Station.MyCountry) then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 3;
         end;
      end;
end;

function TContestKingOfSpainSSB.GetDisplayName: string;
begin
   Result := 'KING-OF-SPAIN-SSB';
end;

function TContestKingOfSpainSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'KING-OF-SPAIN-SSB';
end;

function TContestKingOfSpainSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'KING-OF-SPAIN-SSB';
end;

function TContestKingOfSpainSSB.GetWA7BNMId: integer;
begin
   Result := 59;
end;

function TContestKingOfSpainSSB.GetQRZRUId: integer;
begin
   Result := 308;
end;

function TContestKingOfSpainSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestKingOfSpainSSB.GetDomesticFileName: string;
begin
   Result := 'ea';
end;

function TContestKingOfSpainSSB.GetFriendlyName: string;
begin
   Result := 'His Maj. King of Spain Contest, SSB';
end;

function TContestKingOfSpainSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestKingOfSpainSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestKingOfSpainSSB.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestKingOfSpainSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestKingOfSpainSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestKingOfSpainSSB.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestKingOfSpainSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := KingOfSpainQSOPointMethod;
end;

function TContestKingOfSpainSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestKingOfSpainSSB.DescribeSession(const aStation: TStationContext;
                                                 aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountry('EA');
   aSession.AddDomesticCountry('EA6');
   aSession.AddDomesticCountry('EA8');
   aSession.AddDomesticCountry('EA9');
end;

initialization
   RegisterContest(KINGOFSPAINSSB, TContestKingOfSpainSSB);

end.

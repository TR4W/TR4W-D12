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

(* THE REF CONTEST, SSB.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'ref';  WA7BNM: 260;  QRZRUID: 67;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTAndQSONumberOrFrenchDepartmentExchange;
   XM: NoDXMults;  QP: REFQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'REF Contest, SSB'

  Blank CABName and ADIFName resolve to the enum's spelling, 'REF-SSB'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: REFQSOPointMethod -- only a French station scores: 3 off our
  continent, 1 on it; anyone else 0. uCallSignRoutines.FrenchID, which has
  answered False for an empty country since M5a -- kept.

  SET-UP: nothing -- the FoundContest arm that named REFCW was commented
  out (and is deleted with this move).

  A SIBLING, NOT A FAMILY MEMBER (M7b batch 2, DECIDED on evidence). It and
  REFCW (uContestREFCW) share their rules today -- one contest in two modes,
  the NRAU-Baltic shape -- and that is exactly NY4I's open Q7 (and Q43).
  While Q7 is open the brief is siblings, so this class is a COPY and owns
  it (design 1.4). Never merge the two, and never extract a base for them. *)
unit uContestREFSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestREFSSB = class(TContestBase)
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
   uContestRegistry,
   uCallSignRoutines;

(* REFQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestREFSSB.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if not FrenchID(aQso.QTH.CountryID) then
      begin
      Exit;
      end;

   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestREFSSB.GetDisplayName: string;
begin
   Result := 'REF-SSB';
end;

function TContestREFSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'REF-SSB';
end;

function TContestREFSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'REF-SSB';
end;

function TContestREFSSB.GetWA7BNMId: integer;
begin
   Result := 260;
end;

function TContestREFSSB.GetQRZRUId: integer;
begin
   Result := 67;
end;

function TContestREFSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestREFSSB.GetDomesticFileName: string;
begin
   Result := 'ref';
end;

function TContestREFSSB.GetFriendlyName: string;
begin
   Result := 'REF Contest, SSB';
end;

function TContestREFSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestREFSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestREFSSB.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestREFSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestREFSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestREFSSB.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrFrenchDepartmentExchange;
end;

function TContestREFSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := REFQSOPointMethod;
end;

function TContestREFSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(REFSSB, TContestREFSSB);

end.

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

(* THE WW PMC CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'pmc';  WA7BNM: 471;  QRZRUID: 229;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTZoneOrSocietyExchange;
   XM: NoDXMults;  QP: WWPMCQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'WW PMC Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'WW PMC'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: WWPMCQSOPointMethod -- 5; with no MY STATE (not a PMC member),
  25 for a station that sent a QTH; with one, 10 for a QTH other than
  ours.

  SET-UP: nothing -- no FoundContest or LogCfg arm named it. *)
unit uContestWWPMC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWWPMC = class(TContestBase)
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

(* WWPMCQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestWWPMC.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 5;
   if Station.MyState = '' then
      begin
      if aQso.QTHString <> '' then
         begin
         aQso.QSOPoints := 25;
         end;
      end
   else
      begin
      if aQso.QTHString <> '' then
         begin
         if Station.MyState <> aQso.QTHString then
            begin
            aQso.QSOPoints := 10;
            end;
         end;
      end;
end;

function TContestWWPMC.GetDisplayName: string;
begin
   Result := 'WW PMC';
end;

function TContestWWPMC.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'WW PMC';
end;

function TContestWWPMC.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'WW PMC';
end;

function TContestWWPMC.GetWA7BNMId: integer;
begin
   Result := 471;
end;

function TContestWWPMC.GetQRZRUId: integer;
begin
   Result := 229;
end;

function TContestWWPMC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestWWPMC.GetDomesticFileName: string;
begin
   Result := 'pmc';
end;

function TContestWWPMC.GetFriendlyName: string;
begin
   Result := 'WW PMC Contest';
end;

function TContestWWPMC.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestWWPMC.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestWWPMC.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestWWPMC.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestWWPMC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestWWPMC.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrSocietyExchange;
end;

function TContestWWPMC.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := WWPMCQSOPointMethod;
end;

function TContestWWPMC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(WWPMC, TContestWWPMC);

end.

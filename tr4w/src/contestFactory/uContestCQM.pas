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

(* THE CQ-M INTERNATIONAL DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 14;  QRZRUID: 126;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberExchange;
   XM: CQDXCC;  QP: CQMQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'CQ-M International DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CQ-M'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: CQMQSOPointMethod. A Russian station: a non-Russian one 2 in
  Europe or Asia, else 3; a Russian one 1 in our own federal okrug, else 2.
  Anyone else: a Russian station 2 from Europe or Asia, else 3; our own
  country 1, another 2, another continent 3.

  THE OKRUG TEST WAS A TRDOS ROUTINE (LOGSTUFF.InSameFederalOkrug, reading
  MY CALL). It was lifted line for line to the leaf uCallSignRoutines at
  M7b, with the station's call as a parameter, and the engine's arm calls
  the lifted one too -- one function, two callers.

  SET-UP: the R150S list on. *)
unit uContestCQM;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQM = class(TContestBase)
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
   (* RussianID, InSameFederalOkrug -- the leaves the arm asks. *)
   uCallSignRoutines;

procedure TContestCQM.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if RussianID(string(Station.MyCountry)) then
      begin
      if not RussianID(string(rxCty)) then
         begin
         if aQso.QTH.Continent in [Europe, Asia] then
            begin
            aQso.QSOPoints := 2;
            end
         else
            begin
            aQso.QSOPoints := 3;
            end;
         end
      else if InSameFederalOkrug(Station.MyCall, string(aQso.Callsign)) then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else
      begin
      (* Outside Russia. *)
      if RussianID(string(rxCty)) then
         begin
         if Station.MyContinent in [Europe, Asia] then
            begin
            aQso.QSOPoints := 2;
            end
         else
            begin
            aQso.QSOPoints := 3;
            end;
         Exit;
         end;
      if Station.MyCountry = rxCty then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      if Station.MyContinent <> aQso.QTH.Continent then
         begin
         aQso.QSOPoints := 3;
         end;
      end;
end;

function TContestCQM.GetDisplayName: string;
begin
   Result := 'CQ-M';
end;

function TContestCQM.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'CQ-M';
end;

function TContestCQM.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'CQ-M';
end;

function TContestCQM.GetWA7BNMId: integer;
begin
   Result := 14;
end;

function TContestCQM.GetQRZRUId: integer;
begin
   Result := 126;
end;

function TContestCQM.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCQM.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestCQM.GetFriendlyName: string;
begin
   Result := 'CQ-M International DX Contest';
end;

function TContestCQM.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCQM.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCQM.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestCQM.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestCQM.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCQM.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestCQM.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CQMQSOPointMethod;
end;

function TContestCQM.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestCQM.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   aSession.R150SMode := True;
end;

initialization
   RegisterContest(CQM, TContestCQM);

end.

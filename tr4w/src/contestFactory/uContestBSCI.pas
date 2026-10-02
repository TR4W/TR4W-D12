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

(* THE BLACK SEA CUP INTERNATIONAL.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 470;  QRZRUID: 232;
   Pxm: NoPrefixMults;  ZnM: ITUZones;  AIE: ZoneInitialExchange;
   DM: WYSIWYGDomestic;  P: 0;  AE: RSTZoneOrSocietyExchange;
   XM: BlackSeaCountries;  QP: BSCIQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Black Sea Cup International'

  Blank CABName and ADIFName resolve to the enum's spelling, 'BLACK SEA CUP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: BSCIQSOPointMethod -- our own zone 1, our continent 3,
  elsewhere 5; 10 for a Black Sea country or a station sending a QTH that
  starts BS. The zone is Station.MyZone: the arm's Val of MY ZONE, which is
  0 when MY ZONE is not a number -- the IARU class's precedent.

  SET-UP: nothing -- no FoundContest or LogCfg arm named it. *)
unit uContestBSCI;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestBSCI = class(TContestBase)
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
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   uCallSignRoutines,
   uTR4WStrings;

(* BSCIQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestBSCI.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.Zone = Station.MyZone then
      begin
      aQso.QSOPoints := 1;
      end
   else if aQso.QTH.Continent = Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 5;
      end;

   if (BlackSeaRegionCountry(rxCty))         or
      (Copy(aQso.QTHString, 1, 2) = 'BS') then
      begin
      aQso.QSOPoints := 10;
      end;
end;

function TContestBSCI.GetDisplayName: string;
begin
   Result := 'Black Sea Cup International';
end;

function TContestBSCI.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'BLACK SEA CUP';
end;

function TContestBSCI.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'BLACK SEA CUP';
end;

function TContestBSCI.GetWA7BNMId: integer;
begin
   Result := 470;
end;

function TContestBSCI.GetQRZRUId: integer;
begin
   Result := 232;
end;

function TContestBSCI.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestBSCI.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestBSCI.GetFriendlyName: string;
begin
   Result := 'Black Sea Cup International';
end;

function TContestBSCI.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestBSCI.GetZoneMultiplierType: ZoneMultType;
begin
   Result := ITUZones;
end;

function TContestBSCI.GetDXMultiplierType: DXMultType;
begin
   Result := BlackSeaCountries;
end;

function TContestBSCI.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := WYSIWYGDomestic;
end;

function TContestBSCI.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestBSCI.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrSocietyExchange;
end;

function TContestBSCI.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := BSCIQSOPointMethod;
end;

function TContestBSCI.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for IARU.
   The same steps on ticking the box stood for IARU.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestBSCI.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_HQ_OR_MEMBER);
   aPrompts.AskFieldWithCommentWhenInside('', ncfMyState);
end;

initialization
   RegisterContest(BSCI, TContestBSCI);

end.

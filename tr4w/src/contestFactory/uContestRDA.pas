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

(* THE RUSSIAN DISTRICT AWARD CONTEST (RDAC).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 94;  QRZRUID: 386;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: RDADistrict;  P: 0;  AE: RSTDomesticQTHOrQSONumberExchange;
   XM: ARRLDXCC;  QP: RDAQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'Russian District Award Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'RDAC'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: RDAQSOPointMethod -- a Russian station: another Russian 1 (2 on
  another continent), or 10 for a portable one (a call ending /P); anyone
  else 3 on our continent and 5 off it. Anyone else: a Russian station 10,
  everything else 0.

  SET-UP: the Russian domestic countries, domestic multipliers counted
  over all bands, and -- for a station outside Russia only -- no DX
  multiplier. The Russian station's DX multiplier is left as the head set
  it, as the arm left it.

  NOT MOVED, ON PURPOSE: LOGEDIT names this contest twice -- in the
  new-multiplier check that reads the initial exchange of a Russian call,
  and in the initial exchange's oblast fallback beside the Russian DX
  contests. Both are seams not built yet (M8, the multiplier sheet; the
  Russian DX contests, registered since M5b, are still named in the same
  routines). *)
unit uContestRDA;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRDA = class(TContestBase)
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

(* RDAQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestRDA.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   aQso.QSOPoints := 0;
   if RussianID(Station.MyCountry) then
      begin
      if RussianID(rxCty) then
         begin
         if Pos('/P', aQso.Callsign) = Length(aQso.Callsign) - 1 then
            begin
            aQso.QSOPoints := 10;
            Exit;
            end;
         aQso.QSOPoints := 1;
         if aQso.QTH.Continent <> Station.MyContinent then
            begin
            aQso.QSOPoints := 2;
            end;
         Exit;
         end;
      if aQso.QTH.Continent = Station.MyContinent then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 5;
         end;
      end
   else if RussianID(rxCty) then
      begin
      aQso.QSOPoints := 10;
      end;
end;

function TContestRDA.GetDisplayName: string;
begin
   Result := 'RDAC';
end;

function TContestRDA.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'RDAC';
end;

function TContestRDA.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'RDAC';
end;

function TContestRDA.GetWA7BNMId: integer;
begin
   Result := 94;
end;

function TContestRDA.GetQRZRUId: integer;
begin
   Result := 386;
end;

function TContestRDA.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRDA.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRDA.GetFriendlyName: string;
begin
   Result := 'Russian District Award Contest';
end;

function TContestRDA.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRDA.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRDA.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCC;
end;

function TContestRDA.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := RDADistrict;
end;

function TContestRDA.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRDA.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestRDA.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := RDAQSOPointMethod;
end;

function TContestRDA.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestRDA.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesRussia);
   if not RussianID(aStation.MyCountry) then
      begin
      aSession.DXMult := NoDXMults;
      end;
   aSession.DomesticMultByBand := dmbbAllBand;
end;

initialization
   RegisterContest(RDA, TContestRDA);

end.

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

(* THE RUSSIAN DX CONTEST (RDXC).

  The ContestsArray row this class states, verbatim:

   Email: 'logs@rdxc.org';  DF: 'russian';  WA7BNM: 310;  QRZRUID: 7;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTDomesticQTHOrQSONumberExchange;  XM: ARRLDXCC;  QP: RussianDXQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'Russian DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'RDXC'.

  WHY IT HAS A CLASS NOW. M5b (2026-10-02): this contest's initial-exchange
  rule was a test of ActiveQSOPointMethod in ZoneCont.GetVEInitialExchange --
  which an operator's QSO POINT METHOD line reached in any contest. A class to
  hold that rule needed the whole row and the scoring arm with it, because
  registering a class makes the class this contest's scorer too. Both are
  transcribed exactly; Test_MovedRowValuesStillMatchTheArray holds the row,
  and the contest matrix the rest -- every line of its record but
  `contest.class` is unchanged, which is the proof.

  A COPY OF THE RU3AX MEMORIAL'S CLASS, AND DELIBERATELY SO (design 1.4). They
  shared one scoring arm, which doubled phone for the RU3AX Memorial by
  asking `if Contest = RU3AXMEMORIAL` inside it; each contest now states its
  own rule and that test is not needed by either.

  SCORING, transcribed from RussianDXQSOPointMethod. A Russian station
  scores 5 for another continent, 3 for another country of its own continent
  and 2 for its own country. Anybody else scores 10 for a Russian station,
  then 5, 3 and 2 the same way.
  ITS INITIAL EXCHANGE: a Russian station's oblast, from its call. *)
unit uContestRussianDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRussianDX = class(TContestBase)
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
      (* A RUSSIAN STATION'S OBLAST -- see the header. *)
      function InitialExchangeFromCall(const aStandardCall: string;
                                       const aCountryID: string;
                                       out aExchange: string): boolean; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uContestRegistry,
   (* RussianID, GetRussiaOblastID -- the leaves the arm and ZoneCont asked. *)
   uCallSignRoutines;

procedure TContestRussianDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if RussianID(Station.MyCountry) then
      begin
      if aQso.QTH.Continent <> Station.MyContinent then
         begin
         aQso.QSOPoints := 5;
         end
      else if rxCty <> Station.MyCountry then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else if RussianID(rxCty) then
      begin
      aQso.QSOPoints := 10;
      end
   else if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 5;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

function TContestRussianDX.InitialExchangeFromCall(const aStandardCall: string;
                                                   const aCountryID: string;
                                                   out aExchange: string): boolean;
begin
   aExchange := '';
   Result := (Copy(aCountryID, 1, 1) = 'U') and (Copy(aCountryID, 2, 1) = 'A');
   if Result then
      begin
      aExchange := GetRussiaOblastID(aStandardCall);
      end;
end;

function TContestRussianDX.GetDisplayName: string;
begin
   Result := 'Russian DX Contest';
end;

function TContestRussianDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'RDXC';
end;

function TContestRussianDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'RDXC';
end;

function TContestRussianDX.GetWA7BNMId: integer;
begin
   Result := 310;
end;

function TContestRussianDX.GetQRZRUId: integer;
begin
   Result := 7;
end;

function TContestRussianDX.GetSubmissionEmail: string;
begin
   Result := 'logs@rdxc.org';
end;

function TContestRussianDX.GetDomesticFileName: string;
begin
   Result := 'russian';
end;

function TContestRussianDX.GetFriendlyName: string;
begin
   Result := 'Russian DX Contest';
end;

function TContestRussianDX.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRussianDX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRussianDX.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCC;
end;

function TContestRussianDX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestRussianDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRussianDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestRussianDX.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := RussianDXQSOPointMethod;
end;

function TContestRussianDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named RUSSIANDX, RU3AXMEMORIAL; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestRussianDX.DescribeSession(const aStation: TStationContext;
                                            aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesRussia);
   aSession.AddDomesticCountry('CE9');
   if not RussianID(string(aStation.MyCountry)) then
      begin
      aSession.MyState := '';
      end;
end;

initialization
   RegisterContest(RUSSIANDX, TContestRussianDX);

end.

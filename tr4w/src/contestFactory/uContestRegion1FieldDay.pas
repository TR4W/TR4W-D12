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

(* THE IARU REGION 1 FIELD DAY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberExchange;
   XM: CQDXCC;  QP: EuropeanFieldDayQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'REGION 1 FIELD DAY'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: EuropeanFieldDayQSOPointMethod -- by OUR country, each society's
  table: France and Austria (own country 10, or 50 portable; Europe 1, or 5
  portable; elsewhere 3); Denmark (own country 1, or 10 portable; Europe 3,
  or 5 portable; elsewhere 6); Switzerland (portable 5, Europe 1,
  elsewhere 2); Italy (portable 6, Europe 1, elsewhere 2, doubled on 160
  and 80 m); everyone else (Europe 2, or 4 portable; elsewhere 3, or 6
  portable), doubled on 160 and 10 m for a G station. Portable is
  uCallSignRoutines.PortableStation, lifted from Tree at this move.

  SET-UP: nothing -- no FoundContest or LogCfg arm named it.

  THE G TEST READS THE FIRST CHARACTER OF MY COUNTRY WITHOUT A LENGTH
  CHECK, as the arm did: with no country set it reads a stale byte. A
  station's country is derived from its call before scoring, so this is
  transcribed, not judged.

  NOT A FAMILY WITH THE RCC RUNNINGS (uContestRegion1FieldDayRCCCW and
  -SSB): they score by another arm. *)
unit uContestRegion1FieldDay;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRegion1FieldDay = class(TContestBase)
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

(* EuropeanFieldDayQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestRegion1FieldDay.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
   countryID: CallString;
begin
   aQso.QSOPoints := 1;

   rxCty := aQso.QTH.CountryID;
   countryID := Station.MyCountry;

   if (countryID = 'F') or (countryID = 'OE') then
      begin
      if rxCty = Station.MyCountry then
         begin
         if PortableStation(aQso.Callsign) then
            begin
            aQso.QSOPoints := 50;
            end
         else
            begin
            aQso.QSOPoints := 10;
            end;
         end
      else if aQso.QTH.Continent = Europe then
         begin
         if PortableStation(aQso.Callsign) then
            begin
            aQso.QSOPoints := 5;
            end
         else
            begin
            aQso.QSOPoints := 1;
            end;
         end
      else
         begin
         aQso.QSOPoints := 3;
         end;

      Exit;
      end;

   if countryID = 'OZ' then
      begin
      if rxCty = Station.MyCountry then
         begin
         if PortableStation(aQso.Callsign) then
            begin
            aQso.QSOPoints := 10;
            end
         else
            begin
            aQso.QSOPoints := 1;
            end;
         end
      else if aQso.QTH.Continent = Europe then
         begin
         if PortableStation(aQso.Callsign) then
            begin
            aQso.QSOPoints := 5;
            end
         else
            begin
            aQso.QSOPoints := 3;
            end;
         end
      else
         begin
         aQso.QSOPoints := 6;
         end;

      Exit;
      end;

   if countryID = 'HB' then
      begin
      if PortableStation(aQso.Callsign) then
         begin
         aQso.QSOPoints := 5;
         end
      else if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      Exit;
      end;

   if countryID = 'I' then
      begin
      if PortableStation(aQso.Callsign) then
         begin
         aQso.QSOPoints := 6;
         end
      else if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;

      if (aQso.Band = Band160) or (aQso.Band = Band80) then
         begin
         aQso.QSOPoints := aQso.QSOPoints * 2;
         end;
      Exit;
      end;

   (* Anywhere else, including DL and PA. *)

   if PortableStation(aQso.Callsign) then
      begin
      if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 4;
         end
      else
         begin
         aQso.QSOPoints := 6;
         end;
      end
   else
      begin
      if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 3;
         end;
      end;

   if countryID[1] = 'G' then
      begin
      if (aQso.Band = Band160) or (aQso.Band = Band10) then
         begin
         aQso.QSOPoints := aQso.QSOPoints * 2;
         end;
      end;
end;

function TContestRegion1FieldDay.GetDisplayName: string;
begin
   Result := 'REGION 1 FIELD DAY';
end;

function TContestRegion1FieldDay.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'REGION 1 FIELD DAY';
end;

function TContestRegion1FieldDay.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'REGION 1 FIELD DAY';
end;

function TContestRegion1FieldDay.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRegion1FieldDay.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestRegion1FieldDay.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRegion1FieldDay.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRegion1FieldDay.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'REGION 1 FIELD DAY';
end;

function TContestRegion1FieldDay.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRegion1FieldDay.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRegion1FieldDay.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestRegion1FieldDay.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestRegion1FieldDay.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRegion1FieldDay.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestRegion1FieldDay.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := EuropeanFieldDayQSOPointMethod;
end;

function TContestRegion1FieldDay.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(REGION1FIELDDAY, TContestRegion1FieldDay);

end.

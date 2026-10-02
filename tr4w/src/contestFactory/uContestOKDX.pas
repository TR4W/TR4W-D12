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

(* THE OK/OM DX CONTEST, CW.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'okom';  WA7BNM: 185;  QRZRUID: 12;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: NoDomesticMults;  P: 0;
   AE: RSTAndQSONumberOrDomesticQTHExchange;  XM: CQDXCC;  QP: OKDXQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'OK/OM DX Contest, CW'

  Blank CABName and ADIFName resolve to the enum's spelling, 'OK-OM DX CW'.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7a) have moved since.

  SCORING, transcribed from OKDXQSOPointMethod. An OK/OM station scores 2 for
  its own country and 3 for another, then 3 for a European and 5 for a
  non-European station that is not itself OK/OM; a station elsewhere scores 1
  for its own country, 3 for another, 5 for another continent, and 10 for an
  OK/OM station. OK/OM is uCallSignRoutines.OKOMStation.
  ITS IMPORT: an alphabetic SRX_STRING is a domestic QTH and anything else is
  stored as the QTH string. (The arm it came from named three contests,
  Ukrainian DX, OK/OM DX and LZ DX; each owns its own copy -- design 1.4.) *)
unit uContestOKDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestOKDX = class(TContestBase)
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
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   SysUtils, uContestRegistry, uCallSignRoutines, uADIF;

procedure TContestOKDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if OKOMStation(Station.MyCountry) then
      begin
      if rxCty <> Station.MyCountry then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      if not OKOMStation(rxCty) then
         begin
         if aQso.QTH.Continent = Europe then
            begin
            aQso.QSOPoints := 3;
            end
         else
            begin
            aQso.QSOPoints := 5;
            end;
         end;
      end;

   if not OKOMStation(Station.MyCountry) then
      begin
      if rxCty = Station.MyCountry then
         begin
         aQso.QSOPoints := 1;
         end;
      if rxCty <> Station.MyCountry then
         begin
         aQso.QSOPoints := 3;
         end;
      if Station.MyContinent <> aQso.QTH.Continent then
         begin
         aQso.QSOPoints := 5;
         end;
      if OKOMStation(rxCty) then
         begin
         aQso.QSOPoints := 10;
         end;
      end;
end;

procedure TContestOKDX.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                       const aSession: TADIFImportSession;
                                       var aExch: ContestExchange);
begin
   if ADIFTextIsAlphabetic(aTemps.SRX_String) then
      begin
      aExch.DomesticQTH := ShortString(aTemps.SRX_String);
      end
   else
      begin
      aExch.QTHString := ShortString(aTemps.SRX_String);
      end;
end;

function TContestOKDX.GetDisplayName: string;
begin
   Result := 'OK/OM DX Contest, CW';
end;

function TContestOKDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'OK-OM DX CW';
end;

function TContestOKDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'OK-OM DX CW';
end;

function TContestOKDX.GetWA7BNMId: integer;
begin
   Result := 185;
end;

function TContestOKDX.GetQRZRUId: integer;
begin
   Result := 12;
end;

function TContestOKDX.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestOKDX.GetDomesticFileName: string;
begin
   Result := 'okom';
end;

function TContestOKDX.GetFriendlyName: string;
begin
   Result := 'OK/OM DX Contest, CW';
end;

function TContestOKDX.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestOKDX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestOKDX.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestOKDX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestOKDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestOKDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestOKDX.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OKDXQSOPointMethod;
end;

function TContestOKDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestOKDX.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountry('OK');
   aSession.AddDomesticCountry('OM');
   if not OKOMStation(string(aStation.MyCountry)) then
      begin
      aSession.DomesticMult := DomesticFile;
      aSession.DomesticFile := 'OKOM';
      end
   else
      begin
      aSession.PrefixMult := Prefix;
      end;
end;

initialization
   RegisterContest(OKDX, TContestOKDX);

end.

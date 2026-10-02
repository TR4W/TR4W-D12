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

(* THE UKRAINIAN DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'ukraine';  WA7BNM: 176;  QRZRUID: 8;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTAndQSONumberOrDomesticQTHExchange;  XM: CQDXCC;  QP: UkrainianQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'Ukrainian DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'UKRAINIAN'.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7) are not moved.

  SCORING, transcribed from UkrainianQSOPointMethod: 10 for Ukraine (UR), 1 for
  the station's own country, 2 for its own continent, 3 otherwise. A Ukrainian
  station scores 1 for another Ukrainian and earns no domestic multiplier.
  ITS IMPORT: an alphabetic SRX_STRING is a domestic QTH and anything else is
  stored as the QTH string. (The arm it came from named three contests,
  Ukrainian DX, OK/OM DX and LZ DX; each owns its own copy -- design 1.4.) *)
unit uContestUkrainianDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUkrainianDX = class(TContestBase)
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
   end;

implementation

uses
   SysUtils, uContestRegistry, uADIF;

procedure TContestUkrainianDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if rxCty = 'UR' then
      begin
      aQso.QSOPoints := 10;
      end
   else if rxCty = Station.MyCountry then
      begin
      aQso.QSOPoints := 1;
      end
   else if aQso.QTH.Continent = Station.MyContinent then
      begin
      aQso.QSOPoints := 2;
      end
   else
      begin
      aQso.QSOPoints := 3;
      end;

   if Station.MyCountry = 'UR' then
      begin
      if rxCty = 'UR' then
         begin
         aQso.QSOPoints := 1;
         end;
      aQso.DomesticMult := False;
      end;
end;

procedure TContestUkrainianDX.ApplyADIFImport(const aTemps: TADIFRecordTemps;
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

function TContestUkrainianDX.GetDisplayName: string;
begin
   Result := 'Ukrainian DX Contest';
end;

function TContestUkrainianDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'UKRAINIAN';
end;

function TContestUkrainianDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'UKRAINIAN';
end;

function TContestUkrainianDX.GetWA7BNMId: integer;
begin
   Result := 176;
end;

function TContestUkrainianDX.GetQRZRUId: integer;
begin
   Result := 8;
end;

function TContestUkrainianDX.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestUkrainianDX.GetDomesticFileName: string;
begin
   Result := 'ukraine';
end;

function TContestUkrainianDX.GetFriendlyName: string;
begin
   Result := 'Ukrainian DX Contest';
end;

function TContestUkrainianDX.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestUkrainianDX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestUkrainianDX.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestUkrainianDX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestUkrainianDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUkrainianDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestUkrainianDX.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := UkrainianQSOPointMethod;
end;

function TContestUkrainianDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(UKRAINIAN, TContestUkrainianDX);

end.

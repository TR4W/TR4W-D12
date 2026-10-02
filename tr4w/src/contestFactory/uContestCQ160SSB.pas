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

(* THE CQ 160-METER CONTEST, SSB.

  The ContestsArray row this class states, verbatim:

   Email: '160SSB@kkn.net';  DF: 's48p14dc';  WA7BNM: 259;  QRZRUID: 312;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: ZoneInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTZoneOrDomesticQTH;  XM: CQDXCCWithNoUSAOrCanada;  QP: CQ160QSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'CQ 160-Meter Contest, SSB'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CQ-160-SSB'.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7) are not moved.

  SCORING, transcribed from CQ160QSOPointMethod (4.77.6):

      same country 2, else same continent 5, else 10.
  ITS IMPORT: SRX_STRING is the domestic QTH. (The arm it came from named five
  contests, CQ 160 CW and SSB, UBA CW and SSB and ARRL 160; each owns its own
  copy of the body -- design 1.4.) *)
unit uContestCQ160SSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQ160SSB = class(TContestBase)
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
   SysUtils, uContestRegistry;

procedure TContestCQ160SSB.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if rxCty = Station.MyCountry then
      begin
      aQso.QSOPoints := 2;
      end
   else if (rxCty <> Station.MyCountry) and
           (aQso.QTH.Continent = Station.MyContinent) then
      begin
      aQso.QSOPoints := 5;
      end
   else
      begin
      aQso.QSOPoints := 10;
      end;
end;

procedure TContestCQ160SSB.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                           const aSession: TADIFImportSession;
                                           var aExch: ContestExchange);
begin
   aExch.DomesticQTH := ShortString(aTemps.SRX_String);
end;

function TContestCQ160SSB.GetDisplayName: string;
begin
   Result := 'CQ 160-Meter Contest, SSB';
end;

function TContestCQ160SSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'CQ-160-SSB';
end;

function TContestCQ160SSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'CQ-160-SSB';
end;

function TContestCQ160SSB.GetWA7BNMId: integer;
begin
   Result := 259;
end;

function TContestCQ160SSB.GetQRZRUId: integer;
begin
   Result := 312;
end;

function TContestCQ160SSB.GetSubmissionEmail: string;
begin
   Result := '160SSB@kkn.net';
end;

function TContestCQ160SSB.GetDomesticFileName: string;
begin
   Result := 's48p14dc';
end;

function TContestCQ160SSB.GetFriendlyName: string;
begin
   Result := 'CQ 160-Meter Contest, SSB';
end;

function TContestCQ160SSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCQ160SSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCQ160SSB.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCCWithNoUSAOrCanada;
end;

function TContestCQ160SSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestCQ160SSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestCQ160SSB.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrDomesticQTH;
end;

function TContestCQ160SSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CQ160QSOPointMethod;
end;

function TContestCQ160SSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(CQ160SSB, TContestCQ160SSB);

end.

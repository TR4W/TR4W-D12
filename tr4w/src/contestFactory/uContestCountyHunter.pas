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

(* GENERAL COUNTY HUNTING LOG -- COUNTY HUNTER.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQTHExchange;  XM: NoDXMults;
   QP: OnePointPerQSO;  ADIFName: '';  CABName: '';
   FriendlyName: 'General County Hunting Log'

  SCORING IS OnePointPerQSO, one arm of LOGSTUFF.CalculateQSOPoints:

      RXData.QSOPoints := 1;

  so the whole rule is FixedModePoints(Mode, 1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  NOTHING ELSE IN THE PROGRAM NAMES THIS CONTEST. This finds only the
  enum and its ContestsArray row, so this class is the whole of what it
  owns:
      rg -i -w COUNTYHUNTER tr4w/src

  NOT A QSO PARTY, AND NOT ON THE STATE-PARTY BASE, even though county
  hunters work county lines. It is a general logging mode (P is 0). The
  county-line rule lives only on TContestStateQSOPartyBase; this class
  inherits TContestBase.ValidateQTHCount, which always passes, so a
  two-QTH exchange is accepted exactly as it was before the class existed.

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE BASE'S DEFAULT (M4):
  the contest has no export rule of its own, so TContestBase formats it
  through the shared arm for its exchange. *)
unit uContestCountyHunter;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCountyHunter = class(TContestBase)
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
   uContestRegistry, uContestFixedPoints;

procedure TContestCountyHunter.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestCountyHunter.GetDisplayName: string;
begin
   Result := 'General County Hunting Log';
end;

function TContestCountyHunter.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'COUNTY HUNTER';
end;

function TContestCountyHunter.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'COUNTY HUNTER';
end;

function TContestCountyHunter.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestCountyHunter.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestCountyHunter.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCountyHunter.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestCountyHunter.GetFriendlyName: string;
begin
   Result := 'General County Hunting Log';
end;

function TContestCountyHunter.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCountyHunter.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCountyHunter.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestCountyHunter.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestCountyHunter.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCountyHunter.GetExchangeKind: ExchangeType;
begin
   Result := RSTQTHExchange;
end;

function TContestCountyHunter.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestCountyHunter.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(COUNTYHUNTER, TContestCountyHunter);

end.

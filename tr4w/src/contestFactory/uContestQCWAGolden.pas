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

(* QCWA GOLDEN.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: QSONumberNameChapterAndQTHExchange;
   XM: NoDXMults;  QP: OnePhoneTwoCW;  ADIFName: '';  CABName: '';
   FriendlyName: ''

  SCORING IS OnePhoneTwoCW, one arm of LOGSTUFF.CalculateQSOPoints:

      if RXData.Mode = CW then 2 else 1

  so the whole rule is SetPoints(2, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  NOTHING ELSE IN THE PROGRAM NAMES THIS CONTEST. This finds only the
  enum and its ContestsArray row, so this class is the whole of what it
  owns:
      rg -i -w QCWAGOLDEN tr4w/src

  A SEPARATE CLASS FROM QCWA, not a descendant of it -- see uContestQCWA.

  BLANK CABName AND FriendlyName MEAN "THE ENUM'S SPELLING"; the getters
  below state the value each resolves to, never the empty string.
  ADIFName is the opposite: blank there is a real answer, and it is
  stated as the empty string.

  EXCHANGE PARSING AND EXPORT COLUMNS ARE NOT MOVED. FormatsExchange is
  inherited False, so uCabrilloExchange and uADIFExchange still format
  this contest through its shared AE arm. *)
unit uContestQCWAGolden;

{$I tr4w.inc}

interface

uses
   VC, uContestFixedPoints;

type
   TContestQCWAGolden = class(TContestFixedPoints)
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
   public
      constructor Create(aContest: ContestType); override;
   end;

implementation

uses
   uContestRegistry;

constructor TContestQCWAGolden.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(2, 1, 1);
end;

function TContestQCWAGolden.GetDisplayName: string;
begin
   Result := 'QCWA GOLDEN';
end;

function TContestQCWAGolden.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'QCWA GOLDEN';
end;

function TContestQCWAGolden.GetADIFContestId: string;
begin
   (* Blank in the row, and blank is the answer -- no ADIF id is
      stated for this contest. *)
   Result := '';
end;

function TContestQCWAGolden.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestQCWAGolden.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestQCWAGolden.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestQCWAGolden.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestQCWAGolden.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's
      spelling it resolves to. *)
   Result := 'QCWA GOLDEN';
end;

function TContestQCWAGolden.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestQCWAGolden.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestQCWAGolden.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestQCWAGolden.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestQCWAGolden.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestQCWAGolden.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberNameChapterAndQTHExchange;
end;

function TContestQCWAGolden.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePhoneTwoCW;
end;

function TContestQCWAGolden.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(QCWAGOLDEN, TContestQCWAGolden);

end.

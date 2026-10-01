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

(* MINI-TEST 80 -- MINI80.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 712;  QRZRUID: 0;  Pxm: CallSignPrefix;
   ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: NoDomesticMults;
   P: 0;  AE: RSTQSONumberExchange;  XM: NoDXMults;
   QP: OnePointPerQSO;  ADIFName: 'MINITEST-80';
   CABName: 'MINITEST-80';  FriendlyName: 'Mini-Test 80'

  SCORING IS OnePointPerQSO, one arm of LOGSTUFF.CalculateQSOPoints:

      RXData.QSOPoints := 1;

  so the whole rule is SetPoints(1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  FCONTEST has an arm for this contest:
      Band80, single band and mode, 10-minute tours; shared with MINITEST.
  That is contest SETUP, not scoring, and it stays in FCONTEST with the
  rest of contest setup.

  ADIFName AND CABName BOTH ENDED IN A SPACE -- 'MINITEST-80 ' -- UNTIL
  2026-09-29, when NY4I ruled it a typo and the row was corrected. Every file
  exported before then carries the space. It is deliberately NOT listed as a
  former ADIF id: uContestRegistry.FindContestByADIFContestId trims its input,
  so the old spelling resolves to this contest by the current id.

  THE THREE MINITEST ROWS ARE THREE CLASSES WITH NO BASE BETWEEN THEM --
  uContestMinitest, uContestMini40, uContestMini80 -- following the NA
  Sprint precedent (CW and RTTY each on TContestFixedPoints directly). They
  agree on scoring today; if a Minitest rule ever reaches all three by
  definition, that is the moment for a family base, not before.

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING AND EXPORT COLUMNS ARE NOT MOVED. FormatsExchange is
  inherited False, so uCabrilloExchange and uADIFExchange still format
  this contest through its shared AE arm. *)
unit uContestMini80;

{$I tr4w.inc}

interface

uses
   VC, uContestFixedPoints;

type
   TContestMini80 = class(TContestFixedPoints)
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

constructor TContestMini80.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(1, 1, 1);
end;

function TContestMini80.GetDisplayName: string;
begin
   Result := 'Mini-Test 80';
end;

function TContestMini80.GetCabrilloName: string;
begin
   Result := 'MINITEST-80';
end;

function TContestMini80.GetADIFContestId: string;
begin
   Result := 'MINITEST-80';
end;

function TContestMini80.GetWA7BNMId: integer;
begin
   Result := 712;
end;

function TContestMini80.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestMini80.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestMini80.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestMini80.GetFriendlyName: string;
begin
   Result := 'Mini-Test 80';
end;

function TContestMini80.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := CallSignPrefix;
end;

function TContestMini80.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestMini80.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestMini80.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestMini80.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestMini80.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestMini80.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestMini80.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(MINI80, TContestMini80);

end.

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

(* KVP.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: EUHFCYear;  AIE: noInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;  XM: NoDXMults;
   QP: OnePhoneTwoCW;  ADIFName: '';  CABName: '';  FriendlyName: ''

  SCORING IS OnePhoneTwoCW, one arm of LOGSTUFF.CalculateQSOPoints:

      if RXData.Mode = CW then 2 else 1

  so the whole rule is SetPoints(2, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  FCONTEST has an arm for this contest:
      ActiveBand := Band80, with three lines commented out beside it
      (a ZoneInitialExchange, a BranchZones zone mult, and the contest
      name 'KV Prvenstvo ZRS').
  uNewContest asks the operator for the last two digits of the year,
  into the MY ZONE field. Both are contest SETUP, not scoring, and stay
  where they are.

  FLAGGED, NOT CHANGED: THE ZONE MULTIPLIER IS EUHFCYear -- the European
  HF Championship's "year licensed" multiplier -- while FCONTEST's
  commented-out line names BranchZones. Which one KVP's rules actually
  want has not been checked against the sponsor; the row's value is
  transcribed exactly. LOGSTUFF, LOGDUPE and LOGEDIT read EUHFCYear from
  the GLOBAL ActiveZoneMult, which FCONTEST still sets from the row, so
  that behaviour is keyed on the multiplier type and is unaffected by
  this class.

  NOT A STATE QSO PARTY: P is 0 and it has no other family, so it
  inherits TContestFixedPoints.

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING AND EXPORT COLUMNS ARE NOT MOVED. FormatsExchange is
  inherited False, so uCabrilloExchange and uADIFExchange still format
  this contest through its shared AE arm. *)
unit uContestKVP;

{$I tr4w.inc}

interface

uses
   VC, uContestFixedPoints;

type
   TContestKVP = class(TContestFixedPoints)
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

constructor TContestKVP.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(2, 1, 1);
end;

function TContestKVP.GetDisplayName: string;
begin
   Result := 'KVP';
end;

function TContestKVP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'KVP';
end;

function TContestKVP.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'KVP';
end;

function TContestKVP.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestKVP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestKVP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestKVP.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestKVP.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's
      spelling it resolves to. *)
   Result := 'KVP';
end;

function TContestKVP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestKVP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := EUHFCYear;
end;

function TContestKVP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestKVP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestKVP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestKVP.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestKVP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePhoneTwoCW;
end;

function TContestKVP.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(KVP, TContestKVP);

end.

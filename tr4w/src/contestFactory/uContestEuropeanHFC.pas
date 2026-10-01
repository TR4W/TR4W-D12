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

(* EUROPEAN HF CHAMPIONSHIP -- EUROPEAN HFC.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 82;  QRZRUID: 31;
   Pxm: NoPrefixMults;  ZnM: EUHFCYear;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;  XM: NoDXMults;
   QP: OnePointPerQSO;  ADIFName: 'EU-HF';  CABName: '';
   FriendlyName: 'European HF Championship'

  SCORING IS OnePointPerQSO, one arm of LOGSTUFF.CalculateQSOPoints:

      RXData.QSOPoints := 1;

  so the whole rule is FixedModePoints(Mode, 1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  uNewContest asks the operator for the last two digits of the year,
  into the MY ZONE field -- operator SETUP, and it stays there. LOGCFG
  carries a CQ-exchange line naming this contest, and it is COMMENTED
  OUT; nothing is read from it. FCONTEST has no arm for it.

  THE ZONE MULTIPLIER EUHFCYear is read by LOGSTUFF, LOGDUPE and LOGEDIT
  from the GLOBAL ActiveZoneMult, which FCONTEST still sets from the row;
  that behaviour is keyed on the multiplier type, which KVP shares, and is
  unaffected by this class.

  THE ADIF ID WAS BLANK UNTIL 2026-09-29 AND IS NOW 'EU-HF', the ADIF 3.1.7
  Contest_ID enumeration's spelling (EU HF Championship), on NY4I's ruling.
  While it was blank, ADIF export fell back to the enum's spelling, so every
  file exported before the change carries CONTEST_ID 'EUROPEAN HFC'. That is
  this contest's former id, and import accepts it: "Yes support old
  spellings."

  NOT A STATE QSO PARTY: P is 0 and it has no other family, so it
  sits on TContestBase directly and states its own points, calling
  FixedModePoints as a helper (TContestFixedPoints retired at M3).

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING AND EXPORT COLUMNS ARE NOT MOVED. FormatsExchange is
  inherited False, so uCabrilloExchange and uADIFExchange still format
  this contest through its shared AE arm. *)
unit uContestEuropeanHFC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestEuropeanHFC = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. Every getter below states
         the ContestsArray row quoted above. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFormerADIFContestIds: TContestIdList; override;
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

procedure TContestEuropeanHFC.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestEuropeanHFC.GetDisplayName: string;
begin
   Result := 'European HF Championship';
end;

function TContestEuropeanHFC.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'EUROPEAN HFC';
end;

function TContestEuropeanHFC.GetADIFContestId: string;
begin
   Result := 'EU-HF';
end;

function TContestEuropeanHFC.GetFormerADIFContestIds: TContestIdList;
begin
   (* What ADIF export wrote while the row's ADIFName was blank: the enum's
      spelling. See the unit header. *)
   Result := ContestIdList(['EUROPEAN HFC']);
end;

function TContestEuropeanHFC.GetWA7BNMId: integer;
begin
   Result := 82;
end;

function TContestEuropeanHFC.GetQRZRUId: integer;
begin
   Result := 31;
end;

function TContestEuropeanHFC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestEuropeanHFC.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestEuropeanHFC.GetFriendlyName: string;
begin
   Result := 'European HF Championship';
end;

function TContestEuropeanHFC.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestEuropeanHFC.GetZoneMultiplierType: ZoneMultType;
begin
   Result := EUHFCYear;
end;

function TContestEuropeanHFC.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestEuropeanHFC.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestEuropeanHFC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestEuropeanHFC.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestEuropeanHFC.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestEuropeanHFC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(EUROPEANHFC, TContestEuropeanHFC);

end.

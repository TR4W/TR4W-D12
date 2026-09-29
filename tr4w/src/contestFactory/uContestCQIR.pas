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

(* CQIR -- IRELAND CALLING.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'ireland';  WA7BNM: 434;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  DM: DomesticFile;  P: 0;
   AE: QSONumberAndPossibleDomesticQTHExchange;  XM: NoDXMults;
   QP: TwoPhoneThreeCW;  ADIFName: '';  CABName: '';
   FriendlyName: 'CQIR - Ireland Calling'

  SCORING IS TwoPhoneThreeCW, one arm of LOGSTUFF.CalculateQSOPoints:

      if RXData.Mode = CW then 3 else 2

  so the whole rule is SetPoints(3, 2, 2) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  FCONTEST has an arm for this contest: AddDomesticCountry('EI'). LOGCFG
  builds its CQ exchange from MY STATE. uNewContest asks for the county
  code and shows an "Ireland" check box. All of that is contest SETUP,
  not scoring, and it stays where it is.

  THE ROW HAS NO AIE FIELD AT ALL -- not commented out, simply absent --
  so its initial-exchange kind is whatever the typed constant initialises
  to (ordinal 0, which is NoInitialExchange today). Following the ARRL
  Field Day precedent for an unstated field, GetInitialExchangeKind is
  deliberately NOT overridden: stating a value here would be inventing a
  choice nobody made. It keeps reading the array.

  NOT A STATE QSO PARTY: P is 0, and DomesticFile names Irish counties,
  not a US state's. No other family, so it inherits TContestFixedPoints.

  BLANK CABName AND FriendlyName MEAN "THE ENUM'S SPELLING"; the getters
  below state the value each resolves to, never the empty string.
  ADIFName is the opposite: blank there is a real answer, and it is
  stated as the empty string.

  EXCHANGE PARSING AND EXPORT COLUMNS ARE NOT MOVED. FormatsExchange is
  inherited False, so uCabrilloExchange and uADIFExchange still format
  this contest through its shared AE arm. *)
unit uContestCQIR;

{$I tr4w.inc}

interface

uses
   VC, uContestFixedPoints;

type
   TContestCQIR = class(TContestFixedPoints)
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
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;
      function GetIsUSQSOParty: boolean; override;
   public
      constructor Create(aContest: ContestType); override;
   end;

implementation

uses
   uContestRegistry;

constructor TContestCQIR.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(3, 2, 2);
end;

function TContestCQIR.GetDisplayName: string;
begin
   Result := 'CQIR - Ireland Calling';
end;

function TContestCQIR.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'CQIR';
end;

function TContestCQIR.GetADIFContestId: string;
begin
   (* Blank in the row, and blank is the answer -- no ADIF id is
      stated for this contest. *)
   Result := '';
end;

function TContestCQIR.GetWA7BNMId: integer;
begin
   Result := 434;
end;

function TContestCQIR.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestCQIR.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCQIR.GetDomesticFileName: string;
begin
   Result := 'ireland';
end;

function TContestCQIR.GetFriendlyName: string;
begin
   Result := 'CQIR - Ireland Calling';
end;

function TContestCQIR.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCQIR.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCQIR.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestCQIR.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestCQIR.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndPossibleDomesticQTHExchange;
end;

function TContestCQIR.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := TwoPhoneThreeCW;
end;

function TContestCQIR.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(CQIR, TContestCQIR);

end.

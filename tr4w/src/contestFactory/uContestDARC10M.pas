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

(* THE DARC 10-METER CONTEST.

  The ContestsArray row this class states, verbatim (its AE carries a
  commented-out RSTAndQSONumberOrDomesticQTHExchange beside it):

   Email: '';  DF: '';  WA7BNM: 223;  QRZRUID: 184;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: WYSIWYGDomestic;  P: 0;  AE: RSTQSONumberAndPossibleDomesticQTHExchange;
   XM: CQDXCC;  QP: OnePointPerQSO;  ADIFName: '';
   CABName: '';  FriendlyName: 'DARC 10-Meter Contest'

  Blank ADIFName and CABName are the enum's spelling, 'DARC-10M'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = DARC10M` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5) and set-up (M7) are not moved.

  SCORING IS OnePointPerQSO, stated through the FixedModePoints helper:

      OnePointPerQSO: RXData.QSOPoints := 1;

  ITS RECEIVED CABRILLO COLUMN IS ITS OWN: '%-3s %4.4d %3s' -- RST, serial,
  and a three-wide DOK -- where the shared
  RSTQSONumberAndPossibleDomesticQTHExchange arm writes a four-wide QTH. That
  was an `if Contest = DARC10M` inside the arm (n4af 4.43.7). The sent column
  is the arm's. *)
unit uContestDARC10M;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestDARC10M = class(TContestBase)
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
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry, uContestFixedPoints;

procedure TContestDARC10M.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestDARC10M.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %4.4d %3s', [aCtx.RSTReceived, aQso.NumberReceived, aCtx.HisQTH]);
end;

function TContestDARC10M.GetDisplayName: string;
begin
   Result := 'DARC 10-Meter Contest';
end;

function TContestDARC10M.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'DARC-10M';
end;

function TContestDARC10M.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'DARC-10M';
end;

function TContestDARC10M.GetWA7BNMId: integer;
begin
   Result := 223;
end;

function TContestDARC10M.GetQRZRUId: integer;
begin
   Result := 184;
end;

function TContestDARC10M.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestDARC10M.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestDARC10M.GetFriendlyName: string;
begin
   Result := 'DARC 10-Meter Contest';
end;

function TContestDARC10M.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestDARC10M.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestDARC10M.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestDARC10M.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := WYSIWYGDomestic;
end;

function TContestDARC10M.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestDARC10M.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndPossibleDomesticQTHExchange;
end;

function TContestDARC10M.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestDARC10M.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(DARC10M, TContestDARC10M);

end.

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

(* THE PCC (4.83.8: every reference to TAC became PCC).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0;  QRZRUID: 35;
   Pxm: Prefix;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTAndQSONumberOrDomesticQTHExchange;
   XM: NoDXMults;  QP: PCCQSOPointMethod;  ADIFName: '';
   CABName: '';  FriendlyName: ''

  Blank ADIFName, CABName and FriendlyName are the enum's spelling, 'PCC'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = PCC` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5) and set-up (M7) are not moved.

  SCORING IS PCCQSOPointMethod, transcribed exactly: 2 for a QSO with another
  country, 1 within our own; and when the received exchange ENDS IN 'M' (a
  mobile), 6 more if our MY STATE is all digits, 2 more otherwise. The arm
  first sets 0 for 80 to 10 m and then overwrites it unconditionally -- that
  line has no effect and is not carried.

  THE SENT SIDE IS ITS OWN. Inside the shared
  RSTAndQSONumberOrDomesticQTHExchange arm, `(MyState <> '') and (Contest <>
  PCC)` sent the state for everyone else; the PCC always sends its serial,
  with '/M' after it when MY STATE is all digits. That branch is this class's
  now, in both exporters, and the shared arm keeps only the state-or-serial
  answer. The received column is the arm's. *)
unit uContestPCC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestPCC = class(TContestBase)
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
      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string; override;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aSessionExchange: ExchangeType): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry,
   (* StringIsAllNumbers -- the test the arm asks of MY STATE. *)
   utils_text;

procedure TContestPCC.CalculateQSOPoints(var aQso: ContestExchange);
var
   lastIndex: integer;
begin
   if aQso.QTH.CountryID <> Station.MyCountry then
      begin
      aQso.QSOPoints := 2;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;

   (* "found 'M' in recvd nr?" -- the exchange's last character. The arm
      indexed the length byte of an empty QTH, which is never 'M'; the guard
      says the same thing aloud. *)
   lastIndex := Length(aQso.QTHString);
   if (lastIndex > 0) and (aQso.QTHString[lastIndex] = 'M') then
      begin
      if StringIsAllNumbers(Station.MyState) then
         begin
         inc(aQso.QSOPoints, 6);
         end
      else
         begin
         inc(aQso.QSOPoints, 2);
         end;
      end;
end;

function TContestPCC.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aCtx: TCabrilloQSOContext): string;
begin
   if StringIsAllNumbers(aMy.MyState) then
      begin
      Result := Format('%-4s %3.4u/M   ', [aCtx.RSTSent, aQso.NumberSent]);  (* n4af 4.43.12 *)
      end
   else
      begin
      Result := Format('%-4s %3.4u   ', [aCtx.RSTSent, aQso.NumberSent]);  (* n4af 4.43.12 *)
      end;
end;

function TContestPCC.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            aSessionExchange: ExchangeType): string;
begin
   if StringIsAllNumbers(aMy.MyState) then
      begin
      Result := Format('%-4d %03u/M   ', [aQso.RSTSent, aQso.NumberSent]);
      end
   else
      begin
      Result := Format('%-4d %03u   ', [aQso.RSTSent, aQso.NumberSent]);
      end;
end;

function TContestPCC.GetDisplayName: string;
begin
   Result := 'PCC';
end;

function TContestPCC.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'PCC';
end;

function TContestPCC.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'PCC';
end;

function TContestPCC.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestPCC.GetQRZRUId: integer;
begin
   Result := 35;
end;

function TContestPCC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestPCC.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestPCC.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; it resolves to the enum's
      spelling. *)
   Result := 'PCC';
end;

function TContestPCC.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := Prefix;
end;

function TContestPCC.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestPCC.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestPCC.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestPCC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestPCC.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestPCC.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := PCCQSOPointMethod;
end;

function TContestPCC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(PCC, TContestPCC);

end.

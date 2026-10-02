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

  so the whole rule is FixedModePoints(Mode, 3, 2, 2) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  FCONTEST had an arm for this contest: AddDomesticCountry('EI'). LOGCFG
  built its CQ exchange from MY STATE. Both are this class's since M7a
  (DescribeSession, CQExchangeDefault). uNewContest asks for the county
  code and shows an "Ireland" check box; that prompt moves at M9.

  THE ROW HAS NO AIE FIELD AT ALL -- not commented out, simply absent --
  so its initial-exchange kind is whatever the typed constant initialises
  to (ordinal 0, which is NoInitialExchange today). Following the ARRL
  Field Day precedent for an unstated field, GetInitialExchangeKind is
  deliberately NOT overridden: stating a value here would be inventing a
  choice nobody made. It keeps reading the array.

  NOT A STATE QSO PARTY: P is 0, and DomesticFile names Irish counties,
  not a US state's. No other family, so it sits on
  TContestBase and states its own points, calling FixedModePoints as
  a helper (TContestFixedPoints retired at M3).

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE BASE'S DEFAULT (M4):
  the contest has no export rule of its own, so TContestBase formats it
  through the shared arm for its exchange. *)
unit uContestCQIR;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQIR = class(TContestBase)
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
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   uContestRegistry, uContestFixedPoints;

procedure TContestCQIR.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 3, 2, 2);
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
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'CQIR';
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

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestCQIR.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountry('EI');
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestCQIR.CQExchangeDefault(const aStation: TStationContext): string;
begin
   if aStation.MyState <> '' then
      begin
      Result := ' ' + aStation.MyState + ' #';
      end
   else
      begin
      Result := ' #';
      end;
end;

initialization
   RegisterContest(CQIR, TContestCQIR);

end.

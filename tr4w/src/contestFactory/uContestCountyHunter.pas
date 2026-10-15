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

  SCORING IS OnePointPerQSO, an arm of the legacy LOGSTUFF scoring
  case (deleted at M10 S3; see git history or the D7 tree):

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

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE CLASS'S, THROUGH HELPERS
  (M11 S9b, S9c): the contest has no export rule of its own, so it states its
  ADIF STX_STRING and its two Cabrillo columns by calling the named helpers
  its exchange uses (uADIFExchange, uCabrilloExchange). *)
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
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* THE ROVER COUNTY -- see TContestBase.StripsRoverCountyFromCall (M11 S7). *)
      function StripsRoverCountyFromCall: boolean; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
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

function TContestCountyHunter.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCountyHunter.GetExchangeKind: ExchangeType;
begin
   Result := RSTQTHExchange;
end;

function TContestCountyHunter.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestCountyHunter.ParseReceivedExchangeFormat(const aText: string;
                                                          aParsers: TExchangeParsers;
                                                          var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTQTH(aText, aExch);
end;

function TContestCountyHunter.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                  const aQso: ContestExchange): string;
begin
   Result := ADIFSentNotImplemented(aMy, aQso);
end;

function TContestCountyHunter.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                      const aQso: ContestExchange;
                                                      const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentNotHandled(aMy, aQso, aCtx);
end;

function TContestCountyHunter.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                          const aQso: ContestExchange;
                                                          const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedNotHandled(aMy, aQso, aCtx);
end;

function TContestCountyHunter.GetFlags: TContestFlags;
begin
   Result := [];
end;

function TContestCountyHunter.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

(* A CALL'S /SUFFIX THAT THE DOMESTIC TABLE KNOWS IS A ROVER'S COUNTY, at
   every station -- M11 S7, 2026-10-14. It was the session's RSTQTH shape;
   see TContestBase.StripsRoverCountyFromCall.

   KEPT AFTER Q94 (2026-10-14), the one contest that is not a QSO party and
   still strips. NY4I's ruling makes a /suffix a county rover only in a QSO
   party; County Hunter's whole exchange is the county, and a mobile's /county
   is the thing being hunted, so the strip stays. That is a recorded decision
   in docs/CONTEST_FACTORY_OPEN_QUESTIONS.md Q94, not NY4I's ruling. It does
   NOT split on export (TContestBase.SplitsRoverCallOnExport, False): it is
   not a QSO party, and its export is unchanged. *)
function TContestCountyHunter.StripsRoverCountyFromCall: boolean;
begin
   Result := True;
end;

(* ONE SEARCH-AND-POUNCE ENTRY MAY CARRY SEVERAL QTHs, at every station --
   M11 S7, 2026-10-14. It was the session's RSTQTH shape; see
   TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestCountyHunter.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(COUNTYHUNTER, TContestCountyHunter);

end.

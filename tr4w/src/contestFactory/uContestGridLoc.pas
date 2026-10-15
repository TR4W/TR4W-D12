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

(* GRID LOC.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NameInitialExchange;
   DM: WYSIWYGDomestic;  P: 0;  AE: NameAndPossibleGridSquareExchange;
   XM: NoDXMults;  QP: OnePointPerQSO;  ADIFName: '';  CABName: '';
   FriendlyName: ''

  SCORING IS OnePointPerQSO, an arm of the legacy LOGSTUFF scoring
  case (deleted at M10 S3; see git history or the D7 tree):

      RXData.QSOPoints := 1;

  so the whole rule is FixedModePoints(Mode, 1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  NOTHING ELSE IN THE PROGRAM NAMES THIS CONTEST. This finds only the
  enum and its ContestsArray row, so this class is the whole of what it
  owns:
      rg -i -w GRIDLOC tr4w/src

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE CLASS'S, THROUGH HELPERS
  (M11 S9b, S9c): the contest has no export rule of its own, so it states its
  ADIF STX_STRING and its two Cabrillo columns by calling the named helpers
  its exchange uses (uADIFExchange, uCabrilloExchange). *)
unit uContestGridLoc;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestGridLoc = class(TContestBase)
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
      (* THE DOMESTIC QTH -- see TContestBase.DomesticMultiplierFromQTH
         (M11 S6). *)
      function DomesticMultiplierFromQTH(const aText: Str20;
                                         var aMultiplier: Str10;
                                         var aQTH: Str10;
                                         var aFound: boolean): TDomesticQTHAnswer; override;
      (* see TContestBase.DomesticQTHReplacesDXMultiplier (M11 S6). *)
      function DomesticQTHReplacesDXMultiplier: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry, uContestFixedPoints;

procedure TContestGridLoc.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestGridLoc.GetDisplayName: string;
begin
   Result := 'GRID LOC';
end;

function TContestGridLoc.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'GRID LOC';
end;

function TContestGridLoc.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'GRID LOC';
end;

function TContestGridLoc.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestGridLoc.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestGridLoc.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestGridLoc.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestGridLoc.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's
      spelling it resolves to. *)
   Result := 'GRID LOC';
end;

function TContestGridLoc.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameInitialExchange;
end;

function TContestGridLoc.GetExchangeKind: ExchangeType;
begin
   Result := NameAndPossibleGridSquareExchange;
end;

function TContestGridLoc.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNameQTH;
end;

function TContestGridLoc.GetADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange): string;
begin
   Result := ADIFSentNotImplemented(aMy, aQso);
end;

function TContestGridLoc.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentNotHandled(aMy, aQso, aCtx);
end;

function TContestGridLoc.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedNotHandled(aMy, aQso, aCtx);
end;

function TContestGridLoc.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestGridLoc.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   WYSIWYGDomestic arm (the trait): the text as received is both the multiplier and
   the QTH, cut to the field's ten characters, and it is always found. *)
function TContestGridLoc.DomesticMultiplierFromQTH(const aText: Str20;
                                                   var aMultiplier: Str10;
                                                   var aQTH: Str10;
                                                   var aFound: boolean): TDomesticQTHAnswer;
begin
   aMultiplier := aText;
   aQTH := aText;
   aFound := True;
   Result := dqaDecided;
end;

(* A DOMESTIC QTH TAKES THE PLACE OF THE DX MULTIPLIER -- M11 S6 part 1,
   moved from LOGDUPE.GetDXQTH's `= WYSIWYGDomestic` guard (the trait). See
   TContestBase.DomesticQTHReplacesDXMultiplier. *)
function TContestGridLoc.DomesticQTHReplacesDXMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(GRIDLOC, TContestGridLoc);

end.

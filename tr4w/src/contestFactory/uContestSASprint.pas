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

(* SA-SPRINT.

  The ContestsArray row this class states, verbatim:

   Email: 'sa-sprint.com/enviar-log/';  DF: '';  WA7BNM: 0000;
   QRZRUID: 0;  Pxm: SouthAmericanPrefixes;  ZnM: NoZoneMults;
   AIE: NoInitialExchange;  DM: NoDomesticMults;  P: 0;
   AE: RSTQSONumberExchange;  XM: NoDXMults;  QP: OnePointPerQSO;
   ADIFName: '';  CABName: '';  FriendlyName: ''

  SCORING IS OnePointPerQSO, one arm of LOGSTUFF.CalculateQSOPoints:

      RXData.QSOPoints := 1;

  so the whole rule is FixedModePoints(Mode, 1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  NOTHING ELSE IN THE PROGRAM NAMES THIS CONTEST. This finds only the
  enum and its ContestsArray row, so this class is the whole of what it
  owns:
      rg -i -w SASPRINT tr4w/src

  THE Email FIELD HOLDS A URL PATH, NOT AN ADDRESS:
  'sa-sprint.com/enviar-log/' (the sponsor's log-upload page, missing its
  scheme). Transcribed exactly, because this class changes no behaviour;
  whatever reads SubmissionEmail gets what it got before. Flagged for NY4I.

  NOT AN NA SPRINT, and not related to TContestNASprintCW: a different
  sponsor, a different exchange, and no QSY rule in FCONTEST.

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE BASE'S DEFAULT (M4):
  the contest has no export rule of its own, so TContestBase formats it
  through the shared arm for its exchange. *)
unit uContestSASprint;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestSASprint = class(TContestBase)
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
   end;

implementation

uses
   uContestRegistry, uContestFixedPoints;

procedure TContestSASprint.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestSASprint.GetDisplayName: string;
begin
   Result := 'SA-SPRINT';
end;

function TContestSASprint.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'SA-SPRINT';
end;

function TContestSASprint.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'SA-SPRINT';
end;

function TContestSASprint.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestSASprint.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestSASprint.GetSubmissionEmail: string;
begin
   Result := 'sa-sprint.com/enviar-log/';
end;

function TContestSASprint.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestSASprint.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's
      spelling it resolves to. *)
   Result := 'SA-SPRINT';
end;

function TContestSASprint.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := SouthAmericanPrefixes;
end;

function TContestSASprint.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestSASprint.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestSASprint.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestSASprint.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestSASprint.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestSASprint.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestSASprint.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(SASPRINT, TContestSASprint);

end.

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

(* MINITEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;  Pxm: CallSignPrefix;
   ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: NoDomesticMults;
   P: 0;  AE: RSTQSONumberExchange;  XM: NoDXMults;
   QP: OnePointPerQSO;  ADIFName: '';  CABName: '';  FriendlyName: ''

  SCORING IS OnePointPerQSO, one arm of LOGSTUFF.CalculateQSOPoints:

      RXData.QSOPoints := 1;

  so the whole rule is FixedModePoints(Mode, 1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  FCONTEST had an arm for this contest:
      Band80, single band and mode, 10-minute tours; shared with MINI80.
  That is contest SETUP, not scoring, and since M7a it is this class's
  DescribeSession -- the arm is gone from FCONTEST.

  THE THREE MINITEST ROWS ARE THREE CLASSES WITH NO BASE BETWEEN THEM --
  uContestMinitest, uContestMini40, uContestMini80 -- following the NA
  Sprint precedent (CW and RTTY sibling classes, no base between). They
  agree on scoring today; if a Minitest rule ever reaches all three by
  definition, that is the moment for a family base, not before.

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE BASE'S DEFAULT (M4):
  the contest has no export rule of its own, so TContestBase formats it
  through the shared arm for its exchange. *)
unit uContestMinitest;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestMinitest = class(TContestBase)
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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uContestRegistry, uContestFixedPoints;

procedure TContestMinitest.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestMinitest.GetDisplayName: string;
begin
   Result := 'MINITEST';
end;

function TContestMinitest.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'MINITEST';
end;

function TContestMinitest.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'MINITEST';
end;

function TContestMinitest.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestMinitest.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestMinitest.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestMinitest.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestMinitest.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's
      spelling it resolves to. *)
   Result := 'MINITEST';
end;

function TContestMinitest.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := CallSignPrefix;
end;

function TContestMinitest.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestMinitest.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestMinitest.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestMinitest.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestMinitest.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestMinitest.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestMinitest.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named MINITEST, MINI80; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestMinitest.DescribeSession(const aStation: TStationContext;
                                           aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
   aSession.MultipleBands := False;
   aSession.MultipleModes := False;
   aSession.MinitourDuration := 10;
end;

initialization
   RegisterContest(MINITEST, TContestMinitest);

end.

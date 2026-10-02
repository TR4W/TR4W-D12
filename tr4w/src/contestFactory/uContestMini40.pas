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

(* MINI-TEST 40 -- MINI40.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 711;  QRZRUID: 0;  Pxm: CallSignPrefix;
   ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: NoDomesticMults;
   P: 0;  AE: RSTQSONumberExchange;  XM: NoDXMults;
   QP: OnePointPerQSO;  ADIFName: 'MINITEST-40';
   CABName: 'MINITEST-40';  FriendlyName: 'Mini-Test 40'

  SCORING IS OnePointPerQSO, one arm of LOGSTUFF.CalculateQSOPoints:

      RXData.QSOPoints := 1;

  so the whole rule is FixedModePoints(Mode, 1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  FCONTEST had an arm for this contest:
      Band40, single band and mode, 10-minute tours.
  That is contest SETUP, not scoring, and since M7a it is this class's
  DescribeSession -- the arm is gone from FCONTEST.

  ADIFName AND CABName BOTH ENDED IN A SPACE -- 'MINITEST-40 ' -- UNTIL
  2026-09-29, when NY4I ruled it a typo and the row was corrected. Every file
  exported before then carries the space. It is deliberately NOT listed as a
  former ADIF id: uContestRegistry.FindContestByADIFContestId trims its input,
  so the old spelling resolves to this contest by the current id.

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
unit uContestMini40;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestMini40 = class(TContestBase)
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

procedure TContestMini40.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestMini40.GetDisplayName: string;
begin
   Result := 'Mini-Test 40';
end;

function TContestMini40.GetCabrilloName: string;
begin
   Result := 'MINITEST-40';
end;

function TContestMini40.GetADIFContestId: string;
begin
   Result := 'MINITEST-40';
end;

function TContestMini40.GetWA7BNMId: integer;
begin
   Result := 711;
end;

function TContestMini40.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestMini40.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestMini40.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestMini40.GetFriendlyName: string;
begin
   Result := 'Mini-Test 40';
end;

function TContestMini40.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := CallSignPrefix;
end;

function TContestMini40.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestMini40.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestMini40.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestMini40.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestMini40.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestMini40.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestMini40.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestMini40.DescribeSession(const aStation: TStationContext;
                                         aSession: TSessionDefaults);
begin
   aSession.Band := Band40;
   aSession.MultipleBands := False;
   aSession.MultipleModes := False;
   aSession.MinitourDuration := 10;
end;

initialization
   RegisterContest(MINI40, TContestMini40);

end.

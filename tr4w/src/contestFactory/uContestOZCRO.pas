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

(* THE OZCHR CONTEST, TEAMS (OZCR-O).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 182;
   Pxm: NoPrefixMults;  ZnM: ITUZones;  AIE: ZoneInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneOrSocietyExchange;
   XM: CQDXCC;  QP: OnePointPerQSO;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'OZCHR-TEAMS'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: OnePointPerQSO -- 1.

  SET-UP: the contest name, and the R150S list on.

  THE CONTEST NAME IS QUESTION MARKS, AND THAT IS TRANSCRIBED, NOT JUDGED.
  FoundContest's arm held a Cyrillic name that reached this tree as literal
  '?' characters (the bytes are 0x3F); the session has always been named
  that. Restoring the Russian text is a data change for NY4I.

  LogCfg's CQ exchange: 5NN and MY STATE, or 5NN and MY ZONE with no state.

  NOT A FAMILY. The OZCHR team and individual contests share a name and a
  sponsor, but not a rule: their point methods, domestic and DX multipliers
  and set-up already differ. *)
unit uContestOZCRO;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestOZCRO = class(TContestBase)
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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   uContestRegistry;

procedure TContestOZCRO.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 1;
end;

function TContestOZCRO.GetDisplayName: string;
begin
   Result := 'OZCHR-TEAMS';
end;

function TContestOZCRO.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'OZCHR-TEAMS';
end;

function TContestOZCRO.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'OZCHR-TEAMS';
end;

function TContestOZCRO.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestOZCRO.GetQRZRUId: integer;
begin
   Result := 182;
end;

function TContestOZCRO.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestOZCRO.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestOZCRO.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'OZCHR-TEAMS';
end;

function TContestOZCRO.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestOZCRO.GetZoneMultiplierType: ZoneMultType;
begin
   Result := ITUZones;
end;

function TContestOZCRO.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestOZCRO.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestOZCRO.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestOZCRO.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrSocietyExchange;
end;

function TContestOZCRO.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestOZCRO.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestOZCRO.DescribeSession(const aStation: TStationContext;
                                        aSession: TSessionDefaults);
begin
   aSession.ContestName := '????-??????? ????????? ?????? - ????? ?????????';
   aSession.R150SMode := True;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved at M7b -- see
   TContestBase.CQExchangeDefault. *)
function TContestOZCRO.CQExchangeDefault(const aStation: TStationContext): string;
begin
   if aStation.MyState <> '' then
      begin
      Result := ' 5NN ' + aStation.MyState;
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyZoneText;
      end;
end;

initialization
   RegisterContest(OZCR_O, TContestOZCRO);

end.

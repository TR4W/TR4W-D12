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

(* THE FISTS WINTER UNLIMITED SPRINT.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 's49p8';  WA7BNM: 251;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTQTHNameAndFistsNumberOrPowerExchange;
   XM: NoDXMults;  QP: FistsQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'FISTS Winter Unlimited Sprint'

  Blank CABName and ADIFName resolve to the enum's spelling, 'FISTS'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: FistsQSOPointMethod -- a member (a FISTS number received) 5,
  else 2.

  ITS FINAL SCORE is the points alone, and that is not this class's rule:
  TContestBase.CombineScore scores the FISTS exchange's points for every
  contest whose session runs it (M6). *)
unit uContestFISTS;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestFISTS = class(TContestBase)
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
   uContestRegistry;

procedure TContestFISTS.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.NumberReceived > 0 then
      begin
      aQso.QSOPoints := 5;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

function TContestFISTS.GetDisplayName: string;
begin
   Result := 'FISTS';
end;

function TContestFISTS.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'FISTS';
end;

function TContestFISTS.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'FISTS';
end;

function TContestFISTS.GetWA7BNMId: integer;
begin
   Result := 251;
end;

function TContestFISTS.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestFISTS.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestFISTS.GetDomesticFileName: string;
begin
   Result := 's49p8';
end;

function TContestFISTS.GetFriendlyName: string;
begin
   Result := 'FISTS Winter Unlimited Sprint';
end;

function TContestFISTS.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestFISTS.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestFISTS.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestFISTS.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestFISTS.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestFISTS.GetExchangeKind: ExchangeType;
begin
   Result := RSTQTHNameAndFistsNumberOrPowerExchange;
end;

function TContestFISTS.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := FistsQSOPointMethod;
end;

function TContestFISTS.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(FISTS, TContestFISTS);

end.

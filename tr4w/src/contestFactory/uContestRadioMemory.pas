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

(* THE RADIO MEMORY CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 83;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTAgeAndPossibleSK;
   XM: NoDXMults;  QP: RadioMemoryQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling, 'RADIO-MEMORY'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: RadioMemoryQSOPointMethod -- the received age, plus the number
  after the space in the received QTH when its next three characters are
  all digits.

  SET-UP: nothing in FoundContest (its arm there was commented out, and
  that comment is deleted with this move). LogCfg's CQ exchange: MY
  STATE. *)
unit uContestRadioMemory;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRadioMemory = class(TContestBase)
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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   uContestRegistry,
   SysUtils,
   utils_text;

(* RadioMemoryQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestRadioMemory.CalculateQSOPoints(var aQso: ContestExchange);
var
   spaceAt: integer;
   theirID: CallString;
begin
   aQso.QSOPoints := aQso.Age;
   spaceAt := Pos(' ', aQso.QTHString);
   if spaceAt <> 0 then
      begin
      theirID := Copy(aQso.QTHString, spaceAt + 1, 3);

      if StringIsAllNumbers(theirID) then
         begin
         Inc(aQso.QSOPoints, StrToIntDef(theirID, 0));
         end;
      end;
end;

function TContestRadioMemory.GetDisplayName: string;
begin
   Result := 'RADIO-MEMORY';
end;

function TContestRadioMemory.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'RADIO-MEMORY';
end;

function TContestRadioMemory.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'RADIO-MEMORY';
end;

function TContestRadioMemory.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestRadioMemory.GetQRZRUId: integer;
begin
   Result := 83;
end;

function TContestRadioMemory.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRadioMemory.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRadioMemory.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'RADIO-MEMORY';
end;

function TContestRadioMemory.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRadioMemory.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRadioMemory.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestRadioMemory.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestRadioMemory.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRadioMemory.GetExchangeKind: ExchangeType;
begin
   Result := RSTAgeAndPossibleSK;
end;

function TContestRadioMemory.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := RadioMemoryQSOPointMethod;
end;

function TContestRadioMemory.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (M7b batch 2). See TContestBase.CQExchangeDefault. *)
function TContestRadioMemory.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' ' + aStation.MyState;
end;

initialization
   RegisterContest(RADIOMEMORY, TContestRadioMemory);

end.

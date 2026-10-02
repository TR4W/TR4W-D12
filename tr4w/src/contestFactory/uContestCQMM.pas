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

(* THE CQMM DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 21;  QRZRUID: 34;
   Pxm: SouthAmericanPrefixes;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTAndContinentExchange;
   XM: CQDXCC;  QP: CQMMQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'CQMM DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CQMM'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: CQMMQSOPointMethod -- on 80 to 10 m only: another continent 3,
  another country 2, our own 1, the first two doubled on 80 and 40 m; 10
  for a station whose three-character QTH ends M, Q or Y. Off those bands
  0, multipliers still earned (no InhibitMults, no UsesBand -- Q44).

  SET-UP: a South American station counts South and North American
  prefixes (anyone else keeps the head's); DXCC multipliers by band over
  all bands (TSessionDefaults.DXCCMultByBand, M7b batch 2); 80 m.

  NOT MOVED, ON PURPOSE: LOGEDIT's remaining-multiplier display and
  MainUnit's prefix rule read this contest's prefix kinds, not its name --
  shared multiplier code, M8. *)
unit uContestCQMM;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQMM = class(TContestBase)
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
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   uTR4WStrings;

(* CQMMQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestCQMM.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
   ptsMult: integer;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.Band in [Band80..Band10] then
      begin
      ptsMult := integer(aQso.Band in [Band40, Band80]) + 1;
      if aQso.QTH.Continent <> Station.MyContinent then
         begin
         aQso.QSOPoints := 3 * ptsMult;
         end
      else if rxCty <> Station.MyCountry then
         begin
         aQso.QSOPoints := 2 * ptsMult;
         end
      else
         begin
         aQso.QSOPoints := 1;
         end;

      if Length(aQso.QTHString) = 3 then
         begin
         if aQso.QTHString[3] in ['M', 'Q', 'Y'] then
            begin
            aQso.QSOPoints := 10;
            end;
         end;
      end;
end;

function TContestCQMM.GetDisplayName: string;
begin
   Result := 'CQMM DX Contest';
end;

function TContestCQMM.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'CQMM';
end;

function TContestCQMM.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'CQMM';
end;

function TContestCQMM.GetWA7BNMId: integer;
begin
   Result := 21;
end;

function TContestCQMM.GetQRZRUId: integer;
begin
   Result := 34;
end;

function TContestCQMM.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCQMM.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestCQMM.GetFriendlyName: string;
begin
   Result := 'CQMM DX Contest';
end;

function TContestCQMM.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := SouthAmericanPrefixes;
end;

function TContestCQMM.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCQMM.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestCQMM.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestCQMM.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCQMM.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndContinentExchange;
end;

function TContestCQMM.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CQMMQSOPointMethod;
end;

function TContestCQMM.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestCQMM.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   if aStation.MyContinent = SouthAmerica then
      begin
      aSession.PrefixMult := SouthAndNorthAmericanPrefixes;
      end;
   aSession.DXCCMultByBand := dmbbAllBand;
   aSession.Band := Band80;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestCQMM.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURCONTINENT, ncfMyState);
end;

initialization
   RegisterContest(CQMM, TContestCQMM);

end.

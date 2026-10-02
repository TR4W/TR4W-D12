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

(* THE NCCC SPRINT.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'naqp';  WA7BNM: 44;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NameQTHInitialExchange;  DM: DomesticFile;  P: 0;
   AE: QSONumberNameDomesticOrDXQTHExchange;  XM: NoDXMults;  QP: OnePointPerQSO;
   ADIFName: '';  CABName: '';  FriendlyName: 'NCCC Sprint'

  Blank CABName and ADIFName resolve to the enum's spelling, 'NCCC-SPRINT'.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7a) have moved since.

  SCORING IS OnePointPerQSO, stated through the FixedModePoints helper:

      OnePointPerQSO: RXData.QSOPoints := 1;

  ITS IMPORT: the STATE tag is the exchange. The received exchange is stored as
  the QTH, the domestic QTH and the exchange string all at once. *)
unit uContestNCCCSprint;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestNCCCSprint = class(TContestBase)
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
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   SysUtils, uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

procedure TContestNCCCSprint.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

procedure TContestNCCCSprint.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                             const aSession: TADIFImportSession;
                                             var aExch: ContestExchange);
begin
   aExch.QTHString   := ShortString(aTemps.State);
   aExch.DomesticQTH := ShortString(aTemps.State);
   aExch.ExchString  := ShortString(aTemps.State);
end;

function TContestNCCCSprint.GetDisplayName: string;
begin
   Result := 'NCCC Sprint';
end;

function TContestNCCCSprint.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'NCCC-SPRINT';
end;

function TContestNCCCSprint.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'NCCC-SPRINT';
end;

function TContestNCCCSprint.GetWA7BNMId: integer;
begin
   Result := 44;
end;

function TContestNCCCSprint.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNCCCSprint.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestNCCCSprint.GetDomesticFileName: string;
begin
   Result := 'naqp';
end;

function TContestNCCCSprint.GetFriendlyName: string;
begin
   Result := 'NCCC Sprint';
end;

function TContestNCCCSprint.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestNCCCSprint.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestNCCCSprint.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestNCCCSprint.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestNCCCSprint.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameQTHInitialExchange;
end;

function TContestNCCCSprint.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberNameDomesticOrDXQTHExchange;
end;

function TContestNCCCSprint.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestNCCCSprint.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named LQP, NCCCSPRINT; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestNCCCSprint.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.AutoDupeEnableCQ := True;
   aSession.AutoDupeEnableSAndP := True;
   aSession.AddDomesticCountry('KH6');
   aSession.AddDomesticCountries(DomesticCountriesKVE);
   aSession.ExchangeMemoryEnable := True;
   aSession.SprintQSYRule := True;
   aSession.AllowDupeQSOs := False;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestNCCCSprint.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' # ' + aStation.MyName + ' ' + aStation.MyState;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for CWOPS, LQP.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestNCCCSprint.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskField(ncfMyName);
   aPrompts.AskFieldWithComment(TC_ENTERYOURNAMEANDQTH, ncfMyState);
end;

initialization
   RegisterContest(NCCCSPRINT, TContestNCCCSprint);

end.

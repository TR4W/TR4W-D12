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

(* THE NORTH AMERICAN QSO PARTY, SSB.

  The ContestsArray row this class states, verbatim:

   Email: 'ssbnaqpmgr@ncjweb.com';  DF: 'naqp';  WA7BNM: 229;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NameInitialExchange;  DM: DomesticFile;  P: 0;
   AE: NameAndDomesticOrDXQTHExchange;  XM: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7;  QP: OnePointPerQSO;
   ADIFName: '';  CABName: '';  FriendlyName: 'North American QSO Party, SSB'

  Blank CABName and ADIFName resolve to the enum's spelling, 'NAQP-SSB'.

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
unit uContestNAQPSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestNAQPSSB = class(TContestBase)
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
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange (M9a). *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry, uContestFixedPoints,
   uTR4WStrings,
   uCanonicalExchange;

procedure TContestNAQPSSB.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

procedure TContestNAQPSSB.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                          const aSession: TADIFImportSession;
                                          var aExch: ContestExchange);
begin
   aExch.QTHString   := ShortString(aTemps.State);
   aExch.DomesticQTH := ShortString(aTemps.State);
   aExch.ExchString  := ShortString(aTemps.State);
end;

function TContestNAQPSSB.GetDisplayName: string;
begin
   Result := 'North American QSO Party, SSB';
end;

function TContestNAQPSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'NAQP-SSB';
end;

function TContestNAQPSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'NAQP-SSB';
end;

function TContestNAQPSSB.GetWA7BNMId: integer;
begin
   Result := 229;
end;

function TContestNAQPSSB.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNAQPSSB.GetSubmissionEmail: string;
begin
   Result := 'ssbnaqpmgr@ncjweb.com';
end;

function TContestNAQPSSB.GetDomesticFileName: string;
begin
   Result := 'naqp';
end;

function TContestNAQPSSB.GetFriendlyName: string;
begin
   Result := 'North American QSO Party, SSB';
end;

function TContestNAQPSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestNAQPSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestNAQPSSB.GetDXMultiplierType: DXMultType;
begin
   Result := NorthAmericanARRLDXCCWithNoUSACanadaOrkL7;
end;

function TContestNAQPSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestNAQPSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameInitialExchange;
end;

function TContestNAQPSSB.GetExchangeKind: ExchangeType;
begin
   Result := NameAndDomesticOrDXQTHExchange;
end;

function TContestNAQPSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestNAQPSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named NAQSOCW, NAQSOSSB, NAQSORTTY; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestNAQPSSB.DescribeSession(const aStation: TStationContext;
                                          aSession: TSessionDefaults);
begin
   aSession.CQExchangeCW := ' ' + aStation.MyName + ' ' + aStation.MyState;
   aSession.QSLCW := '73 \ NA>';
   aSession.QuickQSLCW1 := 'TU';
   aSession.QSOBeforeCW := ' QSO B4 \ NA';
   aSession.SPExchangeCW := aStation.MyName + ' ' + aStation.MyState;
   aSession.CallOkNowCW := '} R';

   aSession.SetCQMemory(CW, smkF1, 'CQ^NA \ \ NA>');
   aSession.SetCQMemory(CW, smkF2, 'CQ^NA CQ^NA \ \ NA>');
   aSession.SetCQMemory(CW, smkF5, '   ? ');
   aSession.SetCQMemory(CW, smkF6, '   NA \ NA ');
   aSession.SetCQMemory(CW, smkF7, '   CQ^NA \ \ NA ');
   aSession.SetCQMemory(CW, smkF8, '   CQ^NA CQ^NA \ \ NA ');
   (* The arm set Alt-F1 twice, to this value both times. *)
   aSession.SetCQMemory(CW, smkAltF1, 'NA \ \ NA');

   aSession.SetExchangeMemory(CW, smkF3, aStation.MyName);
   aSession.SetExchangeMemory(CW, smkF4, aStation.MyState);
   aSession.SetExchangeMemory(CW, smkF5, '@ DE \ ' + aStation.MyName + ' ' + aStation.MyState);
   aSession.SetExchangeMemory(CW, smkAltF3, 'NAME?');
   aSession.SetExchangeMemory(CW, smkAltF4, 'QTH?');
   aSession.SetExchangeMemory(CW, smkF7, '   CQ^NA \ \ NA ');
   aSession.SetExchangeMemory(CW, smkF8, '   CQ^NA CQ^NA \ \ NA ');

   aSession.AddDomesticCountries(DomesticCountriesKVEKH6KL);
   aSession.LiteralDomesticQTH := True;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for NAQSOCW, NAQSORTTY, SST.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestNAQPSSB.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURNAMEANDSTATE, ncfMyState);
   aPrompts.AskField(ncfMyName);
end;

(* THE CANONICAL RECEIVED EXCHANGE -- uExchangeBuilder's arm for this
   contest, moved here at M9a (2026-10-02): the name and the state (or
   DX), rebuilt from the fields so an edit to either reaches the
   scoreboard (2026-05-28). The arm named SST and the three NAQP runnings;
   each holds its own copy (design 1.4). See
   TContestBase.CanonicalReceivedExchange; the caller collapses the
   whitespace. *)
function TContestNAQPSSB.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   Result := Trim(string(aQso.Name)) + ' ' + Trim(string(aQso.QTHString));
end;

initialization
   RegisterContest(NAQSOSSB, TContestNAQPSSB);

end.

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

(* THE NORTH AMERICAN QSO PARTY, CW.

  The ContestsArray row this class states, verbatim:

   Email: 'cwnaqpmgr@ncjweb.com';  DF: 'naqp';  WA7BNM: 218;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NameInitialExchange;  DM: DomesticFile;  P: 0;
   AE: NameAndDomesticOrDXQTHExchange;  XM: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7;  QP: OnePointPerQSO;
   ADIFName: '';  CABName: '';  FriendlyName: 'North American QSO Party, CW'

  Blank CABName and ADIFName resolve to the enum's spelling, 'NAQP-CW'.

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
unit uContestNAQPCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestNAQPCW = class(TContestBase)
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
   end;

implementation

uses
   SysUtils, uContestRegistry, uContestFixedPoints;

procedure TContestNAQPCW.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

procedure TContestNAQPCW.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                         const aSession: TADIFImportSession;
                                         var aExch: ContestExchange);
begin
   aExch.QTHString   := ShortString(aTemps.State);
   aExch.DomesticQTH := ShortString(aTemps.State);
   aExch.ExchString  := ShortString(aTemps.State);
end;

function TContestNAQPCW.GetDisplayName: string;
begin
   Result := 'North American QSO Party, CW';
end;

function TContestNAQPCW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'NAQP-CW';
end;

function TContestNAQPCW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'NAQP-CW';
end;

function TContestNAQPCW.GetWA7BNMId: integer;
begin
   Result := 218;
end;

function TContestNAQPCW.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNAQPCW.GetSubmissionEmail: string;
begin
   Result := 'cwnaqpmgr@ncjweb.com';
end;

function TContestNAQPCW.GetDomesticFileName: string;
begin
   Result := 'naqp';
end;

function TContestNAQPCW.GetFriendlyName: string;
begin
   Result := 'North American QSO Party, CW';
end;

function TContestNAQPCW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestNAQPCW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestNAQPCW.GetDXMultiplierType: DXMultType;
begin
   Result := NorthAmericanARRLDXCCWithNoUSACanadaOrkL7;
end;

function TContestNAQPCW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestNAQPCW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameInitialExchange;
end;

function TContestNAQPCW.GetExchangeKind: ExchangeType;
begin
   Result := NameAndDomesticOrDXQTHExchange;
end;

function TContestNAQPCW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePointPerQSO;
end;

function TContestNAQPCW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named NAQSOCW, NAQSOSSB, NAQSORTTY; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestNAQPCW.DescribeSession(const aStation: TStationContext;
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

initialization
   RegisterContest(NAQSOCW, TContestNAQPCW);

end.

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

(* INTERNET SPRINT.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 's49p13';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: QSONumberNameDomesticOrDXQTHExchange;
   XM: NorthAmericanARRLDXCCWithNoUSACanadaOrkL7;
   QP: AlwaysOnePointPerQSO;  ADIFName: '';  CABName: '';
   FriendlyName: ''

  SCORING IS AlwaysOnePointPerQSO, an arm of the legacy LOGSTUFF scoring
  case (deleted at M10 S3; see git history or the D7 tree):

      RXData.QSOPoints := 1;

  so the whole rule is FixedModePoints(Mode, 1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  FCONTEST had an arm for this contest:
      band, auto-dupe, sprint QSY rule, CW messages.
  That is contest SETUP, not scoring, and since M7a it is this class's
  DescribeSession -- the arm is gone from FCONTEST.

  AlwaysOnePointPerQSO SCORES EXACTLY LIKE OnePointPerQSO, and the
  difference is not scoring. Its meaning -- "ignores dupes" in VC.pas --
  is a DUPE POLICY, and since M3 (2026-10-01) this class states it:
  GetMarksDupes answers False, and LOGSUBS2 asks MarksDupes through
  ContestIdentity rather than testing the global ActiveQSOPointMethod. So an
  operator's QSO POINT METHOD line no longer switches dupe marking for this
  contest, in either direction. The point method itself was deleted as a
  concept at M10 S4 (2026-10-14); this class's GetMarksDupes is now the only
  place the rule is stated.

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE BASE'S DEFAULT (M4):
  the contest has no export rule of its own, so TContestBase formats it
  through the shared arm for its exchange. *)
unit uContestInternetSprint;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestInternetSprint = class(TContestBase)
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
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      function GetMarksDupes: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   end;

implementation

uses
   uDXMultiplierKey,
   uContestRegistry, uContestFixedPoints;

procedure TContestInternetSprint.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestInternetSprint.GetDisplayName: string;
begin
   Result := 'INTERNET SPRINT';
end;

function TContestInternetSprint.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'INTERNET SPRINT';
end;

function TContestInternetSprint.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'INTERNET SPRINT';
end;

function TContestInternetSprint.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestInternetSprint.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestInternetSprint.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestInternetSprint.GetDomesticFileName: string;
begin
   Result := 's49p13';
end;

function TContestInternetSprint.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's
      spelling it resolves to. *)
   Result := 'INTERNET SPRINT';
end;

function TContestInternetSprint.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestInternetSprint.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestInternetSprint.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestInternetSprint.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberNameDomesticOrDXQTHExchange;
end;

function TContestInternetSprint.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand];
end;

function TContestInternetSprint.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

function TContestInternetSprint.GetMarksDupes: boolean;
begin
   (* "Ignores dupes" -- the meaning the row's AlwaysOnePointPerQSO carried.
      See the unit header. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestInternetSprint.DescribeSession(const aStation: TStationContext;
                                                 aSession: TSessionDefaults);
begin
   aSession.Band := Band20;
   aSession.AutoDupeEnableCQ := False;
   aSession.AutoDupeEnableSAndP := False;
   aSession.ExchangeMemoryEnable := False;
   aSession.SprintQSYRule := True;

   aSession.SPExchangeCW := '@ #   (   ' + aStation.MyState + ' \';
   aSession.RepeatSPExchangeCW := '@ #   (   ' + aStation.MyState;
   aSession.CQExchangeCW := ' \ #   (   ' + aStation.MyState;
   aSession.QSLCW := 'EE';

   aSession.SetCQMemory(CW, smkF1, 'INT \');
   aSession.SetCQMemory(CW, smkF2, 'CQ^INT \ \ INT');
   aSession.SetCQMemory(CW, smkF5, '  ?');
   aSession.SetCQMemory(CW, smkF6, '  INT \');
   aSession.SetCQMemory(CW, smkF7, '  CQ^INT \ \ INT');
   aSession.SetCQMemory(CW, smkF8, '  CQ^INT CQ^INT \ \ INT');

   aSession.SetExchangeMemory(CW, smkF7, '  CQ^INT \ \ INT');
   aSession.SetExchangeMemory(CW, smkF8, '  CQ^INT CQ^INT \ \ INT');
   aSession.SetExchangeMemory(CW, smkF3, '#');
   aSession.SetExchangeMemory(CW, smkF4, '  (  ');
   aSession.SetExchangeMemory(CW, smkF5, aStation.MyState);
   aSession.SetExchangeMemory(CW, smkF6, '@ \ # ( ' + aStation.MyState);
   aSession.SetExchangeMemory(CW, smkAltF3, 'NR?');
   aSession.SetExchangeMemory(CW, smkAltF4, 'NAME?');
   aSession.SetExchangeMemory(CW, smkAltF5, 'QTH?');
   aSession.AddDomesticCountries(DomesticCountriesKVE);
   aSession.AddDomesticCountry('KL');
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`NorthAmericanARRLDXCCWithNoUSACanadaOrkL7`) until the
   kind was deleted. *)
function TContestInternetSprint.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   North American countries other than the USA, Canada and Alaska -- the
   NorthAmericanARRLDXCCWithNoUSACanadaOrkL7 arm. The CQ list, whatever the
   kind's name: the country-mode set never held it. *)
function TContestInternetSprint.DXMultiplierKey(const aQso: ContestExchange;
                                                out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if IsNorthAmericanDXCountry(aQso.QTH.CountryID, aQso.QTH.Continent) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

initialization
   RegisterContest(INTERNETSPRINT, TContestInternetSprint);

end.

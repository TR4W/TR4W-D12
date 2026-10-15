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

(* North American Sprint - RTTY.

  OnePointPerQSO, as the CW running -- stated here, not inherited: the CW
  running is a sibling class, not a family base (see uContestNASprintCW's
  header for why no NA Sprint base exists). On TContestBase since M3. *)
unit uContestNASprintRTTY;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestNASprintRTTY = class(TContestBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFriendlyName: string; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetWA7BNMId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function GetFlags: TContestFlags; override;
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
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uDXMultiplierKey,
   uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

procedure TContestNASprintRTTY.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestNASprintRTTY.GetDisplayName: string;
begin
   Result := 'North American Sprint, RTTY';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestNASprintRTTY.GetCabrilloName: string;
begin
   Result := 'NA-SPRINT-RTTY';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestNASprintRTTY.GetADIFContestId: string;
begin
   Result := 'NA-SPRINT-RTTY';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestNASprintRTTY.GetFriendlyName: string;
begin
   Result := 'North American Sprint, RTTY';
end;

function TContestNASprintRTTY.GetWA7BNMId: integer;
begin
   Result := 155;
end;

function TContestNASprintRTTY.GetSubmissionEmail: string;
begin
   Result := 'rttysprint@ncjweb.com';
end;

function TContestNASprintRTTY.GetDomesticFileName: string;
begin
   Result := 's49p8';
end;

function TContestNASprintRTTY.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameQTHInitialExchange;
end;

function TContestNASprintRTTY.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberNameDomesticOrDXQTHExchange;
end;

function TContestNASprintRTTY.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsQSONumberNameQTH;
end;

function TContestNASprintRTTY.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfRTCCapable];
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named NASPRINTCW, NASPRINTRTTY; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestNASprintRTTY.DescribeSession(const aStation: TStationContext;
                                               aSession: TSessionDefaults);
begin
   aSession.Band := Band20;

   aSession.CQExchangeCW := '^  \   # ' + aStation.MyName + ' ' + aStation.MyState;
   aSession.QSLCW := 'TU';
   aSession.QuickQSLCW1 := 'EE';
   aSession.QSOBeforeCW := 'B4 \ NA';
   aSession.SPExchangeCW := '@ # ' + aStation.MyName + ' ' + aStation.MyState + '  \ ';
   aSession.RepeatSPExchangeCW := '# ' + aStation.MyName + ' ' + aStation.MyState;
   aSession.CallOkNowCW := '} R';

   aSession.SetCQMemory(CW, smkF1, 'NA \');
   aSession.SetCQMemory(CW, smkF2, 'CQ^NA CQ^NA \ \ NA');
   aSession.SetCQMemory(CW, smkF5, '   ? ');
   aSession.SetCQMemory(CW, smkF6, '   NA \ NA ');
   aSession.SetCQMemory(CW, smkF7, '   CQ^NA \ \ NA ');
   aSession.SetCQMemory(CW, smkF8, '   CQ^NA CQ^NA \ \ NA ');
   (* The arm set Alt-F1 to 'NA \ NA' first and overwrote it with this. *)
   aSession.SetCQMemory(CW, smkAltF1, 'NA \ \ NA');

   aSession.SetExchangeMemory(CW, smkF3, 'NR #');
   aSession.SetExchangeMemory(CW, smkF4, aStation.MyName);
   aSession.SetExchangeMemory(CW, smkF5, aStation.MyState);
   aSession.SetExchangeMemory(CW, smkF6, '@ \ NR^# ' + aStation.MyName + ' ' + aStation.MyState);
   aSession.SetExchangeMemory(CW, smkF7, '   CQ^NA \ \ NA ');
   aSession.SetExchangeMemory(CW, smkF8, '   CQ^NA CQ^NA \ \ NA ');
   aSession.SetExchangeMemory(CW, smkAltF3, 'NR?');
   aSession.SetExchangeMemory(CW, smkAltF4, 'NAME?');
   aSession.SetExchangeMemory(CW, smkAltF5, 'QTH?');

   aSession.SprintQSYRule := True;
   aSession.AddDomesticCountries(DomesticCountriesKVE);
   aSession.AddDomesticCountry('KL');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for NASPRINTCW, SPRINTSSB.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestNASprintRTTY.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURQTHANDTHENAME, ncfMyState);
   aPrompts.AskField(ncfMyName);
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`NorthAmericanARRLDXCCWithNoUSACanadaOrkL7`) until the
   kind was deleted. *)
function TContestNASprintRTTY.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   North American countries other than the USA, Canada and Alaska -- the
   NorthAmericanARRLDXCCWithNoUSACanadaOrkL7 arm. The CQ list, whatever the
   kind's name: the country-mode set never held it. *)
function TContestNASprintRTTY.DXMultiplierKey(const aQso: ContestExchange;
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


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestNASprintRTTY.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(NASPRINTRTTY, TContestNASprintRTTY);

end.

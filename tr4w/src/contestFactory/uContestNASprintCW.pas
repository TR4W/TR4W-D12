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

(* North American Sprint - CW.

  OnePointPerQSO. A sprint's character is its QSY rule and its exchange, not its scoring.

  ON TContestBase SINCE M3 (2026-10-01), with the RTTY running a SIBLING class,
  not a family member -- no NA Sprint base is introduced. The evidence: the two
  rows already differ (domestic file 'naqp' here, 's49p8' for RTTY), this class
  owns its export and RTTY's does not, and NY4I's family ruling names NRAU-Baltic
  only; whether every two-mode pair follows it is Q7 in
  CONTEST_OWNERSHIP_DESIGN.md, still his. TContestFixedPoints retired at M3; the
  one point is stated here through the FixedModePoints helper.

  THE SSB SPRINT IS NOT THIS CONTEST'S SIBLING EITHER. NY4I: a different contest
  with a different sponsor -- uContestSprintSSB, on TContestBase. *)
unit uContestNASprintCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestNASprintCW = class(TContestBase)
   protected
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
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
   public
      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string; override;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aSessionExchange: ExchangeType): string; override;
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
   SysUtils, uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

procedure TContestNASprintCW.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestNASprintCW.GetDisplayName: string;
begin
   Result := 'North American Sprint, CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestNASprintCW.GetCabrilloName: string;
begin
   Result := 'NA-SPRINT-CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestNASprintCW.GetADIFContestId: string;
begin
   Result := 'NA-SPRINT-CW';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestNASprintCW.GetFriendlyName: string;
begin
   Result := 'North American Sprint, CW';
end;

(* THE EXCHANGE IS SERIAL, NAME AND STATE-OR-DX.

   'DX' IS SUBSTITUTED ON BOTH SIDES when there is no state, which is the
   Sprint's way of saying "outside North America" -- an empty column would be
   read by a scorer as a missing field rather than as a legitimate answer.

   THE WIDTHS ARE DELIBERATELY ASYMMETRIC and this is not a typo: sent is
   `%-4d %-7s %-8s` and received is `%-4u %-5s %-4s`. Both carry the 4.88.3
   marker in the legacy source, so they were set to those numbers together and
   on purpose.

   THE SHARED ARM STAYS: the SSB Sprint and the NA Sprint RTTY run the same
   exchange with no rule of their own, so TContestBase formats them through
   QSONumberNameDomesticOrDXQTHExchange -- the arm this class copies. *)
function TContestNASprintCW.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   if aMy.MyState = '' then
      begin
      Result := Format('%-4d %-7s %-8s', [aQso.NumberSent, aMy.MyName, 'DX']);
      end
   else
      begin
      Result := Format('%-4d %-7s %-8s', [aQso.NumberSent, aMy.MyName, aMy.MyState]);
      end;
end;

function TContestNASprintCW.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                           const aQso: ContestExchange;
                                                           const aCtx: TCabrilloQSOContext): string;
begin
   (* Tested on aQso.QTHString and formatted from aCtx.HisQTH, matching the
      legacy arm exactly. *)
   if aQso.QTHString = '' then
      begin
      Result := Format('%-4u %-5s %-4s', [aQso.NumberReceived, string(aQso.Name), 'DX']);
      end
   else
      begin
      Result := Format('%-4u %-5s %-4s', [aQso.NumberReceived, string(aQso.Name), aCtx.HisQTH]);
      end;
end;

function TContestNASprintCW.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   aSessionExchange: ExchangeType): string;
begin
   if aMy.MyState = '' then
      begin
      Result := Format('%-4d %-7s %-8s', [aQso.NumberSent, aMy.MyName, 'DX']);
      end
   else
      begin
      Result := Format('%-4d %-7s %-8s', [aQso.NumberSent, aMy.MyName, aMy.MyState]);
      end;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named NASPRINTCW, NASPRINTRTTY; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestNASprintCW.DescribeSession(const aStation: TStationContext;
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
   The same steps on choosing stood for NASPRINTRTTY, SPRINTSSB.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestNASprintCW.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURQTHANDTHENAME, ncfMyState);
   aPrompts.AskField(ncfMyName);
end;

initialization
   RegisterContest(NASPRINTCW, TContestNASprintCW);

end.

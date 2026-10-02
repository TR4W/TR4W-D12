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
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uContestRegistry, uContestFixedPoints;

procedure TContestNASprintRTTY.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestNASprintRTTY.GetDisplayName: string;
begin
   Result := 'North American Sprint - RTTY';
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

initialization
   RegisterContest(NASPRINTRTTY, TContestNASprintRTTY);

end.

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

(* MICHIGAN QSO PARTY.

  THE SECOND STATE PARTY, AND IT EXISTS TO PROVE THE BASE RATHER THAN TO SHOW
  IT OFF. Florida had a class and Michigan ran entirely through the legacy path,
  so the pair is the one place in the corpus where TContestStateQSOPartyBase can be
  measured: both logs are in the golden corpus, and test-contest-factory.sh can
  diff factory against legacy on a contest that has just changed sides.

  WHAT IT DOES NOT OWN, AND WHY THAT IS THE POINT.

  ITS EXCHANGE IS NOT FLORIDA'S. Michigan is RSTDomesticQTHExchange and Florida
  is RSTDomesticOrDXQTHExchange: Florida delegates to the domestic parser only
  for a domestic callsign and gives a DX station a free-text QTH, where Michigan
  has no DX side at all. Two state parties, two parsers -- which is the whole
  argument for this base being a mechanism base and not a family one.

  IT DOES NOT FORMAT ITS OWN EXCHANGE. FormatsExchange stays False, so Cabrillo
  and ADIF still come from the legacy RSTDomesticQTHExchange arm. That arm is
  shared with roughly a dozen other contests and carries three cases that are
  not Michigan's (CQVHF's grid, SPDX and PACC's serial number), so taking it
  over means reproducing a decision tree no gate can see -- ADDING_A_CONTEST.md
  section 4: exchange formatting is checked by the golden corpus only where the
  corpus log happens to exercise it. The move is section 6.3's, done for every
  contest on the arm at once, not smuggled in here.

  ITS POINTS ARE ITS OWN, though they happen to equal Florida's. OnePhoneTwoCW
  is 11 contests' answer and two of them being state parties is a coincidence
  of sponsors -- California is three points flat and Texas is TwoPhoneThreeCW.
  NY4I on the two Field Days: "They keep diverging with rule changes each
  year." *)
unit uContestMichiganQP;

{$I tr4w.inc}

interface

uses
   VC, uContestStateQSOPartyBase;

type
   TContestMichiganQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;
      function GetHostState: string; override;

      (* NO COUNTY LINE AT ALL -- AND ContestsArray SAYS OTHERWISE.

         THE SPONSOR'S RULE: "No station may claim simultaneous operation in
         more than one county, state, or province." Michigan is the opposite
         end of the same axis from Florida, whose rules allow exactly two.

         VC.pas GIVES MICHQSOPARTY CountyLineAllowed: True, WHICH IS WRONG, AND
         THIS IS THE FIRST THING THE FACTORY HAS CAUGHT THAT NOTHING ELSE
         COULD. The flag is not inert: MainUnit's ADIF import sets
         ceClearDupeSheet whenever the same (call|band|mode) reappears with a
         different QTHString in a contest carrying it, so a GENUINE DUPLICATE
         in a Michigan log is accepted today instead of being flagged.

         THE ARRAY IS DELIBERATELY NOT EDITED. It is the compatibility source
         and the class is where a contest states what it owns, so the two are
         allowed to disagree exactly where somebody has deliberately made them
         -- see uContestBase's note on the accessors. Everything still reading
         ContestsArray directly (MainUnit's import, uADIF's rover-call parse)
         is unchanged and keeps its present behaviour until it asks the factory
         instead. That repoint is a separate change with its own evidence.

         SO WHAT DOES CHANGE TODAY: the exchange parser will refuse a
         two-county exchange in this contest, which is the edit check the rule
         describes. Nothing in the export path consults this -- verified
         against uADIF.ResolveRoverCall and MainUnit's import, both of which
         read the array -- so the golden corpus cannot move. *)
      function GetCountyLineCountiesMax: integer; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

uses
   uContestFixedPoints, uContestRegistry;

function TContestMichiganQP.GetDisplayName: string;
begin
   Result := 'Michigan QSO Party';
end;

function TContestMichiganQP.GetHostState: string;
begin
   Result := 'MI';
end;

function TContestMichiganQP.GetCountyLineCountiesMax: integer;
begin
   (* Zero, so the derived CountyLineAllowed reads False. *)
   Result := 0;
end;

(* OnePhoneTwoCW: `if Mode = CW then 2 else 1`, so DIGITAL scores the PHONE
   value. Written as three numbers rather than a mode test for that reason --
   see the note on FixedModePoints. *)
procedure TContestMichiganQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

initialization
   RegisterContest(MICHQSOPARTY, TContestMichiganQP);

end.

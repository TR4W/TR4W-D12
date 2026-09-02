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

(* ARRL INTERNATIONAL DX -- WHAT CW AND PHONE SHARE.

  THE FAMILY SHAPE IS TR4QT'S, and deliberately so. NY4I pointed at
  src/contests/ARRLDXBase.{h,cpp} with ARRLDXCWContest and ARRLDXPhoneContest
  beside it: a base holding the rules both modes share, and a thin subclass per
  mode carrying only identity and mode validation. That is the right
  decomposition and there is no reason to invent a different one.

  WHAT IS TAKEN FROM TR4QT IS THE STRUCTURE, NOT THE RULES. The standing note on
  that project is that it is useful ABOVE the engine and is "never" an authority
  on scoring, multipliers or exchange -- it is a reimplementation, not a
  specification, and not independent corroboration of anything.

  AND THE TWO PROGRAMS GENUINELY DIFFER HERE, WHICH IS WHY THAT MATTERS.
  TR4QT's ARRLDXBase says "W/VE stations may ONLY work DX stations", and it
  means it literally -- NY4I, 2026-09-02: "when TR4QT says we do not work them,
  we never been we will not allow it to be logged. But they would be zero
  points as TR4W does today." TR4QT REFUSES THE CONTACT; TR4W LOGS IT AT ZERO
  POINTS and sets InhibitMults.

  THIS CODE KEEPS TR4W'S BEHAVIOUR, and test-contest-factory.sh holds it to it
  byte for byte. Whether TR4W should instead refuse the entry is a DECISION,
  not a port detail: it changes what an operator can do at the keyboard, and it
  is the kind of thing that has to be right in a contest rather than discovered
  in one. TR4QT expresses the refusal through isValidQSO, which is on the list
  of virtuals TContestBase grows into -- so there is somewhere for it to go
  when the decision is made.

  The rules below are LOGSTUFF's ARRLDXQSOPointMethod arm, moved verbatim.

  CHOSEN AS THE FIRST FAMILY BECAUSE IT IS PROVABLE, not because it is easy.
  arrl_dx_cw_2025_ny4i is a 66-QSO golden-corpus set with a D7-written
  reference.

  THE SCORING IS THE ARRLDXQSOPointMethod ARM, MOVED VERBATIM. Not tidied, not
  restructured: the point of the first move is to show the seam carries
  behaviour unchanged, and any difference in the exported Cabrillo would then be
  the SEAM rather than an improvement someone made on the way past.

  THE RULE: W/VE WORK DX, DX WORK W/VE. Three points either way; a W station
  working another W scores nothing AND inhibits multipliers, which is the part
  worth noticing -- the arm sets InhibitMults, so scoring and multipliers are
  not as separable here as the base class's comment would like. That coupling is
  inherited from the legacy code and is left exactly as it was; untangling it is
  a change of behaviour and belongs in its own commit, against its own
  measurement. *)
unit uContestARRLDXBase;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRLDXBase = class(TContestBase)
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

procedure TContestARRLDXBase.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   (* The legacy routine reads this into a local at the top and every arm uses
      it; keeping the name makes the moved code diff-able against its origin. *)
   rxCty := aQso.QTH.CountryID;

   if (Station.MyCountry = 'K') or (Station.MyCountry = 'VE') then
      begin
      if (rxCty <> 'K') and (rxCty <> 'VE') then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 0;
         aQso.InhibitMults := True;
         end;
      end
   else if (rxCty = 'K') or (rxCty = 'VE') then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 0;
      aQso.InhibitMults := True;
      end;
end;

(* NOTHING IS REGISTERED HERE. A family base is not a contest an operator can
  select, and registering it for both modes -- which is what this unit did
  before the split -- makes "which class serves ARRL-DX-CW" answerable only by
  reading the base. Each mode registers itself, in its own unit. *)

end.

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

(* ARRL INTERNATIONAL DX -- the first contest moved into the factory.

  CHOSEN BECAUSE IT IS PROVABLE, not because it is easy. arrl_dx_cw_2025_ny4i is
  a 66-QSO golden-corpus set with a D7-written reference, so this move is
  checked byte for byte by something that was not written alongside it.

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
unit uContestARRLDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRLDX = class(TContestBase)
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

uses
   uContestRegistry;

procedure TContestARRLDX.CalculateQSOPoints(var aQso: ContestExchange);
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

initialization
   (* BOTH MODES, because they are two contests to an operator and two rows in
      ContestsArray, and share every scoring rule. One class, two
      registrations -- the radio factory's "one model, one registration" rule
      says the same thing from the other side: an operator picks ARRL-DX-CW or
      ARRL-DX-SSB, so both must be selectable, even though one class serves
      them. *)
   RegisterContest(ARRLDXCW, TContestARRLDX);
   RegisterContest(ARRLDXSSB, TContestARRLDX);

end.

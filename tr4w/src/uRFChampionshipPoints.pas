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

(* THE RUSSIAN CHAMPIONSHIP'S POINTS TABLE -- LIFTED OUT OF LOGSTUFF AT M6
  (2026-10-02), where it was ChampionshipRFPointsArray.

  The points for a contact between two Russian zones 1 to 7: row = the
  station's own zone (its MY STATE's first digit), column = the worked
  station's, indexed `myZone + (hisZone - 1) * 7`. A contact inside one zone
  scores 11, and the far corners 25.

  WHY A UNIT OF ITS OWN. The CW and SSB runnings of the Championship gained
  classes at M6 -- siblings, as the SAC pair are (design 1.5, Q7) -- and both
  score by this table; so does LOGSTUFF's ChampionshipRFMethod arm, which
  stays reachable through an operator's QSO POINT METHOD until M10. A class
  may not use the TRDOS engine (design 1.3), so the table moved to a leaf all
  three read, as uExchangeTokens was lifted at M5b. One table, copied
  nowhere: the sponsor's numbers are one fact. *)
unit uRFChampionshipPoints;

{$I tr4w.inc}

interface

const
   RFChampionshipPoints: array[1..49] of Byte =
      (
      11, 12, 13, 14, 16, 20, 25,
      12, 11, 12, 13, 15, 19, 23,
      13, 12, 11, 12, 14, 18, 21,
      14, 13, 12, 11, 12, 15, 18,
      16, 15, 14, 12, 11, 12, 14,
      20, 19, 18, 15, 12, 11, 12,
      25, 23, 21, 18, 14, 12, 11
      );

implementation

end.

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

(* CQ WORLD WIDE -- CW and SSB.

  SCORING IS BY DISTANCE, EXPRESSED AS CONTINENT AND COUNTRY:

    another continent          3
    same continent, other country, and I am NOT in North America   1
    same continent, other country, and I AM in North America       2
    own country                0

  THE NORTH AMERICA CASE IS THE ONE TO NOTICE. Within North America a
  cross-country contact is worth two rather than one, which is CQ WW's own rule
  and reads like a mistake if you meet it cold. It is not: NA has many countries
  close together, and one point would make the whole continent nearly worthless
  to work.

  OWN COUNTRY SCORES ZERO BUT IS STILL LOGGED, and still counts for
  multipliers -- unlike ARRL DX, where a same-side contact also sets
  InhibitMults. Two contests, two rules, and the difference is easy to lose when
  the arms sit next to each other in one 3,000-line case.

  THE RTTY RUNNING IS A DIFFERENT METHOD (CQWWRTTYQSOPointMethod: same continent
  and different country is 2, with no North America special case) and therefore
  a different class when it is moved. Not folded in here on the grounds that it
  is nearly the same -- "nearly" is where these go wrong. *)
unit uContestCQWWBase;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQWWBase = class(TContestBase)
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

procedure TContestCQWWBase.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else if aQso.QTH.CountryID <> Station.MyCountry then
      begin
      if Station.MyContinent <> NorthAmerica then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else
      begin
      aQso.QSOPoints := 0;
      end;
end;

end.

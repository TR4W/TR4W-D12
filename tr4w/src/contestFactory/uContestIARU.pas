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

(* IARU HF WORLD CHAMPIONSHIP.

    same ITU zone as me     1
    same continent          3
    anywhere else           5
    a society station       1

  THE ZONE IS THE ITU ZONE, and this contest is the reason TR4W now knows the
  difference. MyZone is one global holding the CQ zone, and every arm that sends
  or scores "my zone" used it -- so an IARU entrant sent the wrong number on
  every QSO until PostUnit.ZoneSentForThisContest was written. The SCORING side
  compares MyZone with the received zone, and the same confusion is latent here:
  if MyZone holds a CQ zone, the "same zone" case matches the wrong stations.
  That is a live question for the bench, not something this move changes -- the
  comparison is reproduced exactly as it was.

  A SOCIETY STATION IS RECOGNISED BY HAVING A DomesticQTH, which is how the
  exchange parser records an HQ or official's abbreviation rather than a zone
  number. Those are worth one point wherever they are.

  THE ZONE CONVERSION IS THE STATION SNAPSHOT'S, not a Val() here. The legacy arm
  does `Val(MyZone, MyZoneValue, Result)` per QSO and ignores the error code, so
  an unset or non-numeric MyZone becomes zone 0 and silently matches any station
  whose zone failed to parse the same way. TStationContext converts once and
  says whether it worked, so "no zone set" can be told from "zone 0". *)
unit uContestIARU;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestIARU = class(TContestBase)
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      function DisplayName: string; override;
   end;

implementation

uses
   uContestRegistry;

procedure TContestIARU.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.DomesticQTH <> '' then
      begin
      (* A society station -- one point wherever it is. *)
      aQso.QSOPoints := 1;
      Exit;
      end;

   if aQso.Zone = Station.MyZone then
      begin
      aQso.QSOPoints := 1;
      end
   else if aQso.QTH.Continent = Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 5;
      end;
end;

function TContestIARU.DisplayName: string;
begin
   Result := 'IARU HF World Championship';
end;

initialization
   RegisterContest(IARU, TContestIARU);

end.

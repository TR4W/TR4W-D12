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
   protected
      function GetFormatsExchange: boolean; override;
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aRSTSent: string): string; override;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aRSTReceived: string;
                                              const aHisQTH: string): string; override;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry;

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

function TContestIARU.GetDisplayName: string;
begin
   Result := 'IARU HF World Championship';
end;

(* THE EXCHANGE IS RST AND EITHER A SOCIETY ABBREVIATION OR AN ITU ZONE.

   WHICH ONE FOLLOWS FROM WHO IS SENDING, on both sides independently: a society
   station sends its abbreviation, everybody else sends a zone. So our side asks
   whether aMy.MyState is set and his side asks whether the QSO carried a QTH
   string -- the same question asked of the two stations.

   THE ZONE IS THE ITU ZONE, AND aMy.MyZone IS WHERE THAT LIVES.
   PostUnit.ZoneSentForThisContest resolves CQ-versus-ITU per contest and puts
   the answer there; Station.MyZone is the raw global and is always the CQ zone.
   Reading the snapshot here would re-break the very contest that made the
   distinction necessary. See the header of this unit.

   %-7u FOR HIS ZONE AND %-7d FOR OURS, reproduced exactly. His is a
   word from the QSO record, ours is a converted integer, and the legacy arm
   spelled them differently. The output is identical for every legal zone; the
   spellings are kept so a future reader diffing against the legacy sees no
   difference at all.

   THE SHARED ARM STAYS: RSTZoneOrDomesticQTH sits on the same body and belongs
   to contests that have no class yet. *)
function TContestIARU.GetFormatsExchange: boolean;
begin
   Result := True;
end;

function TContestIARU.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            const aRSTSent: string): string;
begin
   if aMy.MyState <> '' then
      begin
      Result := Format('%-3s %-7s', [aRSTSent, aMy.MyState]);
      end
   else
      begin
      Result := Format('%-3s %-7d', [aRSTSent, StrToIntDef(AnsiString(aMy.MyZone), 0)]);
      end;
end;

function TContestIARU.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aRSTReceived: string;
                                                const aHisQTH: string): string;
begin
   (* aQso.QTHString, not aHisQTH: the legacy arm TESTS rx.QTHString and then
      formats csQTHString, which the exporter set from it. The test and the
      value are the same source. *)
   if aQso.QTHString <> '' then
      begin
      Result := Format('%-3s %-7s', [aRSTReceived, aHisQTH]);
      end
   else
      begin
      Result := Format('%-3s %-7u', [aRSTReceived, aQso.Zone]);
      end;
end;

function TContestIARU.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                        const aQso: ContestExchange): string;
begin
   if aMy.MyState <> '' then
      begin
      Result := Format('%-3d %-7s', [aQso.RSTSent, aMy.MyState]);
      end
   else
      begin
      Result := Format('%-3d %-7d', [aQso.RSTSent, StrToIntDef(AnsiString(aMy.MyZone), 0)]);
      end;
end;

initialization
   RegisterContest(IARU, TContestIARU);

end.

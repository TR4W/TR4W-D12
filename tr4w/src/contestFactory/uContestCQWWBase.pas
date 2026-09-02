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
   protected
      function GetFormatsExchange: boolean; override;
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
   SysUtils;

(* THE EXCHANGE IS RST AND A CQ ZONE, zero-padded to two digits.

   '%-7.2d' is a width of 7 with a PRECISION of 2 -- zone 3 prints as "03",
   left-aligned in seven columns. The precision is the part that matters and the
   part that looks like a typo: CQ WW zones are conventionally two digits, and a
   log full of "3" where the sponsor expects "03" is a formatting difference a
   robot scorer sees.

   THE JIDX HALF OF THE LEGACY ARM IS NOT HERE. RSTZoneExchange is shared, and
   inside it `if Contest in [JIDXSSB, JIDXCW]` takes the zone from MyState
   instead -- that is JIDX's rule and stays in the legacy case until JIDX has a
   class. *)
(* THE ZONE COMES FROM aMy, NOT FROM Station.MyZone, and that is not
   interchangeable. PostUnit.ZoneSentForThisContest decides which zone a contest
   actually sends -- the ITU zone for an ITUZones contest, the CQ zone
   otherwise -- and puts the answer in aMy.MyZone. Station.MyZone is the raw
   global, which is always the CQ zone. Reading the snapshot here would undo
   that fix for every ITU contest that later shares this shape.

   AnsiString() EXPLICITLY: StrToIntDef resolves to the AnsiString overload, so a
   bare call narrows implicitly. A zone is ASCII digits, so the conversion is
   safe; saying so is the point. *)
function TContestCQWWBase.GetFormatsExchange: boolean;
begin
   Result := True;
end;

function TContestCQWWBase.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aRSTSent: string): string;
begin
   Result := Format('%-3s %-7.2d', [aRSTSent, StrToIntDef(AnsiString(aMy.MyZone), 0)]);
end;

function TContestCQWWBase.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aRSTReceived: string;
                                           const aHisQTH: string): string;
begin
   Result := Format('%-3s %-7.2d', [aRSTReceived, aQso.Zone]);
end;

function TContestCQWWBase.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string;
begin
   Result := Format('%-3d %-7.2d', [aQso.RSTSent, StrToIntDef(AnsiString(aMy.MyZone), 0)]);
end;

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

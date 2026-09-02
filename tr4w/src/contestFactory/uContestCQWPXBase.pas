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

(* CQ WPX -- CW and SSB.

  SCORING IS BY BAND AS WELL AS DISTANCE, which is what makes it different from
  CQ WW: the low bands are worth more, because they are harder.

    another continent          160/80/40: 6    20/15/10: 3
    same continent, other country          2               1, DOUBLED in NA
    own country                1

  THE NORTH AMERICA DOUBLING IS WRITTEN AS `Points := Points + Points` in the
  legacy arm and is kept as a doubling here rather than being folded into the
  band table. It applies only to the same-continent branch, and writing it out
  as four more numbers would hide that it is one rule.

  BANDS OUTSIDE 160-10 SCORE NOTHING, and that is inherited rather than chosen:
  the legacy `case RXData.Band of` lists six bands and has no else, so WARC and
  VHF fall through with QSOPoints left at the 0 the routine set on entry. CQ WPX
  is not run on those bands, so the case does not arise in a real log -- but the
  behaviour is reproduced exactly rather than "improved" into a default, because
  an improvement here would be a scoring change nobody asked for.

  Band 160 through Band10 is written out because the enum's ORDER is not a
  contract: a range test would silently include anything inserted between them. *)
unit uContestCQWPXBase;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQWPXBase = class(TContestBase)
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

(* THE EXCHANGE IS RST AND A SERIAL NUMBER.

   THE SENT WIDTH IS COMPUTED, NOT CONSTANT, and that is issue 177 rather than
   cleverness: '%.*d' with a precision of `3 - Ord(nrSent < 0)` gives C's '%03d'
   semantics, where the SIGN counts inside the width. -1 prints as "-01", not
   "-001". Delphi's '%.3d' pads DIGITS and would print "-001", so the two differ
   for exactly the negative sentinel that means "no serial".

   The ADIF side uses a plain '%03d' because ADIF is not column-aligned and the
   legacy arm never applied the sign rule there. *)
function TContestCQWPXBase.GetFormatsExchange: boolean;
begin
   Result := True;
end;

function TContestCQWPXBase.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aRSTSent: string): string;
begin
   Result := Format('%-3s %.*d ', [aRSTSent, 3 - Ord(aQso.NumberSent < 0), aQso.NumberSent]);
end;

function TContestCQWPXBase.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aRSTReceived: string;
                                           const aHisQTH: string): string;
begin
   Result := Format('%-3s %-3.3u', [aRSTReceived, aQso.NumberReceived]);
end;

function TContestCQWPXBase.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string;
begin
   Result := Format('%-3d %03d ', [aQso.RSTSent, aQso.NumberSent]);
end;

procedure TContestCQWPXBase.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 0;

   if aQso.QTH.Continent = Station.MyContinent then
      begin
      if aQso.QTH.CountryID = Station.MyCountry then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         case aQso.Band of
            Band160, Band80, Band40:
               begin
               aQso.QSOPoints := 2;
               end;
            Band20, Band15, Band10:
               begin
               aQso.QSOPoints := 1;
               end;
            end;

         if Station.MyContinent = NorthAmerica then
            begin
            aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
            end;
         end;
      end
   else
      begin
      case aQso.Band of
         Band160, Band80, Band40:
            begin
            aQso.QSOPoints := 6;
            end;
         Band20, Band15, Band10:
            begin
            aQso.QSOPoints := 3;
            end;
         end;
      end;
end;

end.

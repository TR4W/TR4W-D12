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
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public

      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string; override;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aSessionExchange: ExchangeType): string; override;
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   end;

implementation

uses
   uADIF,
   SysUtils;

(* THE EXCHANGE IS RST AND A CQ ZONE, zero-padded to two digits.

   '%-7.2d' is a width of 7 with a PRECISION of 2 -- zone 3 prints as "03",
   left-aligned in seven columns. The precision is the part that matters and the
   part that looks like a typo: CQ WW zones are conventionally two digits, and a
   log full of "3" where the sponsor expects "03" is a formatting difference a
   robot scorer sees.

   THE JIDX HALF OF THE LEGACY ARM IS GONE. RSTZoneExchange is shared, and
   inside it `if Contest in [JIDXSSB, JIDXCW]` took the zone from MyState. It
   was dead -- the contest matrix shows JIDX always runs RSTPrefectureExchange
   -- and was deleted at M4 (2026-10-01) rather than given a class to live in. *)
(* THE ZONE COMES FROM aMy, NOT FROM Station.MyZone, and that is not
   interchangeable. PostUnit.ZoneSentForThisContest decides which zone a contest
   actually sends -- the ITU zone for an ITUZones contest, the CQ zone
   otherwise -- and puts the answer in aMy.MyZone. Station.MyZone is the raw
   global, which is always the CQ zone. Reading the snapshot here would undo
   that fix for every ITU contest that later shares this shape.

   AnsiString() EXPLICITLY: StrToIntDef resolves to the AnsiString overload, so a
   bare call narrows implicitly. A zone is ASCII digits, so the conversion is
   safe; saying so is the point. *)
function TContestCQWWBase.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7.2d', [aCtx.RSTSent, StrToIntDef(AnsiString(aMy.MyZone), 0)]);
end;

function TContestCQWWBase.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                         const aQso: ContestExchange;
                                                         const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7.2d', [aCtx.RSTReceived, aQso.Zone]);
end;

function TContestCQWWBase.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 aSessionExchange: ExchangeType): string;
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

(* THE RST COMES OFF FIRST. SRX_STRING is '59 8' -- the received RST and the
   zone -- because the exporter prepends the RST to make the field symmetric
   with STX_STRING. The old code stored the whole thing as the QTH and then
   asked StrToIntDef for a zone, which answered 0 because '59 8' is not a
   number.

   AND A ZONE IS NOT A LOCATION. D7 emits no QTH for these QSOs at all;
   filling QTHString put a <QTH>59 8 into every re-exported record. The zone
   has its own field and CQZ already populates it. *)
procedure TContestCQWWBase.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                           const aSession: TADIFImportSession;
                                           var aExch: ContestExchange);
begin
   aExch.Zone := StrToIntDef(ExchangeFromSRXString(aTemps.SRX_String,
                                                   aExch.RSTReceived), 0);
end;

end.

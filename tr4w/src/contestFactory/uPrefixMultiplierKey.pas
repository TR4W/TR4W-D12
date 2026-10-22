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

(* THE PREFIX-MULTIPLIER KEYS MORE THAN ONE CONTEST COMPUTES -- HELPERS, NOT
  A RULE. M11 S3, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S3).

  Each contest's prefix multiplier is its class's own rule now
  (TContestBase.PrefixMultiplierKey): the class decides WHETHER a QSO earns a
  prefix key and WHICH computation gives it. Until S3 that rule was
  LOGEDIT.SetPrefix's `case ContestSession.PrefixMult of`, an enum choosing
  the computation FOR the contest. What is left here is the computation
  itself, where it is more than reading one field -- the design's definition
  of a helper (CONTEST_OWNERSHIP_DESIGN.md 1.3): called BY the class's own
  code, never selected for it, and holding no rule identity.

  THE THREE BODIES ARE ZONECONT'S, MOVED AS THEY STOOD, with one change of
  shape and none of behaviour:

    * IndonesianDistrict read Settings.My.Country, a global. A helper reads
      no global (design 1.3), so the entrant's country is a parameter; the
      YB DX class passes Station.MyCountry, which uContestFactory.CurrentStation
      fills from that same setting on every ActiveContest call.
    * Each name they call -- GetNumber, GetOblast, GetPrefix,
      ScandinavianCountry, IndonesianCountry -- resolved in ZoneCont to
      uCallSignRoutines' copy (Tree's GetOblast and ZoneCont's own GetNumber
      were shadowed or declared after the use), and resolves to the same
      copy here.

  WHAT IS DELIBERATELY NOT A HELPER. The arms that read one field -- the
  CTY prefix (QTH.Prefix, the WPX-style key), the callsign as the key, and the
  continent filters over the CTY prefix -- are one or two lines in each class
  that uses them. A helper for a field read would hold nothing but the
  contest's own choice, which is the class's to state (design 1.3, 1.4). *)
unit uPrefixMultiplierKey;

{$I tr4w.inc}

interface

uses
   VC;

(* WAE: the country of a non-European station, and for W, VE, VK, ZL, ZS, JA,
   PY and UA9 the country plus the call's district number. A European
   station answers ''. *)
function EuropeanCountriesAndWAECallRegions(const QTH: QTHRecord): string;

(* SAC: a Scandinavian station's country plus its call district (OH0 and OJ0
   are their own); every other station answers ''. *)
function SACDistrict(const QTH: QTHRecord): string;

(* YB DX: the WPX prefix of the call when either the worked station or the
   entrant (aMyCountry) is Indonesian; otherwise ''. *)
function IndonesianDistrict(const QTH: QTHRecord; const aMyCountry: string): string;


implementation

uses
   uCallSignRoutines;

function EuropeanCountriesAndWAECallRegions(const QTH: QTHRecord): string;
var
   NumberChar: AnsiChar;
begin
   Result := '';
   if QTH.Continent = Europe then
      begin
      Exit;
      end;
   Result := QTH.CountryID;
   (* The original comment: "W, VE, VK, ZL, ZS, JA, PY, ? ????? RA8/RA9 ?
      RA0" -- its Russian words were lost to a codepage long ago. *)
   if (QTH.CountryID = 'K')   or
      (QTH.CountryID = 'VE')  or
      (QTH.CountryID = 'VK')  or
      (QTH.CountryID = 'ZL')  or
      (QTH.CountryID = 'ZS')  or
      (QTH.CountryID = 'JA')  or
      (QTH.CountryID = 'PY')  or
      (QTH.CountryID = 'UA9') then
      begin
      NumberChar := AnsiChar(GetNumber(QTH.StandardCall));
      Result := QTH.CountryID + NumberChar;
      end;
end;

function SACDistrict(const QTH: QTHRecord): string;
var
   Oblast: Str2;
begin
   Result := '';
   if ScandinavianCountry(QTH.CountryID) then
      begin
      Oblast := GetOblast(QTH.StandardCall);
      if length(Oblast) = 0 then
         begin
         Oblast := '0';
         end;
      Result := QTH.CountryID + Oblast[1];
      if (QTH.CountryID = 'OH0') or (QTH.CountryID = 'OJ0') then
         begin
         Result := QTH.CountryID;
         end;
      end;
end;

function IndonesianDistrict(const QTH: QTHRecord; const aMyCountry: string): string;
begin
   Result := '';
   if IndonesianCountry(QTH.CountryID) or IndonesianCountry(aMyCountry) then
      begin
      Result := GetPrefix(QTH.StandardCall);
      end;
end;

end.

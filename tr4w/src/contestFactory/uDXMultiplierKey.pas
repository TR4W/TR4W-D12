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

(* THE COUNTRY LISTS MORE THAN ONE CONTEST'S DX MULTIPLIER EXCLUDES -- HELPERS,
  NOT A RULE. M11 S4, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S4).

  Each contest's DX multiplier is its class's own rule now
  (TContestBase.DXMultiplierKey): the class decides WHETHER a QSO earns a DX
  key and from which countries. Until S4 that rule was LOGDUPE.GetDXQTH's
  `case ContestSession.DXMult of`, an enum choosing the countries FOR the
  contest. What is left here is a set of countries several sponsors happen to
  exclude alike -- the design's definition of a helper
  (CONTEST_OWNERSHIP_DESIGN.md 1.3): called BY the class's own code, never
  selected for it, and holding no rule identity. A class stops calling one the
  day its sponsor's list changes.

  EACH BODY IS ITS ARM'S TEST, AS IT STOOD, inverted to say "is it one of
  these" (the arm assigned when it was NOT). The country is a ShortString, as
  the arm's field was, so no comparison here converts or allocates a string
  the arm did not.

  ONE KEY IS A HELPER TOO (issue #136, 2026-10-27): every country but K, VE,
  KH6 and KL, which ten contests keyed with the same body. The contest still
  passes whether it counts one -- see DXCCKeyExceptUSACanadaHawaiiAlaska.

  WHAT IS DELIBERATELY NOT A HELPER. Every other country (the key is the CTY
  country), a continent filter (WAE's Europe), a one-country exclusion (JT,
  ARI's first letter), UBA's and the Black Sea lists (uCallSignRoutines
  already holds them, one contest each) and PACC's own key: each is one or two
  lines in the one class that uses it, and a helper would hold nothing but
  that contest's choice (design 1.3, 1.4). *)
unit uDXMultiplierKey;

{$I tr4w.inc}

interface

uses
   VC;

(* THE USA OR CANADA -- the CTY countries K and VE. ARRL DX (for a W/VE
   entrant), the CQ 160, the Arizona, Florida and Idaho QSO parties and the
   Salmon Run (inside Washington) count every other country. *)
function IsUSAOrCanadaCountry(const aCountryID: ShortString): boolean;

(* THE USA, CANADA, HAWAII OR ALASKA -- K, VE, KH6 and KL. ARCI, and the
   Delaware, New England, 7th-area and Texas QSO parties for an entrant
   inside them, count every other country. *)
function IsUSACanadaHawaiiOrAlaskaCountry(const aCountryID: ShortString): boolean;

(* AN ARRL SECTION COUNTRY -- uCallSignRoutines.ARRLSectionCountryString (K,
   VE and the US possessions). ARRL 10, Winter Field Day and ARRL 160 (for an
   entrant in one) count every other country. *)
function IsARRLSectionCountry(const aCountryID: ShortString): boolean;

(* A NORTH AMERICAN COUNTRY OTHER THAN THE USA, CANADA OR ALASKA -- the
   NAQP, NA Sprint, Internet Sprint and SST multiplier countries. *)
function IsNorthAmericanDXCountry(const aCountryID: ShortString;
                                  aContinent: ContinentType): boolean;

(* A DXCC MULTIPLIER OF EVERY COUNTRY BUT THE USA, CANADA, HAWAII AND ALASKA
   -- the KEY, not only the country list. Issue #136, 2026-10-27: ten
   contests carried this body word for word -- the Delaware, Florida,
   Nebraska, New Mexico, Oklahoma, Texas and Ontario QSO parties (on
   TContestStateQSOPartyBase since 926617b3), and the 7QP, the New England
   QSO Party and ARCI (on TContestBase, which could not reach the party
   base's copy). It lives here so every contest calls ONE routine.

   WHETHER THE CONTEST COUNTS ONE, AND FOR WHICH ENTRANTS, STAYS THE
   CLASS'S: it passes its own answer as aCounts (the 7QP and most parties
   ask Station.InHostState, New England asks for a New England entrant,
   Florida and ARCI count for every entrant and pass True), and states its
   own HasDXMultiplier. With aCounts, the key is the worked station's CTY
   country unless IsUSACanadaHawaiiOrAlaskaCountry; without, no key. aKey is
   '' whenever the answer is False, which is "leave the DX QTH as it was"
   (TContestBase.DXMultiplierKey).

   DXCCCountryMode is the list that key is counted on: DXCC (the ARRL list)
   where the contest counts it, the CQ list where it does not. Pinned by
   uTestDXMultiplierKey. *)
function DXCCKeyExceptUSACanadaHawaiiAlaska(aCounts: boolean;
                                            const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
function DXCCCountryMode(aCounts: boolean): CountryModeType;

implementation

uses
   uCallSignRoutines;

function IsUSAOrCanadaCountry(const aCountryID: ShortString): boolean;
begin
   Result := (aCountryID = 'K') or (aCountryID = 'VE');
end;

function IsUSACanadaHawaiiOrAlaskaCountry(const aCountryID: ShortString): boolean;
begin
   Result := (aCountryID = 'K')   or
             (aCountryID = 'VE')  or
             (aCountryID = 'KH6') or
             (aCountryID = 'KL');
end;

function IsARRLSectionCountry(const aCountryID: ShortString): boolean;
begin
   Result := pos(' ' + aCountryID + ' ', ARRLSectionCountryString) <> 0;
end;

function IsNorthAmericanDXCountry(const aCountryID: ShortString;
                                  aContinent: ContinentType): boolean;
begin
   Result := (aContinent = NorthAmerica) and
             (aCountryID <> 'K')         and
             (aCountryID <> 'VE')        and
             (aCountryID <> 'KL');
end;

(* Every DXCC country but K, VE, KH6 and KL, where the contest counts one --
   see the declaration. *)
function DXCCKeyExceptUSACanadaHawaiiAlaska(aCounts: boolean;
                                            const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if aCounts and
      not IsUSACanadaHawaiiOrAlaskaCountry(aQso.QTH.CountryID) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

function DXCCCountryMode(aCounts: boolean): CountryModeType;
begin
   if aCounts then
      begin
      Result := ARRLCountryMode;
      end
   else
      begin
      Result := CQCountryMode;
      end;
end;

end.

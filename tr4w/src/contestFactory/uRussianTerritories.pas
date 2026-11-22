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

(* THE RUSSIAN TERRITORIES A CALL NAMES, AND A RUSSIAN STATION'S OBLAST FROM
  ITS CALL WITH THEM.

  LIFTED VERBATIM FROM uContestRussianDX (issue 57, 2026-11-22) when the
  RU3AX Memorial became its second user: the RDXC's rule 7.3 (2027) and the
  RU3AX Memorial's rule 7.1 (2025: "Separate Russian Oblasts are Franz Joseph
  (R1FJ) and Russian stations in Antarctica (R1AN)") name the same two
  territories by call, and a copy would drift. The names keep their RDXC
  spelling so the Russian DX class reads exactly as it did.

  WHAT IS NOT HERE, ON PURPOSE: what each contest DOES with a territory. The
  RDXC scores one as European Russia and keys FJL / RI1AN as DXCC territories
  of their own (its rule 7.3); the RU3AX Memorial says nothing of the kind,
  so it keys the plain CTY.DAT country. Those rules stay in their classes. *)
unit uRussianTerritories;

{$I tr4w.inc}

interface

type
   (* THE THREE TERRITORIES A RUSSIAN CONTEST'S RULES NAME -- each its own
      oblast. *)
   TRDXCTerritory = (rdxcNone, rdxcKaliningrad, rdxcFranzJosefLand, rdxcRussianAntarctica);

const
   (* CTY.DAT's ids for the two non-CTY-entity territories: Franz Josef
      Land's entity, and Antarctica's -- RI1AN... is "a separate DXCC
      territory" in the RDXC, and Antarctica is the DXCC entity it stands in. *)
   FRANZ_JOSEF_LAND_ENTITY = 'R1FJ';
   ANTARCTICA_ENTITY       = 'CE9';
   KALININGRAD_ENTITY      = 'UA2';

(* WHICH TERRITORY, IF ANY. The rules name RI1FJ... and RI1AN... by CALL, so
   the call decides for those two -- whatever CTY.DAT resolves it to.
   MEASURED 2026-10-22 with the shipped CTY.DAT, in both country modes:
   RI1FJA, RI1FJL, R1FJL and RI1ANA all resolve to UA (ctyLocateCall rewrites
   R[B-Z] to RA before its prefix walk, so CTY's RI1F and RI1AN prefixes are
   never reached); only the exact =RI1ANC/=RI1ANI/=RI1ANY reach CE9.
   Kaliningrad is a CTY.DAT entity of its own, so the country decides; so
   does Franz Josef Land's entity for a call CTY.DAT files there. *)
function RDXCTerritoryOf(const aCall: string; const aCountryID: string): TRDXCTerritory;

(* A STATION'S OBLAST FROM ITS CALL: the FJ and AN territories, then the one
   rule (Q50), uCallSignRoutines.RussianStationOblast -- which reads R1FJ's
   '1F' as St Petersburg and knows nothing of RI1AN. '' for a station that is
   not Russian, and for a call holding '/' (the one rule's answer). *)
function RDXCOblastFromCall(const aCall: string; const aCountryID: string): string;

implementation

uses
   SysUtils,
   (* RussianStationOblast -- the one oblast rule (Q50). *)
   uCallSignRoutines;

function RDXCTerritoryOf(const aCall: string; const aCountryID: string): TRDXCTerritory;
var
   call: string;
begin
   call := UpperCase(Trim(aCall));
   if Copy(call, 1, 5) = 'RI1AN' then
      begin
      Result := rdxcRussianAntarctica;
      end
   else if (Copy(call, 1, 5) = 'RI1FJ') or (aCountryID = FRANZ_JOSEF_LAND_ENTITY) then
      begin
      Result := rdxcFranzJosefLand;
      end
   else if aCountryID = KALININGRAD_ENTITY then
      begin
      Result := rdxcKaliningrad;
      end
   else
      begin
      Result := rdxcNone;
      end;
end;

function RDXCOblastFromCall(const aCall: string; const aCountryID: string): string;
begin
   case RDXCTerritoryOf(aCall, aCountryID) of
      rdxcRussianAntarctica:
         begin
         Result := 'AN';
         end;
      rdxcFranzJosefLand:
         begin
         Result := 'FJ';
         end;
   else
      begin
      Result := RussianStationOblast(aCall, aCountryID);
      end;
   end;
end;

end.

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

(* THE MY-EXCHANGE AS ADIF SEES IT -- NAMED HELPERS, ONE PER DISTINCT OUTPUT.
  M11 S9b, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S9b; NY4I's ruling
  on Q92, option 2).

  WHAT IT REPLACES. FormatADIFExchangeOfKind was a `case` over the session's
  exchange shape (ExchangeType) with one arm per shape -- the third of the
  four exchange-shape machines. It was TContestBase's default, so every
  contest without an override of its own reached it through the base. Now
  each contest class states its STX_STRING (TContestBase.FormatADIFSentExchange,
  through the protected GetADIFSentExchange) by CALLING one of the helpers
  below. No enum selects a helper, and nothing here names a contest or an
  exchange shape (CONTEST_OWNERSHIP_DESIGN.md 1.3).

  ONE HELPER PER OUTPUT, NOT PER SHAPE. The classes that reached the
  machine run 49 shapes; the 26 arms that built a string printed 22 distinct
  layouts for them, because several arms already shared a body ('%-3d %-7s'
  of the RST and the state served five). A helper per shape would have been
  that body written five times. A helper is named for what it prints.

  EACH BODY IS ITS ARM, AS IT STOOD -- INCLUDING THE WIDTH OF WHAT IT READS.
  The machine copied MY STATE, MY NAME, MY GRID, MY PARK and MY ZONE into
  ShortStrings first (twenty characters, a grid seven, a park ten), so a
  longer value was cut before it reached the format. The Clipped... functions
  below do the same cut, so a helper prints exactly what the arm printed for
  every input; the pin (uTestADIFSentExchange) feeds a 26-character state to
  prove it.

  THE ARMS NO REGISTERED CONTEST REACHED went with the machine: the n4af
  RSTQSONumberOrDomesticQTH arm and QSONumberAndAge, and six labels of the
  'not yet implemented' arm. Their enum members stay until the deletion
  stage.

  THREE LAYOUTS WERE NEVER BUILT, AND ARE TRANSCRIBED, NOT FIXED (plan
  F25). The machine's format for QSONumberAndGridSquare ('%-3s' of a
  number), RSTZoneAndPossibleDomesticQTH ('%02u' of a ShortString) and
  AgeAndQSONumber (three specifiers, two arguments) raised, its own
  try/except swallowed it, and the caller got ADIFMyExchangeErrorMarker. So
  the Cup RF's three runnings, CQ WW RTTY and the Youth Championship RF
  export 'Error generating my exchange' as STX_STRING, and still do:
  ADIFSentNotBuilt is that answer, by name, for the class that owns the
  exchange to replace with the layout it means. *)
unit uADIFExchange;

{$I tr4w.inc}

interface

uses
  VC,
  SysUtils,
  uContestBase;   // TMyStationExchange and nothing else

const
  (* WHAT STX_STRING CARRIES WHEN THE EXCHANGE COULD NOT BE BUILT -- a QSO
     that is not a good one, or a format that raised. One spelling, because
     PostUnit writes it too, for a contest's own formatter that raises. *)
  ADIFMyExchangeErrorMarker = 'Error generating my exchange';

(* Each helper is one contest's STX_STRING, built from the worked QSO (the
  RST and serial SENT) and the station's own exchange. The caller has decided
  the QSO is a good one. *)

(* The grid alone: the Grid and Grid2 exchanges. *)
function ADIFSentGrid(const aMy: TMyStationExchange;
                      const aQso: ContestExchange): string;

(* The state alone: a geographic coordinate or a coordinate sum is typed into
   MY STATE. *)
function ADIFSentState(const aMy: TMyStationExchange;
                       const aQso: ContestExchange): string;

(* The park reference alone. *)
function ADIFSentPark(const aMy: TMyStationExchange;
                      const aQso: ContestExchange): string;

(* '%-3d %-7s' of the RST and the state: the Power, Age, Continent and
   Domestic-or-DX exchanges. *)
function ADIFSentRSTState(const aMy: TMyStationExchange;
                          const aQso: ContestExchange): string;

(* '%-3d %-7s' of the RST and the grid. *)
function ADIFSentRSTGrid(const aMy: TMyStationExchange;
                         const aQso: ContestExchange): string;

(* '%-3d %-5s %-7s' of the RST, the name and the state. *)
function ADIFSentRSTNameQTH(const aMy: TMyStationExchange;
                            const aQso: ContestExchange): string;

(* '%-3d %-16s' of the RST and the age (and a possible SK). *)
function ADIFSentRSTAgeSK(const aMy: TMyStationExchange;
                          const aQso: ContestExchange): string;

(* '%-3d %-4d %-7s' of the RST, the serial and the grid. *)
function ADIFSentRSTQSONumberGrid(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange): string;

(* '%-3d %03d ' of the RST and the serial. *)
function ADIFSentRSTQSONumber(const aMy: TMyStationExchange;
                              const aQso: ContestExchange): string;

(* The RST and the serial and the state: '%-3d %d%-6s' with the serial run
   into a state of TRC, '%-3d %-4d %-6s ' otherwise. *)
function ADIFSentRSTQSONumberState(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string;

(* '%-3d %-7d' of the RST and the zone as a plain number. *)
function ADIFSentRSTPrefecture(const aMy: TMyStationExchange;
                               const aQso: ContestExchange): string;

(* '%-3d %-7.2d' of the RST and the zone to two digits. *)
function ADIFSentRSTZone(const aMy: TMyStationExchange;
                         const aQso: ContestExchange): string;

(* The state when there is one, else the zone: '%-3d %-7s' or '%-3d %-7d'. *)
function ADIFSentRSTZoneOrState(const aMy: TMyStationExchange;
                                const aQso: ContestExchange): string;

(* The state when there is one, else the serial: '%-3d %-7s' or
   '%-4d %03u   '. *)
function ADIFSentRSTStateOrQSONumber(const aMy: TMyStationExchange;
                                     const aQso: ContestExchange): string;

(* '%-3d %-10s' of the RST and the previous postal code, which the export
   never had: always blank. *)
function ADIFSentRSTPostalCode(const aMy: TMyStationExchange;
                               const aQso: ContestExchange): string;

(* '%-3d %-7s' of the serial and the name. *)
function ADIFSentQSONumberName(const aMy: TMyStationExchange;
                               const aQso: ContestExchange): string;

(* '%-4d %-7s %-8s' of the serial, the name and the state -- 'DX' when the
   station has none. *)
function ADIFSentQSONumberNameState(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange): string;

(* '  %-10s %-4s' of the name and the state. *)
function ADIFSentNameState(const aMy: TMyStationExchange;
                           const aQso: ContestExchange): string;

(* '%-4s %-6d' of the state then the serial. *)
function ADIFSentStateThenQSONumber(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange): string;

(* '%-3s %03d    ' of the state then the serial. *)
function ADIFSentStateAndQSONumberSum(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange): string;

(* '  %s    %03d ' of the state then the serial. *)
function ADIFSentIndentedStateAndQSONumber(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange): string;

(* '%-.3u%-7.3d' of the previous serial received (never carried by the
   export: always 0) and the serial sent. *)
function ADIFSentQSONumberPreviousQSONumber(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange): string;

(* 'None', logged as an Error: an exchange whose STX_STRING was never
   written. Nineteen shapes were on the machine's "not yet implemented" list;
   registered contests run thirteen of them, and fourteen contests answer
   this. *)
function ADIFSentNotImplemented(const aMy: TMyStationExchange;
                                const aQso: ContestExchange): string;

(* ADIFMyExchangeErrorMarker: the answer for an exchange with no layout, and
   for the three layouts that were never built (see the unit header). The
   base class answers it too -- a contest that states nothing prints
   nothing it could be wrong about. *)
function ADIFSentNotBuilt(const aMy: TMyStationExchange;
                          const aQso: ContestExchange): string;

implementation

uses
  Log4D;   // the same single concession uCabrilloExchange makes, and for the
           // same reason: an unhandled exchange must say so.

var
  logger: TLogLogger;

(* THE MACHINE'S SHORTSTRINGS. It copied each station field into a ShortString
   of the width VC gives it, once, at the top, and every arm read the copy.
   Str20 for the state, name and zone, GridString (7) for the grid and Str10
   for the park. The cut is reproduced here so a longer value prints as it
   did. *)
function ClippedState(const aMy: TMyStationExchange): string;
begin
  Result := string(Str20(aMy.MyState));
end;

function ClippedName(const aMy: TMyStationExchange): string;
begin
  Result := string(Str20(aMy.MyName));
end;

function ClippedGrid(const aMy: TMyStationExchange): string;
begin
  Result := string(GridString(aMy.MyGrid));
end;

function ClippedPark(const aMy: TMyStationExchange): string;
begin
  Result := string(Str10(aMy.MyPark));
end;

function ClippedZone(const aMy: TMyStationExchange): integer;
begin
  Result := StrToIntDef(AnsiString(Str20(aMy.MyZone)), 0);
end;

function ADIFSentGrid(const aMy: TMyStationExchange;
                      const aQso: ContestExchange): string;
begin
  Result := ClippedGrid(aMy);
end;

function ADIFSentState(const aMy: TMyStationExchange;
                       const aQso: ContestExchange): string;
begin
  Result := ClippedState(aMy);
end;

function ADIFSentPark(const aMy: TMyStationExchange;
                      const aQso: ContestExchange): string;
begin
  Result := ClippedPark(aMy);
end;

function ADIFSentRSTState(const aMy: TMyStationExchange;
                          const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %-7s', [aQso.RSTSent, ClippedState(aMy)]);
end;

function ADIFSentRSTGrid(const aMy: TMyStationExchange;
                         const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %-7s', [aQso.RSTSent, ClippedGrid(aMy)]);
end;

function ADIFSentRSTNameQTH(const aMy: TMyStationExchange;
                            const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %-5s %-7s',
     [aQso.RSTSent, ClippedName(aMy), ClippedState(aMy)]);
end;

function ADIFSentRSTAgeSK(const aMy: TMyStationExchange;
                          const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %-16s', [aQso.RSTSent, ClippedState(aMy)]);
end;

function ADIFSentRSTQSONumberGrid(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %-4d %-7s',
     [aQso.RSTSent, aQso.NumberSent, ClippedGrid(aMy)]);
end;

(* '%03d' is a WIDTH in Pascal's Format, not a zero-pad flag: serial 7 prints
   as '  7'. Issue 177 asked for the C spelling and got this. Pinned as it
   prints. *)
function ADIFSentRSTQSONumber(const aMy: TMyStationExchange;
                              const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %03d ', [aQso.RSTSent, aQso.NumberSent]);
end;

function ADIFSentRSTQSONumberState(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string;
begin
  if ClippedState(aMy) = 'TRC' then
     begin
     Result := Format('%-3d %d%-6s',
        [aQso.RSTSent, aQso.NumberSent, ClippedState(aMy)]);
     end
  else
     begin
     Result := Format('%-3d %-4d %-6s ',
        [aQso.RSTSent, aQso.NumberSent, ClippedState(aMy)]);
     end;
end;

function ADIFSentRSTPrefecture(const aMy: TMyStationExchange;
                               const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %-7d', [aQso.RSTSent, ClippedZone(aMy)]);
end;

function ADIFSentRSTZone(const aMy: TMyStationExchange;
                         const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %-7.2d', [aQso.RSTSent, ClippedZone(aMy)]);
end;

function ADIFSentRSTZoneOrState(const aMy: TMyStationExchange;
                                const aQso: ContestExchange): string;
begin
  if ClippedState(aMy) <> '' then
     begin
     Result := Format('%-3d %-7s', [aQso.RSTSent, ClippedState(aMy)]);
     end
  else
     begin
     Result := Format('%-3d %-7d', [aQso.RSTSent, ClippedZone(aMy)]);
     end;
end;

function ADIFSentRSTStateOrQSONumber(const aMy: TMyStationExchange;
                                     const aQso: ContestExchange): string;
begin
  if ClippedState(aMy) <> '' then
     begin
     Result := Format('%-3d %-7s', [aQso.RSTSent, ClippedState(aMy)]);
     end
  else
     begin
     Result := Format('%-4d %03u   ', [aQso.RSTSent, aQso.NumberSent]);
     end;
end;

(* THE MACHINE'S POSTAL-CODE BRANCH NEVER RAN. It chose between MY POSTAL CODE
   (the first contact) and the previous QSO's, by a count (`contacts`) and a
   previous-QTH string that were variables nothing assigned, so it always
   printed the empty previous code. That is what this prints. The RoPoCo's
   postcode is the Cabrillo export's (it carries the previous QTH). *)
function ADIFSentRSTPostalCode(const aMy: TMyStationExchange;
                               const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %-10s', [aQso.RSTSent, '']);
end;

function ADIFSentQSONumberName(const aMy: TMyStationExchange;
                               const aQso: ContestExchange): string;
begin
  Result := Format('%-3d %-7s', [aQso.NumberSent, ClippedName(aMy)]);
end;

function ADIFSentQSONumberNameState(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange): string;
var
  state: string;
begin
  state := ClippedState(aMy);
  if state = '' then
     begin
     state := 'DX';
     end;
  Result := Format('%-4d %-7s %-8s', [aQso.NumberSent, ClippedName(aMy), state]);
end;

function ADIFSentNameState(const aMy: TMyStationExchange;
                           const aQso: ContestExchange): string;
begin
  Result := Format('  %-10s %-4s', [ClippedName(aMy), ClippedState(aMy)]);
end;

function ADIFSentStateThenQSONumber(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange): string;
begin
  Result := Format('%-4s %-6d', [ClippedState(aMy), aQso.NumberSent]);
end;

function ADIFSentStateAndQSONumberSum(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange): string;
begin
  Result := Format('%-3s %03d    ', [ClippedState(aMy), aQso.NumberSent]);
end;

function ADIFSentIndentedStateAndQSONumber(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange): string;
begin
  Result := Format('  %s    %03d ', [ClippedState(aMy), aQso.NumberSent]);
end;

(* The machine's `pnr` (the previous number received) was a variable nothing
   assigned: 0. *)
function ADIFSentQSONumberPreviousQSONumber(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange): string;
begin
  Result := Format('%-.3u%-7.3d', [0, aQso.NumberSent]);
end;

function ADIFSentNotImplemented(const aMy: TMyStationExchange;
                                const aQso: ContestExchange): string;
begin
  Result := 'None';
  logger.Error('[] MyExchange ADIF not yet implemented for this exchange');
end;

function ADIFSentNotBuilt(const aMy: TMyStationExchange;
                          const aQso: ContestExchange): string;
begin
  Result := ADIFMyExchangeErrorMarker;
end;

initialization
  logger := TLogLogger.GetLogger('TR4WDebugLog.ADIFExchange');

end.

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
unit uCabrilloExchange;
{$I tr4w.inc}

(* THE CABRILLO EXCHANGE COLUMNS, ONE HELPER PER DISTINCT COLUMN -- and nothing
  that names a contest, and nothing that selects by an exchange kind.

  M11 S9c (2026-10-14). Until then this unit was ONE function,
  FormatCabrilloExchangeOfKind: a `case` over the session's exchange shape
  that built both columns of a QSO: line. It is gone. Each helper below
  builds ONE column (the sent one or the received one) for one distinct
  layout, named for what it prints, and every contest class states its own
  columns by calling the two it wants from TContestBase's
  GetCabrilloSentExchange / GetCabrilloReceivedExchange (NY4I's ruling Q92,
  option 2: plain named helpers a class calls explicitly; no enum picks one).

  Sent and received are separate helpers because the machine's arms were
  written as pairs only by habit: the same received layout is paired with
  three different sent ones, and a pair per shape would have been the same
  body up to ten times.

  WHAT THE HELPERS TAKE. The same three things the machine took: the station
  (aMy), the worked QSO (aQso) and what the exporter decided about it before
  asking (aCtx -- the formatted RSTs, the his-QTH it selected, the previous
  record's values). None of it is the session's exchange: the field that
  carried it is gone from TCabrilloQSOContext.

  THE WIDTHS ARE THE CONTRACT. Cabrillo is a column format and these strings
  are what a robot scorer reads, so every Format string below is the arm's,
  trailing spaces included. uTestCabrilloColumns pins each helper's text
  literally, and every contest's two columns at the seven roster stations.

  EVERY RULE THAT BELONGED TO ONE CONTEST is that contest class's override
  (since M4), not a branch here:

    FOC Marathon's membership number      TContestFOCMarathon
    Ukraine Championship / Ural Cup order TContestUkraineChampionship,
                                          TContestUralCup
    UK/EI '--', RSGB IOTA '------'        TContestUKEI, TContestRSGBIOTA
    DARC 10 m's received column           TContestDARC10M
    PACC's serial in the state column     TContestPACC
    PCC's own sent branch                 TContestPCC

  TWO TESTS STAY, AND THEY NAME NO CONTEST: `MyState = 'TRC'` and
  `ContestTitle = 'PGA'` (CabrilloSentRSTQSONumberState and
  CabrilloReceivedRSTQSONumberQTH). They are operator-driven hooks for two
  events that have no ContestType (inventory D7, design Q8 -- NY4I's, open),
  so there is no class they could move to.

  THE ARMS THAT WENT WITH THE MACHINE, none reached by a registered contest
  (measured against the frozen matrix's session exchanges): QSONumberAndAge
  (Age QSONumber), RSTAndGrid3 (RST, grid) and RSTQSONumberOrDomesticQTH
  (n4af 4.40.6). Their ExchangeType members stay for the deletion stage.

  A CONTEST THAT HAS NO COLUMN LAYOUT prints CabrilloExchangeErrorMarker in
  both columns, loudly, rather than blanks (Issue #1043): fifteen registered
  contests run a shape the machine never had an arm for (ALL JA, ARCI,
  County Hunter, FISTS, Grid Loc, JA Long Prefecture, Kids Day, NZ Field Day,
  POTA, QCWA, QCWA Golden, TEN-TEN, the UA4W Championship, WWL and Xmas), and
  so does the classless DUMMYCONTEST. Each registered one states the marker
  BY NAME (CabrilloSentNotHandled); the base answers it for a contest that
  states nothing. TContestBase.FormatCabrilloSentExchange logs the Error --
  it knows the contest's name; a helper does not. *)

interface

uses
  VC,
  SysUtils,
  (* TMyStationExchange and TCabrilloQSOContext. uContestBase uses this unit
     back from its implementation, for the default it delegates to. *)
  uContestBase;

type
  (* DECLARED IN uContestBase, aliased so callers and tests that know this
     unit keep compiling. Two records that differ by one field are two records
     that drift; there is one of each. *)
  TMyStationExchange = uContestBase.TMyStationExchange;
  TCabrilloQSOContext = uContestBase.TCabrilloQSOContext;

const
  (* Both columns, for an exchange with no layout (Issue #1043). PostUnit
     uppercases the received column, so the marker is all caps to keep the two
     identical. *)
  CabrilloExchangeErrorMarker = 'ERROR EXCHANGE NOT HANDLED';

(* ---- THE SENT COLUMN ----------------------------------------------------- *)

(* '%-11s' of the grid. *)
function CabrilloSentGrid(const aMy: TMyStationExchange;
                          const aQso: ContestExchange;
                          const aCtx: TCabrilloQSOContext): string;

(* RST, name, state: '%-3s %-5s %-7s'. *)
function CabrilloSentRSTNameState(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;

(* Serial, name: '%-3d %-7s'. *)
function CabrilloSentQSONumberName(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange;
                                   const aCtx: TCabrilloQSOContext): string;

(* RST and a postal code: our own on the first record, otherwise the one the
   previous record carried (RSGB RoPoCo). '%-3s %-10s'. *)
function CabrilloSentRSTPostalCode(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange;
                                   const aCtx: TCabrilloQSOContext): string;

(* RST, serial, grid: '%-3s %-4.4d %-7s'. *)
function CabrilloSentRSTQSONumberGrid(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;

(* RST and the zone as a plain number: '%-3s %-7d' (the JIDX prefecture
   shape's sent side). *)
function CabrilloSentRSTZoneNumber(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange;
                                   const aCtx: TCabrilloQSOContext): string;

(* Name and state, indented: '  %-10s %-4s'. *)
function CabrilloSentNameState(const aMy: TMyStationExchange;
                               const aQso: ContestExchange;
                               const aCtx: TCabrilloQSOContext): string;

(* Serial, name, state -- 'DX' when we have none: '%-4d %-7s %-8s'. *)
function CabrilloSentQSONumberNameStateDX(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string;

(* RST and the state in a 16-wide column: '%-3s %-16s' (the SKCC-style
   age-and-possible-SK shape). *)
function CabrilloSentRSTStateWide(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;

(* RST and the state: '%-3s %-7s'. Five shapes print this. *)
function CabrilloSentRSTState(const aMy: TMyStationExchange;
                              const aQso: ContestExchange;
                              const aCtx: TCabrilloQSOContext): string;

(* RST and the state -- 'DX' when we have none: '%-3s %-7s'. *)
function CabrilloSentRSTStateOrDX(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;

(* The state -- 'DX' when we have none -- and NO RST: '%-7s'. The
   location-only column (Wisconsin's Cabrillo page: "RST columns are not
   needed"; #88, 2026-10-26). *)
function CabrilloSentStateOrDX(const aMy: TMyStationExchange;
                               const aQso: ContestExchange;
                               const aCtx: TCabrilloQSOContext): string;

(* RST and the grid: '%-3s %-7s'. *)
function CabrilloSentRSTGrid(const aMy: TMyStationExchange;
                             const aQso: ContestExchange;
                             const aCtx: TCabrilloQSOContext): string;

(* State, serial (the age-and-serial shape): '%-2s %.*d '. *)
function CabrilloSentStateQSONumber2(const aMy: TMyStationExchange;
                                     const aQso: ContestExchange;
                                     const aCtx: TCabrilloQSOContext): string;

(* Serial, state cut to four: '%.*d %-6.4s '. *)
function CabrilloSentQSONumberStateShort(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;

(* Serial, state: '%-4d %-6s'. *)
function CabrilloSentQSONumberState(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;

(* State, serial (the Ukraine Championship and the Ural Cup put the QTH
   first): '%-4s %-6.4d'. *)
function CabrilloSentStateQSONumber(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;

(* RST, serial, state, with the TRC and PGA events' own layouts. *)
function CabrilloSentRSTQSONumberState(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;

(* RST, zone, state -- 'DX' when we have none: '%-3s %.2u %-4s'. *)
function CabrilloSentRSTZoneStateDX(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;

(* RST and the state, or the zone when we have no state. *)
function CabrilloSentRSTStateOrZone(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;

(* State, serial (the coordinates-sum shape): '%-3s %3.4d    '. *)
function CabrilloSentStateQSONumberSum(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;

(* Serial, state (the geo-coordinates shape): '%-3.4d %-7s '. *)
function CabrilloSentQSONumberGeoState(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;

(* RST, serial: '%-3s %.*d '. *)
function CabrilloSentRSTQSONumber(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;

(* Zone, serial (the zone-and-serial shape): '  %s    %3.4d '. *)
function CabrilloSentStateZoneQSONumber(const aMy: TMyStationExchange;
                                        const aQso: ContestExchange;
                                        const aCtx: TCabrilloQSOContext): string;

(* RST and the zone, two digits: '%-3s %-7.2d'. *)
function CabrilloSentRSTZone(const aMy: TMyStationExchange;
                             const aQso: ContestExchange;
                             const aCtx: TCabrilloQSOContext): string;

(* The previous record's serial received, then our serial: '%-.3u%-7.4d'
   (Radio YOC). *)
function CabrilloSentQSONumberPreviousQSONumber(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aCtx: TCabrilloQSOContext): string;

(* RST and the state, or the serial when we have no state. *)
function CabrilloSentRSTStateOrQSONumber(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;

(* CabrilloExchangeErrorMarker. *)
function CabrilloSentNotHandled(const aMy: TMyStationExchange;
                                const aQso: ContestExchange;
                                const aCtx: TCabrilloQSOContext): string;

(* ---- THE RECEIVED COLUMN ------------------------------------------------- *)

(* '%-11s' of the his-QTH the exporter selected. *)
function CabrilloReceivedGrid(const aMy: TMyStationExchange;
                              const aQso: ContestExchange;
                              const aCtx: TCabrilloQSOContext): string;

(* RST, name, his-QTH: '%-3s %-5s %-7s'. *)
function CabrilloReceivedRSTNameQTH(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;

(* Serial, name: '%-3u %-7s'. *)
function CabrilloReceivedQSONumberName(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;

(* RST and the postal code as logged: '%-3s %-10s'. *)
function CabrilloReceivedRSTPostalCode(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;

(* RST, serial, his-QTH: '%-3s %-4.4u %-7s'. *)
function CabrilloReceivedRSTQSONumberGrid(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string;

(* RST and his-QTH: '%-3s %-7s'. *)
function CabrilloReceivedRSTQTH(const aMy: TMyStationExchange;
                                const aQso: ContestExchange;
                                const aCtx: TCabrilloQSOContext): string;

(* Name and his-QTH, indented: '  %-10s %-4s'. *)
function CabrilloReceivedNameQTH(const aMy: TMyStationExchange;
                                 const aQso: ContestExchange;
                                 const aCtx: TCabrilloQSOContext): string;

(* Serial, name, his-QTH -- 'DX' when the QSO has none: '%-4u %-5s %-4s'. *)
function CabrilloReceivedQSONumberNameQTHDX(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            const aCtx: TCabrilloQSOContext): string;

(* RST, age, his-QTH: '%-3s %u %s'. *)
function CabrilloReceivedRSTAgeQTH(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange;
                                   const aCtx: TCabrilloQSOContext): string;

(* RST and age: '%-3s %-7u'. *)
function CabrilloReceivedRSTAge(const aMy: TMyStationExchange;
                                const aQso: ContestExchange;
                                const aCtx: TCabrilloQSOContext): string;

(* Age and serial: ' %-3d %.*d'. *)
function CabrilloReceivedAgeQSONumber(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;

(* RST and the QSO's OWN Power, not the his-QTH the exporter selected:
   '%-3s %-7s'. FOC Marathon keeps its membership number there. *)
function CabrilloReceivedRSTPower(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;

(* Serial, his-QTH (the grid-square shape): '%3.4u %-6s'. *)
function CabrilloReceivedQSONumberQTHShort(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string;

(* Serial, his-QTH: '%-4.4u %-6s'. *)
function CabrilloReceivedQSONumberQTH(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;

(* His-QTH, serial (the Ukraine Championship and the Ural Cup put the QTH
   first): '%-4s %-6.4u'. *)
function CabrilloReceivedQTHQSONumber(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;

(* RST, serial, his-QTH, with the PGA and TRC events' own layouts. *)
function CabrilloReceivedRSTQSONumberQTH(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;

(* RST, zone, his-QTH -- 'DX' when the QSO has none: '%-3s %.2u %-3s'. *)
function CabrilloReceivedRSTZoneQTHDX(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;

(* RST and his-QTH, or his zone when the QSO has no QTH. *)
function CabrilloReceivedRSTQTHOrZone(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;

(* His-QTH, serial (the coordinates-sum shape): '%-3s %3.4u'. *)
function CabrilloReceivedQTHQSONumberSum(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;

(* Serial, his-QTH (the geo-coordinates shape): '%-3.4u %-7s'. *)
function CabrilloReceivedQSONumberGeoQTH(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;

(* RST and serial: '%-3s %-3.3u'. *)
function CabrilloReceivedRSTQSONumber(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;

(* RST and the QSO's own QTH (the continent): '%-3s %-7s'. *)
function CabrilloReceivedRSTContinent(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;

(* RST and his-QTH -- 'DX' when the QSO has none: '%-3s %-7s'. *)
function CabrilloReceivedRSTQTHDX(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;

(* His-QTH -- 'DX' when the QSO has none -- and NO RST: '%-7s'. The
   location-only column (Wisconsin, #88). *)
function CabrilloReceivedQTHDX(const aMy: TMyStationExchange;
                               const aQso: ContestExchange;
                               const aCtx: TCabrilloQSOContext): string;

(* RST and his-QTH -- when the QSO has none, its DX QTH, or 'DX':
   '%-3s %-7s'. *)
function CabrilloReceivedRSTQTHOrDXQTH(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;

(* RST and his-QTH when it is a DOMESTIC QTH -- one the session's table knew
   when the QSO was logged, so the record carries a DomesticQTH -- else 'DX':
   '%-3s %-7s'. For a sponsor whose QTH column is "county ... or two-letter
   State/Province abbreviation, or "DX"" while a DX station SENDS its DXCC
   entity on the air (the New Mexico QSO Party, 2026-10-26): what was typed
   for such a station ("599 LY") is not written. CabrilloReceivedRSTQTHDX
   tests QTHString instead, so a typed DX QTH there leaves the column as the
   exporter's HisQTH -- empty unless LITERAL DOMESTIC QTH. *)
function CabrilloReceivedRSTDomesticQTHOrDX(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            const aCtx: TCabrilloQSOContext): string;

(* Zone, serial (the zone-and-serial shape): '  %-4u   %.3d'. *)
function CabrilloReceivedZoneQSONumber(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;

(* RST and zone, two digits: '%-3s %-7.2d'. *)
function CabrilloReceivedRSTZone(const aMy: TMyStationExchange;
                                 const aQso: ContestExchange;
                                 const aCtx: TCabrilloQSOContext): string;

(* The received serial split in two: '%-.4d%-.4d' (Radio YOC). *)
function CabrilloReceivedQSONumberPreviousQSONumber(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;

(* RST and his-QTH, or the serial when the QSO has no QTH. *)
function CabrilloReceivedRSTQTHOrQSONumber(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string;

(* CabrilloExchangeErrorMarker. *)
function CabrilloReceivedNotHandled(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;

(* The serial sign rule several shapes share: a negative serial prints three
   (or four) digits including the sign. Public since 2026-10-14 so the ADIF
   STX_STRING of the five F25 contests (uADIFExchange) prints the same serial
   their Cabrillo column does, from one function. *)
function SerialWidth(aNumber, aWidth: integer): integer;

implementation

(* See the declaration. *)
function SerialWidth(aNumber, aWidth: integer): integer;
begin
  Result := aWidth - Ord(aNumber < 0);
end;

(* A ZONE FIELD AS THE MACHINE READ IT: MY ZONE is text, and an unreadable one
   is zero. *)
function MyZoneNumber(const aMy: TMyStationExchange): integer;
begin
  Result := StrToIntDef(aMy.MyZone, 0);
end;

function CabrilloSentGrid(const aMy: TMyStationExchange;
                          const aQso: ContestExchange;
                          const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-11s', [aMy.MyGrid]);
end;

function CabrilloSentRSTNameState(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-5s %-7s', [aCtx.RSTSent, aMy.MyName, aMy.MyState]);
end;

function CabrilloSentQSONumberName(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange;
                                   const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3d %-7s', [aQso.NumberSent, aMy.MyName]);
end;

function CabrilloSentRSTPostalCode(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange;
                                   const aCtx: TCabrilloQSOContext): string;
begin
  if aCtx.RecordNumber = 1 then
     begin
     Result := SysUtils.Format('%-3s %-10s', [aCtx.RSTSent, aMy.MyPostalCode]);
     end
  else
     begin
     Result := SysUtils.Format('%-3s %-10s', [aCtx.RSTSent, aCtx.PreviousQTH]);
     end;
end;

function CabrilloSentRSTQSONumberGrid(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-4.4d %-7s', [aCtx.RSTSent, aQso.NumberSent, aMy.MyGrid]);
end;

function CabrilloSentRSTZoneNumber(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange;
                                   const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-7d', [aCtx.RSTSent, MyZoneNumber(aMy)]);
end;

function CabrilloSentNameState(const aMy: TMyStationExchange;
                               const aQso: ContestExchange;
                               const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('  %-10s %-4s', [aMy.MyName, aMy.MyState]);
end;

function CabrilloSentQSONumberNameStateDX(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string;
var
  state: string;
begin
  state := aMy.MyState;
  if aMy.MyState = '' then
     begin
     state := 'DX';
     end;
  Result := SysUtils.Format('%-4d %-7s %-8s', [aQso.NumberSent, aMy.MyName, state]);
end;

function CabrilloSentRSTStateWide(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-16s', [aCtx.RSTSent, aMy.MyState]);
end;

function CabrilloSentRSTState(const aMy: TMyStationExchange;
                              const aQso: ContestExchange;
                              const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTSent, aMy.MyState]);
end;

(* THE STATE WE SEND, 'DX' WHEN WE HAVE NONE -- the one statement of it, for
   the RST and the location-only columns alike. *)
function SentStateOrDX(const aMy: TMyStationExchange): string;
begin
  Result := aMy.MyState;
  if aMy.MyState = '' then
     begin
     Result := 'DX';
     end;
end;

(* HIS QTH, 'DX' WHEN THE QSO HAS NONE -- the one statement of it, for the
   RST and the location-only columns alike. *)
function ReceivedQTHOrDX(const aQso: ContestExchange;
                         const aCtx: TCabrilloQSOContext): string;
begin
  Result := aCtx.HisQTH;
  if aQso.QTHString = '' then
     begin
     Result := 'DX';
     end;
end;

function CabrilloSentRSTStateOrDX(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTSent, SentStateOrDX(aMy)]);
end;

function CabrilloSentStateOrDX(const aMy: TMyStationExchange;
                               const aQso: ContestExchange;
                               const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-7s', [SentStateOrDX(aMy)]);
end;

function CabrilloSentRSTGrid(const aMy: TMyStationExchange;
                             const aQso: ContestExchange;
                             const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTSent, aMy.MyGrid]);
end;

function CabrilloSentStateQSONumber2(const aMy: TMyStationExchange;
                                     const aQso: ContestExchange;
                                     const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-2s %.*d ', [aMy.MyState, SerialWidth(aQso.NumberSent, 3),
                                           aQso.NumberSent]);
end;

function CabrilloSentQSONumberStateShort(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%.*d %-6.4s ', [SerialWidth(aQso.NumberSent, 3), aQso.NumberSent,
                                             aMy.MyState]);
end;

function CabrilloSentQSONumberState(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-4d %-6s', [aQso.NumberSent, aMy.MyState]);
end;

function CabrilloSentStateQSONumber(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-4s %-6.4d', [aMy.MyState, aQso.NumberSent]);
end;

function CabrilloSentRSTQSONumberState(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;
begin
  if aMy.MyState = 'TRC' then      // 4.63.3
     begin
     Result := SysUtils.Format('%-3s %d%-6s', [aCtx.RSTSent, aQso.NumberSent, aMy.MyState]);
     end
  else if aCtx.ContestTitle = 'PGA' then       // 4.92.4
     begin
     Result := SysUtils.Format('%-3s %3.3d%s     ', [aCtx.RSTSent, aQso.NumberSent, aMy.MyState]);
     end
  else
     begin
     Result := SysUtils.Format('%-3s %-4.4d %6s      ', [aCtx.RSTSent, aQso.NumberSent, aMy.MyState]);
     end;
end;

function CabrilloSentRSTZoneStateDX(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;
var
  state: string;
begin
  state := aMy.MyState;
  if aMy.MyState = '' then
     begin
     state := 'DX';
     end;
  Result := SysUtils.Format('%-3s %.2u %-4s', [aCtx.RSTSent, MyZoneNumber(aMy), state]);
end;

function CabrilloSentRSTStateOrZone(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;
begin
  if aMy.MyState <> '' then
     begin
     Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTSent, aMy.MyState]);
     end
  else
     begin
     Result := SysUtils.Format('%-3s %-7d', [aCtx.RSTSent, MyZoneNumber(aMy)]);
     end;
end;

function CabrilloSentStateQSONumberSum(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %3.4d    ', [aMy.MyState, aQso.NumberSent]);
end;

function CabrilloSentQSONumberGeoState(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3.4d %-7s ', [aQso.NumberSent, aMy.MyState]);
end;

function CabrilloSentRSTQSONumber(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %.*d ', [aCtx.RSTSent, SerialWidth(aQso.NumberSent, 3),
                                           aQso.NumberSent]);   // issue 177
end;

function CabrilloSentStateZoneQSONumber(const aMy: TMyStationExchange;
                                        const aQso: ContestExchange;
                                        const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('  %s    %3.4d ', [aMy.MyState, aQso.NumberSent]);
end;

function CabrilloSentRSTZone(const aMy: TMyStationExchange;
                             const aQso: ContestExchange;
                             const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-7.2d', [aCtx.RSTSent, MyZoneNumber(aMy)]);   // 4.51.1 issue#185
end;

function CabrilloSentQSONumberPreviousQSONumber(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aCtx: TCabrilloQSOContext): string;
begin
  (* THE PREVIOUS NUMBER IS CARRIED BY THE EXPORTER (aCtx), not by a var
     parameter the arm used to write back -- formatting a line changes
     nothing outside it. *)
  Result := SysUtils.Format('%-.3u%-7.4d', [aCtx.PreviousNumberReceived, aQso.NumberSent]);   // 4.72.9
end;

function CabrilloSentRSTStateOrQSONumber(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;
begin
  (* THE PCC'S BRANCHES ARE TContestPCC'S, and taking them out left this one.
     An all-digit MY STATE is never empty, so for every other contest the
     first test already took it: the '/M' branch was the PCC's alone. *)
  if aMy.MyState <> '' then      // 4.83.2
     begin
     Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTSent, aMy.MyState]);
     end
  else
     begin
     Result := SysUtils.Format('%-4s %3.4u   ', [aCtx.RSTSent, aQso.NumberSent]);  // n4af 4.43.12
     end;
end;

function CabrilloSentNotHandled(const aMy: TMyStationExchange;
                                const aQso: ContestExchange;
                                const aCtx: TCabrilloQSOContext): string;
begin
  Result := CabrilloExchangeErrorMarker;
end;

function CabrilloReceivedGrid(const aMy: TMyStationExchange;
                              const aQso: ContestExchange;
                              const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-11s', [aCtx.HisQTH]);
end;

function CabrilloReceivedRSTNameQTH(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-5s %-7s', [aCtx.RSTReceived, string(aQso.Name), aCtx.HisQTH]);
end;

function CabrilloReceivedQSONumberName(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3u %-7s', [aQso.NumberReceived, string(aQso.Name)]);
end;

function CabrilloReceivedRSTPostalCode(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-10s', [aCtx.RSTReceived, string(aQso.QTHString)]);
end;

function CabrilloReceivedRSTQSONumberGrid(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-4.4u %-7s', [aCtx.RSTReceived, aQso.NumberReceived, aCtx.HisQTH]);
end;

function CabrilloReceivedRSTQTH(const aMy: TMyStationExchange;
                                const aQso: ContestExchange;
                                const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTReceived, aCtx.HisQTH]);
end;

function CabrilloReceivedNameQTH(const aMy: TMyStationExchange;
                                 const aQso: ContestExchange;
                                 const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('  %-10s %-4s', [string(aQso.Name), aCtx.HisQTH]);
end;

function CabrilloReceivedQSONumberNameQTHDX(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            const aCtx: TCabrilloQSOContext): string;
var
  qth: string;
begin
  qth := aCtx.HisQTH;
  if aQso.QTHString = '' then
     begin
     qth := 'DX';
     end;
  Result := SysUtils.Format('%-4u %-5s %-4s', [aQso.NumberReceived, string(aQso.Name), qth]);   // 4.88.3
end;

function CabrilloReceivedRSTAgeQTH(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange;
                                   const aCtx: TCabrilloQSOContext): string;
var
  age: integer;
begin
  age := aQso.Age;
  Result := SysUtils.Format('%-3s %u %s', [aCtx.RSTReceived, age, aCtx.HisQTH]);
end;

function CabrilloReceivedRSTAge(const aMy: TMyStationExchange;
                                const aQso: ContestExchange;
                                const aCtx: TCabrilloQSOContext): string;
var
  age: integer;
begin
  age := aQso.Age;
  Result := SysUtils.Format('%-3s %-7u', [aCtx.RSTReceived, age]);
end;

function CabrilloReceivedAgeQSONumber(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;
var
  age: integer;
begin
  age := aQso.Age;
  Result := SysUtils.Format(' %-3d %.*d', [age, SerialWidth(aQso.NumberReceived, 4),
                                           aQso.NumberReceived]);   // n4af 4.42.4
end;

function CabrilloReceivedRSTPower(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTReceived, string(aQso.Power)]);
end;

function CabrilloReceivedQSONumberQTHShort(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%3.4u %-6s', [aQso.NumberReceived, aCtx.HisQTH]);
end;

function CabrilloReceivedQSONumberQTH(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-4.4u %-6s', [aQso.NumberReceived, aCtx.HisQTH]);
end;

function CabrilloReceivedQTHQSONumber(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-4s %-6.4u', [aCtx.HisQTH, aQso.NumberReceived]);
end;

function CabrilloReceivedRSTQSONumberQTH(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;
begin
  if aCtx.ContestTitle = 'PGA' then           // 4.92.4
     begin
     Result := SysUtils.Format('%-3s%5.3d%s', [aCtx.RSTReceived, aQso.NumberReceived, aCtx.HisQTH]);
     end
  else if aCtx.HisQTH = 'TRC' then      // 4.63.3
     begin
     Result := SysUtils.Format('%-3s%5d%-8s', [aCtx.RSTReceived, aQso.NumberReceived, aCtx.HisQTH]);
     end
  else
     begin
     Result := SysUtils.Format('%-3s %4.4d %4s', [aCtx.RSTReceived, aQso.NumberReceived, aCtx.HisQTH]);
     end;
end;

function CabrilloReceivedRSTZoneQTHDX(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;
var
  qth: string;
  zone: integer;
begin
  qth := aCtx.HisQTH;
  if aQso.QTHString = '' then
     begin
     qth := 'DX';
     end;
  zone := aQso.Zone;
  Result := SysUtils.Format('%-3s %.2u %-3s', [aCtx.RSTReceived, zone, qth]);
end;

function CabrilloReceivedRSTQTHOrZone(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;
var
  zone: integer;
begin
  zone := aQso.Zone;
  if aQso.QTHString <> '' then
     begin
     Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTReceived, aCtx.HisQTH]);
     end
  else
     begin
     Result := SysUtils.Format('%-3s %-7u', [aCtx.RSTReceived, zone]);
     end;
end;

function CabrilloReceivedQTHQSONumberSum(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %3.4u', [aCtx.HisQTH, aQso.NumberReceived]);
end;

function CabrilloReceivedQSONumberGeoQTH(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3.4u %-7s', [aQso.NumberReceived, aCtx.HisQTH]);
end;

function CabrilloReceivedRSTQSONumber(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-3.3u', [aCtx.RSTReceived, aQso.NumberReceived]);   // issue 177
end;

function CabrilloReceivedRSTContinent(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTReceived, string(aQso.QTHString)]);
end;

function CabrilloReceivedRSTQTHDX(const aMy: TMyStationExchange;
                                  const aQso: ContestExchange;
                                  const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTReceived, ReceivedQTHOrDX(aQso, aCtx)]);
end;

function CabrilloReceivedQTHDX(const aMy: TMyStationExchange;
                               const aQso: ContestExchange;
                               const aCtx: TCabrilloQSOContext): string;
begin
  Result := SysUtils.Format('%-7s', [ReceivedQTHOrDX(aQso, aCtx)]);
end;

function CabrilloReceivedRSTQTHOrDXQTH(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;
var
  qth: string;
begin
  qth := aCtx.HisQTH;
  if aQso.QTHString = '' then
     begin
     if aQso.DXQTH = '' then
        begin
        qth := 'DX';
        end
     else
        begin
        qth := string(aQso.DXQTH);
        end;
     end;
  Result := SysUtils.Format('%-3s %-7s', [aCtx.RSTReceived, qth]);
end;

function CabrilloReceivedRSTDomesticQTHOrDX(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            const aCtx: TCabrilloQSOContext): string;
var
  qth: string;
begin
  qth := aCtx.HisQTH;
  if aQso.DomesticQTH = '' then
     begin
     qth := 'DX';
     end;
  (* UnicodeFormat: FPC 3.2.2's SysUtils.Format takes AnsiString, and this
     unit's strings are UnicodeString -- no narrowing added. *)
  Result := UnicodeFormat('%-3s %-7s', [aCtx.RSTReceived, qth]);
end;

function CabrilloReceivedZoneQSONumber(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string;
var
  zone: integer;
begin
  zone := aQso.Zone;
  Result := SysUtils.Format('  %-4u   %.3d', [zone, aQso.NumberReceived]);   // 4.98.4
end;

function CabrilloReceivedRSTZone(const aMy: TMyStationExchange;
                                 const aQso: ContestExchange;
                                 const aCtx: TCabrilloQSOContext): string;
var
  zone: integer;
begin
  zone := aQso.Zone;
  Result := SysUtils.Format('%-3s %-7.2d', [aCtx.RSTReceived, zone]);   // 4.51.1 issue185
end;

function CabrilloReceivedQSONumberPreviousQSONumber(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
var
  thousands, units: integer;
begin
  thousands := (aQso.NumberReceived div 1000);    // 4.53.2
  units     := (aQso.NumberReceived mod 1000);    // 4.53.2
  Result := SysUtils.Format('%-.4d%-.4d', [thousands, units]);    // 4.53.4
end;

function CabrilloReceivedRSTQTHOrQSONumber(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string;
begin
  if aQso.QTHString <> '' then
     begin
     Result := SysUtils.Format('%-3s %-3s', [aCtx.RSTReceived, aCtx.HisQTH]);   // 4.84.2
     end
  else
     begin
     Result := SysUtils.Format('%-3s %.3u', [aCtx.RSTReceived, aQso.NumberReceived]);
     end;
end;

function CabrilloReceivedNotHandled(const aMy: TMyStationExchange;
                                    const aQso: ContestExchange;
                                    const aCtx: TCabrilloQSOContext): string;
begin
  Result := CabrilloExchangeErrorMarker;
end;

end.

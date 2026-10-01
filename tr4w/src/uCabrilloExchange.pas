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

(* THE CABRILLO EXCHANGE COLUMNS, ONE ARM PER EXCHANGE SHAPE -- and nothing
  that names a contest.

  Issue #998 lifted this `case` out of PostUnit, dependency-light (VC,
  SysUtils, Log4D) so the arms could be pinned with golden lines; and
  uTestCabrilloExchange pins them.

  SINCE M4 (2026-10-01) IT IS THE BASE'S DEFAULT, NOT THE EXPORTER'S CASE.
  PostUnit asks the contest -- uContestRegistry.ContestIdentity, a plain
  TContestBase for a contest with no class -- and TContestBase's
  FormatCabrilloSentExchange / FormatCabrilloReceivedExchange call this with
  the session's exchange. So this function is what an RST-and-serial or a
  name-and-QTH exchange LOOKS LIKE, and every rule that belonged to ONE
  contest is an override on that contest's class:

    FOC Marathon's membership number      TContestFOCMarathon
    Ukraine Championship / Ural Cup order TContestUkraineChampionship,
                                          TContestUralCup
    UK/EI '--', RSGB IOTA '------'        TContestUKEI, TContestRSGBIOTA
    DARC 10 m's received column           TContestDARC10M
    PACC's serial in the state column     TContestPACC
    PCC's own sent branch                 TContestPCC

  THREE CONTEST TESTS WERE DEAD AND ARE DELETED, measured in the contest
  matrix: CQ VHF's and SP DX's branches inside RSTDomesticQTHExchange, and
  JIDX's inside RSTZoneExchange. No variant of those contests ever ran with
  that exchange (CQ VHF runs RSTAndOrGridExchange, SP DX
  RSTDomesticQTHOrQSONumberExchange, JIDX RSTPrefectureExchange), so only an
  operator's EXCHANGE RECEIVED line could reach them. So were the two arms
  inventory D4 listed: QSONumberPrecedenceCheckDomesticQTHExchange and
  ClassDomesticOrDXQTHExchange are reached by Sweepstakes and the two Field
  Days only, all of which format their own; an operator who states either
  exchange for some other contest now gets the unhandled marker below rather
  than a line built for a contest he is not running.

  TWO TESTS STAY, AND THEY NAME NO CONTEST: `MyState = 'TRC'` and
  `ContestTitle = 'PGA'`. They are operator-driven hooks for two events that
  have no ContestType (inventory D7, design Q8 -- NY4I's, open), so there is
  no class they could move to. *)

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

(* Builds the MY-EXCHANGE (MyEx) and HIS-EXCHANGE (HisEx) Cabrillo columns for
  one QSO, from the shared arm for aCtx.SessionExchange.

  True for every exchange that has an arm. False only for one that has none
  (Issue #1043): both columns then carry an "ERROR EXCHANGE NOT HANDLED"
  marker rather than being written silently blank, and -- when
  aReportUnhandled -- an Error is logged naming aContestName. *)
function FormatCabrilloExchangeOfKind(
    const aCtx         : TCabrilloQSOContext;
    const rx           : ContestExchange;
    const my           : TMyStationExchange;
    const aContestName : string;
    aReportUnhandled   : boolean;
    out   MyEx, HisEx  : string) : boolean;

implementation

uses
  Log4D;   (* Issue #1043: an unhandled exchange must say so. Log4D is
              self-contained and already linked by the unit-test harness. *)

var
  logger: TLogLogger;

function FormatCabrilloExchangeOfKind(
    const aCtx         : TCabrilloQSOContext;
    const rx           : ContestExchange;
    const my           : TMyStationExchange;
    const aContestName : string;
    aReportUnhandled   : boolean;
    out   MyEx, HisEx  : string) : boolean;
var
  (* The PostUnit per-QSO locals these arms were written against, as strings
     and integers. *)
  RSTSent, RSTReceived, csQTHString, csName,
  cMyGrid, cMyName, cMyState, csPower : string;
  cMyZone, nrSent, nrReceived, HisZone, hisAge, hisnr, rxnr : integer;

  procedure SetMyEx(const fmt: string; const args: array of const);
  begin
    MyEx := SysUtils.Format(fmt, args);
  end;

  procedure SetHisEx(const fmt: string; const args: array of const);
  begin
    HisEx := SysUtils.Format(fmt, args);
  end;

begin
  Result := True;
  MyEx := '';
  HisEx := '';

  RSTSent     := aCtx.RSTSent;
  RSTReceived := aCtx.RSTReceived;
  csQTHString := aCtx.HisQTH;
  csName      := string(rx.Name);
  cMyGrid     := my.MyGrid;
  cMyName     := my.MyName;
  cMyState    := my.MyState;
  cMyZone     := StrToIntDef(my.MyZone, 0);
  nrSent      := rx.NumberSent;
  nrReceived  := rx.NumberReceived;
  HisZone     := rx.Zone;

  case aCtx.SessionExchange of

    GridExchange, Grid2Exchange:
      begin
      SetMyEx('%-11s', [cMyGrid]);
      SetHisEx('%-11s', [csQTHString]);
      end;

    RSTAndGrid3Exchange:                // 4.96.3
      begin
      SetMyEx('%-7s%-11s ', [RSTSent, cMyGrid]);
      SetHisEx('%-3s %-11s ', [RSTReceived, csQTHString]);
      end;

    RSTNameAndQTHExchange:
      begin
      SetMyEx('%-3s %-5s %-7s', [RSTSent, cMyName, cMyState]);
      SetHisEx('%-3s %-5s %-7s', [RSTReceived, csName, csQTHString]);
      end;

    QSONumberAndNameExchange:
      begin
      SetMyEx('%-3d %-7s', [nrSent, cMyName]);
      SetHisEx('%-3u %-7s', [nrReceived, csName]);
      end;

    RSTAndPostalCodeExchange:
      begin
      if aCtx.RecordNumber = 1 then
         begin
         SetMyEx('%-3s %-10s', [RSTSent, my.MyPostalCode]);
         end
      else
         begin
         SetMyEx('%-3s %-10s', [RSTSent, aCtx.PreviousQTH]);
         end;
      SetHisEx('%-3s %-10s', [RSTReceived, string(rx.QTHString)]);
      end;

    RSTQSONumberAndGridSquareExchange:
      begin
      SetMyEx('%-3s %-4.4d %-7s', [RSTSent, nrSent, cMyGrid]);
      SetHisEx('%-3s %-4.4u %-7s', [RSTReceived, nrReceived, csQTHString]);
      end;

    RSTQSONumberOrDomesticQTHExchange:      // n4af 4.40.6
      begin
      if cMyState <> '' then
         begin
         SetMyEx('%-3s  %-8s', [RSTSent, cMyState]);        // 4.98.11
         end;

      if cMyState = '' then
         begin
         SetMyEx('%-3s  %-6d', [RSTSent, nrSent]);
         end;

      if nrReceived >= 1 then
         begin
         SetHisEx('%-3s %6d %-6s', [RSTReceived, nrReceived, csQTHString]);
         end;
      if nrReceived < 1 then
         begin
         SetHisEx('%-3s   %9s', [RSTReceived, csQTHString]);
         end;
      end;

    RSTPrefectureExchange:
      begin
      SetMyEx('%-3s %-7d', [RSTSent, cMyZone]);
      SetHisEx('%-3s %-7s', [RSTReceived, csQTHString]);
      end;

    NameAndDomesticOrDXQTHExchange:
      begin
      SetMyEx('  %-10s %-4s', [my.MyName, cMyState]);
      SetHisEx('  %-10s %-4s', [csName, csQTHString]);
      end;

    QSONumberNameDomesticOrDXQTHExchange:
      begin
      csName  := string(rx.Name);
      cMyName := my.MyName;
      if my.MyState = '' then
         begin
         cMyState := 'DX';
         end;
      if rx.QTHString = '' then
         begin
         csQTHString := 'DX';
         end;

      SetMyEx('%-4d %-7s %-8s', [nrSent, cMyName, cMyState]);    // 4.88.3
      SetHisEx('%-4u %-5s %-4s', [nrReceived, csName, csQTHString]);  // 4.88.3
      end;

    RSTAgeAndPossibleSK:
      begin
      SetMyEx('%-3s %-16s', [RSTSent, cMyState]);
      nrReceived := rx.Age;
      SetHisEx('%-3s %u %s', [RSTReceived, nrReceived, csQTHString]);
      end;

    RSTAgeExchange:
      begin
      SetMyEx('%-3s %-7s', [RSTSent, cMyState]);
      nrReceived := rx.Age;
      SetHisEx('%-3s %-7u', [RSTReceived, nrReceived]);
      end;

    AgeAndQSONumberExchange:      // 4.55.4
      begin
      SetMyEx('%-2s %.*d ', [cMyState, 3 - Ord(nrSent < 0), nrSent]);
      hisAge := rx.Age;
      nrReceived := rx.NumberReceived;          // n4af 04.42.4
      SetHisEx(' %-3d %.*d', [hisAge, 4 - Ord(nrReceived < 0), nrReceived]);   // n4af 4.42.4
      end;

    QSONumberAndAgeExchange:      // 4.119.1
      begin
      (* Unreachable by any active contest; RSTSent here is the numeric RST. *)
      SetMyEx('%-3d %.*d %-2s      ', [rx.RSTSent, 3 - Ord(nrSent < 0), nrSent, cMyState]);
      hisAge := rx.Age;
      nrReceived := rx.NumberReceived;          // n4af 04.42.4
      SetHisEx(' %-3d %3d %.2d', [rx.RSTSent, nrReceived, hisAge]);       // n4af 4.42.4
      end;

    RSTPowerExchange:
      begin
      (* FOC Marathon's membership-number branch is TContestFOCMarathon's;
         ARRL DX formats its own. *)
      csPower := string(rx.Power);
      SetHisEx('%-3s %-7s', [RSTReceived, csPower]);
      SetMyEx('%-3s %-7s', [RSTSent, cMyState]);
      end;

    RSTAndOrGridExchange:
      begin
      SetHisEx('%-3s %-7s', [RSTReceived, csQTHString]);
      SetMyEx('%-3s %-7s', [RSTSent, cMyGrid]);
      end;

    QSONumberAndGridSquare:
      begin
      SetMyEx('%.*d %-6.4s ', [3 - Ord(nrSent < 0), nrSent, cMyState]);
      SetHisEx('%3.4u %-6s', [nrReceived, csQTHString]);
      end;

    QSONumberDomesticOrDXQTHExchange, QSONumberDomesticQTHExchange:
      begin
      (* The Ukraine Championship and the Ural Cup put the QTH first; that
         is each of those classes' own override now. *)
      SetMyEx('%-4d %-6s', [nrSent, cMyState]);
      SetHisEx('%-4.4u %-6s', [nrReceived, csQTHString]);
      end;

    QSONumberAndPossibleDomesticQTHExchange, RSTQSONumberAndDomesticQTHExchange, RSTQSONumberAndPossibleDomesticQTHExchange:
      begin
      if cMyState = 'TRC' then      // 4.63.3
         begin
         SetMyEx('%-3s %d%-6s', [RSTSent, nrSent, cMyState]);
         end
      else if aCtx.ContestTitle = 'PGA' then       // 4.92.4
         begin
         SetMyEx('%-3s %3.3d%s     ', [RSTSent, nrSent, cMyState]);
         end
      else
         begin
         SetMyEx('%-3s %-4.4d %6s      ', [RSTSent, nrSent, cMyState]);
         end;

      (* UK/EI's '--', the RSGB IOTA's '------' and DARC 10 m's received
         column are those classes' own overrides now. *)
      if aCtx.ContestTitle = 'PGA' then           // 4.92.4
         begin
         SetHisEx('%-3s%5.3d%s', [RSTReceived, nrReceived, csQTHString]);
         end
      else if csQTHString = 'TRC' then      // 4.63.3
         begin
         SetHisEx('%-3s%5d%-8s', [RSTReceived, nrReceived, csQTHString]);
         end
      else
         begin
         SetHisEx('%-3s %4.4d %4s', [RSTReceived, nrReceived, csQTHString]);
         end;
      end;

    RSTZoneAndPossibleDomesticQTHExchange:
      begin
      if my.MyState = '' then
         begin
         cMyState := 'DX';
         end;

      SetMyEx('%-3s %.2u %-4s', [RSTSent, cMyZone, cMyState]);

      if rx.QTHString = '' then
         begin
         csQTHString := 'DX';
         end;
      SetHisEx('%-3s %.2u %-3s', [RSTReceived, HisZone, csQTHString]);
      end;

    RSTZoneOrDomesticQTH, RSTZoneOrSocietyExchange:
      begin
      if my.MyState <> '' then
         begin
         SetMyEx('%-3s %-7s', [RSTSent, cMyState]);
         end
      else
         begin
         SetMyEx('%-3s %-7d', [RSTSent, cMyZone]);
         end;

      if rx.QTHString <> '' then
         begin
         SetHisEx('%-3s %-7s', [RSTReceived, csQTHString]);
         end
      else
         begin
         SetHisEx('%-3s %-7u', [RSTReceived, HisZone]);
         end;
      end;

    QSONumberAndCoordinatesSum: (* RFASCHAMPIONSHIP *)
      begin
      SetMyEx('%-3s %3.4d    ', [cMyState, nrSent]);
      SetHisEx('%-3s %3.4u', [csQTHString, nrReceived]);
      end;

    QSONumberAndGeoCoordinates:
      begin
      SetMyEx('%-3.4d %-7s ', [nrSent, cMyState]);
      SetHisEx('%-3.4u %-7s', [nrReceived, csQTHString]);
      end;

    RSTQSONumberExchange:
      begin
      SetMyEx('%-3s %.*d ', [RSTSent, 3 - Ord(nrSent < 0), nrSent]);   // issue 177
      SetHisEx('%-3s %-3.3u', [RSTReceived, nrReceived]);              // issue 177
      end;

    RSTAndContinentExchange:
      begin
      csQTHString := string(rx.QTHString);
      SetHisEx('%-3s %-7s', [RSTReceived, csQTHString]);
      SetMyEx('%-3s %-7s', [RSTSent, cMyState]);
      end;

    RSTDomesticQTHExchange:
      begin
      (* PACC's serial in the state column is TContestPACC's. CQ VHF's and SP
         DX's branches here were dead -- see the unit header. *)
      if my.MyState = '' then
         begin
         cMyState := 'DX';
         end;
      if rx.QTHString = '' then
         begin
         csQTHString := 'DX';
         end;
      SetHisEx('%-3s %-7s', [RSTReceived, csQTHString]);
      SetMyEx('%-3s %-7s', [RSTSent, cMyState]);
      end;

    RSTDomesticOrDXQTHExchange:
      begin
      if rx.QTHString = '' then
         begin
         if rx.DXQTH = '' then
            begin
            csQTHString := 'DX';
            end
         else
            begin
            csQTHString := string(rx.DXQTH);
            end;
         end;

      SetHisEx('%-3s %-7s', [RSTReceived, csQTHString]);
      SetMyEx('%-3s %-7s', [RSTSent, cMyState]);
      end;

    QSONumberAndZone:
      begin
      SetHisEx('  %-4u   %.3d', [HisZone, nrReceived]);   // 4.98.4
      SetMyEx('  %s    %3.4d ', [cMyState, nrSent]);
      end;

    RSTZoneExchange:
      begin
      (* JIDX's prefecture-as-zone branch here was dead -- see the header. *)
      SetHisEx('%-3s %-7.2d', [RSTReceived, HisZone]);   // 4.51.1 issue185
      SetMyEx('%-3s %-7.2d', [RSTSent, cMyZone]);        // 4.51.1 issue#185
      end;

    QSONumberAndPreviousQSONumber:
      begin
      (* THE PREVIOUS NUMBER IS CARRIED BY THE EXPORTER (aCtx), not by a var
         parameter this arm used to write back -- formatting a line now
         changes nothing outside it. *)
      hisnr := (nrReceived div 1000);    // 4.53.2
      rxnr  := (nrReceived mod 1000);    // 4.53.2
      SetMyEx('%-.3u%-7.4d', [aCtx.PreviousNumberReceived, nrSent]);    // 4.72.9
      SetHisEx('%-.4d%-.4d', [hisnr, rxnr]);    // 4.53.4
      end;

    RSTAndQSONumberOrFrenchDepartmentExchange, RSTAndQSONumberOrDomesticQTHExchange, RSTDomesticQTHOrQSONumberExchange:
      begin
      (* THE PCC'S BRANCHES ARE TContestPCC'S, and taking them out left two.
         The arm read `if (MyState <> '') and (Contest <> PCC)`, then "MY
         STATE is all digits" for the '/M' form, then the plain serial. An
         all-digit MY STATE is never empty, so for every other contest the
         first test already took it: the '/M' branch was the PCC's alone, and
         went with it. *)
      if my.MyState <> '' then      // 4.83.2
         begin
         SetMyEx('%-3s %-7s', [RSTSent, cMyState]);
         end
      else
         begin
         SetMyEx('%-4s %3.4u   ', [RSTSent, nrSent]);  // n4af 4.43.12
         end;

      if rx.QTHString <> '' then
         begin
         SetHisEx('%-3s %-3s', [RSTReceived, csQTHString]); // 4.84.2
         end
      else
         begin
         SetHisEx('%-3s %.3u', [RSTReceived, nrReceived]);
         end;
      end;
    else
       begin
       (* Issue #1043: rather than silently writing a blank exchange, write a
          loud marker into BOTH columns so the offending QSO line is obvious
          in the Cabrillo output. (PostUnit uppercases HisEx, so the marker is
          all-caps to keep both columns identical.) *)
       if aReportUnhandled then
          begin
          logger.Error(SysUtils.Format(
            'FormatCabrilloExchangeOfKind: unhandled exchange %d (contest "%s") -- ' +
            'wrote ERROR marker to the Cabrillo line. See Issue #1043.',
            [Ord(aCtx.SessionExchange), aContestName]));
          end;
       MyEx   := 'ERROR EXCHANGE NOT HANDLED';
       HisEx  := 'ERROR EXCHANGE NOT HANDLED';
       Result := False;
       end;
  end;
end;

initialization
  logger := TLogLogger.GetLogger('uCabrilloExchange');

end.

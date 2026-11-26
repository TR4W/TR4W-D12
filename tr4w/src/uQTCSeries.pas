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

(* THE WAE QTC RULES, WITHOUT A WINDOW (2026-11-26).

  docs/ContestRules/WAE/rules.txt section 7. The send and receive windows
  (uQTCS, uQTCR), the loader (MainUnit.LoadinLog), a peer's row (uNet) and the
  exports ask these; nothing here reads a global or the log.

  - A QTC SERIES IS LOGGED AS '<series>/<QTCs in it>', the second figure the
    QTCs actually transferred ("the second figure denotes the number of QTCs
    in the series"). A book offered as 10 and stopped after 6 confirmed is a
    series of 6. D7 logged the offered count (uQTCS SaveQTCS); the sponsor's
    rule overrides.
  - A QTC RECORD COUNTS (points, the per-pair quota, the export, the summary)
    unless it is deleted. One predicate, QTCRecordCounts.
  - THE SERIES NUMBER NEVER GOES BACK: the next series is one more than the
    highest series ever logged, deleted rows included -- a number announced
    on the air is used, whatever became of its rows.
  - TWO CALLS ARE ONE STATION FOR QTC PURPOSES when their base calls agree
    (uCallSignRoutines.RootCall: DL1AA/P, DL1AA/QRP and EA8/DL1AA are all
    DL1AA). The quota of 10 per pair and "the QTC may not be reported back to
    the original station" both use it. *)
unit uQTCSeries;

{$I tr4w.inc}

interface

uses
   VC;

(* '<series>/<count>', e.g. '3/6'. *)
function QTCSeriesText(aSeries, aCount: integer): string;

(* A QTC record (sent or received) that counts: not deleted. False for any
  other record kind. *)
function QTCRecordCounts(const aRec: ContestExchange): boolean;

(* THE HIGHEST SERIES SENT SO FAR, given the one before and the next record:
  an rkQTCS record's series (QSOPoints) raises it, deleted or not. *)
function QTCSeriesHighWater(aCurrent: integer; const aRec: ContestExchange): integer;

(* The key the per-pair quota is counted under: the base call. *)
function QTCQuotaKey(const aCall: string): string;

(* One station for QTC purposes: the same base call. Two empty calls are not. *)
function SameQTCStation(const aCallA, aCallB: string): boolean;

(* MAY THIS LOGGED QSO BE REPORTED IN A QTC SENT TO aReceiverCall? A contact
  (uOperatorList.LogRecordIsContact: a QSO, not deleted, with a band and a
  mode), not a dupe, not an X-QSO (uContestRegistry.StoredQSOIsXQSO: the
  operator's flag or the contest's off-contest rule), worth points (a WAE
  CW/SSB QSO scores 0 only on 160 m or between two stations of the same side,
  neither of which is a contest QSO), not already sent in a QTC, and not a
  QSO with the receiving station itself (by base call). *)
function QSOMayBeReportedInQTC(const aQso: ContestExchange;
                               const aReceiverCall: string): boolean;

(* ONE LINE OF A SERIES WE SENT, as the log stores it: Callsign the station
  that received it, NumberSent the QSO's HHMM, Kids the QSO's call,
  NumberReceived its serial, RandomCharsReceived the series text and
  QSOPoints the series number. The caller stamps time, band, mode and ids. *)
function SentQTCRecord(const aReceiverCall: string; aSeries, aCount: integer;
                       aQsoTime: integer; const aQsoCall: string;
                       aQsoNumber: integer): ContestExchange;

(* ONE LINE OF A SERIES WE RECEIVED: the same fields, Callsign the station
  that sent it. QSOPoints stays 0 (a received series is not our numbering). *)
function ReceivedQTCRecord(const aSenderCall: string; aSeries, aCount: integer;
                           aQsoTime: integer; const aQsoCall: string;
                           aQsoNumber: integer): ContestExchange;

implementation

uses
   SysUtils,
   uCallSignRoutines,
   uOperatorList,
   uContestRegistry;

function QTCSeriesText(aSeries, aCount: integer): string;
begin
   Result := IntToStr(aSeries) + '/' + IntToStr(aCount);
end;

function QTCRecordCounts(const aRec: ContestExchange): boolean;
begin
   Result := (aRec.ceRecordKind in [rkQTCR, rkQTCS]) and
             (not aRec.ceQSO_Deleted);
end;

function QTCSeriesHighWater(aCurrent: integer; const aRec: ContestExchange): integer;
begin
   Result := aCurrent;
   if (aRec.ceRecordKind = rkQTCS) and (aRec.QSOPoints > Result) then
      begin
      Result := aRec.QSOPoints;
      end;
end;

function QTCQuotaKey(const aCall: string): string;
var
   call: string;
begin
   call := UpperCase(Trim(aCall));
   Result := RootCall(call);
   (* RootCall ANSWERS '' FOR A TWO-CHARACTER STRING ('W1'): measured by
     uTestQTCCounts, where W1..W9 fell into one row. In that case the call
     itself is the key, so no two different calls share one. *)
   if Result = '' then
      begin
      Result := call;
      end;
end;

function SameQTCStation(const aCallA, aCallB: string): boolean;
var
   a: string;
begin
   a := QTCQuotaKey(aCallA);
   Result := (a <> '') and (a = QTCQuotaKey(aCallB));
end;

function QSOMayBeReportedInQTC(const aQso: ContestExchange;
                               const aReceiverCall: string): boolean;
begin
   Result := False;
   if not LogRecordIsContact(aQso) then
      begin
      Exit;
      end;
   if aQso.ceDupe then
      begin
      Exit;
      end;
   if StoredQSOIsXQSO(aQso) then
      begin
      Exit;
      end;
   if aQso.QSOPoints <= 0 then
      begin
      Exit;
      end;
   if aQso.ceWasSendInQTC then
      begin
      Exit;
      end;
   if SameQTCStation(string(aQso.Callsign), aReceiverCall) then
      begin
      Exit;
      end;
   Result := True;
end;

function QTCRecord(aKind: LogRecordKind; const aOtherCall: string;
                   aSeries, aCount: integer; aQsoTime: integer;
                   const aQsoCall: string; aQsoNumber: integer): ContestExchange;
begin
   Result.Clear;
   Result.ceRecordKind := aKind;
   Result.Callsign := CallString(aOtherCall);
   Result.NumberSent := aQsoTime;
   Result.Kids := ShortString(aQsoCall);
   Result.NumberReceived := aQsoNumber;
   (* string[7]: '9999/10' fits; a series number past 9999 is not a WAE. *)
   Result.RandomCharsReceived := ShortString(QTCSeriesText(aSeries, aCount));
end;

function SentQTCRecord(const aReceiverCall: string; aSeries, aCount: integer;
                       aQsoTime: integer; const aQsoCall: string;
                       aQsoNumber: integer): ContestExchange;
begin
   Result := QTCRecord(rkQTCS, aReceiverCall, aSeries, aCount, aQsoTime,
                       aQsoCall, aQsoNumber);
   Result.QSOPoints := aSeries;
end;

function ReceivedQTCRecord(const aSenderCall: string; aSeries, aCount: integer;
                           aQsoTime: integer; const aQsoCall: string;
                           aQsoNumber: integer): ContestExchange;
begin
   Result := QTCRecord(rkQTCR, aSenderCall, aSeries, aCount, aQsoTime,
                       aQsoCall, aQsoNumber);
end;

end.

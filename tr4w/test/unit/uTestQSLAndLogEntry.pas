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

(* QSL AND LOG WITH A REFUSED EXCHANGE -- issue 274 item 7, NY4I's option
  (b), 2026-11-19: "B is right as we never want to write suspect data to the
  qso table."

  In QSL MODE = QSL AND LOG, MainUnit.ParametersOkay answers True whatever
  the parse said, so the QSO is logged with what the parse left. The zone
  parsers refuse on a copy (items 1-2), so a refused CQ WW '599 45' leaves
  the zone out of the QSO. What (b) adds: the TYPED TEXT is kept in
  ExchString, so the raw entry survives for a later Edit QSO. Before it this
  branch never wrote ExchString at all, accepted or refused.

  Driven through the real engine (uTestEngineEntry), CQ WW CW in CQ zone
  mode, with the mode and the zone mode put back in a finally. The Standard
  mode rows pin that a refusal there still writes no ExchString. *)
unit uTestQSLAndLogEntry;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TQSLAndLogEntryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ARefusedZoneIsNotWrittenButTheTypedTextIsKept;
      procedure Test_AnAcceptedEntryKeepsItsTextAndZone;
      procedure Test_StandardModeStillWritesNoTextForARefusal;
   end;

implementation

uses
   SysUtils,
   (* ContestExchange, ContestType *)
   VC,
   (* CTY.ctyZoneMode *)
   uCTYDAT,
   (* ParameterOkayMode *)
   LogStuff,
   (* Enter, SetUpSession, RestoreSession -- last, so its names win. *)
   uTestEngineEntry;

(* ONE ENTRY IN aMode, CQ WW CW in CQ zone mode, as the operator types it. *)
function EnterIn(aMode: ParameterOkayModeType; const aExch: string;
                 var aRX: ContestExchange): boolean;
var
   savedMode: ParameterOkayModeType;
   savedZoneMode: ZoneModeType;
begin
   savedMode := ParameterOkayMode;
   savedZoneMode := CTY.ctyZoneMode;
   SetUpSession(CQWWCW, [], '');
   try
      ParameterOkayMode := aMode;
      CTY.ctyZoneMode := CQZoneMode;
      Result := Enter('W1AW', aExch, aRX);
   finally
      RestoreSession;
      CTY.ctyZoneMode := savedZoneMode;
      ParameterOkayMode := savedMode;
      end;
end;

procedure TQSLAndLogEntryTests.Test_ARefusedZoneIsNotWrittenButTheTypedTextIsKept;
var
   rx: ContestExchange;
begin
   BeginTest('Test_ARefusedZoneIsNotWrittenButTheTypedTextIsKept');

   (* THERE ARE 40 CQ ZONES: 45 is refused by the parse, and this mode logs
      anyway. *)
   CheckTrue(EnterIn(QSLAndLog, '599 45', rx), 'QSL AND LOG logs a refused entry');
   CheckEquals(0, Integer(rx.Zone), 'the invalid zone 45 is not written to the QSO');
   CheckEquals('599 45', string(rx.ExchString), 'the typed text is kept for a later edit');

   CheckTrue(EnterIn(QSLAndLog, '599 85', rx), 'QSL AND LOG logs a refused 85');
   CheckEquals(0, Integer(rx.Zone), 'the invalid zone 85 is not written');
   CheckEquals('599 85', string(rx.ExchString), 'the typed 85 is kept');
end;

procedure TQSLAndLogEntryTests.Test_AnAcceptedEntryKeepsItsTextAndZone;
var
   rx: ContestExchange;
begin
   BeginTest('Test_AnAcceptedEntryKeepsItsTextAndZone');

   CheckTrue(EnterIn(QSLAndLog, '599 5', rx), 'QSL AND LOG logs an accepted entry');
   CheckEquals(5, Integer(rx.Zone), 'the zone is written');
   CheckEquals('599 5', string(rx.ExchString), 'the typed text is kept');
end;

procedure TQSLAndLogEntryTests.Test_StandardModeStillWritesNoTextForARefusal;
var
   rx: ContestExchange;
begin
   BeginTest('Test_StandardModeStillWritesNoTextForARefusal');

   CheckFalse(EnterIn(Standard, '599 45', rx), 'Standard refuses 45');
   CheckEquals(0, Integer(rx.Zone), 'Standard: no zone written');
   CheckEquals('', string(rx.ExchString), 'Standard: a refusal writes no text');

   CheckTrue(EnterIn(Standard, '599 5', rx), 'Standard accepts 5');
   CheckEquals(5, Integer(rx.Zone), 'Standard: the zone is written');
   CheckEquals('599 5', string(rx.ExchString), 'Standard: an accepted entry keeps its text');
end;

procedure TQSLAndLogEntryTests.RunAllTests;
begin
   Test_ARefusedZoneIsNotWrittenButTheTypedTextIsKept;
   Test_AnAcceptedEntryKeepsItsTextAndZone;
   Test_StandardModeStillWritesNoTextForARefusal;
end;

end.

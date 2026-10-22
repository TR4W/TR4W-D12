(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* Q73 -- A QSO PARTY'S CALL/<county> IS ITS OWN STATION FOR DUPES (NY4I,
  2026-10-16: "NY4I/PIN in FQP should be considered a different station than
  NY4I/HIL ... Note in the NEQP (or IN7QPNE) that could be K1AR/NHHIL").

  MEASURED 2026-10-17, ALREADY SO: the dupe sheet (uCallsigns'
  TCallsignsList) keys a station on the call EXACTLY AS LOGGED, slash and
  suffix included, and nothing on the way strips a rover's county from the
  call -- the rover strip (MainUnit.LocateCallStrippingRoverCounty) touches
  only the CTY.DAT lookup, ParametersOkay and LogContact keep the call, the
  log stores it, the loader and the rescore hand it to the sheet as stored,
  and an ADIF import puts it back from APP_TR4W_ROVERCALL. The one rewrite on
  the way is n4af's mobile rule (LogContact): CALL/M working from a county is
  logged as CALL/<county>, which lands on the same key.

  SO THIS PINS THE KEY. A rover in one county is a different station from
  the same call in another county and from the fixed call; the same county
  again is a dupe. A suffix that is not a county keeps today's rule, which is
  the same exact key -- it was never stripped either. If the sheet ever
  starts normalising a call (a root call, StandardCallFormat), this fails. *)
unit uTestRoverDupeKey;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TRoverDupeKeyTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ACountyRoverIsItsOwnStation;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uCallsigns,
   uContestRegistry,
   PostUnit;

(* A LIST OF THE TEST'S OWN, freed in the test's finally. *)
procedure InitList(var aList: TCallsignsList);
begin
   aList := TCallsignsList.Create;
end;

function IsDupe(var aList: TCallsignsList; const aCall: string): boolean;
var
   index: integer;
begin
   Result := aList.CallsignIsDupe(aCall, Band20, CW, index);
end;

procedure TRoverDupeKeyTests.Test_ACountyRoverIsItsOwnStation;
var
   list: TCallsignsList;
   savedContest: TContestHandle;
   savedByBand: boolean;
   savedByMode: boolean;
begin
   BeginTest('Test_ACountyRoverIsItsOwnStation');

   savedContest := Contest;
   savedByBand := Settings.Qso.ByBand;
   savedByMode := Settings.Qso.ByMode;
   InitList(list);
   try
      Settings.Qso.ByBand := True;
      Settings.Qso.ByMode := True;

      (* FLORIDA: NY4I/PIN, then NY4I/HIL. *)
      Contest := ContestHandleOf(FLORIDAQSOPARTY);
      list.AddCallsign('NY4I/PIN', CW, Band20, False);
      CheckTrue(IsDupe(list, 'NY4I/PIN'), 'FQP: NY4I/PIN again is a dupe');
      CheckFalse(IsDupe(list, 'NY4I/HIL'), 'FQP: NY4I/HIL is another station');
      CheckFalse(IsDupe(list, 'NY4I'), 'FQP: the fixed NY4I is another station');
      list.AddCallsign('NY4I/HIL', CW, Band20, False);
      CheckTrue(IsDupe(list, 'NY4I/HIL'), 'FQP: and once worked, HIL is a dupe');
      CheckTrue(IsDupe(list, 'NY4I/PIN'), 'FQP: PIN still is');

      (* NEW ENGLAND: K1AR/NHHIL, then K1AR/NHMER. *)
      Contest := ContestHandleOf(NEWENGLANDQSO);
      list.AddCallsign('K1AR/NHHIL', CW, Band20, False);
      CheckTrue(IsDupe(list, 'K1AR/NHHIL'), 'NEQP: K1AR/NHHIL again is a dupe');
      CheckFalse(IsDupe(list, 'K1AR/NHMER'), 'NEQP: K1AR/NHMER is another station');

      (* IN7QPNE: the same key. *)
      Contest := ContestHandleOf(IN7QPNE);
      CheckTrue(IsDupe(list, 'K1AR/NHHIL'), 'IN7QPNE: K1AR/NHHIL is the same key');
      CheckFalse(IsDupe(list, 'K1AR/NHBEL'), 'IN7QPNE: K1AR/NHBEL is another station');

      (* NOT A COUNTY: today's rule, the same exact key. *)
      Contest := ContestHandleOf(FLORIDAQSOPARTY);
      list.AddCallsign('W1AW/P', CW, Band20, False);
      CheckTrue(IsDupe(list, 'W1AW/P'), 'W1AW/P again is a dupe');
      CheckFalse(IsDupe(list, 'W1AW'), 'W1AW/P is not W1AW, as it never was');
   finally
      list.Free;
      Settings.Qso.ByMode := savedByMode;
      Settings.Qso.ByBand := savedByBand;
      Contest := savedContest;
   end;
end;

procedure TRoverDupeKeyTests.RunAllTests;
begin
   Test_ACountyRoverIsItsOwnStation;
end;

end.

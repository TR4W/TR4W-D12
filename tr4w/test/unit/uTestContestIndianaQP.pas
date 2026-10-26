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

(* THE INDIANA QSO PARTY'S 2026 RULES (#88 round 3, checked 2026-10-26).
  The sponsor's text is docs/ContestRules/QSOParties/Indiana/
  IN-QSO-PARTY-Rules.txt; each test quotes the rule it holds.

    * multipliers count once per MODE, for every entrant -- through the
      real multiplier sheet (Sheet.SetMultFlags), as LogContact asks it;
    * Indiana is not one of an Indiana entrant's "other 49" states. *)
unit uTestContestIndianaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestIndianaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_IndianaMultipliersCountOncePerMode;
      procedure Test_IndianaIsNoStateMultiplierInState;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uMults,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   LogDupe,
   LogDom,
   (* Sheet, the multiplier sheet LogContact asks. *)
   LogStuff,
   (* Contest, the session's contest. *)
   PostUnit,
   FCONTEST,
   uTestQSOPartyRules;

(* "Multipliers count once per mode (i.e. once on CW and once on phone).
   This means you can double your possible mults by working both modes."
   The contest says so (MultByMode); set-up copies it into the session as
   FCONTEST does, and the sheet then counts Connecticut on CW and again on
   phone, but not again on CW on another band. An Indiana entrant. *)
procedure TContestIndianaQPTests.Test_IndianaMultipliersCountOncePerMode;
var
   savedContest: TContestHandle;
   savedMultByBand: boolean;
   savedMultByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedInHostState: boolean;
   savedMyState: string;
   savedSheet: TMultsObject;

   function Flagged(const aMult: string; aBand: BandType; aMode: ModeType;
                    aExtMode: ExtendedModeType): boolean;
   var
      rx: ContestExchange;
   begin
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      rx.Callsign := 'W1XX';
      rx.Band := aBand;
      rx.Mode := aMode;
      rx.ExtMode := aExtMode;
      rx.QTHString := ShortString(aMult);
      rx.DomesticQTH := ShortString(aMult);
      rx.DomMultQTH := ShortString(aMult);
      Sheet.SetMultFlags(rx);
      Sheet.AddQSOToSheets(@rx, False);
      Result := rx.DomesticMult;
   end;

begin
   BeginTest('Test_IndianaMultipliersCountOncePerMode');
   CheckTrue(ContestIdentity(INQSOPARTY).MultByMode, 'Indiana counts its multipliers by mode');
   CheckFalse(ContestIdentity(INQSOPARTY).MultByBand, 'and not by band');

   savedContest := Contest;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedInHostState := StationInHostState;
   savedMyState := Settings.My.State;
   savedSheet := mo;
   mo := TMultsObject.Create;
   try
      Settings.My.State := 'INMRN';
      ClearContestSentState;
      StationInHostState := True;
      Contest := ContestHandleOf(INQSOPARTY);
      ReleaseActiveContest;
      Settings.Mult.ByBand := ContestIdentity(INQSOPARTY).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(INQSOPARTY).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      CheckTrue(Flagged('Ct', Band20, CW, eCW), 'Connecticut on CW is a new multiplier');
      CheckTrue(Flagged('Ct', Band20, Phone, eUSB), 'and on phone it is new again -- once per mode');
      CheckFalse(Flagged('Ct', Band40, CW, eCW), 'but CW on another band is not -- not per band');
      CheckFalse(Flagged('Ct', Band15, Phone, eUSB), 'nor phone on another band');
      CheckTrue(Flagged('INADA', Band20, CW, eCW), 'an Indiana county on CW is');
      CheckTrue(Flagged('INADA', Band20, Phone, eUSB), 'and on phone again');
      CheckFalse(Flagged('In', Band20, CW, eCW), 'Indiana itself is never one for an Indiana entrant');
   finally
      mo.Free;
      mo := savedSheet;
      Settings.My.State := savedMyState;
      ClearContestSentState;
      StationInHostState := savedInHostState;
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

(* "Indiana stations: The 92 Indiana counties (see Section 9). The other 49
   U.S. states (District of Columbia counts as Maryland)." in.dom includes
   the shared S50.DOM, so it gives IN the multiplier IN; an Indiana
   entrant's QSO with it earns none. Ohio and a county still count, and
   outside Indiana the rule is not asked. *)
procedure TContestIndianaQPTests.Test_IndianaIsNoStateMultiplierInState;
var
   host: string;
begin
   BeginTest('Test_IndianaIsNoStateMultiplierInState');
   host := InStateMultiplierOf(INQSOPARTY, 'IN');
   CheckEquals('IN', host, 'in.dom gives IN the multiplier IN (S50.DOM)');
   CheckFalse(CountsForEntrant(INQSOPARTY, True, host, rmDomestic), 'in state: Indiana is no multiplier');
   CheckFalse(CountsForEntrant(INQSOPARTY, True, 'In', rmDomestic), 'in the file''s own spelling either');
   CheckTrue(CountsForEntrant(INQSOPARTY, True, InStateMultiplierOf(INQSOPARTY, 'OH'), rmDomestic),
             'Ohio is');
   CheckTrue(CountsForEntrant(INQSOPARTY, True, InStateMultiplierOf(INQSOPARTY, 'INADA'), rmDomestic),
             'a county is');
   CheckTrue(CountsForEntrant(INQSOPARTY, False, host, rmDomestic), 'outside Indiana the rule is not asked');
   CheckFalse(CountsForEntrant(INQSOPARTY, True, 'DX', rmDomestic), 'and DX is still no multiplier');
end;

procedure TContestIndianaQPTests.RunAllTests;
begin
   Test_IndianaMultipliersCountOncePerMode;
   Test_IndianaIsNoStateMultiplierInState;
end;

end.

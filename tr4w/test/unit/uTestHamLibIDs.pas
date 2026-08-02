{
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
}
unit uTestHamLibIDs;

{
  Every radio's HamLib rig_model, as registered, checked against the value the
  legacy RadioParametersArray carried.

  WHY THIS EXISTS.  The registry rows were populated from that array by script,
  93 of them in one pass.  A script that silently transcribes the wrong number
  produces a radio that connects to HamLib as some OTHER rig -- which does not
  fail to compile, does not fail to connect, and misbehaves only in ways an
  operator has to notice on the air.  This is the check that a compiler cannot
  do for us.

  It also guards the retirement itself (task #28).  RadioParametersArray is
  being kept for historic reference but must stop being read by running code;
  the moment the last reader goes, nothing else would notice these two drifting
  apart.  #16 exists because they HAD drifted -- three wrong hamlibIDs, found
  only when someone went looking.

  The expected values are LITERALS, read out of RadioParametersArray by hand and
  written here, rather than read from the array at run time.  That is the point:
  if a future edit changes the array, this test does not quietly follow it.

  It is not an independent authority on what each rig_model SHOULD be -- HamLib's
  riglist.h is that -- it is a fixture that catches the registry drifting from
  the values TR4W has been shipping.  (Writing it, I first guessed six of these
  from memory and got all six wrong, which is a fair demonstration of why the
  numbers are checked against the source rather than recalled.)
}

interface

uses
   SysUtils, uTR4WTestFramework, uRadioRegistry, VC;

type
   THamLibIDTests = class(TTestCase)
   protected
      procedure CheckID(model: InterfacedRadioType; expected: Integer;
                        const label_: string);
      procedure Test_EnumRadiosCarryTheirHamLibID;
      procedure Test_TheThreeThatHadDrifted;
      procedure Test_UnregisteredIsZero;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure THamLibIDTests.CheckID(model: InterfacedRadioType; expected: Integer;
                                 const label_: string);
begin
   CheckEquals(expected, RegisteredHamLibID(model), label_);
end;

procedure THamLibIDTests.Test_EnumRadiosCarryTheirHamLibID;
begin
   BeginTest('registered radios report the HamLib rig_model they were given');

   // A spread across every family, so a whole-family miss cannot hide.
   CheckID(K2,        2021, 'Elecraft K2');
   CheckID(K3,        2029, 'Elecraft K3');
   CheckID(KX3,       2045, 'Elecraft KX3');
   CheckID(K4,        2047, 'Elecraft K4');

   CheckID(TS570,     2016, 'Kenwood TS-570');
   CheckID(TS850,     2009, 'Kenwood TS-850');

   CheckID(IC718,     3013, 'Icom IC-718');
   CheckID(IC7300,    3073, 'Icom IC-7300');

   CheckID(FT1000MP,  1024, 'Yaesu FT-1000MP');
   CheckID(FT847,     1001, 'Yaesu FT-847');

   CheckID(ORION,    16008, 'Ten-Tec Orion');
end;

procedure THamLibIDTests.Test_TheThreeThatHadDrifted;
begin
   BeginTest('the three IDs corrected in task #16 stayed corrected');

   // These were WRONG in RadioParametersArray until #16.  If the registry ever
   // reports the old values again, something re-imported stale data.
   CheckID(TS590,  2031, 'Kenwood TS-590 (was wrong before #16)');
   CheckID(TS2000, 2014, 'Kenwood TS-2000 (was wrong before #16)');
   CheckID(FLEX,   2036, 'Flex 6000+ (was wrong before #16)');
end;

procedure THamLibIDTests.Test_UnregisteredIsZero;
begin
   BeginTest('an unregistered model reports 0, not a stale or random id');

   // NoInterfacedRadio is the "no radio" sentinel and is deliberately not
   // registered.  0 is the honest answer, and it is what SetUpRadioInterface
   // must NOT hand to HamLib -- the reason the array is still the source there
   // until every row is populated and verified.
   CheckEquals(0, RegisteredHamLibID(NoInterfacedRadio),
               'the NONE sentinel has no rig_model');
end;

procedure THamLibIDTests.RunAllTests;
begin
   Test_EnumRadiosCarryTheirHamLibID;
   Test_TheThreeThatHadDrifted;
   Test_UnregisteredIsZero;
end;

end.

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
{$I ..\..\src\tr4w.inc}

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
   SysUtils, uTR4WTestFramework, uRadioRegistry, VC, uHamLibDirect;

type
   THamLibIDTests = class(TTestCase)
   protected
      procedure CheckID(model: InterfacedRadioType; expected: Integer;
                        const label_: string);
      procedure Test_EnumRadiosCarryTheirHamLibID;
      procedure Test_TheThreeThatHadDrifted;
      procedure Test_UnregisteredIsZero;
      procedure Test_IcomCIVAddresses;
      procedure Test_ScalarWidthsMatchTheCABI;
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

procedure THamLibIDTests.Test_IcomCIVAddresses;
begin
   BeginTest('Icom CI-V receiver addresses come from the registry');

   // Populated from RadioParametersArray's RA column by script, 44 of them.  A
   // wrong CI-V address is the same class of silent fault as a wrong rig_model:
   // it compiles, it connects, and the radio simply ignores commands addressed
   // to somebody else.  Spread across the range so a block-shift cannot hide.
   CheckEquals($5E, RegisteredCIVAddress(IC718),  'IC-718');
   CheckEquals($94, RegisteredCIVAddress(IC7300), 'IC-7300');
   CheckEquals($98, RegisteredCIVAddress(IC7610), 'IC-7610');
   CheckEquals($A4, RegisteredCIVAddress(IC705),  'IC-705');
   CheckEquals($04, RegisteredCIVAddress(IC735),  'IC-735 (lowest)');
   CheckEquals($70, RegisteredCIVAddress(IC7000), 'IC-7000');
   CheckEquals($88, RegisteredCIVAddress(IC7100), 'IC-7100');

   // A non-CI-V radio must report 0, not a neighbour's address -- this is what
   // uCFG seeds Radio.ReceiverAddress from for EVERY model, Icom or not.
   CheckEquals(0, RegisteredCIVAddress(K3),    'the K3 is not a CI-V radio');
   CheckEquals(0, RegisteredCIVAddress(TS570), 'the TS-570 is not a CI-V radio');
   CheckEquals(0, RegisteredCIVAddress(NoInterfacedRadio), 'the NONE sentinel');
end;

(* THE SCALAR ABI, WHICH NO COMPILER CHECKS.

  uHamLibDirect binds hamlib through GetProcedureAddress, so every parameter
  is whatever Pascal says it is and NOTHING verifies that against rig.h. A
  type declared one word too narrow does not fail to compile, does not fail to
  load, and misbehaves only on the air -- the same class of defect as a wrong
  rig_model above, which is why it lives in this unit.

  THE THREE THAT MOVE ARE shortfreq_t, pbwidth_t AND hamlib_token_t. They are
  a C `long`, whose width is set by the platform DATA MODEL and not by the
  bitness of the build:

      Windows i386    ILP32   long = 32
      Windows x86_64  LLP64   long = 32   <-- unchanged by the 64-bit port
      Linux x86_64    LP64    long = 64
      macOS aarch64   LP64    long = 64

  So this test asserts 4 on Windows only, and asserts the INVARIANTS that hold
  everywhere separately. Do not "fix" a failure here by widening the type on
  Windows -- Microsoft kept long at 32 bits, and clong already knows that. *)
procedure THamLibIDTests.Test_ScalarWidthsMatchTheCABI;
begin
   BeginTest('the hamlib scalar types match rig.h on this platform');

   // FIXED WIDTH EVERYWHERE -- these never move, so a change is a mistake.
   CheckEquals(8, SizeOf(freq_t),      'freq_t is a C double');
   CheckEquals(8, SizeOf(rmode_t),     'rmode_t is a C uint64_t');
   CheckEquals(8, SizeOf(setting_t),   'setting_t is a C uint64_t');
   CheckEquals(4, SizeOf(vfo_t),       'vfo_t is a C unsigned int');
   CheckEquals(4, SizeOf(ptt_t),       'ptt_t is a C enum');
   CheckEquals(4, SizeOf(dcd_t),       'dcd_t is a C enum');

   // THE C TYPEDEF RELATIONSHIP: rig.h:663 is `typedef shortfreq_t pbwidth_t`,
   // so these two cannot legally disagree on ANY platform. Declaring them
   // independently is how they would drift.
   CheckEquals(SizeOf(shortfreq_t), SizeOf(pbwidth_t),
               'pbwidth_t IS shortfreq_t (rig.h:663)');

   // A POINTER IS A POINTER -- this is the one the 64-bit port does move.
   CheckEquals(SizeOf(Pointer), SizeOf(PRIG), 'PRIG is an opaque RIG*');

{$IFDEF WINDOWS}
   // ILP32 and LLP64 agree: a C long is 32 bits on BOTH Windows targets, so
   // this arm is correct for the Win64 build too and must not be relaxed.
   CheckEquals(4, SizeOf(shortfreq_t),    'C long is 32-bit on Windows');
   CheckEquals(4, SizeOf(hamlib_token_t), 'C long is 32-bit on Windows');
{$ELSE}
   // LP64: a C long follows the pointer on the unixes TR4W builds for.
   CheckEquals(SizeOf(Pointer), SizeOf(shortfreq_t),
               'C long follows the pointer on LP64');
   CheckEquals(SizeOf(Pointer), SizeOf(hamlib_token_t),
               'C long follows the pointer on LP64');
{$ENDIF}
end;

procedure THamLibIDTests.RunAllTests;
begin
   Test_EnumRadiosCarryTheirHamLibID;
   Test_TheThreeThatHadDrifted;
   Test_UnregisteredIsZero;
   Test_IcomCIVAddresses;
   Test_ScalarWidthsMatchTheCABI;
end;

end.

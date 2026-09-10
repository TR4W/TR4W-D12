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
unit uPortAddress;
{$I tr4w.inc}

(*
  WHERE A PORT'S IDENTITY LIVES.

  ------------------------------------------------------------------------
  WHY THIS UNIT EXISTS
  ------------------------------------------------------------------------

  TR4W stores a serial port as 'SERIAL n', parses that into a PortType
  ordinal, and turns the ordinal back into a device name at the point of
  opening.  Three spellings of one fact, and the two ends of the chain are
  the same thing: the name the operating system answers to.

  THAT LAST STEP WAS WRITTEN FIVE TIMES.  Once in MainUnit as
  ConvertPortTypeToCOMString, and four more times as a bare
  Format('COM%d', [Ord(port)]) -- in the radio factory, the CW keyer, the
  rotator controller and the WinKeyer.  Three of the four carried a comment
  saying so out loud: "the same rule the radio factory, the WinKeyer and the
  CW keyer all use".  Knowing they were copies did not stop them being copies.

  Five copies is five edits when the rule changes, and the rule IS changing.
  A port on Linux is /dev/ttyUSB0 and NO ARITHMETIC ON AN ORDINAL WILL EVER
  PRODUCE IT.  So this unit is the choke point the move off 'SERIAL n' flows
  through: today the ordinal is still the input, and what changes later is
  that it stops being.

  ------------------------------------------------------------------------
  WHAT A PortType IS ACTUALLY BEING ASKED
  ------------------------------------------------------------------------

  Three different questions, which is the whole problem with it:

    1. WHAT KIND of port is this -- serial, network, LPT, none.  This is what
       nearly every call site asks, through `= NoPort`, `= Network` or
       `in SerialPorts`, and it is the only one of the three that genuinely
       wants an enumeration.
    2. WHICH port.  Only the name formatter asks this, and it is the part
       that cannot be spelled off Windows.
    3. A SMALL INTEGER to key an array.  Exactly one table wants this, and it
       wants a dictionary instead.

  Separating those is the work.  This unit starts with question 2 because it
  is the one that was copied five times.
*)

interface

uses
   VC;   // PortType, SerialPorts

type
   (*
     WHAT KIND OF PORT THIS IS, and the only one of PortType's three jobs that
     genuinely wants an enumeration.

     Nearly every site that touches a configured port asks only this -- on the
     radio path alone, 25 of them -- through `= NoPort`, `= Network`,
     `in SerialPorts` or an LPT range test.  None of them cares WHICH port.

     FOUR VALUES, NOT SIXTY-EIGHT.  PortType has 64 serial members because it
     was also carrying the address; that is what this splits off.
   *)
   TPortKind = (pkNone, pkSerial, pkNetwork, pkParallel);

(*
  The device name the operating system answers to, for a configured port.

  '' FOR A PORT THAT IS NOT SERIAL, and that is a fix rather than a
  formality.  Three of the five call sites this replaces guarded only with
  `<> NoPort`, so a port configured as NETWORK -- ordinal 65, one past
  Serial64 -- produced the device name 'COM65' and an open against whatever
  happened to be on it.  Nothing reported that; the open either failed with a
  name the operator had never configured, or succeeded against someone else's
  hardware.

  ON THE ORDINAL.  Serial1 is ordinal 1 BY CONSTRUCTION of the enum, so the
  COM number is the ordinal and there is no table to consult.  That property
  is the reason this can be one line, and also the reason it is Windows-only:
  it is a fact about how the enum was declared, not about how ports are named.
*)
function SerialDeviceName(const aPort: PortType): string;

(*
  THE NAME TO ACTUALLY OPEN: the one that was CONFIGURED, if there is one, and
  otherwise the one the ordinal implies.

  This is the widen half of widen-then-narrow -- step 1 of
  docs\PORT_IDENTITY_PLAN.md.  Every caller asks this instead of
  SerialDeviceName, and every name is empty today, so the answer is unchanged
  until the store starts supplying one.  When it does, no call site changes
  again.

  WHY A NAME BEATS AN ORDINAL, in one line: /dev/ttyUSB0 cannot be computed
  from a number, and COM7 no longer has to be.

  TRIMMED, because a name arrives from a settings file an operator can edit,
  and ' COM7 ' is a port they meant.
*)
function EffectiveDeviceName(const aConfiguredName: string;
                             const aPort: PortType): string;

(*
  WHAT KIND OF PORT A CONFIGURED PAIR DESCRIBES.

  A NAME IS ALWAYS SERIAL, AND THAT IS WHY THIS EXISTS.  '/dev/ttyUSB0' has no
  ordinal -- none can be computed -- so on Linux the enum is NoPort while the
  port is perfectly real.  Every `in SerialPorts` test would say the radio is
  not serial, the serial arm would never run, and the name would never be read.

  THIS IS WHY THE STEPS IN docs\PORT_IDENTITY_PLAN.md WERE REORDERED.  That
  document had the store move to device names BEFORE the kind was separable.
  Doing step 1 showed it cannot: a store holding a device node, with the kind
  still derived from an ordinal, produces a radio that is configured and
  invisible.  The kind has to come out first.

  A network port has an address and a port number, never a device name, so the
  name arm cannot swallow one.
*)
function PortKindOf(const aConfiguredName: string;
                    const aPort: PortType): TPortKind;

implementation

uses
   SysUtils;

function SerialDeviceName(const aPort: PortType): string;
begin
   if not (aPort in SerialPorts) then
      begin
      Result := '';
      Exit;
      end;

   Result := 'COM' + IntToStr(Ord(aPort));
end;

function EffectiveDeviceName(const aConfiguredName: string;
                             const aPort: PortType): string;
begin
   Result := Trim(aConfiguredName);
   if Result <> '' then
      begin
      Exit;
      end;

   (* NO NAME CONFIGURED -- fall back to what the ordinal means.  That is the
     Windows answer and, until the store carries names, the only answer. *)
   Result := SerialDeviceName(aPort);
end;

function PortKindOf(const aConfiguredName: string;
                    const aPort: PortType): TPortKind;
begin
   (* THE NAME DECIDES, WHEN THERE IS ONE.  See the note on the declaration:
     a device node has no ordinal, so asking the ordinal would call a real
     port "not configured". *)
   if Trim(aConfiguredName) <> '' then
      begin
      Result := pkSerial;
      Exit;
      end;

   if aPort in SerialPorts then
      begin
      Result := pkSerial;
      end
   else if aPort = Network then
      begin
      Result := pkNetwork;
      end
   else if aPort in [Parallel1, Parallel2, Parallel3] then
      begin
      Result := pkParallel;
      end
   else
      begin
      (* NoPort, and anything the enum grows that this does not know about.
        Defaulting to "nothing configured" is the safe answer: it opens no
        transport, where guessing serial would open the wrong one. *)
      Result := pkNone;
      end;
end;

end.

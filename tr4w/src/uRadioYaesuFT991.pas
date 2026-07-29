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
unit uRadioYaesuFT991;

{
  Yaesu FT-991 / FT-991A -- lead model of the legacy rtYaesu3 group (FT-891,
  FT-991), migrated from uRadioPolling.pFT891_FT991.

  It is a SUBCLASS of TYaesuSerial (uRadioYaesuASCII), not a new family base,
  because the wire protocol is the same one:

    IF; / OI;   28 bytes, identical field offsets -- frequency at 6 (9 digits,
                Issue #218), clarifier 15-19, RIT-on 20, XIT-on 21, mode 22
    split       read with FT;, set with FT3; on / FT2; off
    TX state    TX;, '1'/'2' = transmitting
    poll cycle  IF;OI;FT;TX;

  Verified by reading the two legacy pollers side by side: pFT891_FT991 and
  pFTDX10_FTDX101 are the same procedure except for which GetVFOInfoForYaesuType
  they call, and LOGRADIO's split/UP/DN/MemoryKeyer arms list FT991 alongside
  FTDX10 in every case.  rtYaesu3 and rtYaesu4 are never distinguished anywhere in
  LOGRADIO -- the split is a polling-table artifact, not a protocol difference.

  THE ONE REAL DEVIATION is the mode character at IF/OI position 22, where the
  legacy Type3 and Type5 maps disagree on exactly one code:

                    Type3 (FT-991)          Type5 (FTDX-10)
      'E'           C4FM                    PSK31
      'F'           -- (unmapped)           DATA-FM

  'E' is why this class exists.  The FT-991 is a System Fusion radio, so 'E' is
  C4FM there; the FTDX-10 has no C4FM and uses 'E' for PSK31.  Decoding one as the
  other would put the wrong mode in the log on an FM QSO.

  CONFIRMED AGAINST THE MANUFACTURER (NY4I supplied the FT-991 CAT manual page for
  the MD command).  Yaesu's own table reads:

      1 LSB   2 USB   3 CW-U   4 FM    5 AM     6 RTTY-LSB   7 CW-L
      8 DATA-LSB      9 RTTY-USB       A DATA-FM             B FM-N
      C DATA-USB      D AM-N           E C4FM

  which matches this driver's map entry for entry: 'E' really is C4FM, 'B' really
  is FM-N, 3/7 are CW-U/CW-L (rmCW/rmCWRev), 6/9 are RTTY-LSB/RTTY-USB
  (rmFSK/rmFSKRev -- LSB being the conventional RTTY sense), and 8/A/C are the
  three DATA variants.  NOTE ALSO: the FT-991 table has NO 'F'.  The inherited base
  map defines 'F' as DATA-FM, which comes from the FTDX-10 side; harmless here
  because this radio never sends it.

  Scope of that evidence: the page documents the MD command, not IF.  The IF
  response's mode field at position 22 uses the same code set -- that part rests on
  the legacy parser, which is bench-proven, rather than on the page itself.

  C4FM maps to rmFM, NOT rmDV, matching the legacy Type3 map (TempMode := FM,
  ExtendedMode := eC4FM).  rmDV looks like the better fit by name, but it is
  D-STAR-specific downstream: MainUnit's mode conversion turns rmDV into
  eDStar/Phone, which would be both wrong and a behaviour change from the
  bench-proven legacy path.  The factory's TRadioMode has no C4FM member; rmFM is
  the honest approximation and preserves what the radio has always reported.

  FT-891 IS NOT REGISTERED HERE.  It is the other rtYaesu3 radio and would be a
  small subclass of this one, but it needs two overrides and has no tester yet:
    - split is ST1;/ST0; and is READ with ST;, not FT; (the 891 has no FT
      command at all -- see the explicit else-arm in pFT891_FT991)
    - PollRadioState must therefore query ST; in place of FT;
  Until someone has one on the bench it stays on the legacy path, which is the
  live fallback for every unproven model.

  ****  NOT YET BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES (what to actually check on a real FT-991).  The mode map no longer
  belongs on this list -- Yaesu's own MD table settles it, above -- so what remains
  is the part no document can answer:
    - Split: engage split at the radio and confirm TR4W shows it at startup;
      also toggle it from TR4W in both directions.
    - Clarifier: confirm positions 15-19 return sign + 4 digits ("+0000"/"-0000").
    - That the IF response really is 28 bytes with the mode at position 22, since
      that offset comes from the legacy parser rather than from the manual page.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCII, uRadioRegistry, VC;

type
  // FT-991 / FT-991A -- rtYaesu3.  Same wire protocol as the FTDX-10; differs
  // only in the mode-character map (see the unit header).
  TYaesuFT991Radio = class(TYaesuSerial)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFT991Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-991';
   // Same capability set as the FTDX-10: VFO B via OI;, clarifier, split via FT;,
   // TX state via TX;.
   FCapabilities.Flags := [rcReadVFOB, rcReadRIT, rcReadSplit, rcReadTXStatus];
   FCapabilities.CWSpeedMin := FCWSpeedMin;
   FCapabilities.CWSpeedMax := FCWSpeedMax;

   // The ONE map entry that differs from the FTDX-10 generation.  Declared as
   // DATA rather than a method override: it is a fact about this radio, not a
   // behaviour, and stating it here keeps the FT-891 -- which shares the same
   // Type3 map -- from having to descend from the FT-991's unit just to inherit
   // one character.
   FModeCharE := rmFM;       // C4FM (System Fusion).  See the header on rmDV.
end;

initialization
  // FT-991 and FT-991A are the same radio to CAT; TR4W's enum has one member.
  RegisterRadio(FT991,
     function: TFactoryRadioBase begin Result := TYaesuFT991Radio.Create end,
     'Yaesu FT-991', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.

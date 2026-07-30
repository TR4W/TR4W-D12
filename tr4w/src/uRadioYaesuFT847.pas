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
unit uRadioYaesuFT847;

{
  Yaesu FT-847 -- shares the FT-817's 5-byte transport and its MAIN-VFO opcodes,
  but is a SATELLITE radio and is missing several things the FT-817 has.

  Source: FT-847 Operating Manual, "CAT System Programming", pages 91-93 (opcode
  chart on p.92).  Read directly -- not inferred from the FT-817.

  WHAT IT SHARES with the FT-817 (hence subclassing rather than a new family):
    - 5-byte block, opcode last, 1 start / 8 data / no parity / 2 stop bits
    - set frequency  $01, 4 BCD digits, MSD first
    - set mode       $07, mode byte at P1
    - read freq+mode $03
    - PTT            $08 on / $88 off

  WHAT IT DOES NOT HAVE -- each is a flag, not a model test in the base class:

    NO SPLIT.  The opcode chart has no SPLIT row at all.  The FT-847 uses SAT RX
    and SAT TX VFOs instead of an A/B split, so there is nothing to send and
    nothing to read back.  FHasSplit := False also stops the base interpreting
    TX-status bit 5 as split: the FT-847's Note 2 layout is its own, and reading
    the FT-817's bit positions into it would be a guess.

    NO RIT OVER CAT.  The chart has no CLAR ON/OFF and no CLAR Frequency row
    ("CLAR", clarifier, being Yaesu's name for RIT/XIT), so RIT does not exist over
    CAT on this radio.  Leaving FHasRIT at the base's False makes all four RIT
    entry points log and return instead of sending undefined opcodes.

    NO DATA MODES.  The mode chart is LSB/USB/CW/CW-R/AM/FM plus the narrow
    variants CW-N $82, CW-R-N $83, AM-N $84, FM-N $88.  There is no DIG and no
    PKT.  LOGRADIO's row agrees independently (DIGL $FF, DIGU $FF), which is the
    convention reused here.

  WHAT IT NEEDS THAT THE FT-817 DOES NOT:

    CAT MUST BE ENABLED FIRST.  Chart row "CAT ON/OFF": P1=00 CAT ON, P1=80 CAT
    OFF -- i.e. the 5-byte all-zero frame, which is exactly the legacy
    TurnOn847CATString.  The radio ignores CAT traffic until it arrives.  Legacy
    sent it once at the top of the poll procedure; FCATEnableOnConnect sends it
    from Connect, which is the same moment named honestly.

  NOT MODELLED (deliberate):
    - Satellite mode ($4E/$8E) and the SAT RX/TX VFO variants of set-freq
      ($11/$21), set-mode ($17/$27) and read ($13/$23).  TR4W has no concept of a
      satellite VFO pair, and inventing one to fit this radio is out of scope for
      a migration.  MAIN VFO only, which is what the legacy driver did too.
    - The narrow mode variants: TRadioMode has no narrow-filter members.

  OPERATOR NOTE FOR THE WIKI: the FT-847 needs a NULL MODEM (crossed) serial
  cable, not the straight cable used by other Yaesu CAT radios -- the manual
  calls this out twice.  Also, CAT cannot be used while an FC-20 antenna tuner is
  connected to the TUNER jack.  Baud is set by Menu #37 (4800 / 9600 / 57600);
  TR4W's default row is 4800.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****
  BENCH QUESTIONS: does the poll answer arrive without the CAT-ON frame being
  repeated (i.e. is once at connect enough)?  Does TX status report anything we
  could use for PTT?
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioYaesuFT817Group, uRadioRegistry, VC,
     Log4D;

type
  TYaesuFT847Radio = class(TYaesuFT817Group)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFT847Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT847');
   radioModel := 'Yaesu FT-847';

   // The ONE thing this radio adds: it answers nothing until CAT is enabled
   // (chart: CAT ON/OFF, P1 = 00).
   FCATEnableOnConnect := True;

   // Everything else stays at the base's restrictive default, stated here so the
   // absence is deliberate rather than forgotten:
   //   FHasSplit     False -- no SPLIT row in the chart
   //   FHasRIT False -- no CLAR rows in the chart
   //   FModeDIGU/L   MODEBYTE_NONE -- no DIG, no PKT
   //   FCapabilities.Flags []  -- split is neither settable nor readable
   //
   // This used to be five lines of SUBTRACTION, undoing an [rcReadSplit] and four
   // traits inherited from TYaesuFT817Radio.  With the group base promising
   // nothing, there is nothing left to undo -- which is the whole reason the base
   // was extracted.
end;

initialization
  RegisterRadio(FT847,
     function: TFactoryRadioBase begin Result := TYaesuFT847Radio.Create end,
     'Yaesu FT-847', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.

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
unit uRadioYaesuFT857;

{
  Yaesu FT-857 and FT-897.

  Source: FT-857D Operating Manual, "CAT Operation", pages 115-118 (opcode chart
  p.117, notes p.118).  The FT-897 shares the legacy poller and an identical
  parameter row, and is registered here as a name-only subclass.

  IDENTICAL TO THE FT-817 in everything this driver uses: 5-byte block with the
  opcode last, set frequency $01 (4 BCD digits, MSD first), set mode $07, read
  freq+mode $03, read TX status $F7, split $02/$82, clarifier $05/$85/$F5, PTT
  $08/$88, and the same TX-status bit assignments (SPLIT bit 5 INVERTED, HI SWR
  bit 6, PTT bit 7).  Hence a thin subclass rather than its own family.

  THE ONE PROTOCOL DIFFERENCE -- data modes.  The FT-857D chart is:

      00 LSB   01 USB   02 CW    03 CWR   04 AM
      06 WFM   08 FM    88 FM-N  82 CW-N  0A DIG   0C PKT

  So $0A (DIG) exists, and $0C is PKT.  LOGRADIO's rows for both models record
  DIGU $0A and DIGL $FF -- i.e. TR4W offers DIG but not PKT-as-RTTY on these two,
  where it does map $0C for the FT-817.  That difference is preserved: FModeDIGL
  is $FF here, so asking for rmFSK logs and returns rather than switching the rig
  to packet.

  DEFERRED WRITES ARE NOT PORTED.  Legacy singled these two models out --
  `if RadioModel in [FT857, FT897] then tYaesuSendFreq := True` (LOGRADIO :3508,
  :3532) -- queueing set commands and emitting them from the poll loop with
  Sleep(100) + PurgeComm after each.  The manual gives no basis for it: the data
  protocol section and every opcode used here are the FT-817's, and nothing is
  said about write timing.  NY4I read the manual the same way.  See the note in
  uRadioYaesuFT817 for the full reasoning and the bench watch-item.

  NOT MODELLED: WFM ($06) and the narrow variants FM-N ($88) / CW-N ($82) --
  TRadioMode has no members for them.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****
  BENCH QUESTION (the one that matters here): after a QSY, does the log show
  repeated "Frame resync: discarded N byte(s)" WARNINGS with N > 1?  A single
  discarded byte is the expected set-command ack and is healthy.  A persistent
  pattern would mean the legacy deferral was compensating for something real.
}

interface

uses uFactoryRadioBase, uRadioYaesuBinary, uRadioYaesuFT817, uRadioRegistry, VC,
     Log4D;

type
  TYaesuFT857Radio = class(TYaesuFT817Radio)
  public
    constructor Create; reintroduce;
  end;

  // FT-897: same legacy poller, same parameter row (SFOC $01, SMOC $07, SW 0,
  // MB 0, DIGU $0A, DIGL $FF) -- differs only in hamlibID.  A name, not a
  // behaviour.  It still gets its own registration so it appears in the radio
  // list under its own name.
  TYaesuFT897Radio = class(TYaesuFT857Radio)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFT857Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT857');
   radioModel := 'Yaesu FT-857';

   // Row: DIGU $0A, DIGL $FF.  DIG yes, PKT-as-RTTY no.
   FModeDIGL := $FF;
   // Everything else stays at the FT-817 defaults: split and clarifier both
   // present, no CAT-enable preamble, DIGU $0A.
end;

constructor TYaesuFT897Radio.Create;
begin
   inherited Create;
   logger := TLogLogger.GetLogger('TR4WDebugLog.FT897');
   radioModel := 'Yaesu FT-897';
end;

initialization
  RegisterRadio(FT857,
     function: TFactoryRadioBase begin Result := TYaesuFT857Radio.Create end,
     'Yaesu FT-857', [rlSerial], 0, False);
  RegisterRadio(FT897,
     function: TFactoryRadioBase begin Result := TYaesuFT897Radio.Create end,
     'Yaesu FT-897', [rlSerial], 0, False);

end.

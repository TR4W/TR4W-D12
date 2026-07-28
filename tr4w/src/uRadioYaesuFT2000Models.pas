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
unit uRadioYaesuFT2000Models;

{
  Registrations for the rtYaesu2 generation -- FT-450, FT-950, FT-1200, FT-2000,
  FTDX-3000, FTDX-5000, FTDX-9000.  The protocol lives in uRadioYaesuASCIILegacy;
  this unit is the model list, the same shape as uRadioKenwoodModels.

  EVERY MODEL GETS ITS OWN REGISTRY ENTRY AND DISPLAY NAME even where several
  share a class: an operator buys an FTDX-5000, and a model with no name of its
  own is invisible in the radio list.

  The generation splits into two behaviours, and only one thing separates them:

    TYaesuASCIILegacy        FT-450, FT-1200, FTDX-3000, FTDX-5000
    TYaesuFT2000ActiveVFO    FT-950, FT-2000, FTDX-9000  -- these three also
                             poll FR; to learn which VFO is receiving

  That grouping is from uRadioPolling.pFTDX9000, which guards its FR; read with
  "if rig.RadioModel in [FT950, FT2000, FTDX9000]".  Here the radio declares it
  instead, so nothing in the base has to ask which model it is.

  THIS IS AN ASCII (Kenwood-style) PROTOCOL, not a binary one -- FA, IF, OI, FR,
  FT, MD, TX, KS, ID, all semicolon-terminated.  The "rtYaesu2" label groups it
  with rtYaesu3/4 by GENERATION, not by encoding; only rtYaesu1 is binary.
  Set-mode (MD0n;), PTT (TX1;/TX0;) and CW keyer speed (KS%.3d;) are inherited
  unchanged from TYaesuSerial, and match the legacy formats: LOGRADIO sends
  'KS%003u;' for rtYaesu2/3/4 alike (:3266-3272).

  FT-2000 IDENTIFICATION: ID returns 0251 (NY4I).  Recorded for a future ident
  check -- TR4W does not currently poll ID for this generation.  The mechanism
  exists on the Kenwood side (FExpectedIdent, uRadioKenwoodTS890) and would be
  new behaviour here, so it is deliberately not wired in this batch.

  ****  NONE OF THESE IS BENCH-VALIDATED  ****
  See uRadioYaesuASCIILegacy for what to check.

  ON THE MISSING SPLIT AND TX READBACK -- state this carefully.  TR4W does not
  read either for this generation: pFTDX9000 polls IF; and OI; (and FR; for three
  models) and nothing else, so the capability set withholds rcReadSplit and
  rcReadTXStatus to match.  That is a statement about THE DRIVER, not about the
  radio.  The FT-2000 does support TX (NY4I), so the readback is very likely a
  gap in TR4W rather than a hardware limitation -- an earlier version of this
  comment asserted the opposite and was wrong.  Adding the reads would be an
  improvement over D7, not a port fix, and wants a bench before it ships.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCIILegacy, uRadioRegistry, VC;

type
  // FT-950 / FT-2000 / FTDX-9000: additionally read FR; for the operating VFO.
  // Abstract in spirit -- it sets only the shared trait.  Each of the three then
  // declares its own FT and FR dialect below, because those two commands do NOT
  // divide these radios the same way (see uRadioYaesuASCIILegacy).
  TYaesuFT2000ActiveVFO = class(TYaesuASCIILegacy)
  public
    constructor Create; reintroduce;
  end;

  // FT-950: FT has absolute 2/3; FR uses 4/5 for VFO-B.
  TYaesuFT950Radio = class(TYaesuFT2000ActiveVFO)
  public
    constructor Create; reintroduce;
  end;

  // FT-2000: FT has ONLY 0/1 -- the one model where FT3;/FT2; is undefined.
  // FR is 0..3 like the FTDX-9000, NOT 0,1,4,5 like the FT-950.
  TYaesuFT2000Radio = class(TYaesuFT2000ActiveVFO)
  public
    constructor Create; reintroduce;
  end;

  // FTDX-9000: FT like the FT-950, FR like the FT-2000.
  TYaesuFTDX9000Radio = class(TYaesuFT2000ActiveVFO)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFT2000ActiveVFO.Create;
begin
   inherited Create;
   FReadsActiveVFO := True;
end;

constructor TYaesuFT950Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-950';
   // FT: 0/1 are TOGGLES, 2/3 are absolute -- use the absolute pair.
   FSplitAbsoluteTwoThree := True;
   // FR: 4 = VFO-A OFF/VFO-B RX, 5 = VFO-A OFF/VFO-B Mute.  Both mean B is the
   // receive VFO; legacy tested only '4', so a muted B reported VFO A.
   FVFOBReceivingChars := ['4', '5'];
end;

constructor TYaesuFT2000Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-2000';
   // FT: P1 is 0 (Main TX) or 1 (Sub TX) and NOTHING ELSE.  FT3;/FT2; -- which
   // LOGRADIO Issue #166 gave the whole group -- are undefined on this radio.
   FSplitAbsoluteTwoThree := False;
   // FR: 0..3 like the FTDX-9000; '4' never occurs, so the legacy test could
   // never fire and VFO B was never detected as the operating VFO.
   FVFOBReceivingChars := ['3'];
end;

constructor TYaesuFTDX9000Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FTDX-9000';
   FSplitAbsoluteTwoThree := True;    // FT like the FT-950
   FVFOBReceivingChars := ['3'];      // FR like the FT-2000
end;

initialization
  // --- no FR; read -------------------------------------------------------
  RegisterRadio(FT450,
     function: TFactoryRadioBase begin Result := TYaesuASCIILegacy.Create end,
     'Yaesu FT-450', [rlSerial], 0, False);
  RegisterRadio(FT1200,
     function: TFactoryRadioBase begin Result := TYaesuASCIILegacy.Create end,
     'Yaesu FT-1200', [rlSerial], 0, False);
  RegisterRadio(FTDX3000,
     function: TFactoryRadioBase begin Result := TYaesuASCIILegacy.Create end,
     'Yaesu FTDX-3000', [rlSerial], 0, False);
  RegisterRadio(FTDX5000,
     function: TFactoryRadioBase begin Result := TYaesuASCIILegacy.Create end,
     'Yaesu FTDX-5000', [rlSerial], 0, False);

  // --- also poll FR;, each with its own FT/FR dialect (manuals via NY4I) -----
  RegisterRadio(FT950,
     function: TFactoryRadioBase begin Result := TYaesuFT950Radio.Create end,
     'Yaesu FT-950', [rlSerial], 0, False);
  RegisterRadio(FT2000,
     function: TFactoryRadioBase begin Result := TYaesuFT2000Radio.Create end,
     'Yaesu FT-2000', [rlSerial], 0, False);
  RegisterRadio(FTDX9000,
     function: TFactoryRadioBase begin Result := TYaesuFTDX9000Radio.Create end,
     'Yaesu FTDX-9000', [rlSerial], 0, False);

end.

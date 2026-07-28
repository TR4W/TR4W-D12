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

  ****  NONE OF THESE IS BENCH-VALIDATED  ****
  See uRadioYaesuASCIILegacy for what to check.  Note in particular that this
  generation has NO split readback and NO TX readback -- that is the radio's
  limitation, not a gap in the port, and the capability set says so.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCIILegacy, uRadioRegistry, VC;

type
  // FT-950 / FT-2000 / FTDX-9000: additionally read FR; for the operating VFO.
  TYaesuFT2000ActiveVFO = class(TYaesuASCIILegacy)
  public
    constructor Create; reintroduce;
  end;

implementation

constructor TYaesuFT2000ActiveVFO.Create;
begin
   inherited Create;
   FReadsActiveVFO := True;
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

  // --- also poll FR; for the operating VFO -------------------------------
  RegisterRadio(FT950,
     function: TFactoryRadioBase begin Result := TYaesuFT2000ActiveVFO.Create end,
     'Yaesu FT-950', [rlSerial], 0, False);
  RegisterRadio(FT2000,
     function: TFactoryRadioBase begin Result := TYaesuFT2000ActiveVFO.Create end,
     'Yaesu FT-2000', [rlSerial], 0, False);
  RegisterRadio(FTDX9000,
     function: TFactoryRadioBase begin Result := TYaesuFT2000ActiveVFO.Create end,
     'Yaesu FTDX-9000', [rlSerial], 0, False);

end.

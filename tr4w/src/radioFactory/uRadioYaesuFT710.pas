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
unit uRadioYaesuFT710;

{
  Yaesu FT-710 -- rtYaesu4, migrated from uRadioPolling.pFTDX10_FTDX101.

  Reads exactly like the FTDX-10: same 28-byte IF;/OI;, same Type5 mode map, same
  poll cycle.  The legacy poller handles all three models with one procedure.

  THE ONE DEVIATION IS HOW SPLIT IS SET.

      FTDX-10 / FTDX-101 / FTX-1F      FT3; on, FT2; off
      FT-710                           FT1; on, FT0; off

  This is not a guess: LOGRADIO's PutRadioIntoSplit and PutRadioOutOfSplit each
  give the FT-710 its OWN arm, separate from the one shared by the other rtYaesu4
  radios, precisely because it takes the older two-value form.  Sending FT3; to an
  FT-710 would be silently ignored and split would never engage.

  READING split is unchanged -- FT; reports the TX VFO and any non-zero means
  split -- so only the setter is overridden.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES:
    - Split, both directions, and confirm split set at the radio shows in TR4W.
      This is the one place the FT-710 is known to differ, so it is the one place
      most likely to be wrong.
    - The 28-byte IF layout, as for the FTDX-101: a later radio in this same
      family (FTX-1F) shifted every field by two.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCII, uRadioRegistry, VC;

type
  TFT710Radio = class(TYaesuSerial)
  public
    constructor Create; reintroduce;
    procedure Split(splitOn: boolean); override;
  end;

implementation

constructor TFT710Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-710';
   FCapabilities.Flags := [rcReadVFOB, rcReadRIT, rcReadSplit, rcReadTXStatus];
   FCapabilities.CWSpeedMin := FCWSpeedMin;
   FCapabilities.CWSpeedMax := FCWSpeedMax;
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWSpeedSync, rcPlayDVK];
end;

procedure TFT710Radio.Split(splitOn: boolean);
begin
   // FT1;/FT0; -- see the unit header.  The rest of the family uses FT3;/FT2;.
   if splitOn then
      begin
      Self.SendToRadio('FT1;');
      end
   else
      begin
      Self.SendToRadio('FT0;');
      end;
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateFT710: TFactoryRadioBase;
begin
   Result := TFT710Radio.Create;
end;

initialization
  RegisterRadio(FT710,
     CreateFT710,
     'Yaesu FT-710', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.

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
unit uRadioElecraftBase;

{
  What every Elecraft radio has in common, regardless of how it is connected.

  The K2/K3/KX3 (serial) and the K4 (network) are separate classes with separate
  transports, and until 2026-08-04 they were separate all the way down to
  TFactoryRadioBase -- so any fact true of "Elecraft" had to be stated twice.
  That is not hypothetical.  Both parsed the same IF response, they drifted, and
  it cost:

    * the SAME RIT/XIT bug had to be found and fixed TWICE -- each copy wrote
      only the legacy scalar and not the per-VFO offset the radio window reads,
      so the serial K3 and the serial K4 each showed a blank indicator until
      someone noticed, separately, months apart;
    * the IF length guard was fixed in one copy and left broken in the other.

  DECODING was lifted out first, into uElecraftIF -- a pure function over a
  string, unit-tested against captured responses (uTestElecraftIF).  APPLYING
  stayed duplicated, on the reasoning that the two radios legitimately differ in
  what they do with a decoded IF.  Reading both bodies side by side, they differ
  in ONE statement out of about fifty: the K3 selects between VFOs, the K4 uses
  the SWAP model (A/B exchange contents, so A is always the operating VFO) and
  must not be told to switch.

  So the apply lives here too, and that one statement is a virtual --
  SelectOperatingVFO -- which is what the difference actually is.  A difference
  worth one override is not a reason to keep a second copy of the other forty
  nine lines.

  BandNumToBand and ModeStrToMode came along for the same reason: both were
  character-for-character copies wrapping the shared uElecraftIF decode.
}

interface

uses
   uFactoryRadioBase, uRadioKYBase, uRadioBand;

type
   TElecraftRadio = class(TKYRadio)
   protected
      procedure DeclareCWProsigns; override;

      // Apply a decoded IF (Transceiver Information) response to this radio's
      // state.  Decoding is uElecraftIF.ParseElecraftIF; this is everything
      // after it.
      function  ParseIFCommand(cmd: string): boolean;

      // THE ONE THING THE K3 AND K4 DO DIFFERENTLY with an IF response.
      //
      // The K3 selects between VFOs, so it reports which one is receiving and
      // TR4W follows.  The K4 uses the swap model -- A and B exchange contents,
      // so A is ALWAYS the operating VFO -- and calling SetActiveVFO there
      // would fight the radio.  Base does the K3 thing; the K4 overrides with
      // nothing.
      procedure SelectOperatingVFO(rxVFOIsB: boolean); virtual;

      // Elecraft wire-format helpers, shared for the same reason.
      function  ModeStrToMode(sMode: string; sDataMode: string): TRadioMode;
      function  BandNumToBand(sBand: string): TRadioBand;
   end;

implementation

uses
   SysUtils,
   MainUnit,        // the logger this radio was given at connect
   uElecraftIF;     // the pure decode: ParseElecraftIF, ElecraftModeToRadioMode

procedure TElecraftRadio.DeclareCWProsigns;
begin
   // Elecraft KY spellings.  Order: half space, SN, AR, SK, BT.
   //
   // The half space is a whole space: a KY string has no half space.
   //
   // '' FOR SN IS DELIBERATE AND IS NOT "undeclared".  Elecraft has no SN, so
   // TR4W's '!' is CONSUMED and keys nothing -- which is not the same as
   // letting '!' through to be keyed as a literal character.  See
   // TFactoryRadioBase.CWProsign, where a declared-but-empty spelling and an
   // undeclared grammar are two different answers.
   FCapabilities.CWProsigns := CWProsigns(' ', '', '+', '*', '=');
end;

procedure TElecraftRadio.SelectOperatingVFO(rxVFOIsB: boolean);
begin
   if rxVFOIsB then
      begin
      Self.SetActiveVFO(nrVFOB);
      end
   else
      begin
      Self.SetActiveVFO(nrVFOA);
      end;
end;

function TElecraftRadio.ParseIFCommand(cmd: string): boolean;
var
   info: TElecraftIF;
   err: TElecraftIFError;
   vfo: TRadioVFO;
begin
   Result := false;

   err := ParseElecraftIF(cmd, info);
   if err <> ifeNone then
      begin
      logger.Error('[ParseIFCommand] %s', [ElecraftIFErrorText(err, cmd)]);
      Exit;
      end;

   // Base setters, not the raw scalars: they also write the per-VFO RITOffset
   // the radio window reads (uFactoryRadioBase.GetRITOffset).  On a SERIAL
   // Elecraft (AI off, IF;FB; polling) this IF response is the ONLY ongoing
   // RIT/XIT source -- the K4's network AI path at RT/XT/RO writes vfo[] itself
   // -- so writing just the scalar left the window indicator stuck off.  That
   // is the bug that was found and fixed twice, once per copy.
   Self.SetRITOffset(info.RITXITOffsetHz);
   Self.SetXITOffset(Self.localRITOffset);   // one shared register on Elecraft
   logger.trace('[ParseIFCommand] RITOffset = %d', [Self.localRITOffset]);

   Self.SetRITOn(info.RITOn);
   Self.SetXITOn(info.XITOn);
   logger.trace('[ParseIFCommand] RIT is %s, XIT is %s',
                [BoolToStr(info.RITOn, True), BoolToStr(info.XITOn, True)]);

   if info.Transmitting then
      begin
      Self.RadioState := rsTransmit;
      end
   else
      begin
      Self.RadioState := rsReceive;
      end;

   Self.SetSplitOn(info.SplitOn);

   // Route to the RX (operating) VFO reported by the IF 'v' field.  Whether
   // this radio should also be told to SWITCH to it is per-model: see
   // SelectOperatingVFO.
   if not info.RXVFOIsB then
      begin
      vfo := Self.vfo[nrVFOA];
      end
   else
      begin
      vfo := Self.vfo[nrVFOB];
      end;
   SelectOperatingVFO(info.RXVFOIsB);

   vfo.frequency := info.FrequencyHz;
   // Serial polling only sends IF;FB; (AI off), so BN never arrives on a band
   // change -- derive band from frequency here, as every other modern radio
   // class does (Icom/Flex/TS-890).  Keeps the band label in sync when the
   // operator changes bands on the radio.
   vfo.band := FreqToRadioBand(info.FrequencyHz);
   vfo.mode := ModeStrToMode(info.ModeChar, info.DataModeChar);
   Result := true;
end;

function TElecraftRadio.ModeStrToMode(sMode: string; sDataMode: string): TRadioMode;
var
   problem: string;
begin
   // The mapping itself lives in uElecraftIF alongside the IF decode.
   Result := ElecraftModeToRadioMode(sMode, sDataMode, problem);
   if problem <> '' then
      begin
      logger.Error('[ModeStrToMode] %s', [problem]);
      end;
end;

function TElecraftRadio.BandNumToBand(sBand: string): TRadioBand;
var
   iBand: integer;
begin
   iBand := StrToIntDef(sBand, -9);
   logger.trace('[BandNumToBand] Converting band string "%s" to iBand=%d', [sBand, iBand]);
   case iBand of
      0: Result := rb160m;
      1: Result := rb80m;
      2: Result := rb60m;
      3: Result := rb40m;
      4: Result := rb30m;
      5: Result := rb20m;
      6: Result := rb17m;
      7: Result := rb15m;
      8: Result := rb12m;
      9: Result := rb10m;
      10:Result := rb6m;
      -9:begin
         logger.Error('[BandNumToBand] Invalid band requested (non-numeric): %s', [sBand]);
         Result := rbNone;
         end;
   else
      begin
      logger.Error('[BandNumToBand] Unhandled band value: %d (from string: %s)', [iBand, sBand]);
      Result := rbNone;
      end;
   end;
   logger.trace('[BandNumToBand] Result band = %d', [Ord(Result)]);
end;

end.

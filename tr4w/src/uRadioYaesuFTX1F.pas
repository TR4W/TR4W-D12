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
unit uRadioYaesuFTX1F;

{
  Yaesu FTX-1F / FTX-1R -- rtYaesu4 (Issue #817), migrated from
  uRadioPolling.pFTX1F + GetVFOInfoForYaesuFTX1.

  IDENTIFICATION: the ID command answers ID0840; (NY4I).  Recorded for a future
  ident check; TR4W does not currently poll ID for this family.  (FT-2000 is
  0251, in uRadioYaesuFT2000Models.)

  SPLIT USES FT1;/FT0; -- A BUG FIX, NOT A STRAIGHT PORT.  Legacy sends FT3;/FT2;
  here, because LOGRADIO :2109/:2173 group FTX1F with FTDX10/FTDX101/FT991.  The
  FTX-1F manual's FT table defines P1 as exactly TWO values -- 0 = MAIN-side
  transmitter, 1 = SUB-side transmitter (i.e. split), confirmed by NY4I.  3 and 2
  are not among them, so the legacy command is undefined for this radio and split
  probably never engaged.

  What makes this convincing rather than a guess: TR4W already READS the answer as
  0/1 (SetSplitOn(msg[3] <> '0'), matching the manual) while WRITING 3/2.  A driver
  that reads a field one way and writes it another has usually had the write copied
  from a neighbouring model -- here the FTDX-10 branch, which the FTX-1F was added
  to when it was new (Issue #817).  The FT-710 already uses the two-value form and
  the FTX-1F is newer still.

  LOGRADIO :2109/:2173 carry the same defect and are corrected alongside this.
  That path is now only a fallback -- PutRadioIntoSplit returns early when a
  factory object exists -- but a wrong fallback is still wrong.

  Otherwise the same ASCII CAT family as the FTDX-10, but Yaesu MOVED EVERY FIELD
  IN THE IF/OI RESPONSE and made it longer.  This is the model that justified
  making ParseIFResponse a virtual seam:

                       FTDX-10 / FT-991      FTX-1F
      response length  28 bytes              30 bytes
      frequency        pos 6, 9 digits       pos 8, 9 digits
      clarifier        pos 15, sign + 4      pos 17, sign + 4
      RIT on           pos 20                pos 22
      XIT on           pos 21                pos 23
      mode             pos 22                pos 24

  Everything after the head is shifted by two, so a driver using the FTDX-10
  offsets would read a frequency built from the wrong digits -- plausible-looking
  garbage rather than an obvious failure.

  MODE MAP: the Type5 table plus two additions.  The FTX-1F is a System Fusion
  radio, but unlike the FT-991 it does NOT reuse 'E' for C4FM -- 'E' stays PSK31
  and C4FM arrives as 'H' or 'I' (two variants in the legacy map).  So this
  overrides ModeCharToMode to add the extra characters, rather than setting
  FModeCharE as the FT-991 does.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES:
    - The +2 offsets above are the whole risk.  If frequency looks wrong, dump a
      raw IF response and count characters before changing anything else.
    - 'H' and 'I' both mapping to C4FM comes from the legacy parser; the two are
      presumably C4FM variants, and both report as FM here (see uRadioYaesuFT991
      on why C4FM is rmFM and not rmDV).
    - Whether the FTX-1R behaves identically -- it shares this enum entry.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCII, uRadioRegistry, uRadioBand, SysUtils,
     Math, VC;

const
   // Field positions in the FTX-1F IF;/OI; response, from
   // GetVFOInfoForYaesuFTX1.  Named because "+2 from the FTDX-10" is only
   // obvious while you are holding both parsers side by side.
   FTX1F_BODY_LEN    = 29;   // 30 on the wire; the reading thread strips ';'
   FTX1F_FREQ_POS    = 8;
   FTX1F_FREQ_LEN    = 9;
   FTX1F_CLAR_POS    = 17;   // sign, then 4 digits
   FTX1F_RIT_POS     = 22;
   FTX1F_XIT_POS     = 23;
   FTX1F_MODE_POS    = 24;

type
  TFTX1FRadio = class(TYaesuSerial)
  protected
    procedure ParseIFResponse(const msg: string; whichVFO: TVFO); override;
    function  ModeCharToMode(c: Char): TRadioMode; override;
  public
    constructor Create; reintroduce;
    procedure Split(splitOn: boolean); override;
  end;

implementation

constructor TFTX1FRadio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FTX-1F';
   FCapabilities.Flags := [rcReadVFOB, rcReadRIT, rcReadSplit, rcReadTXStatus];
   FCapabilities.CWSpeedMin := FCWSpeedMin;
   FCapabilities.CWSpeedMax := FCWSpeedMax;
   // FModeCharE stays rmPSK: this radio has C4FM but reports it as 'H'/'I',
   // NOT by reusing 'E' the way the FT-991 does.
end;

procedure TFTX1FRadio.ParseIFResponse(const msg: string; whichVFO: TVFO);
var
   hz: integer;
   ritHz: integer;
   ritSign: integer;
begin
   // Deliberately NOT calling inherited: every offset differs.  See the table in
   // the unit header.
   if Length(msg) < FTX1F_MODE_POS then
      begin
      logger.Error('[FTX1F.ParseIFResponse] short response (%d chars, need %d): %s',
                   [Length(msg), FTX1F_MODE_POS, msg]);
      Exit;
      end;

   hz := StrToIntDef(Copy(msg, FTX1F_FREQ_POS, FTX1F_FREQ_LEN), -1);
   if hz < 0 then
      begin
      logger.Error('[FTX1F.ParseIFResponse] non-numeric frequency: %s',
                   [Copy(msg, FTX1F_FREQ_POS, FTX1F_FREQ_LEN)]);
      Exit;
      end;
   Self.vfo[whichVFO].frequency := hz;
   Self.vfo[whichVFO].band := FreqToRadioBand(hz);
   Self.vfo[whichVFO].mode := Self.ModeCharToMode(msg[FTX1F_MODE_POS]);

   ritSign := IfThen(msg[FTX1F_CLAR_POS] = '-', -1, 1);
   ritHz := StrToIntDef(Copy(msg, FTX1F_CLAR_POS + 1, 4), 0) * ritSign;
   Self.SetRITOffset(ritHz);
   Self.SetXITOffset(ritHz);
   Self.SetRITOn(msg[FTX1F_RIT_POS] = '1');
   Self.SetXITOn(msg[FTX1F_XIT_POS] = '1');
end;

function TFTX1FRadio.ModeCharToMode(c: Char): TRadioMode;
begin
   // Two characters the rest of the family does not use.  Everything else
   // defers upward so the shared table stays in one place.
   if (c = 'H') or (c = 'I') then
      begin
      Result := rmFM;        // C4FM variants -- rmFM, not rmDV; see FT-991 header
      end
   else
      begin
      Result := inherited ModeCharToMode(c);
      end;
end;

// FT P1: 0 = MAIN-side transmitter, 1 = SUB-side transmitter (split).  Only those
// two values exist on this radio -- see the unit header for why the inherited
// FT3;/FT2; is wrong here.  Same form the FT-710 uses.
procedure TFTX1FRadio.Split(splitOn: boolean);
begin
   if splitOn then
      begin
      Self.SendToRadio('FT1;');
      end
   else
      begin
      Self.SendToRadio('FT0;');
      end;
end;

initialization
  RegisterRadio(FTX1F,
     function: TFactoryRadioBase begin Result := TFTX1FRadio.Create end,
     'Yaesu FTX-1F', [rlSerial], 0, False);

end.

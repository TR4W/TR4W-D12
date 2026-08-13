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
unit uRadioYaesuASCIILegacy;
{$I ..\tr4w.inc}

{
  Yaesu ASCII CAT -- the OLDER generation (legacy rtYaesu2): FT-450, FT-950,
  FT-1200, FT-2000, FTDX-3000, FTDX-5000, FTDX-9000.  Ported from
  uRadioPolling.pFTDX9000 + GetVFOInfoForFT2000 and the LOGRADIO rtYaesu2 arms.

  Same command vocabulary as uRadioYaesuASCII -- IF;, OI;, FA/FB, MD0n; -- but a
  DIFFERENT WIRE FORMAT, which is why it is a generation of its own rather than a
  handful of per-model overrides:

                            newer (uRadioYaesuASCII)   THIS generation
      IF;/OI; length        28 bytes                   27 bytes
      frequency            pos 6, NINE digits          pos 6, EIGHT digits
      RIT offset            pos 15                      pos 14
      RIT on               pos 20                      pos 19
      XIT on               pos 21                      pos 20
      mode                 pos 22                      pos 21
      set frequency        FA%09u;                     FA%08u;
      split on / off       FT3; / FT2;                 FR0;FT3; / FR0;FT2;
      split READBACK       FT;                         NONE -- see below
      TX readback          TX;                         NONE

  The eight-vs-nine digit frequency is the same Issue #218 distinction LOGRADIO
  makes explicitly in its set-frequency arm, and it cuts both ways: reading a
  9-digit field out of a 27-byte response would swallow the following character
  and mis-scale everything after it.

  TWO THINGS THIS GENERATION CANNOT DO, declared as absent capabilities rather
  than silently not implemented:

    NO SPLIT READBACK.  The legacy poller never asks.  Split is set-only, so
    TR4W cannot discover split that was engaged at the front panel, and the
    indicator will not follow the radio.  That is a real functional gap versus
    the newer radios, not an oversight in this port -- pFTDX9000 has no FT; read
    and never touches CurrentStatus.Split.

    NO TX READBACK.  Same: no TX; in the poll cycle.

  WHAT FR; IS FOR HERE, and what it is NOT.  Three models -- FT-950, FT-2000,
  FTDX-9000 -- additionally poll FR; and treat a reply of '4' as "VFO B is the
  operating VFO".  It reports the RECEIVE VFO, not split.  Models that read it set
  FReadsActiveVFO in their constructor; the base never asks which radio it is.

  ****  NOT BENCH-VALIDATED -- every model here is on the tester list  ****

  BENCH NOTES:
    - The 27-byte layout above is the whole risk.  If frequency looks wrong,
      capture a raw IF response and count characters before touching anything.
    - Split, both directions.  FR0;FT3;/FR0;FT2; are the forms LOGRADIO settled
      on for Issue #166, replacing an earlier FR0;FT1;/FR0;FT0; -- so this
      command has already been wrong once.
    - On an FT-950/FT-2000/FTDX-9000: that selecting VFO B at the radio moves
      TR4W's displayed frequency to VFO B's.
}

interface

uses uFactoryRadioBase, uRadioYaesuASCII, uRadioBand, StrUtils, SysUtils, Math,
     Log4D, VC;

const
   // Field positions in the 27-byte IF;/OI; response (GetVFOInfoForFT2000).
   // Named because "one less than the newer radios" is not something to
   // rediscover from a diff at 3am during a contest.
   Y2_FREQ_POS = 6;
   Y2_FREQ_LEN = 8;      // EIGHT, not nine
   Y2_CLAR_POS = 14;     // sign, then 4 digits
   Y2_RIT_POS  = 19;
   Y2_XIT_POS  = 20;
   Y2_MODE_POS = 21;

type
  TYaesuASCIILegacy = class(TYaesuSerial)
  protected
    // FT-950 / FT-2000 / FTDX-9000 poll FR; to learn which VFO is receiving.
    // The others do not answer it, so asking would just cost a timeout.
    FReadsActiveVFO: boolean;

    // ---- THE TWO TRAITS THAT DO NOT AGREE ON A GROUPING ----------------------
    // These three radios divide DIFFERENTLY depending on which command you look
    // at, which is why both are flags and neither is a class split (manuals via
    // NY4I):
    //
    //             FT values                      FR values
    //   FT-950    0,1 toggle + 2,3 absolute      0,1,4,5   ('4' = VFO-B RX)
    //   FT-2000   0,1 ONLY                       0,1,2,3   (no '4' at all)
    //   FTDX-9000 0,1 toggle + 2,3 absolute      0,1,2,3   (no '4' at all)
    //
    // By FT the odd one out is the FT-2000; by FR it is the FT-950.  No single
    // hierarchy expresses that, so the model sets two independent flags and this
    // base never asks which radio it is.

    // True  -> split with FT3;/FT2;  (absolute "VFO-B TX" / "VFO-A TX")
    // False -> split with FT1;/FT0;  (the FT-2000, whose FT has only 0 and 1)
    // Note the FT-950/FTDX-9000 DO have 0/1 -- but there they are TOGGLES, which
    // cannot set a definite state.  That is what LOGRADIO Issue #166 was fixing
    // when it moved the whole group from FT1;/FT0; to FT3;/FT2; -- correct for
    // those two, but it left the FT-2000 sending a parameter it does not define.
    FSplitAbsoluteTwoThree: boolean;

    // Which FR replies mean "VFO B is the receiving VFO".
    //   FT-950              ['4','5']  -- 4 = B RX, 5 = B muted (still the RX VFO)
    //   FT-2000 / FTDX-9000 ['3']      -- 3 = Main muted, Sub RX
    // '2' on the latter two means BOTH receivers are live (true dual receive).
    // TR4W has a single "operating VFO", so '2' deliberately stays VFO A: with
    // both live, Main is the primary.  A judgement call, not a manual statement.
    FVFOBReceivingChars: TSysCharSet;

    procedure ParseIFResponse(const msg: string; whichVFO: TVFO); override;
  public
    constructor Create; reintroduce;
    procedure ProcessMessage(sMessage: string); override;
    procedure PollRadioState; override;
    procedure Split(splitOn: boolean); override;
    procedure SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode); override;
  end;

implementation

constructor TYaesuASCIILegacy.Create;
begin
   inherited Create;
   radioModel := 'Yaesu (rtYaesu2 generation)';   // models override
   FReadsActiveVFO := False;
   // Defaults = the legacy behaviour for the models NOT yet verified against a
   // manual (FT-450, FT-1200, FTDX-3000, FTDX-5000).  Each verified model sets
   // these explicitly in its own constructor, so the defaults never silently
   // stand in for a checked value.
   FSplitAbsoluteTwoThree := True;      // FT3;/FT2;, as legacy sends
   FVFOBReceivingChars    := ['4'];     // as legacy tests
   // No rcReadSplit and no rcReadTXStatus -- because TR4W DOES NOT POLL THEM,
   // not because the radios cannot report them.  State it that way round: an
   // earlier version of this comment claimed the generation "genuinely cannot"
   // and that is false.  The FTDX-9000 FT command has a documented Read form
   // whose answer P2 is 0 = TX on Main (VFO-A), 1 = TX on Sub (VFO-B) (NY4I,
   // manual) -- i.e. split readback exists and we simply never ask.  The legacy
   // poll cycle this was ported from (pFTDX9000) sends IF; OI; FR; and stops.
   //
   // Declaring the absence is still right: a caller can distinguish "split off"
   // from "we do not know".  But adding an FT; poll would be an IMPROVEMENT over
   // D7, not a port fix, and wants a bench before it ships.
   FCapabilities.Flags := [rcReadVFOB, rcReadRIT];
   FCapabilities.CWSpeedMin := FCWSpeedMin;
   FCapabilities.CWSpeedMax := FCWSpeedMax;
end;

procedure TYaesuASCIILegacy.ParseIFResponse(const msg: string; whichVFO: TVFO);
var
   hz: integer;
   ritHz: integer;
   ritSign: integer;
begin
   // Deliberately NOT calling inherited -- every offset differs, and the
   // frequency field is a different LENGTH.
   if Length(msg) < Y2_MODE_POS then
      begin
      logger.Error('[Y2.ParseIFResponse] short response (%d chars, need %d): %s',
                   [Length(msg), Y2_MODE_POS, msg]);
      Exit;
      end;

   hz := StrToIntDef(Copy(msg, Y2_FREQ_POS, Y2_FREQ_LEN), -1);
   if hz < 0 then
      begin
      logger.Error('[Y2.ParseIFResponse] non-numeric frequency: %s',
                   [Copy(msg, Y2_FREQ_POS, Y2_FREQ_LEN)]);
      Exit;
      end;
   Self.vfo[whichVFO].frequency := hz;
   Self.vfo[whichVFO].band := FreqToRadioBand(hz);
   Self.vfo[whichVFO].mode := Self.ModeCharToMode(msg[Y2_MODE_POS]);

   ritSign := IfThen(msg[Y2_CLAR_POS] = '-', -1, 1);
   ritHz := StrToIntDef(Copy(msg, Y2_CLAR_POS + 1, 4), 0) * ritSign;
   Self.SetRITOffset(ritHz);
   Self.SetXITOffset(ritHz);
   Self.SetRITOn(msg[Y2_RIT_POS] = '1');
   Self.SetXITOn(msg[Y2_XIT_POS] = '1');
end;

procedure TYaesuASCIILegacy.PollRadioState;
begin
   // No FT; and no TX; -- this generation answers neither.  Asking would add a
   // timeout to every cycle on a 4800 baud link.
   if FReadsActiveVFO then
      begin
      Self.SendToRadio('IF;OI;FR;');
      end
   else
      begin
      Self.SendToRadio('IF;OI;');
      end;
end;

procedure TYaesuASCIILegacy.ProcessMessage(sMessage: string);
begin
   if (Length(sMessage) >= 3) and SameText(AnsiLeftStr(sMessage, 2), 'FR') then
      begin
      // FR reports the RECEIVE VFO, NOT split -- FT is what indicates split.
      // Which replies mean "VFO B" is per-model; see FVFOBReceivingChars.
      UpdateLastValidResponse;
      if CharInSet(sMessage[3], FVFOBReceivingChars) then
         begin
         Self.SetActiveVFO(nrVFOB);
         end
      else
         begin
         Self.SetActiveVFO(nrVFOA);
         end;
      Exit;
      end;

   inherited ProcessMessage(sMessage);
end;

procedure TYaesuASCIILegacy.Split(splitOn: boolean);
begin
   // FR0; first (receive on VFO A), then the transmit VFO.  Both commands, in
   // this order -- LOGRADIO Issue #166.
   //
   // The transmit-VFO parameter is per-model: FT3;/FT2; are the ABSOLUTE forms
   // on radios that have them, but the FT-2000's FT accepts only 0 and 1.  See
   // FSplitAbsoluteTwoThree.
   if FSplitAbsoluteTwoThree then
      begin
      if splitOn then
         begin
         Self.SendToRadio('FR0;FT3;');
         end
      else
         begin
         Self.SendToRadio('FR0;FT2;');
         end;
      end
   else
      begin
      if splitOn then
         begin
         Self.SendToRadio('FR0;FT1;');
         end
      else
         begin
         Self.SendToRadio('FR0;FT0;');
         end;
      end;
end;

procedure TYaesuASCIILegacy.SetFrequency(freq: longint; vfo: TVFO; mode: TRadioMode);
var sCmd: string;
begin
   case vfo of
      nrVFOA: sCmd := 'FA';
      nrVFOB: sCmd := 'FB';
      else
         begin
         logger.error('[Y2.SetFrequency] Invalid VFO passed');
         Exit;
         end;
      end;
   // EIGHT digits on this generation (LOGRADIO Issue #218 draws the same line).
   Self.SendToRadio(Format('%s%.8d;', [sCmd, freq]));
   if mode <> rmNone then
      begin
      Self.SetMode(mode, vfo);
      end;
end;

end.

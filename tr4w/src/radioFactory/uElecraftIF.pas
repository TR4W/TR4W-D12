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
unit uElecraftIF;

{
  DECODING AN ELECRAFT "IF" (Transceiver Information) RESPONSE, ONCE.

  WHY THIS UNIT EXISTS.  The K3 (uRadioElecraftSerial) and the K4
  (uRadioElecraftK4) each carried their own copy of this parser, character for
  character, because the K3's was ported from the K4's.  Two copies of one wire
  format is a drift generator, and it drifted:

    * The SAME RIT/XIT bug had to be found and fixed TWICE -- both copies wrote
      only the legacy scalar and not the per-VFO offset the radio window reads,
      so the serial K3 and the serial K4 each showed a blank RIT/XIT indicator
      until someone noticed, separately, months apart.
    * The length guard was fixed in the K3 copy and left broken in the K4 copy
      (see IF_PARSED_LENGTH below).

  WHAT THIS UNIT IS.  A PURE function over a string.  It has no logger, touches
  no radio object, and performs no I/O, so it can be unit-tested against real
  captured responses with no transport and no globals -- see uTestElecraftIF.

  WHAT IT DELIBERATELY IS NOT.  It is not a shared base class.  The K3 and K4
  differ in what they DO with a decoded IF -- most notably the K4 uses the
  "swap" VFO model (A/B exchange contents, so A is always the operating VFO)
  and must NOT call SetActiveVFO, while the K3 selects between VFOs and must.
  Those are real per-model behaviours, not drift.  Decoding is shared; applying
  is not.

  THE WIRE FORMAT (identical on K2/K3/K4):

      IF[f]*****+yyyyrx*00tmvspbd1*;

      [f]   operating frequency, 11 digits, EXCLUDING any RIT/XIT offset
      *     a space (0x20)
      +     sign of the RIT/XIT offset, '+' or '-'
      yyyy  RIT/XIT offset in Hz (-9999..+9999 under computer control)
      r     1 = RIT on
      x     1 = XIT on
      t     1 = transmitting
      m     operating mode (see MD)
      v     receive-mode VFO: 0 = VFO A, 1 = VFO B
      s     1 = scan in progress            (read and discarded)
      p     1 = split
      b     band-change flag on K2 extended (read and discarded)
      d     DATA sub-mode: 0=DATA A, 1=AFSK A, 2=FSK D, 3=PSK D

  Note the trailing "1*" after d: a literal '1' and a space that carry no
  information here.  They matter only because they explain the old length
  guard -- see IF_PARSED_LENGTH.
}

interface

uses
   uFactoryRadioBase;   // TRadioMode only.  This unit is a leaf: nothing in
                        // the factory may ever use uElecraftIF in return.

const
   // What the parse actually CONSUMES, counted from the field list above:
   // 11 freq + 5 blanks + 1 sign + 4 offset + r + x + space + "00" + t + m + v
   // + s + p + b + d = 33.  NOT the length of the response.
   //
   // Both drivers hand us the response with the leading "IF" already stripped
   // by ProcessMessage, and a real K3/K4 payload is 35 -- the 33 above plus the
   // trailing '1' and space that nothing reads.  The old K3 guard tested for
   // 35 and so happened to work, but it was counting characters the parser
   // never looks at, and would have rejected a firmware that stopped sending
   // them.  Test what we consume.
   //
   // The K4 copy never had a working guard at all.  It read
   //     if not length(cmd) in [36,38] then
   // and Pascal binds `not` tighter than `in`, so that evaluated
   // (not Length(cmd)) in [36,38] -- a bitwise NOT, always negative, never in
   // the set.  The guard could not fire and its error message was unreachable.
   IF_PARSED_LENGTH = 33;

type
   // Why the decode failed.  Returned rather than logged so this stays pure --
   // each driver logs in its own voice and category.
   TElecraftIFError = (
      ifeNone,
      ifeTooShort,        // fewer than IF_PARSED_LENGTH characters to parse
      ifeBadFrequency,    // the 11-digit frequency field was not numeric
      ifeBadRITOffset     // the 4-digit RIT/XIT offset field was not numeric
   );

   // One decoded IF response.  Positional fields only: no interpretation beyond
   // applying the sign to the offset.
   TElecraftIF = record
      FrequencyHz:    integer;   // [f], excludes any RIT/XIT offset
      RITXITOffsetHz: integer;   // SIGNED.  One register serves both on Elecraft
      RITOn:          boolean;
      XITOn:          boolean;
      Transmitting:   boolean;
      SplitOn:        boolean;
      RXVFOIsB:       boolean;   // the 'v' field: False = VFO A, True = VFO B
      ModeChar:       string;    // 'm', one character -- see ElecraftModeToRadioMode
      DataModeChar:   string;    // 'd', one character
   end;

// Decode one IF response.  Accepts it with or without the leading "IF".
// Returns ifeNone and fills info on success; on failure returns the reason and
// info is undefined.
function ParseElecraftIF(const cmd: string; out info: TElecraftIF): TElecraftIFError;

// Human-readable reason, for the caller to log.  '' when err = ifeNone.
function ElecraftIFErrorText(err: TElecraftIFError; const cmd: string): string;

// Elecraft MD byte (plus the DT sub-mode byte) -> TRadioMode.  Shared for the
// same reason as the parser: both drivers had identical copies.
// problem is '' on success, otherwise a message for the caller to log; the
// result is then the same lenient fallback the drivers have always used
// (rmNone for a bad mode, rmData for a bad sub-mode).
function ElecraftModeToRadioMode(const modeChar, dataModeChar: string;
                                 out problem: string): TRadioMode;

implementation

uses
   SysUtils, StrUtils;

function ParseElecraftIF(const cmd: string; out info: TElecraftIF): TElecraftIFError;
var
   s: string;
   sign: integer;
   offset: integer;
begin
   Result := ifeNone;
   s := cmd;

   // Tolerated, though in practice both drivers strip it before calling: the
   // command letters may or may not still be on the front.
   if AnsiLeftStr(s, 2) = 'IF' then
      begin
      Delete(s, 1, 2);
      end;

   if Length(s) < IF_PARSED_LENGTH then
      begin
      Result := ifeTooShort;
      Exit;
      end;

   info.FrequencyHz := StrToIntDef(AnsiLeftStr(s, 11), -999);
   if info.FrequencyHz = -999 then
      begin
      Result := ifeBadFrequency;
      Exit;
      end;
   Delete(s, 1, 11);

   Delete(s, 1, 5);   // five blanks

   // Default '+' when the radio sends anything else, matching the drivers.
   if AnsiLeftStr(s, 1) = '-' then
      begin
      sign := -1;
      end
   else
      begin
      sign := 1;
      end;
   Delete(s, 1, 1);

   offset := StrToIntDef(AnsiLeftStr(s, 4), -999);
   if offset = -999 then
      begin
      Result := ifeBadRITOffset;
      Exit;
      end;
   info.RITXITOffsetHz := offset * sign;
   Delete(s, 1, 4);

   info.RITOn := AnsiLeftStr(s, 1) = '1';
   Delete(s, 1, 1);

   info.XITOn := AnsiLeftStr(s, 1) = '1';
   Delete(s, 1, 1);

   Delete(s, 1, 1);   // the space
   Delete(s, 1, 2);   // the fixed "00"

   info.Transmitting := AnsiLeftStr(s, 1) = '1';
   Delete(s, 1, 1);

   info.ModeChar := AnsiLeftStr(s, 1);
   Delete(s, 1, 1);

   info.RXVFOIsB := AnsiLeftStr(s, 1) <> '0';
   Delete(s, 1, 2);   // the VFO character AND the scan character

   info.SplitOn := AnsiLeftStr(s, 1) = '1';
   Delete(s, 1, 1);

   Delete(s, 1, 1);   // the band-change flag

   info.DataModeChar := AnsiLeftStr(s, 1);
end;

function ElecraftIFErrorText(err: TElecraftIFError; const cmd: string): string;
begin
   case err of
      ifeTooShort:
         Result := Format('IF response too short: %d chars, need at least %d after the command letters - %s',
                          [Length(cmd), IF_PARSED_LENGTH, cmd]);
      ifeBadFrequency:
         Result := Format('frequency returned in IF command was not a number - %s', [cmd]);
      ifeBadRITOffset:
         Result := Format('RIT offset returned in IF command was not a number - %s', [cmd]);
   else
      Result := '';
   end;
end;

function ElecraftModeToRadioMode(const modeChar, dataModeChar: string;
                                 out problem: string): TRadioMode;
var
   iMode: integer;
begin
   problem := '';
   iMode := StrToIntDef(modeChar, -999);
   case iMode of
      0: Result := rmNone;
      1: Result := rmLSB;
      2: Result := rmUSB;
      3: Result := rmCW;
      4: Result := rmFM;
      5: Result := rmAM;
      6: begin
         case StrToIntDef(dataModeChar, -9) of
            0: Result := rmData;
            1: Result := rmAFSK;
            2: Result := rmFSK;
            3: Result := rmPSK;
            -9: begin
               problem := Format('Non-numeric string passed for sDataMode (%s)', [dataModeChar]);
               Result := rmData;
               end;
         else
            begin
            problem := Format('Unexpected string passed for sDataMode (%s)', [dataModeChar]);
            Result := rmData;
            end;
         end;
         end;
      7: Result := rmCWRev;
      9: Result := rmDataRev;
      -999: begin
         problem := Format('Non-numeric string passed for sMode (%s)', [modeChar]);
         Result := rmNone;
         end;
   else
      begin
      problem := Format('Unexpected string passed for sMode (%s)', [modeChar]);
      Result := rmNone;
      end;
   end;
end;

end.

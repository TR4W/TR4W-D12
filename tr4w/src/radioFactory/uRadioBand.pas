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
unit uRadioBand;
{$I ..\tr4w.inc}

{
  Band/frequency pure utility functions.

  No dependencies on radio hardware, protocols, or UI — fully testable
  in isolation with the console test runner.

  TRadioBand is the canonical definition.  uFactoryRadioBase includes this unit
  in its interface uses clause so all existing consumers see TRadioBand
  unchanged — no other files need updating.

  D12 migration note:
    LongInt is 32-bit on both D7 and D12/32-bit.  Frequencies up to ~4.3 GHz
    fit safely.  If microwave bands above 2.1 GHz are ever added, switch to
    Int64 in Phase 3.
}

interface

uses
   VC;   // BandType, for GetRadioBandFromBandType below

// ---------------------------------------------------------------------------
// Band enum — canonical definition (moved from uFactoryRadioBase).
// Order matters: routines in this unit rely on the enum ordinal values only
// indirectly (via case statements), so the order is stable.
// ---------------------------------------------------------------------------

type TRadioBand = (rbNone,
                   rb160m, rb80m, rb60m, rb40m, rb30m,
                   rb20m,  rb17m, rb15m, rb12m, rb10m,
                   rb6m,   rb4m,  rb2m,  rb70cm);

// ---------------------------------------------------------------------------
// FreqToRadioBand — classify a frequency (Hz) into a ham band.
//
// Uses conventional band-edge frequencies.  Frequencies below 1.8 MHz
// (including 0) map to rb160m; frequencies at or above 500 MHz map to rbNone.
// Thread-safe: pure function, no side effects.
// ---------------------------------------------------------------------------

function FreqToRadioBand(freq: LongInt): TRadioBand;

// ---------------------------------------------------------------------------
// RadioBandToFreq — return the typical calling frequency for a band (Hz).
//
// Used when SetBand is called and no band-memory frequency is available.
// rbNone and unrecognised values default to 20m (14.100 MHz).
// ---------------------------------------------------------------------------

function RadioBandToFreq(band: TRadioBand): LongInt;

// ---------------------------------------------------------------------------
// GetRadioBandFromBandType — TRDOS BandType to the factory's TRadioBand.
//
// MOVED HERE FROM MainUnit (2026-08-07).  It is a pure enum mapping and had no
// business in the main window: its one caller is a radio driver, and reaching it
// meant a leaf driver pulled the whole main-window unit graph in -- which is
// what made dcc32 die with an internal error and stopped every cold build.
//
// BEHAVIOUR CHANGE, deliberate: an unmapped band now returns rbNone.  The
// original fell out of its case with Result NEVER ASSIGNED and returned whatever
// happened to be on the stack, which for a band the case does not cover (60m is
// commented out there) is an arbitrary band.  It logged the error and then
// returned rubbish.  Reporting is now the caller's job -- this unit is a pure
// mapping and has no logger.
// ---------------------------------------------------------------------------

function GetRadioBandFromBandType(band: BandType): TRadioBand;

implementation

function FreqToRadioBand(freq: LongInt): TRadioBand;
begin
   if      freq < 2000000   then
      begin
      Result := rb160m
      end
   else if freq < 4000000   then Result := rb80m
   else if freq < 6000000   then Result := rb60m
   else if freq < 7300000   then Result := rb40m
   else if freq < 11000000  then Result := rb30m
   else if freq < 15000000  then Result := rb20m
   else if freq < 19000000  then Result := rb17m
   else if freq < 22000000  then Result := rb15m
   else if freq < 25000000  then Result := rb12m
   else if freq < 30000000  then Result := rb10m
   else if freq < 54000000  then Result := rb6m
   else if freq < 80000000  then Result := rb4m
   else if freq < 170000000 then Result := rb2m
   else if freq < 500000000 then Result := rb70cm
   else
      begin
      Result := rbNone;
      end;
end;

function RadioBandToFreq(band: TRadioBand): LongInt;
begin
   case band of
      rb160m:  Result := 1900000;
      rb80m:   Result := 3600000;
      rb60m:   Result := 5357000;
      rb40m:   Result := 7100000;
      rb30m:   Result := 10125000;
      rb20m:   Result := 14100000;
      rb17m:   Result := 18100000;
      rb15m:   Result := 21100000;
      rb12m:   Result := 24920000;
      rb10m:   Result := 28400000;
      rb6m:    Result := 50100000;
      rb4m:    Result := 70100000;
      rb2m:    Result := 144100000;
      rb70cm:  Result := 432100000;
   else
      Result := 14100000;  // Default to 20m (covers rbNone)
   end;
end;

function GetRadioBandFromBandType(band: BandType): TRadioBand;
begin
   case band of
      NoBand:  Result := rbNone;
      Band160: Result := rb160m;
      Band80:  Result := rb80m;
      Band40:  Result := rb40m;
      Band30:  Result := rb30m;
      Band20:  Result := rb20m;
      Band17:  Result := rb17m;
      Band15:  Result := rb15m;
      Band12:  Result := rb12m;
      Band10:  Result := rb10m;
      Band6:   Result := rb6m;
      Band2:   Result := rb2m;
      Band432: Result := rb70cm;
   else
      // 60m reaches here: BandType has Band60 but the original mapping left it
      // commented out, and rb60m exists in TRadioBand.  Left as-is rather than
      // quietly adding a mapping nobody has tested on the air -- but it now
      // returns a DEFINED value instead of an unassigned Result.
      begin
      Result := rbNone;
      end;
   end;
end;

end.

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

  Frequency width:
    LongInt is 32-bit, so a SIGNED Hz value tops out at 2.147 GHz.  Every band
    TR4W's BandType names below that -- through 23 cm (1240..1300 MHz) -- is
    representable.  2304 MHz and above are NOT, and adding them means widening
    this unit and everything that hands it a frequency to Int64 first.
}

interface

uses
   VC;   // BandType, for GetRadioBandFromBandType below

// ---------------------------------------------------------------------------
// Band enum — canonical definition (moved from uFactoryRadioBase).
// Order matters: routines in this unit rely on the enum ordinal values only
// indirectly (via case statements), so the order is stable.
// ---------------------------------------------------------------------------

(*
   Ordered by ASCENDING frequency, and deliberately so: rb125cm (222 MHz) sits
   between rb2m and rb70cm rather than being appended, because reading the list
   is how anyone checks that a band is missing.  Nothing persists these
   ordinals -- the only enum-indexed use in the tree is TIcomRadio's band-memory
   array, which the compiler resizes -- so inserting is safe.

   rb125cm/rb33cm/rb23cm were ADDED 2026-09-24 after an IC-9700 on 1295.206 MHz
   left TR4W showing 432: the list stopped at rb70cm, so FreqToRadioBand
   returned rbNone for every frequency at or above 500 MHz, that became NoBand,
   and uRadioPolling's NoBand guard (correctly) refused to propagate a sentinel
   -- so the band never followed the dial.  222 MHz was wrong in a quieter way:
   it fell in the 170..500 MHz window and reported 70 cm.
*)
type TRadioBand = (rbNone,
                   rb160m,  rb80m,  rb60m,  rb40m, rb30m,
                   rb20m,   rb17m,  rb15m,  rb12m, rb10m,
                   rb6m,    rb4m,   rb2m,
                   rb125cm, rb70cm, rb33cm, rb23cm);

// ---------------------------------------------------------------------------
// FreqToRadioBand — classify a frequency (Hz) into a ham band.
//
// DELIBERATELY PERMISSIVE, and that is the difference from
// uBandLookup.CalculateBandMode.  This routine asks "which band is the dial
// nearest", so it classifies a frequency that is out of band (a repeater
// splinter, a listening frequency, 0 Hz at startup) rather than answering
// "unknown" -- the band on the screen has to follow the VFO.  CalculateBandMode
// asks the stricter question "which band SEGMENT is this exactly in" and is
// entitled to say NoBand.
//
// The two must never DISAGREE where both have an answer; uTestRadioBand walks
// every FreqModeArray entry and fails if they do.  That check is the guard
// against the drift that produced this comment.
//
// Frequencies below 1.8 MHz (including 0) map to rb160m; frequencies above
// 1.5 GHz map to rbNone -- TR4W's BandType names 2304 MHz and up, but a signed
// 32-bit Hz value cannot reach them (see the header note).
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

// ---------------------------------------------------------------------------
// GetBandTypeFromRadioBand - the factory's TRadioBand back to TRDOS BandType.
//
// MOVED HERE FROM MainUnit (2026-09-24), where it was GetTR4WBandFromNetworkBand
// -- a hand-maintained INVERSE of the mapping directly above it, in a unit no
// test can link.  Two halves of one mapping, free to disagree, and they had:
// both were missing 222 MHz, 902 MHz and 1296 MHz.
//
// Total: a band this program cannot name (rb4m, rb60m) returns NoBand.  The
// original fell out of its case with Result UNASSIGNED after logging an error.
// Reporting stays with the caller -- this unit is a pure mapping and has no
// logger.
// ---------------------------------------------------------------------------

function GetBandTypeFromRadioBand(band: TRadioBand): BandType;

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
   else if freq < 300000000 then Result := rb125cm
   else if freq < 500000000 then Result := rb70cm
   (* 1.000 GHz exactly belongs to 33 cm, not 23 cm: FreqModeArray's 902 entry
      runs 900..1000 MHz and its 1296 entry starts at 1000 MHz, and
      CalculateBandMode takes the FIRST hit.  <= keeps the two in step. *)
   else if freq <= 1000000000 then Result := rb33cm
   else if freq < 1500000000 then Result := rb23cm
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
      rb125cm: Result := 222100000;
      rb70cm:  Result := 432100000;
      rb33cm:  Result := 903100000;
      rb23cm:  Result := 1296100000;
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
      Band2:    Result := rb2m;
      Band222:  Result := rb125cm;
      Band432:  Result := rb70cm;
      Band902:  Result := rb33cm;
      Band1296: Result := rb23cm;
   else
      // 60m reaches here: BandType has Band60 but the original mapping left it
      // commented out, and rb60m exists in TRadioBand.  Left as-is rather than
      // quietly adding a mapping nobody has tested on the air -- but it now
      // returns a DEFINED value instead of an unassigned Result.
      //
      // So do Band2304 and above: a signed 32-bit Hz value cannot reach them,
      // so no radio driver in this tree can report one.
      begin
      Result := rbNone;
      end;
   end;
end;

function GetBandTypeFromRadioBand(band: TRadioBand): BandType;
begin
   case band of
      rb160m:  Result := Band160;
      rb80m:   Result := Band80;
      rb40m:   Result := Band40;
      rb30m:   Result := Band30;
      rb20m:   Result := Band20;
      rb17m:   Result := Band17;
      rb15m:   Result := Band15;
      rb12m:   Result := Band12;
      rb10m:   Result := Band10;
      rb6m:    Result := Band6;
      rb2m:    Result := Band2;
      rb125cm: Result := Band222;
      rb70cm:  Result := Band432;
      rb33cm:  Result := Band902;
      rb23cm:  Result := Band1296;
   else
      (* rbNone, and the two bands TR4W's BandType cannot name: rb60m (Band60
         is commented out of the enum) and rb4m (70 MHz, Region 1 only). *)
      begin
      Result := NoBand;
      end;
   end;
end;

end.

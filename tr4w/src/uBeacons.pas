{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uBeacons;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}

{
  THE BEACON SEAM, AND THE BEACON DATA.  The window itself is now an LCL form --
  src\ui\lcl\uBeaconsForm.pas -- and what is left here is the entry point plus
  the two tables that say what the NCDXF/IBP schedule IS.

  The split is deliberate. The names and the frequencies are domain data with a
  life of their own: a beacon goes off the air, a new one is licensed, and the
  table changes without anything about the window changing. The 18x5 grid of
  window handles that used to display them was presentation, and it is gone.

  DELETED here, not wrapped (Phase 4b): BeaconsMonitorDlgProc, its ninety
  tCreateStaticWindow calls and the BeaconsHandle array that held their handles,
  the ten tCreateButtonWindow calls, SetBeaconFreq and ShowBeaconsNames (both
  took an HWND neither of them used, and nothing outside this unit called
  either), the write-only `FC` global, one goto, and the commented-out
  BeaconsGrids locator table.

  KEPT: the IBP schedule at the foot of this unit. It is the reference that says
  what the program is modelling, and no code replaces it.
}

interface

const
  BEACONS                               = 18;

  // The eighteen NCDXF/IBP beacons, in transmission order.  The order is the
  // schedule: index 0 starts each three-minute cycle on the first frequency and
  // every other beacon follows it up the bands.  DO NOT SORT THIS.
  BeaconsNames                          : array[0..BEACONS - 1] of PAnsiChar = ('4U1UN', 'VE8AT', 'W6WX', 'KH6WO', 'ZL6B', 'VK6RBP', 'JA2IGY', 'RR9O', 'VR2B', '4S7B', 'ZS6DN', '5Z4B', '4X6TU', 'OH2B', 'CS3B', 'LU4AA', 'OA4B', 'YV5B');

  // Indexed by the original dialog's control ids, which the form's buttons
  // still carry as their Tag.  101..105 are the five IBP frequencies, in kHz,
  // and are the five columns of the display; 106..110 are time-standard
  // stations, offered as buttons only -- they have no beacon schedule.
  FreqArray                             : array[101..110] of Word = (14100, 18110, 21150, 24930, 28200, 10000, 9996, 5000, 4996, 10144);

// the Beacon Monitor window.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
//
// Phase 4b, 2026-08-19: that is exactly what happened, and no call site moved.
procedure ShowBeaconsMonitor;

implementation

uses
  uBeaconsForm;

procedure ShowBeaconsMonitor;
begin
   uBeaconsForm.ShowBeaconsMonitor;
end;

{
Schedule of IBP/NCDXF Beacon Transmissions

Frequency
Country            Call   14100 18110 21150 24930 28200

United Nations NY  4U1UN  00.00 00.10 00.20 00.30 00.40
Northern Canada    VE8AT  00.10 00.20 00.30 00.40 00.50
USA (CA)           W6WX   00:20 00.30 00:40 00.50 01:00
Hawaii             KH6WO  00.30 - 00.50 - 01.10
New Zealand        ZL6B   00.40 00.50 01.00 01.10 01.20
West Australia     VK6RBP 00.50 01.00 01.10 01.20 01.30

Japan              JA2IGY 01.00 01.10 01.20 01.30 01.40
Siberia            RR9O   01.10 01.20 01.30 01.40 01.50
China              VR2HK  01.20 01.30 01.40 01.50 02.00
Sri Lanka          4S7B   01.30 01.40 01.50 02.00 02.10
South Africa       ZS6DN  01:40 01.50 02:00 02:10 02:20
Kenya              5Z4B   01.50 02.00 02.10 02.20 02.30

Israel             4X6TU  02:00 02:10 02:20 02.30 02:40
Finland            OH2B   02:10 02:20 02:30 02:40 02:50
Madeira            CS3B   02.20 02.30 02.40 02.50 00.00
Argentina          LU4AA  02:30 02:40 02:50 00.00 00:10
Peru               OA4B   02.40 02.50 00.00 00.10 00.20
Venezuela          YV5B   02:50 00.00 00:10 00:20 00:30

KH6WO is not currently licensed for 18 or 24 MHz.

}

end.

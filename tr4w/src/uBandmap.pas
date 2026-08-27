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
unit uBandmap;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  uConfigValues,
  SysUtils,
  uMenu,
  uCommctrl,
  uCTYDAT,
  uSpots,
  TF,
  VC,
  uTelnet,
  uWinkey,
  Windows,
  LogCW,
  LogEdit,
  uGradient,
  uCallsigns,
  Messages,
  LogStuff,
  LogSubs2,
  LogK1EA,
  LogWind,
  LogRadio,
  LogDupe,
  LOGSUBS1,
  Tree
  ,
  uTR4WStrings;

{
const
  bm_hotkey_escape                      = 1;
  bm_hotkey_delete                      = 2;
  bm_hotkey_return                      = 3;
  bm_hotkey_pause                       = 4;
}

type
  TBandMapButtons = record
    Menu: HMENU;
    Text: PAnsiChar;
  end;
  {
  const
    BandMapButtonsCount                   = 6;
    BandMapButtonsArray                   : array[0..BandMapButtonsCount - 1] of TBandMapButtons =
      (
      (Menu: Ord(BAB); Text: 'All bands'),
      (Menu: Ord(BAM); Text: 'All modes'),
      (Menu: Ord(BCQ); Text: 'Display CQ'),
      (Menu: Ord(BDD); Text: 'Dupe display'),
      (Menu: Ord(VBE); Text: 'VHF band'),
      (Menu: Ord(WBE); Text: 'WARC band')
      );
  }
procedure TuneRadioToSpot(Spot: TSpotRecord; Radio: RadioType);

var
  // WHAT IS LEFT.  Everything else that stood here -- the list box and status bar
  // handles, the background brush, the DRAWITEMSTRUCT pointer, the measured
  // frequency width, the status-bar panel pixel table, the focus-freeze flags --
  // described a Win32 control.  The control is a TDrawGrid on uBandMapForm now,
  // and a form owns its own widgets.
  //
  // These three are OPERATOR SETTINGS (BANDMAP ITEM HEIGHT, BANDMAP ITEM WIDTH,
  // BAND MAP DISPLAY GHZ) and are read from the CFG table by address, so they
  // stay module-level rather than becoming form fields.
  BandMapItemHeight: integer = 14;
  BandMapItemWidth: integer = 135;
  BandMapDisplayGhz: boolean;
  PreviousDisplayedBandmapBand: BandType;

implementation
uses MainUnit, uDupesheet;

procedure TuneRadioToSpot(Spot: TSpotRecord; Radio: RadioType);
var
  EntryBand: BandType;
  EntryMode: ModeType;
  //  Index                                 : integer;
  QZBOffset: integer;
const
  MAX_QZB_OFFSET = 30;
begin
  QZBOffset := 0; // 4.92.4
  if (OpMode = SearchAndPounceOpMode) then
     begin
     LastSPFrequency := ActiveRadioPtr^.LastDisplayedFreq;
     LastSPMode := ActiveMode;
     end;

  //?
  EntryBand := NoBand;
  EntryMode := NoMode;
  logger.Trace('Entering TuneRadioToSpot %s - %d', [Spot.FCall,
    Spot.FFrequency]);
  GetBandMapBandModeFromFrequency(Spot.FFrequency, EntryBand, EntryMode);
  if (EntryBand = NoBand) then
     begin
     logger.trace('Exiting TuneRadioToSpot due to NoBand');
     exit;
     end;
  if ((radio1.filteredstatus.freq = 0) or (radio2.filteredstatus.freq = 0)) then
     begin
     BandMapSO2RDisplay := False;
     Config.QSYInactiveRadio := False;
     Config.InBandLock := False;
     end;
  if BandMapSO2RDisplay then
    // B1: was (not WKBusy).  This is the WIDEST of the B1 substitutions -- CPU,
    // CAT and YCCC keying now also block a same-band SO2R spot tune, where
    // before only the WinKeyer did.  4.105.15
    if (ActiveBand = Spot.FBand) and (not CWStillBeingSent) then
       begin
       Radio := ActiveRadio;
       Config.QSYInactiveRadio := False;
       end
    else
       begin
       Config.QSYInactiveRadio := True;
       Radio := InactiveRadio;
       end;
  if ((Config.InBandLock) and (Config.TwoRadioMode)) then
     begin
     if Config.QSYInactiveRadio then
       if ((InActiveRadioPtr.BandMemory <> EntryBand) and (EntryBand =
         ActiveRadioPtr.BandMemory)) then
          begin
          QuickDisplay(TC_2radio_warn);
          exit;
          end;
     if not Config.QSYInactiveRadio then
       if ((ActiveBand <> EntryBand) and (EntryBand =
         InActiveRadioPtr.BandMemory)) then // 4.92.1
          begin
          QuickDisplay(TC_2radio_warn);
          exit;
          end;
     end;

  // Sleep(100);  4.92.4
  logger.trace('[TuneRadioToSpot] Calling SetRadioFreq %d', [(Spot.FFrequency +
    QZBOffset)]);
  SetRadioFreq(Radio, Spot.FFrequency + QZBOffset, EntryMode, 'A');
  PutRadioOutOfSplit(Radio);
  if (QZBRandomOffsetEnable and (EntryMode = CW)) then
     begin
     QZBOffset := Windows.GetTickCount mod (MAX_QZB_OFFSET * 2);
     if QZBOffset > MAX_QZB_OFFSET then
        begin
        QZBOffset := QZBOffset - MAX_QZB_OFFSET * 2;
        end;
     end
  else
     begin
     QZBOffset := 0;
     end;

  if Spot.FQSXFrequency <> 0 then
     begin
     case BandMapSplitMode of
       ByCutoffFrequency:
         begin
           SetRadioFreq(Radio, Spot.FQSXFrequency + QZBOffset, EntryMode, 'B');
           SetRadioFreq(Radio, Spot.FFrequency, EntryMode, 'A');
         end;
       AlwaysPhone:
         begin
           SetRadioFreq(Radio, Spot.FQSXFrequency + QZBOffset, Phone, 'B');
           SetRadioFreq(Radio, Spot.FFrequency, Phone, 'A');
         end;
     end;
     PutRadioIntoSplit(Radio);
     end;

  if Radio = InactiveRadio then
     begin
     InActiveRadioPtr.BandMemory := Spot.FBand; //Gav 4.37
     InActiveRadioPtr.ModeMemory := Spot.FMode; //Gav 4.37
  //   Exit;  // .126.8
     end;
  tCleareExchangeWindow;
  tCallWindowSetFocus;
  CallAlreadySent := False;
  ExchangeHasBeenSent := False;
  SetOpMode(SearchAndPounceOpMode);

  if PInteger(@Spot.FCall[1])^ = tCQAsInteger then
     begin
     Exit;
     end;
  if PInteger(@Spot.FCall[1])^ = tNEWAsInteger then
     begin
     Exit;
     end;
    if not Config.QSYInactiveRadio then
   //  tSetExchWindInitExchangeEntry ; // 4.138.2
       begin
       PutCallToCallWindow(Spot.FCall);
       end;
  

  if not QSOByMode then
     begin
     EntryMode := Both;
     end;
  DispalayB4(integer(
    //  CallsignsList.CallsignIsDupe(CallWindowString, EntryBand, EntryMode, Index)
    VisibleLog.CallIsADupe(CallWindowString, EntryBand, EntryMode)
    ));

end;
end.


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
  uCTYDAT,
  uSpots,
  TF,
  VC,
  uTelnet,
  uWinKey,
(* Windows: named but used nowhere in this unit (2026-09-08). *)
  LogCW,
  LogEdit,
  uGradient,
  uCallsigns,
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

(* TBandMapButtons IS DELETED (2026-09-08). A record of HMENU and PAnsiChar,
  declared and referenced NOWHERE -- checked with the comment-blanking reader.
  It described the buttons of the Win32 band map, which is a designed LCL form
  (uBandMapForm) now, and it was the last thing in this unit that named a
  Windows type. *)
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
(* Tunes to the spot and, unless the spot is a CQ/NEW marker or goes to the
  inactive radio, puts its call in the call window. TRUE when it put the call
  there -- the one case BAND MAP CLICK GOES TO EXCHANGE acts on (issue 185).
  A caller that does not care ignores the result. *)
function TuneRadioToSpot(Spot: TSpotRecord; Radio: RadioType): boolean;

(* ISSUE 185, PURE: the cursor goes to the EXCHANGE window after a spot tune
  only when the operator turned BAND MAP CLICK GOES TO EXCHANGE on AND the
  tune put the spot's call in the call window. Otherwise it stays in the call
  window, which is D7's behaviour and the default. *)
function SpotTuneFocusesExchange(aOptionOn, aCallPlaced: boolean): boolean;

(* Puts the cursor where SpotTuneFocusesExchange says, for this setting:
  the exchange window, or the call window. aCallPlaced is TuneRadioToSpot's
  answer. *)
procedure FocusEntryAfterSpotTune(aCallPlaced: boolean);

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
  PreviousDisplayedBandmapBand: BandType;

implementation
uses
   MainUnit,
   uCrashLog,        // OnMainThread
   uDupesheet,
   uDXSpotParse,     // SpotCallIsCQMarker / SpotCallIsNewMarker, SpotCommentForDisplay
   uSettingsModel;   // Settings.BandMap -- the eight display filters

(* WHAT TYPING A CALL AND THEN PRESSING SPACE DOES, FOR A CALL A SPOT CLICK
  FILLED IN (issue 244), plus the spot's comment (issue 247).

  Typing runs only ShowPartialCallMults (from CallWindowChange); the full
  needs / mult / name / country pass is ShowStationInformation, which Space and
  Enter run. A spot click used to stop at the field write, so the needs strip
  and the "Mult needs for" header waited for a keystroke. This runs the SAME
  routine -- nothing is derived a second time -- and then the comment.

  It logs nothing and moves no focus (TuneRadioToSpot has already returned focus
  to the call field). A dupe still shows: DispalayB4 below and ShowInformation
  from CallWindowChange are untouched.

  StationInformationCall is a latch against repeats that only a logged QSO
  clears; a click is a deliberate new look, so it is cleared first. Nothing is
  done unless the field really holds the spot's call (the call is refused when
  it is our own) or off the main thread, where the panels must not be touched. *)
procedure ShowClickedSpotInformation(const Spot: TSpotRecord);
begin
  if not OnMainThread then
     begin
     Exit;
     end;
  if CallWindowString <> Spot.FCall then
     begin
     Exit;
     end;
  StationInformationCall := '';
  ShowStationInformation(CallWindowString);
  DisplaySpotComment(SpotCommentForDisplay(SpotNotesText(Spot)));
  (* AND THE LOOKUP SPACE WOULD BROADCAST (issue 49), so a listener such as
    DXView loads the clicked call as it does a typed one. *)
  BroadcastLookupForCall(CallWindowString);
end;

function SpotTuneFocusesExchange(aOptionOn, aCallPlaced: boolean): boolean;
begin
   Result := aOptionOn and aCallPlaced;
end;

procedure FocusEntryAfterSpotTune(aCallPlaced: boolean);
begin
   if SpotTuneFocusesExchange(Settings.BandMap.ClickGoesToExchange, aCallPlaced) then
      begin
      tExchangeWindowSetFocus;
      end
   else
      begin
      tCallWindowSetFocus;
      end;
end;

function TuneRadioToSpot(Spot: TSpotRecord; Radio: RadioType): boolean;
var
  EntryBand: BandType;
  EntryMode: ModeType;
  //  Index                                 : integer;
  QZBOffset: integer;
const
  MAX_QZB_OFFSET = 30;
begin
  Result := False;
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
  (* THESE THREE ARE RUN-TIME STATE WRITTEN INTO SETTINGS, so the operator's
    configured values are kept first, as forced (NY4I, 2026-11-15): the file
    keeps what the operator chose, not "off because radio 2 was switched off"
    or the last spot's radio. Once per property; cheap after the first. *)
  Settings.KeepStationValue('QSY INACTIVE RADIO', True);
  if ((radio1.filteredstatus.freq = 0) or (radio2.filteredstatus.freq = 0)) then
     begin
     Settings.KeepStationValue('BAND MAP SO2R DISPLAY', True);
     Settings.KeepStationValue('IN BAND LOCKOUT', True);
     Settings.BandMap.So2rDisplay := False;
     Settings.So2r.QsyInactiveRadio := False;
     Settings.So2r.InBandLockout := False;
     end;
  if Settings.BandMap.So2rDisplay then
    // B1: was (not WKBusy).  This is the WIDEST of the B1 substitutions -- CPU,
    // CAT and YCCC keying now also block a same-band SO2R spot tune, where
    // before only the WinKeyer did.  4.105.15
    if (ActiveBand = Spot.FBand) and (not CWStillBeingSent) then
       begin
       Radio := ActiveRadio;
       Settings.So2r.QsyInactiveRadio := False;
       end
    else
       begin
       Settings.So2r.QsyInactiveRadio := True;
       Radio := InactiveRadio;
       end;
  if ((Settings.So2r.InBandLockout) and (Settings.So2r.TwoRadioMode)) then
     begin
     if Settings.So2r.QsyInactiveRadio then
       if ((InActiveRadioPtr.BandMemory <> EntryBand) and (EntryBand =
         ActiveRadioPtr.BandMemory)) then
          begin
          QuickDisplay(TC_2radio_warn);
          exit;
          end;
     if not Settings.So2r.QsyInactiveRadio then
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
  if (Settings.Qzb.RandomOffsetEnable and (EntryMode = CW)) then
     begin
     { GetTickCount64: this wants a varying number, so which 32 bits it
       lands on does not matter -- but the Windows call did. }
     QZBOffset := GetTickCount64 mod (MAX_QZB_OFFSET * 2);
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
     case Settings.BandMap.SplitMode of
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

  if SpotCallIsCQMarker(Spot.FCall) then
     begin
     Exit;
     end;
  if SpotCallIsNewMarker(Spot.FCall) then
     begin
     Exit;
     end;
    if not Settings.So2r.QsyInactiveRadio then
   //  tSetExchWindInitExchangeEntry ; // 4.138.2
       begin
       PutCallToCallWindow(Spot.FCall);
       ShowClickedSpotInformation(Spot);
       Result := True;
       end;


  if not Settings.Qso.ByMode then
     begin
     EntryMode := Both;
     end;
  DispalayB4(integer(
    //  CallsignsList.CallsignIsDupe(CallWindowString, EntryBand, EntryMode, Index)
    VisibleLog.CallIsADupe(CallWindowString, EntryBand, EntryMode)
    ));

  (* ISSUE 185: the call window was focused above, before the call went in;
    with BAND MAP CLICK GOES TO EXCHANGE on, the cursor moves on to the
    exchange window. Focus only -- the exchange is not filled (option A). *)
  if SpotTuneFocusesExchange(Settings.BandMap.ClickGoesToExchange, Result) then
     begin
     tExchangeWindowSetFocus;
     end;
end;
end.


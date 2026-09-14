(*
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
 *)
unit uSettingsEffects;
{$I tr4w.inc}

(*
  WHAT HAS TO HAPPEN ON SCREEN WHEN A SETTING CHANGES.

  ------------------------------------------------------------------------
  THIS UNIT IS THE REPLACEMENT FOR crP
  ------------------------------------------------------------------------

  Thirty CFGCA rows carry `crP`, an index into CommandsProcArray, and uCFG's
  own note is blunt about what it is for: the handler is "the ONLY thing that
  repaints for a changed setting".  Without it a setting takes effect at the
  next restart -- AUTO SEND CHARACTER COUNT is the worked example, where the
  arrow beside the call sign field appeared only after one (NY4I, 2026-08-21).

  NY4I, 2026-09-11: *"a property setter can do the side effect, which is better
  than a hook index."*  That is the design, and this unit is the other half of
  it: TSettingsGroup's setters RAISE the change, and this subscribes.

  ------------------------------------------------------------------------
  WHY THIS IS NOT JUST CommandsProcArray WEARING A HAT
  ------------------------------------------------------------------------

  The objection is fair on its face -- a table of settings to side effects has
  been replaced by a routine that branches on settings and does side effects.
  Three things are genuinely different, and each was a real defect class:

  1. IT CANNOT POINT AT THE WRONG HANDLER.  `crP: 1` and `crA: 23` are integers
     typed by hand into a 508-row table, and a wrong one compiles.  That has
     happened: EXTERNAL LOGGER ENABLED carried crA: 23, the WSJT-X
     colorization hook.  A path is a string derived from the property itself.

  2. IT FIRES HOWEVER THE VALUE WAS SET.  The crP handler ran only when
     CheckCommand applied the row, so a config file repainted and a menu
     toggle did not -- which is exactly why the band map form grew its own
     ToggleAndRepaint helper, hand-writing the repaint the table would have
     done.  Two spellings of one rule, and they can disagree.  A setter has
     one.

  3. IT IS ONE PLACE, AND IT NAMES WHAT IT DOES.  `crP: 1` is a number whose
     meaning is in another file.

  ------------------------------------------------------------------------
  THE RULE FOR ADDING TO IT
  ------------------------------------------------------------------------

  MATCH A GROUP, NOT A SETTING, wherever the whole group shares one effect.
  All eight band map filters redraw the band map, so the arm below tests the
  prefix and there are no eight cases to keep in step with eight properties.
  Reach for an exact path only where one setting in a group genuinely differs.

  AND NOTHING HERE MAY ASSUME ITS WINDOW EXISTS.  Every seam this unit calls is
  a procedure variable that is nil until the form opens, so a setting changed
  with the band map closed is a no-op rather than a fault.  That is not
  defensive coding: config load happens before any window is created.
*)

interface

(* Subscribe to the settings model.  Called once, from the startup sequence in
  uProgramMain, AFTER the settings are loaded -- assigning it earlier would
  repaint for every value the load assigns, against windows that do not exist
  yet. *)
procedure InstallSettingsEffects;

implementation

uses
   SysUtils,
   uSettingsModel,
   FContest,       // RecalculateMyCountryContinentAndZoneNew
   VC,             (* the multiplier spelling tables and ActiveDXMult --
                     the contest engine owns these, the settings hold the
                     token, and this is where one becomes the other *)
   LogDupe,        // DXMultTypenameArray, ActivePrefixMult
   LogDom,         // DomesticMultStringArray, ActiveDomesticMult
   uCTYDAT,        (* CTY.ctyCountryMode / ctyZoneMode -- which lists CTY.DAT
                     resolves against, set by the two multiplier hooks *)
   LogWind,        (* Settings.My.Call -- the callsign the derivation starts
                     from; DispalayLogGridLines; DisplayInsertMode *)
                   // DisplayInsertMode, the INS/OVR panel;
                   // DisplayCodeSpeed, which is also the DVK's state panel;
                   // and UpadateAutoSend
   LogEdit,        (* VisibleLog.ShowRemainingMultipliers -- was
                     CommandsProcArray[2] *)
   LogStuff,       // AutoQSLCount -- the countdown this interval re-seeds
   uStations,      // SetStationsCallsignMask -- was CommandsProcArray[12]
   uRemMults,      // UpdateRemainingMultsWindows -- was CommandsProcArray[9]
   uNet,           // SetComputerName -- announce the name to the other position
   uBandMapView,   // BandMapRefresh -- the band map's own view seam
   MainUnit,       // wsjtx -- the server object these three act on
   uStateBridge;   // RefreshWSJTXIndicator -- the main window's box

const
   (* The property path prefix that names a group.  Spelled once, here, and
     compared with the dot attached so a future group called 'BandMapExtra'
     cannot match it by accident. *)
   BAND_MAP = 'BandMap.';

   (* HF / VHF / WARC.  These reach the band map too -- two of the three
     carried the same crP: 1 -- but they are not display filters, so they are
     their own group and get their own arm rather than being folded in. *)
   BANDS = 'Bands.';

   (* AN EXACT PATH, NOT A GROUP, and the header above says when to reach
     for one: where a single setting in a group genuinely differs. QSY
     INACTIVE RADIO carried crP:1, the band map redraw; the other six SO2R
     settings repaint nothing, so matching the group would repaint for all
     of them. *)
   QSY_INACTIVE_RADIO = 'So2r.QsyInactiveRadio';

   (* THE DERIVED STATION FACTS. Country, continent and zone are computed
     from the callsign unless the operator has stated one, and changing any
     of them has to re-run that -- which is what AdditionalProcsArray slots 8
     (MY COUNTRY) and 21 (MY ZONE) did.

     STARTUP DOES NOT NEED THIS and deliberately does not get it: this unit
     is installed after every config file is read, and FCONTEST's own
     SetUpContest calls the same routine once the contest is known. What is
     left for here is the case the hook index could never cover properly --
     a value changed from Preferences, mid-session. *)
   MY_COUNTRY = 'My.Country';
   MY_ZONE    = 'My.Zone';

   (* THE CALLSIGN IS WHAT THE OTHER THREE ARE DERIVED FROM, so changing it
     re-runs the same derivation. That was AdditionalProcsArray slot 14. *)
   MY_CALL    = 'My.Call';

   (* THE TWO crP REDRAWS THAT CAME WITH THE VC.pas SETTINGS.

     Both are exact paths and both are single settings in their group, so
     there is nothing to match a prefix against: their groups hold one
     property each.

     NEITHER ASSUMES ITS WINDOW EXISTS. SetStationsCallsignMask returns
     immediately when the Stations form is nil, and SetRemMultsColumnWidth
     -- which UpdateRemainingMultsWindows calls -- asks RemMultsForm for the
     form and does nothing when it gets nil. *)
   STATIONS_CALLSIGNS_MASK = 'Stations.CallsignsMask';
   CONTEST_NAME            = 'Contest.Name';
   DOMESTIC_MULTIPLIER     = 'Contest.DomesticMultiplier';
   DX_MULTIPLIER           = 'Contest.DxMultiplier';
   PREFIX_MULTIPLIER       = 'Contest.PrefixMultiplier';
   ZONE_MULTIPLIER         = 'Contest.ZoneMultiplier';
   SHOW_DOMESTIC_NAME      = 'RemainingMults.ShowDomesticName';
   REMAINING_MULT_DISPLAY  = 'RemainingMults.DisplayMode';
   (* INSERT OR OVERWRITE, shown on a panel of the main window. crP: 8,
     DisplayInsertMode.

     THIS ARM IS WHY THE Alt-MENU TOGGLE USED TO GO THE LONG WAY ROUND. The
     hook ran only when CheckCommand applied the row, so MainUnit's menu item
     called InvertBooleanCommand -- a scan of CFGCA for the row whose address
     matched the global -- purely to get the panel repainted. The setter
     raises the change however the value arrives, so that routine is gone. *)
   INSERT_MODE = 'CallWindow.InsertMode';

   (* THIS POSITION'S NAME, which the other positions display. crP: 6,
     SetComputerName, which sends a station-status packet. It is a no-op on a
     station with no network link, which is every single-operator one. *)
   COMPUTER_NAME = 'Computer.Name';

   (* THE THREE WSJT-X HOOKS, AdditionalProcsArray slots 23, 24 and 25.

     EXACT PATHS AND NOT THE GROUP, because the group's five settings do
     three different things and two of them do nothing at all: the
     broadcast port is read when the server starts, and matching the
     prefix would restart the listener every time one was assigned --
     which a settings LOAD does, five times in a row.

     SLOT 23 IS THE WORKED EXAMPLE OF WHY THESE ARE SETTERS NOW. EXTERNAL
     LOGGER ENABLED carried crA: 23 for a period, so enabling the external
     logger started the WSJT-X server. A hook index is an integer typed by
     hand into a table and a wrong one compiles; a path is derived from
     the property itself. *)
   WSJTX_ENABLED         = 'Wsjtx.Enabled';
   WSJTX_SEND_HIGHLIGHTS = 'Wsjtx.SendHighlights';
   WSJTX_MULTICAST_GROUP = 'Wsjtx.MulticastGroup';

   (* THE LOG GRID'S LINES, crP: 3. An exact path: the other three
     main-window appearance flags are read when a window is BUILT, so
     matching the group would call a redraw for three settings that have
     no run-time effect at all. *)
   SHOW_GRIDLINES = 'MainWindow.ShowGridlines';

   (* THE NEXT SERIAL NUMBER ON SCREEN, crP: 5. The panel shows what will
     be sent, and whether an abandoned QSO gives its number back changes
     that -- so the display has to follow the setting rather than wait
     for the next QSO. *)
   AUTO_QSO_NUMBER_DECREMENT = 'Operating.AutoQsoNumberDecrement';

   (* The code-speed panel doubles as the DVK's state in phone mode --
     'DVK ON', 'DVK OFF', or 'DVK Dis.' when the keyer is switched off. *)
   DVK_ENABLE = 'Dvk.Enable';

   (* AutoSendEnable is DERIVED from the count and is also toggled from the
     keyboard, so the derivation has to run whenever the count changes. *)
   AUTO_SEND_CHARACTER_COUNT = 'Cw.AutoSendCharacterCount';

   (* AutoQSLCount is the live countdown; this is what it reloads from, so
     changing it re-seeds the counter. *)
   AUTO_QSL_INTERVAL = 'Message.AutoQslInterval';


function InGroup(const aPath, aPrefix: string): boolean;
begin
   (* Case-insensitive: a path is built from Pascal identifiers, and Pascal
     does not distinguish their case.

     UnicodeSameText, NOT SameText.  This unit compiles with String =
     UnicodeString and SysUtils.SameText takes AnsiString, so the plain name
     narrows BOTH arguments at the call -- two of the conversions the build
     counts, for a comparison of two ASCII identifiers that can never lose a
     character.  Harmless here and still worth spelling correctly: the ceiling
     is a ratchet, and a conversion admitted because "this one is fine" is how
     it stops meaning anything. *)
   Result := UnicodeSameText(Copy(aPath, 1, Length(aPrefix)), aPrefix);
end;


(* ONE TOKEN, ONE TABLE, ONE INDEX -- the ckList arm of CheckCommand, lifted.

  The four multiplier modes are separate enums with separate spelling tables,
  so the only thing they share is the RULE: find the token in the table and
  assign its index. Writing it four times would be four chances to differ.

  STRINGS THROUGHOUT, NOT A Pointer AND A LENGTH. The first version of this
  took `aTable: Pointer` and called TF.GetValueFromArray, because the tables
  were still PAnsiChar -- NY4I asked why, and the answer was that I had
  bridged instead of converting. The tables are string arrays now: an open
  array carries its own bounds, so the aHigh parameter is gone too, and a
  wrong length can no longer walk off the end.

  THE TARGET IS STILL A Byte POINTER, and that one is real: the four globals
  are four DIFFERENT enum types, so there is no single typed reference that
  can name them all. It is the ordinal that is assigned, exactly as
  ListParamArray's lpVar did. *)
procedure ApplyMultiplierToken(const aToken: string;
                               const aTable: array of string;
                               const aTarget: PByte);
var
   i: integer;
   token: string;
begin
   token := Trim(aToken);
   if token = '' then
      begin
      Exit;
      end;

   for i := 0 to High(aTable) do
      begin
      if UnicodeSameText(aTable[i], token) then
         begin
         (* UNKNOWN LEAVES THE VALUE ALONE, which is why this assigns inside
           the match rather than after the loop: a token the table does not
           have must not become some other multiplier mode and silently
           rescore the contest. *)
         aTarget^ := Byte(i);
         Exit;
         end;
      end;
end;

procedure SettingChanged(const aPath: string);
begin
   if UnicodeSameText(aPath, MY_COUNTRY) or UnicodeSameText(aPath, MY_ZONE)
      or UnicodeSameText(aPath, MY_CALL) then
      begin
      (* The routine reads the WasSet flags itself, so a stated value is
        looked up and an unstated one is derived. Passing the callsign is
        what it needs to derive FROM. *)
      RecalculateMyCountryContinentAndZoneNew(UTF8Encode(Settings.My.Call));
      end;

   (* A MULTIPLIER TOKEN BECOMES THE LIVE MODE.

     The setting is a string -- the spelling an operator's config file has
     always used -- and the contest engine reads an enum. This is the whole of
     what the four ckList rows did: match the token against the subsystem's
     own table and assign the ordinal.

     UNKNOWN LEAVES THE VALUE ALONE. GetValueFromArray answers UNKNOWNTYPE for
     a spelling it does not have, and a refusal that corrected the mode to
     something else would silently rescore the contest. The registered
     vocabulary means CheckCommand refuses such a value before it ever gets
     here; this is the second guard, not the first. *)
   if UnicodeSameText(aPath, DOMESTIC_MULTIPLIER) then
      begin
      ApplyMultiplierToken(Settings.Contest.DomesticMultiplier, DomesticMultStringArray,
                           @ActiveDomesticMult);
      end;

   if UnicodeSameText(aPath, DX_MULTIPLIER) then
      begin
      ApplyMultiplierToken(Settings.Contest.DxMultiplier, DXMultTypenameArray,
                           @ActiveDXMult);
      (* WHICH COUNTRY LIST CTY.DAT RESOLVES AGAINST. This was the row's
        crA: 20 hook, F_DX_MULTIPLIER, and it was dropped with the row --
        restored here. The ARRL DXCC family means ARRL country mode; anything
        else means CQ. *)
      if ActiveDXMult in [ARRLDXCCWithNoUSAOrCanada,
                          ARRLDXCCWithNoARRLSections,
                          ARRLDXCCWithNoUSACanadaKH6OrKL7,
                          ARRLDXCCWithNoIOrIS0,
                          ARRLDXCCWithNoJT,
                          ARRLDXCC] then
         begin
         CTY.ctyCountryMode := ARRLCountryMode;
         end
      else
         begin
         CTY.ctyCountryMode := CQCountryMode;
         end;
      end;

   if UnicodeSameText(aPath, PREFIX_MULTIPLIER) then
      begin
      ApplyMultiplierToken(Settings.Contest.PrefixMultiplier, PrefixMultStringArray,
                           @ActivePrefixMult);
      end;

   if UnicodeSameText(aPath, ZONE_MULTIPLIER) then
      begin
      ApplyMultiplierToken(Settings.Contest.ZoneMultiplier, ZoneMultTypeSA,
                           @ActiveZoneMult);
      (* THE ZONE MODE AND THE ZONE INITIAL EXCHANGE. This was the row's
        crA: 2 hook, F_ZONE_MULTIPLIER, dropped with the row and restored
        here. Neither corpus set exercises it, which is why a green run did
        not notice. *)
      if ActiveZoneMult = CQZones then
         begin
         ActiveInitialExchange := ZoneInitialExchange;
         CTY.ctyZoneMode := CQZoneMode;
         end;
      if ActiveZoneMult = ITUZones then
         begin
         ActiveInitialExchange := ZoneInitialExchange;
         CTY.ctyZoneMode := ITUZoneMode;
         end;
      end;

   if UnicodeSameText(aPath, CONTEST_NAME) then
      begin
      (* THE TITLE IS BUILT FROM THE NAME, so a changed name leaves a stale
        title.  This was CFGCA's crA hook F_CONTEST_NAME, which fired only
        when a CONFIG LINE set the name -- so a contest loaded any other way
        kept whatever title was there.  A setter runs however it was set. *)
      SetContestTitle;
      end;

   if UnicodeSameText(aPath, STATIONS_CALLSIGNS_MASK) then
      begin
      (* THE FILTER CHANGED, so the list on screen no longer matches it.
        This was CommandsProcArray[12], and it rebuilds the column from the
        callsigns the program holds rather than re-reading anything. *)
      SetStationsCallsignMask;
      end;

   if UnicodeSameText(aPath, REMAINING_MULT_DISPLAY) then
      begin
      (* WHETHER A WORKED MULTIPLIER IS ERASED OR HIGHLIGHTED changes what
        those windows hold, not just how wide they are. This was
        CommandsProcArray[2].

        THROUGH THE INSTANCE. That table holds
        `@EditableLog.ShowRemainingMultipliers` -- the address of a method on
        an old-style object TYPE, with no instance -- and every other caller
        in the tree says VisibleLog, which is the one instance there is. *)
      VisibleLog.ShowRemainingMultipliers;
      end;

   if UnicodeSameText(aPath, SHOW_DOMESTIC_NAME) then
      begin
      (* A COLUMN WIDTH, not a caption: showing the domestic multiplier's
        name needs the wider prefix column. This was CommandsProcArray[9]. *)
      UpdateRemainingMultsWindows;
      end;

   if UnicodeSameText(aPath, INSERT_MODE) then
      begin
      DisplayInsertMode;
      end;

   if UnicodeSameText(aPath, AUTO_QSL_INTERVAL) then
      begin
      (* This was F_AUTO_QSL_INTERVAL, crA: 6. *)
      AutoQSLCount := Settings.Message.AutoQslInterval;
      end;

   if UnicodeSameText(aPath, AUTO_SEND_CHARACTER_COUNT) then
      begin
      (* This was CommandsProcArray[4]. *)
      UpadateAutoSend;
      end;

   if UnicodeSameText(aPath, DVK_ENABLE) then
      begin
      (* This was CommandsProcArray[7], and the panel it repaints is the one
        that shows the code speed on CW and the DVK's state on phone. The
        routine guards on the main window itself, the way DisplayInsertMode
        does -- a setting can be applied before any window exists. *)
      DisplayCodeSpeed;
      end;

   if UnicodeSameText(aPath, COMPUTER_NAME) then
      begin
      SetComputerName;
      end;

   if UnicodeSameText(aPath, WSJTX_ENABLED) then
      begin
      (* NOT AN ERROR WHEN THE SERVER IS NOT THERE. uProgramMain creates
        wsjtx only when this setting is already on, so at startup the
        object genuinely does not exist yet and the old hook logged an
        error every time -- a message that fires during correct operation
        is one people learn to ignore. *)
      if Assigned(wsjtx) then
         begin
         if Settings.Wsjtx.Enabled then
            begin
            wsjtx.Start;
            end
         else
            begin
            wsjtx.Stop;
            end;
         end;

      (* The main window's box tracks the SETTING, not just the link --
        enabled shows it, red until a heartbeat arrives; disabled hides
        it. Repaint here so it answers immediately, because for a setting
        just turned OFF the next state change never comes. *)
      RefreshWSJTXIndicator;
      end;

   if UnicodeSameText(aPath, WSJTX_SEND_HIGHLIGHTS) and Assigned(wsjtx) then
      begin
      wsjtx.SendColorization := Settings.Wsjtx.SendHighlights;
      end;

   if UnicodeSameText(aPath, WSJTX_MULTICAST_GROUP) and Assigned(wsjtx) then
      begin
      (* ONLY WHEN THERE IS A SOCKET TO JOIN WITH. Every Preferences save
        re-applies every setting, so with WSJT-X disabled this warned
        'UDP server not active' on each Save -- twice in one bench session.
        Nothing is lost by skipping: Start joins the group itself. *)
      if wsjtx.Running and (Settings.Wsjtx.MulticastGroup <> '') then
         begin
         wsjtx.JoinMulticastGroup(Settings.Wsjtx.MulticastGroup);
         end;
      end;

   if UnicodeSameText(aPath, AUTO_QSO_NUMBER_DECREMENT) then
      begin
      DisplayNextQSONumber;
      end;

   if UnicodeSameText(aPath, SHOW_GRIDLINES) then
      begin
      (* DispalayLogGridLines reads the property itself and then checks
        the window height, which is why the call takes no argument. It is
        safe before any window exists: the grid accessor it reaches is a
        no-op while the form is nil. *)
      DispalayLogGridLines;
      end;

   if InGroup(aPath, BAND_MAP) or InGroup(aPath, BANDS)
      or UnicodeSameText(aPath, QSY_INACTIVE_RADIO) then
      begin
      (* A VIEW change: the filter moved, the list of spots did not.  The form
        coalesces these, so calling it per property is not per-frame work even
        when a whole group is assigned at once. *)
      if Assigned(BandMapRefresh) then
         begin
         BandMapRefresh;
         end;
      end;
end;


procedure InstallSettingsEffects;
begin
   Settings.OnChanged := @SettingChanged;
end;

end.

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
unit uSpots;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}

interface

uses
  uConfigValues,
  VC,
  TF,
  uDupesheet,
  LogStuff,
  LogDupe,
  LogEdit,
  LogPack,
  LogRadio,
  LogSCP,
  Tree,
  SyncObjs,
  Generics.Collections;

type

  (* THE SPOT STORE'S CONTAINER (2026-10-17).

    History, because each step removed a hand-managed thing:

        PSpotsList = ^TSpotsList;
        TSpotsList = array[0..1000] of TSpotRecord;     (a pointer to a block)

    became `array of TSpotRecord` on 2026-09-14 (NY4I: "the band map which uses
    an array for an unknown reason FList[i] in bandmap code. All that has to go
    away."), and that is now a generic list. The list owns the count, the
    capacity and the shifting of records on insert and delete, so this unit no
    longer carries Grow / SetCapacity / an indexed-copy loop of its own, and an
    index outside the list RAISES instead of reading whatever was there.

    A list of RECORDS returns a copy from Items[], so a field cannot be assigned
    through it: every in-place edit below reads the record, changes the copy and
    writes it back. TSpotRecord holds only ShortStrings, AnsiChar arrays and
    ordinals, so the copy is a plain byte copy and nothing managed is involved. *)
  TSpotsList = TList<TSpotRecord>;

  (* WHICH THREAD TOUCHES THE STORE -- the invariant this class keeps.

    The MAIN thread is the only one that CHANGES the list: the cluster's reader
    thread never touches it (it queues events; TClusterEvents.Drain runs
    ProcessDX, and so AddSpot, on the main thread via QueueAsyncCall), uNet's
    DX-spot arm and LoadBandMap run on the main thread, and the ageing tick, the
    band map form's Delete / Clear and the dupe / multiplier refreshes are all
    main-thread work.

    The RADIO POLLING thread READS it: uRadioPolling calls
    DisplayCallsignOnThisFreq and TuneDupeCheck, and RequestRepaint. Those two
    scans therefore take FCriticalSection -- a list that shrinks under an unlocked
    reader would otherwise raise out of the poller -- and every mutator takes it
    for the part that changes the list. The main thread's own reads (Get,
    BuildVisibleSpots, IndexOfSpot) are unlocked, which is safe exactly because
    only the main thread writes.

    The token is bumped from either thread with a plain Inc. A lost increment
    needs two bumps to collide and still leaves the token different from the
    painted one, so the only cost would be one coalesced repaint. *)
  TDXSpotsList = class

  private
    FList: TSpotsList;
    FCurrentCursorFreq: integer;
    FCriticalSection: TCriticalSection;
    // THE REPAINT TOKEN.  Bumped by every mutator and by RequestRepaint; the
    // band map compares it against what it last painted.  It replaces the
    // global boolean BandMapNeedsRefresh, which three units raised and a fourth
    // cleared -- a mutator that forgot to raise it simply did not appear until
    // something unrelated repainted, and there was no way to tell that from a
    // spot that had not arrived.  A counter cannot be missed or double-cleared.
    FRepaintToken: cardinal;
    FPaintedToken: cardinal;
    function GetCount: integer;

  protected
    function CompareStrings(const s1, s2: CallString): integer;

  public
    constructor Create;
    destructor Destroy; override;
    function Get(Index: integer): TSpotRecord;
    function AddSpot(var Spot: TSpotRecord; SendToNetwork: boolean): integer;
    procedure Clear;
    procedure SetCursor;
    procedure DecrementSpotsTimes;
    procedure UpdateSpotsMultiplierStatus;
    procedure UpdateSpotsDupeStatus(const RXCall: string; RXBand: BandType;
      RXMode: ModeType);
    // WHICH spots to show, in display order -- the filter pass and the centring
    // window, with no control anywhere in it.  Returns the count; aIndex[0..n-1]
    // are indexes into FList and aCursorRow is the row carrying the cursor
    // frequency, or whatever the caller passed in when no row does.
    //
    // FList INDEXES, NOT COPIES, because the Win32 list box stores them as item
    // data and reads them back through Get().  A caller that keeps them past
    // the call must copy: an insert shifts the list, so it renumbers every
    // index above it.  The LCL form takes copies immediately.
    function BuildVisibleSpots(var aIndex: array of integer;
                               var aCursorRow: integer): integer;
    procedure Delete(Index: integer);
    //    procedure ClearDupes;
    procedure ResetSpotsTimes;
    procedure ResetSpotsDupes;

    procedure DisplayCallsignOnThisFreq(Freq: integer);
    procedure TuneDupeCheck(Freq: integer);
    function FindSpot(const Spot: TSpotRecord; var Index: integer): boolean;
    property Count: integer read GetCount;

    // Ask for a repaint WITHOUT changing the list -- the VFO moved, or a filter
    // was toggled.  Mutators do this for themselves; this is for the callers
    // whose change is to the VIEW.
    procedure RequestRepaint;
    function NeedsRepaint: boolean;

    // "I have drawn everything up to here."  Display does this for itself at
    // the end of its own successful path; the LCL form has to say so explicitly
    // because it paints from a snapshot rather than inside this object.
    procedure MarkPainted;

    // WHERE A SPOT IS NOW, found by identity rather than trusted from an index
    // the caller kept.  An insert shifts the list, so an index taken a quarter
    // second ago may name a different spot -- which is exactly how the old band
    // map could paint, and delete, the wrong row.  Frequency AND callsign,
    // because the list may legitimately hold the same call twice on different
    // frequencies.  Linear over at most a thousand entries and only ever called
    // from an operator action.
    function IndexOfSpot(const aSpot: TSpotRecord): integer;
    property RepaintToken: cardinal read FRepaintToken;
  end;

{ HOW OLD A SPOT IS, IN WHOLE SECONDS.  The arithmetic is uSpotAge, which is a
  leaf and therefore unit-tested; this is only the spot-shaped wrapper. }
function SpotAgeSeconds(const aSpot: TSpotRecord): integer;

var
  SpotsList: TDXSpotsList;
  SpotsDisplayed: integer;

implementation
uses
   uSettingsModel,     // Settings.BandMap -- the eight display filters
  uMainForm,   { the call field, named -- wh[] round 3 }
  uSpotAge,   // UTCNow, AgeSeconds -- the leaf the tests can link
  uDXSpotParse, // SpotCallIsCQMarker / SpotCallIsNewMarker
  SysUtils,   // Issue #997: Format/StrPCopy
  utils_text, // D12: ANSI StrPCopy for wsprintfBuffer
  LOGSUBS2,
  MainUnit,
  uNet,
  uBandMapView,   // BandMapSelected -- ask the view, do not reach into it
  uBandmap,
  LogWind;

function SpotAgeSeconds(const aSpot: TSpotRecord): integer;
begin
   Result := AgeSeconds(aSpot.FSysTime, UTCNow);
end;

{ TStringList }

constructor TDXSpotsList.Create;
begin
  inherited Create;
  FList := TSpotsList.Create;
  FCriticalSection := TCriticalSection.Create;
  FCurrentCursorFreq := -1;
end;

destructor TDXSpotsList.Destroy;
begin
  FreeAndNil(FCriticalSection);
  FreeAndNil(FList);
  inherited Destroy;
end;

function TDXSpotsList.GetCount: integer;
begin
  Result := FList.Count;
end;

function TDXSpotsList.AddSpot(var Spot: TSpotRecord; SendToNetwork: boolean):
  integer;
var
  i: integer;
  //ie: str80;

begin

  SetCursor;
  ie_check := False;
  // The BandMapPreventRefresh gate that stood here DISCARDED the spot: it
  // returned before InsertSpot, so a spot arriving while the operator had the
  // band map focused never entered the list at all.  SendAndClearBuffer was
  // meant to replay those, but InsertSpotBuffer -- the only thing that could
  // fill the buffer -- was declared, defined and never called, so BCount never
  // left zero and the replay was a no-op.  The whole BList group is gone with
  // this gate.
  //
  // Focus must freeze the VIEW, never the MODEL.  Display still honours the
  // flag, so the rows stay put under the operator's mouse; the spots are now
  // waiting there when focus leaves instead of being lost.
  if Settings.BandMap.So2rDisplay then
    if ((Radio1.FilteredStatus.Freq <> 0) and (Radio2.FilteredStatus.Freq <> 0))
      then
      if ((ActiveBand <> Spot.Fband) and (InactiveRadioptr.BandMemory <>
        Spot.Fband)) then
         begin
         exit; // 4.105.14
         end;
  for i := 0 to FList.Count - 1 do
     begin
     // 4.102.5 - filter the added spots to match the actual bm display

     if not Settings.BandMap.AllBands then
       if FList[i].FBand <> BandmapBand then
          begin
          Continue; //Gav  ActiveBand changed to BandmapBand
          end;
     if not Settings.BandMap.AllModes then
       if FList[i].FMode <> BandmapMode then
          begin
          Continue; //Gav  ActiveMode changed to BandmapMode
          end;
     if not Settings.BandMap.DupeDisplay then
       if FList[i].FDupe then
          begin
          Continue;
          end;
     if not Settings.BandMap.DisplayCQ then
       if FList[i].FCQ then
          begin
          Continue;
          end;
     if not Settings.Bands.WarcEnabled then
       if FList[i].FWARCBand then
          begin
          Continue;
          end;
     //if Settings.So2r.TwoRadioMode then
     if ((ActiveBand <> Spot.Fband) and (InactiveRadioptr.BandMemory <>
       Spot.Fband)) then
        begin
        Continue;
        end;
     if Settings.BandMap.MultsOnly then
       if not ((FList[i].FMult) or (FList[i].FCQ)) then
          begin
          Continue; //Gav added or FCQ to stop CQ spots being trapped by Mult only filter
          end;
     if not Settings.Bands.VhfEnabled then
       if (FList[i].FBand > Band12) then
          begin
          Continue;
          end;
     if (FList[i].FBand = Spot.FBand) and (FList[i].FCall = Spot.FCall) then
        begin
        continue;
        end;
     end;
  if Spot.FBand in [Band30, Band17, Band12] then
     begin
     Spot.FWARCBand := True;
     end;
  if (Settings.Operating.IeSwitch) then
     begin
     ie_check := True;
     if (InitialExchangeEntry(Spot.FCall) = '') then
        begin
        exit;
        end;
     end;

  // A spot on a frequency the list already holds REPLACES that entry (FindSpot
  // keys on frequency alone); otherwise it goes in at the insertion point.  The
  // search is inside the lock with the change it decides, so the index it
  // returns cannot go stale between the two.
  FCriticalSection.Enter;
  try
     if FindSpot(Spot, Result) then
        begin
        FList[Result] := Spot;
        end
     else
        begin
        FList.Insert(Result, Spot);
        end;
  finally
     FCriticalSection.Leave;
  end;
  RequestRepaint;
  //  if CallWinKeyDown then
  //   Windows.SetFocus(wh[mweCall]);
  // end;

  (* Network.ShareSpots is read HERE, at the moment of the spot, so changing it
    needs no restart.  A spot received from the network is added with
    SendToNetwork False, which is why a station never posts back what it was
    sent. *)
  if (SendToNetwork)                       and
     (Settings.Network.ShareSpots)         and
     (not SpotCallIsCQMarker(Spot.FCall))  and
     (NetIsConnected)                      then
     begin
     SendDXSpotToNet(Spot);
     end;

end;

function TDXSpotsList.BuildVisibleSpots(var aIndex: array of integer;
                                        var aCursorRow: integer): integer;
var
  FilteredSpotCount: integer;
  k: integer;
  i: integer;
  bottom: integer;
  top: integer;
  centre: integer;
  centrefound: boolean;
  NumberEntriesDisplayed: integer;
  // Diagnostic counters -- per-filter rejection tallies (issue: bandmap-startup-clear).
  // Total of all reject* + rejNoNext + NumberEntriesDisplayed should equal FList.Count.
  rejDupeNext, rejBand, rejMode, rejDupeFlag, rejCQ, rejWARC, rejMultsOnly, rejVHF: Integer;
begin
  bottom := 0;
  top := 1;
  centrefound := False; // 4.79.3
  rejDupeNext := 0; rejBand := 0; rejMode := 0; rejDupeFlag := 0;
  rejCQ := 0; rejWARC := 0; rejMultsOnly := 0; rejVHF := 0;
  //  inc(SpotsDisplayed);
  //  setwindowtext(OpModeWindowHandle,inttopchar(SpotsDisplayed));
  UpdateSpotsMultiplierStatus;
  NumberEntriesDisplayed := 0;
  k := 0;
  for i := 0 to FList.Count - 1 do
     begin
     // Drop a spot whose call matches the NEXT one in the frequency-sorted list.
     // The last element has no next: `FList[i + 1]` at i = FList.Count - 1 read one
     // past the live entries, and past the declared array[0..1000] altogether
     // once the list was full, comparing against whatever happened to be there.
     // Usually that garbage did not match and the spot survived, so the bug was
     // invisible -- but a chance match silently dropped the highest spot.
     if (i < FList.Count - 1) and (FList[i].FCall = FList[i + 1].FCall) then
        begin
        Inc(rejDupeNext);
        continue;
        end;
     if not Settings.BandMap.AllBands then
       if FList[i].FBand <> BandmapBand then
          begin
          Inc(rejBand);
          Continue; //Gav  ActiveBand changed to BandmapBand
          end;
     if not Settings.BandMap.AllModes then
       if FList[i].FMode <> BandmapMode then
          begin
          Inc(rejMode);
          Continue; //Gav  ActiveMode changed to BandmapMode
          end;
     if not Settings.BandMap.DupeDisplay then
       if FList[i].FDupe then
          begin
          Inc(rejDupeFlag);
          Continue;
          end;
     if not Settings.BandMap.DisplayCQ then
       if FList[i].FCQ then
          begin
          Inc(rejCQ);
          Continue;
          end;
     if not Settings.Bands.WarcEnabled then
       if FList[i].FWARCBand then
          begin
          Inc(rejWARC);
          Continue;
          end;
     if Settings.BandMap.MultsOnly then
       if not ((FList[i].FMult) or (FList[i].FCQ)) then
          begin
          Inc(rejMultsOnly);
          Continue; //Gav added or FCQ to stop CQ spots being trapped by Mult only filter
          end;
     if not Settings.Bands.VhfEnabled then
       if (FList[i].FBand > Band12) then
          begin
          Inc(rejVHF);
          Continue;
          end;

     if FList[i].FFrequency = FCurrentCursorFreq then
        begin
        aCursorRow := NumberEntriesDisplayed;
        end;
     aIndex[k] := i;
     inc(NumberEntriesDisplayed);
     inc(k);

     end;
  logger.Trace('[BuildVisibleSpots] filter pass: FList.Count=%d, passed=%d, rejected by: NextDup=%d Band=%d Mode=%d DupeFlag=%d CQ=%d WARC=%d MultsOnly=%d VHF=%d',
    [FList.Count, NumberEntriesDisplayed, rejDupeNext, rejBand, rejMode, rejDupeFlag,
     rejCQ, rejWARC, rejMultsOnly, rejVHF]);

  //Gav   Start of added section to limit and centre bandmap on vfo, using pointers to Flist stored in aIndex arrray

  FilteredSpotCount := k;

  if FilteredSpotCount > Settings.BandMap.DisplayLimit then
     begin
     // Every endpoint test below must go through aIndex.  The window
     // (bottom..top) indexes the FILTERED list, so asking the UNFILTERED FList
     // about it is asking a different list: with any filter active FList[0] is
     // not the first spot on display, and FList[FilteredSpotCount] is not the
     // last -- it is an unrelated spot, and off the end of the array[0..1000]
     // once the list fills up.
     if FList[aIndex[0]].FFrequency >= BandMapCursorFrequency then
        begin
        // Everything on display is at or above the cursor -- show the low end.
        top := Settings.BandMap.DisplayLimit - 1;
        bottom := 0;
        centrefound := true;
        end;

     if FList[aIndex[FilteredSpotCount - 1]].FFrequency <= BandMapCursorFrequency then
        begin
        // Everything on display is at or below the cursor -- show the high end.
        top := FilteredSpotCount - 1;
        bottom := FilteredSpotCount - Settings.BandMap.DisplayLimit;
        centrefound := true;
        end;

     // Named bound, NOT `to k - 1`.  Treating the loop variable as a value is
     // what produced the out-of-range window this routine used to clamp.
     for k := 0 to FilteredSpotCount - 1 do
        begin
        if FList[aIndex[k]].FFrequency > BandMapCursorFrequency then
           begin
           centre := k;
           if (centre >= (Settings.BandMap.DisplayLimit div 2)) and (centre <=
             (FilteredSpotCount - (Settings.BandMap.DisplayLimit div 2))) then
              begin
              top := centre + ((Settings.BandMap.DisplayLimit div 2) - 1);
              bottom := centre - (Settings.BandMap.DisplayLimit div 2);
              centrefound := true;
              end;
           if centre > (FilteredSpotCount - (Settings.BandMap.DisplayLimit div 2)) then
              begin
              top := FilteredSpotCount - 1;
              bottom := FilteredSpotCount - Settings.BandMap.DisplayLimit;
              centrefound := true;
              end;
           if centre < (Settings.BandMap.DisplayLimit div 2) then
              begin
              top := Settings.BandMap.DisplayLimit - 1;
              bottom := 0;
              centrefound := true;
              end;
           break;
           end;
        end;

     if (centrefound <> true) then
        begin
        // No displayed spot is above the cursor, so the cursor sits at or beyond
        // the top of the list: the high end is the window to show -- the same one
        // the second test above picks, which is why this should now be
        // unreachable.  It is kept because centrefound is set in four places and
        // a later branch could leave it False.
        //
        // This read `centre := abs((k - 1) div 2)`.  After a for loop completes
        // normally, Delphi leaves the loop variable UNDEFINED -- so that line
        // centred the window on a garbage value, and `centre - (limit div 2)`
        // could land below zero.  THAT is the wrong range the clamp below was
        // added to absorb.
        top := FilteredSpotCount - 1;
        bottom := FilteredSpotCount - Settings.BandMap.DisplayLimit;
        end;
     end

  else
     begin
     top := FilteredSpotCount - 1;
     bottom := 0;
     end;

  // BACKSTOP, not the fix.  The four branches above are now each provably in
  // range, so neither clamp should ever fire; the Warn is how we find out if a
  // later edit breaks that.  The guard stays at the indexing loop rather than
  // in any one branch because the invariant belongs here: whatever the branches
  // decide, this array may only be read within its bounds.
  //
  // NOTE ON WHAT THIS DOES *NOT* EXPLAIN.  This clamp was added believing it
  // was the cause of an ERangeError NY4I saw in this routine.  It cannot be:
  // range checking is OFF in this build (tr4w.lproj, DCC_RangeChecking=false)
  // and no unit here turns it on, so a negative index is a SILENT bad read, not
  // a raised exception.  With $R-, an ERangeError comes from the RTL itself --
  // chiefly SetLength with a NEGATIVE length, which in this routine means
  // `setlength(aIndex, FList.Count)` above with FList.Count < 0.  That crash is
  // still unexplained; do not treat it as fixed by this clamp.
  if bottom < 0 then
     begin
     logger.Warn('[BuildVisibleSpots] bottom=%d clamped to 0 (top=%d, filtered=%d, limit=%d)',
                 [bottom, top, FilteredSpotCount, Settings.BandMap.DisplayLimit]);
     bottom := 0;
     end;
  if top > FilteredSpotCount - 1 then
     begin
     logger.Warn('[BuildVisibleSpots] top=%d clamped to %d (bottom=%d, limit=%d)',
                 [top, FilteredSpotCount - 1, bottom, Settings.BandMap.DisplayLimit]);
     top := FilteredSpotCount - 1;
     end;
  // The caller renders aIndex[bottom..top].  Returning the COUNT and the
  // bottom row rather than a pair of endpoints would be a second convention to
  // get wrong; these are the same two numbers the list box loop already used.
  Result := 0;
  if FilteredSpotCount > 0 then
     begin
     for k := bottom to top do
        begin
        aIndex[Result] := aIndex[k];
        Inc(Result);
        end;
     end;
  logger.Trace('[BuildVisibleSpots] window: bottom=%d, top=%d, rows=%d, cursorRow=%d, limit=%d',
    [bottom, top, Result, aCursorRow, Settings.BandMap.DisplayLimit]);
end;

procedure TDXSpotsList.Clear;
begin
  RequestRepaint;
  FCriticalSection.Enter;
  try
     FList.Clear;
  finally
     FCriticalSection.Leave;
  end;
end;

procedure TDXSpotsList.RequestRepaint;
begin
  Inc(FRepaintToken);
end;

function TDXSpotsList.NeedsRepaint: boolean;
begin
  Result := FRepaintToken <> FPaintedToken;
end;

procedure TDXSpotsList.MarkPainted;
begin
  FPaintedToken := FRepaintToken;
end;

function TDXSpotsList.IndexOfSpot(const aSpot: TSpotRecord): integer;
var
  i: integer;
begin
  Result := -1;
  for i := 0 to FList.Count - 1 do
     begin
     if (FList[i].FFrequency = aSpot.FFrequency) and
        (FList[i].FCall = aSpot.FCall) then
        begin
        Result := i;
        Exit;
        end;
     end;
end;

procedure TDXSpotsList.Delete(Index: integer);
begin
  // THE Enter WAS MISSING once.  This routine had `try ... finally
  // FCriticalSection.Leave end` with nothing acquiring the section first, so it
  // called LeaveCriticalSection on a section this thread did not own -- which
  // decrements the recursion count of whoever DOES own it and can hand the list
  // to two threads at once.  The range test is inside the lock for the same
  // reason the search in AddSpot is: the count it tests must be the count it
  // deletes from.
  FCriticalSection.Enter;
  try
     if (Index < 0) or (Index >= FList.Count) then
        begin
        Exit;
        end;
     FList.Delete(Index);
  finally
     FCriticalSection.Leave;
  end;
  RequestRepaint;
end;

function TDXSpotsList.FindSpot(const Spot: TSpotRecord; var Index: integer):
  boolean;
var
  l, h, i, c: integer;
begin
  Result := False;
  l := 0;
  h := FList.Count - 1;
  while l <= h do
     begin
     i := (l + h) shr 1;
     c := FList[i].FFrequency - Spot.FFrequency;
       //CompareStrings(FList[I].FCall, s);
     if c < 0 then
        begin
        l := i + 1
        end
     else
        begin
        h := i - 1;
        if c = 0 then
           begin
           Result := True;
           l := i;
           end;
        end;
     end;
  Index := l;
end;

function TDXSpotsList.Get(Index: integer): TSpotRecord;
begin
  Result := Default(TSpotRecord); // ny4i Test to return null Issue #115
  if (Index < 0) or (Index >= FList.Count) then
     begin
     Exit;
     end;
  Result := FList[Index];
end;

procedure TDXSpotsList.UpdateSpotsMultiplierStatus;
var
  i: integer;
  Spot: TSpotRecord;
begin
  for i := 0 to FList.Count - 1 do
     begin
     Spot := FList[i];
     if (not SpotCallIsCQMarker(Spot.FCall)) and
        (not SpotCallIsNewMarker(Spot.FCall)) then
        begin
        // The multiplier question is asked OUTSIDE the lock (it walks the
        // log); only the write-back is locked, so the poller never sees a
        // half-written record.  Only the main thread changes the list, so
        // entry i is still the one that was read.
        Spot.FMult := VisibleLog.DetermineIfNewMult(Spot.FCall, Spot.FBand,
          Spot.FMode);
        FCriticalSection.Enter;
        try
           FList[i] := Spot;
        finally
           FCriticalSection.Leave;
        end;
        end;
     end;
  RequestRepaint;
end;

{ AGE EVERY SPOT AND DROP THE ONES PAST THE LIMIT.

  BAND MAP DECAY TIME is stated in MINUTES -- the help file and the operator's
  habit both say so -- but it is compared in SECONDS, so a spot expires sixty
  seconds after IT arrived rather than at the next minute boundary.  That is
  the whole difference between spots falling off one at a time and the map
  emptying in one tick. }
procedure TDXSpotsList.DecrementSpotsTimes;
var
  i: integer;
  Spot: TSpotRecord;
begin
  if FList.Count = 0 then
     begin
     Exit;
     end;
  // Past the empty-list guard, every remaining path changes FAgeSeconds.
  RequestRepaint;

  FCriticalSection.Enter;
  try
     i := 0;
     while i < FList.Count do
        begin
        Spot := FList[i];
        Spot.FAgeSeconds := SpotAgeSeconds(Spot);
        if Spot.FAgeSeconds >= Settings.BandMap.DecayTime * 60 then
           begin
           // The next spot has just moved into slot i, so i does not advance.
           FList.Delete(i);
           end
        else
           begin
           FList[i] := Spot;
           Inc(i);
           end;
        end;
  finally
     FCriticalSection.Leave;
  end;
end;

procedure TDXSpotsList.UpdateSpotsDupeStatus(const RXCall: string; RXBand:
  BandType; RXMode: ModeType);
var
  i: integer;
  Spot: TSpotRecord;
begin
  FCriticalSection.Enter;
  try
     for i := 0 to FList.Count - 1 do
        begin
        Spot := FList[i];
        if (Spot.FBand = RXBand) and
           (Spot.FMode = RXMode) and
           (Spot.FCall = RXCall) then
           begin
           Spot.FDupe := True;
           FList[i] := Spot;
           end;
        end;
  finally
     FCriticalSection.Leave;
  end;
  // Was `Display` -- a model routine painting a control.  Its caller
  // (logsubs2.pas:1710) calls DisplayBandMap immediately afterwards anyway.
  RequestRepaint;
end;

function TDXSpotsList.CompareStrings(const s1, s2: CallString): integer;
var
  L1, L2, l, i: integer;
begin
  L1 := length(s1);
  L2 := length(s2);
  if L1 > L2 then
     begin
     l := L2
     end
  else
     begin
     l := L1;
     end;
  for i := 1 to l do
     begin
     Result := Ord(s1[i]) - Ord(s2[i]);
     if Result <> 0 then
        begin
        Exit;
        end;
     end;
  if Result = 0 then
     begin
     Result := L1 - L2;
     end;

  //  Result := CompareString(LOCALE_SYSTEM_DEFAULT, NORM_IGNORECASE, @s1[1], length(s1), @s2[1], length(s2)) - 2;

end;

procedure TDXSpotsList.ResetSpotsTimes;
var
  Index: integer;
  Spot: TSpotRecord;
begin
  FCriticalSection.Enter;
  try
     for Index := 0 to FList.Count - 1 do
        begin
        Spot := FList[Index];
        Spot.FAgeSeconds := 0;
        FList[Index] := Spot;
        end;
  finally
     FCriticalSection.Leave;
  end;
  RequestRepaint;
end;

procedure TDXSpotsList.ResetSpotsDupes;
var
  Index: integer;
  Spot: TSpotRecord;
begin
  FCriticalSection.Enter;
  try
     for Index := 0 to FList.Count - 1 do
        begin
        Spot := FList[Index];
        Spot.FDupe := False;
        FList[Index] := Spot;
        end;
  finally
     FCriticalSection.Leave;
  end;
  RequestRepaint;
end;

procedure TDXSpotsList.SetCursor;
begin
  FCriticalSection.Enter;
  try
     // WHICH SPOT THE OPERATOR IS ON, remembered as a FREQUENCY so the
     // centring window can find it again after the list has been rebuilt.
     // This used to ask the list box for its selected item's data; the band
     // map is a form now and answers through the view seam.
     if Assigned(BandMapSelected) then
        begin
        FCurrentCursorFreq := BandMapSelected;
        if (FCurrentCursorFreq >= 0) and (FCurrentCursorFreq < FList.Count) then
           begin
           FCurrentCursorFreq := FList[FCurrentCursorFreq].FFrequency;
           end;
        end;
  finally
     FCriticalSection.Leave;
  end;
end;

procedure TDXSpotsList.TuneDupeCheck(Freq: integer);
var
  Index: integer;
  FoundCall: CallString;
  Spot: TSpotRecord;
  d: integer;
  a: integer;
begin
  if not BandMapEnable then
     begin
     Exit;
     end;

  d := MaxLongint  { was Windows.MaxLongint: same $7FFFFFFF, declared by System };
  FoundCall := '';
  // THE POLLING THREAD RUNS THIS, so the scan holds the lock: the main thread
  // may delete from the list while it walks.  Everything that touches the call
  // window happens after the lock is released, off the copy in FoundCall.
  FCriticalSection.Enter;
  try
     for Index := 0 to FList.Count - 1 do
        begin
        Spot := FList[Index];
        a := Abs(Spot.FFrequency - Freq);
        if a = 0 then
           begin
           Exit;
           end;
        if (a < Settings.BandMap.GuardBand) and
           (not SpotCallIsCQMarker(Spot.FCall)) then
           begin
           if (a < d) then
              begin
              d := a;
              FoundCall := Spot.FCall;
              end;
           DupeInfoCall := FoundCall;
           break; // stop search on match 4.130.1
           end;
        end;
  finally
     FCriticalSection.Leave;
  end;
  if (d >= Settings.BandMap.GuardBand) or (Pos(UTF8Encode(Settings.My.Call), FoundCall) > 0) then
    // 4.57.8  // 4.72.1
     begin
     ClearAltD;
     tClearDupeInfoCall;

     end;

  if d <= Settings.BandMap.GuardBand then
     begin
     {  if not Settings.Contest.SprintQsyRule then
       begin
        switch := False;    // n4af 4.56.1
        switchnext := False;
       end;   }
     tClearDupeInfoCall; // 4.57.10
     ClearAltD; // 4.65.2
     DupeInfoCall := FoundCall; // 4.65.2
     DupeCheckOnInactiveRadio(True);
     DupeInfoCallWindowCleared := False;
     tCallWindowSetFocus;
     end;
end;

procedure TDXSpotsList.DisplayCallsignOnThisFreq(Freq: integer);
var
  Index: integer;
  FoundCall: CallString;
  Spot: TSpotRecord;
  d: integer;
  a: integer;
begin
  if not BandMapEnable then
     begin
     Exit;
     end;
  if not Settings.BandMap.CallWindowEnable then
     begin
     Exit;
     end;
  if CallsignIsTypedByOperator then
     begin
     Exit;
     end;

  d := MaxLongint;
  FoundCall := '';
  // THE POLLING THREAD RUNS THIS -- see TuneDupeCheck for why the scan is
  // locked and the call window is touched only after it.
  FCriticalSection.Enter;
  try
     for Index := 0 to FList.Count - 1 do
        begin
        Spot := FList[Index];
        a := Abs(Spot.FFrequency - Freq);
        if (a < Settings.BandMap.GuardBand) and
           (not SpotCallIsCQMarker(Spot.FCall)) then
           begin
           if a < d then
              begin
              d := a;
              FoundCall := Spot.FCall;
              end;
           end;
        end;
  finally
     FCriticalSection.Leave;
  end;

  if d <= Settings.BandMap.GuardBand then
     begin
     if (FoundCall <> Settings.My.Call) and
        (OpMode = SearchAndPounceOpMode) then // n4af 4.45.10
        begin
        tCleareCallWindow;
        tClearDupeInfoCall; // 4.55.6
        PutCallToCallWindow(FoundCall);
        SetEntrySel(TR4WCallEdit, 0, -1);
        CallsignIsPastedFromBandMap := True;
        // tSetExchWindInitExchangeEntry ; // 4.139.1
        // Windows.SetFocus(wh[mweCall]);      // 4.139.2
        end;


    Exit;
     end;

  if not CallWindowEmpty then
    if (CallsignIsPastedFromBandMap)  then
       begin
       tCleareCallWindow;
       tCleareExchangeWindow;
       //tCallWindowSetFocus;
       end
    else
     if CallWindowEmpty then
        begin
        tcleareExchangeWindow;
        tcleareCallWindow;
        tCallWindowSetFocus;
        end;

end;

initialization
  SpotsList := TDXSpotsList.Create;
  tCallWindowSetFocus;    // 4.139.1

finalization
  FreeAndNil(SpotsList);
end.



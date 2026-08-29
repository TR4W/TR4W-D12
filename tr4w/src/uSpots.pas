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
  WinSock2,
  Windows,
  Messages,
  LogDupe,
  LogEdit,
  LogPack,
  LogRadio,
  LogSCP,
  Tree,
  SyncObjs;

type

  PSpotsList = ^TSpotsList;
  TSpotsList = array[0..1000] of TSpotRecord;

  TDXSpotsList = object {class}

  private
    FList: PSpotsList;
    FCount{, j}: integer;
    FCurrentCursorFreq: integer;
    FCapacity: integer;
    FCriticalSection: TCriticalSection;
    // THE REPAINT TOKEN.  Bumped by every mutator and by RequestRepaint; the
    // band map compares it against what it last painted.  It replaces the
    // global boolean BandMapNeedsRefresh, which three units raised and a fourth
    // cleared -- a mutator that forgot to raise it simply did not appear until
    // something unrelated repainted, and there was no way to tell that from a
    // spot that had not arrived.  A counter cannot be missed or double-cleared.
    FRepaintToken: cardinal;
    FPaintedToken: cardinal;
    procedure Grow;

  protected
    function GetCapacity: integer;
    procedure SetCapacity(NewCapacity: integer);
    function CompareStrings(const s1, s2: CallString): integer;
    procedure InsertSpot(Index: integer; const Spot: TSpotRecord); virtual;

  public
    //destructor Destroy; override;
    constructor Init;
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
    // the call must copy: InsertSpot Moves the array, so an insert renumbers
    // every index above it.  The LCL form takes copies immediately.
    function BuildVisibleSpots(var aIndex: array of integer;
                               var aCursorRow: integer): integer;
    procedure Delete(Index: integer);
    //    procedure ClearDupes;
    procedure ResetSpotsTimes;
    procedure ResetSpotsDupes;

    procedure DisplayCallsignOnThisFreq(Freq: integer);
    procedure TuneDupeCheck(Freq: integer);
    function FindSpot(const Spot: TSpotRecord; var Index: integer): boolean;
      virtual;
    property Count: integer read FCount;

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
    // the caller kept.  InsertSpot Moves the array, so an index taken a quarter
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
  uMainForm,   { the call field, named -- wh[] round 3 }
  uSpotAge,   // UTCNow, AgeSeconds -- the leaf the tests can link
  SysUtils,   // Issue #997: Format/StrPCopy
  uAnsiStr, // D12: ANSI StrPCopy for wsprintfBuffer
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

constructor TDXSpotsList.Init;
begin
  Grow;
  FCriticalSection := TCriticalSection.Create;
end;

//destructor TDXSpotsList.Destroy;
//begin
//   FreeAndNil(FCriticalSection);
//end;

function TDXSpotsList.AddSpot(var Spot: TSpotRecord; SendToNetwork: boolean):
  integer;
label
  add;
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
  if BandMapSO2RDisplay then
    if ((Radio1.FilteredStatus.Freq <> 0) and (Radio2.FilteredStatus.Freq <> 0))
      then
      if ((ActiveBand <> Spot.Fband) and (InactiveRadioptr.BandMemory <>
        Spot.Fband)) then
         begin
         exit; // 4.105.14
         end;
  for i := 0 to FCount - 1 do
     begin
     // 4.102.5 - filter the added spots to match the actual bm display

     if not BandMapAllBands then
       if FList^[i].FBand <> BandmapBand then
          begin
          Continue; //Gav  ActiveBand changed to BandmapBand
          end;
     if not BandMapAllModes then
       if FList^[i].FMode <> BandmapMode then
          begin
          Continue; //Gav  ActiveMode changed to BandmapMode
          end;
     if not BandMapDupeDisplay then
       if FList^[i].FDupe then
          begin
          Continue;
          end;
     if not BandMapDisplayCQ then
       if FList^[i].FCQ then
          begin
          Continue;
          end;
     if not WARCBandsEnabled then
       if FList^[i].FWARCBand then
          begin
          Continue;
          end;
     //if Config.TwoRadioMode then
     if ((ActiveBand <> Spot.Fband) and (InactiveRadioptr.BandMemory <>
       Spot.Fband)) then
        begin
        Continue;
        end;
     if BandMapMultsOnly then
       if not ((FList^[i].FMult) or (FList^[i].FCQ)) then
          begin
          Continue; //Gav added or FCQ to stop CQ spots being trapped by Mult only filter
          end;
     if not VHFBandsEnabled then
       if (FList^[i].FBand > Band12) then
          begin
          Continue;
          end;
     if (FList^[i].FBand = Spot.FBand) and (FList^[i].FCall = Spot.FCall) then
        begin
        continue;
        end;
     end;
  if Spot.FBand in [Band30, Band17, Band12] then
     begin
     Spot.FWARCBand := True;
     end;
  if (IE_Switch) then
     begin
     ie_check := True;
     if (InitialExchangeEntry(Spot.FCall) = '') then
        begin
        exit;
        end;
     end;

  if FindSpot(Spot, Result) then
     begin
     goto Add;
     end;
  FCriticalSection.Enter;
  try
     InsertSpot(Result, Spot);
  finally
     FCriticalSection.Leave;
  end;
  Add:    // How to experienced programmers write GoTo statements? I don't get it! // ny4i
  FList^[Result] := Spot;
  RequestRepaint;
  //  if CallWinKeyDown then
  //   Windows.SetFocus(wh[mweCall]);
  // end;

  if SendToNetwork then
    if PInteger(@Spot.FCall[1])^ <> tCQAsInteger then
      if NetIsConnected then
         begin
         NetDXSpot.dsSpot := Spot;
         SendToNet(NetDXSpot, SizeOf(NetDXSpot));
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
  // Total of all reject* + rejNoNext + NumberEntriesDisplayed should equal FCount.
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
  for i := 0 to FCount - 1 do
     begin
     // Drop a spot whose call matches the NEXT one in the frequency-sorted list.
     // The last element has no next: `FList^[i + 1]` at i = FCount - 1 read one
     // past the live entries, and past the declared array[0..1000] altogether
     // once the list was full, comparing against whatever happened to be there.
     // Usually that garbage did not match and the spot survived, so the bug was
     // invisible -- but a chance match silently dropped the highest spot.
     if (i < FCount - 1) and (FList^[i].FCall = FList^[i + 1].FCall) then
        begin
        Inc(rejDupeNext);
        continue;
        end;
     if not BandMapAllBands then
       if FList^[i].FBand <> BandmapBand then
          begin
          Inc(rejBand);
          Continue; //Gav  ActiveBand changed to BandmapBand
          end;
     if not BandMapAllModes then
       if FList^[i].FMode <> BandmapMode then
          begin
          Inc(rejMode);
          Continue; //Gav  ActiveMode changed to BandmapMode
          end;
     if not BandMapDupeDisplay then
       if FList^[i].FDupe then
          begin
          Inc(rejDupeFlag);
          Continue;
          end;
     if not BandMapDisplayCQ then
       if FList^[i].FCQ then
          begin
          Inc(rejCQ);
          Continue;
          end;
     if not WARCBandsEnabled then
       if FList^[i].FWARCBand then
          begin
          Inc(rejWARC);
          Continue;
          end;
     if BandMapMultsOnly then
       if not ((FList^[i].FMult) or (FList^[i].FCQ)) then
          begin
          Inc(rejMultsOnly);
          Continue; //Gav added or FCQ to stop CQ spots being trapped by Mult only filter
          end;
     if not VHFBandsEnabled then
       if (FList^[i].FBand > Band12) then
          begin
          Inc(rejVHF);
          Continue;
          end;

     // SendMessage(BandMapListBox, LB_ADDSTRING, 0, integer(i));         //GAV original message send

     if FList^[i].FFrequency = FCurrentCursorFreq then
        begin
        aCursorRow := NumberEntriesDisplayed;
        end;
     aIndex[k] := i;
     inc(NumberEntriesDisplayed);
     inc(k);

     end;
  logger.Trace('[BuildVisibleSpots] filter pass: FCount=%d, passed=%d, rejected by: NextDup=%d Band=%d Mode=%d DupeFlag=%d CQ=%d WARC=%d MultsOnly=%d VHF=%d',
    [FCount, NumberEntriesDisplayed, rejDupeNext, rejBand, rejMode, rejDupeFlag,
     rejCQ, rejWARC, rejMultsOnly, rejVHF]);

  //Gav   Start of added section to limit and centre bandmap on vfo, using pointers to Flist stored in aIndex arrray

  FilteredSpotCount := k;

  if FilteredSpotCount > BandMapDisplayLimit then
     begin
     // Every endpoint test below must go through aIndex.  The window
     // (bottom..top) indexes the FILTERED list, so asking the UNFILTERED FList
     // about it is asking a different list: with any filter active FList^[0] is
     // not the first spot on display, and FList^[FilteredSpotCount] is not the
     // last -- it is an unrelated spot, and off the end of the array[0..1000]
     // once the list fills up.
     if FList^[aIndex[0]].FFrequency >= BandMapCursorFrequency then
        begin
        // Everything on display is at or above the cursor -- show the low end.
        top := BandMapDisplayLimit - 1;
        bottom := 0;
        centrefound := true;
        end;

     if FList^[aIndex[FilteredSpotCount - 1]].FFrequency <= BandMapCursorFrequency then
        begin
        // Everything on display is at or below the cursor -- show the high end.
        top := FilteredSpotCount - 1;
        bottom := FilteredSpotCount - BandMapDisplayLimit;
        centrefound := true;
        end;

     // Named bound, NOT `to k - 1`.  Treating the loop variable as a value is
     // what produced the out-of-range window this routine used to clamp.
     for k := 0 to FilteredSpotCount - 1 do
        begin
        if FList^[aIndex[k]].FFrequency > BandMapCursorFrequency then
           begin
           centre := k;
           if (centre >= (BandMapDisplayLimit div 2)) and (centre <=
             (FilteredSpotCount - (BandMapDisplayLimit div 2))) then
              begin
              top := centre + ((BandMapDisplayLimit div 2) - 1);
              bottom := centre - (BandMapDisplayLimit div 2);
              centrefound := true;
              end;
           if centre > (FilteredSpotCount - (BandMapDisplayLimit div 2)) then
              begin
              top := FilteredSpotCount - 1;
              bottom := FilteredSpotCount - BandMapDisplayLimit;
              centrefound := true;
              end;
           if centre < (BandMapDisplayLimit div 2) then
              begin
              top := BandMapDisplayLimit - 1;
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
        bottom := FilteredSpotCount - BandMapDisplayLimit;
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
  // `setlength(aIndex, FCount)` above with FCount < 0.  That crash is
  // still unexplained; do not treat it as fixed by this clamp.
  if bottom < 0 then
     begin
     logger.Warn('[BuildVisibleSpots] bottom=%d clamped to 0 (top=%d, filtered=%d, limit=%d)',
                 [bottom, top, FilteredSpotCount, BandMapDisplayLimit]);
     bottom := 0;
     end;
  if top > FilteredSpotCount - 1 then
     begin
     logger.Warn('[BuildVisibleSpots] top=%d clamped to %d (bottom=%d, limit=%d)',
                 [top, FilteredSpotCount - 1, bottom, BandMapDisplayLimit]);
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
    [bottom, top, Result, aCursorRow, BandMapDisplayLimit]);
end;

procedure TDXSpotsList.Clear;
begin
  RequestRepaint;
  FCriticalSection.Enter;
  try
     if FCount <> 0 then
        begin
        FCount := 0;
        SetCapacity(0);
        end;
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
  if not Assigned(FList) then
     begin
     Exit;
     end;
  for i := 0 to FCount - 1 do
     begin
     if (FList^[i].FFrequency = aSpot.FFrequency) and
        (FList^[i].FCall = aSpot.FCall) then
        begin
        Result := i;
        Exit;
        end;
     end;
end;

procedure TDXSpotsList.Delete(Index: integer);
begin
  if (Index < 0) or (Index >= FCount) then
     begin
     Exit; //Error(@SListIndexError, Index);
     end;
  // THE Enter WAS MISSING.  This routine has always had `try ... finally
  // FCriticalSection.Leave end` with nothing acquiring the section first, so it
  // called LeaveCriticalSection on a section this thread did not own -- which
  // decrements the recursion count of whoever DOES own it and can hand the list
  // to two threads at once.  Every sibling (InsertSpot, Clear, SetCursor) pairs
  // them correctly; this one was the odd man out.
  FCriticalSection.Enter;
  try
     dec(FCount);
     if Index < FCount then
        begin
        System.Move(FList^[Index + 1], FList^[Index], (FCount - Index) * SizeOf(TSpotRecord));
        end;
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
  h := FCount - 1;
  while l <= h do
     begin
     i := (l + h) shr 1;
     c := FList^[i].FFrequency - Spot.FFrequency;
       //CompareStrings(FList^[I].FCall, s);
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
  FillChar(Result, SizeOf(Result), 0); // ny4i Test to return null Issue #115
  if (Index < 0) or (Index >= FCount) then
     begin
     Exit; //ERROR(@SListIndexError, Index);
     end;
  Result := FList^[Index];
end;

function TDXSpotsList.GetCapacity: integer;
begin
  Result := FCapacity;
end;

procedure TDXSpotsList.UpdateSpotsMultiplierStatus;
var
  i: integer;
begin
  for i := 0 to FCount - 1 do
     begin

     if PInteger(@FList^[i].FCall[1])^ <> tCQAsInteger then
       if PInteger(@FList^[i].FCall[1])^ <> tNEWAsInteger then
          begin
          FList^[i].FMult := VisibleLog.DetermineIfNewMult(FList^[i].FCall,
            FList^[i].FBand, FList^[i].FMode);
          end;
     //    FList^[i].FMult := MultString <> 0;
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
label
  NextSpot;
var
  i: integer;
  Difference: integer;
begin
  if FCount = 0 then
     begin
     Exit;
     end;
  // Up here, not at the end: the loop below leaves through a goto and two
  // Exits, so there is no single end to hang it on.  Past the empty-list guard,
  // every remaining path changes FAgeSeconds.
  RequestRepaint;

  i := 0;
  NextSpot:

  Difference := SpotAgeSeconds(FList^[i]);
  FList^[i].FAgeSeconds := Difference;
  if Difference >= BandMapDecayTime * 60 then
     begin
     Delete(i)
     end
  else
     begin
     inc(i);
     end;
  if i = FCount then
     begin
     Exit;
     end;
  goto NextSpot;
end;

procedure TDXSpotsList.UpdateSpotsDupeStatus(const RXCall: string; RXBand:
  BandType; RXMode: ModeType);
var
  i: integer;
begin
  for i := 0 to FCount - 1 do
     begin
     if FList^[i].FBand = RXBand then
       if FList^[i].FMode = RXMode then
         if FList^[i].FCall = RXCall then
            begin
            FList^[i].FDupe := True;
            end;
     end;
  // Was `Display` -- a model routine painting a control.  Its caller
  // (LOGSUBS2.PAS:1710) calls DisplayBandMap immediately afterwards anyway.
  RequestRepaint;
end;

procedure TDXSpotsList.Grow;
var
  delta: integer;
begin
  if FCapacity > 64 then
     begin
     delta := FCapacity div 4
     end
  else if FCapacity > 8 then
     begin
     delta := 16
     end
  else
     begin
     delta := 4;
     end;
  SetCapacity(FCapacity + delta);
end;

procedure TDXSpotsList.InsertSpot(Index: integer; const Spot: TSpotRecord);
begin
  FCriticalSection.Enter;
  try
     if FCount = FCapacity then
        begin
        Grow;
        end;
     if Index < FCount then
        begin
        System.Move(FList^[Index], FList^[Index + 1],(FCount - Index) * SizeOf(TSpotRecord));
        end;
     FList^[Index] := Spot;
     inc(FCount);
  finally
     FCriticalSection.Leave;
  end;
end;

procedure TDXSpotsList.SetCapacity(NewCapacity: integer);
begin
  ReallocMem(FList, NewCapacity * SizeOf(TSpotRecord));
  FCapacity := NewCapacity;
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
begin
  FCriticalSection.Enter;
  try
     if Assigned(FList) then
        begin
        for Index := 0 to FCount - 1 do
           begin
           FList^[Index].FAgeSeconds := 0;
           end;
        end;
  finally
     FCriticalSection.Leave;
  end;
  RequestRepaint;
end;

procedure TDXSpotsList.ResetSpotsDupes;
var
  Index: integer;
begin
  FCriticalSection.Enter;
  try
     if Assigned(FList) then
        begin
        for Index := 0 to FCount - 1 do
           begin
           FList^[Index].FDupe := False;
           end;
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
        if (FCurrentCursorFreq >= 0) and (FCurrentCursorFreq < FCount) and
           Assigned(FList) then
           begin
           FCurrentCursorFreq := FList^[FCurrentCursorFreq].FFrequency;
           end;
        end;
  finally
     FCriticalSection.Leave;
  end;
end;

procedure TDXSpotsList.TuneDupeCheck(Freq: integer);
var
  Index: integer;
  Index2: integer;
  d: integer;
  a: integer;
begin
  if not BandMapEnable then
     begin
     Exit;
     end;
  if not Assigned(FList) then
     begin
     exit;
     end;

  d := MAXLONG;
  //  Index2 := 0; // 4.79.3
  for Index := 0 to FCount - 1 do
     begin
     a := Abs(FList^[Index].FFrequency - Freq);
     if a = 0 then
        begin
        exit;
        end;
     if (a < BandMapGuardBand) and (PInteger(@FList^[Index].FCall[1])^ <>
       tCQAsInteger) then
        begin
        if (a < d) then
           begin
           d := a;
           Index2 := Index;
           end;
        DupeInfoCall := FList^[Index2].FCall;
        break; // stop search on match 4.130.1
        end;
     end;
  if (d >= BandMapGuardBand) or (Pos(MyCall, Flist^[Index2].FCall) > 0) then
    // 4.57.8  // 4.72.1
     begin
     ClearAltD;
     tClearDupeInfoCall;

     end;

  if d <= BandMapGuardBand then
     begin
     {  if not SprintQSYRule then
       begin
        switch := False;    // n4af 4.56.1
        switchnext := False;
       end;   }
     tClearDupeInfoCall; // 4.57.10
     ClearAltD; // 4.65.2
     DupeInfoCall := FList^[Index2].FCall; // 4.65.2
     DupeCheckOnInactiveRadio(True);
     DupeInfoCallWindowCleared := False;
     tCallWindowSetFocus;
     end;
end;

procedure TDXSpotsList.DisplayCallsignOnThisFreq(Freq: integer);
var
  Index: integer;
  Index2: integer;
  d: integer;
  a: integer;
begin
  if not BandMapEnable then
     begin
     Exit;
     end;
  if not BandMapCallWindowEnable then
     begin
     Exit;
     end;
  if CallsignIsTypedByOperator then
     begin
     Exit;
     end;

  d := MAXLONG;
  //  index2 := 0; // 4.79.3
  for Index := 0 to FCount - 1 do
     begin
     a := Abs(FList^[Index].FFrequency - Freq);
     {logger.debug('[TDXSpotsList.DisplayCallsignOnThisFreq] a = %d, BandMapGuardBand = %d,  PInteger(@FList^[Index].FCall[1])^ = %d, tCQAsInteger = %d',
                  [a, BandMapGuardBand, PInteger(@FList^[Index].FCall[1])^, tCQAsInteger]);}
     if (a < BandMapGuardBand) and (PInteger(@FList^[Index].FCall[1])^ <>  tCQAsInteger) then
        begin
        if a < d then
           begin
           d := a;
           Index2 := Index;
           end;
        end;
     end;

  if d <= BandMapGuardBand then
     begin
     //if (Pos(MyCall,Flist^[Index2].FCall)>0) then continue;
     if FList^[Index2].FCall <> MyCall then
       if OpMode = SearchAndPounceOpMode then // n4af 4.45.10
          begin
          tCleareCallWindow;
          tClearDupeInfoCall; // 4.55.6
          PutCallToCallWindow(FList^[Index2].FCall);
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

begin
  //  SpotsList := TDXSpotsList.Create;
  SpotsList.Init;
  SpotsList.FCurrentCursorFreq := -1;
  tCallWindowSetFocus;    // 4.139.1
end.



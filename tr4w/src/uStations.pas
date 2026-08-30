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
unit uStations;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  Classes,
  SysUtils,
  TF,
  VC,
  Tree,
  Windows,
  uCallsigns,
  LogDupe,
  LogWind,
  Messages
  ,
  uTR4WStrings,
  uAnsiStr;

procedure FillStationsColumn;
function AddCallsignToStationColumn(Call: CallString): integer;
procedure UpdateStationStatus(Call: CallString; i: integer);
function FindStationInCallsignColumn(Call: CallString): integer;
procedure UpdateAllStationsList;
procedure UpdateCallsignAfterEditing(Before, After: CallString);
procedure SetStationsCallsignMask;
procedure EnumSTATIONSTXT(FileString: PShortString);
procedure BuildStationsColumns;
procedure ClearStationsColumn;
procedure StationsWindowShown;

var
//  StationsListView                      : HWND;
  StationsListFileInUse                 : boolean;
  StationsStartBand                     : BandType;

implementation

uses
  MainUnit,
  Forms,           { Application.QueueAsyncCall -- the marshalling below }
  SyncObjs,
  uCrashLog,       { OnMainThread }
  uStationsForm;   { the view -- see the model note below }

{ ---------------------------------------------------------------------------
  THE ROWS ARE A MODEL NOW, NOT THE CONTROL.

  The Win32 version kept the row set INSIDE the list view and had no choice
  about it: the control was created with LVS_SORTASCENDING, so IT decided the
  order, insertion index did not equal row index, and the only identity a row
  had was the text in column 0.  Two routines paid for that -- one found a
  station with LVM_FINDITEM, the other walked every row calling
  ListView_GetItemText just to learn which callsign it was looking at.

  StationRows is that set, sorted, and the list view is a projection of it: row
  i shows StationRows[i].  Both halves move together (Add then InsertRow,
  Delete then DeleteRow), so an index is meaningful on either side and nothing
  reads a row back to find out what it is.

  Sorted, CaseSensitive False IS LVS_SORTASCENDING's rule -- the control sorted
  with lstrcmpi -- and callsigns are upper-cased on the way in besides.
  Duplicates are ACCEPTED rather than ignored, because the control accepted them
  and this change is not the place to decide they are wrong.
  --------------------------------------------------------------------------- }
var
  StationRows: TStringList = nil;

function Rows: TStringList;
begin
  if StationRows = nil then
     begin
     StationRows := TStringList.Create;
     StationRows.CaseSensitive := False;
     StationRows.Duplicates := dupAccept;
     StationRows.Sorted := True;
     end;
  Result := StationRows;
end;

{ StationsDlgProc IS GONE, and with it the last Win32 in this unit.

  Its four arms, and where each went:

    WM_SIZE            -> tListBoxClientAlign, stretching the list over the
                          client area.  The .lfm says Align = alClient.
    WM_WINDOWPOSCHANGING, WM_EXITSIZEMOVE
                       -> DefTR4WProc.  Neither converted form wires an
                          equivalent (the band map and the function keys window
                          do not either), so the FrmSetFocus-after-resize
                          nicety is not reproduced.  Stated rather than
                          silently dropped.
    WM_NOTIFY          -> FrmSetFocus on NM_RELEASEDCAPTURE, same nicety.
    WM_INITDIALOG      -> StationsWindowShown, reached through the form's
                          OnShow.  See the seam in uStationsForm. }

{ The header, rebuilt from scratch each time the window opens.

  SIX BAND COLUMNS, and the six are not fixed: Band160..Band10 is the whole
  contest-HF set in BandType order (160, 80, 40, 20, 15, 10 -- 30/17/12 sit
  AFTER Band10 in the enum), and UpdateAllStationsList re-captions all six from
  StationsStartBand, which becomes Band6 on a VHF band.  So the header follows
  the operator to VHF and the widths do not have to change with it. }
procedure BuildStationsColumns;
var
  TempBand: BandType;
begin
  StationsClearColumns;
  StationsAddColumn(string(RC_CALLSIGN), 75, False);
  for TempBand := Band160 to Band10 do
     begin
     StationsAddColumn(string(BandStringsArrayWithOutSpaces[TempBand]), 36, True);
     end;
end;

procedure FillStationsColumn;
var
  Index                                 : integer;
begin
  StationsListFileInUse := False;
  if EnumerateLinesInFile('STATIONS.TXT', EnumSTATIONSTXT, True) then
     begin
     // The file supplied the list, so nothing else adds to it -- set AFTER the
     // enumeration, not per line.  See EnumSTATIONSTXT.
     StationsListFileInUse := True;
     end
  else
{
  if OpenFileForRead(FileRead, TR4W_LOG_PATH_NAME + 'STATIONS.TXT') then
  begin
    StationsListFileInUse := False;
    while not Eof(FileRead) do
    begin
      ReadLn(FileRead, Call);
      if Call <> '' then
        if Call[1] <> ';' then
          AddCallsignToStationColumn(Call);
    end;
    Close(FileRead);
    StationsListFileInUse := True;
  end
  else
}
     begin
     for Index := 0 to CallsignsList.Count - 1 do
       if CallsignsList.GetQSOs(Index) > 0 then
          begin
          AddCallsignToStationColumn(CallsignsList.Get(Index));
          end;
     StationsListFileInUse := False;
     end;
  UpdateAllStationsList;
end;

{ Empty the rows -- both halves, together.  MainUnit reloads the log and then
  refills this window; it used to do that by sending LVM_DELETEALLITEMS to the
  control, which is no longer where the rows live. }
procedure ClearStationsColumn;
begin
  Rows.Clear;
  StationsClearRows;
end;

{ Returns the row this callsign now occupies, or -1 IF IT WAS NOT ADDED.

  The -1 is new and it matters.  The two early exits below used to leave Result
  UNDEFINED, and UpdateCallsignAfterEditing fed that straight into
  UpdateStationStatus as a row number -- a garbage index into the control, which
  Win32 ignored and an LCL list would raise on. }
function AddCallsignToStationColumn(Call: CallString): integer;
var
  s: string;
begin
  Result := -1;
  if StationsListFileInUse then Exit;

  if StationsCallsignsMask <> '' then
    if pos(StationsCallsignsMask, Call) = 0 then Exit;

  s := UpperCase(string(Call));
  Result := Rows.Add(s);         // sorted -- this IS the row position
  StationsInsertRow(Result, s);
end;

{ UpdateStationStatus IS CALLED FROM A SOCKET THREAD, AND IT WRITES A TListView.

  LogContact does display work as well as logging -- UpdateStationStatus,
  ShowDomesticMultiplierStatus, DisplayHour, DisplayNamePercentage -- and
  uWSJTX calls LogContact directly from its UDP listener. Measured 2026-08-30:
  thread 30356, one worked QSO.

  THE MAIN-WINDOW GUARD DOES NOT COVER THIS ONE, and that is the point worth
  recording. uMainForm's element accessors defer, so everything reaching the
  main window off-thread was made safe by a funnel. THIS window has its own
  accessors, and StationsSetCell assigns TListItem.Caption and SubItems with no
  thread check at all -- ListUsable tests nil and HandleAllocated and nothing
  else. So the off-thread report, which only instruments SetMainWindowText and
  the main-window accessors, could never have named it: the converted tool
  windows each have their own way in.

  A TListView item write from a socket thread is worse than a caption write. It
  manipulates the widget set's item list and can send LVM_SETITEM and
  reallocate, so it is the class of race that corrupts rather than the class
  that flickers.

  MARSHALLED AS A WHOLE ROUTINE, not per cell: it reads the dupe model and then
  writes six cells from it, and deferring the writes one at a time would let a
  second QSO interleave and paint half of each. }
procedure QueueStationStatus(const aCall: CallString; const aIndex: integer); forward;

procedure UpdateStationStatus(Call: CallString; i: integer);
var
  Index                                 : integer;
  ItemIndex                             : integer;
  da                                    : TDupesArray;
  QSOB4                                 : boolean;
  TempMode                              : ModeType;
  p                                     : string;
  TempIndex                             : integer;
begin
  if tr4w_WindowsArray[tw_STATIONS_INDEX].WndHandle = 0 then Exit;

  if not OnMainThread then
     begin
     QueueStationStatus(Call, i);
     Exit;
     end;

  Call[length(Call) + 1] := #0;
  if i = -1 then
     begin
     ItemIndex := FindStationInCallsignColumn(Call);

     if ItemIndex = -1 then
        begin
        if StationsListFileInUse = False then ItemIndex := AddCallsignToStationColumn(Call) else Exit;
        end

     end
  else
     begin
     ItemIndex := i;
     end;

  // AddCallsignToStationColumn declines a callsign the mask excludes.
  if ItemIndex < 0 then Exit;

  if not CallsignsList.FindCallsign(Call, Index) then Exit;
  if not CallsignsList.GetDupesArray(Index, da) then Exit;

  if QSOByMode then TempMode := ActiveMode else TempMode := Both;

  for TempIndex := 0 to 5 { BandType(Ord(StationsStartBand) + 5)} do
     begin
     QSOB4 := (da[TempMode] and (1 shl (Ord(StationsStartBand) + TempIndex))) <> 0;
     if QSOB4 then p := '+' else p := '';
     StationsSetCell(ItemIndex, TempIndex + 1, p);
     end;
  if i = -1 then
     begin
     StationsSelectAndShow(ItemIndex);
     end;
end;

{ LVM_FINDITEM was a linear scan of the control's own text.  A sorted list finds
  it by bisection and, more to the point, answers from the model -- so the answer
  is a row number the caller can hand straight back to any other routine here. }
function FindStationInCallsignColumn(Call: CallString): integer;
begin
  if not Rows.Find(UpperCase(string(Call)), Result) then
     begin
     Result := -1;
     end;
end;

procedure UpdateAllStationsList;
var
  Index                                 : integer;
begin
  if tr4w_WindowsArray[tw_STATIONS_INDEX].WndHandle = 0 then Exit;
  if ActiveBand in [Band6..BandLight] then StationsStartBand := Band6 else StationsStartBand := Band160;
  for Index := 0 to 5 do
     begin
     StationsSetColumnCaption(Index + 1,
       string(BandStringsArrayWithOutSpaces[BandType(Index + Ord(StationsStartBand))]));
     end;

  // THE MODEL IS THE THING WALKED.  This loop used to ask the control how many
  // rows it had and then read each callsign back out of column 0 with
  // ListView_GetItemText, into a 12-byte buffer.  Both of those went away with
  // the row set: the count and the callsign are the model's, and CallString no
  // longer has to be rebuilt from bytes.
  StationsBeginUpdate;
  for Index := 0 to Rows.Count - 1 do
     begin
     UpdateStationStatus(CallString(Rows[Index]), Index);
     end;
  StationsEndUpdate;

  TF.Format(wsprintfBuffer, PAnsiChar(WinAnsi(TC_STATIONSINMODE)), ModeStringArray[ActiveMode]);
  StationsSetCaption(string(PAnsiChar(@wsprintfBuffer)));
end;

procedure UpdateCallsignAfterEditing(Before, After: CallString);
var
  Index                                 : integer;
begin
  if tr4w_WindowsArray[tw_STATIONS_INDEX].WndHandle = 0 then Exit;
  if Before = After then Exit;
  Index := FindStationInCallsignColumn(Before);
  if Index = -1 then Exit;

  Rows.Delete(Index);
  StationsDeleteRow(Index);

  Index := AddCallsignToStationColumn(After);
  if Index < 0 then Exit;      // excluded by the mask -- nothing to update
  UpdateStationStatus(After, Index);
end;

procedure SetStationsCallsignMask;
begin
  if tr4w_WindowsArray[tw_STATIONS_INDEX].WndHandle = 0 then Exit;
  ClearStationsColumn;
  FillStationsColumn;
end;

{ ONE LINE OF STATIONS.TXT USED TO LOAD, AND ONLY ONE.

  This callback added a callsign and then set StationsListFileInUse := True --
  but AddCallsignToStationColumn opens with `if StationsListFileInUse then
  Exit`, so every line after the first was dropped in silence.  The flag means
  "this list came from the file, so do not add worked callsigns to it
  dynamically" (see UpdateStationStatus, which reads it exactly that way), and
  that is a fact about the WHOLE enumeration, not about a line.  It is set by
  FillStationsColumn when the enumeration finishes.

  Found while moving the rows out of the control, 2026-08-24.  Not reproducible
  here -- no STATIONS.TXT exists in target\ -- which is consistent with the
  feature being rarely used rather than with it working. }
procedure EnumSTATIONSTXT(FileString: PShortString);
begin
  if FileString^[1] <> ';' then
     begin
     AddCallsignToStationColumn(FileString^);
     end;
end;

{ Everything the dialog's WM_INITDIALOG did, minus the two lines that were about
  being a dialog: the window handle is recorded by OpenTR4WWindow, and the list
  view is in the .lfm.  Reached through the form's OnShow -- see the seam there. }
procedure StationsWindowShown;
begin
  BuildStationsColumns;
  ClearStationsColumn;
  FillStationsColumn;
end;

{ ------------------------------------------------------------ marshalling --
  A FIFO, not a single pending slot. Two QSOs logged in quick succession are two
  different callsigns, and the LAST one is not the only one that matters here --
  each has its own row to paint. That is the opposite of the station-display
  case in uWSJTX, where newest-wins is right because there is one "who are you
  working" and a newer answer supersedes the older. }
type
  TPendingStatus = record
    Call: CallString;
    Index: integer;
  end;

  TStationStatusWork = class(TObject)
  public
    procedure Drain(Data: PtrInt);
  end;

var
  GStatusQueue: array of TPendingStatus;
  GStatusLock: TCriticalSection = nil;
  GStatusWork: TStationStatusWork = nil;

procedure TStationStatusWork.Drain(Data: PtrInt);
var
  item: TPendingStatus;
  n: integer;
begin
  while True do
     begin
     GStatusLock.Acquire;
     try
       n := Length(GStatusQueue);
       if n = 0 then
          begin
          Exit;
          end;
       item := GStatusQueue[0];
       Move(GStatusQueue[1], GStatusQueue[0], (n - 1) * SizeOf(TPendingStatus));
       SetLength(GStatusQueue, n - 1);
     finally
       GStatusLock.Release;
     end;

     // On the main thread now, so this takes the normal path.
     UpdateStationStatus(item.Call, item.Index);
     end;
end;

procedure QueueStationStatus(const aCall: CallString; const aIndex: integer);
var
  n: integer;
begin
  if GStatusWork = nil then
     begin
     GStatusWork := TStationStatusWork.Create;
     end;

  GStatusLock.Acquire;
  try
    n := Length(GStatusQueue);
    SetLength(GStatusQueue, n + 1);
    GStatusQueue[n].Call := aCall;
    GStatusQueue[n].Index := aIndex;
  finally
    GStatusLock.Release;
  end;

  // Queue first, THEN schedule -- a drain already running picks up what we just
  // added; the reverse order can leave an entry with no drain pending.
  // QueueAsyncCall RAISES on a shut-down queue rather than returning False.
  if (Application = nil) or Application.Terminated then
     begin
     Exit;
     end;
  Application.QueueAsyncCall(GStatusWork.Drain, 0);
end;

initialization
  GStatusLock := TCriticalSection.Create;
  StationsOnShow := @StationsWindowShown;

finalization
  GStatusWork.Free;
  GStatusWork := nil;
  GStatusLock.Free;
  GStatusLock := nil;
  StationRows.Free;
  StationRows := nil;

end.


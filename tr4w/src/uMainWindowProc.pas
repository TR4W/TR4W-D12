unit uMainWindowProc;
{$I tr4w.inc}
{
  THE MAIN WINDOW'S WINDOW PROCEDURE.

  Lifted out of tr4w.dpr on 2026-08-17, at the start of Phase 3 of the
  Win32-to-LCL migration.  BEHAVIOUR-NEUTRAL: the body below is the one that was
  in the program file, moved and not rewritten.

  WHY IT HAD TO MOVE.  Phase 3a makes tr4whandle a TForm's handle, and a form is
  a class in a unit -- it cannot reach a function declared in the .dpr.  So the
  window procedure had to become referenceable before the form could exist.  It
  is also 350 lines of message dispatch that had no business in a program file
  whose job is startup order.

  WHAT IT STILL IS: a raw Win32 WNDPROC, registered on tr4w_WinClass and called
  by Windows.  Phase 3a keeps it exactly that -- the TForm will delegate to it --
  and only later phases move individual messages onto LCL controls, where most
  of them stop needing a hand-written proc at all.
}

interface

uses
  Windows,
  Classes;   // TShiftState, TObject -- the LCL event signatures

type
   { WHICH entry field a handler belongs to. Passed EXPLICITLY from a named
     handler rather than derived from Sender: branching on Sender is banned
     here, and it is also what makes the shared body below safe to share. }
   TTR4WEntryField = (efCall, efExchange);

   { THE CALLSIGN AND EXCHANGE FIELDS' KEYBOARD BEHAVIOUR, as LCL events.

     Phase 3c. These arms lived in the hand-rolled GetMessage loop in tr4w.dpr
     and dispatched by comparing Msg.HWND against wh[mweCall] / wh[mweExchange].
     That comparison existed only because there were no control objects to hang
     events on; the fields became LCL TEdits in Phase 3b, so the arms are not
     relocated so much as given the home they always wanted.

     It matters beyond tidiness: HWND is Win32-only, and a raw handle comparison
     in the input path is one of the things that cannot follow this program to
     macOS or Linux.

     The loop still exists and still owns what is genuinely GLOBAL -- the
     QuickQSL keys, the numeric-keypad CW memories, and ShowFMessages on the
     Ctrl/Alt keyup -- because those fire no matter which window has focus and
     have no control to belong to. }
   { ON AnsiChar: this tree compiles with char = WideChar, but the LCL's
     TKeyPressEvent is `var Key: char` compiled in the LCL's own mode, where
     char is AnsiChar.  Writing `char` here produced "got (TObject;var
     WideChar) expected (TObject;var Char)" -- so the type is stated
     explicitly, for the same reason the house rule says to name the ...A
     variant of a generic Win32 call rather than let the binding be inferred. }
   TTR4WEntryEvents = class
   private
      procedure EntryKeyPress(var Key: AnsiChar; const aField: TTR4WEntryField);
      procedure EntryKeyDown(var Key: word; const aField: TTR4WEntryField);
   public
      procedure CallKeyPress(Sender: TObject; var Key: AnsiChar);
      procedure CallKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure CallKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure ExchangeKeyPress(Sender: TObject; var Key: AnsiChar);
      procedure ExchangeKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
   end;

var
   { Created on first use by EntryEvents. One instance serves both fields. }
   TR4WEntryEvents: TTR4WEntryEvents = nil;

function EntryEvents: TTR4WEntryEvents;


function WindowProc(TRHWND: HWND; Msg: UINT; wParam: wParam; lParam: lParam): longword; stdcall;

implementation

{ MINIMAL, and measured rather than inherited.  Lifting this out of tr4w.dpr
  brought the program's whole 300-unit uses clause with it; the list below is
  what the compiler actually demanded, arrived at by stripping to four units and
  reading the missing identifiers.  A window procedure that pulls in everything
  is a window procedure nothing can be moved out of. }
uses
  Messages,
  VC,                 // tr4whandle, wh[], the mwe* elements, tr4wColors
  TF,
  MainUnit,
  uCommctrl,          // PNMLVCustomDraw, CDDS_*, CDRF_*, ListView_GetHeader
  LogWind,            // QuickDisplay
  uGetServerLog,      // WM_USER_HEADLESS_SYNC_REPLACE + the headless-sync state
  uFunctionKeys,      // ShowFMessages
  uPOTAParks,         // WM_POTA_DOWNLOAD_DONE / _LOAD_DONE and the loaders
  uTRMasterUpdate,    // WM_TRMASTER_DOWNLOAD_DONE
  uCTYUpdate,         // WM_CTY_DOWNLOAD_DONE / WM_CTY_VERSION_CHECKED
  uTCIServer,         // WM_TCI_APPLY
  uPanelUpdate,       // WM_PANEL_UPDATE
  uMMTTY,             // the MMTTY window message
  LOGSUBS2,           // ExitProgram, on WM_CLOSE
  uCTYDAT,            // ctyLoadInCountryFile, after a CTY.DAT download
  LOGSTUFF,           // CallWindowKeyDownProc, ProcessTAB, SpaceBarProc2, ...
  tree,               // KeyboardCallsignChar
  LOGK1EA,            // ShiftKeyEnable
  LOGRADIO,           // RITBumpUp/Down, VFOBumpUp/Down
  LogCW,              // RepeatLastCWMessage
  uMenu;              // menu_cwspeedup / menu_cwspeeddown via ProcessMenu
                      // (NOT cty.pas -- that one is the DLL import and takes
                      // a PWideChar, which is not what this call site passes)

// Column-double-click padding (Issue #750 follow-up).
//
// Windows' default ListView/Header response to a double-click on a
// column divider is to auto-fit the column to its widest content.
// The auto-fit chooses the header-divider position, which is a few
// pixels narrower than the cell-content area because the ListView's
// cell layout adds an internal left/right margin.  At the just-fits
// threshold the saved value triggers ellipsis on the very content
// that fit visually pre-save.
//
// Fix: intercept HDN_DIVIDERDBLCLICK directly -- run the auto-fit
// ourselves with LVSCW_AUTOSIZE_USEHEADER, add COLUMN_DOUBLECLICK_PAD_PX
// for breathing room, apply that width, and save.  We must do all
// the work inside HDN_DIVIDERDBLCLICK and suppress the default OS
// behaviour: HDN_ENDTRACK only fires for end-of-drag, not for
// double-click auto-fit, so a "set a flag in HDN_DIVIDERDBLCLICK
// and add padding in HDN_ENDTRACK" approach silently drops the
// save on double-click.  Manual drag is handled in HDN_ENDTRACK
// without padding -- the dragged width is the operator's explicit
// choice.
const
  COLUMN_DOUBLECLICK_PAD_PX = 12;

function EntryEvents: TTR4WEntryEvents;
begin
   if TR4WEntryEvents = nil then
      begin
      TR4WEntryEvents := TTR4WEntryEvents.Create;
      end;
   Result := TR4WEntryEvents;
end;

{ The two fields' OnKeyPress bodies differ by one call, so they share one and
  the caller says which field it is. Setting Key to #0 is the LCL's "consume",
  and it replaces the loop's `goto NoTransMess`. }
procedure TTR4WEntryEvents.EntryKeyPress(var Key: AnsiChar; const aField: TTR4WEntryField);
var
   vk: wParam;
begin
   // QUICK QSL.  This was the WM_CHAR arm at the top of the message loop, where
   // it fired whatever had focus.  There is no application-wide KeyPress hook in
   // the LCL -- AddOnKeyDownBeforeHandler carries a virtual key, not a character,
   // and QUICK QSL KEY 1 / 2 are characters an operator chooses (default '\' and
   // '=').  Mapping one to a virtual key means VkKeyScan and the current keyboard
   // layout, which is a Win32 call and a locale question, to answer something
   // this field already knows.
   //
   // It belongs here anyway: QuickQSLProcedure returns immediately unless
   // CallWindowString is non-empty, so it has never done anything except while
   // the operator was part-way through a callsign.
   //
   // THE NARROWING, stated rather than hidden: it no longer fires while a TOOL
   // WINDOW has focus.  Typing a call, clicking into the band map and then
   // pressing '\' used to QSL; now it does not.  Bench queue section 30.
   if (Key = QuickQSLKey1) or (Key = QuickQSLKey2) then
      begin
      QuickQSLProcedure(Key);
      end;

   if aField = efCall then
      begin
      CallWindowKeyDownProc(Ord(Key));
      if CallWindowCharConsumed then
         begin
         CallWindowCharConsumed := False;
         Key := #0;
         Exit;
         end;
      end
   else
      begin
      ExchangeWindowKeyDownProc(Ord(Key));    // 4.102.7, ny4i Issue 87
      end;

   // KeyboardCallsignChar TAKES ITS KEY BY var AND CAN REPLACE IT -- it maps
   // QuestionMarkChar to '?' and SlashMarkChar to '/' (tree.pas:5152). The loop
   // passed Msg.wParam and then dispatched the mutated message, so the
   // substitution reached the field. Passing Ord(Key) here would have compiled
   // if the parameter were by value, silently dropped the substitution, and
   // left the operator's ? and / keys inserting the wrong character.
   //
   // The compiler caught it -- "call by var for arg no. 1 has to match exactly"
   // -- which is the only reason it is handled rather than lost.
   vk := Ord(Key);
   if KeyboardCallsignChar(vk, boolean(ActiveMainWindow)) = False then
      begin
      Key := #0;
      end
   else
      begin
      Key := AnsiChar(Byte(vk));
      end;
end;

procedure TTR4WEntryEvents.CallKeyPress(Sender: TObject; var Key: AnsiChar);
begin
   EntryKeyPress(Key, efCall);
end;

procedure TTR4WEntryEvents.ExchangeKeyPress(Sender: TObject; var Key: AnsiChar);
begin
   EntryKeyPress(Key, efExchange);
end;

{ Key := 0 consumes (the loop's `goto NoTransMess`); a bare Exit lets the key
  through untouched (the loop's `goto TransMess`). }
procedure TTR4WEntryEvents.EntryKeyDown(var Key: word; const aField: TTR4WEntryField);
begin
   // Ctrl+= : repeat the exact characters last sent on CW. '=' alone is QUICK
   // QSL KEY 2, so a bare key collides; the Ctrl combo avoids that.
   if (Key = 187 {VK_OEM_PLUS '='}) and (ActiveMode = CW) and
      ((GetKeyState(VK_CONTROL) and $8000) <> 0) then
      begin
      RepeatLastCWMessage;
      Key := 0;
      Exit;
      end;

   if Key in [VK_F1..VK_F12] then
      begin
      ProcessFuntionKeys(Key);
      end;

   if Key = VK_F4 then
      begin
      Key := 0;
      Exit;
      end;

   if Key > 40 then
      begin
      Exit;
      end;

   if (Key = VK_RIGHT {39}) and (aField = efExchange) then
      begin
      TryPutSpaceinExchangeWindow;
      end;

   if Key = VK_PRIOR {33} then
      begin
      ProcessMenu(menu_cwspeedup);
      end;

   if Key = VK_NEXT {34} then
      begin
      ProcessMenu(menu_cwspeeddown);
      end;

   if (Key = VK_SPACE {32}) and (aField = efCall) then
      begin
      SpaceBarProc2;
      Key := 0;
      Exit;
      end;

   if (Key = VK_UP)                                              and
      (ActiveMainWindow = awCallWindow {tr4w_CallWindowActive})  and
      (CallWindowString = '')                                    then
      begin
      if tLogIndex <> 0 then
         begin
         tAltE;
         end;
      end;

   if (Key = VK_UP {38}) or (Key = VK_DOWN {40}) then
      begin
      ProcessTAB(0);
      Key := 0;
      end;

   if {18} Key = VK_MENU then
      begin
      ShowFMessages(24);
      end;

   if {17} Key = VK_CONTROL then
      begin
      ShowFMessages(12);
      end;

   if Key = VK_SHIFT then
      begin
      // In S&P the shift key tunes the VFO with RIT/XIT on but RIT/XIT do not
      // change; in RUN mode it tunes the RIT, and the VFO DISPLAY must change
      // to show the RX frequency.  4.105.6 / 4.97.3.
      //
      // LEFT vs RIGHT SHIFT IS ASKED OF THE KEYBOARD, NOT OF THE MESSAGE.  The
      // loop read the scan code out of lParam -- 42 left, 54 right -- and an
      // LCL OnKeyDown has no lParam to read: it is handed a virtual key and a
      // TShiftState, and the win32 widgetset does not split VK_SHIFT into
      // VK_LSHIFT / VK_RSHIFT (there is no VK_LSHIFT anywhere under
      // lcl\interfaces\win32).
      //
      // GetKeyState is therefore the substitute, and it is the ONE genuinely
      // Windows-only line in this class.  Better named here than buried in a
      // scan-code test: no LCL cross-platform API distinguishes the two shift
      // keys, so this behaviour needs a per-platform answer whenever a Mac or
      // Linux build is attempted.
      if ShiftKeyEnable then
         begin
         if (GetKeyState(VK_LSHIFT) and $8000) <> 0 then
            begin
            if OpMode = CQOpMode then
               begin
               RITBumpDown;
               end
            else
               begin
               VFOBumpDown;
               end;
            end;

         if (GetKeyState(VK_RSHIFT) and $8000) <> 0 then
            begin
            if OpMode = CQOpMode then
               begin
               RITBumpUp;
               end
            else
               begin
               VFOBumpUP;
               end;
            end;
         end;
      end;
end;

procedure TTR4WEntryEvents.CallKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   EntryKeyDown(Key, efCall);
end;

procedure TTR4WEntryEvents.ExchangeKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   EntryKeyDown(Key, efExchange);
end;

{ Only the callsign field had a WM_KEYUP arm. The loop's other two KEYUP lines
  stay in the loop: ShowFMessages(0) on the Ctrl/Alt keyup is global, and the
  band map's list box is a raw Win32 control in a different window, which will
  move when that window converts. }
procedure TTR4WEntryEvents.CallKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   if Key = 222 {apostrophe} then
      begin
      if StartSendingNowKey = '''' then
         begin
         StartSendingNow(True);
         end;
      Key := 0;
      end;
end;

function WindowProc(TRHWND: HWND; Msg: UINT; wParam: wParam; lParam: lParam): longword; stdcall;

label
  GoToExit, CallDefWindowProc;
var
  HDNotifyPtr: PHDNotify;
  lplvcd: PNMLVCustomDraw;
  hdrColIdx: Integer;
  { NMHDR.code SIGNED.  See the note at the assignment: the Windows unit
    declares that field unsigned for FPC, and every notification constant
    is negative. }
  hdrCode: Integer;
  hdrNewWidth: Integer;
begin

  case Msg of

//    WM_POWERBROADCAST: ShowMessage(PChar('WM_POWERBROADCAST' + IntToStr(wParam)));

    WM_DISPLAYCHANGE:
      begin
        if wParam <= 8 then tEightBitsPerPixel := True else tEightBitsPerPixel := False;
        // Issue #1060: a monitor was added/removed or resolution changed -- pull
        // any now-off-screen TR4W window back onto an active monitor.
        RevalidateOpenWindowsOnScreen;
      end;

    // Issue #912: headless server-log auto-sync.  RunSyncThread (worker)
    // SendMessages here once the download is complete; we close the temp
    // file handle and call ReplaceLogByServerLog on the UI thread so
    // LoadinLog's ListView access is safe.
    WM_USER_HEADLESS_SYNC_REPLACE:
      begin
        if NewServerLogHandle <> INVALID_HANDLE_VALUE then
          begin
          CloseHandle(NewServerLogHandle);
          NewServerLogHandle := INVALID_HANDLE_VALUE;
          end;
        ReplaceLogByServerLog(True);
        logger.Info('Auto-sync: local log replaced with server log.');
        HeadlessSyncMode := False;
      end;

//    WM_MOUSEWHEEL: SetStackPointerOnMouseWheel(SHORT(HiWord(Cardinal(wParam))));
    WM_TIMECHANGE:
      begin
        GetSystemTime(UTC);
        SystemTimeChanging;
      end;

    //    WM_CONTEXTMENU: if HWND(wParam) = _NewELogWindow then ShowLogPopupMenu(tr4whandle);

    WM_SIZE:
      begin
        if MMTTY.MMTTYEngine <> 0 then
        begin
          if wParam = SIZE_MINIMIZED then Windows.ShowWindow(MMTTY.MMTTYEngine, SW_SHOWMINNOACTIVE);
          if wParam = SIZE_RESTORED then Windows.ShowWindow(MMTTY.MMTTYEngine, SW_RESTORE);
        end;
      end;

    WM_WINDOWPOSCHANGING: WINDOWPOSCHANGINGPROC(PWindowPos(lParam));
    WM_NOTIFY:
      begin
        with PNMHdr(lParam)^ do

          if (hWndFrom = wh[mweEditableLog]) then
            case code of

              NM_DBLCLK: EditableLogWindowDblClick;

              // ARROW-DOWN OFF THE LAST ROW RETURNS FOCUS TO THE CALL WINDOW.
              //
              // Moved here from the message loop (tr4w.dpr, the one
              // `Msg.HWND = wh[mweEditableLog]` keyboard arm) as part of Phase
              // 3b.  The loop dies in 3c, and every arm in it has to find a
              // home that outlives it.
              //
              // LVN_KEYDOWN, and NOT an LCL TListView.  A ListView notifies its
              // PARENT of key presses, which is a native mechanism that works
              // whoever owns the message pump.  Converting this control to a
              // TListView instead would have been the obvious move and is the
              // wrong one: TR4W drives it through EIGHTEEN raw API call sites
              // -- insert, delete, item state, column widths -- while a
              // TListView keeps its own Items/Columns model.  That model would
              // be EMPTY while the control was full, and any property change
              // forcing RecreateWnd would rebuild the control from it and wipe
              // the visible log.  Mid-contest.
              LVN_KEYDOWN:
                begin
                if PLVKeyDown(lParam)^.wVKey = VK_DOWN then
                   begin
                   // Only when the selection is already on the last row --
                   // otherwise Down just moves down the log, as it should.
                   if ListView_GetNextItem(wh[mweEditableLog], LVNI_ALL, LVNI_SELECTED)
                      = tLogIndex - 1 then
                      begin
                      // Traced like every other key path in this program -- and
                      // for a reason beyond consistency: a focus transition is
                      // otherwise invisible to any test that is not the
                      // operator's eyes.  Cross-process focus reads report
                      // nothing when the program is not in the foreground, so
                      // the log is the only observable this behaviour has.
                      logger.Trace('[EditableLog] VK_DOWN on the last row -> focus to the call window');
                      tCallWindowSetFocus;
                      end;
                   end;
                end;

              // Issue #750: gray out the editable-log row for X-QSO
              // records.  The X-QSO flag is stashed in the row's
              // per-item lParam by tAddContestExchangeToLog ->
              // SetRowXQSOFlag.  We must return CDRF_NOTIFYITEMDRAW
              // at the table-level prepaint to be called back per
              // item; then at item prepaint, replace the text colour
              // with mid-gray ($808080) when the item's lParam is 1.
              // CDRF_NEWFONT tells the listview to apply the new
              // colour.  Exit; bypasses the trailing DefWindowProc
              // call so our Result is what gets returned to the
              // listview's parent-wndproc dispatch.
              NM_CUSTOMDRAW:
                begin
                  lplvcd := PNMLVCustomDraw(lParam);
                  case lplvcd.nmcd.dwDrawStage of
                     CDDS_PREPAINT:
                        begin
                        Result := CDRF_NOTIFYITEMDRAW;
                        Exit;
                        end;
                     CDDS_ITEMPREPAINT:
                        begin
                        if lplvcd.nmcd.lItemlParam = 1 then
                           lplvcd.clrText := $00808080; // mid-gray
                        Result := CDRF_NEWFONT;
                        Exit;
                        end;
                  end;
                end;

              NM_SETFOCUS:
                begin
                  ActiveMainWindow := awEditableLog;
                end;
              NM_KILLFOCUS:
                begin
                end;
            end
          else if (hWndFrom = ListView_GetHeader(wh[mweEditableLog])) then
            begin
            // HDN_DIVIDERDBLCLICK: operator double-clicked the divider
            // to auto-fit.  Do EVERYTHING here (auto-fit, padding,
            // save) instead of deferring to a follow-up HDN_ENDTRACK:
            // per Win32, HDN_ENDTRACK only fires for end-of-drag.  The
            // OS's internal auto-fit during double-click does not
            // generate one, so a flag-based "wait for HDN_ENDTRACK"
            // approach silently drops the save.
            //
            // We run the auto-fit ourselves with LVSCW_AUTOSIZE_USEHEADER,
            // add COLUMN_DOUBLECLICK_PAD_PX for breathing room, apply
            // that to the column, and save.  Returning a non-zero
            // Result suppresses the default header auto-fit; Exit
            // bypasses DefWindowProc which would otherwise overwrite
            // Result with its own return value.
            // SIGNED, and this is the whole defect.
            //
            // NMHDR.code as the Windows unit declares it for FPC is UNSIGNED,
            // while every HDN_/NM_/LVN_ notification constant is NEGATIVE
            // (HDN_ENDTRACKW = HDN_FIRST - 27 = -327).  Comparing the two
            // promotes both to a wider type, so the code arrives as 4294966969
            // and never equals -327.  Delphi's Windows.pas declares that field
            // as Integer, which is why this worked before the FPC port and
            // fails silently after it: the operator drags a column, nothing is
            // saved, and nothing is logged.
            //
            // Proved rather than assumed (2026-08-22): the log printed
            // `code=-327` and `ENDTRACKW=-327` on one line -- %d reinterprets
            // the bits -- and `eq(ENDTRACKW)=0` on the next.
            hdrCode := Integer(code);

            if (hdrCode = HDN_DIVIDERDBLCLICKA) or (hdrCode = HDN_DIVIDERDBLCLICKW) then
               begin
               HDNotifyPtr := PHDNotify(lParam);
               hdrColIdx := HDNotifyPtr^.Item;
               ListView_SetColumnWidth(wh[mweEditableLog], hdrColIdx,
                                       LVSCW_AUTOSIZE_USEHEADER);
               hdrNewWidth := ListView_GetColumnWidth(wh[mweEditableLog],
                                                     hdrColIdx)
                              + COLUMN_DOUBLECLICK_PAD_PX;
               ListView_SetColumnWidth(wh[mweEditableLog], hdrColIdx,
                                       hdrNewWidth);
               SaveColumnWidthToConfig(hdrColIdx, hdrNewWidth);
               Result := 1; // suppress default header auto-fit
               Exit;
               end
            else if (hdrCode = HDN_ENDTRACK) or (hdrCode = HDN_ENDTRACKW) then
               begin
               // Normal end-of-drag: save the dragged width exactly
               // as the operator left it.  No padding here -- the
               // operator explicitly chose this width.
               HDNotifyPtr := PHDNotify(lParam);
               if (HDNotifyPtr^.pItem <> nil) and
                  ((HDNotifyPtr^.pItem^.mask and HDI_WIDTH) <> 0) then
                  SaveColumnWidthToConfig(HDNotifyPtr^.Item,
                                          HDNotifyPtr^.pItem^.cxy)
               else
                  // pItem unavailable — fall back to querying the ListView directly
                  SaveColumnWidthToConfig(HDNotifyPtr^.Item,
                     ListView_GetColumnWidth(wh[mweEditableLog],
                                             HDNotifyPtr^.Item));
               end;
            end;
      end;
    // WM_MEASUREITEM and WM_DRAWITEM for the possible-call list are GONE.
    // Phase 3b made it a designed LCL TListBox, so its item height is a property
    // and its drawing is OnDrawItem on the control -- see uMainForm.lfm and
    // CreateTR4WPossibleCallList.  Both arms only ever served this one control
    // id, so there is nothing left for them to answer.


    WM_LBUTTONDOWN: DragWindow(TRHWND);

    WM_SETFOCUS:
      begin
        if ActiveMainWindow = awExchangeWindow then
          tExchangeWindowSetFocus
        else
          tCallWindowSetFocus;
        ShowFMessages(0);
      end;

    WM_POTA_DOWNLOAD_DONE:
      begin
      // Fired by the async download thread (see uPOTAParks).
      // wParam=1: file saved OK; wParam=0: download failed.
      if wParam = 1 then
         begin
         if LoadPOTAParks(POTAParksFilePath) > 0 then
            QuickDisplay(PAnsiChar('POTA parks loaded'))
         else
            QuickDisplay(PAnsiChar('POTA parks file could not be loaded'));
         end
      else
         QuickDisplay(PAnsiChar('POTA parks download failed'));
      end;

    WM_TRMASTER_DOWNLOAD_DONE:
      begin
      // Fired by the async download thread (see uTRMasterUpdate).
      // wParam=1: file saved OK; wParam=0: download failed.
      //
      // WHY THIS DOES NOT RELOAD SCP, unlike the CTY handler above.
      // ctyLoadInCountryFile is a clean, idempotent reload entry point.
      // TRMASTER has no equivalent: LOGSCP loads it LAZILY into a heap index
      // array behind three flags (TRMasterFileOpen, IndexArrayAllocated,
      // MasterFileExists) plus a cached OperatorNameSet built once, and the
      // only close routine, SCPDisableAndDeAllocateFileBuffer, also sets
      // SCPDisabledByApplication -- it disables SCP rather than reloading it.
      //
      // A partial reload that left OperatorNameSet stale, or SCP disabled,
      // would be wrong data during a contest and would look like nothing at
      // all. Telling the operator to restart is honest and costs one restart;
      // guessing at TRDOS load state is not worth a wrong callsign hint.
      // A proper CD.ReloadTRMaster belongs with the SQLite log work, not here.
      if wParam = 1 then
         begin
         QuickDisplay(PAnsiChar('TRMASTER.DTA downloaded -- restart TR4W to use it'));
         end
      else
         begin
         QuickDisplay(PAnsiChar('TRMASTER.DTA download failed'));
         end;
      end;

    WM_POTA_LOAD_DONE:
      begin
      // Fired by TPOTALoadThread after parsing the CSV off the UI thread.
      // lParam is the parsed TStringList — ApplyLoadedParks takes ownership.
      ApplyLoadedParks(lParam);
      end;

    WM_PANEL_UPDATE:
      begin
      // Posted by a radio reading thread (see uPanelUpdate). lParam carries the
      // update; RunQueuedPanelUpdate applies it here on the main thread and
      // frees it. Same reasoning as WM_TCI_APPLY below, and the same shape.
      RunQueuedPanelUpdate(lParam);
      end;

    WM_TCI_APPLY:
      begin
      // Posted by a TCI connection thread (see uTCIServer). lParam is the apply
      // command; TCIRunQueuedApply runs it here on the main thread and frees it.
      //
      // A posted message rather than TThread.Queue because a queueing thread
      // that exits purges its own callback, and rather than Synchronize because
      // that would block an Indy connection thread against TTCIServer.Stop.
      TCIRunQueuedApply(lParam);
      end;

    WM_CTY_VERSION_CHECKED:
      begin
      if wParam = 1 then
         begin
         // Silent startup notice — no MessageBox, no blocking
         Format(wsprintfBuffer,
            'Newer CTY.DAT available (dated %d). Press Alt-O to download.',
            lParam);
         QuickDisplay(wsprintfBuffer);
         end;
      end;

    WM_CTY_DOWNLOAD_DONE:
      begin
      if wParam = 1 then
         begin
         QuickDisplay(PAnsiChar('CTY.DAT downloaded. Reloading...'));
         // Reload on main thread — CTY tables have no locking, so background
         // reload would race with callsign lookups. Message handler is a safe
         // quiescent point.
         ctyLoadInCountryFile(TR4W_CTY_FILENAME, False, True);
         QuickDisplay(PAnsiChar('CTY.DAT reloaded successfully.'));
         end
      else
         QuickDisplay(PAnsiChar('CTY.DAT download failed.'));
      end;

    WM_CTLCOLORLISTBOX, WM_CTLCOLOREDIT, WM_CTLCOLORSTATIC:
      begin
        Result := DrawWindows(lParam, wParam);
        if Result <> 0 then Exit;
      end;

    WM_CLOSE:
      begin
        GoToExit:
        ExitProgram(True);
        Msg := 0;
      end;

    WM_COMMAND:
      begin
        case wParam of
          66:
            begin
              EditableLogWindowDblClick;
            end;
        end;
{$IF tDebugMode}
        if HiWord(wParam) = BN_CLICKED then
        begin
          if lParam = integer(CPUButtonHandle) then CPUButtonProc;
          FrmSetFocus;
        end;
{$IFEND}

        if (LoWord(wParam) >= 10000) and (LoWord(wParam) <= 10700) then
           ProcessMenu(wParam);
        if (LoWord(wParam) >= 10700) and (LoWord(wParam) <= 10750) then
            RunPlugin(LoWord(wParam));

        if lParam = integer(wh[mweCall]) then
        begin
          if HiWord(wParam) = EN_KILLFOCUS then
          begin
            CheckQuestionMark;
          end;
          if HiWord(wParam) = EN_UPDATE {EN_CHANGE} then CallWindowChange;

          if HiWord(wParam) = EN_SETFOCUS then
          begin
            // The caret is the TEdit's own now -- see the note on the
            // exchange arm below.
            ActiveMainWindow := awCallWindow;
{$IF MORSERUNNER}
//            Windows.SendMessage(MorseRunner_Callsign, WM_SETFOCUS, 0, 0);
{$IFEND}
          end;
        end;

        if lParam = integer(wh[mweExchange]) then
        begin
          if HiWord(wParam) = EN_CHANGE then ExchangeWindowChange;
          if HiWord(wParam) = EN_SETFOCUS then
          begin
            // NO ChangeCaret, AND NO DestroyCaret ON THE WAY OUT.  TR4W drew
            // its own block caret from cursor.bmp into whichever entry field had
            // focus, created here and destroyed on EN_KILLFOCUS.  The fields are
            // LCL TEdits since Phase 3b and a TEdit maintains its own caret, so
            // both ran: NY4I saw two cursors side by side, 2026-08-18.
            //
            // 241b408c sequenced them -- destroy-before-create plus an
            // invalidate -- which made the symptom go away without removing
            // either system.  This is the removal.  NY4I chose the LCL caret
            // over re-expressing the block shape as control painting, on the
            // grounds that D7 showed a plain underline anyway.
            //
            // The CUSTOM CARET command is retired to csRem in uCFG.pas rather
            // than deleted, so an existing .cfg carrying it still loads.
            ActiveMainWindow := awExchangeWindow;
{$IF MORSERUNNER}
//            Windows.SendMessage(MorseRunner_nUMBER, WM_SETFOCUS, 0, 0);
{$IFEND}
          end;
        end;

      end;

  end; {of case}

  if Msg = MMTTY.mmttyMSG then mmttyProcessMessage(wParam, lParam);

  CallDefWindowProc:
  Result := longword(DefWindowProc(TRHWND, Msg, wParam, lParam));
end;

end.

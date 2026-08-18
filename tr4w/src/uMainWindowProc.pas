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
  Windows;

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
  uMMTTY,             // the MMTTY window message, under MMTTYMODE
  LOGSUBS2,           // ExitProgram, on WM_CLOSE
  uCTYDAT;            // ctyLoadInCountryFile, after a CTY.DAT download
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

function WindowProc(TRHWND: HWND; Msg: UINT; wParam: wParam; lParam: lParam): longword; stdcall;

label
  GoToExit, CallDefWindowProc;
var
  HDNotifyPtr: PHDNotify;
  lplvcd: PNMLVCustomDraw;
  hdrColIdx: Integer;
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
    WM_TRAYBALLON:
      begin

      end;
    WM_TIMECHANGE:
      begin
        GetSystemTime(UTC);
        SystemTimeChanging;
      end;

    //    WM_CONTEXTMENU: if HWND(wParam) = _NewELogWindow then ShowLogPopupMenu(tr4whandle);

{$IF MMTTYMODE}
    WM_SIZE:
      begin
        if MMTTY.MMTTYEngine <> 0 then
        begin
          if wParam = SIZE_MINIMIZED then Windows.ShowWindow(MMTTY.MMTTYEngine, SW_SHOWMINNOACTIVE);
          if wParam = SIZE_RESTORED then Windows.ShowWindow(MMTTY.MMTTYEngine, SW_RESTORE);
        end;
      end;
{$IFEND}

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
            if (code = HDN_DIVIDERDBLCLICKA) or (code = HDN_DIVIDERDBLCLICKW) then
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
            else if (code = HDN_ENDTRACK) or (code = HDN_ENDTRACKW) then
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
    WM_MEASUREITEM: if wParam = MainWindowPCLID then
        PMeasureItemStruct(lParam).itemHeight := ws;
       
    WM_DRAWITEM:
      begin
        if wParam = MainWindowPCLID then
          PossibleCallsProc(PDrawItemStruct(lParam));
      end;


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

{$IF MMTTYMODE}
  if Msg = MMTTY.mmttyMSG then mmttyProcessMessage(wParam, lParam);
{$IFEND}

  CallDefWindowProc:
  Result := longword(DefWindowProc(TRHWND, Msg, wParam, lParam));
end;

end.

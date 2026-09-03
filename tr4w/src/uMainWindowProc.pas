unit uMainWindowProc;
{$I tr4w.inc}
{
  THE MAIN WINDOW'S WINDOW PROCEDURE.

  Lifted out of tr4w.lpr on 2026-08-17, at the start of Phase 3 of the
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
  Classes,   // TShiftState, TObject -- the LCL event signatures
  uTR4WStrings;

type
   { WHICH entry field a handler belongs to. Passed EXPLICITLY from a named
     handler rather than derived from Sender: branching on Sender is banned
     here, and it is also what makes the shared body below safe to share. }
   TTR4WEntryField = (efCall, efExchange);

   { THE CALLSIGN AND EXCHANGE FIELDS' KEYBOARD BEHAVIOUR, as LCL events.

     Phase 3c. These arms lived in the hand-rolled GetMessage loop in tr4w.lpr
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
      procedure RestoreBankOnModifierRelease(const aKey: word);
      procedure CallKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure ExchangeKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure ExchangeKeyPress(Sender: TObject; var Key: AnsiChar);
      procedure ExchangeKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);

      { THE NOTIFICATION ARMS -- Phase 3d, the same move Phase 3c made for the
        keyboard.  These were EN_UPDATE, EN_CHANGE, EN_SETFOCUS and EN_KILLFOCUS
        arriving as WM_COMMAND and dispatched by comparing lParam against
        wh[mweCall] / wh[mweExchange].  A named handler per field, wired at
        creation: nothing branches on Sender, and one field's handler cannot be
        reached by the other. }
      procedure CallChange(Sender: TObject);
      procedure CallEnter(Sender: TObject);
      procedure CallExit(Sender: TObject);
      procedure ExchangeChange(Sender: TObject);
      procedure ExchangeEnter(Sender: TObject);
   end;

var
   { Created on first use by EntryEvents. One instance serves both fields. }
   TR4WEntryEvents: TTR4WEntryEvents = nil;

function EntryEvents: TTR4WEntryEvents;

(* RESULTS ARRIVING FROM BACKGROUND THREADS. Passed to the async starters by
  whoever starts them; run on the main thread by uMainThread. *)




function WindowProc(TRHWND: HWND; Msg: UINT; wParam: wParam; lParam: lParam): longword; stdcall;

(* RESULTS ARRIVING FROM BACKGROUND THREADS. Passed to the async starters by
  whoever starts them; run on the main thread by uMainThread. *)
procedure PotaDownloadFinished(aData: PtrInt);
procedure PotaLoadFinished(aData: PtrInt);
procedure TRMasterDownloadFinished(aData: PtrInt);
procedure CTYVersionChecked(aData: PtrInt);
procedure CTYDownloadFinished(aData: PtrInt);

implementation

{ MINIMAL, and measured rather than inherited.  Lifting this out of tr4w.lpr
  brought the program's whole 300-unit uses clause with it; the list below is
  what the compiler actually demanded, arrived at by stripping to four units and
  reading the missing identifiers.  A window procedure that pulls in everything
  is a window procedure nothing can be moved out of. }
uses
  SysUtils,
  uCrashLog,          // LogCaughtException -- see the guard on WindowProc
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
procedure TTR4WEntryEvents.CallChange(Sender: TObject);
begin
   { WAS EN_UPDATE, IS NOW OnChange, AND THAT IS A REAL IF SMALL DIFFERENCE.
     EN_UPDATE fires BEFORE the control repaints; the LCL's OnChange is
     EN_CHANGE, which fires after.  The old code even carried the doubt in a
     comment: EN_UPDATE, with EN_CHANGE beside it in braces.  There is no LCL
     event for EN_UPDATE,
     and inventing one by subclassing to catch a Win32 notification would put
     back exactly what this phase removes.  What can be observed is a repaint of
     the raw text before CallWindowChange has processed it. }
   CallWindowChange;
end;

procedure TTR4WEntryEvents.CallEnter(Sender: TObject);
begin
   // The caret is the TEdit's own -- see the note that was on the exchange arm.
   ActiveMainWindow := awCallWindow;
end;

procedure TTR4WEntryEvents.CallExit(Sender: TObject);
begin
   CheckQuestionMark;
end;

procedure TTR4WEntryEvents.ExchangeChange(Sender: TObject);
begin
   ExchangeWindowChange;
end;

procedure TTR4WEntryEvents.ExchangeEnter(Sender: TObject);
begin
   { NO ChangeCaret, AND NO DestroyCaret ON THE WAY OUT.  TR4W drew its own
     block caret from cursor.bmp into whichever entry field had focus.  The
     fields are LCL TEdits since Phase 3b and a TEdit maintains its own caret,
     so both ran: NY4I saw two cursors side by side, 2026-08-18.  241b408c
     sequenced them and made the symptom go away without removing either
     system; the removal came later.  NY4I chose the LCL caret over
     re-expressing the block shape as control painting, on the grounds that D7
     showed a plain underline anyway.  The CUSTOM CARET command is retired to
     csRem in uCFG.pas rather than deleted, so an existing .cfg still loads. }
   ActiveMainWindow := awExchangeWindow;
end;

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

{ The exchange field had no key-up arm at all. It needs this one for the same
  reason the callsign field does: the operator can be in either when they let
  go of Ctrl. }
procedure TTR4WEntryEvents.ExchangeKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   RestoreBankOnModifierRelease(Key);
end;

{ RELEASING Ctrl OR Alt PUTS THE PLAIN FUNCTION-KEY BANK BACK.

  This lived in uAppInputHooks on Application.OnUserInput, and it never ran.
  Measured on NY4I's machine, 2026-08-28: with TRACE on, the KeyDownBefore
  handler logs every key -- `[InputHooks] key $11 ctrl=1` for Ctrl -- while the
  OnUserInput handler beside it produced NOTHING, so the restore was never
  reached and the labels stayed on the Ctrl bank ("when I unpress Ctrl, the
  labels did not change back", reported three times).

  AddOnKeyDownBeforeHandler delivers; AddOnUserInputHandler does not. So the
  release is handled where the events demonstrably arrive: the entry fields,
  which have been LCL controls since Phase 3b and raise real key events. That is
  also where the operator is when they hold Ctrl to look at a bank.

  The old comment here said this line "stays in the loop" because it was global.
  The loop is gone, and global turned out to mean nowhere. }
procedure TTR4WEntryEvents.RestoreBankOnModifierRelease(const aKey: word);
begin
   if (aKey = VK_CONTROL) or (aKey = VK_MENU) then
      begin
      ShowFMessages(0);
      end;
end;

procedure TTR4WEntryEvents.CallKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   RestoreBankOnModifierRelease(Key);

   if Key = 222 {apostrophe} then
      begin
      if StartSendingNowKey = '''' then
         begin
         StartSendingNow(True);
         end;
      Key := 0;
      end;
end;

function WindowProcBody(TRHWND: HWND; Msg: UINT; wParam: wParam; lParam: lParam): longword; stdcall;

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
    (* WM_NOTIFY IS GONE, AND WITH IT THE LAST WIN32 KNOWLEDGE OF THE LOG.

      Every arm in it answered for the editable log's list-view control: the
      double-click, arrow-down off the last row, the X-QSO grey, the focus
      change, and the two header arms that saved a dragged column width. The
      log is an LCL grid now (uLogGrid) and each of those is an event on the
      control -- see TTR4WMainForm.MainLogDblClick, MainLogKeyDown,
      MainLogEnter and MainLogHeaderSized, and TLogGrid.DrawCell for the
      colours.

      ONE OF THOSE ARMS WAS A REAL DEFECT AND IS WORTH KEEPING THE REASONING
      FOR, because it can recur anywhere this tree compares a notification
      code. NMHDR.code is UNSIGNED as FPC's Windows unit declares it, while
      every HDN_/NM_/LVN_ constant is NEGATIVE (HDN_ENDTRACKW = -327).
      Comparing the two promotes both to a wider type, so the code arrived as
      4294966969 and never matched: the operator dragged a column, nothing was
      saved, nothing was logged. Delphi declares that field as Integer, which
      is why it worked before the FPC port. A grid reports a column resize as
      a method call with an integer index, so the comparison does not exist. *)

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

    (* SIX ARMS FOR BACKGROUND RESULTS ARE GONE FROM HERE.

      A worker thread that finished -- a CTY download, a TRMASTER download, a
      POTA parse, a TCI apply -- used to hand its result over by POSTING A
      WINDOW MESSAGE to the main window, which meant each one needed a message
      id, a window handle for the thread to post to, and an arm in this
      procedure. None of that is about the work.

      They are plain procedures now, below, run on the main thread by
      uMainThread.RunOnMainThread (Application.QueueAsyncCall). The thread is
      handed the procedure when it is started, so this unit no longer has to
      know a background operation exists.

      IT ALSO CLOSES A SILENT FAILURE. PostMessage returns False when the
      target queue is full or the window is gone; where the lParam carried
      OWNERSHIP -- the POTA park list, the TCI command -- a refused post lost
      the result and leaked the object. Two of the four sites checked the
      return value. RunOnMainThread cannot refuse. *)

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

        (* A MENU COMMAND HAS lParam = 0. A CONTROL NOTIFICATION DOES NOT.

          WM_COMMAND carries three different things and Windows tells them
          apart by lParam, not by the id: for a menu item it is 0, for an
          accelerator it is 0, and for a CONTROL it is that control's HWND.
          These two tests read only LoWord(wParam), so every notification from
          a control whose id happened to fall between 10000 and 10750 ran a
          MENU COMMAND -- or, past 10700, tried to load a plugin.

          THIS IS A CONSEQUENCE OF THE LCL CONVERSION AND COULD NOT HAVE BITTEN
          BEFORE IT. When the main window was built by hand every child control
          was given its id here, and none of them were in that range. The
          window is a TForm now and the LCL assigns ids to its children, so the
          entry fields, panels and lists carry whatever numbers it hands out.

          MEASURED FROM A CRASH NY4I CAUGHT IN THE DEBUGGER, 2026-09-03:
          wParam = 67119598, which is LoWord 10734 and HiWord 1024 -- and 1024
          is EN_UPDATE, an edit control telling its parent the text changed.
          lParam was 159459822, the control's handle. That reached RunPlugin as
          "plugin number 34", indexed PluginsArray[34] in an array[1..16], read
          rubbish as a file name, got a nil entry point from LoadLibrary and
          called address zero.

          THE CRASH WAS THE LUCKY OUTCOME. Ids in the LOWER range go to
          ProcessMenu, which runs a real menu action -- silently, on every
          keystroke that updates an entry field. That is the shape of "it just
          will not log a contact": the program is busy doing something else
          each time you type. *)
        if lParam = 0 then
           begin
           if (LoWord(wParam) >= 10000) and (LoWord(wParam) <= 10700) then
              begin
              ProcessMenu(wParam);
              end;

           (* > 10700, not >= : the two ranges overlapped at exactly 10700, so
              that one id was dispatched BOTH ways. Plugin ids start at
              10700 + LoadedPlugins with LoadedPlugins >= 1, so nothing is
              lost. *)
           if (LoWord(wParam) > 10700) and (LoWord(wParam) <= 10750) then
              begin
              RunPlugin(LoWord(wParam));
              end;
           end;

        // The call and exchange notification arms USED TO BE HERE, dispatched
        // by comparing lParam against wh[mweCall] / wh[mweExchange].  They are
        // OnChange / OnEnter / OnExit on the controls themselves now -- see
        // TTR4WEntryEvents.  Phase 3d.


      end;

  end; {of case}

  if Msg = MMTTY.mmttyMSG then mmttyProcessMessage(wParam, lParam);

  CallDefWindowProc:
  Result := longword(DefWindowProc(TRHWND, Msg, wParam, lParam));
end;

{ NO EXCEPTION MAY LEAVE A WINDOW PROCEDURE, AND THE REASON IS NOT TIDINESS.

  A window procedure is called BY WINDOWS, across a kernel callback boundary.  A
  language exception cannot unwind through that boundary, so Windows does not
  unwind it -- it TERMINATES THE PROCESS with STATUS_FATAL_APP_EXIT
  (0xC000041D).  Nothing runs on the way out: not ExceptProc, not
  Application.OnException, not a finally block.  tr4w.log simply stops.

  That is exactly how the 2026-08-23 startup crash presented (NY4I: "we seem to
  have a fragility issue here").  The Windows Application log recorded TWO codes
  for one death -- 0xE0465043, which is FreePascal's own SEH exception code, and
  0xC000041D, the fatal-callback kill -- so the sequence is not in doubt: Pascal
  raised, the callback boundary refused it, Windows killed us.  The crash
  reporter added earlier the same day could not help: it was never reached.

  So the boundary gets the guard.  Catch, report with a real backtrace, and
  return a defined value.  A message handled badly is a glitch; a message that
  kills the program mid-contest is a lost log.

  THIS IS A BACKSTOP, NOT A LICENCE.  The code below should still not raise, and
  the accessors it calls still guard their own preconditions.  What changes is
  that being wrong about that now costs a log line instead of the operator's
  session. }
(* ============================ RESULTS ARRIVING FROM BACKGROUND THREADS ====

  Each of these runs ON THE MAIN THREAD, handed here by RunOnMainThread. They
  were arms of WindowProc; the bodies are unchanged apart from taking their one
  argument as a parameter instead of digging it out of wParam/lParam.

  They are passed to the async starters BY the code that starts them -- see
  MainUnit and uProgramMain -- so a background unit no longer needs a window
  handle, and this unit no longer needs to know the operation exists. *)

(* aData: 1 = the file saved, 0 = the download failed. *)
procedure PotaDownloadFinished(aData: PtrInt);
begin
   if aData = 1 then
      begin
      if LoadPOTAParks(POTAParksFilePath) > 0 then
         begin
         QuickDisplay(PAnsiChar(TC_POTAPARKSLOADED));
         end
      else
         begin
         QuickDisplay(PAnsiChar(TC_POTAPARKSFILECOULDLOADED));
         end;
      end
   else
      begin
      QuickDisplay(PAnsiChar(TC_POTAPARKSDOWNLOADFAILED));
      end;
end;

(* aData is the parsed TStringList -- ApplyLoadedParks takes ownership. *)
procedure PotaLoadFinished(aData: PtrInt);
begin
   ApplyLoadedParks(aData);
end;

(* aData: 1 = the file saved, 0 = the download failed.

  WHY THIS DOES NOT RELOAD SCP, unlike the CTY handler below.
  ctyLoadInCountryFile is a clean, idempotent reload entry point. TRMASTER has
  no equivalent: LOGSCP loads it LAZILY into a heap index array behind three
  flags (TRMasterFileOpen, IndexArrayAllocated, MasterFileExists) plus a cached
  OperatorNameSet built once, and the only close routine,
  SCPDisableAndDeAllocateFileBuffer, also sets SCPDisabledByApplication -- it
  disables SCP rather than reloading it.

  A partial reload that left OperatorNameSet stale, or SCP disabled, would be
  wrong data during a contest and would look like nothing at all. Telling the
  operator to restart is honest and costs one restart; guessing at TRDOS load
  state is not worth a wrong callsign hint. A proper reload belongs with the
  SQLite log work, not here. *)
procedure TRMasterDownloadFinished(aData: PtrInt);
begin
   if aData = 1 then
      begin
      QuickDisplay(PAnsiChar(TC_TRMASTERDTADOWNLOADEDRESTARTTR4WUS));
      end
   else
      begin
      QuickDisplay(PAnsiChar(TC_TRMASTERDTADOWNLOADFAILED));
      end;
end;

(* aData is the latest CTY.DAT date, or 0 when there is nothing newer.

  ONE VALUE WHERE THERE WERE TWO. The message carried wParam=1/0 alongside the
  date, and wParam=0 only ever came with a date of 0 -- so the date alone says
  it, and there is no pair to get out of step. *)
procedure CTYVersionChecked(aData: PtrInt);
begin
   if aData = 0 then
      begin
      Exit;
      end;

   (* A silent startup notice -- no MessageBox, nothing that blocks. *)
   Format(wsprintfBuffer,
      'Newer CTY.DAT available (dated %d). Press Alt-O to download.',
      aData);
   QuickDisplay(wsprintfBuffer);
end;

(* aData: 1 = the file saved, 0 = the download failed. *)
procedure CTYDownloadFinished(aData: PtrInt);
begin
   if aData = 1 then
      begin
      QuickDisplay(PAnsiChar(TC_CTYDATDOWNLOADEDRELOADING));
      (* RELOADED ON THE MAIN THREAD. The CTY tables have no locking, so a
        background reload would race with callsign lookups; arriving here is a
        safe quiescent point. *)
      ctyLoadInCountryFile(TR4W_CTY_FILENAME, False, True);
      QuickDisplay(PAnsiChar(TC_CTYDATRELOADEDSUCCESSFULLY));
      end
   else
      begin
      QuickDisplay(PAnsiChar(TC_CTYDATDOWNLOADFAILED));
      end;
end;

function WindowProc(TRHWND: HWND; Msg: UINT; wParam: wParam; lParam: lParam): longword; stdcall;
begin
  Result := 0;
  try
     Result := WindowProcBody(TRHWND, Msg, wParam, lParam);
  except
     on E: TObject do
        begin
        LogCaughtException(Format('WindowProc msg $%x', [Msg]), E);
        // DefWindowProc, not 0: for most messages 0 CLAIMS we handled it,
        // which would suppress default behaviour on top of the fault.
        // Letting Windows do its default is the smaller lie.
        Result := longword(DefWindowProc(TRHWND, Msg, wParam, lParam));
        end;
  end;
end;

end.

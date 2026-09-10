unit uMainForm;
{$I ..\..\tr4w.inc}
{
  THE MAIN WINDOW, AS AN LCL FORM.  Phase 3a of the Win32-to-LCL migration.

  BEHAVIOUR-NEUTRAL BY CONSTRUCTION, and that is the whole design of this step.
  tr4whandle stops being the result of CreateWindowExW on TR4W's own registered
  class and becomes a TForm's Handle.  EVERYTHING ELSE IS UNCHANGED: the 43
  child elements are still created by the same placement loop from the same
  TWindows table, still parented to tr4whandle, still painted the same way; the
  hand-rolled GetMessage loop is still running; the accelerator table is still
  applied by TranslateAccelerator.

  Later steps -- not this one -- move the four input-bearing controls onto LCL
  controls (3b) and replace the loop with Application.Run (3c).

  WHY A FORM AT ALL, THIS EARLY.  A raw Win32 child parented to a TForm receives
  Windows messages but generates NO LCL key events, so TForm.KeyPreview and
  Application.AddOnKeyDownBeforeHandler cannot route it.  The input-bearing
  controls therefore have to become LCL controls in the same step that retires
  the loop -- and they cannot become LCL controls until there is a form to put
  them on.  This is that form.

  NOT A DESIGNED .lfm, deliberately.  The main window's layout is a TABLE TIMES
  A RUNTIME SCALE FACTOR: every element is placed at TWindows[e].mweiX * ws,
  where ws derives from the operator's font-size setting, and the vertical
  origin depends on EditableLogHeight, which is MEASURED at run time from the
  ListView.  A designed form would freeze 50 positions at one font size.  So the
  form is created with CreateNew and the placement loop is kept.

  THE ONE OBSERVABLE CHANGE: the window's Win32 CLASS name.  It was 'TR4W'; an
  LCL form's class is 'Window', hardcoded at win32int.pp:240 and used for forms
  at win32wsforms.pp:212 -- LCL's TCreateParams has no WinClassName, so unlike
  the VCL there is no override.  The window's TITLE is unaffected (DisplayContestTitle
  sets it with SetWindowTextA), as are the taskbar entry and everything an
  operator sees.  Only FindWindow('TR4W', nil) from another process would notice.
  NY4I confirmed 2026-08-17 that nothing third-party depends on it.
}

interface

uses
{$IFDEF WINDOWS}
  (* GATED WITH WHAT USES IT (2026-09-08). Both remaining Windows calls in this
    unit are already inside {$IFDEF WINDOWS} -- ShowWindow on the MMTTY engine's
    window, and SetWindowLong to give an entry field a control id for the
    AutoIt-driven UI tests -- but the uses clause was not, so the unit could
    never have compiled off Windows however well its code was gated. That is
    the trap TF's clause already documents: a unit whose CODE is behind
    {$IFDEF WINDOWS} but whose USES clause is not fails on the clause and never
    reaches the code. *)
  Windows,
{$ENDIF}
  Classes, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  Grids,             // TDrawGrid, TGridDrawState -- the possible-call strip
  LCLType,
  LMessages,
  uElementPanel,     // TElementPanel -- the 43 status readouts
  uAnsiStr,          // LclText -- a grid cell holds UTF-8
  uLogGrid,          // TLogGrid -- the editable log is one
  VC,                // TMainWindowElement -- the main window's own elements
  uMainWindowProc;   // TTR4WEntryField, EntryEvents -- the fields' key handlers

type
  { DESIGNED, from uMainForm.lfm.  NY4I, 2026-08-22: forms come from an editor
    file so a person can open them in the designer and change them without
    reading Pascal.

    WHAT THE .lfm OWNS: the form itself -- border, icons, colour, taskbar
    button -- and, from here on, any control added to the main window.

    WHAT IT DOES NOT OWN: the positions of the 50 legacy elements.  Those are
    placed at TWindows[e].mweiX * ws, where ws comes from the operator's
    font-size setting and the vertical origin is measured from the log's height
    at run time.  Freezing them into a designed layout would be a regression.
    A designed control is still REPOSITIONED by that loop; being in the .lfm
    gives it an editable identity, not a fixed geometry. }
  TTR4WMainForm = class(TForm)
    (* POLLS FOR THE TWO THINGS WINDOWS USED TO SEND A MESSAGE ABOUT.

      WM_TIMECHANGE and WM_DISPLAYCHANGE had no cross-platform equivalent, and
      catching them is why a window procedure was subclassed in front of this
      form at all. NY4I, 2026-09-06: "unless there is an alternative cross
      platform way, a timer to check both time and screen info?" *)
    tmrSystemWatch: TTimer;
    { PUBLISHED so the streaming loader finds it in uMainForm.lfm, and so
      Lint-FormFields can check the two agree.  Declared in the designer,
      REPOSITIONED at run time -- see CreateTR4WPossibleCallList. }
    lstPossibleCall: TStringGrid;

    { BEGIN GENERATED MAIN-WINDOW ELEMENT FIELDS -- tools/gen_main_elements.py }
    { DESIGNED, in uMainForm.lfm, so pressing F12 in Lazarus shows them.
      REPOSITIONED at run time from TWindows[] -- see CreateMainElement.

      PUBLISHED so the streaming loader binds each one, and so
      Lint-FormFields can check the .lfm and this list agree. }
    pnlAutoSendCount: TElementPanel;
    pnlBandMode: TElementPanel;
    pnlBeamHeading: TElementPanel;
    pnlClock: TElementPanel;
    pnlCodeSpeed: TElementPanel;
    pnlComputerID: TElementPanel;
    pnlCountryName: TElementPanel;
    pnlCQQSOCounter: TElementPanel;
    pnlCQTotal: TElementPanel;
    pnlCurrentOperator: TElementPanel;
    pnlDate: TElementPanel;
    pnlDupeInfoCall: TElementPanel;
    pnlFootSwitch: TElementPanel;
    pnlFullTime: TElementPanel;
    pnlLocator: TElementPanel;
    pnlHourRate: TElementPanel;
    pnlInsert: TElementPanel;
    pnlLastQSOTime: TElementPanel;
    pnlLocalTime: TElementPanel;
    pnlMasterStatus: TElementPanel;
    pnlNewMultStatus: TElementPanel;
    pnlMultNeedsHeader: TElementPanel;
    pnlName: TElementPanel;
    pnlOnAirTimeCounter: TElementPanel;
    pnlOpMode: TElementPanel;
    pnlPaddle: TElementPanel;
    pnlQSOsWithThisStation: TElementPanel;
    pnlPTTStatus: TElementPanel;
    pnlQSOB4Status: TElementPanel;
    pnlQSONeedsHeader: TElementPanel;
    pnlQSONumber: TElementPanel;
    pnlQuickCommand: TElementPanel;
    pnlRadioOneFreq: TElementPanel;
    pnlRadioOne: TElementPanel;
    pnlRadioTwoFreq: TElementPanel;
    pnlRadioTwo: TElementPanel;
    pnlRate: TElementPanel;
    pnlSPQSOCounter: TElementPanel;
    pnlTenMinuts: TElementPanel;
    pnlTotalScore: TElementPanel;
    pnlUserInfo: TElementPanel;
    pnlWinKey: TElementPanel;
    pnlWSJTX: TElementPanel;
    { END GENERATED MAIN-WINDOW ELEMENT FIELDS }

    { THE EVENT IS THE FORM'S, and is wired in uMainForm.lfm so it is visible in
      the designer.  It delegates to PossibleCallDrawProc, which MainUnit sets:
      the drawing reads PossibleCallList and the colour table, and this unit has
      no business knowing about either.

      Declaring it here also keeps the LCL's own types in the one unit that
      already speaks them.  MainUnit uses both Windows and the LCL, so a method
      signature written there has to name which TRect and which TOwnerDrawState
      it means -- and getting that wrong produces a type error that reads as if
      the signatures were identical, because printed out they are. }
    procedure lstPossibleCallPrepareCanvas(Sender: TObject;
                                           aCol, aRow: integer;
                                           aState: TGridDrawState);
    (* WIRED IN uMainForm.lfm, so they live in the IMPLICIT PUBLISHED REGION --
      everything above the first visibility keyword. The streaming loader
      resolves a handler by NAME through RTTI, and method RTTI exists only for
      published members. The handlers further down are `public` and work
      because they are ASSIGNED IN CODE; nothing looks them up. *)

    (* THE MAIN WINDOW WAS GIVEN FOCUS -- put it in the right entry field.

      Was the WM_SETFOCUS arm of TR4W's own window procedure. OnActivate is the
      LCL's event for it, and is kept correct by the LCL's own focus handling
      in a way WM_SETFOCUS on the form is not: the form's native window and the
      focused CONTROL are different questions. *)
    procedure SystemWatchTick(Sender: TObject);

    procedure MainFormActivate(Sender: TObject);

    (* THE OPERATOR ASKED TO CLOSE THE PROGRAM.

      Was the WM_CLOSE arm, which called ExitProgram(True) and then zeroed Msg
      so DefWindowProc would not destroy the window underneath it. CanClose
      says that to the LCL. *)
    procedure MainFormCloseQuery(Sender: TObject; var CanClose: boolean);

    (* DRAG THE WINDOW BY ITS BODY -- three handlers, and no Win32 at all.

      THE REASON WRITTEN HERE UNTIL 2026-09-07 WAS WRONG, and it was wrong in
      the way that is hardest to catch: it named a real setting that really
      removes a title bar, and that setting does not apply to THIS window.

      `NO CAPTION` is applied in MainUnit.OpenTR4WWindow, so it reaches the
      TOOL windows -- band map, function keys, and the rest. The main form's
      BorderStyle is bsSizeable in the .lfm and nothing overrides it at run
      time, so the main window keeps its caption whatever that setting says.
      (Preferences labels it "Main window has no title bar", which is wrong
      too; docs/BENCH_QUEUE.md has it right, and records that the setting has
      almost certainly never worked at all.)

      WHAT THIS IS, THEN: pre-existing behaviour with no surviving rationale.
      The main window's own Win32 procedure carried `WM_LBUTTONDOWN:
      DragWindow(TRHWND)` right up until it was deleted, and D7 had the same
      arm in DefTR4WProc -- which was the shared procedure for its CAPTIONLESS
      TOOL windows, where it made obvious sense. It looks like it was copied
      onto the main window along with the rest of that procedure.

      It is kept because it is what the program does today and no operator has
      been asked, not because a reason for it has been found. Removing it is a
      decision for NY4I, not a cleanup.

      WAS TF.DragWindow, WHICH POSTED WM_SYSCOMMAND / SC_MOVE. That handed the
      drag to the system's own move loop -- a Win32 idiom inherited from the
      original program, not how an LCL application moves a window (NY4I,
      2026-09-07: "is that the way this is typically done in an LCL
      application?"). It is not; this is.

      Three consequences beyond portability:

        THE SNAP CAME WITH IT. Edge snapping used to be reachable only from
        WMWindowPosChanging, because only the system move loop generated the
        message it hangs on. Both drags now call the same uWindowSnap routine.

        IT CAN BE TESTED. SC_MOVE takes over the mouse, so a body drag could
        not be driven from outside the process at all -- Test-MainWindowEvents
        says so in its own header. Posted mouse messages drive these handlers.

        MOUSE POSITION IS TRACKED IN SCREEN COORDINATES, VIA ClientToScreen
        ON THE EVENT'S OWN X,Y. Two things had to be true at once and only
        this satisfies both.

        SCREEN space, because client space breaks the moment a snap fires:
        the window jumps to the edge, the next MouseMove arrives relative to
        the MOVED window, and the drag walks away from the pointer.

        From the EVENT, not from Mouse.CursorPos, because CursorPos reads the
        physical pointer -- so a drag driven by posted messages would not move
        the window at all, and the harness could only test this by seizing the
        real mouse. ClientToScreen converts using the form's position at the
        instant of the event, which is what makes the result absolute. *)
    procedure MainFormMouseDown(Sender: TObject; Button: TMouseButton;
                                Shift: TShiftState; X, Y: integer);
    procedure MainFormMouseMove(Sender: TObject; Shift: TShiftState;
                                X, Y: integer);
    procedure MainFormMouseUp(Sender: TObject; Button: TMouseButton;
                              Shift: TShiftState; X, Y: integer);

    (* MINIMISED OR RESTORED -- take MMTTY with us.

      Was the WM_SIZE arm, which decoded wParam for SIZE_MINIMIZED and
      SIZE_RESTORED. That is the window STATE, not its size, and WindowState
      says it without decoding anything. *)
    procedure MainFormWindowStateChange(Sender: TObject);
  private
    { Body-drag state. PRIVATE, not published: Lint-FormFields requires every
      published field to have a component behind it, and these are not
      controls. }
    FDragging:       boolean;
    FDragMouseOrigin: TPoint;   // screen position of the pointer when it went down
    FDragFormOrigin:  TPoint;   // Left/Top of the form at that same moment
  public
    (* The editable log's row supply and its double-click. See uLogGrid. *)
    procedure MainLogFetchRows(Sender: TObject; const aFirstIndex: Int64;
                               var aRows: array of TLogGridRow);
    procedure BuildLogGrid;
    procedure BuildDupesGrid;
    procedure DupesFetchRows(Sender: TObject; const aFirstIndex: Int64;
                             var aRows: array of TLogGridRow);
    (* EVERY MENU ITEM'S OnClick.

      Was the WM_COMMAND arm of TR4W's own window procedure -- the last reason
      that procedure was subclassed in front of this form. Each item carries
      its command id in Tag, so one handler serves the whole menu.

      PUBLIC, NOT PUBLISHED: BuildTR4WMainMenu assigns it to 140 items in code,
      so nothing looks it up by name and Lint-FormEvents would report a
      published handler no .lfm wires. *)
    (* EDGE SNAPPING, THROUGH THE LCL'S OWN MESSAGE MAP.

      Was the WM_WINDOWPOSCHANGING arm of a hand-installed window procedure.
      The win32 widgetset already translates that message into
      LM_WINDOWPOSCHANGING carrying the same PWindowPos and delivers it here
      (win32callback.inc), so nothing needs subclassing -- and on a widget set
      that never sends it, this simply never runs. *)
    procedure WMWindowPosChanging(var aMsg: TLMWindowPosMsg);
      message LM_WINDOWPOSCHANGING;

    procedure MenuItemClick(Sender: TObject);

    { Builds the main menu from T_MENU_ARRAY and adopts it. A METHOD, so
      the handler below is named without a qualifier -- see the note there. }
    procedure InstallMenu;

    procedure MainLogDblClick(Sender: TObject);
    procedure MainLogKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure MainLogEnter(Sender: TObject);
    procedure MainLogHeaderSized(Sender: TObject; IsColumn: boolean;
                                 Index: integer);
  end;

(* THE OWNER-DRAW SEAM IS GONE (2026-09-10).

  TPossibleCallDrawProc and PossibleCallDrawProc were how MainUnit painted
  this strip: a procedure variable, a TCanvas, an item index and a
  TOwnerDrawState, because the Win32 original answered WM_DRAWITEM.

  NY4I: "if you touch a piece of code, validate if the code is doing things as
  a native LCL app would do it. If not, change it to such. The way the program
  did it before is immaterial."

  A TStringGrid draws its own Cells. The only thing left that is genuinely
  ours is WHICH COLOURS a cell takes, and the LCL has a hook for exactly that
  -- OnPrepareCanvas, called with the cell and its state, before the text is
  drawn. So there is no painting code, no canvas passed between units, and no
  procedure variable. *)

{ Creates the callsign or exchange entry field as an LCL TEdit and returns its
  HANDLE, which the caller stores in wh[mweCall] / wh[mweExchange] exactly as
  before.

  RETURNING A HANDLE, NOT THE CONTROL, is what makes this step safe on its own.
  Everything in TR4W addresses these fields through wh[] -- SetWindowText,
  focus, the caret, the colour handler -- and the message loop routes keystrokes
  by comparing Msg.HWND against wh[mweCall]. A TEdit's Handle IS that HWND, so
  every one of those paths keeps working unchanged while the control underneath
  becomes an LCL object.

  That is the point of doing it now: the loop still runs, the routing is
  untouched, and the only thing that changed is what kind of object owns the
  window. Phase 3c then moves the keyboard onto this control's own events and
  DELETES the Msg.HWND comparisons -- which it can only do once the control is
  an LCL control able to raise them. }
procedure CreateTR4WEntryField(const aLeft, aTop, aWidth, aHeight: integer;
                               const aId: integer;
                               const aBorder: boolean;
                               const aField: TTR4WEntryField;
                               const aFontName: string = '';
                               const aFontHeight: integer = 0;
                               const aFontBold: boolean = False);

{ Creates the main form and returns its handle, which becomes tr4whandle.
  aMenu is TR4W's own menu, built by CreateTR4WMenu -- CreateWindowExW used to
  take it as a parameter, so it is attached here instead. }
{ Tell the LCL the main window is on screen.

  TR4W SHOWS ITS MAIN WINDOW WITH A RAW SetWindowPos(..., SWP_SHOWWINDOW)
  (OpenOtherWindows), which the LCL cannot see.  A form whose Visible property
  is still False does not show its CHILD CONTROLS -- so the callsign and
  exchange fields were created, sized and positioned correctly and never
  appeared.  NY4I found that on the bench, 2026-08-18; every automated check
  here passed, because a control that exists with the right id at the right
  geometry looks identical to a working one unless something reads its
  Visible flag.  Dump-WindowTree now does.

  Called beside the SetWindowPos rather than replacing it: the raw call still
  does the positioning and z-order the program wants, and this only reconciles
  the LCL's own state with what already happened. }
procedure ShowTR4WMainForm;

{ THE POSSIBLE-CALL LIST.  Phase 3b.

  DESIGNED IN uMainForm.lfm and merely configured here.  It replaces a raw
  CreateWindowExW(LISTBOX, LBS_OWNERDRAWFIXED or LBS_MULTICOLUMN or ...), and the
  two Win32 messages that made that work become properties: WM_MEASUREITEM is
  ItemHeight, WM_DRAWITEM is OnDrawItem -- the mapping docs/ROADMAP.md section 2
  states for exactly this case.

  THE GEOMETRY IS APPLIED HERE, not in the designer, because this control is one
  of the fifty in the TWindows table: its position is a runtime scale factor
  times a table entry, and freezing it would break the operator's font-size
  setting.  Designed identity, runtime placement -- the two are not in conflict
  (NY4I, 2026-08-22).

  RETURNS THE HANDLE, like CreateTR4WEntryField, so wh[mwePossibleCall] keeps
  working and the five LB_* messages the rest of the program sends still land.

  The DRAWING is attached by the caller through TR4WMainForm.lstPossibleCall: it
  reads PossibleCallList and the colour table, which this unit has no business
  knowing about. }
procedure CreateTR4WPossibleCallList(const aLeft, aTop, aWidth, aHeight,
                                     aId, aItemHeight, aColumnWidth: integer);


(* THE EDITABLE LOG -- the contest log on the main window.

  A TLogGrid: an LCL-drawn grid holding no rows, which asks for the record it
  is painting. See uLogGrid.

  IT RETURNS NOTHING. It used to return an HWND, and roughly thirty call sites
  reached the control through wh[mweEditableLog] to set a colour, read the
  header, ask which row was selected or set a column width. Every one of those
  is a routine below now. The handle was not an implementation detail worth
  keeping: one of those sites replaced the control's window style wholesale and
  left the log blank for three sessions. *)
procedure CreateTR4WEditableLog(const aLeft, aTop, aWidth, aHeight: integer);

(* THE ROW COUNT, TAKEN FROM THE LOG ITSELF.

  ONE DEFINITION, because there were two and they could disagree. LoadinLog set
  the grid from LogSourceRecordCount while the logging path set it from
  tRestartInfo.riTotalRecordsInLog -- a counter maintained by hand, in two
  units, and reset to zero by a third. Two numbers for "how many records are in
  the log" is how a freshly logged QSO can shrink the grid instead of growing
  it.

  It also opens the source if something has closed it, so the count and the
  rows come from the same place in the same state. *)
procedure TR4WEditableLogRefreshCount;

(* How many log records exist. Setting it is what makes the log appear. *)
procedure TR4WEditableLogSetCount(const aCount: Int64);

(* Forget cached rows -- after an edit, a rescore or a reload. *)
procedure TR4WEditableLogRefresh;

(* Colours from TWindows[mweEditableLog], and the gridlines setting. *)
procedure TR4WEditableLogApplyColors;
procedure TR4WEditableLogSetGridLines(const aOn: boolean);

(* Where the grid sits, and how tall it ended up. *)
procedure TR4WEditableLogSetBounds(const aLeft, aTop, aWidth, aHeight: integer);
function  TR4WEditableLogBoundsHeight: integer;

(* Put the newest QSO in view, which is where an operator looks. *)
procedure TR4WEditableLogScrollToEnd;

(* The selected row as a LOG RECORD index, or -1. The one definition of that
  mapping; the double-click mismatch came from having had two. *)
function  TR4WEditableLogSelectedRecord: Int64;
procedure TR4WEditableLogSelectRecord(const aIndex: Int64);

procedure TR4WEditableLogFocus;
function  TR4WEditableLogVisible: boolean;
procedure TR4WEditableLogShow(const aVisible: boolean);

(* The callsign in one row, read from the log. *)
function  TR4WEditableLogCallsignAt(const aIndex: Int64): string;

(* PREVIOUS QSOs WITH THE STATION BEING WORKED -- the "B4" list.

  IT SHARES THE EDITABLE LOG'S RECTANGLE and the two swap: showing one hides
  the other. That is what the Win32 version intended.

  IT NEVER WORKED. tPreviousDupeQSOsWndHandle was declared and used and NEVER
  ASSIGNED -- always 0 -- so ListView_DeleteAllItems, tAddContestExchangeToLog
  and ShowWindow were all no-ops on a null handle, and the only thing that did
  happen was the editable log being hidden to make room for a window that did
  not exist. With AUTO DISPLAY DUPE QSO on, working a dupe blanked the log area
  and showed nothing. Found 2026-09-04 while converting it.

  The records are held here rather than re-read: the caller has them in hand
  from its scan, and a handful of dupes is not worth a second pass. *)
procedure TR4WPreviousDupesSet(const aQsos: array of ContestExchange);
procedure TR4WPreviousDupesShow(const aVisible: boolean);
procedure TR4WPreviousDupesSetBounds(const aLeft, aTop, aWidth, aHeight: integer);

(* Builds the main window. It RETURNED ITS HWND until 2026-09-07, for the one
  caller that assigned tr4whandle -- and that global is gone, so the result had
  no reader and the signature was the last thing making this an HWND-shaped
  operation. *)
procedure CreateTR4WMainForm;

var
  { The form itself.  Exposed because Phase 3b parents LCL controls onto it and
    Phase 3c hands it to Application.Run.  Nothing else should need it: the rest
    of the program continues to work in tr4whandle. }
  TR4WMainForm: TTR4WMainForm = nil;
  TR4WCallEdit: TEdit = nil;
  TR4WEditableLog: TLogGrid = nil;

  { The B4 list -- see TR4WPreviousDupesSet.  Created on first use, because a
    contest may never show one. }
  TR4WPreviousDupes: TLogGrid = nil;
  TR4WExchangeEdit: TEdit = nil;

{ THE ENTRY FIELDS.

  Ordinary LCL property access, guarded once rather than per call site.  Two
  hazards make the guard necessary and both are compiler-invisible: these
  objects are NIL on the headless /EXPORT path, and reaching them off the main
  thread is now a crash where the Win32 they replaced was a harmless no-op.
  The full history, and what licensed the conversion, is on the implementation
  side. }
function  EntryText(const aEdit: TEdit): string;
procedure SetEntryText(const aEdit: TEdit; const aText: string);
procedure SetEntrySel(const aEdit: TEdit; const aStart, aLength: integer);
function  EntrySelStart(const aEdit: TEdit): integer;
function  EntrySelLength(const aEdit: TEdit): integer;
procedure FocusEntry(const aEdit: TEdit;
                     const aBringForward: boolean = False);
procedure SetEntryColors(const aEdit: TEdit; const aBack, aText: TColor);


{ ---------------------------------------------------------------------------
  THE MAIN WINDOW'S OWN ELEMENTS.

  Forty-two of the fifty TMainWindowElement entries were raw Win32 STATIC
  controls, created by one loop in CreateMainWindow from the metadata in
  TWindows[] and painted by TR4W's WM_CTLCOLORSTATIC handler.  They are LCL
  TPanels now, held here, one per element.

  A TPanel RATHER THAN A TLabel, because a Win32 static in this program is not
  just text: defStyle is SS_CENTER or SS_SUNKEN, and DefStyleDis adds
  WS_DISABLED.  A panel has all three -- Alignment, BevelOuter and Enabled --
  where a label would need a container for the border.

  STILL CREATED IN CODE, NOT IN THE .lfm, and deliberately: their positions come
  from TWindows[] in character cells scaled by `ws`, which changes with the
  font.  A designed layout would have to duplicate that table, and the table is
  what the rest of the program reads.  See the note on the form class above. }
(* Binds the designed panels to their elements. Called once, by
  CreateTR4WMainForm. *)
procedure BindMainElements;

procedure CreateMainElement(const aElement: TMainWindowElement;
                            const aStyle: cardinal;
                            const aLeft, aTop, aWidth, aHeight: integer);
function  MainElement(const aElement: TMainWindowElement): TPanel;
procedure SetElementText(const aElement: TMainWindowElement; const aText: string);
procedure SetElementColors(const aElement: TMainWindowElement;
                           const aBack, aText: TColor);
procedure ShowElement(const aElement: TMainWindowElement; const aVisible: boolean);
procedure EnableElement(const aElement: TMainWindowElement; const aEnabled: boolean);
procedure SetElementLeft(const aElement: TMainWindowElement; const aLeft: integer);
procedure SetElementBounds(const aElement: TMainWindowElement;
                           const aLeft, aTop, aWidth, aHeight: integer);
{ The fonts are built with tCreateFont and handed round as HFONTs; an LCL
  control paints its caption from its own TFont, so the SHAPE is passed rather
  than the handle. }
procedure SetElementFont(const aElement: TMainWindowElement;
                         const aName: string; const aHeight: integer;
                         const aBold: boolean);

(* Decide which window edge every control on the main window holds to, so the
  window can be resized. Called once, after the layout is built. *)
(* Put the main window back where -- and at what height -- it was left.
  Reads the rect FindAndSaveRectOfAllWindows wrote. *)
procedure RestoreMainWindowBounds(const aSaved: TRect);

(* Let the operator resize the main window vertically. Width is pinned:
  see the note at the call site.

  BOTH FIGURES ARE CLIENT SIZES. The width was an OUTER size until 2026-09-09;
  see the body for what that cost. *)
procedure MakeMainWindowResizeable(const aClientWidth, aClientHeight: integer);

procedure AnchorMainWindowControls;

(* THE THREE PROGRESS BARS, AND THE TOUR-DURATION READOUT BESIDE ONE OF THEM.

  Designed TProgressBars now, where they were msctls_progress32 windows driven
  by PBM_* messages from LOGWIND. Every message had a property:

     PBM_SETPOS       -> Position          PBM_SETRANGE   -> Max
     PBM_SETSTEP      -> Step              PBM_SETMARQUEE -> Style pbstMarquee

  THE TWO THAT DID NOT ARE PBM_SETBARCOLOR AND PBM_SETBKCOLOR, and they were
  already doing nothing: tr4w.lpr ships a manifest asking for comctl32 version
  6, and under visual styles the common control IGNORES both and draws in the
  theme colour. The red and blue those calls asked for have not been on screen
  for as long as the manifest has. Dropped rather than reimplemented, because
  reimplementing them means owner-drawing the bar.

  ALSO GONE: a SetWindowLong(GWL_STYLE) pair that switched the tour bar in and
  out of marquee mode by rewriting its window style wholesale. That is the same
  move that blanked the log grid for three sessions -- see uLogGrid. *)
type
   TMainProgressBar = (mpbLastHour, mpbRate, mpbTourDuration);

procedure SetProgressBounds(const aBar: TMainProgressBar;
                            const aLeft, aTop, aWidth, aHeight: integer);
procedure SetProgressMax(const aBar: TMainProgressBar; const aMax: integer);
procedure SetProgressPosition(const aBar: TMainProgressBar; const aValue: integer);
procedure SetProgressMarquee(const aBar: TMainProgressBar; const aOn: boolean);
procedure ShowProgressBar(const aBar: TMainProgressBar; const aVisible: boolean);

procedure SetTourDurationBounds(const aLeft, aTop, aWidth, aHeight: integer);
procedure SetTourDurationText(const aText: TCaption);
procedure ShowTourDurationText(const aVisible: boolean);

{ THREE THINGS THAT USED TO BE INJECTED KEYSTROKES.

  Each was a PostMessage into an entry field's window -- a space, the
  start-sending key, a paste -- and the POST was doing real work: it deferred
  the action until the message being handled had finished.  Calling the same
  code directly instead would run it INSIDE the current key or click, which is a
  reentrancy change, not a syntax one.

  So the deferral is kept, through Application.QueueAsyncCall, which is what
  this program already uses to hand work to the main loop (see uPanelUpdate).
  What goes away is the pretence that a synthetic keystroke is being typed. }
{ Put a call into the call field FROM ANY THREAD, caret at the end.
  MainUnit.PutCallToCallWindow uses this when it is not on the main thread. }
procedure QueuePutCallToCallField(const aCall: string);

{ Clear both entry fields and return focus to the call field, FROM ANY THREAD.
  The "ready for the next QSO" gesture; uWSJTX's two copies of it call this. }
procedure QueueClearCallAndFocus;

procedure QueueAppendSpaceToExchange;
procedure QueueStartSendingKey(const aKey: AnsiChar);
procedure QueuePasteIntoCallField;

{ The possible-call strip -- a TStringGrid, and it HOLDS THE CALLSIGNS.

  It was an owner-drawn listbox holding N empty strings, with the text living
  in a global the paint handler indexed by item position. See the
  implementation for what that cost. }
procedure ClearPossibleCalls;
{ Appends one candidate and returns its index, or -1 when there is no strip.
  The CALLSIGN goes in; the control holds it. }
function  AddPossibleCall(const aCall: string;
                          const aDupe: boolean): integer;
function  PossibleCallCount: integer;
function  SelectedPossibleCall: integer;
procedure SelectPossibleCall(const aIndex: integer);
procedure PossibleCallsUpdated;
{ The list draws its own items, so it paints from its own TFont -- tWM_SETFONT
  on the handle would be ignored.  Same three numbers tCreateFont was given. }
procedure SetPossibleCallFont(const aName: string; const aHeight: integer;
                              const aBold: boolean);

implementation

{$R *.lfm}

uses
   // IMPLEMENTATION-section, so these are not imposed on anything that uses
   // this unit and a cycle back to here is legal.
   //
   LOGSUBS2,           // ExitProgram -- the close path, see MainFormCloseQuery
   uWindowSnap,        // SnapWindowToEdges -- shared by both drag paths
   uFunctionKeys,      // ShowFMessages -- the F-key strip, on activate
   uMMTTY,             // MMTTY.MMTTYEngine -- see MainFormWindowStateChange
   Menus,              // TMenuItem -- the menu is a TMainMenu now
   uMenu,              // BuildTR4WMainMenu -- the menu from T_MENU_ARRAY
   uSystemWatch,       // the clock/display poll -- see SystemWatchTick
   uGetServerLog,      // the headless-sync state
   SysUtils,           // UpperCase
   uCrashLog,          // OnMainThread / ReportOffMainThread / LogCaughtException
   (* Grids moved to the INTERFACE clause -- lstPossibleCall is a TDrawGrid
      and a published field's type has to be visible there. It was here
      for TGridOptions (TR4WEditableLogSetGridLines). *)
   uMainThreadWork,    // RequestMainThreadJob -- the colour sweep, coalesced
   uLogSource,         // the virtual log list reads through the seam
   uConfigValues,      // Config.ShowGridLines
   MainUnit;           // LogRowTextFor, Config -- see CreateTR4WEditableLog

(* WHY THIS FORM'S MESSAGE HANDLERS ARE KEYED ON LM_, NOT WM_.

  TR4W used to put its own window procedure in front of the LCL's on this
  form's HWND, so it could answer nine raw Win32 messages. The subclass is
  gone -- all nine are ordinary LCL events or an LCL message handler, and the
  list of where each one went is beside the routines they replaced, further
  down. The REASON the subclass existed is kept, because it is why the
  replacement is shaped the way it is.

  THE LCL RENAMES MESSAGES BEFORE ANY FORM SEES THEM. The first attempt at
  this overrode TWinControl.WndProc and matched TLMessage.msg against the
  Win32 numbers:

    WM_CLOSE   arrives as LM_CLOSEQUERY                (win32callback.inc:2094)
    WM_COMMAND arrives as CN_COMMAND via Perform, for a raw HMENU        (:2205)

  and WM_DRAWITEM, WM_MEASUREITEM, WM_CTLCOLOR* and WM_LBUTTONDOWN are
  consumed by the widgetset's own handlers on the way past. A test keyed on
  the Win32 numbers therefore never matched: TR4W's menu did nothing, the
  program could not be closed and had to be killed, and owner-drawn parts of
  the main window were drawn by the wrong code.

  Found on the bench by NY4I, 2026-08-18. No gate caught it -- the smoke
  runner asserts only that the process SURVIVED a command, which a program
  that refuses to exit does very well indeed.

  So WMWindowPosChanging below is declared `message LM_WINDOWPOSCHANGING`,
  which is the name the widgetset actually delivers. Everything else is a
  published event, which cannot be got wrong this way at all. *)
type
   { AN ELEMENT OPERATION THAT ARRIVED ON THE WRONG THREAD.  See the note on
     ElementOnMainThread for why this exists. }
   TElementOp = (eoText, eoShow, eoEnable, eoColors);

   PElementWork = ^TElementWork;
   TElementWork = record
      Op: TElementOp;
      Element: TMainWindowElement;
      Text: string;
      Flag: boolean;
      Back, Fore: TColor;   // eoColors only
   end;

function ControlUsable(const aCtrl: TWinControl): boolean; forward;

{ Defined with the deferred actions further down, because that is where the
  queue it uses lives.  Called by the three element accessors above it. }
function ElementOnMainThread(const aOp: TElementOp;
                             const aElement: TMainWindowElement;
                             const aText: string; const aFlag: boolean;
                             const aCaller: CodePointer): boolean; forward;

{ The colour accessor's arm of the same guard.  Separate because colours are two
  TColors rather than a string and a flag, and widening the shared signature to
  carry four payload arguments for the sake of one caller reads worse than this. }
function ElementOnMainThreadColors(const aElement: TMainWindowElement;
                                   const aBack, aFore: TColor;
                                   const aCaller: CodePointer): boolean; forward;

{ ---------------------------------------------------------------------------
  THE ELEMENT CONTROLS.
  --------------------------------------------------------------------------- }

var
   { BEGIN GENERATED MAIN-WINDOW ELEMENT MAP -- tools/gen_main_elements.py }
   { Each element and the component that shows it.  Generated from the same
     table as the .lfm, so a row added to TWindows[] cannot reach one and
     miss the other. }
   ELEMENT_COMPONENTS: array[0 .. 42] of
      record
         Element: TMainWindowElement;
         Name:    string;
      end = (
      (Element: mweAutoSendCount; Name: 'pnlAutoSendCount'),
      (Element: mweBandMode; Name: 'pnlBandMode'),
      (Element: mweBeamHeading; Name: 'pnlBeamHeading'),
      (Element: mweClock; Name: 'pnlClock'),
      (Element: mweCodeSpeed; Name: 'pnlCodeSpeed'),
      (Element: mweComputerID; Name: 'pnlComputerID'),
      (Element: mweCountryName; Name: 'pnlCountryName'),
      (Element: mweCQQSOCounter; Name: 'pnlCQQSOCounter'),
      (Element: mweCQTotal; Name: 'pnlCQTotal'),
      (Element: mweCurrentOperator; Name: 'pnlCurrentOperator'),
      (Element: mweDate; Name: 'pnlDate'),
      (Element: mweDupeInfoCall; Name: 'pnlDupeInfoCall'),
      (Element: mweFootSwitch; Name: 'pnlFootSwitch'),
      (Element: mweFullTime; Name: 'pnlFullTime'),
      (Element: mweLocator; Name: 'pnlLocator'),
      (Element: mweHourRate; Name: 'pnlHourRate'),
      (Element: mweInsert; Name: 'pnlInsert'),
      (Element: mweLastQSOTime; Name: 'pnlLastQSOTime'),
      (Element: mweLocalTime; Name: 'pnlLocalTime'),
      (Element: mweMasterStatus; Name: 'pnlMasterStatus'),
      (Element: mweNewMultStatus; Name: 'pnlNewMultStatus'),
      (Element: mweMultNeedsHeader; Name: 'pnlMultNeedsHeader'),
      (Element: mweName; Name: 'pnlName'),
      (Element: mweOnAirTimeCounter; Name: 'pnlOnAirTimeCounter'),
      (Element: mweOpMode; Name: 'pnlOpMode'),
      (Element: mwePaddle; Name: 'pnlPaddle'),
      (Element: mweQSOsWithThisStation; Name: 'pnlQSOsWithThisStation'),
      (Element: mwePTTStatus; Name: 'pnlPTTStatus'),
      (Element: mweQSOB4Status; Name: 'pnlQSOB4Status'),
      (Element: mweQSONeedsHeader; Name: 'pnlQSONeedsHeader'),
      (Element: mweQSONumber; Name: 'pnlQSONumber'),
      (Element: mweQuickCommand; Name: 'pnlQuickCommand'),
      (Element: mweRadioOneFreq; Name: 'pnlRadioOneFreq'),
      (Element: mweRadioOne; Name: 'pnlRadioOne'),
      (Element: mweRadioTwoFreq; Name: 'pnlRadioTwoFreq'),
      (Element: mweRadioTwo; Name: 'pnlRadioTwo'),
      (Element: mweRate; Name: 'pnlRate'),
      (Element: mweSPQSOCounter; Name: 'pnlSPQSOCounter'),
      (Element: mweTenMinuts; Name: 'pnlTenMinuts'),
      (Element: mweTotalScore; Name: 'pnlTotalScore'),
      (Element: mweUserInfo; Name: 'pnlUserInfo'),
      (Element: mweWinKey; Name: 'pnlWinKey'),
      (Element: mweWSJTX; Name: 'pnlWSJTX')
      );
   { END GENERATED MAIN-WINDOW ELEMENT MAP }

   GElements: array[TMainWindowElement] of TElementPanel;

   { Bound by BindMainElements from uMainForm.lfm, alongside the elements. }
   GProgressBars: array[TMainProgressBar] of TProgressBar;
   GTourDurationText: TElementPanel;


function MainElement(const aElement: TMainWindowElement): TPanel;
begin
   Result := GElements[aElement];
end;

function ElementUsable(const aElement: TMainWindowElement): boolean;
begin
   Result := ControlUsable(GElements[aElement]);
end;

(* THE ELEMENT'S PANEL -- FOUND, NOT CREATED.

  IT USED TO BUILD ONE HERE. Every status readout on the main window was a
  TPanel constructed at run time, which is why opening tr4w.lpi and pressing
  F12 showed an empty form: there was nothing in the .lfm to show. NY4I,
  2026-09-04: "I should be able to open Lazarus and hit F12 to see the main
  form. Then I will see each item as a LCL control that I could change
  something if I so desired."

  They are designed components now -- 43 of them, generated into uMainForm.lfm
  from the same TWindows[] table this routine reads, by
  tools/gen_main_elements.py. BindMainElements matches each one to its element
  once, and this applies the style and the bounds exactly as before.

  NOTHING ABOUT THE RUNTIME LAYOUT CHANGES. The .lfm carries those positions
  computed at the default scale, purely so the designer shows something
  recognisable; the real placement is still TWindows[e].mweiX * ws with ws
  following the operator's font size. That is what keeps CLAUDE.md's note --
  "freezing them into a designed layout would be a regression" -- true: nothing
  is frozen. *)
(* NO HANDLE IS RETURNED, AND NONE IS CREATED.

  This used to end `Result := p.Handle`, which the caller stored in wh[]. That
  array is written for every element and READ BY NOTHING -- measured 2026-09-05,
  its only live readers are the server log's list view (CreateListView and
  LOGWIND.SetListViewColor), which fills its own entries.

  Touching Handle is not a read, it is a CONSTRUCTION: it forces the window into
  existence there and then. Doing that for 110 panels at startup, to populate an
  array nobody consults, is work the operator pays for on every launch. The LCL
  creates each handle when the form is shown, which is when it is needed. *)
procedure CreateMainElement(const aElement: TMainWindowElement;
                           const aStyle: cardinal;
                           const aLeft, aTop, aWidth, aHeight: integer);
var
   p: TPanel;
begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   p := GElements[aElement];
   if p = nil then
      begin
      (* A ROW IN TWindows[] WITH NO COMPONENT. Regenerating the .lfm fixes it;
        saying so is better than silently drawing nothing, which is what the
        Win32 version did for the previous-dupe window for years. *)
      if logger <> nil then
         begin
         logger.Error('[MainWindow] element %d has no designed component -- ' +
                      'run tools/gen_main_elements.py', [Ord(aElement)]);
         end;
      Exit;
      end;

   (* THE WIN32 STYLE BITS, ONE AT A TIME. Every one of them has a property,
     which is the whole reason this control is not painted by a
     WM_CTLCOLORSTATIC handler.

       SS_SUNKEN    -> BevelOuter bvLowered
       SS_CENTER    -> Alignment taCenter, SS_LEFT -> taLeftJustify
       WS_VISIBLE   -> Visible (uVisStyle omits it; those elements start hidden)
       WS_DISABLED  -> Enabled False (DefStyleDis)
       SS_NOPREFIX  -> no counterpart needed: a TPanel caption is not an
                       accelerator string, so there is no '&' to suppress. *)
   if (aStyle and SS_SUNKEN) <> 0 then
      begin
      p.BevelOuter := bvLowered;
      end
   else
      begin
      p.BevelOuter := bvNone;
      end;

   if (aStyle and SS_CENTER) <> 0 then
      begin
      p.Alignment := taCenter;
      end
   else
      begin
      p.Alignment := taLeftJustify;
      end;

   p.Caption := '';
   p.ParentColor := False;
   p.ParentFont := False;

   (* AutoSize BEFORE SetBounds. LCL controls autosize by default and a
     streamed or assigned size is silently overridden; this tree has paid for
     that once already (see CreateTR4WEntryField). *)
   p.AutoSize := False;
   p.SetBounds(aLeft, aTop, aWidth, aHeight);

   p.Enabled := (aStyle and WS_DISABLED) = 0;
   p.Visible := (aStyle and WS_VISIBLE) <> 0;
end;

(* MATCH EVERY DESIGNED PANEL TO ITS ELEMENT, ONCE.

  By NAME, from the generated table, because a component streamed from a .lfm
  is reached through FindComponent -- the published field is assigned by the
  loader, but the ELEMENT it belongs to is knowledge only TWindows[] has.

  Reported rather than assumed: a missing component means the .lfm and the
  table have diverged, and the next thing that happens is a status readout
  that never updates and nothing to say why. *)
(* THE FIVE LIVE COLOUR RULES, RE-EVALUATED AFTER A CAPTION CHANGE.

  ALWAYS AS A JOB, never called straight through, and that is an improvement on
  what WriteMainWindowText did rather than a copy of it. Jobs COALESCE: the
  element-initialisation loop writes forty-three captions and gets ONE colour
  sweep out of it, where the old path ran forty-three. It is also the answer
  for a write that arrives off the main thread, which the old path had to test
  for separately. *)
procedure RequestElementColourRefresh;
begin
   RequestMainThreadJob(mtMainWindowElementColors);
end;

(* uCrashLog's reporter, in the shape uElementPanel asks for. *)
procedure ReportElementOffThread(const aSite: string; const aCaller: CodePointer);
begin
   ReportOffMainThread(aSite, aCaller);
end;

(* A PANEL WHOSE CAPTION WILL NOT FIT AT ANY READABLE SIZE.

  Names the panel, what it holds, the font actually in use, and the two widths
  -- because "text is touching the border" is a symptom and "needs 214px, has
  180px, font Liberation Sans" is a diagnosis.

  THE FONT NAME IS THE INTERESTING PART. TR4W asks for 'Arial' (VC.pas), which
  a typical Linux box does not have, so fontconfig substitutes something whose
  metrics differ from every width this program computed on Windows. If the
  reports name a substituted font, that is where to look first. *)
procedure ReportElementOverflow(const aPanel, aCaption, aFont: string;
                                const aWanted, aAvailable: integer);
begin
   (* THE TWO NUMBERS ARE THE DIAGNOSIS. "needs 61px, has 30px" says the cell
     is half the width its text requires, which no font substitution and no
     shrinking will fix -- and it distinguishes that from "needs 32, has 30",
     which a couple of pixels of padding would solve. *)
   logger.Warn('[Layout] %s had to shrink to fit: wants %dpx at full size, '
               + 'has %dpx, font "%s", text "%s"',
               [aPanel, aWanted, aAvailable, aFont, aCaption]);
end;

procedure BindMainElements;
var
   i: integer;
   c: TComponent;
begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   for i := Low(ELEMENT_COMPONENTS) to High(ELEMENT_COMPONENTS) do
      begin
      c := TR4WMainForm.FindComponent(ELEMENT_COMPONENTS[i].Name);

      if c is TElementPanel then
         begin
         GElements[ELEMENT_COMPONENTS[i].Element] := TElementPanel(c);
         end
      else
         begin
         GElements[ELEMENT_COMPONENTS[i].Element] := nil;
         if logger <> nil then
            begin
            logger.Error('[MainWindow] uMainForm.lfm has no TElementPanel named %s -- ' +
                         'run tools/gen_main_elements.py',
                         [ELEMENT_COMPONENTS[i].Name]);
            end;
         end;
      end;

   GProgressBars[mpbLastHour] := TProgressBar(TR4WMainForm.FindComponent('pbLastHour'));
   GProgressBars[mpbRate] := TProgressBar(TR4WMainForm.FindComponent('pbRate'));
   GProgressBars[mpbTourDuration] :=
      TProgressBar(TR4WMainForm.FindComponent('pbTourDuration'));
   GTourDurationText :=
      TElementPanel(TR4WMainForm.FindComponent('pnlTourDuration'));
end;

function ProgressBarOf(const aBar: TMainProgressBar): TProgressBar;
begin
   Result := GProgressBars[aBar];
   if not ControlUsable(Result) then
      begin
      Result := nil;
      end;
end;

procedure SetProgressBounds(const aBar: TMainProgressBar;
                            const aLeft, aTop, aWidth, aHeight: integer);
var
   p: TProgressBar;
begin
   p := ProgressBarOf(aBar);
   if p <> nil then
      begin
      p.SetBounds(aLeft, aTop, aWidth, aHeight);
      end;
end;

procedure SetProgressMax(const aBar: TMainProgressBar; const aMax: integer);
var
   p: TProgressBar;
begin
   p := ProgressBarOf(aBar);
   if p <> nil then
      begin
      p.Max := aMax;
      end;
end;

procedure SetProgressPosition(const aBar: TMainProgressBar; const aValue: integer);
var
   p: TProgressBar;
begin
   p := ProgressBarOf(aBar);
   if p = nil then
      begin
      Exit;
      end;

   (* CLAMPED, because PBM_SETPOS was. The common control silently pinned a
     value outside its range; TProgressBar.Position raises nothing either, but
     the LCL stores what it is given and a later Max change would show it. The
     callers pass live rates and hour counts, which do exceed the range. *)
   if aValue < p.Min then
      begin
      p.Position := p.Min;
      end
   else if aValue > p.Max then
      begin
      p.Position := p.Max;
      end
   else
      begin
      p.Position := aValue;
      end;
end;

procedure SetProgressMarquee(const aBar: TMainProgressBar; const aOn: boolean);
var
   p: TProgressBar;
begin
   p := ProgressBarOf(aBar);
   if p = nil then
      begin
      Exit;
      end;

   if aOn then
      begin
      p.Style := pbstMarquee;
      end
   else
      begin
      p.Style := pbstNormal;
      end;
end;

procedure ShowProgressBar(const aBar: TMainProgressBar; const aVisible: boolean);
var
   p: TProgressBar;
begin
   p := ProgressBarOf(aBar);
   if p <> nil then
      begin
      p.Visible := aVisible;
      end;
end;

procedure RestoreMainWindowBounds(const aSaved: TRect);
var
   r: TRect;
begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   r := TR4WMainForm.BoundsRect;

   (* A SAVED RECT WITH NO SIZE IS A FIRST RUN, or a file written before the
     window could be resized -- keep the laid-out height in that case rather
     than collapsing the window to nothing. *)
   r.Left := aSaved.Left;
   r.Top := aSaved.Top;

   if (aSaved.Bottom - aSaved.Top) > 0 then
      begin
      r.Bottom := r.Top + (aSaved.Bottom - aSaved.Top);
      end
   else
      begin
      r.Bottom := r.Top + TR4WMainForm.Height;
      end;

   (* WIDTH IS THE LAYOUT'S, NEVER THE FILE'S -- Constraints pin it, and
     handing the LCL a width it will refuse just makes the two disagree. *)
   r.Right := r.Left + TR4WMainForm.Width;

   TR4WMainForm.BoundsRect := r;
end;

(* EVERY CHILD THAT STICKS OUT OF THE CLIENT AREA, NAMED AND MEASURED.

  TWO SYMPTOMS ON NY4I'S MINT BOX POINT AT THE SAME QUESTION and neither can be
  answered from a screenshot: content running into the window border, and a
  horizontal scroll bar appearing "for no apparent reason". A form with
  AutoScroll on grows one the moment a child extends past the client area, so
  the scroll bar is not a separate defect to chase -- it is the layout
  reporting an overhang in the only way a widget set can.

  WHICH CHILD, AND BY HOW MANY PIXELS, is the thing nobody knows. This walks
  the form's immediate children once, after the layout is built, and names any
  whose right or bottom edge is outside the client rectangle.

  ONE LINE PER OFFENDER AND A COUNT, so a clean window costs a single line.
  Written as a diagnostic on purpose: what the fix is -- a wider window,
  narrower content, or a font that measures like the one this program was
  designed against -- depends on which controls report and by how much. *)
(* Last reported state, so the report above fires on a CHANGE rather than
  every two seconds. *)
var
   GLastHorzScroll: boolean = False;

procedure ReportMainWindowOverhang;
var
   i:       integer;
   c:       TControl;
   cw, ch:  integer;
   found:   integer;
begin
   if (TR4WMainForm = nil) or (logger = nil) then
      begin
      Exit;
      end;

   cw := TR4WMainForm.ClientWidth;
   ch := TR4WMainForm.ClientHeight;
   found := 0;

   for i := 0 to TR4WMainForm.ControlCount - 1 do
      begin
      c := TR4WMainForm.Controls[i];

      if not c.Visible then
         begin
         Continue;
         end;

      if ((c.Left + c.Width) > cw) or ((c.Top + c.Height) > ch) then
         begin
         Inc(found);
         logger.Warn('[Layout] %s "%s" is outside the client area: ' +
                     'right %d of %d, bottom %d of %d',
                     [c.ClassName, c.Name,
                      c.Left + c.Width, cw,
                      c.Top + c.Height, ch]);
         end;
      end;

   logger.Info('[Layout] %d of %d child control(s) extend past the client ' +
               'area (%dx%d)',
               [found, TR4WMainForm.ControlCount, cw, ch]);
end;

(* EVERY VISIBLE CHILD, WITH ITS CLASS AND ITS BOUNDS, ONCE.

  BECAUSE A SCREENSHOT GIVES A POSITION AND NOTHING ELSE. NY4I has pointed at
  the same artifact five times -- a scroll-bar-shaped band directly under the
  editable log -- and I have now named the wrong control for it TWICE,
  including one he had already corrected: "That is absolutely not. The
  possible calls are under the exchange window. That is the second time you
  have made that assumption in so many days."

  He is right, and the arithmetic says so: CreateTR4WPossibleCallList is
  placed at EditableLogHeight + ws * 13, which is six rows BELOW the bottom of
  the log, down among the status panels. Nothing about it is under the log.

  SO STOP READING GEOMETRY OUT OF THE SOURCE AND ASK THE RUNNING PROGRAM. One
  line per control, at DEBUG so it costs nothing in a contest, listing exactly
  what a screenshot can be measured against: class, name, left, top, width,
  height. Whatever is sitting at the log's bottom edge will be in this list
  with a Top that matches, and there will be no interpretation involved. *)
procedure DumpMainWindowChildren;
var
   i: integer;
   c: TControl;
begin
   if (TR4WMainForm = nil) or (logger = nil) then
      begin
      Exit;
      end;

   if not logger.IsDebugEnabled then
      begin
      Exit;
      end;

   logger.Debug('[Layout] --- main window children, client %dx%d ---',
                [TR4WMainForm.ClientWidth, TR4WMainForm.ClientHeight]);

   for i := 0 to TR4WMainForm.ControlCount - 1 do
      begin
      c := TR4WMainForm.Controls[i];

      logger.Debug('[Layout]   %-18s %-22s L=%4d T=%4d W=%4d H=%4d vis=%s',
                   [c.ClassName, c.Name, c.Left, c.Top, c.Width, c.Height,
                    BoolToStr(c.Visible, True)]);
      end;

   (* AND THE LOG GRID'S INTERNALS, because the band NY4I is pointing at is
     INSIDE it: the grid bottom and the status-panel row below meet exactly,
     at y=244 on his machine, so there is no gap between them to show. A grid
     whose client height is not a whole number of rows has dead space at the
     bottom, and that is the only place left for it to be. *)
   if TR4WEditableLog <> nil then
      begin
      logger.Debug('[Layout]   editable log: H=%d client=%d rowH=%d rows=%d ' +
                   'fixed=%d -> content=%d, leftover=%d',
                   [TR4WEditableLog.Height, TR4WEditableLog.ClientHeight,
                    TR4WEditableLog.DefaultRowHeight,
                    TR4WEditableLog.RowCount, TR4WEditableLog.FixedRows,
                    TR4WEditableLog.RowCount * TR4WEditableLog.DefaultRowHeight,
                    TR4WEditableLog.ClientHeight -
                      (TR4WEditableLog.RowCount * TR4WEditableLog.DefaultRowHeight)]);
      end;

   if TR4WEditableLog <> nil then
      begin
      logger.Debug('[EditableLog] Paint saw: calls=%d client=%d rowH=%d ' +
                   'rows=%d gridHeight=%d drawn=%d',
                   [TR4WEditableLog.PaintCount, TR4WEditableLog.PaintClient,
                    TR4WEditableLog.PaintRowH, TR4WEditableLog.PaintRows,
                    TR4WEditableLog.PaintGrid, TR4WEditableLog.PaintDrawn]);
      end;

   logger.Debug('[Layout] --- end children ---');
end;

(* WHERE IS THE HORIZONTAL SCROLL BAR COMING FROM.

  NY4I has reported one four times -- "still have a horizontal scroll bar for
  no reason" -- and I have now been wrong about it twice, which is why this is
  a probe rather than another change.

  WHAT HAS ALREADY BEEN RULED OUT, so nobody re-checks it:

    * A child hanging off the client area. ReportMainWindowOverhang says 0 of
      118, measured on the Mint box.
    * The editable log and the B4 list. Both are TLogGrid with ssAutoVertical,
      and TCustomGrid.GetSBVisibility (grids.pas:5329) can only raise a
      horizontal bar when FScrollBars is ssHorizontal, ssBoth or ssAutoBoth.
    * The possible-call strip. It was a TListBox and is now a TDrawGrid with
      ScrollBars = ssNone.

  SO ASK THE FORM ITSELF, EVERY TICK, AND REPORT ONLY WHEN THE ANSWER CHANGES.
  A TForm with AutoScroll on grows a bar when its content is wider than its
  client, and that content can arrive LONG after the layout ran -- a control
  created on first use, or one moved by a later resize -- which is exactly the
  window ReportMainWindowOverhang, running once at startup, cannot see.

  The widest child is named, because "there is a scroll bar" is not a
  diagnosis and "pnlWhatever ends at 812 in a 782 client" is. *)
procedure ReportHorizontalScroll;
var
   i:       integer;
   c:       TControl;
   right:   integer;
   widest:  integer;
   name_:   string;
   visible: boolean;
begin
   if (TR4WMainForm = nil) or (logger = nil) then
      begin
      Exit;
      end;

   (* IsScrollBarVisible IS A WIN32 AND QT ANSWER ONLY, AND THIS PROBE WAS
     BLIND FOR IT.

     It asks the widget set through GetScrollbarVisible, and the base
     implementation is

         function TWidgetSet.GetScrollbarVisible(...): boolean;
         begin
           Result := false;
         end;

     -- intfbaselcl.inc:430. win32, qt, qt5, qt6 and customdrawn override it.
     GTK DOES NOT. So on gtk2 this returned False whatever was on screen, and a
     probe written to answer "is there a scroll bar" answered "no" six times
     while NY4I was looking at one. The LCL knows the call is trouble there:
     grids.pas:3529 says "Don't use GetScrollbarvisible from the widgetset --
     it sends WM_PAINT message (Gtk2). Issue #30160".

     THE LCL-SIDE VALUES ARE READABLE EVERYWHERE, so ask those instead: Visible
     is the switch, and a non-zero Range wider than the Page is what raises a
     bar. That is the state the program controls and can be held to. *)
   visible := TR4WMainForm.HorzScrollBar.Visible and
              (TR4WMainForm.HorzScrollBar.Range >
               TR4WMainForm.HorzScrollBar.Page);

   if visible = GLastHorzScroll then
      begin
      Exit;
      end;
   GLastHorzScroll := visible;

   if not visible then
      begin
      logger.Info('[Layout] the main window''s horizontal scroll bar is gone.');
      Exit;
      end;

   widest := 0;
   name_  := '(none)';

   for i := 0 to TR4WMainForm.ControlCount - 1 do
      begin
      c := TR4WMainForm.Controls[i];
      if not c.Visible then
         begin
         Continue;
         end;

      right := c.Left + c.Width;
      if right > widest then
         begin
         widest := right;
         name_  := c.ClassName + ' "' + c.Name + '"';
         end;
      end;

   logger.Warn('[Layout] the main window WANTS A HORIZONTAL SCROLL BAR: ' +
               'visible=%s range %d, page %d, client %d. Widest child is %s, ' +
               'ending at %d. AutoScroll=%s',
               [BoolToStr(TR4WMainForm.HorzScrollBar.Visible, True),
                TR4WMainForm.HorzScrollBar.Range,
                TR4WMainForm.HorzScrollBar.Page,
                TR4WMainForm.ClientWidth,
                name_, widest,
                BoolToStr(TR4WMainForm.AutoScroll, True)]);
end;

procedure MakeMainWindowResizeable(const aClientWidth, aClientHeight: integer);
begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   (* THE BORDER STYLE IS SET IN THE .lfm, NOT HERE, AND THAT IS THE WHOLE
     POINT OF THIS ROUTINE'S SHAPE.

     Assigning BorderStyle at run time calls RecreateWnd -- confirmed in
     lcl/interfaces/win32/win32wsforms.pp, TWin32WSCustomForm.SetFormBorderStyle
     is literally `RecreateWnd(AForm)`. The main window CANNOT survive that:

       * tr4whandle is captured once, in CreateTR4WMainForm, and every
         Windows.* call in the program uses it. A recreated form has a new
         HWND, so the old one is dead and every call against it does nothing.
         That is why the contest name stopped appearing in the title -- LOGWIND
         sets it with SetWindowTextA(tr4whandle, ...).
       * The GWL_WNDPROC subclass is installed on that handle. Recreating drops
         it, so WM_CLOSE never reached ExitProgram: closing the main window left
         the program running with Radio 1, Radio 2 and the DX cluster still up.
       * SetMenu was called on that handle too.
       * A sizeable frame is thicker than a fixed one, so the client area
         shrank under a layout already computed for the old frame -- the
         "compressed" bottom.

     Four symptoms, one line. It is a design-time property now.

     SIZED BY ITS CLIENT AREA, not its outer size, for the same reason: the
     caller knows how much room the controls need, and how thick the frame is
     is the widget set's business. The old code set an OUTER height of
     `6 + MainWindowCaptionAndHeader + EditableLogHeight + ws * 14` where
     MainWindowCaptionAndHeader is SM_CYMENU + SM_CYCAPTION -- so the 6 was a
     frame allowance for bsSingle specifically, and the client height it
     actually wanted is what is passed here. Same geometry as before, and it
     stays right whatever the border is.

     THE WIDTH IS A CLIENT WIDTH TOO, SINCE 2026-09-09. It was an OUTER width,
     and the note that stood here defended it: "that is what the original did,
     and changing it to a client width would make the window about sixteen
     pixels wider than every previous version".

     THAT REASONING PRESERVED A WIN32 MEASUREMENT AND BROKE THE LAYOUT. Every
     control on this window is placed in CLIENT coordinates spanning
     0 .. MainWindowChildsWidth, and the caller passes exactly that number --
     ws * 46. Handing it to Width makes the CLIENT that much narrower than the
     controls it has to hold, by however thick the frame is. The rightmost
     column loses its last few pixels: on Windows a bsSingle frame is thin
     enough that nobody looked twice; on gtk2 it is not.

     NY4I, Linux Mint 2026-09-09, with a screenshot: the QSO/multiplier need
     strips -- which are anchored to the RIGHT edge, so they take the whole
     error -- ran into the window border, and so did the text in the top right.

     IT WAS NEVER RIGHT ON WINDOWS EITHER, only invisible. The same reasoning
     already appears three paragraphs above for the HEIGHT: "the caller knows
     how much room the controls need, and how thick the frame is is the widget
     set's business". The width was the half that did not get the argument
     applied to it.

     Matching an older release's outer size is a cosmetic goal; holding the
     controls the layout computed is a correctness one. *)
   TR4WMainForm.ClientWidth := aClientWidth;
   TR4WMainForm.ClientHeight := aClientHeight;

   (* THIS FORM SCROLLS NOTHING, SO IT GETS NO SCROLL BARS.

     NY4I asked the right question after six reports of a horizontal bar I
     could not find: "setting HorzScrollBar Visible to false -- default is true
     according to the Laz documentation -- would not force it to not appear?"
     It would, and it does.

     TScrollingWinControl publishes both bars with Visible defaulting TRUE.
     That is the correct default for a TScrollBox and wrong for this window:
     every control on it is positioned absolutely from ws, nothing here scrolls
     or ever has, and the vertical resize moves the log's rows rather than a
     viewport. A bar that appears on this form is always spurious.

     AutoScroll is already False (the LCL's own default for this class), which
     stops the RANGE being computed from the children -- but Visible is a
     separate switch and a range set from anywhere else still raises a bar.

     BOTH, NOT JUST THE HORIZONTAL ONE. Only the horizontal was reported, and
     the vertical would be exactly as wrong for exactly the same reason;
     leaving it armed would be waiting for the same bug to be found again from
     the other axis. *)
   TR4WMainForm.HorzScrollBar.Visible := False;
   TR4WMainForm.VertScrollBar.Visible := False;

   (* MEASURED AND REPORTED, because this is the number a screenshot cannot
     give you. A client narrower than what the layout asked for means the right
     edge is being clipped, and until this line the only evidence was text
     touching a border in a photograph. *)
   if logger <> nil then
      begin
      logger.Info('[Layout] main window: client %dx%d, outer %dx%d, layout ' +
                  'asked for %d wide',
                  [TR4WMainForm.ClientWidth, TR4WMainForm.ClientHeight,
                   TR4WMainForm.Width, TR4WMainForm.Height, aClientWidth]);
      end;

   ReportMainWindowOverhang;
   DumpMainWindowChildren;

   (* Measured after sizing rather than computed, so the floor is exactly the
     height the layout just took. *)
   TR4WMainForm.Constraints.MinHeight := TR4WMainForm.Height;
   TR4WMainForm.Constraints.MinWidth := TR4WMainForm.Width;
   TR4WMainForm.Constraints.MaxWidth := TR4WMainForm.Width;
end;

procedure AnchorMainWindowControls;
var
   e: TMainWindowElement;

   (* NIL, NOT ControlUsable -- AND THE PROBE PROVED THIS ONE.

     ControlUsable answers `(aCtrl <> nil) and aCtrl.HandleAllocated`, which is
     right for the entry-field accessors it was written for: SelStart, SelLength
     and SetFocus genuinely need a window. ANCHORS DO NOT -- they are a property
     the LCL reads when it aligns children, and the form streamer sets them on
     controls that have no handle at all.

     This routine runs from CreateMainWindow, BEFORE the form is shown.
     Measured on the bench 2026-09-08:

       AFTER-ANCHOR EditableLog     handle=False
       AFTER-ANCHOR CallEdit        handle=True
       AFTER-ANCHOR lstPossibleCall handle=False

     So the log grid and the possible-call strip were the two controls whose
     anchors were SILENTLY SKIPPED -- no log line, no failure -- and they are
     exactly the two that did not move when the window was resized. *)
   procedure AnchorToBottom(const aControl: TWinControl);
   begin
      if aControl <> nil then
         begin
         aControl.Anchors := [akLeft, akBottom];
         end;
   end;

begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   (* WHICH EDGE EACH CONTROL BELONGS TO -- IN ONE PLACE, ON PURPOSE.

     The main window is three horizontal bands: seven rows of status above the
     log, the log, and everything below it. Until now that was expressed as
     ARITHMETIC -- TWindows[e].mweiY * ws + mweB * EditableLogHeight -- so the
     lower band's position was computed from the log's height and the window
     could not be resized at all, because nothing would have moved.

     mweB IS the band. It has always been the band; it was just being used as a
     multiplier. Read as an anchor instead, the same one bit says: rows above
     the log hold to the TOP, rows below hold to the BOTTOM, and the log takes
     up the slack between them.

     The arithmetic STAYS -- it is what lays the window out initially, and it
     is what follows the operator's font-size setting, which no anchor can do.
     Anchors decide only what happens when the window is RESIZED, which
     previously was nothing.

     Scattering `Anchors := ...` through the six routines that create these
     controls would have made the policy unreadable and left the next control
     to be added with no obvious rule to follow. One routine, called once, after
     everything exists. *)
   for e := Low(TMainWindowElement) to High(TMainWindowElement) do
      begin
      if not ControlUsable(GElements[e]) then
         begin
         Continue;
         end;

      if TWindows[e].mweB = 0 then
         begin
         GElements[e].Anchors := [akLeft, akTop];
         end
      else
         begin
         GElements[e].Anchors := [akLeft, akBottom];
         end;
      end;

   (* THE LOG IS THE ONE CONTROL THAT ABSORBS THE CHANGE. Held to all four
     edges, it grows and shrinks with the window while both bands keep their
     size. That is what makes a taller window mean MORE QSOs on screen. *)
   if TR4WEditableLog <> nil then
      begin
      TR4WEditableLog.Anchors := [akLeft, akTop, akRight, akBottom];
      end;

   (* The rest of the lower band, which is not in TWindows[] and so has no
     mweB to read: the two entry fields, the possible-call strip, the three
     progress bars and the tour readout. *)
   AnchorToBottom(TR4WCallEdit);
   AnchorToBottom(TR4WExchangeEdit);
   AnchorToBottom(GTourDurationText);
   AnchorToBottom(GProgressBars[mpbLastHour]);
   AnchorToBottom(GProgressBars[mpbRate]);
   AnchorToBottom(GProgressBars[mpbTourDuration]);

   (* The possible-call strip spans the window, so it follows the right edge
     as well as the bottom. *)
   if TR4WMainForm.lstPossibleCall <> nil then
      begin
      TR4WMainForm.lstPossibleCall.Anchors := [akLeft, akRight, akBottom];
      end;
end;

procedure SetTourDurationBounds(const aLeft, aTop, aWidth, aHeight: integer);
begin
   if ControlUsable(GTourDurationText) then
      begin
      GTourDurationText.SetBounds(aLeft, aTop, aWidth, aHeight);
      end;
end;

procedure SetTourDurationText(const aText: TCaption);
begin
   if ControlUsable(GTourDurationText) and (GTourDurationText.Caption <> aText) then
      begin
      GTourDurationText.Caption := aText;
      end;
end;

procedure ShowTourDurationText(const aVisible: boolean);
begin
   if ControlUsable(GTourDurationText) then
      begin
      GTourDurationText.Visible := aVisible;
      end;
end;

procedure SetElementText(const aElement: TMainWindowElement; const aText: string);
begin
   if not ElementOnMainThread(eoText, aElement, aText, False,
                            get_caller_addr(get_frame)) then
      begin
      Exit;
      end;
   if not ElementUsable(aElement) then
      begin
      Exit;
      end;
   if GElements[aElement].Caption <> aText then
      begin
      (* THE PANEL FITS ITS OWN CAPTION and reports an off-thread write --
        see TElementPanel. Both used to happen here and in SetMainWindowText,
        which is why a direct `pnlRadioOne.Caption := s` could not have been
        safe before. *)
      GElements[aElement].Caption := aText;
      end;
end;

procedure SetElementColors(const aElement: TMainWindowElement;
                           const aBack, aText: TColor);
begin
   { THIS WAS THE ONE ACCESSOR OF THE FOUR WITHOUT A THREAD GUARD, and there is
     no reason for that beyond the order they were written in.  Its known
     off-thread caller is safe by a DIFFERENT mechanism -- uRadioPolling
     registers RefreshMainWindowElementColors as a main-thread job -- which is
     precisely the fragile kind of safety this exercise removes: it holds only
     while that one registration keeps holding.  A colour write is also not a
     hypothetical: the WSJT-X indicator's colour is what five separate defects
     were about. }
   if not ElementOnMainThreadColors(aElement, aBack, aText,
                                  get_caller_addr(get_frame)) then
      begin
      Exit;
      end;
   if not ElementUsable(aElement) then
      begin
      Exit;
      end;
   if GElements[aElement].Color <> aBack then
      begin
      GElements[aElement].Color := aBack;
      end;
   if GElements[aElement].Font.Color <> aText then
      begin
      GElements[aElement].Font.Color := aText;
      end;
end;

procedure ShowElement(const aElement: TMainWindowElement; const aVisible: boolean);
begin
   if not ElementOnMainThread(eoShow, aElement, '', aVisible,
                            get_caller_addr(get_frame)) then
      begin
      Exit;
      end;
   if not ElementUsable(aElement) then
      begin
      Exit;
      end;
   GElements[aElement].Visible := aVisible;
end;

procedure EnableElement(const aElement: TMainWindowElement; const aEnabled: boolean);
begin
   if not ElementOnMainThread(eoEnable, aElement, '', aEnabled,
                            get_caller_addr(get_frame)) then
      begin
      Exit;
      end;
   if not ElementUsable(aElement) then
      begin
      Exit;
      end;
   GElements[aElement].Enabled := aEnabled;
end;

procedure SetElementLeft(const aElement: TMainWindowElement; const aLeft: integer);
begin
   if not ElementUsable(aElement) then
      begin
      Exit;
      end;
   GElements[aElement].Left := aLeft;
end;

procedure SetElementBounds(const aElement: TMainWindowElement;
                           const aLeft, aTop, aWidth, aHeight: integer);
begin
   if not ElementUsable(aElement) then
      begin
      Exit;
      end;
   GElements[aElement].SetBounds(aLeft, aTop, aWidth, aHeight);
end;

procedure SetElementFont(const aElement: TMainWindowElement;
                         const aName: string; const aHeight: integer;
                         const aBold: boolean);
begin
   if not ElementUsable(aElement) then
      begin
      Exit;
      end;

   // NEGATIVE HEIGHT is the same convention tCreateFont passes to CreateFont:
   // the CHARACTER height, not the cell height.  Passing it positive here would
   // give visibly larger text than the Win32 original.
   GElements[aElement].Font.Name := aName;
   GElements[aElement].Font.Height := -aHeight;

   (* THE HEIGHT THIS ELEMENT WAS ASKED FOR, WITH THE SIGN IT WAS APPLIED
     WITH. The panel keeps it so it has something to shrink FROM and something
     to return to -- see TElementPanel.BaseFontHeight, which is signed. *)
   GElements[aElement].BaseFontHeight := -aHeight;
   if aBold then
      begin
      GElements[aElement].Font.Style := [fsBold];
      end
   else
      begin
      GElements[aElement].Font.Style := [];
      end;
end;

{ ---------------------------------------------------------------------------
  THE DEFERRED ACTIONS.  One runner, because QueueAsyncCall wants a method.
  --------------------------------------------------------------------------- }
type
   TDeferredAction = (daAppendSpace, daStartSending, daPasteCall,
                      daPutCall, daClearCallAndFocus);


   TEntryDeferrer = class(TObject)
   public
      procedure Run(Data: PtrInt);
      procedure RunElement(Data: PtrInt);
   end;

var
   GDeferrer: TEntryDeferrer = nil;
   { The key daStartSending carries.  One pending value is enough: the foot
     switch cannot produce two before the queue drains.

     AnsiChar, not char: this unit compiles with the UnicodeStrings mode
     switch, so a bare `char` is a WideChar -- and TKeyPressEvent's Key is
     passed BY VAR, so the types have to match exactly rather than convert. }
   GStartSendingKey: AnsiChar = #0;

   { The call daPutCall carries, under GPendingLock because the WSJT-X UDP
     listener writes it while the main thread reads it -- unlike
     GStartSendingKey, whose one producer is the foot switch.

     LAST ONE WINS, and that is correct rather than merely convenient: this is
     "the station the operator should be looking at", so a newer answer
     supersedes an older one. Queueing a growing list of calls to type into one
     field and then erase would be the wrong shape. }
   GPendingCall: string = '';
   GPendingLock: TRTLCriticalSection;

procedure Queue(const aAction: TDeferredAction);
begin
   if GDeferrer = nil then
      begin
      GDeferrer := TEntryDeferrer.Create;
      end;

   // Application can be gone on the way out, and QueueAsyncCall RAISES on a
   // shut-down queue rather than returning False -- the same trap uPanelUpdate
   // documents.
   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;
   Application.QueueAsyncCall(GDeferrer.Run, PtrInt(aAction));
end;

{ THE ELEMENT ACCESSORS ARE CALLED FROM WORKER THREADS, AND THE WIN32 THEY
  REPLACED MADE THAT SAFE BY ACCIDENT.

  SetWindowTextW, ShowWindow and EnableWindow are kernel calls: Windows marshals
  them to the window's own thread, so uWSJTX could write the WSJT-X indicator
  straight from an Indy UDP listener thread and it simply worked.  Assigning an
  LCL Caption, Visible or Enabled does no such thing.

  NY4I asked how a WSJT-X datagram turns that indicator green; tracing the
  answer is what found this.  TWSJTXServer.OnServerRead runs on the listener
  thread -- uWSJTX sets ThreadedEvent := True explicitly -- and uWinKey and
  LOGK1EA write elements from their own threads too.

  THE GUARD GOES HERE, NOT AT THE CALL SITES.  There are seventy-five callers of
  SetMainWindowText alone, spread across the program, and asking each to know
  which thread it is on is exactly the kind of rule that is right for a year and
  then quietly wrong.  One funnel cannot be forgotten.

  This is a SAFETY NET, not the hot path.  A radio polled every 10 ms goes
  through uPanelUpdate.PostElementText, which coalesces; this queues one async
  call per operation and is for the cold callers -- a heartbeat, a WinKey state
  change, a foot switch. }
function ElementOnMainThread(const aOp: TElementOp;
                             const aElement: TMainWindowElement;
                             const aText: string; const aFlag: boolean;
                             const aCaller: CodePointer): boolean;
var
   work: PElementWork;
begin
   Result := True;
   if OnMainThread then
      begin
      Exit;
      end;

   { IT DEFERRED SILENTLY UNTIL NOW, AND THAT WAS THE GAP.

     Its sibling guard eight hundred lines up -- ControlUsable, for the entry
     fields -- has always called ReportOffMainThread, and that report is what
     licensed the entry-field conversion: "EntryUsable names every distinct
     off-main-thread caller, and a full bench session with a K4 produced none."
     THE PROGRAM SAID SO, RATHER THAN ME.

     The element guard made the same claim unaskable.  It quietly did the right
     thing and told nobody, so "does any thread still write a main-window
     element" had no answer short of a hand call-graph walk -- the exact form of
     evidence that has been wrong three times in this tree.

     DISPLAY_STATE_MODEL_PLAN.md sets the finish line as "the guard stays as a
     backstop; it should simply stop having anything to catch."  That is not a
     checkable condition while the backstop is mute.  Now a bench session
     answers it, and the remaining step -- making these accessors internal to
     src/ui -- can be justified by evidence instead of by inspection.

     Deduped by caller address inside ReportOffMainThread, so a per-frame writer
     costs one line in the log, not thousands. }
   { aCaller, NOT get_caller_addr(get_frame).  THE DIFFERENCE IS THE WHOLE
     VALUE OF THE REPORT.  Taken here, the frame above is SetElementText --
     always, for every caller in the program -- and ReportOffMainThread dedups
     by address, so the accessor would name ITSELF once and then go quiet
     forever.  Measured 2026-08-29: exactly two lines in a full session, which
     says off-thread writes happen and nothing about WHERE.

     Each accessor now takes its own caller's address and passes it down, so
     the log names the code that actually wrote the element.  That list is the
     scope of step 4. }
   ReportOffMainThread('main window element accessor', aCaller);

   Result := False;
   if (Application = nil) or Application.Terminated then
      begin
      Exit;      // shutting down; dropping it is what the old no-op did
      end;

   if GDeferrer = nil then
      begin
      GDeferrer := TEntryDeferrer.Create;
      end;

   New(work);
   work^.Op := aOp;
   work^.Element := aElement;
   work^.Text := aText;
   work^.Flag := aFlag;
   Application.QueueAsyncCall(GDeferrer.RunElement, PtrInt(work));
end;

function ElementOnMainThreadColors(const aElement: TMainWindowElement;
                                   const aBack, aFore: TColor;
                                   const aCaller: CodePointer): boolean;
var
   work: PElementWork;
begin
   Result := True;
   if OnMainThread then
      begin
      Exit;
      end;

   ReportOffMainThread('main window element colours', aCaller);

   Result := False;
   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;

   if GDeferrer = nil then
      begin
      GDeferrer := TEntryDeferrer.Create;
      end;

   New(work);
   work^.Op := eoColors;
   work^.Element := aElement;
   work^.Text := '';
   work^.Flag := False;
   work^.Back := aBack;
   work^.Fore := aFore;
   Application.QueueAsyncCall(GDeferrer.RunElement, PtrInt(work));
end;

procedure TEntryDeferrer.RunElement(Data: PtrInt);
var
   work: PElementWork;
begin
   work := PElementWork(Data);
   if work = nil then
      begin
      Exit;
      end;
   try
      case work^.Op of
        eoText:   SetElementText(work^.Element, work^.Text);
        eoShow:   ShowElement(work^.Element, work^.Flag);
        eoEnable: EnableElement(work^.Element, work^.Flag);
        eoColors: SetElementColors(work^.Element, work^.Back, work^.Fore);
      end;
   finally
      Dispose(work);
   end;
end;

procedure TEntryDeferrer.Run(Data: PtrInt);
begin
   case TDeferredAction(Data) of

     daAppendSpace:
        begin
        // Was PostMessage(wh[mweExchange], WM_KEYDOWN, 32, 0): a synthetic
        // space, which TranslateMessage turned into a WM_CHAR the edit
        // appended.  The caller has already checked that the caret is at the
        // end and the last character is not a space.
        if ControlUsable(TR4WExchangeEdit) then
           begin
           TR4WExchangeEdit.Text := TR4WExchangeEdit.Text + ' ';
           TR4WExchangeEdit.SelStart := Length(TR4WExchangeEdit.Text);
           end;
        end;

     daStartSending:
        begin
        // Was PostMessage(wh[mweCall], WM_CHAR, StartSendingNowKey, 0) from the
        // foot switch.  The point was never to put a character in the field --
        // it was to reach the field's key handler, which is now callable.
        if (GStartSendingKey <> #0) and Assigned(EntryEvents) then
           begin
           EntryEvents.CallKeyPress(nil, GStartSendingKey);
           GStartSendingKey := #0;
           end;
        end;

     daPutCall:
        begin
        { The field write half of MainUnit.PutCallToCallWindow, which keeps the
          decision half (the MyCall check). Text and selection move TOGETHER
          and that is the whole reason this is one deferred operation rather
          than two deferred accessors: the caret goes to the END of the text,
          so the selection has to be computed AFTER the write lands. Deferring
          SetEntryText and SetEntrySel separately would read the length of the
          text the write had not yet made. }
        { Through the accessors rather than at the control, so the
          HandleAllocated guard and the ShortString narrowing are handled in the
          one place that already handles them.  We are on the main thread here
          by construction, so their thread check is free. }
        EnterCriticalSection(GPendingLock);
        try
           SetEntryText(TR4WCallEdit, GPendingCall);
        finally
           LeaveCriticalSection(GPendingLock);
        end;
        SetEntrySel(TR4WCallEdit, Length(EntryText(TR4WCallEdit)), 0);
        end;

     daClearCallAndFocus:
        begin
        { Both fields cleared and focus returned to the call field -- the
          "ready for the next QSO" gesture. ONE action, not three, because the
          focus must land after both clears; three separate hops could
          interleave with a fourth thing the operator did in between. }
        SetEntryText(TR4WCallEdit, '');
        SetEntryText(TR4WExchangeEdit, '');
        FocusEntry(TR4WCallEdit);
        end;

     daPasteCall:
        begin
        // Was WM_PASTE followed by WM_SETFOCUS, both posted.  THE SECOND ONE
        // NEVER DID ANYTHING: posting WM_SETFOCUS tells a window it has gained
        // focus, it does not give it focus.  FocusEntry actually moves it.
        if ControlUsable(TR4WCallEdit) then
           begin
           TR4WCallEdit.PasteFromClipboard;
           end;
        FocusEntry(TR4WCallEdit);
        end;
   end;
end;

procedure QueueAppendSpaceToExchange;
begin
   Queue(daAppendSpace);
end;

procedure QueueStartSendingKey(const aKey: AnsiChar);
begin
   GStartSendingKey := aKey;
   Queue(daStartSending);
end;

procedure QueuePasteIntoCallField;
begin
   Queue(daPasteCall);
end;

procedure QueuePutCallToCallField(const aCall: string);
begin
   EnterCriticalSection(GPendingLock);
   try
      GPendingCall := aCall;
   finally
      LeaveCriticalSection(GPendingLock);
   end;
   Queue(daPutCall);
end;

procedure QueueClearCallAndFocus;
begin
   Queue(daClearCallAndFocus);
end;

(* THE WINDOW PROCEDURE IS GONE -- THIS IS AN ORDINARY LCL FORM NOW.

  TR4W installed its own procedure in front of the LCL's with
  SetWindowLongPtr(GWL_WNDPROC) so it could answer nine raw Win32 messages.
  All nine are LCL events or an LCL message handler:

    WM_CLOSE              OnCloseQuery
    WM_COMMAND            TMenuItem.OnClick   (the menu is a TMainMenu)
    WM_SETFOCUS           OnActivate
    WM_SIZE               OnWindowStateChange
    WM_LBUTTONDOWN        OnMouseDown
    WM_TIMECHANGE         a poll -- uSystemWatch
    WM_DISPLAYCHANGE      a poll -- uSystemWatch
    WM_WINDOWPOSCHANGING  WMWindowPosChanging, via LM_WINDOWPOSCHANGING
    WM_USER_HEADLESS_...  uMainThread.RunOnMainThread

  WHAT WENT WITH IT is worth naming, because each was a hazard of having a
  window procedure at all: an allow-list of message ids that had to be kept
  in step with the case labels by hand and silently dropped anything missing
  from it -- three of its eight literals were wrong once, and every failure
  was invisible; a try/except wrapper, because an exception leaving a kernel
  callback is undefined behaviour; and the rule that TR4W got first refusal
  on every message, which is what made the LCL deaf to its own controls. *)

(* THE DUPE FLAG PER CANDIDATE -- the view's own render state.

  ITS LENGTH IS THE COUNT, so there is no separate counter to disagree with
  the control. The callsigns live in the grid's Cells; this is the one thing
  a cell needs that a cell cannot hold, and it is set by the same call that
  sets the text, so the two cannot drift.

  NOT Objects[], which is where the Win32 version put it (LB_SETITEMDATA) and
  where an integer cast to TObject would put it again. CLAUDE.md names that
  shape as a defect in its own right. *)
var
   GPossibleDupe: array of boolean;

(* DECLARED HERE, ABOVE ITS FIRST USE, and that is not a style choice: the
  paint hook below runs long before the accessors that maintain it appear in
  this file, and Pascal resolves in order. *)

(* THE COLOURS OF ONE CANDIDATE, AND NOTHING ELSE.

  A TStringGrid DRAWS ITS OWN CELLS. This is called just before it draws one,
  with the cell and its state, and everything set on the canvas here is what
  the grid then uses -- brush, font, and the text style that decides
  alignment. That is the whole of the custom drawing in this control now.

  WHAT IT REPLACED, because the difference is the point. The strip was an
  owner-drawn listbox holding N EMPTY STRINGS, with the callsigns in a global
  that a paint handler in another unit indexed by item position. Everything
  that went wrong with it followed from the control holding no data:

    * N empty strings are identical to N empty strings, so the control could
      not tell its content had changed and the repaint had to be forced by
      hand (NY4I, 2026-08-24: "scp updated the first time but subsequent calls
      did not change from the prior values").
    * Its item count could not be trusted, so a separate counter was kept
      beside it.
    * Every pixel was ours, so DefaultDrawing had to be off.
    * Hiding it when empty took its window handle away, and the accessors that
      guarded on that handle stopped working -- which broke the feature
      outright for one build.

  Cells[i, 0] holds the callsign now. ColCount is the count. Setting a cell
  invalidates it. None of the four can recur.

  TWO SIGNALS, KEPT INDEPENDENT. A dupe is a red cell with white text, which
  is what it has always been. The current candidate is BOLD rather than
  bordered -- the old red rectangle was drawn by hand, and a font weight
  survives being combined with the red background where a second colour would
  not. Both are visible at once on a cell that is both.

  taCenter through TextStyle, not through a Columns collection: the grid gains
  and loses columns on every keystroke, and a collection would have to be
  rebuilt each time to say one thing that never varies. *)
procedure TTR4WMainForm.lstPossibleCallPrepareCanvas(Sender: TObject;
                                                     aCol, aRow: integer;
                                                     aState: TGridDrawState);
var
   style: TTextStyle;
begin
   if (aCol < Low(GPossibleDupe)) or (aCol > High(GPossibleDupe)) then
      begin
      Exit;
      end;

   if GPossibleDupe[aCol] then
      begin
      lstPossibleCall.Canvas.Brush.Color := clRed;
      lstPossibleCall.Canvas.Font.Color  := clWhite;
      end
   else
      begin
      lstPossibleCall.Canvas.Brush.Color :=
         tr4wColorsArray[TWindows[mwePossibleCall].mweBackG];
      lstPossibleCall.Canvas.Font.Color :=
         tr4wColorsArray[TWindows[mwePossibleCall].mweColor];
      end;

   if aCol = lstPossibleCall.Col then
      begin
      lstPossibleCall.Canvas.Font.Style :=
         lstPossibleCall.Canvas.Font.Style + [fsBold];
      end;

   style := lstPossibleCall.Canvas.TextStyle;
   style.Alignment   := taCenter;
   style.Layout      := tlCenter;
   style.SingleLine  := True;
   style.EndEllipsis := True;
   lstPossibleCall.Canvas.TextStyle := style;
end;

var
   (* The QSOs the B4 list is showing. Held rather than re-read: the caller
     found them by scanning the log and there are only ever a handful. *)
   GDupeQsos: array of ContestExchange;

(* THE EDITABLE LOG.

  A TLogGrid -- see uLogGrid for why it is a grid the LCL draws rather than a
  list view, which on Windows is the comctl32 control and was reconfigurable
  behind the LCL's back by anything holding its handle.

  THE ROWS ARE NOT HELD ANYWHERE. The grid asks MainLogFetchRow for the record
  it is about to paint and caches the answer itself, so this unit keeps no
  cache of its own -- the two that used to live here and in uLogEditForm are
  one, inside the control. *)

procedure TR4WEditableLogRefresh;
begin
   if TR4WEditableLog <> nil then
      begin
      TR4WEditableLog.Reload;
      end;
end;

(* ONE RECORD, FOR THE GRID TO PAINT.

  LogSourceReadAtIndex is independent of any sequential read in progress, which
  is what makes it safe to call from a paint while LoadinLog is walking the
  same log. LogRowTextFor turns the record into the fourteen strings a row
  shows and is the same routine the log file's own export uses, so what is on
  screen and what is written out cannot disagree. *)
procedure TTR4WMainForm.MainLogFetchRows(Sender: TObject;
                                         const aFirstIndex: Int64;
                                         var aRows: array of TLogGridRow);
var
   qsos: array of ContestExchange;
   got:  integer;
   i:    integer;
begin
   (* OPENED ONCE, NOT PER BATCH. LogSourceOpen ensures the one connection
     exists; it is not reopened per fetch. *)
   if not LogSourceIsOpen then
      begin
      if not LogSourceOpen then
         begin
         Exit;
         end;
      end;

   SetLength(qsos, Length(aRows));
   got := LogSourceReadRange(aFirstIndex, qsos);

   for i := 0 to got - 1 do
      begin
      (* LogRowTextFor is the same routine the export uses, so what is on
        screen and what is written out cannot disagree. *)
      LogRowTextFor(qsos[i], aRows[Low(aRows) + i].Text);
      aRows[Low(aRows) + i].Deleted := qsos[i].ceQSO_Deleted;
      aRows[Low(aRows) + i].XQSO    := qsos[i].ceXQSO;
      aRows[Low(aRows) + i].Valid   := True;
      end;
end;

(* A DOUBLE-CLICK OPENS THE QSO UNDER THE POINTER.

  The grid has already moved its own selection to that row by the time this
  runs, so the record is SelectedRecord and there is no separate hit test --
  which is where the row/record mismatch came from when there was one. *)
(* THE FORM BUILDS AND WIRES ITS OWN CONTROL.

  A METHOD, NOT THE UNIT-LEVEL PROCEDURE, and the reason is a lint rather than
  taste. Wiring from outside reads TR4WEditableLog.OnEnter :=
  TR4WMainForm.MainLogEnter -- a DOTTED name, which Lint-FormEvents
  deliberately does not count as wiring, because a dotted name is also how an
  implementation header is spelled and counting those would make every
  unwired handler look wired. The lint caught two of these the first time it
  ran over this form. Inside the class the names are unqualified and the
  wiring is visible to it. *)
procedure TTR4WMainForm.BuildLogGrid;
begin
   TR4WEditableLog := TLogGrid.Create(Self);
   TR4WEditableLog.Parent        := Self;
   TR4WEditableLog.OnFetchRows   := MainLogFetchRows;
   TR4WEditableLog.OnDblClick    := MainLogDblClick;
   TR4WEditableLog.OnKeyDown     := MainLogKeyDown;
   TR4WEditableLog.OnEnter       := MainLogEnter;
   TR4WEditableLog.OnHeaderSized := MainLogHeaderSized;

   (* FITTED TO THE CONTENTS AND STRETCHED TO THE WINDOW, like the two dialog
     grids -- NY4I, 2026-09-04.

     THE DECLARED WIDTHS CLIPPED. ColumnsArray[].Width is a DOS-era count of
     CHARACTERS multiplied by ws, which for a proportional font is arbitrary:
     Freq had four of them and showed "21300...." for a frequency that needs
     eight. The Win32 list view did exactly the same thing, so this is not a
     regression being fixed -- it is the original being improved on, and the
     cost is that the layout is no longer pixel-identical to it.

     A COLUMN THE OPERATOR HAS DRAGGED STILL WINS. SizeColumnsToFit keeps an
     overridden width and leaves it out of the surplus, so a hand-sized column
     stays where it was put. *)
   TR4WEditableLog.Sizing := lgsFitAndFill;
end;

procedure TTR4WMainForm.InstallMenu;
begin
   (* MenuItemClick UNQUALIFIED, and that is not style.

     Lint-FormEvents treats a DOTTED name as the implementation header
     rather than a reference, so TR4WMainForm.MenuItemClick read as "declared
     but never wired" -- a handler assigned to 140 menu items. Inside a
     method of the same class the bare name is the method reference, and
     the form building its own menu is where this belongs anyway. *)
   Menu := BuildTR4WMainMenu(Self, MenuItemClick);
end;

procedure TTR4WMainForm.MainFormCloseQuery(Sender: TObject;
                                           var CanClose: boolean);
begin
   (* ExitProgram OWNS THE SHUTDOWN, as it did from the WM_CLOSE arm -- it
     asks the operator, saves and closes down in order. CanClose stays False
     because the arm's `Msg := 0` said exactly that: do not let the framework
     destroy this window on its own. *)
   CanClose := False;
   ExitProgram(True);
end;

procedure TTR4WMainForm.MainFormMouseDown(Sender: TObject; Button: TMouseButton;
                                          Shift: TShiftState; X, Y: integer);
begin
   if Button <> mbLeft then
      begin
      Exit;
      end;

   FDragging        := True;
   FDragMouseOrigin := ClientToScreen(Point(X, Y));
   FDragFormOrigin  := Point(Left, Top);

   (* CAPTURE, because a drag routinely leaves the window behind. Without it
     the pointer crosses onto another control or off the form and the moves
     stop arriving here, so the window sticks mid-drag and only catches up if
     the pointer wanders back. The system move loop did this implicitly. *)
   MouseCapture := True;
end;

procedure TTR4WMainForm.MainFormMouseMove(Sender: TObject; Shift: TShiftState;
                                          X, Y: integer);
var
   here: TPoint;
   work: TRect;
   newL: integer;
   newT: integer;
begin
   if not FDragging then
      begin
      Exit;
      end;

   here := ClientToScreen(Point(X, Y));
   newL := FDragFormOrigin.X + (here.X - FDragMouseOrigin.X);
   newT := FDragFormOrigin.Y + (here.Y - FDragMouseOrigin.Y);

   (* THE SIZE PASSED HERE IS THE LCL'S, AND THAT IS THE RIGHT ONE FOR THIS
     PATH. Width and Height are what Left and Top are measured against, so the
     window lands flush with its VISIBLE edge against the work area.

     WMWindowPosChanging passes a different number for the same window, and
     the difference is real rather than an inconsistency to iron out: the
     message carries the OUTER size, which on Windows includes the invisible
     resize border -- 1028 where the LCL says 1012, measured 2026-09-07. Each
     path snaps in the coordinate space its own numbers are expressed in. *)
   work := Screen.WorkAreaRect;
   SnapWindowToEdges(newL, newT, Width, Height,
                     work.Left, work.Top, work.Right, work.Bottom);

   if (newL <> Left) or (newT <> Top) then
      begin
      SetBounds(newL, newT, Width, Height);
      end;
end;

procedure TTR4WMainForm.MainFormMouseUp(Sender: TObject; Button: TMouseButton;
                                        Shift: TShiftState; X, Y: integer);
begin
   if not FDragging then
      begin
      Exit;
      end;

   FDragging    := False;
   MouseCapture := False;
end;

(* SNAP TO THE SCREEN EDGES while the window is being moved.

  Within 20 pixels of the left or top edge, or of the work area's right or
  bottom, the window goes flush. Unchanged from the WM_WINDOWPOSCHANGING arm
  except for where the work area comes from: tWorkingAreaRect was filled once
  at start-up by SystemParametersInfo(SPI_GETWORKAREA), and Screen.WorkAreaRect
  is the LCL's own, read when it is used -- so this now follows a taskbar that
  moves. *)
procedure TTR4WMainForm.WMWindowPosChanging(var aMsg: TLMWindowPosMsg);
var
   p:    PWindowPos;
   work: TRect;
begin
   inherited;

   p := aMsg.WindowPos;
   if p = nil then
      begin
      Exit;
      end;

   (* THE FAR-EDGE ARMS USE THE SIZE THE MESSAGE CARRIES, AND ONLY THAT.

     A drag fills cx and cy with the window's outer size, which is the case
     these two arms are for. A programmatic SetWindowPos(..., SWP_NOSIZE) does
     not: cx and cy are documented as ignored and are whatever the caller left
     in the structure, usually zero, so the distance comes out a screen width
     wrong and nothing snaps. That is the RIGHT outcome -- a saved window
     position being restored at start-up should land where it was saved, not be
     pulled to an edge -- but it is worth knowing before treating a programmatic
     move as a test of these arms.

     Taking the size from Width/Height instead was tried and is wrong: LCL
     reports 1012 for a window Windows measures at 1028, the difference being
     the invisible resize border, so the snap target lands 16 px past the edge
     (measured 2026-09-07). Test-MainWindowEvents therefore drives these arms
     the way a drag does, with a real size in the message. *)
   work := Screen.WorkAreaRect;
   SnapWindowToEdges(p^.X, p^.Y, p^.cx, p^.cy,
                     work.Left, work.Top, work.Right, work.Bottom);
end;

procedure TTR4WMainForm.MenuItemClick(Sender: TObject);
begin
   (* NO `if lParam = 0` GUARD, because the ambiguity is gone rather than
     handled. WM_COMMAND carried three different things and Windows told them
     apart by lParam -- 0 for a menu item, 0 for an accelerator, the control's
     HWND for a notification -- and reading only LoWord(wParam) is what turned
     an edit control's EN_UPDATE into "plugin number 34" and crashed TR4W
     (2026-09-03). An OnClick can only be a menu click. *)
   DispatchCommandId(TMenuItem(Sender).Tag);
end;

procedure TTR4WMainForm.SystemWatchTick(Sender: TObject);
begin
   (* Cheap: two property reads unless the answer has changed. *)
   ReportHorizontalScroll;

   (* THE PAINT NUMBERS, ON THE TIMER RATHER THAN AT LAYOUT. The child dump
     runs once, while the form is being built and before anything has been
     drawn, so it reports calls=0 whatever the truth is. Reading them here is
     what makes the count mean something. *)
   if (TR4WEditableLog <> nil) and (logger <> nil) then
      begin
      logger.Debug('[EditableLog] Paint tick: calls=%d client=%d rowH=%d ' +
                   'rows=%d gridHeight=%d drawn=%d',
                   [TR4WEditableLog.PaintCount, TR4WEditableLog.PaintClient,
                    TR4WEditableLog.PaintRowH, TR4WEditableLog.PaintRows,
                    TR4WEditableLog.PaintGrid, TR4WEditableLog.PaintDrawn]);
      end;

   if SystemClockJumped then
      begin
      (* WAS THE WM_TIMECHANGE ARM. GetSystemTime first, exactly as it did:
        SystemTimeChanging re-reads UTC itself but SKIPS that in hand-log mode,
        and the arm forced it either way. *)
      {$IFDEF WINDOWS}
      GetSystemTime(UTC);
      {$ENDIF}
      SystemTimeChanging;
      if logger <> nil then
         begin
         logger.Info('[SystemWatch] the system clock was changed -- readouts refreshed');
         end;
      end;

   if DisplayLayoutChanged then
      begin
      (* WAS THE WM_DISPLAYCHANGE ARM. Issue #1060: a monitor was added or
        removed, or the resolution changed -- pull any now-off-screen TR4W
        window back onto an active monitor. *)
      (* COLOUR DEPTH HAS NO LCL EQUIVALENT and only uGradient reads it, to
        collapse a gradient to a flat fill on an 8-bit display. RefreshColourDepth
        gates itself, so this call needs no conditional. *)
      RefreshColourDepth;
      RevalidateOpenWindowsOnScreen;
      if logger <> nil then
         begin
         logger.Info('[SystemWatch] the display layout changed -- windows revalidated');
         end;
      end;
end;

procedure TTR4WMainForm.MainFormActivate(Sender: TObject);
begin
   if ActiveMainWindow = awExchangeWindow then
      begin
      tExchangeWindowSetFocus;
      end
   else
      begin
      tCallWindowSetFocus;
      end;
   ShowFMessages(0);
end;

procedure TTR4WMainForm.MainFormWindowStateChange(Sender: TObject);
begin
   (* ShowWindow ON ANOTHER PROGRAM'S WINDOW, AND WINDOWS-ONLY.

     MMTTY is a separate EXE -- WinExec'd, not a DLL -- and MMTTYEngine is its
     top-level HWND, found by window class. TR4W minimises and restores it
     alongside itself so the RTTY window does not sit on the desktop after the
     logger is minimised. The LCL has no vocabulary for a window it does not
     own; ShowWindow is the interface another process exposes.

     GATED because MMTTY IS a Windows program -- there is nothing to minimise
     on macOS or Linux, so this is not a call to be ported but a feature that
     does not exist there (NY4I, 2026-09-06). *)
   {$IFDEF WINDOWS}
   if MMTTY.MMTTYEngine = 0 then
      begin
      Exit;
      end;

   case WindowState of
     wsMinimized: Windows.ShowWindow(MMTTY.MMTTYEngine, SW_SHOWMINNOACTIVE);
     wsNormal:    Windows.ShowWindow(MMTTY.MMTTYEngine, SW_RESTORE);
   end;
   {$ENDIF}
end;

procedure TTR4WMainForm.MainLogDblClick(Sender: TObject);
begin
   EditableLogWindowDblClick;
end;

(* THE B4 LIST, BUILT LIKE THE LOG AND SHOWING THE SAME COLUMNS.

  Hidden until something asks for it, and sharing the editable log's bounds --
  see TR4WPreviousDupesShow. *)
procedure TTR4WMainForm.BuildDupesGrid;
begin
   TR4WPreviousDupes := TLogGrid.Create(Self);
   TR4WPreviousDupes.Parent     := Self;
   TR4WPreviousDupes.OnFetchRows := DupesFetchRows;

   (* The same sizing as the log it stands in for, or the B4 list would lay its
     columns out differently from the window it replaces. *)
   TR4WPreviousDupes.Sizing := lgsFitAndFill;
   TR4WPreviousDupes.Visible    := False;

   ApplyMainFontTo(TR4WPreviousDupes.Font);
   TR4WPreviousDupes.DefaultRowHeight := ws + 2;
   TR4WPreviousDupes.Color      := tr4wColorsArray[TWindows[mweEditableLog].mweBackG];
   TR4WPreviousDupes.Font.Color := tr4wColorsArray[TWindows[mweEditableLog].mweColor];
   TR4WPreviousDupes.BuildColumns;

   if TR4WEditableLog <> nil then
      begin
      TR4WPreviousDupes.BoundsRect := TR4WEditableLog.BoundsRect;
      end;
end;

(* THE RECORDS ARE ALREADY IN MEMORY -- the caller scanned the log to find
  them, so painting costs no database work. aFirstIndex indexes THOSE, not the
  log. *)
procedure TTR4WMainForm.DupesFetchRows(Sender: TObject; const aFirstIndex: Int64;
                                       var aRows: array of TLogGridRow);
var
   i: integer;
   m: Int64;
begin
   for i := Low(aRows) to High(aRows) do
      begin
      m := aFirstIndex + (i - Low(aRows));
      if (m < 0) or (m >= Length(GDupeQsos)) then
         begin
         Break;
         end;

      LogRowTextFor(GDupeQsos[m], aRows[i].Text);
      aRows[i].Deleted := GDupeQsos[m].ceQSO_Deleted;
      aRows[i].XQSO    := GDupeQsos[m].ceXQSO;
      aRows[i].Valid   := True;
      end;
end;

(* ARROW-DOWN OFF THE LAST ROW RETURNS FOCUS TO THE CALL WINDOW.

  The whole log is reachable now, so "the last row" is the last RECORD rather
  than the bottom of a five-row window -- which is what it meant when the list
  held a tail of the log and is why this used to fire in the middle of a
  contest.

  Traced like every other key path here, and for a reason beyond consistency: a
  focus transition is invisible to any test that is not the operator's eyes,
  because a cross-process focus read reports nothing while the program is not
  in the foreground. The log is the only observable this behaviour has. *)
procedure TTR4WMainForm.MainLogKeyDown(Sender: TObject; var Key: word;
                                       Shift: TShiftState);
begin
   if Key <> VK_DOWN then
      begin
      Exit;
      end;

   if TR4WEditableLog = nil then
      begin
      Exit;
      end;

   if TR4WEditableLog.SelectedRecord = TR4WEditableLog.RecordCount - 1 then
      begin
      if logger <> nil then
         begin
         logger.Trace('[EditableLog] VK_DOWN on the last row -> focus to the call window');
         end;
      Key := 0;
      tCallWindowSetFocus;
      end;
end;

procedure TTR4WMainForm.MainLogEnter(Sender: TObject);
begin
   ActiveMainWindow := awEditableLog;
end;

(* THE OPERATOR DRAGGED A COLUMN EDGE, so remember the width they chose.

  No padding and no auto-fit: they picked this width explicitly. The
  double-click-to-auto-fit arm that stood beside this is gone with the header
  control -- TLogGrid distributes widths itself on every resize, which is the
  behaviour that feature approximated. *)
procedure TTR4WMainForm.MainLogHeaderSized(Sender: TObject; IsColumn: boolean;
                                           Index: integer);
begin
   if not IsColumn then
      begin
      Exit;
      end;

   if TR4WEditableLog = nil then
      begin
      Exit;
      end;

   SaveColumnWidthToConfig(Index, TR4WEditableLog.ColWidths[Index]);
end;

procedure CreateTR4WEditableLog(const aLeft, aTop, aWidth, aHeight: integer);
begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   if TR4WEditableLog = nil then
      begin
      TR4WMainForm.BuildLogGrid;
      end;

   TR4WEditableLog.SetBounds(aLeft, aTop, aWidth, aHeight);

   (* THE OPERATOR'S OWN FONT, and the row height that goes with it. Without
     this the grid drew in the LCL default and looked like a different program
     from the window around it (NY4I, 2026-09-04). *)
   ApplyMainFontTo(TR4WEditableLog.Font);
   TR4WEditableLog.DefaultRowHeight := ws + 2;

   TR4WEditableLogApplyColors;
   TR4WEditableLog.BuildColumns;
   TR4WEditableLog.Visible := True;
   TR4WEditableLogRefresh;
end;

procedure TR4WPreviousDupesSet(const aQsos: array of ContestExchange);
var
   i: integer;
begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   if TR4WPreviousDupes = nil then
      begin
      TR4WMainForm.BuildDupesGrid;
      end;

   SetLength(GDupeQsos, Length(aQsos));
   for i := Low(aQsos) to High(aQsos) do
      begin
      GDupeQsos[i - Low(aQsos)] := aQsos[i];
      end;

   TR4WPreviousDupes.Reload;
   TR4WPreviousDupes.RecordCount := Length(GDupeQsos);
end;

procedure TR4WPreviousDupesShow(const aVisible: boolean);
begin
   if (TR4WPreviousDupes = nil) and aVisible and (TR4WMainForm <> nil) then
      begin
      TR4WMainForm.BuildDupesGrid;
      end;

   if TR4WPreviousDupes <> nil then
      begin
      TR4WPreviousDupes.Visible := aVisible;
      end;

   (* THE TWO SHARE ONE RECTANGLE, so showing either hides the other. *)
   TR4WEditableLogShow(not aVisible);
end;

procedure TR4WPreviousDupesSetBounds(const aLeft, aTop, aWidth, aHeight: integer);
begin
   if TR4WPreviousDupes <> nil then
      begin
      TR4WPreviousDupes.SetBounds(aLeft, aTop, aWidth, aHeight);
      end;
end;

procedure TR4WEditableLogApplyColors;
begin
   if TR4WEditableLog = nil then
      begin
      Exit;
      end;

   TR4WEditableLog.Color      := tr4wColorsArray[TWindows[mweEditableLog].mweBackG];
   TR4WEditableLog.Font.Color := tr4wColorsArray[TWindows[mweEditableLog].mweColor];
   TR4WEditableLog.Invalidate;
end;

procedure TR4WEditableLogSetGridLines(const aOn: boolean);
begin
   if TR4WEditableLog = nil then
      begin
      Exit;
      end;

   if aOn then
      begin
      TR4WEditableLog.Options := TR4WEditableLog.Options + [goVertLine, goHorzLine];
      end
   else
      begin
      TR4WEditableLog.Options := TR4WEditableLog.Options - [goVertLine, goHorzLine];
      end;
end;

procedure TR4WEditableLogRefreshCount;
var
   n: Int64;
begin
   if TR4WEditableLog = nil then
      begin
      Exit;
      end;

   if not LogSourceIsOpen then
      begin
      if not LogSourceOpen then
         begin
         TR4WEditableLog.RecordCount := 0;
         Exit;
         end;
      end;

   n := LogSourceRecordCount;

   (* WHAT THE LOG SAYS versus what the grid is showing, every time a QSO is
     logged. One line, because "the contact did not appear" has three
     completely different causes -- the count did not move, the count moved and
     the rows did not, or this was never called -- and they are indistinguishable
     from the screen. *)
   if logger <> nil then
      begin
      logger.Debug('[EditableLog] refresh: log has %d record(s), grid had %d',
                   [n, TR4WEditableLog.RecordCount]);
      end;

   TR4WEditableLog.RecordCount := n;
end;

procedure TR4WEditableLogSetCount(const aCount: Int64);
begin
   if TR4WEditableLog = nil then
      begin
      Exit;
      end;
   TR4WEditableLog.RecordCount := aCount;
end;

(* SnapEditableLogToWholeRows IS DELETED, AND IT WAS THE WRONG LAYER.

  It rounded the grid's height down to a whole number of rows, which removed
  the dead strip at creation and did nothing at all in the case that mattered:
  TR4WEditableLog is anchored [akLeft, akTop, akRight, akBottom], so when the
  form is restored to its saved height the LCL STRETCHES the grid by the
  anchor, never going near the setter. The leftover came straight back, at an
  arbitrary size, and no amount of snapping at creation could reach it.

  THAT IS ALSO WHY IT LOOKED FIXED FROM HERE. A headless run has no saved
  window position to restore, so the grid kept its snapped height and the band
  was genuinely gone -- on a machine whose window was the wrong size to show
  the defect. NY4I's was not.

  IT ALSO ARGUED WITH A DECISION ALREADY RECORDED. CheckEditableWindowHeight
  says, of the loop that used to make whole rows fit: "THE QUESTION ITSELF IS
  RETIRED. The list scrolls now, so there is no reason to make a whole number
  of rows fit." That is right. The grid is allowed a fractional height; what it
  is not allowed to do is leave the remainder unpainted.

  TLogGrid.Paint fills it now -- see there. One mechanism, at the layer that
  cannot be bypassed. *)

procedure TR4WEditableLogSetBounds(const aLeft, aTop, aWidth, aHeight: integer);
begin
   if TR4WEditableLog = nil then
      begin
      Exit;
      end;

   (* THROUGH THE LCL, and there is no other way now: the grid has no window
     handle for anything to reposition behind its back. *)
   TR4WEditableLog.SetBounds(aLeft, aTop, aWidth, aHeight);

   (* AND THEN SNAPPED TO A WHOLE NUMBER OF ROWS, WHICH IS THE BAND NY4I HAS
     BEEN POINTING AT SINCE 2026-09-09.

     A grid draws whole rows and leaves whatever is over. Measured on his Mint
     box: the grid was 125 pixels of client with a row height of 19, so six
     rows filled 114 and ELEVEN PIXELS AT THE BOTTOM belonged to no row. gtk2
     paints that strip in the theme's own background rather than the grid's
     colour, so a grey band ran the full width of the window immediately below
     the last QSO -- indistinguishable from a scroll-bar trough, which is
     exactly what it was reported as, five times.

     THE HEIGHT IT WAS GIVEN CAME FROM WIN32 ARITHMETIC. The caller asks for
     `30 + LinesInEditableLog * (ws + 2)`, where 30 was an allowance for a
     list view's header and border. This grid's header is a REAL ROW of
     DefaultRowHeight, so the allowance is 19 here and 30 leaves a remainder.

     FIXED HERE RATHER THAN AT THE CALLER, and that is deliberate: the caller
     would have to know the row height, the fixed-row count and the border
     inset, and the border inset is a widget-set answer -- 0 on gtk2, non-zero
     on Win32. The control knows all three. Asking it to round DOWN to a whole
     number of rows is correct on every platform without anyone having to know
     which one they are on.

     NOTHING BELOW MOVES OUT OF PLACE. MainUnit reads EditableLogHeight back
     from this control immediately afterwards and positions every row of status
     panels relative to it, so the window closes up by the leftover instead of
     opening a gap. *)
end;

procedure TR4WEditableLogScrollToEnd;
begin
   if TR4WEditableLog = nil then
      begin
      Exit;
      end;

   TR4WEditableLog.ScrollToEnd;

   (* WHERE THE VIEW ACTUALLY ENDED UP. "The grid did not update" and "the new
     row is below the bottom edge" look identical on screen and have nothing in
     common as causes. *)
   if logger <> nil then
      begin
      logger.Debug('[EditableLog] scrolled: rows=%d selected=%d topRow=%d visible=%d',
                   [TR4WEditableLog.RowCount, TR4WEditableLog.Row,
                    TR4WEditableLog.TopRow, TR4WEditableLog.VisibleRowCount]);
      end;
end;

function TR4WEditableLogSelectedRecord: Int64;
begin
   Result := -1;
   if TR4WEditableLog <> nil then
      begin
      Result := TR4WEditableLog.SelectedRecord;
      end;
end;

procedure TR4WEditableLogSelectRecord(const aIndex: Int64);
begin
   if TR4WEditableLog <> nil then
      begin
      TR4WEditableLog.SelectedRecord := aIndex;
      end;
end;

procedure TR4WEditableLogFocus;
begin
   if (TR4WEditableLog <> nil) and TR4WEditableLog.CanFocus then
      begin
      TR4WEditableLog.SetFocus;
      end;
end;

function TR4WEditableLogVisible: boolean;
begin
   Result := (TR4WEditableLog <> nil) and TR4WEditableLog.Visible;
end;

procedure TR4WEditableLogShow(const aVisible: boolean);
begin
   if TR4WEditableLog <> nil then
      begin
      TR4WEditableLog.Visible := aVisible;
      end;
end;

function TR4WEditableLogBoundsHeight: integer;
begin
   Result := 0;
   if TR4WEditableLog <> nil then
      begin
      Result := TR4WEditableLog.Height;
      end;
end;

(* THE CALLSIGN IN ONE ROW, read from the log rather than from the display.

  LOGEDIT asked the list view for the text it had already painted
  (ListView_GetItemText). A grid that holds no rows cannot answer that, and it
  was the wrong question anyway -- the answer it wanted is in the log. *)
function TR4WEditableLogCallsignAt(const aIndex: Int64): string;
var
   rows: array[0 .. 0] of TLogGridRow;
begin
   Result := '';
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   rows[0].Valid := False;
   TR4WMainForm.MainLogFetchRows(nil, aIndex, rows);
   if rows[0].Valid then
      begin
      Result := rows[0].Text[logColCallsign];
      end;
end;

procedure CreateTR4WPossibleCallList(const aLeft, aTop, aWidth, aHeight,
                                     aId, aItemHeight, aColumnWidth: integer);
begin
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   with TR4WMainForm.lstPossibleCall do
      begin
      (* THE COLOURS, which RefreshMainWindowElementColors does not apply:
         its loop skips anything with mweiStyle <= 2 and this element has 0.
         Without them the LCL would answer WM_CTLCOLORLISTBOX from the form
         default rather than from the table, which is the regression that
         forwarding the message would otherwise introduce. *)
      Color      := tr4wColorsArray[TWindows[mwePossibleCall].mweBackG];
      Font.Color := tr4wColorsArray[TWindows[mwePossibleCall].mweColor];

      // WM_MEASUREITEM, which the main window proc used to answer with
      // `itemHeight := ws` for this one control id.  A property, and that arm is
      // deleted.
      DefaultRowHeight := aItemHeight;

      (* LB_SETCOLUMNWIDTH IS BACK, LITERALLY.

        This briefly went through TListBox.Columns -- "the LCL says how MANY
        columns and divides the client width" -- which was a faithful reading
        of the LCL documentation and worked on exactly one widget set.
        TWin32WSCustomListBox implements SetColumnCount; gtk2 does not declare
        it, gtk3 declares it with an EMPTY body, and Qt declares it with the
        body commented out under a {$note implement} pragma. Only Win32 has
        ever laid a TListBox out in columns.

        A TDrawGrid takes the column width directly, which is what the Win32
        message did, so the arithmetic is gone rather than reproduced. *)
      if aColumnWidth > 0 then
         begin
         DefaultColWidth := aColumnWidth;
         end;

      SetBounds(aLeft, aTop, aWidth, aHeight);

      (* RE-CAPTURE THE ANCHOR BASE, AND THIS IS NOT OPTIONAL FOR THIS CONTROL.

        An anchored control does not remember a rule, it remembers a MEASUREMENT:
        BaseBounds, plus the BaseParentClientSize they were taken against. The
        LCL then reproduces that distance whenever the parent resizes.

        lstPossibleCall is the only bottom-anchored control on this form that is
        DESIGNED rather than built in code, so its base was captured by the
        streamer against the .lfm's ClientHeight of 370 -- and the SetBounds
        above then moved it to a runtime position the base knows nothing about.
        Measured on the bench 2026-09-08, the stored gap to the bottom was

            370 (design ClientHeight) - 458 (runtime bottom) = -88

        so the strip tracked the window's bottom edge perfectly and sat 88
        pixels BELOW the client area, off screen, at every size. The entry
        fields are unaffected because they are created in code and have no
        design-time base to be stale.

        UpdateBaseBounds(True, True, False) stores the bounds AND the parent
        client size as they are now, which is what makes the anchor mean what
        the arithmetic above just said. *)
      UpdateBaseBounds(True, True, False);

      // NO ITEM TEXT is set anywhere, and that is faithful rather than lazy.
      // The Win32 control was created WITHOUT LBS_HASSTRINGS: LB_ADDSTRING's
      // lParam was item DATA, not a string, and the owner-draw never read it
      // either -- it indexes PossibleCallList by the item's ORDINAL.  This
      // list's whole job is to have the right NUMBER of items.  Giving them
      // captions would invent a second source of truth for what each row says.
      end;
end;


procedure CreateTR4WEntryField(const aLeft, aTop, aWidth, aHeight: integer;
                               const aId: integer;
                               const aBorder: boolean;
                               const aField: TTR4WEntryField;
                               const aFontName: string = '';
                               const aFontHeight: integer = 0;
                               const aFontBold: boolean = False);
var
   edit: TEdit;
begin
   edit := TEdit.Create(TR4WMainForm);
   edit.Parent := TR4WMainForm;

   // The style bits CreateWindowExW used to pass, one by one:
   //   ES_UPPERCASE   -> CharCase
   //   WS_TABSTOP     -> TabStop
   //   ES_AUTOHSCROLL -> AutoSize False + no word wrap; a single-line TEdit
   //                     scrolls horizontally by default
   //   ES_NOHIDESEL   -> HideSelection False, so the selection stays visible
   //                     when focus moves. Contest logging depends on it: the
   //                     operator must see what is selected while the caret is
   //                     in the other field.
   //   WS_EX_STATICEDGE, conditional on NOT Config.NoBorder -> BorderStyle
   edit.CharCase := ecUpperCase;
   edit.TabStop := True;
   edit.HideSelection := False;

   // AutoSelect OFF.  This is an LCL behaviour with no Win32 counterpart, not a
   // style bit being translated: TCustomEdit.Create sets FAutoSelect := True
   // (customedit.inc:81) and then SelectAll's on DoEnter and on the first left
   // click after focus (:632, :526).  A raw Win32 edit never did that outside a
   // dialog, and TR4W is not a dialog -- it owns its own caret placement
   // (PlaceCaretToTheEnd, and the EM_SETSEL calls in MainUnit around 5380 /
   // 5385 / 5511) and decides for itself whether an exchange is selected for
   // overtype or appended to.
   //
   // Left True it selects the exchange the operator has already typed, and
   // ES_NOHIDESEL -- which IS faithful, VC.pas:2197 -- then keeps that block
   // painted after focus leaves.  NY4I on the bench, 2026-08-18: the exchange
   // field showed "20" reverse-video where D7 shows plain text and a caret.
   // The next character typed would have replaced the exchange instead of
   // extending it, so this was a data defect, not a colour one.
   edit.AutoSelect := False;

   edit.AutoSize := False;
   if aBorder then
      begin
      edit.BorderStyle := bsSingle;
      end
   else
      begin
      edit.BorderStyle := bsNone;
      end;

   // AutoSize False BEFORE SetBounds. LCL controls autosize by default and FMX
   // ones do not, so a streamed or assigned Height is silently overridden --
   // this tree has paid for that once already.
   edit.SetBounds(aLeft, aTop, aWidth, aHeight);

   // The control id is what test/ui/Test-Typing.ps1 and every other instrument
   // finds these fields by, and what the dialog-item helpers use. A TEdit does
   // not set one, so it is applied to the handle directly.
   // THE KEYBOARD ARMS, ATTACHED TO THE CONTROL -- Phase 3c.  These behaviours
   // lived in the GetMessage loop and dispatched by comparing Msg.HWND against
   // wh[mweCall] / wh[mweExchange].  A named handler per field, chosen HERE at
   // creation from an explicit parameter: nothing branches on Sender, and the
   // handler for a field cannot be reached by the other one.
   if aField = efCall then
      begin
      edit.OnKeyPress := EntryEvents.CallKeyPress;
      edit.OnKeyDown  := EntryEvents.CallKeyDown;
      edit.OnKeyUp    := EntryEvents.CallKeyUp;
      edit.OnChange   := EntryEvents.CallChange;
      edit.OnEnter    := EntryEvents.CallEnter;
      edit.OnExit     := EntryEvents.CallExit;
      TR4WCallEdit := edit;
      end
   else
      begin
      edit.OnKeyPress := EntryEvents.ExchangeKeyPress;
      edit.OnKeyDown  := EntryEvents.ExchangeKeyDown;
      edit.OnKeyUp    := EntryEvents.ExchangeKeyUp;
      edit.OnChange   := EntryEvents.ExchangeChange;
      edit.OnEnter    := EntryEvents.ExchangeEnter;
      TR4WExchangeEdit := edit;
      end;

   // THE OBJECT IS KEPT, not only its handle.  Nothing reads these two yet;
   // they exist because Phase 7 cannot write TR4WMainForm.edtCall.Text while
   // the only thing this function returns is an HWND.
   { THE FONT BEFORE THE HANDLE, and the ordering is the whole point.

     Assigning Font to a TEdit RECREATES its handle. Doing it after the line
     below would discard the GWL_ID applied there and leave the HWND this
     function returned pointing at a destroyed window -- Test-Typing.ps1 caught
     exactly that: "no control with id 73 (the callsign window)". }
   if aFontName <> '' then
      begin
      edit.Font.Name   := aFontName;
      edit.Font.Height := -aFontHeight;
      if aFontBold then
         begin
         edit.Font.Style := [fsBold];
         end;
      end;

   (* THE DIALOG CONTROL ID IS FOR THE UI TEST HARNESSES, and it is the reason
     this raw call stays.

     An LCL control has no dialog id -- nothing in TR4W asks for one, and the
     last GetDlgItem against this window went with the Win32 children. But two
     harnesses drive the real binary and find these fields the only way an
     outside process can, by walking EnumChildWindows and reading
     GetDlgCtrlID: tr4w/test/ui/Test-Typing.ps1 and Test-CountyLineEntry.ps1,
     both looking for 73 (callsign) and 88 (exchange), the ids VC.pas declares.

     Delete this line and both tests fail with "no control with id 73" -- which
     is exactly how it was found the first time, when assigning Font after this
     line recreated the handle and threw the id away. There is no LCL property
     for it; the id is a Win32 window attribute and the harness is a Win32
     client.

     GATED, because the harnesses are Windows too -- Test-Typing.ps1 is
     PowerShell calling user32. On macOS or Linux there is neither a dialog id
     nor a script asking for one.

     AUTOIT CAN ADDRESS THESE FIELDS WITHOUT THIS LINE, so it is a real option
     and not a dead end. NY4I is trialling it (2026-09-06) and demonstrated it
     against a running v5.0.2.

     Half of that is worth stating carefully, because an earlier version of this
     comment got it wrong in both directions. AutoIt's ControlID *is*
     GetDlgCtrlID, so its id-based targeting does die with this line. But its
     OTHER way of naming a control, ClassNameNN, does not -- a TEdit is a NATIVE
     Win32 EDIT control under the win32 widgetset, so AutoIt sees class 'Edit'
     and can take the callsign field as instance 2 of it. The claim that "every
     LCL control reports the class Window" was an over-generalisation from the
     FORM's class and is false for this control.

     MEASURED on the running program, 2026-09-06, by attaching
     test\ui\Dump-WindowTree.ps1 to it -- 167 windows in the process:

       Window  140     (the form and every TElementPanel)
       Button    8
       Edit      4     id 1001, 1001 on the DX Cluster window
                       id   88 (exchange), 73 (callsign) on the main window

     WHAT THE ID BUYS IS THE FAILURE MODE, NOT THE ACCESS. An instance number is
     ENUMERATION ORDER, and enumeration order here is not creation order: this
     unit is asked for the callsign field first (MainUnit calls for mweCall
     before mweExchange) and the callsign field enumerates SECOND. The number is
     a z-order artifact.

     That matters because of the trap documented forty lines above -- assigning
     Font after this line RECREATES the handle. A recreated handle moves in the
     z-order, so the same event that produced "no control with id 73 (the
     callsign window)" and pointed straight at the cause would instead silently
     renumber the instances. Keystrokes would land in the exchange field,
     ExchangeWindowKeyDownProc does not emit the trace Test-Typing.ps1 asserts
     on, and the test would fail as "the keyboard is not routed" -- true-looking,
     loud, and aimed at the wrong subsystem.

     So this is a trade, not an impossibility: an id fails truthfully, an
     instance fails misleadingly, and the id costs one gated line.

     WHAT DOES RETIRE THIS LINE is an in-process channel, because the id is
     only half of what ties the harness to Windows. The other half is
     PostMessage(WM_CHAR), which has no macOS or Linux equivalent at all --
     gating the id alone buys no portability, it only makes a Windows-only
     dependency compile cleanly elsewhere.

     /FIELDCHECK is the shape to copy (uProgramMain.pas -> RunEditQSOFieldCheck
     in uEditQSOForm): it puts values through LCL controls directly, reports
     through an exit code and a text file, and touches no window handle, so it
     would run unchanged on any platform. uWebSocketServer -- transport only,
     no TCI knowledge -- is the intended carrier for the same idea driven from
     outside. When Test-Typing.ps1 and Test-CountyLineEntry.ps1 stop walking
     child windows this goes entirely rather than staying behind a gate. *)
   (* edit.Handle READ HERE, inside the gate, rather than into a Result the
     caller never wanted. This used to be `Result := edit.Handle` forty lines
     up, which made every caller hold an HWND so that this one Windows-only
     line could have one -- and the only place any of them went was wh[], which
     nothing read. Reading it here still forces handle creation at the same
     point in the sequence, so the font-before-handle ordering above is
     unaffected. *)
   {$IFDEF WINDOWS}
   Windows.SetWindowLong(edit.Handle, GWL_ID, aId);
   {$ENDIF}
end;

procedure ShowTR4WMainForm;
var
   want: TRect;   { the bounds the program asked for, in the form's own units }
begin
   if not Assigned(TR4WMainForm) then
      begin
      Exit;
      end;

   (* ASK THE FORM WHAT THE PROGRAM WANTS, NOT THE WINDOW.

     This used to begin with

       Windows.GetWindowRect(TR4WMainForm.Handle, r);
       TR4WMainForm.SetBounds(r.Left, r.Top, ...);

     and that line is what stopped the main window coming back where the
     operator left it. MEASURED, from NY4I's log (2026-09-06):

       [MainPos] RESTORE asked for (2201,270,3213,734); form is at (0,30,1012,494)
       [MainPos] SHOWN     at      (0,30,1028,553);  form BoundsRect=(0,30,1012,494)

     A HIDDEN LCL FORM DOES NOT REALIZE ITS BOUNDS IMMEDIATELY. Assigning
     BoundsRect updates the form; the HWND is moved when the form is shown.
     RestoreMainWindowBounds had just set 2201,270 and this ran BEFORE the show
     -- so GetWindowRect answered for a window still at the designed 0,30, and
     SetBounds wrote that back INTO the form. The restore was overwritten by a
     measurement of the thing it had not yet been applied to, and the
     SetWindowPos below pinned the window there so nothing could recover it.

     It was wrong in its units as well: 1028x553 is the OUTER rect, and the
     form's own bounds for the same window are 1012x494. Feeding an outer size
     to SetBounds is what grew the function-key window by its frame on every
     restart -- see the note in LclFormFor -- and this was that mistake on the
     main window.

     AND ITS PREMISE HAD EXPIRED. It said the LCL's bounds were "still the
     placeholder CreateNew was given", because CreateMainWindow,
     CheckEditableWindowHeight and SetWindowSize all sized this window with a
     raw SetWindowPos on tr4whandle. None of them does now: the form is built
     with Create and its .lfm, MakeMainWindowResizeable sizes it through
     Width / ClientHeight / Constraints, CheckEditableWindowHeight sizes the LOG
     control, and SetWindowSize only computes metrics. The log says so too --
     the form's bounds before the restore were the real 1012x464, not the .lfm's
     806x370.

     So the geometry the program wants is what the FORM holds. Read it, show,
     and put it back if the framework adjusted it -- through BoundsRect, in the
     form's own units, which is the one thing the old code was right about:
     showing the form makes the LCL apply menu height and border metrics of its
     own, and TR4W's layout is computed from the font-size setting and is not a
     number the framework can improve on. *)
   want := TR4WMainForm.BoundsRect;

   TR4WMainForm.Visible := True;

   (* FIELD BY FIELD, not EqualRect: `Windows` is first in this unit's uses
     clause, so an unqualified EqualRect binds to the user32 entry point rather
     than to the RTL's -- a Win32 call for four integer comparisons, and the
     kind that only shows up when someone counts them. *)
   if (TR4WMainForm.BoundsRect.Left   <> want.Left)  or
      (TR4WMainForm.BoundsRect.Top    <> want.Top)   or
      (TR4WMainForm.BoundsRect.Right  <> want.Right) or
      (TR4WMainForm.BoundsRect.Bottom <> want.Bottom) then
      begin
      TR4WMainForm.BoundsRect := want;
      end;
end;


procedure CreateTR4WMainForm;
begin
   // Create, NOT CreateNew.  CreateNew deliberately does not load a .lfm, and
   // that is what made this form unopenable in the designer.
   //
   // Everything that used to be assigned here is now IN uMainForm.lfm, which is
   // the point of the change rather than a side effect:
   //   BorderStyle bsSingle + BorderIcons [biSystemMenu, biMinimize]
   //       -- the style bits CreateWindowExW passed (WS_SYSMENU or
   //          WS_MINIMIZEBOX, no WS_THICKFRAME or WS_MAXIMIZEBOX).  The
   //          operator could never resize this window by dragging and still
   //          cannot.
   //   Color clBtnFace
   //       -- matches the class brush the registered window class carried,
   //          tr4wBrushArray[TWindows[mweWholeScreen].mweBackG].  A form paints
   //          its own background and would otherwise take the LCL default.
   //   ShowInTaskBar stAlways
   //       -- the Win32 window got a taskbar button for free as a plain unowned
   //          top-level window.  An LCL form is owned by the hidden Application
   //          window, and an owned window is not a taskbar candidate unless it
   //          says so.  stDefault would only work for Application.MainForm, and
   //          TR4W has none: Application.CreateForm is never called because
   //          Application.Run is never called (the hand-rolled loop still owns
   //          the program).
   //   Position poDesigned and the bounds
   //       -- placeholders.  CreateMainWindow calls SetWindowPos immediately
   //          afterwards with the real geometry, which it can only compute once
   //          the editable-log ListView exists and has been measured.
   TR4WMainForm := TTR4WMainForm.Create(nil);

   (* THE DESIGNED PANELS ARE NOW MATCHED TO THEIR ELEMENTS. Before anything
     asks for one -- CreateMainElement, SetMainWindowText, the colour pass --
     because every one of those looks the element up in GElements. *)
   BindMainElements;

   (* THE DETECTOR THE SetMainWindowText FUNNEL USED TO BE. Injected rather
     than referenced, so uElementPanel stays a leaf the lintlfm checker can
     link -- see TElementOffThreadReport. *)
   ElementOffThreadReport := @ReportElementOffThread;
   ElementCaptionChanged  := @RequestElementColourRefresh;
   ElementOverflowReport  := @ReportElementOverflow;

   (* FORCE THE WINDOW INTO EXISTENCE, and say so.

     This read `Result := TR4WMainForm.Handle` under the comment "Touching
     Handle is what forces the window to exist" -- the RESULT was incidental and
     the SIDE EFFECT was the point, which is exactly what HandleNeeded is for.
     Nothing wants the handle any more.

     A note about installing TR4W's window procedure in front of the LCL's used
     to follow. There is no subclass. *)
   TR4WMainForm.HandleNeeded;

   (* THE MENU IS THE FORM'S, built from T_MENU_ARRAY as a TMainMenu.

     Was SetMenu(Result, aMenu) with an HMENU built by CreateTR4WMenu and
     handed in. A native menu reports a click as WM_COMMAND to its owner
     window, which is why this form had a window procedure in front of it;
     a TMenuItem raises OnClick. *)
   TR4WMainForm.InstallMenu;
end;


{ ---------------------------------------------------------------------------
  THE ENTRY FIELDS.  Ordinary LCL property access, as of round 2.

  THEY WERE WIN32 UNTIL NOW, AND THE REASON IS WORTH KEEPING.  Round 1 named the
  controls at nineteen call sites but had to reach them through their HANDLES,
  because the radio polling thread did UI work directly:

         pFactoryRadio -> UpdateStatus -> ProcessFilteredStatus
                       -> SetOpMode(SearchAndPounceOpMode)  [uRadioPolling:881]
                          -> tCallWindowSetFocus ...

  Every Win32 original was SAFE BY ACCIDENT from a worker thread -- InvalidateRect
  posts, a cross-thread SetFocus fails harmlessly, a cross-thread SendMessage
  blocks but works -- and every LCL equivalent is unsafe there.  TR4W crashed at
  contest-open three times before that was found, and found nothing in the log
  each time.

  WHAT MADE THE FLIP SAFE, in order, because no single step would have:

    1. uMainThreadWork -- the polling thread now REQUESTS its UI work and the
       main thread performs it.
    2. The worker-thread guard -- tCreateThread routes through BeginThread and
       reports faults, so a mistake here is a log line rather than a vanished
       process.
    3. THE PROGRAM SAID SO, RATHER THAN ME.  EntryUsable names every distinct
       off-main-thread caller, and a full bench session with a K4 produced none
       (NY4I, 2026-08-23).  That is what licensed this change: "I traced the
       callers" is precisely the claim that was wrong three times.

  THE THREAD CHECK STAYS, and is not scaffolding left behind.  A clean session
  proves the paths that ran, not the paths that exist -- an untried contest mode
  or an unplugged radio family can still reach these, and now that they are LCL
  the consequence is a crash instead of a harmless no-op.  It costs one thread-id
  compare on a path already doing string work, and it reports each caller once.

  THE NIL GUARD ALSO STAYS, and it is the more dangerous of the two.  A headless
  /EXPORT boots the contest, writes the files and halts before any GUI, so these
  objects are NIL there.  The Win32 calls were silent no-ops on handle 0; direct
  property access took the golden corpus from 22/0/4 to 0/26 in one step, dying
  so early that not even the startup breadcrumbs ran.
  --------------------------------------------------------------------------- }

{ The single funnel: both guards, in one place, for every accessor below.
  TWinControl rather than TEdit so the possible-call list shares it -- a second
  copy would be a second place for the HandleAllocated half to get lost, which
  is exactly how the 2026-08-23 startup crash happened. }
function ControlUsable(const aCtrl: TWinControl): boolean;
begin
   if not OnMainThread then
      begin
      // LOGS, does not raise: an exception on a worker thread is the failure
      // mode being removed, not a way to report it.  Deduped by caller.
      ReportOffMainThread('entry field accessor', get_caller_addr(get_frame));
      end;

   // HandleAllocated, NOT just non-nil, AND THIS WAS A REGRESSION.
   //
   // The handle-based EntryHandle this replaced tested BOTH, and dropping the
   // second half while "simplifying" the guard is how TR4W crashed on startup
   // on 2026-08-23 (NY4I: "we seem to have a fragility issue here").  A TEdit
   // exists from the moment it is constructed, but its WINDOW does not: the LCL
   // creates that lazily.  .Text is happy either way, which is what made the
   // omission look harmless -- but SelStart, SelLength and SetFocus are not,
   // and those are reached from CallWindowChange, i.e. from INSIDE A WINDOW
   // PROCEDURE, where a raised exception is a fatal process kill (see the guard
   // on WindowProc).  The Win32 originals were no-ops on handle 0.
   Result := (aCtrl <> nil) and aCtrl.HandleAllocated;
end;

function EntryText(const aEdit: TEdit): string;
begin
   Result := '';
   if not ControlUsable(aEdit) then
      begin
      Exit;
      end;
   Result := aEdit.Text;
end;

procedure SetEntryText(const aEdit: TEdit; const aText: string);
begin
   if not ControlUsable(aEdit) then
      begin
      Exit;
      end;
   aEdit.Text := aText;
end;

{ aLength < 0 selects to the end, which is what EM_SETSEL with -1 meant. }
procedure SetEntrySel(const aEdit: TEdit; const aStart, aLength: integer);
begin
   if not ControlUsable(aEdit) then
      begin
      Exit;
      end;

   aEdit.SelStart := aStart;
   if aLength < 0 then
      begin
      aEdit.SelLength := Length(aEdit.Text) - aStart;
      end
   else
      begin
      aEdit.SelLength := aLength;
      end;
end;

function EntrySelStart(const aEdit: TEdit): integer;
begin
   Result := 0;
   if not ControlUsable(aEdit) then
      begin
      Exit;
      end;
   Result := aEdit.SelStart;
end;

function EntrySelLength(const aEdit: TEdit): integer;
begin
   Result := 0;
   if not ControlUsable(aEdit) then
      begin
      Exit;
      end;
   Result := aEdit.SelLength;
end;

procedure FocusEntry(const aEdit: TEdit;
                     const aBringForward: boolean = False);
var
   frm: TCustomForm;
begin
   if not ControlUsable(aEdit) then
      begin
      Exit;
      end;

   { CanFocus ALONE WAS NOT ENOUGH, and NY4I's CW session proved it: eighteen
     times, the window-procedure guard caught

         EInvalidOperation: [TCustomForm.SetFocus] TR4WMainForm Can not focus
           FOCUSENTRY -> TCALLWINDOWSETFOCUS -> WINDOWPROCBODY msg $7

     -- WM_SETFOCUS on the main window, whose handler pushes focus into the call
     field.  CanFocus asks about the CONTROL; TWinControl.SetFocus then walks up
     and focuses the FORM, and TCustomForm.SetFocus raises when the form is
     neither active nor visible-and-enabled (customform.inc:395).  Read there,
     not guessed: that is the startup and hidden-window case, which is exactly
     when a WM_SETFOCUS arrives.

     SO ASK THE FORM, AND WHEN IT CANNOT TAKE FOCUS, RECORD THE INTENT INSTEAD
     OF DEMANDING IT.  ActiveControl is the LCL's own mechanism for "focus this
     when you can", and SetActiveControl only validates while the form is
     visible (customform.inc:1859), so assigning it to a form that has not been
     shown is both safe and exactly right.  The Win32 SetFocus this replaced
     failed silently in the same situation -- this restores that behaviour
     without restoring the silence. }
   frm := GetParentForm(aEdit);
   if frm = nil then
      begin
      Exit;
      end;

   if not frm.IsVisible then
      begin
      frm.ActiveControl := aEdit;
      Exit;
      end;

   if (frm.Active or (frm.IsControlVisible and frm.Enabled)) and
      aEdit.CanFocus                                          then
      begin
      aEdit.SetFocus;
      end;

   { ISSUE 131 (NY4I), CARRIED ACROSS RATHER THAN DROPPED.

     tExchangeWindowSetFocus found that SetFocus returned ACCESS DENIED under
     CW-by-CAT and added SetForegroundWindow as a fallback -- a real bug fixed
     against real symptoms, so it is not discarded just because the conversion
     would be tidier without it.  BringToFront is the LCL's SetForegroundWindow.

     OPT-IN, because only the exchange path ever had it.  Giving it to every
     caller would mean TR4W could pull itself to the foreground while the
     operator is in another application -- a new behaviour, on a path that never
     asked for it.

     Focused is asked AFTER the attempt above, so the fallback costs nothing on
     the normal path. }
   if aBringForward and (not aEdit.Focused) then
      begin
      frm.BringToFront;
      if aEdit.CanFocus then
         begin
         aEdit.SetFocus;
         end;
      end;
end;

{ THE ENTRY FIELDS' COLOURS ARE PROPERTIES NOW, NOT A WM_CTLCOLOR ARM.

  Assigning Color also clears ParentColor, which is what we want: these two
  fields are coloured from TWindows[] and from the operating mode, not from
  whatever the form is painted with.  Assign only on a CHANGE -- a TColor
  setter invalidates, and SetOpMode runs on every mode toggle. }
procedure SetEntryColors(const aEdit: TEdit; const aBack, aText: TColor);
begin
   if not ControlUsable(aEdit) then
      begin
      Exit;
      end;

   if aEdit.Color <> aBack then
      begin
      aEdit.Color := aBack;
      end;

   if aEdit.Font.Color <> aText then
      begin
      aEdit.Font.Color := aText;
      end;
end;


{ ---------------------------------------------------------------------------
  THE POSSIBLE-CALL LIST.

  lstPossibleCall is an LCL TListBox and has been since Phase 3b -- it is
  declared in uMainForm.lfm and drawn by the form's own OnDrawItem.  What was
  still Win32 was every OPERATION on it: LB_RESETCONTENT, LB_ADDSTRING,
  LB_SETCURSEL, LB_GETCURSEL and LB_GETCOUNT, sent to wh[mwePossibleCall] from
  three different units.

  THE ITEMS CARRY NO DATA, AND THAT IS NOT AN OVERSIGHT.  The list is
  owner-drawn and PossibleCallsDrawItem indexes PossibleCallList.List[] by the
  item's POSITION, so the lParam the old LB_ADDSTRING passed was never read.
  The model is PossibleCallList; the listbox only has to agree with it on how
  many rows there are and which one is current.  Adding an empty string is
  therefore the faithful translation, not a shortcut.
  --------------------------------------------------------------------------- }

(* HOW MANY CALLS THE STRIP IS SHOWING.

  A GRID HAS NO Items.Count, and its ColCount cannot answer this: a TDrawGrid
  has a minimum of one column whether or not anything is in it, so an empty
  strip and a strip holding one call are indistinguishable from the control.
  The listbox could answer because zero items is a legal state for it.

  Kept beside the accessors that maintain it rather than derived, because the
  alternative -- asking PossibleCallList.NumberPossibleCalls -- would make the
  control and the model agree by ACCIDENT. They are filled by two different
  routines and the whole point of AddPossibleCall's return value is that the
  caller is told where its row landed. *)

(* NIL IS THE ONLY THING THAT DISQUALIFIES THIS CONTROL -- NOT ControlUsable.

  AND THAT DISTINCTION BROKE THE FEATURE FOR ONE BUILD. ControlUsable tests
  HandleAllocated, and the LCL creates a control's window LAZILY AND ONLY FOR
  A VISIBLE CONTROL. The moment the strip learned to hide itself when empty,
  every accessor that guarded with ControlUsable started returning early on a
  hidden strip -- so AddPossibleCall never added a column, and the possible
  calls stopped appearing at all. NY4I, 2026-09-10: "regression. Now the
  possible calls do not work. They worked before this change."

  ControlUsable IS RIGHT WHERE IT IS USED, and its own comment says why: the
  entry fields need a real window for SelStart, SelLength and SetFocus, and
  dropping the handle test there crashed TR4W on startup once already.

  NOTHING THIS STRIP DOES NEEDS A WINDOW. ColCount, Col, Visible, Font and
  Invalidate are all LCL-side properties that work on a control that has never
  been shown -- and Visible is the one that CREATES the handle, so demanding a
  handle before setting it is backwards. *)
function PossibleCallListBox: TStringGrid;
begin
   Result := nil;
   if TR4WMainForm = nil then
      begin
      Exit;
      end;
   Result := TR4WMainForm.lstPossibleCall;
end;

procedure ClearPossibleCalls;
var
   lb: TStringGrid;
begin
   SetLength(GPossibleDupe, 0);

   lb := PossibleCallListBox;
   if lb = nil then
      begin
      Exit;
      end;

   (* ONE COLUMN, NOT ZERO -- the grid will not accept zero. It is empty and
     hidden, so nothing is drawn from it. *)
   lb.ColCount := 1;
   lb.Cells[0, 0] := '';

   (* AND HIDDEN, WHICH IS THE FIX FOR "a horizontal scroll bar for no
     reason".

     NOTHING HAS EVER HIDDEN THIS STRIP. It sat on the main window at all
     times, empty for all but a few hundred milliseconds per callsign, and an
     empty control still paints itself: as a TListBox that was a sunken
     rectangle the width of the strip, which NY4I reported four times as a
     horizontal scroll bar, and after the grid conversion it was a bordered
     cell in the same place. Same defect wearing two widgets.

     WHY WINDOWS NEVER SHOWED IT. There the empty listbox drew in the form's
     own colour with no visible frame, so it was invisible rather than absent.
     GTK draws a themed, recessed widget whether or not it has content.

     THE PROBE THAT FOUND IT RULED THE OBVIOUS ANSWER OUT FIRST:
     TR4WMainForm.HorzScrollBar.IsScrollBarVisible never became True, and no
     child ever extended past the client area -- 0 of 118 on every tick. It
     was never a scroll bar at all. *)
   lb.Visible := False;
   lb.Invalidate;
end;

(* ONE CANDIDATE, TEXT AND ALL.

  IT TAKES THE CALLSIGN NOW. It used to take nothing and add an empty string,
  leaving the text in a global for a paint handler to find -- see
  lstPossibleCallPrepareCanvas for the four defects that followed from a
  control holding no data. *)
function AddPossibleCall(const aCall: string;
                         const aDupe: boolean): integer;
var
   lb: TStringGrid;
begin
   Result := -1;
   lb := PossibleCallListBox;
   if lb = nil then
      begin
      Exit;
      end;

   Result := Length(GPossibleDupe);
   SetLength(GPossibleDupe, Result + 1);
   GPossibleDupe[Result] := aDupe;

   lb.ColCount := Length(GPossibleDupe);
   (* LclText, NOT a plain assignment. A grid cell is the LCL's AnsiString
     holding UTF-8 and this unit's string is UTF-16, so the assignment would
     narrow silently -- which is what the narrowing ceiling exists to keep
     visible. UTF-16 to UTF-8 loses nothing; saying so here is the point. *)
   lb.Cells[Result, 0] := AnsiString(LclText(aCall));

   (* SHOWN ONLY WHEN IT HAS SOMETHING TO SHOW -- see ClearPossibleCalls. *)
   lb.Visible := True;
end;

function PossibleCallCount: integer;
begin
   Result := Length(GPossibleDupe);
end;

{ -1 when nothing is selected -- the same value LB_GETCURSEL returned as
  LB_ERR, so callers that test for it are unchanged. }
function SelectedPossibleCall: integer;
var
   lb: TStringGrid;
begin
   Result := -1;
   lb := PossibleCallListBox;
   if (lb = nil) or (Length(GPossibleDupe) = 0) then
      begin
      Exit;
      end;

   (* THE GRID ALWAYS HAS A CURRENT COLUMN and a listbox did not always have a
     current item, so the empty case is answered above rather than by the
     control. Without that, an empty strip would report column 0 as selected
     and a caller would read a callsign out of a list that has none. *)
   Result := lb.Col;
end;

{ CALL THIS AFTER REBUILDING THE LIST, AND IT IS NOT OPTIONAL.

  The rows carry no text -- the model is PossibleCallList and the owner-draw
  reads it by ordinal -- so after a refresh the listbox's OWN content is
  byte-identical to what it held before: the same N empty strings.  Nothing in
  it changed, so nothing invalidates, so OnDrawItem is not called again and the
  operator keeps seeing the PREVIOUS callsigns.  NY4I, 2026-08-24: "scp updated
  the first time but subsequent calls did not change from the prior values."

  THE WIN32 VERSION GOT THIS BY ACCIDENT, which is why the conversion lost it.
  LB_ADDSTRING's lParam was the item DATA and every row got a different value,
  so the items genuinely differed and the control repainted itself.  The note
  on CreateTR4WPossibleCallList -- "the owner-draw never read it either" -- was
  true and beside the point: the DRAW handler ignored that data, but the
  CONTROL did not.

  A control whose data lives outside it has to be told when that data moves.
  One Invalidate per rebuild is cheaper than the item data ever was, and it
  keeps PossibleCallList as the single source of truth. }
procedure PossibleCallsUpdated;
var
   lb: TStringGrid;
begin
   lb := PossibleCallListBox;
   if lb = nil then
      begin
      Exit;
      end;
   lb.Invalidate;
end;

procedure SetPossibleCallFont(const aName: string; const aHeight: integer;
                              const aBold: boolean);
var
   lb: TStringGrid;
begin
   lb := PossibleCallListBox;
   if lb = nil then
      begin
      Exit;
      end;

   lb.ParentFont := False;
   lb.Font.Name := aName;
   lb.Font.Height := -aHeight;
   if aBold then
      begin
      lb.Font.Style := [fsBold];
      end
   else
      begin
      lb.Font.Style := [];
      end;
end;

procedure SelectPossibleCall(const aIndex: integer);
var
   lb: TStringGrid;
begin
   lb := PossibleCallListBox;
   if lb = nil then
      begin
      Exit;
      end;

   (* Out of range is not an error here: LB_SETCURSEL simply failed, and the
     arrow-key handlers walk off both ends of the list by design.

     -1 IS DROPPED, and that is a real difference from the listbox. It meant
     "nothing selected", which a grid cannot represent -- there is always a
     current cell. The strip is rebuilt and re-selected from index 0 on every
     keystroke, so the state -1 described never survives a repaint anyway. *)
   if (aIndex >= 0) and (aIndex < Length(GPossibleDupe)) then
      begin
      lb.Col := aIndex;
      end;
end;

initialization
   (* THE SAME REGISTRATION uElementPanel MAKES, AND FOR THE SAME REASON.

     The streaming loader resolves a class by NAME, and it only knows the names
     it has been given: a component with a published field on the form class is
     found through that field's type, and one without has to be registered.
     None of the four controls added to this form in 2026-09 has a field.

     WITHOUT IT THE WHOLE FORM FAILS TO LOAD, at the first TProgressBar, with
     EClassNotFound -- which is how the golden corpus went from 24 passing to
     26 failing in one step. Not "the bars are missing": the main window never
     finishes streaming, so the headless export dies before writing anything. *)
   RegisterClass(TProgressBar);

   InitCriticalSection(GPendingLock);

finalization
   DoneCriticalSection(GPendingLock);

end.

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
  Windows, Classes, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  LCLType,
  LMessages,
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
    { PUBLISHED so the streaming loader finds it in uMainForm.lfm, and so
      Lint-FormFields can check the two agree.  Declared in the designer,
      REPOSITIONED at run time -- see CreateTR4WPossibleCallList. }
    lstPossibleCall: TListBox;

    { THE EVENT IS THE FORM'S, and is wired in uMainForm.lfm so it is visible in
      the designer.  It delegates to PossibleCallDrawProc, which MainUnit sets:
      the drawing reads PossibleCallList and the colour table, and this unit has
      no business knowing about either.

      Declaring it here also keeps the LCL's own types in the one unit that
      already speaks them.  MainUnit uses both Windows and the LCL, so a method
      signature written there has to name which TRect and which TOwnerDrawState
      it means -- and getting that wrong produces a type error that reads as if
      the signatures were identical, because printed out they are. }
    procedure lstPossibleCallDrawItem(Control: TWinControl; Index: integer;
                                      ARect: TRect; State: TOwnerDrawState);
  public
    (* The editable log's virtual-list handlers. See CreateTR4WEditableLog. *)
    procedure MainLogData(Sender: TObject; Item: TListItem);
    procedure MainLogCustomDrawItem(Sender: TCustomListView; Item: TListItem;
                                    State: TCustomDrawState; var DefaultDraw: boolean);
  end;

type
  { The drawing itself, as a PLAIN procedure so the unit that owns the knowledge
    does not have to build a class to satisfy a method pointer. }
  TPossibleCallDrawProc = procedure(Control: TWinControl; Index: integer;
                                    ARect: TRect; State: TOwnerDrawState);

var
  PossibleCallDrawProc: TPossibleCallDrawProc = nil;

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
function CreateTR4WEntryField(const aLeft, aTop, aWidth, aHeight: integer;
                              const aId: integer;
                              const aBorder: boolean;
                              const aField: TTR4WEntryField;
                              const aFontName: string = '';
                              const aFontHeight: integer = 0;
                              const aFontBold: boolean = False): HWND;

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
function CreateTR4WPossibleCallList(const aLeft, aTop, aWidth, aHeight,
                                    aId, aItemHeight, aColumnWidth: integer): HWND;


(* THE EDITABLE LOG -- an LCL virtual list, returning its HWND.

  REPLACES CreateEditableLog's CreateWindowExW FOR THE MAIN WINDOW. That control
  was created with LVS_NOSCROLL and filled with the last LinesInEditableLog
  records, which is why the log showed five rows and had no scrollbar. NY4I:
  "I do not see my vertical scroll bar and I still see the qso window as a fixed
  5."

  OwnerData, SO IT HOLDS NO ROWS. It knows the record count and asks OnData for
  what it is about to paint, so the whole contest is scrollable without the
  thousands of LVM_INSERTITEM messages that filling it would cost.

  IT STILL RETURNS AN HWND, and wh[mweEditableLog] still holds it. Roughly thirty
  call sites set colours, read the header, ask which row is selected and set
  column widths through that handle; they keep working because a TListView has
  one. What could NOT survive is the FILLING -- LVM_INSERTITEM against an
  OwnerData list does nothing -- and those sites are converted with this. *)
function CreateTR4WEditableLog(const aLeft, aTop, aWidth, aHeight: integer): HWND;

(* The row count the list reports. Called when the log grows or is reloaded. *)
procedure TR4WEditableLogSetCount(const aCount: integer);

(* Forget cached rows -- after an edit, a rescore or a reload. *)
procedure TR4WEditableLogRefresh;

(* WHERE THE LIST SITS.

  THROUGH THE LCL, NEVER SetWindowPos. CLAUDE.md states the rule for forms and
  it is just as true for a control on one: "the LCL holds its own bounds and
  pushes the designed ones back down when it shows". The main window sized this
  control with three SetWindowPos calls; against an LCL control they move the
  window on screen and leave the LCL believing the old rectangle, and the next
  realign puts it back. Created at height 0 -- which is what the Win32 control
  was created at, sized later by those same calls -- that meant a control the
  LCL kept at zero height and an editable log that rendered as blank paper. *)
procedure TR4WEditableLogSetBounds(const aLeft, aTop, aWidth, aHeight: integer);

(* Put the newest QSO in view, which is where an operator looks. *)
procedure TR4WEditableLogScrollToEnd;

function CreateTR4WMainForm(const aMenu: HMENU): HWND;

var
  { The form itself.  Exposed because Phase 3b parents LCL controls onto it and
    Phase 3c hands it to Application.Run.  Nothing else should need it: the rest
    of the program continues to work in tr4whandle. }
  TR4WMainForm: TTR4WMainForm = nil;
  TR4WCallEdit: TEdit = nil;
  TR4WEditableLog: TListView = nil;
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
function  CreateMainElement(const aElement: TMainWindowElement;
                            const aStyle: cardinal;
                            const aLeft, aTop, aWidth, aHeight: integer): HWND;
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

{ The possible-call list -- an LCL TListBox since Phase 3b; these replace
  LB_RESETCONTENT / LB_ADDSTRING / LB_SETCURSEL / LB_GETCURSEL / LB_GETCOUNT
  sent to wh[mwePossibleCall].  See the implementation for why the items
  carry no data. }
procedure ClearPossibleCalls;
function  AddPossibleCall: integer;
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
   // Solely for the message CONSTANTS in IsTR4WsOwnMessage below. The list used
   // to spell them as literal integers to avoid exactly these six lines; three
   // of the eight literals were wrong and each failure was silent. Six units in
   // an implementation clause is the cheaper mistake.
   uPOTAParks,         // WM_POTA_DOWNLOAD_DONE / WM_POTA_LOAD_DONE
   uCTYUpdate,         // WM_CTY_VERSION_CHECKED / WM_CTY_DOWNLOAD_DONE
   uTRMasterUpdate,    // WM_TRMASTER_DOWNLOAD_DONE
   uTCIServer,         // WM_TCI_APPLY
   uGetServerLog,      // WM_USER_HEADLESS_SYNC_REPLACE
   SysUtils,           // Format -- the window-procedure guard
   uCrashLog,          // OnMainThread / ReportOffMainThread / LogCaughtException
   uLogSource,         // the virtual log list reads through the seam
   uConfigValues,      // Config.ShowGridLines
   MainUnit;           // LogRowTextFor, Config -- see CreateTR4WEditableLog

var
   { The LCL's own window procedure for the main form, saved when TR4W's is
     installed in front of it.  Everything TR4W does not claim chains here. }
   GLCLFormProc: Pointer = nil;

{ The messages TR4W's own window procedure handles.

  AN EXPLICIT ALLOW-LIST, not "delegate everything".  The alternative -- pass
  every message to the legacy proc and let its DefWindowProc fallthrough deal
  with the rest -- would take WM_PAINT, WM_ERASEBKGND, WM_DESTROY and the LCL's
  own bookkeeping away from the form and break it in ways that present as
  painting bugs.  This list is exactly the case labels in
  uMainWindowProc.WindowProc, so the two must be kept in step; a message added
  there and not here is silently never delivered. }
function IsTR4WsOwnMessage(const aMsg: UINT): boolean;
begin
   Result := (aMsg = WM_CLOSE) or
             (aMsg = WM_COMMAND) or
             (aMsg = WM_NOTIFY) or
             // WM_DRAWITEM AND WM_MEASUREITEM ARE DELIBERATELY ABSENT, and
             // removing them from this list is the FIX, not an omission.
             //
             // Their arms in uMainWindowProc.WindowProc were deleted when the
             // possible-call strip became a designed TListBox -- correctly, as
             // both only ever served that one control id.  But the message
             // stayed CLAIMED here, and a claimed message this proc no longer
             // answers is SWALLOWED: line 841 calls WindowProc and returns
             // without chaining to the LCL.
             //
             // WM_DRAWITEM is sent to the PARENT of an owner-drawn list, so
             // the LCL form proc never received it and TListBox.OnDrawItem was
             // never called.  The strip held its rows, reported Visible, sat in
             // bounds, and painted NOTHING -- measured 2026-08-28: two matching
             // calls in the model, zero draw calls, for weeks (NY4I).
             //
             // The note above says a message added THERE and not HERE is never
             // delivered.  This is its mirror image, and it is the second time
             // this control has been hit by it -- see the WM_CTLCOLORLISTBOX
             // forward at line 835.
             (aMsg = WM_CTLCOLORLISTBOX) or
             (aMsg = WM_CTLCOLOREDIT) or
             (aMsg = WM_CTLCOLORSTATIC) or
             (aMsg = WM_LBUTTONDOWN) or
             (aMsg = WM_SETFOCUS) or
             (aMsg = WM_TIMECHANGE) or
             (aMsg = WM_DISPLAYCHANGE) or
             (aMsg = WM_WINDOWPOSCHANGING) or
             (aMsg = WM_SIZE) or
             // The messages TR4W posts to itself from worker threads, BY THEIR
             // CONSTANTS.
             //
             // These were written out as literal values, with a comment saying
             // that avoided "depending on five more units for four integers".
             // Measured 2026-08-20: THREE OF THE EIGHT WERE WRONG, and every one
             // of them failed in total silence -- the message simply chained to
             // the LCL, which does not know it, and the handler in
             // uMainWindowProc.WindowProc never ran.
             //
             //   WM_APP + 213 was claimed for WM_CTY_VERSION_CHECKED, which is
             //     actually WM_APP + 210. 213 is not any message at all.
             //   WM_APP + 100 was claimed for WM_TRAYBALLON, which was
             //     actually WM_SOCK + 3 = $5F7. Not close. (That message and
             //     uTrayBalloon are gone now -- the tray feature was not
             //     wanted -- but the mistake is left described because it is
             //     the CLASS of error this list must not repeat.)
             //   WM_PANEL_UPDATE (WM_APP + 230) was never added, so the radio
             //     panel marshalling seam never delivered a single update --
             //     which is why RIT/XIT/SPLIT stayed yellow on the bench and
             //     survived two wrong diagnoses before this one. (That message
             //     no longer exists: uPanelUpdate hands its payload to
             //     Application.QueueAsyncCall now, which has no id anyone can
             //     forget to register. The example stands -- it is the CLASS of
             //     error this list must not repeat.)
             //
             // The units cost is real and it is worth paying. A list of integers
             // that must agree with constants declared elsewhere cannot be
             // checked by anything; a list of the constants themselves cannot be
             // wrong about a value at all. What it can still be wrong about is
             // MEMBERSHIP -- a new message nobody adds here -- and that is what
             // Lint-AppMessages exists to catch.
             (aMsg = WM_POTA_DOWNLOAD_DONE) or
             (aMsg = WM_POTA_LOAD_DONE) or
             (aMsg = WM_CTY_VERSION_CHECKED) or
             (aMsg = WM_CTY_DOWNLOAD_DONE) or
             (aMsg = WM_TRMASTER_DOWNLOAD_DONE) or
             (aMsg = WM_TCI_APPLY) or
             // NOT a WM_APP message -- WM_USER + 200 -- and the fourth one this
             // list was dropping. It is SENT, not posted, by uGetServerLog so
             // the multi-op log replace happens on the UI thread; unclaimed, it
             // chained to the LCL, the replace never ran, and the sending thread
             // blocked to be told nothing happened.
             (aMsg = WM_USER_HEADLESS_SYNC_REPLACE);
end;

{ TR4W'S WINDOW PROCEDURE, INSTALLED ON THE FORM'S HWND AHEAD OF THE LCL'S.

  WHY A SUBCLASS AND NOT A WndProc OVERRIDE.  The first version of this overrode
  TWinControl.WndProc and matched on TLMessage.msg.  That was wrong, and wrong in
  a way only a person operating the program could find: THE LCL RENAMES MESSAGES
  BEFORE ANY FORM SEES THEM.

    WM_CLOSE   arrives as LM_CLOSEQUERY                (win32callback.inc:2094)
    WM_COMMAND arrives as CN_COMMAND via Perform, for a raw HMENU        (:2205)

  and WM_DRAWITEM, WM_MEASUREITEM, WM_CTLCOLOR* and WM_LBUTTONDOWN are consumed
  by the widgetset's own handlers on the way past.  An allow-list keyed on the
  Win32 numbers therefore never matched: TR4W's menu did nothing, the program
  could not be closed and had to be killed, and owner-drawn parts of the main
  window were being drawn by the wrong code.

  Found on the bench by NY4I, 2026-08-18.  No gate here caught it -- the smoke
  runner asserts only that the process SURVIVED a command, which a program that
  refuses to exit does very well indeed.

  Subclassing removes the class of problem rather than the three instances of
  it: TR4W's procedure sees the RAW Win32 message first, exactly as it did when
  it owned the window class, and anything it does not claim chains on to the LCL
  untouched.  What used to fall through to DefWindowProc now falls through to
  the LCL's proc, which is the right default for a form. }
{ The entry-field guard, declared here and defined with the accessors it was
  written for.  IsEntryFieldHandle below is above them in the file because the
  window procedure that calls it is, and a forward declaration is cheaper than
  moving either. }
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
   GElements: array[TMainWindowElement] of TPanel;

function MainElement(const aElement: TMainWindowElement): TPanel;
begin
   Result := GElements[aElement];
end;

function ElementUsable(const aElement: TMainWindowElement): boolean;
begin
   Result := ControlUsable(GElements[aElement]);
end;

function CreateMainElement(const aElement: TMainWindowElement;
                           const aStyle: cardinal;
                           const aLeft, aTop, aWidth, aHeight: integer): HWND;
var
   p: TPanel;
begin
   Result := 0;
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   p := TPanel.Create(TR4WMainForm);
   p.Parent := TR4WMainForm;
   GElements[aElement] := p;

   // THE WIN32 STYLE BITS, ONE AT A TIME.  Every one of them has a property,
   // which is the whole reason this control can stop being painted by a
   // WM_CTLCOLORSTATIC handler.
   //
   //   SS_SUNKEN    -> BevelOuter bvLowered
   //   SS_CENTER    -> Alignment taCenter, SS_LEFT -> taLeftJustify
   //   WS_VISIBLE   -> Visible (uVisStyle omits it; those elements start hidden)
   //   WS_DISABLED  -> Enabled False (DefStyleDis)
   //   SS_NOPREFIX  -> no counterpart needed: a TPanel caption is not an
   //                   accelerator string, so there is no '&' to suppress.
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

   // AutoSize BEFORE SetBounds.  LCL controls autosize by default and a
   // streamed or assigned size is silently overridden; this tree has paid for
   // that once already (see CreateTR4WEntryField).
   p.AutoSize := False;
   p.SetBounds(aLeft, aTop, aWidth, aHeight);

   p.Enabled := (aStyle and WS_DISABLED) = 0;
   p.Visible := (aStyle and WS_VISIBLE) <> 0;

   Result := p.Handle;
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

{ Is this handle one of the main window's own elements?  Asked by the
  WM_CTLCOLORSTATIC fork below for the same reason as the entry fields: a
  control that owns its colours must not also be painted by TR4W. }
function IsMainElementHandle(const aWnd: HWND): boolean;
var
   e: TMainWindowElement;
begin
   Result := False;
   if aWnd = 0 then
      begin
      Exit;
      end;

   for e := Low(TMainWindowElement) to High(TMainWindowElement) do
      begin
      if ControlUsable(GElements[e]) and (GElements[e].Handle = aWnd) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

{ Is this handle one of the two entry fields?  Asked by the WM_CTLCOLOREDIT arm
  below, which is the only caller and the reason this is not exported.

  ControlUsable rather than a bare nil test, so a control whose window has not
  been created yet cannot have .Handle read -- reading it would CREATE the
  handle, from inside a window procedure, for a control the caller was only
  asking about. }
function IsEntryFieldHandle(const aWnd: HWND): boolean;
begin
   Result := False;
   if aWnd = 0 then
      begin
      Exit;
      end;

   Result := (ControlUsable(TR4WCallEdit)     and (TR4WCallEdit.Handle     = aWnd)) or
             (ControlUsable(TR4WExchangeEdit) and (TR4WExchangeEdit.Handle = aWnd));
end;

function IsPossibleCallHandle(const aWnd: HWND): boolean;
{ Guarded the same way as IsEntryFieldHandle: the control is nil on the
  headless /EXPORT path, where no form is ever built. }
begin
   Result := ControlUsable(TR4WMainForm.lstPossibleCall)
             and (TR4WMainForm.lstPossibleCall.Handle = aWnd);
end;

function TR4WFormSubclassProcBody(TRHWND: HWND; Msg: UINT;
                                  wParam: wParam; lParam: lParam): longword; stdcall;
begin
   { THE ENTRY FIELDS ARE COLOURED BY THE LCL, so their WM_CTLCOLOREDIT never
     reaches TR4W's DrawWindows at all.

     Not an exclusion inside DrawWindows, because DECLINING IS NOT EXPRESSIBLE
     THERE.  That function has no "not mine" answer: every path -- including the
     one where nothing matched -- falls into its DrawWindow label and returns
     the whole-screen brush, and WindowProcBody's fallthrough is DefWindowProc,
     not the LCL.  So a control TR4W stopped painting would have been painted
     by the system default instead of by its own Color, which is worse than
     what it replaced.  The fork belongs HERE, where chaining to the LCL is
     already what "not mine" means.

     TEdit.Color and TEdit.Font.Color then decide, and the LCL answers from
     Brush.Reference.Handle (win32callback.inc:1420).  ONE system paints the
     control, which is the whole point: while TR4W claimed this message, the
     Color property on a converted TEdit did nothing at all. }
   (* AND THE POSSIBLE-CALL LIST, added 2026-08-27 after MEASURING it.

      DrawWindows carried a comment saying nothing reached it any more. A
      counter in CheckWindowAndColor said otherwise: 48 queries, 7 matches,
      and every match was this one control. WM_CTLCOLORLISTBOX was simply not
      in the fork above, so the list box's background was still being decided
      by TR4W while the LCL owned everything else about it.

      The items are owner-drawn through lstPossibleCallDrawItem, so this
      message only ever governed the background BEYOND the items -- which is
      why nobody noticed. It is the last main-window element on the Win32
      colour path, and with it forwarded the whole WM_CTLCOLOR* arm of
      WindowProcBody has nothing left to answer. *)
   if ((Msg = WM_CTLCOLOREDIT)    and IsEntryFieldHandle(HWND(lParam))) or
      ((Msg = WM_CTLCOLORSTATIC)  and IsMainElementHandle(HWND(lParam))) or
      ((Msg = WM_CTLCOLORLISTBOX) and IsPossibleCallHandle(HWND(lParam)))  then
      begin
      Result := Windows.CallWindowProc(GLCLFormProc, TRHWND, Msg, wParam, lParam);
      Exit;
      end;

   if IsTR4WsOwnMessage(Msg) then
      begin
      Result := uMainWindowProc.WindowProc(TRHWND, Msg, wParam, lParam);

      // Three messages run BOTH handlers, for two different reasons.
      //
      // WM_SIZE and WM_WINDOWPOSCHANGING are STRUCTURAL: the LCL tracks its own
      // idea of the form's bounds from them, and a form whose bookkeeping
      // disagrees with its HWND misbehaves later in ways hard to trace back.
      // TR4W's handlers for both are advisory, so running both is correct.
      //
      // WM_COMMAND is chained because CLAIMING IT STARVES THE LCL'S OWN
      // CONTROLS.  A child control's notifications -- EN_CHANGE, EN_SETFOCUS
      // and the rest -- reach their control only through the parent's
      // WM_COMMAND, so an LCL TEdit on this form would never raise OnChange or
      // OnEnter while TR4W swallowed it.  Nothing depends on that yet, which is
      // exactly why it is worth fixing now: the entry fields cannot stop using
      // TR4W's hand-rolled EN_* routing until the framework's own routing
      // works.  TR4W still gets first refusal and still decides; the LCL simply
      // stops being deaf.
      if (Msg = WM_SIZE) or (Msg = WM_WINDOWPOSCHANGING) or (Msg = WM_COMMAND) then
         begin
         Result := Windows.CallWindowProc(GLCLFormProc, TRHWND, Msg, wParam, lParam);
         end;
      Exit;
      end;

   Result := Windows.CallWindowProc(GLCLFormProc, TRHWND, Msg, wParam, lParam);
end;


{ THE OTHER KERNEL-CALLBACK BOUNDARY, guarded for the same reason as
  uMainWindowProc.WindowProc -- read the long note there.  An exception raised
  in here cannot unwind back into Windows, so it does not unwind: the process
  is terminated with STATUS_FATAL_APP_EXIT and the log simply stops.

  This one matters at least as much as the other, because it runs FIRST: every
  message reaching the main form comes through here, and what it does not claim
  it chains to the LCL. }
function TR4WFormSubclassProc(TRHWND: HWND; Msg: UINT;
                              wParam: wParam; lParam: lParam): longword; stdcall;
begin
   Result := 0;
   try
      Result := TR4WFormSubclassProcBody(TRHWND, Msg, wParam, lParam);
   except
      on E: TObject do
         begin
         LogCaughtException(Format('TR4WFormSubclassProc msg $%x', [Msg]), E);
         Result := longword(Windows.DefWindowProc(TRHWND, Msg, wParam, lParam));
         end;
   end;
end;

procedure TTR4WMainForm.lstPossibleCallDrawItem(Control: TWinControl;
                                                Index: integer; ARect: TRect;
                                                State: TOwnerDrawState);
begin
   if Assigned(PossibleCallDrawProc) then
      begin
      PossibleCallDrawProc(Control, Index, ARect, State);
      end;
end;

type
   (* One row, remembered -- the same shape uLogEditForm uses and for the same
     reason: a virtual list asks twice per row (text, then colour) and each ask
     was a database read plus a run of the 360-line row builder. *)
   TMainRowCache = record
      Index:   integer;
      Text:    TLogRowText;
      Deleted: boolean;
      XQSO:    boolean;
   end;
   PMainRowCache = ^TMainRowCache;

const
   MAIN_CACHE_ROWS = 512;

var
   GMainRowCache: array[0..MAIN_CACHE_ROWS - 1] of TMainRowCache;

procedure TR4WEditableLogRefresh;
var
   i: integer;
begin
   for i := Low(GMainRowCache) to High(GMainRowCache) do
      begin
      GMainRowCache[i].Index := -1;
      end;
   if TR4WEditableLog <> nil then
      begin
      TR4WEditableLog.Invalidate;
      end;
end;

function MainRow(aIndex: integer): PMainRowCache;
var
   rec: ContestExchange;
   c:   LogColumnsType;
begin
   Result := @GMainRowCache[aIndex mod MAIN_CACHE_ROWS];
   if Result^.Index = aIndex then
      begin
      Exit;
      end;

   Result^.Index := -1;
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      Result^.Text[c] := '';
      end;
   Result^.Deleted := False;
   Result^.XQSO    := False;

   (* OPENED AND CLOSED PER MISS, not held. The main window lives for the whole
     contest and the log is written underneath it by every QSO; holding a read
     cursor open across that is asking for a stale view. A miss is rare -- the
     cache covers twenty screens. *)
   if not LogSourceOpen then
      begin
      Exit;
      end;
   try
      if not LogSourceReadAtIndex(aIndex, rec) then
         begin
         Exit;
         end;
      LogRowTextFor(rec, Result^.Text);
      Result^.Deleted := rec.ceQSO_Deleted;
      Result^.XQSO    := rec.ceXQSO;
      Result^.Index   := aIndex;
   finally
      LogSourceClose;
   end;
end;

procedure TR4WEditableLogSetCount(const aCount: integer);
begin
   if TR4WEditableLog = nil then
      begin
      if logger <> nil then
         begin
         logger.Warn('[EditableLog] SetCount(%d) but there is no control', [aCount]);
         end;
      Exit;
      end;
   TR4WEditableLogRefresh;
   TR4WEditableLog.Items.Count := aCount;
   if logger <> nil then
      begin
      logger.Info('[EditableLog] count=%d bounds=(%d,%d,%d,%d) visible=%s',
                  [aCount, TR4WEditableLog.Left, TR4WEditableLog.Top,
                   TR4WEditableLog.Width, TR4WEditableLog.Height,
                   BoolToStr(TR4WEditableLog.Visible, True)]);
      end;
end;

(* MEASURED AND DISTRIBUTED, the same way uLogEditForm does it and for the same
  reason: ColumnsArray[].Width is a COUNT OF CHARACTERS, and the Win32 control
  turned it into pixels with a magic factor that depended on the font it had
  been given. Measuring against the font the control is actually using is the
  only version that survives a font change.

  COMPUTED FIRST, APPLIED ONCE, inside BeginUpdate/EndUpdate -- writing widths
  as they are calculated draws the intermediate state, which is an animation an
  operator can watch. *)
procedure SizeMainLogColumns;
var
   c:      LogColumnsType;
   i:      integer;
   charW:  integer;
   wanted: integer;
   total:  integer;
   slack:  integer;
   given:  integer;
   widths: array of integer;
begin
   if (TR4WEditableLog = nil) or (TR4WEditableLog.Columns.Count = 0) then
      begin
      Exit;
      end;

   TR4WEditableLog.Canvas.Font.Assign(TR4WEditableLog.Font);
   charW := TR4WEditableLog.Canvas.TextWidth('0');
   if charW < 1 then
      begin
      charW := 7;
      end;

   SetLength(widths, TR4WEditableLog.Columns.Count);
   total := 0;
   i := 0;
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if not ColumnsArray[c].Enable then
         begin
         Continue;
         end;
      if i > High(widths) then
         begin
         Break;
         end;
      wanted := (ColumnsArray[c].Width * charW) + charW;
      if wanted < TR4WEditableLog.Canvas.TextWidth(AnsiString(ColumnsArray[c].Text)) + charW then
         begin
         wanted := TR4WEditableLog.Canvas.TextWidth(AnsiString(ColumnsArray[c].Text)) + charW;
         end;
      widths[i] := wanted;
      total := total + wanted;
      Inc(i);
      end;

   if (TR4WEditableLog.ClientWidth > total) and (total > 0) then
      begin
      slack := TR4WEditableLog.ClientWidth - total;
      given := 0;
      for i := 0 to High(widths) do
         begin
         if i = High(widths) then
            begin
            widths[i] := widths[i] + (slack - given);
            end
         else
            begin
            wanted := (widths[i] * slack) div total;
            widths[i] := widths[i] + wanted;
            given := given + wanted;
            end;
         end;
      end;

   TR4WEditableLog.Columns.BeginUpdate;
   try
      for i := 0 to High(widths) do
         begin
         if TR4WEditableLog.Columns[i].Width <> widths[i] then
            begin
            TR4WEditableLog.Columns[i].Width := widths[i];
            end;
         end;
   finally
      TR4WEditableLog.Columns.EndUpdate;
   end;
end;

procedure TR4WEditableLogSetBounds(const aLeft, aTop, aWidth, aHeight: integer);

begin

   if TR4WEditableLog = nil then

      begin

      Exit;

      end;

   TR4WEditableLog.SetBounds(aLeft, aTop, aWidth, aHeight);

   SizeMainLogColumns;

end;

procedure TR4WEditableLogScrollToEnd;
begin
   if (TR4WEditableLog = nil) or (TR4WEditableLog.Items.Count = 0) then
      begin
      Exit;
      end;
   TR4WEditableLog.Items[TR4WEditableLog.Items.Count - 1].MakeVisible(False);
end;

(* METHODS OF THE FORM, not plain procedures. OnData and OnCustomDrawItem are
  `of object` -- a bare procedure will not assign to them, and the compiler says
  so rather than letting a dangling Self through. *)
procedure TTR4WMainForm.MainLogData(Sender: TObject; Item: TListItem);
var
   e:     PMainRowCache;
   c:     LogColumnsType;
   first: boolean;
begin
   e := MainRow(Item.Index);

   first := True;
   Item.SubItems.Clear;
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if not ColumnsArray[c].Enable then
         begin
         Continue;
         end;
      if first then
         begin
         Item.Caption := e^.Text[c];
         first := False;
         end
      else
         begin
         Item.SubItems.Add(e^.Text[c]);
         end;
      end;
end;

(* X-QSO grey and deleted red, from the RECORD.

  The Win32 control did this through NM_CUSTOMDRAW in uMainWindowProc, reading a
  flag smuggled into the row's per-item lParam by SetRowXQSOFlag. A virtual row
  knows its own record, so the smuggling goes. *)
procedure TTR4WMainForm.MainLogCustomDrawItem(Sender: TCustomListView; Item: TListItem;
                                              State: TCustomDrawState; var DefaultDraw: boolean);
var
   e: PMainRowCache;
begin
   DefaultDraw := True;
   e := MainRow(Item.Index);

   if e^.Deleted then
      begin
      Sender.Canvas.Font.Color := clRed;
      end
   else if e^.XQSO then
      begin
      Sender.Canvas.Font.Color := clGray;
      end;
end;

function CreateTR4WEditableLog(const aLeft, aTop, aWidth, aHeight: integer): HWND;
var
   c:   LogColumnsType;
   col: TListColumn;
begin
   Result := 0;
   if TR4WMainForm = nil then
      begin
      Exit;
      end;

   TR4WEditableLogRefresh;

   if TR4WEditableLog = nil then
      begin
      TR4WEditableLog := TListView.Create(TR4WMainForm);
      TR4WEditableLog.Parent := TR4WMainForm;
      end;

   with TR4WEditableLog do
      begin
      SetBounds(aLeft, aTop, aWidth, aHeight);
      ViewStyle  := vsReport;
      OwnerData  := True;
      ReadOnly   := True;
      RowSelect  := True;
      GridLines  := Config.ShowGridLines;
      Color      := tr4wColorsArray[TWindows[mweEditableLog].mweBackG];
      Font.Color := tr4wColorsArray[TWindows[mweEditableLog].mweColor];
      OnData           := TR4WMainForm.MainLogData;
      OnCustomDrawItem := TR4WMainForm.MainLogCustomDrawItem;

      Columns.BeginUpdate;
      try
         Columns.Clear;
         for c := Low(LogColumnsType) to High(LogColumnsType) do
            begin
            if not ColumnsArray[c].Enable then
               begin
               Continue;
               end;
            col := Columns.Add;
            col.Caption := AnsiString(ColumnsArray[c].Text);
            col.Width   := 40;
            end;
      finally
         Columns.EndUpdate;
      end;

      Visible := True;
      Result  := Handle;
      end;

   (* THREE NUMBERS THAT SETTLE IT. Two attempts at making this control draw
     have been guesses; this reports what it actually IS. *)
   if logger <> nil then
      begin
      logger.Info('[EditableLog] created: bounds=(%d,%d,%d,%d) visible=%s ' +
                  'parent=%s columns=%d count=%d handle=%d',
                  [TR4WEditableLog.Left, TR4WEditableLog.Top,
                   TR4WEditableLog.Width, TR4WEditableLog.Height,
                   BoolToStr(TR4WEditableLog.Visible, True),
                   BoolToStr(TR4WEditableLog.Parent <> nil, True),
                   TR4WEditableLog.Columns.Count,
                   TR4WEditableLog.Items.Count,
                   PtrUInt(TR4WEditableLog.Handle)]);
      end;

   with TR4WEditableLog do
      begin
      end;

   SizeMainLogColumns;
   with TR4WEditableLog do
      begin
      end;
end;

function CreateTR4WPossibleCallList(const aLeft, aTop, aWidth, aHeight,
                                    aId, aItemHeight, aColumnWidth: integer): HWND;
begin
   Result := 0;
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
      ItemHeight := aItemHeight;

      // LB_SETCOLUMNWIDTH set the column width directly; the LCL says how MANY
      // columns and divides the client width.  Derived from the same two
      // numbers, so the operator sees the width they always have.
      if (aColumnWidth > 0) and (aWidth > aColumnWidth) then
         begin
         Columns := aWidth div aColumnWidth;
         end;

      SetBounds(aLeft, aTop, aWidth, aHeight);

      // NO ITEM TEXT is set anywhere, and that is faithful rather than lazy.
      // The Win32 control was created WITHOUT LBS_HASSTRINGS: LB_ADDSTRING's
      // lParam was item DATA, not a string, and the owner-draw never read it
      // either -- it indexes PossibleCallList by the item's ORDINAL.  This
      // list's whole job is to have the right NUMBER of items.  Giving them
      // captions would invent a second source of truth for what each row says.
      Result := Handle;
      end;
end;


function CreateTR4WEntryField(const aLeft, aTop, aWidth, aHeight: integer;
                              const aId: integer;
                              const aBorder: boolean;
                              const aField: TTR4WEntryField;
                              const aFontName: string = '';
                              const aFontHeight: integer = 0;
                              const aFontBold: boolean = False): HWND;
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

   Result := edit.Handle;
   Windows.SetWindowLong(Result, GWL_ID, aId);
end;

procedure ShowTR4WMainForm;
var
   r: TRect;
begin
   if not Assigned(TR4WMainForm) then
      begin
      Exit;
      end;

   // READ THE REAL BOUNDS BACK FIRST.  Everything that sizes this window --
   // CreateMainWindow, CheckEditableWindowHeight, SetWindowSize -- does it with
   // a raw SetWindowPos on tr4whandle, so the LCL's own idea of the form's
   // bounds is still the placeholder CreateNew was given.  Setting Visible then
   // makes the LCL apply THAT, and the window collapses to the placeholder:
   // NY4I, 2026-08-18, "the screen is quite small and only a partial view" --
   // a 400x200 window with the menu wrapped onto two lines.
   //
   // Reconciling instead of assigning: read what the window actually is and
   // tell the LCL, rather than deciding here what it should be. The program
   // owns its geometry; this only stops the framework overwriting it.
   Windows.GetWindowRect(TR4WMainForm.Handle, r);
   TR4WMainForm.SetBounds(r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top);

   TR4WMainForm.Visible := True;

   // AND PUT IT BACK.  Telling the LCL the bounds is not enough: showing the
   // form makes it apply its own adjustments -- menu height, border metrics --
   // and the window came out 1018x705 where TR4W had made it 1012x656.  Close
   // enough to look almost right, which is worse than obviously wrong.
   //
   // TR4W computes that geometry from the font-size setting and the MEASURED
   // height of the log ListView; it is not a number the framework can improve
   // on.  So the raw rect is restored after the show, and the LCL is left
   // holding a correct BoundsRect either way.
   Windows.SetWindowPos(TR4WMainForm.Handle, 0, r.Left, r.Top,
                        r.Right - r.Left, r.Bottom - r.Top,
                        SWP_NOZORDER or SWP_NOACTIVATE);
end;


function CreateTR4WMainForm(const aMenu: HMENU): HWND;
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

   // Touching Handle is what forces the window to exist.
   Result := TR4WMainForm.Handle;

   // INSTALL TR4W'S PROCEDURE IN FRONT OF THE LCL'S, keeping the LCL's to
   // chain to.  After Handle has forced the window into existence, before
   // anything is shown.
   GLCLFormProc := Pointer(Windows.SetWindowLongPtr(Result, GWL_WNDPROC,
                                                    LONG_PTR(@TR4WFormSubclassProc)));

   if aMenu <> 0 then
      begin
      Windows.SetMenu(Result, aMenu);
      end;
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

function PossibleCallListBox: TListBox;
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
   lb: TListBox;
begin
   lb := PossibleCallListBox;
   if not ControlUsable(lb) then
      begin
      Exit;
      end;
   lb.Items.Clear;
end;

{ Appends one row and returns its index, or -1 when there is no list. }
function AddPossibleCall: integer;
var
   lb: TListBox;
begin
   Result := -1;
   lb := PossibleCallListBox;
   if not ControlUsable(lb) then
      begin
      Exit;
      end;
   Result := lb.Items.Add('');
end;

function PossibleCallCount: integer;
var
   lb: TListBox;
begin
   Result := 0;
   lb := PossibleCallListBox;
   if not ControlUsable(lb) then
      begin
      Exit;
      end;
   Result := lb.Items.Count;
end;

{ -1 when nothing is selected -- the same value LB_GETCURSEL returned as
  LB_ERR, so callers that test for it are unchanged. }
function SelectedPossibleCall: integer;
var
   lb: TListBox;
begin
   Result := -1;
   lb := PossibleCallListBox;
   if not ControlUsable(lb) then
      begin
      Exit;
      end;
   Result := lb.ItemIndex;
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
   lb: TListBox;
begin
   lb := PossibleCallListBox;
   if not ControlUsable(lb) then
      begin
      Exit;
      end;
   lb.Invalidate;
end;

procedure SetPossibleCallFont(const aName: string; const aHeight: integer;
                              const aBold: boolean);
var
   lb: TListBox;
begin
   lb := PossibleCallListBox;
   if not ControlUsable(lb) then
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
   lb: TListBox;
begin
   lb := PossibleCallListBox;
   if not ControlUsable(lb) then
      begin
      Exit;
      end;

   // Out of range is not an error here: LB_SETCURSEL simply failed, and the
   // arrow-key handlers walk off both ends of the list by design.
   if (aIndex >= -1) and (aIndex < lb.Items.Count) then
      begin
      lb.ItemIndex := aIndex;
      end;
end;

initialization
   InitCriticalSection(GPendingLock);

finalization
   DoneCriticalSection(GPendingLock);

end.

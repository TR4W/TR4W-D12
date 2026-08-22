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
  Windows, Forms, Controls, Graphics, StdCtrls, LCLType, LMessages,
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
                              const aField: TTR4WEntryField): HWND;

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


function CreateTR4WMainForm(const aMenu: HMENU): HWND;

var
  { The form itself.  Exposed because Phase 3b parents LCL controls onto it and
    Phase 3c hands it to Application.Run.  Nothing else should need it: the rest
    of the program continues to work in tr4whandle. }
  TR4WMainForm: TTR4WMainForm = nil;
  TR4WCallEdit: TEdit = nil;
  TR4WExchangeEdit: TEdit = nil;

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
   uPanelUpdate;       // WM_PANEL_UPDATE

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
             (aMsg = WM_DRAWITEM) or
             (aMsg = WM_MEASUREITEM) or
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
             //     survived two wrong diagnoses before this one.
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
             (aMsg = WM_PANEL_UPDATE) or
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
function TR4WFormSubclassProc(TRHWND: HWND; Msg: UINT;
                              wParam: wParam; lParam: lParam): longword; stdcall;
begin
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


procedure TTR4WMainForm.lstPossibleCallDrawItem(Control: TWinControl;
                                                Index: integer; ARect: TRect;
                                                State: TOwnerDrawState);
begin
   if Assigned(PossibleCallDrawProc) then
      begin
      PossibleCallDrawProc(Control, Index, ARect, State);
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
                              const aField: TTR4WEntryField): HWND;
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
      TR4WCallEdit := edit;
      end
   else
      begin
      edit.OnKeyPress := EntryEvents.ExchangeKeyPress;
      edit.OnKeyDown  := EntryEvents.ExchangeKeyDown;
      TR4WExchangeEdit := edit;
      end;

   // THE OBJECT IS KEPT, not only its handle.  Nothing reads these two yet;
   // they exist because Phase 7 cannot write TR4WMainForm.edtCall.Text while
   // the only thing this function returns is an HWND.
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

end.

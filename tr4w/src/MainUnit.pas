
{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

 This file is part of TR4W (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
 Public License along with TR4W in GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 }

unit MainUnit;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}

interface

uses
  uMainWindowProc, // TTR4WEntryField -- CreateCallOrExchangeWin names the field
  Graphics,        // TFont -- ApplyMainFontTo, for controls the LCL draws
  uConfigValues,   // Config.CodeSpeedIncrement
  Types,               // TRect -- the OnDrawItem signature qualifies it as
                       // Types.TRect because this unit also uses Windows,
                       // whose TRect is a DIFFERENT declaration; a method
                       // built on the wrong one will not match TDrawItemEvent
                       // however identical the two records look.
  Controls,            // TWinControl -- the OnDrawItem signature (Phase 3b).
  Forms,               // TCustomForm -- the tw_ windows that are LCL forms
                       // TRect is QUALIFIED as Types.TRect where that signature is
                       // declared: this unit also uses Windows, whose TRect is a
                       // DIFFERENT declaration, and a method built on the wrong one
                       // will not match TDrawItemEvent however identical the two
                       // records look.  Types is already in the implementation uses.
  uFlasher,    { the call-field flash is a timer now }
  StdCtrls,            // TListBox, TOwnerDrawState -- same
  LCLIntf,             // OpenURL / OpenDocument -- the cross-platform launchers
  LCLType,             // BOOL, SM_CXSCREEN, VK_CONTROL, VK_MENU -- was Windows
  FileUtil,            // CopyFile -- QUALIFIED at the call site, because this
                       // unit also uses Windows and CopyFile is a name in both
  uPlatformProcess,    // RunProgram / RunWindowsUtility -- the only launchers
  Logstuff,
  uADIF,
  uMenu,
  uAltD,
  uMessagesList,
  uMMTTY,
  utils_text,
  uCallSignRoutines,
  uCallsigns,
  uCTYDAT,
  uBMCF,
  uIO,
  utils_file,
  { $ IF LANG = 'RUS'}
  { $ IFEND}

  // ShellAPI,
  uMults,
  // uSelectFile,
  //
  (* uErmak, *)   { ERMAK commented out -- see the banner in uErmak.pas }
  uCheckLatestVersion,
  // uMakeHelpFile,
  uAltP,
(* THE WINDOWS-ONLY IMPORTS, TOGETHER (2026-09-08, NY4I).

  Windows moved here from its own line further down. A `uses` entry is resolved
  BEFORE any conditional inside the unit body, so gating the CODE while leaving
  the clause ungated is a gate that can never fire -- the compiler fails on the
  clause and never reaches the code. That is the same lesson TF learned; see
  the note on its own gated block.

  THIS DOES NOT MEAN MainUnit COMPILES OFF WINDOWS. It has plenty of Win32 left
  in it. What it means is that the ones already gated now have a clause that
  agrees with them, and the next one to go leaves a shorter list rather than
  changing nothing measurable. *)
{$IFDEF WINDOWS}
  MMSystem,     // sndPlaySound + timeKillEvent, both gated at their call site
{$ENDIF}
  uCRC32,
  uCFG,
  uWinKey,
  // uStack,
  uStations,
  uGetScores,
  uSpots,
  uIntercom,
  uGetServerLog,
  uMessages,
  LPT,
  uQTCS,
  uQTCR,
  uCbrSum,
  PostUnit,
  uWinManager,
  uBandmap,
  TF,
  Version,
  VC,
  uGradient,
  uNet,
  uCAT,
  uAutoCQ,
  uFileView,
  uTelnet,
  uFunctionKeys,
  uRadio12,
  uSendKeyboard,
  uSendSpot,
  uDupesheet,
  uRemMults,
  // uReminder,
  uTotal,
  uMaster,
  uInputQuery,
  uEditQSO,
  uSynTime,
  uBeacons,
  (* A NOTE STOOD HERE CLAIMING "uCommctrl IS STILL HERE FOR TLVItem", AND IT
    WAS WRONG TWICE (removed 2026-09-08). There was no `uCommctrl` in this
    clause, and there is no uCommctrl.pas in the tree -- the unit was deleted
    and its note was not. And the type it named came from the WINDOWS unit
    (FPC declares it in rtl/win/wininc/struct.inc), not from a commctrl
    header at all.

    NY4I put it plainly: "the whole concept of a commctrl unit in an LCL
    application makes no sense anymore." It does not, and there was not one --
    only a comment insisting otherwise, which I read and repeated before
    checking.

    The type itself is gone now too; see EmitCol. *)
  uDialogs,
  uLogSearch,
  (* WINDOWS STAYS, AND THE REMAINING BILL IS SMALL -- SMALLER THAN THE NOTE
    THAT STOOD HERE CLAIMED (corrected 2026-09-08, NY4I).

    THE EARLIER MEASUREMENT WAS TAKEN WRONG, and the mistake is the useful
    part. It removed the import, built for WINDOWS, and reported all 53
    errors as the bill. But on a Windows build every {$IFDEF WINDOWS} block
    is LIVE, so that count includes code which is already gated and is not a
    portability problem at all. It conflated "needs the Windows unit when
    building for Windows" with "still binds this unit to Windows".

    Measured properly -- by gate state, not by error count:

    UNGATED `Windows.`-QUALIFIED CALLS: TWO.

      SetEvent           (~1180)  one of the four CreateEvent objects shared
                                  with uNet and uProgramMain. They move
                                  together or not at all, and logk1ea's
                                  tCWSleep waits on one with a timeout, so
                                  this is CW element timing.
      (LoadLibrary is GONE -- RichEditOperation moved to uMMTTYForm on
       2026-09-08, taking the RICHED32 refcount and VC's RichEditObject
       globals with it. Both its callers were MMTTY window lifecycle.)

    ALREADY GATED, and therefore NOT remaining work: CreateFontW,
    GetWindowRect, FindFirstFileA, FindClose, lstrcatA -- five calls the old
    note listed as outstanding.

    UNGATED CALLS WRITTEN WITHOUT THE `Windows.` PREFIX: THREE.

      ExitProcess              (~3784) how tr4w_ShutDown leaves. Halt is the
                                       portable one and the difference is
                                       REAL -- Halt runs finalization
                                       sections, ExitProcess does not -- so
                                       this is a decision about shutdown,
                                       not a swap.
      SetThreadPriority +
        THREAD_PRIORITY_LOWEST (~7505) FPC has ThreadSetPriority; the value
                                       mapping is not one-for-one.
      EscapeCommFunction       (~6753) serial line control, and uSerialPort's
                                       business rather than this unit's.

    EVERYTHING ELSE UNGATED IS A CONSTANT OR A TYPE LCLType ALREADY DECLARES,
    and that part is mechanical: IDYES/IDNO/IDOK/IDCANCEL, SW_HIDE,
    SW_SHOWNORMAL, SWP_NOSIZE, SWP_SHOWWINDOW, VK_CONTROL, VK_MENU,
    MF_GRAYED, MF_BYPOSITION, SM_CXSCREEN, BOOL, INVALID_HANDLE_VALUE,
    LoWord. (LVIF_TEXT and the list-view item type were on this list and are
    gone entirely -- see EmitCol.)

    AND TWO ARE NOT WINDOWS AT ALL: odSelected and odFocused are the LCL's
    own TOwnerDrawState.

    ORDER THAT MAKES IT CHEAP: LCLType first (mechanical, most of the list),
    then ExitProcess/SetThreadPriority/EscapeCommFunction, then the four
    shared events LAST because they are not this unit's to move alone.

    HOW TO RE-MEASURE THIS, AND THE LISTS ABOVE ARE NOT THE BEST SOURCE.
    NY4I, 2026-09-08: "unqualified identifiers reported by the compiler are
    the best source of truth." He is right, and the lists above are a GREP
    MODEL of what the compiler would say -- useful, but not authoritative,
    and the earlier version of this note was wrong precisely because a grep
    and a Windows-target build were treated as if they were.

    THE AUTHORITATIVE MEASUREMENT IS tools/Compile-Linux.ps1 MainUnit.pas:
    it takes the NON-Windows arm of every gate, so its "Identifier not found"
    list is exactly the ungated bill, with no judgement of mine in between.

    IT CANNOT ANSWER YET, AND THAT IS THE REAL BLOCKER. MainUnit's
    dependencies fail first, so the compiler never reaches this unit. As of
    2026-09-08 the chain is: logk1ea (FIXED -- feInvalidHandle, this commit),
    then uMMTTY, which needs UINT, TColorRef and LF_FACESIZE and is
    Windows-only by nature. Clear the chain and the compiler replaces every
    list above with a fact. *)
{$IFDEF WINDOWS}
  Windows,
  Messages,
{$ENDIF}
  LogK1EA,
  BeepUnit,
  //LOGDDX,
  LogDom,
  LogDupe,
  LOGDVP,
  LogEdit,
  LogGrid,
  // LOGMENU,
  LogNet,
  LogPack,
  LogRadio,
  LogSCP,
  LOGSUBS1,
  LOGSUBS2,
  LOGWAE,
  LogWind,
  Tree,
  SysUtils,
  StrUtils,
  ZoneCont,
  classes,
  IdGlobal,
  uWSJTX,
  uDXLabPathfinder,
  Math,
  Log4D,
  uFactoryRadioBase,
  uRadioBand,
  uExternalLogger,
  IdURI
  ,
  uTR4WStrings,
  uAnsiStr,
  LCLStrConsts;

var
  Begin_QSO: boolean = False; // 4.115.3
  JA_Switch: boolean = False; // 4.72.5
  VK_Switch: boolean = False; // 4.72.5
  K_Switch: boolean = False; // 4.72.5
  VE_Switch: boolean = False; // 4.72.5
  PTT_SET: boolean = False; //4.53.9
  InSplit: boolean = False;
  { QWord with GetTickCount64: the on-air timer subtracts this from a tick,
    and a 32-bit stamp against a 64-bit clock only agrees under 49.7 days
    of uptime. Written by LogCfg and logwind, read by logwind. }
  StartCPU: QWord;
  STString: Str10; // 4.56.7
  Switch: boolean = False;
  SwitchNext: boolean = False; // 4.52.3
  CallWinKeyDown: boolean = False; // 4.52.4
  CallWindowCharConsumed: boolean = False; // set by CallWindowKeyDownProc when it fully handles a char
  FontS: integer;
  FirstQSO: Cardinal;
  T1: Cardinal;
  Esc_Counter: integer = 0;
  Call_Found: Boolean = False;
  Second: Boolean = False;
  Third: Boolean = False;
  wsjtx: TWSJTXServer;
  externalLogger: TExternalLogger;
  // saveLastADIFName / saveLastContest cache moved to uADIF.pas with
  // GetContestByADIFName (Issue #887).
  logger: TLogLogger;
  appender: TLogFileAppender;
  s1, s2, s3, s4: str20;
  Exchw: str20;
  Callw: str20;
  Act_Freq: Cardinal = 0;
  Act_Band: BandType;
  Inact_Freq: Cardinal = 0;
  Inact_Band: BandType;
  so2r_swap: boolean = false;

function ConvertPortTypeToCOMString(port: PortType): string;
procedure CheckNumber;
procedure RunPlugin(PluginNumber: integer);
procedure LoadInPlugins();
procedure OpenListOfMessages;
procedure OpenStationInformationWindow(const aOnAccept: TCabrilloSummaryAction);
function GetAddMultBand(Mult: TAdditionalMultByBand; Band: BandType): BandType;
procedure scWK_RESET; // n4af 4.43.10
procedure SetCommand(c: PAnsiChar);
procedure ImportFromADIF;
procedure CheckQuestionMark;
(* TelnetWantsClipboardKey IS GONE (2026-09-07) -- it had no caller.

  Issue #23: it told the hand-rolled message loop to skip TranslateAccelerator
  when Ctrl-C/V/X/A/Z was pressed inside the DX cluster window, so the cluster's
  edit field got the keystroke instead of the main accelerator table stealing it
  (Ctrl-V was Execute Config File, Ctrl-C was Clear Mult Sheet).

  BOTH HALVES OF THAT ARE GONE. There is no hand-rolled loop -- the program runs
  Application.Run -- and TranslateAccelerator appears nowhere in live code. An
  LCL edit control receives its own clipboard keys, which is what made the
  function unnecessary rather than merely uncalled. *)
procedure InvertBooleanCommand(Command: PBoolean);
procedure RunExplorer(Command: PAnsiChar);
procedure OpenInDefaultTextEditor(FileName: PAnsiChar);   // Issue #986
{ THE POSSIBLE-CALL LIST'S OWNER-DRAW, declared here because CreateMainWindow
  assigns it long before the drawing code appears further down.

  A CLASS because OnDrawItem is a METHOD pointer -- the same reason
  TTR4WEntryEvents exists for the entry fields' key handlers.  One instance, no
  state; it exists to give the handler an implicit Self. }
procedure PossibleCallsDrawItem(Control: TWinControl; Index: integer;
                                ARect: Types.TRect; State: TOwnerDrawState);

procedure RunOptionsDialog(f: CFGFunc);
// A STRING, NOT A PChar.  The declaration was PChar, which binds to PWideChar
// in this unit, while every interesting caller holds an ANSI buffer -- so the
// two menu items repointed here in 2026-08 did not compile until the TYPE was
// fixed rather than cast at the call site.  See CLAUDE.md on type honesty:
// the program passes strings, and conversions belong at the real boundary.
procedure OpenUrl(const url: string);
function ParseADIFRecord(sADIF: string; var exch: ContestExchange): boolean;
procedure ProcessImportedSRX_String(fieldValue: string; var exch:
  ContestExchange);
// GetContestByADIFName moved to uADIF.pas (Issue #887).
procedure SetExtendedModeFromMode(RData: ContestExchange);
function GetTR4WBandFromNetworkBand(band: TRadioBand): BandType;
// GetRadioBandFromBandType moved to radioFactory\uRadioBand.pas (2026-08-07),
// beside the other band mappings.  Its only caller is a radio driver, and
// reaching it here forced that driver to pull in this unit's whole graph.
procedure GetTRModeAndExtendedModeFromNetworkMode(netMode: TRadioMode; var mode:
  ModeType; var extMode: extendedModeType);

procedure LoadinLog;
(* THE TEXT OF ONE LOG ROW, COLUMN BY COLUMN.

  BuildLogRow is the only thing that knows how a QSO is displayed -- 360 lines
  and 36 columns of it. It used to write STRAIGHT INTO A WIN32 LISTVIEW, which
  a virtual grid cannot use: the grid asks "what is the text of row N, column
  C" and there was nowhere to ask.

  SO THE ROUTINE WAS LEFT ALONE AND ONLY ITS DESTINATION MOVED. Every
  condition, every goto and every special case is where it always was, and the
  31 widget calls became one helper writing into this array. That was
  deliberate: the conditionals are where a display bug would hide, and nothing
  in the corpus or the unit tests looks at a rendered row, so restructuring
  them would have been unverifiable.

  THE LISTVIEW HALF IS NOW GONE TOO (2026-09-06), with the last window that
  had one -- so this is not one of two destinations any more, it is the only
  one. tAddContestExchangeToLog, which was the other, is deleted.

  TLogRowText and PLogRowText are declared in VC, beside LogColumnsType: both
  the filler here and the LCL forms that read it need them. *)
procedure LogRowTextFor(const RXData: ContestExchange; out aText: TLogRowText);


procedure GenerateCallsignsList(FileName: PAnsiChar);
procedure MakeAllCallsignsList;

procedure showint(Num: integer);
(* ShowMessage2 and ShowMessageParent are GONE (2026-09-07) -- see the body.
  One had no callers, the other had one and was identical. *)
procedure ShowMessage(Text: string);
procedure ShowSyserror(ErrorCode: Cardinal);
procedure FilePreview;

procedure tCallWindowSetFocus;
procedure tExchangeWindowSetFocus;
procedure tRuntPaddleAndFootSwitchThread;
//procedure TryToLoadRICHED32DLL;
procedure InitializeQSO;
procedure CreateCallOrExchangeWin(Top, ID: integer; const aField: TTR4WEntryField);
procedure TimeApplet(i: Cardinal);

{ ASK THE OPERATOR, WITHOUT AN HWND.

  The parameter never carried information: fifteen of the twenty-two callers
  passed tr4whandle, a literal 0, or their own Self.Handle -- three spellings
  of "parent it to the application".  An LCL dialog is application-modal and
  parents itself to the active form, so there is nothing left to pass.

  THE DEFAULT BUTTON IS PART OF THE BEHAVIOUR, NOT OF THE STYLING.  The Win32
  call passed MB_DEFBUTTON2, so No was focused and a reflexive Enter answered
  No -- on prompts including "do you really want to clear the log".  Plain
  MessageDlg focuses the FIRST button, so the obvious swap would have moved
  every one of those defaults to Yes: same buttons, same words, one keystroke
  away from a different outcome, and invisible in review.  QuestionDlg takes
  an IsDefault marker that applies to the button before it (LCL
  promptdialog.inc:900), which keeps Yes/No in that order with No focused.
  NY4I, 2026-08-28: "that could impact operator muscle memory".

  The captions now come from the LCL and are translated with the rest of the
  program; MessageBoxW took them from the OS locale, which ignored --lang.

  MB_TOPMOST is gone with the HWND.  It existed to beat TR4W's always-on-top
  main window, and an application-modal LCL dialog does not need it. }
(* THE HWND FORMS ARE GONE, on their own terms.

  Two overloads took an owner window and called MessageBoxW/MessageBoxA, under
  a note that read "THE HWND FORMS, FOR THE SEVEN CALLERS THAT STILL HAVE A
  REAL ONE: uQTCR, uQTCS and uNewContest are Win32 DIALOGS ... These die when
  those three convert; do not add callers."

  All three converted. Measured 2026-09-06: all TWENTY-TWO call sites in the
  tree pass a string and nothing else, so the overloads had no callers at all
  while the comment still asserted seven. `overload` goes with them -- each
  name is a single function again. *)
function YesOrNo(const Text: string): integer;
function YesOrNo2(const Text: string): integer;
(* PTTOffWhenStopWAV IS GONE (2026-09-07). It was a Win32 TIMERPROC that
  nothing ever registered -- no SetTimer, no timeSetEvent, anywhere in the tree
  -- so the PTT it was meant to drop after a WAV finished was never dropped by
  it. WAV_STOP_PTT_TIMER_IDENTIFIER was read only inside it and was never
  assigned a timer id either, which made its KillTimer a call against zero. *)
procedure OneSecondTick;

procedure SaveTR4WPOSFILE;
procedure StartLayoutAutosave;
procedure StopLayoutAutosave;
procedure LoadTR4WPOSFILE;
procedure RevalidateOpenWindowsOnScreen;

procedure FrmSetFocus;
procedure tAltE;
procedure SetWindowSize;
function OpenLogFile: boolean;
function tSetFilePointer(lDistanceToMove: LONGINT; aOrigin: Longint): Int64;

procedure CloseLogFile;
function ReadLogFile: boolean;
procedure ShowPreviousDupeQSOsWnd(show: boolean);
procedure TryPutSpaceinExchangeWindow;
procedure ShowInformation;
procedure QuickQSLProcedure(Key: Char);
procedure StartSendingNow(FromKeyBoard: boolean);
procedure ClearLog;
procedure ReadVersionBlock;
procedure MakeTestLog;
//function TryToCheckTheLatestVersion: boolean;
procedure tGetSystemTime;
procedure SystemTimeChanging;
function AddRecordToLogAndSendToNetwork(var CE: ContestExchange): boolean;
procedure CompleteCallsign;
function GetRealVirtualKey(var Key: integer): Byte;
procedure Escape_proc;
function GetCPU: int64;
function TuneOnFreqFromCallWindow: boolean;
procedure ReturnInCQOpMode;
procedure ReturnInSAPOpMode;
function Send_DE: boolean;
procedure SendB4;
// procedure ProcessKeyDownTerm; // 4.46.2
function TryLogContact: boolean;
procedure SpaceBarProc;
procedure SpaceBarProc2;

procedure FindAndSaveRectOfAllWindows;
function TryKillAutoCQ: boolean;
procedure RunAutoCQ;

procedure TestMP;
procedure FlashCallWindow;
procedure ProcessCommandLine;
procedure PutCallToCallWindow(Call: CallString);
procedure SetColumnsWidth;
procedure SaveColumnWidthToConfig(ColIndex: Integer; NewWidth: Integer);
procedure ExecuteConfigurationFile(const f: AnsiString);
procedure CheckEditableWindowHeight;
function CheckCommandInCallsignWindow: boolean;
procedure ClearMultSheet_CtrlC;
procedure tClearMultSheet;
procedure ReCalculateHourDisplay;
procedure SetRemMultsColumnWidth;
procedure CheckInactiveRigCallingCQ;
procedure tAltI;
procedure tr4w_alt_n_transmit_frequency;
procedure tr4w_toggle_sidetone;
procedure tClearDupesheet_Ctrl_K;
procedure tClearDupesheet;
procedure tr4w_add_note_in_log;
procedure tr4w_log_qso_without_cw;
(* THE MAIN WINDOW'S NATIVE HANDLE, derived, never cached.

  For the handful of Windows-only APIs that take one -- DWM, HtmlHelp, MAPI
  and MMTTY -- and for nothing else. Everything that merely wants to parent,
  own, show or address a window has an LCL form to do it with.

  Answers 0 before the form exists, which is what every caller's guard already
  tested tr4whandle for. *)
function MainWindowHandle: THandle;

procedure tr4w_ShutDown;
procedure CallWindowChange;
procedure ExchangeWindowChange;
procedure CreateFonts;
//procedure CreateMWFonts;
function MainFontCellHeight: integer;
procedure ApplyMainFontTo(aFont: TFont);
//function DrawEdit(lParam: lParam; wParam: wParam): Cardinal;
procedure ProcessMenu(menuID: integer);
procedure ProcessTAB(lowparam: Word);
procedure ProcessReturn;
procedure CreateMainWindow;
procedure CallWindowKeyDownProc(wParam: integer);
procedure CallWindowKeyUpProc;
procedure ExchangeWindowKeyDownProc(wParam: integer);
procedure RepeatLastCWMessage;
{ Re-title the radio panels from whatever radio is now in each slot. Call after
  anything that repoints a slot -- activating a profile, or changing the radio
  in the CAT dialog. Safe when a panel is closed. }
procedure RefreshRadioWindowCaptions;

(* SET A MENU ITEM'S ENABLED / CHECKED / CAPTION BY COMMAND ID, or do nothing
  if the menu has no such row.

  These replace CheckMenuItem / EnableMenuItem / ModifyMenu on the menu HANDLE.
  MenuItemById answers nil for an id the menu does not contain, and that is an
  ORDINARY outcome here -- the POTA rows are hidden outside a POTA contest, and
  the window menu is asked about ids a given build may not have. Reaching a nil
  would be an access violation inside a menu handler, so the guard lives in one
  place rather than at twenty call sites. *)
procedure SetMenuEnabled(const aId: word; const aEnabled: boolean);
procedure SetMenuChecked(const aId: word; const aChecked: boolean);
procedure SetMenuCaption(const aId: word; const aText: string);

{ The item's caption, or '' when the menu has no such row. }
function MenuCaption(const aId: word): string;

procedure OpenTR4WWindow(ID: WindowsType);
procedure OpenOtherWindows;
procedure CloseTR4WWindow(ID: WindowsType);

{ CLOSE A WINDOW FROM OUTSIDE IT -- the door for anything that is not the
  window's own OnClose.

  CloseTR4WWindow is the PRIMITIVE: it destroys the handle and updates the
  table, and a form's OnClose is expected to have already decided to hide.
  Calling it on an LCL form that is still Visible destroys the handle behind
  the framework's back, and the widget set simply RECREATES it -- the window
  does not go away, and WndHandle is left 0, so the next request opens it
  again. That is the caNone failure reached through a different door, and it is
  why the Windows-menu entry and the accelerator would not close the Stations
  window (NY4I, bench queue). Measured 2026-08-26: open -> 11 windows, command
  again -> still 11.

  So: if this ID is an LCL form, ask the FORM to close. Its OnClose sets
  caHide and calls CloseTR4WWindow itself. }
procedure RequestCloseTR4WWindow(ID: WindowsType);

procedure SetOpMode(OperationMode: OpModeType);

{ Push the entry fields' colours into the controls.  Cheap and idempotent; call
  it after anything that changes either the palette or the operating mode. }
procedure RefreshEntryFieldColors;

{ The same, for the main window's own elements -- including the five whose
  colour depends on live state.  See the implementation. }
procedure RefreshMainWindowElementColors;

{ See the implementation: the one rule both the sweep and uStateBridge use. }
function WSJTXIndicatorBack: tr4wColors;

procedure ProcessFuntionKeys(Key: integer);
procedure CreateDirectoryIfNotExist;
procedure CheckAndSetInitialExchangeCursorPos;
procedure ClearInfoWindows;
function Get_Ctl_Code(nr: integer): Cardinal;
procedure DebugMsg(s: string); // ny4i
function IsCWByCATActive(theRadio: RadioPtr): boolean; overload;
// ny4i Issue # 111
function IsCWByCATActive: boolean; overload; // ny4i Issue # 111

// ADIFDateStringToQSOTime, ADIFTimeStringToQSOTime moved to uADIF.pas (Issue #887).
function DigitsIn(n: smallInt): byte;
function GetModeFromExtendedMode(extMode: ExtendedModeType): ModeType;

function ParametersOkay(Call: CallString;
  ExchangeString: Str40 {CallString};
  Band: BandType;
  Mode: ModeType;
  Freq: LONGINT;
  var RData: ContestExchange): boolean;

//procedure PossibleCallsProc(PCDRAWITEMSTRUCT: PDrawItemStruct);

procedure EditableLogWindowDblClick;
procedure tClearDupeInfoCall;
procedure tCleareCallWindow;
procedure tCleareExchangeWindow;
procedure tSetExchWindInitExchangeEntry;
procedure HandleRepeatPOTAParks;
//function AddCallsignAndExchangeToInitialExchangesList(Call: CallString; InitialExchangeString: CallString): boolean;
//function FindStringInInitCallsignListBox(s: CallString; var Index: integer): boolean;

procedure tWinHelp(WindowHelpID: Byte);

function AskConvertLog(sVersion: string): boolean; // ny4i




procedure UpdateWindows;
procedure tUpdateLog(UpdAction: UpadateAction);
//procedure SelectFileOfFolder(Parent: HWND; FileName: PChar; Mask: PChar; SelectType: CFGType);

//procedure main(LogFileName: pchar; var CreatedReport: pchar; var ReLoadLog: boolean); stdcall external 'Plugins/tr4wSortLog.dll' name 'main';

procedure PTTOn;
procedure PTTOff;

procedure ResetRadioPorts;
procedure WagCheck;

type
  Tmain = procedure(
    LogFileName: PAnsiChar;
    var CreatedReport: PAnsiChar;
    var ReLoadLog: boolean;
    var MakeRescore: boolean;
    ExchangeInformation: ExchangeInformationRecord;
    ActiveExchange: ExchangeType;
    reserved1: integer;
    reserved2: integer;
    reserved3: integer
    ) stdcall;

  Ttr4wGetPlugin = function(): PAnsiChar; stdcall;

// TADIF_Fields enum moved to uADIF.pas (Issue #887).

var
  debugstr: string;
const
  CWByCATBufferTerminator = Chr(242);
  tAboutText =
    TR4W_CURRENTVERSION +
    ' - ' +
    TR4W_CURRENTVERSIONDATE +
    #13 +
    '2006 - 2012 Dmitriy Gulyaev UA4WLI' + #13 +
    'TR4WSERVER version - ' + TR4WSERVER_CURRENTVERSION + #13#13 +
    'https://tr4w.net'#13#10

  // 'Log format version - v.1.' + LOGVERSION4 + #13 +
  // 'Compiler directives: ['{$IFOPT I+} + 'I'{$ENDIF}{$IFOPT R+} + 'R'{$ENDIF}{$IFOPT Q+} + 'Q'{$ENDIF} + ']'
{$IFNDEF LANG_ENG} + #13'Language: ' + TC_TRANSLATION_LANGUAGE + ' (by ' +
  TC_TRANSLATION_AUTHOR + ')'{$ENDIF} + #13#10 +
  'On basis of the source code of the TRLog v.6.80 UA4WLI + Larry Tyree N6TR' + #13
    + //n4af 4.30.0
  'Current development team = N4AF, NY4I, UR7QM '; //n4af 4.30.0
  // Radio1AsPchar : PChar = TC_RADIO1;
  // Radio2AsPchar : PChar = TC_RADIO2;

implementation

uses
   uAppTimers,   (* StartAppTimer / StopAppTimer -- LCL TTimers, not SetTimer *)
  Menus,              // TMenuItem -- the menu is a TMainMenu now
   uWindowTable,   { tr4w_WindowsArray, tWindowsExist -- moved out of VC/TF }
  { The SQLite shadow -- an IMPLEMENTATION-section use, so no interface
    cycle. It never raises and never blocks logging: see uLogStore. }
  uLogStore,
  uLogEditForm,       // View / Edit Log -- an LCL virtual list now; also
                      // SaveLogEditLayout, see SaveTR4WPOSFILE
  uContestFileKind,   // a .db is not an INI -- see SaveColumnWidthToConfig
  (* Which store a log READ comes from -- step B4.  Its implementation
     uses this unit back, which is legal: both edges are
     implementation-section. *)
  uLogSource,
{$IF tDebugMode}
  // uDocumentation,
{$IFEND}

// FMX is Delphi-only.  Under FPC the LCL is the intended replacement (proven on
// the bench: an LCL form runs inside TR4W's own GetMessage loop, and TThread.Queue
// drains), but that port is not done, and blocking every other unit on it would
// mean never finding out whether the CONTEST ENGINE works under FPC.  Excluded
// here so the FPC build can be built and tested; the three commands below are
// simply unavailable in it.  This guard comes OUT with the LCL port.
  uUDPBroadcastConfig, // TUDPStream / usLookup
  uPanelUpdate,     // ForgetPanel -- see CloseTR4WWindow
  uUDPBroadcaster,  // Enabled() -- the broadcaster owns the enable rule
  Dialogs,             // QuestionDlg -- the HWND-free YesOrNo, see below
  uMainForm,
  uAboutForm,   // ShowAboutBox -- the designed About box        // the main window IS
  uBandMapForm,        // CreateTR4WBandMapWindow -- the band map tool window
  uCrashLog,           // LogCaughtException, OnMainThread
  uStateBridge,        // InstallStateBridge -- the domain/UI crossing
  uMainThreadWork,     // mtMainWindowElementColors
  uStationsForm,       // CreateTR4WStationsWindow -- the stations tool window
  uTelnetForm,         // CreateTR4WTelnetWindow -- the DX cluster tool window
  uMMTTYForm,          // CreateTR4WMMTTYWindow -- the LAST Win32 tool window
  uDupeSheetForm,      // CreateTR4WDupeSheetWindow -- both dupe sheets
  uMasterForm,             // CreateTR4WMasterWindow -- the SCP window
  uPostScoresForm,         // CreateTR4WPostScoresWindow
  uHamScoreForm,           // CreateTR4WHamScoreWindow
  uIntercomForm,           // CreateTR4WIntercomWindow
  uRadioPanelForm,         // CreateTR4WRadioPanelWindow -- both radios
  uNetworkForm,            // CreateTR4WNetworkWindow
  uRemMultsForm,       // CreateTR4WRemMultsWindow -- all five mult windows
  uFunctionKeysForm,   // CreateTR4WFunctionKeysWindow -- the first LCL tool window a TForm now -- CreateTR4WMainForm
  uPrefsForm,       // the PREF command -- the radio Preferences window
  uTCIServer,       // the TCI server, stopped in tr4w_ShutDown
  uRadioPolling,
  uRadioRegistry,   // the rc* capability members (re-exported for using units)
  uHamScore,        // Issue #783 -- HamScoreResyncFromScratch (Tools menu)
  LogCfg,
  LogCW,
  uCWKeyerBase,     // ActiveCWKeyer -- autosend routing (B2)
  uCT1BOH,
  CfgCmd,
  CFGDEF,
  // Country9,
  FCONTEST,
  uPOTAParks,
  uPendingCounties,
  uCTYUpdate,
  uTRMasterUpdate,  // Download TRMASTER.DTA (Super Check Partial)
  ExtCtrls,           // TTimer -- the window-layout autosave
  DateUtils,          // MilliSecondsBetween -- the start-up timing
  uLogSearchForm,     // SaveLogSearchLayout -- not a tw_ window, see SaveTR4WPOSFILE
  uWindowLayoutStore, // the window layout, keyed by name
  uTR4WConfigFile,   // TR4WConfigFileName / Save- LoadWindowLayout
  uWSJTXState,       // the state the WSJT-X indicator paints from
  uPanadapterForm;   // it is not a tw_ window, so it saves its own row




// GetCPU -- a monotonic high-resolution counter for the debug timing readout.
//
// Was `db 0fh,31h`, i.e. a raw RDTSC opcode emitted as bytes. Two problems with
// that beyond not assembling on a 64-bit compiler: the timestamp counter is
// per-core, so a thread migrating between cores can read it going BACKWARDS,
// and its tick rate is not a documented constant on modern CPUs.
//
// QueryPerformanceCounter is the supported replacement, is monotonic across
// cores, and is what every other timing site in this program already uses. The
// UNIT changes from CPU cycles to QPC ticks, which affects nothing: the only
// compiled caller displays the delta across a block that is itself inside a
// {$IF tDebugMode} switch, and the LOGK1EA caller is inside the same one. Both
// compile out of every shipping build.
//
// (These are // comments deliberately: a {$IF ...} directive inside a { } block
// comment ends that comment at its own closing brace, which is exactly how the
// first version of this note failed to compile.)

function GetCPU: int64;
begin
  (* GetTickCount64, not Windows.QueryPerformanceCounter.

    THE UNIT CHANGES AND THE NAME NO LONGER FITS. This was CPU cycles (a raw
    RDTSC), then QPC ticks, and it is MILLISECONDS now. Both remaining callers
    are inside {$IF tDebugMode} and one of them has its arithmetic commented
    out, so nothing in a shipping build reads either the value or its
    resolution -- which is the only reason a coarser clock is acceptable here.

    IF SUB-MILLISECOND TIMING IS EVER NEEDED, this is not the function to
    stretch: the assessment of per-platform high-resolution timers, EpikTimer
    included, is in docs/PLATFORM_CLOCK_ABSTRACTION.md part 2. The CW element
    clock in LOGK1EA is the caller that would want it, and it already says in
    its own comment that its off-Windows arm will not key a contest.

    Monotonic on every platform FPC targets, which the original RDTSC was not:
    the timestamp counter is per-core, so a thread migrating between cores
    could read it going backwards. *)
  Result := int64(GetTickCount64);
end;

(* MOVED TO uHostName ON 2026-09-07 -- see that unit for why it is a unit.

  In short: there is no portable RTL call for a host name (Windows has
  GetComputerNameW, Unix has unix.pp's GetHostName, and neither compiles on the
  other), so a conditional is unavoidable. What was avoidable was having it in
  the middle of this file. Its two callers -- the HamScore XML in LOGSUBS2 and
  the PSTRotator XML in uRadioPolling -- now use uHostName.LocalComputerName
  directly. *)

// Logs additional QSO records when the operator entered multiple POTA park
// references or multiple counties in a single exchange.  The parser
// (ProcessRSTAndPOTAPark / ProcessRSTAndDomesticQTHExchange) places extras
// onto uPOTAParks's or uPendingCounties's queue; this procedure drains both
// queues and writes one extra QSO per queued ref.
//
// Kept in its own procedure rather than inlined into TryLogContact so the
// extra ReceivedData accesses do not push TryLogContact past the threshold
// where Delphi 7 pins @ReceivedData into ESI as an optimization (an
// optimization that interacts badly with the calls in this drain logic and
// produced an AV at TryLogContact's later @ReceivedData accesses).
//
// Issue #885 (county lines) and POTA Nfer.

// Build the per-QSO exchange string so each multi-ref QSO gets its own ADIF
// SRX_STRING instead of the combined original input.  Issue #889.
//
// The leading field has to match what the operator actually typed for this
// exchange, because ExchString is echoed into SRX_STRING: the serial-number
// exchanges (CQP, PA and VA QSO Parties) carry a received QSO number where
// the RST exchanges carry an RS(T).  Emitting the RST for a serial-number
// contest would put the defaulted 599 into the log in place of the number
// the station actually sent.
function PerQSOExchString(const RXData: ContestExchange): string;
begin
  case ActiveExchange of
    QSONumberDomesticQTHExchange,
    QSONumberDomesticOrDXQTHExchange:
       begin
       Result := IntToStr(RXData.NumberReceived) + ' ' + string(RXData.QTHString);
       end;
  else
     begin
     Result := IntToStr(RXData.RSTReceived) + ' ' + string(RXData.QTHString);
     end;
  end;
end;

procedure DrainPendingMultiQSORefs;
var
  TempRX : ContestExchange;
begin
  if (not HasPendingParks)     and 
     (not HasPendingCounties) then
     begin
     Exit;
     end;
  TempRX := ReceivedData;
  while HasPendingParks do
     begin
     TempRX.QTHString := DequeuePendingPark;
     TempRX.ExchString := PerQSOExchString(TempRX);   // Issue #889
     LogContact(TempRX, True);
     end;
  while HasPendingCounties do
     begin
     TempRX.QTHString := DequeuePendingCounty;
     FoundDomesticQTH(TempRX);  // refresh DomMultQTH/DomesticQTH
     TempRX.ExchString := PerQSOExchString(TempRX);   // Issue #889
     // QSO-party rule: a station that changes county is a new station and
     // is NOT a dupe of an earlier QSO with the same call.  The follow-up
     // county records share callsign+band+mode with the first one, so the
     // generic dupe check would otherwise flag them, blank their points,
     // and emit "AF4O is a dupe and will be logged with zero QSO points."
     // Setting ceClearDupeSheet=True bypasses both LogContact's and
     // tUpdateLog(actRescore)'s dupe-stamping for this record only.
     TempRX.ceClearDupeSheet := True;
     // NumberSent is intentionally NOT incremented for county-line follow-up
     // records: per CQ Magazine guidance for the California QSO Party (and
     // other state QPs that combine serial numbers with county-line ops),
     // ALL legs of a single on-air exchange share the one transmitted serial
     // number.  Both records inherit it from the first.  See issue #892 for
     // the related "next station's serial jumps by N" question, which is a
     // separate architectural concern (TotalContacts/QSOTotals is bumped per
     // LogContact call rather than per distinct station worked).
     LogContact(TempRX, True);
     end;
end;

// State-QP rover slash-in-call ("KG1S/MON"):
//
// The operator types a call with a /COUNTY suffix to indicate the rover's
// current county.  TR4W keeps the call AS-IS in the log (KG1S/MON) so the
// operator's intent is preserved end-to-end.  Cabrillo emits the literal
// KG1S/MON; ADIF emits the bare call in the standard <CALL> field plus the
// full form in a TR4W-specific <APP_TR4W_ROVERCALL> field (handled at
// export time in postunit.pas).
//
// At submit time (Enter, just before TryLogContact runs), if the operator
// has not already typed an exchange, move the county from the call's slash-
// suffix into the exchange field so the standard exchange parser sees a
// clean "MON" and produces the right multiplier / log row.  No keystroke-
// time interference — the operator can edit the call freely while typing.

// Detect a state-QP rover slash-in-call.  Returns True when:
//   - active exchange is a state-QP type
//   - CallWindowString contains a '/'
//   - the suffix validates as a domestic QTH (so /M, /P, /4 etc. are left
//     alone for other code paths to handle)
// On True, RoverCounty is populated with the validated county abbreviation.

// Wrap ctyLocateCall so a state-QP rover suffix (KG1S/MON) is stripped
// off the call before the country/zone lookup.  /M would otherwise be
// interpreted as a Great Britain prefix indicator, mislabeling the QSO
// with country=G.  The caller's Call value is unchanged; only the lookup
// uses the bare form.
//
// Falls through to plain ctyLocateCall behaviour when:
//   - active exchange is not a state-QP type
//   - the call has no '/'
//   - the suffix doesn't validate as a domestic QTH (e.g. /M, /P, /4)
//
// Used by ParametersOkay (live entry) and ParseADIFRecord at EOR (import).

function ctyLocateCallStripRover(const Call: CallString; var QTH: QTHRecord): Boolean;
var
  LookupCall  : CallString;
  SlashPos    : Integer;
  ProbeRX     : ContestExchange;
  FoundQTH    : Boolean;
  ProbeSuffix : string;
begin
  LookupCall := Call;
  logger.Info('[ctyLocateCallStripRover] ENTER Call=[%s] ActiveExchange=%d',
              [string(Call), Ord(ActiveExchange)]);
  if ((ActiveExchange = RSTDomesticQTHExchange) or
      (ActiveExchange = RSTQTHExchange) or
      (ActiveExchange = RSTDomesticOrDXQTHExchange)) then
     begin
     SlashPos := Pos('/', string(LookupCall));
     logger.Info('[ctyLocateCallStripRover] QP exchange, SlashPos=%d', [SlashPos]);
     if SlashPos > 0 then
        begin
        FillChar(ProbeRX, SizeOf(ProbeRX), 0);
        ProbeSuffix := UpperCase(
           Copy(string(LookupCall), SlashPos + 1,
                Length(string(LookupCall)) - SlashPos));
        ProbeRX.QTHString := ProbeSuffix;
        FoundQTH := FoundDomesticQTH(ProbeRX);
        logger.Info('[ctyLocateCallStripRover] suffix=[%s] FoundDomesticQTH=%s',
                    [ProbeSuffix, BoolToStr(FoundQTH, True)]);
        if FoundQTH then
           begin
           LookupCall := Copy(string(LookupCall), 1, SlashPos - 1);
           end;
        end;
     end
  else
     begin
     logger.Info('[ctyLocateCallStripRover] NOT a QP exchange, skipping strip', []);
     end;
  Result := ctyLocateCall(LookupCall, QTH);
  logger.Info('[ctyLocateCallStripRover] EXIT LookupCall=[%s] Result=%s CountryID=[%s] Prefix=[%s]',
              [string(LookupCall), BoolToStr(Result, True),
               string(QTH.CountryID), string(QTH.Prefix)]);
end;

function DetectRoverSlashInCall(out RoverCounty: string): Boolean;
var
  CallStr  : string;
  SlashPos : Integer;
  ProbeRX  : ContestExchange;
begin
  Result := False;
  RoverCounty := '';

  if not ((ActiveExchange = RSTDomesticQTHExchange) or
          (ActiveExchange = RSTQTHExchange) or
          (ActiveExchange = RSTDomesticOrDXQTHExchange)) then
     begin
     Exit;
     end;

  CallStr := string(CallWindowString);
  SlashPos := Pos('/', CallStr);
  if SlashPos = 0 then
     begin
     Exit;
     end;

  RoverCounty := UpperCase(Copy(CallStr, SlashPos + 1, Length(CallStr) - SlashPos));
  if RoverCounty = '' then
     begin
     Exit;
     end;

  // Validate the suffix against the domestic-mults table using a scratch
  // ContestExchange so we don't disturb any global state.
  FillChar(ProbeRX, SizeOf(ProbeRX), 0);
  ProbeRX.QTHString := RoverCounty;
  if not FoundDomesticQTH(ProbeRX) then
     begin
     Exit;  // /M, /P, /4 or any non-county suffix — leave alone
     end;

  Result := True;
end;

// When the operator hits Enter in the call window with a rover call
// ("KG1S/MON") and no exchange typed yet, copy the county from the call's
// slash-suffix into the exchange field and move focus there so the
// operator can confirm with another Enter to log.
//
// Called from the start of ReturnInCQOpMode / ReturnInSAPOpMode (the
// Enter-in-call-window handlers) — NOT from TryLogContact, which fires
// only when both call and exchange are filled.
//
// The call itself is left untouched: KG1S/MON is the operator's intent
// and survives through the log, Cabrillo, and the ADIF APP_TR4W_ROVERCALL
// field.

procedure PrefillExchangeFromRoverCallSuffix;
var
  RoverCounty : string;
begin
  if ExchangeWindowString <> '' then
     begin
     Exit;
     end;
  if not DetectRoverSlashInCall(RoverCounty) then
     begin
     Exit;
     end;
  ExchangeWindowString := RoverCounty;
  // The string() step is what Delphi was doing implicitly: PChar() of a
  // ShortString is not a legal cast, PChar() of a string expression is.
  SetEntryText(TR4WExchangeEdit, string(ExchangeWindowString));
  // Move focus to exchange.  The caller's existing focus-move logic only
  // fires when ExchangeWindowString is empty (which won't be true after
  // we just populated it), so we have to do it ourselves here.
  if not Config.LeaveCursorInCallWindow then
     begin
     tExchangeWindowSetFocus;
     end;
end;

function TryLogContact: boolean;
var
  // Saved before ClearContestExchange wipes ReceivedData; passed to
  // SetPendingContactInfo so the WM_POTA_NEXT_PARK handler can restore
  // the call and pre-fill the exchange after the caller's window clears.
  SavedCall    : CallString;
  SavedRSTSent : Integer;
begin
   Result := False;

   (* WHY DID ENTER DO NOTHING? -- instrumentation, 2026-09-03.

     ParametersOkay is the gate between pressing Enter and a QSO existing, and
     it refuses SILENTLY: TryLogContact returns False and the operator sees a
     log that simply did not grow. NY4I has been hitting exactly that and there
     was nothing anywhere in the log to say whether the keystroke arrived, or
     arrived and was refused.

     Both lines below are cheap and fire once per Enter, so they can stay --
     "the operator pressed Enter and no QSO appeared" is a question worth being
     able to answer from a log file rather than from a debugger. *)
   if logger <> nil then
      begin
      logger.Debug('[Log] Enter: call="%s" exch="%s" band=%d mode=%d',
                   [string(CallWindowString), string(ExchangeWindowString),
                    Ord(ActiveBand), Ord(ActiveMode)]);
      end;

   if ParametersOkay(CallWindowString, ExchangeWindowString, ActiveBand,
                     ActiveMode, ActiveRadioPtr.LastDisplayedFreq
                    {LastDisplayedFreq[ActiveRadio]},
                    ReceivedData) then
      begin
      ReceivedData.ceSearchAndPounce := OpMode = SearchAndPounceOpMode;
      ReceivedData.ceComputerID := ComputerID;

    // Issue #889: when this is a multi-county or multi-park entry, the
    // parser has queued additional refs and ParametersOkay just stamped
    // ReceivedData.ExchString with the COMBINED original input
    // (e.g. "57 PIN/HIL").  Rewrite to per-QSO form for the first QSO so
    // each ADIF SRX_STRING reflects only its own ref.
      if HasPendingParks or HasPendingCounties then
         begin
         ReceivedData.ExchString := PerQSOExchString(ReceivedData);
         end;

      LogContact(ReceivedData, True);
      DrainPendingMultiQSORefs;

    // Capture before ClearContestExchange zeroes out ReceivedData.
    // Needed for 2fer refill below.
      SavedCall    := ReceivedData.Callsign;
      SavedRSTSent := ReceivedData.RSTSent;

      tElapsedTimeFromLastQSO := GetTickCount64;
      UpdateWindows;
    // It is not clear to me why we would call SHowStationInformation again.
      ShowStationInformation(@ReceivedData.Callsign);
      ClearContestExchange(ReceivedData);
      LastTwoLettersCrunchedOn := '';
      CallAlreadySent := False;
      ExchangeHasBeenSent := False;
      EditingCallsignSent := False;
      SeventyThreeMessageSent := False;
      EscapeDeletedCallEntry := CallWindowString;

      if (CallWindowString = DupeInfoCall) and 
         (CallWindowString <> MyCall)      then
      // n4af issue 158
         begin
         DupeInfoCallWindowState := diNone;
         TR4WMainForm.pnlDupeInfoCall.Caption := '';
         end;
    // showint(1);
      tCleareCallWindow;
    // showint(2);

      tCleareExchangeWindow;

      tCallWindowSetFocus;
      CleanUpDisplay;

    // A prior bad-exchange attempt (e.g. TC_IMPROPERARRLFIELDDAYCLASS) leaves
    // an error in the QuickCommand window on its own 30s flash timer.  Once a
    // corrected QSO is logged that error is stale, so clear it now.
      ClearQuickDisplayText;

      Result := True;

      if OpMode = SearchAndPounceOpMode then
         begin
         SendSerialNumberChange(sntReserved);
         end;

      SendSerialNumberChange(sntFree);
      StationInformationCall := '';
    // Moved this to the very end of the process to log a contact. ny4i
      end;
end;

procedure ResetRadioPorts;
begin
  logger.info('Resetting radio ports');
  // CheckAndInitializePorts_ForThisRadio -> SetUpRadioInterface handles stopping
  // the old polling thread, disconnecting, freeing, and recreating the radio object.
  ActiveRadioPtr.CheckAndInitializePorts_ForThisRadio;
  InActiveRadioPtr.CheckAndInitializePorts_ForThisRadio;
end;

// (The local pRadio was removed with B1 -- its only live use was the CW busy
//  predicate, which is now LogCW.CWStillBeingSent.)
procedure Escape_proc;
begin

  if CallWindowString <> '' then
     begin
     Call_Found := True
     end
  else
     begin
     Call_Found := False;
     end;

  if ActiveMode in [Phone, FM] then
     begin
     if ActiveRadioPtr^.HasCapability(rcPlayDVK) { and
    (ActiveRadioPtr^.tPTTStatus = PTT_ON) } then
        begin
        ActiveRadioPtr^.MemoryKeyer(0); // Playing memory 0 stops the message.
        end;
     end;

  if (ActiveMode = CW) then
    // ny4i Issue 130 and (IsCWByCATActive) then // n4af 4.45.5 proposed to allow
     begin
     // B5: Esc always stops a radio that is CAT-sending.  The active/inactive
     // pair that stood here is the CAT adapter's StopSending body, verbatim.
     KeyerCAT.StopSending;
     end;

  // SetOpMode(CQOpMode); // n4af 4.46.12

  TryKillAutoCQ;

  if ActiveMode = Digital then
    if MMTTY.mmttyTXIsOn then
       begin
       PostMmttyMessage(RXM_PTT, RXM_PTT_SWITCH_TO_RX_IMMEDIATELY);
       Exit;
       end;

  // B1: the busy test is now the facade's -- CWStillBeingSent asks exactly the
  // ACTIVE keyer, instead of OR-ing three backends' latches together.  The
  // pRadio swap-resolution block that stood here existed only to feed
  // `pRadio.CWByCAT_Sending` into that OR (its other use was already commented
  // out), so it goes with it.  Behaviour deltas, deliberate: the CAT arm now
  // follows ActiveRadioPtr rather than the swap-resolved radio (matching every
  // other CAT busy test -- plan quirk Q6), the YCCC box is now included, and a
  // stale latch on an UNSELECTED backend can no longer make Escape think CW is
  // still going out.
  if ((ActiveMode = CW) and CWStillBeingSent) or
    ((ActiveMode in [Phone, FM]) and (DVPOn = True)) then
     begin
     if tAutoSendMode then
        begin
        EditingCallsignSent := True;
        end;
     tAutoSendMode := False;
     FlushCWBufferAndClearPTT('MainUnit: typing while CW still being sent'); //n4af 4.33.3

     if DVPOn then
        begin
        tExitFromDVPThread := True;
{$IFDEF WINDOWS}
        (* Stop the file, then cancel the duration timer that would otherwise
          signal tDVP_Event again after the thread has gone.  Both are winmm
          and both are gated with their counterparts in LOGDVP -- read the
          note at the top of that unit for what replaces them. *)
        sndPlaySound(nil, SND_ASYNC);
{$ENDIF}
{$IFDEF WINDOWS}
        (* GATED WITH THE TIMER THAT SIGNALS IT. tDVP_Event is handed to
          winmm timeSetEvent in logdvp, so the multimedia timer signals this
          HANDLE -- which is why it cannot become a SyncObjs.TEvent the way
          tNet_Event just did. It moves when the element clock does. *)
        Windows.SetEvent(tDVP_Event);
{$ENDIF}
{$IFDEF WINDOWS}
        timeKillEvent(tDVPTimerEventID);
{$ENDIF}
        DVPOn := False;
        PTTOff;
        DisplayCodeSpeed;
        end;
     exit; // 4.97.4
     end;

  if ActiveRadioPtr^.tTwoRadioMode = TR2 then
    if (not Call_Found) then
       begin
       tCleareCallWindow;
       tCleareExchangeWindow;
       tCallWindowSetFocus;
       ActiveRadioPtr^.tTwoRadioMode := TR0;
       InActiveRadioPtr^.tTwoRadioMode := TR0;
       SwapRadios;
       SetOpMode(CQOpMode);
       Exit;
       end;

  // if tr4w_ExchangeWindowActive then
  if ActiveMainWindow = awExchangeWindow then
    // if ExchangeWindowString <> '' then // 4.97.2
     begin
     tCleareExchangeWindow;
     tCallWindowSetFocus;
     Exit;
     end;

  if Call_Found = True then
     begin
     EscapeDeletedCallEntry := CallWindowString;
     tCleareCallWindow;
     EditingCallsignSent := False;
     CallAlreadySent := False;
     ExchangeHasBeenSent := False;
     SeventyThreeMessageSent := False;
     ClearInfoWindows;
     if OpMode = CQOpMode then
        begin
        if OpMode2 = SearchAndPounceOpMode then
          if (not Call_Found) then
             begin
             OpMode2 := CQOpMode;
             ShowFMessages(0);
             end;
        end;
     end;

  if ExchangeWindowString <> '' then
     begin
     tCleareExchangeWindow;
     Exit; //4.90.5
     end;

  if ActiveRadioPtr^.tTwoRadioMode = TR1 then
     begin
     ActiveRadioPtr^.tTwoRadioMode := TR0;
     InActiveRadioPtr^.tTwoRadioMode := TR0;
     SwapRadios;
     if OpMode = SearchAndPounceOpMode then
       if (not Call_Found) then
          begin
          SetOpMode(CQOpMode);
          end;
     end;

  if tPreviousDupeQSOsShowed then
     begin
     ShowPreviousDupeQSOsWnd(False); //DestroyPreviousDupeQSOsWnd;
     end;

  if Call_Found = False then
     begin
     ClearMasterListBox;
     ClearAltD; // n4af 4.65.2
     tClearDupeInfoCall; //n4af 4.65.2
     end;
  if TwoRadioState = CallReady then
     begin
     TwoRadioState := Idle;
     end;

  tCallWindowSetFocus;

  if OpMode = SearchAndPounceOpMode then
    if not Call_Found then
      if (Config.EscapeExitsSearchAndPounce) then
         begin
         SetOpMode(CQOpMode);
         end;

end;

procedure SpaceBarProc2;
begin
  if (DupeInfoCall = '') and (CallWindowString = '') and (OpMode = SearchAndPounceOpMode) then // 4.102.3
    if not DEEnable then
       begin
       SendStringAndStop(MyCall)
       end
    else
       begin
       SendStringAndStop(DEPlusMyCall);
       end;

  if (DupeInfoCall <> '') and (CallWindowString = '') then
     begin
     ActiveRadioPtr^.StopSendingCW;
     inActiveRadioPtr^.StopSendingCW;

     if Config.TwoRadioMode then
        begin
        SwitchNext := False; // 4.56.1
        InActiveRadioPtr^.tTwoRadioMode := TR2;
        end
     else
        begin
        InActiveRadioPtr^.tTwoRadioMode := TR1;
        end;

     SwapRadios;
     SetOpMode(SearchAndPounceOpMode);
     PutCallToCallWindow(DupeInfoCall);
     ShowStationInformation(@DupeInfoCall);
     if Config.TwoRadioMode then
        begin
        Send_DE;
        if (length(CallWindowString) >= 3) and (ExchangeWindowString = '') then
           begin
           tExchangeWindowSetFocus;
           tSetExchWindInitExchangeEntry;
           CheckAndSetInitialExchangeCursorPos;
           end;
        end;
     ShowStationInformation(@CallWindowString);
     DisplayGridSquareStatus(CallWindowString);
     end
  else
     begin
     if (OpMode <> SearchAndPounceOpMode) and ((CallWindowString = '') or not Config.SpaceBarDupeCheckEnable) then
        begin
        if CWStillBeingSent then
           begin
           FlushCWBufferAndClearPTT; { Clear CW sent on Inactive Radio}
           end;

        SetUpToSendOnActiveRadio;

        InactiveRigCallingCQ := False;

        if MessageEnable then
           begin
           if ActiveMode = CW then
              begin
              if DEEnable then
                 begin
                 SendStringAndStop(DEPlusMyCall)
                 end
              else
                 begin
                 SendStringAndStop(MyCall);
                 end;
              end
           else if ActiveMode = Digital then
              begin
              SendStringAndStop(CallWindowString + ' DE ' + MyCall + ' KK')
              end
           else
           end;

        KeyStamp(F1);
        DisplayNextQSONumber;
        ClearContestExchange(ReceivedData);
        ExchangeHasBeenSent := False;
        SetOpMode(SearchAndPounceOpMode);

        DisplayAutoSendCharacterCount;
        EscapeDeletedCallEntry := CallWindowString;
        end
     else
        begin
        if (StartSendingNowKey = ' ') and (OpMode = CQOpMode) then
           begin
           StartSendingNow(True)
           end
        else
           begin
           WindowDupeCheck;
           end;
        tempRXData.Callsign := CallWindowString;
        if UDPBroadcaster.Enabled(usLookup) then
           begin
           LookupInfoToUDP(tempRXData);
           end;
        end;
     end;
end;

procedure SpaceBarProc;

begin

  if (DupeInfoCall <> '') and (CallWindowString = '') then
     begin

     FlushCWBufferAndClearPTT('MainUnit: DupeInfoCall set with an empty call window');

     if (TwoRadioState = CallReady) then
        begin
        CheckTwoRadioState(SpaceBarPressed)
        end
         {KK1L: 6.73 Should modify to handle Alt-D from SAP mode}
     else
        begin
        SwapRadios; { Changes band/mode and display }
        end;

     if TwoRadioState <> CallReady then
        begin
        SetOpMode(SearchAndPounceOpMode);
        ShowStationInformation(@CallWindowString);
        DisplayGridSquareStatus(CallWindowString);
        VisibleLog.DoPossibleCalls(CallWindowString);

        if (length(CallWindowString) >= 3) and (ExchangeWindowString = '') then
           begin
           tExchangeWindowSetFocus;
           tSetExchWindInitExchangeEntry;
           CheckAndSetInitialExchangeCursorPos;
           end;

        DisplayNextQSONumber;
        ClearContestExchange(ReceivedData);
        ExchangeHasBeenSent := False;

        DisplayAutoSendCharacterCount;
        end;
     end

    { Still a SpaceBar, but not doing DupeInfoCall }

  else if ((OpMode <> SearchAndPounceOpMode)                        and 
          ((CallWindowString = '') or not Config.SpaceBarDupeCheckEnable)) then
     begin

     FlushCWBufferAndClearPTT; { Clear CW sent on Inactive Radio}

     SetUpToSendOnActiveRadio;

     InactiveRigCallingCQ := False;

     if MessageEnable then
        begin
        if ActiveMode = CW then
           begin
           if DEEnable then
              begin
              SendStringAndStop(DEPlusMyCall)
              end
           else
              begin
              SendStringAndStop(MyCall);
              end;
           end
        else if ActiveMode = Digital then
           begin
           SendStringAndStop(CallWindowString + ' DE ' + MyCall + ' KK')
           end
        else
          //wli SendFunctionKeyMessage (F1, SearchAndPounceOpMode);
        end;

     KeyStamp(F1);

     // repeat
     // PutUpExchangeWindow;
     DisplayNextQSONumber;
     ClearContestExchange(ReceivedData);
     ExchangeHasBeenSent := False;
     // until not SearchAndPounce;
     SetOpMode(SearchAndPounceOpMode);
     ClearContestExchange(ReceivedData);

     // RemoveWindow(ExchangeWindow);

     DisplayAutoSendCharacterCount;

     EscapeDeletedCallEntry := CallWindowString;

     // if CallWindowString = '' then ResetSavedWindowListAndPutUpCallWindow;
     end
  else
     begin
     if WindowDupeCheck then //RemoveWindow(ExchangeWindow);
       // Windows.SetWindowTextA(ExchangeWindowHandle, '');
        begin
        SetEntryText(TR4WExchangeEdit, '');
        end;
     // RestorePreviousWindow;

     end;
end;

{ THE ENTRY FIELDS KEEP THEIR OWN COPY OF THEIR COLOURS, exactly like the list
  views RefreshMainWindowColors has to re-push into.  An LCL control paints from
  its Color and Font.Color, so a change to TWindows[] or to OpMode has to be
  handed to it; invalidating alone repaints it in the colours it already holds.

  Search-and-pounce turns the exchange field green.  That used to be an arm in
  DrawWindows keyed on wh[mweExchange]; it is one assignment here, and it is the
  same assignment the normal case makes with a different colour, so the two
  cannot drift apart the way a paint-time special case and a creation-time
  default could. }
{ EVERY ELEMENT'S COLOUR, INCLUDING THE FIVE THAT DEPEND ON LIVE STATE.

  DrawWindows evaluated those five WHILE PAINTING -- PTT status, the WSJT-X
  link, the dupe-info state and the two radios' connected flags -- which is why
  they needed no push: Windows asked on every repaint.  An LCL control paints
  from a property, so the push has to exist, and this is it.

  CALLED FROM SetMainWindowText, which is not as odd as it looks: in every one
  of the five cases the code that changes the state also writes the element's
  text (uRadioPolling writes the PTT string, uWSJTX writes 'WSJTX' or clears it,
  LOGSUBS2 writes the dupe line).  So the colour lands at the same moment it
  used to, and the one-second timer refreshes as a backstop for anything that
  changes state without saying so.

  THE WSJT-X ARM USED TO SET THE TEXT FROM INSIDE THE PAINT HANDLER.  That is
  gone -- uWSJTX already writes it (uWSJTX.pas:438), and a paint handler that
  mutates what it is painting cannot be called from a text setter without
  recursing. }
(* WriteMainWindowText IS GONE, AND SO IS THE FUNNEL IT SERVED.

  Every main-window readout used to be written through
  SetMainWindowText(mweClock, s), which routed the write, re-evaluated the five
  live colour rules and reported an off-thread caller. NY4I's done-criterion
  for this phase, recorded in Lint-Win32Dialogs, was that it stop: "the above
  SetMainWindowText will be moved to something like edLocator.Text := ..".

  ALL THREE OF ITS JOBS SURVIVE, on the control rather than in a funnel:

    the ROUTING   -- a call site now names the control it writes, so
                     SetEntryText(TR4WExchangeEdit, ...) cannot be confused
                     with a panel. That routing existed because ONE path served
                     both kinds, and its comment records what that cost: three
                     writes reaching a nil panel and returning quietly.

    the COLOURS   -- TElementPanel raises ElementCaptionChanged and uMainForm
                     answers by REQUESTING the sweep as a coalescing job, which
                     is better than the direct call this made: the element-init
                     loop now costs one sweep rather than forty-three.

    the DETECTOR  -- TElementPanel.RealSetText asks whether it is on the main
                     thread, and it sees EVERY caption assignment including a
                     direct one. That is what made removing the funnel safe,
                     and it is what NY4I asked about before agreeing to it.

  A dispatcher holding an ELEMENT rather than a control -- the init loop, the
  marshalled panel update -- calls uMainForm.SetElementText, which is a plain
  Caption write and not a second funnel. *)

function WSJTXIndicatorBack: tr4wColors;
begin
   if (WSJTXState <> nil) and WSJTXState.Connected then
      begin
      Result := trGreen;
      end
   else
      begin
      Result := trRed;
      end;
end;

procedure RefreshMainWindowElementColors;
const
   { Hoisted out of DrawWindows, which is the only place it used to be needed. }
   DupeInfoCallWindowColorArray: array[DupeInfoState] of tr4wColors =
     (trBtnFace, trRed, trYellow, trLightBlue);
var
   e: TMainWindowElement;
   back: tr4wColors;
   fore: tr4wColors;
begin
   for e := Low(TMainWindowElement) to High(TMainWindowElement) do
      begin
      if TWindows[e].mweiStyle <= 2 then
         begin
         Continue;      // not one of the elements this creates
         end;

      back := TWindows[e].mweBackG;
      fore := TWindows[e].mweColor;

      // The five live rules, in the order DrawWindows had them.
      if (e = mweDupeInfoCall) and (DupeInfoCallWindowState <> diNone) then
         begin
         back := DupeInfoCallWindowColorArray[DupeInfoCallWindowState];
         end;

      if (e = mwePTTStatus) and (ActiveRadioPtr <> nil) then
         begin
         if ActiveRadioPtr.tPTTStatus = PTT_ON then
            begin
            if ActiveRadio = RadioOne then
               begin
               back := trRed        // n4af 4.46.4
               end
            else
               begin
               back := trYellow;
               end;
            end;
         end;

      if e = mweWSJTX then
         begin
         back := WSJTXIndicatorBack;
         end;

      if ((e = mweRadioOneFreq) or (e = mweRadioOne)) and Radio1.RadioDisconnected then
         begin
         fore := AlertColor;
         end;

      if ((e = mweRadioTwoFreq) or (e = mweRadioTwo)) and Radio2.RadioDisconnected then
         begin
         fore := AlertColor;
         end;

      SetElementColors(e, tr4wColorsArray[back], tr4wColorsArray[fore]);
      end;
end;

procedure RefreshEntryFieldColors;
var
   exchBack: TColor;
begin
   SetEntryColors(TR4WCallEdit,
                  tr4wColorsArray[TWindows[mweCall].mweBackG],
                  tr4wColorsArray[TWindows[mweCall].mweColor]);

   if OpMode = SearchAndPounceOpMode then
      begin
      exchBack := tr4wColorsArray[trGreen];
      end
   else
      begin
      exchBack := tr4wColorsArray[TWindows[mweExchange].mweBackG];
      end;

   SetEntryColors(TR4WExchangeEdit,
                  exchBack,
                  tr4wColorsArray[TWindows[mweExchange].mweColor]);
end;

procedure SetOpMode(OperationMode: OpModeType);
begin

  OpMode := OperationMode;
  OpMode2 := OperationMode;
  SearchAndPounceMode := OpMode = SearchAndPounceOpMode;
  TR4WMainForm.pnlOpMode.Caption := OpModeString[OperationMode];
  if OperationMode = CQOpMode then
     begin
     EditingCallsignSent := False;
     end;
  tCallWindowSetFocus;
  DisplayAutoSendCharacterCount;
  RefreshEntryFieldColors;
  ShowFMessages(0);
  SendStationStatus(sstOpMode);
end;

procedure ReturnInCQOpMode;
begin
  if InactiveRigCallingCQ and 
     Switch               then // n4af 4.44.10
     begin
     Switch := False;
     CheckInactiveRigCallingCQ; // swapradios
     InactiveRigCallingCQ := False; // n4af 4.44.3
     if (length(CallWindowString) > 0) then
        begin
        exit; // n4af 4.44.2
        end;
     end;

  if (length(CallWindowString) = 0)     and 
     (length(ExchangeWindowString) = 0) then
     begin
     if MessageEnable then
        begin
        TryKillAutoCQ;
        SendFunctionKeyMessage(F1, CQOpMode);
        InactiveRigCallingCQ := False; // n4af 4.44.3
        end;
     Exit;
     end;

  // State-QP rover (KG1S/MON): if call has /COUNTY suffix and exchange
  // is empty, copy the county to the exchange and move focus there so
  // the operator can confirm with another Enter.
  PrefillExchangeFromRoverCallSuffix;
   
  if (length(CallWindowString) <> 0)    and 
     (length(ExchangeWindowString) = 0) and
     SwitchNext                         then // 4.52.8
     begin
     if tAutoSendMode                and 
        (AutoSendCharacterCount > 0) then
        begin
        SwitchNext := False;
        InactiveRigCallingCQ := False;
        CallAlreadySent := True;
        SwapRadios;
        end;
     end;

  if SCPMinimumLetters > 0 then
     begin
     DisplayUserInfo(CallWindowString);
     ShowName(CallWindowString);
     end;
  DisplayGridSquareStatus(CallWindowString);

  if Contest <> GENERALQSO then
     begin
     ShowStationInformation(@CallWindowString); //gav 4.44.8
     VisibleLog.DoPossibleCalls(CallWindowString);
     end;

  if AutoDupeEnableCQ        and 
     tCallWindowStringIsDupe then
     begin
     CallAlreadySent := False;
     // ShowFMessages(0);
     // FlashCallWindow;
     // EscapeDeletedCallEntry := CallWindowString;
     // if tAutoSendMode = True then CallAlreadySent := True;
     // if DupeCheckSound <> DupeCheckNoSound then DoABeep(ThreeHarmonics);
     // if tAutoSendMode = True then CallAlreadySent := True;
     // tAutoSendMode := False;
     SendB4;
     // DispalayDupe; // 4.108.6
     // tCleareCallWindow;
     end;
  if CallAlreadySent = False then
     begin
     if ActiveMode in [CW, Digital] then // WLI
        begin
        OpMode2 := SearchAndPounceOpMode;
        ShowFMessages(0);
        end;
     // CheckInactiveRigCallingCQ;
     if not tAutoSendMode then
        begin
        if MessageEnable then
           begin
           SetSpeed(DisplayedCodeSpeed); // 4.106.1
           if not SendCrypticMessage(CallWindowString) then
              begin
              Exit;
              end;
           end;
        end;
     tAutoSendMode := False;
     CallAlreadySent := True;
     ExchangeHasBeenSent := True;
     CallsignICameBackTo := CallWindowString;
     if MessageEnable then
        begin
        AddOnCQExchange;
        end;

     if QTCsEnabled then
        begin
        DisplayQTCNumber(NumberQTCsThisStation(CallWindowString));
        end;

     if (ExchangeWindowString = '') and 
        (ExchangeMemoryEnable)      then // 4.83.3
        begin
        if not Config.LeaveCursorInCallWindow then
           begin
           tExchangeWindowSetFocus;
           end;
        tSetExchWindInitExchangeEntry; // 4.83.9
        CheckAndSetInitialExchangeCursorPos;
        end;

     if not Config.LogWithSingleEnter then
        begin
        Exit;
        end;
     end;

  // IF K5KA.ModeEnabled THEN DupeCheckOnInactiveRadio;

  if ExchangeHasBeenSent = False then
    if MessageEnable and not BeSilent then
      if not (DebugFlag and (Config.CWTone = 0)) then
         begin
         // Frm.ExchangeWindow . SetFocus;
         tExchangeWindowSetFocus;
         CallsignICameBackTo := CallWindowString;
         tAutoSendMode := False;
         AddOnCQExchange;
         end;

  if ParametersOkay(CallWindowString, ExchangeWindowString, ActiveBand,
    ActiveMode, ActiveRadioPtr.LastDisplayedFreq, ReceivedData) then
     begin
     if ActiveMode = CW then
        begin

        if not Send73Message then
           begin
           Exit;
           end;
        OpMode2 := CQOpMode;
        ShowFMessages(0);

        //SendCorrectCallIfNeeded;

        end

     else
       {................phone.....................}
       if MessageEnable and 
          not BeSilent then
          begin
          if QuickQSL <> NoQuickQSLKey then
             begin
             SendCrypticMessage(QuickQSLPhoneMessage)
             end
          else
             begin
             Send73Message;
             end;
          end;
     {................phone.....................}

     if DualingCQState = DualGettingExchange then
        begin
        DualingCQState := DualSendingQSL;
        end;
     BeSilent := False;

     if not TailEnding then
        begin
        // ReceivedData.ceSearchAndPounce := False;
        TryLogContact;
        ShowStationInformation(@ReceivedData.Callsign);
        UpdateTotals2;

        //{WLI}

        EscapeDeletedCallEntry := CallWindowString;
        tCleareCallWindow;
        tCleareExchangeWindow;
        tCallWindowSetFocus;
        // sendmessage(CallWindowHandle,wm_setfocus,0,0);
        // CallWindow . SetFocus;
        if OnDeckCall <> '' then // 4.102.4
           begin
           PutCallToCallWindow(OnDeckCall);
           end;
        Exit;
        end;
     end;
end;

procedure ReturnInSAPOpMode;
label
  loop;
var
  n: integer;
 // TempString: Str10;
begin
  n := 0;
  DebugMsg('>>>>Entering ReturnInSAPOpMode');
  ExchangeHasBeenSent := False;
  Exchw := ExchangeWindowString;
  Callw := CallWindowString;
  ParseFourFields(ExchangeWindowString, s1, s2, s3, s4);
  loop:
  if (ExchangeWindowString = '') and (CallWindowString = '') then
    if Config.AutoReturnToCQMode then
       begin
       //     tClearDupeInfoCall; // 4.126.1
       //     clearAltD;         //4.126.1
       NameCallsignPutUp := '';
       CleanUpDisplay;
       if ActiveRadioPtr^.tTwoRadioMode = TR1 then
          begin
          ActiveRadioPtr^.tTwoRadioMode := TR0;
          InActiveRadioPtr^.tTwoRadioMode := TR0;
          SwapRadios;
          end;

       SetOpMode(CQOpMode);
       if MessageEnable then
          begin
          SendFunctionKeyMessage(F1, OpMode);
          end;
       Exit;
       end;

  // State-QP rover (KG1S/MON): if call has /COUNTY suffix and exchange
  // is empty, copy the county to the exchange and move focus there so
  // the operator can confirm with another Enter.
  PrefillExchangeFromRoverCallSuffix;

  // if tr4w_CallWindowActive then
  if (length(CallWindowString) >= 3) then
     begin
     tCreateAndAddNewSpot(CallWindowString, tCallWindowStringIsDupe,
       ActiveRadioPtr);
     if not AutoDupeEnableSandP then // n4af 4.49.5
        begin
        tExchangeWindowSetFocus; // n4af issue155 4.47.12
        end;
     end;
  if (ExchangeWindowString = '') then
    if (length(CallWindowString) >= 3) and
      ((not tCallWindowStringIsDupe) or
      (not AutoDupeEnableSandP)) then

       begin
       // ExchangeHasBeenSent := False;
       if IsAGoodCall(CallWindowString) then
          begin
          if not Send_DE then
             begin
             Exit;
             end;
          tExchangeWindowSetFocus;
          end;
       end;

  if QTCsEnabled then
     begin
     DisplayQTCNumber(NumberQTCsThisStation(CallWindowString));
     end;

  if tCallWindowStringIsDupe and {not }AutoDupeEnableSandP then
     begin
     DispalayDupe;
     // if WindowDupeCheck then
     Exit;
     end;

  DisplayGridSquareStatus(CallWindowString);
  ShowStationInformation(@CallWindowString);

  if (ExchangeWindowString = '') {and (ExchangeMemoryEnable)} then // 4.84.1
     begin
     if ExchangeMemoryEnable then
        begin
        tSetExchWindInitExchangeEntry;
        end;
     CheckAndSetInitialExchangeCursorPos;
     Exit;
     end;

  VisibleLog.DoPossibleCalls(CallWindowString);
  // DDX(MaybeRespondToMyCall);

 // if TwoRadioState = StationCalled then CheckTwoRadioState(ReturnPressed)
 // else
  if MessageEnable and (not ExchangeHasBeenSent) and (not BeSilent) and
    MessageEnable then

     begin
     // Multi-county exchanges (e.g. "DAL/BAY", "DAL BAY") are handled at the
     // parser level: ProcessRSTAndDomesticQTHExchange splits and queues the
     // extras, and the drain loop in TryLogContact logs the additional QSOs
     // immediately.  No pre-split is needed here -- Issue #885.

     if ActiveMode in [CW, Digital] then

       if not SendCrypticMessage(SearchAndPounceExchange) then
          begin
          Exit;
          end;

     if ActiveMode in [Phone, FM] then
        begin
        SendCrypticMessage(SearchAndPouncePhoneExchange);
        end;

     ExchangeHasBeenSent := True;

     //if activeradioptr^.cwbycat then backtoinactiveradioafterqso; // ny4i Issue130 Moving this to after LogContact
     {TODO } // Uncomment above and comment below to check for CWBC_AutoSend ny4i 9-mar-2016
     //if activeradioptr^.cwbycat then backtoinactiveradioafterqso; // ny4i Issue153 commented out

     end;

  if TryLogContact then
     begin
     if ActiveRadioPtr^.tTwoRadioMode = TR2 then
        begin
        ActiveRadioPtr^.tTwoRadioMode := TR3;
        end;
     // TwoRadioState := SendingExchange;
     if ReceivedData.DomesticMult or ReceivedData.DXMult or ReceivedData.ZoneMult
       then
        begin
        VisibleLog.ShowRemainingMultipliers;
        end;
     if ReceivedData.DomesticMult then
        begin
        VisibleLog.DisplayGridMap(ActiveBand, ActiveMode);
        end;
     if SprintQSYRule then
        begin
        QuickDisplay(TC_SPRINTQSYRULE);
        if OpMode = SearchAndPounceOpMode then
           begin
           SetOpMode(CQOpMode);
           end;
        end;
     end;
  if (ActiveExchange = RSTDomesticQTHExchange) or (ActiveExchange =
    RSTQTHEXCHANGE) then
     begin
     if (IsAlpha(S2)) and (S2 <> '') then
        begin

        CallWindowString := callw;
        // S3 := '';
        exchangewindowstring := s1;
        BeSilent := True;
     //   S2 := '';
        goto loop;
        end;
     end;
end;

function Send_DE: boolean;
begin
  Result := True;
  if ActiveMode = CW then
     begin
     // SetSpeed(DisplayedCodeSpeed);
     // InactiveRigCallingCQ := False;
     if MessageEnable and not BeSilent then
        begin
        if DEEnable then
           begin
           Result := SendCrypticMessage(DEPlusMyCall)
           end
        else
           begin
           Result := SendCrypticMessage(MyCall);
           end;
        // DebugMsg('<<<<SendCrypticMessage(MyCall)');
        KeyStamp(F1);
        end;
     Exit;
     end;

  if ActiveMode = Digital then
     begin
     SendCrypticMessage(#13#10 + CallWindowString + ' DE ' + MyCall + ' ' +
       MyCall)
     end

  else
     begin
     if Config.DVKEnable and MessageEnable and not BeSilent then
        begin
        SendFunctionKeyMessage(F1, SearchAndPounceOpMode);
        end;
     // if (ActiveDVKPort <> NoPort) and not BeSilent then
     {KK1L: 6.73 Added mode to GetExMemoryString}
     //{WLI} (GetEXMemoryString (ActiveMode, F1));
     end;

end;

procedure SendB4;
var
  QTC: integer;
begin
  if AutoDisplayDupeQSO then
     begin
     ShowPreviousDupeQSOs(CallWindowString, ActiveBand, ActiveMode);
     // EditableLogDisplayed := True;
     end;

  if ActiveMode in [CW, Digital] then //wli issue 276
     begin
     if QTCsEnabled then
        begin
        QTC := NumberQTCsThisStation(StandardCallFormat(CallWindowString, False));
        DisplayQTCNumber(QTC);
        if QTC < 10 then
           begin
           if QTCsEnabled and (MyContinent = Europe) then
              begin
              AddStringToBuffer(' B4 ', Config.CWTone);
              // WAEQTC (CallWindowString);
              end
           else if MessageEnable and not BeSilent then
              begin
              SendCrypticMessage(CallWindowString + ' ' + QSOBeforeMessage);
              end;
           end;
        // else
        // if MessageEnable and not BeSilent then
        // SendCrypticMessage(CallWindowString + ' ' + QSOBeforeMessage);

        end
     else if MessageEnable and not BeSilent then
       { if CallAlreadySent = False then
      SendCrypticMessage(CallWindowString + ' ' + QSOBeforeMessage)
      else
      SendCrypticMessage(QSOBeforeMessage); }
       if DualingCQState <> NoDualingCQs then
          begin
          DualingCQState := SendingDupeMessage;
          end;
     end;

  if ActiveMode = Phone then
     begin
     //wli
     SendCrypticMessage(QSOBeforePhoneMessage);

     // Write (' DUPE!!');
     EscapeDeletedCallEntry := CallWindowString;

     if QTCsEnabled then
        begin
        DisplayQTCNumber(NumberQTCsThisStation(StandardCallFormat(CallWindowString, False)))
        end
     end;

  CallAlreadySent := False;
  SeventyThreeMessageSent := False;
  // DispalayB4(SW_HIDE);
  // Windows.ShowWindow(B4StatusWindowHandle, SW_HIDE);

  // tCleareCallWindow

end;

// Where every window was left, into the 'windows' section of settings/tr4w.json.
//
// THE NAME IS NOW HISTORICAL.  It is kept because ExitProgram in
// logsubs2.pas calls it and renaming a routine across the trdos boundary buys
// nothing; the file it used to write is described in uWindowLayoutStore.
//
// It used to be `sWriteFile(h, tr4w_WindowsArray, SizeOf(tr4w_WindowsArray))` --
// a raw dump of the array, HWNDs and WndProcAdr pointers included. See
// uWindowLayoutStore for the three ways that silently reset an operator's
// layout, of which "someone builds this 64-bit" is the one now on the roadmap.
procedure SaveTR4WPOSFILE;
var
  store: TWindowLayoutStore;
  i: WindowsType;
begin
  FindAndSaveRectOfAllWindows;

  store := TWindowLayoutStore.Create;
  try
     // The SAME range FindAndSaveRectOfAllWindows fills, deliberately. Beyond
     // tw_HAMSCOREWINDOW_INDEX is only tw_Dummy11, which is not a window and
     // whose rect is therefore whatever the array was initialised with --
     // writing it would put a permanent entry for a non-existent window in the
     // operator's settings file.
     for i := tw_MAINWINDOW_INDEX to tw_HAMSCOREWINDOW_INDEX do
        begin
        store.SetLayout(WindowNames[i],
                        tr4w_WindowsArray[i].WndRect,
                        tr4w_WindowsArray[i].WndVisible);
        end;

     SaveWindowLayout(TR4WConfigFileName, store);
  finally
     store.Free;
  end;

  // The panadapters are NOT tw_ windows -- they have no entry in
  // tr4w_WindowsArray, so the loop above cannot see them.  Riding this call
  // gives them the 5-second autosave AND the save-at-exit backstop without a
  // second mechanism writing the same file.
  SavePanadapterLayout;

  (* AND THE SEARCH WINDOW, for the same reason and by the same route: it is
    not a tw_ window either, so the loop above cannot see it. *)
  SaveLogSearchLayout;
  SaveLogEditLayout;
end;

// Issue #739: a saved window rectangle can land off-screen when the monitor it
// was saved on is no longer present (laptop undocked, external display removed,
// resolution lowered).  TR4W restores saved rects verbatim, so such a window
// comes back unreachable.  Validate a rect against the CURRENT monitor layout
// and, if it is not meaningfully visible, clamp/recenter it onto the nearest
// monitor's work area (taskbar excluded).  Plain USER32 multi-monitor API --
// Delphi 7 / Win32 safe, no VCL.  The multi-monitor API is imported directly
// from user32 because this project's Windows unit does not surface it.
const
  TR4W_MONITOR_DEFAULTTONEAREST = $00000002;

type
  TTR4WMonitorInfo = record
    cbSize: DWORD;
    rcMonitor: TRect;
    rcWork: TRect;
    dwFlags: DWORD;
  end;

function tr4wMonitorFromRect(lprc: PRect; dwFlags: DWORD): Cardinal; stdcall;
  external 'user32.dll' name 'MonitorFromRect';
function tr4wGetMonitorInfo(hMonitor: Cardinal;
  var lpmi: TTR4WMonitorInfo): BOOL; stdcall;
  external 'user32.dll' name 'GetMonitorInfoA';

type
  TRelocInfo = record
    Relocated: boolean;   // moved at startup because its saved monitor was absent
    OrigRect: TRect;      // original saved rect (restore if the display returns)
  end;

var
  RelocState: array[WindowsType] of TRelocInfo;

{ Are these the same window placement -- POSITION AND SIZE?

  It compared Left and Top ONLY and was called PositionsMatch, so a window the
  operator had RESIZED but not moved read as untouched.  Both callers are really
  asking "has the operator touched this since we relocated it", and resizing it
  is touching it; the autosave below asks the same question and needs the size
  to count.

  The tolerance stays, and now applies to the size too: a placement that lands a
  pixel or two out is the same placement, not a change worth writing to disk. }
function BoundsMatch(const A, B: TRect): boolean;
const
  TOL = 5;  // px; SetBounds lands exactly -- allow a little slack
begin
  Result := (Abs(A.Left   - B.Left)   <= TOL) and
            (Abs(A.Top    - B.Top)    <= TOL) and
            (Abs(A.Right  - B.Right)  <= TOL) and
            (Abs(A.Bottom - B.Bottom) <= TOL);
end;

{ THE WINDOW LAYOUT AUTOSAVE.

  NY4I: "you do want to save on moving the window or resizing in case the
  program crashed but the save at the end can be an extra check."  Nothing
  reached disk until ExitProgram, so a crash -- or a power cut mid-contest --
  lost every move and resize made since start-up.

  POLLED, NOT EVENT-DRIVEN, and that was the choice:

    * No per-form wiring, so nothing is missed when the next window converts and
      there is nothing to remember to add.
    * It covers the windows that are STILL WIN32 DIALOGS, which an OnChangeBounds
      hook could not.
    * It cannot miss a change.  A move made by the WINDOW MANAGER -- a snap, a
      monitor going away, a DPI change -- may raise no event at all.

  The cost is one rectangle comparison per window every few seconds, and it
  WRITES ONLY WHEN SOMETHING ACTUALLY MOVED: a station whose windows are sitting
  still writes nothing at all.

  The exit save stays as the backstop NY4I asked for. }
const
   LAYOUT_AUTOSAVE_MS = 5000;

{ Defined below, beside the window table it walks. }
procedure RestoreToolWindows; forward;

type
   TLayoutAutosave = class
      procedure Tick(Sender: TObject);
   end;

   { Exists only to give QueueAsyncCall a method to call.  Queue is a method so
     the @ resolves against Self -- taking a method pointer off a variable at
     the call site does not parse. }
   TDeferredWindowRestore = class
      procedure Queue;
      procedure Run(Data: PtrInt);
   end;

var
   GLayoutTimer: TTimer = nil;
   GLayoutAutosave: TLayoutAutosave = nil;
   GDeferredRestore: TDeferredWindowRestore = nil;
   { What is believed to be ON DISK.  Compared against the live rects; without
     it this would rewrite the file every tick. }
   GSavedLayout: array[WindowsType] of TRect;

procedure TDeferredWindowRestore.Queue;
begin
   { NO @ -- this unit compiles in Delphi mode, where a bare method name in
     a procedural-type context IS the method pointer.  ObjFPC's @Run does
     not parse here.  (And a brace comment cannot spell the mode directive
     out: Pascal comments do not nest, so it would end the comment and the
     rest would compile as code.) }
   Application.QueueAsyncCall(Self.Run, 0);
end;

procedure TDeferredWindowRestore.Run(Data: PtrInt);
begin
   RestoreToolWindows;
end;

{ Show the main window first and let the loop restore the rest -- see
  OpenOtherWindows. }
procedure QueueToolWindowRestore;
begin
   if GDeferredRestore = nil then
      begin
      GDeferredRestore := TDeferredWindowRestore.Create;
      end;
   GDeferredRestore.Queue;
end;

procedure SnapshotSavedLayout;
var
   i: WindowsType;
begin
   for i := Low(WindowsType) to High(WindowsType) do
      begin
      GSavedLayout[i] := tr4w_WindowsArray[i].WndRect;
      end;
end;

procedure TLayoutAutosave.Tick(Sender: TObject);
var
   i: WindowsType;
   changed: boolean;
begin
   FindAndSaveRectOfAllWindows;

   changed := False;
   for i := Low(WindowsType) to High(WindowsType) do
      begin
      if not BoundsMatch(tr4w_WindowsArray[i].WndRect, GSavedLayout[i]) then
         begin
         changed := True;
         { NAME THE WINDOW, not just the fact.  This fired every tick on its
           first outing -- a closed form reporting hidden bounds -- and "a
           window moved" could not say which, so the cause had to be guessed
           at.  A feature that writes to disk on a timer should be able to
           justify every write it makes. }
         if logger.IsTraceEnabled then
            begin
            logger.Trace('[Layout] %s moved or resized: (%d,%d,%d,%d) -> (%d,%d,%d,%d) -- saving',
                         [WindowNames[i],
                          GSavedLayout[i].Left, GSavedLayout[i].Top,
                          GSavedLayout[i].Right, GSavedLayout[i].Bottom,
                          tr4w_WindowsArray[i].WndRect.Left, tr4w_WindowsArray[i].WndRect.Top,
                          tr4w_WindowsArray[i].WndRect.Right, tr4w_WindowsArray[i].WndRect.Bottom]);
            end;
         Break;
         end;
      end;

   { The panadapter answers for itself -- see SavePanadapterLayout.  Asked
     AFTER the tw_ loop so that loop's Break-on-first-change logging is
     unaffected. }
   if (not changed) and PanadapterLayoutChanged then
      begin
      changed := True;
      if logger.IsTraceEnabled then
         begin
         logger.Trace('[Layout] a panadapter moved, resized or changed open state -- saving');
         end;
      end;

   if not changed then
      begin
      Exit;
      end;

   SaveTR4WPOSFILE;
   SnapshotSavedLayout;
end;

{ Called once the layout has been LOADED and the windows placed, so the first
  tick does not report the load itself as a change and rewrite the file. }
procedure StartLayoutAutosave;
begin
   if GLayoutTimer <> nil then
      begin
      Exit;
      end;

   SnapshotSavedLayout;

   GLayoutAutosave := TLayoutAutosave.Create;
   GLayoutTimer := TTimer.Create(nil);
   GLayoutTimer.Interval := LAYOUT_AUTOSAVE_MS;
   GLayoutTimer.OnTimer := GLayoutAutosave.Tick;
   GLayoutTimer.Enabled := True;
end;

procedure StopLayoutAutosave;
begin
   if GLayoutTimer <> nil then
      begin
      GLayoutTimer.Enabled := False;
      end;
   FreeAndNil(GLayoutTimer);
   FreeAndNil(GLayoutAutosave);

   { The deferred window restore lives on the same start-up-to-shutdown scale.
     REMOVE THE QUEUED CALL FIRST: a program that exits before the loop ever
     idles would otherwise leave the LCL holding a method pointer into a freed
     object. }
   if GDeferredRestore <> nil then
      begin
      Application.RemoveAsyncCalls(GDeferredRestore);
      FreeAndNil(GDeferredRestore);
      end;
end;


/// <summary>True if R is meaningfully visible on the nearest monitor's work area.</summary>
function RectIsOnScreen(const R: TRect): boolean;
const
   MIN_VISIBLE_W = 100;
   MIN_VISIBLE_H = 60;
var
   Mon: Cardinal;
   MI: TTR4WMonitorInfo;
   Inter: TRect;
begin
   if (R.Right - R.Left <= 0) or
      (R.Bottom - R.Top <= 0) then
      begin
      Result := False;
      Exit;
      end;
   Mon := tr4wMonitorFromRect(@R, TR4W_MONITOR_DEFAULTTONEAREST);
   MI.cbSize := SizeOf(MI);
   if not tr4wGetMonitorInfo(Mon, MI) then
      begin
      Result := True;   // can't validate -> treat as on-screen and leave it alone
      Exit;
      end;
   { ENOUGH OF IT VISIBLE TO GRAB -- OR ALL OF IT, IF IT IS SMALLER THAN THAT.

     The bare thresholds asked "are at least 100x60 pixels showing", which fails
     any window that is legitimately SMALLER than 100x60 however completely it
     is on screen.  The function-key bar is about forty pixels tall, so a
     correctly saved rect was judged off-screen and relocated to the corner --
     NY4I: "still opened in upper left", every restart (2026-08-26).

     The question is VISIBILITY, not size: a 780x38 window with all 780x38 on
     the work area is fully visible and must be left alone. }
   Result := IntersectRect(Inter, R, MI.rcWork) and
             ((Inter.Right - Inter.Left) >=
                Min(MIN_VISIBLE_W, R.Right - R.Left)) and
             ((Inter.Bottom - Inter.Top) >=
                Min(MIN_VISIBLE_H, R.Bottom - R.Top));
end;

/// <summary>
/// Validate one saved window against the CURRENT monitor layout.
/// </summary>
/// <remarks>
/// If it is not meaningfully visible (its saved monitor is gone), clamp it
/// onto the nearest monitor's work area, cascaded by CascadeIndex so
/// several recovered windows fan out instead of stacking.
/// Records the move in RelocState so SaveTR4WPOSFILE can
/// keep the ORIGINAL rect (restoring the multi-monitor layout when the display
/// returns) unless the user moves the window this session.
/// </remarks>
/// <param name="Idx"> (WindowsType) Index into tr4w_WindowsArray</param>
/// <param name="CascadeIndex"> (integer) returns next  tr4w_WindowsArray to access</param>

procedure EnsureRectOnScreen(Idx: WindowsType; var CascadeIndex: integer);
const
   EDGE_MARGIN = 40;
   CASCADE_STEP = 26;
var
   R: TRect;
   Mon: Cardinal;
   MI: TTR4WMonitorInfo;
   W : integer;
   H : integer;
   ofs: integer;
begin
   RelocState[Idx].Relocated := False;
   R := tr4w_WindowsArray[Idx].WndRect;
   W := R.Right - R.Left;
   H := R.Bottom - R.Top;
   // Skip unset / never-saved entries (no real size); the default logic owns those.
   if (W <= 0) or
      (H <= 0) then
      begin
      Exit;
      end;

   // Nearest monitor -- works even when the rect is entirely off-screen.
   Mon := tr4wMonitorFromRect(@R, TR4W_MONITOR_DEFAULTTONEAREST);
   MI.cbSize := SizeOf(MI);
   if not tr4wGetMonitorInfo(Mon, MI) then
      begin
      if logger.IsTraceEnabled then
         begin
         logger.Trace('[EnsureRect] %s (idx=%d) GetMonitorInfo FAILED -> keep saved',
                      [WindowNames[Idx], Ord(Idx)]);
         end;
      Exit;  // Can't validate -- leave the saved rect untouched.
      end;

   if logger.IsTraceEnabled then
      begin
      logger.Trace('[EnsureRect] %s (idx=%d) rect=(%d,%d,%d,%d) rcWork=(%d,%d,%d,%d)',
                   [ WindowNames[Idx]
                    ,Ord(Idx)
                    ,R.Left
                    ,R.Top
                    ,R.Right
                    ,R.Bottom
                    ,MI.rcWork.Left
                    ,MI.rcWork.Top
                    ,MI.rcWork.Right
                    ,MI.rcWork.Bottom
                   ]);
      end;

   // Visible enough if it overlaps the work area by at least a usable margin.
   if RectIsOnScreen(R) then
      begin
      if logger.IsTraceEnabled then
         begin
         logger.Trace('[EnsureRect] %s (idx=%d) KEPT (visible on this monitor)',
                      [ WindowNames[Idx]
                      ,Ord(Idx)
                      ]);
         end;
      Exit;
      end;

   // Not visible: remember the original (R is still pristine here), then clamp the
   // size to the work area and move fully inside it with a per-window cascade offset.
   RelocState[Idx].OrigRect := R;
   if W > (MI.rcWork.Right - MI.rcWork.Left) then
      begin
      W := MI.rcWork.Right - MI.rcWork.Left;
      end;
   if H > (MI.rcWork.Bottom - MI.rcWork.Top) then
      begin
      H := MI.rcWork.Bottom - MI.rcWork.Top;
      end;

   ofs := CascadeIndex * CASCADE_STEP;
   R.Left := MI.rcWork.Left + EDGE_MARGIN + ofs;
   R.Top := MI.rcWork.Top + EDGE_MARGIN + ofs;
   // Keep it fully on the work area (also pulls the cascade tail back from edges).
   if R.Left + W > MI.rcWork.Right then
      begin
      R.Left := MI.rcWork.Right - W;
      end;
   if R.Top + H > MI.rcWork.Bottom then
      begin
      R.Top := MI.rcWork.Bottom - H;
      end;
   if R.Left < MI.rcWork.Left then
      begin
      R.Left := MI.rcWork.Left;
      end;
   if R.Top < MI.rcWork.Top then
      begin
      R.Top := MI.rcWork.Top;
      end;
   R.Right := R.Left + W;
   R.Bottom := R.Top + H;

   tr4w_WindowsArray[Idx].WndRect := R;
   RelocState[Idx].Relocated := True;
   if logger.IsInfoEnabled then
      begin
      logger.Info('[EnsureRect] %s (idx=%d) RELOCATED to (%d,%d,%d,%d)',
                   [ WindowNames[Idx]
                   ,Ord(Idx)
                   ,R.Left
                   ,R.Top
                   ,R.Right
                   ,R.Bottom
                   ]);
      end;
   Inc(CascadeIndex);

end;

{ Defined below, next to the rest of the window-opening code; the rescue path
  above it is the one caller that needs it early. }
function LclFormFor(const ID: WindowsType): TCustomForm; forward;

(* MOVE THE FORM, NOT THE WINDOW.

   Every tool window is an LCL form, and a form keeps its own idea of where it
   is.  SetWindowPos moves the native window without telling it, so Left/Top go
   stale -- and the next time anything makes the LCL push its bounds down, the
   window jumps back.  That is exactly how the band map lost NY4I's saved
   position (2026-08-25), and the rule in CLAUDE.md came out of it: position a
   form through its properties.

   THE HWND FALLBACK IS GONE, PROVED RATHER THAN ASSUMED. It was a
   SetWindowPos on tr4w_WindowsArray[aID].WndHandle when LclFormFor returned
   nil. The caller only reaches here for a window whose handle is non-zero and
   passes IsWindow -- and a tw_ window HAS a handle only because
   OpenTR4WWindow built its form, which is the object LclFormFor returns. So
   nil form and live handle cannot both be true, and the fallback could only
   ever have run with nothing to move. *)
procedure MoveWindowTo(const aID: WindowsType; const aLeft, aTop: integer);
var
   frm: TCustomForm;
begin
   frm := LclFormFor(aID);
   if (frm <> nil) and frm.HandleAllocated then
      begin
      frm.SetBounds(aLeft, aTop, frm.Width, frm.Height);
      Exit;
      end;

   if logger <> nil then
      begin
      logger.Warn('[Revalidate] %s has a window but no LCL form object -- not '
                  + 'moved. This should be unreachable.', [WindowNames[aID]]);
      end;
end;

/// <summary>
/// Re-validate OPEN window positions after a live display-topology change
/// (monitor added/removed, resolution change).  Symmetric:
///   * a window whose monitor vanished is moved onto an active monitor;
///   * a previously-rescued, untouched window whose ORIGINAL monitor has
///     returned is sent back home;
///   * if the user moved a rescued window meanwhile, its new spot is adopted.
/// Every move uses SWP_NOACTIVATE | SWP_NOZORDER so focus and z-order are never
/// disturbed during a contest.  Minimized windows are left alone.
/// </summary>
procedure RevalidateOpenWindowsOnScreen;
var
   i: WindowsType;
   CascadeIndex: integer;
   frm: TCustomForm;
   live: TRect;
begin
   CascadeIndex := 0;
   for i := tw_MAINWINDOW_INDEX to tw_HAMSCOREWINDOW_INDEX do
      begin
      (* WAS h = 0 / IsWindow(h) / IsIconic(h) -- three Win32 questions about
        an object we hold. A nil entry is a closed window (IsWindow's job, and
        the zero test's), and WindowState is what IsIconic was asking. *)
      frm := tr4w_WindowsArray[i].WndForm;
      if (frm = nil) or (not frm.HandleAllocated) or
         (frm.WindowState = wsMinimized) then
         begin
         Continue;
         end;
      live := frm.BoundsRect;

      if RelocState[i].Relocated then
         begin
         // Rescued on an earlier change and still flagged relocated.
         if not BoundsMatch(live, tr4w_WindowsArray[i].WndRect) then
            begin
            // The user moved it since the rescue -> adopt the new spot.
            RelocState[i].Relocated := False;
            tr4w_WindowsArray[i].WndRect := live;
            end
         else if RectIsOnScreen(RelocState[i].OrigRect) then
            begin
            // Untouched, and its original monitor is back -> send it home.
            tr4w_WindowsArray[i].WndRect := RelocState[i].OrigRect;
            MoveWindowTo(i, RelocState[i].OrigRect.Left,
                            RelocState[i].OrigRect.Top);
            RelocState[i].Relocated := False;
            if logger.IsInfoEnabled then
               begin
               logger.Info('[Revalidate] %s (idx=%d) RESTORED to original (%d,%d)',
                           [ WindowNames[i]
                           ,Ord(i)
                           ,RelocState[i].OrigRect.Left
                           ,RelocState[i].OrigRect.Top
                           ]);
               end;
            end;
         // else: still off-screen and untouched -> leave it rescued (OrigRect kept).
         end
      else
         begin
         // Not currently relocated: rescue it if this change pushed it off-screen.
         tr4w_WindowsArray[i].WndRect := live;
         EnsureRectOnScreen(i, CascadeIndex);
         if RelocState[i].Relocated then
            begin
            MoveWindowTo(i, tr4w_WindowsArray[i].WndRect.Left,
                            tr4w_WindowsArray[i].WndRect.Top);
            end;
         end;
      end;
end;

// The saved layout from the 'windows' section of settings/tr4w.json, into
// tr4w_WindowsArray.  False when there is no such section, which is every
// settings folder written before this format existed.
//
// A window the file does not MENTION is left exactly as the array already held
// it -- TryGetLayout does not touch its arguments on a miss -- so the default
// rects computed further down still apply to it.  That matters: a zero rect is
// how LoadTR4WPOSFILE decides a window has never been placed, so a miss must
// not be reported as (0,0,0,0).
function LoadWindowLayoutFromJSON: boolean;
var
   store: TWindowLayoutStore;
   i: WindowsType;
   r: TRect;
   visible: boolean;
begin
   store := TWindowLayoutStore.Create;
   try
      Result := LoadWindowLayout(TR4WConfigFileName, store);
      if not Result then
         begin
         Exit;
         end;

      for i := tw_MAINWINDOW_INDEX to tw_HAMSCOREWINDOW_INDEX do
         begin
         r       := tr4w_WindowsArray[i].WndRect;
         visible := tr4w_WindowsArray[i].WndVisible;
         if store.TryGetLayout(WindowNames[i], r, visible) then
            begin
            tr4w_WindowsArray[i].WndRect    := r;
            tr4w_WindowsArray[i].WndVisible := visible;
            end;
         end;
   finally
      store.Free;
   end;
end;

// ONE-TIME SEED from the binary settings/tr4w.pos, so an operator upgrading
// does not lose the layout they have.  Read EXACTLY as the old loader read it,
// same size check and same whole-array read, because the job is to reproduce
// that result rather than to improve on it.
//
// THE FILE IS READ AND LEFT IN PLACE.  Deleting it would be a destructive step
// on the operator's data with nothing to undo it, and leaving it means an older
// TR4W still finds its layout.  It simply stops being read once tr4w.json has a
// 'windows' section -- which the very next exit writes.
//
// This does read HWND and WndProcAdr bytes off disk into the array, as it
// always did; the loader below zeroes the handles and reassigns every window
// procedure from literals a few lines further on.
//
// TFileStream, NOT CreateFile/GetFileSize/ReadFile (2026-09-08, NY4I).  This
// routine POST-DATES the move to JSON, so it never had a reason to be written
// against the Win32 file API -- the RTL was already the house style when it was
// written.  Nothing about reading a fixed-size record needs a Windows handle.
//
// THE SEMANTICS ARE DELIBERATELY UNCHANGED where they were load-bearing: the
// same exact-size gate, the same single whole-array read, the file left in
// place.  The job is still to reproduce the old loader's result.
//
// TWO THINGS THAT ARE BETTER, AND BOTH WERE SILENT BEFORE.  ReadFile's byte
// count went into pNumberOfBytesRead and was never looked at, so a file that
// passed the size check and then delivered fewer bytes -- truncated, or being
// rewritten by another instance -- left the layout array PARTLY overwritten
// with whatever the read managed, and nothing said so.  ReadBuffer raises on a
// short read instead.  And every failure path returned in silence, which for a
// once-per-upgrade migration means an operator loses their window layout with
// nothing to explain it; it is reported now.
procedure SeedLayoutFromLegacyPOSFile;
var
   fs: TFileStream;
   (* AnsiString, not string. TR4W_POS_FILENAME is a FileNameType -- an array
     of AnsiChar -- and TFileStream, FileExists and the rest of the RTL file
     layer take an AnsiString. Declaring this as the UTF-16 string would
     widen the bytes on the way in and narrow them back on the way out, for
     nothing. *)
   posPath: AnsiString;
begin
   posPath := StrPas(TR4W_POS_FILENAME);

   // Not an error and not worth a log line: the overwhelming majority of
   // startups are an operator who never had a .pos file, or whose layout has
   // already been seeded and now lives in tr4w.json.
   if not FileExists(posPath) then
      begin
      Exit;
      end;

   try
      fs := TFileStream.Create(posPath, fmOpenRead or fmShareDenyNone);
      try
         // EXACT size, as before.  A .pos from a build whose window array had
         // a different member count is not partially usable -- the records
         // would land at the wrong offsets -- so refusing it is right.
         if fs.Size <> SizeOf(tr4w_WindowsArray) then
            begin
            if logger <> nil then
               begin
               logger.Warn('[Layout] %s is %d bytes, expected %d -- not seeding ' +
                           'the window layout from it',
                           [posPath, fs.Size, SizeOf(tr4w_WindowsArray)]);
               end;
            Exit;
            end;

         fs.ReadBuffer(tr4w_WindowsArray, SizeOf(tr4w_WindowsArray));
      finally
         fs.Free;
      end;
   except
      on E: EStreamError do
         begin
         if logger <> nil then
            begin
            logger.Warn('[Layout] could not read %s -- %s: %s. The window ' +
                        'layout stays at its defaults.',
                        [posPath, E.ClassName, E.Message]);
            end;
         end;
   end;
end;

procedure LoadTR4WPOSFILE;
var
  i: WindowsType;
  Left: integer;
  CascadeIndex: integer;
begin

{$IF MAKE_DEFAULT_VALUES = true}
  Exit;
{$IFEND}
  if not LoadWindowLayoutFromJSON then
     begin
     SeedLayoutFromLegacyPOSFile;
     end;
  for i := tw_BANDMAPWINDOW_INDEX to tw_HAMSCOREWINDOW_INDEX do
    if tr4w_WindowsArray[i].WndRect.Right = 0 then
       begin
       tr4w_WindowsArray[i].WndRect.Top := 400;
       tr4w_WindowsArray[i].WndRect.Left := Ord(i) * 30;
       tr4w_WindowsArray[i].WndRect.Right := Ord(i) * 30 + 220;
       tr4w_WindowsArray[i].WndRect.Bottom := 600;
       end;
  // Issue #783 Phase 4: give the HamScore status window enough room for
  // the URL line and the multi-line status edit.  Default 220 x N is too
  // narrow / short.  Min: 410 wide x 270 tall.
  if tr4w_WindowsArray[tw_HAMSCOREWINDOW_INDEX].WndRect.Right -
     tr4w_WindowsArray[tw_HAMSCOREWINDOW_INDEX].WndRect.Left < 410 then
     begin
     tr4w_WindowsArray[tw_HAMSCOREWINDOW_INDEX].WndRect.Right :=
       tr4w_WindowsArray[tw_HAMSCOREWINDOW_INDEX].WndRect.Left + 410;
     end;
  if tr4w_WindowsArray[tw_HAMSCOREWINDOW_INDEX].WndRect.Bottom -
     tr4w_WindowsArray[tw_HAMSCOREWINDOW_INDEX].WndRect.Top < 270 then
     begin
     tr4w_WindowsArray[tw_HAMSCOREWINDOW_INDEX].WndRect.Bottom :=
       tr4w_WindowsArray[tw_HAMSCOREWINDOW_INDEX].WndRect.Top + 270;
     end;

  if tr4w_WindowsArray[tw_MAINWINDOW_INDEX].WndRect.Right = 0 then
     begin
     Left := (GetSystemMetrics(SM_CXSCREEN) - 46 * 17) div 2;
     tr4w_WindowsArray[tw_MAINWINDOW_INDEX].WndRect.Top := 100;
     tr4w_WindowsArray[tw_MAINWINDOW_INDEX].WndRect.Left := Left;

     tr4w_WindowsArray[tw_FUNCTIONKEYSWINDOW_INDEX].WndVisible := True;
     tr4w_WindowsArray[tw_FUNCTIONKEYSWINDOW_INDEX].WndRect.Top := 24 * 17 + 100;
     tr4w_WindowsArray[tw_FUNCTIONKEYSWINDOW_INDEX].WndRect.Left := Left;
     tr4w_WindowsArray[tw_FUNCTIONKEYSWINDOW_INDEX].WndRect.Right := 46 * 17 +
       Left;
     tr4w_WindowsArray[tw_FUNCTIONKEYSWINDOW_INDEX].WndRect.Bottom := 24 * 17 +
       130 + 40;

     tr4w_WindowsArray[tw_NETWINDOW_INDEX].WndRect.Right := 500;
     tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndRect.Right := 650;
     end;
  // Issue #739: validate every restored rect against the current monitor layout
  // so a window saved on a now-absent monitor is pulled back on-screen (cascaded).
  CascadeIndex := 0;
  for i := tw_MAINWINDOW_INDEX to tw_HAMSCOREWINDOW_INDEX do
     begin
     EnsureRectOnScreen(i, CascadeIndex);
     end;
  for i := tw_BANDMAPWINDOW_INDEX to tw_HAMSCOREWINDOW_INDEX do
     begin
     tr4w_WindowsArray[i].WndForm := nil;
     end;

  // No WndProcAdr for the band map: OpenTR4WWindow's seam builds an LCL form
  // for tw_BANDMAPWINDOW_INDEX and never reaches CreateDialogIndirectParam.
  // No WndProcAdr for either dupe sheet: both are LCL forms as of 2026-08-24
  // and OpenTR4WWindow's seam builds them.
  // No WndProcAdr for the function keys window either, as of 2026-09-01 -- and
  // it was the LAST ONE. OpenTR4WWindow has tested tw_FUNCTIONKEYSWINDOW_INDEX
  // FIRST and built the LCL form since 2026-08-24, so this assignment has been
  // dead ever since: written on every start-up, read by nothing. The proc it
  // pointed at went with it.
  //
  // Every entry in tr4w_WindowsArray now has a nil WndProcAdr, which is what
  // makes OpenTR4WWindow's CreateDialogIndirectParam fallback unreachable --
  // see the note where that used to be.
  // No WndProcAdr for the SCP window: it is an LCL form as of 2026-08-24.
  // No WndProcAdr for any of the five remaining-multiplier windows: they are
  // LCL forms as of 2026-08-24.
  // Neither radio panel has a WndProcAdr: they are two instances of one LCL
  // form (uRadioPanelForm) and OpenTR4WWindow reaches them directly.
  // tw_NETWINDOW_INDEX has no WndProcAdr: it is an LCL form (uNetworkForm).
  // It could not be one until the multi-op socket stopped being delivered to
  // this window by WSAAsyncSelect.
  // tw_INTERCOMWINDOW_INDEX has no WndProcAdr: it is an LCL form
  // (uIntercomForm) and OpenTR4WWindow reaches it directly.
  // tw_POSTSCORESWINDOW_INDEX has no WndProcAdr: it is an LCL form
  // (uPostScoresForm) and OpenTR4WWindow reaches it directly.
  // Issue #783 Phase 4 -- HamScore RTC status window dialog
  // tw_HAMSCOREWINDOW_INDEX has no WndProcAdr: it is an LCL form
  // (uHamScoreForm) and OpenTR4WWindow reaches it directly.
  // No WndProcAdr for the stations window either: it is an LCL form as of
  // 2026-08-24 and OpenTR4WWindow's seam builds it.
  // tw_MP3RECORDER has no WndProcAdr: it is an LCL form (uMP3RecorderForm)
  // and OpenTR4WWindow reaches it directly.

end;

procedure scWK_RESET; // n4af 4.43.10
begin
  wkSendAdminCommand(wkRESET);
end;

(* The clock and rate displays, once a second. A plain procedure now -- it read
  none of the four arguments a TIMERPROC is given. *)
procedure OneSecondTick;
begin
  UpdateTimeAndRateDisplays(True, True);

{$IF tDebugMode}
  // Windows.SetWindowTextA(tr4whandle, inttopchar({GetHeapStatus.TotalFree}AllocMemSize));
 // Windows.SetWindowTextA(InsertWindowHandle, inttopchar(FreeMemCount));
{$IFEND}
end;

procedure FrmSetFocus;
begin
  (* THE FORM TAKES FOCUS, not a handle. Windows.SetFocus against the
    cached tr4whandle is the same trap the title bar fell into. CanFocus
    guards the case TWinControl.SetFocus raises on and the API ignored:
    a form that is not yet visible. *)
  if (TR4WMainForm <> nil) and TR4WMainForm.CanFocus then
     begin
     TR4WMainForm.SetFocus;
     end;
end;

function GetRealVirtualKey(var Key: integer): Byte;

begin
  Result := 0;

  // if GetKeyState(VK_CONTROL or VK_MENU) < -126 then Exit;

  if GetKeyState(VK_CONTROL) < -126 then
     begin
     Key := Key + 12;
     Result := 1;
     Exit;
     end;

  if GetKeyState(VK_MENU) < -126 then
     begin
     Key := Key + 24;
     Result := 2;
     end;

end;

procedure ShowSyserror(ErrorCode: Cardinal);
begin
  (* MB_TASKMODAL was asking by hand for what an LCL dialog is by default. *)
  MessageDlg('TR4W', LclText(SysUtils.SysErrorMessage(ErrorCode)), mtError, [mbOK], 0);
end;

function YesOrNo(const Text: string): integer;
begin
   if QuestionDlg('TR4W', Text, mtConfirmation,
                  [mrYes, mrNo, 'IsDefault'], 0) = mrYes then
      begin
      Result := IDYES;
      end
   else
      begin
      Result := IDNO;
      end;
end;

function YesOrNo2(const Text: string): integer;
begin
   { OK/Cancel, and OK was MB_DEFBUTTON1 -- the first button, which is what
     QuestionDlg focuses anyway, so no marker is needed here. }
   if QuestionDlg('TR4W', Text, mtConfirmation,
                  [mrOk, mrCancel], 0) = mrOk then
      begin
      Result := IDOK;
      end
   else
      begin
      Result := IDCANCEL;
      end;
end;

function TuneOnFreqFromCallWindow: boolean;
var
  TempFreq: Cardinal;
  TempMode: ModeType;
  TempBand: BandType;
  TempVFO: Char;
  TempString: CallString;
  FilteredFreq: longint;   // read once -- see the band-fallback block below
const
  QSYSHIFT = 20000;
begin
  Result := False;
  logger.debug('[TuneOnFreq] Enter: CallWindowString="%s"', [CallWindowString]);
  if CheckCommandInCallsignWindow then
     begin
     tCleareCallWindow;
     Result := True;
     Exit;
     end;
  if length(CallWindowString) < 2 then
     begin
     logger.debug('[TuneOnFreq] Exit: length < 2');
     Exit;
     end;

  TempVFO := 'A';
  TempString := CallWindowString;

  if TempString[length(TempString)] = 'B' then
     begin
     TempVFO := 'B';
     TempString[0] := AnsiChar(Ord(TempString[0]) - 1);
     end;

  if StringIsAllNumbersOrDecimal(TempString) = False then
     begin
     logger.debug('[TuneOnFreq] Exit: not all numbers/decimal, TempString="%s"', [TempString]);
     Exit;
     end;

  TempBand := ActiveBand;
  logger.debug('[TuneOnFreq] TempBand=%d, TempString="%s"', [Ord(TempBand), TempString]);

  if not (TempBand in [Band160..Band2]) then
     begin
     // READ ONCE.  This tried the radio's frequency shifted up, then the same
     // frequency shifted down, then logged it -- three separate reads of a value
     // the polling thread is free to change between them.  A QSY landing in the
     // middle made the -QSYSHIFT fallback probe a DIFFERENT base frequency than
     // the +QSYSHIFT attempt, so the two halves of one decision disagreed, and
     // the diagnostic printed a third value again.
     //
     // A single aligned 32-bit read is atomic, so this never tore; the defect
     // was assuming three reads of one field return the same answer.
     FilteredFreq := ActiveRadioPtr.FilteredStatus.Freq;

     GetBandMapBandModeFromFrequency(FilteredFreq + QSYSHIFT, TempBand, TempMode);

     if not (TempBand in [Band160..Band2]) then
        begin
        GetBandMapBandModeFromFrequency(FilteredFreq - QSYSHIFT, TempBand, TempMode);
        end;

     if not (TempBand in [Band160..Band2]) then
        begin
        logger.debug('[TuneOnFreq] Exit: TempBand not in HF range after fallback, FilteredFreq=%d', [FilteredFreq]);
        Exit;
        end;
     end;

  TempFreq := StrToIntDef(TempString, 0);
  //3500
  // 620
  // 34
  if (TempFreq >= 0)   and 
     (TempFreq <= 999) then
     begin
     if TempFreq < 100 then
        begin
        TempFreq := TempFreq * 1000 + StartingFrequencies[TempBand];
        end
     else
        begin
        TempFreq := TempFreq * 1000 + (StartingFrequencies[TempBand] div 1000000)
          * 1000000;
        end;
     end
  else
     begin
     TempFreq := TempFreq * 1000;
     end;

  logger.debug('[TuneOnFreq] TempFreq=%u before GetBandMap', [TempFreq]);
  GetBandMapBandModeFromFrequency(TempFreq, TempBand, TempMode);
  logger.debug('[TuneOnFreq] After GetBandMap: TempBand=%d, TempMode=%d', [Ord(TempBand), Ord(TempMode)]);
  if TempBand <> NoBand then
     begin
     SetRadioFreq(ActiveRadio, TempFreq, TempMode, TempVFO);
     tCleareCallWindow; // 4.139.2
     Result := True;
     logger.debug('[TuneOnFreqFromCallWindow] Clearing Mults and QSO Needs Headers');
     TR4WMainForm.pnlMultNeedsHeader.Caption := PAnsiChar('');
     TR4WMainForm.pnlQSONeedsHeader.Caption := PAnsiChar('');
     end;

  {
  i := 0;
  if length(TempString) = 3 then i := tBaseFrequencys[ActiveBand];
  if pos('.', TempString) in [3, 4] then i := tBaseFrequencys[ActiveBand];
  Val(TempString, f, code);

  if f > (maxdword / 1000) then Exit;
  TempFreq := round((i + f) * 1000);
  TempMode := NoMode;
  GetBandMapBandModeFromFrequency(TempFreq, TempBand, TempMode);
  // CalculateBandMode(TempFreq, TempBand, TempMode);
  if TempBand <> NoBand then
  begin
  SetRadioFreq(ActiveRadio, TempFreq, TempMode, TempVFO);
  tCleareCallWindow;
  Result := True;
  end;
  }
end;

{ THE FORM BEHIND A WINDOW INDEX, or nil for one that is still a Win32 dialog
  or has not been created yet.

  ONE MAPPING, USED BY BOTH THE OPEN PATH AND THE SAVE PATH, and that is the
  whole point of it existing.  They must agree about what a window's bounds
  MEAN, and this is exactly the defect that came of them disagreeing:

    FindAndSaveRectOfAllWindows saved Windows.GetWindowRect -- the OUTER
    rectangle, frame included.  OpenTR4WWindow restored into
    lclForm.BoundsRect.  On a form whose LCL Height is its CLIENT height, the
    saved outer height became the new client height and THE WINDOW GREW BY THE
    FRAME EVERY TIME.  NY4I's function-key window: resize it shorter, quit,
    restart, and it is back where it started -- 39 pixels taller per cycle,
    measured (BoundsRect 42 against GetWindowRect 81 on the same window).

  So the save asks the FORM when there is one, and Windows only when there is
  not.  Two lists of which windows are forms would drift; there is one. }
(* THE TABLE ANSWERS THIS NOW.

  This was a twenty-arm case mapping each tw_ id to its form global -- the same
  mapping OpenTR4WWindow performs when it opens the window, written a second
  time and kept in step by hand.

  IT ALSO ANSWERED FOR CLOSED WINDOWS, which is the half that mattered. The
  form globals outlive their windows, so this returned an object for a window
  the operator had shut, and every caller had to pair it with tWindowsExist for
  the answer to mean anything. The table holds a form only while the window is
  open, so the pairing IS the lookup. *)
function LclFormFor(const ID: WindowsType): TCustomForm;
begin
   Result := tr4w_WindowsArray[ID].WndForm;
end;

procedure FindAndSaveRectOfAllWindows;
label
  1;
var
  tipos: WindowsType;
  temprect: TRect;
  TempBool: boolean;
  iconic: boolean;
  lclForm: TCustomForm;
begin
  for tipos := tw_MAINWINDOW_INDEX to tw_HAMSCOREWINDOW_INDEX do
     begin
     { SAVE WHAT THE RESTORE WILL READ -- see LclFormFor.  Windows only for a
       window that is still a Win32 dialog. }
     { SAVE WHAT THE RESTORE WILL CONSUME.

       MEASURED, in one call, on NY4I's bench (2026-08-26):

         GetWindowRect = (1708,837,2500,919)   792 x 82   the real window
         BoundsRect    = (1708,837,2484,880)   776 x 43   what the LCL holds
         L/T = 1708,837   W/H = 776,43   client = 776,43

       LEFT AND TOP AGREE EXACTLY.  Width and Height DO NOT: the LCL's are the
       CLIENT dimensions, and the real window is bigger by the frame -- 16 and
       39 here.

       So saving GetWindowRect and restoring through BoundsRect fed an OUTER
       size in as a CLIENT size, and the window grew by the frame EVERY restart:
       792x82 -> 808x121 in the very next sample.  NY4I: resize it shorter, quit,
       restart, and it is back where it started.

       Both sides now speak the LCL's units.  Which measure is "right" does not
       matter -- only that one object answers both questions. }
     { AND ONLY WHEN THE WINDOW IS ACTUALLY OPEN.

       WndHandle is zeroed by CloseTR4WWindow, which is how this routine has
       always known a window is shut -- GetWindowRect then failed and the saved
       rect was kept.  A CLOSED LCL FORM STILL HAS AN OBJECT AND STILL HAS A
       HANDLE, so asking the form instead threw that guard away: every closed
       window reported its hidden bounds, which differ from the saved ones, so
       the autosave saw a change EVERY TICK and rewrote the file every five
       seconds -- overwriting good saved positions with a hidden form's. }
     (* THE HANDLE TEST IS THE NIL TEST NOW. It was there because LclFormFor
       answered for CLOSED windows too, and reading a closed form's bounds
       overwrote a good saved position every tick. The table only holds an open
       window's form, so the guard is the lookup -- and the GetWindowRect
       fallback goes with it: it existed for the case where there was no form,
       which is now the case where there is no window. *)
     lclForm := LclFormFor(tipos);
     TempBool := (lclForm <> nil) and lclForm.HandleAllocated;
     if TempBool then
        begin
        temprect := lclForm.BoundsRect;
        end;

     // VISIBILITY IS ITS OWN QUESTION, asked of Windows rather than inferred
     // from whether a rectangle could be read.
     //
     // The two used to be the same answer, and correctly so: every one of these
     // was a dialog whose HWND existed only between CreateDialogIndirectParam
     // and DestroyWindow, so a rect that could be read WAS an open window.  An
     // LCL form's handle outlives its visibility -- it survives being hidden,
     // and the widget set may recreate it on its own -- so the old rule now
     // reads "hidden" as "visible".
     //
     // WndVisible is what OpenOtherWindows replays at startup, so getting it
     // wrong means a window the operator closed comes back on the next run.
     // IsWindowVisible answers for a zero handle too (False), which is the
     // closed case.
     tr4w_WindowsArray[tipos].WndVisible := (lclForm <> nil) and lclForm.Visible;
     if not TempBool then
        begin
        if logger.IsTraceEnabled then
           begin
           logger.Trace('[SaveRect] %s (idx=%d) no open form -> keep saved',
             [WindowNames[tipos], Ord(tipos)]);
           end;
        Continue;
        end;
     iconic := (lclForm <> nil) and (lclForm.WindowState = wsMinimized);
     if logger.IsTraceEnabled then
        begin
        logger.Trace('[SaveRect] %s (idx=%d) live=(%d,%d,%d,%d) iconic=%d reloc=%d savedWndRect=(%d,%d,%d,%d)',
          [WindowNames[tipos], Ord(tipos), temprect.Left, temprect.Top, temprect.Right, temprect.Bottom,
           Ord(iconic), Ord(RelocState[tipos].Relocated),
           tr4w_WindowsArray[tipos].WndRect.Left, tr4w_WindowsArray[tipos].WndRect.Top,
           tr4w_WindowsArray[tipos].WndRect.Right, tr4w_WindowsArray[tipos].WndRect.Bottom]);
        end;
     // Issue #739: if we relocated this window at startup because its saved
     // monitor was absent, and the user did not move it this session, keep the
     // ORIGINAL saved rect so reconnecting that display restores the layout.
     if RelocState[tipos].Relocated and
        BoundsMatch(temprect, tr4w_WindowsArray[tipos].WndRect) then
        begin
        if logger.IsTraceEnabled then
           begin
           logger.Trace('[SaveRect] %s (idx=%d) PRESERVE -> orig=(%d,%d,%d,%d)',
             [WindowNames[tipos], Ord(tipos), RelocState[tipos].OrigRect.Left, RelocState[tipos].OrigRect.Top,
              RelocState[tipos].OrigRect.Right, RelocState[tipos].OrigRect.Bottom]);
           end;
        tr4w_WindowsArray[tipos].WndRect := RelocState[tipos].OrigRect;
        Continue;
        end;
     // Issue #739: save any non-minimized position, including negative X/Y on a
     // monitor placed left of / above the primary.  IsIconic skips only minimized
     // windows (which report a -32000 sentinel rect).
     if not iconic then
        begin
        tr4w_WindowsArray[tipos].WndRect := temprect;
        end;
     end;
end;

function TryKillAutoCQ: boolean;
begin
  Result := False;
  if tAutoCQMode = True then
     begin
     StopAppTimer(atAutoCQ);
     tAutoCQMode := False;
     TR4WMainForm.pnlOpMode.Caption := 'CQ';
     QuickDisplay('');
     Result := True;
     end;

end;

procedure RunAutoCQ;

begin
  if tAutoCQMode = False then
     begin
     SetUpToSendOnActiveRadio;
     SetOpMode(CQOpMode);
     tAutoCQMode := True;
     TR4WMainForm.pnlOpMode.Caption := 'AutoCQ';
     SendFunctionKeyMessage(AutoCQMemory, OpMode);
     tDisplayAutoCQStatus;
     end;
end;

procedure TestMP;
var
  F1, F2, F3: integer;
  PartialRadioResponse: string;
  TempFreq: integer;
  TempBand: BandType;
  TempMode: ModeType;

begin
  PartialRadioResponse :=
    #$11 + #$01 + #$56 + #$76 + #$B4 + #$20 + #$20 + #$02 + #$33 + #$20 + #$11 +
    #$33 + #$33 + #$91 + #$11 + #$20 +
    #$0B + #$00 + #$AB + #$F8 + #$D4 + #$20 + #$20 + #$02 + #$33 + #$20 + #$11 +
    #$33 + #$33 + #$91 + #$11 + #$20
    ;
  // PartialRadioResponse := ' ' + PartialRadioResponse;
  with Radio1.CurrentStatus do
     begin
     F1 := Ord(PartialRadioResponse[2]);
     F1 := F1 * 256 * 256 * 256;
     F2 := Ord(PartialRadioResponse[3]);
     F2 := F2 * 256 * 256;
     F3 := Ord(PartialRadioResponse[4]);
     F3 := F3 * 256;

     TempFreq := F1 + F2 + F3 + Ord(PartialRadioResponse[5]);

     { Frequency corrections }

     if Radio1.RadioModel = FT1000MP then
        begin
        TempFreq := round(TempFreq * 0.625);
        end;
     if Radio1.RadioModel = FT100 then
        begin
        TempFreq := round(TempFreq * 1.25);
        end;

     { Calculate default band/mode }

     CalculateBandMode(TempFreq, TempBand, TempMode);

     { Look at band/mode information from radio }

     if Radio1.RadioModel = FT1000MP then
        begin
        case (Ord(PartialRadioResponse[8]) and $07) of
          2, 5, 6: TempMode := CW;
        else
          TempMode := Phone;
        end;
        end;

     if Radio1.RadioModel = FT100 then
        begin
        case (Ord(PartialRadioResponse[6]) and $07) of
          2, 3, 5: TempMode := CW;
        else
          TempMode := Phone;
        end;
        end;

     VFO[VFOA].Frequency := TempFreq;
     VFO[VFOA].Band := TempBand;
     VFO[VFOA].Mode := TempMode;

     Delete(PartialRadioResponse, 1, 16);
     if PartialRadioResponse[2] = #$20 then
        begin
        PartialRadioResponse[2] := #0;
        end;
     F1 := Ord(PartialRadioResponse[2]);
     F1 := F1 * 256 * 256 * 256;
     F2 := Ord(PartialRadioResponse[3]);
     F2 := F2 * 256 * 256;
     F3 := Ord(PartialRadioResponse[4]);
     F3 := F3 * 256;

     TempFreq := F1 + F2 + F3 + Ord(PartialRadioResponse[5]);

     { Frequency corrections }
    {
   11270352 MUST
   548141268
   7043.970
   }
     if Radio1.RadioModel = FT1000MP then
        begin
        TempFreq := round(TempFreq * 0.625);
        end;
     if Radio1.RadioModel = FT100 then
        begin
        TempFreq := round(TempFreq * 1.25);
        end;

     { Calculate default band/mode }

     CalculateBandMode(TempFreq, TempBand, TempMode);

     { Look at band/mode information from radio }

     if Radio1.RadioModel = FT1000MP then
        begin
        case (Ord(PartialRadioResponse[8]) and $07) of
          2, 5, 6: TempMode := CW;
        else
          TempMode := Phone;
        end;
        end;

     if Radio1.RadioModel = FT100 then
        begin
        case (Ord(PartialRadioResponse[6]) and $07) of
          2, 3, 5: TempMode := CW;
        else
          TempMode := Phone;
        end;
        end;

     VFO[VFOB].Frequency := TempFreq;
     VFO[VFOB].Band := TempBand;
     VFO[VFOB].Mode := TempMode;

     end;

end;

// ALT+I -- INCREMENT THE NUMBER IN THE EXCHANGE FIELD.
//
// TALKS TO THE CONTROL, NOT TO A WINDOW.  It used to ask Windows:
//
//     Value := GetDlgItemInt(tr4whandle, EXCHANGEWINDOWID, lpTranslated, False);
//     SetEntryText(TR4WExchangeEdit, ...);
//
// -- three Win32 calls addressing an LCL TEdit by dialog-item id and by HWND.
// It stopped working (NY4I, 2026-08-23: "It did not work which is why I
// asked"), and it could not have been noticed by a build: GetDlgItemInt simply
// reports lpTranslated = False and the routine does nothing at all.  A silent
// no-op is the characteristic failure of reaching an LCL control through the
// Win32 API.
//
// The object has been sitting there for exactly this.  CreateEntryField keeps
// TR4WExchangeEdit and says why: "THE OBJECT IS KEPT, not only its handle.
// Nothing reads these two yet."  Something does now.
//
// This is the worked example for the other 644 HWNDs the Win32 lint counts --
// the conversion that matters is not moving a widget into a .lfm, it is
// deleting the handle that reaches it.
procedure tAltI;
var
  value: integer;
begin
  if TR4WExchangeEdit = nil then
     begin
     Exit;
     end;

  // Not a number: do nothing, which is what lpTranslated = False meant.
  if not TryStrToInt(Trim(TR4WExchangeEdit.Text), value) then
     begin
     Exit;
     end;

  // THE LEADING SPACE IS KEPT.  The old format string was ' %u' -- the field is
  // written with one and every other writer of this field matches it, so
  // dropping it here would make the exchange shift by a character only when
  // Alt+I was used.
  TR4WExchangeEdit.Text := ' ' + IntToStr(value + 1);

  TR4WExchangeEdit.SelStart  := Length(TR4WExchangeEdit.Text);
  TR4WExchangeEdit.SelLength := 0;
end;

procedure tr4w_alt_n_transmit_frequency;
var
  Freq: integer;
  RadioToSet: RadioPtr {RadioType};
begin
  begin

    // "-" is a TOGGLE, but InSplit only records split that TR4W ITSELF set -- it is
    // assigned nowhere except in this routine.  When the RADIO is already in split
    // (set at the front panel, or still in split when the program starts), InSplit
    // is False while the radio window's split indicator and the TC_SPLIT_WARN banner
    // are both on, because those are driven from rig.CurrentStatus.Split
    // (uRadioPolling DisplayCurrentStatus).  "-" then fell through to the "enter a
    // transmit frequency" branch and the operator had to press it twice to get out.
    // Consult the radio's state as well: CurrentStatus.Split is read back on radios
    // that report split and mirrors the commanded state on those that don't, so this
    // is a superset of InSplit and cannot regress a radio that worked before.
    if InSplit                            or 
       ActiveRadioPtr.CurrentStatus.Split then
       begin
       PutRadioOutOfSplit(ActiveRadio); // n4af 4.47.5
       PutRadioOutOfSplit(InActiveRadio);
       // THE RADIO IS THE SOURCE OF TRUTH.  For a radio that REPORTS split,
       // InSplit is not maintained at all -- the condition above already reads
       // ActiveRadioPtr.CurrentStatus.Split, so the radio's own broadcast drives
       // everything and the program cannot show a state the rig is not in.
       //
       // Only a radio that CANNOT report split needs the shadow flag, because
       // there the commanded state is the only state there is.
       //
       // Do NOT simply skip the clear for reporting radios: NOTHING else in the
       // program writes InSplit (it is assigned in exactly three places, all
       // here), so leaving it True stranded the flag and every later '-' re-ran
       // this branch and appeared to do nothing.
       if not ActiveRadioPtr.HasCapability(rcReadSplit) then
          begin
          InSplit := False;
          end;
       exit;
       end;

    Freq := QuickEditFreq(TC_TRANSMITFREQUENCYKILOHERTZ, 10);

    RadioToSet := ActiveRadioPtr {ActiveRadio};

    if Freq < -2 then
       begin
       Freq := Freq * (-1);
       RadioToSet := InActiveRadioPtr {InactiveRadio};
       end;

    if (Freq = 0) then
       begin
       PutRadioOutOfSplit(ActiveRadio);
       end;
    if (Freq = -0) then
       begin
       PutRadioOutOfSplit(InactiveRadio);
       end;
    if (Freq > 1000)    and 
       (Freq < 1000000) then
       begin
       case RadioToSet.BandMemory {BandMemory[RadioToSet]} of
         Band80: Freq := Freq + 3000000;
         //      Band60: Freq := Freq  +5300000;
         Band40: Freq := Freq + 7000000;
         Band20: Freq := Freq + 14000000;
         Band15: Freq := Freq + 21000000;
         Band10: Freq := Freq + 28000000;
         end;
       end;
    // Same rule as the exit branch: a reporting radio's split state comes
    // from the radio, so do not shadow it here either.
    if not RadioToSet.HasCapability(rcReadSplit) then
       begin
       InSplit := True;
       end;
    if Freq > 1000000 then
       begin
       // SetRadioFreq(ActiveRadio, Freq, ActiveMode, 'B');
       RadioToSet.SetRadioFreq(Freq, RadioToSet.ModeMemory, 'B');
       // SetRadioFreq(RadioToSet, Freq, ModeMemory[RadioToSet], 'B'); {KK1L: 6.73}
       // PutRadioIntoSplit(RadioToSet); {KK1L: 6.73}
       RadioToSet.PutRadioIntoSplit;
       SplitFreq := Freq;
       // Same rule as the exit branch: a reporting radio's split state comes
       // from the radio, so do not shadow it here either.
       if not RadioToSet.HasCapability(rcReadSplit) then
          begin
          InSplit := True;
          end;
       end;
    BandMapCursorFrequency := Freq; {KK1L: 6.68 Band map tracks transmit freq}
    DisplayBandMap;
  end;
end;

procedure tr4w_toggle_sidetone;
begin
  if (ActiveMode = Phone) and DVPActive then
     begin
     ReviewBackCopyFiles
     end
  else if Config.CWTone <> 0 then
     begin
     OldCWTone := Config.CWTone;
     Config.CWTone := 0;
     AddStringToBuffer('', Config.CWTone);
     NoSound;
     end
  else
     begin
     if OldCWTone = 0 then
        begin
        OldCWTone := 700;
        end;
     Config.CWTone := OldCWTone;
     AddStringToBuffer('', Config.CWTone);
     end;
end;

procedure tClearDupesheet_Ctrl_K;
begin
  tInputDialogWarning := True;
  if QuickEditResponse(TC_YESTOCLEARTHEDUPESHEET, 3) = 'YES' then
     begin
     tClearDupesheet;
     end;
end;

procedure tClearDupesheet;

begin

  tUpdateLog(actSetClearDupesheetBit);
  UpdateTotals2;
  CallsignsList.ClearDupes;

  QuickDisplay(TC_DUPESHEETCLEARED
    { To restore, delete RESTART.BIN and start program over.'});

  // callsignsList.DisplayDupeSheet(@Radio1 {ActiveBand, ActiveMode}); //n4af 4.38.7
  CallsignsList.DisplayDupeSheet(@Radio2 {ActiveBand, ActiveMode});
  // n4af 4.38.7
  SpotsList.ResetSpotsDupes;
  // ResetBandMapDupes;
  DisplayBandMap;
  UpdateAllStationsList;

  ShowInformation;
end;

procedure tr4w_add_note_in_log;
var
  s: ShortString;
  i: integer;
begin
  tInputDialogLowerCase := True;
  s := QuickEditResponse(TC_NOTE, 80);
  i := length(s);
  logger.info('******* User added note: [%s]', [s]);
  if i = 0 then
     begin
     Exit;
     end
  else if i > 80 then
     begin
     i := 80;
     end;
  FillChar(TempRXData, SizeOf(ContestExchange), 0);
  TempRXData.ceRecordKind := rkNote;
  (* Move, and the arguments reverse: MoveMemory(Dest, Src, Len) but
    Move(const Src, var Dest, Count). *)
  Move(s[1], TempRXData.Prefix, i);
  AddRecordToLogAndSendToNetwork(TempRXData);
end;

procedure tr4w_log_qso_without_cw;
var
  PeviousCWEnable: boolean;
  PeviousDVPEnable: boolean;
  PreviousBeSilent: boolean;
begin
  PeviousCWEnable := Config.CWEnable;
  PeviousDVPEnable := Config.DVKEnable;
  PreviousBeSilent := BeSilent;

  Config.CWEnable := False;
  Config.DVKEnable := False;
  BeSilent := True;

  ProcessReturn;

  Config.CWEnable := PeviousCWEnable;
  Config.DVKEnable := PeviousDVPEnable;
  BeSilent := PreviousBeSilent;
end;

procedure tr4w_ShutDown;
begin
  { PTTOff; // 4.113.1
  scWK_RESET; // 4.113.1
  WkClose; // 4.113.1 }

  // Backstop only.  The call that MATTERS is at the top of ExitProgram --
  // by the time this runs the radios are already disconnected.  Left here
  // for any exit path that does not go through ExitProgram; it reports
  // honestly when there is nothing left to talk to.
  PutAllRadiosIntoReceive;

  if IsDXLabPathfinderRunning then
     begin
     StopDXLabPathfinder;
     end;
  if Assigned(wsjtx) then
     begin
     wsjtx.Stop;
     FreeAndNil(wsjtx);
     end;

  // Before the radios go away.  Stop detaches the polling hook first, so the
  // poll loop cannot enter a server that is tearing its sessions down, and
  // each session's disconnect unkeys a transmitter that client was holding.
  if Assigned(TCIServer) then
     begin
     TCIServer.Stop;
     FreeAndNil(TCIServer);
     end;

  if assigned(externalLogger) then
     begin
     FreeAndNil(externalLogger);
     end;

  { A PANADAPTER MAY STILL HOLD EITHER RADIO.  Release it before the object
    goes, while StopSpectrum can still join the reading thread -- the same
    contract RadioObject.ShutDownRadioInterface honours on a profile change.

    DETACH, DO NOT CLOSE.  Closing records visible=False, which at exit would
    quietly discard "this window was open" and stop it reopening next run. }
  PanadapterRadioGoingAway(Radio1.tFactoryObject, False);
  PanadapterRadioGoingAway(Radio2.tFactoryObject, False);

  if Radio1.tFactoryObject <> nil then
     begin
     FreeAndNil(Radio1.tFactoryObject);
     end;

  if Radio2.tFactoryObject <> nil then
     begin
     FreeAndNil(Radio2.tFactoryObject);
     end;


  (* CLOSE THE LOG DATABASE. NOTHING ELSE EVER DID.

    THE SYMPTOM WAS STRAY FILES: every contest left a .db-wal and a .db-shm
    behind (NY4I, 2026-09-02). SQLite deletes both when the LAST connection
    closes cleanly, and keeps them when a process "exits without cleanly
    shutting down the database connection" -- which is precisely what this
    program did, on every run.

    THE CAUSE IS THREE LINES BELOW: ExitProcess. It terminates immediately, so
    no unit finalization runs, no destructor runs, and TLogDatabase.Destroy --
    which does close the connection properly -- was never reached. LogStoreClose
    existed, was correct, and had NO CALLERS anywhere in the tree.

    SO THE STRAY FILES WERE THE SMALL HALF OF IT. LogStoreClose also runs
    CaptureConfigurationOnClose, so the contest configuration was never recorded
    into the log at close either. A .db-wal is visible; that is not.

    BEFORE THE LOGGER GOES, deliberately -- the capture reports its own failures
    through it, and this is the last moment those reach the file.

    LEFT-OVER FILES FROM EARLIER RUNS ARE NOT OURS TO DELETE. A -wal holds
    COMMITTED transactions that are not yet checkpointed into the .db, so
    removing one by hand loses QSOs. The only safe disposal is the one SQLite
    documents: open the database and close it cleanly -- which, from this commit
    on, simply happens the next time that contest is opened. *)
  LogStoreClose;

  if Assigned(logger) then
     begin
     logger.Info('------------------------------Program shutdown----------------------------');
     FreeAndNil(logger);
     end;
  // Issue #783 -- stop the HamScore RTC uploader cleanly so its worker thread
  // is not holding sockets when the process exits.  This was a `finally` at the
  // bottom of tr4w.lpr, below the message loop, which meant it only ran if the
  // loop RETURNED -- and it never does: the exit path is ExitProcess, three
  // lines below this one.  So the clean shutdown it exists to provide has never
  // actually happened.  Here it does.
  HamScoreShutdown;

  (* NOTHING TO UNREGISTER. The matching RegisterClass in uProgramMain is gone
    (2026-09-06): it registered a window class that no CreateWindowEx names,
    because the main window is an LCL form. Unregistering a class that was
    never registered simply fails, which is why this never reported anything.

    The original carried a note worth keeping: the call had to be qualified,
    because an unqualified UnregisterClass binds to Classes.UnregisterClass --
    a completely different routine that deregisters a streaming class. ny4i,
    Issue 145. *)
  (* ZERO, NOT hInstance. This passed the MODULE HANDLE as the process exit
    code, so every clean shutdown of TR4W reported 4194304 ($400000, the
    default image base) to whatever launched it. Any script that checks an
    exit code -- a CI step, a harness, an operator's batch file -- reads that
    as a failure, and it has been the value since the D7 tree. *)
{$IFDEF WINDOWS}
  ExitProcess(0);
{$ELSE}
  (* Halt, NOT ExitProcess -- AND THE DIFFERENCE IS REAL, WHICH IS WHY THIS IS
    NOT A SWAP ON WINDOWS TOO.

    Halt runs FINALIZATION SECTIONS; ExitProcess does not. Every unit with a
    `finalization` block gets to run one way and not the other, and this tree
    has several that free objects and close files there -- uNet's GNetLock and
    tNet_Event among them. Something may be relying on them NOT running, and
    finding out means reading each one, so unifying the two is a DECISION
    about shutdown rather than a portability fix.

    Off Windows there is no ExitProcess to choose, so Halt it is; on Windows
    nothing changes until that decision is made. Recorded in
    docs/WIN32_ARTIFACT_SWEEP.md. *)
  Halt(0);
{$ENDIF}

end;

procedure ShowBeamAndHeadingInVHFContest(WindowString: CallString);
var
  Grid: GridString;
label
  1;
begin
  if VHFBandsEnabled then
     begin
     1:
     Grid := RemoveFirstString(WindowString);
     if Grid = '' then
        begin
        Exit;
        end;
     if length(Grid) >= 4 then
       if LooksLikeAGrid(Grid) then
          begin
          DisplayBeamHeading(CallWindowString, Grid);
          end;
     goto 1;
     end;
end;

procedure ExchangeWindowChange;
var
  TestString, TempString: Str40;
  TempExchange: ContestExchange;
  DQTH: boolean;
begin
  ExchangeWindowString := ShortString(AnsiString(EntryText(TR4WExchangeEdit)));
  if VHFBandsEnabled then
     begin
     ShowBeamAndHeadingInVHFContest(ExchangeWindowString);
     end;

  if DomesticCountryCall(CallWindowString) then
    if DoingDomesticMults then
       begin
       TempString := ExchangeWindowString;
       while TempString <> '' do
          begin
          TestString := RemoveFirstString(TempString);

          // if Contest in [NAQSOCW, NAQSOSSB] then
          // if TempString <> '' then Continue;

          // if ActiveDomesticMult = RDADistrict then
          // if length(TestString) <> 4 then TestString := '';
          if TestString = '' then
             begin
             Exit;
             end;
          logger.debug('[ExchangeWindowChange] Setting TempExchange.QTHString to (%s)', [TestString]);
          TempExchange.QTHString := TestString;
          DQTH := FoundDomesticQTH(TempExchange);
          if not DQTH then
             begin
             DispalayNewMult(SW_HIDE);
             //Exit;
             Continue;

             end;
          // if not DQTH then TempExchange.DomMultQTH := '' ;
          // strU(TempExchange.DomMultQTH);
          VisibleLog.SetMultStatus(CallWindowString, TempExchange.DomMultQTH);
          if DQTH then
             begin
             Exit;
             end;
          end;
       end;

  // POTA: look up park name from exchange as typed and show via QuickDisplay.
  if (ActiveExchange = RSTAndPOTAPark) and POTAParksLoaded then
     begin
     TempString := ExchangeWindowString;
     while TempString <> '' do
        begin
        TestString := RemoveFirstString(TempString);
        TestString := NormalizePOTAPark(TestString, MyPark);
        if TestString <> '' then
           begin
           if GetPOTAParkName(TestString) <> '' then
              begin
              QuickDisplay(GetPOTAParkName(TestString));
              Exit;
              end;
           end;
        end;
     end;

end;

procedure WagCheck; //added by n4af at behest of wag contest mgr
var
  ARF: integer;

begin
  ARF := ActiveRadioPtr.CurrentStatus.Freq div 1000;

  if (ARF > 3650) and (ARF < 3700) then
     begin
     QuickDisplay(TC_WagWarn); // 4.90.3
     exit;
     end;

  if (ARF > 7043) and (ARF < 7080) then
     begin
     QuickDisplay(TC_WagWarn);
     exit;
     end;

  if (ARF > 7080) and (ARF < 7143) then
     begin
     QuickDisplay(TC_WagWarn);
     exit;
     end;

  if (ARF > 14060) and (ARF < 14125) then
     begin
     QuickDisplay(TC_WagWarn);
     exit;
     end;

  if (ARF > 14280) and (ARF < 14350) then
     begin
     QuickDisplay(TC_WagWarn);
     exit;
     end;

  if (ARF > 21347) and (ARF < 21450) then
     begin
     QuickDisplay(TC_WagWarn);
     exit;
     end;

  if (ARF > 28225) and (ARF < 28400) then
     begin
     QuickDisplay(TC_WagWarn);
     exit;
     end;
end;

procedure CallWindowChange;
var
  nCmdShow: integer;
begin

  // Split warning is driven by DisplayCurrentStatus (uRadioPolling) on confirmed
  // state transitions — not here, where CurrentStatus.Split may be stale.
  // CallDataBase.ClearDataEntry;
  TR4WMainForm.pnlName.Caption := '';
  TR4WMainForm.pnlUserInfo.Caption := '';

  if Contest = WAG then //n4af 4.31.4
     begin
     WagCheck; //n4af
     end;

  CallWindowString := ShortString(AnsiString(Copy(EntryText(TR4WCallEdit), 1,
                                                  CallstringLength)));

  CallWindowEmpty := CallWindowString[0] = #0;
  if CallWindowEmpty then
     begin
     CallsignIsTypedByOperator := False;
     end;

  CallsignIsPastedFromBandMap := False;

  CallWindowKeyUpProc;
  ShowPartialCallMults(@CallWindowString);
  // if VHFBandsEnabled then ShowBeamAndHeadingInVHFContest(CallWindowString);

  if CallWindowString = '' then
     begin
     ShowElement(mweNewMultStatus, False);
     if OpMode = CQOpMode then
        begin
        if OpMode2 = SearchAndPounceOpMode then
           begin
           OpMode2 := CQOpMode;
           ShowFMessages(0);
           tCleareExchangeWindow;
           end;
        end;
     end;

  CallsignsList.CreatePartialsList(CallWindowString);

  {MASTER}

  nCmdShow := SW_HIDE;
  if length(CallWindowString) > 2 then
  begin
{$IF SCPDEBUG}
    nCmdShow := integer(scpFoundCallsign(@CallWindowString, MasterListBox,
      nil));
{$ELSE}
    if (SCPMinimumLetters > 0) then
       begin
       ClearMasterListBox;
       if VisibleLog.SuperCheckPartial(CallWindowString, True, ActiveRadioPtr)
         then
          begin
          nCmdShow := SW_SHOWNORMAL;
          end;
       end;
{$IFEND}
  end;

  ShowElement(mweMasterStatus, nCmdShow <> SW_HIDE);
  if not InactiveRigCallingCQ then //n4af 04.40.2
     begin
     ShowInformation;
     end;

  if tShowTypedCallsign then
     begin
     SendStationStatus(sstCallsign);
     end;

end;

function MainWindowHandle: THandle;
begin
   if TR4WMainForm = nil then
      begin
      Result := 0;
      Exit;
      end;
   Result := TR4WMainForm.Handle;
end;

(* THE ROUNDED-CORNER CODE IS GONE (2026-09-07). The window wears whatever
  corners the platform gives it.

  ApplyDWMRoundedCorners asked the DWM compositor for Windows 11 corners --
  DwmSetWindowAttribute(DWMWA_WINDOW_CORNER_PREFERENCE, DWMWCP_ROUND) -- with a
  Windows 10 fallback that clipped the window to a CreateRoundRectRgn.

  THE LCL HAS NO EQUIVALENT, and that was checked rather than assumed: neither
  DWMWA_WINDOW_CORNER_PREFERENCE nor DWMWCP appears anywhere in Lazarus, and the
  widgetset touches DwmApi in exactly one place (win32winapi.inc:1834) for
  DWMWA_EXTENDED_FRAME_BOUNDS. So this could only ever have been a raw Win32
  call, and it brought a LoadLibrary/GetProcAddress/FreeLibrary of its own on
  every invocation -- duplicating work FPC's DwmApi unit already does at unit
  initialisation.

  NY4I, 2026-09-07: "remove the win32 specific rounded corners code to be pure
  LCL. We will live with it or write a cross platform class we can use on our
  code, but that is not needed now."

  A DEFECT DIES WITH IT, worth recording in case the cross-platform version is
  ever written. The callers' comment said "DWM rounding is compositor-managed;
  no reapplication needed after move" -- true of the Windows 11 path and NOT of
  the fallback, which sized a region from the window as it stood at that
  instant. The main window became resizable earlier the same day, so on Windows
  10 the region would have stopped matching the frame the first time an operator
  dragged it. *)

{ See the WSJT-X note inside CreateMainWindow. }
const
  WSJTX_CELLS = 3;               // mweWSJTX's mweiWidth
  WSJTX_CHARS = 5;               // Length('WSJTX'), written by uStateBridge
  WSJTX_MIN_FONT_HEIGHT = 8;     // below this it stops being readable

procedure CreateMainWindow;
//var PanelWidth : array[0..1] of Integer;
var
  e: TMainWindowElement;
  temprect: TRect;
  // OffsetY : integer;
begin
  // PHASE 3a: the main window is an LCL TForm, and tr4whandle is its Handle.
  // Behaviour-neutral -- everything below this line is unchanged, the children
  // are still parented to tr4whandle, and the hand-rolled message loop is still
  // running. See src\ui\lcl\uMainForm.pas for what did and did not change.
  //
  // Was: CreateWindowExW($00010100, tr4w_ClassName, nil,
  //                      WS_SYSMENU or WS_MINIMIZEBOX,
  //                      0, 30, MainWindowWidth, 0, 0, tr4w_main_menu,
  //                      hInstance, nil)
  (* THE FORM IS THE WINDOW. This assigned its Handle to tr4whandle, a global
    that no longer exists -- the three Windows-only callers that still need a
    native handle ask MainWindowHandle for a fresh one. *)
  CreateTR4WMainForm;
  tr4w_WindowsArray[tw_MAINWINDOW_INDEX].WndForm := TR4WMainForm;

  (* THE EDITABLE LOG IS AN LCL GRID -- see uLogGrid.

    IT HAS NO WINDOW HANDLE. wh[mweEditableLog] is not assigned and nothing
    reaches this control except through the routines uMainForm exports. The
    thirty call sites that used to set a colour, read the header, ask which row
    was selected or set a column width through that handle are those routines
    now.

    WHAT THE WIN32 CONTROL COST, since the replacement is only justified by it:
    it was created with LVS_NOSCROLL and held LinesInEditableLog rows, so there
    was no scrollbar and the log showed five QSOs of a contest (NY4I: "I do not
    see my vertical scroll bar and I still see the qso window as a fixed 5").
    It was created at height 0 and sized afterwards, and a loop that sized it by
    counting visible rows drove that height back to 0 against a virtual list.
    And one line in LOGWIND replaced its window style wholesale, which stripped
    LVS_OWNERDATA and left the log blank. None of those are expressible against
    a control the LCL draws. *)
  CreateTR4WEditableLog(0, ws * 7,
    MainWindowChildsWidth, 30 + LinesInEditableLog * (ws + 2));
  DispalayLogGridLines;

  EditableLogHeight := TR4WEditableLogBoundsHeight;

  (* THE WINDOW IS SIZED AT THE END OF THIS ROUTINE, by
    MakeMainWindowResizeable, and no longer here.

    What stood here was a SetWindowPos giving an OUTER size, preceded by a
    GetWindowRect whose result was never read. One routine owns the size now,
    and it sets the CLIENT height -- which is the measurement this layout
    actually cares about and the one that does not change when the border
    does. *)
   { Round the four corners of the main window - radius 12px, adjust as needed }
  for e := Low(TMainWindowElement) to High(TMainWindowElement) do
     begin
     if TWindows[e].mweiStyle <= 2 then
        begin
        Continue;
        end;
     // AN LCL TPanel, not a Win32 STATIC.  Same metadata, same arithmetic --
     // TWindows[] is still the layout -- and the style bits become properties.
     // See CreateMainElement.
     (* wh[e] WAS WRITTEN HERE AND READ BY NOTHING. Measured 2026-09-05: the
       only live readers of wh[] are the server log's list view. Storing a
       handle for each element meant CreateMainElement had to CREATE one --
       touching TWinControl.Handle constructs the window -- so 110 windows were
       forced into existence at startup to fill an array nobody consults. *)
     //  wh[e] := CreateMainElement(   //AGENT_DEPRECATED
     CreateMainElement(
       e,
       TWindows[e].mweiStyle and (not (Cardinal(Config.NoBorder) * SS_SUNKEN)),
       TWindows[e].mweiX * ws,
       TWindows[e].mweiY * ws + TWindows[e].mweB * EditableLogHeight,
       round(TWindows[e].mweiWidth * ws),
       TWindows[e].mweiHeight * ws
       );

     // tWM_SETFONT handed the control an HFONT; an LCL control paints from its
     // own TFont, so the SHAPE goes across instead.  These are the same three
     // numbers tCreateFont was given for MainFont.
     SetElementFont(e, string(MainFontName),
                    ws - 2 + FontSize, BoldFont);

     SetElementColors(e,
                      tr4wColorsArray[TWindows[e].mweBackG],
                      tr4wColorsArray[TWindows[e].mweColor]);

     if TWindows[e].mweText <> '' then
        begin
        (* BY ELEMENT, because this is a loop over all of them. Direct
          property access is for the sites that name one; a dispatcher needs
          the indexed setter, and uMainForm's is a plain Caption write. *)
        SetElementText(e, TWindows[e].mweText)
        end
     end;

  { THE WSJT-X INDICATOR IS THREE CELLS WIDE AND ITS TEXT IS FIVE
    CHARACTERS.  It has never fitted -- mweWSJTX is mweiWidth 3 and
    uStateBridge writes the literal 'WSJTX' (NY4I, 2026-08-26: "the WSJTX
    letters are too big for the field").

    A SMALLER FONT, NOT A WIDER CELL, and that is NY4I's call: widening it
    would push QSO B4 along and move a row of the main window that is
    otherwise exactly where it has always been.

    The size is DERIVED from the mismatch rather than picked -- the same
    base every other element gets, scaled by cells-over-characters -- so it
    tracks the operator's FONT SIZE setting and the window scale instead of
    being right at one size and wrong at the others.  The floor keeps it
    legible if that arithmetic ever lands somewhere silly. }
  SetElementFont(mweWSJTX, string(MainFontName),
                 Max(WSJTX_MIN_FONT_HEIGHT,
                     Round((ws - 2 + FontSize) * WSJTX_CELLS / WSJTX_CHARS)),
                 BoldFont);


  // THE AUTO-SEND ARROW: a real code point in the main font, not byte 175 in
  // the Symbol font.
  //
  // It used to be mweText: #175#0 rendered in Symbol, where 0xAF is the down
  // arrow -- correct under D7, which set window text through SetWindowTextA and
  // handed the font a byte. SetMainWindowText now writes through
  // SetWindowTextW ("so the whole path is Unicode", TF.pas), so that byte is
  // widened by the codepage to U+00AF MACRON, which Symbol has no glyph for.
  // Windows drew the missing-glyph box.
  //
  // It went unnoticed because the arrow only appears when AUTO SEND CHARACTER
  // COUNT > 0, and on a station whose tr4w.ini could not be written that
  // setting reverted to 0 on every restart. Migrating it to the JSON store on
  // 2026-08-21 made it persist, and the box appeared (NY4I).
  //
  // U+2193 in the ordinary font also drops a Windows-only font dependency:
  // Symbol does not exist on GTK or Cocoa. See ROADMAP.md section 2.
  SetElementText(mweAutoSendCount, #$2193);
  DisplayAutoSendCharacterCount;

  // The QSO number is the one element with its own font -- tCreateFont(ws + 3,
  // FW_EXTRABOLD, lcfn).  FW_EXTRABOLD has no LCL counterpart; fsBold is the
  // closest a TFont offers, and the two render identically on every face TR4W
  // ships with.
  if LuconSZLoadded then
     begin
     SetElementFont(mweQSONumber, 'Lucida Console SZ', ws + 3, True);
     end
  else
     begin
     SetElementFont(mweQSONumber, 'Lucida Console', ws + 3, True);
     end;

  CreateCallOrExchangeWin(EditableLogHeight + ws * 8 {Line2},
    CALLSIGNWINDOWID, efCall);

{$IF OZCR2008}
  // QuickMemoryWindowHandle := nfCreateTR4WStaticWindow('Quick M.', col9, Line5, 4 * ws, DefStyleDis);
{$IFEND}

  DisplayInsertMode;

  Radio1.FreqElement := mweRadioOneFreq;
  Radio1.NameElement := mweRadioOne;
  Radio2.FreqElement := mweRadioTwoFreq;
  Radio2.NameElement := mweRadioTwo;

  (* DESIGNED IN uMainForm.lfm; positioned here, like every other element.
    The two colour arguments these calls used to carry are gone -- see the
    note on the progress bars in uMainForm, they had not reached the screen
    since the comctl32 v6 manifest was added. *)
  SetProgressBounds(mpbLastHour, ws * 28 {col6},
    EditableLogHeight + 10 * ws {Line4}, 5 * ws, ws);
  SetProgressBounds(mpbRate, ws * 33 {col8},
    EditableLogHeight + 10 * ws {Line4}, 5 * ws, ws);

  CreateCallOrExchangeWin(EditableLogHeight + ws * 8
    {+ round(ws * 1.5)} + MainWindowEditHeight + 1, EXCHANGEWINDOWID, efExchange);

  TR4WExchangeEdit.MaxLength := 35;   // created immediately above

  // Both fields exist now, so give them their colours.  Nothing else paints
  // them any more.
  RefreshEntryFieldColors;

  if TourDuration <> 0 then
     begin
     // Windows.GetWindowRect(wh[mweQuickCommand], temprect);
     SetElementBounds(mweQuickCommand, 0, EditableLogHeight + ws * 12,
                      ws * 33, ws);
     ShowElement(mweQuickCommand, True);
     SetTourDurationBounds(38 * ws {col9},
       EditableLogHeight + ws * 12 {Line7}, 8 * ws, ws);
     ShowTourDurationText(True);

     SetProgressBounds(mpbTourDuration, 33 * ws {col8},
       EditableLogHeight + ws * 12 {Line7}, 5 * ws, ws);
     SetProgressMax(mpbTourDuration, TourDuration);
     ShowProgressBar(mpbTourDuration, True);

     ShowTourDuration;
     end;

  // PHASE 3b: DESIGNED in uMainForm.lfm, positioned here.  It is addressed by
  // its Handle exactly as before, so the five LB_* messages uCallsigns and
  // LOGEDIT send it still land -- a TListBox's Handle IS that HWND.
  //
  // What moved: WM_MEASUREITEM and WM_DRAWITEM were answered by the main window
  // proc for this one control id, and are now ItemHeight and OnDrawItem.
  CreateTR4WPossibleCallList(
    0, EditableLogHeight + ws * 13 {line6}, MainWindowChildsWidth, ws,
    MainWindowPCLID, ws, 5 * ws {the old LB_SETCOLUMNWIDTH});
  SetPossibleCallFont(string(MainFontName),
                      ws - 2 + FontSize, BoldFont);

  // The drawing is attached HERE, not in uMainForm: it reads PossibleCallList
  // and the colour table, which that unit has no business knowing about.
  // The form's OnDrawItem is wired in uMainForm.lfm and delegates to this.
  PossibleCallDrawProc := @PossibleCallsDrawItem;


  (* THE CONTEST'S NAME IN TWO MENU CAPTIONS. Was ModifyMenuA, which rewrites
    the row through the menu handle; Caption is the property that row has. *)
  SetMenuCaption(menu_qrzru_calendar,
                 SysUtils.Format(TC_RULESONQRZRU, [string(ContestTypeSA[Contest])]));
  SetMenuCaption(menu_WA7BNM_calendar,
                 SysUtils.Format(TC_RULESONSM3CER, [string(ContestTypeSA[Contest])]));
  if (pos('CQ-WW', ContestTypeSA[Contest]) <> 0) or (pos('IARU-HF',
    ContestTypeSA[Contest]) <> 0) then //n4af 4.35.5 // 4.115.4
     begin
     T1 := 3600000 // 60 min break criteria
     end
  else
     begin
     T1 := 1800000; // normal 30min break
     end;
  if ContestsArray[Contest].QRZRUID = 0 then
     begin
     SetMenuEnabled(menu_qrzru_calendar, False);
     end;
  if ContestsArray[Contest].WA7BNM = 0 then
     begin
     SetMenuEnabled(menu_WA7BNM_calendar, False);
     end;
  if Contest = WRTC then
     begin
     SetMenuEnabled(menu_windows_trmasterdta, False);
     SetMenuEnabled(menu_windows_telnet, False);
     SetMenuEnabled(menu_windows_getscores, False);
     end;

  EnableNetworkMenuItem(False);

  // Windows.EnableMenuItem(tr4w_main_menu, menu_windows_mmtty, MF_BYCOMMAND or MF_ENABLED);

{$IF not OZCR2008}
  // DeleteMenu(tr4w_main_menu, menu_windows_stack, MF_BYCOMMAND or MF_GRAYED);
  // DeleteMenu(tr4w_main_menu, menu_windows_mf, MF_BYCOMMAND or MF_GRAYED);
{$IFEND}

  if not (Contest in [DARCWAEDCCW..DARCWAEDCSSB]) then
     begin
     SetMenuEnabled(menu_ctrl_qtcfunctions, False);
     end;

  (* HIDE the POTA-specific rows outside a POTA contest -- invisible rather
    than greyed, because they are irrelevant there and would only clutter the
    menu.

    Visible := False, NOT a Free. DeleteMenu removed the row from the menu
    handle; freeing the TMenuItem would leave the id index holding a dangling
    pointer, and nothing needs the row back -- as the original note says, they
    were never re-added if the operator switched contests mid-session. *)
  if Contest <> POTA then
     begin
     if MenuItemById(menu_download_pota_parks) <> nil then
        begin
        MenuItemById(menu_download_pota_parks).Visible := False;
        end;
     if MenuItemById(menu_repeat_pota_parks) <> nil then
        begin
        MenuItemById(menu_repeat_pota_parks).Visible := False;
        end;
     end;
  // if ContestsArray[Contest].e <> 0 then
  ErmakSpecification := ((ContestsBooleanArray[Contest] and (1 shl ERMAK_BIT))
    <> 0) and (RussianID(MyCall));

  if ErmakSpecification then
     begin
     SetMenuCaption(menu_cabrillo, ERMAK_);
     end;

  // AppendMenu(GetSubMenu(tr4w_main_menu, menu_rescore), MF_POPUP , 11010, 'NepItem');
  // InsertMenu(tr4w_main_menu, menu_rescore, MF_BYCOMMAND, 177, 'aa');
  (* THE MAIN WINDOW BECOMES RESIZEABLE, AND THE LOG IS WHAT GROWS.

    Everything above is unchanged: the layout is still computed from TWindows[]
    scaled by ws, which is what follows the operator's font-size setting. What
    is new is that the controls now know which edge they belong to, so the
    window can be dragged taller and the extra height goes to the log instead
    of nowhere.

    THE HEIGHT IS THE ONLY FREE DIMENSION FOR NOW. The bands are laid out in
    fixed ws-scaled columns across the full width, so a wider window would just
    add empty space on the right; the columns following the width is a separate
    piece of work. Pinning MinWidth = MaxWidth says that honestly rather than
    offering a resize that does nothing useful.

    MinHeight is the layout's own height, so the window can grow but never
    shrink far enough to eat the entry fields, which is what a bare bsSizeable
    would allow.

    THE SECOND ARGUMENT IS A CLIENT HEIGHT. The old sizing call asked for an
    OUTER height of `6 + MainWindowCaptionAndHeader + EditableLogHeight +
    ws * 14`, where MainWindowCaptionAndHeader is SM_CYMENU + SM_CYCAPTION --
    so the caption and menu terms were there to convert a client measurement
    into an outer one, and the 6 was a frame allowance for the fixed border.
    Handing over the client height directly drops both conversions and the
    assumption about how thick the frame is.

    SIZE FIRST, THEN ANCHOR, AND THE ORDER IS LOAD-BEARING. An anchor holds a
    control at a fixed DISTANCE from an edge, captured from wherever the
    control is when the parent next resizes. Every control above was just
    positioned in absolute coordinates by the ws arithmetic, for the finished
    layout -- so if the form's client height changes AFTER anchoring, each
    bottom-anchored control is dragged by that delta and lands somewhere the
    arithmetic never put it.

    The delta is near zero at the default font size, because the .lfm form
    height and the computed height agree to a pixel there. It is not zero at
    any other WindowSize, which is exactly the kind of defect that ships
    looking fine on the machine it was written on. *)
  MakeMainWindowResizeable(ws * 46, 6 + EditableLogHeight + ws * 14);
  AnchorMainWindowControls;

end;

{ Loud above this, trace below it.  A window that takes a fifth of a second
  to restore is worth a line in an ordinary log. }
const
  SLOW_WINDOW_OPEN_MS = 200;

{ THE TOOL WINDOWS.  Runs from the MESSAGE LOOP, not before it -- see
  OpenOtherWindows. }
procedure RestoreToolWindows;
var
  i: WindowsType;
  startedAt: TDateTime;
  tookMs: Int64;
begin
  for i := tw_BANDMAPWINDOW_INDEX to tw_HAMSCOREWINDOW_INDEX do  // Issue #783 -- include HamScore in restore
    if tr4w_WindowsArray[i].WndVisible then
       begin
       // TIME EACH ONE.  This whole loop logs nothing of its own, so a slow
       // start-up shows up in the log as a silent gap of seconds between the
       // band map and whatever runs next -- and "which window" then cannot be
       // answered without a rebuild.  A restored window that connects to
       // something (Telnet, a radio panel asking a rig whether it has a
       // spectrum) is exactly the kind that can block, so the loop is asked to
       // account for itself.
       startedAt := Now;
       OpenTR4WWindow(i);
       tookMs := MilliSecondsBetween(Now, startedAt);
       if tookMs >= SLOW_WINDOW_OPEN_MS then
          begin
          logger.Info('[Startup] restoring the %s window took %d ms', [WindowNames[i], tookMs]);
          end
       else if logger.IsTraceEnabled then
          begin
          logger.Trace('[Startup] restored %s in %d ms', [WindowNames[i], tookMs]);
          end;
       end;

  // THE OPERATOR TYPES IN THE CALL WINDOW, not in whatever opened last.  A
  // restored tool window is Shown, and showing a window can take the focus --
  // harmless when this ran before the message loop, but this now runs after
  // tCallWindowSetFocus has already put the caret where it belongs.
  //
  // AND BRING THE MAIN WINDOW FORWARD WHILE DOING IT, which plain
  // tCallWindowSetFocus does not.  Showing a tool window can take the
  // FOREGROUND, not just the focus; setting focus into a form that is not
  // frontmost records the intent -- ActiveControl -- and shows no caret, so
  // the operator starts typing with nowhere visible to type (NY4I,
  // 2026-08-28: 'after startup I do not know where the cursor is').
  //
  // FocusEntry keeps BringToFront opt-in because a caller that pulled TR4W
  // to the foreground mid-contest would be a new and unwelcome behaviour.
  // START-UP IS THE ONE PLACE THAT IS NOT TRUE: the operator just launched
  // the program, and the window they launched belongs in front.
  FocusEntry(TR4WCallEdit, True);
end;

{ THE MAIN WINDOW FIRST, THE TOOL WINDOWS AFTER THE LOOP IS RUNNING.

  This used to restore every tool window and only then show the main one, all
  before Application.Run -- so a window doing real work at open held the main
  window unpainted for exactly that long.  Telnet was measured at 1741 ms on
  2026-08-26 (726 cluster hosts into a combo box, since fixed), and the log
  showed it as a silent gap with nothing to name the cause.

  THE POINT IS NOT THAT TELNET WAS SLOW.  It is that the ordering made every
  future slow window a main-window delay, invisibly.  NY4I: "wouldn't you
  create the window then have the telnet thread run after the window is up?"

  So: show the main window NOW, and queue the rest.  QueueAsyncCall runs the
  restore on the main thread at the first idle moment inside Application.Run,
  which is after the main window has painted.  Not a thread -- these are
  windows, and windows belong to the thread that owns the loop. }
procedure OpenOtherWindows;
begin
  (* POSITION *AND* HEIGHT, THROUGH THE FORM.

    SWP_NOSIZE stood here because the window could not be resized, so its size
    was never worth restoring. It can be now, and an operator who drags the log
    taller expects to find it that way next time.

    Through BoundsRect, not SetWindowPos, and that is the whole reason this is
    not a two-line change: the LCL keeps its own idea of a form's bounds and
    pushes it back down when the form shows, so a raw SetWindowPos is silently
    undone. The same rule already governs every tool window.

    THE TWO SIDES MUST SPEAK THE SAME UNITS. LclFormFor now answers for the main
    window, so FindAndSaveRectOfAllWindows saves BoundsRect and this reads it
    back -- one object answering both questions, which is exactly the fix the
    note in that routine records. Saving an outer rect and restoring it as a
    client rect is what grew a window by its frame on every restart.

    THE WIDTH IS DELIBERATELY NOT RESTORED: MakeMainWindowResizeable pins it, so
    the layout decides it, not a saved file. *)
  RestoreMainWindowBounds(tr4w_WindowsArray[tw_MAINWINDOW_INDEX].WndRect);
  // ...and tell the LCL, which cannot see a raw SWP_SHOWWINDOW.  Without this
  // the form's Visible stays False and it never shows its CHILD CONTROLS --
  // which is how the callsign and exchange fields came to be created, sized and
  // positioned correctly and never drawn.
  ShowTR4WMainForm;
  QueueToolWindowRestore;
end;

(* THE HEIGHT OF THE MAIN WINDOW FONT, IN PIXELS.

  ONE CONSUMER NOW, and it is ApplyMainFontTo. The second was CreateFonts,
  which built an HFONT for the Win32 main window; that window is LCL and the
  handle was write-only, so it went on 2026-09-07 along with tCreateFont.

  The arithmetic is kept exactly as it was -- ws + 2*FontSize - 3 -- because it
  is what the operator's chosen font size has always produced, and this is now
  the only place it is written down.

  A positive lfHeight was a CHARACTER CELL height, which is what TFont.Height
  means in the LCL too, which is why the same number carried across unchanged
  when the main window stopped being a Win32 window. *)
function MainFontCellHeight: integer;
begin
   Result := ws + 2 * FontSize - 3;
end;

(* THE MAIN WINDOW FONT, AS AN LCL FONT.

  For controls the LCL draws -- the editable log is the first -- which cannot
  use the HFONT that MainFont holds. Same family, same height, same weight, so
  the log is in the typeface the operator chose for the window rather than
  whatever the control defaulted to. *)
procedure ApplyMainFontTo(aFont: TFont);
begin
   if aFont = nil then
      begin
      Exit;
      end;

   aFont.Name   := string(MainFontName);
   aFont.Height := MainFontCellHeight;

   if BoldFont then
      begin
      aFont.Style := aFont.Style + [fsBold];
      end
   else
      begin
      aFont.Style := aFont.Style - [fsBold];
      end;
end;

(* SIX FONTS WERE BUILT HERE AND ONE WAS EVER USED.

  tCreateFont IS GONE WITH THEM. It wrapped Windows.CreateFontW and added
  `FontSize - 1` to whatever height it was handed -- an adjustment that existed
  for the main window's own text, which the LCL now draws from a TFont. Five of
  its six results were write-only (see the note in VC.pas), so deleting them
  left one call, and a one-caller wrapper that silently alters its argument is
  worse than the call itself.

  WHAT AN LCL APPLICATION DOES INSTEAD, and already does here: set Name, Height
  and Style on the control's TFont. ApplyMainFontTo below is that, and
  MainFontCellHeight is the shared arithmetic. Nothing in this program should
  acquire a new HFONT.

  THE ONE THAT REMAINS IS NOT AN EXCEPTION TO THAT. LucidaConsoleFont is
  consumed only by TF.CreateRichEdit, which creates a RICHED32 window to host
  MMTTY's output -- MMTTY is a separate Windows EXE and that is a real Win32
  control, so WM_SETFONT with an HFONT is its actual API. It is gated to match
  its consumer, which is what stops this routine reaching for Windows at all
  off the platform.

  `13 + FontSize - 1` is tCreateFont's arithmetic, written out rather than
  hidden, so the size the operator sees does not change. *)
procedure CreateFonts;
begin
{$IFDEF WINDOWS}
  LucidaConsoleFont := Windows.CreateFontW(
    13 + FontSize - 1,
    0, 0, 0,
    FW_BOLD * Ord(BoldFont),
    0, 0, 0,
    DEFAULT_CHARSET,
    OUT_DEFAULT_PRECIS,
    Clip_Default_Precis,
    Default_Quality,
    DEFAULT_PITCH,
    'Lucida Console');
{$ENDIF}
end;

// Issue #20 -- shared body for Ctrl-P (short path) and Alt-Ctrl-P (long path).
// Redoes the possible-calls display, then turns the rotor either to the typed
// heading (when the Call window holds a 2-3 digit bearing) or to the last beam
// heading shown.  When longPath is True the bearing is reflected 180 degrees.
procedure RedoPossibleCallsAndTurnRotor(longPath: boolean);
var
   heading: integer;
begin
   ShowStationInformation(@CallWindowString);
   DisplayGridSquareStatus(CallWindowString);
   VisibleLog.DoPossibleCalls(CallWindowString);

   if
      (
      (length(CallWindowString) in [2, 3]) and
      (StringIsAllNumbers(CallWindowString)) and
      ((StrToIntDef(CallWindowString, 0) div 2) in [0..180])
      ) then
      begin
      heading := StrToIntDef(CallWindowString, 0);
      tCleareCallWindow;
      end
   else
      begin
      heading := LastHeadingShown;
      end;

   if longPath then
      begin
      heading := (heading + 180) mod 360;
      end;

   RotorControl(heading);
end;

// Where a downloaded TRMASTER.DTA should be written.
//
// CD.ActiveFilename is a RESOLVER RESULT, not a name to create files under.
// FCONTEST.SetUpFileNames tries, in order, TRMASTER.DTA in the contest .cfg
// directory, then TRMASTER.DTA in the working directory, and finally
// MASTER.DTA in the working directory -- the old K1EA name. When NOTHING is
// installed, which is exactly the first-run case a download serves, it holds
// that last fallback. Handing it straight to the downloader saved the file as
// `MASTER.DTA` (observed 2026-08-16). SCP would still read it, so nothing
// would have looked broken, and the operator would have a legacy-named file
// they never asked for -- plus a second copy the day they drop a real
// TRMASTER.DTA beside it.
//
// So: UPDATING replaces whatever file is actually there, whatever it is
// called; CREATING uses the canonical name, in the directory the resolver
// already chose.
function TRMasterDownloadTarget: string;
var
   resolved: string;
begin
   resolved := string(PAnsiChar(@CD.ActiveFilename));

   if SysUtils.FileExists(resolved) then
      begin
      Result := resolved;
      end
   else
      begin
      Result := SysUtils.ExtractFilePath(resolved) + 'TRMASTER.DTA';
      end;
end;

procedure ProcessMenu(menuID: integer);
var
  LowordWparam: integer;
  ID: WindowsType;
  lclForm: TCustomForm;   { the window-menu toggle asks it whether it is visible }
  focus: TWinControl;   { the control to put focus back on -- see below }
  TempCallstring: CallString;
  //http : TidHttp;
 // page : String;
begin

   (* WHICH COMMAND ARRIVED -- instrumentation 2026-09-03. The Enter
     accelerator (10651) is posted and TryLogContact is never reached;
     this says whether ProcessMenu is the link that drops it. *)
   if logger <> nil then
      begin
      logger.Debug('[Menu] ProcessMenu(%d)', [menuID]);
      end;
  LowordWparam := LoWord(menuID);

  if LowordWparam >= menu_windows_bandmap then
    if LowordWparam <= menu_windows_hamscore then  // Issue #783 -- extended past dupesheet2
       begin
       ID := WindowsType(LowordWparam - menu_windows_bandmap + 1);

       { PICKING THE MENU SHOWS THE WINDOW, ALWAYS -- it does not toggle a flag
         that may have drifted from what is on screen.

         This asked tWindowsExist, which is `WndHandle <> 0`, and that is not
         the same question as "is the operator looking at it". A form closed
         with caHide keeps its object and can keep a handle while being
         invisible, so an item the operator sees UNCHECKED could still take the
         close branch: the window stayed away, the check mark went ON, and a
         second pick was needed to get it back. NY4I, 2026-08-28, on the DX
         cluster after Escape: "Selecting the unchecked DX cluster in the window
         should ALWAYS show the window - goes for all others too."

         So: not there, or there but not visible -> show it. Only a window that
         is genuinely on screen is closed. }
       lclForm := LclFormFor(ID);
       if (not tWindowsExist(ID)) then
          begin
          OpenTR4WWindow(ID);
          end
       else if (lclForm <> nil) and (not lclForm.Visible) then
          begin
          { Exists but hidden -- the case that used to close it again. }
          lclForm.Visible := True;
          lclForm.BringToFront;
          SetMenuChecked(LowordWparam, True);
          tr4w_WindowsArray[ID].WndVisible := True;
          end
       else
          begin
          RequestCloseTR4WWindow(ID);
          end;
       Exit;
       end;

  case LowordWparam of
    menu_alt_increment_time_1..menu_alt_increment_time_0:
      begin
        IncrementTime(LowordWparam - menu_alt_increment_time_1 + 1);
      end;

    menu_options:
      RunOptionsDialog(cfAll);

    // menu_bandplan:
    // tDialogBox(44, @BMCFDlgProc);

    menu_appearance:
      RunOptionsDialog(cfAppearance);

    menu_colors:
      RunOptionsDialog(cfCol);

    // tDialogBox(61, @SettingsDlgProc2);
    // DialogBoxParam(hInstance, MAKEINTRESOURCE(61), tr4whandle, @SettingsDlgProc2, integer(cfAll));

    menu_messages: //tDialogBox(71, @MESDlgProc);
      ShowProgramMessage;

    menu_import_adif:
      begin
        ImportFromADIF;
        (*FillChar(TR4W_ADIF_FILENAME, SizeOf(TR4W_ADIF_FILENAME), 0);
        if OpenFileDlg(nil, tr4whandle, 'ADIF (*.adi)'#0'*.adi', TR4W_ADIF_FILENAME, OFN_HIDEREADONLY or OFN_ENABLESIZING or OFN_FILEMUSTEXIST) then
        begin
        if QSOTotals[All, Both] > 0 then
        if YesOrNo(TC_APPENDIMPORTEDQSOSTOCURRENTLOG) = IDno then Exit;
       // if ImportFromADIFThreadID = 0 then tCreateThread(@ImportFromADIF, ImportFromADIFThreadID);
        ImportFromADIF;
        end;
        *)
      end;

    menu_export_notes: MakeNotesList;

    // Settings -> 'CAT and CW Keying' opens the radio Preferences window, and
    // that is now the only route. The LEGACY per-slot dialog that used to sit
    // here -- two menu arms, the CATLEGACY call-window command and the
    // Ctrl+Alt+1 / Ctrl+Alt+2 accelerators -- is DELETED (2026-08-29), along
    // with uCAT.CATDlgProc and the dead uHardWare property sheet.
    //
    // Nothing was lost: the LCL editor writes a strict superset of its
    // settings, and the old one could not reach the CI-V address, startup
    // command, polling switch, frequency offset, Icom filter/data-mode bytes,
    // auto-info level, wide CW filter or the RTS/DTR lines at all. Its edits
    // also did not survive a restart once a profile was active -- the library
    // won and logged the override.
    menu_radio_preferences: ShowPreferences;

    menu_lpt:
      ShowLPTDialog;
    // tDialogBox(64, @LPTDlgProc);

    (* The old per-slot WinKeyer settings dialog was deleted 2026-09-05. It
      had no launcher -- this line, commented out -- and Preferences had
      already taken the job, which is what the live arm below does. *)
    menu_winkeyer2: RunOptionsDialog(cfWK);

    menu_alt_WkMode: // 4.60.1
      begin
        wkClose;
        wkOpen;
      end;

    //alt
    menu_alt_dupecheck: DupeCheckOnInactiveRadio(False);

    menu_alt_tooglerigs:
      begin
        ActiveRadioPtr^.tTwoRadioMode := TR0;
        InActiveRadioPtr^.tTwoRadioMode := TR0;
        SwapRadios;
        // InactiveRigCallingCQ := False;
        Str(InActiveRadioPtr.SpeedMemory, SpeedString);
        {KK1L: 6.73 Used to use a variable CheckSpeed}
      end;

    menu_alt_autocqresume:
      RunAutoCQ;

    menu_alt_SO2R_edit:
      begin
        tAltE;
        if SO2R_Swap then
           begin
           processreturn;
           end;
      end;

    menu_alt_savetofloppy:
      SaveLogFileToFloppy;

    menu_alt_swapmults:
      SwapMultDisplay;

    menu_alt_incnumber:
      tAltI;

    menu_alt_multbell:
      begin
        InvertBoolean(MultiplierAlarm);

        if MultiplierAlarm then
           begin
           DoABeep(BeepCongrats);
           end;
      end;
    menu_alt_p: OpenListOfMessages;
    menu_alt_killcw: ToggleCW(True);
    menu_alt_searchlog:
      // tDialogBox(47, @LogSearchDlgProc);
      ShowLogSearch;

    menu_alt_transfreq: tr4w_alt_n_transmit_frequency;

    menu_alt_x: ExitProgram(True);

    menu_alt_autocq:
      begin
        // if ActiveMode = CW then
        if tAutoCQMode = False then
          // tDialogBox(70, @AutoCQDlgProc);
           begin
           ShowAutoCQ;
           end;
        //QuickDisplay('Enter Time XX:YY GMT:');
        //Readln(junk);
      end;

    menu_alt_cwspeed:
      SetNewCodeSpeed;

    menu_alt_settime:
      TimeApplet(0);

    menu_alt_setnettime:
      if YesOrNo(TC_SENDTIMETOCOMPUTERSONTHENETWORK) = IDYES then
         begin
         (* TF.FillSystemTimeUTC, not Windows.GetSystemTime. Same UTC, same
           SYSTEMTIME -- VC declares that record on every platform now -- and TF
           already had this routine for its own GetTime and GetDate, so this is
           an existing helper gaining a caller rather than a new one.

           WHAT GOES ON THE WIRE IS UNCHANGED, which matters more than usual
           here: tsTime is sent as the raw bytes of a packed record to every
           other station in the multi-op, and the receiving end (uNet,
           NET_TIMESYN_ID) range-checks the fields before it sets the clock. A
           different layout, or a local-time value, would be a silent
           cross-version protocol break rather than a visible failure. *)
         TF.FillSystemTimeUTC(NetTimeSync.tsTime);
         SendToNet(NetTimeSync, SizeOf(NetTimeSync));
         end;

    menu_alt_flushlogtodisk:
      begin
        // MoveEditableLogIntoLogFile;
        UpdateTotals2;
      end;

    menu_alt_deleteqso:
      begin
        DeleteLastContact;
        LastTwoLettersCrunchedOn := '';
      end;

    menu_alt_initialexhange:
      begin
        LOGSUBS2.DoAltZ();
      end;

    menu_alt_tooglesidetone:
      tr4w_toggle_sidetone;

    menu_alt_toogleautosend:
      begin
        if AutoSendCharacterCount > 0 then
           begin
           InvertBoolean(AutoSendEnable);
           end;
        DisplayAutoSendCharacterCount;
      end;

    menu_alt_bandup:
      begin
        RememberFrequency;
        LastDisplayedBand := NoBand; // Force DisplayBandMode to always call SetRadioFreq
        BandDownOrUp(DirectionUp);
        ShowInformation;
      end;

    menu_alt_banddown:
      begin
        RememberFrequency;
        LastDisplayedBand := NoBand; // Force DisplayBandMode to always call SetRadioFreq
        BandDownOrUp(DirectionDown);
        ShowInformation;
      end;

    menu_alt_ssbcwmode:
      begin
        RememberFrequency;
        ToggleModes;
        DisplayAutoSendCharacterCount;
        ShowInformation;
        VisibleLog.ShowQSOStatus(@CallWindowString);
        ShowFMessages(0);
      end;

    menu_ctrl_trpath:
      begin
        quickdisplay(tr4w_path_name);
      end;

    menu_ctrl_ptt: // 4.53.9
      begin
        if PTT_Set then
           begin
           PTTOFF;
           PTT_Set := False;
           end
        else
           begin
           PTTON;
           PTT_Set := True;
           end;
      end;

    menu_ctrl_sendkeyboardinput:
      // if (ActiveMode = CW) or (ActiveMode = Digital) then
      begin
        // Issue #1006: if a Send Keyboard Input dialog is already open, do not
        // open a second one. Clicking a (send from keyboard) function-key button
        // re-enters here while the dialog is up -- the modal disables only the
        // main window, not the function-key window -- and the nested modal plus
        // the single SendKeyboardWindow handle leaves the dialog unclosable.
        if SendKeyboardInputDialogOpen then Exit;
        (* PUT FOCUS BACK AFTER THE MODAL, ASKED OF THE LCL.

          Was GetFocus into an HWND and SetFocus(handle) afterwards. That
          restores the native focus window; Screen.ActiveControl restores the
          CONTROL the LCL believes is focused, which is what everything else in
          this program reads. Nil is possible -- nothing focused -- and
          assigning nil back is a no-op, so no guard is needed. *)
        focus := Screen.ActiveControl;
        if ActiveMode = CW then
          if not Config.CWEnable then
             begin
             logger.Warn('Trying menu_ctrl_sendkeyboardinput while CWEnable is false');
             Exit;
             end;
        { The send-keyboard box is parented on whichever window asked for it.
          BOTH QTC windows are LCL forms now, so ShowModalOverWin32Parent's
          Screen.DisableForms covers them and there is no raw HWND left to name
          -- the main window is the only parent this call has. }
        // DialogBox(hInstance, MAKEINTRESOURCE(60), tCardinal, @SendKeyboardCWDlgProc);
        ShowSendKeyboardCW;
        { focus.SetFocus, not Screen.ActiveControl := -- that property is
          read-only in the LCL; the control focuses itself. }
        if (focus <> nil) and focus.CanFocus then
           begin
           focus.SetFocus;
           end;
      end;
    // tDialogBox(60, @SendKeyboardCWDlgProc);

    menu_ctrl_cleardupesheet:
      tClearDupesheet_Ctrl_K;

    menu_ctrl_viewlogdat:
      // tDialogBox(74, @LogEditDlgProc);
      (* The LCL form, not the Win32 dialog -- see uLogEditForm. *)
      ShowLogEditForm;

    menu_ctrl_note:
      tr4w_add_note_in_log;

    menu_ctrl_redoposscalls:
      begin
        RedoPossibleCallsAndTurnRotor(False);   // Ctrl-P -- short path
      end;

    menu_alt_ctrl_redoposscalls:                // Issue #20
      begin
        RedoPossibleCallsAndTurnRotor(True);    // Alt-Ctrl-P -- long path
      end;

    menu_ctrl_qtcfunctions:
      begin

        WAEQTC2;
        DisplayTotalScore;
        UpdateTotals2;
        // FrmSetFocus;
        tCallWindowSetFocus;

      end;

    menu_ctrl_recalllastentry:

      if EscapeDeletedCallEntry <> '' then
         begin
         PutCallToCallWindow(EscapeDeletedCallEntry);
         end;

    menu_ctrl_refreshbandmap:
      begin
        if TR4WBandMapForm <> nil then
           begin
           TR4WBandMapForm.grdSpots.SetFocus;
           end;
      end;

    menu_ctrl_cursorinbandmap:
      begin
        // BandMapSettingFocus bracketed this call to stop DefDlgProc's
        // WM_ACTIVATE handling firing a nested SetFocus that immediately
        // produced LBN_KILLFOCUS, which stole the focus straight back
        // (issue #861).  There is no DefDlgProc and no LBN_KILLFOCUS now --
        // the LCL owns focus for a control on a form -- so the guard goes with
        // the thing it was guarding against.
        if TR4WBandMapForm <> nil then
           begin
           TR4WBandMapForm.grdSpots.SetFocus;
           end;
      end;

    menu_ctrl_cursorintelnet:
      begin
        { WAS: SetFocus on a raw handle, then LB_GETCURSEL / LB_GETTOPINDEX /
          LB_GETCOUNT / LB_SETCURSEL to work out where to put the selection.
          The view says what those four were asking for. }
        if not TelnetConsoleHasFocus then
           begin
           TelnetFocusConsole;
           if TelnetConsoleSelectForEntry then
              begin
              ActiveMainWindow := awUnknown;
              end;
           end
        else
           begin
           FrmSetFocus;
           end;
        Exit;
      end;

    menu_ctrl_incAQSLinterval:
      if AutoQSLInterval < 6 then
         begin
         inc(AutoQSLInterval);
         AutoQSLCount := AutoQSLInterval;
         DisplayAutoQSLInterval;
         end;

    menu_ctrl_decAQSLinterval:
      if AutoQSLInterval > 0 then
         begin
         dec(AutoQSLInterval);
         AutoQSLCount := AutoQSLInterval;
         DisplayAutoQSLInterval;
         end;

    menu_ctrl_showCallsign:
      begin
        if CallWindowString <> '' then
           begin
           TF.Format(wsprintfBuffer, 'Callsign %s', @CallWindowString[1]);
           ShowMessage(wsprintfBuffer);
           end
        else
           begin
           ShowMessage('Empty');
           end;
      end;

    menu_ctrl_showSpeed:
      begin
        if ActiveMode = CW then
           begin
           TF.Format(wsprintfBuffer, 'Speed %u', CodeSpeed);
           ShowMessage(wsprintfBuffer);
           end;
      end;

    menu_ctrl_showBand:
      begin
        TF.Format(wsprintfBuffer, 'Band %s',
          BandStringsArrayWithOutSpaces[ActiveBand]);
        ShowMessage(wsprintfBuffer);
      end;

    menu_ctrl_showQSONumber:
      begin

        TF.Format(wsprintfBuffer, 'QSO number %u', TotalContacts);
        ShowMessage(wsprintfBuffer);
      end;

    menu_ctrl_logqsowithoutcw:
      tr4w_log_qso_without_cw;

    menu_ctrl_sendspot:
      // if TelnetSock <> 0 then
      // tDialogBox(59, @SendSpotDlgProc);
      ShowSendSpot;

    menu_ctrl_clearmultsheet:
      begin
        ClearMultSheet_CtrlC;
      end;

    menu_send_message:
      begin
        NetIntercomMessage.imSender := ComputerID;
        FillChar(NetIntercomMessage.imMessage, SizeOf(NetIntercomMessage.imMessage), 0);
        tInputDialogLowerCase := True;
        NetIntercomMessage.imMessage :=
          QuickEditResponse(TC_MESSAGETOSENDVIANETWORK, 80);
        if NetIntercomMessage.imMessage <> '' then
           begin
           SendToNet(NetIntercomMessage, SizeOf(NetIntercomMessage));
           end;
      end;

    menu_ctrl_ct1bohscreen:
      // tDialogBox(40, @ct1bohDlgProc);
      ShowCT1BOHInfo;

    menu_ctrl_PlaceHolder: AddBandMapPlaceHolder;

    menu_mainwindow_setfocus: FrmSetFocus;

    menu_insertmode: InvertBooleanCommand(@InsertMode);

    menu_ctrl_SplitOff: // n4af 4.47.5
      tr4w_alt_n_transmit_frequency;

    menu_escape:
      Escape_proc;

    menu_csv:
      ExportToCSV;

    menu_inactiveradio_cwspeedup:
      if InActiveRadioPtr.SpeedMemory < (99 - Config.CodeSpeedIncrement) then
         begin
         inc(InActiveRadioPtr.SpeedMemory, Config.CodeSpeedIncrement);
         end;

    menu_inactiveradio_cwspeeddown:
      if InActiveRadioPtr.SpeedMemory > (Config.CodeSpeedIncrement + 1) then
         begin
         dec(InActiveRadioPtr.SpeedMemory, Config.CodeSpeedIncrement);
         end;

    menu_cwspeedup:
      begin
        if tAutoCQMode = True then
           begin
           inc(AutoCQDelayTime, 500);
           tDisplayAutoCQStatus;
           Exit;
           end;
        if ActiveMode = CW then
           begin
           SpeedUp;
           end;
      end;

    menu_cwspeeddown:
      begin
        if tAutoCQMode = True then
           begin
           if AutoCQDelayTime > 500 then
              begin
              dec(AutoCQDelayTime, 500);
              end;
           tDisplayAutoCQStatus;
           Exit;
           end;
        if ActiveMode = CW then
           begin
           SlowDown;
           end;
      end;

    //C:\>w32tm /config /syncfromflags:manual /manualpeerlist:ntp5.tamu.edu
    //C:\>w32tm /config /update

    // menu_get_offset:
    // WinExec('w32tm /stripchart /computer:pool.ntp.org /dataonly /samples:5', SW_NORMAL);

    // WinExec('cmd.exe /k start /b "w32tm /stripchart /computer:pool.ntp.org /dataonly /samples:5"', SW_NORMAL);
    //'cmd.exe /k start /b ????\conp.exe'

    // WinExec('w32tm /resync', SW_NORMAL);
    //w32tm /resync
    // w32tm /stripchart /computer:pool.ntp.org /dataonly /samples:1

    menu_beaconsmonitor:
      // tDialogBox(49, @BeaconsMonitorDlgProc);
      ShowBeaconsMonitor;

    // menu_COAX_Length_Calculator:
    // tDialogBox(51, @COAX_Length_CalculatorDlgProc);

    // menu_Distance:
    // tDialogBox(53, @DistanceDlgProc);

    // menu_Grid:
    // tDialogBox(55, @GridDlgProc);

    // menu_lc:
    // tDialogBox(56, @LCDlgProc);

    item_calculator: RunWindowsUtility('calc.exe');

    menu_reset_radio_ports:
      begin
        ResetRadioPorts;
        {logger.info('Resetting radio ports');
        if ActiveRadioPtr.tFactoryObject <> nil then
           begin
           ActiveRadioPtr.tFactoryObject.Disconnect;
           ActiveRadioPtr.tFactoryObject.Connect;
        end;

        ActiveRadioPtr.CheckAndInitializePorts_ForThisRadio;
        //
        // Handle radio two
        //
        if InActiveRadioPtr.tFactoryObject <> nil then
           begin
           InActiveRadioPtr.tFactoryObject.Disconnect;
           InActiveRadioPtr.tFactoryObject.Connect;
           end
         else if InActiveRadioPtr.tFactoryObject <> nil then
            begin
            InActiveRadioPtr.tFactoryObject.Disconnect;
            InActiveRadioPtr.tFactoryObject.Connect;
            end;

         InActiveRadioPtr.CheckAndInitializePorts_ForThisRadio;
         }
      end;

    menu_pingserver:
      begin
        // Windows ping: -w and -n are its spelling of timeout and count.
        RunWindowsUtility(SysUtils.Format('ping %s -w 2000 -n 10',
                                          [string(ServerAddress)]));
      end;

    menu_runserver:
      begin
        // OUR program, so RunProgram -- it is meaningful on every platform
        // and needs no Windows guard.
        RunProgram(string(TR4W_PATH_NAME) + 'server\tr4wserver.exe', []);
      end;

    menu_windowsmanager:
      begin
        //tDialogBox(57, @WindowsManagerDlgProc);
        ShowWindowsManager;
        if ManageForm = nil then
           begin
           Exit;
           end;

        (* $313 IS AN UNDOCUMENTED MESSAGE AND IS LEFT ALONE ON PURPOSE.

          It appears exactly once in the tree, as a bare number, with no name
          and no comment: SendMessage(wnd, $313, 0, MakeLong(Left, Top + 20)).
          It is not any documented window message -- 0x0313 falls in the gap
          between WM_HOTKEY (0x0312) and WM_PRINT (0x0317) -- so what it is
          meant to do here cannot be read off the code, and guessing at an LCL
          equivalent (ManageForm.Top := ... + 20, say) would be inventing
          behaviour rather than porting it.

          The HANDLE PLUMBING around it is converted -- the dialog hands back a
          form now -- so this is the only thing left, derived at the one call
          that needs it. It wants an operator who knows what this feature is
          supposed to do, not a reader of the source. *)
{$IFDEF WINDOWS}
        (* $313 IS AN UNDOCUMENTED MESSAGE and that is precisely why it is
          gated rather than translated: nobody here knows what the receiving
          window does with it, so there is nothing to reimplement.  It wants an
          operator who knows what this feature is supposed to do. *)
        Windows.GetWindowRect(ManageForm.Handle, tr4w_TempRect);
        SendMessage(ManageForm.Handle, $313, 0, MakeLong(tr4w_TempRect.Left,
          tr4w_TempRect.Top + 20));
{$ENDIF}
        FrmSetFocus;
      end;

    menu_volume_control: RunWindowsUtility('SNDVOL32.EXE');
    menu_recording_control: RunWindowsUtility('SNDVOL32.EXE -r');
    // menu_soundrecorder: WinExec('SNDREC32.EXE', SW_SHOWNORMAL);

    // TYPED, not `integer(@Proc)` through an lParam.  The window took an
    // untyped Pointer and called it back, so nothing checked that what OK ran
    // was a parameterless procedure -- the compiler could not have noticed a
    // mismatch here.
    menu_cabrillo: OpenStationInformationWindow(CreateCabrilloFile);
    menu_summary: OpenStationInformationWindow(SummarySheet);
    menu_3830scores: ExportTo3830Scores;  // Issue: 3830 quick-submission report
    menu_edit_cabrillo_summary: OpenStationInformationWindow(nil);  // Issue #914
    menu_export_edi: OpenStationInformationWindow(ExportToEDI);

    menu_scorebyhour: ScoreByHour;
    menu_continentlist: ContinentReport;
    menu_qsobycountry:
      {ShowReport(rtQSOsByCountryByBand);//}QSOsByCountryByBand;
    menu_adif: ExportToADIF;

    menu_trlog:
      begin
        if EscapeDeletedCallEntry <> '' then
           begin
           PutCallToCallWindow(EscapeDeletedCallEntry);
           end;
      end;

    menu_initial_ex_list:
      begin
        MakeReportFileName('CUSTOM_INITIAL.EX');
        GenerateCallsignsList(@ReportsFilename[1]);
        FilePreview;
      end;
    menu_allcallsigns_list: MakeAllCallsignsList;
    menu_first_call_work_ineachcountry:
      {ShowReport(rtFirstCountry);//}tFirstCallInEachCountry;
    menu_first_call_work_InEachZone:
      {ShowReport(rtFirstZone);//}tFirstCallInEachZone;

    // menu_POSSIBLEBADZONE: ZoneReport;

    menu_band_changes: BandChangeReport;

    menu_log_file_properties:
      RunExplorer(@TR4W_LOG_PATH_NAME);

    menu_exit: ExitProgram(True);

    menu_clear_log:
      if YesOrNo(TC_REALLYWANTTOCLEARTHELOG) = IDYES then
         begin
         ClearLog;
         end;

    // A DESIGNED FORM, not a MessageBox.  MessageBox does not exist off Windows,
    // and a message box cannot be opened in the designer by anyone who wants to
    // change what About says.  Same content, assembled from the same constants,
    // with the website as a clickable link.  See src/ui/lcl/uAboutForm.pas.
    menu_about:
      ShowAboutBox;

    // menu_send_bug: SendMail('tr4w@qrz.ru', True);

    menu_historytxt:
      begin
        // Issue #986 -- open in the system default text editor, not Notepad.
        TF.Format(wsprintfBuffer, '%shistory.txt', TR4W_PATH_NAME);
        OpenInDefaultTextEditor(wsprintfBuffer);
      end;

    menu_wiki_rus:
      OpenUrl('http://www.tr4w.com/wiki/');

    menu_home_page:
      OpenUrl('https://tr4w.net/'); // n4af 04.42.5

    menu_download_latest_cty_dat:
      begin
      QuickDisplay(PAnsiChar(TC_DOWNLOADINGCTYDAT));
      DownloadCTYAsync(string(PAnsiChar(@TR4W_CTY_FILENAME)),
        BackgroundEvents.CTYDownloadFinished);
      end;

    // CHECK FOR UPDATES.  uCheckLatestVersion has existed complete, with a
    // download link and a translated prompt, since the D7 days and had NO
    // CALLER -- the only route to it was inside a brace-commented block.  NY4I
    // asked for it on the Help menu (2026-08-22), after the bench queue sent him
    // looking for an option that did not exist.
    //
    // ONE KNOWN DEFECT REMAINS IN WHAT THIS CALLS, flagged rather than silently
    // shipped and recorded in docs/BENCH_QUEUE.md: it does its socket work ON
    // THIS THREAD and sleeps 2 seconds waiting for the reply, so the UI freezes
    // for at least that long.  NY4I's own standing rule is no I/O on the main
    // thread.  Wiring it up was the request; rewriting it is the follow-up, and
    // doing both at once would mean a bench failure could not be attributed.
    menu_check_latest_version:
      begin
      CheckLatestVersion;
      end;

    menu_download_trmaster:
      begin
      QuickDisplay(TC_DOWNLOADINGTRMASTERDTA);
      DownloadTRMasterAsync(TRMasterDownloadTarget,
        BackgroundEvents.TRMasterDownloadFinished);
      end;

    menu_download_pota_parks:
      begin
      QuickDisplay(TC_DOWNLOADINGPOTAPARKS);
      DownloadPOTAParksAsync(POTAParksFilePath,
        BackgroundEvents.PotaDownloadFinished);
      end;

    menu_repeat_pota_parks:
      HandleRepeatPOTAParks;

    menu_hamscore_resync:                 // Issue #783 Phase 3
      begin
      QuickDisplay(TC_HAMSCOREQUEUEINGFULLLOGRESYNC);
      HamScoreResyncFromScratch;       // enqueue <deletelog>
      SendFullLogToHamScore;           // enqueue every QSO from the binary log
      end;

    menu_spmode_ortab:
      ProcessTAB(LowordWparam);

    menu_cqmode: SetOpMode(CQOpMode);
    tr4w_accelerator_vkreturn: ProcessReturn;

    // menu_alt_resetwakeup:
    // WakeUpCount := 0;
    menu_alt_init_qso: InitializeQSO;

    menu_settimezone:
      TimeApplet(1);

    menu_rescore:
      begin
        tUpdateLog(actRescore);
        LoadinLog;
      end;

    //tLoadinLog({True, }True);
    // RunRescoreDialog(UPDATEALLQSOS);

    // menu_fast_rescore: RunRescoreDialog(FASTRESCORE);

    menu_login:
      begin
        FillChar(TempCallstring, SizeOf(TempCallstring), 0);
        TempCallstring := QuickEditResponse(TC_CURRENT_OPERATOR_CALLSIGN, 6);
        if length(TempCallstring) > 0 then
           begin
           // A US-looking call is held to the stricter US form; anything else
           // only has to be a good callsign. Same two tiers as before, with
           // the regexes replaced by uCallSignRoutines -- see IsAGoodCall.
           if IsAUSPrefix(TempCallString) then
              begin
              if IsAGoodUSCall(TempCallString) then
                 begin
                 Move(TempCallstring[1], CurrentOperator, 6);
                 TR4WMainForm.pnlCurrentOperator.Caption := CurrentOperator;
                 Sheet.SaveRestartFile; // Issue 661 ny4i
                 SendStationStatus(sstOperator);
                 end
              else
                 begin
                 ShowMessage(TC_LOGINCALLDOESLOOKLIKECALLSIGN);
                 end;
              end
           else if IsAGoodCall(TempCallString) then
              begin
              Move(TempCallstring[1], CurrentOperator, 6);
              TR4WMainForm.pnlCurrentOperator.Caption := CurrentOperator;
              Sheet.SaveRestartFile; // Issue 661 ny4i
              SendStationStatus(sstOperator);
              end
           else
              begin
              ShowMessage(TC_LOGINCALLDOESLOOKLIKECALLSIGN);
              end;
           end;
        // ShowMessage(CurrentOperator);
      end;

    menu_getserverlog:
      SendToNet(NET_LOGINFO_MESSAGE, SizeOf(NET_LOGINFO_MESSAGE));
    // tDialogBox(73, @GetServerLogDlgProc);

    menu_clearserverlog:
      begin
        tInputDialogWarning := True;
{$IF NOT tDebugMode}
        if QuickEditResponse(TC_CLEARALLLOGS, 12) = 'CLEARALLLOGS' then
{$IFEND}

        begin
          ServerMessage.smMessage := SM_CLEARALLLOGS_MESSAGE;
          SendToNet(ServerMessage, SizeOf(ServerMessage));
        end;
      end;

    menu_clear_dupesheet_in_network:
      begin
        tInputDialogWarning := True;
{$IF NOT tDebugMode}
        if QuickEditResponse(TC_CLEAR_DUPESHEET_NET, 14) = 'CLEARDUPESHEET' then
{$IFEND}
        begin
          ServerMessage.smMessage := SM_CLEAR_DUPESHEET_MESSAGE;
          SendToNet(ServerMessage, SizeOf(ServerMessage));
        end;
      end;

    menu_clear_multsheet_in_network:
      begin
        tInputDialogWarning := True;
{$IF NOT tDebugMode}
        if QuickEditResponse(TC_CLEAR_MULTSHEET_NET, 14) = 'CLEARMULTSHEET' then
{$IFEND}
        begin
          ServerMessage.smMessage := SM_CLEAR_MULTSHEET_MESSAGE;
          SendToNet(ServerMessage, SizeOf(ServerMessage));
        end;
      end;

    // menu_compare_logs: SendToNet(NET_LOGINFO_MESSAGE, SizeOf(NET_LOGINFO_MESSAGE));

  {  menu_wa7bnm_calendar:
      OpenUrl('http://www.hornucopia.com/contestcal/weeklycont.php');
    // Shellexecute(0, 'open', 'http://www.hornucopia.com/contestcal/weeklycont.php', nil, nil, SW_NORMAL); // 4.75.3
    {begin
    http := TidHttp.Create(nil);
    try
    page := http.get('http://www.hornucopia.com/contestcal/weeklycont.php');
    finally
    http.Free;
    end;
    end;
    }
    // THROUGH OpenUrl, which is what the commented-out line above each of
    // these already said.  Four menu items had grown their own ShellExecute
    // beside a disabled call to the helper -- so the helper had six callers and
    // four bypassers, and only the callers would have been fixed by a change to
    // it.  Phase 8: ShellExecute has no Mac or GTK equivalent; LCLIntf.OpenURL
    // does, and it now lives in exactly one place.
    menu_3830_scores_posting: // 4.51.8
      OpenUrl('http://www.3830scores.com/');

    menu_arrl_submit: // 4.53.3
      OpenUrl('http://contest-log-submission.arrl.org/');

    menu_qrzru_calendar:
      begin
        OpenUrl(SysUtils.Format('http://www.qrz.ru/contest/detail/%d.html',
                                [ContestsArray[Contest].QRZRUID]));
      end;

    menu_WA7BNM_calendar:
      begin
        OpenUrl(SysUtils.Format('https://contestcalendar.com/contestdetails.php?ref=%u',
                                [ContestsArray[Contest].WA7BNM]));   // 4.127.1

      end;

    menu_ctrl_execute_config: // 4.67.5
      begin
        if OpenFileDlg('', TC_CONFIGURATION_FILE + ' (*.cfg)|*.cfg',
                       TR4W_EXECONFIGFILE_FILENAME, False) then
          // TR4W_EXECONFIGFILE_FILENAME is a NUL-terminated AnsiChar array, NOT
          // a ShortString.  The ShortString() variable cast that used to be here
          // reinterpreted the path's FIRST CHARACTER as the length byte -- 'C'
          // gave length 67 -- so the pointer happened to land right while the
          // length was garbage.  Both GetRidOfPrecedingSpaces and
          // OpenFileForRead_old inside LoadInSeparateConfigFile use that length.
           begin
           ExecuteConfigurationFile(PAnsiChar(@TR4W_EXECONFIGFILE_FILENAME[0]));
           end;
      end;

    menu_ctrl_shdxcallsign:
      begin
        FillChar(TempCallstring, SizeOf(TempCallstring), 0);
        if CallWindowString <> '' then
           begin
           TempCallstring := CallWindowString
           end
        else
           begin
           TempCallstring := VisibleLog.LastEntry(False, letCallsign);
           end;

        if TempCallstring <> '' then
           begin
           TF.Format(wsprintfBuffer, 'SH/DX %s 5', @TempCallstring[1]);
           SendViaTelnetSocket(wsprintfBuffer);
           end;
      end;

  end;
end;

procedure ProcessTAB(lowparam: Word);
begin
  (* Was guarded by the NOT arm of the MorseRunner switch -- the arm that
    actually compiled. MorseRunner is gone, so this is simply what ProcessTAB
    does. *)
  if lowparam = menu_spmode_ortab then
    if OpMode = CQOpMode then
       begin
       SetOpMode(SearchAndPounceOpMode);
       Exit;
       end;

  // ChangeFocus('ProcessTAB');

  if ActiveMainWindow = awCallWindow then
     begin
     tExchangeWindowSetFocus
     end
  else if ActiveMainWindow = awExchangeWindow then
     begin
     tCallWindowSetFocus;
     end;
  {
  if tr4w_CallWindowActive then
  begin
  tExchangeWindowSetFocus;
  tr4w_CallWindowActive := False;
  end
  else
  if tr4w_ExchangeWindowActive then
  begin
  tCallWindowSetFocus;
  tr4w_CallWindowActive := True;
  end
  }
end;

procedure ProcessKeyDownTerm; // 4.46.2
begin
  if activeradioptr^.cwbycat and autosendenable and Config.AutoCallTerminate then
    if length(CallWindowString) = AutoSendCharacterCount then
       begin
       tExchangeWindowSetFocus;
       tSetExchWindInitExchangeEntry;
       CheckAndSetInitialExchangeCursorPos;
       processreturn;
       end;
end;

procedure ProcessReturn;
var
  revnr: string[6];

label
  SetFreq;
begin

   (* instrumentation 2026-09-03 -- see ProcessMenu above. *)
   if logger <> nil then
      begin
      logger.Debug('[Menu] ProcessReturn entered');
      end;
  tDispalyOnAirTime;

  // ENTER IN THE TELNET COMMAND BOX SENDS.  Was a GetParent comparison against
  // the combo's raw handle -- a combo box being two windows is why the parent
  // and not the handle itself -- followed by a synthesised WM_COMMAND 104.
  if TelnetCommandHasFocus then
     begin
     // Was `TelnetSock <> 0`.  The raw socket handle is gone; ask uTelnet
     // whether the cluster link is up (uDXClusterClient owns the socket).
     if TelnetIsConnected and Assigned(TelnetFormOnSend) then
        begin
        TelnetFormOnSend;
        end;
     Exit;
     end;

  // ENTER IN THE BAND MAP TUNES THE RADIO.  This used to PostMessage a
  // hand-assembled WM_COMMAND -- 131173 is LBN_DBLCLK in the high word and the
  // list box's control id in the low word -- so the band map's dialog proc
  // would run its double-click arm.  Synthesising a notification in order to
  // reach a routine is a Win32 idiom for "I have no way to call that"; the form
  // exposes the action.
  (* DOES THE SPOT GRID HAVE FOCUS? Asked of the LCL.

    Was `Windows.GetFocus` into a TempHWND, compared against
    grdSpots.Handle -- a native handle pulled back out of an LCL control to be
    matched against another one. Screen.ActiveControl is the same question with
    no handle at either end, and it is what the LCL keeps up to date. *)
  if (TR4WBandMapForm <> nil) and
     (Screen.ActiveControl = TR4WBandMapForm.grdSpots) then
     begin
     TR4WBandMapForm.SpotsDblClick(nil);
     Exit;
     end;

  // ENTER ON A CONSOLE LINE TUNES TO IT, and it is the same action the double
  // click runs.  This used to PostMessage a hand-assembled WM_COMMAND -- 131173
  // is LBN_DBLCLK in the high word over the list box's control id -- to reach
  // the dialog procedure's double-click arm.  Same idiom the band map shed just
  // above, and for the same reason: synthesising a notification in order to
  // reach a routine means there was no way to call it.
  if TelnetConsoleHasFocus then
     begin
     if (TelnetConsoleSelected >= 0) and Assigned(TelnetFormOnConsoleDblClick) then
        begin
        TelnetFormOnConsoleDblClick(TelnetConsoleSelected);
        end;
     Exit;
     end;

  // if tr4w_ExchangeWindowActive = False then if tr4w_CallWindowActive = False then
  (* The grid raises its own OnDblClick -- see TTR4WMainForm.MainLogDblClick.
    This arm tested a window handle against the log's, and there is no handle
    to test. *)

  // check if membership # entered
  // n4af 4.67.2 check for reverse lookup of membership #
  // 4.67.3 look for member # in trmaster.asc
  if (CallWindowString[1]) = 'R' then
     begin
     RevNr := copy(CallWindowString, 2, length(callwindowstring) - 1);
     if StringIsAllNumbers(RevNr) then
        begin
        if not CallsignsList.FindNumber(RevNr) then
           begin
           exit;
           end;
        PutCallToCallWindow(CallWindowString);
        exit;
        end;
     end;
  SetFreq:
  if TuneOnFreqFromCallWindow then
     begin
     Exit;
     end;
  if CallWindowString = 'TXON' then
     begin
     logger.debug('Calling tPTTVIACAT with true');
     tPTTVIACAT(true);
     end
  else if CallWindowString = 'TXOFF' then
     begin
     tPTTVIACAT(false);
     end;
  if (ActiveExchange = RSTDomesticQTHExchange) then
    if (CallWindowString <> '') and (ExchangeWindowString <> '') then
       begin
       ParseFourFields(ExchangeWindowString, s1, s2, s3, s4);
       end;
  {    if S3 <> '' then
       begin
        ExchangeWindowString := S3

      }
  if OpMode = CQOpMode then
     begin
     ctyGetCountryID(callwindowstring);
     if SwitchNext then //4.52.3
        begin
        if (CallWindowString <> '') then // 4.92.2
           begin
           SwitchNext := False; // 4.92.2
           Switch := False;
           // B1: ask the ACTIVE keyer (was WKBusy or CWThreadID -- CAT and YCCC
           // were simply missing here, so a CQ advance could interrupt CW they
           // were still sending).  4.52.4 issue 192
           if CWStillBeingSent then
              begin
              FlushCWBuffer;
              ReturnInCQOpMode;
              exit;
              end
           else
              begin
              swapradios;
              end;
           if (AutoSendEnable) and (AutoSendCharacterCount > 0) then
              begin // end 4.52.4
              SwapRadios;
              InactiveRigCallingCQ := False;
              end;
           end;
        end;

     if switch = False then // n4af 4.44.7
        begin
        InactiveRigCallingCQ := False // n4af 4.42.11
        end
     else
        begin
        if autosendenable then // n4af 4.44.7
           begin // do not swap yet if autosend
           switch := False;
           ReturnInCQOpMode;
           exit;
           end;
        checkinactiverigcallingcq;
        Switch := False;
        if CallWindowString = '' then // 4.52.3
           begin
           SwitchNext := False;
           end;
        // exit;
        end;
     ReturnInCQOpMode;
     Exit;
     end;

  if OpMode = SearchAndPounceOpMode then
     begin
     ReturnInSAPOpMode;
     // Exit;
     end;

end;

procedure RepeatLastCWMessage;
   // '=' repeat-last-CW-message: replay the exact characters last sent on CW.
   // Centralized so it works in both the call and exchange windows -- it is
   // dispatched from the main message loop (tr4w.lpr), the same way the
   // function keys are, rather than from a single window's key handler.
begin
   if LastCWMessage <> '' then
      begin
      AddStringToBuffer(LastCWMessage, Config.CWTone);
      if IsCWByCATActive then
         begin
         AddStringToBuffer(CWByCATBufferTerminator, Config.CWTone);
         end;
      end;
end;

procedure CallWindowKeyDownProc(wParam: integer);
var
  Key: Char;
  itempos: integer;
label
  wait;
begin
  CallWinKeyDown := True; // 4.52.4
  CallsignIsTypedByOperator := True;
  Key := Char(wParam);
  logger.trace('[CallWindowKeyDownProc] Key pressed = ' + key);
  if tAutoCQMode then
    if TryKillAutoCQ then
       begin
       Escape_proc;
       end;

  if key = '-' then
     begin
     tr4w_alt_n_transmit_frequency; // Note this is a toggle
     tCleareCallWindow;
     CallWindowCharConsumed := True; // prevent WM_CHAR from inserting '-' into the cleared field
     Exit;
     end;

  // '=' repeat-last-CW-message is handled centrally in the main message loop
  // (tr4w.lpr WM_CHAR) so it works in both the call and exchange windows.
  // start sending now code
  if Key = StartSendingNowKey then
    if tAutoSendMode = False then
      if OpMode = CQOpMode then
        if ActiveMode = CW then
          if CallWindowString <> '' then
            // if (not StringHas(CallWindowString, '/')) then
             begin
             if MessageEnable then
                begin
                CheckInactiveRigCallingCQ;
                DebugMsg('[CallWindowKeyDownProc] Call AddStringToBuffer with ' +
                  CallWindowString);
                AddStringToBuffer(CallWindowString, Config.CWTone);
                if IsCWByCATActive then
                   begin
                   DebugMsg('[CallWindowKeyDownProc] Calling AddStringToBuffer with CWByCATBufferTerminator');
                   AddStringToBuffer(CWByCATBufferTerminator, Config.CWTone);
                   end;
                // PTTForceOn;
                tAutoSendMode := True;
                end;
             end;
  // autosend code here
  if (tAutoSendMode = True) then
     begin
     if Key = BackSpace then
        begin
        if EditingCallsignSent then
           begin
           // if length(CallWindowString) > 0 then
          { begin
        // Delete(CallWindowString, length(CallWindowString), 1);
        end }
           end

        else if (CWEnabled and DeleteLastCharacter) or not CWEnabled then
           begin
           end
        else
           begin
           logger.trace('[CallWindowKeyDownProc] Calling AddStringToBuffer with !');
           AddStringToBuffer('!', Config.CWTone);
           EditingCallsignSent := True;
           end;

        end
     else
        begin
        if Key <> StartSendingNowKey then
           begin
           // B2: the three-way keyer branch that stood here (CAT sends the char
           // plus its terminator, WinKeyer sends UpCase'd, CPU buffers the raw
           // char) is now the adapters' SendChar bodies, each preserved verbatim
           // -- including the YCCC oddity that autosend chars go to the CPU keyer
           // because no YCCC arm ever existed here (quirk Q4).
           ActiveCWKeyer.SendChar(Key);
           end;
        EditingCallsignSent := False;
        end;
     end;
  if (SwitchNext {and (CallWindowString<>'')} and CWStillBeingSent) then
    // B1: was (CWThreadID <> 0) or wkBUSY or ActiveRadioPtr.CWByCAT_Sending;
    // now the active keyer only -- adds YCCC, and a stale latch on an
    // unselected backend no longer blocks the swap.  4.52.10
     begin
     FlushCWBuffer;
     SwapRadios;
     logger.trace('[CallWindowKeyDownProc] SwapExit');
     exit;
     end;
  // CallsignsList.CreatePartialsList(CallWindowString);
  if not InsertMode then
     begin
     // OVERTYPE: select the character under the caret, so the next keystroke
     // replaces it instead of being inserted before it.  This was
     // EditSetSelLength on wh[mweCall] -- EM_GETSEL, EM_SETSEL and
     // EM_SCROLLCARET.  The LCL's SelStart setter scrolls the caret into view
     // itself (win32wsstdctrls.pp:1376), so the third message has no
     // counterpart to lose.
     SetEntrySel(TR4WCallEdit, EntrySelStart(TR4WCallEdit), 1);
     end;
  if CWStillBeingSent then
    // B1: same substitution as above.  4.52.10
     begin
     Switch := False;
     SwitchNext := False;
     InactiveRigCallingCQ := False;
     InactiveSwapRadio := False;
     end;

  itempos := SelectedPossibleCall;
  logger.trace('[CallWindowKeyDownProc] itemrpos');
  if Key = PossibleCallLeftKey then
     begin
     dec(itempos);
     end;
  if Key = PossibleCallRightKey then
     begin
     inc(itempos);
     logger.trace('[CallWindowKeyDownProc] itemright set ' + Key);
     end;
  if itempos = -1 then
     begin
     itempos := 0;
     end;
  SelectPossibleCall(itempos);

  // Re-read rather than trusting itempos: SelectPossibleCall ignores an index
  // past the end, exactly as LB_SETCURSEL did, so the walk can ask for a row
  // that does not exist and the selection simply stays put.
  itempos := SelectedPossibleCall;

  if Key = PossibleCallAcceptKey then

    if PossibleCallCount > 0 then
       begin
       logger.trace('[CallWindowKeyDownProc] PutCallToCallWindow ' + Key);
       PutCallToCallWindow(LogSCP.PossibleCallList.List[itempos].Call);
       end;

end;

procedure CallWindowKeyUpProc;
begin
  if AutoSendEnable then
     begin
     if AutoSendCharacterCount = length(CallWindowString) then
        begin
        DebugMsg('[CallWindowKeyUpProc] Calling StartSendingNow with False');
        StartSendingNow(False);
        end;
     end;
end;

{------------------------------------------------------------------------------}

procedure ExchangeWindowKeyDownProc(wParam: integer);
var
  //c: hwnd;
  itempos: integer;
  key: char;

begin
  // `c := wh[mweExchange]` WAS HERE, and it was a dead store into LOGWIND's
  // interface-scope global `c` -- the LOCAL of that name is commented out just
  // above, which is how the write escaped.  Nothing in the program reads that
  // global; swept every unit 2026-08-24.
  Key := Char(wParam);
  itempos := SelectedPossibleCall;
  if Key = PossibleCallLeftKey then
     begin
     dec(itempos);
     end;
  if Key = PossibleCallRightKey then
     begin
     inc(itempos);
     end;
  if itempos = -1 then
     begin
     itempos := 0;
     end;
  SelectPossibleCall(itempos);

  // Re-read rather than trusting itempos: SelectPossibleCall ignores an index
  // past the end, exactly as LB_SETCURSEL did, so the walk can ask for a row
  // that does not exist and the selection simply stays put.
  itempos := SelectedPossibleCall;

  if Key = PossibleCallAcceptKey then

    if PossibleCallCount > 0 then
       begin
       PutCallToCallWindow(LogSCP.PossibleCallList.List[itempos].Call);
       end;

  // If the contest type uses sections and we see a section starting to be typed,
  // start pre-filling the fields where the cals are placed for SCP
  // This code is a shell at the moment for implementation of Issue 87
  // Uncomment call in MsgLoop to call this when the window is mweExchange
end;
{------------------------------------------------------------------------------}

{ Re-title a radio panel from the radio currently in that slot.

  CALLED WHENEVER THE SLOT CHANGES, not only when the window opens. The caption
  was previously built inline in OpenTR4WWindow, with a comment admitting it
  went stale if the radio changed while the panel was up. Profiles turned that
  from a corner case into the normal one: activating a profile repoints BOTH
  slots at once, so the panels were left naming the PREVIOUS profile's radios,
  and a slot set to (none) kept the name of the radio just removed from it
  (NY4I, 2026-08-31).

  DOES NOTHING IF THE WINDOW IS NOT OPEN: there is no caption to set, and the
  open path calls this itself.

  THE GUARD ON rigName IS NOT PADDING. RadioName is INITIALISED to
  TC_RADIO1/TC_RADIO2 (logradio.pas) and only replaced when a definition is
  applied, so appending it unconditionally reads "Radio 1 Radio 1" on a station
  with no radio configured -- the state this panel is most often opened in while
  one is being set up. An emptied slot lands there too, and correctly reads just
  "Radio 2". }
procedure RefreshRadioWindowCaption(const ID: WindowsType);
var
   radioCaption, rigName: string;
   Radio: RadioPtr;
   lclForm: TCustomForm;
begin
   if not (ID in [tw_RADIOINTERFACEWINDOW1_INDEX, tw_RADIOINTERFACEWINDOW2_INDEX]) then
      begin
      Exit;
      end;

   { The handle is read straight from the array rather than held in an HWND
     local. Lint-Win32Dialogs counts declarations too, and this routine adds no
     Win32 SURFACE -- it is the same SetWindowTextW that was inline in
     OpenTR4WWindow, moved. A baseline raised for a variable would be a baseline
     raised for nothing. }
   if tr4w_WindowsArray[ID].WndForm = nil then
      begin
      Exit;
      end;

   if ID = tw_RADIOINTERFACEWINDOW1_INDEX then
      begin
      radioCaption := TC_RADIO1;
      Radio := @Radio1;
      end
   else
      begin
      radioCaption := TC_RADIO2;
      Radio := @Radio2;
      end;

   rigName := Trim(string(Radio.RadioName));
   if (rigName <> '') and (not SameText(rigName, radioCaption)) then
      begin
      radioCaption := radioCaption + ' ' + rigName;
      end;

   (* THE PANEL IS AN LCL FORM; its title is a property. LclFormFor answers for
     both radio slots, and the guard above has already established the window
     exists.

     PWideChar(WideString(...)) is also the exact shape that produced garbled
     captions elsewhere in this tree -- there it was a POINTER CAST of a
     resourcestring rather than a conversion. Here the WideString() made it a
     real conversion, so it worked; it is going because the Win32 call it fed
     is going, not because it was broken. *)
   //Windows.SetWindowTextW(tr4w_WindowsArray[ID].WndHandle, PWideChar(WideString(radioCaption))); //AGENT_DEPRECATED
   lclForm := LclFormFor(ID);
   if lclForm <> nil then
      begin
      lclForm.Caption := TCaption(radioCaption);
      end;
end;

{ Both radio panels, after anything that can repoint a slot. }
procedure RefreshRadioWindowCaptions;
begin
   RefreshRadioWindowCaption(tw_RADIOINTERFACEWINDOW1_INDEX);
   RefreshRadioWindowCaption(tw_RADIOINTERFACEWINDOW2_INDEX);
end;


(* SET A MENU ITEM'S ENABLED / CHECKED / CAPTION, or do nothing if there is no
  such item.

  MenuItemById answers nil for an id the menu does not contain, and that is an
  ORDINARY outcome: two rows are removed on some contests, and the window menu
  is asked about ids that a given build may not have. Reaching a nil here would
  be an access violation inside a menu handler -- a fault that surfaces
  mid-contest -- so the guard lives in one place rather than at twenty call
  sites. *)
procedure SetMenuEnabled(const aId: word; const aEnabled: boolean);
var
   item: TMenuItem;
begin
   item := MenuItemById(aId);
   if item <> nil then
      begin
      item.Enabled := aEnabled;
      end;
end;

procedure SetMenuChecked(const aId: word; const aChecked: boolean);
var
   item: TMenuItem;
begin
   item := MenuItemById(aId);
   if item <> nil then
      begin
      item.Checked := aChecked;
      end;
end;

procedure SetMenuCaption(const aId: word; const aText: string);
var
   item: TMenuItem;
begin
   item := MenuItemById(aId);
   if item <> nil then
      begin
      item.Caption := TCaption(aText);
      end;
end;

{ The item's caption, or '' when the menu has no such row. }
function MenuCaption(const aId: word): string;
var
   item: TMenuItem;
begin
   Result := '';
   if MenuItemById(aId) <> nil then
      begin
      Result := string(MenuItemById(aId).Caption);
      end;
end;

procedure OpenTR4WWindow(ID: WindowsType);
const
  NORESIZEEDWINDOW = SWP_SHOWWINDOW or SWP_NOSIZE;
  wi: array[WindowsType] of WindowsType = (
    tw_MAINWINDOW_INDEX,
    tw_BANDMAPWINDOW_INDEX,
    tw_MASTERWINDOW_INDEX,
    tw_FUNCTIONKEYSWINDOW_INDEX,
    tw_MASTERWINDOW_INDEX,
    tw_REMMULTSWINDOW_INDEX,
    tw_RADIOINTERFACEWINDOW1_INDEX,
    tw_RADIOINTERFACEWINDOW1_INDEX,
    tw_TELNETWINDOW_INDEX,
    tw_NETWINDOW_INDEX,
    tw_MMTTYWINDOW_INDEX,
    tw_INTERCOMWINDOW_INDEX,
    tw_POSTSCORESWINDOW_INDEX,
    tw_STATIONS_INDEX,
    tw_REMMULTSWINDOW_INDEX,
    tw_REMMULTSWINDOW_INDEX,
    tw_REMMULTSWINDOW_INDEX,
    tw_Unused17,                 // was tw_MP3RECORDER; the slot keeps its ordinal
    tw_REMMULTSWINDOW_INDEX,
    tw_MASTERWINDOW_INDEX,
    tw_HAMSCOREWINDOW_INDEX,   // Issue #783 Phase 4 -- HamScore status window
    tw_Dummy11
    );
var
  TempFlag: Cardinal;
  Radio: RadioPtr;
  i: integer;
  // The LCL form this window IS, when it is one, so the show at the bottom does
  // not have to ask a second time which windows are forms.
  lclForm: TCustomForm;
  { The window's title, taken from its menu row -- see below. }
  menuTitle: string;
begin
  if Contest = WRTC then
    if ID in [tw_MASTERWINDOW_INDEX, tw_TELNETWINDOW_INDEX,
      tw_POSTSCORESWINDOW_INDEX] then
       begin
       Exit;
       end;


  if ID = tw_NETWINDOW_INDEX then
    if not (ComputerID in ['A'..'Z']) then
       begin
       // showwarning(TC_SETCOMPUTERIDVALUE);

       SetCommand('COMPUTER ID');
       Exit;
       end;

  if ID = tw_MMTTYWINDOW_INDEX then
     begin
     if TR4W_MMTTYPATH[0] = #0 then
        begin
        SetCommand('MMTTY ENGINE');
        Exit;
        end;
     (* uMMTTYForm owns this now -- both callers are MMTTY window lifecycle,
       and the pane the DLL backs is that form's. *)
     uMMTTYForm.RichEditOperation(True);
     end;

  if tWindowsExist(ID) then
     begin
     Exit;
     end;

  SetMenuChecked(10199 + Ord(ID), True);
  tr4w_WindowsArray[ID].WndVisible := True;

 
 // if ID = tw_RADIOINTERFACEWINDOW2_INDEX then
 // h := CreateDialogParam(hInstance, MAKEINTRESOURCE(tw_RADIOINTERFACEWINDOW1_INDEX), tr4whandle, tr4w_WindowsArray[tw_RADIOINTERFACEWINDOW1_INDEX].WndProcAdr, integer(ID))
 // else
 // h := CreateDialogParam(hInstance, MAKEINTRESOURCE(ID), tr4whandle, tr4w_WindowsArray[ID].WndProcAdr, integer(ID));


  //h := CreateDialogParam(hInstance, MAKEINTRESOURCE(wi[ID]), tr4whandle, tr4w_WindowsArray[ID].WndProcAdr, integer(ID));

  // THE FIRST tw_ WINDOW THAT IS AN LCL FORM, and the seam every other one will
  // use as it converts.  One test before the DLGTEMPLATE call, returning the
  // form's Handle -- the same strangler shape CreateTR4WMainForm used for the
  // main window in Phase 3a.
  //
  // Everything downstream keeps working because it only ever dealt in a handle
  // and a rectangle: WndHandle, WndVisible, WndRect, the SetWindowPos that
  // positions it, and CloseTR4WWindow.
  lclForm := nil;
  if ID = tw_FUNCTIONKEYSWINDOW_INDEX then
     begin
     CreateTR4WFunctionKeysWindow;
     lclForm := TR4WFunctionKeysForm;
     end
  else if ID = tw_BANDMAPWINDOW_INDEX then
     begin
     CreateTR4WBandMapWindow;
     lclForm := TR4WBandMapForm;
     end
  else if ID = tw_STATIONS_INDEX then
     begin
     CreateTR4WStationsWindow;
     lclForm := TR4WStationsForm;
     end
  else if ID = tw_TELNETWINDOW_INDEX then
     begin
     CreateTR4WTelnetWindow;
     lclForm := TR4WTelnetForm;
     end
  else if ID = tw_MMTTYWINDOW_INDEX then
     begin
     CreateTR4WMMTTYWindow;
     lclForm := TR4WMMTTYForm;
     end
  else if (ID = tw_REMMULTSWINDOW_INDEX)  or
          (ID = tw_STATIONS_RM_DX)        or
          (ID = tw_STATIONS_RM_DOM)       or
          (ID = tw_STATIONS_RM_ZONE)      or
          (ID = tw_STATIONS_RM_PREFIX)    then
     begin
     // FIVE INSTANCES of one form -- the widest of the converted windows.
     CreateTR4WRemMultsWindow(ID);
     lclForm := RemMultsForm(ID);
     end
  else if ID = tw_NETWINDOW_INDEX then
     begin
     CreateTR4WNetworkWindow;
     lclForm := TR4WNetworkForm;
     end
  else if (ID = tw_RADIOINTERFACEWINDOW1_INDEX) or
          (ID = tw_RADIOINTERFACEWINDOW2_INDEX) then
     begin
     // TWO INSTANCES of one form -- an SO2R station has both open.
     CreateTR4WRadioPanelWindow(ID);
     lclForm := RadioPanelForm(ID);
     end
  (* THE MP3 RECORDER WINDOW IS GONE (2026-09-07). Recording moves to
    QSOCapture, which slices QSOs from TR4W's own N1MM-format contactinfo UDP
    broadcasts -- verified working on NY4I's station before this was removed.

    What went with it: the waveIn capture engine, the lame_enc.dll binding, the
    per-QSO and hourly recording hooks, and the Edit QSO play button. The tw_
    slot itself is kept as tw_Unused17 because menu ids are derived from the
    ordinal. *)
  else if ID = tw_INTERCOMWINDOW_INDEX then
     begin
     CreateTR4WIntercomWindow;
     lclForm := TR4WIntercomForm;
     end
  else if ID = tw_HAMSCOREWINDOW_INDEX then
     begin
     CreateTR4WHamScoreWindow;
     lclForm := TR4WHamScoreForm;
     end
  else if ID = tw_POSTSCORESWINDOW_INDEX then
     begin
     CreateTR4WPostScoresWindow;
     lclForm := TR4WPostScoresForm;
     end
  else if ID = tw_MASTERWINDOW_INDEX then
     begin
     CreateTR4WMasterWindow;
     lclForm := TR4WMasterForm;
     end
  else if (ID = tw_DUPESHEETWINDOW1_INDEX) or
          (ID = tw_DUPESHEETWINDOW2_INDEX) then
     begin
     // TWO INSTANCES, which is why this one takes the index: the dupe sheet is
     // per radio and both can be open at once.
     CreateTR4WDupeSheetWindow(ID);
     lclForm := DupeSheetForm(ID);
     end
  else
     begin
     (* THE WIN32 FALLBACK IS GONE (2026-09-01), and it could not have run.

        It was

          h := CreateDialogIndirectParam(hInstance,
                 PDlgTemplate(@MAINTR4WDLGTEMPLATE)^, tr4whandle,
                 tr4w_WindowsArray[ID].WndProcAdr, integer(ID));

        -- the original path every tool window took. Twenty arms above now cover
        every openable id in the tw_ enum, and as of today NOT ONE entry in
        tr4w_WindowsArray has a WndProcAdr. So the only way here was an id with
        no arm, and it would have handed CreateDialogIndirectParam a NIL window
        procedure: the dialog fails, h is 0, and the operator gets nothing with
        no explanation.

        REPORTED RATHER THAN SILENT, because that is the case this branch now
        exists for. A new tw_ window added without an arm gets a log line naming
        the id instead of a window that does not appear. *)
     if logger <> nil then
        begin
        logger.Error('[Windows] OpenTR4WWindow has no arm for window id %d ' +
                     '(%s) -- every tool window must build an LCL form',
                     [Ord(ID), WindowNames[ID]]);
        end;
     end;

  (* THE HANDLE, DERIVED FROM THE FORM, ONCE.

    Each arm above used to take an HWND back from its creator AND set lclForm
    to the same object -- the window named twice, once as a thing and once as a
    number. Fourteen functions returned a handle so that this one routine could
    put it in WndHandle, which is why fourteen units declared HWND at all.

    Nil form means no window, which is exactly what the error arm above leaves,
    so the old `h := 0` there is this line instead. *)

  // The window's caption is its MENU ITEM's text with the accelerator cut off,
  // so this reads back what CreateTR4WMenu wrote. W on both sides: the menu is
  // built with AppendMenuW, and an ANSI round trip here would decode a Cyrillic
  // caption through whatever codepage the machine happens to be running.
  //
  (* THE WINDOW'S TITLE IS ITS MENU ROW'S TEXT, with the accelerator cut off.

    Was GetMenuStringW into a local WideChar buffer, then a scan for the tab.
    MenuCaption returns the row's Caption, and the shortcut is still whatever
    follows a tab -- BuildTR4WMainMenu appends it there, exactly as the Win32
    walk did.

    THE LOCAL BUFFER IS GONE WITH THE CALL, and so is the trap it existed for:
    a failed GetMenuStringW left whatever the previous caller had put in the
    shared buffer, which is how three windows once came up titled with stale
    bytes rather than titled empty. MenuCaption answers '' for a row that is
    not there. *)
  menuTitle := MenuCaption(10199 + Ord(ID));
  i := Pos(#9, menuTitle);
  if i > 0 then
     begin
     menuTitle := Copy(menuTitle, 1, i - 1);
     end;

  // THROUGH THE FORM WHEN IT IS ONE, and this is not tidiness -- SetWindowTextW
  // writes the native title BEHIND the LCL's back, leaving Caption holding
  // whatever it held before.
  //
  // That is a stale-property bug with a delay fuse.  A window that sets its own
  // caption later -- the dupe sheet writes "Radio 1 Dupesheet - 10m-CW", the
  // stations window writes "Stations in CW mode" -- assigns the SAME STRING it
  // assigned last time it was open.  TControl.SetCaption compares and does
  // nothing, so the native title keeps the menu text this line just wrote, and
  // the operator sees "Radio 1" on every reopen while the first open looked
  // right (NY4I, 2026-08-24: "it just states Radio 1").
  //
  // Setting the property keeps the two in step and costs one Win32 call less.
  //
  // NO else ARM ANY MORE, and the reason is a proof rather than a measurement:
  // the ONLY path that leaves lclForm nil is the final else above, whose first
  // statement is `h := 0`. So lclForm = nil implies h = 0, and the
  // SetWindowTextW(h, menuText) that stood here could only ever have been
  // handed a null handle -- doing nothing, silently, on top of an Error that
  // arm already logs.
  if lclForm <> nil then
     begin
     lclForm.Caption := TCaption(menuTitle);
     end;
  {
  Windows.GetMenuStringA(tr4w_main_menu, 10199 + Ord(ID), wsprintfBuffer, SizeOf(wsprintfBuffer), MF_BYCOMMAND);
  for TempFlag := 0 to 100 do if wsprintfBuffer[TempFlag] = #9 then wsprintfBuffer[TempFlag] := #0;
  Windows.SetWindowTextA(h, wsprintfBuffer);
  }
  (* NO CAPTION IS BorderStyle, AND THE OLD LINE COULD NOT HAVE WORKED.

     It was

       Windows.SetWindowLong(h, GWL_STYLE, GetWindowLong(h, GWL_STYLE) - WS_POPUP);

     -- SUBTRACTION from a style word, not `and not`.  WS_POPUP is $80000000 and
     an LCL top-level form is created WS_OVERLAPPED, so the bit being taken away
     was NOT SET: the DWORD wraps and the remaining style bits are whatever the
     borrow leaves.  It also removes the wrong thing even when it works -- the
     caption is WS_CAPTION, which the commented-out line above it named.

     A second block further down then shrank the outer height by SM_CYSMCAPTION
     to make room for the caption's disappearance.  With bsNone the LCL removes
     the frame itself and reports the new size, so there is nothing to
     compensate and that block is gone with this one.

     BEFORE the saved BoundsRect is applied, and the handle re-read: changing
     BorderStyle recreates the window, and `h` would otherwise name a destroyed
     one.  NO CAPTION defaults to False and nobody has bench-tested it either
     way -- see docs/BENCH_QUEUE.md. *)

  if Config.NoCaption and (lclForm <> nil) then
     begin
     lclForm.BorderStyle := bsNone;
     end;

  tr4w_WindowsArray[ID].WndForm := lclForm;

  Radio := nil;
  if ID = tw_RADIOINTERFACEWINDOW1_INDEX then
     begin
     Radio := @Radio1;
     end;
  if ID = tw_RADIOINTERFACEWINDOW2_INDEX then
     begin
     Radio := @Radio2;
     end;

  if Radio <> nil then
     begin
     (* THE SLOT, NOT A HANDLE. Which panel this rig draws on is exactly what
       the ID above just told us. *)
     if ID = tw_RADIOINTERFACEWINDOW2_INDEX then
        begin
        Radio.tRadioPanelSlot := 2;
        end
     else
        begin
        Radio.tRadioPanelSlot := 1;
        end;

     // NO CONTROL HANDLES ARE TAKEN HERE ANY MORE.  They were GetDlgItem(h,
     // 121..123) and GetDlgItem(h, 105..106), handed to uRadioPolling so it
     // could post against them.  The panel is an LCL form now and its labels
     // are TGraphicControls, which HAVE NO WINDOW HANDLE -- so every update
     // travels as (panel, control id) instead, the way the text always did.

     // The mode labels (Issue #566) are 105 and 106, and they are built by
     // uRadio12 alongside every other control on this panel. They used to be
     // created HERE instead -- thirty lines of GetWindowRect / ScreenToClient
     // arithmetic against controls another unit had just placed, inside the
     // generic opener that has no other business knowing what a radio is.
     // AND THE FIVE ALIASES ARE GONE. RIT/XIT/Split were written here and read
     // NOWHERE; the two mode handles were read only as `<> 0`, which is what
     // tRadioPanelSlot answers. All five held the same value as the line above.

     // CAPTION: the localized label plus the rig, e.g. "Radio 1 K4" (NY4I,
     // 2026-08-20). The generic caption a few lines up is the MENU text, which
     // says only "Radio 1" and cannot tell an operator which of two rigs a
     // panel belongs to -- the thing a panel is for on an SO2R station.
     //
     // TC_RADIO1/TC_RADIO2, not a literal, so this follows the language the
     // rest of the UI is in.
     //
     // THE GUARD IS NOT DEFENSIVE PADDING. RadioName is INITIALISED to
     // TC_RADIO1/TC_RADIO2 in logradio.pas:3423 and is only replaced when a
     // radio definition from the library is applied, so appending it
     // unconditionally reads "Radio 1 Radio 1" on a station with no radio
     // configured -- which is exactly the state this panel is most often opened
     // in while setting one up.
     // ONE ROUTINE, called here and again whenever the slot's radio changes.
     // It used to be written out inline with a note saying the caption was set
     // at OPEN only and went stale if the radio changed underneath it. Profiles
     // made that visible: activating one repoints BOTH slots at once, so a
     // panel could sit there naming a radio that had just been moved to the
     // other slot or removed altogether (NY4I, 2026-08-31).
     RefreshRadioWindowCaption(ID);

     DisplayCurrentStatus(Radio);
     end;

  TempFlag := SWP_SHOWWINDOW;
  // if ID in [tw_RADIOINTERFACEWINDOW1_INDEX, tw_RADIOINTERFACEWINDOW2_INDEX, tw_MP3RECORDER, tw_GETSCORESWINDOW_INDEX]
  // then TempFlag := NORESIZEEDWINDOW;

  // THROUGH THE FORM WHEN IT IS ONE.  SetWindowPos moves the WINDOW; it does
  // not tell the LCL, whose own Left/Top/Width/Height still hold the DESIGNED
  // values from the .lfm.  Showing the form then pushes those cached bounds
  // back down to the handle and the window snaps to (0,0) at its designed size,
  // silently undoing the restore.
  //
  // That is why NY4I's band map would not come back where he left it
  // (2026-08-25): the layout was saved correctly and loaded correctly -- the
  // exit trace shows savedWndRect=(68,408,544,747), his moved position -- and
  // then the window was drawn at (0,0,476,339) anyway.  The NEXT exit saved
  // THAT, so one restart was enough to lose the real position for good.  Both
  // converted windows showed it; every unconverted one reports hWnd=0 and keeps
  // its saved rect, which is why only these two were affected.
  //
  // Same shape as the caption fix a few lines below: write the PROPERTY and let
  // the LCL do the Win32 call, or the two disagree and the widget set wins.
  (* THE WIN32 POSITIONING FALLBACK IS GONE, AND THIS ONE WAS SETTLED BY
    READING RATHER THAN BY WAITING FOR A LOG LINE.

    It asked "is this branch still reachable?" and was instrumented on
    2026-09-05 so evidence could answer. The answer is in the code: the only
    path that leaves lclForm nil is the final else above, and its FIRST
    STATEMENT is `h := 0`. tr4w_WindowsArray[ID].WndHandle is assigned from h.
    So the SetWindowPos that stood here was always given a null handle -- it
    could not position anything, which is the same silent nothing that lost the
    band map's saved position and the reason the branch was kept.

    The Error that arm logs names the window id and says every tool window must
    build an LCL form. That is the report; this was never more than a Win32
    call that failed quietly underneath it. *)
  if lclForm <> nil then
     begin
     lclForm.BoundsRect := tr4w_WindowsArray[ID].WndRect;
     end;

  // TELL THE LCL THE WINDOW IS UP -- IT CANNOT SEE A RAW SWP_SHOWWINDOW.
  //
  // This is the same defect ShowTR4WMainForm exists to fix, and it bit the band
  // map the same way: everything above shows the window through SetWindowPos on
  // an HWND, so the form's Visible property stays FALSE while the window is
  // plainly on the screen.  The LCL then does not show the CHILD CONTROLS, and
  // anything that asks the form whether it is visible gets the wrong answer.
  //
  // For the band map that meant an empty grid AND no context menu: the refresh
  // timer skips a form that is not visible -- which is right, and is how a
  // minimised TR4W stops costing a repaint four times a second -- so it skipped
  // every tick, and there was no live grid under the cursor to right-click on.
  //
  // Done HERE rather than in each Create function so the next tool window to
  // convert inherits it.  Positioning happens above, so this shows the form
  // where it belongs rather than at its designed position first.
  if lclForm <> nil then
     begin
     lclForm.Visible := True;
     end;

  FrmSetFocus;
end;

procedure CheckNumber;
begin
  if StringIsAllNumbers(CallWindowString) then
    if CallsignsList.FindNumber(CallWindowString) then
       begin
       PutCallToCallWindow(CallWindowString);
       end;

end;

procedure RequestCloseTR4WWindow(ID: WindowsType);
var
  // TCustomForm, matching LclFormFor -- Close is declared there, and a
  // TForm variable would not accept every form this can be handed.
  form: TCustomForm;
begin
  if not tWindowsExist(ID) then
     begin
     Exit;
     end;

  form := LclFormFor(ID);
  if (form <> nil) and form.Visible then
     begin
     // The framework's own way out. OnClose -> caHide -> CloseTR4WWindow.
     form.Close;
     Exit;
     end;

  CloseTR4WWindow(ID);
end;

procedure CloseTR4WWindow(ID: WindowsType);
begin
  if not tWindowsExist(ID) then
     begin
     Exit;
     end;
  FindAndSaveRectOfAllWindows;
  (* WHICH RADIO'S PANEL IS THIS? The ID says so.

    This compared the closing window's HANDLE against each radio's stored
    handle to work out which radio to clear -- while the window id it was
    handed answers directly. *)
  if ID = tw_RADIOINTERFACEWINDOW1_INDEX then
     begin
     Radio1.tRadioPanelSlot := 0;
     end;
  if ID = tw_RADIOINTERFACEWINDOW2_INDEX then
     begin
     Radio2.tRadioPanelSlot := 0;
     end;
  // Drop anything uPanelUpdate remembers about this panel BEFORE the window
  // goes. Windows reuses handles, and a stale 'last posted' entry would then
  // suppress the first update to a completely different window -- a panel
  // that reopens blank and stays blank, with nothing to point at.
  if tr4w_WindowsArray[ID].WndForm <> nil then
     begin
     (* ForgetPanel BY SLOT. It keyed its "last posted" cache by window handle,
       which mattered because Windows REUSES handles -- a stale entry could
       suppress the first update to a different window. A slot is stable and
       cannot be recycled, so the hazard the cache-clearing guarded against is
       gone; clearing it on close is still right, because the panel's contents
       do not survive being closed. *)
     if ID = tw_RADIOINTERFACEWINDOW1_INDEX then
        begin
        ForgetPanel(1);
        end
     else if ID = tw_RADIOINTERFACEWINDOW2_INDEX then
        begin
        ForgetPanel(2);
        end;

     (* HIDE, NOT DestroyWindow. The form object is kept and reused -- every
       creator does `if <form> = nil then Create` -- so destroying the native
       window behind the LCL's back only forced it to build another one on the
       next open. Hide is what the framework's own path does two routines up
       (form.Close -> caHide -> here). *)
     tr4w_WindowsArray[ID].WndForm.Hide;
     end;
  tr4w_WindowsArray[ID].WndForm := nil;
  tr4w_WindowsArray[ID].WndVisible := False;
  SetMenuChecked(10199 + Ord(ID), False);
  FrmSetFocus;
end;

procedure ProcessFuntionKeys(Key: integer);
begin
  GetRealVirtualKey(Key);

  if (OpMode2 = SearchAndPounceOpMode) then
     begin
     ProcessExchangeFunctionKey(CHR(Key))
     end
  else
     begin
     SendFunctionKeyMessage(CHR(Key), OpMode);
     end;
end;

procedure CreateDirectoryIfNotExist;
const
  DirArray: array[0..5] of PAnsiChar = ('dvk', 'dvk\lettersandnumbers',
    'dvk\fullcallsigns', 'dvk\fullserialnumbers', 'settings', 'dxcluster');
var
  i: integer;
begin
  //GetLastError = Cannot create a file when that file already exist s.

  for i := 0 to length(DirArray) - 1 do
     begin
     (* ForceDirectories, not CreateDirectoryA: it is the RTL's, it takes a
       string, and it makes intermediate levels -- which CreateDirectoryA does
       not, so a nested path silently did nothing here before. *)
     ForceDirectories(AnsiString(DirArray[i]));
     end;
  // Windows.CreateDirectoryA(GetYearString, nil);

end;

procedure CheckAndSetInitialExchangeCursorPos;
begin
  if InitialExchangeCursorPos = AtEnd then
     begin
     SetEntrySel(TR4WExchangeEdit, Length(EntryText(TR4WExchangeEdit)), 0);
     end;
  if InitialExchangeCursorPos = AtStart then
    // SetCursorPos(0,1); // n4af 4.42.7
     begin
     SetEntrySel(TR4WExchangeEdit, 0, 0); // 4.108.8
     end;

  if InitialExchangeOverwrite then
     begin
     SetEntrySel(TR4WExchangeEdit, 0, -1);
     end;
end;

procedure ClearInfoWindows;
begin
  ShowElement(mweMasterStatus, False);
  DispalayB4(SW_HIDE);
  // Windows.ShowWindow(B4StatusWindowHandle, SW_HIDE);
  CleanUpDisplay;
end;

function Get_Ctl_Code(nr: integer): Cardinal;
const
  FILE_DEVICE_UNKNOWN = $00000022;
  FILE_DEVICE_SERIAL_PORT = $0000001B;
  method_buffered = 0;
  FILE_ANY_ACCESS = $0000;
  FILE_DEVICE_PARALLEL_PORT = $00000016;
begin
  Result :=
    (FILE_DEVICE_PARALLEL_PORT shl 16) or
    (FILE_ANY_ACCESS shl 14) or
    (nr shl 2) or
    method_buffered;
end;

// Issue #1010: after an exchange-parsing error, drop the caret right after the
// offending token in the exchange window so the operator can fix it in place
// instead of arrowing back from end-of-line. No-op if no token was recorded or
// it isn't found in the current exchange text. Kept as its own procedure (not
// inlined into the long ParametersOkay) per the Delphi 7 codegen caution.
procedure PositionExchangeCursorAtErrorToken;
var
  p: integer;
begin
  if ExchangeErrorToken = '' then
     begin
     Exit;
     end;
  p := Pos(ExchangeErrorToken, ExchangeWindowString);
  if p > 0 then
     begin
     p := (p - 1) + Length(ExchangeErrorToken);   // 0-based caret just past the token
     SetEntrySel(TR4WExchangeEdit, p, 0);
     end;
end;

function ParametersOkay(Call: CallString;
  ExchangeString: Str40 {CallString};
  Band: BandType;
  Mode: ModeType;
  Freq: LONGINT;
  var RData: ContestExchange): boolean;

{ This function get called when a carriage return has been pressed when
 entering exchange data. It will look at the data in the exchange
 window and decide if enough information is there to log the contact.
 If something is missing, a False response will be generated. It the
 correct information is there, a True response will be generated and
 the appropriate fields in the ContestExchange record will be updated.

 It is the responsibility of this function to put the proper multiplier
 information into the proper fields in the RData record. The
 information in the RData.QTH is "raw" information and may need
 to be modified before putting it into the DomesticQTH, DXQTH, Prefix or
 Zone fields of RData. This has the effect of doing away with
 most of the meaning of the active multiplier flags except to know that
 the multiplier is switched on. }

var
  RST: Word;
  //s1, s2, s3, s4: str20;
begin
  logger.debug('>>>Entering ParametersOkay');
  logger.debug('Calling ParametersOkay with call = %s, Band = %s, Mode = %s, freq = %d, ExchangeString = %s', [call, BandStringsArray[Band], ModeStringArray[Mode], freq, ExchangeString]);

  // RData.QTHString :='';
  ParametersOkay := False;

  GetRidOfPostcedingSpaces(ExchangeString);

  LookForOnDeckCall(ExchangeString);

  ExchangeErrorMessage := '';
  ExchangeErrorToken := '';   // Issue #1010

  if NoLog then
     begin
     ParametersOkay := False;
     QuickDisplay(TC_SORRYNOLOG);
     DoABeep(ThreeHarmonics);
     Exit;
     end;

  LogBadQSOString := '';

  { Need this in case we exit soon }
  FillChar(RData.Callsign, SizeOf(RData.Callsign), 0);
  RData.ID := GetGUID;
  RData.Callsign := Call;
  if (ExchangeString = '') and not (ActiveExchange in [RSTNameAndQTHExchange,
    RSTAndPOTAPark]) then // These two exchanges allow blank exchanges
     begin
     logger.debug('Exiting ParametersOkay early: ExchangeString=<%s>',
       [ExchangeString]);
     Exit;
     end;
  { if length(ExchangeString) > 5 then // 4.96.3
  CallsignUpdateEnable := False;}
  if CallsignUpdateEnable then
     begin // This looks like the secxond line should be under IF but it was not.
     RData.Callsign := GetCorrectedCallFromExchangeString(ExchangeString);
     RData.Callsign[Ord(RData.Callsign[0]) + 1] := #0;
     end;

  RST := GetSentRSTFromExchangeString(ExchangeString);

  if RST <> 0 then
     begin
     RData.RSTSent := RST;
     end;

  if RData.Callsign = '' then
     begin
     RData.Callsign := Call
     end
  else
     begin
     end;
  logger.debug('[ParametersOkay] Setting RData.QTHString to zero');
  FillChar(RData.QTHString, SizeOf(RData.QTHString), 0);

  if ParameterOkayMode = QSLAndLog then
     begin
     RData.Band := Band;
     RData.Mode := Mode;
     if RData.ExtMode = eNoMode then
        begin
        if ActiveRadioPtr^.nextExtendedMode = eNoMode then
           begin
           SetExtendedModeFromMode(RData);
           end;
        end;

     // Not the way to do this as the radio does not know the extendedMode--just Mode. NY4I
     //RData.ExtMode := ActiveRadioptr.CurrentStatus.ExtendedMode; // 4.93.3
     RData.NumberSent := NextSerialToSend;  // Issue #954: highest sent serial + 1, not a QSO count
     RData.Frequency := Freq;

     if ActiveMode in [Phone, FM] then
        begin
        DefaultRST := 59
        end
     else
        begin
        DefaultRST := 599;
        end;

     if RData.RSTSent = 0 then
       if ActiveMode = Phone then
          begin
          RData.RSTSent := (LogRSSent)
          end
       else
          begin
          RData.RSTSent := (LogRSTSent);
          end;

     // LocateCall(RData.Callsign, RData.QTH, True);

     if DoingDXMults then
        begin
        GetDXQTH(RData);
        end;

     if DoingPrefixMults then
        begin
        SetPrefix(RData);
        end;

     GetRidOfPrecedingSpaces(ExchangeString);
     GetRidOfPostcedingSpaces(ExchangeString);

     ParametersOkay := True;
     LogBadQSOString := ExchangeString;
     logger.debug('Calling ProcessExchange from ParametersOkay QSLAndLog');
     ProcessExchange(ExchangeString, RData); {wli}
     CalculateQSOPoints(RData);
     Exit;
     end;

  if not IsAGoodCall(RData.Callsign) then
     begin
     TF.Format(QuickDisplayBuffer, PAnsiChar(LclText(TC_HASIMPROPERSYNTAX)), @RData.Callsign[1]);
     QuickDisplay(QuickDisplayBuffer);
     DoABeep(Warning);
     Exit;
     end;

  RData.Band := Band;
  RData.Mode := Mode;
  if RData.ExtMode = eNoMode then
    // if ExtMode was already set, no reason to look to the radio for it. WSJT-X sets it for example ny4i Issue 658
     begin
     if ActiveRadioPtr^.CurrentStatus.ExtendedMode = eNoMode then
       // This should have been set by radio object but what is nextExtendedMode
        begin
        SetExtendedModeFromMode(RData);
        end
     else
        begin
        Rdata.ExtMode := ActiveRadioPtr^.CurrentStatus.ExtendedMode;
        end;
     end;
  // ny4i Don't do this please - Issue 466 -=> Rdata.ExtMode := ActiveRadioptr^.CurrentStatus.ExtendedMode ; // 4.93.3
  RData.NumberSent := NextSerialToSend;  // Issue #954: highest sent serial + 1, not a QSO count
  RData.Frequency := Freq;

  if RData.RSTSent = 0 then
     begin
     FillChar(RData.RSTSent, SizeOf(RData.RSTSent), 0);
     if ActiveMode in [Phone, FM] then
        begin
        RData.RSTSent := LogRSSent;
        end
     else
        begin
        RData.RSTSent := LogRSTSent;
        end;
     end;

  if ActiveMode in [Phone, FM] then
     begin
     DefaultRST := 59
     end
  else
     begin
     DefaultRST := 599;
     end;

  // State-QP rover (KG1S/MON): use ctyLocateCallStripRover so the
  // country/zone lookup runs on the bare call (KG1S) instead of the
  // slashed form (which would be misinterpreted as a GB prefix
  // indicator).  RData.Callsign itself is preserved.
  ctyLocateCallStripRover(RData.Callsign, RData.QTH);

  if DoingDXMults then
     begin
     GetDXQTH(RData);
     end;

  if DoingPrefixMults then
     begin
     SetPrefix(RData);
     end;
  case ActivePrefixMult of
    BelgiumPrefixes: if RData.QTH.CountryID = 'ON' then
                        begin
                        RData.Prefix := RData.QTH.Prefix;
                        end;
    SACDistricts: RData.Prefix := SACDistrict(RData.QTH);
    IndonesianDistricts:
      begin
        RData.Prefix := IndonesianDistrict(Rdata.QTH); // 4.64.1
        if (Contest = YBDX) and (IndonesianCountry(MyCountry)) then
           begin
           SetPrefix(RData);
           end;
      end;
    Prefix: RData.Prefix := RData.QTH.Prefix;
    SouthAmericanPrefixes: if RData.QTH.Continent = SouthAmerica then
                              begin
                              RData.Prefix := RData.QTH.Prefix;
                              end;
    NonSouthAmericanPrefixes: if RData.QTH.Continent <> SouthAmerica then
                                 begin
                                 RData.Prefix := RData.QTH.Prefix;
                                 end;
  end;

  GetRidOfPrecedingSpaces(ExchangeString);
  GetRidOfPostcedingSpaces(ExchangeString);
  logger.debug('Calling ProcessExchange from ParametersOkay');
  ParametersOkay := ProcessExchange(ExchangeString, RData);

  if ExchangeErrorMessage <> '' then
     begin
     QuickDisplayError(ExchangeErrorMessage);
     PositionExchangeCursorAtErrorToken;   // Issue #1010: caret after the offending token
     end;

  if Result = False then
     begin
     Exit;
     end;

  if RData.RSTReceived = 0 then
    if ActiveMode in [Phone, FM] then
       begin
       RData.RSTReceived := LogRSSent
       end
    else
       begin
       RData.RSTReceived := LogRSTSent;
       end;

  RData.ExchString := ExchangeString;
  CalculateQSOPoints(Rdata);
end;

{ THE OWNER-DRAW, as an LCL event.  Phase 3b.

  PossibleCallsProc's body, reached through OnDrawItem instead of WM_DRAWITEM.
  DRAWITEMSTRUCT's fields map exactly: ItemID is Index, rcItem is ARect, and the
  ODS_SELECTED / ODA_FOCUS bits are the TOwnerDrawState set.  The HDC comes from
  the control's Canvas.

  A CLASS because OnDrawItem is a METHOD pointer -- the same reason
  TTR4WEntryEvents exists for the entry fields' key handlers.  One instance, no
  state; it exists to give the handler an implicit Self.

  THE GDI INSIDE IS UNCHANGED ON PURPOSE.  Moving the plumbing and redrawing the
  pixels in one step would make any visual difference impossible to attribute,
  and this control repaints on every keystroke in the callsign field.  Converting
  the body to Canvas calls is Phase 7 burn-down and is counted separately. }
(* THE POSSIBLE-CALL LIST, DRAWN ON THE LCL CANVAS (2026-09-08).

  This is the LIVE owner-draw handler and it is worth saying how it is reached,
  because a search of the Pascal alone says the opposite:

      uMainForm.lfm:78   OnDrawItem = lstPossibleCallDrawItem   <- the LCL wires it
        TTR4WMainForm.lstPossibleCallDrawItem
          PossibleCallDrawProc(...)          <- the seam, guarded by Assigned
            = @PossibleCallsDrawItem         <- set in CreateMainWindow
              here

  Nothing in Pascal calls lstPossibleCallDrawItem; the only reference is a
  STRING in the .lfm, resolved by the streaming loader. So this looked exactly
  like the dead PossibleCallsProc below it, and is not.

  WHAT CHANGED: the body drew with GDI on an HDC taken from the canvas --
  CreatePen/SelectObject/Rectangle/DeleteObject, SetBkMode, SetTextColor,
  DrawTextA, DrawFocusRect -- inside a handler the LCL already calls with a
  TCanvas. Every one of those has a canvas equivalent, so there was nothing to
  translate, only something to stop doing:

    CreatePen + SelectObject + Rectangle    Canvas.Pen + Canvas.Rectangle. The
                                            LCL owns the pen's lifetime, which
                                            also removes the leak-if-you-return
                                            shape of the original.
    GradientRect(dc, r, c, c, ...)          Canvas.FillRect. Both stops were
                                            the SAME COLOUR, so this was a
                                            gradient from a colour to itself --
                                            an expensive flat fill.
    SetTextColor + DrawTextA                Canvas.Font.Color + Canvas.TextRect
                                            with a TTextStyle. DT_CENTER,
                                            DT_VCENTER, DT_SINGLELINE and
                                            DT_END_ELLIPSIS map one-for-one to
                                            Alignment, Layout, SingleLine and
                                            EndEllipsis.
    DrawTextA on @Call[1]                   a string. The A-variant took a
                                            pointer into a ShortString and a
                                            length; TextRect takes the text.

  NO EARLY EXIT ON odFocused -- see the focus rectangle at the end. The Win32
  original tested itemAction = ODA_FOCUS, a distinct ACTION meaning "draw the
  focus rectangle only, the item is already on screen". odFocused is a STATE
  FLAG, set during an ordinary repaint of the focused row, so honouring it the
  old way drew a rectangle around nothing and returned -- the focused entry
  rendered as an empty box. Faithful line, wrong axis; kept fixed. *)
procedure PossibleCallsDrawItem(Control: TWinControl; Index: integer;
                                ARect: Types.TRect; State: TOwnerDrawState);
const
  nWidth = 2;
var
  cv: TCanvas;
  r: TRect;
  style: TTextStyle;
begin
  if (Index < 0) or (Index > High(PossibleCallList.List)) then
     begin
     Exit;
     end;

  cv := TListBox(Control).Canvas;
  r  := ARect;

  if odSelected in State then
     begin
     cv.Pen.Color   := clRed;
     cv.Pen.Width   := nWidth;
     cv.Pen.Style   := psSolid;
     (* bsClear so Rectangle draws the BORDER ONLY. The GDI original got that
       from whatever brush the DC happened to hold; saying it is the point. *)
     cv.Brush.Style := bsClear;
     cv.Rectangle(r.Left + 1, r.Top + 1, r.Right, r.Bottom);

     r.Top    := r.Top + nWidth;
     r.Left   := r.Left + nWidth;
     r.Right  := r.Right - nWidth;
     r.Bottom := r.Bottom - nWidth;
     end;

  if PossibleCallList.List[Index].Dupe then
     begin
     cv.Brush.Color := clRed;
     cv.Font.Color  := clWhite;
     end
  else
     begin
     cv.Brush.Color := tr4wColorsArray[TWindows[mwePossibleCall].mweBackG];
     cv.Font.Color  := tr4wColorsArray[TWindows[mwePossibleCall].mweColor];
     end;

  cv.Brush.Style := bsSolid;
  cv.FillRect(r);

  FillChar(style, SizeOf(style), 0);
  style.Alignment   := taCenter;     // DT_CENTER
  style.Layout      := tlCenter;     // DT_VCENTER
  style.SingleLine  := True;         // DT_SINGLELINE
  style.EndEllipsis := True;         // DT_END_ELLIPSIS
  style.Clipping    := True;
  style.Opaque      := False;        // the fill above already painted it

  (* LclText, not a plain cast: TCanvas.TextRect takes the LCL's AnsiString,
    which holds UTF-8, and this unit's `string` is UTF-16. Stating the
    conversion at the boundary is what CLAUDE.md asks for and what keeps the
    narrowing ceiling meaningful. *)
  cv.TextRect(r, r.Left, r.Top,
              LclText(PossibleCallList.List[Index].Call), style);

  { OVER the finished item, and over the WHOLE item: ARect, not the r that
    the selection border shrank. }
  if odFocused in State then
     begin
     cv.DrawFocusRect(ARect);
     end;
end;

//procedure PossibleCallsProc(PCDRAWITEMSTRUCT: PDrawItemStruct);
//label
//  draw;
//const
//  nWidth = 2;
//var
//  TempColor: tcolor;
//  Pen, PenOld: HPEN;
//begin
//
//  if (PCDRAWITEMSTRUCT^.itemAction = ODA_FOCUS) then
//     begin
//     DrawFocusRect(PCDRAWITEMSTRUCT^.HDC, PCDRAWITEMSTRUCT^.rcItem);
//     Exit;
//     end;
//
//  if lobyte(PCDRAWITEMSTRUCT^.itemState) = ODS_SELECTED then
//     begin
//     Pen := CreatePen(PS_SOLID, nWidth, $FF0000 {RGB(255, 0, 0)});
//     SetBkMode(PCDRAWITEMSTRUCT^.HDC, TRANSPARENT);
//     PenOld := SelectObject(PCDRAWITEMSTRUCT^.HDC, Pen);
//
//     Rectangle(PCDRAWITEMSTRUCT^.HDC,
//       PCDRAWITEMSTRUCT^.rcItem.Left + 1,
//       PCDRAWITEMSTRUCT^.rcItem.Top + 1,
//       PCDRAWITEMSTRUCT^.rcItem.Right,
//       PCDRAWITEMSTRUCT^.rcItem.Bottom);
//
//     SelectObject(PCDRAWITEMSTRUCT^.HDC, PenOld);
//     DeleteObject(Pen);
//
//     PCDRAWITEMSTRUCT^.rcItem.Top := PCDRAWITEMSTRUCT^.rcItem.Top + nWidth;
//     PCDRAWITEMSTRUCT^.rcItem.Left := PCDRAWITEMSTRUCT^.rcItem.Left + nWidth;
//     PCDRAWITEMSTRUCT^.rcItem.Right := PCDRAWITEMSTRUCT^.rcItem.Right - nWidth;
//     PCDRAWITEMSTRUCT^.rcItem.Bottom := PCDRAWITEMSTRUCT^.rcItem.Bottom - nWidth;
//     end;
//
//  if PossibleCallList.List[PCDRAWITEMSTRUCT^.ItemID].Dupe then
//     begin
//     TempColor := clred;
//     Windows.SetTextColor(PCDRAWITEMSTRUCT^.HDC, $00FFFFFF);
//     // InflateRect(PCDRAWITEMSTRUCT^.rcItem,-1,-1);
//     end
//  else
//     begin
//     TempColor := tr4wColorsArray[TWindows[mwePossibleCall].mweBackG];
//     //clbtnface;
//     Windows.SetTextColor(PCDRAWITEMSTRUCT^.HDC,
//       tr4wColorsArray[TWindows[mwePossibleCall].mweColor] { $ 00000000});
//     end;
//
//  GradientRect(PCDRAWITEMSTRUCT^.HDC, PCDRAWITEMSTRUCT^.rcItem, TempColor,
//    TempColor {tr4wColorsArray[TWindows[mwePossibleCall].mweBackG]},
//    gdHorizontal);
//
//  SetBkMode(PCDRAWITEMSTRUCT^.HDC, TRANSPARENT);
//  Windows.DrawTextA(PCDRAWITEMSTRUCT^.HDC,
//    @PossibleCallList.List[PCDRAWITEMSTRUCT^.ItemID].Call[1],
//    length(PossibleCallList.List[PCDRAWITEMSTRUCT^.ItemID].Call),
//    PCDRAWITEMSTRUCT^.rcItem, DT_END_ELLIPSIS + DT_SINGLELINE + DT_CENTER +
//    DT_VCENTER);
//end;

procedure EditableLogWindowDblClick;
var
  Size: Int64;
begin
  (* THE GRID ANSWERS IN RECORDS, AND THAT IS THE WHOLE ANSWER.

    THE ROW-TO-RECORD MAPPING THAT STOOD HERE IS GONE, and leaving it in place
    is why a double click stopped opening the editor at all (NY4I, 2026-09-04:
    "when I double-click on a contact in the log grid, the edit dialog is not
    appearing").

    The mapping existed because the Win32 list view showed the LAST
    LinesInEditableLog records, so a row was an offset into a five-row window
    and the record index had to be reconstructed. The grid shows the WHOLE log
    and its SelectedRecord is already a record index -- so running it through
    that mapping converted a correct answer into a wrong one, and for any row
    at or beyond LinesInEditableLog the mapping answered -1, the guard below
    took it as "not a record", and the routine returned in silence.

    That is the same class of defect as the two duplicated facts in the grid
    itself: a translation that was necessary under the old model, left in place
    under the new one, where it is not a no-op but an error. *)
  IndexOfItemInLogForEdit := TR4WEditableLogSelectedRecord;
  if IndexOfItemInLogForEdit < 0 then
     begin
     Exit;
     end;

  (* STILL BOUNDS-CHECKED AGAINST THE LOG. SelectedRecord is checked against
    the count the grid was last given, which is not quite the same as what the
    log holds now -- and the editor addresses a record by index. *)
  if not LogSourceOpen then
     begin
     Exit;
     end;
  Size := LogSourceRecordCount;
  LogSourceClose;

  if IndexOfItemInLogForEdit >= Size then
     begin
     Exit;
     end;

  (* WHICH RECORD IS ABOUT TO BE EDITED. A double click that opens nothing and
    one that opens the WRONG QSO look identical from the keyboard, and the
    difference between them is one line of arithmetic -- which is exactly what
    went wrong here. *)
  if logger <> nil then
     begin
     logger.Debug('[EditableLog] double-click -> editing record %d',
                  [IndexOfItemInLogForEdit]);
     end;

  OpenEditQSOWindow;
  FrmSetFocus;
end;

procedure tWinHelp(WindowHelpID: Byte);
begin
  // WinHelp(tr4whandle, TR4W_HLP_FILENAME, HELP_CONTEXT, Cardinal(WindowHelpID));
end;

{
procedure DecrementTimeInDupesArray;
var
 i : cardinal;
 TemeLeft : byte;
begin
 for i := 0 to 1000 do
 begin
 if tDupesArray[i].tActive = False then Break;
 TemeLeft := tDupesArray[i].tMinutsLeft;
 if TemeLeft > 0 then
 begin
 Dec(TemeLeft);
 tDupesArray[i].tMinutsLeft := TemeLeft;
 end;

 end;

end;
}

procedure tClearDupeInfoCall;
begin
  FillChar(DupeInfoCall, SizeOf(DupeInfoCall), 0);
end;

procedure tCleareCallWindow;
begin
  logger.debug('Clearing main call window');
  SetEntryText(TR4WCallEdit, '');

end;

procedure tCleareExchangeWindow;
begin
  // Windows.SetWindowTextA(ExchangeWindowHandle, nil);
  // SetEntryText(TR4WExchangeEdit, nil);
  SetEntryText(TR4WExchangeEdit, '');
  
end;

procedure tSetExchWindInitExchangeEntry;
begin
  // D12: InitialExchangeEntry + SetMainWindowText are native string now, so the
  // Str80 local, its ZeroMemory, and the @ie[1] ASCIIZ view are all gone.
  SetEntryText(TR4WExchangeEdit, InitialExchangeEntry(CallWindowString));
  if Config.LeaveCursorInCallWindow then
     begin
     tCallWindowSetFocus;
     end;
end;

procedure HandleRepeatPOTAParks;
// Called from the "Repeat POTA Parks (2nd Op)" Commands menu item.
// Pre-fills the exchange with the parks from the last logged POTA contact so
// the operator only needs to type the new callsign and press Enter.
// The call window is left blank — the operator types the second op's call.
var
  ExchStr : string;
  ExchBuf : array[0..80] of AnsiChar;
begin
  ExchStr := GetLastPOTAExchange;
  if ExchStr = '' then
     begin
     QuickDisplay(TC_NOPOTAPARKSLOGGEDYETSESSION);
     Exit;
     end;

  // Pre-fill exchange window; leave call window empty for the new callsign.
  // ExchBuf was a byte buffer built only to hand SetWindowTextA a PAnsiChar.
  ExchangeWindowString := ExchStr;
  SetEntryText(TR4WExchangeEdit, string(ExchStr));

  tCallWindowSetFocus;
  QuickDisplay('2nd op: type callsign, verify exchange, then Enter - ' + ExchStr);
end;

procedure UpdateWindows;
begin
  UpdateTotals2;
  VisibleLog.ShowRemainingMultipliers;
  VisibleLog.DisplayGridMap(ActiveBand, ActiveMode);
  DisplayTotalScore {(TotalScore)};
  // DisplayInsertMode;
  DisplayNextQSONumber;
  SpotsList.UpdateSpotsMultiplierStatus;
  //UpdateBandMapMultiplierStatus;
  CallsignsList.DisplayDupeSheet(@Radio1 {ActiveBand, ActiveMode});
  CallsignsList.DisplayDupeSheet(@Radio2);
  DisplayQSOsByOpMode;
end;

procedure showint(Num: integer);
begin
  logger.Error(IntToStr(Num));
  //TF.Format(wsprintfBuffer, '%i', Num);
  //ShowMessage(wsprintfBuffer);
end;

(* ONE ROUTINE, WHERE THERE WERE THREE.

  ShowMessage, ShowMessage2 and ShowMessageParent differed in exactly one thing
  -- the caption Win32 was given: 'TR4W', nil, and 'TR4W' again -- and carried
  three verbatim copies of the twelve-line headless guard between them. Measured
  2026-09-07: ShowMessage2 had NO callers at all, and ShowMessageParent had one,
  in uEditQSO, which now calls this. Its own comment already said the owner
  window it was named for had gone.

  MB_TASKMODAL was asking by hand for what an LCL dialog is by default, and
  tr4whandle was only ever the owner of the box. *)
procedure ShowMessage(Text: string);
begin
  logger.Info('Sending to MessageBox: ' + Text);

  (* NO MODAL WHEN THERE IS NO OPERATOR.

     showwarning in TF has had this guard for a while, with a comment describing
     exactly this failure -- and its siblings here never got it, so the rule
     held for warnings and not for messages. Two headless runs hung on it in one
     session: "Invalid statement in config file" during /RESCORE, and
     "RESTART.BIN is for a different contest" during a batch export. Both sat
     forever with nobody to click OK.

     The text is already in the log above, which is what a headless run has
     instead of a screen. *)
  if tSilentExport then
     begin
     Exit;
     end;

  MessageDlg('TR4W', LclText(Text), mtInformation, [mbOK], 0);
end;

procedure FilePreview;
begin
  if tSilentExport then Exit;   // batch /EXPORT: no modal preview window

  { RichEditOperation(True) STOOD HERE and is gone with the RichEdit: the
    viewer shows the file in a TMemo now and takes no reference on
    RICHED32.DLL.  The refcount itself stays -- the MMTTY window is its other
    caller -- and leaving the Load here without the matching Unload in the
    viewer's teardown would have leaked the library for the session. }
  ShowFullLog;
  { The preview opens ON TOP of the station-information window, which is still
    modal underneath it.  Was SetFocus on a global HWND. }
  FocusCabrilloSummaryWindow;
end;

procedure tCallWindowSetFocus;
begin
  // if ActiveMainWindow <> awCallWindow then
  // if not tr4w_CallWindowActive then

  begin
    // ChangeFocus('call');
    FocusEntry(TR4WCallEdit);
    // Windows.SetWindowTextA(InsertWindowHandle, inttopchar(GetTickCount64));

  end;
end;

procedure tExchangeWindowSetFocus;
begin
  { ny4i Issue 131, PRESERVED THROUGH THE CONVERSION.
    SetFocus returned an Access Denied error when using CWBC, so
    SetForegroundWindow was added as a fallback.  The original note also said
    "this can get dicey with threads ... needs thorough testing with WinKey and
    K1EA keyer because of the threading used there" -- and that testing has now
    happened: NY4I keyed CW on 2026-08-23 and the accessors' off-main-thread
    check reported NOTHING, so this runs on the main thread after all.

    The fallback is kept regardless.  It was written against real symptoms, and
    "the thread theory did not hold" is not evidence that the symptom is gone.
    aBringForward is BringToFront, the LCL's SetForegroundWindow, and it is
    opt-in so no other focus path gains the ability to steal the foreground. }
  FocusEntry(TR4WExchangeEdit, {aBringForward} True);
end;

procedure tRuntPaddleAndFootSwitchThread;
begin
  if tPaddleFootSwitchThread <> INVALID_HANDLE_VALUE then
     begin
     Exit;
     end;
  tExitFromPaddleFootSwitchThread := False;
  logger.Info('Calling tCreateThread from tRuntPaddleAndFootSwitchThread');
  tPaddleFootSwitchThread := tCreateThread(@tPaddleFootSwitchThreadProc,
    tPaddleThreadID);
  logger.Info('Created PaddleAndFootSwitch thread with threadid of %d',
    [tPaddleThreadID]);
  // Issue #997: asm SetThreadPriority -> Pascal call. The old `push eax` pushed a
  // stale handle (clobbered by the preceding logger.Info), so this never applied;
  // now set it on the real handle. BEHAVIOR CHANGE: paddle/foot-switch thread now
  // actually runs LOWEST.
{$IFDEF WINDOWS}
  SetThreadPriority(tPaddleFootSwitchThread, THREAD_PRIORITY_LOWEST);
{$ELSE}
  (* FPC HAS ThreadSetPriority, AND IT IS STILL NOT A ONE-LINE SWAP.

    Two mismatches, neither of them cosmetic. The HANDLE: this is a Win32
    thread handle from tCreateThread, where ThreadSetPriority wants a
    TThreadID -- so wiring it up is part of moving the paddle thread itself.
    The SCALE: Win32 has seven named levels and FPC takes -15..15, and on
    Linux a plain thread cannot raise priority at all without privilege, so
    "lowest" is the only direction that even works unasked.

    Leaving it unset is the safe failure: the thread runs at normal priority,
    which is what it did on Windows for years before Issue #997 found the
    asm was pushing a stale handle and the call never applied at all. *)
{$ENDIF}
end;
{
procedure TryToLoadRICHED32DLL;
begin
 if RICHED32DLLHANDLE = 0 then RICHED32DLLHANDLE := Windows.LoadLibrary('RICHED32.DLL');
end;
}

procedure InitializeQSO;
begin
  tAutoSendMode := False;
  ExchangeHasBeenSent := False;
  CallAlreadySent := False;
  tCleareCallWindow;
  tCleareExchangeWindow;
  tCallWindowSetFocus;
  ClearAltD; // 4.65.2
  tClearDupeInfoCall; // 4.65.2
  if OpMode = CQOpMode then
     begin
     OpMode2 := CQOpMode;
     ShowFMessages(0);
     end;
end;

procedure CreateCallOrExchangeWin(Top, ID: integer; const aField: TTR4WEntryField);
begin
  // PHASE 3b: an LCL TEdit, addressed by its Handle exactly as before.  The
  // message loop still routes keystrokes by comparing Msg.HWND against
  // wh[mweCall], and a TEdit's Handle IS that HWND, so nothing about the
  // routing changes here.  See src\ui\lcl\uMainForm.pas.
  // THE SHAPE, NOT AN HFONT, and passed IN so it is applied before the handle
  // exists. tWM_SETFONT(Result, MainWindowEditFont) sent WM_SETFONT to an LCL
  // TEdit, which paints from its own TFont and ignores it -- so these two
  // fields kept the FORM's default while every element got MainFont, and the
  // call window read smaller than the band, date and time beside it (NY4I,
  // 2026-08-28). Same three numbers MainWindowEditFont is built from.
  if LuconSZLoadded then
     begin
     CreateTR4WEntryField(ws * 15 {col4}, Top, 13 * ws,
                          MainWindowEditHeight, ID,
                          not Config.NoBorder, aField,
                          'Lucida Console SZ', ws + 3, True);
     end
  else
     begin
     CreateTR4WEntryField(ws * 15 {col4}, Top, 13 * ws,
                          MainWindowEditHeight, ID,
                          not Config.NoBorder, aField,
                          'Lucida Console', ws + 3, True);
     end;
  // THE SHAPE, NOT AN HFONT.  tWM_SETFONT(Result, MainWindowEditFont) sent a
  // WM_SETFONT to an LCL TEdit, which paints from its own TFont and ignores it,
  // so these two fields kept the FORM's default while every element got
  // MainFont -- the call window read smaller than the band, date and time
  // beside it (NY4I, 2026-08-28).  Same three numbers MainWindowEditFont is
  // created from: ws + 3, extra-bold, Lucida Console (SZ when it loaded).
  (* EM_LIMITTEXT IS MaxLength, and the idiom was already three lines from
    here. This was SendMessage(Result, EM_LIMITTEXT, 12, 0) -- reaching for the
    control by handle -- while the line immediately below this routine's second
    call site says TR4WExchangeEdit.MaxLength := 35. Same control, same
    property, one of them going through a window handle.

    Unchanged in effect: both fields were limited to 12 here and the exchange
    was then raised to 35 by its caller, and both still are. *)
  if aField = efCall then
     begin
     TR4WCallEdit.MaxLength := 12;
     end
  else
     begin
     TR4WExchangeEdit.MaxLength := 12;
     end;
end;

procedure TimeApplet(i: Cardinal);
begin
  RunWindowsUtility(SysUtils.Format(
    'rundll32.exe shell32.dll,Control_RunDLL timedate.cpl,,%u', [i]));
end;

procedure LoadinLog;
label
  1, 2, start;
var
  (* Int64 AND SIGNED, because it holds LogSourceRecordCount, which answers -1
    for "cannot be read". As a Cardinal the guard below was always false and the
    build's always-false ratchet said so. It was a Cardinal when it held
    GetFileSize, which cannot be negative. *)
  Size: Int64;
  CurrentRecord, FirstRecord: integer;
  TempMode: ModeType;

begin

  start:
{$IF tDebugMode}
  T1 := GetTickCount64;
  // m :=0;
{$IFEND}
  (* THE LOG IS THE DATABASE -- step B5.

    WHAT STOOD HERE, AND WHY NONE OF IT SURVIVES. A CreateFileA with
    OPEN_ALWAYS, so opening a contest created the .TRW as a side effect; a read
    of the four-byte version string with a conversion prompt when it did not
    match; and a check that the file length was a whole number of
    SizeOf(ContestExchange) records. Every one of those is a question about a
    FLAT FILE OF FIXED-WIDTH RECORDS, and the answers are now the database's own:
    TLogDatabase verifies application_id and user_version when it opens, and a
    row cannot be half a record.

    THE CONVERSION PROMPT GOES WITH THEM. A .TRW written by an older TR4W is not
    opened and upgraded in place any more -- it is MIGRATED, once, the first
    time this build opens that contest, by the importer in uLogStore. An
    operator sees their QSOs either way; the difference is that the old path
    rewrote their log file and the new one leaves it untouched.

    LogSourceOpen is what creates or migrates: see uLogStore.EnsureOpen. *)
  if not LogSourceOpen then
     begin
     Exit;
     end;

  (* RESET THE VIEW BEFORE REFILLING IT.

     These three sat between the CreateFileA and the header check, and went with
     that block when it was replaced -- which is a reload appending to the list
     instead of rebuilding it, and two counters starting from wherever the last
     load left them. Nothing failed: the harness opens a fresh contest, so the
     list is empty either way and the bug only shows on a SECOND load.

     Lint-Win32Dialogs caught it, by counting wh[] uses and noticing one had
     gone -- a ratchet meant for tracking the LCL conversion, catching a
     deletion nobody meant to make. *)
  CurrentRecord := 0;
  tLogIndex := 0;
  TR4WEditableLogSetCount(0);

  Size := LogSourceRecordCount;
  if Size < 0 then
     begin
     LogSourceClose;
     Exit;
     end;
  LogSourceRewind;

  (* WHICH RECORD THE EDITABLE LOG STARTS AT IS NO LONGER A QUESTION.

    It was, while the list held the LAST LinesInEditableLog records and the
    loader had to skip the rest. The grid is virtual and shows the WHOLE log,
    so the loader inserts nothing and skips nothing, and the guard that used
    this is gone with it.

    uEditableLogView, which owned that expression, is deleted with it. *)
  Sheet.DisposeOfMemoryAndZeroTotals;
  // LoadingInLogFile := True;
  1:
  if LogSourceNext(TempRXData) then
     begin

     if TempRXData.ceSendToServer = False then
        begin
        inc(tUSQ);
        end;
     if TempRXData.ceNeedSendToServerAE = True then
        begin
        inc(tUSQE);
        end;

     inc(tRestartInfo.riTotalRecordsInLog);
     // if tRestartInfo.riTotalRecordsInLog = 3057 then
     // tRestartInfo.riTotalRecordsInLog := 3057;
     // if tTotalRecordsInLog mod 1000 = 0 then DispalyLoadedQSOs(tTotalRecordsInLog);
     if TempRXData.ceRecordKind in [rkQTCR, rkQTCS] then
        begin
        IncrementQTCCount(TempRXData.Callsign);
        end;

     if TempRXData.ceRecordKind = rkQTCS then
        begin
        NumberQTCBooksSent := TempRXData.QSOPoints;
        end;

     if TempRXData.ceRecordKind = rkQSO then
       if (not TempRXData.ceQSO_Deleted) and (TempRXData.Band <> NoBand) and
         (TempRXData.Mode <> NoMode) then
          begin
          // Issue #954: feed the serial high-water mark.  This counts every
          // non-deleted QSO that consumed a number -- INCLUDING X-QSO -- which is
          // exactly why it lives OUTSIDE the #750 guard below: marking a QSO X-QSO
          // (or deleting a mid-log QSO) must not roll the sent serial backward.
          // Range/sentinel filtering is handled inside UpdateMaxSerialSent.
          if not TempRXData.ceQSO_Deleted then
             begin
             UpdateMaxSerialSent(TempRXData.Band, TempRXData.NumberSent);
             end;
          // Issue #750: X-QSO records are kept in the log (and the
          // editable log view -- they paint grayed) but contribute
          // nothing to QSOTotals, multipliers, points, or the dupe
          // sheet.  tUpdateLog(actRescore) has the same guard for the
          // same reason; this load-time path (LoadinLog) also needs
          // it so totals are correct after a fresh log open / load.
          if (TempRXData.ceQSO_Deleted = False) and
             (TempRXData.ceXQSO        = False) then
             begin
             TempMode := TempRXData.Mode;
             if TempMode = FM then
                begin
                TempMode := Phone;
                end;
             inc(QSOTotals[TempRXData.Band, TempMode]);
             inc(QSOTotals[TempRXData.Band, Both]);
             inc(QSOTotals[AllBands, TempMode]);

             if (SingleBand = TempRXData.Band) or (SingleBand = AllBands) then
                begin
                TotalQSOPoints := TotalQSOPoints + TempRXData.QSOPoints;
                end;

             if Contest = MOQSOPARTY then
                begin
                CheckMOQSOPartyBonusStation(TempRXData.Callsign);
                end;

             Sheet.AddQSOToSheets(@TempRXData, True);
             CallsignsList.AddCallsign(TempRXData.Callsign, TempMode,
               TempRXData.Band, TempRXData.ceClearDupeSheet);
             if not IntitialExLoaded then
                begin
                CallsignsList.AddIniitialExchange(TempRXData.Callsign,
                  GetInitialExchangeStringFromContestExchange(TempRXData));
                end;

             if TempRXData.Band in [Band160..Band10] then // 4.115.3
                begin
                inc(ContinentQSOCount[TempRXData.Band, TempRXData.QTH.Continent]);
                inc(ContinentQSOCount[AllBands, TempRXData.QTH.Continent]);
                inc(TimeSpentByBand[TempRXData.Band]);
                // PreviousBand := TempRXData.Band;
                end;
             // Issue #750 follow-up: this increment was previously OUTSIDE
             // the X-QSO guard, so the score grid's "All" column counted
             // X-QSO records even though every per-band/per-mode counter
             // skipped them. Moved inside so the totals are consistent.
             inc(QSOTotals[AllBands, Both]);
             end;
          end;
     // else
     // asm nop end;

     inc(CurrentRecord);
     {                                              c
    if CurrentRecord = 1976 then
    asm
    nop
    end;
    }
     goto 1;
     end;
  2:
  // LoadingInLogFile := False;
  LogSourceClose;

  (* THE LIST IS TOLD HOW MANY RECORDS THERE ARE, ONCE, AFTER THE WALK.

    It is a virtual list: nothing is inserted during the loop, so this call is
    what makes the log appear at all.

    IT WAS BRIEFLY INSIDE THE `Size < 0` ERROR BRANCH ABOVE, where it ran only
    when the log could NOT be read -- so the grid was blank, and two attempts
    at fixing the CONTROL found nothing wrong with it because nothing was.
    Instrumentation settled it in one run: "created ... columns=14 count=0" and
    then no count line at all.

    Size, not riTotalRecordsInLog: that total counts QTC and note records as it
    walks, and the list is indexed over log RECORDS. *)
  if Size > 0 then
     begin
     TR4WEditableLogRefreshCount;
     TR4WEditableLogScrollToEnd;
     end;
  // DispalyLoadedQSOs(-1);
  IntitialExLoaded := True;
  Sheet.SetUpRemainingMultiplierArrays;
  UpdateWindows;
  Sheet.SaveRestartFile;

  (* THE COLUMN WIDTHS ARE THE GRID'S OWN BUSINESS NOW. It sizes them on every
    resize and on a column rebuild, honouring the operator's saved overrides --
    see TLogGrid.SizeColumns. EnsureListViewColumnVisible, which restored them
    by hand through a window handle, is deleted. *)
  ReCalculateHourDisplay;
{$IF tDebugMode}
  QuickDisplay(inttopchar(GetTickCount64 - T1));
  // showint(m);
{$IFEND}
  if contest = RADIOYOC then // 4.53.2 // 4.72.9
     begin
     PrevNr := copy(IntToStr(TempRXData.NumberReceived), 1, 3); // 4.53.2
     end;
end;

(* WHERE A COLUMN'S TEXT GOES.

  The 31 widget calls in BuildLogRow became this one. With aCollect nil the
  behaviour is exactly what it always was -- the same LVM_SETITEM with the same
  elvi -- and otherwise the same text lands in an array instead.

  UNIT LEVEL, NOT NESTED, AND THAT IS NOT A STYLE CHOICE. Nested inside
  BuildLogRow they segfaulted the program at EXIT: that routine declares labels
  and contains a goto, and giving it a static link produced code that did not
  survive finalization. Measured -- /EXPORT returned 139 with the helpers
  nested and 0 with them lifted out, everything else identical. Do not move
  them back in.

  THE COLUMN IS RECOVERED FROM elviCol, which holds ColumnsArray[c].pos
  rather than Ord(c). The reverse lookup is a scan because the forward mapping
  IS ColumnsArray; a second table would be a second thing to drift. *)
function ColumnAtPos(aPos: integer): LogColumnsType;
var
   c: LogColumnsType;
begin
   Result := Low(LogColumnsType);
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if ColumnsArray[c].pos = aPos then
         begin
         Result := c;
         Exit;
         end;
      end;
end;

(* THE LIST-VIEW HALF IS GONE (2026-09-06), because its last caller is.

  It was

     if aInsert then ListView_InsertItem(...) else ListView_SetItem(...);

  reached only when aCollect was nil, which meant "write straight into a Win32
  list view". The one window still doing that -- the multi-op server-log sync
  dialog -- is a TLogGrid now, so nothing passes nil and those were the last
  two live ListView_ calls in the program. aInsert distinguished the first
  column from the rest and has nothing left to distinguish. *)
(* TWO VALUES, NOT A comctl32 STRUCT (2026-09-08).

  This took a var parameter of the list-view ITEM type and read exactly two of
  its fields. The note in BuildLogRow had already worked out that it was a
  carrier rather than a list-view item, and that replacing it "touches all 31
  emit sites in a routine full of labels and gotos, so it is a change of its
  own".

  This is that change, and it was the LAST THING stopping MainUnit compiling
  for a non-Windows target.

  WHERE THE TYPE ACTUALLY CAME FROM, since a comment in the uses clause said
  otherwise and I believed it first: the WINDOWS unit, which declares it in
  rtl/win/wininc/struct.inc. Not from uCommctrl -- that unit does not exist in
  this tree and nothing imported it. Verified by grep and by the compiler,
  after NY4I pointed out that a commctrl unit in an LCL application makes no
  sense; it made none because it was not there.

  MECHANICAL AND EXACT. All 31 call sites had one identical shape, and the two
  fields became two locals assigned in the same order at the same points, so
  the sequence of (column, text) pairs reaching aCollect is unchanged. That is
  what makes it checkable against a log window opened before it.

  STILL A PAnsiChar, deliberately. Passing a `string` would retire the
  RowTextAnsi and FreqAnsi buffers that exist only to keep the text alive --
  a real simplification, and a SEPARATE one, because it changes what each of
  the 36 assignments has to produce. See docs/WIN32_ARTIFACT_SWEEP.md. *)
procedure EmitCol(const aColumn: Integer; const aText: PAnsiChar;
                  aCollect: PLogRowText);
begin
   aCollect^[ColumnAtPos(aColumn)] := string(AnsiString(aText));
end;

procedure BuildLogRow(RXData: ContestExchange; aCollect: PLogRowText);
label
  SetItem, Domestic; //n4af
var
  (* WAS a single comctl32 list-view item. Two plain locals now -- see
    EmitCol. Named for what they carry: the column POSITION and its text. *)
  elviCol: Integer;
  elviText: PAnsiChar;
  Mults: Cardinal;
  MultString: array[0..7] of AnsiChar;
  FreqAnsi: AnsiString;   // D12: persistent buffer for pszText (see freq column below)
  RowTextAnsi: AnsiString;   // the same, for the rkNote and deleted-QSO captions
begin

  (* elvi IS A CARRIER, NOT A LIST-VIEW ITEM, and has been since the last
    list view went. Only two of its fields are read: iSubItem names the column
    by POSITION and pszText holds that column's text. iItem numbered a row in a
    widget and is gone with it, and so is the var Index that fed it.

    Replacing the struct with a plain (column, text) pair is a real
    simplification -- it also retires the PAnsiChar buffers below -- but it
    touches all 31 emit sites in a routine full of labels and gotos, so it is a
    change of its own. *)
  (* The Mask assignment is gone with the struct. It told ListView_SetItem
    which fields of the item were meaningful, and there is no list view. *)
  elviCol := ColumnsArray[logColBand].pos; //Ord(logColBand);

  if RXData.ceRecordKind = rkNote then
     begin
     RowTextAnsi := LclText(RC_NOTE);   elviText := PAnsiChar(RowTextAnsi);
     EmitCol(elviCol, elviText, aCollect);
     elviCol := ColumnsArray[logColCallsign].pos; //(logColCallsign);
     elviText := @RXData.Prefix;
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  (* THE BLANK ROW IS GONE WITH THE SECOND FLAG.

    This arm inserted a row with NO TEXT for a ceQSO_Skiped record -- the thing
    Alt-Y left behind, and what NY4I called "a very DOS way to do it". It was
    only reachable because skipped and deleted were two flags; they are one now,
    so a deleted QSO falls into the arm below and says DELETED instead of
    showing a hole in the log.

    HIDING IT ENTIRELY IS THE DESTINATION, not this change: deleted QSOs stop
    being listed at all, with a "Show deleted QSOs" toggle in the Edit Log
    window to bring them back and restore them. That needs the virtual list, so
    it lands with D1. Saying DELETED is strictly better than saying nothing in
    the meantime. *)

  if RXData.ceQSO_Deleted then
     begin
     RowTextAnsi := LclText(RC_DELETED);   elviText := PAnsiChar(RowTextAnsi);
     EmitCol(elviCol, elviText, aCollect);
     Exit;
     end;

  // if RXData.ceFMMode then TempMode := FM else TempMode := RXData.Mode;

  // P1 := BandStringsArray[RXData.Band];
  // P2 := ModeString[RXData.Mode];
  // Issue #997: removed empty asm (commented push p1/p2); Format below does it.
  TF.Format(LogDisplayBuffer, TWO_STRINGS, BandStringsArray[RXData.Band],
    ModeStringArray[RXData.Mode]);

  elviText := LogDisplayBuffer;
  EmitCol(elviCol, elviText, aCollect);

  {
  aYear := (RXData.tSysTime.qtYear + 2000) mod 100;
  aMonthString := MonthTags[RXData.tSysTime.qtMonth];
  asm
  push aYear
  push aMonthString
  movzx eax, RXData.tSysTime.qtDay
  push eax
  end;
  wsprintf(LogDisplayBuffer, '%02d-%s-%02d');
  asm add esp,20
  end;
  }
  elviCol := ColumnsArray[logColDate].pos;
  // elviText := LogDisplayBuffer;
  elviText := tGetDateFormat(RXData.tSysTime);
  EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem

  TF.Format(LogDisplayBuffer, '%.2d:%.2d', RXData.tSysTime.qtHour,
    RXData.tSysTime.qtMinute);
  elviCol := ColumnsArray[logColTime].pos; //Ord(logColTime);
  elviText := LogDisplayBuffer;
  EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem

  CID_TWO_BYTES[0] := RXData.ceComputerID;
  elviCol := ColumnsArray[logColComputerID].pos; //Ord(logColComputerID);
  elviText := @CID_TWO_BYTES;
  EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem

  if RXData.ceRecordKind = rkNote then
     begin
     Exit;
     end;
  if RXData.NumberSent <> -1 then
     begin
     elviCol := ColumnsArray[logColNumberSent].pos; //Ord(logColNumberSent);
     elviText := inttopchar(RXData.NumberSent {+10020});
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  elviCol := ColumnsArray[logColCallsign].pos; //Ord(logColCallsign);

  if RXData.ceRecordKind in [rkQTCR, rkQTCS] then
     begin
     TF.Format(LogDisplayBuffer, 'QTC: %s', @RXData.Callsign[1]);
     elviText := LogDisplayBuffer;
     end
  else
     begin
     elviText := @RXData.Callsign[1]; //@RXData.Callsign[1];
     end;
  EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem

  if ColumnsArray[logColNumberReceive].Enable then
    if RXData.NumberReceived <> -1 then
       begin
       elviCol := ColumnsArray[logColNumberReceive].pos;
       //Ord(logColNumberReceive);
       elviText := inttopchar(RXData.NumberReceived);
       EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
       end;

  if RXData.ceRecordKind in [rkQTCR, rkQTCS] then
     begin
     elviCol := ColumnsArray[logColQTC].pos; //Ord(logColQTC);
     TF.Format(LogDisplayBuffer, '%.4d %s', RXData.NumberSent, @RXData.Kids[1]);
     elviText := LogDisplayBuffer;
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem

     elviCol := ColumnsArray[logColNumberSent].pos; //Ord(logColNumberSent);
     elviText := @RXData.RandomCharsReceived[1];
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     Exit;
     end;

  if ColumnsArray[logColClass].Enable then
     begin
     elviCol := ColumnsArray[logColClass].pos; //Ord(logColDXMult);
     elviText := @RXData.ceClass[1];
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  if ColumnsArray[logColDXMult].Enable then
     begin
     elviCol := ColumnsArray[logColDXMult].pos; //Ord(logColDXMult);
     elviText := @RXData.DXQTH[1];
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  if ColumnsArray[logColZoneMult].Enable then
     begin
     if RXData.Zone <> DUMMYZONE then
        begin
        elviCol := ColumnsArray[logColZoneMult].pos; //Ord(logColZoneMult);
        elviText := inttopchar(RXData.Zone);
        EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
        end;
     end;

  if ((ColumnsArray[logColPower].Enable) and (Contest <> FOCMARATHON)) then
    //n4af 4.32.5
     begin
     if RXData.Power <> '' then
        begin
        elviCol := ColumnsArray[logColPower].pos;
        elviText := @RXData.Power[1];
        EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
        end;
     end
  else if (ColumnsArray[logColFOC].Enable) then
     begin
     elviCol := ColumnsArray[logColFOC].pos;
     elviText := @RXData.Power[1];
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem

     end;

  if ColumnsArray[logColPrefixMult].Enable then
     begin
     elviCol := ColumnsArray[logColPrefixMult].pos; //Ord(logColPrefixMult);
     elviText := @RXData.Prefix[1];
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  Mults := 0;
  if RXData.DXMult then
    if RXdata.DomesticMult then
       begin
       goto Domestic //n4af
       end
    else
       begin
       MultString[Mults] := 'x';
       inc(Mults);
       end;
  Domestic:

  if RXData.DomesticMult then
     begin
     MultString[Mults] := 'd';
     inc(Mults);
     end;

  if RXData.ZoneMult then
     begin
     MultString[Mults] := 'z';
     inc(Mults);
     end;

  if RXData.PrefixMult then
     begin
     MultString[Mults] := 'p';
     inc(Mults);
     end;

  // Mults := Ord(RXData.DXMult) + Ord(RXData.DomesticMult) + Ord(RXData.ZoneMult) + Ord(RXData.PrefixMult);

  if Mults <> 0 then
     begin
     MultString[Mults] := #0;
     elviCol := ColumnsArray[logColTotalMults].pos; //Ord(logColTotalMults);
     elviText := MultString; //inttopchar(Mults);
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  if ColumnsArray[logColPrecedence].Enable then
     begin
     elviCol := ColumnsArray[logColPrecedence].pos; //rd(logColPrecedence);
     CID_TWO_BYTES[0] := RXData.Precedence;
     elviText := CID_TWO_BYTES;
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  if ColumnsArray[logColCheck].Enable then
     begin
     // if RXData.Check <> 0 then //n4af 4.34.7
     begin
       elviCol := ColumnsArray[logColCheck].pos; //Ord(logColCheck);
       elviText := inttopchar(RXData.Check);
       EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;
     end;

  if ColumnsArray[logColChapter].Enable then
     begin
     if RXData.Chapter <> '' then
        begin
        elviCol := ColumnsArray[logColChapter].pos; //Ord(logColCheck);
        elviText := @RXData.Chapter[1];
        EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
        end;
     end;

  if ColumnsArray[logColQTH].Enable then
     begin
     elviCol := ColumnsArray[logColQTH].pos; //Ord(logColQTH);
     if DoingDomesticMults then
        begin
        if LiteralDomesticQTH then
           begin
           elviText := @RXData.QTHString[1]
           end
        else
           begin
           elviText := @RXData.DomesticQTH {DomMultQTH} [1];
           end;
        end
     else
        begin
        elviText := @RXData.QTHString[1];
        end;
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  elviCol := ColumnsArray[logColPoints].pos; //Ord(logColPoints);
  elviText := inttopchar(RXData.QSOPoints);
  EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem

  if ColumnsArray[logColAge].Enable then
     begin
     // if RXData.Age <> 0 then // 4.99.3
     begin
       elviCol := ColumnsArray[logColAge].pos; //Ord(logColAge);
       elviText := inttopchar(RXData.Age);
       EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;
     end;

  if ColumnsArray[logColKids].Enable then
     begin
     elviCol := ColumnsArray[logColKids].pos; //Ord(logColAge);
     elviText := @RXData.Kids[1];
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  if ColumnsArray[logColName].Enable then
     begin
     if RXData.Name <> '' then
        begin
        elviCol := ColumnsArray[logColName].pos; //Ord(logColName);
        elviText := @RXData.Name[1];
        EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
        end;
     end;
  if RXData.ceSearchAndPounce then
    // if RXData.tSearchAndPounce then
     begin
     elviCol := ColumnsArray[logColSearchAndPounce].pos;
     //Ord(logColSearchAndPounce);
     elviText := '$';
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  if RXData.ceDupe then
     begin
     elviCol := ColumnsArray[logColDupe].pos; //Ord(logColDupe);
     elviText := 'D';
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  if RXData.Frequency <> 0 then
     begin
     elviCol := ColumnsArray[logColFreq].pos; //Ord(logColFreq);
     // boundary: log ListView is still LV_ITEMA; hold the freq text in a
     // function-scoped AnsiString so pszText stays valid through ListView_SetItem
     // (FreqToPChar now returns a managed string temporary that dies at statement
     // end).  W-flip tracked with the ListView A->W surface.
     FreqAnsi := AnsiString(FreqToPChar {FreqToPCharWithoutHZ}(RXData.Frequency));
     elviText := PAnsiChar(FreqAnsi);
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  if RXData.ceOperator[0] <> #0 then
     begin
     elviCol := ColumnsArray[logColOperator].pos;
     elviText := RXData.ceOperator;
     EmitCol(elviCol, elviText, aCollect);   // Issue #997: was asm call setitem
     end;

  (* THE X-QSO FLAG NO LONGER TRAVELS IN A ROW'S lParam.

    SetRowXQSOFlag stashed it there so the main window's NM_CUSTOMDRAW handler
    could grey the row without re-reading the log. Both ends are gone: the log
    is a TLogGrid, and TLogGridRow carries Deleted and XQSO as fields, read
    straight off the record by whoever fetches it. The flag is a property of
    the QSO, and it is now stored as one. *)

  Exit;

  // Issue #997: setitem label-subroutine removed; call sites inline ListView_SetItem.
end;


(* THE ROW AS TEXT, which is now the only way a row is built. *)
procedure LogRowTextFor(const RXData: ContestExchange; out aText: TLogRowText);
var
   c: LogColumnsType;
begin
   for c := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      aText[c] := '';
      end;
   BuildLogRow(RXData, @aText);
end;

procedure LogEnsureVisible;
begin

  if ActiveMainWindow <> awEditableLog then
     begin
     TR4WEditableLogScrollToEnd;
     end;
end;

procedure GenerateCallsignsList(FileName: PAnsiChar);
var
  h: THandle;
  i: integer;
  nNumberOfBytesToWrite: Cardinal;
  InitialExchange: CallString;
  Callsign: CallString;
begin
  // MakeReportFileName('CUSTOM_INITIAL.EX');
  if not tOpenFileForWrite(h, FileName {@ReportsFilename[1]}) then
     begin
     Exit;
     end;
  sWriteFileFromString(h, ';callsign exchange'#13#10#13#10);
  for i := 0 to CallsignsList.Count - 1 do
     begin
     FillChar(InitialExchange, SizeOf(InitialExchange), 0);
     InitialExchange := CallsignsList.GetIniitialExchangeByIndex(i);
     if InitialExchange <> '' then

        begin
        FillChar(Callsign, SizeOf(Callsign), 0);
        Callsign := CallsignsList.Get(i);
        // if tPos(Callsign, '/') = 0 then
        begin
          //if StringHas(InitialExchange, '255 ') then
          // InitialExchange := GetLastString(initialexchange); // 4.90.6
          nNumberOfBytesToWrite := TF.Format(wsprintfBuffer, '%-15s %s'#13#10,
            @Callsign[1], @InitialExchange[1]);
          sWriteFile(h, wsprintfBuffer, nNumberOfBytesToWrite);
        end;

        end;
     end;
  FileClose(h);   { a FILE handle -- sWriteFile above }
end;

procedure MakeAllCallsignsList;
var
  h: THandle;
  i: integer;
  counter: integer;
  QSOs: integer;
  WriteHeader: boolean;
  TempCall: CallString;
begin
  MakeReportFileName('ALLCALLSIGNS.TXT');
  if not tOpenFileForWrite(h, @ReportsFilename[1]) then
     begin
     Exit;
     end;

  sWriteFile(h, wsprintfBuffer, TF.Format(wsprintfBuffer,
    #13#10' %s'#13#10#13#10' Unique callsigns: %u '#13#10, @ContestTitle[1],
    CallsignsList.GetTotalWorkedStations));

  for QSOs := 20 downto 1 do
     begin
     WriteHeader := True;
     counter := 0;
     for i := 0 to CallsignsList.Count - 1 do
        begin
        if CallsignsList.GetQSOs(i) = QSOs then
           begin
           inc(counter);
           if WriteHeader then
              begin

              sWriteFile(h, wsprintfBuffer, TF.Format(wsprintfBuffer,
                #13#10#13#10' %u QSOs:'#13#10' -----------------'#13#10#13#10,
                QSOs));
              end;
           FillChar(TempCall, SizeOf(TempCall), 0);
           TempCall := CallsignsList.Get(i);
           sWriteFile(h, wsprintfBuffer, TF.Format(wsprintfBuffer,
             ' %4u. %s '#13#10, counter, @TempCall[1]));
           WriteHeader := False;
           end;
        end;
     end;

  FileClose(h);   { a FILE handle -- sWriteFile above }
  FilePreview;
end;

procedure tAltE;
label
  1;
begin
  if tPreviousDupeQSOsShowed then
     begin
     Exit;
     end;
  Act_Freq := ActiveRadioPtr.filteredstatus.freq;
  Act_Band := ActiveBand;
  if InactiveRadioptr.LastDisplayedFreq = 0 then
     begin
     goto 1;
     end;
  inAct_Band := InActiveRadioPtr.BandMemory;

  InAct_Freq := InactiveRadioptr.LastDisplayedFreq;
  so2r_swap := true;
  1:
  TR4WEditableLogFocus;
  TR4WEditableLogScrollToEnd;
  //   processreturn;
        // LogEnsureVisible;
end;

procedure SetWindowSize;
//const
// ewh : array[1 + 12..15 + 12] of REAL = (12.6, 13.7, 13.7, 15.7, 16.8, 18, 18, 20, 20.6, 20.6, 22.8, 23.8, 23.8, 25.8, 25.75);
begin

  ws := WindowSize + 12;

  ws2 := ws div 4;
  // EditableLogWindowHeight := //Trunc((LinesInEditableLog + 1) * ewh[ws]) + 1;
  // (LinesInEditableLog + 1) * ws + ws2 + 12;

  (* NY4I asked whether this still needs GetSystemMetrics. It does not need
    it at all: MainWindowCaptionAndHeader was ASSIGNED HERE AND READ NOWHERE.
    Measured comment-stripped across every .pas/.lpr/.inc in the tree outside
    the vendored include/ -- two occurrences, this line and its declaration in
    VC.pas, both deleted.

    It was the Win32 main window's non-client height, added to a computed
    MainWindowHeight; that arithmetic is the commented-out block above, because
    an LCL form sizes itself and its caption and menu are the LCL's business.

    IF A NON-CLIENT HEIGHT IS EVER WANTED AGAIN, the LCL answer is not
    GetSystemMetrics -- which LCLIntf does provide cross-platform -- but
    `Form.Height - Form.ClientHeight`, which is the real number for that form
    on that window manager rather than a system average. *)

  //MainWindowHeight := EditableLogWindowHeight + 14 * ws + 7 + MainWindowCaptionAndHeader;

  RightTopWidth := 14 * ws;

  //line1 := ws * 7 + EditableLogWindowHeight + 0;
  //Line2 := line1 + ws;
  //Line3 := line1 + ws * 2;
  //Line4 := line1 + ws * 3 {+ 12};
  //Line5 := line1 + ws * 4;
  //line6 := line1 + ws * 5;
  //Line7 := line1 + ws * 6;
  //line8 := line1 + ws * 7;

  //col2 := 4 * ws;
  //col3 := 8 * ws;
  //col4 := 15 * ws;

  //col5 := col4 + 10 * ws;
  //col6 := col5 + 3 * ws;
  //col7 := col6 + 3 * ws;
  //col8 := col7 + 2 * ws;
  //col9 := col8 + 5 * ws;
  //col10 := col9 + 4 * ws;
  //col11 := col10 + 2 * ws {50};

  MainWindowChildsWidth := 46 * ws; //col11 + ws * 2; //MainWindowWidth - 8+8;
  MainWindowWidth := MainWindowChildsWidth + 7;

  MainWindowEditHeight := ((ws * 3) div 2) - 1 {ws + 4};
  FKButtonWidth := ws * 4 - 3;
end;

procedure tUpdateLog(UpdAction: UpadateAction);
label
  1, 2, 3, 4;
var
  MapFin: Cardinal;
  MapBase: Pointer;
  (* A RECORD, not a pointer into a memory map. *)
  RescoredRXData: ContestExchange;
  (* What it looked like before this pass, so only real changes are written. *)
  RescoredBefore: ContestExchange;
  LogSize: Int64;
  QSOCounter: Cardinal;
  // Snapshot of fields that actRescore can mutate, captured before the
  // rescore work so we can log a single line per record describing the
  // before/after when anything actually changed.  Useful for catching
  // silent rescore-induced corruption (e.g. rover-call /M -> DX=G).
  beforeCountryID : DXMultiplierString;
  beforePrefix    : PrefixMultiplierString;
  beforeDXQTH     : DXMultiplierString;
  beforeDomMult   : Boolean;
  beforeDXMult    : Boolean;
  beforePrefixMult: Boolean;
  beforeZoneMult  : Boolean;
  beforeQSOPoints : Word;
  beforeDupe      : Boolean;
begin

  (* ROWS, NOT A MEMORY MAP -- step B5.

    This mapped the whole .TRW PAGE_READWRITE and walked it by pointer,
    mutating records where they lay and flushing the view at the end. It was a
    good fit for a flat file of fixed-width records and it is not portable to
    anything else: there is no file to map now.

    THE LOOP BODY IS UNCHANGED. Every statement in it operated on
    RescoredRXData, which is a local record here instead of a pointer into a
    mapping. Rewriting the body as well would have meant a difference in the
    rescore could have come from the rewrite rather than from the store.

    ONLY CHANGED ROWS ARE WRITTEN, which the mapping got for free: a record the
    rescore did not touch was simply left alone in the file. CompareMem against
    a snapshot restores that property, and it matters -- a rescore of a
    thousand-QSO log would otherwise issue a thousand UPDATEs to write back
    values that never changed. *)
  if not LogSourceOpen then
     begin
     Exit;
     end;
  LogSize := LogSourceRecordCount;
  if LogSize <= 0 then
     begin
     goto 2;
     end;
  QSOCounter := 0;

  if UpdAction = actRescore then
     begin
     // LoadingInLogFile := True;
     Sheet.DisposeOfMemoryAndZeroTotals;
     end;
  1:
  if not LogSourceReadAtIndex(QSOCounter, RescoredRXData) then
     begin
     goto 4;
     end;
  RescoredBefore := RescoredRXData;

  if RescoredRXData.ceRecordKind = rkQSO then
     begin
     if UpdAction = actSetClearDupesheetBit then
        begin
        RescoredRXData.ceClearDupeSheet := True;
        end;

     if UpdAction = actResetClearDupesheetBit then
        begin
        RescoredRXData.ceClearDupeSheet := False;
        end;

     if UpdAction = actRescore then
       // Issue #750: X-QSO records stay in the log (for NIL protection
       // of the worked station) but are deliberately excluded from
       // every scoring artifact -- the rescore rebuilds the dupe
       // sheet, mult sheet, and totals from this loop, so skipping
       // X-QSO from the main scoring path makes them invisible to
       // dupe checking, mults, and totals.  We ALSO zero out the
       // record's own QSOPoints and ceDupe fields so the editable log
       // displays a consistent "0" in the Pts column for every
       // X-QSO record (matches DXLog.net's convention -- N1MM keeps
       // the historical points, but a consistent visual signal is
       // more useful at a glance).  The contact still exports to
       // ADIF and Cabrillo (with the `X-QSO:` prefix instead of `QSO:`).
       if RescoredRXData.ceQSO_Deleted = False then
         if RescoredRXData.ceQSO_Deleted = False then
         if RescoredRXData.ceXQSO then
            begin
            RescoredRXData.QSOPoints := 0;
            RescoredRXData.ceDupe    := False;
            end
         else
            begin
            // Snapshot before rescore so we can report what (if anything) changed.
            beforeCountryID  := RescoredRXData.QTH.CountryID;
            beforePrefix     := RescoredRXData.Prefix;
            beforeDXQTH      := RescoredRXData.DXQTH;
            beforeDomMult    := RescoredRXData.DomesticMult;
            beforeDXMult     := RescoredRXData.DXMult;
            beforePrefixMult := RescoredRXData.PrefixMult;
            beforeZoneMult   := RescoredRXData.ZoneMult;
            beforeQSOPoints  := RescoredRXData.QSOPoints;
            beforeDupe       := RescoredRXData.ceDupe;

            if DoingPrefixMults then
               begin
               FillChar(RescoredRXData.QTH, SizeOf(RescoredRXData.QTH), 0);
               FillChar(RescoredRXData.DXQTH, SizeOf(RescoredRXData.DXQTH), 0);
               // State-QP rover (KG1S/MON): strip suffix for country lookup so
               // /M doesn't get misread as a GB prefix.  Without this the
               // rescore wipes the correct USA lookup done at log-time and
               // restamps the record as DX=G.
               ctyLocateCallStripRover(RescoredRXData.Callsign, RescoredRXData.QTH);
               SetPrefix(RescoredRXData);
               end;
            // if (RXData.Prefix <> '') and DoingPrefixMults then
            {
          if RescoredRXData.Callsign = 'RP7X' then
          asm
          nop
          end;
          }

            if DoingZoneMults or DoingDXMults then
               begin
               FillChar(RescoredRXData.QTH, SizeOf(RescoredRXData.QTH), 0);
               FillChar(RescoredRXData.DXQTH, SizeOf(RescoredRXData.DXQTH), 0);
               // State-QP rover (KG1S/MON): strip suffix for country lookup so
               // /M doesn't get misread as a GB prefix.  Without this the
               // rescore wipes the correct USA lookup done at log-time and
               // restamps the record as DX=G.
               ctyLocateCallStripRover(RescoredRXData.Callsign, RescoredRXData.QTH);
               GetDXQTH(RescoredRXData);
               //.DXQTH := RescoredRXData.QTH.CountryID;
               end;

            {rk4wwq}
            // RescoredRXData.ceContest := Contest;
            {
          if RescoredRXData.Zone = 255 then
          begin
          if (RescoredRXData.NumberReceived > 999) and (RescoredRXData.NumberReceived < 9999) then
          begin
          asm nop end;
          RescoredRXData.Zone := RescoredRXData.NumberReceived div 1000;
          RescoredRXData.NumberReceived := RescoredRXData.NumberReceived mod 1000;
          end;
          end;
          }
            {rk4wwq}

            if RescoredRXData.id = '' then
               begin
               RescoredRXData.id := GetGUID;
               end;

            Sheet.SetMultFlags(RescoredRXData);
            CalculateQSOPoints(RescoredRXData);
            if (not tAllowDupeQSOs) and (RescoredRXData.ceClearDupeSheet = False)
              and (VisibleLog.CallIsADupe(RescoredRXData.Callsign,
              RescoredRXData.Band, RescoredRXData.Mode)) then
               begin
               RescoredRXData.QSOPoints := 0;
               RescoredRXData.ceDupe := True;
               end
            else
               begin
               RescoredRXData.ceDupe := False;
               end;

            // Report whenever actRescore actually mutated a record.  One line
            // per changed record makes silent rescore-induced corruption
            // (rover-call DX=G, mult-flag flip, points change, etc.) visible.
            if (beforeCountryID  <> RescoredRXData.QTH.CountryID) or
               (beforePrefix     <> RescoredRXData.Prefix)        or
               (beforeDXQTH      <> RescoredRXData.DXQTH)         or
               (beforeDomMult    <> RescoredRXData.DomesticMult)  or
               (beforeDXMult     <> RescoredRXData.DXMult)        or
               (beforePrefixMult <> RescoredRXData.PrefixMult)    or
               (beforeZoneMult   <> RescoredRXData.ZoneMult)      or
               (beforeQSOPoints  <> RescoredRXData.QSOPoints)     or
               (beforeDupe       <> RescoredRXData.ceDupe) then
               begin
               logger.Info('[actRescore] %s [%d] changed: ' +
                  'CountryID [%s]->[%s] Prefix [%s]->[%s] DXQTH [%s]->[%s] ' +
                  'DomMult %s->%s DXMult %s->%s PrefixMult %s->%s ZoneMult %s->%s ' +
                  'QSOPoints %d->%d Dupe %s->%s',
                  [string(RescoredRXData.Callsign), QSOCounter,
                   string(beforeCountryID),  string(RescoredRXData.QTH.CountryID),
                   string(beforePrefix),     string(RescoredRXData.Prefix),
                   string(beforeDXQTH),      string(RescoredRXData.DXQTH),
                   BoolToStr(beforeDomMult,    True), BoolToStr(RescoredRXData.DomesticMult, True),
                   BoolToStr(beforeDXMult,     True), BoolToStr(RescoredRXData.DXMult,       True),
                   BoolToStr(beforePrefixMult, True), BoolToStr(RescoredRXData.PrefixMult,   True),
                   BoolToStr(beforeZoneMult,   True), BoolToStr(RescoredRXData.ZoneMult,     True),
                   beforeQSOPoints, RescoredRXData.QSOPoints,
                   BoolToStr(beforeDupe, True), BoolToStr(RescoredRXData.ceDupe, True)]);
               end;

            Sheet.AddQSOToSheets(@RescoredRXData, False);
            CallsignsList.AddCallsign(RescoredRXData.Callsign,
              RescoredRXData.Mode, RescoredRXData.Band,
              RescoredRXData.ceClearDupeSheet);
            end;

     if UpdAction = actClearMults then
        begin
        RescoredRXData.ceClearMultSheet := True;
        RescoredRXData.DomesticMult := False;
        RescoredRXData.DXMult := False;
        RescoredRXData.PrefixMult := False;
        RescoredRXData.ZoneMult := False;
        end;
     end;
  (* The mapping wrote back implicitly; this says so. *)
  if not CompareMem(@RescoredBefore, @RescoredRXData, SizeOf(ContestExchange)) then
     begin
     LogStoreUpdateQSOAtIndex(QSOCounter, RescoredRXData);
     end;

  inc(QSOCounter);
  if QSOCounter <> LogSize then
     begin
     goto 1;
     end;
  4:
  2:
  LogSourceClose;

  if UpdAction = actRescore then
     begin
     Sheet.SetUpRemainingMultiplierArrays;
     Sheet.SaveRestartFile;
     // LoadingInLogFile := False;
     end;
end;

(* THE BINARY .TRW PRIMITIVES, ON THE RTL (2026-09-08, NY4I).

  These four are one set -- they all act on the LogHandle global -- so they
  convert together or not at all. FileOpen, FileSeek, FileRead and FileClose
  take the very same THandle and on Windows ARE CreateFile, SetFilePointer,
  ReadFile and CloseHandle, so this is a spelling change.

  WHAT THIS IS STILL FOR, since the database is the default read source: the
  historical .TRW is what an operator upgrading actually has on disk, and it is
  what the ADIF import appends to and what the version-block reader walks. It
  is a converter's path, not the log-reading path -- ReCalculateHourDisplay was
  the last routine using it to ask a question the database can answer, and it
  no longer does.

  fmShareDenyNone matches FILE_SHARE_READ or FILE_SHARE_WRITE. There is no RTL
  equivalent of FILE_FLAG_SEQUENTIAL_SCAN and none is wanted: it is a cache
  hint, not semantics. *)
function tSetFilePointer(lDistanceToMove: LONGINT; aOrigin: Longint): Int64;
begin
  (* SysUtils' fsFrom* origins, not Win32's dwMoveMethod. The VALUES are
    identical -- FILE_BEGIN/CURRENT/END and fsFromBeginning/fsFromCurrent/
    fsFromEnd are both 0/1/2 -- so this is the same seek; what changes is that
    the two remaining callers no longer import Windows constants.

    Longint, not Classes' TSeekOrigin: fsFrom* ARE Longint constants in
    SysUtils, and FileSeek's Int64 overload takes a Longint origin. Those two
    spellings are easy to confuse and the compiler catches it.

    IT RETURNS THE NEW POSITION NOW. The old body threw SetFilePointer's result
    away and returned Low(Cardinal) unconditionally, so every caller that
    looked at it saw 0 whether the seek worked or not. No caller did look;
    returning the truth costs nothing and removes a trap. *)
  Result := FileSeek(LogHandle, Int64(lDistanceToMove), aOrigin);
end;

function OpenLogFile: boolean;
var
  h: THandle;
begin
  h := FileOpen(StrPas(TR4W_LOG_FILENAME), fmOpenReadWrite or fmShareDenyNone);
  Result := h <> THandle(feInvalidHandle);
  if Result then
     begin
     LogHandle := h;
     end;
end;

procedure CloseLogFile;
begin
  FileClose(LogHandle);
end;

function ReadLogFile: boolean;
begin
  (* FileRead returns the byte count directly, where ReadFile returned it
    through a var parameter. The test is the same one: a whole record, or the
    caller stops. *)
  Result := FileRead(LogHandle, TempRXData, SizeOf(ContestExchange)) =
            SizeOf(ContestExchange);
end;

(* THE B4 LIST AND THE LOG SHARE ONE RECTANGLE, so showing either hides the
  other. Both are LCL grids now -- see TR4WPreviousDupesShow, which owns the
  swap. This held two window handles in an array indexed by the boolean, and
  one of them was never assigned. *)
procedure ShowPreviousDupeQSOsWnd(show: boolean);
begin
  tPreviousDupeQSOsShowed := show;
  TR4WPreviousDupesShow(show);
end;

procedure TryPutSpaceinExchangeWindow;
var
  Selection: TSelection;
begin
  Selection.StartPos := EntrySelStart(TR4WExchangeEdit);
  Selection.EndPos   := Selection.StartPos + EntrySelLength(TR4WExchangeEdit);

  if Selection.StartPos = Selection.EndPos then
    if Selection.StartPos = length(ExchangeWindowString) then
      if (Selection.StartPos = 0) or
        (ExchangeWindowString[length(ExchangeWindowString)] <> ' ') then
         begin
         QueueAppendSpaceToExchange;
         end;

end;

procedure ShowInformation;
var
  // TempMode : ModeType;
  // TempBand : BandType;
  Index: integer;
  QSOs: integer;
begin

  DisplayCountryName(CallWindowString);

  DisplayBeamHeading(CallWindowString, '');

  tCallWindowStringIsDupe := VisibleLog.CallIsADupe(CallWindowString,
    ActiveBand, ActiveMode);
  DispalayB4(integer(tCallWindowStringIsDupe));

  if not CallsignsList.FindCallsign(CallWindowString, Index) then
     begin
     Exit;
     end;
  QSOs := CallsignsList.GetQSOs(Index);
  DisplayQSOsWithThisStation(QSOs);
end;

procedure QuickQSLProcedure(Key: Char);
begin
  if CallWindowString = '' then
     begin
     Exit;
     end;

  // if (Key = QuickQSLKey1) or (Key = QuickQSLKey2) then
  begin
    if ParametersOkay(CallWindowString, ExchangeWindowString, ActiveBand,
      ActiveMode, ActiveRadioPtr.LastDisplayedFreq, ReceivedData) then
      // if ProcessExchange(ExchangeWindowString, ReceivedData) then

       begin
       if MessageEnable then
          begin

          SendCorrectCallIfNeeded;
          if Key = QuickQSLKey1 then
             begin
             if ActiveMode = Phone then
                begin
                SendCrypticMessage(QuickQSLPhoneMessage)
                end
             else
                begin
                SendCrypticMessage(QuickQSLMessage1);
                end;
             end;
          if Key = QuickQSLKey2 then
             begin
             SendCrypticMessage(QuickQSLMessage2);
             end;
          end;
       TryLogContact;
       end;
  end;
end;

procedure StartSendingNow(FromKeyBoard: boolean);
begin

  if AutoSendCharacterCount > EntrySelStart(TR4WCallEdit) then
     begin
     Exit;
     end;

  if not CheckPTTLockout then
    if (CallWindowString <> '') then
      if not CallAlreadySent then
        if (ActiveMode = CW) then
          if (OpMode = CQOpMode) then
            if (EditingCallsignSent = False) then
              if (not StringIsAllNumbersOrDecimal(CallWindowString)) then
                // if StringHasNumber(CallWindowString) then
                if not (CallWindowString[1] = '\') then
                   begin
                   if not FromKeyBoard then
                     if StringHas(CallWindowString, '/') then
                        begin
                        Exit;
                        end;
                   CallWindowKeyDownProc(integer(StartSendingNowKey));
                   end;
end;

procedure ClearLog;
begin
  // Windows.CopyFileA(NewLogFileName, 'NewLogFileName', False);
  ReplaceLogByServerLog(False);
  if not OpenLogFile then
     begin
     Exit;
     end;

  FillChar(tRestartInfo, SizeOf(tRestartInfo), 0);
  ReadVersionBlock;
  (* FileTruncate, not SetEndOfFile. SetEndOfFile cuts the file at the
    CURRENT position, which ReadVersionBlock just set to the end of the
    header; FileTruncate takes an absolute size, so the position has to be
    named rather than implied. Same result, and it says what it does. *)
  FileTruncate(LogHandle, tSetFilePointer(0, fsFromCurrent));
  CloseLogFile;

  LoadinLog;
  if tr4w_WindowsArray[tw_STATIONS_INDEX].WndForm <> nil then
     begin
     // Was LVM_DELETEALLITEMS on wh[mweStations].  The rows are a model now, so
     // emptying the control alone would leave the model holding every callsign
     // and the two halves out of step for the rest of the contest.
     ClearStationsColumn;
     FillStationsColumn;
     end;
  SendStationStatus(sstQSOs);
end;
{
procedure GetLogColumnsWidth;
var
 col : LogColumnsType;
begin
// for col := logColBand to logColDummy do
// tRestartInfo.riColumnsWidthArray[col] := Windows.SendMessage(_NewELogWindow, LVM_GETCOLUMNWIDTH, integer(col), 0);
end;

procedure SetLogColumnsWidth;
var
 col : LogColumnsType;
begin

// if tRestartInfo.riColumnsWidthArray[logColBand] < 1 then Exit;
// for col := logColBand to logColDummy do
// Windows.SendMessage(
// _NewELogWindow,
// LVM_SETCOLUMNWIDTH,
// integer(col),
// tRestartInfo.riColumnsWidthArray[col]);

end;
}

procedure ReadVersionBlock;
begin
  tSetFilePointer(SizeOfTLogHeader, fsFromBeginning);
end;

procedure MakeTestLog;
var
  h: THandle;
  i: integer;
begin

  if not tOpenFileForWrite(h, 'C:\test.trw') then
     begin
     Exit;
     end;
  sWriteFile(h, LogHeader, SizeOfTLogHeader);

  for i := 1 to 30000 do
     begin

     ClearContestExchange(TempRXData);
     tGetQSOSystemTime(TempRXData.tSysTime);
     TempRXData.Band := Band40;
     TempRXData.Band := BandType(Random(6));
     TempRXData.Mode := ModeType(Random(2));
     SetExtendedModeFromMode(TempRXData);
     TempRXData.Callsign := CD.GetRandomCall;
     TempRXData.NumberSent := i;
     ctyLocateCall(TempRXData.Callsign, TempRXData.QTH);
     TempRXData.DXQTH := TempRXData.QTH.CountryID;
     TempRXData.Zone := ctyGetCQZone(TempRXData.Callsign);
     TempRXData.NumberSent := i;
     TempRXData.NumberReceived := i + 100;
     sWriteFile(h, TempRXData, SizeOf(ContestExchange));
     end;
  FileClose(h);   { a FILE handle -- sWriteFile above }
end;

procedure CompleteCallsign;
var
  MaskPos: integer;
  TempCallsign: CallString;
  MaskInserted: boolean;
begin
  if CompleteCallsignMask = '' then
     begin
     Exit;
     end;
  if pos('*', CompleteCallsignMask) = 0 then
     begin
     Exit;
     end;
  MaskInserted := False;
  TempCallsign := '';
  for MaskPos := 1 to length(CompleteCallsignMask) do
     begin
     if CompleteCallsignMask[MaskPos] <> '*' then
        begin
        TempCallsign := TempCallsign + CompleteCallsignMask[MaskPos];
        end
     else
        begin
        if MaskInserted = False then
           begin
           TempCallsign := TempCallsign + CallWindowString;
           end;
        MaskInserted := True;
        end;
     end;
  PutCallToCallWindow(TempCallsign);
end;

{
function TryToCheckTheLatestVersion: boolean;
begin
 Result := False;
 tGetSystemTime;

 if UTC.wYear * 12 * 30 + UTC.wMonth * 30 + UTC.wDay >= EXPIREDDAY then
 if YesOrNo(
 TC_THISVERSION +
 TR4W_CURRENTVERSION +
 TC_WASBUILDIN +
 TR4W_CURRENTVERSIONDATE +
}

{$IFDEF LANG_ENG}
// ')' +
{$ENDIF}
{
 '.' +
 #13 +
 TC_DOYOUWANTTOCHECKTHELATESTVERSION
 ) = IDYES then
 begin
 OpenURL(TR4W_DOWNLOAD_LINK);
 Result := True;
 end;

end;
}

(* THE CLOCK COMES FROM THE RTL, NOT FROM WINDOWS (2026-09-08).

  Both of these read Windows.GetSystemTime into the VC global UTC. TF already
  had the portable equivalent written FOR THIS -- FillSystemTimeUTC, added
  2026-09-05, which decodes LocalTimeToUniversal into the SAME SYSTEMTIME
  record VC declares on every platform, so nothing downstream changes.

  ONE FIELD IS NOT A STRAIGHT COPY and it is the reason to use the helper
  rather than repeat the four lines here: Win32's wDayOfWeek is 0-based and
  SysUtils.DayOfWeek is 1-based. FillSystemTimeUTC carries the -1. Getting it
  wrong would be invisible until something indexed a day-name array, which
  tree.GetDayString does. *)
procedure tGetSystemTime;
begin
  if not tHandLogMode then
     begin
     TF.FillSystemTimeUTC(UTC);
     end;
{$IF tDebugMode}
  // inc(GetSystemTimeCounter);
  // Windows.SetWindowTextA(tr4whandle, inttopchar(GetSystemTimeCounter));
{$IFEND}
end;

procedure SystemTimeChanging;
begin
  if not tHandLogMode then
     begin
     TF.FillSystemTimeUTC(UTC);   (* see tGetSystemTime *)
     end;
  TR4WMainForm.pnlClock.Caption := GetTimeString;
  TR4WMainForm.pnlFullTime.Caption := GetFullTimeString(False);
  TR4WMainForm.pnlDate.Caption := GetDateString;
end;

function AddRecordToLogAndSendToNetwork(var CE: ContestExchange): boolean;
begin
  CE.ceQSOID1 := STARTTIMEOFTHETR4W;
  CE.ceQSOID2 := GetTickCount64;
  CE.ceComputerID := ComputerID;
  CE.ceContest := Contest;
  CE.Band := ActiveBand;
  CE.Mode := ActiveMode;
  SetExtendedModeFromMode(CE);
  tGetQSOSystemTime(CE.tSysTime);
  CE.ceOperator := CurrentOperator;

  Result := SendRecordToServer(NET_QSOINFO_ID, CE);
  if not Result then
     begin
     inc(tUSQ);
     end;

  tAddQSOToLog(CE);
end;

{ THE CALL-FIELD FLASH.

  WHAT THIS FIXES.  It hid the call field, slept 100 ms, and showed it again
  -- the sleep being on the MAIN THREAD.  (Written as prose, not as the
  original three statements, so that a grep for call sites or for sleeps does
  not find this comment and count it as code.)  Its one call site (ReturnInCQOpMode, the
  operator pressing Enter in CQ mode with AutoDupeEnableCQ set) is commented
  out, so it never ran and nothing froze; uncommenting it as written would have
  frozen the UI for 100 ms on EVERY auto-dupe, at the exact moment the operator
  is typing.  A latent hazard is worth fixing when it is found rather than
  leaving armed for whoever removes the comment (NY4I, 2026-08-23).

  IT ALSO STOPS HIDING THE FIELD.  Hiding and re-showing a focused edit can move
  the caret, which mid-callsign is worse than not flashing at all.  A background
  colour says the same thing and touches nothing the operator is using.

  trAlert from TR4W's own palette rather than a colour invented here -- this
  fires on a DUPE, which is what that entry is for.  The resting colour is read
  at the start rather than assumed, so a theme change cannot leave the field
  stuck on a hardcoded "normal".

  It is the FIRST of the four flashers done the right way: TR4WCallEdit is a
  real LCL TEdit, so it has a .Color.  The quick-display and intercom flashers
  still toggle Enabled and Selected because their targets are still raw Win32
  windows -- see uFlasher. }
var
  gCallFieldFlasher: TFlasher = nil;
  gCallFieldRestColor: TColor = clWindow;

function CallFieldFlasher: TFlasher;
begin
  if gCallFieldFlasher = nil then
     begin
     gCallFieldFlasher := TFlasher.Create;
     end;
  Result := gCallFieldFlasher;
end;

procedure CallFieldFlashPhase(const aOn: boolean);
begin
  if TR4WCallEdit = nil then
     begin
     Exit;
     end;

  if aOn then
     begin
     TR4WCallEdit.Color := gCallFieldRestColor;
     end
  else
     begin
     TR4WCallEdit.Color := tr4wColorsArray[trAlert];
     end;
end;

procedure FlashCallWindow;
begin
  if TR4WCallEdit = nil then
     begin
     Exit;
     end;

  // Read the resting colour now, not at unit load: it is whatever the field
  // actually is when the flash starts.
  gCallFieldRestColor := TR4WCallEdit.Color;

  // Two phases at 100 ms -- one dark, one back to normal, the same beat the
  // hide/Sleep/show had.  The flasher always lands on the resting state, so an
  // interrupted flash cannot leave the field coloured.
  CallFieldFlasher.Start(@CallFieldFlashPhase, 2, 100);
end;

procedure ProcessCommandLine;

begin
  {
  p := GetCommandLine;
  ShowMessage(p);
  l := Windows.lstrlen(p);

  for i := 0 to l - 4 do
  begin
  // Issue #997: asm pointer arith -> Pascal (p := p + i, preserved exactly).
  p := Pointer(Cardinal(p) + Cardinal(i));
  if PInteger(p)^ = 0 then sm;
  end;
  }
end;

procedure PutCallToCallWindow(Call: CallString);
begin
  logger.debug('[PutCallToCallWindow] Putting %s into main call window',
    [Call]);
  Call[Ord(Call[0]) + 1] := #0;
  if call = MyCall then
     begin
     logger.debug('[PutCallToCallWindow] Exiting early because call (%s) = MyCall (%s)', [call, MyCall]);
     exit; // n4af issue 158
     end;
  logger.debug('Putting "%s" into the call field', [Call]);

  { THE DECISION IS ABOVE, THE FIELD WRITE IS BELOW, AND ONLY THE WRITE HAS A
    THREAD REQUIREMENT.  The MyCall check is arithmetic on a string and is
    correct on any thread; touching a TEdit is not.

    THE WSJT-X UDP LISTENER GETS HERE.  Measured, not supposed -- tr4w.log,
    2026-08-29 23:05, thread 23196 (the Indy UDP reader) reaching ENTRYTEXT and
    SETENTRYSEL by this path while WSJT-X called TI1T.  The entry-field guard
    reported it and then, unlike the ELEMENT guard, carried on: ControlUsable
    logs and returns, it does not defer.  So the assignments really did run on
    the listener thread.

    THAT IS ALSO WHY THIS IS ONE DEFERRED OPERATION AND NOT TWO DEFERRED
    ACCESSORS.  The caret goes to the END of the text, so the selection depends
    on the write having already landed; deferring SetEntryText and SetEntrySel
    separately would measure the length of text that was not there yet.

    Main-thread callers -- the other nine, all keyboard paths -- are unchanged
    and still synchronous. }
  if not OnMainThread then
     begin
     QueuePutCallToCallField(string(Call));
     Exit;
     end;

  SetEntryText(TR4WCallEdit, string(Call));
  SetEntrySel(TR4WCallEdit, Length(EntryText(TR4WCallEdit)), 0);
end;

procedure SetColumnsWidth;
var
  i: integer;
  TempColumn: LogColumnsType;
begin
  ColumnsArray[logColPrecedence].Enable := ActiveExchange =
    QSONumberPrecedenceCheckDomesticQTHExchange;
  ColumnsArray[logColCheck].Enable := ActiveExchange =
    QSONumberPrecedenceCheckDomesticQTHExchange;
  ColumnsArray[logColQTC].Enable := QTCsEnabled;
  ColumnsArray[logColAge].Enable := ExchangeInformation.Age;

  ColumnsArray[logColQTH].Enable := ExchangeInformation.QTH;
  ColumnsArray[logColClass].Enable := ExchangeInformation.ClassEI;

  // ColumnsArray[logColDomMult].Enable := ExchangeInformation.QTH and (ActiveDomesticMult <> NoDomesticMults);
  // if ColumnsArray[logColDomMult].Enable then ColumnsArray[logColQTH].Enable := False;

  ColumnsArray[logColName].Enable := ExchangeInformation.Name;
  ColumnsArray[logColZoneMult].Enable := ExchangeInformation.Zone;
  if Contest <> FOCMARATHON then //n4af 4.32.5
     begin
     ColumnsArray[logColPower].Enable := ExchangeInformation.Power;
     end;
  if Contest = FOCMARATHON then //n4af 4.32.5
     begin
     ColumnsArray[logColFOC].Enable := ExchangeInformation.Power; //n4af 4.32.5
     end;
  ColumnsArray[logColChapter].Enable := ExchangeInformation.Chapter;

  ColumnsArray[logColNumberReceive].Enable := ExchangeInformation.QSONumber;
  ColumnsArray[logColPrefixMult].Enable := ActivePrefixMult <> NoPrefixMults;
  ColumnsArray[logColDXMult].Enable := ActiveDXMult <> NoDXMults;
  // ColumnsArray[logColPostCode].Enable := ExchangeInformation.PostalCode;
  ColumnsArray[logColKids].Enable := ExchangeInformation.Kids;
  i := -1;
  for TempColumn := logColBand to High(LogColumnsType) {Pred(logColDummy)} do
    if ColumnsArray[TempColumn].Enable then
       begin
       inc(i);
       ColumnsArray[TempColumn].pos := i;
       end;
end;


(* COLUMN WIDTHS ARE NOT WRITTEN INTO A LOG DATABASE.

  THIS ROUTINE WRITES WITH WritePrivateProfileStringA INTO TR4W_CFG_FILENAME,
  and that name is a .db now. Windows' profile API does not know that: it opens
  the file, PARSES THE WHOLE THING as an INI, and rewrites it. Against a SQLite
  database that is slow enough to look like a hang and has no business
  happening at all.

  MEASURED THREE TIMES, 2026-09-03: the last line in the log before the program
  stopped responding was this routine's own debug line -- "column 1 is now 118
  wide", then "column 13 is now 97 wide". Once while the Edit Log window was
  open, once on shutdown, and NY4I had not touched a column divider on either
  occasion.

  THE DATABASE SURVIVED, which is luck rather than design: integrity_check
  still reports ok, so the API evidently declined to write a file it could not
  parse. It is not a guarantee, and it is not worth relying on.

  BY CONTENT, NOT BY EXTENSION -- ClassifyContestFile, the same test the config
  loader uses. A log an operator renamed to .cfg is still a database.

  WHERE THIS SHOULD END UP: a column width is a UI preference and belongs in
  settings\tr4w.json with the rest of the window layout, not in the contest
  file at all. Recorded rather than done, because that is a settings migration
  and this is a hang. *)
procedure SaveColumnWidthToConfig(ColIndex: Integer; NewWidth: Integer);
var
   TempColumn: LogColumnsType;
   KeyName: ShortString;
   WidthStr: ShortString;
   matched: boolean;
begin
   // ENTERED, and said so.  "The width did not stick" has THREE causes and the
   // logging could only distinguish one of them:
   //
   //   1. the header notification never arrived  -> no line at all
   //   2. it arrived but matched no column       -> the "no column at index" line
   //   3. it matched and the write failed        -> the "could NOT be saved" line
   //
   // Without 1 and 2 spelled out, a silent log looked the same as a working one.
   logger.Debug('[ColumnWidth] header reports column %d is now %d wide',
                [ColIndex, NewWidth]);

   (* See the note above this routine. *)
   if ClassifyContestFile(StrPas(@TR4W_CFG_FILENAME[0])) <> cfkTextConfig then
      begin
      logger.Debug('[ColumnWidth] not saved -- the contest file is not a text ' +
                   '.cfg (%s)', [StrPas(@TR4W_CFG_FILENAME[0])]);
      Exit;
      end;

   matched := False;
   for TempColumn := Low(LogColumnsType) to High(LogColumnsType) do
      begin
      if ColumnsArray[TempColumn].Enable and (ColumnsArray[TempColumn].pos = ColIndex) then
         begin
         if NewWidth > 0 then
            begin
            ColumnWidthOverride[TempColumn] := NewWidth;
            // Use language-neutral canonical name (see VC.pas) so the CFG
            // file is portable across language builds. ColumnsArray[].Text
            // is translated at compile time and would lock the CFG to the
            // language it was written under.
            KeyName := 'COLUMN WIDTH ' + StrPas(ColumnCanonicalName[TempColumn]);
            KeyName[Ord(KeyName[0]) + 1] := #0;
            Str(NewWidth, WidthStr);
            WidthStr[Ord(WidthStr[0]) + 1] := #0;

            // CHECKED, and it never was.  WritePrivateProfileStringA returns a
            // BOOL and this discarded it, so a width the operator dragged went
            // nowhere without a word -- exactly the failure NY4I found on
            // tr4w.ini (2026-08-21), in a second place.
            //
            // The likely causes are worth naming because the operator cannot
            // guess them: no contest is loaded, so TR4W_CFG_FILENAME is not a
            // real path; or the .cfg is read-only.
            (* APPLIED HERE, PERSISTED BY THE LOG.

              An INI write into TR4W_CFG_FILENAME stood here, and that name is
              a .db -- so dragging a column divider asked Windows to parse a
              SQLite database as an INI and rewrite it. Three of NY4I's freezes
              ended on this routine's own log line.

              CheckCommand accepts 'COLUMN WIDTH <token>' (uCFG.pas:1664, inside
              CheckCommand), so the value applies to the running program the
              same way any other command does -- and uLogStore.CaptureConfiguration
              writes the widths into the log's config table at close, beside the
              function-key memories, from where the startup apply restores them.

              SO THE WIDTH IS STILL PER CONTEST, which is what the .cfg gave. It
              is simply in the contest's own file now rather than beside it. *)
            CheckCommand(@KeyName[1], WidthStr);
            logger.Debug('[ColumnWidth] %s = %d applied',
                         [StrPas(ColumnCanonicalName[TempColumn]), NewWidth]);
            end;
         matched := True;
         Exit;
         end;
      end;

   if not matched then
      begin
      // The header gave an index that no ENABLED column claims.  ColumnsArray
      // .pos is recomputed by SetColumnsWidth whenever the contest's exchange
      // changes which columns exist, so an index can outlive the column it
      // referred to.
      logger.Warn('[ColumnWidth] no enabled column sits at index %d -- ' +
                  'width %d was not saved', [ColIndex, NewWidth]);
      end;
end;

procedure ExecuteConfigurationFile(const f: AnsiString);
var
  FirstCommand: boolean;

begin
  RunningConfigFile := True;
  ClearDupeSheetCommandGiven := False;
  FirstCommand := False;
  if utils_file.FileExists(PAnsiChar(f)) then
     begin
     LoadInSeparateConfigFile(f, FirstCommand, MyCall);
     end;
  if ClearDupeSheetCommandGiven then
     begin
     tClearDupesheet;
     end;
  RunningConfigFile := False;

end;

// The custom memory manager that used to live here (NewGetMem / NewFreeMem /
// NewReallocMem / NewMemMgr / SetNewMemMgr) is DELETED.  It was never installed
// in any build we ship -- SetNewMemMgr was called only under {$IF tDebugMode},
// and tDebugMode is False -- and it was unsound in three separate ways:
//
//   - Each hook opened with `add esp,12 / pop PreviousProcAddress / sub esp,16`
//     to reach up the stack for the caller's return address.  That assumed the
//     exact frame layout the Delphi 7 compiler produced.  D12 guarantees no
//     such thing, and the functions also carried a try/except, whose SEH
//     registration record lives on the very stack being indexed by hand.
//   - The except handler called wsprintfA and showwarning FROM INSIDE A GetMem
//     callback that had fired because an allocation just failed -- re-entering
//     the allocator in order to report the allocator.
//   - It was inconsistent: NewReallocMem had none of the address capture, so
//     the three hooks did not behave alike.
//
// What it bought was a diagnostic code in a message box. What it cost was six
// blocks of x86-32 assembly that cannot assemble on a 64-bit compiler.
// If allocation-failure diagnostics are wanted again, the supported route is
// System.GetMemoryManager/SetMemoryManagerEx with ReturnAddress, not hand
// arithmetic on ESP.

procedure CheckEditableWindowHeight;
var
  h: integer;
begin
  (* THE TWO SHRINK/GROW LOOPS THAT STOOD HERE ARE GONE, AND THEY ARE WHAT LEFT
    THE LOG BLANK.

    They set the height and then nudged it a pixel at a time -- up to 200 times
    each, under a guard -- until ListView_GetCountPerPage reported exactly
    LinesInEditableLog rows. That was the fixed-five window made exact: size the
    control so five whole rows fit and no sixth is half-shown.

    IT CANNOT WORK AGAINST A VIRTUAL LIST, and it fails in the worst direction.
    GetCountPerPage on an OwnerData list that has not been given a count yet
    does not answer the question the loop is asking, the condition never became
    false, and the guard ran all 200 iterations -- subtracting 200 from a height
    of 150. Measured on NY4I's machine: created at bounds=(0,154,1012,150),
    and by the time the row count was set, bounds=(0,154,1012,0). A control of
    zero height draws nothing, which is exactly what he saw twice.

    THE QUESTION ITSELF IS RETIRED. The list scrolls now, so there is no reason
    to make a whole number of rows fit: a partly visible row at the bottom edge
    is what the scrollbar is for. The height is the log area's height and
    nothing measures rows to get it.

    LinesInEditableLog SURVIVES ONLY AS THAT HEIGHT, and it goes when the
    ROW COUNT setting is retired -- at which point this reads as the window
    layout it always was. *)
  h := 30 + LinesInEditableLog * (ws + 2);
  TR4WEditableLogSetBounds(0, ws * 7, MainWindowChildsWidth, h);
end;

function CheckCommandInCallsignWindow: boolean;
begin
  Result := true;
  case AnsiIndexText(AnsiUpperCase(CallWindowString),
    ['ADIF', 'CAB', 'CMD', 'COL', 'CWOFF', 'CWON', 'EXIT', 'NOTE', 'OPON',
    'SCORE',
      'SUM', 'UDP', 'WCY', 'WWV',
    // Opens the radio Preferences window.  Appended out of alphabetical order
    // deliberately: AnsiIndexText does not care about order, and slotting it
    // after 'EXIT' would renumber the case arms below, where an off-by-one
    // silently fires the WRONG command.
    //
    // 'FMXTEST' (was 14) and 'FMXDESIGN' (was 16) were removed with the FMX
    // twins on 2026-08-17, which is why PREF and CATLEGACY renumbered here --
    // the one edit this array's ordering rule was written to make deliberate.
    'PREF']) of
    0: ProcessMenu(menu_adif);
    1: ProcessMenu(menu_cabrillo);
    2: RunWindowsUtility('cmd.exe');
    3: ProcessMenu(menu_colors);
    4:
      // TODO: candidate for LogCW.SetCWState(False, ...) once the 'CW Off'/'CW On'
      // quick-display text is parameterized (Issue 380 cleanup). Left inline for now.
      begin
        if CWEnabled or Config.CWEnable then
           begin
           QuickDisplay(TC_CWOFF);
           FlushCWBufferAndClearPTT('MainUnit: CW turned Off');
           CWEnabled := False;
           Config.CWEnable := false;
           DisplayCodeSpeed;
           end;
      end;
    5:
      // TODO: candidate for LogCW.SetCWState(True, ...) (Issue 380 cleanup). Left inline for now.
      begin
        CWEnabled := True;
        Config.CWEnable := true;
        QuickDisplay('CW On');
        DisplayCodeSpeed;
        SetSpeed(CodeSpeed);
      end;
    6: ProcessMenu(menu_exit);
    7: ProcessMenu(menu_ctrl_note);
    8: ProcessMenu(menu_login);
    9: SendScoreToUDP;
    10: ProcessMenu(menu_summary);
    11: SendFullLogToUDP;
    12: SendViaTelnetSocket('SH/WCY');
    13: SendViaTelnetSocket('SH/WWV');
    14: ShowPreferences;
  else
    Result := false; // False result does not clear call window
  end; // case
  Exit;

end;

procedure ClearMultSheet_CtrlC;
begin
  tInputDialogWarning := True;
  if QuickEditResponse(TC_CLEARMULTTOCLEARMULTSHEET, 9) = 'CLEARMULT' then
     begin
     tClearMultSheet;
     end;
end;

procedure tClearMultSheet;
begin
  tUpdateLog(actClearMults);
  LoadinLog;
  QuickDisplay(TC_MULTSHEETCLEARED);
end;

(* BAND CHANGES IN THE CURRENT HOUR, FROM THE DATABASE (2026-09-08, NY4I).

  It walks the log BACKWARDS from the newest QSO and stops at the first one
  from an earlier hour, counting how many times the band changed on the way.
  That is a question about QSOs, and LogSource answers it -- lsDatabase is the
  default read source since step B4, so this routine was the odd one out,
  opening the .TRW by handle and seeking in it by hand.

  THE OLD LOOP BOUND WAS WRONG, and this is the part worth keeping:

      TempFileSize := (Windows.GetFileSize(LogHandle, nil) div 256) * -1;

  A hardcoded 256 for the record size, while the SEEK on the next line used
  SizeOf(ContestExchange). Those disagree: uTestLogRepository measures both
  SizeOf(ContestExchange) and SizeOfTLogHeader at 376 BYTES. So the bound was
  about 1.47x the record count and it also counted the header, and a log whose
  records were ALL in the current hour would keep seeking past the start of the
  file. It survived because the `goto 2` normally fires within a few records --
  the first QSO from a previous hour ends the walk -- so the bad bound was only
  reachable early in a contest or on a small log.

  LogSourceRecordCount is the count of RECORDS. No header arithmetic, no
  hardcoded size, and the walk cannot run off the front.

  THE CONTROL FLOW IS THE SAME, with the three labels named for what they did:
    goto 2  -> Break     a QSO from an earlier hour: the walk is finished
    goto 3  -> Continue  skip this QSO's band, keep walking
    goto 1  -> the loop

  TempRXData is still the global GoodLookingQSO reads, so that predicate and
  everything downstream of it are untouched. *)
procedure ReCalculateHourDisplay;
var
  offsetFromEnd: Int64;
  recordCount: Int64;
  TempBand: BandType;
  TempHour: Byte;
begin
  TempBand := NoBand;
  tGetSystemTime;
  TempHour := UTC.wHour;
  tThisHourBandChanges := 0;

  recordCount := LogSourceRecordCount;
  if recordCount <= 0 then
     begin
     DisplayHour;
     Exit;
     end;

  (* A while, not a for: FPC will not take an Int64 loop counter, and the
    record count is genuinely Int64 -- LogSourceRecordCount answers -1 when it
    cannot read, which the guard above has already excluded. *)
  offsetFromEnd := 0;
  while offsetFromEnd < recordCount do
     begin
     (* THE INCREMENT IS AT THE TOP, and it has to be: there are two Continues
       below, and in a while loop Continue jumps straight to the test. With the
       increment at the bottom the first skipped QSO would spin forever.

       offsetFromEnd = 1 is the LAST record, which is where the backwards walk
       starts -- the old code's FilePointer := -1. *)
     inc(offsetFromEnd);
     if not LogSourceReadFromEnd(offsetFromEnd, TempRXData) then
        begin
        Break;
        end;

     if not GoodLookingQSO then
        begin
        Continue;
        end;

     if TempHour <> TempRXData.tSysTime.qtHour then
        begin
        Break;
        end;

     if tThisHourPreviousBand = NoBand then
        begin
        tThisHourPreviousBand := TempRXData.Band;
        end;

     if TempBand <> TempRXData.Band then
        begin
        if (HourDisplay = BandChangesThisComputer) and
           (TempRXData.ceComputerID <> ComputerID) then
           begin
           Continue;
           end;

        if TempBand <> NoBand then
           begin
           inc(tThisHourBandChanges);
           end;

        TempBand := TempRXData.Band;
        end;
     end;

  DisplayHour;
end;

procedure SetRemMultsColumnWidth;
var
  Width: integer;
  frm: TfrmRemMults;
 // DomWidth: integer;

begin
  // 4.71.2 attempt to allow longer column width for long DOM MULTS by setting SHOW DOMESTIC MULTIPLIER NAME to TRUE
  // FillChar(RemMultsColumnWidthArray, sizeof(RemMultsColumnWidthArray), 0);

  if (tShowDomesticMultiplierName) or (DoingPrefixMults) then
     begin
     Width := PREFIXCOLUMNWIDTH
     end
  else
     begin
     Width := BASECOLUMNWIDTH;
     end;

  // ONLY THE GENERIC WINDOW, and that is not new: the Win32 version sent
  // LB_SETCOLUMNWIDTH to tw_REMMULTSWINDOW_INDEX alone.  The four fixed-type
  // windows were given BASECOLUMNWIDTH once, at creation, and never followed
  // SHOW DOMESTIC MULTIPLIER NAME afterwards.  Left as it was -- it is a real
  // inconsistency and a bench question, not something to change unseen.
  frm := RemMultsForm(tw_REMMULTSWINDOW_INDEX);
  if frm <> nil then
     begin
     frm.Mults.SetCellWidth(Width);
     end;
end;

procedure CheckInactiveRigCallingCQ;

begin
  if SwitchNext then //n4af 4.30.1
    // B1: was (not WKBusy) and (not (CWThreadID <> 0)) -- CAT and YCCC were
    // missing, so the inactive rig could be swapped to while they were still
    // keying.  n4af 4.52.6
    if ((length(CallWindowString) > 0) {or (InactiveSwapRadio)}) and
       (not CWStillBeingSent) then
       begin
       InactiveRigCallingCQ := False;
       scWk_Reset;
       SwapRadios;
       SwitchNext := False; // 4.52.8
       if (not AutoSendEnable) or (not AutoSendCharacterCount > 0) then
         //n4af 4.42.10 Redrive dupe check
          begin
          ReturninCQopmode;
          end;
       ShowInformation;
       end;
  // pRadio := ActiveRadioPtr;
  // if ((ActiveMode = CW) and autosendenable and (not WKBusy)) then
  // {((CWThreadID <> 0) or wkBUSY or pRadio.CWByCAT_Sending))} then
  // begin
  // SwapRadios;
  // inactiverigcallingcq := False;
  // end

end;


(*----------------------------------------------------------------------------*)

// GetADIFMode, GetADIFSubMode, GetADIFBand moved to uADIF.pas (Issue #887).

// ---------------------------------------------------------------------------
// Contest-specific post-processing for an imported ADIF record.
//
// Most ADIF tag-to-ContestExchange mapping is done by uADIF.ApplyADIFFields-
// ToExchange (a pure function, no MainUnit globals).  But for several
// contests, the tag-level value needs contest-aware reinterpretation:
// e.g. for ARRL_RTTY_ROUNDUP, the QTHString is built from RST + STATE in
// a contest-defined format; for POTA, the QTHString comes from POTA_REF
// or SIG_INFO depending on which was supplied.
//
// This routine takes the temps captured during field mapping and applies
// the contest-specific logic.  It uses MainUnit-scope globals
// (currentOperator, ActiveDomesticMult, ActiveExchange, DoingDomesticMults)
// which is why it stays in MainUnit rather than moving to uADIF.
// ---------------------------------------------------------------------------
procedure ApplyContestSpecificADIFTail(const temps: TADIFRecordTemps;
                                       var exch: ContestExchange);
var
  j : Integer;
begin
  // fix up operator
  if exch.ceOperator = '' then
     begin
     exch.ceOperator := currentOperator;
     end;

  if Length(temps.SRX_String) > 0 then
     begin
     exch.ExchString := temps.SRX_String;
     end;

  case exch.ceContest of
    GENERALQSO:
      // Use grid square as exchange for any ADIF source, not just WSJT-X.
      // WSJT-X does not always include PROGRAMID, so gating on FromWSJTX
      // caused ExchString to stay empty when PROGRAMID was absent.
      if temps.GridSquare <> '' then
         begin
         exch.ExchString  := temps.GridSquare;
         exch.QTHString   := temps.GridSquare;
         exch.DomesticQTH := temps.GridSquare;
         end;

    WAG:
      exch.QTHString := temps.SRX_String;

    ARRL160, CQ160CW, CQ160SSB, UBACW, UBASSB:
      exch.DomesticQTH := temps.SRX_String;

    ARRL_RTTY_ROUNDUP:
      begin
        logger.Debug('[ParseADIF] exch.QTH.CountryID = %s',
                     [exch.QTH.CountryID]);
        if (exch.QTH.CountryID = 'K') or (exch.QTH.CountryID = 'VE') then
           begin
           exch.QTHString := IntToStr(exch.RSTReceived) + ' ' + temps.State
           end
        else
           begin
           exch.QTHString := IntToStr(exch.RSTReceived) + ' ' +
                             IntToStr(exch.NumberReceived);
           end;
        exch.ExchString := exch.QTHString;
      end;

    ARRLSSCW, ARRLSSSSB, WINTERFIELDDAY, ARRLFIELDDAY:
      begin
        exch.DomesticQTH := temps.ARRL_Sect;
        exch.QTHString   := temps.ARRL_Sect;
      end;

    CWOPS:
      exch.Age := StrToIntDef(exch.QTHString, 0);

    CQWWCW, CQWWSSB:
      begin
        // For CQWW the QTHString is the zone (as a string); the SRX_STRING
        // carries the zone numerically.
        exch.QTHString := temps.SRX_String;
        exch.zone      := StrToIntDef(temps.SRX_String, 0);
      end;

    FOCMARATHON:
      exch.Power := temps.FOC_Num;

    IARU:
      exch.QTHString := temps.SRX_String;

    NAQSOCW, NAQSOSSB, NAQSORTTY, NCCCSPRINT:
      begin
        exch.QTHString   := temps.State;
        exch.DomesticQTH := temps.State;
        exch.ExchString  := temps.State;
      end;

    UKRAINIAN, OKDX, LZDX:
      if IsAlpha(temps.SRX_String) then
         begin
         exch.DomesticQTH := temps.SRX_String
         end
      else
         begin
         exch.QTHString := temps.SRX_String;
         end;

    POTA:
      if IsValidPOTAPark(temps.POTARef) then
         begin
         if Length(temps.POTARef) = 0 then
            begin
            if AnsiUpperCase(temps.SIG) = 'POTA' then
              if IsValidPOTAPark(temps.SIG_Info) then
                 begin
                 exch.QTHString := temps.SIG_Info;
                 end;
            end
         else
            begin
            exch.QTHString := temps.POTARef;
            end;
         end
      else
        if LooksLikeAState(temps.State) then
           begin
           exch.QTHString   := temps.State;
           exch.DomesticQTH := temps.State;
           end;

    WWDIGI, ARRLDIGI:
      begin
        exch.ExchString  := temps.GridSquare;
        exch.DomesticQTH := temps.GridSquare;
      end;

  else
    if (ActiveDomesticMult = GridSquares) or
       (ActiveExchange = RSTAndOrGridExchange) or
       (ActiveExchange = Grid2Exchange) or
       (ActiveExchange = RSTAndGrid3Exchange) or
       (ActiveExchange = GridExchange) then
       begin
       exch.QTHString   := temps.GridSquare;
       exch.DomesticQTH := temps.GridSquare;
       exch.ExchString  := IntToStr(exch.RSTReceived) + ' ' + temps.GridSquare;
       end
    else if DoingDomesticMults then
       begin
       if exch.QTHString <> '' then
         // ADIF QTH tag carries the county/state code unambiguously
         // for state QSO parties.  Prefer it when present -- the
         // alpha-prefix-of-SRX_STRING heuristic below was already
         // unreliable, and now fails outright because SRX_STRING is
         // normalized to include a leading RST ("59 MON") on export.
          begin
          exch.DomesticQTH := exch.QTHString
          end
       else
          begin
          // Legacy fallback for ADIF imports that lack a QTH tag.
          // Loads DomesticQTH with the ALPHA prefix of SRX_STRING.
          j := 1;
          while (j <= Length(temps.SRX_String)) and
                not (temps.SRX_String[j] in ['0'..'9']) do
             begin
             Inc(j);
             end;
          exch.DomesticQTH := Copy(temps.SRX_String, 1, j - 1);
          end;
       end
    else
       begin
       exch.ExchString := temps.SRX_String;
       end;
  end;
end;

function ParseADIFRecord(sADIF: string; var exch: ContestExchange): boolean;
var
  fields : TADIFFieldList;
  temps  : TADIFRecordTemps;
begin
  logger.debug('[ParseADIFRecord] Parsing %s', [sADIF]);
  Result := ParseADIFFieldsList(sADIF, fields);
  // Even when no terminator is found, apply whatever fields the lexer
  // managed to parse -- same forgiving behaviour as the legacy
  // implementation, which logged at error but kept the partial exch.
  ApplyADIFFieldsToExchange(fields, exch, temps);
  ApplyContestSpecificADIFTail(temps, exch);
  // State-QP rover (KG1S/MON): strip suffix for country lookup so /M
  // doesn't get misread as a GB prefix indicator.  Done here (rather
  // than inside uADIF) because the strip uses MainUnit-scope state
  // (DomQTHTable, ActiveExchange).
  ctyLocateCallStripRover(exch.Callsign, exch.QTH);
end; // of ParseADIFRecord
(*----------------------------------------------------------------------------*)

procedure ImportFromADIF;
var
  adif: TextFile;
  adifFileName: string;
  sBuffer: string;
  FoundEOH: boolean;
  QSOCounter: integer;
  lpNumberOfBytesWritten: Cardinal;
  // County-line detection during import.  Within a single ImportFromADIF
  // pass we remember the first QTHString seen for each (call|band|mode)
  // tuple.  When a later record reuses the same (call|band|mode) with a
  // different QTHString AND the contest's CountyLineAllowed flag is True,
  // we set ceClearDupeSheet on the later record so the post-import
  // rescore (tUpdateLog(actRescore)) does NOT flag it as a dupe.
  // ContestsArray[ceContest].CountyLineAllowed is set to True only for
  // the 13 single-state QSO parties (VC.pas).  Multi-state QPs (7QP /
  // NEQP / etc.) are deliberately not flagged -- they need their own
  // per-state county-line handling, tracked separately.
  seenCallBandMode    : TStringList;
  cbmKey              : string;
  cbmKeyIdx           : Integer;
  priorQTHForKey      : string;

  procedure DisplayLoadedQSOs;
  begin
    TF.Format(QuickDisplayBuffer, PAnsiChar(LclText('%u ' + TC_QSO_IMPORTED)), QSOCounter);
    SetTextInQuickCommandWindow(QuickDisplayBuffer);
  end;
begin
  { This is a total rewrite of the ADIF import processing. - NY4I 2020 Jul 2
  }
  FoundEOH := false;
  // TR4W's own GetOpenFileNameA wrapper, not VCL's TOpenDialog.  This restores
  // the house pattern that was here before -- it survived in comments at the
  // ProcessMenu call site -- and is the last thing keeping Vcl.Dialogs linked.
  //
  // The filter is a DOUBLE-NUL terminated pair of C strings, which is what
  // GetOpenFileName wants: description#0patterns#0#0.  (The commented original
  // ended with a single #0; that is the one thing not copied verbatim.)
  FillChar(TR4W_ADIF_FILENAME, SizeOf(TR4W_ADIF_FILENAME), 0);
  if not OpenFileDlg('', 'ADIF (*.adi, *.adif)|*.adi;*.adif',
                     TR4W_ADIF_FILENAME, True) then
     begin
     Exit;   // operator cancelled
     end;
  adifFileName := string(AnsiString(PAnsiChar(@TR4W_ADIF_FILENAME[0])));

  if QSOTotals[AllBands, Both] > 0 then
     begin
     // YesOrNo is MessageBoxA, so it answers with Win32 IDYES/IDNO.
     if YesOrNo(TC_APPENDIMPORTEDQSOSTOCURRENTLOG) = IDNO then
        begin
        Exit;
        end;
     end;

  if not FileExists(adifFileName) then
     begin
     ShowMessage({TC_IMPORTFILENOTFOUND} 'The import file is not available' + ' '
       + adifFileName);
     exit;
     end;

  if not OpenLogFile then
     begin
     ShowMessage({TC_CANNOTOPENLOG} TC_CANNOTOPENLOGFILE);

     exit;
     end;
  tSetFilePointer(0, fsFromEnd);
  // Now open te file and process

  if not FileExists(adifFileName) then
     begin
     DebugMsg('In ImportADIF, ADIF file ' + adifFilename + ' does not exists');
     Exit;
     end;

  AssignFile(adif, adifFileName);
  //ReWrite(adif);
  QSOCounter := 0;
  Reset(adif);
  seenCallBandMode := TStringList.Create;
  try
    seenCallBandMode.CaseSensitive := False;
    while not Eof(adif) do
       begin
       ReadLn(adif, sBuffer);
       if not FoundEOH then
          begin
          if trim(AnsiUpperCase(sBuffer)) = '<EOH>' then
             begin
             FoundEOH := true;
             end;
          end
       else
          begin
          ClearContestExchange(TempRXData);
          if ParseADIFRecord(sBuffer, TempRXData) then // processed a record if true
             begin
             // State-QP rover (KG1S/MON): strip suffix for country lookup so
             // the /M tail isn't misread as a GB prefix indicator.  Without
             // this wrapper the post-ParseADIFRecord lookup overwrites the
             // QTH set inside ParseADIFRecord and we end up with DX=G.
             ctyLocateCallStripRover(TempRXData.Callsign, TempRXData.QTH);

             // County-line follow-up detection.  If the imported record
             // reuses (call|band|mode) with a different QTHString AND the
             // contest's CountyLineAllowed flag is True (see VC.pas), set
             // ceClearDupeSheet so the post-import rescore does not
             // dupe-flag this record.  Otherwise leave the flag alone --
             // the standard dupe check stays in effect.
             cbmKey := string(TempRXData.Callsign) + '|' +
                       IntToStr(Ord(TempRXData.Band)) + '|' +
                       IntToStr(Ord(TempRXData.Mode));
             cbmKeyIdx := seenCallBandMode.IndexOfName(cbmKey);
             if cbmKeyIdx >= 0 then
                begin
                priorQTHForKey := seenCallBandMode.ValueFromIndex[cbmKeyIdx];
                if (priorQTHForKey <> string(TempRXData.QTHString)) and
                   ContestsArray[TempRXData.ceContest].CountyLineAllowed then
                   begin
                   TempRXData.ceClearDupeSheet := True;
                   end;
                end
             else
                begin
                seenCallBandMode.Add(cbmKey + '=' + string(TempRXData.QTHString));
                end;

             CalculateQSOPoints(TempRXData);
             (* Into the log -- which is the database. The binary write that
                followed this is gone with the .TRW. *)
             LogStoreAppendQSO(TempRXData);
             inc(QSOCounter);
             if QSOCounter mod 100 = 0 then
                begin
                DisplayLoadedQSOs;
                end;
             end;
          end;
       end;
  finally
    seenCallBandMode.Free;
  end;

  CloseFile(adif);

  CloseLogFile;

  tUpdateLog(actRescore);
  LoadinLog;
  DisplayLoadedQSOs;
  ImportFromADIFThreadID := 0;

end; // of ImportFromADIF

procedure CheckQuestionMark;
var
  i: integer;
begin
  if CallWindowString = '' then
     begin
     Exit;
     end;
  for i := 1 to CallstringLength do
     begin
     if CallWindowString[i] = '?' then
        begin
        SetEntrySel(TR4WCallEdit, i - 1, 1);
        Break;
        end;
     end;
end;

(* ChangeFocus IS DELETED (2026-09-07). A focus-tracing helper that appended
  to 'D:\TR4W_WinAPI\out\TEST\focus.txt' -- one developer's absolute path, on
  a drive letter no other machine has, opened with OPEN_EXISTING so it failed
  silently everywhere else. Both callers were already commented out.

  It held five raw Win32 calls: CreateFile, SetFilePointer, WriteFile,
  CloseHandle and GetTickCount64. *)

// Offers to set a configuration command now, and takes the operator to WHERE
// THAT SETTING ACTUALLY LIVES.
//
// THE DEFECT THIS FIXES (2026-08-16).  This used to send every prompt to the
// Ctrl-J options dialog.  That was right when Ctrl-J was the only settings UI,
// and it silently stopped being right as Preferences took ownership of rows:
// CommandsToListView2 (uOption.pas) EXCLUDES crS in [csRem, csOwned, csJSON],
// so an owned command is simply not in that list. Worse, the dialog's
// not-found path selected row 0 -- so the operator answered "yes, set it now"
// and landed on an arbitrary unrelated command, highlighted as though it were
// the one they asked for.
//
// Both live callers were already broken by this: COMPUTER ID is csOwned and
// MMTTY ENGINE is csJSON (uCFG.pas:500, :622). Neither has been reachable
// through this prompt since Preferences took those rows.
//
// So route by OWNERSHIP rather than sending everything to one dialog:
//   csOwned / csJSON -> Preferences, at the owning section, control focused
//   everything else  -> Ctrl-J, as before
//
// The ownership test is the SAME crS the Ctrl-J filter reads, so the two
// cannot disagree about who owns a row. An unknown command falls through to
// Ctrl-J, which is the old behaviour and no worse than it was.
procedure SetCommand(c: PAnsiChar);
var
  cmd: string;
  idx: integer;
  ownedElsewhere: boolean;
begin
  TF.Format(TempBuffer1, PAnsiChar(LclText(TC_SET_VALUE_OF_SET_NOW)), c);
  if YesOrNo(string(TempBuffer1)) = IDno then
     begin
     Exit;
     end;

  cmd := string(c);
  idx := FindCFGCommand(cmd);
  ownedElsewhere := (idx >= 0) and (CFGCA[idx].crS in [csOwned, csJSON]);

  if ownedElsewhere then
     begin
     // ShowPreferencesForCommand reports its own failure and still leaves
     // Preferences open, so there is nothing useful to fall back TO here --
     // Ctrl-J is precisely the dialog that cannot show this row.
     if not ShowPreferencesForCommand(cmd) then
        begin
        logger.Warn('[SetCommand] "%s" is owned by Preferences but has no ' +
                    'control there; opened Preferences without a deep link',
                    [cmd]);
        end;
     Exit;
     end;

  // NO OTHER EDITOR EXISTS.  This used to hand the command to Ctrl-J through
  // CommandToSet, which pre-selected its row in that list.  Ctrl-J is gone, and
  // measured against comment-stripped source there are ZERO live csOld/csNew
  // rows left for it to have shown -- every live row is csOwned, csJSON, or
  // csRem (withdrawn and not applied).  So the only honest thing is to say so
  // rather than open a window that cannot show it.
  logger.Warn('[SetCommand] "%s" is not a setting any editor shows -- ' +
              'it is neither owned by Preferences nor a live CFGCA row', [cmd]);
  ShowMessage(Format(TC_SCANNOTEDITEDHERE, [cmd]));
end;

procedure InvertBooleanCommand(Command: PBoolean);
var
  i: integer;
begin
  for i := 1 to CommandsArraySize do
    if CFGCA[i].crAddress = Command then
       begin
       InvertBoolean(Command^);
       (* THROUGH SetCFGCommandValue, which applies AND persists through the
         configuration store. The ini write that stood here reached a file
         nothing reads: INSERT MODE, its only caller'''s row, is csJSON. *)
       SetCFGCommandValue(string(StrPas(CFGCA[i].crCommand)),
                          string(StrPas(BA[Command^])));
       RunCommandRedrawProc(i);
       end;
end;

(* ShowHelp IS GONE (2026-09-07), with the CHM help system it drove.

  NY4I: "remove references to htmlhelp as that is not a thing anymore."

  IT HAD ALREADY STOPPED WORKING, which is the part worth recording. The whole
  body sat inside {$IFDEF LANG_RUS} and TR4W builds English only, so it
  compiled to an empty procedure -- for the life of the FPC tree. Its two call
  sites were a Help menu arm that is itself inside {$IFDEF LANG_RUS} and so was
  never compiled either, and a Help button on the server-log window that
  therefore did nothing when clicked. That button is removed with it rather
  than left as an affordance that answers nothing.

  src\Htmlhelp.pas went too: a LoadLibrary of hhctrl.ocx, the HH_* command
  constants, and an ANSI/wide entry-point pair. *)

procedure RunExplorer(Command: PAnsiChar);
var
  TempPchar: PAnsiChar;
begin

  if strpos(Command, '.') <> nil then
     begin
     TempPchar := 'explorer /select, %s'
     end
  else
     begin
     TempPchar := 'explorer %s';
     end;

  RunWindowsUtility(SysUtils.Format(string(TempPchar), [string(Command)]));
end;

const
  ASSOCF_NONE         = $00000000;   // Issue #986
  ASSOCSTR_EXECUTABLE = 2;           // the executable registered for the type

// AssocQueryStringA asks Windows which executable is registered for a file
// extension (here, ".txt").  Declared directly because Delphi 7's ShlwApi
// import unit does not expose it.
function AssocQueryStringA(flags: DWORD; str: DWORD; pszAssoc, pszExtra,
  pszOut: PAnsiChar; pcchOut: PDWORD): HRESULT; stdcall;
  external 'shlwapi.dll' name 'AssocQueryStringA';

// Issue #986 -- open FileName in the user's default text editor (the program
// registered for the ".txt" extension) instead of hard-coding Notepad.  Shared
// by every "open in editor" path (the file-preview window, history.txt, ...).
// Falls back to Notepad if no .txt association can be resolved or the editor
// fails to launch, so the behavior never regresses on a misconfigured system.
procedure OpenInDefaultTextEditor(FileName: PAnsiChar);
var
  editor   : array[0..1023] of AnsiChar;
  cmdBuf   : array[0..1279] of AnsiChar;   // local: caller may pass wsprintfBuffer
  len      : DWORD;
  launched : boolean;
begin
  launched := False;
  len := SizeOf(editor);
  editor[0] := #0;
  if AssocQueryStringA(ASSOCF_NONE, ASSOCSTR_EXECUTABLE, '.txt', nil,
        editor, @len) = S_OK then
     begin
     if editor[0] <> #0 then
        begin
        // NO QUOTING. RunProgram passes arguments as a LIST, so a path with
        // a space in it needs no quotes -- and hand-quoting was the bug this
        // line was written to avoid.
        launched := RunProgram(string(PAnsiChar(@editor[0])),
                               [string(FileName)]);
        end;
     end;

  if not launched then
     begin
     // Fallback: Notepad. Windows-only by name, hence the utility route.
     RunWindowsUtility(SysUtils.Format('Notepad %s', [string(FileName)]));
     end;
end;

// CTRL-J NOW OPENS PREFERENCES (NY4I, 2026-08-16).
//
// The old options dialog listed every CFGCA row whose crS was not csRem /
// csOwned / csJSON. As of 2026-08-16 there are NONE: all 173 that were left
// were registered in uSettingsDeclarations and flipped to csOwned in the same
// commit, so this dialog would open on an empty list.
//
// csOwned was the right flip rather than csJSON: it hides the row from here
// while CheckCommand still applies the ini value, so nothing about how a
// setting LOADS changed — only where it is edited. Retiring the ini is a
// separate, per-row job, and only six of those rows are read by an export unit
// and must stay csOwned for good. See docs/CTRLJ_INVENTORY.md.
//
// The menu entry stays where fifteen years of muscle memory expects it; it just
// arrives somewhere better. `f` is now unused — kept in the signature because
// several call sites pass a filter and changing them all is churn for no gain
// while the entry point may still want to select a page one day.
procedure RunOptionsDialog(f: CFGFunc);
var
  page: NativeInt;
begin
  // THE MENU ITEM NAMES A PAGE, SO OPEN AT IT.  Settings > Colors landing on
  // whatever page Preferences was last left on is not what the menu said it
  // would do (NY4I, 2026-08-21).
  //
  // EVERY filter maps to the page that now owns those settings.
  //
  // cfWK, cfRadio1 and cfRadio2 were left unmapped in the first pass on the
  // grounds that they name DEVICES rather than sections.  That was wrong, and
  // NY4I found it immediately: "where did all those winkeyer options go?"  The
  // devices live in a LIBRARY, and the library is on a page -- CW Settings
  // holds the keying devices, Radios holds the radios.  Landing there is
  // exactly what the menu item means, and the operator picks the device from
  // the list.  Opening Preferences wherever it was last left made settings that
  // are perfectly present look deleted.
  //
  // cfAll stays unmapped because it genuinely has no page: it IS Preferences.
  page := -1;
  case f of
    cfCol:        page := NAV_COLORS;
    cfAppearance: page := NAV_APPEARANCE;
    cfWK:         page := NAV_CW;       // the CW keying-device library
    cfRadio1,
    cfRadio2:     page := NAV_RADIOS;
  end;

  if page >= 0 then
     begin
     if ShowPreferencesAtPage(page) then
        begin
        logger.Info('[Options] menu -> Preferences page %d', [page]);
        Exit;
        end;
     // SelectPage reports its own failure; Preferences is open either way, so
     // fall through rather than leaving the operator with nothing.
     end;


  // EVERY filter goes to Preferences now, colors included.
  //
  // cfCol was the last holdout and it was never a filter over CFGCA at all --
  // it was a different dialog wearing the same window, built from
  // TWindows[TMainWindowElement], two rows per element, and saved to the ini's
  // [COLORS] section.  None of those are CFGCA rows, which is why emptying
  // Ctrl-J did not touch them and why Preferences had nowhere to show them
  // (NY4I caught the editor going unreachable, 2026-08-16).
  //
  // Preferences has a Colors page under Appearance now, so the old dialog has
  // no remaining caller and uOption.pas is gone.
  logger.Info('[Options] Ctrl-J -> Preferences');
  ShowPreferences;
end;

procedure OpenUrl(const url: string);
var
 // lpcbValue: DWORD;
 // phkResult: hkey;
  sURI: string;
begin
  // This code no longer works so just do the SHellExecute
  {lpcbValue := SizeOf(TempBuffer2);

  if RegOpenKeyEx(HKEY_CLASSES_ROOT, 'http\shell\open\command', 0,
    KEY_ALL_ACCESS, phkResult) = ERROR_SUCCESS then
  begin
    RegQueryValueEx(phkResult, nil, nil, nil, @TempBuffer2, @lpcbValue);
    RegCloseKey(phkResult);

    for lpcbValue := 0 to SizeOf(TempBuffer2) - 2 do
      if TempBuffer2[lpcbValue] = '"' then
        if TempBuffer2[lpcbValue + 1] = ' ' then
          TempBuffer2[lpcbValue + 1] := #0;

    TF.Format(wsprintfBuffer, '%s "%s"', TempBuffer2, url);

    WinExec(wsprintfBuffer, SW_SHOWNORMAL);
  end
  else
     begin}
  sURI := TIDURI.URLEncode(url);

  // QUALIFIED, AND IT MUST BE.  Pascal identifiers are case-insensitive, so
  // LCLIntf's OpenURL and this unit's OpenUrl are THE SAME NAME: an unqualified
  // call here resolves to the routine we are standing in and recurses until the
  // stack goes.  The compiler cannot warn -- both are legal and one is nearer.
  LCLIntf.OpenURL(string(sURI));
  { end;}
  //RunExplorer(url);
end;

function GetAddMultBand(Mult: TAdditionalMultByBand; Band: BandType): BandType;
begin
  case Mult of
    dmbbDefauld: Result := Band;
    dmbbAllBand: Result := AllBands;
  end;

end;

// DeviceIoControlHandler was DELETED here: a KERNEL-MODE driver dispatch
// routine that had been pasted into a user-mode application. It switched on
// IOCTL_READ_PORTS / IOCTL_WRITE_PORTS (uIO.pas) and did raw LPT base-address
// arithmetic over $3BC / $378 / $278 in ~160 lines of x86-32 assembly.
//
// Nothing called it -- it was declared in this unit's interface and had zero
// call sites anywhere in the tree. It could not have worked if anything had:
// both READ_PORT_UCHAR and WRITE_PORT_UCHAR were commented out, so the read
// path stored a hard-coded 0 and the write path wrote nowhere. Those are
// kernel-only routines in any case; from ring 3 this was never going to run.
//
// Actual LPT access in TR4W goes through uIO and inpout32.dll, which is a
// real driver. That path is untouched. (It used to say "DLPortIO /
// inpout32.dll"; DLPortIO.pas was the OLDER driver, superseded by the inpout32
// rewrite and deleted on 2026-09-08 -- it was in no project file and
// referenced by nothing.)

(* GATED WITH ITS LOADER, FOR THE LOADER'S REASON (2026-09-08).

  LoadInPlugins is {$IFDEF WINDOWS} on NY4I's decision -- "interesting concept
  but not something I want to propagate nor decide to kill now" -- and this is
  the other half of the same feature: the routine that RUNS what that one
  loaded. Read its comment for the standing position; nothing new is decided
  here.

  GATING THIS ONE IS NOT COSMETIC, even though it can never be reached off
  Windows. LoadedPlugins stays 0 there, so no menu row exists to dispatch and
  no id in the 10700..10709 range can arrive. But the BODY still has to
  compile, and it names LoadLibraryA and GetLastError -- which is why the
  declarations are inside the gate as well, exactly as they are in the loader.

  THE PORTABLE SHAPE EXISTS if the product decision ever goes the other way:
  TLibHandle + LoadLibrary + GetProcedureAddress from the RTL's dynlibs, and
  GetLastOSError for the message. It is deliberately not written yet, because
  writing it would quietly answer a question NY4I has left open -- half a port
  of an undecided feature is worse than none, since it reads as a commitment.

  OFF WINDOWS THIS IS A NO-OP THAT SAYS SO. A silent one would make "my plugin
  did nothing" unanswerable. *)
procedure RunPlugin(PluginNumber: integer);
{$IFDEF WINDOWS}
var
  CreatedReport: PAnsiChar;
  MakeRescore, ReLoadLog: boolean;
  module: THandle;
  TempFunc: Tmain;
{$ENDIF}
begin
{$IFNDEF WINDOWS}
  logger.Warn('[Plugin] command %d ignored -- plugins are Windows-only in ' +
              'this build. See LoadInPlugins.', [PluginNumber]);
{$ELSE}
  (* NOTHING HERE CHECKED ANYTHING, and all three checks are needed.

    The loader is careful -- it tests the entry point before it adds a menu
    item -- and this, the thing that runs the plugin, tested neither the index
    nor the library nor the function. An access violation at address $00000000
    was the result (NY4I, 2026-09-03, caught in the debugger at the call
    below). The id that got here was not a plugin at all; see the WM_COMMAND
    note in uMainWindowProc, which is the real defect. This is the second line
    of defence, and it should have been the first. *)
  if (PluginNumber - 10700 < Low(PluginsArray)) or
     (PluginNumber - 10700 > High(PluginsArray)) then
     begin
     logger.Error('[Plugin] command %d is not a plugin -- there are %d, so the ' +
                  'valid range is %d..%d. Ignored.',
                  [PluginNumber, High(PluginsArray),
                   10700 + Low(PluginsArray), 10700 + High(PluginsArray)]);
     Exit;
     end;

  TF.Format(TempBuffer1, '%sPlugins\%s', TR4W_PATH_NAME, PluginsArray[PluginNumber
    - 10700]);

  module := LoadLibraryA(TempBuffer1);
  if module = 0 then
     begin
     logger.Error('[Plugin] cannot load %s -- %s',
                  [StrPas(TempBuffer1), SysErrorMessage(GetLastError)]);
     Exit;
     end;

  TempFunc := GetProcAddress(module, 'main');
  if not Assigned(TempFunc) then
     begin
     (* A DLL WITH NO `main` IS NOT A TR4W PLUGIN. Calling what
       GetProcAddress returned is a call to address zero. *)
     logger.Error('[Plugin] %s exports no "main" -- not a TR4W plugin.',
                  [StrPas(TempBuffer1)]);
     FreeLibrary(module);
     Exit;
     end;

  CreatedReport := nil;
  ReLoadLog := False;
  MakeRescore := False;
  TempFunc(TR4W_LOG_FILENAME, CreatedReport, ReLoadLog, MakeRescore,
    ExchangeInformation, ActiveExchange, 0, 0, 0);
  if ReLoadLog then
     begin
     LoadinLog;
     end;

  if CreatedReport <> nil then
     begin
     PreviewFileNameAddress := CreatedReport; //TR4W_CFG_FILENAME;
     FilePreview;
     end;

  FreeLibrary(module);
{$ENDIF}
end;

(* THE PLUGIN LOADER, WINDOWS-ONLY FOR NOW AND DELIBERATELY UNDECIDED.

  NY4I, 2026-09-08: "IFDEF WINDOWS the body of LoadInPlugins. Interesting
  concept but not something I want to propagate nor decide to kill now."

  So this gate is a HOLDING POSITION, not a design. The routine scans
  Plugins\tr4w*.dll, loads each with LoadLibrary, asks it for tr4wGetPlugin and
  adds a menu row per plugin -- a Windows DLL plug-in model end to end. Every
  call in it is Win32: FindFirstFileA, FindNextFileA, LoadLibraryA,
  GetProcAddress, FreeLibrary, FindClose, and TWin32FindDataA in the var block,
  which is why the DECLARATIONS are inside the gate too and not just the code.

  WHAT IS NOT DECIDED, and should not be guessed at here: whether TR4W keeps a
  binary plug-in interface at all. If it does, the portable shape exists --
  FindAllFiles for the scan, TLibHandle/LoadLibrary/GetProcedureAddress from
  the RTL's dynlibs for the loading -- and the per-platform part shrinks to the
  file extension. That is a decision about the product, not a translation, so
  the gate stays until someone makes it.

  OFF WINDOWS NOTHING LOADS AND LoadedPlugins STAYS 0, which is the same state
  a Windows machine with an empty Plugins directory reaches. No caller needs a
  gate of its own; the menu simply has no Plugins group. It says so in the log
  rather than being silent, because "my plugins are missing" is otherwise
  unanswerable. *)
procedure LoadInPlugins();
{$IFDEF WINDOWS}
label
  1, Next;
var
  lpFindFileData: TWin32FindDataA;
  hFindFile: THandle;
  module: THandle;
  TempFunc: Ttr4wGetPlugin;
  exitItem:   TMenuItem;   { the Exit row -- the plugins group sits above it }
  pluginMenu: TMenuItem;   { the Plugins popup, once one plugin has loaded }
  pluginItem: TMenuItem;
const
  MAXLOADEDPLUGINS = 10;
{$ENDIF}
begin
{$IFDEF WINDOWS}
  { A LOCAL, so it holds rubbish until it is set -- and it is TESTED
    before the first plugin creates it. }
  pluginMenu := nil;
  TF.Format(TempBuffer1, '%sPlugins\tr4w*.dll', TR4W_PATH_NAME);

  hFindFile := Windows.FindFirstFileA(TempBuffer1, lpFindFileData);
  if hFindFile <> INVALID_HANDLE_VALUE then
     begin
     goto 1
     end
  else
     begin
     Exit;
     end;

  Next:
  if FindNextFileA(hFindFile, lpFindFileData) then
     begin
     1:
     TF.Format(TempBuffer1, '%sPlugins\%s', TR4W_PATH_NAME,
       lpFindFileData.cFileName);

     module := LoadLibraryA(TempBuffer1);
     TempFunc := GetProcAddress(module, 'tr4wGetPlugin');
     if @TempFunc <> nil then
        begin
        (* THE PLUGINS SUBMENU, inserted above Exit.

          Was CreatePopupMenu + InsertMenuA(MF_POPUP) + AppendMenuA. A
          TMenuItem with children IS a popup, and Insert takes the POSITION of
          the row to sit above -- which is what MF_BYCOMMAND + menu_exit meant.

          Each plugin row gets the same OnClick as every other item and carries
          its id in Tag, so 10700 + n reaches RunPlugin through
          DispatchCommandId exactly as it did through WM_COMMAND. *)
        if LoadedPlugins = 0 then
           begin
           exitItem := MenuItemById(menu_exit);
           if exitItem <> nil then
              begin
              pluginMenu := TMenuItem.Create(TR4WMainForm);
              pluginMenu.Caption := 'Plugins';
              exitItem.Parent.Insert(exitItem.MenuIndex, pluginMenu);
              end;
           end;
        inc(LoadedPlugins);
        if pluginMenu <> nil then
           begin
           pluginItem := TMenuItem.Create(TR4WMainForm);
           pluginItem.Caption := TCaption(string(TempFunc()));
           pluginItem.Tag     := 10700 + LoadedPlugins;
           pluginItem.OnClick := TR4WMainForm.MenuItemClick;
           pluginMenu.Add(pluginItem);
           end;
        Windows.lstrcatA(PluginsArray[LoadedPlugins], lpFindFileData.cFileName);
        end;
     FreeLibrary(module);
     goto Next;
     end;
  Windows.FindClose(hFindFile);
  { A separator above Exit, so the plugin rows are visibly their own group. }
  if LoadedPlugins > 0 then
     begin
     exitItem := MenuItemById(menu_exit);
     if exitItem <> nil then
        begin
        pluginItem := TMenuItem.Create(TR4WMainForm);
        pluginItem.Caption := '-';
        exitItem.Parent.Insert(exitItem.MenuIndex, pluginItem);
        end;
     end;
{$ELSE}
  if logger <> nil then
     begin
     logger.Info('[Plugins] TR4W plug-ins are Windows DLLs; none are loaded on ' +
                 'this platform. See the note above LoadInPlugins.');
     end;
{$ENDIF}
end;

procedure OpenStationInformationWindow(const aOnAccept: TCabrilloSummaryAction);
begin
  ShowCreateCabrillo(aOnAccept);
end;

procedure OpenListOfMessages;
begin
  ShowAltP;
end;

(* THE DVP -> DVK RENAME IS GONE, AND SO IS THE MECHANISM.

  RenameCommand read a key out of tr4w.ini, deleted it and wrote it back under
  a new name. It existed to carry three settings across a rename, in a file
  this program no longer writes and which is empty on a migrated station -- so
  it read nothing and did nothing, three times, on every start.

  All three rows live in settings\tr4w.json now (DVK ENABLE, DVK PATH, DVK
  RECORDER), where they arrived through the ordinary migration. A rename helper
  for the ini has nothing left to rename. *)

procedure PTTOn;
label
  DrawPTTLabel;
var
  // hand : HWND;
  TempPTTValue: Byte;
  TempPortInterface: PortInterface;
  TempByte: Byte;
begin
  DebugMsg('Enter MainUnit.PTTOn');
  if not Config.PTTEnable then
     begin

     if ActiveRadioPtr.tKeyerPort in [Parallel1..Parallel3] then
       if DriverIsLoaded() then
          begin
          TempByte := GetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl);
          DriverBitOperation(TempByte, STROBE_SIGNAL, boSet1);
          SetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl, TempByte);
          end;

     Exit;
     end;

  begin
    if wkTurnPTT(True) then
       begin
       goto DrawPTTLabel;
       end;
    if tPTTVIACAT(True) then
       begin
       goto DrawPTTLabel;
       end;
    TempPortInterface := tGetPortType(ActiveRadioPtr.tKeyerPort);
    if TempPortInterface <> NoInterface then
       begin
       if TempPortInterface = SerialInterface then
          begin
          (* WHICH LINE, AND ASSERT IT -- see LOGK1EA.DrivePTTLine. This built a
            Win32 escape code (SETRTS / SETDTR) and pushed it at a raw handle;
            choosing the line and choosing the direction are separate things
            now, and the port is the keyer's TSerialPort. *)
          if DrivePTTLine(ActiveRadioPtr, True) then
             begin
             goto DrawPTTLabel;
             end;
          Exit;
          end;

       if not DriverIsLoaded() then
          begin
          Exit;
          end;

       TempByte := GetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl);
       DriverBitOperation(TempByte, STROBE_SIGNAL, boSet1);
       DriverBitOperation(TempByte, PTT_SIGNAL, boSet1);
       // TempByte := TempByte or BIT0; //1pin (Inverted)
       // TempByte := TempByte or BIT2; //16pin
       SetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl, TempByte);

       DrawPTTLabel:
       logger.debug('Entering Main.PTTOn');
       ActiveRadioPtr.tPTTStatus := PTT_ON;
       PTTStatusChanged;

       Sleep(Config.PTTTurnOnDelay);
       end;
  end;
end;

procedure PTTOff;
label
  DrawPTTLabel;
var
  PTT_value: Byte;
  TempPortInterface: PortInterface;
  TempByte: Byte;
begin
  DebugMsg('Enter MainUnit.PTTOff');
  if not Config.PTTEnable then
     begin
     if ActiveRadioPtr.tKeyerPort in [Parallel1..Parallel3] then
       if DriverIsLoaded() then
          begin
          TempByte := GetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl);
          DriverBitOperation(TempByte, STROBE_SIGNAL, boSet0);
          SetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl, TempByte);
          end;

     Exit;

     end;
  if IsCWByCATActive(ActiveRadioPtr) then // ny4i Issue 131
     begin
     DEBUGMsg('Stopping CW from PTTOff');
     ActiveRadioPtr^.StopSendingCW;
     goto DrawPTTLabel; // Fix this goto...Put the code below in an IF... TODO
     end;
  if wkTurnPTT(False) then
     begin
     goto DrawPTTLabel;
     end;
  if tPTTVIACAT(False) then
     begin
     goto DrawPTTLabel;
     end;
  TempPortInterface := tGetPortType(ActiveRadioPtr.tKeyerPort);
  if TempPortInterface <> NoInterface then
     begin
     if TempPortInterface = SerialInterface then
        begin
        if DrivePTTLine(ActiveRadioPtr, False) then
           begin
           goto DrawPTTLabel;
           end;
        Exit;
        end;

     if not DriverIsLoaded() then
        begin
        Exit;
        end;

     TempByte := GetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl);
     DriverBitOperation(TempByte, STROBE_SIGNAL, boSet0);
     DriverBitOperation(TempByte, PTT_SIGNAL, boSet0);
     SetPortByte(ActiveRadioPtr.tKeyerPortHandle, otControl, TempByte);

     DrawPTTLabel:
     ActiveRadioPtr.tPTTStatus := PTT_OFF;
     PTTStatusChanged;

     end;
end;

procedure CreateLogfile(aLine: string);
var
  aFileName: string;
  myFile: TextFile;
  aFilePath: string;
begin
  try
    //aLine := 'The line which you want to print. You can change this line dynamically by passing aLine as parameter to CreateLogfile function';
    aFileName := 'TR4WLogfile_' + FormatDateTime('dd-mm-yyyy', Now) + '.log';
    aFilePath := aFileName;
    AssignFile(myFile, aFilePath);
    try
      if FileExists(aFilePath) then
         begin
         Append(myFile)
         end
      else
         begin
         Rewrite(myFile);
         end;
      WriteLn(myFile, FormatDateTime('dd-mmm-yyyy hh:nn:ss.zzz', Now) + ': ' +
        ALine);
      Flush(myFile);
    except
    end;
  finally
    CloseFile(myFile);
  end;
end;
procedure DebugMsg(s: string);
begin
   if Assigned(logger) then
      begin
      logger.Debug(s);
      end;
end;

// These two functions are overloaded so on can call without any parameters to
// test the active radio. Or pass a ptr to the radio of one's choosing. If the
// radio pointer is nil, then it just uses the active radio.

function IsCWByCATActive(theRadio: RadioPtr): boolean; // ny4i Issue # 111
var
  ptr: RadioPtr;
begin
  if not Assigned(theRadio) then
     begin
     ptr := ActiveRadioPtr;
     end
  else
     begin
     ptr := theRadio;
     end;
  // TWO INDEPENDENT FACTS, both required.  ptr.CWByCAT is the OPERATOR's config
  // setting -- what they want.  rcCWByCAT is what the RADIO can do.  A user can
  // switch the option on for a radio that cannot key CW over CAT, and the
  // capability is what stops that.  (Was `RadioModel in RadioSupportsCWByCAT`.)
  // Asked of the RADIO OBJECT (HasCapability), not of a model-keyed table: a
  // string-id factory radio has RadioModel = NoInterfacedRadio, so the enum
  // lookup reported every capability as absent and CW-by-CAT was silently
  // skipped for it (TCI keyed nothing -- NY4I, 2026-08-03).
  Result := (ptr.CWByCAT) and ptr.HasCapability(rcCWByCAT);
end;

function IsCWByCATActive: boolean; // ny4i Issue # 111
begin
  Result := IsCWByCatActive(ActiveRadioPtr);
  // Call base function with active radio // ny4i Issue 111
end;

// ADIFDateStringToQSOTime, ADIFTimeStringToQSOTime moved to uADIF.pas (Issue #887).

function GetTR4WBandFromNetworkBand(band: TRadioBand): BandType;
begin
  case band of
    rbNone: Result := NoBand;
    rb160m: Result := Band160;
    rb80m: Result := Band80;
    //   rb60m: Result := Band60;
    rb40m: Result := Band40;
    rb30m: Result := Band30;
    rb20m: Result := Band20;
    rb17m: Result := Band17;
    rb15m: Result := Band15;
    rb12m: Result := Band12;
    rb10m: Result := Band10;
    rb6m: Result := Band6;
    rb4m: Result := NoBand;
    rb2m: Result := Band2;
    rb70cm: Result := Band432;
  else
    begin
      logger.Error('[GetTR4WBandFromNetworkBand] band is invalid - Ord is %d',
        [Ord(band)]);
    end;
  end; // of case

end;

// GetRadioBandFromBandType lives in radioFactory\uRadioBand.pas as of 2026-08-07.

procedure GetTRModeAndExtendedModeFromNetworkMode(netMode: TRadioMode; var mode:
  ModeType; var extMode: extendedModeType);
begin
  case netMode of
    rmNone:
      begin
      end;
    rmLSB:
      begin
        extMode := eLSB;
        mode := Phone;
      end;
    rmUSB:
      begin
        extMode := eUSB;
        mode := Phone;
      end;
    rmCW:
      begin
        extMode := eCW;
        mode := CW;
      end;
    rmFM:
      begin
        extMode := eFM;
        mode := FM;
      end;
    rmAM:
      begin
        extMode := eAM;
        mode := Phone;
      end;
    rmData:
      begin
        extMode := eData;
        mode := Digital;
      end;
    rmCWRev:
      begin
        extMode := eCW_R;
        mode := CW;
      end;
    rmDATARev:
      begin
        extMode := eData_R;
        mode := Digital;
      end;
    rmFSK:
      begin
        extMode := eRTTY;
        mode := Digital;
      end;
    rmAFSK:
      begin
        extMode := eRTTY;
        mode := Digital;
      end;
    rmPSK:
      begin
        extMode := ePSK31;
        mode := Digital;
      end;
    rmPSKRev:
      begin
        extMode := ePSK31;
        mode := Digital;
      end;
    rmFSKRev:
      begin
        extMode := eRTTY_R;
        mode := Digital;
      end;
    rmDV:
      begin
        extMode := eDStar;
        mode := Phone;
      end;
  else
    begin
      logger.Warn('[GetTRModeAndExtendedModeFromNetworkMode] Unhandled netMode from Net Object - Ord = %d', [Ord(netMode)]);
    end;
  end; // of case
end;

function GetModeFromExtendedMode(extMode: ExtendedModeType): ModeType;
begin
  //ExtendedModeStringArray : array[ExtendedModeType] of string = ('CW', 'RTTY', 'FT8', 'FT4', 'JT65', 'PSK31', 'PSK63', 'SSB', 'FM', 'AM', 'MFSK', 'JS8', 'USB', 'SSB');
  case extMode of
    eCW, eCW_R: Result := CW;
    eSSB, eAM, eAM_N, eUSB, eLSB:
      Result := Phone;
    eFM, eFM_N, eDstar, eC4FM, eWFM: Result := FM;
  else
    Result := Digital;
  end;
end;

function DigitsIn(n: smallInt): byte;
// byte is 0 to 255 so more than enough, smallInt is -32768..32767
var
  isNegative: boolean;
begin
  isNegative := false;
  if n < 0 then
     begin
     isNegative := true;
     n := n * -1;
     end;
  if n > 9999 then
     begin
     Result := 5
     end
  else if n > 999 then
     begin
     Result := 4
     end
  else if n > 99 then
     begin
     Result := 3
     end
  else if n > 9 then
     begin
     Result := 2
     end
  else
     begin
     Result := 1;
     end;

  if isNegative then
     begin
     Result := Result + 1;
     end;
end;

(*----------------------------------------------------------------------------*)
function AskConvertLog(sVersion: string): boolean;
{ Converts a log file from a prior binary format to the current v1.7 format.
  Supported source versions: v1.5, v1.6.
  For each source version there is a corresponding frozen record type:
    v1.5 -> ContestExchangev1_5  (no ExtMode, no ExchString, no id)
    v1.6 -> ContestExchangev1_6  (no id field)
  The original log is renamed to <logname>.<vN_N> and a read-only backup
  copy is created as <logname>-<version>.bkup before any conversion begins.
  The id field is left blank after conversion. }
var
  OldFile, NewFile, fName, sVersionTag: string;
  ansiMsg: AnsiString;   // D12: hold the ANSI text alive across the PAnsiChar display call
  fileSetCode, attrs: integer;
  oldFH_v1_6: file of ContestExchangev1_6;
  oldFH_v1_5: file of ContestExchangev1_5;
  newFH: file of ContestExchange;
  headerFH: file of TLogHeader;
  oldRXData_v1_6: ContestExchangev1_6;
  oldRXData_v1_5: ContestExchangev1_5;
  newRXData: ContestExchange;
begin
  Result := false;

  logger.Info('AskConvertLog: converting log from version ' + sVersion + ' to ' + LOGVERSION);

  if (sVersion <> 'v1.5') and (sVersion <> 'v1.6') then
     begin
     ansiMsg := AnsiString('Cannot convert log version ' + sVersion + ' to ' + LOGVERSION + '. Unknown source version.');
     ShowMessage(PAnsiChar(ansiMsg));
     logger.Fatal('AskConvertLog: unknown source version: ' + sVersion);
     Exit;
     end;

  { The general logic here is as follows:
    Read the log header and confirm the version differs from current.
    If the user agrees to convert, back up the original file, then
    rename it with a version-tagged extension so the conversion reads it. }
  ansiMsg := AnsiString('This log is version ' + sVersion + '. Would you like to convert it to ' + LOGVERSION + '?');
  // IDNO, not VCL's mrNo.  They are both 7 in D12 (System.UITypes: mrNo = idNo
  // = 7), so this comparison was correct by coincidence rather than by intent;
  // YesOrNo returns MessageBoxA's ID and should be compared with the Win32
  // constant.  Behaviour is unchanged -- verified against the D12 RTL source.
  if YesOrNo(string(ansiMsg)) = IDNO then
     begin
     logger.Fatal('User opted to not upgrade log format');
     Halt;
     end;

  NewFile := StrPas(TR4W_LOG_FILENAME) + '-' + sVersion + '.bkup';
  if not FileExists(TR4W_LOG_FILENAME) then
     begin
     ShowMessage(PAnsiChar(TC_LOGFILENOTFOUND));
     Exit;
     end;

  if FileExists(NewFile) then
     begin
     attrs := FileGetAttr(NewFile);
     if attrs and faReadOnly > 0 then
        begin
        ShowMessage(PAnsiChar(TC_CANNOTCOPYLOGREADONLY));
        Exit;
        end;
     end;

  (* FileUtil.CopyFile, not CopyFileA. The LCL's takes strings on every
    platform, so the Win32 entry point and the code-page conversion that
    existed only to feed it go together.

    QUALIFIED, because this unit still uses Windows and BOTH declare a
    CopyFile. An unqualified call resolves by uses order, which is exactly
    the kind of silent choice CLAUDE.md warns about for TRect here.

    cffOverwriteFile MATCHES THE OLD BEHAVIOUR: CopyFileA's third argument
    is bFailIfExists, and it was False, so the copy overwrote. The read-only
    check above is what actually guards an existing file. ExceptionOnError
    stays False so a failure still arrives as False, not as an exception. *)
  if not FileUtil.CopyFile(StrPas(TR4W_LOG_FILENAME), LclText(NewFile),
                           [cffOverwriteFile], False) then
     begin
     ShowMessage(PAnsiChar(TC_CANNOTBACKUPLOG + StrPas(TR4W_LOG_FILENAME)));
     Exit;
     end;

  ShowMessage(PAnsiChar(TC_BACKUPCREATED));
  fileSetCode := FileSetAttr(NewFile, faReadOnly);
  if fileSetCode = 0 then
     begin
     logger.Info(NewFile + ' made into a read only file');
     end
  else
     begin
     ShowMessage(TC_CANNOTCOPYLOGREADONLY);
     Exit;
     end;

  // Rename the original log to TR4W_LOG_FILENAME + '.<vN_N>' (e.g. .v1_5, .v1_6, .v1_7)
  sVersionTag := StringReplace(sVersion, '.', '_', [rfReplaceAll]);
  OldFile := StrPas(TR4W_LOG_FILENAME) + '.' + sVersionTag;
  fName := StrPas(TR4W_LOG_FILENAME);
  if not RenameFile(fName, OldFile) then
     begin
     ShowMessage(string(TC_CANNOTRENAME) + ' ' + fName + ' >>> ' + OldFile);
     Exit;
     end;

  //***
  // Original is backed up and renamed. Write the new v1.7 header and convert.
  //***

  AssignFile(headerFH, string(TR4W_LOG_FILENAME));
  ReWrite(headerFH);
  Write(headerFH, LogHeader);
  CloseFile(headerFH);

  if sVersion = 'v1.5' then
     begin
     // --- v1.5 to v1.7 ---
     // v1.5 has no ExtMode or ExchString fields; derive ExtMode from Mode
     // and use QTHString as a fallback for ExchString.
     AssignFile(oldFH_v1_5, OldFile);
     FileMode := fmOpenRead;
     Reset(oldFH_v1_5);
     AssignFile(newFH, string(TR4W_LOG_FILENAME));
     FileMode := fmOpenWrite;
     Reset(newFH);
     Seek(newFH, 1);
     Seek(oldFH_v1_5, 1);
     while not EOF(oldFH_v1_5) do
        begin
        Read(oldFH_v1_5, oldRXData_v1_5);
        ClearContestExchange(newRXData);
        newRXData.tSysTime := oldRXData_v1_5.tSysTime;
        newRXData.Band := oldRXData_v1_5.Band;
        newRXData.Mode := oldRXData_v1_5.Mode;
        newRXData.ceQSOID1 := oldRXData_v1_5.ceQSOID1;
        newRXData.ceQSOID2 := oldRXData_v1_5.ceQSOID2;
        newRXData.Frequency := oldRXData_v1_5.Frequency;
        newRXData.ceQSO_Deleted := oldRXData_v1_5.ceQSO_Deleted;
        newRXData.ceComputerID := oldRXData_v1_5.ceComputerID;
        newRXData.ceOperatorID := oldRXData_v1_5.ceOperatorID;
        newRXData.ceRecordKind := oldRXData_v1_5.ceRecordKind;
        (* FOLDED, NOT COPIED: a v1_5 log's "skipped" is a deletion. See the
           note on ceQSO_Skiped in VC.pas. *)
        newRXData.ceQSO_Deleted := newRXData.ceQSO_Deleted or
                                   oldRXData_v1_5.ceQSO_Skiped;
        newRXData.ceSendToServer := oldRXData_v1_5.ceSendToServer;
        newRXData.ceNeedSendToServerAE := oldRXData_v1_5.ceNeedSendToServerAE;
        newRXData.ceDupe := oldRXData_v1_5.ceDupe;
        newRXData.PostalCode_old := oldRXData_v1_5.PostalCode_old;
        newRXData.Prefix := oldRXData_v1_5.Prefix;
        newRXData.Callsign := oldRXData_v1_5.Callsign;
        newRXData.Age := oldRXData_v1_5.Age;
        newRXData.ceWasSendInQTC := oldRXData_v1_5.ceWasSendInQTC;
        newRXData.DomesticMult := oldRXData_v1_5.DomesticMult;
        newRXData.DXMult := oldRXData_v1_5.DXMult;
        newRXData.PrefixMult := oldRXData_v1_5.PrefixMult;
        newRXData.ZoneMult := oldRXData_v1_5.ZoneMult;
        newRXData.ceClass := oldRXData_v1_5.ceClass;
        newRXData.Precedence := oldRXData_v1_5.Precedence;
        newRXData.ceRadio := oldRXData_v1_5.ceRadio;
        newRXData.Check := oldRXData_v1_5.Check;
        newRXData.QTH := oldRXData_v1_5.QTH;
        newRXData.DXQTH := oldRXData_v1_5.DXQTH;
        newRXData.Radio := oldRXData_v1_5.Radio;
        newRXData.DomMultQTH := oldRXData_v1_5.DomMultQTH;
        newRXData.DomesticQTH := oldRXData_v1_5.DomesticQTH;
        newRXData.Name := oldRXData_v1_5.Name;
        newRXData.Power := oldRXData_v1_5.Power;
        newRXData.NumberReceived := oldRXData_v1_5.NumberReceived;
        newRXData.NumberSent := oldRXData_v1_5.NumberSent;
        newRXData.RSTSent := oldRXData_v1_5.RSTSent;
        newRXData.RSTReceived := oldRXData_v1_5.RSTReceived;
        newRXData.QTHString := oldRXData_v1_5.QTHString;
        newRXData.RandomCharsSent := oldRXData_v1_5.RandomCharsSent;
        newRXData.TenTenNum := oldRXData_v1_5.TenTenNum;
        newRXData.Chapter := oldRXData_v1_5.Chapter;
        newRXData.ceClearDupeSheet := oldRXData_v1_5.ceClearDupeSheet;
        newRXData.ceSearchAndPounce := oldRXData_v1_5.ceSearchAndPounce;
        newRXData.Prefecture := oldRXData_v1_5.Prefecture;
        newRXData.InhibitMults := oldRXData_v1_5.InhibitMults;
        newRXData.Zone := oldRXData_v1_5.Zone;
        newRXData.NameSent := oldRXData_v1_5.NameSent;
        newRXData.Kids := oldRXData_v1_5.Kids;
        newRXData.ceContest := oldRXData_v1_5.ceContest;
        newRXData.QSOPoints := oldRXData_v1_5.QSOPoints;
        newRXData.RandomCharsReceived := oldRXData_v1_5.RandomCharsReceived;
        newRXData.ceClearMultSheet := oldRXData_v1_5.ceClearMultSheet;
        newRXData.MP3Record := oldRXData_v1_5.MP3Record;
        newRXData.ceOperator := oldRXData_v1_5.ceOperator;
        // Derive ExtMode from Mode (v1.5 has no ExtMode field)
        if oldRXData_v1_5.Mode = CW then
           begin
           newRXData.ExtMode := eCW;
           end
        else if oldRXData_v1_5.Mode = Phone then
           begin
           newRXData.ExtMode := eSSB;
           end
        else if oldRXData_v1_5.Mode = Digital then
           begin
           newRXData.ExtMode := eRTTY;
           end;
        // Use QTHString as ExchString fallback (v1.5 has no ExchString field)
        newRXData.ExchString := oldRXData_v1_5.QTHString;
        // id (GUID) left blank; rescore will backfill if needed
        Write(newFH, newRXData);
        end;
     CloseFile(oldFH_v1_5);
     CloseFile(newFH);
     end
  else
     begin
     // --- v1.6 to v1.7 ---
     // v1.6 has no id field; id is left blank after conversion.
     AssignFile(oldFH_v1_6, OldFile);
     FileMode := fmOpenRead;
     Reset(oldFH_v1_6);
     AssignFile(newFH, string(TR4W_LOG_FILENAME));
     FileMode := fmOpenWrite;
     Reset(newFH);
     Seek(newFH, 1);
     Seek(oldFH_v1_6, 1);
     while not EOF(oldFH_v1_6) do
        begin
        Read(oldFH_v1_6, oldRXData_v1_6);
        ClearContestExchange(newRXData);
        newRXData.tSysTime := oldRXData_v1_6.tSysTime;
        newRXData.Band := oldRXData_v1_6.Band;
        newRXData.Mode := oldRXData_v1_6.Mode;
        newRXData.ceQSOID1 := oldRXData_v1_6.ceQSOID1;
        newRXData.ceQSOID2 := oldRXData_v1_6.ceQSOID2;
        newRXData.Frequency := oldRXData_v1_6.Frequency;
        newRXData.ceQSO_Deleted := oldRXData_v1_6.ceQSO_Deleted;
        newRXData.ceComputerID := oldRXData_v1_6.ceComputerID;
        newRXData.ceOperatorID := oldRXData_v1_6.ceOperatorID;
        newRXData.ceRecordKind := oldRXData_v1_6.ceRecordKind;
        (* FOLDED, NOT COPIED -- see the v1_5 arm above. *)
        newRXData.ceQSO_Deleted := newRXData.ceQSO_Deleted or
                                   oldRXData_v1_6.ceQSO_Skiped;
        newRXData.ceSendToServer := oldRXData_v1_6.ceSendToServer;
        newRXData.ceNeedSendToServerAE := oldRXData_v1_6.ceNeedSendToServerAE;
        newRXData.ceDupe := oldRXData_v1_6.ceDupe;
        newRXData.PostalCode_old := oldRXData_v1_6.PostalCode_old;
        newRXData.Prefix := oldRXData_v1_6.Prefix;
        newRXData.Callsign := oldRXData_v1_6.Callsign;
        newRXData.Age := oldRXData_v1_6.Age;
        newRXData.ceWasSendInQTC := oldRXData_v1_6.ceWasSendInQTC;
        newRXData.DomesticMult := oldRXData_v1_6.DomesticMult;
        newRXData.DXMult := oldRXData_v1_6.DXMult;
        newRXData.PrefixMult := oldRXData_v1_6.PrefixMult;
        newRXData.ZoneMult := oldRXData_v1_6.ZoneMult;
        newRXData.ExtMode := oldRXData_v1_6.ExtMode;
        newRXData.ExchString := oldRXData_v1_6.ExchString;
        newRXData.ceClass := oldRXData_v1_6.ceClass;
        newRXData.Precedence := oldRXData_v1_6.Precedence;
        newRXData.ceRadio := oldRXData_v1_6.ceRadio;
        newRXData.Check := oldRXData_v1_6.Check;
        newRXData.QTH := oldRXData_v1_6.QTH;
        newRXData.DXQTH := oldRXData_v1_6.DXQTH;
        newRXData.Radio := oldRXData_v1_6.Radio;
        newRXData.DomMultQTH := oldRXData_v1_6.DomMultQTH;
        newRXData.DomesticQTH := oldRXData_v1_6.DomesticQTH;
        newRXData.Name := oldRXData_v1_6.Name;
        newRXData.Power := oldRXData_v1_6.Power;
        newRXData.NumberReceived := oldRXData_v1_6.NumberReceived;
        newRXData.NumberSent := oldRXData_v1_6.NumberSent;
        newRXData.RSTSent := oldRXData_v1_6.RSTSent;
        newRXData.RSTReceived := oldRXData_v1_6.RSTReceived;
        newRXData.QTHString := oldRXData_v1_6.QTHString;
        newRXData.RandomCharsSent := oldRXData_v1_6.RandomCharsSent;
        newRXData.TenTenNum := oldRXData_v1_6.TenTenNum;
        newRXData.Chapter := oldRXData_v1_6.Chapter;
        newRXData.ceClearDupeSheet := oldRXData_v1_6.ceClearDupeSheet;
        newRXData.ceSearchAndPounce := oldRXData_v1_6.ceSearchAndPounce;
        newRXData.Prefecture := oldRXData_v1_6.Prefecture;
        newRXData.InhibitMults := oldRXData_v1_6.InhibitMults;
        newRXData.Zone := oldRXData_v1_6.Zone;
        newRXData.NameSent := oldRXData_v1_6.NameSent;
        newRXData.Kids := oldRXData_v1_6.Kids;
        newRXData.ceContest := oldRXData_v1_6.ceContest;
        newRXData.QSOPoints := oldRXData_v1_6.QSOPoints;
        newRXData.RandomCharsReceived := oldRXData_v1_6.RandomCharsReceived;
        newRXData.ceClearMultSheet := oldRXData_v1_6.ceClearMultSheet;
        newRXData.MP3Record := oldRXData_v1_6.MP3Record;
        newRXData.ceOperator := oldRXData_v1_6.ceOperator;
        // id left blank — not present in v1.6 files
        Write(newFH, newRXData);
        end;
     CloseFile(oldFH_v1_6);
     CloseFile(newFH);
     end;

  Result := true;
end;
(*----------------------------------------------------------------------------*)
// NY4I
// Note we cache last returned one to avoid a subsequent lookup since the
// contest most likely did not change. An example is an ADIF file import.

// GetContestByADIFName moved to uADIF.pas (Issue #887).

procedure SetExtendedModeFromMode(RData: ContestExchange);
begin
  if RData.ExtMode = eNoMode then
     begin
     if RData.Mode = PHONE then
       // We cannot really pick eUSB here. It depends upon the radio mode
        begin
        RData.ExtMode := eSSB;
        // Maybe call someting to guess based on the freqwuency but set it ahead of time
        end
     else if RData.Mode = CW then
        begin
        RData.ExtMode := eCW;
        end
     else if RData.Mode = Digital then
        begin
        RData.ExtMode := eDATA;
        end
     else if RData.Mode = FM then
        begin
        RData.ExtMode := eFM;
        end;
     end;

end;

procedure ProcessImportedSRX_String(fieldValue: string; var exch:
  ContestExchange);
begin
  case exch.ceContest of
    ARRLFIELDDAY, WINTERFIELDDAY:
      begin
        // parse SRX_STRING of 1A EPA into class 1A and QTHString of EPA
        logger.debug('Calling ProcessClassAndDomesticOrDXQTHExchange from ProcessImportedSRX_String');
        ProcessClassAndDomesticOrDXQTHExchange(fieldValue, exch);
        exch.exchString := fieldValue;
        if length(exch.DomesticQTH) = 0 then
           begin
           exch.DomesticQTH := exch.QTHString;
           end;
      end;
  end; // case
end;

(* IsWin64 IS DELETED (2026-09-08), and it was here TWICE.

  The identical function stood in tree.pas and in MainUnit, and NOTHING in the
  tree called either one -- checked with the comment-blanking reader, so a
  mention inside a comment could not fool it. It asked whether a 32-bit build
  was running under WOW64, via GetProcAddress(GetModuleHandle(Kernel32),
  'IsWow64Process'), which is Windows and nothing but.

  Two copies of a routine nobody calls is the CLAUDE.md duplication rule with
  the volume turned up: copies drift, and these two had already begun to --
  same body, different formatting of the same stdcall declaration. Found by
  compiling for Linux, where both were among the last reasons two units named
  the Windows unit. *)

// Written in terms of the ENUM MEMBERS, not raw ordinals.  The previous version
// hard-coded 1..20 = COM, 21 = socket, 22..25 = LPT, which silently encoded the
// old port ceiling in a third place and had to be edited in lockstep with the
// enum -- exactly the kind of coupling that breaks when someone widens the range.
// (It was also already wrong at the top end: it claimed 22..25 were LPT1..LPT4,
// but only Parallel1..Parallel3 exist, so ordinal 25 was unreachable.)
function ConvertPortTypeToCOMString(port: PortType): string;
begin
  Result := '';
  if port in SerialPorts then
     begin
     // Serial1 is ordinal 1, so the COM number IS the ordinal.
     Result := 'COM' + IntToStr(Ord(port));
     end
  else if port = Network then
     begin
     Result := 'socket';
     end
  else if port in [Parallel1, Parallel2, Parallel3] then
     begin
     Result := 'LPT' + IntToStr(Ord(port) - Ord(Parallel1) + 1);
     end;
end;
begin
// The {$IF tDebugMode} SetNewMemMgr call that stood here went with the custom
// memory manager -- see the note where those hooks used to be defined.

end.


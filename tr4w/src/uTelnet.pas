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
unit uTelnet;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}

interface

uses
  uConfigValues,   // Config -- migrated settings
  // ClipBrd (Vcl.ClipBrd) was listed here and never referenced -- there is no
  // Clipboard use anywhere in this unit.  Removed with the rest of the VCL.
  uCTYDAT,
  uGradient,
  PostUnit,
  VC,
  TF,
  utils_net,
  utils_text,
  utils_file,
  uCallSignRoutines,
  LogK1EA,
  uCallsigns,
  LogStuff,
  //Country9,
  LogRadio,
  uSpots,
  Windows,
  LogEdit,
  LogDupe,
  LogWind,
  WinSock2,
  //  uSpotsFilter,
  //  uDXSSpotsFilter,
  Tree,
  LogPack,
  uCommctrl,
  Messages
  ;

//type  ClusterType = (ctDXSpider, ctARCluster);
type
  TelnetStringType = (tstTR4W, tstSend, tstReceived, tstReceivedDupe,
    tstReceivedMult, tstError, tstAlert);

type
  TTBButton = packed record
    iBitmap: integer;
    idCommand: integer;
    fsState: Byte;
    fsStyle: Byte;
    bReserved: array[1..2] of Byte;
    dwData: LONGINT;
    iString: integer;
  end;
{$IFDEF AUTOSPOT}
var
  first: boolean;
{$ENDIF}
procedure SendClientStatus;
function TelnetWndDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam:
  lParam): BOOL; stdcall;
function TelnetThreadProc(Param: Pointer): DWORD; stdcall;   // Issue #23 -- DX cluster I/O thread
procedure StartTelnetConnect;                                // Issue #23 -- main-thread launcher
procedure Disconnect;
procedure TelnetConnectionError(wsaErr: integer);            // Issue #23 -- explicit code (marshaled)
function SendViaTelnetSocket(p: PAnsiChar): integer;
// Is the DX cluster link up?  Exported because MainUnit asks (it used to test
// the raw `TelnetSock <> 0`); the client object itself stays private to this
// unit so nothing outside can drive the socket behind the UI's back.
function TelnetIsConnected: boolean;
procedure AddStringToTelnetConsole(p: string; c: TelnetStringType);
procedure SaveTelnetWindowSpots;
procedure EnableTelnetToolbatButtons(b: boolean);
procedure ProcessTelnetLine(const Line: AnsiString);
function ProcessDX(const Line: AnsiString; InListBox: boolean; var Stringtype:
  TelnetStringType): boolean;
procedure tCreateAndAddNewSpot(Call: CallString; Dupe: boolean; Radio:
  RadioPtr);
procedure AppendTelnetPopupMenu(MenuText: PAnsiChar);
procedure EmunTRCLUSTERDAT(FileString: PShortString);
procedure EmunDXCLUSTERALERTLISTTXT(FileString: PShortString);
procedure EnumCLUSTERCOMMANDSTXT(FileString: PShortString);

const
  MAXITEMSINTELNETPOPUPMENU = 70;
  TELNETBUTTONS = 6{$IFDEF LANG_RUS} + 1{$ENDIF};

var
  ItemsInTelnetPopupMenu: integer;
  ClientStatus: TClientStatus = (csID: NET_CLIENTSTATUS_ID);
  //  ClusterTypeDetermined            : boolean;

  //  tClusterType                          : ClusterType = ctDXSpider;

  TelnetServer: Str50; //n4af 04-11-2013
  TempSpot: TSpotRecord;

  tbButtons: array[0..TELNETBUTTONS - 1] of TTBButton = (
    (iBitmap: VIEW_NETCONNECT;
    idCommand: 200;
    fsState: TBSTATE_ENABLED;
    fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
    dwData: 0;
    iString: 0;
    ),
    (iBitmap: VIEW_NETDISCONNECT;
    idCommand: 201;
    fsState: TBSTATE_ENABLED;
    fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
    dwData: 0;
    iString: 1;
    ),
    (iBitmap: VIEW_SORTTYPE;
    idCommand: 203;
    fsState: TBSTATE_ENABLED;
    fsStyle: TBSTYLE_CHECK or TBSTYLE_AUTOSIZE;
    dwData: 0;
    iString: 3;
    ),
    //CLEAR
    (iBitmap: VIEW_NEWFOLDER;
    idCommand: 204;
    fsState: TBSTATE_ENABLED;
    fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
    dwData: 0;
    iString: 4;
    ),
    //COMMANDS
    (iBitmap: VIEW_DETAILS;
    idCommand: 202;
    fsState: TBSTATE_ENABLED;
    fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
    dwData: 0;
    iString: 2;
    ),
    {
        (iBitmap: VIEW_PARENTFOLDER;
        idCommand: 205;
        fsState: TBSTATE_ENABLED;
        fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
        dwData: 0;
        iString: 5;
        ),
     }

         //SH/FDX 100
    (iBitmap: VIEW_PARENTFOLDER;
    idCommand: 206;
    fsState: TBSTATE_ENABLED;
    fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
    dwData: 0;
    iString: 5;
    )
{$IFDEF LANG_RUS}
    ,
    (iBitmap: - 1; //VIEW_SORTNAME;
    idCommand: 207;
    fsState: TBSTATE_ENABLED;
    fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
    dwData: 0;
    iString: 6;
    )

{$ENDIF}
    {
        (iBitmap: VIEW_PARENTFOLDER;
        idCommand: 207;
        fsState: TBSTATE_ENABLED;
        fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
        dwData: 0;
        iString: 7;
        ),
    }

         //FILTER
    {
        (iBitmap: VIEW_SORTSIZE;
        idCommand: 208;
        fsState: TBSTATE_ENABLED;
        fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
        dwData: 0;
        iString: 6;
        )
    }
    );

const
  SOCK_IDLE = 0;
  SOCK_CLIENT = 3;
  DXSpotLength = 76;

var
  FirstChar: integer;
  //  NextFirstChar                         : integer;
  OldTelnetFreezeMode: boolean;
  TelnetFreezeMode: boolean;
  TelThreadID: Cardinal;
  TelThreadHandle: THandle;     // Issue #23 -- kept so we can join the I/O thread before teardown
  TelnetStopRequested: boolean; // Issue #23 -- set by Disconnect so a thread that is still
                                // connecting bails out after connect instead of orphaning
  // TelnetSock is GONE -- the socket now lives inside TDXClusterClient, and
  // "are we connected" is ClusterClient.IsConnected.  It was doubling as a
  // connected-flag in four places, which is exactly the two-sources-of-truth
  // shape that lets a stale handle read as a live link.
  TelToolbar: HWND;
  TelnetListBox: HWND;
  TelnetCommandWindow: HWND;
  TelnetListBoxOldProc: Pointer;

  TelPopMemu: HMENU;
  TelLastPopMemu: HMENU;

  telnet_callsign_alert_list_loaded: boolean;
  TelnetCallsignAlertList: HWND;
implementation
uses uNet,
  uDXClusterClient,   // the socket half, extracted so it can be tested headless
  uDXSpotParse,       // the decode half, likewise -- ProcessDX keeps only APPLY
  uBandmap,
  LogGrid,
  SysUtils,   // Issue #997: provides SysUtils.Format/StrPCopy for asm removal.
              // ORDER/QUALIFICATION MATTERS: SysUtils also declares SysErrorMessage,
              // which differs from TF.SysErrorMessage (SysUtils trims the trailing
              // CRLF, TF does not).  Call sites needing TF's behavior are explicitly
              // TF-qualified (see TelnetConnectionError / WinSock error display).
  MainUnit;

// Issue #23 -- DX cluster I/O thread <-> main-thread message protocol.  The
// cluster thread does ALL blocking network I/O (connect + recv) and never
// touches UI or shared spot/bandmap state; it only posts these to the telnet
// window, which does that work on the main (UI) thread.  Declared here so both
// TelnetWndDlgProc (handler) and TelnetThreadProc (sender) see them.
const
  WM_TELNET_MSG         = WM_USER + 250;
  TELNET_CONNECTED      = 1;   // lParam = 0
  TELNET_CONNECT_FAILED = 2;   // lParam = WSA error code
  TELNET_DATA           = 3;   // lParam = PTelnetChunk (handler disposes it)
  TELNET_CLOSED         = 4;   // lParam = WSA error code (0 = graceful close)
  // Unterminated text sitting in the receive buffer -- a login prompt, in
  // practice.  Same chunk ownership as TELNET_DATA.  NOT fed to the spot
  // decoder: it is by definition an incomplete line, and the complete one will
  // arrive later through TELNET_DATA.
  TELNET_PENDING        = 5;   // lParam = PTelnetChunk (handler disposes it)

  // Auto-reconnect: WM_TIMER id on the telnet window, and the backoff bounds.
  // First retry is quick because the common case is a node bouncing; the cap
  // keeps a node that is down for hours to one attempt a minute.
  TELNET_RETRY_TIMER = 1;
  RETRY_DELAY_MIN    = 5000;    // 5 s
  RETRY_DELAY_MAX    = 60000;   // 60 s -- NY4I's cap

  // The login fallback: send the callsign anyway if no `login:` has arrived.
  // Covers nodes that prompt in prose we deliberately do not match, and nodes
  // that do not prompt at all.  4 s is comfortably past a banner on a live link
  // and short enough that a node which never prompts is not left hanging.
  TELNET_LOGIN_TIMER = 2;
  LOGIN_PROMPT_WAIT  = 4000;

type
  PTelnetChunk = ^TTelnetChunk;
  TTelnetChunk = record
    Len:  integer;
    Data: array[0..8192] of AnsiChar;
  end;

  // Cluster events arrive on the client's READER THREAD.  Every one of these
  // does nothing but package the news and PostMessage it -- identical
  // marshaling to the old recv loop, and for the same reason: the handler
  // touches the bandmap, the log and the UI, none of which is thread-safe.
  //
  // A class only because the event types are `of object`; it holds no state.
  TClusterEvents = class
    procedure Line(const L: AnsiString);
    procedure PendingText(const L: AnsiString);
    procedure Connected;
    procedure Disconnected(const Text: string; Code: Integer);
  end;

var
  // Declared HERE, above the window procedure, because Pascal needs the
  // declaration before the first use and the WM_TELNET_MSG handler asks
  // IsConnected long before the event methods are implemented.
  ClusterClient: TDXClusterClient;
  ClusterEvents: TClusterEvents;
  // Scratch for one received line, main thread only (the window procedure and
  // the list-box re-decode).  Replaces the 20 KB TelnetBuffer global in TF.pas.
  TelnetLine: AnsiString;
  // "A session was established and has not been torn down yet" -- the UI's own
  // state, NOT the socket's.  These are different facts the moment the far end
  // hangs up: the socket is gone while the toolbar still shows a live session.
  // This is what `TelnetSock <> 0` actually meant before the socket moved into
  // TDXClusterClient.  Main thread only.
  TelnetSessionActive: boolean;

  // ---- auto-reconnect ------------------------------------------------------
  // Armed when a session we did not end goes away; cancelled the moment the
  // OPERATOR ends one.  Gated on CONNECTION AT STARTUP (Config.tConnectionAtStartup):
  // an operator who does not want TR4W dialling the cluster on its own has
  // already said so with that command, and reconnecting would contradict it.
  //
  // Radios have had this for a while (TFactoryRadioBase, 1 s -> 30 s backoff);
  // the cluster is the one link that stayed down until somebody noticed the
  // window had gone quiet.  Mid-contest that tends to be twenty minutes.
  TelnetRetryArmed: boolean;
  TelnetRetryDelay: integer;   // ms, doubles per failure to RETRY_DELAY_MAX
  PendingTelnetHost: array[0..255] of AnsiChar;   // set on the main thread before the I/O thread starts
  PendingTelnetPort: Word;

// Forward-declared: the window procedure below arms and cancels the retry, but
// the helpers need AddStringToTelnetConsole, which is declared after it.
procedure ArmTelnetRetry; forward;
procedure CancelTelnetRetry; forward;

// The login sequence, forward-declared for the same reason: the WM_TELNET_MSG
// handler runs it and it needs SendViaTelnetSocket, which is declared later.
procedure ArmClusterLogin; forward;
procedure CancelClusterLogin; forward;
procedure SendClusterLogin; forward;
procedure AnswerClusterLoginPrompts(const Line: AnsiString); forward;

var
  // Armed on connect, disarmed when the callsign goes out. See ArmClusterLogin.
  ClusterLoginArmed: boolean;
  // ---- the login sequence --------------------------------------------------
  // Main thread only: everything here runs from the WM_TELNET_MSG handler.
  //
  // Armed on connect when the active cluster has a password, and disarmed the
  // moment one is sent OR the budget below runs out.  A password is a secret
  // being matched against a live public feed, so it gets a window, not a
  // standing subscription: without one, ANY later line containing "password:"
  // -- an announcement, somebody's spot comment -- would transmit it as a
  // command, in the clear, to everyone on the node.
  ClusterPasswordArmed: boolean;
  ClusterPasswordLinesLeft: integer;
  // Held back until the login is done.  Sending it with the callsign would
  // offer it up as the answer to a password prompt.
  ClusterPendingConnectCommand: AnsiString;

const
  // Lines of grace for the prompt to arrive.  A DXSpider banner is a few dozen
  // lines and the prompt comes FIRST, so this is generous; the point is that it
  // is finite.
  CLUSTER_PASSWORD_LINE_BUDGET = 60;

// ---------------------------------------------------------------------------
//  Issue #973 - field substitution in cluster_commands.txt
//
//  Cluster command lines may embed {TOKEN} placeholders that are expanded to
//  live program values at send time (and previewed in a hover tooltip).
//  Doubled braces are literal escapes: {{ -> {  and  }} -> }.
//  Unknown tokens are left verbatim so a typo is visible in the preview
//  rather than silently transmitted as a blank into a live cluster filter.
// ---------------------------------------------------------------------------

var
  TelCmdTooltip: HWND = 0;                   // tracking tooltip for the preview
  ClusterTooltipText: array[0..511] of AnsiChar; // stable storage for the tip text

// Trim surrounding spaces and upper-case A..Z so token matching is
// case-insensitive and tolerant of '{ MY_CALL }'.
function NormalizeClusterToken(const S: AnsiString): AnsiString;
var
   i, First, Last: integer;
   c: AnsiChar;
begin
   First := 1;
   Last := Length(S);
   while (First <= Last) and (S[First] = ' ') do
      begin
      Inc(First);
      end;
   while (Last >= First) and (S[Last] = ' ') do
      begin
      Dec(Last);
      end;
   Result := '';
   for i := First to Last do
      begin
      c := S[i];
      if (c >= 'a') and (c <= 'z') then
         begin
         c := AnsiChar(Ord(c) - 32);
         end;
      Result := Result + c;
      end;
end;

{ Returns the live value for a single (already normalized) token name.        }
{ Found is set False for an unrecognized token so the caller can leave it      }
{ verbatim. This is the single source of truth for the token vocabulary.       }
function ClusterTokenValue(const Token: AnsiString; var Found: boolean): AnsiString;
var
   RealFreq: Real;
   FreqStr: ShortString;
begin
   Found := True;
   if Token = 'MY_CALL' then
      begin
      Result := MyCall
      end
   else if Token = 'MY_STATE' then
      begin
      Result := MyState
      end
   else if Token = 'MY_SECTION' then
      begin
      Result := MySection
      end
   else if Token = 'MY_NAME' then
      begin
      Result := MyName
      end
   else if Token = 'MY_GRID' then
      begin
      Result := MyGrid
      end
   else if Token = 'MY_ZONE' then
      begin
      Result := MyZone
      end
   else if Token = 'MY_CHECK' then
      begin
      Result := MyCheck
      end
   else if Token = 'MY_PREC' then
      begin
      Result := MyPrec
      end
   else if Token = 'MY_CLASS' then
      begin
      Result := MyFDClass
      end
   else if Token = 'MY_PARK' then
      begin
      Result := MyPark
      end
   else if Token = 'MY_POSTALCODE' then
      begin
      Result := MyPostalCode
      end
   else if Token = 'CALL' then
      begin
      Result := CallWindowString
      end
   else if Token = 'DATE' then
      begin
      Result := GetDateString
      end
   else if Token = 'TIME' then
      begin
      Result := GetTimeString
      end
   else if Token = 'BAND' then
      begin
      Result := BandStringsArrayWithOutSpaces[ActiveBand]
      end
   else if Token = 'FREQ' then
      begin
      RealFreq := Radio1.FilteredStatus.Freq / 1000.0;   { Hz -> kHz }
      Str(RealFreq: 0: 1, FreqStr);
      Result := FreqStr;
      end
   else
      begin
      Found := False;
      end;
end;

// Expands every {TOKEN} in Src. Pure transform - no global state is mutated -
// so it is safe to call both from the send path and from the menu-hover proc.
function ExpandClusterTokens(Src: PAnsiChar): AnsiString;
var
   S, Token, Value: AnsiString;
   i, Len, j: integer;
   Found: boolean;
begin
   S := Src;
   Result := '';
   i := 1;
   Len := Length(S);
   while i <= Len do
      begin
      if (S[i] = '{') and (i < Len) and (S[i + 1] = '{') then
         begin
         Result := Result + '{';
         Inc(i, 2);
         end
      else if (S[i] = '}') and (i < Len) and (S[i + 1] = '}') then
         begin
         Result := Result + '}';
         Inc(i, 2);
         end
      else if S[i] = '{' then
         begin
         j := i + 1;
         while (j <= Len) and (S[j] <> '}') do
            begin
            Inc(j);
            end;
         if j > Len then
            begin
            { Unterminated brace - emit the remainder literally. }
            Result := Result + Copy(S, i, Len - i + 1);
            i := Len + 1;
            end
         else
            begin
            Token := NormalizeClusterToken(Copy(S, i + 1, j - i - 1));
            Value := ClusterTokenValue(Token, Found);
            if Found then
               begin
               Result := Result + Value;
               end
            else
               begin
               Result := Result + Copy(S, i, j - i + 1);   // leave {TOKEN} verbatim
               end;
            i := j + 1;
            end;
         end
      else
         begin
         Result := Result + S[i];
         Inc(i);
         end;
      end;
end;

{ Creates the once-per-window tracking tooltip used to preview expanded        }
{ command values. TrackPopupMenu has no native tooltips, so a manually         }
{ positioned TTF_TRACK tooltip is driven from WM_MENUSELECT.                   }
function CreateClusterCommandTooltip(Owner: HWND): HWND;
const
   TTF_TRACK = $0020;
   TTF_ABSOLUTE = $0080;
var
   ti: TOOLINFO;
begin
   Result := CreateWindowExA(0, 'tooltips_class32', nil,
      WS_POPUP or TTS_NOPREFIX or TTS_ALWAYSTIP,
      0, 0, 0, 0, Owner, 0, hInstance, nil);
   if Result = 0 then
      begin
      Exit;
      end;
   SetWindowPos(Result, HWND_TOPMOST, 0, 0, 0, 0,
      SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE);
   Windows.ZeroMemory(@ti, SizeOf(ti));
   ti.cbSize := SizeOf(ti);
   ti.uFlags := TTF_TRACK or TTF_ABSOLUTE;
   ti.HWND := Owner;
   ti.uId := 0;
   ti.lpszText := nil;
   SendMessage(Result, TTM_ADDTOOL, 0, Integer(@ti));
   SendMessage(Result, TTM_SETMAXTIPWIDTH, 0, 600);
end;

{ Hides the preview tooltip (menu closed, or item carries no tokens). }
procedure HideClusterCommandTooltip;
var
   ti: TOOLINFO;
begin
   if TelCmdTooltip = 0 then
      begin
      Exit;
      end;
   Windows.ZeroMemory(@ti, SizeOf(ti));
   ti.cbSize := SizeOf(ti);
   ti.HWND := tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle;
   ti.uId := 0;
   SendMessage(TelCmdTooltip, TTM_TRACKACTIVATE, 0, Integer(@ti));
end;

{ Shows the expanded value of the highlighted command item near the cursor.    }
{ Only real command items (id 1000..) that actually contain a token produce a   }
{ preview; everything else hides the tooltip to avoid noise.                    }
procedure ShowClusterCommandTooltip(ItemId, Flags: word);
var
   Expanded: AnsiString;
   ti: TOOLINFO;
   pt: TPoint;
begin
   if TelCmdTooltip = 0 then
      begin
      Exit;
      end;
   if (ItemId < 1000)                            or
      (ItemId > 1000 + MAXITEMSINTELNETPOPUPMENU) or
      ((Flags and MF_POPUP) <> 0)                 then
      begin
      HideClusterCommandTooltip;
      Exit;
      end;
   GetMenuStringA(TelPopMemu, ItemId, wsprintfBuffer, 256, MF_BYCOMMAND);
   Expanded := ExpandClusterTokens(wsprintfBuffer);
   if Expanded = AnsiString(wsprintfBuffer) then
      begin
      { No substitution occurred - nothing useful to preview. }
      HideClusterCommandTooltip;
      Exit;
      end;
   lstrcpynA(ClusterTooltipText, PAnsiChar(Expanded), SizeOf(ClusterTooltipText));
   Windows.ZeroMemory(@ti, SizeOf(ti));
   ti.cbSize := SizeOf(ti);
   ti.HWND := tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle;
   ti.uId := 0;
   ti.lpszText := ClusterTooltipText;
   SendMessage(TelCmdTooltip, TTM_UPDATETIPTEXT, 0, Integer(@ti));
   GetCursorPos(pt);
   SendMessage(TelCmdTooltip, TTM_TRACKPOSITION, 0,
      MakeLong(pt.X + 16, pt.Y + 16));
   SendMessage(TelCmdTooltip, TTM_TRACKACTIVATE, Integer(True), Integer(@ti));
   // The popup menu is itself a top-most window and re-asserts its z-order on
   // every mouse move (which is what drives WM_MENUSELECT), so lift the tooltip
   // back above the menu after each activation - otherwise it renders behind it.
   SetWindowPos(TelCmdTooltip, HWND_TOPMOST, 0, 0, 0, 0,
      SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE);
end;

function TelnetWndDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam:
  lParam): BOOL; stdcall;
label
  1, DrawSpot;
var

  temprect: TRect;

  i : integer;
  TempTextColor: Cardinal;
  TempPoint: TPoint;
  TDIS: PDrawItemStruct;
  InfoBuffer: array[0..1023] of AnsiChar;   // Issue #23 -- LB_GETTEXT has no size limit; must hold the
                                        // longest list item (error messages run ~230 chars, far past
                                        // the old 128, overrunning the stack).  AddStringToTelnetConsole
                                        // caps items to this size so this read can never overrun.
  StringType: TelnetStringType;
  ExpandedClusterCommand: AnsiString;   { Issue #973 }
const
  // Issue #23 -- tstTR4W (status messages) was green for no real reason; show it
  // as normal black text.  Errors stay red.
  TelnetStringColor: array[TelnetStringType] of tr4wColors = (trBlack, trBlue,
    trBlack, trLightGray, trRed, trRed, trBlack);
  //  TelnetStringOffset                    : array[TelnetStringType] of integer = (15, 2, 15, 15, 15, 20, 15);
begin
  Result := False;
  case Msg of

    WM_MEASUREITEM:
      begin
        PMeasureItemStruct(lParam).itemHeight := 13;
      end;

    WM_DRAWITEM:

      begin
        TDIS := Pointer(lParam);

        if TDIS^.itemAction = ODA_DRAWENTIRE then
           begin
           i := SendMessageA(TDIS^.hwndItem, LB_GETTEXT, TDIS^.ItemID,
             integer(@InfoBuffer));

           StringType := TelnetStringType(SendMessage(TDIS^.hwndItem,
             LB_GETITEMDATA, TDIS^.ItemID, 0));

           if StringType = tstAlert then
              begin
              GradientRect(TDIS^.HDC, TDIS^.rcItem, tr4wColorsArray[trYellow],
                tr4wColorsArray[trYellow], gdHorizontal);
              end;

           Windows.SetTextColor(TDIS^.HDC,
             tr4wColorsArray[TelnetStringColor[StringType]]);
           SetBkMode(TDIS^.HDC, TRANSPARENT);
           Windows.TextOutA(TDIS^.HDC, TDIS^.rcItem.Left + 5
             {TelnetStringOffset[StringType]}, TDIS^.rcItem.Top, InfoBuffer, i);
           Result := True;
           end;
      end;

    WM_WINDOWPOSCHANGING, WM_EXITSIZEMOVE: DefTR4WProc(Msg, lParam, hwnddlg);

    // Issue #23 -- messages from the DX cluster I/O thread (TelnetThreadProc).
    // All UI and spot/bandmap processing happen here, on the main thread.
    WM_TELNET_MSG:
      begin
        case wParam of
          TELNET_CONNECTED:
            begin
              if TR4W_TELNET_DEBUG then
                 begin
                 logger.Info('[Telnet] Connected to %s:%d', [PAnsiChar(@PendingTelnetHost[0]), PendingTelnetPort]);
                 end;
              TelnetSessionActive := True;   // there is now something to tear down
              // We are back: forget any pending retry and reset the backoff, so
              // the NEXT outage starts at 5 s again rather than inheriting the
              // 60 s this one may have crept up to.
              CancelTelnetRetry;
              TF.Format(wsprintfBuffer, '%s%s:%u', TC_CONNECTEDTO,
                @PendingTelnetHost[0], PendingTelnetPort);
              AddStringToTelnetConsole(wsprintfBuffer, tstTR4W);
              // (The TelnetBuffer clear that stood here is gone with the buffer
              // -- there is no shared receive state to reset between sessions.)
              // LOG IN.  Until 2026-08-11 this branch sent ConnectionCommand
              // INSTEAD of the callsign when one was configured -- so anybody
              // who set a connection command never logged in at all -- and
              // otherwise merely PRE-FILLED the input box with MyCall and waited
              // for the operator to press Enter.
              //
              // WAIT FOR THE PROMPT, with a timeout.  The first version of this
              // sent the callsign the instant the socket opened, on the argument
              // that TR4W had always effectively done so.  It had not: the old
              // code only PRE-FILLED the input box and the operator pressed
              // Enter after seeing the prompt.  HamAlert discarded a callsign
              // that arrived before its banner and then sat at `login:` waiting
              // (NY4I, 2026-08-12).  See ArmClusterLogin.
              ArmClusterLogin;
              SendClientStatus;
              EnableTelnetToolbatButtons(True);
              EnableWindowTrue(hwnddlg, 104);
            end;

          TELNET_CONNECT_FAILED:
            begin
              // Issue #23 -- keep the detailed WinSock reason in the log for
              // diagnostics, but show the operator a short message naming the
              // host they tried to reach (the raw message is long and unwrapped).
              // CODE 0 MEANS NO SOCKET ERROR, so SysErrorMessage(0) renders as
              // "The operation completed successfully" -- a failure line that
              // says nothing failed, which is exactly how the already-connected
              // refusal disguised itself.  The real reason came through
              // OnDisconnected; do not overwrite it with a lie.
              if lParam = 0 then
                 begin
                 logger.Error('[Telnet] Could not connect to %s:%d -- no socket error reported ' +
                              '(see the preceding reason)',
                   [PAnsiChar(@PendingTelnetHost[0]), PendingTelnetPort]);
                 end
              else
                 begin
                 logger.Error('[Telnet] Could not connect to %s:%d -- WinSock %d: %s',
                   [PAnsiChar(@PendingTelnetHost[0]), PendingTelnetPort, lParam,
                    SysUtils.SysErrorMessage(lParam)]);
                 end;

              // TEARDOWN BEFORE COSMETICS.  Disconnect used to sit after the
              // console formatting, and the whole log shows it NEVER RAN across
              // three failures -- leaving the session up and wedging every
              // later attempt.  Whatever aborted the handler did so before this
              // line; putting the state change first means a formatting problem
              // can no longer cost the teardown.
              Disconnect;

              TF.Format(wsprintfBuffer, '%s%s:%u', TC_FAILEDTOCONNECTTO,
                @PendingTelnetHost[0], PendingTelnetPort);
              AddStringToTelnetConsole(wsprintfBuffer, tstError);
              // Keep trying, with a longer gap each time.  A failed RETRY comes
              // back through here, which is what makes the backoff advance --
              // and a first connect that fails is retried too, so a TR4W
              // started before the network is up still ends up connected.
              ArmTelnetRetry;
            end;

          TELNET_DATA:
            begin
              if lParam <> 0 then
                 begin
                 // The chunk now carries exactly ONE complete line, terminator
                 // already stripped by the transport.  No shared receive
                 // buffer, no NUL bookkeeping, no re-scanning for line breaks.
                 SetString(TelnetLine, PAnsiChar(@PTelnetChunk(lParam)^.Data[0]),
                           PTelnetChunk(lParam)^.Len);
                 Dispose(PTelnetChunk(lParam));
                 // BEFORE the spot decoder, and unconditionally: a login prompt
                 // is not a spot, and the answer must go out before anything
                 // else this line might trigger.  Costs one Pos() per line and
                 // only while the window is open -- it returns immediately once
                 // the password has gone or the budget has run out.
                 AnswerClusterLoginPrompts(TelnetLine);
                 ProcessTelnetLine(TelnetLine);
                 end;
            end;

          // AN UNTERMINATED PROMPT. Answered, but NOT decoded and NOT displayed:
          // it is an incomplete line by definition, and the complete one arrives
          // later through TELNET_DATA. Feeding it to ProcessDX would decode the
          // same text twice.
          TELNET_PENDING:
            begin
              if lParam <> 0 then
                 begin
                 SetString(TelnetLine, PAnsiChar(@PTelnetChunk(lParam)^.Data[0]),
                           PTelnetChunk(lParam)^.Len);
                 Dispose(PTelnetChunk(lParam));
                 AnswerClusterLoginPrompts(TelnetLine);
                 end;
            end;

          TELNET_CLOSED:
            begin
              // Guard on the SESSION, not on the socket.  This asks "is there a
              // session still to tear down", which is exactly what the old
              // `TelnetSock <> 0` meant -- that handle was cleared only by our
              // own Disconnect.
              //
              // Asking ClusterClient.IsConnected here was WRONG and shipped
              // broken: on a SERVER-initiated close the socket is already down
              // by the time this posted message is handled, so the guard was
              // False precisely in the case it exists to handle.  Disconnect
              // never ran, so the toolbar kept showing a live session -- Connect
              // greyed, Disconnect enabled -- and TelThreadID was never cleared,
              // which also blocked reconnecting.  (NY4I: sent `bye` to the
              // simulator, 2026-08-04.)
              if TelnetSessionActive then
                 begin
                 if lParam <> 0 then
                    begin
                    TelnetConnectionError(lParam);
                    end;
                 Disconnect;
                 // We did not ask for this -- the node hung up or the link
                 // died -- so start trying to get it back.  Disconnect has
                 // already restored the toolbar, so the operator can still
                 // take over at any point and CancelTelnetRetry will stop us.
                 ArmTelnetRetry;
                 end;
            end;
        end;
      end;

    // Auto-reconnect tick.  One-shot: kill it first, then try.  If the attempt
    // fails, TELNET_CONNECT_FAILED arms the next one with a longer delay, so
    // the loop continues without this handler knowing how many have gone by.
    WM_TIMER:
      begin
        if wParam = TELNET_RETRY_TIMER then
           begin
           KillTimer(hwnddlg, TELNET_RETRY_TIMER);
           TelnetRetryArmed := False;
           AddStringToTelnetConsole('Reconnecting...', tstTR4W);
           StartTelnetConnect;
           end;

        // No `login:` arrived in time. Send the callsign anyway: the node may
        // prompt in prose we deliberately do not match, or not prompt at all.
        // SendClusterLogin kills this timer and is a no-op if the prompt won
        // the race.
        if wParam = TELNET_LOGIN_TIMER then
           begin
           if ClusterLoginArmed then
              begin
              logger.Info('[Telnet] No login prompt within %d ms -- sending the callsign anyway',
                          [LOGIN_PROMPT_WAIT]);
              end;
           SendClusterLogin;
           end;
      end;

    WM_INITDIALOG:
      begin

        CreateComboBox(hwnddlg, 102);
        CreateComboBox(hwnddlg, 106);
        CreateButton(BS_DEFPUSHBUTTON or BS_CENTER or WS_DISABLED, RC_SEND, 0,
          0, 60, hwnddlg, 104);
        CreateOwnerDrawListBox(LBS_NOTIFY or LBS_OWNERDRAWFIXED or LBS_HASSTRINGS
          or LBS_NOINTEGRALHEIGHT or WS_CHILD or WS_VISIBLE or WS_VSCROLL or
          WS_HSCROLL or WS_TABSTOP, hwnddlg);
        //

        tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle := hwnddlg;
        telnet_callsign_alert_list_loaded := False;
        ItemsInTelnetPopupMenu := 0;

        EnumerateLinesInFile('DXCLUSTER_ALERT_LIST.TXT',
          EmunDXCLUSTERALERTLISTTXT, True);

        // Issue 392
        // If the cluster in the config file is not in TRCLUSTER.DAT, this does not connect.
        // We could add it to the EnumTRClusterDAT or just take it as a host and connect.
        // We should check the hosts is valid too but we can see that in the connect.
        // Also, ensure we get a useful error message when we cannot connect.
        // Currently it just says Operation Successful which is false and not helpful.
        EnumerateLinesInFile('TRCLUSTER.DAT', EmunTRCLUSTERDAT, False);
        EmunTRCLUSTERDAT(@TelnetServer);
        // Issue 392 ny4i - This adds the value in the config for telnet server to the drop-down
        i := SendDlgItemMessageA(hwnddlg, 102, CB_FINDSTRING, Cardinal(-1),
          integer(@TelnetServer[1])); //n4af 4.35.1
        //     i := SendDlgItemMessage(hwnddlg, 102, CB_FINDSTRINGEXACT, -1,integer(@TelnetServer[1]));
        if i <> CB_ERR then
           begin
           tCB_SETCURSEL(hwnddlg, 102, i);
           end;

        TelToolbar := uCommctrl.CreateToolBarEx(hwnddlg,
          WS_CHILD or
          WS_VISIBLE or
          TBSTYLE_TOOLTIPS or
          TBSTYLE_LIST or
          TBSTYLE_TRANSPARENT or
          TBSTYLE_AUTOSIZE or
          TBSTYLE_FLAT,
          0, 13, HINST_COMMCTRL, IDB_VIEW_SMALL_COLOR, @tbButtons,
          TELNETBUTTONS, 0, 0, 0, 0, SizeOf(TTBButton));

        SendMessage(TelToolbar, TB_ADDSTRING, 0,
          integer(PAnsiChar(TC_TELNET{$IFDEF LANG_RUS} + '?'#0#0{$ENDIF})));
        EnableTelnetToolbatButtons(False);

        TelnetListBox := Get101Window(hwnddlg);
        // Issue #997: asm tWM_SETFONT -> call the existing TF helper directly
        tWM_SETFONT(TelnetListBox, LucidaConsoleFont);

        TelnetCommandWindow := GetDlgItem(hwnddlg, 106);

        //        TelnetListBoxOldProc := Pointer(Windows.SetWindowLong(TelnetListBox, GWL_WNDPROC, integer(@TelnetListBoxNewProc)));
                //        SendMessage(hwnddlg, WM_SETICON, ICON_SMALL, DisconnectedIcon);
        //            SendMessage(TelnetConnectionStatus, STM_SETICON, 0, 0);

        if Config.tConnectionAtStartup then
           begin
           SendMessage(hwnddlg, WM_COMMAND, 200, 0);
           end;

        TelPopMemu := CreatePopupMenu;
        TelLastPopMemu := TelPopMemu;
        AppendTelnetPopupMenu('HELP');
        AppendTelnetPopupMenu('SHOW/USERS');
        AppendTelnetPopupMenu('SHOW/WWV');
        AppendTelnetPopupMenu('SHOW/FILTER');

        EnumerateLinesInFile('CLUSTER_COMMANDS.TXT', EnumCLUSTERCOMMANDSTXT,
          True);

        // Issue #973: tooltip that previews each command's expanded value.
        TelCmdTooltip := CreateClusterCommandTooltip(hwnddlg);

        //tLB_ADDSTRING(TelnetListBox,'DX DE SM6WET:    28025.0  G0ORH        SRI, THIS IS CORRECT           0953Z JO68  ');
        //tLB_ADDSTRING(TelnetListBox,'DX DE G4MJS:     14180.0  2DONCG       YOUR TURN TO MAKE A BREW       0953Z JO01  ');
        //tLB_ADDSTRING(TelnetListBox,'DX DE LU6FL:      1845.0  LU6FL        CQ CQ TEST SSB                 0953Z FF97  ');
        //tLB_ADDSTRING(TelnetListBox,'DX DE RZ3DSD:    14258.9  RA3RGQ/1                                    0953Z  ');
        //tLB_ADDSTRING(TelnetListBox,'DX DE F5PPO:     18135.0  CQ9U                                        0953Z  ');
        //tLB_ADDSTRING(TelnetListBox,'DX DE PA3C:      24897.2  LZ1PJ                                       0954Z JO33  ');

      end;
    //    WM_HELP: tWinHelp(7);

    // Issue #973: preview the highlighted command's expanded value in a tooltip.
    WM_MENUSELECT:
      begin
        if (HiWord(wParam) = $FFFF) and (lParam = 0) then
           begin
           HideClusterCommandTooltip   // menu closed
           end
        else
           begin
           ShowClusterCommandTooltip(LoWord(wParam), HiWord(wParam));
           end;
      end;

    WM_EXITMENULOOP:
      begin
        HideClusterCommandTooltip;
      end;

    WM_COMMAND:
      begin
        if HiWord(wParam) = LBN_SELCHANGE then
           begin
           DlgDirSelectExA(hwnddlg, wsprintfBuffer, SizeOf(wsprintfBuffer), 101);
           end;

        if HiWord(wParam) = LBN_DBLCLK then
           begin
           //      DlgDirSelectEx(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, wsprintfBuffer, SizeOf(wsprintfBuffer), 101);  //n4af
           //    DlgDirList(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, wsprintfBuffer, 101, 106, DDL_ARCHIVE or DDL_DIRECTORY);       //n4af
           //   ShowMessage(SysErrorMessage(GetLastError));
           i := SendMessage(TelnetListBox, LB_GETCURSEL, 0, 0);
           if i = LB_ERR then
              begin
              Exit;
              end;
           // Re-decode the line the operator clicked, straight from the list box
           // -- no shared buffer in the middle any more.
           SendMessageA(TelnetListBox, LB_GETTEXT, i, integer(@TempBuffer1[0]));
           TelnetLine := AnsiString(PAnsiChar(@TempBuffer1[0]));
           if Copy(TelnetLine, 1, 6) = 'DX de ' then
              begin
              if ProcessDX(TelnetLine, True, StringType) then
                 begin
                 TuneRadioToSpot(TempSpot, RadioOne);
                 end;
              end;

           end;

        if (wParam >= 1000) then
          if (wParam <= 1000 + MAXITEMSINTELNETPOPUPMENU) then
             begin
             GetMenuStringA(TelPopMemu, wParam, wsprintfBuffer, 256,
               MF_BYCOMMAND);
             //n4af    4.51.1
             // Issue #973: expand {TOKEN} fields to live values before sending.
             // Cap to 250 so SendViaTelnetSocket's CRLF append cannot overflow
             // its 256-byte wsprintfBuffer when expansion grows the string.
             ExpandedClusterCommand := ExpandClusterTokens(wsprintfBuffer);
             if Length(ExpandedClusterCommand) > 250 then
                begin
                SetLength(ExpandedClusterCommand, 250);
                end;
             SendViaTelnetSocket(PAnsiChar(ExpandedClusterCommand));
             end;

        case wParam of
          // Operator clicked Disconnect: cancel FIRST, so a retry armed by an
          // earlier drop cannot fire and drag the link back up against their
          // wishes.  This is the one place that must beat the timer.
          201:
            begin
            CancelTelnetRetry;
            Disconnect;
            end;

          202:
            begin
              GetCursorPos(TempPoint);
              TrackPopupMenu(TelPopMemu, TPM_TOPALIGN, TempPoint.X, TempPoint.Y
                + 10, 0, hwnddlg, nil);
            end;

          203: InvertBoolean(TelnetFreezeMode);
          //            PostMessage(hwnddlg, WM_SYSCOMMAND, SC_MOVE, 0);
          204: SendDlgItemMessage(hwnddlg, 101, LB_RESETCONTENT, 0, 0);

          //            ScrollWindowEx(TelnetListBox, 0, -50, 0, 0, 0, 0, SW_SMOOTHSCROLL);
//          205: SendViaSocket('SH/USERS');
          206: SendViaTelnetSocket('SH/DX 50'); //n4af 04-11-2014

{$IFDEF LANG_RUS}
          207: ShowHelp('ru_dxcluster');
{$ENDIF}

          //          DialogBox(hInstance, MAKEINTRESOURCE(44), hwnddlg, @SpotsFilterDlgProc);
          200: StartTelnetConnect;   // Issue #23 -- launch the DX cluster I/O thread

          104:
            begin
              SendMessage(TelnetCommandWindow, CB_SHOWDROPDOWN, 0, 0);
              Windows.GetWindowTextA(TelnetCommandWindow, TempBuffer1,
                SizeOf(TempBuffer1));
              if TempBuffer1[0] = #0 then
                 begin
                 Exit;
                 end;
              SendViaTelnetSocket(TempBuffer1);
              Windows.SetWindowTextA(TelnetCommandWindow, nil);
              if
                SendMessageA(TelnetCommandWindow, CB_FINDSTRING, -1,
                integer(PAnsiChar(@TempBuffer1))) = CB_ERR then
                //  SendMessage(TelnetCommandWindow, CB_FINDSTRINGEXACT, -1, integer(PChar(@TempBuffer1))) = CB_ERR then
                 begin
                 tCB_ADDSTRING_PCHAR(hwnddlg, 106, TempBuffer1);
                 end;

            end

        end;
        {
                if HiWord(wParam) = LBN_KILLFOCUS then TelnetFreezeMode := OldTelnetFreezeMode;

                if HiWord(wParam) = LBN_SETFOCUS then
                  begin
                    OldTelnetFreezeMode := TelnetFreezeMode;
                    TelnetFreezeMode := True;
                  end;
         }
      end;

    //    WM_NCHITTEST:      if TelnetHint <> 0 then PostMessage(TelnetHint, WM_CLOSE, 0, 0);

    WM_LBUTTONDOWN: DragWindow(hwnddlg);

    WM_CLOSE: 1:
      begin
        CloseTR4WWindow(tw_TELNETWINDOW_INDEX);
      end;

    WM_DESTROY:
      begin
        Disconnect;
        TelnetCommandWindow := 0;
        TelnetListBox := 0;
        SaveTelnetWindowSpots;
        DestroyMenu(TelPopMemu);
      end;
    {
        WM_NCLBUTTONDBLCLK:
          begin
            if IsIconic(hwnddlg) = False then
              PostMessage(hwnddlg, WM_SYSCOMMAND, SC_MINIMIZE, 10000);
          end;
    }
    WM_SIZE:
      begin

        Windows.GetClientRect(hwnddlg, temprect);
        TempTextColor := temprect.Top + 28;

        Windows.SetWindowPos(Windows.GetDlgItem(hwnddlg, 102), HWND_TOP, 0,
          TempTextColor, 160, 300, SWP_SHOWWINDOW);

        Windows.SetWindowPos(Windows.GetDlgItem(hwnddlg, 106), HWND_TOP, 165,
          TempTextColor, temprect.Right - temprect.Left - 210 - 25, 300,
          SWP_SHOWWINDOW);
        Windows.SetWindowPos(Windows.GetDlgItem(hwnddlg, 104), HWND_TOP,
          temprect.Right - temprect.Left - 40 - 25, TempTextColor, 0, 0,
          SWP_NOSIZE
          or SWP_SHOWWINDOW);

        Windows.SetWindowPos(TelnetListBox, HWND_TOP, 0, 27 + 25, temprect.Right
          - temprect.Left, temprect.Bottom - temprect.Top - 55,
          {SWP_NOSIZE or }SWP_SHOWWINDOW);
        MoveWindow(TelToolbar, 0, 0, LoWord(lParam), 0, True);
        SendMessage(TelnetListBox, WM_VSCROLL, SB_BOTTOM, 0);

      end;

  end;
end;

// Runs on the DX cluster I/O thread.  Connects (blocking), then loops on
// blocking recv, posting each chunk to the telnet window.  Posts CONNECTED /
// CONNECT_FAILED / CLOSED for lifecycle.  Does NO UI and touches NO shared
// contest/bandmap state -- that all happens on the main thread in the handler.
procedure TClusterEvents.Line(const L: AnsiString);
var
  chunk: PTelnetChunk;
  n:     integer;
begin
  n := Length(L);
  if n > SizeOf(chunk^.Data) - 1 then
     begin
     n := SizeOf(chunk^.Data) - 1;   // room for the NUL
     end;
  New(chunk);
  if n > 0 then
     begin
     Move(L[1], chunk^.Data[0], n);
     end;
  chunk^.Data[n] := #0;
  chunk^.Len := n;
  if TR4W_TELNET_DEBUG then
     begin
     logger.Info('[Telnet RX %d] %s', [n, PAnsiChar(@chunk^.Data[0])]);
     end;
  PostMessage(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle,
              WM_TELNET_MSG, TELNET_DATA, LPARAM(chunk));
end;

// Same marshalling as Line, and for the same reason -- this fires on the reader
// thread and the handler answers prompts and touches UI state.
procedure TClusterEvents.PendingText(const L: AnsiString);
var
  chunk: PTelnetChunk;
  n:     integer;
begin
  n := Length(L);
  if n > SizeOf(chunk^.Data) - 1 then
     begin
     n := SizeOf(chunk^.Data) - 1;
     end;
  New(chunk);
  if n > 0 then
     begin
     Move(L[1], chunk^.Data[0], n);
     end;
  chunk^.Data[n] := #0;
  chunk^.Len := n;
  if TR4W_TELNET_DEBUG then
     begin
     logger.Info('[Telnet RX pending %d] %s', [n, PAnsiChar(@chunk^.Data[0])]);
     end;
  PostMessage(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle,
              WM_TELNET_MSG, TELNET_PENDING, LPARAM(chunk));
end;

procedure TClusterEvents.Connected;
begin
  PostMessage(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle,
              WM_TELNET_MSG, TELNET_CONNECTED, 0);
end;

procedure TClusterEvents.Disconnected(const Text: string; Code: Integer);
begin
  // Connect failure and mid-session close are the same message to the user; the
  // handler distinguishes them, as before, by which one it receives.
  PostMessage(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle,
              WM_TELNET_MSG, TELNET_CLOSED, Code);
end;

// Runs on its own thread purely because Connect BLOCKS (10 s timeout) and must
// not freeze the UI.  Once connected, the client's own reader thread takes over
// and this one exits -- there is no recv loop here any more.
function TelnetThreadProc(Param: Pointer): DWORD; stdcall;
begin
  Result := 0;

  if TR4W_TELNET_DEBUG then
     begin
     logger.Info('[Telnet] Connecting to %s:%d', [PAnsiChar(@PendingTelnetHost[0]), PendingTelnetPort]);
     end;

  if not ClusterClient.Connect(string(AnsiString(PAnsiChar(@PendingTelnetHost[0]))),
                               PendingTelnetPort) then
     begin
     // Reason already reported through OnDisconnected; tell the window the
     // ATTEMPT failed so it prints "failed to connect" rather than "closed".
     PostMessage(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle,
                 WM_TELNET_MSG, TELNET_CONNECT_FAILED, 0);
     Exit;
     end;

  // Issue #23 -- Disconnect/window-close while we were blocked in connect: drop
  // the link we just made instead of leaving it orphaned.
  if TelnetStopRequested then
     begin
     ClusterClient.Disconnect;
     end;
end;

// Runs on the MAIN thread (Connect button).  Reads host:port from the dialog
// (UI access stays on the UI thread), then spawns the I/O thread.
procedure StartTelnetConnect;
var
  StackTelHandle: HWND;
  i: integer;
begin
  if TelThreadID <> 0 then
     begin
     Exit;   // already connecting / connected
     end;

  // A LIVE SESSION IS TORN DOWN FIRST.  Connecting while already connected used
  // to reach TDXClusterClient.Connect, which refused with a bare False; the
  // operator saw "Could not connect -- WinSock 0", the old session was left up,
  // and because IsConnected stayed true EVERY later attempt failed the same way
  // until TR4W was restarted (NY4I, 2026-08-12, three failures in the log).
  //
  // Asking to connect is unambiguous about intent -- especially now that the
  // active cluster can change in Preferences -- so switch, rather than refuse.
  if ClusterClient.IsConnected then
     begin
     logger.Info('[Telnet] Connect requested while connected -- dropping the current session first');
     Disconnect;
     end;

  StackTelHandle := tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle;
  PendingTelnetPort := 23;
  i := Windows.GetDlgItemTextA(StackTelHandle, 102, TempBuffer1, SizeOf(TempBuffer1));

  // TempBuffer1 is 0-based; scan [length-1 .. 0].  ':' splits host:port; ' '
  // terminates the host.
  dec(i);
  while i >= 0 do
     begin
     if TempBuffer1[i] = ':' then
        begin
        PendingTelnetPort := pchartoint(@TempBuffer1[i + 1]);
        TempBuffer1[i] := #0;
        end;
     if TempBuffer1[i] = ' ' then
        begin
        TempBuffer1[i] := #0;
        end;
     dec(i);
     end;

  Windows.lstrcpynA(PendingTelnetHost, TempBuffer1, SizeOf(PendingTelnetHost));

  // Issue #23 -- immediate visual feedback so connect is not a black box:
  // show the attempt in the window and switch the toolbar to the connected
  // state (grays Connect, enables Disconnect) the instant the user clicks.
  TF.Format(wsprintfBuffer, '%s%s:%u', TC_CONNECTINGTO, @PendingTelnetHost[0],
    PendingTelnetPort);
  AddStringToTelnetConsole(wsprintfBuffer, tstTR4W);
  EnableTelnetToolbatButtons(True);

  // Issue #23 -- start each session live: a Freeze left on from a previous
  // connection would silently suppress auto-scroll on reconnect, looking like
  // the cluster is dead.  Clear the mode and un-press the Freeze toolbar button.
  TelnetFreezeMode := False;
  OldTelnetFreezeMode := False;
  SendMessage(TelToolbar, TB_CHECKBUTTON, 203, 0);

  TelnetStopRequested := False;
  logger.Debug('Starting DX cluster I/O thread');
  TelThreadHandle := tCreateThread(@TelnetThreadProc, TelThreadID);
  logger.Debug('Created DX cluster thread with threadid of %d', [TelThreadID]);
end;

procedure Disconnect;
var
  StackTelHandle: HWND;
begin
  // NOT gated on TELNET DEBUG any more.  "Did the teardown run?" turned out to
  // be the one question the log could not answer: three failed connects in a
  // row left the session up, and the absence of this line -- with debug ON --
  // was the only evidence that Disconnect never executed.  A state change this
  // consequential should say so unconditionally; it is one line per session.
  logger.Info('[Telnet] Disconnecting (connected=%s)',
              [BoolToStr(ClusterClient.IsConnected, True)]);

  // HERE, because this is the ONE teardown both paths reach -- the operator's
  // Disconnect button and a server-initiated close.  A login timer left running
  // would otherwise fire after the link is gone, or against the next session.
  CancelClusterLogin;

  StackTelHandle := tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle;

  // Issue #23 -- show a disconnect message only if we were actually connected.
  // A failed connect routes through here too but never connected, so
  // "DISCONNECTED from" would be wrong there.
  //
  // Guarded on the SESSION for the same reason as the TELNET_CLOSED handler: on
  // a server-initiated close the socket is already gone, so IsConnected would
  // suppress the very message the operator most needs to see.
  if TelnetSessionActive then
     begin
     TF.Format(wsprintfBuffer, '%s%s:%u', TC_DISCONNECTEDFROM, @PendingTelnetHost[0],
       PendingTelnetPort);
     AddStringToTelnetConsole(wsprintfBuffer, tstTR4W);
     end;

  // Tell a still-connecting thread to bail (it checks this after connect, since
  // we can't unblock an in-progress connect).
  TelnetStopRequested := True;

  // Drop the link first -- this unblocks the client's reader so it can exit --
  // then JOIN the connect thread before any teardown.  Without the join the
  // main thread tore down (and kept allocating/logging) while the I/O thread
  // was still terminating, which corrupted state and crashed.  Disconnect
  // itself joins the reader, so both threads are gone before we return.
  ClusterClient.Disconnect;
  if TelThreadHandle <> 0 then
     begin
     WaitForSingleObject(TelThreadHandle, 5000);
     CloseHandle(TelThreadHandle);
     TelThreadHandle := 0;
     end;
  TelThreadID := 0;
  // Session is over: the next TELNET_CLOSED (a late one from the reader, say)
  // must not run this teardown a second time.
  TelnetSessionActive := False;

  EnableWindowFalse(StackTelHandle, 104);
  EnableWindowTrue(StackTelHandle, 102);
  EnableTelnetToolbatButtons(False);
  //  tEnableMenuItem(menu_ctrl_sendspot, MF_BYCOMMAND + MF_GRAYED);
  SendClientStatus;
end;

procedure TelnetConnectionError(wsaErr: integer);
var
  msg: string;
begin
  // Issue #23 -- log the WinSock error to the general error log always
  // (independent of TELNET DEBUG) and show it in the telnet window.  The code is
  // passed in (not read from WSAGetLastError) because it may have been captured
  // on the I/O thread and marshaled here -- WSAGetLastError is per-thread.
  msg := SysUtils.SysErrorMessage(wsaErr);
  logger.Error('[Telnet] WinSock error %d: %s', [wsaErr, msg]);
  AddStringToTelnetConsole(msg, tstError);
end;

function SendViaTelnetSocket(p: PAnsiChar): integer;
var
  sent: integer;
begin
  Result := 0;
  if not ClusterClient.IsConnected then
     begin
     Exit;
     end;
  if TR4W_TELNET_DEBUG then   // Issue #23
     begin
     logger.Info('[Telnet TX] %s', [p]);
     end;
  AddStringToTelnetConsole(p, tstSend);
  // The CRLF the old code appended by hand is now SendLine's job, and the
  // shared wsprintfBuffer it formatted through is gone with it -- that global
  // was only ever safe because this runs on the main thread.
  //
  // Failure is an exception from Indy rather than a SOCKET_ERROR return, so the
  // teardown that used to follow a bad send() lives in the handler below.  Same
  // outcome: report, then drop the dead link.
  try
    ClusterClient.SendLine(AnsiString(p));
  except
    on E: Exception do
       begin
       Result := -1;
       AddStringToTelnetConsole(PAnsiChar(AnsiString(E.Message)), tstError);
       Disconnect;
       end;
  end;
end;

{ ------------------------------------------------------- the login sequence --

  Three steps, in order, and the order is the whole design:

     connect  ->  send the callsign
              ->  answer `password:` if the cluster has one
              ->  send the "After connecting" command

  WHY THE CALLSIGN IS SENT UNPROMPTED.  Nodes do prompt, but the prose forms
  ("Enter your callsign", 228 lines of the capture corpus) are sysop text that a
  localised node translates -- and prompts carry NO LINE TERMINATOR, so they
  arrive smeared into the next chunk. Matching either is fragile in a way that
  fails on somebody else's node. Sending on connect needs no matching at all.

  WHY THE PASSWORD IS NOT.  `password:` is a protocol token from the same layer
  as `login:` -- a Spanish DXSpider node that translates its entire banner still
  prints both in English -- so matching it is safe in a way the prose is not.
  And a password must NEVER be sent unprompted: a node that did not ask reads it
  as a command, which puts it on the screen and in that node's logs.
                                                                              }

// The password goes out WITHOUT the console echo and WITHOUT the [Telnet TX]
// log line that SendViaTelnetSocket writes for everything else -- which is the
// entire reason this does not simply call it. Sending the operator's password
// through the normal path would print it in the telnet window and write it to
// tr4w.log in the clear.
procedure SendClusterPasswordQuietly;
begin
   if not ClusterClient.IsConnected then
      begin
      Exit;
      end;

   try
      ClusterClient.SendLine(AnsiString(TelnetPassword));
      // The console still SAYS something happened -- an operator watching a
      // login stall needs to know the password went, just not what it was.
      AddStringToTelnetConsole('<password sent>', tstSend);
   except
      on E: Exception do
         begin
         AddStringToTelnetConsole(PAnsiChar(AnsiString(E.Message)), tstError);
         Disconnect;
         end;
   end;
end;

procedure SendClusterConnectCommand;
begin
   if ClusterPendingConnectCommand = '' then
      begin
      Exit;
      end;

   SendViaTelnetSocket(PAnsiChar(ClusterPendingConnectCommand));
   // Once only: this is reached from two places -- straight after the login when
   // there is no password, and after the password when there is.
   ClusterPendingConnectCommand := '';
end;

// Called on connect. Nothing is sent yet -- we wait for `login:`, and start a
// timer so that a node which never sends one still gets a callsign.
//
// WHY WAITING IS RIGHT AND SENDING WAS NOT. HamAlert discards a callsign that
// arrives before its banner, then prompts and waits forever. The corpus proves
// prompts EXIST; it could not prove an early send is accepted, because TR4W has
// never made one -- the operator always typed it after seeing the prompt. The
// first version of this read the corpus as licence to send early. It was not.
//
// The timer is what keeps the prompt-matching honest. Because a node that
// prompts in prose ("Enter your callsign") or in a translation is handled by the
// clock rather than by a word list, LineAsksForLogin can stay at the one token
// that survives translation instead of growing a phrasebook.
// Called wherever a session ends, so a pending login timer cannot outlive it and
// fire against the next connection -- or, worse, against a link the operator has
// just deliberately dropped.  SendViaTelnetSocket would refuse on a closed
// socket anyway, but a timer nobody cancelled is the kind of thing that only
// misbehaves once the code around it changes.
procedure CancelClusterLogin;
begin
   if ClusterLoginArmed then
      begin
      KillTimer(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle,
                TELNET_LOGIN_TIMER);
      ClusterLoginArmed := False;
      end;
   ClusterPasswordArmed := False;
   ClusterPendingConnectCommand := '';
end;

procedure ArmClusterLogin;
begin
   // Any leftovers from a previous session go first: reconnecting must start the
   // sequence cleanly, not inherit a half-finished one.
   CancelClusterLogin;
   ClusterLoginArmed := True;

   // Held back until the login is done -- see the header above.
   ClusterPendingConnectCommand := AnsiString(Trim(string(ConnectionCommand)));
   ClusterPasswordArmed := False;
   ClusterPasswordLinesLeft := 0;

   SetTimer(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle,
            TELNET_LOGIN_TIMER, LOGIN_PROMPT_WAIT, nil);
end;

procedure SendClusterLogin;
var
   call: string;
begin
   if not ClusterLoginArmed then
      begin
      // Already sent. Reached from both the prompt and the timer, and whichever
      // loses the race must do nothing -- sending the callsign twice puts the
      // second copy in as a COMMAND once the node has logged us in.
      Exit;
      end;

   ClusterLoginArmed := False;
   KillTimer(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, TELNET_LOGIN_TIMER);

   // BLANK MEANS MY CALL, which is what the Preferences field promises. Resolved
   // HERE and not at config-apply time, because MyCall can change between
   // startup and a connect -- a different contest, a different operator.
   call := Trim(TelnetLoginCall);
   if call = '' then
      begin
      call := Trim(string(MyCall));
      end;

   if call = '' then
      begin
      // No callsign anywhere. Reported rather than sending an empty line and
      // leaving the operator looking at a node that never greets them.
      AddStringToTelnetConsole('No callsign configured -- cannot log in to the cluster',
                               tstError);
      logger.Warn('[Telnet] Connected but neither the cluster login nor MY CALL is set');
      Exit;
      end;

   SendViaTelnetSocket(PAnsiChar(AnsiString(call)));

   if TelnetPassword <> '' then
      begin
      ClusterPasswordArmed := True;
      ClusterPasswordLinesLeft := CLUSTER_PASSWORD_LINE_BUDGET;
      logger.Info('[Telnet] Logged in as %s; waiting for a password prompt', [call]);
      end
   else
      begin
      logger.Info('[Telnet] Logged in as %s', [call]);
      SendClusterConnectCommand;
      end;
end;

// Called for every received line. Answers whichever prompt is outstanding --
// the login first, then the password -- and returns immediately once neither is.
procedure AnswerClusterLoginPrompts(const Line: AnsiString);
begin
   if ClusterLoginArmed then
      begin
      if LineAsksForLogin(Line) then
         begin
         SendClusterLogin;
         end;
      // Nothing else to do with this line: the password prompt cannot precede
      // the callsign, and the timer covers a prompt that never comes.
      Exit;
      end;

   if not ClusterPasswordArmed then
      begin
      Exit;
      end;

   // The test itself lives in uDXSpotParse, with the other line decoders and
   // under test -- see LineAsksForPassword for why it is a substring, why the
   // colon is load-bearing, and why English is the right answer here.
   if LineAsksForPassword(Line) then
      begin
      ClusterPasswordArmed := False;
      SendClusterPasswordQuietly;
      SendClusterConnectCommand;
      Exit;
      end;

   Dec(ClusterPasswordLinesLeft);
   if ClusterPasswordLinesLeft <= 0 then
      begin
      // The window closed with no prompt. Said out loud: the alternative is a
      // configured password that silently never gets used, which looks like the
      // password being wrong.
      ClusterPasswordArmed := False;
      logger.Info('[Telnet] No password prompt in %d lines -- the stored password was not sent',
                  [CLUSTER_PASSWORD_LINE_BUDGET]);
      // The command still goes, because the node evidently did not want a
      // password and the operator asked for this to be sent after connecting.
      SendClusterConnectCommand;
      end;
end;

procedure AddStringToTelnetConsole(p: string; c: TelnetStringType);
var
  Handle: HWND;
  buf: array[0..1023] of AnsiChar;   // Issue #23 -- bound the list item to InfoBuffer's size
begin
  if TR4W_TELNET_DEBUG then   // Issue #23 -- every line written to the telnet window
     begin
     logger.Info('[Telnet WINDOW t=%d] %s', [Ord(c), p]);
     end;

  Handle := TelnetListBox;

  // Issue #23 -- copy into a bounded buffer first.  The owner-draw handler reads
  // each item back via LB_GETTEXT (which has no size limit) into a same-sized
  // stack buffer; capping here guarantees that read can never overrun the stack.
  // boundary: the telnet console listbox is ANSI (LB_ADDSTRING via SendMessageA).
  Windows.lstrcpynA(buf, PAnsiChar(AnsiString(p)), SizeOf(buf));

  SendMessage(Handle, LB_SETITEMDATA, SendMessageA(Handle, LB_ADDSTRING, 0,
    integer(@buf)), integer(c));

  if TelnetFreezeMode then
     begin
     Exit;
     end;
  SendMessage(Handle, WM_HSCROLL, SB_BOTTOM, 0);
  SendMessage(Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure SaveTelnetWindowSpots;
var

  i, Lines: integer;
  LineLength: longword;
  TimeString: PAnsiChar;
  TelnetLogHandle: HWND;
begin
  if not tWindowsExist(tw_TELNETWINDOW_INDEX) then
     begin
     Exit;
     end;
  Lines :=
    SendDlgItemMessage(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, 101,
    LB_GETCOUNT, 0, 0);
  if Lines < 10 then
     begin
     Exit;
     end;
  TimeString := GetTimeString;
  TimeString[2] := '-';
  // Issue #997: asm wsprintf -> Format
  StrPCopy(wsprintfBuffer, SysUtils.Format('%sDXCluster\dxcluster %s %s.txt',
    [string(PAnsiChar(@TR4W_PATH_NAME)), string(GetDateString), string(TimeString)]));

  TelnetLogHandle := CreateFileA(wsprintfBuffer, GENERIC_WRITE, FILE_SHARE_WRITE,
    nil, CREATE_NEW, FILE_ATTRIBUTE_ARCHIVE, 0);

  if TelnetLogHandle <> INVALID_HANDLE_VALUE then
     begin
     for i := 0 to Lines - 1 do
        begin
        LineLength :=
          SendDlgItemMessageA(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle,
          101, LB_GETTEXT, i, lParam(@wsprintfBuffer));
        wsprintfBuffer[LineLength + 0] := #13;
        wsprintfBuffer[LineLength + 1] := #10;
        sWriteFile(TelnetLogHandle, wsprintfBuffer, LineLength + 2);
        end;
     CloseHandle(TelnetLogHandle);
     end;

end;

procedure EnableTelnetToolbatButtons(b: boolean);

  procedure SetToolButSt(Control: Byte);
  var
    State: boolean;
  begin
    State := b;
    if Control = 200 then
       begin
       InvertBoolean(State);
       end;
    SendMessage(TelToolbar, TB_ENABLEBUTTON, integer(Control), integer(State));
  end;
begin

  SetToolButSt(200);
  SetToolButSt(201);
  SetToolButSt(202);
  //  SetToolButSt(205);
   // SetToolButSt(206);
  //  SetToolButSt(207);
  //  SetToolButSt(208);
end;

// Handle ONE complete cluster line: show it, and if it is a spot, decode it.
//
// Was ProcessTelnetString(ByteReceived), which scanned a shared receive buffer
// for line breaks itself.  It no longer has to -- the transport delivers whole
// lines (uDXClusterClient) -- and it no longer can get it wrong: that scan
// restarted per chunk with no carry-over, so a line split across two TCP
// segments was cut in half and both halves dropped.
//
// The `d > 120` force-break went with it.  It existed to stop a runaway
// terminator-less stream from swallowing the buffer; with the terminator now
// doing that job, its only remaining effect would be to chop a long comment
// into two console lines.
procedure ProcessTelnetLine(const Line: AnsiString);
var
  AddedSpot: boolean;
  StringType: TelnetStringType;

begin
  AddedSpot := False;
  StringType := tstReceived;

  // "DX de " -- the two PInteger compares this replaces were $64205844 ("DX d")
  // at the line start and $20656420 (" de ") two bytes in, which together spell
  // exactly these six characters.  Same test, minus the endian puzzle.
  if Copy(Line, 1, 6) = 'DX de ' then
     begin
     AddedSpot := ProcessDX(Line, False, StringType);
     end;

  // The wire->display edge: one decode, here, of one complete line.
  AddStringToTelnetConsole(string(Line), StringType);

  if AddedSpot then
  begin
    // `sleep(BMDelay)` stood here -- a sleep on the MAIN THREAD, inside a
    // message handler, once per accepted spot, stalling the message pump for
    // every window in the program.  Its comment said it was to avoid driving
    // the radio too fast, which is a concern for the AUTOSPOT tuning path
    // below, not for the message loop.  BMDelay was `= 0` with no CFG row and
    // no way to set it, so nothing changes today -- but a throttle for the
    // radio belongs on the radio call, not on the pump.
    //
    // The BandMapNeedsRefresh block that stood here is gone too: AddSpot bumps
    // SpotsList's repaint token itself, so the 250 ms timer picks the spot up
    // whether or not this path remembers to ask.  The band/mode test it was
    // guarded by only decided whether the spot was VISIBLE -- which is
    // Display's filter pass's job, and it re-runs anyway.

{$IFDEF AUTOSPOT}
    if Config.TwoRadioMode then
       begin
       if first then
          begin
          //TLogger.GetInstance.Debug(Format('Writing to Radio One: %s',[TempSpot.FFreqString]));
          TuneRadioToSpot(TempSpot, RadioOne); // ny4i test code to exercise radio
          first := false;
          end
       else
          begin
          first := true;
          //TLogger.GetInstance.Debug(Format('Writing to Radio Two: %s',[TempSpot.FFreqString]));
          TuneRadioToSpot(TempSpot, RadioTwo);
          end;
       end
    else
       begin
       //TLogger.GetInstance.Debug(Format('Writing to Radio One: %s',[TempSpot.FFreqString]));
       TuneRadioToSpot(TempSpot, RadioOne);
       end;

{$ENDIF}
  end;

end;

// Decode ONE complete cluster line and apply it to the running program.
//
// The DECODE half now lives in uDXSpotParse: it is a pure function of the line,
// so it links into the unit-test EXE and is pinned there (uTestDXSpotParse).
// What is left here is everything that needs the running program and therefore
// cannot -- the log (dupe and multiplier), the spot list, the alert list box,
// the display and the clock.  That mixture is exactly why the decoder had no
// test for as long as the two halves shared a function.
function ProcessDX(const Line: AnsiString; InListBox: boolean; var Stringtype:
  TelnetStringType): boolean;
var
  MinuteOfDay: integer;
  ct: Cardinal;
begin
  Result := False;
  Stringtype := tstReceived;

  if not ParseDXSpotLine(Line, TempSpot) then
     begin
     Exit;
     end;

  // The telnet window's list box wants the decoded fields only: no log lookup,
  // no band map, no alerting.  This was a `goto 1` past the whole apply half.
  if InListBox then
     begin
     Result := True;
     Exit;
     end;

  GetBandMapBandModeFromFrequency(TempSpot.FFrequency, TempSpot.FBand,
    TempSpot.FMode);

  //  if TempSpot.FBand = Band20 then    TempSpot.FQSXFrequency := TempSpot.FFrequency + 1000;

  TempSpot.FDupe :=
    //CallsignsList.CallsignIsDupe(TempSpot.FCall, TempSpot.FBand, TempSpot.FMode, I1);
  VisibleLog.CallIsADupe(TempSpot.FCall, TempSpot.FBand, TempSpot.FMode);

  if TempSpot.FDupe then
     begin
     Stringtype := tstReceivedDupe;
     end;

  if not TempSpot.FDupe then
     begin
     TempSpot.FMult := VisibleLog.DetermineIfNewMult(TempSpot.FCall,
       TempSpot.FBand, TempSpot.FMode);
     //    TempSpot.FMult := MultString <> 0;
     if TempSpot.FMult then
        begin
        Stringtype := tstReceivedMult;
        end;

     end;

  // The spot's own age.  `ct` is "now" in the same made-up unit the stamp is
  // converted into -- minutes, with the day and month folded in as fixed-size
  // blocks (30-day months).  It is only ever used as a difference against a
  // stamp from the same run, so the calendar being wrong does not matter; this
  // is unchanged.
  ct := UTC.wMinute + UTC.wHour * 60 + UTC.wDay * 60 * 24 + UTC.wMonth * 60 * 24
    * 30;
  if ParseDXSpotTimeUTC(Line, MinuteOfDay) then
     begin
     TempSpot.FSysTime := Cardinal(MinuteOfDay) +
       UTC.wDay * 60 * 24 + UTC.wMonth * 60 * 24 * 30;
     if ct >= TempSpot.FSysTime then
        begin
        TempSpot.FMinutesLeft := ct - TempSpot.FSysTime;
        end;
     end
  else
     begin
     TempSpot.FSysTime := ct;
     end;

  if TempSpot.FCall = MyCall then
     begin
     Stringtype := tstAlert;
     QuickDisplay(TC_YOUARESPOTTEDBYANOTHERSTATION);
     QuickBeep;
     end;
  if not TempSpot.FDupe then // 4.93.4
     begin
     SpotsList.AddSpot(TempSpot, True);
     end;

  if telnet_callsign_alert_list_loaded then
    if Windows.SendMessageA(TelnetCallsignAlertList, LB_FINDSTRINGEXACT, -1,
      integer(PAnsiChar(@TempSpot.FCall[1]))) <> LB_ERR then
       begin
       Stringtype := tstAlert;

       TF.Format(QuickDisplayBuffer,
         'New DX Cluster spot: %s was spoted by %s on %s', @TempSpot.FCall[1],
         @TempSpot.FSourceCall[1], TempSpot.FFreqString);
       QuickDisplay(QuickDisplayBuffer);

       Tree.QuickBeep;
       end;

  Result := True;
end;

procedure tCreateAndAddNewSpot(Call: CallString; Dupe: boolean; Radio:
  RadioPtr);
label
  1;
var
  TempFrequency: LONGINT;
  Mult: boolean;
begin
  if not BandMapEnable then
     begin
     Exit;
     end;
  if bandmappreventrefresh then
     begin
     exit;
     end;
  if StringIsAllNumbers(Call) then
     begin
     Exit;
     end;
  //  if ActiveRadio = RadioOne then TempFrequency := Radio1.FilteredStatus.Freq;
  //  if ActiveRadio = RadioTwo then TempFrequency := Radio2.FilteredStatus.Freq;
  TempFrequency := Radio^.FilteredStatus.Freq;
  if TempFrequency = 0 then
    //    if OpMode = SearchAndPounceOpMode then
    if AskForFrequencies then
       begin
       Call[length(Call) + 1] := #0;
       // Issue #997: asm wsprintf -> Format
       StrPCopy(wsprintfBuffer, SysUtils.Format(TC_FREQUENCYFORCALLINKHZ,
         [string(PAnsiChar(@Call[1]))]));
       TempFrequency := QuickEditFreq(wsprintfBuffer, 10);
       end;
  if TempFrequency <= 0 then
     begin
     Exit;
     end;

  Windows.ZeroMemory(@TempSpot, SizeOf(TempSpot));

  if PInteger(@Call[1])^ = tCQAsInteger then
     begin
     Mult := False;
     TempSpot.FCQ := True; //GAV changed from true to false
     goto 1;
     end;

  if PInteger(@Call[1])^ = tNEWAsInteger then
     begin
     Mult := False;
     goto 1;
     end;

  Mult := VisibleLog.DetermineIfNewMult(Call, ActiveBand, ActiveMode);
  //  Mult := MultString <> 0;

  1:
  TempSpot.FCall := Call;

  TempSpot.FFrequency := TempFrequency;

  if TempSpot.FCQ then
    //GAV      issue, picking activeband on dupecheck   changed from ActiveBand / mode to BandmapBand / mode  if not CQ
     begin
     TempSpot.FBand := ActiveBand;
     TempSpot.FMode := ActiveMode;
     end
  else
     begin
     TempSpot.FBand := BandmapBand;
     TempSpot.FMode := BandmapMode;
     end;

  TempSpot.FQSXFrequency := 0;
  TempSpot.FDupe := Dupe;
  TempSpot.FMult := Mult;
  TempSpot.FMinutesLeft := 0;
  TempSpot.FSourceCall := MyCall + '-' + ComputerID;
  TempSpot.FNotes[0] := #0;
  //  Windows.GetSystemTime(TempSpot.FSysTime);
  TempSpot.FSysTime := UTC.wMinute + UTC.wHour * 60 + UTC.wDay * 60 * 24 +
    UTC.wMonth * 60 * 24 * 30;
  SpotsList.AddSpot(TempSpot, True);

  DisplayBandMap;
end;

function TelnetIsConnected: boolean;
begin
  Result := (ClusterClient <> nil) and ClusterClient.IsConnected;
end;

// Stop retrying.  Called wherever the OPERATOR takes charge of the link --
// clicking Disconnect, or closing the window -- so an automatic reconnect can
// never undo a deliberate act.
procedure CancelTelnetRetry;
begin
  if TelnetRetryArmed then
     begin
     KillTimer(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle,
               TELNET_RETRY_TIMER);
     TelnetRetryArmed := False;
     end;
  TelnetRetryDelay := 0;
end;

// Schedule the next attempt, backing off.  Silent retrying is worse than none
// -- the operator would have no way to tell a reconnecting cluster from a dead
// one -- so every attempt is announced in the console.
procedure ArmTelnetRetry;
var
  wnd: HWND;
begin
  if not Config.tConnectionAtStartup then
     begin
     Exit;   // operator has opted out of TR4W dialling on its own
     end;

  if TelnetRetryDelay = 0 then
     begin
     TelnetRetryDelay := RETRY_DELAY_MIN;
     end
  else
     begin
     TelnetRetryDelay := TelnetRetryDelay * 2;
     if TelnetRetryDelay > RETRY_DELAY_MAX then
        begin
        TelnetRetryDelay := RETRY_DELAY_MAX;
        end;
     end;

  wnd := tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle;
  if wnd = 0 then
     begin
     Exit;   // window gone; nothing to reconnect into
     end;

  // TF.Format is wsprintf-style: positional arguments, not an open array.
  TF.Format(wsprintfBuffer, 'Reconnecting to %s:%u in %u seconds...',
         @PendingTelnetHost[0], PendingTelnetPort, TelnetRetryDelay div 1000);
  AddStringToTelnetConsole(wsprintfBuffer, tstTR4W);

  SetTimer(wnd, TELNET_RETRY_TIMER, TelnetRetryDelay, nil);
  TelnetRetryArmed := True;
end;

procedure SendClientStatus;
begin
  ClientStatus.csTelnet := ClusterClient.IsConnected;
  SendToNet(ClientStatus, SizeOf(ClientStatus));
end;

procedure AppendTelnetPopupMenu(MenuText: PAnsiChar);
var
  Flag: Cardinal;
  Offset: integer;
begin
  if ItemsInTelnetPopupMenu > MAXITEMSINTELNETPOPUPMENU - 1 then
     begin
     Exit;
     end;
  if MenuText[0] = #0 then
     begin
     Exit;
     end;

  Flag := MF_STRING;
  Offset := 0;

  if MenuText[0] = '-' then
     begin
     Flag := MF_SEPARATOR;
     end;

  if MenuText[0] = '.' then
     begin
     TelLastPopMemu := TelPopMemu;
     Exit;
     end;

  if MenuText[0] = '#' then
     begin
     Flag := MF_STRING + MF_DISABLED + MF_GRAYED;
     Offset := 1;
     end;

  if MenuText[0] = '!' then
     begin
     Flag := MF_STRING + MF_CHECKED;
     Offset := 1;
     end;

  if MenuText[0] = '>' then
     begin
     TelLastPopMemu := CreatePopupMenu;
     Windows.AppendMenuA(TelPopMemu, MF_STRING + MF_POPUP, TelLastPopMemu,
       @MenuText[1]);
     inc(ItemsInTelnetPopupMenu);
     Exit;
     end;

  if MenuText[0] = '=' then
     begin
     Flag := MF_STRING;
     Offset := 1;
     end;

  Windows.AppendMenuA(TelLastPopMemu, Flag, 1000 + ItemsInTelnetPopupMenu,
    @MenuText[Offset]);

  inc(ItemsInTelnetPopupMenu);
end;

procedure EmunTRCLUSTERDAT(FileString: PShortString);
begin
  tCB_ADDSTRING_PCHAR(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, 102,
    string(PAnsiChar(@FileString^[1])));
end;

procedure EmunDXCLUSTERALERTLISTTXT(FileString: PShortString);
begin
  if telnet_callsign_alert_list_loaded = False then
     begin
     TelnetCallsignAlertList := CreateWindowA('LISTBOX', nil, $50210003, 0, 0, 0, 0,
       tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, 0, hInstance, nil);
     end;

  tLB_ADDSTRING(TelnetCallsignAlertList, @FileString^[1]);
  telnet_callsign_alert_list_loaded := True;
end;

procedure EnumCLUSTERCOMMANDSTXT(FileString: PShortString);
begin
  if FileString^[1] = ';' then
     begin
     Exit;
     end;
  AppendTelnetPopupMenu(@FileString^[1]);
end;

initialization
  ClusterEvents := TClusterEvents.Create;
  ClusterClient := TDXClusterClient.Create;
  ClusterClient.OnLine         := ClusterEvents.Line;
  ClusterClient.OnPendingText  := ClusterEvents.PendingText;
  ClusterClient.OnConnected    := ClusterEvents.Connected;
  ClusterClient.OnDisconnected := ClusterEvents.Disconnected;

finalization
  // Destroy stops the reader and closes the socket; do it before the events
  // object goes, or a line arriving during teardown would call into freed code.
  ClusterClient.Free;
  ClusterEvents.Free;

end.


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
{$IMPORTEDDATA OFF}

interface

uses
  ClipBrd,
  uCTYDAT,
  uGradient,
  PostUnit,
  //  uTrayBalloon,
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
procedure CheckClusterType(ByteReceived: integer);
procedure AppendTelnetPopupMenu(MenuText: PAnsiChar);
procedure EmunTRCLUSTERDAT(FileString: PShortString);
procedure EmunDXCLUSTERALERTLISTTXT(FileString: PShortString);
procedure EnumCLUSTERCOMMANDSTXT(FileString: PShortString);

const
  MAXITEMSINTELNETPOPUPMENU = 70;
  TELNETBUTTONS = 6{$IF LANG = 'RUS'} + 1{$IFEND};

var
  ItemsInTelnetPopupMenu: integer;
  ClientStatus: TClientStatus = (csID: NET_CLIENTSTATUS_ID);
  // BandMapNeedsRefresh moved to LogWind so it is accessible from uRadioPolling without circular dependencies
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
{$IF LANG = 'RUS'}
    ,
    (iBitmap: - 1; //VIEW_SORTNAME;
    idCommand: 207;
    fsState: TBSTATE_ENABLED;
    fsStyle: TBSTYLE_BUTTON or TBSTYLE_AUTOSIZE;
    dwData: 0;
    iString: 6;
    )

{$IFEND}
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
  PendingTelnetHost: array[0..255] of AnsiChar;   // set on the main thread before the I/O thread starts
  PendingTelnetPort: Word;

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
      Result := MyCall
   else if Token = 'MY_STATE' then
      Result := MyState
   else if Token = 'MY_SECTION' then
      Result := MySection
   else if Token = 'MY_NAME' then
      Result := MyName
   else if Token = 'MY_GRID' then
      Result := MyGrid
   else if Token = 'MY_ZONE' then
      Result := MyZone
   else if Token = 'MY_CHECK' then
      Result := MyCheck
   else if Token = 'MY_PREC' then
      Result := MyPrec
   else if Token = 'MY_CLASS' then
      Result := MyFDClass
   else if Token = 'MY_PARK' then
      Result := MyPark
   else if Token = 'MY_POSTALCODE' then
      Result := MyPostalCode
   else if Token = 'CALL' then
      Result := CallWindowString
   else if Token = 'DATE' then
      Result := GetDateString
   else if Token = 'TIME' then
      Result := GetTimeString
   else if Token = 'BAND' then
      Result := BandStringsArrayWithOutSpaces[ActiveBand]
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
            GradientRect(TDIS^.HDC, TDIS^.rcItem, tr4wColorsArray[trYellow],
              tr4wColorsArray[trYellow], gdHorizontal);

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
              Format(wsprintfBuffer, '%s%s:%u', TC_CONNECTEDTO,
                @PendingTelnetHost[0], PendingTelnetPort);
              AddStringToTelnetConsole(wsprintfBuffer, tstTR4W);
              // (The TelnetBuffer clear that stood here is gone with the buffer
              // -- there is no shared receive state to reset between sessions.)
              if ConnectionCommand <> '' then
                 SendViaTelnetSocket(@ConnectionCommand[1])
              else
                 SetDlgItemTextA(hwnddlg, 106, @MyCall[1]);
              SendClientStatus;
              EnableTelnetToolbatButtons(True);
              EnableWindowTrue(hwnddlg, 104);
            end;

          TELNET_CONNECT_FAILED:
            begin
              // Issue #23 -- keep the detailed WinSock reason in the log for
              // diagnostics, but show the operator a short message naming the
              // host they tried to reach (the raw message is long and unwrapped).
              logger.Error('[Telnet] Could not connect to %s:%d -- WinSock %d: %s',
                [PAnsiChar(@PendingTelnetHost[0]), PendingTelnetPort, lParam,
                 SysUtils.SysErrorMessage(lParam)]);
              Format(wsprintfBuffer, '%s%s:%u', TC_FAILEDTOCONNECTTO,
                @PendingTelnetHost[0], PendingTelnetPort);
              AddStringToTelnetConsole(wsprintfBuffer, tstError);
              Disconnect;
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
                 ProcessTelnetLine(TelnetLine);
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
                 end;
            end;
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
          tCB_SETCURSEL(hwnddlg, 102, i);

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
          integer(PAnsiChar(TC_TELNET{$IF LANG = 'RUS'} + '?'#0#0{$IFEND})));
        EnableTelnetToolbatButtons(False);

        TelnetListBox := Get101Window(hwnddlg);
        // Issue #997: asm tWM_SETFONT -> call the existing TF helper directly
        tWM_SETFONT(TelnetListBox, LucidaConsoleFont);

        TelnetCommandWindow := GetDlgItem(hwnddlg, 106);

        //        TelnetListBoxOldProc := Pointer(Windows.SetWindowLong(TelnetListBox, GWL_WNDPROC, integer(@TelnetListBoxNewProc)));
                //        SendMessage(hwnddlg, WM_SETICON, ICON_SMALL, DisconnectedIcon);
        //            SendMessage(TelnetConnectionStatus, STM_SETICON, 0, 0);

        if tConnectionAtStartup then
          SendMessage(hwnddlg, WM_COMMAND, 200, 0);

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
          HideClusterCommandTooltip   // menu closed
        else
          ShowClusterCommandTooltip(LoWord(wParam), HiWord(wParam));
      end;

    WM_EXITMENULOOP:
      begin
        HideClusterCommandTooltip;
      end;

    WM_COMMAND:
      begin
        if HiWord(wParam) = LBN_SELCHANGE then
          DlgDirSelectExA(hwnddlg, wsprintfBuffer, SizeOf(wsprintfBuffer), 101);

        if HiWord(wParam) = LBN_DBLCLK then
        begin
          //      DlgDirSelectEx(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, wsprintfBuffer, SizeOf(wsprintfBuffer), 101);  //n4af
          //    DlgDirList(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, wsprintfBuffer, 101, 106, DDL_ARCHIVE or DDL_DIRECTORY);       //n4af
          //   ShowMessage(SysErrorMessage(GetLastError));
          i := SendMessage(TelnetListBox, LB_GETCURSEL, 0, 0);
          if i = LB_ERR then
            Exit;
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
              SetLength(ExpandedClusterCommand, 250);
            SendViaTelnetSocket(PAnsiChar(ExpandedClusterCommand));
          end;

        case wParam of
          201: Disconnect;

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

{$IF LANG = 'RUS'}
          207: ShowHelp('ru_dxcluster');
{$IFEND}

          //          DialogBox(hInstance, MAKEINTRESOURCE(44), hwnddlg, @SpotsFilterDlgProc);
          200: StartTelnetConnect;   // Issue #23 -- launch the DX cluster I/O thread

          104:
            begin
              SendMessage(TelnetCommandWindow, CB_SHOWDROPDOWN, 0, 0);
              Windows.GetWindowTextA(TelnetCommandWindow, TempBuffer1,
                SizeOf(TempBuffer1));
              if TempBuffer1[0] = #0 then
                Exit;
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
  Format(wsprintfBuffer, '%s%s:%u', TC_CONNECTINGTO, @PendingTelnetHost[0],
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
  if TR4W_TELNET_DEBUG then   // Issue #23 -- log every disconnect
     begin
     logger.Info('[Telnet] Disconnecting (connected=%s)',
                 [BoolToStr(ClusterClient.IsConnected, True)]);
     end;
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
     Format(wsprintfBuffer, '%s%s:%u', TC_DISCONNECTEDFROM, @PendingTelnetHost[0],
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
    Exit;
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
    Exit;
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
    Exit;
  Lines :=
    SendDlgItemMessage(tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, 101,
    LB_GETCOUNT, 0, 0);
  if Lines < 10 then
    Exit;
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
      InvertBoolean(State);
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
    sleep(BMDelay);
    // So we do not drive the serial port and radio too fast.    // 4.93.beta       // 4.102.5
    // Signal the 250ms refresh timer rather than repainting immediately.
    // The timer coalesces bursts of spots into a single repaint, eliminating
    // flashing. The spot data (FList) is always current; the display is at
    // most 250ms behind.
    if BandMapAllBands or (TempSpot.FBand = BandmapBand) then
      if BandMapAllModes or (TempSpot.FMode = BandmapMode) then
        BandMapNeedsRefresh := True;

{$IFDEF AUTOSPOT}
    if TwoRadioMode then
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

// Does `Token` appear at 0-based offset `Index`?
//
// This replaces the `PInteger(@Buf[i])^ = $20585351 {QSX }` idiom that ran
// through this decoder.  That trick compared four characters as one 32-bit
// integer -- a D7-era micro-optimisation that saved a few cycles on 1990s
// hardware and has cost every reader since, because the constant only spells
// "QSX " if you know the machine is little-endian and read the bytes backwards.
// It is also silently limited to exactly four characters and silently wrong on
// a big-endian target.  The compare below is the same test, written down.
function TokenAt(const Buf: array of AnsiChar; Index: integer;
                 const Token: AnsiString): boolean;
var
  k: integer;
begin
  Result := False;
  if (Index < 0) or (Index + Length(Token) > Length(Buf)) then
     begin
     Exit;
     end;
  for k := 1 to Length(Token) do
     begin
     if Buf[Index + k - 1] <> Token[k] then
        begin
        Exit;
        end;
     end;
  Result := True;
end;

// Decode ONE complete cluster line into TempSpot.
//
// Takes the LINE, not an offset into a shared receive buffer.  It used to read
// `TelnetBuffer[DX + n]` -- a global the socket wrote into -- which meant the
// decoder could only run where that global was live, i.e. never in a test.  The
// column arithmetic below is unchanged and deliberately so: those offsets are
// tuned against what real nodes actually emit.  All that changed is WHERE the
// bytes come from, so DX is now always 0 and the `DX + n` expressions keep
// reading exactly as they always did.
function ProcessDX(const Line: AnsiString; InListBox: boolean; var Stringtype:
  TelnetStringType): boolean;
label
  1;
var
  // The line, NUL-filled so any read past its end sees a terminator exactly as
  // it did in the old NUL-terminated receive buffer.  1024 is far beyond any
  // real cluster line (~80-120 chars).
  LineBuf: array[0..1023] of AnsiChar;
  DX: integer;        // always 0; kept so the offsets below read as before
  copyLen: integer;
  i, i1: integer;
  TempFrequency: integer;

  f: integer;
  QSXPos: integer;
  TempChar: AnsiChar;
  Hertz: integer;
  DivHertz: boolean;
  QSXBand: BandType;
  QSXMode: ModeType;
  UpKhz: integer;

  Offset: integer;
  ct: Cardinal;
begin
  // Copy the line into a NUL-filled local.  Zero-filling is what makes the
  // fixed offsets below safe on a SHORT line: a read past the end lands on #0,
  // exactly as it did when this walked a NUL-terminated receive buffer.
  Windows.ZeroMemory(@LineBuf, SizeOf(LineBuf));
  copyLen := Length(Line);
  if copyLen > SizeOf(LineBuf) - 1 then
     begin
     copyLen := SizeOf(LineBuf) - 1;
     end;
  if copyLen > 0 then
     begin
     Move(Line[1], LineBuf[0], copyLen);
     end;
  DX := 0;   // the line starts at the start; see the header

  Offset := 0;
  Result := False;
  Stringtype := tstReceived;
  Windows.ZeroMemory(@TempSpot, SizeOf(TSpotRecord));
  TempSpot.FBand := NoBand;
  TempSpot.FMode := NoMode;

  //  ShowMessage(@LineBuf[DX + 24]);
  if LineBuf[DX + 24] = '.' then
     begin
     Offset := 3; // 4.92.6
     end;
  if LineBuf[DX + 25] = '.' then
     begin
     Offset := 4;
     end;
  if LineBuf[DX + 26] = '.' then
     begin
     Offset := 5;
     end;
  if LineBuf[Dx + 23] = '.' then
     begin
     Offset := 1;
     end;
  {Source Callsign}
  for i := DX + 9 to DX + 20 do
  begin
    if ((LineBuf[i] = ' ') or (LineBuf[i] = ':')) then
    begin
      if LineBuf[i + 1] <> ' ' then // 4.92.6
         begin
         SetLength(TempSpot.FSourceCall, i - DX - 6);
         end;
      Windows.lstrcpynA(@TempSpot.FSourceCall[1], @LineBuf[DX + 6], i - DX -
        5);
      i1 := i;
      Break;
    end;
  end;

  for i := DX + 10 to DX + 20 do
  begin
    // if LineBuf[i] = ' ' then if LineBuf[i + 1] <> ' ' then
    // Two nested single-statement ifs collapsed into one condition -- no else
    // on either, so this is the same test, and it satisfies the begin/end rule
    // without adding a pointless nesting level.  4.92.6
    if ((LineBuf[i] = ' ') or (LineBuf[i] = ':')) and
       (LineBuf[i + 1] <> ' ') then
      begin
        Windows.lstrcpynA(@TempSpot.FFreqString[0], @LineBuf[i + 1], DX + 24
          - i + Offset);

        TempFrequency := 0;

        for f := 0 to 12 do
        begin
          if TempFrequency > 2100000 { $ 7FFFFFF} then
            Exit;

          if TempSpot.FFreqString[f] = '.' then
          begin
            //            try

            // 0010368100 - 009E3464
            // 1778165408 - 69FCA6A0
            // 2147483647   7FFFFFFF
            //            TempFrequency := 10368970*1000;
            TempFrequency :=
              (
              TempFrequency * 10 +
              (Ord(TempSpot.FFreqString[f + 1]) - 48)
              ) * 100;
            //            if TempFrequency < 10000000 then TempFrequency := TempFrequency * 100;
            //            except
            //              asm
            //            nop
            //              end;
            //          end;
            //103 681 190 00
            if (TempFrequency > 1300000000) or (TempFrequency < 0) then

              Exit;
            TempSpot.FFrequency := TempFrequency;
            Break;
          end;
          if TempSpot.FFreqString[f] = #0 then
            Break;
          if TempSpot.FFreqString[f] in ['0'..'9'] then
            TempFrequency := TempFrequency * 10 + (Ord(TempSpot.FFreqString[f])
              - 48);
        end;

      end;
  end;

  //1

  {DX}

//  DXCallStart := 25;
  if Offset = 4 then
    Offset := 3; // 4.92.7
  for i := DX + 27 to DX + 39 do
  begin
    // Nested single-statement ifs collapsed; same test, no else on either. 4.92.7
    if (LineBuf[i] <> ' ') and
       (LineBuf[i + 1] = ' ') then
      begin
        SetLength(TempSpot.FCall, i - (DX + 25 + Offset));
        Windows.lstrcpynA(@TempSpot.FCall[1], @LineBuf[DX + 26 + Offset], i
          - (DX + 24 + Offset));
        if not GoodCallSyntax(TempSpot.FCall) then
          Exit;
        Break;
      end;
  end;

  {Note}
  if LineBuf[DX + 39 + Offset] <> '                              ' then
    // This is not right as the extensions can be at the end so check if th ewhole comment (30 bytes) is blank // ny4i
  begin
    Windows.lstrcpynA(@TempSpot.FNotes[0], @LineBuf[DX + 39 + Offset], 31);
    //was 31 but allow for null ny4i
    StrUpper(PAnsiChar(@LineBuf[DX + 39 + Offset]));
    for i := DX + 39 to DX + 65 do
    begin
      //        i1:=
     // i1 := PInteger(@LineBuf[i])^;

      if TokenAt(LineBuf, i, 'QSX ') then
      begin
        if LineBuf[i + 4] in ['0'..'9'] then
        begin

          Hertz := 1000;
          DivHertz := False;

          for QSXPos := 4 to 12 do
          begin
            TempChar := LineBuf[i + QSXPos];
            case TempChar of
              ' ': Break;
              '0'..'9':
                begin
                  TempSpot.FQSXFrequency := TempSpot.FQSXFrequency * 10 +
                    (Ord(TempChar) - 48);
                  if DivHertz then
                    Hertz := Hertz div 10;
                end;
              '.': DivHertz := True;
            end;
          end;

          TempSpot.FQSXFrequency := TempSpot.FQSXFrequency * Hertz;
          if TempSpot.FQSXFrequency < 10000 then
            TempSpot.FQSXFrequency := TempSpot.FFrequency +
              TempSpot.FQSXFrequency;
          QSXBand := NoBand;
          CalculateBandMode(TempSpot.FQSXFrequency, QSXBand, QSXMode);
          if QSXBand = NoBand then
            TempSpot.FQSXFrequency := 0;
        end;

      end;

      // "UP n" -- QSX n kHz up.  ONE test covering every spelling the format
      // has: UP1, UP 5, UP10, UP 10.  Read "UP", allow one optional space, then
      // take the digits and do the arithmetic.
      //
      // This replaces TWO blocks that between them still missed cases: five
      // hard-coded tokens UP1..UP5, and a separate space-form block.  So "UP7"
      // and "UP10" (no space) were silently ignored -- the QSX was dropped and
      // the operator worked the wrong frequency.  Reading the number instead of
      // enumerating spellings is why this now handles all of them.
      //
      // Left word boundary is required so PUP / CUP / SOUP in a comment cannot
      // fake a QSX -- and guarded on i > 0, because the old space-form block
      // read LineBuf[i - 1] with no such guard and would step off the front of
      // the buffer when the match sat at offset 0.
      if (i > 0) and (LineBuf[i - 1] = ' ') and
         (LineBuf[i] = 'U') and (LineBuf[i + 1] = 'P') then
         begin
         QSXPos := i + 2;
         if LineBuf[QSXPos] = ' ' then      // the optional space: "UP 10"
            begin
            Inc(QSXPos);
            end;
         UpKhz := 0;
         // Terminates on the NUL that fills the tail of LineBuf, so a match at
         // the very end of the line cannot run past it.
         while (QSXPos <= High(LineBuf)) and (LineBuf[QSXPos] in ['0'..'9']) do
            begin
            UpKhz := UpKhz * 10 + (Ord(LineBuf[QSXPos]) - Ord('0'));
            Inc(QSXPos);
            end;
         if UpKhz > 0 then
            begin
            TempSpot.FQSXFrequency := TempSpot.FFrequency + UpKhz * 1000;
            end;
         end;
    end;
  end;

  if InListBox then
    goto 1;
  //1

  GetBandMapBandModeFromFrequency(TempSpot.FFrequency, TempSpot.FBand,
    TempSpot.FMode);

  //  if TempSpot.FBand = Band20 then    TempSpot.FQSXFrequency := TempSpot.FFrequency + 1000;

  TempSpot.FDupe :=
    //CallsignsList.CallsignIsDupe(TempSpot.FCall, TempSpot.FBand, TempSpot.FMode, I1);
  VisibleLog.CallIsADupe(TempSpot.FCall, TempSpot.FBand, TempSpot.FMode);

  if TempSpot.FDupe then
    Stringtype := tstReceivedDupe;

  if not TempSpot.FDupe then
  begin
    TempSpot.FMult := VisibleLog.DetermineIfNewMult(TempSpot.FCall,
      TempSpot.FBand, TempSpot.FMode);
    //    TempSpot.FMult := MultString <> 0;
    if TempSpot.FMult then
      Stringtype := tstReceivedMult;

  end;

  //  Windows.GetSystemTime(TempSpot.FSysTime);
  ct := UTC.wMinute + UTC.wHour * 60 + UTC.wDay * 60 * 24 + UTC.wMonth * 60 * 24
    * 30;
  if (LineBuf[DX + 74] = 'Z') then
  begin
    TempSpot.FSysTime := ((Ord(LineBuf[DX + 70]) - $30) * 10 +
      Ord(LineBuf[DX + 71]) - $30) * 60 +
      ((Ord(LineBuf[DX + 72]) - $30) * 10 + Ord(LineBuf[DX + 73]) -
      $30) + UTC.wDay * 60 * 24 + UTC.wMonth * 60 * 24 * 30;
    if ct >= TempSpot.FSysTime then
      TempSpot.FMinutesLeft := ct - TempSpot.FSysTime;

  end
  else
    TempSpot.FSysTime := ct;

  //  TempSpot.FSysTime.wHour := (Ord(LineBuf[DX + 70]) - $30) * 10 + Ord(LineBuf[DX + 71]) - $30;
  //  TempSpot.FSysTime.wMinute := (Ord(LineBuf[DX + 72]) - $30) * 10 + Ord(LineBuf[DX + 73]) - $30;
  if TempSpot.FCall = MyCall then
  begin
    Stringtype := tstAlert;
    QuickDisplay(TC_YOUARESPOTTEDBYANOTHERSTATION);
    QuickBeep;
  end;
  if not TempSpot.FDupe then // 4.93.4
    SpotsList.AddSpot(TempSpot, True);

  if telnet_callsign_alert_list_loaded then
    if Windows.SendMessageA(TelnetCallsignAlertList, LB_FINDSTRINGEXACT, -1,
      integer(PAnsiChar(@TempSpot.FCall[1]))) <> LB_ERR then
    begin
      Stringtype := tstAlert;

      Format(QuickDisplayBuffer,
        'New DX Cluster spot: %s was spoted by %s on %s', @TempSpot.FCall[1],
        @TempSpot.FSourceCall[1], TempSpot.FFreqString);
      QuickDisplay(QuickDisplayBuffer);

      Tree.QuickBeep;
    end;

  1:
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
    Exit;
  if bandmappreventrefresh then
    exit;
  if StringIsAllNumbers(Call) then
    Exit;
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
    Exit;

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

procedure CheckClusterType(ByteReceived: integer);

begin

end;

function TelnetIsConnected: boolean;
begin
  Result := (ClusterClient <> nil) and ClusterClient.IsConnected;
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
    Exit;
  if MenuText[0] = #0 then
    Exit;

  Flag := MF_STRING;
  Offset := 0;

  if MenuText[0] = '-' then
    Flag := MF_SEPARATOR;

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
    TelnetCallsignAlertList := CreateWindowA('LISTBOX', nil, $50210003, 0, 0, 0, 0,
      tr4w_WindowsArray[tw_TELNETWINDOW_INDEX].WndHandle, 0, hInstance, nil);

  tLB_ADDSTRING(TelnetCallsignAlertList, @FileString^[1]);
  telnet_callsign_alert_list_loaded := True;
end;

procedure EnumCLUSTERCOMMANDSTXT(FileString: PShortString);
begin
  if FileString^[1] = ';' then
    Exit;
  AppendTelnetPopupMenu(@FileString^[1]);
end;

initialization
  ClusterEvents := TClusterEvents.Create;
  ClusterClient := TDXClusterClient.Create;
  ClusterClient.OnLine         := ClusterEvents.Line;
  ClusterClient.OnConnected    := ClusterEvents.Connected;
  ClusterClient.OnDisconnected := ClusterEvents.Disconnected;

finalization
  // Destroy stops the reader and closes the socket; do it before the events
  // object goes, or a line arriving during teardown would call into freed code.
  ClusterClient.Free;
  ClusterEvents.Free;

end.


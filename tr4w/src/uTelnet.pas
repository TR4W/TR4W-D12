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
  Menus,           // TMenuItem -- the commands popup is an LCL menu now
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
  uSpotAge,   // UTCNow
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
  ,
  uTR4WStrings,
  uAnsiStr;

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
{ Rebuild the cluster drop-down after the library has been edited, KEEPING the
  operator's current choice. Called by Preferences when it saves. }
procedure TelnetRefreshClusterList;
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
  { The submenu currently being filled, nil at the top level.  Replaces the
    TelLastPopMemu HMENU: the item that owns a submenu and the submenu itself
    are ONE object now, so they cannot disagree. }
  TelLastMenuParent: TMenuItem;

  telnet_callsign_alert_list_loaded: boolean;
  TelnetCallsignAlertList: HWND;
implementation
uses uNet,
  Forms,             // Application.QueueAsyncCall -- the event transport
  ExtCtrls,          // TTimer -- the retry and login timers, off the dialog's WM_TIMER
  uTelnetForm,       // the window itself, a designed form since 2026-08-25
  uRadioConfigStore,   // the cluster library -- what the drop-down now lists
  uKeyerConfigStore,   // LoadConfig fills both libraries from the one file
  uUDPBroadcastConfig, // TUDPBroadcastConfig -- LoadConfig fills it too
  uRadioConfigApply,   // RadioStoreFileName
  uTR4WConfigFile,     // LoadConfig
  uPrefsForm,          // ShowPreferencesAtPage / NAV_CLUSTER -- the Configure button
  SyncObjs,          // the queue lock, shared with the cluster reader thread
  uClusterTokens,    // the braced-token parser, a leaf so it can be tested
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

// Issue #23 -- DX cluster I/O thread -> main-thread event protocol.  The
// cluster thread does ALL blocking network I/O (connect + recv) and never
// touches UI or shared spot/bandmap state; it hands each piece of news to the
// main thread, which does that work there.
//
// IT USED TO BE A WINDOW MESSAGE.  WM_TELNET_MSG was PostMessage'd to the
// telnet window's HWND, which made that window part of the TRANSPORT -- the
// same shape that stopped uNet's network window becoming a form until the
// socket moved to Indy.  Nothing about "a line arrived from the cluster"
// needs a window, and a handle of 0 (the window closed, or not yet created)
// silently DROPPED the news and LEAKED the heap block carrying it.
//
// Application.QueueAsyncCall instead, for the reason uPanelUpdate and uNet
// both document: TThread.Queue purges by the calling thread's id when that
// thread dies, and a cluster reader dies exactly when a disconnect needs
// reporting.
//
// ONE ORDERED QUEUE FOR ALL FIVE KINDS, not a queue for data and direct calls
// for lifecycle.  A window message queue is FIFO, and the handler relied on
// that: CLOSED must not overtake the DATA lines that preceded it, or the last
// thing the node said before hanging up is lost -- which on a login failure is
// the only line that explains why.

const
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
  TClusterEventKind = (
    cekConnected,       // Code unused
    cekConnectFailed,   // Code = WSA error code (0 = none reported)
    cekData,            // Text = one complete line, terminator already stripped
    cekPending,         // Text = an UNTERMINATED line, in practice a login prompt
    cekClosed);         // Code = WSA error code (0 = graceful close)

  // THE TEXT IS AN AnsiString, not the 8 KB fixed buffer this used to carry.
  // New/Dispose managed that buffer by hand and the HANDLER owned the free, so
  // any path that did not reach the handler leaked it -- a window handle of 0
  // being exactly such a path.  It also capped a line at 8192 characters for no
  // reason the cluster protocol requires.
  TClusterEvent = record
    Kind: TClusterEventKind;
    Code: Integer;
    Text: AnsiString;
  end;

  // Cluster events arrive on the client's READER THREAD.  Every one of these
  // does nothing but append to the queue and ask the main thread to drain it:
  // the handlers touch the bandmap, the log and the UI, none of which is
  // thread-safe.
  //
  // A class because the event methods are `of object` and QueueAsyncCall needs
  // a method; it holds no state of its own.  The queue is a unit global under a
  // lock, so a drain already scheduled still finds work queued after it.
  TClusterEvents = class
    procedure Line(const L: AnsiString);
    procedure PendingText(const L: AnsiString);
    procedure Connected;
    procedure Disconnected(const Text: string; Code: Integer);
    procedure Drain(Data: PtrInt);
  end;

var
  // Declared HERE, above the window procedure, because Pascal needs the
  // declaration before the first use and the toolbar arms ask IsConnected
  // long before the event methods are implemented.
  ClusterClient: TDXClusterClient;
  ClusterEvents: TClusterEvents;

  // THE QUEUE, and the lock that is the ONLY thing shared with the reader
  // thread.  SyncObjs-QUALIFIED for the reason uNet records: a long uses
  // clause can put a RECORD named TCriticalSection in scope, and FPC then
  // reads `= nil` as a record initialiser and asks for a '('.
  GClusterLock: SyncObjs.TCriticalSection = nil;
  GClusterQueue: array of TClusterEvent;
  // Reentrancy guard.  A handler can call Disconnect, which blocks; nothing
  // in that path pumps messages today, but a nested drain would hand the
  // same event to two handlers, and that is not a failure anyone would
  // diagnose from a log.
  GClusterDraining: boolean = False;
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

// The login sequence, forward-declared for the same reason: the cluster-event
// handler runs it and it needs SendViaTelnetSocket, which is declared later.
procedure ArmClusterLogin; forward;
procedure CancelClusterLogin; forward;
procedure SendClusterLogin; forward;
{ aComplete distinguishes a whole line from an unterminated prompt.  It exists
  for the LINE BUDGET only -- both kinds are still offered to the prompt tests,
  because a login or password prompt characteristically arrives WITHOUT a
  terminator and the pending path is the only way it is ever seen. }
procedure AnswerClusterLoginPrompts(const Line: AnsiString;
                                    const aComplete: boolean); forward;

var
  // Armed on connect, disarmed when the callsign goes out. See ArmClusterLogin.
  ClusterLoginArmed: boolean;
  // ---- the login sequence --------------------------------------------------
  // Main thread only: everything here runs from HandleClusterEvent.
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

// THE TOKEN VOCABULARY -- the half that needs the application's state.
//
// The parser itself now lives in uClusterTokens, which links without the
// socket, the spot model or this dialog procedure and is therefore under unit
// test.  What stays here is the part that could never move: knowing that
// MY_CALL means the MyCall global.
//
// Result is False for an unrecognised token so the parser can leave it
// verbatim.  This is the single source of truth for the token vocabulary.
function TelnetClusterTokenValue(const Token: string; out Value: string): boolean;
var
   RealFreq: Real;
   FreqStr: ShortString;
begin
   Result := True;
   Value := '';

   if Token = 'MY_CALL' then
      begin
      Value := string(MyCall)
      end
   else if Token = 'MY_STATE' then
      begin
      Value := string(MyState)
      end
   else if Token = 'MY_SECTION' then
      begin
      Value := string(MySection)
      end
   else if Token = 'MY_NAME' then
      begin
      Value := string(MyName)
      end
   else if Token = 'MY_GRID' then
      begin
      Value := string(MyGrid)
      end
   else if Token = 'MY_ZONE' then
      begin
      Value := string(MyZone)
      end
   else if Token = 'MY_CHECK' then
      begin
      Value := string(MyCheck)
      end
   else if Token = 'MY_PREC' then
      begin
      Value := string(MyPrec)
      end
   else if Token = 'MY_CLASS' then
      begin
      Value := string(MyFDClass)
      end
   else if Token = 'MY_PARK' then
      begin
      Value := string(MyPark)
      end
   else if Token = 'MY_POSTALCODE' then
      begin
      Value := string(MyPostalCode)
      end
   else if Token = 'CALL' then
      begin
      Value := string(CallWindowString)
      end
   else if Token = 'DATE' then
      begin
      Value := string(GetDateString)
      end
   else if Token = 'TIME' then
      begin
      Value := string(GetTimeString)
      end
   else if Token = 'BAND' then
      begin
      Value := string(BandStringsArrayWithOutSpaces[ActiveBand])
      end
   else if Token = 'FREQ' then
      begin
      RealFreq := Radio1.FilteredStatus.Freq / 1000.0;   { Hz -> kHz }
      Str(RealFreq: 0: 1, FreqStr);
      Value := string(FreqStr);
      end
   else
      begin
      Result := False;
      end;
end;

// The expansion, keeping the boundary between literal text and substituted
// values so a caller can SHOW the operator which parts came from a token.
function TelnetClusterSegments(const Src: string): TClusterSegments;
begin
   Result := ExpandClusterSegments(Src, TelnetClusterTokenValue);
end;

// The finished command text, for callers that do not need the boundaries.
function ExpandClusterTokens(Src: PAnsiChar): AnsiString;
begin
   Result := AnsiString(SegmentsToText(TelnetClusterSegments(string(AnsiString(Src)))));
end;

{ ---------------------------------------------------------------------------
  WHAT THE DIALOG PROCEDURE USED TO DO.

  TelnetWndDlgProc is GONE and so is the tracking tooltip it drove.  Everything
  below is the same work, reached the same way, with the WM_ dispatch replaced
  by the form calling back.  The button ids are deliberately unchanged so the
  arms can be read against the originals.

  THE PREVIEW TOOLTIP IS NOT REPLACED HERE.  It was a TTF_TRACK tooltip driven
  from WM_MENUSELECT, and it existed to show a command's expanded value on
  hover.  A Win32 tooltip is plain text, so it could never show WHICH part was
  substituted -- which is what NY4I asked for.  uClusterTokens already returns
  that as segments, and a TPopupMenu can draw them; that is the next step, not
  a reimplementation of the tooltip.
  --------------------------------------------------------------------------- }

{ THE TWO TIMERS.  Both were SetTimer against the dialog's HWND with the tick
  handled in its WM_TIMER arm, so both had to convert with it.

  TTimer, not uWinTimer: these are the form's behaviour and the LCL owns its own
  hidden timer window, so neither depends on the telnet window having a handle.
  The window GUARD is kept regardless -- see ArmTelnetRetry, which still refuses
  to arm when the window is gone, because that is the behaviour that shipped and
  changing it is a separate decision. }
var
  TelnetRetryTimer: TTimer = nil;
  ClusterLoginTimer: TTimer = nil;

type
  TTelnetTimers = class
    procedure RetryTick(Sender: TObject);
    procedure LoginTick(Sender: TObject);
  end;

var
  TelnetTimers: TTelnetTimers = nil;

procedure TTelnetTimers.RetryTick(Sender: TObject);
begin
  // One-shot: stop it first, then try.  If the attempt fails, cekConnectFailed
  // arms the next one with a longer delay, so the loop continues without this
  // handler knowing how many have gone by.
  TelnetRetryTimer.Enabled := False;
  TelnetRetryArmed := False;
  AddStringToTelnetConsole('Reconnecting...', tstTR4W);
  StartTelnetConnect;
end;

procedure TTelnetTimers.LoginTick(Sender: TObject);
begin
  // No `login:` arrived in time.  Send the callsign anyway: the node may prompt
  // in prose we deliberately do not match, or not prompt at all.
  ClusterLoginTimer.Enabled := False;
  if ClusterLoginArmed then
     begin
     logger.Info('[Telnet] No login prompt within %d ms -- sending the callsign anyway',
                 [LOGIN_PROMPT_WAIT]);
     end;
  SendClusterLogin;
end;

{ Fill the drop-down from the operator's cluster library, and put up the
  prompt when there is nothing in it.

  ENTRY FORMAT IS 'host:port  Name' -- host FIRST, then whitespace, then a
  label. That is not cosmetic: TelnetConnect parses the combo text by taking
  everything up to the first space as host:port (see the note there, and the
  control-id bug it records). Preferences shows the same cluster the other way
  round, 'Name - host:port', because nothing parses that. }
procedure AddDefinedClustersToHostList;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr, line: string;
   i, defined: integer;
begin
   defined := 0;
   if FileExists(RadioStoreFileName) then
      begin
      store  := TRadioConfigStore.Create;
      keyers := TKeyerConfigStore.Create;
      udp    := TUDPBroadcastConfig.Create;
      try
         if LoadConfig(RadioStoreFileName, store, keyers, loadErr, udp) then
            begin
            for i := 0 to store.ClusterCount - 1 do
               begin
               if Trim(store.Cluster(i).Server) = '' then
                  begin
                  Continue;      // a half-entered definition is not a choice
                  end;
               line := Trim(store.Cluster(i).Server);
               if Trim(store.Cluster(i).Name) <> '' then
                  begin
                  line := line + '  ' + Trim(store.Cluster(i).Name);
                  end;
               TelnetAddHostItem(line);
               Inc(defined);
               end;
            end
         else
            begin
            logger.Warn('[Telnet] cluster library could not be read: %s', [loadErr]);
            end;
      finally
         udp.Free;
         keyers.Free;
         store.Free;
      end;
      end;

   { THE SERVER ACTUALLY IN USE IS ALWAYS OFFERED, even when it is not in the
     library. An operator upgrading from a version without one has TELNET SERVER
     in their ini and a cluster that works; taking it out of the list because it
     has no definition yet would be a regression dressed as tidiness. It does
     NOT count towards `defined` -- it is not a library entry, and if it is the
     only thing here the prompt still belongs on screen. }
   if Trim(string(TelnetServer)) <> '' then
      begin
      TelnetAddHostItem(Trim(string(TelnetServer)));
      end;

   TelnetSetNoClustersHint(defined = 0);
end;

{ Rebuild the drop-down after the cluster library has been edited, KEEPING THE
  OPERATOR'S CURRENT CHOICE.

  Called from Preferences when it saves. The selection is read before the
  rebuild and put back after, so editing an unrelated cluster -- or adding one
  -- does not silently repoint the window at a different server. If the entry
  they had selected is gone, the text is still restored rather than snapped to
  row 0: they may be connected to it right now, and a combo that disagrees with
  the live connection is worse than one showing something not in the list.

  DOES NOTHING IF THE WINDOW HAS NEVER BEEN OPENED -- there is no list to
  rebuild, and TelnetFormShowHandler will build it correctly when it is. }
procedure TelnetRefreshClusterList;
var
   chosen: string;
begin
   { NO 'does the window exist' TEST HERE. Every accessor below guards itself --
     TelnetHostText returns '' and the list calls no-op when there is no form --
     so a second check would only be a second place to get it wrong. }
   chosen := TelnetHostText;

   TelnetBeginHostList;
   AddDefinedClustersToHostList;
   TelnetEndHostList;

   if Trim(chosen) <> '' then
      begin
      TelnetSelectHostItem(chosen);
      end;
end;

{ WM_INITDIALOG.  A dialog was rebuilt every time it opened; a form is created
  once and reshown, so this runs on every show and must be idempotent -- which
  is why the menu and the host list are CLEARED first.  The Win32 version could
  not get this wrong because its controls did not survive a close. }
procedure TelnetFormShowHandler;
var
  i: integer;
begin
  telnet_callsign_alert_list_loaded := False;
  ItemsInTelnetPopupMenu := 0;
  TelLastMenuParent := nil;

  EnumerateLinesInFile('DXCLUSTER_ALERT_LIST.TXT',
    EmunDXCLUSTERALERTLISTTXT, True);

  // THE DROP-DOWN LISTS THE OPERATOR'S OWN CLUSTERS, NOT A CATALOGUE.
  //
  // It used to be the 726 lines of TRCLUSTER.DAT, which is every public node
  // that existed when the file was compiled.  Now that clusters are DEFINED --
  // name, server, login, password, post-connect command -- offering a list of
  // 726 servers TR4W knows nothing about invites the operator to pick one that
  // has no credentials attached and will not log them in.
  //
  // NO FALLBACK TO THE FILE WHEN NOTHING IS DEFINED, and that is deliberate.
  // NY4I, 2026-08-30: "the fallback would be confusing for a first time user.
  // They will never look for the settings dialog."  A first run therefore shows
  // one greyed line telling them to define a cluster, which is a signpost; 726
  // hostnames are not.
  //
  // BATCHED.  Adding hosts one at a time blocked the main thread for 1.7 s on
  // every open -- and start-up opens this window before the message loop runs,
  // so that was 1.7 s of unpainted main window.  See TelnetBeginHostList.
  TelnetBeginHostList;
  AddDefinedClustersToHostList;
  TelnetEndHostList;

  TelnetSelectHostItem(string(TelnetServer));

  TelnetMenuClear;
  AppendTelnetPopupMenu('HELP');
  AppendTelnetPopupMenu('SHOW/USERS');
  AppendTelnetPopupMenu('SHOW/WWV');
  AppendTelnetPopupMenu('SHOW/FILTER');
  EnumerateLinesInFile('CLUSTER_COMMANDS.TXT', EnumCLUSTERCOMMANDSTXT, True);

  TelnetSetConnected(TelnetIsConnected);
  TelnetSetFreezePressed(TelnetFreezeMode);

  // CONNECT ON OPEN, and only when nothing is connected yet -- reshowing the
  // window must not dial a second time.
  if Config.tConnectionAtStartup and (not TelnetIsConnected) and
     (TelThreadID = 0) then
     begin
     StartTelnetConnect;
     end;

  i := 0;   // silences the unused-variable note when the block above compiles out
  if i <> 0 then
     begin
     Exit;
     end;
end;

{ The toolbar.  Same ids the Win32 WM_COMMAND carried. }
procedure TelnetFormCommandHandler(const aId: integer);
begin
  case aId of
    TELNET_CMD_CONNECT:
      begin
      StartTelnetConnect;   // Issue #23 -- launch the DX cluster I/O thread
      end;

    // Operator clicked Disconnect: cancel FIRST, so a retry armed by an earlier
    // drop cannot fire and drag the link back up against their wishes.  This is
    // the one place that must beat the timer.
    TELNET_CMD_DISCONNECT:
      begin
      CancelTelnetRetry;
      Disconnect;
      end;

    TELNET_CMD_COMMANDS:
      begin
      TelnetShowCommandMenu;
      end;

    TELNET_CMD_FREEZE:
      begin
      InvertBoolean(TelnetFreezeMode);
      TelnetSetFreezePressed(TelnetFreezeMode);
      if not TelnetFreezeMode then
         begin
         TelnetConsoleScrollToEnd;   // catch up with what arrived while frozen
         end;
      end;

    TELNET_CMD_CLEAR:
      begin
      TelnetConsoleClear;
      end;

    TELNET_CMD_SHOW50:
      begin
      SendViaTelnetSocket('SH/DX 50');   //n4af 04-11-2014
      end;

    { Straight to the page that defines clusters. Answered HERE rather than in
      the form so the cluster window keeps no dependency on the settings tree. }
    TELNET_CMD_CONFIGURE:
      begin
      if not ShowPreferencesAtPage(NAV_CLUSTER) then
         begin
         logger.Warn('[Telnet] Preferences has no DX Cluster page to open');
         end;
      end;
  end;
end;

{ The Send button, and Enter in the command box. }
procedure TelnetFormSendHandler;
var
  Text: string;
begin
  Text := Trim(TelnetCommandText);
  if Text = '' then
     begin
     Exit;
     end;

  SendViaTelnetSocket(PAnsiChar(WinAnsi(Text)));
  TelnetRememberCommand(Text);
  TelnetSetCommandText('');
end;

{ A cluster command chosen from the popup. }
procedure TelnetFormMenuHandler(const aId: integer);
var
  Expanded: AnsiString;
  Item: string;
begin
  Item := TelnetMenuCaption(aId);
  if Item = '' then
     begin
     Exit;
     end;

  // Issue #973: expand braced tokens to live values before sending.  Capped at
  // 250 so SendViaTelnetSocket's CRLF append cannot overflow its 256-byte
  // buffer when expansion GROWS the string.
  Expanded := AnsiString(SegmentsToText(TelnetClusterSegments(Item)));
  if Length(Expanded) > 250 then
     begin
     SetLength(Expanded, 250);
     end;
  SendViaTelnetSocket(PAnsiChar(Expanded));
end;

{ A console line was double-clicked: if it is a spot, tune to it.  Re-decoded
  from the line itself, exactly as the LBN_DBLCLK arm did. }
procedure TelnetFormConsoleDblClickHandler(const aIndex: integer);
var
  StringType: TelnetStringType;
begin
  TelnetLine := AnsiString(TelnetConsoleLine(aIndex));
  if Copy(TelnetLine, 1, 6) = 'DX de ' then
     begin
     if ProcessDX(TelnetLine, True, StringType) then
        begin
        TuneRadioToSpot(TempSpot, RadioOne);
        end;
     end;
end;

// ON THE MAIN THREAD.  One event, handled exactly as the WM_TELNET_MSG arms
// handled it -- this is a move, not a rewrite.  What changed is how it got
// here, and that the text arrived with it instead of on the heap.
procedure HandleClusterEvent(const aEvent: TClusterEvent);
begin
  case aEvent.Kind of
    cekConnected:
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
        TF.Format(wsprintfBuffer, '%s%s:%u', PAnsiChar(WinAnsi(TC_CONNECTEDTO)),
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
        // The send box is ungreyed by TelnetSetConnected above -- one call for
        // one fact.  This used to be a separate EnableWindow against control
        // 104, which is how the toolbar and the send box got out of step.
      end;

    cekConnectFailed:
      begin
        // Issue #23 -- keep the detailed WinSock reason in the log for
        // diagnostics, but show the operator a short message naming the
        // host they tried to reach (the raw message is long and unwrapped).
        // CODE 0 MEANS NO SOCKET ERROR, so SysErrorMessage(0) renders as
        // "The operation completed successfully" -- a failure line that
        // says nothing failed, which is exactly how the already-connected
        // refusal disguised itself.  The real reason came through
        // OnDisconnected; do not overwrite it with a lie.
        if aEvent.Code = 0 then
           begin
           logger.Error('[Telnet] Could not connect to %s:%d -- no socket error reported ' +
                        '(see the preceding reason)',
             [PAnsiChar(@PendingTelnetHost[0]), PendingTelnetPort]);
           end
        else
           begin
           logger.Error('[Telnet] Could not connect to %s:%d -- WinSock %d: %s',
             [PAnsiChar(@PendingTelnetHost[0]), PendingTelnetPort, aEvent.Code,
              SysUtils.SysErrorMessage(aEvent.Code)]);
           end;

        // TEARDOWN BEFORE COSMETICS.  Disconnect used to sit after the
        // console formatting, and the whole log shows it NEVER RAN across
        // three failures -- leaving the session up and wedging every
        // later attempt.  Whatever aborted the handler did so before this
        // line; putting the state change first means a formatting problem
        // can no longer cost the teardown.
        Disconnect;

        TF.Format(wsprintfBuffer, '%s%s:%u', PAnsiChar(WinAnsi(TC_FAILEDTOCONNECTTO)),
          @PendingTelnetHost[0], PendingTelnetPort);
        AddStringToTelnetConsole(wsprintfBuffer, tstError);
        // Keep trying, with a longer gap each time.  A failed RETRY comes
        // back through here, which is what makes the backoff advance --
        // and a first connect that fails is retried too, so a TR4W
        // started before the network is up still ends up connected.
        ArmTelnetRetry;
      end;

    cekData:
      begin
        // Exactly ONE complete line, terminator already stripped by the
        // transport.  No shared receive buffer, no NUL bookkeeping, no
        // re-scanning for line breaks -- and no heap block to dispose of:
        // the text travelled on the event and dies with it.
        TelnetLine := aEvent.Text;
        // BEFORE the spot decoder, and unconditionally: a login prompt
        // is not a spot, and the answer must go out before anything
        // else this line might trigger.  Costs one Pos() per line and
        // only while the window is open -- it returns immediately once
        // the password has gone or the budget has run out.
        AnswerClusterLoginPrompts(TelnetLine, True);
        ProcessTelnetLine(TelnetLine);
      end;

    // AN UNTERMINATED PROMPT. Answered, but NOT decoded and NOT displayed:
    // it is an incomplete line by definition, and the complete one arrives
    // later through TELNET_DATA. Feeding it to ProcessDX would decode the
    // same text twice.
    cekPending:
      begin
        TelnetLine := aEvent.Text;
        AnswerClusterLoginPrompts(TelnetLine, False);
      end;

    cekClosed:
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
           if aEvent.Code <> 0 then
              begin
              TelnetConnectionError(aEvent.Code);
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

// ON THE MAIN THREAD, from the LCL's async queue.  Takes ONE event at a time
// and releases the lock before handling it: a handler calls Disconnect, which
// joins the reader thread, and holding the lock across that would deadlock
// against a reader trying to report its own exit.
procedure TClusterEvents.Drain(Data: PtrInt);
var
  ev: TClusterEvent;
  n: integer;
begin
  if GClusterDraining then
     begin
     Exit;
     end;

  GClusterDraining := True;
  try
    while True do
       begin
       GClusterLock.Acquire;
       try
         n := Length(GClusterQueue);
         if n = 0 then
            begin
            Exit;
            end;
         ev := GClusterQueue[0];
         Move(GClusterQueue[1], GClusterQueue[0], (n - 1) * SizeOf(TClusterEvent));
         // The moved-from slot still holds a counted reference to the string
         // that is now ALSO in the first slot.  Blank it without finalising,
         // or SetLength frees a string the caller is about to read.
         FillChar(GClusterQueue[n - 1], SizeOf(TClusterEvent), 0);
         SetLength(GClusterQueue, n - 1);
       finally
         GClusterLock.Release;
       end;

       HandleClusterEvent(ev);
       end;
  finally
    GClusterDraining := False;
  end;
end;

// ON THE READER THREAD (and, for the connect failure, on the connect thread).
// Appends one event and asks the main thread to drain.  Everything the handler
// needs travels IN the event; nothing here reads UI or contest state.
procedure QueueClusterEvent(aKind: TClusterEventKind; aCode: Integer;
                            const aText: AnsiString);
var
  n: integer;
begin
  GClusterLock.Acquire;
  try
    n := Length(GClusterQueue);
    SetLength(GClusterQueue, n + 1);
    GClusterQueue[n].Kind := aKind;
    GClusterQueue[n].Code := aCode;
    GClusterQueue[n].Text := aText;
  finally
    GClusterLock.Release;
  end;

  // Queue first, THEN schedule.  A drain already running picks up what we just
  // added; one that is not gets scheduled here.  The reverse order can leave an
  // event sitting with no drain pending.
  if (Application = nil) or Application.Terminated then
     begin
     Exit;
     end;
  Application.QueueAsyncCall(ClusterEvents.Drain, 0);
end;

procedure TClusterEvents.Line(const L: AnsiString);
begin
  if TR4W_TELNET_DEBUG then
     begin
     logger.Info('[Telnet RX %d] %s', [Length(L), string(L)]);
     end;
  QueueClusterEvent(cekData, 0, L);
end;

// Same marshalling as Line, and for the same reason -- this fires on the reader
// thread and the handler answers prompts and touches UI state.
procedure TClusterEvents.PendingText(const L: AnsiString);
begin
  if TR4W_TELNET_DEBUG then
     begin
     logger.Info('[Telnet RX pending %d] %s', [Length(L), string(L)]);
     end;
  QueueClusterEvent(cekPending, 0, L);
end;

procedure TClusterEvents.Connected;
begin
  QueueClusterEvent(cekConnected, 0, '');
end;

procedure TClusterEvents.Disconnected(const Text: string; Code: Integer);
begin
  // Connect failure and mid-session close are the same message to the user; the
  // handler distinguishes them, as before, by which KIND it receives.
  QueueClusterEvent(cekClosed, Code, '');
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
     // Reason already reported through OnDisconnected; say the ATTEMPT failed
     // so the console prints "failed to connect" rather than "closed".
     QueueClusterEvent(cekConnectFailed, 0, '');
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
  i: integer;
  Host: string;
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

  PendingTelnetPort := 23;

  { HOST[:PORT] FOLLOWED BY AN OPTIONAL DESCRIPTION, which is the TRCLUSTER.DAT
    line format -- "dxc.example.com:7300  Some Node".

    Was GetDlgItemTextA(hwnd, 102, ...) plus a backwards scan for ':' and ' '.
    THE CONTROL ID IS WHAT MADE THIS DANGEROUS: 102 stopped existing when the
    window became a form, and nothing failed to compile -- it simply read an
    empty string and TR4W dialled ":23" forever, retrying on the backoff with a
    perfectly healthy-looking log.  A number is not a name and the compiler
    cannot check it. }
  Host := TelnetHostText;

  i := Pos(' ', Host);
  if i > 0 then
     begin
     Host := Copy(Host, 1, i - 1);
     end;

  i := Pos(':', Host);
  if i > 0 then
     begin
     PendingTelnetPort := StrToIntDef(Copy(Host, i + 1, MaxInt), 23);
     Host := Copy(Host, 1, i - 1);
     end;

  if Host = '' then
     begin
     { REPORTED, not dialled.  The empty-host case used to be indistinguishable
       from a node being down. }
     AddStringToTelnetConsole('No cluster host selected -- choose one from the list.', tstError);
     logger.Error('[Telnet] Connect requested with no host selected');
     Exit;
     end;

  Windows.lstrcpynA(PendingTelnetHost, PAnsiChar(WinAnsi(Host)),
                    SizeOf(PendingTelnetHost));

  // Issue #23 -- immediate visual feedback so connect is not a black box:
  // show the attempt in the window and switch the toolbar to the connected
  // state (grays Connect, enables Disconnect) the instant the user clicks.
  TF.Format(wsprintfBuffer, '%s%s:%u', PAnsiChar(WinAnsi(TC_CONNECTINGTO)), @PendingTelnetHost[0],
    PendingTelnetPort);
  AddStringToTelnetConsole(wsprintfBuffer, tstTR4W);
  EnableTelnetToolbatButtons(True);

  // Issue #23 -- start each session live: a Freeze left on from a previous
  // connection would silently suppress auto-scroll on reconnect, looking like
  // the cluster is dead.  Clear the mode and un-press the Freeze toolbar button.
  TelnetFreezeMode := False;
  OldTelnetFreezeMode := False;
  TelnetSetFreezePressed(False);

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
     TF.Format(wsprintfBuffer, '%s%s:%u', PAnsiChar(WinAnsi(TC_DISCONNECTEDFROM)), @PendingTelnetHost[0],
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

  { One call, one fact -- see the note in the connected handler.  The two
    EnableWindow calls against control ids 104 and 102 that stood here are part
    of TelnetSetConnected now. }
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
       AddStringToTelnetConsole(PAnsiChar(WinAnsi(E.Message)), tstError);
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
         AddStringToTelnetConsole(PAnsiChar(WinAnsi(E.Message)), tstError);
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
      ClusterLoginTimer.Enabled := False;
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

   ClusterLoginTimer.Interval := LOGIN_PROMPT_WAIT;
   ClusterLoginTimer.Enabled := True;
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
   ClusterLoginTimer.Enabled := False;

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

   SendViaTelnetSocket(PAnsiChar(WinAnsi(call)));

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
procedure AnswerClusterLoginPrompts(const Line: AnsiString;
                                    const aComplete: boolean);
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

   { COMPLETE LINES ONLY, AND THE NAME IS THE SPECIFICATION.

     This is a budget of LINES -- it says so, and so does the message below.
     It was decremented once per CALL, and this routine is called from BOTH
     the cekData and cekPending arms, so a line split across a TCP segment
     was charged TWICE: once when the transport surfaced the fragment as a
     possible prompt, once when the terminator arrived.

     Measured on a live NC7J session, 2026-08-29: 63 receive events carried 46
     complete "DX de" lines, so about a quarter were split.  That turns a
     60-line budget into roughly 47 and gets worse the busier the node is --
     and a skimmer node blasting spots during login is precisely when the
     budget is under pressure.

     The failure is quiet and looks like something else: the budget expires,
     the stored password is never sent, and the operator sees a node that
     rejects them.  The log line then states a number of lines that were never
     counted, so the evidence contradicts itself.

     Charging only the complete line makes the count mean what it says. }
   if not aComplete then
      begin
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
begin
  if TR4W_TELNET_DEBUG then   // Issue #23 -- every line written to the telnet window
     begin
     logger.Info('[Telnet WINDOW t=%d] %s', [Ord(c), p]);
     end;

  // The 1023-character cap that stood here is GONE with the reason for it.  It
  // existed because the owner-draw handler read each item back through
  // LB_GETTEXT into a fixed stack buffer, so an over-long item was a stack
  // overrun; the view holds strings now and draws them without copying.
  TelnetConsoleAdd(p, c);

  if TelnetFreezeMode then
     begin
     Exit;
     end;
  TelnetConsoleScrollToEnd;
end;

{ THE SESSION LOG.  Written on the way out, and only when there is enough to be
  worth keeping.

  Reads the console through the view rather than through LB_GETTEXT into
  wsprintfBuffer, which is why the 256-byte truncation is gone: a long spot
  comment used to be cut off in the saved file and nowhere else, so the file
  disagreed with what the operator had been looking at. }
procedure SaveTelnetWindowSpots;
var
  i, Lines: integer;
  TimeString: PAnsiChar;
  TelnetLogHandle: HWND;
  Line: AnsiString;
begin
  if not tWindowsExist(tw_TELNETWINDOW_INDEX) then
     begin
     Exit;
     end;

  Lines := TelnetConsoleCount;
  if Lines < 10 then
     begin
     Exit;
     end;

  TimeString := GetTimeString;
  TimeString[2] := '-';
  StrPCopy(wsprintfBuffer, SysUtils.Format('%sDXCluster\dxcluster %s %s.txt',
    [string(PAnsiChar(@TR4W_PATH_NAME)), string(GetDateString), string(TimeString)]));

  TelnetLogHandle := CreateFileA(wsprintfBuffer, GENERIC_WRITE, FILE_SHARE_WRITE,
    nil, CREATE_NEW, FILE_ATTRIBUTE_ARCHIVE, 0);

  if TelnetLogHandle <> INVALID_HANDLE_VALUE then
     begin
     for i := 0 to Lines - 1 do
        begin
        Line := AnsiString(TelnetConsoleLine(i)) + #13#10;
        sWriteFile(TelnetLogHandle, Line[1], Length(Line));
        end;
     CloseHandle(TelnetLogHandle);
     end;
end;

{ "b" MEANS CONNECTED.  Kept as a one-liner over the view's own routine rather
  than deleted, because six call sites pass it and the name says what those
  sites mean.  The Win32 body reached into the toolbar with TB_ENABLEBUTTON per
  button and INVERTED the sense for Connect by hand; the view owns that now,
  along with the send box the old code enabled somewhere else entirely -- which
  is how the two got out of step when a teardown path missed one. }
procedure EnableTelnetToolbatButtons(b: boolean);
begin
  TelnetSetConnected(b);
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
  ct: TDateTime;   { now, UTC -- see the stamping block below }
  { Held across the SendMessageA below -- see the note there. }
  alertCall: AnsiString;
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

  // WHEN IT ARRIVED, NOT WHEN THE SPOTTER SAYS IT WAS MADE.
  //
  // The cluster line carries HHMM and nothing finer, so stamping from it put
  // EVERY spot of a given clock minute on the same timestamp -- and they then
  // all expired on the same tick, which is the chunking NY4I was still seeing
  // after the TDateTime change (2026-08-25).  Moving to a TDateTime fixed the
  // arithmetic and left this, because ParseDXSpotTimeUTC simply has no seconds
  // to give:
  //
  //     EncodeTime(MinuteOfDay div 60, MinuteOfDay mod 60, 0, 0)
  //                                                        ^ always
  //
  // UTCNow has milliseconds, so two spots a second apart now differ by a second
  // and fall off a second apart.
  //
  // WHAT THIS GIVES UP, said plainly: a spot RELAYED late -- made ten minutes
  // ago and only reaching us now -- is treated as new and lives a full decay
  // time from arrival.  That is the trade NY4I asked for, and it is the right
  // way round: the map is a picture of what is workable now, and a stale spot
  // arriving late is still news to this station.  ParseDXSpotTimeUTC keeps its
  // other callers; it is only the AGE that stops using it.
  TempSpot.FSysTime := UTCNow;
  TempSpot.FAgeSeconds := SpotAgeSeconds(TempSpot);

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

  { A REAL Win32 BOUNDARY -- LB_FINDSTRINGEXACT wants a null-terminated
    PAnsiChar -- BUT THE SOURCE WAS A SHORTSTRING, which has no terminator.  The
    search therefore ran past the callsign into whatever followed FCall in the
    spot record, and matched or missed accordingly.

    An AnsiString HELD IN A LOCAL across the call is the supported way to reach
    that boundary: it is terminated, and the local keeps it alive -- PAnsiChar of
    a temporary would dangle under FPC, which this tree has already been bitten
    by (see the radio-name note in uCallsigns.DisplayDupeSheet). }
  if telnet_callsign_alert_list_loaded then
    begin
    alertCall := AnsiString(TempSpot.FCall);
    if Windows.SendMessageA(TelnetCallsignAlertList, LB_FINDSTRINGEXACT, -1,
      LPARAM(PAnsiChar(alertCall))) <> LB_ERR then
       begin
       Stringtype := tstAlert;

       TF.Format(QuickDisplayBuffer,
         'New DX Cluster spot: %s was spoted by %s on %s', @TempSpot.FCall[1],
         @TempSpot.FSourceCall[1], TempSpot.FFreqString);
       QuickDisplay(QuickDisplayBuffer);

       Tree.QuickBeep;
       end;
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
  // A SECOND COPY OF DEFECT 3.1, and it drops data for the same reason: this
  // returned when the band map had focus, so a CQ marker for the frequency the
  // operator was sitting on was never created at all.  BandMapPreventRefresh is
  // gone with the Win32 window -- freezing the VIEW is the form's business and
  // it does not involve refusing to record anything.
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
         [string(Call)]));
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
  TempSpot.FAgeSeconds := 0;
  TempSpot.FSourceCall := MyCall + '-' + ComputerID;
  TempSpot.FNotes[0] := #0;
  // OUR OWN spot: made now, by definition.
  TempSpot.FSysTime := UTCNow;
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
     TelnetRetryTimer.Enabled := False;
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

  TelnetRetryTimer.Interval := TelnetRetryDelay;
  TelnetRetryTimer.Enabled := True;
  TelnetRetryArmed := True;
end;

procedure SendClientStatus;
begin
  ClientStatus.csTelnet := ClusterClient.IsConnected;
  SendToNet(ClientStatus, SizeOf(ClientStatus));
end;

{ ONE LINE OF CLUSTER_COMMANDS.TXT -> ONE MENU ITEM.

  The prefix characters are the file format and are unchanged:
     -  a separator
     .  return to the top level
     >  start a submenu, titled by the rest of the line
     #  present but greyed
     !  present and ticked
     =  a plain item (an explicit escape, so a command may start with a prefix
        character)

  WHAT CHANGED IS THE PARENT.  The Win32 version tracked TelLastPopMemu, a bare
  HMENU, and appended to whichever menu it happened to be pointing at; here it
  is a TMenuItem and nil means top level.  Same shape, but the item that owns
  the submenu and the submenu itself are now ONE object rather than two that
  could disagree. }
procedure AppendTelnetPopupMenu(MenuText: PAnsiChar);
var
  Text: string;
  Enabled: boolean;
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

  Text := string(AnsiString(MenuText));
  Enabled := True;
  Offset := 1;

  if Text[1] = '-' then
     begin
     TelnetMenuAddItem(TelLastMenuParent, '-', -1, True);
     Inc(ItemsInTelnetPopupMenu);
     Exit;
     end;

  if Text[1] = '.' then
     begin
     TelLastMenuParent := nil;
     Exit;
     end;

  if Text[1] = '>' then
     begin
     TelLastMenuParent := TelnetMenuAddItem(nil, Copy(Text, 2, MaxInt), -1, True);
     Inc(ItemsInTelnetPopupMenu);
     Exit;
     end;

  if Text[1] = '#' then
     begin
     Enabled := False;
     Offset := 2;
     end
  else if (Text[1] = '!') or (Text[1] = '=') then
     begin
     Offset := 2;
     end;

  TelnetMenuAddItem(TelLastMenuParent, Copy(Text, Offset, MaxInt),
                    1000 + ItemsInTelnetPopupMenu, Enabled);
  Inc(ItemsInTelnetPopupMenu);
end;

procedure EmunTRCLUSTERDAT(FileString: PShortString);
begin
  TelnetAddHostItem(string(FileString^));
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
  GClusterLock := SyncObjs.TCriticalSection.Create;
  ClusterEvents := TClusterEvents.Create;

  { THE TIMERS, off the dialog's WM_TIMER.  Created disabled; nothing starts
    until a session is attempted, so the headless export path never runs one. }
  TelnetTimers := TTelnetTimers.Create;
  TelnetRetryTimer := TTimer.Create(nil);
  TelnetRetryTimer.Enabled := False;
  TelnetRetryTimer.OnTimer := TelnetTimers.RetryTick;
  ClusterLoginTimer := TTimer.Create(nil);
  ClusterLoginTimer.Enabled := False;
  ClusterLoginTimer.OnTimer := TelnetTimers.LoginTick;

  { THE VIEW'S CALLBACKS.  Assigned rather than called directly because
    uTelnetForm's interface uses THIS unit for TelnetStringType -- see its
    header.  This is the only place the two are tied together. }
  TelnetFormOnShow            := @TelnetFormShowHandler;
  TelnetFormOnCommand         := @TelnetFormCommandHandler;
  TelnetFormOnSend            := @TelnetFormSendHandler;
  TelnetFormOnMenu            := @TelnetFormMenuHandler;
  TelnetFormOnConsoleDblClick := @TelnetFormConsoleDblClickHandler;
  ClusterClient := TDXClusterClient.Create;
  ClusterClient.OnLine         := ClusterEvents.Line;
  ClusterClient.OnPendingText  := ClusterEvents.PendingText;
  ClusterClient.OnConnected    := ClusterEvents.Connected;
  ClusterClient.OnDisconnected := ClusterEvents.Disconnected;

finalization
  // Destroy stops the reader and closes the socket; do it before the events
  // object goes, or a line arriving during teardown would call into freed code.
  ClusterClient.Free;
  // AND BEFORE THE OBJECT IS FREED, drop any drain still queued against it --
  // the reader can have queued one on its way out, and an async call into a
  // freed method is a crash with no useful stack.
  if Application <> nil then
     begin
     Application.RemoveAsyncCalls(ClusterEvents);
     end;
  ClusterEvents.Free;
  GClusterQueue := nil;
  FreeAndNil(GClusterLock);
  FreeAndNil(TelnetRetryTimer);
  FreeAndNil(ClusterLoginTimer);
  FreeAndNil(TelnetTimers);

end.


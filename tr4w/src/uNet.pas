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
unit uNet;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}

interface

uses
  SysUtils,
  Classes,       { TBytes }
  SyncObjs,      { the reader/main-thread handover }
  Forms,         { Application.QueueAsyncCall -- the transport }
  IdGlobal,      { TIdBytes }
  uNetClient,    { the multi-op link, over Indy }

  VC,
  TF,
  uNetFraming,   { NetMessageSize -- one table, no per-arm advances }
  uNetHello,     { THelloMessage, TNetPeers -- the first message on a link }
  uNetLink,      { TNetLinkState -- what the link is doing, and who is told }
  uNetResend,    { TNetDelivery -- what became of each QSO packet }
  uNetCatchUp,   { TPushPlan -- the QSOs the server lacks, RestockServer }
  uServerQsoIndex, { the pairs the resend posted on this link }
  utils_file,
  uTotal,
  uSpots,
  uIntercom,
  CfgCmd,
  //Country9,
  LogSCP,
  LogPack,
  LogK1EA,
  LogEdit,
  LogRadio,
  LogStuff,
  LogDupe,
  LogWind,
  PostUnit,
  uGradient,
  (* WINDOWS, GATED, FOR ONE CALL.

    SetSystemTime SETS THE MACHINE CLOCK from a peer's time-sync packet. Not
                  a missing API -- Unix has settimeofday -- but it needs ROOT,
                  and a contest logger asking for root so another station can
                  move the clock is a POLICY question. NY4I's. The call is
                  gated with an {$ELSE} that reports the packet was ignored,
                  so a station that declines simply keeps its own time.

    THE IMPORT WAS LEFT UNGATED WHEN THE CALL WAS GATED, EARLIER TODAY, and
    the cross compiler is what found it -- `uses Windows` fails on Linux
    whether or not anything inside the unit still needs it. Gating a call
    without gating the import it exists for is a half-measure that looks
    finished in a `Windows.` scan.

    tNet_Event WAS the other user and is a SyncObjs.TEvent now; see its
    declaration for why it was separable and the three CW/DVP events are not.
    WinSock2 and Messages went with the move to Indy's TNetClient
    (2026-08-25) -- the WSAAsyncSelect window message went with them. *)
{$IFDEF WINDOWS}
  Windows,
{$ENDIF}
  Tree

  ,
  uTR4WStrings,
  utils_text;

type
  TNetWindowColumnsInfo = record
    Width: integer;
    Text: string;
    fmt: integer;
  end;

const
{$IF OZCR2008}
  NetColumns                            = 12;
{$ELSE}
  NetColumns                            = 10;
{$IFEND}

var
  { A var, and the four translatable titles are BLANK until
    InitializeNetworkColumnTitles fills them.

    They used to be PAnsiChar initialised from RC_/TC_ constants, which is a
    compile-time fold and therefore untranslatable however good the catalogue
    is. Filling them cannot happen in this unit's initialization either: unit
    initialization runs BEFORE the translation is loaded, so it would capture
    English just as surely. uProgramMain calls it at the right moment. }
  NetColumnsArray                       : array[0..NetColumns - 1] of TNetWindowColumnsInfo =
    (
    (Width: 62; Text: ''; fmt: LVCFMT_CENTER),
    (Width: 25; Text: 'Id'; fmt: LVCFMT_CENTER),
    (Width: 60; Text: ''; fmt: LVCFMT_CENTER),
//    (Width: 47; Text: 'Mode'; fmt: LVCFMT_CENTER),
    (Width: 60; Text: ''; fmt: LVCFMT_CENTER),
    (Width: 30; Text: 'St.'; fmt: LVCFMT_CENTER),
    (Width: 37; Text: 'PTT'; fmt: LVCFMT_CENTER),
    (Width: 40; Text: 'Qs'; fmt: LVCFMT_CENTER),
    (Width: 70; Text: ''; fmt: LVCFMT_LEFT),
    (Width: 25; Text: 'D'; fmt: LVCFMT_CENTER),
    (Width: 70; Text: 'Op'; fmt: LVCFMT_LEFT)
//,    (Width: 50; Text: 'LN'; fmt: LVCFMT_LEFT)
{$IF OZCR2008}
    ,
    (Width: 85; Text: 'Length'; fmt: LVCFMT_LEFT),
    (Width: 150; Text: 'CW Message'; fmt: LVCFMT_CENTER)
{$IFEND}
    );

{ Fill the translatable station-list column titles. Call AFTER the translation
  is loaded and BEFORE the network window is built. }
procedure InitializeNetworkColumnTitles;
procedure SetComputerName;
procedure ShowServerMessage(ServMess: TServerMessage);
{ ONE CELL of the station list -- see the implementation.  Exported because
  DisplayMessageStatus writes two of the OZCR2008 columns. }
procedure SetClientCell(const aRow, aCol: integer; const aText: string);
function FindAndUpdateQSOInLog(var RXData: ContestExchange): boolean;
//procedure SendEditedQSOToNetwork(var CE: ContestExchange);
procedure ShowConnectionStatus(Operation: string);
procedure AddNewClient(ClientID: integer);
function ConnectThread(aParameter: Pointer): DWORD; stdcall;
procedure DisplayClientStatus(Index: integer);
procedure DisplayMessageStatus(Index: integer; Msg: TMessageState);
procedure NetDisconnect;
procedure ProcessServerLogInfo(s: PLogFileInformation);
procedure SetStatusByte;
procedure SendStationStatus(ssType: StationStatusType);
procedure SendMessageStatus;
procedure TryConnectToNetwork;
(* aTag is a QSO packet's identity (uNetResend.NetQsoTag), handed back when the
  packet's write finishes. 0 for everything else. *)
function SendToNet(var buf; Len: integer; aTag: Int64 = 0): integer;

(* TELL THE OTHER POSITIONS A SETTING CHANGED.

  RESTORED 2026-09-10.  IT WAS LOST IN THE LCL CONVERSION, silently, and this
  is a port regression rather than a feature that never existed -- checked
  against the D7 tree at C:\TR4W before saying so:

      JCTRL2.PAS:1817  procedure SendParameterToNetwork(Line: MenuEntryType)
      uOption.pas:919  the Options dialog, reading the value back out of its
                       Win32 list view with ListView_GetItemText
      uNet.pas:217     ParameterToNetwork.pnID := NET_PARAMETER_ID, set while
                       the network WINDOW was being created

  All three went with the windows that held them.  What survived is the
  RECEIVE side, which still applies an inbound change -- so this build has
  been obeying its peers while telling them nothing.

  THE CONSEQUENCE IS SILENT AND REMOTE, which is why it lasted: an operator
  changes a setting at one position, sees it take effect, and the second
  position quietly keeps running the old value.  Nobody finds out until two
  operators disagree mid-contest.

  pnID IS SET HERE, not once at startup as D7 did it.  The D7 assignment lived
  in the network window's WM_INITDIALOG, so a build without that window never
  set it -- and a message with the wrong id is discarded by the server without
  a word.  Setting it at the point of sending cannot be skipped by a window
  that did not open. *)
procedure SendParameterToNetwork(const aCommand, aValue: string);

(* THE FOUR RECORDS WHOSE ID WAS LOST (2026-10-27).

  Each procedure owns one record and sets its id word on EVERY send, as
  SendParameterToNetwork does, so an id cannot be forgotten by a caller or lost
  with a window. A caller never holds the record. All four do nothing when the
  link is down. The packets are posted like any other (SendToNet), so the guard
  there still judges them.

    SendDXSpotToNet            a spot, to the other positions (uSpots)
    SendTimeSyncToNet          this station's UTC, for the others to set their clocks
    SendIntercomToNet          one line of text to the other positions
    SendSpotViaNetworkToNet    "send this spot text to your cluster" -- the
                               spot form's path when no cluster is connected here *)
procedure SendDXSpotToNet(const aSpot: TSpotRecord);
procedure SendTimeSyncToNet;
procedure SendIntercomToNet(const aText: string);
procedure SendSpotViaNetworkToNet(const aSpotText: string);

(* How many distinct refused (id, length) pairs SendToNet has reported on this
  link. A test reads it; nothing else does. *)
function NetSendRefusalsReported: integer;

{ IS THE MULTI-OP LINK UP?  Replaces `NetSocket <> 0`, which three other units
  were reading directly. }
function NetIsConnected: boolean;

(* THE LINK BELONGS TO THE PROGRAM, NOT TO THE NETWORK WINDOW (2026-10-27).

  NY4I: "I never liked the idea that we only connected when the Network window
  was up." Until today TryConnectToNetwork had two callers, both in
  uNetworkForm, and closing that window dropped the link. Now:

    WHO WANTS A LINK    GLinkWanted, the operator's wish for this session. It is
                        set by NetLinkConnect / NetLinkReconnect (the Net menu)
                        and at startup by NetLinkStartup (Network.AutoConnect),
                        and cleared by NetLinkDisconnect.
    WHO RETRIES         the atNetReconnect timer, on the main thread, runs only
                        while a link is wanted. It is NetLinkTick. Opening,
                        closing or hiding the Network window starts and stops
                        nothing.
    WHO IS TOLD         uNetLink.NetLinkObservers. The window subscribes in its
                        constructor and unsubscribes in its destructor; this unit
                        never names it for notification. NetLinkChanged may be
                        called from any thread: it hops to the main thread.
    THE REFUSAL LATCH   (a server refused for its protocol, or an id refused) is
                        re-armed by NetLinkConnect and NetLinkReconnect, which
                        used to be done by opening the window. *)

(* What the link is doing now, from live facts. Main thread. *)
function NetLinkState: TNetLinkState;

(* Does the operator want a link this session? *)
function NetLinkWanted: boolean;

(* A refusal is standing: the operator has been told and nothing is retried. *)
function NetLinkRefused: boolean;

procedure NetLinkConnect;
procedure NetLinkDisconnect;
procedure NetLinkReconnect;

(* LEAVE THE NETWORK AT EXIT. Stops the retry timer and closes a live link, so
  the server sees a clean departure and the other stations clear this one's row
  at once instead of when the socket times out. Packets already posted get the
  client's bounded drain (a QSO logged a moment ago still goes). A connect that
  is still being built is left alone - the client is that thread's until it
  returns, and the process is ending. Main thread, from ExitProgram. *)
procedure NetLinkShutdown;

(* The one place startup decides: connects when Network.AutoConnect says so and
  this station has a legal computer id (uNetLink.ShouldConnectAtStartup). Always
  brings the Net menu into line with the state. Call once, after the menu is
  built. *)
procedure NetLinkStartup;

(* The retry timer's tick. Public so a test can drive it. *)
procedure NetLinkTick;

(* The state changed (or a status line did): tell the Net menu and everyone on
  NetLinkObservers. Any thread; the work runs on the main thread. *)
procedure NetLinkChanged;

(* The link is down for good reasons of its own (dropped, refused): close it,
  forget the other stations, say so in the status panel. Main thread. *)
procedure NetLinkWentDown;

(* Enable the Net menu's rows from the link's state: Connect, Disconnect and
  Reconnect by their own rules, the rows that send to other stations only on a
  live link. The top-level Net menu itself is always available. *)
procedure ApplyNetworkMenuState;

(* The same, for a state the caller names: what ApplyNetworkMenuState does with
  the live one, and how a test shows every state on the real menu. *)
procedure ApplyNetworkMenuStateFor(const aState: TNetLinkState);

(* The Network window's title, from the last status line the link reported.
  Safe to call from any thread. *)
function NetWindowCaption: string;

(* Write every station the link knows into the Network window's list. This is
  what a window opened MID-SESSION needs: it was not there to see the status
  messages go by, so it asks for the state instead of waiting for the next
  message. A no-op while there is no window. *)
procedure DisplayAllClients;

(* EVERY CONTEST TRAVELS THIS LINK -- network protocol 2, 2026-10-27 (NY4I: "ALL
  contests must work on the network, including those registered by id").

  The V1 packet named a contest with one byte that only a legacy contest has;
  Q108 S4 therefore guarded six doors against a contest registered by its id,
  whose byte is assigned when the registry seals and differs between builds.
  THE BYTE IS NO LONGER READ. Stations agree on the contest by its ID STRING,
  announced in the HELLO message (uNetHello) right after the password and again
  whenever the operator changes contest; a received QSO is judged by what its
  SENDER announced, and an accepted record is stamped with THIS station's own
  contest handle before it is logged. So every guard is gone, and with them
  ContestCanUseMultiOp, MultiOpRefusalText and SContestNotOnMultiOp. *)

(* THE CONTEST HAS CHANGED: TELL THE OTHER STATIONS. Sends a new HELLO when a
  link is up; nothing happens otherwise. *)
procedure NetContestChanged;

(* THIS STATION'S HELLO -- protocol, program version, computer id and the ID of
  the contest it is on. The first thing sent on every link. False when it
  cannot be built whole (an id longer than the field): nothing is sent. *)
function SendHello: boolean;

(* WHAT EVERY STATION HAS ANNOUNCED, for this link. Read by the unit tests. *)
function NetPeers: TNetPeers;

(* THE SERVER OR ITS PROTOCOL HAS BEEN REFUSED FOR THIS ADDRESS AND PORT, and the
  operator has been told. The connect timer then stops retrying (every five
  seconds for ever would be the same message again); Connect and Reconnect on
  the Net menu call this, so trying again after the server has been updated is
  the operator's act. It also forgets a refused computer id: whoever asks to
  connect again wants the attempt made. *)
procedure ForgetServerRefusal;

(* PEERS HAVE TO BE ON THE SAME CONTEST -- Q110, NY4I 2026-10-18: "Peers have to
  be on the same contest and that is a flagged error to be reported."

  A record from another station on a different contest is never logged, scored
  or applied: the NET_QSOINFO arm (QSO, note, QTC) and the NET_EDITEDQSO arm
  both ask here first. There is no other receive path -- the server's log sync
  reads no QSO packet in this client.

  THE JUDGEMENT (protocol 2): the packet's sender (aSender, qiSenderID, its
  ordinal 1..26) announced a contest id in its HELLO; the record is accepted
  when that id is the id of THIS station's contest, and then stamped with this
  station's own handle (aRec.ceContest), whatever byte the sender wrote. A
  sender that has announced nothing is refused too: nothing says what it is
  running.

  False means REFUSED, and the refusal is REPORTED, not silent:
    the log     one Error line per record (peer, its contest, ours, the call);
                the lines ARE the audit trail of what was dropped, so they are
                not rate-limited
    the screen  one QuickDisplay notice per (peer, peer's contest) per link
                session, so a busy peer cannot flood the operator; the latch is
                forgotten when the link comes up (ForgetPeerContestNotices).
                A sender that never said HELLO is a log line only.

  aDoor names the arm for the log. *)
function PeerRecordInOurContest(var aRec: ContestExchange; const aSender: integer;
                                const aDoor: string): boolean;

(* How many operator notices PeerRecordInOurContest has raised since the last
  ForgetPeerContestNotices -- the test's way to read "raised once". *)
function PeerContestNoticeCount: integer;
procedure ForgetPeerContestNotices;

type
  TPeerNoticeProc = procedure(const aText: string);

(* Where the operator notice goes; nil means QuickDisplay. A unit test points it
  at a recorder, because QuickDisplay needs a main window and a notice armer
  that live for the whole process. *)
var
  PeerContestNoticeSink: TPeerNoticeProc = nil;
  (* The same for the catch-up notice ("Resent to the server ..."), said once per
    link by ResendOfflineWork. *)
  ResendNoticeSink: TPeerNoticeProc = nil;

(* The walk over NetBuffer, one arm per message id. In the interface so the
  unit tests can put a packet in NetBuffer and hand it to the real arms. *)
function ConsumeNetBuffer(const i: integer; out aDesync: boolean): integer;

(* THE QSOS AND EDITS MADE WHILE THE LINK WAS DOWN MUST REACH THE SERVER WHEN IT
  COMES BACK -- Phase 1, C5 (2026-10-27). NY4I: a station that reboots or loses
  the link mid-contest must catch up.

  WHAT IT REPLACES. CommitChangesInLocalLog read the binary .TRW with
  OpenLogFile / ReadLogFile, which this build no longer keeps, so it returned at
  once; and its only caller was the log-sync thread, which nothing started. A QSO
  logged offline was never sent and nothing said so. It is gone.

  THE ROWS ARE THE LOG'S. sent_to_server = 0 marks a QSO the server has not been
  given and server_dirty = 1 one it holds an older version of; the repository
  answers which rows (uLogStore.LogStoreCollectUnsentToServer). A row owing a QSO
  goes as NET_QSOINFO_ID -- NOT NET_OFFLINEQSO_ID, which both servers store and
  never relay, so the other stations would not get it. A row owing an edit goes
  as NET_EDITEDQSO_ID. Both are posted from the MAIN thread to the send queue in
  one go, with no wait for an answer per record (the old loop waited a second
  for each).

  WHEN. Once per link, after the SERVER'S OWN HELLO has arrived (it proves the
  server speaks this protocol; a link that is merely connected proves nothing),
  at the end of the drain that handled it, so a refusal sent in the same breath
  has already been acted on. NetServiceResend is that step; ResendOfflineWork is
  the work and may be called directly.

  WHEN A QSO COUNTS AS SENT is uNetResend's header: when the writer thread has
  handed its bytes to the socket, not when it was posted. A flag changes only
  then, on the main thread (SettleServerProgress). A packet that is never
  written leaves its row owing, and the next link sends it again.

  WHAT A SECOND SEND DOES. Nothing: both servers and this client ignore a QSO
  whose (ceQSOID1, ceQSOID2) they already hold (ReceivedQsoIsKnown). *)
type
   TResendResult = record
      (* QSO packets and edit packets posted. *)
      Qsos: integer;
      Edits: integer;
   end;

function ResendOfflineWork: TResendResult;
procedure NetServiceResend;

(* THE OTHER HALF OF CATCHING UP: WHAT THE OTHER STATIONS LOGGED WHILE THIS ONE
  WAS AWAY (Phase 1, C6). Once per link, at the same moment as the resend (the
  server's HELLO, at the end of the drain that handled it), the server's log is
  fetched on its second port and the QSOs this log lacks are added, insert only
  -- automatically with SERVER AUTO SYNCHRONIZE LOG ON CONNECT, otherwise after
  asking. The rules, and why D7's CRC compare and replace could not be kept, are
  uNetCatchUp's header; the fetch and the write are uGetServerLog's. A no-op
  unless the HELLO made it due and the link is still up. *)
procedure NetServiceCatchUp;

(* THE THIRD HALF: RESTOCKING A SERVER THAT LOST ITS LOG (2026-10-28). The fetch
  that catches this station up also shows which of THIS log's QSOs the server
  lacks (uNetCatchUp.TPushPlan); this posts them. Each goes as NET_OFFLINEQSO_ID,
  which both servers store, ACK and do NOT relay, so the stations that are
  connected are not flooded. NO TAG: the rows are already sent_to_server = 1, so
  no flag is written when the packets go (SettleServerProgress sees nothing to
  settle). A link that drops half way needs no repair: the plan is made again
  from the server's log on the next link.

  The same guards as ResendOfflineWork, checked NOW because the fetch is
  asynchronous and the link may have changed since it was asked for. aPosted is
  how many were posted. True when the whole plan was posted; False when a guard
  refused or the link went down part way (aPosted says how far). *)
function RestockServer(aPlan: TPushPlan; out aPosted: integer): boolean;

(* CAN A RESTOCK GO DOWN THE LINK RIGHT NOW? The link is up, the server has said
  HELLO (it speaks this protocol) and has not refused this station's computer id
  -- the guards ResendOfflineWork uses. The window enables its Send button by
  it, the on-connect question is only asked when it holds, and RestockServer
  checks it again at send time. *)
function NetCanRestock: boolean;

(* THE PAIRS THE RESEND POSTED ON THIS LINK, owed rows the server may not have
  read yet. TPushPlan counts them as owed. Cleared when a link comes up. *)
function NetResentThisLink: TServerQsoIndex;

(* Record what became of the QSO packets the writer thread has finished with,
  and bring tUSQ / tUSQE into line with the log. Main thread. The writer
  schedules it; a test calls it. *)
procedure SettleServerProgress;

(* Do we already hold this QSO? A QSO arriving twice -- a resend of one the
  server had, an overlap of a live send and a resend -- must be logged once. The
  pair (0, 0) is never "known": it identifies nothing. *)
function ReceivedQsoIsKnown(const aRec: ContestExchange): boolean;

(* How many received QSOs ReceivedQsoIsKnown has turned away since start. *)
function NetDuplicateQsosIgnored: integer;

(* A NEW LINK IS A NEW SESSION (Q110, protocol 2, and C5): nobody has announced
  anything yet, the server has not answered, and nothing has been caught up.
  The connect thread calls it before the HELLO goes out; a test calls it to
  start a link from nothing. *)
procedure NetBeginLinkSession;

(* What the writer thread has reported and the main thread has not yet settled
  -- the test's way to wait for a write to finish. *)
function NetDeliveryLedger: TNetDelivery;

(* Hang the handlers on a client: bytes, drops, and what became of each QSO
  packet. ConnectToTR4WServer does it for the real client; a test does it for a
  TNetClient.CreateWithWriter so the real posting, writing and settling run
  without a server. *)
procedure AttachNetClient(aClient: TNetClient);

function SendRecordToServer(RecordType: Word; const rec: ContestExchange): boolean;
procedure SendFullStationStatus;
procedure SendSerialNumberChange(Status: TSerialNumberType);

type
  TParameterToNetworkPtr = ^TParameterToNetwork;
  TIntercomMessagePtr = ^TIntercomMessage;

var
  PreviousSerialNumberType              : TSerialNumberType = sntUnknown {sntFree};

  ServerSerialNumber                    : integer;
  (* A PORTABLE EVENT, NOT A WIN32 HANDLE (2026-09-08).

    THIS ONE WAS SEPARABLE AND THE OTHER THREE ARE NOT, which is the whole
    reason it moved on its own. tCW_Event, tCWPaddle_Event and tDVP_Event are
    handed to winmm's timeSetEvent with TIME_CALLBACK_EVENT_SET -- the
    multimedia timer signals the Win32 HANDLE itself -- so they cannot become
    a TEvent without replacing the CW element clock. tNet_Event never touches
    timeSetEvent: it is an ordinary producer/consumer signal between the
    network reader and the log-sync loop, and TEvent does that on every
    platform.

    AUTO-RESET, matching CreateEvent(nil, FALSE, FALSE, nil): TEvent's second
    argument is ManualReset, so False here means the wait consumes the signal
    exactly as the Win32 one did. *)
  tNet_Event                            : SyncObjs.TEvent;
  CurrentDisplayedRow                   : integer = 1;

  MF                                    : MultsFrequencies;
  tUSQ                                  : Cardinal;
  tUSQE                                 : Cardinal;

  (* tShowTypedCallsign, tAllowAutoUpdate and tNetStatusUpdateInterval are
    gone (2026-09-12) -- Settings.Network owns all three. *)
  tMessagesExhangeEnable                : boolean = True;
  StationStatusStringBuffer             : array[0..31] of Char;
  STARTTIMEOFTHETR4W                    : Cardinal;
  ACK                                   : integer;
  NetProcThreadID                       : Cardinal;

{(*}
  MyStationState                        : TStationState        ;// = (ssID: NET_STATIONSTATUS_ID);
  NetSynQSOInformation                  : TNetSynQSOInformation;// = (qsID: NET_TAKESERVERQSO_ID);//262
  NetQSOInfoToSend                      : TNetQSOInformation   ;// = (qiID: NET_QSOINFO_ID);//264
  (* NetDXSpot, NetTimeSync, NetIntercomMessage and SendSpotViaNetwork are no
    longer global (2026-10-27). Their id initialisers were commented out when
    the Network window stopped assigning them, and nothing else did, so every
    one of those packets left with id 0 and the server dropped the link. Each
    now lives in the implementation behind a Send...ToNet procedure that sets
    its id on every send. *)
  ParameterToNetwork                    : TParameterToNetwork  ;// = (pnID: NET_PARAMETER_ID; );//514
  ServerMessage                        : TServerMessage        = (smID: NET_SERVERMESSAGE_ID);//8
{*)}
  NetThreadID                           : TThreadID;
  StatusArray                           : array[1..26] of TStationState;
  PosInClientsList                      : array[1..26] of integer;
  (* ServerPassword is gone (2026-09-12) -- Settings.Server.Password, a
    TSecretText, so it lives in the keychain and is never taken from a
    peer. *)
  (* ServerAddress, ServerPort and ServerAutoSynchronizeLogOnConnect are
    gone (2026-09-12) -- Settings.Server owns all three. Issue #912. *)
  { THE LINK, over Indy.  Was `NetSocket: Cardinal` -- a raw Winsock handle
    that three other units tested for zero; ask NetIsConnected instead. }
  NetClient                             : TNetClient = nil;
  ConnectedwithServer                   : boolean;
//  NetworkListViewhandle                 : HWND;
  TotalClients                          : integer;
//  LastStatus                       : StationStatusType;
const

  STATUS_BYTE_BIT_PTT                   = 1;
  STATUS_BYTE_BIT_OPMODE                = 2;
  STATUS_BYTE_BIT_DUPE                  = 4;
  STATUS_BYTE_BIT_PTT_LOCKOUT           = 8;
//  STATUS_BYTE_BIT_MULT                  = 8;

implementation
uses
   uSettingsModel,     // Settings -- the settings that have left CFGCA
   uAppTimers,   (* StartAppTimer / StopAppTimer -- LCL TTimers, not SetTimer *)
  Menus,          { TMenuItem -- the Network menu row }
  uMenu,          { TopLevelMenuItem }
   { The SQLite shadow -- an IMPLEMENTATION-section use, so no interface
     cycle. uLogStore never raises and never blocks logging. }
   uLogStore,
  (* Which store a log read comes from. *)
  uLogSource,
  uMainForm,   { the call field, named -- wh[] round 3 }
  uPanelUpdate,   { PostStatusText -- the Network status panel, from any thread }
  uNetworkForm,   { the station list is a TListView on a form now }
  Controls,       { TCaption -- see ShowConnectionStatus }
  uCFG,
  LOGSUBS2,
  uRadioPolling,
  uRadioConfigApply,   // ApplyPeerCommand -- a peer's config change
  uContestRegistry,    // ContestId, ContestIdentity -- the ID a HELLO carries
  Version,             // TR4W_CURRENTVERSION_NUMBER -- the HELLO's program version
  uTelnet,
  uGetServerLog,
  MainUnit,
  uAppStrings,   { SNetComputerIDInUse -- new UI text does not go in uTR4WStrings }
  uComputerID,   { the station-id rule and its two wire encodings }
   uConfigValues,
   uHostResolve;   { TryResolveHost -- a .local name through the C library, issue 148 }

{ THE ID THE SERVER REFUSED, in the ordinal form the wire uses, or #0.

  WITHOUT THIS THE CLIENT RETRIES THE REFUSAL EVERY FIVE SECONDS FOREVER.  The
  retry timer (NetLinkTick) calls TryConnectToNetwork whenever the link is down, so
  a station kicked for a duplicate id would reconnect, be refused, drop and come
  straight back -- flooding both logs and telling the operator nothing he had not
  already dismissed once.

  IT CLEARS ITSELF.  Rather than a flag someone has to remember to reset, the
  refused id is REMEMBERED and compared: the moment COMPUTER ID is changed to
  anything else the comparison stops matching and retrying resumes on its own.
  That is exactly the action the message asks for, so recovery needs no second
  step and no restart.

  UNIT SCOPE, deliberately.  It is written by the message arm inside
  ConsumeNetBuffer and read by TryConnectToNetwork seven hundred lines later;
  the first version of this declared it among ConsumeNetBuffer's LOCALS, where
  it compiled at the write and vanished at the read. }
var
  FRefusedComputerID : AnsiChar = #0;

(* NETWORK PROTOCOL 2 -- WHAT THIS STATION KNOWS ABOUT THE OTHER ENDS.

  GPeers: what each station announced in its HELLO (uNetHello). Created with the
  unit, emptied when a link comes up, read and written on the MAIN thread by the
  message arms.

  THE SERVER'S ANSWER. FHelloSentTick is when this station's HELLO went out and
  FServerHelloSeen whether the server has said anything back. A server that
  does not know HELLO (every server before protocol 2) drops the link the moment
  it reads one, so "the link dropped within a few seconds of the HELLO and the
  server never answered" is how that case is told from an ordinary drop.

  FServerRefusedFor: the server address and port the operator was last told this
  build cannot talk to -- the same refusal-without-nagging shape as
  FRefusedComputerID, and re-armed by ForgetServerRefusal. *)
var
  GPeers:            TNetPeers = nil;
  FHelloSentTick:    QWord = 0;
  FServerHelloSeen:  boolean = False;
  FServerRefusedFor: string = '';
  (* THE OPERATOR'S WISH FOR A LINK THIS SESSION, and the last status line the
    link reported (the Network window's title, read under GNetLock because the
    connect thread writes it). See NetLinkConnect. *)
  GLinkWanted:       boolean = False;
  GLinkOperation:    string = '';
  (* CATCHING UP (Phase 1, C5). GResendDue: the server's own HELLO has arrived on
    this link and the work it unlocks has not been done. GResentThisLink: it has,
    so a second server HELLO on the same link does not do it again. Both are
    cleared when a link comes up. Main thread. *)
  GResendDue:        boolean = False;
  GResentThisLink:   boolean = False;
  (* CATCHING UP FROM THE SERVER'S LOG (Phase 1, C6): due once the server's HELLO
    has come on this link, started by NetServiceCatchUp at the end of the same
    drain as the resend. Cleared when a link comes up. Main thread. *)
  GCatchUpDue:       boolean = False;
  (* What became of the QSO packets: the writer thread reports, the main thread
    settles (uNetResend). *)
  GNetDelivery:      TNetDelivery = nil;
  (* The pairs ResendOfflineWork posted on this link. Main thread. *)
  GResentKeys:       TServerQsoIndex = nil;
  GDuplicateQsos:    integer = 0;
  (* Which refused outbound packets (SendToNet's guard) have been reported on
    this link. Thread-safe; reset when a link comes up. *)
  GSendRefusals:     TNetSendRefusals = nil;
  (* A spot from the network was ignored on this link because Network.ShareSpots
    is off: the Debug line is written once per link. Main thread (the drain);
    reset when a link comes up. *)
  GSpotShareNoted:   boolean = False;

const
  (* An older server drops the link within a read or two of the HELLO; an
    ordinary failure at any other time is not blamed on the protocol. *)
  HELLO_ANSWER_WINDOW_MS = 5000;

function ServerKey: string;
begin
   Result := Settings.Server.Address + ':' + IntToStr(Settings.Server.Port);
end;

(* THE SERVER CANNOT BE USED: TELL THE OPERATOR ONCE AND LET GO.

  Latches the address and port so the connect timer stops retrying, then closes
  the link. Runs on the main thread (a message arm, or the drop report). *)
procedure RefuseServer(const aWhy: string);
begin
   FServerRefusedFor := ServerKey;
   NetLinkWentDown;
   showwarning(aWhy);
end;

(* THE SERVER SPEAKS ANOTHER PROTOCOL: SAY WHICH END IS BEHIND, in words. *)
procedure RefuseServerProtocol(const aServerProtocol: Word);
begin
   logger.Warn('[Net] the server speaks network protocol %d and this TR4W speaks %d',
               [aServerProtocol, NET_PROTOCOL_VERSION]);
   if JudgeProtocol(NET_PROTOCOL_VERSION, aServerProtocol) = pvTheirsNewer then
      begin
      RefuseServer(SysUtils.Format(SNetServerProtocolNewer,
                                   [aServerProtocol, NET_PROTOCOL_VERSION]));
      end
   else
      begin
      RefuseServer(SysUtils.Format(SNetServerProtocolOlder,
                                   [aServerProtocol, NET_PROTOCOL_VERSION]));
      end;
end;

(* A HELLO: THE SERVER'S OWN (computer id 0) OR A STATION'S, relayed. *)
procedure HandleHelloReceived(const aHello: THelloMessage);
begin
   if aHello.hmComputerID = 0 then
      begin
      FServerHelloSeen := True;
      logger.Info('[Net] server hello: network protocol %d, server version %s',
                  [aHello.hmProtocol, HelloAppVersion(aHello)]);
      if JudgeProtocol(NET_PROTOCOL_VERSION, aHello.hmProtocol) <> pvSame then
         begin
         RefuseServerProtocol(aHello.hmProtocol);
         end
      else
         begin
         (* THE SERVER SPEAKS THIS PROTOCOL: what was logged while the link was
           down can go. Not here -- the server answers a HELLO before it judges
           the computer id, so a refusal may be in the same buffer -- but when
           the drain that is handling this buffer has finished with it
           (NetServiceResend). *)
         GResendDue := True;
         GCatchUpDue := True;
         end;
      Exit;
      end;

   if GPeers.Announce(aHello) then
      begin
      logger.Info('[Net] station %s announced contest "%s" (TR4W %s, protocol %d)',
                  [ComputerIDLetter(AnsiChar(aHello.hmComputerID)),
                   HelloContestId(aHello), HelloAppVersion(aHello),
                   aHello.hmProtocol]);
      end
   else
      begin
      logger.Warn('[Net] a hello with computer id %d was ignored',
                  [aHello.hmComputerID]);
      end;
end;

procedure InitializeNetworkColumnTitles;
{ Indices, not names: the array is positional and the four translatable
  titles sit at 0, 2, 3 and 7. Kept next to the declaration deliberately --
  inserting a column without updating these would silently retitle the wrong
  ones, and nothing would fail. }
begin
   NetColumnsArray[0].Text := RC_NAME;
   NetColumnsArray[2].Text := RC_BAND;
   NetColumnsArray[3].Text := TC_FREQ;
   NetColumnsArray[7].Text := RC_CALLSIGN;
end;

{ CONSUME WHOLE MESSAGES FROM NetBuffer AND SAY HOW MANY BYTES WENT.

  THIS IS THE WM_SOCK_NET ARM, MOVED AND OTHERWISE UNTOUCHED.  It used to run
  inside the network window's dialog procedure, because WSAAsyncSelect posted
  WM_SOCK_NET there whenever the socket became readable -- which is what tied
  the multi-op transport to a window.  The bytes arrive over Indy now and this
  runs on the MAIN THREAD, which is where it always ran, so every arm still
  touches the log, the mult sheet and the display exactly as before.

  THE NESTED Walk IS WHY THE BODY COULD BE MOVED VERBATIM.  Its arms leave
  through `Exit` when the buffer is spent; wrapping them means Exit ends the
  walk rather than the whole routine, and Bufindex is still standing afterwards
  to say how far it got.

  RETURNS BYTES CONSUMED, so the caller can keep a short tail.  That is new and
  it matters: recv() and Indy both hand over whatever has arrived, which may cut
  a record in half, and uNetFraming's nwPartial arm used to log the remainder
  and drop it.  A caller that carries the tail forward turns that into nothing
  at all -- the same class of defect as the DX cluster's lost lines. }
function ConsumeNetBuffer(const i: integer; out aDesync: boolean): integer;
var
  { AN UNRECOGNISED ID IS NOT THE SAME AS A SHORT TAIL, and telling them apart
    is what stops the link WEDGING.

    Both used to leave the same way, because the whole recv buffer was thrown
    away afterwards either way.  Now that the caller keeps what was not
    consumed, a short tail must be kept -- the next read completes it -- while
    an unrecognised id must NOT be, or the same bytes are re-examined forever
    and no message ever gets through again, in silence. }
  Desync: boolean;
  { COPIED FROM NetDlgProc's OWN var BLOCK, which is where the walk used to
    live.  Nothing added and nothing renamed; `i` became the parameter. }
  Bufindex                              : integer;
  ClientID                              : integer;
  DisconnectedClient                    : integer;
  MsgId                                 : word;
  MsgSize                               : integer;
  StationStPtr                          : TStationStatePtr;
  NetQSOInfoPtr                         : NetQSOInformationPtr;
  ServerMessagePtr                      : TServerMessagePtr;
  NetDXSpotPtr                          : TNetDXSpotPtr;
  NetTimeSyncPtr                        : TNetTimeSyncPtr;
  ParameterToNetworkPtr                 : TParameterToNetworkPtr;
  IntercomMessagePtr                    : TIntercomMessagePtr;

   { The label lives HERE: a goto may not cross a procedure boundary. }
   procedure Walk;
   label
     CheckBuffer;
   begin
        Bufindex := 1;

        //        i-���-�� �� ����������� ����
        //        Bufindex- � ����� ������� �������� ������

        CheckBuffer:

        { WHERE THIS MESSAGE ENDS IS ASKED ONCE, BEFORE ANY ARM RUNS.

          Each arm used to carry its own `Bufindex := Bufindex + SizeOf(...)`,
          and one of them named the wrong record: NET_SPOTVIANETWORK_ID cast the
          buffer to TSendSpotViaNetworkPtr and advanced by 264 bytes for a
          48-byte message.  While the size lives beside the arm, the arm can
          disagree with the cast on the line above it.  uNetFraming holds one
          table now and the arms hold none. }
        MsgId := PWORD(@NetBuffer[Bufindex])^;
        MsgSize := NetMessageSize(MsgId);

        { AN ID NOTHING KNOWS USED TO BE A SILENT WHOLE-BUFFER LOSS.  No arm
          matched, so nothing advanced, control span a counter to 30 and
          returned -- the network window just stopped updating for a station
          while the connection still said "connected". }
        if MsgSize = 0 then
           begin
           Desync := True;
           logger.Warn('[Net] Unrecognised message id %d at offset %d of %d ' +
                       'bytes -- the rest of this buffer is discarded',
                       [MsgId, Bufindex, i]);
           Exit;
           end;

        { THE LENGTH CHECK THE LOOP NEVER HAD.  Every arm below casts a whole
          record out of the buffer.  If 100 bytes of a 264-byte QSO had arrived,
          the other 164 were STALE BYTES FROM AN EARLIER recv and the QSO was
          logged from them -- a duplicate of an earlier contact with a plausible
          call and a wrong band, unmarked anywhere in the UI.

          This does not make a split message WORK; that needs a carry-over
          buffer the receive path does not have yet (bench queue 40).  It makes
          it fail loudly instead of silently logging a wrong QSO. }
        if (i - Bufindex + 1) < MsgSize then
           begin
           logger.Warn('[Net] Message id %d at offset %d needs %d bytes but ' +
                       'only %d arrived -- discarded, not guessed',
                       [MsgId, Bufindex, MsgSize, i - Bufindex + 1]);
           Exit;
           end;

        case MsgId of
          NET_STATIONSTATUS_ID:
            begin
              StationStPtr := @NetBuffer[Bufindex];
              if StationStPtr^.ssComputerID in ['A'..'Z'] then
                 begin
                 ClientID := Ord(StationStPtr^.ssComputerID) - Ord('A') + 1;
                 if PosInClientsList[ClientID] = 0 then
                    begin
                    AddNewClient(ClientID);
                    end;
                 StatusArray[ClientID] := StationStPtr^;
                 DisplayClientStatus(ClientID);

                 end;
            end;

          NET_INTERCOMMESSAGE_ID:
            begin
              IntercomMessagePtr := @NetBuffer[Bufindex];
              (* THE SHORTSTRING ITSELF, not the address of its first byte.
                It carries its own length; the pointer form had to guess one by
                looking for a NUL that a Str80 does not have, and imMessage is
                the last field of a packed record sitting on the receive
                buffer. *)
              AddMessageToIntercomWindow(IntercomMessagePtr^.imMessage, IntercomMessagePtr^.imSender);
            end;

          NET_LOGCOMPARE_ID:
            begin
              ProcessServerLogInfo(@NetBuffer[Bufindex + 2 - 2]);
            end;
{
          NET_MULTSFREQUENCIES_ID:
            begin
              Move(NetBuffer[Bufindex + 2], MF, SizeOf(MultsFrequencies));
              DisplayMultsFrequencies;
              Bufindex := Bufindex + SizeOf(NetMultsFrequencies);
              if Bufindex - 1 >= I then Exit;
            end;
}
          NET_PARAMETER_ID:
            begin
              ParameterToNetworkPtr := @NetBuffer[Bufindex];
              // ApplyPeerCommand, not CheckCommand + an ini write.  A row that
              // has moved to settings\tr4w.json is INERT to CheckCommand, so
              // this returned False for seventeen rows -- the UDP broadcast
              // block among them -- and the operator was told nothing while the
              // station that made the change saw it take effect.  The routine
              // routes on the row's own state and persists to whichever file is
              // that row's system of record.
              //
              // A peer's CONTEST command is followed whatever the contest (it
              // used to be refused for a contest with no legacy number): the
              // setting's effect re-announces THIS station's contest in a new
              // HELLO (NetContestChanged), which is how the others learn it.
              if ApplyPeerCommand(string(ParameterToNetworkPtr^.pnCommand),
                                  string(ParameterToNetworkPtr^.pnValue)) then
                 begin
 //                ShowTrayTips();
                 QuickDisplay(string(ParameterToNetworkPtr^.pnCommand) + ' was changed by other station in network');
                 end;
            end;

          NET_TIMESYN_ID:
            begin

              NetTimeSyncPtr := @NetBuffer[Bufindex];
              if NetTimeSyncPtr.tsTime.wYear > 2007 then
                if NetTimeSyncPtr.tsTime.wMonth <= 12 then
                  if NetTimeSyncPtr.tsTime.wDay <= 31 then
                    if NetTimeSyncPtr.tsTime.wHour <= 23 then
                       begin

                       (* SETTING THE MACHINE CLOCK IS A POLICY QUESTION OFF
                         WINDOWS, NOT A MISSING API.

                         Unix has settimeofday/clock_settime, so this could
                         be written -- but it needs ROOT, and a contest
                         logger asking for root so a peer station can move
                         the system clock is a decision about what TR4W
                         should be allowed to do, not a translation. It is
                         NY4I's call, and until it is made the honest
                         behaviour is to say the packet arrived and was not
                         acted on, rather than to fail silently or to
                         pretend the clock was set.

                         The multi-op protocol is unaffected either way: the
                         sender broadcasts, and a station that declines to
                         move its clock simply keeps its own time. *)
{$IFDEF WINDOWS}
                       if Windows.SetSystemTime(NetTimeSyncPtr.tsTime) then
                          begin
                          QuickDisplay(TC_COMPUTERCLOCKISSYNCHRONIZED)
                          end
                       else
                          begin
                          ShowSysErrorMessage('SET SYSTEM TIME');
                          end;
{$ELSE}
                       logger.Info('[Net] time-sync packet ignored: setting ' +
                                   'the system clock is not implemented on ' +
                                   'this platform (it needs root, and whether ' +
                                   'TR4W should do it at all is undecided)');
{$ENDIF}
                       end;
            end;

          NET_NETWORKDXSPOT_ID:
            begin
              (* SHARING OFF: this station does not take the network's spots.
                The packet is still CONSUMED -- the common advance at the foot
                of the loop moves past it -- and is not an error. Read at the
                moment of the spot, so a change needs no restart. AddSpot is
                called with SendToNetwork False, so a received spot is never
                posted back. *)
              if Settings.Network.ShareSpots then
                 begin
                 NetDXSpotPtr := @NetBuffer[Bufindex];
                 SpotsList.AddSpot(NetDXSpotPtr^.dsSpot, False);
                 DisplayBandMap;
                 end
              else
                 begin
                 if not GSpotShareNoted then
                    begin
                    GSpotShareNoted := True;
                    logger.Debug('[Net] spot from the network ignored: sharing is off');
                    end;
                 end;
            end;

          NET_QSOINFO_ID:
            begin
              NetQSOInfoPtr := @NetBuffer[Bufindex];
              (* JUDGED BY WHAT THE SENDER ANNOUNCED, NOT BY THE RECORD'S BYTE
                (protocol 2). An accepted record comes back stamped with THIS
                station's contest; one from a station on another contest, or
                one that never said HELLO, is dropped whole and reported. *)
              (* AND NOT ONE THIS STATION ALREADY HOLDS (Phase 1, C5). A station
                that was disconnected sends again what it logged meanwhile, and
                one it had already sent whose flag was never set (a crash, a
                write that finished as the link fell) goes twice; the server
                relays a QSO it did not have, but another station may still meet
                the same pair twice. The first copy is logged; the next ones are
                counted and ignored. Judged AFTER the contest gate, so a QSO from
                another contest is still reported as that. *)
              if PeerRecordInOurContest(NetQSOInfoPtr^.qiInformation,
                                        NetQSOInfoPtr^.qiSenderID,
                                        'NET_QSOINFO') and
                 (not ReceivedQsoIsKnown(NetQSOInfoPtr^.qiInformation)) then
                 begin
                 if NetQSOInfoPtr^.qiInformation.ceRecordKind = rkQSO then
                    begin
                    if NetQSOInfoPtr^.qiComputerID <> NetQSOInfoToSend.qiComputerID then
                       begin
                       LogContact(NetQSOInfoPtr^.qiInformation, False);
                       UpdateWindows;
                       end;
                    end;

                 if NetQSOInfoPtr^.qiInformation.ceRecordKind = rkNote then
                    begin
                    (* A PEER'S RECORD THAT THIS STATION COULD NOT KEEP. It is
                      already logged at the station that made it, so this is not
                      a lost contact -- but this station's copy of the multi-op
                      log is now incomplete and only the log says so. *)
                    if not tAddQSOToLog(NetQSOInfoPtr^.qiInformation) then
                       begin
                       logger.Error('[Net] a note from the network did NOT commit '
                                    + 'to the contest log');
                       end;
                    end;

                 if NetQSOInfoPtr^.qiInformation.ceRecordKind in [rkQTCR, rkQTCS] then
                    begin
                    if NetQSOInfoPtr^.qiInformation.ceRecordKind = rkQTCS then
                       begin
                       NumberQTCBooksSent := NetQSOInfoPtr^.qiInformation.QSOPoints;
                       end;
                    IncrementQTCCount(NetQSOInfoPtr^.qiInformation.Callsign);
                    if not tAddQSOToLog(NetQSOInfoPtr^.qiInformation) then
                       begin
                       logger.Error('[Net] a QTC record from %s did NOT commit to '
                                    + 'the contest log',
                                    [NetQSOInfoPtr^.qiInformation.Callsign]);
                       end;
                    DisplayTotalScore;
                    UpdateTotals2;
                    end;
                 end;

            end;

          NET_EDITEDQSO_ID:
            begin
              NetQSOInfoPtr := @NetBuffer[Bufindex];

              if (NetQSOInfoPtr^.qiComputerID <> NetQSOInfoToSend.qiComputerID) and
                 PeerRecordInOurContest(NetQSOInfoPtr^.qiInformation,
                                        NetQSOInfoPtr^.qiSenderID,
                                        'NET_EDITEDQSO') then
                 begin
                 if FindAndUpdateQSOInLog(NetQSOInfoPtr^.qiInformation) then
                    begin
                    if Settings.Network.AllowAutoUpdate then
                       begin
                       RescoreLog;
                       end;
                    end;
                 end;
            end;

          NET_SPOTVIANETWORK_ID:
            begin
              // A SPOT ANOTHER OPERATOR ANNOUNCED ON THE MULTI-OP NETWORK,
              // forwarded out to the DX cluster.  This is the ONLY place the
              // two subsystems touch, and it is a feature, not shared
              // transport: tr4wserver carries QSOs, radio and operator state;
              // the cluster carries spot text.
              SendViaTelnetSocket(TSendSpotViaNetworkPtr(@NetBuffer[Bufindex])^.vnMessage);

              // WAS SizeOf(NetQSOInfoToSend) -- 264 bytes for a 48-byte
              // message, an overshoot of 216.  The line above casts this to
              // TSendSpotViaNetworkPtr, which is what it is; the advance
              // disagreed with the cast.  One network spot desynchronised the
              // rest of the buffer, and the desync is silent (see the
              // no-advance guard at the foot of this loop).
            end;

          NET_HELLO_ID:
            begin
              HandleHelloReceived(THelloMessagePtr(@NetBuffer[Bufindex])^);
            end;

          NET_SERVERMESSAGE_ID:
            begin

              ServerMessagePtr := @NetBuffer[Bufindex];
              case ServerMessagePtr.smMessage of

                SM_CLEARALLLOGS_MESSAGE: ClearLog;

                SM_CLEAR_DUPESHEET_MESSAGE: tClearDupesheet;

                SM_CLEAR_MULTSHEET_MESSAGE: tClearMultSheet;

//                SM_SERVERLOG_CHANGED_MESSAGE: ShowTrayTips(TC_SERVER_LOG_CHANGED);

                SM_DISCONECT_CLIENT_MESSAGE:
                  begin
                    // `i` IS THE RECV BYTE COUNT, not scratch.  This arm used
                    // to assign smParam (a client index, 1..26) straight into
                    // it, after which the loop's `Bufindex - 1 >= i` test
                    // compared against a small integer and exited -- dropping
                    // every message that had arrived behind the disconnect
                    // notice in the same segment.
                    DisconnectedClient := ServerMessagePtr^.smParam;

                    // RANGE-CHECKED, because 0 IS REACHABLE.  The server sends
                    // ClientsSoocketsArray[b].clID, which is #0 for any client
                    // that connected and never announced an id -- including,
                    // now, one the server refused.  StatusArray is [1..26] and
                    // range checking is off in this tree, so index 0 would not
                    // raise: it would zero the sixteen bytes in front of the
                    // array and carry on.
                    if DisconnectedClient in [1..26] then
                       begin
                       FillChar(StatusArray[DisconnectedClient], SizeOf(TStationState), 0);
                       DisplayClientStatus(DisconnectedClient);
                       (* A STATION THAT HAS GONE ANNOUNCED NOTHING NOW: its
                         HELLO would otherwise vouch for a contest that no
                         longer has anyone on it. *)
                       GPeers.Forget(DisconnectedClient);
                       end;
                  end;

                { THE SERVER WILL NOT SPEAK THIS STATION'S PROTOCOL: smParam is
                  the one it speaks. Said once; the link goes. }
                SM_PROTOCOL_MISMATCH_MESSAGE:
                  begin
                    FServerHelloSeen := True;
                    RefuseServerProtocol(Word(ServerMessagePtr^.smParam));
                  end;

                { THE SERVER WILL NOT HAVE THIS ID.  Latch, say so once, and go
                  away -- see FRefusedComputerID for why the retry has to stop
                  and how it starts again. }
                SM_COMPUTERID_IN_USE_MESSAGE:
                  begin
                    FRefusedComputerID := AnsiChar(ServerMessagePtr^.smParam);
                    logger.Warn('[Net] server refused computer ID %s -- ' +
                                'another station is already using it',
                                [string(Settings.Computer.Id)]);
                    NetLinkWentDown;
                    showwarning(SysUtils.Format(SNetComputerIDInUse,
                                                [string(Settings.Computer.Id)]));
                  end;

                SM_GETSTATUS_MESSAGE: SendFullStationStatus;

                SM_RECEIVED_UPDATED_QSO_MESSAGE:
//                asm                nop end;
                  tNet_Event.SetEvent;

                SM_SERIAL_NUMBER_CHANGED:
                  begin
                    ServerSerialNumber := ServerMessagePtr^.smParam;
                    DisplayNextQSONumber;
                  end;
              end;

              ShowServerMessage(ServerMessagePtr^);

            end;
        end;
{
        IntPtr := @NetBuffer[Bufindex];

        if IntPtr^ = Ord('D') + Ord('I') * $100 + Ord('S') * $10000 + Ord('C') * $1000000 then
        begin
          I := integer(NetBuffer[Bufindex + 4]);
          FillChar(StatusArray[I], SizeOf(TStationState), 0);
          DisplayClientStatus(I);
          Bufindex := Bufindex + SizeOf(sDISMESSAGE);
          if Bufindex - 1 >= I then Exit;
        end;
}
{
        if PDWORD(@NetBuffer[Bufindex])^ = NET_CLEARLOG_MESSAGE then
        begin
          ClearLog;
          Bufindex := Bufindex + SizeOf(NET_CLEARLOG_MESSAGE);
          if Bufindex - 1 >= I then Exit;
        end;
}
{$IF OZCR2008}

        WordPtr := @NetBuffer[Bufindex];
        if WordPtr^ = NET_MESSAGESTATE_ID then
           begin
           MessageStatePtr := @NetBuffer[Bufindex];
           if MessageStatePtr^.msComputerId in ['A'..'Z'] then
              begin
              ClientID := Ord(MessageStatePtr^.msComputerId) - Ord('A') + 1;
              DisplayMessageStatus(ClientID, MessageStatePtr^);
              end;
           Bufindex := Bufindex + SizeOf(TMessageState);
           if Bufindex - 1 >= i then Exit;
           end;
{$IFEND}
        { ONE ADVANCE, FROM THE TABLE, AND IT CANNOT BE FORGOTTEN.

          The 30-iteration spin that used to be here was a guard against an arm
          that advanced nothing.  Nothing can now: the size was resolved before
          the case ran, and every path through it arrives here.  A cap that
          exists because the loop might not terminate is worse than a loop that
          terminates. }
        inc(Bufindex, MsgSize);
        if Bufindex - 1 >= i then
           begin
           Exit;
           end;

        goto CheckBuffer;
   end;

begin
   Desync := False;
   Walk;
   aDesync := Desync;
   Result := Bufindex - 1;
   if Result < 0 then
      begin
      Result := 0;
      end;
end;

{ ---------------------------------------------- bytes off the reader thread -- }

{ WHAT ARRIVES, AND WHERE IT IS ALLOWED TO BE HANDLED.

  TNetClient's reader is a THREAD.  Every arm of ConsumeNetBuffer writes the
  log, the mult sheet, the status list and the display -- all main-thread
  things -- so nothing here parses on the reader.  The bytes are appended to a
  buffer under a lock and the main thread is asked to drain it.

  Application.QueueAsyncCall, for the reason uPanelUpdate documents at length:
  TThread.Queue purges by the calling thread's id when that thread dies, and a
  network reader dies exactly when a disconnect needs reporting.

  THE TAIL IS KEPT.  A read can end mid-record -- that is ordinary TCP, and it
  is the same defect class that lost DX cluster lines at segment boundaries.
  ConsumeNetBuffer says how many bytes it used and whatever is left waits for
  the rest to arrive. }

type
   TNetDrainer = class(TObject)
   private
      procedure DrainBuffer;
   public
      procedure Drain(Data: PtrInt);
      procedure ReportDropped(Data: PtrInt);
      procedure LinkChanged(Data: PtrInt);
      (* The writer thread has finished with QSO packets: record what became of
        them. See SettleServerProgress. *)
      procedure Settle(Data: PtrInt);
   end;

var
   { SyncObjs-QUALIFIED.  uPanelUpdate declares this exact line unqualified
     and compiles, because its uses clause is five units long.  uNet's is
     forty, and something in it redeclares TCriticalSection as a RECORD --
     FPC then reads `= nil` as a record initialiser and asks for a '('. }
   GNetLock: SyncObjs.TCriticalSection = nil;
   GNetDrainer: TNetDrainer = nil;
   GNetPending: TBytes;   { nil to begin with -- a dynamic array is }

procedure TNetDrainer.Drain(Data: PtrInt);
begin
   DrainBuffer;
   (* AFTER everything that arrived has been handled, whatever it was: a server
     HELLO and the refusal that may follow it in one read are both acted on
     before any QSO is posted. *)
   NetServiceResend;
   (* THEN what the others logged meanwhile is fetched. The order matters only
     for the log: what this station sends is posted before it asks. *)
   NetServiceCatchUp;
end;

procedure TNetDrainer.Settle(Data: PtrInt);
begin
   SettleServerProgress;
end;

procedure TNetDrainer.DrainBuffer;
var
   take, used: integer;
   desync: boolean;
begin
   while True do
      begin
      GNetLock.Acquire;
      try
         take := Length(GNetPending);
         if take > SizeOf(NetBuffer) then
            begin
            take := SizeOf(NetBuffer);
            end;
         if take <= 0 then
            begin
            Exit;
            end;
         Move(GNetPending[0], NetBuffer, take);
      finally
         GNetLock.Release;
      end;

      used := ConsumeNetBuffer(take, desync);

      if desync then
         begin
         // THE STREAM IS NO LONGER ON A MESSAGE BOUNDARY and there is no way to
         // find the next one: the protocol has no framing marker to hunt for,
         // only a table of sizes by id.  Throwing the buffer away is what the
         // old code did implicitly on every unrecognised id, and it is still
         // the only recovery -- but it says so now instead of looking like an
         // ordinary read.
         GNetLock.Acquire;
         try
            GNetPending := nil;
         finally
            GNetLock.Release;
         end;
         logger.Error('[Net] stream desynchronised -- %d byte(s) discarded to resynchronise',
                      [take - used]);
         Exit;
         end;

      if used <= 0 then
         begin
         // A short tail: nothing whole yet.  Wait for the rest rather than
         // spinning, and do NOT drop it -- dropping it is what lost DX cluster
         // lines at segment boundaries.
         Exit;
         end;

      GNetLock.Acquire;
      try
         if used >= Length(GNetPending) then
            begin
            GNetPending := nil;
            end
         else
            begin
            Move(GNetPending[used], GNetPending[0], Length(GNetPending) - used);
            SetLength(GNetPending, Length(GNetPending) - used);
            end;
      finally
         GNetLock.Release;
      end;
      end;
end;

{ THE OLD `i <= 0` ARM OF WM_SOCK_NET, unchanged except that it now runs
  because the reader said the link dropped rather than because recv returned
  nothing.  Auto-reconnect still comes from the WM_TIMER path, which retries
  while the link is down. }
procedure TNetDrainer.ReportDropped(Data: PtrInt);
begin
   (* THE LOST-LINK MESSAGE IS THE STATUS NOW, AND THE QuickDisplay THAT STOOD
     HERE IS DELETED RATHER THAN MOVED.  ShowConnectionStatus (inside
     NetLinkWentDown) says the same thing and writes the Network panel, which
     HOLDS it until the link comes back -- whereas the notice it replaced was
     wiped after 30 s, or sooner by any of the ~120 other things that write that
     caption.  Two spellings of one fact, and the shorter-lived one was the one
     an operator saw. *)
   NetLinkWentDown;

   (* THE LINK WENT WITHIN SECONDS OF OUR HELLO AND THE SERVER NEVER ANSWERED IT.
     A server that does not know HELLO closes the link on reading one, and says
     nothing a station could read -- so this is how "your server is older than
     this TR4W" is told from an ordinary drop. Said once per address and port;
     the connect timer then stops retrying (ForgetServerRefusal re-arms it). *)
   if (not FServerHelloSeen) and (FHelloSentTick <> 0) and
      (FServerRefusedFor = '') and
      (GetTickCount64 - FHelloSentTick < HELLO_ANSWER_WINDOW_MS) then
      begin
      logger.Warn('[Net] the server closed the link without answering HELLO ' +
                  '(network protocol %d); it is probably older than this TR4W',
                  [NET_PROTOCOL_VERSION]);
      FServerRefusedFor := ServerKey;
      NetLinkChanged;
      showwarning(SysUtils.Format(SNetNoHelloAnswer, [NET_PROTOCOL_VERSION]));
      end;
end;

(* THE STATE CHANGED, from any thread. The Net menu and the observers are
  touched on the main thread only: the connect thread reports through here, and
  so does the status line it writes. *)
procedure TNetDrainer.LinkChanged(Data: PtrInt);
begin
   ApplyNetworkMenuState;
   NetLinkObservers.Notify(nil);
end;

procedure NetLinkChanged;
begin
   if GetCurrentThreadId = MainThreadID then
      begin
      GNetDrainer.LinkChanged(0);
      Exit;
      end;

   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;
   Application.QueueAsyncCall(GNetDrainer.LinkChanged, 0);
end;

{ ON THE READER THREAD. }
procedure NetDataArrived(const aData: TIdBytes);
var
   have: integer;
begin
   if Length(aData) = 0 then
      begin
      Exit;
      end;

   GNetLock.Acquire;
   try
      have := Length(GNetPending);
      SetLength(GNetPending, have + Length(aData));
      Move(aData[0], GNetPending[have], Length(aData));
   finally
      GNetLock.Release;
   end;

   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;
   Application.QueueAsyncCall(GNetDrainer.Drain, 0);
end;

{ ON THE READER THREAD.  Reports the drop the way the old `i <= 0` arm of
  WM_SOCK_NET did -- it is the same event, arriving as an event instead of as a
  zero-length read. }
procedure NetLinkDropped(const aText: string);
begin
   logger.Warn('[Net] link to TR4WServer lost: %s', [aText]);
   Application.QueueAsyncCall(GNetDrainer.ReportDropped, 0);
end;

const
   (* The packet kind the writer reports for a new QSO; also the name
     NetPacketKind gives NET_QSOINFO_ID. *)
   KIND_QSOINFO = NET_KIND_QSOINFO;

(* ON THE WRITER THREAD.  A QSO or edit packet's write FINISHED -- written, or
  failed -- and this is how the main thread learns it. Only the three kinds that
  carry a QSO are of interest; the rest (a status, a spot) are not in the log.

  Nothing is written to the log HERE: the repository is the main thread's. The
  outcome is queued (TNetDelivery) and the main thread is asked to settle it,
  once for however many arrive before it gets there. Until it does, the row
  stays as it was: owing. *)
procedure ReportPacketOutcome(const aKind: string; aTag: Int64; aWritten: boolean);
begin
   if (aKind <> NET_KIND_QSOINFO) and (aKind <> NET_KIND_EDITEDQSO) and
      (aKind <> NET_KIND_OFFLINEQSO) then
      begin
      Exit;
      end;
   if GNetDelivery = nil then
      begin
      Exit;
      end;

   (* A QSO packet that was WRITTEN and carries no tag has no row to mark: the
     restock's OFFLINEQSO (rows already sent) and a QSO with no network key. It
     is not reported, so a push of thousands does not queue thousands of
     outcomes for the main thread to read and discard. A failure is still
     reported, so it is counted and logged. *)
   if aWritten and (aTag = 0) then
      begin
      Exit;
      end;

   if GNetDelivery.Report(aKind, aTag, aWritten) then
      begin
      if (Application <> nil) and (not Application.Terminated) then
         begin
         Application.QueueAsyncCall(GNetDrainer.Settle, 0);
         end;
      end;
end;

(* ON THE WRITER THREAD. The bytes of a packet went to the socket. *)
procedure NetPacketWritten(const aKind: string; const aTag: Int64);
begin
   ReportPacketOutcome(aKind, aTag, True);
end;

(* ON THE WRITER THREAD. A packet's write failed, or the link was already down:
  the packet is gone and its row still owes it. It used to add one to tUSQ right
  here, from the wrong thread; SettleServerProgress counts the rows instead. *)
procedure NetPacketLost(const aKind: string; const aTag: Int64);
begin
   ReportPacketOutcome(aKind, aTag, False);
end;

procedure NetBeginLinkSession;
begin
   GPeers.Clear;
   ForgetPeerContestNotices;
   GSendRefusals.Forget;
   GSpotShareNoted := False;
   FServerHelloSeen := False;
   (* AND NOTHING HAS BEEN CAUGHT UP YET: the QSOs logged while the last link
     was down go once the server's HELLO has come on THIS one. These are the
     main thread's variables, written by the connect thread before the HELLO is
     sent -- nothing can be reading them until the server has answered it. *)
   GResendDue := False;
   GResentThisLink := False;
   GCatchUpDue := False;
   GResentKeys.Clear;
   (* Cardinal(GetTickCount64) -- TRUNCATED DELIBERATELY. qiComputerID is a
     field of TNetQSOInformation, which is a PACKED RECORD SENT BETWEEN
     STATIONS, so its width is on the wire and is not ours to widen. The
     value is only ever used as a distinguishing number. *)
   NetQSOInfoToSend.qiComputerID := Cardinal(GetTickCount64);
end;

function NetDeliveryLedger: TNetDelivery;
begin
   Result := GNetDelivery;
end;

procedure AttachNetClient(aClient: TNetClient);
begin
   aClient.OnData := @NetDataArrived;
   aClient.OnDisconnected := @NetLinkDropped;
   aClient.OnPacketLost := @NetPacketLost;
   aClient.OnPacketWritten := @NetPacketWritten;
end;

procedure NetDisconnect;
begin
  // The WSAAsyncSelect(..., 0, 0) that stood here was cancelling the socket's
  // window notifications before closing it.  There are none to cancel now.
  if NetClient <> nil then
     begin
     NetClient.Disconnect;
     end;
  GNetPending := nil;
  ServerSerialNumber := 0;
  FillChar(MF, SizeOf(MultsFrequencies), 0);
  NetLinkChanged;
//  DisplayMultsFrequencies;
end;

procedure SendStationStatus(ssType: StationStatusType);
var
  callAnsi: AnsiString;   { sstCallsign -- see the byte-exact note below }
  callLen: integer;
  nameAnsi: AnsiString;   { sstComputerNameAndID -- the same boundary }
  nameLen: integer;
begin
//  Exit;
  if not NetIsConnected then Exit;

  MyStationState.ssID := NET_STATIONSTATUS_ID;

  case ssType of
    sstComputerNameAndID:
      begin
        (* A LOCAL ANSI COPY, AND THE LENGTH CLAMPED TO THE FIELD.

          The name is a property now, so there is no length byte to Move
          from -- but the clamp is the half worth keeping. ssName is NINE
          bytes and the old global was a Str10 whose row set no enforced
          maximum, so a ten-character name moved ten bytes over the top of
          ssType, the field that says what this packet IS. *)
        nameAnsi := UTF8Encode(Settings.Computer.Name);
        nameLen := Length(nameAnsi);
        if nameLen > SizeOf(MyStationState.ssName) then
           begin
           nameLen := SizeOf(MyStationState.ssName);
           end;

        FillChar(MyStationState.ssName, SizeOf(MyStationState.ssName), 0);
        if nameLen > 0 then
           begin
           Move(nameAnsi[1], MyStationState.ssName, nameLen);
           end;
        MyStationState.ssComputerID := Settings.Computer.Id;
      end;

    sstBandModeFreq:
      begin
        MyStationState.ssCurrentBand := ActiveBand;
        MyStationState.ssCurrentMode := ActiveMode;
        MyStationState.ssFreq := ActiveRadioPtr^.CurrentStatus.Freq {div 1000};
      end;

    sstPTT, sstOpMode: SetStatusByte;
    {
    sstPTT:
      MyStationState.ssPTTState := tPTTStatus;
      //MyStationState.ssStatusByte := MyStationState.ssStatusByte or (1 shl N);

    sstOpMode:
      MyStationState.ssOpMode := OpMode;
}
    sstQSOs:
      MyStationState.ssQSOTotals := Word(QSOTotals[AllBands, Both] {TotalContacts});

    sstCallsign:
      begin
        SetStatusByte;
        // BYTE-EXACT ON PURPOSE.  ssCallsign is a fixed AnsiChar array in a
        // record sent over the wire to tr4wserver, and this reproduces
        // GetWindowTextA's contract exactly: copy what fits, NUL-terminate,
        // leave the rest of the buffer alone.  Assigning a string here would
        // change a serialised field.
        callAnsi := AnsiString(EntryText(TR4WCallEdit));
        callLen := Length(callAnsi);
        if callLen > SizeOf(MyStationState.ssCallsign) - 1 then
           begin
           callLen := SizeOf(MyStationState.ssCallsign) - 1;
           end;
        if callLen > 0 then
           begin
           Move(callAnsi[1], MyStationState.ssCallsign[0], callLen);
           end;
        MyStationState.ssCallsign[callLen] := #0;
      end;

    sstOperator:
      Move(CurrentOperator, MyStationState.ssOperator, SizeOf(OperatorType));
  end;

  MyStationState.ssType := ssType;

  SendToNet(MyStationState, SizeOf(MyStationState));
end;

procedure SetStatusByte;
begin
  MyStationState.ssStatusByte :=
    STATUS_BYTE_BIT_PTT * Byte(ActiveRadioPtr.tPTTStatus) +
    STATUS_BYTE_BIT_OPMODE * Byte(OpMode) +
    STATUS_BYTE_BIT_DUPE * Byte(tCallWindowStringIsDupe) +
    STATUS_BYTE_BIT_PTT_LOCKOUT * Byte(Settings.Ptt.Lockout);
//    + STATUS_BYTE_BIT_MULT * Byte(tNewMultIndicatorPrevState)
  ;
end;

procedure SendMessageStatus;
var
  MyMessageState                        : TMessageState;
  i                                     : integer;
begin
  if not NetIsConnected then Exit;
  MyMessageState.msComputerId := Settings.Computer.Id;
  MyMessageState.msID := NET_MESSAGESTATE_ID;
  if CWMessageToNetwork <> '' then
     begin
     (* Move, not Windows.MoveMemory -- AND THE FIRST TWO ARGUMENTS SWAP.

       MoveMemory(Destination, Source, Length) is the Win32 order.
       Move(Source, Destination, Count) is Pascal's, and it is the reverse.
       A transliteration that kept the order would compile, run, and copy the
       message BACKWARDS into the wire record -- silently, on the network
       path, where the symptom is a garbled CW message at the other station
       and nothing at all locally.

       They also differ on overlap: MoveMemory handles it (it is RtlMoveMemory)
       and so does Move, so nothing is lost there. *)
     Move(CWMessageToNetwork[1], MyMessageState.msCWMessage[0],
          length(CWMessageToNetwork));
     end;

  MyMessageState.msCWMessage[length(CWMessageToNetwork)] := #0;

  i := CWBufferEnd - CWBufferStart;
  if CWBufferEnd < CWBufferStart then
     begin
     i := i + CWBufferSize;
     end;
  if i < 0 then
     begin
     i := 0;
     end;
  MyMessageState.msCWElements := i;

  SendToNet(MyMessageState, SizeOf(TMessageState));
  if MyMessageState.msCWElements < 1 then
     begin
     StopAppTimer(atNetCWStatus);
     end;
end;

type
  TConnectToTR4WServerLogState = (nclsInitial, nclsTrying, nclsConnected, nclsFailed);

const
  FConnectLogStateLabel : array[TConnectToTR4WServerLogState] of string =
    ('initial', 'trying', 'connected', 'failed');

var
  // Last logged connect-attempt outcome.  TR4W retries every ~5s while the
  // multi-op server is unreachable; without this gate the log would fill
  // with four debug lines per retry (TryConnectToNetwork enter, tCreateThread
  // create, Network thread create, ConnectThread exit) drowning out anything
  // else.  We log only on transitions: first attempt, recover, fail.
  FConnectLogState : TConnectToTR4WServerLogState = nclsInitial;

  // Issue #1041: was THIS connect attempt an announced one (first / after a
  // recovery) rather than a silent retry?  ConnectThread reads it at exit to
  // log its destruction at the same volume as its creation.  No lock needed:
  // NetThreadID gates a single connect thread at a time, so the value set when
  // the thread is created stays put for that thread's whole life.
  FConnectThreadAnnounced : boolean = False;

{ THIS STATION'S ID AS THE WIRE CARRIES IT.

  AN ORDINAL, 1..26 -- NOT THE LETTER, whatever TClientEntry.clID's AnsiChar and
  the server's comments suggest.  NET_STATIONSTATUS_ID carries the same identity
  as the LETTER and converts it back on receipt (uNet.pas:331), so the protocol
  has two encodings of one identity and they must not be confused.

  THROUGH uComputerID, not by repeating the arithmetic.  This conversion now
  happens in three places -- announcing the id, deciding whether the server's
  refusal still applies, and the server judging it -- and the shared one also
  answers #0 for anything that is not 'A'..'Z', which JudgeComputerID then
  refuses as out of range rather than aliasing onto some other station. }
function WireComputerID: AnsiChar;
begin
   Result := ComputerIDOrdinal(Settings.Computer.Id);
end;

procedure TryConnectToNetwork;
var
  announce: boolean;
begin
  (* NOT OVER A LIVE LINK.

    Connect's first act is Disconnect, so calling this while connected does not
    "reconnect" -- it silently kills a working link and builds a new one. The
    network window's timer checks NetIsConnected before calling, but the
    invariant belongs with the routine that owns it rather than with one of its
    callers, and this is the exact failure that was chased on 2026-09-06.
    (The caller is the retry timer, NetLinkTick, since 2026-10-27.) *)
  if NetIsConnected then
     begin
     Exit;
     end;

  { REFUSED, AND NOTHING HAS CHANGED SINCE.  Silent on purpose: the operator has
    already been told once, and repeating it every five seconds would be the
    same defect in a different costume. }
  if (FRefusedComputerID <> #0) and (FRefusedComputerID = WireComputerID) then
     begin
     Exit;
     end;
  FRefusedComputerID := #0;

  { THE SERVER WAS REFUSED (its protocol, or no answer to HELLO) and the
    operator has been told. The same silence as above. }
  if FServerRefusedFor = ServerKey then
     begin
     Exit;
     end;

  // Issue #1041: log the "trying" line only on a GENUINE new attempt -- the
  // first one (nclsInitial) or after we'd been connected and dropped
  // (nclsConnected).  The old condition (<> nclsTrying) re-fired here every
  // retry because after a failure the state is nclsFailed; that, paired with
  // the fail handler flipping it back to nclsFailed, made the "trying" debug
  // and the "failed" warn ping-pong every 5s instead of going silent.  While
  // we are in the silent retry phase (nclsFailed) we must NOT relabel the
  // state, so neither line repeats until something actually changes.
  announce := FConnectLogState in [nclsInitial, nclsConnected];
  if announce then
     begin
     logger.Debug('TryConnectToNetwork -> %s:%d  (will retry every 5s while server is unreachable; further attempts logged only on state change)', [Settings.Server.Address, Settings.Server.Port]);
     FConnectLogState := nclsTrying;
     end;
  if not ThreadStarted(NetThreadID) then
     begin
     FConnectThreadAnnounced := announce;
     tCreateThread(ConnectThread, NetThreadID, not announce {Quiet on silent retries});
     NetLinkChanged;
     end;
end;

{ CONNECT AND SHAKE HANDS, reporting the password case the way the dialog did.

  Returns False for every failure; the caller shows TC_FAILEDTOCONNECTTO, which
  is what it did before. }
var
   (* THE SERVER NAME THAT COULD NOT BE RESOLVED, as the Error line has already
     named it, under GNetLock (the connect thread sets it, ForgetServerRefusal
     on the main thread clears it). The retry timer comes back every few
     seconds: the first failure of a name is an Error, the rest are Debug. *)
   FResolveFailedFor: string = '';

(* RESOLVE THE SERVER'S NAME through the platform (uHostResolve; Windows is
  unchanged). Runs on the CONNECT THREAD, never the main thread: the C library
  can block for seconds. False names the host in the log and leaves the link
  down, so the status line says "failed", never "connected". *)
function ResolveServerAddress(out aAddress: string): boolean;
var
   why:   string;
   first: boolean;
begin
   Result := TryResolveHost(Settings.Server.Address, aAddress, why);

   GNetLock.Acquire;
   try
      if Result then
         begin
         FResolveFailedFor := '';
         first := False;
         end
      else
         begin
         first := FResolveFailedFor <> Settings.Server.Address;
         FResolveFailedFor := Settings.Server.Address;
         end;
   finally
      GNetLock.Release;
   end;

   if not Result then
      begin
      if first then
         begin
         logger.Error('[Net] %s', [why]);
         end
      else
         begin
         logger.Debug('[Net] %s', [why]);
         end;
      end;
end;

function ConnectToTR4WServer: boolean;
var
   err: string;
   wrongPassword: boolean;
   serverAddress: string;
begin
   if NetClient = nil then
      begin
      NetClient := TNetClient.Create;
      AttachNetClient(NetClient);
      end;

   (* A name the platform cannot resolve is a failed attempt, and the Error line
     above has named it. Indy is handed the ADDRESS this returns; the log lines
     that follow still print Settings.Server.Address, the name as typed. *)
   if not ResolveServerAddress(serverAddress) then
      begin
      Result := False;
      Exit;
      end;

   Result := NetClient.Connect(serverAddress, Settings.Server.Port,
                               AnsiString(Settings.Server.Password),
                               err, wrongPassword);
   if Result then
      begin
      Exit;
      end;

   if wrongPassword then
      begin
      showwarning(TC_CONNECTTOTR4WSERVERFAILED);
      end
   else
      begin
      logger.Debug('[Net] connect to %s:%d failed: %s',
                   [Settings.Server.Address, Settings.Server.Port, err]);
      end;
end;

function ConnectThread(aParameter: Pointer): DWORD; stdcall;
label
  1, 2;
var
  i                                     : integer;
begin
  Result := 0;   (* the thread exit code -- see TF.TTR4WThreadStart *)
  DifferentContests := False;
  ShowConnectionStatus(TC_CONNECTINGTO);

  if ConnectToTR4WServer then
{
  TempSocket := GetSocket; // socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  tr4w_saddr.sin_addr.S_addr := inet_addr(tgethostbyname(PAnsiChar(AnsiString(Settings.Server.Address))));
  tr4w_saddr.sin_port := htons(Settings.Server.Port);

  if TempSocket = INVALID_SOCKET then goto 2;
  i := tConnect(TempSocket, @tr4w_saddr);
  //I := WinSock2.WSAConnect(TempSocket, @tr4w_saddr, SizeOf(sockaddr_in), @<the password>, nil, nil, nil);
  if i = 0 then
}
     begin
     // The socket, the ten-byte password, the four-byte acknowledgement, the
     // Sleep(200) waiting for it, TCP_NODELAY and the WSAAsyncSelect that made
     // the network WINDOW the socket's event sink -- all of that is TNetClient's
     // now, and the handshake happens inside Connect because a link the server
     // has not acknowledged is not a link.
     FillChar(StatusArray, SizeOf(StatusArray), 0);
     (* A NEW LINK IS A NEW SESSION (Q110, protocol 2): nobody has announced
       anything yet, and the server has not answered. Before the HELLO goes
       out, so nothing it provokes can arrive into the old state. *)
     NetBeginLinkSession;

     (* HELLO FIRST. It carries the computer id that COMPUTERID used to (the
       server judges it the same way) and the server refuses a link whose first
       message is anything else. An id that cannot be sent whole ends the
       attempt rather than going out truncated. *)
     if not SendHello then
        begin
        NetDisconnect;
        ShowConnectionStatus(TC_FAILEDTOCONNECTTO);
        end
     else
        begin
        SendFullStationStatus;
        SendClientStatus;
        ServerMessage.smMessage := SM_GETSTATUS_MESSAGE;
        SendToNet(ServerMessage, SizeOf(ServerMessage));
 //     SendStationStatus;
        ShowConnectionStatus(TC_CONNECTEDTO);
        if FConnectLogState <> nclsConnected then
           begin
           logger.Info('Connected to TR4WServer at %s:%d', [Settings.Server.Address, Settings.Server.Port]);
           FConnectLogState := nclsConnected;
           end;
        end;
     end
  else
     begin
     1:
     ShowConnectionStatus(TC_FAILEDTOCONNECTTO);
     NetDisconnect;
     if FConnectLogState <> nclsFailed then
        begin
        logger.Warn('Failed to connect to TR4WServer at %s:%d (will keep retrying silently)', [Settings.Server.Address, Settings.Server.Port]);
        FConnectLogState := nclsFailed;
        end;
     end;
  2:
  (* THE OPERATOR ASKED FOR DISCONNECT WHILE THIS ATTEMPT WAS IN FLIGHT.
    NetLinkDisconnect cannot close a link whose thread is still building it, so
    it clears the wish and leaves this to notice. A link that came up anyway is
    dropped here, and the retry timer is already stopped. *)
  if (not NetLinkWanted) and NetIsConnected then
     begin
     NetDisconnect;
     ShowConnectionStatus(TC_DISCONNECTEDFROM);
     end;
  // Issue #1041: log destruction at the same volume as creation -- debug on a
  // genuine (announced) attempt so create/destroy pair up in the log, trace
  // during the silent retry loop so it stays quiet.
  if FConnectThreadAnnounced then
     begin
     logger.Debug('[ConnectThread] Thread %u destroyed, NetThreadID cleared', [PtrUInt(GetCurrentThreadId)])
     end
  else
     begin
     logger.Trace('[ConnectThread] Thread %u exiting, NetThreadID cleared', [PtrUInt(GetCurrentThreadId)]);
     end;
  ClearThread(NetThreadID);
  (* AFTER the thread id is cleared: the state is "connecting" while it is set,
    so the change that ends an attempt must be announced once it is not. *)
  NetLinkChanged;
end;

{ ONE CELL OF THE STATION LIST.

  Was tLVSetText(h, row, col, text) against the Win32 list view's handle, with
  `h := wh[mweNetwork]` fetched at the top of DisplayClientStatus.  The list is
  a TListView on uNetworkForm now; the row and column arithmetic above is
  untouched.

  Silently does nothing when the window is closed, which is exactly what
  tLVSetText did against a zero handle. }
procedure SetClientCell(const aRow, aCol: integer; const aText: string);
begin
  if TR4WNetworkForm <> nil then
     begin
     TR4WNetworkForm.SetCell(aRow, aCol, aText);
     end;
end;

(* ONE FIELD OF ONE STATION'S ROW, chosen by the status type it came from.

  This was the body of DisplayClientStatus, which always drew the field named by
  the LAST message's own type. Drawing a whole row (a window opened mid-session)
  needs every type, so the type is a parameter and the two callers differ only in
  which they pass. *)
procedure DisplayClientField(Index: integer; aType: StationStatusType);
var
  i, i2                                 : integer;
//  p                                     : PChar;
  TempBuffer                            : array[0..31] of AnsiChar;
const
  da                                    : array[boolean] of string = ('', 'D');
begin
  i := PosInClientsList[Index] - 1;
  CurrentDisplayedRow := Index;

  if StatusArray[Index].ssComputerID = #0 then
     begin
     (* EVERY COLUMN, not the first eight: the D flag and the operator sit in
       columns 8 and 9 and a station that left kept them. *)
     for i2 := 0 to NetColumns - 1 do
        begin
        SetClientCell(i, i2, '');
        end;
     Exit;
     end;

  //LastStatus := StatusArray[Index].ssType;
  case aType of

    sstComputerNameAndID:
      begin
        SetClientCell(i, 0, string(StatusArray[Index].ssName));
        SetClientCell(i, 1, CharBufferText([StatusArray[Index].ssComputerID]));
      end;
    sstBandModeFreq:
      begin

//        p := FreqToPCharWithoutHZ(StatusArray[Index].ssFreq);
//        asm push p end;
//        I2 := StatusArray[Index].ssFreq div 1000;
//        asm push i2 end;
{
        p := ModeString[StatusArray[Index].ssCurrentMode];
        asm push p end;

        p := BandStringsArrayWithOutSpaces[StatusArray[Index].ssCurrentBand];
        asm push p end;
}
        (* CONCATENATION, not TF.Format into a buffer and a cast back out.
          Both tables are string arrays now, and this was two PChar arguments
          to a wsprintfA shim whose result was read back through
          PAnsiChar(@TempBuffer). *)
        SetClientCell(i, 2,
           BandStringsArrayWithOutSpaces[StatusArray[Index].ssCurrentBand]
           + ModeStringArray[StatusArray[Index].ssCurrentMode]);

        // D12: FreqToPChar returns native string; flows straight through tLVSetText
        // (this replaced an earlier PAnsiChar(WinAnsi(...)) LV_ITEMA hack).
        SetClientCell(i, 3, FreqToPChar{WithoutHZ}(StatusArray[Index].ssFreq));        // 4.61.7
{
        ListView_SetItemText(h, i, 2, BandStringsArray[StatusArray[Index].ssCurrentBand]);
        ListView_SetItemText(h, i, 3, ModeString[StatusArray[Index].ssCurrentMode]);
        ListView_SetItemText(h, i, 4, FreqToPCharWithoutHZ(StatusArray[Index].ssFreq));
}
      end;

    sstPTT:
      begin
        SetClientCell(i, 6 - 1, PTTStatusString[PTTStatusType((StatusArray[Index].ssStatusByte and (1 shl 0)) <> 0)]);
        (* A TListView repaints an item when its text changes; this forced
          a repaint on a Win32 handle that is always 0. *)
      end;

    sstOpMode:
      SetClientCell(i, 5 - 1, OpModeString[OpModeType((StatusArray[Index].ssStatusByte and (1 shl 1)) <> 0)]);

    sstQSOs:
      SetClientCell(i, 7 - 1, IntToStr(StatusArray[Index].ssQSOTotals));

    sstCallsign:
      begin
        SetClientCell(i, 8 - 1, string(StatusArray[Index].ssCallsign));
        SetClientCell(i, 9 - 1, da[(StatusArray[Index].ssStatusByte and (1 shl 2)) <> 0]);
      end;

    sstOperator:
      SetClientCell(i, 9, string(StatusArray[Index].ssOperator));
  end;

end;

procedure DisplayClientStatus(Index: integer);
begin
  DisplayClientField(Index, StatusArray[Index].ssType);
end;

procedure DisplayAllClients;
var
   id: integer;
   kind: StationStatusType;
begin
   for id := Low(StatusArray) to High(StatusArray) do
      begin
      (* A STATION THAT HAS A ROW. PosInClientsList is set the first time a
        station is heard and never cleared, so a row that has been blanked
        (the station left) is blanked again rather than skipped. *)
      if PosInClientsList[id] > 0 then
         begin
         for kind := Low(StationStatusType) to High(StationStatusType) do
            begin
            DisplayClientField(id, kind);
            end;
         end;
      end;
end;

function FindAndUpdateQSOInLog(var RXData: ContestExchange): boolean;
label
  1, 2;
var
  FilePointer                           : integer;
begin
  Result := False;
  FilePointer := -1;

  (* ONE INDEXED STATEMENT INSTEAD OF A BACKWARDS SCAN OF THE WHOLE LOG.

     This walked the .TRW from the end, one record at a time, comparing
     (ceQSOID1, ceQSOID2) until it found the QSO -- then seeked back and
     rewrote it in place. The search and the write are a single UPDATE ...
     WHERE on that pair. (This said "the database has an index on exactly that
     pair" until 2026-10-27, and it has none: the statement reads the table,
     about 2 ms for 12,000 rows, measured. Cheap enough not to add one.)

     The scan and its FilePointer are gone with the binary log. FilePointer is
     kept only because the surrounding routine still reports it. *)
  if not LogSourceOpen then Exit;
  begin
    Result := LogStoreUpdateQSOBySessionIds(RXData);
    CloseLogFile;
  end;
end;

(* EnableNetworkMenuItem IS GONE (2026-10-27). It greyed the WHOLE Net menu, by
  position, whenever there was no link - which would now hide the very commands
  that make one. The Net menu is always available; ApplyNetworkMenuState enables
  each row by the link's state. *)

procedure ProcessServerLogInfo(s: PLogFileInformation);
var
  Records                               : Int64;
begin
  (* THE SERVER'S LOG-COMPARE PACKET IS READ FOR ONE NUMBER AND ACTED ON FOR
     NONE (Phase 1, C6, 2026-10-27).

     HOW IT WORKED IN D7: both ends CRC32'd THE RAW BYTES OF THEIR OWN .TRW and
     compared the two numbers; a difference meant "ask the operator" or, with
     SERVER AUTO SYNCHRONIZE LOG ON CONNECT, "replace the log by the server's".
     This station keeps no .TRW (the log is SQLite), the server still does, and
     a REPLACE would destroy every QSO only this station holds. Neither half
     survives.

     WHAT REPLACED IT is not a better comparison but no comparison: the station
     fetches the server's log whenever the link comes up (NetServiceCatchUp) and
     adds the QSOs it lacks, insert only (uNetCatchUp, uGetServerLog). The fetch
     IS the comparison, and the answer is a count of missing QSOs, which no CRC
     could give.

     So this arm only notes what the server says it holds, once per link, in the
     log: that makes a catch-up that found nothing readable against a log the
     server called empty (or the reverse) something a person can see. The size
     counts the server's header record. The fields of the packet this station
     used to fill in are not read by anything and are not written. *)
  Records := 0;
  if s^.liServerLogSize > SizeOfTLogHeader then
     begin
     Records := (Int64(s^.liServerLogSize) - SizeOfTLogHeader) div SizeOf(ContestExchange);
     end;
  logger.Info('[Net] the server says its log holds %d record(s) (%d bytes)',
              [Records, s^.liServerLogSize]);
end;

(* THE ROW IS CREATED WHEN IT IS FIRST WRITTEN, not here.

  This inserted an item into wh[mweNetwork] -- a handle that is never assigned,
  because the station list is a TListView on uNetworkForm now. The insert has
  therefore been doing nothing, and nothing was lost by it: SetCell adds rows on
  demand, precisely because a status can arrive for a station before anything
  has drawn it. *)
procedure AddNewClient(ClientID: integer);
begin
  inc(TotalClients);
  PosInClientsList[ClientID] := TotalClients;
end;

(* THE NETWORK WINDOW'S TITLE, AS A CAPTION AND AN RTL FORMAT.

  Two Win32 habits in two lines. The window is TR4WNetworkForm now, so its
  title is a property -- writing it through tr4w_WindowsArray[].WndHandle only
  worked while that cached handle stayed valid, which is how the MAIN window's
  title came to go blank when its form was recreated.

  And TF.Format is a wsprintf shim: it took the resourcestring as a PAnsiChar,
  every argument as a PAnsiChar, and wrote into a fixed buffer. SysUtils.Format
  takes the string and an array of const, so TC_NETWORK ('Network : %s %s:%d')
  is passed as itself, the server address converts from its ShortString on
  the way in, and the port goes as an integer rather than being pushed as
  bytes. No
  buffer, no WinAnsi round trip, no pointer into a ShortString's first byte. *)
procedure ShowConnectionStatus(Operation: string);
begin
  (* THE LAST STATUS LINE IS KEPT, and the Network window is TOLD rather than
    written to. This used to set TR4WNetworkForm.Caption here, and ConnectThread
    calls this from a WORKER: an LCL control written off the main thread. The
    window follows the link through NetLinkObservers instead, asks
    NetWindowCaption for the title, and gets the right one when it opens
    mid-session as well. *)
  GNetLock.Acquire;
  try
     GLinkOperation := Operation;
  finally
     GNetLock.Release;
  end;
  NetLinkChanged;

  (* AND THE MAIN WINDOW'S NETWORK STATUS PANEL, FROM THE SAME ONE PLACE.

    THE POINT OF PUTTING IT HERE IS THAT THERE IS NOTHING TO KEEP IN STEP.  All
    four transitions -- connecting, connected, failed, disconnected -- already
    come through this routine, so the panel cannot be left holding a state the
    network window has moved on from.  The network window's CAPTION is only
    visible while that window is open, which is why the same fact is worth a
    panel: a multi-op operator works with it closed.

    Posted rather than assigned: ConnectThread runs this off the main thread.

    AND THE PANEL DOES NOT GET THE WINDOW'S TITLE.  TC_NETWORK is 'Network : %s %s:%d' and
    the %s is the server address, which has no bounded length -- the caption of
    a window the operator sized can carry that; a panel a quarter of the main
    window wide cannot.  NY4I, 2026-09-26: state it generically and let the
    operator open the network window for the particulars.

    SO THE PANEL NAMES THE SUBSYSTEM, NOT A GENERIC NOUN.  It said "server" for
    a day and NY4I reported the cost, 2026-09-27: "'Connected to host' is not
    specific enough. What host? Do you mean connected to DX Cluster? Connected
    to radio host (via IP)?"  The panels carry no labels, so a word that names
    no subsystem names nothing.

    THE NAME COMES FROM uPanelUpdate.StatusSubsystemName, WHICH THE CLUSTER
    PANEL ALSO ASKS -- one statement of the rule rather than two that can
    drift.  For this owner it answers RC_NETWORK, AND THAT IS NOT TC_NETWORK:
    TC_NETWORK is the FORMAT two statements above and cannot be concatenated;
    RC_NETWORK is the plain 'Network' the Windows menu already labels this
    window with, translated in every catalogue.  Same Operation prefix as that
    caption, so the two surfaces still cannot word the transition differently
    -- and the caption still carries the address, which is the detail view this
    panel points at. *)
  PostStatusText(stoNetwork, Operation + StatusSubsystemName(stoNetwork));
end;

function NetWindowCaption: string;
var
   operation: string;
begin
   GNetLock.Acquire;
   try
      operation := GLinkOperation;
   finally
      GNetLock.Release;
   end;

   (* NOTHING HAS BEEN REPORTED YET: no attempt has been made this session, so
     the honest title is the one for a link that is not there. *)
   if operation = '' then
      begin
      operation := TC_DISCONNECTEDFROM;
      end;

   Result := Format(TC_NETWORK,
                    [operation, Settings.Server.Address, Settings.Server.Port]);
end;

(* ------------------------------------------------------- THE LINK'S OWNER *)

function NetLinkWanted: boolean;
begin
   Result := GLinkWanted;
end;

function NetLinkRefused: boolean;
begin
   Result := (FServerRefusedFor = ServerKey) or
             ((FRefusedComputerID <> #0) and (FRefusedComputerID = WireComputerID));
end;

function NetLinkState: TNetLinkState;
begin
   Result := ResolveLinkState(GLinkWanted, NetIsConnected,
                              ThreadStarted(NetThreadID), NetLinkRefused);
end;

procedure ApplyNetworkMenuState;
begin
   ApplyNetworkMenuStateFor(NetLinkState);
end;

procedure ApplyNetworkMenuStateFor(const aState: TNetLinkState);
const
   (* THE ROWS THAT SEND SOMETHING TO THE OTHER STATIONS. *)
   NEEDS_A_LIVE_LINK: array[0..5] of word = (
      menu_alt_setnettime, menu_send_message, menu_getserverlog,
      menu_clearserverlog, menu_clear_dupesheet_in_network,
      menu_clear_multsheet_in_network);
var
   i: integer;

   procedure SetRow(const aId: word; const aEnabled: boolean);
   var
      item: TMenuItem;
   begin
      item := MenuItemById(aId);
      if item <> nil then
         begin
         item.Enabled := aEnabled;
         end;
   end;

begin
   SetRow(menu_net_connect,    LinkCommandEnabled(aState, nlcConnect));
   SetRow(menu_net_disconnect, LinkCommandEnabled(aState, nlcDisconnect));
   SetRow(menu_net_reconnect,  LinkCommandEnabled(aState, nlcReconnect));
   SetRow(menu_net_showwindow, LinkCommandEnabled(aState, nlcShowWindow));
   for i := Low(NEEDS_A_LIVE_LINK) to High(NEEDS_A_LIVE_LINK) do
      begin
      SetRow(NEEDS_A_LIVE_LINK[i], LinkNeedsLiveLink(aState));
      end;
end;

procedure NetLinkWentDown;
var
   i: integer;
begin
   NetDisconnect;
   FillChar(StatusArray, SizeOf(StatusArray), 0);
   for i := 1 to 26 do
      begin
      DisplayClientStatus(i);
      end;
   ShowConnectionStatus(TC_DISCONNECTEDFROM);
end;

procedure NetLinkTick;
begin
   (* THE RETRY, FOR AS LONG AS A LINK IS WANTED. TryConnectToNetwork refuses on
     its own while connected, while a refusal stands, and while an attempt is
     already running, so this needs no state of its own. *)
   if GLinkWanted and (not NetIsConnected) then
      begin
      TryConnectToNetwork;
      end;
end;

procedure NetLinkConnect;
begin
   (* NO LEGAL COMPUTER ID, NO LINK. The whole protocol indexes stations by that
     letter and the server refuses a link without one, so asking would only
     produce a refusal. Say what to change instead - the route the Network
     window's old open-gate took. *)
   if not (Settings.Computer.Id in ['A'..'Z']) then
      begin
      SetCommand('COMPUTER ID');
      Exit;
      end;

   GLinkWanted := True;
   ForgetServerRefusal;
   StartAppTimer(atNetReconnect, Settings.Network.StatusUpdateInterval, @NetLinkTick);
   if not NetIsConnected then
      begin
      TryConnectToNetwork;
      end;
   NetLinkChanged;
end;

procedure NetLinkDisconnect;
begin
   GLinkWanted := False;
   StopAppTimer(atNetReconnect);

   (* A CONNECT THAT IS STILL BEING BUILT IS NOT CLOSED FROM HERE: the client is
     the connect thread's until it returns. Clearing the wish is enough, because
     the thread looks at it before it ends and drops a link nobody wants. *)
   if ThreadStarted(NetThreadID) then
      begin
      NetLinkChanged;
      Exit;
      end;

   NetLinkWentDown;
end;

procedure NetLinkReconnect;
begin
   if ThreadStarted(NetThreadID) then
      begin
      Exit;
      end;

   NetLinkWentDown;
   NetLinkConnect;
end;

procedure NetLinkShutdown;
begin
   GLinkWanted := False;
   StopAppTimer(atNetReconnect);
   if ThreadStarted(NetThreadID) then
      begin
      logger.Info('[Net] exiting while a connect is in flight; the link is left to the process end');
      Exit;
      end;

   if NetIsConnected then
      begin
      logger.Info('[Net] leaving the network');
      end;
   NetDisconnect;
   (* THE DRAIN THAT NetDisconnect GIVES THE WRITER IS WHEN THE LAST QSOS GO, and
     the main thread's settle is queued behind this very call, so it would never
     run: the program is exiting. Record what became of them now, while the log
     is still open. Whatever it misses is sent again next time and ignored by
     whoever already has it. *)
   SettleServerProgress;
end;

procedure NetLinkStartup;
begin
   if ShouldConnectAtStartup(Settings.Network.AutoConnect, Settings.Computer.Id) then
      begin
      logger.Info('[Net] connecting to %s:%d at startup (NETWORK AUTO CONNECT)',
                  [Settings.Server.Address, Settings.Server.Port]);
      NetLinkConnect;
      Exit;
      end;

   logger.Info('[Net] not connecting at startup (NETWORK AUTO CONNECT is %s, ' +
               'COMPUTER ID is "%s"); Connect on the Net menu does it',
               [BoolToStr(Settings.Network.AutoConnect, 'on', 'off'),
                string(Settings.Computer.Id)]);
   ApplyNetworkMenuState;
end;

procedure DisplayMessageStatus(Index: integer; Msg: TMessageState);
const
  PROGRESS_BAR_MAX_CHARS                = 25;
var
  i                                     : integer;
  ProgressBarPos                        : integer;
begin
  (* THE CW PROGRESS, AS TEXT: one '|' for every six CW elements sent, capped
    at 25. This was a 26-byte buffer filled with '|', cut short by writing a
    NUL at the position, and read back through a PAnsiChar. StringOfChar is
    that string, with no buffer and no pointer.

    NOTE FOR THE LARGER JOB (ROADMAP §5): this is not a control. It is
    characters of '|' written into a station-list CELL, so the "progress
    bar" an operator sees in the multi-op list is TEXT. That is one of the three
    unrelated things called a progress bar here, and the reason NY4I wants them
    unified on one component. *)
  ProgressBarPos := Msg.msCWElements div 6;
  if ProgressBarPos > PROGRESS_BAR_MAX_CHARS then
     begin
     ProgressBarPos := PROGRESS_BAR_MAX_CHARS;
     end;
  i := PosInClientsList[Index] - 1;
  SetClientCell(i, 10, StringOfChar('|', ProgressBarPos));
  SetClientCell(i, 11, string(Msg.msCWMessage));
end;

procedure SendParameterToNetwork(const aCommand, aValue: string);
begin
   if not NetIsConnected then
      begin
      Exit;
      end;

   (* ZEROED, because both fields are ShortStrings inside a record that goes
     out as BYTES: a shorter value written over a longer one would otherwise
     leave the previous tail on the wire.  D7 zeroed them for the same
     reason. *)
   FillChar(ParameterToNetwork.pnCommand, SizeOf(ParameterToNetwork.pnCommand), 0);
   FillChar(ParameterToNetwork.pnValue, SizeOf(ParameterToNetwork.pnValue), 0);

   ParameterToNetwork.pnID      := NET_PARAMETER_ID;
   ParameterToNetwork.pnCommand := ShortString(AnsiString(aCommand));
   ParameterToNetwork.pnValue   := ShortString(AnsiString(aValue));

   SendToNet(ParameterToNetwork, SizeOf(ParameterToNetwork));

   if logger <> nil then
      begin
      logger.Debug('[Net] sent "%s" = "%s" to the other positions',
                   [aCommand, aValue]);
      end;
end;

procedure SendDXSpotToNet(const aSpot: TSpotRecord);
var
   packet: TNetDXSpot;
begin
   if not NetIsConnected then
      begin
      Exit;
      end;

   (* A LOCAL, built whole: there is no earlier value for a tail to survive in,
     and no global whose id someone has to remember to set. *)
   packet := Default(TNetDXSpot);
   packet.dsID := NET_NETWORKDXSPOT_ID;
   packet.dsSpot := aSpot;
   SendToNet(packet, SizeOf(packet));
end;

procedure SendTimeSyncToNet;
var
   packet: TNetTimeSync;
begin
   if not NetIsConnected then
      begin
      Exit;
      end;

   packet := Default(TNetTimeSync);
   packet.tsID := NET_TIMESYN_ID;
   (* WHAT GOES ON THE WIRE IS UNCHANGED: tsTime is the raw bytes of a packed
     record, UTC, and the receiving arm range-checks it before it sets a clock.
     See TF.FillSystemTimeUTC. *)
   TF.FillSystemTimeUTC(packet.tsTime);
   SendToNet(packet, SizeOf(packet));
end;

procedure SendIntercomToNet(const aText: string);
var
   packet: TIntercomMessage;
begin
   if (aText = '') or (not NetIsConnected) then
      begin
      Exit;
      end;

   (* imMessage is a ShortString inside a record sent as bytes: a fresh record
     leaves no tail of an earlier, longer message behind, and the assignment
     truncates at 80. *)
   packet := Default(TIntercomMessage);
   packet.imID := NET_INTERCOMMESSAGE_ID;
   packet.imSender := Settings.Computer.Id;
   packet.imMessage := ShortString(AnsiString(aText));
   SendToNet(packet, SizeOf(packet));
end;

procedure SendSpotViaNetworkToNet(const aSpotText: string);
var
   packet: TSendSpotViaNetwork;
   text: AnsiString;
   i: integer;
begin
   if (aSpotText = '') or (not NetIsConnected) then
      begin
      Exit;
      end;

   (* vnMessage is a FIXED 46-byte array: the record starts zeroed, and the copy
     stops one short of the end so the terminator survives. *)
   packet := Default(TSendSpotViaNetwork);
   packet.vnID := NET_SPOTVIANETWORK_ID;
   text := AnsiString(aSpotText);
   for i := 1 to Length(text) do
      begin
      if i > SizeOf(packet.vnMessage) - 1 then
         begin
         Break;
         end;
      packet.vnMessage[i - 1] := text[i];
      end;
   SendToNet(packet, SizeOf(packet));
end;

function NetSendRefusalsReported: integer;
begin
   Result := GSendRefusals.Count;
end;

(* WHAT A PACKET IS CALLED IN THE LOG.  Every record of this protocol opens
  with a Word id (VC: NET_*_ID); the one exception, NET_LOGINFO_MESSAGE, is a
  DWORD whose low word is not an id and falls through to the hex form. *)
function NetPacketKind(var buf; Len: integer): string;
var
   id: Word;
begin
   Result := 'packet';
   if Len < SizeOf(Word) then
      begin
      Exit;
      end;
   id := Word(buf);
   case id of
      NET_MESSAGESTATE_ID:       Result := 'MESSAGESTATE';
      NET_LOGCOMPARE_ID:         Result := 'LOGCOMPARE';
      NET_INTERCOMMESSAGE_ID:    Result := 'INTERCOM';
      NET_NETWORKDXSPOT_ID:      Result := 'DXSPOT';
      NET_QSOINFO_ID:            Result := KIND_QSOINFO;
      NET_EDITEDQSO_ID:          Result := NET_KIND_EDITEDQSO;
      NET_OFFLINEQSO_ID:         Result := NET_KIND_OFFLINEQSO;
      NET_THIS_QTC_WAS__SEND_ID: Result := 'QTCSENT';
      NET_TAKESERVERQSO_ID:      Result := 'TAKESERVERQSO';
      NET_TIMESYN_ID:            Result := 'TIMESYNC';
      NET_PARAMETER_ID:          Result := 'PARAMETER';
      NET_STATIONSTATUS_ID:      Result := 'STATIONSTATUS';
      NET_CLIENTSTATUS_ID:       Result := 'CLIENTSTATUS';
      NET_SPOTVIANETWORK_ID:     Result := 'SPOTVIANETWORK';
      NET_COMPUTERID_ID:         Result := 'COMPUTERID';
      NET_SERVERMESSAGE_ID:      Result := 'SERVERMESSAGE';
   else
      Result := SysUtils.Format('packet $%.4x', [id]);
   end;
end;

(* POSTS, DOES NOT WRITE.  The packet bytes are copied here, on the caller's
  thread, and a single writer thread sends them in order (uNetSendQueue). The
  result is the count POSTED -- 0 when there is no link -- so a caller that
  compared it with the record size still reads "accepted"; a write that fails
  later is reported through NetPacketLost (and a good one through
  NetPacketWritten, with aTag). *)
function SendToNet(var buf; Len: integer; aTag: Int64 = 0): integer;
var
   id: Word;
begin
   Result := 0;
   if not NetIsConnected then
      begin
      Exit;
      end;

   (* THE GUARD (2026-10-27). This is the only caller of NetClient.Send, so it is
     the one place every packet passes. A packet whose first Word is not an id
     the framing table knows, or whose length is not that message's size, is
     REFUSED: nothing is posted, the result is 0, and the first time each
     distinct (id, length) is seen on a link an Error names it.

     Why a refusal and not a pass-through: such a packet makes the server lose
     the stream and drop the connection, and the reconnect then resends and
     catches up, so one bad packet becomes a link that flaps once per send. That
     is how every DX spot, time sync and intercom line behaved from 2026-08-25
     (id 0, the right size). No caller sends a raw non-protocol buffer; the only
     one that existed, LogNet.SendMultiMessage (K1EA network text), has no live
     caller. There is deliberately no bypass. *)
   id := 0;
   if Len >= SizeOf(Word) then
      begin
      id := Word(buf);
      end;

   if not OutboundPacketIsWellFormed(id, Len) then
      begin
      if GSendRefusals.FirstSighting(id, Len) and (logger <> nil) then
         begin
         logger.Error('[Net] REFUSED to send a malformed packet: id %d ($%.4x), ' +
                      '%d bytes (that id''s record is %d bytes; 0 = not a known ' +
                      'id). Nothing was sent. A record sent with its id word ' +
                      'unassigned looks exactly like this.',
                      [id, id, Len, NetMessageSize(id)]);
         end;
      Exit;
      end;

   Result := NetClient.Send(NetPacketKind(buf, Len), buf, Len, aTag);
end;

function NetIsConnected: boolean;
begin
  Result := (NetClient <> nil) and NetClient.IsConnected;
end;

procedure NetContestChanged;
begin
   if not NetIsConnected then
      begin
      Exit;
      end;

   (* NOTHING IS REFUSED ANY MORE (protocol 2): every contest travels this
     link. The others only need to be told which one this station is on now,
     because they judge each QSO by what its sender last announced. *)
   SendHello;
end;

function SendHello: boolean;
var
   hello: THelloMessage;
begin
   Result := BuildHello(NET_PROTOCOL_VERSION, Ord(WireComputerID),
                        TR4W_CURRENTVERSION_NUMBER, ContestId(Contest), hello);
   if not Result then
      begin
      (* AN ID THAT DOES NOT FIT IS NOT TRUNCATED: a truncated id names another
        contest. Nothing is sent, and the link is not used. *)
      logger.Error('[Net] cannot announce contest "%s": it does not fit the ' +
                   'HELLO message (%d characters of printable ASCII at most)',
                   [ContestId(Contest), HELLO_CONTEST_CHARS]);
      Exit;
      end;

   FHelloSentTick := GetTickCount64;
   SendToNet(hello, SizeOf(hello));
   logger.Debug('[Net] sent hello: protocol %d, contest "%s", computer id %d',
                [hello.hmProtocol, ContestId(Contest), hello.hmComputerID]);
end;

function NetPeers: TNetPeers;
begin
   Result := GPeers;
end;

procedure ForgetServerRefusal;
begin
   FServerRefusedFor := '';
   FRefusedComputerID := #0;
   GNetLock.Acquire;
   try
      FResolveFailedFor := '';   (* the operator asked again: name it again *)
   finally
      GNetLock.Release;
   end;
end;

var
   FPeerContestNotices: integer;

function PeerRecordInOurContest(var aRec: ContestExchange; const aSender: integer;
                                const aDoor: string): boolean;
var
   peer, ours, theirs, theirsName, notice: string;
   theirHandle: TContestHandle;
   verdict: TPeerContestVerdict;
begin
   Result := False;

   if (aSender >= FIRST_COMPUTER_ID) and (aSender <= LAST_COMPUTER_ID) then
      begin
      peer := string(ComputerIDLetter(AnsiChar(aSender)));
      end
   else
      begin
      peer := '?';
      end;

   ours := ContestId(Contest);
   verdict := JudgePeerContest(GPeers, aSender, ours);

   if verdict = pcSame then
      begin
      (* THE SENDER'S BYTE IS NEVER READ. A contest registered by id has a byte
        that differs between builds, so the record is stamped with THIS
        station's own handle before anything stores or scores it. *)
      aRec.ceContest := Contest;
      Result := True;
      Exit;
      end;

   if verdict = pcNoHello then
      begin
      if logger <> nil then
         begin
         logger.Error('[Net] %s from station %s REFUSED: that station has ' +
                      'not announced a contest (no HELLO from it), so there ' +
                      'is nothing to say it is on "%s" (call %s).',
                      [aDoor, peer, ours, string(aRec.Callsign)]);
         end;
      Exit;
      end;

   (* EVERY RECORD IS LOGGED, ONCE PER LINK IS SHOWN. The log line is the only
     record of which QSOs were dropped, so it is not rate-limited; the screen
     is, because a peer logging a QSO a minute would otherwise bury every other
     notice for the length of the contest. *)
   theirs := GPeers.ContestIdOf(aSender);
   if logger <> nil then
      begin
      logger.Error('[Net] %s from station %s REFUSED: it is on contest "%s" and ' +
                   'this station is on "%s" (call %s). Peers must run the same ' +
                   'contest (Q110).',
                   [aDoor, peer, theirs, ours, string(aRec.Callsign)]);
      end;

   if GPeers.FirstNotice(aSender, theirs) then
      begin
      inc(FPeerContestNotices);
      (* A contest this build does not know (a peer on a newer one) is named by
        its id, which is all there is. *)
      theirsName := theirs;
      if FindContestById(theirs, theirHandle) then
         begin
         theirsName := ContestIdentity(theirHandle).DisplayName;
         end;
      notice := SysUtils.Format(SPeerOnAnotherContest,
                          [peer, theirsName, ContestIdentity(Contest).DisplayName]);
      if Assigned(PeerContestNoticeSink) then
         begin
         PeerContestNoticeSink(notice);
         end
      else
         begin
         QuickDisplay(notice);
         end;
      end;
end;

function PeerContestNoticeCount: integer;
begin
   Result := FPeerContestNotices;
end;

procedure ForgetPeerContestNotices;
begin
   FPeerContestNotices := 0;
   GPeers.ForgetNotices;
end;

(* WHAT THE SERVER STILL HAS TO HEAR ABOUT, POSTED. See the declaration for the
  design; this is the work.

  THE GUARDS ARE THE POINT. Posting to a link that is not up posts nothing; one
  whose server has not yet said HELLO may be a server that will close it; and a
  station refused for its computer id must not push its QSOs through a link the
  server has disowned. Once per link, because the server's HELLO comes once and
  a second would otherwise send everything twice.

  THE ROWS ARE READ INTO MEMORY FIRST and the cursor is closed before anything
  is posted: a burst of a few hundred 376-byte records is under 200 KB, and it
  keeps the store from being read while the main thread is busy writing. Nothing
  is written to the log here -- the flags change when the packets are WRITTEN
  (SettleServerProgress). *)
function ResendOfflineWork: TResendResult;
var
   rows: TLogRowUpdates;
   i: integer;
   needs: TResendNeeds;
   rec: ContestExchange;
   posted: boolean;
   notice: string;
begin
   Result.Qsos := 0;
   Result.Edits := 0;

   if GResentThisLink then
      begin
      Exit;
      end;
   if not NetIsConnected then
      begin
      Exit;
      end;
   if not FServerHelloSeen then
      begin
      Exit;
      end;
   if FRefusedComputerID <> #0 then
      begin
      Exit;
      end;
   GResentThisLink := True;

   rows := TLogRowUpdates.Create;
   try
      if not LogStoreCollectUnsentToServer(rows) then
         begin
         logger.Error('[Net] could not read the log to find the QSOs logged ' +
                      'while the link was down; nothing was resent. They stay ' +
                      'unsent and go on the next link.');
         Exit;
         end;

      posted := True;
      for i := 0 to rows.Count - 1 do
         begin
         rec := rows.Row(i);
         needs := ResendNeedsOf(rec);

         if needs.NeedsQso then
            begin
            (* A QSO the server has never been given goes whole, with whatever
              edits it has had: the packet is the record as it stands. *)
            posted := SendRecordToServer(NET_QSOINFO_ID, rec);
            if not posted then
               begin
               Break;
               end;
            GResentKeys.Add(rec.ceQSOID1, rec.ceQSOID2);
            Inc(Result.Qsos);
            end;

         if needs.NeedsEdit then
            begin
            posted := SendRecordToServer(NET_EDITEDQSO_ID, rec);
            if not posted then
               begin
               Break;
               end;
            GResentKeys.Add(rec.ceQSOID1, rec.ceQSOID2);
            Inc(Result.Edits);
            end;
         end;

      if not posted then
         begin
         logger.Warn('[Net] the link went down while the QSOs logged ' +
                     'meanwhile were being sent; %d QSO(s) and %d edit(s) were ' +
                     'posted, the rest stay unsent', [Result.Qsos, Result.Edits]);
         end;
   finally
      rows.Free;
   end;

   if (Result.Qsos = 0) and (Result.Edits = 0) then
      begin
      Exit;
      end;

   logger.Info('[Net] resending what was logged while disconnected: %d QSO(s), ' +
               '%d edit(s)', [Result.Qsos, Result.Edits]);

   (* THE OTHER STATIONS ARE TOLD A BATCH ARRIVED, as the D7 resend did: the
     server relays this message and each station shows the count. *)
   if Result.Qsos > 0 then
      begin
      ServerMessage.smMessage := SM_SERVERLOG_CHANGED_MESSAGE;
      ServerMessage.smParam := Result.Qsos;
      SendToNet(ServerMessage, SizeOf(ServerMessage));
      end;

   notice := SysUtils.Format(SNetResent, [Result.Qsos, Result.Edits]);
   if Assigned(ResendNoticeSink) then
      begin
      ResendNoticeSink(notice);
      end
   else
      begin
      QuickDisplay(notice);
      end;
end;

procedure NetServiceResend;
begin
   if not GResendDue then
      begin
      Exit;
      end;
   GResendDue := False;
   ResendOfflineWork;
end;

procedure NetServiceCatchUp;
begin
   if not GCatchUpDue then
      begin
      Exit;
      end;
   GCatchUpDue := False;

   (* THE SAME GUARDS AS THE RESEND: a station refused for its computer id has
     been disowned by the server, and one whose link has already dropped has
     nothing to ask. The fetch uses its own connection, but it is the link that
     says this server is ours to trust. *)
   if (not NetIsConnected) or (not FServerHelloSeen) or (FRefusedComputerID <> #0) then
      begin
      Exit;
      end;

   StartServerCatchUp(cuOnConnect);
end;

(* WHAT BECAME OF THE QSO PACKETS THE WRITER HAS FINISHED WITH, written down.
  Main thread. Flags only, in one transaction; a QSO whose bytes reached the
  socket is marked sent, an edit is cleared when every edit packet for it has,
  and anything that failed is left exactly as it was -- owing. *)
procedure SettleServerProgress;
var
   sent, edited: TNetTags;
   sentKeys, editKeys: TQsoSessionKeys;
   lost, i, unsent, dirty: integer;
   id1, id2: Cardinal;
begin
   if GNetDelivery = nil then
      begin
      Exit;
      end;

   GNetDelivery.Settle(sent, edited, lost);
   if (Length(sent) = 0) and (Length(edited) = 0) and (lost = 0) then
      begin
      Exit;
      end;

   SetLength(sentKeys, Length(sent));
   for i := 0 to High(sent) do
      begin
      NetTagIds(sent[i], id1, id2);
      sentKeys[i].SessionId := id1;
      sentKeys[i].SessionSeq := id2;
      end;
   SetLength(editKeys, Length(edited));
   for i := 0 to High(edited) do
      begin
      NetTagIds(edited[i], id1, id2);
      editKeys[i].SessionId := id1;
      editKeys[i].SessionSeq := id2;
      end;

   if (Length(sentKeys) > 0) or (Length(editKeys) > 0) then
      begin
      if not LogStoreMarkServerProgress(sentKeys, editKeys) then
         begin
         logger.Error('[Net] could not record that %d QSO(s) and %d edit(s) ' +
                      'reached the server; they stay unsent and go again on ' +
                      'the next link', [Length(sentKeys), Length(editKeys)]);
         end;
      end;

   if lost > 0 then
      begin
      logger.Warn('[Net] %d QSO packet(s) did not reach the server; a logged ' +
                  'QSO''s row stays unsent and goes again when the link is back, ' +
                  'and a restock is planned again from the server''s log', [lost]);
      end;

   if LogStoreCountUnsentToServer(unsent, dirty) then
      begin
      tUSQ := unsent;
      tUSQE := dirty;
      (* THE ONLY PLACE THESE TWO NUMBERS CAN BE READ is this line: the log
        compare window that showed them is gone (Phase 1, C6). *)
      logger.Debug('[Net] still owed to the server: %d QSO(s), %d edit(s)',
                   [unsent, dirty]);
      end;
end;

function ReceivedQsoIsKnown(const aRec: ContestExchange): boolean;
begin
   Result := False;
   if not QsoHasNetworkIdentity(aRec) then
      begin
      Exit;
      end;

   Result := LogStoreHasQSOBySessionIds(aRec.ceQSOID1, aRec.ceQSOID2);
   if Result then
      begin
      Inc(GDuplicateQsos);
      logger.Info('[Net] QSO %s (%d/%d) is already in the log; the copy that ' +
                  'just arrived is ignored',
                  [string(aRec.Callsign), aRec.ceQSOID1, aRec.ceQSOID2]);
      end;
end;

function NetDuplicateQsosIgnored: integer;
begin
   Result := GDuplicateQsos;
end;

(* ONE QSO OR EDIT PACKET, built from a record and posted.

  THE RECORD IS NEVER CHANGED. It used to set ceSendToServer on it before
  posting, and callers then stored it, so the log said "sent" for a packet that
  was only queued -- and a link that died with it still queued lost the QSO
  without a trace. The log's flags now change when the packet is WRITTEN
  (SettleServerProgress), so the record goes to the log as the caller made it:
  a new QSO unsent, an edited one dirty.

  THE PACKET says the opposite: sent, not dirty. That is what the server stores
  and what every other station logs for a QSO that came from the network, and
  those must not try to send it back.

  THE TAG is the QSO's network key, handed back when the write finishes so the
  right row is marked. A QSO with no key (both ids 0) travels, as it always
  did, but cannot be marked afterwards; it is not owed after a link-up either.

  True means POSTED, not delivered. *)
(* THE ONE PLACE A QSO OR EDIT PACKET IS BUILT AND POSTED. aTag is what the
  writer hands back when the bytes are written (0 = nothing to settle: the
  restock sends rows that are already marked sent). *)
function PostQsoPacket(RecordType: Word; const rec: ContestExchange;
                       aTag: Int64): boolean;
begin
   Result := False;
   if not NetIsConnected then
      begin
      Exit;
      end;

   NetQSOInfoToSend.qiID := RecordType;
   NetQSOInfoToSend.qiInformation := rec;
   NetQSOInfoToSend.qiInformation.ceSendToServer := True;
   NetQSOInfoToSend.qiInformation.ceNeedSendToServerAE := False;
   (* WHO PUT THIS ON THE WIRE (protocol 2). Every QSO, edit and offline resend
     goes through here, so this is the one place the sender is stated: the
     receivers judge the packet's contest by what THIS station announced, not by
     ceContest -- which, for a contest registered by id, means nothing outside
     this program. *)
   NetQSOInfoToSend.qiSenderID := Ord(WireComputerID);

   if SendToNet(NetQSOInfoToSend, SizeOf(NetQSOInfoToSend), aTag) <>
      SizeOf(NetQSOInfoToSend) then
      begin
      Exit;
      end;

   if (RecordType = NET_EDITEDQSO_ID) and (GNetDelivery <> nil) then
      begin
      GNetDelivery.EditPosted(aTag);
      end;
   Result := True;
end;

function SendRecordToServer(RecordType: Word; const rec: ContestExchange): boolean;
begin
   Result := PostQsoPacket(RecordType, rec,
                           NetQsoTag(rec.ceQSOID1, rec.ceQSOID2));
end;

function NetResentThisLink: TServerQsoIndex;
begin
   Result := GResentKeys;
end;

function NetCanRestock: boolean;
begin
   Result := NetIsConnected and FServerHelloSeen and (FRefusedComputerID = #0);
end;

function RestockServer(aPlan: TPushPlan; out aPosted: integer): boolean;
var
   i: integer;
begin
   Result := False;
   aPosted := 0;

   if not NetCanRestock then
      begin
      logger.Info('[Net] restock: the link is not usable now; nothing was sent');
      Exit;
      end;

   Result := True;
   for i := 0 to aPlan.Count - 1 do
      begin
      if not PostQsoPacket(NET_OFFLINEQSO_ID, aPlan.Row(i), 0) then
         begin
         Result := False;
         logger.Warn('[Net] restock: the link went down after %d of %d QSO(s); ' +
                     'the rest are planned again from the server''s log on the ' +
                     'next link', [aPosted, aPlan.Count]);
         Break;
         end;
      Inc(aPosted);
      end;

   if aPosted > 0 then
      begin
      logger.Info('[Net] restock: %d QSO(s) the server did not have were posted ' +
                  '(OFFLINEQSO: stored, acknowledged, not relayed)', [aPosted]);
      end;
end;

procedure ShowServerMessage(ServMess: TServerMessage);
begin
//  FillChar(s, SizeOf(s), 0);
  case ServMess.smMessage of
    SM_SERVERLOG_CHANGED_MESSAGE:
      begin
        QuickDisplay(SysUtils.Format(AnsiString(LclText(TC_SERVER_LOG_CHANGED)), [ServMess.smParam]));
      end;
    SM_CLEARALLLOGS_MESSAGE: QuickDisplay(TC_ALL_LOGS_NETWORK_CLEARED);
//    SM_CLEARSERVERLOG_MESSAGE: ShowTrayTips();
  end;

end;

procedure SetComputerName;
begin
  SendStationStatus(sstComputerNameAndID);
end;

procedure SendFullStationStatus;
var
  s                                     : StationStatusType;
begin
  for s := Low(StationStatusType) to High(StationStatusType) do
     begin
     SendStationStatus(s);
     Sleep(20);
     end;
end;

procedure SendSerialNumberChange(Status: TSerialNumberType);
begin
  if not NetIsConnected then Exit;
  if ServerSerialNumber = 0 then Exit; // no serial number lockout
  if PreviousSerialNumberType = Status then Exit;
  ServerMessage.smMessage := SM_SERIAL_NUMBER_CHANGED;
  ServerMessage.smParam := integer(Status);
  SendToNet(ServerMessage, SizeOf(ServerMessage));
  PreviousSerialNumberType := Status;
  if Status = sntReserved then
     begin
     DisplayNextQSONumber;
     end;
end;

(* THE INITIALIZATION SECTION.

  It existed and set one variable. The two objects the reader thread hands its
  bytes through were declared `= nil` and created NOWHERE -- so NetDataArrived's
  first statement, GNetLock.Acquire, faulted on the first byte of every
  connection and the multi-op link has not received one since the Indy
  conversion (found 2026-09-06, from a reader-thread access violation two
  milliseconds after each connect).

  HERE, rather than in a routine somebody has to call. They are unit-scoped
  singletons with no dependencies and no configuration; giving them a lifetime
  as long as the unit's removes the question of whether the thing that creates
  them ran, which is the question that was answered wrongly for weeks. *)
initialization
  { Cardinal, matching the declaration -- see uNet's STARTTIMEOFTHETR4W. }
  STARTTIMEOFTHETR4W := Cardinal(GetTickCount64);
//GetDiskFreeSpace(nil,STARTTIMEOFTHETR4W,STARTTIMEOFTHETR4W,STARTTIMEOFTHETR4W,STARTTIMEOFTHETR4W);

  GNetLock    := SyncObjs.TCriticalSection.Create;
  GNetDrainer := TNetDrainer.Create;
  GPeers      := TNetPeers.Create;
  GSendRefusals := TNetSendRefusals.Create;
  GNetDelivery := TNetDelivery.Create;
  GResentKeys := TServerQsoIndex.Create;

  (* OWNED HERE NOW, not created in uProgramMain's CreateEvent block with the
    three CW/DVP events. It is this unit's signal and nothing outside uses it,
    so its lifetime belongs with GNetLock's rather than in the startup
    sequence. *)
  tNet_Event  := SyncObjs.TEvent.Create(nil, False, False, '');

finalization
  (* SAFE BY ORDER, not by a lock. Unit finalization runs after the program
    body has returned, and ExitProgram calls NetLinkShutdown (which calls
    NetDisconnect) long before that -- which stops the writer and the reader
    thread and waits for them. (Until 2026-10-27 this comment said so and no
    such call existed.) So nothing is inside
    the lock, or about to take it, when it goes. *)
  FreeAndNil(GNetDrainer);
  FreeAndNil(GPeers);
  FreeAndNil(GSendRefusals);
  FreeAndNil(GNetDelivery);
  FreeAndNil(GResentKeys);
  FreeAndNil(GNetLock);
  FreeAndNil(tNet_Event);

end.
{
��� ���������� �����            - SendSerialNumberChange(sntFree);
��� �������� ������ � ������ CQ - SendSerialNumberChange(sntReserved);

tr4wserver:
���� �������� sntReserved �� ������ � ���� �������� ����������������
}


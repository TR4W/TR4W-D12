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
  utils_net,
  utils_file,
  uTotal,
  uSpots,
  uLogCompare,
  uIntercom,
  uCommctrl,
  CFGCMD,
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
  WinSock2,
  Windows,
  Messages,
  Tree

  ,
  uTR4WStrings,
  uAnsiStr;

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
procedure ConnectThread;
procedure DisplayClientStatus(Index: integer);
procedure DisplayMessageStatus(Index: integer; Msg: TMessageState);
procedure EnableNetworkMenuItem(uEnable: Cardinal);
procedure NetDisconnect;
procedure ProcessServerLogInfo(s: PLogFileInformation);
procedure SetStatusByte;
procedure SendStationStatus(ssType: StationStatusType);
procedure SendMessageStatus;
procedure TryConnectToNetwork;
function InitListViewImageLists(hwndLV: HWND): boolean;
function SendToNet(var buf; Len: integer): integer;

{ IS THE MULTI-OP LINK UP?  Replaces `NetSocket <> 0`, which three other units
  were reading directly. }
function NetIsConnected: boolean;
procedure CommitChangesInLocalLog;
function SendRecordToServer(RecordType: Word; var rec: ContestExchange): boolean;
procedure SendFullStationStatus;
procedure SendSerialNumberChange(Status: TSerialNumberType);

type
  TParameterToNetworkPtr = ^TParameterToNetwork;
  TIntercomMessagePtr = ^TIntercomMessage;

var
  PreviousSerialNumberType              : TSerialNumberType = sntUnknown {sntFree};

  ServerSerialNumber                    : integer;
  tNet_Event                            : Cardinal;
  tShowTypedCallsign                    : boolean = True;
  CurrentDisplayedRow                   : integer = 1;

  MF                                    : MultsFrequencies;
  tUSQ                                  : Cardinal;
  tUSQE                                 : Cardinal;

  tAllowAutoUpdate                      : boolean = True;
  tNetStatusUpdateInterval              : integer = 5000;
  tMessagesExhangeEnable                : boolean = True;
  StationStatusStringBuffer             : array[0..31] of Char;
  STARTTIMEOFTHETR4W                    : Cardinal;
  ACK                                   : integer;
  NetProcThreadID                       : Cardinal;

{(*}
  MyStationState                        : TStationState        ;// = (ssID: NET_STATIONSTATUS_ID);
  NetSynQSOInformation                  : TNetSynQSOInformation;// = (qsID: NET_TAKESERVERQSO_ID);//262
  NetQSOInfoToSend                      : TNetQSOInformation   ;// = (qiID: NET_QSOINFO_ID);//264
  NetDXSpot                             : TNetDXSpot           ;// = (dsID: NET_NETWORKDXSPOT_ID);//98
  NetTimeSync                           : TNetTimeSync         ;// = (tsID: NET_TIMESYN_ID);//20
  NetIntercomMessage                    : TIntercomMessage     ;// = (imID: NET_INTERCOMMESSAGE_ID);//84
  ParameterToNetwork                    : TParameterToNetwork  ;// = (pnID: NET_PARAMETER_ID; );//514
  SendSpotViaNetwork                    : TSendSpotViaNetwork  ;// = (vnID: NET_SPOTVIANETWORK_ID);//48
  ComputerNetID                         : TComputerNetID        = (ciID: NET_COMPUTERID_ID);//4
  ServerMessage                         : TServerMessage        = (smID: NET_SERVERMESSAGE_ID);//8
{*)}
  pc                                    : PChar;
  NetThreadID                           : Cardinal;
  StatusArray                           : array[1..26] of TStationState;
  PosInClientsList                      : array[1..26] of integer;
  ServerAddress                         : str31 = 'LOCALHOST';
  ServerPassword                        : Str20 = 'TR4WSERVER';
  ServerPort                            : integer = 1061;
  ServerAutoSynchronizeLogOnConnect     : boolean = False;  // Issue #912
  { THE LINK, over Indy.  Was `NetSocket: Cardinal` -- a raw Winsock handle
    that three other units tested for zero; ask NetIsConnected instead. }
  NetClient                             : TNetClient = nil;
  LogSyncSocket                         : Cardinal;
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
   { The SQLite shadow -- an IMPLEMENTATION-section use, so no interface
     cycle. uLogShadow never raises and never blocks logging. }
   uLogShadow,
  uMainForm,   { the call field, named -- wh[] round 3 }
  uNetworkForm,   { the station list is a TListView on a form now }
  uCFG,
  LOGSUBS2,
  uRadioPolling,
  uRadioConfigApply,   // ApplyPeerCommand -- a peer's config change
  uTelnet,
  uGetServerLog,
  MainUnit,
  uAppStrings,   { SNetComputerIDInUse -- new UI text does not go in uTR4WStrings }
  uComputerID,   { the station-id rule and its two wire encodings }
   uConfigValues;

{ THE ID THE SERVER REFUSED, in the ordinal form the wire uses, or #0.

  WITHOUT THIS THE CLIENT RETRIES THE REFUSAL EVERY FIVE SECONDS FOREVER.  The
  network window's timer calls TryConnectToNetwork whenever the link is down, so
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
              AddMessageToIntercomWindow(@IntercomMessagePtr^.imMessage[1], IntercomMessagePtr^.imSender);
            end;

          NET_LOGCOMPARE_ID:
            begin
              ProcessServerLogInfo(@NetBuffer[Bufindex + 2 - 2]);
            end;
{
          NET_MULTSFREQUENCIES_ID:
            begin
              Windows.CopyMemory(@MF, @NetBuffer[Bufindex + 2], SizeOf(MultsFrequencies));
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

                       if Windows.SetSystemTime(NetTimeSyncPtr.tsTime) then
                          begin
                          QuickDisplay(TC_COMPUTERCLOCKISSYNCHRONIZED)
                          end
                       else
                          begin
                          ShowSysErrorMessage('SET SYSTEM TIME');
                          end;
                       end;
            end;

          NET_NETWORKDXSPOT_ID:
            begin
              NetDXSpotPtr := @NetBuffer[Bufindex];
              SpotsList.AddSpot(NetDXSpotPtr^.dsSpot, False);
              DisplayBandMap;
            end;

          NET_QSOINFO_ID:
            begin
              NetQSOInfoPtr := @NetBuffer[Bufindex];
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
                 tAddQSOToLog(NetQSOInfoPtr^.qiInformation);
                 end;

              if NetQSOInfoPtr^.qiInformation.ceRecordKind in [rkQTCR, rkQTCS] then
                 begin
                 if NetQSOInfoPtr^.qiInformation.ceRecordKind = rkQTCS then
                    begin
                    NumberQTCBooksSent := NetQSOInfoPtr^.qiInformation.QSOPoints;
                    end;
                 IncrementQTCCount(NetQSOInfoPtr^.qiInformation.Callsign);
                 tAddQSOToLog(NetQSOInfoPtr^.qiInformation);
                 DisplayTotalScore;
                 UpdateTotals2;
                 end;

            end;

          NET_EDITEDQSO_ID:
            begin
              NetQSOInfoPtr := @NetBuffer[Bufindex];

              if NetQSOInfoPtr^.qiComputerID <> NetQSOInfoToSend.qiComputerID then
                 begin
                 if FindAndUpdateQSOInLog(NetQSOInfoPtr^.qiInformation) then
                   if tAllowAutoUpdate then
                      begin
                      tUpdateLog(actRescore);
                      LoadinLog;
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
                       Windows.ZeroMemory(@StatusArray[DisconnectedClient],
                                          SizeOf(TStationState));
                       DisplayClientStatus(DisconnectedClient);
                       end;
                  end;

                { THE SERVER WILL NOT HAVE THIS ID.  Latch, say so once, and go
                  away -- see FRefusedComputerID for why the retry has to stop
                  and how it starts again. }
                SM_COMPUTERID_IN_USE_MESSAGE:
                  begin
                    FRefusedComputerID := AnsiChar(ServerMessagePtr^.smParam);
                    logger.Warn('[Net] server refused computer ID %s -- ' +
                                'another station is already using it',
                                [string(ComputerID)]);
                    NetDisconnect;
                    showwarning(SysUtils.Format(SNetComputerIDInUse,
                                                [string(ComputerID)]));
                  end;

                SM_GETSTATUS_MESSAGE: SendFullStationStatus;

                SM_RECEIVED_UPDATED_QSO_MESSAGE:
//                asm                nop end;
                  Windows.SetEvent(tNet_Event);

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
          Windows.ZeroMemory(@StatusArray[I], SizeOf(TStationState));
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
   public
      procedure Drain(Data: PtrInt);
      procedure ReportDropped(Data: PtrInt);
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
var
   i: integer;
begin
   NetDisconnect;
   Windows.ZeroMemory(@StatusArray, SizeOf(StatusArray));
   for i := 1 to 26 do
      begin
      DisplayClientStatus(i);
      end;
   ShowConnectionStatus(TC_DISCONNECTEDFROM);
   TF.Format(wsprintfBuffer, PAnsiChar(WinAnsi(TC_CONNECTIONTOTR4WSERVERLOST)),
             @ServerAddress[1], ServerPort);
   QuickDisplay(wsprintfBuffer);
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
  EnableNetworkMenuItem(MF_GRAYED + MF_BYPOSITION);
  Windows.ZeroMemory(@MF, SizeOf(MultsFrequencies));
//  DisplayMultsFrequencies;
end;

procedure SendStationStatus(ssType: StationStatusType);
var
  callAnsi: AnsiString;   { sstCallsign -- see the byte-exact note below }
  callLen: integer;
begin
//  Exit;
  if not NetIsConnected then Exit;

  MyStationState.ssID := NET_STATIONSTATUS_ID;

  case ssType of
    sstComputerNameAndID:
      begin
        Windows.ZeroMemory(@MyStationState.ssName, SizeOf(MyStationState.ssName));
        Windows.CopyMemory(@MyStationState.ssName, @ComputerName[1], Ord(ComputerName[0]));
        MyStationState.ssComputerID := ComputerID;
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
      Windows.CopyMemory(@MyStationState.ssOperator, @CurrentOperator, SizeOf(OperatorType));
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
    STATUS_BYTE_BIT_PTT_LOCKOUT * Byte(Config.PTTLockout);
//    + STATUS_BYTE_BIT_MULT * Byte(tNewMultIndicatorPrevState)
  ;
end;

procedure SendMessageStatus;
var
  MyMessageState                        : TMessageState;
  i                                     : integer;
begin
  if not NetIsConnected then Exit;
  MyMessageState.msComputerId := ComputerID;
  MyMessageState.msID := NET_MESSAGESTATE_ID;
  if CWMessageToNetwork <> '' then
     begin
     Windows.MoveMemory(@MyMessageState.msCWMessage[0], @CWMessageToNetwork[1], length(CWMessageToNetwork));
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
     KillTimer(tr4whandle, UPDATE_NET_CW_MESSAGE);
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
   Result := ComputerIDOrdinal(ComputerID);
end;

procedure TryConnectToNetwork;
var
  announce: boolean;
begin
  { REFUSED, AND NOTHING HAS CHANGED SINCE.  Silent on purpose: the operator has
    already been told once, and repeating it every five seconds would be the
    same defect in a different costume. }
  if (FRefusedComputerID <> #0) and (FRefusedComputerID = WireComputerID) then
     begin
     Exit;
     end;
  FRefusedComputerID := #0;

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
     logger.Debug('TryConnectToNetwork -> %s:%d  (will retry every 5s while server is unreachable; further attempts logged only on state change)', [ServerAddress, ServerPort]);
     FConnectLogState := nclsTrying;
     end;
  if NetThreadID = 0 then
     begin
     FConnectThreadAnnounced := announce;
     tCreateThread(@ConnectThread, NetThreadID, not announce {Quiet on silent retries});
     end;
end;

{ CONNECT AND SHAKE HANDS, reporting the password case the way the dialog did.

  Returns False for every failure; the caller shows TC_FAILEDTOCONNECTTO, which
  is what it did before. }
function ConnectToTR4WServer: boolean;
var
   err: string;
   wrongPassword: boolean;
begin
   if NetClient = nil then
      begin
      NetClient := TNetClient.Create;
      NetClient.OnData := @NetDataArrived;
      NetClient.OnDisconnected := @NetLinkDropped;
      end;

   Result := NetClient.Connect(string(ServerAddress), ServerPort,
                               AnsiString(ServerPassword), err, wrongPassword);
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
                   [string(ServerAddress), ServerPort, err]);
      end;
end;

procedure ConnectThread;
label
  1, 2;
var
  i                                     : integer;
begin
  DifferentContests := False;
  ShowConnectionStatus(TC_CONNECTINGTO);

  if ConnectToTR4WServer then
{
  TempSocket := GetSocket; // socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  tr4w_saddr.sin_addr.S_addr := inet_addr(tgethostbyname(@ServerAddress[1]));
  tr4w_saddr.sin_port := htons(ServerPort);

  if TempSocket = INVALID_SOCKET then goto 2;
  i := tConnect(TempSocket, @tr4w_saddr);
  //I := WinSock2.WSAConnect(TempSocket, @tr4w_saddr, SizeOf(sockaddr_in), @ServerPassword, nil, nil, nil);
  if i = 0 then
}
     begin
     // The socket, the ten-byte password, the four-byte acknowledgement, the
     // Sleep(200) waiting for it, TCP_NODELAY and the WSAAsyncSelect that made
     // the network WINDOW the socket's event sink -- all of that is TNetClient's
     // now, and the handshake happens inside Connect because a link the server
     // has not acknowledged is not a link.
     ZeroMemory(@StatusArray, SizeOf(StatusArray));
     NetQSOInfoToSend.qiComputerID := Windows.GetTickCount;

 //    sCIDMESSAGE[4] := Char(Ord(ComputerID) - Ord('A') + 1);
     ComputerNetID.ciComputerID := WireComputerID;
     SendToNet(ComputerNetID, SizeOf(ComputerNetID));
     SendFullStationStatus;
     SendClientStatus;
     ServerMessage.smMessage := SM_GETSTATUS_MESSAGE;
     SendToNet(ServerMessage, SizeOf(ServerMessage));
 //    SendStationStatus;
     EnableNetworkMenuItem(MF_ENABLED + MF_BYPOSITION);
     ShowConnectionStatus(TC_CONNECTEDTO);
     if FConnectLogState <> nclsConnected then
        begin
        logger.Info('Connected to TR4WServer at %s:%d', [ServerAddress, ServerPort]);
        FConnectLogState := nclsConnected;
        end;
     end
  else
     begin
     1:
     ShowConnectionStatus(TC_FAILEDTOCONNECTTO);
     NetDisconnect;
     if FConnectLogState <> nclsFailed then
        begin
        logger.Warn('Failed to connect to TR4WServer at %s:%d (will keep retrying silently)', [ServerAddress, ServerPort]);
        FConnectLogState := nclsFailed;
        end;
     end;
  2:
  // Issue #1041: log destruction at the same volume as creation -- debug on a
  // genuine (announced) attempt so create/destroy pair up in the log, trace
  // during the silent retry loop so it stays quiet.
  if FConnectThreadAnnounced then
     begin
     logger.Debug('[ConnectThread] Thread %d destroyed, NetThreadID cleared', [GetCurrentThreadId])
     end
  else
     begin
     logger.Trace('[ConnectThread] Thread %d exiting, NetThreadID cleared', [GetCurrentThreadId]);
     end;
  NetThreadID := 0;
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

procedure DisplayClientStatus(Index: integer);
var
  elvi                                  : TLVItem;
  i, i2                                 : integer;
  h                                     : HWND;
//  p                                     : PChar;
  TempBuffer                            : array[0..31] of AnsiChar;
const
  da                                    : array[boolean] of PAnsiChar = (nil, 'D');
begin
  i := PosInClientsList[Index] - 1;
  CurrentDisplayedRow := Index;
  elvi.Mask := LVIF_TEXT;
  h := wh[mweNetwork];

  if StatusArray[Index].ssComputerID = #0 then
     begin
     for i2 := 0 to 7 do
        begin
        SetClientCell(i, i2, '');
        end;
     Exit;
     end;

  //LastStatus := StatusArray[Index].ssType;
  case StatusArray[Index].ssType of

    sstComputerNameAndID:
      begin
        CID_TWO_BYTES[0] := StatusArray[Index].ssComputerID;
        SetClientCell(i, 0, string(StatusArray[Index].ssName));
        SetClientCell(i, 1, string(PAnsiChar(@CID_TWO_BYTES)));
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
        TF.Format(@TempBuffer, '%s%s', BandStringsArrayWithOutSpaces[StatusArray[Index].ssCurrentBand], ModeStringArray[StatusArray[Index].ssCurrentMode]);

        SetClientCell(i, 2, string(PAnsiChar(@TempBuffer)));

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
        SetClientCell(i, 6 - 1, string(PTTStatusString[PTTStatusType((StatusArray[Index].ssStatusByte and (1 shl 0)) <> 0)]));
        //ListView_Update(h, I);
        ListView_RedrawItems(h, i, i);
      end;

    sstOpMode:
      SetClientCell(i, 5 - 1, string(OpModeString[OpModeType((StatusArray[Index].ssStatusByte and (1 shl 1)) <> 0)]));

    sstQSOs:
      SetClientCell(i, 7 - 1, IntToStr(StatusArray[Index].ssQSOTotals));

    sstCallsign:
      begin
        SetClientCell(i, 8 - 1, string(StatusArray[Index].ssCallsign));
        SetClientCell(i, 9 - 1, string(da[(StatusArray[Index].ssStatusByte and (1 shl 2)) <> 0]));
      end;

    sstOperator:
      SetClientCell(i, 9, string(StatusArray[Index].ssOperator));
  end;

  //  ListView_SetItemText(h, I, 8, inttopchar(StatusArray[Index].ssCWElements));
  //  ListView_SetItemText(h, I, 9, StatusArray[Index].ssCWMessage);
end;

function FindAndUpdateQSOInLog(var RXData: ContestExchange): boolean;
label
  1, 2;
var
  FilePointer                           : integer;
begin
  Result := False;
  FilePointer := -1;
  if not OpenLogFile then Exit;
  begin
    1:
    tSetFilePointer(FilePointer * SizeOf(ContestExchange), FILE_END);
    if ReadLogFile then
       begin
       if TempRXData.ceQSOID1 = RXData.ceQSOID1 then
         if TempRXData.ceQSOID2 = RXData.ceQSOID2 then
            begin
            tSetFilePointer(FilePointer * SizeOf(ContestExchange), FILE_END);
            sWriteFile(LogHandle, RXData, SizeOf(ContestExchange));
            { The shadow finds the same QSO by the same key -- one indexed
              statement instead of this backwards scan. }
            ShadowUpdateQSOBySessionIds(RXData);
            Result := True;
            goto 2;
            end;
       dec(FilePointer);
       goto 1;
       end;
    2:
    CloseLogFile;
  end;
end;

procedure EnableNetworkMenuItem(uEnable: Cardinal);
begin
  EnableMenuItem(tr4w_main_menu, 7, uEnable);
  DrawMenuBar(tr4whandle);
end;

procedure ProcessServerLogInfo(s: PLogFileInformation);
var
  IdenticalLogs                         : boolean;
begin
  tUpdateLog(actGetCRC32);
  s^.liLocalCRC32 := tCRC32;
  if not OpenLogFile then Exit;
  IdenticalLogs := True;
//  b := Windows.GetFileInformationByHandle(LogHandle, c);
  s^.liLocalLogSize := Windows.GetFileSize(LogHandle, nil);
  CloseLogFile;
//  if b then
  begin

    if s^.liLocalCRC32 <> s^.liSeverCRC32 then
       begin
       IdenticalLogs := False;
       end;
//IdenticalLogs=
//    if tUSQ <> 0 then IdenticalLogs := False;
//    if tUSQE <> 0 then IdenticalLogs := False;

    if not IdenticalLogs then
       begin
       // Issue #912: if SERVER AUTO SYNCHRONIZE LOG ON CONNECT is set, skip
       // the "Difference in logs" dialog AND the GetServerLog dialog entirely
       // and run the sync headlessly in a worker thread.  The replace happens
       // on the UI thread via SendMessage (see WM_USER_HEADLESS_SYNC_REPLACE
       // in tr4w.lpr) so LoadinLog's ListView access is thread-safe.
       //
       // Safety: only auto-sync when contests match (or server has no contest
       // yet); otherwise fall through to the existing dialog so the operator
       // sees the wrong-server warning.
       if ServerAutoSynchronizeLogOnConnect and
          ((s^.liContest = Contest) or (s^.liContest = DUMMYCONTEST)) then
          begin
          logger.Info('Auto-synchronizing local log from server (CRC mismatch: local %x, server %x)',
                      [s^.liLocalCRC32, s^.liSeverCRC32]);
          QuickDisplay(TC_AUTOSYNCHRONIZINGLOG);
          NewServerLogHandle := CreateFileA(TR4W_SYN_FILENAME,
                                           GENERIC_READ or GENERIC_WRITE,
                                           FILE_SHARE_READ or FILE_SHARE_WRITE,
                                           nil, CREATE_ALWAYS,
                                           FILE_ATTRIBUTE_ARCHIVE, 0);
          if NewServerLogHandle = INVALID_HANDLE_VALUE then
             begin
             logger.Error('Auto-sync: could not create %s', [TR4W_SYN_FILENAME]);
             // Fall through to the existing dialog so the operator can react.
             ShowLogCompare(integer(s));
             end
          else
             begin
             HeadlessSyncMode := True;
             if LogSyncThreadID = 0 then
                begin
                tCreateThread(@RunSyncThread, LogSyncThreadID);
                end;
             end;
          end
       else
 //      DialogBoxParam(hInstance, MAKEINTRESOURCE(75), tr4whandle, @LogCompareDlgProc, integer(s))
          begin
          ShowLogCompare(integer(s));
          end;
       end
    else
       begin
       QuickDisplay(TC_SERVERANDLOCALLOGSAREIDENTICAL);
       end;

  end;

end;

procedure AddNewClient(ClientID: integer);
var
  elvi                                  : TLVItem;
begin
  //  InitListViewImageLists(NetworkListViewhandle);

  elvi.Mask := LVIF_PARAM;
  elvi.iItem := TotalClients;
  elvi.iSubItem := 0;

  //  elvi.iImage := 0;
  ListView_InsertItem(wh[mweNetwork], elvi);
  inc(TotalClients);
  PosInClientsList[ClientID] := TotalClients;
end;

function InitListViewImageLists(hwndLV: HWND): boolean;
var
  hiconItem                             : HICON; // icon for list view items
  //  himlLarge                        : HImageList; // image list for icon view
  himlSmall                             : HImageList; // image list for other views
begin

  //  himlLarge := ImageList_Create(GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), Cardinal(True), 1, 1);
  himlSmall := ImageList_Create(15, 15, Cardinal(True), 1, 1);

  // Add an icon to each image list.
  hiconItem := LoadIcon(hInstance, 'MAINICON');
  //  hiconItem := LoadIcon(0, IDI_WINLOGO);
  //  ImageList_AddIcon(himlLarge, hiconItem);
  ImageList_AddIcon(himlSmall, hiconItem);
  DeleteObject(hiconItem);

  // Assign the image lists to the list view control.
//  ListView_SetImageList(hwndLV, himlLarge, LVSIL_NORMAL);

  ListView_SetImageList(hwndLV, himlSmall, LVSIL_SMALL);
  Result := True;
end;

procedure ShowConnectionStatus(Operation: string);
begin
  TF.Format(@NetBuffer, PAnsiChar(WinAnsi(TC_NETWORK)), PAnsiChar(WinAnsi(Operation)), @ServerAddress[1], ServerPort);
  Windows.SetWindowTextA(tr4w_WindowsArray[tw_NETWINDOW_INDEX].WndHandle, @NetBuffer);
end;

procedure DisplayMessageStatus(Index: integer; Msg: TMessageState);
var
  elvi                                  : TLVItem;
  i                                     : integer;
  h                                     : HWND;
  ProgressBarArray                      : array[0..25] of AnsiChar;
  ProgressBarPos                        : integer;
begin
  Windows.FillMemory(@ProgressBarArray[0], SizeOf(ProgressBarArray), Byte('|'));
  ProgressBarPos := Msg.msCWElements div 6;
  if ProgressBarPos > SizeOf(ProgressBarArray) - 1 then
     begin
     ProgressBarPos := SizeOf(ProgressBarArray) - 1;
     end;
  ProgressBarArray[ProgressBarPos] := #0;
  i := PosInClientsList[Index] - 1;
  elvi.Mask := LVIF_TEXT;
  h := wh[mweNetwork];
  SetClientCell(i, 10, string(PAnsiChar(@ProgressBarArray)));
  SetClientCell(i, 11, string(Msg.msCWMessage));
end;

function SendToNet(var buf; Len: integer): integer;
begin
  Result := 0;
  if NetIsConnected then
     begin
     Result := NetClient.Send(buf, Len);
     end;
end;

function NetIsConnected: boolean;
begin
  Result := (NetClient <> nil) and NetClient.IsConnected;
end;

procedure CommitChangesInLocalLog;
label
  1;
var
  SendedQSOs                            : integer;
  (* WHICH record the scan is standing on, 0-based.  See UpdateRec. *)
  RecordIndex                           : integer;

  procedure UpdateRec;
  begin
    tSetFilePointer(-1 * SizeOf(ContestExchange), FILE_CURRENT);
    sWriteFile(LogHandle, TempRXData, SizeOf(ContestExchange));

    (* BY INDEX, NOT "THE NEWEST" -- and calling it "the newest" was wrong.

       CommitChangesInLocalLog scans FORWARD from ReadVersionBlock, so the seek
       above is -1 from CURRENT: the record just read, anywhere in the log. The
       database call said ShadowUpdateNewestQSO, which rewrote the LAST row.
       So a QSO was marked as sent to the server in the binary log while a
       different one was marked in the database -- and since B4 the database is
       what every window and every export reads.

       The three sites that legitimately mean "the newest" all seek FILE_END;
       this one never did. *)
    ShadowUpdateQSOAtIndex(RecordIndex, TempRXData);
    inc(SendedQSOs);
    WaitForSingleObject(tNet_Event, 1000);
    // Runs on the sync WORKER thread and the window is an LCL form now, so this
    // goes through the marshalling seam rather than writing a control directly.
    // See uGetServerLog.ReportSyncProgress.
    ReportSyncProgress(SYNC_FIELD_SENT, SendedQSOs);
  end;
begin
  if (tUSQE = 0) and (tUSQ = 0) then Exit;
  SendedQSOs := 0;
  if not OpenLogFile then Exit;

  ReadVersionBlock;
  RecordIndex := -1;
  1:
  if ReadLogFile then
     begin
     inc(RecordIndex);

     if TempRXData.ceSendToServer = False then
        begin
        if SendRecordToServer(NET_OFFLINEQSO_ID, TempRXData) then
           begin
           UpdateRec;
           dec(tUSQ)
           end;

        end;

     if TempRXData.ceNeedSendToServerAE = True then
        begin
        if SendRecordToServer(NET_EDITEDQSO_ID, TempRXData) then
           begin
           UpdateRec;
           dec(tUSQE)
           end;
        end;

     goto 1;
     end;

  if SendedQSOs > 0 then
     begin
     ServerMessage.smMessage := SM_SERVERLOG_CHANGED_MESSAGE;
     ServerMessage.smParam := SendedQSOs;
     SendToNet(ServerMessage, SizeOf(ServerMessage));
     end;

  CloseLogFile;
end;

function SendRecordToServer(RecordType: Word; var rec: ContestExchange): boolean;
var
  BytesSent                             : integer;
  SendToServer                          : boolean;
  SendToServerAE                        : boolean;
begin
  Result := False;
  if not NetIsConnected then Exit;

  SendToServer := rec.ceSendToServer;
  SendToServerAE := rec.ceNeedSendToServerAE;

  rec.ceSendToServer := True;
  rec.ceNeedSendToServerAE := False;

  NetQSOInfoToSend.qiID := RecordType;
  NetQSOInfoToSend.qiInformation := rec;

  BytesSent := SendToNet(NetQSOInfoToSend, SizeOf(NetQSOInfoToSend)); // <> SizeOf(NetQSOInfoToSend)
  if BytesSent <> SizeOf(NetQSOInfoToSend) then
     begin
     rec.ceSendToServer := SendToServer;
     rec.ceNeedSendToServerAE := SendToServerAE;
     end
  else
     begin
     Result := True;
 //    if not SendToServer then dec(tUSQ);
 //    if not SendToServerAE then dec(tUSQE);
     end;
end;

procedure ShowServerMessage(ServMess: TServerMessage);
begin
//  Windows.ZeroMemory(@s, SizeOf(s));
  case ServMess.smMessage of
    SM_SERVERLOG_CHANGED_MESSAGE:
      begin
        TF.Format(QuickDisplayBuffer, PAnsiChar(WinAnsi(TC_SERVER_LOG_CHANGED)), ServMess.smParam);
        QuickDisplay(QuickDisplayBuffer);
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

begin
  STARTTIMEOFTHETR4W := Windows.GetTickCount;
//GetDiskFreeSpace(nil,STARTTIMEOFTHETR4W,STARTTIMEOFTHETR4W,STARTTIMEOFTHETR4W,STARTTIMEOFTHETR4W);

end.
{
��� ���������� �����            - SendSerialNumberChange(sntFree);
��� �������� ������ � ������ CQ - SendSerialNumberChange(sntReserved);

tr4wserver:
���� �������� sntReserved �� ������ � ���� �������� ����������������
}


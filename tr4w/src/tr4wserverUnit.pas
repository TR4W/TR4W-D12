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
unit tr4wserverUnit;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  (* WINDOWS AND WINSOCK2 ARE HERE FOR TYPE NAMES ONLY.

    Measured 2026-09-06: there is not one live Win32 API CALL left in this unit
    or in tr4wserver.lpr -- every Windows. reference the compiler can see is
    inside a comment. What still binds these two units in is a handful of TYPE
    declarations, and they are not all alike:

      TSocket        the client's identity, ~40 sites. It is a Cardinal on
                     every platform; making that explicit is a rename, not a
                     port, and it is the next thing to do here.
      HWND           ApplicationHandle, which was the message box's parent.
                     MessageDlg does not need one, so this goes with it.
      SYSTEMTIME     inside a protocol record -- on the WIRE between stations.
                     VC declares a layout-identical version off Windows; this
                     unit should use that, not its own.
      sockaddr_in,
      POverlapped,
      BOOL           leftovers of bind() and TransmitFile, both deleted. Dead
                     declarations, and they can simply go.

    Removing the two uses entries is therefore a real piece of work rather than
    a line edit, and it is written down here rather than half-done. *)
  Windows,
  WinSock2,
  VC,
  Log4D,        // server logging: InitServerLogger / logger, restored from the fork
  Version,      // TR4WSERVER_CURRENTVERSION, used by FullServerVersion below
  TF,
  uCRC32,
  uComputerID,   // the station-id rule, kept away from the sockets so it can be tested
  Classes,       // TStringList -- the client list is built and handed over whole
  uServerNet,    // the transport: Indy, not WSAAsyncSelect
  IdStack,       // GStack.LocalAddress -- the IP readout
  Dialogs,       // MessageDlg -- was MessageBoxW
  Controls,      // mrYes -- the modal results MessageDlg answers with
  uAnsiStr,      // StrPLCopy over PAnsiChar; SysUtils' is PWideChar
  uServerForm,   // the readouts, by name instead of by control number
  Messages;
const

  SERVERDEBUG                           = False;

type
  _TRANSMIT_FILE_BUFFERS = record
    Head: Pointer {lpvoid};
    HeadLength: DWORD;
    Tail: Pointer {lpvoid};
    TailLength: DWORD;
  end;

  TRANSMIT_FILE_BUFFERS = _TRANSMIT_FILE_BUFFERS;
  PTRANSMIT_FILE_BUFFERS = ^TRANSMIT_FILE_BUFFERS;
  LPTRANSMIT_FILE_BUFFERS = ^TRANSMIT_FILE_BUFFERS;


  TAcceptEx = function
    (
    sListenSocket, sAcceptSocket: TSocket;
    lpOutputBuffer: PChar;
    dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD;
    var lpdwBytesReceived: DWORD;
    lpOverlapped: POverlapped
    ): BOOL; stdcall;
{
  function AcceptEx(sListenSocket, sAcceptSocket: TSocket; lpOutputBuffer: LPVOID;
  dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD;
  var lpdwBytesReceived: DWORD; lpOverlapped: POVERLAPPED): BOOL; stdcall;
  }

type
  TServerLogArray = packed record
    slaCID: Byte;
    slaID1: Word;
    slaID2: Cardinal;
    slaAddress: Word;
    slaQSOTime: SYSTEMTIME;
  end;

type
  SocketPtr = ^Cardinal;

//  ServerLogArray = array of ContestExchange;
//  ServerLogArrayPtr = ^ServerLogArray;

type
  TClientEntry = packed record
    clSerialNumber: integer;
    clSocket: Cardinal;
    clIPAdr: array[0..15] of AnsiChar;
    clName: array[0..31] of AnsiChar;

    clSerialNumberStatus: TSerialNumberType;
    clConnectedToTelnet: boolean;
    clID: AnsiChar;
  end;

type
  DebugMessageType =
    (
    dmSpotViaNet,
    dmRX,
    dmTX,
    dmRun,
    dmDisc,
    dmMF,
    dmRXDisc,
    dmQSOInfo,
    dmList,
    dmAccept,
    dmTransmitFile,
    dmLogInfo,
    dmPass,
    dmStationStatus,
    dmDXSpot,
    dmTimeSyn,
    dmParam,
    dmIntercom,
    dmEditQSO,
    dmClearLogs,
    dmClearDupeSheet,
    dmSeverLogChanged,
    dmMessage,
    dmTR4W,
    dmROLQ
    );

const
  DebugMessagesArray                    : array[DebugMessageType] of PAnsiChar =
    ('SVN', 'RX ', 'TX ', 'RUN', 'DSC', 'MF ', 'RXD', 'QSO', 'LST', 'ACC', 'TF ', 'LI ', 'PAS', 'SS ', 'DXS', 'TS ', 'PAR', 'INT', 'EQ ', 'CLL', 'CLD', 'SLC', 'MES', 'TR ', 'OLQ');

  // TransmitFile flag from MSWSOCK.  Was supplied by the vendored WinSock2.pas;
  // the RTL's Winapi.WinSock2 does not declare the MSWSOCK extensions, and
  // TransmitFile itself is already loaded here as a function pointer.
  TF_DISCONNECT                         = $01;

  _TR4WSERVER                           = 'TR4WSERVER';
  _TR4WSERVERINIFILE                    = 'TR4WSERVER.INI';

  tsIPADDRESS                           = 106;
  tsCLIENTS                             = 110;
  MAXCLIENTS                            = 26;
  FullServerVersion                     = _TR4WSERVER + ' ' + TR4WSERVER_CURRENTVERSION;
  MaxContestExchangesBufferSize         = 30;
//  MAXSERIALNUMBER                       = 20000;
var
//  SerialsNumber                         : array[1..MAXSERIALNUMBER] of TSerialNumberType;

  MSWSOCKLoaded                         : boolean = False;
  sAllowTimeSynchronizing               : boolean = True;
  SerialNumberLockoutEnable             : boolean = False;
//  tGetLogTimeout                        : integer = 50;
  lpdwBytesReceived                     : DWORD;
  ServerMessagePtr                      : TServerMessagePtr;
  ServerMessage                         : TServerMessage = (smID: NET_SERVERMESSAGE_ID);
{
  ServerMF                              : MultsFrequencies =
    (
    (1810000, 3550000, 7040000, 14070000, 21070000, 28070000),
    (0000000, 0000000, 0000000, 00000000, 00000000, 00000000),
    (1890000, 3680000, 7100000, 14110000, 21160000, 28505000)
    );
}
//  NetMF                                 : NetMultsFrequencies = (mfID: NET_MULTSFREQUENCIES_ID);

  Server_TRANSMIT_FILE_BUFFERS          : _TRANSMIT_FILE_BUFFERS;

//  AcceptEx                              : TAcceptEx;

//  LogArrayPtr                           : ServerLogArray;
  TempCE                                : ContestExchange;

  EditedQSOPtr                          : NetQSOInformationPtr;
  ServerNewQSOPtr                       : NetQSOInformationPtr;
  ServerLogFileInformation              : TLogFileInformation = (liID: NET_LOGCOMPARE_ID);

  SENDTR4W                              : array[0..3] of AnsiChar = 'TR4W';
  PASSTR4W                              : array[0..3] of AnsiChar = 'PASS';

  ContestExchangesBuffer                : array[1..MaxContestExchangesBufferSize] of ContestExchange;

  ServerSyncMode                        : boolean;
  ServerLogOpened                       : boolean = False;
  ServerDebugMode                       : boolean = False;

  NetSynQSOInformation                  : TNetSynQSOInformation = (qsID: NET_TAKESERVERQSO_ID);

  TempLongBool                          : LongBool;
  CorrectPortNumber                     : LongBool;

  answer                                : array[1..2] of AnsiChar;
  ClientsSoocketsArray                  : array[1..MAXCLIENTS] of TClientEntry;
  ServerBuffer                          : array[0..4096 - 1] of AnsiChar;
  tr4wServerPassword                    : array[0..010] of AnsiChar;
  (* The message-only window that receives WM_SOCK_*. Owned by the program
    (tr4wserver.lpr); declared here because RunServer and RunSyncListener are
    the ones that name it in WSAAsyncSelect. Goes when Indy lands. *)
  ServerSocketSink                      : HWND = 0;
  ServerLogFileName                     : array[0..255] of AnsiChar;
{$IF SERVERDEBUG}
  ServerDebugFileName                   : array[0..255] of Char;
{$IFEND}
//  MultsFrequenciesFileName              : array[0..255] of Char;
  DisplayBuffer                         : array[0..063] of AnsiChar;

  client_addr                           : sockaddr_in;
  mysaddr                               : sockaddr_in;
  net_mywsadata                         : TWSAData;
  myhostent                             : Phostent;

  hIpAddr                               : HWND;
  ApplicationHandle                     : HWND;
  (* THE SERVER LOG, AS A STREAM.

    Was `ServerLogHandle: HWND` and thirty-odd Win32 calls against it. A
    TFileStream is the RTL's, works on every platform FPC targets, and knows
    its own size -- which is most of what the old code asked the handle for. *)
  ServerLog                             : TFileStream = nil;
  ServerTempLogHandle                   : HWND = INVALID_HANDLE_VALUE;

  LogArraySize                          : integer;
  ENABLE_TCP_NODELAY                    : integer = 1;
  Bufindex                              : integer;
  net_sock_rx                           : integer = 0;
  net_sock_tx                           : integer = 0;
  nclients                              : integer;
  addrlen                               : integer = SizeOf(sockaddr_in);

  MSWSOCK_DLL                           : Cardinal;
  ServerOS                              : Cardinal;
  PortNumber                            : Cardinal;
  ContestExchangesBufferIndex           : Cardinal = 0;
//  SetPointerEvent                       : Cardinal;
  BytesWritten                          : Cardinal;

  logger                                : TLogLogger;
  appender                              : TLogRollingFileAppender;

  LastDisplayedBytesRCVD                : Cardinal = 0;
  LastDisplayedBytesSEND                : Cardinal = 0;

  BytesRCVD                             : Cardinal = 0;
  BytesSEND                             : Cardinal = 0;

  ServerSocket                          : Cardinal;
  ListenerSocket                        : Cardinal;
  ServerThread                          : Cardinal;
  ServerThreadID                        : Cardinal;
  NewClientThread                       : Cardinal;
  NewClientThreadID                     : Cardinal;
  ThreadID                              : Cardinal;
  SendLogTo                             : Cardinal;
  ServerCRC32                           : Cardinal;
  ServerCRC32Changed                    : boolean = True;
const
  WM_SOCK_NET_RX                        = WM_USER + 131;
  WM_SOCK_NET_ACCEPT                    = WM_USER + 132;
  WM_SOCK_NET_SYNLISTNER                = WM_SOCK_NET_ACCEPT + 1;

//procedure SortServerLog;
//function SortServerLogArrayShell: boolean;

function tUpdateServerLog(UpdAction: UpadateAction): boolean;
procedure SendConfirmMessage(s: TSocket);
procedure SerialNumbersChanged;
procedure UpdateSerialNumbersStatus(s: TSocket; Status: TSerialNumberType);
procedure RunServerThread;
procedure RunServer;
procedure GetServerLogCRC32;
function sSend(s: TSocket; var buf; Len: integer; mt: DebugMessageType): integer;
function ServerMessageBox(const Text: string; uType: UINT): integer;
procedure InitServerLogger;
procedure ScanLogForSerialsNumbers;
procedure StopServer;
procedure AddSocketToArray(soc: Cardinal; IP: PAnsiChar; Name: PAnsiChar);
procedure DeleteSocketFromArray(soc: Cardinal);
procedure SendMessageToClients(From: Cardinal; Count: integer; ToAll: boolean; mt: DebugMessageType);
procedure ProcessClientBuffer(aSocket: Cardinal; aBytes: integer);
procedure DisplayRCVDBytes;
procedure DisplaySENDBytes;
procedure DisplayClients;
procedure DisplayServerLogSize;
//procedure SetServerIcon(Icon: PChar);
procedure UpdateQSOInServerlog(CE: ContestExchange);
function OpenServerLog(dwCreationDistribution: DWORD): boolean;
procedure CloseServerLog;
procedure AddContestExchangeToBuffer(CE: ContestExchange);
procedure WriteContestExchangesBufferToServerLog;
procedure SendLogFileInformation(s: TSocket);
function ClearServerLog: boolean;
procedure WriteToServerDebugFile(Count: Cardinal; s: TSocket; comment: PChar; mt: DebugMessageType);
procedure SendDisconnectMessage(Client: AnsiChar);
procedure SetComputerID(ID: AnsiChar; s: TSocket);
procedure SetStatus(Status: TClientStatus; s: TSocket);
procedure SendSpotViaNet(Status: TSendSpotViaNetwork; s: TSocket);
function CorrectPassword(s: TSocket; BytesReceived: integer): boolean;
//procedure LoadinMultsFrequencies;
//procedure SaveMultsFrequencies;
//procedure SendMFToClients;

implementation

procedure RunServerThread;
begin
  //  ServerThread := CreateThread(nil, 0, @RunServer, nil, 0, ServerThreadID);
  RunServer;
end;

// Restored from the tr4wserver/src fork (commit 60620b2, "TR4WServer logging").
// The D12 string work branched from a copy that predated it, so this and the
// two logging sites below were absent from the copy being modernized -- and
// tr4wserver.lpr calls this at WM_INITDIALOG.
procedure InitServerLogger;
begin
  appender := TLogRollingFileAppender.Create('name', 'tr4wserver.log');
  appender.Layout := TLogPatternLayout.Create('%d ' + TTCCPattern);
  TLogBasicConfigurator.Configure(appender);
  logger := TLogLogger.GetLogger('TR4WServer');
  logger.Level := All;
  logger.Info('TR4WServer starting');
end;

procedure RunServer;
label
  UnSucc;
begin

  DisplayRCVDBytes;
  DisplaySENDBytes;
  DisplayClients;
//  Windows.ZeroMemory(@ClientsSoocketsArray, SizeOf(ClientsSoocketsArray));
  (* THE ADDRESS TO TELL OPERATORS, FROM INDY'S STACK.

    Was Gethostname + gethostbyname + iNet_ntoa -- three WinSock calls to
    print one string. GStack.LocalAddress is the same answer and is whatever
    the platform's stack says. *)
  SetServerIP(GStack.LocalAddress);
  (* BOTH LISTENERS, IN ONE CALL. This was socket/bind/listen plus a
    WSAAsyncSelect naming a window, and RunSyncListener was the same again on
    PortNumber + 1. Indy owns the accept loop and the per-client threads; the
    reporting on failure is unchanged, and still a message box, because a
    server that cannot listen has nothing else to say. *)
  if not StartServerNet(PortNumber, PortNumber + 1) then
     begin
     goto UnSucc;
     end;

  { ONE state, not two enables kept in step by hand -- see SetServerRunning. }
  SetServerRunning(True);
//  SetServerIcon(IDI_APPLICATION);
//  DisplayClients;
  Exit;
  UnSucc:


end;

(* SHUT THE LISTENERS DOWN AND FORGET THE CLIENTS.

  Was: cancel each client's WSAAsyncSelect, closesocket it, then the same for
  the listening socket. Indy closes the connections when the server goes
  inactive, so what is left here is the engine's own bookkeeping. *)
procedure StopServer;
var
  i: integer;
begin
  StopServerNet;

  for i := 1 to maxclients do
     begin
     ClientsSoocketsArray[i].clSocket := 0;
     end;
  nclients := 0;
  SetServerRunning(False);
end;

procedure SendMessageToClients(From: Cardinal; Count: integer; ToAll: boolean; mt: DebugMessageType);
var
  i                                     : Cardinal;
  I2                                    : integer;
begin
  for i := 1 to maxclients do
    if ClientsSoocketsArray[i].clSocket <> 0 then
       begin
       if ToAll = False then if ClientsSoocketsArray[i].clSocket = From then Continue;
       I2 := sSend(ClientsSoocketsArray[i].clSocket, ServerBuffer[Bufindex], Count, mt);

       Sleep(0);
       end;
end;

procedure AddSocketToArray(soc: Cardinal; IP: PAnsiChar; Name: PAnsiChar);
var
  i                                     : integer;
begin
  for i := 1 to maxclients do
    if ClientsSoocketsArray[i].clSocket = 0 then
       begin
       (* FillChar and StrPLCopy, not ZeroMemory and lstrcpyA.

         The `- 4` is preserved and is not an accident: it skips
         clSerialNumber, which survives a client reconnecting. StrPLCopy also
         BOUNDS the copy, which lstrcpyA did not -- a reverse-DNS name longer
         than 31 characters would have run off the end of clName. *)
       FillChar(ClientsSoocketsArray[i].clSocket, SizeOf(TClientEntry) - 4, 0);
       ClientsSoocketsArray[i].clSocket := soc;
       uAnsiStr.StrPLCopy(@ClientsSoocketsArray[i].clIPAdr[0], AnsiString(IP),
                          High(ClientsSoocketsArray[i].clIPAdr));
       if Name <> nil then
          begin
          uAnsiStr.StrPLCopy(@ClientsSoocketsArray[i].clName[0], AnsiString(Name),
                             High(ClientsSoocketsArray[i].clName));
          end;
       if Name = nil then
          begin
          ClientsSoocketsArray[i].clName[0] := '?';
          end;
       inc(nclients);
       Break;
       end;
end;

procedure DeleteSocketFromArray(soc: Cardinal);
var
  b                                     : Byte;
begin
  for b := 1 to maxclients do
    if ClientsSoocketsArray[b].clSocket = soc then
       begin
       ClientsSoocketsArray[b].clSocket := 0;
       SendDisconnectMessage(ClientsSoocketsArray[b].clID);
       dec(nclients);
       Break;
       end;
end;

(* ONE CLIENT'S BYTES, PARSED. EXTRACTED FROM THE DIALOG PROCEDURE, NOT
  REWRITTEN.

  This was the WM_SOCK_NET_RX arm of TR4wServerDlgProc: 190 lines of message
  ids, forwarding rules and log writes, with two labels and four gotos. It is
  the multi-op protocol, nothing in this tree tests it, and the surest way to
  break a contest would be to retype it. So it moved verbatim -- the only edits
  are the two identifiers that used to be dialog-procedure locals (wp is
  aSocket, BytesReceived is aBytes) and the removal of the read itself.

  THE READ IS THE TRANSPORT'S JOB NOW. The arm began by calling sRecv and
  treating <= 0 as a disconnect; Indy reads, and says a connection closed by
  raising rather than by returning zero. See uServerNet.

  RUNS ON THE MAIN THREAD. uServerNet marshals with Synchronize, so every
  routine called from here -- SendMessageToClients, the log writes, the
  readouts -- sees exactly the single-threaded world it always did. That is
  deliberate: Indy gives each client a thread, and letting those threads into
  this would turn a protocol parser into a concurrency problem. *)
procedure ProcessClientBuffer(aSocket: Cardinal; aBytes: integer);
label
  1, CheckBuffer;
var
  counter: Cardinal;
begin
        Bufindex := 0;
        counter := 0;
        //            if br mod 5 <> 0 then MessageBox(ApplicationHandle, PChar(IntToStr(br)), 'recv', MB_YESNO or MB_ICONQUESTION or MB_TOPMOST or MB_DEFBUTTON2);

        CheckBuffer:

        case PWORD(@ServerBuffer[Bufindex])^ of

          NET_MESSAGESTATE_ID:
            begin
              SendMessageToClients(aSocket, SizeOf(TMessageState), True, dmMessage);
              Bufindex := Bufindex + SizeOf(TMessageState);
            end;

          NET_STATIONSTATUS_ID:
            begin
              SendMessageToClients(aSocket, SizeOf(TStationState), True, dmStationStatus);
              Bufindex := Bufindex + SizeOf(TStationState);
              if Bufindex = aBytes then goto 1;
            end;

          NET_NETWORKDXSPOT_ID:
            begin
              SendMessageToClients(aSocket, SizeOf(TNetDXSpot), False, dmDXSpot);
              Bufindex := Bufindex + SizeOf(TNetDXSpot);
            end;

          NET_TIMESYN_ID:
            begin
              if sAllowTimeSynchronizing then SendMessageToClients(aSocket, SizeOf(TNetTimeSync), False, dmTimeSyn);
              Bufindex := Bufindex + SizeOf(TNetTimeSync);
            end;

          NET_PARAMETER_ID:
            begin
              SendMessageToClients(aSocket, SizeOf(TParameterToNetwork), False, dmParam);
              Bufindex := Bufindex + SizeOf(TParameterToNetwork);
            end;

          NET_INTERCOMMESSAGE_ID:
            begin
              SendMessageToClients(aSocket, SizeOf(TIntercomMessage), True, dmIntercom);
              Bufindex := Bufindex + SizeOf(TIntercomMessage);
            end;

          NET_EDITEDQSO_ID:
            begin
              SendMessageToClients(aSocket, SizeOf(TNetQSOInformation), False, dmEditQSO);
              EditedQSOPtr := @ServerBuffer[Bufindex];
              logger.Debug('NET_EDITEDQSO: call=' + string(EditedQSOPtr^.qiInformation.Callsign) +
                ' band=' + IntToStr(Ord(EditedQSOPtr^.qiInformation.Band)) +
                ' mode=' + IntToStr(Ord(EditedQSOPtr^.qiInformation.Mode)) +
                ' exch=' + string(EditedQSOPtr^.qiInformation.ExchString));
              UpdateQSOInServerlog(EditedQSOPtr^.qiInformation);
              SendConfirmMessage(aSocket);

              Bufindex := Bufindex + SizeOf(TNetQSOInformation);
            end;

          NET_OFFLINEQSO_ID:
            begin
              ServerNewQSOPtr := @ServerBuffer[Bufindex];
              if OpenServerLog(OPEN_EXISTING) then
              begin
                ServerLog.Seek(0, soEnd);
                ServerLog.WriteBuffer(ServerNewQSOPtr.qiInformation, SizeOf(ContestExchange));
                FileFlush(ServerLog.Handle);
                DisplayServerLogSize;
                CloseServerLog;
                SendConfirmMessage(aSocket);
              end;
              Bufindex := Bufindex + SizeOf(TNetQSOInformation);
            end;

          NET_QSOINFO_ID:
            begin
              ServerNewQSOPtr := @ServerBuffer[Bufindex];
              logger.Debug('NET_QSOINFO: call=' + string(ServerNewQSOPtr^.qiInformation.Callsign) +
                ' band=' + IntToStr(Ord(ServerNewQSOPtr^.qiInformation.Band)) +
                ' mode=' + IntToStr(Ord(ServerNewQSOPtr^.qiInformation.Mode)) +
                ' exch=' + string(ServerNewQSOPtr^.qiInformation.ExchString));
              SendMessageToClients(aSocket, SizeOf(TNetQSOInformation), False, dmQSOInfo);
              if OpenServerLog(OPEN_EXISTING) then
              begin
                ServerLog.Seek(0, soEnd);
                ServerLog.WriteBuffer(ServerNewQSOPtr.qiInformation, SizeOf(ContestExchange));
                FileFlush(ServerLog.Handle);
                DisplayServerLogSize;
                CloseServerLog;
              end
              else
                AddContestExchangeToBuffer(ServerNewQSOPtr.qiInformation);
              Bufindex := Bufindex + SizeOf(TNetQSOInformation);
            end;

          NET_CLIENTSTATUS_ID:
            begin
              SetStatus(TClientStatusPtr(@ServerBuffer[Bufindex])^, aSocket);
              inc(Bufindex, SizeOf(TClientStatus));
            end;

          NET_SPOTVIANETWORK_ID:
            begin
              SendSpotViaNet(TSendSpotViaNetworkPtr(@ServerBuffer[Bufindex])^, aSocket);
              inc(Bufindex, SizeOf(TSendSpotViaNetwork));
            end;

          NET_COMPUTERID_ID:
            begin
              SetComputerID(TComputerNetIDPtr(@ServerBuffer[Bufindex])^.ciComputerID, aSocket);
              Bufindex := Bufindex + SizeOf(TComputerNetID);
            end;
{
          NET_MULTSFREQUENCIES_ID:
            begin
              Windows.CopyMemory(@ServerMF, @ServerBuffer[Bufindex + 2], SizeOf(MultsFrequencies));
              SendMFToClients;
              Bufindex := Bufindex + SizeOf(NetMultsFrequencies);
            end;
}
          NET_SERVERMESSAGE_ID:
            begin
              ServerMessagePtr := @ServerBuffer[Bufindex];
              case ServerMessagePtr.smMessage of
{
                SM_CLEARSERVERLOG_MESSAGE:
                  begin
                    if ClearServerLog then SendMessageToClients(aSocket, SizeOf(TServerMessage), True, dmClearLogs);
                  end;
}

                SM_SERIAL_NUMBER_CHANGED:
                  begin
                    if SerialNumberLockoutEnable then
                      UpdateSerialNumbersStatus(aSocket, TSerialNumberType(ServerMessagePtr.smParam));
                  end;

                SM_CLEARALLLOGS_MESSAGE:
                  begin
                    if ClearServerLog then SendMessageToClients(aSocket, SizeOf(TServerMessage), True, dmClearLogs);
                  end;

                SM_CLEAR_DUPESHEET_MESSAGE:
                  begin
                    if tUpdateServerLog(actSetClearDupesheetBit) then SendMessageToClients(aSocket, SizeOf(TServerMessage), True, dmClearLogs);
                  end;

                SM_CLEAR_MULTSHEET_MESSAGE:
                  begin
                    if tUpdateServerLog(actClearMults) then SendMessageToClients(aSocket, SizeOf(TServerMessage), True, dmClearLogs);
                  end;
{
                SM_SORTLOG_MESSAGE:
                  begin
                    if OpenServerLog(OPEN_EXISTING) then
                    begin
                      SortServerLog;
                      CloseServerLog;
                    end;
                  end;
}
                SM_SERVERLOG_CHANGED_MESSAGE:
                  begin
                    SendMessageToClients(aSocket, SizeOf(TServerMessage), False, dmClearLogs);
                  end;

                SM_GETSTATUS_MESSAGE:
                  SendMessageToClients(aSocket, SizeOf(TServerMessage), False, dmClearLogs);

              end;
              Bufindex := Bufindex + SizeOf(TServerMessage);

            end;

        end;

        if Bufindex = aBytes then goto 1;

        if PDWORD(@ServerBuffer[Bufindex])^ = NET_LOGINFO_MESSAGE then
        begin
          SendLogFileInformation(aSocket);
          Bufindex := Bufindex + SizeOf(NET_LOGINFO_MESSAGE);
          if Bufindex = aBytes then goto 1;
        end;

        inc(counter);

        if counter < 25 then goto CheckBuffer;
        1:
        DisplayRCVDBytes;

end;

(* THE FOUR READOUTS. Each was a control NUMBER written straight into the
  Win32 dialog -- 108, 112, 109, 115 -- with the meaning of the number living in
  a .res nobody could open in a designer. They name what they are reporting now
  and uServerForm decides where it appears; see that unit's header. *)

procedure DisplayRCVDBytes;
begin
  { Still throttled to whole kilobytes. This fires on EVERY recv, so the guard
    is not cosmetic -- it is why a busy multi-op does not repaint per packet. }
  if (BytesRCVD - LastDisplayedBytesRCVD) < 1024 then Exit;
  SetBytesReceivedKB(BytesRCVD div 1024);
  LastDisplayedBytesRCVD := BytesRCVD
end;

procedure DisplaySENDBytes;
begin
  if (BytesSEND - LastDisplayedBytesSEND) < 1024 then Exit;
  SetBytesSentKB(BytesSEND div 1024);
  LastDisplayedBytesSEND := BytesSEND;
end;

procedure DisplayClients;
var
  i     : integer;
  lines : TStringList;
begin
  (* THE WHOLE LIST AT ONCE. This was LB_RESETCONTENT followed by one
    LB_ADDSTRING per client, built through TF.Format into a shared AnsiChar
    buffer. A TStringList says the same thing and the form assigns it in one
    step, so there is no window in which the list is half-rebuilt. *)
  lines := TStringList.Create;
  try
     for i := 1 to maxclients do
       if ClientsSoocketsArray[i].clSocket <> 0 then
          begin
          lines.Add(Format('%s: %s',
                           [String(PAnsiChar(@ClientsSoocketsArray[i].clIPAdr[0])),
                            String(PAnsiChar(@ClientsSoocketsArray[i].clName[0]))]));
          end;
     SetClientList(lines);
  finally
     lines.Free;
  end;

  { The count, and the title bar with it -- see SetClientCount. }
  SetClientCount(nclients);
end;

procedure DisplayServerLogSize;
begin
  ServerCRC32Changed := True;
  SetServerLogQSOs((ServerLog.Size - 4) div SizeOf(ContestExchange));
end;
{
procedure SetServerIcon(Icon: PChar);
begin
  SendMessage(ApplicationHandle, WM_SETICON, ICON_SMALL, LoadIcon(0, Icon));
end;
}
{
procedure CreateServerLog;
var
   I, i2                           : Cardinal;
begin

      begin
         for I := 1 to maxclients do
            if ClientsSoocketsArray[I].clSocket <> 0 then
               begin
                  i2 := Send(ClientsSoocketsArray[I].clSocket, SYNCMESSAGE, SizeOf(SYNCMESSAGE), 0);
                  BytesSEND := BytesSEND + i2;
               end;

      end;
end;
}


procedure UpdateQSOInServerlog(CE: ContestExchange);
label
  1, 2;
var
  pNumberOfBytesRead                    : Cardinal;
  FilePointer                           : integer;

begin
  FilePointer := -1;
  if OpenServerLog(OPEN_EXISTING) then
     begin
     1:
     ServerLog.Seek(FilePointer * SizeOf(ContestExchange), soEnd);
     pNumberOfBytesRead := ServerLog.Read(TempCE, SizeOf(ContestExchange));
     if pNumberOfBytesRead = SizeOf(ContestExchange) then
        begin
        if TempCE.ceQSOID1 = CE.ceQSOID1 then
          if TempCE.ceQSOID2 = CE.ceQSOID2 then
             begin
             ServerLog.Seek(FilePointer * SizeOf(ContestExchange), soEnd);
             ServerLog.WriteBuffer(CE, SizeOf(ContestExchange));
             ServerCRC32Changed := True;
             goto 2;
             end;
        dec(FilePointer);
        goto 1;
        end;
     2:
     CloseServerLog;
     end;
end;


(* Load_MSWSOCK AND TransmitServerLog ARE GONE, AND SO IS THE REASON FOR THEM.

  The log-sync listener answered with TransmitFile -- a WinSock EXTENSION that
  lives in MSWSOCK.DLL rather than ws2_32, so it had to be reached with
  LoadLibrary and GetProcAddress -- and TransmitServerLog was the fallback for
  the Windows versions that lacked it, running on a thread of its own from
  CreateThread.

  Indy writes a stream. uServerNet.SyncExecute opens the log as a TFileStream
  and hands it to IOHandler.Write, on the connection's own thread, which is
  what that CreateThread was for. *)

(* OPEN, AND THE PARAMETER IS STILL THE WIN32 DISPOSITION -- deliberately.

  Every caller says OPEN_EXISTING or OPEN_ALWAYS, and those two words carry the
  intent exactly: "the log must already be there" and "make one if it is not".
  Renaming them would touch a dozen call sites to say the same thing, so the
  constants stay as the vocabulary and only the mechanism changed.

  fmShareDenyNone matches the old FILE_SHARE_READ or FILE_SHARE_WRITE: the sync
  listener reads this file while the server writes it. *)
function OpenServerLog(dwCreationDistribution: DWORD): boolean;
var
   name: string;
begin
  Result := False;
  if ServerLogOpened then Exit;

  name := String(PAnsiChar(@ServerLogFileName[0]));
  try
     if (dwCreationDistribution = OPEN_ALWAYS) and (not FileExists(name)) then
        begin
        ServerLog := TFileStream.Create(name, fmCreate or fmShareDenyNone);
        end
     else
        begin
        ServerLog := TFileStream.Create(name, fmOpenReadWrite or fmShareDenyNone);
        end;
     Result := True;
  except
     on E: Exception do
        begin
        { REPORTED. The Win32 version returned INVALID_HANDLE_VALUE and the
          reason was in GetLastError, which nothing read. }
        logger.Error('[Log] cannot open %s: %s', [name, E.Message]);
        FreeAndNil(ServerLog);
        Result := False;
        end;
  end;

  ServerLogOpened := Result;
end;

procedure CloseServerLog;
begin
  FreeAndNil(ServerLog);
  ServerLogOpened := False;
end;

procedure AddContestExchangeToBuffer(CE: ContestExchange);
begin
  if ContestExchangesBufferIndex = MaxContestExchangesBufferSize then Exit;
  inc(ContestExchangesBufferIndex);
  ContestExchangesBuffer[ContestExchangesBufferIndex] := CE;
end;

procedure WriteContestExchangesBufferToServerLog;
var
  c, lpNumberOfBytesWritten             : Cardinal;
begin
  if ContestExchangesBufferIndex = 0 then Exit;
  if not OpenServerLog(OPEN_EXISTING) then
     begin
     ContestExchangesBufferIndex := 0;
     Exit;
     end;
  ServerLog.Seek(0, soEnd);
  for c := 1 to ContestExchangesBufferIndex do
     begin
     ServerLog.WriteBuffer(ContestExchangesBuffer[c], SizeOf(ContestExchange));
     end;
  FileFlush(ServerLog.Handle);
  DisplayServerLogSize;
  CloseServerLog;
  ContestExchangesBufferIndex := 0;
end;

procedure SendLogFileInformation(s: TSocket);
var
  pNumberOfBytesRead                    : Cardinal;
begin
  if not OpenServerLog(OPEN_EXISTING) then Exit;
  ServerLogFileInformation.liServerLogSize := ServerLog.Size;
  ServerLogFileInformation.liContest := DUMMYCONTEST;
  if ServerLogFileInformation.liServerLogSize > SizeOfTLogHeader then
     begin
     ServerLog.Seek(SizeOfTLogHeader, soBeginning);
     pNumberOfBytesRead := ServerLog.Read(TempCE, SizeOf(TempCE));
     ServerLogFileInformation.liContest := TempCE.ceContest;
     end;
  CloseServerLog;
  GetServerLogCRC32;
  ServerLogFileInformation.liSeverCRC32 := ServerCRC32;
  sSend(s, ServerLogFileInformation, SizeOf(TLogFileInformation), dmLogInfo);
end;

function ClearServerLog: boolean;
begin
  Result := False;
  if not OpenServerLog(OPEN_EXISTING) then Exit;
  ServerLog.Seek(SizeOfTLogHeader, soBeginning);
  ServerLog.Size := ServerLog.Position;
  DisplayServerLogSize;
  CloseServerLog;
  ScanLogForSerialsNumbers;
  Result := True;
end;

procedure WriteToServerDebugFile(Count: Cardinal; s: TSocket; comment: PChar; mt: DebugMessageType);
var
  h                                     : HWND;
  lpNumberOfBytesWritten                : Cardinal;
  line                                  : AnsiString;
begin
{$IF SERVERDEBUG}
  if not ServerDebugMode then Exit;
  (* THE DEBUG FILE, APPENDED THROUGH A STREAM.

    Was CreateFile + SetFilePointer(FILE_END) + WriteFile + CloseHandle. Only
    compiled under SERVERDEBUG, which is why it outlived the rest. *)
  if FileExists(String(PAnsiChar(@ServerDebugFileName[0]))) then
     begin
     dbg := TFileStream.Create(String(PAnsiChar(@ServerDebugFileName[0])),
                               fmOpenWrite or fmShareDenyNone);
     end
  else
     begin
     dbg := TFileStream.Create(String(PAnsiChar(@ServerDebugFileName[0])),
                               fmCreate or fmShareDenyNone);
     end;
  if h = INVALID_HANDLE_VALUE then Exit;
  dbg.Seek(0, soEnd);

  // Was six manual pushes, a wsprintf, and `add esp,32` to unwind. Three
  // separate defects came out with the assembly, none of which the compiler
  // could report because SERVERDEBUG is False and this never compiled:
  //
  //   - `Time` was a local PChar that was NEVER ASSIGNED. The leading %s
  //     formatted whatever happened to be on the stack. It now carries the
  //     timestamp the column was obviously meant to hold.
  //   - TempBuffer was array[0..255] of Char, i.e. WideChar under D12, but
  //     `stored` is a CHARACTER count and WriteFile takes BYTES -- so it wrote
  //     half the line, as UTF-16, into a text log.
  //   - wsprintf into a fixed 256-element buffer with a caller-supplied
  //     `comment` had no bound.
  line := AnsiString(Format('%s  Client: %-6u   Bytes: %-7u  RX: %-7d  TX: %-7d   %s'#13#10,
     [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), s, Count,
      BytesRCVD, BytesSEND, string(comment)]));

  dbg.WriteBuffer(PAnsiChar(line)^, Length(line));
  dbg.Free;
{$IFEND}
end;

procedure SendDisconnectMessage(Client: AnsiChar);
var
  i                                     : Cardinal;
begin
  for i := 1 to maxclients do
    if ClientsSoocketsArray[i].clSocket <> 0 then
       begin
       ServerMessage.smMessage := SM_DISCONECT_CLIENT_MESSAGE;
       ServerMessage.smParam := integer(Client);
       sSend(ClientsSoocketsArray[i].clSocket, ServerMessage, SizeOf(ServerMessage), dmDisc);
       Sleep(0);
       end;
end;

{ Tell one station its id is not available and leave it unidentified.

  IT IS NOT DISCONNECTED HERE.  The socket is the server's only handle on a
  client and tearing it down races the send; the client latches on this message
  and drops itself, which is also what lets it say something useful to the
  operator.  A client that ignores the message stays connected WITHOUT an id,
  which is exactly where every client sits between connecting and announcing --
  so the failure mode is the status quo, not something new. }
procedure RefuseComputerID(s: TSocket; ID: AnsiChar; const aWhy: string);
begin
  ServerMessage.smMessage := SM_COMPUTERID_IN_USE_MESSAGE;
  ServerMessage.smParam := Ord(ID);
  sSend(s, ServerMessage, SizeOf(ServerMessage), dmDisc);
  logger.Warn('Refused computer ID %s (%s): %s',
              [ComputerIDLetter(ID), aWhy, 'station left unidentified']);
end;

{ WHAT THIS USED TO BE: three lines that stored the letter and asked nothing.

  The server has held every connected station's id in one array all along, and
  never compared them -- clID was written here and read in exactly ONE other
  place in the whole program, SendDisconnectMessage.  So a second station
  claiming a letter already in use was accepted in silence, and the damage
  landed on the CLIENTS: StatusArray is INDEXED by the id (uNet.pas:331), so the
  two stations become one row on every machine in the network, and three
  separate "is this QSO mine?" tests -- MainUnit, LOGEDIT, and the Cabrillo
  transmitter-id column in PostUnit -- start attributing one station's QSOs to
  the other.  Nothing anywhere reports it and the log looks correctly merged.

  FIRST COME, FIRST SERVED.  The station already holding the id is operating;
  the one that just arrived is not.  Disturbing the wrong one of those in the
  middle of a contest would be worse than the collision. }
procedure SetComputerID(ID: AnsiChar; s: TSocket);
var
  i                                     : integer;
  mine                                  : integer;
  taken                                 : TComputerIDSet;
  { Which slot holds each id, so the refusal can name the station that has it.
    An address is worth more to the operator than "some other station". }
  holder                                : array[FIRST_COMPUTER_ID..LAST_COMPUTER_ID] of integer;
begin
  FillChar(holder, SizeOf(holder), 0);
  mine := 0;
  for i := 1 to maxclients do
    if ClientsSoocketsArray[i].clSocket = s then
       begin
       mine := i;
       Break;
       end;

  if mine = 0 then
     begin
     { A socket with no slot.  Nothing to record it against, and refusing it
       would send to a client the server does not believe in. }
     Exit;
     end;

  { WHICH IDS ARE ACTUALLY TAKEN.  Only CONNECTED slots count, and this
    station's own slot is excluded -- DeleteSocketFromArray clears clSocket and
    leaves clID standing, so counting either would refuse a station reclaiming
    the letter it held before its own reconnect.  Locking an operator out of his
    own network would be a worse defect than the one being fixed. }
  taken := [];
  for i := 1 to maxclients do
     begin
     if (i <> mine) and (ClientsSoocketsArray[i].clSocket <> 0) and
        (Ord(ClientsSoocketsArray[i].clID) in
           [FIRST_COMPUTER_ID..LAST_COMPUTER_ID]) then
        begin
        Include(taken, Ord(ClientsSoocketsArray[i].clID));
        holder[Ord(ClientsSoocketsArray[i].clID)] := i;
        end;
     end;

  case JudgeComputerID(ID, taken) of
     cidOutOfRange:
        begin
        RefuseComputerID(s, ID, 'not a letter A..Z');
        Exit;
        end;

     cidInUse:
        begin
        RefuseComputerID(s, ID, 'already held by ' +
           string(PAnsiChar(@ClientsSoocketsArray[holder[Ord(ID)]].clIPAdr[0])));
        Exit;
        end;
  end;

  ClientsSoocketsArray[mine].clID := ID;
  logger.Debug('Computer ID %s accepted for client %d',
               [ComputerIDLetter(ID), mine]);
end;

procedure SetStatus(Status: TClientStatus; s: TSocket);
var
  i                                     : integer;
begin
  for i := 1 to maxclients do
    if ClientsSoocketsArray[i].clSocket = s then
       begin
       ClientsSoocketsArray[i].clConnectedToTelnet := Status.csTelnet;
       Break;
       end;
end;

procedure SendSpotViaNet(Status: TSendSpotViaNetwork; s: TSocket);
var
  i                                     : integer;
begin
  for i := 1 to maxclients do
    if ClientsSoocketsArray[i].clConnectedToTelnet then
      if ClientsSoocketsArray[i].clSocket <> s then
         begin
         sSend(ClientsSoocketsArray[i].clSocket, Status, SizeOf(Status), dmSpotViaNet);
         Break;
         end;
end;

function CorrectPassword(s: TSocket; BytesReceived: integer): boolean;
var
  i                                     : integer;
  Offset                                : integer;
begin
  Offset := 0;
  if BytesReceived > 10 then
     begin
     if PInteger(@ServerBuffer[0])^ = 542393671 {'GET '} then
       if PInteger(@ServerBuffer[6])^ = 1397965136 {'PASS'} then
           //          MessageBox(ApplicationHandle, @ServerBuffer, _TR4WSERVER, MB_OK or MB_ICONWARNING or MB_TOPMOST);
          begin
          Offset := 11;
          end;
     end;
  Result := False;
  for i := 0 to 9 do
    if ServerBuffer[i + Offset] <> tr4wServerPassword[i] then
       begin
       sSend(s, PASSTR4W, SizeOf(PASSTR4W), dmPass);
       Exit;
       end;
  Result := True;
end;

(* THE LOG'S CRC, READ INTO MEMORY INSTEAD OF MAPPED.

  Was CreateFileMapping + MapViewOfFile over the whole file, for a read-only
  scan. Memory mapping is a Win32 API with no portable equivalent worth the
  conditional, and it bought nothing here: the CRC has to touch every byte
  anyway, so a read is the same work without the mapping.

  A contest log is a few megabytes -- 376 bytes per QSO, so ten thousand QSOs
  is under four -- which is why holding it is reasonable. If that ever stops
  being true the answer is a chunked CRC, not a mapping. *)
procedure GetServerLogCRC32;
var
  buf: TBytes;
begin
  if not ServerCRC32Changed then Exit;
  ServerCRC32 := 0;
  if not OpenServerLog(OPEN_EXISTING) then Exit;
  try
     SetLength(buf, ServerLog.Size);
     if Length(buf) > 0 then
        begin
        ServerLog.Position := 0;
        ServerLog.ReadBuffer(buf[0], Length(buf));
        ServerCRC32 := uCRC32.GetCRC32(buf[0], Length(buf));
        end;
     ServerCRC32Changed := False;
  finally
     CloseServerLog;
  end;
end;

(* THE WIRE WRITE, THROUGH INDY. Was WinSock's Send() on a raw handle; the
  handle is still how the engine names a client, and uServerNet turns it back
  into a connection. Everything else here -- the byte accounting, the readout,
  the debug file -- is unchanged. *)
function sSend(s: TSocket; var buf; Len: integer; mt: DebugMessageType): integer;
begin
  Result := SendToClient(s, buf, Len);
  BytesSEND := BytesSEND + DWORD(Result);
  DisplaySENDBytes;
{$IF SERVERDEBUG}
  WriteToServerDebugFile(Result, s, nil, mt);
{$IFEND}

end;
function tUpdateServerLog(UpdAction: UpadateAction): boolean;
label
  1, 2, 3;
var
  MapFin                                : Cardinal;
  MapBase                               : Pointer;
  RescoredRXData                        : ContestExchangePtr;
  LogSize                               : Cardinal;
  QSOCounter                            : Cardinal;
  LogBuf                                : TBytes;
begin
  Result := False;
  if not OpenServerLog(OPEN_EXISTING) then Exit;

  (* READ, MODIFY, WRITE BACK -- instead of mapping the file.

    This was CreateFileMapping + MapViewOfFile over the whole log, walked with
    pointer arithmetic and flushed with FlushViewOfFile. Memory mapping is
    Win32 with no portable equivalent worth a conditional, and what it was
    doing is a read-modify-write of every QSO record.

    The walk below is UNCHANGED -- same pointer arithmetic, same labels, same
    per-record rules -- it just runs over a buffer this routine owns rather
    than over a view of the file. The write-back is at the end, and only when
    something actually changed. *)
  LogSize := ServerLog.Size;

  if LogSize <= SizeOf(TLogHeader) then
     begin
     goto 2;
     end;
  LogSize := ((LogSize - SizeOf(TLogHeader)) div SizeOfContestExchange);
  QSOCounter := 0;

  SetLength(LogBuf, ServerLog.Size);
  ServerLog.Position := 0;
  ServerLog.ReadBuffer(LogBuf[0], Length(LogBuf));

  RescoredRXData := Pointer(PByte(@LogBuf[0]) + SizeOfTLogHeader);

  1:

  if RescoredRXData^.ceRecordKind = rkQSO then
     begin
     if UpdAction = actSetClearDupesheetBit then
        begin
        RescoredRXData^.ceClearDupeSheet := True;
        end;

     if UpdAction = actClearMults then
        begin
        RescoredRXData^.ceClearMultSheet := True;
        RescoredRXData^.DomesticMult := False;
        RescoredRXData^.DXMult := False;
        RescoredRXData^.PrefixMult := False;
        RescoredRXData^.ZoneMult := False;
        end;

     end;
  inc(QSOCounter);
  if QSOCounter <> LogSize then
     begin
     // Issue #997: asm advance-by-one-record -> explicit pointer arithmetic.
     RescoredRXData := Pointer(Cardinal(RescoredRXData) + SizeOfContestExchange);
     goto 1;
     end;

  Result := True;
  ServerCRC32Changed := True;

  { Back to disk in one write, then flushed -- FlushViewOfFile's job. }
  ServerLog.Position := 0;
  ServerLog.WriteBuffer(LogBuf[0], Length(LogBuf));
  FileFlush(ServerLog.Handle);

  2:
  CloseServerLog;

end;

procedure SendConfirmMessage(s: TSocket);
begin
  ServerMessage.smMessage := SM_RECEIVED_UPDATED_QSO_MESSAGE;
  sSend(s, ServerMessage, SizeOf(ServerMessage), dmROLQ);
end;

function ServerMessageBox(const Text: string; uType: UINT): integer;
begin
  (* THE LCL'S DIALOG, NOT MessageBoxW.

    uType carried Win32 MB_* flags. Only two shapes were ever used -- a warning
    with OK, and a yes/no question -- so the flag is read for MB_YESNO and
    everything else is an OK box. The result is still IDYES/IDNO/IDOK because
    the callers compare against those. *)
  if (uType and MB_YESNO) = MB_YESNO then
     begin
     if MessageDlg(String(_TR4WSERVER), Text, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
        begin
        Result := IDYES;
        end
     else
        begin
        Result := IDNO;
        end;
     end
  else
     begin
     MessageDlg(String(_TR4WSERVER), Text, mtWarning, [mbOK], 0);
     Result := IDOK;
     end;
end;

procedure ScanLogForSerialsNumbers;
label
  Next;
var
  i                                     : Cardinal;
  NextNumberToSend                      : integer;
begin
  if not SerialNumberLockoutEnable then Exit;
  if not OpenServerLog(OPEN_EXISTING) then Exit;
  NextNumberToSend := 0;

  ServerLog.Seek(SizeOf(ContestExchange), soBeginning);
  Next:
  i := ServerLog.Read(TempCE, SizeOf(ContestExchange));
  if i = SizeOf(ContestExchange) then
     begin
     if NextNumberToSend < TempCE.NumberSent then
        begin
        NextNumberToSend := TempCE.NumberSent;
        end;
     goto Next;
     end;
  CloseServerLog;

  NextNumberToSend := NextNumberToSend + 1;

  for i := 1 to MAXCLIENTS do
     begin
     ClientsSoocketsArray[i].clSerialNumber := NextNumberToSend;
     ClientsSoocketsArray[i].clSerialNumberStatus := sntFree;
     end;
  SerialNumbersChanged;
end;

procedure SerialNumbersChanged;
var
  i                                     : integer;
begin
  if not SerialNumberLockoutEnable then Exit;
  for i := 1 to maxclients do
     begin
     if ClientsSoocketsArray[i].clSocket <> 0 then
       if ClientsSoocketsArray[i].clSerialNumberStatus = sntFree then
          begin
          ServerMessage.smMessage := SM_SERIAL_NUMBER_CHANGED;
          ServerMessage.smParam := ClientsSoocketsArray[i].clSerialNumber;
          sSend(ClientsSoocketsArray[i].clSocket, ServerMessage, SizeOf(ServerMessage), dmROLQ);
          end;
     end;
end;

procedure UpdateSerialNumbersStatus(s: TSocket; Status: TSerialNumberType);
var
  i                                     : integer;
begin
  if not SerialNumberLockoutEnable then Exit;
  for i := 1 to maxclients do
     begin
     if ClientsSoocketsArray[i].clSocket = s then
        begin
        ClientsSoocketsArray[i].clSerialNumberStatus := Status;
        Break;
        end;
     end;

  if Status = sntReserved then
     begin
     for i := 1 to maxclients do
        begin
        inc(ClientsSoocketsArray[i].clSerialNumber);
        end;
     end;

  SerialNumbersChanged;

end;

end.
{

Serial number server

N1MM logger supports a single sequence of serial numbers for SO2R, MS, M2 and MM.

The serial number is reserved in
S&P mode when the cursor leaves the callsign field or the Exchange key (F2 default) is sent.
Either through spacing, tabbing, or hitting Enter in ESM or pressing the Exchange key.
This is needed so you can enter calls to check for dupes while not reserving a serial number.
RUN mode as soon as you enter a letter in the call-sign field.
This because on SSB people frequently talk before they type, and they need to see the serial number displayed earlier. A serial number is not assigned in S&P mode until the space bar is pressed, so you can do dupe and check multipliers without committing a serial number to it, by entering it in the callsign field without pressing [Enter] or [Space].
In SO2R and SO2V, doing Alt+W (wipe) after a serial number has been reserved or wipe through QSY will "un-reserve" that number.

Because of the way the serial number server works, there are a couple of cautions:
Serial numbers issued by the second radio may be out of time sequence with those issued by the main one. This occurs because certain program actions cause a serial number to be reserved for the use of a station, and if that station does not use that number until after the other station has made several QSOs, when the log is viewed in chronological order the serial number will appear to be out of order. I don't think there is anything to be done about this.
For similar reasons, depending on operator actions at one or the other station, such as shutting down the program while a number is reserved, there may be some gaps (numbers not issued) when reviewing the final log.
The most important aspects of serial numbering are that the serial sent to a station be correctly logged, and that there be no duplicate serial numbers sent; N1MM logger seems to meet both these criteria.
Sometimes it's possible a number will be skipped when given out but not used (example: QSO not made after all or deleted). Contest committees do accept this behavior!.
The maximum sent number to give is 32767. The maximum receive number is 99999.
 Most sponsors are more interested in serial number accuracy than in serial number time order. If you think about it, it is impossible to guarantee the order of serial numbers in a two radio situation. This assumes that you always log the time when the QSO is added to the log, which is the right time from a rules point of view. i.e. end of contact.
Addendum by Steve, N2IC
Let me say a few words about the way serial numbers are "reserved" in N1MM Logger. For the sake of this discussion, I'll assume that ESM is being used.

When you enter a callsign in the Entry Window, and hit the Enter or Space key, a serial number is reserved and locked-in to that QSO. If it turns out that the QSO is not completed and logged, that serial number is "lost", and will be not used for a subsequent QSO.

This gets to be especially interesting with SO2R and SO2V. Let's say you are running on Radio 1, and search-and-pouncing on Radio 2. You enter a call on Radio 2, and hit the Enter key, reserving a serial number on Radio 2. You get beaten out on Radio 2, and go back to running stations on Radio 1, advancing the serial number beyond the number reserved on Radio 2. A few minutes pass, and you finally work the station on Radio 2. Your log now appears to have non-sequential serial numbers. If you never work that station on Radio 2, the reserved serial number on Radio 2 is lost, and will not be used for any subsequent QSO.

I can't speak for all contest sponsors, but for Sweepstakes and CW/SSB WPX, this is not an issue. There is no problem for these log adjudicators if your serial numbers are out-of-sequence, or if there are missing serial numbers in your log. Your log will be correctly processed. In addition, the N1MM Logger Summary window reports the correct number of successfully completed QSO's.

In summary, stop fretting about out-of-sequence or missing serial numbers. The software is working as designed
}


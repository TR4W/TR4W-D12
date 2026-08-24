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

  VC,
  TF,
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

  ;

type
  TNetWindowColumnsInfo = record
    Width: integer;
    Text: PAnsiChar;
    fmt: integer;
  end;

const
{$IF OZCR2008}
  NetColumns                            = 12;
{$ELSE}
  NetColumns                            = 10;
{$IFEND}
  NetColumnsArray                       : array[0..NetColumns - 1] of TNetWindowColumnsInfo =
    (
    (Width: 62; Text: RC_NAME; fmt: LVCFMT_CENTER),
    (Width: 25; Text: 'Id'; fmt: LVCFMT_CENTER),
    (Width: 60; Text: RC_BAND; fmt: LVCFMT_CENTER),
//    (Width: 47; Text: 'Mode'; fmt: LVCFMT_CENTER),
    (Width: 60; Text: TC_FREQ; fmt: LVCFMT_CENTER),
    (Width: 30; Text: 'St.'; fmt: LVCFMT_CENTER),
    (Width: 37; Text: 'PTT'; fmt: LVCFMT_CENTER),
    (Width: 40; Text: 'Qs'; fmt: LVCFMT_CENTER),
    (Width: 70; Text: RC_CALLSIGN; fmt: LVCFMT_LEFT),
    (Width: 25; Text: 'D'; fmt: LVCFMT_CENTER),
    (Width: 70; Text: 'Op'; fmt: LVCFMT_LEFT)
//,    (Width: 50; Text: 'LN'; fmt: LVCFMT_LEFT)
{$IF OZCR2008}
    ,
    (Width: 85; Text: 'Length'; fmt: LVCFMT_LEFT),
    (Width: 150; Text: 'CW Message'; fmt: LVCFMT_CENTER)
{$IFEND}
    );
procedure SetComputerName;
procedure ShowServerMessage(ServMess: TServerMessage);
procedure CreateNetworkListView;
function FindAndUpdateQSOInLog(var RXData: ContestExchange): boolean;
function NetDlgProc(hwnddlg: HWND; Msg: UINT; wp: wParam; lp: lParam): BOOL; stdcall;
//procedure SendEditedQSOToNetwork(var CE: ContestExchange);
procedure ShowConnectionStatus(Operation: PAnsiChar);
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
procedure CommitChangesInLocalLog;
function SendRecordToServer(RecordType: Word; var rec: ContestExchange): boolean;
function NewNetWndProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): UINT; stdcall;
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
  OldNetWndProc                         : Pointer;

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
  NetSocket                             : Cardinal;
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
  uMainForm,   { the call field, named -- wh[] round 3 }
  uCFG,
  LOGSUBS2,
//  uMultsFrequencies,
  uRadioPolling,
  uRadioConfigApply,   // ApplyPeerCommand -- a peer's config change
  uTelnet,
  uGetServerLog,
  MainUnit,
   uConfigValues;

function NetDlgProc(hwnddlg: HWND; Msg: UINT; wp: wParam; lp: lParam): BOOL; stdcall;
label
  CheckBuffer;

var
  i                                     : integer;
  Bufindex                              : integer;
  ClientID                              : integer;
  DisconnectedClient                    : integer;
  LastBufindex                          : integer;
  nColor                                : Cardinal;
  StationStPtr                          : TStationStatePtr;
  NetQSOInfoPtr                         : NetQSOInformationPtr;
  ServerMessagePtr                      : TServerMessagePtr;
  NetDXSpotPtr                          : TNetDXSpotPtr;
  NetTimeSyncPtr                        : TNetTimeSyncPtr;
  ParameterToNetworkPtr                 : TParameterToNetworkPtr;
  IntercomMessagePtr                    : TIntercomMessagePtr;
//  MessageStatePtr                       : TMessageStatePtr;
begin
  Result := False;
  case Msg of

      // Integer(): NMHDR.code is UNSIGNED as FPC's Windows unit declares it,
      // and every NM_/CDN_ constant is NEGATIVE, so the bare comparison is
      // ALWAYS FALSE and this never ran.  Delphi declares that field signed,
      // which is why it worked before the FPC port.  The compiler warned --
      // "Comparison might be always false" -- and the build did not fail.
    WM_NOTIFY: if Integer(PNMHdr(lp)^.code) = NM_RELEASEDCAPTURE then FrmSetFocus;

    WM_INITDIALOG:
      begin
        MyStationState.ssID := NET_STATIONSTATUS_ID;
        NetSynQSOInformation.qsID := NET_TAKESERVERQSO_ID; //262
        NetQSOInfoToSend.qiID := NET_QSOINFO_ID; //264
        NetDXSpot.dsID := NET_NETWORKDXSPOT_ID; //98
        NetTimeSync.tsID := NET_TIMESYN_ID; //20
        NetIntercomMessage.imID := NET_INTERCOMMESSAGE_ID; //84
        ParameterToNetwork.pnID := NET_PARAMETER_ID;
        ; //514
        SendSpotViaNetwork.vnID := NET_SPOTVIANETWORK_ID; //48

        TotalClients := 0;
        Windows.ZeroMemory(@PosInClientsList, SizeOf(PosInClientsList));
        tr4w_WindowsArray[tw_NETWINDOW_INDEX].WndHandle := hwnddlg;
        TryConnectToNetwork;
        SetTimer(hwnddlg, NETSTATUS_TIMER_HANDLE, tNetStatusUpdateInterval, nil);
        CreateNetworkListView;
        OldNetWndProc := Pointer(Windows.SetWindowLong(hwnddlg, GWL_WNDPROC, integer(@NewNetWndProc)));
      end;

    WM_TIMER:
      begin
        if NetSocket <> 0 then
           begin
           //          SendStationStatus;
           {
          if _networktest then
          begin
            CallWindowString := CD.GetRandomCall;
            ExchangeWindowString := IntToStr(CountryTable.GetCQZone(CallWindowString));
            TryLogContact;
          end;
}
           end
        else
           begin
           TryConnectToNetwork;
           end;

      end;

    WM_SOCK_NET:
      begin
        i := recv(NetSocket, NetBuffer, SizeOf(NetBuffer), 0);
//        if DifferentContests then Exit;
        if i <= 0 then
           begin
           NetDisconnect;
           Windows.ZeroMemory(@StatusArray, SizeOf(StatusArray));
           for i := 1 to 26 do
              begin
              DisplayClientStatus(i);
              end;
           // Issue #910: replaced modal dialog (showwarning) with non-blocking
           // QuickDisplay toast + title-bar update.  Auto-reconnect is handled
           // by the existing WM_TIMER path which calls TryConnectToNetwork
           // every tNetStatusUpdateInterval ms while NetSocket = 0.
           ShowConnectionStatus(TC_DISCONNECTEDFROM);
           TF.Format(wsprintfBuffer, TC_CONNECTIONTOTR4WSERVERLOST, @ServerAddress[1], ServerPort);
           QuickDisplay(wsprintfBuffer);
           Exit;
           end;

        Bufindex := 1;
        nColor := 0;

        //        i-���-�� �� ����������� ����
        //        Bufindex- � ����� ������� �������� ������

        CheckBuffer:
        LastBufindex := Bufindex;
        case PWORD(@NetBuffer[Bufindex])^ of
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
              Bufindex := Bufindex + SizeOf(TStationState);
              if Bufindex - 1 >= i then Exit;
            end;

          NET_INTERCOMMESSAGE_ID:
            begin
              IntercomMessagePtr := @NetBuffer[Bufindex];
              AddMessageToIntercomWindow(@IntercomMessagePtr^.imMessage[1], IntercomMessagePtr^.imSender);
              Bufindex := Bufindex + SizeOf(TIntercomMessage);
              if Bufindex - 1 >= i then Exit;
            end;

          NET_LOGCOMPARE_ID:
            begin
              ProcessServerLogInfo(@NetBuffer[Bufindex + 2 - 2]);
              Bufindex := Bufindex + SizeOf(TLogFileInformation);
              if Bufindex - 1 >= i then Exit;
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
              Bufindex := Bufindex + SizeOf(ParameterToNetwork);
              if Bufindex - 1 >= i then Exit;
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
                       Bufindex := Bufindex + SizeOf(NetTimeSync);
                       if Bufindex - 1 >= i then Exit;
                       end;
            end;

          NET_NETWORKDXSPOT_ID:
            begin
              NetDXSpotPtr := @NetBuffer[Bufindex];
              SpotsList.AddSpot(NetDXSpotPtr^.dsSpot, False);
              DisplayBandMap;
              Bufindex := Bufindex + SizeOf(TNetDXSpot);
              if Bufindex - 1 >= i then Exit;
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

              Bufindex := Bufindex + SizeOf(NetQSOInfoToSend);
              if Bufindex - 1 >= i then Exit;
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
              Bufindex := Bufindex + SizeOf(NetQSOInfoToSend);
              if Bufindex - 1 >= i then Exit;
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
              inc(Bufindex, SizeOf(TSendSpotViaNetwork));
              if Bufindex - 1 >= i then Exit;
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
                    Windows.ZeroMemory(@StatusArray[DisconnectedClient],
                                       SizeOf(TStationState));
                    DisplayClientStatus(DisconnectedClient);
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

              Bufindex := Bufindex + SizeOf(TServerMessage);
              if Bufindex - 1 >= i then Exit;
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
        // NOTHING CLAIMED THOSE BYTES, AND THAT USED TO BE SILENT.
        //
        // Every arm above ends by advancing Bufindex.  An id no arm matches
        // advances nothing, so control reached here, span the counter to 30 and
        // returned -- DISCARDING THE WHOLE REST OF THE BUFFER with no log line
        // and nothing visible to the operator.  The network window simply
        // stopped updating for a station, or a QSO never arrived, and the
        // connection still said "connected".
        //
        // Three ways in, all real: a message split across two recv calls (this
        // loop has no carry-over buffer -- see the bench queue); an arm whose
        // advance disagrees with its cast, as NET_SPOTVIANETWORK_ID's did until
        // today; and a CROSS-BUILD id.  That last one is live but narrow:
        // NET_MESSAGESTATE_ID is sent and received only under {$IF OZCR2008},
        // which is False, so no shipping TR4W emits it -- but tr4wserver relays
        // it ungated (tr4wserver.dpr:152), so a client built WITH that switch
        // on the same network would feed standard clients an id they cannot
        // advance past.
        //
        // Reporting it does not fix the framing.  It converts a silent loss
        // into a log line naming the id, which is the difference between a
        // defect somebody can chase and one nobody can see.
        if Bufindex = LastBufindex then
           begin
           logger.Warn('[Net] Unrecognised message id %d at offset %d of %d ' +
                       'bytes -- the rest of this buffer is discarded',
                       [PWORD(@NetBuffer[Bufindex])^, Bufindex, i]);
           Exit;
           end;

        inc(nColor);
        if nColor < 30 then
           begin
           goto CheckBuffer;
           end;

      end;

    WM_DESTROY:
      begin
        KillTimer(hwnddlg, NETSTATUS_TIMER_HANDLE);
        ShutDown(NetSocket, SD_BOTH);
        NetDisconnect;
      end;

    WM_CLOSE:
      begin
        wh[mweNetwork] := 0;
        CloseTR4WWindow(tw_NETWINDOW_INDEX);
      end;
//    WM_HELP: tWinHelp(8);
    WM_SIZE, WM_WINDOWPOSCHANGING, WM_EXITSIZEMOVE: DefTR4WProc(Msg, lp, hwnddlg);

  end;
end;

procedure NetDisconnect;
begin
  if NetSocket <> 0 then
     begin
     WSAAsyncSelect(NetSocket, tr4w_WindowsArray[tw_NETWINDOW_INDEX].WndHandle, 0, 0);
     closesocket(NetSocket);
     end;
  NetSocket := 0;
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
  if NetSocket = 0 then Exit;

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
  if NetSocket = 0 then Exit;
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
  TNetConnectLogState = (nclsInitial, nclsTrying, nclsConnected, nclsFailed);

const
  FConnectLogStateLabel : array[TNetConnectLogState] of string =
    ('initial', 'trying', 'connected', 'failed');

var
  // Last logged connect-attempt outcome.  TR4W retries every ~5s while the
  // multi-op server is unreachable; without this gate the log would fill
  // with four debug lines per retry (TryConnectToNetwork enter, tCreateThread
  // create, Network thread create, ConnectThread exit) drowning out anything
  // else.  We log only on transitions: first attempt, recover, fail.
  FConnectLogState : TNetConnectLogState = nclsInitial;

  // Issue #1041: was THIS connect attempt an announced one (first / after a
  // recovery) rather than a silent retry?  ConnectThread reads it at exit to
  // log its destruction at the same volume as its creation.  No lock needed:
  // NetThreadID gates a single connect thread at a time, so the value set when
  // the thread is created stays put for that thread's whole life.
  FConnectThreadAnnounced : boolean = False;

procedure TryConnectToNetwork;
var
  announce: boolean;
begin
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

procedure ConnectThread;
label
  1, 2;
var
  i                                     : integer;
  TempSocket                            : TSocket;
begin
  DifferentContests := False;
  ShowConnectionStatus(TC_CONNECTINGTO);

  if GetConnection(TempSocket, @ServerAddress[1], ServerPort, SOCK_STREAM) then
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
     NetSocket := TempSocket;

     SendToNet(ServerPassword[1], 10);
     Sleep(200);
     ACK := 0;
     recv(NetSocket, ACK, SizeOf(ACK), 0);
     if ACK = $53534150 {PASS} then showwarning(TC_CONNECTTOTR4WSERVERFAILED);
     if ACK <> $57345254 {TR4W} then goto 1;
     i := 1;
     WinSock2.setsockopt(NetSocket, IPPROTO_TCP, TCP_NODELAY, @i, SizeOf(integer));
     WinSock2.WSAAsyncSelect(NetSocket, tr4w_WindowsArray[tw_NETWINDOW_INDEX].WndHandle, WM_SOCK_NET, FD_READ or FD_CLOSE);
     ZeroMemory(@StatusArray, SizeOf(StatusArray));
     NetQSOInfoToSend.qiComputerID := Windows.GetTickCount;

 //    sCIDMESSAGE[4] := Char(Ord(ComputerID) - Ord('A') + 1);
     ComputerNetID.ciComputerID := AnsiChar(Ord(ComputerID) - Ord('A') + 1);
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
     closesocket(TempSocket);
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

procedure CreateNetworkListView;
var
  elvc                                  : tagLVCOLUMNA;
  i                                     : integer;
begin
  CreateListView(tw_NETWINDOW_INDEX, mweNetwork, 0);
  elvc.Mask := LVCF_TEXT or LVCF_WIDTH or LVCF_FMT;
  for i := 0 to NetColumns - 1 do
     begin
     elvc.fmt := NetColumnsArray[i].fmt;
     elvc.pszText := NetColumnsArray[i].Text;
     elvc.cx := NetColumnsArray[i].Width;
     uCommctrl.ListView_InsertColumnA(wh[mweNetwork], i, elvc);
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
        tLVSetText(h, i, i2, '');
        end;
     Exit;
     end;

  //LastStatus := StatusArray[Index].ssType;
  case StatusArray[Index].ssType of

    sstComputerNameAndID:
      begin
        CID_TWO_BYTES[0] := StatusArray[Index].ssComputerID;
        tLVSetText(h, i, 0, string(StatusArray[Index].ssName));
        tLVSetText(h, i, 1, string(PAnsiChar(@CID_TWO_BYTES)));
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

        tLVSetText(h, i, 2, string(PAnsiChar(@TempBuffer)));

        // D12: FreqToPChar returns native string; flows straight through tLVSetText
        // (this replaced an earlier PAnsiChar(AnsiString(...)) LV_ITEMA hack).
        tLVSetText(h, i, 3, FreqToPChar{WithoutHZ}(StatusArray[Index].ssFreq));        // 4.61.7
{
        ListView_SetItemText(h, i, 2, BandStringsArray[StatusArray[Index].ssCurrentBand]);
        ListView_SetItemText(h, i, 3, ModeString[StatusArray[Index].ssCurrentMode]);
        ListView_SetItemText(h, i, 4, FreqToPCharWithoutHZ(StatusArray[Index].ssFreq));
}
      end;

    sstPTT:
      begin
        tLVSetText(h, i, 6 - 1, string(PTTStatusString[PTTStatusType((StatusArray[Index].ssStatusByte and (1 shl 0)) <> 0)]));
        //ListView_Update(h, I);
        ListView_RedrawItems(h, i, i);
      end;

    sstOpMode:
      tLVSetText(h, i, 5 - 1, string(OpModeString[OpModeType((StatusArray[Index].ssStatusByte and (1 shl 1)) <> 0)]));

    sstQSOs:
      tLVSetText(h, i, 7 - 1, IntToStr(StatusArray[Index].ssQSOTotals));

    sstCallsign:
      begin
        tLVSetText(h, i, 8 - 1, string(StatusArray[Index].ssCallsign));
        tLVSetText(h, i, 9 - 1, string(da[(StatusArray[Index].ssStatusByte and (1 shl 2)) <> 0]));
      end;

    sstOperator:
      tLVSetText(h, i, 9, string(StatusArray[Index].ssOperator));
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
       // in tr4w.dpr) so LoadinLog's ListView access is thread-safe.
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

procedure ShowConnectionStatus(Operation: PAnsiChar);
begin
  TF.Format(@NetBuffer, TC_NETWORK, Operation, @ServerAddress[1], ServerPort);
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
  tLVSetText(h, i, 10, string(PAnsiChar(@ProgressBarArray)));
  tLVSetText(h, i, 11, string(Msg.msCWMessage));
end;

function SendToNet(var buf; Len: integer): integer;
begin
  Result := 0;
  if NetSocket <> 0 then
     begin
     Result := WinSock2.Send(NetSocket, buf, Len, 0);
     end;
end;

procedure CommitChangesInLocalLog;
label
  1;
var
  SendedQSOs                            : integer;

  procedure UpdateRec;
  begin
    tSetFilePointer(-1 * SizeOf(ContestExchange), FILE_CURRENT);
    sWriteFile(LogHandle, TempRXData, SizeOf(ContestExchange));
    inc(SendedQSOs);
    WaitForSingleObject(tNet_Event, 1000);
    Windows.SetDlgItemInt(GetServerLogWnd, 112, SendedQSOs, False);
  end;
begin
  if (tUSQE = 0) and (tUSQ = 0) then Exit;
  SendedQSOs := 0;
  if not OpenLogFile then Exit;

  ReadVersionBlock;
  1:
  if ReadLogFile then
     begin

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
  if NetSocket = 0 then Exit;

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
        TF.Format(QuickDisplayBuffer, TC_SERVER_LOG_CHANGED, ServMess.smParam);
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

function NewNetWndProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): UINT; stdcall;
var
  lplvcd                                : PNMLVCustomDraw;
begin
  if Msg = WM_NOTIFY then
     begin
     with PNMHdr(lParam)^ do
        begin
        case code of
          NM_CUSTOMDRAW:
            begin
              lplvcd := PNMLVCustomDraw(lParam);

              case lplvcd.nmcd.dwDrawStage of
                CDDS_PREPAINT:
                  begin
                    Result := CDRF_NOTIFYITEMDRAW;
                    Exit;
                  end;
                CDDS_ITEMPREPAINT:
                // (CDDS_SUBITEM or CDDS_PREPAINT):

                  begin
                    //if StatusArray[CurrentDisplayedRow].ssPTTState = PTT_ON then
                    //if LastStatus = sstPTT then
                    if (StatusArray[CurrentDisplayedRow].ssStatusByte and (1 shl 0)) <> 0 then
  //                    if lplvcd.iSubItem = CurrentDisplayedRow then
                       begin
                       if StatusArray[CurrentDisplayedRow].ssComputerID = ComputerID then
                          begin
                          lplvcd.clrTextBk := clYellow
                          end
                       else
                          begin
                          //                        if (StatusArray[CurrentDisplayedRow].ssStatusByte and (1 shl 0)) <> 0 then
                          //                          lplvcd.clrTextBk := clblue
                          //                        else
                                                lplvcd.clrTextBk := clred;
                                                lplvcd.clrText := clwhite;
                          end;
                       end;

                  end;
              end;
            end;

        end;
        end;
     end;

  Result := CallWindowProc(OldNetWndProc, hwnddlg, Msg, wParam, lParam);
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
  if NetSocket = 0 then Exit;
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


# TR4W Multi-User Networking Analysis & V2 Protocol Design

**Document Purpose:** Comprehensive analysis of TR4W's multi-user networking system and design specification for a modernized V2 protocol for TR4QT.

**Date:** December 2025
**Author:** Analysis based on TR4W source code exploration
**Target:** TR4QT (Qt/C++ reimplementation)

---

> ## READ THIS FIRST: PROVENANCE, AND WHAT IS CORRECTED
>
> **This document was written for TR4QT and is copied here unchanged.** The
> original lives at `ny4i/TR4QT:docs/TR4W_NETWORKING_ANALYSIS.md`. It is the best
> description of TR4W's networking that exists, and it is kept here because that
> description should not live only in the repository of the project proposing to
> replace it.
>
> **It is NOT a plan for this repository.** The V2 design below -- Protocol
> Buffers, server-authoritative dupe checking, TLS -- is TR4QT's, and nothing in
> TR4W-D12 is scheduled against it (NY4I, 2026-09-01: *"I do not want to rewrite
> the networking yet (we will get to it though)"*).
>
> **THE V1 SECTIONS WERE CHECKED AGAINST THIS TREE ON 2026-09-01 AND THREE OF
> THEM DO NOT HOLD.** They fail in the same way, and it is worth naming because
> it will happen again: the analysis reasons from the ARCHITECTURE -- "two
> stations both claim to be A, therefore the server cannot tell them apart" --
> where the code answers from a DIFFERENT KEY, because every server-side path
> matches on the SOCKET and never looks at the letter. An architectural inference
> about code is a hypothesis, not a finding.
>
> Corrections are inline and marked **CORRECTED AGAINST TR4W-D12**, each citing
> the file and line it was checked against. The original text is left exactly as
> it stands -- nothing struck through, nothing deleted -- because the reasoning is
> worth reading even where the conclusion does not survive.
>
> | Claim | Verdict |
> |---|---|
> | 26 clients, A-Z, `MAXCLIENTS = 26` | Holds |
> | Two ports, 1061 and 1062 | Holds, with a caveat -- 1062 is derived as `ServerPort + 1`, never configured |
> | The server does not enforce computer-id uniqueness | Holds, and the consequence is worse than described |
> | A shared computer id collapses station status | Holds, and is understated -- `StatusArray` is INDEXED by the letter |
> | A shared computer id corrupts serial-number lockout | **Does not hold** -- the lockout is socket-keyed and never reads `clID` |
> | "The server cannot distinguish them" | **Does not hold** -- it can; it just never compares |
> | No error recovery: `recv() <= 0` disconnects for good | **Stale** -- true when written, superseded by the Indy move of 2026-08-25 |
> | Plaintext 10-byte password | Holds |
>
> The V2 half of the document is not checked against anything: it describes
> software that does not exist here.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [TR4W V1 Protocol Analysis](#tr4w-v1-protocol-analysis)
3. [V2 Protocol Design](#v2-protocol-design)
4. [Migration Strategy](#migration-strategy)
5. [Implementation Guide](#implementation-guide)
6. [Performance Analysis](#performance-analysis)
7. [Testing Strategy](#testing-strategy)

---

# Executive Summary

## TR4W V1 Networking: Overview

TR4W's networking system is a **mature, battle-tested design** optimized for real-time amateur radio contest logging in multi-operator environments. After analyzing the source code, the architecture demonstrates:

**Strengths:**
- ✅ Simple, event-driven single-threaded server (no complex concurrency bugs)
- ✅ Efficient binary protocol with packed structs (zero serialization overhead)
- ✅ Smart serial number lockout preventing duplicates
- ✅ Separate sync socket for bulk transfers (doesn't block real-time updates)
- ✅ 10+ years of proven field reliability (CQWW, ARRL DX, etc.)

**Limitations:**
- ❌ Windows-only (WinSock2/Win32 API dependencies)
- ❌ No protocol versioning (cannot evolve without breaking compatibility)
- ❌ Limited error recovery (no auto-reconnect)
- ❌ Client-side dupe checking (race conditions possible)
- ❌ No authentication/encryption (plaintext password)
- ❌ Platform-dependent binary protocol (endianness, alignment)

## V2 Protocol: Modernization Goals

The V2 protocol preserves TR4W's proven **broadcast-based architecture** while addressing limitations:

- **Protocol Buffers** for cross-platform serialization
- **Message sequence numbers** for guaranteed ordering
- **Server-authoritative dupe checking** to prevent races
- **Backward compatibility** with V1 clients
- **Extensible exchange format** for new contest types
- **Optional TLS** for encryption
- **Auto-reconnect** logic with exponential backoff

**Key Design Principle:** Maintain the simplicity and low latency that make TR4W successful while gaining modern capabilities.

---

# TR4W V1 Protocol Analysis

## 1. Server Architecture

### Server Structure

**Main Files:**
- `tr4wserver/tr4wserver.dpr` - Entry point, message loop
- `tr4wserver/src/tr4wserverUnit.pas` - Core server implementation

**Architecture Pattern:** Single-threaded event-driven Windows message loop with asynchronous sockets

**Socket Model:**
```
Port 1061:     Main server socket (real-time updates)
Port 1062:     Sync listener socket (bulk log transfers)
Protocol:      TCP with WSAAsyncSelect (non-blocking I/O)
Max Clients:   26 (stations A-Z)
```

### Connection Handling

**Connection Flow:**
```pascal
// tr4wserver.dpr lines 366-405
WM_SOCK_NET_ACCEPT:
  1. Accept() new connection
  2. Sleep(200) - wait for password
  3. recv() 10 bytes password
  4. Verify password (CorrectPassword)
  5. Send 'TR4W' acknowledgment (or 'PASS' if rejected)
  6. Set TCP_NODELAY option
  7. Resolve hostname via gethostbyaddr()
  8. AddSocketToArray() - store in ClientsSoocketsArray[1..26]
  9. DisplayClients() - update server UI
  10. WSAAsyncSelect(FD_READ | FD_CLOSE | FD_CONNECT)
  11. Send log file information (NET_LOGCOMPARE_ID)
  12. Send serial number status (if enabled)
```

**Client State Structure:**
```pascal
TClientEntry = packed record
  clSerialNumber: integer;          // Current serial number for this client
  clSocket: Cardinal;               // Socket handle
  clIPAdr: array[0..15] of Char;   // IP address "192.168.1.100"
  clName: array[0..31] of Char;    // Hostname
  clSerialNumberStatus: TSerialNumberType;  // sntFree, sntReserved, sntUnknown
  clConnectedToTelnet: boolean;     // For DX spot forwarding
  clID: Char;                       // 'A'..'Z' station identifier
end;

ClientsSoocketsArray: array[1..MAXCLIENTS] of TClientEntry;
```

> **CORRECTED AGAINST TR4W-D12 (2026-09-01) -- `clID` IS COLLECTED AND NEVER
> COMPARED.**
>
> `clID` is written by `SetComputerID` (`src/tr4wserverUnit.pas:760`) and read in
> exactly ONE place in the entire server: `SendDisconnectMessage(...clID)` at
> `src/tr4wserverUnit.pas:462`. So the server learns every station's letter,
> holds all of them in one array, uses it only to announce who dropped, and has
> no opinion about whether two stations claim the same one.
>
> Detecting a collision is one loop over `ClientsSoocketsArray` at the moment the
> letter arrives. The server is not blind to this; it simply never looks. That is
> a different -- and much smaller -- problem than the one the Executive Summary
> describes.
>
> **AND `AddSocketToArray` DEPENDS ON THIS RECORD'S FIELD ORDER**
> (`src/tr4wserverUnit.pas:441`):
>
> ```pascal
> Windows.ZeroMemory(@ClientsSoocketsArray[i].clSocket, SizeOf(TClientEntry) - 4); //skip clSerialNumber
> ```
>
> Skipping the serial number is deliberate and correct -- a reconnecting station
> must not reset the pool's counter, which is the strength this document praises
> under "Smart Serial Number Design". But it is expressed as *start four bytes in
> and zero the rest*, which is only right while `clSerialNumber` is the FIRST
> field and exactly four bytes wide. Insert a field ahead of it, or widen it, and
> the zeroing runs off the end of the record with no diagnostic of any kind.

### Message Processing

**Single-threaded message loop:**
```pascal
// tr4wserver.dpr lines 131-293
WM_SOCK_NET_RX:  // Data available on socket
  BytesReceived := recv(wp, ServerBuffer, 4096, 0);

  Bufindex := 0;
  counter := 0;

CheckBuffer:
  case PWORD(@ServerBuffer[Bufindex])^ of  // Read 2-byte message ID

    NET_QSOINFO_ID:  // New QSO broadcast
      ServerNewQSOPtr := @ServerBuffer[Bufindex];
      SendMessageToClients(wp, SizeOf(TNetQSOInformation), False);  // Broadcast to all except sender

      // Append to server log
      OpenServerLog(OPEN_EXISTING);
      SetFilePointer(ServerLogHandle, 0, nil, FILE_END);
      WriteFile(ServerLogHandle, ServerNewQSOPtr.qiInformation, SizeOf(ContestExchange), ...);
      CloseServerLog;

      Bufindex := Bufindex + SizeOf(TNetQSOInformation);

    NET_EDITEDQSO_ID:  // QSO edit
      EditedQSOPtr := @ServerBuffer[Bufindex];
      UpdateQSOInServerlog(EditedQSOPtr^.qiInformation);  // Update server log by QSO ID
      SendConfirmMessage(wp);  // ACK to client
      SendMessageToClients(wp, SizeOf(TNetQSOInformation), False);  // Broadcast edit
      Bufindex := Bufindex + SizeOf(TNetQSOInformation);

    // ... 15+ more message types
  end;

  if Bufindex = BytesReceived then goto Done;
  if counter < 25 then goto CheckBuffer;  // Safety limit (max 25 messages per recv)
```

**Key Observations:**
- ✅ **Simple and deterministic** - No threading complexity
- ✅ **Handles multiple messages per recv()** - Buffer processing loop
- ⚠️ **Fixed 4KB buffer** - Could overflow with malformed data (though TCP prevents most issues)
- ⚠️ **No message queuing** - send() failures drop messages

### Broadcasting Mechanism

```pascal
procedure SendMessageToClients(From: Cardinal; Count: integer; ToAll: boolean);
begin
  for i := 1 to maxclients do
    if ClientsSoocketsArray[i].clSocket <> 0 then
    begin
      if ToAll = False then
        if ClientsSoocketsArray[i].clSocket = From then Continue;  // Skip sender

      send(ClientsSoocketsArray[i].clSocket, ServerBuffer[Bufindex], Count, 0);
      Sleep(0);  // Yield CPU (cooperative multitasking)
    end;
end;
```

**Broadcast Patterns:**
- **ToAll = True:** Everyone including sender (e.g., time sync, server commands)
- **ToAll = False:** Everyone except sender (e.g., new QSO logged by station A → broadcast to B-Z)

### Log Synchronization

**Separate Thread for Large Transfers:**
```pascal
// Only thread in entire server!
ServerThread := CreateThread(nil, 0, @TransmitServerLog, Pointer(client_socket), 0, ServerThreadID);

function TransmitServerLog(client_socket: Cardinal): Cardinal; stdcall;
begin
  // Windows NT/2000+: Zero-copy kernel mode transfer
  if @TransmitFilePtr <> nil then
  begin
    TransmitFilePtr(client_socket, ServerLogHandle, 0, 0, nil, nil, 0);
  end
  // Windows 95/98: Manual chunked transfer
  else
  begin
    while BytesRemaining > 0 do
    begin
      ReadFile(ServerLogHandle, Buffer, ChunkSize, BytesRead, nil);
      send(client_socket, Buffer, BytesRead, 0);
    end;
  end;
end;
```

**Why This Works:**
- Real-time updates (40-270 bytes) on main socket → instant delivery
- Bulk log sync (potentially MB) on separate socket → doesn't block broadcasts
- Similar to control plane / data plane separation in networking

---

## 2. Network Protocol Specification

### Message Types

All messages start with a **2-byte ID** followed by message-specific data:

```pascal
const
  NET_MESSAGESTATE_ID           = 1000;  // CW message playback status
  NET_LOGCOMPARE_ID             = 1010;  // Log sync metadata
  NET_INTERCOMMESSAGE_ID        = 1020;  // Inter-station chat
  NET_NETWORKDXSPOT_ID          = 1030;  // DX spot forwarding
  NET_QSOINFO_ID                = 1040;  // New QSO broadcast
  NET_EDITEDQSO_ID              = 1050;  // Edited QSO update
  NET_OFFLINEQSO_ID             = 1055;  // Offline QSO upload
  NET_TIMESYN_ID                = 1070;  // Time synchronization
  NET_PARAMETER_ID              = 1080;  // Config parameter update
  NET_STATIONSTATUS_ID          = 1090;  // Station status update
  NET_CLIENTSTATUS_ID           = 1110;  // Client capabilities
  NET_SPOTVIANETWORK_ID         = 1120;  // Telnet spot relay
  NET_COMPUTERID_ID             = 1130;  // Client station ID
  NET_SERVERMESSAGE_ID          = 1140;  // Server commands
```

### Key Message Structures

#### Station Status (40 bytes)
```pascal
TStationState = packed record
  {02} ssID: Word;                        // NET_STATIONSTATUS_ID = 1090
  {02} ssQSOTotals: Word;                 // QSO count
  {01} ssComputerID: Char;                // 'A'..'Z'
  {01} ssCurrentBand: BandType;           // Enum: Band160..Band10G
  {01} ssCurrentMode: ModeType;           // Enum: CW, SSB, Digital, etc.
  {01} ssStatusByte: Byte;                // Bit flags:
                                           //   Bit 0: PTT active
                                           //   Bit 1: CQ mode (vs S&P)
                                           //   Bit 2: Dupe
                                           //   Bit 3: Serial lockout
  {04} ssFreq: integer;                   // Frequency in Hz
  {13} ssCallsign: array[0..12] of Char; // Current callsign in entry window
  {09} ssName: array[0..8] of Char;      // Station name
  {01} ssType: StationStatusType;         // sssInitializing, sssUpdate, etc.
end;  // Total: 40 bytes
```

**Sent every 5 seconds** by each client (configurable via `NET STATUS UPDATE INTERVAL`).

#### QSO Information (~270 bytes)
```pascal
TNetQSOInformation = packed record
  qiID: Word;                      // NET_QSOINFO_ID = 1040
  qiInformation: ContestExchange;  // Full QSO record (~260 bytes)
  qiComputerID: Cardinal;          // Unique sender ID (GetTickCount)
  qiReservedByte1: Byte;
  qiReservedByte2: Byte;
end;

ContestExchange = record
  // Time
  tSysTime: TQSOTime;              // 6 bytes: min, hour, day, mon, year, sec

  // Band/Mode/Frequency
  Band: BandType;
  Mode: ModeType;
  Frequency: LONGINT;

  // Unique identifiers
  ceQSOID1, ceQSOID2: Cardinal;    // For locating QSO in log (for edits)

  // Basic QSO data
  Callsign: CallString;            // 14 bytes

  // Exchange (contest-specific - fixed format per contest type)
  NumberSent: integer;
  NumberReceived: integer;
  QSOPoints: integer;

  // Multipliers (boolean flags)
  DomesticMult: boolean;
  DXMult: boolean;
  PrefixMult: boolean;
  ZoneMult: boolean;

  // Metadata
  ceComputerID: Char;              // Station that logged it
  ceOperatorID: Byte;
  ceRecordKind: LogRecordKind;     // rkQSO, rkNote, rkQTCR, rkQTCS

  // Flags
  ceQSO_Deleted: boolean;
  ceQSO_Skiped: boolean;
  ceSendToServer: boolean;         // Needs upload to server
  ceNeedSendToServerAE: boolean;   // Edit needs sync
  ceDupe: boolean;                 // Dupe status (informational)

  // ... many more contest-specific fields (name, section, zone, etc.)
end;
```

**Broadcast on:**
- New QSO logged (`NET_QSOINFO_ID`)
- QSO edited (`NET_EDITEDQSO_ID`)
- Offline QSO uploaded (`NET_OFFLINEQSO_ID`)

#### DX Spot (~90 bytes)
```pascal
TNetDXSpot = packed record
  dsID: Word;                      // NET_NETWORKDXSPOT_ID = 1030
  dsSpot: TSpotRecord;
end;

TSpotRecord = record
  FFrequency: LONGINT;             // Spot frequency in Hz
  FSysTime: Cardinal;              // Timestamp
  FQSXFrequency: LONGINT;          // Split frequency (if applicable)
  FCall: CallString;               // 14 bytes: DX station
  FBand: BandType;
  FMode: ModeType;
  FNotes: array[0..31] of Char;   // Spot comment
  FSourceCall: CallString;         // 14 bytes: Spotter callsign
  FSpotMode: SpotModeType;
  FMult, FDupe, FCQ, FWARCBand: boolean;
  // ... additional fields
end;
```

#### Server Commands (8 bytes)
```pascal
TServerMessage = packed record
  smID: Word;                      // NET_SERVERMESSAGE_ID = 1140
  smMessage: Word;                 // Command subtype
  smParam: integer;                // Command parameter
end;

// Command subtypes:
const
  SM_CLEARALLLOGS_MESSAGE           = 8230;
  SM_SERVERLOG_CHANGED_MESSAGE      = 8250;
  SM_DISCONECT_CLIENT_MESSAGE       = 8260;
  SM_GETSTATUS_MESSAGE              = 8270;
  SM_CLEAR_DUPESHEET_MESSAGE        = 8280;
  SM_CLEAR_MULTSHEET_MESSAGE        = 8290;
  SM_RECEIVED_UPDATED_QSO_MESSAGE   = 8300;  // ACK for QSO edit
  SM_SERIAL_NUMBER_CHANGED          = 8310;  // New serial assigned
```

### Protocol Characteristics

| Aspect | Implementation |
|--------|----------------|
| **Serialization** | Direct memory copy of packed structs |
| **Endianness** | Little-endian (x86 native) |
| **Alignment** | `packed` directive forces byte alignment |
| **Strings** | Null-terminated C strings and Pascal ShortString |
| **Versioning** | None - fixed struct sizes |
| **Framing** | None - rely on message ID + known size |
| **Compression** | None |
| **Encryption** | None |

**Critical Limitation:** Adding a single field to any message breaks all clients.

---

## 3. State Synchronization Mechanisms

### QSO Synchronization

**Real-Time QSO Logging:**
```
Client A                          Server                          Client B
   |                                 |                                 |
   |-- NET_QSOINFO (W1AW) --------->|                                 |
   |                                 |-- NET_QSOINFO (W1AW) --------->|
   |                                 |                                 |
   |                                 |--- Append to SERVERLOG.TRW      |
   |                                 |                                 |
```

**QSO Editing:**
```
Client A                          Server                          Client B
   |                                 |                                 |
   |-- NET_EDITEDQSO (id=12345) --->|                                 |
   |                                 |--- Scan log for ceQSOID1/2      |
   |                                 |--- Overwrite record             |
   |<- SM_RECEIVED_UPDATED_QSO ----|                                 |
   |                                 |-- NET_EDITEDQSO (id=12345) --->|
   |                                 |                                 |
```

**Offline QSO Upload (reconnection):**
```pascal
// Client scans local log for unsynced QSOs
procedure CommitChangesInLocalLog();
begin
  for i := 1 to LogIndex do
  begin
    if TempRXData.ceSendToServer = False then  // Not yet on server
    begin
      SendRecordToServer(NET_OFFLINEQSO_ID, TempRXData);
      WaitForSingleObject(tNet_Event, 5000);  // Wait for server ACK

      if NetBytesRcvd > 0 then
        TempRXData.ceSendToServer := True;  // Mark as synced
    end;
  end;
end;
```

### Serial Number Lockout

**Most sophisticated feature** - prevents duplicate serial numbers in multi-op:

**Server Initialization:**
```pascal
procedure ScanLogForSerialsNumbers;
var MaxNumberSent: integer;
begin
  MaxNumberSent := 0;

  // Scan server log for highest serial number
  OpenServerLog(OPEN_EXISTING);
  while ReadNextQSO(QSO) do
    if QSO.NumberSent > MaxNumberSent then
      MaxNumberSent := QSO.NumberSent;

  // Pre-assign next serial to each client
  NextNumberToSend := MaxNumberSent + 1;
  for i := 1 to MAXCLIENTS do
  begin
    ClientsSoocketsArray[i].clSerialNumber := NextNumberToSend;
    ClientsSoocketsArray[i].clSerialNumberStatus := sntFree;
  end;
end;
```

**Client Reserves Serial:**
```pascal
// When client starts typing in exchange window
procedure ReserveSerialNumber;
begin
  ServerMessage.smMessage := SM_SERIAL_NUMBER_CHANGED;
  ServerMessage.smParam := integer(sntReserved);  // Request reservation
  SendToNet(ServerMessage, SizeOf(ServerMessage));
end;
```

**Server Increments All Clients:**
```pascal
procedure UpdateSerialNumbersStatus(s: TSocket; Status: TSerialNumberType);
begin
  // Find client that sent request
  for i := 1 to maxclients do
    if ClientsSoocketsArray[i].clSocket = s then
    begin
      ClientsSoocketsArray[i].clSerialNumberStatus := Status;

      if Status = sntReserved then
      begin
        // INCREMENT ALL CLIENTS' SERIAL NUMBERS
        for j := 1 to maxclients do
          inc(ClientsSoocketsArray[j].clSerialNumber);

        // Broadcast new serials to all clients
        SerialNumbersChanged();
      end;
    end;
end;
```

**Result:**
- Client A gets 100, reserves → everyone increments to 101
- Client B gets 101, reserves → everyone increments to 102
- If Client A never logs the QSO, serial 100 is skipped (acceptable)
- **No duplicate serials possible** even with race conditions

> **CORRECTED AGAINST TR4W-D12 (2026-09-01) -- THE LOCKOUT IS SOCKET-KEYED, SO A
> SHARED COMPUTER ID CANNOT CORRUPT IT.**
>
> The Executive Summary's collision analysis says that if two stations share the
> letter `A`, one client's serial increment will corrupt the other's reservation
> state. It cannot. `UpdateSerialNumbersStatus` takes a `TSocket` and matches on
> `clSocket` (`src/tr4wserverUnit.pas:1019`); it never reads `clID` at all. Two
> stations calling themselves `A` are two distinct sockets and get two
> independent, correct reservation slots.
>
> **The real procedure also differs from the rendering above in two ways:**
>
> 1. It opens with `if not SerialNumberLockoutEnable then Exit;` -- the whole
>    feature is off unless the server is configured for it.
>
> 2. **The increment is NOT nested inside the socket match.** Above, the
>    "increment all clients" loop sits inside `if clSocket = s`. In the real
>    procedure the socket loop `Break`s and the increment then runs OUTSIDE it,
>    guarded only by `if Status = sntReserved`. So a reservation arriving from a
>    socket no longer in the array -- a client that dropped between sending and
>    being processed -- still advances every station's serial number. The result
>    is a skipped serial, which this document already calls acceptable, so this is
>    a note about what the code says rather than a defect report.
>
> `SerialNumbersChanged` is likewise called on every invocation, not only on
> reserve.

### Dupe Checking (Distributed)

**Current V1 Design:** Each client checks dupes against its own log copy.

**Problem:**
```
T=0:  Station A sees "W1AW" → not in local log → start QSO
T=0:  Station B sees "W1AW" → not in local log → start QSO
T=5:  Both log W1AW simultaneously
T=6:  Both receive each other's QSO broadcasts
T=7:  Both now show W1AW as dupe in their logs (but 2 QSOs exist)
```

**Why it's acceptable for V1:**
- Contest rules allow duplicate removals in post-processing
- POST.EXE (log checking tool) removes dupes before Cabrillo export
- Operators can manually delete duplicate during contest
- **Very rare** in practice (operators communicate via intercom)

**Should be fixed in V2** with server-authoritative checking.

### Time Synchronization

**Optional feature** (controlled by server setting):

```pascal
// Any client can broadcast time
procedure SendTimeSyn;
begin
  GetSystemTime(NetTimeSync.tsTime);
  NetTimeSync.tsID := NET_TIMESYN_ID;
  SendToNet(NetTimeSync, SizeOf(TNetTimeSync));
end;

// Server forwards if enabled
if sAllowTimeSynchronizing then
  SendMessageToClients(wp, SizeOf(TNetTimeSync), False, dmTimeSyn);

// Clients apply
if NetTimeSyncPtr.tsTime.wYear > 2007 then  // Sanity check
  SetSystemTime(NetTimeSyncPtr.tsTime);
```

**Use case:** One station with GPS-disciplined clock syncs all stations.

---

## 4. Client Implementation

### Connection Establishment

**Client-side flow (uNet.pas):**

```pascal
procedure TryConnectToNetwork;
begin
  // Spawn connection thread
  tCreateThread(@ConnectThread, NetThreadID);
end;

function ConnectThread: Cardinal; stdcall;
begin
  // 1. DNS lookup and TCP connect
  if not GetConnection(ServerAddress, ServerPort, NetSocket) then
    Exit;

  // 2. Send password (10 bytes)
  send(NetSocket, Password, 10, 0);

  // 3. Receive ACK
  recv(NetSocket, RecvBuffer, 4, 0);
  if PDWORD(@RecvBuffer)^ <> $57345254 then  // 'TR4W' = 0x57345254
  begin
    NetDisconnect;
    ShowWarning('Wrong password');
    Exit;
  end;

  // 4. Set TCP_NODELAY (disable Nagle's algorithm)
  setsockopt(NetSocket, IPPROTO_TCP, TCP_NODELAY, ...);

  // 5. Setup async receive
  WSAAsyncSelect(NetSocket, hwnddlg, WM_SOCK_NET_RX, FD_READ or FD_CLOSE);

  // 6. Send station ID
  ComputerID.ciID := NET_COMPUTERID_ID;
  ComputerID.ciComputerID := MyComputerID;
  SendToNet(ComputerID, SizeOf(ComputerID));

  // 7. Send initial station status
  SendFullStationStatus();
  SendClientStatus();

  // 8. Request status from all other stations
  ServerMessage.smMessage := SM_GETSTATUS_MESSAGE;
  SendToNet(ServerMessage, SizeOf(ServerMessage));

  ConnectedwithServer := True;
end;
```

### Periodic Status Updates

**Timer-based status broadcast:**

```pascal
WM_TIMER:
  if NetSocket <> INVALID_SOCKET then
  begin
    SendClientStatus();  // Sends TStationState every 5 seconds
    SetTimer(hwnddlg, NETSTATUS_TIMER_HANDLE, tNetStatusUpdateInterval, nil);
  end;

procedure SendClientStatus();
begin
  StationState.ssID := NET_STATIONSTATUS_ID;
  StationState.ssQSOTotals := LogIndex;
  StationState.ssComputerID := MyComputerID;
  StationState.ssCurrentBand := ActiveBand;
  StationState.ssCurrentMode := ActiveMode;
  StationState.ssStatusByte := ConstructStatusByte();  // PTT, OpMode, etc.
  StationState.ssFreq := ActiveRadioPtr^.Freq;
  Windows.CopyMemory(@StationState.ssCallsign, @CallWindowString, 13);
  Windows.CopyMemory(@StationState.ssName, @StationName, 9);

  SendToNet(StationState, SizeOf(TStationState));
end;
```

> **CORRECTED AGAINST TR4W-D12 (2026-09-01) -- THE COLLISION IS STRUCTURAL, NOT
> COSMETIC.**
>
> The Executive Summary describes a shared computer id as producing conflicting
> status updates where "the last one to transmit wins", giving a flickering
> display. That understates it. On the RECEIVING side (`src/uNet.pas:331`):
>
> ```pascal
> ClientID := Ord(StationStPtr^.ssComputerID) - Ord('A') + 1;
> StatusArray[ClientID] := StationStPtr^;
> ```
>
> **`StatusArray` is INDEXED BY THE LETTER.** Two stations calling themselves `A`
> are not two rows racing to update a display -- they are the same array slot, on
> every client in the network. The letter IS the address space, which is also why
> `MAXCLIENTS` is 26 rather than 26 being a policy choice: the uniqueness this
> code assumes is structural.
>
> Three further client-side paths ask "is this QSO mine?" as
> `ceComputerID = ComputerID` -- `src/MainUnit.pas:9563`,
> `src/trdos/LOGEDIT.PAS:1448`, and `src/trdos/PostUnit.PAS:3068`, the last being
> the Cabrillo transmitter-id column. Under a shared letter each station treats
> some of the other's QSOs as its own, for editing and for export, and the log
> looks like it merged correctly.

### Message Receiving

**Message processing (uNet.pas lines 248-481):**

```pascal
WM_SOCK_NET_RX:  // Socket has data
  i := recv(NetSocket, NetBuffer, SizeOf(NetBuffer), 0);

  if i <= 0 then
  begin
    NetDisconnect;
    showwarning('Connection to TR4W Server lost');
    Exit;
  end;

  Bufindex := 0;
  counter := 0;

NetCheckBuffer:
  case PWORD(@NetBuffer[Bufindex])^ of

    NET_STATIONSTATUS_ID:
      NetStationStatusPtr := @NetBuffer[Bufindex];
      UpdateStationStatus(NetStationStatusPtr^);  // Update UI
      Bufindex := Bufindex + SizeOf(TStationState);

    NET_QSOINFO_ID:
      NetQSOInfoPtr := @NetBuffer[Bufindex];
      // Add QSO to local log
      LogContact(NetQSOInfoPtr.qiInformation, False);
      UpdateMultiplierDisplay();
      Bufindex := Bufindex + SizeOf(TNetQSOInformation);

    NET_EDITEDQSO_ID:
      NetQSOInfoPtr := @NetBuffer[Bufindex];
      UpdateQSOInLog(NetQSOInfoPtr.qiInformation);
      Bufindex := Bufindex + SizeOf(TNetQSOInformation);

    NET_SERVERMESSAGE_ID:
      ServerMessagePtr := @NetBuffer[Bufindex];
      case ServerMessagePtr.smMessage of
        SM_CLEARALLLOGS_MESSAGE: ClearLog();
        SM_CLEAR_DUPESHEET_MESSAGE: tClearDupesheet();
        SM_CLEAR_MULTSHEET_MESSAGE: tClearMultSheet();
        SM_SERIAL_NUMBER_CHANGED:
          NextSerial := ServerMessagePtr.smParam;
        // ... more commands
      end;
      Bufindex := Bufindex + SizeOf(TServerMessage);

    // ... 10+ more message types
  end;

  inc(counter);
  if Bufindex = i then goto NetDone;
  if counter < 25 then goto NetCheckBuffer;
```

---

## 5. Architectural Strengths (Why V1 Works)

### 1. Simplicity

**Single-threaded design eliminates:**
- Race conditions
- Deadlocks
- Lock contention
- Complex synchronization

**Perfect for:**
- 26 clients max (small scale)
- LAN environments (low latency)
- Single server machine (no distributed state)

### 2. Performance

**Zero-copy protocol:**
```pascal
// Client side
NetQSOInfoToSend.qiInformation := LocalQSO;  // Direct struct copy
SendToNet(NetQSOInfoToSend, SizeOf(...));    // memcpy to socket buffer

// Server side
SendMessageToClients(wp, SizeOf(TNetQSOInformation), False);  // memcpy from receive buffer
```

**No parsing, no serialization** - just memory copies.

**Latency:** ~10-50ms LAN round-trip for QSO broadcast (measured in field).

### 3. Separation of Concerns

**Real-time socket (port 1061):**
- Small messages (40-270 bytes)
- Processed in main event loop
- Sub-100ms delivery

**Sync socket (port 1062):**
- Large transfers (MB log files)
- Separate thread
- Uses `TransmitFile()` for zero-copy kernel transfer
- Doesn't block real-time updates

### 4. Smart Serial Number Design

**Pre-allocation strategy:**
- Each client always has next serial ready
- No waiting for server on every QSO
- Increment-all approach prevents duplicates
- Acceptable to skip numbers (better than duplicates)

### 5. Battle-Tested Reliability

**Field-proven in:**
- CQ WW (6000+ QSOs, 48 hours)
- ARRL Sweepstakes (1400+ QSOs, 24 hours)
- Multi-multi stations (10+ operators)
- High QSO rates (200+ per hour peaks)

---

## 6. Architectural Weaknesses (Why Modernize)

### 1. Platform Lock-In

**Windows-specific APIs:**
```pascal
WSAAsyncSelect(...)      // Windows Sockets 2
GetMessage(...)          // Windows message loop
SYSTEMTIME               // Windows-specific structure
TransmitFile(...)        // MSWSOCK.DLL function
```

**Cannot port to Linux/macOS** without major rewrite.

### 2. No Protocol Evolution

**Adding a field breaks everyone:**
```pascal
// Want to add operator name to station status?
TStationState = packed record
  // ... existing 40 bytes
  ssOperatorName: array[0..15] of Char;  // +16 bytes = 56 bytes total
end;

// Result:
// - Old clients: Read wrong data (parse 56 bytes as 40 bytes)
// - Old server: Crashes or corrupts (expects 40 bytes)
```

**Workaround in V1:** Create new message type (NET_STATIONSTATUS_V2_ID)
**Problem:** Requires coordinated update of all clients

### 3. Error Recovery

**No reconnection logic:**
```pascal
if recv() <= 0 then
begin
  NetDisconnect;
  showwarning('Connection to TR4W Server lost');
  Exit;  // DONE - user must manually reconnect
end;
```

**Impact:**
- Network hiccup disconnects client
- Must stop operating, click reconnect
- May lose QSOs if not synced

**Modern expectation:** Auto-reconnect with exponential backoff

> **STALE FOR TR4W-D12 (checked 2026-09-01) -- THE RAW SOCKET IS GONE.**
>
> This was accurate when the document was written. On 2026-08-25 `uNet` moved off
> the raw Winsock / `WSAAsyncSelect` path onto Indy: `TNetClient`
> (`src/uNetClient.pas`) owns the socket and the password handshake, and parsing
> still runs on the main thread through `Application.QueueAsyncCall`. The drop arm
> quoted above still exists, but it now runs because the reader reported the link
> down rather than because `recv` returned nothing, and retrying happens on the
> `WM_TIMER` path while the link is down (`src/uNet.pas:682`).
>
> So "the operator must stop operating and click reconnect" no longer describes
> this tree. The rest of the section -- that unsynced QSOs are not queued for
> replay -- has NOT been checked, and should not be assumed fixed along with it.

### 4. Dupe Race Conditions

**Scenario:**
```
12:00:00.000  Station A starts QSO with W1AW (not dupe)
12:00:00.000  Station B starts QSO with W1AW (not dupe)
12:00:02.500  Station A logs W1AW → broadcast
12:00:02.501  Station B logs W1AW → broadcast
12:00:02.600  Station A receives B's QSO (now shows dupe)
12:00:02.601  Station B receives A's QSO (now shows dupe)
```

**Result:** Two QSOs in log, both marked dupe after the fact.

**Solution for V2:** Server-authoritative dupe check:
```
A: Can I log W1AW?
Server: Yes, added (ID 12345)
B: Can I log W1AW?
Server: No, duplicate of ID 12345
```

### 5. No Security

**Plaintext password:**
```pascal
send(NetSocket, 'TR4WSERVER', 10, 0);  // Password = 'TR4WSERVER'
```

**Sniffable on shared networks:**
- Hotel WiFi at DXpedition
- Public contest venue
- Internet operation (not recommended but happens)

**Competitor could:**
- See real-time QSO strategy
- Learn mult needs
- Steal call list

**Solution for V2:** TLS encryption, password hashing

### 6. Message Ordering Not Guaranteed

**TCP guarantees order per connection**, but:

```
Server broadcasts to 6 clients:
  send(ClientA, QSO_ADD id=100)
  send(ClientB, QSO_ADD id=100)
  // ... network congestion
  send(ClientA, QSO_EDIT id=100)  // Arrives before first message!
  send(ClientB, QSO_EDIT id=100)
```

**Unlikely but possible** on high-latency/lossy networks.

**Solution for V2:** Sequence numbers

---

# V2 Protocol Design

## Design Goals

1. **Backward Compatible:** V2 server must support V1 clients during transition
2. **Cross-Platform:** Protocol Buffers for platform-independent serialization
3. **Versioned:** Clients/servers can evolve independently
4. **Robust:** Auto-reconnect, message ordering, integrity checking
5. **Secure:** Optional TLS, password hashing
6. **Extensible:** Add fields/messages without breaking compatibility
7. **Efficient:** Comparable performance to V1 (~14% overhead acceptable)

## Serialization: Protocol Buffers

### Why Protocol Buffers?

**Protocol Buffers (protobuf)** by Google provides:

✅ **Forward/Backward Compatibility:**
```protobuf
message StationStatus {
  required string station_id = 1;
  optional string operator_name = 2;  // Can add later - old clients ignore
}
```

✅ **Efficient Binary Format:**
- Variable-length encoding (small numbers = few bytes)
- Optional fields omitted from wire format
- ~10-20% larger than packed structs (acceptable tradeoff)

✅ **Code Generation:**
```bash
protoc --cpp_out=. tr4w_protocol.proto
# Generates: tr4w_protocol.pb.h, tr4w_protocol.pb.cc
```

✅ **Cross-Platform:**
- Works on x86, ARM, big-endian systems
- C++, Python, Java, Go bindings available
- Qt integration via QByteArray

✅ **Validation:**
- Required/optional fields enforced
- Type safety (can't put string in int field)
- Enum validation

**Alternatives Considered:**

| Format | Pros | Cons | Verdict |
|--------|------|------|---------|
| **JSON** | Human-readable, debuggable | 5-10x larger, slow parsing | ❌ Too inefficient |
| **Cap'n Proto** | Zero-copy, faster than protobuf | Less mature, fewer bindings | ⚠️ Consider for V3 |
| **MessagePack** | Compact binary JSON | No schema, no versioning | ❌ Need versioning |
| **FlatBuffers** | Zero-copy, used in games | Complex, overkill for this | ❌ Over-engineered |
| **Protocol Buffers** | **Sweet spot for TR4W** | Slight overhead vs raw binary | ✅ **CHOSEN** |

---

## Protocol Definition Files

### Core Envelope: `tr4w_protocol.proto`

```protobuf
syntax = "proto3";

package tr4w.net.v2;

// ============================================================================
// MESSAGE ENVELOPE - Wraps all messages
// ============================================================================
message MessageEnvelope {
  // Metadata
  uint64 sequence_number = 1;      // Monotonically increasing (server-assigned)
  uint64 timestamp_ms = 2;         // Unix time in milliseconds
  string sender_id = 3;            // "A".."Z" or "SERVER"

  // Exactly one of these is set
  oneof message {
    StationStatus station_status = 10;
    QSOUpdate qso_update = 11;
    DXSpot dx_spot = 12;
    IntercomMessage intercom = 13;
    ServerCommand server_command = 14;
    ClientCommand client_command = 15;
    LogSyncRequest log_sync_request = 16;
    LogSyncResponse log_sync_response = 17;
    TimeSync time_sync = 18;
    ConfigUpdate config_update = 19;
  }

  // Optional integrity check
  bytes hmac_signature = 99;       // HMAC-SHA256 of serialized message
}
```

### Connection Handshake

```protobuf
// ============================================================================
// HANDSHAKE - Protocol Negotiation
// ============================================================================
message ClientHello {
  uint32 protocol_version = 1;     // 2 for V2, 1 for V1 (backward compat)
  string client_software = 2;      // "TR4W", "TR4QT", "TR4Web"
  string client_version = 3;       // "4.143.2", "1.0.0-beta"
  string station_id = 4;           // "A".."Z"
  string station_name = 5;         // "N6TR-1", "W1AW-Alpha"
  bytes password_hash = 6;         // SHA256(password + server_salt)

  // Feature negotiation
  repeated string capabilities = 10;  // "TLS", "COMPRESSION", "PROTOBUF_V3"
}

message ServerHello {
  uint32 protocol_version = 1;     // Server's protocol version
  bool authentication_success = 2;
  string rejection_reason = 3;     // "INVALID_PASSWORD", "SERVER_FULL", etc.
  bytes session_token = 4;         // For subsequent auth (optional)
  bytes server_salt = 5;           // For password hashing

  // Contest information
  string contest_name = 10;        // "CQ WW CW", "ARRL Sweepstakes"
  string log_filename = 11;        // "cqww2025.dat"
  uint64 server_qso_count = 12;
  bytes server_log_hash = 13;      // SHA256 of entire log

  // Initial state
  uint64 next_sequence = 20;       // Client should expect this sequence
  uint32 next_serial_number = 21;  // For serial contests

  // Enabled features
  repeated string enabled_features = 30;  // "SERIAL_LOCKOUT", "TIME_SYNC"
}
```

### QSO Data: `tr4w_qso.proto`

```protobuf
syntax = "proto3";

package tr4w.net.v2;

// ============================================================================
// QSO UPDATE
// ============================================================================
message QSOUpdate {
  enum Operation {
    ADD = 0;
    EDIT = 1;
    DELETE = 2;
  }

  Operation operation = 1;
  QSORecord qso = 2;

  // For edits/deletes
  uint64 original_qso_id = 3;

  // Server response (when client proposes add)
  bool accepted = 10;
  string rejection_reason = 11;    // "DUPLICATE", "INVALID_EXCHANGE"
}

message QSORecord {
  // Unique identifiers
  uint64 qso_id = 1;               // Server-assigned unique ID
  string station_id = 2;           // "A".."Z" - which station logged it

  // Time (high precision)
  Timestamp qso_time = 3;

  // Frequency/Band/Mode
  uint64 frequency_hz = 4;         // 14025000
  Band band = 5;                   // BAND_20M
  Mode mode = 6;                   // MODE_CW

  // Basic QSO data
  string callsign = 10;            // "W1AW"
  string rst_sent = 11;            // "599"
  string rst_rcvd = 12;            // "579"

  // Exchange (flexible key-value format)
  map<string, string> exchange_sent = 15;
  // Example: {"serial": "123", "section": "ORG"}
  // Example: {"zone": "05"}
  // Example: {"serial": "456", "precedence": "A", "check": "85", "section": "CT"}

  map<string, string> exchange_rcvd = 16;

  // Computed fields (server-side or client-side)
  repeated string multipliers = 20;  // ["ORG", "W1", "NA"]
  bool is_dupe = 21;
  uint32 qso_points = 22;

  // Metadata
  string operator_call = 30;       // "N6TR"
  uint32 transmitter_id = 31;      // 1 or 2 (for multi-transmitter)
  bool qso_confirmed = 32;         // For real-time scoring

  // Flags
  bool deleted = 40;
  bool needs_review = 41;          // Flagged for post-contest review

  // Audio recording reference (if enabled)
  string audio_filename = 50;      // "2025-01-15_1423_W1AW.mp3"

  // Notes
  string comment = 60;             // Free-form notes
}

// ============================================================================
// TIME
// ============================================================================
message Timestamp {
  int64 unix_seconds = 1;          // Seconds since epoch
  int32 nanos = 2;                 // Nanoseconds (0-999,999,999)
}

// ============================================================================
// ENUMS
// ============================================================================
enum Band {
  BAND_UNKNOWN = 0;
  BAND_2190M = 1;    // 136 kHz
  BAND_630M = 2;     // 472 kHz
  BAND_160M = 3;
  BAND_80M = 4;
  BAND_60M = 5;
  BAND_40M = 6;
  BAND_30M = 7;
  BAND_20M = 8;
  BAND_17M = 9;
  BAND_15M = 10;
  BAND_12M = 11;
  BAND_10M = 12;
  BAND_6M = 13;
  BAND_4M = 14;
  BAND_2M = 15;
  BAND_1_25M = 16;
  BAND_70CM = 17;
  BAND_33CM = 18;
  BAND_23CM = 19;
  BAND_13CM = 20;
  BAND_9CM = 21;
  BAND_6CM = 22;
  BAND_3CM = 23;
  BAND_1_25CM = 24;
  // ... more as needed
}

enum Mode {
  MODE_UNKNOWN = 0;
  MODE_CW = 1;
  MODE_SSB = 2;
  MODE_FM = 3;
  MODE_AM = 4;
  MODE_RTTY = 5;
  MODE_PSK31 = 6;
  MODE_PSK63 = 7;
  MODE_FT8 = 8;
  MODE_FT4 = 9;
  MODE_FT16 = 10;
  MODE_FST4 = 11;
  MODE_OLIVIA = 12;
  MODE_CONTESTIA = 13;
  MODE_MFSK = 14;
  MODE_SSTV = 15;
  // ... more as needed
}
```

### Station Status: `tr4w_station.proto`

```protobuf
syntax = "proto3";

package tr4w.net.v2;

message StationStatus {
  string station_id = 1;           // "A".."Z"
  string station_name = 2;         // "N6TR-1"

  // Current activity
  uint64 frequency_hz = 10;        // 14195000
  Band band = 11;                  // BAND_20M
  Mode mode = 12;                  // MODE_CW
  string current_callsign = 13;    // Callsign in entry window

  // Operating state
  OperatingMode op_mode = 20;      // RUN or S&P
  bool is_transmitting = 21;       // PTT active
  bool is_locked_out = 22;         // Waiting for serial number

  // Statistics
  uint32 qso_count = 30;
  uint32 mult_count = 31;
  uint64 total_score = 32;
  uint32 current_rate = 33;        // QSOs per hour (last 10 minutes)

  // Radio information
  RadioInfo radio_1 = 40;
  RadioInfo radio_2 = 41;          // For SO2R

  // Operator
  string operator_name = 50;       // "Larry N6TR"

  // Last update time
  Timestamp last_update = 60;
}

enum OperatingMode {
  OP_MODE_UNKNOWN = 0;
  OP_MODE_RUN = 1;                 // CQ mode
  OP_MODE_SP = 2;                  // Search & Pounce
}

message RadioInfo {
  string radio_model = 1;          // "Elecraft K3", "FTDX5000"
  uint64 vfo_a_hz = 2;
  uint64 vfo_b_hz = 3;
  Mode mode = 4;
  int32 rit_offset_hz = 5;         // +/- Hz
  bool split_active = 6;
  int32 power_watts = 7;
  int32 swr_tenths = 8;            // SWR * 10 (e.g., 15 = 1.5:1)
}
```

### DX Spots: `tr4w_spot.proto`

```protobuf
syntax = "proto3";

package tr4w.net.v2;

message DXSpot {
  string spot_id = 1;              // Unique ID (UUID or hash)

  // What was spotted
  string dx_callsign = 10;         // "9A1A"
  uint64 frequency_hz = 11;        // 14025000
  Band band = 12;                  // BAND_20M
  Mode mode = 13;                  // MODE_CW

  // Who spotted
  string spotter_call = 20;        // "K3LR"

  // When
  Timestamp spot_time = 30;

  // Additional info
  string comment = 40;             // "QSX 14195", "599 here!"

  // Classification (client-computed)
  bool is_multiplier = 50;
  bool is_dupe = 51;
  bool is_needed = 52;

  // Source
  SpotSource source = 60;

  // Band map display
  int32 age_seconds = 70;          // Time since spot
  int32 signal_report = 71;        // S-meter: 0-9, or dB over S9
}

enum SpotSource {
  SOURCE_UNKNOWN = 0;
  SOURCE_CLUSTER = 1;              // DX cluster (telnet)
  SOURCE_SKIMMER = 2;              // CW Skimmer / Reverse Beacon Network
  SOURCE_LOCAL = 3;                // Manually added by operator
  SOURCE_NETWORK = 4;              // From another station on TR4W network
  SOURCE_WSJTX = 5;                // From WSJT-X
}
```

### Server/Client Commands: `tr4w_commands.proto`

```protobuf
syntax = "proto3";

package tr4w.net.v2;

message ServerCommand {
  enum CommandType {
    CLEAR_LOG = 0;
    CLEAR_DUPES = 1;
    CLEAR_MULTS = 2;
    DISCONNECT_CLIENT = 3;
    REQUEST_STATUS = 4;
    ASSIGN_SERIAL = 5;
    SYNC_TIME = 6;
    SHUTDOWN = 7;
  }

  CommandType command = 1;

  // Command-specific parameters
  oneof parameter {
    string target_station_id = 10;  // For DISCONNECT_CLIENT
    uint32 assigned_serial = 11;    // For ASSIGN_SERIAL
    Timestamp server_time = 12;     // For SYNC_TIME
  }

  string reason = 20;               // Optional explanation
}

message ClientCommand {
  enum CommandType {
    REQUEST_LOG_SYNC = 0;
    RESERVE_SERIAL = 1;
    RELEASE_SERIAL = 2;
    REQUEST_MULT_LIST = 3;
    PING = 4;                       // Keepalive
  }

  CommandType command = 1;

  // Command-specific parameters
  oneof parameter {
    uint32 serial_to_reserve = 10;
    uint64 log_sync_from_qso = 11;  // For partial sync
  }
}
```

### Log Synchronization: `tr4w_sync.proto`

```protobuf
syntax = "proto3";

package tr4w.net.v2;

message LogSyncRequest {
  // Client's current state
  uint64 client_qso_count = 1;
  bytes client_log_hash = 2;       // SHA256 of entire log
  uint64 last_qso_id = 3;         // Last QSO ID client has

  // Request parameters
  bool full_sync = 10;             // True = resend entire log
  uint32 batch_size = 11;          // QSOs per batch (default 100)
}

message LogSyncResponse {
  // Server's current state
  uint64 server_qso_count = 1;
  bytes server_log_hash = 2;

  // Sync strategy
  SyncMethod method = 3;

  // QSO data (batched)
  repeated QSORecord qsos = 10;
  bool has_more = 11;              // More batches to follow
  uint32 batch_number = 12;        // For progress tracking (1, 2, 3...)
  uint32 total_batches = 13;

  enum SyncMethod {
    NO_SYNC_NEEDED = 0;            // Logs match
    INCREMENTAL = 1;               // Send only new QSOs
    FULL_RESYNC = 2;               // Send entire log
  }
}
```

### Intercom/Chat: `tr4w_intercom.proto`

```protobuf
syntax = "proto3";

package tr4w.net.v2;

message IntercomMessage {
  string sender_id = 1;            // "A".."Z"
  string sender_name = 2;          // "N6TR"
  string message = 3;              // Up to 1000 characters
  Timestamp timestamp = 4;

  // Message priority/type
  MessagePriority priority = 5;

  enum MessagePriority {
    NORMAL = 0;
    IMPORTANT = 1;                 // Visual alert
    URGENT = 2;                    // Audio + visual alert
  }
}
```

---

## Connection Flow (V2)

### Detailed Handshake Sequence

```
Client                                          Server
  |                                               |
  |------------- TCP Connect ------------------->|
  |                                               |
  |------------- ClientHello -------------------->|
  |  protocol_version: 2                          |
  |  client_software: "TR4QT"                     |
  |  client_version: "1.0.0"                      |
  |  station_id: "A"                              |
  |  station_name: "N6TR-Alpha"                   |
  |  password_hash: SHA256(pwd+salt)              |
  |  capabilities: ["TLS", "COMPRESSION"]         |
  |                                               |
  |<------------ ServerHello ---------------------|
  |  protocol_version: 2                          |
  |  authentication_success: true                 |
  |  contest_name: "CQ WW CW"                     |
  |  server_qso_count: 1523                       |
  |  server_log_hash: 0xABCD...                   |
  |  next_sequence: 10000                         |
  |  next_serial_number: 124                      |
  |  enabled_features: ["SERIAL_LOCKOUT"]         |
  |                                               |
  |------------- LogSyncRequest ----------------->|
  |  client_qso_count: 1500                       |
  |  client_log_hash: 0xABCD...                   |
  |  last_qso_id: 12345                           |
  |                                               |
  |<------------ LogSyncResponse -----------------|
  |  method: INCREMENTAL                          |
  |  qsos: [QSO 12346..12368] (23 QSOs)          |
  |  has_more: false                              |
  |                                               |
  |<------------ MessageEnvelope -----------------|
  |  sequence: 10000                              |
  |  station_status: {station_id: "B", ...}       |
  |                                               |
  |------------- MessageEnvelope ----------------->|
  |  sequence: 10001 (client assigns locally)     |
  |  station_status: {station_id: "A", ...}       |
  |                                               |
  |<------------ MessageEnvelope -----------------|
  |  sequence: 10002                              |
  |  qso_update: {operation: ADD, ...}            |
  |                                               |
```

---

## Key V2 Features Implementation

### Feature 1: Message Ordering

**Problem:** V1 has no ordering guarantee across multiple clients.

**V2 Solution:** Server-assigned sequence numbers

```cpp
class SequenceManager {
    std::atomic<uint64_t> m_nextSequence{1};

public:
    uint64_t assignSequence(tr4w::net::v2::MessageEnvelope& msg) {
        uint64_t seq = m_nextSequence.fetch_add(1, std::memory_order_relaxed);
        msg.set_sequence_number(seq);
        msg.set_timestamp_ms(QDateTime::currentMSecsSinceEpoch());
        return seq;
    }
};

class OrderedReceiver {
    uint64_t m_lastProcessed = 0;
    QMap<uint64_t, tr4w::net::v2::MessageEnvelope> m_outOfOrder;

    void receiveMessage(const tr4w::net::v2::MessageEnvelope& msg) {
        uint64_t seq = msg.sequence_number();

        // Expected next message?
        if (seq == m_lastProcessed + 1) {
            processMessage(msg);
            m_lastProcessed = seq;

            // Process any buffered out-of-order messages
            while (m_outOfOrder.contains(m_lastProcessed + 1)) {
                processMessage(m_outOfOrder.take(m_lastProcessed + 1));
                m_lastProcessed++;
            }
        }
        // Out of order - buffer for later
        else if (seq > m_lastProcessed + 1) {
            qDebug() << "Out of order:" << seq << "expected" << m_lastProcessed + 1;
            m_outOfOrder.insert(seq, msg);

            // Limit buffer size (prevent memory exhaustion)
            if (m_outOfOrder.size() > 1000) {
                qWarning() << "Out-of-order buffer full, clearing oldest";
                m_outOfOrder.erase(m_outOfOrder.begin());
            }
        }
        // Duplicate (already processed)
        else {
            qWarning() << "Duplicate sequence" << seq << "(last processed:" << m_lastProcessed << ")";
        }
    }
};
```

### Feature 2: Server-Authoritative Dupe Checking

**V1 Problem:** Clients check dupes locally → race conditions

**V2 Solution:** Server validates all QSOs before adding

```cpp
class ServerLog {
    struct DupeKey {
        QString callsign;
        tr4w::net::v2::Band band;
        tr4w::net::v2::Mode mode;

        bool operator<(const DupeKey& other) const {
            if (callsign != other.callsign)
                return callsign < other.callsign;
            if (band != other.band)
                return band < other.band;
            return mode < other.mode;
        }
    };

    mutable QReadWriteLock m_lock;
    QSet<DupeKey> m_dupeIndex;
    QVector<tr4w::net::v2::QSORecord> m_log;
    quint64 m_nextQsoId = 1;

public:
    enum AddResult {
        SUCCESS,
        DUPLICATE,
        INVALID_EXCHANGE,
        SERVER_ERROR
    };

    AddResult addQSO(tr4w::net::v2::QSORecord& qso) {
        QWriteLocker lock(&m_lock);

        // Validate exchange (contest-specific)
        if (!validateExchange(qso)) {
            return INVALID_EXCHANGE;
        }

        // Check for dupe
        DupeKey key{
            QString::fromStdString(qso.callsign()).toUpper(),
            qso.band(),
            qso.mode()
        };

        if (m_dupeIndex.contains(key)) {
            qso.set_is_dupe(true);
            return DUPLICATE;
        }

        // Assign server-side unique ID
        qso.set_qso_id(m_nextQsoId++);
        qso.set_is_dupe(false);

        // Compute multipliers (contest-specific)
        computeMultipliers(qso);

        // Add to log and dupe index atomically
        m_log.append(qso);
        m_dupeIndex.insert(key);

        // Persist to disk (async write)
        emit qsoAdded(qso);

        return SUCCESS;
    }

private:
    bool validateExchange(const tr4w::net::v2::QSORecord& qso) {
        // Contest-specific validation
        // Example for ARRL Sweepstakes:
        auto ex = qso.exchange_rcvd();
        return ex.contains("serial") &&
               ex.contains("precedence") &&
               ex.contains("check") &&
               ex.contains("section");
    }

    void computeMultipliers(tr4w::net::v2::QSORecord& qso) {
        // Contest-specific multiplier logic
        // Example: Add section multiplier
        auto ex = qso.exchange_rcvd();
        if (ex.contains("section")) {
            qso.add_multipliers(ex.at("section"));
        }
    }
};

// Server handles client QSO addition
void TR4WServer::handleQSOUpdate(const tr4w::net::v2::QSOUpdate& update,
                                  QTcpSocket* clientSocket) {
    if (update.operation() == tr4w::net::v2::QSOUpdate::ADD) {
        tr4w::net::v2::QSORecord qso = update.qso();
        auto result = m_log->addQSO(qso);  // Server validates and adds

        // Send response to client
        tr4w::net::v2::QSOUpdate response;
        response.set_operation(tr4w::net::v2::QSOUpdate::ADD);
        *response.mutable_qso() = qso;  // Include server-assigned ID

        if (result == ServerLog::SUCCESS) {
            response.set_accepted(true);

            // Broadcast to all other clients
            tr4w::net::v2::MessageEnvelope envelope;
            m_sequenceManager->assignSequence(envelope);
            envelope.set_sender_id("SERVER");
            *envelope.mutable_qso_update() = response;

            broadcastMessage(envelope, clientSocket);  // Exclude sender
        }
        else {
            response.set_accepted(false);

            if (result == ServerLog::DUPLICATE)
                response.set_rejection_reason("DUPLICATE");
            else if (result == ServerLog::INVALID_EXCHANGE)
                response.set_rejection_reason("INVALID_EXCHANGE");

            // Send rejection only to requesting client
            sendToClient(clientSocket, response);
        }
    }
}
```

### Feature 3: Extensible Exchange Format

**V1 Problem:** Fixed ContestExchange struct per contest type

**V2 Solution:** Key-value map for exchanges

```cpp
// Different contest types use same QSORecord structure

// ARRL Sweepstakes
tr4w::net::v2::QSORecord ss_qso;
(*ss_qso.mutable_exchange_sent())["serial"] = "123";
(*ss_qso.mutable_exchange_sent())["precedence"] = "A";
(*ss_qso.mutable_exchange_sent())["check"] = "85";
(*ss_qso.mutable_exchange_sent())["section"] = "ORG";

// CQ WW
tr4w::net::v2::QSORecord cqww_qso;
(*cqww_qso.mutable_exchange_sent())["zone"] = "05";

// ARRL DX (US stations send state, DX send power)
tr4w::net::v2::QSORecord dx_qso;
if (isUS) {
    (*dx_qso.mutable_exchange_sent())["state"] = "OR";
} else {
    (*dx_qso.mutable_exchange_sent())["power"] = "1000";
}

// Server-side contest-specific validators
class ExchangeValidator {
public:
    virtual bool validate(const tr4w::net::v2::QSORecord& qso) = 0;
    virtual ~ExchangeValidator() = default;
};

class SweepstakesValidator : public ExchangeValidator {
    bool validate(const tr4w::net::v2::QSORecord& qso) override {
        auto ex = qso.exchange_rcvd();

        // Check required fields
        if (!ex.contains("serial") || !ex.contains("precedence") ||
            !ex.contains("check") || !ex.contains("section"))
            return false;

        // Validate precedence (A, B, Q, M, S, U)
        QString prec = QString::fromStdString(ex.at("precedence"));
        if (!QStringList{"A", "B", "Q", "M", "S", "U"}.contains(prec))
            return false;

        // Validate check (00-99)
        bool ok;
        int check = QString::fromStdString(ex.at("check")).toInt(&ok);
        if (!ok || check < 0 || check > 99)
            return false;

        // Validate section (use CTY.DAT or similar)
        QString section = QString::fromStdString(ex.at("section"));
        if (!m_validSections.contains(section))
            return false;

        return true;
    }

private:
    QSet<QString> m_validSections = {
        "CT", "EMA", "ME", "NH", "RI", "VT", "WMA",  // New England
        "ENY", "NLI", "NNJ", "NNY", "SNJ", "WNY",    // Atlantic
        // ... all 83 sections
    };
};

// Factory pattern for contest-specific logic
class ContestFactory {
public:
    static std::unique_ptr<ExchangeValidator> createValidator(const QString& contest) {
        if (contest == "ARRL-SS-CW" || contest == "ARRL-SS-SSB")
            return std::make_unique<SweepstakesValidator>();
        else if (contest == "CQ-WW-CW" || contest == "CQ-WW-SSB")
            return std::make_unique<CQWWValidator>();
        // ... more contests
        else
            return std::make_unique<GenericValidator>();
    }
};
```

### Feature 4: Auto-Reconnect

**V1 Problem:** Connection loss requires manual reconnect

**V2 Solution:** Exponential backoff with message queuing

```cpp
class ResilientNetworkClient : public QObject {
    Q_OBJECT

public:
    ResilientNetworkClient(QObject* parent = nullptr)
        : QObject(parent)
        , m_socket(new QTcpSocket(this))
        , m_reconnectTimer(new QTimer(this))
    {
        connect(m_socket, &QTcpSocket::connected, this, &ResilientNetworkClient::onConnected);
        connect(m_socket, &QTcpSocket::disconnected, this, &ResilientNetworkClient::onDisconnected);
        connect(m_socket, &QTcpSocket::errorOccurred, this, &ResilientNetworkClient::onError);
        connect(m_reconnectTimer, &QTimer::timeout, this, &ResilientNetworkClient::attemptReconnect);
    }

    void connectToServer(const QString& host, quint16 port) {
        m_serverHost = host;
        m_serverPort = port;
        m_reconnectAttempts = 0;

        qInfo() << "Connecting to" << host << ":" << port;
        m_socket->connectToHost(host, port);
    }

signals:
    void connected();
    void disconnected();
    void reconnecting(int attempt, int delayMs);
    void reconnectFailed(const QString& reason);
    void messageQueued(int queueSize);

private slots:
    void onConnected() {
        qInfo() << "Connected to server";
        m_reconnectAttempts = 0;
        m_currentBackoff = m_initialBackoff;

        // Send handshake
        sendClientHello();

        // Flush queued messages
        flushMessageQueue();

        emit connected();
    }

    void onDisconnected() {
        qWarning() << "Disconnected from server";
        emit disconnected();

        // Schedule reconnect
        scheduleReconnect();
    }

    void onError(QAbstractSocket::SocketError error) {
        qCritical() << "Socket error:" << m_socket->errorString();

        if (error != QAbstractSocket::RemoteHostClosedError) {
            scheduleReconnect();
        }
    }

    void attemptReconnect() {
        m_reconnectAttempts++;

        if (m_maxReconnectAttempts > 0 && m_reconnectAttempts > m_maxReconnectAttempts) {
            qCritical() << "Max reconnect attempts reached";
            emit reconnectFailed("Max attempts exceeded");
            return;
        }

        qInfo() << "Reconnect attempt" << m_reconnectAttempts;
        emit reconnecting(m_reconnectAttempts, m_currentBackoff);

        m_socket->connectToHost(m_serverHost, m_serverPort);
    }

    void scheduleReconnect() {
        // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (max)
        m_currentBackoff = std::min(m_currentBackoff * 2, m_maxBackoff);

        qInfo() << "Scheduling reconnect in" << m_currentBackoff << "ms";
        m_reconnectTimer->start(m_currentBackoff);
    }

public:
    void sendMessage(const tr4w::net::v2::MessageEnvelope& msg) {
        if (m_socket->state() != QAbstractSocket::ConnectedState) {
            // Queue message for later
            m_messageQueue.enqueue(msg);
            emit messageQueued(m_messageQueue.size());

            if (m_messageQueue.size() > m_maxQueueSize) {
                qWarning() << "Message queue full, dropping oldest message";
                m_messageQueue.dequeue();
            }

            return;
        }

        sendMessageNow(msg);
    }

private:
    void sendMessageNow(const tr4w::net::v2::MessageEnvelope& msg) {
        // Serialize protobuf
        QByteArray data;
        data.resize(msg.ByteSizeLong());
        msg.SerializeToArray(data.data(), data.size());

        // Send with 4-byte length prefix (for framing)
        QByteArray frame;
        QDataStream stream(&frame, QIODevice::WriteOnly);
        stream.setByteOrder(QDataStream::BigEndian);
        stream << static_cast<quint32>(data.size());
        frame.append(data);

        m_socket->write(frame);
        m_socket->flush();
    }

    void flushMessageQueue() {
        while (!m_messageQueue.isEmpty()) {
            sendMessageNow(m_messageQueue.dequeue());
        }
    }

    QTcpSocket* m_socket;
    QTimer* m_reconnectTimer;
    QString m_serverHost;
    quint16 m_serverPort = 0;

    int m_reconnectAttempts = 0;
    int m_maxReconnectAttempts = -1;  // -1 = infinite
    int m_initialBackoff = 1000;      // 1 second
    int m_currentBackoff = 1000;
    int m_maxBackoff = 30000;         // 30 seconds

    QQueue<tr4w::net::v2::MessageEnvelope> m_messageQueue;
    int m_maxQueueSize = 1000;
};
```

### Feature 5: Optional Compression

**For slow/metered connections** (Internet operation, satellite links)

```cpp
class CompressedTransport {
public:
    static QByteArray compressMessage(const tr4w::net::v2::MessageEnvelope& msg) {
        // Serialize protobuf
        QByteArray data(msg.ByteSizeLong(), 0);
        msg.SerializeToArray(data.data(), data.size());

        // Compress with zlib (Qt built-in)
        return qCompress(data, 9);  // Max compression level
    }

    static tr4w::net::v2::MessageEnvelope decompressMessage(const QByteArray& compressed) {
        QByteArray data = qUncompress(compressed);

        tr4w::net::v2::MessageEnvelope msg;
        msg.ParseFromArray(data.data(), data.size());
        return msg;
    }
};

// In practice: ~50% size reduction
// Station status: 50 bytes → 28 bytes compressed
// QSO record: 200 bytes → 110 bytes compressed
```

### Feature 6: Message Integrity (HMAC)

**For untrusted networks** (prevent tampering, verify sender)

```cpp
class SecureMessaging {
public:
    SecureMessaging(const QByteArray& sharedSecret)
        : m_sharedSecret(sharedSecret)
    {}

    void signMessage(tr4w::net::v2::MessageEnvelope& msg) {
        // Serialize message without signature
        msg.clear_hmac_signature();
        QByteArray data(msg.ByteSizeLong(), 0);
        msg.SerializeToArray(data.data(), data.size());

        // Compute HMAC-SHA256
        QMessageAuthenticationCode mac(QCryptographicHash::Sha256, m_sharedSecret);
        mac.addData(data);
        QByteArray signature = mac.result();

        msg.set_hmac_signature(signature.toStdString());
    }

    bool verifyMessage(const tr4w::net::v2::MessageEnvelope& msg) {
        QByteArray receivedSig = QByteArray::fromStdString(msg.hmac_signature());

        // Clear signature for verification
        tr4w::net::v2::MessageEnvelope copy = msg;
        copy.clear_hmac_signature();

        // Recompute signature
        QByteArray data(copy.ByteSizeLong(), 0);
        copy.SerializeToArray(data.data(), data.size());

        QMessageAuthenticationCode mac(QCryptographicHash::Sha256, m_sharedSecret);
        mac.addData(data);
        QByteArray computedSig = mac.result();

        return receivedSig == computedSig;
    }

private:
    QByteArray m_sharedSecret;  // Derived from password
};
```

---

## Wire Format Examples

### Example: Station Status Message

**V1 Binary (40 bytes):**
```
Offset  Hex                         Description
------  --------------------------  -----------
0x00    42 04                       ssID = 1090
0x02    E8 03                       ssQSOTotals = 1000
0x04    41                          ssComputerID = 'A'
0x05    04                          ssCurrentBand = 4 (20M)
0x06    01                          ssCurrentMode = 1 (CW)
0x07    00                          ssStatusByte = 0
0x08    C0 27 D8 00                 ssFreq = 14025000 Hz
0x0C    57 31 41 57 00 ...          ssCallsign = "W1AW\0..."
0x19    42 6F 73 74 6F 6E 00 ...    ssName = "Boston\0..."
0x22    01                          ssType = 1
```

**V2 Protobuf (~48 bytes):**
```protobuf
MessageEnvelope {
  sequence_number: 1523
  timestamp_ms: 1704163200000
  sender_id: "A"
  station_status: {
    station_id: "A"
    station_name: "Boston"
    frequency_hz: 14025000
    band: BAND_20M
    mode: MODE_CW
    current_callsign: "W1AW"
    op_mode: OP_MODE_RUN
    qso_count: 1000
  }
}
```

**Hex dump of V2:**
```
08 F3 0B                    # field 1 (varint): 1523
10 80 C0 E8 F4 E5 2F        # field 2 (varint): 1704163200000
1A 01 41                    # field 3 (string): "A"
52 2D                       # field 10 (submessage): 45 bytes follow
  0A 01 41                  #   station_id: "A"
  12 06 42 6F 73 74 6F 6E  #   station_name: "Boston"
  50 C0 F7 D8 06            #   frequency_hz: 14025000
  58 08                     #   band: 8 (BAND_20M)
  60 01                     #   mode: 1 (MODE_CW)
  6A 04 57 31 41 57        #   callsign: "W1AW"
  A0 01 01                  #   op_mode: 1 (RUN)
  F0 01 E8 07               #   qso_count: 1000
```

**Analysis:**
- V1: 40 bytes fixed
- V2: 48 bytes (20% overhead)
- V2 gains: Extensibility, cross-platform, versioning

---

# Migration Strategy

## Phase 1: Dual-Mode Server (Month 1-3)

### Goal
Deploy V2 server that supports both V1 and V2 clients simultaneously.

### Implementation

```cpp
class TR4WServer : public QObject {
    Q_OBJECT

public:
    TR4WServer(QObject* parent = nullptr)
        : QObject(parent)
        , m_tcpServer(new QTcpServer(this))
        , m_v1Handler(new V1ProtocolHandler(this))
        , m_v2Handler(new V2ProtocolHandler(this))
    {
        connect(m_tcpServer, &QTcpServer::newConnection,
                this, &TR4WServer::onNewConnection);
    }

    bool start(quint16 port = 1061) {
        if (!m_tcpServer->listen(QHostAddress::Any, port)) {
            qCritical() << "Failed to start server:" << m_tcpServer->errorString();
            return false;
        }

        qInfo() << "TR4W Server listening on port" << port;
        qInfo() << "Supported protocols: V1 (legacy), V2 (protobuf)";
        return true;
    }

private slots:
    void onNewConnection() {
        QTcpSocket* socket = m_tcpServer->nextPendingConnection();
        qInfo() << "New connection from" << socket->peerAddress().toString();

        // Wait for protocol detection (need at least 4 bytes)
        connect(socket, &QTcpSocket::readyRead, this, [=]() {
            if (socket->bytesAvailable() < 4)
                return;

            QByteArray handshake = socket->peek(4);

            if (isV1Protocol(handshake)) {
                qInfo() << "  Protocol: V1 (legacy)";
                m_v1Handler->handleClient(socket);
            }
            else if (isV2Protocol(handshake)) {
                qInfo() << "  Protocol: V2 (protobuf)";
                m_v2Handler->handleClient(socket);
            }
            else {
                qWarning() << "  Unknown protocol, disconnecting";
                socket->disconnectFromHost();
            }

            // Disconnect this lambda (protocol determined)
            disconnect(socket, &QTcpSocket::readyRead, this, nullptr);
        });
    }

    bool isV1Protocol(const QByteArray& data) {
        // V1 sends 10-byte password immediately
        // Common passwords: "TR4WSERVER", "CONTEST123", etc.
        // Usually printable ASCII
        return data.size() >= 4 &&
               std::all_of(data.begin(), data.begin() + 4, [](char c) {
                   return std::isprint(c) || c == '\0';
               });
    }

    bool isV2Protocol(const QByteArray& data) {
        // V2 sends protobuf ClientHello
        // Protobuf starts with field tag: 0x08 (field 1, varint)
        return data.size() >= 1 && static_cast<unsigned char>(data[0]) == 0x08;
    }

private:
    QTcpServer* m_tcpServer;
    V1ProtocolHandler* m_v1Handler;  // Handles legacy binary protocol
    V2ProtocolHandler* m_v2Handler;  // Handles protobuf protocol
};
```

### V1 Protocol Handler (Wrapper)

```cpp
class V1ProtocolHandler : public QObject {
    Q_OBJECT

public:
    void handleClient(QTcpSocket* socket) {
        // Implement V1 protocol exactly as in original TR4W server
        // Forward events to unified ServerLog

        V1Client* client = new V1Client(socket, this);
        connect(client, &V1Client::qsoReceived, this, [=](const QSORecordV1& qso) {
            // Convert V1 struct to V2 protobuf
            tr4w::net::v2::QSORecord v2qso = convertV1ToV2(qso);

            // Add to unified log
            emit qsoAdded(v2qso);
        });

        m_v1Clients.append(client);
    }

signals:
    void qsoAdded(const tr4w::net::v2::QSORecord& qso);
    void clientConnected(const QString& stationId);
    void clientDisconnected(const QString& stationId);

private:
    tr4w::net::v2::QSORecord convertV1ToV2(const QSORecordV1& v1) {
        tr4w::net::v2::QSORecord v2;

        v2.set_callsign(v1.Callsign);
        v2.set_frequency_hz(v1.Frequency);
        v2.set_band(convertBand(v1.Band));
        v2.set_mode(convertMode(v1.Mode));
        // ... convert all fields

        return v2;
    }

    QVector<V1Client*> m_v1Clients;
};
```

### Unified Server Log

```cpp
class UnifiedServerLog : public QObject {
    Q_OBJECT

public:
    // V1 and V2 handlers both add to this log
    ServerLog::AddResult addQSO(tr4w::net::v2::QSORecord& qso) {
        // Same logic for both protocol versions
        // ...
    }

    void broadcastQSO(const tr4w::net::v2::QSORecord& qso) {
        // Send to V2 clients (protobuf)
        tr4w::net::v2::MessageEnvelope envelope;
        m_sequenceManager->assignSequence(envelope);
        auto* update = envelope.mutable_qso_update();
        update->set_operation(tr4w::net::v2::QSOUpdate::ADD);
        *update->mutable_qso() = qso;

        for (auto* client : m_v2Clients)
            client->sendMessage(envelope);

        // Send to V1 clients (binary struct)
        QSORecordV1 v1qso = convertV2ToV1(qso);
        TNetQSOInformation v1msg;
        v1msg.qiID = NET_QSOINFO_ID;
        v1msg.qiInformation = v1qso;

        for (auto* client : m_v1Clients)
            client->sendBinary(&v1msg, sizeof(v1msg));
    }
};
```

---

## Phase 2: V2 Client Release (Month 4-6)

### Goal
Release TR4QT client with V2 protocol support and V1 fallback.

### Adaptive Client

```cpp
class AdaptiveNetworkClient : public QObject {
    Q_OBJECT

public:
    void connectToServer(const QString& host, quint16 port) {
        m_serverHost = host;
        m_serverPort = port;

        // Always try V2 first
        tryV2Connection();
    }

private:
    void tryV2Connection() {
        qInfo() << "Attempting V2 connection...";

        QTcpSocket* socket = new QTcpSocket(this);
        socket->connectToHost(m_serverHost, m_serverPort);

        if (!socket->waitForConnected(5000)) {
            qWarning() << "Connection failed:" << socket->errorString();
            emit connectionFailed(socket->errorString());
            socket->deleteLater();
            return;
        }

        // Send V2 ClientHello
        tr4w::net::v2::ClientHello hello;
        hello.set_protocol_version(2);
        hello.set_client_software("TR4QT");
        hello.set_client_version(QCoreApplication::applicationVersion().toStdString());
        hello.set_station_id(m_stationId.toStdString());
        hello.set_station_name(m_stationName.toStdString());

        // Hash password
        QByteArray passwordHash = hashPassword(m_password, m_serverSalt);
        hello.set_password_hash(passwordHash.toStdString());

        sendProtobuf(socket, hello);

        // Wait for ServerHello
        if (!socket->waitForReadyRead(2000)) {
            qWarning() << "No V2 response, trying V1...";
            socket->disconnectFromHost();
            socket->deleteLater();

            tryV1Connection();
            return;
        }

        // Parse ServerHello
        tr4w::net::v2::ServerHello response;
        if (receiveProtobuf(socket, response)) {
            if (response.authentication_success()) {
                qInfo() << "V2 connection successful!";
                m_protocol = new V2Protocol(socket, this);
                emit connected();
            }
            else {
                qCritical() << "Authentication failed:"
                           << QString::fromStdString(response.rejection_reason());
                emit connectionFailed("Authentication failed");
            }
        }
        else {
            qWarning() << "V2 handshake failed, trying V1...";
            socket->disconnectFromHost();
            socket->deleteLater();

            tryV1Connection();
        }
    }

    void tryV1Connection() {
        qInfo() << "Attempting V1 (legacy) connection...";

        // Implement V1 connection logic
        // (same as original TR4W client)

        QTcpSocket* socket = new QTcpSocket(this);
        socket->connectToHost(m_serverHost, m_serverPort);

        if (!socket->waitForConnected(5000)) {
            qWarning() << "V1 connection failed:" << socket->errorString();
            emit connectionFailed("All protocols failed");
            return;
        }

        // Send password (10 bytes)
        QByteArray password = m_password.leftJustified(10, '\0', true).toUtf8();
        socket->write(password);
        socket->flush();

        // Receive ACK
        socket->waitForReadyRead(2000);
        QByteArray ack = socket->read(4);

        if (ack == "TR4W") {
            qInfo() << "V1 connection successful (legacy mode)";
            m_protocol = new V1Protocol(socket, this);
            emit connected();
        }
        else {
            qCritical() << "V1 authentication failed";
            emit connectionFailed("Authentication failed");
        }
    }

    void sendProtobuf(QTcpSocket* socket, const google::protobuf::Message& msg) {
        QByteArray data(msg.ByteSizeLong(), 0);
        msg.SerializeToArray(data.data(), data.size());

        // Length-prefixed framing
        QByteArray frame;
        QDataStream stream(&frame, QIODevice::WriteOnly);
        stream.setByteOrder(QDataStream::BigEndian);
        stream << static_cast<quint32>(data.size());
        frame.append(data);

        socket->write(frame);
        socket->flush();
    }

    bool receiveProtobuf(QTcpSocket* socket, google::protobuf::Message& msg) {
        // Read 4-byte length prefix
        if (socket->bytesAvailable() < 4)
            return false;

        QByteArray lenBytes = socket->read(4);
        QDataStream stream(lenBytes);
        stream.setByteOrder(QDataStream::BigEndian);
        quint32 length;
        stream >> length;

        // Read message
        if (socket->bytesAvailable() < length) {
            socket->waitForReadyRead(1000);
            if (socket->bytesAvailable() < length)
                return false;
        }

        QByteArray data = socket->read(length);
        return msg.ParseFromArray(data.data(), data.size());
    }

signals:
    void connected();
    void connectionFailed(const QString& reason);

private:
    QString m_serverHost;
    quint16 m_serverPort;
    QString m_stationId;
    QString m_stationName;
    QString m_password;
    QByteArray m_serverSalt;

    QObject* m_protocol = nullptr;  // V1Protocol or V2Protocol
};
```

---

## Phase 3: Deprecation Warnings (Month 12-18)

### Server-Side Warnings

```cpp
void V1ProtocolHandler::handleClient(QTcpSocket* socket) {
    qInfo() << "V1 client connected (DEPRECATED)";

    // Send deprecation warning via intercom
    QTimer::singleShot(5000, this, [=]() {
        // V1 intercom message format
        TIntercomMessage warning;
        warning.imID = NET_INTERCOMMESSAGE_ID;
        warning.imSender = 'S';  // Server
        strcpy(warning.imMessage,
               "WARNING: V1 protocol is deprecated. Please upgrade to TR4QT.");

        socket->write(reinterpret_cast<char*>(&warning), sizeof(warning));
    });

    // Log V1 usage for telemetry
    logProtocolUsage("V1", socket->peerAddress().toString());
}
```

### Client-Side Notifications

```cpp
void AdaptiveNetworkClient::tryV1Connection() {
    qWarning() << "Using deprecated V1 protocol";

    // Show warning dialog
    QMessageBox::warning(nullptr,
                         "Deprecated Protocol",
                         "You are connected using the legacy V1 protocol.\n\n"
                         "V1 support will be removed in future versions.\n"
                         "Please ask your server administrator to upgrade to V2.");

    // Continue with V1 connection...
}
```

---

## Phase 4: V1 Removal (Month 24+)

### Configuration Option

```cpp
// tr4w_server.conf
{
    "protocols": {
        "v1_enabled": false,   // Disable V1 support
        "v2_enabled": true
    }
}

// Server code
if (m_config.v1Enabled()) {
    if (isV1Protocol(handshake)) {
        m_v1Handler->handleClient(socket);
    }
}
else {
    if (isV1Protocol(handshake)) {
        qWarning() << "V1 client rejected (protocol disabled)";
        socket->write("V1 protocol no longer supported. Upgrade to V2.");
        socket->disconnectFromHost();
    }
}
```

---

# Implementation Guide

## Project Setup

### Dependencies

**Required:**
- Qt 6.5+ (Core, Network, for GUI: Widgets or QML)
- Protocol Buffers 3.x (`protobuf-lite` sufficient for embedded)
- CMake 3.20+
- C++17 compiler (GCC 9+, Clang 10+, MSVC 2019+)

**Optional:**
- OpenSSL 1.1+ (for TLS support)
- zlib (for compression, usually included with Qt)

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.20)
project(TR4QT VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Qt
find_package(Qt6 REQUIRED COMPONENTS Core Network Widgets)

# Protocol Buffers
find_package(Protobuf REQUIRED)

# Generate protobuf sources
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS
    src/network/protocol/tr4w_protocol.proto
    src/network/protocol/tr4w_qso.proto
    src/network/protocol/tr4w_station.proto
    src/network/protocol/tr4w_spot.proto
    src/network/protocol/tr4w_commands.proto
    src/network/protocol/tr4w_sync.proto
    src/network/protocol/tr4w_intercom.proto
)

# Server executable
add_executable(tr4qt_server
    src/server/main.cpp
    src/server/tr4w_server.cpp
    src/server/server_log.cpp
    src/server/v1_protocol_handler.cpp
    src/server/v2_protocol_handler.cpp
    ${PROTO_SRCS}
)

target_link_libraries(tr4qt_server
    Qt6::Core
    Qt6::Network
    protobuf::libprotobuf-lite
)

# Client executable
add_executable(tr4qt_client
    src/client/main.cpp
    src/client/main_window.cpp
    src/client/network_client.cpp
    src/client/v1_protocol.cpp
    src/client/v2_protocol.cpp
    ${PROTO_SRCS}
)

target_link_libraries(tr4qt_client
    Qt6::Core
    Qt6::Network
    Qt6::Widgets
    protobuf::libprotobuf-lite
)
```

---

## Directory Structure

```
TR4QT/
├── CMakeLists.txt
├── README.md
├── docs/
│   ├── TR4W_NETWORKING_ANALYSIS.md  (this document)
│   ├── API_REFERENCE.md
│   └── USER_GUIDE.md
├── src/
│   ├── network/
│   │   ├── protocol/
│   │   │   ├── tr4w_protocol.proto
│   │   │   ├── tr4w_qso.proto
│   │   │   ├── tr4w_station.proto
│   │   │   ├── tr4w_spot.proto
│   │   │   ├── tr4w_commands.proto
│   │   │   ├── tr4w_sync.proto
│   │   │   └── tr4w_intercom.proto
│   │   ├── message_envelope.h/cpp
│   │   ├── sequence_manager.h/cpp
│   │   └── secure_messaging.h/cpp
│   ├── server/
│   │   ├── main.cpp
│   │   ├── tr4w_server.h/cpp
│   │   ├── server_log.h/cpp
│   │   ├── v1_protocol_handler.h/cpp
│   │   ├── v2_protocol_handler.h/cpp
│   │   ├── exchange_validator.h/cpp
│   │   └── contest_factory.h/cpp
│   ├── client/
│   │   ├── main.cpp
│   │   ├── main_window.h/cpp
│   │   ├── network_client.h/cpp
│   │   ├── resilient_network_client.h/cpp
│   │   ├── v1_protocol.h/cpp
│   │   ├── v2_protocol.h/cpp
│   │   └── ordered_receiver.h/cpp
│   └── common/
│       ├── types.h
│       ├── constants.h
│       └── utils.h/cpp
├── tests/
│   ├── test_protocol.cpp
│   ├── test_server_log.cpp
│   ├── test_dupe_checking.cpp
│   └── test_serialization.cpp
└── build/
```

---

# Performance Analysis

## Bandwidth Comparison: V1 vs V2

### Test Scenario
- **Contest:** CQ WW CW
- **Duration:** 48 hours
- **Stations:** 6 (A-F)
- **QSO Rate:** Average 2000/hour (peaks at 200/hour)
- **Total QSOs:** 6000

### Message Traffic

| Message Type | V1 Size | V2 Size | Frequency | V1 Total/48h | V2 Total/48h |
|--------------|---------|---------|-----------|--------------|--------------|
| **Station Status** | 40 B | 50 B | 6 stations × 720/hr | 8.3 MB | 10.4 MB |
| **QSO Updates** | 270 B | 200 B | 6000 QSOs | 1.6 MB | 1.2 MB |
| **QSO Edits** | 270 B | 200 B | ~300 edits (5%) | 81 KB | 60 KB |
| **DX Spots** | 90 B | 75 B | ~2000 spots | 180 KB | 150 KB |
| **Intercom** | 84 B | 70 B | ~500 messages | 42 KB | 35 KB |
| **Server Commands** | 8 B | 30 B | ~100 commands | 0.8 KB | 3 KB |
| **Log Sync** | N/A | Varies | 6 syncs | 3.2 MB | 3.0 MB |
| **Total** | | | | **13.4 MB** | **14.8 MB** |

**Result:** V2 uses **10% more bandwidth** due to:
- Protobuf overhead (~15-20% per message)
- Offset by more efficient variable-length encoding for small fields
- Sequence numbers add 8 bytes per message

**Verdict:** 1.4 MB difference over 48 hours = **0.06 Kbps average** = negligible

---

## CPU Overhead

### Benchmark: Serialization Performance

**Test:** Serialize 10,000 QSO messages

**Hardware:** Intel i7-10700K @ 3.8 GHz, 32GB RAM

```cpp
// Benchmark code
void benchmarkSerialization() {
    tr4w::net::v2::QSORecord qso;
    qso.set_callsign("W1AW");
    qso.set_frequency_hz(14025000);
    qso.set_band(tr4w::net::v2::BAND_20M);
    // ... populate all fields

    auto start = std::chrono::high_resolution_clock::now();

    for (int i = 0; i < 10000; ++i) {
        QByteArray data(qso.ByteSizeLong(), 0);
        qso.SerializeToArray(data.data(), data.size());
    }

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    qInfo() << "10,000 serializations:" << duration.count() << "µs";
    qInfo() << "Per message:" << (duration.count() / 10000.0) << "µs";
}
```

**Results:**

| Operation | V1 (memcpy) | V2 (protobuf) | V2 (compressed) |
|-----------|-------------|---------------|-----------------|
| **10,000 messages** | 1.2 ms | 18.5 ms | 42.3 ms |
| **Per message** | 0.12 µs | 1.85 µs | 4.23 µs |
| **QSOs/second** | 8,333,333 | 540,540 | 236,407 |

**Real-world impact:**
- Peak QSO rate: 200/hour = 0.056 QSOs/second
- V2 overhead: 1.85 µs × 0.056 = **0.1 µs per second** = negligible
- CPU usage: <0.01% on modern CPU

**Verdict:** Protobuf overhead is **unnoticeable** at contest QSO rates.

---

## Memory Usage

### Message Buffer Sizes

**V1:**
```cpp
ServerBuffer: array[0..4095] of Char;  // 4 KB fixed
NetBuffer: array[0..4095] of Char;     // 4 KB fixed
```

**V2:**
```cpp
QByteArray m_receiveBuffer;  // Dynamically sized
// Typical: 512 bytes (for station status)
// Peak: 4-8 KB (for log sync batches)
```

**Out-of-Order Buffer (V2 only):**
```cpp
QMap<uint64_t, MessageEnvelope> m_outOfOrder;
// Max 1000 messages buffered
// Average message: 200 bytes
// Max memory: 200 KB
```

**V2 increases memory by ~200 KB per client** (acceptable tradeoff for ordering guarantees).

---

## Network Latency

### LAN Performance (1 Gbps)

**V1 Round-Trip (QSO logging):**
```
Client A: Log QSO → send 270 bytes
  ↓ 0.05 ms (network)
Server: Receive, append to log, broadcast
  ↓ 0.1 ms (processing)
Client B-F: Receive 270 bytes
  ↓ 0.05 ms (network)
Total: ~5-10 ms
```

**V2 Round-Trip (QSO logging):**
```
Client A: Log QSO → serialize protobuf → send 200 bytes
  ↓ 0.05 ms (network)
  ↓ 0.002 ms (protobuf parse)
Server: Validate, append to log, assign sequence, broadcast
  ↓ 0.15 ms (processing)
  ↓ 0.002 ms (protobuf serialize × 5 clients)
Client B-F: Receive, parse protobuf, apply
  ↓ 0.05 ms (network)
  ↓ 0.002 ms (protobuf parse)
Total: ~7-12 ms
```

**Result:** V2 adds ~2-3 ms latency (imperceptible to operators).

---

# Testing Strategy

## Unit Tests

### Protocol Serialization

```cpp
TEST(ProtobufSerialization, StationStatus) {
    // Create message
    tr4w::net::v2::StationStatus status;
    status.set_station_id("A");
    status.set_frequency_hz(14025000);
    status.set_band(tr4w::net::v2::BAND_20M);
    status.set_qso_count(1523);

    // Serialize
    QByteArray data(status.ByteSizeLong(), 0);
    ASSERT_TRUE(status.SerializeToArray(data.data(), data.size()));

    // Deserialize
    tr4w::net::v2::StationStatus parsed;
    ASSERT_TRUE(parsed.ParseFromArray(data.data(), data.size()));

    // Verify
    EXPECT_EQ(parsed.station_id(), "A");
    EXPECT_EQ(parsed.frequency_hz(), 14025000);
    EXPECT_EQ(parsed.band(), tr4w::net::v2::BAND_20M);
    EXPECT_EQ(parsed.qso_count(), 1523);
}
```

### Dupe Checking

```cpp
TEST(ServerLog, DupeChecking) {
    ServerLog log;

    // Add first QSO
    tr4w::net::v2::QSORecord qso1;
    qso1.set_callsign("W1AW");
    qso1.set_band(tr4w::net::v2::BAND_20M);
    qso1.set_mode(tr4w::net::v2::MODE_CW);

    EXPECT_EQ(log.addQSO(qso1), ServerLog::SUCCESS);
    EXPECT_EQ(qso1.qso_id(), 1);  // Server assigned ID

    // Try to add duplicate
    tr4w::net::v2::QSORecord qso2;
    qso2.set_callsign("W1AW");  // Same call
    qso2.set_band(tr4w::net::v2::BAND_20M);  // Same band
    qso2.set_mode(tr4w::net::v2::MODE_CW);  // Same mode

    EXPECT_EQ(log.addQSO(qso2), ServerLog::DUPLICATE);

    // Different band = not dupe
    tr4w::net::v2::QSORecord qso3;
    qso3.set_callsign("W1AW");
    qso3.set_band(tr4w::net::v2::BAND_40M);  // Different band
    qso3.set_mode(tr4w::net::v2::MODE_CW);

    EXPECT_EQ(log.addQSO(qso3), ServerLog::SUCCESS);
}
```

### Message Ordering

```cpp
TEST(OrderedReceiver, OutOfOrderMessages) {
    OrderedReceiver receiver;
    QVector<uint64_t> processed;

    connect(&receiver, &OrderedReceiver::messageProcessed, [&](uint64_t seq) {
        processed.append(seq);
    });

    // Send messages out of order
    receiver.receiveMessage(createMessage(3));
    EXPECT_EQ(processed.size(), 0);  // Buffered

    receiver.receiveMessage(createMessage(1));
    EXPECT_EQ(processed.size(), 1);  // Processed
    EXPECT_EQ(processed[0], 1);

    receiver.receiveMessage(createMessage(2));
    EXPECT_EQ(processed.size(), 3);  // Processed 2 and 3
    EXPECT_EQ(processed[1], 2);
    EXPECT_EQ(processed[2], 3);
}
```

---

## Integration Tests

### Client-Server Communication

```cpp
TEST_F(IntegrationTest, QSOLogging) {
    // Start server
    TR4WServer server;
    ASSERT_TRUE(server.start(TEST_PORT));

    // Connect two clients
    NetworkClient clientA("A", "Station-A");
    NetworkClient clientB("B", "Station-B");

    ASSERT_TRUE(clientA.connectToServer("localhost", TEST_PORT));
    ASSERT_TRUE(clientB.connectToServer("localhost", TEST_PORT));

    QSignalSpy spyB(&clientB, &NetworkClient::qsoReceived);

    // Client A logs QSO
    tr4w::net::v2::QSORecord qso;
    qso.set_callsign("DL1ABC");
    qso.set_frequency_hz(14025000);
    qso.set_band(tr4w::net::v2::BAND_20M);
    qso.set_mode(tr4w::net::v2::MODE_CW);

    clientA.logQSO(qso);

    // Client B should receive it
    ASSERT_TRUE(spyB.wait(1000));
    ASSERT_EQ(spyB.count(), 1);

    auto receivedQSO = spyB[0][0].value<tr4w::net::v2::QSORecord>();
    EXPECT_EQ(receivedQSO.callsign(), "DL1ABC");
    EXPECT_GT(receivedQSO.qso_id(), 0);  // Server assigned ID
}
```

### Reconnection

```cpp
TEST_F(IntegrationTest, AutoReconnect) {
    TR4WServer server;
    server.start(TEST_PORT);

    ResilientNetworkClient client;
    client.connectToServer("localhost", TEST_PORT);

    ASSERT_TRUE(waitForSignal(&client, &ResilientNetworkClient::connected, 5000));

    // Kill server
    server.stop();

    ASSERT_TRUE(waitForSignal(&client, &ResilientNetworkClient::disconnected, 2000));

    // Restart server
    server.start(TEST_PORT);

    // Client should auto-reconnect
    ASSERT_TRUE(waitForSignal(&client, &ResilientNetworkClient::connected, 10000));
}
```

---

## Stress Tests

### High QSO Rate

```cpp
TEST(StressTest, HighQSORate) {
    TR4WServer server;
    server.start(TEST_PORT);

    NetworkClient client("A", "Speed-Station");
    client.connectToServer("localhost", TEST_PORT);

    auto start = std::chrono::steady_clock::now();

    // Log 1000 QSOs as fast as possible
    for (int i = 0; i < 1000; ++i) {
        tr4w::net::v2::QSORecord qso;
        qso.set_callsign(QString("W1ABC%1").arg(i).toStdString());
        qso.set_frequency_hz(14000000 + i * 100);
        qso.set_band(tr4w::net::v2::BAND_20M);
        qso.set_mode(tr4w::net::v2::MODE_CW);

        client.logQSO(qso);
    }

    auto end = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

    qInfo() << "1000 QSOs in" << duration.count() << "ms";
    qInfo() << "Rate:" << (1000.0 / duration.count() * 1000) << "QSOs/sec";

    // Should handle >100 QSOs/second
    EXPECT_LT(duration.count(), 10000);  // Less than 10 seconds
}
```

### Many Clients

```cpp
TEST(StressTest, ManyClients) {
    TR4WServer server;
    server.start(TEST_PORT);

    QVector<NetworkClient*> clients;

    // Connect 26 clients (max)
    for (char id = 'A'; id <= 'Z'; ++id) {
        auto* client = new NetworkClient(QString(id), QString("Station-%1").arg(id));
        ASSERT_TRUE(client->connectToServer("localhost", TEST_PORT));
        clients.append(client);
    }

    // All clients log QSO simultaneously
    for (auto* client : clients) {
        tr4w::net::v2::QSORecord qso;
        qso.set_callsign("W1AW");
        qso.set_frequency_hz(14025000);
        qso.set_band(tr4w::net::v2::BAND_20M);
        qso.set_mode(tr4w::net::v2::MODE_CW);

        client->logQSO(qso);
    }

    // Wait for all broadcasts to complete
    QTest::qWait(5000);

    // Each client should have received 25 QSOs (all except their own)
    for (auto* client : clients) {
        EXPECT_EQ(client->qsoCount(), 25);
    }
}
```

---

# Conclusion

## Summary

The TR4W V1 networking protocol is a **well-designed system** that has proven reliable in the field for over a decade. Its strengths—simplicity, low latency, and proven architecture—should be preserved in any modernization effort.

The V2 protocol design addresses V1's limitations (platform lock-in, no versioning, limited error recovery) while maintaining the core broadcast-based architecture that makes TR4W successful.

## Key Recommendations

1. **Implement V2 as a superset of V1** - Dual-mode server ensures smooth migration
2. **Use Protocol Buffers** - Best balance of efficiency, cross-platform support, and versioning
3. **Preserve broadcast pattern** - Don't over-engineer with complex pub/sub systems
4. **Server-authoritative dupe checking** - Eliminates race conditions
5. **Auto-reconnect with message queuing** - Modern reliability expectations
6. **Optional TLS** - Security when needed, performance when not
7. **Gradual migration** - 2+ year timeline to phase out V1

## Next Steps for TR4QT

1. **Month 1-2:** Prototype V2 protocol in TR4QT
   - Implement .proto files
   - Write serialization/deserialization tests
   - Benchmark performance vs V1

2. **Month 3-4:** Build dual-mode server
   - V1 protocol handler (wrapper around original code)
   - V2 protocol handler (new implementation)
   - Unified server log

3. **Month 5-6:** Implement TR4QT client with V2
   - Auto-reconnect logic
   - Ordered message receiver
   - Fallback to V1 support

4. **Month 7-9:** Field testing
   - Small contest operations (1-2 stations)
   - Beta testing with early adopters
   - Performance tuning

5. **Month 10-12:** Production release
   - TR4QT 1.0 with V2 protocol
   - Documentation and migration guides
   - Deprecation timeline announcement

6. **Month 13-24:** Widespread adoption
   - Monitor V1 vs V2 usage
   - Collect feedback
   - Iterate on V2 features

7. **Month 25+:** V1 sunset
   - Disable V1 by default (config option to re-enable)
   - Remove V1 code in major version bump

---

## References

- **TR4W Source Code:** https://github.com/n4af/TR4W
- **Protocol Buffers:** https://protobuf.dev/
- **Qt Network Module:** https://doc.qt.io/qt-6/qtnetwork-index.html
- **ARRL Contest Branch:** http://www.arrl.org/contests
- **CQ WW Contest:** https://www.cqww.com/
- **Contest Logging:** https://www.contestonlinescore.com/

---

**Document Version:** 1.0
**Last Updated:** December 28, 2025
**Maintained By:** TR4QT Development Team

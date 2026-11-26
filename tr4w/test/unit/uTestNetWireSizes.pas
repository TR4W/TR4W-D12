(* EVERY V1 MULTI-OP WIRE SIZE, PINNED.

  The multi-op protocol has no framing: a message is a Word id followed by the
  record that id implies, and the record IS the in-memory type. So changing a
  field in VC.pas changes the bytes on the wire, with nothing to say so. That is
  exactly how TNetDXSpot grew from 98 to 106 bytes on 2026-08-25 (TSpotRecord's
  FSysTime became a TDateTime) and broke every other implementation of the
  protocol without a single test failing here.

  The in-tree client and tr4wserver cannot disagree with each other, because both
  size every record with SizeOf. TR4WServerPy (a separate repository) keeps a
  hand-written table, _build_message_sizes, and a D7 station has the sizes of its
  day. THIS TEST is the place where a change of size makes the build fail, so the
  person making it is told, in the failure message, what else has to change.

  WHAT IT PINS IS WHAT THIS TREE SENDS. Where another implementation disagrees,
  the other implementation is wrong or stale; the failure messages below say so.

  PLATFORM. TNetDXSpot is a packed record holding a NATURALLY ALIGNED
  TSpotRecord (a TDateTime inside it), and ContestExchange is naturally aligned
  too. Their size is therefore a compiler and target decision, not a property of
  the protocol. The literals below were measured on i386-win32. The unit tests
  also run on the Linux CI job, where every literal held on x86_64 (dispatch
  run 40486524295, 2026-10-27), so a different answer there fails here, by
  name. The macOS job does not run the suite yet (issue 141), so aarch64 is
  unmeasured. *)
unit uTestNetWireSizes;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TTestNetWireSizes = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure CheckWire(const aName: string; const aExpected, aActual: integer);
      procedure Test_RecordSizes;
      procedure Test_TheFramerAgreesWithEachRecord;
      procedure Test_TheThreeQSOIdsShareOneSize;
      procedure Test_SpotRecordInsideTheSpotMessage;
      procedure Test_EveryFixedRecordIsUnmanaged;
   end;

implementation

uses
   SysUtils, VC, uNetFraming, uNetHello;

const
   (* The sentence every failure ends with. *)
   WHAT_ELSE = ' changed size: this is a V1 wire change. Update ' +
               '_build_message_sizes in TR4WServerPy (tr4wserver.py), its ' +
               'CLAUDE.md size table, tools/netprobe/netprobe.py, ' +
               'docs/TR4W_NETWORKING_ANALYSIS.md, and say so to any D7 (4.x) ' +
               'station on the network.';

procedure TTestNetWireSizes.CheckWire(const aName: string; const aExpected, aActual: integer);
begin
   CheckEquals(aExpected, aActual, aName + WHAT_ELSE);
end;

(* The table in docs: one line per message record. A record's size INCLUDES its
  leading id Word -- the id is the first field of each record. *)
procedure TTestNetWireSizes.Test_RecordSizes;
begin
   CheckWire('TMessageState (1000)',            64,  SizeOf(TMessageState));
   CheckWire('TLogFileInformation (1010)',      19,  SizeOf(TLogFileInformation));
   CheckWire('TIntercomMessage (1020)',         84,  SizeOf(TIntercomMessage));
   CheckWire('TNetDXSpot (1030)',               106, SizeOf(TNetDXSpot));
   CheckWire('NET_TAKESERVERQSO_SIZE (1060, D7 server)', 382, NET_TAKESERVERQSO_SIZE);
   CheckWire('NET_TIMESYN_SIZE (1070, removed)', 20, NET_TIMESYN_SIZE);
   CheckWire('TParameterToNetwork (1080)',      514, SizeOf(TParameterToNetwork));
   CheckWire('TStationState (1090)',            46,  SizeOf(TStationState));
   CheckWire('TClientStatus (1110)',            3,   SizeOf(TClientStatus));
   CheckWire('TSendSpotViaNetwork (1120)',      48,  SizeOf(TSendSpotViaNetwork));
   CheckWire('TComputerNetID (1130)',           4,   SizeOf(TComputerNetID));
   CheckWire('TServerMessage (1140)',           8,   SizeOf(TServerMessage));
   CheckWire('THelloMessage (1150)',            70,  SizeOf(THelloMessage));
end;

(* The client's own framing table must give the same answers as the records.
  Id 1056 is deliberately absent from it, so it is not asked here. *)
procedure TTestNetWireSizes.Test_TheFramerAgreesWithEachRecord;
begin
   CheckWire('NetMessageSize(MESSAGESTATE)',   64,  NetMessageSize(NET_MESSAGESTATE_ID));
   CheckWire('NetMessageSize(LOGCOMPARE)',     19,  NetMessageSize(NET_LOGCOMPARE_ID));
   CheckWire('NetMessageSize(INTERCOM)',       84,  NetMessageSize(NET_INTERCOMMESSAGE_ID));
   CheckWire('NetMessageSize(NETWORKDXSPOT)',  106, NetMessageSize(NET_NETWORKDXSPOT_ID));
   (* PROTOCOL 5: the three QSO ids are variable messages with no fixed size, and
     the retired fixed 384-byte ids are unknown. *)
   CheckWire('NetMessageSize(retired QSOINFO 1040)',    0, NetMessageSize(1040));
   CheckWire('NetMessageSize(retired EDITEDQSO 1050)',  0, NetMessageSize(1050));
   CheckWire('NetMessageSize(retired OFFLINEQSO 1055)', 0, NetMessageSize(1055));
   CheckWire('NetMessageSize(wire QSO)',          0, NetMessageSize(NET_WIRE_QSO_ID));
   CheckWire('NetMessageSize(TAKESERVERQSO)',  382, NetMessageSize(NET_TAKESERVERQSO_ID));
   CheckWire('NetMessageSize(TIMESYN)',        20,  NetMessageSize(NET_TIMESYN_ID));
   CheckWire('NetMessageSize(PARAMETER)',      514, NetMessageSize(NET_PARAMETER_ID));
   CheckWire('NetMessageSize(STATIONSTATUS)',  46,  NetMessageSize(NET_STATIONSTATUS_ID));
   CheckWire('NetMessageSize(CLIENTSTATUS)',   3,   NetMessageSize(NET_CLIENTSTATUS_ID));
   CheckWire('NetMessageSize(SPOTVIANETWORK)', 48,  NetMessageSize(NET_SPOTVIANETWORK_ID));
   CheckWire('NetMessageSize(COMPUTERID)',     4,   NetMessageSize(NET_COMPUTERID_ID));
   CheckWire('NetMessageSize(SERVERMESSAGE)',  8,   NetMessageSize(NET_SERVERMESSAGE_ID));
   CheckWire('NetMessageSize(HELLO)',          70,  NetMessageSize(NET_HELLO_ID));
   CheckEquals(0, NetMessageSize(NET_THIS_QTC_WAS__SEND_ID),
               'id 1056 has no record and must stay out of the framing table');
end;

(* A new QSO, an edit and an offline QSO are one MESSAGE SHAPE under three ids
  (protocol 5): id, 4-byte length, payload. *)
procedure TTestNetWireSizes.Test_TheThreeQSOIdsShareOneSize;
begin
   CheckEquals(6, NET_WIRE_HEADER_SIZE, 'the header is the id Word and a 4-byte length');
   CheckEquals(60000, NET_WIRE_MAX_PAYLOAD, 'the payload cap');
   CheckEquals(131072, NET_RECEIVE_BUFFER_SIZE, 'every receive buffer');
   CheckTrue(NetIsWireId(NET_WIRE_QSO_ID) and NetIsWireId(NET_WIRE_EDIT_ID) and
             NetIsWireId(NET_WIRE_OFFLINE_ID), 'all three are wire ids');
end;

(* The spot message is the id plus a TSpotRecord. The inner record is the part
  whose size depends on the compiler's alignment of a Double. *)
procedure TTestNetWireSizes.Test_SpotRecordInsideTheSpotMessage;
begin
   CheckWire('TSpotRecord', 104, SizeOf(TSpotRecord));
   CheckEquals(SizeOf(Word) + SizeOf(TSpotRecord), SizeOf(TNetDXSpot),
               'TNetDXSpot must be the id Word plus exactly one TSpotRecord');
end;

(* ContestExchange IS NOT ON THE WIRE (protocol 5 deleted the fixed 384-byte QSO
  packet) and, since issue 386 batch B, not the .TRW record either: its size is
  no contract, so it is not pinned here. The file's record is uLogBinaryFile's
  frozen TTrwRecordV17, pinned in uTestLogBinaryFile. *)

(* EVERY FIXED MESSAGE IS SENT AS ITS OWN BYTES (SendToNet(rec, SizeOf(rec))),
  so none may hold a managed field: a string or a dynamic array would put a
  POINTER on the wire. A run-time check, not VC's compile guard: these are
  fixed messages whose sizes are pinned above. No fixed message carries
  ContestExchange any more (issue 386, batch B, deleted TNetSynQSOInformation). *)
procedure TTestNetWireSizes.Test_EveryFixedRecordIsUnmanaged;
begin
   CheckFalse(IsManagedType(TMessageState), 'TMessageState');
   CheckFalse(IsManagedType(TLogFileInformation), 'TLogFileInformation');
   CheckFalse(IsManagedType(TIntercomMessage), 'TIntercomMessage');
   CheckFalse(IsManagedType(TNetDXSpot), 'TNetDXSpot');
   CheckFalse(IsManagedType(TParameterToNetwork), 'TParameterToNetwork');
   CheckFalse(IsManagedType(TStationState), 'TStationState');
   CheckFalse(IsManagedType(TClientStatus), 'TClientStatus');
   CheckFalse(IsManagedType(TSendSpotViaNetwork), 'TSendSpotViaNetwork');
   CheckFalse(IsManagedType(TComputerNetID), 'TComputerNetID');
   CheckFalse(IsManagedType(TServerMessage), 'TServerMessage');
   CheckFalse(IsManagedType(THelloMessage), 'THelloMessage');
end;

procedure TTestNetWireSizes.RunAllTests;
begin
   Test_RecordSizes;
   Test_TheFramerAgreesWithEachRecord;
   Test_TheThreeQSOIdsShareOneSize;
   Test_SpotRecordInsideTheSpotMessage;
   Test_EveryFixedRecordIsUnmanaged;
end;

end.

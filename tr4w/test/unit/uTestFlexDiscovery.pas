unit uTestFlexDiscovery;
{$I ..\..\src\tr4w.inc}

{
  Parses a REAL FlexRadio discovery datagram.

  The 676 bytes below are a verbatim capture from NY4I's FLEX-6300 on
  2026-07-29, taken off UDP 4992 with the radio powered up. FlexRadio's
  discovery packet format is not in any document we hold -- the SmartSDR CAT
  User Guide covers the CAT port only -- so this capture IS the specification,
  and pinning it in a test is what stops the parser drifting away from the one
  piece of ground truth we have.

  No radio and no network: ParsePacket is deliberately Indy-free and takes bytes.

  BYTES, not a string.  The header carries $A9, $FF and $6A; decoding those
  through the machine's ANSI codepage would corrupt them, which is the same trap
  that broke CI-V serial I/O.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFlexDiscovery;

type
   TFlexDiscoveryTests = class(TTestCase)
   protected
      procedure Test_ParsesRealCapture;
      procedure Test_RejectsForeignPacket;
      procedure Test_RejectsTruncatedPacket;
      procedure Test_ValueForMatchesWholeKeyOnly;
      procedure Test_SecondPacketCarriesNoStaleFields;
      procedure Test_RejectedPacketClearsPreviousFields;
      procedure Test_ReparsingDoesNotLeak;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   // Verbatim capture -- do not "tidy" these bytes.
   CAPTURE: array[0..675] of Byte = (
      $38, $5D, $00, $A9, $00, $00, $08, $00, $00, $00, $1C, $2D, $53, $4C, $FF, $FF,
      $6A, $69, $A0, $78, $00, $00, $00, $00, $00, $00, $00, $00, $64, $69, $73, $63,
      $6F, $76, $65, $72, $79, $5F, $70, $72, $6F, $74, $6F, $63, $6F, $6C, $5F, $76,
      $65, $72, $73, $69, $6F, $6E, $3D, $33, $2E, $31, $2E, $30, $2E, $32, $20, $6D,
      $6F, $64, $65, $6C, $3D, $46, $4C, $45, $58, $2D, $36, $33, $30, $30, $20, $73,
      $65, $72, $69, $61, $6C, $3D, $34, $35, $31, $35, $2D, $35, $30, $34, $35, $2D,
      $36, $33, $30, $30, $2D, $34, $30, $31, $38, $20, $76, $65, $72, $73, $69, $6F,
      $6E, $3D, $34, $2E, $31, $2E, $35, $2E, $33, $39, $37, $39, $34, $20, $6E, $69,
      $63, $6B, $6E, $61, $6D, $65, $3D, $46, $4C, $45, $58, $2D, $36, $33, $30, $30,
      $20, $63, $61, $6C, $6C, $73, $69, $67, $6E, $3D, $57, $34, $47, $41, $43, $20,
      $69, $70, $3D, $31, $39, $32, $2E, $31, $36, $38, $2E, $37, $33, $2E, $31, $32,
      $38, $20, $70, $6F, $72, $74, $3D, $34, $39, $39, $32, $20, $73, $74, $61, $74,
      $75, $73, $3D, $41, $76, $61, $69, $6C, $61, $62, $6C, $65, $20, $69, $6E, $75,
      $73, $65, $5F, $69, $70, $3D, $31, $39, $32, $2E, $31, $36, $38, $2E, $37, $33,
      $2E, $32, $31, $38, $20, $69, $6E, $75, $73, $65, $5F, $68, $6F, $73, $74, $3D,
      $31, $39, $32, $2E, $31, $36, $38, $2E, $37, $33, $2E, $32, $31, $38, $20, $6D,
      $61, $78, $5F, $6C, $69, $63, $65, $6E, $73, $65, $64, $5F, $76, $65, $72, $73,
      $69, $6F, $6E, $3D, $76, $33, $20, $72, $61, $64, $69, $6F, $5F, $6C, $69, $63,
      $65, $6E, $73, $65, $5F, $69, $64, $3D, $30, $30, $2D, $31, $43, $2D, $32, $44,
      $2D, $30, $32, $2D, $30, $41, $2D, $44, $43, $20, $66, $70, $63, $5F, $6D, $61,
      $63, $3D, $20, $77, $61, $6E, $5F, $63, $6F, $6E, $6E, $65, $63, $74, $65, $64,
      $3D, $31, $20, $6C, $69, $63, $65, $6E, $73, $65, $64, $5F, $63, $6C, $69, $65,
      $6E, $74, $73, $3D, $32, $20, $61, $76, $61, $69, $6C, $61, $62, $6C, $65, $5F,
      $63, $6C, $69, $65, $6E, $74, $73, $3D, $31, $20, $6D, $61, $78, $5F, $70, $61,
      $6E, $61, $64, $61, $70, $74, $65, $72, $73, $3D, $32, $20, $61, $76, $61, $69,
      $6C, $61, $62, $6C, $65, $5F, $70, $61, $6E, $61, $64, $61, $70, $74, $65, $72,
      $73, $3D, $31, $20, $6D, $61, $78, $5F, $73, $6C, $69, $63, $65, $73, $3D, $32,
      $20, $61, $76, $61, $69, $6C, $61, $62, $6C, $65, $5F, $73, $6C, $69, $63, $65,
      $73, $3D, $30, $20, $67, $75, $69, $5F, $63, $6C, $69, $65, $6E, $74, $5F, $69,
      $70, $73, $3D, $31, $39, $32, $2E, $31, $36, $38, $2E, $37, $33, $2E, $32, $31,
      $38, $20, $67, $75, $69, $5F, $63, $6C, $69, $65, $6E, $74, $5F, $68, $6F, $73,
      $74, $73, $3D, $31, $39, $32, $2E, $31, $36, $38, $2E, $37, $33, $2E, $32, $31,
      $38, $20, $67, $75, $69, $5F, $63, $6C, $69, $65, $6E, $74, $5F, $70, $72, $6F,
      $67, $72, $61, $6D, $73, $3D, $53, $6D, $61, $72, $74, $53, $44, $52, $2D, $57,
      $69, $6E, $20, $67, $75, $69, $5F, $63, $6C, $69, $65, $6E, $74, $5F, $73, $74,
      $61, $74, $69, $6F, $6E, $73, $3D, $52, $41, $44, $49, $4F, $31, $20, $67, $75,
      $69, $5F, $63, $6C, $69, $65, $6E, $74, $5F, $68, $61, $6E, $64, $6C, $65, $73,
      $3D, $30, $78, $33, $37, $45, $32, $37, $43, $37, $38, $20, $6D, $69, $6E, $5F,
      $73, $6F, $66, $74, $77, $61, $72, $65, $5F, $76, $65, $72, $73, $69, $6F, $6E,
      $3D, $31, $2E, $31, $2E, $31, $33, $20, $65, $78, $74, $65, $72, $6E, $61, $6C,
      $5F, $70, $6F, $72, $74, $5F, $6C, $69, $6E, $6B, $3D, $30, $20, $6C, $69, $63,
      $65, $6E, $73, $65, $5F, $69, $73, $5F, $75, $6E, $6B, $6E, $6F, $77, $6E, $3D,
      $30, $00, $00, $00
   );

procedure TFlexDiscoveryTests.Test_ParsesRealCapture;
var
   r: TFlexDiscoveredRadio;
begin
   BeginTest('parses the captured FLEX-6300 discovery datagram');
   CheckTrue(TFlexDiscovery.ParsePacket(CAPTURE, Length(CAPTURE), r),
             'a real capture must parse');
   // The value the caller actually needs.
   CheckEquals('192.168.73.128', r.IPAddress, 'ip');
   CheckEquals(4992, r.Port, 'port');
   CheckEquals('FLEX-6300', r.Model, 'model');
   CheckEquals('FLEX-6300', r.Nickname, 'nickname');
   CheckEquals('4515-5045-6300-4018', r.Serial, 'serial');
   CheckEquals('Available', r.Status, 'status');
end;

procedure TFlexDiscoveryTests.Test_RejectsForeignPacket;
var
   bad: array[0..675] of Byte;
   r: TFlexDiscoveredRadio;
   i: Integer;
begin
   // Same packet with the Class ID OUI changed: something else broadcasting on
   // 4992 must be rejected, not parsed. Paired with the test above so this
   // cannot pass by ParsePacket rejecting everything.
   BeginTest('rejects a packet whose Class ID OUI is not FlexRadio');
   for i := 0 to High(CAPTURE) do
      begin
      bad[i] := CAPTURE[i];
      end;
   bad[FLEX_CLASSID_OUI_OFFSET + 2] := $99;   // 00 00 1C 2D -> 00 00 99 2D
   CheckFalse(TFlexDiscovery.ParsePacket(bad, Length(bad), r),
              'a non-Flex OUI must be rejected');
end;

procedure TFlexDiscoveryTests.Test_RejectsTruncatedPacket;
var
   r: TFlexDiscoveredRadio;
begin
   // A runt datagram must not index past the buffer.
   BeginTest('rejects a datagram too short to hold a payload');
   CheckFalse(TFlexDiscovery.ParsePacket(CAPTURE, 12, r), 'runt packet must be rejected');
end;

procedure TFlexDiscoveryTests.Test_ValueForMatchesWholeKeyOnly;
begin
   // The real payload contains ip=, inuse_ip= AND gui_client_ips=. A substring
   // match on 'ip=' would return the wrong address -- and would look correct,
   // because it still yields a valid-looking IP.
   BeginTest('ValueFor matches a whole key, not a substring');
   CheckEquals('192.168.73.128',
               TFlexDiscovery.ValueFor('inuse_ip=1.2.3.4 ip=192.168.73.128 gui_client_ips=5.6.7.8', 'ip'),
               'ip must not match inuse_ip or gui_client_ips');
   CheckEquals('1.2.3.4',
               TFlexDiscovery.ValueFor('inuse_ip=1.2.3.4 ip=192.168.73.128', 'inuse_ip'),
               'inuse_ip resolves to its own value');
   CheckEquals('', TFlexDiscovery.ValueFor('model=FLEX-6300', 'absent'), 'missing key -> empty');
end;

(* The captured VITA-49 header followed by a caller-supplied payload and a NUL.
   The header is what makes ParsePacket accept it; only the key=value run
   differs from the real capture. *)
function PacketWithPayload(const Payload: AnsiString): TBytes;
var
   i: Integer;
begin
   SetLength(Result, FLEX_PAYLOAD_OFFSET + Length(Payload) + 1);
   for i := 0 to FLEX_PAYLOAD_OFFSET - 1 do
      begin
      Result[i] := CAPTURE[i];
      end;
   for i := 1 to Length(Payload) do
      begin
      Result[FLEX_PAYLOAD_OFFSET + i - 1] := Byte(Payload[i]);
      end;
   Result[High(Result)] := 0;
end;

procedure TFlexDiscoveryTests.Test_SecondPacketCarriesNoStaleFields;
var
   r: TFlexDiscoveredRadio;
   first, second: TBytes;
begin
   (* DiscoverRadios parses every datagram into ONE reused record. A second
      radio's packet that omits nickname/serial/status/port must not inherit
      the first radio's values -- that would attach one radio's serial number
      to another radio's address. The first packet uses a non-default port so
      the port assertion can tell "stale" from "defaulted". *)
   BeginTest('a second packet into the same record carries none of the first''s fields');
   first := PacketWithPayload('model=FLEX-6300 nickname=SHACK serial=1111-2222 ip=192.168.1.1 port=5555 status=In_Use');
   CheckTrue(TFlexDiscovery.ParsePacket(first, Length(first), r), 'first packet must parse');
   CheckEquals(5555, r.Port, 'first packet''s own port');
   second := PacketWithPayload('model=FLEX-8600 ip=10.1.2.3');
   CheckTrue(TFlexDiscovery.ParsePacket(second, Length(second), r), 'second packet must parse');
   CheckEquals('10.1.2.3', r.IPAddress, 'ip is the second packet''s');
   CheckEquals('FLEX-8600', r.Model, 'model is the second packet''s');
   CheckEquals(FLEX_DISCOVERY_PORT, r.Port, 'absent port= falls back to the default, not the first packet''s 5555');
   CheckEquals('', r.Nickname, 'nickname absent in the second packet');
   CheckEquals('', r.Serial, 'serial absent in the second packet');
   CheckEquals('', r.Status, 'status absent in the second packet');
end;

procedure TFlexDiscoveryTests.Test_RejectedPacketClearsPreviousFields;
var
   r: TFlexDiscoveredRadio;
begin
   (* The early-exit path must leave the record empty, not holding the last
      accepted radio. *)
   BeginTest('a rejected packet leaves no fields from the previous parse');
   CheckTrue(TFlexDiscovery.ParsePacket(CAPTURE, Length(CAPTURE), r), 'first packet must parse');
   CheckFalse(TFlexDiscovery.ParsePacket(CAPTURE, 12, r), 'runt packet must be rejected');
   CheckEquals('', r.IPAddress, 'ip cleared');
   CheckEquals('', r.Model, 'model cleared');
   CheckEquals('', r.Nickname, 'nickname cleared');
   CheckEquals('', r.Serial, 'serial cleared');
   CheckEquals('', r.Status, 'status cleared');
   CheckEquals(0, r.Port, 'port cleared');
end;

procedure TFlexDiscoveryTests.Test_ReparsingDoesNotLeak;
const
   PARSES = 500;
   (* A leak of five strings per parse is several hundred KB over PARSES; a
      correct parser returns to the same heap level. The slack only absorbs
      allocator bookkeeping. *)
   SLACK_BYTES = 4096;
var
   r: TFlexDiscoveredRadio;
   i: Integer;
   before, after: PtrUInt;
begin
   (* FillChar over a record holding managed strings nils their pointers
      without releasing them. DiscoverRadios reuses one record for every
      datagram at 1 Hz per radio, so that leaked five strings per packet. *)
   BeginTest('parsing into a reused record does not leak its strings');
   TFlexDiscovery.ParsePacket(CAPTURE, Length(CAPTURE), r);   // warm-up: r now owns strings
   before := GetFPCHeapStatus.CurrHeapUsed;
   for i := 1 to PARSES do
      begin
      TFlexDiscovery.ParsePacket(CAPTURE, Length(CAPTURE), r);
      end;
   after := GetFPCHeapStatus.CurrHeapUsed;
   CheckTrue(after <= before + SLACK_BYTES,
             Format('heap grew %d bytes over %d parses', [Int64(after) - Int64(before), PARSES]));
end;

procedure TFlexDiscoveryTests.RunAllTests;
begin
   Test_ParsesRealCapture;
   Test_RejectsForeignPacket;
   Test_RejectsTruncatedPacket;
   Test_ValueForMatchesWholeKeyOnly;
   Test_SecondPacketCarriesNoStaleFields;
   Test_RejectedPacketClearsPreviousFields;
   Test_ReparsingDoesNotLeak;
end;

end.

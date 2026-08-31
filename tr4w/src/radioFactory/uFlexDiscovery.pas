{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
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
unit uFlexDiscovery;
{$I ..\tr4w.inc}

{
  FlexRadio 6000-series network discovery.

  PASSIVE, unlike the K4.  There is no probe to send: the radio BROADCASTS a
  VITA-49 datagram to UDP 4992 once per second, unsolicited, whenever it is
  powered up.  Discovery is therefore "bind 4992 and listen for a second or two".

  GROUNDED IN A REAL CAPTURE, not in documentation -- FlexRadio's discovery
  packet format is not in the SmartSDR CAT User Guide, the only Flex document we
  hold.  Three consecutive datagrams were captured from NY4I's FLEX-6300
  (2026-07-29) and every offset below was read off those bytes:

    off  bytes                      meaning
    ---  -------------------------  ------------------------------------------
     0   38 5d 00 a9                VITA-49 header word.  0x00A9 = 169 32-bit
                                    words = 676 bytes = the datagram length.
                                    Low nibble of byte 1 is a packet counter:
                                    it read 5d, 5e, 5f on the three packets.
     4   00 00 08 00                Stream ID
     8   00 00 1c 2d                Class ID word 1 -- OUI 00:1C:2D, FlexRadio
    12   53 4c ff ff                Class ID word 2
    16   6a 69 a0 78                Integer timestamp, UTC seconds.  Rose by 1
                                    per packet, confirming the 1 Hz cadence.
    20   00 x8                      Fractional timestamp
    28   'discovery_protocol_...'   ASCII payload, space-separated key=value,
                                    NUL-padded to the 4-byte boundary.

  Payload from that capture (trimmed):

    discovery_protocol_version=3.1.0.2 model=FLEX-6300 serial=4515-5045-6300-4018
    version=4.1.5.39794 nickname=FLEX-6300 callsign=... ip=192.168.73.128
    port=4992 status=Available ...

  We consume only ip / port / model / nickname / serial / status.  The rest
  (slice counts, GUI client info, licensing) is real but is not TR4W's business.

  BYTE-EXACT.  ParsePacket takes BYTES, never a string: the header carries $A9,
  $FF and $6A, and decoding those through the machine's ANSI codepage would
  corrupt them.  Same rule as the CI-V serial path.

  ParsePacket has no Indy or network dependency so it can be unit-tested against
  the captured bytes with no radio present.
}

interface

uses
  Windows, SysUtils, Classes,
  IdUDPClient, IdGlobal, IdStack,
  Log4D;

const
  FLEX_DISCOVERY_PORT       = 4992;   // radio broadcasts here, once per second
  FLEX_DISCOVERY_TIMEOUT_MS = 3000;   // >= 2 broadcast intervals, so one is certain

  // VITA-49 offsets, from the capture documented above.
  FLEX_CLASSID_OUI_OFFSET   = 8;      // 00 00 1C 2D
  FLEX_PAYLOAD_OFFSET       = 28;     // first byte of the ASCII key=value run
  FLEX_MIN_PACKET_LEN       = FLEX_PAYLOAD_OFFSET + 1;

type
  TFlexDiscoveredRadio = record
    IPAddress : string;   // ip=      -- what the caller actually needs
    Port      : Integer;  // port=    -- 4992 in the capture
    Model     : string;   // model=   e.g. 'FLEX-6300'
    Nickname  : string;   // nickname=
    Serial    : string;   // serial=
    Status    : string;   // status=  e.g. 'Available', 'In_Use'
  end;
  PFlexDiscoveredRadio = ^TFlexDiscoveredRadio;

  TFlexDiscovery = class(TObject)
  public
    // Listens on UDP 4992 for TimeoutMs and returns a TList of
    // PFlexDiscoveredRadio (caller owns the list and the items).
    class function DiscoverRadios(TimeoutMs: Integer = FLEX_DISCOVERY_TIMEOUT_MS): TList;

    // Validates and parses one datagram.  False unless the Class ID OUI is
    // FlexRadio's 00:1C:2D AND the payload yields a non-empty ip=.
    // Indy-free and byte-exact -- unit-testable against captured bytes.
    class function ParsePacket(const Buf: array of Byte; Len: Integer;
                               var Radio: TFlexDiscoveredRadio): Boolean;

    // Pulls one key's value out of a space-separated key=value payload.
    // '' if absent.  Exposed for testing.
    class function ValueFor(const Payload, Key: string): string;
  end;

implementation

uses
  StrUtils,
  VC;   // TIdText -- Indy's own string type, which is not `string` on both compilers

var
  logger: TLogLogger;

class function TFlexDiscovery.ValueFor(const Payload, Key: string): string;
var
  p, stop: Integer;
  needle: string;
begin
  Result := '';
  needle := Key + '=';

  // Must match at a token boundary, or 'ip=' would also hit 'inuse_ip=' and
  // 'gui_client_ips=' -- both present in a real payload.
  p := 1;
  while True do
     begin
     p := PosEx(needle, Payload, p);
     if p = 0 then
        begin
        Exit;
        end;
     if (p = 1) or (Payload[p - 1] = ' ') then
        begin
        Break;
        end;
     Inc(p, Length(needle));
     end;

  Inc(p, Length(needle));
  stop := PosEx(' ', Payload, p);
  if stop = 0 then
     begin
     stop := Length(Payload) + 1;
     end;
  Result := Copy(Payload, p, stop - p);
end;

class function TFlexDiscovery.ParsePacket(const Buf: array of Byte; Len: Integer;
                                          var Radio: TFlexDiscoveredRadio): Boolean;
var
  i: Integer;
  payload: string;
begin
  Result := False;
  FillChar(Radio, SizeOf(Radio), 0);
  Radio.IPAddress := '';
  Radio.Model     := '';
  Radio.Nickname  := '';
  Radio.Serial    := '';
  Radio.Status    := '';
  Radio.Port      := 0;

  if Len < FLEX_MIN_PACKET_LEN then
     begin
     Exit;
     end;

  // Class ID OUI 00:1C:2D identifies FlexRadio.  Anything else on this port is
  // not ours -- reject rather than trying to parse it.
  if not ((Buf[FLEX_CLASSID_OUI_OFFSET]     = $00) and
          (Buf[FLEX_CLASSID_OUI_OFFSET + 1] = $00) and
          (Buf[FLEX_CLASSID_OUI_OFFSET + 2] = $1C) and
          (Buf[FLEX_CLASSID_OUI_OFFSET + 3] = $2D)) then
     begin
     Exit;
     end;

  // Payload is plain ASCII, NUL-padded to the 4-byte boundary.  Build it a byte
  // at a time: no codepage decode, and stop at the first NUL.
  payload := '';
  for i := FLEX_PAYLOAD_OFFSET to Len - 1 do
     begin
     if Buf[i] = 0 then
        begin
        Break;
        end;
     payload := payload + Char(Buf[i]);   // Char, not Chr -- see uRadioYaesuBinary.SendBytes
     end;

  Radio.IPAddress := ValueFor(payload, 'ip');
  Radio.Port      := StrToIntDef(ValueFor(payload, 'port'), FLEX_DISCOVERY_PORT);
  Radio.Model     := ValueFor(payload, 'model');
  Radio.Nickname  := ValueFor(payload, 'nickname');
  Radio.Serial    := ValueFor(payload, 'serial');
  Radio.Status    := ValueFor(payload, 'status');

  // An ip= is the entire point; without one the hit is useless to the caller.
  Result := Radio.IPAddress <> '';
end;

class function TFlexDiscovery.DiscoverRadios(TimeoutMs: Integer): TList;
var
  client: TIdUDPClient;
  RecvBuf: TIdBytes;
  RecvLen: Integer;
  PeerIP: TIdText;   // var parameter of Indy's ReceiveBuffer -- must match Indy exactly
  PeerPort: Word;
  StartTime: LongWord;
  Parsed: TFlexDiscoveredRadio;
  Radio: PFlexDiscoveredRadio;
  i: Integer;
  isDuplicate: Boolean;
  raw: array of Byte;
begin
  Result := TList.Create;

  TIdStack.IncUsage;
  client := TIdUDPClient.Create(nil);
  try
    try
      // Bind the broadcast port and listen.  ReuseSocket is REQUIRED: SmartSDR
      // (or SmartSDR CAT) is usually already bound to 4992 on this machine, and
      // without it the bind fails and discovery finds nothing on exactly the
      // machines most likely to have a Flex.
      client.BoundPort       := FLEX_DISCOVERY_PORT;
      client.ReuseSocket     := rsTrue;
      client.BroadcastEnabled := True;
      client.ReceiveTimeout  := 250;
      client.Active          := True;
      logger.Info('[FlexDiscovery] Listening on UDP %d for %d ms',
                  [FLEX_DISCOVERY_PORT, TimeoutMs]);
    except
      on E: Exception do
         begin
         logger.Warn('[FlexDiscovery] Could not bind UDP %d: %s',
                     [FLEX_DISCOVERY_PORT, E.Message]);
         Exit;
         end;
    end;

    StartTime := GetTickCount;
    while (GetTickCount - StartTime) < LongWord(TimeoutMs) do
       begin
       try
          SetLength(RecvBuf, 2048);
          RecvLen := client.ReceiveBuffer(RecvBuf, PeerIP, PeerPort);

          if RecvLen > 0 then
             begin
             SetLength(raw, RecvLen);
             for i := 0 to RecvLen - 1 do
                begin
                raw[i] := Byte(RecvBuf[i]);
                end;

             if ParsePacket(raw, RecvLen, Parsed) then
                begin
                isDuplicate := False;
                for i := 0 to Result.Count - 1 do
                   begin
                   if PFlexDiscoveredRadio(Result[i])^.IPAddress = Parsed.IPAddress then
                      begin
                      isDuplicate := True;
                      Break;
                      end;
                   end;

                if not isDuplicate then
                   begin
                   New(Radio);
                   Radio^ := Parsed;
                   Result.Add(Radio);
                   logger.Info('[FlexDiscovery] Found %s (%s) serial %s at %s:%d status=%s',
                               [Parsed.Model, Parsed.Nickname, Parsed.Serial,
                                Parsed.IPAddress, Parsed.Port, Parsed.Status]);
                   end;
                end
             else
                begin
                logger.Debug('[FlexDiscovery] %d bytes from %s were not a Flex discovery packet',
                             [RecvLen, PeerIP]);
                end;
             end;
       except
          on E: Exception do
             begin
             // ReceiveTimeout -- keep waiting until the overall window expires.
             end;
       end;
       end;

    logger.Info('[FlexDiscovery] Discovery complete: %d radio(s) found', [Result.Count]);
  finally
    try
       client.Active := False;
    except
       // ignore
    end;
    client.Free;
    TIdStack.DecUsage;
  end;
end;

initialization
  logger := TLogLogger.GetLogger('TR4WDebugLog.FlexDiscovery');

end.

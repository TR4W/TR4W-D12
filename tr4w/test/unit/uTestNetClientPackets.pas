(*
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
 *)

(* WHAT THE CLIENT ITSELF PUTS ON THE WIRE -- 2026-10-27.

  THE BUG THIS PINS. From 2026-08-25 every DX spot, time sync, intercom line and
  spot-via-network this client sent left with id 0: the four global records had
  their id initialisers commented out and nothing assigned them. The server
  cannot frame a stream past an id it does not know, so it dropped the
  connection, and the reconnect, resend and catch-up ran once per spot.

  WHY NOTHING SAW IT. tools/netprobe built its own packets. The size pins in
  uTestNetWireSizes check TYPES. Neither ever looked at a byte the CLIENT wrote.
  This suite does: the real uNet over a TNetClient whose writer is a stub (the
  real queue and writer thread, no socket), every sender driven through its real
  entry point, and the FIRST WORD and LENGTH of what reaches the writer checked
  against the framing table.

  AND THE GUARD in uNet.SendToNet: a packet whose id the table does not know, or
  whose length is not that message's size, is refused and reported once per
  distinct (id, length) per link, whoever built it.

  WHAT IT CANNOT REACH: a real server reading these bytes. That is netprobe and
  the bench. *)
unit uTestNetClientPackets;

{$I ..\..\src\tr4w.inc}

interface

uses
   Classes, SyncObjs, VC, uTR4WTestFramework;

type
   TNetClientPacketTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_AnId0RecordIsRefusedByTheLeafJudge;
      procedure Test_TheRefusalLatchReportsEachPairOnce;

      procedure Test_ADxSpotLeavesWithItsIdAndItsSize;
      procedure Test_SharingOffPostsNoSpot;
      procedure Test_SharingOffIgnoresSpotsFromTheNetwork;
      procedure Test_AnOlderStationsTimeSyncIsSkippedNotActedOn;
      procedure Test_AnIntercomLineLeavesWithItsIdAndItsSize;
      procedure Test_ASpotViaNetworkLeavesWithItsIdAndItsSize;
      procedure Test_StationStatusAndParameterLeaveWithTheirIds;

      procedure Test_TheGuardRefusesIdZeroAndWrongSizes;
      procedure Test_EveryIdTheTableKnowsPassesAtItsSize;
      procedure Test_TheGuardReportsEachBadPairOncePerLink;

      procedure Test_EverySenderGoesThroughItsHelper;

      procedure Test_TheAnnouncedStationCarriesTheTypedCallsign;
      procedure Test_TheConnectThreadDoesNotReadTheEntryField;

      procedure Test_ANotedSharedEditIsSentOnceAtTheSave;
      procedure Test_AnUnsharedEditIsNotSent;
      procedure Test_AnEditTypedBackIsNotSent;
      procedure Test_AnOverLongSharedEditIsToldAndNotSent;
      procedure Test_OnePositionsSettingsAreNotShared;
      procedure Test_TheSharedListIsTheRuledOne;
      procedure Test_APeersOwnPositionSettingsAreRefused;
   end;

implementation

uses
   SysUtils, Forms, StdCtrls, uNet, uNetClient, uNetFraming, uSpots,
   uSettingsModel, uMainForm, uCrashLog, TF,
   uCFG;   (* the noted Preferences edits, issue 315 *)

type
   (* A WRITER WITH NO SOCKET that keeps every packet's bytes. Runs on the
     queue's writer thread. *)
   TCaptureLink = class
   private
      FLock: TCriticalSection;
      FPackets: array of TBytes;
      FCount: integer;
   public
      constructor Create;
      destructor Destroy; override;
      function Write(const aBytes: TBytes): boolean;
      function Count: integer;
      function Packet(const aIndex: integer): TBytes;
   end;

constructor TCaptureLink.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
end;

destructor TCaptureLink.Destroy;
begin
   FLock.Free;
   inherited Destroy;
end;

function TCaptureLink.Write(const aBytes: TBytes): boolean;
begin
   FLock.Enter;
   try
      SetLength(FPackets, FCount + 1);
      FPackets[FCount] := Copy(aBytes, 0, Length(aBytes));
      Inc(FCount);
      Result := True;
   finally
      FLock.Leave;
   end;
end;

function TCaptureLink.Count: integer;
begin
   FLock.Enter;
   try
      Result := FCount;
   finally
      FLock.Leave;
   end;
end;

function TCaptureLink.Packet(const aIndex: integer): TBytes;
begin
   FLock.Enter;
   try
      Result := Copy(FPackets[aIndex], 0, Length(FPackets[aIndex]));
   finally
      FLock.Leave;
   end;
end;

(* Waits (5 s at most) until the writer thread has been handed aCount packets. *)
function WaitPackets(aLink: TCaptureLink; aCount: integer): boolean;
var
   started: QWord;
begin
   started := GetTickCount64;
   repeat
      Result := aLink.Count >= aCount;
      if not Result then
         begin
         Sleep(5);
         end;
   until Result or (GetTickCount64 - started > 5000);
end;

(* The first Word of a packet, low byte first -- how the server reads it. *)
function IdOf(const aBytes: TBytes): Word;
begin
   Result := 0;
   if Length(aBytes) >= SizeOf(Word) then
      begin
      Result := Word(aBytes[0]) or (Word(aBytes[1]) shl 8);
      end;
end;

(* A link with a capturing writer, as the real uNet uses one. *)
procedure OpenLink(out aLink: TCaptureLink);
begin
   aLink := TCaptureLink.Create;
   NetClient := TNetClient.CreateWithWriter(aLink.Write);
   AttachNetClient(NetClient);
   NetBeginLinkSession;
end;

procedure CloseLink(var aLink: TCaptureLink);
begin
   NetClient.Free;
   NetClient := nil;
   FreeAndNil(aLink);
end;

(* --------------------------------------------------------------------------- *)
(* the judge and the latch, alone                                               *)
(* --------------------------------------------------------------------------- *)

procedure TNetClientPacketTests.Test_AnId0RecordIsRefusedByTheLeafJudge;
var
   id: integer;
   passed: integer;
begin
   BeginTest('the leaf judge: id 0 and a wrong size are refused');

   CheckFalse(OutboundPacketIsWellFormed(0, SizeOf(TNetDXSpot)),
              'id 0 at the DX spot size (what the client sent) is refused');
   CheckFalse(OutboundPacketIsWellFormed(0, 0), 'nothing at all');
   CheckFalse(OutboundPacketIsWellFormed(NET_NETWORKDXSPOT_ID, 1),
              'one byte cannot hold an id');
   CheckFalse(OutboundPacketIsWellFormed(NET_NETWORKDXSPOT_ID, -1), 'a negative length');
   CheckFalse(OutboundPacketIsWellFormed(NET_NETWORKDXSPOT_ID, SizeOf(TNetDXSpot) - 1),
              'one byte short');
   CheckFalse(OutboundPacketIsWellFormed(NET_NETWORKDXSPOT_ID, SizeOf(TNetDXSpot) + 1),
              'one byte long');
   CheckFalse(OutboundPacketIsWellFormed(9999, 20), 'an id no table knows');
   CheckTrue(OutboundPacketIsWellFormed(NET_NETWORKDXSPOT_ID, SizeOf(TNetDXSpot)),
             'the right id at the right size passes');

   (* Every id the table knows passes at exactly its size and at no other. *)
   passed := 0;
   for id := 0 to $FFFF do
      begin
      if NetMessageSize(Word(id)) > 0 then
         begin
         Inc(passed);
         CheckTrue(OutboundPacketIsWellFormed(Word(id), NetMessageSize(Word(id))),
                   'id ' + IntToStr(id) + ' at its size');
         CheckFalse(OutboundPacketIsWellFormed(Word(id), NetMessageSize(Word(id)) + 1),
                    'id ' + IntToStr(id) + ' one byte long');
         end;
      end;
   CheckTrue(passed >= 15, 'the table is not empty');
end;

procedure TNetClientPacketTests.Test_TheRefusalLatchReportsEachPairOnce;
var
   latch: TNetSendRefusals;
begin
   BeginTest('the refusal latch reports each (id, length) once');
   latch := TNetSendRefusals.Create;
   try
      CheckTrue(latch.FirstSighting(0, 106), 'first sight of (0, 106)');
      CheckFalse(latch.FirstSighting(0, 106), 'the second is silent');
      CheckFalse(latch.FirstSighting(0, 106), 'and the third');
      CheckTrue(latch.FirstSighting(0, 20), 'another length is another pair');
      CheckTrue(latch.FirstSighting(1030, 106), 'another id is another pair');
      CheckEquals(3, latch.Count, 'three pairs held');
      latch.Forget;
      CheckEquals(0, latch.Count, 'forgotten at link-up');
      CheckTrue(latch.FirstSighting(0, 106), 'and reported again on the next link');
   finally
      latch.Free;
   end;
end;

(* --------------------------------------------------------------------------- *)
(* what the client's own senders write                                          *)
(* --------------------------------------------------------------------------- *)

(* A REAL SPOT, through the real store: a spot added with SendToNetwork True is
  forwarded to the other positions, as a spot arriving from the cluster is. The
  bytes 78 B2 D9 00 are 14,267,000 Hz -- the head NY4I's server log showed
  behind an id of 00 00. *)
procedure TNetClientPacketTests.Test_ADxSpotLeavesWithItsIdAndItsSize;
var
   link: TCaptureLink;
   spot: TSpotRecord;
   bytes: TBytes;
begin
   BeginTest('a DX spot leaves with NET_NETWORKDXSPOT_ID and its size');
   OpenLink(link);
   try
      spot := Default(TSpotRecord);
      spot.FFrequency := 14267000;
      spot.FCall := 'VE7OMT';
      spot.FBand := Band20;
      spot.FMode := CW;
      spot.FSysTime := Now;

      SpotsList.Clear;
      SpotsList.AddSpot(spot, True);
      SpotsList.Clear;

      CheckTrue(WaitPackets(link, 1), 'the spot was written');
      bytes := link.Packet(0);
      CheckEquals(NET_NETWORKDXSPOT_ID, IdOf(bytes), 'the first Word is the spot id');
      CheckEquals(NetMessageSize(NET_NETWORKDXSPOT_ID), Length(bytes), 'and it is 106 bytes');
      CheckEquals($78, bytes[2], 'the frequency follows the id, low byte first');
      CheckEquals($B2, bytes[3], 'frequency byte 2');
      CheckEquals($D9, bytes[4], 'frequency byte 3');
      CheckEquals(1, link.Count, 'and it is the only packet');
   finally
      CloseLink(link);
   end;
end;

(* NETWORK SHARE SPOTS, THE SEND GATE (2026-10-29). With sharing off the spot
  still enters THIS station's list but nothing is posted. The proof that nothing
  was posted is not a wait: an intercom line is posted AFTER the spot, the queue
  is FIFO, and the first packet the writer receives must be that line. *)
procedure TNetClientPacketTests.Test_SharingOffPostsNoSpot;
var
   link: TCaptureLink;
   spot: TSpotRecord;
   savedShare, savedSo2r, savedIe: boolean;
begin
   BeginTest('Network.ShareSpots off: a cluster spot is kept locally and not posted');
   savedShare := Settings.Network.ShareSpots;
   savedSo2r := Settings.BandMap.So2rDisplay;
   savedIe := Settings.Operating.IeSwitch;
   OpenLink(link);
   try
      Settings.BandMap.So2rDisplay := False;
      Settings.Operating.IeSwitch := False;
      spot := Default(TSpotRecord);
      spot.FFrequency := 14267000;
      spot.FCall := 'VE7OMT';
      spot.FBand := Band20;
      spot.FMode := CW;
      spot.FSysTime := Now;

      SpotsList.Clear;
      Settings.Network.ShareSpots := False;
      SpotsList.AddSpot(spot, True);
      CheckEquals(1, SpotsList.Count, 'the spot is in this station''s own list');
      SendIntercomToNet('marker');
      CheckTrue(WaitPackets(link, 1), 'the marker was written');
      CheckEquals(NET_INTERCOMMESSAGE_ID, IdOf(link.Packet(0)),
                  'the first packet is the marker, so no spot went before it');
      CheckEquals(1, link.Count, 'and nothing else was posted');

      (* The same spot with sharing back on is posted: the gate is the setting. *)
      Settings.Network.ShareSpots := True;
      spot.FFrequency := 14268000;
      spot.FCall := 'VE7OMU';
      SpotsList.AddSpot(spot, True);
      CheckTrue(WaitPackets(link, 2), 'the second spot was posted');
      CheckEquals(NET_NETWORKDXSPOT_ID, IdOf(link.Packet(1)), 'it is a DX spot');
      CheckEquals(NetMessageSize(NET_NETWORKDXSPOT_ID), Length(link.Packet(1)),
                  'of 106 bytes');
   finally
      Settings.Network.ShareSpots := savedShare;
      Settings.BandMap.So2rDisplay := savedSo2r;
      Settings.Operating.IeSwitch := savedIe;
      SpotsList.Clear;
      CloseLink(link);
   end;
end;

(* THE RECEIVE GATE. Two spots back to back in one buffer: with sharing off
  both are consumed whole (no desync, the whole length reported) and neither
  reaches the list; with it on both do. A spot taken from the network is added
  with SendToNetwork False, so it is never posted back. *)
procedure TNetClientPacketTests.Test_SharingOffIgnoresSpotsFromTheNetwork;
var
   link: TCaptureLink;
   savedShare, savedSo2r, savedIe: boolean;

   procedure FeedTwoSpots;
   var
      first, second: TNetDXSpotPtr;
      desync: boolean;
   begin
      first := TNetDXSpotPtr(@NetBuffer[1]);
      second := TNetDXSpotPtr(@NetBuffer[1 + SizeOf(TNetDXSpot)]);
      first^ := Default(TNetDXSpot);
      second^ := Default(TNetDXSpot);
      first^.dsID := NET_NETWORKDXSPOT_ID;
      first^.dsSpot.FFrequency := 14267000;
      first^.dsSpot.FCall := 'VE7OMT';
      first^.dsSpot.FBand := Band20;
      first^.dsSpot.FMode := CW;
      first^.dsSpot.FSysTime := Now;
      second^.dsID := NET_NETWORKDXSPOT_ID;
      second^.dsSpot.FFrequency := 21025000;
      second^.dsSpot.FCall := 'K1ABC';
      second^.dsSpot.FBand := Band15;
      second^.dsSpot.FMode := CW;
      second^.dsSpot.FSysTime := Now;
      CheckEquals(2 * SizeOf(TNetDXSpot),
                  ConsumeNetBuffer(2 * SizeOf(TNetDXSpot), desync),
                  'both spots were consumed whole');
      CheckFalse(desync, 'and the stream stayed on a message boundary');
   end;

begin
   BeginTest('Network.ShareSpots off: spots from the network are consumed and ignored');
   savedShare := Settings.Network.ShareSpots;
   savedSo2r := Settings.BandMap.So2rDisplay;
   savedIe := Settings.Operating.IeSwitch;
   OpenLink(link);
   try
      Settings.BandMap.So2rDisplay := False;
      Settings.Operating.IeSwitch := False;
      SpotsList.Clear;

      Settings.Network.ShareSpots := False;
      FeedTwoSpots;
      CheckEquals(0, SpotsList.Count, 'sharing off: neither spot reached the list');

      Settings.Network.ShareSpots := True;
      FeedTwoSpots;
      CheckEquals(2, SpotsList.Count, 'sharing on: both spots reached the list');

      SendIntercomToNet('marker');
      CheckTrue(WaitPackets(link, 1), 'the marker was written');
      CheckEquals(NET_INTERCOMMESSAGE_ID, IdOf(link.Packet(0)),
                  'a received spot is never posted back');
      CheckEquals(1, link.Count, 'nothing else was posted');
   finally
      Settings.Network.ShareSpots := savedShare;
      Settings.BandMap.So2rDisplay := savedSo2r;
      Settings.Operating.IeSwitch := savedIe;
      SpotsList.Clear;
      CloseLink(link);
   end;
end;

(* "SYNCHRONIZE TIME ON ALL COMPUTERS" WAS REMOVED (2026-11-03) -- a station may
  not set another's clock. An OLDER station still sends the packet, so a
  time-sync message followed at once by a DX spot must be consumed whole (its 20
  bytes skipped, the stream still on a boundary), the spot must still be handled,
  and nothing may be posted back. Whether the clock is untouched is not
  observable here; nothing in uNet calls a clock setter any more (source read
  in Test_EverySenderGoesThroughItsHelper). *)
procedure TNetClientPacketTests.Test_AnOlderStationsTimeSyncIsSkippedNotActedOn;
var
   link: TCaptureLink;
   savedShare, savedSo2r, savedIe: boolean;
   syn: PWord;
   spot: TNetDXSpotPtr;
   desync: boolean;
   i: integer;
begin
   BeginTest('an older station''s time sync is skipped by its size and not acted on');
   savedShare := Settings.Network.ShareSpots;
   savedSo2r := Settings.BandMap.So2rDisplay;
   savedIe := Settings.Operating.IeSwitch;
   OpenLink(link);
   try
      Settings.BandMap.So2rDisplay := False;
      Settings.Operating.IeSwitch := False;
      Settings.Network.ShareSpots := True;
      SpotsList.Clear;

      for i := 1 to NET_TIMESYN_SIZE do
         begin
         NetBuffer[i] := #0;
         end;
      syn := PWord(@NetBuffer[1]);
      syn^ := NET_TIMESYN_ID;
      NetBuffer[3] := #$EA;     (* wYear 2026, little-endian *)
      NetBuffer[4] := #$07;
      spot := TNetDXSpotPtr(@NetBuffer[1 + NET_TIMESYN_SIZE]);
      spot^ := Default(TNetDXSpot);
      spot^.dsID := NET_NETWORKDXSPOT_ID;
      spot^.dsSpot.FFrequency := 14267000;
      spot^.dsSpot.FCall := 'VE7OMT';
      spot^.dsSpot.FBand := Band20;
      spot^.dsSpot.FMode := CW;
      spot^.dsSpot.FSysTime := Now;

      CheckEquals(NET_TIMESYN_SIZE + SizeOf(TNetDXSpot),
                  ConsumeNetBuffer(NET_TIMESYN_SIZE + SizeOf(TNetDXSpot), desync),
                  'the time sync and the spot behind it were consumed whole');
      CheckFalse(desync, 'the stream stayed on a message boundary');
      CheckEquals(1, SpotsList.Count, 'the spot behind the time sync was handled');

      SendIntercomToNet('marker');
      CheckTrue(WaitPackets(link, 1), 'the marker was written');
      CheckEquals(NET_INTERCOMMESSAGE_ID, IdOf(link.Packet(0)), 'and is the first thing posted');
      CheckEquals(1, link.Count, 'the time sync was not answered or relayed');
   finally
      Settings.Network.ShareSpots := savedShare;
      Settings.BandMap.So2rDisplay := savedSo2r;
      Settings.Operating.IeSwitch := savedIe;
      SpotsList.Clear;
      CloseLink(link);
   end;
end;

procedure TNetClientPacketTests.Test_AnIntercomLineLeavesWithItsIdAndItsSize;
var
   link: TCaptureLink;
   bytes: TBytes;
begin
   BeginTest('an intercom line leaves with NET_INTERCOMMESSAGE_ID and its size');
   OpenLink(link);
   try
      SendIntercomToNet('hello 40m');
      SendIntercomToNet('');
      CheckTrue(WaitPackets(link, 1), 'the line was written');
      bytes := link.Packet(0);
      CheckEquals(NET_INTERCOMMESSAGE_ID, IdOf(bytes), 'the first Word is the intercom id');
      CheckEquals(NetMessageSize(NET_INTERCOMMESSAGE_ID), Length(bytes), 'and it is 84 bytes');
      CheckEquals(9, integer(bytes[3]), 'the ShortString length byte follows the sender');
      CheckEquals(Ord('h'), integer(bytes[4]), 'and then the text');
      CheckEquals(1, link.Count, 'an empty line sends nothing');
   finally
      CloseLink(link);
   end;
end;

procedure TNetClientPacketTests.Test_ASpotViaNetworkLeavesWithItsIdAndItsSize;
var
   link: TCaptureLink;
   bytes: TBytes;
   i: integer;
begin
   BeginTest('a spot-via-network leaves with NET_SPOTVIANETWORK_ID and its size');
   OpenLink(link);
   try
      SendSpotViaNetworkToNet('DX VE7OMT 14267.0 test');
      (* The longest text the field holds is one short of it, so the terminator
        survives. A longer one is REFUSED with a notice, not cut (issue 315);
        that branch shows a notice on the main window and is not driven here. *)
      SendSpotViaNetworkToNet(StringOfChar('A', 45));
      CheckTrue(WaitPackets(link, 2), 'both were written');

      bytes := link.Packet(0);
      CheckEquals(NET_SPOTVIANETWORK_ID, IdOf(bytes), 'the first Word is the spot-via-network id');
      CheckEquals(NetMessageSize(NET_SPOTVIANETWORK_ID), Length(bytes), 'and it is 48 bytes');
      CheckEquals(Ord('D'), integer(bytes[2]), 'the text follows the id');

      bytes := link.Packet(1);
      CheckEquals(NET_SPOTVIANETWORK_ID, IdOf(bytes), 'the long one has the id too');
      CheckEquals(NetMessageSize(NET_SPOTVIANETWORK_ID), Length(bytes), 'at the same size');
      CheckEquals(0, integer(bytes[Length(bytes) - 1]), 'and ends in a terminator');
      for i := 2 to Length(bytes) - 2 do
         begin
         CheckEquals(Ord('A'), integer(bytes[i]), 'every byte before it is text');
         end;
   finally
      CloseLink(link);
   end;
end;

(* The two that were never broken, captured all the same: ssID and pnID are set
  inside the senders, so a window that never opened (NETWORK AUTO CONNECT) and a
  radio polling thread both get them. *)
procedure TNetClientPacketTests.Test_StationStatusAndParameterLeaveWithTheirIds;
var
   link: TCaptureLink;
begin
   BeginTest('station status and a parameter leave with their ids');
   OpenLink(link);
   try
      SendStationStatus(sstQSOs);
      SendParameterToNetwork('SOME COMMAND', 'SOME VALUE');
      CheckTrue(WaitPackets(link, 2), 'both were written');

      CheckEquals(NET_STATIONSTATUS_ID, IdOf(link.Packet(0)), 'status id');
      CheckEquals(NetMessageSize(NET_STATIONSTATUS_ID), Length(link.Packet(0)), 'status size');
      CheckEquals(NET_PARAMETER_ID, IdOf(link.Packet(1)), 'parameter id');
      CheckEquals(NetMessageSize(NET_PARAMETER_ID), Length(link.Packet(1)), 'parameter size');
   finally
      CloseLink(link);
   end;
end;

(* --------------------------------------------------------------------------- *)
(* the guard                                                                    *)
(* --------------------------------------------------------------------------- *)

procedure TNetClientPacketTests.Test_TheGuardRefusesIdZeroAndWrongSizes;
var
   link: TCaptureLink;
   zero106: array[0..105] of Byte;
   shortDx: array[0..9] of Byte;
   oneByte: array[0..0] of Byte;
   unknown: array[0..19] of Byte;
   i: integer;
begin
   BeginTest('the guard refuses id 0, a wrong size, one byte and an unknown id');
   OpenLink(link);
   try
      for i := Low(zero106) to High(zero106) do
         begin
         zero106[i] := 0;
         end;
      for i := Low(shortDx) to High(shortDx) do
         begin
         shortDx[i] := 0;
         end;
      shortDx[0] := Byte(NET_NETWORKDXSPOT_ID and $FF);
      shortDx[1] := Byte(NET_NETWORKDXSPOT_ID shr 8);
      oneByte[0] := 7;
      for i := Low(unknown) to High(unknown) do
         begin
         unknown[i] := 0;
         end;
      unknown[0] := $0F;
      unknown[1] := $27;      (* 9999 *)

      CheckEquals(0, SendToNet(zero106, SizeOf(zero106)), 'id 0 at 106 bytes: refused');
      CheckEquals(0, SendToNet(shortDx, SizeOf(shortDx)), 'the spot id at 10 bytes: refused');
      CheckEquals(0, SendToNet(oneByte, SizeOf(oneByte)), 'one byte: refused');
      CheckEquals(0, SendToNet(unknown, SizeOf(unknown)), 'an unknown id: refused');
      CheckEquals(4, NetSendRefusalsReported, 'four distinct pairs were reported');

      (* FIFO: when this good packet is the only one written, none of the refused
        ones was ever posted. *)
      SendIntercomToNet('good');
      CheckTrue(WaitPackets(link, 1), 'the good packet was written');
      Sleep(50);
      CheckEquals(1, link.Count, 'and it is the only packet that reached the writer');
   finally
      CloseLink(link);
   end;
end;

(* EVERY ID THE FRAMING TABLE KNOWS goes out at its size, and its result is the
  count posted. A table entry that the guard turned away would break a message
  the server expects. *)
procedure TNetClientPacketTests.Test_EveryIdTheTableKnowsPassesAtItsSize;
var
   link: TCaptureLink;
   buf: TBytes;
   id, size, i, sent: integer;
begin
   BeginTest('every id in the framing table passes at its size');
   OpenLink(link);
   try
      sent := 0;
      for id := 0 to $FFFF do
         begin
         size := NetMessageSize(Word(id));
         if size > 0 then
            begin
            SetLength(buf, size);
            for i := 0 to size - 1 do
               begin
               buf[i] := 0;
               end;
            buf[0] := Byte(id and $FF);
            buf[1] := Byte(id shr 8);
            CheckEquals(size, SendToNet(buf[0], size), 'id ' + IntToStr(id) + ' posted');
            Inc(sent);
            end;
         end;

      CheckTrue(sent >= 15, 'the table is not empty');
      CheckTrue(WaitPackets(link, sent), 'all were written');
      CheckEquals(0, NetSendRefusalsReported, 'none was refused');
   finally
      CloseLink(link);
   end;
end;

procedure TNetClientPacketTests.Test_TheGuardReportsEachBadPairOncePerLink;
var
   link: TCaptureLink;
   zero106: array[0..105] of Byte;
   zero20: array[0..19] of Byte;
   i: integer;
begin
   BeginTest('the guard reports each bad (id, size) once per link');
   OpenLink(link);
   try
      for i := Low(zero106) to High(zero106) do
         begin
         zero106[i] := 0;
         end;
      for i := Low(zero20) to High(zero20) do
         begin
         zero20[i] := 0;
         end;

      for i := 1 to 5 do
         begin
         SendToNet(zero106, SizeOf(zero106));
         end;
      CheckEquals(1, NetSendRefusalsReported, 'five sends of one bad pair: one report');
      SendToNet(zero20, SizeOf(zero20));
      CheckEquals(2, NetSendRefusalsReported, 'a second pair: two');
      SendToNet(zero20, SizeOf(zero20));
      CheckEquals(2, NetSendRefusalsReported, 'a repeat: still two');

      NetBeginLinkSession;
      CheckEquals(0, NetSendRefusalsReported, 'a new link forgets');
      SendToNet(zero106, SizeOf(zero106));
      CheckEquals(1, NetSendRefusalsReported, 'and reports the pair again');
   finally
      CloseLink(link);
   end;
end;

(* THE MENU ARMS CANNOT BE DRIVEN FROM A TEST (QuickEditResponse is modal), so
  the wiring is a source read: each caller goes through its helper, and none of
  the four old global records is named outside uNet's own helpers. The helpers
  themselves are exercised above. *)
procedure TNetClientPacketTests.Test_EverySenderGoesThroughItsHelper;
var
   root: string;

   function Slurp(const aRelative: string): string;
   var
      lines: TStringList;
   begin
      lines := TStringList.Create;
      try
         lines.LoadFromFile(AnsiString(ExpandFileName(root + aRelative)));
         Result := lines.Text;
      finally
         lines.Free;
      end;
   end;

   function BodyOf(const aText, aHeader: string): string;
   var
      p, q: integer;
   begin
      p := Pos(aHeader, aText);
      CheckTrue(p > 0, aHeader + ' is there');
      Result := Copy(aText, p, Length(aText));
      q := Pos(LineEnding + 'end;', Result);
      if q > 0 then
         begin
         Result := Copy(Result, 1, q);
         end;
   end;

var
   net, mainText, spots, command, form: string;
begin
   BeginTest('every sender goes through its helper');
   root := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim;
   net := Slurp('uNet.pas');
   mainText := Slurp('MainUnit.pas');
   spots := Slurp('uSpots.pas');
   command := Slurp('uProcessCommand.pas');
   form := Slurp('ui' + PathDelim + 'lcl' + PathDelim + 'uSendSpotForm.pas');

   CheckTrue(Pos('SendDXSpotToNet(Spot)', spots) > 0, 'uSpots sends through its helper');
   CheckEquals(0, Pos('SendTimeSyncToNet', net + mainText), 'no time-sync sender is left');
   CheckEquals(0, Pos('SetSystemTime', net), 'and uNet cannot set the machine clock');
   CheckTrue(Pos('SendIntercomToNet(', mainText) > 0, 'the send-message arm');
   CheckTrue(Pos('SendIntercomToNet(scFileName)', command) > 0, 'the SENDMESSAGE command');
   CheckTrue(Pos('SendSpotViaNetworkToNet(spot)', form) > 0, 'the spot form');

   CheckEquals(0, Pos('SendToNet(NetDXSpot', spots + mainText + command + form),
               'no caller sends the old DX spot global');
   CheckEquals(0, Pos('SendToNet(NetIntercomMessage', spots + mainText + command + form),
               'nor the intercom global');
   CheckEquals(0, Pos('SendToNet(SendSpotViaNetwork', spots + mainText + command + form),
               'nor the spot-via-network global');

   CheckTrue(Pos('dsID := NET_NETWORKDXSPOT_ID',
                 BodyOf(net, 'procedure SendDXSpotToNet(const aSpot: TSpotRecord);' +
                             LineEnding + 'var')) > 0, 'the DX spot id is set');
   CheckTrue(Pos('imID := NET_INTERCOMMESSAGE_ID',
                 BodyOf(net, 'procedure SendIntercomToNet(const aText: string);' +
                             LineEnding + 'var')) > 0, 'the intercom id is set');
   CheckTrue(Pos('vnID := NET_SPOTVIANETWORK_ID',
                 BodyOf(net, 'procedure SendSpotViaNetworkToNet(const aSpotText: string);' +
                             LineEnding + 'var')) > 0, 'the spot-via-network id is set');
end;

(* ISSUE 150. The status the server is sent when the link comes up must carry
  the callsign the operator has typed. The connect thread used to build it and
  read the entry field from a worker thread, where the guard refuses the read and
  the callsign went out empty.

  THE BYTES ARE CAPTURED FROM THE CLIENT'S OWN SEND PATH, with a real TEdit
  standing in for the call window (the global the program reads is TR4WCallEdit).
  The announcement runs here, on the main thread, as the drainer runs it. *)
procedure TNetClientPacketTests.Test_TheAnnouncedStationCarriesTheTypedCallsign;
var
   link: TCaptureLink;
   frm: TForm;
   edit: TEdit;
   savedEdit: TEdit;
   bytes: TBytes;
   st: ^TStationState;
   i, found, statusPackets, lastIndex: integer;
begin
   BeginTest('the station announced at link-up carries the typed callsign');
   InstallCrashLog;   (* records the main thread id; OnMainThread is false without it *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;
   savedEdit := TR4WCallEdit;
   frm := TForm.CreateNew(nil);
   OpenLink(link);
   try
      edit := TEdit.Create(frm);
      edit.Parent := frm;
      edit.Text := 'K1ABC';
      edit.HandleNeeded;
      TR4WCallEdit := edit;

      NetAnnounceStation;

      (* Every status type, the cluster state and the request for the others. *)
      CheckTrue(WaitPackets(link, Ord(High(StationStatusType)) + 1 + 2),
                'the whole announcement was written');
      found := 0;
      statusPackets := 0;
      lastIndex := link.Count - 1;
      for i := 0 to link.Count - 1 do
         begin
         bytes := link.Packet(i);
         if IdOf(bytes) = NET_STATIONSTATUS_ID then
            begin
            Inc(statusPackets);
            CheckEquals(SizeOf(TStationState), Length(bytes), 'a status is its full size');
            st := @bytes[0];   (* the bytes read as the record, no copy *)
            if st^.ssType = sstCallsign then
               begin
               Inc(found);
               CheckEquals('K1ABC', string(PAnsiChar(@st^.ssCallsign[0])),
                           'the callsign status carries what was typed');
               end;
            end;
         end;
      CheckEquals(1, found, 'exactly one callsign status');
      CheckEquals(Ord(High(StationStatusType)) + 1, statusPackets, 'one status per type');
      CheckEquals(NET_SERVERMESSAGE_ID, IdOf(link.Packet(lastIndex)),
                  'and the request for the others'' statuses goes last');
   finally
      TR4WCallEdit := savedEdit;
      CloseLink(link);
      frm.Free;
   end;
end;

(* The wiring half: nothing the connect thread runs may reach SendFullStationStatus
  or the entry field. The thread schedules the announcement instead. *)
procedure TNetClientPacketTests.Test_TheConnectThreadDoesNotReadTheEntryField;
var
   lines: TStringList;
   text, body: string;
   p, q: integer;
begin
   BeginTest('ConnectThread schedules the announcement and does not send statuses');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ExpandFileName(ExtractFilePath(ParamStr(0)) +
                         '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim + 'uNet.pas')));
      text := lines.Text;
   finally
      lines.Free;
   end;
   p := Pos('function ConnectThread(aParameter: Pointer): DWORD; stdcall;' + LineEnding + 'label', text);
   CheckTrue(p > 0, 'ConnectThread is there');
   body := Copy(text, p, Length(text));
   q := Pos(LineEnding + 'end;', body);
   CheckTrue(q > 0, 'and ends');
   body := Copy(body, 1, q);
   CheckEquals(0, Pos('SendFullStationStatus', body), 'it does not send the full status');
   CheckEquals(0, Pos('SendStationStatus', body), 'nor any status');
   CheckTrue(Pos('GNetDrainer.AnnounceStation', body) > 0, 'it hands the announcement to the main thread');
end;

(* --------------------------------------------------------------------------- *)
(* a Preferences edit of a shared setting (issue 315)                            *)
(* --------------------------------------------------------------------------- *)

const
   (* Shared, owned by the settings object, contest-scoped: what Preferences
     edits and the peers apply live. *)
   SHARED_EDIT   = 'CONTEST TITLE';
   (* A station's own: never sent. *)
   UNSHARED_EDIT = 'MY NAME';
   (* Sent straight after the flush, so "nothing was sent" is a packet that
     arrives FIRST rather than a wait that times out. *)
   SENTINEL      = 'TEST SENTINEL';

(* The command and the value a parameter packet carries. *)
function ParameterOf(const aBytes: TBytes; out aCommand, aValue: string): boolean;
var
   rec: TParameterToNetwork;
begin
   aCommand := '';
   aValue := '';
   Result := Length(aBytes) = SizeOf(TParameterToNetwork);
   if not Result then
      begin
      Exit;
      end;
   rec := TParameterToNetworkPtr(@aBytes[0])^;
   aCommand := string(rec.pnCommand);
   aValue := string(rec.pnValue);
end;

function LiveValue(const aCommand: string): string;
begin
   if not Settings.TryGetByCommand(aCommand, Result) then
      begin
      Result := '';
      end;
end;

(* The setting put back as the test found it -- its value, and whether it was
  stated, because TrySetByCommand states a contest-scoped setting. *)
procedure RestoreSetting(const aCommand, aValue: string; aStated: boolean);
begin
   Settings.TrySetByCommand(aCommand, aValue);
   Settings.SetCommandStated(aCommand, aStated);
   ForgetSharedPreferenceChange(aCommand);
end;

(* The first packet after a flush: the sentinel when the flush sent nothing. *)
function FirstCommandAfterFlush(aLink: TCaptureLink; out aValue: string): string;
begin
   SendParameterToNetwork(SENTINEL, 'END');
   Result := '';
   aValue := '';
   if WaitPackets(aLink, 1) then
      begin
      ParameterOf(aLink.Packet(0), Result, aValue);
      end;
end;

procedure TNetClientPacketTests.Test_ANotedSharedEditIsSentOnceAtTheSave;
var
   link: TCaptureLink;
   savedValue, command, value: string;
   savedStated: boolean;
begin
   BeginTest('a shared Preferences edit is sent once, with its live value, at the save');
   savedValue := LiveValue(SHARED_EDIT);
   savedStated := Settings.CommandIsStated(SHARED_EDIT);
   OpenLink(link);
   try
      CheckTrue(CommandIsSharedWithPeers(SHARED_EDIT), 'the premise: it is shared');

      (* What a bound control does: note, then apply, as each keystroke does. *)
      NoteSharedPreferenceChange(SHARED_EDIT);
      CheckTrue(Settings.TrySetByCommand(SHARED_EDIT, 'MULTI'), 'a first keystroke');
      NoteSharedPreferenceChange(SHARED_EDIT);
      CheckTrue(Settings.TrySetByCommand(SHARED_EDIT, 'MULTI OP TITLE'), 'the last one');
      CheckTrue(SharedPreferenceChangePending(SHARED_EDIT), 'noted, not yet sent');
      CheckEquals(0, link.Count, 'nothing goes while the operator types');

      ShareNotedPreferenceChanges;
      CheckTrue(WaitPackets(link, 1), 'the save sends it');
      CheckTrue(ParameterOf(link.Packet(0), command, value), 'a parameter packet');
      CheckEquals(NET_PARAMETER_ID, IdOf(link.Packet(0)), 'with the parameter id');
      CheckEquals(SHARED_EDIT, command, 'naming the setting');
      CheckEquals('MULTI OP TITLE', value, 'carrying the final value, not a keystroke');
      CheckFalse(SharedPreferenceChangePending(SHARED_EDIT), 'and the note is gone');

      (* A second save with nothing new sends nothing. *)
      ShareNotedPreferenceChanges;
      SendParameterToNetwork(SENTINEL, 'END');
      CheckTrue(WaitPackets(link, 2), 'the sentinel arrives');
      ParameterOf(link.Packet(1), command, value);
      CheckEquals(SENTINEL, command, 'a second save sent nothing before it');
   finally
      CloseLink(link);
      RestoreSetting(SHARED_EDIT, savedValue, savedStated);
   end;
end;

procedure TNetClientPacketTests.Test_AnUnsharedEditIsNotSent;
var
   link: TCaptureLink;
   savedValue, value: string;
   savedStated: boolean;
begin
   BeginTest('a Preferences edit of a station''s own setting is not sent');
   savedValue := LiveValue(UNSHARED_EDIT);
   savedStated := Settings.CommandIsStated(UNSHARED_EDIT);
   OpenLink(link);
   try
      CheckFalse(CommandIsSharedWithPeers(UNSHARED_EDIT), 'the premise: not shared');
      NoteSharedPreferenceChange(UNSHARED_EDIT);
      CheckFalse(SharedPreferenceChangePending(UNSHARED_EDIT), 'an unshared name is not noted');
      CheckTrue(Settings.TrySetByCommand(UNSHARED_EDIT, savedValue + 'X'), 'the edit');
      ShareNotedPreferenceChanges;
      CheckEquals(SENTINEL, FirstCommandAfterFlush(link, value), 'nothing was sent');
   finally
      CloseLink(link);
      RestoreSetting(UNSHARED_EDIT, savedValue, savedStated);
   end;
end;

procedure TNetClientPacketTests.Test_AnEditTypedBackIsNotSent;
var
   link: TCaptureLink;
   savedValue, value: string;
   savedStated: boolean;
begin
   BeginTest('a shared edit typed back to what it was sends nothing');
   savedValue := LiveValue(SHARED_EDIT);
   savedStated := Settings.CommandIsStated(SHARED_EDIT);
   OpenLink(link);
   try
      NoteSharedPreferenceChange(SHARED_EDIT);
      CheckTrue(Settings.TrySetByCommand(SHARED_EDIT, savedValue + 'X'), 'typed');
      NoteSharedPreferenceChange(SHARED_EDIT);
      CheckTrue(Settings.TrySetByCommand(SHARED_EDIT, savedValue), 'and typed back');
      ShareNotedPreferenceChanges;
      CheckEquals(SENTINEL, FirstCommandAfterFlush(link, value), 'nothing was sent');
   finally
      CloseLink(link);
      RestoreSetting(SHARED_EDIT, savedValue, savedStated);
   end;
end;

procedure TNetClientPacketTests.Test_AnOverLongSharedEditIsToldAndNotSent;
var
   link: TCaptureLink;
   savedValue, longValue, value: string;
   savedStated, beep: boolean;
begin
   BeginTest('a shared edit over 255 bytes is told and not sent; the value stays whole');
   savedValue := LiveValue(SHARED_EDIT);
   savedStated := Settings.CommandIsStated(SHARED_EDIT);
   beep := Settings.Operating.BeepEnable;
   Settings.Operating.BeepEnable := False;   (* the notice beeps *)
   longValue := StringOfChar('T', 300);
   OpenLink(link);
   try
      NoteSharedPreferenceChange(SHARED_EDIT);
      CheckTrue(Settings.TrySetByCommand(SHARED_EDIT, longValue), 'the long value is taken here');
      CheckTrue(SharedSettingNotSentText(SHARED_EDIT, longValue) <> '',
                'the operator is told it will not be sent');
      ShareNotedPreferenceChanges;
      CheckEquals(SENTINEL, FirstCommandAfterFlush(link, value), 'and it was not sent');
      CheckEquals(longValue, LiveValue(SHARED_EDIT), 'kept whole here, not cut');
   finally
      CloseLink(link);
      RestoreSetting(SHARED_EDIT, savedValue, savedStated);
      Settings.Operating.BeepEnable := beep;
   end;
end;

(* ONE POSITION'S SETTINGS ARE NOT SHARED (issue 315). BAND and MODE assign
  this position's ActiveBand and ActiveMode; the five CW values are its
  operator's keying. Each resolves, and Preferences edits each, so a name
  coming back onto the list would move or re-key every other position. *)
procedure TNetClientPacketTests.Test_OnePositionsSettingsAreNotShared;
const
   OWN: array[0..6] of string = ('BAND', 'MODE', 'CODE SPEED', 'CW TONE',
      'WEIGHT', 'FARNSWORTH ENABLE', 'FARNSWORTH SPEED');
var
   i: integer;
begin
   BeginTest('a position''s band, mode and CW keying are not shared with peers');
   for i := Low(OWN) to High(OWN) do
      begin
      CheckTrue(Settings.OwnsCommand(OWN[i]), OWN[i] + ' resolves (the premise)');
      CheckFalse(CommandIsSharedWithPeers(OWN[i]), OWN[i] + ' is not shared');
      end;
end;

(* THE SHARED LIST AFTER NY4I'S RULINGS OF 2026-11-19 (issue 315). Pinned both
  ways: every name on it resolves (a name nothing owns can never be sent), and
  none of the names he took off, or ruled operator-specific, is on it. *)
procedure TNetClientPacketTests.Test_TheSharedListIsTheRuledOne;
const
   ON_THE_LIST: array[0..42] of string = (
      'CATEGORY-ASSISTED', 'CATEGORY-BAND', 'CATEGORY-MODE',
      'CATEGORY-OPERATOR', 'CATEGORY-OVERLAY', 'CATEGORY-POWER',
      'CATEGORY-TRANSMITTER', 'CONTEST NAME', 'CONTEST TITLE',
      'INITIAL EXCHANGE FILENAME', 'MULT REPORT MINIMUM BANDS', 'QSL MODE',
      'SINGLE BAND SCORE',
      'QSO POINTS DOMESTIC CW', 'QSO POINTS DOMESTIC PHONE',
      'QSO POINTS DX CW', 'QSO POINTS DX PHONE', 'MULT BY BAND',
      'MULT BY MODE', 'QSO BY BAND', 'QSO BY MODE', 'QSO NUMBER BY BAND',
      'COUNT DOMESTIC COUNTRIES', 'DOMESTIC FILENAME', 'MULTIPLE BANDS',
      'MULTIPLE MODES', 'HF BAND ENABLE', 'VHF BAND ENABLE',
      'WARC BAND ENABLE', 'SPRINT QSY RULE', 'MINITOUR DURATION',
      'R150S MODE', 'RFOBL MODE', 'LITERAL DOMESTIC QTH',
      'DIGITAL MODE ENABLE', 'QTC ENABLE', 'QTC EXTRA SPACE', 'QTC MINUTES',
      'QTC QRS', 'MULT SHEET AUTO RESET', 'CUSTOM INITIAL EXCHANGE STRING',
      'INITIAL EXCHANGE OVERWRITE', 'TEN MINUTE RULE');
   OFF_THE_LIST: array[0..24] of string = (
      'CONTEST', 'MY CONTINENT', 'INITIAL EXCHANGE CURSOR POS',
      'COPY FILES', 'CQ MENU', 'DISPLAY REFRESH', 'DVK PORT', 'HOUR OFFSET',
      'ICOM COMMAND PAUSE', 'INPUT CONFIG FILE', 'MULTIPLIER ITEM WIDTH',
      'PADDLE PORT', 'TAIL END CW MESSAGE', 'TAIL END KEY',
      'TAIL END MESSAGE', 'TAIL END SSB MESSAGE', 'CONNECTION COMMAND',
      (* the contest's messages and the operator's habits: not shared *)
      'QSL MESSAGE', 'QSO BEFORE MESSAGE', 'CALL OK NOW MESSAGE',
      'QUICK QSL MESSAGE', 'AUTO DUPE ENABLE CQ', 'AUTO DUPE ENABLE S AND P',
      'EXCHANGE MEMORY ENABLE', 'BAND');
var
   i: integer;
begin
   BeginTest('the shared list is the one NY4I ruled');
   for i := Low(ON_THE_LIST) to High(ON_THE_LIST) do
      begin
      CheckTrue(Settings.OwnsCommand(ON_THE_LIST[i]),
                ON_THE_LIST[i] + ' resolves, so it can be sent');
      CheckTrue(CommandIsSharedWithPeers(ON_THE_LIST[i]),
                ON_THE_LIST[i] + ' is shared');
      end;
   for i := Low(OFF_THE_LIST) to High(OFF_THE_LIST) do
      begin
      CheckFalse(CommandIsSharedWithPeers(OFF_THE_LIST[i]),
                 OFF_THE_LIST[i] + ' is not shared');
      end;
end;

(* THE RECEIVING SIDE REFUSES ONE POSITION'S OWN SETTINGS, even from an older
  peer that still sends them (issue 315, NY4I 2026-11-19: "6. Yes"). Driven
  through the real NET_PARAMETER arm: the packet is consumed whole, the stream
  stays on a boundary, and the live value is the one it was. *)
procedure TNetClientPacketTests.Test_APeersOwnPositionSettingsAreRefused;
const
   OWN: array[0..6] of string = ('BAND', 'MODE', 'CODE SPEED', 'CW TONE',
      'WEIGHT', 'FARNSWORTH ENABLE', 'FARNSWORTH SPEED');
var
   link: TCaptureLink;
   i: integer;
   before, sent: string;
   desync: boolean;
   rec: TParameterToNetworkPtr;
begin
   BeginTest('a peer''s band, mode and CW keying are refused on receipt');
   OpenLink(link);
   try
      for i := Low(OWN) to High(OWN) do
         begin
         CheckTrue(CommandIsOnePositionsOwn(OWN[i]), OWN[i] + ' is a position''s own');
         before := LiveValue(OWN[i]);
         sent := 'NOT ' + before;
         if before = 'TRUE' then
            begin
            sent := 'FALSE';
            end
         else if before = 'FALSE' then
            begin
            sent := 'TRUE';
            end;
         rec := TParameterToNetworkPtr(@NetBuffer[1]);
         rec^ := Default(TParameterToNetwork);
         rec^.pnID := NET_PARAMETER_ID;
         rec^.pnCommand := ShortString(AnsiString(OWN[i]));
         rec^.pnValue := ShortString(AnsiString(sent));
         CheckEquals(SizeOf(TParameterToNetwork),
                     ConsumeNetBuffer(SizeOf(TParameterToNetwork), desync),
                     OWN[i] + ': the packet was consumed whole');
         CheckFalse(desync, OWN[i] + ': the stream stayed on a boundary');
         CheckEquals(before, LiveValue(OWN[i]), OWN[i] + ' was not applied');
         end;
      CheckFalse(CommandIsOnePositionsOwn('CONTEST TITLE'),
                 'a shared name is not refused');
      CheckFalse(CommandIsOnePositionsOwn('MY NAME'),
                 'nor is any other name');
   finally
      CloseLink(link);
   end;
end;

procedure TNetClientPacketTests.RunAllTests;
begin
   Test_TheAnnouncedStationCarriesTheTypedCallsign;
   Test_TheConnectThreadDoesNotReadTheEntryField;
   Test_AnId0RecordIsRefusedByTheLeafJudge;
   Test_TheRefusalLatchReportsEachPairOnce;

   Test_ADxSpotLeavesWithItsIdAndItsSize;
   Test_SharingOffPostsNoSpot;
   Test_SharingOffIgnoresSpotsFromTheNetwork;
   Test_AnOlderStationsTimeSyncIsSkippedNotActedOn;
   Test_AnIntercomLineLeavesWithItsIdAndItsSize;
   Test_ASpotViaNetworkLeavesWithItsIdAndItsSize;
   Test_StationStatusAndParameterLeaveWithTheirIds;

   Test_TheGuardRefusesIdZeroAndWrongSizes;
   Test_EveryIdTheTableKnowsPassesAtItsSize;
   Test_TheGuardReportsEachBadPairOncePerLink;

   Test_EverySenderGoesThroughItsHelper;

   Test_ANotedSharedEditIsSentOnceAtTheSave;
   Test_AnUnsharedEditIsNotSent;
   Test_AnEditTypedBackIsNotSent;
   Test_AnOverLongSharedEditIsToldAndNotSent;
   Test_OnePositionsSettingsAreNotShared;
   Test_TheSharedListIsTheRuledOne;
   Test_APeersOwnPositionSettingsAreRefused;
end;

end.

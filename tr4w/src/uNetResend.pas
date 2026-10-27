unit uNetResend;
{$I tr4w.inc}

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

(*
  WHAT THE SERVER HAS, AND WHAT STILL HAS TO BE TOLD TO IT (Phase 1, C5,
  2026-10-27).

  NY4I: a station that reboots or loses the link in the middle of a contest must
  catch up when the link comes back. The QSOs and edits it made meanwhile are
  rows in the SQLite log with sent_to_server = 0 or server_dirty = 1; this unit
  is the part of "send them again" that needs no socket, no store and no widget
  set, so it can be unit tested on its own. (A leaf, like uNetHello: the
  repository answers WHICH rows, uNet posts them, and this decides what each one
  needs and when a flag may change.)

  THREE ANSWERS LIVE HERE.

  1. WHICH PACKETS A ROW STILL OWES (ResendNeedsOf). A row owes a QSO packet
     while sent_to_server is 0 and an edit packet while server_dirty is 1. A row
     with no network identity (both ids 0 -- an imported QSO, which never went
     through the network path) owes nothing: it cannot be told apart from its
     neighbours on the wire, nor marked afterwards by its ids.

  2. WHEN A FLAG MAY CHANGE (TNetDelivery). A QSO counts as SENT when the writer
     thread has handed its bytes to the socket -- not when the packet was posted
     to the send queue (a link that dies with packets still queued would lose
     them and the log would say they were delivered), and not when an
     application-level acknowledgement arrives (the server acknowledges no
     QSO packet; adding one is a protocol change). What is written is NOT proof
     the server read it: a packet in the kernel's send buffer when the cable is
     pulled is still lost. The server and every station ignore a QSO whose
     (ceQSOID1, ceQSOID2) they already hold, so the remedy for that sliver is a
     harmless second send, never a lost QSO.
     An EDIT clears server_dirty only when EVERY edit packet posted for that QSO
     has been written: a second edit posted before the first one's write is
     reported must not have its need cleared by the first, and an edit whose
     write failed keeps the flag for good (the next link-up sends it again).

  3. A QSO ID THAT IS UNIQUE (NextQsoSequence). ceQSOID1 is a tick taken once at
     program start; ceQSOID2 was GetTickCount64 at the moment of the QSO, whose
     resolution on Windows is 10 to 16 ms. Two records created inside one clock
     step -- the QTC loop writes up to ten, and sleeps between them only while
     the link is up -- carried the SAME pair. The servers and the stations now
     ignore a QSO whose pair they hold, so the second would have vanished. This
     makes ceQSOID2 strictly increasing within a run.

  THREADS. Report is called on the WRITER thread; everything else here is the
  MAIN thread's, as is the NextQsoSequence state.
*)

interface

uses
   SysUtils,
   Classes,
   SyncObjs,
   VC;

const
   (* The packet kinds uNet.NetPacketKind names, as the send queue carries them. *)
   NET_KIND_QSOINFO    = 'QSOINFO';
   NET_KIND_EDITEDQSO  = 'EDITEDQSO';
   NET_KIND_OFFLINEQSO = 'OFFLINEQSO';

type
   TNetTags = array of Int64;

(* A QSO'S IDENTITY ON THE WIRE, in one Int64 so the send queue can carry it with
  the packet: ceQSOID1 in the high half, ceQSOID2 in the low. 0 means "no
  identity" (both ids 0), which is also what an untagged packet carries. *)
function NetQsoTag(aId1, aId2: Cardinal): Int64;
procedure NetTagIds(aTag: Int64; out aId1, aId2: Cardinal);

(* Does this QSO have an identity the network can use? *)
function QsoHasNetworkIdentity(const aRec: ContestExchange): boolean;

type
   TResendNeeds = record
      (* The server has never been given this QSO. *)
      NeedsQso: boolean;
      (* The server has an older version of it. *)
      NeedsEdit: boolean;
   end;

function ResendNeedsOf(const aRec: ContestExchange): TResendNeeds;

(* THE NEXT ceQSOID2: aTick (GetTickCount64 truncated to a Cardinal), or one
  more than the previous answer when the clock has not moved on. Wraps with
  the tick. MAIN THREAD. *)
function NextQsoSequence(aTick: Cardinal): Cardinal;

(* Forget the previous answer. For the unit tests. *)
procedure ResetQsoSequence;

type
   TNetWriteOutcome = record
      Kind: string;
      Tag: Int64;
      Written: boolean;
   end;

   TNetWriteOutcomes = array of TNetWriteOutcome;

   (* WHAT BECAME OF THE QSO PACKETS: the writer thread reports, the main thread
     settles. *)
   TNetDelivery = class(TObject)
   private
      FLock: TCriticalSection;
      FOutcomes: TNetWriteOutcomes;
      FCount: integer;
      (* Edit packets posted and not yet settled, by tag. Main thread only. *)
      FEdits: TStringList;
      (* AnsiString, because TStringList's own methods take one: a unicode
        string passed to them is narrowed on every call. *)
      function EditKey(aTag: Int64): AnsiString;
   public
      constructor Create;
      destructor Destroy; override;

      (* MAIN THREAD. An EDITEDQSO packet for aTag was handed to the send
        queue. Call it right after the post succeeds. *)
      procedure EditPosted(aTag: Int64);

      (* ANY THREAD (the writer's). A packet's write finished: aWritten True
        when its bytes went to the socket, False when the write failed. Returns
        True when the caller should arrange for Settle to run -- the outcome
        queue was empty, so no earlier call has already done so. *)
      function Report(const aKind: string; aTag: Int64; aWritten: boolean): boolean;

      (* MAIN THREAD. Takes every reported outcome, in the order they were
        reported, and says what the log should now record:
          aSent         tags of QSOs whose QSOINFO / OFFLINEQSO was written
                        (sent_to_server may become 1);
          aEditsDone    tags whose edits have ALL been written
                        (server_dirty may become 0);
          aLost         how many QSO or edit packets failed to write.
        A packet with no tag (0) cannot be tied to a row; it counts as lost
        when it failed and is otherwise ignored. *)
      procedure Settle(out aSent, aEditsDone: TNetTags; out aLost: integer);

      (* Outcomes reported and not yet settled. *)
      function Unsettled: integer;
      (* Edit packets posted and not yet settled. *)
      function EditsInFlight: integer;
   end;

implementation

type
   (* How many edit packets for one QSO are in flight, and whether any failed. *)
   TEditInFlight = class(TObject)
   public
      Count: integer;
      Failed: boolean;
   end;

var
   GSeqLast: Cardinal = 0;
   GSeqStarted: boolean = False;

function NetQsoTag(aId1, aId2: Cardinal): Int64;
begin
   Result := (Int64(aId1) shl 32) or Int64(aId2);
end;

procedure NetTagIds(aTag: Int64; out aId1, aId2: Cardinal);
begin
   aId1 := Cardinal((aTag shr 32) and $FFFFFFFF);
   aId2 := Cardinal(aTag and $FFFFFFFF);
end;

function QsoHasNetworkIdentity(const aRec: ContestExchange): boolean;
begin
   Result := (aRec.ceQSOID1 <> 0) or (aRec.ceQSOID2 <> 0);
end;

function ResendNeedsOf(const aRec: ContestExchange): TResendNeeds;
begin
   Result.NeedsQso := False;
   Result.NeedsEdit := False;
   if not QsoHasNetworkIdentity(aRec) then
      begin
      Exit;
      end;
   Result.NeedsQso := not aRec.ceSendToServer;
   Result.NeedsEdit := aRec.ceNeedSendToServerAE;
end;

function NextQsoSequence(aTick: Cardinal): Cardinal;
begin
   Result := aTick;
   (* A signed difference, so a tick that has wrapped past the previous answer
     is still "later" and one that is the same or earlier is not. *)
   if GSeqStarted and (Longint(aTick - GSeqLast) <= 0) then
      begin
      Result := GSeqLast + 1;
      end;
   GSeqLast := Result;
   GSeqStarted := True;
end;

procedure ResetQsoSequence;
begin
   GSeqLast := 0;
   GSeqStarted := False;
end;

{ ---------------------------------------------------------------- TNetDelivery -- }

constructor TNetDelivery.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   FEdits := TStringList.Create;
   FEdits.Sorted := True;
   FEdits.Duplicates := dupIgnore;
   FEdits.OwnsObjects := True;
end;

destructor TNetDelivery.Destroy;
begin
   FEdits.Free;
   FLock.Free;
   inherited Destroy;
end;

function TNetDelivery.EditKey(aTag: Int64): AnsiString;
begin
   Result := IntToHex(aTag, 16);
end;

procedure TNetDelivery.EditPosted(aTag: Int64);
var
   at: integer;
   state: TEditInFlight;
begin
   if aTag = 0 then
      begin
      Exit;
      end;

   at := FEdits.IndexOf(EditKey(aTag));
   if at < 0 then
      begin
      state := TEditInFlight.Create;
      FEdits.AddObject(EditKey(aTag), state);
      end
   else
      begin
      state := TEditInFlight(FEdits.Objects[at]);
      end;
   Inc(state.Count);
end;

function TNetDelivery.Report(const aKind: string; aTag: Int64;
                             aWritten: boolean): boolean;
begin
   FLock.Enter;
   try
      Result := FCount = 0;
      if FCount = Length(FOutcomes) then
         begin
         SetLength(FOutcomes, (FCount * 2) + 64);
         end;
      FOutcomes[FCount].Kind := aKind;
      FOutcomes[FCount].Tag := aTag;
      FOutcomes[FCount].Written := aWritten;
      Inc(FCount);
   finally
      FLock.Leave;
   end;
end;

procedure TNetDelivery.Settle(out aSent, aEditsDone: TNetTags; out aLost: integer);
var
   taken: TNetWriteOutcomes;
   i, at, nSent, nEdits: integer;
   state: TEditInFlight;
begin
   SetLength(aSent, 0);
   SetLength(aEditsDone, 0);
   aLost := 0;
   nSent := 0;
   nEdits := 0;

   FLock.Enter;
   try
      taken := Copy(FOutcomes, 0, FCount);
      FCount := 0;
   finally
      FLock.Leave;
   end;

   for i := 0 to High(taken) do
      begin
      if not taken[i].Written then
         begin
         Inc(aLost);
         end;

      if taken[i].Kind = NET_KIND_EDITEDQSO then
         begin
         if taken[i].Tag = 0 then
            begin
            Continue;
            end;
         at := FEdits.IndexOf(EditKey(taken[i].Tag));
         if at < 0 then
            begin
            (* Not tracked -- a packet posted before this ledger existed, or a
              settle that ran twice. A written edit with no other in flight is
              done. *)
            if taken[i].Written then
               begin
               SetLength(aEditsDone, nEdits + 1);
               aEditsDone[nEdits] := taken[i].Tag;
               Inc(nEdits);
               end;
            Continue;
            end;

         state := TEditInFlight(FEdits.Objects[at]);
         Dec(state.Count);
         if not taken[i].Written then
            begin
            state.Failed := True;
            end;
         if state.Count <= 0 then
            begin
            if not state.Failed then
               begin
               SetLength(aEditsDone, nEdits + 1);
               aEditsDone[nEdits] := taken[i].Tag;
               Inc(nEdits);
               end;
            FEdits.Delete(at);
            end;
         end
      else if (taken[i].Kind = NET_KIND_QSOINFO) or
              (taken[i].Kind = NET_KIND_OFFLINEQSO) then
         begin
         if taken[i].Written and (taken[i].Tag <> 0) then
            begin
            SetLength(aSent, nSent + 1);
            aSent[nSent] := taken[i].Tag;
            Inc(nSent);
            end;
         end;
      end;
end;

function TNetDelivery.Unsettled: integer;
begin
   FLock.Enter;
   try
      Result := FCount;
   finally
      FLock.Leave;
   end;
end;

function TNetDelivery.EditsInFlight: integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to FEdits.Count - 1 do
      begin
      Inc(Result, TEditInFlight(FEdits.Objects[i]).Count);
      end;
end;

end.

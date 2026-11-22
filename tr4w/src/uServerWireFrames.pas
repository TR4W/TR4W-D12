unit uServerWireFrames;

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
  WHAT THE SERVER DECIDES ABOUT ONE WIRE QSO MESSAGE -- protocol 5, design
  13.7 (issues 300 and 341). A LEAF: no sockets, no window, no server state, so
  a unit test drives it against a scratch TServerWireStore. tr4wserverUnit
  does the sending (relay, ACK) from the outcome it returns.

  THE RULES (13.7, "Server behaviour"):
   NEW     a bad row (checksum, JSON, number) is refused: logged, not stored,
           not relayed, and the link is NOT dropped. A stored row is relayed; a
           guid the log already holds is neither stored nor relayed. A row the
           disk refused is STILL RELAYED -- the issue-314 ruling (no packet
           acknowledges a QSO, so withholding it would only take it from the
           other stations; the next station to link restocks the server).
   EDIT    last writer wins by guid. Relayed and ACKed, even for a guid the log
           never held (it stores nothing, as before). Not ACKed when the write
           failed.
   OFFLINE stored (inside a held run) and NEVER relayed. The ACK is DEFERRED:
           AckAfterRelease means "send it only after the store's Release
           returned True" (13.6 rule 11). RunFailed means the disk refused a
           row, the whole held run was rolled back, and every ACK pending for
           that run is void.
*)

interface

uses
   SysUtils,
   uWireQso,
   uNetFraming,
   uServerWireStore;

type
   TWireFrameLevel = (wlDebug, wlInfo, wlWarn, wlError);

   TWireFrameOutcome = record
      Take: TWireTake;           (* wtOk, or why the row was refused *)
      Reason: string;
      Call: string;
      Guid: string;
      Stored: TWireInsert;       (* NEW and OFFLINE: what the store did *)
      Relay: boolean;
      AckNow: boolean;
      AckAfterRelease: boolean;
      RunFailed: boolean;
      Level: TWireFrameLevel;
      Detail: string;            (* the line for the server's log *)
   end;

   (* One frame of the sync stream, ready to write. *)
   TSyncFrameWriter = procedure(const aFrame: TBytes) of object;

(* aKindId: NET_WIRE_QSO_ID, NET_WIRE_EDIT_ID or NET_WIRE_OFFLINE_ID. aPayload:
  the bytes after the six header bytes (sender byte, then the JSON). *)
function ProcessWireFrame(aStore: TServerWireStore; aColumns: TWireColumns;
                          const aKindId: word; const aPayload: TBytes): TWireFrameOutcome;

(* THE SYNC STREAM (13.7): ONE ReadAll snapshot, then the header frame
  {"contest","rows","schema"} and one frame per row, in arrival order, each
  handed to aWriter. aRows is the row count of the header. False when the log
  could not be read (nothing written). *)
function SendSyncStream(aStore: TServerWireStore; aColumns: TWireColumns;
                        aWriter: TSyncFrameWriter; out aRows: integer): boolean;

implementation

uses
   VC;

function KindName(const aKindId: word): string;
begin
   case aKindId of
      NET_WIRE_QSO_ID: Result := 'NEW';
      NET_WIRE_EDIT_ID: Result := 'EDIT';
      NET_WIRE_OFFLINE_ID: Result := 'OFFLINE';
   else
      Result := 'id ' + IntToStr(aKindId);
   end;
end;

function ValueOf(aColumns: TWireColumns; const aValues: TWireValues;
                 const aName: string): string;
var
   i: integer;
begin
   Result := '';
   i := aColumns.IndexOfName(aName);
   if (i >= 0) and (i < Length(aValues)) then
      begin
      Result := aValues[i];
      end;
end;

function ProcessWireFrame(aStore: TServerWireStore; aColumns: TWireColumns;
                          const aKindId: word; const aPayload: TBytes): TWireFrameOutcome;
var
   sender: Byte;
   values: TWireValues;
   who: string;
begin
   Result := Default(TWireFrameOutcome);
   Result.Level := wlDebug;
   Result.Take := TakeWireMessage(aColumns, aPayload, sender, values, Result.Reason);
   if Result.Take <> wtOk then
      begin
      Result.Level := wlWarn;
      Result.Detail := Format('[Net] a %s row was refused (%s): not stored, not relayed',
                              [KindName(aKindId), Result.Reason]);
      Exit;
      end;

   Result.Call := ValueOf(aColumns, values, 'callsign');
   Result.Guid := ValueOf(aColumns, values, 'guid');
   who := Format('%s: call=%s band=%s mode=%s guid=%s',
                 [KindName(aKindId), Result.Call, ValueOf(aColumns, values, 'band'),
                  ValueOf(aColumns, values, 'mode'), Result.Guid]);

   case aKindId of
      NET_WIRE_QSO_ID:
         begin
         Result.Stored := aStore.Insert(values);
         case Result.Stored of
            wiStored:
               begin
               Result.Relay := True;
               Result.Detail := who;
               end;
            wiDuplicate:
               begin
               Result.Level := wlInfo;
               Result.Detail := '[Net] ' + who + ' is already in the server log: not stored, not relayed';
               end;
            wiRejected:
               begin
               Result.Level := wlWarn;
               Result.Detail := '[Net] ' + who + ' is not a row of the server log''s schema: refused';
               end;
         else
            begin
            (* The disk refused it. STILL RELAYED (issue 314). *)
            Result.Relay := True;
            Result.Level := wlError;
            Result.Detail := '[Net] ' + who + ' could not be stored; relayed anyway';
            end;
         end;
         end;

      NET_WIRE_EDIT_ID:
         begin
         Result.Relay := True;
         if aStore.UpdateNewest(values) then
            begin
            Result.AckNow := True;
            Result.Detail := who;
            end
         else
            begin
            Result.Level := wlError;
            Result.Detail := '[Net] ' + who + ' could not be stored; relayed anyway';
            end;
         end;

      NET_WIRE_OFFLINE_ID:
         begin
         aStore.Hold;
         Result.Stored := aStore.Insert(values);
         case Result.Stored of
            wiStored:
               begin
               Result.AckAfterRelease := True;
               Result.Detail := who;
               end;
            wiDuplicate:
               begin
               (* Already held: acknowledged, as before. *)
               Result.AckAfterRelease := True;
               Result.Level := wlInfo;
               Result.Detail := '[Net] ' + who + ' is already in the server log: not stored again';
               end;
            wiRejected:
               begin
               Result.Level := wlWarn;
               Result.Detail := '[Net] ' + who + ' is not a row of the server log''s schema: refused';
               end;
         else
            begin
            Result.RunFailed := True;
            Result.Level := wlError;
            Result.Detail := '[Net] ' + who + ' could not be stored: the whole run is rolled back, ' +
                             'nothing in it is acknowledged';
            end;
         end;
         end;
   end;
end;

function SendSyncStream(aStore: TServerWireStore; aColumns: TWireColumns;
                        aWriter: TSyncFrameWriter; out aRows: integer): boolean;
var
   rows: TWireRows;
   contest: string;
   i: integer;
begin
   aRows := 0;
   Result := aStore.ReadAll(rows, contest);
   if not Result then
      begin
      Exit;
      end;
   aRows := Length(rows);
   aWriter(BuildSyncHeaderFrame(contest, aRows));
   for i := 0 to High(rows) do
      begin
      aWriter(BuildSyncRowFrame(aColumns, rows[i]));
      end;
end;

end.

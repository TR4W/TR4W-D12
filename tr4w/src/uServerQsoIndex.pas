unit uServerQsoIndex;
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
  WHICH QSOs THE SERVER'S LOG ALREADY HOLDS (Phase 1, C5, 2026-10-27).

  A station that was disconnected sends again what it logged meanwhile, and one
  that crashed before it could note what it had sent sends some of it twice. The
  server must store and relay a QSO once. A QSO is told from another by the pair
  (ceQSOID1, ceQSOID2) -- the same key the server already finds an edit's record
  by -- so this is a set of those pairs, built from the log file the first time
  it is asked and kept in step as the server appends.

  A LEAF, like uNetHello: it knows the record (VC.ContestExchange) and a stream,
  not the server, so the logic is unit tested without Indy.

  THE LOG FILE IS THE AUTHORITY, not this set. Someone can delete SERVERLOG.TRW
  between runs, clear it from the menu or replace it, so the set remembers the
  SIZE of the file it was built from and says it is stale (ReflectsLog) when the
  file is a different size; the server then rebuilds it from the file instead of
  trusting it. An append the server makes itself is noted with the new size.

  THE PAIR (0, 0) IS NEVER IN IT. It is what a QSO that did not go through the
  network path carries, so it identifies nothing; a record with it is stored
  every time, as it always was.

  A PAIR IS ONLY AS UNIQUE AS THE STATIONS MAKE IT. Two QSOs with one pair would
  be taken for the same QSO and the second dropped. uNetResend.NextQsoSequence
  makes the second half unique within a run of a station; the first half is the
  station's start tick, so two stations would have to have started in the same
  millisecond and logged in the same one. The server says so in its log when it
  turns a QSO away, with the call, so a collision would be found.
*)

interface

uses
   SysUtils,
   Classes,
   VC;

type
   TServerQsoIndex = class(TObject)
   private
      FKeys: TStringList;
      FLogSize: Int64;
      (* AnsiString, because TStringList's own methods take one. *)
      function KeyOf(aId1, aId2: Cardinal): AnsiString;
   public
      constructor Create;
      destructor Destroy; override;

      (* Forget everything, including the size: the next question rebuilds. *)
      procedure Clear;

      (* How many pairs it holds. *)
      function Count: integer;

      (* Is this pair in the log? False for (0, 0). *)
      function Contains(aId1, aId2: Cardinal): boolean;

      (* The server has appended a QSO with this pair. Ignored for (0, 0) and for
        a pair already held. *)
      procedure Add(aId1, aId2: Cardinal);

      (* Is the set built from a log of exactly this size? *)
      function ReflectsLog(aLogSize: Int64): boolean;

      (* The log is now this size and the set agrees with it -- call it after an
        append the server made and Added. *)
      procedure NoteLogSize(aLogSize: Int64);

      (* Rebuild from the log file's stream: skip aHeaderBytes, then read
        SizeOf(ContestExchange) at a time to the end; a short tail is ignored.
        Leaves the set reflecting the stream's size. *)
      procedure LoadFromLog(aLog: TStream; aHeaderBytes: integer);
   end;

implementation

constructor TServerQsoIndex.Create;
begin
   inherited Create;
   FKeys := TStringList.Create;
   FKeys.Sorted := True;
   FKeys.Duplicates := dupIgnore;
   FLogSize := -1;
end;

destructor TServerQsoIndex.Destroy;
begin
   FKeys.Free;
   inherited Destroy;
end;

function TServerQsoIndex.KeyOf(aId1, aId2: Cardinal): AnsiString;
begin
   Result := IntToHex(aId1, 8) + IntToHex(aId2, 8);
end;

procedure TServerQsoIndex.Clear;
begin
   FKeys.Clear;
   FLogSize := -1;
end;

function TServerQsoIndex.Count: integer;
begin
   Result := FKeys.Count;
end;

function TServerQsoIndex.Contains(aId1, aId2: Cardinal): boolean;
var
   at: integer;
begin
   Result := False;
   if (aId1 = 0) and (aId2 = 0) then
      begin
      Exit;
      end;
   Result := FKeys.Find(KeyOf(aId1, aId2), at);
end;

procedure TServerQsoIndex.Add(aId1, aId2: Cardinal);
begin
   if (aId1 = 0) and (aId2 = 0) then
      begin
      Exit;
      end;
   FKeys.Add(KeyOf(aId1, aId2));
end;

function TServerQsoIndex.ReflectsLog(aLogSize: Int64): boolean;
begin
   Result := (FLogSize >= 0) and (FLogSize = aLogSize);
end;

procedure TServerQsoIndex.NoteLogSize(aLogSize: Int64);
begin
   FLogSize := aLogSize;
end;

procedure TServerQsoIndex.LoadFromLog(aLog: TStream; aHeaderBytes: integer);
var
   rec: ContestExchange;
begin
   Clear;
   aLog.Position := aHeaderBytes;
   while aLog.Position + SizeOf(ContestExchange) <= aLog.Size do
      begin
      aLog.ReadBuffer(rec, SizeOf(ContestExchange));
      Add(rec.ceQSOID1, rec.ceQSOID2);
      end;
   FLogSize := aLog.Size;
end;

end.

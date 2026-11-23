unit uNetCatchUp;
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
  A STATION THAT COMES UP IN THE MIDDLE OF A CONTEST CATCHES UP FROM THE SERVER
  (Phase 1, C6, 2026-10-27; REBUILT FOR PROTOCOL 5, W3+W5, 2026-11-22).

  NY4I: "Late catch-up has to be supported as it was ... to handle a station that
  comes up (reboots) in the middle of the contest."

  WHAT THE SERVER SENDS (docs/TR4WSERVER_SQLITE_DESIGN.md 13.7). On its second
  port, after the password: a header frame {"contest":"<id>","rows":N,
  "schema":5}, then N row frames, each a 4-byte LE length and the UTF-8 JSON row
  (the same row as a live QSO message, no sender byte), in arrival order, from ONE
  read of the server's database. There is no byte image of a file and no CRC: a
  row is its on-wire columns, and its identity is its GUID (the old pair
  (ceQSOID1, ceQSOID2) is a station's local session id and no longer travels).

  WHAT THE STATION DOES, INSERT ONLY:

    - THE CONTEST IS COMPARED ONCE, from the header (JudgeSyncContest): the
      server holds ONE contest (the first station's HELLO named it). A different
      one is refused whole with the existing contest-mismatch notice; there is no
      per-row judge. A server that holds none yet has no rows to give.
    - DOWNLOAD: every row the server holds whose guid this log lacks is added
      (BuildCatchUpPlan), after a backup, in one transaction, stored VERBATIM
      under the sender's guid -- a station that was offline receives everything
      it missed (NY4I ruling 3). A row with no guid names nothing and is skipped;
      a guid twice in the server's rows is added once. Nothing already in this log
      is changed or removed.
    - PUSH (TPushPlan): rows LOGGED HERE (the wire computer_id is this station's)
      whose guid the server lacks go to it as OFFLINE rows. A row copied from a
      peer by an older build carries a local guid unlike the original, so pushing
      it would DUPLICATE it on the server: only rows logged here are pushed. A
      row still owed (the resend sends it as a new QSO) and a row with no guid
      are left out and counted.

  There is no "is this station behind" test to get wrong: the fetch IS the
  comparison, and the answer is the number of server rows this log lacks.

  WHAT IT DOES NOT DO: pick up an EDIT another station made to a QSO this one
  holds while this one was away. Insert-only cannot tell which copy is newer (a
  row has no edit counter and this station's own edit may still be on its way).
  An edit made while this station is UP arrives live.

  A LEAF, like uNetHello and uNetResend: no sockets, no store, no widget set, so
  all of it is reachable from a unit test. The fetch is uGetServerLog's, the
  write is uLogStore's.
*)

interface

uses
   SysUtils,
   Classes,
   uGuidSet,
   uWireQso;

const
   (* A server that declares more rows than this is refused before any is read: a
     number a damaged header cannot reach by accident. *)
   SERVER_LOG_MAX_ROWS = 2000000;

type
   (* THE SERVER'S LOG AS THE SYNC PORT SENT IT: the contest its header named and
     its rows, as wire values in QsoWireColumns' order. Filled by the download
     (one thread), then read on the MAIN thread only. *)
   TServerLogImage = class(TObject)
   private
      FContest: string;
      FDeclared: integer;
      FRows: array of TWireValues;
      FCount: integer;
      FQsoCount: integer;
      FGuids: TGuidSet;
      FGuidTag, FKindTag, FDeletedTag: integer;
   public
      constructor Create;
      destructor Destroy; override;

      (* The header frame was read: the contest the server holds and how many
        rows follow. *)
      procedure StartImage(const aContest: string; aDeclaredRows: integer);
      (* One row frame, taken apart and checked. *)
      procedure AddRow(const aValues: TWireValues);

      property Contest: string read FContest;
      property DeclaredRows: integer read FDeclared;
      (* Rows held; equal to DeclaredRows when the download is whole. *)
      function Count: integer;
      (* How many of them are QSOs that count: record_kind QSO and not deleted --
        what the sync window has always shown as "QSOs". *)
      function QsoCount: integer;
      (* Row aIndex (0-based); no values outside 0..Count-1. *)
      function Row(aIndex: integer): TWireValues;
      (* Does the server hold this guid? *)
      function HoldsGuid(const aGuid: string): boolean;
   end;

   TSyncContestVerdict = (
      scSame,       // the server holds this station's contest
      scServerNone, // the server names none (it holds nothing yet)
      scOther       // another contest: refuse the download
   );

(* THE ONE COMPARISON of the sync header's contest with this station's, by id
  string, case-insensitive. *)
function JudgeSyncContest(const aServerContest, aOurContestId: string): TSyncContestVerdict;

type
   (* WHY A SERVER ROW IS NOT ADDED. *)
   TCatchUpSkip = (
      cusNoIdentity,      // no guid: it names no QSO
      cusAlreadyHeld,     // this log has it
      cusRepeated         // the server's rows hold the same guid twice
   );

   (* WHAT A CATCH-UP WOULD DO, computed and not yet done: the rows to add (by
     position in the image) and how many were skipped, and why. *)
   TCatchUpPlan = class(TObject)
   private
      FRows: array of integer;
      FCount: integer;
      FSkipped: array[TCatchUpSkip] of integer;
      FFirstCall: array[TCatchUpSkip] of string;
   public
      procedure AddRow(aIndex: integer);
      procedure Skip(aWhy: TCatchUpSkip; const aCall: string);

      (* Rows to add. *)
      function Count: integer;
      (* The image position of row aN of those to add. *)
      function RowIndex(aN: integer): integer;
      function Skipped(aWhy: TCatchUpSkip): integer;
      function SkippedTotal: integer;
      (* The callsign of the first row skipped for that reason, or ''. *)
      function FirstCallSkipped(aWhy: TCatchUpSkip): string;
   end;

(* The reason as words, for the log. *)
function CatchUpSkipText(aWhy: TCatchUpSkip): string;

(* THE PLAN: every row of aImage whose guid aHeld does not hold, once each.
  aHeld is the set of guids this log holds; it is read, not changed. *)
function BuildCatchUpPlan(aImage: TServerLogImage; aHeld: TGuidSet): TCatchUpPlan;

(* A one-line account of a plan for the log. *)
function CatchUpSummary(aPlan: TCatchUpPlan): string;

type
   (* WHAT BECOMES OF ONE ROW OF THIS LOG when the server is restocked. *)
   TPushVerdict = (
      pvSend,          // logged here and the server lacks it: push it
      pvNoIdentity,    // no guid: it names nothing on the wire
      pvNotLoggedHere, // another station's row: that station pushes it
      pvOwed,          // the resend sends it (sent_to_server = 0 or server_dirty = 1)
      pvServerHas,     // the server's rows hold the guid
      pvRepeated       // this log holds the guid twice; pushed once
   );

   (* THE ROWS OF THIS LOG THE SERVER LACKS, computed and not yet sent. Built from
     the server image; fed this log's rows one at a time (Consider). Owns copies
     of the rows it will send, with their row ids. *)
   TPushPlan = class(TObject)
   private
      FServer: TGuidSet;
      FTaken: TGuidSet;
      (* Not owned. See Create. *)
      FResentThisLink: TGuidSet;
      FComputerId: string;
      FRowIds: array of Int64;
      FRows: array of TWireValues;
      FCount: integer;
      FVerdicts: array[TPushVerdict] of integer;
      FGuidTag, FComputerTag: integer;
   public
      (* aImage is the server's log; its guids are read now and the image is not
        kept (it may be nil). aComputerId is THIS station's computer id letter:
        only rows logged here are pushed. aResentThisLink (not owned, may be nil)
        is the set of guids the resend posted on THIS link: the fetch runs on its
        own connection and may have been served before the server read them, and
        the writer may already have marked them sent, so they would otherwise
        look like rows the server lacks. They count as owed. *)
      constructor Create(aImage: TServerLogImage; const aComputerId: string;
                         aResentThisLink: TGuidSet = nil);
      destructor Destroy; override;

      (* Does the server's log hold this guid? The repository asks it before it
        reads a row's other columns. *)
      function ServerHolds(const aGuid: string): boolean;

      (* Judge one row of this log, and keep it when the server lacks it. aOwed is
        True for a row whose flags say the resend still owes it. *)
      function Consider(aRowId: Int64; const aValues: TWireValues;
                        aOwed: boolean = False): TPushVerdict;

      (* Rows to send, and row aN of them (0-based). *)
      function Count: integer;
      function RowId(aN: integer): Int64;
      function Row(aN: integer): TWireValues;

      (* How many rows got each verdict. *)
      function Verdicts(aVerdict: TPushVerdict): integer;
   end;

(* A one-line account for the log: how many to send, how many skipped and why. *)
function PushSummary(aPlan: TPushPlan): string;

type
   (* WHAT THE STATION DOES ON CONNECT once it knows how many QSOs the server holds
     that this log lacks (aPull) and how many of this log's the server lacks
     (aPush). ONE decision for both directions, so the operator is asked once. *)
   TSyncOnConnect = (
      socNothing,    // both sides complete: say nothing
      socDoNow,      // SERVER AUTO SYNCHRONIZE LOG ON CONNECT is on: just do it
      socAskPull,    // ask: only the server has something to give
      socAskPush,    // ask: only this log has something to give
      socAskBoth     // ask once, covering both
   );

function SyncOnConnect(aPull, aPush: integer; aAutoSynchronize: boolean): TSyncOnConnect;

implementation

uses
   uQsoColumns;

(* ---------------------------------------------------------- TServerLogImage *)

constructor TServerLogImage.Create;
begin
   inherited Create;
   FGuids := TGuidSet.Create;
   FGuidTag := QsoWireColumns.IndexOfName('guid');
   FKindTag := QsoWireColumns.IndexOfName('record_kind');
   FDeletedTag := QsoWireColumns.IndexOfName('deleted');
end;

destructor TServerLogImage.Destroy;
begin
   FGuids.Free;
   inherited Destroy;
end;

procedure TServerLogImage.StartImage(const aContest: string; aDeclaredRows: integer);
begin
   FContest := aContest;
   FDeclared := aDeclaredRows;
   FRows := nil;
   FCount := 0;
   FQsoCount := 0;
   FGuids.Clear;
end;

procedure TServerLogImage.AddRow(const aValues: TWireValues);
begin
   if Length(aValues) <> QsoWireColumns.Count then
      begin
      Exit;
      end;
   if FCount = Length(FRows) then
      begin
      SetLength(FRows, (FCount * 2) + 256);
      end;
   FRows[FCount] := aValues;
   Inc(FCount);
   FGuids.Add(aValues[FGuidTag]);
   if (aValues[FKindTag] = 'QSO') and (aValues[FDeletedTag] <> '1') then
      begin
      Inc(FQsoCount);
      end;
end;

function TServerLogImage.Count: integer;
begin
   Result := FCount;
end;

function TServerLogImage.QsoCount: integer;
begin
   Result := FQsoCount;
end;

function TServerLogImage.Row(aIndex: integer): TWireValues;
begin
   if (aIndex < 0) or (aIndex >= FCount) then
      begin
      Result := nil;
      Exit;
      end;
   Result := FRows[aIndex];
end;

function TServerLogImage.HoldsGuid(const aGuid: string): boolean;
begin
   Result := FGuids.Contains(aGuid);
end;

function JudgeSyncContest(const aServerContest, aOurContestId: string): TSyncContestVerdict;
begin
   if aServerContest = '' then
      begin
      Result := scServerNone;
      end
   else if LowerCase(aServerContest) = LowerCase(aOurContestId) then
      begin
      Result := scSame;
      end
   else
      begin
      Result := scOther;
      end;
end;

(* ------------------------------------------------------------ TCatchUpPlan *)

procedure TCatchUpPlan.AddRow(aIndex: integer);
begin
   if FCount = Length(FRows) then
      begin
      SetLength(FRows, (FCount * 2) + 64);
      end;
   FRows[FCount] := aIndex;
   Inc(FCount);
end;

procedure TCatchUpPlan.Skip(aWhy: TCatchUpSkip; const aCall: string);
begin
   if FSkipped[aWhy] = 0 then
      begin
      FFirstCall[aWhy] := aCall;
      end;
   Inc(FSkipped[aWhy]);
end;

function TCatchUpPlan.Count: integer;
begin
   Result := FCount;
end;

function TCatchUpPlan.RowIndex(aN: integer): integer;
begin
   if (aN < 0) or (aN >= FCount) then
      begin
      Result := -1;
      Exit;
      end;
   Result := FRows[aN];
end;

function TCatchUpPlan.Skipped(aWhy: TCatchUpSkip): integer;
begin
   Result := FSkipped[aWhy];
end;

function TCatchUpPlan.SkippedTotal: integer;
var
   why: TCatchUpSkip;
begin
   Result := 0;
   for why := Low(TCatchUpSkip) to High(TCatchUpSkip) do
      begin
      Inc(Result, FSkipped[why]);
      end;
end;

function TCatchUpPlan.FirstCallSkipped(aWhy: TCatchUpSkip): string;
begin
   Result := FFirstCall[aWhy];
end;

function CatchUpSkipText(aWhy: TCatchUpSkip): string;
begin
   case aWhy of
      cusNoIdentity:     Result := 'no guid';
      cusAlreadyHeld:    Result := 'already in this log';
      cusRepeated:       Result := 'repeated in the server log';
   else
      begin
      Result := '';
      end;
   end;
end;

function BuildCatchUpPlan(aImage: TServerLogImage; aHeld: TGuidSet): TCatchUpPlan;
var
   i, guidTag, callTag: integer;
   row: TWireValues;
   taken: TGuidSet;
begin
   Result := TCatchUpPlan.Create;
   guidTag := QsoWireColumns.IndexOfName('guid');
   callTag := QsoWireColumns.IndexOfName('callsign');
   taken := TGuidSet.Create;
   try
      for i := 0 to aImage.Count - 1 do
         begin
         row := aImage.Row(i);

         if row[guidTag] = '' then
            begin
            Result.Skip(cusNoIdentity, row[callTag]);
            Continue;
            end;

         if aHeld.Contains(row[guidTag]) then
            begin
            Result.Skip(cusAlreadyHeld, row[callTag]);
            Continue;
            end;

         if taken.Contains(row[guidTag]) then
            begin
            Result.Skip(cusRepeated, row[callTag]);
            Continue;
            end;

         taken.Add(row[guidTag]);
         Result.AddRow(i);
         end;
   finally
      taken.Free;
   end;
end;

function CatchUpSummary(aPlan: TCatchUpPlan): string;
var
   why: TCatchUpSkip;
begin
   Result := IntToStr(aPlan.Count) + ' to add';
   for why := Low(TCatchUpSkip) to High(TCatchUpSkip) do
      begin
      if aPlan.Skipped(why) > 0 then
         begin
         Result := Result + '; ' + IntToStr(aPlan.Skipped(why)) + ' ' +
                   CatchUpSkipText(why);
         if aPlan.FirstCallSkipped(why) <> '' then
            begin
            Result := Result + ' (first: ' + aPlan.FirstCallSkipped(why) + ')';
            end;
         end;
      end;
end;

(* ------------------------------------------------------------ the push plan *)

constructor TPushPlan.Create(aImage: TServerLogImage; const aComputerId: string;
                             aResentThisLink: TGuidSet);
var
   i: integer;
begin
   inherited Create;
   FResentThisLink := aResentThisLink;
   FComputerId := aComputerId;
   FServer := TGuidSet.Create;
   FTaken := TGuidSet.Create;
   FGuidTag := QsoWireColumns.IndexOfName('guid');
   FComputerTag := QsoWireColumns.IndexOfName('computer_id');
   if aImage <> nil then
      begin
      for i := 0 to aImage.Count - 1 do
         begin
         FServer.Add(aImage.Row(i)[FGuidTag]);
         end;
      end;
end;

destructor TPushPlan.Destroy;
begin
   FTaken.Free;
   FServer.Free;
   inherited Destroy;
end;

function TPushPlan.ServerHolds(const aGuid: string): boolean;
begin
   Result := FServer.Contains(aGuid);
end;

function TPushPlan.Consider(aRowId: Int64; const aValues: TWireValues;
                            aOwed: boolean): TPushVerdict;
var
   guid: string;
begin
   guid := aValues[FGuidTag];

   if guid = '' then
      begin
      Result := pvNoIdentity;
      end
   else if aValues[FComputerTag] <> FComputerId then
      begin
      Result := pvNotLoggedHere;
      end
   else if aOwed then
      begin
      Result := pvOwed;
      end
   else if (FResentThisLink <> nil) and FResentThisLink.Contains(guid) then
      begin
      Result := pvOwed;
      end
   else if FServer.Contains(guid) then
      begin
      Result := pvServerHas;
      end
   else if FTaken.Contains(guid) then
      begin
      Result := pvRepeated;
      end
   else
      begin
      Result := pvSend;
      FTaken.Add(guid);
      if FCount = Length(FRows) then
         begin
         SetLength(FRows, (FCount * 2) + 64);
         SetLength(FRowIds, Length(FRows));
         end;
      FRows[FCount] := aValues;
      FRowIds[FCount] := aRowId;
      Inc(FCount);
      end;

   Inc(FVerdicts[Result]);
end;

function TPushPlan.Count: integer;
begin
   Result := FCount;
end;

function TPushPlan.RowId(aN: integer): Int64;
begin
   Result := 0;
   if (aN >= 0) and (aN < FCount) then
      begin
      Result := FRowIds[aN];
      end;
end;

function TPushPlan.Row(aN: integer): TWireValues;
begin
   Result := nil;
   if (aN >= 0) and (aN < FCount) then
      begin
      Result := FRows[aN];
      end;
end;

function TPushPlan.Verdicts(aVerdict: TPushVerdict): integer;
begin
   Result := FVerdicts[aVerdict];
end;

function PushSummary(aPlan: TPushPlan): string;
begin
   Result := IntToStr(aPlan.Count) + ' to send; ' +
             IntToStr(aPlan.Verdicts(pvNoIdentity)) + ' with no guid skipped; ' +
             IntToStr(aPlan.Verdicts(pvNotLoggedHere)) + ' logged at another station skipped; ' +
             IntToStr(aPlan.Verdicts(pvOwed)) + ' still owed (the resend sends them) skipped';
   if aPlan.Verdicts(pvRepeated) > 0 then
      begin
      Result := Result + '; ' + IntToStr(aPlan.Verdicts(pvRepeated)) +
                ' repeated in this log';
      end;
end;

function SyncOnConnect(aPull, aPush: integer; aAutoSynchronize: boolean): TSyncOnConnect;
begin
   if (aPull <= 0) and (aPush <= 0) then
      begin
      Result := socNothing;
      end
   else if aAutoSynchronize then
      begin
      Result := socDoNow;
      end
   else if (aPull > 0) and (aPush > 0) then
      begin
      Result := socAskBoth;
      end
   else if aPull > 0 then
      begin
      Result := socAskPull;
      end
   else
      begin
      Result := socAskPush;
      end;
end;

end.

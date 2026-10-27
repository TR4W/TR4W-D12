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
  (Phase 1, C6, 2026-10-27).

  NY4I: "Late catch-up has to be supported as it was ... to handle a station that
  comes up (reboots) in the middle of the contest."

  HOW IT WAS (D7, uNet.ProcessServerLogInfo and uGetServerLog): on connect the
  server sent a packet holding a CRC32 of SERVERLOG.TRW; the station CRC32'd its
  own .TRW and, when they differed, either replaced its log with the server's
  file (SERVER AUTO SYNCHRONIZE LOG ON CONNECT) or asked. This station keeps no
  .TRW, so the comparison means nothing and the REPLACE would destroy every QSO
  that only this station holds. Both go.

  WHAT IT IS NOW. The log is fetched from the server's second port whenever a
  station catches up, and MERGED, INSERT ONLY:

    - a server record whose (ceQSOID1, ceQSOID2) this log already holds is left
      alone, and so is the row it matches -- nothing here deletes or rewrites a
      row this station has;
    - a record whose pair is (0, 0) names nothing and is skipped;
    - a record that is not for THIS contest is skipped and counted, never
      imported (below);
    - every record that is added is stamped with this station's own contest
      handle and marked sent and clean, so the resend (uNetResend) never sends
      it back.

  There is no "is this station behind" test to get wrong: the fetch IS the
  comparison, and the answer is the number of server records this log lacks. The
  server log is 376 bytes a QSO, so 10,000 QSOs is 3.76 MB.

  WHAT IT DOES NOT DO: pick up an EDIT another station made to a QSO this one
  holds, while this one was away. The server's copy of an edited QSO is the
  edited record in place; D7 got it by replacing the whole file. Here nothing
  says which copy is newer (a record has no edit counter, and this station's own
  edit may still be on its way to the server), so overwriting could turn a newer
  local edit back into an older one. Insert-only is the safe half, and the other
  half belongs to the row-level protocol. An edit made while this station is UP
  still arrives live (uNet, NET_EDITEDQSO).

  WHICH CONTEST A SERVER RECORD BELONGS TO is the delicate question, because the
  server is contest-agnostic and its log may not have been cleared between
  contests, and because the one byte on the record (ceContest) is only
  comparable for a legacy contest -- a contest registered by id has a handle
  assigned when the registry seals, different between builds. The rule
  (JudgeServerRecord):

    this station's contest is a LEGACY one: the byte is definitive. A record
      whose byte is not ours is another contest, whatever its author says.
    the record's author (ceComputerID) is a station that has announced a
      contest in its HELLO on this link: if that contest is ours the record is
      accepted, if not it is skipped.
    the author has announced nothing (it has left, or it is this very station
      after its log was lost): the byte decides -- equal to our handle is
      accepted, different is skipped. For a contest registered by id this is
      right for stations on the same build and cannot be better; the skipped
      count says how many were not judged, and the log names the first.

  A LEAF, like uNetHello and uNetResend: no sockets, no store, no widget set, so
  all of it is reachable from a unit test. The fetch is uGetServerLog's, the
  write is uLogStore's.
*)

interface

uses
   SysUtils,
   Classes,
   VC,
   uComputerID,
   uNetHello,
   uServerQsoIndex;

const
   (* A server log larger than this is refused before it is read into memory:
     about 700,000 QSOs, far past any contest, and a number a damaged size field
     cannot reach by accident. *)
   SERVER_LOG_MAX_BYTES = 256 * 1024 * 1024;

type
   (* THE SERVER'S LOG FILE, AS BYTES. The first SizeOfTLogHeader bytes are a
     header (the server's own, no QSO); every SizeOf(ContestExchange) after that
     is one record. It is kept as bytes and read a record at a time, so a large
     log is held once and not twice. MAIN THREAD once it has been handed over:
     Row moves the stream's position. *)
   TServerLogImage = class(TObject)
   private
      FData: TMemoryStream;
      FCount: integer;
      FQsoCount: integer;
   public
      constructor Create;
      destructor Destroy; override;

      (* Where the download is written. *)
      property Data: TMemoryStream read FData;

      (* The download is complete: aDeclaredSize is the size the server stated
        before the bytes. True when what arrived is exactly that and is a whole
        number of records after the header (an empty log, no bytes or a header
        only, is whole). False says why, in aWhy, and the image holds no
        records. *)
      function Accept(aDeclaredSize: Int64; out aWhy: string): boolean;

      (* Records after the header. *)
      function Count: integer;

      (* How many of them are QSOs that count: a band and a mode and not deleted
        -- what the sync window has always shown as "QSOs". *)
      function QsoCount: integer;

      (* Record aIndex (0-based). False, with a zeroed record, outside 0..Count-1. *)
      function Row(aIndex: integer; out aRec: ContestExchange): boolean;
   end;

   (* WHAT THE JUDGE NEEDS TO KNOW ABOUT THIS STATION AND THE LINK. *)
   TCatchUpContext = record
      (* What every station announced on this link. *)
      Peers: TNetPeers;
      (* This station's contest, by id and by handle. *)
      OurContestId: string;
      OurHandle: TContestHandle;
      (* True when it is a legacy contest, whose handle is its frozen number and
        therefore means the same thing on every build. *)
      OurIsLegacy: boolean;
   end;

   TCatchUpVerdict = (
      cvAccept,           // for this contest
      cvOtherContest,     // for another contest: its author said so, or its byte does
      cvUnknownContest    // its author is not here to ask and its byte cannot say
   );

(* IS THIS SERVER RECORD FOR THE CONTEST THIS STATION IS RUNNING? The rule is in
  the unit header. *)
function JudgeServerRecord(const aRec: ContestExchange;
                           const aCtx: TCatchUpContext): TCatchUpVerdict;

type
   (* WHY A SERVER RECORD IS NOT ADDED. *)
   TCatchUpSkip = (
      cusNoIdentity,      // (0, 0): it names no QSO
      cusAlreadyHeld,     // this log has it
      cusRepeated,        // the server's file holds the same pair twice
      cusOtherContest,
      cusUnknownContest
   );

   (* WHAT A CATCH-UP WOULD DO, computed and not yet done: the records to add (by
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

      (* Records to add. *)
      function Count: integer;
      (* The image position of record aN of those to add. *)
      function RowIndex(aN: integer): integer;
      function Skipped(aWhy: TCatchUpSkip): integer;
      function SkippedTotal: integer;
      (* The callsign of the first record skipped for that reason, or ''. *)
      function FirstCallSkipped(aWhy: TCatchUpSkip): string;
   end;

(* The reason as words, for the log. *)
function CatchUpSkipText(aWhy: TCatchUpSkip): string;

(* THE PLAN: every record of aImage that aHeld does not hold and the judge
  accepts, once each. aHeld is the set of network keys this log holds; it is
  read, not changed. *)
function BuildCatchUpPlan(aImage: TServerLogImage; aHeld: TServerQsoIndex;
                          const aCtx: TCatchUpContext): TCatchUpPlan;

(* A one-line account of a plan for the log: how many to add, and how many were
  skipped for each reason with the first call. *)
function CatchUpSummary(aPlan: TCatchUpPlan): string;

(* A RECORD AS IT IS WHEN IT JOINS THIS LOG: this station's contest handle (the
  sender's byte is never stored), and sent and clean -- it came from the server,
  so it is not owed back. *)
procedure StampCaughtUp(var aRec: ContestExchange; const aOurHandle: TContestHandle);

implementation

(* ---------------------------------------------------------- TServerLogImage *)

constructor TServerLogImage.Create;
begin
   inherited Create;
   FData := TMemoryStream.Create;
end;

destructor TServerLogImage.Destroy;
begin
   FData.Free;
   inherited Destroy;
end;

function TServerLogImage.Accept(aDeclaredSize: Int64; out aWhy: string): boolean;
var
   i: integer;
   rec: ContestExchange;
begin
   Result := False;
   aWhy := '';
   FCount := 0;
   FQsoCount := 0;

   if FData.Size > SERVER_LOG_MAX_BYTES then
      begin
      aWhy := 'the server log is larger than ' + IntToStr(SERVER_LOG_MAX_BYTES) +
              ' bytes';
      Exit;
      end;

   if FData.Size <> aDeclaredSize then
      begin
      aWhy := 'the server said its log was ' + IntToStr(aDeclaredSize) +
              ' bytes and ' + IntToStr(FData.Size) + ' arrived';
      Exit;
      end;

   if FData.Size = 0 then
      begin
      Result := True;
      Exit;
      end;

   if FData.Size < SizeOfTLogHeader then
      begin
      aWhy := 'the server log is shorter than its header (' +
              IntToStr(FData.Size) + ' bytes)';
      Exit;
      end;

   if ((FData.Size - SizeOfTLogHeader) mod SizeOf(ContestExchange)) <> 0 then
      begin
      aWhy := 'the server log is not a whole number of ' +
              IntToStr(SizeOf(ContestExchange)) + '-byte records after its ' +
              IntToStr(SizeOfTLogHeader) + '-byte header (' +
              IntToStr(FData.Size) + ' bytes)';
      Exit;
      end;

   FCount := (FData.Size - SizeOfTLogHeader) div SizeOf(ContestExchange);
   for i := 0 to FCount - 1 do
      begin
      Row(i, rec);
      if (rec.Band <> NoBand) and (rec.Mode <> NoMode) and
         (not rec.ceQSO_Deleted) then
         begin
         Inc(FQsoCount);
         end;
      end;
   Result := True;
end;

function TServerLogImage.Count: integer;
begin
   Result := FCount;
end;

function TServerLogImage.QsoCount: integer;
begin
   Result := FQsoCount;
end;

function TServerLogImage.Row(aIndex: integer; out aRec: ContestExchange): boolean;
begin
   Result := (aIndex >= 0) and (aIndex < FCount);
   if not Result then
      begin
      aRec := Default(ContestExchange);
      Exit;
      end;

   FData.Position := Int64(SizeOfTLogHeader) + Int64(aIndex) * SizeOf(ContestExchange);
   FData.ReadBuffer(aRec, SizeOf(ContestExchange));
end;

(* ------------------------------------------------------------------- judge *)

function JudgeServerRecord(const aRec: ContestExchange;
                           const aCtx: TCatchUpContext): TCatchUpVerdict;
var
   authorOrdinal: integer;
   byteIsOurs: boolean;
begin
   byteIsOurs := aRec.ceContest = aCtx.OurHandle;

   (* A LEGACY CONTEST'S BYTE IS DEFINITIVE: it is the frozen number, the same on
     every build. A record that is not ours is another contest's, whatever its
     author announces now -- a station can change contest, and its earlier QSOs
     stay in the server's log. *)
   if aCtx.OurIsLegacy and (not byteIsOurs) then
      begin
      Result := cvOtherContest;
      Exit;
      end;

   (* ceComputerID is the LETTER; the table is by ordinal. 0 for anything that is
     not A..Z, which the table does not know. *)
   authorOrdinal := Ord(ComputerIDOrdinal(aRec.ceComputerID));

   case JudgePeerContest(aCtx.Peers, authorOrdinal, aCtx.OurContestId) of
      pcSame:
         begin
         Result := cvAccept;
         end;
      pcOther:
         begin
         Result := cvOtherContest;
         end;
   else
      begin
      (* The author is not here to ask. *)
      if byteIsOurs then
         begin
         Result := cvAccept;
         end
      else
         begin
         Result := cvUnknownContest;
         end;
      end;
   end;
end;

(* -------------------------------------------------------------------- plan *)

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
   Inc(FSkipped[aWhy]);
   if FFirstCall[aWhy] = '' then
      begin
      FFirstCall[aWhy] := aCall;
      end;
end;

function TCatchUpPlan.Count: integer;
begin
   Result := FCount;
end;

function TCatchUpPlan.RowIndex(aN: integer): integer;
begin
   if (aN < 0) or (aN >= FCount) then
      begin
      raise ERangeError.Create('TCatchUpPlan.RowIndex: ' + IntToStr(aN) +
                               ' is outside 0..' + IntToStr(FCount - 1));
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
      cusNoIdentity:     Result := 'no network identity (0, 0)';
      cusAlreadyHeld:    Result := 'already in this log';
      cusRepeated:       Result := 'repeated in the server log';
      cusOtherContest:   Result := 'for another contest';
      cusUnknownContest: Result := 'contest not known (its author is not here and its contest byte differs)';
   else
      begin
      Result := '';
      end;
   end;
end;

function BuildCatchUpPlan(aImage: TServerLogImage; aHeld: TServerQsoIndex;
                          const aCtx: TCatchUpContext): TCatchUpPlan;
var
   i: integer;
   rec: ContestExchange;
   taken: TServerQsoIndex;
begin
   Result := TCatchUpPlan.Create;
   taken := TServerQsoIndex.Create;
   try
      for i := 0 to aImage.Count - 1 do
         begin
         aImage.Row(i, rec);

         if (rec.ceQSOID1 = 0) and (rec.ceQSOID2 = 0) then
            begin
            Result.Skip(cusNoIdentity, string(rec.Callsign));
            Continue;
            end;

         if aHeld.Contains(rec.ceQSOID1, rec.ceQSOID2) then
            begin
            Result.Skip(cusAlreadyHeld, string(rec.Callsign));
            Continue;
            end;

         if taken.Contains(rec.ceQSOID1, rec.ceQSOID2) then
            begin
            Result.Skip(cusRepeated, string(rec.Callsign));
            Continue;
            end;

         case JudgeServerRecord(rec, aCtx) of
            cvAccept:
               begin
               taken.Add(rec.ceQSOID1, rec.ceQSOID2);
               Result.AddRow(i);
               end;
            cvOtherContest:
               begin
               Result.Skip(cusOtherContest, string(rec.Callsign));
               end;
         else
            begin
            Result.Skip(cusUnknownContest, string(rec.Callsign));
            end;
         end;
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

procedure StampCaughtUp(var aRec: ContestExchange; const aOurHandle: TContestHandle);
begin
   aRec.ceContest := aOurHandle;
   aRec.ceSendToServer := True;
   aRec.ceNeedSendToServerAE := False;
end;

end.

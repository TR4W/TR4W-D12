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

(* THE FIRST MESSAGE ON A MULTI-OP LINK -- NETWORK PROTOCOL 2.

  WHAT IT IS FOR.  Two things the V1 link never had: a statement of WHICH
  PROTOCOL each end speaks, and a statement of WHICH CONTEST each station is
  running that is not a byte.

  The V1 packet named a contest with ONE BYTE (ContestExchange.ceContest), a
  number that only a legacy contest has.  A contest registered by its string id
  gets its byte when the registry seals, and the byte differs between builds, so
  it cannot be compared across a network.  Stations therefore AGREE ON THE
  CONTEST BY ITS ID STRING, announced here once per link and again whenever the
  operator changes contest; a QSO is then judged by what its SENDER announced
  (uNet.PeerRecordInOurContest), and the byte is never read.

  THE RULES.
    - The station sends THelloMessage right after the password handshake,
      before anything else.  The server refuses a link whose first message is
      anything else (a 4.x station sends COMPUTERID first) and drops it.
    - The server answers with its own, computer id 0, so the station can see
      which protocol it is talking to.  A station that is refused for its
      version is sent SM_PROTOCOL_MISMATCH carrying the server's version.
    - The server keeps each station's last HELLO, tells a newcomer every
      other station's, and relays a station's HELLO to the rest -- so a
      contest change reaches everyone with no message of its own.
    - The two versions must be EQUAL.  There is no negotiation: V1 stations
      cannot join (NY4I, 2026-10-27: a 4.x station never joins a 5.x network).

  THE LAYOUT IS THE WIRE.  Packed, little-endian, 70 bytes, fixed: the framing
  has no length prefix, so a variable field would be a framing change.  It is
  pinned in uTestNetWireSizes and mirrored in TR4WServerPy and the netprobe
  tool.

  NO SOCKETS AND NO WINDOWS HERE, so the whole of it is reachable from a unit
  test. *)
unit uNetHello;

{$I tr4w.inc}

interface

uses
   Classes,
   VC,
   uComputerID;

const
   (* The protocol this build speaks.  V1 was the D7 / pre-HELLO wire (no
     HELLO message at all); this is 2.  Raise it when ANY wire record changes
     size or meaning, and say so in docs/TR4W_NETWORKING_ANALYSIS.md. *)
   NET_PROTOCOL_VERSION = 2;

   HELLO_VERSION_CHARS  = 16;
   HELLO_CONTEST_CHARS  = 48;

type
   THelloMessage = packed record
      hmID:          Word;       (* NET_HELLO_ID *)
      hmProtocol:    Word;       (* NET_PROTOCOL_VERSION of the sender *)
      (* 1..26 for a station; 0 in the SERVER's own hello.  A station that
        sends 0 has no legal id and is refused like any other bad id. *)
      hmComputerID:  Byte;
      hmReserved:    Byte;       (* 0 *)
      hmAppVersion:  array[0..HELLO_VERSION_CHARS - 1] of AnsiChar;   (* NUL padded *)
      hmContestId:   array[0..HELLO_CONTEST_CHARS - 1] of AnsiChar;   (* NUL padded; '' from the server *)
   end;

   THelloMessagePtr = ^THelloMessage;

   TProtocolVerdict = (
      pvSame,          // the same version -- the only one that may talk
      pvTheirsOlder,   // the other end speaks an older protocol than ours
      pvTheirsNewer    // the other end speaks a newer one
   );

   TPeerContestVerdict = (
      pcSame,          // the sender announced the contest this station is on
      pcOther,         // the sender announced a different contest
      pcNoHello        // the sender has announced nothing
   );

(* May these two ends talk?  Equal versions only; the other two answers say
  WHICH end is behind, which is what the operator's message needs. *)
function JudgeProtocol(const aOurs, aTheirs: Word): TProtocolVerdict;

(* Builds a hello.  False, with aHello zeroed, when a text does not fit its
  field or is not printable ASCII -- an id that cannot be sent whole must not be
  sent truncated, because a truncated id would name a different contest. *)
function BuildHello(const aProtocol: Word; const aComputerID: Byte;
                    const aAppVersion, aContestId: string;
                    out aHello: THelloMessage): boolean;

function HelloAppVersion(const aHello: THelloMessage): string;
function HelloContestId(const aHello: THelloMessage): string;

type
   (* WHAT EACH STATION HAS ANNOUNCED, by its ordinal 1..26.

     One per link: cleared when the link comes up, filled by the HELLOs the
     server relays, emptied for a station when the server says it left.  It
     also remembers which (station, contest) pairs the operator has already
     been told about, so a busy peer on another contest raises one notice and
     not one per QSO. *)
   TNetPeers = class
   private
      FKnown:      array[FIRST_COMPUTER_ID..LAST_COMPUTER_ID] of boolean;
      FProtocol:   array[FIRST_COMPUTER_ID..LAST_COMPUTER_ID] of Word;
      FAppVersion: array[FIRST_COMPUTER_ID..LAST_COMPUTER_ID] of string;
      FContestId:  array[FIRST_COMPUTER_ID..LAST_COMPUTER_ID] of string;
      FNoticed:    array of string;   (* a list of (station|contest id) keys: short, so searched in order *)
   public
      constructor Create;
      destructor Destroy; override;

      procedure Clear;

      (* False, and nothing recorded, when the id is not 1..26. *)
      function Announce(const aHello: THelloMessage): boolean;
      procedure Forget(const aOrdinal: integer);

      function Knows(const aOrdinal: integer): boolean;
      function ContestIdOf(const aOrdinal: integer): string;
      function AppVersionOf(const aOrdinal: integer): string;
      function ProtocolOf(const aOrdinal: integer): Word;

      (* True the FIRST time this pair is asked since the last ForgetNotices. *)
      function FirstNotice(const aOrdinal: integer; const aContestId: string): boolean;
      procedure ForgetNotices;
   end;

(* Is this sender on this contest?  The ONE judgement of a received QSO's
  contest.  The comparison ignores case, as the contest-name resolver does. *)
function JudgePeerContest(const aPeers: TNetPeers; const aSender: integer;
                          const aOurContestId: string): TPeerContestVerdict;

implementation

uses
   SysUtils;

function JudgeProtocol(const aOurs, aTheirs: Word): TProtocolVerdict;
begin
   if aTheirs = aOurs then
      begin
      Result := pvSame;
      end
   else if aTheirs < aOurs then
      begin
      Result := pvTheirsOlder;
      end
   else
      begin
      Result := pvTheirsNewer;
      end;
end;

(* One text into a NUL-padded field.  The field is an open array so it carries
  its own length; nothing is written past it. *)
function PutText(const aText: string; var aField: array of AnsiChar): boolean;
var
   i: integer;
begin
   Result := False;
   if Length(aText) > Length(aField) then
      begin
      Exit;
      end;

   for i := 1 to Length(aText) do
      begin
      if (Ord(aText[i]) < 32) or (Ord(aText[i]) > 126) then
         begin
         Exit;
         end;
      aField[i - 1] := AnsiChar(Ord(aText[i]));
      end;
   Result := True;
end;

function GetText(const aField: array of AnsiChar): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to High(aField) do
      begin
      if aField[i] = #0 then
         begin
         Break;
         end;
      Result := Result + Char(Ord(aField[i]));
      end;
end;

function BuildHello(const aProtocol: Word; const aComputerID: Byte;
                    const aAppVersion, aContestId: string;
                    out aHello: THelloMessage): boolean;
begin
   aHello := Default(THelloMessage);
   aHello.hmID := NET_HELLO_ID;
   aHello.hmProtocol := aProtocol;
   aHello.hmComputerID := aComputerID;

   Result := PutText(aAppVersion, aHello.hmAppVersion) and
             PutText(aContestId, aHello.hmContestId);
   if not Result then
      begin
      aHello := Default(THelloMessage);
      end;
end;

function HelloAppVersion(const aHello: THelloMessage): string;
begin
   Result := GetText(aHello.hmAppVersion);
end;

function HelloContestId(const aHello: THelloMessage): string;
begin
   Result := GetText(aHello.hmContestId);
end;

(* ---------------------------------------------------------------- TNetPeers *)

constructor TNetPeers.Create;
begin
   inherited Create;
   FNoticed := nil;
end;

destructor TNetPeers.Destroy;
begin
   FNoticed := nil;
   inherited Destroy;
end;

procedure TNetPeers.Clear;
var
   i: integer;
begin
   for i := FIRST_COMPUTER_ID to LAST_COMPUTER_ID do
      begin
      Forget(i);
      end;
   ForgetNotices;
end;

function TNetPeers.Announce(const aHello: THelloMessage): boolean;
var
   n: integer;
begin
   n := aHello.hmComputerID;
   Result := (n >= FIRST_COMPUTER_ID) and (n <= LAST_COMPUTER_ID);
   if not Result then
      begin
      Exit;
      end;

   FKnown[n] := True;
   FProtocol[n] := aHello.hmProtocol;
   FAppVersion[n] := HelloAppVersion(aHello);
   FContestId[n] := HelloContestId(aHello);
end;

procedure TNetPeers.Forget(const aOrdinal: integer);
begin
   if (aOrdinal >= FIRST_COMPUTER_ID) and (aOrdinal <= LAST_COMPUTER_ID) then
      begin
      FKnown[aOrdinal] := False;
      FProtocol[aOrdinal] := 0;
      FAppVersion[aOrdinal] := '';
      FContestId[aOrdinal] := '';
      end;
end;

function TNetPeers.Knows(const aOrdinal: integer): boolean;
begin
   Result := (aOrdinal >= FIRST_COMPUTER_ID) and (aOrdinal <= LAST_COMPUTER_ID) and
             FKnown[aOrdinal];
end;

function TNetPeers.ContestIdOf(const aOrdinal: integer): string;
begin
   Result := '';
   if Knows(aOrdinal) then
      begin
      Result := FContestId[aOrdinal];
      end;
end;

function TNetPeers.AppVersionOf(const aOrdinal: integer): string;
begin
   Result := '';
   if Knows(aOrdinal) then
      begin
      Result := FAppVersion[aOrdinal];
      end;
end;

function TNetPeers.ProtocolOf(const aOrdinal: integer): Word;
begin
   Result := 0;
   if Knows(aOrdinal) then
      begin
      Result := FProtocol[aOrdinal];
      end;
end;

function TNetPeers.FirstNotice(const aOrdinal: integer;
                               const aContestId: string): boolean;
var
   key: string;
   i: integer;
begin
   key := IntToStr(aOrdinal) + '|' + aContestId;
   for i := 0 to High(FNoticed) do
      begin
      if UnicodeSameText(FNoticed[i], key) then
         begin
         Result := False;
         Exit;
         end;
      end;
   Result := True;
   SetLength(FNoticed, Length(FNoticed) + 1);
   FNoticed[High(FNoticed)] := key;
end;

procedure TNetPeers.ForgetNotices;
begin
   FNoticed := nil;
end;

function JudgePeerContest(const aPeers: TNetPeers; const aSender: integer;
                          const aOurContestId: string): TPeerContestVerdict;
begin
   if not aPeers.Knows(aSender) then
      begin
      Result := pcNoHello;
      end
   else if UnicodeSameText(aPeers.ContestIdOf(aSender), aOurContestId) then
      begin
      Result := pcSame;
      end
   else
      begin
      Result := pcOther;
      end;
end;

end.

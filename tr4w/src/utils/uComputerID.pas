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
unit uComputerID;
{$I ..\tr4w.inc}

(*
  WHICH STATION IS WHICH, ON A MULTI-OP NETWORK.

  Every TR4W station on the network announces a one-letter id.  It is not a
  label: it is an INDEX.  A client receiving a station status computes

     StatusArray[Ord(ssComputerID) - Ord('A') + 1] := ...        (uNet.pas)

  so the letter IS the address of that station's row, on every machine in the
  network -- which is also why the server accepts exactly 26 clients rather than
  26 being a policy.  Three further places ask "is this QSO mine?" by comparing
  a QSO's ceComputerID against this station's own, one of them the transmitter
  id written into every Cabrillo QSO line for a multi-op entry.

  SO TWO STATIONS SHARING A LETTER IS NOT A COSMETIC CLASH.  They become one row
  on every client, and each starts treating some of the other's QSOs as its own
  for editing and for export.  Nothing reports it, and the merged log looks
  correct.  Until 2026-09-01 nothing checked: the server stored the id and never
  compared it against the twenty-five others it was already holding.

  THE RULE LIVES HERE, AWAY FROM THE SOCKETS, so it can be tested.  The server
  owns the question of WHICH ids are currently taken -- that is a walk over its
  client array, and it is plumbing.  What COUNTS as acceptable is a rule, it has
  three outcomes rather than a boolean, and it is worth pinning exhaustively.

  ON THE ENCODING, WHICH IS THE TRAP IN THIS AREA.  The id travels in TWO forms
  on ONE protocol:

    NET_COMPUTERID_ID     an ORDINAL, 1..26.  The client sends
                          AnsiChar(Ord(Settings.Computer.Id) - Ord('A') + 1).
    NET_STATIONSTATUS_ID  the LETTER, 'A'..'Z', converted back on receipt.

  TClientEntry.clID is declared AnsiChar and every comment near it -- including
  the TR4QT protocol analysis -- calls it "'A'..'Z' station identifier".  It
  holds the ORDINAL.  This unit works in the ordinal because that is what the
  wire and the server array carry, and converts to a letter only for display.
*)

interface

const
   { The whole address space.  MAXCLIENTS in the server is this same number for
     this same reason, not by coincidence. }
   FIRST_COMPUTER_ID = 1;
   LAST_COMPUTER_ID  = 26;

type
   { The ids currently held by CONNECTED stations. }
   TComputerIDSet = set of FIRST_COMPUTER_ID..LAST_COMPUTER_ID;

   TComputerIDVerdict =
      (
      cidAccept,       // free, and in range
      cidOutOfRange,   // not 1..26 -- would index StatusArray out of bounds
      cidInUse         // another connected station already answers to it
      );

{ May this station have this id?

  aTaken must NOT include the asking station's own current id, or a station that
  re-announces the id it already holds refuses itself. }
function JudgeComputerID(const aID: AnsiChar;
                         const aTaken: TComputerIDSet): TComputerIDVerdict;

const
   (* A letter held by a stale session of the SAME station is taken over by the
     new connection. If the same letter is taken over AGAIN inside this many
     milliseconds, the two "same" stations are really two live ones sharing an
     address (NAT, a gateway): the later claim is refused as it always was, so
     they cannot evict each other for ever. The Python server's
     ID_TAKEOVER_FLAP_WINDOW is 30 seconds; the two must stay equal. *)
   ID_TAKEOVER_FLAP_WINDOW_MS = 30000;

type
   TTakeoverVerdict =
      (
      tvNotSameStation,   // refuse, as always
      tvTakeOver,         // the holder is a stale session of this station
      tvFlap              // same station, but a takeover of this letter was just done
      );

(* IS THE CLAIMANT, AS FAR AS THE SERVER CAN TELL, THE SAME MACHINE AS THE
  HOLDER of the letter (a session the server may not yet know is dead)?

  The peer address is the necessary condition: empty or different is no. The
  host name, the program version and the contest must then not DISAGREE; a
  value either side does not have (the legacy COMPUTERID path carries no
  version or contest) does not count against it. It is not a proof: the HELLO
  has no install id, so two stations behind one address that announce the same
  version and contest are indistinguishable, and the flap window is what stops
  that becoming a fight. The same rule as the Python server's _same_station. *)
function IsSameStation(const aClaimAddress, aHolderAddress,
                       aClaimHostName, aHolderHostName,
                       aClaimVersion, aHolderVersion,
                       aClaimContest, aHolderContest: string): boolean;

(* WHAT TO DO ABOUT A HOLDER. aLastTakeoverTick is the tick (GetTickCount64) at
  which this letter was last taken over, 0 for never (a tick of 0 is the first
  millisecond after boot). *)
function JudgeTakeover(const aSameStation: boolean;
                       const aLastTakeoverTick, aNowTick: QWord): TTakeoverVerdict;

{ The ordinal as the operator's letter, or '?' when it is not a legal id.

  '?' rather than an exception or a blank: this is only ever used to build a
  message about something that has ALREADY gone wrong, and a message that
  cannot be composed is worse than one that says the id was unreadable. }
function ComputerIDLetter(const aID: AnsiChar): AnsiChar;

{ The letter as the ordinal the wire carries.  #0 for anything that is not
  'A'..'Z', which is a value JudgeComputerID rejects as out of range. }
function ComputerIDOrdinal(const aLetter: AnsiChar): AnsiChar;

implementation

function JudgeComputerID(const aID: AnsiChar;
                         const aTaken: TComputerIDSet): TComputerIDVerdict;
begin
   { RANGE BEFORE UNIQUENESS, and not only for tidiness: an out-of-range id
     would index StatusArray outside 1..26 on every client that receives a
     status from this station, and range checking is off in this tree -- so it
     would not raise, it would corrupt whatever sits beside the array. }
   if not (Ord(aID) in [FIRST_COMPUTER_ID..LAST_COMPUTER_ID]) then
      begin
      Result := cidOutOfRange;
      end
   else if Ord(aID) in aTaken then
      begin
      Result := cidInUse;
      end
   else
      begin
      Result := cidAccept;
      end;
end;

function IsSameStation(const aClaimAddress, aHolderAddress,
                       aClaimHostName, aHolderHostName,
                       aClaimVersion, aHolderVersion,
                       aClaimContest, aHolderContest: string): boolean;
begin
   Result := False;
   if (aClaimAddress = '') or (aClaimAddress <> aHolderAddress) then
      begin
      Exit;
      end;

   if (aClaimHostName <> '') and (aHolderHostName <> '') and
      (aClaimHostName <> aHolderHostName) then
      begin
      Exit;
      end;

   if (aClaimVersion <> '') and (aHolderVersion <> '') and
      (aClaimVersion <> aHolderVersion) then
      begin
      Exit;
      end;

   if (aClaimContest <> '') and (aHolderContest <> '') and
      (aClaimContest <> aHolderContest) then
      begin
      Exit;
      end;

   Result := True;
end;

function JudgeTakeover(const aSameStation: boolean;
                       const aLastTakeoverTick, aNowTick: QWord): TTakeoverVerdict;
begin
   if not aSameStation then
      begin
      Result := tvNotSameStation;
      end
   else if (aLastTakeoverTick <> 0) and
           (aNowTick - aLastTakeoverTick < ID_TAKEOVER_FLAP_WINDOW_MS) then
      begin
      Result := tvFlap;
      end
   else
      begin
      Result := tvTakeOver;
      end;
end;

function ComputerIDLetter(const aID: AnsiChar): AnsiChar;
begin
   if Ord(aID) in [FIRST_COMPUTER_ID..LAST_COMPUTER_ID] then
      begin
      Result := AnsiChar(Ord(aID) + Ord('A') - 1);
      end
   else
      begin
      Result := '?';
      end;
end;

function ComputerIDOrdinal(const aLetter: AnsiChar): AnsiChar;
begin
   if aLetter in ['A'..'Z'] then
      begin
      Result := AnsiChar(Ord(aLetter) - Ord('A') + 1);
      end
   else
      begin
      Result := #0;
      end;
end;

end.

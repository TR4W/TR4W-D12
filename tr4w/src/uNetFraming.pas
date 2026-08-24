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

{ WHERE ONE MULTI-OP MESSAGE ENDS AND THE NEXT BEGINS.

  THIS IS THE MULTI-OPERATOR NETWORK -- TR4WServer, carrying QSOs, radio state
  and operator state.  It is NOT the DX cluster, which is a separate connection
  to a separate peer carrying line-oriented spot text.  The two are unrelated
  and the only place they touch is one spot-forwarding call in uNet.

  THE PROTOCOL HAS NO FRAMING.  No length prefix, no sentinel, no checksum.  A
  message is a leading Word id followed by the record that id implies, and the
  boundary is therefore IMPLICIT IN A TYPE TABLE.  Both ends compile the same
  VC.pas, so they agree by construction -- until a hand-written advance in one
  arm disagrees with the record it just cast.

  WHICH IS EXACTLY WHAT HAPPENED.  NET_SPOTVIANETWORK_ID cast the buffer to
  TSendSpotViaNetworkPtr and then advanced by SizeOf(NetQSOInfoToSend): 264
  bytes for a 48-byte message.  One network-forwarded spot desynchronised
  everything behind it, silently.  That defect is only possible while the SIZE
  lives beside each arm; here there is one table and the arms cannot disagree
  with it.

  IT DELIBERATELY KNOWS NOTHING ELSE.  No sockets, no windows, no handlers, no
  logging -- so the whole of it is reachable from a unit test, which the parse
  loop inside a dialog procedure never was. }
unit uNetFraming;

{$I tr4w.inc}

interface

uses
   VC;

type
   { Why a walk stopped. }
   TNetWalkResult = (
      nwComplete,     // the buffer ended exactly on a message boundary
      nwPartial,      // a known id, but not all of its bytes are here yet
      nwUnknownId     // no table entry -- the walk cannot advance past it
   );

{ How many bytes the message with this id occupies, INCLUDING its leading id
  Word, or 0 if the id is not one we know.

  0 IS THE IMPORTANT ANSWER.  It is what tells the caller it cannot advance,
  which is the difference between reporting a desync and spinning on it. }
function NetMessageSize(const aId: word): integer;

{ Walks one received buffer.

  aBuffer is 1-BASED, matching NetBuffer, because the caller passes that
  directly and a translation would be one more place to be off by one.
  aLength is the byte count recv returned.

  aOffset is in/out: the 1-based position to read from, advanced past the
  message that was returned.  aId receives the id found there.

  Returns True when a COMPLETE message is available at aOffset -- and only
  then may the caller cast a record out of the buffer.  Returns False with
  aResult saying why: nwComplete (nothing left), nwPartial (a known message
  that has not all arrived) or nwUnknownId. }
function NextNetMessage(const aBuffer; const aLength: integer;
                        var aOffset: integer; out aId: word;
                        out aResult: TNetWalkResult): boolean;

implementation

type
   PWordArray = ^word;

function NetMessageSize(const aId: word): integer;
begin
   case aId of
      NET_MESSAGESTATE_ID:     Result := SizeOf(TMessageState);
      NET_LOGCOMPARE_ID:       Result := SizeOf(TLogFileInformation);
      NET_INTERCOMMESSAGE_ID:  Result := SizeOf(TIntercomMessage);
      NET_NETWORKDXSPOT_ID:    Result := SizeOf(TNetDXSpot);

      // Three ids, one record: a new QSO, an edited QSO and an offline QSO
      // differ in what the receiver DOES, not in what arrives.
      NET_QSOINFO_ID,
      NET_EDITEDQSO_ID,
      NET_OFFLINEQSO_ID:       Result := SizeOf(TNetQSOInformation);

      NET_TAKESERVERQSO_ID:    Result := SizeOf(TNetSynQSOInformation);
      NET_TIMESYN_ID:          Result := SizeOf(TNetTimeSync);
      NET_PARAMETER_ID:        Result := SizeOf(TParameterToNetwork);
      NET_STATIONSTATUS_ID:    Result := SizeOf(TStationState);
      NET_CLIENTSTATUS_ID:     Result := SizeOf(TClientStatus);
      NET_SPOTVIANETWORK_ID:   Result := SizeOf(TSendSpotViaNetwork);
      NET_COMPUTERID_ID:       Result := SizeOf(TComputerNetID);
      NET_SERVERMESSAGE_ID:    Result := SizeOf(TServerMessage);
   else
      // NET_THIS_QTC_WAS__SEND_ID (1056) is DELIBERATELY ABSENT: the constant
      // exists in VC.pas but nothing on either side sends or handles it, and
      // guessing a record for it would put a wrong size in the one table that
      // is supposed to be right.
      Result := 0;
   end;
end;

function NextNetMessage(const aBuffer; const aLength: integer;
                        var aOffset: integer; out aId: word;
                        out aResult: TNetWalkResult): boolean;
var
   remaining: integer;
   size: integer;
   p: PByte;
begin
   Result := False;
   aId := 0;
   aResult := nwComplete;

   if (aOffset < 1) or (aLength < 1) then
      begin
      Exit;
      end;

   remaining := aLength - aOffset + 1;
   if remaining <= 0 then
      begin
      Exit;      // ended exactly on a boundary -- nwComplete
      end;

   // NOT EVEN THE ID FITS.  One byte of a two-byte id is a partial message, not
   // an unknown one; calling it unknown would report a garbage id built from
   // one real byte and one stale one.
   if remaining < SizeOf(word) then
      begin
      aResult := nwPartial;
      Exit;
      end;

   p := PByte(@aBuffer);
   Inc(p, aOffset - 1);          // 1-based, like NetBuffer
   aId := PWord(p)^;

   size := NetMessageSize(aId);
   if size = 0 then
      begin
      aResult := nwUnknownId;
      Exit;
      end;

   { THE LENGTH CHECK THE ORIGINAL LOOP NEVER HAD.

     Every arm used to cast a whole record out of the buffer without asking
     whether the whole record was there.  If 100 bytes of a 264-byte QSO had
     arrived, the remaining 164 were STALE BYTES FROM AN EARLIER recv -- and the
     QSO was logged from them.  A duplicate of an earlier contact with a
     plausible call and a wrong band, or a garbage exchange, and nothing in the
     UI marked it.

     This does not make a split message WORK -- that needs a carry-over buffer
     the receive path does not have yet.  It makes it FAIL LOUDLY instead of
     silently logging a wrong QSO, which is the trade this branch takes every
     time. }
   if remaining < size then
      begin
      aResult := nwPartial;
      Exit;
      end;

   Inc(aOffset, size);
   Result := True;
end;

end.

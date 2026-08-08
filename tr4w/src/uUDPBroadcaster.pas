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
unit uUDPBroadcaster;

{
  Owns the UDP broadcast DECISIONS: is this stream switched on, where does it
  go, and on which port.

  WHY THIS EXISTS AT ALL.  Those three facts used to live in fourteen globals
  read at the point of sending, and the first of them -- "is this stream on" --
  was tested by the CALLER.  Seven call sites restated it (MainUnit:1075,
  LOGSUBS2:688, 1466, 1587, 2763, 2851) and they had ALREADY DIVERGED:
  SendDeletedContactToUDP checked the flag itself, LogContactToUDP did not and
  relied on each of its callers to remember.  A rule restated at seven sites is
  a rule that a new eighth site breaks silently, and the operator's report is
  "it broadcasts when I told it not to" (NY4I 2026-08-08).

  The enable test is now INSIDE Send.  A caller cannot forget it because a
  caller cannot express it.

  WHAT THIS UNIT DELIBERATELY DOES NOT DO.

  It does not build payloads.  Those need ContestExchange and the contest
  globals and belong where they are, in LOGSUBS2 -- the seam is "TRDOS says what
  happened and hands over the bytes; this decides whether and where they go".

  It does not know Indy.  The transport is a hook (TUDPSendProc) assigned once
  at startup by the unit that owns the TIdUDPClient.  That is what lets the
  whole of this be unit-tested -- enable rules, port routing, address -- with a
  recording stub and no socket.  A design whose rules can only be checked by
  watching a network trace is a design whose rules do not get checked.

  THE CONFIG IS SWAPPED WHOLE, never edited field by field.  These settings
  change as a SET: one address, six ports, seven enables.  A property setter per
  field would leave a window in which the address is the new one and the port is
  still the old one, and a send from another thread would read the mixture.
  Configure() takes a COPY and replaces the previous one, so a send sees either
  the old settings or the new ones and never a blend.
}

interface

uses
   System.SysUtils,
   System.SyncObjs,
   uUDPBroadcastConfig;

type
   // The transport, injected.  AnsiString because the payloads are built as
   // bytes-on-the-wire text and must not be re-encoded on the way out.
   // A PLAIN procedure type, not "of object": the unit that owns the socket
   // installs a unit-level routine, and a test installs a recording stub.
   // Neither is a method, and requiring one would have meant inventing an
   // object purely to satisfy the signature.
   TUDPSendProc = procedure(const aAddress: string;
                            const aPort: integer;
                            const aPayload: AnsiString);

   TUDPBroadcaster = class
   private
      FConfig: TUDPBroadcastConfig;
      FSend: TUDPSendProc;
      FLock: TCriticalSection;
      // Sends to every destination registered for the stream.  Caller holds
      // the lock; the transport is called OUTSIDE it -- see Send.
      procedure CollectTargets(const aStream: TUDPStream;
                               var aAddresses: TArray<string>;
                               var aPorts: TArray<integer>);
   public
      constructor Create;
      destructor Destroy; override;

      // Replaces the settings as a whole.  Takes a COPY: the caller keeps
      // ownership of what it passes, and a later edit of that object cannot
      // reach into a send that is already under way.
      procedure Configure(const aConfig: TUDPBroadcastConfig);

      // The current settings, as a copy the caller owns.  A copy rather than
      // the live object so nothing outside can mutate what sends are reading.
      function Snapshot: TUDPBroadcastConfig;

      // Where the transport is plugged in.  Nil until assigned, and a send with
      // no transport is a no-op rather than an AV -- the broadcaster is created
      // before the socket exists.
      procedure SetTransport(const aSend: TUDPSendProc);

      // Is this stream switched on?  Public because a caller may want to skip
      // BUILDING a payload it is about to throw away; it is not a precondition
      // of Send, which tests it again.
      function Enabled(const aStream: TUDPStream): boolean;

      // Sends, IF the stream is enabled.  Silently doing nothing is correct
      // here: "not enabled" is the operator's decision, not a fault.
      procedure Send(const aStream: TUDPStream; const aPayload: AnsiString);

      // The one policy flag that is not a stream: whether an edited or
      // previously-logged QSO is rebroadcast, or only new ones.
      function BroadcastAllQSOs: boolean;
   end;

// The one instance.  Created on first use so no unit's initialisation order
// can matter, and freed in this unit's finalization.
function UDPBroadcaster: TUDPBroadcaster;

implementation

var
   gBroadcaster: TUDPBroadcaster = nil;
   gCreateLock: TCriticalSection = nil;

function UDPBroadcaster: TUDPBroadcaster;
begin
   gCreateLock.Enter;
   try
      if gBroadcaster = nil then
         begin
         gBroadcaster := TUDPBroadcaster.Create;
         end;
      Result := gBroadcaster;
   finally
      gCreateLock.Leave;
   end;
end;

constructor TUDPBroadcaster.Create;
begin
   inherited Create;
   FLock   := TCriticalSection.Create;
   FConfig := TUDPBroadcastConfig.Create;   // documented defaults until configured
   FSend   := nil;
end;

destructor TUDPBroadcaster.Destroy;
begin
   FConfig.Free;
   FLock.Free;
   inherited Destroy;
end;

procedure TUDPBroadcaster.Configure(const aConfig: TUDPBroadcastConfig);
var
   replacement: TUDPBroadcastConfig;
   previous: TUDPBroadcastConfig;
begin
   if aConfig = nil then
      begin
      Exit;
      end;

   // Built OUTSIDE the lock and swapped in with one assignment: the lock is
   // held for a pointer exchange, not for a fourteen-field copy.
   replacement := aConfig.Clone;

   FLock.Enter;
   try
      previous := FConfig;
      FConfig  := replacement;
   finally
      FLock.Leave;
   end;

   previous.Free;
end;

function TUDPBroadcaster.Snapshot: TUDPBroadcastConfig;
begin
   FLock.Enter;
   try
      Result := FConfig.Clone;
   finally
      FLock.Leave;
   end;
end;

procedure TUDPBroadcaster.SetTransport(const aSend: TUDPSendProc);
begin
   FLock.Enter;
   try
      FSend := aSend;
   finally
      FLock.Leave;
   end;
end;

procedure TUDPBroadcaster.CollectTargets(const aStream: TUDPStream;
                                        var aAddresses: TArray<string>;
                                        var aPorts: TArray<integer>);
var
   i, n: integer;
begin
   // Caller holds the lock.
   SetLength(aAddresses, 0);
   SetLength(aPorts, 0);
   n := 0;
   for i := 0 to FConfig.DestinationCount - 1 do
      begin
      if FConfig.Destination[i].Stream <> aStream then
         begin
         Continue;
         end;
      SetLength(aAddresses, n + 1);
      SetLength(aPorts, n + 1);
      aAddresses[n] := FConfig.Destination[i].Address;
      aPorts[n]     := FConfig.Destination[i].Port;
      Inc(n);
      end;
end;

function TUDPBroadcaster.Enabled(const aStream: TUDPStream): boolean;
begin
   // EMERGENT, not a stored flag.  A stream is on when something is listening.
   // The old shape had a separate boolean, which meant "enabled" and "has
   // somewhere to go" were two facts free to disagree -- CONTACT=FALSE with a
   // contact port carefully filled in says nothing at all.
   FLock.Enter;
   try
      Result := FConfig.CountFor(aStream) > 0;
   finally
      FLock.Leave;
   end;
end;

procedure TUDPBroadcaster.Send(const aStream: TUDPStream; const aPayload: AnsiString);
var
   sendProc: TUDPSendProc;
   addresses: TArray<string>;
   ports: TArray<integer>;
   i: integer;
begin
   // The destinations are collected under ONE lock, so every target comes from
   // the same configuration -- the reason Configure swaps rather than edits.
   FLock.Enter;
   try
      CollectTargets(aStream, addresses, ports);
      sendProc := FSend;
   finally
      FLock.Leave;
   end;

   // Nothing listening: not a fault, just a stream the operator did not
   // subscribe anything to.
   if Length(addresses) = 0 then
      begin
      Exit;
      end;

   // No transport yet: the broadcaster predates the socket, and a send during
   // startup is not worth an exception.
   if not Assigned(sendProc) then
      begin
      Exit;
      end;

   // OUTSIDE the lock.  A transport that blocks -- a slow or unreachable
   // destination -- must not hold up a Configure from the UI thread, and with
   // several destinations that risk is multiplied.
   for i := 0 to High(addresses) do
      begin
      sendProc(addresses[i], ports[i], aPayload);
      end;
end;

function TUDPBroadcaster.BroadcastAllQSOs: boolean;
begin
   FLock.Enter;
   try
      Result := FConfig.AllQSOs;
   finally
      FLock.Leave;
   end;
end;

initialization
   gCreateLock := TCriticalSection.Create;

finalization
   FreeAndNil(gBroadcaster);
   FreeAndNil(gCreateLock);

end.

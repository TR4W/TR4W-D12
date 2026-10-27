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

(* THE MULTI-OP LINK AS A STATE, AND WHO IS TOLD WHEN IT CHANGES.

  NY4I, 2026-10-27: "I never liked the idea that we only connected when the
  Network window was up."  The link belongs to the PROGRAM; the Network window
  is one view of it, and the Net menu is its control.  This unit holds the
  small amount of that which needs no socket and no widget set, so a unit test
  can reach all of it:

    TNetLinkState         what the link is doing, from four facts uNet knows
    LinkCommandEnabled    which of Connect / Disconnect / Reconnect / Show
                          window the operator is offered in each state
    LinkNeedsLiveLink     the Net-menu rows that mean nothing without a link
    ShouldConnectAtStartup  the startup rule
    NetLinkObservers      who wants to hear that the state changed

  THE OBSERVERS ARE THE ANSWER TO "NO DANGLING REFERENCE FROM THE LINK TO THE
  WINDOW".  The link never names the form.  A form that wants to follow the link
  adds a method of its own and REMOVES it in its destructor; the link only
  ever calls what is on the list.  The list is walked from a copy, so an
  observer may remove itself while it is being told. *)
unit uNetLink;

{$I tr4w.inc}

interface

uses
   Classes;

type
   (* nlsOff        the operator has not asked for a link (or has taken it
                    down); nothing is retried
      nlsConnecting a connect attempt is in flight
      nlsConnected  the server acknowledged the password and this station
      nlsWaiting    a link is wanted and is not up: the retry timer is trying
      nlsRefused    a link is wanted, the server (or its protocol, or this
                    station's id) was refused and the operator has been told;
                    nothing is retried until Connect or Reconnect *)
   TNetLinkState = (nlsOff, nlsConnecting, nlsConnected, nlsWaiting, nlsRefused);

   TNetLinkCommand = (nlcConnect, nlcDisconnect, nlcReconnect, nlcShowWindow);

(* The state from the four facts that decide it. A live link wins over
  everything, then a connect in flight; only then do the operator's wish
  (aWanted) and a standing refusal (aRefused) matter. A refusal with no wish
  for a link is not shown: the link is simply off. *)
function ResolveLinkState(const aWanted, aConnected, aConnecting,
                          aRefused: boolean): TNetLinkState;

(* May the operator use this command now?  Show window is always offered.

  Disconnect is offered while a connect is in flight: it cancels the retries
  (the attempt's thread drops its own link if it succeeds), and without it an
  unreachable server would leave no way to stop the retrying. Connect and
  Reconnect are not offered while connecting - an attempt is already running. *)
function LinkCommandEnabled(const aState: TNetLinkState;
                            const aCommand: TNetLinkCommand): boolean;

(* The Net-menu rows that send something to the other stations (set the clock,
  send a message, clear the server's logs): enabled only on a live link. *)
function LinkNeedsLiveLink(const aState: TNetLinkState): boolean;

(* THE STARTUP RULE. The link connects at startup only when the operator has
  said so (Network.AutoConnect) AND this station has a legal computer id, the
  letter the whole protocol indexes stations by. Without an id the connect would
  only be refused, so nothing is attempted and the Connect menu item says what
  is missing when it is used. *)
function ShouldConnectAtStartup(const aAutoConnect: boolean;
                                const aComputerId: AnsiChar): boolean;

(* The state in words for the log. Not for the operator: it is not translated. *)
function LinkStateName(const aState: TNetLinkState): string;

type
   (* A LIST OF WHO WANTS TO HEAR THAT THE LINK CHANGED. *)
   TNetLinkObservers = class
   private
      FList: array of TNotifyEvent;
      function IndexOf(const aObserver: TNotifyEvent): integer;
   public
      (* Adding the same method twice adds it once. *)
      procedure Add(const aObserver: TNotifyEvent);
      procedure Remove(const aObserver: TNotifyEvent);
      function Count: integer;
      procedure Notify(aSender: TObject);
   end;

(* The one list the program has. *)
function NetLinkObservers: TNetLinkObservers;

implementation

uses
   SysUtils;

function ResolveLinkState(const aWanted, aConnected, aConnecting,
                          aRefused: boolean): TNetLinkState;
begin
   if aConnected then
      begin
      Result := nlsConnected;
      end
   else if aConnecting then
      begin
      Result := nlsConnecting;
      end
   else if not aWanted then
      begin
      Result := nlsOff;
      end
   else if aRefused then
      begin
      Result := nlsRefused;
      end
   else
      begin
      Result := nlsWaiting;
      end;
end;

function LinkCommandEnabled(const aState: TNetLinkState;
                            const aCommand: TNetLinkCommand): boolean;
begin
   case aCommand of
      nlcConnect:
         begin
         Result := aState in [nlsOff, nlsWaiting, nlsRefused];
         end;
      nlcDisconnect:
         begin
         Result := aState <> nlsOff;
         end;
      nlcReconnect:
         begin
         Result := aState in [nlsConnected, nlsWaiting, nlsRefused];
         end;
   else
      begin
      Result := True;
      end;
   end;
end;

function LinkNeedsLiveLink(const aState: TNetLinkState): boolean;
begin
   Result := aState = nlsConnected;
end;

function ShouldConnectAtStartup(const aAutoConnect: boolean;
                                const aComputerId: AnsiChar): boolean;
begin
   Result := aAutoConnect and (aComputerId >= 'A') and (aComputerId <= 'Z');
end;

function LinkStateName(const aState: TNetLinkState): string;
begin
   case aState of
      nlsOff:
         begin
         Result := 'off';
         end;
      nlsConnecting:
         begin
         Result := 'connecting';
         end;
      nlsConnected:
         begin
         Result := 'connected';
         end;
      nlsWaiting:
         begin
         Result := 'waiting to retry';
         end;
      nlsRefused:
         begin
         Result := 'refused';
         end;
   else
      begin
      Result := 'unknown';
      end;
   end;
end;

(* -------------------------------------------------------- TNetLinkObservers *)

function TNetLinkObservers.IndexOf(const aObserver: TNotifyEvent): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to High(FList) do
      begin
      if (TMethod(FList[i]).Code = TMethod(aObserver).Code) and
         (TMethod(FList[i]).Data = TMethod(aObserver).Data) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure TNetLinkObservers.Add(const aObserver: TNotifyEvent);
begin
   if (not Assigned(aObserver)) or (IndexOf(aObserver) >= 0) then
      begin
      Exit;
      end;
   SetLength(FList, Length(FList) + 1);
   FList[High(FList)] := aObserver;
end;

procedure TNetLinkObservers.Remove(const aObserver: TNotifyEvent);
var
   i: integer;
begin
   i := IndexOf(aObserver);
   if i < 0 then
      begin
      Exit;
      end;
   while i < High(FList) do
      begin
      FList[i] := FList[i + 1];
      Inc(i);
      end;
   SetLength(FList, Length(FList) - 1);
end;

function TNetLinkObservers.Count: integer;
begin
   Result := Length(FList);
end;

procedure TNetLinkObservers.Notify(aSender: TObject);
var
   snapshot: array of TNotifyEvent;
   i: integer;
begin
   (* A SNAPSHOT, so an observer that removes itself (a form being destroyed)
     does not shift the list under the walk. One removed by ANOTHER observer
     during the walk is skipped: its object may already be gone. *)
   snapshot := Copy(FList, 0, Length(FList));
   for i := 0 to High(snapshot) do
      begin
      if IndexOf(snapshot[i]) >= 0 then
         begin
         snapshot[i](aSender);
         end;
      end;
end;

var
   GObservers: TNetLinkObservers = nil;

function NetLinkObservers: TNetLinkObservers;
begin
   if GObservers = nil then
      begin
      GObservers := TNetLinkObservers.Create;
      end;
   Result := GObservers;
end;

initialization

finalization
   FreeAndNil(GObservers);

end.

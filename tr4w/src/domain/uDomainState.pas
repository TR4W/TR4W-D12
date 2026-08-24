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

{ THE BASE OF THE DOMAIN LAYER.  First unit under src\domain\.

  WHAT THIS LAYER IS FOR, in one sentence: a worker thread should update STATE,
  not name a widget.  Today a UDP listener thread calls
  SetMainWindowText(mweWSJTX, 'WSJTX') -- an Indy thread that knows the name of
  a control.  The order this is being unwound in, and why display state goes
  before SQLite and the contest factory, is docs\DOMAIN_LAYER_SEQUENCE.md.

  NOTHING HERE MAY TOUCH THE LCL OR WINDOWS, and that is enforced rather than
  intended: build\Lint-DomainPurity.ps1 fails the build if any unit under
  src\domain\ references the widget set, the Windows unit, wh[] or an mwe*
  identifier.  The lint shipped with this file, not after it, because a `uses
  Forms` arrives in a commit that is about something else.

  Classes IS allowed.  It is the FCL, not the LCL -- TList and TMethod are
  RTL-level and available on every platform TR4W will target.

  THE MARSHALLING IS NOT HERE EITHER.  A state object notifies on whatever
  thread changed it; the UI side subscribes through a bridge that hands the work
  to the main thread (see src\ui\lcl\uStateBridge.pas).  That is the ONE
  marshalling point the plan asks for -- the domain does not know a main thread
  exists. }
unit uDomainState;

{$I ..\tr4w.inc}

interface

uses
   Classes, SysUtils, SyncObjs;

type
   { A subscriber.  Deliberately Sender-less: a handler is registered per state
     object, so branching on who sent it is the thing this shape prevents --
     the same rule TTR4WEntryEvents follows for the entry fields. }
   TStateChanged = procedure of object;

   TDomainState = class(TObject)
   private
      FLock: TCriticalSection;
      FSubscribers: array of TStateChanged;
   protected
      { Take the lock around a read or a write of a field.  Every property
        below does; a state object is written by worker threads. }
      procedure Lock;
      procedure Unlock;

      { Tell everyone the state moved.  CALLED WITH THE LOCK RELEASED -- a
        subscriber that reads the state back would otherwise deadlock, and one
        that does real work would hold a lock across it. }
      procedure NotifyChanged;
   public
      constructor Create;
      destructor Destroy; override;

      procedure Subscribe(const aHandler: TStateChanged);
      procedure Unsubscribe(const aHandler: TStateChanged);
   end;

implementation

constructor TDomainState.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
end;

destructor TDomainState.Destroy;
begin
   FreeAndNil(FLock);
   inherited Destroy;
end;

procedure TDomainState.Lock;
begin
   FLock.Acquire;
end;

procedure TDomainState.Unlock;
begin
   FLock.Release;
end;

procedure TDomainState.Subscribe(const aHandler: TStateChanged);
var
   i: integer;
begin
   Lock;
   try
      // Idempotent: subscribing twice would notify twice, and a form that is
      // rebuilt would do exactly that.
      for i := Low(FSubscribers) to High(FSubscribers) do
         begin
         if (TMethod(FSubscribers[i]).Code = TMethod(aHandler).Code) and
            (TMethod(FSubscribers[i]).Data = TMethod(aHandler).Data)    then
            begin
            Exit;
            end;
         end;

      SetLength(FSubscribers, Length(FSubscribers) + 1);
      FSubscribers[High(FSubscribers)] := aHandler;
   finally
      Unlock;
   end;
end;

procedure TDomainState.Unsubscribe(const aHandler: TStateChanged);
var
   i, j: integer;
begin
   Lock;
   try
      for i := Low(FSubscribers) to High(FSubscribers) do
         begin
         if (TMethod(FSubscribers[i]).Code = TMethod(aHandler).Code) and
            (TMethod(FSubscribers[i]).Data = TMethod(aHandler).Data)    then
            begin
            for j := i to High(FSubscribers) - 1 do
               begin
               FSubscribers[j] := FSubscribers[j + 1];
               end;
            SetLength(FSubscribers, Length(FSubscribers) - 1);
            Exit;
            end;
         end;
   finally
      Unlock;
   end;
end;

procedure TDomainState.NotifyChanged;
var
   snapshot: array of TStateChanged;
   i: integer;
begin
   // COPIED UNDER THE LOCK, CALLED OUTSIDE IT.  A subscriber is free to read
   // this state, to unsubscribe, or to take its own lock; none of that is safe
   // while this one is held.
   Lock;
   try
      SetLength(snapshot, Length(FSubscribers));
      for i := Low(FSubscribers) to High(FSubscribers) do
         begin
         snapshot[i] := FSubscribers[i];
         end;
   finally
      Unlock;
   end;

   for i := Low(snapshot) to High(snapshot) do
      begin
      if Assigned(snapshot[i]) then
         begin
         snapshot[i];
         end;
      end;
end;

end.

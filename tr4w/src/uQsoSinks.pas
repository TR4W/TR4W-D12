unit uQsoSinks;
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
  THE THREE CONCRETE SINKS OF THE QSO DISPATCHER, in delivery order: UDP
  broadcast, external logger, HamScore.

  Each runs on the dispatcher thread (uQsoDispatcher) and each reads only what
  its owner makes thread-safe:

    UDP             the broadcaster's own configuration, swapped under its lock,
                    so a Preferences change applies to the next message.
    external logger the commands in the message; the logger's own sender
                    thread does the connecting, with its retry and backoff.
    HamScore        the body in the message; the uploader's own thread does the
                    HTTP, on its cycle, with its retry.

  The last two sinks only hand a finished value to a queue that already has a
  thread.  They are here so ONE place decides what leaves the program and in
  what order, not because they would have blocked.

  This unit is separate from uQsoDispatcher because it must name the external
  logger and HamScore, and uExternalLogger itself uses the dispatcher's types.
*)

interface

(* Adds the three sinks to QsoDispatcher.  Idempotent: a second call does
  nothing.  Called once at startup, and by a test that wants the real sinks. *)
procedure InstallQsoSinks;

implementation

uses
   SysUtils,
   uQsoDispatcher,
   uUDPBroadcaster,
   uHamScore,
   uExternalLogger,
   MainUnit;      // the externalLogger global

type
   TUDPQsoSink = class(TQsoSink)
   public
      function Name: string; override;
      function Wants(const aMessage: TQsoMessage): boolean; override;
      procedure Deliver(const aMessage: TQsoMessage); override;
   end;

   TExternalLoggerQsoSink = class(TQsoSink)
   public
      function Name: string; override;
      function Wants(const aMessage: TQsoMessage): boolean; override;
      procedure Deliver(const aMessage: TQsoMessage); override;
   end;

   THamScoreQsoSink = class(TQsoSink)
   public
      function Name: string; override;
      function Wants(const aMessage: TQsoMessage): boolean; override;
      procedure Deliver(const aMessage: TQsoMessage); override;
   end;

var
   gInstalled: boolean = False;

{ TUDPQsoSink }

function TUDPQsoSink.Name: string;
begin
   Result := 'UDP';
end;

function TUDPQsoSink.Wants(const aMessage: TQsoMessage): boolean;
begin
   // Whether the STREAM is on is the broadcaster's to say, and it says it in
   // SendNow, under its lock, against the configuration as it is NOW.
   Result := aMessage.UDPPayload <> '';
end;

procedure TUDPQsoSink.Deliver(const aMessage: TQsoMessage);
begin
   if aMessage.DirectPort > 0 then
      begin
      UDPBroadcaster.SendDirect(aMessage.DirectAddress, aMessage.DirectPort,
                                aMessage.UDPPayload);
      end
   else
      begin
      UDPBroadcaster.SendNow(aMessage.UDPStream, aMessage.UDPPayload);
      end;
end;

{ TExternalLoggerQsoSink }

function TExternalLoggerQsoSink.Name: string;
begin
   Result := 'ExternalLogger';
end;

function TExternalLoggerQsoSink.Wants(const aMessage: TQsoMessage): boolean;
begin
   // externalLogger is created once at startup and freed in tr4w_ShutDown,
   // after the dispatcher has been stopped.
   Result := (aMessage.ExtOp <> xoNone) and Assigned(externalLogger);
end;

procedure TExternalLoggerQsoSink.Deliver(const aMessage: TQsoMessage);
begin
   externalLogger.SubmitOp(aMessage.ExtOp, aMessage.ExtCommand1,
                           aMessage.ExtCommand2, aMessage.Description);
end;

{ THamScoreQsoSink }

function THamScoreQsoSink.Name: string;
begin
   Result := 'HamScore';
end;

function THamScoreQsoSink.Wants(const aMessage: TQsoMessage): boolean;
begin
   Result := (aMessage.HamOp <> hoNone) and (aMessage.HamBody <> '');
end;

procedure THamScoreQsoSink.Deliver(const aMessage: TQsoMessage);
begin
   HamScoreSubmit(aMessage.HamOp = hoDelete, aMessage.HamQSOID, aMessage.HamBody);
end;

procedure InstallQsoSinks;
begin
   if gInstalled then
      begin
      Exit;
      end;
   QsoDispatcher.AddSink(TUDPQsoSink.Create);
   QsoDispatcher.AddSink(TExternalLoggerQsoSink.Create);
   QsoDispatcher.AddSink(THamScoreQsoSink.Create);
   gInstalled := True;
end;

end.

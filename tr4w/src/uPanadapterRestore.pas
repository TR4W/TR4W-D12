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

{ REOPENING THE PANADAPTERS THAT WERE OPEN AT SHUTDOWN.

  ITS OWN UNIT, and not a corner of uRadioPanelForm, for two reasons.  The
  small one is that a helper class with an OnTimer handler inside a DESIGNED
  form's unit reads to Lint-FormEvents as an unwired form handler -- and that
  lint is right to be suspicious.  The real one is that this is not the radio
  panel's job: the panel is a window, this is a start-up policy that happens to
  call one routine the panel exports.

  WHAT IT IS NOT: it is not the layout save.  Where the windows are and whether
  they were open is written by uPanadapterForm, riding MainUnit's existing
  autosave.  This unit only READS that answer and acts on it. }
unit uPanadapterRestore;

{$I tr4w.inc}

interface

procedure StartPanadapterRestore;
procedure StopPanadapterRestore;

implementation

uses
   SysUtils,
   Forms,               { Application.QueueAsyncCall }
   ExtCtrls,            { TTimer -- the bounded start-up retry }
   DateUtils,           { IncSecond }
   MainUnit,            { logger }
   uRadioPanelForm,     { OpenPanadapterForSlot }
   uPanadapterForm;     { PanadapterWasOpen }

{ WHY A RETRY AND NOT A ONE-SHOT.  "Was it open last time" is answered from
  disk instantly; "can this radio stream spectrum yet" is not, because
  SpectrumAvailable stays False until the polling thread has connected and the
  K4 has answered.  On a cold start that is seconds away, and on a rig that is
  switched off it never arrives -- which is exactly why this expires. }
const
   PAN_RESTORE_INTERVAL_MS = 2000;
   PAN_RESTORE_WINDOW_SEC  = 60;

type
   TPanadapterRestore = class
      procedure RetryOpen(Sender: TObject);
      procedure FirstAttempt(Data: PtrInt);
   end;

var
   GPanRestoreTimer: TTimer = nil;
   GPanRestore: TPanadapterRestore = nil;
   { True while this slot is still owed a window. }
   GPanRestorePending: array[1..2] of boolean = (False, False);
   GPanRestoreDeadline: TDateTime = 0;

procedure StopPanadapterRestore;
begin
   if GPanRestoreTimer <> nil then
      begin
      GPanRestoreTimer.Enabled := False;
      end;
   FreeAndNil(GPanRestoreTimer);

   { Drop the queued first attempt before the object goes, or a program that
     exits before the loop idles leaves the LCL holding a method pointer into
     freed memory. }
   if GPanRestore <> nil then
      begin
      Application.RemoveAsyncCalls(GPanRestore);
      FreeAndNil(GPanRestore);
      end;
end;

procedure TPanadapterRestore.FirstAttempt(Data: PtrInt);
begin
   RetryOpen(nil);
end;

procedure TPanadapterRestore.RetryOpen(Sender: TObject);
var
   slot: integer;
   outstanding: integer;
begin
   outstanding := 0;

   for slot := Low(GPanRestorePending) to High(GPanRestorePending) do
      begin
      if not GPanRestorePending[slot] then
         begin
         Continue;
         end;

      if OpenPanadapterForSlot(slot) then
         begin
         GPanRestorePending[slot] := False;
         logger.Info('[Panadapter] reopened radio %d''s panadapter, as it was open at shutdown',
                     [slot]);
         end
      else
         begin
         Inc(outstanding);
         end;
      end;

   if outstanding = 0 then
      begin
      StopPanadapterRestore;
      Exit;
      end;

   { GIVE UP OUT LOUD.  A rig that is switched off is the ordinary case here,
     and a silent expiry is indistinguishable from a broken feature. }
   if Now > GPanRestoreDeadline then
      begin
      for slot := Low(GPanRestorePending) to High(GPanRestorePending) do
         begin
         if GPanRestorePending[slot] then
            begin
            logger.Info('[Panadapter] radio %d''s panadapter was open at shutdown, but that radio '
                        + 'has not offered a spectrum stream within %d s -- not reopening it',
                        [slot, PAN_RESTORE_WINDOW_SEC]);
            GPanRestorePending[slot] := False;
            end;
         end;
      StopPanadapterRestore;
      end;
end;

procedure StartPanadapterRestore;
var
   slot: integer;
   wanted: integer;
begin
   if GPanRestoreTimer <> nil then
      begin
      Exit;
      end;

   wanted := 0;
   for slot := Low(GPanRestorePending) to High(GPanRestorePending) do
      begin
      GPanRestorePending[slot] := PanadapterWasOpen(slot);
      if GPanRestorePending[slot] then
         begin
         Inc(wanted);
         end;
      end;

   if wanted = 0 then
      begin
      Exit;
      end;

   GPanRestoreDeadline := IncSecond(Now, PAN_RESTORE_WINDOW_SEC);

   GPanRestore := TPanadapterRestore.Create;
   GPanRestoreTimer := TTimer.Create(nil);
   GPanRestoreTimer.Interval := PAN_RESTORE_INTERVAL_MS;
   GPanRestoreTimer.OnTimer := GPanRestore.RetryOpen;
   GPanRestoreTimer.Enabled := True;

   { The first attempt without waiting a whole interval -- a radio that is
     already up should not cost the operator two seconds of empty screen.

     QUEUED, NOT CALLED.  This routine runs before Application.Run, and opening
     two panadapters here is ~130 ms of main thread that the main window spends
     unpainted.  Same rule as MainUnit's deferred tool-window restore: windows
     that are not the main window get created once the loop is running. }
   Application.QueueAsyncCall(GPanRestore.FirstAttempt, 0);
end;

end.

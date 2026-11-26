unit uUnattendedGuard;

(* THE BACKSTOP FOR --unattended (see uStartupArgs): no window that waits for an
  answer may open when nobody is there to answer it.

  ONE HOOK, NOT A TEST AT EACH DIALOG.  Application.ModalStarted is what the LCL
  calls for a modal form, a message box, a Windows task dialog and a file
  dialog, so a dialog added next year is covered without anybody remembering to.

  It cannot say WHICH question was asked -- the event carries no text -- so it
  writes the call stack.  Those are ADDRESSES in tr4w-early.log; the build's
  .dbg file resolves them to the routine that asked, as for a crash report. *)

{$IFDEF FPC}{$MODE Delphi}{$MODESWITCH UnicodeStrings}{$ENDIF}

interface

(* Call once, before anything that can open a window. *)
procedure InstallUnattendedGuard;

implementation

uses
   Classes, SysUtils, Forms,
   uCrashLog,
   VC;

type
   TUnattendedGuard = class
      procedure ModalBeginning(Sender: TObject);
   end;

var
   guard: TUnattendedGuard;

procedure TUnattendedGuard.ModalBeginning(Sender: TObject);
const
   MAX_FRAMES = 24;
var
   frames: array[0..MAX_FRAMES - 1] of CodePointer;
   count, i: integer;
begin
   EarlyTrace('[Unattended] a window that waits for an answer was about to '
              + 'open; ending the run. Called from:');
   count := CaptureBacktrace(1, MAX_FRAMES, @frames[0]);
   for i := 0 to count - 1 do
      begin
      EarlyTrace('[Unattended]   ' + string(BackTraceStrFunc(frames[i])));
      end;
   Halt(EXITCODE_UNATTENDED);
end;

procedure InstallUnattendedGuard;
begin
   if guard <> nil then
      begin
      Exit;
      end;
   guard := TUnattendedGuard.Create;
   Application.AddOnModalBeginHandler(guard.ModalBeginning);
end;

finalization
   (* NOT REMOVED FROM Application first: Interfaces' finalization, which frees
     Application, runs after this one, and nothing opens a window during it. *)
   FreeAndNil(guard);

end.

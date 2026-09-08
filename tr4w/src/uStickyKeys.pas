unit uStickyKeys;
{$I tr4w.inc}

(* STICKY KEYS, SUSPENDED FOR THE DURATION OF A RUN.  ny4i Issue 126.

  Windows switches Sticky Keys on when it sees five shift presses in a row.
  A contest operator produces that inside a minute, and the dialog steals the
  keyboard mid-QSO -- so TR4W saves the setting at startup, clears the two
  flags that trigger it, and puts the setting back on the way out.

  WHY THIS IS A UNIT AND NOT TWO CALL SITES.  It already was two call sites,
  in two different subsystems: the save lived in uProgramMain and the restore
  in trdos/logsubs2's ExitProgram, sharing a global declared in VC.pas.  The
  halves therefore drifted, in a way neither file showed on its own:

    - THE RESTORE RAN EVEN IF THE SAVE HAD FAILED.  Nothing checked
      SystemParametersInfo's result, so a failed SPI_GETSTICKYKEYS left the
      global zeroed and the exit path wrote those zeros back as if they were
      the operator's settings.  It is guarded here, and the save is the only
      thing that can arm the restore.
    - THE SAVE WAS GATED AND THE RESTORE WAS NOT, which is what surfaced this
      during the Windows-dependency sweep: VC.pas gates the global on
      {$IFDEF WINDOWS} but logsubs2 called SystemParametersInfo bare.

  Off Windows both routines are no-ops, deliberately and permanently: no other
  platform has the misfeature to defend against, so there is nothing to
  emulate.  Callers need no conditional -- that is the point of the unit. *)

interface

procedure SuspendStickyKeys;
(* Save the current setting and clear the flags that let a run of shift keys
   turn Sticky Keys on.  Call once, at startup. *)

procedure RestoreStickyKeys;
(* Put back exactly what SuspendStickyKeys saved.  Does nothing if the save
   never happened or failed.  Safe to call more than once. *)

implementation

uses
{$IFDEF WINDOWS}
   Windows,
{$ENDIF}
   SysUtils,
   Log4D;

var
   logger: TLogLogger;

{$IFDEF WINDOWS}
var
   (* The operator's setting, and whether we actually hold it.  Private to this
     unit -- it used to be VC.StickyKeysAtStartup, visible to the whole tree
     for the benefit of exactly two lines. *)
   SavedSettings:  STICKYKEYS;
   SavedIsValid:   boolean = False;
{$ENDIF}

procedure SuspendStickyKeys;
{$IFDEF WINDOWS}
var
   Suspended: STICKYKEYS;
{$ENDIF}
begin
{$IFDEF WINDOWS}
   if SavedIsValid then
      begin
      (* Already suspended.  Saving again would capture OUR OWN cleared flags
        as though they were the operator's, and the restore would then be a
        no-op that looks like it worked. *)
      Exit;
      end;

   SavedSettings.cbSize := SizeOf(STICKYKEYS);
   SavedIsValid := SystemParametersInfo(SPI_GETSTICKYKEYS,
                                        SizeOf(STICKYKEYS),
                                        @SavedSettings,
                                        0);
   if not SavedIsValid then
      begin
      logger.Warn('[StickyKeys] SPI_GETSTICKYKEYS failed (%d) -- ' +
                  'leaving the setting alone', [GetLastOSError]);
      Exit;
      end;

   Suspended.cbSize  := SavedSettings.cbSize;
   Suspended.dwFlags := SavedSettings.dwFlags and
                        not (SKF_STICKYKEYSON or SKF_HOTKEYACTIVE);
   if not SystemParametersInfo(SPI_SETSTICKYKEYS,
                               SizeOf(Suspended),
                               @Suspended,
                               0) then
      begin
      logger.Warn('[StickyKeys] SPI_SETSTICKYKEYS failed (%d)',
                  [GetLastOSError]);
      end;
{$ENDIF}
end;

procedure RestoreStickyKeys;
begin
{$IFDEF WINDOWS}
   if not SavedIsValid then
      begin
      Exit;
      end;

   if not SystemParametersInfo(SPI_SETSTICKYKEYS,
                               SizeOf(SavedSettings),
                               @SavedSettings,
                               0) then
      begin
      logger.Warn('[StickyKeys] restore failed (%d)', [GetLastOSError]);
      end;

   (* Restored -- so a second call has nothing to put back, and a later
     Suspend is free to take a fresh reading. *)
   SavedIsValid := False;
{$ENDIF}
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.StickyKeys');

end.

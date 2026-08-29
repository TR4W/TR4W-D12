unit uLegacyIniPrompt;
{$I ..\..\tr4w.inc}

{
  OFFER TO REMOVE tr4w.ini, ONCE, AFTER IT HAS STOPPED BEING USED.

  Every station setting lives in settings\tr4w.json now.  What remains of
  tr4w.ini is a file that is READ ONCE per installation, to carry an existing
  configuration into the store, and then never again -- see
  SeedMigratedCommandsFromIni, SeedBandPlanFromIni and
  SeedElementColorsFromGlobals.

  WHY ASK RATHER THAN JUST DELETE IT.  Deleting an operator's configuration file
  without asking is not ours to do, however unused it is: it is the only copy of
  what the station looked like before the migration, and a contest operator is
  entitled to keep it until they are satisfied.  NY4I asked for the prompt for
  exactly that reason (2026-08-21).

  WHY ASK AT ALL, rather than leaving it forever.  A file that looks like
  configuration but is ignored is a trap: the next person to debug this station
  will edit it, see no effect, and lose an hour.  That includes the operator
  themselves in six months.

  THE ANSWER IS RECORDED (TRadioConfigStore.KeepLegacyIni), so this is asked
  once.  A prompt that returns every start is not a choice.

  NO BACKUP COPY IS MADE, deliberately: "There should not be any backups of the
  ini or anything else. Only json should be used except for the contest.cfg"
  (NY4I).  Renaming it to .bak would recreate the same trap under a different
  extension.

  ORDER MATTERS.  This must run AFTER the seeding, or it would offer to delete a
  file whose contents have not been carried across yet; and after the /EXPORT
  early exit in tr4w.lpr, or a headless golden-corpus run would block on a
  modal dialog.
}

interface

// Ask once, and act on the answer.  Silent and immediate when there is nothing
// to do: no ini, or the operator already answered.
//
// TAKES A FILENAME AND OWNS ITS OWN STORE.  There is no long-lived store at
// startup -- uRadioConfigApply creates one, applies it and frees it -- so
// borrowing a reference would mean keeping one alive purely for this, and the
// only thing this needs from it is one boolean.
procedure OfferToRetireLegacyIni(const aStoreFileName: string);

implementation

uses
   SysUtils,
   Dialogs,
   Controls,
   uAppStrings,
   uRadioConfigStore,
   uIniRetireForm,    // the Yes/No + do-not-ask-again dialog
   uTR4WConfigFile,   // SaveConfig -- the ONE writer of tr4w.json
   VC,          // TR4W_INI_FILENAME
   MainUnit;    // logger

procedure OfferToRetireLegacyIni(const aStoreFileName: string);
var
   ini: string;
   err: string;
   store: TRadioConfigStore;
   dontAskAgain: boolean;
   remove: boolean;
begin
   ini := string(TR4W_INI_FILENAME);
   if not FileExists(ini) then
      begin
      Exit;
      end;

   // THE STORE MUST EXIST FIRST.  Offering to delete the old file before the
   // new one has ever been written would leave a station with neither if the
   // very next thing to happen were a crash.
   if not FileExists(aStoreFileName) then
      begin
      logger.Info('[LegacyIni] %s still present, but %s has not been written yet -- not offering',
                  [ini, aStoreFileName]);
      Exit;
      end;

   store := TRadioConfigStore.Create;
   try
      if not store.LoadFromFile(aStoreFileName, err) then
         begin
         // A store that will not load is a bigger problem than a stale ini, and
         // deleting the ini would remove the only other copy of the settings.
         logger.Warn('[LegacyIni] not offering: %s did not load -- %s',
                     [aStoreFileName, err]);
         Exit;
         end;

      if store.KeepLegacyIni then
         begin
         Exit;
         end;

      // TWO QUESTIONS, TWO CONTROLS.  This was a MessageDlg read as
      // `<> mrYes`, so No -- and the title-bar X with it -- recorded a
      // PERMANENT "never ask again", which is not what No means.  "Remove the
      // file?" and "should I stop asking?" are separate, and the second one is
      // a check box now (NY4I, 2026-08-23).
      remove := AskToRetireLegacyIni(Format(SIniRetirePrompt,
                                            [aStoreFileName, ini]),
                                     dontAskAgain);

      // THE CHECK BOX IS ANSWERED FIRST, AND INDEPENDENTLY OF THE BUTTON.  It
      // is its own question, so it is recorded whichever way the operator
      // answered the other one -- including alongside Yes.  That matters here
      // rather than being a nicety: the removal below can FAIL (a read-only
      // ini is exactly NY4I's case), and if the tick were only recorded on the
      // No path, an operator who ticked it and pressed Yes would be asked again
      // next start despite having said not to be.
      //
      // RE-READ, SET, WRITE.  The store was loaded before the dialog; saving
      // the whole object now would write back a snapshot taken before the
      // operator had a chance to change anything else, which is only safe
      // because nothing else runs while a modal dialog is up -- but the narrow
      // write is what makes that not need arguing about.
      if dontAskAgain then
         begin
         store.KeepLegacyIni := True;
         SaveConfig(aStoreFileName, store, nil, nil);
         logger.Info('[LegacyIni] operator asked not to be reminded about %s again',
                     [ini]);
         end;

      if not remove then
         begin
         logger.Info('[LegacyIni] operator left %s in place', [ini]);
         Exit;
         end;
   finally
      store.Free;
   end;

   try
      // DeleteFile returns a result rather than raising, but a read-only file
      // or a locked handle is worth reporting either way -- and reporting is
      // all that is needed, because nothing reads the file.
      if SysUtils.DeleteFile(ini) then
         begin
         logger.Info('[LegacyIni] removed %s', [ini]);
         ShowMessage(Format(SIniRetireRemoved, [ini]));
         end
      else
         begin
         err := SysErrorMessage(GetLastOSError);
         logger.Warn('[LegacyIni] could not remove %s -- %s', [ini, err]);
         ShowMessage(Format(SIniRetireFailed, [ini, err]));
         end;
   except
      on E: Exception do
         begin
         logger.Warn('[LegacyIni] could not remove %s -- %s', [ini, E.Message]);
         ShowMessage(Format(SIniRetireFailed, [ini, E.Message]));
         end;
   end;
end;

end.

unit uAppStrings;
{$I tr4w.inc}

{
  USER-FACING TEXT AS resourcestring -- the start of the I18N replacement.

  TR4W has translated its UI by COMPILING a different binary per language: a
  `TC_...` constant per string in src\lang\tr4w_consts_<LANG>.pas, selected by
  a LANG_xxx define.  Nine binaries, nine constant files that drift, and each
  one an ANSI file in its own codepage -- 1251 for Russian, 1250 for Czech and
  Serbian, 1252 for German -- which is why a blanket encoding conversion was
  wrong and why a file that loses its BOM silently corrupts.

  The replacement is `resourcestring` and ONE binary per platform (NY4I,
  2026-08-13).  Resource DLLs are out: they have no FMX/macOS/Linux equivalent.

  THIS UNIT IS THE FIRST STEP, and deliberately a small one.  New dialogs and
  message boxes declare their text here; nothing existing was converted, because
  a sweep of the whole TC_ table belongs with the translation work and not with
  a feature commit.  Do NOT add a TC_ constant for new UI text -- add it here.

  WHY resourcestring RATHER THAN const: the compiler places these in a
  resource string table, so a translation tool can enumerate and replace them
  without recompiling, and FPC/Lazarus already understand the format.  A plain
  const is invisible to all of that.

  NAMING: S<Area><Thing>.  No TC_ prefix -- that prefix means "lives in the
  per-language const files", and these deliberately do not.
}

interface

resourcestring
   SWRLSummary = 'WRL delivery: pending %d; sending %d; up to date %d; uncertain %d; failed %d. Reopen Preferences to refresh.';
   SWRLStatusUnavailable = 'WRL delivery status is unavailable for the current log.';
   SWRLDeliveryIssue = 'World Radio League delivery needs attention. %s. Local logging continues; check the TR4W log and WRL delivery records.';

   // PREFERENCES > EXTERNAL LOGGER -- the grid is the editor (issue 220).
   SLoggerGridOrder       = 'Order';
   SLoggerGridLogger      = 'Logger';
   SLoggerGridProvider    = 'Provider';
   SLoggerGridSend        = 'Send new QSOs';
   SLoggerGridYes         = 'Yes';
   SLoggerGridNo          = 'No';
   SLoggerGridNone        = 'No loggers configured';
   SLoggerGridAdd         = 'Add...';
   SLoggerGridEdit        = 'Edit...';
   SLoggerGridMoveUp      = 'Move up';
   SLoggerGridMoveDown    = 'Move down';
   SLoggerGridRemove      = 'Remove...';
   SLoggerGridRemoveAsk   = 'Remove logger definition? Pending deliveries stay in the contest log and will not be redirected to another definition.';
   // Resend QSOs and Open web site (issue 356), the grid's popup items.
   SLoggerGridOpenSite    = 'Open web site';
   SLoggerGridResend      = 'Resend QSOs...';
   SLoggerSiteRefused     = 'Not opened: "%s" is not an http or https web address.';
   SLoggerSiteOpenFailed  = 'The browser could not be started for %s.';
   (* %s is the logger's name. The two captions are the dialog's buttons. *)
   SLoggerResendBody      = 'Resend QSOs of this contest to %s only.' + #10#10 +
      'Not yet delivered: queues the QSOs this logger was never sent (for example those logged while Send new QSOs was off) and any it refused. QSOs already delivered, waiting, or of unknown outcome are left alone.' + #10#10 +
      'Resend all: also sends delivered QSOs again as updates of the same remote contact (not for Cloudlog / Wavelog or AC Log, which have no update call). A QSO of unknown outcome is never resent.';
   SLoggerResendUndelivered = 'Not yet delivered';
   SLoggerResendAll       = 'Resend all';
   SLoggerResendAllAsk    = 'Resend all QSOs to %s? A contact that is already at the destination by another route (another definition of this logger, a manual import) cannot be recognised and may appear twice. Delivered contacts are sent again as updates, which uses the service''s quota.';
   (* %s name; then queued, new, sent again, delivered, waiting, unknown outcome, other stations. *)
   SLoggerResendDone      = '%s: queued %d QSOs (%d new, %d sent again). Left alone: %d delivered, %d waiting, %d of unknown outcome that need review, %d logged by other stations.';
   SLoggerResendRefused   = 'Nothing was queued for %s: %s';
   SLoggerResendWhyNotRunning = 'it is not running. Save Preferences, and restart TR4W if it was added or its connection settings changed since start.';
   SLoggerResendWhyNotActive = 'Send new QSOs is off for it. Switch it on and save Preferences first.';
   SLoggerResendWhyPaused = 'its delivery is paused after a capture failure (see tr4w.log).';
   SLoggerResendWhySetup  = 'its account or logbook is not set up.';
   SLoggerResendWhyUnsupported = 'it has no delivery queue to resend into.';
   SLoggerResendWhyNoLog  = 'no writable contest log is open.';
   SLoggerResendWhyFailed = 'the log could not be updated (see tr4w.log). Nothing was changed.';
   // RESYNC (the Resync button on the logger's row). %s is the logger's name.
   // Resync is the Resend dialog (one implementation); the column heading and the
   // sentences appended to its summary are new.
   SLoggerResyncColumn    = 'Resync';
   // %d: how many QSOs could not be made into this logger's contact.
   SLoggerResendNotDeliverable = '%d QSOs cannot be sent in their present form (see Edit QSO > External loggers for each reason); correct them and resync again.';
   SLoggerResendResumed   = 'Delivery, which was paused after a failure, is resumed.';
   // Appended to the Resend dialog's question, so the operator knows before answering.
   SLoggerResendDuplicateNote = 'A QSO that already has a delivery row at this logger is never created a second time. If this logger''s delivery was paused after a failure, answering Not yet delivered or Resend all also resumes it.';
   SLoggerResyncWhySwitchedOff = 'Resync is not available: this logger is switched off. Switch it on and save Preferences first.';
   (* CREATE LOGBOOK (issue 358): the WRL logger row's popup item and its dialogs.
      %s is the logger's name, the logbook's name, or the logbook's id as marked. *)
   SLoggerGridCreateLogbook = 'Create logbook...';
   SWRLCreateCaption      = 'Create World Radio League logbook';
   SWRLCreatePrompt       = 'Name of the new logbook (up to 100 characters). It is made on the World Radio League web site for the account this API key belongs to:';
   SWRLCreateReplaceAsk   = '%s already has a logbook chosen. Create a new logbook and use it instead? Contacts already queued for the old logbook are not moved.';
   SWRLCreateKeyMissing   = 'This logger has no API key available. Enter the key in the logger''s editor (unlock the password vault if it is locked) first.';
   SWRLCreateBusy         = 'A logbook is already being created for a logger. Wait for it to finish.';
   (* logbook name, logbook id, logger name. *)
   SWRLCreateDone         = 'Created logbook "%s" (id %s) at World Radio League and chose it for %s. Save Preferences to keep it. The new logbook is used after you restart TR4W: a running logger keeps the settings it started with.';
   SWRLCreateFailed       = 'The logbook was not created: %s';
   SWRLCreateUncertain    = 'World Radio League did not confirm the logbook, so it may have been created. Look at your logbooks on the World Radio League web site (or use Refresh in the logger''s editor) before trying again, so you do not make a second one.';
   SWRLWhyNameRequired    = 'the name is empty.';
   (* %d is 100. *)
   SWRLWhyNameTooLong     = 'the name is longer than %d characters.';
   SWRLWhyKey             = 'World Radio League did not accept the API key (it is missing, wrong or revoked). Check the key in the logger''s editor.';
   SWRLWhyMembership      = 'the key was refused because the account needs a current World Radio League membership.';
   SWRLWhyScope           = 'the key is not allowed to create logbooks. Make a key that may write logbooks.';
   SWRLWhyIp              = 'the key is restricted to other IP addresses than this computer''s.';
   SWRLWhyConflict        = 'a logbook with that name may already exist, or World Radio League treated the request as a conflict. Choose the existing logbook in the logger''s editor, or use another name.';
   (* field name, WRL's message. *)
   SWRLWhyValidationField = 'World Radio League rejected the %s: %s';
   SWRLWhyValidation      = 'World Radio League rejected the request: %s';
   SWRLWhyRate            = 'too many requests just now. Wait a minute and try again.';
   (* WRL's error code. *)
   SWRLWhyDown            = 'the World Radio League service is not available right now (%s). Try again later.';
   SWRLWhyOther           = 'the request failed (%s).';
   (* World Radio League's request id, for a support request. *)
   SWRLRequestId          = '(request id %s)';
   SLoggerGridHint        = 'Right-click a logger to edit it, change Send new QSOs, move or remove it; drag the Order cell to reorder. Active loggers send in Order. Save Preferences to apply Enabled and Order now; a new logger, or changed connection settings, applies after a restart.';
   SLoggerGridChanged     = 'Logger definitions changed. Save Preferences to apply Enabled and Order now; connection changes apply after a restart.';
   (* After a save (issue 233). %d is how many loggers still wait for a restart. *)
   SLoggerGridSavedRestart = 'Saved. Enabled and Order are in effect. %d logger(s) with new or changed connection settings apply after you restart TR4W.';
   (* THE ENABLED CHECKBOX AND THE CONNECTION STATE COLUMN (issue 226). The
      state text names what the running delivery worker last did; the colour
      only repeats it. %d is a count, %s a fixed delivery code. *)
   SLoggerGridEnabled     = 'Enabled';
   SLoggerGridState       = 'Connection';
   SLoggerStateDisabled   = 'Disabled';
   SLoggerStateRestart    = 'Restart TR4W to apply';
   SLoggerStateApplyOnSave = 'Applies on Save';
   SLoggerStateIdle       = 'Idle';
   SLoggerStateSending    = 'Sending (%d pending)';
   SLoggerStateRetrying   = 'Retrying: %s';
   SLoggerStatePaused     = 'Paused: %s';
   SLoggerStateFailed     = 'Failed: %s';
   SLoggerStateCounts     = '%s (%d uncertain, %d failed)';

   // EDIT QSO -- where each external logger stands with the QSO: a button
   // on Edit QSO (shown only when the QSO has a delivery row) opens a
   // read-only window with one row per destination -- the logger's name, its
   // state (the words below) and when it last answered, in UTC.
   SEditQSODeliveriesButton  = 'External loggers...';
   SDeliveryWindowTitle      = 'External loggers for this QSO';
   SDeliveryColLogger        = 'Logger';
   SDeliveryColStatus        = 'Status';
   SDeliveryColLastSent      = 'Last sent (UTC)';
   SDeliveryClose            = 'Close';
   SEditQSODeliveryNeverSent = 'Not sent yet';
   SEditQSODeliveryPending   = 'pending';
   SEditQSODeliverySending   = 'sending';
   SEditQSODeliverySynced    = 'up to date';
   SEditQSODeliveryUncertain = 'uncertain';
   SEditQSODeliveryFailed    = 'failed';
   SEditQSODeliveryFailedWithCode = 'failed (%s)';
   // A destination that gives no reply (DXKeeper, AC Log): the command was
   // written to it, which is all that is known.
   SEditQSODeliveryHandedOff = 'handed off (not confirmed)';
   // A delivery that failed in a way that is tried again.
   SEditQSODeliveryRetryingWithCode = 'retrying (%s)';
   // A QSO that could not be made into this logger's contact (a required field
   // is missing): the row is failed, and the reason follows the colon.
   SEditQSODeliveryFailedBecause = 'failed: %s';
   SLoggerWhyNoFrequency = 'no frequency';
   SLoggerWhyNoMode = 'no mode';
   SLoggerWhyNoTime = 'no date or time';
   SLoggerWhyNoStationCall = 'no station call sign';
   SLoggerWhyNotDeliverable = 'a required field is missing';
   // One line on the quick-command panel, never a dialog. %s: logger name, call sign, reason.
   SLoggerQsoNotSent = '%s: QSO %s not sent (%s). See Edit QSO > External loggers.';
   // The same, once more than one QSO was held back within the minute.
   // %s: logger name; %d: how many; %s: the latest call sign; %s: the reason.
   SLoggerQsosNotSent = '%s: %d QSOs not sent, the latest %s (%s). See Edit QSO > External loggers.';
   // A configured logger with no delivery row for this QSO (the Edit QSO window
   // lists every configured logger, so an empty list never reads as "never tried").
   SDeliveryNotSentPaused = 'not sent: paused (review needed)';
   SDeliveryNotSentOff = 'not sent: switched off';
   SDeliveryNotSentRestart = 'not sent: not running (restart TR4W)';
   SDeliveryNotSentSetup = 'not sent: setup incomplete';
   SDeliveryNotSentNotQueued = 'not sent: not queued for this QSO';
   { ---------------------------------------------- retiring the legacy ini - }

   // Shown ONCE, after the settings have been carried into settings\tr4w.json.
   // The wording states what has already happened before it asks for anything:
   // an operator who is told "may I delete your configuration" reasonably says
   // no, and an operator who is told "your settings have already been copied,
   // this file is no longer read" can answer the question that is actually
   // being asked.
   { The single-instance warning's title.  It used to be tr4w_ClassName -- the
     WINDOW CLASS NAME -- which happens to read as 'TR4W' and so looked
     deliberate.  A caption is user-facing text and belongs here. }
   SAlreadyRunningTitle = 'TR4W';

   (* TR4W COULD NOT OPEN tr4w.log, AND KEPT RUNNING.  The first %s is the
     reason as the RTL gives it, which names the file; the second is the
     folder TR4W writes its own files to this run.

     REWORDED 2026-11-20 (issue 165, NY4I's Program Files test): "its log
     file" reads, in a CONTEST LOGGER, as the contest log -- the operator's
     QSOs. tr4w.log is the troubleshooting log and nothing else, so the
     message says so first. It does NOT promise the contest log is safe: if
     this folder refuses files the contest log may be refused too, and that
     failure is reported on its own, so the message says exactly that.

     A NEW KEY, not new text under the old SLogFileUnavailable: the message
     also gained a second argument (the folder), and an old translation
     applied to it would silently drop that folder. Under a new key the old
     translations simply stop applying and the English shows until the
     catalogues are merged; the old entry is left in the .po files for the
     i18n merge to retire. *)
   SDiagnosticLogUnavailable =
      'TR4W could not open its diagnostic log, tr4w.log.' + sLineBreak + sLineBreak +
      '%s' + sLineBreak + sLineBreak +
      'This is the troubleshooting log TR4W keeps for problem reports. It is ' +
      'NOT your contest log: your QSOs are kept in a separate contest log ' +
      'file, and TR4W tells you separately if it cannot save to that.' +
      sLineBreak + sLineBreak +
      'TR4W writes its own files in:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'TR4W will keep running and keep trying to open tr4w.log. Until it can, ' +
      'no troubleshooting details from this session are recorded.';

   (* SHOWN ONCE: the program folder refuses new files (an install under
     C:\Program Files run as a standard user), so TR4W writes under the
     user's application data instead (issue 165, 2026-11-20). %0:s is the
     program folder, %1:s the folder TR4W writes to now. *)
   SWritableRootMoved =
      'TR4W cannot save files in the folder it is installed in:' + sLineBreak +
      '    %0:s' + sLineBreak + sLineBreak +
      'So your settings, contest logs, backups and the troubleshooting log ' +
      '(tr4w.log) are kept here instead:' + sLineBreak +
      '    %1:s' + sLineBreak + sLineBreak +
      'Nothing is lost. To keep everything in one folder, install TR4W in a ' +
      'folder you can write to, such as C:\tr4w.';
   (* SHOWN ONCE, INSTEAD OF SWritableRootMoved, when TR4W is installed
     under Program Files: it then writes under the user's application data
     whoever starts it, including Run as administrator, so the folder may
     well be writable and the text must not say otherwise (issue 165,
     2026-11-20). %0:s is the program folder, %1:s the folder TR4W writes
     to now. *)
   SWritableRootMovedProgramFiles =
      'TR4W is installed under Program Files, which Windows protects:' + sLineBreak +
      '    %0:s' + sLineBreak + sLineBreak +
      'So your settings, contest logs, backups and the troubleshooting log ' +
      '(tr4w.log) are kept here instead, however TR4W is started (including ' +
      'Run as administrator):' + sLineBreak +
      '    %1:s' + sLineBreak + sLineBreak +
      'Nothing is lost. To keep everything in one folder, install TR4W ' +
      'outside Program Files, in a folder you can write to such as C:\tr4w.';
   (* Added to the notice when settings were carried across from the
     install folder. %s is the file names. *)
   SWritableRootCopied =
      'Copied from the install folder''s settings: %s';
   (* Added when contest logs (.db files) are in the install folder: TR4W
     cannot open them there for writing. *)
   SWritableRootOldLogs =
      'Contest logs already in the install folder were left where they are. ' +
      'To keep logging in one, copy it (with any file of the same name ' +
      'ending -wal or -shm) into the folder above.';

   (* A SETTINGS SAVE THE DISK REFUSED -- shown once per run; every failure
     is logged. %0:s is the file, %1:s the system's reason. It replaced the
     LCL's raw "risk data corruption / kill the program" dialog. *)
   SSettingsNotSaved =
      'TR4W could not save your settings to:' + sLineBreak +
      '    %0:s' + sLineBreak + sLineBreak +
      '%1:s' + sLineBreak + sLineBreak +
      'The settings file on disk was not changed. TR4W keeps running with the ' +
      'settings as you have them now, but changes made in this session will be ' +
      'lost when TR4W closes unless a later save works.' + sLineBreak + sLineBreak +
      'Check that the folder exists, that you can write to it, and that the ' +
      'disk is not full. This message is shown once per session; later ' +
      'failures are written to tr4w.log.';

   SIniRetireTitle = 'Old settings file';

   SIniRetirePrompt =
      'Your settings have been moved to:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'The old file is no longer read:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'Remove it now?' + sLineBreak + sLineBreak +
      'The file is ignored either way.';

   { THE SECOND QUESTION, ASKED SEPARATELY.  It used to be a sentence in the
     prompt above saying that No would also stop TR4W asking -- so an operator
     who was simply not ready to delete a file today gave a permanent answer
     without meaning to.  Two questions, two controls. }
   SIniRetireDontAsk = 'Do not ask me about this file again';

   SIniRetireRemoved  = 'Removed %s.';
   SIniRetireFailed   = 'Could not remove %s -- %s.' + sLineBreak +
                        'It is ignored regardless, so nothing is broken.';

   { ------------------------------- the FIRST start after an upgrade ------- }

   (* OFFERED ONCE, AND ONLY WHEN THERE IS AN OLD ini AND NO settings FILE AT
     ALL -- see uLegacyConversionCheck for why that condition cannot fire
     twice.  NY4I asked for this on 2026-09-20: "if you do see an INI file but
     no json file, should you immediately ask them to run the convert program?
     Warn them if they continue, they could overwrite some saved settings in
     the new program?"

     THE RISK SENTENCE IS THE POINT OF THE TEXT, AND IT IS NOT "you could lose
     your settings" -- that would be false and an operator would rightly stop
     trusting the rest of it.  Continuing loses nothing: TR4W writes a file of
     defaults, and converting later overwrites those defaults with the 4.x
     values, which is exactly what was wanted.  The real hazard is an ORDER:
     continue now, configure the station by hand, convert afterwards -- and
     the old file overwrites the work just done.  So the text says that, and
     says it as the reason to convert first rather than as a threat. *)
   SFirstRunConvertTitle = 'TR4W -- settings from an earlier version';

   SFirstRunConvertPrompt =
      'TR4W has found settings from an earlier version:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'and it has not written its own settings file yet:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'TR4W can carry that old configuration across now. The conversion ' +
      'lists what it would change and asks before writing anything, so you ' +
      'can look first and still say no.' + sLineBreak + sLineBreak +
      'You do not have to do it now. Nothing is lost by continuing: TR4W ' +
      'starts with its defaults, your old file is left untouched, and ' +
      'converting later simply replaces those defaults with your old values.' +
      sLineBreak + sLineBreak +
      'What is worth knowing is the ORDER. If you continue now and then set ' +
      'TR4W up by hand, converting afterwards overwrites that work with the ' +
      'values from the old file. Converting first avoids the question.';

   SFirstRunConvertNow  = 'Convert now';
   SFirstRunConvertSkip = 'Continue without converting';

   { The conversion program is installed beside TR4W. If it is not there this
     is almost always a copied executable rather than an installation -- the
     same shape as the missing-OpenSSL case above -- so the message says where
     it should be instead of only that it is absent. }
   SFirstRunConvertMissing =
      'TR4W could not find the conversion program:' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'It is installed beside TR4W itself. TR4W will start with its ' +
      'defaults, and your old settings file is left untouched.';

   (* SHOWN WHEN THE CONVERSION RAN AND THE SETTINGS FILE STILL IS NOT THERE.
     Two different things reach this and the operator need not be told which:
     they answered No to the converter's own prompt, or the converter had no
     terminal to ask in and therefore wrote nothing on purpose.  Either way
     the honest statement is that nothing was converted, and the way to do it
     later is the same. *)
   SFirstRunConvertNothingDone =
      'Nothing was converted.' + sLineBreak + sLineBreak +
      'TR4W will start with its defaults and your old settings file is ' +
      'untouched. You can convert at any time by running' + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'from a command prompt in that folder. Converting then replaces ' +
      'whatever you have configured in the meantime with the old values.';

   { ------------------------------------------------- downloads that fail --- }

   { WHY THIS NAMES THE INSTALLER.  A missing OpenSSL pair almost always means
     tr4w.exe was copied somewhere on its own -- the installer ships
     libeay32.dll and ssleay32.dll beside it (buildull.nsi). The operator
     cannot deduce that from "download failed", so ASK THE QUESTION (NY4I,
     2026-08-26: "They should be asked if they ran the INSTALLER"). }
   SDownloadNoSSLLibrary =
      'the OpenSSL libraries could not be loaded.' + sLineBreak + sLineBreak +
      'libeay32.dll and ssleay32.dll must sit in the same folder as tr4w.exe. ' +
      'The TR4W installer puts them there -- was this folder installed, or is ' +
      'it a copy of tr4w.exe on its own?';

   { The reason is the POINT of this dialog. It used to advise checking the
     network and the folder permissions -- neither of which was ever the
     problem in the one case anybody hit, and the real reason was sitting in
     the log the whole time. }
   SCtyDownloadFailedTitle = 'CTY.DAT';

   { The refusal paths. Rare and close to programmer error, but they reach the
     same dialog, so they are text like any other -- not literals. }
   SDownloadCouldNotStart = 'the download was refused before it began (bad URL).';

   { REFUSED, NOT FAILED, and the distinction is the message. The operator
     asked for verified TLS and the program could not set it up -- usually a
     missing CA bundle. It used to connect anyway and mention it only in the
     log, which made a verification setting look like a secure default while
     behaving like the old unverified-everywhere state.

     The %s carries the exact setup failure, and the sentence names the way
     out, because the operator's real choice here is "fix the bundle" or
     "decide you do not want verification" and neither is guessable from
     "download failed". }
   SDownloadCannotVerify =
      'the server''s certificate could not be verified (%s).' + sLineBreak + sLineBreak +
      'The request was REFUSED rather than sent unverified. Turn off ' +
      'Preferences > Network > verify server certificates if you want to ' +
      'proceed without checking.';
   SDownloadRenameFailed  = 'the file downloaded but could not be saved under its final name.';

   (* A POST that is answered with a redirect is NEVER followed (issue 255): the
     program does not know whether the server acted on it, and re-sending could
     post twice. It is unusual, and the project wants to hear about it. %d is
     the status, the first %s the address the server named, the second where
     to report it. *)
   SPostRedirected =
      'the server answered the upload with a redirect (status %d) to %s. ' +
      'TR4W does not follow a redirect on an upload, and the upload was not repeated. ' +
      'This is unexpected: please file an issue at %s and include this message.';
   (* Club Log, World Radio League and Cloudlog uploads repeat a POST at a
     redirect target (issue 255 follow-up), but only when that is safe; this is
     the report when it is not. %d is the status, the first %s the address the
     server named, the second the reason (one of the strings below). *)
   SPostRepostRefused =
      'the server answered the upload with a redirect (status %d) to %s and it was not repeated: %s';
   SRepostSeeOther =
      'status 303 means the upload was handled and the result is at that address; TR4W does not send it again.';
   SRepostTooMany = 'the server redirected the upload more than %d times.';
   SRepostNoLocation = 'the redirect named no address.';
   SRepostBadLocation = 'the redirect address is not usable.';
   SRepostDowngrade = 'the redirect leads from https to plain http, which is never followed.';
   SRepostOtherHost =
      'the redirect leads to a different host or port, and the upload carries a key that only the original server may see.';
   { The operator notice for a missing CA bundle (issue 221). A background
     upload cannot show a dialog of its own, so the delivery worker hands this
     text to its owner, which shows it once. %0:s is the list of places looked,
     %1:s the service whose uploads are paused. }
   SCaBundleMissingNotice =
      'The certificate file cacert.pem was not found (looked in: %0:s); ' +
      'uploads to %1:s are paused until it is available.';

   { HamScore's status line while no CA bundle is found (issue 221). Nothing is
     sent and the QSOs are kept. %0:s is the places looked, %1:d the QSOs held. }
   SHamScoreNoBundleStatus =
      'Not sent: cacert.pem not found (looked in: %0:s) -- %1:d QSO(s) retained';

   (* Shown INSTEAD of an OS error code when the file is simply absent -- see
     TF.UnableToFindFileMessage for why an errno is the wrong thing to print
     in that case. *)
   SFileNotFoundThere = 'TR4W could not find this file:';

   (* Added to that message when the file's FOLDER does not exist either. *)
   SIncompleteInstallHint =
      'The folder is missing too, so this copy of TR4W is probably not completely installed.' +
      sLineBreak + sLineBreak +
      'Start TR4W from the folder the installer put it in (it holds CTY.DAT, TRMASTER.DTA and a dom folder), or run the installer again.';

   (* Shown once at startup when the program's own data folders look absent.
     %0:s is the folder it looked in, %1:s the missing names, one per line. *)
   SInstallIncompleteStartup =
      'This copy of TR4W looks incompletely installed.' +
      sLineBreak + sLineBreak +
      'Not found in %0:s:' + sLineBreak + '%1:s' +
      sLineBreak + sLineBreak +
      'Start TR4W from the folder the installer put it in (it holds CTY.DAT, TRMASTER.DTA and a dom folder), or run the installer again.' +
      sLineBreak + sLineBreak +
      'TR4W will still start, but contests that need these files will not work properly.';

   (* WHICH SETTING BUILT THAT PATH. A wrong path with no attribution sends an
     operator looking at the disk when the answer is in the configuration --
     NY4I, Linux Mint, 2026-09-20. The single %s is the command name, e.g.
     DOMESTIC FILENAME. *)
   SFileNameCameFromSetting =
      'The name came from the %s setting for this contest.';

   (* AN INCLUDE FILE LINE IN A .dom THAT COULD NOT BE FOLLOWED -- issue
     #138. The setting is the wrong attribution here: DOMESTIC FILENAME named
     the file that holds the line, not the file the line names. So the
     message names both files and the line. First %s the .dom holding the
     line, second the line as written, third every path that was tried. *)
   SDomIncludeNotRead =
      'The domestic file %s names a file TR4W could not read, on the line "%s".' +
      sLineBreak + sLineBreak +
      'It was looked for here:' + sLineBreak + '%s' + sLineBreak + sLineBreak +
      'The rest of the file was loaded; the entries in the missing file were not.';
   (* First %s the .dom, %d the nesting limit, second %s the line. *)
   SDomIncludeTooDeep =
      'The domestic file %s nests INCLUDE FILE more than %d deep, on the line "%s". ' +
      'That line was not followed: the files probably include one another in a circle.';

   { ------------------------------------------- the contest readiness check -

     ONE LINE PER GAP, AND EACH SAYS WHAT TR4W WILL DO INSTEAD. "MY COUNTRY is
     empty" on its own does not tell an operator that their exchange is about
     to change shape; NY4I lost a bench session to precisely that gap
     (2026-09-20). See uContestReadiness. }

   SReadinessHeading =
      'This contest is set up, but TR4W is missing information it needs:';

   SReadinessFooter =
      'Set these in Preferences > Station, then restart TR4W: they are read ' +
      'once when the contest is set up, so changing them now will not ' +
      'change this contest.';

   SReadinessMyCallMissing =
      'MY CALL is empty. TR4W cannot work out your country, continent or ' +
      'zone without it, and nothing that depends on them will be right.';

   SReadinessMyCountryMissing =
      'MY COUNTRY is empty. It is normally worked out from MY CALL through ' +
      'CTY.DAT. Until it has a value TR4W treats this station as DX -- in ' +
      'ARRL DX that means it will ask every station for a state or province ' +
      'and refuse a power such as K or 100.';

   SReadinessMyStateMissing =
      'MY STATE is empty and this contest sends your state, province or ' +
      'section. TR4W will send a serial number instead.';

   SReadinessMyZoneMissing =
      'MY ZONE is empty and this contest sends your zone.';

   (* A contest that exchanges the year first licensed (TReceivedYearKind) --
     MY LICENSE YEAR, issue 298. It sends nothing for the year while empty. *)
   SReadinessMyLicenseYearMissing =
      'MY LICENSE YEAR is empty and this contest sends the year you were ' +
      'first licensed.';

   SReadinessMyGridMissing =
      'MY GRID is empty and this contest sends your grid square.';

   SReadinessDomesticFileMissing =
      'This contest scores domestic multipliers from a .DOM file and none ' +
      'is named, so no domestic multiplier will be counted.';

   { WHICH SETTING PUT THE EXCHANGE IN THIS MODE -- shown beside a rejected
     exchange, where the operator is looking. }

   SExchangeModeFromEmptyCountry =
      'This contest is asking for a state, province or section because MY ' +
      'COUNTRY is empty.';

   SExchangeModeFromCountry =
      'This contest is asking for a state, province or section because MY ' +
      'COUNTRY is %s.';

   { THE SAME THING IN A FEW WORDS. QuickDisplayError writes into a
     main-window element, not a dialog, so the sentences above will not fit. }

   SExchangeModeBriefEmptyCountry = '(MY COUNTRY is empty)';
   SExchangeModeBriefCountry      = '(MY COUNTRY = %s)';

   SCtyDownloadFailed =
      'Could not download CTY.DAT to:' + sLineBreak + sLineBreak +
      '    %s' + sLineBreak + sLineBreak +
      'Reason: %s' + sLineBreak + sLineBreak +
      'tr4w.log records the full detail.';

   { ------------------------------------------------------ the contest log - }

   { THE QSO DID NOT REACH THE DISK, said where the operator is looking.

     The store already reports a failure once, with the reason, in a dialog.
     That is not enough on its own: the contact that matters is the one in
     front of the operator RIGHT NOW, and a dialog dismissed an hour ago says
     nothing about this one. So this line appears per QSO, and it says what to
     do rather than only what happened -- the contact is still on screen and
     still workable. }
   SQsoNotLogged =
      'NOT LOGGED -- the contest log would not accept this QSO. ' +
      'See tr4w.log. Do not clear the entry.';

   { ------------------------------------------------ multi-op networking - }

   // NAMES THE SETTING, because that is what the operator has to change.
   // "Connection refused" would send him to look at the network cable; the
   // problem is a letter in his own configuration, and two stations cannot
   // share one -- the whole protocol indexes station status BY that letter.
   SNetComputerIDInUse =
      'Computer ID %s is already in use by another station on this network.' +
      sLineBreak + sLineBreak +
      'Change COMPUTER ID to a letter no other station is using, then ' +
      'reconnect.';

   (* SContestNotOnMultiOp WAS HERE and is gone (2026-10-27): network protocol
     2 carries every contest, so no door refuses one any more. *)

   (* THE SERVER SPEAKS ANOTHER NETWORK PROTOCOL THAN THIS TR4W (protocol 2,
     2026-10-27). Two messages, because the way out differs: the server is the
     older end, or this program is. The first %d is the protocol the server
     speaks, the second the one this TR4W speaks. They say what to update and
     on which computer; the operator has nothing else to act on. *)
   (* THE MULTI-OP SERVER CANNOT BE REACHED, as ONE short line for the main
     window's notice area. Shown once, at startup; the reason (Tailcat tunnel
     or not) is in tr4w.log, never here. *)
   SNetServerNotAvailable = 'Connection to the TR4WServer is not available';

   SNetServerProtocolOlder =
      'The multi-op server speaks network protocol %d, but this TR4W needs ' +
      'protocol %d. Update TR4WServer on the server computer, then choose ' +
      'Connect on the Net menu.';

   SNetServerProtocolNewer =
      'The multi-op server speaks network protocol %d, which is newer than ' +
      'the protocol %d this TR4W speaks. Update TR4W on this computer, then ' +
      'choose Connect on the Net menu.';

   (* THE SERVER HUNG UP ON THE FIRST MESSAGE WITHOUT ANSWERING. A server from
     before protocol 2 does exactly that, and it cannot say so. %d is the
     protocol this TR4W speaks. *)
   SNetNoHelloAnswer =
      'The multi-op server closed the connection without answering. It is ' +
      'probably older than this TR4W (which speaks network protocol %d). ' +
      'Update TR4WServer on the server computer, then choose Connect on the ' +
      'Net menu.';

   (* THE NET MENU'S LINK COMMANDS (2026-10-27). The multi-op link belongs to the
     program, not to the Network window, so the operator is offered its verbs.
     SNetMenuShowWindow brings the station list forward; it does not connect. *)
   SNetMenuConnect    = 'Connect';
   SNetMenuDisconnect = 'Disconnect';
   SNetMenuReconnect  = 'Reconnect';
   SNetMenuShowWindow = 'Show Network window';

   (* THE NET MENU ROW THAT OPENS THE SYNCHRONIZE WINDOW, AND THAT WINDOW'S TITLE
     (2026-10-27, reworded 2026-10-28). They replace RC_SYNLOG ("Compare and
     synchronize logs") and RC_SYNLOG2 ("Synchronize log"): the window compares
     nothing and replaces nothing. It works in BOTH directions: it ADDS the
     server's QSOs this log is missing and SENDS the QSOs this log has that the
     server lacks (a server that lost its log). The 2026-10-27 English ("Add
     missing QSOs from the server...", "Server log") described half of it; the
     keys are unchanged and their msgstr were still empty in every catalogue.
     NEW KEYS rather than new English under the old ones, because the catalogues
     translate by key and ignore the msgid, so a reworded RC_SYNLOG would go on
     showing the old meaning in every reviewed language. The row keeps its
     keystroke (Ctrl+Alt+S, uAccelerators, by menu_getserverlog). *)
   SNetMenuServerLog = 'Synchronize with the server...';
   SServerLogTitle   = 'Synchronize with the server';
   (* PEERS MUST BE ON THE SAME CONTEST -- Q110, NY4I 2026-10-18. A QSO from
     another station on a different contest is refused and this is the
     notice, raised once per station and contest per link. %s: the station
     letter, its contest, this station's contest. *)
   SPeerOnAnotherContest =
      'Station %s is on %s, this station is on %s -- its QSOs are NOT being ' +
      'logged here. All stations must run the same contest.';

   (* A PEER ON ANOTHER BUILD -- issue 120 item 4, NY4I 2026-11-19: "Clients
     should all be same version as server or report it". Said once per station
     and version per link; nothing is refused. %s: the station letter, its
     version, this station's version. *)
   SPeerOnAnotherVersion =
      'Station %s runs TR4W %s, this station runs %s. All stations should ' +
      'run the same version.';

   (* CATCHING UP AFTER A LINK THAT WAS DOWN (Phase 1, C5, 2026-10-27). Said once
     per link, when the QSOs logged and the edits made while this station was
     disconnected have been handed to the server. %d: how many QSOs, then how
     many edits. *)
   SNetResent =
      'Resent to the server what was logged while disconnected: %d QSO(s), ' +
      '%d edit(s).';

   (* A QSO FROM ANOTHER STATION THIS LOG COULD NOT STORE (issue 347, 2026-11-22).
     Said ONCE per link, the first time; every one is in tr4w.log. The server
     holds the QSO, so a catch-up or Net > Synchronize adds it once this log
     can be written. *)
   SPeerQsoNotSaved =
      'A QSO from another station could NOT be saved to this log. It is not ' +
      'lost if the server has it: the next catch-up from the server, or Net > ' +
      'Synchronize, adds it once this log can be written. Further refusals ' +
      'are in tr4w.log.';

   (* CATCHING UP FROM THE SERVER'S LOG (Phase 1, C6, 2026-10-27) -- the other
     half of the above: a station that comes up in the middle of a contest asks
     the server for what the others logged meanwhile. Nothing in this log is
     changed or removed; QSOs it lacks are added. *)

   (* Said when they have been added. %d: how many. *)
   SNetCaughtUp =
      'Caught up from the server: %d QSO(s) added.';

   (* Said after the line above when the server's log also held QSOs for another
     contest, which are never added. %d: how many. *)
   SCatchUpSkipped =
      '%d QSO(s) on the server belong to another contest and were not added.';

   (* The question, when SERVER AUTO SYNCHRONIZE LOG ON CONNECT is off. %d: how
     many QSOs the server holds that this log does not. *)
   SCatchUpAsk =
      'The server holds %d QSO(s) that this log does not have. Add them to ' +
      'this log now? Nothing already in this log is changed or removed, and a ' +
      'backup of the log is taken first.';

   (* The server's log could not be read. %s: why. *)
   SCatchUpFetchFailed =
      'Could not read the server''s log to catch up: %s';

   (* The QSOs were NOT added. %s: why. *)
   SCatchUpMergeFailed =
      'Nothing was added to the log: %s';

   (* The Synchronize window's button: before the server's log has been read, and
     once it has. %d: how many QSOs it would add. *)
   SServerLogAdd =
      'Add missing QSOs';

   SServerLogAddMissing =
      'Add %d missing QSO(s)';

   (* RESTOCKING A SERVER THAT LOST ITS LOG (2026-10-28) -- the other direction of
     the catch-up: this log holds QSOs the server does not. *)

   (* Said when they have been posted. %d: how many. *)
   SNetPushedToServer =
      'Sent to the server: %d QSO(s) it did not have.';

   (* The same, when QSOs logged while disconnected were ALSO resent on this
     link (NY4I, 2026-11-22: the notice said 5 when 25 went). %d: the total,
     how many were logged while disconnected, how many the server did not have. *)
   SNetPushedToServerTotal =
      'Sent to the server: %d QSO(s) -- %d logged while disconnected, ' +
      '%d it did not have.';

   (* The question when only this log has something to give and SERVER AUTO
     SYNCHRONIZE LOG ON CONNECT is off. %d: how many QSOs. *)
   SPushAsk =
      'The server lacks %d QSO(s) of yours. Send them to the server now? ' +
      'Nothing in this log is changed, and the server ignores any QSO it ' +
      'already holds.';

   (* The ONE question when both directions apply. %d: the server's QSOs this log
     lacks, then this log's QSOs the server lacks. *)
   SSyncAskBoth =
      'The server holds %d QSO(s) this log lacks and lacks %d of yours. Add ' +
      'the first to this log and send the second to the server now? Nothing ' +
      'already in this log is changed or removed, and a backup of the log is ' +
      'taken first.';

   (* The Synchronize window's second button: before the server's log has been
     read, and once it has. %d: how many QSOs it would send. *)
   SServerLogSend =
      'Send QSOs to the server';

   SServerLogSendCount =
      'Send %d QSO(s) to the server';

   { --------------------------------------------------- verification checks - }

   (* Tools -> Run Verification Checks.  The window title names the thing an
     operator is asking about, not the mechanism. *)
   SVerifyTitle        = 'Verification checks';
   SVerifyRun          = '&Run checks';
   SVerifyClose        = '&Close';
   SVerifyColumnCheck  = 'Check';
   SVerifyColumnResult = 'Result';
   SVerifyPassed       = 'Passed';
   SVerifyFailed       = 'FAILED';

   (* %d is how many checks are about to run.  Shown before the work starts,
     because an integrity check walks every page of the contest log and the
     window must not simply freeze in silence. *)
   SVerifyRunning      = 'Running %d check(s)...';

   (* %d is the number that ran. *)
   SVerifyAllPassed    = 'All %d check(s) passed.';

   (* THE FAILURE COUNT COMES FIRST, because it is the number being looked
     for.  %d of %d. *)
   SVerifySomeFailed   = '%d of %d check(s) FAILED. Select a row for details.';

   { --------------------------------------------------- the file manager - }

   (* "Open log directory", AND THE FILE-VIEW WINDOW'S Explore BUTTON, WHEN
     NOTHING OPENED.

     NY4I, testing 5.0.15 on his Mac: "on the mac version, open log directory
     does not work".  It did not, and it also did not SAY so -- the launcher
     it used is Windows-only and declines elsewhere with a log line nobody is
     reading.  A menu item that does nothing and reports nothing is
     indistinguishable from a broken menu.

     %s IS THE PATH, and it is in the message because the operator's next
     question is always "which folder?", and because a stale path and a
     desktop with no file manager look identical without it. *)
   SCouldNotShowInFileManager =
      'TR4W could not open this location in your file manager:' + sLineBreak +
      sLineBreak + '%s' + sLineBreak + sLineBreak +
      'Check that it still exists.  tr4w.log records what was tried.';

   (* ------------------------------------ refused exchanges (M5b, 7.10) - *)

   (* SWEEPSTAKES WITHOUT A PRECEDENCE. NY4I, 2026-10-02: "A sweepstakes
     entry should not have been logged without a precedence." Shown where an
     improper section is shown -- the main window's one-line notice -- so it
     is a few words, and it names the letters that are legal. *)
   SExchangeNoPrecedence = 'Missing precedence (Q A B U M S)';

   (* SWEEPSTAKES WITH A SERIAL THAT CANNOT BE TOLD FROM THE CHECK -- NY4I,
     2026-11-04: "If the exchange is ambiguous, it is ok to tell the user and
     ask them to put serial number and precedence together. Give an example
     such as 'Ambiguous exchange - Enter 43M or 30M to resolve...' using the
     actual ambiguous information to build the message." Each %s is one of
     the two typed numbers joined to the precedence, in the order typed. *)
   SExchangeAmbiguousSerial = 'Ambiguous exchange - enter %s or %s to resolve';

   (* A SWEEPSTAKES WORD THE CALL CORRECTION WOULD TAKE AS THE CALL -- NY4I,
     2026-11-04: "if ambiguous since a99ct is an edge case, we can ask".
     The first %s is the word as typed ('A99CT'), the second the same
     exchange spelled so it cannot be read as a call ('99A CT'). *)
   SExchangeCallOrExchange =
      'Ambiguous entry - %s may be a callsign or an exchange. For the exchange, enter %s; for the call, type it in the call window';

   (* A SWEEPSTAKES CHECK THAT IS NOT TWO DIGITS -- NY4I, 2026-11-04: "check
     will always be two digits"; in 'A99CT 5' "the lone 5 would have to be a
     mal-sent check". %s is the number as typed. *)
   SExchangeCheckNotTwoDigits = 'Check must be two digits (%s)';

   (* A SWEEPSTAKES EXCHANGE WITH NO CHECK, OR NO SECTION -- issue #174, NY4I's
     bench of 2026-11-04: 'A99 32' (no section) and 'A99CT' (no check) were
     refused with no message at all. Shown only when the entry was already
     refused and no reason above applies; a section that is present but not
     in the contest's file is a different refusal and is not this one. *)
   SExchangeNoCheck = 'Missing check (two digits)';
   SExchangeNoSection = 'Missing section';

   (* A SERIAL-AND-NAME EXCHANGE WITH NO NAME (CW Open and the other
     LOGSTUFF.ProcessQSONumberAndNameExchange contests). '123' alone was
     refused with no message, so Enter appeared to do nothing. A missing
     serial says TC_NOQSONUMBERFOUND, as the serial-and-QTH parser does. *)
   SExchangeNoNameFound = 'No name found!!';

   (* THE EUROPEAN HF CHAMPIONSHIP'S AND KVP'S LICENSE YEAR
     (LOGSTUFF.ProcessRSTAndLicenceYearExchange, 2026-11-11). A lone '599'
     said 'Improper zone number!!' -- these contests have no zone. "No year"
     is an empty entry or a report alone; anything else that is not one or two
     digits after an optional report is an improper year. "License" as the
     New Contest row (SNewContestLicenseYearLabel) and the sponsor spell it. *)
   SExchangeNoLicenseYear = 'No license year found!!';
   SExchangeImproperLicenseYear = 'Improper license year!!';

   (* A QSO PARTY'S OUT-OF-STATE STATION WORKING ANOTHER OUT-OF-STATE ONE.
     NY4I, 2026-10-02: "It's not valid for a fl station to work an Idaho or
     VE station in the NC QSO party", "we should refuse to log it and show an
     error like we would with an invalid county".  %s is the host state. *)
   SExchangeOutOfStateWorksHostOnly = 'Out of state: work %s stations only';

   (* A COUNTY LINE OF THE IN7QPNE COMPOSITE WHOSE COUNTIES ARE NOT ALL OF ONE
     PARTY -- issue 85. NY4I, 2026-11-22: "a rover cannot operate from across
     a state line for two counties" (of two parties). %s and %s are the first
     county and the first one that is not in its party, as typed. *)
   SExchangeCountyLineOneParty = 'County line %s/%s: the counties must be in one QSO party';

   (* A WORD OF AN RST-AND-GRID EXCHANGE THAT IS NEITHER -- Q115, NY4I
     2026-10-18. The parser used to drop such a word silently, so '599 FN3'
     logged a QSO with no grid. %s is the word as typed. *)
   SExchangeNotAGridOrReport = '%s is not a grid square or a signal report';

   (* A WORD IN THE RS(T)'S PLACE THAT THE MODE DOES NOT TAKE AS ONE -- issue
     325, the RSGB RoPoCo's postcode parser
     (LOGSTUFF.ProcessRSTAndPostalCodeExchange). '699 HA1 1TA' logged a report
     of 699 and 'HA1 1TA CT' the default report. %s is the word as typed. *)
   SExchangeNotASignalReport = '%s is not a signal report';

   (* THE ALL JA'S TWO REFUSALS (LOGSTUFF.ProcessRSTAllJAPrefectureAndPrecedenceExchange,
     2026-11-24). NY4I's bench: '101 H' and '02 H' were refused with no
     message at all. The numbers are uContestAllJA.ALLJA_PREFECTURE_PATTERN's;
     the letters ALLJA_POWER_CLASS_PATTERN's. *)
   SExchangeAllJAPrefecture = 'Prefecture must be 02-48 or 101-114';
   SExchangeAllJAPower = 'Power must be H, M, L or P';

   (* THE RSGB RoPoCo's ENTRY WITH NO POSTCODE IN IT -- review M6, 2026-11-16
     (LOGSTUFF.ProcessRSTAndPostalCodeExchange). Every legal entry carries the
     postcode; a report or a number alone ('5', '599') logged a QSO with a
     blank QTH. *)
   SExchangeNoPostcode = 'No postcode in the exchange';

   (* A GRID CONTEST'S EXCHANGE WITH NO GRID IN IT -- Q115, NY4I 2026-10-18:
     "The contest class should be stating what is required." Shown when the
     class requires the grid and only a signal report was typed. *)
   SExchangeGridRequired = 'Grid square required';

   (* THE COMBINED IN7QPNE PARTY'S NEW CONTEST PROMPT -- Q87, NY4I
     2026-10-14. The shared prompt names the party's area twice, and this
     party's area is four areas, so it printed the token 'IN7QPNE' twice. *)
   SNewContestIN7QPNECountyOrState =
      'Enter your county if you are in Indiana, the 7th call area, New ' +
      'England or Delaware. Enter your state, Canadian Province or "DX" ' +
      'if outside all four:';

   (* IN7QPNE REFUSED FOR A STATION INSIDE ONE OF ITS FOUR PARTIES -- Q104,
     NY4I 2026-10-16: an in-state station uses its own party, and a 7th-area
     station the 7QP, never its single state's party. Shown in the New
     Contest dialog's comment while OK stays disabled. The first %s is the
     MY STATE as typed, the second the party's contest name (e.g. "7th Call
     Area QSO Party"). *)
   SNewContestIN7QPNEInsideAParty =
      'IN7QPNE is for stations outside Indiana, the 7th call area, New ' +
      'England and Delaware. From %s, choose the %s instead.';

   (* THE ONTARIO QSO PARTY'S NEW CONTEST PROMPT -- #127, NY4I 2026-10-26:
     "Its own province prompt". The shared prompt reads "Enter your county if
     you are in ON state", and an Ontario entrant's MY STATE is its OQP
     county code: one who types ON is set up OUTSIDE Ontario, silently. A DX
     entrant states nothing and sends its own country prefix (the party
     base's SentLocation). *)
   SNewContestOntarioQPCountyOrLocation =
      'Enter your Ontario county code (e.g. TOR) if you are in Ontario. ' +
      'Enter your state or Canadian province if outside Ontario; leave it ' +
      'empty if you are DX (your country prefix is sent):';

   (* THE QUEBEC QSO PARTY'S NEW CONTEST PROMPT -- #128, NY4I 2026-10-26: "A
     translatable region prompt replaces the US 'county in state' wording".
     The shared prompt reads "Enter your county if you are in QC state", and
     a Quebec entrant's MY STATE is its administrative region code (MTL,
     QUE, ...): one who types QC is set up OUTSIDE Quebec, silently. A DX
     entrant states nothing and sends "DX" ("province, US state or DX for
     other entities"). *)
   SNewContestQuebecQPRegionOrLocation =
      'Enter your Quebec administrative region code (e.g. MTL) if you are in ' +
      'Quebec. Enter your state or Canadian province if outside Quebec; leave ' +
      'it empty if you are DX (DX is sent):';

   (* A QSO PARTY'S "I AM IN <AREA>" CHOICE -- issue 217 (NY4I, 2026-11-05:
     the Florida QSO Party's notice asked a Florida station for its county
     under a MY STATE label). The box is TC_IAMIN; these are the row's two
     labels and the notice for each side of it. %s is the party's area as
     the contest names it (FL, 7th area). The labels are the words an
     operator reads -- the command queued is MY STATE on both sides. *)
   SNewContestHostAreaCountyLabel = 'MY COUNTY';
   SNewContestHostAreaStateLabel = 'MY STATE';

   (* THE LICENCE-YEAR ROW'S LABEL -- the European HF Championship and KVP
     (NY4I, 2026-11-11: their prompt asks for the year of the first licence,
     and the row beside it read MY ZONE, a D7 artifact). The year has been
     its own setting since issue 298, so the label IS the command queued, MY
     LICENSE YEAR; the label mechanism stays for the rows that still differ
     (TNewContestPrompt.RowLabel). *)
   SNewContestLicenseYearLabel = 'MY LICENSE YEAR';

   (* THE QUESTION PREFERENCES ASKS WHEN THE STATION'S LICENSE YEAR CHANGES
     WHILE THE OPEN CONTEST SENDS THE YEAR -- issue 300 (uLicenseYearChange is
     the rule). TWO answers since log schema 8 (NY4I, 2026-11-13: a logged QSO
     stores the year it sent); the three-button dialog's body and its "this
     contest and its existing QSOs" button were retired with it. The body's
     %0:s is the new station year, %1:s the contest's name, %2:s the year it
     sends now; SLicenseYearNone stands in for an empty year. Buttons:
     SLicenseYearScopeAlsoContest and SLicenseYearScopeStationOnly, the default
     for Enter and Escape. *)
   SLicenseYearScopeTitle = 'License year';
   SLicenseYearScopeAlsoContest = 'Also this contest';
   SLicenseYearScopeStationOnly = 'Station default only';
   SLicenseYearNone = '(none)';
   SLicenseYearScopeBodyStored =
      'The station''s default license year is now %0:s.' + sLineBreak +
      sLineBreak +
      '%1:s sends the license year, and sends %2:s now.' + sLineBreak +
      sLineBreak +
      'Should this contest send the new year too?' + sLineBreak +
      sLineBreak +
      'QSOs already logged keep the year they sent.';

   (* ASKED AFTER "Also this contest" WHEN LOGGED QSOs SENT THE OLD YEAR --
     the correction, default No (NY4I, 2026-11-13: a mistaken year is
     corrected by editing the QSO; this is the same correction for all of
     them at once). %0:d is how many, %1:s the old year, %2:s the new one. *)
   SLicenseYearCorrectTitle = 'Correct logged QSOs?';
   SLicenseYearCorrectBody =
      '%0:d QSO(s) already logged in this contest sent the license year %1:s.' +
      sLineBreak + sLineBreak +
      'Change them to %2:s?' + sLineBreak + sLineBreak +
      'Answer Yes only if %1:s was a mistake. A QSO logged with %1:s on the ' +
      'air sent %1:s, and its log should say so.';

   (* THE SAME TWO QUESTIONS FOR ANY STATION VALUE THE OPEN CONTEST USES --
     schema 9 phase 2 (2026-11-17; uStationFactChange is the rule). Asked
     ONCE per Save, listing every value that changed; when the only one is
     the license year, the license-year text above is asked instead. The
     buttons are SLicenseYearScopeAlsoContest and SLicenseYearScopeStationOnly
     (the default for Enter and Escape); the correction is Yes/No, default
     No.

     SStationScopeLine is one line of the list: %0:s the value's name
     (StationFactCaption), %1:s the new station default, %2:s what the
     contest uses now (SLicenseYearNone for none). SStationScopeBody: %0:s
     the lines, %1:s the contest's name.

     SStationCorrectLine: %0:s the name, %1:d how many logged QSOs, %2:s the
     old value, %3:s the new one. SStationCorrectBody: %0:s the lines. *)
   SStationScopeTitle = 'Station values';
   SStationScopeLine = '%0:s: %1:s (this contest: %2:s)';
   SStationScopeBody =
      'You changed the station''s default:' + sLineBreak +
      sLineBreak +
      '%0:s' + sLineBreak +
      sLineBreak +
      '%1:s uses these. Should this contest use the new values too?' +
      sLineBreak + sLineBreak +
      'QSOs already logged keep what they sent.';
   (* APPENDED TO BOTH SCOPE QUESTIONS (the list's and the license year's):
     the Station page shows the contest's own value where it states one, so
     "Station default only" puts that value back in the box -- said before
     it happens, not discovered after. *)
   SStationScopeStationOnlyNote =
      '"Station default only" keeps this contest''s own value, and the page ' +
      'shows it again.';
   (* THE NOTE ON THE STATION PAGE while a value it shows is the open
     contest's and differs from the station's default (NY4I's bench,
     2026-11-17: the page showed the station's B while the contest sent U).
     %0:s the contest's name, %1:s the station defaults, each an
     SStationContestNoteItem (%0:s the value's name, %1:s the default,
     SLicenseYearNone for none) joined by '; '. *)
   SStationContestNote =
      'Shown as %0:s uses them: this contest states its own value for some ' +
      'of these. Station defaults: %1:s.';
   SStationContestNoteItem = '%0:s %1:s';
   SStationCorrectLine = '%0:s: %1:d QSO(s) sent %2:s, now %3:s';
   SStationCorrectBody =
      'QSOs already logged in this contest sent the old values:' + sLineBreak +
      sLineBreak +
      '%0:s' + sLineBreak +
      sLineBreak +
      'Change them to the new values?' + sLineBreak + sLineBreak +
      'Answer Yes only if the old values were a mistake. A QSO sent what it ' +
      'sent on the air, and its log should say so.';

   (* WHY A STATION FIELD'S TEXT IS NOT THAT FIELD'S SHAPE (2026-11-16) --
     uStationFieldCheck.StationFieldProblem's answers, shown by Preferences >
     Station when the field loses focus and listed at Save. The line above
     each names the setting and the text, so these carry no %s. *)
   SStationFieldGrid =
      'A grid square is two letters A to R and two digits, optionally ' +
      'followed by two letters: EL88 or EL88PA.';
   SStationFieldZone = 'A CQ zone is a number from 1 to 40.';
   SStationFieldState =
      'Two letters must be a US state, DC, a US territory or a Canadian ' +
      'province or territory. A county, grid or other QTH may be longer.';
   SStationFieldItuZone =
      'An ITU zone is a number from 1 to 90, or 0 to use the zone CTY.DAT gives.';
   SStationFieldSection =
      'This is not an ARRL or RAC section. A station outside the US and ' +
      'Canada enters DX.';
   SStationFieldCountry =
      'This is not a CTY.DAT country prefix. The United States is K.';
   SStationFieldPark =
      'A park reference is two letters, a hyphen and four or five digits: ' +
      'US-1234. Separate several parks with commas.';
   SStationFieldIota =
      'An IOTA reference is two letters, a hyphen and three digits: NA-001.';
   SStationFieldFDClass =
      'A Field Day class is the number of transmitters and one letter: 2A, ' +
      'or 2H for Winter Field Day.';
   SStationFieldCheck =
      'The check is two digits, the last two of the year first licensed: 85.';
   SStationFieldPrec = 'The precedence is one letter: Q, A, B, U, M or S.';
   SStationFieldFOCNumber = 'The FOC number is digits only.';
   SStationFieldPrefecture =
      'A prefecture is a JARL number of up to three digits, or a two-letter code.';
   SStationFieldPowerClass = 'The power class is one letter: H, M, L or P.';
   SStationFieldLicenseYear =
      'The license year is up to four digits: 1985, 85, or a number of years.';
   (* The line under the Station fields when a save is refused because a field
     is still wrong: %s is that field's caption and its reason. Nothing on the
     Station page is written until every field is right. *)
   SStationPageNotSaved = 'Station settings not saved. %s';

   (* THE CWT'S QTH-OR-MEMBER-NUMBER ROW'S LABEL (2026-11-11): the prompt asks
     for a QTH or a CWops member number, and the row beside it read MY STATE.
     What is typed is kept in MY STATE and the command queued is MY STATE;
     this is only what the operator reads (TNewContestPrompt.RowLabel). Kept
     to the width of CATEGORY-TRANSMITTER, the longest label the same
     160-pixel column already shows. *)
   SNewContestQTHOrMemberLabel = 'MY QTH OR MEMBER NO';

   (* THE CLUB MEMBERSHIP-NUMBER ROW'S LABEL (issue 51): PCC and Arktika
     Spring ask a club member for its number, and the row read MY STATE. The
     number is still kept in MY STATE and queued as MY STATE; this is only
     what the operator reads (TNewContestPrompt.RowLabel). *)
   SNewContestMemberNumberLabel = 'MY MEMBER NO';

   (* THE NAME-AND-QTH PROMPT WITHOUT A MEMBER NUMBER (issue 290,
     2026-11-12): the Locust QSO Party and the NCCC Sprint showed the CWT's
     TC_ENTERYOURNAMEANDQTH, which ends 'or member number', and neither
     exchanges one. LQP 2015 rules (K6VVA, archived): "Operator NAME ... and
     QTH (U.S. Mainland State, Canadian Province, KH6 (HI), KL7 (AK) or KP2
     (VI) / KP4 (PR) or "DX" for non W/K/VE North American Countries)".
     NCCC Sprint rules (ncccsprint.com): "Exchange: Serial Number, Name,
     QTH". The CWT keeps TC_ENTERYOURNAMEANDQTH. *)
   SNewContestEnterNameAndQTH =
      'Enter your name and QTH (US state, Canadian Province or DX country):';

   (* THE ALL JA'S POWER CLASS PROMPT (NY4I, 2026-11-23). *)
   SNewContestEnterPowerClass =
      'Enter your power class (H, M, L or P):';
   (* A STARTUP FIELD WHOSE VALUE ITS CONTEST'S PATTERN REFUSES
     (uNewContest; TNewContestPrompt.Pattern): %s the row's label. *)
   SNewContestFieldValueRefused =
      'The value of %s is not one this contest accepts.';

   SNewContestHostAreaInsideNotice =
      'You are in %s: choose your county from the list.';
   (* THE HAWAII QSO PARTY'S PLACES ARE DISTRICTS, NOT COUNTIES -- #118, NY4I
     2026-11-17: "The New Contest prompt must say district". The row label
     and the inside notice the party states (TNewContestHostArea.PlaceLabel,
     .InsideNotice), and its prompt. %s is the area. *)
   SNewContestHostAreaDistrictLabel = 'MY DISTRICT';
   SNewContestHostAreaInsideDistrictNotice =
      'You are in %s: choose your district from the list.';
   SNewContestHawaiiQPDistrictOrLocation =
      'Enter your Hawaii district (e.g. HON) if you are in Hawaii. Enter your ' +
      'state or Canadian province if outside Hawaii, or DX:';
   (* THE CANADIAN PRAIRIES QSO PARTY'S PROMPT -- issue 117, 2026-11-18. Its
     places are federal electoral districts in three provinces; the row label
     and inside notice are the district texts above. *)
   SNewContestCPQPDistrictOrLocation =
      'Enter your federal electoral district (e.g. AIR) if you are in Alberta, ' +
      'Saskatchewan or Manitoba. Enter your state or Canadian province if ' +
      'outside the prairies, or DX:';
   (* THE ATLANTIC CANADA QSO PARTY'S PROMPT -- issue 116, 2026-11-18. Its
     places are counties (NL: divisions) in four provinces, each sent as a
     five-letter province + county code. *)
   SNewContestACQPCountyOrLocation =
      'Enter your five-letter county or division code (e.g. NSHRM) if you are ' +
      'in New Brunswick, Nova Scotia, Prince Edward Island or Newfoundland and ' +
      'Labrador. Enter your state or Canadian province if outside Atlantic ' +
      'Canada, or DX:';
   SNewContestHostAreaOutsideNotice =
      'You are outside %0:s: enter your US state or Canadian province ' +
      '(two letters, e.g. GA or ON), or DX. Tick the box if you are in %0:s.';
   (* An outside entry that names a place inside the area -- one of its
     counties, or the host state itself. %0:s is the entry, %1:s the area. *)
   SNewContestHostAreaEntryIsInside =
      '%0:s is inside %1:s: tick the box and choose your county from the list.';
   (* An outside entry that is no state, province or DX. %s is the entry. *)
   SNewContestHostAreaEntryNotAState =
      '%s is not a US state, a Canadian province or DX. Enter the two-letter ' +
      'code, e.g. GA or ON, or DX.';
   (* A PARTY WHOSE OUTSIDE STATIONS SEND THEIR ARRL OR RAC SECTION
     (TNewContestHostArea.OutsideTakesSection -- the Pennsylvania QSO Party,
     NY4I 2026-11-20): the row's label, its notice (%0:s the area) and the
     refusal of an entry that is no section (%s the entry). *)
   SNewContestHostAreaSectionLabel = 'MY SECTION';
   SNewContestHostAreaOutsideSectionNotice =
      'You are outside %0:s: enter your ARRL or RAC section (e.g. WCF or ' +
      'ONE), or DX. Tick the box if you are in %0:s.';
   SNewContestHostAreaEntryNotASection =
      '%s is not an ARRL or RAC section or DX. Enter your section, e.g. WCF ' +
      'or ONE, or DX.';

   (* MY CALL AND THE "I AM IN ..." BOX DISAGREE -- issue 167, asked once at
     OK. %0:s is the box's region (North America, Canada), %1:s MY CALL,
     %2:s the country the country file puts that call in. Yes creates the
     contest as entered; No goes back to the New Contest window. *)
   SNewContestIAmInCheckTitle = 'Check your location';
   SNewContestIAmInTickedOutside =
      'You ticked "I am in %0:s", but your callsign %1:s is in %2:s.' + #10#10 +
      'Create the contest as entered? Choose No to go back and change it.';
   SNewContestIAmInClearedInside =
      'You did not tick "I am in %0:s", but your callsign %1:s is in %2:s.' + #10#10 +
      'Create the contest as entered? Choose No to go back and change it.';

   (* THE BOX THAT NAMES WHAT IS SENT, NOT A PLACE -- issue 167, NY4I
     2026-11-19: "I agree a new caption for these contests. A KP4 operator
     in North America can use their KP4 call ... You could ask to confirm
     the choice." For the contests whose box is a list of countries that
     send a state or province (ARRL 10, ARRL 160, the RTTY Roundup, CQ 160,
     CQ WW RTTY), where "I am in North America" told a KP4 or XE entrant the
     wrong thing. The exchange is what decides (NY4I: "The exchange is what
     triggers the question"), so the caption names it and no country: which
     countries send one is each contest's list, and the question at OK names
     the call's country. SHORT: the box is 180 pixels wide in the designed
     form. The & is the box's accelerator, as in TC_IAMIN. *)
   SNewContestBoxSendsStateOrProvince =
      '&I send a state or province';
   SNewContestBoxSendsARRLOrRACSection =
      '&I send an ARRL/RAC section';
   (* THE QUESTION FOR THAT BOX, asked once at OK. %0:s is the box's caption
     as shown (without the &), %1:s MY CALL, %2:s the country the country
     file puts that call in. Yes creates the contest as entered; No goes back
     to the New Contest window. Nothing is refused: a call can be operated
     from somewhere its country file does not say. *)
   SNewContestBoxTickedOutside =
      'You ticked "%0:s", but your callsign %1:s is in %2:s, and stations ' +
      'there do not send that in this contest.' + #10#10 +
      'If you are operating from a place that does, choose Yes. ' +
      'Choose No to go back and change it.';
   SNewContestBoxClearedInside =
      'You did not tick "%0:s", but your callsign %1:s is in %2:s, and ' +
      'stations there send that in this contest.' + #10#10 +
      'If you are operating from somewhere else, choose Yes. ' +
      'Choose No to go back and change it.';

   (* --------------------------------------------- the contest UI (M9b) - *)

   (* AN INACTIVE CONTEST'S LINE IN THE NEW CONTEST DROP-DOWN. NY4I,
     2026-10-02: "inactive contests go at the bottom of the drop down". Since
     Q59 (2026-10-19) they are listed only when "Show inactive contests" is
     ticked, and cannot be chosen for a new contest; the mark says why. %s is
     the contest's display name. *)
   SContestInactive = '%s (inactive)';

   (* THE TOTALS GRID'S MULTIPLIER ROW WHEN THE MULTIPLIER IS EACH DIFFERENT
     CALLSIGN WORKED -- issue 277 (2026-11-11): the CWOps CW Open's rule,
     "each different call sign is a multiplier the first time it is worked in
     that session", where the row read 'Prefixes'. Short: it shares the grid's
     left column with 'Prefixes' and 'Dom Mults'. *)
   STotalsCallsignMults = 'Calls';

   (* THE TOTALS GRID'S MULTIPLIER ROW WHEN THE MULTIPLIER IS EACH GRID
     SQUARE WORKED -- the South Dakota QSO Party's digital grids (issue 129,
     2026-11-18), kept on the prefix sheet, where the row read 'Prefixes'.
     Short, as 'Calls' is. *)
   STotalsGridMults = 'Grids';

   (* THE TOTALS GRID'S MULTIPLIER ROW WHEN THE PREFIX SHEET HOLDS PROVINCES --
     the Atlantic Canada QSO Party's in-region province per band and mode
     (issue 116, 2026-11-18), where the row read 'Prefixes'. *)
   STotalsProvinceMults = 'Provinces';

   (* THE TOTALS GRID'S MULTIPLIER ROW WHEN THE PREFIX SHEET HOLDS CLUB
     STATIONS -- the Vermont QSO Party's approved club stations (issue 270,
     2026-11-19), keyed on the club's call, where the row read 'Prefixes'. *)
   STotalsClubStationMults = 'Clubs';

   (* ONE LINE OF THE SCORE'S HINT, PER PART OF A SCORE -- issue 86 (NY4I,
     2026-11-15): IN7QPNE's four parties, each as its own class scores it.
     %0:s the part (a contest's name), %1:d QSOs, %2:d QSO points, %3:d
     multipliers, %4:d its score. *)
   SScorePartHint = '%0:s: %1:d QSOs, %2:d points, %3:d mults, score %4:d';

   (* THE VERMONT QSO PARTY'S CLUB-STATION FILE IS NOT THIS YEAR'S -- issue
     270 (NY4I, 2026-11-19: "inform the user we found a file but it appears
     to be for last year's contest and they should renew one at the contest
     URL"). Shown when the contest is opened. %0:s the file, %1:d the year its
     header states, %2:s the sponsor's page. *)
   SVermontClubFileStale = '%0:s is the Vermont QSO Party club-station list for %1:d: ' +
      'it appears to be last year''s. Club stations will not count until you ' +
      'get a current list from %2:s';

   (* ...AND ITS HEADER STATES NO YEAR, so no QSO can be matched to it. %0:s
     the file, %1:s the sponsor's page. *)
   SVermontClubFileNoYear = '%0:s states no contest year (a line YEAR 2027), so its ' +
      'Vermont QSO Party club stations will not count. Get a current list from %1:s';

   (* THE TOTALS GRID'S ZONE ROW AND THE LOG'S ZONE COLUMN WHEN THE "ZONE" IS
     THE YEAR OF FIRST LICENSE -- the European HF Championship and KVP
     (2026-11-11), whose year is kept in the zone slot. The row read 'Zones'
     and the column 'Zn'. The column's ColumnsArray text stays 'Zn': it is
     also the COLUMN WIDTH token. *)
   STotalsLicenseYearMults = 'Years';
   SLogColumnLicenseYear = 'Year';

   (* THE NEW CONTEST DIALOG'S CONTEST LIST -- Q103 / Q52, 2026-10-19. The
     label over the search box and the list, in the same capitals as the
     MY CALL and CATEGORY-* labels beside it. *)
   SNewContestContestLabel = 'CONTEST';

   (* THE GREYED HINT INSIDE THE EMPTY SEARCH BOX. Typing filters the list
     to the contests whose name contains the text, anywhere, ignoring case;
     "QSO" is the example because it lists every QSO party. *)
   SNewContestSearchHint = 'Search: type part of a name, e.g. QSO';

   (* THE BOX UNDER THE NEW CONTEST LIST -- Q59, NY4I 2026-10-19: "hide
     inactive contests". Unticked (the default) the list holds only contests
     that can be started; ticked, the inactive ones are listed too, marked
     SContestInactive, and still cannot be chosen for a new contest. *)
   SNewContestShowInactive = 'Show inactive contests';

   (* THE BOX THAT ORDERS THE NEW CONTEST LIST BY DATE -- NY4I 2026-11-16:
     "show me the contests coming up soonest". Ticked, a contest on the air
     now lists first, then the soonest to start; contests with no date follow
     alphabetically. Unticked (the default) the list is alphabetical. *)
   SNewContestSoonestFirst = 'Upcoming contests first';

   (* THE HINT AFTER A CONTEST THAT IS ON THE AIR NOW, in that ordering. The
     other hints are a date and a UTC time in ISO form, which need no
     translation. *)
   SNewContestRunningNow = 'running now';

   (* THE "LAST CONTEST" BUTTON'S SECOND LINE -- NY4I 2026-10-19: "make the
     contest and year more obvious". %0:s is the contest's display name (a
     sponsor's proper name, not translated), %1:d the year it was run. Reorder
     freely; both must stay. *)
   SLatestContestLine = '%0:s %1:d';

   (* ITS THIRD LINE: %0:s is the entry's callsign, %1:s the log's file name
     without its directory. Shown only when the log declares a callsign. *)
   SLatestContestDetail = '%0:s - %1:s';

   (* THE NEW CONTEST DIALOG'S EXISTING-LOG GRID, its four column headers --
     NY4I 2026-10-19. One row per log in the contest directory: the contest's
     display name, the year it was run, the entry's callsign, and the file
     name without its directory. And, since 2026-10-24 (NY4I, two logs of one
     contest he could not tell apart), the UTC date and time of the log's
     newest QSO and how many QSOs it holds -- "QSOs" is that count. *)
   SNewContestFilesContest = 'Contest';
   SNewContestFilesYear = 'Year';
   SNewContestFilesCall = 'Call';
   SNewContestFilesLastQSO = 'Last QSO';
   SNewContestFilesQSOs = 'QSOs';
   SNewContestFilesFile = 'File';

   (* CATEGORY-POWER CHANGED WITH QSOs IN THE LOG. NY4I, 2026-10-01: "Maybe
     we remind them of that mid-contest but let it be changed." A notice, not
     a question -- the change has already been made and the log rescored.
     %s is the new power category (HIGH, LOW, QRP). *)
   SCategoryPowerChangedRescored =
      'CATEGORY-POWER is now %s -- the scoring category changed and the log was rescored.';

   (* ---------------------- an ADIF import names our station (schema 3) - *)

   (* ASKED BEFORE THE IMPORT COMMITS, when the file names our station for
     some QSOs and any of it is not this contest's. NY4I, 2026-10-18: "If the
     import has its own my fields, we should report that and ask the user if
     they should override the contest." %d of %d: the QSOs that name our
     station, of all the file's; %s: the MY_ tags they carry; the last %s:
     one line per tag that differs, from SImportMyFactsDifference. *)
   SImportMyFactsQuestion =
      'This file names our station for %d of its %d QSO(s) (%s), and it is ' +
      'not what this contest has:%s' + sLineBreak + sLineBreak +
      'Keep the file''s values for those QSOs?' + sLineBreak +
      'Yes keeps the file''s. No gives them this contest''s, as a new QSO ' +
      'would get.';

   (* One line of SImportMyFactsQuestion: the tag, how many QSOs differ, one
     of the file's values and this contest's. *)
   SImportMyFactsDifference = '%s: %d QSO(s), e.g. %s (this contest: %s)';

   (* WHAT THE IMPORT DID WITH OUR STATION -- the end of its report. *)
   SImportMyFactsSame =
      '%d QSO(s) named our station (%s), the same as this contest''s.';
   SImportMyFactsKept = 'The file''s station was kept for %d QSO(s).';
   SImportMyFactsReplaced =
      '%d QSO(s) were given this contest''s station in place of the file''s.';
   SImportMyFactsStamped =
      '%d QSO(s) named no station of ours and were given this contest''s.';

   (* ---------------------------------------- the backup destination - *)

   (* ISSUE #98 STEP 2: the folder a backup is COPIED to after it is written
     locally. Each is shown ONCE per change of state, on the status line,
     which is one small panel; %s is the folder.

     A FAILURE IS ONE SHORT SENTENCE PER REASON (NY4I, 2026-11-18: "far too
     verbose and small. We just need to know the backup failed and a simple
     reason"). The reason is uBackupCopier.TBackupCopyFailure; the full detail
     -- the file, the system's own message -- goes to tr4w.log only. Whole
     sentences, not a reason spliced into one, so a translation can order
     its words. These replace SBackupCopyFailed ('Backups are NOT reaching
     %s: %s. ...'), RENAMED rather than reworded so no translation of the
     old two-%s sentence is ever formatted with one argument. *)
   SBackupDestinationReachable = 'Backup destination %s is reachable.';
   SBackupCopyFailedDiskFull = 'Backup to %s FAILED: the disk is full.';
   SBackupCopyFailedFolderMissing = 'Backup to %s FAILED: the folder is not there.';
   SBackupCopyFailedNoAccess = 'Backup to %s FAILED: access denied.';
   SBackupCopyFailedOther = 'Backup to %s FAILED.';
   SBackupCopyRecovered = 'Backups are reaching %s again.';
   (* Shown when a backup has been written locally and its copy is queued;
     %s is the DESTINATION folder, not the local file. *)
   SBackupCopyingToDestination = 'Log backed up; copying to %s ...';
   (* Shown when a copy has arrived and read back the same; %s is the file
     at the destination. *)
   SBackupCopiedTo = 'Backup copied to %s.';
   (* The title of the folder chooser on the Preferences backup page. *)
   SBackupDestinationDialogTitle = 'Backup destination folder';

   (* ------------------------------------------- TX inhibited (#97) - *)

   (* THE KEYED RADIO'S STATUS PANEL, for the key-up only: the station is
     transmitting and the radio says it will not radiate.  %s is the radio's
     own words for why ("TX test mode" from a K4) -- bounded to 31 characters
     by TTXInhibitReason, so this stays inside a status panel. *)
   STXInhibitedStatus = 'TX INHIBITED: %s';
   (* THE PTT INDICATOR'S CAPTION for the same key-up.  The indicator is three
     character cells wide (VC.TWindows[mwePTTStatus]), so the sentence cannot
     go there; the status panel above carries it. *)
   STXInhibitedIndicator = 'INH';

   (* ------------------------------------ Preferences, Online scoring - *)

   (* THE NOTE UNDER THE HAMSCORE SERVICE URL, shown only while that URL is
     plain http:// (uHTTPDownload.IsPlainHttpUrl). Nothing is refused; it says
     what plain http costs and names the https alternative. Keep the URL as
     written: it is an address, not prose. *)
   SHamScorePlainHttpNote =
      'Plain http: your HamScore password is sent unencrypted. Use https://hamscore.com/postxml/ if the server supports it.';

   (* ---------------------- Preferences, the pages that replace More settings - *)

   (* NAVIGATION ENTRIES AND HEADINGS for the settings that left the More
     settings holding page (issue 235).  Each nav entry's text is also the
     heading of the page it opens, so one string serves both. *)
   (* Operating > Messages: what is sent around your own call (DE ENABLE). *)
   SPrefsNavMessages = 'Messages';
   (* CW Settings > While operating: the page that was Operating > CW.  Under
     CW Settings a child called "CW" would say nothing. *)
   SPrefsNavCWWhileOperating = 'While operating';
   (* CW Settings > Speed and characters: CODE SPEED, the cut numbers, the
     question mark and slash characters, and automatic sending. *)
   SPrefsNavCWSpeedAndCharacters = 'Speed and characters';
   (* Contest > Printed log: LOG SUB TITLE and CONTACTS PER PAGE. *)
   SPrefsNavPrintedLog = 'Printed log';
   (* UNDER THE PRINTED LOG HEADING, AND IT MUST STAY TRUE: nothing in this
     build reads either setting.  Do not reword it into a promise. *)
   SPrefsPrintedLogNote =
      'This version of TR4W does not print the log, so these two settings are kept but have no effect yet.';
   (* A block heading on the Hardware page, over STEREO PIN HIGH -- the YCCC
     SO2R box's stereo control, which the checkbox above it enables. *)
   SPrefsYCCCBoxHeading = 'YCCC SO2R box';
   (* A block heading on the Band Map page, over IE SWITCH: only spots that
     match the initial exchange file and TRMASTER reach the band map. *)
   SPrefsInitialExchangeFilterHeading = 'Initial exchange filter';
   (* THE OPERATING PAGE'S INTRODUCTION.  It named CW among the pages below it;
     CW moved under CW Settings, so the sentence says where it went. *)
   SPrefsOperatingInfo =
      'How the log behaves while you are running the contest. Band map, bands, messages, scoring and two-radio settings are on the pages below; CW is under CW Settings.';

   (* ISSUE 264: THE KEYER LIBRARY MOVED UNDER HARDWARE.  A WinKeyer is
     hardware to a new operator, so the list of keying devices (WinKeyer, YCCC
     SO2R+) left the top of CW Settings for Hardware > CW keyers. *)
   (* Hardware > CW keyers: the nav entry. *)
   SPrefsNavCWKeyers = 'CW keyers';
   (* THE HARDWARE PAGE'S INTRODUCTION, which names the pages below it. *)
   SPrefsHardwareInfo =
      'Station-wide hardware. Settings that belong to one radio are under Radios; rotators are under Rotators; WinKeyer and YCCC SO2R+ keyers are under CW keyers.';
   (* At the top of CW Settings: where the keyer library went. *)
   SPrefsCWKeyersPointer =
      'WinKeyer and YCCC SO2R+ keyers, and their settings, are under Hardware > CW keyers.';
   (* On Hardware > CW keyers: what stayed under CW Settings. *)
   SPrefsKeyersCWPointer =
      'The CW TR4W sends, and the paddle and serial-line keying it does itself, are under CW Settings.';
   (* The Preferences search result for the keyer library. *)
   SPrefsSearchCWKeyers = 'WinKeyer and YCCC SO2R+ keyers';
   (* NEVER SHOWN: words the Preferences search matches to find the keyer
     library.  They are the WinKeyer settings in the keyer editor (Edit... on
     Hardware > CW keyers); translate each one exactly as that window's caption
     is translated, so an operator's search for it finds the list. *)
   SPrefsSearchWinKeyerSettings =
      'Keyer mode, Sidetone, Weight, Dit/dah ratio, Switchpoint, Lead-in, Tail, Compensation, First extension, Auto space, CT spacing, Ignore speed pot, Sidetone on, Paddle-only sidetone, Swap paddles';
   (* A Preferences page that holds nothing yet (issue 279: Web Server -- TR4W
     has no web server).  It replaced "Use the existing configuration screens
     for it", which pointed at no screen. *)
   SPrefsPageHasNoSettingsYet = 'There are no settings on this page yet.';

   (* Issue 235, stage 2: the rest of More settings.  New navigation entries
     (each is also its page's heading)... *)
   SPrefsNavEntryAndDupeChecking = 'Entry and dupe checking';
   SPrefsNavLogDisplay = 'Log display';
   SPrefsNavFilesAndUpdates = 'Files and updates';
   (* A child of Operating > Band Map: the band map window's size and split
     handling, and the offset added when tuning to a spot. *)
   SPrefsNavBandMapWindow = 'Window and tuning';
   (* A child of DX Cluster. *)
   SPrefsNavClusterSpots = 'Spots and console';
   (* THE REST OF THE PREFERENCES NAVIGATION TREE (2026-11-24).  These
     were literals in uPrefsForm.BuildNavTree, so no catalogue held them
     and the tree was English in every language.  The search box shows a
     match's section from the node's own text, so it follows.  SCP, WSJT-X,
     DXLab and MMTTY stay literals: they are names, not words. *)
   SPrefsNavStation          = 'Station';
   SPrefsNavHardware         = 'Hardware';
   SPrefsNavRadios           = 'Radios';
   SPrefsNavRotators         = 'Rotators';
   SPrefsNavDXCluster        = 'DX Cluster';
   SPrefsNavOperating        = 'Operating';
   SPrefsNavBandMap          = 'Band Map';
   SPrefsNavBands            = 'Bands';
   SPrefsNavOnlineScoring    = 'Online Scoring';
   SPrefsNavTwoRadioMode     = 'Two Radio Mode';
   SPrefsNavUDPBroadcast     = 'UDP Broadcast';
   SPrefsNavNetwork          = 'Network';
   SPrefsNavAppearance       = 'Appearance';
   SPrefsNavColors           = 'Colors';
   SPrefsNavLogging          = 'Logging';
   SPrefsNavBackup           = 'Backup';
   SPrefsNavContest          = 'Contest';
   SPrefsNavAudio            = 'Audio';
   SPrefsNavCWSettings       = 'CW Settings';
   SPrefsNavPaddleAndPTT     = 'Paddle and PTT';
   SPrefsNavWebServer        = 'Web Server';
   SPrefsNavTCIServer        = 'TCI Server';
   SPrefsNavExternalSoftware = 'External Software';
   SPrefsNavExternalLogger   = 'External Logger';
   SPrefsNavAdvanced         = 'Advanced';

   (* The mult strip's one-row label when the QSO strip above is split CW:/SSB:
     and the multipliers are not (uMainGrids): a mult counts once across
     both modes.  'CW:' and 'SSB:' are mode tags and stay literals. *)
   SMultStripBothModes = 'Both:';
   (* ...and the GROUP HEADINGS rows sit under on a page. *)
   SPrefsGroupBandsAndFrequencies = 'Starting band and mode, and frequency memory';
   SPrefsGroupDupeChecking = 'Dupe checking';
   SPrefsGroupSearchAndPounce = 'Search and pounce';
   SPrefsGroupTyping = 'Typing';
   SPrefsGroupWhatIsLogged = 'What a QSO records';
   SPrefsGroupHandLog = 'Entering a log by hand';
   (* Two Radio Mode: TUNE ALT-D ENABLE, filled in while tuning the inactive
     radio. *)
   SPrefsGroupTuningOtherRadio = 'Tuning the other radio';
   SPrefsGroupBandMapWindow = 'Band map window';
   (* The Colors page's band map block -- the band map's colour roles
     (issue 59), under the main window's grid. *)
   SPrefsGroupBandMapColors = 'Band map colors';
   SPrefsGroupSpotTuning = 'Tuning to a spot';
   (* The WSJT-X / JTDX page's block for the N1MM log listener (issue 45). *)
   SPrefsGroupN1MMListener = 'N1MM log listener (JTDX, JTAlert)';
   (* ~~SPrefsGroupRadioPolling~~ -- gone with its one row: FREQUENCY POLL
     RATE is a field of each radio definition now (issue 235 step 3). *)
   (* MAIN CALLSIGN: the station's own call, remembered for New Contest; not
     the call being operated, which a contest can override. *)
   SPrefsGroupStationCallsign = 'Your own callsign, remembered for New Contest';
   SPrefsGroupSuggestedCalls = 'Suggested-call keys';
   SPrefsGroupNetworkStations = 'Stations and the Network window';
   SPrefsGroupInternet = 'Internet downloads and uploads';
   SPrefsGroupRateDisplay = 'Rate display';
   SPrefsGroupLogWindow = 'Log window';
   (* USER INFO SHOWN: the TRMASTER field shown just below the call window. *)
   SPrefsGroupUserInfo = 'Information shown under the call window';
   SPrefsGroupAlerts = 'Alerts';
   SPrefsGroupVoiceKeyer = 'Voice keyer';
   (* THESE THREE ARE CONTEST LEAVES NOW (Contest > Modes, > Initial exchange,
     > Multiplier data): their nav entry and page heading.  The identifiers
     stay, because the catalogues already carry their translations under
     these names; a renamed identifier would orphan them. *)
   SPrefsGroupModes = 'Modes';
   SPrefsGroupInitialExchange = 'Initial exchange';
   SPrefsGroupMultiplierData = 'Multiplier data';
   (* THE OTHER CONTEST LEAVES: the Contest page was split so it is not one
     long list.  Each is its page's nav entry and heading. *)
   SPrefsNavQTC = 'QTC';
   SPrefsNavQSOSettings = 'QSO settings';
   SPrefsNavQuickQSL = 'Quick QSL';
   (* CATEGORY-ASSISTED .. CATEGORY-TRANSMITTER: the Cabrillo header's
     CATEGORY lines.  NY4I's wording. *)
   SPrefsNavCabrilloHeadings = 'Cabrillo headings';
   (* Special contest modes and rules: minitour, R150S, RFOBL, sprint QSY,
     ten-minute rule, single-band score, multiple bands. *)
   SPrefsNavContestRules = 'Contest rules';
   (* THE BAND PLAN ROW on the Bands page: a label and the button that opens
     the band plan editor, which saves its own whole section. *)
   SPrefsBandPlanRow = 'Band plan (cutoff frequencies and memories)';
   SPrefsBandPlanEdit = 'Edit...';
   (* A GENERATED FILE ROW'S BUTTON (CALL HISTORY FILENAME, INITIAL EXCHANGE
     FILENAME) -- the same words as the designed Browse buttons. *)
   SPrefsBrowse = 'Browse...';
   (* THE APPEARANCE PAGE'S FONT SUMMARY, 'Arial, Bold': the word that follows
     the face when BOLD FONT is on. The same English the Bold check box it
     replaced carried, so its translations came with it. *)
   SPrefsFontBold = 'Bold';

   (* ------------------------------------ Call history download (Help) - *)

   (* HELP -> THE CONTEST'S CALL HISTORY FILE, from supercheckhistory.com.
     Manual only: nothing downloads it by itself. *)
   SMenuDownloadCallHistory = 'Download call history for this contest';
   SCallHistoryDownloading = 'Downloading call history...';
   SCallHistoryNoSource = 'This contest has no call history download';
   SCallHistoryBusy = 'A call history download is already running';
   SCallHistoryUpdated = 'Call history updated (%d entries, %s)';
   (* Appended to the update message once the running contest has the new file
     (live reload, 2026-11-20). %d is how many calls it stored. *)
   SCallHistoryInUse = 'it is in use now (%d calls)';
   (* Appended when the downloaded file was not applied to the running contest:
     unreadable, or the contest or USE CALL HISTORY FILE wants no call history. *)
   SCallHistoryNotApplied = 'it was not applied to the running contest (see tr4w.log); any call history already loaded stays in use';
   SCallHistoryCurrent = 'Call history already current';
   SCallHistoryNotAvailable = 'No call history file for this contest on supercheckhistory.com';
   SCallHistoryFailed = 'Download failed (%s); the previous file was kept';
   SCallHistoryRefused = 'Server refused (HTTP %d); the previous file was kept';
   (* Appended to the update message when CALL HISTORY FILENAME names another
     file: the downloaded one is not the file that is read. %s is that name. *)
   SCallHistoryOtherFile = 'CALL HISTORY FILENAME is "%s", so the downloaded file is not the one in use';
   (* WHY A DOWNLOAD WAS NOT KEPT -- the %s of SCallHistoryFailed. *)
   SCallHistoryReasonHtml = 'the server sent a web page, not a call history file';
   SCallHistoryReasonTooSmall = 'the file is too small to be a call history';
   SCallHistoryReasonTooLarge = 'the file is larger than expected';
   SCallHistoryReasonTooFewRows = 'the file has too few usable rows';
   SCallHistoryReasonSmaller = 'the new file is much smaller than the one held';
   SCallHistoryReasonWrite = 'the file could not be saved';

   (* ------------------------------------------- HamScore resync (Tools) - *)

   (* THE TOOLS MENU ITEM AND THE STATUS WINDOW'S BUTTON for the same action.
     It was "Resync from log". The ellipsis is because it opens a dialog; the
     dialog is where the optional delete is spelled out. *)
   SHamScoreResyncCaption = 'Re-send Log to HamScore...';

   (* THE DIALOG (MainUnit.HamScoreResyncWithConfirmation). %s is the contest's
     id as HamScore receives it (the <deletelog><contest> value). Nothing here
     claims the server de-duplicates: the code only shows that a re-sent QSO
     carries its original ID, the way an edit does. *)
   SHamScoreResyncBody =
      'Re-send only: uploads every QSO in this log again, each with its original ID. Nothing is deleted on the HamScore server, so a QSO you have deleted from this log will still be there.' + #10#10 +
      'Delete and re-send: first deletes the HamScore server''s log for this contest (%s), then uploads every QSO. This cannot be undone on the server, and scores on the HamScore site are empty or incomplete until the upload finishes. Use it when the server shows QSOs that are no longer in this log.';
   SHamScoreResyncOnly = 'Re-send only';
   SHamScoreResyncDeleteFirst = 'Delete and re-send';

   (* ---------------------------------------- a locked contest log (2026-10-31) - *)

   (* THE STARTUP DIALOG (uLogStore.AskAboutALockedLog). %s is the log's file,
     then one of the two "held" sentences below. The three captions are the
     buttons; the answer is read by modal result, never by position. NOTHING
     here may offer to delete the -wal or -shm: they can hold committed QSOs. *)
   SLogLockedTitle = 'Contest log is locked';
   SLogLockedBody =
      'TR4W cannot open the contest log for writing:' + #10 + '%s' + #10#10 +
      '%s' + #10#10 +
      'To fix it: close the other TR4W (look for one stopped at an error ' +
      'dialog, or end it in the Task Manager), or pause the backup, sync or ' +
      'antivirus tool that has the file, then choose Retry.' + #10#10 +
      'Open read-only lets you view and export the log, but NO QSO CAN BE ' +
      'LOGGED until TR4W is restarted with the log unlocked.';
   SLogLockedHeldHere = 'This TR4W''s own background connection is holding it: %s.';
   SLogLockedHeldElsewhere =
      'Another program is holding it -- most likely another TR4W, or one that ' +
      'crashed and is still waiting at an error dialog; or a backup, cloud ' +
      'sync (OneDrive, Dropbox) or antivirus program reading the file.';
   SLogLockedRetry = 'Retry';
   SLogLockedReadOnly = 'Open read-only (no logging)';
   SLogLockedQuit = 'Quit TR4W';

   (* ------------------------ a new contest's log name is taken (issue 276) - *)

   (* THE NEW CONTEST QUESTION (uNewContest.AskAboutATakenLogName), asked when
     a log for the same contest, date and callsign already exists -- CW Open
     runs three sessions a day. The first %s is the existing log, the second
     the numbered name a new log would get. The two captions are buttons; the
     third is the LCL's own Cancel. NOTHING HERE OVERWRITES OR DELETES A LOG.
     It replaced TC_FOLDERALREADYEXISTSOVERWRITE, which offered to overwrite
     a "folder" and opened the existing log whichever button was chosen. *)
   SNewLogNameTakenTitle = 'This contest already has a log';
   SNewLogNameTakenBody =
      'A log for this contest, date and callsign already exists:' + #10 + '%s' + #10#10 +
      'Create new log: start a separate, empty log named' + #10 + '%s' + #10 +
      'The existing log is kept unchanged.' + #10#10 +
      'Open existing log: continue logging in the existing log.' + #10#10 +
      'Cancel: go back to the New Contest window. Nothing is created.';
   SNewLogCreateNumbered = 'Create new log';
   SNewLogOpenExisting = 'Open existing log';
   (* The same question when the taken log IS THE ONE OPEN (File > Open Log,
     2026-11-11): Open existing is not offered, because opening the open log
     does nothing. The first %s is that log, the second the numbered name.
     Buttons: SNewLogCreateNumbered and the LCL's own Cancel. *)
   SNewLogNameTakenOpenBody =
      'The log for this contest, date and callsign is the log you have open:' + #10 + '%s' + #10#10 +
      'Create new log: start a separate, empty log named' + #10 + '%s' + #10 +
      'The open log is kept unchanged.' + #10#10 +
      'Cancel: go back to the New Contest window. Nothing is created.';

   (* Shown once, the first time a read-only session refuses a write. %s is the
     log's file. *)
   SLogReadOnlyRefused =
      'This contest log was opened READ-ONLY because it was locked:' + #10 +
      '%s' + #10#10 +
      'Nothing can be saved to it -- NO QSO IS BEING LOGGED. Close what holds ' +
      'the log and restart TR4W to log again.';

   (* A write that met a locked log after every retry (uLogStore.Disable). %s
     says what was being written ("appending a QSO"). *)
   SLogBusyNotSaved =
      'The contest log was locked by another program while %s, so that change ' +
      'was NOT saved. The log itself is not damaged and TR4W keeps it open.' +
      #10#10 + 'If this was a QSO, it is still in the entry window: log it ' +
      'again. If this keeps happening, run Tools > Run Verification Checks.';

   (* A WRITE THE DISK WOULD NOT TAKE -- a full disk, or a write error
     (uLogStore.Disable, 2026-11-18). The log stays open READ-ONLY: it can
     be viewed, and nothing is saved until a save finds the disk takes
     writes again. Shown once per log, at the first failure. The
     first %s is the reason (one of the SLogReadOnlyReason strings), the
     second the remedy (an SLogReadOnlyFix string), the third the log's
     file. *)
   SLogNotSavedReadOnly =
      'The contest log is not being saved (%s).' + #10#10 +
      'QSOs can still be viewed but not saved or edited. %s' + #10#10 +
      'The log written so far is in %s.';
   (* NO RESTART (2026-11-18): the next save tries the disk again
     (uLogStore.LogStoreTryRecoverWrites). *)
   (* %d is the megabytes to free (uLogStore.LOG_DISK_FULL_FREE_MB), %s the
     drive ("D:"), or the folder when the log's path has no drive letter. *)
   SLogReadOnlyFixDiskFull = 'Free at least %d MB on %s, then press Enter again.';
   SLogReadOnlyFixWriteError =
      'Check the drive the log is on, then press Enter again. Details are in tr4w.log.';
   (* The status line, once, when a save finds the disk takes writes again. *)
   SLogWritableAgain = 'The log is writable again.';
   (* THE STATUS LINE AFTER EVERY QSO WHILE THE LAST PERIODIC BACKUP FAILED
     (issue 351 (b)): said again until a backup succeeds, not once. %d is the
     minutes between retries (uLogBackup.PERIODIC_BACKUP_RETRY_SEC). ONE
     LINE: keep it short. *)
   SLogBackupStillFailing = 'Last log backup FAILED: retried every %d min. See tr4w.log.';
   (* AFTER A RESTORE FROM A BACKUP THAT HOLDS EXTERNAL-LOGGER DELIVERY ROWS
     (issue 242, warn only): uLogRestore.TLogRestoreResult.DeliveryNotice.
     The caller shows it; nothing is changed. *)
   SLogRestoreDeliveryNotice =
      'The restored log''s record of what was sent to external loggers (Club Log, ' +
      'WRL, DXKeeper) is as old as the backup. QSOs logged after the backup may ' +
      'already be at those services but are not in this log, and QSOs the backup ' +
      'had not yet sent will be sent again. Check each service''s log.';
   (* WHY THE LOG IS READ-ONLY, in a few words: the %s of SLogNotSavedReadOnly
     and of SLogReadOnlyNotSaved. *)
   SLogReadOnlyReasonDiskFull = 'disk full';
   SLogReadOnlyReasonWriteError = 'write error';
   SLogReadOnlyReasonLocked = 'locked';
   (* THE STATUS LINE, every time a QSO or an edit is refused because the log
     is read-only -- no dialog. %s is the reason, an SLogReadOnlyReason
     string. *)
   SLogReadOnlyNotSaved = 'Log is read-only (%s): not saved.';
   (* The same line when the cause is a FULL DISK, saying how much to free and
     where -- a small free does not work (NY4I, 16 KB). %d megabytes, %s the
     drive or folder, as SLogReadOnlyFixDiskFull. ONE LINE: keep it short. *)
   SLogReadOnlyNotSavedDiskFull = 'Log is read-only (disk full): free %d MB on %s, then Enter.';
   (* THE STATUS LINE WHEN A CHANGE TO A LOGGED QSO -- an Edit QSO save, an
     Alt-Y delete or restore -- was not committed and the log is NOT
     read-only (issue 349): a write or a commit failed, or the row was not
     there. Nothing was sent anywhere. ONE LINE: keep it short. *)
   SLogChangeNotSaved = 'NOT SAVED -- the contest log did not take this change. See tr4w.log.';

   (* THE ENTRY AREA'S LOG STATUS (uEntryStatus, 2026-11-22): the first line
     of the panel beside the call and exchange. The reason follows on the
     next line (SQsoNotLogged or SLogReadOnlyNotSaved...). The panel is
     narrow -- seven grid units, 91 px at the smallest scale -- so KEEP THESE
     SHORT; a longer translation wraps onto the reason's line. *)
   SEntryStatusQsoNotSaved = 'QSO not saved';
   SEntryStatusLogReadOnly = 'Log read-only';
   (* The names the call and exchange fields give assistive technology
     (AccessibleName). *)
   SEntryFieldCallName = 'Call';
   SEntryFieldExchangeName = 'Exchange';

   (* THE RADIO PANEL'S ACTIVE-RADIO LABEL (uRadioPanelForm, 2026-11-22): shown
     on the ACTIVE radio's panel only, beside its cyan tint -- the station's
     choice of radio, never the rig's VFO A/B. One row the panel's full width
     (185 px at the smallest size), so a longer word fits; keep it one word.
     The second string is the name the label gives assistive technology
     (AccessibleName). *)
   SRadioPanelActive = 'Active';
   SRadioPanelActiveName = 'Active radio';

   (* ENFORCE VALID CALLSIGN (issue 180): the QSO is refused because the
     call's base -- the longest part around any '/' -- is not a DXCC entity in
     the country file. %s is the call as typed. On the status line, no beep
     (NY4I: nobody hears a beep in headphones). *)
   SCallNotAKnownEntity = '%s is not logged: its base call is not in the country file';

   (* WHY A DOUBLE CLICK ON THE LOG OPENED NO EDIT QSO WINDOW -- on the status
     line, because it said nothing at all (2026-11-18). *)
   SEditQSONoQSOSelected = 'No QSO selected.';
   SEditQSOLogUnreadable = 'The contest log cannot be read: see tr4w.log.';
   SEditQSONoSuchQSO = 'That QSO is not in the log any more.';
   SEditQSOCannotRead = 'That QSO could not be read from the log: see tr4w.log.';
   SEditQSONotEditable = 'A deleted QSO, or a record that is not a QSO, cannot be edited here.';

   (* EDIT QSO -- OUR STATION AS RECORDED FOR THE QSO (log schema 3). The
     group caption says where the values came from; the rest label the
     fields. Moved here from uTR4WStrings, which pas2res regenerates and
     would have deleted them from (issue 158). *)
   SEditQSOMyStation            = 'Our station for this QSO';
   SEditQSOMyStationNotRecorded = 'Our station for this QSO (not recorded)';
   SEditQSOMyStationAssumed     = 'Our station for this QSO (assumed: a network QSO)';
   SEditQSOMyCall               = 'Call';
   SEditQSOMyGrid               = 'Grid';
   SEditQSOMyState              = 'State';
   SEditQSOMyCounty             = 'County';
   SEditQSOMySection            = 'Section';
   SEditQSOMyPark               = 'Park';
   SEditQSOMyCQZone             = 'CQ zone';
   SEditQSOMyITUZone            = 'ITU zone';
   (* THE LICENCE YEAR THE QSO SENT (qso.year_sent, issue 300), and the
     refusal of one the contest's kind cannot send. *)
   SEditQSOMyYearSent           = 'Year sent';
   SEditQSOImproperSentYear     = 'Improper license year sent!!';
   (* THE REST OF WHAT THE QSO SENT OF OUR STATION -- log schema 9 (phase 2,
     2026-11-17). Also the names uStationFactRecord.StationFactCaption gives
     every station fact, which Preferences lists in its two questions below,
     so IOTA and the license year are here though Edit QSO shows neither
     under these words. *)
   SEditQSOMyName               = 'Name';
   SEditQSOMyFdClass            = 'FD class';
   SEditQSOMyCheck              = 'Check';
   SEditQSOMyPrec               = 'Precedence';
   SEditQSOMyPostalCode         = 'Postal code';
   SEditQSOMyFocNumber          = 'FOC number';
   SEditQSOMyPrefecture         = 'Prefecture';
   SEditQSOMyPowerClass         = 'Power class';
   SEditQSOMyIota             = 'IOTA';
   SStationFactLicenseYear      = 'License year';
   (* A changed value of our station that its field's rule refuses
     (uStationFactRecord.EditedStationFactProblem): %0:s the field's name,
     %1:s the text typed, %2:s the rule's reason. Shown as a bad call is,
     and nothing is saved. *)
   SEditQSOStationValueRefused  = '%0:s "%1:s" cannot be saved.' + sLineBreak +
                                  sLineBreak + '%2:s';

   (* TOOLS > CORRECT STATION FACTS (issue 223): one station value set on
     every logged QSO, or from QSO n on (uStationFactRecord.
     StationFactBulkProblem; uLogStore.LogStoreCorrectStationFacts).
     %s in SStationCorrectionNotAllowed is the fact's name
     (StationFactCaption). *)
   SStationCorrectionNotAllowed = '%s cannot be changed on logged QSOs.';
   SStationCorrectionEmptyValue = 'Type the value the QSOs should have.';
   SStationCorrectionZoneZero   = 'A zone of 0 is not a zone.';
   SStationCorrectionBackupFailed = 'Nothing was changed: the log could not be ' +
                                    'backed up first. %s';
   SStationCorrectionFailed     = 'Nothing was changed: the contest log did not ' +
                                  'take the correction. See tr4w.log.';
   SStationCorrectionReadOnly   = 'Nothing was changed: the contest log is read-only.';
   (* The Tools-menu dialog (uCorrectStationFactsDialog). *)
   SMenuCorrectStationFacts     = 'Correct Station Facts...';
   SStationCorrectionTitle      = 'Correct station facts on logged QSOs';
   SStationCorrectionChooseFact = 'Which of your station''s values is wrong on the ' +
                                  'QSOs already logged?';
   (* %s the fact's name. *)
   SStationCorrectionValuePrompt = 'The value the QSOs should have for %s:';
   SStationCorrectionFromPrompt = 'Change the QSOs from log record number ' +
                                  '(1 = every QSO in the log):';
   SStationCorrectionBadFrom    = 'A log record number is a whole number from 1 up.';
   SStationCorrectionNothing    = 'No logged QSO needs changing.';
   SStationCorrectionScopeAll   = 'ALL PRIOR CONTACTS in the log';
   (* %d the first log record number changed. *)
   SStationCorrectionScopeFrom  = 'every contact from log record %d on';
   (* %0:s the fact, %1:s the new value, %2:d the QSOs to change, %3:s the
     scope (SStationCorrectionScopeAll / ...From), %4:s what they hold now,
     %5:d imported, %6:d never recorded, %7:d per place, %8:d of the %2:d
     a multi-op peer's. *)
   SStationCorrectionConfirm    = 'This CHANGES %0:s to "%1:s" on %2:d logged QSO(s): %3:s.' +
                                  sLineBreak + 'They say now: %4:s.' + sLineBreak +
                                  sLineBreak +
                                  'The log is BACKED UP FIRST. Each changed QSO is then ' +
                                  'sent again as an edit -- to Club Log, WRL and any other ' +
                                  'external logger, to the multi-op server and as a UDP ' +
                                  'replace -- and the log is rescored. %8:d of them are a ' +
                                  'multi-op peer''s: corrected here, sent by that station.' +
                                  sLineBreak + sLineBreak +
                                  'Not changed: %5:d imported, %6:d never recorded (they ' +
                                  'follow your setting: correct it in Preferences too), ' +
                                  '%7:d per place (a rover or an in-state party).';
   SStationCorrectionChangeButton = 'Change the QSOs';
   SStationCorrectionCancelButton = 'Cancel';
   (* %0:s the fact, %1:s the value, %2:d the QSOs changed, %3:s the backup. *)
   SStationCorrectionDone       = '%0:s is now "%1:s" on %2:d logged QSO(s).' + sLineBreak +
                                  'The log as it was is in %3:s';

   (* FILE > OPEN LOG... (issue 218, S0; the New Contest dialog since issue
     228). TR4W closes the open contest the way File > Exit does and starts
     again on the chosen log. The title follows the version and ' - ' in the
     dialog's title bar (uNewContestForm.NewContestFormCaption). *)
   SMenuOpenLog              = 'Open Log...';
   SOpenLogSwitchTitle       = 'Switch to another contest (TR4W restarts on the one you choose)';
   SOpenLogHandOffFailed     = 'Open Log was not done: the new contest could not be ' +
                               'saved for the restart. The reason is in tr4w.log.';
   SOpenLogRefusedKeyed     = 'Open Log was not done: a radio is transmitting. ' +
                               'Unkey it, then choose File > Open Log again.';
   SOpenLogRefusedSendingCW  = 'Open Log was not done: a CW message is still being ' +
                               'sent. Let it finish, then choose File > Open Log again.';
   SOpenLogAlreadyOpen       = 'That log is already open.';
   (* %s is the file the operator chose. *)
   SOpenLogNotAContestLog    = 'Not a TR4W contest log, so it was not opened: %s';

   (* THE SEARCH LOG WINDOW (issue 230). The first is the greyed hint inside
     the empty Callsign box -- shown only while the box is empty, never
     searched for; the box searches for the typed text anywhere in a call.
     The second is its status line when the log cannot be opened. *)
   SLogSearchCallHint      = 'Call or part of one';
   SLogSearchLogUnreadable = 'The log could not be read';

   (* THE EXTERNAL LOGGER EDITOR BUILDS ITS ROWS FROM EACH PROVIDER'S OWN
      DECLARATION (issue 227). Captions of the declared fields, then the
      messages the editor and the start-up check share. *)
   SLoggerFieldHost          = 'Host / IP address';
   SLoggerFieldPort          = 'Port';
   SLoggerFieldClubLogCall   = 'Club Log callsign';
   SLoggerFieldClubLogToken  = 'Club Log API token';
   SLoggerFieldWRLKey        = 'WRL API key';
   SLoggerFieldWRLLogbook    = 'Logbook';
   (* Cloudlog / Wavelog (issue 204). The address is the site as the browser
      opens it, https only (add /index.php if the site needs it). *)
   SLoggerFieldCloudlogUrl     = 'Cloudlog / Wavelog address (https://...)';
   SLoggerFieldCloudlogKey     = 'Cloudlog / Wavelog API key';
   SLoggerFieldCloudlogProfile = 'Station profile ID';
   (* QRZ Logbook (issue 310): the logbook's callsign and its API access key. *)
   SLoggerFieldQRZCall         = 'QRZ logbook callsign';
   SLoggerFieldQRZKey          = 'QRZ logbook API key';
   (* %s is a field caption. *)
   SLoggerFieldRequired      = 'Enter %s';
   SLoggerChoiceRequired     = 'Choose %s from the list';
   SLoggerChoiceNeedsKey     = 'Enter the API key and load the list before choosing %s';
   SLoggerPortRange          = 'External logger port must be between 1 and 65535';
   SLoggerChoiceRefresh      = 'Refresh';
   SLoggerChoiceLoading      = 'Loading...';
   (* %s is a short error code from the provider. *)
   SLoggerChoiceFailed       = 'The list could not be loaded: %s. The saved choice is kept.';
   (* Shown for a saved choice whose name was never recorded (a definition
      saved before the editor kept names). It still works. *)
   SLoggerChoiceSaved        = 'Saved choice (refresh to see its name)';
   (* The editor's note under the Active box. What applies on the Preferences
      Save and what waits for a restart is issue 233's rule, the one
      SLoggerGridHint states for the grid. *)
   SLoggerEditorNote         = 'Save to Preferences returns this logger to the Preferences window. Click Save there to store it; Active takes effect then, with no restart. A logger added since TR4W started, or a changed key, host or logbook, applies after you restart TR4W. Each logger sends independently.';
   (* The editor's delivery status line for this logger in the open contest
      log. The five %d are counts. *)
   SLoggerEditorNoLog        = 'No contest log is open.';
   SLoggerEditorCounts       = 'Pending %d | Sending %d | Synced %d | Uncertain %d | Failed %d';
   SLoggerEditorNoCounts     = 'Delivery status unavailable';

   (* The radio editor refusing a FREQUENCY POLL RATE (issue 235 step 3).
     The two %d are the bounds, 10 and 1000. *)
   SRadioEditBadPollRate     = 'The frequency poll rate must be a whole number of milliseconds from %d to %d.';

   (* The tooltip of the radio editor's "Drive through HamLib" box. The %s
     is the HamLib library's own version string (e.g. 4.7.2), or
     SRadioEditHamLibNotAvailable when the library cannot be loaded. *)
   SRadioEditUseHamLibHint      = 'Drive this radio through the HamLib library instead of TR4W''s own driver. HamLib version: %s';
   SRadioEditHamLibNotAvailable = 'not available';

   (* THE URL TEST BUTTON (issue 251, Preferences > Online scoring). NY4I's
      rule: report what came back and let the operator decide. A 200 is
      success; nothing here calls an address invalid, bad or failed, because
      an error is not a verdict on what the operator typed. A reply is
      "Answered <status>"; no reply is "No answer: <what happened>". The
      words in parentheses are the program's own account of the problem and
      are never translated (a library or the system wrote them). *)
   SUrlTestButton            = 'Test';
   SUrlTestRunning           = 'Asking...';
   SUrlTestNothing           = 'Nothing to test: the address box is empty.';
   (* %d is the HTTP status code. *)
   SUrlTestAnswered          = 'Answered %d';
   (* %d is the HTTP status code, %s the address that answered after a redirect. *)
   SUrlTestAnsweredFrom      = 'Answered %d from %s';
   SUrlTestNoAnswerScheme    = 'No answer: the address does not start with http:// or https://';
   SUrlTestNoAnswerPlain     = 'No answer: a plain http:// address was not sent';
   SUrlTestNoAnswerTls       = 'No answer: the OpenSSL libraries could not be loaded';
   SUrlTestNoAnswerTlsLib    = 'No answer: the TLS library stopped while connecting';
   SUrlTestNoAnswerTrust     = 'No answer: the certificate file cacert.pem could not be used';
   SUrlTestNoAnswerVerify    = 'No answer: server certificates cannot be checked on this machine';
   SUrlTestNoAnswerCert      = 'No answer: the server''s certificate was not accepted';
   SUrlTestNoAnswerName      = 'No answer: the host name was not found';
   SUrlTestNoAnswerConnect   = 'No answer: could not connect';
   SUrlTestNoAnswerConnTime  = 'No answer: timed out connecting';
   SUrlTestNoAnswerIoTime    = 'No answer: timed out waiting for the server';
   SUrlTestNoAnswerLost      = 'No answer: the connection was lost';
   SUrlTestNoAnswerCancelled = 'No answer: the request was cancelled';
   SUrlTestNoAnswerOther     = 'No answer';

   (* THE PER-DESTINATION "VERIFY THE SERVER'S CERTIFICATE" CHECK BOX (issue
      256): beside each HTTP destination -- an external logger's editor, the
      HamScore URL and the score Posting URL. Ticked by default. The global
      setting network.verifyServerCertificates stays the master: with it off
      nothing is verified whatever this box says. The warning is shown beside
      the box while it is CLEARED and says what that costs. *)
   SVerifyServerCaption      = 'Verify the server''s certificate';
   SVerifyServerOffWarning   = 'The server''s identity is not checked; anyone between you and it can read what you send.';

   (* PLAIN http:// FOR AN EXTERNAL LOGGER (NY4I, 2026-11-24). A logger's address
      that starts with http:// is refused unless the operator ticks Allow
      insecure: the key and the contacts then travel unencrypted. The editor
      says so ONCE, when the address is left or saved; a delivery that is
      refused says so in words (SLoggerWhyInsecure, in the Connection column and
      Edit QSO's External loggers window) and once on the quick-command panel
      (SLoggerPlainHttpRefusedNotice; the logger's name is put in front by the
      owner). *)
   SAllowInsecureCaption     = 'Allow insecure (plain http)';
   SLoggerPlainHttpNotice    = 'This address is plain http. Everything sent, including your API key, travels unencrypted. Use https if the server offers it. If you must use http, tick Allow insecure.';
   SLoggerWhyInsecure        = 'plain http not allowed (tick Allow insecure or use https)';
   (* CLOUDLOG / WAVELOG FAILURES IN WORDS (NY4I, 2026-11-24: a Cloudlog served
      through index.php answered 404 and the operator saw only the code
      CLOUDLOG_HTTP_404). DeliveryFailureReasonText maps each code to one of
      these, for the Connection column, Edit QSO's window and the log. *)
   SLoggerWhyCloudlog404     = 'The server answered 404 for the API address. If your Cloudlog runs through index.php, end the address with /index.php.';
   SLoggerWhyCloudlogKey     = 'The server refused the API key, or the key has no write permission (HTTP %d). Check the key, the station profile id and the station call sign.';
   SLoggerWhyCloudlog401     = 'The server answered 401. One of three things is wrong: the API key (wrong, or read-only); the station profile id (it is the NUMBER of the station location, not its name); or the call sign does not match the one set on that station profile.';
   SLoggerWhyCloudlogKeyRejected = 'The server rejected the API key (missing or wrong). Check the key.';
   SLoggerWhyCloudlogStationNotOwned = 'The station profile id does not belong to the owner of the API key. Use the station location''s NUMBER from Cloudlog''s Station Locations list, not its name.';
   SLoggerWhyCloudlogCallMismatch = 'The call sign does not match the call sign set on that station profile in Cloudlog.';
   SLoggerCloudlogProfileNote ='The station profile is normally a number: the station location''s number in Cloudlog''s Station Locations list, not its name.';
   SLoggerWhyCloudlogReadOnly ='The API key is read-only. Use a key with write permission.';
   SLoggerWhyCloudlog405     = 'The server does not accept this request at that address (HTTP 405). Check the address; an instance served through index.php needs it to end with /index.php.';
   SLoggerWhyCloudlog4xx     = 'The server refused the request (HTTP %d). Check the address and the station profile id.';
   SLoggerWhyCloudlog5xx     = 'The server reported an error (HTTP %d). Check that contact in Cloudlog before sending it again.';
   SLoggerWhyCloudlogRejected = 'The server did not take this contact (for example, it already has it).';
   SLoggerWhyCloudlogUrl     = 'The address must start with https:// (or http://).';
   SLoggerWhyCloudlogRedirect = 'The address redirects somewhere the program will not follow. Check the address (try https://, and /index.php at the end).';
   SLoggerWhyCloudlogSetup   = 'The address, station profile id or API key is empty.';
   SLoggerWhyCloudlogBadRequest = 'The server said the request was malformed.';
   SLoggerWhyCloudlogUnreadable = 'The server''s answer was not understood. Check that contact in Cloudlog before sending it again.';
   SLoggerWhyCloudlogNoChange = 'Cloudlog and Wavelog cannot change or delete a contact that was already sent.';
   (* THE STANDALONE "EXTERNAL LOGGERS" WINDOW (NY4I, 2026-11-24: the status of
      every logger, Resync, and a way to the settings page, without going
      into Preferences each time). SLoggersWindowTitle is also the Windows
      menu row's text and so the window's title. Its columns reuse the
      Preferences grid's captions (the SLoggerGrid strings). *)
   SLoggersWindowTitle       = 'External loggers';
   SLoggersWindowResync      = 'Resync...';
   SLoggersWindowEdit        = 'Edit / add...';
   SLoggersWindowOn          = 'On';
   SLoggersWindowOff         = 'Off';
   SLoggerPlainHttpRefusedNotice ='nothing was sent: the address is plain http. Use https, or tick Allow insecure in this logger''s settings, save, and restart TR4W.';
   (* THE CLOUDLOG / WAVELOG "FIND..." BUTTON beside the Station profile
      (NY4I, 2026-11-24): one read-only GET of the station locations the key's
      owner has, to pick the NUMBER from. Nothing is sent that is not a read;
      no contact is posted. Every sentence below is shown in the editor. *)
   SLoggerFindCaption        = 'Find...';
   SLoggerFindLoading        = 'Looking up the station locations...';
   SLoggerFindPickCaption    = 'Station location';
   SLoggerFindPickPrompt     = 'Pick the station location this logger sends to:';
   SLoggerFindInactive       = 'inactive';
   SLoggerFindNoAddress      = 'Enter the Cloudlog / Wavelog address first.';
   SLoggerFindNoKey          = 'Enter the API key first.';
   SLoggerFindPlainHttp      = 'Nothing was sent: the address is plain http. Use https, or tick Allow insecure (plain http) and try again.';
   SLoggerFindBadAddress     = 'Nothing was sent: the address must start with https:// (or http:// with Allow insecure ticked).';
   SLoggerFindSecure         = 'A secure (https) connection could not be set up, so nothing was sent. The certificate was refused, or the TLS library or the certificate file is missing. The log has the detail.';
   SLoggerFindNoAnswer       = 'There was no answer from the server. Check the address and that the server is reachable.';
   SLoggerFind401            = 'The server refused the key (HTTP 401): it is wrong, or it is not allowed to read station locations.';
   SLoggerFind404            = 'The server answered 404: the address is probably wrong. If the site has no URL rewriting, end the address with /index.php.';
   SLoggerFindHttp           = 'The server answered HTTP %d, not a list of station locations. Check the address.';
   SLoggerFindNotList        = 'The server''s answer was not a list of station locations. Check the address.';
   SLoggerFindEmpty          = 'No station locations were found for this key.';

   (* THE TAILCAT ADDRESS ROW on Preferences > Network (issue 293): the
      string a server operator gives a remote position to reach the multi-op
      server through a Tailcat tunnel. *)
   SPrefsNetTailcatCaption   = 'Tailcat address:';
   SPrefsNetTailcatHint      = 'To reach a server on another network, paste the address its operator gave you and tick Use Tailcat. Server above is then not used. Treat the address like a password.';
   (* The checkbox beside the address (NY4I, 2026-11-12). "Tailcat" is a
     product name and is not translated. *)
   SPrefsNetUseTailcat       = 'Use Tailcat';

   (* A VALUE TOO LONG FOR WHERE IT IS KEPT -- issue 302. Both places hold 255
      BYTES, which is fewer characters when the text is not plain ASCII, so
      the text says bytes. The editor's dialog stays open after its message.
      %0:d is the length of what was typed, %1:d the limit. *)
   SMessageEditTextTooLong    = 'The message is %0:d bytes long and a message holds %1:d. Shorten it and press OK again.';
   SMessageEditCaptionTooLong = 'The caption is %0:d bytes long and a caption holds %1:d. Shorten it and press OK again.';
   (* A WORD IN BRACES THAT TR4W DOES NOT KNOW (2026-11-20). In a program
      message, {NAME} is a command from the List of commands, or {ROVERCALL}
      or {ROVERQTH}. %0:s is the word as typed, without its braces. The
      editor refuses to save the message; the dialog stays open. *)
   SMessageEditUnknownWord    = 'TR4W does not know the word {%0:s}. Use a command from the List of commands, {ROVERCALL} or {ROVERQTH}, and press OK again.';
   (* On the status line when a message being sent names a word TR4W does
      not know: the word is skipped and nothing of it is sent. %0:s is the
      word, without its braces. *)
   SMessageUnknownWordSkipped = 'The message names {%0:s}, which TR4W does not know. It was skipped and not sent.';
   (* The network pass words ({PASS B}, {PASS 14000}, {LASTPASSEDFREQ}): a
      message that cannot be filled in is NOT SENT, and these say why.
      %0:s is the word's argument as written (the station or band) and, for
      the two that name the station, its computer id. *)
   SNetStationMissing = 'Missing';
   SPassNeedsName ='A {PASS} word needs a station or a band, for example {PASS B} or {PASS 14000}. The message was not sent.';
   SPassNotABand = '{PASS %0:s} is not a band. Use a band in kHz, for example 14000. The message was not sent.';
   SPassBandEmpty = 'No other station is on the %0:s kHz band, so {PASS %0:s} cannot be filled in. The message was not sent.';
   SPassStationAbsent = 'Station %0:s is not on the network, so {PASS %0:s} cannot be filled in. The message was not sent.';
   SPassStationIsUs = '{PASS %0:s} names this computer. Name another position. The message was not sent.';
   SPassNoFrequency = 'Station %0:s is on the network but has not reported a frequency yet. The message was not sent.';
   SPassNothingPassed = '{LASTPASSEDFREQ} has nothing to send: no frequency has been passed yet. Use {PASS B} first. The message was not sent.';
   (* On the status line when a shared setting is too long for the network:
      %0:s is the setting's name, %1:d its length, %2:d the limit. The setting
      is still changed on this station. *)
   SNetParameterTooLong       = '%0:s was not sent to the other stations: it is %1:d bytes and the network carries %2:d.';
   (* On the status line when an intercom line or a spot text is too long for its
      network packet (issue 315): %0:d is its length in bytes, %1:d the limit.
      Nothing was sent. *)
   (* An export, report or Cabrillo file could not be written (issue 313): %0:s
      is the file, %1:s the reason in the system's words. Any earlier file of
      that name is unchanged. *)
   SExportNotWritten          = 'The file %0:s was NOT written: %1:s. An earlier file of that name, if there was one, is unchanged.';
   SNetTextTooLong            ='Not sent to the other stations: the text is %0:d bytes and the network carries %1:d.';

   (* WHAT THE RECEIVED EXCHANGE HOLDS, IN WORDS (issue 296) -- one phrase per
      field the open contest marks (TContestBase.ReceivedExchangeFields), put
      together by uExchangeHint.ExchangeHintText into, for example, "serial
      number and name". Lower case: they are read as part of one phrase.
      SExchangeHintAnd joins the last two: %0:s is everything before the last
      field (already separated by commas), %1:s the last field. *)
   SExchangeHintSignalReport   = 'signal report';
   SExchangeHintSerialNumber   = 'serial number';
   SExchangeHintPrecedence     = 'precedence';
   SExchangeHintCheck          = 'check';
   SExchangeHintName           = 'name';
   SExchangeHintAge            = 'age';
   SExchangeHintClass          = 'class';
   SExchangeHintChapter        = 'chapter';
   SExchangeHintPower          = 'power';
   SExchangeHintZone           = 'zone';
   SExchangeHintLicenseYear    = 'license year';
   SExchangeHintYearsLicensed  = 'years licensed';
   SExchangeHintZoneOrSociety  = 'zone or society';
   SExchangeHintQTH            = 'QTH';
   SExchangeHintTenTenNumber   = '10-10 number';
   SExchangeHintFOCNumber      = 'FOC number';
   SExchangeHintRandomChars    = 'random characters';
   SExchangeHintAnd            = '%0:s and %1:s';

   (* Tools -> Commands (issue 87 step 0): one item per call-window command.
     Each caption leads with the word the call window accepts, so the menu
     also teaches what can be typed there. *)
   SCmdMenuCommands      = 'Commands';
   SCmdMenuADIF          = 'ADIF - export the log as ADIF';
   SCmdMenuCAB           = 'CAB - export the log as Cabrillo';
   SCmdMenuCMD           = 'CMD - open a command prompt';
   SCmdMenuCOL           = 'COL - colours';
   SCmdMenuCWOFF         = 'CWOFF - turn CW off';
   SCmdMenuCWON          = 'CWON - turn CW on';
   SCmdMenuEXIT          = 'EXIT - exit TR4W';
   SCmdMenuNOTE          = 'NOTE - add a note to the log';
   SCmdMenuOPON          = 'OPON - operator log-in';
   SCmdMenuSCORE         = 'SCORE - send the score by UDP';
   SCmdMenuSUM           = 'SUM - summary sheet';
   SCmdMenuUDP           = 'UDP - send the whole log by UDP';
   SCmdMenuWCY           = 'WCY - ask the cluster for SH/WCY';
   SCmdMenuWWV           = 'WWV - ask the cluster for SH/WWV';
   SCmdMenuPREF          = 'PREF - Preferences';
   SCmdMenuROVER         = 'ROVER - where this station is roving';
   (* What the call window's CWON command says once CW is on. *)
   SCallWindowCWOn       = 'CW On';

   (* ALT-K OUTSIDE CW MODE (issue 23, NY4I option A): the key toggles the
     voice keyer in Phone, Digital and FM, as it did in D7, so its menu item
     says so. In CW mode the item keeps RC_KILLCW ('Toggle CW'). *)
   SMenuToggleVoiceKeyer = 'Toggle Voice Keyer';

   (* ROVING (issues 133 and 87): where a roving station operates now. A unit
     is one of the contest's own places -- a county, a Hawaii district. *)
   SRoverNoUnit          = 'No place was given';
   (* %0:s is the unit as typed, upper-cased. *)
   SRoverUnknownUnit     = '%0:s is not one of this contest''s places';
   (* %0:d is the contest's county-line limit. *)
   SRoverTooManyUnits    = 'This contest allows at most %0:d places at once';
   SRoverDialogTitle     = 'Rover';
   SRoverDialogPrompt    = 'Where this station operates now (one place, or several ' +
                           'at a county line, separated by a space, a comma or a dash)';
   SRoverDialogOK        = 'OK';
   SRoverDialogOff       = 'Rover off';
   SRoverDialogCancel    = 'Cancel';
   (* The main window's ROVER panel and the notice. %0:s is the call on the
     air: MY CALL and the places, as a boundary station signs them --
     NY4I/KOH/KON. *)
   SRoverStatus          = 'ROVER %0:s';
   SRoverTurnedOff       = 'Rover off';
   SRoverNoPlaces        = 'This contest has no places to rove';

   { ------------------------------------------------------- setup wizard --- }

   (* The setup wizard (uSetupWizardForm): opens by itself on a brand-new
     install and from Tools -> Setup Wizard.  Every caption on the form comes
     from here; the .lfm text is a designer placeholder. *)
   SWizMenu              = 'Setup Wizard...';
   SWizTitle             = 'TR4W setup';
   (* %0:d is this page's number, %1:d how many pages the wizard has now --
     the count changes as items are ticked on the checklist. *)
   SWizStepOf            = 'Step %0:d of %1:d';
   SWizBack              = '< Back';
   SWizNext              = 'Next >';
   SWizCreate            = 'Create configuration';
   SWizCancel            = 'Cancel';
   SWizClose             = 'Close';

   SWizStationHeading    = 'Your station';
   SWizStationIntro      = 'Who you are and where you are. Only the callsign is required, and all of this can be changed later in Preferences > Station.';
   SWizDerivedNote       = 'CQ zone, ITU zone, country and continent are filled in from the callsign. Correct any that are wrong.';
   SWizNoCountry         = 'The country file does not know this callsign, so nothing was filled in from it.';
   SWizCtyMissing        = 'There is no country file yet, so the zones and country cannot be filled in from the callsign.';
   SWizCtyDownload       = 'Download country file';
   SWizCtyDownloading    = 'Downloading the country file...';
   SWizCtyDone           = 'The country file was downloaded.';
   SWizCtyFailed         = 'The country file could not be downloaded. tr4w.log says why. You can try again, or continue without it.';
   SWizCallsign          = 'Callsign:';
   SWizName              = 'First name:';
   SWizGrid              = 'Grid square:';
   SWizCQZone            = 'CQ zone:';
   SWizITUZone           = 'ITU zone:';
   SWizState             = 'State/Province:';
   SWizSection           = 'ARRL section:';
   SWizCountry           = 'Country:';
   SWizContinent         = 'Continent:';
   SWizPostal            = 'Postal code:';
   SWizCallbookFilled    = 'Some details were filled in from the callbook (hamdb.org). Please check them.';
   SWizCallRequired      ='Enter your callsign to continue.';
   (* %s is the callsign as typed.  Queried, never refused: special-event and
     unusual calls are real (the Preferences Station page asks the same). *)
   SWizCallOdd           = '"%s" does not look like a regular callsign.'#13#10#13#10'Use it anyway?';

   SWizChecklistHeading  = 'What else would you like to set up now?';
   SWizChecklistIntro    = 'Tick what you have. Anything left unticked can be set up later in Preferences.';
   SWizItemRadio         = 'A radio (rig control)';
   SWizItemRadioHint     = 'TR4W reads and sets the frequency and mode.';
   SWizItemKeyer         = 'A WinKeyer';
   SWizItemKeyerHint     = 'A WinKeyer CW keyer on its own port.';
   SWizItemCluster       = 'A DX cluster';
   SWizItemClusterHint   = 'DX spots in the band map.';

   SWizRadioHeading      = 'Radio';
   SWizRadioIntro        = 'Choose your radio and how it is connected. These are the same settings Preferences uses. TR4W connects to it when you create the configuration.';
   (* The two CW choices on the radio page, offered only for a radio that can
     do them.  Both end up in the station profile, as in Preferences > Hardware. *)
   SWizRadioCWByCAT      = 'Send CW through the radio (CW by CAT)';
   SWizRadioSpeedSync    = 'Keep the radio''s CW speed in step with TR4W';
   SWizKeyerHeading      = 'WinKeyer';
   (* THE NAME A NEW LIBRARY ENTRY STARTS WITH, in the setup wizard and in
     Preferences' New buttons alike, so the two agree. A display name the
     operator can change, never a key: the store makes it unique ('Radio 2'). *)
   SDefaultRadioName     = 'Radio';
   SDefaultKeyerName     = 'WinKeyer';
   SDefaultClusterName   = 'Cluster';
   SWizKeyerIntro       = 'Choose the port your WinKeyer is on. A WinKeyer needs its own port, not the radio''s.';

   SWizClusterHeading    = 'DX cluster';
   SWizClusterIntro      = 'Pick a cluster from the list, or type its host name or IP address and its port. Leave the login blank to log in with your callsign.';
   SWizClusterServer     = 'Server:';
   SWizClusterServerHint = 'A host name or an IP address, for example dxc.nc7j.com or 192.168.1.5. Leave the port blank for the standard port, 23.';
   SWizClusterPort       = 'Port:';
   SWizClusterPortBad    = 'The port must be a number from 1 to 65535, or blank.';
   SWizClusterLogin      = 'Login callsign:';
   SWizClusterPassword   = 'Password:';
   SWizClusterCommand    = 'After connecting:';
   SWizClusterNeeded     = 'Enter a cluster server, or go back and untick it.';

   SWizResultHeading     = 'Done';
   SWizResultIntro       = 'This is what was saved. All of it can be changed later in Preferences.';
   (* %s is the callsign. *)
   SWizResStation        = 'Station %s saved.';
   (* %0:s is the setting's name, %1:s the value that was refused. *)
   SWizResRefused        = '%0:s "%1:s" was not accepted. Set it in Preferences > Station.';
   (* %0:s is the radio type as the radio list names it, %1:s how it is
     connected (SWizResOnPort or SWizResAtAddress), %2:s the radio's name. *)
   SWizResRadio          = 'Radio 1: %0:s %1:s. Name: "%2:s".';
   (* %s is a serial port, such as COM3, or a network address:port. *)
   SWizResOnPort         = 'on %s';
   SWizResAtAddress      = 'at %s';
   SWizResNoPort         = 'with no port chosen yet';
   SWizResCWByCAT        = 'CW is sent through the radio (CW by CAT).';
   SWizResSpeedSync      = 'The radio''s CW speed follows the speed set in TR4W.';
   SWizResRadioFailed    = 'The radio was not saved: %s. Set it up in Preferences > Radios.';
   (* %0:s is the keyer's name, %1:s its port. *)
   SWizResKeyer          = 'WinKeyer "%0:s" on %1:s, used for CW on radio 1.';
   SWizResKeyerFailed    = 'The WinKeyer was not saved: %s. Set it up in Preferences.';
   (* %0:s is the cluster's name, %1:s its server and port, %2:s the login. *)
   SWizResCluster        = 'DX cluster "%0:s": %1:s, logging in as %2:s.';
   SWizResLoginAsStation = 'your station callsign';
   SWizResShowDetails    = 'Show details';
   (* The detail lines, each indented under the line above.  Never a password:
     only whether one was set. *)
   SWizDetSerial         = '   Serial: %0:s baud, %1:s, RTS %2:s, DTR %3:s';
   SWizDetNetworkUser    = '   Network user: %s';
   SWizDetNetworkPassword = '   Network password: set';
   SWizDetPolling        = '   Frequency polling: %0:s, every %1:s ms';
   SWizDetKeyerPort      = '   The radio''s keyer output port: %s';
   SWizDetStartup        = '   Startup command: %s';
   SWizDetKeyerMode      = '   Mode %0:s, sidetone %1:s';
   SWizDetClusterCommand = '   After connecting: %s';
   SWizDetClusterPassword = '   Password: set';
   SWizDetOn             = 'on';
   SWizDetOff            = 'off';
   SWizResClusterFailed  = 'The DX cluster was not saved. Set it up in Preferences > DX Cluster.';
   (* %s is the station profile's name -- "Default" on a new install. *)
   SWizResProfile        = 'The station profile "%s" now holds the hardware you set up. You can refine it in Preferences > Hardware.';
   (* Asked before the New Contest window, on a brand-new install. *)
   SWizStartupPrompt     = 'This looks like a new installation. Would you like to run the Setup Wizard first?';
   (* %s lists the ports that collide, one per line. *)
   SWizResPortWarning   = 'Check these ports:'#13#10'%s';
   (* %s is the reason. *)
   SWizResApplyFailed    = 'Saved, but not put into use: %s. Restart TR4W or use Activate in Preferences.';
   SWizResNotSaved       = 'The radio, keyer and cluster were not saved: %s';
   SWizPrefsOpen         = 'Close Preferences first, so the setup wizard and Preferences do not overwrite each other''s changes.';

   (* THE SETUP WIZARD'S EXTERNAL LOGGER, ROTATOR AND WSJT-X ITEMS (issue 334).
     A rotator's first name, in the wizard and in Preferences' Add alike; the
     store makes it unique ('Rotator 2'). *)
   SDefaultRotatorName   = 'Rotator';
   SWizItemLogger        = 'An external logger';
   SWizItemLoggerHint    = 'Each QSO also goes to DXKeeper, Club Log, QRZ, Cloudlog/Wavelog or another logbook.';
   SWizItemRotator       = 'An antenna rotator';
   SWizItemRotatorHint   = 'TR4W turns the antenna toward the station you are working.';
   SWizItemWSJTX         = 'WSJT-X';
   SWizItemWSJTXHint     = 'Decodes and logged QSOs come in from WSJT-X over UDP.';
   SWizLoggerHeading     = 'External logger';
   SWizLoggerIntro       = 'Choose the program or service that should receive your QSOs, and how to reach it. These are the same settings Preferences uses. Keys and passwords are kept in the system''s credential store.';
   SWizLoggerLoading     = 'The logbook list is still loading. Wait for it, then press Next again.';
   SWizRotatorHeading    = 'Rotator';
   SWizRotatorIntro      = 'Choose your rotator and how it is connected. It turns for every band; Preferences > Rotators can limit it to some.';
   SWizRotatorType       = 'Type:';
   SWizRotatorPort       = 'Serial port:';
   SWizRotatorAddress    = 'IP address:';
   SWizRotatorUDPPort    = 'UDP port:';
   SWizRotatorNeedsType  = 'Choose the rotator type, or go back and untick it.';
   SWizRotatorNeedsPort  = 'Choose the serial port the rotator is on, or go back and untick it.';
   SWizRotatorUDPPortBad = 'The UDP port must be a number from 1 to 65535, or blank.';
   SWizWSJTXHeading      = 'WSJT-X';
   SWizWSJTXIntro        = 'TR4W can take decodes and logged QSOs from WSJT-X and mark the calls you still need. In WSJT-X, set Settings > Reporting > UDP Server to 127.0.0.1 and the port below.';
   SWizWSJTXEnable       = 'Use WSJT-X with TR4W';
   SWizWSJTXPort         = 'UDP port:';
   SWizWSJTXPortBad      = 'The port must be a number from 1 to 65535.';
   (* The rest of Settings.Wsjtx, worded as Preferences' WSJT-X page words
     them.  Highlights: the colours are TR4W's own dupe and new-multiplier
     colours (uProgramMain sends them to the WSJT-X server). *)
   SWizWSJTXHighlights   = 'Send callsign highlighting to WSJT-X';
   SWizWSJTXHighlightsHint = 'WSJT-X colours the calls in its decode list that are dupes or new multipliers, in TR4W''s colours.';
   SWizWSJTXRadioControl = 'Let WSJT-X control the radio';
   (* %d is the TCP port of TR4W's DX Commander compatible interface, which
     exists only while this box is ticked. *)
   SWizWSJTXRadioControlHint = 'TR4W then offers a DX Commander compatible interface on TCP port %d, and that is what WSJT-X connects to when DX Commander is chosen as its radio.';
   SWizWSJTXMulticast    = 'Multicast group:';
   SWizWSJTXMulticastHint = 'Advanced. Leave it blank unless WSJT-X is configured to use a multicast group.';
   (* %0:s is the rotator's name, %1:s its type, %2:s how it is reached
     (SWizResOnPort, SWizResAtAddress, SWizResNoPort or SWizResDefaultAddress). *)
   SWizResRotator        = 'Rotator "%0:s": %1:s %2:s, turning for every band.';
   SWizResDefaultAddress = 'at the default address';
   SWizResRotatorFailed  = 'The rotator was not saved. Set it up in Preferences > Rotators.';
   (* %0:s is the logger's name, %1:s the provider (DXKeeper, Club Log ...). *)
   SWizResLoggerActive   = 'External logger "%0:s" (%1:s) receives each new QSO.';
   SWizResLoggerInactive = 'External logger "%0:s" (%1:s) is saved but not switched on. Switch it on in Preferences.';
   (* %s is the reason. *)
   SWizResLoggerFailed   = 'The external logger was not saved: %s';
   SWizResLoggerRestart  = 'The external logger starts sending the next time TR4W starts.';
   (* %s is the UDP port. *)
   SWizResWSJTXOn        = 'WSJT-X: TR4W listens on UDP port %s.';
   SWizResWSJTXOff       = 'WSJT-X: the integration is off.';
   (* %d is the DX Commander compatible interface's TCP port. *)
   SWizResWSJTXRadioControl = 'WSJT-X can control the radio through TCP port %d.';
   SWizResWSJTXHighlights = 'WSJT-X: TR4W sends it callsign highlighting.';
   (* %s is the multicast group, for example 224.0.0.1. *)
   SWizResWSJTXMulticast = 'WSJT-X: TR4W joins multicast group %s.';
   SWizResWSJTXRestart   = 'The WSJT-X change takes effect the next time TR4W starts.';

   (* THE BAND MAP. The right-click item that copies the selected spot as
      "CALL [entity] freq comment" (issue 183), and the country panel with the
      beam heading to the spotted call (issue 186): %0:s is the country's
      name, %1:d the heading in degrees. *)
   SBandMapCopySpot       = 'Copy spot';
   SBandMapCountryHeading = '%0:s  (%1:d deg)';
   (* THE BAND MAP'S TWO VIEW TOGGLES on its right-click menu: scroll the map
      to keep the radio's frequency in the middle (issue 246), and order the
      spots by the beam heading (issue 82). *)
   SBandMapCenterOnRadio  = 'Center on radio frequency';
   SBandMapSortByBeam     = 'Sort by beam heading';
   (* THE TEXT SIZE SUBMENU on the same menu: BAND MAP SIZE stepped up or
      down, or put back to its default. *)
   SBandMapTextSize       = 'Text size';
   SBandMapTextLarger     = 'Larger';
   SBandMapTextSmaller    = 'Smaller';
   SBandMapTextReset      = 'Reset';
   (* SEND SPOT: the tick that puts the station's section, state or county
      (its domestic multiplier) the program knows for the call into the
      comment -- never a serial number, RST or the rest of the exchange
      (issue 175; "Exchange in comment" until 2026-11-16). *)
   SSendSpotLocationInComment = 'Section/state/county in comment';
   (* THE DX CLUSTER SPOTTED THIS STATION (issue 68): %s is the call of the
      station that posted the spot, as the cluster gave it. *)
   SYouAreSpottedBy = 'You are spotted by %s.';

   (* SELF-SPOT (issue 188): Control -> Self-spot, the SPOTME macro command and
      the automatic spot. A REFUSAL always says why and that NOTHING was sent. *)
   SMenuSelfSpot              = 'Self-spot';
   SSelfSpotSent              = 'Self-spot sent: %0:s on %1:s.';
   SSelfSpotNotAllowed        = 'Self-spot refused: this contest''s rules do not allow spotting yourself. Nothing sent.';
   SSelfSpotSearchAndPounce   = 'Self-spot refused: not in Search & Pounce mode. Nothing sent.';
   SSelfSpotNoCall            = 'Self-spot refused: there is no station call set. Nothing sent.';
   SSelfSpotNoFrequency       = 'Self-spot refused: the radio has not reported a frequency. Nothing sent.';
   SSelfSpotNoLink            = 'Self-spot refused: neither the DX cluster nor the network is connected. Nothing sent.';
   SSelfSpotTooSoon           = 'Self-spot refused: the last one was sent less than %d minutes ago. Nothing sent.';
   SSelfSpotNotMoved          = 'Self-spot refused: the VFO has not moved %d Hz since the last self-spot. Nothing sent.';

   (* PTT BY CAT (issue 36).  %s is the radio's model name.  Shown once per
     session for a radio the feature matrix says CANNOT be keyed by a CAT
     command; nothing is refused -- the command is still sent. *)
   SRadioPTTByCATNotSupported = '%s: PTT via CAT is not supported by this radio. Use a hardware PTT line, or turn off "Key the transmitter with a CAT command".';

   (* A LOOSE CATALOGUE IN FORCE (2026-11-24).  Shown once per start, after the
     main window is up, when languages\<lang>\tr4w.po in the data directory
     replaced the translations built into the program.  The first %s is the
     file's full path, the second its date (yyyy-mm-dd); keep them in that
     order.  Twenty-one such files sat unnoticed for three months and hid
     every later translation fix, with one information line in the log. *)
   SLanguageFileOverrides     = 'Language file %s overrides the built-in translations (dated %s)';

implementation

end.

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
   SWRLSetup = 'Set up World Radio League...';
   SWRLTitle = 'World Radio League';
   SWRLApiKey = 'API key:';
   SWRLValidate = 'Validate key and load logbooks';
   SWRLLogbook = 'Destination logbook:';
   SWRLNewLogbook = 'New logbook name:';
   SWRLCreate = 'Create logbook';
   SWRLUse = 'Use this logbook';
   SWRLCancel = 'Cancel';
   SWRLWorking = 'Contacting World Radio League...';
   SWRLReady = 'Key validated. Select a logbook, or create one.';
   SWRLFailure = 'WRL could not complete the request: %s';
   SWRLUncertain = 'WRL may have saved the request. Reload the logbooks before trying to create it again.';
   SWRLRestart = 'WRL is configured. Apply these settings and restart TR4W to use this logbook.';
   SWRLSummary = 'WRL delivery: pending %d; sending %d; up to date %d; uncertain %d; failed %d. Reopen Preferences to refresh.';
   SWRLStatusUnavailable = 'WRL delivery status is unavailable for the current log.';
   SWRLDeliveryIssue = 'World Radio League delivery needs attention. %s. Local logging continues; check the TR4W log and WRL delivery records.';

   // EDIT QSO -- the read-only external-logger delivery line under "Our
   // station for this QSO". Line: logger, state, then the sent clause.
   // Example: "External logger WRL: up to date. Last sent 2026-10-31 14:05 UTC"
   SEditQSODeliveryLine      = 'External logger %s: %s. %s';
   SEditQSODeliveryLastSent  = 'Last sent %s UTC';
   SEditQSODeliveryNeverSent = 'Not sent yet';
   SEditQSODeliveryPending   = 'pending';
   SEditQSODeliverySending   = 'sending';
   SEditQSODeliverySynced    = 'up to date';
   SEditQSODeliveryUncertain = 'uncertain';
   SEditQSODeliveryFailed    = 'failed';
   SEditQSODeliveryFailedWithCode = 'failed (%s)';
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

   { TR4W COULD NOT OPEN tr4w.log, AND KEPT RUNNING.  %s is the reason as the
     RTL gives it, which names the file.  The last sentence is the cost that
     matters to an operator: a fault reported from this session may have no
     log behind it. }
   SLogFileUnavailable =
      'TR4W could not open its log file.' + sLineBreak + sLineBreak +
      '%s' + sLineBreak + sLineBreak +
      'TR4W will keep running and keep trying to open it. Until it can, ' +
      'nothing from this session is written to the log.';

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

   (* Shown INSTEAD of an OS error code when the file is simply absent -- see
     TF.UnableToFindFileMessage for why an errno is the wrong thing to print
     in that case. *)
   SFileNotFoundThere = 'TR4W could not find this file:';

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

   (* CATCHING UP AFTER A LINK THAT WAS DOWN (Phase 1, C5, 2026-10-27). Said once
     per link, when the QSOs logged and the edits made while this station was
     disconnected have been handed to the server. %d: how many QSOs, then how
     many edits. *)
   SNetResent =
      'Resent to the server what was logged while disconnected: %d QSO(s), ' +
      '%d edit(s).';

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

   (* A QSO PARTY'S OUT-OF-STATE STATION WORKING ANOTHER OUT-OF-STATE ONE.
     NY4I, 2026-10-02: "It's not valid for a fl station to work an Idaho or
     VE station in the NC QSO party", "we should refuse to log it and show an
     error like we would with an invalid county".  %s is the host state. *)
   SExchangeOutOfStateWorksHostOnly = 'Out of state: work %s stations only';

   (* A WORD OF AN RST-AND-GRID EXCHANGE THAT IS NEITHER -- Q115, NY4I
     2026-10-18. The parser used to drop such a word silently, so '599 FN3'
     logged a QSO with no grid. %s is the word as typed. *)
   SExchangeNotAGridOrReport = '%s is not a grid square or a signal report';

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

   (* --------------------------------------------- the contest UI (M9b) - *)

   (* AN INACTIVE CONTEST'S LINE IN THE NEW CONTEST DROP-DOWN. NY4I,
     2026-10-02: "inactive contests go at the bottom of the drop down". Since
     Q59 (2026-10-19) they are listed only when "Show inactive contests" is
     ticked, and cannot be chosen for a new contest; the mark says why. %s is
     the contest's display name. *)
   SContestInactive = '%s (inactive)';

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
     locally. Each of the first three is shown ONCE per change of state, on
     the status line; %s is the folder, and in SBackupCopyFailed the second
     %s is the reason, in English. *)
   SBackupDestinationReachable = 'Backup destination %s is reachable.';
   SBackupCopyFailed =
      'Backups are NOT reaching %s: %s. Logging continues, and TR4W keeps trying.';
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

implementation

end.

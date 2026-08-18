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
unit uSettingsDeclarations;
{$I tr4w.inc}

{
  WHAT SETTINGS EXIST, and what each one is called.

  Every setting the Preferences window edits is declared here with a MODERN KEY
  -- 'operating.cw.sayHi' -- and, while it still lives in CFGCA, the legacy
  command name it currently maps to.

  WHY THE KEY AND THE COMMAND ARE DIFFERENT.  The key is ours: it is what the
  JSON file holds, what a panel binds to, and it is stable.  The command is the
  legacy spelling, and it is on its way out.  Keeping them separate means the
  day 'SAY HI ENABLE' stops existing, the key does not change, the JSON does not
  change, and no panel changes -- only the line here.

  THE ORDER OF MIGRATION, so it is clear what a line means:

    RegisterLegacySetting(key, 'COMMAND', caption)
        still a CFGCA row.  Read and written through CheckCommand, so its
        bounds and crA hook still run.  Most settings are here today.

    RegisterSetting(TBoolSetting.Create(key, caption, getter, setter))
        graduated: a typed closure over the global it actually lives in.  No
        pointer, no type tag.

    RegisterSetting(TBoolSetting.Own(key, caption, default))
        fully modern: the registry holds the value, there is no global, and
        nothing in CFGCA knows about it.  All NEW settings look like this.

  A panel cannot tell the three apart -- that is the point.  Graduating a
  setting is a one-line change here.

  WHY ONE UNIT RATHER THAN SELF-REGISTRATION NEXT TO EACH OWNER, which is what
  the radio factory does and what this unit's header would otherwise recommend:
  these settings' owners are TRDOS units that predate any of this and that we
  are deliberately not editing.  Putting a registration line inside LOGSTUFF to
  be tidy would touch proven contest code for a settings screen's benefit.  As
  settings graduate onto real objects, their registrations should move to those
  objects and this unit should shrink.
}

interface

{ Called once at startup, before any settings UI can open.  Idempotent: calling
  it twice is a no-op rather than a duplicate-key exception, because a second
  entry point appearing later is more likely than not. }
procedure DeclareAllSettings;

implementation

uses
  uConfigValues,
   uSettingsRegistry,
   uSettingsLegacy;   // RegisterLegacySetting -- no FMX

var
   GDeclared: boolean = False;

procedure DeclareAllSettings;
begin
   if GDeclared then
      begin
      Exit;
      end;
   GDeclared := True;

   // --- Operating: CW ------------------------------------------------------
   RegisterStoredSetting('operating.cw.sayHi',            'SAY HI ENABLE',
                         'Send a greeting to stations worked before');
   RegisterStoredSetting('operating.cw.sayHiRateCutoff',  'SAY HI RATE CUTOFF',
                         'Stop above this rate');
   RegisterStoredSetting('operating.cw.keypadMemories',   'KEYPAD CW MEMORIES',
                         'Number keypad sends CW memories');
   RegisterStoredSetting('operating.cw.leadingZeros',     'LEADING ZEROS',
                         'Leading zeros');
   RegisterStoredSetting('operating.cw.leadingZeroChar',  'LEADING ZERO CHARACTER',
                         'Leading zero sent as');

   // Radio serial keying.  These shape only the CW TR4W generates itself by
   // toggling DTR/RTS -- a WinKeyer, a YCCC box or CW-by-CAT keep their own
   // timing -- which is why they sit in their own frame rather than beside the
   // settings that apply to every keyer.
   RegisterStoredSetting('operating.cw.serial.ditDahRatio',    'DIT DAH RATIO',
                         'Dit/dah ratio');
   RegisterStoredSetting('operating.cw.serial.weight',         'WEIGHT',
                         'Weight');
   RegisterStoredSetting('operating.cw.serial.farnsworth',     'FARNSWORTH ENABLE',
                         'Farnsworth spacing');
   RegisterStoredSetting('operating.cw.serial.farnsworthSpeed','FARNSWORTH SPEED',
                         'Character speed');

   // --- CW Settings (the keyer page) ---------------------------------------
   RegisterStoredSetting('cw.enable',            'CW ENABLE',
                         'Send CW');
   RegisterStoredSetting('cw.speedFromDatabase', 'CW SPEED FROM DATABASE',
                         'Match the speed a station was worked at before');
   // MIGRATED 2026-08-14 -- the first row to graduate.  Stored: writes go to
   // settings\tr4w.json, the CFGCA row is csJSON, and so it no longer appears
   // in Ctrl-J nor in tr4w.ini.  The two halves must stay in step; see
   // docs/CFG_MIGRATION_PLAN.md.
   RegisterStoredSetting('cw.speedIncrement',    'CW SPEED INCREMENT',
                         'Speed step');
   RegisterStoredSetting('cw.tone',              'CW TONE',
                         'Sidetone');

   { CW SENDING BEHAVIOUR. These shape what the keyer sends and how, whichever
     keyer is selected -- unlike the serial-keying group above, which only
     affects CW TR4W generates itself. }
   RegisterStoredSetting('cw.messagesChainable',  'ALL CW MESSAGES CHAINABLE',
                         'Any message may chain into the next');
   RegisterStoredSetting('cw.tuneWithDits',       'TUNE WITH DITS',
                         'Tune with dits rather than a solid carrier');
   RegisterStoredSetting('cw.sendFourLetterCall', 'SEND COMPLETE FOUR LETTER CALL',
                         'Always send all four letters of a four-letter call');

   { The F-key button captions, 2026-08-15. }
   RegisterStoredSetting('cw.includeFKeyNumber',              'INCLUDE F-KEY NUMBER',
                         'Show the key number on the function-key buttons');

   { The old Appearance menu's contents, 2026-08-15. }
   RegisterStoredSetting('appearance.noBorder',               'NO BORDER',
                         'Main window has no border');
   RegisterStoredSetting('appearance.noCaption',              'NO CAPTION',
                         'Main window has no title bar');
   RegisterStoredSetting('appearance.noColumnHeader',         'NO COLUMN HEADER',
                         'Hide the log column headings');
   RegisterStoredSetting('appearance.showGridlines',          'SHOW GRIDLINES',
                         'Draw gridlines in the log');

   { Audio: MP3 recording and the digital voice keyer, 2026-08-15. }
   RegisterStoredSetting('audio.mp3.recorderEnable',          'MP3 RECORDER ENABLE',
                         'Record each QSO to MP3');
   RegisterStoredSetting('audio.mp3.path',                    'MP3 PATH',
                         'Folder for MP3 recordings');
   RegisterStoredSetting('audio.mp3.player',                  'MP3 PLAYER',
                         'MP3 player program');
   RegisterStoredSetting('audio.dvk.enable',                  'DVK ENABLE',
                         'Use the digital voice keyer');
   RegisterStoredSetting('audio.dvk.localizedMessages',       'DVK LOCALIZED MESSAGES ENABLE',
                         'Use localized DVK message files');
   RegisterStoredSetting('audio.dvk.path',                    'DVK PATH',
                         'Folder for DVK recordings');
   RegisterStoredSetting('audio.dvk.recorder',                'DVK RECORDER',
                         'DVK recorder program');
   RegisterStoredSetting('audio.useRecordedSigns',            'USE RECORDED SIGNS',
                         'Send recorded audio for callsign characters');

   { PADDLE. The paddle keyer TR4W runs itself; a WinKeyer or YCCC box keeps its
     own. PADDLE PORT is deliberately NOT here -- it is a parallel port, and
     whether TR4W keeps supporting those is an open question (see the Hardware
     panel). Speed and tone are useful regardless of which port carries it. }
   RegisterStoredSetting('cw.paddle.speed',       'PADDLE SPEED',
                         'Paddle speed');
   RegisterStoredSetting('cw.paddle.monitorTone', 'PADDLE MONITOR TONE',
                         'Paddle sidetone');
   RegisterStoredSetting('cw.paddle.swap',        'SWAP PADDLES',
                         'Swap dit and dah');
   RegisterStoredSetting('cw.paddle.pttHoldCount','PADDLE PTT HOLD COUNT',
                         'Hold PTT for');

   { PTT. Not CW-only -- PTT ENABLE keys the transmitter for phone too -- but it
     is grouped with the keyer because that is where an operator changes it. }
   RegisterStoredSetting('ptt.enable',            'PTT ENABLE',
                         'Assert PTT when transmitting');
   RegisterStoredSetting('ptt.turnOnDelay',       'PTT TURN ON DELAY',
                         'Delay after PTT before sending');
   RegisterStoredSetting('ptt.noPollDuringPTT',   'NO POLL DURING PTT',
                         'Stop polling the radio while transmitting');

   { Operating and PTT, 2026-08-15. Captions follow each command's help entry:
     AUTO CALL TERMINATE stops sending when the call window changes, and
     CONFIRM EDIT CHANGES asks before an edited QSO is written back. }
   RegisterStoredSetting('ptt.viaCommands',                   'PTT VIA COMMANDS',
                         'Key the transmitter with a CAT command');
   RegisterStoredSetting('ptt.lockout',                       'PTT LOCKOUT',
                         'Lock out PTT');
   RegisterStoredSetting('operating.autoCallTerminate',       'AUTO CALL TERMINATE',
                         'Stop sending when the call window changes');
   RegisterStoredSetting('operating.autoReturnToCQ',          'AUTO RETURN TO CQ MODE',
                         'Return to CQ mode after logging');
   RegisterStoredSetting('operating.escapeExitsSAP',          'ESCAPE EXITS SEARCH AND POUNCE',
                         'Escape leaves search and pounce');
   RegisterStoredSetting('operating.leaveCursorInCall',       'LEAVE CURSOR IN CALL WINDOW',
                         'Leave the cursor in the call window');
   RegisterStoredSetting('operating.logWithSingleEnter',      'LOG WITH SINGLE ENTER',
                         'Log with a single Enter');
   RegisterStoredSetting('operating.spaceBarDupeCheck',       'SPACE BAR DUPE CHECK ENABLE',
                         'Space bar performs a dupe check');
   RegisterStoredSetting('operating.confirmEditChanges',      'CONFIRM EDIT CHANGES',
                         'Confirm before saving an edited QSO');
   RegisterStoredSetting('operating.autoQSONumberDecrement',  'AUTO QSO NUMBER DECREMENT',
                         'Give the serial number back when a QSO is abandoned');

   // --- Operating: bands ---------------------------------------------------
   // MIGRATED 2026-08-16, with the CFGCA rows flipped to csJSON in the same
   // commit.  These are SET BY THE CONTEST -- FCONTEST assigns them at fourteen
   // sites when a contest is selected -- and an earlier draft of the migration
   // plan held them back for that reason, as "contest properties wearing a
   // settings costume".  That line was withdrawn (NY4I, 2026-08-16): every
   // parameter belongs in the registry, and who writes it is a separate
   // question from where it is stored.
   //
   // Checked against the export rule before flipping, because that rule is what
   // COMPUTER ID broke: none of HFBandEnable / WARCBandsEnabled /
   // VHFBandsEnabled is read by PostUnit, uCbrSum, uADIF or uCabrillo*, so
   // csJSON is safe here rather than csOwned.  (Note the globals are spelled
   // inconsistently -- HFBandEnable but VHFBandsEnabled -- which makes a naive
   // grep under-report.)
   RegisterStoredSetting('operating.bands.hf',   'HF BAND ENABLE',
                         'HF (160 - 10 m)');
   RegisterStoredSetting('operating.bands.warc', 'WARC BAND ENABLE',
                         'WARC (30, 17, 12 m)');
   RegisterStoredSetting('operating.bands.vhf',  'VHF BAND ENABLE',
                         'VHF and up');

   // --- Operating: two radio -----------------------------------------------
   RegisterStoredSetting('operating.tworadio.enable',       'TWO RADIO MODE',
                         'Two radio mode');

   { Two radio and multi-op, 2026-08-15. Captions from each command's own entry
     in commands_help_eng.ini rather than invented -- IN BAND LOCKOUT is
     documented as "prevents Band Map selection that would place both radios on
     a single band", and MULTI MULTS ONLY decides whether all QSOs or only new
     multipliers are passed around the network. }
   RegisterStoredSetting('operating.tworadio.inBandLockout',  'IN BAND LOCKOUT',
                         'Stop both radios landing on one band');
   RegisterStoredSetting('operating.tworadio.qsyInactive',    'QSY INACTIVE RADIO',
                         'QSY the inactive radio');
   RegisterStoredSetting('operating.tworadio.swapRelaySense', 'SWAP RADIO RELAY SENSE',
                         'Invert the radio relay sense');
   RegisterStoredSetting('operating.tworadio.waitForStrength', 'WAIT FOR STRENGTH',
                         'Wait for a signal strength reading');
   RegisterStoredSetting('network.multiMultsOnly',            'MULTI MULTS ONLY',
                         'Pass only new multipliers around the network');
   RegisterStoredSetting('network.intercomFile',              'INTERCOM FILE ENABLE',
                         'Log network messages to INTERCOM.TXT');

   { Super Check Partial, band map and log files, 2026-08-15. }
   RegisterStoredSetting('scp.possibleCalls',                 'POSSIBLE CALLS',
                         'Offer possible calls');
   RegisterStoredSetting('scp.partialCall',                   'PARTIAL CALL ENABLE',
                         'Match on a partial callsign');
   RegisterStoredSetting('scp.wildcardPartials',              'WILDCARD PARTIALS',
                         'Allow wildcards in a partial');
   RegisterStoredSetting('scp.nameFlag',                      'NAME FLAG ENABLE',
                         'Flag a station whose name is known');
   RegisterStoredSetting('bandmap.callWindowShowAllSpots',    'CALL WINDOW SHOW ALL SPOTS',
                         'Show every spot in the call window');
   RegisterStoredSetting('bandmap.swapPacketSpotRadios',      'SWAP PACKET SPOT RADIOS',
                         'Send spots to the other radio');
   RegisterStoredSetting('logging.checkLogFileSize',          'CHECK LOG FILE SIZE',
                         'Warn when the log file grows unexpectedly');
   RegisterStoredSetting('logging.unknownCountryFile',        'UNKNOWN COUNTRY FILE ENABLE',
                         'Record callsigns with no country match');
   RegisterStoredSetting('logging.updateRestartFile',         'UPDATE RESTART FILE ENABLE',
                         'Keep the restart file up to date');
   RegisterStoredSetting('operating.tworadio.altDBuffer',   'ALT-D BUFFER ENABLE',
                         'Alt-D remembers what you typed');
   RegisterStoredSetting('operating.tworadio.altDCQ',       'ALT-D CQ ENABLE',
                         'Alt-D can start a CQ on the second radio');
   RegisterStoredSetting('operating.tworadio.blindCQ',      'ALWAYS CALL BLIND CQ',
                         'Always call a blind CQ');
   RegisterStoredSetting('operating.tworadio.skipActiveBand','SKIP ACTIVE BAND',
                         'Skip the band the other radio is on');

   // --- Operating: online scoring ------------------------------------------
   RegisterStoredSetting('scoring.hamscore.enable',      'HAMSCORE ENABLE',
                         'Post my score while the contest runs');
   RegisterStoredSetting('scoring.hamscore.url',         'HAMSCORE URL',
                         'Service URL');
   RegisterStoredSetting('scoring.hamscore.username',    'HAMSCORE USERNAME',
                         'Username');
   RegisterStoredSetting('scoring.hamscore.password',    'HAMSCORE PASSWORD',
                         'Password');
   RegisterStoredSetting('scoring.hamscore.contactInfo', 'HAMSCORE SEND CONTACT INFO',
                         'Include contact information');
   RegisterStoredSetting('scoring.board.postingUrl',     'SCORE POSTING URL',
                         'Posting URL');
   RegisterStoredSetting('scoring.board.readingUrl',     'SCORE READING URL',
                         'Reading URL');

   // --- DX cluster ---------------------------------------------------------
   RegisterStoredSetting('cluster.connectAtStartup', 'CONNECTION AT STARTUP',
                         'Connect at startup');
   // CONNECTION COMMAND is NOT registered as a flat setting. It belongs to the
   // cluster definition -- one cluster, one connect command -- and the cluster
   // editor in Preferences owns it. Registering it here as well gave one edit box
   // two stores, of which only the cluster one was ever read.
   //
   // The CFGCA row stays live (not csJSON) on purpose: a station with no cluster
   // library still has ApplyActiveCluster leave the legacy value alone, so an old
   // tr4w.ini CONNECTION COMMAND must keep working.

   { ===================================================================== }
   {  THE CTRL-J TAIL, registered 2026-08-16 so Ctrl-J can be retired.

     Every row that was still visible in Ctrl-J is registered here and its
     CFGCA row flipped to csOwned in the same commit.  csOwned hides a row
     from Ctrl-J while CheckCommand still applies the ini value, so this
     changes WHERE a setting is edited and nothing about how it loads --
     no behaviour change, and no exposure to the export rule.

     RegisterLegacySetting, not Stored: the write still goes to tr4w.ini,
     exactly as Ctrl-J's did.  Retiring the ini (csJSON) is a separate,
     per-row job -- only 6 of these are read by an export unit and must
     stay csOwned for ever; see docs/CTRLJ_INVENTORY.md.

     The key's PREFIX is the panel it renders on (contest., operating., ...)
     and is the only thing that decides placement, so regrouping later is a
     rename rather than moving controls in a designer.

     Captions are derived from the command name.  The COMMAND is what an
     operator will search for -- fifteen years of muscle memory -- and it is
     indexed alongside the caption, so a reworded caption costs nothing. }
   { ===================================================================== }

   // --- Contest (68) ----------------------------------
   RegisterLegacySetting('contest.autoQslInterval',     'AUTO QSL INTERVAL',
                          'Auto QSL Interval');
   RegisterLegacySetting('contest.autoCqDelayTime',     'AUTO-CQ DELAY TIME',
                          'Auto-CQ Delay Time');
   RegisterLegacySetting('contest.beepEvery10Qsos',     'BEEP EVERY 10 QSOS',
                          'Beep Every 10 QSOs');
   RegisterLegacySetting('contest.categoryAssisted',    'CATEGORY-ASSISTED',
                          'Category-Assisted');
   RegisterLegacySetting('contest.categoryBand',        'CATEGORY-BAND',
                          'Category-Band');
   RegisterLegacySetting('contest.categoryMode',        'CATEGORY-MODE',
                          'Category-Mode');
   RegisterLegacySetting('contest.categoryOperator',    'CATEGORY-OPERATOR',
                          'Category-Operator');
   RegisterLegacySetting('contest.categoryOverlay',     'CATEGORY-OVERLAY',
                          'Category-Overlay');
   RegisterLegacySetting('contest.categoryPower',       'CATEGORY-POWER',
                          'Category-Power');
   RegisterLegacySetting('contest.categoryTransmitter', 'CATEGORY-TRANSMITTER',
                          'Category-Transmitter');
   RegisterLegacySetting('contest.columnDupesheetEnable','COLUMN DUPESHEET ENABLE',
                          'Column Dupesheet Enable');
   RegisterLegacySetting('contest.contest',             'CONTEST',
                          'Contest');
   RegisterLegacySetting('contest.contestName',         'CONTEST NAME',
                          'Contest Name');
   RegisterLegacySetting('contest.contestTitle',        'CONTEST TITLE',
                          'Contest Title');
   RegisterLegacySetting('contest.countDomesticCountries','COUNT DOMESTIC COUNTRIES',
                          'Count Domestic Countries');
   RegisterLegacySetting('contest.customInitialExchangeString','CUSTOM INITIAL EXCHANGE STRING',
                          'Custom Initial Exchange String');
   RegisterLegacySetting('contest.domesticMultiplier',  'DOMESTIC MULTIPLIER',
                          'Domestic Multiplier');
   RegisterLegacySetting('contest.dxMultiplier',        'DX MULTIPLIER',
                          'DX Multiplier');
   RegisterLegacySetting('contest.exchangeMemoryEnable','EXCHANGE MEMORY ENABLE',
                          'Exchange Memory Enable');
   RegisterLegacySetting('contest.exchangeReceived',    'EXCHANGE RECEIVED',
                          'Exchange Received');
   RegisterLegacySetting('contest.gridMapCenter',       'GRID MAP CENTER',
                          'Grid Map Center');
   RegisterLegacySetting('contest.initialExchange',     'INITIAL EXCHANGE',
                          'Initial Exchange');
   RegisterLegacySetting('contest.initialExchangeCursorPos','INITIAL EXCHANGE CURSOR POS',
                          'Initial Exchange Cursor Pos');
   RegisterLegacySetting('contest.initialExchangeOverwrite','INITIAL EXCHANGE OVERWRITE',
                          'Initial Exchange Overwrite');
   RegisterLegacySetting('contest.literalDomesticQth',  'LITERAL DOMESTIC QTH',
                          'Literal Domestic Qth');
   RegisterLegacySetting('contest.logRsSent',           'LOG RS SENT',
                          'Log Rs Sent');
   RegisterLegacySetting('contest.logRstSent',          'LOG RST SENT',
                          'Log Rst Sent');
   RegisterLegacySetting('contest.lookForRstSent',      'LOOK FOR RST SENT',
                          'Look For Rst Sent');
   RegisterLegacySetting('contest.messageEnable',       'MESSAGE ENABLE',
                          'Message Enable');
   RegisterLegacySetting('contest.minitourDuration',    'MINITOUR DURATION',
                          'Minitour Duration');
   RegisterLegacySetting('contest.multByBand',          'MULT BY BAND',
                          'Mult By Band');
   RegisterLegacySetting('contest.multByMode',          'MULT BY MODE',
                          'Mult By Mode');
   RegisterLegacySetting('contest.multReportMinimumBands','MULT REPORT MINIMUM BANDS',
                          'Mult Report Minimum Bands');
   RegisterLegacySetting('contest.multSheetAutoReset',  'MULT SHEET AUTO RESET',
                          'Mult Sheet Auto Reset');
   RegisterLegacySetting('contest.multipleBands',       'MULTIPLE BANDS',
                          'Multiple Bands');
   RegisterLegacySetting('contest.multipleModes',       'MULTIPLE MODES',
                          'Multiple Modes');
   RegisterLegacySetting('contest.prefixMultiplier',    'PREFIX MULTIPLIER',
                          'Prefix Multiplier');
   RegisterLegacySetting('contest.qslMode',             'QSL MODE',
                          'QSL Mode');
   RegisterLegacySetting('contest.qsoByBand',           'QSO BY BAND',
                          'QSO By Band');
   RegisterLegacySetting('contest.qsoByMode',           'QSO BY MODE',
                          'QSO By Mode');
   RegisterLegacySetting('contest.qsoNumberByBand',     'QSO NUMBER BY BAND',
                          'QSO Number By Band');
   RegisterLegacySetting('contest.qsoPointMethod',      'QSO POINT METHOD',
                          'QSO Point Method');
   RegisterLegacySetting('contest.qsoPointsDomesticCw', 'QSO POINTS DOMESTIC CW',
                          'QSO Points Domestic CW');
   RegisterLegacySetting('contest.qsoPointsDomesticPhone','QSO POINTS DOMESTIC PHONE',
                          'QSO Points Domestic Phone');
   RegisterLegacySetting('contest.qsoPointsDxCw',       'QSO POINTS DX CW',
                          'QSO Points DX CW');
   RegisterLegacySetting('contest.qsoPointsDxPhone',    'QSO POINTS DX PHONE',
                          'QSO Points DX Phone');
   RegisterLegacySetting('contest.qtcEnable',           'QTC ENABLE',
                          'Qtc Enable');
   RegisterLegacySetting('contest.qtcExtraSpace',       'QTC EXTRA SPACE',
                          'Qtc Extra Space');
   RegisterLegacySetting('contest.qtcMinutes',          'QTC MINUTES',
                          'Qtc Minutes');
   RegisterLegacySetting('contest.qtcQrs',              'QTC QRS',
                          'Qtc Qrs');
   RegisterLegacySetting('contest.quickQslCwMessage',   'QUICK QSL CW MESSAGE',
                          'Quick QSL CW Message');
   RegisterLegacySetting('contest.quickQslCwMessage1',  'QUICK QSL CW MESSAGE1',
                          'Quick QSL CW Message1');
   RegisterLegacySetting('contest.quickQslKey1',        'QUICK QSL KEY 1',
                          'Quick QSL Key 1');
   RegisterLegacySetting('contest.quickQslKey2',        'QUICK QSL KEY 2',
                          'Quick QSL Key 2');
   RegisterLegacySetting('contest.quickQslMessage1',    'QUICK QSL MESSAGE 1',
                          'Quick QSL Message 1');
   RegisterLegacySetting('contest.quickQslMessage2',    'QUICK QSL MESSAGE 2',
                          'Quick QSL Message 2');
   RegisterLegacySetting('contest.quickQslSsbMessage',  'QUICK QSL SSB MESSAGE',
                          'Quick QSL SSB Message');
   RegisterLegacySetting('contest.r150sMode',           'R150S MODE',
                          'R150S Mode');
   RegisterLegacySetting('contest.randomCqMode',        'RANDOM CQ MODE',
                          'Random CQ Mode');
   RegisterLegacySetting('contest.remainingMultDisplayMode','REMAINING MULT DISPLAY MODE',
                          'Remaining Mult Display Mode');
   RegisterLegacySetting('contest.reverseInitialEx',    'REVERSE INITIAL EX',
                          'Reverse Initial Ex');
   RegisterLegacySetting('contest.rfoblMode',           'RFOBL MODE',
                          'Rfobl Mode');
   RegisterLegacySetting('contest.showAllSerialPorts',  'SHOW ALL SERIAL PORTS',
                          'Show All Serial Ports');
   RegisterLegacySetting('contest.showDomesticMultiplierName','SHOW DOMESTIC MULTIPLIER NAME',
                          'Show Domestic Multiplier Name');
   RegisterLegacySetting('contest.singleBandScore',     'SINGLE BAND SCORE',
                          'Single Band Score');
   RegisterLegacySetting('contest.sprintQsyRule',       'SPRINT QSY RULE',
                          'Sprint Qsy Rule');
   RegisterLegacySetting('contest.tenMinuteRule',       'TEN MINUTE RULE',
                          'Ten Minute Rule');
   RegisterLegacySetting('contest.zoneMultiplier',      'ZONE MULTIPLIER',
                          'Zone Multiplier');

   // --- Operating (34) --------------------------------
   RegisterLegacySetting('operating.ctrlj.askForFrequencies', 'ASK FOR FREQUENCIES',
                          'Ask For Frequencies');
   RegisterLegacySetting('operating.ctrlj.autoDisplayDupeQso','AUTO DISPLAY DUPE QSO',
                          'Auto Display Dupe QSO');
   RegisterLegacySetting('operating.ctrlj.autoDupeEnableCq',  'AUTO DUPE ENABLE CQ',
                          'Auto Dupe Enable CQ');
   RegisterLegacySetting('operating.ctrlj.autoDupeEnableSAndP','AUTO DUPE ENABLE S AND P',
                          'Auto Dupe Enable S And P');
   RegisterLegacySetting('operating.ctrlj.autoSPEnable',      'AUTO S&P ENABLE',
                          'Auto S&P Enable');
   RegisterLegacySetting('operating.ctrlj.autoSPEnableSensitivity','AUTO S&P ENABLE SENSITIVITY',
                          'Auto S&P Enable Sensitivity');
   RegisterLegacySetting('operating.ctrlj.autoTimeIncrement', 'AUTO TIME INCREMENT',
                          'Auto Time Increment');
   RegisterLegacySetting('operating.ctrlj.band',              'BAND',
                          'Band');
   RegisterLegacySetting('operating.ctrlj.clearDupeSheet',    'CLEAR DUPE SHEET',
                          'Clear Dupe Sheet');
   RegisterLegacySetting('operating.ctrlj.customUserString',  'CUSTOM USER STRING',
                          'Custom User String');
   RegisterLegacySetting('operating.ctrlj.deEnable',          'DE ENABLE',
                          'De Enable');
   RegisterLegacySetting('operating.ctrlj.digitalModeEnable', 'DIGITAL MODE ENABLE',
                          'Digital Mode Enable');
   RegisterLegacySetting('operating.ctrlj.distanceMode',      'DISTANCE MODE',
                          'Distance Mode');
   RegisterLegacySetting('operating.ctrlj.dupeCheckSound',    'DUPE CHECK SOUND',
                          'Dupe Check Sound');
   RegisterLegacySetting('operating.ctrlj.dupeSheetAutoReset','DUPE SHEET AUTO RESET',
                          'Dupe Sheet Auto Reset');
   RegisterLegacySetting('operating.ctrlj.frequencyMemory',   'FREQUENCY MEMORY',
                          'Frequency Memory');
   RegisterLegacySetting('operating.ctrlj.frequencyMemoryEnable','FREQUENCY MEMORY ENABLE',
                          'Frequency Memory Enable');
   RegisterLegacySetting('operating.ctrlj.frequencyPollRate', 'FREQUENCY POLL RATE',
                          'Frequency Poll Rate');
   RegisterLegacySetting('operating.ctrlj.ieSwitch',          'IE SWITCH',
                          'Ie Switch');
   RegisterLegacySetting('operating.ctrlj.incrementTimeEnable','INCREMENT TIME ENABLE',
                          'Increment Time Enable');
   RegisterLegacySetting('operating.ctrlj.logFrequencyEnable','LOG FREQUENCY ENABLE',
                          'Log Frequency Enable');
   RegisterLegacySetting('operating.ctrlj.logSubTitle',       'LOG SUB TITLE',
                          'Log Sub Title');
   RegisterLegacySetting('operating.ctrlj.mainCallsign',      'MAIN CALLSIGN',
                          'Main Callsign');
   RegisterLegacySetting('operating.ctrlj.mode',              'MODE',
                          'Mode');
   RegisterLegacySetting('operating.ctrlj.possibleCallAcceptKey','POSSIBLE CALL ACCEPT KEY',
                          'Possible Call Accept Key');
   RegisterLegacySetting('operating.ctrlj.possibleCallLeftKey','POSSIBLE CALL LEFT KEY',
                          'Possible Call Left Key');
   RegisterLegacySetting('operating.ctrlj.possibleCallMode',  'POSSIBLE CALL MODE',
                          'Possible Call Mode');
   RegisterLegacySetting('operating.ctrlj.possibleCallRightKey','POSSIBLE CALL RIGHT KEY',
                          'Possible Call Right Key');
   RegisterLegacySetting('operating.ctrlj.qsxEnable',         'QSX ENABLE',
                          'Qsx Enable');
   RegisterLegacySetting('operating.ctrlj.qzbRandomOffsetEnable','QZB RANDOM OFFSET ENABLE',
                          'Qzb Random Offset Enable');
   RegisterLegacySetting('operating.ctrlj.radiusOfEarth',     'RADIUS OF EARTH',
                          'Radius Of Earth');
   RegisterLegacySetting('operating.ctrlj.shiftKeyEnable',    'SHIFT KEY ENABLE',
                          'Shift Key Enable');
   RegisterLegacySetting('operating.ctrlj.stationsCallsignsMask','STATIONS CALLSIGNS MASK',
                          'Stations Callsigns Mask');
   RegisterLegacySetting('operating.ctrlj.wakeUpTimeOut',     'WAKE UP TIME OUT',
                          'Wake Up Time Out');

   // --- CW (12) ---------------------------------------
   RegisterLegacySetting('cw.ctrlj.autoSendCharacterCount',   'AUTO SEND CHARACTER COUNT',
                          'Auto Send Character Count');
   RegisterLegacySetting('cw.ctrlj.codeSpeed',                'CODE SPEED',
                          'Code Speed');
   RegisterLegacySetting('cw.ctrlj.paddlePort',               'PADDLE PORT',
                          'Paddle Port');
   RegisterLegacySetting('cw.ctrlj.questionMarkChar',         'QUESTION MARK CHAR',
                          'Question Mark Char');
   RegisterLegacySetting('cw.ctrlj.short0',                   'SHORT 0',
                          'Short 0');
   RegisterLegacySetting('cw.ctrlj.short1',                   'SHORT 1',
                          'Short 1');
   RegisterLegacySetting('cw.ctrlj.short2',                   'SHORT 2',
                          'Short 2');
   RegisterLegacySetting('cw.ctrlj.short9',                   'SHORT 9',
                          'Short 9');
   RegisterLegacySetting('cw.ctrlj.shortIntegers',            'SHORT INTEGERS',
                          'Short Integers');
   RegisterLegacySetting('cw.ctrlj.slashMarkChar',            'SLASH MARK CHAR',
                          'Slash Mark Char');
   RegisterLegacySetting('cw.ctrlj.startSendingNowKey',       'START SENDING NOW KEY',
                          'Start Sending Now Key');
   RegisterLegacySetting('cw.ctrlj.tuneAltDEnable',           'TUNE ALT-D ENABLE',
                          'Tune Alt-D Enable');

   // --- Appearance (13) -------------------------------
   // customCaret was here until 2026-08-18; the CFG row is csRem now and
   // retired rows are not registered (cf. AUTO ALT-D ENABLE, BACKCOPY ENABLE).
   RegisterLegacySetting('appearance.ctrlj.beepEnable',       'BEEP ENABLE',
                          'Beep Enable');
   RegisterLegacySetting('appearance.ctrlj.columnAutosize',   'COLUMN AUTOSIZE',
                          'Column Autosize');
   RegisterLegacySetting('appearance.ctrlj.completeCallsignMask','COMPLETE CALLSIGN MASK',
                          'Complete Callsign Mask');
   RegisterLegacySetting('appearance.ctrlj.contactsPerPage',  'CONTACTS PER PAGE',
                          'Contacts Per Page');
   RegisterLegacySetting('appearance.ctrlj.hourDisplay',      'HOUR DISPLAY',
                          'Hour Display');
   RegisterLegacySetting('appearance.ctrlj.insertMode',       'INSERT MODE',
                          'Insert Mode');
   RegisterLegacySetting('appearance.ctrlj.rateDisplay',      'RATE DISPLAY',
                          'Rate Display');
   RegisterLegacySetting('appearance.ctrlj.reminder',         'REMINDER',
                          'Reminder');
   RegisterLegacySetting('appearance.layout.rowCount',         'ROW COUNT',
                          'Row Count');
   RegisterLegacySetting('appearance.ctrlj.showFrequencyInLog','SHOW FREQUENCY IN LOG',
                          'Show Frequency In Log');
   RegisterLegacySetting('appearance.ctrlj.showTypedCallsign','SHOW TYPED CALLSIGN',
                          'Show Typed Callsign');
   RegisterLegacySetting('appearance.ctrlj.userInfoShown',    'USER INFO SHOWN',
                          'User Info Shown');
   RegisterLegacySetting('appearance.layout.windowSize',       'WINDOW SIZE',
                          'Window Size');

   // --- Hardware (5) ---------------------------------
   RegisterLegacySetting('hardware.ctrlj.lpt1BaseAddress',    'LPT1 BASE ADDRESS',
                          'LPT1 Base Address');
   RegisterLegacySetting('hardware.ctrlj.lpt2BaseAddress',    'LPT2 BASE ADDRESS',
                          'LPT2 Base Address');
   RegisterLegacySetting('hardware.ctrlj.lpt3BaseAddress',    'LPT3 BASE ADDRESS',
                          'LPT3 Base Address');
   RegisterLegacySetting('hardware.ctrlj.stereoPinHigh',      'STEREO PIN HIGH',
                          'Stereo Pin High');
   RegisterLegacySetting('hardware.ctrlj.useControlPort',     'USE CONTROL PORT',
                          'Use Control Port');

   // --- Files/Updates (7) ----------------------------
   RegisterLegacySetting('files.ctrlj.allowAutoUpdate',       'ALLOW AUTO UPDATE',
                          'Allow Auto Update');
   RegisterLegacySetting('files.ctrlj.callsignUpdateEnable',  'CALLSIGN UPDATE ENABLE',
                          'Callsign Update Enable');
   RegisterLegacySetting('files.ctrlj.countryInformationFile','COUNTRY INFORMATION FILE',
                          'Country Information File');
   RegisterLegacySetting('files.ctrlj.ctyUpdateCheckOnStartup','CTY UPDATE CHECK ON STARTUP',
                          'Cty Update Check On Startup');
   RegisterLegacySetting('files.ctrlj.domesticFilename',      'DOMESTIC FILENAME',
                          'Domestic Filename');
   RegisterLegacySetting('files.ctrlj.missingcallsignsFileEnable','MISSINGCALLSIGNS FILE ENABLE',
                          'Missingcallsigns File Enable');
   RegisterLegacySetting('files.ctrlj.unknownCountryFileName','UNKNOWN COUNTRY FILE NAME',
                          'Unknown Country File Name');

   // --- Band Map (5) ---------------------------------
   RegisterLegacySetting('bandmap.ctrlj.bandMapCutoffFrequency','BAND MAP CUTOFF FREQUENCY',
                          'Band Map Cutoff Frequency');
   RegisterLegacySetting('bandmap.ctrlj.bandMapItemHeight',   'BAND MAP ITEM HEIGHT',
                          'Band Map Item Height');
   RegisterLegacySetting('bandmap.ctrlj.bandMapItemWidth',    'BAND MAP ITEM WIDTH',
                          'Band Map Item Width');
   RegisterLegacySetting('bandmap.ctrlj.bandMapSize',         'BAND MAP SIZE',
                          'Band Map Size');
   RegisterLegacySetting('bandmap.ctrlj.bandMapSplitMode',    'BAND MAP SPLIT MODE',
                          'Band Map Split Mode');

   // --- Network (2) ----------------------------------
   RegisterLegacySetting('network.ctrlj.computerName',        'COMPUTER NAME',
                          'Computer Name');
   RegisterLegacySetting('network.ctrlj.netStatusUpdateInterval','NET STATUS UPDATE INTERVAL',
                          'Net Status Update Interval');

   // --- Voice/DVK (2) --------------------------------
   RegisterLegacySetting('voice.ctrlj.mp3RecorderBitrate',    'MP3 RECORDER BITRATE',
                          'Mp3 Recorder Bitrate');
   RegisterLegacySetting('voice.ctrlj.mp3RecorderDuration',   'MP3 RECORDER DURATION',
                          'Mp3 Recorder Duration');

   // --- Advanced (2) ---------------------------------
   RegisterLegacySetting('advanced.handLogMode',        'HAND LOG MODE',
                          'Hand Log Mode');
   RegisterLegacySetting('advanced.noLog',              'NO LOG',
                          'No Log');

   // --- DX Cluster (1) -------------------------------
   RegisterLegacySetting('cluster.ctrlj.broadcastAllPacketData','BROADCAST ALL PACKET DATA',
                          'Broadcast All Packet Data');
   // Two rows a case-SENSITIVE type scan missed on 2026-08-16: their crType is
   // spelled 'ctFilename' and 'ctinteger' in CFGCA. Pascal does not care; the
   // scan did, and reported Ctrl-J empty while they were still in it.
   // STEREO CONTROL PIN joins STEREO PIN HIGH on Hardware.
   RegisterLegacySetting('hardware.ctrlj.stereoControlPin',   'STEREO CONTROL PIN',
                          'Stereo Control Pin');
   RegisterLegacySetting('files.ctrlj.initialExchangeFilename','INITIAL EXCHANGE FILENAME',
                          'Initial Exchange Filename');


end;

end.

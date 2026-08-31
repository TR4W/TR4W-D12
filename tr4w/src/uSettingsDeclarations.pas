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
   uSettingsLegacy,   // RegisterLegacySetting -- no FMX
   uSettingsCaptions;  // RS_* -- the translatable setting labels

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
                         RS_OPERATING_CW_SAYHI);
   RegisterStoredSetting('operating.cw.sayHiRateCutoff',  'SAY HI RATE CUTOFF',
                         RS_OPERATING_CW_SAYHIRATECUTOFF);
   RegisterStoredSetting('operating.cw.keypadMemories',   'KEYPAD CW MEMORIES',
                         RS_OPERATING_CW_KEYPADMEMORIES);
   RegisterStoredSetting('operating.cw.leadingZeros',     'LEADING ZEROS',
                         RS_OPERATING_CW_LEADINGZEROS);
   RegisterStoredSetting('operating.cw.leadingZeroChar',  'LEADING ZERO CHARACTER',
                         RS_OPERATING_CW_LEADINGZEROCHAR);

   // Radio serial keying.  These shape only the CW TR4W generates itself by
   // toggling DTR/RTS -- a WinKeyer, a YCCC box or CW-by-CAT keep their own
   // timing -- which is why they sit in their own frame rather than beside the
   // settings that apply to every keyer.
   RegisterStoredSetting('operating.cw.serial.ditDahRatio',    'DIT DAH RATIO',
                         RS_OPERATING_CW_SERIAL_DITDAHRATIO);
   RegisterStoredSetting('operating.cw.serial.weight',         'WEIGHT',
                         RS_OPERATING_CW_SERIAL_WEIGHT);
   RegisterStoredSetting('operating.cw.serial.farnsworth',     'FARNSWORTH ENABLE',
                         RS_OPERATING_CW_SERIAL_FARNSWORTH);
   RegisterStoredSetting('operating.cw.serial.farnsworthSpeed','FARNSWORTH SPEED',
                         RS_OPERATING_CW_SERIAL_FARNSWORTHSPEED);

   // --- CW Settings (the keyer page) ---------------------------------------
   RegisterStoredSetting('cw.enable',            'CW ENABLE',
                         RS_CW_ENABLE);
   RegisterStoredSetting('cw.speedFromDatabase', 'CW SPEED FROM DATABASE',
                         RS_CW_SPEEDFROMDATABASE);
   // MIGRATED 2026-08-14 -- the first row to graduate.  Stored: writes go to
   // settings\tr4w.json, the CFGCA row is csJSON, and so it no longer appears
   // in Ctrl-J nor in tr4w.ini.  The two halves must stay in step; see
   // docs/CFG_MIGRATION_PLAN.md.
   RegisterStoredSetting('cw.speedIncrement',    'CW SPEED INCREMENT',
                         RS_CW_SPEEDINCREMENT);
   RegisterStoredSetting('cw.tone',              'CW TONE',
                         RS_CW_TONE);

   { CW SENDING BEHAVIOUR. These shape what the keyer sends and how, whichever
     keyer is selected -- unlike the serial-keying group above, which only
     affects CW TR4W generates itself. }
   RegisterStoredSetting('cw.messagesChainable',  'ALL CW MESSAGES CHAINABLE',
                         RS_CW_MESSAGESCHAINABLE);
   RegisterStoredSetting('cw.tuneWithDits',       'TUNE WITH DITS',
                         RS_CW_TUNEWITHDITS);
   RegisterStoredSetting('cw.sendFourLetterCall', 'SEND COMPLETE FOUR LETTER CALL',
                         RS_CW_SENDFOURLETTERCALL);

   { The F-key button captions, 2026-08-15. }
   RegisterStoredSetting('cw.includeFKeyNumber',              'INCLUDE F-KEY NUMBER',
                         RS_CW_INCLUDEFKEYNUMBER);

   { The old Appearance menu's contents, 2026-08-15. }
   RegisterStoredSetting('appearance.noBorder',               'NO BORDER',
                         RS_APPEARANCE_NOBORDER);
   RegisterStoredSetting('appearance.noCaption',              'NO CAPTION',
                         RS_APPEARANCE_NOCAPTION);
   RegisterStoredSetting('appearance.noColumnHeader',         'NO COLUMN HEADER',
                         RS_APPEARANCE_NOCOLUMNHEADER);
   RegisterStoredSetting('appearance.showGridlines',          'SHOW GRIDLINES',
                         RS_APPEARANCE_SHOWGRIDLINES);

   { Audio: MP3 recording and the digital voice keyer, 2026-08-15. }
   RegisterStoredSetting('audio.mp3.recorderEnable',          'MP3 RECORDER ENABLE',
                         RS_AUDIO_MP3_RECORDERENABLE);
   RegisterStoredSetting('audio.mp3.path',                    'MP3 PATH',
                         RS_AUDIO_MP3_PATH);
   RegisterStoredSetting('audio.mp3.player',                  'MP3 PLAYER',
                         RS_AUDIO_MP3_PLAYER);
   RegisterStoredSetting('audio.dvk.enable',                  'DVK ENABLE',
                         RS_AUDIO_DVK_ENABLE);
   RegisterStoredSetting('audio.dvk.localizedMessages',       'DVK LOCALIZED MESSAGES ENABLE',
                         RS_AUDIO_DVK_LOCALIZEDMESSAGES);
   RegisterStoredSetting('audio.dvk.path',                    'DVK PATH',
                         RS_AUDIO_DVK_PATH);
   RegisterStoredSetting('audio.dvk.recorder',                'DVK RECORDER',
                         RS_AUDIO_DVK_RECORDER);
   RegisterStoredSetting('audio.useRecordedSigns',            'USE RECORDED SIGNS',
                         RS_AUDIO_USERECORDEDSIGNS);

   { PADDLE. The paddle keyer TR4W runs itself; a WinKeyer or YCCC box keeps its
     own. PADDLE PORT is deliberately NOT here -- it is a parallel port, and
     whether TR4W keeps supporting those is an open question (see the Hardware
     panel). Speed and tone are useful regardless of which port carries it. }
   RegisterStoredSetting('cw.paddle.speed',       'PADDLE SPEED',
                         RS_CW_PADDLE_SPEED);
   RegisterStoredSetting('cw.paddle.monitorTone', 'PADDLE MONITOR TONE',
                         RS_CW_PADDLE_MONITORTONE);
   RegisterStoredSetting('cw.paddle.swap',        'SWAP PADDLES',
                         RS_CW_PADDLE_SWAP);
   RegisterStoredSetting('cw.paddle.pttHoldCount','PADDLE PTT HOLD COUNT',
                         RS_CW_PADDLE_PTTHOLDCOUNT);

   { PTT. Not CW-only -- PTT ENABLE keys the transmitter for phone too -- but it
     is grouped with the keyer because that is where an operator changes it. }
   RegisterStoredSetting('ptt.enable',            'PTT ENABLE',
                         RS_PTT_ENABLE);
   RegisterStoredSetting('ptt.turnOnDelay',       'PTT TURN ON DELAY',
                         RS_PTT_TURNONDELAY);
   RegisterStoredSetting('ptt.noPollDuringPTT',   'NO POLL DURING PTT',
                         RS_PTT_NOPOLLDURINGPTT);

   { Operating and PTT, 2026-08-15. Captions follow each command's help entry:
     AUTO CALL TERMINATE stops sending when the call window changes, and
     CONFIRM EDIT CHANGES asks before an edited QSO is written back. }
   RegisterStoredSetting('ptt.viaCommands',                   'PTT VIA COMMANDS',
                         RS_PTT_VIACOMMANDS);
   RegisterStoredSetting('ptt.lockout',                       'PTT LOCKOUT',
                         RS_PTT_LOCKOUT);
   RegisterStoredSetting('operating.autoCallTerminate',       'AUTO CALL TERMINATE',
                         RS_OPERATING_AUTOCALLTERMINATE);
   RegisterStoredSetting('operating.autoReturnToCQ',          'AUTO RETURN TO CQ MODE',
                         RS_OPERATING_AUTORETURNTOCQ);
   RegisterStoredSetting('operating.escapeExitsSAP',          'ESCAPE EXITS SEARCH AND POUNCE',
                         RS_OPERATING_ESCAPEEXITSSAP);
   RegisterStoredSetting('operating.leaveCursorInCall',       'LEAVE CURSOR IN CALL WINDOW',
                         RS_OPERATING_LEAVECURSORINCALL);
   RegisterStoredSetting('operating.logWithSingleEnter',      'LOG WITH SINGLE ENTER',
                         RS_OPERATING_LOGWITHSINGLEENTER);
   RegisterStoredSetting('operating.spaceBarDupeCheck',       'SPACE BAR DUPE CHECK ENABLE',
                         RS_OPERATING_SPACEBARDUPECHECK);
   RegisterStoredSetting('operating.confirmEditChanges',      'CONFIRM EDIT CHANGES',
                         RS_OPERATING_CONFIRMEDITCHANGES);
   RegisterStoredSetting('operating.autoQSONumberDecrement',  'AUTO QSO NUMBER DECREMENT',
                         RS_OPERATING_AUTOQSONUMBERDECREMENT);

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
                         RS_OPERATING_BANDS_HF);
   RegisterStoredSetting('operating.bands.warc', 'WARC BAND ENABLE',
                         RS_OPERATING_BANDS_WARC);
   RegisterStoredSetting('operating.bands.vhf',  'VHF BAND ENABLE',
                         RS_OPERATING_BANDS_VHF);

   // --- Operating: two radio -----------------------------------------------
   RegisterStoredSetting('operating.tworadio.enable',       'TWO RADIO MODE',
                         RS_OPERATING_TWORADIO_ENABLE);

   { Two radio and multi-op, 2026-08-15. Captions from each command's own entry
     in commands_help_eng.ini rather than invented -- IN BAND LOCKOUT is
     documented as "prevents Band Map selection that would place both radios on
     a single band", and MULTI MULTS ONLY decides whether all QSOs or only new
     multipliers are passed around the network. }
   RegisterStoredSetting('operating.tworadio.inBandLockout',  'IN BAND LOCKOUT',
                         RS_OPERATING_TWORADIO_INBANDLOCKOUT);
   RegisterStoredSetting('operating.tworadio.qsyInactive',    'QSY INACTIVE RADIO',
                         RS_OPERATING_TWORADIO_QSYINACTIVE);
   RegisterStoredSetting('operating.tworadio.swapRelaySense', 'SWAP RADIO RELAY SENSE',
                         RS_OPERATING_TWORADIO_SWAPRELAYSENSE);
   RegisterStoredSetting('operating.tworadio.waitForStrength', 'WAIT FOR STRENGTH',
                         RS_OPERATING_TWORADIO_WAITFORSTRENGTH);
   RegisterStoredSetting('network.multiMultsOnly',            'MULTI MULTS ONLY',
                         RS_NETWORK_MULTIMULTSONLY);
   RegisterStoredSetting('network.intercomFile',              'INTERCOM FILE ENABLE',
                         RS_NETWORK_INTERCOMFILE);

   { Super Check Partial, band map and log files, 2026-08-15. }
   RegisterStoredSetting('scp.possibleCalls',                 'POSSIBLE CALLS',
                         RS_SCP_POSSIBLECALLS);
   RegisterStoredSetting('scp.partialCall',                   'PARTIAL CALL ENABLE',
                         RS_SCP_PARTIALCALL);
   RegisterStoredSetting('scp.wildcardPartials',              'WILDCARD PARTIALS',
                         RS_SCP_WILDCARDPARTIALS);
   RegisterStoredSetting('scp.nameFlag',                      'NAME FLAG ENABLE',
                         RS_SCP_NAMEFLAG);
   RegisterStoredSetting('bandmap.callWindowShowAllSpots',    'CALL WINDOW SHOW ALL SPOTS',
                         RS_BANDMAP_CALLWINDOWSHOWALLSPOTS);
   RegisterStoredSetting('bandmap.swapPacketSpotRadios',      'SWAP PACKET SPOT RADIOS',
                         RS_BANDMAP_SWAPPACKETSPOTRADIOS);
   RegisterStoredSetting('logging.checkLogFileSize',          'CHECK LOG FILE SIZE',
                         RS_LOGGING_CHECKLOGFILESIZE);
   RegisterStoredSetting('logging.unknownCountryFile',        'UNKNOWN COUNTRY FILE ENABLE',
                         RS_LOGGING_UNKNOWNCOUNTRYFILE);
   RegisterStoredSetting('logging.updateRestartFile',         'UPDATE RESTART FILE ENABLE',
                         RS_LOGGING_UPDATERESTARTFILE);
   RegisterStoredSetting('operating.tworadio.altDBuffer',   'ALT-D BUFFER ENABLE',
                         RS_OPERATING_TWORADIO_ALTDBUFFER);
   RegisterStoredSetting('operating.tworadio.altDCQ',       'ALT-D CQ ENABLE',
                         RS_OPERATING_TWORADIO_ALTDCQ);
   RegisterStoredSetting('operating.tworadio.blindCQ',      'ALWAYS CALL BLIND CQ',
                         RS_OPERATING_TWORADIO_BLINDCQ);
   RegisterStoredSetting('operating.tworadio.skipActiveBand','SKIP ACTIVE BAND',
                         RS_OPERATING_TWORADIO_SKIPACTIVEBAND);

   // --- Operating: online scoring ------------------------------------------
   RegisterStoredSetting('scoring.hamscore.enable',      'HAMSCORE ENABLE',
                         RS_SCORING_HAMSCORE_ENABLE);
   RegisterStoredSetting('scoring.hamscore.url',         'HAMSCORE URL',
                         RS_SCORING_HAMSCORE_URL);
   RegisterStoredSetting('scoring.hamscore.username',    'HAMSCORE USERNAME',
                         RS_SCORING_HAMSCORE_USERNAME);
   RegisterStoredSetting('scoring.hamscore.password',    'HAMSCORE PASSWORD',
                         RS_SCORING_HAMSCORE_PASSWORD);
   RegisterStoredSetting('scoring.hamscore.contactInfo', 'HAMSCORE SEND CONTACT INFO',
                         RS_SCORING_HAMSCORE_CONTACTINFO);
   RegisterStoredSetting('scoring.board.postingUrl',     'SCORE POSTING URL',
                         RS_SCORING_BOARD_POSTINGURL);
   RegisterStoredSetting('scoring.board.readingUrl',     'SCORE READING URL',
                         RS_SCORING_BOARD_READINGURL);

   // --- DX cluster ---------------------------------------------------------
   RegisterStoredSetting('cluster.connectAtStartup', 'CONNECTION AT STARTUP',
                         RS_CLUSTER_CONNECTATSTARTUP);
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
   RegisterStoredSetting('contest.autoQslInterval',     'AUTO QSL INTERVAL',
                          RS_CONTEST_AUTOQSLINTERVAL);
   RegisterStoredSetting('contest.autoCqDelayTime',     'AUTO-CQ DELAY TIME',
                          RS_CONTEST_AUTOCQDELAYTIME);
   RegisterStoredSetting('contest.beepEvery10Qsos',     'BEEP EVERY 10 QSOS',
                          RS_CONTEST_BEEPEVERY10QSOS);
   RegisterStoredSetting('contest.categoryAssisted',    'CATEGORY-ASSISTED',
                          RS_CONTEST_CATEGORYASSISTED);
   RegisterStoredSetting('contest.categoryBand',        'CATEGORY-BAND',
                          RS_CONTEST_CATEGORYBAND);
   RegisterStoredSetting('contest.categoryMode',        'CATEGORY-MODE',
                          RS_CONTEST_CATEGORYMODE);
   RegisterStoredSetting('contest.categoryOperator',    'CATEGORY-OPERATOR',
                          RS_CONTEST_CATEGORYOPERATOR);
   RegisterStoredSetting('contest.categoryOverlay',     'CATEGORY-OVERLAY',
                          RS_CONTEST_CATEGORYOVERLAY);
   RegisterStoredSetting('contest.categoryPower',       'CATEGORY-POWER',
                          RS_CONTEST_CATEGORYPOWER);
   RegisterStoredSetting('contest.categoryTransmitter', 'CATEGORY-TRANSMITTER',
                          RS_CONTEST_CATEGORYTRANSMITTER);
   RegisterStoredSetting('contest.contest',             'CONTEST',
                          RS_CONTEST_CONTEST);
   RegisterStoredSetting('contest.contestName',         'CONTEST NAME',
                          RS_CONTEST_CONTESTNAME);
   RegisterStoredSetting('contest.contestTitle',        'CONTEST TITLE',
                          RS_CONTEST_CONTESTTITLE);
   RegisterStoredSetting('contest.countDomesticCountries','COUNT DOMESTIC COUNTRIES',
                          RS_CONTEST_COUNTDOMESTICCOUNTRIES);
   RegisterStoredSetting('contest.customInitialExchangeString','CUSTOM INITIAL EXCHANGE STRING',
                          RS_CONTEST_CUSTOMINITIALEXCHANGESTRING);
   RegisterStoredSetting('contest.domesticMultiplier',  'DOMESTIC MULTIPLIER',
                          RS_CONTEST_DOMESTICMULTIPLIER);
   RegisterStoredSetting('contest.dxMultiplier',        'DX MULTIPLIER',
                          RS_CONTEST_DXMULTIPLIER);
   RegisterStoredSetting('contest.exchangeMemoryEnable','EXCHANGE MEMORY ENABLE',
                          RS_CONTEST_EXCHANGEMEMORYENABLE);
   RegisterStoredSetting('contest.exchangeReceived',    'EXCHANGE RECEIVED',
                          RS_CONTEST_EXCHANGERECEIVED);
   RegisterStoredSetting('contest.gridMapCenter',       'GRID MAP CENTER',
                          RS_CONTEST_GRIDMAPCENTER);
   RegisterStoredSetting('contest.initialExchange',     'INITIAL EXCHANGE',
                          RS_CONTEST_INITIALEXCHANGE);
   RegisterStoredSetting('contest.initialExchangeCursorPos','INITIAL EXCHANGE CURSOR POS',
                          RS_CONTEST_INITIALEXCHANGECURSORPOS);
   RegisterStoredSetting('contest.initialExchangeOverwrite','INITIAL EXCHANGE OVERWRITE',
                          RS_CONTEST_INITIALEXCHANGEOVERWRITE);
   RegisterStoredSetting('contest.literalDomesticQth',  'LITERAL DOMESTIC QTH',
                          RS_CONTEST_LITERALDOMESTICQTH);
   RegisterStoredSetting('contest.logRsSent',           'LOG RS SENT',
                          RS_CONTEST_LOGRSSENT);
   RegisterStoredSetting('contest.logRstSent',          'LOG RST SENT',
                          RS_CONTEST_LOGRSTSENT);
   RegisterStoredSetting('contest.lookForRstSent',      'LOOK FOR RST SENT',
                          RS_CONTEST_LOOKFORRSTSENT);
   RegisterStoredSetting('contest.messageEnable',       'MESSAGE ENABLE',
                          RS_CONTEST_MESSAGEENABLE);
   RegisterStoredSetting('contest.minitourDuration',    'MINITOUR DURATION',
                          RS_CONTEST_MINITOURDURATION);
   RegisterStoredSetting('contest.multByBand',          'MULT BY BAND',
                          RS_CONTEST_MULTBYBAND);
   RegisterStoredSetting('contest.multByMode',          'MULT BY MODE',
                          RS_CONTEST_MULTBYMODE);
   RegisterStoredSetting('contest.multReportMinimumBands','MULT REPORT MINIMUM BANDS',
                          RS_CONTEST_MULTREPORTMINIMUMBANDS);
   RegisterStoredSetting('contest.multSheetAutoReset',  'MULT SHEET AUTO RESET',
                          RS_CONTEST_MULTSHEETAUTORESET);
   RegisterStoredSetting('contest.multipleBands',       'MULTIPLE BANDS',
                          RS_CONTEST_MULTIPLEBANDS);
   RegisterStoredSetting('contest.multipleModes',       'MULTIPLE MODES',
                          RS_CONTEST_MULTIPLEMODES);
   RegisterStoredSetting('contest.prefixMultiplier',    'PREFIX MULTIPLIER',
                          RS_CONTEST_PREFIXMULTIPLIER);
   RegisterStoredSetting('contest.qslMode',             'QSL MODE',
                          RS_CONTEST_QSLMODE);
   RegisterStoredSetting('contest.qsoByBand',           'QSO BY BAND',
                          RS_CONTEST_QSOBYBAND);
   RegisterStoredSetting('contest.qsoByMode',           'QSO BY MODE',
                          RS_CONTEST_QSOBYMODE);
   RegisterStoredSetting('contest.qsoNumberByBand',     'QSO NUMBER BY BAND',
                          RS_CONTEST_QSONUMBERBYBAND);
   RegisterStoredSetting('contest.qsoPointMethod',      'QSO POINT METHOD',
                          RS_CONTEST_QSOPOINTMETHOD);
   RegisterStoredSetting('contest.qsoPointsDomesticCw', 'QSO POINTS DOMESTIC CW',
                          RS_CONTEST_QSOPOINTSDOMESTICCW);
   RegisterStoredSetting('contest.qsoPointsDomesticPhone','QSO POINTS DOMESTIC PHONE',
                          RS_CONTEST_QSOPOINTSDOMESTICPHONE);
   RegisterStoredSetting('contest.qsoPointsDxCw',       'QSO POINTS DX CW',
                          RS_CONTEST_QSOPOINTSDXCW);
   RegisterStoredSetting('contest.qsoPointsDxPhone',    'QSO POINTS DX PHONE',
                          RS_CONTEST_QSOPOINTSDXPHONE);
   RegisterStoredSetting('contest.qtcEnable',           'QTC ENABLE',
                          RS_CONTEST_QTCENABLE);
   RegisterStoredSetting('contest.qtcExtraSpace',       'QTC EXTRA SPACE',
                          RS_CONTEST_QTCEXTRASPACE);
   RegisterStoredSetting('contest.qtcMinutes',          'QTC MINUTES',
                          RS_CONTEST_QTCMINUTES);
   RegisterStoredSetting('contest.qtcQrs',              'QTC QRS',
                          RS_CONTEST_QTCQRS);
   RegisterStoredSetting('contest.quickQslCwMessage',   'QUICK QSL CW MESSAGE',
                          RS_CONTEST_QUICKQSLCWMESSAGE);
   RegisterStoredSetting('contest.quickQslCwMessage1',  'QUICK QSL CW MESSAGE1',
                          RS_CONTEST_QUICKQSLCWMESSAGE1);
   RegisterStoredSetting('contest.quickQslKey1',        'QUICK QSL KEY 1',
                          RS_CONTEST_QUICKQSLKEY1);
   RegisterStoredSetting('contest.quickQslKey2',        'QUICK QSL KEY 2',
                          RS_CONTEST_QUICKQSLKEY2);
   RegisterStoredSetting('contest.quickQslMessage1',    'QUICK QSL MESSAGE 1',
                          RS_CONTEST_QUICKQSLMESSAGE1);
   RegisterStoredSetting('contest.quickQslMessage2',    'QUICK QSL MESSAGE 2',
                          RS_CONTEST_QUICKQSLMESSAGE2);
   RegisterStoredSetting('contest.quickQslSsbMessage',  'QUICK QSL SSB MESSAGE',
                          RS_CONTEST_QUICKQSLSSBMESSAGE);
   RegisterStoredSetting('contest.r150sMode',           'R150S MODE',
                          RS_CONTEST_R150SMODE);
   RegisterStoredSetting('contest.randomCqMode',        'RANDOM CQ MODE',
                          RS_CONTEST_RANDOMCQMODE);
   RegisterStoredSetting('contest.remainingMultDisplayMode','REMAINING MULT DISPLAY MODE',
                          RS_CONTEST_REMAININGMULTDISPLAYMODE);
   RegisterStoredSetting('contest.reverseInitialEx',    'REVERSE INITIAL EX',
                          RS_CONTEST_REVERSEINITIALEX);
   RegisterStoredSetting('contest.rfoblMode',           'RFOBL MODE',
                          RS_CONTEST_RFOBLMODE);
   RegisterStoredSetting('contest.showAllSerialPorts',  'SHOW ALL SERIAL PORTS',
                          RS_CONTEST_SHOWALLSERIALPORTS);
   RegisterStoredSetting('contest.showDomesticMultiplierName','SHOW DOMESTIC MULTIPLIER NAME',
                          RS_CONTEST_SHOWDOMESTICMULTIPLIERNAME);
   RegisterLegacySetting('contest.singleBandScore',     'SINGLE BAND SCORE',
                          'Single Band Score');
   RegisterStoredSetting('contest.sprintQsyRule',       'SPRINT QSY RULE',
                          RS_CONTEST_SPRINTQSYRULE);
   RegisterStoredSetting('contest.tenMinuteRule',       'TEN MINUTE RULE',
                          RS_CONTEST_TENMINUTERULE);
   RegisterStoredSetting('contest.zoneMultiplier',      'ZONE MULTIPLIER',
                          RS_CONTEST_ZONEMULTIPLIER);

   // --- Operating (34) --------------------------------
   RegisterStoredSetting('operating.ctrlj.askForFrequencies', 'ASK FOR FREQUENCIES',
                          RS_OPERATING_CTRLJ_ASKFORFREQUENCIES);
   RegisterStoredSetting('operating.ctrlj.autoDisplayDupeQso','AUTO DISPLAY DUPE QSO',
                          RS_OPERATING_CTRLJ_AUTODISPLAYDUPEQSO);
   RegisterStoredSetting('operating.ctrlj.autoDupeEnableCq',  'AUTO DUPE ENABLE CQ',
                          RS_OPERATING_CTRLJ_AUTODUPEENABLECQ);
   RegisterStoredSetting('operating.ctrlj.autoDupeEnableSAndP','AUTO DUPE ENABLE S AND P',
                          RS_OPERATING_CTRLJ_AUTODUPEENABLESANDP);
   RegisterStoredSetting('operating.ctrlj.autoSPEnable',      'AUTO S&P ENABLE',
                          RS_OPERATING_CTRLJ_AUTOSPENABLE);
   RegisterStoredSetting('operating.ctrlj.autoSPEnableSensitivity','AUTO S&P ENABLE SENSITIVITY',
                          RS_OPERATING_CTRLJ_AUTOSPENABLESENSITIVITY);
   RegisterStoredSetting('operating.ctrlj.autoTimeIncrement', 'AUTO TIME INCREMENT',
                          RS_OPERATING_CTRLJ_AUTOTIMEINCREMENT);
   RegisterLegacySetting('operating.ctrlj.band',              'BAND',
                          'Band');
   RegisterLegacySetting('operating.ctrlj.clearDupeSheet',    'CLEAR DUPE SHEET',
                          'Clear Dupe Sheet');
   RegisterStoredSetting('operating.ctrlj.customUserString',  'CUSTOM USER STRING',
                          RS_OPERATING_CTRLJ_CUSTOMUSERSTRING);
   RegisterStoredSetting('operating.ctrlj.deEnable',          'DE ENABLE',
                          RS_OPERATING_CTRLJ_DEENABLE);
   RegisterStoredSetting('operating.ctrlj.digitalModeEnable', 'DIGITAL MODE ENABLE',
                          RS_OPERATING_CTRLJ_DIGITALMODEENABLE);
   RegisterStoredSetting('operating.ctrlj.distanceMode',      'DISTANCE MODE',
                          RS_OPERATING_CTRLJ_DISTANCEMODE);
   RegisterStoredSetting('operating.ctrlj.dupeCheckSound',    'DUPE CHECK SOUND',
                          RS_OPERATING_CTRLJ_DUPECHECKSOUND);
   RegisterStoredSetting('operating.ctrlj.dupeSheetAutoReset','DUPE SHEET AUTO RESET',
                          RS_OPERATING_CTRLJ_DUPESHEETAUTORESET);
   RegisterStoredSetting('operating.ctrlj.frequencyMemory',   'FREQUENCY MEMORY',
                          RS_OPERATING_CTRLJ_FREQUENCYMEMORY);
   RegisterStoredSetting('operating.ctrlj.frequencyMemoryEnable','FREQUENCY MEMORY ENABLE',
                          RS_OPERATING_CTRLJ_FREQUENCYMEMORYENABLE);
   RegisterStoredSetting('operating.ctrlj.frequencyPollRate', 'FREQUENCY POLL RATE',
                          RS_OPERATING_CTRLJ_FREQUENCYPOLLRATE);
   RegisterStoredSetting('operating.ctrlj.ieSwitch',          'IE SWITCH',
                          RS_OPERATING_CTRLJ_IESWITCH);
   RegisterStoredSetting('operating.ctrlj.incrementTimeEnable','INCREMENT TIME ENABLE',
                          RS_OPERATING_CTRLJ_INCREMENTTIMEENABLE);
   RegisterStoredSetting('operating.ctrlj.logFrequencyEnable','LOG FREQUENCY ENABLE',
                          RS_OPERATING_CTRLJ_LOGFREQUENCYENABLE);
   RegisterStoredSetting('operating.ctrlj.logSubTitle',       'LOG SUB TITLE',
                          RS_OPERATING_CTRLJ_LOGSUBTITLE);
   RegisterStoredSetting('operating.ctrlj.mainCallsign',      'MAIN CALLSIGN',
                          RS_OPERATING_CTRLJ_MAINCALLSIGN);
   RegisterStoredSetting('operating.ctrlj.mode',              'MODE',
                          RS_OPERATING_CTRLJ_MODE);
   RegisterStoredSetting('operating.ctrlj.possibleCallAcceptKey','POSSIBLE CALL ACCEPT KEY',
                          RS_OPERATING_CTRLJ_POSSIBLECALLACCEPTKEY);
   RegisterStoredSetting('operating.ctrlj.possibleCallLeftKey','POSSIBLE CALL LEFT KEY',
                          RS_OPERATING_CTRLJ_POSSIBLECALLLEFTKEY);
   RegisterStoredSetting('operating.ctrlj.possibleCallMode',  'POSSIBLE CALL MODE',
                          RS_OPERATING_CTRLJ_POSSIBLECALLMODE);
   RegisterStoredSetting('operating.ctrlj.possibleCallRightKey','POSSIBLE CALL RIGHT KEY',
                          RS_OPERATING_CTRLJ_POSSIBLECALLRIGHTKEY);
   RegisterStoredSetting('operating.ctrlj.qsxEnable',         'QSX ENABLE',
                          RS_OPERATING_CTRLJ_QSXENABLE);
   RegisterStoredSetting('operating.ctrlj.qzbRandomOffsetEnable','QZB RANDOM OFFSET ENABLE',
                          RS_OPERATING_CTRLJ_QZBRANDOMOFFSETENABLE);
   RegisterStoredSetting('operating.ctrlj.radiusOfEarth',     'RADIUS OF EARTH',
                          RS_OPERATING_CTRLJ_RADIUSOFEARTH);
   RegisterStoredSetting('operating.ctrlj.shiftKeyEnable',    'SHIFT KEY ENABLE',
                          RS_OPERATING_CTRLJ_SHIFTKEYENABLE);
   RegisterStoredSetting('operating.ctrlj.stationsCallsignsMask','STATIONS CALLSIGNS MASK',
                          RS_OPERATING_CTRLJ_STATIONSCALLSIGNSMASK);
   RegisterStoredSetting('operating.ctrlj.wakeUpTimeOut',     'WAKE UP TIME OUT',
                          RS_OPERATING_CTRLJ_WAKEUPTIMEOUT);

   // --- CW (12) ---------------------------------------
   RegisterStoredSetting('cw.ctrlj.autoSendCharacterCount',   'AUTO SEND CHARACTER COUNT',
                          RS_CW_CTRLJ_AUTOSENDCHARACTERCOUNT);
   RegisterStoredSetting('cw.ctrlj.codeSpeed',                'CODE SPEED',
                          RS_CW_CTRLJ_CODESPEED);
   RegisterStoredSetting('cw.ctrlj.paddlePort',               'PADDLE PORT',
                          RS_CW_CTRLJ_PADDLEPORT);
   RegisterStoredSetting('cw.ctrlj.questionMarkChar',         'QUESTION MARK CHAR',
                          RS_CW_CTRLJ_QUESTIONMARKCHAR);
   RegisterStoredSetting('cw.ctrlj.short0',                   'SHORT 0',
                          RS_CW_CTRLJ_SHORT0);
   RegisterStoredSetting('cw.ctrlj.short1',                   'SHORT 1',
                          RS_CW_CTRLJ_SHORT1);
   RegisterStoredSetting('cw.ctrlj.short2',                   'SHORT 2',
                          RS_CW_CTRLJ_SHORT2);
   RegisterStoredSetting('cw.ctrlj.short9',                   'SHORT 9',
                          RS_CW_CTRLJ_SHORT9);
   RegisterStoredSetting('cw.ctrlj.shortIntegers',            'SHORT INTEGERS',
                          RS_CW_CTRLJ_SHORTINTEGERS);
   RegisterStoredSetting('cw.ctrlj.slashMarkChar',            'SLASH MARK CHAR',
                          RS_CW_CTRLJ_SLASHMARKCHAR);
   RegisterStoredSetting('cw.ctrlj.startSendingNowKey',       'START SENDING NOW KEY',
                          RS_CW_CTRLJ_STARTSENDINGNOWKEY);
   RegisterStoredSetting('cw.ctrlj.tuneAltDEnable',           'TUNE ALT-D ENABLE',
                          RS_CW_CTRLJ_TUNEALTDENABLE);

   // --- Appearance (13) -------------------------------
   // customCaret was here until 2026-08-18; the CFG row is csRem now and
   // retired rows are not registered (cf. AUTO ALT-D ENABLE, BACKCOPY ENABLE).
   RegisterStoredSetting('appearance.ctrlj.beepEnable',       'BEEP ENABLE',
                          RS_APPEARANCE_CTRLJ_BEEPENABLE);
   RegisterStoredSetting('appearance.ctrlj.columnAutosize',   'COLUMN AUTOSIZE',
                          RS_APPEARANCE_CTRLJ_COLUMNAUTOSIZE);
   RegisterStoredSetting('appearance.ctrlj.completeCallsignMask','COMPLETE CALLSIGN MASK',
                          RS_APPEARANCE_CTRLJ_COMPLETECALLSIGNMASK);
   RegisterStoredSetting('appearance.ctrlj.contactsPerPage',  'CONTACTS PER PAGE',
                          RS_APPEARANCE_CTRLJ_CONTACTSPERPAGE);
   RegisterStoredSetting('appearance.ctrlj.hourDisplay',      'HOUR DISPLAY',
                          RS_APPEARANCE_CTRLJ_HOURDISPLAY);
   RegisterStoredSetting('appearance.ctrlj.insertMode',       'INSERT MODE',
                          RS_APPEARANCE_CTRLJ_INSERTMODE);
   RegisterStoredSetting('appearance.ctrlj.rateDisplay',      'RATE DISPLAY',
                          RS_APPEARANCE_CTRLJ_RATEDISPLAY);
   RegisterStoredSetting('appearance.ctrlj.reminder',         'REMINDER',
                          RS_APPEARANCE_CTRLJ_REMINDER);
   RegisterStoredSetting('appearance.layout.rowCount',         'ROW COUNT',
                          RS_APPEARANCE_LAYOUT_ROWCOUNT);
   RegisterStoredSetting('appearance.ctrlj.showFrequencyInLog','SHOW FREQUENCY IN LOG',
                          RS_APPEARANCE_CTRLJ_SHOWFREQUENCYINLOG);
   RegisterStoredSetting('appearance.ctrlj.showTypedCallsign','SHOW TYPED CALLSIGN',
                          RS_APPEARANCE_CTRLJ_SHOWTYPEDCALLSIGN);
   RegisterStoredSetting('appearance.ctrlj.userInfoShown',    'USER INFO SHOWN',
                          RS_APPEARANCE_CTRLJ_USERINFOSHOWN);
   RegisterStoredSetting('appearance.layout.windowSize',       'WINDOW SIZE',
                          RS_APPEARANCE_LAYOUT_WINDOWSIZE);

   // --- Hardware (5) ---------------------------------
   RegisterStoredSetting('hardware.ctrlj.lpt1BaseAddress',    'LPT1 BASE ADDRESS',
                          RS_HARDWARE_CTRLJ_LPT1BASEADDRESS);
   RegisterStoredSetting('hardware.ctrlj.lpt2BaseAddress',    'LPT2 BASE ADDRESS',
                          RS_HARDWARE_CTRLJ_LPT2BASEADDRESS);
   RegisterStoredSetting('hardware.ctrlj.lpt3BaseAddress',    'LPT3 BASE ADDRESS',
                          RS_HARDWARE_CTRLJ_LPT3BASEADDRESS);
   RegisterStoredSetting('hardware.ctrlj.stereoPinHigh',      'STEREO PIN HIGH',
                          RS_HARDWARE_CTRLJ_STEREOPINHIGH);
   RegisterStoredSetting('hardware.ctrlj.useControlPort',     'USE CONTROL PORT',
                          RS_HARDWARE_CTRLJ_USECONTROLPORT);

   // --- Files/Updates (7) ----------------------------
   RegisterStoredSetting('files.ctrlj.allowAutoUpdate',       'ALLOW AUTO UPDATE',
                          RS_FILES_CTRLJ_ALLOWAUTOUPDATE);
   RegisterStoredSetting('files.ctrlj.callsignUpdateEnable',  'CALLSIGN UPDATE ENABLE',
                          RS_FILES_CTRLJ_CALLSIGNUPDATEENABLE);
   RegisterStoredSetting('files.ctrlj.countryInformationFile','COUNTRY INFORMATION FILE',
                          RS_FILES_CTRLJ_COUNTRYINFORMATIONFILE);
   RegisterStoredSetting('files.ctrlj.ctyUpdateCheckOnStartup','CTY UPDATE CHECK ON STARTUP',
                          RS_FILES_CTRLJ_CTYUPDATECHECKONSTARTUP);
   RegisterStoredSetting('files.ctrlj.domesticFilename',      'DOMESTIC FILENAME',
                          RS_FILES_CTRLJ_DOMESTICFILENAME);
   RegisterStoredSetting('files.ctrlj.missingcallsignsFileEnable','MISSINGCALLSIGNS FILE ENABLE',
                          RS_FILES_CTRLJ_MISSINGCALLSIGNSFILEENABLE);
   RegisterStoredSetting('files.ctrlj.unknownCountryFileName','UNKNOWN COUNTRY FILE NAME',
                          RS_FILES_CTRLJ_UNKNOWNCOUNTRYFILENAME);

   // --- Band Map (5) ---------------------------------
   RegisterStoredSetting('bandmap.ctrlj.bandMapCutoffFrequency','BAND MAP CUTOFF FREQUENCY',
                          RS_BANDMAP_CTRLJ_BANDMAPCUTOFFFREQUENCY);
   RegisterStoredSetting('bandmap.ctrlj.bandMapItemHeight',   'BAND MAP ITEM HEIGHT',
                          RS_BANDMAP_CTRLJ_BANDMAPITEMHEIGHT);
   RegisterStoredSetting('bandmap.ctrlj.bandMapItemWidth',    'BAND MAP ITEM WIDTH',
                          RS_BANDMAP_CTRLJ_BANDMAPITEMWIDTH);
   RegisterStoredSetting('bandmap.ctrlj.bandMapSize',         'BAND MAP SIZE',
                          RS_BANDMAP_CTRLJ_BANDMAPSIZE);
   RegisterStoredSetting('bandmap.ctrlj.bandMapSplitMode',    'BAND MAP SPLIT MODE',
                          RS_BANDMAP_CTRLJ_BANDMAPSPLITMODE);

   // --- Network (2) ----------------------------------
   RegisterStoredSetting('network.ctrlj.computerName',        'COMPUTER NAME',
                          RS_NETWORK_CTRLJ_COMPUTERNAME);
   RegisterStoredSetting('network.ctrlj.netStatusUpdateInterval','NET STATUS UPDATE INTERVAL',
                          RS_NETWORK_CTRLJ_NETSTATUSUPDATEINTERVAL);

   // --- Voice/DVK (2) --------------------------------
   RegisterStoredSetting('voice.ctrlj.mp3RecorderBitrate',    'MP3 RECORDER BITRATE',
                          RS_VOICE_CTRLJ_MP3RECORDERBITRATE);
   RegisterStoredSetting('voice.ctrlj.mp3RecorderDuration',   'MP3 RECORDER DURATION',
                          RS_VOICE_CTRLJ_MP3RECORDERDURATION);

   // --- Advanced (2) ---------------------------------
   RegisterStoredSetting('advanced.handLogMode',        'HAND LOG MODE',
                          RS_ADVANCED_HANDLOGMODE);
   RegisterStoredSetting('advanced.noLog',              'NO LOG',
                          RS_ADVANCED_NOLOG);

   // --- DX Cluster (1) -------------------------------
   RegisterStoredSetting('cluster.ctrlj.broadcastAllPacketData','BROADCAST ALL PACKET DATA',
                          RS_CLUSTER_CTRLJ_BROADCASTALLPACKETDATA);
   // Two rows a case-SENSITIVE type scan missed on 2026-08-16: their crType is
   // spelled 'ctFilename' and 'ctinteger' in CFGCA. Pascal does not care; the
   // scan did, and reported Ctrl-J empty while they were still in it.
   // STEREO CONTROL PIN joins STEREO PIN HIGH on Hardware.
   RegisterStoredSetting('hardware.ctrlj.stereoControlPin',   'STEREO CONTROL PIN',
                          RS_HARDWARE_CTRLJ_STEREOCONTROLPIN);
   RegisterStoredSetting('files.ctrlj.initialExchangeFilename','INITIAL EXCHANGE FILENAME',
                          RS_FILES_CTRLJ_INITIALEXCHANGEFILENAME);


end;

end.

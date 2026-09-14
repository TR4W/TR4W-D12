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

(* DID THE DECLARATIONS FINISH?

  False before they run, and false if any registration RAISED partway. It
  exists because the obvious test -- count the settings and check there are
  plenty -- cannot tell a complete run from one that failed near the end,
  and that is not hypothetical: on 2026-09-12 a migrated setting whose
  Preferences registration had not moved raised here, crashed TR4W at
  startup for every contest in the golden corpus, and the unit tests stayed
  GREEN at 24784 passed because 200-odd settings had registered before the
  failure and the floor was 200. *)
function SettingsDeclarationsComplete: boolean;

implementation

uses
  SysUtils,          // Exception -- see DeclareAllSettings' failure guard
  uConfigValues,
   LogWind,           // the four QSO-point globals -- see TQSOPointsAccess
   uSettingsRegistry,
   uSettingsLegacy,   // RegisterLegacySetting -- no FMX
   uSettingsModelBinding,   // RegisterModelSetting -- no CFGCA row
   uSettingsCaptions;  // RS_* -- the translatable setting labels

(* THE GETTER/SETTER HOST CLASS IS GONE, 2026-09-12, AND SO IS THE `type`
  BLOCK THAT HELD IT.

  It existed because a typed closure is a method pointer and a method needs
  an object to hang on. It held five pairs: the four QSO-point values, which
  were the first settings in this tree to leave CFGCA and took step two of
  the three this unit's header describes -- a closure over a global -- and
  TourDuration.

  All five have since taken step three. They are properties on
  uSettingsModel, there is no global for a closure to reach, and their
  registrations name them instead. *)

var
   GDeclared: boolean = False;
   (* Set only when every registration has run. See
     SettingsDeclarationsComplete. *)
   GComplete: boolean = False;
   (* What went wrong, kept so EVERY later call fails the same way instead
     of returning quietly on a half-built registry. *)
   GFailure: string = '';

function SettingsDeclarationsComplete: boolean;
begin
   Result := GComplete;
end;

procedure DeclareAllSettings;
begin
   (* A SECOND CALL AFTER A FAILURE FAILS AGAIN, rather than returning as
     though the registry were built. The guard below is what made a broken
     registration survivable enough to reach the corpus: the first caller
     raised, GDeclared was already True, and every caller after it -- the
     unit tests included -- saw a half-built registry and no error. *)
   if GDeclared then
      begin
      if GFailure <> '' then
         begin
         raise Exception.Create(GFailure);
         end;
      Exit;
      end;

   (* Set BEFORE the registrations, not after: a second pass would register
     every key twice. Re-entrance is the thing this prevents; completion is
     what GComplete records. *)
   GDeclared := True;
   try

   // --- Operating: CW ------------------------------------------------------
   RegisterModelSetting( 'operating.cw.sayHi',            'SAY HI ENABLE',
                         RS_OPERATING_CW_SAYHI);
   RegisterModelSetting( 'operating.cw.sayHiRateCutoff',  'SAY HI RATE CUTOFF',
                         RS_OPERATING_CW_SAYHIRATECUTOFF);
   RegisterModelSetting( 'operating.cw.keypadMemories',   'KEYPAD CW MEMORIES',
                         RS_OPERATING_CW_KEYPADMEMORIES);
   RegisterModelSetting( 'operating.cw.leadingZeros',     'LEADING ZEROS',
                         RS_OPERATING_CW_LEADINGZEROS);
   RegisterModelSetting( 'operating.cw.leadingZeroChar',  'LEADING ZERO CHARACTER',
                         RS_OPERATING_CW_LEADINGZEROCHAR);

   // Radio serial keying.  These shape only the CW TR4W generates itself by
   // toggling DTR/RTS -- a WinKeyer, a YCCC box or CW-by-CAT keep their own
   // timing -- which is why they sit in their own frame rather than beside the
   // settings that apply to every keyer.
   RegisterModelSetting( 'operating.cw.serial.ditDahRatio',    'DIT DAH RATIO',
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
   RegisterModelSetting( 'cw.speedFromDatabase', 'CW SPEED FROM DATABASE',
                         RS_CW_SPEEDFROMDATABASE);
   // MIGRATED 2026-08-14 -- the first row to graduate.  Stored: writes go to
   // settings\tr4w.json, the CFGCA row is csJSON, and so it no longer appears
   // in Ctrl-J nor in tr4w.ini.  The two halves must stay in step; see
   // docs/CFG_MIGRATION_PLAN.md.
   RegisterModelSetting( 'cw.speedIncrement',    'CW SPEED INCREMENT',
                         RS_CW_SPEEDINCREMENT);
   RegisterStoredSetting('cw.tone',              'CW TONE',
                         RS_CW_TONE);

   { CW SENDING BEHAVIOUR. These shape what the keyer sends and how, whichever
     keyer is selected -- unlike the serial-keying group above, which only
     affects CW TR4W generates itself.

     RegisterModelSetting, NOT RegisterStoredSetting: these have left CFGCA for
     TCwSettings. The legacy registrar reads four of its own attributes out of
     the row (crJ, crP, crA, crNetwork), so it CANNOT register a setting whose
     row is gone -- it raises "no CFGCA command called ..." at startup. That is
     the failure this batch hit, and it is the reason the two registrars are
     separate rather than one with a fallback. }
   RegisterModelSetting( 'cw.messagesChainable',  'ALL CW MESSAGES CHAINABLE',
                         RS_CW_MESSAGESCHAINABLE);
   RegisterModelSetting( 'cw.tuneWithDits',       'TUNE WITH DITS',
                         RS_CW_TUNEWITHDITS);
   RegisterModelSetting( 'cw.sendFourLetterCall', 'SEND COMPLETE FOUR LETTER CALL',
                         RS_CW_SENDFOURLETTERCALL);

   { The F-key button captions, 2026-08-15. }
   RegisterModelSetting( 'cw.includeFKeyNumber',              'INCLUDE F-KEY NUMBER',
                         RS_CW_INCLUDEFKEYNUMBER);

   { The old Appearance menu's contents, 2026-08-15. }
   RegisterModelSetting( 'appearance.noBorder',               'NO BORDER',
                         RS_APPEARANCE_NOBORDER);
   RegisterModelSetting( 'appearance.noCaption',              'NO CAPTION',
                         RS_APPEARANCE_NOCAPTION);
   RegisterModelSetting( 'appearance.noColumnHeader',         'NO COLUMN HEADER',
                         RS_APPEARANCE_NOCOLUMNHEADER);
   RegisterModelSetting( 'appearance.showGridlines',          'SHOW GRIDLINES',
                         RS_APPEARANCE_SHOWGRIDLINES);

   { Audio: MP3 recording and the digital voice keyer, 2026-08-15. }
   RegisterModelSetting( 'audio.mp3.recorderEnable',          'MP3 RECORDER ENABLE',
                         RS_AUDIO_MP3_RECORDERENABLE);
   (* MODEL, not stored, since 2026-09-13. Neither has a reader -- see
     TMp3Settings -- and both are carried rather than withdrawn. *)
   RegisterModelSetting( 'audio.mp3.path',                    'MP3 PATH',
                         RS_AUDIO_MP3_PATH);
   RegisterModelSetting( 'audio.mp3.player',                  'MP3 PLAYER',
                         RS_AUDIO_MP3_PLAYER);
   RegisterModelSetting( 'audio.dvk.enable',                  'DVK ENABLE',
                         RS_AUDIO_DVK_ENABLE);
   RegisterModelSetting( 'audio.dvk.localizedMessages',       'DVK LOCALIZED MESSAGES ENABLE',
                         RS_AUDIO_DVK_LOCALIZEDMESSAGES);
   (* MODEL, not stored, since 2026-09-13: Settings.Dvk.Path and .Recorder
     own these and both command names derive from the property path. *)
   RegisterModelSetting( 'audio.dvk.path',                    'DVK PATH',
                         RS_AUDIO_DVK_PATH);
   RegisterModelSetting( 'audio.dvk.recorder',                'DVK RECORDER',
                         RS_AUDIO_DVK_RECORDER);
   RegisterModelSetting( 'audio.useRecordedSigns',            'USE RECORDED SIGNS',
                         RS_AUDIO_USERECORDEDSIGNS);

   { PADDLE. The paddle keyer TR4W runs itself; a WinKeyer or YCCC box keeps its
     own. PADDLE PORT is deliberately NOT here -- it is a parallel port, and
     whether TR4W keeps supporting those is an open question (see the Hardware
     panel). Speed and tone are useful regardless of which port carries it. }
   RegisterModelSetting( 'cw.paddle.speed',       'PADDLE SPEED',
                         RS_CW_PADDLE_SPEED);
   RegisterModelSetting( 'cw.paddle.monitorTone', 'PADDLE MONITOR TONE',
                         RS_CW_PADDLE_MONITORTONE);
   RegisterModelSetting( 'cw.paddle.swap',        'SWAP PADDLES',
                         RS_CW_PADDLE_SWAP);
   RegisterModelSetting( 'cw.paddle.pttHoldCount','PADDLE PTT HOLD COUNT',
                         RS_CW_PADDLE_PTTHOLDCOUNT);

   { PTT. Not CW-only -- PTT ENABLE keys the transmitter for phone too -- but it
     is grouped with the keyer because that is where an operator changes it. }
   RegisterModelSetting( 'ptt.enable',            'PTT ENABLE',
                         RS_PTT_ENABLE);
   RegisterModelSetting( 'ptt.turnOnDelay',       'PTT TURN ON DELAY',
                         RS_PTT_TURNONDELAY);
   RegisterModelSetting( 'ptt.noPollDuringPTT',   'NO POLL DURING PTT',
                         RS_PTT_NOPOLLDURINGPTT);

   { Operating and PTT, 2026-08-15. Captions follow each command's help entry:
     AUTO CALL TERMINATE stops sending when the call window changes, and
     CONFIRM EDIT CHANGES asks before an edited QSO is written back. }
   RegisterModelSetting( 'ptt.viaCommands',                   'PTT VIA COMMANDS',
                         RS_PTT_VIACOMMANDS);
   RegisterModelSetting( 'ptt.lockout',                       'PTT LOCKOUT',
                         RS_PTT_LOCKOUT);
   RegisterModelSetting( 'operating.autoCallTerminate',       'AUTO CALL TERMINATE',
                         RS_OPERATING_AUTOCALLTERMINATE);
   RegisterModelSetting( 'operating.autoReturnToCQ',          'AUTO RETURN TO CQ MODE',
                         RS_OPERATING_AUTORETURNTOCQ);
   RegisterModelSetting( 'operating.escapeExitsSAP',          'ESCAPE EXITS SEARCH AND POUNCE',
                         RS_OPERATING_ESCAPEEXITSSAP);
   RegisterModelSetting( 'operating.leaveCursorInCall',       'LEAVE CURSOR IN CALL WINDOW',
                         RS_OPERATING_LEAVECURSORINCALL);
   RegisterModelSetting( 'operating.logWithSingleEnter',      'LOG WITH SINGLE ENTER',
                         RS_OPERATING_LOGWITHSINGLEENTER);
   RegisterModelSetting( 'operating.spaceBarDupeCheck',       'SPACE BAR DUPE CHECK ENABLE',
                         RS_OPERATING_SPACEBARDUPECHECK);
   RegisterModelSetting( 'operating.confirmEditChanges',      'CONFIRM EDIT CHANGES',
                         RS_OPERATING_CONFIRMEDITCHANGES);
   RegisterModelSetting( 'operating.autoQSONumberDecrement',  'AUTO QSO NUMBER DECREMENT',
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
   (* MOVED TO uSettingsModel 2026-09-11, and registered through the MODEL
     binding rather than the stored one.

     Their CFGCA rows are DELETED, not retired -- so RegisterStoredSetting
     cannot be used here at all: its constructor looks the command up in the
     array and raises when it is absent.  That raise is correct behaviour for
     a typo and is what caught this migration, loudly, in the unit tests.

     The keys are UNCHANGED ('operating.bands.hf'), so an existing station's
     stored value and any Preferences layout that names them still resolve. *)
   RegisterModelSetting('operating.bands.hf',   'HF BAND ENABLE',
                        RS_OPERATING_BANDS_HF);
   RegisterModelSetting('operating.bands.warc', 'WARC BAND ENABLE',
                        RS_OPERATING_BANDS_WARC);
   RegisterModelSetting('operating.bands.vhf',  'VHF BAND ENABLE',
                        RS_OPERATING_BANDS_VHF);

   // --- Operating: two radio -----------------------------------------------
   RegisterModelSetting( 'operating.tworadio.enable',       'TWO RADIO MODE',
                         RS_OPERATING_TWORADIO_ENABLE);

   { Two radio and multi-op, 2026-08-15. Captions from each command's own entry
     in commands_help_eng.ini rather than invented -- IN BAND LOCKOUT is
     documented as "prevents Band Map selection that would place both radios on
     a single band", and MULTI MULTS ONLY decides whether all QSOs or only new
     multipliers are passed around the network. }
   RegisterModelSetting( 'operating.tworadio.inBandLockout',  'IN BAND LOCKOUT',
                         RS_OPERATING_TWORADIO_INBANDLOCKOUT);
   RegisterModelSetting( 'operating.tworadio.qsyInactive',    'QSY INACTIVE RADIO',
                         RS_OPERATING_TWORADIO_QSYINACTIVE);
   RegisterModelSetting( 'operating.tworadio.swapRelaySense', 'SWAP RADIO RELAY SENSE',
                         RS_OPERATING_TWORADIO_SWAPRELAYSENSE);
   RegisterModelSetting( 'operating.tworadio.waitForStrength', 'WAIT FOR STRENGTH',
                         RS_OPERATING_TWORADIO_WAITFORSTRENGTH);
   RegisterModelSetting( 'network.multiMultsOnly',            'MULTI MULTS ONLY',
                         RS_NETWORK_MULTIMULTSONLY);
   RegisterModelSetting( 'network.intercomFile',              'INTERCOM FILE ENABLE',
                         RS_NETWORK_INTERCOMFILE);

   { Super Check Partial, band map and log files, 2026-08-15. }
   RegisterModelSetting( 'scp.possibleCalls',                 'POSSIBLE CALLS',
                         RS_SCP_POSSIBLECALLS);
   RegisterModelSetting( 'scp.partialCall',                   'PARTIAL CALL ENABLE',
                         RS_SCP_PARTIALCALL);
   RegisterModelSetting( 'scp.wildcardPartials',              'WILDCARD PARTIALS',
                         RS_SCP_WILDCARDPARTIALS);
   RegisterModelSetting( 'scp.nameFlag',                      'NAME FLAG ENABLE',
                         RS_SCP_NAMEFLAG);
   RegisterModelSetting( 'bandmap.callWindowShowAllSpots',    'CALL WINDOW SHOW ALL SPOTS',
                         RS_BANDMAP_CALLWINDOWSHOWALLSPOTS);
   RegisterModelSetting( 'bandmap.swapPacketSpotRadios',      'SWAP PACKET SPOT RADIOS',
                         RS_BANDMAP_SWAPPACKETSPOTRADIOS);
   RegisterModelSetting( 'logging.checkLogFileSize',          'CHECK LOG FILE SIZE',
                         RS_LOGGING_CHECKLOGFILESIZE);
   RegisterModelSetting( 'logging.unknownCountryFile',        'UNKNOWN COUNTRY FILE ENABLE',
                         RS_LOGGING_UNKNOWNCOUNTRYFILE);
   RegisterModelSetting( 'logging.updateRestartFile',         'UPDATE RESTART FILE ENABLE',
                         RS_LOGGING_UPDATERESTARTFILE);
   RegisterModelSetting( 'operating.tworadio.altDBuffer',   'ALT-D BUFFER ENABLE',
                         RS_OPERATING_TWORADIO_ALTDBUFFER);
   RegisterModelSetting( 'operating.tworadio.altDCQ',       'ALT-D CQ ENABLE',
                         RS_OPERATING_TWORADIO_ALTDCQ);
   RegisterModelSetting( 'operating.tworadio.blindCQ',      'ALWAYS CALL BLIND CQ',
                         RS_OPERATING_TWORADIO_BLINDCQ);
   RegisterModelSetting( 'operating.tworadio.skipActiveBand','SKIP ACTIVE BAND',
                         RS_OPERATING_TWORADIO_SKIPACTIVEBAND);

   // --- Operating: online scoring ------------------------------------------
   RegisterModelSetting( 'scoring.hamscore.enable',      'HAMSCORE ENABLE',
                         RS_SCORING_HAMSCORE_ENABLE);
   RegisterModelSetting( 'scoring.hamscore.url',         'HAMSCORE URL',
                         RS_SCORING_HAMSCORE_URL);
   RegisterModelSetting( 'scoring.hamscore.username',    'HAMSCORE USERNAME',
                         RS_SCORING_HAMSCORE_USERNAME);
   RegisterModelSetting( 'scoring.hamscore.password',    'HAMSCORE PASSWORD',
                         RS_SCORING_HAMSCORE_PASSWORD);
   RegisterModelSetting( 'scoring.hamscore.contactInfo', 'HAMSCORE SEND CONTACT INFO',
                         RS_SCORING_HAMSCORE_CONTACTINFO);
   RegisterModelSetting( 'scoring.board.postingUrl',     'SCORE POSTING URL',
                         RS_SCORING_BOARD_POSTINGURL);
   RegisterModelSetting( 'scoring.board.readingUrl',     'SCORE READING URL',
                         RS_SCORING_BOARD_READINGURL);

   // --- DX cluster ---------------------------------------------------------
   RegisterModelSetting( 'cluster.connectAtStartup', 'CONNECTION AT STARTUP',
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
   RegisterModelSetting( 'contest.autoQslInterval',     'AUTO QSL INTERVAL',
                          RS_CONTEST_AUTOQSLINTERVAL);
   RegisterModelSetting( 'contest.autoCQDelayTime',           'AUTO-CQ DELAY TIME',
                          RS_CONTEST_AUTOCQDELAYTIME);
   RegisterModelSetting('contest.beepEvery10Qsos',     'BEEP EVERY 10 QSOS',
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
   RegisterModelSetting( 'contest.countDomesticCountries','COUNT DOMESTIC COUNTRIES',
                          RS_CONTEST_COUNTDOMESTICCOUNTRIES);
   RegisterModelSetting( 'contest.customInitialExchangeString','CUSTOM INITIAL EXCHANGE STRING',
                          RS_CONTEST_CUSTOMINITIALEXCHANGESTRING);
   RegisterStoredSetting('contest.domesticMultiplier',  'DOMESTIC MULTIPLIER',
                          RS_CONTEST_DOMESTICMULTIPLIER);
   RegisterStoredSetting('contest.dxMultiplier',        'DX MULTIPLIER',
                          RS_CONTEST_DXMULTIPLIER);
   RegisterModelSetting( 'contest.exchangeMemoryEnable','EXCHANGE MEMORY ENABLE',
                          RS_CONTEST_EXCHANGEMEMORYENABLE);
   RegisterStoredSetting('contest.exchangeReceived',    'EXCHANGE RECEIVED',
                          RS_CONTEST_EXCHANGERECEIVED);
   RegisterModelSetting('contest.gridMapCenter',       'GRID MAP CENTER',
                          RS_CONTEST_GRIDMAPCENTER);
   RegisterStoredSetting('contest.initialExchange',     'INITIAL EXCHANGE',
                          RS_CONTEST_INITIALEXCHANGE);
   RegisterStoredSetting('contest.initialExchangeCursorPos','INITIAL EXCHANGE CURSOR POS',
                          RS_CONTEST_INITIALEXCHANGECURSORPOS);
   RegisterModelSetting('contest.initialExchangeOverwrite','INITIAL EXCHANGE OVERWRITE',
                          RS_CONTEST_INITIALEXCHANGEOVERWRITE);
   RegisterModelSetting( 'contest.literalDomesticQth',  'LITERAL DOMESTIC QTH',
                          RS_CONTEST_LITERALDOMESTICQTH);
   RegisterModelSetting('contest.logRsSent',           'LOG RS SENT',
                          RS_CONTEST_LOGRSSENT);
   RegisterModelSetting('contest.logRstSent',          'LOG RST SENT',
                          RS_CONTEST_LOGRSTSENT);
   RegisterModelSetting('contest.lookForRstSent',      'LOOK FOR RST SENT',
                          RS_CONTEST_LOOKFORRSTSENT);
   RegisterModelSetting('contest.messageEnable',       'MESSAGE ENABLE',
                          RS_CONTEST_MESSAGEENABLE);
   (* GRADUATED, AND IT NAMED A CONCEPT THE OLD TABLE HAD NO WORD FOR.

     The row said 5..60 minutes. The variable defaults to 0, and MainUnit:4344
     reads exactly `if TourDuration <> 0` -- so zero means "no minitour", and
     the setting could not hold its own value.

     Unlike the QSO-point rows, WIDENING THE RANGE WOULD HAVE BEEN WRONG: 0..60
     admits 1, 2, 3 and 4, which are not durations anybody wants. The value is
     not at the edge of the range, it is outside it and means something else.

     So TIntSetting gained Sentinel: one value accepted beside the range and
     offered in AllowedValues, rather than a bound relaxed until the sentinel
     slips through. That is the general shape -- "off, or a real value" -- and
     it is what a typed setting can say and a Word-bounded table row cannot.

     Read-only from crJ:2, like the QSO-point rows: a contest sets it. *)
   (* CREATED HERE NOW, AND IT USED TO BE CREATED AFTER THIS LINE.

     The guard sat beside the four QSO-point registrations further down, so
     the method pointers taken here were built from a NIL instance. It ran
     only because these methods touch no field: a non-virtual method with a
     nil Self is a plain call that never dereferences it. The QSO-point
     registrations have gone to the settings model and taken the guard with
     them, so it belongs before its first use. *)
   RegisterStoredSetting('contest.multReportMinimumBands','MULT REPORT MINIMUM BANDS',
                          RS_CONTEST_MULTREPORTMINIMUMBANDS);
   RegisterStoredSetting('contest.prefixMultiplier',    'PREFIX MULTIPLIER',
                          RS_CONTEST_PREFIXMULTIPLIER);
   RegisterStoredSetting('contest.qslMode',             'QSL MODE',
                          RS_CONTEST_QSLMODE);
   RegisterModelSetting('contest.qsoNumberByBand',     'QSO NUMBER BY BAND',
                          RS_CONTEST_QSONUMBERBYBAND);
   RegisterStoredSetting('contest.qsoPointMethod',      'QSO POINT METHOD',
                          RS_CONTEST_QSOPOINTMETHOD);
   (* GRADUATED OFF CFGCA (2026-09-09) -- AND THE TABLE IS WHY.

     These four hold -1 when the contest sets no fixed point value; the scoring
     code says so directly, `if (QSOPointsDomesticCW >= 0) then` in
     logstuff:6450. The value is legitimate and load-bearing.

     THE CFGCA ROW COULD NOT DECLARE IT. crMin and crMax are Word -- UNSIGNED --
     so the table cannot express a negative bound at all, and the rows said
     0..MAXWORD while the variables sat at -1. Every one of the four therefore
     held a value its own declared range rejected, which uTestAllSettings found
     the day it was written.

     That is not a bug to patch in the table. It is the table being unable to
     describe a setting the program legitimately has, and the fix is to stop
     asking it to: TIntSetting's bounds are signed integers, so -1 is simply in
     range and says what it means.

     READ-ONLY, from crJ:2 on the rows they replace. A contest's .cfg sets
     these; the operator does not, and a panel must not offer a control that
     edits them. That is the crJ gap the TR4QT settings review called a
     blocking prerequisite -- see TSettingBase.ReadOnly.

     THE CFGCA ROWS STAY FULLY ACTIVE, AND THAT IS NOT AN OVERSIGHT. A first
     draft of this comment said they would be retired to csRem. That would have
     been a scoring bug: csRem means CheckCommand recognises a command and does
     NOT apply it, and these four are set BY THE CONTEST'S .cfg FILE --
     "QSO POINTS DOMESTIC CW = 2" is how a contest declares its points. Retiring
     the row would leave every such contest scoring on -1.

     So this is the migration state the header calls step two, exactly: the
     registry now owns how the setting is READ, WRITTEN AND VALIDATED by
     Preferences, while the .cfg loader keeps writing the same global through
     the same row. One variable, two writers, which is what a closure over a
     global means. The row goes when the .cfg loader stops needing it, not
     before. *)
   (* THE SENTINEL IS IN THE TYPE NOW. This was a closure over TourDuration
     with an explicit range of 5..60 and 0 declared as the off value; the
     property's subrange is 0..60 and says the same thing, for the same
     reason -- MainUnit tests `<> 0` to know there is no tour. *)
   RegisterModelSetting( 'contest.minitourDuration',    'MINITOUR DURATION',
                          RS_CONTEST_MINITOURDURATION).ReadOnly := True;

   RegisterModelSetting( 'contest.multByBand',          'MULT BY BAND',
                          RS_CONTEST_MULTBYBAND).ReadOnly := True;
   RegisterModelSetting( 'contest.multByMode',          'MULT BY MODE',
                          RS_CONTEST_MULTBYMODE).ReadOnly := True;
   RegisterModelSetting( 'contest.multSheetAutoReset',  'MULT SHEET AUTO RESET',
                          RS_CONTEST_MULTSHEETAUTORESET).ReadOnly := True;
   RegisterModelSetting( 'contest.multipleBands',       'MULTIPLE BANDS',
                          RS_CONTEST_MULTIPLEBANDS);
   RegisterModelSetting( 'contest.multipleModes',       'MULTIPLE MODES',
                          RS_CONTEST_MULTIPLEMODES);
   RegisterModelSetting( 'contest.qsoByBand',           'QSO BY BAND',
                          RS_CONTEST_QSOBYBAND).ReadOnly := True;
   RegisterModelSetting( 'contest.qsoByMode',           'QSO BY MODE',
                          RS_CONTEST_QSOBYMODE).ReadOnly := True;
   (* THE THIRD STEP, TAKEN (2026-09-12): the four QSO-point values are
     properties on uSettingsModel and there is no global and no CFGCA row
     left. What stands below is what this unit's header calls a fully
     migrated setting -- registered by NAME, with the model owning the type,
     the range and the value.

     WHY THEY WERE HALF-WAY HERE. crMin and crMax are Word -- UNSIGNED -- so
     the table could not express the -1 that means "this contest sets no
     fixed point value", and all four rows said 0..MAXWORD while all four
     variables sat at -1. A getter/setter pair over the globals was the way
     round that in September. The model states it as a TYPE instead:
     TQsoPoints = -1..65535, which TrySetByCommand reads out of RTTI.

     STILL READ-ONLY, from crJ: 2 on the rows they replace. A contest sets
     these; the operator does not, and a panel must not offer a control that
     edits them. *)
   RegisterModelSetting( 'contest.qsoPointsDomesticCw',
      'QSO POINTS DOMESTIC CW',
      RS_CONTEST_QSOPOINTSDOMESTICCW).ReadOnly := True;

   RegisterModelSetting( 'contest.qsoPointsDomesticPhone',
      'QSO POINTS DOMESTIC PHONE',
      RS_CONTEST_QSOPOINTSDOMESTICPHONE).ReadOnly := True;

   RegisterModelSetting( 'contest.qsoPointsDxCw',
      'QSO POINTS DX CW',
      RS_CONTEST_QSOPOINTSDXCW).ReadOnly := True;

   RegisterModelSetting( 'contest.qsoPointsDxPhone',
      'QSO POINTS DX PHONE',
      RS_CONTEST_QSOPOINTSDXPHONE).ReadOnly := True;
   RegisterModelSetting( 'contest.qtcEnable',           'QTC ENABLE',
                          RS_CONTEST_QTCENABLE);
   RegisterModelSetting( 'contest.qtcExtraSpace',       'QTC EXTRA SPACE',
                          RS_CONTEST_QTCEXTRASPACE);
   RegisterModelSetting( 'contest.qtcMinutes',          'QTC MINUTES',
                          RS_CONTEST_QTCMINUTES);
   RegisterModelSetting( 'contest.qtcQrs',              'QTC QRS',
                          RS_CONTEST_QTCQRS);
   { THE QUICK-QSL MESSAGES MOVED TO Settings.Messages, so these are
     RegisterModelSetting -- the legacy registrar reads four of its own
     attributes out of the CFGCA row and raises at startup when the row is
     gone.

     THE FIRST THREE ARE ONE SETTING. QUICK QSL CW MESSAGE, QUICK QSL CW
     MESSAGE1 and QUICK QSL MESSAGE 1 were three rows over a single global,
     and all three keys are kept rather than a spelling chosen, because a
     panel or a saved preference may name any of them. They now agree with
     each other, which as separate stored values they did not.

     THEY ARE CONTEST-SCOPED, so Preferences edits the running value and the
     settings FILE does not hold it -- see TMessageSettings. That is the same
     arrangement the three band enables already have. }
   RegisterModelSetting( 'contest.quickQslCwMessage',   'QUICK QSL CW MESSAGE',
                          RS_CONTEST_QUICKQSLCWMESSAGE);
   RegisterModelSetting( 'contest.quickQslCwMessage1',  'QUICK QSL CW MESSAGE1',
                          RS_CONTEST_QUICKQSLCWMESSAGE1);
   RegisterModelSetting('contest.quickQslKey1',        'QUICK QSL KEY 1',
                          RS_CONTEST_QUICKQSLKEY1);
   RegisterModelSetting('contest.quickQslKey2',        'QUICK QSL KEY 2',
                          RS_CONTEST_QUICKQSLKEY2);
   RegisterModelSetting( 'contest.quickQslMessage1',    'QUICK QSL MESSAGE 1',
                          RS_CONTEST_QUICKQSLMESSAGE1);
   RegisterModelSetting( 'contest.quickQslMessage2',    'QUICK QSL MESSAGE 2',
                          RS_CONTEST_QUICKQSLMESSAGE2);
   RegisterModelSetting( 'contest.quickQslSsbMessage',  'QUICK QSL SSB MESSAGE',
                          RS_CONTEST_QUICKQSLSSBMESSAGE);
   RegisterModelSetting( 'contest.r150sMode',           'R150S MODE',
                          RS_CONTEST_R150SMODE);
   RegisterModelSetting('contest.randomCqMode',        'RANDOM CQ MODE',
                          RS_CONTEST_RANDOMCQMODE);
   RegisterModelSetting( 'contest.remainingMultDisplayMode','REMAINING MULT DISPLAY MODE',
                          RS_CONTEST_REMAININGMULTDISPLAYMODE);
   RegisterModelSetting( 'contest.reverseInitialEx',    'REVERSE INITIAL EX',
                          RS_CONTEST_REVERSEINITIALEX);
   RegisterModelSetting( 'contest.rfoblMode',           'RFOBL MODE',
                          RS_CONTEST_RFOBLMODE);
   RegisterModelSetting( 'contest.showAllSerialPorts',  'SHOW ALL SERIAL PORTS',
                          RS_CONTEST_SHOWALLSERIALPORTS);
   RegisterModelSetting( 'contest.showDomesticMultiplierName','SHOW DOMESTIC MULTIPLIER NAME',
                          RS_CONTEST_SHOWDOMESTICMULTIPLIERNAME);
   RegisterLegacySetting('contest.singleBandScore',     'SINGLE BAND SCORE',
                          'Single Band Score');
   RegisterModelSetting( 'contest.sprintQsyRule',       'SPRINT QSY RULE',
                          RS_CONTEST_SPRINTQSYRULE);
   RegisterModelSetting( 'contest.tenMinuteRule',       'TEN MINUTE RULE',
                          RS_CONTEST_TENMINUTERULE);
   RegisterStoredSetting('contest.zoneMultiplier',      'ZONE MULTIPLIER',
                          RS_CONTEST_ZONEMULTIPLIER);

   // --- Operating (34) --------------------------------
   RegisterModelSetting( 'operating.ctrlj.askForFrequencies', 'ASK FOR FREQUENCIES',
                          RS_OPERATING_CTRLJ_ASKFORFREQUENCIES);
   RegisterModelSetting('operating.ctrlj.autoDisplayDupeQso','AUTO DISPLAY DUPE QSO',
                          RS_OPERATING_CTRLJ_AUTODISPLAYDUPEQSO);
   RegisterModelSetting( 'operating.ctrlj.autoDupeEnableCq',  'AUTO DUPE ENABLE CQ',
                          RS_OPERATING_CTRLJ_AUTODUPEENABLECQ);
   RegisterModelSetting( 'operating.ctrlj.autoDupeEnableSAndP','AUTO DUPE ENABLE S AND P',
                          RS_OPERATING_CTRLJ_AUTODUPEENABLESANDP);
   RegisterModelSetting( 'operating.ctrlj.autoSPEnable',      'AUTO S&P ENABLE',
                          RS_OPERATING_CTRLJ_AUTOSPENABLE);
   RegisterModelSetting( 'operating.ctrlj.autoSPEnableSensitivity','AUTO S&P ENABLE SENSITIVITY',
                          RS_OPERATING_CTRLJ_AUTOSPENABLESENSITIVITY);
   RegisterModelSetting( 'operating.ctrlj.autoTimeIncrement', 'AUTO TIME INCREMENT',
                          RS_OPERATING_CTRLJ_AUTOTIMEINCREMENT);
   RegisterLegacySetting('operating.ctrlj.band',              'BAND',
                          'Band');
   RegisterLegacySetting('operating.ctrlj.clearDupeSheet',    'CLEAR DUPE SHEET',
                          'Clear Dupe Sheet');
   RegisterModelSetting( 'operating.ctrlj.customUserString',  'CUSTOM USER STRING',
                          RS_OPERATING_CTRLJ_CUSTOMUSERSTRING);
   RegisterModelSetting('operating.ctrlj.deEnable',          'DE ENABLE',
                          RS_OPERATING_CTRLJ_DEENABLE);
   RegisterModelSetting( 'operating.ctrlj.digitalModeEnable', 'DIGITAL MODE ENABLE',
                          RS_OPERATING_CTRLJ_DIGITALMODEENABLE);
   RegisterModelSetting( 'operating.ctrlj.distanceMode',      'DISTANCE MODE',
                          RS_OPERATING_CTRLJ_DISTANCEMODE);
   RegisterModelSetting( 'operating.ctrlj.dupeCheckSound',    'DUPE CHECK SOUND',
                          RS_OPERATING_CTRLJ_DUPECHECKSOUND);
   RegisterModelSetting('operating.ctrlj.dupeSheetAutoReset','DUPE SHEET AUTO RESET',
                          RS_OPERATING_CTRLJ_DUPESHEETAUTORESET);
   RegisterStoredSetting('operating.ctrlj.frequencyMemory',   'FREQUENCY MEMORY',
                          RS_OPERATING_CTRLJ_FREQUENCYMEMORY);
   RegisterModelSetting( 'operating.ctrlj.frequencyMemoryEnable','FREQUENCY MEMORY ENABLE',
                          RS_OPERATING_CTRLJ_FREQUENCYMEMORYENABLE);
   RegisterModelSetting( 'operating.ctrlj.frequencyPollRate', 'FREQUENCY POLL RATE',
                          RS_OPERATING_CTRLJ_FREQUENCYPOLLRATE);
   RegisterModelSetting( 'operating.ctrlj.ieSwitch',          'IE SWITCH',
                          RS_OPERATING_CTRLJ_IESWITCH);
   RegisterModelSetting( 'operating.ctrlj.incrementTimeEnable','INCREMENT TIME ENABLE',
                          RS_OPERATING_CTRLJ_INCREMENTTIMEENABLE);
   RegisterModelSetting( 'operating.ctrlj.logFrequencyEnable','LOG FREQUENCY ENABLE',
                          RS_OPERATING_CTRLJ_LOGFREQUENCYENABLE);
   RegisterModelSetting( 'operating.ctrlj.logSubTitle',       'LOG SUB TITLE',
                          RS_OPERATING_CTRLJ_LOGSUBTITLE);
   RegisterModelSetting( 'operating.ctrlj.mainCallsign',      'MAIN CALLSIGN',
                          RS_OPERATING_CTRLJ_MAINCALLSIGN);
   RegisterStoredSetting('operating.ctrlj.mode',              'MODE',
                          RS_OPERATING_CTRLJ_MODE);
   RegisterModelSetting( 'operating.ctrlj.possibleCallAcceptKey','POSSIBLE CALL ACCEPT KEY',
                          RS_OPERATING_CTRLJ_POSSIBLECALLACCEPTKEY);
   RegisterModelSetting( 'operating.ctrlj.possibleCallLeftKey','POSSIBLE CALL LEFT KEY',
                          RS_OPERATING_CTRLJ_POSSIBLECALLLEFTKEY);
   RegisterModelSetting( 'operating.ctrlj.possibleCallMode',  'POSSIBLE CALL MODE',
                          RS_OPERATING_CTRLJ_POSSIBLECALLMODE);
   RegisterModelSetting( 'operating.ctrlj.possibleCallRightKey','POSSIBLE CALL RIGHT KEY',
                          RS_OPERATING_CTRLJ_POSSIBLECALLRIGHTKEY);
   RegisterModelSetting('operating.ctrlj.qsxEnable',         'QSX ENABLE',
                          RS_OPERATING_CTRLJ_QSXENABLE);
   RegisterModelSetting( 'operating.ctrlj.qzbRandomOffsetEnable','QZB RANDOM OFFSET ENABLE',
                          RS_OPERATING_CTRLJ_QZBRANDOMOFFSETENABLE);
   RegisterModelSetting( 'operating.ctrlj.radiusOfEarth',     'RADIUS OF EARTH',
                          RS_OPERATING_CTRLJ_RADIUSOFEARTH);
   RegisterModelSetting( 'operating.ctrlj.shiftKeyEnable',    'SHIFT KEY ENABLE',
                          RS_OPERATING_CTRLJ_SHIFTKEYENABLE);
   RegisterModelSetting( 'operating.ctrlj.stationsCallsignsMask','STATIONS CALLSIGNS MASK',
                          RS_OPERATING_CTRLJ_STATIONSCALLSIGNSMASK);
   RegisterModelSetting( 'operating.ctrlj.wakeUpTimeOut',     'WAKE UP TIME OUT',
                          RS_OPERATING_CTRLJ_WAKEUPTIMEOUT);

   // --- CW (12) ---------------------------------------
   RegisterModelSetting( 'cw.ctrlj.autoSendCharacterCount',   'AUTO SEND CHARACTER COUNT',
                          RS_CW_CTRLJ_AUTOSENDCHARACTERCOUNT);
   RegisterStoredSetting('cw.ctrlj.codeSpeed',                'CODE SPEED',
                          RS_CW_CTRLJ_CODESPEED);
   (* PADDLE PORT named which PARALLEL port the paddle was wired to, and went
     with the LPT removal of 2026-09-13.  A YCCC box reports its own paddle
     over OTRSP. *)
   RegisterModelSetting( 'cw.ctrlj.questionMarkChar',         'QUESTION MARK CHAR',
                          RS_CW_CTRLJ_QUESTIONMARKCHAR);
   { THE CUT NUMBERS moved to Settings.Cw, so RegisterModelSetting. The keys
     are unchanged, which is the point of keys being ours: these four still
     live at cw.ctrlj.* in the settings file and no panel changes. }
   RegisterModelSetting( 'cw.ctrlj.short0',                   'SHORT 0',
                          RS_CW_CTRLJ_SHORT0);
   RegisterModelSetting( 'cw.ctrlj.short1',                   'SHORT 1',
                          RS_CW_CTRLJ_SHORT1);
   RegisterModelSetting( 'cw.ctrlj.short2',                   'SHORT 2',
                          RS_CW_CTRLJ_SHORT2);
   RegisterModelSetting( 'cw.ctrlj.short9',                   'SHORT 9',
                          RS_CW_CTRLJ_SHORT9);
   RegisterModelSetting('cw.ctrlj.shortIntegers',            'SHORT INTEGERS',
                          RS_CW_CTRLJ_SHORTINTEGERS);
   RegisterModelSetting( 'cw.ctrlj.slashMarkChar',            'SLASH MARK CHAR',
                          RS_CW_CTRLJ_SLASHMARKCHAR);
   RegisterModelSetting('cw.ctrlj.startSendingNowKey',       'START SENDING NOW KEY',
                          RS_CW_CTRLJ_STARTSENDINGNOWKEY);
   RegisterModelSetting( 'cw.ctrlj.tuneAltDEnable',           'TUNE ALT-D ENABLE',
                          RS_CW_CTRLJ_TUNEALTDENABLE);

   // --- Appearance (13) -------------------------------
   // customCaret was here until 2026-08-18; the CFG row is csRem now and
   // retired rows are not registered (cf. AUTO ALT-D ENABLE, BACKCOPY ENABLE).
   RegisterModelSetting( 'appearance.ctrlj.beepEnable',       'BEEP ENABLE',
                          RS_APPEARANCE_CTRLJ_BEEPENABLE);
   RegisterModelSetting( 'appearance.ctrlj.columnAutosize',   'COLUMN AUTOSIZE',
                          RS_APPEARANCE_CTRLJ_COLUMNAUTOSIZE);
   RegisterModelSetting( 'appearance.ctrlj.completeCallsignMask','COMPLETE CALLSIGN MASK',
                          RS_APPEARANCE_CTRLJ_COMPLETECALLSIGNMASK);
   RegisterModelSetting( 'appearance.ctrlj.contactsPerPage',  'CONTACTS PER PAGE',
                          RS_APPEARANCE_CTRLJ_CONTACTSPERPAGE);
   RegisterModelSetting( 'appearance.ctrlj.hourDisplay',      'HOUR DISPLAY',
                          RS_APPEARANCE_CTRLJ_HOURDISPLAY);
   RegisterModelSetting('appearance.ctrlj.insertMode',       'INSERT MODE',
                          RS_APPEARANCE_CTRLJ_INSERTMODE);
   RegisterModelSetting( 'appearance.ctrlj.rateDisplay',      'RATE DISPLAY',
                          RS_APPEARANCE_CTRLJ_RATEDISPLAY);
   (* True, True: broadcast to the other position, and needs a restart --
     which is what the row's crNetwork: 1 and crJ: 1 said. *)
   RegisterModelSetting( 'appearance.layout.rowCount',         'ROW COUNT',
                          RS_APPEARANCE_LAYOUT_ROWCOUNT, True, True);
   RegisterModelSetting( 'appearance.ctrlj.showFrequencyInLog','SHOW FREQUENCY IN LOG',
                          RS_APPEARANCE_CTRLJ_SHOWFREQUENCYINLOG);
   RegisterModelSetting( 'appearance.ctrlj.showTypedCallsign','SHOW TYPED CALLSIGN',
                          RS_APPEARANCE_CTRLJ_SHOWTYPEDCALLSIGN);
   RegisterModelSetting( 'appearance.ctrlj.userInfoShown',    'USER INFO SHOWN',
                          RS_APPEARANCE_CTRLJ_USERINFOSHOWN);
   RegisterModelSetting( 'appearance.layout.windowSize',       'WINDOW SIZE',
                          RS_APPEARANCE_LAYOUT_WINDOWSIZE, True, True);

   (* --- Hardware (1) -------------------------------------------------

     FOUR OF THE FIVE WENT WITH THE PARALLEL PORT, 2026-09-13.  The three LPT
     base addresses addressed it directly; USE CONTROL PORT chose between the
     radio's control port and an LPT for the paddle and foot switch, a choice
     with only one side left and whose other arm had already been deleted as
     worse than dead.

     STEREO PIN HIGH STAYS, and it is the distinction worth keeping: it is
     read by YCCCSetStereo, so it describes what the operator wants rather
     than which LPT pin delivers it. *)
   RegisterStoredSetting('hardware.ctrlj.stereoPinHigh',      'STEREO PIN HIGH',
                          RS_HARDWARE_CTRLJ_STEREOPINHIGH);

   // --- Files/Updates (7) ----------------------------
   RegisterModelSetting( 'files.ctrlj.allowAutoUpdate',       'ALLOW AUTO UPDATE',
                          RS_FILES_CTRLJ_ALLOWAUTOUPDATE);
   RegisterModelSetting( 'files.ctrlj.callsignUpdateEnable',  'CALLSIGN UPDATE ENABLE',
                          RS_FILES_CTRLJ_CALLSIGNUPDATEENABLE);
   RegisterModelSetting('files.ctrlj.countryInformationFile','COUNTRY INFORMATION FILE',
                          RS_FILES_CTRLJ_COUNTRYINFORMATIONFILE);
   RegisterModelSetting( 'files.ctrlj.ctyUpdateCheckOnStartup','CTY UPDATE CHECK ON STARTUP',
                          RS_FILES_CTRLJ_CTYUPDATECHECKONSTARTUP);
   RegisterModelSetting( 'files.ctrlj.domesticFilename',      'DOMESTIC FILENAME',
                          RS_FILES_CTRLJ_DOMESTICFILENAME).ReadOnly := True;
   RegisterModelSetting( 'files.ctrlj.missingcallsignsFileEnable','MISSINGCALLSIGNS FILE ENABLE',
                          RS_FILES_CTRLJ_MISSINGCALLSIGNSFILEENABLE);
   RegisterModelSetting( 'files.ctrlj.unknownCountryFileName','UNKNOWN COUNTRY FILE NAME',
                          RS_FILES_CTRLJ_UNKNOWNCOUNTRYFILENAME);

   // --- Band Map (5) ---------------------------------
   RegisterStoredSetting('bandmap.ctrlj.bandMapCutoffFrequency','BAND MAP CUTOFF FREQUENCY',
                          RS_BANDMAP_CTRLJ_BANDMAPCUTOFFFREQUENCY);
   (* MOVED TO uSettingsModel 2026-09-11, and they keep crJ:1's meaning --
     NeedsRestart -- explicitly, because for these three it is true: the band
     map grid's geometry is computed once in LayOutGrid.

     Their ranges moved with them, from crMin/crMax into SUBRANGE TYPES on the
     properties, so TrySetByCommand still refuses 51 for an item height
     without being told which setting that is. *)
   RegisterModelSetting('bandmap.ctrlj.bandMapItemHeight',   'BAND MAP ITEM HEIGHT',
                        RS_BANDMAP_CTRLJ_BANDMAPITEMHEIGHT, True, True);
   RegisterModelSetting('bandmap.ctrlj.bandMapItemWidth',    'BAND MAP ITEM WIDTH',
                        RS_BANDMAP_CTRLJ_BANDMAPITEMWIDTH, True, True);
   RegisterModelSetting('bandmap.ctrlj.bandMapSize',         'BAND MAP SIZE',
                        RS_BANDMAP_CTRLJ_BANDMAPSIZE, True, True);
   RegisterModelSetting( 'bandmap.ctrlj.bandMapSplitMode',    'BAND MAP SPLIT MODE',
                          RS_BANDMAP_CTRLJ_BANDMAPSPLITMODE);

   // --- Network (2) ----------------------------------

   (* THE FIRST FULLY-MODERN SETTING IN THE TREE -- TBoolSetting.Own, so the
     registry holds the value, there is no global, and CFGCA knows nothing
     about it. See the three registration forms in this unit's header; this is
     the third, and the shape every new setting should take.

     WHAT IT CONTROLS. On by default: server certificates are checked against
     the shipped root bundle, and the certificate must belong to the host we
     asked for. Off means TR4W connects anyway and says so in the log.

     WHY IT CAN BE TURNED OFF AT ALL, given that the point of the change was
     to start verifying: until 2026-09-09 nothing was verified anywhere, so
     turning it on is a behaviour change that could break a download or an
     upload that works today -- a server with a misconfigured chain, a
     corporate middlebox, a root newer than our bundle. Discovering that
     during a contest with no way through would be worse than the exposure.

     It is deliberately NOT reachable from a dialog yet. An operator who needs
     it edits settings\tr4w.json, which is friction on purpose: this should
     be a considered act, not a checkbox to click past when something fails. *)
   RegisterSetting(TBoolSetting.Own('network.verifyServerCertificates',
                   'Verify server certificates for downloads and uploads',
                   True));

   (* NOT BROADCAST, which is the one place the model registrar needs
     telling: its default is True and the row said crNetwork: 0. Sending
     this position's name to the other positions would overwrite theirs
     with it, which is the opposite of what the setting is for. *)
   RegisterModelSetting('network.ctrlj.computerName',        'COMPUTER NAME',
                          RS_NETWORK_CTRLJ_COMPUTERNAME, False);
   RegisterModelSetting( 'network.ctrlj.netStatusUpdateInterval','NET STATUS UPDATE INTERVAL',
                          RS_NETWORK_CTRLJ_NETSTATUSUPDATEINTERVAL);

   // --- Voice/DVK -----------------------------------
   (* THE MP3 RECORDER SETTINGS ARE GONE, retired 2026-09-09 to match the
     comment that has stood above their rows in uCFG since the recorder itself
     was deleted on 2026-09-07: "their COMMANDS are marked csRem". One of the
     four -- SAMPLERATE -- actually was. Bitrate and duration were not, so they
     stayed live, stored, and offered in Preferences for a feature with no
     code behind it.

     FOUND BY uTestAllSettings, which is the point of that suite: bitrate's
     value was 0 while its own allow-list is (8,16,24,32,40,48,56,64), so
     Preferences would have shown a drop-down that could not represent the
     current value -- and saving the form would have changed a setting the
     operator never touched. Nothing else in the tree was ever going to notice.

     The DECLARATIONS in uCFG stay: ListParamArray's lpVar is dereferenced with
     no nil check, so a blanked row is a latent access violation rather than a
     tidy hole. Retiring the COMMAND is the mechanism this tree already uses.

     MP3 RECORDER ENABLE is deliberately left alone. It is equally dead, but it
     has a designed checkbox in Preferences (chkMP3RecorderEnable), so removing
     it is a change to a form and NY4I should see it rather than find it. *)

   // --- Advanced (2) ---------------------------------
   RegisterModelSetting( 'advanced.handLogMode',        'HAND LOG MODE',
                          RS_ADVANCED_HANDLOGMODE);
   RegisterModelSetting('advanced.noLog',              'NO LOG',
                          RS_ADVANCED_NOLOG);

   // --- DX Cluster (1) -------------------------------
   RegisterModelSetting( 'cluster.ctrlj.broadcastAllPacketData','BROADCAST ALL PACKET DATA',
                          RS_CLUSTER_CTRLJ_BROADCASTALLPACKETDATA);
   // Two rows a case-SENSITIVE type scan missed on 2026-08-16: their crType is
   // spelled 'ctFilename' and 'ctinteger' in CFGCA. Pascal does not care; the
   // scan did, and reported Ctrl-J empty while they were still in it.
   (* STEREO CONTROL PIN was WHICH LPT PIN drove the headphone relay -- pin 5
     or pin 9 -- and went with the parallel port.  STEREO PIN HIGH, the state
     it applied, stays: see the Hardware group above. *)
   RegisterStoredSetting('files.ctrlj.initialExchangeFilename','INITIAL EXCHANGE FILENAME',
                          RS_FILES_CTRLJ_INITIALEXCHANGEFILENAME);

      GComplete := True;
   except
      on E: Exception do
         begin
         GFailure := E.ClassName + ': ' + E.Message;
         raise;
         end;
   end;
end;

end.

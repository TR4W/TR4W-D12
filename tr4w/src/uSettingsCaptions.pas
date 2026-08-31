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
unit uSettingsCaptions;
{$I tr4w.inc}

{
  THE PREFERENCES SETTING LABELS, as resourcestrings so they can be translated.

  These are the third argument of every RegisterStoredSetting call. They were
  plain string literals until 2026-08-31, which meant they reached no catalogue
  and were never translated -- and because the Preferences SEARCH INDEX matches
  on this same text, a German operator had to search in ENGLISH for a setting
  whose on-screen label was German.

  WHY THEY ARE IN THEIR OWN UNIT rather than among the ~700 in uTR4WStrings.
  The key a translator works against is `unitname:identifier`, so the unit name
  is part of the permanent address of every one of these strings. Keeping them
  together gives the catalogue one clearly labelled block for "the settings
  labels" instead of scattering them through the general string table. It does
  NOT split the .po file -- there is one catalogue per language regardless.

  THE IDENTIFIER COMES FROM THE SETTING KEY, NEVER FROM THE ENGLISH. The msgctxt
  is permanent: rename it and every translator's work on that string is orphaned.
  A key-derived name survives an improvement to the English wording, which is
  the change most likely to happen. So 'operating.cw.sayHi' is RS_OPERATING_CW_SAYHI
  no matter how the sentence beside it is later reworded.

  DO NOT EDIT BY HAND TO ADD A SETTING. Add the RegisterStoredSetting call with
  its caption as a resourcestring declared here; the two belong together and
  Lint-SearchIndex will not catch a missing caption for you.
}

interface

resourcestring
   RS_OPERATING_CW_SAYHI                      = 'Send a greeting to stations worked before';
   RS_OPERATING_CW_SAYHIRATECUTOFF            = 'Stop above this rate';
   RS_OPERATING_CW_KEYPADMEMORIES             = 'Number keypad sends CW memories';
   RS_OPERATING_CW_LEADINGZEROS               = 'Leading zeros';
   RS_OPERATING_CW_LEADINGZEROCHAR            = 'Leading zero sent as';
   RS_OPERATING_CW_SERIAL_DITDAHRATIO         = 'Dit/dah ratio';
   RS_OPERATING_CW_SERIAL_WEIGHT              = 'Weight';
   RS_OPERATING_CW_SERIAL_FARNSWORTH          = 'Farnsworth spacing';
   RS_OPERATING_CW_SERIAL_FARNSWORTHSPEED     = 'Character speed';
   RS_CW_ENABLE                               = 'Send CW';
   RS_CW_SPEEDFROMDATABASE                    = 'Match the speed a station was worked at before';
   RS_CW_SPEEDINCREMENT                       = 'Speed step';
   RS_CW_TONE                                 = 'Sidetone';
   RS_CW_MESSAGESCHAINABLE                    = 'Any message may chain into the next';
   RS_CW_TUNEWITHDITS                         = 'Tune with dits rather than a solid carrier';
   RS_CW_SENDFOURLETTERCALL                   = 'Always send all four letters of a four-letter call';
   RS_CW_INCLUDEFKEYNUMBER                    = 'Show the key number on the function-key buttons';
   RS_APPEARANCE_NOBORDER                     = 'Main window has no border';
   RS_APPEARANCE_NOCAPTION                    = 'Main window has no title bar';
   RS_APPEARANCE_NOCOLUMNHEADER               = 'Hide the log column headings';
   RS_APPEARANCE_SHOWGRIDLINES                = 'Draw gridlines in the log';
   RS_AUDIO_MP3_RECORDERENABLE                = 'Record each QSO to MP3';
   RS_AUDIO_MP3_PATH                          = 'Folder for MP3 recordings';
   RS_AUDIO_MP3_PLAYER                        = 'MP3 player program';
   RS_AUDIO_DVK_ENABLE                        = 'Use the digital voice keyer';
   RS_AUDIO_DVK_LOCALIZEDMESSAGES             = 'Use localized DVK message files';
   RS_AUDIO_DVK_PATH                          = 'Folder for DVK recordings';
   RS_AUDIO_DVK_RECORDER                      = 'DVK recorder program';
   RS_AUDIO_USERECORDEDSIGNS                  = 'Send recorded audio for callsign characters';
   RS_CW_PADDLE_SPEED                         = 'Paddle speed';
   RS_CW_PADDLE_MONITORTONE                   = 'Paddle sidetone';
   RS_CW_PADDLE_SWAP                          = 'Swap dit and dah';
   RS_CW_PADDLE_PTTHOLDCOUNT                  = 'Hold PTT for';
   RS_PTT_ENABLE                              = 'Assert PTT when transmitting';
   RS_PTT_TURNONDELAY                         = 'Delay after PTT before sending';
   RS_PTT_NOPOLLDURINGPTT                     = 'Stop polling the radio while transmitting';
   RS_PTT_VIACOMMANDS                         = 'Key the transmitter with a CAT command';
   RS_PTT_LOCKOUT                             = 'Lock out PTT';
   RS_OPERATING_AUTOCALLTERMINATE             = 'Stop sending when the call window changes';
   RS_OPERATING_AUTORETURNTOCQ                = 'Return to CQ mode after logging';
   RS_OPERATING_ESCAPEEXITSSAP                = 'Escape leaves search and pounce';
   RS_OPERATING_LEAVECURSORINCALL             = 'Leave the cursor in the call window';
   RS_OPERATING_LOGWITHSINGLEENTER            = 'Log with a single Enter';
   RS_OPERATING_SPACEBARDUPECHECK             = 'Space bar performs a dupe check';
   RS_OPERATING_CONFIRMEDITCHANGES            = 'Confirm before saving an edited QSO';
   RS_OPERATING_AUTOQSONUMBERDECREMENT        = 'Give the serial number back when a QSO is abandoned';
   RS_OPERATING_BANDS_HF                      = 'HF (160 - 10 m)';
   RS_OPERATING_BANDS_WARC                    = 'WARC (30, 17, 12 m)';
   RS_OPERATING_BANDS_VHF                     = 'VHF and up';
   RS_OPERATING_TWORADIO_ENABLE               = 'Two radio mode';
   RS_OPERATING_TWORADIO_INBANDLOCKOUT        = 'Stop both radios landing on one band';
   RS_OPERATING_TWORADIO_QSYINACTIVE          = 'QSY the inactive radio';
   RS_OPERATING_TWORADIO_SWAPRELAYSENSE       = 'Invert the radio relay sense';
   RS_OPERATING_TWORADIO_WAITFORSTRENGTH      = 'Wait for a signal strength reading';
   RS_NETWORK_MULTIMULTSONLY                  = 'Pass only new multipliers around the network';
   RS_NETWORK_INTERCOMFILE                    = 'Log network messages to INTERCOM.TXT';
   RS_SCP_POSSIBLECALLS                       = 'Offer possible calls';
   RS_SCP_PARTIALCALL                         = 'Match on a partial callsign';
   RS_SCP_WILDCARDPARTIALS                    = 'Allow wildcards in a partial';
   RS_SCP_NAMEFLAG                            = 'Flag a station whose name is known';
   RS_BANDMAP_CALLWINDOWSHOWALLSPOTS          = 'Show every spot in the call window';
   RS_BANDMAP_SWAPPACKETSPOTRADIOS            = 'Send spots to the other radio';
   RS_LOGGING_CHECKLOGFILESIZE                = 'Warn when the log file grows unexpectedly';
   RS_LOGGING_UNKNOWNCOUNTRYFILE              = 'Record callsigns with no country match';
   RS_LOGGING_UPDATERESTARTFILE               = 'Keep the restart file up to date';
   RS_OPERATING_TWORADIO_ALTDBUFFER           = 'Alt-D remembers what you typed';
   RS_OPERATING_TWORADIO_ALTDCQ               = 'Alt-D can start a CQ on the second radio';
   RS_OPERATING_TWORADIO_BLINDCQ              = 'Always call a blind CQ';
   RS_OPERATING_TWORADIO_SKIPACTIVEBAND       = 'Skip the band the other radio is on';
   RS_SCORING_HAMSCORE_ENABLE                 = 'Post my score while the contest runs';
   RS_SCORING_HAMSCORE_URL                    = 'Service URL';
   RS_SCORING_HAMSCORE_USERNAME               = 'Username';
   RS_SCORING_HAMSCORE_PASSWORD               = 'Password';
   RS_SCORING_HAMSCORE_CONTACTINFO            = 'Include contact information';
   RS_SCORING_BOARD_POSTINGURL                = 'Posting URL';
   RS_SCORING_BOARD_READINGURL                = 'Reading URL';
   RS_CLUSTER_CONNECTATSTARTUP                = 'Connect at startup';
   RS_CONTEST_AUTOQSLINTERVAL                 = 'Auto QSL Interval';
   RS_CONTEST_AUTOCQDELAYTIME                 = 'Auto-CQ Delay Time';
   RS_CONTEST_BEEPEVERY10QSOS                 = 'Beep Every 10 QSOs';
   RS_CONTEST_CATEGORYASSISTED                = 'Category-Assisted';
   RS_CONTEST_CATEGORYBAND                    = 'Category-Band';
   RS_CONTEST_CATEGORYMODE                    = 'Category-Mode';
   RS_CONTEST_CATEGORYOPERATOR                = 'Category-Operator';
   RS_CONTEST_CATEGORYOVERLAY                 = 'Category-Overlay';
   RS_CONTEST_CATEGORYPOWER                   = 'Category-Power';
   RS_CONTEST_CATEGORYTRANSMITTER             = 'Category-Transmitter';
   RS_CONTEST_CONTEST                         = 'Contest';
   RS_CONTEST_CONTESTNAME                     = 'Contest Name';
   RS_CONTEST_CONTESTTITLE                    = 'Contest Title';
   RS_CONTEST_COUNTDOMESTICCOUNTRIES          = 'Count Domestic Countries';
   RS_CONTEST_CUSTOMINITIALEXCHANGESTRING     = 'Custom Initial Exchange String';
   RS_CONTEST_DOMESTICMULTIPLIER              = 'Domestic Multiplier';
   RS_CONTEST_DXMULTIPLIER                    = 'DX Multiplier';
   RS_CONTEST_EXCHANGEMEMORYENABLE            = 'Exchange Memory Enable';
   RS_CONTEST_EXCHANGERECEIVED                = 'Exchange Received';
   RS_CONTEST_GRIDMAPCENTER                   = 'Grid Map Center';
   RS_CONTEST_INITIALEXCHANGE                 = 'Initial Exchange';
   RS_CONTEST_INITIALEXCHANGECURSORPOS        = 'Initial Exchange Cursor Pos';
   RS_CONTEST_INITIALEXCHANGEOVERWRITE        = 'Initial Exchange Overwrite';
   RS_CONTEST_LITERALDOMESTICQTH              = 'Literal Domestic Qth';
   RS_CONTEST_LOGRSSENT                       = 'Log Rs Sent';
   RS_CONTEST_LOGRSTSENT                      = 'Log Rst Sent';
   RS_CONTEST_LOOKFORRSTSENT                  = 'Look For Rst Sent';
   RS_CONTEST_MESSAGEENABLE                   = 'Message Enable';
   RS_CONTEST_MINITOURDURATION                = 'Minitour Duration';
   RS_CONTEST_MULTBYBAND                      = 'Mult By Band';
   RS_CONTEST_MULTBYMODE                      = 'Mult By Mode';
   RS_CONTEST_MULTREPORTMINIMUMBANDS          = 'Mult Report Minimum Bands';
   RS_CONTEST_MULTSHEETAUTORESET              = 'Mult Sheet Auto Reset';
   RS_CONTEST_MULTIPLEBANDS                   = 'Multiple Bands';
   RS_CONTEST_MULTIPLEMODES                   = 'Multiple Modes';
   RS_CONTEST_PREFIXMULTIPLIER                = 'Prefix Multiplier';
   RS_CONTEST_QSLMODE                         = 'QSL Mode';
   RS_CONTEST_QSOBYBAND                       = 'QSO By Band';
   RS_CONTEST_QSOBYMODE                       = 'QSO By Mode';
   RS_CONTEST_QSONUMBERBYBAND                 = 'QSO Number By Band';
   RS_CONTEST_QSOPOINTMETHOD                  = 'QSO Point Method';
   RS_CONTEST_QSOPOINTSDOMESTICCW             = 'QSO Points Domestic CW';
   RS_CONTEST_QSOPOINTSDOMESTICPHONE          = 'QSO Points Domestic Phone';
   RS_CONTEST_QSOPOINTSDXCW                   = 'QSO Points DX CW';
   RS_CONTEST_QSOPOINTSDXPHONE                = 'QSO Points DX Phone';
   RS_CONTEST_QTCENABLE                       = 'Qtc Enable';
   RS_CONTEST_QTCEXTRASPACE                   = 'Qtc Extra Space';
   RS_CONTEST_QTCMINUTES                      = 'Qtc Minutes';
   RS_CONTEST_QTCQRS                          = 'Qtc Qrs';
   RS_CONTEST_QUICKQSLCWMESSAGE               = 'Quick QSL CW Message';
   RS_CONTEST_QUICKQSLCWMESSAGE1              = 'Quick QSL CW Message1';
   RS_CONTEST_QUICKQSLKEY1                    = 'Quick QSL Key 1';
   RS_CONTEST_QUICKQSLKEY2                    = 'Quick QSL Key 2';
   RS_CONTEST_QUICKQSLMESSAGE1                = 'Quick QSL Message 1';
   RS_CONTEST_QUICKQSLMESSAGE2                = 'Quick QSL Message 2';
   RS_CONTEST_QUICKQSLSSBMESSAGE              = 'Quick QSL SSB Message';
   RS_CONTEST_R150SMODE                       = 'R150S Mode';
   RS_CONTEST_RANDOMCQMODE                    = 'Random CQ Mode';
   RS_CONTEST_REMAININGMULTDISPLAYMODE        = 'Remaining Mult Display Mode';
   RS_CONTEST_REVERSEINITIALEX                = 'Reverse Initial Ex';
   RS_CONTEST_RFOBLMODE                       = 'Rfobl Mode';
   RS_CONTEST_SHOWALLSERIALPORTS              = 'Show All Serial Ports';
   RS_CONTEST_SHOWDOMESTICMULTIPLIERNAME      = 'Show Domestic Multiplier Name';
   RS_CONTEST_SPRINTQSYRULE                   = 'Sprint Qsy Rule';
   RS_CONTEST_TENMINUTERULE                   = 'Ten Minute Rule';
   RS_CONTEST_ZONEMULTIPLIER                  = 'Zone Multiplier';
   RS_OPERATING_CTRLJ_ASKFORFREQUENCIES       = 'Ask For Frequencies';
   RS_OPERATING_CTRLJ_AUTODISPLAYDUPEQSO      = 'Auto Display Dupe QSO';
   RS_OPERATING_CTRLJ_AUTODUPEENABLECQ        = 'Auto Dupe Enable CQ';
   RS_OPERATING_CTRLJ_AUTODUPEENABLESANDP     = 'Auto Dupe Enable S And P';
   RS_OPERATING_CTRLJ_AUTOSPENABLE            = 'Auto S&P Enable';
   RS_OPERATING_CTRLJ_AUTOSPENABLESENSITIVITY = 'Auto S&P Enable Sensitivity';
   RS_OPERATING_CTRLJ_AUTOTIMEINCREMENT       = 'Auto Time Increment';
   RS_OPERATING_CTRLJ_CUSTOMUSERSTRING        = 'Custom User String';
   RS_OPERATING_CTRLJ_DEENABLE                = 'De Enable';
   RS_OPERATING_CTRLJ_DIGITALMODEENABLE       = 'Digital Mode Enable';
   RS_OPERATING_CTRLJ_DISTANCEMODE            = 'Distance Mode';
   RS_OPERATING_CTRLJ_DUPECHECKSOUND          = 'Dupe Check Sound';
   RS_OPERATING_CTRLJ_DUPESHEETAUTORESET      = 'Dupe Sheet Auto Reset';
   RS_OPERATING_CTRLJ_FREQUENCYMEMORY         = 'Frequency Memory';
   RS_OPERATING_CTRLJ_FREQUENCYMEMORYENABLE   = 'Frequency Memory Enable';
   RS_OPERATING_CTRLJ_FREQUENCYPOLLRATE       = 'Frequency Poll Rate';
   RS_OPERATING_CTRLJ_IESWITCH                = 'Ie Switch';
   RS_OPERATING_CTRLJ_INCREMENTTIMEENABLE     = 'Increment Time Enable';
   RS_OPERATING_CTRLJ_LOGFREQUENCYENABLE      = 'Log Frequency Enable';
   RS_OPERATING_CTRLJ_LOGSUBTITLE             = 'Log Sub Title';
   RS_OPERATING_CTRLJ_MAINCALLSIGN            = 'Main Callsign';
   RS_OPERATING_CTRLJ_MODE                    = 'Mode';
   RS_OPERATING_CTRLJ_POSSIBLECALLACCEPTKEY   = 'Possible Call Accept Key';
   RS_OPERATING_CTRLJ_POSSIBLECALLLEFTKEY     = 'Possible Call Left Key';
   RS_OPERATING_CTRLJ_POSSIBLECALLMODE        = 'Possible Call Mode';
   RS_OPERATING_CTRLJ_POSSIBLECALLRIGHTKEY    = 'Possible Call Right Key';
   RS_OPERATING_CTRLJ_QSXENABLE               = 'Qsx Enable';
   RS_OPERATING_CTRLJ_QZBRANDOMOFFSETENABLE   = 'Qzb Random Offset Enable';
   RS_OPERATING_CTRLJ_RADIUSOFEARTH           = 'Radius Of Earth';
   RS_OPERATING_CTRLJ_SHIFTKEYENABLE          = 'Shift Key Enable';
   RS_OPERATING_CTRLJ_STATIONSCALLSIGNSMASK   = 'Stations Callsigns Mask';
   RS_OPERATING_CTRLJ_WAKEUPTIMEOUT           = 'Wake Up Time Out';
   RS_CW_CTRLJ_AUTOSENDCHARACTERCOUNT         = 'Auto Send Character Count';
   RS_CW_CTRLJ_CODESPEED                      = 'Code Speed';
   RS_CW_CTRLJ_PADDLEPORT                     = 'Paddle Port';
   RS_CW_CTRLJ_QUESTIONMARKCHAR               = 'Question Mark Char';
   RS_CW_CTRLJ_SHORT0                         = 'Short 0';
   RS_CW_CTRLJ_SHORT1                         = 'Short 1';
   RS_CW_CTRLJ_SHORT2                         = 'Short 2';
   RS_CW_CTRLJ_SHORT9                         = 'Short 9';
   RS_CW_CTRLJ_SHORTINTEGERS                  = 'Short Integers';
   RS_CW_CTRLJ_SLASHMARKCHAR                  = 'Slash Mark Char';
   RS_CW_CTRLJ_STARTSENDINGNOWKEY             = 'Start Sending Now Key';
   RS_CW_CTRLJ_TUNEALTDENABLE                 = 'Tune Alt-D Enable';
   RS_APPEARANCE_CTRLJ_BEEPENABLE             = 'Beep Enable';
   RS_APPEARANCE_CTRLJ_COLUMNAUTOSIZE         = 'Column Autosize';
   RS_APPEARANCE_CTRLJ_COMPLETECALLSIGNMASK   = 'Complete Callsign Mask';
   RS_APPEARANCE_CTRLJ_CONTACTSPERPAGE        = 'Contacts Per Page';
   RS_APPEARANCE_CTRLJ_HOURDISPLAY            = 'Hour Display';
   RS_APPEARANCE_CTRLJ_INSERTMODE             = 'Insert Mode';
   RS_APPEARANCE_CTRLJ_RATEDISPLAY            = 'Rate Display';
   RS_APPEARANCE_CTRLJ_REMINDER               = 'Reminder';
   RS_APPEARANCE_LAYOUT_ROWCOUNT              = 'Row Count';
   RS_APPEARANCE_CTRLJ_SHOWFREQUENCYINLOG     = 'Show Frequency In Log';
   RS_APPEARANCE_CTRLJ_SHOWTYPEDCALLSIGN      = 'Show Typed Callsign';
   RS_APPEARANCE_CTRLJ_USERINFOSHOWN          = 'User Info Shown';
   RS_APPEARANCE_LAYOUT_WINDOWSIZE            = 'Window Size';
   RS_HARDWARE_CTRLJ_LPT1BASEADDRESS          = 'LPT1 Base Address';
   RS_HARDWARE_CTRLJ_LPT2BASEADDRESS          = 'LPT2 Base Address';
   RS_HARDWARE_CTRLJ_LPT3BASEADDRESS          = 'LPT3 Base Address';
   RS_HARDWARE_CTRLJ_STEREOPINHIGH            = 'Stereo Pin High';
   RS_HARDWARE_CTRLJ_USECONTROLPORT           = 'Use Control Port';
   RS_FILES_CTRLJ_ALLOWAUTOUPDATE             = 'Allow Auto Update';
   RS_FILES_CTRLJ_CALLSIGNUPDATEENABLE        = 'Callsign Update Enable';
   RS_FILES_CTRLJ_COUNTRYINFORMATIONFILE      = 'Country Information File';
   RS_FILES_CTRLJ_CTYUPDATECHECKONSTARTUP     = 'Cty Update Check On Startup';
   RS_FILES_CTRLJ_DOMESTICFILENAME            = 'Domestic Filename';
   RS_FILES_CTRLJ_MISSINGCALLSIGNSFILEENABLE  = 'Missingcallsigns File Enable';
   RS_FILES_CTRLJ_UNKNOWNCOUNTRYFILENAME      = 'Unknown Country File Name';
   RS_BANDMAP_CTRLJ_BANDMAPCUTOFFFREQUENCY    = 'Band Map Cutoff Frequency';
   RS_BANDMAP_CTRLJ_BANDMAPITEMHEIGHT         = 'Band Map Item Height';
   RS_BANDMAP_CTRLJ_BANDMAPITEMWIDTH          = 'Band Map Item Width';
   RS_BANDMAP_CTRLJ_BANDMAPSIZE               = 'Band Map Size';
   RS_BANDMAP_CTRLJ_BANDMAPSPLITMODE          = 'Band Map Split Mode';
   RS_NETWORK_CTRLJ_COMPUTERNAME              = 'Computer Name';
   RS_NETWORK_CTRLJ_NETSTATUSUPDATEINTERVAL   = 'Net Status Update Interval';
   RS_VOICE_CTRLJ_MP3RECORDERBITRATE          = 'Mp3 Recorder Bitrate';
   RS_VOICE_CTRLJ_MP3RECORDERDURATION         = 'Mp3 Recorder Duration';
   RS_ADVANCED_HANDLOGMODE                    = 'Hand Log Mode';
   RS_ADVANCED_NOLOG                          = 'No Log';
   RS_CLUSTER_CTRLJ_BROADCASTALLPACKETDATA    = 'Broadcast All Packet Data';
   RS_HARDWARE_CTRLJ_STEREOCONTROLPIN         = 'Stereo Control Pin';
   RS_FILES_CTRLJ_INITIALEXCHANGEFILENAME     = 'Initial Exchange Filename';
implementation

end.

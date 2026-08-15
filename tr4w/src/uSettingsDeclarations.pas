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

   // --- Operating: bands ---------------------------------------------------
   RegisterLegacySetting('operating.bands.hf',   'HF BAND ENABLE',
                         'HF (160 - 10 m)');
   RegisterLegacySetting('operating.bands.warc', 'WARC BAND ENABLE',
                         'WARC (30, 17, 12 m)');
   RegisterLegacySetting('operating.bands.vhf',  'VHF BAND ENABLE',
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
end;

end.

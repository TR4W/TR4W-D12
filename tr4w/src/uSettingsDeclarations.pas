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
   RegisterLegacySetting('operating.cw.sayHi',            'SAY HI ENABLE',
                         'Send a greeting to stations worked before');
   RegisterLegacySetting('operating.cw.sayHiRateCutoff',  'SAY HI RATE CUTOFF',
                         'Stop above this rate');
   RegisterLegacySetting('operating.cw.keypadMemories',   'KEYPAD CW MEMORIES',
                         'Number keypad sends CW memories');
   RegisterLegacySetting('operating.cw.leadingZeros',     'LEADING ZEROS',
                         'Leading zeros');
   RegisterLegacySetting('operating.cw.leadingZeroChar',  'LEADING ZERO CHARACTER',
                         'Leading zero sent as');

   // Radio serial keying.  These shape only the CW TR4W generates itself by
   // toggling DTR/RTS -- a WinKeyer, a YCCC box or CW-by-CAT keep their own
   // timing -- which is why they sit in their own frame rather than beside the
   // settings that apply to every keyer.
   RegisterLegacySetting('operating.cw.serial.ditDahRatio',    'DIT DAH RATIO',
                         'Dit/dah ratio');
   RegisterLegacySetting('operating.cw.serial.weight',         'WEIGHT',
                         'Weight');
   RegisterLegacySetting('operating.cw.serial.farnsworth',     'FARNSWORTH ENABLE',
                         'Farnsworth spacing');
   RegisterLegacySetting('operating.cw.serial.farnsworthSpeed','FARNSWORTH SPEED',
                         'Character speed');

   // --- CW Settings (the keyer page) ---------------------------------------
   RegisterLegacySetting('cw.enable',            'CW ENABLE',
                         'Send CW');
   RegisterLegacySetting('cw.speedFromDatabase', 'CW SPEED FROM DATABASE',
                         'Match the speed a station was worked at before');
   // MIGRATED 2026-08-14 -- the first row to graduate.  Stored: writes go to
   // settings\tr4w.json, the CFGCA row is csJSON, and so it no longer appears
   // in Ctrl-J nor in tr4w.ini.  The two halves must stay in step; see
   // docs/CFG_MIGRATION_PLAN.md.
   RegisterStoredSetting('cw.speedIncrement',    'CW SPEED INCREMENT',
                         'Speed step');
   RegisterLegacySetting('cw.tone',              'CW TONE',
                         'Sidetone');

   // --- Operating: bands ---------------------------------------------------
   RegisterLegacySetting('operating.bands.hf',   'HF BAND ENABLE',
                         'HF (160 - 10 m)');
   RegisterLegacySetting('operating.bands.warc', 'WARC BAND ENABLE',
                         'WARC (30, 17, 12 m)');
   RegisterLegacySetting('operating.bands.vhf',  'VHF BAND ENABLE',
                         'VHF and up');

   // --- Operating: two radio -----------------------------------------------
   RegisterLegacySetting('operating.tworadio.enable',       'TWO RADIO MODE',
                         'Two radio mode');
   RegisterLegacySetting('operating.tworadio.altDBuffer',   'ALT-D BUFFER ENABLE',
                         'Alt-D remembers what you typed');
   RegisterLegacySetting('operating.tworadio.altDCQ',       'ALT-D CQ ENABLE',
                         'Alt-D can start a CQ on the second radio');
   RegisterLegacySetting('operating.tworadio.blindCQ',      'ALWAYS CALL BLIND CQ',
                         'Always call a blind CQ');
   RegisterLegacySetting('operating.tworadio.skipActiveBand','SKIP ACTIVE BAND',
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
   RegisterLegacySetting('scoring.board.postingUrl',     'SCORE POSTING URL',
                         'Posting URL');
   RegisterLegacySetting('scoring.board.readingUrl',     'SCORE READING URL',
                         'Reading URL');

   // --- DX cluster ---------------------------------------------------------
   RegisterLegacySetting('cluster.connectAtStartup', 'CONNECTION AT STARTUP',
                         'Connect at startup');
   RegisterLegacySetting('cluster.connectCommand',   'CONNECTION COMMAND',
                         'After connecting, send');
end;

end.

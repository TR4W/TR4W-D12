(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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
 *)

(* A SPOT AS TEXT: the band map's copied spot (issue 183) and its country panel
  with the beam heading (issue 186), and the Send Spot comment built from its
  two ticks (issue 175). All are pure functions of their forms, so they are
  pinned without creating a form. How the menu item, the panel and the dialog
  look on screen is a bench question. *)
unit uTestSpotText;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSpotTextTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ACopiedSpotIsCallEntityFrequencyComment;
      procedure Test_ACopiedSpotLeavesOutWhatItLacks;
      procedure Test_ACopiedMarkerRowHasNoEntity;
      procedure Test_TheCountryPanelCarriesTheHeading;
      procedure Test_NoHeadingShowsTheCountryAlone;
      procedure Test_TheSpotCommentFollowsBothTicks;
      procedure Test_ATypedSpotCommentIsNotOverwritten;
      procedure Test_EveryBandMapToggleIsAStationBoolean;
      procedure Test_ABandMapToggleIsSavedToTheSettingsFile;
   end;

implementation

uses
   SysUtils,
   Forms,             (* Application -- the Send Spot form is streamed *)
   LogGrid,
   uAppStrings,
   uBandMapForm,
   uSendSpotForm,
   VC,                (* TR4W_INI_FILENAME -- the settings file is redirected *)
   utils_text,        (* SetCharBuffer, CharBufferText *)
   uFileText,         (* TempDirectory, CombinePath *)
   uKeychain,         (* InstallTestKeychain -- a save stores the secrets *)
   uCTYDAT,           (* ctyLoadInCountryFile -- the entity of a copied spot *)
   uSettingsModel,
   uTR4WConfigFile,   (* TR4WConfigFileName, LoadSettingsSection *)
   uRadioConfigApply; (* ToggleAndStoreCommand *)

procedure TSpotTextTests.Test_ACopiedSpotIsCallEntityFrequencyComment;
begin
   BeginTest('Test_ACopiedSpotIsCallEntityFrequencyComment');
   CheckEquals('VP8LP [Falkland Islands] 14025.3 UP 2',
               string(SpotCopyText('VP8LP', 'Falkland Islands', '14025.3', 'UP 2')),
               'call, entity in brackets, frequency, comment, one space apart');
end;

procedure TSpotTextTests.Test_ACopiedSpotLeavesOutWhatItLacks;
begin
   BeginTest('Test_ACopiedSpotLeavesOutWhatItLacks');
   CheckEquals('CQ 7012.0 RUN',
               string(SpotCopyText('CQ', '', '7012.0', 'RUN')),
               'no entity: no brackets');
   CheckEquals('K1ABC [United States] 3525.1',
               string(SpotCopyText('K1ABC', 'United States', '3525.1', '')),
               'no comment: no trailing space');
end;

(* THE MENU'S OWN TEXT FOR A MARKER ROW (issue 183, review M9). The markers are
  stored as 'CQ/ <qso number>' and 'NEW <hhmm>'; the menu compared the call
  with the bare words 'CQ' and 'NEW', which never matched, so a marker was
  looked up in CTY.DAT as a callsign. This goes through SpotCopyTextFor -- what
  the menu item assigns to the clipboard -- with the country file loaded, so a
  marker the lookup resolves would show up as brackets. *)
procedure TSpotTextTests.Test_ACopiedMarkerRowHasNoEntity;

   function SpotWith(const aCall: string): TSpotRecord;
   begin
      Result := Default(TSpotRecord);
      Result.FCall := ShortString(aCall);
      Result.FFrequency := 7012000;
   end;

var
   ctyPath, text: string;
begin
   BeginTest('Test_ACopiedMarkerRowHasNoEntity');
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   (* The control case first: a real call does get its entity, so an empty
     bracket below means "a marker", not "no country file". *)
   text := SpotCopyTextFor(SpotWith('VP8LP'));
   CheckTrue(Pos(' [', text) > 0, 'a real call carries its entity: ' + text);

   (* WHY THIS CAN FAIL: CTY.DAT does name a country for the marker text, so
     the old code -- which looked the marker up -- printed it in brackets. *)
   CheckTrue(ctyGetCountryName(ctyGetCountry('CQ/ 17')) <> '',
             'the marker, looked up as a call, does resolve -- the defect was visible');

   text := SpotCopyTextFor(SpotWith('CQ/ 17'));
   CheckEquals(0, Pos('[', text), 'a CQ marker row has no entity: ' + text);
   CheckEquals(1, Pos('CQ/ 17 ', text), 'and starts with the marker as stored: ' + text);

   text := SpotCopyTextFor(SpotWith('NEW 0703'));
   CheckEquals(0, Pos('[', text), 'a NEW marker row has no entity: ' + text);
end;

procedure TSpotTextTests.Test_TheCountryPanelCarriesTheHeading;
var
   heading: integer;
begin
   BeginTest('Test_TheCountryPanelCarriesTheHeading');
   CheckEquals(Format(SBandMapCountryHeading, ['Germany', 45]),
               string(CountryWithHeading('Germany', 45)),
               'the country and the heading, through the translatable format');
   CheckEquals(Format(SBandMapCountryHeading, ['Japan', 0]),
               string(CountryWithHeading('Japan', 0)),
               'a heading of 0 is a heading (due north), not "none"');
   (* The heading the band map asks for, from two real grids. *)
   heading := GetBeamHeading('EM17', 'JN58');
   CheckTrue(heading >= 0, 'two real grids give a heading');
   CheckEquals(Format(SBandMapCountryHeading, ['Germany', heading]),
               string(CountryWithHeading('Germany', heading)),
               'and the panel shows it');
end;

procedure TSpotTextTests.Test_NoHeadingShowsTheCountryAlone;
begin
   BeginTest('Test_NoHeadingShowsTheCountryAlone');
   CheckEquals('Germany', string(CountryWithHeading('Germany', -1)),
               '-1 (no station grid, or none for the call) shows the country alone');
   CheckEquals('Germany',
               string(CountryWithHeading('Germany', GetBeamHeading('', 'JN58'))),
               'no station grid gives -1, so no heading');
end;

(* THE SEND SPOT COMMENT (issue 175): the contest's name, the station's
  section, state or county, both one space apart, or nothing; a location the
  program does not know adds nothing even when its tick is on. *)
procedure TSpotTextTests.Test_TheSpotCommentFollowsBothTicks;
begin
   BeginTest('Test_TheSpotCommentFollowsBothTicks');
   CheckEquals('', SpotCommentText('ARRL-SS-CW', 'NFL', False, False),
               'neither tick: no comment, as unticking the contest name always gave');
   CheckEquals('ARRL-SS-CW', SpotCommentText('ARRL-SS-CW', 'NFL', True, False),
               'the contest name alone, as before');
   CheckEquals('NFL', SpotCommentText('ARRL-SS-CW', 'NFL', False, True),
               'the section/state/county alone');
   CheckEquals('ARRL-SS-CW NFL', SpotCommentText('ARRL-SS-CW', 'NFL', True, True),
               'both, one space apart');
   CheckEquals('ARRL-SS-CW', SpotCommentText('ARRL-SS-CW', '', True, True),
               'no location known: no trailing space');
   CheckEquals('', SpotCommentText('ARRL-SS-CW', '', False, True),
               'no location known and no contest name: no comment');
end;

(* A COMMENT THE OPERATOR TYPED IS THEIRS (issue 175, review). Ticking either
  box, or editing the callsign, used to rebuild the comment and throw away
  what was typed. On the streamed form, never shown: the edits' and ticks'
  OnChange handlers come from the .lfm, so this also fails if those are lost. *)
procedure TSpotTextTests.Test_ATypedSpotCommentIsNotOverwritten;
var
   frm: TfrmSendSpot;
   savedContestTick: boolean;
begin
   BeginTest('Test_ATypedSpotCommentIsNotOverwritten');
   Application.Initialize;
   savedContestTick := tContestNameInComment;
   frm := TfrmSendSpot.Create(nil);
   try
      frm.edtComment.Text := 'UP 2 LOUD';
      frm.chkContestName.Checked := not frm.chkContestName.Checked;
      CheckEquals('UP 2 LOUD', string(frm.edtComment.Text),
                  'a tick leaves a typed comment alone');
      (* Toggled twice, so the session's remembered tick is as it was. *)
      frm.chkLocation.Checked := not frm.chkLocation.Checked;
      CheckEquals('UP 2 LOUD', string(frm.edtComment.Text),
                  'so does the section/state/county tick');
      frm.chkLocation.Checked := not frm.chkLocation.Checked;
      frm.edtCallsign.Text := 'K1ABC';
      CheckEquals('UP 2 LOUD', string(frm.edtComment.Text),
                  'so does a new callsign');
   finally
      frm.Free;
      tContestNameInComment := savedContestTick;
   end;
end;

(* THE BAND MAP'S TOGGLES ARE SAVED (2026-11-15). Its menu and hotkeys assigned
  the property and nothing wrote settings\tr4w.json, so ALL BANDS, ALL MODES
  and MULTS ONLY came back at the next start as they were before the session.
  They now go through ToggleAndStoreCommand, by NAME -- so every name must be
  one the settings object owns as a boolean, and not contest-scoped, or
  ApplyAndStoreCommand would apply it and save it nowhere. *)
procedure TSpotTextTests.Test_EveryBandMapToggleIsAStationBoolean;
var
   i: integer;
   value: string;
begin
   BeginTest('Test_EveryBandMapToggleIsAStationBoolean');
   for i := Low(BANDMAP_TOGGLED_SETTINGS) to High(BANDMAP_TOGGLED_SETTINGS) do
      begin
      CheckTrue(Settings.OwnsCommand(BANDMAP_TOGGLED_SETTINGS[i]),
                BANDMAP_TOGGLED_SETTINGS[i] + ' is owned by the settings object');
      CheckFalse(Settings.CommandIsContestScoped(BANDMAP_TOGGLED_SETTINGS[i]),
                 BANDMAP_TOGGLED_SETTINGS[i] + ' is a station setting, saved to the file');
      CheckTrue(Settings.TryGetByCommand(BANDMAP_TOGGLED_SETTINGS[i], value),
                BANDMAP_TOGGLED_SETTINGS[i] + ' reads back');
      CheckTrue((value = 'TRUE') or (value = 'FALSE'),
                BANDMAP_TOGGLED_SETTINGS[i] + ' is a boolean (read "' + value + '")');
      end;

   CheckFalse(ToggleAndStoreCommand('BAND MAP DECAY TIME'),
              'a number is not toggled');
   CheckFalse(ToggleAndStoreCommand('NO SUCH COMMAND'),
              'nor is a name nothing owns');
end;

(* THE SETTINGS FILE IS REDIRECTED FIRST, and the test refuses to toggle unless
  TR4WConfigFileName really landed in its own temp folder -- the same guard as
  uTestColumnWidthStore's flush: a --settings switch would win over the
  redirect, and a save there would write a real file. *)
procedure TSpotTextTests.Test_ABandMapToggleIsSavedToTheSettingsFile;
var
   oldIni, dir, fn: string;
   savedAllBands, savedMultsOnly: boolean;
   fresh: TR4WSettings;
begin
   BeginTest('Test_ABandMapToggleIsSavedToTheSettingsFile');
   InstallTestKeychain;
   fn             := '';
   oldIni         := CharBufferText(TR4W_INI_FILENAME);
   savedAllBands  := Settings.BandMap.AllBands;
   savedMultsOnly := Settings.BandMap.MultsOnly;
   dir := CombinePath(TempDirectory, 'tr4wbandmap_' + TGUID.NewGuid.ToString);
   fresh := TR4WSettings.Create;
   try
      SetCharBuffer(TR4W_INI_FILENAME, CombinePath(dir, 'tr4w.ini'));
      fn := TR4WConfigFileName;
      if Pos(dir, fn) <> 1 then
         begin
         CheckTrue(False, 'the settings file was not redirected (' + fn +
                          ') -- a --settings switch? The toggle is skipped');
         Exit;
         end;

      Settings.BandMap.AllBands  := False;
      Settings.BandMap.MultsOnly := True;

      CheckTrue(ToggleAndStoreCommand(BANDMAP_ALL_BANDS), 'ALL BANDS toggles');
      CheckTrue(ToggleAndStoreCommand(BANDMAP_MULTS_ONLY), 'MULTS ONLY toggles');
      CheckTrue(Settings.BandMap.AllBands, 'ALL BANDS is on for the session');
      CheckFalse(Settings.BandMap.MultsOnly, 'MULTS ONLY is off for the session');

      (* What the next start reads: the file's settings section, into an
        object that has never seen the toggle. *)
      fresh.BandMap.AllBands  := False;
      fresh.BandMap.MultsOnly := True;
      CheckTrue(LoadSettingsSection(fn, fresh), 'the file holds a settings section');
      CheckTrue(fresh.BandMap.AllBands, 'ALL BANDS on reaches the file');
      CheckFalse(fresh.BandMap.MultsOnly, 'MULTS ONLY off reaches the file');
   finally
      fresh.Free;
      (* Put back by property, never by a save: nothing here may write a file
        but the temp one. *)
      Settings.BandMap.AllBands  := savedAllBands;
      Settings.BandMap.MultsOnly := savedMultsOnly;
      SetCharBuffer(TR4W_INI_FILENAME, oldIni);
      if (fn <> '') and (Pos(dir, fn) = 1) then
         begin
         DeleteFile(fn);
         RemoveDir(dir);
         end;
   end;
end;

procedure TSpotTextTests.RunAllTests;
begin
   Test_ACopiedSpotIsCallEntityFrequencyComment;
   Test_ACopiedSpotLeavesOutWhatItLacks;
   Test_ACopiedMarkerRowHasNoEntity;
   Test_TheCountryPanelCarriesTheHeading;
   Test_NoHeadingShowsTheCountryAlone;
   Test_TheSpotCommentFollowsBothTicks;
   Test_ATypedSpotCommentIsNotOverwritten;
   Test_EveryBandMapToggleIsAStationBoolean;
   Test_ABandMapToggleIsSavedToTheSettingsFile;
end;

end.

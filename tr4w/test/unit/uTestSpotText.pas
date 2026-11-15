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
      procedure Test_TheCountryPanelCarriesTheHeading;
      procedure Test_NoHeadingShowsTheCountryAlone;
      procedure Test_TheSpotCommentFollowsBothTicks;
   end;

implementation

uses
   SysUtils,
   LogGrid,
   uAppStrings,
   uBandMapForm,
   uSendSpotForm;

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
  section, both one space apart, or nothing; a section the program does not
  know adds nothing even when its tick is on. *)
procedure TSpotTextTests.Test_TheSpotCommentFollowsBothTicks;
begin
   BeginTest('Test_TheSpotCommentFollowsBothTicks');
   CheckEquals('', SpotCommentText('ARRL-SS-CW', 'NFL', False, False),
               'neither tick: no comment, as unticking the contest name always gave');
   CheckEquals('ARRL-SS-CW', SpotCommentText('ARRL-SS-CW', 'NFL', True, False),
               'the contest name alone, as before');
   CheckEquals('NFL', SpotCommentText('ARRL-SS-CW', 'NFL', False, True),
               'the section alone');
   CheckEquals('ARRL-SS-CW NFL', SpotCommentText('ARRL-SS-CW', 'NFL', True, True),
               'both, one space apart');
   CheckEquals('ARRL-SS-CW', SpotCommentText('ARRL-SS-CW', '', True, True),
               'no section known: no trailing space');
   CheckEquals('', SpotCommentText('ARRL-SS-CW', '', False, True),
               'no section known and no contest name: no comment');
end;

procedure TSpotTextTests.RunAllTests;
begin
   Test_ACopiedSpotIsCallEntityFrequencyComment;
   Test_ACopiedSpotLeavesOutWhatItLacks;
   Test_TheCountryPanelCarriesTheHeading;
   Test_NoHeadingShowsTheCountryAlone;
   Test_TheSpotCommentFollowsBothTicks;
end;

end.

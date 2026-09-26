unit uTestLegacyConversionCheck;

(* THE FIRST-RUN CONVERSION CONDITION, PINNED IN ALL FOUR DIRECTIONS.

  NY4I approved a single offer at first start (2026-09-20): if there is a 4.x
  tr4w.ini and TR4W has never written its own settings file, offer to run
  tr4wconvert.  What makes that safe -- and what stops it becoming the
  always-in-the-way ini detector that was removed the day before -- is that
  the condition is EXACTLY two file tests and that TR4W writes the settings
  file within seconds of asking.  From then on the right-hand test is False
  forever and the offer cannot be made again.

  So the thing worth pinning is not "does it fire" but the three cases where
  it must NOT, and each of those is a real station:

      ini, no json     an operator upgrading from 4.x           -> offer
      ini and json     every start after the first              -> silent
      no ini, json     a station that never had 4.x             -> silent
      neither          a brand new install, first ever start    -> silent

  AND THE COMMAND LINE, WHICH IS WHERE THIS WENT WRONG.  The offer detected an
  ini and then launched tr4wconvert naming only the DESTINATION, leaving the
  converter to look for an ini beside it -- so when the destination was
  somewhere else, the ini that triggered the offer was not the ini that was
  read, and the converter reported "there is no old configuration to convert"
  about a station that had one.  Nothing failed: exit 0, and a first run that
  converted nothing looks exactly like a first run with nothing to convert.
  The arguments are a pure function of the two paths, so they are pinned here.

  WHAT THIS CANNOT TEST, said plainly rather than implied by omission: the
  DIALOG.  uFirstRunConvert pulls in the LCL and the unit-test binary
  deliberately links no widget set, so nothing here exercises the QuestionDlg,
  the launch of tr4wconvert or the message shown when nothing was converted.
  That is why the condition lives in a leaf of its own -- the half that can be
  asserted is separated from the half that can only be operated. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TLegacyConversionCheckTests = class(TTestCase)
   protected
      procedure Test_AnIniWithNoSettingsFileOffersTheConversion;
      procedure Test_AnIniBesideASettingsFileIsSilent;
      procedure Test_ASettingsFileWithNoIniIsSilent;
      procedure Test_NeitherFileIsSilent;
      procedure Test_AnEmptyPathIsNotAFile;
      procedure Test_TheArgumentsNameBothFiles;
      procedure Test_ADestinationElsewhereStillNamesTheDetectedIni;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uLegacyConversionCheck;

(* A directory of this test's own, so nothing here can see -- or disturb --
  the settings of the machine running the suite. *)
function ScratchDir: string;
var
   dir: string;
begin
   dir := IncludeTrailingPathDelimiter(GetTempDir) +
          Format('tr4w-firstrun-%d', [Random(1000000000)]);
   ForceDirectories(dir);
   Result := IncludeTrailingPathDelimiter(dir);
end;

procedure TouchFile(const aFileName: string);
var
   f: TextFile;
begin
   AssignFile(f, aFileName);
   Rewrite(f);
   try
      WriteLn(f, 'x');
   finally
      CloseFile(f);
   end;
end;

procedure TLegacyConversionCheckTests.Test_AnIniWithNoSettingsFileOffersTheConversion;
var
   dir: string;
begin
   BeginTest('an old ini and no settings file offers the conversion');
   dir := ScratchDir;
   TouchFile(dir + 'tr4w.ini');
   CheckTrue(LegacyConversionOffered(dir + 'tr4w.ini', dir + 'tr4w.json'),
             'this is the upgrading operator -- the one case that asks');
end;

procedure TLegacyConversionCheckTests.Test_AnIniBesideASettingsFileIsSilent;
var
   dir: string;
begin
   BeginTest('an old ini beside a settings file asks nothing');
   dir := ScratchDir;
   TouchFile(dir + 'tr4w.ini');
   TouchFile(dir + 'tr4w.json');
   (* THIS IS WHAT MAKES THE OFFER ONE-SHOT. TR4W writes the settings file on
     the very first load, so every start after the first lands here. Nothing
     is remembered and nothing has to be. *)
   CheckFalse(LegacyConversionOffered(dir + 'tr4w.ini', dir + 'tr4w.json'),
              'TR4W has its own settings now -- never ask again');
end;

procedure TLegacyConversionCheckTests.Test_ASettingsFileWithNoIniIsSilent;
var
   dir: string;
begin
   BeginTest('a settings file with no old ini asks nothing');
   dir := ScratchDir;
   TouchFile(dir + 'tr4w.json');
   CheckFalse(LegacyConversionOffered(dir + 'tr4w.ini', dir + 'tr4w.json'),
              'there is nothing to convert');
end;

procedure TLegacyConversionCheckTests.Test_NeitherFileIsSilent;
var
   dir: string;
begin
   BeginTest('a station with neither file asks nothing');
   dir := ScratchDir;
   CheckFalse(LegacyConversionOffered(dir + 'tr4w.ini', dir + 'tr4w.json'),
              'a brand new install has nothing to say about 4.x');
end;

procedure TLegacyConversionCheckTests.Test_AnEmptyPathIsNotAFile;
begin
   BeginTest('an unnamed file is not a present one');
   (* FileExists('') is False on every platform this builds for, so this
     mostly pins the INTENT: "no path was resolved" must never be allowed to
     read as "the file is there", because one of the two tests is a negative
     and a bad path would make it true. *)
   CheckFalse(LegacyConversionOffered('', 'x.json'), 'no ini named');
   CheckFalse(LegacyConversionOffered('x.ini', ''), 'no settings file named');
end;

(* The command line as one readable string, which is what an assertion about
  arguments is actually about.  The join is this test's own and says nothing
  about quoting: RunConsoleProgramAndWait is handed the ARRAY, so a path with a
  space in it is still one argument.  The fixtures below have none, so reading
  the joined form back is unambiguous. *)
function ArgLine(const aArgs: TLegacyConversionArgs): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to High(aArgs) do
      begin
      if i > 0 then
         begin
         Result := Result + ' ';
         end;
      Result := Result + aArgs[i];
      end;
end;

procedure TLegacyConversionCheckTests.Test_TheArgumentsNameBothFiles;
begin
   BeginTest('the command line names the detected ini and the destination');
   (* THE INI IS NAMED EVEN WHERE THE CONVERTER WOULD HAVE LOOKED ANYWAY.  Not
     because it is needed there, but because the alternative is a rule that
     decides when to name it -- and a second copy of "where does the ini live"
     is precisely what this defect was. *)
   CheckEquals('--settings C:\tr4w\settings\tr4w.json '
               + '--ini C:\tr4w\settings\tr4w.ini',
               ArgLine(LegacyConversionArguments('C:\tr4w\settings\tr4w.ini',
                                                 'C:\tr4w\settings\tr4w.json')),
               'both paths, passed through unchanged');
end;

procedure TLegacyConversionCheckTests.Test_ADestinationElsewhereStillNamesTheDetectedIni;
var
   args: TLegacyConversionArgs;
begin
   BeginTest('a destination in another directory still converts the detected ini');
   (* THE CASE THAT WAS BROKEN.  --settings moves the destination; TR4W resolves
     its legacy ini from its own settings directory and does not follow.  Before
     this, these arguments held the destination alone and tr4wconvert looked for
     D:\elsewhere\tr4w.ini -- a file that is not there, on a station whose
     entire 4.x configuration was sitting in the ini it had just been told
     about. *)
   args := LegacyConversionArguments('C:\tr4w\settings\tr4w.ini',
                                     'D:\elsewhere\my.json');
   CheckEquals(4, Length(args), 'four arguments: two switches and two paths');
   CheckEquals('C:\tr4w\settings\tr4w.ini', args[3],
               'the ini that was DETECTED is the ini that is converted');
   CheckEquals('D:\elsewhere\my.json', args[1],
               'and the destination is still the one the program will read');
end;

procedure TLegacyConversionCheckTests.RunAllTests;
begin
   Randomize;
   Test_AnIniWithNoSettingsFileOffersTheConversion;
   Test_AnIniBesideASettingsFileIsSilent;
   Test_ASettingsFileWithNoIniIsSilent;
   Test_NeitherFileIsSilent;
   Test_AnEmptyPathIsNotAFile;
   Test_TheArgumentsNameBothFiles;
   Test_ADestinationElsewhereStillNamesTheDetectedIni;
end;

end.

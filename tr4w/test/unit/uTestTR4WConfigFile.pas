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
unit uTestTR4WConfigFile;
{$I ..\..\src\tr4w.inc}

{
  Tests for the settings\tr4w.json composer.

  WHAT MATTERS HERE IS COEXISTENCE, not either store's own round trip -- those
  are covered by uTestRadioConfigStore and uTestKeyerConfigStore.  These tests
  pin the things that only break when two tenants share one file:

    * both sections survive one save/load;
    * a file written BEFORE the keyer library existed still loads, with the
      keyer store simply empty rather than the load failing;
    * no BOM, because Python and jq reject one and our own reader would not;
    * an unreadable file is REPORTED rather than silently read as "no config",
      which would present as a lost configuration.
}

interface

uses
   SysUtils, Classes, uJSON, uFileText,
   uTR4WTestFramework, uRadioConfigStore, uKeyerConfigStore, uTR4WConfigFile;

type
   TTR4WConfigFileTests = class(TTestCase)
   private
      FTempFiles: TStringList;
      function TempFileName: string;
      // AddRadio takes a definition and OWNS it on success, so this makes one.
      procedure AddNamedRadio(const aStore: TRadioConfigStore; const aName: string);
   protected
      procedure Test_BothSectionsSurviveARoundTrip;
      procedure Test_FileWithoutKeyersStillLoads;
      procedure Test_WrittenWithoutABOM;
      procedure Test_MissingFileIsReported;
      procedure Test_MalformedFileIsReportedNotSilentlyEmpty;
      procedure Test_SaveCreatesTheDirectory;
      procedure Test_EveryHeaderSectionSurvivesARoundTrip;
      procedure Test_HeaderSectionsAreIndependent;
      procedure Test_ClearEmptiesTheHeaders;
   public
      constructor Create(const AName: string);
      destructor Destroy; override;
      procedure RunAllTests; override;
   end;

implementation

constructor TTR4WConfigFileTests.Create(const AName: string);
begin
   inherited Create(AName);
   FTempFiles := TStringList.Create;
end;

destructor TTR4WConfigFileTests.Destroy;
var
   i: integer;
begin
   for i := 0 to FTempFiles.Count - 1 do
      begin
      if FileTextExists(FTempFiles[i]) then
         begin
         DeleteFileIfExists(FTempFiles[i]);
         end;
      end;
   FTempFiles.Free;
   inherited Destroy;
end;

procedure TTR4WConfigFileTests.AddNamedRadio(const aStore: TRadioConfigStore;
                                             const aName: string);
var
   r: TRadioDefinition;
   err: string;
begin
   r := TRadioDefinition.Create;
   r.Name := aName;
   if not aStore.AddRadio(r, err) then
      begin
      // Only free on failure: on success the store owns it.
      r.Free;
      CheckTrue(False, 'AddRadio failed: ' + err);
      end;
end;

function TTR4WConfigFileTests.TempFileName: string;
begin
   Result := CombinePath(TempDirectory,
                           'tr4wcfg_' + TGUID.NewGuid.ToString + '.json');
   FTempFiles.Add(Result);
end;

procedure TTR4WConfigFileTests.Test_BothSectionsSurviveARoundTrip;
var
   radios, radios2: TRadioConfigStore;
   keyers, keyers2: TKeyerConfigStore;
   fn, err: string;
begin
   BeginTest('Test_BothSectionsSurviveARoundTrip');
   radios := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   radios2 := TRadioConfigStore.Create;
   keyers2 := TKeyerConfigStore.Create;
   try
      fn := TempFileName;
      AddNamedRadio(radios, 'K4');
      keyers.AddKeyer('Desk WinKey', kkWinKeyer).Port := 'SERIAL 7';
      keyers.AddKeyer('YCCC box', kkYCCC).Port := 'SERIAL 9';

      SaveConfig(fn, radios, keyers);
      CheckTrue(LoadConfig(fn, radios2, keyers2, err), 'load succeeded: ' + err);

      CheckEquals(1, radios2.RadioCount, 'the radio section survived');
      CheckEquals(2, keyers2.KeyerCount, 'the keyer section survived');
      CheckEquals('Desk WinKey', keyers2.Keyer(0).Name, 'and in order');
      CheckEquals('SERIAL 7', keyers2.Keyer(0).Port, 'with its fields');
   finally
      keyers2.Free;
      radios2.Free;
      keyers.Free;
      radios.Free;
   end;
end;

procedure TTR4WConfigFileTests.Test_FileWithoutKeyersStillLoads;
var
   radios, radios2: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   fn, err: string;
begin
   BeginTest('Test_FileWithoutKeyersStillLoads');
   // A file written before the keyer library existed. An absent section is a
   // new tenant, not a corrupt file.
   radios := TRadioConfigStore.Create;
   radios2 := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      fn := TempFileName;
      AddNamedRadio(radios, 'K4');
      radios.SaveToFile(fn);          // the OLD writer -- no 'keyers' key

      CheckTrue(LoadConfig(fn, radios2, keyers, err), 'old file still loads: ' + err);
      CheckEquals(1, radios2.RadioCount, 'radios came back');
      CheckEquals(0, keyers.KeyerCount, 'and the keyer store is simply empty');
   finally
      keyers.Free;
      radios2.Free;
      radios.Free;
   end;
end;

procedure TTR4WConfigFileTests.Test_WrittenWithoutABOM;
var
   radios: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   fn: string;
   bytes: TBytes;
begin
   BeginTest('Test_WrittenWithoutABOM');
   // RFC 8259 forbids a BOM at the start of JSON, and Python's json.load and jq
   // both reject one. Our own reader tolerates it, which is exactly why this
   // needs a test rather than trust.
   radios := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      fn := TempFileName;
      SaveConfig(fn, radios, keyers);
      bytes := ReadAllBytesFile(fn);
      CheckTrue(Length(bytes) >= 1, 'something was written');
      CheckFalse((Length(bytes) >= 3) and (bytes[0] = $EF) and
                 (bytes[1] = $BB) and (bytes[2] = $BF),
                 'no UTF-8 BOM at the start');
   finally
      keyers.Free;
      radios.Free;
   end;
end;

procedure TTR4WConfigFileTests.Test_MissingFileIsReported;
var
   radios: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   err: string;
begin
   BeginTest('Test_MissingFileIsReported');
   radios := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      CheckFalse(LoadConfig(CombinePath(TempDirectory, 'no_such_tr4w.json'),
                            radios, keyers, err), 'a missing file reports False');
      CheckTrue(err <> '', 'and says why');
   finally
      keyers.Free;
      radios.Free;
   end;
end;

procedure TTR4WConfigFileTests.Test_MalformedFileIsReportedNotSilentlyEmpty;
var
   radios: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   fn, err: string;
begin
   BeginTest('Test_MalformedFileIsReportedNotSilentlyEmpty');
   // Reading rubbish as "no configuration" would look exactly like a first run,
   // and the operator would have no way to tell that from a lost library.
   radios := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      fn := TempFileName;
      WriteAllTextUTF8(fn, 'this is not json');
      CheckFalse(LoadConfig(fn, radios, keyers, err), 'malformed reports False');
      CheckTrue(err <> '', 'and says why: ' + err);
   finally
      keyers.Free;
      radios.Free;
   end;
end;

procedure TTR4WConfigFileTests.Test_SaveCreatesTheDirectory;
var
   radios: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   dir, fn: string;
begin
   BeginTest('Test_SaveCreatesTheDirectory');
   radios := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      dir := CombinePath(TempDirectory, 'tr4wcfg_' + TGUID.NewGuid.ToString);
      fn := CombinePath(dir, 'tr4w.json');
      FTempFiles.Add(fn);
      SaveConfig(fn, radios, keyers);
      CheckTrue(FileTextExists(fn), 'the settings directory was created');
      // Remove the directory too, so the temp area does not accumulate.
      DeleteFileIfExists(fn);
      RemoveDir(dir);
   finally
      keyers.Free;
      radios.Free;
   end;
end;

// EXHAUSTIVE over HEADER_SECTIONS, not over the two names known today.  A new
// header section added to that table without a save/load path would otherwise
// read back empty -- and an empty header is a LEGAL value, so the export would
// simply omit the tags rather than fail. That is the same silent-zero shape
// that hid the missing frame rules in the CW work.
procedure TTR4WConfigFileTests.Test_EveryHeaderSectionSurvivesARoundTrip;
var
   radios: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   fn, err: string;
   s: integer;
begin
   BeginTest('Test_EveryHeaderSectionSurvivesARoundTrip');
   fn := TempFileName;
   radios := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      for s := Low(HEADER_SECTIONS) to High(HEADER_SECTIONS) do
         begin
         radios.Header(HEADER_SECTIONS[s].Section).Values['_TAG'] :=
            'value for ' + HEADER_SECTIONS[s].Section;
         end;
      SaveConfig(fn, radios, keyers);
   finally
      keyers.Free;
      radios.Free;
   end;

   radios := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      CheckTrue(LoadConfig(fn, radios, keyers, err), 'loaded: ' + err);
      for s := Low(HEADER_SECTIONS) to High(HEADER_SECTIONS) do
         begin
         CheckEquals('value for ' + HEADER_SECTIONS[s].Section,
                     radios.Header(HEADER_SECTIONS[s].Section).Values['_TAG'],
                     HEADER_SECTIONS[s].Section + ' survived the round trip');
         end;
   finally
      keyers.Free;
      radios.Free;
   end;
end;

// The sections must not share storage.  They hold the SAME tag spellings --
// uCbrSum writes _LOCATION into whichever section the contest selects -- so a
// map that collapsed them would silently show a Cabrillo station its ERMAK
// answers.
procedure TTR4WConfigFileTests.Test_HeaderSectionsAreIndependent;
var
   radios: TRadioConfigStore;
begin
   BeginTest('Test_HeaderSectionsAreIndependent');
   radios := TRadioConfigStore.Create;
   try
      radios.Header('REPORT').Values['_LOCATION']      := 'WCF';
      radios.Header('ERMAKREPORT').Values['_LOCATION'] := 'UA4';
      CheckEquals('WCF', radios.Header('REPORT').Values['_LOCATION'],
                  'REPORT keeps its own value');
      CheckEquals('UA4', radios.Header('ERMAKREPORT').Values['_LOCATION'],
                  'ERMAKREPORT keeps its own value');
      // Case-insensitive, as ini section lookup was: a caller passing the VC
      // spelling and one passing lower case must reach the same list.
      CheckEquals('WCF', radios.Header('report').Values['_LOCATION'],
                  'section lookup is case-insensitive');
      // An unknown section reads empty rather than raising.
      CheckEquals('', radios.Header('NOSUCHSECTION').Values['_LOCATION'],
                  'an unknown section is an empty header');
   finally
      radios.Free;
   end;
end;

// Clear is what LoadFromJSON calls first.  A Clear that left headers behind
// would carry one station's name and address into the next file loaded.
procedure TTR4WConfigFileTests.Test_ClearEmptiesTheHeaders;
var
   radios: TRadioConfigStore;
begin
   BeginTest('Test_ClearEmptiesTheHeaders');
   radios := TRadioConfigStore.Create;
   try
      radios.Header('REPORT').Values['_NAME'] := 'Tom';
      radios.Clear;
      CheckEquals('', radios.Header('REPORT').Values['_NAME'],
                  'Clear emptied the header');
   finally
      radios.Free;
   end;
end;

procedure TTR4WConfigFileTests.RunAllTests;
begin
   Test_BothSectionsSurviveARoundTrip;
   Test_FileWithoutKeyersStillLoads;
   Test_WrittenWithoutABOM;
   Test_MissingFileIsReported;
   Test_MalformedFileIsReportedNotSilentlyEmpty;
   Test_SaveCreatesTheDirectory;
   Test_EveryHeaderSectionSurvivesARoundTrip;
   Test_HeaderSectionsAreIndependent;
   Test_ClearEmptiesTheHeaders;
end;

end.

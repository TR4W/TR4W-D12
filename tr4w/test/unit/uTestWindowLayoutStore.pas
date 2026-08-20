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
unit uTestWindowLayoutStore;
{$I ..\..\src\tr4w.inc}

{
  Tests for the 'windows' section of settings\tr4w.json.

  THE POINT OF THE FORMAT IS THAT IT IS KEYED BY NAME, so most of what is
  pinned here is about the failure modes of the format it REPLACED, which
  addressed windows by array index and could not say so:

    * a rect survives a round trip with its VISIBILITY, and (0,0,0,0) is a
      legal rect rather than a sentinel for absent -- the old format stored
      zero rects routinely;
    * the ORDER entries appear in the file does not matter;
    * a name this build does not know is KEPT, because that is what a newer
      TR4W's window looks like to an older one;
    * and WindowNames covers WindowsType exactly once, with no duplicates,
      because those names are now the on-disk key.

  That last one is the reason this suite links VC.pas.  Adding a member to
  WindowsType without adding a name is a compile error -- FPC checks the array
  length -- but a DUPLICATE name compiles perfectly and silently makes two
  windows share one saved rectangle.
}

interface

uses
   SysUtils, Classes, Types,
   uTR4WTestFramework, uJSON, uFileText, uWindowLayoutStore, uTR4WConfigFile,
   VC;

type
   TWindowLayoutStoreTests = class(TTestCase)
   private
      FTempFiles: TStringList;
      function TempFileName: string;
   protected
      procedure Test_LayoutSurvivesARoundTrip;
      procedure Test_AZeroRectIsAValueNotAnAbsence;
      procedure Test_LookupIsByNameNotByOrder;
      procedure Test_LookupIsCaseInsensitive;
      procedure Test_SettingTheSameWindowTwiceReplacesIt;
      procedure Test_AnAbsentWindowLeavesTheCallersValuesAlone;
      procedure Test_ANonObjectEntryIsSkippedNotReadAsZero;
      procedure Test_AnUnknownWindowNameSurvivesASave;
      procedure Test_SaveAndLoadThroughTheSharedFile;
      procedure Test_WindowNamesAreUniqueAndPresent;
   public
      constructor Create(const AName: string);
      destructor Destroy; override;
      procedure RunAllTests; override;
   end;

implementation

constructor TWindowLayoutStoreTests.Create(const AName: string);
begin
   inherited Create(AName);
   FTempFiles := TStringList.Create;
end;

destructor TWindowLayoutStoreTests.Destroy;
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

function TWindowLayoutStoreTests.TempFileName: string;
begin
   Result := CombinePath(TempDirectory,
                         'tr4wwin_' + TGUID.NewGuid.ToString + '.json');
   FTempFiles.Add(Result);
end;

procedure TWindowLayoutStoreTests.Test_LayoutSurvivesARoundTrip;
var
   a, b: TWindowLayoutStore;
   obj: TJSONObject;
   quoted: TJSONValue;
   r: TRect;
   visible: boolean;
begin
   BeginTest('Test_LayoutSurvivesARoundTrip');
   a := TWindowLayoutStore.Create;
   b := TWindowLayoutStore.Create;
   try
      a.SetLayout('BandMap', Rect(10, 20, 230, 400), True);
      a.SetLayout('Telnet',  Rect(-5, 60, 645, 300), False);

      obj := a.ToJSON;
      try
         b.FromJSON(obj);
      finally
         obj.Free;
      end;

      CheckEquals(2, b.EntryCount, 'both windows came back');

      CheckTrue(b.TryGetLayout('BandMap', r, visible), 'BandMap is there');
      CheckEquals(10,  r.Left,   'left');
      CheckEquals(20,  r.Top,    'top');
      CheckEquals(230, r.Right,  'right');
      CheckEquals(400, r.Bottom, 'bottom');
      CheckTrue(visible, 'and visible');

      // A NEGATIVE left, because a window on a second monitor to the left of
      // the primary has one, and the old format stored it as a signed integer.
      CheckTrue(b.TryGetLayout('Telnet', r, visible), 'Telnet is there');
      CheckEquals(-5, r.Left, 'a negative left survives');
      CheckFalse(visible, 'and not visible');

      // The visibility flag is read through the value's TEXT form so a
      // hand-edited "true" reads like a bare true. Pin both spellings, since
      // the file is advertised as editable.
      b.Clear;
      quoted := TJSONObject.ParseJSONValue(
         '{"A":{"left":0,"top":0,"right":0,"bottom":0,"visible":"true"}}');
      try
         CheckTrue(quoted is TJSONObject, 'the quoted-bool fixture parses');
         b.FromJSON(TJSONObject(quoted));
      finally
         quoted.Free;
      end;
      CheckTrue(b.TryGetLayout('A', r, visible), 'the quoted form is read');
      CheckTrue(visible, 'and reads as visible');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TWindowLayoutStoreTests.Test_AZeroRectIsAValueNotAnAbsence;
var
   a, b: TWindowLayoutStore;
   obj: TJSONObject;
   r: TRect;
   visible: boolean;
begin
   BeginTest('Test_AZeroRectIsAValueNotAnAbsence');
   // LoadTR4WPOSFILE tests `WndRect.Right = 0` to decide a window has never
   // been placed, so zero rects are ordinary content in a saved layout. A
   // store that treated an all-zero rect as "no entry" would drop them.
   a := TWindowLayoutStore.Create;
   b := TWindowLayoutStore.Create;
   try
      a.SetLayout('Master', Rect(0, 0, 0, 0), False);
      obj := a.ToJSON;
      try
         b.FromJSON(obj);
      finally
         obj.Free;
      end;

      CheckEquals(1, b.EntryCount, 'the zero rect was stored');
      CheckTrue(b.TryGetLayout('Master', r, visible), 'and can be read back');
      CheckEquals(0, r.Right, 'as zero');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TWindowLayoutStoreTests.Test_LookupIsByNameNotByOrder;
var
   store: TWindowLayoutStore;
   value: TJSONValue;
   r: TRect;
   visible: boolean;
begin
   BeginTest('Test_LookupIsByNameNotByOrder');
   // The failure this format exists to prevent: the old file addressed windows
   // by their position in WindowsType, so reordering the enum moved every
   // saved rectangle onto a different window. Here the order in the document
   // is not information at all.
   store := TWindowLayoutStore.Create;
   try
      value := TJSONObject.ParseJSONValue(
         '{"Telnet":{"left":7,"top":0,"right":0,"bottom":0,"visible":false},' +
         ' "Main":{"left":3,"top":0,"right":0,"bottom":0,"visible":true}}');
      try
         CheckTrue(value is TJSONObject, 'the fixture parses');
         store.FromJSON(TJSONObject(value));
      finally
         value.Free;
      end;

      CheckTrue(store.TryGetLayout('Main', r, visible), 'Main resolved');
      CheckEquals(3, r.Left, 'to ITS rect, though it is written second');
      CheckTrue(store.TryGetLayout('Telnet', r, visible), 'Telnet resolved');
      CheckEquals(7, r.Left, 'to its own');
   finally
      store.Free;
   end;
end;

procedure TWindowLayoutStoreTests.Test_LookupIsCaseInsensitive;
var
   store: TWindowLayoutStore;
   r: TRect;
   visible: boolean;
begin
   BeginTest('Test_LookupIsCaseInsensitive');
   // The file is meant to be hand-editable, so 'bandmap' must find 'BandMap'
   // rather than silently creating a second window nothing reads.
   store := TWindowLayoutStore.Create;
   try
      store.SetLayout('BandMap', Rect(1, 2, 3, 4), True);
      CheckTrue(store.TryGetLayout('bandmap', r, visible), 'found lowercase');
      CheckEquals(1, r.Left, 'the same entry');
      CheckEquals(1, store.EntryCount, 'and only one entry exists');
   finally
      store.Free;
   end;
end;

procedure TWindowLayoutStoreTests.Test_SettingTheSameWindowTwiceReplacesIt;
var
   store: TWindowLayoutStore;
   r: TRect;
   visible: boolean;
begin
   BeginTest('Test_SettingTheSameWindowTwiceReplacesIt');
   store := TWindowLayoutStore.Create;
   try
      store.SetLayout('Main', Rect(1, 1, 1, 1), False);
      store.SetLayout('Main', Rect(9, 9, 9, 9), True);
      store.SetLayout('MAIN', Rect(5, 5, 5, 5), True);

      CheckEquals(1, store.EntryCount, 'one entry after three sets');
      CheckTrue(store.TryGetLayout('Main', r, visible), 'still readable');
      CheckEquals(5, r.Left, 'holding the last value written');
   finally
      store.Free;
   end;
end;

procedure TWindowLayoutStoreTests.Test_AnAbsentWindowLeavesTheCallersValuesAlone;
var
   store: TWindowLayoutStore;
   r: TRect;
   visible: boolean;
begin
   BeginTest('Test_AnAbsentWindowLeavesTheCallersValuesAlone');
   // LoadTR4WPOSFILE computes a default rect for every window and then asks the
   // file to override it. A TryGet that zeroed its out-parameters on a miss
   // would destroy that default and stack every unsaved window at the origin.
   store := TWindowLayoutStore.Create;
   try
      r := Rect(11, 22, 33, 44);
      visible := True;
      CheckFalse(store.TryGetLayout('NoSuchWindow', r, visible), 'reports absent');
      CheckEquals(11, r.Left,   'and left the caller''s left');
      CheckEquals(44, r.Bottom, 'and bottom');
      CheckTrue(visible, 'and visibility');
   finally
      store.Free;
   end;
end;

procedure TWindowLayoutStoreTests.Test_ANonObjectEntryIsSkippedNotReadAsZero;
var
   store: TWindowLayoutStore;
   value: TJSONValue;
begin
   BeginTest('Test_ANonObjectEntryIsSkippedNotReadAsZero');
   // A hand-edit that leaves a name pointing at a string must not be read as a
   // window at (0,0,0,0): that is a legal rect, so the window would move to the
   // corner with nothing anywhere saying the file was damaged.
   store := TWindowLayoutStore.Create;
   try
      value := TJSONObject.ParseJSONValue(
         '{"Main":"oops","BandMap":{"left":4,"top":0,"right":0,"bottom":0}}');
      try
         CheckTrue(value is TJSONObject, 'the fixture parses');
         store.FromJSON(TJSONObject(value));
      finally
         value.Free;
      end;

      CheckEquals(1, store.EntryCount, 'only the well-formed entry was taken');
      CheckTrue(store.IndexOfWindow('Main') < 0, 'and the damaged one was skipped');
      // BandMap above carries no "visible" key at all, which is the shape of
      // every hand edit that deletes a line. Absent must read as not visible
      // rather than raising or defaulting to shown.
      CheckTrue(store.IndexOfWindow('BandMap') >= 0, 'and the good one was taken');
   finally
      store.Free;
   end;
end;

procedure TWindowLayoutStoreTests.Test_AnUnknownWindowNameSurvivesASave;
var
   store: TWindowLayoutStore;
   fn: string;
   r: TRect;
   visible: boolean;
begin
   BeginTest('Test_AnUnknownWindowNameSurvivesASave');
   // What a NEWER TR4W's window looks like to an older build. SaveConfig's
   // merge protects whole SECTIONS; the windows section is written whole, so
   // preserving individual rows is SaveWindowLayout's job and needs its own
   // test.
   fn := TempFileName;
   store := TWindowLayoutStore.Create;
   try
      store.SetLayout('SomeWindowFromTheFuture', Rect(1, 2, 3, 4), True);
      SaveWindowLayout(fn, store);

      // Now save as a build that has never heard of it.
      store.Clear;
      store.SetLayout('Main', Rect(5, 6, 7, 8), True);
      SaveWindowLayout(fn, store);

      store.Clear;
      CheckTrue(LoadWindowLayout(fn, store), 'the layout loads');
      CheckTrue(store.TryGetLayout('SomeWindowFromTheFuture', r, visible),
                'the unknown window is still on disk');
      CheckEquals(3, r.Right, 'with its rect');
      CheckTrue(store.TryGetLayout('Main', r, visible), 'and ours beside it');
      CheckEquals(7, r.Right, 'with its own');
   finally
      store.Free;
   end;
end;

procedure TWindowLayoutStoreTests.Test_SaveAndLoadThroughTheSharedFile;
var
   store: TWindowLayoutStore;
   fn: string;
   r: TRect;
   visible: boolean;
begin
   BeginTest('Test_SaveAndLoadThroughTheSharedFile');
   fn := TempFileName;
   store := TWindowLayoutStore.Create;
   try
      // A file with no 'windows' section is not an error -- it is every file
      // written before this format existed, and the caller's cue to seed from
      // the old tr4w.pos.
      WriteAllTextUTF8(fn, '{"version": 1}');
      CheckFalse(LoadWindowLayout(fn, store), 'no windows section reports False');
      CheckEquals(0, store.EntryCount, 'and the store is empty');

      store.SetLayout('Radio1', Rect(100, 200, 300, 400), True);
      SaveWindowLayout(fn, store);

      store.Clear;
      CheckTrue(LoadWindowLayout(fn, store), 'now it loads');
      CheckTrue(store.TryGetLayout('Radio1', r, visible), 'Radio1 came back');
      CheckEquals(300, r.Right, 'with its rect');

      // And the tenant that was already in the file is untouched -- the
      // section-level guarantee, exercised from the window side.
      CheckTrue(Pos('"version"', ReadAllTextUTF8(fn)) > 0,
                'the version key that was there is still there');
   finally
      store.Free;
   end;
end;

// EXHAUSTIVE over WindowsType, not over the names known today.
procedure TWindowLayoutStoreTests.Test_WindowNamesAreUniqueAndPresent;
var
   i, j: WindowsType;
begin
   BeginTest('Test_WindowNamesAreUniqueAndPresent');
   // FPC checks the LENGTH of the array for us, so a missing name is a compile
   // error. A blank or DUPLICATE name is not: it compiles, and two windows then
   // share one saved rectangle with the winner decided by iteration order.
   // That is the silent-legal-value shape this codebase keeps being bitten by.
   for i := Low(WindowsType) to High(WindowsType) do
      begin
      CheckTrue(Trim(WindowNames[i]) <> '',
                Format('WindowNames[%d] is not blank', [Ord(i)]));

      // Ord(j) > Ord(i), so each PAIR is compared once rather than twice.
      // Succ(i) as the loop bound would be evaluated even when i is already
      // High(WindowsType), which is out of range for the type.
      for j := Low(WindowsType) to High(WindowsType) do
         begin
         if Ord(j) > Ord(i) then
            begin
            CheckFalse(SameText(WindowNames[i], WindowNames[j]),
                       Format('WindowNames[%d] "%s" is not also [%d]',
                              [Ord(i), WindowNames[i], Ord(j)]));
            end;
         end;
      end;
end;

procedure TWindowLayoutStoreTests.RunAllTests;
begin
   Test_LayoutSurvivesARoundTrip;
   Test_AZeroRectIsAValueNotAnAbsence;
   Test_LookupIsByNameNotByOrder;
   Test_LookupIsCaseInsensitive;
   Test_SettingTheSameWindowTwiceReplacesIt;
   Test_AnAbsentWindowLeavesTheCallersValuesAlone;
   Test_ANonObjectEntryIsSkippedNotReadAsZero;
   Test_AnUnknownWindowNameSurvivesASave;
   Test_SaveAndLoadThroughTheSharedFile;
   Test_WindowNamesAreUniqueAndPresent;
end;

end.

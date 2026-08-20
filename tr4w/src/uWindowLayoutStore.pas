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
unit uWindowLayoutStore;
{$I tr4w.inc}

{
  Where each TR4W window was left: the 'windows' section of settings\tr4w.json.

  WHAT THIS REPLACES, and why it is worth a unit.  The layout used to live in
  settings\tr4w.pos, which was a raw fwrite of `array[WindowsType] of TWndEntry`
  -- 22 entries of 25 bytes, and each of those 25 bytes was TRect(16) +
  boolean(1) + HWND(4) + Pointer(4).  A live window handle and a CODE POINTER,
  written to disk.  They were already noise on the way back in: LoadTR4WPOSFILE
  zeroes every handle and reassigns every WndProcAdr from literals immediately
  after reading them.  But they counted towards the size, and the size was the
  validity check:

      if GetFileSize(h, nil) <> SizeOf(tr4w_WindowsArray) then discard the file

  So three separate things silently reset every operator's layout.  Adding a
  member to WindowsType changes the size.  REORDERING that enum changes nothing
  about the size and instead moves each window's saved position onto a
  DIFFERENT window, because entries were addressed by array index.  And a
  64-bit build changes HWND and Pointer to eight bytes apiece -- 22 x 33 = 726
  against the 550 on disk -- so the first x86_64 TR4W anyone runs discards the
  layout of every TR4W before it.  That last one is not hypothetical; it is on
  the roadmap.

  SO THE FORMAT IS KEYED BY NAME AND HOLDS NOTHING THAT IS NOT DATA.  A rect and
  a visibility flag, under the window's name.  No handles, no pointers, no
  ordinal positions, nothing whose meaning depends on how this build happened to
  be compiled.

  THIS UNIT DOES NOT KNOW WHAT A TR4W WINDOW IS, deliberately.  It maps names to
  rectangles and nothing more; the WindowsType <-> name correspondence stays in
  VC.pas beside the enum it describes.  That keeps the uses clause pure RTL, so
  the store is testable without booting the application's globals -- the same
  discipline uRadioConfigStore holds to and for the same reason.

  IT KEEPS NAMES IT DOES NOT RECOGNISE.  A store is loaded, overwritten window
  by window, and written back, so an entry belonging to a window this build has
  never heard of survives the trip.  That is what a NEWER TR4W's windows look
  like to an older one, and dropping them would make running an older build once
  quietly destroy part of the layout.
}

interface

uses
   SysUtils,
   Classes,
   Types,
   Generics.Collections,
   uJSON;

type
   TWindowLayoutEntry = class(TObject)
   public
      Name: string;
      Rect: TRect;
      Visible: boolean;
   end;

   TWindowLayoutStore = class(TObject)
   private
      FEntries: TObjectList<TWindowLayoutEntry>;
   public
      constructor Create;
      destructor Destroy; override;

      procedure Clear;

      function EntryCount: integer;
      function Entry(const aIndex: integer): TWindowLayoutEntry;

      // Case-INSENSITIVE, matching the keyer and radio stores: the names are a
      // written-down contract and an operator hand-editing the file should not
      // be able to orphan a window by typing 'bandmap'.
      function IndexOfWindow(const aName: string): integer;

      // Replace-or-add. A blank name is refused rather than stored: it could
      // only come from a bug, and an entry nothing can look up again is worse
      // than no entry.
      procedure SetLayout(const aName: string; const aRect: TRect;
                          const aVisible: boolean);

      // False when the name is absent, and aRect/aVisible are then untouched --
      // so the caller keeps whatever default it had computed. There is no
      // "empty rect" sentinel because (0,0,0,0) is a value the old format could
      // and did store.
      function TryGetLayout(const aName: string; var aRect: TRect;
                            var aVisible: boolean): boolean;

      function ToJSON: TJSONObject;
      procedure FromJSON(const aObj: TJSONObject);
   end;

implementation

const
   // The field names inside one window's object. Spelled out rather than
   // derived, because these are on disk and a refactor must not be able to
   // rename them by accident.
   KEY_LEFT    = 'left';
   KEY_TOP     = 'top';
   KEY_RIGHT   = 'right';
   KEY_BOTTOM  = 'bottom';
   KEY_VISIBLE = 'visible';

constructor TWindowLayoutStore.Create;
begin
   inherited Create;
   FEntries := TObjectList<TWindowLayoutEntry>.Create(True);
end;

destructor TWindowLayoutStore.Destroy;
begin
   FEntries.Free;
   inherited Destroy;
end;

procedure TWindowLayoutStore.Clear;
begin
   FEntries.Clear;
end;

function TWindowLayoutStore.EntryCount: integer;
begin
   Result := FEntries.Count;
end;

function TWindowLayoutStore.Entry(const aIndex: integer): TWindowLayoutEntry;
begin
   if (aIndex < 0) or (aIndex >= FEntries.Count) then
      begin
      Result := nil;
      Exit;
      end;
   Result := FEntries[aIndex];
end;

function TWindowLayoutStore.IndexOfWindow(const aName: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to FEntries.Count - 1 do
      begin
      if SameText(FEntries[i].Name, aName) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure TWindowLayoutStore.SetLayout(const aName: string; const aRect: TRect;
                                       const aVisible: boolean);
var
   idx: integer;
   entry: TWindowLayoutEntry;
begin
   if Trim(aName) = '' then
      begin
      Exit;
      end;

   idx := IndexOfWindow(aName);
   if idx >= 0 then
      begin
      entry := FEntries[idx];
      end
   else
      begin
      entry := TWindowLayoutEntry.Create;
      // The name as the CALLER spells it on a new entry; an existing entry
      // keeps the spelling already on disk, so a hand-edited file is not
      // rewritten underneath the operator on every save.
      entry.Name := aName;
      FEntries.Add(entry);
      end;

   entry.Rect    := aRect;
   entry.Visible := aVisible;
end;

function TWindowLayoutStore.TryGetLayout(const aName: string; var aRect: TRect;
                                         var aVisible: boolean): boolean;
var
   idx: integer;
begin
   idx := IndexOfWindow(aName);
   Result := idx >= 0;
   if not Result then
      begin
      Exit;
      end;

   aRect    := FEntries[idx].Rect;
   aVisible := FEntries[idx].Visible;
end;

function TWindowLayoutStore.ToJSON: TJSONObject;
var
   i: integer;
   win: TJSONObject;
begin
   // An OBJECT keyed by window name, not an array of {name, rect} -- so the
   // file reads as "BandMap": { ... } and needs no schema to follow. Same
   // choice, for the same reason, as the radio store's `commands`.
   Result := TJSONObject.Create;
   for i := 0 to FEntries.Count - 1 do
      begin
      win := TJSONObject.Create;
      win.AddPair(KEY_LEFT,    TJSONNumber.Create(FEntries[i].Rect.Left));
      win.AddPair(KEY_TOP,     TJSONNumber.Create(FEntries[i].Rect.Top));
      win.AddPair(KEY_RIGHT,   TJSONNumber.Create(FEntries[i].Rect.Right));
      win.AddPair(KEY_BOTTOM,  TJSONNumber.Create(FEntries[i].Rect.Bottom));
      win.AddPair(KEY_VISIBLE, TJSONBool.Create(FEntries[i].Visible));
      JSONSetSection(Result, FEntries[i].Name, win);
      end;
end;

procedure TWindowLayoutStore.FromJSON(const aObj: TJSONObject);
var
   i: integer;
   value: TJSONValue;
   win: TJSONObject;
   r: TRect;
   visible: boolean;
begin
   Clear;
   if aObj = nil then
      begin
      Exit;
      end;

   for i := 0 to aObj.Count - 1 do
      begin
      value := JSONPairValue(aObj, i);
      if not (value is TJSONObject) then
         begin
         // A name whose value is not an object is skipped rather than treated
         // as a window at (0,0,0,0). A zero rect is a LEGAL value here, so
         // defaulting would put a window in the top-left corner with nothing
         // to say it had been damaged.
         Continue;
         end;

      win := TJSONObject(value);
      r.Left   := JSONGetInt(win, KEY_LEFT,   0);
      r.Top    := JSONGetInt(win, KEY_TOP,    0);
      r.Right  := JSONGetInt(win, KEY_RIGHT,  0);
      r.Bottom := JSONGetInt(win, KEY_BOTTOM, 0);

      // Absent means NOT visible, which is what the old format's zeroed
      // boolean meant for a window that had never been opened.
      //
      // Read through the TEXT form on purpose, so "visible": "true" from a hand
      // edit reads the same as "visible": true. This file is meant to be edited
      // by an operator, and the radio store's JSONGetInt tolerates a quoted
      // number for exactly the same reason. SameText also covers a writer that
      // spells it True.
      visible := SameText(JSONGetStr(win, KEY_VISIBLE, 'false'), 'true');

      SetLayout(JSONPairName(aObj, i), r, visible);
      end;
end;

end.

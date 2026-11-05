unit uNewContestHostArea;

(* A QSO PARTY STATION'S OWN QTH, AS THE NEW CONTEST DIALOG ASKS FOR IT --
  issue 217 (NY4I, 2026-11-05).

  WHY IT EXISTS. A QSO party's MY STATE holds one of two things: the
  station's county when it is inside the host area, its state, province or
  DX when it is outside. Set-up tells them apart by one rule --
  FCONTEST.FoundMyStateInDomFile: is the value a KEY of the party's county
  file? The dialog asked for both in one free-text box under a MY STATE
  label and checked nothing, so a Florida station could type anything and be
  set up out of state without a word.

  The dialog now asks "I am in <area>" first. Inside, it offers the county
  file's keys and nothing else; outside, it takes a state, a province or DX.
  This unit is the part of that which needs no form, so it can be pinned:

    THostAreaPlaces           the county file's keys, in file order, each
                              with the text the drop-down shows for it;
    HostAreaStationIsInside   the in-state rule, as set-up applies it;
    HostAreaOutsideRefusal    what an outside entry may be.

  THE KEYS ARE READ BY uDomFileKeys' OWN RULE (DomFileLineKey), and INCLUDE
  lines are NOT followed -- FoundMyStateInDomFile does not follow them, so a
  key only an included file declares would be offered and then judged out of
  state. The key is the UPPER-CASED spelling, which is what the old free-text
  box stored (its CharCase is upper), so a county chosen from the list sends
  exactly the text an operator typing it sent before.

  A LEAF: no form, no contest, no global. *)

{$I tr4w.inc}

interface

uses
   Classes;

type
   (* THE PLACES INSIDE A HOST AREA -- one per key of its county file. *)
   THostAreaPlaces = class
   private
      FKeys: TStringList;
      FDisplays: TStringList;
   public
      constructor Create;
      destructor Destroy; override;

      (* Forgets what was loaded, then takes every key aLines declares, first
        spelling wins. A key's display is 'KEY - Name' when its line gives a
        '^Name', else the key alone. *)
      procedure LoadFromLines(const aLines: TStrings);
      (* The same, of the file at aPath. A missing file loads nothing. *)
      procedure LoadFromFile(const aPath: string);

      function Count: integer;
      (* The value stored and sent for place aIndex. *)
      function Key(aIndex: integer): string;
      (* What the drop-down shows for place aIndex. *)
      function Display(aIndex: integer): string;
      (* The place aValue names, trimmed and in any case; -1 for none. *)
      function IndexOfKey(const aValue: string): integer;

      (* Both lists, index for index, for a control to take a copy of. *)
      property Keys: TStringList read FKeys;
      property Displays: TStringList read FDisplays;
   end;

(* IS A STATION WHOSE MY STATE IS aValue INSIDE THE AREA? -- set-up's rule
  (a key of the county file), never True for an empty value. *)
function HostAreaStationIsInside(const aPlaces: THostAreaPlaces;
                                 const aValue: string): boolean;

(* WHY aValue IS NOT AN ENTRY FOR A STATION OUTSIDE aArea -- '' accepts it.

  Accepted: a US state or Canadian province (uPOTAReference.LooksLikeAState,
  the list Tree always had), or DX; in any case. Refused, saying so: a key of
  the area's places, and aHostState itself -- either would describe a
  station INSIDE the area, which the box is for. Refused: anything else. An
  empty value is accepted here: an empty row is the dialog's own rule. *)
function HostAreaOutsideRefusal(const aPlaces: THostAreaPlaces;
                                const aArea, aHostState, aValue: string): string;

implementation

uses
   SysUtils,
   uDomFileKeys,     (* DomFileLineKey -- the in-state test's own key rule *)
   uPOTAReference,   (* LooksLikeAState -- the states and provinces *)
   uAppStrings;      (* SNewContestHostAreaEntry* *)

const
   (* What a station outside every party's area may send for its QTH. *)
   HOST_AREA_DX = 'DX';

(* The first '^Name' of the line's aliases, without its '^'; '' for none. *)
function DomLineDisplayName(const aLine: string): string;
var
   rest: string;
   item: string;
   p: integer;
begin
   Result := '';
   p := Pos('=', aLine);
   if p = 0 then
      begin
      Exit;
      end;

   rest := Copy(aLine, p + 1, Length(aLine));
   while rest <> '' do
      begin
      p := Pos(',', rest);
      if p > 0 then
         begin
         item := Trim(Copy(rest, 1, p - 1));
         rest := Copy(rest, p + 1, Length(rest));
         end
      else
         begin
         item := Trim(rest);
         rest := '';
         end;

      if (Length(item) > 1) and (item[1] = '^') then
         begin
         Result := Trim(Copy(item, 2, Length(item)));
         Exit;
         end;
      end;
end;

constructor THostAreaPlaces.Create;
begin
   inherited Create;
   FKeys := TStringList.Create;
   FDisplays := TStringList.Create;
end;

destructor THostAreaPlaces.Destroy;
begin
   FreeAndNil(FDisplays);
   FreeAndNil(FKeys);
   inherited Destroy;
end;

procedure THostAreaPlaces.LoadFromLines(const aLines: TStrings);
var
   i: integer;
   key: string;
   name: string;
begin
   FKeys.Clear;
   FDisplays.Clear;
   for i := 0 to aLines.Count - 1 do
      begin
      key := DomFileLineKey(aLines[i]);
      if (key = '') or (IndexOfKey(key) >= 0) then
         begin
         Continue;
         end;

      (* AnsiString() STATED: TStringList holds the RTL string and this unit's
        string is UnicodeString. The shipped .dom files are ASCII -- the
        list was read from one as AnsiString a moment ago -- so nothing is
        lost; saying so keeps the conversion out of the narrowing count. *)
      name := DomLineDisplayName(aLines[i]);
      FKeys.Add(AnsiString(key));
      if name <> '' then
         begin
         FDisplays.Add(AnsiString(key + ' - ' + name));
         end
      else
         begin
         FDisplays.Add(AnsiString(key));
         end;
      end;
end;

procedure THostAreaPlaces.LoadFromFile(const aPath: string);
var
   lines: TStringList;
begin
   FKeys.Clear;
   FDisplays.Clear;
   if not FileExists(aPath) then
      begin
      Exit;
      end;

   lines := TStringList.Create;
   try
      (* EXPLICIT AT THE BOUNDARY -- uDomFileKeys.DomFileOnDiskDeclaresKey's
        reason: TStrings.LoadFromFile takes the RTL's AnsiString name. *)
      lines.LoadFromFile(AnsiString(aPath));
      LoadFromLines(lines);
   finally
      lines.Free;
      end;
end;

function THostAreaPlaces.Count: integer;
begin
   Result := FKeys.Count;
end;

function THostAreaPlaces.Key(aIndex: integer): string;
begin
   Result := FKeys[aIndex];
end;

function THostAreaPlaces.Display(aIndex: integer): string;
begin
   Result := FDisplays[aIndex];
end;

function THostAreaPlaces.IndexOfKey(const aValue: string): integer;
var
   wanted: string;
   i: integer;
begin
   Result := -1;
   wanted := UpperCase(Trim(aValue));
   if wanted = '' then
      begin
      Exit;
      end;

   for i := 0 to FKeys.Count - 1 do
      begin
      if FKeys[i] = wanted then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function HostAreaStationIsInside(const aPlaces: THostAreaPlaces;
                                 const aValue: string): boolean;
begin
   Result := (aPlaces <> nil) and (aPlaces.IndexOfKey(aValue) >= 0);
end;

function HostAreaOutsideRefusal(const aPlaces: THostAreaPlaces;
                                const aArea, aHostState, aValue: string): string;
var
   entry: string;
begin
   Result := '';
   entry := UpperCase(Trim(aValue));
   if entry = '' then
      begin
      Exit;
      end;

   if HostAreaStationIsInside(aPlaces, entry) or
      ((aHostState <> '') and (entry = UpperCase(Trim(aHostState)))) then
      begin
      Result := Format(SNewContestHostAreaEntryIsInside, [entry, aArea]);
      Exit;
      end;

   if (entry = HOST_AREA_DX) or LooksLikeAState(entry) then
      begin
      Exit;
      end;

   Result := Format(SNewContestHostAreaEntryNotAState, [entry]);
end;

end.

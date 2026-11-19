unit uRoverState;

(* WHERE A ROVING STATION IS OPERATING NOW -- issues 133 and 87 (NY4I,
  2026-11-19).

  A rover (a QSO-party mobile, a Hawaii QSO Party district rover) changes the
  place it sends during the event. The place is one of the CONTEST'S OWN
  UNITS -- a county code of its .dom, a Hawaii district -- and at a boundary
  (a county line) it is several at once, up to the class's
  CountyLineCountiesMax. One log covers the whole event; each QSO is stamped
  with the unit it was sent from.

  THE RULINGS THIS HOLDS TO:
    * a bare ROVER in the call window (or Tools -> Commands) opens a dialog;
      no typed argument in the call window;
    * the dialog takes ONE unit or SEVERAL, typed and separated by a space, a
      comma or a dash (a slash too: the on-air spelling NY4I/KON/KOH uses
      one), or picked from the list; up to the contest's county-line limit;
    * OFF is a dialog choice: roving off, and nothing else changes;
    * with roving off NOTHING changes anywhere -- every reader asks Active
      first.

  No shipped .dom key holds a space, a comma, a dash or a slash (measured
  2026-11-19 over tr4w/target/dom), so splitting on them loses no key.

  A LEAF: no form, no contest, no global but the one state object. The
  dialog, the stamp and the sent exchange read it; only the dialog writes it.
  Main thread only, like the settings it stands beside. *)

{$I tr4w.inc}

interface

uses
   Classes,
   uNewContestHostArea;   (* THostAreaPlaces -- the contest's units *)

type
   TRoverState = class
   private
      FUnits: TStringList;
   public
      constructor Create;
      destructor Destroy; override;

      (* True while roving: at least one unit is set. *)
      function Active: boolean;
      function Count: integer;
      (* Unit aIndex, as the contest's .dom spells its key (upper case). *)
      function UnitAt(aIndex: integer): string;
      (* The units joined by aSeparator, in the order they were chosen --
        'KOH/KON' for '/'. '' when not roving. *)
      function Joined(const aSeparator: string): string;

      (* Roving from exactly aUnits (already validated); an empty list is
        TurnOff. *)
      procedure SetUnits(const aUnits: TStrings);
      procedure TurnOff;
   end;

(* THE UNITS TYPED IN aText, split on a space, a comma, a dash or a slash,
  each trimmed and upper-cased, a repeat dropped, order kept. aUnits is
  emptied first. True when at least one unit was found. *)
function SplitRoverUnitsText(const aText: string; aUnits: TStrings): boolean;

(* WHY aUnits CANNOT BE THE ROVER'S PLACE -- '' accepts them.

  Refused: no unit at all; a unit that is no key of aPlaces (named in the
  reason); more units than aMaxUnits. aMaxUnits below 1 means one. *)
function RoverUnitsRefusal(const aUnits: TStrings;
                           const aPlaces: THostAreaPlaces;
                           aMaxUnits: integer): string;

var
   (* Created in this unit's initialization, freed in its finalization. *)
   RoverState: TRoverState;

implementation

uses
   SysUtils,
   uAppStrings;   (* SRover* *)

constructor TRoverState.Create;
begin
   inherited Create;
   FUnits := TStringList.Create;
end;

destructor TRoverState.Destroy;
begin
   FreeAndNil(FUnits);
   inherited Destroy;
end;

function TRoverState.Active: boolean;
begin
   Result := FUnits.Count > 0;
end;

function TRoverState.Count: integer;
begin
   Result := FUnits.Count;
end;

function TRoverState.UnitAt(aIndex: integer): string;
begin
   Result := string(FUnits[aIndex]);
end;

function TRoverState.Joined(const aSeparator: string): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to FUnits.Count - 1 do
      begin
      if i > 0 then
         begin
         Result := Result + aSeparator;
         end;
      Result := Result + string(FUnits[i]);
      end;
end;

procedure TRoverState.SetUnits(const aUnits: TStrings);
begin
   FUnits.Assign(aUnits);
end;

procedure TRoverState.TurnOff;
begin
   FUnits.Clear;
end;

function SplitRoverUnitsText(const aText: string; aUnits: TStrings): boolean;
var
   i: integer;
   word: string;

   procedure TakeWord;
   begin
      word := UpperCase(Trim(word));
      (* AnsiString() STATED: the list holds the RTL string; a unit is an
        ASCII .dom key. *)
      if (word <> '') and (aUnits.IndexOf(AnsiString(word)) < 0) then
         begin
         aUnits.Add(AnsiString(word));
         end;
      word := '';
   end;

begin
   aUnits.Clear;
   word := '';
   for i := 1 to Length(aText) do
      begin
      if CharInSet(aText[i], [' ', ',', '-', '/', #9]) then
         begin
         TakeWord;
         end
      else
         begin
         word := word + aText[i];
         end;
      end;
   TakeWord;
   Result := aUnits.Count > 0;
end;

function RoverUnitsRefusal(const aUnits: TStrings;
                           const aPlaces: THostAreaPlaces;
                           aMaxUnits: integer): string;
var
   i: integer;
begin
   Result := '';
   if aUnits.Count = 0 then
      begin
      Result := SRoverNoUnit;
      Exit;
      end;

   for i := 0 to aUnits.Count - 1 do
      begin
      if aPlaces.IndexOfKey(string(aUnits[i])) < 0 then
         begin
         Result := Format(SRoverUnknownUnit, [string(aUnits[i])]);
         Exit;
         end;
      end;

   if aMaxUnits < 1 then
      begin
      aMaxUnits := 1;
      end;
   if aUnits.Count > aMaxUnits then
      begin
      Result := Format(SRoverTooManyUnits, [aMaxUnits]);
      end;
end;

initialization
   RoverState := TRoverState.Create;

finalization
   FreeAndNil(RoverState);

end.

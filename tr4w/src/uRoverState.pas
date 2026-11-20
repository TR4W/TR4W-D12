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
   VC,                    (* ContestExchange -- a boundary QSO's legs *)
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

(* THE CALL ON THE AIR (NY4I, 2026-11-17, 2026-11-19 and 2026-11-20): while
  roving, MY CALL gains the rover's places -- NY4I/KOH, and at a boundary
  NY4I/KOH/KON, in the order chosen. It is what the message token
  {ROVERCALL} keys, and what the S&P call and DE <call> send. The macros'
  '\' does NOT use it: '\' is always the plain call setting (NY4I,
  2026-11-20). Not roving: aCall unchanged; a fixed station never sends a
  /KOH.

  The message tokens themselves -- {ROVERCALL}, {ROVERQTH} -- are read by
  uMessageText, the one grammar of a program message. *)
function RovingCall(const aCall: string): string;

type
   TRoverLegs = array of ContestExchange;

(* A BOUNDARY OPERATION'S EXTRA QSOs -- issue 133 (NY4I 2026-11-18, the HQP
  rules: "Log such contacts as TWO contacts, one from each location"; and
  2026-11-19: one row per county). aLogged is every QSO the entry has logged
  already -- the first, and each leg of a county line the WORKED station was
  on -- each stamped with the rover's FIRST place. The answer is, for each
  further place in the order chosen, a copy of every one of them stamped with
  that place: one row per place, the received legs crossed with ours. Every
  copy keeps the entry's ContestExchange.id, so the store files them in one
  qso_set_id with the first (SaveQSOGroupingByExchangeId): the common id that
  links one contact's rows. Not roving, or one place: empty. *)
function RoverBoundaryLegs(const aLogged: TRoverLegs;
                           const aState: TRoverState): TRoverLegs;

var
   (* Created in this unit's initialization, freed in its finalization. *)
   RoverState: TRoverState;

implementation

uses
   SysUtils,
   uQsoMyFacts,   (* AssembledCall -- the one call assembly *)
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

function RovingCall(const aCall: string): string;
begin
   Result := aCall;
   if (RoverState <> nil) and RoverState.Active then
      begin
      Result := AssembledCall(aCall, RoverState.Joined('/'));
      end;
end;

function RoverBoundaryLegs(const aLogged: TRoverLegs;
                           const aState: TRoverState): TRoverLegs;
var
   place, leg, n: integer;
begin
   Result := nil;
   if (aState = nil) or (aState.Count < 2) then
      begin
      Exit;
      end;
   SetLength(Result, (aState.Count - 1) * Length(aLogged));
   n := 0;
   for place := 1 to aState.Count - 1 do
      begin
      for leg := 0 to High(aLogged) do
         begin
         Result[n] := aLogged[leg];
         Result[n].ceRoverQTH := ShortString(aState.UnitAt(place));
         (* NOT THE FIRST PLACE'S DUPE: LogContact marks a copy a dupe only
           when ITS key is one, and never clears the mark. Its points are the
           caller's to work out again (a dupe's were zeroed); its multiplier
           flags SetMultFlags clears and decides afresh. *)
         Result[n].ceDupe := False;
         Inc(n);
         end;
      end;
end;

initialization
   RoverState := TRoverState.Create;

finalization
   FreeAndNil(RoverState);

end.

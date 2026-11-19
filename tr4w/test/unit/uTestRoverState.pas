unit uTestRoverState;
{$I ..\..\src\tr4w.inc}

(* WHERE A ROVING STATION IS NOW -- issues 133 and 87 (NY4I, 2026-11-19).

  WHAT IS PINNED, AND WHY EACH:

    the split       a typed entry takes a space, a comma, a dash or a slash
                    between units, any case, a repeat once: NY4I's three
                    separators plus the on-air slash;
    the refusal     a unit that is no place of the contest is named; more
                    units than the county-line limit are refused; a limit
                    below one means one;
    the state       off by default, on with the units in the order chosen,
                    off again on TurnOff -- and joined for display. *)

interface

uses
   uTR4WTestFramework;

type
   TRoverStateTests = class(TTestCase)
   protected
      procedure Test_TheThreeSeparatorsAndTheSlashSplitUnits;
      procedure Test_AnUnknownUnitIsNamed;
      procedure Test_TheCountyLineLimitHolds;
      procedure Test_TheStateIsOffUntilSet;
      procedure Test_HawaiiRovesItsFourteenDistrictsTwoAtATime;
      procedure Test_TheDialogTicksWhatIsTypedAndRefusesPastTheLimit;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes, Controls,
   uAppStrings,          (* SRover* *)
   uRoverForm,           (* TfrmRover *)
   VC,                   (* CQWWCW, TContestHandle *)
   uContestRegistry,     (* FindContestById, ContestIdentity *)
   uAppPaths,            (* ShippedDomDirOverride *)
   uTestContestObjects,  (* ShippedDomDir -- the tree's target\dom *)
   uNewContestHostArea,  (* THostAreaPlaces *)
   uRoverSession,        (* ContestRoverPlaces *)
   uRoverState;

(* Three Hawaii districts, as hawaiiqp_cty.dom spells its lines. *)
function HawaiiPlaces: THostAreaPlaces;
var
   lines: TStringList;
begin
   Result := THostAreaPlaces.Create;
   lines := TStringList.Create;
   try
      lines.Add('KOH > Hi = KOH,^Kohala');
      lines.Add('KON > Hi = KON,^Kona');
      lines.Add('HIL > Hi = HIL,^Hilo');
      Result.LoadFromLines(lines);
   finally
      lines.Free;
      end;
end;

procedure TRoverStateTests.Test_TheThreeSeparatorsAndTheSlashSplitUnits;
var
   units: TStringList;
begin
   BeginTest('Test_TheThreeSeparatorsAndTheSlashSplitUnits');
   units := TStringList.Create;
   try
      CheckTrue(SplitRoverUnitsText('koh', units), 'one unit');
      CheckEquals('KOH', units.CommaText, 'upper-cased');

      SplitRoverUnitsText('KOH KON', units);
      CheckEquals('KOH,KON', units.CommaText, 'a space');
      SplitRoverUnitsText('KOH,KON', units);
      CheckEquals('KOH,KON', units.CommaText, 'a comma');
      SplitRoverUnitsText('KOH-KON', units);
      CheckEquals('KOH,KON', units.CommaText, 'a dash');
      SplitRoverUnitsText('KOH/KON', units);
      CheckEquals('KOH,KON', units.CommaText, 'a slash');
      SplitRoverUnitsText(' KON , - koh  ', units);
      CheckEquals('KON,KOH', units.CommaText, 'mixed, blanks, order kept');
      SplitRoverUnitsText('KOH KOH kon', units);
      CheckEquals('KOH,KON', units.CommaText, 'a repeat counts once');

      CheckFalse(SplitRoverUnitsText(' , - ', units), 'separators alone are nothing');
      CheckEquals(0, units.Count, 'and leave the list empty');
   finally
      units.Free;
      end;
end;

procedure TRoverStateTests.Test_AnUnknownUnitIsNamed;
var
   units: TStringList;
   places: THostAreaPlaces;
begin
   BeginTest('Test_AnUnknownUnitIsNamed');
   units := TStringList.Create;
   places := HawaiiPlaces;
   try
      SplitRoverUnitsText('KOH', units);
      CheckEquals('', RoverUnitsRefusal(units, places, 2), 'a district is a place');

      SplitRoverUnitsText('KOH XYZ', units);
      CheckEquals(Format(SRoverUnknownUnit, ['XYZ']),
                  RoverUnitsRefusal(units, places, 2), 'XYZ is named');

      units.Clear;
      CheckEquals(string(SRoverNoUnit), RoverUnitsRefusal(units, places, 2),
                  'nothing is refused');
   finally
      places.Free;
      units.Free;
      end;
end;

procedure TRoverStateTests.Test_TheCountyLineLimitHolds;
var
   units: TStringList;
   places: THostAreaPlaces;
begin
   BeginTest('Test_TheCountyLineLimitHolds');
   units := TStringList.Create;
   places := HawaiiPlaces;
   try
      SplitRoverUnitsText('KOH KON', units);
      CheckEquals('', RoverUnitsRefusal(units, places, 2),
                  'two at Hawaii''s limit of two');
      SplitRoverUnitsText('KOH KON HIL', units);
      CheckEquals(Format(SRoverTooManyUnits, [2]),
                  RoverUnitsRefusal(units, places, 2), 'three past it');

      SplitRoverUnitsText('KOH KON', units);
      CheckEquals(Format(SRoverTooManyUnits, [1]),
                  RoverUnitsRefusal(units, places, 0),
                  'a party with no county line takes one');
      CheckEquals('', RoverUnitsRefusal(units, places, High(integer)),
                  'an unlimited party takes any number');
   finally
      places.Free;
      units.Free;
      end;
end;

procedure TRoverStateTests.Test_TheStateIsOffUntilSet;
var
   state: TRoverState;
   units: TStringList;
begin
   BeginTest('Test_TheStateIsOffUntilSet');
   state := TRoverState.Create;
   units := TStringList.Create;
   try
      CheckFalse(state.Active, 'off when made');
      CheckEquals('', state.Joined('/'), 'and joins to nothing');

      SplitRoverUnitsText('KON KOH', units);
      state.SetUnits(units);
      CheckTrue(state.Active, 'on with units');
      CheckEquals(2, state.Count, 'two of them');
      CheckEquals('KON', state.UnitAt(0), 'in the order chosen');
      CheckEquals('KON/KOH', state.Joined('/'), 'joined for display');

      state.TurnOff;
      CheckFalse(state.Active, 'off again');

      CheckFalse(RoverState.Active, 'the program''s state starts off');
   finally
      units.Free;
      state.Free;
      end;
end;

(* THE CONTEST'S OWN UNITS: Hawaii's district file (the New Contest box's), at
  its county-line limit of two; Georgia's counties at its own; CQ WW has none,
  so ROVER says so. *)
procedure TRoverStateTests.Test_HawaiiRovesItsFourteenDistrictsTwoAtATime;
var
   places: THostAreaPlaces;
   maxUnits: integer;
   handle: TContestHandle;
   savedDomDir: string;
begin
   BeginTest('Test_HawaiiRovesItsFourteenDistrictsTwoAtATime');
   places := THostAreaPlaces.Create;
   savedDomDir := ShippedDomDirOverride;
   try
      ShippedDomDirOverride := ShippedDomDir;

      CheckTrue(FindContestById('HI-QSO-PARTY', handle), 'Hawaii is registered');
      CheckTrue(ContestRoverPlaces(ContestIdentity(handle), places, maxUnits),
                'Hawaii has rover places');
      CheckEquals(14, places.Count, 'its fourteen districts');
      CheckTrue(places.IndexOfKey('KOH') >= 0, 'KOH among them');
      CheckEquals(-1, places.IndexOfKey('HI'), 'and no state');
      CheckEquals(2, maxUnits, 'two at a district line');

      CheckFalse(ContestRoverPlaces(ContestIdentity(CQWWCW), places, maxUnits),
                 'CQ WW has no places to rove');
      CheckEquals(0, places.Count, 'and loads none');
      CheckEquals(1, maxUnits, 'and its limit reads one');

      CheckFalse(ContestRoverPlaces(nil, places, maxUnits), 'no contest, no places');
   finally
      ShippedDomDirOverride := savedDomDir;
      places.Free;
      end;
end;

(* THE DIALOG, NEVER SHOWN: what is typed ticks the list, a tick writes the
  box, OK refuses past the limit and names why, "Rover off" turns it off. *)
procedure TRoverStateTests.Test_TheDialogTicksWhatIsTypedAndRefusesPastTheLimit;
var
   places: THostAreaPlaces;
   state: TRoverState;
   form: TfrmRover;
begin
   BeginTest('Test_TheDialogTicksWhatIsTypedAndRefusesPastTheLimit');
   places := HawaiiPlaces;
   state := TRoverState.Create;
   form := TfrmRover.Create(nil);
   try
      form.Prepare(places, 2, state);
      CheckEquals(3, form.clbUnits.Items.Count, 'one row per place');
      CheckEquals('KOH - Kohala', form.clbUnits.Items[0], 'shown with its name');
      CheckEquals('', form.edtUnits.Text, 'nothing typed when not roving');

      form.edtUnits.Text := 'KOH-KON';
      CheckTrue(form.clbUnits.Checked[0], 'KOH ticked from the box');
      CheckTrue(form.clbUnits.Checked[1], 'KON ticked from the box');
      CheckFalse(form.clbUnits.Checked[2], 'HIL not');

      form.clbUnits.Checked[1] := False;
      form.UnitsClickCheck(form.clbUnits);
      CheckEquals('KOH', form.edtUnits.Text, 'unticking KON takes it out of the box');

      form.edtUnits.Text := 'KOH KON HIL';
      form.OKClick(form.btnOK);
      CheckEquals(integer(mrNone), integer(form.ModalResult), 'three at a limit of two stays open');
      CheckEquals(Format(SRoverTooManyUnits, [2]), form.lblRefusal.Caption, 'and says why');

      form.edtUnits.Text := 'kon, koh';
      form.OKClick(form.btnOK);
      CheckEquals(integer(mrOK), integer(form.ModalResult), 'two is accepted');
      CheckEquals('KON,KOH', form.Chosen.CommaText, 'in the order typed');
      CheckFalse(form.TurnedOff, 'and is no "off"');

      form.OffClick(form.btnOff);
      CheckTrue(form.TurnedOff, '"Rover off" turns it off');
      CheckEquals(0, form.Chosen.Count, 'with nothing chosen');
   finally
      form.Free;
      state.Free;
      places.Free;
      end;
end;

procedure TRoverStateTests.RunAllTests;
begin
   Test_TheThreeSeparatorsAndTheSlashSplitUnits;
   Test_AnUnknownUnitIsNamed;
   Test_TheCountyLineLimitHolds;
   Test_TheStateIsOffUntilSet;
   Test_HawaiiRovesItsFourteenDistrictsTwoAtATime;
   Test_TheDialogTicksWhatIsTypedAndRefusesPastTheLimit;
end;

end.

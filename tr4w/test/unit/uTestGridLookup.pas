unit uTestGridLookup;
{$I ..\..\src\tr4w.inc}

(*
   A WSJT-X GRID NAMES A STATE ONLY WHEN IT LIES IN ONE (issue 52).

   The table is WSJT-X's grid.dat, 695 grids, compiled into uGridLookup. A grid
   in several states is ambiguous: NO state is inferred and the candidates are
   worded for the operator (NY4I: 'possible states for EN61 are ...').
   Expected values are read from the attached grid.txt, not from the code.
*)

interface

uses
   SysUtils, Classes,
   uTR4WTestFramework;

type
   TGridLookupTests = class(TTestCase)
   private
      procedure Test_TheTableHoldsEveryGrid;
      procedure Test_UniqueGrids;
      procedure Test_AmbiguousGridsInferNothing;
      procedure Test_UnknownAndMalformedGrids;
      procedure Test_CaseAndSixCharacterGrids;
      procedure Test_PossibleStatesComment;
      procedure Test_ReturnStatesForGrid;
      procedure Test_OwnLifetime;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uGridLookup;

procedure TGridLookupTests.Test_TheTableHoldsEveryGrid;
begin
   BeginTest('Test_TheTableHoldsEveryGrid');
   CheckEquals(695, GRID_STATE_TABLE_COUNT, 'the attached file has 695 grids');
   CheckEquals(695, GridLookupShared.GridCount, 'every one loaded, none merged');
end;

procedure TGridLookupTests.Test_UniqueGrids;
var
   state: string;
begin
   BeginTest('Test_UniqueGrids');
   CheckTrue(StateOfGrid('EL87', state) = gskUnique, 'EL87 unique');
   CheckEquals('FL', state, 'EL87');
   CheckTrue(StateOfGrid('EL88', state) = gskUnique, 'EL88 unique');
   CheckEquals('FL', state, 'EL88');
   CheckTrue(StateOfGrid('AL91', state) = gskUnique, 'AL91 unique');
   CheckEquals('HI', state, 'AL91');
   CheckTrue(StateOfGrid('DM03', state) = gskUnique, 'DM03 unique');
   CheckEquals('CA', state, 'DM03');
end;

procedure TGridLookupTests.Test_AmbiguousGridsInferNothing;
var
   state: string;
begin
   BeginTest('Test_AmbiguousGridsInferNothing');
   CheckTrue(StateOfGrid('DM07', state) = gskAmbiguous, 'DM07 is CA-NV');
   CheckEquals('', state, 'no state is inferred, not even the first');
   CheckTrue(StateOfGrid('EN61', state) = gskAmbiguous, 'EN61 is IL-IN-MI');
   CheckEquals('', state, 'EN61 infers nothing');
   CheckTrue(StateOfGrid('EN02', state) = gskAmbiguous, 'EN02 is NE-SD');
end;

procedure TGridLookupTests.Test_UnknownAndMalformedGrids;
var
   state: string;
begin
   BeginTest('Test_UnknownAndMalformedGrids');
   CheckTrue(StateOfGrid('JO22', state) = gskUnknown, 'a grid outside the table');
   CheckEquals('', state, 'unknown');
   CheckTrue(StateOfGrid('', state) = gskUnknown, 'empty');
   CheckTrue(StateOfGrid('EL', state) = gskUnknown, 'a field alone is not a grid');
   CheckTrue(StateOfGrid('EL8', state) = gskUnknown, 'three characters');
   CheckTrue(StateOfGrid('EL87a', state) = gskUnknown, 'five characters');
   CheckTrue(StateOfGrid('ZZ87', state) = gskUnknown, 'a field beyond R');
   CheckTrue(StateOfGrid('EL8X', state) = gskUnknown, 'a non-digit square');
   CheckEquals('', PossibleStatesComment('JO22'), 'no comment for an unknown grid');
   CheckEquals('', PossibleStatesComment('EL87'), 'no comment for a unique grid');
end;

procedure TGridLookupTests.Test_CaseAndSixCharacterGrids;
var
   state: string;
begin
   BeginTest('Test_CaseAndSixCharacterGrids');
   CheckTrue(StateOfGrid('el87', state) = gskUnique, 'lower case');
   CheckEquals('FL', state, 'el87');
   CheckTrue(StateOfGrid('EL87qu', state) = gskUnique, '6 characters, lower-case subsquare');
   CheckEquals('FL', state, 'EL87qu');
   CheckTrue(StateOfGrid('EL87QU12', state) = gskUnique, '8 characters');
   CheckTrue(StateOfGrid(' EL87 ', state) = gskUnique, 'surrounding blanks');
   CheckTrue(StateOfGrid('en61ab', state) = gskAmbiguous, '6 characters ambiguous');
end;

procedure TGridLookupTests.Test_PossibleStatesComment;
begin
   BeginTest('Test_PossibleStatesComment');
   CheckEquals('possible states for DM07 are CA and NV',
               PossibleStatesComment('DM07'), 'two states');
   CheckEquals('possible states for EN61 are IL, IN and MI',
               PossibleStatesComment('en61'), 'three states, grid shown upper case');
   CheckEquals('possible states for EN61 are IL, IN and MI',
               PossibleStatesComment('EN61ab'), 'a 6-character grid shows the 4');
end;

procedure TGridLookupTests.Test_ReturnStatesForGrid;
var
   lookup: TGridLookup;
   states: TStringList;
begin
   BeginTest('Test_ReturnStatesForGrid');
   lookup := TGridLookup.Create;
   states := TStringList.Create;
   try
      CheckTrue(lookup.ReturnStatesForGrid('DM07', states), 'found');
      CheckEquals(2, states.Count, 'two candidates');
      CheckEquals('CA', states[0], 'table order');
      CheckEquals('NV', states[1], 'table order');
      states.Clear;
      CheckFalse(lookup.ReturnStatesForGrid('JO22', states), 'unknown answers False');
      CheckEquals(0, states.Count, 'and appends nothing');
   finally
      states.Free;
      lookup.Free;
   end;
end;

procedure TGridLookupTests.Test_OwnLifetime;
var
   lookup: TGridLookup;
   state: string;
begin
   BeginTest('Test_OwnLifetime');
   (* The prototype's constructor was private and its destructor freed one past
      the end. A public create, a use and a free is the whole check; the
      checked build (heaptrc) is what would show an overrun. *)
   lookup := TGridLookup.Create;
   try
      CheckEquals(695, lookup.GridCount, 'a fresh table');
      lookup.AddStateToGrid('EL87', 'FL');
      CheckEquals(695, lookup.GridCount, 'a repeat adds nothing');
      lookup.AddStateToGrid('EL87', 'GA');
      CheckTrue(lookup.StateKindOfGrid('EL87', state) = gskAmbiguous,
                'a second state makes it ambiguous');
   finally
      lookup.Free;
   end;
end;

procedure TGridLookupTests.RunAllTests;
begin
   Test_TheTableHoldsEveryGrid;
   Test_UniqueGrids;
   Test_AmbiguousGridsInferNothing;
   Test_UnknownAndMalformedGrids;
   Test_CaseAndSixCharacterGrids;
   Test_PossibleStatesComment;
   Test_ReturnStatesForGrid;
   Test_OwnLifetime;
end;

end.

unit uTestGridLookup;
{$I ..\..\src\tr4w.inc}

(*
   A GRID NAMES A STATE ONLY WHEN IT LIES IN ONE (issue 52).

   The table is the ARRL's vuccgrids.dat (version 1.6, 2026-03-27, as shipped
   with TrustedQSL), generated into uGridStateTable.inc by
   tools/grids/gen_grid_state_table.py: 1844 grids that reach a state or a
   province. The file lists every subdivision a grid TOUCHES, so a border grid
   is ambiguous. A grid is judged per DXCC entity (CN88 is WA for 291 and BC
   for 1); the entity-less StateOfGrid is the conservative form (a state only
   when the grid has one subdivision across ALL entities). NO state is inferred
   for an ambiguous grid and the candidates are worded for the operator
   (NY4I: 'possible states for EN61 are ...').
   Expected values are read from vuccgrids.dat, not from the code.

   UNRUN when written: the sandbox that wrote it was told not to run the unit
   suite.
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
      procedure Test_PerEntityRule;
      procedure Test_CanadianCodesAreADIFs;
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
   CheckEquals(1844, GRID_STATE_TABLE_COUNT, 'vuccgrids.dat 1.6 has 1844 grids with a subdivision');
   CheckEquals(1844, GridLookupShared.GridCount, 'every one loaded, none merged');
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
   CheckTrue(StateOfGrid('DM78', state) = gskUnique, 'DM78 is Colorado only');
   CheckEquals('CO', state, 'DM78');
   CheckTrue(StateOfGrid('BP51', state) = gskUnique, 'BP51 is Alaska only');
   CheckEquals('AK', state, 'BP51');
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
   CheckTrue(StateOfGrid('DM37', state) = gskAmbiguous,
             'DM37 is AZ and UT: the file lists the edge Arizona touches');
   (* THE ENTITY-LESS FORM IS CONSERVATIVE: CN88 is WA for the USA and BC for
      Canada, so with no call to say which, it is ambiguous. *)
   CheckTrue(StateOfGrid('CN88', state) = gskAmbiguous, 'CN88 is WA and BC');
   CheckEquals('', state, 'CN88 infers nothing without a country');
   CheckTrue(StateOfGrid('FN35', state) = gskAmbiguous, 'FN35 is NY, VT and QC');
end;

procedure TGridLookupTests.Test_UnknownAndMalformedGrids;
var
   state: string;
begin
   BeginTest('Test_UnknownAndMalformedGrids');
   CheckTrue(StateOfGrid('JO22', state) = gskUnknown, 'a grid outside the table');
   CheckEquals('', state, 'unknown');
   CheckTrue(StateOfGrid('AP79', state) = gskUnknown, 'AP79 is not in vuccgrids.dat');
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
   CheckTrue(StateOfGridForEntity('cn88ab', GRID_ENTITY_CANADA, state) = gskUnique,
             '6 characters, per entity');
   CheckEquals('BC', state, 'cn88ab for Canada');
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
   CheckEquals('possible states for CN88 are WA and BC',
               PossibleStatesComment('CN88'), 'every entity''s, the USA first');
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

(* The rule the ADIF export applies, entity by entity. *)
procedure TGridLookupTests.Test_PerEntityRule;
var
   state: string;
begin
   BeginTest('Test_PerEntityRule');
   CheckTrue(StateOfGridForEntity('CN88', GRID_ENTITY_USA, state) = gskUnique,
             'CN88 for the USA');
   CheckEquals('WA', state, 'CN88 for the USA');
   CheckTrue(StateOfGridForEntity('CN88', GRID_ENTITY_CANADA, state) = gskUnique,
             'CN88 for Canada');
   CheckEquals('BC', state, 'CN88 for Canada');
   CheckTrue(StateOfGridForEntity('CN78', GRID_ENTITY_USA, state) = gskUnique,
             'CN78 for the USA');
   CheckEquals('WA', state, 'CN78 for the USA');
   CheckTrue(StateOfGridForEntity('CN81', GRID_ENTITY_USA, state) = gskAmbiguous,
             'CN81 is CA and OR');
   CheckEquals('', state, 'CN81 infers nothing');
   CheckTrue(StateOfGridForEntity('DM37', GRID_ENTITY_USA, state) = gskAmbiguous,
             'DM37 is AZ and UT');
   CheckTrue(StateOfGridForEntity('DM78', GRID_ENTITY_USA, state) = gskUnique,
             'DM78 for the USA');
   CheckEquals('CO', state, 'DM78');
   CheckTrue(StateOfGridForEntity('EN29', GRID_ENTITY_USA, state) = gskUnique,
             'EN29 for the USA is Minnesota only');
   CheckEquals('MN', state, 'EN29 for the USA');
   CheckTrue(StateOfGridForEntity('EN29', GRID_ENTITY_CANADA, state) = gskAmbiguous,
             'EN29 for Canada is MB and ON');
   CheckEquals('', state, 'EN29 for Canada infers nothing');
   CheckTrue(StateOfGridForEntity('DM78', GRID_ENTITY_CANADA, state) = gskUnknown,
             'a Canadian call has no province in a US-only grid');
   CheckTrue(StateOfGridForEntity('BL11', GRID_ENTITY_HAWAII, state) = gskUnique,
             'BL11 is Hawaii');
   CheckEquals('HI', state, 'BL11');
   CheckTrue(StateOfGridForEntity('BP51', GRID_ENTITY_ALASKA, state) = gskUnique,
             'BP51 is Alaska');
   CheckEquals('AK', state, 'BP51');
   CheckTrue(StateOfGridForEntity('BL11', GRID_ENTITY_USA, state) = gskUnknown,
             'Hawaii is not a 291 subdivision');
   CheckTrue(StateOfGridForEntity('DM78', 223, state) = gskUnknown,
             'an entity with no list (England) names nothing');
   CheckTrue(StateOfGridForEntity('DL88', 50, state) = gskUnknown,
             'Mexico shares DL88 with Texas and has no subdivision list');
   CheckTrue(StateOfGridForEntity('DL88', GRID_ENTITY_USA, state) = gskUnique,
             'DL88 for the USA is Texas');
   CheckEquals('TX', state, 'DL88');
   CheckTrue(StateOfGridForEntity('JO22', GRID_ENTITY_USA, state) = gskUnknown,
             'a grid the table lacks');
   CheckTrue(StateOfGridForEntity('XX', GRID_ENTITY_USA, state) = gskUnknown,
             'not a grid');
end;

(* vuccgrids.dat spells two Canadian provinces with their pre-ADIF codes; the
   generator writes ADIF's NL and QC. *)
procedure TGridLookupTests.Test_CanadianCodesAreADIFs;
var
   state: string;
begin
   BeginTest('Test_CanadianCodesAreADIFs');
   CheckTrue(StateOfGridForEntity('GN29', GRID_ENTITY_CANADA, state) = gskUnique,
             'GN29 is Newfoundland and Labrador only');
   CheckEquals('NL', state, 'NF is written NL');
   CheckTrue(StateOfGridForEntity('FO10', GRID_ENTITY_CANADA, state) = gskUnique,
             'FO10 is Quebec only');
   CheckEquals('QC', state, 'PQ is written QC');
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
      CheckEquals(1844, lookup.GridCount, 'a fresh table');
      lookup.AddStateToGrid('EL87', GRID_ENTITY_USA, 'FL');
      CheckEquals(1844, lookup.GridCount, 'a repeat adds nothing');
      lookup.AddStateToGrid('EL87', GRID_ENTITY_USA, 'GA');
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
   Test_PerEntityRule;
   Test_CanadianCodesAreADIFs;
   Test_OwnLifetime;
end;

end.

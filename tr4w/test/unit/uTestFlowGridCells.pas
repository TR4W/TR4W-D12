unit uTestFlowGridCells;
{$I ..\..\src\tr4w.inc}

(*
  THE FLOW GRIDS: EACH CELL KEEPS WHAT IT MEANS (pointer audit P9, item 5.1).

  TFlowGrid (uFlowGrid) is the model behind three windows -- the dupe sheet,
  the Super Check Partial window and the remaining-multiplier windows. Each
  cell carried ONE PtrInt in Objects[], meaning a different thing per window:
  a district digit, a "this is a dupe" flag, and a (kind, index) pair packed
  into two 16-bit halves. That is WIN32_ARTIFACT_SWEEP.md's worked example.

  ONE WINDOW AT A TIME, one commit each. Every window's test drives that
  form's own pair -- what its builder calls to add a cell and what its paint
  handler calls to read one back -- and was written against the PtrInt
  encoding and run green there before the cell became a typed object.

  REAL FORMS, streamed and never shown. A TFlowGrid needs no window handle:
  its model is a list, and layout reads the grid's designed size.

  The -Checked run is part of the oracle here: a typed cell is an object the
  grid owns, and heaptrc's unfreed-block ceiling is what says a rebuild frees
  the cells it replaces.
*)

interface

uses
   SysUtils, uTR4WTestFramework;

type
   TFlowGridCellTests = class(TTestCase)
   protected
      procedure Test_DupeSheet_EveryCallKeepsItsDistrict;
      procedure Test_DupeSheet_ARebuildReplacesTheCells;
      procedure Test_DupeSheet_ACellPastTheEndHasNoDistrict;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,             (* Application *)
   uDupeSheetForm;

procedure InitWidgetSet;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

(* ----------------------------------------------------------------------- *)
(* The dupe sheet: a call and its district digit.                          *)
(* ----------------------------------------------------------------------- *)

const
   DUPE_CALLS: array[0..4] of string = ('W1AW', 'K3LR', 'N6TV', 'VE3XYZ', 'W0AIH');
   DUPE_DISTRICTS: array[0..4] of AnsiChar = ('1', '3', '6', '3', '0');

procedure FillDupeSheet(const aForm: TfrmDupeSheet);
var
   i: integer;
begin
   aForm.Calls.BeginRebuild;
   for i := Low(DUPE_CALLS) to High(DUPE_CALLS) do
      begin
      aForm.AddCall(DUPE_CALLS[i], DUPE_DISTRICTS[i]);
      end;
   aForm.Calls.EndRebuild;
end;

procedure TFlowGridCellTests.Test_DupeSheet_EveryCallKeepsItsDistrict;
var
   f: TfrmDupeSheet;
   i: integer;
begin
   BeginTest('Dupe sheet: every call comes back with the district it was added with');
   InitWidgetSet;
   f := TfrmDupeSheet.Create(nil);
   try
      FillDupeSheet(f);
      CheckEquals(Length(DUPE_CALLS), f.Calls.Count, 'cell count');
      for i := Low(DUPE_CALLS) to High(DUPE_CALLS) do
         begin
         CheckEquals(DUPE_CALLS[i], f.Calls.TextAt(i), 'call ' + IntToStr(i));
         CheckEquals(string(DUPE_DISTRICTS[i]), string(f.DistrictAt(i)),
                     'district of ' + DUPE_CALLS[i]);
         end;
   finally
      f.Free;
   end;
end;

procedure TFlowGridCellTests.Test_DupeSheet_ARebuildReplacesTheCells;
var
   f: TfrmDupeSheet;
begin
   BeginTest('Dupe sheet: a rebuild (a band change) replaces every cell');
   InitWidgetSet;
   f := TfrmDupeSheet.Create(nil);
   try
      FillDupeSheet(f);
      f.Calls.BeginRebuild;
      f.AddCall('JA1ABC', '1');
      f.AddCall('KH6XX', '6');
      f.Calls.EndRebuild;
      CheckEquals(2, f.Calls.Count, 'cell count after rebuild');
      CheckEquals('JA1ABC', f.Calls.TextAt(0), 'call 0');
      CheckEquals('1', string(f.DistrictAt(0)), 'district 0');
      CheckEquals('KH6XX', f.Calls.TextAt(1), 'call 1');
      CheckEquals('6', string(f.DistrictAt(1)), 'district 1');

      (* And an empty rebuild -- the sheet for a band with nothing worked. *)
      f.Calls.BeginRebuild;
      f.Calls.EndRebuild;
      CheckEquals(0, f.Calls.Count, 'cell count after an empty rebuild');
   finally
      f.Free;
   end;
end;

(* The paint handler asks for every cell of the grid, and the last column is
  rarely full. A cell past the end must answer the "no district" the handler
  falls back from -- never a neighbour's. *)
procedure TFlowGridCellTests.Test_DupeSheet_ACellPastTheEndHasNoDistrict;
var
   f: TfrmDupeSheet;
begin
   BeginTest('Dupe sheet: a cell past the end has no district');
   InitWidgetSet;
   f := TfrmDupeSheet.Create(nil);
   try
      FillDupeSheet(f);
      CheckEquals(Ord(#0), Ord(f.DistrictAt(Length(DUPE_CALLS))), 'one past the end');
      CheckEquals(Ord(#0), Ord(f.DistrictAt(-1)), 'index -1');
   finally
      f.Free;
   end;
end;

procedure TFlowGridCellTests.RunAllTests;
begin
   Test_DupeSheet_EveryCallKeepsItsDistrict;
   Test_DupeSheet_ARebuildReplacesTheCells;
   Test_DupeSheet_ACellPastTheEndHasNoDistrict;
end;

end.

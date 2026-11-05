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
   SysUtils, VC, uTR4WTestFramework;

type
   TFlowGridCellTests = class(TTestCase)
   protected
      procedure Test_DupeSheet_EveryCallKeepsItsDistrict;
      procedure Test_DupeSheet_ARebuildReplacesTheCells;
      procedure Test_DupeSheet_ACellPastTheEndHasNoDistrict;
      procedure Test_SCP_EveryCallKeepsItsDupeFlag;
      procedure Test_SCP_ACallPastCapacityIsRefused;
      procedure Test_RemMults_EveryCellKeepsItsKindAndIndex;
      procedure Test_RemMults_ARebuildReplacesTheCells;
      procedure Test_RemMults_ACellPastTheEndIsNotAMultiplier;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,             (* Application *)
   uDupeSheetForm,
   uMasterForm,
   uRemMultsForm;

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

(* ----------------------------------------------------------------------- *)
(* The Super Check Partial window: a call and whether it is a dupe.       *)
(* ----------------------------------------------------------------------- *)

const
   SCP_CALLS: array[0..4] of string = ('K1AR', 'K1ZZ', 'K1TO', 'K1EA', 'K1DG');
   SCP_DUPES: array[0..4] of boolean = (True, False, False, True, False);

procedure TFlowGridCellTests.Test_SCP_EveryCallKeepsItsDupeFlag;
var
   f: TfrmMaster;
   i: integer;
begin
   BeginTest('SCP window: every call comes back with the dupe flag it was added with');
   InitWidgetSet;
   f := TfrmMaster.Create(nil);
   try
      f.Calls.BeginRebuild;
      for i := Low(SCP_CALLS) to High(SCP_CALLS) do
         begin
         CheckTrue(f.AddCall(SCP_CALLS[i], SCP_DUPES[i]), 'added ' + SCP_CALLS[i]);
         end;
      f.Calls.EndRebuild;

      CheckEquals(Length(SCP_CALLS), f.Calls.Count, 'cell count');
      for i := Low(SCP_CALLS) to High(SCP_CALLS) do
         begin
         CheckEquals(SCP_CALLS[i], f.Calls.TextAt(i), 'call ' + IntToStr(i));
         CheckTrue(SCP_DUPES[i] = f.IsDupeAt(i), 'dupe flag of ' + SCP_CALLS[i]);
         end;
      CheckFalse(f.IsDupeAt(Length(SCP_CALLS)), 'a cell past the end is not a dupe');
      CheckFalse(f.IsDupeAt(-1), 'index -1 is not a dupe');
   finally
      f.Free;
   end;
end;

(* THE SCP WINDOW SHOWS ONLY WHAT FITS (LimitToVisible). A call it refuses must
  leave the cells already there as they were -- and, under -Checked, must not
  leak the cell the grid was handed. *)
procedure TFlowGridCellTests.Test_SCP_ACallPastCapacityIsRefused;
var
   f: TfrmMaster;
   i, cap: integer;
begin
   BeginTest('SCP window: a call past what fits is refused and the rest are kept');
   InitWidgetSet;
   f := TfrmMaster.Create(nil);
   try
      cap := f.Calls.Capacity;
      CheckTrue(cap > 0, 'the designed window shows no cells');
      f.Calls.BeginRebuild;
      for i := 0 to cap - 1 do
         begin
         CheckTrue(f.AddCall('W' + IntToStr(i), Odd(i)), 'cell ' + IntToStr(i) + ' fits');
         end;
      CheckFalse(f.AddCall('OVERFLOW', True), 'a call past capacity was added');
      CheckFalse(f.AddCall('OVERFLOW2', False), 'a second call past capacity was added');
      f.Calls.EndRebuild;

      CheckEquals(cap, f.Calls.Count, 'cell count');
      for i := 0 to cap - 1 do
         begin
         CheckEquals('W' + IntToStr(i), f.Calls.TextAt(i), 'call ' + IntToStr(i));
         CheckTrue(Odd(i) = f.IsDupeAt(i), 'dupe flag ' + IntToStr(i));
         end;
   finally
      f.Free;
   end;
end;

(* ----------------------------------------------------------------------- *)
(* The remaining-multiplier windows: a multiplier's KIND and its INDEX.    *)
(* ----------------------------------------------------------------------- *)

const
   (* Every kind appears, two cells share an index under different kinds, and
     the indices reach past 255 (a DXCC entity) and past 1,000 (a prefix
     list). *)
   RM_KINDS: array[0..5] of RemainingMultiplierType =
      (rmDX, rmDX, rmZone, rmDomestic, rmPrefix, rmZone);
   RM_INDEXES: array[0..5] of integer = (0, 338, 40, 12, 1234, 0);

procedure FillRemMults(const aForm: TfrmRemMults);
var
   i: integer;
begin
   aForm.Mults.BeginRebuild;
   for i := Low(RM_KINDS) to High(RM_KINDS) do
      begin
      aForm.AddMult(RM_KINDS[i], RM_INDEXES[i]);
      end;
   aForm.Mults.EndRebuild;
end;

procedure TFlowGridCellTests.Test_RemMults_EveryCellKeepsItsKindAndIndex;
var
   f: TfrmRemMults;
   i, index: integer;
   kind: RemainingMultiplierType;
begin
   BeginTest('Remaining mults: every cell comes back with the kind and index it was added with');
   InitWidgetSet;
   f := TfrmRemMults.Create(nil);
   try
      FillRemMults(f);
      CheckEquals(Length(RM_KINDS), f.Mults.Count, 'cell count');
      for i := Low(RM_KINDS) to High(RM_KINDS) do
         begin
         CheckTrue(f.MultAt(i, kind, index), 'cell ' + IntToStr(i) + ' found');
         CheckEquals(Ord(RM_KINDS[i]), Ord(kind), 'kind of cell ' + IntToStr(i));
         CheckEquals(RM_INDEXES[i], index, 'index of cell ' + IntToStr(i));
         end;
   finally
      f.Free;
   end;
end;

procedure TFlowGridCellTests.Test_RemMults_ARebuildReplacesTheCells;
var
   f: TfrmRemMults;
   index: integer;
   kind: RemainingMultiplierType;
begin
   BeginTest('Remaining mults: a rebuild (a band change) replaces every cell');
   InitWidgetSet;
   f := TfrmRemMults.Create(nil);
   try
      FillRemMults(f);
      f.Mults.BeginRebuild;
      f.AddMult(rmPrefix, 7);
      f.Mults.EndRebuild;
      CheckEquals(1, f.Mults.Count, 'cell count after rebuild');
      CheckTrue(f.MultAt(0, kind, index), 'cell 0 found');
      CheckEquals(Ord(rmPrefix), Ord(kind), 'kind after rebuild');
      CheckEquals(7, index, 'index after rebuild');
   finally
      f.Free;
   end;
end;

procedure TFlowGridCellTests.Test_RemMults_ACellPastTheEndIsNotAMultiplier;
var
   f: TfrmRemMults;
   index: integer;
   kind: RemainingMultiplierType;
begin
   BeginTest('Remaining mults: a cell past the end is not a multiplier');
   InitWidgetSet;
   f := TfrmRemMults.Create(nil);
   try
      FillRemMults(f);
      CheckFalse(f.MultAt(Length(RM_KINDS), kind, index), 'one past the end');
      CheckFalse(f.MultAt(-1, kind, index), 'index -1');
   finally
      f.Free;
   end;
end;

procedure TFlowGridCellTests.RunAllTests;
begin
   Test_RemMults_EveryCellKeepsItsKindAndIndex;
   Test_RemMults_ARebuildReplacesTheCells;
   Test_RemMults_ACellPastTheEndIsNotAMultiplier;
   Test_DupeSheet_EveryCallKeepsItsDistrict;
   Test_DupeSheet_ARebuildReplacesTheCells;
   Test_DupeSheet_ACellPastTheEndHasNoDistrict;
   Test_SCP_EveryCallKeepsItsDupeFlag;
   Test_SCP_ACallPastCapacityIsRefused;
end;

end.

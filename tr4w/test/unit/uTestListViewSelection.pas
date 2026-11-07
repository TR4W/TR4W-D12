unit uTestListViewSelection;
{$I ..\..\src\tr4w.inc}

(*
  A WINDOW THAT OPENS ON A ROW SHOWS THAT ROW SELECTED -- ON EVERY WIDGET SET.

  The Alt-P window opens on the message last edited, and the Stations window
  selects the callsign it has just updated. Both select through
  uLCLFormHelpers.SelectListViewRow, which exists because a TListView
  selection written before the list has a window is lost on gtk2 (measured
  on the Linux CI runner, 2026-11-07; the raw LCL behaviour is pinned in
  uTestAltPRows). These tests say what the PROGRAM does, so they carry no
  platform switch: the Linux runner is where they prove something.

  WHAT THEY READ IS THE WINDOW, NOT THE LCL'S CACHE. TCustomListView keeps
  the selected item in a private field, and ItemIndex answers from it once it
  is marked valid -- whatever the widget shows. TListItem.Selected, with a
  handle, asks the widget set (listitem.inc, GetState -> ItemGetState), so
  that is the check; the key or row read back through the seam is the
  identity check beside it.

  REAL FORMS, STREAMED FROM THEIR .lfm AND SHOWN OFF SCREEN, in the order the
  program uses: Alt-P fills and selects in its own OnShow, through uAltP's
  real fill; Stations is showing before a row is selected.
*)

interface

uses
   SysUtils, uTR4WTestFramework;

type
   TListViewSelectionTests = class(TTestCase)
   private
      procedure CheckAltPWindowSelects(const aKey: integer; const aWhat: string);
   protected
      procedure Test_AltPOpensWithTheRememberedKeySelectedInTheWindow;
      procedure Test_AltPReopenedSelectsTheNewKeyInTheWindow;
      procedure Test_AltPSelectionMadeBeforeTheWindowReachesIt;
      procedure Test_StationsSelectsTheRowInTheWindow;
      procedure Test_TheLCLKeepsAListBoxIndexWrittenBeforeTheHandle;
      procedure Test_TheLCLKeepsAComboIndexWrittenBeforeTheHandle;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,               (* Application *)
   ComCtrls,            (* TCustomListView, TListItem *)
   StdCtrls,            (* TListBox, TComboBox -- the LCL probes *)
   VC,                  (* MesWindow, CQMsgWin *)
   uAltP,               (* LastSelectedMessage; wires AltPFormOnFill *)
   uAltPForm,
   uStationsForm,
   uTestShowOffScreen;

(* How many rows the WIDGET says are selected, and the first one. *)
function WindowSelection(const aView: TCustomListView; out aFirst: integer): integer;
var
   i: integer;
begin
   Result := 0;
   aFirst := -1;
   for i := 0 to aView.Items.Count - 1 do
      begin
      if aView.Items[i].Selected then
         begin
         Inc(Result);
         if aFirst < 0 then
            begin
            aFirst := i;
            end;
         end;
      end;
end;

procedure InitialiseWidgetSet;
begin
   (* The widget set registers its window classes here; a handle asked for
     before it fails with "Cannot find window class". Repeat calls are
     harmless. *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;
end;

(* The Alt-P window as ShowAltP opens it -- the CQ window, the standard bank,
  opening on aKey -- but shown without a modal loop. *)
procedure OpenAltP(const aKey: integer);
begin
   MesWindow := CQMsgWin;
   LastSelectedMessage := aKey;
   if TR4WAltPForm = nil then
      begin
      TR4WAltPForm := TfrmAltP.Create(nil);
      end;
   ShowOffScreen(TR4WAltPForm);
end;

procedure TListViewSelectionTests.CheckAltPWindowSelects(const aKey: integer;
                                                         const aWhat: string);
var
   lv   : TListView;
   first: integer;
begin
   lv := TR4WAltPForm.lvMessages;
   CheckTrue(lv.HandleAllocated, aWhat + ': the list has no window');
   CheckEquals(12, lv.Items.Count, aWhat + ': the standard bank is twelve rows');
   CheckEquals(1, WindowSelection(lv, first), aWhat + ': rows selected in the window');
   CheckEquals(aKey, first, aWhat + ': the window''s selected row');
   CheckEquals(aKey, AltPSelectedKey, aWhat + ': the key read back');
end;

procedure TListViewSelectionTests.Test_AltPOpensWithTheRememberedKeySelectedInTheWindow;
var
   savedWindow: MesWindowType;
   savedKey   : integer;
begin
   BeginTest('Alt-P: the window opens with the remembered key selected in it');
   InitialiseWidgetSet;
   savedWindow := MesWindow;
   savedKey    := LastSelectedMessage;
   try
      OpenAltP(5);          (* F6: row 5 of the standard bank *)
      CheckAltPWindowSelects(5, 'first open');
   finally
      FreeAndNil(TR4WAltPForm);
      MesWindow           := savedWindow;
      LastSelectedMessage := savedKey;
   end;
end;

(* The form is reused (ShowAltPWindow keeps it), so a second open refills a
  list that already has a window and a selection cached from the first. *)
procedure TListViewSelectionTests.Test_AltPReopenedSelectsTheNewKeyInTheWindow;
var
   savedWindow: MesWindowType;
   savedKey   : integer;
begin
   BeginTest('Alt-P: a reopened window selects the new key in it');
   InitialiseWidgetSet;
   savedWindow := MesWindow;
   savedKey    := LastSelectedMessage;
   try
      OpenAltP(5);
      TR4WAltPForm.Hide;
      Application.ProcessMessages;
      OpenAltP(9);          (* F10 *)
      CheckAltPWindowSelects(9, 'second open');
      TR4WAltPForm.Hide;
      Application.ProcessMessages;
      OpenAltP(5);          (* back to a row the cache once held *)
      CheckAltPWindowSelects(5, 'third open');
   finally
      FreeAndNil(TR4WAltPForm);
      MesWindow           := savedWindow;
      LastSelectedMessage := savedKey;
   end;
end;

(* The seam promises a selection whenever it is called, not only from OnShow:
  rows added and a key selected while the form has never been shown are in
  the window once it is. This is the order the raw-LCL pin shows gtk2
  losing. *)
procedure TListViewSelectionTests.Test_AltPSelectionMadeBeforeTheWindowReachesIt;
const
   ROW_COMMANDS: array[0..3] of AnsiString = ('cmd0', 'cmd1', 'cmd2', 'cmd3');
var
   savedFill: procedure;
   lv       : TListView;
   first, i : integer;
begin
   BeginTest('Alt-P: a key selected before the window exists is selected in it');
   InitialiseWidgetSet;
   savedFill := AltPFormOnFill;
   AltPFormOnFill := nil;   (* the rows below are the test's; no refill on show *)
   TR4WAltPForm := TfrmAltP.Create(nil);
   try
      lv := TR4WAltPForm.lvMessages;
      CheckFalse(lv.HandleAllocated, 'the list must start with no window');
      for i := 0 to 3 do
         begin
         AltPAddRow(ROW_COMMANDS[i], '', '', i);
         end;
      CheckTrue(AltPSelectByKey(2), 'key 2 found');
      ShowOffScreen(TR4WAltPForm);
      CheckEquals(1, WindowSelection(lv, first), 'rows selected in the window');
      CheckEquals(2, first, 'the window''s selected row');
      CheckEquals(2, AltPSelectedKey, 'the key read back');
   finally
      FreeAndNil(TR4WAltPForm);
      AltPFormOnFill := savedFill;
   end;
end;

(* Stations selects the callsign UpdateStationStatus just touched, while the
  window is open. Its rows are built by uStations from the contest when it
  shows; the test builds its own through the same view seam instead, so it
  depends on no contest state. *)
procedure TListViewSelectionTests.Test_StationsSelectsTheRowInTheWindow;
var
   savedShow: procedure;
   savedForm: TfrmStations;
   lv       : TListView;
   first    : integer;
begin
   BeginTest('Stations: the selected callsign is selected in the window');
   InitialiseWidgetSet;
   savedShow := StationsOnShow;
   savedForm := TR4WStationsForm;
   StationsOnShow := nil;
   TR4WStationsForm := TfrmStations.Create(nil);
   try
      ShowOffScreen(TR4WStationsForm);
      lv := TR4WStationsForm.lvStations;
      CheckTrue(lv.HandleAllocated, 'the shown list has no window');

      StationsBeginUpdate;
      try
         StationsAddColumn('Call', 75, False);
         StationsAddColumn('20', 36, True);
         StationsInsertRow(0, 'K1AR');
         StationsInsertRow(1, 'N2IC');
         StationsInsertRow(2, 'W9RE');
      finally
         StationsEndUpdate;
      end;

      StationsSelectAndShow(1);
      CheckEquals(1, WindowSelection(lv, first), 'rows selected in the window');
      CheckEquals(1, first, 'the window''s selected row');

      StationsSelectAndShow(2);
      CheckEquals(1, WindowSelection(lv, first), 'rows selected after a move');
      CheckEquals(2, first, 'the selection moved to row 2');

      StationsSelectAndShow(2);   (* the same row again: still selected *)
      CheckEquals(1, WindowSelection(lv, first), 'rows selected after a repeat');
      CheckEquals(2, first, 'a repeated selection is kept');
   finally
      TR4WStationsForm.Free;
      TR4WStationsForm := savedForm;
      StationsOnShow   := savedShow;
   end;
end;

(* THE OTHER TWO LIST CONTROLS, PROBED (2026-11-07). TR4W writes ItemIndex on
  many a TListBox and TComboBox before its form shows -- every Preferences
  page does. The LCL keeps that write in FItemIndex and InitializeWnd pushes
  it to the widget set (customlistbox.inc, customcombobox.inc), which is the
  same shape as the list view's re-apply that gtk2 loses. So it is measured,
  not assumed: with a handle, both GetItemIndex implementations ASK THE
  WIDGET SET (customlistbox.inc 643-650, customcombobox.inc 1022-1027), so
  the read below is the window's answer. No platform switch: if one fails on
  a widget set, that is the finding -- every pre-show write of that control
  is affected there and needs its own fix. *)
procedure TListViewSelectionTests.Test_TheLCLKeepsAListBoxIndexWrittenBeforeTheHandle;
var
   host: TForm;
   lb  : TListBox;
begin
   BeginTest('LCL: a list box index written before the handle is in the window');
   InitialiseWidgetSet;
   host := TForm.CreateNew(nil);
   try
      lb        := TListBox.Create(host);
      lb.Parent := host;
      lb.Items.Add('row0');
      lb.Items.Add('row1');
      lb.Items.Add('row2');
      CheckFalse(lb.HandleAllocated, 'the probe must start with no window');
      lb.ItemIndex := 1;
      lb.HandleNeeded;
      CheckTrue(lb.HandleAllocated, 'the probe has no window');
      CheckEquals(1, lb.ItemIndex, 'the window lost the list box index');
   finally
      host.Free;
   end;
end;

procedure TListViewSelectionTests.Test_TheLCLKeepsAComboIndexWrittenBeforeTheHandle;
var
   host: TForm;
   cb  : TComboBox;
begin
   BeginTest('LCL: a drop-down index written before the handle is in the window');
   InitialiseWidgetSet;
   host := TForm.CreateNew(nil);
   try
      cb        := TComboBox.Create(host);
      cb.Parent := host;
      cb.Style  := csDropDownList;
      cb.Items.Add('row0');
      cb.Items.Add('row1');
      cb.Items.Add('row2');
      CheckFalse(cb.HandleAllocated, 'the probe must start with no window');
      cb.ItemIndex := 2;
      cb.HandleNeeded;
      CheckTrue(cb.HandleAllocated, 'the probe has no window');
      CheckEquals(2, cb.ItemIndex, 'the window lost the drop-down index');
   finally
      host.Free;
   end;
end;

procedure TListViewSelectionTests.RunAllTests;
begin
   Test_AltPOpensWithTheRememberedKeySelectedInTheWindow;
   Test_AltPReopenedSelectsTheNewKeyInTheWindow;
   Test_AltPSelectionMadeBeforeTheWindowReachesIt;
   Test_StationsSelectsTheRowInTheWindow;
   Test_TheLCLKeepsAListBoxIndexWrittenBeforeTheHandle;
   Test_TheLCLKeepsAComboIndexWrittenBeforeTheHandle;
end;

end.

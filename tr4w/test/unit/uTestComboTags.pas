unit uTestComboTags;
{$I ..\..\src\tr4w.inc}

(*
  Unit tests for the tag helpers in uLCLFormHelpers: AddComboItem,
  ClearComboItems, SelectByTag, SelectedTag, HasTag, the TListBox trio, and the
  shared fillers that use them.

  WHY A REAL CONTROL, AND NOT A MOCK.  Every defect in this area was the tag
  and its row disagreeing, so the thing under test is the control's own Items.
  Most of these build a real TComboBox with no owner and no parent -- the LCL
  keeps Items in a plain string list until a handle is allocated.  The
  WITH-HANDLE tests put the control on an off-screen form and give it a window,
  because then Items is the widget set's own list (on Win32 the tag rides as the
  item data), and that is the list the operator's window uses.

  THE DEFECT THESE EXIST FOR (2026-08-31).  A newly created station profile
  could not be selected: a raw cbxProfile.Clear emptied Items and left a SECOND
  tag list behind, so the rebuild appended on top of stale tags.  Since issue
  216 there is no second list -- each row carries its tag in its own Objects[]
  slot -- so the desync tests below no longer exercise a repair: they show that
  the desync cannot be made at all, by a clear, an insert, a delete, a reorder
  or a sort.
*)

interface

uses
   SysUtils, StdCtrls, Forms, uTR4WTestFramework;

type
   TComboTagTests = class(TTestCase)
   protected
      procedure Test_AddThenSelectByTag;
      procedure Test_TagIsIndependentOfDisplayText;
      procedure Test_SelectedTagFollowsItemIndex;
      procedure Test_HasTagFindsAndMisses;
      procedure Test_SelectByTagIsCaseInsensitive;
      procedure Test_AbsentTagFallsBackToFirstItem;
      procedure Test_ClearComboItemsClearsBoth;
      procedure Test_ClearComboItemsFreesEveryTag;

      // The desync cases -- see the header.
      procedure Test_RawItemsClearThenRefill_SelectsTheRightRow;
      procedure Test_StaleTagsAreDiscardedNotIndexed;
      procedure Test_ItemsFilledDirectlyGiveEmptyTagNotNeighbour;
      procedure Test_SelectByTagNeverExceedsItemCount;
      procedure Test_AReorderCarriesEachTagWithItsRow;
      procedure Test_SortingCarriesEachTagWithItsRow;
      procedure Test_AnInsertOrDeleteShiftsNoTag;

      // No filler can double a list on a refill (issue 237's shape).
      procedure Test_TheSharedFillersNeverDouble;

      procedure Test_ListBoxAddAndSelectedTag;
      procedure Test_ListBoxRawClearThenRefill;

      // The widget set's own list.
      procedure Test_WithHandle_ComboTagsSurviveTheHandleAndAReorder;
      procedure Test_WithHandle_ListBoxTextChangeKeepsTheTag;

   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uLCLFormHelpers;

// A combo with no owner and no parent.  Freed by every test that makes one.
function NewCombo: TComboBox;
begin
   Result      := TComboBox.Create(nil);
   Result.Name := 'cbxUnderTest';
end;

function NewList: TListBox;
begin
   Result      := TListBox.Create(nil);
   Result.Name := 'lstUnderTest';
end;

(* An off-screen form that never shows, for a control that needs a window.
  The widget set registers its window classes in Application.Initialize; a
  handle asked for before it fails with "Cannot find window class".  Repeat
  calls are harmless -- uTestAltPRows makes the same one. *)
function NewHostForm: TForm;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
   Result := TForm.CreateNew(nil);
   Result.SetBounds(-10000, -10000, 320, 240);
end;

// Three rows whose tags deliberately do NOT match their captions, so an
// implementation that quietly compares display text fails.
procedure FillThree(const aCombo: TComboBox);
begin
   AddComboItem(aCombo, 'Icom IC-7760',    'radio.ic7760');
   AddComboItem(aCombo, 'Elecraft K4',     'radio.k4');
   AddComboItem(aCombo, 'Yaesu FT-1000MP', 'radio.ft1000mp');
end;

(* How many rows carry this tag.  A refill that doubles shows here as 2. *)
function RowsCarrying(const aCombo: TComboBox; const aTag: string): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to aCombo.Items.Count - 1 do
      begin
      aCombo.ItemIndex := i;
      if SameText(SelectedTag(aCombo), aTag) then
         begin
         Inc(Result);
         end;
      end;
end;

// ---------------------------------------------------------------------------
// The straightforward round trips
// ---------------------------------------------------------------------------

procedure TComboTagTests.Test_AddThenSelectByTag;
var
   c: TComboBox;
begin
   BeginTest('SelectByTag selects the row carrying that tag');
   c := NewCombo;
   try
      FillThree(c);
      SelectByTag(c, 'radio.k4');
      CheckEquals(1, c.ItemIndex);
      CheckEquals('radio.k4', SelectedTag(c));
   finally
      c.Free;
   end;
end;

procedure TComboTagTests.Test_TagIsIndependentOfDisplayText;
var
   c: TComboBox;
begin
   BeginTest('A tag is matched, not the caption beside it');
   c := NewCombo;
   try
      FillThree(c);
      // The CAPTION of row 1, offered as a tag, must not match anything.
      SelectByTag(c, 'Elecraft K4');
      CheckEquals(0, c.ItemIndex, 'a caption matched as if it were a tag');
   finally
      c.Free;
   end;
end;

procedure TComboTagTests.Test_SelectedTagFollowsItemIndex;
var
   c: TComboBox;
begin
   BeginTest('SelectedTag reports the tag of the selected row');
   c := NewCombo;
   try
      FillThree(c);
      c.ItemIndex := 2;
      CheckEquals('radio.ft1000mp', SelectedTag(c));
      c.ItemIndex := -1;
      CheckEquals('', SelectedTag(c), 'no selection should give no tag');
   finally
      c.Free;
   end;
end;

procedure TComboTagTests.Test_HasTagFindsAndMisses;
var
   c: TComboBox;
begin
   BeginTest('HasTag answers for present and absent tags');
   c := NewCombo;
   try
      FillThree(c);
      CheckTrue(HasTag(c, 'radio.ic7760'));
      CheckFalse(HasTag(c, 'radio.ts590'));
   finally
      c.Free;
   end;
end;

procedure TComboTagTests.Test_SelectByTagIsCaseInsensitive;
var
   c: TComboBox;
begin
   BeginTest('Tag matching is case-insensitive, as Pascal identifiers are');
   c := NewCombo;
   try
      FillThree(c);
      SelectByTag(c, 'RADIO.K4');
      CheckEquals(1, c.ItemIndex);
   finally
      c.Free;
   end;
end;

procedure TComboTagTests.Test_AbsentTagFallsBackToFirstItem;
var
   c: TComboBox;
begin
   BeginTest('An unknown tag selects item 0 rather than leaving nothing');
   c := NewCombo;
   try
      FillThree(c);
      c.ItemIndex := 2;
      SelectByTag(c, 'radio.nothing-like-this');
      CheckEquals(0, c.ItemIndex);
   finally
      c.Free;
   end;
end;

procedure TComboTagTests.Test_ClearComboItemsClearsBoth;
var
   c: TComboBox;
begin
   BeginTest('ClearComboItems empties the tags as well as the items');
   c := NewCombo;
   try
      FillThree(c);
      ClearComboItems(c);
      CheckEquals(0, c.Items.Count);
      CheckFalse(HasTag(c, 'radio.k4'), 'a tag survived the clear');
   finally
      c.Free;
   end;
end;

(* The tags are components the combo owns, so a combo refilled all session
  must not collect them -- including ones a raw Clear left unreferenced. *)
procedure TComboTagTests.Test_ClearComboItemsFreesEveryTag;
var
   c: TComboBox;
   base: integer;
begin
   BeginTest('ClearComboItems frees every tag the combo owns, raw-cleared ones too');
   c := NewCombo;
   try
      (* Counted from what the combo owns before the fill, in case a widget
        set ever gives a combo a component of its own. *)
      base := c.ComponentCount;
      FillThree(c);
      CheckEquals(base + 3, c.ComponentCount, 'one tag per row');
      c.Items.Clear;                       // raw: leaves three unreferenced
      FillThree(c);
      ClearComboItems(c);
      CheckEquals(base, c.ComponentCount, 'tags left behind after the clear');
   finally
      c.Free;
   end;
end;

// ---------------------------------------------------------------------------
// The desync cases.  Each one goes behind the helpers on purpose.
// ---------------------------------------------------------------------------

(* THE SHIPPED DEFECT, REPRODUCED.  Empty the combo the way RefreshProfileCombo
  did -- Items only -- then rebuild it with one MORE row, and ask for the new
  row by tag.  With the old second list this found the new tag at index 6 of a
  4-row list. *)
procedure TComboTagTests.Test_RawItemsClearThenRefill_SelectsTheRightRow;
var
   c: TComboBox;
begin
   BeginTest('A raw Items.Clear before a refill still selects the right row');
   c := NewCombo;
   try
      FillThree(c);

      c.Items.Clear;                       // NOT ClearComboItems -- the defect
      FillThree(c);
      AddComboItem(c, 'Kenwood TS-590', 'radio.ts590');

      SelectByTag(c, 'radio.ts590');
      CheckEquals(3, c.ItemIndex, 'selected the wrong row after a raw Clear');
      CheckEquals('radio.ts590', SelectedTag(c));
   finally
      c.Free;
   end;
end;

(* A raw clear must leave nothing matchable from the previous fill. *)
procedure TComboTagTests.Test_StaleTagsAreDiscardedNotIndexed;
var
   c: TComboBox;
begin
   BeginTest('Tags from a previous fill are gone with their rows, not matched');
   c := NewCombo;
   try
      FillThree(c);
      c.Items.Clear;
      AddComboItem(c, 'Elecraft K4', 'radio.k4');

      CheckEquals(1, c.Items.Count);
      CheckFalse(HasTag(c, 'radio.ic7760'),
                 'a tag with no item behind it is still matchable');
      SelectByTag(c, 'radio.k4');
      CheckEquals(0, c.ItemIndex);
   finally
      c.Free;
   end;
end;

(* A row added straight to Items has no tag: it must report none -- NOT the
  tag of some other row. *)
procedure TComboTagTests.Test_ItemsFilledDirectlyGiveEmptyTagNotNeighbour;
var
   c: TComboBox;
begin
   BeginTest('A row added straight to Items has no tag, not a neighbour tag');
   c := NewCombo;
   try
      FillThree(c);
      c.Items.Add('Ten-Tec Orion');        // straight to Items, no tag

      c.ItemIndex := 3;
      CheckEquals('', SelectedTag(c), 'reported another row tag');

      // And the tagged rows still answer for themselves.
      SelectByTag(c, 'radio.ft1000mp');
      CheckEquals(2, c.ItemIndex);
   finally
      c.Free;
   end;
end;

(* The invariant stated as itself: SelectByTag must never leave ItemIndex
  outside the item list. *)
procedure TComboTagTests.Test_SelectByTagNeverExceedsItemCount;
var
   c: TComboBox;
begin
   BeginTest('SelectByTag never sets ItemIndex past the last item');
   c := NewCombo;
   try
      FillThree(c);
      c.Items.Clear;
      c.Items.Add('Only One');             // 1 untagged item

      SelectByTag(c, 'radio.ft1000mp');    // a tag of the previous fill
      CheckEquals(0, c.ItemIndex, 'the fallback is the first item');
   finally
      c.Free;
   end;
end;

(* The case a second list could never get right without hooking every
  mutation: the rows move and their tags must move with them. *)
procedure TComboTagTests.Test_AReorderCarriesEachTagWithItsRow;
var
   c: TComboBox;
begin
   BeginTest('Exchange and Move carry each tag with its row');
   c := NewCombo;
   try
      FillThree(c);
      c.Items.Exchange(0, 2);              // Yaesu, Elecraft, Icom
      SelectByTag(c, 'radio.ic7760');
      CheckEquals(2, c.ItemIndex, 'Icom after the exchange');
      CheckEquals('Icom IC-7760', string(c.Items[c.ItemIndex]));

      c.Items.Move(2, 0);                  // Icom, Yaesu, Elecraft
      SelectByTag(c, 'radio.k4');
      CheckEquals(2, c.ItemIndex, 'Elecraft after the move');
      CheckEquals('Elecraft K4', string(c.Items[c.ItemIndex]));
   finally
      c.Free;
   end;
end;

procedure TComboTagTests.Test_SortingCarriesEachTagWithItsRow;
var
   c: TComboBox;
begin
   BeginTest('Sorted := True carries each tag with its row');
   c := NewCombo;
   try
      FillThree(c);
      c.Sorted := True;                    // Elecraft, Icom, Yaesu
      CheckEquals('Elecraft K4', string(c.Items[0]), 'the list sorted');
      SelectByTag(c, 'radio.ic7760');
      CheckEquals(1, c.ItemIndex);
      c.ItemIndex := 0;
      CheckEquals('radio.k4', SelectedTag(c));
   finally
      c.Free;
   end;
end;

procedure TComboTagTests.Test_AnInsertOrDeleteShiftsNoTag;
var
   c: TComboBox;
begin
   BeginTest('An insert or delete leaves every row with its own tag');
   c := NewCombo;
   try
      FillThree(c);
      c.Items.Insert(0, 'Untagged');       // Untagged, Icom, Elecraft, Yaesu
      c.ItemIndex := 0;
      CheckEquals('', SelectedTag(c), 'the inserted row took a tag');
      SelectByTag(c, 'radio.k4');
      CheckEquals(2, c.ItemIndex, 'Elecraft after the insert');

      c.Items.Delete(1);                   // Untagged, Elecraft, Yaesu
      CheckFalse(HasTag(c, 'radio.ic7760'), 'the deleted row''s tag survived');
      SelectByTag(c, 'radio.ft1000mp');
      CheckEquals(2, c.ItemIndex, 'Yaesu after the delete');
   finally
      c.Free;
   end;
end;

(* Each shared filler, run twice, gives the same list: same count, each tag
  once.  Edit QSO doubled its Band and Mode lists on every reopen (issue 237);
  a filler here that appended instead of replacing would do the same to every
  serial-port, stop-bits and RTS/DTR drop-down. *)
procedure TComboTagTests.Test_TheSharedFillersNeverDouble;
var
   c: TComboBox;
   first, base: integer;
begin
   BeginTest('FillSerialPortCombo, FillStopBitsCombo, FillRTSDTRCombo never double');
   c := NewCombo;
   try
      base := c.ComponentCount;
      FillSerialPortCombo(c, nil);
      first := c.Items.Count;
      FillSerialPortCombo(c, nil);
      CheckEquals(first, c.Items.Count, 'serial ports doubled');
      CheckEquals(base + first, c.ComponentCount, 'serial ports: tags left behind');

      FillStopBitsCombo(c, 2);
      FillStopBitsCombo(c, 2);
      CheckEquals(3, c.Items.Count, 'stop bits doubled');
      CheckEquals(base + 3, c.ComponentCount, 'stop bits: tags left behind');
      CheckEquals(1, RowsCarrying(c, '2'), 'stop bits: tag 2 more than once');

      FillRTSDTRCombo(c, 'PTT');
      FillRTSDTRCombo(c, 'PTT');
      CheckEquals(5, c.Items.Count, 'RTS/DTR doubled');
      CheckEquals(base + 5, c.ComponentCount, 'RTS/DTR: tags left behind');
      CheckEquals(1, RowsCarrying(c, 'PTT'), 'RTS/DTR: tag PTT more than once');
   finally
      c.Free;
   end;
end;

// ---------------------------------------------------------------------------
// TListBox carries the same trio, so it gets the same two questions.
// ---------------------------------------------------------------------------

procedure TComboTagTests.Test_ListBoxAddAndSelectedTag;
var
   l: TListBox;
begin
   BeginTest('AddListItem / SelectedListTag round trip');
   l := NewList;
   try
      AddListItem(l, 'Radio 1', 'slot.1');
      AddListItem(l, 'Radio 2', 'slot.2');
      l.ItemIndex := 1;
      CheckEquals('slot.2', SelectedListTag(l));
   finally
      l.Free;
   end;
end;

procedure TComboTagTests.Test_ListBoxRawClearThenRefill;
var
   l: TListBox;
   base: integer;
begin
   BeginTest('A raw Items.Clear on a list box does not shift its tags');
   l := NewList;
   try
      base := l.ComponentCount;
      AddListItem(l, 'Radio 1', 'slot.1');
      AddListItem(l, 'Radio 2', 'slot.2');

      l.Items.Clear;                       // Items only
      AddListItem(l, 'Radio 9', 'slot.9');

      // With the old second list this returned 'slot.1' -- a DIFFERENT row's
      // tag, confidently, with no exception and no blank.
      l.ItemIndex := 0;
      CheckEquals('slot.9', SelectedListTag(l));

      ClearListItems(l);
      CheckEquals(0, l.Items.Count, 'ClearListItems left rows behind');
      CheckEquals(base, l.ComponentCount, 'ClearListItems left tags behind');
   finally
      l.Free;
   end;
end;

// ---------------------------------------------------------------------------
// With a window: the widget set's own list
// ---------------------------------------------------------------------------

(* Filled BEFORE the handle, so the tags cross the handoff from the LCL's
  string list into the widget set's (CreateWnd assigns the one to the other);
  then reordered and deleted ON the widget set's list. *)
procedure TComboTagTests.Test_WithHandle_ComboTagsSurviveTheHandleAndAReorder;
var
   f: TForm;
   c: TComboBox;
   base: integer;
begin
   BeginTest('With a window: combo tags survive the handle, a reorder and a delete');
   f := NewHostForm;
   try
      c        := TComboBox.Create(f);
      c.Name   := 'cbxUnderTest';
      c.Parent := f;
      FillThree(c);
      c.HandleNeeded;
      CheckTrue(c.HandleAllocated, 'the combo has no window');

      SelectByTag(c, 'radio.ft1000mp');
      CheckEquals(2, c.ItemIndex, 'Yaesu after the handle');

      c.Items.Exchange(0, 2);              // Yaesu, Elecraft, Icom
      SelectByTag(c, 'radio.ic7760');
      CheckEquals(2, c.ItemIndex, 'Icom after the exchange');

      c.Items.Delete(0);                   // Elecraft, Icom
      c.ItemIndex := 0;
      CheckEquals('radio.k4', SelectedTag(c), 'Elecraft after the delete');

      ClearComboItems(c);
      base := c.ComponentCount;
      FillThree(c);
      SelectByTag(c, 'radio.k4');
      CheckEquals(1, c.ItemIndex, 'Elecraft after a refill');
      CheckEquals(base + 3, c.ComponentCount, 'tags left behind by the refill');
   finally
      f.Free;
   end;
end;

(* SetListItemText rewrites a row in place; on Win32 that is a delete and an
  insert of the string, and the widget set carries the item data across. *)
procedure TComboTagTests.Test_WithHandle_ListBoxTextChangeKeepsTheTag;
var
   f: TForm;
   l: TListBox;
begin
   BeginTest('With a window: SetListItemText keeps the row''s tag');
   f := NewHostForm;
   try
      l        := TListBox.Create(f);
      l.Name   := 'lstUnderTest';
      l.Parent := f;
      AddListItem(l, 'Radio 1', 'slot.1');
      AddListItem(l, 'Radio 2', 'slot.2');
      l.HandleNeeded;
      CheckTrue(l.HandleAllocated, 'the list box has no window');
      AddListItem(l, 'Radio 3', 'slot.3');    // added ON the widget set's list

      SetListItemText(l, 1, 'Radio 2 (renamed)');
      CheckEquals('Radio 2 (renamed)', string(l.Items[1]), 'the text changed');
      l.ItemIndex := 1;
      CheckEquals('slot.2', SelectedListTag(l), 'the renamed row lost its tag');
      l.ItemIndex := 2;
      CheckEquals('slot.3', SelectedListTag(l), 'the row added with a handle');
   finally
      f.Free;
   end;
end;

// ---------------------------------------------------------------------------

procedure TComboTagTests.RunAllTests;
begin
   Test_AddThenSelectByTag;
   Test_TagIsIndependentOfDisplayText;
   Test_SelectedTagFollowsItemIndex;
   Test_HasTagFindsAndMisses;
   Test_SelectByTagIsCaseInsensitive;
   Test_AbsentTagFallsBackToFirstItem;
   Test_ClearComboItemsClearsBoth;
   Test_ClearComboItemsFreesEveryTag;

   Test_RawItemsClearThenRefill_SelectsTheRightRow;
   Test_StaleTagsAreDiscardedNotIndexed;
   Test_ItemsFilledDirectlyGiveEmptyTagNotNeighbour;
   Test_SelectByTagNeverExceedsItemCount;
   Test_AReorderCarriesEachTagWithItsRow;
   Test_SortingCarriesEachTagWithItsRow;
   Test_AnInsertOrDeleteShiftsNoTag;

   Test_TheSharedFillersNeverDouble;

   Test_ListBoxAddAndSelectedTag;
   Test_ListBoxRawClearThenRefill;

   Test_WithHandle_ComboTagsSurviveTheHandleAndAReorder;
   Test_WithHandle_ListBoxTextChangeKeepsTheTag;
end;

end.

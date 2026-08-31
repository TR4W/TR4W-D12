unit uTestComboTags;
{$I ..\..\src\tr4w.inc}

{
  Unit tests for the tag helpers in uLCLFormHelpers: AddComboItem,
  ClearComboItems, SelectByTag, SelectedTag, HasTag and the TListBox pair.

  WHY A REAL CONTROL, AND NOT A MOCK.  A combo's tag list is a SECOND object
  living beside Items, and every defect in this area is a disagreement between
  the two.  A mock of Items would be a mock of exactly the thing under test.
  These build a real TComboBox with no owner and no parent; the LCL keeps Items
  in a plain string list until a handle is allocated, so nothing needs a window.

  THE DEFECT THESE EXIST FOR (2026-08-31).  A newly created station profile
  could not be selected.  RefreshProfileCombo emptied the combo with a raw
  cbxProfile.Clear -- which clears Items and NOT the tags -- so the rebuild
  appended on top of the stale tags, and SelectByTag then matched the new name
  at an index past the end of the rebuilt item list.  Nothing raised and nothing
  was logged; the combo simply kept showing the previously active profile.

  So the cases that matter are the DESYNC ones, in both directions.  A test that
  only adds and selects through the helpers passes with or without the fix, and
  would have passed on the day the defect shipped.
}

interface

uses
   SysUtils, StdCtrls, uTR4WTestFramework;

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

      // The desync cases -- see the header.
      procedure Test_RawItemsClearThenRefill_SelectsTheRightRow;
      procedure Test_StaleTagsAreDiscardedNotIndexed;
      procedure Test_ItemsFilledDirectlyGiveEmptyTagNotNeighbour;
      procedure Test_SelectByTagNeverExceedsItemCount;

      procedure Test_ListBoxAddAndSelectedTag;
      procedure Test_ListBoxRawClearThenRefill;

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

// Three rows whose tags deliberately do NOT match their captions, so an
// implementation that quietly compares display text fails.
procedure FillThree(const aCombo: TComboBox);
begin
   AddComboItem(aCombo, 'Icom IC-7760',    'radio.ic7760');
   AddComboItem(aCombo, 'Elecraft K4',     'radio.k4');
   AddComboItem(aCombo, 'Yaesu FT-1000MP', 'radio.ft1000mp');
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

// ---------------------------------------------------------------------------
// The desync cases.  Each one goes behind the helpers on purpose.
// ---------------------------------------------------------------------------

{ THE SHIPPED DEFECT, REPRODUCED.  Empty the combo the way RefreshProfileCombo
  did -- Items only -- then rebuild it with one MORE row, and ask for the new
  row by tag.  With stale tags left in place the new tag is found at index 6 of
  a 4-row list; MEASURED with the guard disabled, the LCL rejects that index and
  ItemIndex lands on -1, and SelectByTag has already Exited so its fallback
  never runs.  Nothing raises. }
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

{ Tags LONGER than items: whatever is left over must not be reachable.  This is
  the shape that let SelectByTag return an index past the end of Items. }
procedure TComboTagTests.Test_StaleTagsAreDiscardedNotIndexed;
var
   c: TComboBox;
begin
   BeginTest('Tags left over from a previous fill are discarded, not matched');
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

{ Tags SHORTER than items: the other direction, from filling Items directly.
  A row with no tag must report no tag -- NOT the tag of some other row. }
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

{ The invariant stated as itself: whatever the two lists have been doing,
  SelectByTag must never leave ItemIndex outside the item list. }
procedure TComboTagTests.Test_SelectByTagNeverExceedsItemCount;
var
   c: TComboBox;
begin
   BeginTest('SelectByTag never sets ItemIndex past the last item');
   c := NewCombo;
   try
      FillThree(c);
      c.Items.Clear;
      c.Items.Add('Only One');             // 1 item, 3 stale tags

      SelectByTag(c, 'radio.ft1000mp');    // the stale tag at index 2
      CheckTrue(c.ItemIndex < c.Items.Count,
                'ItemIndex ran past the end of Items');
      CheckTrue(c.ItemIndex >= -1, 'ItemIndex is not a valid selection');
   finally
      c.Free;
   end;
end;

// ---------------------------------------------------------------------------
// TListBox carries the same pair, so it gets the same two questions.
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
begin
   BeginTest('A raw Items.Clear on a list box does not shift its tags');
   l := NewList;
   try
      AddListItem(l, 'Radio 1', 'slot.1');
      AddListItem(l, 'Radio 2', 'slot.2');

      l.Items.Clear;                       // Items only
      AddListItem(l, 'Radio 9', 'slot.9');

      // The sharpest failure of the whole set: with the guard disabled this
      // returns 'slot.1' -- a DIFFERENT row's tag, confidently, with no
      // exception and no blank.  A caller cannot tell it is being lied to.
      l.ItemIndex := 0;
      CheckEquals('slot.9', SelectedListTag(l));
   finally
      l.Free;
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

   Test_RawItemsClearThenRefill_SelectsTheRightRow;
   Test_StaleTagsAreDiscardedNotIndexed;
   Test_ItemsFilledDirectlyGiveEmptyTagNotNeighbour;
   Test_SelectByTagNeverExceedsItemCount;

   Test_ListBoxAddAndSelectedTag;
   Test_ListBoxRawClearThenRefill;
end;

end.

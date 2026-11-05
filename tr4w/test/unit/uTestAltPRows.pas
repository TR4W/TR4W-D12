unit uTestAltPRows;
{$I ..\..\src\tr4w.inc}

(*
  THE ALT-P WINDOW: A ROW CARRIES ITS FUNCTION KEY (pointer audit P9, item 5.4).

  Every row of the Alt-P list is one message memory, and THE ROW'S POSITION IS
  NOT ITS IDENTITY: with a bank filter on, row 0 is F1, CONTROL-F1 or ALT-F1
  depending on what is showing. uAltP asks AltPSelectedKey to decide what may
  be edited (the exchange window's first two keys are fixed), so a key that
  comes back wrong edits the wrong memory -- silently.

  WRITTEN AGAINST THE OLD SHAPE FIRST, where the key rode in TListItem.Data as
  Pointer(aKey + 1), and run green there; then the view's typed item replaced
  the pointer with these tests unchanged. They use only the public seam uAltP
  uses -- AltPAddRow, AltPSelect, AltPSelectByKey, AltPSelectedKey -- so they
  say what the window promises, not how it stores it.

  A REAL FORM, STREAMED FROM ITS .lfm AND NEVER SHOWN (see MakeForm for why
  it still gets a handle). The global TR4WAltPForm is what the seam reads, so
  each test sets it and puts nil back.
*)

interface

uses
   SysUtils, uTR4WTestFramework;

type
   TAltPRowTests = class(TTestCase)
   protected
      procedure Test_EveryRowReportsTheKeyItWasAddedWith;
      procedure Test_SelectByKeyFindsTheRowWhereverItIs;
      procedure Test_TheNotAFunctionKeyRowIsMinusOneNotNil;
      procedure Test_AnAbsentKeyIsNotSelectedAndChangesNothing;
      procedure Test_NoSelectionIsMinusOne;
      procedure Test_ARefillInAnotherOrderMovesTheKeysWithTheRows;
      procedure Test_TheRowTextStaysBesideItsKey;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,      (* Application *)
   uAltPForm;

(* The four keys that test the edges: -1 (not a function key -- the 'other
  messages' window), 0 (F1, the one a +1/-1 encoding confuses with nil), 11
  (F12, the last standard key) and 35 (ALT-F12, the last key of all). Added in
  an order that is NOT their numeric order, so a key that quietly equals its
  row number fails. *)
const
   KEYS: array[0..3] of integer = (11, -1, 35, 0);

(* WITH A WINDOW HANDLE, NEVER SHOWN. Measured: a TListView with no handle
  drops the FIRST selection made on it (ItemIndex reads -1 afterwards; every
  later one holds). Selection is the LCL's, not the key's; the cause inside
  the LCL was not traced. The window the operator opens always has its handle, so the test
  asks for one rather than pinning the quirk. *)
procedure MakeForm;
begin
   (* The widget set registers its window classes here; a handle asked for
     before it fails with "Cannot find window class". Repeat calls are
     harmless -- uTestNewContestForm makes the same one. *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;
   TR4WAltPForm := TfrmAltP.Create(nil);
   TR4WAltPForm.lvMessages.HandleNeeded;
end;

procedure DropForm;
begin
   FreeAndNil(TR4WAltPForm);
end;

procedure AddFourRows;
var
   i: integer;
begin
   AltPBeginUpdate;
   try
      AltPClear;
      for i := Low(KEYS) to High(KEYS) do
         begin
         AltPAddRow(AnsiString('cmd' + IntToStr(KEYS[i])),
                    AnsiString('msg' + IntToStr(KEYS[i])),
                    AnsiString('cap' + IntToStr(KEYS[i])),
                    KEYS[i]);
         end;
   finally
      AltPEndUpdate;
   end;
end;

procedure TAltPRowTests.Test_EveryRowReportsTheKeyItWasAddedWith;
var
   i: integer;
begin
   BeginTest('Alt-P: selecting each row reports the key it was added with');
   MakeForm;
   try
      AddFourRows;
      CheckEquals(4, AltPRowCount, 'row count');
      for i := Low(KEYS) to High(KEYS) do
         begin
         AltPSelect(i);
         CheckEquals(i, AltPSelectedIndex, 'row ' + IntToStr(i) + ' selected');
         CheckEquals(KEYS[i], AltPSelectedKey, 'key of row ' + IntToStr(i));
         end;
   finally
      DropForm;
   end;
end;

procedure TAltPRowTests.Test_SelectByKeyFindsTheRowWhereverItIs;
var
   i: integer;
begin
   BeginTest('Alt-P: AltPSelectByKey selects the row carrying that key');
   MakeForm;
   try
      AddFourRows;
      for i := Low(KEYS) to High(KEYS) do
         begin
         CheckTrue(AltPSelectByKey(KEYS[i]), 'key ' + IntToStr(KEYS[i]) + ' found');
         CheckEquals(i, AltPSelectedIndex, 'key ' + IntToStr(KEYS[i]) + ' row');
         CheckEquals(KEYS[i], AltPSelectedKey, 'key read back');
         end;
   finally
      DropForm;
   end;
end;

procedure TAltPRowTests.Test_TheNotAFunctionKeyRowIsMinusOneNotNil;
begin
   BeginTest('Alt-P: a row added with key -1 answers -1, and key 0 answers 0');
   MakeForm;
   try
      AddFourRows;
      AltPSelect(1);
      CheckEquals(-1, AltPSelectedKey, 'the -1 row');
      AltPSelect(3);
      CheckEquals(0, AltPSelectedKey, 'the F1 row (key 0)');
   finally
      DropForm;
   end;
end;

procedure TAltPRowTests.Test_AnAbsentKeyIsNotSelectedAndChangesNothing;
begin
   BeginTest('Alt-P: a key not in the list is not found and leaves the selection');
   MakeForm;
   try
      AddFourRows;
      AltPSelect(2);
      CheckFalse(AltPSelectByKey(12), 'key 12 is not in the list');
      CheckEquals(2, AltPSelectedIndex, 'the selection moved');
      CheckEquals(35, AltPSelectedKey, 'the selected key changed');
   finally
      DropForm;
   end;
end;

procedure TAltPRowTests.Test_NoSelectionIsMinusOne;
begin
   BeginTest('Alt-P: with nothing selected the key is -1, empty or not');
   MakeForm;
   try
      CheckEquals(-1, AltPSelectedKey, 'empty list');
      AddFourRows;
      CheckEquals(-1, AltPSelectedKey, 'filled, nothing selected');
   finally
      DropForm;
   end;
   (* And with no window at all -- the seam's own guard. *)
   CheckEquals(-1, AltPSelectedKey, 'no form');
   CheckFalse(AltPSelectByKey(0), 'no form, select by key');
end;

procedure TAltPRowTests.Test_ARefillInAnotherOrderMovesTheKeysWithTheRows;
begin
   BeginTest('Alt-P: a refill (a bank change) carries each key with its new row');
   MakeForm;
   try
      AddFourRows;
      AltPBeginUpdate;
      try
         AltPClear;
         AltPAddRow('ctrl-f1', '', '', 12);
         AltPAddRow('ctrl-f2', '', '', 13);
      finally
         AltPEndUpdate;
      end;
      CheckEquals(2, AltPRowCount, 'rows after refill');
      AltPSelect(0);
      CheckEquals(12, AltPSelectedKey, 'row 0 after refill');
      AltPSelect(1);
      CheckEquals(13, AltPSelectedKey, 'row 1 after refill');
      CheckFalse(AltPSelectByKey(11), 'a key from the previous fill survived');
   finally
      DropForm;
   end;
end;

procedure TAltPRowTests.Test_TheRowTextStaysBesideItsKey;
var
   i: integer;
begin
   BeginTest('Alt-P: the three columns of a row are the ones added with its key');
   MakeForm;
   try
      AddFourRows;
      for i := Low(KEYS) to High(KEYS) do
         begin
         CheckTrue(AltPSelectByKey(KEYS[i]), 'found');
         CheckEquals('cmd' + IntToStr(KEYS[i]),
                     string(AltPRowText(AltPSelectedIndex, 0)), 'command');
         CheckEquals('msg' + IntToStr(KEYS[i]),
                     string(AltPRowText(AltPSelectedIndex, 1)), 'message');
         CheckEquals('cap' + IntToStr(KEYS[i]),
                     string(AltPRowText(AltPSelectedIndex, 2)), 'caption');
         end;
   finally
      DropForm;
   end;
end;

procedure TAltPRowTests.RunAllTests;
begin
   Test_EveryRowReportsTheKeyItWasAddedWith;
   Test_SelectByKeyFindsTheRowWhereverItIs;
   Test_TheNotAFunctionKeyRowIsMinusOneNotNil;
   Test_AnAbsentKeyIsNotSelectedAndChangesNothing;
   Test_NoSelectionIsMinusOne;
   Test_ARefillInAnotherOrderMovesTheKeysWithTheRows;
   Test_TheRowTextStaysBesideItsKey;
end;

end.

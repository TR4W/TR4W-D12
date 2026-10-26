unit uTestOperatorList;
{$I ..\..\src\tr4w.inc}

(* THE SORTED OPERATOR LIST (uOperatorList).

  NY4I, CQ WW SSB 2026: the operator header must list operators by descending
  number of contacts, and the list counted a NOTE record as a contact (NY4I:
  45 QSO + 3 NOTE, listed as 48).

  Coverage:
    LogRecordIsContact -- QSO yes; NOTE, QTC, deleted, no band, no mode no
    TOperatorTally     -- counts exclude notes and deleted rows; descending
                          order; ties are alphabetical and independent of the
                          order the records arrived in; a blank operator is
                          nobody; names match without regard to case;
                          the separator is the caller's; an empty tally is ''
*)

interface

uses
   SysUtils, Classes, uTR4WTestFramework, VC, utils_text, uOperatorList;

type
   TOperatorListTests = class(TTestCase)
   protected
      procedure Test_Contact_QSO_Counts;
      procedure Test_Contact_Note_DoesNotCount;
      procedure Test_Contact_QTC_DoesNotCount;
      procedure Test_Contact_Deleted_DoesNotCount;
      procedure Test_Contact_NoBand_NoMode_DoNotCount;

      procedure Test_Tally_NotesAreNotCounted;
      procedure Test_Tally_DescendingByContacts;
      procedure Test_Tally_TiesAlphabetical;
      procedure Test_Tally_TieOrderIgnoresArrivalOrder;
      procedure Test_Tally_TotalOrder_CaseOnlyDifference;
      procedure Test_Tally_BlankOperatorIgnored;
      procedure Test_Tally_CaseInsensitiveMatch;
      procedure Test_Tally_Separator;
      procedure Test_Tally_Empty;
      procedure Test_Tally_SingleOperator;
      procedure Test_Tally_NY4I_KS4FLA_Shape;

      procedure Test_Lines_Short_OneLine;
      procedure Test_Lines_Empty_OneBareLine;
      procedure Test_Lines_WinterFD_WrapsAt75;
   public
      procedure RunAllTests; override;
   end;

implementation

function MakeRecord(const aOperator: string; aKind: LogRecordKind;
                    aDeleted: boolean): ContestExchange;
begin
   Result := Default(ContestExchange);
   SetCharBuffer(Result.ceOperator, aOperator);
   Result.ceRecordKind := aKind;
   Result.ceQSO_Deleted := aDeleted;
   Result.Band := Band20;
   Result.Mode := CW;
end;

procedure AddMany(aTally: TOperatorTally; const aOperator: string; aCount: integer);
var
   i: integer;
begin
   for i := 1 to aCount do
      begin
      aTally.AddRecord(MakeRecord(aOperator, rkQSO, False));
      end;
end;

procedure TOperatorListTests.Test_Contact_QSO_Counts;
begin
   BeginTest('Test_Contact_QSO_Counts');
   CheckTrue(LogRecordIsContact(MakeRecord('NY4I', rkQSO, False)), 'a live QSO');
end;

procedure TOperatorListTests.Test_Contact_Note_DoesNotCount;
begin
   BeginTest('Test_Contact_Note_DoesNotCount');
   CheckFalse(LogRecordIsContact(MakeRecord('NY4I', rkNote, False)), 'a NOTE');
end;

procedure TOperatorListTests.Test_Contact_QTC_DoesNotCount;
begin
   BeginTest('Test_Contact_QTC_DoesNotCount');
   CheckFalse(LogRecordIsContact(MakeRecord('NY4I', rkQTCR, False)), 'a received QTC');
   CheckFalse(LogRecordIsContact(MakeRecord('NY4I', rkQTCS, False)), 'a sent QTC');
end;

procedure TOperatorListTests.Test_Contact_Deleted_DoesNotCount;
begin
   BeginTest('Test_Contact_Deleted_DoesNotCount');
   CheckFalse(LogRecordIsContact(MakeRecord('NY4I', rkQSO, True)), 'a deleted QSO');
end;

procedure TOperatorListTests.Test_Contact_NoBand_NoMode_DoNotCount;
var
   rec: ContestExchange;
begin
   BeginTest('Test_Contact_NoBand_NoMode_DoNotCount');
   rec      := MakeRecord('NY4I', rkQSO, False);
   rec.Band := NoBand;
   CheckFalse(LogRecordIsContact(rec), 'no band: the export drops it');
   rec      := MakeRecord('NY4I', rkQSO, False);
   rec.Mode := NoMode;
   CheckFalse(LogRecordIsContact(rec), 'no mode: the export drops it');
end;

procedure TOperatorListTests.Test_Tally_NotesAreNotCounted;
var
   tally: TOperatorTally;
   i: integer;
begin
   BeginTest('Test_Tally_NotesAreNotCounted');
   tally := TOperatorTally.Create;
   try
      AddMany(tally, 'NY4I', 45);
      for i := 1 to 3 do
         begin
         tally.AddRecord(MakeRecord('NY4I', rkNote, False));
         end;
      tally.AddRecord(MakeRecord('NY4I', rkQSO, True));
      AddMany(tally, 'KS4FLA', 38);
      CheckEquals(45, tally.ContactsOf('NY4I'), 'NY4I: 45 QSO, 3 NOTE, 1 deleted');
      CheckEquals(38, tally.ContactsOf('KS4FLA'), 'KS4FLA');
   finally
      tally.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_DescendingByContacts;
var
   tally: TOperatorTally;
begin
   BeginTest('Test_Tally_DescendingByContacts');
   tally := TOperatorTally.Create;
   try
      AddMany(tally, 'W1AAA', 2);
      AddMany(tally, 'W3CCC', 30);
      AddMany(tally, 'W2BBB', 10);
      CheckEquals('W3CCC, W2BBB, W1AAA', tally.ListText(', '), 'most contacts first');
   finally
      tally.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_TiesAlphabetical;
var
   tally: TOperatorTally;
begin
   BeginTest('Test_Tally_TiesAlphabetical');
   tally := TOperatorTally.Create;
   try
      AddMany(tally, 'NY4I', 6);
      AddMany(tally, 'AF4O', 6);
      AddMany(tally, 'N4KIN', 22);
      CheckEquals('N4KIN, AF4O, NY4I', tally.ListText(', '), 'the arrl_fd shape');
   finally
      tally.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_TieOrderIgnoresArrivalOrder;
var
   a, b: TOperatorTally;
begin
   BeginTest('Test_Tally_TieOrderIgnoresArrivalOrder');
   a := TOperatorTally.Create;
   b := TOperatorTally.Create;
   try
      AddMany(a, 'K4OLE', 6);
      AddMany(a, 'W7WMS', 6);
      AddMany(b, 'W7WMS', 6);
      AddMany(b, 'K4OLE', 6);
      CheckEquals(a.ListText(', '), b.ListText(', '), 'same counts, either arrival order');
      CheckEquals('K4OLE, W7WMS', a.ListText(', '), 'alphabetical');
   finally
      a.Free;
      b.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_TotalOrder_CaseOnlyDifference;
var
   tally: TOperatorTally;
begin
   BeginTest('Test_Tally_TotalOrder_CaseOnlyDifference');
   (* Names that differ only in case are ONE operator, so the tie-break never
     meets two equal-comparing entries. *)
   tally := TOperatorTally.Create;
   try
      tally.Add('W1AW');
      tally.Add('w1aw');
      CheckEquals(1, tally.OperatorCount, 'one operator');
      CheckEquals(2, tally.ContactsOf('W1AW'), 'two contacts');
      CheckEquals('W1AW', tally.ListText(', '), 'first spelling is written');
   finally
      tally.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_BlankOperatorIgnored;
var
   tally: TOperatorTally;
begin
   BeginTest('Test_Tally_BlankOperatorIgnored');
   tally := TOperatorTally.Create;
   try
      tally.Add('');
      tally.Add('   ');
      tally.AddRecord(MakeRecord('', rkQSO, False));
      CheckEquals(0, tally.OperatorCount, 'blank is nobody');
      CheckEquals('', tally.ListText(', '), 'and writes nothing');
   finally
      tally.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_CaseInsensitiveMatch;
var
   tally: TOperatorTally;
begin
   BeginTest('Test_Tally_CaseInsensitiveMatch');
   tally := TOperatorTally.Create;
   try
      tally.Add('ny4i');
      tally.Add('NY4I');
      CheckEquals(2, tally.ContactsOf('Ny4I'), 'one operator whatever the case');
   finally
      tally.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_Separator;
var
   tally: TOperatorTally;
begin
   BeginTest('Test_Tally_Separator');
   tally := TOperatorTally.Create;
   try
      AddMany(tally, 'NY4I', 3);
      AddMany(tally, 'KS4FLA', 2);
      CheckEquals('NY4I, KS4FLA', tally.ListText(OPERATOR_LIST_SEPARATOR), 'the Cabrillo form');
      CheckEquals('NY4I KS4FLA', tally.ListText(' '), 'the separator is the caller''s');
      CheckEquals('NY4I' + #13#10 + 'KS4FLA', tally.ListText(#13#10), 'any text');
   finally
      tally.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_Empty;
var
   tally: TOperatorTally;
begin
   BeginTest('Test_Tally_Empty');
   tally := TOperatorTally.Create;
   try
      CheckEquals('', tally.ListText(', '), 'no operators');
      CheckEquals(0, tally.ContactsOf('NY4I'), 'an operator never added');
   finally
      tally.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_SingleOperator;
var
   tally: TOperatorTally;
begin
   BeginTest('Test_Tally_SingleOperator');
   tally := TOperatorTally.Create;
   try
      AddMany(tally, 'W1AW/4', 5);
      CheckEquals('W1AW/4', tally.ListText(', '), 'no separator for one');
   finally
      tally.Free;
   end;
end;

procedure TOperatorListTests.Test_Tally_NY4I_KS4FLA_Shape;
var
   tally: TOperatorTally;
   i: integer;
begin
   BeginTest('Test_Tally_NY4I_KS4FLA_Shape');
   (* The log that raised this: the 3830 report said 'NY4I' alone. *)
   tally := TOperatorTally.Create;
   try
      for i := 1 to 38 do
         begin
         tally.AddRecord(MakeRecord('KS4FLA', rkQSO, False));
         end;
      for i := 1 to 45 do
         begin
         tally.AddRecord(MakeRecord('NY4I', rkQSO, False));
         end;
      for i := 1 to 3 do
         begin
         tally.AddRecord(MakeRecord('NY4I', rkNote, False));
         end;
      CheckEquals('NY4I, KS4FLA', tally.ListText(', '), 'NY4I 45 ahead of KS4FLA 38');
   finally
      tally.Free;
   end;
end;

(* THE CABRILLO LINE CAP -- 75 characters, continued on further OPERATORS
  lines (Cabrillo 3.0 header specification). *)
procedure TOperatorListTests.Test_Lines_Short_OneLine;
begin
   CheckEquals('OPERATORS: NY4I, KS4FLA'#13#10,
               CabrilloOperatorLines('NY4I, KS4FLA'), 'two operators, one line');
end;

procedure TOperatorListTests.Test_Lines_Empty_OneBareLine;
begin
   CheckEquals('OPERATORS: '#13#10, CabrilloOperatorLines(''),
               'no operator still writes the tag, as the header always did');
end;

(* The Winter Field Day corpus set's list, 140 characters on one line in the
  D7 reference. Every line must be 75 or fewer, begin with the tag, and
  together hold every callsign in the original order. *)
procedure TOperatorListTests.Test_Lines_WinterFD_WrapsAt75;
const
   LIST = 'NE4C, K2BHS, KR4U, N0OAC, N4FOY, AA0O, NY4I, N2SKH, KA4IOX, N4GRC, ' +
          'AF4O, WD4IFT, WR6N, KB8ESY, K4OLE, W7WMS, KQ4GMO, W4TA, KM6JZN';
var
   lines: TStringList;
   i: integer;
   joined: string;
begin
   lines := TStringList.Create;
   try
      lines.Text := CabrilloOperatorLines(LIST);
      CheckTrue(lines.Count > 1, 'a 140-character list needs more than one line');
      joined := '';
      for i := 0 to lines.Count - 1 do
         begin
         CheckTrue(Length(lines[i]) <= CABRILLO_OPERATORS_LINE_MAX,
                   'line ' + IntToStr(i) + ' is ' + IntToStr(Length(lines[i])) + ' characters');
         CheckEquals('OPERATORS: ', Copy(lines[i], 1, 11), 'line ' + IntToStr(i) + ' starts with the tag');
         if joined <> '' then
            begin
            joined := joined + ', ';
            end;
         joined := joined + Copy(lines[i], 12, MaxInt);
         end;
      CheckEquals(LIST, joined, 'every callsign, in order, none split');
   finally
      lines.Free;
   end;
end;

procedure TOperatorListTests.RunAllTests;
begin
   Test_Contact_QSO_Counts;
   Test_Contact_Note_DoesNotCount;
   Test_Contact_QTC_DoesNotCount;
   Test_Contact_Deleted_DoesNotCount;
   Test_Contact_NoBand_NoMode_DoNotCount;

   Test_Tally_NotesAreNotCounted;
   Test_Tally_DescendingByContacts;
   Test_Tally_TiesAlphabetical;
   Test_Tally_TieOrderIgnoresArrivalOrder;
   Test_Tally_TotalOrder_CaseOnlyDifference;
   Test_Tally_BlankOperatorIgnored;
   Test_Tally_CaseInsensitiveMatch;
   Test_Tally_Separator;
   Test_Tally_Empty;
   Test_Tally_SingleOperator;
   Test_Tally_NY4I_KS4FLA_Shape;

   Test_Lines_Short_OneLine;
   Test_Lines_Empty_OneBareLine;
   Test_Lines_WinterFD_WrapsAt75;
end;

end.

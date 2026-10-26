unit uOperatorList;
{$I tr4w.inc}

(* THE LIST OF OPERATORS A LOG WAS WORKED BY -- ONE ROUTINE, EVERY WRITER.

  NY4I, CQ WW SSB 2026 (multi-op NY4I + KS4FLA): "when we create the cabrillo
  file or any other file that has an operator header, we are supposed to create
  a sorted list of operators (descending number of contacts). That did not
  happen." The Cabrillo header was right; the 3830 report read the operator
  field the entrant had once typed into the Cabrillo summary and printed that.
  Two writers, two answers. This unit is the one answer, and the writers
  (PostUnit's Cabrillo header, the 3830 report, the summary sheet, the Cabrillo
  summary dialog) all ask it.

  WHAT A CONTACT IS, FOR THIS PURPOSE: a record of kind rkQSO, not deleted, with
  a band and a mode -- exactly PostUnit's GoodLookingQSO, which now asks
  LogRecordIsContact, so the operator list and the QSO lines of the same file
  can never count different records. A NOTE is not a contact (NY4I's log
  held 45 QSO and 3 NOTE rows for him, and the list counted 48); neither is a
  deleted QSO, nor a QTC record, nor a record the export would drop.

  ORDER: most contacts first. Two operators with the same count are ordered
  alphabetically (case-insensitive), then by exact spelling, so the order is a
  TOTAL one. TStringList.CustomSort is not stable -- FPC's quicksort picks its
  pivot at random -- and the old routine needed a tie-break bolted on for
  that reason (measured on arrl_fd_2026_ny4i: the same log exported in two
  orders). This unit does not sort a TStringList at all.

  The tally is a plain class over two arrays so a test can feed it names
  without a database; OperatorListFromLog is the only part that reads the log. *)

interface

uses
   VC;

const
   (* THE SEPARATOR THE CABRILLO LINE HAS ALWAYS HAD, and a legal one: the
     Cabrillo 3.0 header specification (wwrof.org, checked 2026-10-25) says
     "A space or comma-delimited list of operator callsign(s)". *)
   OPERATOR_LIST_SEPARATOR = ', ';

   (* THE SAME SPECIFICATION CAPS THE LINE: "The OPERATOR line is a maximum of
     75 characters long and must begin with OPERATORS: followed by a space.
     Use multiple OPERATOR lines if needed." *)
   CABRILLO_OPERATORS_LINE_MAX = 75;

type
   TOperatorTally = class
   private
      FNames:  array of string;
      FCounts: array of integer;
      function IndexOfOperator(const aOperator: string): integer;
      function Precedes(aIndexA, aIndexB: integer): boolean;
   public
      (* Counts one contact for aOperator. A blank name is nobody and is
        ignored. Names match without regard to case; the first spelling seen
        is the one written. *)
      procedure Add(const aOperator: string);
      (* Counts the record when it is a contact (LogRecordIsContact). *)
      procedure AddRecord(const aQso: ContestExchange);
      (* How many contacts aOperator has; 0 for an operator never added. *)
      function ContactsOf(const aOperator: string): integer;
      (* How many different operators. *)
      function OperatorCount: integer;
      (* The operators, most contacts first, joined by aSeparator. *)
      function ListText(const aSeparator: string): string;
   end;

(* IS THIS RECORD A CONTACT -- the question PostUnit's GoodLookingQSO asked,
  moved here so the operator list asks it too. *)
function LogRecordIsContact(const aQso: ContestExchange): boolean;

(* THE OPERATORS OF THE OPEN CONTEST'S LOG, sorted, joined by
  OPERATOR_LIST_SEPARATOR. '' when the log cannot be read or has no operator.
  It opens and closes the log source itself, so call it when no other reader
  has the source open (the source is a single global cursor). *)
function OperatorListFromLog: string;

(* THE CABRILLO OPERATORS LINE(S) FOR aList, a list joined by
  OPERATOR_LIST_SEPARATOR, each line CRLF-terminated and at most
  CABRILLO_OPERATORS_LINE_MAX characters. Callsigns are never split; order is
  kept, so the first line still names the operators with the most contacts.
  An empty list gives one 'OPERATORS: ' line, as the header always wrote. A
  single callsign longer than a line goes on a line of its own. *)
function CabrilloOperatorLines(const aList: string): string;

implementation

uses
   SysUtils,
   utils_text,
   uLogSource;

function LogRecordIsContact(const aQso: ContestExchange): boolean;
begin
   Result := False;

   if aQso.ceRecordKind <> rkQSO then
      begin
      Exit;
      end;
   if aQso.ceQSO_Deleted then
      begin
      Exit;
      end;
   if aQso.Band = NoBand then
      begin
      Exit;
      end;
   if aQso.Mode = NoMode then
      begin
      Exit;
      end;

   Result := True;
end;

function TOperatorTally.IndexOfOperator(const aOperator: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to High(FNames) do
      begin
      if utils_text.UpperCase(FNames[i]) = utils_text.UpperCase(aOperator) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure TOperatorTally.Add(const aOperator: string);
var
   name:  string;
   index: integer;
begin
   name := Trim(aOperator);
   if name = '' then
      begin
      Exit;
      end;

   index := IndexOfOperator(name);
   if index < 0 then
      begin
      index := Length(FNames);
      SetLength(FNames, index + 1);
      SetLength(FCounts, index + 1);
      FNames[index]  := name;
      FCounts[index] := 0;
      end;
   Inc(FCounts[index]);
end;

procedure TOperatorTally.AddRecord(const aQso: ContestExchange);
begin
   if LogRecordIsContact(aQso) then
      begin
      Add(CharBufferText(aQso.ceOperator));
      end;
end;

function TOperatorTally.ContactsOf(const aOperator: string): integer;
var
   index: integer;
begin
   index := IndexOfOperator(Trim(aOperator));
   if index < 0 then
      begin
      Result := 0;
      end
   else
      begin
      Result := FCounts[index];
      end;
end;

function TOperatorTally.OperatorCount: integer;
begin
   Result := Length(FNames);
end;

(* A TOTAL ORDER: count, descending; then name, ignoring case; then the exact
  spelling. Two different entries can never compare equal.

  ORDINAL comparisons of native strings, case folded by utils_text.UpperCase
  (ASCII only, as a callsign is). Not SysUtils.CompareText/CompareStr: in FPC
  3.2.2 those take AnsiString, so each call narrowed both arguments; and not
  UnicodeCompareText, which is locale-aware on Windows and could order two
  callsigns differently from one machine to the next. *)
function TOperatorTally.Precedes(aIndexA, aIndexB: integer): boolean;
var
   foldA, foldB: string;
begin
   if FCounts[aIndexA] <> FCounts[aIndexB] then
      begin
      Result := FCounts[aIndexA] > FCounts[aIndexB];
      Exit;
      end;

   foldA := utils_text.UpperCase(FNames[aIndexA]);
   foldB := utils_text.UpperCase(FNames[aIndexB]);
   if foldA <> foldB then
      begin
      Result := foldA < foldB;
      end
   else
      begin
      Result := FNames[aIndexA] < FNames[aIndexB];
      end;
end;

function TOperatorTally.ListText(const aSeparator: string): string;
var
   order: array of integer;
   i, j, held: integer;
begin
   Result := '';

   SetLength(order, Length(FNames));
   for i := 0 to High(order) do
      begin
      order[i] := i;
      end;

   (* INSERTION SORT: an event has a handful of operators, and the order is a
     total one, so the result does not depend on the algorithm. *)
   for i := 1 to High(order) do
      begin
      held := order[i];
      j    := i - 1;
      while (j >= 0) and Precedes(held, order[j]) do
         begin
         order[j + 1] := order[j];
         Dec(j);
         end;
      order[j + 1] := held;
      end;

   for i := 0 to High(order) do
      begin
      if i > 0 then
         begin
         Result := Result + aSeparator;
         end;
      Result := Result + FNames[order[i]];
      end;
end;

function OperatorListFromLog: string;
var
   tally: TOperatorTally;
   qso:   ContestExchange;
begin
   Result := '';

   if not LogSourceOpen then
      begin
      Exit;
      end;

   tally := TOperatorTally.Create;
   try
      try
         LogSourceRewind;
         while LogSourceNext(qso) do
            begin
            tally.AddRecord(qso);
            end;
      finally
         LogSourceClose;
      end;
      Result := tally.ListText(OPERATOR_LIST_SEPARATOR);
   finally
      tally.Free;
   end;
end;

function CabrilloOperatorLines(const aList: string): string;
const
   PREFIX = 'OPERATORS: ';
var
   rest, call, line: string;
   cut: integer;
begin
   Result := '';
   line := '';
   rest := aList;

   while rest <> '' do
      begin
      cut := Pos(OPERATOR_LIST_SEPARATOR, rest);
      if cut = 0 then
         begin
         call := Trim(rest);
         rest := '';
         end
      else
         begin
         call := Trim(Copy(rest, 1, cut - 1));
         rest := Copy(rest, cut + Length(OPERATOR_LIST_SEPARATOR), MaxInt);
         end;

      if call = '' then
         begin
         Continue;
         end;

      if line = '' then
         begin
         line := PREFIX + call;
         end
      else if Length(line) + Length(OPERATOR_LIST_SEPARATOR) + Length(call) <= CABRILLO_OPERATORS_LINE_MAX then
         begin
         line := line + OPERATOR_LIST_SEPARATOR + call;
         end
      else
         begin
         Result := Result + line + #13#10;
         line := PREFIX + call;
         end;
      end;

   if line = '' then
      begin
      line := PREFIX;
      end;
   Result := Result + line + #13#10;
end;

end.

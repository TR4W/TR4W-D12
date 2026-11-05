unit uTestTelnetConsoleKinds;
{$I ..\..\src\tr4w.inc}

(*
  THE DX CLUSTER CONSOLE: A LINE KEEPS ITS KIND (pointer audit P9, item 5.3).

  Every console line carries a TelnetStringType -- sent, received, a dupe, a
  multiplier, an error, an alert -- and the owner-draw handler colours the line
  from it (an alert gets a yellow band). The kind rode in Items.Objects[] as
  TObject(Ord(kind)), an integer dressed as an object. A kind that comes back
  wrong is a line in the wrong colour, which nothing else would notice.

  WRITTEN AGAINST THE OLD SHAPE FIRST and run green there; then the view's
  typed per-kind objects replaced the integer with these tests unchanged. They
  use only the seam uTelnet uses -- TelnetConsoleAdd, TelnetConsoleTrim,
  TelnetConsoleClear, TelnetConsoleLine, TelnetConsoleKind.

  THE TRIM IS THE CASE THAT MATTERS. Lines leave from the TOP in chunks once
  the console passes its limit; a kind held anywhere but WITH its line would
  have to move in step, and a test that only adds would pass either way.

  A REAL FORM WITH A HANDLE, NEVER SHOWN. Every console routine is a silent
  no-op until the list box has a window handle (ConsoleUsable), so a test
  without one would pass on any code at all. Each test therefore asserts the
  TEXT came back before it believes a kind.
*)

interface

uses
   SysUtils, uTR4WTestFramework;

type
   TTelnetConsoleKindTests = class(TTestCase)
   protected
      procedure Test_EachKindComesBackWithItsLine;
      procedure Test_ATrimKeepsEveryKindWithItsLine;
      procedure Test_AClearThenRefillCarriesTheNewKinds;
      procedure Test_ARowThatIsNotThereIsAStatusLine;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,          (* Application *)
   uTelnet,        (* TelnetStringType *)
   uTelnetForm;

const
   (* Larger than anything a test adds, so TelnetConsoleAdd's own trim stays
     out of the way except where a test asks for it. *)
   NO_TRIM = 100000;

procedure MakeForm;
begin
   if Application <> nil then
      begin
      Application.Initialize;
      end;
   TR4WTelnetForm := TfrmTelnet.Create(nil);
   TR4WTelnetForm.lstConsole.HandleNeeded;
end;

procedure DropForm;
begin
   FreeAndNil(TR4WTelnetForm);
end;

(* Line n's kind, cycling through every value, so neighbours always differ. *)
function KindFor(const n: integer): TelnetStringType;
begin
   Result := TelnetStringType(n mod (Ord(High(TelnetStringType)) + 1));
end;

function LineFor(const n: integer): string;
begin
   Result := 'line ' + IntToStr(n);
end;

procedure TTelnetConsoleKindTests.Test_EachKindComesBackWithItsLine;
var
   n: integer;
   count: integer;
begin
   BeginTest('Telnet console: every kind comes back with the line it was added with');
   MakeForm;
   try
      count := 2 * (Ord(High(TelnetStringType)) + 1);
      for n := 0 to count - 1 do
         begin
         TelnetConsoleAdd(LineFor(n), KindFor(n), NO_TRIM);
         end;

      CheckEquals(LineFor(0), TelnetConsoleLine(0),
                  'no text came back -- the console has no handle and every check below would be empty');
      for n := 0 to count - 1 do
         begin
         CheckEquals(LineFor(n), TelnetConsoleLine(n), 'text of row ' + IntToStr(n));
         CheckEquals(Ord(KindFor(n)), Ord(TelnetConsoleKind(n)),
                     'kind of row ' + IntToStr(n));
         end;
   finally
      DropForm;
   end;
end;

procedure TTelnetConsoleKindTests.Test_ATrimKeepsEveryKindWithItsLine;
const
   LIMIT = 10;
   ADDED = 25;
var
   n, row, first: integer;
   seen: integer;
begin
   BeginTest('Telnet console: lines trimmed from the top take their kinds with them');
   MakeForm;
   try
      for n := 0 to ADDED - 1 do
         begin
         TelnetConsoleAdd(LineFor(n), KindFor(n), LIMIT);
         end;

      (* The trim keeps between 90% and 100% of the limit, so ask the console
        where it starts rather than computing it here. *)
      first := -1;
      for n := 0 to ADDED - 1 do
         begin
         if TelnetConsoleLine(0) = LineFor(n) then
            begin
            first := n;
            end;
         end;
      CheckTrue(first > 0, 'the console was not trimmed, or its first line is not one that was added');

      seen := 0;
      for row := 0 to LIMIT do
         begin
         n := first + row;
         if n >= ADDED then
            begin
            Break;
            end;
         CheckEquals(LineFor(n), TelnetConsoleLine(row), 'text of row ' + IntToStr(row));
         CheckEquals(Ord(KindFor(n)), Ord(TelnetConsoleKind(row)),
                     'kind of row ' + IntToStr(row) + ' (line ' + IntToStr(n) + ')');
         Inc(seen);
         end;
      CheckEquals(ADDED - first, seen, 'every surviving line was checked');
      CheckEquals('', TelnetConsoleLine(seen), 'a row past the survivors');
   finally
      DropForm;
   end;
end;

procedure TTelnetConsoleKindTests.Test_AClearThenRefillCarriesTheNewKinds;
begin
   BeginTest('Telnet console: after Clear, new lines carry their own kinds');
   MakeForm;
   try
      TelnetConsoleAdd('old alert', tstAlert, NO_TRIM);
      TelnetConsoleAdd('old error', tstError, NO_TRIM);
      TelnetConsoleClear;
      CheckEquals('', TelnetConsoleLine(0), 'Clear left a line');

      TelnetConsoleAdd('new send', tstSend, NO_TRIM);
      TelnetConsoleAdd('new mult', tstReceivedMult, NO_TRIM);
      CheckEquals('new send', TelnetConsoleLine(0), 'text row 0');
      CheckEquals(Ord(tstSend), Ord(TelnetConsoleKind(0)), 'kind row 0');
      CheckEquals('new mult', TelnetConsoleLine(1), 'text row 1');
      CheckEquals(Ord(tstReceivedMult), Ord(TelnetConsoleKind(1)), 'kind row 1');
   finally
      DropForm;
   end;
end;

procedure TTelnetConsoleKindTests.Test_ARowThatIsNotThereIsAStatusLine;
begin
   BeginTest('Telnet console: a row that is not there reads as a status line');
   MakeForm;
   try
      TelnetConsoleAdd('only', tstAlert, NO_TRIM);
      CheckEquals(Ord(tstTR4W), Ord(TelnetConsoleKind(-1)), 'row -1');
      CheckEquals(Ord(tstTR4W), Ord(TelnetConsoleKind(1)), 'row past the end');
   finally
      DropForm;
   end;
   CheckEquals(Ord(tstTR4W), Ord(TelnetConsoleKind(0)), 'no window at all');
end;

procedure TTelnetConsoleKindTests.RunAllTests;
begin
   Test_EachKindComesBackWithItsLine;
   Test_ATrimKeepsEveryKindWithItsLine;
   Test_AClearThenRefillCarriesTheNewKinds;
   Test_ARowThatIsNotThereIsAStatusLine;
end;

end.

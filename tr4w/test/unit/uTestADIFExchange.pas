(* PINS THE ADIF MY-EXCHANGE HELPERS, ONE LAYOUT AT A TIME.

  The twin of uTestCabrilloExchange. These were the arms of
  uADIFExchange.FormatADIFExchangeOfKind until M11 S9b, which turned the arms
  into named helpers (ADIFSentRSTNameQTH ...) that each contest class calls.
  uTestADIFSentExchange pins which contest sends which; this pins what each
  helper PRINTS, with the widths that make the expectations look fussy:
  '%-3d %-5s %-7s' is padded output that lands in an ADIF field, so a change
  of one space is a change to every exported log.

  THESE ARE CHARACTERIZATION TESTS. They record what the code DOES, validated
  against a corpus run that byte-diffs ref.adi for all thirteen fixture sets
  and still passes. Two of them record a DEFECT and say so -- a pin that
  quietly blesses a bug is worse than no pin. *)
unit uTestADIFExchange;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TTestADIFExchange = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_GridIsJustTheGrid;
      procedure Test_SixCharacterGridIsNotTruncated;
      procedure Test_RSTNameAndQTH;
      procedure Test_QSONumberAndName;
      procedure Test_RSTQSONumberAndGridSquare;
      procedure Test_ClassAndSection;
      procedure Test_RSTQSONumber;
      procedure Test_POTAParkIsJustThePark;
      procedure Test_BadQSOYieldsTheErrorMarker;
      procedure Test_DEFECT_AgeAndQSONumberHasThreeSpecsAndTwoArgs;
   end;

implementation

uses
   VC, uContestBase, uADIFExchange;

function MakeMy: TMyStationExchange;
begin
   Result.MyState      := 'FL';
   Result.MyGrid       := 'EL88AA';
   Result.MyName       := 'TOM';
   Result.MyZone       := '5';
   Result.MyFDClass    := '1D';
   Result.MySection    := 'WCF';
   Result.MyCheck      := '84';
   Result.MyPrec       := 'A';
   Result.MyFOCNumber  := '1234';
   Result.MyPostalCode := '33701';
   Result.MyPark       := 'K-1234';
end;

function MakeRx: ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.RSTSent     := 599;
   Result.RSTReceived := 599;
   Result.NumberSent  := 7;
   Result.Band        := Band20;
   Result.Mode        := CW;
   Result.ceRecordKind := rkQSO;
end;

procedure TTestADIFExchange.Test_GridIsJustTheGrid;
begin
   CheckEquals('EL88AA', ADIFSentGrid(MakeMy, MakeRx), 'the Grid and Grid2 exchanges');
end;

(* Issue #902's fix, pinned. The old code wrote #0 at byte 5 unconditionally,
  which silently truncated six-character grids -- EL88AA became EL88 in every
  exported exchange. If this ever reads 'EL88' again, that regressed. *)
procedure TTestADIFExchange.Test_SixCharacterGridIsNotTruncated;
begin
   Check(ADIFSentGrid(MakeMy, MakeRx) <> 'EL88',
         'a six-character grid must not be cut to four (issue #902)');
   CheckEquals(6, Length(ADIFSentGrid(MakeMy, MakeRx)), 'all six characters survive');
end;

procedure TTestADIFExchange.Test_RSTNameAndQTH;
begin
   // '%-3d %-5s %-7s' of 599, TOM, FL
   CheckEquals('599 TOM   FL     ', ADIFSentRSTNameQTH(MakeMy, MakeRx),
               'RST, name and QTH, padded');
end;

procedure TTestADIFExchange.Test_QSONumberAndName;
begin
   // '%-3d %-7s' of NumberSent and the name
   CheckEquals('7   TOM    ', ADIFSentQSONumberName(MakeMy, MakeRx),
               'serial then name');
end;

procedure TTestADIFExchange.Test_RSTQSONumberAndGridSquare;
begin
   // '%-3d %-4d %-7s'
   CheckEquals('599 7    EL88AA ', ADIFSentRSTQSONumberGrid(MakeMy, MakeRx),
               'RST, serial, grid');
end;

(* THE FIELD DAYS HAVE NO HELPER (M4, inventory D4) -- both format their own
   STX_STRING, pinned on their classes in uTestContestExport. A contest that
   states nothing, the base, keeps the marker. *)
procedure TTestADIFExchange.Test_ClassAndSection;
var
   obj: TContestBase;
begin
   obj := TContestBase.Create(DUMMYCONTEST);
   try
      (* F25/F26, 2026-10-14 (NY4I): it was the placeholder 'Error generating
         my exchange'. The base states no layout, so the field is '' and the
         failure is reported (uTestADIFSentExchange pins the reporting). *)
      CheckEquals('', obj.FormatADIFSentExchange(MakeMy, MakeRx),
                  'a contest with no statement of its own');
   finally
      obj.Free;
      end;
end;

(* '%-3d %03d ' -- AND THE SERIAL IS NOT ZERO-PADDED, WHICH IS ALMOST CERTAINLY
  NOT WHAT WAS INTENDED.

  In C, "%03d" of 7 is "007". In Object Pascal it is not: Format's grammar is
  %[index:][-][width][.precision]type, so the leading zero is simply part of the
  width -- 03 is 3 -- and the result is right-justified with SPACES. Serial 7
  exports as "  7", not "007".

  The arm carries the comment "issue 177", which suggests somebody went looking
  for a zero-padded serial and wrote the C spelling. Whether the field should
  be "007" is a contest question; pinning what it actually produces is not, and
  a wrong expectation here is how the next reader would have discovered this the
  hard way. I wrote '599 007 ' first and the test caught me. *)
procedure TTestADIFExchange.Test_RSTQSONumber;
begin
   CheckEquals('599   7 ', ADIFSentRSTQSONumber(MakeMy, MakeRx),
               'Pascal Format does not zero-pad -- 03 is a WIDTH, not a flag');
end;

procedure TTestADIFExchange.Test_POTAParkIsJustThePark;
begin
   CheckEquals('K-1234', ADIFSentPark(MakeMy, MakeRx), 'the park reference alone');
end;

(* A QSO PostUnit rejects never reaches a contest at all (since M4 the decision
  is PostUnit's, which owns the log), and 2026-10-14 (NY4I: "report an error as
  the silent error is not good") what it writes into STX_STRING is NOTHING:
  the placeholder 'Error generating my exchange' this test pinned is deleted,
  because a robot reads a placeholder as an exchange. A contest with no
  layout raises instead, and the caller reports it. *)
procedure TTestADIFExchange.Test_BadQSOYieldsTheErrorMarker;
var
   raised: boolean;
begin
   raised := False;
   try
      ADIFSentNotImplemented(MakeMy, MakeRx);
   except
      on E: EADIFExchangeNotImplemented do
         begin
         raised := True;
         end;
   end;
   CheckTrue(raised, 'no layout raises, it does not answer a placeholder');
end;

(* THIS PINNED A DEFECT UNTIL 2026-10-14, AND THE DEFECT IS FIXED (plan F25,
  NY4I).

  The AgeAndQSONumber arm read:

      Result := Format('%-3d %-2s %03d      ', [cMyState, nrSent]);

  THREE format specifiers, TWO arguments -- and the first specifier is %d while
  the first argument is a string. Format raised, the machine's own try/except
  swallowed it, and the caller got the initialisation string, so the Youth
  Championship RF exported 'Error generating my exchange' in that field -- as
  did the Cup RF's three runnings (QSONumberAndGridSquare: '%-3s' of a number)
  and CQ WW RTTY (RSTZoneAndPossibleDomesticQTH: '%02u' of a ShortString).

  Each of the five now exports what its own Cabrillo sent column prints; this
  is the Youth Championship RF's: the state and the serial. *)
procedure TTestADIFExchange.Test_DEFECT_AgeAndQSONumberHasThreeSpecsAndTwoArgs;
begin
   CheckEquals('FL 007 ', ADIFSentStateQSONumber2(MakeMy, MakeRx),
               'F25 fixed: the Youth Championship RF sends the state and the serial');
end;

procedure TTestADIFExchange.RunAllTests;
begin
   Test_GridIsJustTheGrid;
   Test_SixCharacterGridIsNotTruncated;
   Test_RSTNameAndQTH;
   Test_QSONumberAndName;
   Test_RSTQSONumberAndGridSquare;
   Test_ClassAndSection;
   Test_RSTQSONumber;
   Test_POTAParkIsJustThePark;
   Test_BadQSOYieldsTheErrorMarker;
   Test_DEFECT_AgeAndQSONumberHasThreeSpecsAndTwoArgs;
end;

end.

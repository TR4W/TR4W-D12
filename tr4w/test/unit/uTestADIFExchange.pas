{ PINS THE ADIF MY-EXCHANGE, ARM BY ARM.

  The twin of uTestCabrilloExchange, which pins 39 Cabrillo arms.  Its ADIF
  sibling had no unit coverage at all until uADIFExchange was extracted: the
  code sat inside a 4,000-line unit no test links, reachable only through the
  golden corpus, and the corpus covers 12 contests out of 184.

  THESE ARE CHARACTERIZATION TESTS.  They record what the code DOES, validated
  against a corpus run that byte-diffs ref.adi for all thirteen fixture sets and
  still passes.  Two of them record a DEFECT and say so -- a pin that quietly
  blesses a bug is worse than no pin.

  Field widths matter and are why the expectations look fussy: '%-3d %-5s %-7s'
  is padded output that lands in an ADIF field, so a change of one space is a
  change to every exported log. }
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
   VC, uCabrilloExchange, uADIFExchange;

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

function Ex(const aExchange: ExchangeType): string;
begin
   Result := FormatADIFMyExchange(aExchange, CQWWCW, MakeRx, MakeMy, True);
end;

procedure TTestADIFExchange.Test_GridIsJustTheGrid;
begin
   CheckEquals('EL88AA', Ex(GridExchange), 'GridExchange');
   CheckEquals('EL88AA', Ex(Grid2Exchange), 'Grid2Exchange');
end;

{ Issue #902's fix, pinned.  The old code wrote #0 at byte 5 unconditionally,
  which silently truncated six-character grids -- EL88AA became EL88 in every
  exported exchange.  If this ever reads 'EL88' again, that regressed. }
procedure TTestADIFExchange.Test_SixCharacterGridIsNotTruncated;
begin
   Check(Ex(GridExchange) <> 'EL88',
         'a six-character grid must not be cut to four (issue #902)');
   CheckEquals(6, Length(Ex(GridExchange)), 'all six characters survive');
end;

procedure TTestADIFExchange.Test_RSTNameAndQTH;
begin
   // '%-3d %-5s %-7s' of 599, TOM, FL
   CheckEquals('599 TOM   FL     ', Ex(RSTNameAndQTHExchange),
               'RST, name and QTH, padded');
end;

procedure TTestADIFExchange.Test_QSONumberAndName;
begin
   // '%-3d %-7s' of NumberSent and the name
   CheckEquals('7   TOM    ', Ex(QSONumberAndNameExchange),
               'serial then name');
end;

procedure TTestADIFExchange.Test_RSTQSONumberAndGridSquare;
begin
   // '%-3d %-4d %-7s'
   CheckEquals('599 7    EL88AA ', Ex(RSTQSONumberAndGridSquareExchange),
               'RST, serial, grid');
end;

procedure TTestADIFExchange.Test_ClassAndSection;
begin
   // '%-3s %-7s ' -- note the trailing space, which is in the format string
   CheckEquals('1D  WCF     ', Ex(ClassDomesticOrDXQTHExchange),
               'Field Day class and section');
end;

{ '%-3d %03d ' -- AND THE SERIAL IS NOT ZERO-PADDED, WHICH IS ALMOST CERTAINLY
  NOT WHAT WAS INTENDED.

  In C, "%03d" of 7 is "007".  In Object Pascal it is not: Format's grammar is
  %[index:][-][width][.precision]type, so the leading zero is simply part of the
  width -- 03 is 3 -- and the result is right-justified with SPACES.  Serial 7
  exports as "  7", not "007".

  The arm carries the comment "issue 177", which suggests somebody went looking
  for a zero-padded serial and wrote the C spelling.  Whether the field should
  be "007" is a contest question; pinning what it actually produces is not, and
  a wrong expectation here is how the next reader would have discovered this the
  hard way.  I wrote '599 007 ' first and the test caught me. }
procedure TTestADIFExchange.Test_RSTQSONumber;
begin
   CheckEquals('599   7 ', Ex(RSTQSONumberExchange),
               'Pascal Format does not zero-pad -- 03 is a WIDTH, not a flag');
end;

procedure TTestADIFExchange.Test_POTAParkIsJustThePark;
begin
   CheckEquals('K-1234', Ex(RSTAndPOTAPark), 'the park reference alone');
end;

{ A QSO the caller rejected never reaches the case at all, and the initial value
  of Result is what comes back.  That string is what PostUnit writes into the
  ADIF field, so it is worth knowing it is this and not empty. }
procedure TTestADIFExchange.Test_BadQSOYieldsTheErrorMarker;
begin
   CheckEquals('Error generating my exchange',
               FormatADIFMyExchange(GridExchange, CQWWCW, MakeRx, MakeMy, False),
               'a rejected QSO yields the marker, not a blank field');
end;

{ THIS PINS A DEFECT, DELIBERATELY.

  The arm reads:

      Result := Format('%-3d %-2s %03d      ', [cMyState, nrSent]);

  THREE format specifiers, TWO arguments -- and the first specifier is %d while
  the first argument is a PAnsiChar.  Format raises, the routine's own
  try/except swallows it, and the caller gets the initialisation string.  So
  every AgeAndQSONumberExchange contest exports 'Error generating my exchange'
  in that field.

  It is pinned rather than fixed because this commit is an extraction and its
  claim is that nothing changed.  Fixing it needs somebody who knows what the
  field should say -- '%-3s %-2s' with a third argument, or two specifiers and
  the age dropped -- and that is a contest question, not a refactoring one.
  Recorded in the bench queue.

  If this test starts FAILING, someone has fixed it; update the expectation and
  delete this comment. }
procedure TTestADIFExchange.Test_DEFECT_AgeAndQSONumberHasThreeSpecsAndTwoArgs;
begin
   CheckEquals('Error generating my exchange', Ex(AgeAndQSONumberExchange),
               'DEFECT: three format specs, two arguments -- Format raises and '
               + 'the except swallows it');
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

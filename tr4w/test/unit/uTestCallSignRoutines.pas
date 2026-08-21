unit uTestCallSignRoutines;
{$I ..\..\src\tr4w.inc}

{
  Tests for uCallSignRoutines callsign-parsing (pre-migration test net).

  These are pure string-slicing routines (prefix/number/suffix extraction,
  validation, normalization) -- exactly the kind of char-index logic the D12
  Unicode phase threatens, and foundational to WPX multipliers and callsign
  handling. uCallSignRoutines was decoupled from the monolith in #1033, so this
  is a MINIMAL-CHANGE net: it exercises the code in place, with ZERO production
  change (see the pre-migration-minimal-change principle).

  Values are traced from the current implementation (not guessed); the exact
  behaviors pinned here must survive the D12 changes unchanged.

  Conventions (docs/tr4w-migration-strategy.md): Char results are compared via
  Integer(Ord(...)); prefixes as strings.
}

interface

uses
   uTR4WTestFramework;

type
   TCallSignRoutinesTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure CheckNum(const Call: string; Expected: Char; const Ctx: string);
      procedure CheckPfx(const Call, Expected, Ctx: string);

      procedure Test_ValidCallCharacter;
      procedure Test_GetNumber;
      procedure Test_GetFirstSuffixLetter;
      procedure Test_GetPrefix;
      procedure Test_GetPrefix_Portable;
      procedure Test_IsAGoodCall_Valid;
      procedure Test_IsAGoodCall_Rejects;
      procedure Test_IsAGoodCall_RealCorpus;
      procedure Test_IsAUSPrefix;
      procedure Test_IsAGoodUSCall;
      procedure Test_RoverAndMobile;
      procedure Test_RootCall_Simple;
      procedure Test_CountryPredicates;
      procedure Test_SimilarCall;
      procedure Test_StandardCallFormat;
   end;

implementation

uses
   Classes, SysUtils,   // the corpus fixture: TStringList, FileExists
   VC, uCallSignRoutines;

procedure TCallSignRoutinesTests.CheckNum(const Call: string; Expected: Char; const Ctx: string);
begin
   CheckEquals(Integer(Ord(Expected)), Integer(Ord(GetNumber(Call))), Ctx);
end;

procedure TCallSignRoutinesTests.CheckPfx(const Call, Expected, Ctx: string);
begin
   CheckEquals(Expected, GetPrefix(Call), Ctx);
end;

// ---------------------------------------------------------------------------
// ValidCallCharacter: '/' , 0-9, A-Z (uppercase only).
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_ValidCallCharacter;
begin
   BeginTest('Test_ValidCallCharacter');
   CheckTrue(ValidCallCharacter('A'),  'A valid');
   CheckTrue(ValidCallCharacter('Z'),  'Z valid');
   CheckTrue(ValidCallCharacter('0'),  '0 valid');
   CheckTrue(ValidCallCharacter('9'),  '9 valid');
   CheckTrue(ValidCallCharacter('/'),  'slash valid');
   CheckFalse(ValidCallCharacter('a'), 'lowercase a invalid');
   CheckFalse(ValidCallCharacter('-'), 'dash invalid');
   CheckFalse(ValidCallCharacter(' '), 'space invalid');
   CheckFalse(ValidCallCharacter('.'), 'dot invalid');
end;

// ---------------------------------------------------------------------------
// GetNumber: the (last) call-area digit; portable strips at '/' first.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_GetNumber;
begin
   BeginTest('Test_GetNumber');
   CheckNum('W1AW',   '1', 'W1AW -> 1');
   CheckNum('K5ZZ',   '5', 'K5ZZ -> 5');
   CheckNum('DL0ABC', '0', 'DL0ABC -> 0');
   CheckNum('N6TR/7', '6', 'N6TR/7 -> 6 (strips before slash)');
   CheckNum('AB',     CHR(0), 'no digit -> #0');
end;

// ---------------------------------------------------------------------------
// GetFirstSuffixLetter: first letter after the last digit.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_GetFirstSuffixLetter;
begin
   BeginTest('Test_GetFirstSuffixLetter');
   CheckEquals(Integer(Ord('A')), Integer(Ord(GetFirstSuffixLetter('W1AW'))), 'W1AW -> A');
   CheckEquals(Integer(Ord('Z')), Integer(Ord(GetFirstSuffixLetter('K5ZZ'))), 'K5ZZ -> Z');
   CheckEquals(Integer(Ord('X')), Integer(Ord(GetFirstSuffixLetter('JA1XYZ'))), 'JA1XYZ -> X');
end;

// ---------------------------------------------------------------------------
// GetPrefix (WPX): the call up to and including the last digit.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_GetPrefix;
begin
   BeginTest('Test_GetPrefix');
   CheckPfx('W1AW',   'W1',  'W1AW -> W1');
   CheckPfx('K5ZZ',   'K5',  'K5ZZ -> K5');
   CheckPfx('DL1ABC', 'DL1', 'DL1ABC -> DL1');
   CheckPfx('JA1XYZ', 'JA1', 'JA1XYZ -> JA1');
end;

// ---------------------------------------------------------------------------
// GetPrefix with a single-digit portable: prefix of the base call with its
// last char replaced by the portable digit. N6TR/7: GetPrefix(N6TR)=N6 -> N + 7.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_GetPrefix_Portable;
begin
   BeginTest('Test_GetPrefix_Portable');
   CheckPfx('N6TR/7', 'N7', 'N6TR/7 -> N7');
end;

// ---------------------------------------------------------------------------
// IsAGoodCall: accepts real-looking calls.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_IsAGoodCall_Valid;
begin
   BeginTest('Test_IsAGoodCall_Valid');
   CheckTrue(IsAGoodCall('W1AW'),   'W1AW valid');
   CheckTrue(IsAGoodCall('K5ZZ'),   'K5ZZ valid');
   CheckTrue(IsAGoodCall('DL1ABC'), 'DL1ABC valid');
   CheckTrue(IsAGoodCall('W1AW/7'), 'W1AW/7 (portable) valid');
end;

// ---------------------------------------------------------------------------
// IsAGoodCall: rejects malformed input.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_IsAGoodCall_Rejects;
begin
   BeginTest('Test_IsAGoodCall_Rejects');
   CheckFalse(IsAGoodCall('AB'),  'too short (<3)');
   CheckFalse(IsAGoodCall('12A'), 'two leading digits');
   CheckFalse(IsAGoodCall('ABC'), 'no digit, 3 letters');
   CheckFalse(IsAGoodCall('333'), 'no letters');
end;

// ---------------------------------------------------------------------------
// RoverCall / MobileCall: trailing /R and /M.
// ---------------------------------------------------------------------------
// EVERY CALLSIGN IN THE FIXTURE MUST BE ACCEPTED.
//
// The fixture is 254 REAL callsigns sampled by SHAPE out of the 234,467 in
// ARRL's LOTW user-activity file -- prefix-portables, double suffixes, /P /M
// /QRP, area-number suffixes, digit-first prefixes, nine-character calls and
// three-character calls. Hand-written examples do not reach those shapes, and
// they are precisely where a validator goes wrong: the RX_CALLSIGN regular
// expression this routine replaced refused 131 of the 234,467, all of them
// legitimate (3DA/G3SXW, 5JSTAYHOME, 7L3DNX/1/QRP).
//
// A failure here means IsAGoodCall has started refusing a callsign that a real
// operator really holds -- which in a contest is a QSO the operator cannot log.
procedure TCallSignRoutinesTests.Test_IsAGoodCall_RealCorpus;
var
   fixture: TStringList;
   path, call: string;
   i, checked: integer;
begin
   BeginTest('Test_IsAGoodCall_RealCorpus');

   // Relative to the EXECUTABLE, not the working directory -- the convention
   // every fixture-using suite here follows.
   path := ExtractFilePath(ParamStr(0)) + 'fixtures\callsigns_lotw_sample.txt';

   if not FileExists(path) then
      begin
      CheckTrue(False, 'fixture not found: ' + path);
      Exit;
      end;

   checked := 0;
   fixture := TStringList.Create;
   try
      fixture.LoadFromFile(path);
      for i := 0 to fixture.Count - 1 do
         begin
         call := Trim(fixture[i]);
         if (call = '') or (call[1] = '#') then
            begin
            Continue;
            end;
         CheckTrue(IsAGoodCall(call), 'real callsign refused: ' + call);
         Inc(checked);
         end;
   finally
      fixture.Free;
   end;

   // A fixture that silently became empty would pass every assertion above.
   CheckTrue(checked > 200, 'fixture should hold 200+ callsigns, saw ' + IntToStr(checked));
end;

// IsAUSPrefix -- "does this START American", deliberately NOT anchored at the
// end, so a US call with any suffix still answers yes.
procedure TCallSignRoutinesTests.Test_IsAUSPrefix;
begin
   BeginTest('Test_IsAUSPrefix');

   CheckTrue(IsAUSPrefix('W1AW'),  'W');
   CheckTrue(IsAUSPrefix('K1TTT'), 'K');
   CheckTrue(IsAUSPrefix('N6TR'),  'N');
   CheckTrue(IsAUSPrefix('AA1K'),  'A');
   CheckTrue(IsAUSPrefix('NY4I'),  'NY4I');

   // NOT anchored: a suffix does not stop it being a US call.
   CheckTrue(IsAUSPrefix('W1AW/KH6'), 'US call with a suffix is still US');

   // LOWER CASE W NOW ANSWERS YES, AND THAT IS THE POINT OF THE REWRITE.
   // The regex this replaced was '^[AaWaKkNn][a-zA-Z]?' -- 'a' twice and NO
   // lowercase 'w' -- so w1aw fell through to the general branch and silently
   // skipped the strict US check. The old suite pinned that typo as expected
   // behaviour, which is why it survived.
   CheckTrue(IsAUSPrefix('a1aw'),  'lower case a');
   CheckTrue(IsAUSPrefix('k1ttt'), 'lower case k');
   CheckTrue(IsAUSPrefix('n6tr'),  'lower case n');
   CheckTrue(IsAUSPrefix('w1aw'),  'lower case w -- was a typo in the old regex');

   CheckFalse(IsAUSPrefix('DL1ABC'), 'German');
   CheckFalse(IsAUSPrefix('G3XYZ'),  'British');
   CheckFalse(IsAUSPrefix('1A0KM'),  'leading digit');
   CheckFalse(IsAUSPrefix(''),       'empty');
end;

// IsAGoodUSCall -- the whole string must be a well-formed US call.
procedure TCallSignRoutinesTests.Test_IsAGoodUSCall;
begin
   BeginTest('Test_IsAGoodUSCall');

   CheckTrue(IsAGoodUSCall('W1AW'),   '1x2');
   CheckTrue(IsAGoodUSCall('K1TTT'),  '1x3');
   CheckTrue(IsAGoodUSCall('NY4I'),   '2x1');
   CheckTrue(IsAGoodUSCall('AA1K'),   '2x1, double-letter prefix');
   CheckTrue(IsAGoodUSCall('N6TR'),   '1x2');
   CheckTrue(IsAGoodUSCall('KC2ABC'), '2x3, the longest legal form');
   CheckTrue(IsAGoodUSCall('W1A'),    '1x1, the shortest legal form');

   CheckFalse(IsAGoodUSCall('DL1ABC'),  'not a US prefix');
   CheckFalse(IsAGoodUSCall('W1AWXYZ'), 'suffix too long');
   CheckFalse(IsAGoodUSCall('W1'),      'no suffix at all');
   CheckFalse(IsAGoodUSCall('W1AW/KH6'), 'ANCHORED: a suffix is not a bare US call');
   // WW1AAW is a legal 2x3 and the first draft of this test wrongly asserted
   // otherwise -- the regex it replaced accepted it too.
   CheckTrue(IsAGoodUSCall('WW1AAW'), '2x3 with a two-letter prefix');
   CheckFalse(IsAGoodUSCall('WWAAW'),  'no digit at all');
   CheckFalse(IsAGoodUSCall('W12AB'),  'two digits where one belongs');
   CheckFalse(IsAGoodUSCall(''),        'empty');
end;

procedure TCallSignRoutinesTests.Test_RoverAndMobile;
begin
   BeginTest('Test_RoverAndMobile');
   CheckTrue(RoverCall('K5ZZ/R'),   'K5ZZ/R is a rover');
   CheckFalse(RoverCall('K5ZZ'),    'K5ZZ is not a rover');
   CheckTrue(MobileCall('K5ZZ/M'),  'K5ZZ/M is mobile');
   CheckFalse(MobileCall('K5ZZ'),   'K5ZZ is not mobile');
end;

// ---------------------------------------------------------------------------
// RootCall: a plain call (no portable) returns unchanged.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_RootCall_Simple;
begin
   BeginTest('Test_RootCall_Simple');
   CheckEquals('W1AW', RootCall('W1AW'), 'plain call unchanged');
end;

// ---------------------------------------------------------------------------
// Country-membership predicates: ' ID ' present in the country's list string.
// Values verified against the constant lists in uCallSignRoutines.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_CountryPredicates;
begin
   BeginTest('Test_CountryPredicates');
   CheckTrue(ARRLSectionCountry('K'),      'K is an ARRL-section country');
   CheckFalse(ARRLSectionCountry('DL'),    'DL is not');
   CheckTrue(ScandinavianCountry('OH'),    'OH Scandinavian');
   CheckTrue(ScandinavianCountry('LA'),    'LA Scandinavian');
   CheckFalse(ScandinavianCountry('K'),    'K not Scandinavian');
   CheckTrue(UBACountry('DL'),             'DL UBA-Euro');
   CheckTrue(UBACountry('F'),              'F UBA-Euro');
   CheckFalse(UBACountry('K'),             'K not UBA-Euro');
   CheckTrue(CISCountry('UA'),             'UA CIS');
   CheckFalse(CISCountry('K'),             'K not CIS');
   CheckTrue(IndonesianCountry('YB'),      'YB Indonesian');
   CheckFalse(IndonesianCountry('K'),      'K not Indonesian');
   CheckTrue(BlackSeaRegionCountry('LZ'),  'LZ Black Sea');
   CheckFalse(BlackSeaRegionCountry('K'),  'K not Black Sea');
end;

// ---------------------------------------------------------------------------
// SimilarCall: true when two calls differ in <=1 position ('?' is a wildcard),
// or one contains the other. Portable designators are stripped first.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_SimilarCall;
begin
   BeginTest('Test_SimilarCall');
   CheckTrue(SimilarCall('W1AW', 'W1AW'),  'identical');
   CheckTrue(SimilarCall('W1AW', 'W1AX'),  'one character differs');
   CheckTrue(SimilarCall('W1AW', 'W?AW'),  'wildcard ? matches');
   CheckFalse(SimilarCall('W1AW', 'K5ZZ'), 'completely different');
end;

// ---------------------------------------------------------------------------
// StandardCallFormat: no-slash calls pass through; /P and /QRP are stripped;
// a call with a longer base and a prefix tail moves the prefix to the front.
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.Test_StandardCallFormat;
begin
   BeginTest('Test_StandardCallFormat');
   CheckEquals('W1AW',    StandardCallFormat('W1AW', True),     'no slash -> unchanged');
   CheckEquals('W1AW',    StandardCallFormat('W1AW/P', True),   '/P stripped');
   CheckEquals('W1AW',    StandardCallFormat('W1AW/QRP', True), '/QRP stripped');
   CheckEquals('DL/W1AW', StandardCallFormat('W1AW/DL', True),  'prefix moved to front');
end;

// ---------------------------------------------------------------------------
// Suite entry point
// ---------------------------------------------------------------------------
procedure TCallSignRoutinesTests.RunAllTests;
begin
   Test_ValidCallCharacter;
   Test_GetNumber;
   Test_GetFirstSuffixLetter;
   Test_GetPrefix;
   Test_GetPrefix_Portable;
   Test_IsAGoodCall_Valid;
   Test_IsAGoodCall_Rejects;
   Test_IsAGoodCall_RealCorpus;
   Test_IsAUSPrefix;
   Test_IsAGoodUSCall;
   Test_RoverAndMobile;
   Test_RootCall_Simple;
   Test_CountryPredicates;
   Test_SimilarCall;
   Test_StandardCallFormat;
end;

end.

unit uTestFormatTranslation;
{$I ..\..\src\tr4w.inc}

{
  BEFORE-AND-AFTER TESTS FOR THE TF.Format -> SysUtils.Format CONVERSION.

  These are not "does the new code look right" tests. THE OLD IMPLEMENTATION IS
  STILL CALLABLE, so this asserts the actual before against the actual after:
  TF.Format was 21 declarations of user32's `wsprintfA`, which is still exported
  and is declared here directly. Every case runs the ORIGINAL wsprintf format
  string through wsprintf, runs the REPLACEMENT Delphi format string through
  SysUtils.Format, and requires the two to produce identical text.

  WHY THIS IS NEEDED. wsprintf and Delphi Format are different languages and one
  of the differences is silent:

      wsprintf('%02u:%02u', 9, 5)  = '09:05'
      Format  ('%02u:%02u', [9,5]) = ' 9: 5'      <-- SPACE-padded

  Delphi has NO zero-pad FLAG; precision is what zero-pads, so the translation is
  %02u -> %.2u. Nothing raises, nothing warns, and the sites are times, log
  backup names and the per-QSO MP3 filename. A wrong pad there does not look
  wrong -- it just fails to match later.

  The other differences DO raise, so they cannot ship silently, but they are
  pinned here anyway because the fix for each is a judgement call and someone
  will otherwise re-make it: %c has no Delphi equivalent (pass a one-character
  string), and the C short modifier `h` in %.2hu is simply dropped.

  ONE TEST DELIBERATELY ASSERTS THE TRAP ITSELF -- that '%02u' and '%.2u' differ
  under SysUtils.Format. If a future RTL ever made them agree, that test fails
  and this whole file can be retired. Until then it is the reason the file
  exists, stated as an executable fact rather than a comment.

  SCOPE: every format string converted in tranches 1 and 2. The remaining
  TF.Format sites use only %s/%d/%u/%x, which mean the same in both languages --
  when they are converted, add cases here only if a new specifier appears.
}

interface

uses
   SysUtils, Windows, uTR4WTestFramework, uFreqTimeFormat;

type
   TFormatTranslationTests = class(TTestCase)
   protected
      procedure Test_ZeroPad_IsTheTrap;
      procedure Test_TimeFormatters;
      procedure Test_FileNameFormatters;
      procedure Test_CharSpecifier;
      procedure Test_WidthAndPrecision_Unchanged;
   public
      procedure RunAllTests; override;
   end;

implementation

{ THE OLD IMPLEMENTATION, declared exactly as TF.pas declares it -- cdecl, one
  Win32 export per argument shape. Only the shapes these tests need. }

function ws2(Output: PAnsiChar; Fmt: PAnsiChar; i1, i2: integer): integer; cdecl;
   external 'user32' name 'wsprintfA';
function ws1s(Output: PAnsiChar; Fmt: PAnsiChar; p: PAnsiChar): integer; cdecl;
   external 'user32' name 'wsprintfA';
function ws1i(Output: PAnsiChar; Fmt: PAnsiChar; i1: integer): integer; cdecl;
   external 'user32' name 'wsprintfA';
{ ARGUMENT ORDER MUST MATCH THE FORMAT STRING. wsprintf is cdecl varargs, so a
  declaration whose parameters are in the wrong order does not fail to compile --
  it reads the pointer as the number and the number as a pointer, and takes an
  access violation. '%.4u %-8s' is (integer, pointer), in that order. }
function ws_is(Output: PAnsiChar; Fmt: PAnsiChar; i1: integer; p: PAnsiChar): integer; cdecl;
   external 'user32' name 'wsprintfA';

var
   Buf: array[0..1023] of AnsiChar;

{ Run the ORIGINAL format string through the ORIGINAL formatter. }
function Old2(const aFmt: string; i1, i2: integer): string;
begin
   FillChar(Buf, SizeOf(Buf), 0);
   ws2(Buf, PAnsiChar(AnsiString(aFmt)), i1, i2);
   Result := string(AnsiString(PAnsiChar(@Buf)));
end;

function Old1i(const aFmt: string; i1: integer): string;
begin
   FillChar(Buf, SizeOf(Buf), 0);
   ws1i(Buf, PAnsiChar(AnsiString(aFmt)), i1);
   Result := string(AnsiString(PAnsiChar(@Buf)));
end;

function Old1s(const aFmt, aArg: string): string;
var
   Arg: AnsiString;
begin
   { The argument is held in a NAMED variable. PAnsiChar of a temporary
     AnsiString is a dangling pointer the moment the expression ends -- that
     exact bug is on record in this tree. }
   Arg := AnsiString(aArg);
   FillChar(Buf, SizeOf(Buf), 0);
   ws1s(Buf, PAnsiChar(AnsiString(aFmt)), PAnsiChar(Arg));
   Result := string(AnsiString(PAnsiChar(@Buf)));
end;

function OldIS(const aFmt: string; i1: integer; const aArg: string): string;
var
   Arg: AnsiString;
begin
   Arg := AnsiString(aArg);
   FillChar(Buf, SizeOf(Buf), 0);
   ws_is(Buf, PAnsiChar(AnsiString(aFmt)), i1, PAnsiChar(Arg));
   Result := string(AnsiString(PAnsiChar(@Buf)));
end;


{ THE REASON THIS FILE EXISTS, as an executable assertion rather than a comment.
  If '%02u' and '%.2u' ever agree under SysUtils.Format, this fails and the
  translation table -- and this file -- can be reconsidered. }
procedure TFormatTranslationTests.Test_ZeroPad_IsTheTrap;
begin
   BeginTest('Test_ZeroPad_IsTheTrap');

   { What the old formatter did with the old string. }
   CheckEquals('09:05', Old2('%02u:%02u', 9, 5), 'wsprintf %02u zero-pads');

   { What a NAIVE translation -- keeping the same string -- would now produce. }
   CheckEquals(' 9: 5', SysUtils.Format('%02u:%02u', [9, 5]),
               'Delphi %02u SPACE-pads: this is the silent failure being guarded');

   { And the translation actually used. }
   CheckEquals('09:05', SysUtils.Format('%.2u:%.2u', [9, 5]),
               'Delphi %.2u zero-pads: the correct replacement');
end;


{ tranche 1: tree.GetTimeString, LogCW.TimeString, uFreqTimeFormat. }
procedure TFormatTranslationTests.Test_TimeFormatters;
var
   h, m: integer;
begin
   BeginTest('Test_TimeFormatters');

   { Every hour and minute, not a sample: the pad only shows below 10, and the
     whole risk is a boundary. 1440 comparisons is cheap. }
   for h := 0 to 23 do
      begin
      for m := 0 to 59 do
         begin
         CheckEquals(Old2('%.2hu:%.2hu', h, m), FormatHourMinute(h, m),
                     Format('HH:MM differs at %d:%d', [h, m]));
         CheckEquals(Old2('%.2hu%.2hu', h, m), FormatHourMinute(h, m, ''),
                     Format('HHMM differs at %d:%d', [h, m]));
         end;
      end;

   { LOGWIND's band map placeholder is minute+second through the same shape. }
   CheckEquals('NEW ' + Old2('%02u%02u', 7, 3),
               'NEW ' + SysUtils.Format('%.2u%.2u', [7, 3]),
               'band map placeholder');
end;


{ tranche 2: the names that go on disk. }
procedure TFormatTranslationTests.Test_FileNameFormatters;
var
   n: integer;
begin
   BeginTest('Test_FileNameFormatters');

   { uGetServerLog, %03d -> %.3d. 1, 9, 10 and 100 are where padding changes. }
   for n in [1, 2, 9, 10, 99, 100, 999] do
      begin
      CheckEquals(Old1i('LOGBACKUP_%03d.TRW', n),
                  SysUtils.Format('LOGBACKUP_%.3d.TRW', [n]),
                  Format('log backup name at %d', [n]));
      end;

   { uMP3Recorder's temp name, %02u -> %.2u. }
   CheckEquals(Old2('TEMP_%02u_%02u.MP3', 9, 5),
               SysUtils.Format('TEMP_%.2u_%.2u.MP3', [9, 5]),
               'MP3 temp name, single-digit hour and day');
   CheckEquals(Old2('TEMP_%02u_%02u.MP3', 23, 31),
               SysUtils.Format('TEMP_%.2u_%.2u.MP3', [23, 31]),
               'MP3 temp name, two-digit hour and day');

   { uHistory's version date. }
   CheckEquals(Old1i('<i> (%02u-', 7), SysUtils.Format('<i> (%.2u-', [7]),
               'history version date');

   { uQTCS: %04u -> %.4u, and '%-8s' is left-justify in BOTH languages. }
   CheckEquals(OldIS('%04u %-8s', 12, 'NY4I'),
               SysUtils.Format('%.4u %-8s', [12, 'NY4I']),
               'QTC line: zero-padded time and left-justified call');
end;


{ %c has no Delphi equivalent at all -- it raises, so it cannot ship quietly,
  but the replacement is a choice worth pinning. LOGDVP's WAV names. }
procedure TFormatTranslationTests.Test_CharSpecifier;
var
   c: AnsiChar;
begin
   BeginTest('Test_CharSpecifier');

   for c := 'A' to 'Z' do
      begin
      CheckEquals(Old1s('LETTERSANDNUMBERS\%s.WAV', string(c)),
                  SysUtils.Format('LETTERSANDNUMBERS\%s.WAV', [string(c)]),
                  'WAV name for ' + string(c));
      end;

   { '_' is the substitution LOGDVP makes for '/', and a digit is the other
     case that reaches this path. }
   CheckEquals(Old1s('LETTERSANDNUMBERS\%s.WAV', '_'),
               SysUtils.Format('LETTERSANDNUMBERS\%s.WAV', ['_']),
               'WAV name for underscore');
   CheckEquals(Old1s('LETTERSANDNUMBERS\%s.WAV', '7'),
               SysUtils.Format('LETTERSANDNUMBERS\%s.WAV', ['7']),
               'WAV name for digit');
end;


{ The specifiers that mean the SAME thing in both languages, pinned so a future
  tranche does not "fix" one of them on the assumption that none of them match. }
procedure TFormatTranslationTests.Test_WidthAndPrecision_Unchanged;
begin
   BeginTest('Test_WidthAndPrecision_Unchanged');

   CheckEquals(Old1i('%d', 42),      SysUtils.Format('%d', [42]),      '%d');
   CheckEquals(Old1i('%u', 42),      SysUtils.Format('%u', [42]),      '%u');
   CheckEquals(Old1i('%4d', 42),     SysUtils.Format('%4d', [42]),     '%4d width');
   CheckEquals(Old1i('%-7d', 42),    SysUtils.Format('%-7d', [42]),    '%-7d left-justify');
   CheckEquals(Old1i('%.2d', 5),     SysUtils.Format('%.2d', [5]),     '%.2d precision');
   { %x IS NOT INTERCHANGEABLE, and this test is how that was found -- it was
     written asserting equality and failed. wsprintf emits LOWER-case hex,
     SysUtils.Format emits UPPER-case. Nothing in the tree is affected today: no
     surviving TF.Format site uses %x, every %x is already SysUtils.Format, and
     the two places where the case matters (TF's GUID builder and the log-compare
     CRC columns) already wrap the result in LowerCase. It is pinned so a future
     tranche that meets a %x knows to add LowerCase rather than discover it in a
     protocol string. }

   CheckEquals('ff', Old1i('%x', 255),            'wsprintf %x is lower-case');
   CheckEquals('FF', SysUtils.Format('%x', [255]), 'Delphi %x is UPPER-case');
   CheckEquals(Old1i('%x', 255), LowerCase(SysUtils.Format('%x', [255])),
               '%x translates only WITH LowerCase');
   CheckEquals(Old1i('%.2x', 10), LowerCase(SysUtils.Format('%.2x', [10])),
               '%.2x translates only WITH LowerCase');
   CheckEquals(Old1s('%s', 'NY4I'),  SysUtils.Format('%s', ['NY4I']),  '%s');
   CheckEquals(Old1s('%2s', 'NY4I'), SysUtils.Format('%2s', ['NY4I']), '%2s narrower than the value');
end;


procedure TFormatTranslationTests.RunAllTests;
begin
   Test_ZeroPad_IsTheTrap;
   Test_TimeFormatters;
   Test_FileNameFormatters;
   Test_CharSpecifier;
   Test_WidthAndPrecision_Unchanged;
end;

end.

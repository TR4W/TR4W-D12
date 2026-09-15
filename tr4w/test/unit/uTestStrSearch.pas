unit uTestStrSearch;
{$I ..\..\src\tr4w.inc}

(* uTestStrSearch -- strU.

  These began as golden-master tests freezing three x86 inline-asm routines in
  uStrSearch while their bodies were rewritten in Pascal (Issue #997). Two of
  those routines, StrComp_JOH_IA32_6 and StrPosPartial, had no production
  caller and were deleted on 2026-09-15, with their nineteen tests and the Off
  pointer helper only those tests used. What remains pins strU, which the
  config loader depends on. *)

interface

uses
   (* NO utils_text HERE ANY MORE, AND THE REASON IS WORTH KEEPING.

     This clause used to name uAnsiStr, and a note explained why: without it
     `StrPos` resolved to SysUtils' and not to TR4W's own, so nine assertions
     were testing a function the program did not call -- and passing, which is
     worse than not testing it. A NATIVE LINUX RUN exposed it, because the
     RTL's answer for an empty needle differs between platforms while TR4W's
     was fixed by its own code.

     THE GENERAL RULE SURVIVES ITS OWN EXAMPLE: a shim that shadows an RTL
     name is resolved by uses ORDER, so which one a call reaches is decided
     somewhere other than the call. uAnsiStr.StrPos itself is gone -- it had
     no caller outside its own tests -- and the nine tests went with it. *)
   SysUtils, uTR4WTestFramework, uStrSearch;

type
   TStrSearchTests = class(TTestCase)
   protected
      // StrU -- in-place ASCII upcase of a ShortString
      procedure Test_StrU_AllLower;
      procedure Test_StrU_Mixed;
      procedure Test_StrU_AlreadyUpper;
      procedure Test_StrU_DigitsPunctUntouched;
      procedure Test_StrU_Empty;
      procedure Test_StrU_ExtendedBytesUntouched;
      procedure Test_StrU_ConfigLineStyle;

   public
      procedure RunAllTests; override;
   end;

implementation

// ---------------------------------------------------------------------------
// StrU -- in-place ASCII upcase
// ---------------------------------------------------------------------------

procedure TStrSearchTests.Test_StrU_AllLower;
var s: ShortString;
begin
   BeginTest('Test_StrU_AllLower');
   s := 'abcxyz';
   StrU(s);
   CheckEquals('ABCXYZ', s, 'StrU all-lower in place');
end;

procedure TStrSearchTests.Test_StrU_Mixed;
var s: ShortString;
begin
   BeginTest('Test_StrU_Mixed');
   s := 'aBcDeF';
   StrU(s);
   CheckEquals('ABCDEF', s, 'StrU mixed case');
end;

procedure TStrSearchTests.Test_StrU_AlreadyUpper;
var s: ShortString;
begin
   BeginTest('Test_StrU_AlreadyUpper');
   s := 'ABCDEF';
   StrU(s);
   CheckEquals('ABCDEF', s, 'StrU already upper unchanged');
end;

procedure TStrSearchTests.Test_StrU_DigitsPunctUntouched;
var s: ShortString;
begin
   BeginTest('Test_StrU_DigitsPunctUntouched');
   s := 'a1!b_z9';
   StrU(s);
   CheckEquals('A1!B_Z9', s, 'StrU leaves digits/punct alone');
end;

procedure TStrSearchTests.Test_StrU_Empty;
var s: ShortString;
begin
   BeginTest('Test_StrU_Empty');
   s := '';
   StrU(s);
   CheckEquals('', s, 'StrU empty string');
end;

procedure TStrSearchTests.Test_StrU_ExtendedBytesUntouched;
var s: ShortString;
begin
   BeginTest('Test_StrU_ExtendedBytesUntouched');
   // Bytes > 'z' (0x7A) are skipped by the asm (CMP AL,'z'; JA). Verify a
   // >127 extended/code-page byte survives unchanged while ASCII upcases.
   s := 'a' + Chr(200) + 'b';
   StrU(s);
   CheckEquals('A' + Chr(200) + 'B', s, 'StrU leaves >127 bytes alone');
end;

procedure TStrSearchTests.Test_StrU_ConfigLineStyle;
var s: ShortString;
begin
   BeginTest('Test_StrU_ConfigLineStyle');
   // The exact pattern the config loader relies on (LogCfg note).
   s := 'radio one password=appleipod';
   StrU(s);
   CheckEquals('RADIO ONE PASSWORD=APPLEIPOD', s, 'StrU config-line upcase');
end;

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------

procedure TStrSearchTests.RunAllTests;
begin

   Test_StrU_AllLower;
   Test_StrU_Mixed;
   Test_StrU_AlreadyUpper;
   Test_StrU_DigitsPunctUntouched;
   Test_StrU_Empty;
   Test_StrU_ExtendedBytesUntouched;
   Test_StrU_ConfigLineStyle;
end;

end.

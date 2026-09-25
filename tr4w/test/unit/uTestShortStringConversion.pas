{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uTestShortStringConversion;
{$I ..\..\src\tr4w.inc}

(* WHAT A ShortString CAST ACTUALLY DOES IN THIS TREE'S COMPILER AND MODE.

  THIS UNIT EXISTS BECAUSE THE PROJECT BELIEVED SOMETHING FALSE, WROTE IT
  DOWN, AND ACTED ON IT THREE TIMES.

  CLAUDE.md stated, categorically, that `ShortStringType(someAnsiString)` is
  NOT a conversion -- that "FPC reinterprets the string's POINTER as a
  ShortString", so the first byte of a pointer becomes the length byte and the
  result is garbage.  Two source comments repeat it as established fact
  (uLogStore, uNewContestCommands), and on 2026-09-24 an agent reviewing
  uRadioKenwoodLAN reported its credential assignment as a live defect on the
  strength of it.  NY4I approved a fix.

  IT IS NOT TRUE.  Measured against FPC 3.2.2 / i386-win32 in this tree's
  exact mode ({$MODE Delphi} + {$MODESWITCH UnicodeStrings}, so `string` is
  UnicodeString): the cast and the plain assignment emit the SAME conversion
  and produce byte-identical results -- for ASCII, for non-ASCII, for a string
  longer than the target, and for a narrow string[N] as well as a full
  ShortString.

  THE ONE REAL DIFFERENCE IS A WARNING, and it matters here: the assignment
  raises W "Implicit string type conversion with potential data loss" and the
  explicit cast suppresses it.  Build-App.ps1 ratchets that count, so
  "correcting" casts to assignments RAISES the narrowing number without
  changing a single byte of behaviour.

  SO WHAT DID BITE THEM?  Something real, misattributed.  The defect
  uEditMessageForm records is that a ShortString has NO NUL TERMINATOR, so
  `@id[1]` passed where a PAnsiChar was expected ran off the end of the text
  into stale stack bytes.  That is a fact about ShortString's layout and is
  unaffected by how the ShortString was produced.  The cast was nearby, not
  guilty.

  THE RULE THAT SURVIVES, and it is worth keeping:
    - a ShortString is NOT null-terminated; never hand @s[1] to something
      expecting a C string;
    - it truncates at its declared width, silently, whichever form you use --
      so the width is the thing to check, not the syntax;
    - prefer the assignment when you WANT the narrowing warning, and the cast
      when the narrowing is deliberate and already bounded elsewhere.

  These tests pin the semantics so the myth cannot come back.  If a future FPC
  ever does make the cast a reinterpretation, this fails loudly and names the
  shape, which is the whole point of writing it down as a test rather than as
  another paragraph.
*)

interface

uses
   uTR4WTestFramework;

type
   TShortStringConversionTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_CastAndAssignAgreeOnAscii;
      procedure Test_CastAndAssignAgreeOnNonAscii;
      procedure Test_BothTruncateAtTheDeclaredWidth;
      procedure Test_NarrowSubrangeBehavesTheSame;
      procedure Test_CredentialSurvivesTheKenwoodShape;
   end;

implementation

uses
   SysUtils;

type
   (* The shape uRadioConfigApply renders a credential through: a 50-character
     subrange, which is the real limit on a LAN password long before the
     255-byte one a ShortString would impose. *)
   TStr50 = string[50];

procedure TShortStringConversionTests.RunAllTests;
begin
   Test_CastAndAssignAgreeOnAscii;
   Test_CastAndAssignAgreeOnNonAscii;
   Test_BothTruncateAtTheDeclaredWidth;
   Test_NarrowSubrangeBehavesTheSame;
   Test_CredentialSurvivesTheKenwoodShape;
end;

(* A helper rather than five copies: what matters in every case is that the two
  spellings produce the SAME bytes, not what those bytes happen to be. *)
function SameBytes(const a, b: ShortString): boolean;
var
   i: integer;
begin
   Result := Length(a) = Length(b);
   if not Result then
      begin
      Exit;
      end;
   for i := 1 to Length(a) do
      begin
      if a[i] <> b[i] then
         begin
         Result := False;
         Exit;
         end;
      end;
end;

procedure TShortStringConversionTests.Test_CastAndAssignAgreeOnAscii;
var
   source: string;
   viaCast, viaAssign: ShortString;
begin
   BeginTest('Test_CastAndAssignAgreeOnAscii');
   source    := 'SecretPassword123';
   viaCast   := ShortString(source);
   viaAssign := source;

   CheckEquals(17, Length(viaCast),  'the cast converts -- it does not take a pointer byte as the length');
   CheckEquals(17, Length(viaAssign), 'and so does the assignment');
   CheckTrue(SameBytes(viaCast, viaAssign), 'the two spellings are the same conversion');
   CheckEquals('SecretPassword123', string(viaCast), 'and the text is intact');
end;

procedure TShortStringConversionTests.Test_CastAndAssignAgreeOnNonAscii;
var
   source: string;
   viaCast, viaAssign: ShortString;
begin
   BeginTest('Test_CastAndAssignAgreeOnNonAscii');
   (* Characters that are NOT representable identically in every code page --
     if either spelling took a different route through the string manager,
     this is where they would part company. *)
   source    := 'pa' + WideChar($00DF) + WideChar($20AC);
   viaCast   := ShortString(source);
   viaAssign := source;

   CheckTrue(SameBytes(viaCast, viaAssign),
             'cast and assignment must agree on a lossy conversion too');
end;

procedure TShortStringConversionTests.Test_BothTruncateAtTheDeclaredWidth;
var
   source: string;
   viaCast, viaAssign: ShortString;
   i: integer;
begin
   BeginTest('Test_BothTruncateAtTheDeclaredWidth');
   source := '';
   for i := 1 to 300 do
      begin
      source := source + 'x';
      end;

   viaCast   := ShortString(source);
   viaAssign := source;

   (* SILENTLY, in both forms.  This is the property that actually deserves
     care at a credential boundary -- not which syntax was used. *)
   CheckEquals(255, Length(viaCast),   'a ShortString caps at 255, by cast');
   CheckEquals(255, Length(viaAssign), 'and by assignment');
   CheckTrue(SameBytes(viaCast, viaAssign), 'same truncation, same bytes');
end;

procedure TShortStringConversionTests.Test_NarrowSubrangeBehavesTheSame;
var
   source: string;
   viaCast, viaAssign: TStr50;
begin
   BeginTest('Test_NarrowSubrangeBehavesTheSame');
   source := StringOfChar('A', 60);

   viaCast   := TStr50(source);
   viaAssign := source;

   CheckEquals(50, Length(viaCast),   'a string[50] caps at 50, by cast');
   CheckEquals(50, Length(viaAssign), 'and by assignment');
   CheckTrue(SameBytes(viaCast, viaAssign), 'same truncation for a subrange too');
end;

procedure TShortStringConversionTests.Test_CredentialSurvivesTheKenwoodShape;
var
   user, pass: string;
   userShort, passShort: ShortString;
begin
   BeginTest('Test_CredentialSurvivesTheKenwoodShape');

   (* THE EXACT SHAPE OF TKenwoodLAN.ApplyNetworkCredentials, which was
     reported as corrupting credentials and does not.  A LAN password reaches
     it through a 50-character subrange upstream, so the 255-byte ceiling is
     never the binding limit and nothing is lost on the way in. *)
   user := 'NY4I';
   pass := 'c0rrect-horse-battery';

   userShort := ShortString(user);
   passShort := ShortString(pass);

   CheckEquals('NY4I', string(userShort), 'the LAN user id arrives intact');
   CheckEquals('c0rrect-horse-battery', string(passShort), 'and so does the password');
   CheckTrue(Length(pass) <= 50,
             'the fixture stays inside the width the config path enforces');
end;

end.

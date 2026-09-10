(*
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
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* THE PLATFORM CONFORMANCE HARNESS -- RECORD, EXPECT, SKIP.

  NY4I asked for this on 2026-09-09, in his own words: "look at all the things
  we ask the platform and confirm the answer we expect ... run a little widget
  on both Linux and the Mac to validate what you are getting back, and maybe
  that will help short-circuit some of these problems."

  IT IS THE RIGHT SHAPE FOR THE DEFECTS THIS PORT ACTUALLY HITS. Every one of
  them so far has had the same form: the SOURCE reads correctly, no compiler
  or lint objects, and only the platform's ANSWER differs. A build cannot see
  that. A unit test on Windows cannot see it. It surfaces on a bench, days
  later, as a symptom several steps removed from its cause -- a path separator
  that ended up scoring a US station as DX, a thread-close convention that put
  a modal dialog on screen after every CW message.

  THREE VERBS, AND THE DIFFERENCE BETWEEN THEM IS THE WHOLE DISCIPLINE:

    Expect  -- we KNOW what this platform must answer. Disagreement FAILS the
               run. This is the only verb that protects anything.

    Note    -- we do not know yet, or the answer legitimately differs and no
               code depends on which. Recorded so the three platforms can be
               diffed, never fails.

    Skip    -- cannot be asked here, with the reason. Counted separately from
               a pass so "it did not run" never reads as "it was fine".

  A Note IS A DEBT, NOT A RESULT. The value of this program is in Expect; a
  file full of Notes is a report nobody reads, which is the failure mode of
  every conformance suite ever abandoned. When a Note's right answer becomes
  known -- usually because something broke and we learned it -- it becomes an
  Expect in the same commit as the fix.

  WINDOWS IS A TARGET TOO, AND THAT IS NOT OPTIONAL. TR4W was written against
  Win32, so Windows is the reference the code's assumptions were formed from.
  A probe that runs only on Linux tells you what Linux does; it does not tell
  you where the two disagree, which is the only question that matters.

  MACHINE READABLE ON PURPOSE. The console output is for a person watching a
  build; the JSON beside it is what the three platforms are compared with.
  Neither is derived from the other after the fact -- they are written from
  the same records, so they cannot drift. *)
unit uProbeReport;

{$MODE DELPHI}
{$H+}

interface

uses
   SysUtils, Classes;

type
   TProbeOutcome = (poPass, poFail, poNote, poSkip);

   (* ONE ANSWER FROM THE PLATFORM.

     Values are strings whatever their real type, and deliberately: the file is
     compared ACROSS platforms where the same fact is an integer here and a
     pointer there (SizeOf(TThreadID) is the worked example), and a comparison
     that has to agree about the type first cannot be made at all. The probe
     renders; the harness stores what it rendered. *)
   TProbe = class
      private
         FKey:      string;
         FActual:   string;
         FExpected: string;
         FOutcome:  TProbeOutcome;
         FDetail:   string;
      public
         constructor Create(const aKey, aActual, aExpected, aDetail: string;
                            const aOutcome: TProbeOutcome);
         property Key:      string read FKey;
         property Actual:   string read FActual;
         property Expected: string read FExpected;
         property Outcome:  TProbeOutcome read FOutcome;
         property Detail:   string read FDetail;
   end;

   (* THE RUN. Owns its probes and reports itself. *)
   TProbeReport = class
      private
         FProbes:   TList;
         FTarget:   string;
         function CountOf(const aOutcome: TProbeOutcome): integer;
         function OutcomeName(const aOutcome: TProbeOutcome): string;
         function JsonEscape(const aValue: string): string;
      public
         constructor Create(const aTarget: string);
         destructor Destroy; override;

         (* WE KNOW THE ANSWER THIS PLATFORM MUST GIVE. A difference fails the
           run and is what this program exists for. *)
         procedure Expect(const aKey, aActual, aExpected: string);
            overload;
         procedure Expect(const aKey: string; const aActual, aExpected: Int64);
            overload;
         procedure Expect(const aKey: string; const aActual, aExpected: boolean);
            overload;

         (* WE DO NOT KNOW YET. Recorded for the cross-platform diff, never
           fails. aDetail says what would have to be true for this to become an
           Expect -- a Note with no such note is a Note nobody will ever
           close. *)
         procedure Note(const aKey, aActual, aDetail: string); overload;
         procedure Note(const aKey: string; const aActual: Int64;
                        const aDetail: string); overload;

         (* CANNOT BE ASKED HERE. Counted apart from a pass, so a probe that
           did not run never reads as one that was satisfied. *)
         procedure Skip(const aKey, aWhy: string);

         procedure WriteConsole;
         procedure WriteJson(const aPath: string);

         function Failed: integer;
         function Total:  integer;
   end;

(* THE TARGET THIS BINARY WAS BUILT FOR, as the JSON file is named and as the
  diff groups results. Compile-time, not run time: what matters is which arm of
  every {$IFDEF} in TR4W was taken, and that is a property of the BUILD. A
  binary reporting the host it happens to be running on would mislabel a
  cross-compiled result. *)
function ProbeTargetName: string;

implementation

constructor TProbe.Create(const aKey, aActual, aExpected, aDetail: string;
                          const aOutcome: TProbeOutcome);
begin
   inherited Create;
   FKey      := aKey;
   FActual   := aActual;
   FExpected := aExpected;
   FDetail   := aDetail;
   FOutcome  := aOutcome;
end;

constructor TProbeReport.Create(const aTarget: string);
begin
   inherited Create;
   FProbes := TList.Create;
   FTarget := aTarget;
end;

destructor TProbeReport.Destroy;
var
   i: integer;
begin
   if FProbes <> nil then
      begin
      for i := 0 to FProbes.Count - 1 do
         begin
         TProbe(FProbes[i]).Free;
         end;
      FProbes.Free;
      end;
   inherited Destroy;
end;

procedure TProbeReport.Expect(const aKey, aActual, aExpected: string);
var
   outcome: TProbeOutcome;
begin
   if aActual = aExpected then
      begin
      outcome := poPass;
      end
   else
      begin
      outcome := poFail;
      end;

   FProbes.Add(TProbe.Create(aKey, aActual, aExpected, '', outcome));
end;

procedure TProbeReport.Expect(const aKey: string; const aActual, aExpected: Int64);
begin
   Expect(aKey, IntToStr(aActual), IntToStr(aExpected));
end;

procedure TProbeReport.Expect(const aKey: string; const aActual, aExpected: boolean);
begin
   Expect(aKey, BoolToStr(aActual, True), BoolToStr(aExpected, True));
end;

procedure TProbeReport.Note(const aKey, aActual, aDetail: string);
begin
   FProbes.Add(TProbe.Create(aKey, aActual, '', aDetail, poNote));
end;

procedure TProbeReport.Note(const aKey: string; const aActual: Int64;
                            const aDetail: string);
begin
   Note(aKey, IntToStr(aActual), aDetail);
end;

procedure TProbeReport.Skip(const aKey, aWhy: string);
begin
   FProbes.Add(TProbe.Create(aKey, '', '', aWhy, poSkip));
end;

function TProbeReport.CountOf(const aOutcome: TProbeOutcome): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to FProbes.Count - 1 do
      begin
      if TProbe(FProbes[i]).Outcome = aOutcome then
         begin
         Inc(Result);
         end;
      end;
end;

function TProbeReport.OutcomeName(const aOutcome: TProbeOutcome): string;
begin
   case aOutcome of
      poPass: Result := 'PASS';
      poFail: Result := 'FAIL';
      poNote: Result := 'note';
      poSkip: Result := 'skip';
   else
      Result := '?';
   end;
end;

function TProbeReport.Failed: integer;
begin
   Result := CountOf(poFail);
end;

function TProbeReport.Total: integer;
begin
   Result := FProbes.Count;
end;

procedure TProbeReport.WriteConsole;
var
   i: integer;
   p: TProbe;
begin
   WriteLn('TR4W platform conformance -- ', FTarget);
   WriteLn('');

   for i := 0 to FProbes.Count - 1 do
      begin
      p := TProbe(FProbes[i]);

      case p.Outcome of
         poPass:
            begin
            WriteLn('  PASS  ', p.Key, ' = ', p.Actual);
            end;
         poFail:
            begin
            WriteLn('  FAIL  ', p.Key);
            WriteLn('          expected: ', p.Expected);
            WriteLn('          actual  : ', p.Actual);
            end;
         poNote:
            begin
            WriteLn('  note  ', p.Key, ' = ', p.Actual);
            if p.Detail <> '' then
               begin
               WriteLn('          ', p.Detail);
               end;
            end;
         poSkip:
            begin
            WriteLn('  skip  ', p.Key, ' -- ', p.Detail);
            end;
      end;
      end;

   WriteLn('');
   WriteLn(Format('=== %d passed, %d failed, %d noted, %d skipped ===',
                  [CountOf(poPass), CountOf(poFail),
                   CountOf(poNote), CountOf(poSkip)]));

   (* SAY WHAT A NOTE OWES, every run, because an unclosed debt that nobody is
     reminded of is not a debt. *)
   if CountOf(poNote) > 0 then
      begin
      WriteLn('');
      WriteLn(Format('%d probe(s) only RECORD an answer. Each is a question ' +
                     'this program cannot yet fail on --', [CountOf(poNote)]));
      WriteLn('turn one into an Expect the day its right answer is known.');
      end;
end;

(* JSON BY HAND, and it is worth saying why rather than reaching for fpjson.

  This program must build and run before anything else about a platform is
  trusted -- it is the thing that tells you whether the platform behaves. The
  fewer units between it and the RTL, the fewer ways it can fail for a reason
  that is not the answer it was asked for. Its own output format is not a place
  that wants a dependency.

  The escaping below covers what a probe value can contain: quotes, backslashes
  (Windows paths), and control characters (a SysErrorMessage can carry one). *)
function TProbeReport.JsonEscape(const aValue: string): string;
var
   i: integer;
   c: char;
begin
   Result := '';
   for i := 1 to Length(aValue) do
      begin
      c := aValue[i];
      case c of
         '"':  Result := Result + '\"';
         '\':  Result := Result + '\\';
         #8:   Result := Result + '\b';
         #9:   Result := Result + '\t';
         #10:  Result := Result + '\n';
         #12:  Result := Result + '\f';
         #13:  Result := Result + '\r';
      else
         if c < ' ' then
            begin
            Result := Result + '\u' + LowerCase(IntToHex(Ord(c), 4));
            end
         else
            begin
            Result := Result + c;
            end;
      end;
      end;
end;

procedure TProbeReport.WriteJson(const aPath: string);
var
   f: TextFile;
   i: integer;
   p: TProbe;
   sep: string;
begin
   AssignFile(f, aPath);
   Rewrite(f);
   try
      WriteLn(f, '{');
      WriteLn(f, '  "target": "', JsonEscape(FTarget), '",');
      WriteLn(f, '  "probes": {');

      for i := 0 to FProbes.Count - 1 do
         begin
         p := TProbe(FProbes[i]);

         if i < FProbes.Count - 1 then
            begin
            sep := ',';
            end
         else
            begin
            sep := '';
            end;

         WriteLn(f, '    "', JsonEscape(p.Key), '": {',
                    '"outcome": "', OutcomeName(p.Outcome), '", ',
                    '"actual": "', JsonEscape(p.Actual), '", ',
                    '"expected": "', JsonEscape(p.Expected), '", ',
                    '"detail": "', JsonEscape(p.Detail), '"}', sep);
         end;

      WriteLn(f, '  },');
      WriteLn(f, '  "passed": ',  CountOf(poPass), ',');
      WriteLn(f, '  "failed": ',  CountOf(poFail), ',');
      WriteLn(f, '  "noted": ',   CountOf(poNote), ',');
      WriteLn(f, '  "skipped": ', CountOf(poSkip));
      WriteLn(f, '}');
   finally
      CloseFile(f);
   end;
end;

function ProbeTargetName: string;
begin
{$IFDEF WINDOWS}
   Result := 'windows';
{$ENDIF}
{$IFDEF LINUX}
   Result := 'linux';
{$ENDIF}
{$IFDEF DARWIN}
   Result := 'darwin';
{$ENDIF}

   (* NAMED BY THE BUILD, so a target nobody taught this routine about is a
     LOUD blank rather than a file that quietly overwrites another's. *)
   if Result = '' then
      begin
      Result := 'UNKNOWN-TARGET';
      end;

   Result := Result + '-' + {$I %FPCTARGETCPU%};
end;

end.

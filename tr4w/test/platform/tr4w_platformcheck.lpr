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

(* TR4W PLATFORM CONFORMANCE -- ASK THE PLATFORM, CHECK THE ANSWER.

    tr4w_platformcheck [<output directory>]

  Writes platformcheck-<target>.json beside the console report and exits
  non-zero if any probe with a known right answer disagreed.

  WHY IT EXISTS. NY4I, 2026-09-09: "is it possible for us to look at all the
  things we ask the platform and confirm the answer we expect ... maybe that
  will help short-circuit some of these problems."

  The problems in question all have one shape. The source reads correctly, no
  compiler and no lint objects, and the platform simply answers differently --
  a thread-close that returns zero for success where Windows returns zero for
  failure, a path split that depends on a separator this file system does not
  have, a library name that is really an assumption about the operating
  system. None of that fails a build. It surfaces on a bench, days later, as a
  symptom several steps from its cause.

  WHAT IT CANNOT DO, and this is worth being plain about because a conformance
  suite that is believed to cover more than it does is worse than none:

    * IT CANNOT CATCH A LOGIC BUG. On the same day this was asked for, a font
      height stored NEGATED disabled caption fitting for every panel on the
      main window. Nothing about that is a platform question; both platforms
      answered correctly and TR4W asked the wrong one.

    * IT ONLY COVERS WHAT SOMEONE THOUGHT TO ASK. Its value grows one probe
      at a time, and the rule for adding one is in uPlatformProbes: a probe
      earns its place by having been a DEFECT first. A suite grown from
      speculation is a suite nobody maintains.

    * A `note` PROVES NOTHING. Only Expect can fail, and only failure protects
      anything. The notes are a survey whose job is to be turned into
      expectations.

  RUN IT ON WINDOWS TOO. TR4W was written against Win32, so Windows is the
  reference its assumptions were formed from; a result from Linux alone says
  what Linux does, not where the two differ, which is the only interesting
  question. *)
program tr4w_platformcheck;

{$MODE DELPHI}
{$H+}

uses
   SysUtils,
   uProbeReport,
   uPlatformProbes;

var
   report:  TProbeReport;
   outDir:  string;
   outFile: string;
begin
   if ParamCount >= 1 then
      begin
      outDir := IncludeTrailingPathDelimiter(ParamStr(1));
      end
   else
      begin
      outDir := IncludeTrailingPathDelimiter(GetCurrentDir);
      end;

   report := TProbeReport.Create(ProbeTargetName);
   try
      RunHeadlessProbes(report);
      report.WriteConsole;

      outFile := outDir + 'platformcheck-' + ProbeTargetName + '.json';
      try
         report.WriteJson(outFile);
         WriteLn('');
         WriteLn('  written: ', outFile);
      except
         on E: Exception do
            begin
            (* REPORTED, AND IT STILL FAILS THE RUN IF A PROBE FAILED. A file
              that could not be written is a problem with the invocation, not
              with the platform, and must not be able to turn a red result
              green. *)
            WriteLn('');
            WriteLn('  COULD NOT WRITE ', outFile, ': ', E.Message);
            end;
      end;

      if report.Failed > 0 then
         begin
         Halt(1);
         end;
   finally
      report.Free;
   end;
end.

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
unit uFirstRunConvert;
{$I ..\..\tr4w.inc}

(*
  THE FIRST START AFTER AN UPGRADE: OFFER TO RUN tr4wconvert.

  NY4I, 2026-09-20: "the answer is when we first run, if you do see an INI
  file but no json file, should you immediately ask them to run the convert
  program? Warn them if they continue, they could overwrite some saved
  settings in the new program?"

  WHAT THIS IS NOT.  An in-program detector for a leftover ini existed and was
  removed the day before this was written -- "it frankly kept getting in the
  way and causing confusion" -- and nothing here may grow back into it.  The
  condition lives in uLegacyConversionCheck and is two file tests; read the
  note there for why it can fire at most once in a station's life and needs no
  remembered answer.

  IT OFFERS TO RUN THE PROGRAM, IT DOES NOT DICTATE A COMMAND.  An operator who
  is told to open a command prompt and type something has been handed a chore
  at the worst possible moment.  tr4wconvert already reports what it would
  change and asks before writing -- defaulting to No -- so launching it is not
  taking a decision away from anybody; it is saving them the typing.

  IT WAITS.  TR4W is about to load the settings file the converter writes, so
  starting it and carrying on would be a race against the operator's own
  answer.  Waiting is correct here and nowhere else: this happens once, before
  any window exists.

  AND IT CHECKS THE RESULT ON DISK RATHER THAN BELIEVING THE EXIT CODE.
  tr4wconvert exits 0 whether it converted or the operator declined, which is
  right for a shell script and useless as a test of what happened.  Two other
  things also end with nothing converted -- an operator who answered No, and a
  launch with no terminal for it to ask in, which is what happens off Windows
  from a desktop icon.  All three deserve the same honest sentence, and
  "did the settings file appear" is the one test that covers them.

  NO LOOP.  The offer is made once per start, the outcome is reported once,
  and TR4W continues either way.

  HEADLESS NEVER SEES ANY OF IT -- the caller in uProgramMain is guarded by
  tSilentExport, for the reason every modal there is: the golden-master corpus
  drives thirteen /EXPORT runs with nobody to dismiss a dialog.
*)

interface

(* Ask, and act on the answer.  Silent and immediate when the condition does
  not hold, which is every start but the first after an upgrade.

  BOTH PATHS ARE PASSED IN rather than resolved here: the caller knows which
  two files this start is actually using -- a --settings switch moves them
  both -- and resolving them a second time is how the offer ends up asking
  about a file the program does not read. *)
procedure OfferFirstRunConversion(const aLegacyIniPath: string;
                                  const aSettingsFilePath: string);

(* True when the offer was made this start and the settings were NOT carried
  across.

  IT EXISTS FOR ONE CALLER AND ONE REASON.  OfferToRetireLegacyIni runs much
  later and offers to DELETE the old ini, on the strength of a settings file
  existing -- and after this offer is declined a settings file DOES exist,
  full of defaults, with nothing converted into it.  Offering to delete an
  operator's only copy of their 4.x configuration minutes after they said
  "not now" is the one way this feature could destroy something, so it is
  suppressed for the rest of the session. *)
function FirstRunConversionDeclined: boolean;

implementation

uses
   SysUtils,
   Dialogs,         (* QuestionDlg, ShowMessage -- the LCL's own, no HWND *)
   Controls,        (* mrYes / mrNo *)
   uAppPaths,       (* SiblingProgramPath -- where tr4wconvert is, per platform *)
   uAppStrings,
   uLegacyConversionCheck,
   uPlatformProcess,   (* RunConsoleProgramAndWait -- the ONE process launcher *)
   MainUnit;           (* logger *)

var
   (* Session state, and deliberately not persisted.  There is nothing to
     remember across starts: the condition cannot hold twice. *)
   GDeclined: boolean = False;


function FirstRunConversionDeclined: boolean;
begin
   Result := GDeclined;
end;


(* The conversion program ships beside TR4W -- full.nsi installs
  tr4wconvert.exe into the same directory as tr4w.exe, and FullBuild puts it
  beside the binary in the tree.  uAppPaths owns both halves of that
  sentence: which directory, and what an executable is called here. *)
function ConverterPath: string;
begin
   Result := SiblingProgramPath('tr4wconvert');
end;


procedure OfferFirstRunConversion(const aLegacyIniPath: string;
                                  const aSettingsFilePath: string);
var
   converter: string;
   exitStatus: integer;
   started: boolean;
begin
   if not LegacyConversionOffered(aLegacyIniPath, aSettingsFilePath) then
      begin
      Exit;
      end;

   logger.Info('[FirstRun] %s is present and %s is not -- offering to convert',
               [aLegacyIniPath, aSettingsFilePath]);

   (* THE ANSWER IS READ AS A RESULT, NEVER BY POSITION.  Windows draws the
     affirmative button first and GTK draws it last; the decision to follow
     the desktop rather than force one order is NY4I's (2026-09-09) and is
     written up at MainUnit.YesOrNo.  Comparing mrYes is what makes that
     difference harmless.

     'IsDefault' binds to the button BEFORE it, so Convert now is the
     default.  That is the recommended action, and pressing it by accident
     costs nothing: tr4wconvert asks its own question and defaults to No. *)
   if QuestionDlg(SFirstRunConvertTitle,
                  Format(SFirstRunConvertPrompt,
                         [aLegacyIniPath, aSettingsFilePath]),
                  mtConfirmation,
                  [mrYes, SFirstRunConvertNow, 'IsDefault',
                   mrNo,  SFirstRunConvertSkip], 0) <> mrYes then
      begin
      GDeclined := True;
      logger.Info('[FirstRun] operator chose to continue without converting');
      Exit;
      end;

   converter := ConverterPath;
   if not FileExists(converter) then
      begin
      GDeclined := True;
      logger.Warn('[FirstRun] the conversion program is not there: %s',
                  [converter]);
      ShowMessage(Format(SFirstRunConvertMissing, [converter]));
      Exit;
      end;

   (* BOTH FILES, EXPLICITLY, AND NEITHER RE-DERIVED.  Left to itself
     tr4wconvert resolves both the same way the program does, which is the
     right default for an operator typing it -- but "the same way" includes a
     portable settings folder beside the BINARY and this program's own path
     rules, and the two can only be guaranteed to agree by naming the files.
     A converter that writes a file the program does not read, or reads an ini
     that is not the one this offer was made about, fails in silence.

     The command line is built in uLegacyConversionCheck beside the condition
     -- it is a pure function of the same two paths, and that is what makes it
     assertable from the test binary, which cannot load this unit. *)
   started := RunConsoleProgramAndWait(converter,
                                       LegacyConversionArguments(aLegacyIniPath,
                                                                 aSettingsFilePath),
                                       exitStatus);

   if not started then
      begin
      (* The launch itself failed; uPlatformProcess has already logged why. *)
      GDeclined := True;
      ShowMessage(Format(SFirstRunConvertMissing, [converter]));
      Exit;
      end;

   logger.Info('[FirstRun] tr4wconvert finished, exit status %d', [exitStatus]);

   (* THE FILE IS THE EVIDENCE -- see the unit header for why the exit code is
     not.  If it is there, the conversion wrote it and TR4W is about to load
     it; nothing more needs saying to the operator, who has just watched the
     converter say it. *)
   if FileExists(aSettingsFilePath) then
      begin
      logger.Info('[FirstRun] %s now exists -- the settings were converted',
                  [aSettingsFilePath]);
      Exit;
      end;

   GDeclined := True;
   logger.Info('[FirstRun] nothing was converted -- %s still does not exist',
               [aSettingsFilePath]);
   ShowMessage(Format(SFirstRunConvertNothingDone, [converter]));
end;

end.

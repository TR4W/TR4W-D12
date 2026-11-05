(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* COMING BACK TO TR4W RAISES EVERY TR4W WINDOW, MAIN ON TOP (NY4I, bench,
  2026-11-01). The z-order itself needs a running program and is on the
  bench queue; what is pinned here is the DECISION -- when the raise runs,
  and which windows go up with the main one -- because a wrong answer there
  is either a raise over a modal or a hidden window shown. See
  uMainForm.TR4WWindowsShouldRaise. *)
unit uTestActivationRaise;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TActivationRaiseTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_RaisesWhenActiveAndNothingBlocks;
      procedure Test_NeverOverAModal;
      procedure Test_NotWhenTheOperatorLeftAgain;
      procedure Test_NotForAHiddenOrMinimisedMainWindow;
      procedure Test_NotOnTheWayOut;
      procedure Test_WhichWindowsGoUpWithTheMainOne;
      procedure Test_ARaiseCannotFeedItself;
      procedure Test_ArmingCountsAsARaise;
      procedure Test_OnlyTheFinishedRestoreArmsTheRaise;
   end;

implementation

uses
   SysUtils,
   uMainForm,
   uTestAutomaticXQSO;   (* SourceText -- a file under tr4w/src, as text *)

(* ISSUE 219. Arming is done by the tool-window restore, which has just
  raised the main window, so arming counts as a raise: an application
  activation still queued from start-up is an echo and raises nothing. *)
procedure TActivationRaiseTests.Test_ArmingCountsAsARaise;
var
   before: QWord;
   armedAt: QWord;
begin
   BeginTest('Test_ArmingCountsAsARaise');
   CheckTrue(ActivationRaiserLastRaiseMs = 0,
             'nothing in the test binary has armed the raise');

   before := SysUtils.GetTickCount64;
   ArmActivationRaiser;
   try
      armedAt := ActivationRaiserLastRaiseMs;
      CheckTrue(armedAt >= before, 'arming stamps the raise as just done');
      CheckTrue(IsActivationEcho(armedAt, armedAt),
                'so an activation queued from start-up is an echo');

      ArmActivationRaiser;
      CheckTrue(ActivationRaiserLastRaiseMs = armedAt, 'a second arm does nothing');
   finally
      DisarmActivationRaiser;
   end;
   CheckTrue(ActivationRaiserLastRaiseMs = 0, 'disarmed');
end;

(* THE ORDER, read from the source because no headless test can run start-up:
  the restore opens its windows without handing focus back, focuses the call
  window once, and arms the raise after that -- and nothing earlier in
  start-up arms it. *)
procedure TActivationRaiseTests.Test_OnlyTheFinishedRestoreArmsTheRaise;
var
   mainText: string;
   formText: string;
   startupText: string;
   focusAt: integer;
   armAt: integer;
   addAt: integer;
   schedAt: integer;
begin
   BeginTest('Test_OnlyTheFinishedRestoreArmsTheRaise');

   mainText := SourceText('MainUnit.pas');
   CheckTrue(Pos('OpenTR4WWindow(i, False);', mainText) > 0,
             'the restore opens each window without handing focus back');

   focusAt := Pos('FocusEntry(TR4WCallEdit, True);', mainText);
   armAt := Pos('ArmActivationRaiser;', mainText);
   CheckTrue(focusAt > 0, 'the restore focuses the call window once');
   CheckTrue(armAt > focusAt, 'and arms the raise after that');

   startupText := SourceText('uProgramMain.pas');
   CheckEquals(0, Pos('ArmActivationRaiser', startupText),
               'start-up does not arm it before the restore');

   (* ONE place adds the handler, and it is ArmActivationRaiser's body --
     ScheduleMainWindowActivation, which runs before the restore, no longer
     does. *)
   formText := SourceText('ui' + PathDelim + 'lcl' + PathDelim + 'uMainForm.pas');
   addAt := Pos('AddOnActivateHandler(GActivationRaiser', formText);
   CheckTrue(addAt > 0, 'the handler is added somewhere');
   CheckEquals(0, Pos('AddOnActivateHandler(GActivationRaiser',
                      Copy(formText, addAt + 1, MaxInt)),
               'in exactly one place');
   (* The BODIES, so the interface declarations are skipped: a body's header
     is followed by begin. *)
   armAt := Pos(#10 + 'procedure ArmActivationRaiser;' + LineEnding + 'begin', formText);
   schedAt := Pos(#10 + 'procedure ScheduleMainWindowActivation;' + LineEnding +
                  'begin', formText);
   CheckTrue((armAt > 0) and (schedAt > armAt), 'both bodies are found, in that order');
   CheckTrue((addAt > armAt) and (addAt < schedAt),
             'inside ArmActivationRaiser, not ScheduleMainWindowActivation');
end;

procedure TActivationRaiseTests.Test_RaisesWhenActiveAndNothingBlocks;
begin
   BeginTest('Test_RaisesWhenActiveAndNothingBlocks');
   CheckTrue(TR4WWindowsShouldRaise(True, True, False, False, False),
             'active, main showing, not minimised, no modal: raise');
end;

(* The modal is the window that must be in front. *)
procedure TActivationRaiseTests.Test_NeverOverAModal;
begin
   BeginTest('Test_NeverOverAModal');
   CheckFalse(TR4WWindowsShouldRaise(True, True, False, True, False),
              'a modal is up: nothing is raised');
end;

(* The raise is queued; by the time it runs the operator may be elsewhere,
  and pulling TR4W back in front of him would be stealing focus. *)
procedure TActivationRaiseTests.Test_NotWhenTheOperatorLeftAgain;
begin
   BeginTest('Test_NotWhenTheOperatorLeftAgain');
   CheckFalse(TR4WWindowsShouldRaise(False, True, False, False, False),
              'TR4W is no longer the active application: nothing is raised');
end;

procedure TActivationRaiseTests.Test_NotForAHiddenOrMinimisedMainWindow;
begin
   BeginTest('Test_NotForAHiddenOrMinimisedMainWindow');
   CheckFalse(TR4WWindowsShouldRaise(True, False, False, False, False),
              'the main window is not showing');
   CheckFalse(TR4WWindowsShouldRaise(True, True, True, False, False),
              'the main window is minimised');
end;

procedure TActivationRaiseTests.Test_NotOnTheWayOut;
begin
   BeginTest('Test_NotOnTheWayOut');
   CheckFalse(TR4WWindowsShouldRaise(True, True, False, False, True),
              'the application is terminating');
end;

(* Arguments: isMain, showing, minimised, hasParent, isHint. *)
procedure TActivationRaiseTests.Test_WhichWindowsGoUpWithTheMainOne;
begin
   BeginTest('Test_WhichWindowsGoUpWithTheMainOne');
   CheckTrue(RaisedWithTheMainWindow(False, True, False, False, False),
             'a showing top-level tool window goes up');
   CheckFalse(RaisedWithTheMainWindow(True, True, False, False, False),
              'the main window is raised separately, last');
   CheckFalse(RaisedWithTheMainWindow(False, False, False, False, False),
              'a hidden window stays hidden');
   CheckFalse(RaisedWithTheMainWindow(False, True, True, False, False),
              'a minimised window stays minimised');
   CheckFalse(RaisedWithTheMainWindow(False, True, False, True, False),
              'a form docked in another control is not a window of its own');
   CheckFalse(RaisedWithTheMainWindow(False, True, False, False, True),
              'a hint is not raised');
end;

(* gtk2 derives activation from per-window focus, so a raise can produce an
  activation of its own; inside the echo window it must not raise again. *)
procedure TActivationRaiseTests.Test_ARaiseCannotFeedItself;
begin
   BeginTest('Test_ARaiseCannotFeedItself');
   CheckFalse(IsActivationEcho(5000, 0),
              'no raise has run yet: nothing is an echo');
   CheckTrue(IsActivationEcho(5000, 5000),
             'at the moment of the raise: echo');
   CheckTrue(IsActivationEcho(5000 + ACTIVATION_ECHO_MS - 1, 5000),
             'just inside the window: echo');
   CheckFalse(IsActivationEcho(5000 + ACTIVATION_ECHO_MS, 5000),
              'at the end of the window: the operator again');
   CheckFalse(IsActivationEcho(4000, 5000),
              'a clock reading before the raise is never an echo');
end;

procedure TActivationRaiseTests.RunAllTests;
begin
   Test_ARaiseCannotFeedItself;
   Test_RaisesWhenActiveAndNothingBlocks;
   Test_NeverOverAModal;
   Test_NotWhenTheOperatorLeftAgain;
   Test_NotForAHiddenOrMinimisedMainWindow;
   Test_NotOnTheWayOut;
   Test_WhichWindowsGoUpWithTheMainOne;
   Test_ArmingCountsAsARaise;
   Test_OnlyTheFinishedRestoreArmsTheRaise;
end;

end.

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
   end;

implementation

uses
   uMainForm;

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
end;

end.

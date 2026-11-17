unit uTestStartupTaskBar;

(* WHO CARRIES TR4W'S TASKBAR BUTTON (2026-11-16).

   Before the main window shows, the hidden Application window carries the
   button (tbSingleButton), so the pinned icon shows TR4W running while the New
   Contest dialog is up; once it shows, the main form carries it (tbDefault).
   See uLCLCoexist.StartupTaskBarBehavior.

   And a modal is owned by the main window only while that window is ON SCREEN:
   owned by the hidden main form CreateMainWindow builds, a startup dialog would
   be cut off from the Application window's button.

   The taskbar itself is a GUI question (tools/gui_test); these pin the two
   decisions. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TStartupTaskBarTests = class(TTestCase)
   protected
      procedure TestTheApplicationCarriesTheButtonUntilTheMainWindowShows;
      procedure TestAModalIsOwnedOnlyByAMainWindowOnScreen;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Forms,
   uLCLCoexist,
   uLCLFormHelpers,
   uMainForm,
   uTestMainFormHarness;   (* EnsureTestMainForm / ReleaseTestMainForm *)

procedure TStartupTaskBarTests.TestTheApplicationCarriesTheButtonUntilTheMainWindowShows;
begin
   BeginTest('TestTheApplicationCarriesTheButtonUntilTheMainWindowShows');
   CheckTrue(StartupTaskBarBehavior(False) = tbSingleButton,
             'no main window on screen: the Application window has the one button');
   CheckTrue(StartupTaskBarBehavior(True) = tbDefault,
             'main window on screen: it has the button, the Application window none');
end;

(* THE CASE THAT CHANGED: the main form exists -- streamed, as CreateMainWindow
  builds it -- and has not been shown. The legacy-ini question is asked then. *)
procedure TStartupTaskBarTests.TestAModalIsOwnedOnlyByAMainWindowOnScreen;
var
   dialog:      TForm;
   madeTheForm: boolean;
begin
   BeginTest('TestAModalIsOwnedOnlyByAMainWindowOnScreen');
   madeTheForm := TR4WMainForm = nil;
   EnsureTestMainForm;
   dialog := TForm.CreateNew(nil);
   try
      CheckTrue(TR4WMainForm <> nil, 'the main form exists');
      CheckTrue(not MainWindowShowing, 'streamed, never shown: not on screen');

      OwnFormByMainWindow(dialog);
      CheckTrue(dialog.PopupMode = pmNone,
                'a hidden main window owns nothing: left to the Application window');
      CheckTrue(dialog.PopupParent = nil, 'no owner form nominated');
   finally
      dialog.Free;
      if madeTheForm then
         begin
         ReleaseTestMainForm;
         end;
   end;
end;

procedure TStartupTaskBarTests.RunAllTests;
begin
   TestTheApplicationCarriesTheButtonUntilTheMainWindowShows;
   TestAModalIsOwnedOnlyByAMainWindowOnScreen;
end;

end.

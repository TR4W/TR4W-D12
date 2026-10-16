unit uTestNewContestForm;
{$I ..\..\src\tr4w.inc}

(* THE NEW CONTEST DIALOG NAMES THE BUILD IN ITS TITLE.

  NY4I, 2026-10-16: the first window of a session read
  " - Open configuration file or start a new contest" -- no program name and no
  version, so he could not see which build he was running. Two writers set the
  caption: uNewContest.PrepareForm wrote TR4W_CURRENTVERSION + the constant,
  and the form's own OnShow, which runs AFTER it, overwrote that with the bare
  constant -- a string that starts with ' - ' because it was written to follow
  the version. The form is the one writer now.

  THE FORM IS STREAMED FROM ITS RESOURCE AND ITS OnShow IS INVOKED THROUGH THE
  EVENT THE .lfm WIRES, not by calling HandleShow by name -- so this also fails
  if the .lfm stops binding OnShow, which is the half a pin on the caption
  function alone could not see. It is never shown: Show would put a window on
  the desktop of whoever runs the suite. *)

interface

uses
   SysUtils, Classes, Forms,
   uTR4WTestFramework,
   uTR4WStrings,      (* TC_OPENCONFIGURATIONFILE *)
   Version,           (* TR4W_CURRENTVERSION *)
   uNewContestForm;

type
   TNewContestFormTests = class(TTestCase)
   protected
      procedure Test_TheCaptionFunctionNamesTheBuild;
      procedure Test_TheShownFormNamesTheBuild;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TNewContestFormTests.Test_TheCaptionFunctionNamesTheBuild;
var
   caption: string;
begin
   BeginTest('Test_TheCaptionFunctionNamesTheBuild');

   caption := NewContestFormCaption;
   CheckEquals(TR4W_CURRENTVERSION + TC_OPENCONFIGURATIONFILE, caption,
               'the title is the version followed by what the dialog is for');
   CheckTrue(Pos(TR4W_CURRENTVERSION, caption) = 1,
             'the title STARTS with the program name and version');
end;

procedure TNewContestFormTests.Test_TheShownFormNamesTheBuild;
var
   frm: TfrmNewContest;
begin
   BeginTest('Test_TheShownFormNamesTheBuild');

   (* The widget set must be initialised before a control needs a window --
     see uTestStatusAndNotice.EnsureMainForm, which does the same. It starts no
     message loop. *)
   if Application <> nil then
      begin
      Application.Initialize;
      end;

   frm := TfrmNewContest.Create(nil);
   try
      CheckTrue(Assigned(frm.OnShow),
                'uNewContestForm.lfm must wire OnShow -- it is the caption''s writer');
      if Assigned(frm.OnShow) then
         begin
         frm.OnShow(frm);
         end;

      CheckTrue(Pos(TR4W_CURRENTVERSION, frm.Caption) = 1,
                'after OnShow the title starts with the version, got "' +
                frm.Caption + '"');
      CheckEquals(NewContestFormCaption, frm.Caption,
                  'after OnShow the title is the one the form owns');
   finally
      frm.Free;
   end;
end;

procedure TNewContestFormTests.RunAllTests;
begin
   Test_TheCaptionFunctionNamesTheBuild;
   Test_TheShownFormNamesTheBuild;
end;

end.

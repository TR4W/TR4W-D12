unit uIniRetireForm;
{$I ..\..\tr4w.inc}

{
  "REMOVE THE OLD SETTINGS FILE?" -- WITH THE SECOND QUESTION ASKED SEPARATELY.

  This was a MessageDlg with Yes and No, and the prompt text carried a sentence
  saying that choosing No would also stop TR4W ever asking again.  NY4I,
  2026-08-23: "Answering No answers that question but should not implicitly also
  set the option to not be asked again."

  He is right, and it is not a wording problem.  "Remove the file?" and "should
  I stop asking?" are two questions, and No answers only the first.  An operator
  who is not ready to delete a file today has said nothing about tomorrow --
  and the old dialog recorded a permanent answer from that silence, with no way
  back except editing keepLegacyIni in settings\tr4w.json by hand.

  So: Yes / No for the file, and a separate "do not ask me again" check box for
  the second question, which is the ordinary way this is done.  A form rather
  than a MessageDlg because MessageDlg cannot carry a check box -- that
  limitation is the whole reason the two questions were ever conflated.
}

interface

uses
  Forms, Controls, StdCtrls, Classes;

type
  TfrmIniRetire = class(TForm)
    lblPrompt: TLabel;
    chkDontAsk: TCheckBox;
    btnYes: TButton;
    btnNo: TButton;
  end;

{ Ask.  Returns True when the operator wants the file removed.  aDontAskAgain is
  the SEPARATE answer, and is False unless the box was ticked -- including when
  the dialog is dismissed with Escape or the X, which says nothing about either
  question and must therefore not be recorded as an answer to one. }
function AskToRetireLegacyIni(const aPrompt: string;
                              out aDontAskAgain: boolean): boolean;

implementation

{$R *.lfm}

uses
  uAppStrings,
  uLCLFormHelpers;   { OwnFormByMainWindow }

function AskToRetireLegacyIni(const aPrompt: string;
                              out aDontAskAgain: boolean): boolean;
var
  f: TfrmIniRetire;
begin
   Result         := False;
   aDontAskAgain  := False;

   f := TfrmIniRetire.Create(nil);
   try
      OwnFormByMainWindow(f);
      f.Caption          := SIniRetireTitle;
      f.lblPrompt.Caption := aPrompt;
      f.chkDontAsk.Caption := SIniRetireDontAsk;

      Result        := f.ShowModal = mrYes;
      aDontAskAgain := f.chkDontAsk.Checked;
   finally
      f.Free;
   end;
end;

end.

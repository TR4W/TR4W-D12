unit uAboutForm;
{$I ..\..\tr4w.inc}

{
  THE ABOUT BOX, AS A DESIGNED LCL FORM.

  WHAT IT REPLACES.  A raw MessageBox showing tAboutText, with the OpenGL
  "about" dialog (uAbout.pas, dialog 68) compiled out beside it behind
  an $IF OGLVERSION switch -- which is False and has been for the life of this tree.  So
  the operator saw a system message box with five lines of text in it.

  WHY BOTHER.  Three reasons, in order of weight:

  1. It is one of the last Win32 windows the program creates.  MessageBox does
     not exist off Windows, and docs/ROADMAP.md section 2 lists it among the
     calls that have to go.
  2. A message box cannot be edited by anyone.  This form opens in the Lazarus
     designer, which is the whole point of the .lfm rule (NY4I, 2026-08-22).
  3. The website line was TEXT in a message box.  Here it is a link the operator
     can click, through LCLIntf.OpenURL -- the cross-platform launcher, not
     ShellExecute.

  NO NEW ENGLISH STRINGS INVENTED.  The content is the same constants the message
  box composed -- version, date, server version, credits -- assembled at run time
  rather than typed into the .lfm, so a version bump does not have to be made in
  two places with one of them missed.
}

interface

uses
  Forms, StdCtrls, Controls, Classes;

type
  TfrmAbout = class(TForm)
    memAbout: TMemo;
    lblURL: TLabel;
    btnOK: TButton;
    procedure lblURLClick(Sender: TObject);
    procedure HandleShow(Sender: TObject);
  end;

{ Modal, and owned by nothing: the caller does not keep it.  Matches how the
  message box behaved -- open, read, close. }
procedure ShowAboutBox;

implementation

{$R *.lfm}

uses
  LCLIntf,        // OpenURL -- the cross-platform launcher
  uLCLFormHelpers,
  Version;        // TR4W_CURRENTVERSION and friends

const
  { The one place the site appears, so the label and the link cannot disagree. }
  TR4W_WEBSITE = 'http://www.tr4w.net';

procedure TfrmAbout.lblURLClick(Sender: TObject);
begin
   // OpenURL, NOT ShellExecute: ShellExecute is Windows-only and is one of the
   // calls the platform lint counts down to zero.
   OpenURL(TR4W_WEBSITE);
end;

procedure TfrmAbout.HandleShow(Sender: TObject);
begin
   // BUILT HERE, not typed into the .lfm.  These are the same constants the
   // MessageBox composed; putting them in the designer would mean a version bump
   // had to be made in two places.
   memAbout.Lines.BeginUpdate;
   try
      memAbout.Lines.Clear;
      memAbout.Lines.Add(TR4W_CURRENTVERSION + ' - ' + TR4W_CURRENTVERSIONDATE);
      memAbout.Lines.Add('');
      memAbout.Lines.Add('(C) 2013 - 2026 TR4W Development Team');
      memAbout.Lines.Add('Original Win32 Port by Dmitriy Gulyaev UA4WLI (2006-2012)');
      memAbout.Lines.Add('Original TRLOG DOS (v 6.80) code by Larry Tyree N6TR');
      memAbout.Lines.Add('');
      memAbout.Lines.Add('TR4WSERVER version - ' + TR4WSERVER_CURRENTVERSION);
      memAbout.Lines.Add('');
      memAbout.Lines.Add('Current development team = N4AF, NY4I, Claude Code');
   finally
      memAbout.Lines.EndUpdate;
   end;

   lblURL.Caption := TR4W_WEBSITE;
end;

procedure ShowAboutBox;
var
   frm: TfrmAbout;
begin
   frm := TfrmAbout.Create(nil);
   try
      OwnFormByMainWindow(frm);
      frm.ShowModal;
   finally
      frm.Free;
   end;
end;

end.

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
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uFMXDesignedProbe;

{
  THROWAWAY, like uFMXSpikeForm -- and deliberately SEPARATE from it.

  THE ONE QUESTION.  Every FMX form in TR4W so far is built in code and
  constructed with CreateNew, the explicitly no-resource constructor.  Before we
  decide to design forms in the IDE instead, one thing has to be true: that FMX
  form STREAMING works in this program.  That is not obvious here, because TR4W
  never calls Application.Run, has no Application.MainForm, and never calls
  Application.CreateForm -- and this project has already produced one surprise
  of exactly that shape (FMX refused to activate any form because
  ApplicationState was not Running; see uFMXCoexist).

  WHY NOT JUST CONVERT uFMXSpikeForm.  Its own header asks for this: a designer
  form would have answered two questions at once -- "does FMX coexist with the
  message loop" and "does form streaming work" -- and a failure would not say
  which.  The coexistence spike has now passed, so this asks the second question
  on its own, and the first stays answered by a form that is still code-built.

  WHAT PASSING LOOKS LIKE, all four together:
    1. The window opens at all.  If the .fmx is missing from the resource or its
       class name does not match, the inherited constructor raises instead --
       that alone is the headline result.
    2. The label text below is visible.  That proves PROPERTIES streamed, not
       merely that a window appeared.
    3. Typing in the edit echoes to the second label.  That proves an event
       handler bound BY NAME from the .fmx to a published method -- the part
       that depends on RTTI and the published-section state of a streamed form,
       and the part most likely to break silently.
    4. A caret blinks in the edit.  Same gate the code-built forms needed; worth
       re-checking on a streamed form rather than assuming it carries over.

  Open it with the FMXDESIGN command in the call window.  Delete this unit, its
  .fmx, the dpr/dproj entries and the MainUnit command arm once the question is
  answered either way -- the durable output is the DECISION, not this form.
}

interface

uses
   Classes,
   System.UITypes,   // TCloseAction
   FMX.Forms,
   FMX.Types,
   FMX.Controls,
   FMX.StdCtrls,
   FMX.Edit,
   FMX.Controls.Presentation;

type
   TFMXDesignedProbe = class(TForm)
      lblWhat: TLabel;
      lblEcho: TLabel;
      edProbe: TEdit;
      btnClose: TButton;
      procedure edProbeChangeTracking(Sender: TObject);
      procedure btnCloseClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
   private
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var aAction: TCloseAction);
   public
      constructor Create(AOwner: TComponent); override;
   end;

// Opened by the FMXDESIGN call-window command.
procedure ShowFMXDesignedProbe;

implementation

{$R *.fmx}

uses
   Windows,
   SysUtils,    // Exception
   FMX.Platform.Win,   // FormToHWND
   MainUnit,           // logger
   uFMXCoexist;

var
   gProbe: TFMXDesignedProbe = nil;


procedure TFMXDesignedProbe.Button1Click(Sender: TObject);
begin
   ShowMessage('Hello');
end;

constructor TFMXDesignedProbe.Create(AOwner: TComponent);
begin
   // Create, NOT CreateNew.  This is the whole point of the probe: the
   // inherited constructor looks for a resource named for this class and
   // streams the .fmx into it.  If that resource is missing or misnamed, this
   // line raises EResNotFound -- which is a clear, loud answer rather than a
   // subtle one.
   inherited Create(AOwner);

   OnShow  := HandleShow;
   OnClose := HandleClose;
end;

procedure TFMXDesignedProbe.HandleShow(Sender: TObject);
begin
   // Registered here rather than in the constructor for the same reason as the
   // code-built forms: the window handle does not exist until the form is shown.
   RegisterFMXFormHandle(FormToHWND(Self));
   logger.Debug('[FMXDesignedProbe] shown -- streamed lblWhat.Text length = %d',
                [Length(lblWhat.Text)]);
end;

procedure TFMXDesignedProbe.HandleClose(Sender: TObject; var aAction: TCloseAction);
begin
   UnregisterFMXFormHandle(FormToHWND(Self));
   // Hide rather than free, matching uFMXSpikeForm: the same command reopens it.
   aAction := TCloseAction.caHide;
end;

// Bound BY NAME from the .fmx (OnChangeTracking = edProbeChangeTracking).  If
// streaming cannot resolve it, FMX raises while loading the form rather than
// leaving the handler quietly unassigned.
procedure TFMXDesignedProbe.edProbeChangeTracking(Sender: TObject);
begin
   lblEcho.Text := 'You typed: ' + edProbe.Text;
end;

procedure TFMXDesignedProbe.btnCloseClick(Sender: TObject);
begin
   Close;
end;

procedure ShowFMXDesignedProbe;
begin
   try
      if gProbe = nil then
         begin
         gProbe := TFMXDesignedProbe.Create(nil);
         end;
      gProbe.Show;
   except
      // A streaming failure must be REPORTED, not swallowed -- a silent no-op
      // would read as "the command does not work" and answer nothing.
      on E: Exception do
         begin
         logger.Error('[FMXDesignedProbe] FAILED to create the designed form: %s: %s',
                      [E.ClassName, E.Message]);
         MessageBox(0, PChar('Designed-form probe failed: ' + E.ClassName +
                             ' - ' + E.Message),
                    'FMX designed-form probe', MB_OK or MB_ICONERROR);
         end;
   end;
end;

end.

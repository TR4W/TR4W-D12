unit uTestShowOffScreen;
{$I ..\..\src\tr4w.inc}

(*
  SHOW A FORM OFF SCREEN, SO A TEST CAN MEASURE IT.

  A form that is streamed and never shown has no geometry: position, anchors,
  alignment and a grid's AutoFillColumns are applied when it is shown and laid
  out. Layout tests show the form to the left of the desktop, out of sight and
  out of the task bar, and let the LCL process the resulting messages before
  they measure. One copy, so every layout test shows a form the same way.
*)

interface

uses
   Forms;

procedure ShowOffScreen(const aForm: TCustomForm);

implementation

procedure ShowOffScreen(const aForm: TCustomForm);
begin
   aForm.Position := poDesigned;
   aForm.ShowInTaskBar := stNever;
   aForm.Left := Screen.DesktopLeft - aForm.Width - 200;
   aForm.Top := Screen.DesktopTop;
   aForm.Show;
   Application.ProcessMessages;
end;

end.

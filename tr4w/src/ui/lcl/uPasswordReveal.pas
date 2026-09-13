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
unit uPasswordReveal;
{$I tr4w.inc}

(*
  THE EYE BESIDE A PASSWORD FIELD.

  One call attaches a reveal toggle to an edit: AttachPasswordReveal(edt).
  There are five password fields across three forms and the count only goes
  up, so this is one control and one behaviour rather than five copies of
  each -- the drawing especially, which is the part nobody would keep in step.

  ------------------------------------------------------------------------
  WHY THE ICON IS DRAWN AND NOT AN IMAGE FILE
  ------------------------------------------------------------------------

  An icon downloaded from the web would mean a binary in the repository, a
  line in the installer, a resource to load, and a licence to check -- for
  two shapes that are an ellipse, a circle and a diagonal line. Drawing them
  costs about thirty lines, scales with the control, and picks up the
  operator's own colours.

  It is deliberately easy to replace: everything about the appearance is in
  Paint, and nothing else in this unit knows what an eye looks like.

  ------------------------------------------------------------------------
  WHY IT IS CREATED AT RUN TIME RATHER THAN PUT IN EACH .lfm
  ------------------------------------------------------------------------

  This tree's rule is that every WINDOW is a designed form, and that is
  unchanged -- no window is created here. What would be gained by drawing
  five identical buttons into three .lfm files is that they would appear in
  the designer; what would be lost is a single place that decides how wide
  the button is, where it sits, what it draws and what it does. The rule
  exists to stop hand-built WINDOWS, not to require copy-and-paste.

  The one visible consequence is that the edit gets narrower by the width of
  the button, which is why AttachPasswordReveal does that itself rather than
  leaving every caller to remember.

  ------------------------------------------------------------------------
  BEHAVIOUR WORTH KNOWING
  ------------------------------------------------------------------------

  IT IS NOT A TAB STOP. Tabbing through a form must reach the fields in the
  order the designer set; a button that inserted itself between them would
  change every form it is added to.

  IT RE-MASKS WHEN THE FIELD LOSES FOCUS. A revealed password left on screen
  while the operator does something else is the thing this feature is
  supposed to help with, not cause.
*)

interface

uses
   StdCtrls;

(*
  Attach a reveal toggle to a password edit.

  The edit is NARROWED to make room, and the button takes the space beside
  it -- so the field and its toggle together occupy exactly what the field
  occupied in the designer, and no .lfm needs adjusting.

  Safe to call on an edit that is not masked; the toggle is attached and
  simply stays hidden until something masks the field.

  Safe to call twice on the same edit: the second call does nothing rather
  than stacking a second button on the first.
*)
procedure AttachPasswordReveal(const aEdit: TEdit);

(*
  TELL THE TOGGLE THAT THE FIELD'S MASKING HAS CHANGED.

  FOR A DIALOG THAT IS REUSED. The generic input prompt is created once and
  masks or unmasks its field per invocation, so a toggle that read the state
  at construction would be wrong on every later use -- showing an eye beside
  a plain text box, or offering to reveal a field that is already visible.

  A form whose masking never changes after streaming does not need this.
*)
procedure SyncPasswordReveal(const aEdit: TEdit);

implementation

uses
   Classes,
   SysUtils,
   Controls,
   Graphics,
   Forms;

type
   TPasswordRevealButton = class(TCustomControl)
   private
      FEdit: TEdit;
      FRevealed: boolean;
      FMaskChar: char;
      procedure SetRevealed(aValue: boolean);
      procedure EditLostFocus(aSender: TObject);
      procedure SyncToEdit;
   protected
      procedure Paint; override;
      procedure Click; override;
   public
      constructor CreateFor(const aEdit: TEdit);
      property Revealed: boolean read FRevealed write SetRevealed;
   end;

constructor TPasswordRevealButton.CreateFor(const aEdit: TEdit);
var
   size: integer;
begin
   inherited Create(aEdit.Owner);

   FEdit := aEdit;
   FRevealed := False;
   (* THE MASK CHARACTER THE FORM CHOSE, not an assumption -- revealing sets
     it to #0 and hiding puts back whatever was there. A field that is not
     masked yet gets the usual default, which SyncToEdit corrects the moment
     the form masks it. *)
   if aEdit.PasswordChar <> #0 then
      begin
      FMaskChar := aEdit.PasswordChar;
      end
   else
      begin
      FMaskChar := '*';
      end;

   Parent := aEdit.Parent;
   size := aEdit.Height;
   SetBounds(aEdit.Left + aEdit.Width - size, aEdit.Top, size, size);
   (* AND THE FIELD GIVES UP THAT SPACE. Together they occupy exactly what
     the edit occupied before, so no designed layout moves. *)
   aEdit.Width := aEdit.Width - size;

   (* The edit's own anchors, so a form that stretches keeps the two
     together instead of leaving the button behind. *)
   Anchors := aEdit.Anchors;

   TabStop := False;
   Cursor := crHandPoint;
   ShowHint := True;
   Hint := 'Show the password';
   (* AN UNMASKED FIELD SHOWS NO EYE. There is nothing to reveal, and an eye
     beside a plain text box invites a click that would do nothing. *)
   Visible := aEdit.PasswordChar <> #0;

   (* RE-MASK ON LEAVING THE FIELD, but ONLY IF THE FORM IS NOT ALREADY
     USING THE EVENT. Taking it would silently replace the form own handler,
     and a designed event that stops firing is the kind of loss this tree has
     a lint for. A field whose form already handles OnExit simply keeps its
     reveal until the dialog closes.

     NO @ ON THE METHOD: this tree compiles in Delphi mode, where an event is
     assigned by name. The address-of form is the objfpc spelling and is a
     syntax error here. *)
   if not Assigned(aEdit.OnExit) then
      begin
      aEdit.OnExit := EditLostFocus;
      end;
end;

procedure TPasswordRevealButton.SetRevealed(aValue: boolean);
begin
   if FRevealed = aValue then
      begin
      Exit;
      end;

   FRevealed := aValue;
   if FRevealed then
      begin
      FEdit.PasswordChar := #0;
      Hint := 'Hide the password';
      end
   else
      begin
      FEdit.PasswordChar := FMaskChar;
      Hint := 'Show the password';
      end;
   Invalidate;
end;

procedure TPasswordRevealButton.EditLostFocus(aSender: TObject);
begin
   Revealed := False;
end;

procedure TPasswordRevealButton.SyncToEdit;
begin
   if FRevealed then
      begin
      (* WE are the reason it is unmasked, so there is nothing to learn from
        the field -- and re-reading it here would mistake our own doing for
        the form's. *)
      Visible := True;
      Exit;
      end;

   if FEdit.PasswordChar <> #0 then
      begin
      FMaskChar := FEdit.PasswordChar;
      end;
   Visible := FEdit.PasswordChar <> #0;
end;

procedure TPasswordRevealButton.Click;
begin
   Revealed := not FRevealed;
   inherited Click;
end;

procedure TPasswordRevealButton.Paint;
var
   w, h: integer;
   cx, cy: integer;
   eyeW, eyeH: integer;
   pupil: integer;
begin
   w := Width;
   h := Height;
   cx := w div 2;
   cy := h div 2;

   (* THE FIELD'S OWN BACKGROUND, so the button reads as part of it rather
     than as a control sitting next to it. *)
   Canvas.Brush.Color := FEdit.Color;
   Canvas.FillRect(0, 0, w, h);

   Canvas.Pen.Color := clGrayText;
   Canvas.Pen.Width := 1;
   Canvas.Brush.Style := bsClear;

   (* The outline: an ellipse a little wider than tall, inset so the stroke
     is not clipped at the edges. *)
   eyeW := (w - 6) div 2;
   eyeH := (h - 10) div 2;
   if eyeW < 3 then
      begin
      eyeW := 3;
      end;
   if eyeH < 2 then
      begin
      eyeH := 2;
      end;
   Canvas.Ellipse(cx - eyeW, cy - eyeH, cx + eyeW, cy + eyeH);

   (* The pupil, filled in the same colour as the outline. *)
   pupil := eyeH - 1;
   if pupil < 1 then
      begin
      pupil := 1;
      end;
   Canvas.Brush.Style := bsSolid;
   Canvas.Brush.Color := clGrayText;
   Canvas.Ellipse(cx - pupil, cy - pupil, cx + pupil, cy + pupil);

   (* AND THE SLASH WHEN THE PASSWORD IS SHOWING, which is the state that
     needs the stronger signal: it says "this is visible, click to hide". *)
   if FRevealed then
      begin
      Canvas.Pen.Color := clGrayText;
      Canvas.Pen.Width := 2;
      Canvas.MoveTo(cx - eyeW, cy + eyeH);
      Canvas.LineTo(cx + eyeW, cy - eyeH);
      end;
end;

(* The toggle already attached to this edit, or nil. Found by asking the
  parent rather than kept in a list: the controls are the list, and a list
  beside them is one more thing that can disagree with them. *)
function RevealButtonFor(const aEdit: TEdit): TPasswordRevealButton;
var
   i: integer;
   child: TControl;
begin
   Result := nil;
   if (aEdit = nil) or (aEdit.Parent = nil) then
      begin
      Exit;
      end;

   for i := 0 to aEdit.Parent.ControlCount - 1 do
      begin
      child := aEdit.Parent.Controls[i];
      if (child is TPasswordRevealButton) and
         (TPasswordRevealButton(child).FEdit = aEdit) then
         begin
         Result := TPasswordRevealButton(child);
         Exit;
         end;
      end;
end;

procedure AttachPasswordReveal(const aEdit: TEdit);
begin
   if aEdit = nil then
      begin
      Exit;
      end;

   (* TWICE IS ONCE. A form that is streamed again, or a helper called from
     two places, must not end up with two buttons on one field. *)
   if RevealButtonFor(aEdit) <> nil then
      begin
      Exit;
      end;

   TPasswordRevealButton.CreateFor(aEdit);
end;

procedure SyncPasswordReveal(const aEdit: TEdit);
var
   button: TPasswordRevealButton;
begin
   button := RevealButtonFor(aEdit);
   if button <> nil then
      begin
      button.SyncToEdit;
      end;
end;

end.

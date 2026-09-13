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

  IT IS DISABLED WHILE THE FIELD IS EMPTY (NY4I). There is nothing to reveal,
  and an eye that can be clicked to no effect teaches an operator that the
  control does not work. Emptying a revealed field also puts it back to
  masked, so typing the next password starts hidden rather than in the clear.

  ------------------------------------------------------------------------
  IT CHAINS THE FIELD'S EVENTS RATHER THAN TAKING THEM
  ------------------------------------------------------------------------

  It needs OnChange to know when the field becomes empty, and OnExit to
  re-mask. One of the five fields -- the cluster password -- already has a
  designed OnChange handler, so taking the event would stop that handler
  firing: a designed event that quietly stops working is a loss this tree has
  a lint for.

  So the previous handler is kept and called. Nothing a form wired in the
  designer stops happening.
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
   Types,
   Controls,
   Graphics,
   Forms;

type
   TPasswordRevealButton = class(TCustomControl)
   private
      FEdit: TEdit;
      FRevealed: boolean;
      FMaskChar: char;
      (* The handlers the FORM wired, kept so they still run. *)
      FPrevChange: TNotifyEvent;
      FPrevExit: TNotifyEvent;
      procedure SetRevealed(aValue: boolean);
      procedure EditLostFocus(aSender: TObject);
      procedure EditChanged(aSender: TObject);
      procedure UpdateEnabled;
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

   (* CHAINED, NOT TAKEN. The previous handler is remembered and called, so a
     designed event keeps firing -- the cluster password already has an
     OnChange the form wired, and replacing it would stop that working with
     nothing to say so.

     NO @ ON THE METHOD: this tree compiles in Delphi mode, where an event is
     assigned by name. The address-of form is the objfpc spelling and is a
     syntax error here. *)
   FPrevExit := aEdit.OnExit;
   aEdit.OnExit := EditLostFocus;
   FPrevChange := aEdit.OnChange;
   aEdit.OnChange := EditChanged;

   UpdateEnabled;
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
   if Assigned(FPrevExit) then
      begin
      FPrevExit(aSender);
      end;
end;

procedure TPasswordRevealButton.EditChanged(aSender: TObject);
begin
   UpdateEnabled;
   if Assigned(FPrevChange) then
      begin
      FPrevChange(aSender);
      end;
end;

(* NOTHING TO REVEAL IN AN EMPTY FIELD. *)
procedure TPasswordRevealButton.UpdateEnabled;
var
   hasText: boolean;
begin
   hasText := FEdit.Text <> '';

   (* EMPTYING A REVEALED FIELD PUTS IT BACK TO MASKED, so the next password
     typed into it starts hidden. Leaving it revealed would mean an operator
     who cleared a field to retype it did so in the clear. *)
   if not hasText then
      begin
      Revealed := False;
      end;

   if Enabled <> hasText then
      begin
      Enabled := hasText;
      Invalidate;
      end;
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
   (* The reused dialog puts a new value in the field after masking it, so
     whether there is anything to reveal has to be asked again here. *)
   UpdateEnabled;
end;

procedure TPasswordRevealButton.Click;
begin
   Revealed := not FRevealed;
   inherited Click;
end;

(*
  THE LID SHAPE, AS TWO CIRCULAR ARCS.

  The first version drew an ELLIPSE with a filled circle inside it, and NY4I
  said what the screenshot shows: a dark blob, not an eye. Two things were
  wrong and the second is the one worth remembering.

  The pupil was sized `eyeH - 1`, a RADIUS taken from a HALF-height, so its
  diameter was very nearly the whole height of the eye -- outline and fill
  touching, which reads as a filled disc.

  And an ellipse is the wrong shape. A drawn eye is a LENS: two arcs that
  meet at points on the left and right, which is what gives it the shape
  everyone recognises at 16 pixels. An ellipse has no corners, so at this
  size it is simply a circle.

  An arc through (-a, 0), (0, -b) and (a, 0) belongs to a circle of radius
  (a*a + b*b) / (2*b), and the lid is that arc mirrored. The points are
  computed and drawn as a polyline rather than handed to Canvas.Arc, because
  Arc's start and end angles are expressed as POINTS ON A BOUNDING BOX and
  the sweep direction is a platform convention -- this way the shape is the
  same on every widget set, which is the whole reason the icon is drawn.
*)
procedure TPasswordRevealButton.Paint;
var
   w, h: integer;
   cx, cy: integer;
   halfW, halfH: integer;
   radius: double;
   lid: double;
   upper, lower: array of TPoint;
   count: integer;
   i, x: integer;
   pupil: integer;
   ink: TColor;
begin
   w := Width;
   h := Height;
   cx := w div 2;
   cy := h div 2;

   (* THE FIELD'S OWN BACKGROUND, so the button reads as part of it rather
     than as a control sitting next to it. *)
   Canvas.Brush.Color := FEdit.Color;
   Canvas.FillRect(0, 0, w, h);

   (* A DISABLED EYE IS DRAWN FAINTER rather than not drawn at all: the
     control keeps its place, so the field does not change width as the
     operator types the first character, and the shape still says what the
     button is for. *)
   if Enabled then
      begin
      ink := clGrayText;
      end
   else
      begin
      ink := clSilver;
      end;

   Canvas.Pen.Color := ink;
   Canvas.Pen.Width := 1;
   Canvas.Brush.Style := bsClear;

   (* THE PROPORTIONS ARE THE ICON. Half as tall as it is wide is what makes
     a lens read as an eye; nearer to round reads as a ball. *)
   halfW := (w div 2) - 3;
   if halfW < 4 then
      begin
      halfW := 4;
      end;
   halfH := Round(halfW * 0.62);
   if halfH < 3 then
      begin
      halfH := 3;
      end;

   radius := (halfW * halfW + halfH * halfH) / (2 * halfH);

   count := 2 * halfW + 1;
   SetLength(upper, count);
   SetLength(lower, count);
   for i := 0 to count - 1 do
      begin
      x := i - halfW;
      (* How far the lid stands off the centre line at this column: zero at
        the two corners, halfH in the middle. *)
      lid := Sqrt(radius * radius - x * x) - (radius - halfH);
      upper[i] := Point(cx + x, cy - Round(lid));
      lower[i] := Point(cx + x, cy + Round(lid));
      end;
   Canvas.Polyline(upper);
   Canvas.Polyline(lower);

   (* The pupil: a small filled circle, deliberately well inside the lids. *)
   pupil := Round(halfH * 0.62);
   if pupil < 2 then
      begin
      pupil := 2;
      end;
   Canvas.Brush.Style := bsSolid;
   Canvas.Brush.Color := ink;
   Canvas.Ellipse(cx - pupil, cy - pupil, cx + pupil, cy + pupil);

   (* AND THE SLASH WHEN THE PASSWORD IS SHOWING, which is the state that
     needs the stronger signal: it says "this is visible, click to hide".
     It is drawn corner to corner rather than across the lids so that it
     reads as a line through the eye at any size. *)
   if FRevealed then
      begin
      Canvas.Brush.Style := bsClear;
      Canvas.Pen.Color := ink;
      Canvas.Pen.Width := 1;
      Canvas.MoveTo(cx - halfW, cy + halfW);
      Canvas.LineTo(cx + halfW, cy - halfW);
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

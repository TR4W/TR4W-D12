program listboxprobe;

(* WHAT AN LCL LIST BOX DOES WHEN ITS ROW HEIGHT CHANGES.

  Written to chase a macOS defect: resizing the DX cluster window produced two
  recovered EAccessViolations, one of them with a program counter of
  $00730074006F0070 -- which is not an address at all, it is the UTF-16 for
  's' 't' 'o' 'p'. Text executed as code means a call through a pointer read
  out of memory that now holds something else, which is what a message to a
  freed object looks like. An earlier build on the same machine reported
  EBusError, the aarch64 symptom of a misaligned pointer.

  THE PATH UNDER TEST IS uTelnetForm.ApplyConsoleScale, and nothing else. It
  does two things to an owner-drawn list box when the window settles at a new
  size:

     lstConsole.Items.BeginUpdate / Font.Size := n / Items.EndUpdate
     lstConsole.ItemHeight := measuredRowHeight

  THE QUESTION THIS ANSWERS IS NOT "does it crash" -- a crash needs the right
  machine. It is the cheaper and more decisive one: DOES EITHER ASSIGNMENT
  REPLACE THE CONTROL'S HANDLE AND ITS Items OBJECT? Because
  TCustomListBox.SetItemHeight calls RecreateWnd (customlistbox.inc:491,
  carrying the LCL's own "TODO: remove RecreateWnd"). InitializeWnd afterwards
  FREES the old strings object and installs a new one bound to the new widget.

  That matters on Cocoa specifically: TCocoaListControlStringList holds a raw
  NSTableView in a field called Owner and sends it reloadData on EVERY change
  (cocoalistcontrol.pas:238-242). A strings object used after its widget has
  gone therefore messages a freed Objective-C object -- an isa pointer read out
  of recycled memory, jumped to. Recycled Cocoa memory very often holds NSString
  text, in UTF-16.

  Run it under xvfb-run on a machine with no display:

     xvfb-run -a ./listboxprobe

  It prints what it measured and exits 0. It asserts nothing: a green run here
  does not clear the Cocoa path, and that is said again at the end of the
  output. *)

{$mode objfpc}{$H+}

uses
   {$IFDEF UNIX}
   cthreads, cwstring,
   {$ENDIF}
   Interfaces, Forms, Controls, StdCtrls, Graphics, Classes, SysUtils;

const
   (* The console's own numbers, from uTelnetForm. *)
   MIN_FONT = 7;
   MAX_FONT = 20;

   (* How hard to lean on it. A DX cluster console is unbounded -- nothing in
     TR4W trims it -- so the interesting case is a long session, not a fresh
     window. *)
   START_LINES    = 4000;
   LINES_PER_TICK = 50;
   CYCLES         = 60;

type
   TProbeForm = class(TForm)
   public
      List: TListBox;
      procedure BuildProbe;
      procedure DrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
                         State: TOwnerDrawState);
      procedure MeasureItem(Control: TWinControl; Index: Integer;
                            var AHeight: Integer);
      procedure AddLines(const aCount: integer);
      function  RowHeightOnScreen: integer;
      function  FontRowHeight: integer;
   end;

var
   Form: TProbeForm;
   Cycle: integer;
   FontSize: integer;
   rowHeight: integer;
   handleBefore, handleAfter: PtrUInt;
   itemsBefore, itemsAfter: PtrUInt;
   fontRecreates, heightRecreates: integer;

procedure TProbeForm.BuildProbe;
begin
   Caption := 'listboxprobe';
   SetBounds(0, 0, 900, 400);

   List := TListBox.Create(Self);
   List.Parent := Self;
   List.Align := alClient;
   (* EXACTLY the console's style: the row height is whatever ItemHeight says,
     which is why ApplyConsoleScale has to assign it. *)
   List.Style := lbOwnerDrawFixed;
   List.ItemHeight := 15;
   List.ScrollWidth := 2000;
   List.Font.Size := 9;
   List.OnDrawItem := @DrawItem;
end;

(* The console's owner draw, reduced to what touches the item payload: an enum
  packed into Objects[] and read back out. *)
procedure TProbeForm.DrawItem(Control: TWinControl; Index: Integer;
                              ARect: TRect; State: TOwnerDrawState);
var
   kind: integer;
   cv: TCanvas;
begin
   if (Index < 0) or (Index >= List.Items.Count) then
      begin
      Exit;
      end;

   kind := integer(PtrUInt(List.Items.Objects[Index]));

   cv := List.Canvas;
   cv.Brush.Color := clWindow;
   cv.FillRect(ARect);
   if kind = 4 then
      begin
      cv.Font.Color := clRed;
      end
   else
      begin
      cv.Font.Color := clBlack;
      end;
   cv.Brush.Style := bsClear;
   cv.TextOut(ARect.Left + 5, ARect.Top, List.Items[Index]);
   cv.Brush.Style := bsSolid;
end;

procedure TProbeForm.AddLines(const aCount: integer);
var
   i: integer;
begin
   for i := 1 to aCount do
      begin
      (* A DX spot is a fixed-width record; the kind rides in Objects[] the way
        TelnetConsoleAdd puts it there. *)
      List.Items.AddObject(
         Format('DX de W1AW-#:    14025.0  DL1ABC       CW 599 spot line %-20d',
                [List.Items.Count]),
         TObject(PtrUInt(List.Items.Count mod 7)));
      end;
end;

(* THE CANDIDATE REPLACEMENT. lbOwnerDrawVariable asks the control's owner how
  tall each row is instead of being told once, so the row height can follow the
  font WITHOUT assigning ItemHeight -- which is the only thing in
  ApplyConsoleScale that recreates the handle. *)
procedure TProbeForm.MeasureItem(Control: TWinControl; Index: Integer;
                                 var AHeight: Integer);
begin
   AHeight := FontRowHeight;
end;

function TProbeForm.FontRowHeight: integer;
begin
   List.Canvas.Font.Assign(List.Font);
   Result := List.Canvas.TextHeight('Wg') + 2;
end;

(* WHAT THE WIDGET SET ACTUALLY LAID OUT, not what we asked for. ItemRect goes
  to the control, which is the only witness that matters. *)
function TProbeForm.RowHeightOnScreen: integer;
var
   r: TRect;
begin
   Result := 0;
   if List.Items.Count = 0 then
      begin
      Exit;
      end;
   r := List.ItemRect(0);
   Result := r.Bottom - r.Top;
end;

function ItemsPtr: PtrUInt;
begin
   Result := PtrUInt(Pointer(Form.List.Items));
end;

begin
   Application.Initialize;
   Form := TProbeForm.CreateNew(nil);
   Form.BuildProbe;
   Form.Show;
   Application.ProcessMessages;

   WriteLn('listboxprobe -- ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
   WriteLn;

   Form.AddLines(START_LINES);
   Application.ProcessMessages;
   WriteLn(Format('%d line(s) in the list', [Form.List.Items.Count]));
   WriteLn;

   (* MEASUREMENT 1 -- does changing the FONT replace the handle or the strings
     object? If it does, ApplyConsoleScale's BeginUpdate and EndUpdate are
     called on TWO DIFFERENT objects and the first one is freed holding an open
     update. *)
   handleBefore := PtrUInt(Form.List.Handle);
   itemsBefore  := ItemsPtr;
   Form.List.Items.BeginUpdate;
   try
      Form.List.Font.Size := 12;
   finally
      Form.List.Items.EndUpdate;
   end;
   Application.ProcessMessages;
   handleAfter := PtrUInt(Form.List.Handle);
   itemsAfter  := ItemsPtr;
   WriteLn(Format('Font.Size   : handle $%x -> $%x   Items $%x -> $%x   %s',
      [handleBefore, handleAfter, itemsBefore, itemsAfter,
       BoolToStr((handleBefore <> handleAfter) or (itemsBefore <> itemsAfter),
                 'RECREATED', 'kept')]));

   (* MEASUREMENT 2 -- and the same question for the row height, which the LCL
     source says calls RecreateWnd. *)
   handleBefore := PtrUInt(Form.List.Handle);
   itemsBefore  := ItemsPtr;
   Form.List.ItemHeight := 21;
   Application.ProcessMessages;
   handleAfter := PtrUInt(Form.List.Handle);
   itemsAfter  := ItemsPtr;
   WriteLn(Format('ItemHeight  : handle $%x -> $%x   Items $%x -> $%x   %s',
      [handleBefore, handleAfter, itemsBefore, itemsAfter,
       BoolToStr((handleBefore <> handleAfter) or (itemsBefore <> itemsAfter),
                 'RECREATED', 'kept')]));
   WriteLn;

   (* THEN LEAN ON IT the way a drag does: settle at a new size, rescale, and
     keep the spots arriving in between. *)
   fontRecreates   := 0;
   heightRecreates := 0;
   for Cycle := 1 to CYCLES do
      begin
      Form.AddLines(LINES_PER_TICK);

      FontSize := MIN_FONT + (Cycle mod (MAX_FONT - MIN_FONT));

      itemsBefore := ItemsPtr;
      Form.List.Items.BeginUpdate;
      try
         Form.List.Font.Size := FontSize;
      finally
         Form.List.Items.EndUpdate;
      end;
      if ItemsPtr <> itemsBefore then
         begin
         Inc(fontRecreates);
         end;

      Form.List.Canvas.Font.Assign(Form.List.Font);
      rowHeight := Form.List.Canvas.TextHeight('Wg') + 2;

      itemsBefore := ItemsPtr;
      if Form.List.ItemHeight <> rowHeight then
         begin
         Form.List.ItemHeight := rowHeight;
         end;
      if ItemsPtr <> itemsBefore then
         begin
         Inc(heightRecreates);
         end;

      (* The scroll-to-end the settle handler does. *)
      if Form.List.Items.Count > 0 then
         begin
         Form.List.TopIndex := Form.List.Items.Count - 1;
         end;

      Application.ProcessMessages;

      if (Cycle mod 10) = 0 then
         begin
         WriteLn(Format('  cycle %3d: %6d line(s), font %2d, row %2d, Items $%x',
                        [Cycle, Form.List.Items.Count, FontSize, rowHeight,
                         ItemsPtr]));
         end;
      end;

   WriteLn;
   WriteLn(Format('%d cycle(s): %d font change(s) replaced the strings object, '
                  + '%d row-height change(s) did',
                  [CYCLES, fontRecreates, heightRecreates]));
   (* ---------------------------------------------------------------------
     AND NOW THE CANDIDATE FIX, measured the same way. lbOwnerDrawVariable
     takes its row height from OnMeasureItem, so the font can change without
     anyone assigning ItemHeight -- and ItemHeight is the only assignment in
     ApplyConsoleScale that recreates the handle.

     TWO THINGS HAVE TO BE TRUE for it to be a fix rather than a swap: the
     handle must survive, and the rows must ACTUALLY get taller. The second is
     asked of the control (ItemRect), not of our own arithmetic. *)
   WriteLn;
   WriteLn('---- lbOwnerDrawVariable ----');
   Form.List.OnMeasureItem := @Form.MeasureItem;
   Form.List.Style := lbOwnerDrawVariable;
   Application.ProcessMessages;

   heightRecreates := 0;
   for Cycle := 1 to CYCLES do
      begin
      Form.AddLines(LINES_PER_TICK);

      FontSize := MIN_FONT + (Cycle mod (MAX_FONT - MIN_FONT));

      itemsBefore  := ItemsPtr;
      handleBefore := PtrUInt(Form.List.Handle);

      Form.List.Font.Size := FontSize;

      (* WHAT MAKES THE WIDGET SET RE-ASK. A font change repaints; it does not
        by itself invite the control to re-measure its rows. One empty update
        cycle is the LCL's own way of saying the item list changed. *)
      Form.List.Items.BeginUpdate;
      Form.List.Items.EndUpdate;

      Application.ProcessMessages;

      if (ItemsPtr <> itemsBefore) or (PtrUInt(Form.List.Handle) <> handleBefore) then
         begin
         Inc(heightRecreates);
         end;

      if (Cycle mod 10) = 0 then
         begin
         WriteLn(Format('  cycle %3d: %6d line(s), font %2d, asked %2d, '
                        + 'ON SCREEN %2d, ItemHeight %2d',
                        [Cycle, Form.List.Items.Count, FontSize,
                         Form.FontRowHeight, Form.RowHeightOnScreen,
                         Form.List.ItemHeight]));
         end;
      end;

   WriteLn;
   WriteLn(Format('%d cycle(s) with no ItemHeight assignment: %d recreate(s)',
                  [CYCLES, heightRecreates]));

   WriteLn;
   WriteLn('NO CRASH IS NOT A CLEAN BILL. This widget set is not Cocoa, and the '
           + 'defect being chased is a message to a freed NSTableView.');

   Form.Free;
   Halt(0);
end.

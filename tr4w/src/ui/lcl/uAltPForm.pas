unit uAltPForm;
{$I ..\..\tr4w.inc}

{
  THE ALT-P PROGRAMMABLE-MESSAGE WINDOW, as a designed form.

  WHAT IT REPLACES. uAltP built this by hand: CreateModalDialog(397, 177, ...)
  with a dialog proc, a ListView created at run time by CreateListView2, three
  columns inserted through uCommctrl.ListView_InsertColumnA, and the rows filled
  by thirteen raw ListView_ calls against an HWND.

  THE SEAM WAS ALREADY THERE. uAltP.ShowAltP was written for this conversion --
  "when the dialog becomes an LCL form, this body changes and nothing else
  does". It did, and nothing else did.

  THE CONTENT LOGIC DID NOT MOVE. DisplaymessagesList still walks F1..AltF12,
  still picks CW or SSB memories, still knows what a CQ window is and what an
  exchange window is. It just calls AltPAddRow instead of filling a TLVItem.
  That split is deliberate: this unit is the view and knows nothing about
  messages; uAltP owns the messages and now knows nothing about how they are
  shown.

  WHAT THE CONVERSION FIXED ON THE WAY.

  The Win32 path null-terminated every ShortString IN PLACE before handing a
  pointer to it -- `TempString[Ord(TempString[0]) + 1] := #0` and the same trick
  on the message memories themselves -- because a ShortString has no terminator
  and LVITEM.pszText is a PAnsiChar. That wrote a byte PAST the length into the
  live message memory. Passing a `string` needs none of it.

  THE TRANSLATIONS ARE WIRED, which is the trap CLAUDE.md warns a conversion
  falls into silently. The Win32 dialog hardcoded the column headers as
  'Command', 'Message' and 'Caption' -- with `//TC_COMMAND` sitting commented out
  beside the first one -- while TC_COMMAND, RC_MESSAGE and RC_CAPTION all exist
  in the catalogues and went unused. The .lfm carries designer placeholders and
  HandleShow assigns the real text, which is the uServerLogForm pattern.

  A FIXED-PITCH FONT, BY PITCH RATHER THAN BY NAME. The dialog used
  TerminalFont, a Win32 HFONT for the 'Terminal' raster face. Naming a Windows
  raster font in a form heading for other platforms is a portability trap, and
  it does not scale; asking for fpFixed says what was actually wanted.
}

interface

uses
   Classes, SysUtils, Forms, Controls, ComCtrls, StdCtrls, ExtCtrls, Buttons,
   LCLType,
   uTR4WStrings;

type
   TfrmAltP = class(TForm)
      rgBank: TRadioGroup;
      lvMessages: TListView;
      btnEdit: TBitBtn;
      btnClose: TBitBtn;
      procedure HandleShow(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure MessagesDblClick(Sender: TObject);
      procedure EditClick(Sender: TObject);
      procedure CloseClick(Sender: TObject);
      procedure BankClick(Sender: TObject);
      procedure HandleResize(Sender: TObject);
   private
      procedure SizeColumns;
      procedure SizeListMinimum;
   end;

{ THE VIEW'S SIDE OF THE SEAM.  uAltP calls these; it never touches a control. }

{ Opens the window modally.  Returns when the operator closes it. }
procedure ShowAltPWindow;

{ Row building.  Begin/End bracket the fill so the list is written once --
  the Win32 version had no equivalent and repainted per row. }
procedure AltPBeginUpdate;
procedure AltPClear;
{ AnsiString THROUGHOUT, not string.  These land in LCL TListItem.Caption and
  SubItems, which are AnsiString (TTranslateString); a UnicodeString API would
  be converted back at every single row. }
{ aKey is the message's KEY ORDINAL -- Ord(Key) - Ord(F1), so 0..35 across the
  three banks -- or -1 for a row that is not a function key (the 'other
  messages' window).  THE ROW'S POSITION IS NOT ITS IDENTITY: with a bank
  filter, row 0 is F1, CONTROLF1 or ALTF1 depending on what is showing, and
  every rule that keyed off the row index would quietly mean something else.
  See AltPSelectedKey. }
procedure AltPAddRow(const aCommand, aMessage, aCaption: AnsiString;
                     const aKey: integer);
procedure AltPEndUpdate;

{ Selection, by row index.  AltPSelect also scrolls the row into view, which is
  what the LVM_ENSUREVISIBLE at the end of DisplaymessagesList asked for. }
procedure AltPSelect(const aIndex: integer);
function  AltPSelectedIndex: integer;

{ The KEY ordinal of the selected row, or -1.  This is what a rule about
  'F1 and F2 are not editable' must ask, not the row number. }
function  AltPSelectedKey: integer;

{ Select by key ordinal rather than by position, and scroll it into view.
  Answers False when that key is not in the bank on show. }
function  AltPSelectByKey(const aKey: integer): boolean;

{ The bank on show: 0 standard, 1 control, 2 alt.  The window filters to one
  because F1-F12 fit without scrolling and the other twenty-four are rarely
  programmed (NY4I, 2026-08-31). }
function  AltPBank: integer;
procedure AltPSetBank(const aBank: integer);

{ Hidden for the 'other messages' window, whose rows are not function keys
  and have no bank. }
procedure AltPShowBankFilter(const aVisible: boolean);
function  AltPRowCount: integer;

{ One cell of one row.  The message editor pre-fills itself from the row the
  operator picked, and used to do it with ListView_GetItemText into a fixed
  512-byte buffer against the raw HWND.  Column 0 is the command, 1 the
  message, 2 the caption.  Returns '' for a row or column that is not there,
  which the buffer version could not distinguish from an empty cell. }
function  AltPRowText(const aRow, aCol: integer): AnsiString;

{ The window handle, for ShowEditMessage.  IT STILL TAKES AN HWND -- uEditMessage
  is a converted form whose entry point kept its Win32 signature, so this is the
  one place the seam still leaks a handle.  It becomes a TCustomForm when that
  unit is next touched. }
function AltPParentHandle: HWND;

var
   TR4WAltPForm: TfrmAltP = nil;

   { EDIT IS THE OWNER'S DECISION, not the view's.  Double-click and the Edit
     button both raise it; uAltP decides what may be edited (the exchange
     window's first two rows are fixed) and what editing means.  Same shape as
     TelnetFormOnSend. }
   AltPFormOnEdit: procedure = nil;

   { FILLING IS THE OWNER'S JOB TOO, and this is what WM_INITDIALOG did:
     it called DisplaymessagesList before the dialog appeared.  Removing the
     dialog proc removed that call, and the window opened correctly and
     completely empty (NY4I, 2026-08-31) -- the columns and the title were
     right, which is exactly what made it look like a data problem rather
     than a missing call. }
   AltPFormOnFill: procedure = nil;

implementation

{$R *.lfm}

uses
   Graphics,          { TFont.Pitch -- fpFixed }
   uLCLFormHelpers;   { ApplyContentMinimumSize }

procedure ShowAltPWindow;
begin
   if TR4WAltPForm = nil then
      begin
      TR4WAltPForm := TfrmAltP.Create(nil);
      end;

   TR4WAltPForm.ShowModal;
end;

procedure AltPBeginUpdate;
begin
   if TR4WAltPForm <> nil then
      begin
      TR4WAltPForm.lvMessages.Items.BeginUpdate;
      end;
end;

procedure AltPClear;
begin
   if TR4WAltPForm <> nil then
      begin
      TR4WAltPForm.lvMessages.Items.Clear;
      end;
end;

procedure AltPAddRow(const aCommand, aMessage, aCaption: AnsiString;
                     const aKey: integer);
var
   row: TListItem;
begin
   if TR4WAltPForm = nil then
      begin
      Exit;
      end;

   row := TR4WAltPForm.lvMessages.Items.Add;
   row.Caption := aCommand;

   { The key travels WITH the row.  Data is a Pointer, so the ordinal is
     carried as one; +1 keeps -1 distinguishable from nil. }
   row.Data := Pointer(PtrInt(aKey + 1));

   { SubItems are positional and BOTH must be added even when empty, or the
     Caption column lands in the Message column for that row.  The Win32 code
     set pszText to nil for an absent value, which had the same requirement
     expressed as a separate ListView_SetItem per sub-item. }

   row.SubItems.Add(aMessage);
   row.SubItems.Add(aCaption);
end;

procedure AltPEndUpdate;
begin
   if TR4WAltPForm <> nil then
      begin
      TR4WAltPForm.lvMessages.Items.EndUpdate;
      end;
end;

procedure AltPSelect(const aIndex: integer);
var
   lv: TListView;
begin
   if TR4WAltPForm = nil then
      begin
      Exit;
      end;

   lv := TR4WAltPForm.lvMessages;

   if (aIndex < 0) or (aIndex >= lv.Items.Count) then
      begin
      Exit;
      end;

   lv.ItemIndex := aIndex;
   lv.Items[aIndex].MakeVisible(False);
end;

function AltPSelectedIndex: integer;
begin
   Result := -1;
   if TR4WAltPForm <> nil then
      begin
      Result := TR4WAltPForm.lvMessages.ItemIndex;
      end;
end;

function AltPSelectedKey: integer;
var
   lv: TListView;
begin
   Result := -1;
   if TR4WAltPForm = nil then
      begin
      Exit;
      end;

   lv := TR4WAltPForm.lvMessages;
   if (lv.ItemIndex < 0) or (lv.ItemIndex >= lv.Items.Count) then
      begin
      Exit;
      end;

   Result := PtrInt(lv.Items[lv.ItemIndex].Data) - 1;
end;

function AltPSelectByKey(const aKey: integer): boolean;
var
   lv: TListView;
   i : integer;
begin
   Result := False;
   if TR4WAltPForm = nil then
      begin
      Exit;
      end;

   lv := TR4WAltPForm.lvMessages;
   for i := 0 to lv.Items.Count - 1 do
      begin
      if (PtrInt(lv.Items[i].Data) - 1) = aKey then
         begin
         lv.ItemIndex := i;
         lv.Items[i].MakeVisible(False);
         Result := True;
         Exit;
         end;
      end;
end;

function AltPBank: integer;
begin
   Result := 0;
   if (TR4WAltPForm <> nil) and (TR4WAltPForm.rgBank.ItemIndex >= 0) then
      begin
      Result := TR4WAltPForm.rgBank.ItemIndex;
      end;
end;

procedure AltPSetBank(const aBank: integer);
begin
   if (TR4WAltPForm <> nil) and (aBank >= 0) and (aBank <= 2) then
      begin
      TR4WAltPForm.rgBank.ItemIndex := aBank;
      end;
end;

procedure AltPShowBankFilter(const aVisible: boolean);
begin
   if TR4WAltPForm <> nil then
      begin
      TR4WAltPForm.rgBank.Visible := aVisible;
      end;
end;

function AltPRowCount: integer;
begin
   Result := 0;
   if TR4WAltPForm <> nil then
      begin
      Result := TR4WAltPForm.lvMessages.Items.Count;
      end;
end;

function AltPRowText(const aRow, aCol: integer): AnsiString;
var
   lv: TListView;
begin
   Result := '';

   if TR4WAltPForm = nil then
      begin
      Exit;
      end;

   lv := TR4WAltPForm.lvMessages;

   if (aRow < 0) or (aRow >= lv.Items.Count) then
      begin
      Exit;
      end;

   if aCol = 0 then
      begin
      Result := lv.Items[aRow].Caption;
      Exit;
      end;

   { SubItems are 0-based from the SECOND column. }
   if (aCol - 1) < lv.Items[aRow].SubItems.Count then
      begin
      Result := lv.Items[aRow].SubItems[aCol - 1];
      end;
end;

function AltPParentHandle: HWND;
begin
   Result := 0;
   if TR4WAltPForm <> nil then
      begin
      Result := TR4WAltPForm.Handle;
      end;
end;

procedure TfrmAltP.HandleShow(Sender: TObject);

   procedure AddColumn(const aCaption: AnsiString; const aWidth: integer);
   var
      col: TListColumn;
   begin
      col := lvMessages.Columns.Add;
      col.Caption := aCaption;
      col.Width   := aWidth;
   end;

begin
   { ASSIGNED HERE, NOT LEFT IN THE .lfm.  A designed caption is English forever;
     these constants are in the catalogues and were unreachable while the Win32
     dialog hardcoded the same words. }

   Caption := RC_LISTOFMESS;

   if rgBank.Items.Count = 0 then
      begin
      rgBank.Items.Add(TC_BANKSTANDARD);
      rgBank.Items.Add(TC_BANKCONTROL);
      rgBank.Items.Add(TC_BANKALT);
      rgBank.ItemIndex := 0;
      end;
   { NO GROUP CAPTION.  The three labels say what they are, and a heading
     would need a constant that says nothing the radios do not.  Cleared
     rather than left, because the .lfm text is a designer placeholder. }
   rgBank.Caption := '';

   { BUILT HERE, NOT IN THE .lfm.  Designer columns would carry English
     captions forever, which is the trap; and a collection in the .lfm is
     what uStationsForm avoids too.  Widths are the Win32 dialog's.
     Idempotent: HandleShow runs on every open. }

   if lvMessages.Columns.Count = 0 then
      begin
      AddColumn(TC_COMMAND, 270);
      AddColumn(RC_MESSAGE, 340);
      AddColumn(RC_CAPTION, 155);
      end
   else
      begin
      lvMessages.Columns[0].Caption := TC_COMMAND;
      lvMessages.Columns[1].Caption := RC_MESSAGE;
      lvMessages.Columns[2].Caption := RC_CAPTION;
      end;

   { The message columns line up only in a fixed-pitch face.  By PITCH, not by
     naming 'Terminal' -- see the unit header. }
   lvMessages.Font.Pitch := fpFixed;

   SizeColumns;

   { AFTER the columns exist, and every time the window opens -- the memories
     may have been edited since.  This is the WM_INITDIALOG call. }

   if Assigned(AltPFormOnFill) then
      begin
      AltPFormOnFill;
      end;

   SizeListMinimum;
   ApplyContentMinimumSize(Self);
end;

procedure TfrmAltP.HandleKeyDown(Sender: TObject; var Key: word;
                                 Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmAltP.MessagesDblClick(Sender: TObject);
begin
   { NM_DBLCLK in the dialog proc. }
   if Assigned(AltPFormOnEdit) then
      begin
      AltPFormOnEdit;
      end;
end;

procedure TfrmAltP.EditClick(Sender: TObject);
begin
   { Control id 1 in the dialog proc. }
   if Assigned(AltPFormOnEdit) then
      begin
      AltPFormOnEdit;
      end;
end;

{ THE COLUMNS FILL THE WINDOW.  Anchoring stretches the CONTROL; a TListView's
  columns keep the widths they were given, so widening the window left the
  three columns ending around 750px with dead space beside them -- visible
  the moment anyone resizes it (NY4I, 2026-08-31).

  IN THE DESIGNED PROPORTIONS, not equal thirds: the command is a fixed-width
  key name, the message is the long one, the caption is short.  The Win32
  dialog's 270/340/155 carry that judgement and are kept as the ratio.

  The last column takes the rounding remainder so the three always sum to the
  full width -- distributing it by ratio leaves a one or two pixel gap that
  shows as a sliver of the wrong colour at the right edge. }
procedure TfrmAltP.SizeColumns;
const
   DESIGN_W: array[0..2] of integer = (270, 340, 155);
var
   avail, total, i, used, w: integer;
begin
   if lvMessages.Columns.Count < 3 then
      begin
      Exit;
      end;

   { Less a little for the vertical scrollbar, so a full-width row does not
     provoke a horizontal one -- the same allowance the cluster console makes. }
   avail := lvMessages.ClientWidth - 4;
   if avail < 60 then
      begin
      Exit;      { mid-layout, or minimised }
      end;

   total := DESIGN_W[0] + DESIGN_W[1] + DESIGN_W[2];
   used  := 0;

   for i := 0 to 1 do
      begin
      w := (avail * DESIGN_W[i]) div total;
      lvMessages.Columns[i].Width := w;
      used := used + w;
      end;

   lvMessages.Columns[2].Width := avail - used;
end;

{ THE SMALLEST LIST THAT STILL SHOWS EVERY ROW.

  A FLOOR OF 150 WAS A GUESS AND IT WAS WRONG: it left six and a half of the
  twelve function keys visible, and a window that hides half a bank of memories
  is the defect this whole minimum exists to prevent (NY4I, 2026-08-31, with
  screenshots of both).

  MEASURED, NOT COMPUTED FROM THE FONT.  The first item's DisplayRect gives the
  real row height AND the real header height in one read -- its Top IS the
  bottom of the header -- so this is right at any DPI, with any font, and after
  any change to the list's own metrics.  Deriving it as TextHeight plus a
  guessed padding would be a second, worse model of what the widget does.

  Nothing to measure means nothing to say: an unfilled list keeps whatever
  floor it already had rather than being pinned to a made-up one. }
procedure TfrmAltP.SizeListMinimum;
var
   r      : TRect;
   rowH   : integer;
   headerH: integer;
begin
   if lvMessages.Items.Count = 0 then
      begin
      Exit;
      end;

   r       := lvMessages.Items[0].DisplayRect(drBounds);
   rowH    := r.Bottom - r.Top;
   headerH := r.Top;

   if rowH <= 0 then
      begin
      Exit;      { mid-layout: the handle exists but nothing is placed yet }
      end;

   { Plus a row's worth of slack, so the last row is not flush against the
     bottom border and a scrollbar arriving cannot eat it. }
   lvMessages.Constraints.MinHeight :=
      headerH + (lvMessages.Items.Count + 1) * rowH;
end;

procedure TfrmAltP.HandleResize(Sender: TObject);
begin
   { Live, not debounced.  Three column widths is nothing to compute, and a
     debounce would leave the columns visibly stale during the drag -- which
     is what the radio panel's borrowed timer did before it was removed. }
   SizeColumns;
end;

procedure TfrmAltP.BankClick(Sender: TObject);
begin
   { Re-fill for the newly chosen bank.  The owner decides what is in it. }
   if Assigned(AltPFormOnFill) then
      begin
      AltPFormOnFill;
      end;

   { The banks are all twelve keys, but the 'other messages' window is 9 or 13,
     so the floor is recomputed rather than assumed. }
   SizeListMinimum;
   ApplyContentMinimumSize(Self);
end;

procedure TfrmAltP.CloseClick(Sender: TObject);
begin
   { Control id 2, and WM_CLOSE, both of which ran EndDialog. }
   Close;
end;

end.

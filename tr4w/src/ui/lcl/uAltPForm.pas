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
   Classes, SysUtils, Forms, Controls, ComCtrls, StdCtrls, Buttons, LCLType,
   uTR4WStrings;

type
   TfrmAltP = class(TForm)
      lvMessages: TListView;
      btnEdit: TBitBtn;
      btnClose: TBitBtn;
      procedure HandleShow(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
      procedure MessagesDblClick(Sender: TObject);
      procedure EditClick(Sender: TObject);
      procedure CloseClick(Sender: TObject);
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
procedure AltPAddRow(const aCommand, aMessage, aCaption: AnsiString);
procedure AltPEndUpdate;

{ Selection, by row index.  AltPSelect also scrolls the row into view, which is
  what the LVM_ENSUREVISIBLE at the end of DisplaymessagesList asked for. }
procedure AltPSelect(const aIndex: integer);
function  AltPSelectedIndex: integer;

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

procedure AltPAddRow(const aCommand, aMessage, aCaption: AnsiString);
var
   row: TListItem;
begin
   if TR4WAltPForm = nil then
      begin
      Exit;
      end;

   row := TR4WAltPForm.lvMessages.Items.Add;
   row.Caption := aCommand;

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

procedure TfrmAltP.CloseClick(Sender: TObject);
begin
   { Control id 2, and WM_CLOSE, both of which ran EndDialog. }
   Close;
end;

end.

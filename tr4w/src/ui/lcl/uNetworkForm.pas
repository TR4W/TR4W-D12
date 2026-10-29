unit uNetworkForm;

{ THE MULTI-OP STATUS WINDOW, AS AN LCL FORM.

  A list view of the other stations, a reconnect timer, and row colouring that
  used to be a WM_NOTIFY / NM_CUSTOMDRAW handler on a SUBCLASSED window
  procedure (OldNetWndProc / NewNetWndProc).  TListView.OnCustomDrawItem is the
  same hook with none of the subclassing.

  THIS WINDOW USED TO BE PART OF THE TRANSPORT.  WSAAsyncSelect posted
  WM_SOCK_NET to it whenever the multi-op socket became readable, and the dialog
  procedure called recv().  That is gone: uNetClient owns the socket over Indy
  and this is now only a view.  The conversion was blocked on that and nothing
  else.

  THE COLUMNS COME FROM NetColumnsArray, not from the designer.  It is the one
  place the widths, alignments and (translated) captions are stated, and a
  second copy in the .lfm would keep working while it drifted.

  THIS WINDOW IS A VIEW OF THE LINK AND NOTHING MORE (2026-10-27).  NY4I: "I
  never liked the idea that we only connected when the Network window was up."
  Showing it connects nothing and closing it disconnects nothing; the link is
  owned by uNet (NetLinkConnect / NetLinkDisconnect / NetLinkReconnect, driven
  by the Net menu and by NETWORK AUTO CONNECT at startup) and the reconnect timer
  that lived here is uNet's.

  HOW IT FOLLOWS THE LINK.  It adds a method of its own to
  uNetLink.NetLinkObservers when it is created and removes it in its destructor,
  so the link never holds a reference to a form that may be gone.  It is told
  when the state or the status line changes and re-reads the title.  The
  station LIST arrives cell by cell as status messages come in -- a window that
  is opened mid-session missed them, so RefreshFromLink asks uNet to write every
  station it knows (DisplayAllClients) each time the window is shown. }

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, ComCtrls, ExtCtrls, Graphics,
   VC;

type
   TfrmNetwork = class(TForm)
      lvClients: TListView;
      procedure HandleCreate(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleKeyDown(Sender: TObject; var Key: word;
                              Shift: TShiftState);
      procedure ClientsCustomDrawItem(Sender: TCustomListView; Item: TListItem;
                                      State: TCustomDrawState;
                                      var DefaultDraw: boolean);
   public
      destructor Destroy; override;

      { One cell.  Rows are created on demand, so a status arriving for a
        station that has no row yet does not have to be ordered. }
      procedure SetCell(const aRow, aCol: integer; const aText: string);

      (* BRING THE WINDOW INTO LINE WITH THE LINK: the title and every station.
        Called when the window is shown, which is what makes a window opened
        mid-session correct. Public so a test can ask without showing a
        window. *)
      procedure RefreshFromLink;

      (* uNetLink's notification: the state or the status line changed. *)
      procedure LinkChanged(Sender: TObject);
   end;

var
   TR4WNetworkForm: TfrmNetwork = nil;

procedure CreateTR4WNetworkWindow;

implementation

{$R *.lfm}

uses
   MainUnit,     { CloseTR4WWindow, FrmSetFocus }
   uNet,         { the columns, NetWindowCaption, DisplayAllClients }
   uNetLink,     { NetLinkObservers -- how this window follows the link }
   uSettingsModel, { Settings.Computer.Id -- whose row is highlighted yellow }
   uLCLFormHelpers;

procedure TfrmNetwork.HandleCreate(Sender: TObject);
var
   i: integer;
   col: TListColumn;
begin
   (* THE GLOBAL NAMES THIS FORM FROM THE MOMENT IT EXISTS, and the observer is
     added in the same breath - the two stand or fall together with the
     destructor below. uNet writes station cells through the global, so a form
     made any other way than CreateTR4WNetworkWindow (a unit test) is still
     found. *)
   TR4WNetworkForm := Self;
   NetLinkObservers.Add(LinkChanged);

   lvClients.ViewStyle := vsReport;
   lvClients.Columns.BeginUpdate;
   try
      lvClients.Columns.Clear;
      for i := 0 to NetColumns - 1 do
         begin
         col := lvClients.Columns.Add;
         col.Caption := string(NetColumnsArray[i].Text);
         col.Width   := NetColumnsArray[i].Width;
         if NetColumnsArray[i].fmt = LVCFMT_LEFT then
            begin
            col.Alignment := taLeftJustify;
            end
         else
            begin
            col.Alignment := taCenter;
            end;
         end;
   finally
      lvClients.Columns.EndUpdate;
   end;
end;

destructor TfrmNetwork.Destroy;
begin
   (* UNSUBSCRIBE BEFORE ANYTHING IS FREED: the link must never be left holding
     a method of a form that is gone. The global is cleared only if it is this
     form, so a second form cannot be orphaned by the first one's destruction. *)
   NetLinkObservers.Remove(LinkChanged);
   if TR4WNetworkForm = Self then
      begin
      TR4WNetworkForm := nil;
      end;
   inherited Destroy;
end;

procedure TfrmNetwork.LinkChanged(Sender: TObject);
begin
   Caption := TCaption(NetWindowCaption);
end;

procedure TfrmNetwork.RefreshFromLink;
begin
   Caption := TCaption(NetWindowCaption);
   DisplayAllClients;
end;

procedure TfrmNetwork.HandleShow(Sender: TObject);
begin
   (* SHOWING THIS WINDOW CONNECTS NOTHING. It used to try the link and start a
     retry timer here; the link is the program's now. What it does is ask the
     link for its state, because a window opened mid-session was not there to
     see the status messages go by. *)
   RefreshFromLink;
end;

procedure TfrmNetwork.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   (* CLOSING THIS WINDOW DISCONNECTS NOTHING (it used to). It hides, and the
     link carries on. *)
   CloseAction := caHide;
   CloseTR4WWindow(tw_NETWINDOW_INDEX);
end;

{ ESCAPE CLOSES IT.  A Win32 DialogBox did this for free; a TForm does not. }
procedure TfrmNetwork.HandleKeyDown(Sender: TObject; var Key: word;
                                    Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmNetwork.ClientsCustomDrawItem(Sender: TCustomListView;
                                            Item: TListItem;
                                            State: TCustomDrawState;
                                            var DefaultDraw: boolean);
var
   row: integer;
begin
   // NM_CUSTOMDRAW, without the subclassed window procedure.
   //
   // Bit 0 of ssStatusByte is PTT.  A transmitting station is highlighted --
   // YELLOW when it is this computer, RED with white text when it is somebody
   // else, which is how an operator sees at a glance that the other station is
   // on the air.
   DefaultDraw := True;
   if Item = nil then
      begin
      Exit;
      end;

   row := Item.Index + 1;
   if (row < Low(StatusArray)) or (row > High(StatusArray)) then
      begin
      Exit;
      end;

   if (StatusArray[row].ssStatusByte and (1 shl 0)) = 0 then
      begin
      Exit;
      end;

   if StatusArray[row].ssComputerID = Settings.Computer.Id then
      begin
      Sender.Canvas.Brush.Color := clYellow;
      end
   else
      begin
      Sender.Canvas.Brush.Color := clRed;
      Sender.Canvas.Font.Color := clWhite;
      end;
end;

procedure TfrmNetwork.SetCell(const aRow, aCol: integer; const aText: string);
var
   item: TListItem;
begin
   if aRow < 0 then
      begin
      Exit;
      end;

   // ROWS ON DEMAND.  tLVSetText wrote into a row the Win32 list view had been
   // told to hold; here the item has to exist first, and a status can arrive
   // for a station before anything has drawn it.
   while lvClients.Items.Count <= aRow do
      begin
      item := lvClients.Items.Add;
      while item.SubItems.Count < NetColumns - 1 do
         begin
         item.SubItems.Add('');
         end;
      end;

   item := lvClients.Items[aRow];
   if aCol = 0 then
      begin
      item.Caption := aText;
      Exit;
      end;

   while item.SubItems.Count < aCol do
      begin
      item.SubItems.Add('');
      end;
   item.SubItems[aCol - 1] := aText;
end;

procedure CreateTR4WNetworkWindow;
begin
   if TR4WNetworkForm = nil then
      begin
      TR4WNetworkForm := TfrmNetwork.Create(nil);
      end;

   LeaveFormUnowned(TR4WNetworkForm);

end;

end.

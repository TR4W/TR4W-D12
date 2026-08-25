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

  CLOSING THE WINDOW STILL DISCONNECTS, which is what WM_DESTROY did.  Now that
  the link no longer depends on this window that is a decision rather than a
  constraint -- and it is NY4I's to make, so the behaviour is unchanged here.
  See bench queue 45. }

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, ComCtrls, ExtCtrls, Graphics,
   VC;

type
   TfrmNetwork = class(TForm)
      lvClients: TListView;
      tmrStatus: TTimer;
      procedure HandleCreate(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleKeyDown(Sender: TObject; var Key: word;
                              Shift: TShiftState);
      procedure StatusTick(Sender: TObject);
      procedure ClientsCustomDrawItem(Sender: TCustomListView; Item: TListItem;
                                      State: TCustomDrawState;
                                      var DefaultDraw: boolean);
   public
      { One cell.  Rows are created on demand, so a status arriving for a
        station that has no row yet does not have to be ordered. }
      procedure SetCell(const aRow, aCol: integer; const aText: string);
   end;

var
   TR4WNetworkForm: TfrmNetwork = nil;

function CreateTR4WNetworkWindow: HWND;

implementation

{$R *.lfm}

uses
   MainUnit,     { CloseTR4WWindow, FrmSetFocus }
   uNet,         { NetIsConnected, TryConnectToNetwork, NetDisconnect, the columns }
   LogStuff,     { ComputerID -- whose row is highlighted yellow }
   uLCLFormHelpers;

procedure TfrmNetwork.HandleCreate(Sender: TObject);
var
   i: integer;
   col: TListColumn;
begin
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

procedure TfrmNetwork.HandleShow(Sender: TObject);
begin
   // What WM_INITDIALOG did after building the list: try the link, then keep
   // trying on the timer.
   TryConnectToNetwork;
   tmrStatus.Interval := tNetStatusUpdateInterval;
   tmrStatus.Enabled := True;
end;

procedure TfrmNetwork.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   CloseAction := caHide;
   tmrStatus.Enabled := False;

   // UNCHANGED: WM_DESTROY killed the timer and disconnected.  See the header --
   // it no longer HAS to, but changing when a multi-op link drops is not a side
   // effect a conversion should have.
   NetDisconnect;
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

procedure TfrmNetwork.StatusTick(Sender: TObject);
begin
   // The WM_TIMER arm, unchanged: retry while the link is down.
   if not NetIsConnected then
      begin
      TryConnectToNetwork;
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

   if StatusArray[row].ssComputerID = ComputerID then
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

function CreateTR4WNetworkWindow: HWND;
begin
   if TR4WNetworkForm = nil then
      begin
      TR4WNetworkForm := TfrmNetwork.Create(nil);
      end;

   OwnFormByMainWindow(TR4WNetworkForm);

   Result := TR4WNetworkForm.Handle;
end;

end.

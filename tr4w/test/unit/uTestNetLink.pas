(* THE MULTI-OP LINK BELONGS TO THE PROGRAM, NOT TO THE NETWORK WINDOW --
  2026-10-27 (NY4I: "I never liked the idea that we only connected when the
  Network window was up").

  What a unit test can reach without a socket:

    - the state machine's decision table (uNetLink.ResolveLinkState) and which
      Net-menu commands each state offers;
    - the startup rule;
    - the observer list the window subscribes to, including removal during a
      notification (a form being destroyed);
    - the Net menu on the REAL built menu, in every state;
    - the refusal latch and its re-arm, through the real message arms;
    - the Network window reading the link's state when it opens mid-session
      (stations that arrived while it did not exist), and unsubscribing when it
      is destroyed;
    - source reads for the wiring a socket would be needed to drive: the window
      starts and stops nothing, Connect and Reconnect re-arm the latch, startup
      asks uNet to decide.

  Connecting, dropping and retrying for real are two machines and a
  BENCH_QUEUE item. *)
unit uTestNetLink;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TTestNetLink = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_TheStateFollowsFourFacts;
      procedure Test_EachStateOffersItsCommands;
      procedure Test_OnlyALiveLinkEnablesTheRowsThatSend;
      procedure Test_TheStartupRule;
      procedure Test_ObserversAreCalledOnceAndMayRemoveThemselves;
      procedure Test_TheNetMenuFollowsEveryState;
      procedure Test_AStationWithNoLinkAndNoWishIsOff;
      procedure Test_ARefusedServerIsLatchedAndConnectReArmsIt;
      procedure Test_ARefusedComputerIdIsLatchedAndConnectReArmsIt;
      procedure Test_AStatusLineTellsTheObservers;
      procedure Test_AWindowOpenedMidSessionShowsEveryStation;
      procedure Test_ADestroyedWindowIsNoLongerTold;
      procedure Test_TheWindowStartsAndStopsNothing;
      procedure Test_StartupAsksUNetToDecide;
   private
      procedure FeedServerMessage(const aMessage: Word; const aParam: integer);
   end;

implementation

uses
   SysUtils, Classes, Menus, ComCtrls, Forms,
   VC, TF, uTR4WStrings,
   uNetHello, uNetLink, uNet, uMenu, uAppStrings, uSettingsModel, uComputerID,
   uNetworkForm;

(* Text into a fixed character field, NUL padded - the way a station status
  carries a name or a call. An open array carries its own bounds. *)
procedure PutChars(var aField: array of AnsiChar; const aText: string);
var
   i: integer;
begin
   for i := 0 to High(aField) do
      begin
      if i < Length(aText) then
         begin
         aField[i] := AnsiChar(aText[i + 1]);
         end
      else
         begin
         aField[i] := #0;
         end;
      end;
end;

(* ---------------------------------------------------------------- helpers *)

var
   GTestMenuOwner: TComponent = nil;

(* THE REAL MENU, built once per process and never freed - the same reason
  uTestMenuShortcuts gives: uMenu publishes it and cannot unpublish it. A menu
  that is already published (that suite's) is USED, not built again: every build
  leaks by design, and the leak ceiling counts them. Built only when this suite
  runs alone. *)
function BuiltNetMenuItem(const aId: word): TMenuItem;
begin
   Result := MenuItemById(aId);
   if (Result = nil) and (GTestMenuOwner = nil) then
      begin
      GTestMenuOwner := TComponent.Create(nil);
      InitializeMenuText;
      BuildTR4WMainMenu(GTestMenuOwner, nil);
      Result := MenuItemById(aId);
      end;
end;

function SourceText(const aRelative: string): string;
var
   lines: TStringList;
   path: string;
begin
   Result := '';
   path := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
                          PathDelim + aRelative);
   if not FileExists(path) then
      begin
      Exit;
      end;

   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(path));
      Result := UpperCase(lines.Text);
   finally
      lines.Free;
   end;
end;

(* The text of one routine: from its header to the next line that starts a
  routine or a unit section. Enough to ask what a body does and does not call. *)
function BodyOf(const aText, aHeader: string): string;
var
   impl, p, nextProc, nextFunc: integer;
   rest: string;
begin
   Result := '';

   (* THE IMPLEMENTATION SECTION ONLY: the interface declares the same header
     and a body is what is wanted. A unit with no such section (a program) is
     searched whole. *)
   impl := Pos(#10 + 'IMPLEMENTATION', aText);
   if impl = 0 then
      begin
      impl := 1;
      end;
   p := Pos(UpperCase(aHeader), Copy(aText, impl, MaxInt));
   if p = 0 then
      begin
      Exit;
      end;
   p := p + impl - 1;

   rest := Copy(aText, p + Length(aHeader), MaxInt);
   nextProc := Pos(#10 + 'PROCEDURE ', rest);
   nextFunc := Pos(#10 + 'FUNCTION ', rest);
   if (nextFunc > 0) and ((nextProc = 0) or (nextFunc < nextProc)) then
      begin
      nextProc := nextFunc;
      end;
   if nextProc = 0 then
      begin
      Result := Copy(aText, p, MaxInt);
      end
   else
      begin
      Result := Copy(aText, p, Length(aHeader) + nextProc);
      end;
end;

(* THE STATUS LINES THE ARMS POST ARE QUEUED ON THE LCL's ASYNC QUEUE, and a
  test that never drains it leaves them unfreed at exit - which the checked run
  counts. Run what is queued. *)
procedure DrainAsyncQueue;
begin
   if Application <> nil then
      begin
      Application.ProcessMessages;
      end;
end;

type
   (* An observer the test owns. *)
   TRecorder = class(TObject)
   public
      Calls: integer;
      (* The list this observer leaves when it is told, if it is set. *)
      LeaveOnCall: TNetLinkObservers;
      procedure Heard(Sender: TObject);
   end;

procedure TRecorder.Heard(Sender: TObject);
begin
   Inc(Calls);
   if LeaveOnCall <> nil then
      begin
      LeaveOnCall.Remove(Heard);
      end;
end;

(* ------------------------------------------------------------ the tables *)

procedure TTestNetLink.Test_TheStateFollowsFourFacts;
begin
   BeginTest('uNetLink: the state follows four facts');

   (* wanted, connected, connecting, refused *)
   Check(ResolveLinkState(False, False, False, False) = nlsOff,
         'nothing wanted, nothing up: off');
   Check(ResolveLinkState(True, False, False, False) = nlsWaiting,
         'wanted and not up: waiting to retry');
   Check(ResolveLinkState(True, False, True, False) = nlsConnecting,
         'an attempt in flight: connecting');
   Check(ResolveLinkState(True, True, False, False) = nlsConnected,
         'up: connected');
   Check(ResolveLinkState(True, False, False, True) = nlsRefused,
         'wanted, down and refused: refused (nothing retries)');
   Check(ResolveLinkState(False, False, False, True) = nlsOff,
         'a refusal with no wish for a link is not shown: off');
   Check(ResolveLinkState(False, True, False, False) = nlsConnected,
         'a live link is connected whatever the wish says (it is about to be dropped)');
   Check(ResolveLinkState(True, False, True, True) = nlsConnecting,
         'an attempt in flight wins over a standing refusal');
end;

procedure TTestNetLink.Test_EachStateOffersItsCommands;
var
   s: TNetLinkState;
begin
   BeginTest('uNetLink: each state offers its commands');

   for s := Low(TNetLinkState) to High(TNetLinkState) do
      begin
      CheckTrue(LinkCommandEnabled(s, nlcShowWindow),
                LinkStateName(s) + ': Show window is always offered');
      end;

   (* Connect: not while up, not while an attempt is already running *)
   CheckTrue(LinkCommandEnabled(nlsOff, nlcConnect), 'off: connect');
   CheckTrue(LinkCommandEnabled(nlsWaiting, nlcConnect), 'waiting: connect (try now)');
   CheckTrue(LinkCommandEnabled(nlsRefused, nlcConnect), 'refused: connect (try again)');
   CheckFalse(LinkCommandEnabled(nlsConnecting, nlcConnect), 'connecting: no connect');
   CheckFalse(LinkCommandEnabled(nlsConnected, nlcConnect), 'connected: no connect');

   (* Disconnect: anything but off. While connecting it stops the retries. *)
   CheckFalse(LinkCommandEnabled(nlsOff, nlcDisconnect), 'off: nothing to disconnect');
   CheckTrue(LinkCommandEnabled(nlsConnecting, nlcDisconnect),
             'connecting: disconnect cancels the retries');
   CheckTrue(LinkCommandEnabled(nlsConnected, nlcDisconnect), 'connected: disconnect');
   CheckTrue(LinkCommandEnabled(nlsWaiting, nlcDisconnect), 'waiting: disconnect stops the retries');
   CheckTrue(LinkCommandEnabled(nlsRefused, nlcDisconnect), 'refused: disconnect');

   (* Reconnect: a link that is, or was wanted; never mid-attempt *)
   CheckFalse(LinkCommandEnabled(nlsOff, nlcReconnect), 'off: reconnect is just connect');
   CheckFalse(LinkCommandEnabled(nlsConnecting, nlcReconnect), 'connecting: no reconnect');
   CheckTrue(LinkCommandEnabled(nlsConnected, nlcReconnect), 'connected: reconnect');
   CheckTrue(LinkCommandEnabled(nlsWaiting, nlcReconnect), 'waiting: reconnect');
   CheckTrue(LinkCommandEnabled(nlsRefused, nlcReconnect), 'refused: reconnect');
end;

procedure TTestNetLink.Test_OnlyALiveLinkEnablesTheRowsThatSend;
var
   s: TNetLinkState;
begin
   BeginTest('uNetLink: only a live link enables the rows that send');

   for s := Low(TNetLinkState) to High(TNetLinkState) do
      begin
      CheckEquals(Ord(s = nlsConnected), Ord(LinkNeedsLiveLink(s)),
                  LinkStateName(s));
      end;
end;

procedure TTestNetLink.Test_TheStartupRule;
begin
   BeginTest('uNetLink: the startup rule');

   CheckTrue(ShouldConnectAtStartup(True, 'A'), 'on, with an id: connect');
   CheckTrue(ShouldConnectAtStartup(True, 'Z'), 'the last letter is legal');
   CheckFalse(ShouldConnectAtStartup(False, 'A'),
              'off: a station that is not on a multi-op network never knocks');
   CheckFalse(ShouldConnectAtStartup(True, #0), 'on, but no computer id: nothing to announce');
   CheckFalse(ShouldConnectAtStartup(True, 'a'), 'ids are capital letters');
   CheckFalse(ShouldConnectAtStartup(True, '1'), 'and only letters');
   CheckFalse(ShouldConnectAtStartup(False, #0), 'off and no id');

   CheckFalse(Settings.Network.AutoConnect,
              'the shipped default is off: SERVER ADDRESS is LOCALHOST, so on would ' +
              'have every single-operator station retrying against itself');
end;

procedure TTestNetLink.Test_ObserversAreCalledOnceAndMayRemoveThemselves;
var
   list: TNetLinkObservers;
   a, b, c: TRecorder;
begin
   BeginTest('uNetLink: observers');

   list := TNetLinkObservers.Create;
   a := TRecorder.Create;
   b := TRecorder.Create;
   c := TRecorder.Create;
   try
      list.Add(a.Heard);
      list.Add(a.Heard);
      list.Add(b.Heard);
      CheckEquals(2, list.Count, 'the same method is added once');

      list.Notify(nil);
      CheckEquals(1, a.Calls, 'a heard it once, not twice');
      CheckEquals(1, b.Calls, 'b heard it');

      list.Remove(b.Heard);
      list.Remove(c.Heard);
      CheckEquals(1, list.Count, 'removing one that is not there changes nothing');
      list.Notify(nil);
      CheckEquals(2, a.Calls, 'a hears again');
      CheckEquals(1, b.Calls, 'b, removed, does not');

      (* A FORM BEING DESTROYED REMOVES ITSELF WHILE IT IS BEING TOLD. *)
      list.Remove(a.Heard);
      c.LeaveOnCall := list;
      list.Add(c.Heard);
      list.Add(b.Heard);
      list.Notify(nil);
      CheckEquals(1, c.Calls, 'c heard it and went');
      CheckEquals(2, b.Calls, 'and b, behind it in the list, still heard it');
      CheckEquals(1, list.Count, 'only b is left');
   finally
      c.Free;
      b.Free;
      a.Free;
      list.Free;
   end;
end;

(* ------------------------------------------------------- the real menu *)

procedure TTestNetLink.Test_TheNetMenuFollowsEveryState;
const
   SENDING_ROWS: array[0..5] of word = (
      menu_alt_setnettime, menu_send_message, menu_getserverlog,
      menu_clearserverlog, menu_clear_dupesheet_in_network,
      menu_clear_multsheet_in_network);
var
   s: TNetLinkState;
   i: integer;
   connectItem, disconnectItem, reconnectItem, showItem: TMenuItem;
begin
   BeginTest('uNet: the Net menu follows every state');

   connectItem := BuiltNetMenuItem(menu_net_connect);
   disconnectItem := BuiltNetMenuItem(menu_net_disconnect);
   reconnectItem := BuiltNetMenuItem(menu_net_reconnect);
   showItem := BuiltNetMenuItem(menu_net_showwindow);
   CheckTrue((connectItem <> nil) and (disconnectItem <> nil) and
             (reconnectItem <> nil) and (showItem <> nil),
             'the Net menu has Connect, Disconnect, Reconnect and Show window');
   if (connectItem = nil) or (disconnectItem = nil) or
      (reconnectItem = nil) or (showItem = nil) then
      begin
      Exit;
      end;

   CheckEquals(SNetMenuConnect, string(connectItem.Caption), 'Connect is captioned');
   CheckEquals(SNetMenuShowWindow, string(showItem.Caption), 'and Show Network window');

   (* THEY LEAD THE NET MENU, in the same popup as the rows that need a link. *)
   CheckTrue(connectItem.Parent = BuiltNetMenuItem(menu_alt_setnettime).Parent,
             'the link commands are in the same popup as the clock and message rows');
   CheckTrue(connectItem.MenuIndex < BuiltNetMenuItem(menu_alt_setnettime).MenuIndex,
             'and come first');
   CheckTrue(connectItem.Parent.Enabled,
             'the Net popup itself is never greyed: it holds the way to connect');

   for s := Low(TNetLinkState) to High(TNetLinkState) do
      begin
      ApplyNetworkMenuStateFor(s);
      CheckEquals(Ord(LinkCommandEnabled(s, nlcConnect)), Ord(connectItem.Enabled),
                  LinkStateName(s) + ': Connect');
      CheckEquals(Ord(LinkCommandEnabled(s, nlcDisconnect)), Ord(disconnectItem.Enabled),
                  LinkStateName(s) + ': Disconnect');
      CheckEquals(Ord(LinkCommandEnabled(s, nlcReconnect)), Ord(reconnectItem.Enabled),
                  LinkStateName(s) + ': Reconnect');
      CheckTrue(showItem.Enabled, LinkStateName(s) + ': Show window');
      for i := Low(SENDING_ROWS) to High(SENDING_ROWS) do
         begin
         CheckEquals(Ord(s = nlsConnected),
                     Ord(BuiltNetMenuItem(SENDING_ROWS[i]).Enabled),
                     LinkStateName(s) + ': row ' + IntToStr(SENDING_ROWS[i]));
         end;
      end;

   (* leave it as a station with no link finds it *)
   ApplyNetworkMenuState;
end;

(* ------------------------------------------------------------- the owner *)

procedure TTestNetLink.Test_AStationWithNoLinkAndNoWishIsOff;
begin
   BeginTest('uNet: no link and no wish is off');

   CheckFalse(NetLinkWanted, 'nothing has asked for a link');
   CheckFalse(NetIsConnected, 'and there is none');
   Check(NetLinkState = nlsOff, 'so the state is off, not "waiting"');
end;

(* A message the SERVER sends, through the real receive arm. *)
procedure TTestNetLink.FeedServerMessage(const aMessage: Word; const aParam: integer);
var
   msg: TServerMessagePtr;
   desync: boolean;
begin
   msg := TServerMessagePtr(@NetBuffer[1]);
   msg^ := Default(TServerMessage);
   msg^.smID := NET_SERVERMESSAGE_ID;
   msg^.smMessage := aMessage;
   msg^.smParam := aParam;
   CheckEquals(SizeOf(TServerMessage), ConsumeNetBuffer(SizeOf(TServerMessage), desync),
               'the whole server message was consumed');
   CheckFalse(desync, 'and the stream stayed on a message boundary');
end;

procedure TTestNetLink.Test_ARefusedServerIsLatchedAndConnectReArmsIt;
var
   connectBody, reconnectBody: string;
   netText: string;
begin
   BeginTest('uNet: a refused server is latched, and Connect and Reconnect re-arm it');

   ForgetServerRefusal;
   CheckFalse(NetLinkRefused, 'nothing is refused to begin with');

   (* THE SERVER SAYS IT SPEAKS ANOTHER PROTOCOL - the real arm, which latches
     the address and port, closes the link and tells the operator once. *)
   FeedServerMessage(SM_PROTOCOL_MISMATCH_MESSAGE, NET_PROTOCOL_VERSION + 1);
   CheckTrue(NetLinkRefused, 'the refusal stands');

   ForgetServerRefusal;
   CheckFalse(NetLinkRefused, 'ForgetServerRefusal re-arms it');

   (* THE RE-ARM IS THE OPERATOR'S ACT NOW, not the window's. *)
   netText := SourceText('src' + PathDelim + 'uNet.pas');
   CheckTrue(netText <> '', 'uNet.pas is beside the tests');
   connectBody := BodyOf(netText, 'PROCEDURE NETLINKCONNECT;');
   CheckTrue(Pos('FORGETSERVERREFUSAL;', connectBody) > 0,
             'Connect re-arms the refusal latch');
   reconnectBody := BodyOf(netText, 'PROCEDURE NETLINKRECONNECT;');
   CheckTrue(Pos('NETLINKCONNECT;', reconnectBody) > 0,
             'Reconnect goes through Connect, so it re-arms it too');
end;

procedure TTestNetLink.Test_ARefusedComputerIdIsLatchedAndConnectReArmsIt;
var
   saved: AnsiChar;
begin
   BeginTest('uNet: a refused computer id is latched, and re-armed with the rest');

   saved := Settings.Computer.Id;
   Settings.Computer.Id := 'B';
   try
      ForgetServerRefusal;
      (* 8320, naming the id the server would not have: the wire form is the
        ordinal *)
      FeedServerMessage(SM_COMPUTERID_IN_USE_MESSAGE, Ord(ComputerIDOrdinal('B')));
      CheckTrue(NetLinkRefused, 'the id refusal stands while the id is unchanged');

      Settings.Computer.Id := 'C';
      CheckFalse(NetLinkRefused, 'and clears itself when the operator changes the id');

      Settings.Computer.Id := 'B';
      CheckTrue(NetLinkRefused, 'a refused id is still refused when it comes back');
      ForgetServerRefusal;
      CheckFalse(NetLinkRefused, 'Connect (ForgetServerRefusal) asks the server again');
   finally
      Settings.Computer.Id := saved;
      ForgetServerRefusal;
   end;
end;

procedure TTestNetLink.Test_AStatusLineTellsTheObservers;
var
   rec: TRecorder;
begin
   BeginTest('uNet: a status line tells the observers and is kept for the title');

   rec := TRecorder.Create;
   try
      NetLinkObservers.Add(rec.Heard);
      try
         ShowConnectionStatus(TC_CONNECTEDTO);
         CheckTrue(rec.Calls >= 1, 'the observer was told on the main thread');
         CheckTrue(Pos(UpperCase(Trim(TC_CONNECTEDTO)), UpperCase(NetWindowCaption)) > 0,
                   'and the title reads the last line: ' + NetWindowCaption);

         ShowConnectionStatus(TC_DISCONNECTEDFROM);
         CheckTrue(Pos('DISCONNECTED', UpperCase(NetWindowCaption)) > 0,
                   'the next line replaces it: ' + NetWindowCaption);
      finally
         NetLinkObservers.Remove(rec.Heard);
      end;
   finally
      rec.Free;
   end;
end;

(* ------------------------------------------------------------ the window *)

procedure TTestNetLink.Test_AWindowOpenedMidSessionShowsEveryStation;
var
   form: TfrmNetwork;
   savedStatus: array[1..26] of TStationState;
   savedPos: array[1..26] of integer;
   savedTotal: integer;
   i: integer;
begin
   BeginTest('uNetworkForm: a window opened mid-session shows every station');

   for i := 1 to 26 do
      begin
      savedStatus[i] := StatusArray[i];
      savedPos[i] := PosInClientsList[i];
      end;
   savedTotal := TotalClients;
   try
      (* THE LINK HAS BEEN UP A WHILE: two stations announced themselves, and
        there was no window to see it. *)
      for i := 1 to 26 do
         begin
         StatusArray[i] := Default(TStationState);
         PosInClientsList[i] := 0;
         end;
      TotalClients := 0;

      StatusArray[1].ssComputerID := 'A';
      PutChars(StatusArray[1].ssName, 'Alpha');
      StatusArray[1].ssQSOTotals := 17;
      PutChars(StatusArray[1].ssCallsign, 'K1ABC');
      PosInClientsList[1] := 1;
      StatusArray[3].ssComputerID := 'C';
      PutChars(StatusArray[3].ssName, 'Charlie');
      StatusArray[3].ssQSOTotals := 42;
      PosInClientsList[3] := 2;
      TotalClients := 2;

      form := TfrmNetwork.Create(nil);
      try
         CheckTrue(TR4WNetworkForm = form, 'the form names itself the Network window');
         CheckEquals(0, form.lvClients.Items.Count,
                     'a new window knows nothing: it saw none of those messages');

         form.RefreshFromLink;

         CheckEquals(2, form.lvClients.Items.Count, 'both stations have a row');
         CheckEquals('Alpha', form.lvClients.Items[0].Caption, 'row 1 is station A');
         CheckEquals('A', form.lvClients.Items[0].SubItems[0], 'with its letter');
         CheckEquals('17', form.lvClients.Items[0].SubItems[5], 'and its QSO count');
         CheckEquals('K1ABC', form.lvClients.Items[0].SubItems[6], 'and its call');
         CheckEquals('Charlie', form.lvClients.Items[1].Caption, 'row 2 is station C');
         CheckEquals('42', form.lvClients.Items[1].SubItems[5], 'with its QSO count');
         CheckEquals(NetWindowCaption, form.Caption,
                     'and the title is the link''s, not the designer''s');

         (* A STATION THAT LEFT BEFORE THE WINDOW OPENED IS BLANK, NOT STALE *)
         StatusArray[1] := Default(TStationState);
         form.RefreshFromLink;
         CheckEquals('', form.lvClients.Items[0].Caption, 'a station that left shows nothing');
         CheckEquals('', form.lvClients.Items[0].SubItems[5], 'not its old QSO count');
         CheckEquals('Charlie', form.lvClients.Items[1].Caption, 'the others are untouched');
      finally
         form.Free;
      end;
   finally
      for i := 1 to 26 do
         begin
         StatusArray[i] := savedStatus[i];
         PosInClientsList[i] := savedPos[i];
         end;
      TotalClients := savedTotal;
   end;
end;

procedure TTestNetLink.Test_ADestroyedWindowIsNoLongerTold;
var
   form: TfrmNetwork;
   before: integer;
begin
   BeginTest('uNetworkForm: a destroyed window leaves nothing behind');

   before := NetLinkObservers.Count;
   form := TfrmNetwork.Create(nil);
   CheckEquals(before + 1, NetLinkObservers.Count, 'it subscribed when created');
   form.Free;
   CheckEquals(before, NetLinkObservers.Count, 'and unsubscribed in its destructor');
   CheckTrue(TR4WNetworkForm = nil, 'the global does not point at a freed form');

   (* The link may report while no window exists. It must not reach a freed
     form: this is the dangling reference the observer list exists to prevent. *)
   NetLinkChanged;
   CheckTrue(True, 'a change with no window is harmless');
end;

procedure TTestNetLink.Test_TheWindowStartsAndStopsNothing;
var
   formText, showBody, closeBody: string;
begin
   BeginTest('uNetworkForm: showing and closing connect and disconnect nothing');

   formText := SourceText('src' + PathDelim + 'ui' + PathDelim + 'lcl' + PathDelim +
                          'uNetworkForm.pas');
   CheckTrue(formText <> '', 'uNetworkForm.pas is beside the tests');

   showBody := BodyOf(formText, 'PROCEDURE TFRMNETWORK.HANDLESHOW');
   closeBody := BodyOf(formText, 'PROCEDURE TFRMNETWORK.HANDLECLOSE');
   CheckTrue(showBody <> '', 'HandleShow is there');
   CheckTrue(closeBody <> '', 'HandleClose is there');

   CheckEquals(0, Pos('TRYCONNECTTONETWORK', showBody), 'showing does not connect');
   CheckEquals(0, Pos('FORGETSERVERREFUSAL', showBody), 'nor re-arm a refusal');
   CheckTrue(Pos('REFRESHFROMLINK', showBody) > 0, 'it asks the link for its state');
   CheckEquals(0, Pos('NETDISCONNECT', closeBody), 'closing does not disconnect');
   CheckEquals(0, Pos('NETLINK', closeBody), 'nor touch the link at all');
   CheckEquals(0, Pos('TTIMER', formText), 'the reconnect timer is not the window''s');
   CheckEquals(0, Pos('TRYCONNECTTONETWORK', formText), 'and nothing here connects');
   CheckTrue(Pos('NETLINKOBSERVERS.ADD(LINKCHANGED)', formText) > 0,
             'it follows the link by subscribing');
   CheckTrue(Pos('NETLINKOBSERVERS.REMOVE(LINKCHANGED)', formText) > 0,
             'and unsubscribes');
end;

procedure TTestNetLink.Test_StartupAsksUNetToDecide;
var
   mainText, startupBody: string;
   startAt, windowsAt: integer;
begin
   BeginTest('uProgramMain: startup asks uNet whether to connect');

   mainText := SourceText('src' + PathDelim + 'uProgramMain.pas');
   CheckTrue(mainText <> '', 'uProgramMain.pas is beside the tests');
   startAt := Pos(#10 + '  NETLINKSTARTUP;', mainText);
   windowsAt := Pos(#10 + '  OPENOTHERWINDOWS;', mainText);
   CheckTrue(startAt > 0, 'startup calls NetLinkStartup');
   CheckTrue((windowsAt > 0) and (startAt > windowsAt),
             'after the windows exist, and so after every headless Halt');

   startupBody := BodyOf(SourceText('src' + PathDelim + 'uNet.pas'),
                         'PROCEDURE NETLINKSTARTUP;');
   CheckTrue(Pos('SHOULDCONNECTATSTARTUP(', startupBody) > 0,
             'uNet applies the rule from uNetLink');
   CheckTrue(Pos('SETTINGS.NETWORK.AUTOCONNECT', startupBody) > 0,
             'to the NETWORK AUTO CONNECT setting');
end;

procedure TTestNetLink.RunAllTests;
begin
   Test_TheStateFollowsFourFacts;
   Test_EachStateOffersItsCommands;
   Test_OnlyALiveLinkEnablesTheRowsThatSend;
   Test_TheStartupRule;
   Test_ObserversAreCalledOnceAndMayRemoveThemselves;
   Test_TheNetMenuFollowsEveryState;
   Test_AStationWithNoLinkAndNoWishIsOff;
   Test_ARefusedServerIsLatchedAndConnectReArmsIt;
   Test_ARefusedComputerIdIsLatchedAndConnectReArmsIt;
   Test_AStatusLineTellsTheObservers;
   Test_AWindowOpenedMidSessionShowsEveryStation;
   Test_ADestroyedWindowIsNoLongerTold;
   Test_TheWindowStartsAndStopsNothing;
   Test_StartupAsksUNetToDecide;
   DrainAsyncQueue;
end;

initialization

finalization
   (* Only set when this suite ran alone and built the menu itself. *)
   FreeAndNil(GTestMenuOwner);

end.

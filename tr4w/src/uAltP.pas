{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
 unit uAltP;
{$I tr4w.inc}

interface

uses
  Tree,
  LogCW,
  TF,
  VC,
  uCommctrl,
  uEditMessage,
  Windows,
  Messages,
  LogWind,
  uTR4WStrings;

type
  TOtherMessageType = packed record
    omCommand: PAnsiChar;
    omCWMessage: MessagePointer;
    omSSBMessage: MessagePointer;
  end;

  TOtherShortMessageType = packed record
    osmCommand: PAnsiChar;
    osmMessage: PAnsiChar;
  end;

function AltPDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
procedure DisplaymessagesList(mt: MesWindowType; MessageMode: ModeType);
procedure EditMessage;

const
  NumberOfOtherMessages                 = 9;
  OthermessagesArray                    : array[0..NumberOfOtherMessages - 1] of TOtherMessageType =
{(*}
    (
    (omCommand: 'CALL OK NOW %s MESSAGE';    omCWMessage: @CorrectedCallMessage;          omSSBMessage: @CorrectedCallPhoneMessage),
    (omCommand: 'CQ %s EXCHANGE';            omCWMessage: @CQExchange;                    omSSBMessage: @CQPhoneExchange),
    (omCommand: 'CQ %s EXCHANGE NAME KNOWN'; omCWMessage: @CQExchangeNameKnown;           omSSBMessage: @CQPhoneExchangeNameKnown),
    (omCommand: 'QSL %s MESSAGE';            omCWMessage: @QSLMessage;                    omSSBMessage: @QSLPhoneMessage),
    (omCommand: 'QSO BEFORE %s MESSAGE';     omCWMessage: @QSOBeforeMessage;              omSSBMessage: @QSOBeforePhoneMessage),
    (omCommand: 'QUICK QSL %s MESSAGE';      omCWMessage: @QuickQSLMessage1;              omSSBMessage: @QuickQSLPhoneMessage),
    (omCommand: 'REPEAT S&P %s EXCHANGE';    omCWMessage: @RepeatSearchAndPounceExchange; omSSBMessage: @RepeatSearchAndPouncePhoneExchange),
    (omCommand: 'S&P %s EXCHANGE';           omCWMessage: @SearchAndPounceExchange;       omSSBMessage: @SearchAndPouncePhoneExchange),
    (omCommand: 'TAIL END %s MESSAGE';       omCWMessage: @TailEndMessage;                omSSBMessage: @TailEndPhoneMessage)
{*)}
  );

  NumberOfOtherShortMessages = 4;
  OtherShortMessagesArray: array[0..NumberOfOtherShortMessages - 1] of TOtherShortMessageType =
{(*}
    (
    (osmCommand: 'SHORT 0'; osmMessage: @Short0  ),
    (osmCommand: 'SHORT 1'; osmMessage: @Short1  ),
    (osmCommand: 'SHORT 2'; osmMessage: @Short2  ),
    (osmCommand: 'SHORT 9'; osmMessage: @Short9  )
{*)}
);

var

  flashreminder                         : boolean;
  ReminderDlgHandle                     : HWND;
  AltPListView                          : HWND;
  LastSelectedMessage                   : integer;
  // Row to pre-select when the dialog next opens (0 = F1, the historical
  // default). A caller -- e.g. right-click on a function-key button -- sets
  // this just before OpenListOfMessages to jump straight to that key; the
  // dialog consumes and resets it on WM_INITDIALOG. Issue #1001.
  InitialAltPSelection                  : integer;


// the Alt-P programmable-message window.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowAltP;

implementation
uses MainUnit;
var
  AltWnd                                : HWND;

const
  CQCWMEMORYF                           = 'CQ CW MEMORY F %u';
  CQCWMEMORYALTF                        = 'CQ CW MEMORY ALTF%u';
  CQCWMEMORYCONTROLF                    = 'CQ CW MEMORY CONTROLF%u';

function AltPDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  1;
var
  elvc                                  : tagLVCOLUMNA;

begin
  Result := False;
  case Msg of

    WM_INITDIALOG:
      begin
        // Honor a caller-requested initial row (Issue #1001), then reset to the
        // default so a subsequent plain open (Alt-P) lands on F1 as before.
        LastSelectedMessage := InitialAltPSelection;
        InitialAltPSelection := 0;
        AltWnd := hwnddlg;
//        AltPListView := Get101Window(hwnddlg);

        Windows.SetWindowTextW(hwnddlg, PWideChar(RC_LISTOFMESS));
        AltPListView := CreateListView2(0, 0, 790, 350, hwnddlg);

        // Issue #997: asm tWM_SETFONT (EAX = AltPListView above).
        tWM_SETFONT(AltPListView, TerminalFont);
        ListView_SetExtendedListViewStyle(AltPListView, LVS_EX_GRIDLINES or LVS_EX_FULLROWSELECT);
        elvc.Mask := LVCF_TEXT or LVCF_WIDTH or LVCF_FMT;
        elvc.fmt := LVCFMT_LEFT;
        elvc.pszText := 'Command'; //TC_COMMAND;
        elvc.cx := 270;
        uCommctrl.ListView_InsertColumnA(AltPListView, 0, elvc);

        elvc.pszText := 'Message';
        elvc.cx := 340;
        uCommctrl.ListView_InsertColumnA(AltPListView, 1, elvc);

        elvc.pszText := 'Caption';
        elvc.cx := 155;
        uCommctrl.ListView_InsertColumnA(AltPListView, 2, elvc);

        DisplaymessagesList(MesWindow, ActiveMode);

      end;
    WM_COMMAND:
      begin
        if wParam = 2 then
           begin
           goto 1;
           end;
        if lParam = 0 then if LoWord(wParam) = 1 then EditMessage;
      end;
    WM_CLOSE: 1: EndDialog(hwnddlg, 0);

    WM_NOTIFY:
      begin
        with PNMHdr(lParam)^ do
           begin
           case code of
             NM_DBLCLK: EditMessage;
           end;
           end;
      end;
  end;

end;

procedure DisplaymessagesList(mt: MesWindowType; MessageMode: ModeType);
label
  1;
var
  { AnsiChar, for the reason documented in uFunctionKeys.ShowFMessages: Char
    is WideChar here, the memory arrays are indexed by the AnsiChar
    constants F1..AltF12, and a WideChar holding CHR(139) actually holds
    U+2039 -- ordinal 8249 -- so `for Key := F1 to AltF12` walked straight
    off the end of the array as soon as it passed 127. This is the same
    fault as the Ctrl-P crash, reached through Alt-P instead. }
  Key                                   : AnsiChar;
  TempString                            : ShortString;
  elvi                                  : TLVItem;
//  TempPchar                             : PChar;
  TempInt                               : integer;
  ModeString                            : PAnsiChar;
  OpModeString                          : PAnsiChar;
  ButtonString                          : PAnsiChar;
  TempMessagePointer                    : MessagePointer;
  TempMode                              : ModeType;
begin
  ListView_DeleteAllItems(AltPListView);
//  if Mode in [CW, Digital] then ModeString := 'CW' else ModeString := 'SSB';

  TempMode := MessageMode;
  if TempMode = Digital then
     begin
     TempMode := CW;
     end;

  case TempMode of
    Digital, CW: ModeString := 'CW';
//    Digital: ModeString := 'DIG'
  else
    ModeString := 'SSB';
  end;

//  if mt = OtherMsgWin then ModeString := 'CW';

  if mt = CQMsgWin then
    OpModeString := 'CQ' else
    if mt = ExMsgWin then
       begin
       OpModeString := 'EX'
       end
    else
       begin

       for TempInt := 0 to NumberOfOtherMessages - 1 do
          begin
          elvi.Mask := LVIF_TEXT;
          elvi.iItem := TempInt;
          elvi.iSubItem := 0;

          // Issue #997: asm wsprintf-push -> TF.Format. The format is a RUNTIME
          // string (omCommand, e.g. 'CQ %s EXCHANGE'); TF.Format == wsprintfA so the
          // runtime C format + ModeString work directly.
          TF.Format(wsprintfBuffer, OthermessagesArray[TempInt].omCommand, ModeString);
          elvi.pszText := wsprintfBuffer;

          ListView_InsertItem(AltPListView, elvi);

          elvi.iSubItem := 1;
          if TempMode = Phone then
             begin
             elvi.pszText := @OthermessagesArray[TempInt].omSSBMessage^[1];
             OthermessagesArray[TempInt].omSSBMessage^[Ord(OthermessagesArray[TempInt].omSSBMessage^[0]) + 1] := #0;
             end
          else
             begin
             elvi.pszText := @OthermessagesArray[TempInt].omCWMessage^[1];
             OthermessagesArray[TempInt].omCWMessage^[Ord(OthermessagesArray[TempInt].omCWMessage^[0]) + 1] := #0;
             end;

          ListView_SetItem(AltPListView, elvi);

          end;

       if TempMode = CW then
          begin
          for TempInt := 0 to NumberOfOtherShortMessages - 1 do
             begin

             elvi.iItem := TempInt + NumberOfOtherMessages;
             elvi.iSubItem := 0;
             elvi.pszText := OtherShortMessagesArray[TempInt].osmCommand;
             ListView_InsertItem(AltPListView, elvi);

             elvi.iSubItem := 1;

             wsprintfBuffer[0] := AnsiChar(OtherShortMessagesArray[TempInt].osmMessage[0]);
             wsprintfBuffer[1] := #0;
             elvi.pszText := wsprintfBuffer;
             ListView_SetItem(AltPListView, elvi);
             end;
          end;

       goto 1;
       end;

  for Key := F1 to AltF12 do
     begin
     elvi.Mask := LVIF_TEXT;
     elvi.iItem := Ord(Key) - Ord(F1);
     elvi.iSubItem := 0;

     if Key in [F1..F12] then
        begin
        ButtonString := '';
        TempInt := Ord(Key) - Ord(F1) + 1;
        end;

     if Key in [ControlF1..ControlF12] then
        begin
        ButtonString := 'CONTROL';
        TempInt := Ord(Key) - Ord(F1) + 1 - 12;
        end;

     if Key in [AltF1..AltF12] then
        begin
        ButtonString := 'ALT';
        TempInt := Ord(Key) - Ord(F1) + 1 - 24;
        end;

     // Issue #997: asm wsprintf-push -> TF.Format. cdecl-reverse pushes ->
     // OpModeString, ModeString, ButtonString, TempInt (%s %s MEMORY %sF%u).
     TF.Format(wsprintfBuffer, '%s %s MEMORY %sF%u', OpModeString, ModeString, ButtonString, TempInt);

     elvi.pszText := wsprintfBuffer;
     ListView_InsertItem(AltPListView, elvi);

     elvi.iSubItem := 1;
     if mt = CQMsgWin then
        begin
        TempString := GetCQMemoryString(TempMode, Key);
        end;
     if mt = ExMsgWin then
        begin
        TempString := GetEXMemoryString(TempMode, Key);
        if Key = F1 then
           begin
           TempString := 'Set by the MY CALL';
           end;
        if Key = F2 then
           begin
           TempString := 'Set by S&P EXCHANGE';
           end;

  //  TC_F1SETBYTHEMYCALLSTATEMENTINCONFIG  = 'F1 - Set by the MY CALL statement in config file';
  //  TC_F2SETBYSPEXCHANGEANDREPEATSP       = 'F2 - Set by S&P EXCHANGE and REPEAT S&P EXCHANGE';
        end;
     if TempString <> '' then
        begin
        TempString[Ord(TempString[0]) + 1] := #0;
        elvi.pszText := @TempString[1];
        end
     else
        begin
        elvi.pszText := nil;
        end;
     ListView_SetItem(AltPListView, elvi);

     elvi.iSubItem := 2;
     if mt = CQMsgWin then
        begin
        TempMessagePointer := CQCaptionMemory[TempMode, Key];
        end;
     if mt = ExMsgWin then
        begin
        TempMessagePointer := EXCaptionMemory[TempMode, Key];
        end;

     if TempMessagePointer <> nil then
        begin
        TempString := TempMessagePointer^;
        TempString[Ord(TempString[0]) + 1] := #0;
        elvi.pszText := @TempString[1];
        end
     else
        begin
        elvi.pszText := nil;
        end;

     ListView_SetItem(AltPListView, elvi);
     end;
  1:
  elvi.Mask := LVIF_STATE;
  elvi.stateMask := 3;
  elvi.State := LVIS_SELECTED or LVIS_FOCUSED;
  SendMessage(AltPListView, LVM_SETITEMSTATE, LastSelectedMessage, LONGINT(@elvi));
  SendMessage(AltPListView, LVM_ENSUREVISIBLE, LastSelectedMessage, LONGINT(False));

end;

procedure EditMessage;
begin
  LastSelectedMessage := ListView_GetNextItem(AltPListView, -1, LVNI_SELECTED);
  if LastSelectedMessage = -1 then Exit;
  if MesWindow = ExMsgWin then if LastSelectedMessage in [0, 1] then Exit;
//  DialogBoxParam(hInstance, MAKEINTRESOURCE(76), AltWnd, @EditMessageDlgProc, LastSelectedMessage);
  ShowEditMessage(AltWnd, LastSelectedMessage);
end;


procedure ShowAltP;
begin
   CreateModalDialog(397, 177, tr4whandle, @AltPDlgProc, 0);
end;
end.


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
  SysUtils,   { Format -- replaced TF.Format/wsprintfA }
  TypInfo,    { GetEnumName -- log enums by NAME, never by ordinal }
  Tree,
  LogCW,
  TF,
  VC,
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
uses MainUnit,
  uAltPForm;   { the view -- see ShowAltP }

const
  CQCWMEMORYF                           = 'CQ CW MEMORY F %u';
  CQCWMEMORYALTF                        = 'CQ CW MEMORY ALTF%u';
  CQCWMEMORYCONTROLF                    = 'CQ CW MEMORY CONTROLF%u';

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
  { The bank's first and last key.  AnsiChar for the reason above -- these
    index the same memory arrays. }
  BankFirst                             : AnsiChar;
  BankLast                              : AnsiChar;
  TempString                            : ShortString;
  { The row being built.  The Win32 path had no equivalent: it wrote each
    column straight into a TLVItem and null-terminated the source
    ShortString IN PLACE to do it. }
  RowCommand                            : AnsiString;
  RowMessage                            : AnsiString;
  RowCaption                            : AnsiString;
  TempInt                               : integer;
  ModeString                            : PAnsiChar;
  OpModeString                          : PAnsiChar;
  ButtonString                          : PAnsiChar;
  TempMessagePointer                    : MessagePointer;
  TempMode                              : ModeType;
begin
  AltPBeginUpdate;
  AltPClear;
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
          { The format string is DATA -- omCommand is e.g. 'CQ %s EXCHANGE' --
            and carries only %s, which means the same in wsprintf and in
            SysUtils.Format.  See docs and the TF.Format tranches. }

          RowCommand := SysUtils.Format(AnsiString(OthermessagesArray[TempInt].omCommand),
                                               [string(AnsiString(ModeString))]);

          { The message memories are ShortStrings.  The Win32 path wrote a #0
            one byte PAST the length into the live memory to make a PAnsiChar
            of them; assigning the ShortString needs none of that. }

          if TempMode = Phone then
             begin
             RowMessage := OthermessagesArray[TempInt].omSSBMessage^;
             end
          else
             begin
             RowMessage := OthermessagesArray[TempInt].omCWMessage^;
             end;

          AltPAddRow(RowCommand, RowMessage, '', -1);
          end;

       if TempMode = CW then
          begin
          for TempInt := 0 to NumberOfOtherShortMessages - 1 do
             begin

             { A SHORT message is ONE character -- osmMessage points at a
               ShortString whose [0] is its length byte, and the Win32 code
               copied that byte as the text.  Preserved exactly. }

             RowCommand := AnsiString(OtherShortMessagesArray[TempInt].osmCommand);
             RowMessage := AnsiChar(OtherShortMessagesArray[TempInt].osmMessage[0]);

             AltPAddRow(RowCommand, RowMessage, '', -1);
             end;
          end;

       AltPShowBankFilter(False);
       goto 1;
       end;

  { ONE BANK AT A TIME.  F1-F12 fit without scrolling; the Control and Alt
    banks are rarely programmed and pushed the list to 36 rows, most of them
    empty (NY4I, 2026-08-31).  The filter is the view's radio group; which
    keys are in a bank is this unit's business. }

  AltPShowBankFilter(True);
  BankFirst := AnsiChar(Ord(F1) + AltPBank * 12);
  BankLast  := AnsiChar(Ord(BankFirst) + 11);

  for Key := BankFirst to BankLast do
     begin
     RowMessage := '';
     RowCaption := '';

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

     { '%s' and '%u' mean the same in wsprintf and SysUtils.Format. }

     RowCommand := SysUtils.Format('%s %s MEMORY %sF%u',
                                   [string(AnsiString(OpModeString)),
                                    string(AnsiString(ModeString)),
                                    string(AnsiString(ButtonString)),
                                    TempInt]);
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
     RowMessage := TempString;
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
        RowCaption := TempMessagePointer^;
        end;

     AltPAddRow(RowCommand, RowMessage, RowCaption, Ord(Key) - Ord(F1));
     end;
  1:
  AltPEndUpdate;

  { OBSERVABLE, and it exists because of how this conversion failed: the
    window opened with correct columns, a correct title and NOT ONE ROW,
    because removing the dialog proc removed the WM_INITDIALOG call that
    filled it.  Everything visible was right, so it read as missing data.
    A row count says which it is, and lets the UI harness assert it. }

  if logger.IsDebugEnabled then
     begin
     { BY NAME, NOT BY ORDINAL.  This line logged Ord(MessageMode) and read
       'mode=1', which took a trip to VC.pas to learn means Digital and not
       Phone -- ModeType is (CW, Digital, Phone, ...) and the obvious reading
       is wrong (NY4I, 2026-08-31).  Worse, an ordinal is not stable: insert a
       mode and every historical log line silently means something else.

       GetEnumName is the same answer the radio registry reached, and for the
       same reason -- see RadioTypeToken, where a hand-maintained parallel
       table drifted from the enum and silently pointed four Kenwoods at the
       wrong driver. }

     logger.Debug('[AltP] filled %d row(s), window=%s mode=%s, selecting %d',
                  [AltPRowCount,
                   GetEnumName(TypeInfo(MesWindowType), Ord(mt)),
                   GetEnumName(TypeInfo(ModeType), Ord(MessageMode)),
                   LastSelectedMessage]);
     end;

  { BY KEY, not by row.  LastSelectedMessage is a key ordinal (0..35) and
    always was -- ResolveFunctionKeyRow computes (aKey - 112) + 0/12/24,
    which is Ord(Key) - Ord(F1).  It merely happened to equal the row index
    while the list showed all thirty-six in order.  With a bank filter it
    does not, and selecting by row would land on a different message. }

  if not AltPSelectByKey(LastSelectedMessage) then
     begin
     { Not in this bank -- the other-messages window, or a stale key.
       Fall back to the first row rather than leaving nothing selected. }
     AltPSelect(0);
     end;
end;

procedure EditMessage;
var
  Row        : integer;
  SelectedKey: AnsiChar;
begin
  Row := AltPSelectedIndex;
  if Row = -1 then
     begin
     Exit;
     end;

  { REMEMBERED BY KEY so the next open lands on the same message whichever
    bank is showing then. }
  LastSelectedMessage := AltPSelectedKey;

  { F1 and F2 of the EXCHANGE window are derived -- 'Set by the MY CALL' and
    'Set by S&P EXCHANGE' -- and are not editable.  ASKED OF THE KEY, not of
    the row: with a bank filter, rows 0 and 1 are CONTROLF1/CONTROLF2 or
    ALTF1/ALTF2 depending on what is showing, and the old row test would have
    silently refused to edit those while letting the real F1/F2 through. }

  { THE KEYS, NOT THEIR NUMBERS.  This read `in [0, 1]`, and 0 and 1 are F1
    and F2 only because of where they sit in the AnsiChar key constants --
    the same class of thing as logging Ord(mode) and having to look up what
    1 means (NY4I, 2026-08-31).  Naming the keys says the rule out loud:
    the EXCHANGE window's F1 and F2 are derived, not stored. }

  SelectedKey := AnsiChar(Ord(F1) + LastSelectedMessage);

  if (MesWindow = ExMsgWin) and
     (SelectedKey in [F1, F2]) then
     begin
     Exit;
     end;

  ShowEditMessage(AltPParentHandle, Row);
end;


{ What WM_INITDIALOG used to do.  The window shows the CURRENT message
  window and mode, so it is read at open time, not captured earlier. }
procedure FillAltPList;
begin
   DisplaymessagesList(MesWindow, ActiveMode);
end;

procedure ShowAltP;
begin
   { The seam this procedure was written for.  Everything the dialog proc
     used to do on WM_INITDIALOG -- title, columns, font, fill, initial
     selection -- is either the form's (uAltPForm) or happens here. }

   LastSelectedMessage := InitialAltPSelection;
   InitialAltPSelection := 0;

   uAltPForm.ShowAltPWindow;
end;

initialization
   { The view raises Edit; this unit decides what it means.  Assigned here
     rather than in the form so uAltPForm depends on nothing. }
   AltPFormOnEdit := @EditMessage;
   AltPFormOnFill := @FillAltPList;
end.


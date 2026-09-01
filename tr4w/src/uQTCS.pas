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
unit uQTCS;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  TF,
  VC,
  utils_file,
  uTotal,
  LogDupe,
  PostUnit,
  LogStuff,
  Windows,
  Tree,
  LogCW,
  uDialogs,
  LogWind,
  LogRadio,
  Messages
  ,
  uTR4WStrings,
  uAnsiStr;

// One of the eight sending commands, by its QTC_SEND_* id.  Was the dialog
// proc's WM_COMMAND case; the window calls this and owns no logic of its own.
procedure QTCSendCommand(const aCommand: integer);

procedure SendQTC(QTC: integer);
procedure SaveQTCS;
procedure SetSendedQSOs;

const
  // QTC_HK_* and RegQTCSHotKeys are GONE with the dialog.  PageUp, PageDown and
  // F10 were registered as SYSTEM-WIDE hotkeys, because a Win32 dialog's
  // buttons swallow keys before the dialog proc sees them; the form handles
  // them in OnKeyDown with KeyPreview instead, which is window-local and cannot
  // fail to register.

  QTC_SEND_NEXT                         = 100;
  QTC_SEND_QRVSTRING                    = 101;
  QTC_SEND_QRV                          = 102;
  QTC_SEND_TIME                         = 103;
  QTC_SEND_CALL                         = 104;
  QTC_SEND_NUMBER                       = 105;
  QTC_SEND_ALL                          = 106;
  QTC_SEND_STOP                         = 107;

  QTCCustomMessages                     = 7;
var
  QTCTXButtonsPChar                     : array[0..QTCCustomMessages] of PAnsiChar =
    (
    'N&EXT [return]',
    nil,
    'Q&RV?',
    '&TIME',
    '&CALL',
    '&NR',
    '&ALL',
    '&STOP'
    );
var
  // THE STATE STAYS HERE, and the window does not own it: a QTC book that is
  // half sent is contest state, not window state.  ArrowWindow and QTCSWindow
  // were the two HWNDs and are gone -- the marker is a label the form moves,
  // and the form closes itself.
  QTCWasSend                            : integer ;
  LastSendedQTCHour                     : integer = -1;

// the WAE QTC send window.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowQTCSend;

implementation
uses
  uNet,
  LOGSUBS2,
  LOGWAE,
  uQTCSendForm,
  MainUnit;

procedure QTCSendCommand(const aCommand: integer);
var
   TempString: Str160;
begin
   case aCommand of
      QTC_SEND_NEXT:
         begin
         if QTCWasSend = NumberMessagesToBeSent then
            begin
            { The whole book has gone out; ask for the QSL and save. }
            if YesOrNo2(SysUtils.Format('QSL %u/%u ?',
                           [QTCNumber, QTCWasSend])) <> IDOK then
               begin
               Exit;
               end;
            SaveQTCS;
            Exit;
            end;

         inc(QTCWasSend);

         { The view catches up with the state it does not own -- this replaces
           EnableWindowTrue, MoveWindow on the arrow and InvalidateRect. }
         if QTCSendFormOpen then
            begin
            QTCSendForm.RefreshProgress;
            end;

         SendQTC(QTCWasSend);
         end;

      QTC_SEND_QRVSTRING: SendStringAndStop(QRVString);

      QTC_SEND_QRV: SendStringAndStop('QRV?');

      QTC_SEND_TIME:
         begin
         if QTCWasSend = 0 then
            begin
            Exit;
            end;
         { Four digits, zero-padded: HHMM read back to the other station. }
         TempString := AnsiString(SysUtils.Format('%.4u',
                          [QTCsToBeSendArray[QTCWasSend].qsTime]));
         SendStringAndStop(TempString);
         end;

      QTC_SEND_CALL:
         begin
         if QTCWasSend = 0 then
            begin
            Exit;
            end;
         SendStringAndStop(QTCsToBeSendArray[QTCWasSend].qsCall);
         end;

      QTC_SEND_NUMBER:
         begin
         if QTCWasSend = 0 then
            begin
            Exit;
            end;
         SendStringAndStop(IntToStr(QTCsToBeSendArray[QTCWasSend].qsNumber));
         end;

      QTC_SEND_ALL: SendQTC(QTCWasSend);

      QTC_SEND_STOP:
         begin
         if YesOrNo(TC_DOYOUREALLYWANTSTOPNOW) = IDNO then
            begin
            Exit;
            end;

         if QTCWasSend > 0 then
            begin
            if YesOrNo(SysUtils.Format(TC_WASMESSAGENUMBERCONFIRMED,
                          [QTCWasSend])) = IDNO then
               begin
               dec(QTCWasSend);
               end;
            end;

         if QTCWasSend < 1 then
            begin
            { Nothing confirmed -- the book is abandoned, and the window's own
              close path says so. }
            CloseQTCSendWindow;
            Exit;
            end;

         SaveQTCS;
         end;
   end;
end;

procedure SendQTC(QTC: integer);
var
  TempString                            : Str160;
  Time                                  : integer;
  Number                                : integer;
  p                                     : PAnsiChar;
  Format                                : PAnsiChar;
  TempQTCMinutes                        : boolean;
const
  FormatArray                           : array[boolean, boolean, boolean] of PAnsiChar =
//QTCQRS,QTCExtraSpace,QTCMinutes
//false,true
  (
    (
    ('%04u %s %u', '%02u %s %u'),
    ('%04u  %s  %u', '%02u  %s  %u')
    )
    ,
    (
    (ControlS + '%04u %s %u' + ControlF, ControlS + '%02u %s %u' + ControlF),
    (ControlS + '%04u  %s  %u' + ControlF, ControlS + '%02u  %s  %u' + ControlF)
    )

    );
begin
  if not (QTC in [1..10]) then Exit;
{
  Format := '%04u %s %u';
  if QTCQRS then
  begin
    Format := ControlS + '%04u %s %u' + ControlF;
    if QTCExtraSpace then Format := ControlS + '%04u  %s  %u' + ControlF;
  end
  else
    if QTCExtraSpace then Format := '%04u  %s  %u';
}

  Time := QTCsToBeSendArray[QTC].qsTime;
  p := @QTCsToBeSendArray[QTC].qsCall[1];
  Number := QTCsToBeSendArray[QTC].qsNumber;

  TempQTCMinutes := (LastSendedQTCHour = (Time div 100)) and QTCMinutes;
  Format := FormatArray[QTCQRS, QTCExtraSpace, TempQTCMinutes];

  if QTCMinutes then
     begin
     if LastSendedQTCHour = (Time div 100) then
        begin
        Time := Time mod 100;
        end;
     LastSendedQTCHour := QTCsToBeSendArray[QTC].qsTime div 100;
     end;

  SetLength(TempString, 160);
  // Issue #997: asm wsprintf-push -> TF.Format (QUALIFIED -- the local var
  // `Format` shadows TF.Format). Runtime format `Format`; cdecl-reverse -> Time, p, Number.
  TempString[0] := AnsiChar(TF.Format(@TempString[1], Format, Time, p, Number));
  SendStringAndStop(TempString);
end;

procedure SaveQTCS;
var
  I                                     : integer;
  QTCRXData                             : ContestExchange;

begin
  for I := 1 to QTCWasSend do 
     begin
     IncrementQTCCount(QTCCallsign);
     Windows.ZeroMemory(@QTCRXData, SizeOf(ContestExchange));
     QTCRXData.ceRecordKind := rkQTCS;
 //    tGetQSOSystemTime(QTCRXData.tSysTime);
 //    QTCRXData.Band := ActiveBand;
 //    QTCRXData.Mode := ActiveMode;
 //    QTCRXData.ceComputerID := ComputerID;
     QTCRXData.Callsign := QTCCallsign;
     {Time}
     QTCRXData.NumberSent := QTCsToBeSendArray[I].qsTime;
     {EU Callsign}
     QTCRXData.Kids := QTCsToBeSendArray[I].qsCall;
     {Number}
     QTCRXData.NumberReceived := QTCsToBeSendArray[I].qsNumber;
     {QTCNumber}
     QTCRXData.RandomCharsReceived := IntToStr(QTCNumber) + '/' + IntToStr(NumberMessagesToBeSent);
     {QTCNumberQTCBooksSent}
     QTCRXData.QSOPoints := QTCNumber;
 //    tAddQSOToLog(QTCRXData);
     if AddRecordToLogAndSendToNetwork(QTCRXData) then
        begin
        Sleep(100);
        end;
     end;
  inc(NumberQTCBooksSent);
  SetSendedQSOs;
  { The book is saved, so the window goes WITHOUT asking whether the operator
    means to abandon it -- EndDialog had the same property, it did not go back
    through WM_CLOSE. }
  CloseQTCSendWindow;
end;

procedure SetSendedQSOs;
label
  1, 2;
var
  pNumberOfBytesRead                    : Cardinal;
 
  SignedQSOs                            : integer;
begin
  if not OpenLogFile then Exit;
  ReadVersionBlock;
  SignedQSOs := 1;
  1:
  Windows.ReadFile(LogHandle, TempRXData, SizeOf(ContestExchange), pNumberOfBytesRead, nil);
  if pNumberOfBytesRead = SizeOf(ContestExchange) then
     begin
     if TempRXData.ceWasSendInQTC = True then
        begin
        goto 1;
        end;
     if (TempRXData.ceQSOID1 = QTCsToBeSendArray[SignedQSOs].qsQSOID1) and (TempRXData.ceQSOID2 = QTCsToBeSendArray[SignedQSOs].qsQSOID2) then
        begin
        TempRXData.ceWasSendInQTC := True;
        tSetFilePointer(-1 * SizeOf(ContestExchange), FILE_CURRENT);
        sWriteFile(LogHandle, TempRXData, SizeOf(ContestExchange));
        if SendRecordToServer(NET_EDITEDQSO_ID, TempRXData) then
           begin
           Sleep(50);
           end;
        if SignedQSOs = QTCWasSend then
           begin
           goto 2;
           end;
        inc(SignedQSOs);
        end;
     goto 1;
     end;
  2:
  CloseLogFile;

end;

procedure ShowQTCSend;
begin
   ShowQTCSendWindow;
end;
end.


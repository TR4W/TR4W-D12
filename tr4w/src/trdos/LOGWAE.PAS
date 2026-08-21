{
 Copyright Larry Tyree, N6TR, 2011,2012,2013,2014,2015.

 This file is part of TR4W    (TRDOS)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W.  If not, see
 <http: www.gnu.org/licenses/>.
 }
unit LOGWAE;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses
  uCallSignRoutines,
  Windows,
  Tree,
  uQTCS,
  uTotal,
  VC,
  TF,
  //Country9,
  ZoneCont,
  LogSCP,
  LogWind,
  LogCW,
  //LOGDDX,
  LogDupe,
  LogStuff,
  LogGrid,
//  Help,
  LogK1EA,
  LOGDVP,
  LogDom,
  PostUnit,
  LogEdit
  ;

type
  QTCActionType = (NoQTCAction, AbortThisQTC, SaveThisQTC);

  TQTCsToBeSend = record
   {02}qsID: Word;
   {02}qsTime: Word;
   {04}qsNumber: integer;
   {04}qsQSOID1: Cardinal;
   {04}qsQSOID2: Cardinal;
   {14}qsCall: CallString;
   {01}qsReserved1: Byte;
   {01}qsReserved2: Byte;
  end;

var
  QTCsToBeSendArray                     : array[1..10] of TQTCsToBeSend;
  QTCExtraSpace                         : boolean = True;
//  QTCNote                          : Str80;
  QTCQRS                                : boolean = True;
  QTCNumber                             : integer;
  NumberMessagesToBeSentString {, QTCNumberString}: string;

  QRVString                             : array[0..160] of AnsiChar;

  //  QTCBuffer                        : LogEntryArray;
  {MaxQTCString, }QTCCallsign           : CallString;
  NumberQTCsAlreadySent                 : integer;

  NumberMessagesToBeSent, {MessageINT, } MaxQTCsThisStation: integer;
const
  QTCTOP                                = 10;

QTCHEIGHT                             = 26;
// QTCHEIGHT                             = 28  ;      //n4af 04.40.2 Q PRINTS AS 'O'
 QTCROWSDIS                            = 2;
 
//procedure WAEQTC(var QTCCallsign: CallString);
procedure WAEQTC2;
procedure LastQTCSent(var Call: CallString; var Time: Str20; var QSONumber: integer);
function NumberAvailableQTCsForThisCall(Call: CallString): integer;

implementation
uses uQTCR,
  MainUnit;

function QTCQuickEditResponse(Prompt: Str80;
  var QTCAction: QTCActionType;
  var ControlEnterUsed: boolean): Str80;

begin
end;

procedure WAEQTC(var QTCCallsign: CallString);

{ This procedure gets called whenever we are asking for a QTC.  It will
  handle everything needed to do the QTC.  It will return after everything
  has been done.  }

label
  SaveQTC, StopQTC, KeepGoing;

  begin

end;

procedure WAEQTC2;

{ This procedure gets called whenever we are asking for a QTC.  It will
  handle everything needed to do the QTC.  It will return after everything
  has been done.  }

label
  SaveQTC, StopQTC, KeepGoing;

var
    p                                     : PAnsiChar;
begin


  Windows.ZeroMemory(@QTCCallsign, 13);
  QTCCallsign := CallWindowString;
  if QTCCallsign = '' then
     begin
     QTCCallsign := VisibleLog.LastEntry(False,letCallsign);
     end;

  if QTCCallsign = '' then Exit;

  if not GoodCallSyntax(QTCCallsign) then
     begin
     DoABeep(Warning);
     QuickDisplay(TC_INVALIDCALLSIGNINCALLWINDOW);
     Exit;
     end;

  QTCCallsign := StandardCallFormat(QTCCallsign, False);

  //  for Line := 1 to 5 do QTCBuffer[Line] := '';

  NumberQTCsAlreadySent := NumberQTCsThisStation(QTCCallsign);

  if NumberQTCsAlreadySent >= 10 then
     begin
     DoABeep(Warning);
     p := @QTCCallsign[1];
     // Issue #997: asm wsprintf-push -> TF.Format.
     TF.Format(wsprintfBuffer, TC_SORRYYOUALREADYHAVE10QTCSWITH, p);
     QuickDisplay(wsprintfBuffer);
     Exit;
     end;

  MaxQTCsThisStation := 10 - NumberQTCsAlreadySent;
//  Str(MaxQTCsThisStation, MaxQTCString);

  if MyContinent = Europe then // We are receiving QTCs
     begin
      {
          if NumberQTCsAlreadySent = 0 then
            SendStringAndStop('QTC?')
          else
            SendStringAndStop('PSE ' + MaxQTCString + ' QTC?');
      }
      //    ClearPTTForceOn;
      {
          repeat
            TempString := QuickEditResponse(PChar('Enter QTC #/# (max of ' + MaxQTCString + ') or RETURN if QRU'), 8);

            if TempString = EscapeKey then
              if CWStillBeingSent then
                FlushCWBufferAndClearPTT
              else
                Exit;

            if TempString = '' then Exit;
          until TempString <> EscapeKey;
      }

    // QTCCallsign is a CallString -- a ShortString -- and a GLOBAL, so a
    // shorter reassignment leaves the tail of the previous call behind it,
    // exactly as the radio name did (56a8ae97).
    SetMainWindowText(mweCall, string(QTCCallsign));
      {
          QTCHeaderString := QuickEditResponse(PChar('Enter QTC #/# (max of ' + MaxQTCString + ') or RETURN if QRU'), 8);

          if QTCHeaderString = '' then
          begin
            if CWStillBeingSent then FlushCWBufferAndClearPTT;
            Exit;
          end;
          if not DetermineQTCNumberAndQuanity(QTCHeaderString, QTCNumber, NumberMessagesToBeSent) then Exit;
      }
//    tDialogBox(62, @QTCRDlgProc);
      ShowQTCReceive;

      //    ClearWindow(EditableLogwindow);

  end

  else

     begin // We are sending QTCs

     NumberMessagesToBeSent := NumberAvailableQTCsForThisCall(QTCCallsign);

     if NumberMessagesToBeSent = 0 then
        begin
        SendStringAndStop('QRU');
        DoABeep(Warning);
        QuickDisplay(TC_NOQTCSPENDINGQRU);
        Exit;
        end;

     if NumberMessagesToBeSent > MaxQTCsThisStation then
        begin
        NumberMessagesToBeSent := MaxQTCsThisStation;
        end;

     QTCNumber := NumberQTCBooksSent + 1;
 {
    asm
    push NumberMessagesToBeSent
    push QTCNumber
    end;
}
     QRVString[0] := AnsiChar(TF.Format(@QRVString[1], 'QTC %u/%u', QTCNumber, NumberMessagesToBeSent));
 //    asm add esp,16 end;

     // Issue #997: asm `lea eax,[QRVString]; call SendStringAndStop` -> direct call.
     SendStringAndStop(QRVString);
     SendStringAndStop(' QRV?');

     // Issue #997: asm wsprintf-push -> TF.Format. TC_ISQRVFOR = 'Is %s QRV for %s?';
     // cdecl-reverse pushes -> arg1=QTCCallsign, arg2=QRVString.
     TF.Format(wsprintfBuffer, TC_ISQRVFOR, @QTCCallsign[1], @QRVString[1]);

     if YesOrNo2(tr4whandle, wsprintfBuffer) <> IDOK then Exit;
     //tDialogBox(63, @QTCSDlgProc);
     ShowQTCSend;

     end;
end;

procedure LastQTCSent(var Call: CallString; var Time: Str20; var QSONumber: integer);


begin
end;

function NumberAvailableQTCsForThisCall(Call: CallString): integer;
label
  1, 2;
var
  QTCs                                  : integer;
begin
  Result := 0;
  if not OpenLogFile then Exit;
  QTCs := 0;
  ReadVersionBlock;
  Windows.ZeroMemory(@QTCsToBeSendArray, SizeOf(QTCsToBeSendArray));
  QTCsToBeSendArray[1].qsID := NET_THIS_QTC_WAS__SEND_ID;
  1:
  if ReadLogFile then
     begin
     if GoodLookingQSO then
       if TempRXData.ceDupe = False then
          begin
          if (TempRXData.ceWasSendInQTC = False) and (TempRXData.Callsign <> Call) then
             begin
             inc(QTCs);
             QTCsToBeSendArray[QTCs].qsTime := TempRXData.tSysTime.qtHour * 100 + TempRXData.tSysTime.qtMinute;
             QTCsToBeSendArray[QTCs].qsCall := TempRXData.Callsign;
             QTCsToBeSendArray[QTCs].qsNumber := TempRXData.NumberReceived;
             QTCsToBeSendArray[QTCs].qsQSOID1 := TempRXData.ceQSOID1;
             QTCsToBeSendArray[QTCs].qsQSOID2 := TempRXData.ceQSOID2;
             end;
          if QTCs = 10 then
             begin
             goto 2;
             end;
          end;
     goto 1;
     end;
  2:
  CloseLogFile;
  Result := QTCs;
{
  NumberQTCsPending := TotalPendingQTCs;

  if NumberQTCsPending = 0 then
  begin
    NumberAvailableQTCsForThisCall := 0;
    Exit;
  end;

  if NumberQTCsPending > 10 then
    NumberQTCsPending := 10;

//BigCompressFormat(Call, CompressedCall);

  for QTC := 0 to NumberQTCsPending - 1 do
//    if BigCompressedCallsAreEqual(CompressedCall, PendingQTCArray^[NextQTCToBeSent + QTC].Call) then
    if PendingQTCArray^[NextQTCToBeSent + QTC].Call = Call then
    begin
      NumberAvailableQTCsForThisCall := QTC;
      Exit;
    end;

  NumberAvailableQTCsForThisCall := NumberQTCsPending;
}
end;

end.


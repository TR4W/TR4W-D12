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
  LCLType,   (* IDOK -- the LCL declares it, and it is the same value *)
  uCallSignRoutines,
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
  ,
  uTR4WStrings,
  utils_text;

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
//  QTCNote                          : Str80;
  (* QTCExtraSpace and QTCQRS are gone (2026-09-12) --
    Settings.Qtc.ExtraSpace and Settings.Qtc.Qrs. *)
  QTCNumber                             : integer;
  NumberMessagesToBeSentString {, QTCNumberString}: string;

  (* A ShortString, BECAUSE THAT IS WHAT IT ALWAYS WAS.

    It was array[0..160] of AnsiChar used as a ShortString BY HAND: byte 0
    held the length and the text began at byte 1, written by TF.Format
    (wsprintfA), which also NUL-terminated it. Two readers therefore took
    @QRVString[1], and one of them carried a comment explaining why that
    pointer was safe.

    TF.Format WAS DELETED (2026-09-14) and the write became

        QRVString := SysUtils.Format('QTC %u/%u', [...]);

    which is a plain char-array assignment: the text now starts at byte 0.
    Both readers were still taking byte 1, so the caption lost its leading
    character -- 'TC 3/10' -- and logwae's Format got a bare Pointer for a
    %s, which FPC reports as "Invalid argument index in format".

    Str160 IS string[160] -- exactly the layout the hand-rolled version was
    imitating -- and it is what SendStringAndStop already takes. Every reader
    now says QRVString and the compiler keeps the length. *)
  QRVString                             : Str160;

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
function NumberAvailableQTCsForThisCall(Call: CallString): integer;

implementation
uses
   uQTCR,
   (* Which store a log READ comes from -- step B4.  See uLogSource. *)
   uLogSource,
  MainUnit,
   (* SetEntryText / TR4WCallEdit -- the QTC callsign goes into the ENTRY
     FIELD, which is a TEdit and not one of the status panels. *)
   uMainForm,
   SysUtils;   // SysUtils.Format -- the shared format buffers are gone

function QTCQuickEditResponse(Prompt: Str80;
  var QTCAction: QTCActionType;
  var ControlEnterUsed: boolean): Str80;

begin
end;

procedure WAEQTC2;

{ This procedure gets called whenever we are asking for a QTC.  It will
  handle everything needed to do the QTC.  It will return after everything
  has been done.  }

label
  SaveQTC, StopQTC, KeepGoing;

begin


  FillChar(QTCCallsign, 13, 0);
  QTCCallsign := CallWindowString;
  if QTCCallsign = '' then
     begin
     QTCCallsign := VisibleLog.LastEntry(False,letCallsign);
     end;

  if QTCCallsign = '' then Exit;

  if not IsAGoodCall(QTCCallsign) then
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
     // Issue #997: asm wsprintf-push -> TF.Format.
     QuickDisplay(SysUtils.Format(AnsiString(LclText(TC_SORRYYOUALREADYHAVE10QTCSWITH)), [string(QTCCallsign)]));
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
    SetEntryText(TR4WCallEdit, string(QTCCallsign));
      {
          QTCHeaderString := QuickEditResponse(PChar('Enter QTC #/# (max of ' + MaxQTCString + ') or RETURN if QRU'), 8);

          if QTCHeaderString = '' then
          begin
            if CWStillBeingSent then FlushCWBufferAndClearPTT;
            Exit;
          end;
          if not DetermineQTCNumberAndQuanity(QTCHeaderString, QTCNumber, NumberMessagesToBeSent) then Exit;
      }
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
     (* PLAIN ASSIGNMENT. This wrote into the ShortString's BODY through a
       PAnsiChar and set its LENGTH BYTE from the sprintf's return -- both of
       which the compiler does correctly, and correctly is the point: the
       hand-written length is what makes a ShortString buffer lie about its
       own contents when the format is wrong. *)
     QRVString := SysUtils.Format('QTC %u/%u', [QTCNumber, NumberMessagesToBeSent]);
 //    asm add esp,16 end;

     // Issue #997: asm `lea eax,[QRVString]; call SendStringAndStop` -> direct call.
     SendStringAndStop(QRVString);
     SendStringAndStop(' QRV?');

     // Issue #997: asm wsprintf-push -> TF.Format. TC_ISQRVFOR = 'Is %s QRV for %s?';
     // cdecl-reverse pushes -> arg1=QTCCallsign, arg2=QRVString.
     (* BOTH PASS AS THEMSELVES NOW. The note that used to stand here said
       @QRVString[1] was "correct and stays" because TF.Format NUL-terminated
       from byte 1 -- true when it was written, and TF.Format is gone. A
       ShortString in an array of const is vtString, which carries its own
       length; a bare @ is vtPointer, which %s refuses. *)
     if YesOrNo2(SysUtils.Format(AnsiString(LclText(TC_ISQRVFOR)),
                                 [QTCCallsign, QRVString])) <> IDOK then Exit;
     ShowQTCSend;

     end;
end;

function NumberAvailableQTCsForThisCall(Call: CallString): integer;
label
  1, 2;
var
  QTCs                                  : integer;
begin
  Result := 0;
  if not LogSourceOpen then Exit;
  QTCs := 0;
  LogSourceRewind;
  FillChar(QTCsToBeSendArray, SizeOf(QTCsToBeSendArray), 0);
  QTCsToBeSendArray[1].qsID := NET_THIS_QTC_WAS__SEND_ID;
  1:
  if LogSourceNext( TempRXData ) then
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
  LogSourceClose;
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


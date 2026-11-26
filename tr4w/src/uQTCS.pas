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
  (* LCLType, not Windows (2026-09-08): Sleep comes from SysUtils, and IDOK /
    IDNO -- what YesOrNo and the dialogs answer with -- are declared by
    lcltype.pp with the same values Win32 gives them. *)
  LCLType,
  Tree,
  LogCW,
  uDialogs,
  LogWind,
  LogRadio,
  (* Messages dropped 2026-09-08: this unit names nothing from it.
    Verified by removing the import and compiling for
    x86_64-linux -- not by grepping, which cannot see a bare type
    name and would have missed it either way. *)
  uTR4WStrings,
  utils_text;

// One of the eight sending commands, by its QTC_SEND_* id.  Was the dialog
// proc's WM_COMMAND case; the window calls this and owns no logic of its own.
procedure QTCSendCommand(const aCommand: integer);

procedure SendQTC(QTC: integer);
procedure SaveQTCS;

(* MARKS THE FIRST aCount QSOS OF THE BOOK (LOGWAE.QTCsToBeSendRowIds) "SENT
  IN A QTC" in the log, in one transaction, and only then tells the server of
  each (issue 385). False when the log did not take the mark: logged, the
  status line says NOT SAVED, and nothing is sent. *)
function MarkQTCBookSent(aCount: integer): boolean;

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
  QTCTXButtonCaptions                   : array[0..QTCCustomMessages] of string =
    (
    'N&EXT [return]',
    '',
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
   { The SQLite shadow -- an IMPLEMENTATION-section use, so no interface
     cycle. uLogStore never raises and never blocks logging. }
   uLogStore,
  uNet,
  uNetResend,       (* QsoHasNetworkIdentity, NetQsoTag -- the mark's send *)
  LogK1EA,          (* DoABeep -- a mark the log did not take *)
  LOGSUBS2,
  LOGWAE,
  uQTCSendForm,
  uSettingsModel,   { Settings.Qtc.Minutes }
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
  (* WAS PAnsiChar, POINTING INTO A ShortString'S CHARACTERS. See where it is
    assigned: a ShortString carries its length in byte 0 and has NO
    TERMINATOR, so anything that walked this pointer read past the callsign
    until it met a zero byte belonging to something else. That is the defect
    logedit records with a screenshot -- "Mult needs for N6TNYC", a callsign
    that has never been on the air. *)
  p                                     : string;
  Format                                : string;
  TempQTCMinutes                        : boolean;
const
  FormatArray                           : array[boolean, boolean, boolean] of string =
//QTCQRS,QTCExtraSpace,QTC MINUTES
//false,true
  (
    (
    (* %.4u / %.2u, not %04u / %02u. The result is SENT AS CW, and the
      difference is audible: a leading 0 is read as WIDTH and pads with
      SPACES, so QTC 7 would go out as '   7' instead of '0007'.

      THAT RULE SURVIVED THE MOVE OFF wsprintfA, and it was measured rather
      than assumed before this table changed hands (2026-09-14):

          SysUtils.Format('%.4u', [7])  ->  '0007'
          SysUtils.Format('%04u',  [7])  ->  '   7'

      FPC reads a PRECISION on an integer as a minimum digit count padded with
      zeros, which is what wsprintfA did, so every string here carries over
      unchanged. *)
    ('%.4u %s %u', '%.2u %s %u'),
    ('%.4u  %s  %u', '%.2u  %s  %u')
    )
    ,
    (
    (ControlS + '%.4u %s %u' + ControlF, ControlS + '%.2u %s %u' + ControlF),
    (ControlS + '%.4u  %s  %u' + ControlF, ControlS + '%.2u  %s  %u' + ControlF)
    )

    );
begin
  if not (QTC in [1..10]) then Exit;
{
  Format := '%04u %s %u';
  if Settings.Qtc.Qrs then
  begin
    Format := ControlS + '%04u %s %u' + ControlF;
    if Settings.Qtc.ExtraSpace then Format := ControlS + '%04u  %s  %u' + ControlF;
  end
  else
    if Settings.Qtc.ExtraSpace then Format := '%04u  %s  %u';
}

  Time := QTCsToBeSendArray[QTC].qsTime;
  p := string(QTCsToBeSendArray[QTC].qsCall);
  Number := QTCsToBeSendArray[QTC].qsNumber;

  TempQTCMinutes := (LastSendedQTCHour = (Time div 100)) and Settings.Qtc.Minutes;
  Format := FormatArray[Settings.Qtc.Qrs, Settings.Qtc.ExtraSpace,
                        TempQTCMinutes];

  if Settings.Qtc.Minutes then
     begin
     if LastSendedQTCHour = (Time div 100) then
        begin
        Time := Time mod 100;
        end;
     LastSendedQTCHour := QTCsToBeSendArray[QTC].qsTime div 100;
     end;

  SetLength(TempString, 160);
  (* THE FORMAT STRING IS STILL CHOSEN AT RUN TIME from FormatArray; what
    changed is that it is a `string` now and SysUtils.Format consumes it.
    The local is still named `Format`, so the call stays qualified. *)
  (* The last TF.Format caller in the tree. It wrote into the ShortString's
    BODY through a PAnsiChar and set its LENGTH BYTE from the sprintf's return;
    plain assignment does both, correctly. The format string is still chosen at
    run time from FormatArray -- that part is unchanged. *)
  TempString := SysUtils.Format(Format, [Time, p, Number]);
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
     FillChar(QTCRXData, SizeOf(ContestExchange), 0);
     QTCRXData.ceRecordKind := rkQTCS;
 //    tGetQSOSystemTime(QTCRXData.tSysTime);
 //    QTCRXData.Band := ActiveBand;
 //    QTCRXData.Mode := ActiveMode;
 //    QTCRXData.ceComputerID := Settings.Computer.Id;
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
  MarkQTCBookSent(QTCWasSend);
  { The book is saved, so the window goes WITHOUT asking whether the operator
    means to abandon it -- EndDialog had the same property, it did not go back
    through WM_CLOSE. }
  CloseQTCSendWindow;
end;

(* THE MARK GOES TO THE ROWS THE BOOK WAS OFFERED FROM (issue 385).

  This scanned the binary .TRW for each QSO's id pair and rewrote the
  database row at the same FILE POSITION. Nothing writes a .TRW any more, so
  on a log made by this build it found no file and marked nothing: the same
  QSOs were offered in the next book. With a leftover .TRW it rewrote rows
  with that file's stale records. *)
function MarkQTCBookSent(aCount: integer): boolean;
var
   rowIds: array of Int64;
   marked: TLogRowUpdates;
   rec: ContestExchange;
   i: integer;
begin
   Result := True;
   if aCount > High(QTCsToBeSendRowIds) then
      begin
      aCount := High(QTCsToBeSendRowIds);
      end;
   if aCount < 1 then
      begin
      Exit;
      end;

   SetLength(rowIds, aCount);
   for i := 1 to aCount do
      begin
      rowIds[i - 1] := QTCsToBeSendRowIds[i];
      end;

   marked := TLogRowUpdates.Create;
   try
      Result := LogStoreMarkSentInQTC(rowIds, marked);
      if not Result then
         begin
         logger.Warn('[QTC] the "sent in a QTC" mark on %d QSO(s) of QTC %d was ' +
                     'NOT saved; nothing was sent to the server', [aCount, QTCNumber]);
         QuickDisplay(LogStoreChangeNotSavedText);
         DoABeep(Warning);
         Exit;
         end;

      (* THE SERVER HEARS OF THE MARK ONLY ONCE IT IS IN THE LOG (issue 349),
        BY ROW: the id pair is only the settle tag. A row with no pair (an
        import's) cannot be settled by the server, so it is not sent --
        SendRecordToServer's rule. The send is queued to the writer thread. *)
      for i := 0 to marked.Count - 1 do
         begin
         rec := marked.Row(i);
         if QsoHasNetworkIdentity(rec) then
            begin
            SendRowToServer(NET_WIRE_EDIT_ID, marked.RowId(i),
                            NetQsoTag(rec.ceQSOID1, rec.ceQSOID2));
            end;
         end;
   finally
      marked.Free;
   end;
end;

procedure ShowQTCSend;
begin
   ShowQTCSendWindow;
end;
end.


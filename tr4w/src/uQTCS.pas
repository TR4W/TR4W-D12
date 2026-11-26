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

(* ONE QTC SERIES TO THE LOG, ALL OR NOTHING -- the send and the receive
  windows' one save (2026-11-26). Each record is stamped as this station's,
  the read-only log is tried again first, then the rows (and, for a sent
  series, the marks on aMarkRowIds) are ONE commit. Only after it: the record
  count, the per-pair quota, the series number, the network (paced aPaceMs
  between records) and the marks' edits. False: nothing moved, the status
  line says NOT SAVED, the caller keeps its window. *)
function CommitQTCSeries(var aRecords: array of ContestExchange;
                         const aMarkRowIds: array of Int64;
                         aPaceMs: integer): boolean;

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
  (* THE LOG REFUSED THE LAST SAVE OF THIS SERIES: NEXT and STOP save it again
    with the count already confirmed, rather than send more or ask again. *)
  QTCSeriesSavePending                  : boolean = False;

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
  uQTCSeries,       (* the series text, the record, the high-water mark *)
  MainUnit;

procedure QTCSendCommand(const aCommand: integer);
var
   TempString: Str160;
begin
   case aCommand of
      QTC_SEND_NEXT:
         begin
         (* A SERIES THE LOG REFUSED IS SAVED AGAIN, NOT EXTENDED: the
           operator's answers stand (see QTCSeriesSavePending). *)
         if QTCSeriesSavePending then
            begin
            SaveQTCS;
            Exit;
            end;
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
         (* After a refused save the confirmed count is already decided:
           asking "was message N confirmed?" again would take one more off. *)
         if QTCSeriesSavePending then
            begin
            SaveQTCS;
            Exit;
            end;
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

(* THE FIRST aCount ROWS OF THE BOOK, as the store takes them. *)
function QTCBookRowIds(aCount: integer): TLiveQsoRowIds;
var
   i: integer;
begin
   Result := nil;
   if aCount > High(QTCsToBeSendRowIds) then
      begin
      aCount := High(QTCsToBeSendRowIds);
      end;
   if aCount < 1 then
      begin
      Exit;
      end;
   SetLength(Result, aCount);
   for i := 1 to aCount do
      begin
      Result[i - 1] := QTCsToBeSendRowIds[i];
      end;
end;

(* THE SERVER HEARS OF EACH MARK ONLY ONCE IT IS IN THE LOG (issue 349), BY
  ROW: the id pair is only the settle tag. A row with no pair (an import's)
  cannot be settled by the server, so it is not sent -- SendRecordToServer's
  rule. The send is queued to the writer thread. *)
procedure SendQTCMarksToServer(aMarked: TLogRowUpdates);
var
   i: integer;
   rec: ContestExchange;
begin
   for i := 0 to aMarked.Count - 1 do
      begin
      rec := aMarked.Row(i);
      if QsoHasNetworkIdentity(rec) then
         begin
         SendRowToServer(NET_WIRE_EDIT_ID, aMarked.RowId(i),
                         NetQsoTag(rec.ceQSOID1, rec.ceQSOID2));
         end;
      end;
end;

(* A SENT SERIES, SAVED ALL OR NOTHING (2026-11-26).

  THE SERIES IS THE QTCs CONFIRMED: QTCWasSend of them, logged as
  '<series>/<QTCWasSend>' on every row -- not the count offered on the air
  ('QTC 3/10' stopped after 6 is the series 3/6). WAE section 7: "the second
  figure denotes the number of QTCs in the series", and only a QTC "correctly
  transferred" counts. D7 logged the offered count.

  ONE TRANSACTION: the QTC rows and the "sent in a QTC" marks on the QSOs they
  reported (uLogStore.LogStoreAppendQTCSeries). Only after its COMMIT are the
  per-pair quota, the series number and the record count moved, the rows sent
  to the network and the marks sent; a refusal moves, marks and sends
  nothing, says so on the status line, and leaves the window open so the
  operator can press NEXT or STOP to save the same series again. *)
function CommitQTCSeries(var aRecords: array of ContestExchange;
                         const aMarkRowIds: array of Int64;
                         aPaceMs: integer): boolean;
var
  I                                     : integer;
  marked                                : TLogRowUpdates;
begin
  Result := False;
  if Length(aRecords) = 0 then
     begin
     Exit;
     end;
  for I := 0 to High(aRecords) do
     begin
     StampLocalLogRecord(aRecords[I]);
     end;

  (* A LOG MADE READ-ONLY BY A FULL DISK IS TRIED AGAIN FIRST -- delete-last's
    and the QSO entry's precheck -- so a series kept after a refusal can be
    saved once space is freed. A log stood down for any other reason stays
    down for the session: the store has said so. *)
  if LogStoreTryRecoverWrites then
     begin
     LogStoreShowRecoveryNotice;
     marked := TLogRowUpdates.Create;
     try
        Result := LogStoreAppendQTCSeries(aRecords, aMarkRowIds, marked);
        if Result then
           begin
           ShowRecordsAppendedToLog(Length(aRecords));
           for I := 0 to High(aRecords) do
              begin
              IncrementQTCCount(aRecords[I].Callsign);
              NumberQTCBooksSent := QTCSeriesHighWater(NumberQTCBooksSent, aRecords[I]);
              if PublishCommittedRecord(aRecords[I]) and (aPaceMs > 0) then
                 begin
                 Sleep(aPaceMs);
                 end;
              end;
           SendQTCMarksToServer(marked);
           end;
     finally
        marked.Free;
     end;
     end;

  if not Result then
     begin
     logger.Error('[QTC] series %s (%d QTC(s)) with %s was NOT saved: no QTC is ' +
                  'counted, no QSO is marked and nothing was sent; the window stays open',
                  [string(aRecords[0].RandomCharsReceived), Length(aRecords),
                   string(aRecords[0].Callsign)]);
     QuickDisplay(LogStoreChangeNotSavedText);
     DoABeep(Warning);
     end;
end;

procedure SaveQTCS;
var
  I                                     : integer;
  records                               : array of ContestExchange;
begin
  if QTCWasSend < 1 then
     begin
     Exit;
     end;

  SetLength(records, QTCWasSend);
  for I := 1 to QTCWasSend do
     begin
     records[I - 1] := SentQTCRecord(string(QTCCallsign), QTCNumber, QTCWasSend,
                                     QTCsToBeSendArray[I].qsTime,
                                     string(QTCsToBeSendArray[I].qsCall),
                                     QTCsToBeSendArray[I].qsNumber);
     end;

  QTCSeriesSavePending := not CommitQTCSeries(records, QTCBookRowIds(QTCWasSend), 100);
  if QTCSeriesSavePending then
     begin
     Exit;
     end;

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
   rowIds: TLiveQsoRowIds;
   marked: TLogRowUpdates;
begin
   Result := True;
   rowIds := QTCBookRowIds(aCount);
   if Length(rowIds) = 0 then
      begin
      Exit;
      end;
   aCount := Length(rowIds);

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

      SendQTCMarksToServer(marked);
   finally
      marked.Free;
   end;
end;

procedure ShowQTCSend;
begin
   (* A NEW BOOK STARTS AT NOTHING SENT. The Win32 dialog reset these on
     WM_INITDIALOG; the LCL form (d017a8ff5) dropped the reset, so a second
     book began with the first one's count -- and would have saved that many
     lines, reading QTCsToBeSendArray past the QSOs this book offered. *)
   QTCWasSend := 0;
   LastSendedQTCHour := -1;
   QTCSeriesSavePending := False;
   ShowQTCSendWindow;
end;
end.


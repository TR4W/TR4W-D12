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
unit uQTCR;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}

(*
  RECEIVING A WAE QTC: THE RULES, not the window.

  The window is ui\lcl\uQTCReceiveForm.  What is left here is what a QTC
  actually is -- a group number and a count, then that many lines of time,
  callsign and serial, each checked before the next is unlocked -- and the code
  that writes them to the log.

  THE DIALOG AND ITS THIRTY-TWO SUBCLASSED EDITS ARE GONE.  QTCRDlgProc built
  the grid and pointed every edit's GWL_WNDPROC at NewQTCREditProc, one
  procedure that then had to work out which control it was running for by
  comparing HWNDs and reading the child id back modulo 100.  See the form's
  header for what each part of it became.

  WHAT IS LEFT ADDRESSES ROWS AND COLUMNS BY NAME.  CheckQTCR used to read
  GetDlgItemInt(QTCRWindow, 200 + Item) and GetDialogItemText(QTCRWindow,
  300 + Item) -- a global window handle and arithmetic on control ids, from a
  unit whose subject is contest rules.  It asks the form for the row's fields
  now, which is the same information without the two things that can silently
  be wrong: the handle and the offset.
*)

interface

uses
  VC,
  utils_text,
  uCallSignRoutines,
  LogStuff,
  LogWind,
  LOGWAE,
  LogCW,
  LogDupe,
  LOGSUBS2,
  uTotal,
  Tree,
  Windows,
  uTR4WStrings;

const

  { The ten ask-him-again buttons, in row order.  Two are blank in the table:
    the seventh is overwritten with '&DE <my callsign>' when the window is
    built, and the tenth has never had a caption. }
  QTCRXButtonsPChar                     : array[1..10] of PAnsiChar =
    (
    '&AGN',
    'R&PT?',
    '&TIME?',
    '&CALL?',
    '&NR?',
    '&R',
    nil,
    '&QTC?',
    'QR&V',
    nil
    );

var
  QTCsReceived                          : integer;

// The operator pressed Return in the QTC-number box: check '<group>/<count>',
// and if it is good unlock the first row and tell him we are ready.
procedure QTCNumberEntered;

// The operator pressed Return somewhere in row aRow: check the row, and if it
// is good either unlock the next one or save the book.
procedure QTCRowEntered(const aRow: integer);

// Forget the group, for a new station.
procedure ResetQTCGroup;

// Has a group been started?  What the window asks before offering to abandon.
function QTCGroupStarted: boolean;

procedure SaveQTCR;

// the WAE QTC receive window.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows what this is, only that the window opens.  When the dialog
// became an LCL form this body changed and nothing at any call site did.
procedure ShowQTCReceive;

implementation

uses
  SysUtils,
  uQTCReceiveForm,
  MainUnit;

var
  QTCsInCurrentGroup                    : integer;
  CurrentGroup                          : integer;

procedure ResetQTCGroup;
begin
   CurrentGroup       := 0;
   QTCsInCurrentGroup := 0;
end;

function QTCGroupStarted: boolean;
begin
   Result := CurrentGroup <> 0;
end;

{ '<group>/<count>', e.g. '3/10'.

  WAS A CHAR BUFFER AND A HAND-ROLLED SCAN: GetWindowTextA into a 64-byte array,
  a loop looking for exactly one '/', and GetNumberFromCharBuffer on each half.
  The rules are unchanged and stated the same way -- at least three characters,
  not ending in a slash, exactly one slash, a non-zero group, and a count from
  one to ten that does not exceed what this station may still send. }
function CheckQTCNr: boolean;
var
   { AnsiString throughout, because that is what the form's fields are.  This
     unit's own `string` is UnicodeString, and letting the conversion happen
     implicitly at each call is exactly the silent narrowing the build counts. }
   s     : AnsiString;
   slash : integer;
begin
   Result := False;

   s := string(QTCReceiveForm.QTCNrText);
   if Length(s) <= 2 then
      begin
      Exit;
      end;
   if s[Length(s)] = '/' then
      begin
      Exit;
      end;

   slash := Pos('/', s);
   if slash = 0 then
      begin
      Exit;
      end;
   { Exactly one.  A second slash anywhere after the first is a typo, not a
     second field. }
   if Pos('/', Copy(s, slash + 1, MaxInt)) > 0 then
      begin
      Exit;
      end;

   CurrentGroup := StrToIntDef(Copy(s, 1, slash - 1), 0);
   if CurrentGroup = 0 then
      begin
      Exit;
      end;

   QTCsInCurrentGroup := StrToIntDef(Copy(s, slash + 1, MaxInt), 0);
   if not (QTCsInCurrentGroup in [1..10]) then
      begin
      Exit;
      end;
   if QTCsInCurrentGroup > MaxQTCsThisStation then
      begin
      Exit;
      end;

   Result := True;
end;

{ One line: a legal time, a callsign that looks like one, and a serial.

  StrToIntDef WITH -1, not 0: GetDlgItemInt reported failure through a separate
  BOOL, and an empty field has to fail rather than read as midnight. }
function CheckQTCR(const aRow: integer): boolean;
var
   frm  : TfrmQTCReceive;
   Time : integer;
   Call : CallString;
begin
   Result := False;
   frm := QTCReceiveForm;
   if frm = nil then
      begin
      Exit;
      end;

   Time := StrToIntDef(Trim(frm.RowTime(aRow)), -1);
   if (Time < 0) or ((Time mod 100) > 59) or ((Time div 100) > 23) then
      begin
      frm.SetStatus(TC_CHECKTIME);
      frm.FocusField(aRow, qcTime);
      Exit;
      end;

   Call := frm.RowCall(aRow);
   if not IsAGoodCall(Call) then
      begin
      { Silent while the field is still empty -- he has not typed it yet, and
        "check callsign" on an untouched box is noise. }
      if Call <> '' then
         begin
         frm.SetStatus(TC_CHECKCALLSIGN);
         end;
      frm.FocusField(aRow, qcCall);
      Exit;
      end;

   if StrToIntDef(Trim(frm.RowNumber(aRow)), -1) < 0 then
      begin
      { No message here, as before: the number is self-evidently missing and the
        caret lands in it. }
      frm.FocusField(aRow, qcNumber);
      Exit;
      end;

   frm.SetStatus('');
   Result := True;
end;

procedure QTCNumberEntered;
var
   frm: TfrmQTCReceive;
begin
   frm := QTCReceiveForm;
   if frm = nil then
      begin
      Exit;
      end;

   if CheckQTCNr then
      begin
      frm.EnableRow(1);
      frm.FocusField(1, qcTime);
      SendStringAndStop('QRV');
      end
   else
      begin
      frm.SetStatus(TC_CHECKQTCNUMBER);
      end;
end;

procedure QTCRowEntered(const aRow: integer);
var
   frm: TfrmQTCReceive;
begin
   frm := QTCReceiveForm;
   if frm = nil then
      begin
      Exit;
      end;

   if not CheckQTCR(aRow) then
      begin
      Exit;
      end;

   inc(QTCsReceived);

   if QTCsReceived < QTCsInCurrentGroup then
      begin
      SendStringAndStop('R');
      frm.EnableRow(aRow + 1);
      frm.FocusField(aRow + 1, qcTime);
      end
   else
      begin
      SaveQTCR;
      end;
end;

procedure SaveQTCR;
var
   i        : integer;
   frm      : TfrmQTCReceive;
   QTCRXData: ContestExchange;
   QTCNr    : AnsiString;
begin
   if QTCsReceived = 0 then
      begin
      Exit;
      end;

   frm := QTCReceiveForm;
   if frm = nil then
      begin
      Exit;
      end;

   if QTCsInCurrentGroup <> QTCsReceived then
      begin
      if YesOrNo(TC_DOYOUREALLYWANTTOSAVETHISQTC) = IDNO then
         begin
         Exit;
         end;
      end;

   { Yes means "let me keep editing", so this returns without saving.  Worth
     reading twice -- the question is phrased the other way round from the one
     above it. }
   if YesOrNo(TC_EDITQTCPRESSYESTOEDITQTCORNOTOLOG) = IDYES then
      begin
      Exit;
      end;

   IF QTCsReceived > QTCsInCurrentGroup then   // 4.126.3
      begin
      QTCsReceived := QTCsInCurrentGroup;
      end;

   QTCNr := frm.QTCNrText;

   for i := 1 to QTCsReceived do
      begin
      IncrementQTCCount(QTCCallsign);
      Windows.ZeroMemory(@QTCRXData, SizeOf(ContestExchange));
      QTCRXData.ceRecordKind := rkQTCR;
      QTCRXData.Callsign := QTCCallsign;
      {Time}
      QTCRXData.NumberSent := StrToIntDef(Trim(frm.RowTime(i)), 0);
      {EU Callsign}
      QTCRXData.Kids := frm.RowCall(i);
      {Number}
      QTCRXData.NumberReceived := StrToIntDef(Trim(frm.RowNumber(i)), 0);
      {QTCNumber}
      QTCRXData.RandomCharsReceived := QTCNr;
      if AddRecordToLogAndSendToNetwork(QTCRXData) then
         begin
         Sleep(50);
         end;
      end;

   SendStringAndStop(AnsiString('QSL ') + QTCNr + AnsiString(' TU'));

   { Was SendMessage(QTCRWindow, WM_CLOSE, 1, 0) -- the 1 in wParam was there
     purely to skip the are-you-sure question on the way out.  Saying Hide says
     that directly. }
   CloseQTCReceiveWindow;
end;

procedure ShowQTCReceive;
begin
   ShowQTCReceiveWindow;
end;

end.
